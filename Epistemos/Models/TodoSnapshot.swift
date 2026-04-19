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
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Only `write` / `merge` produce a plan; `list` / `clear` aren't
        // list-snapshots in the same sense.
        let action = (obj["action"] as? String)?.lowercased() ?? "write"
        switch action {
        case "write", "merge":
            break
        case "clear":
            return TodoSnapshot(items: [], capturedAt: Date())
        default:
            return nil
        }

        guard let rawArray = obj["todos"] as? [[String: Any]] else {
            return nil
        }

        let parsed: [TodoSnapshotItem] = rawArray.enumerated().compactMap { idx, entry in
            guard let content = (entry["content"] as? String)?.trimmingCharacters(in: .whitespaces),
                  !content.isEmpty else {
                return nil
            }
            let statusRaw = (entry["status"] as? String)?.lowercased() ?? "pending"
            let status = TodoStatus(rawValue: statusRaw) ?? .pending
            let id = (entry["id"] as? String) ?? "todo-\(idx)"
            let activeForm = (entry["active_form"] as? String)?
                .trimmingCharacters(in: .whitespaces)
                .nonEmpty ?? content
            return TodoSnapshotItem(
                id: id,
                content: content,
                activeForm: activeForm,
                status: status
            )
        }

        return TodoSnapshot(items: parsed, capturedAt: Date())
    }
}

struct TodoSnapshotItem: Equatable, Sendable, Identifiable {
    let id: String
    let content: String
    let activeForm: String
    let status: TodoStatus
}

enum TodoStatus: String, Sendable, Equatable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
