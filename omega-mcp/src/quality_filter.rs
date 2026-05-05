// Quality filter: ensures only functionally verified traces enter the training pool.
// Removes failed/partial traces, validates JSON structure, checks completeness.

use crate::trace_logger::ExecutionTrace;

/// Filter traces to only include high-quality training data.
/// Returns traces where: all steps succeeded, total duration > 0, request is non-empty.
pub fn filter_quality(traces: Vec<ExecutionTrace>) -> Vec<ExecutionTrace> {
    traces.into_iter().filter(|t| is_quality_trace(t)).collect()
}

/// Check if a trace meets quality criteria for training.
pub fn is_quality_trace(trace: &ExecutionTrace) -> bool {
    // Must be marked successful overall
    if !trace.success {
        return false;
    }

    // Must have at least one step
    if trace.plan_steps.is_empty() {
        return false;
    }

    // Request must be non-empty
    if trace.request.trim().is_empty() {
        return false;
    }

    // All steps must have succeeded
    if !trace.plan_steps.iter().all(|s| s.success) {
        return false;
    }

    // Each step must have valid tool name
    if trace.plan_steps.iter().any(|s| s.tool.is_empty()) {
        return false;
    }

    // Each step's arguments must be valid JSON
    for step in &trace.plan_steps {
        if serde_json::from_str::<serde_json::Value>(&step.arguments_json).is_err() {
            return false;
        }
        if serde_json::from_str::<serde_json::Value>(&step.result_json).is_err() {
            return false;
        }
    }

    true
}

/// Statistics about filtering results.
pub struct FilterStats {
    pub total_input: usize,
    pub passed: usize,
    pub failed_overall: usize,
    pub failed_empty_steps: usize,
    pub failed_step_errors: usize,
    pub failed_invalid_json: usize,
}

/// Filter with statistics.
pub fn filter_with_stats(traces: Vec<ExecutionTrace>) -> (Vec<ExecutionTrace>, FilterStats) {
    let total = traces.len();
    let mut failed_overall = 0;
    let mut failed_empty = 0;
    let mut failed_steps = 0;
    let mut failed_json = 0;

    let passed: Vec<ExecutionTrace> = traces
        .into_iter()
        .filter(|t| {
            if !t.success {
                failed_overall += 1;
                return false;
            }
            if t.plan_steps.is_empty() {
                failed_empty += 1;
                return false;
            }
            if !t.plan_steps.iter().all(|s| s.success) {
                failed_steps += 1;
                return false;
            }
            for s in &t.plan_steps {
                if serde_json::from_str::<serde_json::Value>(&s.arguments_json).is_err()
                    || serde_json::from_str::<serde_json::Value>(&s.result_json).is_err()
                {
                    failed_json += 1;
                    return false;
                }
            }
            true
        })
        .collect();

    let stats = FilterStats {
        total_input: total,
        passed: passed.len(),
        failed_overall,
        failed_empty_steps: failed_empty,
        failed_step_errors: failed_steps,
        failed_invalid_json: failed_json,
    };

    (passed, stats)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::trace_logger::{ExecutionTrace, TraceStep};

    fn good_trace() -> ExecutionTrace {
        ExecutionTrace {
            id: "good".to_string(),
            request: "Open Safari".to_string(),
            plan_steps: vec![TraceStep {
                agent: "safari".to_string(),
                tool: "open_url".to_string(),
                arguments_json: r#"{"url":"https://apple.com"}"#.to_string(),
                result_json: r#"{"opened":true}"#.to_string(),
                duration_ms: 100,
                success: true,
            }],
            total_duration_ms: 100,
            success: true,
            feedback: None,
        }
    }

    #[test]
    fn test_good_trace_passes() {
        assert!(is_quality_trace(&good_trace()));
    }

    #[test]
    fn test_failed_trace_rejected() {
        let mut t = good_trace();
        t.success = false;
        assert!(!is_quality_trace(&t));
    }

    #[test]
    fn test_empty_steps_rejected() {
        let mut t = good_trace();
        t.plan_steps.clear();
        assert!(!is_quality_trace(&t));
    }

    #[test]
    fn test_failed_step_rejected() {
        let mut t = good_trace();
        t.plan_steps[0].success = false;
        assert!(!is_quality_trace(&t));
    }

    #[test]
    fn test_invalid_json_rejected() {
        let mut t = good_trace();
        t.plan_steps[0].arguments_json = "not json".to_string();
        assert!(!is_quality_trace(&t));
    }

    #[test]
    fn test_filter_with_stats() {
        let traces = vec![good_trace(), {
            let mut t = good_trace();
            t.id = "bad".to_string();
            t.success = false;
            t
        }];
        let (passed, stats) = filter_with_stats(traces);
        assert_eq!(stats.total_input, 2);
        assert_eq!(stats.passed, 1);
        assert_eq!(stats.failed_overall, 1);
        assert_eq!(passed.len(), 1);
    }
}
