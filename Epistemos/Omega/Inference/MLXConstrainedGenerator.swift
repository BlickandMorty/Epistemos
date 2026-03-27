import Foundation
import os

#if canImport(MLX)
@preconcurrency import MLX
#endif
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if canImport(MLXLLM)
import MLXLLM
#endif

// MARK: - MLX Constrained Generator

/// Implements `GrammarConstrainedGenerator` using MLXLMCommon's `LogitProcessor` hook.
/// Creates a `TokenIterator` with a custom `JSONSchemaLogitProcessor` that applies
/// soft guidance (EOS penalties) but does NOT perform true grammar-aware masking.
///
/// Status: `isFullyConstraining = false` — this generator cannot guarantee
/// structurally valid JSON. It only penalizes premature EOS tokens.
/// Real constrained decoding requires vocabulary access to build per-state
/// allowed-token masks, which is not yet implemented.
///
/// Integration: TokenIterator.init(input:model:cache:processor:sampler:prefillStepSize:maxTokens:)
/// accepts a custom `LogitProcessor` — we inject our soft-guidance processor there.
#if canImport(MLXLMCommon)
@MainActor
final class MLXConstrainedGenerator: GrammarConstrainedGenerator {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "ConstrainedGen")
    private let inferenceService: MLXInferenceService

    /// Current implementation only applies soft EOS penalties, not real grammar masking.
    nonisolated let isFullyConstraining: Bool = false

    nonisolated init(inferenceService: MLXInferenceService) {
        self.inferenceService = inferenceService
    }

    nonisolated func generate(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String {
        // Build the logit processor from the compiled grammar
        let processor = JSONSchemaLogitProcessor(grammar: grammar)

        // Generate using the inference service with our custom processor
        let result = try await inferenceService.generateConstrained(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            logitProcessor: processor
        )

        return result
    }
}
#else
// Stub for non-MLX builds (CI, tests without GPU)
final class MLXConstrainedGenerator: GrammarConstrainedGenerator {
    nonisolated let isFullyConstraining: Bool = false

    nonisolated func generate(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String {
        throw ConstrainedGeneratorError.mlxUnavailable
    }
}
#endif

enum ConstrainedGeneratorError: Error, LocalizedError {
    case mlxUnavailable
    case tokenizationFailed
    case grammarViolation(String)

    var errorDescription: String? {
        switch self {
        case .mlxUnavailable: "MLX framework not available"
        case .tokenizationFailed: "Failed to tokenize prompt"
        case .grammarViolation(let detail): "Grammar violation: \(detail)"
        }
    }
}

// MARK: - JSON Schema Logit Processor

/// A `LogitProcessor` that applies soft structural guidance for JSON generation.
///
/// **IMPORTANT**: This processor does NOT perform true grammar-constrained decoding.
/// It only penalizes premature EOS/stop tokens while inside JSON structures.
/// It does not mask invalid tokens or enforce grammar rules.
///
/// True constrained decoding would require:
/// 1. Access to the tokenizer vocabulary to decode each token ID
/// 2. A grammar FSA that tracks valid next-character sets
/// 3. Masking all token IDs whose decoded text is not in the valid set
///
/// Current guidance: penalizes EOS tokens by -50 logits when depth > 0.
/// This reduces premature stopping but does not guarantee valid JSON.
#if canImport(MLXLMCommon)
struct JSONSchemaLogitProcessor: LogitProcessor {
    private let grammar: ToolSchemaGrammar.CompiledGrammar
    private var state: JSONParserState = .arrayStart
    private var depth: Int = 0
    private var inString: Bool = false
    private var escaped: Bool = false
    private var generatedText: String = ""
    private var currentKey: String = ""
    private var keyBuffer: String = ""
    private var collectingKey: Bool = false

    /// Token IDs that map to JSON structural characters.
    /// Lazily populated on first `process()` call.
    private var allowedTokenCache: [JSONParserState: MLXArray]? = nil

    init(grammar: ToolSchemaGrammar.CompiledGrammar) {
        self.grammar = grammar
    }

    mutating func prompt(_ prompt: MLXArray) {
        // Reset state for new generation
        state = .arrayStart
        depth = 0
        inString = false
        escaped = false
        generatedText = ""
        currentKey = ""
        keyBuffer = ""
        collectingKey = false
    }

    func process(logits: MLXArray) -> MLXArray {
        // SOFT GUIDANCE ONLY — does not guarantee valid JSON.
        // Penalizes premature EOS/stop tokens when inside a JSON structure.
        // This is NOT constrained decoding — it's a heuristic that reduces
        // premature stopping but cannot enforce grammar rules.

        let modified = logits

        // Boost the EOS/stop token penalty if we haven't closed the array
        if depth > 0 {
            // We're inside the JSON structure — penalize premature stopping
            // Token ID 151643 is <|endoftext|> for Qwen models
            // Token ID 151645 is <|im_end|> for Qwen models
            let penaltyTokens: [UInt32] = [151643, 151645]
            let indices = MLXArray(penaltyTokens)
            var selectedLogits = modified[0..., indices]
            selectedLogits = selectedLogits - 50.0
            modified[0..., indices] = selectedLogits
        }

        return modified
    }

    mutating func didSample(token: MLXArray) {
        // Track the generated token for state transitions
        // In a full implementation, we'd decode the token and update the FSA.
        // For now, we increment/decrement depth on bracket tokens.
        let tokenId = token.item(Int.self)

        // Common Qwen token IDs for JSON structural characters
        // These are approximate — exact IDs vary by tokenizer
        // Full mapping requires tokenizer.decode() access
        switch tokenId {
        case 58: // '['
            depth += 1
        case 60: // ']'
            depth = max(0, depth - 1)
        case 90: // '{'
            depth += 1
        case 92: // '}'
            depth = max(0, depth - 1)
        default:
            break
        }
    }
}

// MARK: - JSON Parser State

/// Tracks position within the JSON output for grammar-constrained decoding.
enum JSONParserState: Hashable {
    case arrayStart          // Expecting '['
    case objectStart         // Expecting '{'
    case keyStart            // Expecting '"' to begin a key
    case inKey               // Inside a key string
    case afterKey            // Expecting ':'
    case valueStart          // Expecting a value (string, number, bool, null, object, array)
    case inStringValue       // Inside a string value
    case inNumberValue       // Inside a numeric value
    case afterValue          // Expecting ',' or '}' or ']'
    case done                // Generation complete
}
#endif

// MARK: - MLXInferenceService Extension

#if canImport(MLXLMCommon)
extension MLXInferenceService {
    /// Generate text with a custom LogitProcessor for constrained decoding.
    /// Bypasses ChatSession to inject the processor directly into TokenIterator.
    ///
    /// Uses: TokenIterator.init(input:model:cache:processor:sampler:prefillStepSize:maxTokens:)
    /// which accepts a custom LogitProcessor and LogitSampler.
    func generateConstrained(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        logitProcessor: some LogitProcessor
    ) async throws -> String {
        // Ensure a model is loaded — reuse the active container
        guard let container = self.container else {
            throw ConstrainedGeneratorError.mlxUnavailable
        }

        // Build the input and run generation with our custom processor
        let result: String = try await container.perform { context in
            // Prepare chat input using Chat.Message API
            var chatMessages: [Chat.Message] = []
            if let sys = systemPrompt {
                chatMessages.append(.system(sys))
            }
            chatMessages.append(.user(prompt))

            let userInput = UserInput(chat: chatMessages)
            let input = try await context.processor.prepare(input: userInput)

            // Create TokenIterator with our custom LogitProcessor
            let sampler = TopPSampler(temperature: 0.3, topP: 0.95)
            let cache = context.model.newCache(parameters: nil)
            var iterator = try TokenIterator(
                input: input,
                model: context.model,
                cache: cache,
                processor: logitProcessor,
                sampler: sampler,
                prefillStepSize: 256,
                maxTokens: maxTokens
            )

            // Collect tokens and detokenize
            var tokens: [Int] = []
            while let token = iterator.next() {
                tokens.append(token)
            }

            // Decode tokens to string
            let output = context.tokenizer.decode(tokens: tokens)
            return output
        }

        return result
    }
}
#endif
