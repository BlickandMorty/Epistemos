import AppKit
import Foundation

/// Three-pulse damped-sinusoid haptic beat scoped to the landing-wave overlay.
///
/// Does **not** modify the global `HapticHelper` used by sidebar/streaming
/// haptics — this is an isolated service with its own accessibility gates.
///
/// Mapping (matches `LandingWaveDesign.HapticBeatDelay`):
///   - t=0.00s  `.levelChange` — impact
///   - t=0.19s  `.alignment`   — Worthington jet rebound
///   - t=0.42s  `.levelChange` — primary wave crest
///
/// Haptic output requires a Magic Trackpad / Force Touch trackpad. External
/// mouse users get silence — acceptable per the plan.
enum LandingWaveHaptics {

    /// Preference key gating the entire landing-wave haptic beat. Defaults to
    /// true; disables globally when set to false in user settings.
    static let preferenceKey = "epistemos.landing.hapticsEnabled"

    /// Fires the full three-pulse beat starting now. Subsequent calls schedule
    /// new beats — the pulses are dispatched on the main queue, so they don't
    /// stack if the user rapid-clicks (each click just adds its own beat).
    ///
    /// - Parameters:
    ///   - reduceMotion: when true, emits nothing (accessibility guard).
    ///   - windowOccluded: when true, emits nothing (performance guard).
    ///   - userDisabled: when true, emits nothing (user preference).
    @MainActor
    static func fireBeat(
        reduceMotion: Bool,
        windowOccluded: Bool,
        userDisabled: Bool = false
    ) {
        guard !reduceMotion, !windowOccluded, !userDisabled else { return }

        // Each performer access happens on the main thread, so we fetch the
        // (non-Sendable) default performer inside each closure rather than
        // capturing it across a `@Sendable` boundary.
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        scheduleBeat(after: LandingWaveDesign.HapticBeatDelay.worthingtonJet) {
            Task { @MainActor in
                NSHapticFeedbackManager.defaultPerformer
                    .perform(.alignment, performanceTime: .now)
            }
        }

        scheduleBeat(after: LandingWaveDesign.HapticBeatDelay.waveCrest) {
            Task { @MainActor in
                NSHapticFeedbackManager.defaultPerformer
                    .perform(.levelChange, performanceTime: .now)
            }
        }
    }

    @MainActor
    private static func scheduleBeat(
        after delaySeconds: Double,
        action: @escaping @Sendable () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds, execute: action)
    }
}
