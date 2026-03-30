import Foundation

// MARK: - Constrained Decoding Service

/// Protocol for grammar-constrained text generation.
/// Implementations should hook into MLX's logit processing to mask invalid tokens
/// at each decoding step. Only implementations that perform **real** token-level
/// masking should report `isFullyConstraining == true`.
///
/// Phase Ω11 status: Current `JSONSchemaLogitProcessor` only penalizes EOS tokens —
/// it does NOT perform grammar-aware masking. Constrained decoding is disabled
/// until a real masking implementation is available.
protocol GrammarConstrainedGenerator: Sendable {
    /// Whether this generator performs real token-level grammar masking.
    /// When false, the generator only applies soft guidance (e.g. EOS penalties)
    /// and cannot guarantee structurally valid output.
    var isFullyConstraining: Bool { get }

    /// Generate text guided by the given EBNF grammar.
    /// Only truly constraining generators guarantee valid output.
    func generate(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String
}

/// Manages grammar compilation and constrained generation for Omega tool calls.
/// Caches compiled grammars to avoid recompilation on every request.
///
/// `isAvailable` is only set to true when the registered generator reports
/// `isFullyConstraining == true`. Soft-guidance-only generators are rejected.
@MainActor @Observable
final class ConstrainedDecodingService {

    /// Whether constrained decoding is truly available.
    /// Only true when the generator performs real token-level grammar masking.
    private(set) var isAvailable: Bool = false

    /// The underlying generator (set only when it truly constrains).
    private var generator: (any GrammarConstrainedGenerator)?

    /// Cached planning grammar (recompiled when tools change).
    private var cachedPlanningGrammar: ToolSchemaGrammar.CompiledGrammar?
    private var cachedToolSchemaHash: Int = 0

    /// Register a constrained generator implementation.
    /// Only enables the constrained path if the generator truly constrains output.
    /// Generators that only apply soft guidance (e.g. EOS penalties) are stored
    /// but `isAvailable` remains false — the system will use unconstrained fallback.
    func setGenerator(_ gen: any GrammarConstrainedGenerator) {
        generator = gen
        isAvailable = gen.isFullyConstraining
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

    /// Reuse the existing constrained-decoding runtime with a precompiled grammar
    /// from another subsystem. Returns `nil` unless the registered generator
    /// performs real token-level masking.
    func generateCompiledGrammarOutput(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String? {
        guard let generator, isAvailable else { return nil }

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
