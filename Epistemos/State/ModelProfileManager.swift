import Foundation
import os
import SwiftData

// MARK: - Model Profile Manager (v2)

/// Central manager for model profiles: CRUD operations, vault association,
/// adapter tracking, and profile-aware graph filtering.
///
/// Each model profile encapsulates:
/// - A model (local or cloud)
/// - A vault scope (the knowledge the model operates on)
/// - Trained adapters (local models only)
/// - Per-profile graph and inference settings
@MainActor @Observable
final class ModelProfileManager {
    private let log = Logger(subsystem: "com.epistemos", category: "ModelProfileManager")

    // MARK: - State

    /// All loaded model profiles.
    private(set) var profiles: [SDModelProfile] = []

    /// The currently active model profile.
    private(set) var activeProfile: SDModelProfile?

    /// SwiftData container for persistence.
    private var modelContainer: ModelContainer?

    // MARK: - Init

    func configure(container: ModelContainer) {
        self.modelContainer = container
        Task { await loadProfiles() }
    }

    // MARK: - CRUD

    /// Load all profiles from SwiftData.
    func loadProfiles() async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDModelProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            profiles = try context.fetch(descriptor)
            log.info("Loaded \(self.profiles.count) model profiles")
        } catch {
            log.error("Failed to load model profiles: \(error.localizedDescription)")
        }
    }

    /// Create a new local model profile.
    func createLocalProfile(
        displayName: String,
        modelIdentifier: String,
        vaultIdentityKey: String,
        vaultDisplayName: String
    ) -> SDModelProfile? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)

        let profile = SDModelProfile()
        profile.displayName = displayName
        profile.modelIdentifier = modelIdentifier
        profile.profileType = "local"
        profile.vaultIdentityKey = vaultIdentityKey
        profile.vaultDisplayName = vaultDisplayName
        profile.isCloudModel = false

        context.insert(profile)
        do {
            try context.save()
            profiles.append(profile)
            log.info("Created local model profile: \(displayName)")
            return profile
        } catch {
            log.error("Failed to create profile: \(error.localizedDescription)")
            return nil
        }
    }

    /// Create a new cloud model profile.
    func createCloudProfile(
        displayName: String,
        cloudProvider: String,
        vaultIdentityKey: String,
        vaultDisplayName: String
    ) -> SDModelProfile? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)

        let profile = SDModelProfile()
        profile.displayName = displayName
        profile.modelIdentifier = cloudProvider
        profile.profileType = "cloud"
        profile.cloudProvider = cloudProvider
        profile.vaultIdentityKey = vaultIdentityKey
        profile.vaultDisplayName = vaultDisplayName
        profile.isCloudModel = true

        context.insert(profile)
        do {
            try context.save()
            profiles.append(profile)
            log.info("Created cloud model profile: \(displayName)")
            return profile
        } catch {
            log.error("Failed to create cloud profile: \(error.localizedDescription)")
            return nil
        }
    }

    /// Delete a model profile.
    func deleteProfile(_ profile: SDModelProfile) {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        context.delete(profile)
        do {
            try context.save()
            profiles.removeAll { $0.id == profile.id }
            if activeProfile?.id == profile.id {
                activeProfile = nil
            }
            log.info("Deleted model profile: \(profile.displayName)")
        } catch {
            log.error("Failed to delete profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Activation

    /// Set the active model profile. This scopes the graph view,
    /// inference context, and adapter selection to this profile.
    func activate(_ profile: SDModelProfile) {
        activeProfile = profile
        profile.updatedAt = Date.now
        save(profile)
        log.info("Activated model profile: \(profile.displayName)")
    }

    /// Deactivate the current profile (return to global/unscoped mode).
    func deactivate() {
        activeProfile = nil
        log.info("Deactivated model profile (global mode)")
    }

    // MARK: - Adapter Management

    /// Associate an adapter with a model profile.
    func addAdapter(_ adapterId: UUID, to profile: SDModelProfile) {
        let idString = adapterId.uuidString
        guard !profile.adapterIds.contains(idString) else { return }
        profile.adapterIds.append(idString)
        profile.updatedAt = Date.now
        save(profile)
    }

    /// Remove an adapter association from a model profile.
    func removeAdapter(_ adapterId: UUID, from profile: SDModelProfile) {
        let idString = adapterId.uuidString
        profile.adapterIds.removeAll { $0 == idString }
        if profile.activeAdapterId == idString {
            profile.activeAdapterId = nil
        }
        profile.updatedAt = Date.now
        save(profile)
    }

    /// Set the active adapter for a model profile.
    func setActiveAdapter(_ adapterId: UUID?, for profile: SDModelProfile) {
        profile.activeAdapterId = adapterId?.uuidString
        profile.updatedAt = Date.now
        save(profile)
    }

    // MARK: - Graph Settings

    /// Save the current graph filter state to a profile.
    func saveGraphSettings(
        nodeTypeFilter: String,
        edgeTypeFilter: String,
        pinnedNodeIds: [String],
        for profile: SDModelProfile
    ) {
        profile.graphNodeTypeFilter = nodeTypeFilter
        profile.graphEdgeTypeFilter = edgeTypeFilter
        profile.pinnedNodeIds = pinnedNodeIds
        profile.updatedAt = Date.now
        save(profile)
    }

    // MARK: - Statistics

    /// Record a conversation with this profile.
    func recordConversation(for profile: SDModelProfile, tokens: Int) {
        profile.conversationCount += 1
        profile.totalTokensProcessed += tokens
        profile.updatedAt = Date.now
        save(profile)
    }

    // MARK: - Queries

    /// Find profiles for a specific model.
    func profiles(forModel modelId: String) -> [SDModelProfile] {
        profiles.filter { $0.modelIdentifier == modelId }
    }

    /// Find profiles attached to a specific vault.
    func profiles(forVault vaultKey: String) -> [SDModelProfile] {
        profiles.filter { $0.vaultIdentityKey == vaultKey }
    }

    /// Find the profile for a cloud provider.
    func cloudProfile(provider: String) -> SDModelProfile? {
        profiles.first { $0.cloudProvider == provider }
    }

    // MARK: - Persistence

    private func save(_ profile: SDModelProfile) {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        context.insert(profile)
        try? context.save()
    }
}
