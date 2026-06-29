//! DeerFlow slice 2 — the PLANNER (the lead agent's decomposition step).
//!
//! Pure, testable pieces (the live model call wires in via the orchestrator,
//! slice 3): the model-facing JSON [`research_plan_schema`], the decomposition
//! [`planner_prompt`], and [`parse_plan`] — which extracts the model's JSON
//! (tolerating prose / ```json fences), deserializes, and runs the slice-1
//! [`ResearchPlan::validate`] so a malformed plan NEVER reaches the sub-agents.
//!
//! Still inert: nothing here calls a model — single-agent stays the default.

use super::{DeepResearchError, ResearchPlan};

/// The JSON schema the planner model must conform to. Shown to the model in the
/// prompt AND usable by the P8.1 schema gate when the planner is exposed as a
/// tool (rejects malformed planner output before any sub-agent runs).
pub fn research_plan_schema() -> serde_json::Value {
    serde_json::json!({
        "type": "object",
        "required": ["objective", "sub_questions"],
        "additionalProperties": false,
        "properties": {
            "objective": { "type": "string", "minLength": 1 },
            "sub_questions": {
                "type": "array",
                "minItems": 1,
                "items": {
                    "type": "object",
                    "required": ["id", "question"],
                    "additionalProperties": false,
                    "properties": {
                        "id": { "type": "string", "minLength": 1 },
                        "question": { "type": "string", "minLength": 1 },
                        "depends_on": {
                            "type": "array",
                            "items": { "type": "string" }
                        }
                    }
                }
            }
        }
    })
}

/// Build the lead-planner decomposition prompt. Asks for a minimal set of
/// independent, parallel-researchable sub-questions, using `depends_on` only for
/// genuine ordering (e.g. a synthesis step). Prefers breadth (parallel) over
/// depth (chains) so the fan-out is wide.
pub fn planner_prompt(objective: &str) -> String {
    format!(
        r#"You are the lead planner of a deep-research run. Decompose the OBJECTIVE into a minimal set of independent, parallel-researchable sub-questions.

Rules:
- Prefer BREADTH over depth: most sub-questions should be independent so they can be researched in parallel.
- Use "depends_on" ONLY when a sub-question genuinely needs another's result first (e.g. a final synthesis/compare step). List the ids it depends on.
- Give each sub-question a short stable "id" (e.g. "q1", "q2").
- Keep the plan small and focused — only the sub-questions truly needed.

Emit ONLY a single JSON object matching this schema, with NO prose before or after:
{schema}

OBJECTIVE: {objective}"#,
        schema = serde_json::to_string_pretty(&research_plan_schema())
            .unwrap_or_else(|_| "{}".to_string()),
        objective = objective.trim(),
    )
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlannerError {
    /// No JSON object could be located in the model output.
    NoJsonFound,
    /// A JSON object was located but did not deserialize into a ResearchPlan.
    InvalidJson(String),
    /// The plan deserialized but failed semantic validation (slice 1).
    InvalidPlan(DeepResearchError),
}

impl std::fmt::Display for PlannerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            PlannerError::NoJsonFound => write!(f, "no JSON object found in planner output"),
            PlannerError::InvalidJson(e) => write!(f, "planner JSON did not parse: {e}"),
            PlannerError::InvalidPlan(e) => write!(f, "planner produced an invalid plan: {e}"),
        }
    }
}

impl std::error::Error for PlannerError {}

/// Extract the JSON object from raw model output: the span from the first `{` to
/// the last `}`. Tolerates prose around it and ```json fences (the braces sit
/// inside the fence). `None` when there is no balanced-looking object.
fn extract_json_object(raw: &str) -> Option<&str> {
    let start = raw.find('{')?;
    let end = raw.rfind('}')?;
    if end > start {
        Some(&raw[start..=end])
    } else {
        None
    }
}

/// Parse a planner model's raw output into a VALIDATED [`ResearchPlan`]. The
/// honest gate between "the model said" and "we run sub-agents": malformed or
/// cyclic plans are rejected here, never executed.
pub fn parse_plan(raw: &str) -> Result<ResearchPlan, PlannerError> {
    let json = extract_json_object(raw).ok_or(PlannerError::NoJsonFound)?;
    let plan: ResearchPlan =
        serde_json::from_str(json).map_err(|e| PlannerError::InvalidJson(e.to_string()))?;
    plan.validate().map_err(PlannerError::InvalidPlan)?;
    Ok(plan)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_requires_objective_and_sub_questions() {
        let schema = research_plan_schema();
        let required = schema["required"].as_array().unwrap();
        assert!(required.iter().any(|v| v == "objective"));
        assert!(required.iter().any(|v| v == "sub_questions"));
        assert_eq!(schema["properties"]["sub_questions"]["minItems"], 1);
    }

    #[test]
    fn prompt_carries_objective_and_schema_and_parallel_guidance() {
        let p = planner_prompt("  compare A and B  ");
        assert!(p.contains("compare A and B"));
        assert!(!p.contains("  compare A and B  ")); // trimmed
        assert!(p.contains("sub_questions"));
        assert!(p.contains("depends_on"));
        assert!(p.to_lowercase().contains("parallel"));
        assert!(p.contains("ONLY a single JSON object"));
    }

    #[test]
    fn parses_a_bare_json_plan() {
        let raw = r#"{"objective":"x","sub_questions":[{"id":"q1","question":"a"},{"id":"q2","question":"b"}]}"#;
        let plan = parse_plan(raw).unwrap();
        assert_eq!(plan.objective, "x");
        assert_eq!(plan.len(), 2);
        assert_eq!(plan.max_parallel_width(), 2);
    }

    #[test]
    fn parses_a_fenced_json_plan_with_prose() {
        let raw = "Sure, here is the plan:\n```json\n{\"objective\":\"x\",\"sub_questions\":[{\"id\":\"q1\",\"question\":\"a\"}]}\n```\nLet me know!";
        let plan = parse_plan(raw).unwrap();
        assert_eq!(plan.len(), 1);
    }

    #[test]
    fn no_json_is_rejected() {
        assert_eq!(
            parse_plan("I cannot do that.").unwrap_err(),
            PlannerError::NoJsonFound
        );
        // Unbalanced (no closing brace) → nothing extractable.
        assert_eq!(
            parse_plan("{ not closed").unwrap_err(),
            PlannerError::NoJsonFound
        );
    }

    #[test]
    fn malformed_json_is_rejected_as_invalid_json() {
        let err = parse_plan("{not: valid json}").unwrap_err();
        assert!(matches!(err, PlannerError::InvalidJson(_)));
    }

    #[test]
    fn a_cyclic_plan_is_rejected_at_parse_time() {
        let raw = r#"{"objective":"x","sub_questions":[
            {"id":"q1","question":"a","depends_on":["q2"]},
            {"id":"q2","question":"b","depends_on":["q1"]}]}"#;
        assert_eq!(
            parse_plan(raw).unwrap_err(),
            PlannerError::InvalidPlan(DeepResearchError::CyclicDependency)
        );
    }

    #[test]
    fn an_unknown_dependency_is_rejected_at_parse_time() {
        let raw = r#"{"objective":"x","sub_questions":[{"id":"q1","question":"a","depends_on":["ghost"]}]}"#;
        assert!(matches!(
            parse_plan(raw).unwrap_err(),
            PlannerError::InvalidPlan(DeepResearchError::UnknownDependency { .. })
        ));
    }

    #[test]
    fn parsed_plan_lays_out_for_parallel_execution() {
        // a → (b, c) → d round-trips through the planner parse + lays out right.
        let raw = r#"{"objective":"x","sub_questions":[
            {"id":"a","question":"qa"},
            {"id":"b","question":"qb","depends_on":["a"]},
            {"id":"c","question":"qc","depends_on":["a"]},
            {"id":"d","question":"qd","depends_on":["b","c"]}]}"#;
        let plan = parse_plan(raw).unwrap();
        let layers = plan.execution_layers().unwrap();
        assert_eq!(layers.len(), 3);
        assert_eq!(layers[1].len(), 2); // b, c in parallel
    }
}
