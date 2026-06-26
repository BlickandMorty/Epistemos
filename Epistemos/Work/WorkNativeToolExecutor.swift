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
    /// Tool names in catalog.rs `category "computer"` — routed to `ComputerUseBridge`, not the Rust FFI base.
    /// (Distinct from `category "automation"`: get_ui_tree/click_element/type_text/press_key/run_shortcut, which
    /// go the base/FFI path like every other Rust-side tool.)
    static let computerToolNames: Set<String> = ["see", "click", "type", "scroll", "keys", "screenshot"]

    /// Compose the executor the MCP server runs: computer-use → ComputerUseBridge; everything else → `base`.
    static func composed(base: @escaping LocalAgentToolExecutor) -> LocalAgentToolExecutor {
        return { @Sendable name, argumentsJson in
            guard computerToolNames.contains(name) else {
                return await base(name, argumentsJson)
            }
            let actionJSON = computerActionJSON(name: name, argumentsJson: argumentsJson)
            let result = await executeComputerAction(actionJSON: actionJSON)
            return LocalToolResult(toolName: name, resultJson: result, isError: isErrorResult(result))
        }
    }

    /// Hop to the main actor to run the @MainActor `ComputerUseBridge`.
    @MainActor
    private static func executeComputerAction(actionJSON: String) async -> String {
        await ComputerUseBridge.shared.execute(actionJSON: actionJSON)
    }

    /// `ComputerUseBridge.execute` parses a single `"action"`-keyed object; the MCP catalog exposes see/click/type/…
    /// as SEPARATE tools. Fold the tool name in as `"action"` while preserving the caller's args.
    static func computerActionJSON(name: String, argumentsJson: String) -> String {
        var object = (try? JSONSerialization.jsonObject(with: Data(argumentsJson.utf8))) as? [String: Any] ?? [:]
        object["action"] = name
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"action":"\#(name)"}"#
        }
        return json
    }

    /// `ComputerUseBridge.errorResult` returns `{"success":false,"error":…}`; treat that as an MCP `isError`.
    static func isErrorResult(_ result: String) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: Data(result.utf8))) as? [String: Any] else {
            return false
        }
        if let success = object["success"] as? Bool { return !success }
        return object["error"] != nil
    }
}
