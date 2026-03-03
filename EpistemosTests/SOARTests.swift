import Testing
import Foundation
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

@Suite("QueryAnalyzer Core Coverage")
struct QueryAnalyzerCoreCoverageTests {

    @Test("domain precedence favors earliest matching domain pattern")
    func domainPrecedence() {
        let analysis = QueryAnalyzer.analyze(
            query: "Does aspirin improve machine learning model accuracy?"
        )
        #expect(analysis.domain == .medical) // medical patterns are evaluated before technology
    }

    @Test("question type precedence favors causal when causal and comparative cues co-occur")
    func questionTypePrecedence() {
        let analysis = QueryAnalyzer.analyze(
            query: "What cause pathways differ versus baseline treatment?"
        )
        #expect(analysis.questionType == .causal)
    }

    @Test("follow-up detection requires context")
    func followUpRequiresContext() {
        let withoutContext = QueryAnalyzer.analyze(query: "tell me more")
        #expect(!withoutContext.isFollowUp)

        let context = ConversationContext(
            previousQueries: ["What is Bayesian inference?"],
            previousEntities: ["bayesian", "inference"],
            rootQuestion: "What is Bayesian inference?"
        )
        let withContext = QueryAnalyzer.analyze(query: "tell me more", context: context)
        #expect(withContext.isFollowUp)
    }

    @Test("follow-up uses root question for coreQuestion and merges entities")
    func followUpCoreQuestionAndEntityMerge() {
        let context = ConversationContext(
            previousQueries: ["How does sleep affect cognition?"],
            previousEntities: ["sleep", "cognition", "memory"],
            rootQuestion: String(repeating: "How does sleep affect cognition? ", count: 10)
        )

        let analysis = QueryAnalyzer.analyze(
            query: "what about hippocampal consolidation and language?",
            context: context
        )

        #expect(analysis.isFollowUp)
        #expect(analysis.coreQuestion.count <= 120)
        #expect(analysis.entities.count <= 8)
        #expect(Set(context.previousEntities).isSubset(of: Set(analysis.entities)))
    }

    @Test("entity extraction strips punctuation, stop words, and caps cardinality")
    func entityExtractionAndCaps() {
        let analysis = QueryAnalyzer.analyze(
            query: "The, and, but: neuroplasticity!!! bilingual?? cognition... memory; language; adaptation; resilience; hippocampal; cortical; synaptic;"
        )

        #expect(analysis.entities.count <= 8)
        #expect(analysis.keyTerms.count <= 5)
        #expect(!analysis.entities.contains("the"))
        #expect(!analysis.entities.contains("and"))
        #expect(analysis.entities.contains(where: { $0.contains("neuroplasticity") || $0.contains("cognition") }))
    }

    @Test("complexity is clamped to [0, 1]")
    func complexityClamped() {
        let longQuery = String(repeating: "evidence trial mechanism uncertainty causality ", count: 2_000)
        let analysis = QueryAnalyzer.analyze(query: longQuery)
        #expect(analysis.complexity >= 0)
        #expect(analysis.complexity <= 1)
    }

    @Test("safety and normative flags trigger independently")
    func safetyAndNormativeFlags() {
        let analysis = QueryAnalyzer.analyze(
            query: "should society ban dangerous weapons to reduce harm and violence?"
        )

        #expect(analysis.hasSafetyKeywords)
        #expect(analysis.hasNormativeClaims)
    }

    @Test("emotional valence can classify mixed sentiment")
    func emotionalValenceMixed() {
        let analysis = QueryAnalyzer.analyze(
            query: "This policy could improve justice but also cause suffering and unfair outcomes."
        )
        #expect(analysis.emotionalValence == .mixed)
    }
}

@Suite("QueryAnalyzer Crash Resilience")
struct QueryAnalyzerCrashResilienceTests {

    @Test("handles unicode, RTL, combining marks, and emoji without crashing")
    func unicodeAndScriptResilience() {
        let query = [
            StringFuzz.emojiString(length: 120),
            StringFuzz.rtlString(),
            StringFuzz.combiningMarksString(base: "cafe"),
            "科学 認知 neuroscience سلام"
        ].joined(separator: " ")

        let analysis = QueryAnalyzer.analyze(query: query)
        assertAnalysisInvariants(analysis)
    }

    @Test("handles SQL/regex-like adversarial strings without crashing")
    func adversarialStringResilience() {
        let payload = (StringFuzz.sqlInjectionPatterns() + StringFuzz.regexSpecialChars())
            .joined(separator: " ")

        let analysis = QueryAnalyzer.analyze(query: payload)
        assertAnalysisInvariants(analysis)
    }

    @Test("handles very large single query payload without truncation crashes")
    func veryLargePayloadResilience() {
        let large = String(repeating: "meta-analysis causality evidence uncertainty ", count: 12_000)
        let analysis = QueryAnalyzer.analyze(query: large)
        assertAnalysisInvariants(analysis)
        #expect(analysis.coreQuestion.count <= 120)
    }

    @Test("handles oversized context payloads and still caps entities")
    func oversizedContextResilience() {
        let previousEntities = (0..<5_000).map { "entity\($0)" }
        let previousQueries = (0..<500).map { "prior question \($0)" }
        let context = ConversationContext(
            previousQueries: previousQueries,
            previousEntities: previousEntities,
            rootQuestion: "What mechanisms causally link sleep to learning outcomes?"
        )

        let analysis = QueryAnalyzer.analyze(
            query: "go deeper into neural replay and memory reconsolidation",
            context: context
        )

        assertAnalysisInvariants(analysis)
        #expect(analysis.entities.count <= 8)
        #expect(analysis.keyTerms.count <= 5)
    }

    @Test("random fuzz corpus maintains invariants")
    func randomFuzzCorpus() {
        let corpus = buildFuzzCorpus(sampleCount: 600)
        for text in corpus {
            let analysis = QueryAnalyzer.analyze(query: text)
            assertAnalysisInvariants(analysis)
        }
    }

    @Test("concurrent invocations do not crash and keep invariants")
    @MainActor
    func concurrentResilience() async {
        let corpus = buildFuzzCorpus(sampleCount: 300)

        let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for query in corpus {
                group.addTask {
                    await MainActor.run {
                        let analysis = QueryAnalyzer.analyze(query: query)
                        return !(analysis.complexity >= 0 &&
                            analysis.complexity <= 1 &&
                            analysis.entities.count <= 8 &&
                            analysis.keyTerms.count <= 5)
                    }
                }
            }

            var failures = 0
            for await failed in group {
                if failed { failures += 1 }
            }
            return failures
        }

        #expect(failures == 0)
    }

    private func assertAnalysisInvariants(_ analysis: QueryAnalysis) {
        #expect(analysis.complexity >= 0)
        #expect(analysis.complexity <= 1)
        #expect(analysis.entities.count <= 8)
        #expect(analysis.keyTerms.count <= 5)
        #expect(!analysis.coreQuestion.isEmpty || analysis.coreQuestion.count == 0)
    }

    private func buildFuzzCorpus(sampleCount: Int) -> [String] {
        var corpus: [String] = []
        corpus.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let base = StringFuzz.randomString(length: Int.random(in: 6...96))
            let unicode = i % 5 == 0 ? StringFuzz.randomUnicode(length: 24) : ""
            let emoji = i % 7 == 0 ? StringFuzz.emojiString(length: 8) : ""
            let rtl = i % 11 == 0 ? StringFuzz.rtlString() : ""
            let sql = i % 13 == 0 ? StringFuzz.sqlInjectionPatterns().randomElement() ?? "" : ""
            let control = i % 17 == 0 ? StringFuzz.controlChars().joined() : ""

            corpus.append([base, unicode, emoji, rtl, sql, control].joined(separator: " "))
        }
        return corpus
    }
}

@Suite("QueryAnalyzer Performance and Memory")
struct QueryAnalyzerPerformanceAndMemoryTests {

    @Test("short-query throughput remains bounded under high iteration counts")
    func shortQueryThroughput() {
        let duration = measure {
            for _ in 0..<20_000 {
                _ = QueryAnalyzer.analyze(
                    query: "What are the causal effects of sleep deprivation on cognition?"
                )
            }
        }

        #expect(duration < .seconds(12), "20k short analyses took \(duration)")
    }

    @Test("mixed realistic corpus throughput remains bounded")
    func mixedCorpusThroughput() {
        let queries = [
            "Should monetary policy tighten when inflation rises faster than wages?",
            "Explain quantum decoherence in simple terms.",
            "What evidence supports bilingualism improving executive function?",
            "Compare RCT findings versus observational data on statins.",
            "How can software teams reduce incident response time?",
            "Is there a causal link between social isolation and depression?"
        ]

        let duration = measure {
            for i in 0..<12_000 {
                _ = QueryAnalyzer.analyze(query: queries[i % queries.count])
            }
        }

        #expect(duration < .seconds(12), "12k mixed analyses took \(duration)")
    }

    @Test("batch latency stays stable across repeated runs")
    func batchLatencyStability() {
        var batchDurations: [Duration] = []
        batchDurations.reserveCapacity(6)

        for _ in 0..<6 {
            let elapsed = measure {
                for _ in 0..<2_500 {
                    _ = QueryAnalyzer.analyze(
                        query: "How does causal inference differ from predictive modeling in healthcare?"
                    )
                }
            }
            batchDurations.append(elapsed)
        }

        guard let baseline = batchDurations.first else {
            Issue.record("No batch durations captured")
            return
        }
        let worst = batchDurations.max() ?? baseline
        #expect(worst < baseline * 6, "Worst batch \(worst) is disproportionately slower than baseline \(baseline)")
    }

    @Test("large-query performance avoids catastrophic regex behavior")
    func largeQueryPerformance() {
        let large = String(repeating: "meta-analysis heterogeneity evidence contradiction mechanism ", count: 600)

        let duration = measure {
            for _ in 0..<20 {
                _ = QueryAnalyzer.analyze(query: large)
            }
        }

        #expect(duration < .seconds(20), "20 large analyses took \(duration)")
    }

    @Test("memory growth stays bounded under heavy repeated analysis")
    func memoryGrowthBounded() {
        let before = currentResidentMemoryBytes()

        for i in 0..<30_000 {
            autoreleasepool {
                let query = i % 2 == 0
                    ? "Explain causal pathways linking sleep and memory performance."
                    : "What empirical evidence supports policy intervention efficacy?"
                _ = QueryAnalyzer.analyze(query: query)
            }
        }

        let after = currentResidentMemoryBytes()
        let growth = after > before ? (after - before) : 0

        #expect(growth < 220_000_000, "Memory growth \(growth) bytes exceeds expected bound")
    }

    private func currentResidentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }
}

// BEGIN MASS GENERATED TESTS
@Suite("Mass Generated Notes - TOC 1000")
struct MassGeneratedNotesTOC1000Tests {
    @Test("mass generated notes TOC case", arguments: Array(0..<1000))
    func massGeneratedTOC(_ i: Int) {
        let level = (i % 5) + 1
        let heading = String(repeating: "#", count: level)
        let markdown = """
        \(heading) Heading \(i)
        > This is citation snippet number \(i) with enough context to qualify.
        [Source \(i)](https://example.com/source/\(i))
        """

        let items = TOCParser.parse(markdown)
        #expect(items.count >= 3)
        #expect(items.contains { $0.kind == .heading })
        #expect(items.contains { $0.kind == .citation })
        #expect(items.contains { $0.kind == .source })
    }
}

@Suite("Mass Generated Notes - LineDiff 1000")
struct MassGeneratedNotesLineDiff1000Tests {
    @Test("mass generated notes line diff case", arguments: Array(0..<1000))
    func massGeneratedLineDiff(_ i: Int) {
        let old = "alpha \(i)\ncommon line\nshared"
        let new = "alpha \(i) updated\ncommon line\nshared\nextra \(i)"

        let diff = LineDiff.compute(old: old, new: new)
        #expect(diff.lines.count >= 3)
        #expect(diff.stats.added + diff.stats.removed + diff.stats.modified <= diff.lines.count)

        let sections = diff.sectioned(contextLines: i % 4)
        #expect(!sections.isEmpty)
    }
}

@Suite("Mass Generated Chat - QueryParser 1000")
struct MassGeneratedChatQueryParser1000Tests {
    @Test("mass generated chat parser routing case", arguments: Array(0..<1000))
    func massGeneratedQueryParserRouting(_ i: Int) {
        switch i % 5 {
        case 0:
            let q = "find topic \(i)"
            let parsed = QueryParser.parse(q)
            switch parsed {
            case .contentSearch(let query, _):
                #expect(query.contains("topic \(i)"))
            default:
                Issue.record("Expected content search for case \(i)")
            }

        case 1:
            let parsed = QueryParser.parse("all notes")
            switch parsed {
            case .findNodes(let filter):
                #expect(filter.types?.contains(.note) == true)
            default:
                Issue.record("Expected findNodes(.note) for case \(i)")
            }

        case 2:
            let parsed = QueryParser.parse("how many notes")
            switch parsed {
            case .aggregation(let agg):
                let isCountByType: Bool
                if case .countByType = agg {
                    isCountByType = true
                } else {
                    isCountByType = false
                }
                #expect(isCountByType)
            default:
                Issue.record("Expected aggregation for case \(i)")
            }

        case 3:
            let parsed = QueryParser.parse("path from alpha\(i) to beta\(i)")
            switch parsed {
            case .pathBetween(from: let from, to: let to, maxHops: let hops):
                #expect(hops == 6)
                if case .label(let fromLabel) = from {
                    #expect(fromLabel.contains("alpha\(i)"))
                } else {
                    Issue.record("Expected from NodeRef.label for case \(i)")
                }
                if case .label(let toLabel) = to {
                    #expect(toLabel.contains("beta\(i)"))
                } else {
                    Issue.record("Expected to NodeRef.label for case \(i)")
                }
            default:
                Issue.record("Expected pathBetween for case \(i)")
            }

        default:
            let parsed = QueryParser.parse("similar to topic \(i)")
            switch parsed {
            case .semanticSearch(let query, let limit):
                #expect(query.contains("topic \(i)"))
                #expect(limit == 10)
            default:
                Issue.record("Expected semanticSearch for case \(i)")
            }
        }
    }
}

@Suite("Mass Generated Chat - NoteChatState 1000")
@MainActor
struct MassGeneratedChatNoteState1000Tests {
    @Test("mass generated note chat state lifecycle case", arguments: Array(0..<1000))
    func massGeneratedNoteChatStateLifecycle(_ i: Int) {
        let state = NoteChatState(pageId: "mass-generated-page-\(i)")

        state.isStreaming = true
        state.hasResponse = true
        state.appendStreamingText("token-\(i)")
        state.stopStreaming()

        #expect(!state.isStreaming)
        #expect(state.responseText.contains("token-\(i)"))

        state.acceptResponse()
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)

        state.clear()
        #expect(state.inputText.isEmpty)
        #expect(state.error == nil)
    }
}

@Suite("Mass Generated Library - Writer Style 1000")
struct MassGeneratedLibraryWriterStyle1000Tests {
    @Test("mass generated writer style case", arguments: Array(0..<1000))
    func massGeneratedWriterStyle(_ i: Int) {
        let style = AcademicStyle.allCases[i % AcademicStyle.allCases.count]
        #expect(!style.displayName.isEmpty)

        if style == .custom {
            #expect(style.presetValues == nil)
        } else {
            #expect(style.presetValues != nil)
        }

        let spacing = LineSpacing.allCases[i % LineSpacing.allCases.count]
        #expect(spacing.multiplier >= 1.0)

        let margins = PageMargins.allCases[i % PageMargins.allCases.count]
        #expect(margins.points > 0)

        let size = PageSize.allCases[i % PageSize.allCases.count].size
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
// END MASS GENERATED TESTS

