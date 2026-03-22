import AppKit

// MARK: - Status Bar
// NSStatusItem in the macOS system menu bar.
// Provides quick access to utility windows (Settings, Notes),
// Home navigation, and MiniChat toggle.

@MainActor
final class StatusBar {
    static let shared = StatusBar()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private init() {}

    // MARK: - Setup

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            // Try the custom book icon from the asset catalog, fall back to SF Symbol
            let img = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "book", accessibilityDescription: "Epistemos")
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

        // MiniChat toggle
        let miniChat = NSMenuItem(
            title: "New Mini Chat", action: #selector(toggleMiniChat), keyEquivalent: "")
        miniChat.image = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil)
        miniChat.target = self
        menu.addItem(miniChat)

        // Home — bring main window to front
        let home = NSMenuItem(
            title: "Home", action: #selector(showHome), keyEquivalent: "")
        home.image = NSImage(systemSymbolName: "house", accessibilityDescription: nil)
        home.target = self
        menu.addItem(home)

        menu.addItem(.separator())

        // Utility windows
        for panel in UtilityPanel.allCases {
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

    @objc private func toggleMiniChat() {
        Task { @MainActor in
            MiniChatWindowController.shared.openNewChat()
        }
    }

    @objc private func showHome() {
        Task { @MainActor in
            AppBootstrap.shared?.chatState.goHome()
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            AppBootstrap.shared?.uiState.homeTab = .home
            NSApplication.shared.activate()
            // mainWindow can be nil when app is backgrounded — find by title.
            if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                main.makeKeyAndOrderFront(nil)
            }
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
}
