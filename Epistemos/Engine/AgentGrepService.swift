import Foundation
import OSLog

// MARK: - AgentGrepService
//
// Wave 9.9 of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` + brain dump 2026-04-26).
//
// Per the user: "when AI grips or looks for files in a repo it will
// also look at those embeddings." This is the agent-facing grep API
// that gives models a unified search surface across:
//   1. Source files indexed by epistemos-code-index (W9.7)
//   2. Sidecar provenance from CodeFileService (W9.5)
//   3. Optional cross-references into Raw Thoughts manifests (W3.1)
//      and EpdocPackage artifacts (W7.1)
//
// The result for each hit carries the matching file + its full
// provenance chain (which run, which thought, which tool call) so
// the calling agent sees the upstream story without a second query.

/// Minimal abstraction over the epistemos-code-index FFI surface.
/// Real implementation will wrap the C ABI from `epistemos-code-index`
/// via `@_silgen_name`; tests use the in-memory stub below.
nonisolated public protocol CodeIndexClient: Sendable {
    func upsert(document: AgentGrepDocument) throws
    func remove(vaultRelativePath: String) throws
    func search(query: String, kindFilter: CodeArtifactKind?, limit: Int) throws -> [AgentGrepBackendHit]
}

/// Document the agent-grep service hands to the backend index. Mirrors
/// the Rust `CodeIndexDocument` field-for-field so the FFI round-trip
/// is mechanical.
nonisolated public struct AgentGrepDocument: Sendable, Hashable {
    public let vaultRelativePath: String
    public let kind: CodeArtifactKind
    public let body: String
    public let contentHash: String

    public init(
        vaultRelativePath: String,
        kind: CodeArtifactKind,
        body: String,
        contentHash: String
    ) {
        self.vaultRelativePath = vaultRelativePath
        self.kind = kind
        self.body = body
        self.contentHash = contentHash
    }
}

/// Raw hit returned by the backend index — vault path + kind + score
/// + snippet. The agent-grep service combines these with sidecar
/// provenance to produce the user-visible `AgentGrepHit`.
nonisolated public struct AgentGrepBackendHit: Sendable, Hashable {
    public let vaultRelativePath: String
    public let kind: CodeArtifactKind
    public let score: Float
    public let snippet: String
    public let symbol: String?
    public let source: String

    public init(
        vaultRelativePath: String,
        kind: CodeArtifactKind,
        score: Float,
        snippet: String,
        symbol: String? = nil,
        source: String = ""
    ) {
        self.vaultRelativePath = vaultRelativePath
        self.kind = kind
        self.score = score
        self.snippet = snippet
        self.symbol = symbol
        self.source = source
    }
}

/// Final result the agent sees: file location + relevance + the full
/// provenance chain (which run / thought / tool produced this code).
/// Provenance is `nil` only for files the indexer has seen but the
/// CodeFileService hasn't sidecared yet (rare; first-launch race).
nonisolated public struct AgentGrepHit: Sendable, Hashable {
    public let vaultRelativePath: String
    public let kind: CodeArtifactKind
    public let score: Float
    public let snippet: String
    public let symbol: String?
    public let source: String
    public let provenance: CodeProvenance?
    /// Cross-references the sidecar carries (other files / docs /
    /// raw-thought runs this file links to). Empty when the indexer
    /// hasn't enriched the sidecar yet.
    public let crossReferences: [EpdocArtifactRef]

    public init(
        vaultRelativePath: String,
        kind: CodeArtifactKind,
        score: Float,
        snippet: String,
        symbol: String?,
        source: String,
        provenance: CodeProvenance?,
        crossReferences: [EpdocArtifactRef]
    ) {
        self.vaultRelativePath = vaultRelativePath
        self.kind = kind
        self.score = score
        self.snippet = snippet
        self.symbol = symbol
        self.source = source
        self.provenance = provenance
        self.crossReferences = crossReferences
    }
}

/// Agent-facing grep service. Combines the W9.7 backend index with
/// the W9.5 CodeFileService to give upstream agents a single query
/// that returns matches + full provenance.
@MainActor
public final class AgentGrepService {

    public enum ServiceError: Error, CustomStringConvertible {
        case backendFailure(underlying: Error)

        public var description: String {
            switch self {
            case .backendFailure(let underlying):
                return "AgentGrepService: backend search failed: \(underlying)"
            }
        }
    }

    private let index: any CodeIndexClient
    private let files: CodeFileService
    private static let log = Logger(subsystem: "com.epistemos", category: "AgentGrepService")

    public init(index: any CodeIndexClient, files: CodeFileService) {
        self.index = index
        self.files = files
    }

    /// Search the workspace + return hits enriched with provenance.
    ///
    /// `kindFilter` narrows by language; `nil` searches all kinds.
    /// `limit` caps the backend hit count BEFORE provenance enrichment.
    public func search(
        query: String,
        kindFilter: CodeArtifactKind? = nil,
        limit: Int = 25
    ) throws -> [AgentGrepHit] {
        let backendHits: [AgentGrepBackendHit]
        do {
            backendHits = try index.search(query: query, kindFilter: kindFilter, limit: limit)
        } catch {
            throw ServiceError.backendFailure(underlying: error)
        }
        return backendHits.map { hit in
            let fileURL = files.vaultRoot.appendingPathComponent(hit.vaultRelativePath, isDirectory: false)
            let sidecar = (try? files.readCodeFile(at: fileURL))?.sidecar
            return AgentGrepHit(
                vaultRelativePath: hit.vaultRelativePath,
                kind: hit.kind,
                score: hit.score,
                snippet: hit.snippet,
                symbol: hit.symbol,
                source: hit.source,
                provenance: sidecar?.provenance,
                crossReferences: sidecar?.crossReferences ?? []
            )
        }
    }

    /// Push a document into the backend index. Called by the W9.5
    /// CodeFileService write path (or by a workspace bootstrap pass)
    /// so the index stays in sync with disk.
    public func indexDocument(at fileURL: URL) throws {
        let pair = try files.readCodeFile(at: fileURL)
        let kind = pair.sidecar?.kind ?? CodeArtifactKind.from(fileURL: fileURL)
        let path = pair.sidecar?.vaultRelativePath
            ?? fileURL.path.replacingOccurrences(of: files.vaultRoot.path + "/", with: "")
        let hash = pair.sidecar?.contentHash ?? ""
        let doc = AgentGrepDocument(
            vaultRelativePath: path,
            kind: kind,
            body: pair.body,
            contentHash: hash
        )
        do {
            try index.upsert(document: doc)
        } catch {
            throw ServiceError.backendFailure(underlying: error)
        }
    }

    /// Drop a document from the backend index (file deleted in vault).
    public func unindex(vaultRelativePath: String) throws {
        do {
            try index.remove(vaultRelativePath: vaultRelativePath)
        } catch {
            throw ServiceError.backendFailure(underlying: error)
        }
    }
}

// MARK: - Stub backend client

/// In-memory `CodeIndexClient` matching the Rust epistemos-code-index
/// stub backend's substring scoring + per-kind filter semantics.
/// Used by tests so the agent-grep surface is exercised without
/// loading the Rust dylib.
nonisolated public final class StubCodeIndexClient: CodeIndexClient, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.epistemos.codeindex.stub")
    private var docs: [String: AgentGrepDocument] = [:]

    public init() {}

    public func upsert(document: AgentGrepDocument) throws {
        if document.vaultRelativePath.isEmpty {
            throw NSError(
                domain: "StubCodeIndexClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "vault_relative_path was empty"]
            )
        }
        queue.sync { docs[document.vaultRelativePath] = document }
    }

    public func remove(vaultRelativePath: String) throws {
        let removed: Bool = queue.sync {
            docs.removeValue(forKey: vaultRelativePath) != nil
        }
        if !removed {
            throw NSError(
                domain: "StubCodeIndexClient",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "not found: \(vaultRelativePath)"]
            )
        }
    }

    public func search(
        query: String,
        kindFilter: CodeArtifactKind?,
        limit: Int
    ) throws -> [AgentGrepBackendHit] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return [] }
        let snapshot: [AgentGrepDocument] = queue.sync {
            docs.values.filter { kindFilter == nil || $0.kind == kindFilter }
        }
        var hits: [AgentGrepBackendHit] = snapshot.compactMap { doc in
            let bodyLower = doc.body.lowercased()
            let basenameLower = (doc.vaultRelativePath as NSString)
                .lastPathComponent.lowercased()
            let pathHit = basenameLower.contains(q)
            let bodyRange = bodyLower.range(of: q)
            if !pathHit && bodyRange == nil { return nil }
            var score: Float = 0
            if pathHit { score += 2.0 }
            if bodyRange != nil { score += 1.0 }
            score = min(score, 3.0)
            let snippet = String(doc.body.prefix(200))
            return AgentGrepBackendHit(
                vaultRelativePath: doc.vaultRelativePath,
                kind: doc.kind,
                score: score,
                snippet: snippet,
                symbol: nil,
                source: "stub-substring"
            )
        }
        hits.sort { $0.score > $1.score }
        if hits.count > limit { hits = Array(hits.prefix(limit)) }
        return hits
    }
}
