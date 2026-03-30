// Usage cost tracking and dashboard data.
//
// Tracks per-provider, per-model token usage and computes costs.
// Pricing is maintained as a lookup table updated from provider docs.
// All costs are in USD micro-cents (millionths of a dollar) for integer arithmetic.
//
// The CostTracker accumulates across sessions and provides summary statistics
// for the usage cost dashboard.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Token usage for a single API call.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TokenUsage {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_creation_tokens: u64,
}

impl TokenUsage {
    pub fn total_tokens(&self) -> u64 {
        self.input_tokens + self.output_tokens + self.cache_read_tokens + self.cache_creation_tokens
    }
}

/// Cost breakdown for a usage period.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CostBreakdown {
    /// Cost in micro-dollars (1 micro-dollar = $0.000001).
    pub input_cost_microdollars: u64,
    pub output_cost_microdollars: u64,
    pub cache_read_cost_microdollars: u64,
    pub cache_creation_cost_microdollars: u64,
    pub total_cost_microdollars: u64,
}

impl CostBreakdown {
    /// Total cost in dollars as a float (for display).
    pub fn total_dollars(&self) -> f64 {
        self.total_cost_microdollars as f64 / 1_000_000.0
    }

    /// Format as a human-readable cost string.
    pub fn format_usd(&self) -> String {
        let dollars = self.total_dollars();
        if dollars < 0.01 {
            format!("${:.4}", dollars)
        } else {
            format!("${:.2}", dollars)
        }
    }
}

/// Per-model pricing in micro-dollars per token.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelPricing {
    pub model_id: String,
    pub input_per_token: u64,
    pub output_per_token: u64,
    pub cache_read_per_token: u64,
    pub cache_creation_per_token: u64,
}

/// Usage record for a single session or time period.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageRecord {
    pub model_id: String,
    pub provider: String,
    pub usage: TokenUsage,
    pub cost: CostBreakdown,
    pub timestamp: String,
    pub session_id: String,
    pub turn_count: u32,
}

/// Aggregate usage summary for the dashboard.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UsageSummary {
    pub total_cost: CostBreakdown,
    pub total_tokens: TokenUsage,
    pub total_turns: u32,
    pub total_sessions: u32,
    pub per_model: HashMap<String, CostBreakdown>,
    pub per_provider: HashMap<String, CostBreakdown>,
}

/// Cost tracker with pricing table and usage accumulation.
pub struct CostTracker {
    pricing: HashMap<String, ModelPricing>,
    records: Vec<UsageRecord>,
}

impl CostTracker {
    /// Create a new tracker with default pricing (March 2026 rates).
    pub fn new() -> Self {
        let mut tracker = Self {
            pricing: HashMap::new(),
            records: Vec::new(),
        };
        tracker.load_default_pricing();
        tracker
    }

    /// Record token usage for an API call and return the cost.
    pub fn record_usage(
        &mut self,
        model_id: &str,
        provider: &str,
        usage: TokenUsage,
        session_id: &str,
        turn_count: u32,
        timestamp: &str,
    ) -> CostBreakdown {
        let cost = self.calculate_cost(model_id, &usage);

        self.records.push(UsageRecord {
            model_id: model_id.to_string(),
            provider: provider.to_string(),
            usage,
            cost: cost.clone(),
            timestamp: timestamp.to_string(),
            session_id: session_id.to_string(),
            turn_count,
        });

        cost
    }

    /// Calculate cost for a given usage without recording it.
    pub fn calculate_cost(&self, model_id: &str, usage: &TokenUsage) -> CostBreakdown {
        let pricing = self.pricing.get(model_id)
            .or_else(|| {
                // Fuzzy match: try prefix matching
                self.pricing.iter()
                    .find(|(k, _)| model_id.starts_with(k.as_str()) || k.starts_with(model_id))
                    .map(|(_, v)| v)
            });

        match pricing {
            Some(p) => {
                let input = usage.input_tokens * p.input_per_token;
                let output = usage.output_tokens * p.output_per_token;
                let cache_read = usage.cache_read_tokens * p.cache_read_per_token;
                let cache_creation = usage.cache_creation_tokens * p.cache_creation_per_token;

                CostBreakdown {
                    input_cost_microdollars: input,
                    output_cost_microdollars: output,
                    cache_read_cost_microdollars: cache_read,
                    cache_creation_cost_microdollars: cache_creation,
                    total_cost_microdollars: input + output + cache_read + cache_creation,
                }
            }
            None => CostBreakdown::default(),
        }
    }

    /// Get aggregate usage summary.
    pub fn summary(&self) -> UsageSummary {
        let mut summary = UsageSummary::default();
        let mut sessions_seen = std::collections::HashSet::new();

        for record in &self.records {
            // Totals
            summary.total_cost.input_cost_microdollars += record.cost.input_cost_microdollars;
            summary.total_cost.output_cost_microdollars += record.cost.output_cost_microdollars;
            summary.total_cost.cache_read_cost_microdollars += record.cost.cache_read_cost_microdollars;
            summary.total_cost.cache_creation_cost_microdollars += record.cost.cache_creation_cost_microdollars;
            summary.total_cost.total_cost_microdollars += record.cost.total_cost_microdollars;

            summary.total_tokens.input_tokens += record.usage.input_tokens;
            summary.total_tokens.output_tokens += record.usage.output_tokens;
            summary.total_tokens.cache_read_tokens += record.usage.cache_read_tokens;
            summary.total_tokens.cache_creation_tokens += record.usage.cache_creation_tokens;

            summary.total_turns += record.turn_count;

            if sessions_seen.insert(record.session_id.clone()) {
                summary.total_sessions += 1;
            }

            // Per-model
            let model_entry = summary.per_model
                .entry(record.model_id.clone())
                .or_default();
            model_entry.total_cost_microdollars += record.cost.total_cost_microdollars;
            model_entry.input_cost_microdollars += record.cost.input_cost_microdollars;
            model_entry.output_cost_microdollars += record.cost.output_cost_microdollars;

            // Per-provider
            let provider_entry = summary.per_provider
                .entry(record.provider.clone())
                .or_default();
            provider_entry.total_cost_microdollars += record.cost.total_cost_microdollars;
            provider_entry.input_cost_microdollars += record.cost.input_cost_microdollars;
            provider_entry.output_cost_microdollars += record.cost.output_cost_microdollars;
        }

        summary
    }

    /// Get the number of recorded usage events.
    pub fn record_count(&self) -> usize {
        self.records.len()
    }

    /// Export all records as JSON.
    pub fn export_json(&self) -> String {
        serde_json::to_string_pretty(&self.records).unwrap_or_else(|_| "[]".to_string())
    }

    /// Clear all records.
    pub fn clear(&mut self) {
        self.records.clear();
    }

    // ── Pricing Table ──

    /// Load default pricing (per-token micro-dollars, verified March 2026).
    fn load_default_pricing(&mut self) {
        let models = vec![
            // Claude Opus 4.6: $15/$75 per MTok
            ModelPricing {
                model_id: "claude-opus-4-6".into(),
                input_per_token: 15,       // $15/MTok = 15 micro-dollars/token
                output_per_token: 75,      // $75/MTok
                cache_read_per_token: 2,   // $1.50/MTok
                cache_creation_per_token: 19, // $18.75/MTok
            },
            // Claude Sonnet 4.6: $3/$15 per MTok
            ModelPricing {
                model_id: "claude-sonnet-4-6".into(),
                input_per_token: 3,
                output_per_token: 15,
                cache_read_per_token: 0,   // $0.30/MTok rounds to 0 micro-dollars
                cache_creation_per_token: 4, // $3.75/MTok
            },
            // Claude Haiku 4.5: $0.80/$4 per MTok
            ModelPricing {
                model_id: "claude-haiku-4-5".into(),
                input_per_token: 1,        // $0.80/MTok rounds to 1
                output_per_token: 4,
                cache_read_per_token: 0,
                cache_creation_per_token: 1,
            },
            // Perplexity Sonar Pro: $3/$15 per MTok
            ModelPricing {
                model_id: "sonar-pro".into(),
                input_per_token: 3,
                output_per_token: 15,
                cache_read_per_token: 0,
                cache_creation_per_token: 0,
            },
            // Local models: $0
            ModelPricing {
                model_id: "local".into(),
                input_per_token: 0,
                output_per_token: 0,
                cache_read_per_token: 0,
                cache_creation_per_token: 0,
            },
        ];

        for model in models {
            self.pricing.insert(model.model_id.clone(), model);
        }
    }
}

impl Default for CostTracker {
    fn default() -> Self {
        Self::new()
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_cost_opus() {
        let tracker = CostTracker::new();
        let usage = TokenUsage {
            input_tokens: 1000,
            output_tokens: 500,
            cache_read_tokens: 0,
            cache_creation_tokens: 0,
        };
        let cost = tracker.calculate_cost("claude-opus-4-6", &usage);
        // 1000 * 15 + 500 * 75 = 15000 + 37500 = 52500 micro-dollars = $0.0525
        assert_eq!(cost.input_cost_microdollars, 15_000);
        assert_eq!(cost.output_cost_microdollars, 37_500);
        assert_eq!(cost.total_cost_microdollars, 52_500);
        assert!((cost.total_dollars() - 0.0525).abs() < 0.0001);
    }

    #[test]
    fn test_calculate_cost_with_cache() {
        let tracker = CostTracker::new();
        let usage = TokenUsage {
            input_tokens: 500,
            output_tokens: 200,
            cache_read_tokens: 2000,
            cache_creation_tokens: 1000,
        };
        let cost = tracker.calculate_cost("claude-opus-4-6", &usage);
        // 500*15 + 200*75 + 2000*2 + 1000*19 = 7500 + 15000 + 4000 + 19000 = 45500
        assert_eq!(cost.total_cost_microdollars, 45_500);
    }

    #[test]
    fn test_calculate_cost_local_is_free() {
        let tracker = CostTracker::new();
        let usage = TokenUsage {
            input_tokens: 10_000,
            output_tokens: 5_000,
            cache_read_tokens: 0,
            cache_creation_tokens: 0,
        };
        let cost = tracker.calculate_cost("local", &usage);
        assert_eq!(cost.total_cost_microdollars, 0);
    }

    #[test]
    fn test_calculate_cost_unknown_model() {
        let tracker = CostTracker::new();
        let usage = TokenUsage {
            input_tokens: 100,
            output_tokens: 50,
            ..Default::default()
        };
        let cost = tracker.calculate_cost("unknown-model-xyz", &usage);
        assert_eq!(cost.total_cost_microdollars, 0); // Unknown = free (safe default)
    }

    #[test]
    fn test_record_and_summary() {
        let mut tracker = CostTracker::new();

        tracker.record_usage(
            "claude-sonnet-4-6",
            "anthropic",
            TokenUsage { input_tokens: 1000, output_tokens: 500, ..Default::default() },
            "session-1",
            3,
            "2026-03-29T10:00:00Z",
        );

        tracker.record_usage(
            "claude-sonnet-4-6",
            "anthropic",
            TokenUsage { input_tokens: 2000, output_tokens: 1000, ..Default::default() },
            "session-1",
            5,
            "2026-03-29T10:05:00Z",
        );

        let summary = tracker.summary();
        assert_eq!(summary.total_sessions, 1); // Same session
        assert_eq!(summary.total_turns, 8); // 3 + 5
        assert_eq!(summary.total_tokens.input_tokens, 3000);
        assert_eq!(summary.total_tokens.output_tokens, 1500);
        assert!(summary.total_cost.total_cost_microdollars > 0);
        assert!(summary.per_model.contains_key("claude-sonnet-4-6"));
        assert!(summary.per_provider.contains_key("anthropic"));
    }

    #[test]
    fn test_multiple_sessions() {
        let mut tracker = CostTracker::new();

        tracker.record_usage(
            "claude-opus-4-6", "anthropic",
            TokenUsage { input_tokens: 100, output_tokens: 50, ..Default::default() },
            "s1", 1, "2026-03-29T10:00:00Z",
        );
        tracker.record_usage(
            "sonar-pro", "perplexity",
            TokenUsage { input_tokens: 200, output_tokens: 100, ..Default::default() },
            "s2", 1, "2026-03-29T11:00:00Z",
        );

        let summary = tracker.summary();
        assert_eq!(summary.total_sessions, 2);
        assert_eq!(summary.per_provider.len(), 2);
        assert_eq!(summary.per_model.len(), 2);
    }

    #[test]
    fn test_format_usd() {
        let cost = CostBreakdown {
            total_cost_microdollars: 52_500,
            ..Default::default()
        };
        assert_eq!(cost.format_usd(), "$0.05");

        let small_cost = CostBreakdown {
            total_cost_microdollars: 500,
            ..Default::default()
        };
        assert_eq!(small_cost.format_usd(), "$0.0005");
    }

    #[test]
    fn test_token_usage_total() {
        let usage = TokenUsage {
            input_tokens: 100,
            output_tokens: 50,
            cache_read_tokens: 200,
            cache_creation_tokens: 75,
        };
        assert_eq!(usage.total_tokens(), 425);
    }

    #[test]
    fn test_export_json() {
        let mut tracker = CostTracker::new();
        tracker.record_usage(
            "local", "local",
            TokenUsage { input_tokens: 100, output_tokens: 50, ..Default::default() },
            "s1", 1, "2026-03-29T10:00:00Z",
        );
        let json = tracker.export_json();
        assert!(json.contains("local"));
        assert!(json.contains("session_id"));
    }

    #[test]
    fn test_clear() {
        let mut tracker = CostTracker::new();
        tracker.record_usage(
            "local", "local",
            TokenUsage::default(), "s1", 1, "now",
        );
        assert_eq!(tracker.record_count(), 1);
        tracker.clear();
        assert_eq!(tracker.record_count(), 0);
    }

    #[test]
    fn test_fuzzy_model_match() {
        let tracker = CostTracker::new();
        // "claude-opus-4-6-20260315" should fuzzy-match "claude-opus-4-6"
        let usage = TokenUsage { input_tokens: 100, output_tokens: 50, ..Default::default() };
        let cost = tracker.calculate_cost("claude-opus-4-6-20260315", &usage);
        assert!(cost.total_cost_microdollars > 0, "Fuzzy match should find pricing");
    }
}
