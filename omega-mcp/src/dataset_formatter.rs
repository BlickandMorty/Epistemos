// Dataset formatter: converts execution traces into training-ready JSONL.
// Implements the 40/20/20/20 data composition from Google Deep Research.

use crate::trace_logger::{ExecutionTrace, trace_to_odia_jsonl};

/// Format multiple traces into a single JSONL string.
pub fn format_traces_to_jsonl(traces: &[ExecutionTrace]) -> String {
    traces.iter()
        .flat_map(|t| trace_to_odia_jsonl(t))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Mix training data categories at the specified ratios.
/// Returns a shuffled JSONL string.
pub fn mix_training_data(
    tool_call_lines: &[String],      // 40%
    general_lines: &[String],         // 20%
    reasoning_lines: &[String],       // 20%
    automation_lines: &[String],      // 20%
    target_count: usize,
) -> String {
    let tool_count = (target_count as f64 * 0.40) as usize;
    let general_count = (target_count as f64 * 0.20) as usize;
    let reasoning_count = (target_count as f64 * 0.20) as usize;
    let automation_count = (target_count as f64 * 0.20) as usize;

    let mut mixed = Vec::with_capacity(target_count);
    mixed.extend(sample(tool_call_lines, tool_count));
    mixed.extend(sample(general_lines, general_count));
    mixed.extend(sample(reasoning_lines, reasoning_count));
    mixed.extend(sample(automation_lines, automation_count));

    // Deterministic shuffle using simple rotation (real impl would use rand)
    let mid = mixed.len() / 2;
    let (a, b) = mixed.split_at(mid);
    let shuffled: Vec<&str> = b.iter().chain(a.iter()).map(|s| s.as_str()).collect();
    // Interleave
    let mut result = Vec::with_capacity(shuffled.len());
    let half = shuffled.len() / 2;
    for i in 0..half {
        result.push(shuffled[i]);
        if i + half < shuffled.len() {
            result.push(shuffled[i + half]);
        }
    }
    if shuffled.len() % 2 != 0 {
        result.push(shuffled[shuffled.len() - 1]);
    }

    result.join("\n")
}

/// Sample `count` items from a slice, repeating if needed.
fn sample(items: &[String], count: usize) -> Vec<String> {
    if items.is_empty() {
        return vec![];
    }
    (0..count).map(|i| items[i % items.len()].clone()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::trace_logger::{ExecutionTrace, TraceStep};

    #[test]
    fn test_format_traces() {
        let traces = vec![ExecutionTrace {
            id: "t-1".to_string(),
            request: "test".to_string(),
            plan_steps: vec![TraceStep {
                agent: "file".to_string(),
                tool: "read_file".to_string(),
                arguments_json: "{}".to_string(),
                result_json: "{}".to_string(),
                duration_ms: 10,
                success: true,
            }],
            total_duration_ms: 10,
            success: true,
            feedback: None,
        }];
        let jsonl = format_traces_to_jsonl(&traces);
        assert!(!jsonl.is_empty());
        assert!(jsonl.contains("read_file"));
    }

    #[test]
    fn test_mix_training_data() {
        let tool = vec!["tool1".to_string(), "tool2".to_string()];
        let general = vec!["gen1".to_string()];
        let reasoning = vec!["reason1".to_string()];
        let automation = vec!["auto1".to_string()];

        let mixed = mix_training_data(&tool, &general, &reasoning, &automation, 10);
        let lines: Vec<&str> = mixed.lines().collect();
        assert_eq!(lines.len(), 10);
    }

    #[test]
    fn test_mix_empty_categories() {
        let mixed = mix_training_data(&[], &[], &[], &[], 10);
        assert!(mixed.is_empty());
    }

    #[test]
    fn test_sample_with_repeat() {
        let items = vec!["a".to_string(), "b".to_string()];
        let sampled = sample(&items, 5);
        assert_eq!(sampled.len(), 5);
        assert_eq!(sampled[0], "a");
        assert_eq!(sampled[1], "b");
        assert_eq!(sampled[2], "a"); // wraps
    }
}
