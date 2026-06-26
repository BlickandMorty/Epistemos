import Foundation

// Native model for an OpenGUI/OpenCode PERMISSION request (visual-target item "native permission/tool cards"). The
// OpenGUI sidecar forwards `harness.on("event")` events (SEPARATE from the LiveSessionEvent stream) as
// `HarnessEvent { type:"permission.requested", request: PermissionRequest }` (src/agents/backend.ts) where
// `PermissionInteractionRequest` (src/protocol/session-transcript.ts) is:
//   { id, sessionID, permission, patterns[], metadata?, always?[], tool?{messageID,callID} }
// opencode only EMITS these when its config gates a tool to "ask" (default = permissive/auto-approve — see the Work
// ledger); the provisioner will opt sensitive tools into "ask" ONLY once the full sidecar→supervisor→card→respond path
// lands (setting "ask" without handling HANGS the agent). This is the pure, lenient, testable REQUEST model + decoder;
// the sidecar forwarding + `respondPermission` wire values (opencode decisions allow_once/allow_always/reject_once) land
// with the supervisor/sidecar slice.

struct WorkPermissionRequest: Identifiable, Sendable, Equatable {
    let id: String
    let harnessID: String?       // source OpenGUI harness; reply must route back here, not the currently selected picker row
    let sessionID: String
    let permission: String        // the permission/tool key being requested (e.g. "bash", "edit", or a wildcard)
    let patterns: [String]        // the specific patterns this request covers (e.g. the command / path)
    let alwaysOptions: [String]   // "always allow" candidates (the request's `always`)
    let toolCallID: String?       // the tool call that triggered it (request.tool.callID), for correlating to a tool card

    /// Compact human subtitle for the card — the specific thing being permitted (falls back to the permission key).
    var detail: String { patterns.isEmpty ? permission : patterns.joined(separator: ", ") }
}

/// The user's decision on a permission card. Wire-value mapping to opencode (allow_once/allow_always/reject_once) is
/// applied where the sidecar `respondPermission` command is built — kept out of this pure UI model on purpose.
enum WorkPermissionDecision: Sendable, Equatable, CaseIterable {
    case allowOnce, allowAlways, reject
}

enum WorkPermissionRequestDecoder {
    /// Decode a permission request from the sidecar. Accepts the harness-event envelope
    /// `{type:"permission.requested", request:{…}}` (or `{event:{…}}` wrappers) OR a bare request object. Lenient:
    /// returns nil only when the essential `id`/`sessionID`/`permission` are absent. Never throws.
    static func decode(_ data: Data?) -> WorkPermissionRequest? {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return decode(any: root)
    }

    static func decode(any: Any) -> WorkPermissionRequest? {
        guard let object = requestObject(from: any) else { return nil }
        guard let id = object["id"] as? String, !id.isEmpty,
              let permission = object["permission"] as? String, !permission.isEmpty else { return nil }
        let harnessID = (object["harnessId"] as? String) ?? (object["harnessID"] as? String)
        guard let sessionID = (object["sessionID"] as? String) ?? (object["sessionId"] as? String),
              !sessionID.isEmpty else { return nil }
        let patterns = (object["patterns"] as? [String]) ?? []
        let alwaysOptions = (object["always"] as? [String]) ?? []
        let tool = object["tool"] as? [String: Any]
        let toolCallID = (tool?["callID"] as? String) ?? (tool?["callId"] as? String)
        return WorkPermissionRequest(
            id: id, harnessID: harnessID, sessionID: sessionID, permission: permission,
            patterns: patterns, alwaysOptions: alwaysOptions, toolCallID: toolCallID)
    }

    /// Dig to the request object: a bare request (has `permission`), else the `request` field, else inside `event`.
    private static func requestObject(from any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            if dict["permission"] != nil, dict["id"] != nil { return dict }      // bare request
            if let request = dict["request"] as? [String: Any] { return requestObject(from: request) }
            if let event = dict["event"] { return requestObject(from: event) }   // {event:{…}} envelope
        }
        return nil
    }
}
