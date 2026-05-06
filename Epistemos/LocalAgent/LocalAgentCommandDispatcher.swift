import Foundation

// MARK: - LocalAgent Command Dispatcher
//
// Single entry point that takes any raw `/...` slash command, tries
// every Core-native parser in order, and returns a typed
// `LocalAgentParsedCommand` if exactly one matches. Returns `.unknown`
// for anything that doesn't match a Core command.
//
// **What this is.** A pure deterministic router — no provider call,
// no I/O, no network, no subprocess. Doctrine §A.7 action class:
// Trivial. Approval is delegated to the per-command `requiresApproval`
// computed property; the dispatcher merely surfaces the intent.
//
// **What this is NOT.** Not the executor. Each branch carries the
// parsed command; the chat surface decides how to act on it. This
// keeps the dispatcher Core-safe and unit-testable.

/// Sum type covering every Core-native parsed command. Add a new
/// variant whenever a new command lands; `parseCore` automatically
/// picks it up via the matching parser.
nonisolated enum LocalAgentParsedCommand: Equatable, Sendable {
    case ask(question: String)
    case append(LocalAgentAppendCommand)
    case calc(LocalAgentCalcCommand)
    case clear(LocalAgentClearCommand)
    case colors(LocalAgentColorsCommand)
    case compact(LocalAgentCompactCommand)
    case configShow(LocalAgentConfigShowCommand)
    case cost(LocalAgentCostCommand)
    case export(LocalAgentExportCommand)
    case font(LocalAgentFontCommand)
    case fontsize(LocalAgentFontSizeCommand)
    case grep(LocalAgentGrepCommand)
    case help(LocalAgentHelpCommand)
    case load(LocalAgentLoadCommand)
    case ls(LocalAgentLsCommand)
    case memory(LocalAgentMemoryCommand)
    case mode(LocalAgentModeCommand)
    case model(LocalAgentModelCommand)
    case newSession(LocalAgentNewSessionCommand)
    case notebook(LocalAgentNotebookCommand)
    case parameter(LocalAgentParameterCommand)
    case persona(LocalAgentPersonaCommand)
    case read(LocalAgentReadCommand)
    case save(LocalAgentSaveCommand)
    case search(LocalAgentSearchCommand)
    case status(LocalAgentStatusCommand)
    case summary(LocalAgentSummaryCommand)
    case systemPrompt(LocalAgentSystemPromptCommand)
    case theme(LocalAgentThemeCommand)
    case think(LocalAgentThinkCommand)
    case todo(LocalAgentTodoCommand)
    case tokens(LocalAgentTokensCommand)
    case toolsToggle(LocalAgentToolsToggleCommand)
    case uiToggle(LocalAgentUIToggleCommand)
    case width(LocalAgentWidthCommand)
    case write(LocalAgentWriteCommand)

    /// Whether this parsed command needs explicit user approval before
    /// the dispatch site executes it. Mirrors each command's own
    /// `requiresApproval` flag for a uniform call-site check.
    nonisolated var requiresApproval: Bool {
        switch self {
        case .ask:                                 return false
        case .append(let c):                       return c.requiresApproval
        case .calc(let c):                         return c.requiresApproval
        case .clear(let c):                        return c.requiresApproval
        case .colors(let c):                       return c.requiresApproval
        case .compact(let c):                      return c.requiresApproval
        case .configShow(let c):                   return c.requiresApproval
        case .cost(let c):                         return c.requiresApproval
        case .export(let c):                       return c.requiresApproval
        case .font(let c):                         return c.requiresApproval
        case .fontsize(let c):                     return c.requiresApproval
        case .grep(let c):                         return c.requiresApproval
        case .help(let c):                         return c.requiresApproval
        case .load(let c):                         return c.requiresApproval
        case .ls(let c):                           return c.requiresApproval
        case .memory(let c):                       return c.requiresApproval
        case .mode(let c):                         return c.requiresApproval
        case .model(let c):                        return c.requiresApproval
        case .newSession(let c):                   return c.requiresApproval
        case .notebook(let c):                     return c.requiresApproval
        case .parameter(let c):                    return c.requiresApproval
        case .persona(let c):                      return c.requiresApproval
        case .read(let c):                         return c.requiresApproval
        case .save(let c):                         return c.requiresApproval
        case .search(let c):                       return c.requiresApproval
        case .status(let c):                       return c.requiresApproval
        case .summary(let c):                      return c.requiresApproval
        case .systemPrompt(let c):                 return c.requiresApproval
        case .theme(let c):                        return c.requiresApproval
        case .think(let c):                        return c.requiresApproval
        case .todo(let c):                         return c.requiresApproval
        case .tokens(let c):                       return c.requiresApproval
        case .toolsToggle(let c):                  return c.requiresApproval
        case .uiToggle(let c):                     return c.requiresApproval
        case .width(let c):                        return c.requiresApproval
        case .write(let c):                        return c.requiresApproval
        }
    }
}

nonisolated enum LocalAgentCommandDispatcher {

    /// Try every Core-native parser in order; return the first match.
    /// Returns `nil` for anything that does not start with a `/`. Returns
    /// `nil` for slash-prefixed input that no parser claims (the chat
    /// surface treats that as "unknown command, render help").
    static func parseCore(_ rawCommand: String) -> LocalAgentParsedCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        // Order matters where prefixes overlap (e.g., /persona vs.
        // /persona list). Each parser internally distinguishes its
        // sub-shapes, but we still try the most-specific first when the
        // command-namespace allows multiple parsers to match the same
        // prefix (we don't have that case yet, but the order below is
        // the safe default).

        if let cmd = LocalAgentAskCommand.parse(trimmed)         { return .ask(question: cmd.question) }
        if let cmd = LocalAgentAppendCommand.parse(trimmed)      { return .append(cmd) }
        if let cmd = LocalAgentCalcCommand.parse(trimmed)        { return .calc(cmd) }
        if let cmd = LocalAgentClearCommand.parse(trimmed)       { return .clear(cmd) }
        if let cmd = LocalAgentColorsCommand.parse(trimmed)      { return .colors(cmd) }
        if let cmd = LocalAgentCompactCommand.parse(trimmed)     { return .compact(cmd) }
        if let cmd = LocalAgentConfigShowCommand.parse(trimmed)  { return .configShow(cmd) }
        if let cmd = LocalAgentCostCommand.parse(trimmed)        { return .cost(cmd) }
        if let cmd = LocalAgentExportCommand.parse(trimmed)      { return .export(cmd) }
        if let cmd = LocalAgentFontCommand.parse(trimmed)        { return .font(cmd) }
        if let cmd = LocalAgentFontSizeCommand.parse(trimmed)    { return .fontsize(cmd) }
        if let cmd = LocalAgentGrepCommand.parse(trimmed)        { return .grep(cmd) }
        if let cmd = LocalAgentHelpCommand.parse(trimmed)        { return .help(cmd) }
        if let cmd = LocalAgentLoadCommand.parse(trimmed)        { return .load(cmd) }
        if let cmd = LocalAgentLsCommand.parse(trimmed)          { return .ls(cmd) }
        if let cmd = LocalAgentMemoryCommand.parse(trimmed)      { return .memory(cmd) }
        if let cmd = LocalAgentModeCommand.parse(trimmed)        { return .mode(cmd) }
        if let cmd = LocalAgentModelCommand.parse(trimmed)       { return .model(cmd) }
        if let cmd = LocalAgentNewSessionCommand.parse(trimmed)  { return .newSession(cmd) }
        if let cmd = LocalAgentNotebookCommand.parse(trimmed)    { return .notebook(cmd) }
        if let cmd = LocalAgentParameterCommand.parse(trimmed)   { return .parameter(cmd) }
        if let cmd = LocalAgentPersonaCommand.parse(trimmed)     { return .persona(cmd) }
        if let cmd = LocalAgentReadCommand.parse(trimmed)        { return .read(cmd) }
        if let cmd = LocalAgentSaveCommand.parse(trimmed)        { return .save(cmd) }
        if let cmd = LocalAgentSearchCommand.parse(trimmed)      { return .search(cmd) }
        if let cmd = LocalAgentStatusCommand.parse(trimmed)      { return .status(cmd) }
        if let cmd = LocalAgentSummaryCommand.parse(trimmed)     { return .summary(cmd) }
        if let cmd = LocalAgentSystemPromptCommand.parse(trimmed) { return .systemPrompt(cmd) }
        if let cmd = LocalAgentThemeCommand.parse(trimmed)       { return .theme(cmd) }
        if let cmd = LocalAgentThinkCommand.parse(trimmed)       { return .think(cmd) }
        if let cmd = LocalAgentTodoCommand.parse(trimmed)        { return .todo(cmd) }
        if let cmd = LocalAgentTokensCommand.parse(trimmed)      { return .tokens(cmd) }
        if let cmd = LocalAgentToolsToggleCommand.parse(trimmed) { return .toolsToggle(cmd) }
        if let cmd = LocalAgentUIToggleCommand.parse(trimmed)    { return .uiToggle(cmd) }
        if let cmd = LocalAgentWidthCommand.parse(trimmed)       { return .width(cmd) }
        if let cmd = LocalAgentWriteCommand.parse(trimmed)       { return .write(cmd) }

        return nil
    }
}

// MARK: - /ask passthrough wrapper
//
// Inline mini-parser for the `/ask <question>` registry entry — the
// only Core command not previously implemented as its own struct.
// Native chat surface treats /ask the same as a bare prompt, so the
// command just unwraps the question text. Trivial action class.

nonisolated struct LocalAgentAskCommand: Equatable, Sendable {
    let question: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentAskCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/ask" || trimmed.hasPrefix("/ask ") else { return nil }
        let body = trimmed.dropFirst("/ask".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return LocalAgentAskCommand(question: body)
    }
}
