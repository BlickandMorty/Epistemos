import SwiftUI

/// VISIBLE SURFACES / two-mode ontology (owner §122/§194 "two toggles = act/work"): the SINGLE source of truth
/// for which mode the user is in (act vs work) + whether each mode's experimental engine is armed. Ties together
/// the pieces already built — `WorkspaceModeKind` (mode-entry transition), the act gate (`ActOsaurusGateStatus`)
/// and the work gate (`WorkOpenCodeShellGateStatus`). Pure + persisted + unit-testable; the picker view below is
/// the thin visual layer the landing flow mounts. Selecting a mode is SEPARATE from arming its engine (the gates
/// are the explicit opt-in toggles) — selection picks the surface, the gate toggles arm the experimental engine.
nonisolated enum WorkspaceModeSelection {
    static let defaultsKey = "epistemos.workspace.mode"

    /// The user's current mode (defaults to `.act` — the chat-like surface — when unset / unrecognized).
    static func current(defaults: UserDefaults = .standard) -> WorkspaceModeKind {
        guard let raw = defaults.string(forKey: defaultsKey),
              let mode = WorkspaceModeKind(rawValue: raw) else { return .act }
        return mode
    }

    /// Persist the user's selected mode.
    static func select(_ mode: WorkspaceModeKind, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: defaultsKey)
    }

    /// Whether the given mode's engine is armed. Act reads the shared act-routing
    /// truth so the landing picker cannot disagree with the mounted surface or
    /// bridge factory; work still reads its explicit Pro gate.
    static func isArmed(
        _ mode: WorkspaceModeKind,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        switch mode {
        case .act:
            _ = defaults
            return LocalAgentLoop.shouldRouteActThroughOsaurus(environment: environment)
        case .work:
            return WorkOpenCodeShellGateStatus.resolvedActive(environment: environment, defaults: defaults)
        }
    }
}

/// Reusable act/work mode picker (owner §194 "two toggles = act/work"). A flat segmented control rendering the
/// two modes with a live per-mode armed dot; selecting persists via `WorkspaceModeSelection` + calls back. The
/// caller binds `mode` and reacts (e.g. drive the `ModeEntryTitleView` transition). Minimal Epistemos chrome;
/// the landing-flow placement + final styling are the owner-reviewed visual follow-on.
struct WorkspaceModePicker: View {
    @Binding var mode: WorkspaceModeKind
    var onSelect: ((WorkspaceModeKind) -> Void)? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceModeKind.allCases, id: \.self) { candidate in
                let selected = candidate == mode
                Button {
                    mode = candidate
                    WorkspaceModeSelection.select(candidate)
                    onSelect?(candidate)
                } label: {
                    HStack(spacing: 5) {
                        if WorkspaceModeSelection.isArmed(candidate) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                        }
                        Text(candidate.defaultLabel)
                            .font(.callout.weight(selected ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selected ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .accessibilityLabel("\(candidate.defaultLabel) mode\(selected ? ", selected" : "")")
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.04)))
    }
}
