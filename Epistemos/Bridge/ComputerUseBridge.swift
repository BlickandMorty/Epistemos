// ComputerUseBridge.swift
//
// Bridges the Rust agent_core "computer" tool to the native macOS
// computer use stack (ScreenCaptureKit, AXorcist, CGEvent).
//
// Architecture:
//   Rust agent_loop → computer_use.rs (returns delegate marker)
//   → StreamingDelegate.onToolStarted("computer")
//   → ChatCoordinator intercepts and calls ComputerUseBridge
//   → Result (screenshot base64 + AX tree JSON) returned to agent
//
// This gives the LLM BOTH visual (screenshot) AND semantic (AX tree)
// understanding of the screen — deeper than pure screenshot-based systems.

import AppKit
import Foundation
import ScreenCaptureKit
import os.log

@MainActor
final class ComputerUseBridge {
    static let shared = ComputerUseBridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "ComputerUse")

    // MARK: - Execute Computer Action

    /// Executes a computer use action and returns the result as a JSON string.
    /// Called by ChatCoordinator when Rust agent's "computer" tool fires.
    func execute(actionJSON: String) async -> String {
        guard let data = actionJSON.data(using: .utf8),
              let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorResult("Invalid action JSON")
        }

        let action = (input["action"] as? String) ?? "screenshot"

        // Check TCC permissions before any action
        guard AXIsProcessTrusted() else {
            return errorResult("Accessibility permission not granted. Open System Settings > Privacy & Security > Accessibility.")
        }

        switch action {
        case "screenshot":
            return await captureScreenWithAXTree()

        case "click":
            let x = (input["x"] as? Int) ?? 0
            let y = (input["y"] as? Int) ?? 0
            return await performClick(x: x, y: y)

        case "type_text":
            let text = (input["text"] as? String) ?? ""
            return await performType(text: text)

        case "scroll":
            let x = (input["x"] as? Int) ?? 0
            let y = (input["y"] as? Int) ?? 0
            let direction = (input["direction"] as? String) ?? "down"
            return await performScroll(x: x, y: y, direction: direction)

        case "get_ax_tree":
            let appName = input["app_name"] as? String
            return await getAccessibilityTree(appName: appName)

        case "key_press":
            let key = (input["text"] as? String) ?? ""
            return await performKeyPress(key: key)

        default:
            return errorResult("Unknown action: \(action)")
        }
    }

    // MARK: - Screenshot + AX Tree (the "deeper than screen capture" capability)

    /// Captures a screenshot AND the accessibility tree, returning both.
    /// The AX tree gives the LLM semantic understanding (button labels,
    /// text fields, checkboxes) without requiring pure visual inference.
    private func captureScreenWithAXTree() async -> String {
        // Capture screenshot via ScreenCaptureKit (macOS 13+)
        let image: CGImage
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                return errorResult("No display found")
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = 1280
            config.height = 720
            config.showsCursor = false
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            return errorResult("Screenshot failed: \(error.localizedDescription)")
        }

        // Convert to base64 JPEG (already scaled to 1280x720 by ScreenCaptureKit config)
        guard let jpegData = jpegData(from: image, quality: 0.7) else {
            return errorResult("Failed to encode screenshot as JPEG")
        }
        let base64Screenshot = jpegData.base64EncodedString()

        // Capture AX tree for semantic understanding
        let axTree = await captureAXTree()

        let result: [String: Any] = [
            "success": true,
            "screenshot_base64": base64Screenshot,
            "screenshot_format": "image/jpeg",
            "screenshot_width": image.width,
            "screenshot_height": image.height,
            "accessibility_tree": axTree,
            "message": "Screenshot captured with accessibility tree. The AX tree shows interactive elements (buttons, text fields, etc.) with their labels and positions.",
        ]

        return jsonString(result)
    }

    // MARK: - Input Actions

    private func performClick(x: Int, y: Int) async -> String {
        let point = CGPoint(x: x, y: y)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                              mouseCursorPosition: point, mouseButton: .left)

        mouseDown?.post(tap: .cghidEventTap)
        // Small delay for UI to register the click
        try? await Task.sleep(for: .milliseconds(50))
        mouseUp?.post(tap: .cghidEventTap)

        // Wait for UI to settle
        try? await Task.sleep(for: .milliseconds(200))

        return successResult("Clicked at (\(x), \(y))")
    }

    private func performType(text: String) async -> String {
        for char in text {
            let str = String(char)
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            var chars = Array(str.utf16)
            event?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event?.post(tap: .cghidEventTap)

            let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)

            try? await Task.sleep(for: .milliseconds(10))
        }

        return successResult("Typed \(text.count) characters")
    }

    private func performScroll(x: Int, y: Int, direction: String) async -> String {
        // Move mouse to position first
        let point = CGPoint(x: x, y: y)
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        // Create scroll event
        let scrollAmount: Int32 = direction == "up" || direction == "left" ? 3 : -3
        let isVertical = direction == "up" || direction == "down"

        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 1,
                                  wheel1: isVertical ? scrollAmount : 0,
                                  wheel2: isVertical ? 0 : scrollAmount,
                                  wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)

        return successResult("Scrolled \(direction) at (\(x), \(y))")
    }

    private func performKeyPress(key: String) async -> String {
        // Map common key names to virtual key codes
        let keyCode: CGKeyCode = switch key.lowercased() {
        case "return", "enter":  36
        case "tab":              48
        case "space":            49
        case "delete":           51
        case "escape", "esc":    53
        case "up":               126
        case "down":             125
        case "left":             123
        case "right":            124
        default:                 0
        }

        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        return successResult("Pressed key: \(key)")
    }

    // MARK: - Accessibility Tree (with heuristic pruning for 70-80% token reduction)

    private func captureAXTree() async -> [[String: Any]] {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return []
        }

        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "Unknown"

        let treeJSON = AXorcistBridge.shared.walkTree(pid: pid)

        guard let data = treeJSON.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [["app": appName, "pid": Int(pid)]]
        }

        // Heuristic pruning: keep only interactive elements + their labels.
        // Raw AX tree = 15k-60k tokens; pruned = 200-500 tokens (per research).
        var elementCounter = 0
        let pruned = parsed.compactMap { node -> [String: Any]? in
            pruneInteractiveOnly(node, counter: &elementCounter)
        }

        return pruned
    }

    /// Prunes AX tree to interactive elements only, assigning @eN element IDs
    /// for deterministic targeting (no pixel coordinate guessing needed).
    private func pruneInteractiveOnly(_ node: [String: Any], counter: inout Int) -> [String: Any]? {
        let role = (node["role"] as? String) ?? ""

        // Interactive roles worth keeping
        let interactiveRoles: Set<String> = [
            "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXCheckBox",
            "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
            "AXMenuItem", "AXMenuBarItem", "AXTab", "AXToolbar",
            "AXList", "AXTable", "AXOutline", "AXScrollBar",
        ]

        let isInteractive = interactiveRoles.contains(role)

        // Recursively prune children
        var prunedChildren: [[String: Any]] = []
        if let children = node["children"] as? [[String: Any]] {
            for child in children {
                if let pruned = pruneInteractiveOnly(child, counter: &counter) {
                    prunedChildren.append(pruned)
                }
            }
        }

        // Keep this node if it's interactive OR has interactive descendants
        guard isInteractive || !prunedChildren.isEmpty else {
            return nil
        }

        counter += 1
        var result: [String: Any] = [
            "elementID": "@e\(counter)",
            "role": role,
        ]

        // Include label/title/value if present
        if let title = node["title"] as? String, !title.isEmpty {
            result["label"] = title
        }
        if let value = node["value"] as? String, !value.isEmpty {
            result["value"] = value
        }
        if let desc = node["description"] as? String, !desc.isEmpty {
            result["description"] = desc
        }

        // Include position for click targeting
        if let x = node["x"] as? Double, let y = node["y"] as? Double,
           x.isFinite, y.isFinite {
            result["x"] = Int(x)
            result["y"] = Int(y)
        }
        if let w = node["width"] as? Double, let h = node["height"] as? Double,
           w.isFinite, h.isFinite {
            result["width"] = Int(w)
            result["height"] = Int(h)
        }

        if !prunedChildren.isEmpty {
            result["children"] = prunedChildren
        }

        return result
    }

    private func getAccessibilityTree(appName: String?) async -> String {
        let tree: [[String: Any]]

        if let name = appName {
            // Find app by name
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.localizedName?.lowercased().contains(name.lowercased()) == true
            }
            if let app = apps.first {
                let treeJSON = AXorcistBridge.shared.walkTree(pid: app.processIdentifier)
                if let data = treeJSON.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    tree = parsed
                } else {
                    tree = []
                }
            } else {
                return errorResult("App '\(name)' not found")
            }
        } else {
            tree = await captureAXTree()
        }

        let result: [String: Any] = [
            "success": true,
            "elements": tree,
            "count": tree.count,
        ]
        return jsonString(result)
    }

    // MARK: - Image Utilities

    private func scaleImage(_ image: CGImage, maxWidth: Int, maxHeight: Int) -> CGImage {
        let width = image.width
        let height = image.height

        if width <= maxWidth && height <= maxHeight {
            return image
        }

        guard width > 0, height > 0 else { return image }

        let scaleX = CGFloat(maxWidth) / CGFloat(width)
        let scaleY = CGFloat(maxHeight) / CGFloat(height)
        let scale = min(scaleX, scaleY)

        guard scale.isFinite else { return image }

        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }

    private func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    // MARK: - Result Helpers

    private func successResult(_ message: String) -> String {
        jsonString(["success": true, "message": message])
    }

    private func errorResult(_ message: String) -> String {
        jsonString(["success": false, "error": message])
    }

    private func jsonString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"success\": false, \"error\": \"JSON serialization failed\"}"
        }
        return str
    }
}
