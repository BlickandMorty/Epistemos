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
    /// Attaches every note inside a named vault folder. At turn time the
    /// attachment gets expanded into per-note `.note` attachments via the
    /// manifest (entries whose `folderName` matches `title`), so the
    /// model receives the full set of note bodies instead of just one
    /// token representing the folder.
    case folder

    var systemImageName: String {
        switch self {
        case .note: "doc.text"
        case .chat: "bubble.left.and.bubble.right"
        case .allNotes: "books.vertical"
        case .folder: "folder"
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
    /// Human-readable label of the model that actually produced this
    /// assistant reply (e.g. "Qwen 3 4B", "Claude Sonnet 4.6", "Apple
    /// Intelligence"). Populated at turn completion from InferenceState.
    /// Optional for backward compatibility with legacy persisted messages
    /// and user messages. When present, the UI renders a small badge so
    /// the user can see exactly which model answered — the Perplexity
    /// pattern: transparent routing as first-class UX.
    var resolvedModelLabel: String?
    /// Typed classification of an error message so the UI can render the
    /// right recovery affordance (Open Settings deep-link for 401s,
    /// "Switch to local" for 429s, tool-failure vs model-refusal visuals,
    /// etc.) instead of pattern-matching on free-form copy. Nil for
    /// non-error messages and for legacy errors whose classifier wasn't
    /// called; in both cases the UI falls back to plain text rendering.
    var errorKind: UserFacingChatErrorKind?
    /// Persisted reasoning trace for this turn — the model's
    /// chain-of-thought if it produced one (streamed in via `<think>…
    /// </think>` tags, Anthropic `thinking` blocks, OpenAI reasoning
    /// summaries, or Gemini thought parts). Optional so legacy
    /// messages without a captured trace keep working. The message
    /// bubble surfaces a click-to-expand button whenever this is
    /// non-empty, so the user can always revisit the reasoning that
    /// produced the answer — not just during the streaming window.
    var thinkingTrace: String?
    /// Wall-clock duration of the thinking phase (popover "Thought for
    /// Ns"). Populated from `thinkingStartedAt`/`thinkingEndedAt` at
    /// turn completion so the persisted badge renders without needing
    /// the live timestamps.
    var thinkingDurationSeconds: Double?
    /// Fraction of input tokens served from the provider's prompt cache
    /// on this turn (0.0 … 1.0). Populated when the provider's usage
    /// payload exposes cache hit counts (Anthropic
    /// `cache_read_input_tokens`, OpenAI `prompt_tokens_details
    /// .cached_tokens`). Nil when the provider didn't report it OR
    /// when there was no cacheable prefix. MessageBubble renders a
    /// small "cache 78%" badge next to the model label so the user
    /// can see the prompt-caching win land turn-to-turn.
    var cacheHitPercent: Double?

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
        contentBlocks: [MessageContentBlock]? = nil,
        resolvedModelLabel: String? = nil,
        errorKind: UserFacingChatErrorKind? = nil,
        thinkingTrace: String? = nil,
        thinkingDurationSeconds: Double? = nil,
        cacheHitPercent: Double? = nil
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
        self.resolvedModelLabel = resolvedModelLabel
        self.errorKind = errorKind
        self.thinkingTrace = thinkingTrace
        self.thinkingDurationSeconds = thinkingDurationSeconds
        self.cacheHitPercent = cacheHitPercent
    }

    /// Effective text content — from contentBlocks if present, otherwise from content.
    var effectiveText: String {
        contentBlocks?.joinedText ?? content
    }
}

/// User-visible reasoning/thinking tier, mapped per-provider in LLMService
/// (OpenAI `reasoning.effort` + `text.verbosity`, Anthropic
/// `thinking.type`/`effort`/`budget_tokens`, Google `thinkingLevel` /
/// `thinkingBudget`). A single app-level taxonomy keeps the settings
/// control consistent across providers; `LLMService` is responsible for
/// silently dropping the control for models that don't support it.
///
/// Each mode presents a fallback subset with mode-specific labels:
/// - Thinking: `.low` / `.medium` / `.high` / `.heavy`
/// - Pro / Agent: at least `.medium` / `.heavy`, with provider-native
///   runtimes allowed to widen the ladder further (for example Codex
///   exposing Low / Medium / High / Extra High)
/// - Fast: no tier (reasoning disabled)
public nonisolated enum ChatReasoningTier: String, Codable, Sendable, CaseIterable {
    /// Disable reasoning/thinking. Fastest + cheapest per turn.
    case off
    /// Low effort. Maps to `reasoning.effort: "low"` on OpenAI,
    /// minimal budget on Anthropic, low thinkingLevel on Gemini 3.x.
    case low
    /// Balanced reasoning. Maps to `reasoning.effort: "medium"` on
    /// OpenAI, adaptive/medium on Anthropic Opus 4.7+, medium
    /// thinkingLevel on Gemini 3.x. Displayed as "Standard" in Pro /
    /// Agent mode, "Medium" in Thinking mode.
    case medium
    /// High effort. Maps to `reasoning.effort: "high"` on OpenAI,
    /// adaptive/high on Anthropic, high thinkingLevel on Gemini.
    case high
    /// Maximum effort the model family supports. Maps to
    /// `reasoning.effort: "xhigh"` on the OpenAI models that accept
    /// it (falls back to "high" otherwise), 32k thinkingBudget on
    /// Gemini 2.5, longest context on Anthropic. Displayed as "Heavy".
    case heavy

    /// Pre-migration aliases so old UserDefaults values keep working.
    /// `"standard"` → `.medium`, `"extended"` → `.high`. Apply via
    /// `ChatReasoningTier(migrating:)` instead of the raw initializer.
    public init?(migrating raw: String) {
        switch raw.lowercased() {
        case "standard": self = .medium
        case "extended": self = .high
        default:
            if let tier = ChatReasoningTier(rawValue: raw) {
                self = tier
            } else {
                return nil
            }
        }
    }

    /// Generic human-readable label. Mode-specific overrides (e.g.
    /// "Standard" vs "Medium" for `.medium`) live on
    /// `EpistemosOperatingMode.reasoningTierLabel(_:)`.
    public var displayName: String {
        switch self {
        case .off: "Off"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .heavy: "Heavy"
        }
    }

    /// Short explanation for Settings / picker subtitles.
    public var summary: String {
        switch self {
        case .off:
            "Skip the reasoning pass. Fastest replies, lowest cost."
        case .low:
            "Light reasoning. Quick checks without deep analysis."
        case .medium:
            "Balanced reasoning. Good default for most turns."
        case .high:
            "Heavy reasoning. Slower and more expensive."
        case .heavy:
            "Maximum reasoning. Slowest + most expensive; best on hard questions."
        }
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
    var contentBlocks: [MessageContentBlock]?
    var thinkingTrace: String?
    var thinkingDurationSeconds: Double?
    var loadedNoteTitles: [String]?
    var contextAttachments: [ContextAttachment]?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        contentBlocks: [MessageContentBlock]? = nil,
        thinkingTrace: String? = nil,
        thinkingDurationSeconds: Double? = nil,
        loadedNoteTitles: [String]? = nil,
        contextAttachments: [ContextAttachment]? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.contentBlocks = contentBlocks
        self.thinkingTrace = thinkingTrace
        self.thinkingDurationSeconds = thinkingDurationSeconds
        self.loadedNoteTitles = loadedNoteTitles
        self.contextAttachments = contextAttachments
        self.createdAt = createdAt
    }
}

enum ChatPreviewText {
    static let emptyPreview = "No messages yet."

    static func preview(for thread: ChatThread, streamingText: String? = nil) -> String? {
        if let streamingText,
           let preview = cleanedPreview(from: streamingText, role: .assistant) {
            return preview
        }

        if let assistantMessage = thread.messages.last(where: { hasPreviewContent($0) && $0.role == .assistant }) {
            return cleanedPreview(from: assistantMessage)
        }

        if let latestMessage = thread.messages.last(where: hasPreviewContent) {
            return cleanedPreview(from: latestMessage)
        }

        return nil
    }

    static func preview(for messages: [ChatMessage], streamingText: String? = nil) -> String? {
        if let streamingText,
           let preview = cleanedPreview(from: streamingText, role: .assistant) {
            return preview
        }

        if let assistantMessage = messages.last(where: { $0.role == .assistant && hasPreviewContent($0) }) {
            return cleanedPreview(from: assistantMessage)
        }

        if let latestMessage = messages.last(where: hasPreviewContent) {
            return cleanedPreview(from: latestMessage)
        }

        return nil
    }

    static func preview(for chat: SDChat) -> String? {
        if let assistantMessage = chat.sortedMessages.last(where: { $0.role == MessageRole.assistant.rawValue && hasPreviewContent($0) }) {
            return cleanedPreview(from: assistantMessage)
        }

        if let latestMessage = chat.sortedMessages.last(where: hasPreviewContent) {
            return cleanedPreview(from: latestMessage)
        }

        return nil
    }

    private static func cleanedPreview(from message: ChatMessage) -> String? {
        if let preview = cleanedPreview(from: message.effectiveText, role: message.role) {
            return preview
        }
        return toolSummaryPreview(from: message.contentBlocks)
    }

    private static func cleanedPreview(from message: AssistantMessage) -> String? {
        if let preview = cleanedPreview(from: message.content, role: message.role) {
            return preview
        }
        return toolSummaryPreview(from: message.contentBlocks)
    }

    private static func cleanedPreview(from message: SDMessage) -> String? {
        let role = MessageRole(rawValue: message.role) ?? .assistant
        if let preview = cleanedPreview(from: message.content, role: role) {
            return preview
        }
        return toolSummaryPreview(from: message.decodedContentBlocks())
    }

    private static func cleanedPreview(from text: String, role: MessageRole) -> String? {
        let visibleText = role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: text)
            : text
        let compact = visibleText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        return String(compact.prefix(140))
    }

    private static func toolSummaryPreview(from blocks: [MessageContentBlock]?) -> String? {
        guard let blocks else { return nil }

        for block in blocks {
            switch block {
            case .toolResult(_, let content, _):
                if let preview = cleanedPreview(from: content, role: .assistant) {
                    return preview
                }
            case .toolUse(_, let name, _):
                return "Used \(name.replacingOccurrences(of: "_", with: " "))"
            default:
                continue
            }
        }

        return nil
    }

    private static func hasPreviewContent(_ message: ChatMessage) -> Bool {
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return toolSummaryPreview(from: message.contentBlocks) != nil
    }

    private static func hasPreviewContent(_ message: AssistantMessage) -> Bool {
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return toolSummaryPreview(from: message.contentBlocks) != nil
    }

    private static func hasPreviewContent(_ message: SDMessage) -> Bool {
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return toolSummaryPreview(from: message.decodedContentBlocks()) != nil
    }
}
