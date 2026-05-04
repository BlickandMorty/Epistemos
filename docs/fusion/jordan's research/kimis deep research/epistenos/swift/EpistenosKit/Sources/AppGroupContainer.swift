import Foundation

// MARK: - AppGroupContainer

/// The canonical App Group container singleton for Epistenos.
///
/// All shared substrate state — mmap arena, blob store, SQLite databases,
/// and resonance indices — lives inside the App Group container so that the
/// main app, XPC services, and the simulation companion can access the same
/// files without escaping the macOS App Sandbox.
///
/// If the App Group is not available (e.g. an old install that predates the
/// entitlements change), every path falls back to a legacy directory under
/// `~/Library/Application Support/Epistenos/`.  A one-time migration copies
/// existing data into the App Group on first launch.
@MainActor
public final class AppGroupContainer {
    public static let shared = AppGroupContainer()

    /// The App Group identifier registered in `EpistenosMAS.entitlements`.
    public let groupIdentifier = "group.com.epistenos.shared"

    /// The legacy fallback directory (pre-MAS install path).
    private var legacyContainerURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Epistenos", isDirectory: true)
    }

    private init() {}

    // MARK: - URL Properties

    /// The shared container URL if the App Group entitlement is active,
    /// otherwise `nil`.
    public var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        )
    }

    /// URL of the mmap arena backing file.
    public var arenaURL: URL {
        containerURL?.appendingPathComponent("arena/epistenos.arena")
            ?? legacyContainerURL.appendingPathComponent("arena/epistenos.arena")
    }

    /// URL of the blob store directory.
    public var blobsURL: URL {
        containerURL?.appendingPathComponent("blobs", isDirectory: true)
            ?? legacyContainerURL.appendingPathComponent("blobs", isDirectory: true)
    }

    /// URL of the provenance SQLite database.
    public var provenanceDBURL: URL {
        containerURL?.appendingPathComponent("provenance/provenance.db")
            ?? legacyContainerURL.appendingPathComponent("provenance/provenance.db")
    }

    /// URL of the vault index SQLite database.
    public var vaultIndexURL: URL {
        containerURL?.appendingPathComponent("vaults/vault_index.db")
            ?? legacyContainerURL.appendingPathComponent("vaults/vault_index.db")
    }

    /// URL of the resonance SQLite database.
    public var resonanceDBURL: URL {
        containerURL?.appendingPathComponent("resonance/resonance.db")
            ?? legacyContainerURL.appendingPathComponent("resonance/resonance.db")
    }

    /// URL for temporary files shared across the App Group.
    public var sharedTempURL: URL {
        containerURL?.appendingPathComponent("tmp", isDirectory: true)
            ?? legacyContainerURL.appendingPathComponent("tmp", isDirectory: true)
    }

    /// URL for shared log files.
    public var sharedLogsURL: URL {
        containerURL?.appendingPathComponent("logs", isDirectory: true)
            ?? legacyContainerURL.appendingPathComponent("logs", isDirectory: true)
    }

    // MARK: - Layout

    /// Ensure that every required subdirectory exists.
    ///
    /// This is idempotent: running twice is a no-op.  Called from `AppBootstrap`
    /// at application launch.
    ///
    /// - Throws: `AppGroupError` if directory creation fails.
    public func ensureLayout() throws {
        let fm = FileManager.default
        let dirs = [
            arenaURL.deletingLastPathComponent(),
            blobsURL,
            provenanceDBURL.deletingLastPathComponent(),
            vaultIndexURL.deletingLastPathComponent(),
            resonanceDBURL.deletingLastPathComponent(),
            sharedTempURL,
            sharedLogsURL,
        ]

        for dir in dirs {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true,
                    attributes: [
                        FileAttributeKey.posixPermissions: 0o700
                    ]
                )
            }
        }
    }

    // MARK: - Migration

    /// One-time migration from the legacy Application Support directory to the
    /// App Group container.
    ///
    /// This is called from `AppBootstrap` on first launch after the App Group
    /// entitlement is added.  It is safe to call multiple times: if the App
    /// Group already contains data, the migration is skipped.
    ///
    /// - Throws: `AppGroupError` if migration fails.
    public func migrateFromLegacyIfNeeded() async throws {
        guard let container = containerURL else {
            print("[AppGroupContainer] App Group not available — skipping migration.")
            return
        }

        let fm = FileManager.default
        let legacy = legacyContainerURL

        // If the legacy directory does not exist, nothing to migrate.
        guard fm.fileExists(atPath: legacy.path) else { return }

        // If the App Group already has a marker file, migration already ran.
        let marker = container.appendingPathComponent(".migrated")
        if fm.fileExists(atPath: marker.path) {
            return
        }

        print("[AppGroupContainer] Migrating legacy data to App Group …")

        // Create layout first.
        try ensureLayout()

        // List of items to migrate: (legacy relative path, App Group relative path)
        let items: [(URL, URL)] = [
            (legacy.appendingPathComponent("provenance.db"), provenanceDBURL),
            (legacy.appendingPathComponent("vault_index.db"), vaultIndexURL),
            (legacy.appendingPathComponent("resonance.db"), resonanceDBURL),
        ]

        for (src, dst) in items {
            if fm.fileExists(atPath: src.path) {
                // If destination exists, do not overwrite.
                if !fm.fileExists(atPath: dst.path) {
                    try fm.copyItem(at: src, to: dst)
                }
            }
        }

        // Copy blob store contents if present.
        let legacyBlobs = legacy.appendingPathComponent("blobs")
        let blobs = blobsURL
        if fm.fileExists(atPath: legacyBlobs.path) {
            let enumerator = fm.enumerator(at: legacyBlobs, includingPropertiesForKeys: nil)
            while let item = enumerator?.nextObject() as? URL {
                let relative = item.path.replacingOccurrences(
                    of: legacyBlobs.path + "/",
                    with: ""
                )
                let dst = blobs.appendingPathComponent(relative)
                if !fm.fileExists(atPath: dst.path) {
                    try? fm.createDirectory(
                        at: dst.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? fm.copyItem(at: item, to: dst)
                }
            }
        }

        // Write migration marker.
        try Data().write(to: marker)
        print("[AppGroupContainer] Migration complete.")
    }
}

// MARK: - AppGroupError

public enum AppGroupError: Error, LocalizedError {
    case directoryCreationFailed(Error)
    case migrationFailed(Error)
    case arenaNotAccessible

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let e):
            return "Could not create App Group directory: \(e.localizedDescription)"
        case .migrationFailed(let e):
            return "Migration failed: \(e.localizedDescription)"
        case .arenaNotAccessible:
            return "Arena file is not accessible in the App Group container."
        }
    }
}
