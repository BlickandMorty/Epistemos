import Foundation
import UniformTypeIdentifiers

// MARK: - EpdocManifest
//
// Wave 7.1 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.1,
//  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3-4).
//
// `manifest.json` for a `.epdoc` package — mirrors the canonical Rust
// `ArtifactHeader` + `ProvenanceBlock` shape from the cognitive artifact
// plan §3 so the Swift writer / Rust reader round-trip byte-equal.
//
// Field naming follows snake_case on the wire (matches the Rust serde
// rename convention used by RawThoughtsManifest + ArtifactKind enum).

/// Producer of an artifact — who/what created it.
nonisolated public enum EpdocProducer: String, Codable, Sendable, Hashable {
    case human
    case agent
    case system
}

/// Lightweight reference to another artifact in the workspace. Carries
/// just enough to resolve the target without embedding it. Used by
/// `EpdocProvenance.derivedFrom`, `.sourceArtifacts`, `.outputArtifacts`.
nonisolated public struct EpdocArtifactRef: Codable, Sendable, Hashable {
    /// ULID/UUID/SwiftData ID of the referenced artifact. The exact id
    /// scheme is decided by the resolver — this layer treats it opaquely.
    public let id: String
    /// Kind of the referenced artifact (mirrors Wave 3.2 unified
    /// taxonomy). Optional — old links may not record it.
    public let kind: ArtifactKind?
    /// Human-readable title at the time the link was captured. May be
    /// stale relative to the current artifact title; UI should refresh.
    public let title: String?

    public init(id: String, kind: ArtifactKind? = nil, title: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
    }
}

/// Provenance metadata — answers "where did this artifact come from".
nonisolated public struct EpdocProvenance: Codable, Sendable, Hashable {
    public let producer: EpdocProducer
    public let derivedFrom: [EpdocArtifactRef]
    /// Optional run id (Raw Thoughts manifest's `run_id`) when the
    /// artifact was produced by an agent run.
    public let generatedByRun: String?
    /// Optional tool name when the artifact came directly from a tool
    /// invocation (`vault_search`, `web_fetch`, etc.).
    public let toolId: String?
    public let sourceArtifacts: [EpdocArtifactRef]
    public let outputArtifacts: [EpdocArtifactRef]

    public init(
        producer: EpdocProducer,
        derivedFrom: [EpdocArtifactRef] = [],
        generatedByRun: String? = nil,
        toolId: String? = nil,
        sourceArtifacts: [EpdocArtifactRef] = [],
        outputArtifacts: [EpdocArtifactRef] = []
    ) {
        self.producer = producer
        self.derivedFrom = derivedFrom
        self.generatedByRun = generatedByRun
        self.toolId = toolId
        self.sourceArtifacts = sourceArtifacts
        self.outputArtifacts = outputArtifacts
    }

    enum CodingKeys: String, CodingKey {
        case producer
        case derivedFrom = "derived_from"
        case generatedByRun = "generated_by_run"
        case toolId = "tool_id"
        case sourceArtifacts = "source_artifacts"
        case outputArtifacts = "output_artifacts"
    }
}

/// `manifest.json` — the canonical document header. One per `.epdoc`
/// package; loaded first by every reader to determine kind + version.
nonisolated public struct EpdocManifest: Codable, Sendable, Hashable {
    /// Stable ULID/UUID for the artifact. Persists across renames.
    public let id: String
    /// Wave 3.2 unified ArtifactKind. For `.epdoc` packages this is
    /// almost always `.document`, but the field is written so a future
    /// kind (e.g. an Output bundle that ships as a package) reuses the
    /// same on-disk shape.
    public let kind: ArtifactKind
    /// Bumped on every backwards-incompatible manifest schema change.
    /// Readers MUST tolerate higher schema_version (forward compat) by
    /// ignoring unknown fields, never by failing to load.
    public let schemaVersion: UInt32
    /// Unix milliseconds.
    public let createdAt: Int64
    public let updatedAt: Int64
    public let title: String
    /// Blake3 / SHA-256 hex digest of `content.pm.json` at write time.
    /// Readers compare against the live content hash on load to detect
    /// out-of-band edits to the canonical file.
    public let contentHash: String
    public let provenance: EpdocProvenance
    /// Wave 7.6 follow-up — free-form metadata bag for theme name,
    /// icon name, accent color hex, display mode, etc. Optional, so
    /// older readers tolerate its absence; newer readers can extend
    /// the convention without bumping `schema_version`.
    ///
    /// Keys are app-defined (no schema enforcement here). Stringified
    /// values keep the `Codable` derivation trivial — booleans become
    /// `"true"`/`"false"`, numbers become decimal strings. If a future
    /// caller needs nested structure, store JSON-encoded text in the
    /// value and decode at the call site.
    ///
    /// Borrowed from Smaug6739/Alexandrie's `nodes.metadata JSON`
    /// column pattern (2026-04-26 scan).
    public let metadata: [String: String]?

    public static let currentSchemaVersion: UInt32 = 1

    public init(
        id: String,
        kind: ArtifactKind = .document,
        schemaVersion: UInt32 = currentSchemaVersion,
        createdAt: Int64,
        updatedAt: Int64,
        title: String,
        contentHash: String,
        provenance: EpdocProvenance,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.contentHash = contentHash
        self.provenance = provenance
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title
        case contentHash = "content_hash"
        case provenance
        case metadata
    }
}

// MARK: - UTType

/// Canonical UTType for `.epdoc` packages. Conforms to `UTType.package`
/// + `UTType.compositeContent` per Apple TN3178 so Finder / Spotlight /
/// Quick Look treat the directory bundle as a single logical document.
///
/// The full Finder integration also requires a matching declaration
/// in Info.plist's `UTExportedTypeDeclarations` + `CFBundleDocumentTypes`;
/// that wiring is a project.yml follow-up. This programmatic declaration
/// is enough for in-app NSDocument round-trips and the source-guard tests.
public extension UTType {
    static var epdoc: UTType {
        UTType(exportedAs: "com.epistemos.epdoc",
               conformingTo: .package)
    }
}
