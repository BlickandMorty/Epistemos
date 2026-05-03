import Foundation

/// Native parser for Hermes-compatible `/todo` slash commands.
///
/// This keeps the user-facing Hermes command shape while routing Core-safe task
/// state into the existing Rust `todo` ledger instead of inventing a parallel
/// Swift task store.
nonisolated struct HermesTodoCommand: Equatable, Sendable {
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

    static func parse(_ rawCommand: String) -> HermesTodoCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/todo" || trimmed.hasPrefix("/todo ") else {
            return nil
        }

        let remainder = trimmed
            .dropFirst("/todo".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else {
            return HermesTodoCommand(action: .list)
        }

        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let verb = parts.first?.lowercased() else {
            return HermesTodoCommand(action: .list)
        }
        let argument = parts.dropFirst()
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch verb {
        case "list":
            return argument.isEmpty ? HermesTodoCommand(action: .list) : nil
        case "add":
            return argument.isEmpty ? nil : HermesTodoCommand(action: .add(content: argument))
        case "done":
            return argument.isEmpty ? nil : HermesTodoCommand(action: .done(id: argument))
        case "clear":
            return argument.isEmpty ? HermesTodoCommand(action: .clear) : nil
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
                    debugDescription: "Unable to encode Hermes todo command as UTF-8 JSON"
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
