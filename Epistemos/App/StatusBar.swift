import AppKit

// MARK: - Status Bar
// NSStatusItem in the macOS system menu bar.
// Provides quick access to utility windows and Home navigation.

@MainActor
final class StatusBar {
    static let shared = StatusBar()
    private nonisolated static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private init() {}

    // MARK: - Setup

    func setup() {
        guard !Self.isRunningTests else { return }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            // Prefer the template-safe Epistemos E asset; keep a semantic E fallback
            // if an asset-catalog integration issue prevents it from loading.
            let img = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "e.circle", accessibilityDescription: "Epistemos")
            img?.size = NSSize(width: 18, height: 18)
            img?.isTemplate = true
            button.image = img
        }

        let menu = buildMenu()
        item.menu = menu

        self.statusItem = item
        self.menu = menu
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Epistemos")

        // Home — bring main window to front
        let home = NSMenuItem(
            title: "Home", action: #selector(showHome), keyEquivalent: "")
        home.image = NSImage(systemSymbolName: "house", accessibilityDescription: nil)
        home.target = self
        menu.addItem(home)

        let skipRestore = NSMenuItem(
            title: "Skip Restore and Relaunch Home",
            action: #selector(skipRestoreAndRelaunch),
            keyEquivalent: ""
        )
        skipRestore.image = NSImage(
            systemSymbolName: "arrow.clockwise.circle",
            accessibilityDescription: nil
        )
        skipRestore.target = self
        menu.addItem(skipRestore)

        menu.addItem(.separator())

        // Utility windows
        for panel in UtilityPanel.statusBarPanels {
            let item = NSMenuItem(
                title: panel.title, action: #selector(openUtilityPanel(_:)), keyEquivalent: "")
            item.image = NSImage(systemSymbolName: panel.icon, accessibilityDescription: nil)
            item.representedObject = panel.rawValue
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(
            title: "Quit Epistemos", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func showHome() {
        Task { @MainActor in
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            AppBootstrap.shared?.uiState.homeTab = .home
            HomeWindowIdentity.surfaceHomeWindow()
        }
    }

    @objc private func skipRestoreAndRelaunch() {
        Task { @MainActor in
            AppBootstrap.shared?.relaunchSkippingRestoreAndDiscardSession()
        }
    }

    @objc private func openUtilityPanel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
            let panel = UtilityPanel(rawValue: rawValue)
        else { return }
        Task { @MainActor in
            UtilityWindowManager.shared.show(panel)
        }
    }

    // MARK: - Teardown

    func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        menu = nil
    }

    var hasInstalledStatusItemForTesting: Bool {
        statusItem != nil
    }
}
