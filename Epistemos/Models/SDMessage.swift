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

    // MARK: - Attachments
    var attachmentsData: Data?          // Encoded [FileAttachment]

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
}
