import Foundation

// MARK: - Hermes Command Dispatcher
//
// Single entry point that takes any raw `/...` slash command, tries
// every Core-native parser in order, and returns a typed
// `HermesParsedCommand` if exactly one matches. Returns `.unknown`
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
nonisolated enum HermesParsedCommand: Equatable, Sendable {
    case ask(question: String)
    case append(HermesAppendCommand)
    case calc(HermesCalcCommand)
    case clear(HermesClearCommand)
    case colors(HermesColorsCommand)
    case compact(HermesCompactCommand)
    case configShow(HermesConfigShowCommand)
    case cost(HermesCostCommand)
    case export(HermesExportCommand)
    case font(HermesFontCommand)
    case fontsize(HermesFontSizeCommand)
    case grep(HermesGrepCommand)
    case help(HermesHelpCommand)
    case load(HermesLoadCommand)
    case ls(HermesLsCommand)
    case memory(HermesMemoryCommand)
    case mode(HermesModeCommand)
    case model(HermesModelCommand)
    case newSession(HermesNewSessionCommand)
    case notebook(HermesNotebookCommand)
    case parameter(HermesParameterCommand)
    case persona(HermesPersonaCommand)
    case read(HermesReadCommand)
    case save(HermesSaveCommand)
    case search(HermesSearchCommand)
    case status(HermesStatusCommand)
    case summary(HermesSummaryCommand)
    case systemPrompt(HermesSystemPromptCommand)
    case theme(HermesThemeCommand)
    case think(HermesThinkCommand)
    case todo(HermesTodoCommand)
    case tokens(HermesTokensCommand)
    case toolsToggle(HermesToolsToggleCommand)
    case uiToggle(HermesUIToggleCommand)
    case width(HermesWidthCommand)
    case write(HermesWriteCommand)

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

nonisolated enum HermesCommandDispatcher {

    /// Try every Core-native parser in order; return the first match.
    /// Returns `nil` for anything that does not start with a `/`. Returns
    /// `nil` for slash-prefixed input that no parser claims (the chat
    /// surface treats that as "unknown command, render help").
    static func parseCore(_ rawCommand: String) -> HermesParsedCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        // Order matters where prefixes overlap (e.g., /persona vs.
        // /persona list). Each parser internally distinguishes its
        // sub-shapes, but we still try the most-specific first when the
        // command-namespace allows multiple parsers to match the same
        // prefix (we don't have that case yet, but the order below is
        // the safe default).

        if let cmd = HermesAskCommand.parse(trimmed)         { return .ask(question: cmd.question) }
        if let cmd = HermesAppendCommand.parse(trimmed)      { return .append(cmd) }
        if let cmd = HermesCalcCommand.parse(trimmed)        { return .calc(cmd) }
        if let cmd = HermesClearCommand.parse(trimmed)       { return .clear(cmd) }
        if let cmd = HermesColorsCommand.parse(trimmed)      { return .colors(cmd) }
        if let cmd = HermesCompactCommand.parse(trimmed)     { return .compact(cmd) }
        if let cmd = HermesConfigShowCommand.parse(trimmed)  { return .configShow(cmd) }
        if let cmd = HermesCostCommand.parse(trimmed)        { return .cost(cmd) }
        if let cmd = HermesExportCommand.parse(trimmed)      { return .export(cmd) }
        if let cmd = HermesFontCommand.parse(trimmed)        { return .font(cmd) }
        if let cmd = HermesFontSizeCommand.parse(trimmed)    { return .fontsize(cmd) }
        if let cmd = HermesGrepCommand.parse(trimmed)        { return .grep(cmd) }
        if let cmd = HermesHelpCommand.parse(trimmed)        { return .help(cmd) }
        if let cmd = HermesLoadCommand.parse(trimmed)        { return .load(cmd) }
        if let cmd = HermesLsCommand.parse(trimmed)          { return .ls(cmd) }
        if let cmd = HermesMemoryCommand.parse(trimmed)      { return .memory(cmd) }
        if let cmd = HermesModeCommand.parse(trimmed)        { return .mode(cmd) }
        if let cmd = HermesModelCommand.parse(trimmed)       { return .model(cmd) }
        if let cmd = HermesNewSessionCommand.parse(trimmed)  { return .newSession(cmd) }
        if let cmd = HermesNotebookCommand.parse(trimmed)    { return .notebook(cmd) }
        if let cmd = HermesParameterCommand.parse(trimmed)   { return .parameter(cmd) }
        if let cmd = HermesPersonaCommand.parse(trimmed)     { return .persona(cmd) }
        if let cmd = HermesReadCommand.parse(trimmed)        { return .read(cmd) }
        if let cmd = HermesSaveCommand.parse(trimmed)        { return .save(cmd) }
        if let cmd = HermesSearchCommand.parse(trimmed)      { return .search(cmd) }
        if let cmd = HermesStatusCommand.parse(trimmed)      { return .status(cmd) }
        if let cmd = HermesSummaryCommand.parse(trimmed)     { return .summary(cmd) }
        if let cmd = HermesSystemPromptCommand.parse(trimmed) { return .systemPrompt(cmd) }
        if let cmd = HermesThemeCommand.parse(trimmed)       { return .theme(cmd) }
        if let cmd = HermesThinkCommand.parse(trimmed)       { return .think(cmd) }
        if let cmd = HermesTodoCommand.parse(trimmed)        { return .todo(cmd) }
        if let cmd = HermesTokensCommand.parse(trimmed)      { return .tokens(cmd) }
        if let cmd = HermesToolsToggleCommand.parse(trimmed) { return .toolsToggle(cmd) }
        if let cmd = HermesUIToggleCommand.parse(trimmed)    { return .uiToggle(cmd) }
        if let cmd = HermesWidthCommand.parse(trimmed)       { return .width(cmd) }
        if let cmd = HermesWriteCommand.parse(trimmed)       { return .write(cmd) }

        return nil
    }
}

// MARK: - /ask passthrough wrapper
//
// Inline mini-parser for the `/ask <question>` registry entry — the
// only Core command not previously implemented as its own struct.
// Native chat surface treats /ask the same as a bare prompt, so the
// command just unwraps the question text. Trivial action class.

nonisolated struct HermesAskCommand: Equatable, Sendable {
    let question: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesAskCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/ask" || trimmed.hasPrefix("/ask ") else { return nil }
        let body = trimmed.dropFirst("/ask".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return HermesAskCommand(question: body)
    }
}
