import Foundation
import os

// MARK: - Command Input Parser
// Pure Swift, synchronous, zero-dependency parser for the Agent Command Center input bar.
// Extracts slash commands (builtin modes + discovered skills), @-mentions,
// and produces a cleaned query string for submission.
// Designed for <1ms latency — called on every debounced input change.

enum CommandInputParser {

    struct ParseResult {
        /// The resolved slash token — builtin mode/command or discovered skill.
        let slashToken: ParsedSlashToken?
        /// Resolved @-mention targets.
        let mentions: [ACCContextMention]
        /// Input with /command and @mentions stripped out.
        let cleanedQuery: String
        /// Current suggestion dropdown state.
        let suggestionState: ACCSuggestionMenuState
    }

    /// Parse raw input text into structured tokens.
    ///
    /// - Parameters:
    ///   - input: Raw text from the command bar
    ///   - availableSkills: Skills discovered via SkillDiscoveryCatalog (searched under /)
    ///   - contextProviders: Known @-mention targets (agents, vault tokens, folders)
    /// - Returns: Structured parse result
    static func parse(
        _ input: String,
        availableSkills: [SkillDiscoveryEntry] = [],
        contextProviders: [ACCContextProvider] = []
    ) -> ParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParseResult(
                slashToken: nil,
                mentions: [],
                cleanedQuery: "",
                suggestionState: .hidden
            )
        }

        // Parse slash command / skill
        let slashResult = parseSlash(trimmed, availableSkills: availableSkills)

        // Parse @mentions from the remaining text
        let textAfterSlash = slashResult.remaining
        let mentionResult = parseMentions(textAfterSlash, contextProviders: contextProviders)

        // Determine suggestion state
        let suggestionState = resolveSuggestionState(
            slashResult: slashResult,
            mentionResult: mentionResult
        )

        return ParseResult(
            slashToken: slashResult.resolvedToken,
            mentions: mentionResult.resolvedMentions,
            cleanedQuery: mentionResult.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestionState: suggestionState
        )
    }

    // MARK: - Slash Parsing

    private struct SlashParseResult {
        let resolvedToken: ParsedSlashToken?
        let remaining: String
        let isPartial: Bool
        let partialFilter: String
    }

    private static func parseSlash(
        _ text: String,
        availableSkills: [SkillDiscoveryEntry]
    ) -> SlashParseResult {
        guard text.hasPrefix("/") else {
            return SlashParseResult(
                resolvedToken: nil,
                remaining: text,
                isPartial: false,
                partialFilter: ""
            )
        }

        // Extract the slash token (everything after / up to first space or end)
        let afterSlash = String(text.dropFirst())
        let spaceIndex = afterSlash.firstIndex(of: " ")
        let slashToken: String
        let remaining: String

        if let spaceIndex {
            slashToken = String(afterSlash[afterSlash.startIndex..<spaceIndex])
            remaining = String(afterSlash[afterSlash.index(after: spaceIndex)...])
        } else {
            slashToken = afterSlash
            remaining = ""
        }

        let normalizedToken = slashToken.lowercased()

        // Try exact match against builtin commands first
        if let builtinCommand = ACCSlashCommand.allCases.first(where: { $0.rawValue == normalizedToken }) {
            return SlashParseResult(
                resolvedToken: .builtinMode(builtinCommand),
                remaining: remaining,
                isPartial: false,
                partialFilter: ""
            )
        }

        // Try exact match against discovered skills
        if let skill = availableSkills.first(where: { $0.identifier.lowercased() == normalizedToken }) {
            return SlashParseResult(
                resolvedToken: .skill(skill),
                remaining: remaining,
                isPartial: false,
                partialFilter: ""
            )
        }

        // No exact match — check if we're mid-typing (no space after token yet)
        if spaceIndex == nil {
            // Still typing the token — this is a partial match. Show suggestions.
            return SlashParseResult(
                resolvedToken: nil,
                remaining: "",
                isPartial: true,
                partialFilter: normalizedToken
            )
        }

        // Has a space after the token but no match — treat as free text
        return SlashParseResult(
            resolvedToken: nil,
            remaining: text,
            isPartial: false,
            partialFilter: ""
        )
    }

    // MARK: - @Mention Parsing

    private struct MentionParseResult {
        let resolvedMentions: [ACCContextMention]
        let cleanedText: String
        let isPartialMention: Bool
        let partialFilter: String
    }

    private static func parseMentions(
        _ text: String,
        contextProviders: [ACCContextProvider]
    ) -> MentionParseResult {
        var mentions: [ACCContextMention] = []
        var cleanedText = text
        var isPartial = false
        var partialFilter = ""

        // Parse bracketed mentions: @[Some Name]
        let bracketedPattern = try? NSRegularExpression(pattern: #"@\[([^\]]+)\]"#, options: [])
        if let bracketedPattern {
            let results = bracketedPattern.matches(
                in: text, options: [],
                range: NSRange(text.startIndex..., in: text)
            )
            for match in results.reversed() {
                guard let tokenRange = Range(match.range(at: 1), in: text),
                      let fullRange = Range(match.range, in: text) else { continue }
                let token = String(text[tokenRange])

                if let provider = contextProviders.first(where: {
                    $0.token.localizedCaseInsensitiveCompare(token) == .orderedSame
                }) {
                    mentions.append(ACCContextMention(
                        id: provider.id,
                        token: provider.token,
                        resolvedLabel: provider.token,
                        mentionType: mentionType(from: provider.category)
                    ))
                } else {
                    // Treat as a note title reference
                    mentions.append(ACCContextMention(
                        id: "note:\(token)",
                        token: token,
                        resolvedLabel: token,
                        mentionType: .openNote
                    ))
                }
                cleanedText.replaceSubrange(fullRange, with: "")
            }
        }

        // Parse single-word mentions: @Safari, @AllNotes
        let singlePattern = try? NSRegularExpression(pattern: #"@(\w[\w:]*)"#, options: [])
        if let singlePattern {
            let results = singlePattern.matches(
                in: cleanedText, options: [],
                range: NSRange(cleanedText.startIndex..., in: cleanedText)
            )

            // Check if the last match is at the end of text (partial mention)
            if let lastMatch = results.last {
                let matchEnd = lastMatch.range.location + lastMatch.range.length
                if matchEnd == (cleanedText as NSString).length {
                    // This might be a partial mention the user is still typing
                    if let tokenRange = Range(lastMatch.range(at: 1), in: cleanedText) {
                        let token = String(cleanedText[tokenRange])
                        let exactMatch = contextProviders.contains(where: {
                            $0.token.localizedCaseInsensitiveCompare(token) == .orderedSame
                        })
                        if !exactMatch {
                            isPartial = true
                            partialFilter = token
                        }
                    }
                }
            }

            for match in results.reversed() {
                guard let tokenRange = Range(match.range(at: 1), in: cleanedText),
                      let fullRange = Range(match.range, in: cleanedText) else { continue }
                let token = String(cleanedText[tokenRange])

                if let provider = contextProviders.first(where: {
                    $0.token.localizedCaseInsensitiveCompare(token) == .orderedSame
                }) {
                    mentions.append(ACCContextMention(
                        id: provider.id,
                        token: provider.token,
                        resolvedLabel: provider.token,
                        mentionType: mentionType(from: provider.category)
                    ))
                    cleanedText.replaceSubrange(fullRange, with: "")
                }
                // Non-matching single-word @tokens are left as-is in the cleaned text
            }
        }

        return MentionParseResult(
            resolvedMentions: mentions.reversed(), // Restore original order
            cleanedText: cleanedText,
            isPartialMention: isPartial,
            partialFilter: partialFilter
        )
    }

    // MARK: - Suggestion State Resolution

    private static func resolveSuggestionState(
        slashResult: SlashParseResult,
        mentionResult: MentionParseResult
    ) -> ACCSuggestionMenuState {
        // Slash partial takes priority
        if slashResult.isPartial {
            return .slashMenu(filter: slashResult.partialFilter)
        }

        // Then @mention partial
        if mentionResult.isPartialMention {
            return .contextMentions(filter: mentionResult.partialFilter)
        }

        return .hidden
    }

    // MARK: - Helpers

    private static func mentionType(from category: ACCContextProvider.Category) -> ACCContextMention.MentionType {
        switch category {
        case .agent: .agent
        case .vault: .vault
        case .folder: .folder
        case .graph: .graph
        case .openNote: .openNote
        }
    }
}
