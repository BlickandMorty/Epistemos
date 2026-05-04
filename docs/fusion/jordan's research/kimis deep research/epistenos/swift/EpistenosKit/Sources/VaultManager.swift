import Foundation
import SwiftUI
import Combine
import LocalAuthentication

// MARK: - Vault Model

/// A single vault container with identity, path, and bookmark data.
public struct Vault: Identifiable, Codable, Equatable {
    public let id: UUID
    public var path: URL
    public var bookmarkData: Data?
    public var createdAt: Date
    public var name: String

    public init(id: UUID = UUID(), path: URL, name: String, bookmarkData: Data? = nil) {
        self.id = id
        self.path = path
        self.name = name
        self.bookmarkData = bookmarkData
        self.createdAt = Date()
    }
}

// MARK: - VaultManager

/// Manages multiple vaults, security-scoped bookmarks, and biometric-gated writes.
///
/// `VaultManager` is the single source of truth for file-system vaults in
/// Epistenos. It persists vault metadata to `UserDefaults` (encrypted at rest
/// via the Data Protection API) and resolves security-scoped bookmarks when
/// the app re-launches.
@MainActor
public final class VaultManager: ObservableObject {
    /// All registered vaults.
    @Published public var vaults: [Vault] = []

    /// The currently active vault. UI observes this to switch contexts.
    @Published public var activeVault: Vault?

    /// App Group container identifier — parameterised for MAS / enterprise builds.
    public let appGroupID: String

    private var cancellables = Set<AnyCancellable>()
    private let biometricGate = BiometricWriteGate()

    private static let vaultsKey = "epistenos.vaults"

    /// Shared singleton for the app group `group.com.epistenos.shared`.
    public static let shared = VaultManager(appGroupID: "group.com.epistenos.shared")

    public init(appGroupID: String) {
        self.appGroupID = appGroupID
        loadVaults()
    }

    // MARK: - Vault Lifecycle

    /// Create a new vault at the given directory URL.
    ///
    /// - Returns: The newly created `Vault`.
    /// - Throws: `VaultError` if the directory cannot be created or bookmarked.
    public func createVault(path: URL) async throws -> Vault {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path.path, isDirectory: &isDir)

        if !exists {
            try fm.createDirectory(at: path, withIntermediateDirectories: true)
        }

        // Create a security-scoped bookmark for sandbox survival.
        let bookmark = try path.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let vault = Vault(
            path: path,
            name: path.lastPathComponent,
            bookmarkData: bookmark
        )

        await MainActor.run {
            vaults.append(vault)
            if activeVault == nil {
                activeVault = vault
            }
            persistVaults()
        }

        return vault
    }

    /// Switch the active vault by ID.
    public func switchVault(id: UUID) {
        guard let target = vaults.first(where: { $0.id == id }) else { return }
        activeVault = target
    }

    // MARK: - Security-Scoped Bookmarks

    /// Start security-scoped resource access for a bookmark-resolved URL.
    ///
    /// The caller **must** call `url.stopAccessingSecurityScopedResource()`
    /// after file-system access completes. This method is a no-op wrapper
    /// that documents the contract.
    public func resolveBookmark(url: URL) async throws -> URL {
        let started = url.startAccessingSecurityScopedResource()
        if !started {
            print("[VaultManager] warning: startAccessingSecurityScopedResource returned false for \(url.path)")
        }
        return url
    }

    /// Resolve the bookmark data stored inside a vault.
    public func resolveVaultBookmark(_ vault: Vault) throws -> URL {
        guard let data = vault.bookmarkData else {
            throw VaultError.noBookmark
        }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            // Re-create bookmark and update vault
            let fresh = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            if let idx = vaults.firstIndex(where: { $0.id == vault.id }) {
                vaults[idx].bookmarkData = fresh
                persistVaults()
            }
        }
        return url
    }

    // MARK: - Biometric-Gated Writes

    /// Perform a write operation gated behind biometric authentication.
    ///
    /// - Parameters:
    ///   - reason: Localised reason shown in the Touch ID / Face ID dialog.
    ///   - operation: The actual file-system write closure.
    /// - Throws: `BiometricError` if authentication fails, or any error from the closure.
    public func gatedWrite(
        reason: String = "Authenticate to write to vault",
        operation: @escaping () async throws -> Void
    ) async throws {
        try await biometricGate.gate(reason: reason, operation: operation)
    }

    // MARK: - Persistence

    private func persistVaults() {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(vaults) {
            UserDefaults.standard.set(data, forKey: Self.vaultsKey)
        }
    }

    private func loadVaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.vaultsKey) else { return }
        let decoder = PropertyListDecoder()
        if let loaded = try? decoder.decode([Vault].self, from: data) {
            vaults = loaded
            activeVault = vaults.first
        }
    }

    // MARK: - App Group Container

    /// Returns the shared container URL for the App Group.
    public func sharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
}

// MARK: - VaultError

public enum VaultError: Error, LocalizedError {
    case noBookmark
    case directoryCreationFailed(Error)
    case bookmarkResolutionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .noBookmark:
            return "Vault has no security-scoped bookmark."
        case .directoryCreationFailed(let e):
            return "Could not create vault directory: \(e.localizedDescription)"
        case .bookmarkResolutionFailed(let e):
            return "Could not resolve bookmark: \(e.localizedDescription)"
        }
    }
}
