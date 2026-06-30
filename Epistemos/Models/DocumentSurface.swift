import Foundation

nonisolated public enum DocumentSurfaceKind: String, Codable, Sendable, Hashable, CaseIterable {
    case note
    case epdoc
    case htmlWorkspace
    case visualization
    case pdf
    case canvas
    case code
}

nonisolated public enum DocumentSurfacePane: String, Codable, Sendable, Hashable, CaseIterable {
    case html
    case css
    case js
    case data
    case routes
    case dom
    case assets
    case preview
    case note
    case epdoc
    case pdf
    case canvas
    case code
}

nonisolated public enum DocumentSurfaceCapability: String, Codable, Sendable, Hashable, CaseIterable {
    case read
    case write
    case patch
    case exportHTML
    case exportPDF
    case importContent = "import"
    case preview
    case annotate
}

nonisolated public struct DocumentSourceRange: Codable, Sendable, Hashable {
    public var startLine: Int
    public var startColumn: Int
    public var endLine: Int
    public var endColumn: Int

    public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.startLine = max(1, startLine)
        self.startColumn = max(1, startColumn)
        self.endLine = max(self.startLine, endLine)
        self.endColumn = max(1, endColumn)
    }
}

nonisolated public struct DocumentSurface: Codable, Sendable, Hashable {
    public var id: String
    public var kind: DocumentSurfaceKind
    public var title: String
    public var fileURL: URL?
    public var currentSelection: DocumentSourceRange?
    public var capabilities: [DocumentSurfaceCapability]
    public var contentHash: String

    public init(
        id: String,
        kind: DocumentSurfaceKind,
        title: String,
        fileURL: URL? = nil,
        currentSelection: DocumentSourceRange? = nil,
        capabilities: [DocumentSurfaceCapability],
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.fileURL = fileURL
        self.currentSelection = currentSelection
        self.capabilities = capabilities
        self.contentHash = contentHash
    }
}
