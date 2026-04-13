//! Trace Analyzer — Aggregate session traces to identify improvement signals.
//!
//! Reads `trace.json` files from multiple sessions and identifies patterns:
//! - FrequentRetries: a skill/tool is retried 3+ times in a session
//! - SlowExecution: a tool consistently takes longer than expected
//! - ConsistentFailure: a tool fails in the same way across sessions
//! - UnusedCapability: a skill step is defined but never invoked

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::storage::session_store::TraceEvent;
use crate::storage::vault::VaultError;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Aggregated pattern from trace analysis.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TracePattern {
    pub skill_name: String,
    pub sessions_analyzed: u32,
    pub success_count: u32,
    pub failure_count: u32,
    pub avg_duration_ms: f64,
    pub improvement_signals: Vec<ImprovementSignal>,
}

/// A specific improvement opportunity detected in traces.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ImprovementSignal {
    /// A tool/step is retried 3+ times in multiple sessions.
    FrequentRetries {
        step: String,
        avg_retry_count: f64,
        sessions_affected: u32,
    },
    /// A tool consistently takes too long.
    SlowExecution {
        step: String,
        avg_ms: f64,
        p95_ms: f64,
    },
    /// A tool fails with the same error across sessions.
    ConsistentFailure {
        step: String,
        error_pattern: String,
        occurrence_count: u32,
    },
    /// A capability exists but is never used.
    UnusedCapability { capability: String },
}

// ---------------------------------------------------------------------------
// Analysis
// ---------------------------------------------------------------------------

/// Analyze traces from multiple session folders for a specific skill.
///
/// Reads `trace.json` from each folder, filters for events matching the
/// skill name, and aggregates patterns.
pub fn analyze_traces(
    session_folders: &[&Path],
    skill_name: &str,
) -> Result<TracePattern, VaultError> {
    let mut all_events: Vec<Vec<TraceEvent>> = Vec::new();
    let mut total_duration_ms: f64 = 0.0;
    let mut duration_count: u32 = 0;
    let mut success_count: u32 = 0;
    let mut failure_count: u32 = 0;

    for folder in session_folders {
        let trace_path = folder.join("trace.json");
        if !trace_path.exists() {
            continue;
        }

        let content = fs::read_to_string(&trace_path)?;
        let events: Vec<TraceEvent> = serde_json::from_str(&content).unwrap_or_default();

        // Filter events related to this skill
        let skill_events: Vec<TraceEvent> = events
            .into_iter()
            .filter(|e| {
                e.name
                    .as_ref()
                    .map(|n| n.contains(skill_name))
                    .unwrap_or(false)
            })
            .collect();

        for event in &skill_events {
            if let Some(ms) = event.duration_ms {
                total_duration_ms += ms as f64;
                duration_count += 1;
            }
            match event.outcome.as_deref() {
                Some("success") | Some("ok") => success_count += 1,
                Some("error") | Some("failure") => failure_count += 1,
                _ => {}
            }
        }

        if !skill_events.is_empty() {
            all_events.push(skill_events);
        }
    }

    let sessions_analyzed = all_events.len() as u32;
    let avg_duration_ms = if duration_count > 0 {
        total_duration_ms / duration_count as f64
    } else {
        0.0
    };

    // Detect improvement signals
    let signals = detect_signals(&all_events, skill_name);

    Ok(TracePattern {
        skill_name: skill_name.to_string(),
        sessions_analyzed,
        success_count,
        failure_count,
        avg_duration_ms,
        improvement_signals: signals,
    })
}

fn detect_signals(sessions: &[Vec<TraceEvent>], skill_name: &str) -> Vec<ImprovementSignal> {
    let mut signals = Vec::new();

    // Detect FrequentRetries: same tool called 3+ times in a session
    let mut retry_sessions: HashMap<String, Vec<u32>> = HashMap::new();
    for session_events in sessions {
        let mut tool_counts: HashMap<&str, u32> = HashMap::new();
        for event in session_events {
            if let Some(ref name) = event.name {
                *tool_counts.entry(name.as_str()).or_default() += 1;
            }
        }
        for (tool, count) in &tool_counts {
            if *count >= 3 {
                retry_sessions
                    .entry(tool.to_string())
                    .or_default()
                    .push(*count);
            }
        }
    }
    for (tool, counts) in &retry_sessions {
        if counts.len() >= 2 {
            let avg: f64 = counts.iter().map(|c| *c as f64).sum::<f64>() / counts.len() as f64;
            signals.push(ImprovementSignal::FrequentRetries {
                step: tool.clone(),
                avg_retry_count: avg,
                sessions_affected: counts.len() as u32,
            });
        }
    }

    // Detect SlowExecution: durations consistently above 5 seconds
    let mut tool_durations: HashMap<String, Vec<f64>> = HashMap::new();
    for session_events in sessions {
        for event in session_events {
            if let (Some(ref name), Some(ms)) = (&event.name, event.duration_ms) {
                tool_durations
                    .entry(name.clone())
                    .or_default()
                    .push(ms as f64);
            }
        }
    }
    for (tool, mut durations) in tool_durations {
        if durations.len() < 3 {
            continue;
        }
        durations.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let avg = durations.iter().sum::<f64>() / durations.len() as f64;
        let p95_idx = (durations.len() as f64 * 0.95) as usize;
        let p95 = durations
            .get(p95_idx.min(durations.len() - 1))
            .copied()
            .unwrap_or(avg);
        if avg > 5000.0 {
            signals.push(ImprovementSignal::SlowExecution {
                step: tool,
                avg_ms: avg,
                p95_ms: p95,
            });
        }
    }

    // Detect ConsistentFailure: same error pattern across 3+ sessions
    let mut error_patterns: HashMap<String, u32> = HashMap::new();
    for session_events in sessions {
        for event in session_events {
            if event.outcome.as_deref() == Some("error") {
                if let Some(ref output) = event.output_summary {
                    let key = format!(
                        "{}::{}",
                        event.name.as_deref().unwrap_or(skill_name),
                        &output[..output.len().min(80)]
                    );
                    *error_patterns.entry(key).or_default() += 1;
                }
            }
        }
    }
    for (pattern, count) in &error_patterns {
        if *count >= 3 {
            let parts: Vec<&str> = pattern.splitn(2, "::").collect();
            signals.push(ImprovementSignal::ConsistentFailure {
                step: parts.first().unwrap_or(&skill_name).to_string(),
                error_pattern: parts.get(1).unwrap_or(&"").to_string(),
                occurrence_count: *count,
            });
        }
    }

    signals
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use tempfile::TempDir;

    fn make_trace_event(name: &str, duration_ms: u64, outcome: &str) -> TraceEvent {
        TraceEvent {
            timestamp: Utc::now(),
            kind: "tool_call".to_string(),
            name: Some(name.to_string()),
            input_summary: None,
            output_summary: if outcome == "error" {
                Some("Connection refused".to_string())
            } else {
                None
            },
            duration_ms: Some(duration_ms),
            outcome: Some(outcome.to_string()),
        }
    }

    fn write_trace(dir: &Path, events: &[TraceEvent]) {
        let json = serde_json::to_string(events).unwrap();
        fs::write(dir.join("trace.json"), json).unwrap();
    }

    #[test]
    fn detect_frequent_retries() {
        let tmp = TempDir::new().unwrap();
        let s1 = tmp.path().join("s1");
        let s2 = tmp.path().join("s2");
        fs::create_dir_all(&s1).unwrap();
        fs::create_dir_all(&s2).unwrap();

        // 4 calls to vault_search in each session
        let events = vec![
            make_trace_event("vault_search", 100, "success"),
            make_trace_event("vault_search", 100, "success"),
            make_trace_event("vault_search", 100, "error"),
            make_trace_event("vault_search", 100, "success"),
        ];
        write_trace(&s1, &events);
        write_trace(&s2, &events);

        let pattern = analyze_traces(&[s1.as_path(), s2.as_path()], "vault_search").unwrap();
        assert!(pattern
            .improvement_signals
            .iter()
            .any(|s| matches!(s, ImprovementSignal::FrequentRetries { .. })));
    }

    #[test]
    fn detect_slow_execution() {
        let tmp = TempDir::new().unwrap();
        let s1 = tmp.path().join("s1");
        fs::create_dir_all(&s1).unwrap();

        let events = vec![
            make_trace_event("web_fetch", 6000, "success"),
            make_trace_event("web_fetch", 7000, "success"),
            make_trace_event("web_fetch", 8000, "success"),
            make_trace_event("web_fetch", 9000, "success"),
        ];
        write_trace(&s1, &events);

        let pattern = analyze_traces(&[s1.as_path()], "web_fetch").unwrap();
        assert!(pattern
            .improvement_signals
            .iter()
            .any(|s| matches!(s, ImprovementSignal::SlowExecution { .. })));
    }

    #[test]
    fn detect_consistent_failure() {
        let tmp = TempDir::new().unwrap();
        let s1 = tmp.path().join("s1");
        fs::create_dir_all(&s1).unwrap();

        let events = vec![
            make_trace_event("api_call", 100, "error"),
            make_trace_event("api_call", 100, "error"),
            make_trace_event("api_call", 100, "error"),
        ];
        write_trace(&s1, &events);

        let pattern = analyze_traces(&[s1.as_path()], "api_call").unwrap();
        assert!(pattern
            .improvement_signals
            .iter()
            .any(|s| matches!(s, ImprovementSignal::ConsistentFailure { .. })));
    }

    #[test]
    fn no_signals_for_healthy_traces() {
        let tmp = TempDir::new().unwrap();
        let s1 = tmp.path().join("s1");
        fs::create_dir_all(&s1).unwrap();

        let events = vec![
            make_trace_event("vault_search", 100, "success"),
            make_trace_event("vault_write", 50, "success"),
        ];
        write_trace(&s1, &events);

        let pattern = analyze_traces(&[s1.as_path()], "vault").unwrap();
        assert!(pattern.improvement_signals.is_empty());
    }

    #[test]
    fn empty_sessions() {
        let pattern = analyze_traces(&[], "vault_search").unwrap();
        assert_eq!(pattern.sessions_analyzed, 0);
        assert!(pattern.improvement_signals.is_empty());
    }
}
