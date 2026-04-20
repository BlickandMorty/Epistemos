import Foundation
import AppKit
import AXorcist
import CoreGraphics

// MARK: - Ghost Computer Agent

/// Ghost OS-style computer use agent using AXorcist for AX queries
/// and omega-ax for input simulation.
///
/// Tools: see, click, type, scroll, keys, screenshot
///
/// AX-first design: uses AXorcist fuzzy matching for element discovery,
/// falls back to coordinate-based CGEvent for input when semantic
/// targeting is unavailable.
@MainActor
final class GhostComputerAgent: OmegaAgent, Sendable {
    let name = "computer"
    let description = "Ghost OS-style macOS computer use via AXorcist accessibility and input simulation"
    let toolNames = ["see", "click", "type", "scroll", "keys", "screenshot"]

    private let screenCapture: ScreenCaptureService
    private let perception: Screen2AXFusion

    init(screenCapture: ScreenCaptureService, perception: Screen2AXFusion? = nil) {
        self.screenCapture = screenCapture
        self.perception = perception ?? Screen2AXFusion(screenCapture: screenCapture)
    }

    func execute(step: AgentStep) async throws -> AgentStepResult {
        let start = ContinuousClock.now

        // Pre-flight: ensure macOS Accessibility permission is granted.
        // Without it, AX queries silently return empty trees and all
        // element targeting fails with no useful error.
        guard AXorcistBridge.shared.hasAccessibilityPermissions else {
            return .fail(
                "Accessibility permission not granted. Open System Settings → Privacy & Security → Accessibility and enable Epistemos. Without this, the agent cannot see or interact with UI elements.",
                stepId: step.id,
                durationMs: 0
            )
        }

        guard let args = try? JSONSerialization.jsonObject(with: Data(step.argumentsJson.utf8)) as? [String: Any] else {
            return .fail("Invalid arguments JSON", stepId: step.id, durationMs: 0)
        }

        let resultJson: String
        switch step.toolName {
        case "see":
            resultJson = await executeSee(args: args)
        case "click":
            resultJson = executeClick(args: args)
        case "type":
            resultJson = executeType(args: args)
        case "scroll":
            resultJson = executeScroll(args: args)
        case "keys":
            resultJson = executeKeys(args: args)
        case "screenshot":
            resultJson = await executeScreenshot(args: args)
        default:
            return .fail("Unknown tool: \(step.toolName)", stepId: step.id, durationMs: 0)
        }

        let elapsed = UInt64(start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000)
        return .ok(resultJson, stepId: step.id, durationMs: elapsed, confidence: 0.9)
    }

    // MARK: - see

    /// View the AX tree using AX-first with Vision OCR fallback.
    /// Uses Screen2AXFusion perception pipeline:
    /// 1. AXorcist tree walk (covers ~90% of apps)
    /// 2. If sparse (<10 interactive), enrich with Apple Vision OCR
    /// Pass "quick": true for AX-only mode (no Vision fallback).
    private func executeSee(args: [String: Any]) async -> String {
        let quick = args["quick"] as? Bool ?? false

        // Quick mode: AX-only via AXorcist (used for verify loops)
        if quick {
            let pid = resolvePID(from: args)
            guard pid > 0 else {
                return "{\"success\":false,\"error\":\"Could not resolve app — provide 'app' or 'pid'\"}"
            }
            return AXorcistBridge.shared.walkTree(pid: pid_t(pid))
        }

        // Full perception: AX-first + Vision OCR fallback
        guard let appName = args["app"] as? String else {
            let pid = resolvePID(from: args)
            guard pid > 0 else {
                return "{\"success\":false,\"error\":\"Could not resolve app — provide 'app' or 'pid'\"}"
            }
            return AXorcistBridge.shared.walkTree(pid: pid_t(pid))
        }

        let result = await perception.perceive(appName: appName)
        return result.axTreeJson
    }

    // MARK: - click

    /// Click using AXorcist fuzzy match or coordinate fallback.
    ///
    /// Multi-strategy targeting when title match fails (stale element / UI redraw):
    /// 1. Title match via AXorcist fuzzy `.contains`
    /// 2. Re-query AX tree and retry title match (handles refresh lag)
    /// 3. Description fallback (element relabeled but description stable)
    /// 4. Role-based search returning top interactive alternatives so the
    ///    agent can self-correct on its next turn
    private func executeClick(args: [String: Any]) -> String {
        // Semantic click: find element by title via AXorcist
        if let elementName = args["element"] as? String {
            if let bundleID = resolveBundleID(from: args) {
                // Strategy 1: Direct title match
                let response = AXorcistBridge.shared.pressElement(
                    bundleID: bundleID,
                    title: elementName
                )
                if case .success = response {
                    return "{\"success\":true,\"method\":\"AXorcist-press\",\"element\":\"\(safeJsonString(elementName))\"}"
                }

                // Strategy 2: Re-query (AX tree may have refreshed since last call)
                let retryResponse = AXorcistBridge.shared.pressElement(
                    bundleID: bundleID,
                    title: elementName
                )
                if case .success = retryResponse {
                    return "{\"success\":true,\"method\":\"AXorcist-press-retry\",\"element\":\"\(safeJsonString(elementName))\"}"
                }

                // Strategy 3: Description fallback — UI may have relabeled the
                // element (e.g. "Submit" → "Submitting...") but the AXDescription
                // often stays stable.
                let descResponse = AXorcistBridge.shared.findElements(
                    bundleID: bundleID,
                    title: elementName,
                    titleMatch: .contains,
                    maxResults: 1
                )
                if let resolvedTitle = Self.resolvedTitle(from: descResponse) {
                    let pressDesc = AXorcistBridge.shared.pressElement(
                        bundleID: bundleID,
                        title: resolvedTitle
                    )
                    if case .success = pressDesc {
                        return "{\"success\":true,\"method\":\"AXorcist-description-fallback\",\"element\":\"\(safeJsonString(elementName))\"}"
                    }
                }

                // Strategy 4: Collect nearby interactive alternatives so the
                // agent can pick the right element on its next turn instead
                // of failing blind.
                let alternatives = gatherAlternatives(bundleID: bundleID, originalTitle: elementName)
                if !alternatives.isEmpty {
                    return "{\"success\":false,\"error\":\"Element '\(safeJsonString(elementName))' not found (UI may have redrawn). Try one of these instead.\",\"alternatives\":\(alternatives)}"
                }
            }

            // Fallback to omega-ax semantic click
            let pid = resolvePID(from: args)
            if pid > 0 {
                return clickElementByName(pid: Int64(pid), elementName: elementName)
            }

            return "{\"success\":false,\"error\":\"Could not resolve app for semantic click\"}"
        }

        // Coordinate click via omega-ax CGEvent
        if let x = args["x"] as? Double, let y = args["y"] as? Double {
            return simulateClick(x: x, y: y)
        }

        return "{\"success\":false,\"error\":\"click requires 'element' name or 'x'/'y' coordinates\"}"
    }

    /// Gather up to 5 interactive elements from the app as click alternatives.
    /// Returns a JSON array string the agent can inspect to self-correct.
    private func gatherAlternatives(bundleID: String, originalTitle: String) -> String {
        let pid = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .processIdentifier ?? -1
        guard pid > 0 else { return "[]" }

        let treeJson = AXorcistBridge.shared.walkTree(pid: pid)
        guard let data = treeJson.data(using: .utf8),
              let tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = tree["elements"] as? [[String: Any]] else {
            return "[]"
        }

        // Filter to interactive elements with non-empty titles
        let interactive = elements.filter {
            ($0["is_interactive"] as? Bool) == true &&
            !(($0["title"] as? String)?.isEmpty ?? true)
        }

        // Sort by title similarity to original (Levenshtein-like: shared prefix length)
        let lowerOriginal = originalTitle.lowercased()
        let sorted = interactive.sorted { a, b in
            let aTitle = (a["title"] as? String ?? "").lowercased()
            let bTitle = (b["title"] as? String ?? "").lowercased()
            let aScore = aTitle.commonPrefix(with: lowerOriginal).count
            let bScore = bTitle.commonPrefix(with: lowerOriginal).count
            return aScore > bScore
        }

        let top = sorted.prefix(5).map { elem -> [String: Any] in
            [
                "title": elem["title"] as? String ?? "",
                "role": elem["role"] as? String ?? "",
                "description": elem["description"] as? String ?? "",
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: top),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }
        return jsonStr
    }

    /// Escape a string for safe embedding in JSON string values.
    private func safeJsonString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func resolvedTitle(from response: AXResponse) -> String? {
        guard case let .success(payload, _) = response else { return nil }
        return resolvedTitle(from: payload)
    }

    private static func resolvedTitle(from payload: Any?) -> String? {
        guard let payload else { return nil }

        if let string = payload as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let dict = payload as? [String: Any] {
            if let title = stringValue(dict["title"]) {
                return title
            }
            if let description = stringValue(dict["description"]) {
                return description
            }
            if let elements = dict["elements"] as? [[String: Any]] {
                for element in elements {
                    if let title = stringValue(element["title"]) {
                        return title
                    }
                    if let description = stringValue(element["description"]) {
                        return description
                    }
                }
            }
        }

        if let array = payload as? [[String: Any]] {
            for element in array {
                if let title = stringValue(element["title"]) {
                    return title
                }
                if let description = stringValue(element["description"]) {
                    return description
                }
            }
        }

        if let array = payload as? [Any] {
            for item in array {
                if let title = resolvedTitle(from: item) {
                    return title
                }
            }
        }

        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    // MARK: - type

    /// Type text via omega-ax CGEvent keyboard simulation.
    private func executeType(args: [String: Any]) -> String {
        guard let text = args["text"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'text' argument\"}"
        }
        return simulateTypeText(text: text)
    }

    // MARK: - scroll

    /// Scroll via CGEvent scroll wheel simulation.
    private func executeScroll(args: [String: Any]) -> String {
        guard let direction = args["direction"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'direction' (up/down/left/right)\"}"
        }

        let amount = (args["amount"] as? Int) ?? 3

        // Determine scroll deltas
        var deltaY: Int32 = 0
        var deltaX: Int32 = 0
        switch direction.lowercased() {
        case "up":    deltaY = Int32(amount)
        case "down":  deltaY = -Int32(amount)
        case "left":  deltaX = Int32(amount)
        case "right": deltaX = -Int32(amount)
        default:
            return "{\"success\":false,\"error\":\"Invalid direction: \(direction). Use up/down/left/right\"}"
        }

        // Create scroll wheel event via CoreGraphics
        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                   units: .line,
                                   wheelCount: 2,
                                   wheel1: deltaY,
                                   wheel2: deltaX,
                                   wheel3: 0) else {
            return "{\"success\":false,\"error\":\"Failed to create scroll event\"}"
        }

        // Move mouse to target position if coordinates provided
        if let x = args["x"] as? Double, let y = args["y"] as? Double {
            let point = CGPoint(x: x, y: y)
            event.location = point
        }

        event.post(tap: .cghidEventTap)

        return "{\"success\":true,\"direction\":\"\(direction)\",\"amount\":\(amount)}"
    }

    // MARK: - keys

    /// Press keyboard keys via omega-ax CGEvent key simulation.
    private func executeKeys(args: [String: Any]) -> String {
        guard let key = args["key"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'key' argument\"}"
        }

        let keyCode = resolveKeyCode(key)
        guard keyCode != UInt16.max else {
            return "{\"success\":false,\"error\":\"Unknown key: \(key)\"}"
        }

        // Build modifier flags
        var modFlags: UInt64 = 0
        if let modifiers = args["modifiers"] as? [String] {
            for mod in modifiers {
                switch mod.lowercased() {
                case "cmd", "command":   modFlags |= CGEventFlags.maskCommand.rawValue
                case "shift":            modFlags |= CGEventFlags.maskShift.rawValue
                case "option", "alt":    modFlags |= CGEventFlags.maskAlternate.rawValue
                case "control", "ctrl":  modFlags |= CGEventFlags.maskControl.rawValue
                default: break
                }
            }
        }

        return simulateKeyPress(keyCode: keyCode, modifiers: modFlags)
    }

    // MARK: - screenshot

    /// Capture screenshot via ScreenCaptureKit → SHM bridge.
    /// Swift owns TCC permissions; pixel data routes through shared memory.
    private func executeScreenshot(args: [String: Any]) async -> String {
        let bundleID: String?
        if let app = args["app"] as? String {
            bundleID = bundleIDForApp(named: app)
        } else {
            bundleID = nil
        }

        let image: CGImage?
        if let bundleID {
            image = await screenCapture.captureApp(bundleID: bundleID)
        } else {
            image = await screenCapture.captureFrontmostWindow()
        }

        guard let cgImage = image else {
            return "{\"success\":false,\"error\":\"Screenshot capture failed\"}"
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return "{\"success\":false,\"error\":\"PNG encoding failed\"}"
        }

        let width = cgImage.width
        let height = cgImage.height

        // Write PNG to shared memory — the agent reads via SHM_REF pointer.
        if pngData.count > 48 * 1024 {
            do {
                let shmRefJson = try ShmWriter.writePayload(
                    sessionId: "tcc_proxy",
                    data: pngData,
                    contentType: "image/png"
                )
                return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"shm_ref\":\(shmRefJson)}"
            } catch {
                return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"data_base64_length\":\(pngData.count * 4 / 3)}"
            }
        }

        let base64 = pngData.base64EncodedString()
        return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"data_base64\":\"\(base64)\"}"
    }

    // MARK: - Helpers

    private func resolvePID(from args: [String: Any]) -> Int64 {
        if let pid = args["pid"] as? Int { return Int64(pid) }
        if let pid = args["pid"] as? Int64 { return pid }
        if let appName = args["app"] as? String {
            return pidForApp(named: appName)
        }
        return -1
    }

    private func resolveBundleID(from args: [String: Any]) -> String? {
        if let app = args["app"] as? String {
            return bundleIDForApp(named: app)
        }
        if let pid = args["pid"] as? Int {
            return NSWorkspace.shared.runningApplications
                .first { $0.processIdentifier == Int32(pid) }?
                .bundleIdentifier
        }
        return nil
    }

    private func pidForApp(named name: String) -> Int64 {
        let lower = name.lowercased()
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName?.lowercased() == lower }) {
            return Int64(app.processIdentifier)
        }
        if let app = apps.first(where: { $0.localizedName?.lowercased().contains(lower) == true }) {
            return Int64(app.processIdentifier)
        }
        return -1
    }

    private func bundleIDForApp(named name: String) -> String? {
        let lower = name.lowercased()
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName?.lowercased() == lower }) {
            return app.bundleIdentifier
        }
        return apps.first(where: { $0.localizedName?.lowercased().contains(lower) == true })?.bundleIdentifier
    }

    /// Map named keys to macOS virtual key codes.
    private func resolveKeyCode(_ key: String) -> UInt16 {
        // Try parsing as integer first
        if let code = UInt16(key) { return code }

        switch key.lowercased() {
        case "return", "enter":  return 36
        case "tab":              return 48
        case "space":            return 49
        case "delete", "backspace": return 51
        case "escape", "esc":    return 53
        case "up":               return 126
        case "down":             return 125
        case "left":             return 123
        case "right":            return 124
        case "home":             return 115
        case "end":              return 119
        case "pageup":           return 116
        case "pagedown":         return 121
        case "f1":  return 122; case "f2":  return 120; case "f3":  return 99
        case "f4":  return 118; case "f5":  return 96;  case "f6":  return 97
        case "f7":  return 98;  case "f8":  return 100; case "f9":  return 101
        case "f10": return 109; case "f11": return 103; case "f12": return 111
        default:
            // Single character: look up by key equivalent
            if key.count == 1, let char = key.lowercased().unicodeScalars.first {
                return keyCodeForCharacter(char)
            }
            return UInt16.max
        }
    }

    /// Map common ASCII characters to virtual key codes.
    private func keyCodeForCharacter(_ char: Unicode.Scalar) -> UInt16 {
        switch char {
        case "a": return 0; case "b": return 11; case "c": return 8
        case "d": return 2; case "e": return 14; case "f": return 3
        case "g": return 5; case "h": return 4;  case "i": return 34
        case "j": return 38; case "k": return 40; case "l": return 37
        case "m": return 46; case "n": return 45; case "o": return 31
        case "p": return 35; case "q": return 12; case "r": return 15
        case "s": return 1;  case "t": return 17; case "u": return 32
        case "v": return 9;  case "w": return 13; case "x": return 7
        case "y": return 16; case "z": return 6
        case "0": return 29; case "1": return 18; case "2": return 19
        case "3": return 20; case "4": return 21; case "5": return 23
        case "6": return 22; case "7": return 26; case "8": return 28
        case "9": return 25
        default: return UInt16.max
        }
    }

    // MARK: - MCP Tool Adapters (for Hermes bridge)
    //
    // Static methods called by EpistemosMCPServer tool handlers.
    // These use the REAL Screen2AXFusion hybrid perception pipeline
    // and omega-ax FFI for input simulation — identical codepath
    // to the OmegaAgent execute() path.

    /// MCP adapter: see — AX-first hybrid perception via Screen2AXFusion.
    static func mcpSee(args: [String: Any]) async -> String {
        guard AXorcistBridge.shared.hasAccessibilityPermissions else {
            return "{\"success\":false,\"error\":\"Accessibility permission not granted. Enable Epistemos in System Settings > Privacy & Security > Accessibility.\"}"
        }

        // If app_name provided, use full Screen2AXFusion pipeline (AX + Vision OCR fallback)
        if let appName = args["app_name"] as? String ?? args["app"] as? String {
            let capture = ScreenCaptureService()
            let perception = Screen2AXFusion(screenCapture: capture)
            let result = await perception.perceive(appName: appName)
            return result.axTreeJson
        }

        // Otherwise, get frontmost app AX tree
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return "{\"success\":false,\"error\":\"No frontmost application\"}"
        }
        return AXorcistBridge.shared.walkTree(pid: frontApp.processIdentifier)
    }

    /// MCP adapter: click — AXorcist semantic targeting + omega-ax CGEvent fallback.
    static func mcpClick(args: [String: Any]) -> String {
        guard AXorcistBridge.shared.hasAccessibilityPermissions else {
            return "{\"success\":false,\"error\":\"Accessibility permission not granted.\"}"
        }

        // Semantic click by label
        if let label = args["label"] as? String ?? args["element"] as? String {
            // Resolve bundle ID from frontmost app or "app" param
            let bundleID: String?
            if let appName = args["app"] as? String {
                bundleID = NSWorkspace.shared.runningApplications
                    .first { $0.localizedName?.lowercased() == appName.lowercased() }?
                    .bundleIdentifier
                    ?? NSWorkspace.shared.runningApplications
                        .first { $0.localizedName?.lowercased().contains(appName.lowercased()) == true }?
                        .bundleIdentifier
            } else {
                bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            }

            if let bundleID {
                let response = AXorcistBridge.shared.pressElement(bundleID: bundleID, title: label)
                if case .success = response {
                    return "{\"success\":true,\"method\":\"AXorcist-press\",\"element\":\"\(mcpSafeJson(label))\"}"
                }

                // Retry with fuzzy contains match
                let fuzzyResponse = AXorcistBridge.shared.findElements(
                    bundleID: bundleID, title: label, titleMatch: .contains, maxResults: 1
                )
                if let resolvedTitle = Self.resolvedTitle(from: fuzzyResponse) {
                    let retryPress = AXorcistBridge.shared.pressElement(bundleID: bundleID, title: resolvedTitle)
                    if case .success = retryPress {
                        return "{\"success\":true,\"method\":\"AXorcist-fuzzy\",\"element\":\"\(mcpSafeJson(label))\"}"
                    }
                }
            }

            // Fallback to omega-ax PID-based click
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                return clickElementByName(pid: Int64(frontApp.processIdentifier), elementName: label)
            }

            return "{\"success\":false,\"error\":\"Could not find element '\(mcpSafeJson(label))'\"}"
        }

        // Coordinate click via omega-ax CGEvent
        if let x = args["x"] as? Double, let y = args["y"] as? Double {
            return simulateClick(x: x, y: y)
        }

        return "{\"success\":false,\"error\":\"click requires 'label' or 'x'/'y' coordinates\"}"
    }

    /// MCP adapter: type — omega-ax CGEvent keyboard simulation.
    static func mcpType(args: [String: Any]) -> String {
        guard let text = args["text"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'text' argument\"}"
        }
        return simulateTypeText(text: text)
    }

    /// MCP adapter: keys — Parse key combo string and simulate via CGEvent.
    static func mcpKeys(args: [String: Any]) -> String {
        guard let keys = args["keys"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'keys' argument\"}"
        }

        // Parse combo string like "cmd+shift+s" into key + modifiers
        let parts = keys.lowercased().split(separator: "+").map(String.init)
        guard let keyName = parts.last else {
            return "{\"success\":false,\"error\":\"Invalid key combo: \(keys)\"}"
        }

        let modParts = parts.dropLast()
        var modFlags: UInt64 = 0
        for mod in modParts {
            switch mod {
            case "cmd", "command": modFlags |= CGEventFlags.maskCommand.rawValue
            case "shift":          modFlags |= CGEventFlags.maskShift.rawValue
            case "option", "alt":  modFlags |= CGEventFlags.maskAlternate.rawValue
            case "ctrl", "control": modFlags |= CGEventFlags.maskControl.rawValue
            default: break
            }
        }

        let keyCode = mcpResolveKeyCode(keyName)
        guard keyCode != UInt16.max else {
            return "{\"success\":false,\"error\":\"Unknown key: \(keyName)\"}"
        }

        return simulateKeyPress(keyCode: keyCode, modifiers: modFlags)
    }

    /// MCP adapter: scroll — CGEvent scroll wheel simulation.
    static func mcpScroll(args: [String: Any]) -> String {
        guard let direction = args["direction"] as? String else {
            return "{\"success\":false,\"error\":\"Missing 'direction' (up/down/left/right)\"}"
        }

        let amount = (args["amount"] as? Int) ?? 3
        var deltaY: Int32 = 0
        var deltaX: Int32 = 0
        switch direction.lowercased() {
        case "up":    deltaY = Int32(amount)
        case "down":  deltaY = -Int32(amount)
        case "left":  deltaX = Int32(amount)
        case "right": deltaX = -Int32(amount)
        default:
            return "{\"success\":false,\"error\":\"Invalid direction: \(direction)\"}"
        }

        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                   wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else {
            return "{\"success\":false,\"error\":\"Failed to create scroll event\"}"
        }
        event.post(tap: .cghidEventTap)
        return "{\"success\":true,\"direction\":\"\(direction)\",\"amount\":\(amount)}"
    }

    /// MCP adapter: screenshot — ScreenCaptureKit capture via TCC Swift Proxy.
    ///
    /// The Swift @MainActor layer owns kTCCServiceScreenCapture permissions.
    /// Pixel data is captured natively, encoded to PNG, and written directly
    /// into POSIX shared memory via `shm_open`. Only the compact SHM_REF JSON
    /// pointer travels over the Unix socket — the Python daemon NEVER calls
    /// macOS TCC APIs or handles raw pixel buffers.
    static func mcpScreenshot(args: [String: Any], screenCapture: ScreenCaptureService?) async -> String {
        let capture = screenCapture ?? ScreenCaptureService()
        let target = args["target"] as? String ?? "window"

        let image: CGImage?
        if target == "screen" {
            image = await capture.captureDisplay()
        } else if let app = args["app"] as? String {
            image = await capture.captureApp(bundleID: app)
        } else {
            image = await capture.captureFrontmostWindow()
        }

        guard let cgImage = image else {
            return "{\"success\":false,\"error\":\"Screenshot capture failed — check Screen Recording permission\"}"
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return "{\"success\":false,\"error\":\"PNG encoding failed\"}"
        }

        let width = cgImage.width
        let height = cgImage.height

        // Route through SHM for payloads that would exceed the 64KB pipe buffer.
        // Small screenshots (e.g. tiny windows) pass through inline.
        if pngData.count > 48 * 1024 {
            do {
                let shmRefJson = try ShmWriter.writePayload(
                    sessionId: "tcc_proxy",
                    data: pngData,
                    contentType: "image/png"
                )
                return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"shm_ref\":\(shmRefJson)}"
            } catch {
                // Fallback to base64 if SHM fails (e.g. in test environments)
                let base64 = pngData.base64EncodedString()
                return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"data_base64\":\"\(base64)\"}"
            }
        }

        let base64 = pngData.base64EncodedString()
        return "{\"success\":true,\"width\":\(width),\"height\":\(height),\"format\":\"png\",\"data_base64\":\"\(base64)\"}"
    }

    // MARK: - MCP Static Helpers

    private static func mcpSafeJson(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func mcpResolveKeyCode(_ key: String) -> UInt16 {
        if let code = UInt16(key) { return code }
        switch key.lowercased() {
        case "return", "enter":    return 36
        case "tab":                return 48
        case "space":              return 49
        case "delete", "backspace": return 51
        case "escape", "esc":      return 53
        case "up":    return 126; case "down":  return 125
        case "left":  return 123; case "right": return 124
        case "home":  return 115; case "end":   return 119
        case "pageup": return 116; case "pagedown": return 121
        case "f1":  return 122; case "f2":  return 120; case "f3":  return 99
        case "f4":  return 118; case "f5":  return 96;  case "f6":  return 97
        case "f7":  return 98;  case "f8":  return 100; case "f9":  return 101
        case "f10": return 109; case "f11": return 103; case "f12": return 111
        default:
            if key.count == 1, let char = key.lowercased().unicodeScalars.first {
                return mcpKeyCodeForChar(char)
            }
            return UInt16.max
        }
    }

    private static func mcpKeyCodeForChar(_ char: Unicode.Scalar) -> UInt16 {
        switch char {
        case "a": return 0;  case "b": return 11; case "c": return 8
        case "d": return 2;  case "e": return 14; case "f": return 3
        case "g": return 5;  case "h": return 4;  case "i": return 34
        case "j": return 38; case "k": return 40; case "l": return 37
        case "m": return 46; case "n": return 45; case "o": return 31
        case "p": return 35; case "q": return 12; case "r": return 15
        case "s": return 1;  case "t": return 17; case "u": return 32
        case "v": return 9;  case "w": return 13; case "x": return 7
        case "y": return 16; case "z": return 6
        case "0": return 29; case "1": return 18; case "2": return 19
        case "3": return 20; case "4": return 21; case "5": return 23
        case "6": return 22; case "7": return 26; case "8": return 28
        case "9": return 25
        default: return UInt16.max
        }
    }
}
