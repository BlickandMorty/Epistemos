import Foundation
import OSLog

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
// THIS FILE is the runtime feature-flag + integration plumbing.
// The actual KIVIKVCache implementation lives in the local
// mlx-swift-lm fork at
// `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift`
// (lines 700-951 — sibling to the existing QuantizedKVCache class)
// and ships in a follow-up commit per the dossier's recommended
// sequencing (KIVI in pure MLX ops first to de-risk protocol fit).
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
}

public enum KIVIPreferences {

    private static let log = Logger(subsystem: "com.epistemos", category: "KIVIQuantization")
    private static let envFlag = "EPISTEMOS_KV_KIVI"

    /// Returns the resolved scheme for the current process. Honors
    /// the env-var feature flag first, then falls back to .affine.
    public static func currentScheme() -> KVQuantScheme {
        if let raw = ProcessInfo.processInfo.environment[envFlag], raw == "1" {
            log.info("KIVI active (EPISTEMOS_KV_KIVI=1)")
            return .kivi
        }
        return .affine
    }

    /// True when KIVI should be activated for a context length above
    /// the threshold. Per dossier: keep .affine for short prompts
    /// (<=4096 tokens) where KIVI's per-token decode tax (~5 tok/s)
    /// matters more than the memory saving.
    public static func shouldUseKIVI(forContextTokens contextTokens: Int) -> Bool {
        guard currentScheme() == .kivi else { return false }
        return contextTokens > 4_096
    }
}
