import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// MARK: - AccessibilityGating
// ---------------------------------------------------------------------------

/// Centralized accessibility gating — single source of truth for all animations.
///
/// Invariant I-14: When the user enables Reduce Motion in System Settings, or when
/// the app window is occluded (not visible), all animations must freeze. This class
/// observes both conditions and emits a system-wide notification when animation
/// should stop.
///
/// Never use `.repeatForever` animations; always gate on `animationsAllowed`.
@MainActor
@Observable
public final class AccessibilityGating {
    public static let shared = AccessibilityGating()

    /// `true` when user has enabled Reduce Motion in System Settings
    public var reduceMotion: Bool {
        didSet { if reduceMotion { stopAllAnimations() } }
    }

    /// `true` when the window is occluded (not visible) — pause animations
    public var windowOccluded: Bool = false

    /// `true` when BOTH conditions allow animation
    public var animationsAllowed: Bool { !reduceMotion && !windowOccluded }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe system reduce-motion setting
        self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        // KVO on NSWorkspace for reduce-motion changes
        NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .sink { [weak self] _ in
                self?.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
            .store(in: &cancellables)
    }

    private func stopAllAnimations() {
        // Emit notification for all animated views to freeze
        NotificationCenter.default.post(name: .accessibilityStopAnimations, object: nil)
    }
}

// ---------------------------------------------------------------------------
// MARK: - Notification.Name Extension
// ---------------------------------------------------------------------------

extension Notification.Name {
    public static let accessibilityStopAnimations = Notification.Name("accessibilityStopAnimations")
}

// ---------------------------------------------------------------------------
// MARK: - GatedAnimationModifier
// ---------------------------------------------------------------------------

/// View modifier that gates animation on AccessibilityGating.
///
/// Usage:
/// ```swift
/// MyView()
///     .gatedAnimation(.easeInOut(duration: 0.3), value: someValue)
/// ```
public struct GatedAnimationModifier<Value: Equatable>: ViewModifier {
    @State private var gating = AccessibilityGating.shared
    let animation: Animation
    let value: Value

    public func body(content: Content) -> some View {
        if gating.animationsAllowed {
            content.animation(animation, value: value)
        } else {
            content  // No animation when gated
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - View Extension
// ---------------------------------------------------------------------------

extension View {
    /// Applies an animation only when Reduce Motion is disabled and the window is visible.
    ///
    /// This modifier reads `AccessibilityGating.shared.animationsAllowed` and either
    /// applies the given animation or suppresses it entirely. Use this in place of
    /// `.animation(_:value:)` for all production animations.
    ///
    /// - Parameters:
    ///   - animation: The `Animation` to apply when gating permits.
    ///   - value: The equatable value that drives the animation change.
    /// - Returns: A view that animates only when accessibility gating allows.
    public func gatedAnimation(_ animation: Animation, value: some Equatable) -> some View {
        modifier(GatedAnimationModifier(animation: animation, value: value))
    }
}
