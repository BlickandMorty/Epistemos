import Foundation

/// Snapshot of the agent's current todo list as published by the Rust
/// `todo` tool (agent_core/src/tools/todo.rs). Parsed out of a
/// `todo_write` tool call's input JSON so the Swift UI can surface the
/// plan live above the chat composer — the user sees the model checking
/// items off instead of having to expand individual tool cards.
struct TodoSnapshot: Equatable, Sendable {
    let items: [TodoSnapshotItem]
    let capturedAt: Date

    var isEmpty: Bool { items.isEmpty }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var inProgressItem: TodoSnapshotItem? {
        items.first { $0.status == .inProgress }
    }

    /// Parse a `todo_write` / `todo` tool call's inputJson payload.
    /// Returns nil on malformed input or an unsupported action.
    static func fromToolInput(_ inputJson: String) -> TodoSnapshot? {
        guard let data = inputJson.data(using: .utf8),
              let payload = try? JSONDecoder().decode(TodoToolInputPayload.self, from: data) else {
            return nil
        }

        // Only `write` / `merge` produce a plan; `list` / `clear` aren't
        // list-snapshots in the same sense.
        switch payload.action {
        case .write, .merge:
            break
        case .clear:
            return TodoSnapshot(items: [], capturedAt: Date())
        }

        guard let todos = payload.todos else {
            return nil
        }

        let parsed: [TodoSnapshotItem] = todos.enumerated().compactMap { idx, entry in
            guard let content = entry.content?
                .trimmingCharacters(in: .whitespaces)
                .nonEmpty else {
                return nil
            }
            let activeForm = entry.activeForm?
                .trimmingCharacters(in: .whitespaces)
                .nonEmpty ?? content
            return TodoSnapshotItem(
                id: entry.id ?? "todo-\(idx)",
                content: content,
                activeForm: activeForm,
                status: entry.status ?? .pending
            )
        }

        return TodoSnapshot(items: parsed, capturedAt: Date())
    }
}

private struct TodoToolInputPayload: Decodable {
    let action: TodoAction
    let todos: [TodoInputItem]?

    enum CodingKeys: String, CodingKey {
        case action
        case todos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decodeIfPresent(TodoAction.self, forKey: .action) ?? .write
        todos = try container.decodeIfPresent([TodoInputItem].self, forKey: .todos)
    }
}

private enum TodoAction: String, Decodable {
    case write
    case merge
    case clear

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        guard let action = TodoAction(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported todo action: \(rawValue)"
            )
        }
        self = action
    }
}

private struct TodoInputItem: Decodable {
    let id: String?
    let content: String?
    let activeForm: String?
    let status: TodoStatus?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case activeForm = "active_form"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        activeForm = try? container.decodeIfPresent(String.self, forKey: .activeForm)
        status = (try? container.decodeIfPresent(TodoStatus.self, forKey: .status)) ?? nil
    }
}

struct TodoSnapshotItem: Equatable, Sendable, Identifiable {
    let id: String
    let content: String
    let activeForm: String
    let status: TodoStatus
}

enum TodoStatus: String, Sendable, Equatable, Decodable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        self = TodoStatus(rawValue: rawValue) ?? .pending
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
