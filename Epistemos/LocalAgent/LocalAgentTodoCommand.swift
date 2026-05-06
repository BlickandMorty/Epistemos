import Foundation

/// Native parser for LocalAgent-compatible `/todo` slash commands.
///
/// This keeps the user-facing LocalAgent command shape while routing Core-safe task
/// state into the existing Rust `todo` ledger instead of inventing a parallel
/// Swift task store.
nonisolated struct LocalAgentTodoCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case list
        case add(content: String)
        case done(id: String)
        case clear
    }

    let action: Action

    var toolName: String { "todo" }

    var requiresApproval: Bool {
        action == .clear
    }

    static func parse(_ rawCommand: String) -> LocalAgentTodoCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/todo" || trimmed.hasPrefix("/todo ") else {
            return nil
        }

        let remainder = trimmed
            .dropFirst("/todo".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else {
            return LocalAgentTodoCommand(action: .list)
        }

        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let verb = parts.first?.lowercased() else {
            return LocalAgentTodoCommand(action: .list)
        }
        let argument = parts.dropFirst()
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch verb {
        case "list":
            return argument.isEmpty ? LocalAgentTodoCommand(action: .list) : nil
        case "add":
            return argument.isEmpty ? nil : LocalAgentTodoCommand(action: .add(content: argument))
        case "done":
            return argument.isEmpty ? nil : LocalAgentTodoCommand(action: .done(id: argument))
        case "clear":
            return argument.isEmpty ? LocalAgentTodoCommand(action: .clear) : nil
        default:
            return nil
        }
    }

    func toolInputJSON(generatedID: String = UUID().uuidString) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data: Data
        switch action {
        case .list:
            data = try encoder.encode(ListPayload())
        case .add(let content):
            data = try encoder.encode(AddPayload(
                id: generatedID,
                content: content,
                activeForm: content
            ))
        case .done(let id):
            data = try encoder.encode(DonePayload(id: id))
        case .clear:
            data = try encoder.encode(ClearPayload())
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                data,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Unable to encode LocalAgent todo command as UTF-8 JSON"
                )
            )
        }
        return json
    }
}

private nonisolated struct ListPayload: Encodable {
    let action = "list"
}

private nonisolated struct AddPayload: Encodable {
    let action = "add"
    let id: String
    let content: String
    let activeForm: String

    enum CodingKeys: String, CodingKey {
        case action
        case id
        case content
        case activeForm = "active_form"
    }
}

private nonisolated struct DonePayload: Encodable {
    let action = "done"
    let id: String
}

private nonisolated struct ClearPayload: Encodable {
    let action = "clear"
}
