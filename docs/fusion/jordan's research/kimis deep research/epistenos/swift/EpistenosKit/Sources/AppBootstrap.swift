import Foundation
import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - AppBootstrap
// ---------------------------------------------------------------------------

/// Bootstrap sequence that runs once on app launch.
///
/// `AppBootstrap` creates the shared `AppEnvironment`, wires `CompanionState`
/// to the event store, ensures the App Group directory layout, and sets the
/// Landing Farm as the default view.
///
/// Call from `applicationDidFinishLaunching(_:)`:
/// ```swift
/// AppBootstrap.shared.run()
/// ```
@MainActor
public final class AppBootstrap: @unchecked Sendable {
    public static let shared = AppBootstrap()

    private init() {}

    /// Execute the bootstrap sequence.
    public func run() {
        let container = AppGroupContainer.shared

        // 1. Ensure App Group directory layout (idempotent).
        do {
            try container.ensureLayout()
        } catch {
            print("[AppBootstrap] ERROR: ensureLayout failed: \(error)")
        }

        let companionState = CompanionState()
        let env = AppEnvironment(
            vaultManager: .shared,
            companionState: companionState,
            eventStore: .shared,
            appGroupContainer: container
        )
        AppEnvironment.shared = env

        // 2. Load companions and wire event stream.
        Task { @MainActor in
            try? await companionState.loadCompanions()
            companionState.startListeningToEvents()
        }

        // 3. One-time legacy migration (async, fire-and-forget).
        Task { @MainActor in
            try? await container.migrateFromLegacyIfNeeded()
        }

        LandingFarmWindowManager.shared.setLandingFarmAsDefault()

        #if DEBUG
        print("[AppBootstrap] Environment bootstrapped. \(companionState.companions.count) companion(s) loaded.")
        #endif
    }
}
