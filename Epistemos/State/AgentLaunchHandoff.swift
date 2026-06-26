import Foundation

// SS-VIS step-2 (owner 2026-06-20): "start off using a tool" from a
// capability launcher. Landing opens the shared AgentToolTogglePanel; toggling
// a tool already arms it via the app-wide AgentCommandCenterState, and the
// AgentClone/fusion submit path inherits that armed state. The ONE remaining
// decision is the operating MODE the new run should start in: a plain tool keeps
// the current mode (the tool is armed, no mode change), while a cowork connector
// / explicit Act action must start in Act mode so a multi-step run is enabled
// from the first turn instead of silently staying single-shot.
//
// This is that pure decision — the foundation the launcher act-mode wiring consumes. It mutates
// nothing; the caller applies the returned mode to the surface's operatingMode binding before submit.
enum AgentLaunchHandoff {

    /// What the user picked from a capability launcher.
    enum Selection: Equatable, Sendable {
        /// A single tool / skill toggle — armed via the shared command center, no mode change.
        case tool
        /// A cowork connector or an explicit Act action — the new chat should run in Act mode.
        case coworkOrAct
    }

    /// The operating mode a launched AgentClone/fusion run should START in.
    /// Tool → unchanged; cowork/Act → `.agent` (Act).
    static func startMode(for selection: Selection,
                          current: EpistemosOperatingMode) -> EpistemosOperatingMode {
        switch selection {
        case .tool:
            return current
        case .coworkOrAct:
            return .agent
        }
    }

    /// Whether launching with `selection` actually changes the mode from `current`, so a caller can
    /// skip a redundant state write (and a redundant re-render) when nothing changes.
    static func changesMode(for selection: Selection,
                            current: EpistemosOperatingMode) -> Bool {
        startMode(for: selection, current: current) != current
    }
}
