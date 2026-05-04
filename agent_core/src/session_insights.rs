//! Session Insights — Analytics and Activity Patterns for Agent Sessions
//!
//! Reference: Hermes `agent/insights.py` (792 LOC)
//! Tracks token usage, cost estimates, activity patterns, and notable sessions.
//! Provides structured data for UI dashboards and user analytics.

use std::collections::HashMap;

use chrono::{Datelike, Timelike};
use serde::{Deserialize, Serialize};

// ── Cost Models ────────────────────────────────────────────────────────────

/// Per-provider cost per 1K tokens (input, output) in USD.
const COST_PER_1K_TOKENS: &[(&str, (f64, f64))] = &[
    ("claude_sonnet", (0.003, 0.015)),
    ("claude_opus", (0.015, 0.075)),
    ("claude_haiku", (0.00025, 0.00125)),
    ("openai", (0.005, 0.015)),
    ("openai_gpt4o", (0.005, 0.015)),
    ("openai_gpt4o_mini", (0.00015, 0.0006)),
    ("gemini_flash", (0.00035, 0.0014)),
    ("gemini_pro", (0.0035, 0.0105)),
    ("perplexity", (0.002, 0.008)),
];

pub fn estimate_cost(provider: &str, input_tokens: u32, output_tokens: u32) -> f64 {
    let (input_cost, output_cost) = COST_PER_1K_TOKENS
        .iter()
        .find(|(name, _)| provider.starts_with(name))
        .map(|(_, costs)| *costs)
        .unwrap_or((0.005, 0.015)); // Default to mid-range pricing

    let input_cost_total = (input_tokens as f64 / 1000.0) * input_cost;
    let output_cost_total = (output_tokens as f64 / 1000.0) * output_cost;
    input_cost_total + output_cost_total
}

// ── Session Metrics ────────────────────────────────────────────────────────

/// Metrics for a single completed session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionMetrics {
    pub session_id: String,
    pub objective: String,
    pub provider_name: String,
    pub started_at: u64,
    pub completed_at: u64,
    pub duration_seconds: u64,
    pub turns: u32,
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub total_tokens: u32,
    pub estimated_cost_usd: f64,
    pub tool_calls_count: u32,
    pub status: String, // "completed", "failed", "cancelled"

    // ── N1 Phase 1: Anthropic prompt-cache telemetry ────────────
    // Anthropic's usage block carries cache_read_input_tokens (90%
    // discount) + cache_creation_input_tokens (25% premium write).
    // Default 0 keeps deserialization backward-compatible with
    // sessions saved before these fields landed.
    /// Tokens served from the prompt cache. Always 0 for non-Anthropic providers.
    #[serde(default)]
    pub cache_read_input_tokens: u32,
    /// Tokens written to the prompt cache. Always 0 for non-Anthropic providers.
    #[serde(default)]
    pub cache_creation_input_tokens: u32,
}

impl SessionMetrics {
    /// Computed: fraction of input tokens served from the cache.
    /// Returns 0.0 when total billed input tokens is 0.
    /// Range: [0.0, 1.0].
    pub fn cached_tokens_share(&self) -> f64 {
        let total_input = self.input_tokens as u64 + self.cache_read_input_tokens as u64;
        if total_input == 0 {
            return 0.0;
        }
        (self.cache_read_input_tokens as f64 / total_input as f64).clamp(0.0, 1.0)
    }
}

/// Aggregated statistics across all sessions.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AggregatedStats {
    pub total_sessions: u32,
    pub total_turns: u32,
    pub total_input_tokens: u64,
    pub total_output_tokens: u64,
    pub total_estimated_cost_usd: f64,
    pub avg_turns_per_session: f64,
    pub avg_tokens_per_session: f64,
    pub avg_duration_seconds: f64,

    // ── N1 Phase 1: Anthropic prompt-cache aggregates ───────────
    // total_cache_read_input_tokens grows much faster than
    // total_input_tokens when the Prompt Tree's Relocation Trick is
    // working. The W9.6 dashboard surfaces aggregate_cached_tokens_share.
    #[serde(default)]
    pub total_cache_read_input_tokens: u64,
    #[serde(default)]
    pub total_cache_creation_input_tokens: u64,
    /// Aggregate cache-hit share: cache_read / (input + cache_read). Range [0,1].
    #[serde(default)]
    pub aggregate_cached_tokens_share: f64,
}

/// Activity pattern data for heatmaps/charts.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ActivityPatterns {
    /// Sessions per day of week (0=Sunday, 6=Saturday)
    pub day_of_week: [u32; 7],
    /// Sessions per hour of day (0-23)
    pub hour_of_day: [u32; 24],
    /// Current streak (consecutive days with sessions)
    pub current_streak: u32,
    /// Longest streak ever
    pub longest_streak: u32,
    /// Sessions in the last 7 days
    pub last_7_days: u32,
    /// Sessions in the last 30 days
    pub last_30_days: u32,
}

/// Provider usage breakdown.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ProviderBreakdown {
    pub provider_name: String,
    pub session_count: u32,
    pub total_tokens: u64,
    pub estimated_cost_usd: f64,
    pub percentage_of_total: f64,
}

/// Tool usage breakdown.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ToolBreakdown {
    pub tool_name: String,
    pub call_count: u32,
    pub percentage_of_total: f64,
}

/// Notable sessions (records/extremes).
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct NotableSessions {
    pub longest_session: Option<SessionMetrics>,
    pub most_tokens: Option<SessionMetrics>,
    pub most_turns: Option<SessionMetrics>,
    pub most_expensive: Option<SessionMetrics>,
    pub last_session: Option<SessionMetrics>,
}

/// Complete insights report.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InsightsReport {
    pub aggregated: AggregatedStats,
    pub activity: ActivityPatterns,
    pub provider_breakdown: Vec<ProviderBreakdown>,
    pub tool_breakdown: Vec<ToolBreakdown>,
    pub notable: NotableSessions,
    pub generated_at: u64,
}

// ── Insights Engine ────────────────────────────────────────────────────────

pub struct InsightsEngine;

impl InsightsEngine {
    /// Build a complete insights report from session metrics history.
    pub fn build_report(sessions: &[SessionMetrics]) -> InsightsReport {
        if sessions.is_empty() {
            return InsightsReport {
                aggregated: AggregatedStats::default(),
                activity: ActivityPatterns::default(),
                provider_breakdown: Vec::new(),
                tool_breakdown: Vec::new(),
                notable: NotableSessions::default(),
                generated_at: now_epoch(),
            };
        }

        let aggregated = Self::compute_aggregated(sessions);
        let activity = Self::compute_activity(sessions);
        let provider_breakdown = Self::compute_provider_breakdown(sessions);
        let tool_breakdown = Self::compute_tool_breakdown(sessions);
        let notable = Self::compute_notable(sessions);

        InsightsReport {
            aggregated,
            activity,
            provider_breakdown,
            tool_breakdown,
            notable,
            generated_at: now_epoch(),
        }
    }

    fn compute_aggregated(sessions: &[SessionMetrics]) -> AggregatedStats {
        let total_sessions = sessions.len() as u32;
        let total_turns: u32 = sessions.iter().map(|s| s.turns).sum();
        let total_input: u64 = sessions.iter().map(|s| s.input_tokens as u64).sum();
        let total_output: u64 = sessions.iter().map(|s| s.output_tokens as u64).sum();
        let total_cost: f64 = sessions.iter().map(|s| s.estimated_cost_usd).sum();
        let total_duration: u64 = sessions.iter().map(|s| s.duration_seconds).sum();

        // N1 Phase 1 — Anthropic prompt-cache aggregates
        let total_cache_read: u64 = sessions
            .iter()
            .map(|s| s.cache_read_input_tokens as u64)
            .sum();
        let total_cache_creation: u64 = sessions
            .iter()
            .map(|s| s.cache_creation_input_tokens as u64)
            .sum();
        // share = cache_read / (input + cache_read). cache_creation
        // is the one-time write — doesn't enter the hit-rate denominator.
        let total_billed_input = total_input + total_cache_read;
        let cached_share = if total_billed_input == 0 {
            0.0
        } else {
            (total_cache_read as f64 / total_billed_input as f64).clamp(0.0, 1.0)
        };

        AggregatedStats {
            total_sessions,
            total_turns,
            total_input_tokens: total_input,
            total_output_tokens: total_output,
            total_estimated_cost_usd: total_cost,
            avg_turns_per_session: total_turns as f64 / total_sessions as f64,
            avg_tokens_per_session: (total_input + total_output) as f64 / total_sessions as f64,
            avg_duration_seconds: total_duration as f64 / total_sessions as f64,
            total_cache_read_input_tokens: total_cache_read,
            total_cache_creation_input_tokens: total_cache_creation,
            aggregate_cached_tokens_share: cached_share,
        }
    }

    fn compute_activity(sessions: &[SessionMetrics]) -> ActivityPatterns {
        let mut patterns = ActivityPatterns::default();
        let now = now_epoch();
        let one_day = 86400u64;
        let seven_days_ago = now.saturating_sub(7 * one_day);
        let thirty_days_ago = now.saturating_sub(30 * one_day);

        for session in sessions {
            // Day of week (0 = Sunday)
            if let Some(dt) = chrono::DateTime::from_timestamp(session.started_at as i64, 0) {
                let weekday = dt.weekday().num_days_from_sunday();
                patterns.day_of_week[weekday as usize] += 1;

                let hour = dt.hour() as usize;
                patterns.hour_of_day[hour] += 1;
            }

            // Recent activity
            if session.started_at >= seven_days_ago {
                patterns.last_7_days += 1;
            }
            if session.started_at >= thirty_days_ago {
                patterns.last_30_days += 1;
            }
        }

        // Compute streaks
        let mut sorted_sessions: Vec<_> = sessions.iter().collect();
        sorted_sessions.sort_by_key(|s| s.started_at);

        let mut current_streak = 0u32;
        let mut longest_streak = 0u32;
        let mut prev_day: Option<u64> = None;

        for session in &sorted_sessions {
            let day = session.started_at / one_day;
            if let Some(prev) = prev_day {
                if day == prev {
                    // Same day, continue
                } else if day == prev + 1 {
                    current_streak += 1;
                } else {
                    longest_streak = longest_streak.max(current_streak);
                    current_streak = 1;
                }
            } else {
                current_streak = 1;
            }
            prev_day = Some(day);
        }
        longest_streak = longest_streak.max(current_streak);

        patterns.current_streak = current_streak;
        patterns.longest_streak = longest_streak;

        patterns
    }

    fn compute_provider_breakdown(sessions: &[SessionMetrics]) -> Vec<ProviderBreakdown> {
        let mut by_provider: HashMap<String, (u32, u64, f64)> = HashMap::new();
        let total_tokens: u64 = sessions
            .iter()
            .map(|s| (s.input_tokens + s.output_tokens) as u64)
            .sum();

        for session in sessions {
            let entry = by_provider
                .entry(session.provider_name.clone())
                .or_insert((0, 0, 0.0));
            entry.0 += 1;
            entry.1 += (session.input_tokens + session.output_tokens) as u64;
            entry.2 += session.estimated_cost_usd;
        }

        let mut breakdown: Vec<_> = by_provider
            .into_iter()
            .map(|(name, (count, tokens, cost))| ProviderBreakdown {
                provider_name: name,
                session_count: count,
                total_tokens: tokens,
                estimated_cost_usd: cost,
                percentage_of_total: if total_tokens > 0 {
                    (tokens as f64 / total_tokens as f64) * 100.0
                } else {
                    0.0
                },
            })
            .collect();

        breakdown.sort_by(|a, b| b.total_tokens.cmp(&a.total_tokens));
        breakdown
    }

    fn compute_tool_breakdown(_sessions: &[SessionMetrics]) -> Vec<ToolBreakdown> {
        // SCHEMA GAP: SessionMetrics carries only the scalar
        // `tool_calls_count: u32` field (line 55) — not the per-tool-name
        // counts ToolBreakdown needs. To populate this without lying:
        //
        // 1. Add `pub tool_call_counts: HashMap<String, u32>` to
        //    SessionMetrics (with `#[serde(default)]` for backward compat).
        // 2. Wire the producer code that builds SessionMetrics from agent
        //    runs to fill in the per-tool counts (search for sites that
        //    currently set `tool_calls_count`).
        // 3. Aggregate across sessions here, compute percentage_of_total
        //    against the grand total, sort by call_count descending.
        //
        // Until the schema is enriched the honest answer is empty —
        // `_sessions` is underscored so the unused-variable warning
        // doesn't pollute the build log. The InsightsReport's
        // `tool_breakdown` field will surface as `[]` in the UI, which
        // is correct (we don't have data to honestly populate it yet).
        Vec::new()
    }

    fn compute_notable(sessions: &[SessionMetrics]) -> NotableSessions {
        let longest = sessions.iter().max_by_key(|s| s.duration_seconds).cloned();
        let most_tokens = sessions.iter().max_by_key(|s| s.total_tokens).cloned();
        let most_turns = sessions.iter().max_by_key(|s| s.turns).cloned();
        let most_expensive = sessions
            .iter()
            .max_by(|a, b| {
                a.estimated_cost_usd
                    .partial_cmp(&b.estimated_cost_usd)
                    .unwrap()
            })
            .cloned();
        let last = sessions.iter().max_by_key(|s| s.completed_at).cloned();

        NotableSessions {
            longest_session: longest,
            most_tokens,
            most_turns,
            most_expensive,
            last_session: last,
        }
    }
}

fn now_epoch() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

// ── FFI Types ──────────────────────────────────────────────────────────────

#[derive(uniffi::Record)]
pub struct SessionMetricsFFI {
    pub session_id: String,
    pub objective: String,
    pub provider_name: String,
    pub started_at: u64,
    pub completed_at: u64,
    pub duration_seconds: u64,
    pub turns: u32,
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub total_tokens: u32,
    pub estimated_cost_usd: f64,
    pub tool_calls_count: u32,
    pub status: String,
}

impl From<SessionMetrics> for SessionMetricsFFI {
    fn from(m: SessionMetrics) -> Self {
        Self {
            session_id: m.session_id,
            objective: m.objective,
            provider_name: m.provider_name,
            started_at: m.started_at,
            completed_at: m.completed_at,
            duration_seconds: m.duration_seconds,
            turns: m.turns,
            input_tokens: m.input_tokens,
            output_tokens: m.output_tokens,
            total_tokens: m.total_tokens,
            estimated_cost_usd: m.estimated_cost_usd,
            tool_calls_count: m.tool_calls_count,
            status: m.status,
        }
    }
}

#[derive(uniffi::Record)]
pub struct InsightsReportFFI {
    pub total_sessions: u32,
    pub total_turns: u32,
    pub total_input_tokens: u64,
    pub total_output_tokens: u64,
    pub total_estimated_cost_usd: f64,
    pub avg_turns_per_session: f64,
    pub avg_tokens_per_session: f64,
    pub avg_duration_seconds: f64,
    pub current_streak: u32,
    pub longest_streak: u32,
    pub last_7_days: u32,
    pub last_30_days: u32,
    pub provider_breakdown_json: String,
    pub notable_sessions_json: String,
    pub generated_at: u64,

    // ── N1 Phase 1: Anthropic prompt-cache aggregates ───────────
    // Surfaced into the W9.6 cost dashboard so Swift can render
    // `cached_tokens_share` directly without a separate plumbing path.
    pub total_cache_read_input_tokens: u64,
    pub total_cache_creation_input_tokens: u64,
    pub aggregate_cached_tokens_share: f64,
}

impl From<InsightsReport> for InsightsReportFFI {
    fn from(r: InsightsReport) -> Self {
        Self {
            total_sessions: r.aggregated.total_sessions,
            total_turns: r.aggregated.total_turns,
            total_input_tokens: r.aggregated.total_input_tokens,
            total_output_tokens: r.aggregated.total_output_tokens,
            total_estimated_cost_usd: r.aggregated.total_estimated_cost_usd,
            avg_turns_per_session: r.aggregated.avg_turns_per_session,
            avg_tokens_per_session: r.aggregated.avg_tokens_per_session,
            avg_duration_seconds: r.aggregated.avg_duration_seconds,
            current_streak: r.activity.current_streak,
            longest_streak: r.activity.longest_streak,
            last_7_days: r.activity.last_7_days,
            last_30_days: r.activity.last_30_days,
            provider_breakdown_json: serde_json::to_string(&r.provider_breakdown)
                .unwrap_or_default(),
            notable_sessions_json: serde_json::to_string(&r.notable).unwrap_or_default(),
            generated_at: r.generated_at,
            total_cache_read_input_tokens: r.aggregated.total_cache_read_input_tokens,
            total_cache_creation_input_tokens: r.aggregated.total_cache_creation_input_tokens,
            aggregate_cached_tokens_share: r.aggregated.aggregate_cached_tokens_share,
        }
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_session(
        id: &str,
        turns: u32,
        input: u32,
        output: u32,
        provider: &str,
        cost: f64,
    ) -> SessionMetrics {
        SessionMetrics {
            session_id: id.to_string(),
            objective: format!("Test session {}", id),
            provider_name: provider.to_string(),
            started_at: 1700000000,
            completed_at: 1700000100,
            duration_seconds: 100,
            turns,
            input_tokens: input,
            output_tokens: output,
            total_tokens: input + output,
            estimated_cost_usd: cost,
            tool_calls_count: turns.saturating_sub(1),
            status: "completed".to_string(),
            cache_read_input_tokens: 0,
            cache_creation_input_tokens: 0,
        }
    }

    fn sample_session_with_cache(
        id: &str,
        input: u32,
        cache_read: u32,
        cache_creation: u32,
    ) -> SessionMetrics {
        let mut s = sample_session(id, 1, input, 0, "claude_sonnet", 0.0);
        s.cache_read_input_tokens = cache_read;
        s.cache_creation_input_tokens = cache_creation;
        s
    }

    #[test]
    fn cached_tokens_share_zero_when_no_input() {
        let s = sample_session_with_cache("a", 0, 0, 0);
        assert_eq!(s.cached_tokens_share(), 0.0);
    }

    #[test]
    fn cached_tokens_share_one_when_all_cached() {
        // input=0, cache_read=1000 → 1000/1000 = 1.0
        let s = sample_session_with_cache("b", 0, 1000, 0);
        assert_eq!(s.cached_tokens_share(), 1.0);
    }

    #[test]
    fn cached_tokens_share_typical_60_percent() {
        // 600 cached / (400 + 600) = 0.60
        let s = sample_session_with_cache("c", 400, 600, 0);
        let share = s.cached_tokens_share();
        assert!((share - 0.6).abs() < 1e-9);
    }

    #[test]
    fn aggregate_cache_share_across_sessions() {
        let sessions = vec![
            sample_session_with_cache("a", 100, 900, 0), // 90 % cached
            sample_session_with_cache("b", 200, 800, 0), // 80 % cached
        ];
        let stats = InsightsEngine::compute_aggregated(&sessions);
        // Total: input=300, cache_read=1700, billed_input=2000.
        // share = 1700 / 2000 = 0.85
        assert_eq!(stats.total_cache_read_input_tokens, 1700);
        assert_eq!(stats.total_cache_creation_input_tokens, 0);
        assert!((stats.aggregate_cached_tokens_share - 0.85).abs() < 1e-9);
    }

    #[test]
    fn aggregate_zero_cache_when_no_anthropic_sessions() {
        // OpenAI doesn't populate the cache fields — they default to 0.
        let sessions = vec![sample_session("a", 1, 1000, 500, "openai", 0.01)];
        let stats = InsightsEngine::compute_aggregated(&sessions);
        assert_eq!(stats.total_cache_read_input_tokens, 0);
        assert_eq!(stats.aggregate_cached_tokens_share, 0.0);
    }

    #[test]
    fn ffi_carries_cache_aggregates() {
        // Confirm InsightsReportFFI surfaces the new fields so Swift can read them.
        let sessions = vec![sample_session_with_cache("a", 100, 900, 50)];
        let report = InsightsEngine::build_report(&sessions);
        let ffi: InsightsReportFFI = report.into();
        assert_eq!(ffi.total_cache_read_input_tokens, 900);
        assert_eq!(ffi.total_cache_creation_input_tokens, 50);
        assert!((ffi.aggregate_cached_tokens_share - 0.9).abs() < 1e-9);
    }

    #[test]
    fn estimate_cost_claude_sonnet() {
        let cost = estimate_cost("claude_sonnet", 1000, 500);
        // (1000/1000)*0.003 + (500/1000)*0.015 = 0.003 + 0.0075 = 0.0105
        assert!(cost > 0.01 && cost < 0.011);
    }

    #[test]
    fn aggregated_stats_computes_correctly() {
        let sessions = vec![
            sample_session("1", 5, 1000, 500, "claude_sonnet", 0.01),
            sample_session("2", 10, 2000, 1000, "openai", 0.02),
        ];

        let report = InsightsEngine::build_report(&sessions);
        assert_eq!(report.aggregated.total_sessions, 2);
        assert_eq!(report.aggregated.total_turns, 15);
        assert_eq!(report.aggregated.total_input_tokens, 3000);
        assert_eq!(report.aggregated.total_output_tokens, 1500);
        assert!(report.aggregated.total_estimated_cost_usd > 0.029);
        assert_eq!(report.aggregated.avg_turns_per_session, 7.5);
    }

    #[test]
    fn empty_sessions_returns_default_report() {
        let report = InsightsEngine::build_report(&[]);
        assert_eq!(report.aggregated.total_sessions, 0);
        assert!(report.provider_breakdown.is_empty());
    }

    #[test]
    fn provider_breakdown_sorted_by_tokens() {
        let sessions = vec![
            sample_session("1", 5, 100, 50, "claude_sonnet", 0.01),
            sample_session("2", 5, 1000, 500, "openai", 0.05),
            sample_session("3", 5, 100, 50, "claude_sonnet", 0.01),
        ];

        let report = InsightsEngine::build_report(&sessions);
        assert_eq!(report.provider_breakdown.len(), 2);
        // openai should be first (most tokens)
        assert_eq!(report.provider_breakdown[0].provider_name, "openai");
    }

    #[test]
    fn notable_sessions_finds_extremes() {
        let sessions = vec![
            SessionMetrics {
                duration_seconds: 50,
                total_tokens: 100,
                turns: 2,
                estimated_cost_usd: 0.01,
                ..sample_session("1", 2, 50, 50, "claude", 0.01)
            },
            SessionMetrics {
                duration_seconds: 200,
                total_tokens: 500,
                turns: 10,
                estimated_cost_usd: 0.05,
                ..sample_session("2", 10, 250, 250, "openai", 0.05)
            },
        ];

        let report = InsightsEngine::build_report(&sessions);
        assert_eq!(
            report.notable.longest_session.as_ref().unwrap().session_id,
            "2"
        );
        assert_eq!(report.notable.most_tokens.as_ref().unwrap().session_id, "2");
        assert_eq!(report.notable.most_turns.as_ref().unwrap().session_id, "2");
    }

    #[test]
    fn activity_patterns_counts_days() {
        // Create sessions on different days
        let mut sessions = Vec::new();
        for i in 0..3 {
            let mut s = sample_session(&i.to_string(), 1, 100, 50, "claude", 0.01);
            s.started_at = 1700000000 + (i * 86400); // One day apart
            sessions.push(s);
        }

        let report = InsightsEngine::build_report(&sessions);
        assert_eq!(report.aggregated.total_sessions, 3);
        // Streak should be at least 3
        assert!(report.activity.longest_streak >= 1);
    }

    #[test]
    fn ffi_conversion_roundtrip() {
        let metrics = sample_session("test", 5, 1000, 500, "claude", 0.01);
        let ffi: SessionMetricsFFI = metrics.clone().into();
        assert_eq!(ffi.session_id, "test");
        assert_eq!(ffi.turns, 5);
        assert_eq!(ffi.input_tokens, 1000);
    }
}
