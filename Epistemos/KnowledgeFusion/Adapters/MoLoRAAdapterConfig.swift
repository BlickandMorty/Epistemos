import Foundation

// Relocated 2026-06-18 from the now-deleted MoLoRAInferenceService.swift (the
// orphaned molora_inference.py subprocess). MoLoRAAdapterConfig is the shared
// adapter descriptor used by AdapterRegistry (getActiveAdapterConfigs) — it
// outlives the Python service, which is replaced by the native NativeAdapterApply
// (LoRAContainer) path. Always-compiled, no MLX dependency.

struct MoLoRAAdapterConfig: Codable, Sendable {
    let path: String
    let type: String       // "knowledge", "style", "tool"
    let rank: Int
    let alpha: Int
}
