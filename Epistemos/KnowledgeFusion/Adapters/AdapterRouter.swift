import Foundation

// MARK: - Routing Mode

enum AdapterRoutingMode: Sendable {
    /// User explicitly selects an adapter from the UI.
    case explicit(adapterId: UUID)

    /// Automatic routing: classify prompt and select appropriate adapter type.
    case automatic

    /// No adapter — use base model only.
    case none

    /// MoLoRA per-token routing (scaffold only — see TODO below).
    case moloraPerToken
}

// MARK: - AdapterRouter

/// Selects which adapter(s) to use for a given inference request.
///
/// ANCHOR 1 Subsystem 5: Dynamic Inference and Routing.
/// ANCHOR 3 GAP 1: NEVER fuse adapters permanently into base weights.
nonisolated struct AdapterRouter: Sendable {

    // MARK: - Mode A: Explicit

    /// Returns the adapter ID selected by the user.
    func routeExplicit(adapterId: UUID) -> UUID {
        adapterId
    }

    // MARK: - Mode B: Automatic

    /// Classifies the prompt via Rust FFI and returns the recommended adapter type.
    @MainActor func routeAutomatic(prompt: String) -> AdapterType? {
        let decision = routePrompt(prompt: prompt)

        // Only route if confidence is sufficient
        guard decision.confidence >= 0.6 else { return nil }

        switch decision.adapterType {
        case "style": return .style
        case "tool": return .tool
        case "knowledge": return .knowledge
        default: return nil
        }
    }

    // MARK: - Mode C: MoLoRA Scaffold

    // TODO: MoLoRA per-token routing requires custom MLX Metal kernel.
    // Scaffold complete. Full implementation blocked pending kernel availability.
    //
    // The research paper describes MoLoRA/HMoRA architecture where multiple
    // adapters are loaded simultaneously and a lightweight routing function
    // evaluates each token to select the appropriate adapter per-token.
    //
    // Interface definition:
    // func routeToken(token: Int, context: [Int]) -> UUID?
    //
    // This requires:
    // 1. Custom MLX Metal kernel for per-token adapter selection
    // 2. Modified attention computation that switches LoRA weights mid-sequence
    // 3. Token-level routing classifier trained on adapter domain labels
    //
    // Until these prerequisites are available, use Mode A (explicit) or
    // Mode B (automatic per-request) routing instead.

    /// MoLoRA per-token routing is handled by the Python-side AdaFuse router
    /// in MoLoRAInferenceService. This Swift-side method is not used directly —
    /// the routing decision happens inside molora_inference.py at layer 0.
    /// See MoLoRAInferenceService.generate() for the actual routing path.
    func routeToken(token: Int, context: [Int]) -> UUID? {
        nil  // Routing handled by Python-side AdaFuse in MoLoRAInferenceService
    }
}
