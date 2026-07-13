#if EPISTEMOS_APP_STORE
import EpistemosLlama
#endif

import Foundation
import OSLog

// June's selected local-model lane. App Store builds link the pinned
// EpistemosLlama XCFramework directly in-process; other targets keep the same
// backend seam unavailable. There is no subprocess, local server, JIT, or
// downloaded executable runtime.
nonisolated final class LocalGGUFQuickChatBackend: @unchecked Sendable {
    /// App-lifetime ownership keeps the selected model warm across June view
    /// churn. The only unload path is explicit memory pressure.
    static let shared = LocalGGUFQuickChatBackend()

    private static let log = Logger(subsystem: "com.epistemos", category: "QuickChatGGUF")

    private let stateLock = NSLock()
    private var loadedModelID: String?
    private var preferredModelID: String?
    private var isGenerating = false
    private var isUnloading = false
    private var unloadAfterGeneration = false
    #if EPISTEMOS_APP_STORE
    private let engine = LlamaLocalChatEngine()
    #endif

    init() {}

    #if EPISTEMOS_APP_STORE
    var isAvailableInThisBuild: Bool { true }
    #else
    var isAvailableInThisBuild: Bool { false }
    #endif

    func setPreferredModel(_ id: String?) {
        stateLock.withLock { preferredModelID = id }
    }

    func resolvedEntry() -> GGUFCatalogEntry? {
        guard isAvailableInThisBuild else { return nil }
        let (preferred, loaded) = stateLock.withLock { (preferredModelID, loadedModelID) }
        if let preferred,
           let entry = GGUFModelCatalog.entry(id: preferred),
           GGUFModelCatalog.installedURL(for: entry) != nil {
            return entry
        }
        if let loaded, let entry = GGUFModelCatalog.entry(id: loaded) {
            return entry
        }
        return GGUFModelCatalog.installedEntries().first
    }

    func unavailability() -> QuickChatEngineUnavailable? {
        guard isAvailableInThisBuild else { return .noLocalModelInstalled }
        guard let entry = resolvedEntry() else { return .noLocalModelInstalled }
        return GGUFModelCatalog.ramGate(for: entry)
    }

    func stream(
        prompt: String,
        instructions: String?,
        maxNewTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            #if EPISTEMOS_APP_STORE
            guard let entry = resolvedEntry() else {
                continuation.finish(throwing: QuickChatError.engineUnavailable(.noLocalModelInstalled))
                return
            }
            if let gate = GGUFModelCatalog.ramGate(for: entry) {
                continuation.finish(throwing: QuickChatError.engineUnavailable(gate))
                return
            }
            guard let modelURL = GGUFModelCatalog.installedURL(for: entry) else {
                continuation.finish(throwing: QuickChatError.engineUnavailable(.noLocalModelInstalled))
                return
            }
            let fullPrompt = entry.template.apply(
                userPrompt: prompt,
                instructions: instructions
            )
            let promptTokenEstimate = GGUFModelCatalog.estimatedTokens(for: fullPrompt)
            guard GGUFModelCatalog.promptFits(
                entry: entry,
                promptTokenEstimate: promptTokenEstimate,
                replyBudgetTokens: maxNewTokens
            ) else {
                continuation.finish(throwing: QuickChatError.exceededContextWindow)
                return
            }
            guard beginGeneration() else {
                continuation.finish(throwing: QuickChatError.engineUnavailable(.localModelBusy))
                return
            }
            let task = Task.detached(priority: .userInitiated) { [self] in
                defer {
                    if finishGeneration() {
                        Task {
                            await engine.unload()
                            finishUnload()
                            Self.log.info("QuickChat GGUF model unloaded after memory-pressure cancellation")
                        }
                    }
                }
                do {
                    let needsLoad = stateLock.withLock { loadedModelID != entry.id } || !engine.isLoaded
                    if needsLoad {
                        try await engine.load(
                            modelURL: modelURL,
                            contextTokens: entry.defaultContextTokens
                        )
                        stateLock.withLock { loadedModelID = entry.id }
                    }
                    for try await event in engine.stream(prompt: fullPrompt, maxNewTokens: maxNewTokens) {
                        switch event {
                        case .token(let piece):
                            guard Self.yieldBounded(piece, to: continuation) else {
                                engine.cancel()
                                return
                            }
                        case .finished:
                            break
                        }
                    }
                    continuation.finish()
                } catch let error as LocalChatEngineError {
                    switch error {
                    case .promptTooLong:
                        continuation.finish(throwing: QuickChatError.exceededContextWindow)
                    case .streamBackpressure:
                        continuation.finish(throwing: QuickChatError.generationFailed(
                            "Local model output could not keep up with its bounded stream buffer. Try again."
                        ))
                    default:
                        continuation.finish(throwing: QuickChatError.generationFailed(
                            String(describing: error)
                        ))
                    }
                } catch {
                    continuation.finish(throwing: QuickChatError.generationFailed(
                        error.localizedDescription
                    ))
                }
            }
            continuation.onTermination = { termination in
                if case .cancelled = termination {
                    self.engine.cancel()
                }
                task.cancel()
            }
            #else
            continuation.finish(throwing: QuickChatError.engineUnavailable(.noLocalModelInstalled))
            #endif
        }
    }

    func cancel() {
        #if EPISTEMOS_APP_STORE
        engine.cancel()
        #endif
    }

    private static func yieldBounded(
        _ piece: String,
        to continuation: AsyncThrowingStream<String, Error>.Continuation
    ) -> Bool {
        switch continuation.yield(piece) {
        case .enqueued:
            return true
        case .dropped:
            continuation.finish(throwing: QuickChatError.generationFailed(
                "Local model output could not keep up with its bounded stream buffer. Try again."
            ))
            return false
        case .terminated:
            return false
        @unknown default:
            continuation.finish(throwing: QuickChatError.generationFailed(
                "Local model output could not keep up with its bounded stream buffer. Try again."
            ))
            return false
        }
    }

    func unloadForMemoryPressure() {
        #if EPISTEMOS_APP_STORE
        switch prepareMemoryPressureUnload() {
        case .afterGeneration:
            engine.cancel()
            Self.log.info("QuickChat GGUF active generation cancelled for memory pressure; unload will follow")
        case .alreadyInProgress:
            Self.log.info("QuickChat GGUF memory-pressure unload already in progress")
        case .immediate:
            Task.detached(priority: .utility) { [self] in
                await engine.unload()
                finishUnload()
                Self.log.info("QuickChat GGUF model unloaded under memory pressure")
            }
        }
        #endif
    }

    private func beginGeneration() -> Bool {
        stateLock.withLock {
            guard !isGenerating, !isUnloading else { return false }
            isGenerating = true
            return true
        }
    }

    private func finishGeneration() -> Bool {
        stateLock.withLock {
            isGenerating = false
            let shouldUnload = unloadAfterGeneration
            unloadAfterGeneration = false
            if shouldUnload {
                isUnloading = true
                loadedModelID = nil
            }
            return shouldUnload
        }
    }

    private enum MemoryPressureUnloadDecision {
        case immediate
        case afterGeneration
        case alreadyInProgress
    }

    private func prepareMemoryPressureUnload() -> MemoryPressureUnloadDecision {
        stateLock.withLock {
            if isUnloading {
                return .alreadyInProgress
            }
            if isGenerating {
                unloadAfterGeneration = true
                return .afterGeneration
            }
            isUnloading = true
            loadedModelID = nil
            return .immediate
        }
    }

    private func finishUnload() {
        stateLock.withLock {
            loadedModelID = nil
            isUnloading = false
        }
    }
}
