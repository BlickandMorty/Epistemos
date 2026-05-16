use serde::Serialize;

use crate::types::TokenUsage;

pub const PRICING_LAST_VERIFIED_ISO8601: &str = "2026-05-04";

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ProviderPricing {
    pub canonical_name: &'static str,
    pub aliases: &'static [&'static str],
    pub input_usd_per_mtok: f64,
    pub output_usd_per_mtok: f64,
    pub cache_creation_usd_per_mtok: Option<f64>,
    pub cache_read_usd_per_mtok: Option<f64>,
    pub request_usd_per_1k: Option<f64>,
    pub last_verified_iso8601: &'static str,
    pub source_url: &'static str,
}

const PRICING_TABLE: &[ProviderPricing] = &[
    ProviderPricing {
        canonical_name: "claude-sonnet-4-6",
        aliases: &["claude_sonnet", "claude-sonnet", "anthropic-sonnet"],
        input_usd_per_mtok: 3.0,
        output_usd_per_mtok: 15.0,
        cache_creation_usd_per_mtok: Some(3.75),
        cache_read_usd_per_mtok: Some(0.30),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://www.anthropic.com/claude/sonnet",
    },
    ProviderPricing {
        canonical_name: "claude-opus-4-6",
        aliases: &["claude_opus", "claude-opus", "anthropic-opus"],
        input_usd_per_mtok: 5.0,
        output_usd_per_mtok: 25.0,
        cache_creation_usd_per_mtok: Some(6.25),
        cache_read_usd_per_mtok: Some(0.50),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://www.anthropic.com/claude/opus",
    },
    ProviderPricing {
        canonical_name: "sonar-pro",
        aliases: &["perplexity", "perplexity-sonar-pro"],
        input_usd_per_mtok: 3.0,
        output_usd_per_mtok: 15.0,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: None,
        request_usd_per_1k: Some(14.0),
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://docs.perplexity.ai/docs/sonar/models/sonar-pro",
    },
    ProviderPricing {
        canonical_name: "codex-mini-latest",
        aliases: &["codex", "openai-codex", "codex-mini"],
        input_usd_per_mtok: 1.50,
        output_usd_per_mtok: 6.0,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.375),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://openai.com/index/introducing-codex/",
    },
    ProviderPricing {
        canonical_name: "gpt-5.5",
        aliases: &["openai", "openai_gpt55", "gpt5.5"],
        input_usd_per_mtok: 5.0,
        output_usd_per_mtok: 30.0,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.50),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://openai.com/api/pricing/",
    },
    ProviderPricing {
        canonical_name: "gemini-2.5-flash",
        aliases: &["gemini", "gemini_flash", "google-gemini"],
        input_usd_per_mtok: 0.30,
        output_usd_per_mtok: 2.50,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.03),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://ai.google.dev/gemini-api/docs/pricing",
    },
    ProviderPricing {
        canonical_name: "kimi-k2.5",
        aliases: &["kimi-k2.5", "moonshot-k2.5"],
        input_usd_per_mtok: 0.60,
        output_usd_per_mtok: 3.0,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.10),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://platform.kimi.ai/docs/pricing/chat-k25",
    },
    ProviderPricing {
        canonical_name: "kimi-k2.6",
        aliases: &[
            "kimi",
            "moonshot",
            "kimi-latest",
            "kimi_latest",
            "kimi-k2.6",
            "moonshot-k2.6",
        ],
        input_usd_per_mtok: 0.95,
        output_usd_per_mtok: 4.0,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.16),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://platform.kimi.ai/docs/pricing/chat-k26",
    },
    ProviderPricing {
        canonical_name: "kimi-k2-0905-preview",
        aliases: &["kimi-k2", "kimi_k2", "moonshot-k2"],
        input_usd_per_mtok: 0.60,
        output_usd_per_mtok: 2.50,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.15),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "https://platform.kimi.ai/docs/pricing/chat-k2",
    },
    ProviderPricing {
        canonical_name: "codestral-latest",
        aliases: &["codestral", "codestral_latest", "codestral-2508"],
        input_usd_per_mtok: 0.30,
        output_usd_per_mtok: 0.90,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: Some(0.03),
        request_usd_per_1k: None,
        last_verified_iso8601: "2026-05-16",
        source_url: "https://docs.mistral.ai/models/model-cards/codestral-25-08",
    },
    ProviderPricing {
        canonical_name: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        aliases: &[
            "together",
            "together_latest",
            "together-llama-3.3-70b",
            "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        ],
        input_usd_per_mtok: 0.88,
        output_usd_per_mtok: 0.88,
        cache_creation_usd_per_mtok: None,
        cache_read_usd_per_mtok: None,
        request_usd_per_1k: None,
        last_verified_iso8601: "2026-05-16",
        source_url: "https://www.together.ai/pricing",
    },
    ProviderPricing {
        canonical_name: "local",
        aliases: &["mlx", "local-qwen", "qwen"],
        input_usd_per_mtok: 0.0,
        output_usd_per_mtok: 0.0,
        cache_creation_usd_per_mtok: Some(0.0),
        cache_read_usd_per_mtok: Some(0.0),
        request_usd_per_1k: None,
        last_verified_iso8601: PRICING_LAST_VERIFIED_ISO8601,
        source_url: "local",
    },
];

pub fn all_pricing() -> &'static [ProviderPricing] {
    PRICING_TABLE
}

pub fn pricing_for(provider: &str) -> Option<&'static ProviderPricing> {
    let normalized = normalize_provider_name(provider);
    PRICING_TABLE.iter().find(|pricing| {
        pricing.canonical_name == normalized
            || pricing
                .aliases
                .iter()
                .any(|alias| normalized.starts_with(alias))
    })
}

pub fn estimate_usage_cost_usd(provider: &str, usage: &TokenUsage) -> f64 {
    let pricing = pricing_for(provider).unwrap_or_else(default_pricing);
    estimate_usage_cost_with_pricing(pricing, usage)
}

pub fn estimate_cost_usd(provider: &str, input_tokens: u32, output_tokens: u32) -> f64 {
    estimate_usage_cost_usd(
        provider,
        &TokenUsage {
            input_tokens,
            output_tokens,
            cache_creation_input_tokens: 0,
            cache_read_input_tokens: 0,
        },
    )
}

fn estimate_usage_cost_with_pricing(pricing: &ProviderPricing, usage: &TokenUsage) -> f64 {
    mtok_cost(usage.input_tokens, pricing.input_usd_per_mtok)
        + mtok_cost(
            usage.cache_creation_input_tokens,
            pricing
                .cache_creation_usd_per_mtok
                .unwrap_or(pricing.input_usd_per_mtok),
        )
        + mtok_cost(
            usage.cache_read_input_tokens,
            pricing
                .cache_read_usd_per_mtok
                .unwrap_or(pricing.input_usd_per_mtok),
        )
        + mtok_cost(usage.output_tokens, pricing.output_usd_per_mtok)
}

fn mtok_cost(tokens: u32, usd_per_mtok: f64) -> f64 {
    (tokens as f64 / 1_000_000.0) * usd_per_mtok
}

fn default_pricing() -> &'static ProviderPricing {
    pricing_for("claude-sonnet-4-6").expect("canonical fallback pricing must exist")
}

fn normalize_provider_name(provider: &str) -> String {
    provider.trim().to_ascii_lowercase().replace('_', "-")
}

pub fn budget_gate_payload_json(
    session_id: &str,
    provider: &str,
    current_spend_usd: f64,
    cap_usd: f64,
    next_gate_usd: f64,
) -> String {
    let payload = serde_json::json!({
        "tool_name": "budget_gate",
        "session_id": session_id,
        "provider": provider,
        "current_spend_usd": round_cents(current_spend_usd),
        "cap_usd": round_cents(cap_usd),
        "next_gate_usd": round_cents(next_gate_usd),
        "pricing_last_verified_iso8601": PRICING_LAST_VERIFIED_ISO8601,
    });
    serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
}

fn round_cents(value: f64) -> f64 {
    if value.is_finite() {
        (value * 100.0).round() / 100.0
    } else {
        0.0
    }
}

#[cfg(test)]
mod tests {
    use super::pricing_for;

    #[test]
    fn pricing_includes_codestral_latest_aliases() {
        let pricing = pricing_for("codestral_latest").expect("Codestral pricing row must exist");

        assert_eq!(pricing.canonical_name, "codestral-latest");
        assert_eq!(pricing.input_usd_per_mtok, 0.30);
        assert_eq!(pricing.output_usd_per_mtok, 0.90);
        assert_eq!(pricing.cache_read_usd_per_mtok, Some(0.03));
    }

    #[test]
    fn pricing_includes_together_latest_aliases() {
        let pricing = pricing_for("together").expect("Together pricing row must exist");

        assert_eq!(
            pricing.canonical_name,
            "meta-llama/Llama-3.3-70B-Instruct-Turbo"
        );
        assert_eq!(pricing.input_usd_per_mtok, 0.88);
        assert_eq!(pricing.output_usd_per_mtok, 0.88);
        assert_eq!(pricing.source_url, "https://www.together.ai/pricing");
    }
}
