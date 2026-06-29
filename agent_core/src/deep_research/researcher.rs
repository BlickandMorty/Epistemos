//! DeerFlow slice 3b — the LIVE researcher: an isolated agent_core sub-agent
//! loop per sub-question. Implements [`SubAgentResearcher`] (the slice-3
//! orchestration seam) by reusing the PROVEN sub-agent-spawning pattern from
//! `tools::delegate_task` (SilentDelegate + run_agent_loop, fresh session +
//! isolated history + the shared tool registry) — not a new mechanism.
//!
//! The agent loop requires a CLOUD provider (CLAUDE.md capability gating): a
//! local provider surfaces an HONEST error finding rather than silently
//! degrading. The new logic (building the focused objective + extracting the
//! findings) lives in the pure helpers below, which ARE unit-tested; `research`
//! is thin proven glue over them.
//!
//! Still inert: constructed only by the future deep-research wiring slice behind
//! EPISTEMOS_DEEP_RESEARCH_V0. Single-agent stays the default.

use super::{SubQuestion, SubResult};
use crate::types::ContentBlock;

// The live multi-agent researcher spawns cloud sub-agent loops — the SAME
// Pro-only capability as tools::delegate_task (which is #[cfg(pro-build)]). Gated
// to Pro. The plan/orchestrator substrate + the pure helpers below stay
// always-compiled (usable by either build / MAS surfaces that only need them).
#[cfg(feature = "pro-build")]
use super::orchestrator::SubAgentResearcher;
#[cfg(feature = "pro-build")]
use crate::agent_loop::{run_agent_loop, AgentConfig, Effort};
#[cfg(feature = "pro-build")]
use crate::provider::AgentProvider;
#[cfg(feature = "pro-build")]
use crate::tools::delegate_task::SilentDelegate;
#[cfg(feature = "pro-build")]
use crate::tools::registry::ToolRegistry;
#[cfg(feature = "pro-build")]
use async_trait::async_trait;
#[cfg(feature = "pro-build")]
use std::sync::Arc;
#[cfg(feature = "pro-build")]
use tokio_util::sync::CancellationToken;

#[cfg(feature = "pro-build")]
const DEEP_RESEARCH_SUBAGENT_PROMPT: &str = "You are a focused research sub-agent in a multi-agent deep-research run. Investigate ONLY your assigned question using your tools (web search, web fetch, vault, file). Return concise, evidence-grounded findings with sources. Do not answer beyond your question.";

#[cfg(feature = "pro-build")]
const SUBAGENT_MAX_OUTPUT_TOKENS: u32 = 4096;

/// A live researcher: each sub-question runs its own isolated agent_core
/// sub-agent loop (own session + message history, shared tools, cloud provider).
#[cfg(feature = "pro-build")]
pub struct LiveSubAgentResearcher {
    provider: Arc<dyn AgentProvider>,
    tool_registry: Arc<ToolRegistry>,
    max_turns: u32,
}

#[cfg(feature = "pro-build")]
impl LiveSubAgentResearcher {
    pub fn new(
        provider: Arc<dyn AgentProvider>,
        tool_registry: Arc<ToolRegistry>,
        max_turns: u32,
    ) -> Self {
        Self {
            provider,
            tool_registry,
            max_turns: max_turns.max(1),
        }
    }
}

#[cfg(feature = "pro-build")]
#[async_trait]
impl SubAgentResearcher for LiveSubAgentResearcher {
    async fn research(&self, sub_question: &SubQuestion, prior: &[SubResult]) -> SubResult {
        let objective = sub_agent_objective(sub_question, prior);

        let config = AgentConfig {
            system_prompt: Some(DEEP_RESEARCH_SUBAGENT_PROMPT.to_string()),
            max_turns: Some(self.max_turns),
            max_output_tokens: Some(SUBAGENT_MAX_OUTPUT_TOKENS),
            effort: Effort::Medium,
            enable_web_search: true,
            enable_web_fetch: true,
            enable_computer_use: false,
            ..AgentConfig::default()
        };

        let session_id = uuid::Uuid::new_v4().to_string();
        let delegate: Arc<dyn crate::bridge::AgentEventDelegate> = Arc::new(SilentDelegate);
        let cancel = CancellationToken::new();

        let findings = match run_agent_loop(
            session_id,
            objective,
            self.provider.clone(),
            self.tool_registry.clone(),
            delegate,
            config,
            cancel,
        )
        .await
        {
            Ok(result) => extract_findings(&result.final_content),
            // Honest: never pretend a failed sub-agent succeeded; the synthesis
            // step reports the gap rather than inventing findings.
            Err(e) => format!("[sub-agent failed: {e}]"),
        };

        SubResult {
            id: sub_question.id.clone(),
            findings,
        }
    }
}

/// Build a sub-agent's objective: the sub-question, plus a digest of ONLY the
/// prior results it `depends_on` (focused, isolated context — unrelated prior
/// findings are NOT injected, keeping each sub-agent's context lean). Pure.
pub fn sub_agent_objective(sub_question: &SubQuestion, prior: &[SubResult]) -> String {
    let deps: Vec<&SubResult> = prior
        .iter()
        .filter(|r| sub_question.depends_on.iter().any(|d| d == &r.id))
        .collect();

    if deps.is_empty() {
        return sub_question.question.clone();
    }

    let context = deps
        .iter()
        .map(|r| format!("- [{}]: {}", r.id, r.findings))
        .collect::<Vec<_>>()
        .join("\n");

    format!(
        "{}\n\nPrior findings you depend on (use as context):\n{}",
        sub_question.question, context
    )
}

/// Extract readable findings from a sub-agent's final content — the joined text
/// of its Text blocks (reuses `ContentBlock::as_text`, same as DelegateTaskTool).
pub fn extract_findings(final_content: &[ContentBlock]) -> String {
    final_content
        .iter()
        .filter_map(ContentBlock::as_text)
        .collect::<Vec<_>>()
        .join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sub(id: &str, q: &str, deps: &[&str]) -> SubQuestion {
        SubQuestion {
            id: id.to_string(),
            question: q.to_string(),
            depends_on: deps.iter().map(|s| s.to_string()).collect(),
        }
    }

    fn res(id: &str, findings: &str) -> SubResult {
        SubResult {
            id: id.to_string(),
            findings: findings.to_string(),
        }
    }

    #[test]
    fn objective_is_just_the_question_when_no_deps() {
        let q = sub("q1", "what is X?", &[]);
        assert_eq!(sub_agent_objective(&q, &[]), "what is X?");
        // Even with prior results, an independent sub-question gets a lean context.
        assert_eq!(
            sub_agent_objective(&q, &[res("other", "stuff")]),
            "what is X?"
        );
    }

    #[test]
    fn objective_injects_only_depended_on_prior_findings() {
        let d = sub("d", "synthesize b and c", &["b", "c"]);
        let prior = vec![res("a", "FA-unrelated"), res("b", "FB"), res("c", "FC")];
        let obj = sub_agent_objective(&d, &prior);
        assert!(obj.contains("synthesize b and c"));
        assert!(obj.contains("[b]: FB"));
        assert!(obj.contains("[c]: FC"));
        // The unrelated prior result 'a' is NOT injected (lean, focused context).
        assert!(!obj.contains("FA-unrelated"));
    }

    #[test]
    fn extract_findings_joins_text_blocks_and_ignores_others() {
        let blocks = vec![
            ContentBlock::Thinking {
                thinking: "internal".into(),
                signature: "sig".into(),
            },
            ContentBlock::Text {
                text: "finding one".into(),
            },
            ContentBlock::ToolUse {
                id: "1".into(),
                name: "web_search".into(),
                input: serde_json::json!({"q": "x"}),
            },
            ContentBlock::Text {
                text: "finding two".into(),
            },
        ];
        assert_eq!(extract_findings(&blocks), "finding one\nfinding two");
        assert_eq!(extract_findings(&[]), "");
    }
}
