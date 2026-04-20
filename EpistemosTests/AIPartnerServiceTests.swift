import Testing
@testable import Epistemos

@Suite("AI Partner Service")
struct AIPartnerServiceTests {
    @MainActor
    @Test("explain action surfaces rationale and can return to the suggestion")
    func explainActionSurfacesRationaleAndCanReturnToSuggestion() {
        let service = AIPartnerService(triageService: nil, graphState: nil)
        let suggestion = InlineSuggestion(
            text: "let cache = LRUCache<String, Node>()",
            type: .refactor,
            range: nil,
            confidence: 0.82,
            context: .init(
                relatedNoteIds: ["note-1", "note-2"],
                semanticScore: 0.74,
                contextLines: [
                    "func renderGraph() {",
                    "    updateNeighbors()",
                    "}"
                ],
                source: "Apple Intelligence"
            )
        )

        service.currentSuggestion = suggestion
        service.explainCurrentSuggestion()

        #expect(service.retroResponse?.title == "AI PARTNER — WHY THIS SUGGESTION")
        #expect(service.retroResponse?.content.contains("Apple Intelligence") == true)
        #expect(service.retroResponse?.content.contains("2 related notes") == true)
        #expect(service.retroResponse?.content.contains("renderGraph") == true)
        #expect(service.retroResponse?.actions.map(\.id) == ["back", "accept", "dismiss"])

        service.retroResponse?.actions.first(where: { $0.id == "back" })?.handler()

        #expect(service.retroResponse?.title == "AI PARTNER — REFACTOR")
        #expect(service.retroResponse?.content == suggestion.text)
        #expect(service.retroResponse?.actions.map(\.id) == ["accept", "dismiss", "explain"])
    }

    @MainActor
    @Test("explain action clamps non-finite percentages instead of trapping")
    func explainActionClampsNonFinitePercentagesInsteadOfTrapping() {
        let service = AIPartnerService(triageService: nil, graphState: nil)
        let suggestion = InlineSuggestion(
            text: "return result",
            type: .completion,
            range: nil,
            confidence: .nan,
            context: .init(
                relatedNoteIds: [],
                semanticScore: .infinity,
                contextLines: [],
                source: "Apple Intelligence"
            )
        )

        service.currentSuggestion = suggestion
        service.explainCurrentSuggestion()

        #expect(service.retroResponse?.content.contains("Confidence: 0%.") == true)
        #expect(service.retroResponse?.content.contains("matched at 0% semantic strength.") == true)
    }
}
