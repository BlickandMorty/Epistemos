import Testing
@testable import Epistemos

@Suite("SOAR")
struct SOARTests {

    // MARK: - SOARDetector

    @Suite("SOARDetector")
    struct DetectorTests {

        private func makeQuery(
            query: String,
            complexity: Double = 0.3,
            questionType: QuestionType = .definitional,
            domain: AnalysisDomain = .general,
            entities: [String] = []
        ) -> QueryAnalysis {
            QueryAnalyzer.analyze(query: query)
        }

        @Test("simple query is not at edge")
        func simpleNotAtEdge() {
            let analysis = QueryAnalyzer.analyze(query: "What is aspirin?")
            let probe = SOARDetector.probeLearnability(
                queryAnalysis: analysis,
                thresholds: .default
            )
            #expect(!probe.atEdge)
            #expect(probe.recommendedDepth == 0)
        }

        @Test("hard keywords increase difficulty")
        func hardKeywords() {
            let analysis = QueryAnalyzer.analyze(
                query: "How does the paradox of consciousness relate to the hard problem of qualia and free will in a self-referential system?"
            )
            let probe = SOARDetector.probeLearnability(
                queryAnalysis: analysis,
                thresholds: .default
            )
            #expect(probe.estimatedDifficulty > 0.5)
        }

        @Test("hard indicators list is non-empty")
        func hardIndicatorsExist() {
            #expect(!SOARDetector.hardIndicators.isEmpty)
            #expect(SOARDetector.hardIndicators.contains("paradox"))
            #expect(SOARDetector.hardIndicators.contains("consciousness"))
        }

        @Test("hard question types include expected values")
        func hardQuestionTypes() {
            #expect(SOARDetector.hardQuestionTypes.contains(.metaAnalytical))
            #expect(SOARDetector.hardQuestionTypes.contains(.causal))
            #expect(SOARDetector.hardQuestionTypes.contains(.speculative))
        }

        @Test("hard domains include expected values")
        func hardDomains() {
            #expect(SOARDetector.hardDomains.contains(.philosophy))
            #expect(SOARDetector.hardDomains.contains(.ethics))
            #expect(SOARDetector.hardDomains.contains(.psychology))
        }

        @Test("at-edge requires 2+ signal triggers — 1 signal is not enough")
        func edgeRequirements() {
            let analysis = QueryAnalyzer.analyze(query: "What color is the sky?")
            // Set thresholds so only confidence triggers (floor very high)
            // but entropy and dissonance do NOT trigger (ceilings very high)
            let oneSignalThresholds = LearnabilityThresholds(
                confidenceFloor: 0.99,     // will trigger (confidence < 0.99)
                entropyCeiling: 0.99,      // won't trigger (entropy < 0.99)
                dissonanceCeiling: 0.99,   // won't trigger (dissonance < 0.99)
                difficultyFloor: 0.01
            )
            let probe = SOARDetector.probeLearnability(
                queryAnalysis: analysis,
                thresholds: oneSignalThresholds
            )
            // Only 1/3 signals triggered — need 2+ to be at edge
            #expect(!probe.atEdge, "Only 1 signal trigger should not put query at edge")
        }

        @Test("recommended depth is 3 for all-trigger edge")
        func depth3ForAllTriggers() {
            // Use prior signals that definitely trigger all 3 conditions
            let lowSignals = BaselineSignals(
                confidence: 0.1,    // below floor 0.35
                entropy: 0.9,       // above ceiling 0.7
                dissonance: 0.8,    // above ceiling 0.6
                healthScore: 0.3
            )
            let analysis = QueryAnalyzer.analyze(
                query: "How does the paradox of consciousness relate to free will in the context of undecidable propositions, ecological fallacy, and Simpson's paradox?"
            )
            let probe = SOARDetector.probeLearnability(
                queryAnalysis: analysis,
                priorSignals: lowSignals,
                thresholds: .default
            )
            #expect(probe.atEdge, "Complex query with low prior signals should be at edge")
            #expect(probe.recommendedDepth == 3, "All 3 triggers active → depth should be 3")
        }

        @Test("difficulty clamped to [0, 1]")
        func difficultyClamped() {
            let analysis = QueryAnalyzer.analyze(
                query: "paradox contradiction dilemma consciousness qualia free will incompleteness emergent self-referential abductive counterfactual ecological fallacy Simpson's paradox"
            )
            let probe = SOARDetector.probeLearnability(
                queryAnalysis: analysis,
                thresholds: .default
            )
            #expect(probe.estimatedDifficulty >= 0)
            #expect(probe.estimatedDifficulty <= 1)
        }
    }

    // MARK: - SOARRewardCalculator

    @Suite("SOARRewardCalculator")
    struct RewardTests {

        @Test("positive confidence delta produces positive reward")
        func positiveConfidenceReward() {
            let baseline = BaselineSignals(confidence: 0.3, entropy: 0.7, dissonance: 0.5, healthScore: 0.5)
            let current = BaselineSignals(confidence: 0.6, entropy: 0.7, dissonance: 0.5, healthScore: 0.5)
            let reward = SOARRewardCalculator.computeReward(baseline: baseline, current: current, weights: .default)
            #expect(reward.deltaConfidence > 0)
            #expect(reward.composite > 0)
            #expect(reward.improved)
        }

        @Test("decreased entropy contributes positively")
        func decreasedEntropyPositive() {
            let baseline = BaselineSignals(confidence: 0.5, entropy: 0.8, dissonance: 0.5, healthScore: 0.5)
            let current = BaselineSignals(confidence: 0.5, entropy: 0.3, dissonance: 0.5, healthScore: 0.5)
            let reward = SOARRewardCalculator.computeReward(baseline: baseline, current: current, weights: .default)
            #expect(reward.composite > 0)
            #expect(reward.improved)
        }

        @Test("no change yields not improved")
        func noChangeNotImproved() {
            let signals = BaselineSignals(confidence: 0.5, entropy: 0.5, dissonance: 0.5, healthScore: 0.5)
            let reward = SOARRewardCalculator.computeReward(baseline: signals, current: signals, weights: .default)
            #expect(reward.composite == 0)
            #expect(!reward.improved)
        }

        @Test("worsening signals produce negative composite")
        func worseningNegative() {
            let baseline = BaselineSignals(confidence: 0.8, entropy: 0.3, dissonance: 0.2, healthScore: 0.8)
            let current = BaselineSignals(confidence: 0.2, entropy: 0.9, dissonance: 0.8, healthScore: 0.2)
            let reward = SOARRewardCalculator.computeReward(baseline: baseline, current: current, weights: .default)
            #expect(reward.composite < 0)
            #expect(!reward.improved)
        }

        @Test("improved threshold is composite > 0.01")
        func improvedThreshold() {
            let baseline = BaselineSignals(confidence: 0.5, entropy: 0.5, dissonance: 0.5, healthScore: 0.5)
            // Tiny improvement
            let current = BaselineSignals(confidence: 0.503, entropy: 0.5, dissonance: 0.5, healthScore: 0.5)
            let reward = SOARRewardCalculator.computeReward(baseline: baseline, current: current, weights: .default)
            // confidence weight = 0.35, delta = 0.003, composite = 0.00105 < 0.01
            #expect(!reward.improved)
        }

        // MARK: - Structural Quality

        @Test("good stone question gets high quality")
        func goodStoneQuality() {
            let quality = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "What empirical evidence from neuroscience contradicts the classical computational theory of mind?",
                targetQuery: "How does consciousness work?"
            )
            #expect(quality > 0.5)
        }

        @Test("very short question gets lower quality than a well-formed one")
        func shortLowerQuality() {
            let shortQ = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "Why?",
                targetQuery: "How does consciousness work?"
            )
            let goodQ = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "What empirical evidence from neuroscience contradicts the classical computational theory of mind?",
                targetQuery: "How does consciousness work?"
            )
            #expect(shortQ < goodQ)
        }

        @Test("quality clamped to [0, 1]")
        func qualityClamped() {
            let q1 = SOARRewardCalculator.assessStructuralQuality(stoneQuestion: "x", targetQuery: "y")
            let q2 = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "What is the relationship between epistemic uncertainty and ontological indeterminacy in quantum mechanics?",
                targetQuery: "Tell me about physics"
            )
            #expect(q1 >= 0 && q1 <= 1)
            #expect(q2 >= 0 && q2 <= 1)
        }

        @Test("high overlap with target reduces quality")
        func highOverlapPenalty() {
            let quality = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "How does consciousness work in the brain?",
                targetQuery: "How does consciousness work in the brain?"
            )
            // Near-identical question should be penalized
            let diverseQuality = SOARRewardCalculator.assessStructuralQuality(
                stoneQuestion: "What neural correlates distinguish phenomenal awareness from access consciousness?",
                targetQuery: "How does consciousness work in the brain?"
            )
            #expect(diverseQuality > quality)
        }
    }

    // MARK: - Default Thresholds

    @Test("default thresholds have reasonable values")
    func defaultThresholds() {
        let t = LearnabilityThresholds.default
        #expect(t.confidenceFloor > 0 && t.confidenceFloor < 1)
        #expect(t.entropyCeiling > 0 && t.entropyCeiling < 1)
        #expect(t.dissonanceCeiling > 0 && t.dissonanceCeiling < 1)
        #expect(t.difficultyFloor > 0 && t.difficultyFloor < 1)
    }

    @Test("default reward weights sum to 1")
    func rewardWeightsSum() {
        let w = RewardWeights.default
        let sum = w.confidence + w.entropy + w.dissonance + w.health
        #expect(abs(sum - 1.0) < 0.001)
    }
}
