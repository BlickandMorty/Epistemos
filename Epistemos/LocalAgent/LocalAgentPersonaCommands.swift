import Foundation

// MARK: - LocalAgent Persona Commands
//
// Core-native parsers + intent for the persona-row commands declared
// in LocalAgentCapabilityRegistry. Each is a parser; the dispatch site
// reads the intent and calls the matching native persona service.
//
// Doctrine §A.7 action class: Sensitive (15-min grace) for any state
// mutation (create/edit/delete/import/export). Read operations are
// Trivial.

nonisolated struct LocalAgentPersonaCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case showCurrent                       // /persona
        case list                              // /persona list
        case switchTo(name: String)            // /persona <name>
        case create(name: String)              // /persona create <name>
        case edit(name: String)                // /persona edit <name>
        case delete(name: String)              // /persona delete <name>
        case export(name: String)              // /persona export <name>
        case importFrom(filePath: String)      // /persona import <file>
        case info(name: String)                // /persona info <name>
    }

    let action: Action

    /// Read operations are Trivial; mutations require approval per the
    /// Sensitive action class.
    var requiresApproval: Bool {
        switch action {
        case .showCurrent, .list, .info, .switchTo:
            return false
        case .create, .edit, .delete, .export, .importFrom:
            return true
        }
    }

    static func parse(_ rawCommand: String) -> LocalAgentPersonaCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/persona" || trimmed.hasPrefix("/persona ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/persona".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if arg.isEmpty {
            return LocalAgentPersonaCommand(action: .showCurrent)
        }

        // Verb? Or bare name?
        let parts = arg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let verb = parts[0].lowercased()
        let argument = parts.count > 1
            ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        switch verb {
        case "list":
            return argument.isEmpty
                ? LocalAgentPersonaCommand(action: .list)
                : nil
        case "create":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .create(name: argument))
        case "edit":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .edit(name: argument))
        case "delete":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .delete(name: argument))
        case "export":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .export(name: argument))
        case "import":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .importFrom(filePath: argument))
        case "info":
            return argument.isEmpty ? nil : LocalAgentPersonaCommand(action: .info(name: argument))
        default:
            // Bare /persona <name> — treat as switchTo. Persona names with
            // spaces are not supported (would clash with verbs); for those
            // the user can quote at the dispatch site.
            return LocalAgentPersonaCommand(action: .switchTo(name: arg))
        }
    }
}
