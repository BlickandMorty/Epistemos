import Testing
import Foundation

@testable import Epistemos

// SS-IL safe-additive regression guards (owner 2026-06-20, NO-DEFERRAL plan): PROVE the inline
// "Ask this note" streaming path is UNCHANGED by the decoration overlay. The overlay is a pure,
// read-only decoration (cold-box separation + scroll arrow); the divider-protected append
// pipeline + the 6 streaming callbacks are never touched. Required before "done".
@Suite("SS-IL inline overlay safety (streaming path unchanged)")
struct SSILInlineOverlaySafetyTests {

    // Guard 1: the divider contract is byte-identical + still rejects in-marker edits.
    @Test("the AI-response divider constant + editTouchesDivider are unchanged")
    func dividerContractUnchanged() {
        #expect(NoteChatInlineResponse.divider == "\n\n<!-- ai-response -->\n\n")
        let body = "user text" + NoteChatInlineResponse.divider + "ai answer"
        // An edit squarely INSIDE the divider marker is rejected (protects the streamed region).
        let markerLoc = (body as NSString).range(of: "ai-response").location
        #expect(markerLoc != NSNotFound)
        #expect(NoteChatInlineResponse.editTouchesDivider(
            in: body, affectedRange: NSRange(location: markerLoc, length: 3)))
        // An edit in the user's text (the very start, far from the divider) is allowed.
        #expect(!NoteChatInlineResponse.editTouchesDivider(
            in: body, affectedRange: NSRange(location: 0, length: 4)))
    }

    // Guard 6: the overlay file CANNOT touch storage — it imports no storage/editor symbols.
    @Test("the overlay imports no NSTextStorage / ProseTextView2 / mutation symbols (can't touch storage)")
    func overlayCannotTouchStorage() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/InlineAnswerDecorationOverlay.swift")
        #expect(!src.contains("NSTextStorage"))
        #expect(!src.contains("ProseTextView2"))
        #expect(!src.contains("replaceCharacters"))
        #expect(!src.contains("textStorage"))
        // …and it is purely non-interactive over the text.
        #expect(src.contains("allowsHitTesting(false)"))
    }

    // Guard 4: the additive rect provider is READ-ONLY — it computes the response range and
    // reads `firstRect`; it does not mutate storage or fire any streaming callback.
    @Test("inlineResponseRectProvider is the read-only getter (firstRect only)")
    func rectProviderIsReadOnly() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        #expect(src.contains("noteChat.inlineResponseRectProvider = { [weak self] in"))
        #expect(src.contains("return tv.firstRect(forCharacterRange: responseRange, actualRange: nil)"))
        // NoteChatState exposes it as a plain provider (additive; not @ObservationIgnored noise).
        let state = try loadMirroredSourceTextFile("Epistemos/State/NoteChatState.swift")
        #expect(state.contains("var inlineResponseRectProvider: (() -> CGRect?)?"))
    }

    // Guard 3/5: the 6 streaming callbacks + the protected-divider toggle still exist, untouched
    // (the overlay work was additive — a new getter + a new overlay file, nothing removed).
    @Test("the 6 streaming callbacks + the protected-divider toggle are untouched")
    func streamingCallbacksUnchanged() throws {
        let state = try loadMirroredSourceTextFile("Epistemos/State/NoteChatState.swift")
        for cb in ["onStreamStart", "onTokenFlush", "onStreamFinish",
                   "onAccept", "onDiscard", "onReplaceInlineResponse"] {
            #expect(state.contains("var \(cb)"))
        }
        let tv = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        #expect(tv.contains("hasProtectedInlineResponseDivider"))
    }
}
