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

    /// Classifies the prompt and returns the recommended adapter type.
    func routeAutomatic(prompt: String) -> AdapterType? {
        let lower = prompt.lowercased()

        // Style cues: personal writing assistance
        let styleCues = [
            "help me write", "in my style", "rewrite this",
            "match my tone", "how would i say", "draft a",
            "writing style", "personal voice", "sound like me",
        ]
        if styleCues.contains(where: { lower.contains($0) }) {
            return .style
        }

        // Tool cues: API/code/function usage
        let toolCues = [
            "how to use", "api", "function", "endpoint",
            "code", "command", "script", "import", "install",
            "configure", "setup", "debug", "compile",
        ]
        let toolHits = toolCues.filter { lower.contains($0) }.count
        if toolHits >= 2 { return .tool }

        // Knowledge cues: factual lookup from vault
        let knowledgeCues = [
            "what is", "according to my notes", "from my vault",
            "what did i write about", "my research on",
            "remind me about", "summarize my notes on",
            "what do i know about",
        ]
        if knowledgeCues.contains(where: { lower.contains($0) }) {
            return .knowledge
        }

        // Default: no adapter (use base model)
        return nil
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

    /// Placeholder for MoLoRA per-token routing. Returns nil (not implemented).
    func routeToken(token: Int, context: [Int]) -> UUID? {
        // MoLoRA per-token routing not yet implemented.
        // See TODO above for prerequisites.
        nil
    }
}
