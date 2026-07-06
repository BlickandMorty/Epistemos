//
//  VaultBookmarkStore.swift
//  Epistemos — KEELSTONE spine
//
//  Owns the security-scoped bookmark lifecycle for a vault mount. This is the
//  MAS authority edge: on the App Store lane, this is the ONLY sanctioned way
//  to hold persistent access to a user-chosen folder across launches.
//
//  Entitlements required (App Store target, Entitlements/AppStore.entitlements):
//    com.apple.security.app-sandbox                       = true
//    com.apple.security.files.user-selected.read-write    = true
//    com.apple.security.files.bookmarks.app-scope         = true
//
//  Hard rules encoded here:
//   1. Resolve with .withSecurityScope; if bookmarkDataIsStale, re-create the
//      bookmark WHILE access is still valid, and persist the fresh data.
//   2. Every startAccessingSecurityScopedResource() is balanced by exactly one
//      stopAccessingSecurityScopedResource(). Leaks here are the "disconnect
//      doesn't disconnect" bug class.
//   3. Bookmark BYTES live in the Keychain, not UserDefaults — treat the mount
//      grant as a secret.
//

import Foundation

public enum VaultBookmarkError: Error, Sendable {
    case accessDenied            // startAccessing... returned false
    case resolutionFailed(Error) // URL(resolvingBookmarkData:) threw
    case creationFailed(Error)   // URL.bookmarkData(...) threw
    case noStoredBookmark        // nothing persisted yet — needs onboarding
}

/// A live, access-holding handle to a vault root. Ending it is a real teardown,
/// not a flag flip. Held for the lifetime of a mount; released on disconnect,
/// permission loss, or volume unmount.
public final class VaultAccessHandle: @unchecked Sendable {
    public let url: URL
    private var isAccessing: Bool
    private let didEndAccess: (URL) -> Void

    init(url: URL, isAccessing: Bool, didEndAccess: @escaping (URL) -> Void) {
        self.url = url
        self.isAccessing = isAccessing
        self.didEndAccess = didEndAccess
    }

    /// Balanced release. Idempotent — safe to call from disconnect and from
    /// deinit without double-stopping.
    public func end() {
        guard isAccessing else { return }
        isAccessing = false
        url.stopAccessingSecurityScopedResource()
        didEndAccess(url)
    }

    deinit { end() }
}

public protocol BookmarkSecretStore: Sendable {
    func loadBookmark(id: String) throws -> Data?
    func saveBookmark(_ data: Data, id: String) throws
    func deleteBookmark(id: String) throws
}

public final class VaultBookmarkStore: Sendable {
    private let secrets: BookmarkSecretStore

    public init(secrets: BookmarkSecretStore) {
        self.secrets = secrets
    }

    /// Called once, at the moment the user picks a folder in NSOpenPanel.
    /// Creates and persists the app-scoped bookmark. On MAS, do this while the
    /// panel-granted access is live.
    public func adoptUserSelectedVault(_ url: URL, id: String) throws {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            try secrets.saveBookmark(data, id: id)
        } catch {
            throw VaultBookmarkError.creationFailed(error)
        }
    }

    /// Resolve the stored bookmark and begin security-scoped access. Refreshes
    /// the bookmark in place if the OS reports it stale. Returns a handle whose
    /// `end()` is the balanced stop.
    public func resolveAndBeginAccess(id: String) throws -> VaultAccessHandle {
        guard let stored = try secrets.loadBookmark(id: id) else {
            throw VaultBookmarkError.noStoredBookmark
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: stored,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw VaultBookmarkError.resolutionFailed(error)
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw VaultBookmarkError.accessDenied
        }

        // Refresh WHILE access is live — this is the only safe window.
        if isStale {
            do {
                let fresh = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try secrets.saveBookmark(fresh, id: id)
            } catch {
                // Non-fatal: we still have live access this session. Log and
                // continue; next launch will re-attempt. Do NOT stop access.
            }
        }

        return VaultAccessHandle(url: url, isAccessing: true) { _ in
            // Hook for the lifecycle machine to observe teardown if needed.
        }
    }

    /// Full teardown of the persisted grant (user explicitly disconnects the
    /// vault). The caller must have already ended any live VaultAccessHandle.
    public func forgetVault(id: String) throws {
        try secrets.deleteBookmark(id: id)
    }
}
