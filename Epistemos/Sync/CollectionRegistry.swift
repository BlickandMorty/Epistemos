import Foundation

// MARK: - Collection Registry
// Persists which folder names are marked as "Collections" across restarts.
//
// SDFolder.isCollection is ephemeral — clearVaultData() wipes all SDFolder rows on every
// restart, and synthesizeFoldersFromSubfolders recreates them with the default value (false).
// This registry remembers the user's choices in UserDefaults and restores them after each
// import so the Collections section survives app restarts.
//
// nonisolated: UserDefaults is thread-safe, so this can be accessed from any actor —
// including VaultIndexActor (@ModelActor) during synthesizeFoldersFromSubfolders.

nonisolated final class CollectionRegistry: Sendable {
    nonisolated static let shared = CollectionRegistry()

    private let key = "epistemos.collectionFolderNames"

    private init() {}

    /// The set of folder names currently marked as collections.
    nonisolated var collectionNames: Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(stored)
    }

    /// Mark or unmark a folder name as a collection.
    nonisolated func setCollection(_ name: String, _ isCollection: Bool) {
        var names = collectionNames
        if isCollection {
            names.insert(name)
        } else {
            names.remove(name)
        }
        UserDefaults.standard.set(Array(names), forKey: key)
    }

    /// Returns true if the given folder name is registered as a collection.
    nonisolated func isCollection(_ name: String) -> Bool {
        collectionNames.contains(name)
    }
}
