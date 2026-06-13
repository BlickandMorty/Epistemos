//! Slice 2 persistence: a durable, replayable mutation command log for the
//! knowledge-core. Each KC mutation captures a deterministic `MutationCommand`;
//! appending them to a JSON-lines file and replaying on open reconstructs state
//! — both the in-memory fact mirrors AND the Cozo db, since replay re-runs the
//! live mutation path. See the cutover plan §10.

use std::path::PathBuf;

/// A replayable mutation command. Deterministic (no timestamps / random ids /
/// clock reads), so replaying the recorded sequence on a fresh store reproduces
/// identical state.
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum MutationCommand {
    IngestDocument {
        page_id: String,
        format: u8,
        text: String,
    },
    InsertBlock {
        page_id: String,
        block_id: String,
        parent_id: Option<String>,
        index: usize,
        content: String,
    },
    MoveBlock {
        page_id: String,
        block_id: String,
        parent_id: Option<String>,
        index: usize,
    },
    DeleteBlock {
        page_id: String,
        block_id: String,
    },
}

impl MutationCommand {
    /// The page every command targets. All four variants carry a `page_id`.
    pub fn page_id(&self) -> &str {
        match self {
            MutationCommand::IngestDocument { page_id, .. }
            | MutationCommand::InsertBlock { page_id, .. }
            | MutationCommand::MoveBlock { page_id, .. }
            | MutationCommand::DeleteBlock { page_id, .. } => page_id,
        }
    }
}

/// Append-only durable command log (JSON-lines). Best-effort: a write failure is
/// surfaced to the caller but never panics.
pub struct OpLog {
    path: PathBuf,
}

impl OpLog {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    /// The durable log's filesystem path.
    pub fn path(&self) -> &std::path::Path {
        &self.path
    }

    /// Append one command as a single JSON line.
    pub fn append(&self, command: &MutationCommand) -> std::io::Result<()> {
        use std::io::Write;
        let line = serde_json::to_string(command)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;
        writeln!(file, "{line}")
    }

    /// Read every parseable command in recorded order. A missing file yields an
    /// empty log; unparseable lines are skipped (best-effort recovery — a corrupt
    /// tail rolls back to a clean prefix rather than failing the whole replay).
    pub fn read_all(path: impl AsRef<std::path::Path>) -> Vec<MutationCommand> {
        let Ok(contents) = std::fs::read_to_string(path.as_ref()) else {
            return Vec::new();
        };
        contents
            .lines()
            .filter(|line| !line.trim().is_empty())
            .filter_map(|line| serde_json::from_str::<MutationCommand>(line).ok())
            .collect()
    }

    /// Compact a command sequence to its minimal state-equivalent form.
    ///
    /// `IngestDocument` does a full `replace_page`, so for any page its LAST
    /// ingest is a reset point: every command for that page recorded before it
    /// is dead and can be dropped. Commands recorded after the last ingest
    /// (block insert/move/delete) still apply on top of it and are kept, in
    /// order. Pages with no ingest at all keep every command (no safe reset
    /// point). Replaying the compacted sequence reproduces identical state.
    ///
    /// This bounds long-run growth from per-edit re-ingests: N edits of one
    /// page collapse to a single ingest.
    pub fn compact(commands: &[MutationCommand]) -> Vec<MutationCommand> {
        use std::collections::HashMap;
        let mut last_ingest: HashMap<&str, usize> = HashMap::new();
        for (index, command) in commands.iter().enumerate() {
            if matches!(command, MutationCommand::IngestDocument { .. }) {
                last_ingest.insert(command.page_id(), index);
            }
        }
        commands
            .iter()
            .enumerate()
            .filter(|(index, command)| match last_ingest.get(command.page_id()) {
                Some(&last) => *index >= last,
                None => true,
            })
            .map(|(_, command)| command.clone())
            .collect()
    }

    /// Atomically replace the log's contents with `commands` (JSON-lines).
    /// Writes a sibling temp file then renames, so a crash mid-write can never
    /// truncate the durable log to a partial state — the rename either fully
    /// lands or the original log survives untouched.
    pub fn rewrite(&self, commands: &[MutationCommand]) -> std::io::Result<()> {
        let mut buf = String::new();
        for command in commands {
            let line = serde_json::to_string(command)
                .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
            buf.push_str(&line);
            buf.push('\n');
        }
        let tmp = self.path.with_extension("jsonl.compacting");
        std::fs::write(&tmp, buf)?;
        std::fs::rename(&tmp, &self.path)
    }
}

#[cfg(test)]
mod compaction_tests {
    use super::*;

    fn ingest(page: &str, text: &str) -> MutationCommand {
        MutationCommand::IngestDocument {
            page_id: page.to_string(),
            format: 0,
            text: text.to_string(),
        }
    }

    fn insert(page: &str, block: &str) -> MutationCommand {
        MutationCommand::InsertBlock {
            page_id: page.to_string(),
            block_id: block.to_string(),
            parent_id: None,
            index: 0,
            content: "x".to_string(),
        }
    }

    #[test]
    fn empty_log_compacts_to_empty() {
        assert!(OpLog::compact(&[]).is_empty());
    }

    #[test]
    fn repeated_ingests_collapse_to_the_last() {
        let log = vec![ingest("A", "v1"), ingest("A", "v2"), ingest("A", "v3")];
        let compacted = OpLog::compact(&log);
        assert_eq!(compacted, vec![ingest("A", "v3")]);
    }

    #[test]
    fn pre_ingest_mutations_are_dropped() {
        // An insert recorded before the page's ingest is discarded by replace_page.
        let log = vec![insert("A", "b1"), ingest("A", "v1")];
        assert_eq!(OpLog::compact(&log), vec![ingest("A", "v1")]);
    }

    #[test]
    fn post_ingest_mutations_are_kept_in_order() {
        let log = vec![ingest("A", "v1"), insert("A", "b1"), insert("A", "b2")];
        assert_eq!(OpLog::compact(&log), log);
    }

    #[test]
    fn compaction_is_independent_per_page() {
        // Interleaved pages: A's first ingest is superseded; B is untouched.
        let log = vec![ingest("A", "v1"), ingest("B", "v1"), ingest("A", "v2")];
        assert_eq!(
            OpLog::compact(&log),
            vec![ingest("B", "v1"), ingest("A", "v2")]
        );
    }

    #[test]
    fn pages_without_an_ingest_keep_all_commands() {
        // No reset point → cannot safely drop anything for that page.
        let log = vec![insert("A", "b1"), insert("A", "b2")];
        assert_eq!(OpLog::compact(&log), log);
    }

    #[test]
    fn compaction_is_idempotent() {
        let log = vec![ingest("A", "v1"), ingest("A", "v2"), ingest("B", "v1")];
        let once = OpLog::compact(&log);
        let twice = OpLog::compact(&once);
        assert_eq!(once, twice);
    }

    #[test]
    fn rewrite_then_read_all_round_trips_compacted_log() {
        let dir = std::env::temp_dir();
        let path = dir.join(format!("epistemos-kc-compact-{}.jsonl", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let log = vec![ingest("A", "v1"), ingest("A", "v2")];
        let oplog = OpLog::new(&path);
        for cmd in &log {
            oplog.append(cmd).expect("append");
        }
        let compacted = OpLog::compact(&OpLog::read_all(&path));
        oplog.rewrite(&compacted).expect("rewrite");
        assert_eq!(OpLog::read_all(&path), vec![ingest("A", "v2")]);
        let _ = std::fs::remove_file(&path);
    }
}
