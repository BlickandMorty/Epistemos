import Foundation

// W-R3 increment (b) (2026-06-24): composes the PRODUCTION `LocalAgentToolExecutor` that backs the app-hosted
// native-tools MCP (`WorkNativeMCPServer` → `WorkToolMCPCore`). This is what makes "every native tool expressed
// to OpenCode" actually EXECUTE (not merely appear in `tools/list`):
//   - computer-category tools (see/click/type/scroll/keys/screenshot) → `ComputerUseBridge` (the @MainActor
//     ScreenCaptureKit/AXorcist/CGEvent stack), translated to the bridge's single `"action"`-keyed JSON shape;
//   - everything else (vault/graph/file/git/web/…) → the injected `base` executor (production =
//     `ToolTierBridge.toolExecutor()` → Rust `execute_tool_call` FFI).
// This closes the gap omega_mcp_stdio can't: that Rust stdio server can only run Rust-side tools, so Swift-side
// computer-use returns an honest error there. Here computer-use runs IN-PROCESS, so the OpenCode agent can drive
// the full native surface.
//
// `ComputerUseBridge` exposes the SAME `.shared.execute(actionJSON:) async -> String` API in BOTH the real build
// (`#if !EPISTEMOS_APP_STORE`, ComputerUseBridge.swift) and the AppStore stub (AppStoreComputerUseStubs.swift,
// which returns "automation denied") — so ONE code path serves both builds; no `#if` here.
//
// RUNTIME-PROOF-OWED: the live computer-use path needs TCC Accessibility + a real screen + OpenCode driving it
// (owner runs). The pure shaping/routing helpers below are unit-tested.
nonisolated enum WorkNativeToolExecutor {
    /// Work MCP computer-use tools routed to `ComputerUseBridge`, not the Rust FFI base.
    /// Distinct from Rust-side automation tools such as get_ui_tree/click_element/type_text/press_key/run_shortcut.
    static let computerToolNames: Set<String> = ["see", "click", "type", "scroll", "keys", "screenshot"]
    private static let bridgeActionByToolName: [String: String] = [
        "see": "screenshot",
        "click": "click",
        "type": "type_text",
        "scroll": "scroll",
        "screenshot": "screenshot",
    ]
    private static let supportedKeyPresses: Set<String> = [
        "return", "enter", "tab", "space", "delete", "escape", "esc", "up", "down", "left", "right",
    ]
    private static let maxCoordinateMagnitude = 1_000_000
    static let toolDefinitions: [OmegaToolDefinition] = [
        OmegaToolDefinition(
            name: "see",
            agent: "computer",
            description: "Capture the current screen with a pruned accessibility tree for native computer-use tasks.",
            argumentsExample: #"{"app_name":"Finder"}"#,
            schemaJson: #"{"type":"object","properties":{"app_name":{"type":"string","description":"Optional running app name to scope accessibility context."},"app":{"type":"string","description":"Compatibility alias for app_name."}}}"#,
            destructive: false,
            requiresConfirmation: false
        ),
        OmegaToolDefinition(
            name: "screenshot",
            agent: "computer",
            description: "Capture the current screen and accessibility tree.",
            argumentsExample: "{}",
            schemaJson: #"{"type":"object","properties":{}}"#,
            destructive: false,
            requiresConfirmation: false
        ),
        OmegaToolDefinition(
            name: "click",
            agent: "computer",
            description: "Click a screen coordinate through the native computer-use bridge.",
            argumentsExample: #"{"x":120,"y":300}"#,
            schemaJson: #"{"type":"object","properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]}"#,
            destructive: true,
            requiresConfirmation: true
        ),
        OmegaToolDefinition(
            name: "type",
            agent: "computer",
            description: "Type text through the native computer-use bridge.",
            argumentsExample: #"{"text":"hello"}"#,
            schemaJson: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#,
            destructive: true,
            requiresConfirmation: true
        ),
        OmegaToolDefinition(
            name: "scroll",
            agent: "computer",
            description: "Scroll at a screen coordinate through the native computer-use bridge.",
            argumentsExample: #"{"x":500,"y":500,"direction":"down"}"#,
            schemaJson: #"{"type":"object","properties":{"x":{"type":"integer"},"y":{"type":"integer"},"direction":{"type":"string","enum":["up","down","left","right"]}},"required":["x","y"]}"#,
            destructive: true,
            requiresConfirmation: true
        ),
        OmegaToolDefinition(
            name: "keys",
            agent: "computer",
            description: "Press one supported navigation/editing key or type a text key sequence through the native computer-use bridge.",
            argumentsExample: #"{"key":"return"}"#,
            schemaJson: #"{"type":"object","properties":{"key":{"type":"string","description":"Supported named key: return, enter, tab, space, delete, escape, up, down, left, or right."},"keys":{"anyOf":[{"type":"string","description":"Text to type."},{"type":"array","items":{"type":"string"},"description":"One supported named key or multiple single-character text tokens."}]},"text":{"type":"string","description":"Text to type."},"modifiers":{"type":"array","items":{"type":"string"},"maxItems":0,"description":"Modifier shortcuts are not supported by this bridge; pass an empty array or omit."}}}"#,
            destructive: true,
            requiresConfirmation: true
        ),
    ]

    /// Compose the executor the MCP server runs: computer-use → ComputerUseBridge; everything else → `base`.
    static func composed(base: @escaping LocalAgentToolExecutor) -> LocalAgentToolExecutor {
        return { @Sendable name, argumentsJson in
            let canonicalName = AgentToolNameAliases.canonical(name)
            guard computerToolNames.contains(canonicalName) else {
                return await base(name, argumentsJson)
            }
            let actionJSON: String
            switch computerActionPlan(name: canonicalName, argumentsJson: argumentsJson) {
            case .run(let json):
                actionJSON = json
            case .reject(let message):
                return LocalToolResult(
                    toolName: canonicalName,
                    resultJson: errorResultJSON(message),
                    isError: true
                )
            }
            let result = await executeComputerAction(actionJSON: actionJSON)
            return LocalToolResult(
                toolName: canonicalName,
                resultJson: result,
                isError: ToolOutputErrorClassifier.isError(toolName: canonicalName, outputJson: result)
            )
        }
    }

    /// Computer-use removed with the Omega lane (cloud-only build): `ComputerUseBridge`
    /// no longer exists, so this returns an unavailable result. (Work/OpenCode itself
    /// is kept; only its dead computer-use tool ref is stubbed.)
    @MainActor
    private static func executeComputerAction(actionJSON: String) async -> String {
        _ = actionJSON
        return "{\"success\":false,\"error\":\"computer action unavailable\"}"
    }

    /// `ComputerUseBridge.execute` parses a single `"action"`-keyed object; the MCP catalog exposes see/click/type/…
    /// as SEPARATE tools. Fold the tool name in as `"action"` while preserving the caller's args.
    static func computerActionJSON(name: String, argumentsJson: String) -> String {
        switch computerActionPlan(name: name, argumentsJson: argumentsJson) {
        case .run(let json):
            return json
        case .reject(let message):
            return unsupportedActionJSON(message)
        }
    }

    private static func computerActionPlan(name: String, argumentsJson: String) -> ComputerActionPlan {
        guard var object = argumentsObject(argumentsJson) else {
            return .reject("The Work MCP computer-use tools require JSON object arguments.")
        }
        let canonicalName = AgentToolNameAliases.canonical(name)
        guard computerToolNames.contains(canonicalName) else {
            return .reject("Unsupported Work MCP computer-use tool.")
        }
        normalizeCommonComputerActionArguments(object: &object)
        switch canonicalName {
        case "click":
            return coordinateActionPlan(object, action: "click")
        case "scroll":
            return scrollActionPlan(object)
        case "type":
            return typeActionPlan(object)
        case "keys":
            return keyboardActionPlan(object)
        default:
            let action = bridgeActionByToolName[canonicalName] ?? canonicalName
            object["action"] = action
            return .run(serializedActionJSON(object, fallbackAction: action))
        }
    }

    private static func argumentsObject(_ argumentsJson: String) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(argumentsJson.utf8)) else {
            return nil
        }
        return object as? [String: Any]
    }

    private enum ComputerActionPlan {
        case run(String)
        case reject(String)
    }

    private static func normalizeCommonComputerActionArguments(object: inout [String: Any]) {
        if object["app_name"] == nil, let app = object["app"] as? String {
            object["app_name"] = app
        }
    }

    private static func coordinateActionPlan(_ source: [String: Any], action: String) -> ComputerActionPlan {
        var object = source
        guard normalizeCoordinatePair(in: &object) else {
            return .reject("The Work MCP \(action) tool requires integer x and y coordinates.")
        }
        object["action"] = action
        return .run(serializedActionJSON(object, fallbackAction: action))
    }

    private static func scrollActionPlan(_ source: [String: Any]) -> ComputerActionPlan {
        var object = source
        guard normalizeCoordinatePair(in: &object) else {
            return .reject("The Work MCP scroll tool requires integer x and y coordinates.")
        }
        if let direction = trimmedString(object["direction"]) {
            let normalized = direction.lowercased()
            guard ["up", "down", "left", "right"].contains(normalized) else {
                return .reject("The Work MCP scroll direction must be up, down, left, or right.")
            }
            object["direction"] = normalized
        }
        object["action"] = "scroll"
        return .run(serializedActionJSON(object, fallbackAction: "scroll"))
    }

    private static func typeActionPlan(_ source: [String: Any]) -> ComputerActionPlan {
        var object = source
        guard let text = object["text"] as? String, !text.isEmpty else {
            return .reject("The Work MCP type tool requires non-empty text.")
        }
        object["action"] = "type_text"
        object["text"] = text
        return .run(serializedActionJSON(object, fallbackAction: "type_text"))
    }

    private static func keyboardActionPlan(_ object: [String: Any]) -> ComputerActionPlan {
        if let modifierProblem = keyboardModifierProblem(in: object) {
            return .reject(modifierProblem)
        }

        if let key = trimmedString(object["key"]) {
            return keyOrTextActionPlan(key, source: object)
        }
        if let keys = object["keys"] as? [Any] {
            return keysArrayActionPlan(keys, source: object)
        }
        if let keys = trimmedString(object["keys"]) {
            return textActionPlan(keys, source: object)
        }
        if let text = trimmedString(object["text"]) {
            return textActionPlan(text, source: object)
        }

        return .reject("The Work MCP keys tool requires key, keys, or text.")
    }

    private static func keysArrayActionPlan(_ keys: [Any], source: [String: Any]) -> ComputerActionPlan {
        var values: [String] = []
        values.reserveCapacity(keys.count)
        for key in keys {
            guard let value = trimmedString(key) else {
                return .reject("The Work MCP keys array must contain only non-empty strings.")
            }
            values.append(value)
        }
        guard !values.isEmpty else {
            return .reject("The Work MCP keys tool requires at least one non-empty key.")
        }
        if values.count == 1 {
            return keyOrTextActionPlan(values[0], source: source)
        }
        guard values.allSatisfy({ $0.count == 1 }) else {
            return .reject("The Work MCP keys tool cannot execute multiple named key presses in one call.")
        }
        return textActionPlan(values.joined(), source: source)
    }

    private static func keyOrTextActionPlan(_ value: String, source: [String: Any]) -> ComputerActionPlan {
        if supportedKeyPresses.contains(value.lowercased()) {
            return keyPressActionPlan(value, source: source)
        }
        return textActionPlan(value, source: source)
    }

    private static func keyPressActionPlan(_ key: String, source: [String: Any]) -> ComputerActionPlan {
        var object = source
        object["action"] = "key_press"
        object["text"] = key
        return .run(serializedActionJSON(object, fallbackAction: "key_press"))
    }

    private static func textActionPlan(_ text: String, source: [String: Any]) -> ComputerActionPlan {
        var object = source
        object["action"] = "type_text"
        object["text"] = text
        return .run(serializedActionJSON(object, fallbackAction: "type_text"))
    }

    private static func keyboardModifierProblem(in object: [String: Any]) -> String? {
        if let modifiers = object["modifiers"] {
            if let array = modifiers as? [Any], array.isEmpty {
                return nil
            }
            return "The Work MCP keys tool does not support modifier shortcuts through ComputerUseBridge yet."
        }

        if object["modifier"] != nil {
            return "The Work MCP keys tool does not support modifier shortcuts through ComputerUseBridge yet."
        }
        return nil
    }

    private static func normalizeCoordinatePair(in object: inout [String: Any]) -> Bool {
        guard let x = integer(object["x"]),
              let y = integer(object["y"]) else {
            return false
        }
        object["x"] = x
        object["y"] = y
        return true
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            guard int >= 0,
                  int <= maxCoordinateMagnitude else {
                return nil
            }
            return int
        case is Bool:
            return nil
        case let number as NSNumber:
            let objectType = String(cString: number.objCType)
            guard objectType != "c", objectType != "B" else { return nil }
            let double = number.doubleValue
            guard double.isFinite,
                  double.rounded(.towardZero) == double,
                  double >= 0,
                  double <= Double(maxCoordinateMagnitude) else {
                return nil
            }
            let int = Int(double)
            guard Double(int) == double else { return nil }
            return int
        case let string as String:
            guard let int = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)),
                  int >= 0,
                  int <= maxCoordinateMagnitude else {
                return nil
            }
            return int
        default:
            return nil
        }
    }

    private static func trimmedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func serializedActionJSON(_ object: [String: Any], fallbackAction: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"action":"\#(fallbackAction)"}"#
        }
        return json
    }

    private static func errorResultJSON(_ message: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [
            "success": false,
            "error": message,
        ]),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"success":false,"error":"Computer-use action failed."}"#
        }
        return json
    }

    private static func unsupportedActionJSON(_ message: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [
            "action": "unsupported",
            "error": message,
        ]),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"action":"unsupported"}"#
        }
        return json
    }
}
