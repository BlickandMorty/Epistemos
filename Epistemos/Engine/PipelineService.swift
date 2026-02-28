import Foundation
import Synchronization
import os

// MARK: - Finish-Once Guard

/// Thread-safe guard that ensures an AsyncThrowingStream.Continuation
/// is finished exactly once, even when called from multiple tasks.
private final class FinishOnce: Sendable {
    private let done = Mutex(false)

    /// Returns `true` exactly once — all subsequent calls return `false`.
    nonisolated func tryFinish() -> Bool {
        done.withLock { done in
            guard !done else { return false }
            done = true
            return true
        }
    }
}

// MARK: - Pipeline Error

nonisolated enum PipelineError: LocalizedError {
    case noLLMService
    case analysisFailure(String)

    var errorDescription: String? {
        switch self {
        case .noLLMService: "No LLM provider configured. Add an API key in Settings."
        case .analysisFailure(let msg): msg
        }
    }
}

// MARK: - Pipeline Service
// Orchestrates the analytical pipeline with 3 API calls total:
// Call 1: Streaming direct answer (Pass 1 — user sees immediately)
// Call 2: Deep research analysis (Pass 2 — Epistemic Lens, background)
// Call 3: Consolidated enrichment (summary + reflection + arbitration + truth, background)

@MainActor
final class PipelineService {

    // MARK: - Dependencies

    private let pipelineState: PipelineState
    private let llmService: any LLMClientProtocol
    private let triageService: TriageService
    private let eventBus: EventBus
    private var soarService: SOARService?

    init(
        pipelineState: PipelineState,
        llmService: any LLMClientProtocol,
        triageService: TriageService,
        eventBus: EventBus,
        soarService: SOARService? = nil
    ) {
        self.pipelineState = pipelineState
        self.llmService = llmService
        self.triageService = triageService
        self.eventBus = eventBus
        self.soarService = soarService
    }

    // MARK: - Active Tasks
    // pipelineTask: cancelled on new query or stop.
    // enrichmentTask: only cancelled on explicit stop — survives new queries.
    private var pipelineTask: Task<Void, Never>?
    private var enrichmentTask: Task<Void, Never>?

    /// Cancel enrichment explicitly (stop button). New queries do NOT cancel enrichment.
    func cancelAllEnrichment() {
        enrichmentTask?.cancel()
        enrichmentTask = nil
    }

    // MARK: - Run Pipeline

    /// Execute the full analytical pipeline for a user query.
    /// When `skipEnrichment` is true, enrichment calls 2-3 are skipped entirely (no Lucid Lens API calls).
    /// `conversationHistory` provides prior User/Assistant turns for multi-turn context.
    /// `onEnriched` delivers enrichment results directly (bypasses the stream) so results
    /// survive query cancellation — the callback is captured by the detached enrichment task.
    func run(
        query: String,
        mode: InferenceMode,
        context: ConversationContext? = nil,
        controls: PipelineControls = .default,
        steeringBias: SteeringBias? = nil,
        soarConfig: SOARConfig? = nil,
        reroute: RerouteInstruction? = nil,
        notesContext: String? = nil,
        skipEnrichment: Bool = false,
        conversationHistory: String? = nil,
        onEnriched: (@MainActor @Sendable (DualMessage, TruthAssessment) -> Void)? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        // Cancel the previous Pass 1 generation, but NOT enrichment —
        // previous enrichment continues in the background and delivers via callback.
        pipelineTask?.cancel()
        pipelineTask = nil

        // Thread-safe guard: ensures continuation.finish() is called exactly once.
        let finisher = FinishOnce()

        return AsyncThrowingStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pipelineTask?.cancel()
                    // Don't cancel enrichment on stream termination — it delivers via callback
                }
            }

            let mainTask = Task { @MainActor [weak self] in
                guard let self else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }
                do {
                    pipelineState.startProcessing()

                    // Step 1: Analyze query
                    let queryAnalysis = QueryAnalyzer.analyze(query: query, context: context)

                    // Generate signals
                    let signals = SignalGenerator.generate(
                        queryAnalysis: queryAnalysis,
                        controls: controls,
                        steeringBias: steeringBias
                    )

                    let baselineSignals = BaselineSignals(
                        confidence: signals.confidence,
                        entropy: signals.entropy,
                        dissonance: signals.dissonance,
                        healthScore: signals.healthScore
                    )

                    // Update signals in state
                    pipelineState.updateSignals(
                        SignalUpdate(
                            confidence: signals.confidence,
                            entropy: signals.entropy,
                            dissonance: signals.dissonance,
                            healthScore: signals.healthScore,
                            safetyState: signals.safetyState,
                            riskScore: signals.riskScore,
                            focusDepth: signals.focusDepth,
                            temperatureScale: signals.temperatureScale,
                            concepts: signals.concepts
                        ))

                    // Run through pipeline stages
                    for stage in PipelineStage.allCases {
                        guard !Task.isCancelled else {
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }
                        let detail = PromptComposer.generateStageDetail(stage: stage, queryAnalysis: queryAnalysis)

                        let startResult = StageResult(
                            stage: stage,
                            status: .running,
                            data: nil,
                            durationMs: nil,
                            error: nil,
                            detail: detail,
                            value: nil
                        )
                        pipelineState.advanceStage(stage, result: startResult)
                        continuation.yield(.stageAdvanced(stage, startResult))

                        try await Task.sleep(for: .milliseconds(20))

                        // Check for SOAR engagement on triage stage
                        if stage == .triage,
                            let soarCfg = soarConfig,
                            soarCfg.enabled,
                            let soars = soarService
                        {
                            let probe = soars.probeLearnability(
                                queryAnalysis: queryAnalysis,
                                priorSignals: baselineSignals
                            )

                            if probe.atEdge {
                                let soarSession = try await soars.runSOAR(
                                    query: query,
                                    queryAnalysis: queryAnalysis,
                                    baselineSignals: baselineSignals,
                                    inferenceMode: mode
                                )

                                if let finalSignals = soarSession.finalSignals {
                                    pipelineState.updateSignals(
                                        SignalUpdate(
                                            confidence: finalSignals.confidence,
                                            entropy: finalSignals.entropy,
                                            dissonance: finalSignals.dissonance,
                                            healthScore: finalSignals.healthScore
                                        ))
                                }

                                continuation.yield(
                                    .soarEvent(
                                        .sessionComplete,
                                        [
                                            "overallImproved": .bool(soarSession.overallImproved),
                                            "iterationsCompleted": .int(
                                                soarSession.iterationsCompleted),
                                        ]))
                            }
                        }

                        let completeResult = StageResult(
                            stage: stage,
                            status: .completed,
                            data: nil,
                            durationMs: 100,
                            error: nil,
                            detail: detail,
                            value: Double.random(in: 0.6...0.95)
                        )
                        pipelineState.advanceStage(stage, result: completeResult)
                        continuation.yield(.stageAdvanced(stage, completeResult))
                    }

                    // ── Pass 1: Stream the direct LLM answer token-by-token ──────────────
                    var tokenChunks: [String] = []
                    let directStream = generateDirectStream(
                        query: query,
                        queryAnalysis: queryAnalysis,
                        signals: signals,
                        controls: controls,
                        steeringBias: steeringBias,
                        soarConfig: soarConfig,
                        reroute: reroute,
                        notesContext: notesContext,
                        chatMode: skipEnrichment ? .plain : .research,
                        conversationHistory: conversationHistory
                    )
                    var insideThinking = false
                    var thinkingBuffer = ""
                    var textBuffer = ""

                    for try await token in directStream {
                        tokenChunks.append(token)
                        textBuffer += token

                        // Check for opening tag
                        if let openRange = textBuffer.range(of: "<thinking>") {
                            // Flush text before the tag as visible text
                            let before = String(
                                textBuffer[textBuffer.startIndex..<openRange.lowerBound])
                            if !before.isEmpty {
                                continuation.yield(.textDelta(before))
                            }
                            textBuffer = String(textBuffer[openRange.upperBound...])
                            insideThinking = true
                        }

                        if insideThinking {
                            // Check for closing tag
                            if let closeRange = textBuffer.range(of: "</thinking>") {
                                let thought = String(
                                    textBuffer[textBuffer.startIndex..<closeRange.lowerBound])
                                if !thought.isEmpty {
                                    thinkingBuffer += thought
                                    continuation.yield(.deliberationDelta(thought))
                                }
                                textBuffer = String(textBuffer[closeRange.upperBound...])
                                insideThinking = false
                                // Flush any remaining text after the closing tag
                                if !textBuffer.isEmpty {
                                    continuation.yield(.textDelta(textBuffer))
                                    textBuffer = ""
                                }
                            } else {
                                // Inside thinking — yield buffered content as deliberation
                                // Keep last 20 chars in buffer in case closing tag spans tokens
                                if textBuffer.count > 20 {
                                    let flushEnd = textBuffer.index(
                                        textBuffer.endIndex, offsetBy: -20)
                                    let flush = String(textBuffer[textBuffer.startIndex..<flushEnd])
                                    continuation.yield(.deliberationDelta(flush))
                                    thinkingBuffer += flush
                                    textBuffer = String(textBuffer[flushEnd...])
                                }
                            }
                        } else {
                            // Normal text — flush
                            if !textBuffer.isEmpty {
                                continuation.yield(.textDelta(textBuffer))
                                textBuffer = ""
                            }
                        }
                    }

                    // Flush any remaining buffer
                    if !textBuffer.isEmpty {
                        if insideThinking {
                            continuation.yield(.deliberationDelta(textBuffer))
                        } else {
                            continuation.yield(.textDelta(textBuffer))
                        }
                    }
                    var rawAnswerBuffer = tokenChunks.joined()

                    // Guard: if the answer is empty or trivially short, treat as error — don't
                    // create a completed message with placeholder metrics.
                    let trimmedAnswer = rawAnswerBuffer.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    guard trimmedAnswer.count >= 10 else {
                        let reason =
                            trimmedAnswer.isEmpty ? "No response received" : "Response too short"
                        continuation.yield(.error("\(reason) — check your API key in Settings."))
                        pipelineState.completeProcessing()
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    // Replace placeholder concepts with real ones from the LLM's [CONCEPTS: ...] tag.
                    // If the LLM included the tag, parse it and strip it from displayed text.
                    // Fall back to regex heuristic extraction if no tag found.
                    let (llmConcepts, cleanedAnswer) = EnrichmentController.parseConceptsTag(from: rawAnswerBuffer)
                    if !llmConcepts.isEmpty {
                        rawAnswerBuffer = cleanedAnswer
                        pipelineState.updateSignals(SignalUpdate(concepts: llmConcepts))
                    } else {
                        let extractedConcepts = EnrichmentController.extractResponseConcepts(
                            from: rawAnswerBuffer,
                            queryEntities: queryAnalysis.entities
                        )
                        if !extractedConcepts.isEmpty {
                            pipelineState.updateSignals(SignalUpdate(concepts: extractedConcepts))
                        }
                    }

                    // ── Fire .completed immediately so the user sees their answer ─────
                    // rawAnalysis is empty here — the real research prose arrives via
                    // .enriched after Pass 2. This prevents the "clone" bug where
                    // the Lucid Lens panel showed a duplicate of the streaming answer.
                    let minimalDualMessage = DualMessage(
                        rawAnalysis: skipEnrichment ? rawAnswerBuffer : "",
                        uncertaintyTags: EnrichmentController.extractUncertaintyTags(from: rawAnswerBuffer),
                        modelVsDataFlags: []
                    )
                    continuation.yield(.completed(minimalDualMessage, nil))
                    pipelineState.completeProcessing()

                    // ── Calls 2-3: Background enrichment ─────────
                    // Skip enrichment entirely when the user has toggled it off.
                    // This saves 2 API calls per query.
                    guard !skipEnrichment else {
                        Log.pipeline.info(
                            "🔬 Enrichment: SKIPPED (regular mode) — no enrichment calls"
                        )
                        // Regular mode: no enrichment. Don't emit fake arbitration or
                        // placeholder truth — those are research-only features.
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    let capturedQuery = query
                    let capturedQueryAnalysis = queryAnalysis
                    let capturedSignals = signals
                    let capturedControls = controls
                    let capturedSteeringBias = steeringBias
                    let capturedSoarConfig = soarConfig
                    let capturedRawAnswerBuffer = rawAnswerBuffer
                    // Enrichment always uses Anthropic if a key is available.
                    // Kimi/OpenAI/Google produce thin or schema-non-compliant output for
                    // the complex JSON enrichment. The chat provider is independent.
                    let capturedLLM = llmService.enrichmentSnapshot()

                    // Early exit: if the enrichment snapshot has no usable API key
                    // (and isn't a local provider), skip enrichment entirely to avoid
                    // 2 failing HTTP requests that all return fallback values anyway.
                    // Ollama and Apple Intelligence don't need API keys — they run locally.
                    let enrichmentKeyValid =
                        !capturedLLM.apiKey.isEmpty
                        || capturedLLM.provider == .ollama
                        || capturedLLM.provider == .appleIntelligence
                    if !enrichmentKeyValid {
                        Log.pipeline.warning(
                            "🔬 Enrichment: SKIPPED (no API key for \(capturedLLM.provider.rawValue)) — yielding signal-derived fallback. Add an Anthropic API key in Settings for full research."
                        )
                        let fallbackArb = EnrichmentController.fallbackArbitration(signals: signals)
                        let fallbackTruth = EnrichmentController.fallbackTruthAssessment(signals: signals)
                        let noKeyDual = DualMessage(
                            rawAnalysis: "",
                            uncertaintyTags: EnrichmentController.extractUncertaintyTags(from: rawAnswerBuffer),
                            modelVsDataFlags: [],
                            laymanSummary: EnrichmentController.fallbackLaymanSummary(
                                queryAnalysis: queryAnalysis, signals: signals),
                            reflection: EnrichmentController.fallbackReflection(signals: signals),
                            arbitration: fallbackArb
                        )
                        onEnriched?(noKeyDual, fallbackTruth)
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    // Strong capture: PipelineService is held by AppBootstrap — no retain cycle.
                    // [weak self] caused silent enrichment death if momentary deallocation occurred.
                    let enrichTask = Task.detached(priority: .userInitiated) {
                        // Prevent macOS App Nap from suspending in-process network requests.
                        let napActivity = ProcessInfo.processInfo.beginActivity(
                            options: [.userInitiated, .idleSystemSleepDisabled],
                            reason: "Epistemos research enrichment (Calls 2-3)"
                        )
                        defer { ProcessInfo.processInfo.endActivity(napActivity) }

                        // Delivery guard: ensures onEnriched is called exactly once,
                        // even if timeout and normal completion race.
                        let deliveryGuard = FinishOnce()

                        Log.pipeline.info(
                            "🔬 Enrichment: STARTED — provider=\(capturedLLM.provider.rawValue) model=\(capturedLLM.model.prefix(30)) keyLen=\(capturedLLM.apiKey.count)"
                        )

                        guard !Task.isCancelled else {
                            Log.pipeline.warning(
                                "Enrichment: CANCELLED before starting — delivering full fallback"
                            )
                            let fallbackDual = DualMessage(
                                rawAnalysis: "",
                                uncertaintyTags: EnrichmentController.extractUncertaintyTags(
                                    from: capturedRawAnswerBuffer),
                                modelVsDataFlags: [],
                                laymanSummary: EnrichmentController.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: EnrichmentController.fallbackReflection(signals: capturedSignals),
                                arbitration: EnrichmentController.fallbackArbitration(signals: capturedSignals)
                            )
                            if deliveryGuard.tryFinish() {
                                await onEnriched?(
                                    fallbackDual,
                                    EnrichmentController.fallbackTruthAssessment(signals: capturedSignals))
                            }
                            return
                        }

                        let enrichmentStart = CFAbsoluteTimeGetCurrent()
                        Log.pipeline.info("🔬 Enrichment: starting Call 2 (Epistemic Lens analysis)")

                        // Safety timeout: 360s (6 min) global cutoff as a last resort.
                        // Call 2 (180s) + Call 3 (300s) = 480s theoretical max,
                        // but individual timeouts should fire first. 360s catches edge cases.
                        let timeoutTask = Task {
                            try await Task.sleep(for: .seconds(360))
                            guard !Task.isCancelled else { return }
                            let elapsed = CFAbsoluteTimeGetCurrent() - enrichmentStart
                            Log.pipeline.info(
                                "🔬 Enrichment: 360s global timeout exceeded (elapsed=\(String(format: "%.1f", elapsed))s), delivering full fallback"
                            )
                            let timeoutDual = DualMessage(
                                rawAnalysis: "",
                                uncertaintyTags: EnrichmentController.extractUncertaintyTags(
                                    from: capturedRawAnswerBuffer),
                                modelVsDataFlags: [],
                                laymanSummary: EnrichmentController.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: EnrichmentController.fallbackReflection(signals: capturedSignals),
                                arbitration: EnrichmentController.fallbackArbitration(signals: capturedSignals)
                            )
                            if deliveryGuard.tryFinish() {
                                await onEnriched?(
                                    timeoutDual,
                                    EnrichmentController.fallbackTruthAssessment(signals: capturedSignals))
                            }
                        }
                        defer { timeoutTask.cancel() }

                        // Note: stage progress for enrichment is NOT yielded to the stream
                        // because the stream is already finished at this point.
                        // Enrichment results are delivered via the onEnriched callback.

                        // Call 2: Deep research prose (180s timeout — heaviest pass, ~6000 tokens)
                        let pass2Start = CFAbsoluteTimeGetCurrent()
                        let rawAnalysis = await PipelineService.withTimeout(seconds: 180) {
                            await EnrichmentController.generateRawAnalysisAsync(
                                query: capturedQuery,
                                queryAnalysis: capturedQueryAnalysis,
                                signals: capturedSignals,
                                controls: capturedControls,
                                steeringBias: capturedSteeringBias,
                                soarConfig: capturedSoarConfig,
                                llm: capturedLLM
                            )
                        } ?? ""
                        let pass2Duration = CFAbsoluteTimeGetCurrent() - pass2Start
                        Log.pipeline.info(
                            "🔬 Call 2 done in \(String(format: "%.1f", pass2Duration))s — \(rawAnalysis.isEmpty ? "EMPTY (failed)" : "\(rawAnalysis.count) chars")"
                        )

                        guard !Task.isCancelled else {
                            Log.pipeline.info(
                                "Enrichment: cancelled after Call 2 — delivering partial+fallback")
                            let fallbackDual = DualMessage(
                                rawAnalysis: rawAnalysis,
                                uncertaintyTags: EnrichmentController.extractUncertaintyTags(
                                    from: rawAnalysis.isEmpty
                                        ? capturedRawAnswerBuffer : rawAnalysis),
                                modelVsDataFlags: [],
                                laymanSummary: EnrichmentController.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: EnrichmentController.fallbackReflection(signals: capturedSignals),
                                arbitration: EnrichmentController.fallbackArbitration(signals: capturedSignals)
                            )
                            if deliveryGuard.tryFinish() {
                                await onEnriched?(
                                    fallbackDual,
                                    EnrichmentController.fallbackTruthAssessment(signals: capturedSignals))
                            }
                            return
                        }

                        // Use Call 2 output if available; fall back to Call 1 text
                        let analysisText =
                            rawAnalysis.isEmpty ? capturedRawAnswerBuffer : rawAnalysis

                        // ── Call 3: Consolidated Enrichment (single LLM call) ──
                        // Produces summary + critique + arbitration + truth in one JSON response.

                        let consolidatedStart = CFAbsoluteTimeGetCurrent()
                        let consolidated = await PipelineService.withTimeout(seconds: 300) {
                            await EnrichmentController.generateConsolidatedEnrichment(
                                query: capturedQuery,
                                rawAnalysis: analysisText,
                                queryAnalysis: capturedQueryAnalysis,
                                signals: capturedSignals,
                                llm: capturedLLM
                            )
                        } ?? nil
                        let consolidatedDuration = CFAbsoluteTimeGetCurrent() - consolidatedStart

                        // Extract results — use consolidated if available, fall back per-field
                        let laymanSummary = consolidated?.laymanSummary
                            ?? EnrichmentController.fallbackLaymanSummary(queryAnalysis: capturedQueryAnalysis, signals: capturedSignals)
                        let reflection = consolidated?.reflection
                            ?? EnrichmentController.fallbackReflection(signals: capturedSignals)
                        let arbitration = consolidated?.arbitration
                            ?? EnrichmentController.fallbackArbitration(signals: capturedSignals)
                        let truthAssessment = consolidated?.truthAssessment
                            ?? EnrichmentController.fallbackTruthAssessment(signals: capturedSignals)

                        Log.pipeline.info(
                            "🔬 Consolidated enrichment done in \(String(format: "%.1f", consolidatedDuration))s — \(consolidated != nil ? "SUCCESS" : "FAILED (using fallbacks)") truth=\(Int(truthAssessment.overallTruthLikelihood * 100))%"
                        )

                        let enrichedDual = DualMessage(
                            rawAnalysis: rawAnalysis,
                            uncertaintyTags: EnrichmentController.extractUncertaintyTags(from: analysisText),
                            modelVsDataFlags: [],
                            laymanSummary: laymanSummary,
                            reflection: reflection,
                            arbitration: arbitration
                        )

                        let totalEnrichment = CFAbsoluteTimeGetCurrent() - enrichmentStart
                        Log.pipeline.info(
                            "🔬 Enrichment: COMPLETE in \(String(format: "%.1f", totalEnrichment))s — rawLen=\(rawAnalysis.count) layman=\(laymanSummary.whatWasTried.prefix(40)) reflection=\(reflection.selfCriticalQuestions.count)q arbitration=\(arbitration.votes.count)v truth=\(Int(truthAssessment.overallTruthLikelihood * 100))%"
                        )
                        if deliveryGuard.tryFinish() {
                            await onEnriched?(enrichedDual, truthAssessment)
                        }
                    }

                    self.enrichmentTask = enrichTask

                    // Stream is done — enrichment delivers via callback, not through the stream.
                    if finisher.tryFinish() { continuation.finish() }

                } catch {
                    pipelineState.setError(error.localizedDescription)
                    continuation.yield(.error(error.localizedDescription))
                    if finisher.tryFinish() { continuation.finish() }
                }
            }

            // Store for cancellation — lightweight MainActor hop
            Task { @MainActor [weak self] in
                self?.pipelineTask = mainTask
            }
        }
    }

    // MARK: - Pass 1: Direct Streaming Answer

    private func generateDirectStream(
        query: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        controls: PipelineControls,
        steeringBias: SteeringBias?,
        soarConfig: SOARConfig?,
        reroute: RerouteInstruction? = nil,
        notesContext: String? = nil,
        chatMode: AnalyticalMode = .plain,
        conversationHistory: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let directives = PromptComposer.compose(
            controls: controls,
            steeringBias: steeringBias,
            soarConfig: soarConfig,
            reroute: reroute,
            analyticsEngineEnabled: true,
            chatMode: chatMode
        )

        let notesSection: String
        if let nc = notesContext {
            notesSection = """

                ## User's Knowledge Vault
                The user has a personal knowledge vault attached. Note titles, metadata, and any @-referenced bodies are below.

                Instructions:
                - When the query relates to topics in their notes, reference specific notes by title and quote content
                - When the query is unrelated to their notes, answer from general knowledge WITHOUT mentioning the vault
                - If the user explicitly asks about their notes or uses @-mentions, always engage with vault content
                - Be clear about what their notes say vs. what you know from training data
                - Identify contradictions, evolving ideas, and gaps across notes when relevant

                \(nc)
                """
        } else {
            notesSection = ""
        }

        Log.pipeline.info(
            "🔬 generateDirectStream — chatMode=\(chatMode == .research ? "RESEARCH" : "PLAIN") queryLen=\(query.count)"
        )

        let systemPrompt: String
        switch chatMode {
        case .research:
            systemPrompt = """
                \(EnrichmentController.systemPreamble)
                \(EnrichmentController.evidenceHierarchy)

                \(directives.isEmpty ? "" : directives + "\n\n")You are answering a research query. Structure your response as follows:

                RESPONSE STRUCTURE:
                1. **Direct answer** (1-2 paragraphs) — State your position clearly. What does the weight of evidence say? At what confidence level?
                2. **Evidence and reasoning** (2-4 paragraphs) — Present the strongest evidence supporting your answer. Reference specific studies, effect sizes, or theoretical frameworks. State which tier of the evidence hierarchy each claim rests on.
                3. **The honest reckoning** (1-2 paragraphs) — Name the uncomfortable truth that most analyses avoid. What is the thing people don't want to say out loud? State it directly, then interrogate it. If a correlation makes us uncomfortable, that discomfort is data — analyze why. Ask "what INPUTS produced this OUTPUT?" rather than stopping at surface description. Show the causal chain: systemic conditions → behavioral outputs → how those outputs get misattributed.
                4. **Counterarguments and paradoxes** (1-2 paragraphs) — Steel-man the 2-3 strongest objections. Where does your own analysis contain tension or contradiction? Name it. If the question itself contains a false premise, say so. Engage counterarguments as a mind wrestling with them in real time — "But here's the paradox...", "This raises the question..." — not as a list of objections you've pre-dismissed.
                5. **Nuance and open questions** (1-2 paragraphs) — What important caveats, boundary conditions, or contextual factors affect the answer? Where does expert opinion genuinely diverge? End with the questions this analysis opens rather than a tidy conclusion. What remains unknown, contested, or unstudied?
                6. **## Sources & References** — List key studies, papers, or authoritative sources. Include author(s), year, title. Only cite sources you are confident exist. If a claim rests on broad scientific consensus rather than a specific paper, say so.

                INTELLECTUAL HONESTY PRINCIPLES:
                - Never smooth over contradictions in the evidence. Name them, sit with them, analyze them.
                - If the data points somewhere uncomfortable, follow it. Then contextualize it. The goal is not to make the reader comfortable — it is to make them informed.
                - Distinguish between what the data says and what narratives people build around the data. Both matter, but they are not the same thing.
                - When analyzing human behavior, always ask what systemic and historical inputs produced the observed output before attributing it to individual character.
                - Acknowledge when your analysis itself contains a performative tension (e.g., arguing against certainty with certainty). That meta-awareness is a feature, not a bug.

                Use markdown formatting (headers, bold, bullets). Aim for \(queryAnalysis.complexity > 0.6 ? "8-12" : "5-8") paragraphs scaled to complexity (\(String(format: "%.1f", queryAnalysis.complexity))/1.0). Write as a mind in motion — show the reasoning encountering resistance and pushing through it. Be direct — never hedge when evidence is strong; never overclaim when evidence is weak.

                Domain: \(queryAnalysis.domain.rawValue) | Type: \(queryAnalysis.questionType.rawValue) | Entities: \(queryAnalysis.entities.prefix(4).joined(separator: ", "))\(notesSection)
                """

        case .plain:
            systemPrompt = """
                You are Epistemos, an intelligent assistant. Be helpful, accurate, and thorough.

                \(directives.isEmpty ? "" : directives + "\n\n")Answer the user's question directly and completely. Use markdown formatting where helpful (headers, bold, bullets, code blocks). Write naturally — match your depth and length to the complexity of the question.

                For simple questions, be concise. For complex questions, provide detailed explanations with examples. Always be honest about uncertainty.\(notesSection)
                """
        }

        // Inject conversation history for multi-turn context
        let finalSystemPrompt: String
        let finalPrompt: String
        if let history = conversationHistory, !history.isEmpty {
            finalSystemPrompt =
                systemPrompt
                + "\n\nThe user's message includes recent conversation history formatted as 'User:' and 'Assistant:' turns. Respond only to the latest User message, using prior turns for context."
            finalPrompt = history + "\n\nUser: " + query
        } else {
            finalSystemPrompt = systemPrompt
            finalPrompt = query
        }

        Log.pipeline.info(
            "🔬 systemPrompt length=\(finalSystemPrompt.count) chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: finalSystemPrompt,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count
        )
    }

    // MARK: - Per-Pass Timeout

    /// Run an async operation with a timeout. Returns nil if the timeout elapses.
    nonisolated private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { try? await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    // MARK: - Signal Override

    func applySignalOverride(signal: String, value: Double) {
        var update = SignalUpdate()
        switch signal {
        case "confidence": update.confidence = value
        case "entropy": update.entropy = value
        case "dissonance": update.dissonance = value
        case "health": update.healthScore = value
        default: break
        }
        pipelineState.updateSignals(update)
    }
}

// MARK: - String Extension

extension String {
    nonisolated func ifEmpty(_ defaultValue: String) -> String {
        isEmpty ? defaultValue : self
    }
}
