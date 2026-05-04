//! Plan §11 Phase 12.5 — Skill discovery.
//!
//! When the agent successfully completes a multi-tool composition
//! (`meta.compose`), the runtime checks three conditions:
//!
//! 1. Was this composition novel (no existing skill matches by
//!    tool-sequence-hash)?
//! 2. Did it succeed within latency budget?
//! 3. Did the user accept the result (no ⌘Z within 5 minutes)?
//!
//! If all three, draft a `.skill.json` + `.skill.md` pair into
//! `agent_core/data/proposed_skills/`. A weekly NightBrain digest
//! surfaces these in the review queue: "You've done X 4 times this
//! week. Save as a skill?"
//!
//! Per FINAL_SYNTHESIS §6 Wave 8 deliberation: this is the
//! progressive-disclosure replacement for Voyager-style autonomy.
//! Every promotion is user-confirmed; nothing silent.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::Duration;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use thiserror::Error;

/// Default budget per Phase 12.5: composition succeeds within
/// "latency budget" — interpret as the 7B p95 from §6.4 (~1500ms
/// per call * 4 calls = 6 seconds for a typical composition).
pub const DEFAULT_LATENCY_BUDGET: Duration = Duration::from_millis(8_000);

/// Plan §8.5 routine-Effect undo window. Phase 12.5 says "no ⌘Z
/// within 5 minutes" — we widen to the full 24h §8.5 window so a
/// user who undoes hours later still tombstones the proposal.
pub const DEFAULT_USER_REJECT_WINDOW: Duration = Duration::from_secs(24 * 60 * 60);

/// Default frequency threshold per the §11 Phase 12.5 NightBrain
/// digest copy ("You've done X 4 times this week"). Below this, the
/// drafted proposal sits but isn't surfaced.
pub const DEFAULT_FREQUENCY_THRESHOLD: u32 = 4;

#[derive(Debug, Error)]
pub enum SkillDiscoveryError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("serialize error: {0}")]
    Serialize(String),
}

/// One observed multi-tool composition. The runtime records this
/// after every successful `meta.compose`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct CompositionTrace {
    /// ULID for the composition.
    pub composition_id: String,
    pub ts: DateTime<Utc>,
    /// Ordered list of dotted tool names invoked.
    pub tool_sequence: Vec<String>,
    /// Total wall time across all calls.
    pub total_duration_ms: u32,
    /// Inferred goal from the user's prompt — e.g. "summarize-recent-research".
    /// Used to name the proposed skill file. Must be slug-safe.
    pub inferred_goal: String,
    /// Was the result accepted (no undo within window)?
    pub user_accepted: bool,
}

impl CompositionTrace {
    /// Compute the canonical sequence hash. Two compositions with the
    /// same tool order produce the same hash; argument values are
    /// excluded so semantically-equivalent runs collapse together.
    pub fn sequence_hash(&self) -> String {
        let mut h = Sha256::new();
        for (i, tool) in self.tool_sequence.iter().enumerate() {
            h.update((i as u32).to_le_bytes());
            h.update(tool.as_bytes());
            h.update(b"\0");
        }
        format!("{:x}", h.finalize())
    }
}

/// Decision the discovery engine produces for a given trace.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum DiscoveryOutcome {
    /// Drafted a proposed skill at `path`.
    Drafted { path: PathBuf },
    /// Trace already matches an existing skill — not novel.
    NotNovel,
    /// Composition exceeded the latency budget.
    OverBudget {
        actual_ms: u32,
        budget_ms: u32,
    },
    /// User rejected the result (⌘Z within window).
    UserRejected,
    /// Frequency below the surfacing threshold; tracked but no
    /// digest entry yet.
    BelowFrequencyThreshold {
        seen: u32,
        threshold: u32,
    },
}

/// In-memory tracker. Production should persist this to a SQLite
/// table alongside heal_events / undo_events; for the scaffold the
/// in-memory state plus on-disk proposed_skills/ is sufficient.
pub struct SkillDiscovery {
    proposed_dir: PathBuf,
    existing_sequence_hashes: HashMap<String, String>, // hash → existing skill name
    sequence_counts: HashMap<String, u32>,             // hash → frequency
    latency_budget: Duration,
    frequency_threshold: u32,
}

impl SkillDiscovery {
    /// Build a fresh discovery engine. `agent_core_data_dir` is the
    /// base directory that contains `proposed_skills/` (canonical:
    /// `agent_core/data/`).
    pub fn new(agent_core_data_dir: impl Into<PathBuf>) -> Self {
        let dir = agent_core_data_dir.into().join("proposed_skills");
        Self {
            proposed_dir: dir,
            existing_sequence_hashes: HashMap::new(),
            sequence_counts: HashMap::new(),
            latency_budget: DEFAULT_LATENCY_BUDGET,
            frequency_threshold: DEFAULT_FREQUENCY_THRESHOLD,
        }
    }

    pub fn with_latency_budget(mut self, b: Duration) -> Self {
        self.latency_budget = b;
        self
    }

    pub fn with_frequency_threshold(mut self, n: u32) -> Self {
        self.frequency_threshold = n;
        self
    }

    /// Register an existing skill so subsequent traces matching its
    /// tool-sequence hash get classified `NotNovel`.
    pub fn register_existing_skill(&mut self, skill_name: &str, tool_sequence: &[String]) {
        let trace = CompositionTrace {
            composition_id: String::new(),
            ts: Utc::now(),
            tool_sequence: tool_sequence.to_vec(),
            total_duration_ms: 0,
            inferred_goal: String::new(),
            user_accepted: true,
        };
        self.existing_sequence_hashes
            .insert(trace.sequence_hash(), skill_name.to_string());
    }

    /// Process one observed composition. Increments the per-sequence
    /// counter, applies the §11 Phase 12.5 gates, drafts a proposal
    /// when all three pass + frequency threshold met.
    pub fn observe(
        &mut self,
        trace: &CompositionTrace,
    ) -> Result<DiscoveryOutcome, SkillDiscoveryError> {
        let hash = trace.sequence_hash();

        // Gate 1: novelty — does an existing skill cover this?
        if self.existing_sequence_hashes.contains_key(&hash) {
            return Ok(DiscoveryOutcome::NotNovel);
        }

        // Gate 2: latency budget.
        let budget_ms = self.latency_budget.as_millis() as u32;
        if trace.total_duration_ms > budget_ms {
            return Ok(DiscoveryOutcome::OverBudget {
                actual_ms: trace.total_duration_ms,
                budget_ms,
            });
        }

        // Gate 3: user acceptance (no ⌘Z within window).
        if !trace.user_accepted {
            return Ok(DiscoveryOutcome::UserRejected);
        }

        // Gate 4 (frequency): track but only surface ≥ threshold.
        let count = self.sequence_counts.entry(hash.clone()).or_insert(0);
        *count += 1;
        let seen = *count;
        if seen < self.frequency_threshold {
            return Ok(DiscoveryOutcome::BelowFrequencyThreshold {
                seen,
                threshold: self.frequency_threshold,
            });
        }

        // All gates pass: draft the .skill.json + .skill.md pair.
        std::fs::create_dir_all(&self.proposed_dir)?;
        let slug = slugify(&trace.inferred_goal);
        let stem = if slug.is_empty() {
            format!("composition-{}", &hash[..12])
        } else {
            format!("{slug}-{}", &hash[..8])
        };
        let json_path = self.proposed_dir.join(format!("{stem}.skill.json"));
        let md_path = self.proposed_dir.join(format!("{stem}.skill.md"));

        let proposal_json = serde_json::json!({
            "$schema": "epistemos://schemas/skill.v1.json",
            "name": slug,
            "version": "0.1.0",
            "inferred_goal": trace.inferred_goal,
            "tool_sequence": trace.tool_sequence,
            "sequence_hash": hash,
            "observed_count": seen,
            "median_duration_ms": trace.total_duration_ms,
            "drafted_at": trace.ts.to_rfc3339(),
            "status": "proposed",
        });
        let json_bytes = serde_json::to_vec_pretty(&proposal_json)
            .map_err(|e| SkillDiscoveryError::Serialize(e.to_string()))?;
        crate::util::atomic_write_bytes(&json_path, &json_bytes)?;

        let md_body = format!(
            "# Proposed skill: `{slug}`\n\
             \n\
             > You've done this {seen} times. Save as a skill?\n\
             \n\
             ## Inferred goal\n\
             {goal}\n\
             \n\
             ## Tool sequence\n\
             {seq}\n\
             \n\
             ## Provenance\n\
             - sequence_hash: `{hash}`\n\
             - last seen: {ts}\n\
             - status: proposed (user must confirm)\n",
            slug = slug,
            seen = seen,
            goal = if trace.inferred_goal.is_empty() {
                "(none recorded)"
            } else {
                trace.inferred_goal.as_str()
            },
            seq = trace
                .tool_sequence
                .iter()
                .enumerate()
                .map(|(i, t)| format!("{}. `{}`", i + 1, t))
                .collect::<Vec<_>>()
                .join("\n"),
            hash = hash,
            ts = trace.ts.to_rfc3339()
        );
        crate::util::atomic_write_bytes(&md_path, md_body.as_bytes())?;

        Ok(DiscoveryOutcome::Drafted { path: json_path })
    }

    pub fn proposed_dir(&self) -> &Path {
        &self.proposed_dir
    }
}

fn slugify(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut last_was_dash = false;
    for ch in s.chars() {
        match ch {
            'a'..='z' | '0'..='9' => {
                out.push(ch);
                last_was_dash = false;
            }
            'A'..='Z' => {
                out.push(ch.to_ascii_lowercase());
                last_was_dash = false;
            }
            ' ' | '_' | '-' => {
                if !last_was_dash && !out.is_empty() {
                    out.push('-');
                    last_was_dash = true;
                }
            }
            _ => {
                // skip; never persist non-ascii in filenames
            }
        }
    }
    if out.ends_with('-') {
        out.pop();
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn fresh() -> (TempDir, SkillDiscovery) {
        let tmp = TempDir::new().expect("tempdir");
        let d = SkillDiscovery::new(tmp.path()).with_frequency_threshold(1);
        (tmp, d)
    }

    fn trace(seq: &[&str], duration_ms: u32, accepted: bool) -> CompositionTrace {
        CompositionTrace {
            composition_id: ulid::Ulid::new().to_string(),
            ts: Utc::now(),
            tool_sequence: seq.iter().map(|s| s.to_string()).collect(),
            total_duration_ms: duration_ms,
            inferred_goal: "summarize recent research".to_string(),
            user_accepted: accepted,
        }
    }

    #[test]
    fn sequence_hash_is_order_dependent() {
        let a = trace(&["vault.search", "knowledge.recall", "reason.think"], 0, true);
        let b = trace(&["vault.search", "knowledge.recall", "reason.think"], 0, true);
        assert_eq!(a.sequence_hash(), b.sequence_hash());
        let c = trace(&["knowledge.recall", "vault.search", "reason.think"], 0, true);
        assert_ne!(a.sequence_hash(), c.sequence_hash());
    }

    #[test]
    fn novel_composition_drafts_skill_file() {
        let (tmp, mut d) = fresh();
        let t = trace(&["vault.search", "reason.think"], 1500, true);
        let outcome = d.observe(&t).unwrap();
        match outcome {
            DiscoveryOutcome::Drafted { path } => {
                assert!(path.is_file());
                assert!(path.starts_with(tmp.path().join("proposed_skills")));
                let json: serde_json::Value =
                    serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
                assert_eq!(json["status"], "proposed");
                assert_eq!(
                    json["tool_sequence"],
                    serde_json::json!(["vault.search", "reason.think"])
                );
                let md_path = path.with_extension("md");
                let md_path = md_path
                    .with_file_name(
                        path.file_stem().unwrap().to_string_lossy().to_string() + ".md",
                    );
                assert!(md_path.is_file(), "expected .skill.md companion at {md_path:?}");
            }
            other => panic!("expected Drafted, got {other:?}"),
        }
    }

    #[test]
    fn duplicate_of_existing_skill_classifies_not_novel() {
        let (_tmp, mut d) = fresh();
        d.register_existing_skill(
            "summarize-research",
            &[
                "vault.search".to_string(),
                "reason.think".to_string(),
            ],
        );
        let t = trace(&["vault.search", "reason.think"], 1500, true);
        assert_eq!(d.observe(&t).unwrap(), DiscoveryOutcome::NotNovel);
    }

    #[test]
    fn over_budget_composition_blocks_proposal() {
        let (_tmp, mut d) = fresh();
        let t = trace(&["x.y"], 999_999, true);
        match d.observe(&t).unwrap() {
            DiscoveryOutcome::OverBudget { actual_ms, .. } => {
                assert_eq!(actual_ms, 999_999);
            }
            other => panic!("expected OverBudget, got {other:?}"),
        }
    }

    #[test]
    fn user_rejected_composition_blocks_proposal() {
        let (_tmp, mut d) = fresh();
        let t = trace(&["x.y"], 100, false);
        assert_eq!(d.observe(&t).unwrap(), DiscoveryOutcome::UserRejected);
    }

    #[test]
    fn frequency_below_threshold_does_not_draft() {
        let tmp = TempDir::new().unwrap();
        let mut d = SkillDiscovery::new(tmp.path()).with_frequency_threshold(4);
        let t = trace(&["x.y"], 100, true);
        // First 3 occurrences below threshold
        for expected_count in 1..=3 {
            match d.observe(&t).unwrap() {
                DiscoveryOutcome::BelowFrequencyThreshold { seen, threshold } => {
                    assert_eq!(seen, expected_count);
                    assert_eq!(threshold, 4);
                }
                other => panic!("expected BelowFrequencyThreshold, got {other:?}"),
            }
        }
        // 4th occurrence drafts
        match d.observe(&t).unwrap() {
            DiscoveryOutcome::Drafted { .. } => {}
            other => panic!("expected Drafted, got {other:?}"),
        }
    }

    #[test]
    fn slugify_handles_messy_inputs() {
        assert_eq!(slugify("Summarize Recent Research"), "summarize-recent-research");
        assert_eq!(slugify("foo_bar  baz"), "foo-bar-baz");
        assert_eq!(slugify("---trim---"), "trim");
        assert_eq!(slugify(""), "");
        assert_eq!(slugify("noasciι"), "noasci"); // strips non-ASCII
    }

    #[test]
    fn drafted_filename_uses_slugified_goal() {
        let (tmp, mut d) = fresh();
        let mut t = trace(&["a.b"], 100, true);
        t.inferred_goal = "Foo Bar Baz".to_string();
        let outcome = d.observe(&t).unwrap();
        match outcome {
            DiscoveryOutcome::Drafted { path } => {
                let name = path.file_name().unwrap().to_string_lossy().to_string();
                assert!(name.starts_with("foo-bar-baz-"));
                assert!(name.ends_with(".skill.json"));
                assert!(path.starts_with(tmp.path().join("proposed_skills")));
            }
            other => panic!("expected Drafted, got {other:?}"),
        }
    }
}
