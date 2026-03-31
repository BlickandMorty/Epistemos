// ── Mixture-of-Agents Parallel Pool ─────────────────────────────────────────
//
// Rust-native parallel sub-agent executor that bypasses Python's GIL.
// Uses rayon's work-stealing thread pool to distribute N concurrent
// sub-agent tasks across all Apple Silicon performance cores.
//
// Architecture:
//   Hermes (Python) calls MCP tool "moa_execute" with N task descriptions.
//   Swift routes to this Rust module via UniFFI.
//   Rust spawns N rayon tasks, each making HTTP requests to the LLM API.
//   Results are collected, a consensus reducer picks the best answer.
//   Single JSON result returned to Hermes in microseconds after completion.
//
// This eliminates the Python GIL bottleneck where threading.Thread
// serializes CPU-bound JSON parsing across all sub-agents.

use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

// MARK: - Types

/// A single sub-agent task in a MoA pool.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MoaTask {
    /// Unique task identifier.
    pub id: String,
    /// The prompt/instruction for this sub-agent.
    pub prompt: String,
    /// Optional model override (defaults to pool's model).
    pub model: Option<String>,
    /// Maximum tokens for this sub-agent's response.
    pub max_tokens: Option<u32>,
}

/// Result from a single sub-agent execution.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MoaResult {
    pub task_id: String,
    pub response: String,
    pub model: String,
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub latency_ms: u64,
    pub success: bool,
    pub error: Option<String>,
}

/// Aggregated result from the MoA pool.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MoaPoolResult {
    pub results: Vec<MoaResult>,
    pub consensus: Option<String>,
    pub total_latency_ms: u64,
    pub tasks_succeeded: usize,
    pub tasks_failed: usize,
}

/// Configuration for the MoA pool.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MoaConfig {
    /// Default model for all sub-agents.
    pub model: String,
    /// Maximum parallel sub-agents (capped at available cores).
    pub max_parallel: usize,
    /// Default max tokens per sub-agent.
    pub default_max_tokens: u32,
    /// Timeout per sub-agent in milliseconds.
    pub timeout_ms: u64,
}

impl Default for MoaConfig {
    fn default() -> Self {
        Self {
            model: "anthropic/claude-sonnet-4-6".to_string(),
            max_parallel: 8,
            default_max_tokens: 2048,
            timeout_ms: 30_000,
        }
    }
}

// MARK: - Pool Execution

/// Execute N sub-agent tasks in parallel using rayon's work-stealing pool.
///
/// Each task runs independently on a separate thread. Results are collected
/// and a simple consensus reducer picks the longest non-error response
/// (a placeholder for more sophisticated voting/ranking).
///
/// The actual HTTP calls to the LLM API are NOT implemented here —
/// they must be provided by the caller via the `executor` closure.
/// This keeps the MoA pool generic and testable.
pub fn execute_pool(
    tasks: Vec<MoaTask>,
    config: &MoaConfig,
    executor: impl Fn(&MoaTask, &MoaConfig) -> MoaResult + Sync + Send,
) -> MoaPoolResult {
    let start = Instant::now();
    let succeeded = AtomicUsize::new(0);
    let failed = AtomicUsize::new(0);

    // Cap parallelism at config limit and available cores
    let pool_size = config.max_parallel.min(rayon::current_num_threads());
    let tasks_to_run: Vec<_> = tasks.into_iter().take(pool_size).collect();

    // Execute in parallel via rayon
    let results: Vec<MoaResult> = tasks_to_run
        .par_iter()
        .map(|task| {
            let result = executor(task, config);
            if result.success {
                succeeded.fetch_add(1, Ordering::Relaxed);
            } else {
                failed.fetch_add(1, Ordering::Relaxed);
            }
            result
        })
        .collect();

    // Simple consensus: pick the longest successful response
    let consensus = results
        .iter()
        .filter(|r| r.success)
        .max_by_key(|r| r.response.len())
        .map(|r| r.response.clone());

    MoaPoolResult {
        results,
        consensus,
        total_latency_ms: start.elapsed().as_millis() as u64,
        tasks_succeeded: succeeded.load(Ordering::Relaxed),
        tasks_failed: failed.load(Ordering::Relaxed),
    }
}

// MARK: - UniFFI Surface

/// Execute a MoA pool from Swift via UniFFI.
/// Takes JSON-encoded tasks and config, returns JSON-encoded results.
///
/// The actual LLM API calls are stubbed here — in production, Swift
/// will provide the HTTP executor via the MCP bridge callback pattern.
pub fn moa_execute_pool(tasks_json: &str, config_json: &str) -> String {
    let tasks: Vec<MoaTask> = match serde_json::from_str(tasks_json) {
        Ok(t) => t,
        Err(e) => return format!("{{\"error\":\"Invalid tasks JSON: {e}\"}}"),
    };
    let config: MoaConfig = match serde_json::from_str(config_json) {
        Ok(c) => c,
        Err(_) => MoaConfig::default(),
    };

    // Stub executor — returns placeholder results.
    // In production, Swift will route each task through the Hermes bridge
    // or directly to the LLM API via URLSession.
    let result = execute_pool(tasks, &config, |task, _cfg| {
        MoaResult {
            task_id: task.id.clone(),
            response: String::new(),
            model: task.model.clone().unwrap_or_default(),
            input_tokens: 0,
            output_tokens: 0,
            latency_ms: 0,
            success: false,
            error: Some("Stub executor — wire HTTP calls via MCP bridge".to_string()),
        }
    });

    serde_json::to_string(&result).unwrap_or_else(|e| format!("{{\"error\":\"{e}\"}}"))
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn test_parallel_execution() {
        let call_count = AtomicU32::new(0);

        let tasks = (0..4)
            .map(|i| MoaTask {
                id: format!("task-{i}"),
                prompt: format!("Test prompt {i}"),
                model: None,
                max_tokens: None,
            })
            .collect();

        let config = MoaConfig {
            max_parallel: 4,
            ..Default::default()
        };

        let result = execute_pool(tasks, &config, |task, _| {
            call_count.fetch_add(1, Ordering::Relaxed);
            MoaResult {
                task_id: task.id.clone(),
                response: format!("Response for {}", task.id),
                model: "test".to_string(),
                input_tokens: 10,
                output_tokens: 20,
                latency_ms: 1,
                success: true,
                error: None,
            }
        });

        assert_eq!(call_count.load(Ordering::Relaxed), 4);
        assert_eq!(result.tasks_succeeded, 4);
        assert_eq!(result.tasks_failed, 0);
        assert_eq!(result.results.len(), 4);
        assert!(result.consensus.is_some());
    }

    #[test]
    fn test_consensus_picks_longest() {
        let tasks = vec![
            MoaTask { id: "a".into(), prompt: "".into(), model: None, max_tokens: None },
            MoaTask { id: "b".into(), prompt: "".into(), model: None, max_tokens: None },
        ];
        let config = MoaConfig::default();

        let result = execute_pool(tasks, &config, |task, _| {
            let response = if task.id == "b" { "longer response wins".to_string() } else { "short".to_string() };
            MoaResult {
                task_id: task.id.clone(),
                response,
                model: "test".to_string(),
                input_tokens: 0,
                output_tokens: 0,
                latency_ms: 0,
                success: true,
                error: None,
            }
        });

        assert_eq!(result.consensus.unwrap(), "longer response wins");
    }

    #[test]
    fn test_caps_at_max_parallel() {
        let tasks: Vec<_> = (0..20)
            .map(|i| MoaTask { id: format!("{i}"), prompt: "".into(), model: None, max_tokens: None })
            .collect();
        let config = MoaConfig { max_parallel: 3, ..Default::default() };

        let result = execute_pool(tasks, &config, |task, _| {
            MoaResult {
                task_id: task.id.clone(),
                response: "ok".into(),
                model: "test".into(),
                input_tokens: 0,
                output_tokens: 0,
                latency_ms: 0,
                success: true,
                error: None,
            }
        });

        assert_eq!(result.results.len(), 3);
    }

    #[test]
    fn test_mixed_success_failure() {
        let tasks = vec![
            MoaTask { id: "ok".into(), prompt: "".into(), model: None, max_tokens: None },
            MoaTask { id: "fail".into(), prompt: "".into(), model: None, max_tokens: None },
        ];
        let config = MoaConfig::default();

        let result = execute_pool(tasks, &config, |task, _| {
            if task.id == "fail" {
                MoaResult {
                    task_id: task.id.clone(), response: String::new(), model: "test".into(),
                    input_tokens: 0, output_tokens: 0, latency_ms: 0,
                    success: false, error: Some("boom".into()),
                }
            } else {
                MoaResult {
                    task_id: task.id.clone(), response: "good".into(), model: "test".into(),
                    input_tokens: 0, output_tokens: 0, latency_ms: 0,
                    success: true, error: None,
                }
            }
        });

        assert_eq!(result.tasks_succeeded, 1);
        assert_eq!(result.tasks_failed, 1);
        assert_eq!(result.consensus.unwrap(), "good");
    }
}
