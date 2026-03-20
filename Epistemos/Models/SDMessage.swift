import Foundation
import SwiftData

// MARK: - SDMessage
// Chat message with full analysis metadata. Replaces v2's MessageRecord (GRDB).
// Rich analysis data (DualMessage, TruthAssessment) stored as JSON-encoded Data
// because these are complex nested Codable types that SwiftData can't natively index.
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
    var reasoningText: String?
    var reasoningDuration: Double?
    // Legacy persisted fields kept for lightweight migration compatibility.
    var isResearchResult: Bool = false
    var researchDuration: Double?
    var researchStartTime: Date?

    // MARK: - Attachments
    var attachmentsData: Data?          // Encoded [FileAttachment]
    var loadedNoteTitlesData: Data?     // Encoded [String]
    var contextAttachmentsData: Data?   // Encoded [ContextAttachment]

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
        dualMessageData.flatMap { try? JSONDecoder().decode(DualMessage.self, from: $0) }
    }

    @MainActor
    private func decodedTruthAssessment() -> TruthAssessment? {
        truthAssessmentData.flatMap { try? JSONDecoder().decode(TruthAssessment.self, from: $0) }
    }

    @MainActor
    private func decodedAttachments() -> [FileAttachment] {
        guard let attachmentsData else { return [] }
        return (try? JSONDecoder().decode([FileAttachment].self, from: attachmentsData)) ?? []
    }

    @MainActor
    private func decodedLoadedNoteTitles() -> [String]? {
        guard let loadedNoteTitlesData else { return nil }
        return try? JSONDecoder().decode([String].self, from: loadedNoteTitlesData)
    }

    @MainActor
    private func decodedContextAttachments() -> [ContextAttachment]? {
        guard let contextAttachmentsData else { return nil }
        return try? JSONDecoder().decode([ContextAttachment].self, from: contextAttachmentsData)
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
        attachmentsData = try? JSONEncoder().encode(attachments)
        loadedNoteTitlesData = try? JSONEncoder().encode(loadedNoteTitles ?? [])
        contextAttachmentsData = try? JSONEncoder().encode(contextAttachments ?? [])
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
            createdAt: createdAt,
            reasoningText: reasoningText,
            reasoningDuration: reasoningDuration,
            loadedNoteTitles: decodedLoadedNoteTitles(),
            contextAttachments: decodedContextAttachments()
        )
    }
}
