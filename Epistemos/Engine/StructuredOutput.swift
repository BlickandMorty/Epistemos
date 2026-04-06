// StructuredOutput.swift
//
// Core types for structured cloud model output (JSON schemas, typed
// results, error handling). Used by CloudLLMClient to get guaranteed
// JSON back from OpenAI (json_schema response format) and Anthropic
// (tool_use with forced tool_choice).
//
// 2026-04-06: Phase 1 of cloud artifact pipeline.

import Foundation

// MARK: - JSON Schema

/// A JSON Schema definition passed to cloud providers to constrain output.
/// OpenAI uses this directly in `response_format.json_schema.schema`.
/// Anthropic uses it as `tools[].input_schema`.
nonisolated struct CloudJSONSchema: @unchecked Sendable {
    /// Schema name (used as the tool name for Anthropic, schema name for OpenAI).
    let name: String
    /// Human-readable description of what the schema produces.
    let description: String?
    /// Raw JSON Schema dictionary (properties, required, type, etc.).
    /// Uses [String: Any] to match the existing JSONSerialization pattern
    /// throughout CloudLLMClient — no need for a full schema type system.
    let schema: [String: Any]
    /// Whether to enforce strict schema adherence (OpenAI only).
    let strict: Bool

    init(name: String, description: String? = nil, schema: [String: Any], strict: Bool = true) {
        self.name = name
        self.description = description
        self.schema = schema
        self.strict = strict
    }
}

// MARK: - Schema Builder

/// Convenience factory for common schema patterns.
nonisolated enum JSONSchemaBuilder {
    /// Build a simple object schema with named properties.
    ///
    /// Example:
    /// ```
    /// JSONSchemaBuilder.object(
    ///     name: "person",
    ///     description: "A person's info",
    ///     properties: [
    ///         "name": ["type": "string"],
    ///         "age": ["type": "integer"],
    ///         "hobbies": ["type": "array", "items": ["type": "string"]]
    ///     ],
    ///     required: ["name", "age"]
    /// )
    /// ```
    static func object(
        name: String,
        description: String? = nil,
        properties: [String: [String: Any]],
        required: [String]? = nil,
        strict: Bool = true
    ) -> CloudJSONSchema {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties,
        ]
        if let required, !required.isEmpty {
            schema["required"] = required
        }
        // OpenAI strict mode requires additionalProperties: false
        if strict {
            schema["additionalProperties"] = false
        }
        return CloudJSONSchema(
            name: name,
            description: description,
            schema: schema,
            strict: strict
        )
    }
}

// MARK: - Result

/// The result of a structured generation call: the decoded value plus
/// the raw JSON string (useful for storage, export, and debugging).
struct StructuredGenerationResult<T: Decodable & Sendable>: Sendable {
    let value: T
    let rawJSON: String
}

// MARK: - Errors

nonisolated enum StructuredOutputError: Error, LocalizedError, Sendable {
    /// The model returned JSON but it didn't decode into the expected type.
    /// Preserves the raw JSON for debugging and fallback display.
    case decodingFailed(underlyingError: any Error, rawJSON: String)
    /// The provider refused the schema (e.g., unsupported model).
    case providerRefusedSchema(reason: String)
    /// The model returned an empty or unparseable response.
    case emptyResponse
    /// The model doesn't support structured output natively.
    case unsupportedModel(String)

    var errorDescription: String? {
        switch self {
        case .decodingFailed(let err, _):
            return "Structured output decoding failed: \(err.localizedDescription)"
        case .providerRefusedSchema(let reason):
            return "Provider refused schema: \(reason)"
        case .emptyResponse:
            return "Empty structured response"
        case .unsupportedModel(let model):
            return "Model \(model) does not support structured output"
        }
    }
}
