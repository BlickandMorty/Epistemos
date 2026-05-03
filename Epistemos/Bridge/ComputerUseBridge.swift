#if !EPISTEMOS_APP_STORE
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
    typealias AccessibilityPermissionProvider = @MainActor () -> Bool
    typealias TrustedActionExecutor = @MainActor (String, [String: Any]) async -> String

    static let shared = ComputerUseBridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "ComputerUse")
    private let accessibilityPermissionProvider: AccessibilityPermissionProvider
    private let trustedActionExecutor: TrustedActionExecutor?
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var toolCallSequence: UInt64 = 0

    init(
        accessibilityPermissionProvider: @escaping AccessibilityPermissionProvider = {
            AXIsProcessTrusted()
        },
        trustedActionExecutor: TrustedActionExecutor? = nil,
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.accessibilityPermissionProvider = accessibilityPermissionProvider
        self.trustedActionExecutor = trustedActionExecutor
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    // MARK: - Execute Computer Action

    /// Executes a computer use action and returns the result as a JSON string.
    /// Called by ChatCoordinator when Rust agent's "computer" tool fires.
    func execute(actionJSON: String) async -> String {
        let parsedAction = parseComputerAction(actionJSON: actionJSON)
        let toolCallID = nextToolCallID()
        recordComputerActionEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: parsedAction.request
        )

        guard let data = actionJSON.data(using: .utf8),
              let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            recordComputerActionEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedAction.request,
                failureClass: "invalid_action_json",
                errorMessage: "Computer action was not accepted."
            )
            return errorResult("Invalid action JSON")
        }

        let action = (input["action"] as? String) ?? "screenshot"

        // Check TCC permissions before any action
        guard accessibilityPermissionProvider() else {
            recordComputerActionEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedAction.request,
                failureClass: "accessibility_permission_denied",
                errorMessage: "Computer action requires Accessibility permission."
            )
            return errorResult("Accessibility permission not granted. Open System Settings > Privacy & Security > Accessibility.")
        }

        recordComputerActionEvent(
            toolCallID: toolCallID,
            kind: .toolCallStarted,
            status: .started,
            request: parsedAction.request
        )

        let start = Date()
        let result = if let trustedActionExecutor {
            await trustedActionExecutor(action, input)
        } else {
            await executeTrustedAction(action: action, input: input)
        }
        let sanitizedResult = parseComputerActionResult(
            result,
            actionClass: parsedAction.request.actionClass
        )
        recordComputerActionEvent(
            toolCallID: toolCallID,
            kind: sanitizedResult.success ? .toolCallCompleted : .toolCallFailed,
            status: sanitizedResult.success ? .completed : .failed,
            request: parsedAction.request,
            result: sanitizedResult.success ? sanitizedResult : nil,
            durationMs: durationMilliseconds(since: start),
            failureClass: sanitizedResult.success ? nil : sanitizedResult.failureClass,
            errorMessage: sanitizedResult.success ? nil : "Computer action failed."
        )
        return result
    }

    private func executeTrustedAction(action: String, input: [String: Any]) async -> String {
        let action = action.trimmingCharacters(in: .whitespacesAndNewlines)

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

    // MARK: - AgentEvent provenance

    private struct ParsedComputerAction {
        let request: ComputerActionRequest
    }

    private struct ComputerActionRequest {
        let actionClass: String
        let coordinateBucket: String?
        let textLengthBucket: String?
        let directionClass: String?
        let keyClass: String?
        let appScope: String?
    }

    private struct ComputerActionResult {
        let success: Bool
        let resultClass: String
        let screenshotIncluded: Bool
        let accessibilityElementCount: Int?
        let failureClass: String?
    }

    private func nextToolCallID() -> String {
        let sequence = toolCallSequence
        if toolCallSequence < UInt64.max {
            toolCallSequence += 1
        }
        return "computer-use-bridge-\(sequence)"
    }

    private func parseComputerAction(actionJSON: String) -> ParsedComputerAction {
        guard let data = actionJSON.data(using: .utf8),
              let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedComputerAction(
                request: ComputerActionRequest(
                    actionClass: "invalid_json",
                    coordinateBucket: nil,
                    textLengthBucket: nil,
                    directionClass: nil,
                    keyClass: nil,
                    appScope: nil
                )
            )
        }

        return ParsedComputerAction(request: computerActionRequest(input: input))
    }

    private func computerActionRequest(input: [String: Any]) -> ComputerActionRequest {
        let actionClass = computerActionClass(input["action"] as? String)
        return ComputerActionRequest(
            actionClass: actionClass,
            coordinateBucket: coordinateBucket(x: input["x"] as? Int, y: input["y"] as? Int),
            textLengthBucket: textLengthBucket(input["text"] as? String),
            directionClass: directionClass(input["direction"] as? String),
            keyClass: actionClass == "key" ? keyClass(input["text"] as? String) : nil,
            appScope: appScope(input["app_name"] as? String)
        )
    }

    private func computerActionClass(_ rawAction: String?) -> String {
        switch rawAction?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case nil, "", "screenshot":
            return "screenshot"
        case "click":
            return "click"
        case "type_text":
            return "type"
        case "scroll":
            return "scroll"
        case "get_ax_tree":
            return "ax_tree"
        case "key_press":
            return "key"
        default:
            return "unknown"
        }
    }

    private func coordinateBucket(x: Int?, y: Int?) -> String? {
        guard let x, let y else { return nil }
        let bucketSize = 100
        return "\(x / bucketSize * bucketSize)-\(y / bucketSize * bucketSize)"
    }

    private func textLengthBucket(_ text: String?) -> String? {
        guard let text else { return nil }
        switch text.count {
        case 0:
            return "0"
        case 1...16:
            return "1_16"
        case 17...64:
            return "17_64"
        default:
            return "65_plus"
        }
    }

    private func directionClass(_ direction: String?) -> String? {
        switch direction?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "up":
            return "up"
        case "down":
            return "down"
        case "left":
            return "left"
        case "right":
            return "right"
        case nil, "":
            return nil
        default:
            return "unknown"
        }
    }

    private func keyClass(_ key: String?) -> String {
        switch key?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "return", "enter", "tab", "space", "delete", "escape", "esc":
            return "editing"
        case "up", "down", "left", "right":
            return "navigation"
        case nil, "":
            return "empty"
        default:
            return "other"
        }
    }

    private func appScope(_ appName: String?) -> String? {
        guard let appName,
              !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "specific"
    }

    private func parseComputerActionResult(_ resultJSON: String, actionClass: String) -> ComputerActionResult {
        guard let data = resultJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ComputerActionResult(
                success: false,
                resultClass: "invalid_result_json",
                screenshotIncluded: false,
                accessibilityElementCount: nil,
                failureClass: "invalid_result_json"
            )
        }

        let success = payload["success"] as? Bool == true
        if success {
            return ComputerActionResult(
                success: true,
                resultClass: resultClass(actionClass: actionClass, payload: payload),
                screenshotIncluded: payload["screenshot_base64"] != nil,
                accessibilityElementCount: accessibilityElementCount(payload),
                failureClass: nil
            )
        }

        return ComputerActionResult(
            success: false,
            resultClass: "failed",
            screenshotIncluded: false,
            accessibilityElementCount: nil,
            failureClass: failureClass(error: payload["error"] as? String)
        )
    }

    private func resultClass(actionClass: String, payload: [String: Any]) -> String {
        if payload["screenshot_base64"] != nil {
            return "screenshot_with_ax_tree"
        }
        if payload["elements"] != nil {
            return "ax_tree"
        }
        switch actionClass {
        case "click", "type", "scroll", "key":
            return "input_action"
        default:
            return "completed"
        }
    }

    private func accessibilityElementCount(_ payload: [String: Any]) -> Int? {
        if let elements = payload["elements"] as? [[String: Any]] {
            return elements.count
        }
        if let tree = payload["accessibility_tree"] as? [[String: Any]] {
            return tree.count
        }
        return nil
    }

    private func failureClass(error: String?) -> String {
        let error = error?.lowercased() ?? ""
        if error.contains("accessibility permission") {
            return "accessibility_permission_denied"
        }
        if error.contains("unknown action") {
            return "unsupported_action"
        }
        if error.contains("no display") {
            return "display_unavailable"
        }
        if error.contains("screenshot failed") {
            return "screenshot_failed"
        }
        if error.contains("encode screenshot") {
            return "screenshot_encoding_failed"
        }
        if error.contains("not found") {
            return "app_unavailable"
        }
        return "computer_action_failed"
    }

    private func durationMilliseconds(since start: Date) -> UInt64? {
        let elapsed = Int(Date().timeIntervalSince(start) * 1_000)
        return elapsed >= 0 ? UInt64(elapsed) : nil
    }

    private func recordComputerActionEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: ComputerActionRequest,
        result: ComputerActionResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "computer-use-bridge",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "computer-use-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "computer.\(request.actionClass)",
            argumentsJSON: computerActionArgumentsJSON(request),
            resultJSON: result.map(computerActionResultJSON),
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: computerActionMetadata(request: request, result: result, failureClass: failureClass)
        )
    }

    private func computerActionArgumentsJSON(_ request: ComputerActionRequest) -> String {
        var payload: [String: Any] = [
            "action_class": request.actionClass,
        ]
        if let coordinateBucket = request.coordinateBucket {
            payload["coordinate_bucket"] = coordinateBucket
        }
        if let textLengthBucket = request.textLengthBucket {
            payload["text_length_bucket"] = textLengthBucket
        }
        if let directionClass = request.directionClass {
            payload["direction_class"] = directionClass
        }
        if let keyClass = request.keyClass {
            payload["key_class"] = keyClass
        }
        if let appScope = request.appScope {
            payload["app_scope"] = appScope
        }
        return jsonString(payload)
    }

    private func computerActionResultJSON(_ result: ComputerActionResult) -> String {
        var payload: [String: Any] = [
            "success": result.success,
            "result_class": result.resultClass,
            "screenshot_included": result.screenshotIncluded,
        ]
        if let accessibilityElementCount = result.accessibilityElementCount {
            payload["accessibility_element_count"] = accessibilityElementCount
        }
        return jsonString(payload)
    }

    private func computerActionMetadata(
        request: ComputerActionRequest,
        result: ComputerActionResult?,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "computer_use_bridge",
            "surface": "computer_use",
            "action_class": request.actionClass,
        ]
        if let result {
            metadata["result_class"] = result.resultClass
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
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
#endif
