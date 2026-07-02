import AppKit
import SwiftUI

public extension View {
    @MainActor
    func commandPaletteHost(registry: CommandRegistry = .shared) -> some View {
        modifier(CommandPaletteHost(registry: registry))
    }
}

@MainActor
private struct CommandPaletteHost: ViewModifier {
    @Bindable var registry: CommandRegistry
    @State private var windowIsKey = false

    func body(content: Content) -> some View {
        content
            .background {
                CommandWindowKeyObserver { isKey in
                    windowIsKey = isKey
                }
                .frame(width: 0, height: 0)
            }
            .sheet(isPresented: palettePresented) {
                CommandPaletteView(registry: registry)
                    .padding(0)
            }
    }

    private var palettePresented: Binding<Bool> {
        Binding(
            get: {
                registry.isCommandPalettePresented && windowIsKey
            },
            set: { newValue in
                if !newValue && windowIsKey {
                    registry.dismissCommandPalette()
                }
            }
        )
    }
}

@MainActor
struct CommandWindowKeyObserver: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onChange = onChange
        nsView.publishCurrentState()
    }

    @MainActor
    final class ObserverView: NSView {
        var onChange: @MainActor (Bool) -> Void = { _ in }
        private var observedWindow: NSWindow?
        private var lastPublishedKeyWindow: Bool?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installObserversIfNeeded()
            publishCurrentState()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func publishCurrentState() {
            installObserversIfNeeded()
            let isKeyWindow = window?.isKeyWindow == true
            guard lastPublishedKeyWindow != isKeyWindow else { return }
            lastPublishedKeyWindow = isKeyWindow
            deliver(isKeyWindow)
        }

        private func deliver(_ isKeyWindow: Bool) {
            Task { @MainActor [onChange] in
                onChange(isKeyWindow)
            }
        }

        private func installObserversIfNeeded() {
            guard observedWindow !== window else { return }
            NotificationCenter.default.removeObserver(self)
            observedWindow = window
            guard let window else { return }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            publishCurrentState()
        }

        @objc private func windowDidResignKey(_ notification: Notification) {
            publishCurrentState()
        }

        @objc private func windowWillClose(_ notification: Notification) {
            lastPublishedKeyWindow = false
            deliver(false)
        }
    }
}
