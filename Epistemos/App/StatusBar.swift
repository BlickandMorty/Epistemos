import AppKit

// MARK: - Status Bar
// NSStatusItem in the macOS system menu bar.
// Provides quick access to utility windows (Settings, Notes, Library),
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
            button.image = NSImage(
                systemSymbolName: "brain.head.profile", accessibilityDescription: "Epistemos")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
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
            title: "Toggle Mini Chat", action: #selector(toggleMiniChat), keyEquivalent: "")
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
            MiniChatWindowController.shared.toggle()
        }
    }

    @objc private func showHome() {
        Task { @MainActor in
            AppBootstrap.shared?.chatState.goHome()
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            NSApplication.shared.activate()
            NSApplication.shared.mainWindow?.makeKeyAndOrderFront(nil)
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
