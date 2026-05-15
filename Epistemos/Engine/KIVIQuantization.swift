import Foundation

// SCAFFOLD ONLY — RCA-P2-010 classification 2026-05-14.
//
// 0 external Swift callers as of audit 2026-05-14. App-side
// runtime feature-flag + integration plumbing for the W9.30 KIVI
// 2-bit asymmetric KV-cache quantizer. The real KIVIKVCache class
// lives in the local mlx-swift-lm fork; this file is the activation
// shim. Re-promote when the env-var path is wired into the MLX
// runtime entry point AND a perplexity regression test gates the
// default-on flip.
//
// MARK: - W9.30 — KIVI per-channel/per-token KV quantization
//
// SCAFFOLD per docs/RESEARCH_DOSSIER_TIER_3_4.md §W9.30:
//
// KIVI (Liu et al., ICML 2024 — "KIVI: A Tuning-Free Asymmetric
// 2-bit Quantization for KV Cache") quantizes Key per-CHANNEL and
// Value per-TOKEN at 2 bits. Asymmetry matters because outliers
// distribute differently across the two tensors. ~13 % of FP16
// footprint at 8K context for Qwen3.5 7B GQA = ~58 MB instead of
// 448 MB → frees ~390 MB → enables 16K-32K context on 16 GB Macs.
//
// THIS FILE is the app-side runtime feature-flag + integration plumbing.
// The actual KIVIKVCache implementation lives in the local mlx-swift-lm fork at
// `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift`
// as a sibling to the existing QuantizedKVCache class.
//
// Activation contract:
//   `EPISTEMOS_KV_KIVI=1` env var → opt-in for the 16 GB Mac path.
//   Default (.affine) is preserved so an experimental KIVI bug
//   never silently degrades the user's daily inference.
//
// Mitigations baked in here per dossier:
//   - Never default-on without a perplexity regression test pass.
//   - Don't combine sliding window + KIVI in v1 — RotatingKVCache
//     already fatalErrors when toQuantized is called, so the guard
//     is upstream.
//   - Tokenizer-state and prompt-cache files use `KIVIKVCache` as
//     the dispatch class name; older saved caches with `QuantizedKVCache`
//     stay loadable via the existing affine path.

public enum KVQuantScheme: String, Sendable, CaseIterable {
    /// Today's default — symmetric per-group affine quantization.
    case affine
    /// W9.30 — KIVI per-channel K + per-token V (2-bit).
    case kivi
    /// Future — TurboQuant turbo4v2 fused Metal kernel
    /// (arozanov/turboquant-mlx port; 4-bit K + 2-bit V).
    case turboQuantV4V2

    var displayLabel: String {
        switch self {
        case .affine:
            "4-bit affine"
        case .kivi:
            "2-bit KIVI"
        case .turboQuantV4V2:
            "TurboQuant v4/v2"
        }
    }
}

public enum KIVIPreferences {

    private nonisolated static let envFlag = "EPISTEMOS_KV_KIVI"

    /// Returns the resolved scheme for the current process. Honors
    /// the env-var feature flag first, then falls back to .affine.
    public nonisolated static func currentScheme() -> KVQuantScheme {
        if let raw = ProcessInfo.processInfo.environment[envFlag], raw == "1" {
            return .kivi
        }
        return .affine
    }

    /// True when KIVI should be activated for a context length above
    /// the threshold. Per dossier: keep .affine for short prompts
    /// (<=4096 tokens) where KIVI's per-token decode tax (~5 tok/s)
    /// matters more than the memory saving.
    public nonisolated static func shouldUseKIVI(forContextTokens contextTokens: Int) -> Bool {
        guard currentScheme() == .kivi else { return false }
        return contextTokens > 4_096
    }
}
