import AppKit
import SwiftUI

// MARK: - Command Palette Window Controller
// Floating NSPanel that hosts CommandPaletteOverlay as a global overlay.
// Activated from any app via Option+Space (global hotkey).
// Also registers global hotkeys for all palette shortcuts (⌘N, ⌘I, ⌘1, etc.)
// so Epistemos commands work from any app — Raycast/Alfred pattern.

@MainActor
final class CommandPaletteWindowController {

    static let shared = CommandPaletteWindowController()

    private var panel: NSPanel?
    private var hostView: NSHostingView<AnyView>?

    // Event monitors (global + local for full coverage).
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    // MARK: - Setup

    /// Call once at app launch. Registers all global hotkeys but defers panel creation to first show.
    func setup(bootstrap: AppBootstrap) {
        registerHotkeys()
    }

    // MARK: - Show / Hide

    func show() {
        ensurePanel()
        guard let panel else { return }

        // Center on the screen where the cursor currently lives (multi-monitor).
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first!

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Teardown

    func teardown() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        hostView = nil
    }

    // MARK: - Panel Lifecycle

    private func ensurePanel() {
        guard panel == nil else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovableByWindowBackground = true

        guard let bootstrap = AppBootstrap.shared else { return }

        let content = CommandPaletteOverlay()
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
            .preferredColorScheme(bootstrap.uiState.theme.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                if let window = note.object as? NSWindow, window == p {
                    Task { @MainActor in
                        CommandPaletteWindowController.shared.hide()
                    }
                }
            }

        let host = NSHostingView(rootView: AnyView(content))
        host.layer?.backgroundColor = .clear
        p.contentView = host
        self.hostView = host
        self.panel = p
    }

    // MARK: - Global Hotkeys

    /// Hotkey binding: keyCode + required modifiers → action.
    private struct HotkeyBinding {
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags
        let action: @MainActor () -> Void
    }

    private func makeBindings() -> [HotkeyBinding] {
        [
            // Option+Space → Toggle palette
            HotkeyBinding(keyCode: 49, modifiers: [.option]) { [weak self] in
                self?.toggle()
            },
            // ⌘N → New Note
            HotkeyBinding(keyCode: 45, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in
                    guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
                    if let pageId = await vaultSync.createPage(title: "New Note") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            },
            // ⌘I → Quick Idea
            HotkeyBinding(keyCode: 34, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in
                    guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
                    if let pageId = await vaultSync.createPage(title: "New Idea", emoji: "💡") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            },
            // ⌘1 → Go Home
            HotkeyBinding(keyCode: 18, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                AppBootstrap.shared?.chatState.goHome()
                AppBootstrap.shared?.uiState.setActivePanel(.home)
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
            },
            // ⌘2 → Open Notes
            HotkeyBinding(keyCode: 19, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                UtilityWindowManager.shared.show(.notes)
            },
            // ⌘3 → Open Library
            HotkeyBinding(keyCode: 20, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                UtilityWindowManager.shared.show(.library)
            },
            // ⌘, → Open Settings
            HotkeyBinding(keyCode: 43, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                UtilityWindowManager.shared.show(.settings)
            },
            // ⇧⌘M → Toggle Mini Chat
            HotkeyBinding(keyCode: 46, modifiers: [.command, .shift]) {
                MiniChatWindowController.shared.toggle()
            },
            // ⌘G → Knowledge Graph
            HotkeyBinding(keyCode: 5, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                HologramController.shared.toggle()
            },
            // ⌘H → Go Home (overrides macOS "Hide" — Epistemos goes home instead)
            HotkeyBinding(keyCode: 4, modifiers: [.command]) {
                NSApp.activate(ignoringOtherApps: true)
                AppBootstrap.shared?.chatState.goHome()
                AppBootstrap.shared?.uiState.setActivePanel(.home)
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
            },
        ]
    }

    private func registerHotkeys() {
        let bindings = makeBindings()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self != nil else { return }
            for binding in bindings {
                if event.keyCode == binding.keyCode && Self.matchModifiers(event, required: binding.modifiers) {
                    let action = binding.action
                    Task { @MainActor in action() }
                    return
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self != nil else { return event }
            for binding in bindings {
                if event.keyCode == binding.keyCode && Self.matchModifiers(event, required: binding.modifiers) {
                    let action = binding.action
                    Task { @MainActor in action() }
                    return nil // Consume the event.
                }
            }
            return event
        }
    }

    /// Check that exactly the required modifiers are held (ignoring capsLock/numericPad/function).
    private static func matchModifiers(_ event: NSEvent, required: NSEvent.ModifierFlags) -> Bool {
        let cleaned = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        return cleaned == required
    }
}
