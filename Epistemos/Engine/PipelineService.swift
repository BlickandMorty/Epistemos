import Foundation
import Synchronization
import os

private final class FinishOnce: Sendable {
    private let done = Mutex(false)

    nonisolated func tryFinish() -> Bool {
        done.withLock { done in
            guard !done else { return false }
            done = true
            return true
        }
    }
}

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

@MainActor
final class PipelineService {
    private let pipelineState: PipelineState
    private let llmService: any LLMClientProtocol
    private let triageService: TriageService
    private let inference: InferenceState
    private let eventBus: EventBus
    private var pipelineTask: Task<Void, Never>?

    init(
        pipelineState: PipelineState,
        llmService: any LLMClientProtocol,
        triageService: TriageService,
        inference: InferenceState,
        eventBus: EventBus
    ) {
        self.pipelineState = pipelineState
        self.llmService = llmService
        self.triageService = triageService
        self.inference = inference
        self.eventBus = eventBus
    }

    func run(
        query: String,
        mode: InferenceMode,
        notesContext: String? = nil,
        conversationHistory: String? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        let _ = (mode, llmService, inference, eventBus)
        pipelineTask?.cancel()
        pipelineTask = nil

        let finisher = FinishOnce()

        return AsyncThrowingStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pipelineTask?.cancel()
                }
            }

            let mainTask = Task { @MainActor [weak self] in
                guard let self else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }

                do {
                    pipelineState.isProcessing = true
                    pipelineState.currentError = nil
                    pipelineState.pipelineStages = []
                    pipelineState.activeStage = nil

                    var emittedVisibleText = ""
                    let directStream = generateDirectStream(
                        query: query,
                        notesContext: notesContext,
                        conversationHistory: conversationHistory
                    )

                    for try await token in directStream {
                        emittedVisibleText += token
                        continuation.yield(.textDelta(token))
                    }

                    guard !Task.isCancelled else {
                        pipelineState.completeProcessing()
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    let finalVisibleAnswer = emittedVisibleText.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    guard finalVisibleAnswer.count >= 10 else {
                        let reason =
                            finalVisibleAnswer.isEmpty ? "No response received" : "Response too short"
                        continuation.yield(.error("\(reason) — install a local Qwen model in Settings."))
                        pipelineState.completeProcessing()
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    continuation.yield(
                        .completed(
                            DualMessage(rawAnalysis: "", uncertaintyTags: [], modelVsDataFlags: []),
                            nil
                        )
                    )
                    pipelineState.completeProcessing()
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

            Task { @MainActor [weak self] in
                self?.pipelineTask = mainTask
            }
        }
    }

    private func generateDirectStream(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        Log.pipeline.info("🔬 generateDirectStream — chatMode=PLAIN queryLen=\(query.count)")

        var promptParts: [String] = []
        if let notesContext, !notesContext.isEmpty {
            promptParts.append(notesContext)
        }
        if let conversationHistory, !conversationHistory.isEmpty {
            promptParts.append(conversationHistory)
            promptParts.append("User: \(query)")
        } else {
            promptParts.append(query)
        }
        let finalPrompt = promptParts.joined(separator: "\n\n")

        Log.pipeline.info(
            "🔬 systemPrompt length=0 chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: nil,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count,
            localReasoningMode: .fast
        )
    }
}
