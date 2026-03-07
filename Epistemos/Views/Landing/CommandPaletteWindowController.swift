import AppKit
import Carbon.HIToolbox
import SwiftUI

extension Notification.Name {
    static let commandPaletteSwitchToChat = Notification.Name("commandPaletteSwitchToChat")
    static let commandPaletteDidHide = Notification.Name("commandPaletteDidHide")
}

// MARK: - Command Palette Window Controller
// Floating NSPanel that hosts CommandPaletteOverlay as a global overlay.
// Activated from any app via Option+Space (global hotkey via Carbon API).
// No accessibility permissions required — uses RegisterEventHotKey, same
// API as Raycast / Alfred / Spotlight.

// MARK: - Keyable Panel
// Borderless NSPanel returns false for canBecomeKey by default,
// which silently blocks all keyboard input. This subclass fixes that.

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CommandPaletteWindowController {

    static let shared = CommandPaletteWindowController()

    // Search palette
    private var panel: NSPanel?
    private var hostView: NSHostingView<AnyView>?
    private var isShowing = false  // Guard against resign during show sequence

    // Carbon global hotkey (Option+Space)
    private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private static var eventHandlerRef: EventHandlerRef?

    private init() {}

    // MARK: - Setup

    /// Call once at app launch. Registers Option+Space as a system-wide hotkey.
    func setup(bootstrap: AppBootstrap) {
        registerGlobalHotkey()
    }

    // MARK: - Show / Hide

    /// Shows the search palette centered on screen.
    func show() {
        ensurePanel()
        guard let panel else { return }

        // Center on the screen where the cursor currently lives (multi-monitor).
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main else { return }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelSize.width / 2
        // Anchor near top of screen (Dynamic Island position).
        let y = screenFrame.maxY - panelSize.height + 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        isShowing = true
        // Activate BEFORE ordering front — ensures macOS routes keyboard events to us
        // even when other apps (ChatGPT, Raycast) have floating panels.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Immediate first responder claim — no gap for other panels to steal focus.
        if let contentView = panel.contentView {
            panel.makeFirstResponder(contentView)
        }

        // Second attempt after SwiftUI has laid out @FocusState-connected views.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            // Re-assert: another overlay may have stolen key status in the gap.
            if panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
                if let contentView = panel.contentView {
                    panel.makeFirstResponder(contentView)
                }
            }
            isShowing = false
        }
    }

    func hide() {
        panel?.orderOut(nil)
        NotificationCenter.default.post(name: .commandPaletteDidHide, object: nil)
    }

    /// Option+Space toggle: show or dismiss global search.
    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    /// Opens the palette directly in chat mode (replaces MiniChat toggle).
    func toggleChatMode() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
            NotificationCenter.default.post(name: .commandPaletteSwitchToChat, object: nil)
        }
    }

    // MARK: - Theme

    func syncTheme(isDark: Bool) {
        panel?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    // MARK: - Teardown

    func teardown() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = Self.eventHandlerRef {
            RemoveEventHandler(ref)
            Self.eventHandlerRef = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostView = nil
    }

    // MARK: - Panel Lifecycle

    private func ensurePanel() {
        guard panel == nil else { return }

        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 120),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // .floating keeps it above all normal windows (like MiniChat).
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.isMovableByWindowBackground = true
        p.minSize = NSSize(width: 400, height: 80)
        p.maxSize = NSSize(width: 540, height: 700)

        guard let bootstrap = AppBootstrap.shared else { return }

        // Wrap overlay in padding so SwiftUI's shadow renders outside the content
        // without being clipped by the window edge. The window itself is transparent
        // and borderless — only the SwiftUI RoundedRectangle is visible.
        let content = CommandPaletteOverlay()
            .padding(40) // Room for shadow to render
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                if let window = note.object as? NSWindow, window == p {
                    Task { @MainActor in
                        guard !CommandPaletteWindowController.shared.isShowing else { return }
                        // Don't auto-dismiss — user closes with Option+Space or Escape.
                        // This keeps the panel visible like MiniChat.
                    }
                }
            }

        let host = NSHostingView(rootView: AnyView(content))
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        p.contentView = host
        self.hostView = host
        self.panel = p
    }

    // MARK: - Global Hotkey (Carbon API)

    /// Registers Option+Space as a system-wide hotkey using Carbon's RegisterEventHotKey.
    /// This API does NOT require accessibility permissions — it's the standard macOS approach
    /// used by Spotlight, Raycast, Alfred, and every other global shortcut utility.
    private func registerGlobalHotkey() {
        var hotKeyID = EventHotKeyID(signature: 0x45504953, id: 1) // "EPIS"

        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C callback — no captured context. Uses the static singleton directly.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                Task { @MainActor in
                    CommandPaletteWindowController.shared.toggle()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &Self.eventHandlerRef
        )

        // Option+Space: optionKey = 0x0800, kVK_Space = 49
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
