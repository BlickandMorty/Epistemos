//! Dispatcher — Intent-based routing to skills or agents.
//!
//! Routes user objectives to the most appropriate handler:
//! 1. Exact trigger match in skills → dispatch to skill (confidence 1.0)
//! 2. TF-IDF similarity > 0.7 → dispatch to top skill
//! 3. Keyword heuristics → dispatch to agent type
//! 4. Default → direct response (no routing)

use crate::routing::contains_any;
use crate::skill_router::SkillRouter;
use crate::storage::skills_registry::SkillRegistryEntry;
use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Where to route the user's intent.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum DispatchTarget {
    /// Route to a specific skill by name.
    Skill(String),
    /// Route to an agent type ("research", "code", "creative").
    Agent(String),
    /// No routing needed — direct LLM response.
    DirectResponse,
}

/// The result of dispatching an intent.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DispatchDecision {
    pub target: DispatchTarget,
    pub confidence: f64,
    pub reasoning: String,
}

// ---------------------------------------------------------------------------
// Dispatch Logic
// ---------------------------------------------------------------------------

/// Route an objective to the best skill or agent.
///
/// Priority cascade:
/// 1. Exact trigger match → skill (confidence 1.0)
/// 2. TF-IDF similarity > 0.7 → top skill
/// 3. Keyword heuristics → agent type
/// 4. Default → DirectResponse
pub fn dispatch_intent(
    objective: &str,
    router: &SkillRouter,
    _available_skills: &[SkillRegistryEntry],
) -> DispatchDecision {
    // Step 1+2: Use the skill router (handles both exact triggers and TF-IDF)
    let matches = router.route(objective, 3);
    if let Some(best) = matches.first() {
        if best.score >= 0.7 {
            return DispatchDecision {
                target: DispatchTarget::Skill(best.skill.name.clone()),
                confidence: best.score,
                reasoning: format!(
                    "Skill '{}' matched with score {:.0}%{}",
                    best.skill.name,
                    best.score * 100.0,
                    best.matched_trigger
                        .as_ref()
                        .map(|t| format!(" (trigger: '{t}')"))
                        .unwrap_or_default()
                ),
            };
        }
    }

    // Step 3: Keyword heuristics for agent type routing
    let lower = objective.to_lowercase();
    if contains_any(
        &lower,
        &[
            "research", "search", "find", "look up", "what is", "compare",
        ],
    ) {
        return DispatchDecision {
            target: DispatchTarget::Agent("research".to_string()),
            confidence: 0.6,
            reasoning: "Keyword match: research/search intent detected".to_string(),
        };
    }
    if contains_any(
        &lower,
        &[
            "code",
            "implement",
            "fix",
            "debug",
            "refactor",
            "test",
            "compile",
        ],
    ) {
        return DispatchDecision {
            target: DispatchTarget::Agent("code".to_string()),
            confidence: 0.6,
            reasoning: "Keyword match: code/engineering intent detected".to_string(),
        };
    }
    if contains_any(
        &lower,
        &["write", "draft", "compose", "creative", "story", "poem"],
    ) {
        return DispatchDecision {
            target: DispatchTarget::Agent("creative".to_string()),
            confidence: 0.5,
            reasoning: "Keyword match: creative/writing intent detected".to_string(),
        };
    }

    // Step 4: Default — direct response
    DispatchDecision {
        target: DispatchTarget::DirectResponse,
        confidence: 0.3,
        reasoning: "No skill or agent type matched — using direct response".to_string(),
    }
}

// Expose SkillMatch for FFI type conversion
pub use crate::skill_router::SkillMatch as SkillMatchExport;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn direct_response_for_generic_query() {
        let router = SkillRouter::load(Path::new("/nonexistent"));
        let decision = dispatch_intent("hello", &router, &[]);
        assert_eq!(decision.target, DispatchTarget::DirectResponse);
    }

    #[test]
    fn code_agent_for_engineering_query() {
        let router = SkillRouter::load(Path::new("/nonexistent"));
        let decision = dispatch_intent("fix the compilation error in main.rs", &router, &[]);
        assert_eq!(decision.target, DispatchTarget::Agent("code".to_string()));
        assert!(decision.confidence >= 0.5);
    }

    #[test]
    fn research_agent_for_search_query() {
        let router = SkillRouter::load(Path::new("/nonexistent"));
        let decision = dispatch_intent("research the latest transformer papers", &router, &[]);
        assert_eq!(
            decision.target,
            DispatchTarget::Agent("research".to_string())
        );
    }

    #[test]
    fn creative_agent_for_writing_query() {
        let router = SkillRouter::load(Path::new("/nonexistent"));
        let decision = dispatch_intent("write a draft blog post about Rust", &router, &[]);
        assert_eq!(
            decision.target,
            DispatchTarget::Agent("creative".to_string())
        );
    }
}
