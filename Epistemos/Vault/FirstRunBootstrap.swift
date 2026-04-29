import Foundation
import OSLog

/// Phase 0.5 — first-run bootstrap, Swift coordinator.
///
/// Mirrors `agent_core/src/bootstrap.rs` (canonical impl). Both implementations
/// satisfy the same spec from PLAN §11 Phase 0.5:
///   1. Vault location (default ~/Documents/Epistemos)
///   2. Background model download — descriptors live in
///      `FirstRunBootstrap.routerCandidates` / `embeddingCandidates`,
///      actual download is `ModelDownloadManager`'s job
///   3. Initial folder scaffold (_inbox, _inbox/review, daily, notes)
///   4. First-capture tooltip (UI concern, not this module)
///
/// Idempotent: re-running on an already-bootstrapped vault preserves the
/// original `createdAt` timestamp and reports `wasFresh = false`.
///
/// TODO: collapse to one impl by exposing `agent_core::bootstrap::bootstrap`
/// via UniFFI. Phase 1 timeline.
public enum FirstRunBootstrap {

    public static let metadataRelativePath = ".epistemos/vault.json"
    public static let schemaVersion: UInt32 = 1
    public static let scaffoldFolders: [String] = [
        "_inbox",
        "_inbox/review",
        "daily",
        "notes"
    ]

    public struct Metadata: Codable, Equatable, Sendable {
        public let schemaVersion: UInt32
        public let createdAt: Date
        public var embeddingModelPin: String?
        public var routerModelPin: String?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case createdAt = "created_at"
            case embeddingModelPin = "embedding_model_pin"
            case routerModelPin = "router_model_pin"
        }
    }

    public struct Receipt: Sendable {
        public let vaultURL: URL
        public let metadataURL: URL
        public let createdFolders: [URL]
        public let wasFresh: Bool
        public let metadata: Metadata
    }

    public enum BootstrapError: Error, Equatable {
        case noParentDirectory(URL)
        case metadataDecodeFailed(String)
    }

    /// Default vault location: `~/Documents/Epistemos` per PLAN §11 Phase 0.5.
    /// Falls back to `~/Epistemos` when Documents isn't resolvable.
    public static func defaultVaultURL(fileManager: FileManager = .default) -> URL {
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docs.appendingPathComponent("Epistemos", isDirectory: true)
        }
        if let home = fileManager.urls(for: .userDirectory, in: .localDomainMask).first {
            return home.appendingPathComponent("Epistemos", isDirectory: true)
        }
        return URL(fileURLWithPath: "Epistemos", isDirectory: true)
    }

    /// True when the vault has not been bootstrapped (no `.epistemos/vault.json`).
    public static func isFresh(at vaultURL: URL, fileManager: FileManager = .default) -> Bool {
        let metadataPath = vaultURL.appendingPathComponent(metadataRelativePath).path
        return !fileManager.fileExists(atPath: metadataPath)
    }

    /// Idempotent bootstrap. On a fresh vault: writes new metadata, reports
    /// every created folder. On an already-bootstrapped vault: re-reads
    /// existing metadata, reports no creations.
    public static func bootstrap(
        at vaultURL: URL,
        fileManager: FileManager = .default
    ) throws -> Receipt {
        let wasFresh = isFresh(at: vaultURL, fileManager: fileManager)

        try fileManager.createDirectory(
            at: vaultURL,
            withIntermediateDirectories: true
        )

        var created: [URL] = []
        for relative in scaffoldFolders {
            let abs = vaultURL.appendingPathComponent(relative, isDirectory: true)
            if !fileManager.fileExists(atPath: abs.path) {
                try fileManager.createDirectory(
                    at: abs,
                    withIntermediateDirectories: true
                )
                created.append(abs)
            }
        }

        let metadataDir = vaultURL.appendingPathComponent(".epistemos", isDirectory: true)
        try fileManager.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        let metadataURL = vaultURL.appendingPathComponent(metadataRelativePath)

        let metadata: Metadata
        if wasFresh {
            // Truncate to second precision so JSON round-trip via ISO8601 is
            // lossless. `Date()` carries sub-second precision that the ISO8601
            // encoder strips on write; comparing the original (with nanos) to
            // the read-back value (without nanos) would fail equality.
            let nowSeconds = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
            let m = Metadata(
                schemaVersion: schemaVersion,
                createdAt: nowSeconds,
                embeddingModelPin: nil,
                routerModelPin: nil
            )
            try writeAtomicJSON(m, to: metadataURL, fileManager: fileManager)
            metadata = m
            Self.log.info("Bootstrapped fresh vault at \(vaultURL.path, privacy: .public)")
        } else {
            metadata = try readMetadata(at: metadataURL)
        }

        return Receipt(
            vaultURL: vaultURL,
            metadataURL: metadataURL,
            createdFolders: created,
            wasFresh: wasFresh,
            metadata: metadata
        )
    }

    public static func readMetadata(at url: URL) throws -> Metadata {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Metadata.self, from: data)
        } catch {
            throw BootstrapError.metadataDecodeFailed(String(describing: error))
        }
    }

    private static func writeAtomicJSON<T: Encodable>(
        _ value: T,
        to url: URL,
        fileManager: FileManager
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(value)

        guard let parent = url.deletingLastPathComponent() as URL?,
              parent.path != "/" else {
            throw BootstrapError.noParentDirectory(url)
        }
        let tmpName = ".tmp.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString)"
        let tmpURL = parent.appendingPathComponent(tmpName)
        try bytes.write(to: tmpURL, options: .atomic)
        // Atomic rename: tmp → final. If final already existed (idempotent
        // re-run path doesn't reach here, but be defensive) replaceItem swaps it.
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: tmpURL)
        } else {
            try fileManager.moveItem(at: tmpURL, to: url)
        }
    }

    fileprivate static let log = Logger(subsystem: "com.epistemos", category: "FirstRunBootstrap")
}

// MARK: - Router & embedding candidates (mirrors Rust ROUTER_CANDIDATES / EMBEDDING_CANDIDATES)

extension FirstRunBootstrap {

    public struct RouterCandidate: Sendable, Equatable {
        public let huggingFaceID: String
        public let displayName: String
        public let residentMB4Bit: UInt32
        public let isPlanDefault: Bool
    }

    /// Plan §6.6.1 anchors the default at Qwen 2.5-1.5B. Qwen 3.5-0.8B / 2B
    /// are registered alongside because 2026-04 community benchmarks show
    /// 3.5-0.8B reaching ~100% classification accuracy with 3 in-prompt
    /// exemplars (which the plan mandates anyway), and 3.5-2B reaching
    /// ~100% zero-shot. Phase 6.5 per-model bench picks the empirical winner.
    public static let routerCandidates: [RouterCandidate] = [
        RouterCandidate(
            huggingFaceID: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            displayName: "Qwen 2.5 1.5B Instruct (4-bit)",
            residentMB4Bit: 1024,
            isPlanDefault: true
        ),
        RouterCandidate(
            huggingFaceID: "mlx-community/Qwen3.5-0.8B-4bit",
            displayName: "Qwen 3.5 0.8B (4-bit)",
            residentMB4Bit: 512,
            isPlanDefault: false
        ),
        RouterCandidate(
            huggingFaceID: "mlx-community/Qwen3.5-2B-4bit",
            displayName: "Qwen 3.5 2B (4-bit)",
            residentMB4Bit: 1280,
            isPlanDefault: false
        )
    ]

    public static var defaultRouter: RouterCandidate {
        // swiftlint:disable:next force_unwrapping
        // Pre-validated by Swift tests + Rust tests + this property is
        // covered by `routerCandidatesHaveExactlyOnePlanDefault`. Force
        // unwrap is safe here because the static array is a compile-time
        // constant; if a future edit breaks the invariant the test fails first.
        return routerCandidates.first(where: { $0.isPlanDefault })!
    }

    public struct EmbeddingCandidate: Sendable, Equatable {
        public let huggingFaceID: String
        public let displayName: String
        public let dims: UInt32
        public let residentMB: UInt32
        public let isPlanDefault: Bool
    }

    public static let embeddingCandidates: [EmbeddingCandidate] = [
        EmbeddingCandidate(
            huggingFaceID: "mlx-community/bge-small-en-v1.5-mlx",
            displayName: "BGE Small EN v1.5",
            dims: 384,
            residentMB: 50,
            isPlanDefault: true
        ),
        EmbeddingCandidate(
            huggingFaceID: "mlx-community/nomic-embed-text-v1.5-mlx",
            displayName: "Nomic Embed Text v1.5 (8k context)",
            dims: 768,
            residentMB: 140,
            isPlanDefault: false
        ),
        EmbeddingCandidate(
            huggingFaceID: "mlx-community/bge-large-en-v1.5-mlx",
            displayName: "BGE Large EN v1.5",
            dims: 1024,
            residentMB: 250,
            isPlanDefault: false
        )
    ]

    public static var defaultEmbedding: EmbeddingCandidate {
        // swiftlint:disable:next force_unwrapping
        return embeddingCandidates.first(where: { $0.isPlanDefault })!
    }
}
