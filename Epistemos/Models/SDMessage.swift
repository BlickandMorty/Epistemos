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

    // MARK: - Attachments
    var attachmentsData: Data?          // Encoded [FileAttachment]
    var loadedNoteTitlesData: Data?     // Encoded [String]
    var contextAttachmentsData: Data?   // Encoded [ContextAttachment]
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
                self.dualMessageData = try JSONEncoder().encode(dualMessage)
            } catch {
                self.dualMessageData = nil
            }
        } else {
            self.dualMessageData = nil
        }

        if let truthAssessment {
            do {
                self.truthAssessmentData = try JSONEncoder().encode(truthAssessment)
            } catch {
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
            attachmentsData = try JSONEncoder().encode(attachments)
        } catch {
            Log.db.error("Failed to encode [FileAttachment] for message \(self.id): \(error.localizedDescription)")
            attachmentsData = nil
        }
        do {
            loadedNoteTitlesData = try JSONEncoder().encode(loadedNoteTitles ?? [])
        } catch {
            Log.db.error("Failed to encode loadedNoteTitles for message \(self.id): \(error.localizedDescription)")
            loadedNoteTitlesData = nil
        }
        do {
            contextAttachmentsData = try JSONEncoder().encode(contextAttachments ?? [])
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
            contextAttachments: decodedContextAttachments()
        )
    }
}
