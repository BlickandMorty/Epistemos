import Foundation

// MARK: - Chat Domain Types
// DualMessage, TruthAssessment, and FileAttachment are defined in EngineTypes.swift.

// MARK: - Content Block Model
// Replaces flat `content: String` for multi-part messages (tool calls, thinking, images).

enum MessageContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case thinking(String)
    case image(base64: String, mediaType: String)

    /// Extract text from this block, if applicable.
    var textContent: String? {
        switch self {
        case .text(let s): return s
        case .thinking(let s): return s
        case .toolResult(_, let content, _): return content
        default: return nil
        }
    }
}

/// Lightweight JSON value type for encoding tool_use inputs without external dependencies.
enum JSONValue: Codable, Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

// MARK: - Cloud Stream Chunk
// Typed stream events replacing flat `AsyncThrowingStream<String, Error>`.

enum CloudStreamChunk: Sendable {
    case textDelta(String)
    case toolCallDelta(id: String, name: String, argumentsDelta: String)
    case thinking(String)
    case usage(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int)
    case done(stopReason: String)
}

// MARK: - Content Block Helpers

extension Array where Element == MessageContentBlock {
    /// Join all `.text` blocks into a single string (backward compatibility).
    var joinedText: String {
        compactMap { if case .text(let s) = $0 { return s } else { return nil } }
            .joined()
    }

    /// Extract all tool_use blocks.
    var toolUseBlocks: [(id: String, name: String, input: [String: JSONValue])] {
        compactMap {
            if case .toolUse(let id, let name, let input) = $0 { return (id, name, input) }
            return nil
        }
    }

    /// Extract thinking content.
    var thinkingContent: String? {
        let parts = compactMap { if case .thinking(let s) = $0 { return s } else { return nil } }
        return parts.isEmpty ? nil : parts.joined()
    }
}

enum ContextAttachmentKind: String, Codable, Sendable, Hashable {
    case note
    case chat
    case allNotes

    var systemImageName: String {
        switch self {
        case .note: "doc.text"
        case .chat: "bubble.left.and.bubble.right"
        case .allNotes: "books.vertical"
        }
    }
}

struct ContextAttachment: Identifiable, Codable, Sendable, Hashable {
    var kind: ContextAttachmentKind
    var targetId: String
    var title: String
    var subtitle: String?

    var id: String { "\(kind.rawValue):\(targetId)" }
    var systemImageName: String { kind.systemImageName }

    init(kind: ContextAttachmentKind, targetId: String, title: String, subtitle: String? = nil) {
        self.kind = kind
        self.targetId = targetId
        self.title = title
        self.subtitle = subtitle
    }
}

struct ChatMessage: Identifiable, Codable, Sendable {
    var id: String
    var chatId: String
    var role: MessageRole
    var content: String
    var dualMessage: DualMessage?
    var truthAssessment: TruthAssessment?
    var confidence: Double?
    var evidenceGrade: EvidenceGrade?
    var mode: InferenceMode?
    var attachments: [FileAttachment]
    var isError: Bool
    var createdAt: Date
    var isVaultBriefing: Bool
    var loadedNoteTitles: [String]?
    var contextAttachments: [ContextAttachment]?
    /// Structured artifacts extracted from this message (JSON, YAML, code, tables).
    var artifacts: [Artifact]
    /// Multi-part content blocks (tool calls, thinking, images). When non-empty, `content` is a computed join of `.text` blocks.
    var contentBlocks: [MessageContentBlock]?

    init(
        id: String = UUID().uuidString,
        chatId: String = "",
        role: MessageRole,
        content: String,
        dualMessage: DualMessage? = nil,
        truthAssessment: TruthAssessment? = nil,
        confidence: Double? = nil,
        evidenceGrade: EvidenceGrade? = nil,
        mode: InferenceMode? = nil,
        attachments: [FileAttachment] = [],
        isError: Bool = false,
        createdAt: Date = .now,
        isVaultBriefing: Bool = false,
        loadedNoteTitles: [String]? = nil,
        contextAttachments: [ContextAttachment]? = nil,
        artifacts: [Artifact] = [],
        contentBlocks: [MessageContentBlock]? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.role = role
        self.content = content
        self.dualMessage = dualMessage
        self.truthAssessment = truthAssessment
        self.confidence = confidence
        self.evidenceGrade = evidenceGrade
        self.mode = mode
        self.attachments = attachments
        self.isError = isError
        self.createdAt = createdAt
        self.isVaultBriefing = isVaultBriefing
        self.loadedNoteTitles = loadedNoteTitles
        self.contextAttachments = contextAttachments
        self.artifacts = artifacts
        self.contentBlocks = contentBlocks
    }

    /// Effective text content — from contentBlocks if present, otherwise from content.
    var effectiveText: String {
        contentBlocks?.joinedText ?? content
    }
}

struct ChatThread: Identifiable, Codable, Sendable {
    var id: String
    var type: String
    var label: String
    var messages: [AssistantMessage]
    var pageId: String?
    var loadedNoteIds: [String]
    var loadedNoteTitles: [String]
    var contextAttachments: [ContextAttachment]
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: String = "chat",
        label: String = "Thread",
        messages: [AssistantMessage] = [],
        pageId: String? = nil,
        loadedNoteIds: [String] = [],
        loadedNoteTitles: [String] = [],
        contextAttachments: [ContextAttachment] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.messages = messages
        self.pageId = pageId
        self.loadedNoteIds = loadedNoteIds
        self.loadedNoteTitles = loadedNoteTitles
        self.contextAttachments = contextAttachments
        self.createdAt = createdAt
    }
}

struct AssistantMessage: Identifiable, Codable, Sendable {
    var id: String
    var role: MessageRole
    var content: String
    var loadedNoteTitles: [String]?
    var contextAttachments: [ContextAttachment]?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        loadedNoteTitles: [String]? = nil,
        contextAttachments: [ContextAttachment]? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.loadedNoteTitles = loadedNoteTitles
        self.contextAttachments = contextAttachments
        self.createdAt = createdAt
    }
}
