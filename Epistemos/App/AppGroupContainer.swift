import Foundation

@MainActor
final class AppGroupContainer {
    static let shared = AppGroupContainer()

    nonisolated static let canonicalGroupIdentifier = "group.com.epistemos.shared"
    nonisolated static let legacyDirectoryName = "Epistemos"
    nonisolated static let arenaFileName = "arena.dat"
    nonisolated static let blobDirectoryName = "blobs"
    nonisolated static let tmpDirectoryName = "tmp"
    nonisolated static let logDirectoryName = "logs"

    let groupIdentifier: String

    private let fileManager: FileManager
    private let legacyBaseURL: URL
    private let containerURLProvider: (String) -> URL?

    init(
        groupIdentifier: String = AppGroupContainer.canonicalGroupIdentifier,
        fileManager: FileManager = .default,
        legacyBaseURL: URL? = nil,
        containerURLProvider: @escaping (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) {
        self.groupIdentifier = groupIdentifier
        self.fileManager = fileManager
        self.legacyBaseURL = legacyBaseURL ?? Self.defaultLegacyBaseURL(fileManager: fileManager)
        self.containerURLProvider = containerURLProvider
    }

    private static func defaultLegacyBaseURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory

        return appSupportURL.appendingPathComponent(Self.legacyDirectoryName, isDirectory: true)
    }

    var containerURL: URL? {
        containerURLProvider(groupIdentifier)
    }

    var rootURL: URL {
        containerURL ?? legacyBaseURL
    }

    var arenaURL: URL {
        rootURL.appendingPathComponent(Self.arenaFileName, isDirectory: false)
    }

    var blobsURL: URL {
        rootURL.appendingPathComponent(Self.blobDirectoryName, isDirectory: true)
    }

    var provenanceDBURL: URL {
        rootURL.appendingPathComponent("provenance.sqlite", isDirectory: false)
    }

    var vaultIndexURL: URL {
        rootURL.appendingPathComponent("vault_index.sqlite", isDirectory: false)
    }

    var resonanceDBURL: URL {
        rootURL.appendingPathComponent("resonance.sqlite", isDirectory: false)
    }

    var sharedTempURL: URL {
        rootURL.appendingPathComponent(Self.tmpDirectoryName, isDirectory: true)
    }

    var sharedLogsURL: URL {
        rootURL.appendingPathComponent(Self.logDirectoryName, isDirectory: true)
    }

    func ensureLayout() throws {
        let directories = [
            rootURL,
            blobsURL,
            sharedTempURL,
            sharedLogsURL,
        ]

        do {
            for directory in directories {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            }
        } catch {
            throw AppGroupContainerError(directoryCreationFailed: rootURL, underlying: error)
        }
    }

    func securityScopedBookmarkData(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw AppGroupContainerError(bookmarkCreationFailed: url, underlying: error)
        }
    }

    func resolveSecurityScopedBookmark(_ data: Data) throws -> URL {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard !isStale else {
                throw AppGroupContainerError.staleBookmark
            }
            return url
        } catch let error as AppGroupContainerError {
            throw error
        } catch {
            throw AppGroupContainerError(bookmarkResolutionFailed: error)
        }
    }

    func migrateLegacyDatabasesIfNeeded() throws {
        guard containerURL != nil else { return }
        try ensureLayout()

        let migrations = [
            ("provenance.db", provenanceDBURL),
            ("provenance.sqlite", provenanceDBURL),
            ("vault_index.db", vaultIndexURL),
            ("vault_index.sqlite", vaultIndexURL),
            ("resonance.db", resonanceDBURL),
            ("resonance.sqlite", resonanceDBURL),
        ]

        for (legacyName, destination) in migrations {
            let source = legacyBaseURL.appendingPathComponent(legacyName, isDirectory: false)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            guard !fileManager.fileExists(atPath: destination.path) else { continue }

            do {
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                throw AppGroupContainerError(migrationFailed: source, destination: destination, underlying: error)
            }
        }
    }
}

enum AppGroupContainerError: Error, LocalizedError, Equatable {
    case directoryCreationFailed(directory: URL, underlyingDescription: String)
    case bookmarkCreationFailed(url: URL, underlyingDescription: String)
    case bookmarkResolutionFailed(underlyingDescription: String)
    case staleBookmark
    case migrationFailed(source: URL, destination: URL, underlyingDescription: String)

    init(directoryCreationFailed directory: URL, underlying: Error) {
        self = .directoryCreationFailed(directory: directory, underlyingDescription: underlying.localizedDescription)
    }

    init(bookmarkCreationFailed url: URL, underlying: Error) {
        self = .bookmarkCreationFailed(url: url, underlyingDescription: underlying.localizedDescription)
    }

    init(bookmarkResolutionFailed underlying: Error) {
        self = .bookmarkResolutionFailed(underlyingDescription: underlying.localizedDescription)
    }

    init(migrationFailed source: URL, destination: URL, underlying: Error) {
        self = .migrationFailed(
            source: source,
            destination: destination,
            underlyingDescription: underlying.localizedDescription
        )
    }

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let directory, let underlyingDescription):
            return "Could not create App Group layout at \(directory.path): \(underlyingDescription)"
        case .bookmarkCreationFailed(let url, let underlyingDescription):
            return "Could not create security-scoped bookmark for \(url.path): \(underlyingDescription)"
        case .bookmarkResolutionFailed(let underlyingDescription):
            return "Could not resolve security-scoped bookmark: \(underlyingDescription)"
        case .staleBookmark:
            return "Security-scoped bookmark is stale and must be refreshed."
        case .migrationFailed(let source, let destination, let underlyingDescription):
            return "Could not migrate \(source.path) to \(destination.path): \(underlyingDescription)"
        }
    }
}
