import Foundation

// MARK: - Hermes Notebook Commands
//
// Core-native parsers for the notebook-row commands declared in
// HermesCapabilityRegistry: /notebook, /notebook list, /notebook clear,
// /notebook open <name>. Each maps to the existing Epistemos vault /
// notebook surface; the dispatch site reads the intent and routes.
//
// `/notebook clear` is destructive and requires approval per the
// registry. Read variants are Trivial.

nonisolated struct HermesNotebookCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case showCurrent              // /notebook
        case list                     // /notebook list
        case clear                    // /notebook clear (destructive)
        case open(name: String)       // /notebook open <name>
    }

    let action: Action

    var requiresApproval: Bool {
        switch action {
        case .clear: return true
        default:     return false
        }
    }

    static func parse(_ rawCommand: String) -> HermesNotebookCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/notebook" || trimmed.hasPrefix("/notebook ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/notebook".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if arg.isEmpty {
            return HermesNotebookCommand(action: .showCurrent)
        }

        let parts = arg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let verb = parts[0].lowercased()
        let argument = parts.count > 1
            ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        switch verb {
        case "list":
            return argument.isEmpty ? HermesNotebookCommand(action: .list) : nil
        case "clear":
            return argument.isEmpty ? HermesNotebookCommand(action: .clear) : nil
        case "open":
            return argument.isEmpty ? nil : HermesNotebookCommand(action: .open(name: argument))
        default:
            // Bare /notebook <name> → treat as open, mirroring /persona <name>.
            return HermesNotebookCommand(action: .open(name: arg))
        }
    }
}
