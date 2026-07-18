import SwiftUI

// MARK: - Centralized Environment Injection
// Single extension method that applies all state/service environment objects.
// Adding a new state object only requires updating this one file.
//
// Views continue using @Environment(UIState.self), etc.
// No view changes needed — this just consolidates the injection point.

extension View {
    /// Apply all Epistemos state and service environment objects from AppBootstrap.
    func withAppEnvironment(_ bootstrap: AppBootstrap) -> some View {
        self
            .environment(bootstrap.uiState)
            .environment(bootstrap.notesUI)
            .environment(bootstrap.eventBus)
            #if !EPISTEMOS_FREE_V1
            .environment(bootstrap.runtimeState)
            #endif
            #if !EPISTEMOS_FREE_V1
            .environment(bootstrap.preparedModelRegistryState)
            #endif
            .environment(bootstrap.vaultSync)
            .environment(bootstrap.workspaceService)
            .environment(bootstrap.threadState)
            .environment(bootstrap.graphState)
            .environment(bootstrap.queryEngine)
            .environment(bootstrap.physicsCoordinator)
            .environment(bootstrap.epistemosConfig)
            .environment(bootstrap.textCapturePipeline)
            .environment(bootstrap.contextualShadowsState)
            .environment(bootstrap.ambientFrequencyPlaybackState)
    }
}
