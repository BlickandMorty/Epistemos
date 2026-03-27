import Testing
@testable import Epistemos

@MainActor
private func makeReasoningService() -> ReasoningLoopService {
    let triage = AppBootstrap.shared?.triageService ?? TriageService(
        inference: InferenceState(),
        localLLMService: nil,
        cloudLLMService: nil
    )
    return ReasoningLoopService(triageService: triage)
}

// MARK: - Quality Score Parsing Tests

@Suite("ReasoningLoop — Quality Score Parsing")
@MainActor
struct ReasoningLoopScoreTests {

    @Test("Parses explicit 'Score: 0.85' format")
    func parseExplicitScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "The reasoning is solid. Score: 0.85")
        #expect(score == 0.85)
    }

    @Test("Parses 'quality: 0.7' format (case insensitive)")
    func parseQualityLabel() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Quality: 0.7 — needs more detail")
        #expect(score == 0.7)
    }

    @Test("Parses 'confidence: 0.92' format")
    func parseConfidenceLabel() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Confidence: 0.92")
        #expect(score == 0.92)
    }

    @Test("Parses standalone decimal in 0-1 range")
    func parseStandaloneDecimal() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "The answer is adequate. 0.65")
        #expect(score == 0.65)
    }

    @Test("Parses integer score as fraction of 10")
    func parseIntegerScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 8")
        #expect(score == 0.8)
    }

    @Test("Returns 0.5 for unparseable text")
    func defaultForGarbage() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "This is great reasoning with no numbers!")
        #expect(score == 0.5)
    }

    @Test("Returns 0.5 for empty string")
    func defaultForEmpty() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "")
        #expect(score == 0.5)
    }

    @Test("Parses 1.0 as perfect score")
    func parsePerfectScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 1.0")
        #expect(score == 1.0)
    }

    @Test("Parses 0.0 as minimum score")
    func parseMinimumScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 0.0 — completely wrong")
        #expect(score == 0.0)
    }
}

// MARK: - Configuration Tests

@Suite("ReasoningLoop — Configuration")
@MainActor
struct ReasoningLoopConfigTests {

    @Test("Default config has reasoning disabled")
    func defaultDisabled() {
        let config = ReasoningLoopConfig()
        #expect(!config.enabled)
        #expect(config.qualityThreshold == 0.7)
        #expect(config.maxRounds == 5)
        #expect(config.enableToolUse)
        #expect(config.minComplexity == 0.40)
    }

    @Test("Low complexity operations should bypass reasoning")
    func lowComplexityBypass() {
        // .rewrite = 0.25, below 0.40 threshold
        #expect(NotesOperation.rewrite.baseComplexity < 0.40)
        #expect(NotesOperation.summarize.baseComplexity < 0.40)
        #expect(NotesOperation.continueWriting.baseComplexity < 0.40)
    }

    @Test("High complexity operations should engage reasoning")
    func highComplexityEngages() {
        #expect(NotesOperation.outline.baseComplexity >= 0.40)
        #expect(NotesOperation.expand.baseComplexity >= 0.40)
        #expect(NotesOperation.analyze.baseComplexity >= 0.40)
    }

    @Test("Complex ask queries cross the reasoning threshold once enabled")
    func complexAskEngagesWhenEnabled() {
        let service = makeReasoningService()
        service.config.enabled = true

        let query = "Compare Bayesian and evidential decision theory across uncertainty, Dutch book arguments, dynamic inconsistency, and practical planning tradeoffs."
        let complexity = service.effectiveComplexity(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        )

        #expect(complexity >= service.config.minComplexity)
        #expect(service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        ))
    }

    @Test("Simple ask queries stay on the direct path even when reasoning is enabled")
    func simpleAskBypassesWhenEnabled() {
        let service = makeReasoningService()
        service.config.enabled = true

        let query = "Summarize this."
        let complexity = service.effectiveComplexity(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        )

        #expect(complexity < service.config.minComplexity)
        #expect(!service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        ))
    }

    @Test("App bootstrap keeps the reasoning loop opt-in by default")
    func bootstrapDefaultsReasoningLoopToDisabled() {
        let bootstrap = AppBootstrap()
        #expect(!bootstrap.reasoningLoopService.config.enabled)
    }
}

// MARK: - Trace Logger Tests

@Suite("ReasoningLoop — Trace Logger")
@MainActor
struct ReasoningTraceLoggerTests {

    @Test("Single round produces one trace line")
    func singleRoundTrace() {
        let logger = ReasoningTraceLogger()
        let round = ReasoningRound(
            roundIndex: 0,
            thinkOutput: "The answer is 42.",
            critiqueOutput: "Score: 0.9 — solid reasoning.",
            qualityScore: 0.9,
            toolCalls: [],
            refinedOutput: "",
            durationMs: 1500
        )

        let lines = logger.logReasoningChain(
            query: "What is the meaning of life?",
            rounds: [round],
            finalAnswer: "The answer is 42.",
            totalDurationMs: 1500
        )

        // Single round → 1 per-round trace (no chain trace for single round)
        #expect(lines.count == 1)

        // Verify JSONL validity
        for line in lines {
            let data = Data(line.utf8)
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(parsed != nil)
            let messages = parsed?["messages"] as? [[String: Any]]
            #expect(messages?.count == 3) // system, user, assistant
        }
    }

    @Test("Multiple rounds produce per-round + chain traces")
    func multiRoundTrace() {
        let logger = ReasoningTraceLogger()
        let rounds = [
            ReasoningRound(
                roundIndex: 0,
                thinkOutput: "Initial thought",
                critiqueOutput: "Score: 0.4 — needs more info",
                qualityScore: 0.4,
                toolCalls: [ToolCallRecord(toolName: "vault_search", query: "life meaning", result: "found stuff", durationMs: 50)],
                refinedOutput: "Refined with search results",
                durationMs: 2000
            ),
            ReasoningRound(
                roundIndex: 1,
                thinkOutput: "Better thought",
                critiqueOutput: "Score: 0.8 — good",
                qualityScore: 0.8,
                toolCalls: [],
                refinedOutput: "",
                durationMs: 1000
            ),
        ]

        let lines = logger.logReasoningChain(
            query: "Deep question",
            rounds: rounds,
            finalAnswer: "Better thought",
            totalDurationMs: 3000
        )

        // 2 per-round traces + 1 chain trace = 3
        #expect(lines.count == 3)
    }

    @Test("Empty rounds produce no traces")
    func emptyRounds() {
        let logger = ReasoningTraceLogger()
        let lines = logger.logReasoningChain(
            query: "test",
            rounds: [],
            finalAnswer: "",
            totalDurationMs: 0
        )
        #expect(lines.isEmpty)
    }

    @Test("Traces are valid JSONL with messages array")
    func validJsonl() {
        let logger = ReasoningTraceLogger()
        let round = ReasoningRound(
            roundIndex: 0,
            thinkOutput: "Think output with \"quotes\" and\nnewlines",
            critiqueOutput: "Score: 0.75",
            qualityScore: 0.75,
            toolCalls: [],
            refinedOutput: "",
            durationMs: 500
        )

        let lines = logger.logReasoningChain(
            query: "Test with special chars: <>&\"'",
            rounds: [round],
            finalAnswer: "Answer",
            totalDurationMs: 500
        )

        #expect(lines.count == 1)

        let data = Data(lines[0].utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)

        let messages = parsed?["messages"] as? [[String: String]]
        #expect(messages?[0]["role"] == "system")
        #expect(messages?[1]["role"] == "user")
        #expect(messages?[2]["role"] == "assistant")
    }
}

// Note: ODIATraceType.reasoning is tested in OmegaODIATraceTests.swift.
// The two ODIATrace definitions (Omega/Knowledge vs KnowledgeFusion/SyntheticData)
// create ambiguity in the test target, so we test the enum case there instead.
