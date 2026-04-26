import Foundation
import Testing

@testable import Epistemos

/// Wave 7.4 source-guard for the ACC slash + at-mention tokenizer
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.4,
///  cross-ref PLAN_V2.md §4.1 Agent Command Center).
///
/// The tokenizer is the pure scanner — UI integration (NSPopover +
/// SwiftUI command palette) is a follow-up. Tests here cover every
/// "active token" detection + non-detection contract from the canonical
/// Linear/Notion/Bear pattern.
@Suite("Command tokenizer (Wave 7.4)")
nonisolated struct CommandTokenizerTests {

    // MARK: - Detection

    @Test("Slash trigger at start of text is detected")
    func slashAtStart() {
        let text = "/note"
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token?.kind == .slash)
        #expect(token?.query == "note")
        #expect(token?.triggerIndex == text.startIndex)
    }

    @Test("Slash trigger after whitespace is detected at word boundary")
    func slashAfterWhitespace() {
        let text = "Run a /search query"
        // Caret right after "y" of "query"
        let caret = text.index(text.startIndex, offsetBy: text.utf16.count - " query".utf16.count)
        // Caret immediately after "/search"
        let earlierCaret = text.range(of: "/search")!.upperBound
        let token = CommandTokenizer.activeToken(in: text, caret: earlierCaret)
        #expect(token?.kind == .slash)
        #expect(token?.query == "search")
        // Suppress unused warning
        _ = caret
    }

    @Test("At-mention trigger after newline is detected")
    func mentionAfterNewline() {
        let text = "Hello\n@kant"
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token?.kind == .mention)
        #expect(token?.query == "kant")
    }

    @Test("Empty query immediately after trigger character is detected")
    func emptyQueryAtTrigger() {
        let text = "Run /"
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token?.kind == .slash)
        #expect(token?.query == "",
                "empty query right after the trigger must still detect (palette opens with no filter)")
    }

    // MARK: - Non-detection

    @Test("Whitespace after trigger closes the token")
    func whitespaceClosesToken() {
        let text = "/find now"
        // Caret after the space — trigger is no longer active.
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token == nil,
                "trigger followed by space → no active completion; cursor sits in plain text")
    }

    @Test("Mid-word slash inside URL is NOT a trigger")
    func slashInsideURLIsNotATrigger() {
        let text = "see https://example.com/foo for context"
        // Caret in the middle of the URL.
        let caret = text.range(of: "/foo")!.upperBound
        let token = CommandTokenizer.activeToken(in: text, caret: caret)
        #expect(token == nil,
                "slash inside a URL (not at a word boundary) must not trigger the slash command palette")
    }

    @Test("Mid-word at-sign inside email is NOT a trigger")
    func atInsideEmailIsNotATrigger() {
        let text = "ping me at jojo@example.com tomorrow"
        let caret = text.range(of: "@example")!.upperBound
        let token = CommandTokenizer.activeToken(in: text, caret: caret)
        #expect(token == nil,
                "@ inside an email address (preceded by an alphanumeric) must not trigger at-mention")
    }

    @Test("Caret at start of empty text returns nil")
    func emptyTextNoToken() {
        let text = ""
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token == nil)
    }

    @Test("Plain text without trigger returns nil")
    func plainTextNoToken() {
        let text = "hello world"
        let token = CommandTokenizer.activeToken(in: text, caret: text.endIndex)
        #expect(token == nil)
    }

    // MARK: - Replacement range

    @Test("replacementRange covers trigger + query")
    func replacementRangeCoversTriggerAndQuery() {
        let text = "type /search"
        let caret = text.endIndex
        guard let token = CommandTokenizer.activeToken(in: text, caret: caret) else {
            #expect(Bool(false), "must detect /search trigger")
            return
        }
        let replaced = String(text[token.replacementRange])
        #expect(replaced == "/search",
                "replacementRange must span the trigger character through the end of the query so a completion fully overwrites both")
    }

    // MARK: - Both kinds reachable

    @Test("Both trigger kinds round-trip through the kind enum")
    func bothKindsReachable() {
        let slashText = "/cmd"
        let mentionText = "@user"
        let slash = CommandTokenizer.activeToken(in: slashText, caret: slashText.endIndex)
        let mention = CommandTokenizer.activeToken(in: mentionText, caret: mentionText.endIndex)
        #expect(slash?.kind == .slash)
        #expect(mention?.kind == .mention)
        #expect(CommandTokenKind.allCases.count == 2,
                "Wave 7.4 ships exactly 2 trigger kinds — adding a 3rd needs a separate plan entry")
    }
}
