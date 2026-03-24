// Enhanced trace logger: captures full request → plan → tool calls → results → feedback.
// Produces JSONL for ODIA training dataset generation.

use serde::{Deserialize, Serialize};

/// A complete execution trace for training data generation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionTrace {
    pub id: String,
    pub request: String,
    pub plan_steps: Vec<TraceStep>,
    pub total_duration_ms: u64,
    pub success: bool,
    pub feedback: Option<String>,
}

/// A single step within a trace.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceStep {
    pub agent: String,
    pub tool: String,
    pub arguments_json: String,
    pub result_json: String,
    pub duration_ms: u64,
    pub success: bool,
}

/// Convert a trace to ODIA format (Observe-Decide-Interact-Assess).
pub fn trace_to_odia_jsonl(trace: &ExecutionTrace) -> Vec<String> {
    trace.plan_steps.iter().enumerate().filter_map(|(i, step)| {
        if !step.success { return None; } // Quality filter: only successful steps

        let odia = serde_json::json!({
            "observe": {
                "task": trace.request,
                "step_index": i,
                "total_steps": trace.plan_steps.len(),
            },
            "decide": {
                "agent": step.agent,
                "tool": step.tool,
                "reasoning": format!("Use {} agent with {} tool", step.agent, step.tool),
            },
            "interact": {
                "tool_call": step.tool,
                "arguments": serde_json::from_str::<serde_json::Value>(&step.arguments_json).unwrap_or_default(),
            },
            "assess": {
                "success": step.success,
                "result": serde_json::from_str::<serde_json::Value>(&step.result_json).unwrap_or_default(),
            }
        });

        serde_json::to_string(&odia).ok()
    }).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_trace() -> ExecutionTrace {
        ExecutionTrace {
            id: "t-1".to_string(),
            request: "Open Safari and go to apple.com".to_string(),
            plan_steps: vec![
                TraceStep {
                    agent: "safari".to_string(),
                    tool: "open_url".to_string(),
                    arguments_json: r#"{"url":"https://apple.com"}"#.to_string(),
                    result_json: r#"{"opened":true}"#.to_string(),
                    duration_ms: 150,
                    success: true,
                },
                TraceStep {
                    agent: "safari".to_string(),
                    tool: "get_page_title".to_string(),
                    arguments_json: "{}".to_string(),
                    result_json: r#"{"title":"Apple"}"#.to_string(),
                    duration_ms: 50,
                    success: true,
                },
            ],
            total_duration_ms: 200,
            success: true,
            feedback: Some("accepted".to_string()),
        }
    }

    #[test]
    fn test_trace_to_odia() {
        let trace = make_trace();
        let lines = trace_to_odia_jsonl(&trace);
        assert_eq!(lines.len(), 2);
        // Each line should be valid JSON
        for line in &lines {
            let parsed: serde_json::Value = serde_json::from_str(line).unwrap();
            assert!(parsed["observe"]["task"].is_string());
            assert!(parsed["decide"]["agent"].is_string());
            assert!(parsed["interact"]["tool_call"].is_string());
            assert!(parsed["assess"]["success"].is_boolean());
        }
    }

    #[test]
    fn test_odia_filters_failures() {
        let mut trace = make_trace();
        trace.plan_steps[1].success = false;
        let lines = trace_to_odia_jsonl(&trace);
        assert_eq!(lines.len(), 1); // Only the successful step
    }

    #[test]
    fn test_empty_trace() {
        let trace = ExecutionTrace {
            id: "t-empty".to_string(),
            request: "nothing".to_string(),
            plan_steps: vec![],
            total_duration_ms: 0,
            success: false,
            feedback: None,
        };
        let lines = trace_to_odia_jsonl(&trace);
        assert!(lines.is_empty());
    }
}
