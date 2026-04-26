import CryptoKit
import Foundation

// MARK: - CodeArtifactSidecar
//
// Wave 9.2 + W9.3 of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §"unified provenance" + brain
//  dump 2026-04-26).
//
// Per the brain dump: when AI generates / mentions code in a chat
// (raw thought), and when an agent tool writes a file, the resulting
// code artifact must auto-link into the unified substrate so future
// agents querying the index see "this file came from this run, this
// thought, derived from this source artifact." Closing the provenance
// loop is what makes upstream agents superpowered.
//
// Per the user's correct intuition: **NEVER embed sidecar data inside
// the source file** (compilers see the bytes; git diffs blow up;
// formatters fight you). Store derivatives as a sibling JSON.
//
// Layout:
//
//     <vault-root>/.epcache/code/<sha256-hex-of-vault-rel-path>.epcode.json
//
// Why hash of the path instead of name+ext: rename-safe (the file
// can move within the vault and we re-resolve via the path-hash on
// the next index pass). A vault-level cache directory keeps source
// dirs pristine + makes the cache trivially gitignore-able
// (`.epcache/` lives outside any tracked source tree).
//
// SHA-256 (CryptoKit, no extra dep) — the Rust counterpart in
// `epistemos-code-index/src/sidecar.rs` mirrors this byte-for-byte
// (see `path_hash_matches_swift_fixture_sources_foo_swift` test).
// blake3 is a future swap once both sides can take the dependency.

// MARK: - Provenance

/// Code-artifact provenance — mirror of `EpdocProvenance` for code
/// files. When an agent or human creates the file, the producer +
/// derivedFrom + generatedByRun + toolId fields capture the full
/// upstream story so a future agent's "where did this come from"
/// query has a single authoritative answer.
nonisolated public struct CodeProvenance: Codable, Sendable, Hashable {
    public let producer: EpdocProducer
    public let derivedFrom: [EpdocArtifactRef]
    /// Optional run id (RawThoughtsManifest.run_id) when the file was
    /// produced by an agent run.
    public let generatedByRun: String?
    /// Optional thinking-block index that originated the code in
    /// the agent's reasoning trace (linked to a thoughts/<idx>.json
    /// sidecar from Wave 3.1).
    public let originatedFromThoughtIndex: UInt32?
    /// Optional tool name when the file was produced by a single
    /// tool invocation (e.g., `write_file`, `edit_file`).
    public let toolId: String?
    /// Optional tool_use_id (mirrors the tools/<tool_use_id>.json
    /// sidecar from Wave 3.1) so the inspector can jump from the
    /// code file straight to its full tool trace.
    public let toolUseId: String?
    public let sourceArtifacts: [EpdocArtifactRef]

    public init(
        producer: EpdocProducer,
        derivedFrom: [EpdocArtifactRef] = [],
        generatedByRun: String? = nil,
        originatedFromThoughtIndex: UInt32? = nil,
        toolId: String? = nil,
        toolUseId: String? = nil,
        sourceArtifacts: [EpdocArtifactRef] = []
    ) {
        self.producer = producer
        self.derivedFrom = derivedFrom
        self.generatedByRun = generatedByRun
        self.originatedFromThoughtIndex = originatedFromThoughtIndex
        self.toolId = toolId
        self.toolUseId = toolUseId
        self.sourceArtifacts = sourceArtifacts
    }

    enum CodingKeys: String, CodingKey {
        case producer
        case derivedFrom = "derived_from"
        case generatedByRun = "generated_by_run"
        case originatedFromThoughtIndex = "originated_from_thought_index"
        case toolId = "tool_id"
        case toolUseId = "tool_use_id"
        case sourceArtifacts = "source_artifacts"
    }
}

// MARK: - Sidecar

/// Sidecar JSON written next to (well, into `.epcache/code/` for) every
/// indexed code file. Carries the embeddings + cross-refs the AI
/// indexer needs to "grep with semantics" — but kept SEPARATE from
/// the source file so the source stays pristine.
nonisolated public struct CodeArtifactSidecar: Codable, Sendable, Hashable {
    /// Bumped on every backwards-incompatible sidecar schema change.
    /// Readers MUST tolerate higher schema_version (forward compat) by
    /// ignoring unknown fields, never by failing to load.
    public let schemaVersion: UInt32
    /// Vault-relative path of the source file at index time (e.g.
    /// `Sources/Epistemos/Foo.swift`). The `.epcache` filename is
    /// blake3(this string), so this field doubles as the rename-detection
    /// witness — a mismatch between the recorded path and the live
    /// path triggers a sidecar rename + reindex.
    public let vaultRelativePath: String
    public let kind: CodeArtifactKind
    /// blake3 / SHA-256 of the source file bytes at index time. If
    /// the live file's hash diverges, the sidecar's embeddings are
    /// stale and need to be recomputed.
    public let contentHash: String
    /// Unix milliseconds at index time.
    public let indexedAt: Int64
    /// Provenance — who/what produced the file.
    public let provenance: CodeProvenance
    /// Symbol table extracted from the source. Used by the agent-grep
    /// API for "find the function named X". Empty for languages
    /// without a tree-sitter grammar (W9.6 follow-up wires the
    /// extractor).
    public let symbols: [CodeSymbol]
    /// Cross-reference links into other vault artifacts (e.g. "this
    /// file imports a function defined in Sources/Bar/Baz.swift" →
    /// EpdocArtifactRef pointing at that other file's sidecar).
    public let crossReferences: [EpdocArtifactRef]
    /// Embedding vector for the file's logical body (e.g. Model2Vec
    /// 256-dim L2-normalised). Stored as flat Float32 so the Rust
    /// indexer can mmap + bulk-load.
    public let embedding: [Float]?

    public static let currentSchemaVersion: UInt32 = 1

    public init(
        schemaVersion: UInt32 = currentSchemaVersion,
        vaultRelativePath: String,
        kind: CodeArtifactKind,
        contentHash: String,
        indexedAt: Int64,
        provenance: CodeProvenance,
        symbols: [CodeSymbol] = [],
        crossReferences: [EpdocArtifactRef] = [],
        embedding: [Float]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.vaultRelativePath = vaultRelativePath
        self.kind = kind
        self.contentHash = contentHash
        self.indexedAt = indexedAt
        self.provenance = provenance
        self.symbols = symbols
        self.crossReferences = crossReferences
        self.embedding = embedding
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case vaultRelativePath = "vault_relative_path"
        case kind
        case contentHash = "content_hash"
        case indexedAt = "indexed_at"
        case provenance
        case symbols
        case crossReferences = "cross_references"
        case embedding
    }
}

/// One symbol extracted from the source by the W9.6 tree-sitter
/// pass. Minimal shape — name + kind + byte range — so the agent-
/// grep API can rank by symbol-name fuzzy match without paying for
/// a heavy AST in the sidecar.
nonisolated public struct CodeSymbol: Codable, Sendable, Hashable {
    public let name: String
    public let kind: CodeSymbolKind
    public let utf8ByteStart: UInt32
    public let utf8ByteEnd: UInt32

    public init(name: String, kind: CodeSymbolKind, utf8ByteStart: UInt32, utf8ByteEnd: UInt32) {
        self.name = name
        self.kind = kind
        self.utf8ByteStart = utf8ByteStart
        self.utf8ByteEnd = utf8ByteEnd
    }

    enum CodingKeys: String, CodingKey {
        case name
        case kind
        case utf8ByteStart = "utf8_byte_start"
        case utf8ByteEnd = "utf8_byte_end"
    }
}

/// Coarse symbol kind — narrower than tree-sitter's full node
/// taxonomy on purpose. Adding a kind requires a sidecar schema
/// version bump (so old readers don't misinterpret).
nonisolated public enum CodeSymbolKind: String, Codable, Sendable, Hashable, CaseIterable {
    case function
    case method
    case type      // class, struct, enum, interface
    case property
    case variable
    case constant
    case macro
    case `import`
}

// MARK: - .epcache path resolver

/// Helpers that compute the canonical sidecar path for a vault-
/// relative source path.
nonisolated public enum CodeSidecarPath {

    /// Subdirectory under the vault root that holds every code
    /// sidecar. Trivially gitignore-able (`.epcache/`).
    public static let cacheRoot: String = ".epcache"
    /// Per-kind subdir keeps `code/`, future `notes/`, `chats/`
    /// etc. cleanly partitioned.
    public static let codeSubdir: String = "code"
    /// Sidecar filename suffix.
    public static let suffix: String = ".epcode.json"

    /// Compute the absolute sidecar URL for a given vault root + the
    /// vault-relative path of the source file.
    ///
    /// Example: vault `~/Vault`, file `Sources/Foo.swift`
    /// →  `~/Vault/.epcache/code/<blake3-or-sha256>.epcode.json`
    public static func sidecarURL(forVaultRoot vaultRoot: URL, vaultRelativePath: String) -> URL {
        let hash = Self.pathHash(vaultRelativePath)
        return vaultRoot
            .appendingPathComponent(cacheRoot, isDirectory: true)
            .appendingPathComponent(codeSubdir, isDirectory: true)
            .appendingPathComponent("\(hash)\(suffix)", isDirectory: false)
    }

    /// Lowercase-hex SHA-256 of the vault-relative path. The Rust
    /// indexer (`epistemos-code-index/src/sidecar.rs::path_hash`)
    /// MUST produce the same bytes for the same input — both sides
    /// pin a fixture for `"Sources/Foo.swift"` so any drift fails
    /// loudly in `cargo test` + the Swift test below.
    ///
    /// SHA-256 (CryptoKit, built-in) over blake3 (would need a new
    /// SPM dep); collision-resistant enough for a filename key.
    public static func pathHash(_ vaultRelativePath: String) -> String {
        let data = Data(vaultRelativePath.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
