import Foundation

nonisolated enum ToolOutputErrorClassifier {
    static func isError(toolName: String, outputJson: String) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: Data(outputJson.utf8))) as? [String: Any] else {
            return false
        }

        let canonicalName = AgentToolNameAliases.canonical(toolName)
        if canonicalName == "browser.complete_task" {
            return browserCompleteTaskIsError(object)
        }

        if hasErrorValue(object["error"]) {
            return true
        }
        if let success = object["success"] as? Bool {
            return !success
        }
        return false
    }

    private static func hasErrorValue(_ value: Any?) -> Bool {
        switch value {
        case nil:
            return false
        case is NSNull:
            return false
        case let string as String:
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let array as [Any]:
            return !array.isEmpty
        case let object as [String: Any]:
            return !object.isEmpty
        default:
            return true
        }
    }

    private static func browserCompleteTaskIsError(_ object: [String: Any]) -> Bool {
        if object["adapter_success"] as? Bool == false {
            return true
        }
        if object["task_success"] as? Bool == false {
            return true
        }
        if object["success"] as? Bool == false {
            return true
        }
        if hasErrorValue(object["error"]) || hasErrorValue(object["errors"]) {
            return true
        }
        if let status = (object["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           ["failed", "incomplete", "unknown"].contains(status) {
            return true
        }
        if object["task_success"] as? Bool == true || object["success"] as? Bool == true {
            return false
        }
        return true
    }
}
