import Foundation

// MARK: - EpdocPackage
//
// Wave 7.1 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.1,
//  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
//
// In-memory representation of a `.epdoc` package's full file tree.
// Used both by writers (build a tree → serialise to FileWrapper → save
// to disk via NSDocument) and readers (load via NSDocument → FileWrapper
// → decode into EpdocPackage → present to the editor).
//
// File layout (per the plan §4):
//
//     MyResearchReport.epdoc/
//       manifest.json              # required: EpdocManifest
//       content.pm.json            # required: canonical ProseMirror JSON
//       projections/               # optional: derived views
//         shadow.md                # GFM Markdown projection (lossy)
//         plain.txt                # FTS-friendly plain text
//         search_blocks.jsonl      # block-level search projection
//       assets/                    # optional: embedded media
//         image-01.png
//       exports/                   # generated on-demand only
//         *.docx                   # Pandoc + reference.docx
//         *.pdf                    # later
//
// Rules (encoded by this struct's API):
//   - manifest + contentJSON are REQUIRED. A package missing either
//     fails to decode (invariant violation).
//   - Projections + assets + exports are OPTIONAL and addressed by name.
//   - Markdown shadow regenerates from canonical on every save.
//   - DOCX/PDF are export snapshots — never autosaved.

/// Reserved top-level filenames inside a `.epdoc` package. Used by the
/// FileWrapper bridge to route reads/writes to the right field.
nonisolated public enum EpdocPackageEntry {
    public static let manifest = "manifest.json"
    public static let content = "content.pm.json"
    public static let projections = "projections"
    public static let assets = "assets"
    public static let exports = "exports"

    /// Filenames inside `projections/` that have first-class fields on
    /// the package. Anything else lives in `extraProjections` as raw bytes.
    public enum Projection {
        public static let shadowMarkdown = "shadow.md"
        public static let plainText = "plain.txt"
        public static let searchBlocksJSONL = "search_blocks.jsonl"
    }
}

/// In-memory representation of a `.epdoc` package.
nonisolated public struct EpdocPackage: Sendable, Hashable {
    public var manifest: EpdocManifest
    /// Raw bytes of `content.pm.json` — the canonical ProseMirror
    /// document. Stored as `Data` (not a parsed JSON tree) so the
    /// reader/writer never has to re-encode the canonical bytes;
    /// content_hash in the manifest is computed against THESE bytes.
    public var contentJSON: Data
    /// Optional Markdown projection — derived, lossy.
    public var shadowMarkdown: Data?
    /// Optional plain-text projection — for FTS5 indexing.
    public var plainText: Data?
    /// Optional block-level search projection (one block per line, JSON).
    public var searchBlocksJSONL: Data?
    /// Other files inside `projections/` not covered by the canonical
    /// fields above. Filename → bytes.
    public var extraProjections: [String: Data]
    /// `assets/` — embedded media. Filename → bytes.
    public var assets: [String: Data]
    /// `exports/` — generated on-demand snapshots (DOCX, PDF).
    /// Filename → bytes. Excluded from autosave by convention.
    public var exports: [String: Data]

    public init(
        manifest: EpdocManifest,
        contentJSON: Data,
        shadowMarkdown: Data? = nil,
        plainText: Data? = nil,
        searchBlocksJSONL: Data? = nil,
        extraProjections: [String: Data] = [:],
        assets: [String: Data] = [:],
        exports: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.contentJSON = contentJSON
        self.shadowMarkdown = shadowMarkdown
        self.plainText = plainText
        self.searchBlocksJSONL = searchBlocksJSONL
        self.extraProjections = extraProjections
        self.assets = assets
        self.exports = exports
    }
}

// MARK: - Errors

nonisolated public enum EpdocPackageError: Error, CustomStringConvertible {
    case missingManifest
    case missingContent
    case malformedManifest(underlying: Error)
    case manifestSchemaTooNew(version: UInt32)
    case wrongFileWrapperShape

    public var description: String {
        switch self {
        case .missingManifest:
            return "EpdocPackage: missing required manifest.json"
        case .missingContent:
            return "EpdocPackage: missing required content.pm.json"
        case .malformedManifest(let underlying):
            return "EpdocPackage: malformed manifest.json — \(underlying)"
        case .manifestSchemaTooNew(let version):
            return "EpdocPackage: manifest.json schema_version \(version) is newer than this build understands"
        case .wrongFileWrapperShape:
            return "EpdocPackage: file wrapper is not a directory wrapper"
        }
    }
}

// MARK: - FileWrapper bridge

extension EpdocPackage {
    /// Build a directory `FileWrapper` mirroring the in-memory tree.
    /// The returned wrapper's `preferredFilename` is unset — callers
    /// (typically NSDocument) set it to the document's base name +
    /// `.epdoc` extension.
    ///
    /// `manifest.json` is always emitted first via JSON encoding;
    /// `content.pm.json` is written verbatim from `contentJSON` (no
    /// re-serialization — preserves byte-equal canonical bytes across
    /// load → save round-trips).
    public func makeFileWrapper(jsonEncoder: JSONEncoder = .epdocCanonical) throws -> FileWrapper {
        var topLevel: [String: FileWrapper] = [:]

        let manifestData = try jsonEncoder.encode(manifest)
        topLevel[EpdocPackageEntry.manifest] = FileWrapper(regularFileWithContents: manifestData)

        topLevel[EpdocPackageEntry.content] = FileWrapper(regularFileWithContents: contentJSON)

        // projections/
        var projChildren: [String: FileWrapper] = [:]
        if let shadow = shadowMarkdown {
            projChildren[EpdocPackageEntry.Projection.shadowMarkdown] =
                FileWrapper(regularFileWithContents: shadow)
        }
        if let plain = plainText {
            projChildren[EpdocPackageEntry.Projection.plainText] =
                FileWrapper(regularFileWithContents: plain)
        }
        if let blocks = searchBlocksJSONL {
            projChildren[EpdocPackageEntry.Projection.searchBlocksJSONL] =
                FileWrapper(regularFileWithContents: blocks)
        }
        for (name, data) in extraProjections {
            projChildren[name] = FileWrapper(regularFileWithContents: data)
        }
        if !projChildren.isEmpty {
            topLevel[EpdocPackageEntry.projections] =
                FileWrapper(directoryWithFileWrappers: projChildren)
        }

        if !assets.isEmpty {
            var children: [String: FileWrapper] = [:]
            for (name, data) in assets {
                children[name] = FileWrapper(regularFileWithContents: data)
            }
            topLevel[EpdocPackageEntry.assets] = FileWrapper(directoryWithFileWrappers: children)
        }

        if !exports.isEmpty {
            var children: [String: FileWrapper] = [:]
            for (name, data) in exports {
                children[name] = FileWrapper(regularFileWithContents: data)
            }
            topLevel[EpdocPackageEntry.exports] = FileWrapper(directoryWithFileWrappers: children)
        }

        return FileWrapper(directoryWithFileWrappers: topLevel)
    }

    /// Decode a directory `FileWrapper` into an in-memory package.
    /// Treats `manifest.json` + `content.pm.json` as REQUIRED — missing
    /// either is an error. Any other top-level file or unrecognised
    /// projection is preserved (in `extraProjections` for projections,
    /// dropped at the package root).
    public init(
        fileWrapper: FileWrapper,
        jsonDecoder: JSONDecoder = .epdocCanonical
    ) throws {
        guard fileWrapper.isDirectory, let children = fileWrapper.fileWrappers else {
            throw EpdocPackageError.wrongFileWrapperShape
        }

        guard let manifestWrapper = children[EpdocPackageEntry.manifest],
              let manifestData = manifestWrapper.regularFileContents else {
            throw EpdocPackageError.missingManifest
        }

        let manifest: EpdocManifest
        do {
            manifest = try jsonDecoder.decode(EpdocManifest.self, from: manifestData)
        } catch {
            throw EpdocPackageError.malformedManifest(underlying: error)
        }
        if manifest.schemaVersion > EpdocManifest.currentSchemaVersion {
            throw EpdocPackageError.manifestSchemaTooNew(version: manifest.schemaVersion)
        }

        guard let contentWrapper = children[EpdocPackageEntry.content],
              let contentData = contentWrapper.regularFileContents else {
            throw EpdocPackageError.missingContent
        }

        var shadow: Data?
        var plain: Data?
        var blocks: Data?
        var extra: [String: Data] = [:]
        if let projWrapper = children[EpdocPackageEntry.projections],
           projWrapper.isDirectory,
           let projChildren = projWrapper.fileWrappers {
            for (name, wrapper) in projChildren {
                guard let data = wrapper.regularFileContents else { continue }
                switch name {
                case EpdocPackageEntry.Projection.shadowMarkdown:    shadow = data
                case EpdocPackageEntry.Projection.plainText:         plain = data
                case EpdocPackageEntry.Projection.searchBlocksJSONL: blocks = data
                default: extra[name] = data
                }
            }
        }

        var assets: [String: Data] = [:]
        if let assetsWrapper = children[EpdocPackageEntry.assets],
           assetsWrapper.isDirectory,
           let assetChildren = assetsWrapper.fileWrappers {
            for (name, wrapper) in assetChildren {
                if let data = wrapper.regularFileContents {
                    assets[name] = data
                }
            }
        }

        var exports: [String: Data] = [:]
        if let exportsWrapper = children[EpdocPackageEntry.exports],
           exportsWrapper.isDirectory,
           let exportChildren = exportsWrapper.fileWrappers {
            for (name, wrapper) in exportChildren {
                if let data = wrapper.regularFileContents {
                    exports[name] = data
                }
            }
        }

        self.init(
            manifest: manifest,
            contentJSON: contentData,
            shadowMarkdown: shadow,
            plainText: plain,
            searchBlocksJSONL: blocks,
            extraProjections: extra,
            assets: assets,
            exports: exports
        )
    }
}

// MARK: - JSON encoder/decoder defaults

public extension JSONEncoder {
    /// Canonical encoder for `.epdoc` packages: pretty-printed +
    /// sorted keys so the on-disk manifest is diff-friendly.
    static var epdocCanonical: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    /// Canonical decoder for `.epdoc` packages. Tolerates extra keys
    /// (forward compatibility) by default — JSONDecoder's default
    /// behaviour is to ignore unknown keys, which is what we want.
    static var epdocCanonical: JSONDecoder {
        JSONDecoder()
    }
}
