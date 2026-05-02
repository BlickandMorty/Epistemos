import Foundation
import Darwin
import OSLog

// MARK: - EpistemosSidecar
//
// Phase 12 of the master plan / Wave 13 §"Phase 12": adds a
// machine-readable JSON sidecar layer next to the user's
// human-readable source files (markdown notes, chat exports, etc.).
//
// Doc 2 amendment (canonical Wave 9-11 §"Doc 2 plan-corrections"):
// the sidecar is **additive** to markdown — never a replacement.
// Notes stay legible, exportable, `vim`-able. Epistemos *adds*
// `[entity-id].epistemos.json` alongside each note file. The moat
// is dual representation without user pain.
//
// Wire format mirrors the Rust struct documented in Wave 13:
//
//   #[derive(Serialize, Deserialize, JsonSchema)]
//   #[serde(deny_unknown_fields, rename_all = "camelCase")]
//   struct EpistemosSidecar {
//       schema_version: u16,
//       entity_id: Ulid,
//       depth: DepthMarker,
//       parent_domain: Option<String>,
//       child_concept: Option<String>,
//       interpretation_directive: Option<String>,
//       derived_from: Vec<Ulid>,
//       embeddings: Option<EmbeddingRef>,
//       cognitive_meta: CognitiveMeta,
//       annotations: Vec<Annotation>,
//   }
//
// The Swift type below is the source-of-truth on the Swift side;
// the Rust ETL (Phase 13, follow-up) reads/writes the same JSON
// shape via its own struct mirror. `schema_version` is per-row so
// individual sidecars can migrate independently.
//
// **Code-file exclusion rule** (master plan §13 + Wave 9 §safety):
// the sidecar generation MUST never touch source-code files. The
// hardcoded suffix list lives in `EpistemosSidecarPolicy` below
// and is enforced by the only public mint / write entry points.

// MARK: - Sidecar payload

nonisolated public struct EpistemosSidecar: Codable, Sendable, Equatable {

    /// Schema version for forward-compatible migrations. Bump when
    /// adding/renaming fields with semantic meaning. Reserve `0` for
    /// "schema-less stub" sidecars (not yet enriched by AFM).
    public var schemaVersion: UInt16

    /// ULID identity for the entity this sidecar describes. Stable
    /// across renames of the source file (the sidecar tracks the
    /// entity, not the path). Encode as the canonical 26-char Crockford
    /// base32 string — readable + URL-safe + lexicographically-time-
    /// orderable.
    public var entityId: String

    /// Knowledge depth marker (L1 / L2 / L3 — master plan Phase 8).
    /// Mirrors `DepthMarker` from `OntologyClassifier.swift` so the
    /// classifier can write directly into a sidecar.
    public var depth: DepthMarker

    /// Parent domain in the ontology — emitted by the W10.1 classifier
    /// as a lowercase kebab-case string (e.g. "neuroscience").
    /// Optional because user-created notes may not be classified yet.
    public var parentDomain: String?

    /// Primary child concept under `parentDomain` — emitted by the
    /// W10.1 classifier as lowercase kebab-case (e.g. "basal-ganglia").
    /// Optional for pre-classifier sidecars and manual user notes.
    public var childConcept: String?

    /// Additive model-facing instruction for how to interpret the
    /// sidecar without replacing the user's canonical Markdown source.
    public var interpretationDirective: String?

    /// AFM-generated 1-2 sentence note summary. Optional for legacy
    /// sidecars and user-authored stubs that have not passed through
    /// the R16 sidecar generator.
    public var summary: String?

    /// AFM-generated retrieval tags. Kept separate from the user's
    /// visible note tags so generated metadata remains auditable.
    public var tags: [String]?

    /// AFM-generated salient entities (people, projects, concepts).
    public var entities: [String]?

    /// AFM-suggested links to other notes by stable note/page ID.
    public var suggestedLinks: [AFMSidecarSuggestedLink]?

    /// Other entity IDs this sidecar was derived from (note merges,
    /// summarisations, transclusions). Empty for primary user notes.
    public var derivedFrom: [String]

    /// Optional reference to an embedding cached elsewhere (Halo
    /// Shadow index keyspace). Future versions may inline a quantised
    /// vector here for offline use; kept as a reference today to keep
    /// sidecars small + diff-friendly.
    public var embeddings: EmbeddingRef?

    /// Cognitive metadata — author intent, emotional valence,
    /// timestamp chains, etc. The shape evolves with the ontology;
    /// schema version gates what's expected.
    public var cognitiveMeta: CognitiveMeta

    /// Free-form annotations the AFM classifier or user can append
    /// without invalidating the schema. Each annotation is timestamped
    /// + author-tagged so the audit trail survives merges.
    public var annotations: [Annotation]

    public init(
        schemaVersion: UInt16 = Self.currentSchemaVersion,
        entityId: String,
        depth: DepthMarker,
        parentDomain: String? = nil,
        childConcept: String? = nil,
        interpretationDirective: String? = nil,
        summary: String? = nil,
        tags: [String]? = nil,
        entities: [String]? = nil,
        suggestedLinks: [AFMSidecarSuggestedLink]? = nil,
        derivedFrom: [String] = [],
        embeddings: EmbeddingRef? = nil,
        cognitiveMeta: CognitiveMeta = CognitiveMeta(),
        annotations: [Annotation] = []
    ) {
        self.schemaVersion = schemaVersion
        self.entityId = entityId
        self.depth = depth
        self.parentDomain = parentDomain
        self.childConcept = childConcept
        self.interpretationDirective = interpretationDirective
        self.summary = summary
        self.tags = tags
        self.entities = entities
        self.suggestedLinks = suggestedLinks
        self.derivedFrom = derivedFrom
        self.embeddings = embeddings
        self.cognitiveMeta = cognitiveMeta
        self.annotations = annotations
    }

    /// Current schema version. Bump when fields are added/renamed
    /// with semantic meaning so writes always carry the latest tag.
    public static let currentSchemaVersion: UInt16 = 3

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case entityId = "entity_id"
        case depth
        case parentDomain = "parent_domain"
        case childConcept = "child_concept"
        case interpretationDirective = "interpretation_directive"
        case summary
        case tags
        case entities
        case suggestedLinks = "suggested_links"
        case derivedFrom = "derived_from"
        case embeddings
        case cognitiveMeta = "cognitive_meta"
        case annotations
    }
}

// MARK: - Suggested Links

nonisolated public struct AFMSidecarSuggestedLink: Codable, Sendable, Equatable, Hashable {
    /// Stable target note/page ID. The generator should choose from
    /// caller-provided candidates, not invent file paths.
    public var targetId: String

    /// Human-readable note title for display and diff review.
    public var title: String

    /// Short model-generated reason this link may matter.
    public var reason: String

    public init(targetId: String, title: String, reason: String) {
        self.targetId = targetId
        self.title = title
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case title
        case reason
    }
}

// MARK: - EmbeddingRef

nonisolated public struct EmbeddingRef: Codable, Sendable, Equatable, Hashable {
    /// Halo Shadow index identifier — the doc_id this entity is
    /// addressable as in the lexical + dense layers.
    public var shadowDocId: String

    /// Embedding dimensionality (e.g. 384 for the W8 default).
    /// Tracked so a future re-embedding pass knows whether the
    /// reference is still valid against the current model.
    public var dim: UInt16

    /// Provenance string — which embedding model produced this. Useful
    /// when the user upgrades the embedder and needs to invalidate
    /// stale references.
    public var source: String

    public init(shadowDocId: String, dim: UInt16, source: String) {
        self.shadowDocId = shadowDocId
        self.dim = dim
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case shadowDocId = "shadow_doc_id"
        case dim
        case source
    }
}

// MARK: - CognitiveMeta

nonisolated public struct CognitiveMeta: Codable, Sendable, Equatable {
    /// ISO-8601 string for when the source content was first ingested.
    public var firstSeenAt: String?

    /// ISO-8601 string for when the AFM classifier last enriched the
    /// sidecar (separate from the source file's mtime).
    public var lastClassifiedAt: String?

    /// Confidence the classifier had in the parent_domain assignment,
    /// 0.0–1.0. Used by the W11.4 Manual mode to decide whether to
    /// surface the classification proposal vs accept silently.
    public var classificationConfidence: Double?

    /// Optional emotional-valence anchor (W10.16 conversation state +
    /// master plan Phase 11 brain dumps). Range -1.0 (negative) to
    /// 1.0 (positive); nil when not yet measured.
    public var emotionalValence: Double?

    /// Number of times the user has explicitly accessed this entity
    /// since ingestion — feeds the W10.2 / W10.15 retrieval-prior
    /// decay (NOT vector quantisation, per the Doc 2 amendment:
    /// "decay retrieval priors over time, rehydrate when relevant").
    public var accessCount: UInt64

    public init(
        firstSeenAt: String? = nil,
        lastClassifiedAt: String? = nil,
        classificationConfidence: Double? = nil,
        emotionalValence: Double? = nil,
        accessCount: UInt64 = 0
    ) {
        self.firstSeenAt = firstSeenAt
        self.lastClassifiedAt = lastClassifiedAt
        self.classificationConfidence = classificationConfidence
        self.emotionalValence = emotionalValence
        self.accessCount = accessCount
    }

    enum CodingKeys: String, CodingKey {
        case firstSeenAt = "first_seen_at"
        case lastClassifiedAt = "last_classified_at"
        case classificationConfidence = "classification_confidence"
        case emotionalValence = "emotional_valence"
        case accessCount = "access_count"
    }
}

// MARK: - Annotation

nonisolated public struct Annotation: Codable, Sendable, Equatable {
    /// ISO-8601 timestamp of when this annotation was written.
    public var at: String

    /// Author tag — `"user"`, `"afm"`, `"hermes"`, `"claude-code"` etc.
    /// Lets the UI show provenance and lets future merges dedupe by
    /// author + content.
    public var author: String

    /// Free-form annotation body. Markdown-friendly so the same field
    /// renders cleanly in a `vim` view of the sidecar AND in the
    /// SwiftUI inspector.
    public var body: String

    public init(at: String, author: String, body: String) {
        self.at = at
        self.author = author
        self.body = body
    }
}

// MARK: - Code-file exclusion policy

/// Enforces the master-plan Phase 12 / Wave 9 safety constraint:
/// **`.epistemos.json` sidecar generation MUST never touch source-code
/// files.** The exclusion list is hardcoded; future additions require a
/// commit + review (no runtime config).
nonisolated public enum EpistemosSidecarPolicy {

    /// File extensions the sidecar engine MUST refuse to touch. Bias
    /// toward over-exclusion: a programming language being missed
    /// here means corrupting the user's source code, which is
    /// catastrophic; over-excluding a markdown variant means a note
    /// doesn't get a sidecar, which is benign.
    public static let excludedExtensions: Set<String> = [
        // Compiled / source languages
        "swift", "rs", "py", "go", "java", "kt", "kts", "scala",
        "c", "cc", "cpp", "cxx", "h", "hh", "hpp", "hxx",
        "m", "mm", "ts", "tsx", "js", "jsx", "mjs", "cjs",
        "rb", "php", "lua", "pl", "pm", "elm", "ex", "exs",
        "cs", "fs", "fsi", "vb", "rb", "erl", "hrl",
        // Build / config / lock
        "json", "toml", "yaml", "yml", "lock", "xml", "plist",
        "gradle", "cmake", "ninja", "bazel", "bzl",
        // Shell / scripts
        "sh", "bash", "zsh", "fish", "ps1", "psm1",
        // Project / IDE
        "pbxproj", "xcconfig", "xcscheme", "entitlements",
        // GPU / shaders
        "metal", "wgsl", "glsl", "hlsl",
    ]

    /// Path patterns that the ETL crawler MUST skip even if the file
    /// extension wasn't on the excluded list. Hardcoded so a custom
    /// `.pkmignore` can't accidentally allow them in.
    public static let excludedPathSegments: Set<String> = [
        ".git", ".build", "build", "DerivedData", "target",
        "node_modules", ".venv", "venv", "__pycache__",
        ".idea", ".vscode", "Pods", ".cocoapods", "xcuserdata",
        ".swiftpm", ".cache", ".tox", ".pytest_cache", ".mypy_cache",
    ]

    /// Returns true when the given URL is allowed to receive a sidecar.
    /// The check is conservative — both extension AND path segments
    /// must clear the exclusion list.
    public static func isEligible(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if excludedExtensions.contains(ext) { return false }
        for component in url.pathComponents {
            if excludedPathSegments.contains(component) { return false }
        }
        return true
    }
}

// MARK: - Sidecar I/O

/// Sidecar filename convention: `<source-stem>.epistemos.json` placed
/// next to the source file. Stable JSON encoding (sortedKeys +
/// prettyPrinted) so `git diff` is human-readable.
nonisolated public enum EpistemosSidecarStore {

    public static let modelDerivedAttributeName = "com.epistemos.modelDerived"

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "EpistemosSidecar"
    )

    public enum SidecarError: Error {
        case ineligibleSource(URL)
        case readFailed(URL, Error)
        case writeFailed(URL, Error)
        case decodeFailed(URL, Error)
        case encodeFailed(URL, Error)
        case modelDerivedMarkFailed(URL, Int32)
    }

    /// Resolve the canonical sidecar URL for a source file. Returns
    /// nil for ineligible sources (code files, build dirs, etc.).
    public static func sidecarURL(for source: URL) -> URL? {
        guard EpistemosSidecarPolicy.isEligible(source) else { return nil }
        let stem = source.deletingPathExtension().lastPathComponent
        let dir = source.deletingLastPathComponent()
        return dir.appendingPathComponent("\(stem).epistemos.json")
    }

    /// Read + decode the sidecar for `source`, if one exists. Returns
    /// nil when the source has no sidecar yet (caller decides whether
    /// to mint a new one).
    ///
    /// AP2 perf-fix — consults `SidecarCache.shared` first; on miss
    /// reads from disk + caches the decoded object so subsequent
    /// CognitiveDepthOverlay / annotation / parent_domain reads pay
    /// only the in-memory cost. The cache is invalidated by `write`
    /// + by FSEvents file-watcher callbacks (Phase 13 follow-up).
    public static func read(for source: URL) throws -> EpistemosSidecar? {
        guard let url = sidecarURL(for: source) else {
            throw SidecarError.ineligibleSource(source)
        }
        if let cached = SidecarCache.shared.lookup(url) { return cached }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw SidecarError.readFailed(url, error) }
        do {
            let decoded = try Self.decoder.decode(EpistemosSidecar.self, from: data)
            SidecarCache.shared.store(decoded, for: url)
            return decoded
        }
        catch { throw SidecarError.decodeFailed(url, error) }
    }

    /// Atomically write `sidecar` for `source`. Encoding is
    /// deterministic so re-saving an unchanged sidecar is a no-op
    /// at the byte level (git-friendly).
    public static func write(
        _ sidecar: EpistemosSidecar,
        for source: URL,
        modelDerived: Bool = false
    ) throws {
        guard let url = sidecarURL(for: source) else {
            throw SidecarError.ineligibleSource(source)
        }
        let data: Data
        do { data = try Self.encoder.encode(sidecar) }
        catch { throw SidecarError.encodeFailed(url, error) }
        do { try data.write(to: url, options: [.atomic]) }
        catch { throw SidecarError.writeFailed(url, error) }
        if modelDerived {
            try Self.markModelDerived(url)
        }
        // AP2 — refresh the in-memory cache after a successful
        // write. Subsequent reads hit the cache without a disk
        // round-trip.
        SidecarCache.shared.store(sidecar, for: url)
        log.debug(
            "Wrote sidecar (\(data.count, privacy: .public)B) for \(source.lastPathComponent, privacy: .public)"
        )
    }

    private static func markModelDerived(_ url: URL) throws {
        let value = Array("true".utf8)
        let result = url.path.withCString { path in
            modelDerivedAttributeName.withCString { name in
                value.withUnsafeBytes { rawBuffer in
                    setxattr(path, name, rawBuffer.baseAddress, rawBuffer.count, 0, 0)
                }
            }
        }
        guard result == 0 else {
            throw SidecarError.modelDerivedMarkFailed(url, errno)
        }
    }

    /// Read-only audit helper for UI disclosure. Fails closed: missing,
    /// ineligible, unreadable, or malformed sidecars are treated as
    /// not model-derived rather than surfacing a misleading badge.
    public static func isModelDerived(for source: URL) -> Bool {
        guard let url = sidecarURL(for: source),
              FileManager.default.fileExists(atPath: url.path)
        else { return false }
        return modelDerivedAttributeValue(for: url) == "true"
    }

    private static func modelDerivedAttributeValue(for url: URL) -> String? {
        let size = url.path.withCString { path in
            modelDerivedAttributeName.withCString { name in
                getxattr(path, name, nil, 0, 0, 0)
            }
        }
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let read = buffer.withUnsafeMutableBytes { rawBuffer in
            url.path.withCString { path in
                modelDerivedAttributeName.withCString { name in
                    getxattr(path, name, rawBuffer.baseAddress, rawBuffer.count, 0, 0)
                }
            }
        }
        guard read > 0 else { return nil }
        return String(decoding: buffer.prefix(read), as: UTF8.self)
    }

    /// AP7 — bulk pre-warm the in-memory sidecar cache by reading up
    /// to `maxSidecars` `*.epistemos.json` files under `vaultRoot` in
    /// parallel via concurrent file I/O. Called from AppBootstrap
    /// after the vault is ready so the first graph render /
    /// depth-overlay query avoids unbounded per-node disk cost.
    /// Returns the count of sidecars warmed.
    @discardableResult
    public static func prefetchAll(
        under vaultRoot: URL,
        maxSidecars: Int = SidecarCache.bound
    ) async -> Int {
        guard maxSidecars > 0 else { return 0 }
        let sidecarURLs = enumerateSidecarsSync(under: vaultRoot, maxCount: maxSidecars)
        // Cap parallelism so we don't open thousands of file
        // descriptors at once on huge vaults.
        let parallelism = min(8, max(2, ProcessInfo.processInfo.activeProcessorCount / 2))
        var warmed = 0
        var nextIndex = 0
        await withTaskGroup(of: Bool.self) { group in
            // Seed `parallelism` initial tasks
            while nextIndex < parallelism, nextIndex < sidecarURLs.count {
                let url = sidecarURLs[nextIndex]
                nextIndex += 1
                group.addTask { await Self.prefetchOne(url) }
            }
            while let didWarm = await group.next() {
                if didWarm { warmed += 1 }
                if nextIndex < sidecarURLs.count {
                    let url = sidecarURLs[nextIndex]
                    nextIndex += 1
                    group.addTask { await Self.prefetchOne(url) }
                }
            }
        }
        log.info("AP7 prefetched \(warmed, privacy: .public) sidecars under \(vaultRoot.lastPathComponent, privacy: .public)")
        return warmed
    }

    private static func prefetchOne(_ url: URL) async -> Bool {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? Self.decoder.decode(EpistemosSidecar.self, from: data)
        else { return false }
        SidecarCache.shared.store(decoded, for: url)
        return true
    }

    /// Synchronous helper — `FileManager.enumerator` isn't Sendable
    /// across async boundaries on macOS 26, so we collect URLs in a
    /// nonisolated sync function and pass the resulting `[URL]` (a
    /// Sendable value type) into the async prefetch loop.
    nonisolated private static func enumerateSidecarsSync(
        under vaultRoot: URL,
        maxCount: Int
    ) -> [URL] {
        guard maxCount > 0 else { return [] }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "json",
               url.lastPathComponent.hasSuffix(".epistemos.json") {
                urls.append(url)
                if urls.count >= maxCount { break }
            }
        }
        return urls
    }

    /// Mint a fresh sidecar stub for a source file with an unset
    /// schema (`schemaVersion = 0`). The classifier upgrades the
    /// schema later when AFM finishes enriching the entity.
    public static func mintStub(for source: URL, depth: DepthMarker = .surface) -> EpistemosSidecar {
        EpistemosSidecar(
            schemaVersion: 0,
            entityId: Self.makeEntityId(),
            depth: depth,
            cognitiveMeta: CognitiveMeta(
                firstSeenAt: ISO8601DateFormatter().string(from: Date())
            )
        )
    }

    /// Generate a 26-char Crockford-base32 ULID for an `entity_id`.
    /// We don't pull in a ULID dep yet — this function is a
    /// hand-rolled time-prefixed Crockford-base32 random ID that
    /// matches ULID spec semantics (lexicographic time-orderability
    /// + collision-resistant random suffix). Bump to `Ulid` crate if
    /// performance ever matters.
    static func makeEntityId() -> String {
        let crockford = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        let nowMs = UInt64(Date().timeIntervalSince1970 * 1000)
        var time = nowMs
        var timePart = Array(repeating: "0", count: 10)
        for i in (0..<10).reversed() {
            timePart[i] = String(crockford[Int(time & 0x1F)])
            time >>= 5
        }
        var rand = [UInt8](repeating: 0, count: 16)
        _ = SystemRandomNumberGenerator.fillRandom(&rand)
        var randPart = ""
        randPart.reserveCapacity(16)
        for byte in rand.prefix(16) {
            randPart.append(crockford[Int(byte & 0x1F)])
        }
        return timePart.joined() + randPart
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    private static let decoder = JSONDecoder()
}

// MARK: - SystemRandomNumberGenerator helper

nonisolated extension SystemRandomNumberGenerator {
    /// Fill the buffer with cryptographically random bytes.
    fileprivate static func fillRandom(_ buf: inout [UInt8]) -> Bool {
        var rng = SystemRandomNumberGenerator()
        for i in 0..<buf.count {
            buf[i] = UInt8.random(in: 0...UInt8.max, using: &rng)
        }
        return true
    }
}
