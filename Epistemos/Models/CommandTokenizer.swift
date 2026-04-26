import Foundation

// MARK: - CommandTokenizer
//
// Wave 7.4 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.4,
//  cross-ref PLAN_V2.md §4.1 Agent Command Center).
//
// Hand-rolled scanner for the Agent Command Center (ACC) input field.
// Detects two trigger characters at word boundaries:
//
//   /  → slash command       (e.g. /note, /search, /run, /think)
//   @  → at-mention          (e.g. @kant, @project-mohawk)
//
// Per the Wave 7.4 research finding: hand-rolled tokenizer, NOT a
// parser library. swift-parsing is overkill for two trigger characters
// and adds 200 KB of binary for no real win. The reference 2026
// implementations (Linear / Notion / Bear) all hand-roll this same
// pattern over NSTextStorage deltas.
//
// This module ships only the tokenizer + token model. The UI layer
// (NSPopover anchored via firstRect(forCharacterRange:) + SwiftUI
// command palette) is a follow-up.

/// Trigger character family for an active completion. Carries no payload —
/// the surrounding context (current text, caret position) supplies the
/// query string + insert range.
nonisolated public enum CommandTokenKind: String, Sendable, Hashable, CaseIterable {
    case slash
    case mention

    /// The single-character trigger that starts a token of this kind.
    public var triggerCharacter: Character {
        switch self {
        case .slash:   return "/"
        case .mention: return "@"
        }
    }
}

/// One detected slash / at-mention occurrence in some input text.
///
/// `triggerIndex` points at the trigger character itself; `queryRange`
/// covers the text AFTER the trigger up to the caret. The full
/// replacement range when the user picks a completion is
/// `triggerIndex ..< queryRange.upperBound`.
nonisolated public struct CommandToken: Sendable, Hashable {
    public let kind: CommandTokenKind
    public let triggerIndex: String.Index
    public let queryRange: Range<String.Index>
    public let query: String

    public init(
        kind: CommandTokenKind,
        triggerIndex: String.Index,
        queryRange: Range<String.Index>,
        query: String
    ) {
        self.kind = kind
        self.triggerIndex = triggerIndex
        self.queryRange = queryRange
        self.query = query
    }

    /// The full range to REPLACE when the user accepts a completion
    /// (covers the trigger character + the query so the inserted item
    /// fully overwrites both).
    public var replacementRange: Range<String.Index> {
        triggerIndex..<queryRange.upperBound
    }
}

/// Stateless scanner for slash + at-mention triggers.
///
/// Usage:
/// ```swift
/// let text = "Hello /find sorted"
/// let caret = text.endIndex  // user's cursor
/// if let token = CommandTokenizer.activeToken(in: text, caret: caret) {
///     // present completion popover for `token`
/// }
/// ```
nonisolated public enum CommandTokenizer {

    /// Find the active completion token (if any) at the given caret
    /// position inside `text`. The "active" token is the most recent
    /// trigger character at a word boundary BEFORE the caret, with no
    /// intervening whitespace / newline that would close the trigger.
    ///
    /// Returns `nil` when no trigger is active (cursor sits in plain
    /// text; or the user typed a space after the trigger; or the
    /// trigger isn't at a word boundary).
    public static func activeToken(in text: String, caret: String.Index) -> CommandToken? {
        guard caret <= text.endIndex else { return nil }
        if caret == text.startIndex { return nil }

        // Walk backward from caret looking for a trigger character.
        // Stop at any whitespace/newline (which closes the trigger),
        // at the start of the string (acts like a word boundary), or
        // at any other character we encounter on the way back —
        // whichever comes first.
        var probe = caret
        var queryEnd = caret
        var foundTrigger: (Character, String.Index)?

        while probe > text.startIndex {
            probe = text.index(before: probe)
            let ch = text[probe]
            if ch.isWhitespace || ch.isNewline {
                // Hit a whitespace boundary before any trigger →
                // the cursor is in plain text; no active token.
                return nil
            }
            if ch == "/" || ch == "@" {
                // Found a candidate trigger. Verify it's at a word
                // boundary: either it's at startIndex, or the
                // character BEFORE it is whitespace / newline.
                if isAtWordBoundary(text: text, triggerIndex: probe) {
                    foundTrigger = (ch, probe)
                    break
                }
                // Mid-word `/` or `@` (e.g. inside an email or path) —
                // not a trigger. Keep scanning back.
                continue
            }
        }

        guard let (triggerChar, triggerIdx) = foundTrigger else {
            return nil
        }

        let kind: CommandTokenKind = (triggerChar == "/") ? .slash : .mention
        let queryStart = text.index(after: triggerIdx)
        // Edge: trigger right at the caret with no query yet.
        if queryStart > queryEnd {
            queryEnd = queryStart
        }
        let queryRange = queryStart..<queryEnd
        let query = String(text[queryRange])
        return CommandToken(
            kind: kind,
            triggerIndex: triggerIdx,
            queryRange: queryRange,
            query: query
        )
    }

    /// True when the character at `triggerIndex` either sits at the
    /// start of the string OR is preceded by whitespace / newline.
    /// Mid-word triggers (e.g. `/` inside `https://`, `@` inside an
    /// email address) are NOT triggers per the canonical pattern.
    @inline(__always)
    private static func isAtWordBoundary(text: String, triggerIndex: String.Index) -> Bool {
        if triggerIndex == text.startIndex { return true }
        let prior = text.index(before: triggerIndex)
        let priorChar = text[prior]
        return priorChar.isWhitespace || priorChar.isNewline
    }
}
