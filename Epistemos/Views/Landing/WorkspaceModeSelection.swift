import Foundation
import SwiftUI

/// VISIBLE SURFACES / mode ontology: the SINGLE source of truth for which mode the user is in (chat/act/work) and
/// whether each mode's engine is actually ready. Act follows the shared local-agent route; Work follows the real
/// bundled runtime factory, while the old Work gate remains only as a compatibility/status seam.
nonisolated enum WorkspaceModeSelection {
    static let defaultsKey = "epistemos.workspace.mode"
    static let didSelectNotification = Notification.Name("epistemos.workspace.mode.didSelect")
    static let selectedModeUserInfoKey = "mode"

    /// The user's current mode (defaults to `.act` — the chat-like surface — when unset / unrecognized).
    static func current(defaults: UserDefaults = .standard) -> WorkspaceModeKind {
        guard let raw = defaults.string(forKey: defaultsKey),
              let mode = WorkspaceModeKind(rawValue: raw) else { return .act }
        return mode
    }

    /// Persist the user's selected mode.
    static func select(_ mode: WorkspaceModeKind, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: defaultsKey)
        NotificationCenter.default.post(
            name: didSelectNotification,
            object: defaults,
            userInfo: [selectedModeUserInfoKey: mode.rawValue]
        )
    }

    /// Whether the given mode's engine is armed.
    static func isArmed(
        _ mode: WorkspaceModeKind,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        switch mode {
        case .act:
            _ = defaults
            _ = environment
            return true
        case .work:
            _ = defaults
            _ = environment
            return WorkOpenCodeRuntime.bundledRuntimeURL() != nil
        case .chat:
            // The native Swarm-backed Chat surface is always available (no experimental
            // engine gate); model readiness is surfaced inside the surface itself.
            return true
        }
    }
}

/// Reusable mode picker. A flat segmented control rendering each mode with a live readiness dot; selecting persists
/// via `WorkspaceModeSelection` + calls back. The caller binds `mode` and reacts (e.g. drive the
/// `ModeEntryTitleView` transition). Minimal Epistemos chrome.
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
