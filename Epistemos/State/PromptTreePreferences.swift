import Foundation

// MARK: - PromptTreePreferences
//
// N1 Phase 1 follow-up — let users toggle the EPISTEMOS_PROMPT_TREE
// feature flag from the Settings UI without needing to set a launch
// environment variable.
//
// The original gate at ChatCoordinator.swift:2213 only read
// `ProcessInfo.processInfo.environment["EPISTEMOS_PROMPT_TREE"]`.
// This helper preserves that path (env var takes precedence — useful
// for CI / Xcode scheme overrides) AND adds a UserDefaults-backed
// toggle so end-users can flip the feature on through the
// StructuredSurfacesView "Prompt Tree (Beta)" toggle.
//
// Doctrine alignment:
//   - 01_DOCTRINE.md §6 #1 (no silent behavior — the toggle's state
//     is visible in Settings → Agent → Structures)
//   - 01_DOCTRINE.md §6 #5 (no silent fallback — env var wins, but
//     when only the toggle is set, it's still observable)
//   - PROMPT_AS_DATA_SPEC.md §7 Phase 1 (Settings toggle for the
//     feature flag)

public enum PromptTreePreferences {

    /// UserDefaults key — namespaced per the existing
    /// `epistemos.<feature>` convention used elsewhere in Settings
    /// (see SettingsView.swift line 982 etc).
    public static let userDefaultsKey = "epistemos.n1.promptTree.enabled"

    /// Environment variable name. Takes precedence over the
    /// UserDefaults toggle when set to "1" — useful for CI /
    /// per-launch overrides via Xcode scheme env vars.
    public static let environmentVariable = "EPISTEMOS_PROMPT_TREE"

    /// Returns true when the Prompt Tree (JSPF + PTF) path should
    /// be active. Resolution order:
    ///   1. Environment variable EPISTEMOS_PROMPT_TREE == "1" → on
    ///   2. UserDefaults epistemos.n1.promptTree.enabled == true → on
    ///   3. Otherwise → off (legacy path)
    ///
    /// Both checks are non-isolated and cheap to call per-turn —
    /// ChatCoordinator's hot path can call this without contention.
    public static func isEnabled() -> Bool {
        if ProcessInfo.processInfo.environment[environmentVariable] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    /// Setter for the UserDefaults toggle. Used by the Settings UI
    /// toggle binding. Does not affect the env-var override; if
    /// EPISTEMOS_PROMPT_TREE=1 is set in the launch environment,
    /// `isEnabled()` will continue returning true regardless of
    /// this preference value.
    public static func setUserDefaultEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
    }

    /// Whether the env-var override is currently active. Used by
    /// the Settings UI to show "Locked on by environment variable"
    /// when the env var pins the value beyond the user's control.
    public static func isPinnedByEnvironment() -> Bool {
        ProcessInfo.processInfo.environment[environmentVariable] == "1"
    }
}
