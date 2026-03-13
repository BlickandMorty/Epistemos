import AppKit

// MARK: - System Appearance Observer
// Plain class (not @Observable) — uses NSWorkspace notifications to detect dark/light mode.
// Pitfall #13: never use .preferredColorScheme() — it overrides @Environment(\.colorScheme).

enum SystemAppearanceState {
    static func isDark(
        globalDomain: [String: Any]? = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
    ) -> Bool {
        (globalDomain?["AppleInterfaceStyle"] as? String) == "Dark"
    }
}

final class SystemAppearanceObserver {
    private var workspaceToken: NSObjectProtocol?
    private var themeToken: NSObjectProtocol?
    nonisolated(unsafe) var onAppearanceChange: (@MainActor @Sendable (Bool) -> Void)?

    @MainActor
    func start() {
        notifyNow()
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.notifyNow() }
        }

        // Also observe system appearance changes directly
        themeToken = DistributedNotificationCenter.default().addObserver(
            forName: .init("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.notifyNow() }
        }
    }

    @MainActor
    func stop() {
        if let t = workspaceToken {
            NSWorkspace.shared.notificationCenter.removeObserver(t)
            workspaceToken = nil
        }
        if let t = themeToken {
            DistributedNotificationCenter.default().removeObserver(t)
            themeToken = nil
        }
    }

    @MainActor
    private func notifyNow() {
        onAppearanceChange?(SystemAppearanceState.isDark())
    }
}
