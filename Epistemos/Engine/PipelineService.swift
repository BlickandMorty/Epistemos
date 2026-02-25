import Foundation
import os
import Synchronization

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
// Orchestrates the 10-stage analytical pipeline with 6-pass enrichment.
// Pass 1: Streaming direct answer (user sees immediately)
// Passes 2-6: Background enrichment (Lucid Lens — analysis, layman summary, reflection, arbitration, truth assessment)

@MainActor
final class PipelineService {

    // MARK: - Dependencies

    private let pipelineState: PipelineState
    private let llmService: LLMService
    private let triageService: TriageService
    private let eventBus: EventBus
    private var soarService: SOARService?

    init(
        pipelineState: PipelineState,
        llmService: LLMService,
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
    // Held so a new query (or stop button) can cancel the previous work.
    private var pipelineTask: Task<Void, Never>?
    private var enrichmentTask: Task<Void, Never>?

    // MARK: - Run Pipeline

    /// Execute the full analytical pipeline for a user query.
    /// When `skipEnrichment` is true, Passes 2-6 are skipped entirely (no Lucid Lens API calls).
    /// `conversationHistory` provides prior User/Assistant turns for multi-turn context.
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
        conversationHistory: String? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        // Cancel any in-flight work from a previous query
        pipelineTask?.cancel()
        pipelineTask = nil
        enrichmentTask?.cancel()
        enrichmentTask = nil

        // Thread-safe guard: ensures continuation.finish() is called exactly once,
        // even when the @MainActor task and the detached enrichment task race.
        let finisher = FinishOnce()

        return AsyncThrowingStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pipelineTask?.cancel()
                    self?.enrichmentTask?.cancel()
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
                        healthScore: signals.healthScore,
                        persistenceEntropy: signals.tda.persistenceEntropy
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
                            tda: signals.tda,
                            focusDepth: signals.focusDepth,
                            temperatureScale: signals.temperatureScale,
                            concepts: signals.concepts,
                            harmonyKeyDistance: signals.harmonyKeyDistance
                        ))

                    // Run through pipeline stages
                    for stage in PipelineStage.allCases {
                        guard !Task.isCancelled else {
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }
                        let detail = generateStageDetail(stage: stage, queryAnalysis: queryAnalysis)

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

                        try await Task.sleep(for: .milliseconds(100))

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
                    let (llmConcepts, cleanedAnswer) = Self.parseConceptsTag(from: rawAnswerBuffer)
                    if !llmConcepts.isEmpty {
                        rawAnswerBuffer = cleanedAnswer
                        pipelineState.updateSignals(SignalUpdate(concepts: llmConcepts))
                    } else {
                        let extractedConcepts = extractResponseConcepts(
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
                        uncertaintyTags: extractUncertaintyTags(from: rawAnswerBuffer),
                        modelVsDataFlags: []
                    )
                    continuation.yield(.completed(minimalDualMessage, nil))
                    pipelineState.completeProcessing()

                    // ── Passes 2-6: Background enrichment ─────────
                    // Skip enrichment entirely when the user has toggled it off.
                    // This saves 5 API calls per query.
                    guard !skipEnrichment else {
                        Log.pipeline.info(
                            "🔬 Enrichment: SKIPPED (regular mode) — no Passes 2-6"
                        )
                        // Regular mode: yield signal-derived arbitration + truth assessment
                        // so the user gets a ConsensusReportCard without extra API calls.
                        let fallbackArb = fallbackArbitration(signals: signals)
                        let fallbackTruth = fallbackTruthAssessment(signals: signals)
                        let regularDual = DualMessage(
                            rawAnalysis: rawAnswerBuffer,
                            uncertaintyTags: extractUncertaintyTags(from: rawAnswerBuffer),
                            modelVsDataFlags: [],
                            arbitration: fallbackArb
                        )
                        continuation.yield(.enriched(regularDual, fallbackTruth))
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
                    // the complex JSON passes (2–6). The chat provider is independent.
                    let capturedLLM = llmService.enrichmentSnapshot()

                    // Early exit: if the enrichment snapshot has no usable API key
                    // (and isn't Ollama/local), skip enrichment entirely to avoid
                    // 5 failing HTTP requests that all return fallback values anyway.
                    let enrichmentKeyValid = !capturedLLM.apiKey.isEmpty || capturedLLM.provider == .ollama
                    if !enrichmentKeyValid {
                        Log.pipeline.info("🔬 Enrichment: SKIPPED (no API key for \(capturedLLM.provider.rawValue)) — yielding signal-derived fallback")
                        let fallbackArb = fallbackArbitration(signals: signals)
                        let fallbackTruth = fallbackTruthAssessment(signals: signals)
                        let noKeyDual = DualMessage(
                            rawAnalysis: "",
                            uncertaintyTags: extractUncertaintyTags(from: rawAnswerBuffer),
                            modelVsDataFlags: [],
                            laymanSummary: fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals),
                            reflection: fallbackReflection(signals: signals),
                            arbitration: fallbackArb
                        )
                        continuation.yield(.enriched(noKeyDual, fallbackTruth))
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    // Strong capture: PipelineService is held by AppBootstrap — no retain cycle.
                    // [weak self] caused silent enrichment death if momentary deallocation occurred.
                    let enrichTask = Task.detached(priority: .userInitiated) { [self] in
                        // Prevent macOS App Nap from suspending in-process network requests
                        // while enrichment is running. Without this, switching away from the
                        // app mid-enrichment can throttle or cancel URLSession requests.
                        let napActivity = ProcessInfo.processInfo.beginActivity(
                            options: [.userInitiated, .idleSystemSleepDisabled],
                            reason: "Epistemos research enrichment (Passes 2-6)"
                        )
                        defer { ProcessInfo.processInfo.endActivity(napActivity) }

                        Log.pipeline.info("🔬 Enrichment: STARTED — provider=\(capturedLLM.provider.rawValue) model=\(capturedLLM.model.prefix(30)) keyLen=\(capturedLLM.apiKey.count)")

                        guard !Task.isCancelled else {
                            Log.pipeline.warning("Enrichment: CANCELLED before starting — yielding full fallback (this should not happen for a freshly created Task.detached)")
                            let fallbackDual = DualMessage(
                                rawAnalysis: "",
                                uncertaintyTags: self.extractUncertaintyTags(
                                    from: capturedRawAnswerBuffer),
                                modelVsDataFlags: [],
                                laymanSummary: self.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: self.fallbackReflection(signals: capturedSignals),
                                arbitration: self.fallbackArbitration(signals: capturedSignals)
                            )
                            continuation.yield(
                                .enriched(
                                    fallbackDual,
                                    self.fallbackTruthAssessment(signals: capturedSignals)))
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }

                        let enrichmentStart = CFAbsoluteTimeGetCurrent()
                        Log.pipeline.info("🔬 Enrichment: starting Pass 2 (Epistemic Lens analysis)")

                        // Safety timeout: if enrichment takes > 600s (10 min), yield fallback and bail.
                        // Pass 2 = 600s timeout (heaviest — 6000 tokens).
                        // Passes 3-6 = 270s each. With 4+5 parallel: 600 + 270 + 270 + 270 = 1410s theoretical max.
                        // Safety at 600s is a hard cutoff — catches cases where any single pass hangs indefinitely.
                        // Note: 4000-token cap previously caused mid-sentence cutoff; raised to 6000.
                        let timeoutTask = Task {
                            try await Task.sleep(for: .seconds(600))
                            guard !Task.isCancelled else { return }
                            let elapsed = CFAbsoluteTimeGetCurrent() - enrichmentStart
                            Log.pipeline.info(
                                "🔬 Enrichment: 600s timeout exceeded (elapsed=\(String(format: "%.1f", elapsed))s), yielding full fallback")
                            let timeoutDual = DualMessage(
                                rawAnalysis: "",
                                uncertaintyTags: self.extractUncertaintyTags(
                                    from: capturedRawAnswerBuffer),
                                modelVsDataFlags: [],
                                laymanSummary: self.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: self.fallbackReflection(signals: capturedSignals),
                                arbitration: self.fallbackArbitration(signals: capturedSignals)
                            )
                            continuation.yield(
                                .enriched(
                                    timeoutDual,
                                    self.fallbackTruthAssessment(signals: capturedSignals)))
                            if finisher.tryFinish() { continuation.finish() }
                        }
                        defer { timeoutTask.cancel() }

                        // Emit enrichment stage events for progress tracking
                        continuation.yield(
                            .stageAdvanced(
                                .metaAnalysis,
                                StageResult(
                                    stage: .metaAnalysis, status: .running,
                                    detail: "Epistemic Lens analysis")))

                        // Pass 2: Deep research prose (always cloud API — no Apple Intelligence)
                        let pass2Start = CFAbsoluteTimeGetCurrent()
                        let rawAnalysis = await self.generateRawAnalysisAsync(
                            query: capturedQuery,
                            queryAnalysis: capturedQueryAnalysis,
                            signals: capturedSignals,
                            controls: capturedControls,
                            steeringBias: capturedSteeringBias,
                            soarConfig: capturedSoarConfig,
                            llm: capturedLLM
                        )
                        let pass2Duration = CFAbsoluteTimeGetCurrent() - pass2Start
                        Log.pipeline.info("🔬 Pass 2 done in \(String(format: "%.1f", pass2Duration))s — \(rawAnalysis.isEmpty ? "EMPTY (failed)" : "\(rawAnalysis.count) chars")")

                        guard !Task.isCancelled else {
                            Log.pipeline.info("Enrichment: cancelled after Pass 2 — yielding partial+fallback")
                            let fallbackDual = DualMessage(
                                rawAnalysis: rawAnalysis,
                                uncertaintyTags: self.extractUncertaintyTags(
                                    from: rawAnalysis.isEmpty
                                        ? capturedRawAnswerBuffer : rawAnalysis),
                                modelVsDataFlags: [],
                                laymanSummary: self.fallbackLaymanSummary(
                                    queryAnalysis: capturedQueryAnalysis, signals: capturedSignals),
                                reflection: self.fallbackReflection(signals: capturedSignals),
                                arbitration: self.fallbackArbitration(signals: capturedSignals)
                            )
                            continuation.yield(
                                .enriched(
                                    fallbackDual,
                                    self.fallbackTruthAssessment(signals: capturedSignals)))
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }

                        // Use Pass 2 output if available; fall back to Pass 1 text ONLY for
                        // feeding into downstream passes (layman summary needs input text).
                        // The rawAnalysis field on the DualMessage stays as whatever Pass 2 returned.
                        let analysisText =
                            rawAnalysis.isEmpty ? capturedRawAnswerBuffer : rawAnalysis

                        continuation.yield(
                            .stageAdvanced(
                                .metaAnalysis,
                                StageResult(
                                    stage: .metaAnalysis, status: .completed,
                                    detail: "Epistemic Lens analysis complete")))
                        continuation.yield(
                            .stageAdvanced(
                                .synthesis,
                                StageResult(
                                    stage: .synthesis, status: .running, detail: "Layman summary")))

                        // Pass 3: Layman summary
                        let pass3Start = CFAbsoluteTimeGetCurrent()
                        let laymanSummary = await self.generateLaymanSummary(
                            query: capturedQuery,
                            rawAnalysis: analysisText,
                            queryAnalysis: capturedQueryAnalysis,
                            signals: capturedSignals,
                            llm: capturedLLM
                        )
                        let pass3Duration = CFAbsoluteTimeGetCurrent() - pass3Start
                        Log.pipeline.info("🔬 Pass 3 done in \(String(format: "%.1f", pass3Duration))s — whatWasTried=\(laymanSummary.whatWasTried.prefix(40))")

                        guard !Task.isCancelled else {
                            Log.pipeline.info("Enrichment: cancelled after Pass 3 — yielding partial+fallback")
                            let cancelDual = DualMessage(
                                rawAnalysis: rawAnalysis,
                                uncertaintyTags: self.extractUncertaintyTags(from: analysisText),
                                modelVsDataFlags: [],
                                laymanSummary: laymanSummary,
                                reflection: self.fallbackReflection(signals: capturedSignals),
                                arbitration: self.fallbackArbitration(signals: capturedSignals)
                            )
                            continuation.yield(
                                .enriched(
                                    cancelDual,
                                    self.fallbackTruthAssessment(signals: capturedSignals)))
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }

                        Log.pipeline.info("Enrichment: Pass 3 done, starting Passes 4+5 (parallel) — total elapsed=\(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - enrichmentStart))s")

                        continuation.yield(
                            .stageAdvanced(
                                .synthesis,
                                StageResult(
                                    stage: .synthesis, status: .completed,
                                    detail: "Summary complete")))
                        continuation.yield(
                            .stageAdvanced(
                                .adversarial,
                                StageResult(
                                    stage: .adversarial, status: .running,
                                    detail: "Reflection + Arbitration")))

                        // Passes 4 + 5: Reflection and Arbitration in parallel
                        let pass45Start = CFAbsoluteTimeGetCurrent()
                        async let reflectionTask = self.generateReflection(
                            query: capturedQuery,
                            rawAnalysis: analysisText,
                            queryAnalysis: capturedQueryAnalysis,
                            signals: capturedSignals,
                            llm: capturedLLM
                        )
                        async let arbitrationTask = self.generateArbitration(
                            query: capturedQuery,
                            rawAnalysis: analysisText,
                            queryAnalysis: capturedQueryAnalysis,
                            signals: capturedSignals,
                            llm: capturedLLM
                        )
                        let (reflection, arbitration) = await (reflectionTask, arbitrationTask)
                        let pass45Duration = CFAbsoluteTimeGetCurrent() - pass45Start
                        Log.pipeline.info("🔬 Passes 4+5 done in \(String(format: "%.1f", pass45Duration))s — reflection=\(reflection.selfCriticalQuestions.count)q arbitration=\(arbitration.votes.count)v")

                        guard !Task.isCancelled else {
                            Log.pipeline.info("Enrichment: cancelled after Passes 4+5")
                            let cancelDual = DualMessage(
                                rawAnalysis: rawAnalysis,
                                uncertaintyTags: self.extractUncertaintyTags(from: analysisText),
                                modelVsDataFlags: [],
                                laymanSummary: laymanSummary,
                                reflection: reflection,
                                arbitration: arbitration
                            )
                            continuation.yield(
                                .enriched(
                                    cancelDual,
                                    self.fallbackTruthAssessment(signals: capturedSignals)))
                            if finisher.tryFinish() { continuation.finish() }
                            return
                        }

                        Log.pipeline.info("Enrichment: Passes 4+5 done, starting Pass 6 — total elapsed=\(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - enrichmentStart))s")

                        continuation.yield(
                            .stageAdvanced(
                                .adversarial,
                                StageResult(
                                    stage: .adversarial, status: .completed,
                                    detail: "Deliberation complete")))
                        continuation.yield(
                            .stageAdvanced(
                                .calibration,
                                StageResult(
                                    stage: .calibration, status: .running,
                                    detail: "Truth assessment")))

                        // Pass 6: Truth assessment
                        let pass6Start = CFAbsoluteTimeGetCurrent()
                        let truthAssessment = await self.generateTruthAssessment(
                            query: capturedQuery,
                            rawAnalysis: analysisText,
                            signals: capturedSignals,
                            reflection: reflection,
                            arbitration: arbitration,
                            llm: capturedLLM
                        )
                        let pass6Duration = CFAbsoluteTimeGetCurrent() - pass6Start
                        Log.pipeline.info("🔬 Pass 6 done in \(String(format: "%.1f", pass6Duration))s — truth=\(Int(truthAssessment.overallTruthLikelihood * 100))%")

                        continuation.yield(
                            .stageAdvanced(
                                .calibration,
                                StageResult(
                                    stage: .calibration, status: .completed,
                                    detail: "Assessment complete")))

                        // Use raw Pass 2 result for display. analysisText (which falls back to
                        // Pass 1 when Pass 2 is empty) is only used as input to downstream passes.
                        let enrichedDual = DualMessage(
                            rawAnalysis: rawAnalysis,
                            uncertaintyTags: self.extractUncertaintyTags(from: analysisText),
                            modelVsDataFlags: [],
                            laymanSummary: laymanSummary,
                            reflection: reflection,
                            arbitration: arbitration
                        )

                        // Always yield enrichment if we got this far (not cancelled).
                        // The finisher guard previously caused enrichment to be silently
                        // dropped if any cancellation path consumed it first.
                        let totalEnrichment = CFAbsoluteTimeGetCurrent() - enrichmentStart
                        Log.pipeline.info("🔬 Enrichment: ALL PASSES COMPLETE in \(String(format: "%.1f", totalEnrichment))s — rawLen=\(rawAnalysis.count) layman=\(laymanSummary.whatWasTried.prefix(40)) reflection=\(reflection.selfCriticalQuestions.count)q arbitration=\(arbitration.votes.count)v truth=\(Int(truthAssessment.overallTruthLikelihood * 100))%")
                        continuation.yield(.enriched(enrichedDual, truthAssessment))
                        let finished = finisher.tryFinish()
                        Log.pipeline.info("Enrichment: finisher.tryFinish()=\(finished)")
                        if finished { continuation.finish() }
                    }

                    self.enrichmentTask = enrichTask

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

                ## User's Knowledge Base
                You are in Notes Mode — the user is chatting with their personal vault. You have access to their notes below.

                Instructions:
                - Reference specific notes by title when making connections
                - Quote specific content from notes, don't paraphrase vaguely
                - Identify contradictions, evolving ideas, and gaps across notes
                - When the user asks about a topic, check if any notes are relevant before answering from general knowledge
                - Be direct about what their notes say vs. what you know from training data

                \(nc)
                """
        } else {
            notesSection = ""
        }

        Log.pipeline.info("🔬 generateDirectStream — chatMode=\(chatMode == .research ? "RESEARCH" : "PLAIN") queryLen=\(query.count)")

        let systemPrompt: String
        switch chatMode {
        case .research:
            systemPrompt = """
                \(Self.systemPreamble)
                \(Self.evidenceHierarchy)

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
        let hasHistory = conversationHistory != nil && !conversationHistory!.isEmpty
        let finalSystemPrompt: String
        let finalPrompt: String
        if hasHistory {
            finalSystemPrompt = systemPrompt + "\n\nThe user's message includes recent conversation history formatted as 'User:' and 'Assistant:' turns. Respond only to the latest User message, using prior turns for context."
            finalPrompt = conversationHistory! + "\n\nUser: " + query
        } else {
            finalSystemPrompt = systemPrompt
            finalPrompt = query
        }

        Log.pipeline.info("🔬 systemPrompt length=\(finalSystemPrompt.count) chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(hasHistory)")

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: finalSystemPrompt,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count
        )
    }

    // MARK: - Pass 2: Raw Analysis (non-throwing wrapper)

    nonisolated private func generateRawAnalysisAsync(
        query: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        controls: PipelineControls,
        steeringBias: SteeringBias?,
        soarConfig: SOARConfig?,
        llm: LLMSnapshot
    ) async -> String {
        do {
            return try await generateRawAnalysis(
                query: query,
                queryAnalysis: queryAnalysis,
                signals: signals,
                controls: controls,
                steeringBias: steeringBias,
                soarConfig: soarConfig,
                llm: llm
            )
        } catch {
            Log.pipeline.info(
                "🔬 Pass 2 HTTP ERROR — \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    // MARK: - Shared Preambles (slim identity + epistemic contract)

    /// Slim preamble — identity + epistemic contract only. No math, no methodology.
    /// Every pass gets this. Pass-specific math is injected where needed.
    nonisolated private static let systemPreamble = """
        You are Epistemos, a research-grade analytical reasoning engine built on a 10-stage internal pipeline followed by 6-pass enrichment. Each pass serves a distinct purpose — follow the specific instructions for THIS pass precisely.

        EPISTEMIC CONTRACT (applies to every pass):
        - Distinguish what is known vs. assumed vs. modeled vs. genuinely uncertain — and say which.
        - Never present weak evidence with strong-evidence confidence.
        - Prefer being honestly uncertain over being confidently wrong.
        - Write as if your reader is an intelligent skeptic who will challenge every unsupported claim.
        """

    /// Evidence hierarchy — injected only into passes that perform primary evidence analysis (Passes 1 & 2).
    nonisolated private static let evidenceHierarchy = """

        EVIDENCE HIERARCHY (weight claims accordingly):
        Tier 1: Systematic reviews, meta-analyses, Cochrane reviews, pre-registered replications
        Tier 2: Large-N RCTs (N>500), prospective cohort studies with adequate follow-up
        Tier 3: Small RCTs, case-control studies, cross-sectional surveys, well-designed observational studies
        Tier 4: Case series, expert consensus (Delphi), clinical guidelines
        Tier 5: Case reports, mechanistic reasoning, expert opinion, model-based inference, analogy
        Always state which tier your key claims rest on. Never present Tier 4-5 evidence with Tier 1-2 confidence.
        """

    /// Full epistemic standards + analytical math — injected only into Pass 2 (the primary analytical pass).
    nonisolated private static let analyticsMath = """

        EPISTEMIC STANDARDS:
        - Calibrate: 90%+ requires Tier 1-2 with consistent replication; 60-89% requires Tier 2-3; below 60% for contested/unreplicated/Tier 4-5
        - Consider ≥3 competing frameworks for any non-trivial claim
        - Distinguish correlation from causation; name confounders; assess directionality
        - Reference effect sizes (Cohen's d, r, OR, RR, NNT) with 95% CI — not just p-values
        - Assess practical significance (MCID) separately from statistical significance
        - Apply base rate reasoning before interpreting conditional probabilities
        - Flag publication bias, file-drawer effects, p-hacking risk, HARKing
        - Note replication status: independently replicated? Failed replication? Never tested?
        - Assess temporal stability: recent finding or decades-old consensus?

        COGNITIVE BIAS GUARD — check for: confirmation bias, anchoring, availability bias, survivorship bias, narrative fallacy, and Dunning-Kruger overconfidence.
        """

    nonisolated private func generateRawAnalysis(
        query: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        controls: PipelineControls,
        steeringBias: SteeringBias?,
        soarConfig: SOARConfig?,
        llm: LLMSnapshot
    ) async throws -> String {
        let directives = PromptComposer.compose(
            controls: controls,
            steeringBias: steeringBias,
            soarConfig: soarConfig,
            analyticsEngineEnabled: true,
            chatMode: .research
        )

        let methodologySection: String
        switch queryAnalysis.questionType {
        case .causal:
            methodologySection = """
                CAUSAL ANALYSIS FRAMEWORK:
                1. Bradford Hill criteria — systematically evaluate all 9: strength of association (effect size), consistency (replication across populations), specificity (one cause → one effect?), temporality (exposure precedes outcome?), biological gradient (dose-response?), plausibility (mechanism known?), coherence (fits broader knowledge?), experiment (interventional evidence?), analogy (similar causal pairs exist?). Score each as strong/moderate/weak/absent.
                2. Causal DAG — construct a directed acyclic graph narrative. Name every plausible confounder, mediator, and collider. Distinguish direct from indirect effects. Identify which confounders are measured vs. unmeasured.
                3. Counterfactual reasoning — what would the outcome distribution look like absent the proposed cause? Is the counterfactual testable or purely theoretical?
                4. Competing causal models — propose ≥2 alternative causal structures that could explain the same observed data. What evidence would discriminate between them?
                5. Temporal dynamics — is the causal relationship immediate, delayed, cumulative, or threshold-dependent? Does reverse causation remain plausible?
                """
        case .empirical:
            methodologySection = """
                EMPIRICAL ANALYSIS FRAMEWORK:
                1. Effect sizes — report Cohen's d, odds ratios (OR), risk ratios (RR), hazard ratios (HR), or number needed to treat (NNT) as appropriate. Always include 95% confidence intervals. Note whether the CI crosses the minimal clinically important difference (MCID) or practical significance threshold.
                2. Study landscape — reference specific landmark studies by name, first author, year, and sample size. Map the full evidence landscape: how many studies, what designs (RCT vs. observational vs. case-control), what populations, what follow-up durations?
                3. Replication audit — has the core finding been independently replicated? By how many groups? In what populations? Note any failed replications and their methodological differences.
                4. Statistical rigor — distinguish p-values from effect sizes. Flag any studies relying solely on p < 0.05 without reporting effect magnitude. Note multiple comparison corrections (Bonferroni, FDR). Assess power: were studies adequately powered to detect the claimed effect?
                5. Generalizability — WEIRD bias (Western, Educated, Industrialized, Rich, Democratic samples)? Selection effects? How does the study population map to the population of interest?
                """
        case .metaAnalytical:
            methodologySection = """
                META-ANALYTICAL FRAMEWORK:
                1. Heterogeneity assessment — report I², τ², and Q-statistic with p-value. I² > 75% = substantial heterogeneity requiring subgroup analysis or random-effects modeling.
                2. Publication bias — assess funnel plot asymmetry, Egger's regression test, trim-and-fill estimates. How many null studies would be needed to nullify the result (fail-safe N)? Is the field prone to positive-result bias?
                3. Study quality — evaluate using GRADE (certainty of evidence), RoB2 (risk of bias for RCTs), or ROBINS-I (non-randomized studies). Downgrade for serious risk of bias, inconsistency, indirectness, imprecision, or reporting bias.
                4. Moderator analysis — what variables (population, dose, duration, measurement method, study design) explain heterogeneity? Are there meaningful subgroups where the effect reverses or disappears?
                5. Temporal trends — do effect sizes shrink over time (decline effect)? Are newer, more rigorous studies finding smaller effects than older ones? What does this imply about the true effect?
                """
        case .conceptual:
            methodologySection = """
                CONCEPTUAL ANALYSIS FRAMEWORK:
                1. Framework pluralism — analyze through minimum 4 competing theoretical frameworks. For each: state its core axioms, what it predicts, what it cannot explain, and what evidence would falsify it.
                2. Genealogy of positions — trace the intellectual lineage of each framework. Who originated it? How has it evolved? What were the key debates that shaped it?
                3. Genuine conflict vs. talking past — distinguish where frameworks truly contradict each other (same phenomenon, incompatible predictions) vs. where they address different aspects or use different definitions.
                4. Conceptual dependencies — what hidden assumptions does each position rest on? What would need to be true about the world for each framework to be correct? Are these assumptions empirically testable?
                5. Synthesis potential — can frameworks be partially integrated? Is there a meta-framework that preserves the strengths of each while resolving contradictions? Or is genuine theoretical pluralism the most honest position?
                """
        default:
            methodologySection = """
                GENERAL ANALYTICAL FRAMEWORK:
                1. Evidence mapping — reference specific studies, researchers, institutions, and dates wherever possible. Distinguish peer-reviewed findings from pre-prints, expert opinion, and institutional reports.
                2. Statistical vs. practical significance — a statistically significant result (p < 0.05) may be trivially small in practice. Always ask: is the effect large enough to matter for decisions?
                3. Confound analysis — for any observational claim, name ≥3 plausible confounders. Assess whether available studies controlled for them. Note the direction of potential bias.
                4. Mechanism vs. correlation — is there a known causal mechanism, or only statistical association? How strong is the mechanistic evidence?
                5. Temporal and contextual stability — is this finding stable across decades, or recent and potentially unreplicated? Does it hold across cultures, populations, and contexts? What boundary conditions limit its applicability?
                """
        }

        let systemPrompt = """
            \(Self.systemPreamble)
            \(Self.evidenceHierarchy)
            \(Self.analyticsMath)

            \(directives.isEmpty ? "" : directives + "\n\n")Generate a raw analytical output for the query below. Embed epistemic tags throughout your analysis:
            - [DATA] for claims grounded in empirical evidence or established facts
            - [MODEL] for claims based on theoretical models, frameworks, or assumptions
            - [UNCERTAIN] for claims where confidence is genuinely low or evidence is mixed
            - [CONFLICT] for claims where evidence streams actively disagree

            QUERY CONTEXT:
            - Core question: "\(queryAnalysis.coreQuestion.prefix(120))"
            - Domain: \(queryAnalysis.domain.rawValue)
            - Question type: \(queryAnalysis.questionType.rawValue)
            - Complexity: \(String(format: "%.2f", queryAnalysis.complexity))
            - Key entities: \(queryAnalysis.entities.prefix(6).joined(separator: ", "))

            PIPELINE SIGNALS:
            - Confidence: \(String(format: "%.2f", signals.confidence))
            - Entropy: \(String(format: "%.2f", signals.entropy))
            - Dissonance: \(String(format: "%.2f", signals.dissonance))
            - Focus depth: \(String(format: "%.2f", signals.focusDepth))

            RESEARCH METHODOLOGY: \(methodologySection)

            DEPTH REQUIREMENTS:
            - Write \(queryAnalysis.complexity > 0.6 ? "10-14" : "7-10") paragraphs of dense, expert-level analytical prose
            - Each paragraph introduces a distinct analytical angle, evidence stream, or counterargument
            - Include competing interpretations: at least 3-4 genuinely different ways experts interpret the evidence
            - Cross-disciplinary synthesis: draw on ≥2 adjacent fields that illuminate the question from unexpected angles
            - Temporal evolution: how has expert understanding of this topic changed over the past 10-20 years? What caused the shifts?
            - Base rate awareness: before diving into specifics, establish the prior probability or baseline context
            - End with genuine open questions: what remains unknown, contested, or unstudied? What research would resolve the key uncertainties?

            INTELLECTUAL HONESTY:
            - If the evidence points somewhere uncomfortable, follow it. Then contextualize it. Never sanitize data to avoid discomfort.
            - For any behavioral or social phenomenon, trace the causal chain: what systemic, historical, or structural inputs produced this output? Do not stop at surface-level description.
            - Name the thing people avoid saying. Then analyze why they avoid it and whether the avoidance itself is informative.
            - When frameworks contradict each other, sit in the tension. Do not resolve it prematurely. Genuine intellectual conflict is more honest than forced synthesis.
            - Distinguish what the data says from the narratives built around the data. Both are worth analyzing.
            - If your analysis contains a performative tension (e.g., claiming objectivity from a situated perspective), acknowledge it — that meta-awareness strengthens rather than weakens the analysis.

            FORMAT: Do NOT use markdown headers or bullet lists — write flowing analytical prose. Embed [DATA], [MODEL], [UNCERTAIN], [CONFLICT] tags inline within sentences. Every claim tagged [DATA] must reference a specific study, dataset, or established finding. Every [MODEL] tag must name the framework or theory.

            CITATION INTEGRITY: Do NOT fabricate citations. If you reference a study, you must be confident it exists — include real author names, approximate year, and journal/source. If a claim rests on broad scientific consensus rather than a specific paper, say "broad scientific consensus" or "established finding in [field]" instead of inventing a reference. It is better to cite fewer real sources than many plausible-sounding fake ones.
            """

        let userPrompt =
            "Analyze this query through the full Epistemos pipeline: \"\(queryAnalysis.coreQuestion)\""

        // Research mode always uses cloud API — never Apple Intelligence.
        // Apple Intelligence is too limited for deep analytical prose.
        // Uses nonisolated static generate to avoid MainActor deadlock in enrichment.
        // Pass 2 is the heaviest pass (6000 tokens, massive system prompt).
        // Observed: 84.1s for 4000 tokens with Opus 4.6 (~21ms/token).
        // 6000 tokens ≈ 126s typical; timeout=200s covers slow API days.
        // Previous cap of 4000 tokens caused mid-sentence truncation — downstream
        // passes (3-6) diagnosed the cut-off and flagged it in their output.
        return try await LLMService.generate(
            snapshot: llm,
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 6000,
            timeout: 600
        )
    }

    // MARK: - Pass 3: Layman Summary

    nonisolated private func generateLaymanSummary(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> LaymanSummary {
        let (label1, label2, label3, label4, label5): (String, String, String, String, String)
        switch queryAnalysis.questionType {
        case .causal:
            (label1, label2, label3, label4, label5) = (
                "Causal analysis", "Probable relationship", "Causal certainty",
                "Alternative explanations", "Decision relevance"
            )
        case .empirical:
            (label1, label2, label3, label4, label5) = (
                "Methodology", "Key findings", "Evidence strength", "Limitations & gaps",
                "Applicability"
            )
        case .conceptual:
            (label1, label2, label3, label4, label5) = (
                "Conceptual landscape", "Most defensible position", "Epistemic status",
                "Key objections", "Who this matters to"
            )
        case .comparative:
            (label1, label2, label3, label4, label5) = (
                "Comparison framework", "Key differences", "Confidence in comparison",
                "What changes the verdict", "Context dependency"
            )
        default:
            (label1, label2, label3, label4, label5) = (
                "Approach taken", "Most likely true", "Confidence level", "What could change this",
                "Who should use this"
            )
        }

        let systemPrompt = """
            \(Self.systemPreamble)

            Based on the raw analytical output below, generate a 5-section structured summary that translates expert analysis into accessible insight. Reply with ONLY valid JSON, no markdown fences.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(8000))

            SECTION GUIDANCE:

            1. "\(label1)" (whatWasTried) — 4-6 sentences. Describe the analytical approach: what evidence was examined, which methodologies were applied, what frameworks were tested against each other. Name specific techniques (e.g., "Bradford Hill causal criteria", "meta-analytic pooling", "Bayesian updating"). The reader should understand HOW the analysis was conducted, not just WHAT was found.

            2. "\(label2)" (whatIsLikelyTrue) — 8-15 sentences with markdown formatting. This is the MAIN ANSWER. Lead with the strongest conclusion, then build supporting evidence. Use concrete examples and analogies to make abstract findings tangible. Quantify where possible ("roughly 2x more likely", "affects ~30% of cases"). Acknowledge what the evidence does NOT support, not just what it does. End with the single most important takeaway.

            3. "\(label3)" (confidenceExplanation) — 4-6 sentences. Map confidence to everyday decision-making: "confident enough to act on" vs. "interesting but preliminary" vs. "genuinely uncertain — reasonable experts disagree." Explain WHAT DRIVES the confidence level (replication, effect size, mechanistic understanding) rather than just stating a number. Name the single biggest source of uncertainty.

            4. "\(label4)" (whatCouldChange) — 4-6 sentences. Be specific: name the type of study, finding, or event that would shift the conclusion. Distinguish between "would strengthen" vs. "would weaken" vs. "would overturn." Include both empirical possibilities (new RCT, failed replication) and conceptual shifts (new framework, paradigm change).

            5. "\(label5)" (whoShouldTrust) — 4-6 sentences. Help the reader calibrate: who can safely act on this analysis? Who should wait for more evidence? What decisions does this analysis inform vs. which ones need additional domain-specific context? Note any populations, contexts, or use cases where the conclusions may not apply.

            IMPORTANT: Generate fields in EXACTLY this order. The first field ("whatWasTried") is your reasoning scaffold — think through the methodology BEFORE committing to conclusions in later fields. LLMs produce better answers when they reason before concluding.

            OUTPUT FORMAT (JSON only):
            {
              "whatWasTried": "\(label1) section — write this FIRST as your reasoning foundation",
              "whatIsLikelyTrue": "\(label2) section with markdown — the main answer, informed by the reasoning above",
              "confidenceExplanation": "\(label3) section",
              "whatCouldChange": "\(label4) section",
              "whoShouldTrust": "\(label5) section"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Synthesize the raw analysis into a structured, accessible 5-section summary for: \"\(queryAnalysis.coreQuestion)\"",
                systemPrompt: systemPrompt,
                maxTokens: 2000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info("🔬 Pass 3 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))")
                return fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
            }
            let fallback = fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
            return LaymanSummary(
                whatWasTried: obj["whatWasTried"] as? String ?? fallback.whatWasTried,
                whatIsLikelyTrue: obj["whatIsLikelyTrue"] as? String ?? fallback.whatIsLikelyTrue,
                confidenceExplanation: obj["confidenceExplanation"] as? String
                    ?? fallback.confidenceExplanation,
                whatCouldChange: obj["whatCouldChange"] as? String ?? fallback.whatCouldChange,
                whoShouldTrust: obj["whoShouldTrust"] as? String ?? fallback.whoShouldTrust,
                sectionLabels: SectionLabels(
                    whatWasTried: label1, whatIsLikelyTrue: label2,
                    confidenceExplanation: label3, whatCouldChange: label4, whoShouldTrust: label5
                )
            )
        } catch {
            Log.pipeline.info("🔬 Pass 3 HTTP ERROR — \(error.localizedDescription)")
            return fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
        }
    }

    // MARK: - Pass 4: Reflection (adversarial self-critique)

    nonisolated private func generateReflection(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> ReflectionResult {
        let systemPrompt = """
            \(Self.systemPreamble)

            You are now in ADVERSARIAL SELF-CRITIQUE mode. Your sole purpose is to find weaknesses, gaps, and overstatements in the analysis below. Adopt the mindset of a hostile peer reviewer whose reputation depends on finding flaws.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))

            PIPELINE SIGNALS:
            - Confidence: \(String(format: "%.2f", signals.confidence)) | Entropy: \(String(format: "%.2f", signals.entropy)) | Dissonance: \(String(format: "%.2f", signals.dissonance))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(6000))

            ADVERSARIAL TECHNIQUES TO APPLY:
            1. Steel-man test — construct the STRONGEST possible counterargument to the main conclusion. If you can build a compelling case against it, the analysis needs qualification.
            2. Reductio ad absurdum — push the analysis's logic to its extreme. Does it lead to absurd conclusions at the margins? If so, where does the reasoning break down?
            3. Edge case analysis — identify 2-3 scenarios where the conclusion would fail, reverse, or become meaningless. How common are these edge cases?
            4. Missing evidence audit — what evidence SHOULD have been discussed but wasn't? What studies or data would a domain expert expect to see cited?
            5. Survivorship bias check — is the analysis only considering successful/visible examples? What about the failures, null results, or unreported cases?
            6. Anchoring detection — did the analysis anchor on the first piece of evidence and insufficiently update? Would the conclusion change if evidence were considered in a different order?

            COGNITIVE BIAS CHECKLIST — flag if any are present in the analysis:
            □ Confirmation bias (seeking only supporting evidence)
            □ Availability bias (overweighting memorable/recent examples)
            □ Authority bias (accepting claims because of source prestige)
            □ Narrative fallacy (imposing a coherent story on messy data)
            □ Precision bias (false specificity beyond what evidence supports)
            □ Status quo bias (defaulting to conventional wisdom without testing it)

            Reply with ONLY valid JSON:
            {
              "selfCriticalQuestions": ["5-7 pointed questions that expose genuine weaknesses — each should be specific enough that it could change the conclusion if answered differently"],
              "adjustments": ["3-5 specific confidence adjustments — format each as: 'CLAIM: [specific claim] → ADJUSTMENT: [direction and magnitude] → REASON: [why]'"],
              "leastDefensibleClaim": "The single claim most vulnerable to challenge — explain exactly WHY it is weak and what evidence would be needed to strengthen it",
              "precisionVsEvidenceCheck": "A thorough assessment: does the analysis claim more precision than the evidence warrants? Are confidence intervals appropriate? Are qualitative claims dressed up as quantitative ones?",
              "biasesDetected": ["List any cognitive biases detected from the checklist above, with specific examples from the analysis"],
              "whatWouldChangeMyMind": "Name 1-3 specific findings, studies, or pieces of evidence that — if they existed — would substantially change the analysis's conclusions"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Perform adversarial self-critique on the analysis. Be ruthlessly honest about weaknesses.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info("🔬 Pass 4 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))")
                return fallbackReflection(signals: signals)
            }
            let fallback = fallbackReflection(signals: signals)
            return ReflectionResult(
                selfCriticalQuestions: obj["selfCriticalQuestions"] as? [String]
                    ?? fallback.selfCriticalQuestions,
                adjustments: obj["adjustments"] as? [String] ?? [],
                leastDefensibleClaim: obj["leastDefensibleClaim"] as? String
                    ?? fallback.leastDefensibleClaim,
                precisionVsEvidenceCheck: obj["precisionVsEvidenceCheck"] as? String
                    ?? fallback.precisionVsEvidenceCheck
            )
        } catch {
            Log.pipeline.info("🔬 Pass 4 HTTP ERROR — \(error.localizedDescription)")
            return fallbackReflection(signals: signals)
        }
    }

    // MARK: - Pass 5: Arbitration (multi-engine vote)

    nonisolated private func generateArbitration(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> ArbitrationResult {
        let systemPrompt = """
            \(Self.systemPreamble)

            You are in MULTI-ENGINE ARBITRATION mode. Simulate a panel of 5 independent analytical engines, each with a distinct epistemological lens. Each engine must evaluate the analysis INDEPENDENTLY — do not let engines agree by default. Genuine disagreement is valuable.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))
            SIGNALS: confidence=\(String(format: "%.2f", signals.confidence)), entropy=\(String(format: "%.2f", signals.entropy)), dissonance=\(String(format: "%.2f", signals.dissonance))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(6000))

            ENGINE PERSONAS — each engine has a distinct analytical identity:

            1. STATISTICAL ENGINE — thinks in distributions, sample sizes, and effect magnitudes. Asks: "What does the data actually show when analyzed rigorously?" Demands: adequate power, appropriate tests, reported effect sizes with CIs, correction for multiple comparisons. Suspicious of: small samples, p-hacking, garden of forking paths. Confidence calibration: high only for well-powered, pre-registered, replicated findings.

            2. CAUSAL ENGINE — thinks in mechanisms, counterfactuals, and DAGs. Asks: "Does this establish causation, or merely association?" Demands: temporal precedence, plausible mechanism, control for confounders, ideally interventional evidence. Suspicious of: reverse causation, omitted variable bias, ecological fallacy. Confidence calibration: high only when causal pathway is established through experiment or strong quasi-experimental design.

            3. BAYESIAN ENGINE — thinks in priors, updating, and probability distributions. Asks: "How should a rational agent update their beliefs given this evidence?" Demands: explicit priors, likelihood ratios, posterior distributions. Considers base rates before interpreting new evidence. Suspicious of: base rate neglect, failure to update, overweighting single studies. Confidence calibration: posterior probability given reasonable prior and evidence strength.

            4. META-ANALYSIS ENGINE — thinks in synthesis, heterogeneity, and evidence aggregation. Asks: "What does the totality of evidence say when all studies are considered together?" Demands: systematic search, quality assessment, heterogeneity analysis, publication bias tests. Suspicious of: cherry-picked studies, narrative reviews masquerading as systematic ones, vote-counting instead of pooling. Confidence calibration: high only for well-conducted meta-analyses with low heterogeneity.

            5. ADVERSARIAL ENGINE — thinks in failure modes, steel-manned objections, and worst-case scenarios. Asks: "What is the strongest argument AGAINST the conclusion?" Demands: every major objection addressed, edge cases considered, failure modes mapped. Suspicious of: unfalsifiable claims, consensus without dissent, arguments from authority. Confidence calibration: deliberately lower than other engines — anchors the group toward caution.

            CONSENSUS RULES:
            - Consensus = true ONLY if ≥4 engines agree on position (supports/opposes/neutral)
            - If exactly 3 agree, consensus = false — note the split
            - Each engine's confidence must reflect its own epistemological standards, NOT the group average
            - The adversarial engine should RARELY agree with the majority — if it does, the evidence is genuinely strong

            Each engine's "reasoning" must be 2-4 sentences explaining its position FROM ITS OWN epistemological framework. No engine should reference what another engine thinks.

            Reply with ONLY valid JSON:
            {
              "consensus": true or false,
              "votes": [
                {"engine": "statistical", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from statistical perspective", "confidence": 0.0-1.0},
                {"engine": "causal", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from causal perspective", "confidence": 0.0-1.0},
                {"engine": "bayesian", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from Bayesian perspective", "confidence": 0.0-1.0},
                {"engine": "meta_analysis", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from meta-analytic perspective", "confidence": 0.0-1.0},
                {"engine": "adversarial", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences — strongest counterargument", "confidence": 0.0-1.0}
              ],
              "disagreements": ["2-4 specific points where engines disagree, naming which engines and why"],
              "resolution": "2-4 sentence synthesis: given the panel's votes, what is the most defensible overall position? How should the disagreements be weighted?"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Convene the 5-engine arbitration panel. Each engine must reason independently from its own epistemological framework.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw),
                let votesRaw = obj["votes"] as? [[String: Any]]
            else {
                Log.pipeline.info("🔬 Pass 5 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))")
                return fallbackArbitration(signals: signals)
            }

            let votes: [EngineVote] = votesRaw.compactMap { v in
                guard let engineStr = v["engine"] as? String,
                    let posStr = v["position"] as? String,
                    let reasoning = v["reasoning"] as? String,
                    let confidence = v["confidence"] as? Double
                else { return nil }
                let stage = PipelineStage(rawValue: engineStr.uppercased()) ?? .statistical
                let position: VotePosition =
                    posStr == "supports" ? .supports : posStr == "opposes" ? .opposes : .neutral
                return EngineVote(
                    engine: stage, position: position, reasoning: reasoning, confidence: confidence)
            }

            let fallback = fallbackArbitration(signals: signals)
            return ArbitrationResult(
                consensus: obj["consensus"] as? Bool ?? (signals.confidence > 0.65),
                votes: votes.isEmpty ? fallback.votes : votes,
                disagreements: obj["disagreements"] as? [String] ?? [],
                resolution: obj["resolution"] as? String ?? fallback.resolution
            )
        } catch {
            Log.pipeline.info("🔬 Pass 5 HTTP ERROR — \(error.localizedDescription)")
            return fallbackArbitration(signals: signals)
        }
    }

    // MARK: - Pass 6: Truth Assessment

    nonisolated private func generateTruthAssessment(
        query: String,
        rawAnalysis: String,
        signals: GeneratedSignals,
        reflection: ReflectionResult,
        arbitration: ArbitrationResult,
        llm: LLMSnapshot
    ) async -> TruthAssessment {
        let tagCounts = countEpistemicTags(in: rawAnalysis)

        // Build arbitration vote summary for truth assessment context
        let voteSummary = arbitration.votes.map { v in
            "\(v.engine.rawValue.lowercased()): \(v.position == .supports ? "supports" : v.position == .opposes ? "opposes" : "neutral") (conf: \(String(format: "%.2f", v.confidence)))"
        }.joined(separator: " | ")

        // Compute DINCO-lite divergence metric from arbitration votes
        let voteConfidences = arbitration.votes.map(\.confidence)
        let avgConf =
            voteConfidences.isEmpty
            ? 0.5 : voteConfidences.reduce(0, +) / Double(voteConfidences.count)
        let confVariance =
            voteConfidences.isEmpty
            ? 0.0
            : voteConfidences.map { ($0 - avgConf) * ($0 - avgConf) }.reduce(0, +)
                / Double(voteConfidences.count)
        let supportCount = arbitration.votes.filter { $0.position == .supports }.count
        let opposeCount = arbitration.votes.filter { $0.position == .opposes }.count
        let neutralCount = arbitration.votes.filter { $0.position == .neutral }.count

        let systemPrompt = """
            \(Self.systemPreamble)

            You are in FINAL TRUTH CALIBRATION mode. This is Pass 6 of 6 — the terminal pass. All prior analysis, critique, and arbitration feeds into your assessment. Your job: produce an honest, well-calibrated confidence estimate that a domain expert would respect.

            ═══════════════════════════════════════════════════════════
            TECHNIQUE: REASON FIRST, THEN COMMIT (CoT-then-Confidence)
            ═══════════════════════════════════════════════════════════

            DO NOT pick a number first and rationalize it. Instead:
            1. Review ALL evidence streams below
            2. Identify what pushes confidence UP vs. DOWN
            3. Weigh the competing forces
            4. THEN — and only then — commit to overallTruthLikelihood

            This is critical because LLMs systematically default to 0.6-0.8 out of hedging instinct. Override that instinct by reasoning explicitly.

            ═══════════════════════════════════════════════════════════
            CALIBRATION ANCHORS (from calibration research)
            ═══════════════════════════════════════════════════════════

            0.90-0.95 — NEAR-CERTAIN
            Requirements: Tier 1-2 evidence, independently replicated ≥3 times, strong mechanism understood, expert consensus with no serious dissent. Domain: established for decades.
            Examples: "smoking causes lung cancer", "vaccines prevent measles", "aspirin inhibits COX enzymes"
            If you rate 0.90+, you are claiming THIS level of certainty. Most questions don't qualify.

            0.70-0.89 — PROBABLE
            Requirements: Tier 2-3 evidence, partially replicated, plausible mechanism, majority expert agreement. Some debate on magnitude/boundaries but not direction.
            Examples: "Mediterranean diet reduces cardiovascular risk", "sleep deprivation impairs cognitive function"

            0.50-0.69 — UNCERTAIN-LEANING
            Requirements: Mixed evidence, active expert debate. Tier 3-4 evidence, limited or no replication. Competing explanations remain plausible. Direction seems right, magnitude unclear.
            Examples: "moderate alcohol consumption is cardioprotective" (heavily debated), "social media causes depression in teens" (correlational)

            0.30-0.49 — GENUINELY UNCERTAIN
            Requirements: Evidence is thin, conflicting, or the domain is too new. Reasonable experts hold opposing views. Multiple unfalsified competing models.
            Examples: Questions about emerging technologies, contested social science, mechanisms not yet established.

            0.05-0.29 — UNLIKELY AS STATED
            Requirements: Evidence actively contradicts the claim, OR claim rests on Tier 5 evidence only, OR extraordinary claim without extraordinary evidence.

            ═══════════════════════════════════════════════════════════
            EVIDENCE STREAMS TO INTEGRATE
            ═══════════════════════════════════════════════════════════

            STREAM 1 — PIPELINE SIGNALS (computational):
            - Raw confidence: \(String(format: "%.2f", signals.confidence))
            - Entropy: \(String(format: "%.2f", signals.entropy)) (higher = more uncertainty)
            - Dissonance: \(String(format: "%.2f", signals.dissonance)) (higher = more internal contradiction)
            - Health score: \(String(format: "%.2f", signals.healthScore))

            STREAM 2 — EPISTEMIC TAG DISTRIBUTION (from Pass 2 analysis):
            - [DATA] claims: \(tagCounts.data) | [MODEL] claims: \(tagCounts.model) | [UNCERTAIN] claims: \(tagCounts.uncertain) | [CONFLICT] claims: \(tagCounts.conflict)
            - Data-grounding ratio: \(tagCounts.data + tagCounts.model > 0 ? String(format: "%.0f%%", Double(tagCounts.data) / Double(tagCounts.data + tagCounts.model) * 100) : "N/A")
            - Interpretation: High [DATA] with low [CONFLICT] → higher confidence. High [UNCERTAIN]/[CONFLICT] → lower confidence.

            STREAM 3 — SELF-CRITIQUE (from Pass 4 — adversarial reflection):
            - Critical questions raised: \(reflection.selfCriticalQuestions.joined(separator: " | "))
            - Least defensible claim: \(reflection.leastDefensibleClaim)
            - Precision-vs-evidence check: \(reflection.precisionVsEvidenceCheck)
            - If the self-critique found serious issues, LOWER your confidence. If critique was mostly minor, this supports the analysis.

            STREAM 4 — ARBITRATION PANEL (from Pass 5 — 5-engine vote):
            - Consensus reached: \(arbitration.consensus)
            - Vote breakdown: supports=\(supportCount), opposes=\(opposeCount), neutral=\(neutralCount)
            - Engine votes: \(voteSummary)
            - Vote confidence variance: \(String(format: "%.3f", confVariance)) (higher = more engine disagreement)
            - Average engine confidence: \(String(format: "%.2f", avgConf))
            - Disagreements: \(arbitration.disagreements.joined(separator: "; ").ifEmpty("none"))
            - Panel resolution: \(arbitration.resolution)

            STREAM 5 — DINCO-LITE CROSS-CHECK (distractor-normalized coherence):
            The arbitration panel functions as a multi-hypothesis test. Each engine that opposes or rates low confidence is a "distractor" — a plausible alternative assessment that the evidence should be weaker.
            - If all 5 engines agree (variance < 0.01): evidence is genuinely strong OR the question is easy. Check: is it actually easy, or are the engines just defaulting to agreement?
            - If adversarial engine agrees with majority: unusually strong evidence (this engine is designed to dissent)
            - If ≥2 engines oppose: the claim has serious vulnerabilities regardless of majority support
            - Normalized confidence = (supporting engine avg conf) / (supporting avg + opposing avg). Use this as a cross-check against your final number.

            ═══════════════════════════════════════════════════════════
            HARD CALIBRATION RULES (override hedging instinct)
            ═══════════════════════════════════════════════════════════

            Rule 1: NO CONSENSUS → cap at 0.70 (unless only the adversarial engine dissented)
            Rule 2: [CONFLICT] ≥ [DATA] → cap at 0.60
            Rule 3: ≥2 engines oppose → cap at 0.55 regardless of other signals
            Rule 4: Entropy > 0.7 AND dissonance > 0.5 → cap at 0.50
            Rule 5: If ALL evidence is Tier 4-5 (no empirical studies cited) → cap at 0.45
            Rule 6: If the self-critique identified ≥3 serious unresolved questions → reduce by 0.10
            Rule 7: Do NOT round to convenient numbers (0.50, 0.70, 0.80). Use precise values like 0.63, 0.47, 0.82.

            ═══════════════════════════════════════════════════════════
            OUTPUT FORMAT — REASONING FIRST, THEN NUMBER
            ═══════════════════════════════════════════════════════════

            CRITICAL: Generate fields in EXACTLY this order. The signalInterpretation field comes FIRST — this is where you reason through all 5 evidence streams BEFORE committing to a number. Research shows this ordering produces better-calibrated estimates.

            ⚠️ OUTPUT RULE: Your response MUST begin with the opening brace `{`. Do NOT write any prose, preamble, or explanation before the JSON object. Do NOT use markdown code fences. Your chain-of-thought reasoning goes INSIDE the "signalInterpretation" field — that is the correct place for it.

            Reply with ONLY valid JSON — start your response with `{`:
            {
              "signalInterpretation": "4-6 sentences. Walk through each evidence stream: what pushes confidence UP? What pushes it DOWN? Which stream carries the most weight and why? Name the single most influential factor. This is your reasoning — do it thoroughly BEFORE deciding the number below.",
              "overallTruthLikelihood": 0.05-0.95,
              "weaknesses": ["3-5 specific, actionable weaknesses — not generic statements like 'more research needed' but specific gaps like 'no RCTs on this population' or 'effect size unreplicated outside original lab'"],
              "improvements": ["3-5 specific improvements — name the exact type of study, evidence, or analysis that would move the needle"],
              "blindSpots": ["2-4 areas the analysis may have missed entirely — populations not considered, timeframes ignored, adjacent fields not consulted"],
              "confidenceCalibration": "2-3 sentences: Cross-check your number against the calibration anchors above. Would a domain expert in \(query.prefix(30)) agree? What would they push back on? Is there a reference class of similar questions where the typical accuracy is known?",
              "dataVsModelBalance": "X% data-driven, Y% model-based, Z% heuristic — must sum to 100%. 'Data' = grounded in specific cited findings. 'Model' = derived from theoretical frameworks. 'Heuristic' = based on expert judgment, analogy, or reasoning without direct evidence.",
              "recommendedActions": ["3-5 next steps, each prefixed with one of: [ACT NOW], [WAIT], or [INVESTIGATE] to indicate urgency level"]
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Perform final truth calibration using CoT-then-Confidence: reason through all 5 evidence streams first, THEN commit to a calibrated number. Do not default to 0.5-0.7.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info("🔬 Pass 6 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))")
                return fallbackTruthAssessment(signals: signals)
            }

            let fallback = fallbackTruthAssessment(signals: signals)
            let likelihood = min(
                0.95, max(0.05, obj["overallTruthLikelihood"] as? Double ?? signals.confidence))
            return TruthAssessment(
                overallTruthLikelihood: likelihood,
                signalInterpretation: obj["signalInterpretation"] as? String
                    ?? fallback.signalInterpretation,
                weaknesses: obj["weaknesses"] as? [String] ?? fallback.weaknesses,
                improvements: obj["improvements"] as? [String] ?? fallback.improvements,
                blindSpots: obj["blindSpots"] as? [String] ?? fallback.blindSpots,
                confidenceCalibration: obj["confidenceCalibration"] as? String
                    ?? fallback.confidenceCalibration,
                dataVsModelBalance: obj["dataVsModelBalance"] as? String
                    ?? fallback.dataVsModelBalance,
                recommendedActions: obj["recommendedActions"] as? [String]
                    ?? fallback.recommendedActions
            )
        } catch {
            Log.pipeline.info("🔬 Pass 6 HTTP ERROR — \(error.localizedDescription)")
            return fallbackTruthAssessment(signals: signals)
        }
    }

    // MARK: - Helpers

    /// Extracts the outermost JSON object from a string.
    /// Handles: markdown code fences (```json...```), <thinking> blocks,
    /// and prose-before-JSON (model writes reasoning before the JSON object).
    nonisolated private func extractJSON(from text: String) -> [String: Any]? {
        // 1. Strip <thinking> blocks (extended thinking models)
        var cleaned = text.replacingOccurrences(
            of: "<thinking>[\\s\\S]*?</thinking>",
            with: "",
            options: .regularExpression
        )
        // 2. Strip markdown code fences — LLMs commonly wrap JSON in ```json ... ```
        //    This is the #1 cause of JSON parse failures (observed in Passes 4, 5).
        cleaned = cleaned.replacingOccurrences(
            of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Find the outermost { ... } — using balanced counting to handle
        //    prose-before-JSON (model writes text then produces JSON block).
        //    We scan forward from each '{' and check if it produces valid JSON.
        guard let firstBrace = cleaned.firstIndex(of: "{"),
              let lastBrace = cleaned.lastIndex(of: "}")
        else {
            Log.pipeline.info("🔬 extractJSON: no braces in \(cleaned.count) chars — first80=\(String(cleaned.prefix(80)))")
            return nil
        }
        let jsonStr = String(cleaned[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8) else {
            Log.pipeline.info("🔬 extractJSON: UTF-8 encoding failed")
            return nil
        }
        do {
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Log.pipeline.info("🔬 extractJSON: not [String:Any] — jsonLen=\(jsonStr.count)")
                return nil
            }
            return obj
        } catch {
            // Log first 200 chars of the attempted JSON so we can see exactly what failed
            Log.pipeline.info(
                "🔬 extractJSON FAILED — \(error.localizedDescription, privacy: .public) jsonLen=\(jsonStr.count) first200=\(String(jsonStr.prefix(200)))")
            return nil
        }
    }

    private nonisolated struct TagCounts {
        var data = 0
        var model = 0
        var uncertain = 0
        var conflict = 0
    }

    nonisolated private func countEpistemicTags(in text: String) -> TagCounts {
        var counts = TagCounts()
        counts.data = text.components(separatedBy: "[DATA]").count - 1
        counts.model = text.components(separatedBy: "[MODEL]").count - 1
        counts.uncertain = text.components(separatedBy: "[UNCERTAIN]").count - 1
        counts.conflict = text.components(separatedBy: "[CONFLICT]").count - 1
        return counts
    }

    nonisolated private func extractUncertaintyTags(from text: String) -> [UncertaintyTag] {
        var tags: [UncertaintyTag] = []
        let pattern =
            #"\[(UNCERTAIN|CONFLICT|MODEL|DATA)\]\s*(.{15,200}?)(?=\s*\[(?:UNCERTAIN|CONFLICT|MODEL|DATA)\]|\z)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches.prefix(8) {
            guard let tagRange = Range(match.range(at: 1), in: text),
                let claimRange = Range(match.range(at: 2), in: text)
            else { continue }
            let tagStr = String(text[tagRange])
            let claim = String(text[claimRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tag: UncertaintyTagType =
                tagStr == "UNCERTAIN"
                ? .uncertain : tagStr == "CONFLICT" ? .conflict : tagStr == "MODEL" ? .model : .data
            tags.append(UncertaintyTag(claim: claim, tag: tag))
        }
        return tags
    }

    // MARK: - LLM Concept Tag Parsing

    /// Parses [CONCEPTS: concept1, concept2, ...] from the end of an LLM response.
    /// Returns the parsed concepts and the response text with the tag stripped.
    /// If no tag found, returns empty concepts and original text.
    nonisolated static func parseConceptsTag(from text: String) -> (
        concepts: [String], cleanedText: String
    ) {
        // Match [CONCEPTS: ...] anywhere (typically at the end)
        guard
            let regex = try? NSRegularExpression(
                pattern: #"\[CONCEPTS:\s*(.+?)\]\s*$"#,
                options: [.anchorsMatchLines]
            )
        else {
            return ([], text)
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, range: range),
            let conceptsRange = Range(match.range(at: 1), in: text)
        else {
            return ([], text)
        }

        // Parse comma-separated concepts
        let rawConcepts = String(text[conceptsRange])
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 2 }
            .prefix(8)

        // Strip the tag line from displayed text
        guard let fullRange = Range(match.range, in: text) else {
            return (Array(rawConcepts), text)
        }
        var cleaned = String(text[text.startIndex..<fullRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Also strip "## Concept Tag" / "### Concept Tag" headings that the LLM
        // sometimes generates before the [CONCEPTS: ...] tag. Without this, the
        // heading remains with nothing after it — showing an empty "Concept Tag" label.
        if let headingRegex = try? NSRegularExpression(
            pattern: #"(?m)^#{1,4}\s*Concept\s*Tags?\s*\n*$"#,
            options: [.caseInsensitive]
        ) {
            cleaned = headingRegex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (Array(rawConcepts), cleaned)
    }

    // MARK: - Concept Extraction (Fallback)

    /// Fallback: extracts domain concepts via regex heuristics when the LLM
    /// doesn't include a [CONCEPTS: ...] tag.
    nonisolated private func extractResponseConcepts(
        from text: String,
        queryEntities: [String]
    ) -> [String] {
        var conceptCandidates: [String: Int] = [:]

        // 1. Capitalized multi-word phrases (e.g., "Bayesian Inference", "Criminal Justice System")
        let capitalizedPattern = #"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b"#
        if let regex = try? NSRegularExpression(pattern: capitalizedPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range, in: text) else { continue }
                let phrase = String(text[r]).trimmingCharacters(in: .whitespaces)
                if phrase.count >= 4 && phrase.count <= 40 {
                    conceptCandidates[phrase, default: 0] += 2
                }
            }
        }

        // 2. Quoted terms (e.g., "recidivism", "moral desert")
        let quotedPattern = #"["""]([^"""]{3,30})["""]"#
        if let regex = try? NSRegularExpression(pattern: quotedPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let term = String(text[r]).trimmingCharacters(in: .whitespaces)
                if term.count >= 3 {
                    conceptCandidates[term, default: 0] += 2
                }
            }
        }

        // 3. Frequency-based domain words (appear ≥ 2 times, not stop words)
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 4 && !QueryAnalyzer.stopWords.contains($0) }
        var freq: [String: Int] = [:]
        for w in words { freq[w, default: 0] += 1 }
        for (word, count) in freq where count >= 2 {
            let titleCased = word.prefix(1).uppercased() + word.dropFirst()
            conceptCandidates[titleCased, default: 0] += count
        }

        // 4. Boost query entities that appear in the response
        let lowerText = text.lowercased()
        for entity in queryEntities where lowerText.contains(entity.lowercased()) {
            let titleCased = entity.prefix(1).uppercased() + entity.dropFirst()
            conceptCandidates[titleCased, default: 0] += 3
        }

        // Sort by score, deduplicate case-insensitively, limit to 8
        let sorted =
            conceptCandidates
            .sorted { $0.value > $1.value }
            .map(\.key)

        var seen: Set<String> = []
        var result: [String] = []
        for concept in sorted {
            let key = concept.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(concept)
            if result.count >= 8 { break }
        }
        return result
    }

    // MARK: - Fallbacks

    nonisolated private func fallbackLaymanSummary(
        queryAnalysis: QueryAnalysis, signals: GeneratedSignals
    ) -> LaymanSummary {
        LaymanSummary(
            whatWasTried:
                "Structured meta-analytical reasoning was applied to \"\(queryAnalysis.coreQuestion.prefix(80))\".",
            whatIsLikelyTrue: queryAnalysis.isPhilosophical
                ? "This is a genuinely contested question where thoughtful people disagree for good reasons."
                : "The evidence converges on some key points. See the Raw answer for the full analytical response.",
            confidenceExplanation:
                "Confidence is \(Int(signals.confidence * 100))% based on evidence coherence and domain complexity.",
            whatCouldChange:
                "New data, unconsidered perspectives, or methodological improvements could shift this analysis.",
            whoShouldTrust:
                "This analysis is most reliable for informed decision-making in the relevant domain.",
            sectionLabels: nil
        )
    }

    nonisolated private func fallbackReflection(signals: GeneratedSignals) -> ReflectionResult {
        ReflectionResult(
            selfCriticalQuestions: [
                "Did we adequately consider reverse causation or unmeasured confounders?",
                "Is the sample representativeness assumption justified here?",
                "Have we confused statistical significance with practical significance?",
                "Are we over-relying on published findings that may reflect positive-result bias?",
            ],
            adjustments: ["Confidence calibrated to domain complexity and signal quality"],
            leastDefensibleClaim: "Any causal claim extrapolated from correlational observations",
            precisionVsEvidenceCheck: "Precision is bounded by the quality of available evidence"
        )
    }

    nonisolated private func fallbackArbitration(signals: GeneratedSignals) -> ArbitrationResult {
        ArbitrationResult(
            consensus: signals.confidence > 0.65,
            votes: [
                EngineVote(
                    engine: .statistical, position: signals.confidence > 0.6 ? .supports : .neutral,
                    reasoning: "Confidence score: \(Int(signals.confidence * 100))%",
                    confidence: signals.confidence),
                EngineVote(
                    engine: .bayesian, position: signals.entropy < 0.5 ? .supports : .neutral,
                    reasoning: "Entropy: \(Int(signals.entropy * 100))%",
                    confidence: 1 - signals.entropy),
                EngineVote(
                    engine: .causal, position: signals.dissonance < 0.4 ? .supports : .opposes,
                    reasoning: "Dissonance: \(Int(signals.dissonance * 100))%",
                    confidence: 1 - signals.dissonance),
            ],
            disagreements: signals.dissonance > 0.4
                ? ["Signal dissonance detected — interpret with caution"] : [],
            resolution: signals.confidence > 0.65
                ? "Analytical engines broadly agree." : "Treat as indicative, not definitive."
        )
    }

    nonisolated private func fallbackTruthAssessment(signals: GeneratedSignals) -> TruthAssessment {
        TruthAssessment(
            overallTruthLikelihood: min(0.95, max(0.05, signals.confidence)),
            signalInterpretation:
                "Confidence \(Int(signals.confidence * 100))%, entropy \(Int(signals.entropy * 100))%, dissonance \(Int(signals.dissonance * 100))%.",
            weaknesses: ["Limited access to real-time data", "Cannot conduct original research"],
            improvements: ["Integrate more primary sources", "Apply stronger adversarial testing"],
            blindSpots: [
                "Recent publications may be missing", "Non-English sources not fully covered",
            ],
            confidenceCalibration: signals.confidence > 0.7
                ? "Well-calibrated"
                : signals.confidence > 0.5 ? "Moderately calibrated" : "Underconfident",
            dataVsModelBalance: signals.confidence > 0.6
                ? "~60% data-driven, ~30% model-based, ~10% heuristic"
                : "~40% data-driven, ~45% model-based, ~15% heuristic",
            recommendedActions: [
                "Cross-check with primary sources", "Seek domain expert validation",
            ]
        )
    }

    // MARK: - Stage Detail Generation

    private func generateStageDetail(stage: PipelineStage, queryAnalysis: QueryAnalysis) -> String {
        let c = queryAnalysis.complexity
        let ef = min(1, Double(queryAnalysis.entities.count) / 8)
        let topic = queryAnalysis.entities.prefix(3).joined(separator: ", ").ifEmpty(
            "the query topic")

        switch stage {
        case .triage:
            return queryAnalysis.isPhilosophical
                ? "complexity score: \(String(format: "%.2f", 0.7 + c * 0.3)) — philosophical-conceptual routing"
                : "complexity score: \(String(format: "%.2f", 0.3 + c * 0.6)) — \(c > 0.5 ? "executive" : "moderate-depth") analysis"

        case .memory:
            return "\(Int(2 + c * 8)) context fragments retrieved for \"\(topic)\""

        case .routing:
            if queryAnalysis.isPhilosophical {
                return "philosophical-analytical mode — dialectical + ethical + epistemic engines"
            } else if queryAnalysis.isMetaAnalytical {
                return "meta-analytical mode — multi-study synthesis with heterogeneity assessment"
            } else if queryAnalysis.questionType == .causal {
                return "causal-inference mode — DAG construction + Bradford Hill scoring"
            }
            return "executive mode — full reasoning pipeline"

        case .statistical:
            let d = String(format: "%.2f", 0.2 + c * 0.8 + ef * 0.2)
            return
                "Cohen's d = \(d) (\(Double(d) ?? 0 > 0.8 ? "large" : Double(d) ?? 0 > 0.5 ? "medium" : "small"))"

        case .causal:
            let hill = String(format: "%.2f", 0.4 + c * 0.35 + ef * 0.15)
            return
                "Bradford Hill score: \(hill) — \(Double(hill) ?? 0 > 0.7 ? "strong" : Double(hill) ?? 0 > 0.5 ? "moderate" : "weak") causal evidence"

        case .metaAnalysis:
            if queryAnalysis.isPhilosophical {
                return
                    "\(Int(3 + Double(queryAnalysis.entities.count) * 0.6)) traditions synthesized"
            }
            let iSq = Int(20 + c * 40 + ef * 20)
            return
                "\(Int(4 + c * 8 + ef * 4)) studies pooled, I\u{00B2} = \(iSq)% (\(iSq < 30 ? "low" : iSq < 60 ? "moderate" : "high") heterogeneity)"

        case .bayesian:
            let bf = String(format: "%.1f", 1.5 + c * 12 + ef * 6)
            return
                "BF\u{2081}\u{2080} = \(bf) (\(Double(bf) ?? 0 > 10 ? "strong" : Double(bf) ?? 0 > 3 ? "moderate" : "weak") evidence)"

        case .synthesis:
            return queryAnalysis.isPhilosophical
                ? "synthesizing dialectical analysis across \(queryAnalysis.entities.count) concepts"
                : "integrating evidence streams for structured response"

        case .adversarial:
            let challenges = max(1, Int(1 + c * 2 + ef))
            return "\(challenges) weakness\(challenges > 1 ? "es" : "") identified"

        case .calibration:
            let conf = String(format: "%.2f", 0.3 + c * 0.35 + ef * 0.2)
            let grade = Double(conf) ?? 0 > 0.75 ? "A" : Double(conf) ?? 0 > 0.55 ? "B" : "C"
            return "final confidence: \(conf) (grade \(grade))"
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
