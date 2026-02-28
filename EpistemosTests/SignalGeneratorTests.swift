import Testing
@testable import Epistemos

@Suite("SignalGenerator")
@MainActor
struct SignalGeneratorTests {

    // MARK: - Helpers

    private func makeAnalysis(
        domain: AnalysisDomain = .general,
        questionType: QuestionType = .conceptual,
        entities: [String] = [],
        complexity: Double = 0.5,
        isEmpirical: Bool = false,
        isPhilosophical: Bool = false,
        isMetaAnalytical: Bool = false,
        hasSafetyKeywords: Bool = false,
        hasNormativeClaims: Bool = false
    ) -> QueryAnalysis {
        QueryAnalysis(
            domain: domain,
            questionType: questionType,
            entities: entities,
            coreQuestion: "test question",
            complexity: complexity,
            isEmpirical: isEmpirical,
            isPhilosophical: isPhilosophical,
            isMetaAnalytical: isMetaAnalytical,
            hasSafetyKeywords: hasSafetyKeywords,
            hasNormativeClaims: hasNormativeClaims,
            keyTerms: entities,
            emotionalValence: .neutral,
            isFollowUp: false,
            followUpFocus: nil
        )
    }

    // MARK: - Range Checks

    @Test("confidence stays within 0.1 to 0.95")
    func confidenceRange() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.confidence >= 0.1)
        #expect(signals.confidence <= 0.95)
    }

    @Test("entropy stays within 0.01 to 0.95")
    func entropyRange() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.entropy >= 0.01)
        #expect(signals.entropy <= 0.95)
    }

    @Test("dissonance stays within 0.01 to 0.95")
    func dissonanceRange() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.dissonance >= 0.01)
        #expect(signals.dissonance <= 0.95)
    }

    @Test("health score stays above 0.2")
    func healthScoreFloor() {
        let analysis = makeAnalysis(hasSafetyKeywords: true)
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.healthScore >= 0.2)
    }

    @Test("risk score stays within 0.01 to 0.9")
    func riskScoreRange() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.riskScore >= 0.01)
        #expect(signals.riskScore <= 0.9)
    }

    // MARK: - Different Query Types Produce Different Signals

    @Test("philosophical query produces different signals than empirical")
    func philosophicalVsEmpirical() {
        let philosophical = makeAnalysis(
            isPhilosophical: true,
            hasNormativeClaims: true
        )
        let empirical = makeAnalysis(isEmpirical: true)

        let philSignals = SignalGenerator.generate(queryAnalysis: philosophical)
        let empSignals = SignalGenerator.generate(queryAnalysis: empirical)

        // Philosophical queries should have higher entropy
        #expect(philSignals.entropy > empSignals.entropy)
        // Philosophical queries should have lower base confidence
        #expect(philSignals.confidence < empSignals.confidence)
    }

    @Test("safety keywords increase risk score")
    func safetyKeywordsRisk() {
        let safe = makeAnalysis(hasSafetyKeywords: false)
        let unsafe = makeAnalysis(hasSafetyKeywords: true)

        let safeSignals = SignalGenerator.generate(queryAnalysis: safe)
        let unsafeSignals = SignalGenerator.generate(queryAnalysis: unsafe)

        #expect(unsafeSignals.riskScore > safeSignals.riskScore)
    }

    @Test("higher complexity produces different signals")
    func complexityEffect() {
        let low = makeAnalysis(complexity: 0.1)
        let high = makeAnalysis(complexity: 0.9)

        let lowSignals = SignalGenerator.generate(queryAnalysis: low)
        let highSignals = SignalGenerator.generate(queryAnalysis: high)

        // Higher complexity should increase entropy
        #expect(highSignals.entropy > lowSignals.entropy)
    }

    @Test("more entities increase entity factor")
    func entityEffect() {
        let few = makeAnalysis(entities: ["one"])
        let many = makeAnalysis(entities: ["a", "b", "c", "d", "e", "f", "g", "h"])

        let fewSignals = SignalGenerator.generate(queryAnalysis: few)
        let manySignals = SignalGenerator.generate(queryAnalysis: many)

        // More entities should produce higher confidence (more entity factor)
        #expect(manySignals.confidence >= fewSignals.confidence)
    }

    // MARK: - Default Controls

    @Test("default controls produce valid signals")
    func defaultControls() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis, controls: .default)
        #expect(signals.confidence >= 0.1)
        #expect(signals.entropy >= 0.01)
        #expect(signals.dissonance >= 0.01)
    }

    // MARK: - Analysis Mode

    @Test("meta-analytical query produces metaAnalytical mode")
    func metaAnalyticalMode() {
        let analysis = makeAnalysis(isMetaAnalytical: true)
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.mode == .metaAnalytical)
    }

    @Test("philosophical query produces philosophicalAnalytical mode")
    func philosophicalMode() {
        let analysis = makeAnalysis(isPhilosophical: true)
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.mode == .philosophicalAnalytical)
    }

    @Test("empirical query produces executive mode")
    func empiricalMode() {
        let analysis = makeAnalysis(isEmpirical: true)
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.mode == .executive)
    }

    @Test("generic query produces moderate mode")
    func moderateMode() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.mode == .moderate)
    }

    // MARK: - Safety State

    @Test("high risk score triggers red safety state")
    func redSafetyState() {
        // Safety keywords + high complexity + many entities => high risk
        let analysis = makeAnalysis(
            entities: ["a", "b", "c", "d", "e", "f", "g", "h"],
            complexity: 1.0,
            hasSafetyKeywords: true
        )
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.riskScore >= 0.55)
        #expect(signals.safetyState == .red)
    }

    @Test("low risk query produces green safety state")
    func greenSafetyState() {
        let analysis = makeAnalysis(complexity: 0.0)
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        #expect(signals.safetyState == .green)
    }

    // MARK: - Grade

    @Test("grade assigned based on clamped confidence")
    func gradeAssignment() {
        let analysis = makeAnalysis()
        let signals = SignalGenerator.generate(queryAnalysis: analysis)
        // Just verify grade is one of the valid values
        let validGrades: [EvidenceGrade] = [.a, .b, .c, .d]
        #expect(validGrades.contains(signals.grade))
    }

}
