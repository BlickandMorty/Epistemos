//! DeerFlow slice 4 — the REPORTER (the lead's final synthesis).
//!
//! Pure + testable: assemble the sub-agent [`SubResult`]s into a synthesis
//! objective for a final lead turn, where every claim must cite the
//! sub-question id `[id]` it rests on — a closed-citation contract over the
//! findings (a claim with no `[id]` has no evidence). The live synthesis run
//! reuses the agent_core loop (PRO-gated, like the researcher).
//!
//! Still inert: the live run is constructed only by the future deep-research
//! wiring slice behind EPISTEMOS_DEEP_RESEARCH_V0.

use super::{ResearchPlan, SubResult};

/// Format the sub-agent findings into a readable, cited digest — one section per
/// result, headed by its sub-question id + question so the synthesis can cite
/// `[id]`. Results with no matching plan question still appear (id + findings).
pub fn findings_digest(plan: &ResearchPlan, results: &[SubResult]) -> String {
    results
        .iter()
        .map(|r| {
            let question = plan
                .sub_questions
                .iter()
                .find(|sq| sq.id == r.id)
                .map(|sq| sq.question.as_str())
                .unwrap_or("(no matching sub-question)");
            format!("## [{}] {}\n{}", r.id, question, r.findings)
        })
        .collect::<Vec<_>>()
        .join("\n\n")
}

/// Build the lead synthesis objective: synthesize the findings into a single
/// coherent answer to the original objective, grounding every claim in a cited
/// `[id]`. Regular (non-raw) string — `\` line-continuations are processed here.
pub fn synthesis_objective(plan: &ResearchPlan, results: &[SubResult]) -> String {
    format!(
        "Synthesize the research findings below into a single coherent, \
well-structured answer to the OBJECTIVE. Ground EVERY claim in the findings and \
cite the sub-question id in square brackets [like-this] for each claim. Do NOT \
introduce facts the findings do not support; if the findings are insufficient \
for part of the objective, say so plainly.\n\nOBJECTIVE: {objective}\n\nFINDINGS:\n{digest}",
        objective = plan.objective,
        digest = findings_digest(plan, results),
    )
}

/// System prompt for the synthesis (reporter) lead turn.
#[cfg(feature = "pro-build")]
const SYNTHESIS_SYSTEM_PROMPT: &str = "You are the lead reporter of a multi-agent deep-research run. Synthesize the sub-agents' findings into one coherent, well-cited answer. Cite every claim with its sub-question id [id]. Never invent facts beyond the findings; surface gaps honestly.";

#[cfg(feature = "pro-build")]
const SYNTHESIS_MAX_OUTPUT_TOKENS: u32 = 8192;

/// Run the live synthesis: a final lead agent_core turn over the findings, no
/// new web research (it reasons over what the sub-agents found). Returns the
/// synthesized report, or an honest "[synthesis failed: ...]" on loop error.
/// PRO-gated (reuses the cloud sub-agent loop, like the researcher).
#[cfg(feature = "pro-build")]
pub async fn run_synthesis(
    plan: &ResearchPlan,
    results: &[SubResult],
    provider: std::sync::Arc<dyn crate::provider::AgentProvider>,
    tool_registry: std::sync::Arc<crate::tools::registry::ToolRegistry>,
    max_turns: u32,
) -> String {
    use crate::agent_loop::{run_agent_loop, AgentConfig, Effort};

    let objective = synthesis_objective(plan, results);
    let config = AgentConfig {
        system_prompt: Some(SYNTHESIS_SYSTEM_PROMPT.to_string()),
        max_turns: Some(max_turns.max(1)),
        max_output_tokens: Some(SYNTHESIS_MAX_OUTPUT_TOKENS),
        effort: Effort::High,
        // Synthesis reasons over the sub-agents' findings — it does not start a
        // fresh web crawl. (The sub-agents already did the searching.)
        enable_web_search: false,
        enable_web_fetch: false,
        enable_computer_use: false,
        ..AgentConfig::default()
    };

    let session_id = uuid::Uuid::new_v4().to_string();
    let delegate: std::sync::Arc<dyn crate::bridge::AgentEventDelegate> =
        std::sync::Arc::new(crate::tools::delegate_task::SilentDelegate);
    let cancel = tokio_util::sync::CancellationToken::new();

    match run_agent_loop(
        session_id,
        objective,
        provider,
        tool_registry,
        delegate,
        config,
        cancel,
    )
    .await
    {
        Ok(result) => super::researcher::extract_findings(&result.final_content),
        Err(e) => format!("[synthesis failed: {e}]"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::deep_research::SubQuestion;

    fn plan() -> ResearchPlan {
        ResearchPlan {
            objective: "compare A and B".to_string(),
            sub_questions: vec![
                SubQuestion {
                    id: "q1".to_string(),
                    question: "what is A?".to_string(),
                    depends_on: vec![],
                },
                SubQuestion {
                    id: "q2".to_string(),
                    question: "what is B?".to_string(),
                    depends_on: vec![],
                },
            ],
        }
    }

    fn results() -> Vec<SubResult> {
        vec![
            SubResult {
                id: "q1".to_string(),
                findings: "A is apples".to_string(),
            },
            SubResult {
                id: "q2".to_string(),
                findings: "B is bananas".to_string(),
            },
        ]
    }

    #[test]
    fn digest_keys_each_finding_by_id_and_question() {
        let d = findings_digest(&plan(), &results());
        assert!(d.contains("## [q1] what is A?"));
        assert!(d.contains("A is apples"));
        assert!(d.contains("## [q2] what is B?"));
        assert!(d.contains("B is bananas"));
    }

    #[test]
    fn digest_tolerates_a_result_with_no_matching_question() {
        let orphan = vec![SubResult {
            id: "ghost".to_string(),
            findings: "f".to_string(),
        }];
        let d = findings_digest(&plan(), &orphan);
        assert!(d.contains("## [ghost] (no matching sub-question)"));
        assert!(d.contains("\nf"));
    }

    #[test]
    fn synthesis_objective_carries_objective_citation_rule_and_digest() {
        let o = synthesis_objective(&plan(), &results());
        assert!(o.contains("OBJECTIVE: compare A and B"));
        assert!(o.contains("Synthesize"));
        assert!(o.to_lowercase().contains("cite"));
        assert!(o.contains("[like-this]"));
        // The digest (with each cited finding) is embedded.
        assert!(o.contains("[q1]") && o.contains("A is apples"));
        assert!(o.contains("[q2]") && o.contains("B is bananas"));
        // No stray literal backslashes from the line-continuations.
        assert!(!o.contains('\\'));
    }
}
