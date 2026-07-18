#if EPISTEMOS_APP_STORE
import Foundation

nonisolated enum JuneGatewayError: LocalizedError {
    case cloudNotConfigured
    case cloudConsentRequired(provider: String, destination: String)
    case modelPreparing(String)

    var errorDescription: String? {
        switch self {
        case .cloudNotConfigured:
            return "Cloud access is not configured. Add an OpenAI or Anthropic API key in June Settings."
        case .cloudConsentRequired(let provider, let destination):
            return "Cloud data consent is off for \(provider). Open June Settings, review the \(destination) disclosure, and enable consent before retrying. Nothing was sent."
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
        } else if let number = rawValue as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
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
        } else if let int = rawValue as? Int {
            guard abs(Double(int)) <= Self.maxSafeNumericMagnitude else { return nil }
            self = .int(int)
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
        error.localizedDescription
    }
}
#endif
