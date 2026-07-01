import Foundation

nonisolated public struct HTMLWorkspaceSourceSnapshot: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: UInt32 = 1

    public var schemaVersion: UInt32
    public var renderedSnapshotName: String?
    public var title: String
    public var indexHTML: String
    public var styleCSS: String
    public var scriptJS: String
    public var dataJSON: String
    public var routes: [String: String]
    public var assets: [String: Data]
    public var dataFeed: HTMLWorkspaceDataFeed?
    public var contentHash: String

    public init(package: HTMLWorkspacePackage, renderedSnapshotName: String?) {
        self.schemaVersion = Self.currentSchemaVersion
        self.renderedSnapshotName = renderedSnapshotName
        self.title = package.manifest.title
        self.indexHTML = package.indexHTML
        self.styleCSS = package.styleCSS
        self.scriptJS = package.scriptJS
        self.dataJSON = package.dataJSON
        self.routes = package.routes
        self.assets = package.assets
        self.dataFeed = package.manifest.dataFeed
        self.contentHash = package.currentContentHash
    }

    public var computedContentHash: String {
        HTMLWorkspacePackageContentHasher.hash(
            indexHTML: indexHTML,
            styleCSS: styleCSS,
            scriptJS: scriptJS,
            dataJSON: dataJSON,
            routes: routes,
            assets: assets
        )
    }

    public func encodedData() throws -> Data {
        try JSONEncoder.epdocCanonical.encode(self)
    }

    public static func decode(from data: Data) throws -> HTMLWorkspaceSourceSnapshot {
        try JSONDecoder.epdocCanonical.decode(HTMLWorkspaceSourceSnapshot.self, from: data)
    }

    public static func sourceName(forRenderedSnapshotName name: String) -> String {
        if name.hasSuffix(".source.json") {
            return name
        }
        if name.hasSuffix(".html") {
            return String(name.dropLast(".html".count)) + ".source.json"
        }
        return name + ".source.json"
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case renderedSnapshotName = "rendered_snapshot_name"
        case title
        case indexHTML = "index_html"
        case styleCSS = "style_css"
        case scriptJS = "script_js"
        case dataJSON = "data_json"
        case routes
        case assets
        case dataFeed = "data_feed"
        case contentHash = "content_hash"
    }
}
