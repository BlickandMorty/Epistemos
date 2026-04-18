import AppKit
import ObjectiveC.runtime

@MainActor
final class HomeWindowInputDiagnostics: NSObject {
    static let shared = HomeWindowInputDiagnostics()
    static let environmentKey = "EPI_HOME_WINDOW_INPUT_DIAGNOSTICS"

    private static let maxLoggedLowAlphaViews = 24

    private var started = false

    private override init() {}

    /// Compile-time opt-in. Never reads the shell env var because users
    /// commonly leave `EPI_HOME_WINDOW_INPUT_DIAGNOSTICS=1` in their shell
    /// rc after a past audit; that was causing the main-window input lag
    /// regression (swizzled `setAlphaValue` + `sendEvent` fired ~10k
    /// diagnostic events per 8 idle minutes, confirmed in
    /// `/tmp/epistemos-runtime.log`). To re-enable for a specific audit,
    /// flip the literal below to `true`, rebuild, and flip it back when
    /// done.
    var isEnabled: Bool { false }

    func startIfNeeded() {
        guard isEnabled, !started else { return }
        started = true
        HomeWindowInputSwizzles.install()

        let center = NotificationCenter.default
        let windowNames: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didDeminiaturizeNotification,
        ]

        windowNames.forEach { name in
            center.addObserver(
                self,
                selector: #selector(handleHomeWindowNotification(_:)),
                name: name,
                object: nil
            )
        }

        center.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            self?.snapshotCurrentHomeWindow(reason: "startup_snapshot")
        }
    }

    func stop() {
        guard started else { return }
        started = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleHomeWindowNotification(_ note: Notification) {
        guard let window = note.object as? NSWindow,
            HomeWindowIdentity.matches(window)
        else { return }
        dumpWindowState(window, reason: note.name.rawValue)
    }

    @objc private func handleApplicationDidBecomeActive(_ note: Notification) {
        snapshotCurrentHomeWindow(reason: "app_didBecomeActive")
    }

    func logSendEvent(window: NSWindow, event: NSEvent) {
        guard isEnabled, HomeWindowIdentity.matches(window) else { return }

        let interestingTypes: Set<NSEvent.EventType> = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseUp,
            .rightMouseUp,
            .keyDown,
        ]
        guard interestingTypes.contains(event.type) else { return }

        var metadata = windowMetadata(window)
        metadata["eventType"] = String(event.type.rawValue)
        metadata["locationInWindow"] = format(point: event.locationInWindow)

        if let contentView = window.contentView {
            let contentPoint = contentView.convert(event.locationInWindow, from: nil)
            let hitView = contentView.hitTest(contentPoint)
            metadata["contentPoint"] = format(point: contentPoint)
            metadata["hitView"] = hitView.map(viewDescription) ?? "nil"
            metadata["hitPath"] = hitView.map(viewPathDescription) ?? "nil"
        } else {
            metadata["hitView"] = "missing_contentView"
        }

        RuntimeDiagnostics.record(
            .info,
            category: "InputAudit",
            message: "home_window_send_event",
            metadata: metadata
        )

        if metadata["hitView"] == "nil" {
            dumpWindowState(window, reason: "send_event_hit_test_nil")
        }
    }

    func logAlphaWrite(view: NSView, newValue: CGFloat) {
        guard isEnabled,
            let window = view.window,
            HomeWindowIdentity.matches(window)
        else { return }

        let tracksWholeTree = view === window.contentView
            || (window.contentView.map { view.isDescendant(of: $0) } ?? false)
        guard tracksWholeTree else { return }

        let shouldLog = newValue < 0.999 || view === window.contentView
        guard shouldLog else { return }

        var metadata = windowMetadata(window)
        metadata["view"] = viewDescription(view)
        metadata["viewPath"] = viewPathDescription(view)
        metadata["newAlphaValue"] = format(number: Double(newValue))

        RuntimeDiagnostics.record(
            newValue < 0.01 ? .warning : .info,
            category: "InputAudit",
            message: "home_window_alpha_write",
            metadata: metadata
        )

        if newValue < 0.5 || view === window.contentView {
            dumpWindowState(window, reason: "alpha_write")
        }
    }

    func snapshotCurrentHomeWindow(reason: String) {
        guard let window = NSApp.windows.first(where: HomeWindowIdentity.matches) else {
            RuntimeDiagnostics.recordLifecycleEvent(
                "home_window_snapshot_missing",
                metadata: ["reason": reason]
            )
            return
        }
        dumpWindowState(window, reason: reason)
    }

    private func dumpWindowState(_ window: NSWindow, reason: String) {
        guard HomeWindowIdentity.matches(window) else { return }
        var metadata = windowMetadata(window)
        metadata["reason"] = reason

        if let contentView = window.contentView {
            metadata["contentView"] = viewDescription(contentView)
            metadata["contentAlphaValue"] = format(number: Double(contentView.alphaValue))
            metadata["contentLayerOpacity"] = format(number: Double(contentView.layer?.opacity ?? -1))
            metadata["contentIsHidden"] = boolLabel(contentView.isHidden)

            let lowAlphaViews = lowAlphaDescendants(in: contentView)
            if !lowAlphaViews.isEmpty {
                metadata["lowAlphaViews"] = lowAlphaViews.joined(separator: " | ")
            }
        } else {
            metadata["contentView"] = "nil"
        }

        RuntimeDiagnostics.recordLifecycleEvent("home_window_snapshot", metadata: metadata)
    }

    private func lowAlphaDescendants(in root: NSView) -> [String] {
        var queue = Array(root.subviews)
        var matches: [String] = []

        while !queue.isEmpty && matches.count < Self.maxLoggedLowAlphaViews {
            let view = queue.removeFirst()
            if view.alphaValue < 0.5 {
                matches.append("\(viewDescription(view)) alpha=\(format(number: Double(view.alphaValue)))")
            }
            queue.append(contentsOf: view.subviews)
        }

        return matches
    }

    private func windowMetadata(_ window: NSWindow) -> [String: String] {
        [
            "windowTitle": window.title,
            "windowIdentifier": window.identifier?.rawValue ?? "nil",
            "windowClass": String(describing: type(of: window)),
            "isKeyWindow": boolLabel(window.isKeyWindow),
            "isMainWindow": boolLabel(window.isMainWindow),
            "isVisible": boolLabel(window.isVisible),
            "ignoresMouseEvents": boolLabel(window.ignoresMouseEvents),
            "styleMask": String(window.styleMask.rawValue),
            "collectionBehavior": String(window.collectionBehavior.rawValue),
        ]
    }

    private func viewDescription(_ view: NSView) -> String {
        String(describing: type(of: view))
    }

    private func viewPathDescription(_ view: NSView) -> String {
        var path: [String] = []
        var current: NSView? = view

        while let node = current, path.count < 8 {
            path.append(viewDescription(node))
            current = node.superview
        }

        return path.joined(separator: " <- ")
    }

    private func boolLabel(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func format(number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(3)))
    }

    private func format(point: CGPoint) -> String {
        "\(format(number: Double(point.x))),\(format(number: Double(point.y)))"
    }
}

private nonisolated enum HomeWindowInputSwizzles {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var installed = false

    static func install() {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }
        installed = true

        swizzle(
            NSWindow.self,
            original: #selector(NSWindow.sendEvent(_:)),
            replacement: #selector(NSWindow.epi_inputDiagnostics_sendEvent(_:))
        )
        swizzle(
            NSView.self,
            original: #selector(setter: NSView.alphaValue),
            replacement: #selector(NSView.epi_inputDiagnostics_setAlphaValue(_:))
        )
    }

    private static func swizzle(_ cls: AnyClass, original: Selector, replacement: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, original),
            let replacementMethod = class_getInstanceMethod(cls, replacement)
        else { return }

        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

private extension NSWindow {
    @objc func epi_inputDiagnostics_sendEvent(_ event: NSEvent) {
        MainActor.assumeIsolated {
            HomeWindowInputDiagnostics.shared.logSendEvent(window: self, event: event)
        }
        epi_inputDiagnostics_sendEvent(event)
    }
}

private extension NSView {
    @objc func epi_inputDiagnostics_setAlphaValue(_ alphaValue: CGFloat) {
        MainActor.assumeIsolated {
            HomeWindowInputDiagnostics.shared.logAlphaWrite(view: self, newValue: alphaValue)
        }
        epi_inputDiagnostics_setAlphaValue(alphaValue)
    }
}
