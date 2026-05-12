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

// MARK: - File Edit Tools

/// Tool definitions for AI-mediated file editing.
/// For Anthropic: each schema maps to `tools[].input_schema`.
/// For OpenAI: each schema maps to `response_format.json_schema.schema`.
nonisolated enum FileEditTool {
    static let editFile = CloudJSONSchema(
        name: "file_patch",
        description: "Replace a range of lines in the active file. Use for targeted edits.",
        schema: [
            "type": "object",
            "properties": [
                "start_line": ["type": "integer", "description": "First line to replace (1-indexed)"],
                "end_line": ["type": "integer", "description": "Last line to replace (1-indexed, inclusive)"],
                "replacement": ["type": "string", "description": "New content for the replaced lines"],
                "explanation": ["type": "string", "description": "Why this edit was made"]
            ],
            "required": ["start_line", "end_line", "replacement", "explanation"]
        ]
    )

    static let replaceFile = CloudJSONSchema(
        name: "file_replace",
        description: "Replace the entire file content. Use only when the edit affects more than 60% of lines.",
        schema: [
            "type": "object",
            "properties": [
                "content": ["type": "string", "description": "Complete new file content"],
                "explanation": ["type": "string", "description": "Why the full replacement was needed"]
            ],
            "required": ["content", "explanation"]
        ]
    )

    static let insertAtLine = CloudJSONSchema(
        name: "file_insert_at_line",
        description: "Insert new lines before a given line number.",
        schema: [
            "type": "object",
            "properties": [
                "line": ["type": "integer", "description": "Insert BEFORE this line (1-indexed)"],
                "content": ["type": "string", "description": "Content to insert"],
                "explanation": ["type": "string", "description": "Why this insertion was made"]
            ],
            "required": ["line", "content", "explanation"]
        ]
    )

    static let deleteLines = CloudJSONSchema(
        name: "file_delete_lines",
        description: "Delete a range of lines from the file.",
        schema: [
            "type": "object",
            "properties": [
                "start_line": ["type": "integer", "description": "First line to delete (1-indexed)"],
                "end_line": ["type": "integer", "description": "Last line to delete (1-indexed, inclusive)"],
                "explanation": ["type": "string", "description": "Why these lines were deleted"]
            ],
            "required": ["start_line", "end_line", "explanation"]
        ]
    )

    static let all: [CloudJSONSchema] = [editFile, replaceFile, insertAtLine, deleteLines]
}

// MARK: - File Edit Operation Model

struct FileEditOperation: Codable, Sendable {
    let startLine: Int
    let endLine: Int
    let replacement: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case startLine = "start_line"
        case endLine = "end_line"
        case replacement
        case explanation
    }

    func validate(against fileLineCount: Int) throws {
        guard startLine >= 1 else {
            throw FileEditError.invalidRange(startLine, endLine, fileLineCount)
        }
        guard endLine <= fileLineCount else {
            throw FileEditError.invalidRange(startLine, endLine, fileLineCount)
        }
        guard startLine <= endLine else {
            throw FileEditError.invalidRange(startLine, endLine, fileLineCount)
        }
    }
}

enum FileEditError: LocalizedError {
    case invalidRange(Int, Int, Int)

    var errorDescription: String? {
        switch self {
        case .invalidRange(let start, let end, let total):
            return "Invalid line range \(start)–\(end) for file with \(total) lines"
        }
    }
}

// MARK: - File Edit Executor

/// Applies file edit operations bottom-to-top to preserve line numbers.
enum FileEditExecutor {
    /// Apply operations to an editor via the noteRangeWriter closure.
    /// Operations are sorted descending by startLine before application.
    static func apply(
        operations: [FileEditOperation],
        writer: (ClosedRange<Int>, String) -> Void,
        lineCount: Int
    ) throws {
        let sorted = try operations
            .map { op -> FileEditOperation in try op.validate(against: lineCount); return op }
            .sorted { $0.startLine > $1.startLine }

        for op in sorted {
            writer(op.startLine...op.endLine, op.replacement)
        }
    }
}
