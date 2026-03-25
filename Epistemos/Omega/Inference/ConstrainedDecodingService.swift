import Foundation

// MARK: - Constrained Decoding Service

/// Protocol for grammar-constrained text generation.
/// The implementation hooks into MLX's logit processing to mask invalid tokens
/// at each decoding step, guaranteeing structurally valid output.
///
/// Phase Ω11: Scaffolding. The actual MLX logit processor binding requires
/// verifying mlx-swift-structured or implementing a custom logit mask (R1 research).
protocol GrammarConstrainedGenerator: Sendable {
    /// Generate text constrained to the given EBNF grammar.
    /// Returns only text that is valid according to the grammar rules.
    func generate(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String
}

/// Manages grammar compilation and constrained generation for Omega tool calls.
/// Caches compiled grammars to avoid recompilation on every request.
@MainActor @Observable
final class ConstrainedDecodingService {

    /// Whether constrained decoding is available (requires MLX logit processor support).
    private(set) var isAvailable: Bool = false

    /// The underlying generator (set when MLX constrained decoding is verified).
    private var generator: (any GrammarConstrainedGenerator)?

    /// Cached planning grammar (recompiled when tools change).
    private var cachedPlanningGrammar: ToolSchemaGrammar.CompiledGrammar?
    private var cachedToolSchemaHash: Int = 0

    /// Register a constrained generator implementation.
    /// Called after R1 research confirms the MLX logit processor API.
    func setGenerator(_ gen: any GrammarConstrainedGenerator) {
        generator = gen
        isAvailable = true
    }

    /// Generate a constrained plan (JSON array of steps) for a task.
    /// Falls back to unconstrained generation if constrained decoding is unavailable.
    func generateConstrainedPlan(
        prompt: String,
        systemPrompt: String?,
        toolSchemas: [[String: Any]],
        maxTokens: Int
    ) async throws -> String? {
        guard let generator else { return nil }

        let grammar = planningGrammar(for: toolSchemas)
        return try await generator.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            grammar: grammar,
            maxTokens: maxTokens
        )
    }

    /// Generate a constrained single tool call for device actions.
    func generateConstrainedToolCall(
        prompt: String,
        systemPrompt: String?,
        toolName: String,
        argumentSchema: [String: Any],
        maxTokens: Int
    ) async throws -> String? {
        guard let generator else { return nil }

        let grammar = ToolSchemaGrammar.compileSingleToolCallGrammar(
            toolName: toolName,
            argumentSchema: argumentSchema
        )
        return try await generator.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            grammar: grammar,
            maxTokens: maxTokens
        )
    }

    // MARK: - Grammar Caching

    private func planningGrammar(for schemas: [[String: Any]]) -> ToolSchemaGrammar.CompiledGrammar {
        let hash = schemas.description.hashValue
        if let cached = cachedPlanningGrammar, cachedToolSchemaHash == hash {
            return cached
        }
        let grammar = ToolSchemaGrammar.compilePlanningGrammar(toolSchemas: schemas)
        cachedPlanningGrammar = grammar
        cachedToolSchemaHash = hash
        return grammar
    }
}
