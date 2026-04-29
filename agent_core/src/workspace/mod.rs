//! Plan §7 — Model Workspace Protocol: filesystem as orchestrator.
//!
//! For multi-step pipelines that span minutes (nightly re-routing,
//! batch ingestion of an email archive), the workspace is a numbered
//! directory tree:
//!
//! ```text
//! agent_core/data/workspace/<job_id>/
//!   00_inputs/
//!     capture-01.mem
//!     capture-02.mem
//!   01_concept_extract/
//!     _step.soul.md
//!     _step.soul.json
//!     out/
//!       capture-01.concepts.json
//!       capture-02.concepts.json
//!   02_canonicalize/
//!   03_route/
//!   04_apply/
//!     receipts/...
//! ```
//!
//! Each numbered folder = one stage. The soul file dictates: which
//! model, which grammar, which tool whitelist. Each stage reads from
//! `<previous>/out/` and writes to `<current>/out/`.
//!
//! Stages are independent processes — each can be inspected, replayed,
//! or hot-fixed. **Replays are deterministic**: reset the breaker,
//! rerun stage N with the same inputs, get byte-identical outputs
//! (Phase 7 exit criterion).
//!
//! This module owns the orchestration primitives (workspace open,
//! stage discovery, replay reset). Concrete stage runners (concept
//! extract, canonicalize, route, apply) plug in via the `StageRunner`
//! trait — they receive a `&Stage` and read/write via its API.
//!
//! Per FINAL_SYNTHESIS §2 Reflective Loop: this is the "Layer 3
//! Executive" stage when running batched. The Memory layer (§2 layer
//! 6) writes signed receipts under `04_apply/receipts/` after each
//! Intent applies.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use thiserror::Error;
use ulid::Ulid;

use crate::util::atomic_write_bytes;

#[derive(Debug, Error)]
pub enum WorkspaceError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("invalid stage directory name '{0}' (expected NN_name)")]
    InvalidStageName(String),
    #[error("stage {0} not found in workspace")]
    StageNotFound(usize),
    #[error("workspace path '{0}' is not a directory")]
    NotADirectory(PathBuf),
    #[error("serialize error: {0}")]
    Serialize(String),
}

/// A workspace job id — ULID for monotonic ordering on disk + for the
/// inspector CLI's `epistemos workspace show <job_id>` form.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, Hash)]
pub struct JobId(pub String);

impl JobId {
    pub fn new() -> Self {
        Self(Ulid::new().to_string())
    }

    pub fn from_str(s: impl Into<String>) -> Self {
        Self(s.into())
    }
}

impl Default for JobId {
    fn default() -> Self {
        Self::new()
    }
}

/// Convention: stage directories are named `NN_<slug>` where NN is a
/// two-digit zero-padded index (00, 01, 02, …) and `<slug>` is the
/// stage name. The `00_inputs` directory is special — it's the
/// pipeline's source, not a stage that produces output via a runner.
fn parse_stage_name(name: &str) -> Result<(usize, &str), WorkspaceError> {
    if name.len() < 4 || !name.is_char_boundary(2) || !name.as_bytes().get(2).map(|b| *b == b'_').unwrap_or(false) {
        return Err(WorkspaceError::InvalidStageName(name.to_string()));
    }
    let (idx_str, rest) = name.split_at(2);
    let idx: usize = idx_str
        .parse()
        .map_err(|_| WorkspaceError::InvalidStageName(name.to_string()))?;
    // strip the underscore
    let slug = &rest[1..];
    Ok((idx, slug))
}

/// One stage in a workspace. Stage 0 is conventionally `00_inputs`
/// (the pipeline source); stages ≥1 are runner-produced.
#[derive(Debug, Clone, PartialEq)]
pub struct Stage {
    pub index: usize,
    pub slug: String,
    pub root: PathBuf,
}

impl Stage {
    pub fn dir_name(&self) -> String {
        format!("{:02}_{}", self.index, self.slug)
    }

    /// Path to the stage's `out/` directory (where this stage's
    /// outputs live). Stage 0 has no `out/`; its files live directly
    /// in its root.
    pub fn out_dir(&self) -> PathBuf {
        if self.index == 0 {
            self.root.clone()
        } else {
            self.root.join("out")
        }
    }

    /// Path to the stage soul file (`_step.soul.json`). Stage 0 has
    /// no soul (it's the input source).
    pub fn soul_path(&self) -> Option<PathBuf> {
        if self.index == 0 {
            None
        } else {
            Some(self.root.join("_step.soul.json"))
        }
    }

    /// List output files in this stage. Returns sorted file names so
    /// replay/inspection is deterministic.
    pub fn list_outputs(&self) -> Result<Vec<PathBuf>, WorkspaceError> {
        let out = self.out_dir();
        if !out.exists() {
            return Ok(Vec::new());
        }
        let mut files = Vec::new();
        for entry in std::fs::read_dir(&out)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_file() {
                // Skip the soul file in stage 0 if any, plus dotfiles.
                if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                    if name.starts_with('.') || name.starts_with('_') {
                        continue;
                    }
                }
                files.push(path);
            }
        }
        files.sort();
        Ok(files)
    }

    /// Write an output file under this stage's `out/`. Atomic
    /// (tempfile + rename) per plan §6.9.
    pub fn write_output(&self, name: &str, contents: &[u8]) -> Result<PathBuf, WorkspaceError> {
        if name.contains('/') || name.contains('\\') || name.starts_with('.') {
            return Err(WorkspaceError::InvalidStageName(format!(
                "output name '{name}' must be a single file (no path separators, no dotfiles)"
            )));
        }
        let out = self.out_dir();
        std::fs::create_dir_all(&out)?;
        let path = out.join(name);
        atomic_write_bytes(&path, contents)
            .map_err(|e| WorkspaceError::Serialize(e.to_string()))?;
        Ok(path)
    }

    /// Replay reset: delete every file under `out/`. Stage 0 (inputs)
    /// is read-only and rejects this — replays start at stage ≥ 1.
    pub fn clear_outputs(&self) -> Result<(), WorkspaceError> {
        if self.index == 0 {
            return Err(WorkspaceError::InvalidStageName(
                "cannot clear stage 0 (inputs) outputs — that's the pipeline source".into(),
            ));
        }
        let out = self.out_dir();
        if !out.exists() {
            return Ok(());
        }
        for entry in std::fs::read_dir(&out)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_file() {
                std::fs::remove_file(&path)?;
            }
        }
        Ok(())
    }
}

/// One workspace job. Owns the directory tree under
/// `agent_core/data/workspace/<job_id>/`.
pub struct Workspace {
    pub job_id: JobId,
    pub root: PathBuf,
}

impl Workspace {
    /// Open an existing workspace (no scaffolding — fails if root
    /// doesn't exist).
    pub fn open(root: impl Into<PathBuf>) -> Result<Self, WorkspaceError> {
        let root = root.into();
        if !root.is_dir() {
            return Err(WorkspaceError::NotADirectory(root));
        }
        let job_id = root
            .file_name()
            .and_then(|n| n.to_str())
            .map(|s| JobId::from_str(s))
            .unwrap_or_default();
        Ok(Self { job_id, root })
    }

    /// Create a fresh workspace under `parent_dir/<job_id>/`. Inserts
    /// the canonical `00_inputs/` directory; runners will add the
    /// `NN_*` stages as they go.
    pub fn create(parent_dir: impl AsRef<Path>) -> Result<Self, WorkspaceError> {
        let job_id = JobId::new();
        let root = parent_dir.as_ref().join(&job_id.0);
        std::fs::create_dir_all(&root)?;
        std::fs::create_dir_all(root.join("00_inputs"))?;
        Ok(Self { job_id, root })
    }

    /// Create a workspace with a specific JobId (test helper + CLI
    /// `epistemos workspace show <job_id>` for resuming).
    pub fn create_with_job_id(
        parent_dir: impl AsRef<Path>,
        job_id: JobId,
    ) -> Result<Self, WorkspaceError> {
        let root = parent_dir.as_ref().join(&job_id.0);
        std::fs::create_dir_all(&root)?;
        std::fs::create_dir_all(root.join("00_inputs"))?;
        Ok(Self { job_id, root })
    }

    /// Discover stages by scanning the workspace root for numbered
    /// directories. Returns them sorted by index.
    pub fn stages(&self) -> Result<Vec<Stage>, WorkspaceError> {
        let mut by_index: BTreeMap<usize, Stage> = BTreeMap::new();
        for entry in std::fs::read_dir(&self.root)? {
            let entry = entry?;
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            let name = match path.file_name().and_then(|n| n.to_str()) {
                Some(n) => n,
                None => continue,
            };
            // skip non-stage dirs (dotfiles, README, etc.)
            if !name
                .as_bytes()
                .get(0..2)
                .map(|b| b.iter().all(|c| c.is_ascii_digit()))
                .unwrap_or(false)
            {
                continue;
            }
            let (index, slug) = parse_stage_name(name)?;
            by_index.insert(
                index,
                Stage {
                    index,
                    slug: slug.to_string(),
                    root: path,
                },
            );
        }
        Ok(by_index.into_values().collect())
    }

    /// Get a specific stage by its index. Returns `StageNotFound` if
    /// it doesn't exist on disk.
    pub fn stage(&self, index: usize) -> Result<Stage, WorkspaceError> {
        self.stages()?
            .into_iter()
            .find(|s| s.index == index)
            .ok_or(WorkspaceError::StageNotFound(index))
    }

    /// Add a new stage directory. Idempotent (no-op when the stage
    /// already exists on disk). Used by the runner to lazily
    /// materialize stages as the pipeline advances.
    pub fn ensure_stage(&self, index: usize, slug: &str) -> Result<Stage, WorkspaceError> {
        let dir_name = format!("{:02}_{}", index, slug);
        let path = self.root.join(&dir_name);
        std::fs::create_dir_all(&path)?;
        if index >= 1 {
            std::fs::create_dir_all(path.join("out"))?;
        }
        Ok(Stage {
            index,
            slug: slug.to_string(),
            root: path,
        })
    }

    /// Plan §7: "Replays are deterministic: reset the breaker, rerun
    /// stage N with the same inputs, get byte-identical outputs."
    /// This clears stage N's `out/` so the runner re-reads from
    /// stage N-1's `out/` (or stage 0's root for stage 1) and rewrites.
    pub fn reset_for_replay(&self, stage_index: usize) -> Result<(), WorkspaceError> {
        if stage_index == 0 {
            return Err(WorkspaceError::InvalidStageName(
                "cannot replay stage 0 — that's the pipeline source".into(),
            ));
        }
        let stage = self.stage(stage_index)?;
        stage.clear_outputs()
    }

    /// Returns the `out/` of the stage immediately before `index`,
    /// or `None` for stage 0. The runner reads its inputs from here.
    pub fn previous_stage_outputs(&self, index: usize) -> Result<Option<Vec<PathBuf>>, WorkspaceError> {
        if index == 0 {
            return Ok(None);
        }
        let prev = self.stage(index - 1)?;
        Ok(Some(prev.list_outputs()?))
    }

    /// Path to the workspace's input directory (stage 0).
    pub fn inputs_dir(&self) -> PathBuf {
        self.root.join("00_inputs")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn fresh_workspace() -> (TempDir, Workspace) {
        let tmp = TempDir::new().expect("tempdir");
        let ws = Workspace::create(tmp.path()).expect("create");
        (tmp, ws)
    }

    #[test]
    fn create_scaffolds_inputs_dir() {
        let (_tmp, ws) = fresh_workspace();
        assert!(ws.inputs_dir().is_dir(), "00_inputs/ must exist after create");
    }

    #[test]
    fn parse_stage_name_round_trips() {
        let (idx, slug) = parse_stage_name("01_concept_extract").unwrap();
        assert_eq!(idx, 1);
        assert_eq!(slug, "concept_extract");
        let (idx, slug) = parse_stage_name("00_inputs").unwrap();
        assert_eq!(idx, 0);
        assert_eq!(slug, "inputs");
    }

    #[test]
    fn parse_stage_name_rejects_malformed() {
        assert!(parse_stage_name("inputs").is_err());
        assert!(parse_stage_name("0_x").is_err());
        assert!(parse_stage_name("aa_x").is_err());
        assert!(parse_stage_name("00").is_err());
    }

    #[test]
    fn ensure_stage_creates_numbered_directory_with_out() {
        let (_tmp, ws) = fresh_workspace();
        let stage = ws.ensure_stage(1, "concept_extract").expect("ensure_stage");
        assert_eq!(stage.index, 1);
        assert_eq!(stage.slug, "concept_extract");
        assert!(stage.root.is_dir());
        assert!(stage.out_dir().is_dir());
        assert_eq!(stage.dir_name(), "01_concept_extract");
    }

    #[test]
    fn stages_returns_sorted_by_index() {
        let (_tmp, ws) = fresh_workspace();
        ws.ensure_stage(2, "canonicalize").unwrap();
        ws.ensure_stage(1, "concept_extract").unwrap();
        ws.ensure_stage(4, "apply").unwrap();
        ws.ensure_stage(3, "route").unwrap();
        let stages = ws.stages().unwrap();
        let indices: Vec<usize> = stages.iter().map(|s| s.index).collect();
        assert_eq!(indices, vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn stage_write_output_is_atomic_and_listable() {
        let (_tmp, ws) = fresh_workspace();
        let stage = ws.ensure_stage(1, "concept_extract").unwrap();
        stage.write_output("a.json", b"{\"a\":1}").unwrap();
        stage.write_output("b.json", b"{\"b\":2}").unwrap();
        let outputs = stage.list_outputs().unwrap();
        assert_eq!(outputs.len(), 2);
        // Sorted output for deterministic replay.
        assert!(outputs[0].file_name().unwrap().to_str().unwrap() < outputs[1].file_name().unwrap().to_str().unwrap());
    }

    #[test]
    fn stage_write_output_rejects_path_separators_and_dotfiles() {
        let (_tmp, ws) = fresh_workspace();
        let stage = ws.ensure_stage(1, "concept_extract").unwrap();
        assert!(stage.write_output("../escape.json", b"{}").is_err());
        assert!(stage.write_output("nested/path.json", b"{}").is_err());
        assert!(stage.write_output(".hidden", b"{}").is_err());
    }

    #[test]
    fn reset_for_replay_clears_outputs_only() {
        let (_tmp, ws) = fresh_workspace();
        let stage = ws.ensure_stage(1, "concept_extract").unwrap();
        stage.write_output("a.json", b"{\"a\":1}").unwrap();
        stage.write_output("b.json", b"{\"b\":2}").unwrap();
        assert_eq!(stage.list_outputs().unwrap().len(), 2);
        ws.reset_for_replay(1).unwrap();
        assert_eq!(stage.list_outputs().unwrap().len(), 0);
        // The stage dir + out dir still exist after the reset.
        assert!(stage.root.is_dir());
        assert!(stage.out_dir().is_dir());
    }

    #[test]
    fn reset_for_replay_rejects_stage_zero() {
        let (_tmp, ws) = fresh_workspace();
        let err = ws.reset_for_replay(0).unwrap_err();
        match err {
            WorkspaceError::InvalidStageName(msg) => {
                assert!(msg.contains("stage 0"), "must explain why: {msg}");
            }
            other => panic!("expected InvalidStageName, got {other:?}"),
        }
    }

    #[test]
    fn previous_stage_outputs_chains_pipeline() {
        let (_tmp, ws) = fresh_workspace();
        // Stage 0 holds inputs (no out/, files live in root).
        let inputs = ws.stage(0).unwrap();
        std::fs::write(inputs.root.join("capture-01.mem"), b"---\n{}\n---\nbody").unwrap();
        // Stage 1 reads from stage 0.
        let prev = ws.previous_stage_outputs(1).unwrap();
        let prev = prev.expect("stage 1 has a previous");
        let names: Vec<String> = prev
            .iter()
            .map(|p| p.file_name().unwrap().to_string_lossy().to_string())
            .collect();
        assert!(names.contains(&"capture-01.mem".to_string()));
        // Stage 0 has no previous.
        assert!(ws.previous_stage_outputs(0).unwrap().is_none());
    }

    #[test]
    fn deterministic_replay_invariant_byte_identical() {
        // Plan §7 exit gate: "rerun stage N with the same inputs,
        // get byte-identical outputs." We model this by running a
        // pure-function stage twice and comparing on-disk bytes.
        let (_tmp, ws) = fresh_workspace();
        // Seed inputs.
        let inputs = ws.stage(0).unwrap();
        std::fs::write(inputs.root.join("capture-01.mem"), b"alpha").unwrap();
        std::fs::write(inputs.root.join("capture-02.mem"), b"bravo").unwrap();

        // Stage 1 runner — pure function: hash the input and write
        // it to <name>.hash. Same inputs → byte-identical outputs.
        let run_stage_1 = |ws: &Workspace| {
            let stage = ws.ensure_stage(1, "concept_extract").unwrap();
            for input in ws.previous_stage_outputs(1).unwrap().unwrap() {
                let bytes = std::fs::read(&input).unwrap();
                let hash = format!("{:x}", sha2::Sha256::digest(&bytes));
                let name = input.file_name().unwrap().to_str().unwrap();
                stage
                    .write_output(&format!("{name}.hash"), hash.as_bytes())
                    .unwrap();
            }
        };

        run_stage_1(&ws);
        let stage = ws.stage(1).unwrap();
        let first: Vec<(String, Vec<u8>)> = stage
            .list_outputs()
            .unwrap()
            .into_iter()
            .map(|p| {
                let name = p.file_name().unwrap().to_string_lossy().to_string();
                let bytes = std::fs::read(&p).unwrap();
                (name, bytes)
            })
            .collect();

        // Replay: clear outputs, rerun.
        ws.reset_for_replay(1).unwrap();
        run_stage_1(&ws);
        let stage = ws.stage(1).unwrap();
        let second: Vec<(String, Vec<u8>)> = stage
            .list_outputs()
            .unwrap()
            .into_iter()
            .map(|p| {
                let name = p.file_name().unwrap().to_string_lossy().to_string();
                let bytes = std::fs::read(&p).unwrap();
                (name, bytes)
            })
            .collect();

        assert_eq!(
            first, second,
            "stage 1 replay must produce byte-identical outputs"
        );
    }
}

#[cfg(test)]
use sha2::Digest;
