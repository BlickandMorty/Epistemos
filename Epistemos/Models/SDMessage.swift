import Foundation
import SwiftData

// MARK: - SDMessage
// Chat message model. Replaces v2's MessageRecord (GRDB).
// Legacy analysis blobs remain JSON-encoded for lightweight migration compatibility.
//
// CloudKit-compatible: all properties optional or defaulted.

@Model
final class SDMessage {
    #Index<SDMessage>([\.id], [\.createdAt])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Content
    var role: String = "user"           // "user", "assistant", "system"
    var content: String = ""

    // MARK: - Analysis Metadata
    // Stored as JSON-encoded Data for complex nested types.
    // Phase 02 creates the Codable types these encode/decode.
    var dualMessageData: Data?          // Encoded DualMessage (rawAnalysis + uncertainty + layman)
    var truthAssessmentData: Data?      // Encoded TruthAssessment

    // Scalar analysis results (directly queryable via #Predicate)
    var evidenceGrade: String?          // "A", "B", "C", "D", "F"
    var confidenceScore: Double?
    var safetyState: String?            // "green", "yellow", "orange", "red"
    var inferenceMode: String?          // "local", "api", "appleIntelligence"

    // MARK: - Authorship (Pass 8: per-model "involvement" memory)
    /// Which provider authored this message, as a stable string id:
    /// "openai" | "anthropic" | "google" | "local" | "appleIntelligence" | nil for user messages.
    /// Legacy messages from before this column existed remain `nil`; code
    /// reading this field MUST treat `nil` as "unknown" rather than any
    /// specific provider.
    var authoredByProviderID: String?
    /// Which specific model authored this message, as a stable string id.
    /// Cloud examples: "claude-opus-4-7", "gpt-5-4", "gemini-3.1-pro".
    /// Local examples: "Qwen/Qwen3-4B-MLX-4bit",
    /// "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit". Legacy messages
    /// remain `nil` — never infer a default.
    var authoredByModelID: String?

    // MARK: - Content Blocks
    /// JSON-encoded [MessageContentBlock]. When present, `content` is a backward-compat
    /// computed join of .text blocks. New code should prefer contentBlocks.
    var contentBlocksData: Data?

    // MARK: - Attachments
    var attachmentsData: Data?          // Encoded [FileAttachment]
    var loadedNoteTitlesData: Data?     // Encoded [String]
    var contextAttachmentsData: Data?   // Encoded [ContextAttachment]
    var artifactsData: Data?            // Encoded [Artifact] — structured output blocks
    var thinkingTrace: String?
    var thinkingDurationSeconds: Double?
    var isError: Bool = false
    var isVaultBriefing: Bool = false

    // MARK: - Timestamps
    var createdAt: Date = Date.now

    // MARK: - Relationships
    var chat: SDChat?

    // MARK: - Init

    init(role: String, content: String) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.createdAt = .now
    }

    @MainActor
    private func decodedDualMessage() -> DualMessage? {
        guard let data = dualMessageData else { return nil }
        do {
            return try JSONDecoder().decode(DualMessage.self, from: data)
        } catch {
            Log.db.error("Failed to decode DualMessage for message \(self.id): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func decodedTruthAssessment() -> TruthAssessment? {
        guard let data = truthAssessmentData else { return nil }
        do {
            return try JSONDecoder().decode(TruthAssessment.self, from: data)
        } catch {
            Log.db.error("Failed to decode TruthAssessment for message \(self.id): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func decodedAttachments() -> [FileAttachment] {
        guard let attachmentsData else { return [] }
        do {
            return try JSONDecoder().decode([FileAttachment].self, from: attachmentsData)
        } catch {
            Log.db.error("Failed to decode [FileAttachment] for message \(self.id): \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    private func decodedLoadedNoteTitles() -> [String]? {
        guard let loadedNoteTitlesData else { return nil }
        do {
            return try JSONDecoder().decode([String].self, from: loadedNoteTitlesData)
        } catch {
            Log.db.error("Failed to decode loadedNoteTitles for message \(self.id): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func decodedContextAttachments() -> [ContextAttachment]? {
        guard let contextAttachmentsData else { return nil }
        do {
            return try JSONDecoder().decode([ContextAttachment].self, from: contextAttachmentsData)
        } catch {
            Log.db.error("Failed to decode [ContextAttachment] for message \(self.id): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func decodedContentBlocks() -> [MessageContentBlock]? {
        guard let contentBlocksData else { return nil }
        do {
            return try JSONDecoder().decode([MessageContentBlock].self, from: contentBlocksData)
        } catch {
            Log.db.error("Failed to decode [MessageContentBlock] for message \(self.id): \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func setContentBlocks(_ blocks: [MessageContentBlock]?) {
        guard let blocks, !blocks.isEmpty else {
            self.contentBlocksData = nil
            return
        }
        do {
            let encoded = try JSONEncoder().encode(blocks)
            self.contentBlocksData = encoded
            // Keep content in sync as joined text for backward compatibility
            self.content = blocks.joinedText
        } catch {
            Log.db.error("Failed to encode [MessageContentBlock] for message \(self.id): \(error.localizedDescription)")
            self.contentBlocksData = nil
            self.content = blocks.joinedText
        }
    }

    @MainActor
    func decodedArtifacts() -> [Artifact] {
        guard let artifactsData else { return [] }
        do {
            return try JSONDecoder().decode([Artifact].self, from: artifactsData)
        } catch {
            Log.db.error("Failed to decode [Artifact] for message \(self.id): \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    func setArtifacts(_ artifacts: [Artifact]) {
        guard !artifacts.isEmpty else {
            self.artifactsData = nil
            return
        }
        do {
            let encoded = try JSONEncoder().encode(artifacts)
            self.artifactsData = encoded
        } catch {
            Log.db.error("Failed to encode [Artifact] for message \(self.id): \(error.localizedDescription)")
            self.artifactsData = nil
        }
    }

    @MainActor
    func updateAnalysis(
        dualMessage: DualMessage?,
        truthAssessment: TruthAssessment?,
        confidence: Double?,
        evidenceGrade: EvidenceGrade?,
        mode: InferenceMode?
    ) {
        self.confidenceScore = confidence
        self.evidenceGrade = evidenceGrade?.rawValue
        self.inferenceMode = mode?.rawValue

        if let dualMessage {
            do {
                let encoded = try JSONEncoder().encode(dualMessage)
                self.dualMessageData = encoded
            } catch {
                Log.db.error("Failed to encode DualMessage for message \(self.id): \(error.localizedDescription)")
                self.dualMessageData = nil
            }
        } else {
            self.dualMessageData = nil
        }

        if let truthAssessment {
            do {
                let encoded = try JSONEncoder().encode(truthAssessment)
                self.truthAssessmentData = encoded
            } catch {
                Log.db.error("Failed to encode TruthAssessment for message \(self.id): \(error.localizedDescription)")
                self.truthAssessmentData = nil
            }
        } else {
            self.truthAssessmentData = nil
        }
    }

    @MainActor
    func updatePresentationSnapshot(
        attachments: [FileAttachment],
        loadedNoteTitles: [String]?,
        contextAttachments: [ContextAttachment]?
    ) {
        do {
            let encoded = try JSONEncoder().encode(attachments)
            attachmentsData = encoded
        } catch {
            Log.db.error("Failed to encode [FileAttachment] for message \(self.id): \(error.localizedDescription)")
            attachmentsData = nil
        }
        do {
            let encoded = try JSONEncoder().encode(loadedNoteTitles ?? [])
            loadedNoteTitlesData = encoded
        } catch {
            Log.db.error("Failed to encode loadedNoteTitles for message \(self.id): \(error.localizedDescription)")
            loadedNoteTitlesData = nil
        }
        do {
            let encoded = try JSONEncoder().encode(contextAttachments ?? [])
            contextAttachmentsData = encoded
        } catch {
            Log.db.error("Failed to encode [ContextAttachment] for message \(self.id): \(error.localizedDescription)")
            contextAttachmentsData = nil
        }
    }

    @MainActor
    func chatMessage(chatId: String) -> ChatMessage {
        ChatMessage(
            id: id,
            chatId: chatId,
            role: MessageRole(rawValue: role) ?? .assistant,
            content: content,
            dualMessage: decodedDualMessage(),
            truthAssessment: decodedTruthAssessment(),
            confidence: confidenceScore,
            evidenceGrade: evidenceGrade.flatMap(EvidenceGrade.init(rawValue:)),
            mode: inferenceMode.flatMap(InferenceMode.init(rawValue:)),
            attachments: decodedAttachments(),
            isError: isError,
            createdAt: createdAt,
            isVaultBriefing: isVaultBriefing,
            loadedNoteTitles: decodedLoadedNoteTitles(),
            contextAttachments: decodedContextAttachments(),
            artifacts: decodedArtifacts(),
            contentBlocks: decodedContentBlocks(),
            authoredByProviderID: authoredByProviderID,
            authoredByModelID: authoredByModelID,
            thinkingTrace: thinkingTrace,
            thinkingDurationSeconds: thinkingDurationSeconds
        )
    }
}
