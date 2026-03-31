import AppKit
import CoreGraphics
import Foundation

// MARK: - Agent Action Executor (VLM Desktop)

/// Executes actions on the agent's isolated desktop via CGEvent and AXUIElement APIs.
///
/// Prefers AX-based actions (work cross-Space, more reliable) over CGEvent
/// (requires active Space, coordinate-based). Falls back to CGEvent for apps
/// with poor AX support.
actor AgentActionExecutor {

    // MARK: - Action Types

    /// Complete action vocabulary for the desktop agent.
    enum Action: Codable, Sendable {
        case click(x: Double, y: Double)
        case doubleClick(x: Double, y: Double)
        case rightClick(x: Double, y: Double)
        case drag(fromX: Double, fromY: Double, toX: Double, toY: Double)
        case typeText(String)
        case keyPress(key: String, modifiers: [KeyModifier])
        case scroll(x: Double, y: Double, deltaX: Double, deltaY: Double)
        case openApp(bundleId: String)
        case wait(seconds: Double)
        case axAction(elementPath: String, action: String)

        enum KeyModifier: String, Codable, Sendable {
            case cmd, shift, option, control, fn
        }

        /// Estimated execution time for scheduling and timeout calculation.
        var estimatedDuration: TimeInterval {
            switch self {
            case .click, .doubleClick, .rightClick: return 0.3
            case .drag: return 0.8
            case .typeText(let text): return Double(text.count) * 0.03
            case .keyPress: return 0.2
            case .scroll: return 0.4
            case .openApp: return 3.0
            case .wait(let s): return s
            case .axAction: return 0.5
            }
        }
    }

    // MARK: - Execution

    /// Execute a single action. Returns true if execution succeeded mechanically.
    func execute(_ action: Action) async throws -> Bool {
        switch action {
        case .click(let x, let y):
            let pt = CGPoint(x: x, y: y)
            return postMouseEvent(type: .leftMouseDown, at: pt)
                && postMouseEvent(type: .leftMouseUp, at: pt)

        case .doubleClick(let x, let y):
            let pt = CGPoint(x: x, y: y)
            postMouseEvent(type: .leftMouseDown, at: pt, clickCount: 1)
            postMouseEvent(type: .leftMouseUp, at: pt, clickCount: 1)
            postMouseEvent(type: .leftMouseDown, at: pt, clickCount: 2)
            return postMouseEvent(type: .leftMouseUp, at: pt, clickCount: 2)

        case .rightClick(let x, let y):
            let pt = CGPoint(x: x, y: y)
            return postMouseEvent(type: .rightMouseDown, at: pt)
                && postMouseEvent(type: .rightMouseUp, at: pt)

        case .drag(let fx, let fy, let tx, let ty):
            let from = CGPoint(x: fx, y: fy)
            let to = CGPoint(x: tx, y: ty)
            postMouseEvent(type: .leftMouseDown, at: from)
            let steps = 20
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let mid = CGPoint(
                    x: from.x + (to.x - from.x) * t,
                    y: from.y + (to.y - from.y) * t
                )
                postMouseEvent(type: .leftMouseDragged, at: mid)
                try await Task.sleep(for: .milliseconds(10))
            }
            return postMouseEvent(type: .leftMouseUp, at: to)

        case .typeText(let text):
            return typeString(text)

        case .keyPress(let key, let modifiers):
            return pressKey(key, modifiers: modifiers)

        case .scroll(let x, let y, let dx, let dy):
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(dy),
                wheel2: Int32(dx),
                wheel3: 0
            ) else { return false }
            event.location = CGPoint(x: x, y: y)
            event.post(tap: .cghidEventTap)
            return true

        case .openApp(let bundleId):
            return await openApplication(bundleId)

        case .wait(let seconds):
            try await Task.sleep(for: .seconds(seconds))
            return true

        case .axAction(let elementPath, let actionName):
            return performAXAction(elementPath: elementPath, action: actionName)
        }
    }

    // MARK: - Mouse Events

    @discardableResult
    private func postMouseEvent(
        type: CGEventType,
        at point: CGPoint,
        clickCount: Int64 = 1
    ) -> Bool {
        let isRight = type == .rightMouseDown || type == .rightMouseUp
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: isRight ? .right : .left
        ) else { return false }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Keyboard Events

    private func typeString(_ text: String) -> Bool {
        for character in text {
            let str = String(character)
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
                return false
            }
            let utf16 = Array(str.utf16)
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            up?.post(tap: .cghidEventTap)
        }
        return true
    }

    private func pressKey(_ key: String, modifiers: [Action.KeyModifier]) -> Bool {
        guard let keyCode = Self.keyCodeMap[key.lowercased()] else { return false }

        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod {
            case .cmd: flags.insert(.maskCommand)
            case .shift: flags.insert(.maskShift)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .fn: flags.insert(.maskSecondaryFn)
            }
        }

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        up.flags = flags
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - App Launch

    private func openApplication(_ bundleId: String) async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            return true
        } catch {
            return false
        }
    }

    // MARK: - AX Actions

    private func performAXAction(elementPath: String, action: String) -> Bool {
        // Element path format: "app:com.apple.Safari/window:0/button:Done"
        // Full implementation uses AXorcistBridge for element resolution.
        // Stub: returns false to signal fallback to CGEvent path.
        return false
    }

    // MARK: - Key Code Map

    private static let keyCodeMap: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96,
        "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111,
    ]
}
