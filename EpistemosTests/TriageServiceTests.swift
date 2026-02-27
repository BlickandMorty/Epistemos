import Testing
@testable import Epistemos

@Suite("TriageService")
struct TriageServiceTests {

    // MARK: - isRefusalResponse

    @Test("empty string is a refusal")
    func emptyRefusal() {
        #expect(TriageService.isRefusalResponse(""))
    }

    @Test("whitespace-only string is a refusal")
    func whitespaceRefusal() {
        #expect(TriageService.isRefusalResponse("   \n  "))
    }

    @Test("generic AI refusal detected")
    func genericRefusal() {
        #expect(TriageService.isRefusalResponse("I can't help with that request."))
        #expect(TriageService.isRefusalResponse("I cannot assist with this topic."))
        #expect(TriageService.isRefusalResponse("As an AI, I don't have the ability to do that."))
    }

    @Test("Apple Intelligence refusal detected")
    func appleRefusal() {
        #expect(TriageService.isRefusalResponse("As a language model created by Apple, I am unable to assist with that."))
        #expect(TriageService.isRefusalResponse("Beyond my remit to provide that kind of analysis."))
    }

    @Test("legitimate response is not a refusal")
    func legitimateResponse() {
        #expect(!TriageService.isRefusalResponse("Aspirin is a nonsteroidal anti-inflammatory drug (NSAID)."))
        #expect(!TriageService.isRefusalResponse("The key insight here is that quantum entanglement does not allow faster-than-light communication."))
    }

    @Test("refusal buried after 500 chars is not detected")
    func buriedRefusal() {
        let longPrefix = String(repeating: "This is valid content. ", count: 30)
        let text = longPrefix + "I can't help with that."
        #expect(!TriageService.isRefusalResponse(text))
    }

    // MARK: - isTruncatedResponse

    @Test("short response is truncated")
    func shortTruncated() {
        #expect(TriageService.isTruncatedResponse("Yes"))
        #expect(TriageService.isTruncatedResponse("I think"))
    }

    @Test("response ending without punctuation is truncated")
    func noPunctuationTruncated() {
        let text = "This is a response that ends abruptly without any terminal punctuation and keeps going on"
        #expect(TriageService.isTruncatedResponse(text))
    }

    @Test("response ending with period is not truncated")
    func periodNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("This is a complete response with a proper ending."))
    }

    @Test("response ending with list marker is not truncated")
    func listNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("Here are the key points:\n- First important item"))
    }

    @Test("response ending with code block is not truncated")
    func codeBlockNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("Here is the code:\n```"))
    }

    // MARK: - shouldFallbackToAPI

    @Test("combines refusal and truncation checks")
    func fallbackCombined() {
        #expect(TriageService.shouldFallbackToAPI(""))           // refusal
        #expect(TriageService.shouldFallbackToAPI("I can't help")) // refusal
        #expect(TriageService.shouldFallbackToAPI("Short"))       // truncated
        #expect(!TriageService.shouldFallbackToAPI("This is a perfectly valid response that should not trigger any fallback."))
    }

    // MARK: - NotesOperation complexity

    @Test("operations have correct complexity ordering")
    func complexityOrdering() {
        #expect(NotesOperation.grammarFix.baseComplexity < NotesOperation.summarize.baseComplexity)
        #expect(NotesOperation.summarize.baseComplexity < NotesOperation.rewrite.baseComplexity)
        #expect(NotesOperation.rewrite.baseComplexity < NotesOperation.continueWriting.baseComplexity)
        #expect(NotesOperation.continueWriting.baseComplexity < NotesOperation.ask(query: "test").baseComplexity)
        #expect(NotesOperation.ask(query: "test").baseComplexity < NotesOperation.outline.baseComplexity)
        #expect(NotesOperation.outline.baseComplexity < NotesOperation.expand.baseComplexity)
        #expect(NotesOperation.expand.baseComplexity < NotesOperation.analyze.baseComplexity)
        #expect(NotesOperation.analyze.baseComplexity < NotesOperation.learn.baseComplexity)
    }

    @Test("all operations have display names")
    func operationDisplayNames() {
        #expect(!NotesOperation.grammarFix.displayName.isEmpty)
        #expect(!NotesOperation.summarize.displayName.isEmpty)
        #expect(!NotesOperation.learn.displayName.isEmpty)
    }

    // MARK: - GeneralOperation complexity

    @Test("apiOnly always has max complexity")
    func apiOnlyMaxComplexity() {
        #expect(GeneralOperation.apiOnly.baseComplexity == 1.0)
    }

    @Test("general operations have display names")
    func generalDisplayNames() {
        #expect(!GeneralOperation.chatResponse(query: "test").displayName.isEmpty)
        #expect(!GeneralOperation.epistemicLens.displayName.isEmpty)
        #expect(!GeneralOperation.brainstorm.displayName.isEmpty)
        #expect(!GeneralOperation.apiOnly.displayName.isEmpty)
    }

    // MARK: - TriageDecision

    @Test("decision labels and icons are non-empty")
    func decisionLabels() {
        #expect(!TriageDecision.appleIntelligence.label.isEmpty)
        #expect(!TriageDecision.apiProvider.label.isEmpty)
        #expect(!TriageDecision.appleIntelligence.icon.isEmpty)
        #expect(!TriageDecision.apiProvider.icon.isEmpty)
    }

    @Test("isOnDevice matches enum case")
    func isOnDevice() {
        #expect(TriageDecision.appleIntelligence.isOnDevice)
        #expect(!TriageDecision.apiProvider.isOnDevice)
    }
}
