//! DeerFlow slice 5 — the top-level run: ties planner → orchestrator →
//! researcher → reporter into one multi-agent deep-research run.
//!
//! PRO-gated (it spawns cloud sub-agent loops, like the researcher/reporter) AND
//! gated behind EPISTEMOS_DEEP_RESEARCH_V0 (`deep_research_enabled`) — so even on
//! the Pro build it does nothing until explicitly opted in. Single-agent stays
//! the default everywhere else.

#[cfg(feature = "pro-build")]
use std::sync::Arc;

#[cfg(feature = "pro-build")]
use super::{ResearchPlan, SubResult};

/// The full output of a deep-research run: the plan, the per-sub-question
/// results, and the synthesized (cited) report.
#[cfg(feature = "pro-build")]
#[derive(Debug, Clone)]
pub struct DeepResearchReport {
    pub plan: ResearchPlan,
    pub results: Vec<SubResult>,
    pub report: String,
}

#[cfg(feature = "pro-build")]
#[derive(Debug)]
pub enum DeepResearchRunError {
    /// The flag is off — the run was not attempted (single-agent default).
    Disabled,
    /// The planner failed to produce a valid plan.
    Planner(super::planner::PlannerError),
    /// The plan was structurally invalid at orchestration time (cyclic, etc.).
    Plan(super::DeepResearchError),
}

#[cfg(feature = "pro-build")]
impl std::fmt::Display for DeepResearchRunError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeepResearchRunError::Disabled => {
                write!(
                    f,
                    "deep research is disabled (EPISTEMOS_DEEP_RESEARCH_V0 off)"
                )
            }
            DeepResearchRunError::Planner(e) => write!(f, "planner: {e}"),
            DeepResearchRunError::Plan(e) => write!(f, "plan: {e}"),
        }
    }
}

#[cfg(feature = "pro-build")]
impl std::error::Error for DeepResearchRunError {}

#[cfg(feature = "pro-build")]
const PLANNER_SYSTEM_PROMPT: &str =
    "You are the lead planner of a deep-research run. Emit ONLY the JSON research plan, no prose.";

/// The planner turn: decompose the objective into a validated ResearchPlan via a
/// single agent_core turn over the planner prompt, then parse + validate.
#[cfg(feature = "pro-build")]
async fn run_planner(
    objective: &str,
    provider: Arc<dyn crate::provider::AgentProvider>,
    tool_registry: Arc<crate::tools::registry::ToolRegistry>,
) -> Result<ResearchPlan, DeepResearchRunError> {
    use crate::agent_loop::{run_agent_loop, AgentConfig, Effort};

    let config = AgentConfig {
        system_prompt: Some(PLANNER_SYSTEM_PROMPT.to_string()),
        max_turns: Some(2),
        max_output_tokens: Some(2048),
        effort: Effort::Medium,
        enable_web_search: false,
        enable_web_fetch: false,
        enable_computer_use: false,
        ..AgentConfig::default()
    };
    let session_id = uuid::Uuid::new_v4().to_string();
    let delegate: Arc<dyn crate::bridge::AgentEventDelegate> =
        Arc::new(crate::tools::delegate_task::SilentDelegate);
    let cancel = tokio_util::sync::CancellationToken::new();

    let raw = match run_agent_loop(
        session_id,
        super::planner::planner_prompt(objective),
        provider,
        tool_registry,
        delegate,
        config,
        cancel,
    )
    .await
    {
        Ok(result) => super::researcher::extract_findings(&result.final_content),
        Err(e) => {
            return Err(DeepResearchRunError::Planner(
                super::planner::PlannerError::InvalidJson(e.to_string()),
            ))
        }
    };

    super::planner::parse_plan(&raw).map_err(DeepResearchRunError::Planner)
}

/// Run a full multi-agent deep-research run: planner → parallel sub-agents →
/// cited synthesis. Returns [`DeepResearchRunError::Disabled`] when the flag is
/// off (the caller falls back to the normal single-agent path).
#[cfg(feature = "pro-build")]
pub async fn run_deep_research(
    objective: &str,
    provider: Arc<dyn crate::provider::AgentProvider>,
    tool_registry: Arc<crate::tools::registry::ToolRegistry>,
    max_concurrency: usize,
    sub_agent_max_turns: u32,
    synthesis_max_turns: u32,
) -> Result<DeepResearchReport, DeepResearchRunError> {
    if !super::deep_research_enabled() {
        return Err(DeepResearchRunError::Disabled);
    }

    // 1. Planner: decompose the objective.
    let plan = run_planner(objective, provider.clone(), tool_registry.clone()).await?;

    // 2. Researcher: run the plan's layers as concurrent isolated sub-agents.
    let researcher: Arc<dyn super::orchestrator::SubAgentResearcher> =
        Arc::new(super::researcher::LiveSubAgentResearcher::new(
            provider.clone(),
            tool_registry.clone(),
            sub_agent_max_turns,
        ));
    let results = super::orchestrator::run_plan(&plan, researcher, max_concurrency)
        .await
        .map_err(DeepResearchRunError::Plan)?;

    // 3. Reporter: synthesize the findings into one cited answer.
    let report = super::reporter::run_synthesis(
        &plan,
        &results,
        provider,
        tool_registry,
        synthesis_max_turns,
    )
    .await;

    Ok(DeepResearchReport {
        plan,
        results,
        report,
    })
}
