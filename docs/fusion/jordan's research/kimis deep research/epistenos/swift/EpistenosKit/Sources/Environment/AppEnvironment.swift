import Foundation
import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - AppEnvironment
// ---------------------------------------------------------------------------

/// A single source of truth for dependency injection across the Epistenos app.
///
/// `AppEnvironment` is created once at bootstrap and passed down through
/// SwiftUI's `.environment(_:)` modifier. All `@Observable` state objects
/// live here so that any view can access them without proliferation of
/// `@State` or `@StateObject` boilerplate.
///
/// Usage:
/// ```swift
/// @Environment(AppEnvironment.self) var appEnvironment
/// ```
@MainActor
public final class AppEnvironment: @unchecked Sendable {
    /// The shared bootstrap instance. Set exactly once in `AppBootstrap`.
    public static var shared: AppEnvironment?

    /// Vault management (security-scoped bookmarks, active vault).
    public let vaultManager: VaultManager

    /// Companion simulation state (landing farm, reactions, archive).
    public let companionState: CompanionState

    /// Live agent event store for reactive companion behaviour.
    public let eventStore: EventStore

    /// App Group container for shared file-system state.
    public let appGroupContainer: AppGroupContainer

    /// Global reduce-motion preference (overrides system setting for testing).
    public var forceReduceMotion: Bool = false

    public init(
        vaultManager: VaultManager = .shared,
        companionState: CompanionState = CompanionState(),
        eventStore: EventStore = .shared,
        appGroupContainer: AppGroupContainer = .shared
    ) {
        self.vaultManager = vaultManager
        self.companionState = companionState
        self.eventStore = eventStore
        self.appGroupContainer = appGroupContainer
    }
}

// ---------------------------------------------------------------------------
// MARK: - Environment Key
// ---------------------------------------------------------------------------

public struct AppEnvironmentKey: EnvironmentKey {
    @MainActor
    public static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    /// Access the bootstrapped `AppEnvironment` from any view.
    public var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// ---------------------------------------------------------------------------
// MARK: - withAppEnvironment
// ---------------------------------------------------------------------------

/// Inject the shared `AppEnvironment` into a view hierarchy.
///
/// Call this on the root view inside the app's `WindowGroup`:
/// ```swift
/// LandingFarmView()
///     .withAppEnvironment(AppEnvironment.shared)
/// ```
extension View {
    public func withAppEnvironment(_ env: AppEnvironment?) -> some View {
        environment(\.appEnvironment, env)
    }
}
