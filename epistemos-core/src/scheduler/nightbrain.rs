// NightBrain — Overnight deep research on flagged notes.
//
// When the user flags notes for research (e.g., via tag "#research" or a UI toggle),
// NightBrain schedules an overnight agent session to:
//   1. Expand each flagged note with deeper analysis
//   2. Cross-reference related notes in the vault
//   3. Generate a morning summary digest
//
// NightBrain is evaluated on the same schedule tick as training (every 30 minutes).
// It runs during the night window (1-5 AM), only when plugged in.
//
// The output is a structured ResearchPlan (what to research) and a MorningSummary
// (what was found). The actual research execution happens in Swift/agent layer;
// this module only manages scheduling and summary generation.

use serde::{Deserialize, Serialize};

/// A note flagged for overnight research.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlaggedNote {
    /// Unique note identifier.
    pub note_id: String,
    /// Note title or first heading.
    pub title: String,
    /// The text content (or excerpt) to research.
    pub excerpt: String,
    /// Optional research directive from the user.
    pub directive: String,
    /// When the note was flagged (ISO 8601).
    pub flagged_at: String,
}

/// A plan for overnight research.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchPlan {
    /// Notes to research, ordered by priority.
    pub notes: Vec<ResearchTask>,
    /// Estimated total research time in minutes.
    pub estimated_minutes: u32,
    /// Whether the plan was approved (auto-approve for <= 5 notes).
    pub auto_approved: bool,
}

/// A single research task within a plan.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchTask {
    pub note_id: String,
    pub title: String,
    pub research_queries: Vec<String>,
    pub cross_reference_ids: Vec<String>,
    pub priority: u32,
}

/// Result of a completed overnight research session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MorningSummary {
    /// When the research started.
    pub started_at: String,
    /// When the research finished.
    pub finished_at: String,
    /// Per-note research results.
    pub results: Vec<NoteResearchResult>,
    /// Overall summary text for the morning digest.
    pub digest: String,
    /// Total notes researched.
    pub notes_researched: u32,
    /// Total new connections discovered.
    pub connections_found: u32,
}

/// Research result for a single note.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoteResearchResult {
    pub note_id: String,
    pub title: String,
    /// Key findings from the research.
    pub findings: Vec<String>,
    /// IDs of related notes discovered.
    pub related_notes: Vec<String>,
    /// Suggested expansions or follow-up questions.
    pub suggestions: Vec<String>,
}

/// NightBrain scheduling decision.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NightBrainDecision {
    pub should_run: bool,
    pub reason: String,
    pub flagged_count: u32,
}

/// Evaluate whether NightBrain should run now.
pub fn evaluate_nightbrain(
    flagged_count: usize,
    current_hour: u32,
    is_on_battery: bool,
    is_agent_running: bool,
    last_run_hours_ago: u32,
) -> NightBrainDecision {
    if flagged_count == 0 {
        return NightBrainDecision {
            should_run: false,
            reason: "No flagged notes".into(),
            flagged_count: 0,
        };
    }

    if is_on_battery {
        return NightBrainDecision {
            should_run: false,
            reason: "On battery — deferred".into(),
            flagged_count: flagged_count as u32,
        };
    }

    if is_agent_running {
        return NightBrainDecision {
            should_run: false,
            reason: "Agent already running".into(),
            flagged_count: flagged_count as u32,
        };
    }

    // Run during night window (1-5 AM) if at least 12 hours since last run
    let in_window = (1..=5).contains(&current_hour);
    let enough_time = last_run_hours_ago >= 12;

    if in_window && enough_time {
        NightBrainDecision {
            should_run: true,
            reason: format!("{flagged_count} flagged notes, {last_run_hours_ago}h since last run"),
            flagged_count: flagged_count as u32,
        }
    } else if in_window {
        NightBrainDecision {
            should_run: false,
            reason: format!("Too soon — only {last_run_hours_ago}h since last run (need 12h)"),
            flagged_count: flagged_count as u32,
        }
    } else {
        NightBrainDecision {
            should_run: false,
            reason: format!("Outside night window (current hour: {current_hour})"),
            flagged_count: flagged_count as u32,
        }
    }
}

/// Build a research plan from flagged notes.
pub fn build_research_plan(
    flagged_notes: &[FlaggedNote],
    vault_note_ids: &[String],
) -> ResearchPlan {
    let mut tasks: Vec<ResearchTask> = flagged_notes
        .iter()
        .enumerate()
        .map(|(i, note)| {
            let queries = derive_research_queries(&note.title, &note.excerpt, &note.directive);
            let cross_refs = find_cross_references(&note.excerpt, vault_note_ids);
            ResearchTask {
                note_id: note.note_id.clone(),
                title: note.title.clone(),
                research_queries: queries,
                cross_reference_ids: cross_refs,
                priority: i as u32 + 1,
            }
        })
        .collect();

    // Sort by priority (earlier flagged = higher priority)
    tasks.sort_by_key(|t| t.priority);

    let estimated_minutes = (tasks.len() as u32) * 5; // ~5 min per note
    let auto_approved = tasks.len() <= 5;

    ResearchPlan {
        notes: tasks,
        estimated_minutes,
        auto_approved,
    }
}

/// Generate a morning summary from research results.
pub fn generate_morning_summary(
    results: &[NoteResearchResult],
    started_at: &str,
    finished_at: &str,
) -> MorningSummary {
    let total_connections: usize = results.iter().map(|r| r.related_notes.len()).sum();

    let digest = if results.is_empty() {
        "No research results to summarize.".to_string()
    } else {
        let mut lines = Vec::new();
        lines.push(format!("Researched {} notes overnight.", results.len()));

        for result in results.iter().take(5) {
            if let Some(finding) = result.findings.first() {
                lines.push(format!("- {}: {}", result.title, finding));
            }
        }

        if results.len() > 5 {
            lines.push(format!("...and {} more notes.", results.len() - 5));
        }

        if total_connections > 0 {
            lines.push(format!(
                "Discovered {} new connections between notes.",
                total_connections
            ));
        }

        lines.join("\n")
    };

    MorningSummary {
        started_at: started_at.to_string(),
        finished_at: finished_at.to_string(),
        results: results.to_vec(),
        digest,
        notes_researched: results.len() as u32,
        connections_found: total_connections as u32,
    }
}

// ── Internal Helpers ────────────────────────────────────────────────────────

/// Derive research queries from note content and directive.
fn derive_research_queries(title: &str, excerpt: &str, directive: &str) -> Vec<String> {
    let mut queries = Vec::new();

    // If user gave a directive, use it as the primary query
    if !directive.is_empty() {
        queries.push(directive.to_string());
    }

    // Generate a query from the title
    if !title.is_empty() {
        queries.push(format!("expand on: {title}"));
    }

    // Extract key phrases from excerpt (simple approach: first sentence)
    if !excerpt.is_empty() {
        let first_sentence = excerpt
            .split(['.', '!', '?'])
            .next()
            .unwrap_or(excerpt)
            .trim();
        if first_sentence.len() > 10 && first_sentence.len() < 200 {
            queries.push(format!("related to: {first_sentence}"));
        }
    }

    queries
}

/// Find vault notes that might be related (simple keyword overlap).
fn find_cross_references(excerpt: &str, vault_note_ids: &[String]) -> Vec<String> {
    // Simple heuristic: return vault note IDs that share keywords with the excerpt.
    // In practice, this would use the instant recall index for semantic matching.
    // For now, return an empty list (cross-references are populated by the agent).
    let _ = (excerpt, vault_note_ids);
    Vec::new()
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_evaluate_no_flagged() {
        let d = evaluate_nightbrain(0, 3, false, false, 24);
        assert!(!d.should_run);
        assert!(d.reason.contains("No flagged"));
    }

    #[test]
    fn test_evaluate_on_battery() {
        let d = evaluate_nightbrain(5, 3, true, false, 24);
        assert!(!d.should_run);
        assert!(d.reason.contains("battery"));
    }

    #[test]
    fn test_evaluate_agent_running() {
        let d = evaluate_nightbrain(5, 3, false, true, 24);
        assert!(!d.should_run);
        assert!(d.reason.contains("already running"));
    }

    #[test]
    fn test_evaluate_outside_window() {
        let d = evaluate_nightbrain(5, 14, false, false, 24);
        assert!(!d.should_run);
        assert!(d.reason.contains("Outside night window"));
    }

    #[test]
    fn test_evaluate_too_soon() {
        let d = evaluate_nightbrain(5, 3, false, false, 6);
        assert!(!d.should_run);
        assert!(d.reason.contains("Too soon"));
    }

    #[test]
    fn test_evaluate_should_run() {
        let d = evaluate_nightbrain(5, 3, false, false, 24);
        assert!(d.should_run);
        assert_eq!(d.flagged_count, 5);
    }

    #[test]
    fn test_evaluate_boundary_hours() {
        // Hour 1 = in window
        assert!(evaluate_nightbrain(1, 1, false, false, 24).should_run);
        // Hour 5 = in window
        assert!(evaluate_nightbrain(1, 5, false, false, 24).should_run);
        // Hour 0 = out
        assert!(!evaluate_nightbrain(1, 0, false, false, 24).should_run);
        // Hour 6 = out
        assert!(!evaluate_nightbrain(1, 6, false, false, 24).should_run);
    }

    fn sample_flagged() -> Vec<FlaggedNote> {
        vec![
            FlaggedNote {
                note_id: "note-1".into(),
                title: "Quantum Computing Basics".into(),
                excerpt: "Quantum computing uses qubits that can exist in superposition.".into(),
                directive: "Find recent advances in quantum error correction".into(),
                flagged_at: "2026-03-29T10:00:00Z".into(),
            },
            FlaggedNote {
                note_id: "note-2".into(),
                title: "Rust Memory Safety".into(),
                excerpt: "Rust prevents data races at compile time through ownership.".into(),
                directive: String::new(),
                flagged_at: "2026-03-29T11:00:00Z".into(),
            },
        ]
    }

    #[test]
    fn test_build_research_plan() {
        let flagged = sample_flagged();
        let vault_ids: Vec<String> = vec![];
        let plan = build_research_plan(&flagged, &vault_ids);

        assert_eq!(plan.notes.len(), 2);
        assert!(plan.auto_approved); // <= 5 notes
        assert_eq!(plan.estimated_minutes, 10); // 2 * 5

        // First note should have directive as primary query
        assert!(plan.notes[0].research_queries[0].contains("quantum error correction"));
    }

    #[test]
    fn test_build_research_plan_auto_approve_threshold() {
        let mut flagged = Vec::new();
        for i in 0..6 {
            flagged.push(FlaggedNote {
                note_id: format!("note-{i}"),
                title: format!("Topic {i}"),
                excerpt: format!("Content about topic {i}"),
                directive: String::new(),
                flagged_at: "2026-03-29T10:00:00Z".into(),
            });
        }
        let plan = build_research_plan(&flagged, &[]);
        assert!(!plan.auto_approved); // > 5 notes
    }

    #[test]
    fn test_generate_morning_summary_empty() {
        let summary = generate_morning_summary(&[], "2026-03-29T01:00:00Z", "2026-03-29T01:00:00Z");
        assert_eq!(summary.notes_researched, 0);
        assert!(summary.digest.contains("No research results"));
    }

    #[test]
    fn test_generate_morning_summary_with_results() {
        let results = vec![
            NoteResearchResult {
                note_id: "note-1".into(),
                title: "Quantum Computing".into(),
                findings: vec!["Recent advances in error correction show promise".into()],
                related_notes: vec!["note-3".into(), "note-7".into()],
                suggestions: vec!["Explore topological qubits".into()],
            },
            NoteResearchResult {
                note_id: "note-2".into(),
                title: "Rust Safety".into(),
                findings: vec!["Ownership model prevents 70% of common CVEs".into()],
                related_notes: vec![],
                suggestions: vec![],
            },
        ];

        let summary =
            generate_morning_summary(&results, "2026-03-29T01:00:00Z", "2026-03-29T03:00:00Z");
        assert_eq!(summary.notes_researched, 2);
        assert_eq!(summary.connections_found, 2);
        assert!(summary.digest.contains("Researched 2 notes"));
        assert!(summary.digest.contains("Quantum Computing"));
    }

    #[test]
    fn test_derive_research_queries() {
        let queries = derive_research_queries(
            "Quantum Computing",
            "Qubits exist in superposition states.",
            "Find error correction methods",
        );
        assert!(queries.len() >= 2);
        assert!(queries[0].contains("error correction"));
        assert!(queries[1].contains("Quantum Computing"));
    }

    #[test]
    fn test_derive_research_queries_no_directive() {
        let queries = derive_research_queries("My Title", "Some excerpt text here.", "");
        assert!(!queries.is_empty());
        assert!(queries[0].contains("My Title"));
    }
}
