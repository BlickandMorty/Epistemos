import Foundation

// MARK: - Chat Domain Types
// DualMessage, TruthAssessment, FileAttachment are defined in EngineTypes.swift

enum ContextAttachmentKind: String, Codable, Sendable, Hashable {
    case note
    case chat
    case allNotes
}

struct ContextAttachment: Identifiable, Codable, Sendable, Hashable {
    var kind: ContextAttachmentKind
    var targetId: String
    var title: String
    var subtitle: String?

    var id: String { "\(kind.rawValue):\(targetId)" }

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
    var reasoningText: String?
    var reasoningDuration: Double?
    var isVaultBriefing: Bool
    var loadedNoteTitles: [String]?
    var contextAttachments: [ContextAttachment]?

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
        reasoningText: String? = nil,
        reasoningDuration: Double? = nil,
        isVaultBriefing: Bool = false,
        loadedNoteTitles: [String]? = nil,
        contextAttachments: [ContextAttachment]? = nil
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
        self.reasoningText = reasoningText
        self.reasoningDuration = reasoningDuration
        self.isVaultBriefing = isVaultBriefing
        self.loadedNoteTitles = loadedNoteTitles
        self.contextAttachments = contextAttachments
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
