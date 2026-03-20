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
        case .noLLMService: "No local AI runtime is available. Install a Qwen 3.5 model in Settings."
        case .analysisFailure(let msg): msg
        }
    }
}

// MARK: - Pipeline Service
// Orchestrates direct answer streaming plus optional background enrichment.

@MainActor
final class PipelineService {

    // MARK: - Dependencies

    private let pipelineState: PipelineState
    private let llmService: any LLMClientProtocol
    private let triageService: TriageService
    private let inference: InferenceState
    private let eventBus: EventBus
    private var soarService: SOARService?

    init(
        pipelineState: PipelineState,
        llmService: any LLMClientProtocol,
        triageService: TriageService,
        inference: InferenceState,
        eventBus: EventBus,
        soarService: SOARService? = nil
    ) {
        self.pipelineState = pipelineState
        self.llmService = llmService
        self.triageService = triageService
        self.inference = inference
        self.eventBus = eventBus
        self.soarService = soarService
    }

    // MARK: - Active Tasks
    // Both tasks are cancelled when a new query starts to prevent zombie enrichment work.
    private var pipelineTask: Task<Void, Never>?
    private var enrichmentTask: Task<Void, Never>?

    /// Cancel enrichment explicitly (stop button).
    func cancelAllEnrichment() {
        enrichmentTask?.cancel()
        enrichmentTask = nil
    }

    // MARK: - Run Pipeline

    /// Execute the direct-answer pipeline for a user query.
    /// When `skipEnrichment` is true, background enrichment is skipped entirely.
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
        // Cancel the previous Pass 1 generation AND any in-flight enrichment.
        // Without cancelling enrichment, rapid queries spawn zombie background tasks
        // that silently consume local compute and memory headroom.
        pipelineTask?.cancel()
        pipelineTask = nil
        enrichmentTask?.cancel()
        enrichmentTask = nil

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
                    if skipEnrichment {
                        pipelineState.isProcessing = true
                        pipelineState.currentError = nil
                        pipelineState.pipelineStages = []
                        pipelineState.activeStage = nil
                    } else {
                        pipelineState.startProcessing()
                    }

                    // Step 1: Analyze query
                    let queryAnalysis = skipEnrichment
                        ? Self.plainQueryAnalysis(for: query)
                        : QueryAnalyzer.analyze(query: query, context: context)

                    // Generate signals
                    let signals = skipEnrichment
                        ? Self.plainSignals()
                        : SignalGenerator.generate(
                            queryAnalysis: queryAnalysis,
                            controls: controls,
                            steeringBias: steeringBias
                        )

                    if !skipEnrichment {
                        let baselineSignals = BaselineSignals(
                            confidence: signals.confidence,
                            entropy: signals.entropy,
                            dissonance: signals.dissonance,
                            healthScore: signals.healthScore
                        )

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
                    enum ThinkingStreamState {
                        case tagged(closingTag: String)
                        case prelude
                    }

                    let openingProbeLimit = max(
                        ThinkingPreludeSyntax.maxOpeningMarkerLength,
                        ThinkingPreludeSyntax.maxNarrativeOpeningProbeLength,
                        24
                    )
                    let thinkingFlushTail = max(ThinkingPreludeSyntax.maxAnswerMarkerLength, 32)
                    let surfaceThinking = inference.showLocalThinkingPanel
                    var pendingPlainThinkingProbe = true
                    var thinkingState: ThinkingStreamState?
                    var textBuffer = ""
                    var emittedVisibleText = ""

                    func emitVisible(_ text: String) {
                        guard !text.isEmpty else { return }
                        emittedVisibleText += text
                        continuation.yield(.textDelta(text))
                    }

                    func emitThinking(_ text: String) {
                        guard surfaceThinking, !text.isEmpty else { return }
                        continuation.yield(.deliberationDelta(text))
                        continuation.yield(.reasoningDelta(text))
                    }

                    for try await token in directStream {
                        tokenChunks.append(token)
                        textBuffer += token

                        if thinkingState == nil,
                           let openingMatch = ThinkingTagSyntax.openingMatch(in: textBuffer) {
                            // Flush text before the tag as visible text
                            let before = String(
                                textBuffer[textBuffer.startIndex..<openingMatch.range.lowerBound]
                            )
                            if !before.isEmpty {
                                emitVisible(before)
                            }
                            textBuffer = String(textBuffer[openingMatch.range.upperBound...])
                            thinkingState = .tagged(closingTag: openingMatch.closingTag)
                            pendingPlainThinkingProbe = false
                        } else if thinkingState == nil,
                                  pendingPlainThinkingProbe,
                                  let preludeRange = ThinkingPreludeSyntax.openingMatch(in: textBuffer) {
                            let before = String(
                                textBuffer[textBuffer.startIndex..<preludeRange.lowerBound]
                            )
                            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                emitVisible(before)
                            }
                            textBuffer = String(textBuffer[preludeRange.upperBound...])
                                .trimmingLeadingWhitespaceAndNewlines()
                            thinkingState = .prelude
                            pendingPlainThinkingProbe = false
                        } else if thinkingState == nil,
                                  pendingPlainThinkingProbe,
                                  ThinkingPreludeSyntax.proseOpeningDetected(in: textBuffer) {
                            thinkingState = .prelude
                            pendingPlainThinkingProbe = false
                        }

                        switch thinkingState {
                        case .tagged(let closingTag):
                            if let closeRange = textBuffer.range(of: closingTag) {
                                let thought = String(
                                    textBuffer[textBuffer.startIndex..<closeRange.lowerBound])
                                if !thought.isEmpty {
                                    emitThinking(thought)
                                }
                                textBuffer = String(textBuffer[closeRange.upperBound...])
                                thinkingState = nil
                                // Flush any remaining text after the closing tag
                                if !textBuffer.isEmpty {
                                    emitVisible(textBuffer)
                                    textBuffer = ""
                                }
                            } else {
                                // Inside thinking — yield buffered content as deliberation
                                // Keep last 20 chars in buffer in case closing tag spans tokens
                                if textBuffer.count > 20 {
                                    let flushEnd = textBuffer.index(
                                        textBuffer.endIndex, offsetBy: -20)
                                    let flush = String(textBuffer[textBuffer.startIndex..<flushEnd])
                                    emitThinking(flush)
                                    textBuffer = String(textBuffer[flushEnd...])
                                }
                            }

                        case .prelude:
                            if let boundary = ThinkingPreludeSyntax.answerBoundary(in: textBuffer) {
                                let thought = String(
                                    textBuffer[textBuffer.startIndex..<boundary.reasoningEnd]
                                )
                                if !thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    emitThinking(thought)
                                }
                                textBuffer = String(textBuffer[boundary.answerStart...])
                                    .trimmingLeadingWhitespaceAndNewlines()
                                thinkingState = nil
                                if !textBuffer.isEmpty {
                                    emitVisible(textBuffer)
                                    textBuffer = ""
                                }
                            } else if let split = ThinkingPreludeSyntax.flushableReasoningPrefix(in: textBuffer) {
                                if !split.flush.isEmpty {
                                    emitThinking(split.flush)
                                }
                                textBuffer = split.remainder
                            } else if textBuffer.count > thinkingFlushTail,
                                      !ThinkingPreludeSyntax.likelyAnswerCandidate(in: textBuffer),
                                      ThinkingPreludeSyntax.salvagedAnswer(in: textBuffer) == nil {
                                let flushEnd = textBuffer.index(
                                    textBuffer.endIndex,
                                    offsetBy: -thinkingFlushTail
                                )
                                let flush = String(textBuffer[textBuffer.startIndex..<flushEnd])
                                if !flush.isEmpty,
                                   textBuffer[flushEnd...].contains(where: { !$0.isWhitespace && !$0.isNewline }) {
                                    emitThinking(flush)
                                }
                                textBuffer = String(textBuffer[flushEnd...])
                            }

                        case nil:
                            if pendingPlainThinkingProbe {
                                if textBuffer.count < openingProbeLimit {
                                    continue
                                }
                                pendingPlainThinkingProbe = false
                            }
                            if !textBuffer.isEmpty {
                                emitVisible(textBuffer)
                                textBuffer = ""
                            }
                        }
                    }

                    guard !Task.isCancelled else {
                        pipelineState.completeProcessing()
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    // Flush any remaining buffer
                    if !textBuffer.isEmpty {
                        if thinkingState != nil {
                            if let split = ThinkingPreludeSyntax.splitReasoningAndAnswer(in: textBuffer) {
                                if !split.reasoning.isEmpty {
                                    emitThinking(split.reasoning)
                                }
                                emitVisible(split.answer)
                            } else if ThinkingPreludeSyntax.likelyAnswerCandidate(in: textBuffer) {
                                emitVisible(textBuffer.trimmingLeadingWhitespaceAndNewlines())
                            } else {
                                emitThinking(textBuffer)
                            }
                        } else {
                            emitVisible(textBuffer)
                        }
                    }
                    let rawTokenBuffer = tokenChunks.joined()

                    if emittedVisibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let salvagedAnswer = ThinkingPreludeSyntax.salvagedAnswer(in: rawTokenBuffer),
                       !salvagedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emitVisible(salvagedAnswer)
                    }

                    // Guard: if the answer is empty or trivially short, treat as error — don't
                    // create a completed message with placeholder metrics.
                    var finalVisibleAnswer = emittedVisibleText.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    guard finalVisibleAnswer.count >= 10 else {
                        let reason =
                            finalVisibleAnswer.isEmpty ? "No response received" : "Response too short"
                        continuation.yield(.error("\(reason) — install a local Qwen model in Settings."))
                        pipelineState.completeProcessing()
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    var rawAnswerBuffer = finalVisibleAnswer
                    let minimalDualMessage: DualMessage
                    if skipEnrichment {
                        minimalDualMessage = DualMessage(
                            rawAnalysis: "",
                            uncertaintyTags: [],
                            modelVsDataFlags: []
                        )
                    } else {
                        let (llmConcepts, cleanedAnswer) = EnrichmentController.parseConceptsTag(from: rawAnswerBuffer)
                        if !llmConcepts.isEmpty {
                            rawAnswerBuffer = cleanedAnswer
                            finalVisibleAnswer = cleanedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
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

                        minimalDualMessage = DualMessage(
                            rawAnalysis: "",
                            uncertaintyTags: EnrichmentController.extractUncertaintyTags(from: rawAnswerBuffer),
                            modelVsDataFlags: []
                        )
                    }

                    continuation.yield(.completed(minimalDualMessage, nil))
                    pipelineState.completeProcessing()

                    // ── Calls 2-3: Background enrichment ─────────
                    // Skip enrichment entirely when the user has toggled it off.
                    // This saves 2 local post-processing passes per query.
                    guard !skipEnrichment else {
                        Log.pipeline.info(
                            "🔬 Enrichment: SKIPPED (regular mode) — no background enrichment passes"
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
                    let capturedLLM = llmService.enrichmentSnapshot()

                    // Strong capture: PipelineService is held by AppBootstrap — no retain cycle.
                    // [weak self] caused silent enrichment death if momentary deallocation occurred.
                    let enrichTask = Task.detached(priority: .utility) {
                        // Delivery guard: ensures onEnriched is called exactly once,
                        // even if timeout and normal completion race.
                        let deliveryGuard = FinishOnce()

                        Log.pipeline.info(
                            "🔬 Enrichment: STARTED — provider=\(capturedLLM.provider.rawValue) model=\(capturedLLM.model.prefix(30)) reasoning=\(capturedLLM.reasoningMode.rawValue)"
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

                } catch is CancellationError {
                    pipelineState.completeProcessing()
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
        let _ = (queryAnalysis, signals, controls, steeringBias, soarConfig, reroute)
        Log.pipeline.info(
            "🔬 generateDirectStream — chatMode=\(chatMode == .research ? "RESEARCH" : "PLAIN") queryLen=\(query.count)"
        )

        var promptParts: [String] = []
        if let nc = notesContext, !nc.isEmpty {
            promptParts.append(nc)
        }
        if let history = conversationHistory, !history.isEmpty {
            promptParts.append(history)
            promptParts.append("User: \(query)")
        } else {
            promptParts.append(query)
        }
        let finalPrompt = promptParts.joined(separator: "\n\n")

        Log.pipeline.info(
            "🔬 systemPrompt length=0 chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        let triageOperation: GeneralOperation = chatMode == .research
            ? .epistemicLens
            : .chatResponse(query: query)
        let requestedLocalReasoningMode: LocalReasoningMode = .fast

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: nil,
            operation: triageOperation,
            contentLength: finalPrompt.count,
            localReasoningMode: requestedLocalReasoningMode
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

    nonisolated private static func plainQueryAnalysis(for query: String) -> QueryAnalysis {
        QueryAnalysis(
            domain: .general,
            questionType: .conceptual,
            entities: [],
            coreQuestion: query,
            complexity: 0,
            isEmpirical: false,
            isPhilosophical: false,
            isMetaAnalytical: false,
            hasSafetyKeywords: false,
            hasNormativeClaims: false,
            keyTerms: [],
            emotionalValence: .neutral,
            isFollowUp: false,
            followUpFocus: nil
        )
    }

    nonisolated private static func plainSignals() -> GeneratedSignals {
        GeneratedSignals(
            confidence: 0.5,
            entropy: 0,
            dissonance: 0,
            healthScore: 1.0,
            safetyState: .green,
            riskScore: 0,
            focusDepth: 0,
            temperatureScale: 1.0,
            concepts: [],
            grade: .c,
            mode: .moderate
        )
    }
}

// MARK: - String Extension

extension String {
    nonisolated func ifEmpty(_ defaultValue: String) -> String {
        isEmpty ? defaultValue : self
    }
}
