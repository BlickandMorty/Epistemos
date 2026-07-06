#if EPISTEMOS_APP_STORE
import Foundation

/// Engine-lane model ids surfaced through June's own model picker
/// (`list_venice_models` / `set_venice_model` / per-session `session.create`
/// model param). Capability truth (Plan 1-MAS §0.5): local = chat tier (no
/// function-calling capability advertised — June's own `modelSupportsTools`
/// gates on it); full agentic tools arrive with the cloud lane.
nonisolated enum JuneModelID {
    static let appleFM = "epistemos.apple-fm"
    static let localGGUF = "epistemos.local-gguf"
    static let cloud = "epistemos.cloud"
}

nonisolated enum JuneGatewayError: LocalizedError {
    case cloudNotConfigured
    case modelPreparing(String)

    var errorDescription: String? {
        switch self {
        case .cloudNotConfigured:
            return "Cloud access is not configured. Connect OpenAI or Anthropic in Settings, or pick an on-device model."
        case .modelPreparing(let detail):
            return detail
        }
    }
}

nonisolated enum JuneGatewayReplyID: Sendable {
    private static let maxStringBytes = 256
    private static let maxSafeNumericMagnitude = 9_007_199_254_740_991.0

    case string(String)
    case int(Int)
    case double(Double)
    case null

    init?(rawValue: Any?) {
        guard let rawValue, !(rawValue is NSNull) else {
            self = .null
            return
        }
        if let string = rawValue as? String {
            guard string.utf8.count <= Self.maxStringBytes else { return nil }
            self = .string(string)
        } else if rawValue is Bool {
            return nil
        } else if let int = rawValue as? Int {
            guard abs(Double(int)) <= Self.maxSafeNumericMagnitude else { return nil }
            self = .int(int)
        } else if let number = rawValue as? NSNumber {
            let double = number.doubleValue
            guard double.isFinite,
                  abs(double) <= Self.maxSafeNumericMagnitude else { return nil }
            if double.rounded(.towardZero) == double,
               double >= Double(Int.min),
               double <= Double(Int.max) {
                self = .int(number.intValue)
            } else {
                self = .double(double)
            }
        } else {
            return nil
        }
    }

    var jsonValue: Any? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .null:
            return nil
        }
    }
}

nonisolated struct PersistedToolCall: Encodable, Sendable {
    let id: String
    let toolCallID: String
    let name: String
    let toolName: String
    let arguments: String

    enum CodingKeys: String, CodingKey {
        case id
        case toolCallID = "tool_call_id"
        case name
        case toolName = "tool_name"
        case arguments
    }
}

nonisolated struct PersistedToolResult: Sendable {
    let id: String
    let name: String
    let content: String
}

nonisolated enum JuneEngineErrorText {
    static func describe(_ error: Error) -> String {
        if let quickChat = error as? QuickChatError {
            switch quickChat {
            case .guardrailBlocked:
                return "The on-device model declined this request."
            case .exceededContextWindow:
                return "This conversation is too long for the on-device model. Start a new chat."
            case .engineUnavailable(let reason):
                return reason.userCopy
            case .generationFailed(let detail):
                return "The on-device model failed to answer (\(detail))."
            }
        }
        return error.localizedDescription
    }
}
#endif
