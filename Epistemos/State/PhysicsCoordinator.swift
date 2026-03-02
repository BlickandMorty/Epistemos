import SwiftUI

// MARK: - Physics Coordinator
// Cross-view signal bus for physics-enhanced UI.
// NOT a physics engine — no timers, no loops, no per-frame cost.
// Views observe specific properties via @Observable; only changed properties
// trigger re-evaluation (e.g., hovering a graph node only re-renders the
// matching sidebar row, not every row).
//
// Injected at app root via AppEnvironment.withAppEnvironment().
// Views access via @Environment(PhysicsCoordinator.self).

@MainActor @Observable
final class PhysicsCoordinator {

    // MARK: - Graph → Sidebar Bridge

    /// Node ID currently hovered in the Metal graph.
    /// Sidebar rows with `.graphReactive(nodeId:)` react to this.
    var graphHoveredNodeId: String?

    // MARK: - Editor → Graph Bridge

    /// Page ID receiving focused activity (typing, scrolling).
    /// The graph can pulse the corresponding node.
    var activeEditPageId: String?

    // MARK: - Transient Pulse

    /// Activity pulse: 0.0 = idle, 1.0 = peak. Decays via spring.
    /// Set to 1.0 on events like "note saved", "graph node clicked".
    var activityPulse: Double = 0

    /// True when the user is mid-interaction (dragging, scrolling, typing).
    /// Ambient effects (breathing) reduce intensity during active interaction.
    var isUserInteracting: Bool = false

    // MARK: - API

    func pulse() {
        activityPulse = 1.0
        withAnimation(Motion.settle) { activityPulse = 0.0 }
    }
}
