import Testing
@testable import Epistemos

/// Owner 2026-06-22: a local model answered the title-generation prompt with a self-description
/// ("4, a Large Language Model developed by Google DeepMind. I am an open weights model") and it
/// was surfaced RAW as the chat title (cousin of the old <think> title leak). The sanitizer must
/// produce a CLEAN short title or skip entirely — never dump the model's self-talk.
@Suite("Chat title sanitizer — clean titles, no model self-talk")
struct ChatTitleSanitizerTests {

    @Test("rejects model self-descriptions / refusals (returns nil → no garbage title)")
    func rejectsSelfDescription() {
        #expect(ChatCoordinator.sanitizeGeneratedTitle(
            "4, a Large Language Model developed by Google DeepMind. I am an open weights model") == nil)
        #expect(ChatCoordinator.sanitizeGeneratedTitle("I am Gemma, an AI assistant") == nil)
        #expect(ChatCoordinator.sanitizeGeneratedTitle("Sorry, I can't help with that") == nil)
        #expect(ChatCoordinator.sanitizeGeneratedTitle("As an AI, I don't have a title") == nil)
    }

    @Test("keeps + cleans real short titles")
    func keepsRealTitles() {
        #expect(ChatCoordinator.sanitizeGeneratedTitle("\"Quantum entanglement basics\"") == "Quantum entanglement basics")
        #expect(ChatCoordinator.sanitizeGeneratedTitle("Title: Fix SwiftUI layout bug") == "Fix SwiftUI layout bug")
        #expect(ChatCoordinator.sanitizeGeneratedTitle("Essay on stoicism.") == "Essay on stoicism")
    }

    @Test("caps an over-long sentence to a short title")
    func capsLongTitles() {
        #expect(ChatCoordinator.sanitizeGeneratedTitle("one two three four five six seven eight nine ten")
            == "one two three four five six seven eight")
    }

    @Test("takes only the first line, ignoring any trailing explanation")
    func firstLineOnly() {
        #expect(ChatCoordinator.sanitizeGeneratedTitle("React vs Vue comparison\nThis title summarizes the chat.")
            == "React vs Vue comparison")
    }

    @Test("empty / whitespace input yields nil")
    func emptyYieldsNil() {
        #expect(ChatCoordinator.sanitizeGeneratedTitle("") == nil)
        #expect(ChatCoordinator.sanitizeGeneratedTitle("   \n  ") == nil)
    }
}
