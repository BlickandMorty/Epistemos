import AppIntents
import Foundation
import OSLog

// MARK: - EpistemosFocusFilter (W14.3)
//
// Wave 14 / App Intents deep-research §"#3 Add Focus Filters" —
// surfaces Epistemos's behavior to macOS Focus modes so the user can
// say "when I'm in Focus: Deep Work, hide all agent interrupts and
// stay local-only."
//
// Apple cap: only ONE `SetFocusFilterIntent` conformance is allowed
// per app (verified via build-time diagnostic 2026-04-26). The
// filter therefore exposes a `mode` parameter (Deep Work / Async /
// Custom) plus per-axis toggles so the user can both pick a preset
// AND tune individual axes from System Settings → Focus.
//
// Verified canonical API: protocol is `SetFocusFilterIntent` (NOT
// `FocusFilterIntent` as the deep-research agent quoted) per
// AppIntents.swiftinterface line 10116.
//
// Persistence: writes through to `UserDefaults` via the
// `EpistemosFocusKeys` constants below; the rest of the app reads
// these to honour the focus.

private let focusLog = Logger(
    subsystem: "com.epistemos",
    category: "EpistemosFocusFilter"
)

// MARK: - UserDefaults bridge

/// UserDefaults keys read by the rest of the app to honour the
/// active Focus filter's settings. Centralised so the filter intent
/// + the runtime checks read/write the same string keys.
public enum EpistemosFocusKeys {
    public static let agentInterruptsDisabled =
        "com.epistemos.focus.agentInterruptsDisabled"
    public static let forceLocalModelsOnly =
        "com.epistemos.focus.forceLocalModelsOnly"
    public static let muteHaloRecallChip =
        "com.epistemos.focus.muteHaloRecallChip"
    public static let lowDistraction =
        "com.epistemos.focus.lowDistraction"

    /// Reset all focus-related keys (called when the user explicitly
    /// turns off the Focus mode; macOS doesn't always invoke a
    /// "filter off" hook).
    public static func clearAll() {
        let d = UserDefaults.standard
        d.removeObject(forKey: agentInterruptsDisabled)
        d.removeObject(forKey: forceLocalModelsOnly)
        d.removeObject(forKey: muteHaloRecallChip)
        d.removeObject(forKey: lowDistraction)
    }
}

// MARK: - Mode enum

enum EpistemosFocusMode: String, AppEnum {
    case deepWork
    case async
    case custom

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        "Epistemos Focus Mode"

    static let caseDisplayRepresentations: [EpistemosFocusMode: DisplayRepresentation] = [
        .deepWork: DisplayRepresentation(
            title: "Deep Work",
            subtitle: "Local only · No interrupts · Halo muted"
        ),
        .async: DisplayRepresentation(
            title: "Async",
            subtitle: "Cloud preferred · Halo prominent"
        ),
        .custom: DisplayRepresentation(
            title: "Custom",
            subtitle: "Use the per-axis toggles below"
        ),
    ]
}

// MARK: - The single SetFocusFilterIntent

struct EpistemosFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Epistemos Focus"
    static let description = IntentDescription(
        "Customize Epistemos behaviour for the active Focus. Pick a preset (Deep Work / Async) or use Custom + the toggles to tune individual axes."
    )

    @Parameter(
        title: "Mode",
        description: "Preset profile, or Custom to honor the per-axis toggles below",
        default: .deepWork
    )
    var mode: EpistemosFocusMode

    @Parameter(
        title: "Disable Agent Interrupts",
        description: "Hide proactive agent popups (compaction prompts, suggestion chips, etc.)",
        default: true
    )
    var disableAgentInterrupts: Bool

    @Parameter(
        title: "Local Models Only",
        description: "Force inference to local Qwen / Hermes; never make cloud calls during this focus",
        default: true
    )
    var localModelsOnly: Bool

    @Parameter(
        title: "Mute Halo Recall Chip",
        description: "Hide the Halo ambient-recall affordance",
        default: true
    )
    var muteHaloChip: Bool

    var displayRepresentation: DisplayRepresentation {
        switch mode {
        case .deepWork:
            return DisplayRepresentation(
                title: "Epistemos: Deep Work",
                subtitle: "Local only · No interrupts · Halo muted"
            )
        case .async:
            return DisplayRepresentation(
                title: "Epistemos: Async",
                subtitle: "Cloud preferred · Halo prominent"
            )
        case .custom:
            return DisplayRepresentation(
                title: "Epistemos: Custom",
                subtitle: "Per-axis toggles"
            )
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let d = UserDefaults.standard
        switch mode {
        case .deepWork:
            d.set(true, forKey: EpistemosFocusKeys.agentInterruptsDisabled)
            d.set(true, forKey: EpistemosFocusKeys.forceLocalModelsOnly)
            d.set(true, forKey: EpistemosFocusKeys.muteHaloRecallChip)
            d.set(true, forKey: EpistemosFocusKeys.lowDistraction)
        case .async:
            d.set(false, forKey: EpistemosFocusKeys.agentInterruptsDisabled)
            d.set(false, forKey: EpistemosFocusKeys.forceLocalModelsOnly)
            d.set(false, forKey: EpistemosFocusKeys.muteHaloRecallChip)
            d.set(false, forKey: EpistemosFocusKeys.lowDistraction)
        case .custom:
            d.set(disableAgentInterrupts, forKey: EpistemosFocusKeys.agentInterruptsDisabled)
            d.set(localModelsOnly, forKey: EpistemosFocusKeys.forceLocalModelsOnly)
            d.set(muteHaloChip, forKey: EpistemosFocusKeys.muteHaloRecallChip)
            d.set(disableAgentInterrupts || localModelsOnly,
                  forKey: EpistemosFocusKeys.lowDistraction)
        }
        focusLog.info(
            "Focus filter engaged mode=\(self.mode.rawValue, privacy: .public)"
        )
        return .result()
    }
}
