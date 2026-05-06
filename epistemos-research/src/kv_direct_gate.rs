//! HELIOS V5 — KV-Direct gate substrate (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-KV-DIRECT-GATE guard
//!
//! Per HELIOS v4 preservation `source_docs/helios_v3.md` Part V
//! "Sharpest Next Move" + Qasim et al. arXiv:2603.19664 v3
//! ("KV-Direct: The Residual Stream Is All You Need", 20 Mar 2026).
//!
//! ## The single sharpest experiment
//!
//! From the doctrine:
//!
//! > "Run KV-Direct (Qasim et al. arXiv:2603.19664) on
//! >  Qwen3-8B-MLX-4bit at 128k context BEFORE writing any
//! >  L2/L3/L_SE code. Binary outcome:
//! >   PASS → L1 (Sherry on residual) is justified; build the rest.
//! >   FAIL → Reconsider L1 architecture before any L2/L3/L_SE code."
//!
//! ## Decision rule (canonical)
//!
//! Acceptance gate is BINARY:
//!
//!   D_KL == 0.0  AND  peak_ram_reduction_factor >= 8.0
//!
//! Per Qasim Theorem 1: greedy-token-identical match means K, V
//! are bit-identical projections of the residual stream. The 8×
//! peak-RAM factor is the canonical threshold for "this is worth
//! shipping."
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// Canonical RAM-reduction factor required for KV-Direct gate
/// acceptance (≥ 8× vs full-cache baseline).
pub const PEAK_RAM_REDUCTION_FACTOR_MIN: f32 = 8.0;

/// Canonical D_KL threshold for KV-Direct gate. Exact 0.0 (greedy
/// token-identical match) per Qasim Theorem 1.
pub const D_KL_THRESHOLD: f32 = 0.0;

/// Observed metrics from one KV-Direct gate run on
/// Qwen3-8B-MLX-4bit at 128k context.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct KvDirectMeasurements {
    /// Output-distribution KL divergence vs full-cache baseline.
    /// Must be EXACTLY 0.0 for PASS (greedy token-identical match).
    pub d_kl: f32,
    /// Peak-RAM reduction factor (full-cache_RAM / kv_direct_RAM).
    pub peak_ram_reduction_factor: f32,
    /// Observed decode throughput (tokens / second).
    pub decode_tok_per_sec: f32,
    /// Observed end-to-end 128k prefill latency (seconds).
    pub prefill_latency_sec: f32,
}

/// Decision outcome for one KV-Direct gate run.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvDirectDecision {
    /// PASS — proceed to build L2/L3/L_SE on top.
    Pass,
    /// FAIL — reconsider L1 architecture before any L2/L3/L_SE code.
    Fail,
}

/// Apply the canonical decision rule.
pub fn evaluate(measurements: &KvDirectMeasurements) -> KvDirectDecision {
    // D_KL must be EXACTLY 0.0 (greedy token-identical match).
    let kl_passes = measurements.d_kl.is_finite() && measurements.d_kl == D_KL_THRESHOLD;
    // Peak-RAM reduction must be >= 8×.
    let ram_passes = measurements.peak_ram_reduction_factor.is_finite()
        && measurements.peak_ram_reduction_factor >= PEAK_RAM_REDUCTION_FACTOR_MIN;
    if kl_passes && ram_passes {
        KvDirectDecision::Pass
    } else {
        KvDirectDecision::Fail
    }
}

/// Canonical Week-1 protocol context for the KV-Direct gate.
///
/// Only `Serialize` is derived: the struct holds a `&'static str`
/// reference to the binary's const pool and cannot be deserialized
/// from a borrowed JSON buffer (same caveat as
/// `theorem_status::TheoremStatusEntry`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
pub struct KvDirectProtocol {
    /// Target model — pinned at Qwen3-8B-MLX-4bit per the doctrine.
    pub model: &'static str,
    /// Context length in tokens — pinned at 128k.
    pub context_length: u32,
    /// Number of test prompts — pinned at 200 (RULER subset).
    pub prompt_count: u32,
}

impl KvDirectProtocol {
    /// Canonical Week-1 protocol per helios_v3 §V.
    pub const CANONICAL: KvDirectProtocol = KvDirectProtocol {
        model: "Qwen3-8B-MLX-4bit",
        context_length: 128 * 1024,
        prompt_count: 200,
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_thresholds_match_doctrine() {
        assert_eq!(D_KL_THRESHOLD, 0.0);
        assert_eq!(PEAK_RAM_REDUCTION_FACTOR_MIN, 8.0);
    }

    #[test]
    fn canonical_protocol_uses_qwen3_8b_at_128k() {
        let p = KvDirectProtocol::CANONICAL;
        assert_eq!(p.model, "Qwen3-8B-MLX-4bit");
        assert_eq!(p.context_length, 128 * 1024);
        assert_eq!(p.prompt_count, 200);
    }

    #[test]
    fn pass_when_kl_zero_and_ram_reduction_meets_minimum() {
        let m = KvDirectMeasurements {
            d_kl: 0.0,
            peak_ram_reduction_factor: 8.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&m), KvDirectDecision::Pass);
    }

    #[test]
    fn pass_when_ram_reduction_exceeds_minimum() {
        let m = KvDirectMeasurements {
            d_kl: 0.0,
            peak_ram_reduction_factor: 12.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&m), KvDirectDecision::Pass);
    }

    #[test]
    fn fail_when_kl_nonzero() {
        let m = KvDirectMeasurements {
            d_kl: 0.001,
            peak_ram_reduction_factor: 12.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&m), KvDirectDecision::Fail);
    }

    #[test]
    fn fail_when_ram_reduction_below_minimum() {
        let m = KvDirectMeasurements {
            d_kl: 0.0,
            peak_ram_reduction_factor: 7.5,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&m), KvDirectDecision::Fail);
    }

    #[test]
    fn fail_when_kl_nan_or_infinity() {
        let nan = KvDirectMeasurements {
            d_kl: f32::NAN,
            peak_ram_reduction_factor: 12.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&nan), KvDirectDecision::Fail);
        let inf = KvDirectMeasurements {
            d_kl: f32::INFINITY,
            peak_ram_reduction_factor: 12.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&inf), KvDirectDecision::Fail);
    }

    #[test]
    fn fail_when_ram_reduction_nan() {
        let m = KvDirectMeasurements {
            d_kl: 0.0,
            peak_ram_reduction_factor: f32::NAN,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        assert_eq!(evaluate(&m), KvDirectDecision::Fail);
    }

    #[test]
    fn decision_serializes_in_snake_case() {
        assert_eq!(serde_json::to_string(&KvDirectDecision::Pass).unwrap(), "\"pass\"");
        assert_eq!(serde_json::to_string(&KvDirectDecision::Fail).unwrap(), "\"fail\"");
    }

    #[test]
    fn measurements_round_trip_through_json() {
        let m = KvDirectMeasurements {
            d_kl: 0.0,
            peak_ram_reduction_factor: 12.0,
            decode_tok_per_sec: 25.0,
            prefill_latency_sec: 30.0,
        };
        let json = serde_json::to_string(&m).unwrap();
        let parsed: KvDirectMeasurements = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, m);
    }

    #[test]
    fn protocol_serializes_to_json_with_canonical_model() {
        // KvDirectProtocol holds a &'static str; only Serialize is
        // derived (not Deserialize) so we verify the export side.
        let p = KvDirectProtocol::CANONICAL;
        let json = serde_json::to_string(&p).unwrap();
        assert!(json.contains("Qwen3-8B-MLX-4bit"));
        assert!(json.contains("131072")); // 128 * 1024
    }
}
