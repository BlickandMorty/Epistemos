import Testing
@testable import Epistemos

@Suite("QueryAnalyzer")
@MainActor
struct QueryAnalyzerTests {

    // MARK: - Complexity

    @Test("short query produces low complexity")
    func shortQueryLowComplexity() {
        let result = QueryAnalyzer.analyze(query: "What is aspirin?")
        #expect(result.complexity < 0.5)
    }

    @Test("long multi-entity query produces higher complexity")
    func longQueryHigherComplexity() {
        let result = QueryAnalyzer.analyze(
            query: "How does the relationship between quantum entanglement and consciousness relate to free will in deterministic physics models with Bayesian inference?"
        )
        #expect(result.complexity > 0.3)
    }

    @Test("complexity is between 0 and 1")
    func complexityRange() {
        let short = QueryAnalyzer.analyze(query: "hello")
        let long = QueryAnalyzer.analyze(
            query: "Explain the meta-analysis of randomized controlled trials examining the efficacy of cognitive behavioral therapy versus pharmacological interventions for treatment-resistant depression in adolescent populations with comorbid anxiety disorders"
        )
        #expect(short.complexity >= 0.0 && short.complexity <= 1.0)
        #expect(long.complexity >= 0.0 && long.complexity <= 1.0)
    }

    // MARK: - Question Type

    @Test("question marks and causal language detect causal type")
    func causalQuestionType() {
        let result = QueryAnalyzer.analyze(query: "Why does aspirin cause stomach bleeding?")
        #expect(result.questionType == .causal)
    }

    @Test("comparative language detected")
    func comparativeQuestionType() {
        let result = QueryAnalyzer.analyze(query: "Compare aspirin versus ibuprofen for pain relief")
        #expect(result.questionType == .comparative)
    }

    @Test("definitional language detected")
    func definitionalQuestionType() {
        let result = QueryAnalyzer.analyze(query: "what is quantum entanglement?")
        #expect(result.questionType == .definitional)
    }

    @Test("evaluative language detected")
    func evaluativeQuestionType() {
        let result = QueryAnalyzer.analyze(query: "should we use aspirin for heart disease prevention?")
        #expect(result.questionType == .evaluative)
    }

    // MARK: - Domain Detection

    @Test("medical domain detected for health queries")
    func medicalDomain() {
        let result = QueryAnalyzer.analyze(query: "What is the best treatment for clinical depression?")
        #expect(result.domain == .medical)
    }

    @Test("philosophy domain detected")
    func philosophyDomain() {
        let result = QueryAnalyzer.analyze(query: "What is the meaning of consciousness and free will?")
        #expect(result.domain == .philosophy)
    }

    @Test("technology domain detected")
    func technologyDomain() {
        let result = QueryAnalyzer.analyze(query: "How does machine learning training work for neural networks?")
        #expect(result.domain == .technology)
    }

    @Test("general domain for generic queries")
    func generalDomain() {
        let result = QueryAnalyzer.analyze(query: "Tell me about cooking pasta")
        #expect(result.domain == .general)
    }

    // MARK: - Emotional Valence

    @Test("negative valence for harmful topics")
    func negativeValence() {
        let result = QueryAnalyzer.analyze(query: "Why does suffering and pain persist in the world?")
        #expect(result.emotionalValence == .negative)
    }

    @Test("positive valence for beneficial topics")
    func positiveValence() {
        let result = QueryAnalyzer.analyze(query: "How does love and hope improve mental health?")
        #expect(result.emotionalValence == .positive)
    }

    @Test("neutral valence for factual queries")
    func neutralValence() {
        let result = QueryAnalyzer.analyze(query: "What is the speed of light?")
        #expect(result.emotionalValence == .neutral)
    }

    // MARK: - Edge Cases

    @Test("empty string does not crash")
    func emptyString() {
        let result = QueryAnalyzer.analyze(query: "")
        #expect(result.domain == .general)
        #expect(result.complexity >= 0)
    }

    @Test("single word query produces result")
    func singleWord() {
        let result = QueryAnalyzer.analyze(query: "aspirin")
        #expect(result.domain == .general || result.domain == .medical)
        #expect(result.complexity < 0.5)
    }

    @Test("very long string does not crash and stays bounded")
    func veryLongString() {
        let longQuery = String(repeating: "quantum entanglement consciousness ", count: 100)
        let result = QueryAnalyzer.analyze(query: longQuery)
        #expect(result.complexity >= 0.0 && result.complexity <= 1.0)
    }

    // MARK: - Boolean Flags

    @Test("empirical flag set for evidence-based queries")
    func empiricalFlag() {
        let result = QueryAnalyzer.analyze(query: "What does the clinical trial evidence show about aspirin efficacy?")
        #expect(result.isEmpirical == true)
    }

    @Test("philosophical flag set for philosophical queries")
    func philosophicalFlag() {
        let result = QueryAnalyzer.analyze(query: "What is the truth about consciousness and free will?")
        #expect(result.isPhilosophical == true)
    }

    @Test("safety keywords detected")
    func safetyKeywords() {
        let result = QueryAnalyzer.analyze(query: "Can aspirin cause harm or danger in high doses?")
        #expect(result.hasSafetyKeywords == true)
    }

    @Test("normative claims detected")
    func normativeClaims() {
        let result = QueryAnalyzer.analyze(query: "Should doctors prescribe this? Is it right or wrong?")
        #expect(result.hasNormativeClaims == true)
    }
}
