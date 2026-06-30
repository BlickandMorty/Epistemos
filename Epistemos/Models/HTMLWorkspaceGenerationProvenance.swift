import Foundation

nonisolated public struct HTMLWorkspaceGenerationProvenance: Codable, Sendable, Hashable {
    public enum Operation: String, Codable, Sendable, Hashable {
        case replaceDocument = "replace_document"
        case regenerate

        var displayName: String {
            switch self {
            case .replaceDocument: "replaceDocument"
            case .regenerate: "regenerate"
            }
        }
    }

    public static let patchToolID = "html_workspace.patch"

    public var producer: EpdocProducer
    public var operation: Operation
    public var generatedAt: Int64
    public var previousContentHash: String
    public var contentHash: String
    public var reversibleSnapshotName: String?
    public var generatedByRun: String?
    public var toolId: String?

    public init(
        producer: EpdocProducer,
        operation: Operation,
        generatedAt: Int64,
        previousContentHash: String,
        contentHash: String,
        reversibleSnapshotName: String? = nil,
        generatedByRun: String? = nil,
        toolId: String? = nil
    ) {
        self.producer = producer
        self.operation = operation
        self.generatedAt = generatedAt
        self.previousContentHash = previousContentHash
        self.contentHash = contentHash
        self.reversibleSnapshotName = reversibleSnapshotName
        self.generatedByRun = generatedByRun
        self.toolId = toolId
    }

    private enum CodingKeys: String, CodingKey {
        case producer
        case operation
        case generatedAt = "generated_at"
        case previousContentHash = "previous_content_hash"
        case contentHash = "content_hash"
        case reversibleSnapshotName = "reversible_snapshot_name"
        case generatedByRun = "generated_by_run"
        case toolId = "tool_id"
    }
}
