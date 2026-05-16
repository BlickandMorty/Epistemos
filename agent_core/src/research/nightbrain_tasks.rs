//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.13 — 6 NoOp NightBrain task bodies:
//!   `dedupe_artifacts` · `memory_distillation` ·
//!   `cloud_knowledge_distillation` (Pro) · `session_graph_generation` ·
//!   `skill_evolution_analysis` · `ssm_state_pruning`.
//! - Companion to `agent_core/src/nightbrain/live.rs` (NOT-B-OWNED per
//!   §2; current NoOp placeholders at line ~218 + dispatch at ~283).
//!
//! # Wave J B.6.13 — NightBrain task body substrates
//!
//! Each of the 6 named tasks gets:
//! - A canonical-name constant (matches the string in live.rs's
//!   `MASTER_TASK_NAMES`).
//! - A typed `TaskInput` + `TaskOutput` pair describing what the task
//!   consumes and emits.
//! - A `NightBrainTaskBody` trait impl that the future wire-in code
//!   wraps with the `NightBrainTask` trait from live.rs.
//!
//! Substrate floor implements the deterministic / pure-Rust portions
//! of each task. Production wiring (replacing the NoOpTask in
//! live.rs) is deferred — `live.rs` is NOT B-owned per §2, so
//! Terminal A or a future authorized iter does the wire-in.
//!
//! The 6 tasks are listed alphabetically to match the
//! `MASTER_TASK_NAMES` registry order in live.rs.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum NightBrainTaskKind {
    CloudKnowledgeDistillation,
    DedupeArtifacts,
    MemoryDistillation,
    SessionGraphGeneration,
    SkillEvolutionAnalysis,
    SsmStatePruning,
}

impl NightBrainTaskKind {
    pub const ALL: [NightBrainTaskKind; 6] = [
        NightBrainTaskKind::CloudKnowledgeDistillation,
        NightBrainTaskKind::DedupeArtifacts,
        NightBrainTaskKind::MemoryDistillation,
        NightBrainTaskKind::SessionGraphGeneration,
        NightBrainTaskKind::SkillEvolutionAnalysis,
        NightBrainTaskKind::SsmStatePruning,
    ];

    pub const fn canonical_name(self) -> &'static str {
        match self {
            NightBrainTaskKind::CloudKnowledgeDistillation => "cloud_knowledge_distillation",
            NightBrainTaskKind::DedupeArtifacts => "dedupe_artifacts",
            NightBrainTaskKind::MemoryDistillation => "memory_distillation",
            NightBrainTaskKind::SessionGraphGeneration => "session_graph_generation",
            NightBrainTaskKind::SkillEvolutionAnalysis => "skill_evolution_analysis",
            NightBrainTaskKind::SsmStatePruning => "ssm_state_pruning",
        }
    }

    /// Whether the task requires Pro entitlement to run.
    pub const fn requires_pro(self) -> bool {
        matches!(self, NightBrainTaskKind::CloudKnowledgeDistillation)
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TaskRunReport {
    pub kind: NightBrainTaskKind,
    pub items_processed: u32,
    pub items_dropped: u32,
    pub items_emitted: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TaskError {
    EmptyInput { kind: NightBrainTaskKind },
    ProEntitlementRequired { kind: NightBrainTaskKind },
}

/// Dedupe a list of artifact-ids by exact equality. Returns the
/// deduped list + the report. Substrate floor uses a HashSet for
/// O(n) dedupe; the trigram-similarity sibling
/// [`dedupe_artifacts_by_trigram_similarity`] is the near-duplicate
/// variant.
pub fn dedupe_artifacts(ids: &[String]) -> Result<(Vec<String>, TaskRunReport), TaskError> {
    if ids.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::DedupeArtifacts,
        });
    }
    let mut seen: std::collections::HashSet<String> = Default::default();
    let mut out = Vec::new();
    for id in ids {
        if seen.insert(id.clone()) {
            out.push(id.clone());
        }
    }
    let dropped = (ids.len() - out.len()) as u32;
    Ok((
        out.clone(),
        TaskRunReport {
            kind: NightBrainTaskKind::DedupeArtifacts,
            items_processed: ids.len() as u32,
            items_dropped: dropped,
            items_emitted: out.len() as u32,
        },
    ))
}

/// Extract the trigram (3-char sliding-window) set of a string. Empty
/// for inputs shorter than 3 chars (the trigram-similarity dedupe
/// falls back to exact-string equality for those — iter 85).
fn trigrams(s: &str) -> std::collections::HashSet<[char; 3]> {
    let chars: Vec<char> = s.chars().collect();
    let mut out = std::collections::HashSet::new();
    if chars.len() < 3 {
        return out;
    }
    for window in chars.windows(3) {
        out.insert([window[0], window[1], window[2]]);
    }
    out
}

/// Jaccard similarity of two trigram sets in `[0.0, 1.0]`.
/// `|A ∩ B| / |A ∪ B|`. Empty-set inputs return 0.0 (no overlap to
/// measure). Identical inputs return 1.0.
fn trigram_jaccard(
    a: &std::collections::HashSet<[char; 3]>,
    b: &std::collections::HashSet<[char; 3]>,
) -> f64 {
    if a.is_empty() && b.is_empty() {
        return 0.0;
    }
    let inter = a.intersection(b).count();
    let union = a.union(b).count();
    if union == 0 {
        return 0.0;
    }
    inter as f64 / union as f64
}

/// Near-duplicate dedupe: walk inputs greedily, keep an item only if
/// its trigram-Jaccard similarity to every previously-kept item is
/// strictly below `threshold`. Strings shorter than 3 chars fall back
/// to exact-string equality (trigrams undefined). `threshold` must be
/// in `(0.0, 1.0]`; values outside that band return
/// `TaskError::EmptyInput` repurposed to keep the public error surface
/// minimal (this validation drift is documented in the test).
///
/// Production (true SimHash / MinHash) trades higher upfront cost for
/// constant-time set-membership; this O(n²) version is the substrate
/// floor — correct, deterministic, dependency-free.
pub fn dedupe_artifacts_by_trigram_similarity(
    ids: &[String],
    threshold: f64,
) -> Result<(Vec<String>, TaskRunReport), TaskError> {
    if ids.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::DedupeArtifacts,
        });
    }
    if !threshold.is_finite() || threshold <= 0.0 || threshold > 1.0 {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::DedupeArtifacts,
        });
    }
    let mut kept: Vec<(String, std::collections::HashSet<[char; 3]>)> = Vec::new();
    for id in ids {
        let tri = trigrams(id);
        let mut is_dup = false;
        for (existing_id, existing_tri) in &kept {
            if tri.is_empty() {
                if existing_id == id {
                    is_dup = true;
                    break;
                }
            } else if existing_tri.is_empty() {
                continue;
            } else if trigram_jaccard(&tri, existing_tri) >= threshold {
                is_dup = true;
                break;
            }
        }
        if !is_dup {
            kept.push((id.clone(), tri));
        }
    }
    let out: Vec<String> = kept.into_iter().map(|(s, _)| s).collect();
    let dropped = (ids.len() - out.len()) as u32;
    Ok((
        out.clone(),
        TaskRunReport {
            kind: NightBrainTaskKind::DedupeArtifacts,
            items_processed: ids.len() as u32,
            items_dropped: dropped,
            items_emitted: out.len() as u32,
        },
    ))
}

/// Distill a memory cluster: substrate-floor reduce step picks the
/// longest unique entry as the representative.
pub fn memory_distillation(entries: &[String]) -> Result<(String, TaskRunReport), TaskError> {
    if entries.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::MemoryDistillation,
        });
    }
    let representative = entries.iter().max_by_key(|e| e.len()).cloned().unwrap();
    Ok((
        representative,
        TaskRunReport {
            kind: NightBrainTaskKind::MemoryDistillation,
            items_processed: entries.len() as u32,
            items_dropped: (entries.len() - 1) as u32,
            items_emitted: 1,
        },
    ))
}

/// Pro-only: validate Pro entitlement, then no-op (the actual
/// cloud-distillation pipeline requires HTTP + provider keys, out of
/// substrate scope).
pub fn cloud_knowledge_distillation(has_pro: bool) -> Result<TaskRunReport, TaskError> {
    if !has_pro {
        return Err(TaskError::ProEntitlementRequired {
            kind: NightBrainTaskKind::CloudKnowledgeDistillation,
        });
    }
    Ok(TaskRunReport {
        kind: NightBrainTaskKind::CloudKnowledgeDistillation,
        items_processed: 0,
        items_dropped: 0,
        items_emitted: 0,
    })
}

/// Generate a session-graph node count from a list of session
/// summaries. Substrate floor returns `entries.len()` as the node
/// count; production adds edge inference from cross-session links.
pub fn session_graph_generation(entries: &[String]) -> Result<TaskRunReport, TaskError> {
    if entries.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::SessionGraphGeneration,
        });
    }
    Ok(TaskRunReport {
        kind: NightBrainTaskKind::SessionGraphGeneration,
        items_processed: entries.len() as u32,
        items_dropped: 0,
        items_emitted: entries.len() as u32,
    })
}

/// Analyze skill evolution: pure-stat reduce over skill invocation
/// counts. Substrate floor returns the highest-invocation skill +
/// total count.
pub fn skill_evolution_analysis(
    skills: &[(String, u32)],
) -> Result<(Option<String>, u32, TaskRunReport), TaskError> {
    if skills.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::SkillEvolutionAnalysis,
        });
    }
    let total: u32 = skills.iter().map(|(_, c)| *c).sum();
    let top = skills.iter().max_by_key(|(_, c)| *c).map(|(s, _)| s.clone());
    Ok((
        top,
        total,
        TaskRunReport {
            kind: NightBrainTaskKind::SkillEvolutionAnalysis,
            items_processed: skills.len() as u32,
            items_dropped: 0,
            items_emitted: 1,
        },
    ))
}

/// Prune SSM state by keeping only entries within `keep_window` of
/// the latest. Substrate floor uses timestamps; production may use
/// magnitude / decay-half-life instead.
pub fn ssm_state_pruning(
    state: &[(u64, f32)],
    keep_window: u64,
) -> Result<(Vec<(u64, f32)>, TaskRunReport), TaskError> {
    if state.is_empty() {
        return Err(TaskError::EmptyInput {
            kind: NightBrainTaskKind::SsmStatePruning,
        });
    }
    let latest = state.iter().map(|(t, _)| *t).max().unwrap();
    let kept: Vec<(u64, f32)> = state
        .iter()
        .filter(|(t, _)| latest.saturating_sub(*t) <= keep_window)
        .copied()
        .collect();
    let dropped = (state.len() - kept.len()) as u32;
    Ok((
        kept.clone(),
        TaskRunReport {
            kind: NightBrainTaskKind::SsmStatePruning,
            items_processed: state.len() as u32,
            items_dropped: dropped,
            items_emitted: kept.len() as u32,
        },
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_distinct_task_kinds() {
        let s: std::collections::HashSet<_> =
            NightBrainTaskKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 6);
    }

    #[test]
    fn only_cloud_distillation_requires_pro() {
        for &k in &NightBrainTaskKind::ALL {
            let expected =
                k == NightBrainTaskKind::CloudKnowledgeDistillation;
            assert_eq!(k.requires_pro(), expected);
        }
    }

    #[test]
    fn canonical_names_match_master_registry() {
        assert_eq!(NightBrainTaskKind::DedupeArtifacts.canonical_name(), "dedupe_artifacts");
        assert_eq!(NightBrainTaskKind::MemoryDistillation.canonical_name(), "memory_distillation");
        assert_eq!(NightBrainTaskKind::CloudKnowledgeDistillation.canonical_name(), "cloud_knowledge_distillation");
        assert_eq!(NightBrainTaskKind::SessionGraphGeneration.canonical_name(), "session_graph_generation");
        assert_eq!(NightBrainTaskKind::SkillEvolutionAnalysis.canonical_name(), "skill_evolution_analysis");
        assert_eq!(NightBrainTaskKind::SsmStatePruning.canonical_name(), "ssm_state_pruning");
    }

    #[test]
    fn dedupe_removes_duplicates() {
        let ids = vec!["a".into(), "b".into(), "a".into(), "c".into(), "b".into()];
        let (out, r) = dedupe_artifacts(&ids).unwrap();
        assert_eq!(out, vec!["a", "b", "c"]);
        assert_eq!(r.items_processed, 5);
        assert_eq!(r.items_dropped, 2);
        assert_eq!(r.items_emitted, 3);
    }

    #[test]
    fn dedupe_empty_errors() {
        let err = dedupe_artifacts(&[]).unwrap_err();
        assert_eq!(
            err,
            TaskError::EmptyInput { kind: NightBrainTaskKind::DedupeArtifacts }
        );
    }

    #[test]
    fn memory_distillation_picks_longest() {
        let entries = vec!["short".into(), "much longer entry".into(), "mid".into()];
        let (rep, r) = memory_distillation(&entries).unwrap();
        assert_eq!(rep, "much longer entry");
        assert_eq!(r.items_emitted, 1);
        assert_eq!(r.items_dropped, 2);
    }

    #[test]
    fn cloud_distillation_requires_pro_flag() {
        let err = cloud_knowledge_distillation(false).unwrap_err();
        assert_eq!(
            err,
            TaskError::ProEntitlementRequired { kind: NightBrainTaskKind::CloudKnowledgeDistillation }
        );
        assert!(cloud_knowledge_distillation(true).is_ok());
    }

    #[test]
    fn session_graph_node_count_matches_input() {
        let entries = vec!["s1".into(), "s2".into(), "s3".into()];
        let r = session_graph_generation(&entries).unwrap();
        assert_eq!(r.items_emitted, 3);
    }

    #[test]
    fn skill_evolution_picks_top() {
        let skills = vec![
            ("query".into(), 5_u32),
            ("write".into(), 12_u32),
            ("read".into(), 3_u32),
        ];
        let (top, total, _) = skill_evolution_analysis(&skills).unwrap();
        assert_eq!(top.as_deref(), Some("write"));
        assert_eq!(total, 20);
    }

    #[test]
    fn ssm_state_pruning_keeps_within_window() {
        // latest = 1000, window = 100 → keep [900..=1000]
        let state = vec![(500, 0.1), (900, 0.2), (1000, 0.3), (200, 0.05)];
        let (kept, r) = ssm_state_pruning(&state, 100).unwrap();
        assert_eq!(kept.len(), 2);
        assert!(kept.iter().all(|(t, _)| *t >= 900));
        assert_eq!(r.items_dropped, 2);
    }

    #[test]
    fn ssm_state_pruning_empty_errors() {
        let err = ssm_state_pruning(&[], 100).unwrap_err();
        assert_eq!(
            err,
            TaskError::EmptyInput { kind: NightBrainTaskKind::SsmStatePruning }
        );
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let r = TaskRunReport {
            kind: NightBrainTaskKind::DedupeArtifacts,
            items_processed: 10,
            items_dropped: 3,
            items_emitted: 7,
        };
        let json = serde_json::to_string(&r).unwrap();
        let back: TaskRunReport = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn all_kinds_have_distinct_canonical_names() {
        let names: std::collections::HashSet<&'static str> = NightBrainTaskKind::ALL
            .iter()
            .map(|k| k.canonical_name())
            .collect();
        assert_eq!(names.len(), 6);
    }

    #[test]
    fn dedupe_preserves_first_occurrence_order() {
        let ids = vec!["c".into(), "a".into(), "b".into(), "a".into(), "c".into()];
        let (out, _) = dedupe_artifacts(&ids).unwrap();
        assert_eq!(out, vec!["c", "a", "b"]);
    }

    #[test]
    fn ssm_pruning_window_zero_keeps_only_latest() {
        let state = vec![(500, 0.1), (1000, 0.3)];
        let (kept, _) = ssm_state_pruning(&state, 0).unwrap();
        assert_eq!(kept, vec![(1000, 0.3)]);
    }

    // ── Trigram-similarity dedupe tests (iter 85) ───────────────────────────

    fn ids(s: &[&str]) -> Vec<String> {
        s.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn trigram_dedupe_drops_near_duplicates() {
        // "hello world" and "hello worlds" share many trigrams.
        let inp = ids(&["hello world", "hello worlds", "goodbye world"]);
        let (out, rep) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap();
        assert!(out.len() < inp.len());
        assert_eq!(rep.items_processed, 3);
    }

    #[test]
    fn trigram_dedupe_keeps_dissimilar() {
        let inp = ids(&["alpha bravo", "charlie delta", "echo foxtrot"]);
        let (out, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap();
        assert_eq!(out.len(), 3);
    }

    #[test]
    fn trigram_dedupe_threshold_one_only_drops_exact() {
        // Threshold 1.0 means trigram sets must be IDENTICAL.
        let inp = ids(&["hello world", "hello world", "hello world!"]);
        let (out, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 1.0).unwrap();
        // First and second have identical trigrams; third differs by '!'.
        assert_eq!(out.len(), 2);
    }

    #[test]
    fn trigram_dedupe_short_strings_use_exact_equality() {
        // Strings shorter than 3 chars have empty trigram set and fall
        // back to exact-string equality.
        let inp = ids(&["a", "a", "b", "bc"]);
        let (out, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap();
        assert_eq!(out, vec!["a".to_string(), "b".to_string(), "bc".to_string()]);
    }

    #[test]
    fn trigram_dedupe_empty_rejected() {
        let inp: Vec<String> = vec![];
        assert!(matches!(
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap_err(),
            TaskError::EmptyInput { .. }
        ));
    }

    #[test]
    fn trigram_dedupe_invalid_threshold_rejected() {
        let inp = ids(&["x"]);
        assert!(dedupe_artifacts_by_trigram_similarity(&inp, 0.0).is_err());
        assert!(dedupe_artifacts_by_trigram_similarity(&inp, -0.1).is_err());
        assert!(dedupe_artifacts_by_trigram_similarity(&inp, 1.5).is_err());
        assert!(dedupe_artifacts_by_trigram_similarity(&inp, f64::NAN).is_err());
    }

    #[test]
    fn trigram_dedupe_single_input_kept() {
        let inp = ids(&["only one"]);
        let (out, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap();
        assert_eq!(out, ids(&["only one"]));
    }

    #[test]
    fn trigram_dedupe_preserves_first_occurrence_order() {
        let inp = ids(&["zulu", "yankee", "xray", "zulu"]);
        let (out, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.5).unwrap();
        assert_eq!(out[0], "zulu");
        assert_eq!(out[1], "yankee");
        assert_eq!(out[2], "xray");
    }

    #[test]
    fn trigram_dedupe_high_threshold_keeps_more() {
        // High threshold = stricter "must be very similar" rule → fewer
        // drops, more kept.
        let inp = ids(&["hello world", "hello worlds", "hello worldz"]);
        let (out_low, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.3).unwrap();
        let (out_high, _) =
            dedupe_artifacts_by_trigram_similarity(&inp, 0.99).unwrap();
        assert!(out_low.len() <= out_high.len());
    }
}
