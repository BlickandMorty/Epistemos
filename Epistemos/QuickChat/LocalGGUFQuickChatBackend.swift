import Foundation
import OSLog

#if canImport(EpistemosLlama)
import EpistemosLlama
#endif

// Surface A engine 2 (Plan 1-MAS §2.1): the embedded llama.cpp GGUF lane —
// the reliability floor and the guardrail-fallback target. Only compiled
// live where the EpistemosLlama package is linked (the AppStore target);
// elsewhere every call reports .noLocalModelInstalled honestly.
//
// Perf doctrine (§12 #5): the loaded model stays WARM across tab switches —
// `mas_model_retained_on_switch = 1` is a budget invariant. Unload happens
// only via unloadForMemoryPressure(), which the app's existing
// DispatchSourceMemoryPressure handler calls, never on view disappear.
nonisolated final class LocalGGUFQuickChatBackend: @unchecked Sendable {
    /// App-lifetime instance: the loaded model must survive view/tab churn
    /// (§12 #5 warm invariant — mas_model_retained_on_switch).
    static let shared = LocalGGUFQuickChatBackend()

    private static let log = Logger(subsystem: "com.epistemos", category: "QuickChatGGUF")

    private let stateLock = NSLock()
    private var loadedModelID: String?
    #if canImport(EpistemosLlama)
    private let engine = LlamaLocalChatEngine()
    #endif

    init() {}

    var isAvailableInThisBuild: Bool {
        #if canImport(EpistemosLlama)
        return true
        #else
        return false
        #endif
    }

    /// The entry that would serve a request right now, if any.
    func resolvedEntry() -> GGUFCatalogEntry? {
        guard isAvailableInThisBuild else { return nil }
        if let loadedModelID, let entry = GGUFModelCatalog.entry(id: loadedModelID) {
            return entry
        }
        return GGUFModelCatalog.installedEntries().first
    }

    func unavailability() -> QuickChatEngineUnavailable? {
        guard isAvailableInThisBuild else { return .noLocalModelInstalled }
        guard let entry = resolvedEntry() else { return .noLocalModelInstalled }
        return GGUFModelCatalog.ramGate(for: entry)
    }

    /// Loads (if needed) and streams. Load happens off the main actor inside
    /// the engine (§12 #2); first-token latency on a cold model is the load
    /// cost — callers show a warm loading state, never a hang (§12 #4).
    func stream(prompt: String, instructions: String?, maxNewTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(EpistemosLlama)
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
            let task = Task.detached(priority: .userInitiated) { [self] in
                do {
                    let needsLoad = stateLock.withLock { loadedModelID != entry.id } || !engine.isLoaded
                    if needsLoad {
                        try await engine.load(
                            modelURL: modelURL,
                            contextTokens: entry.defaultContextTokens
                        )
                        stateLock.withLock { loadedModelID = entry.id }
                    }
                    let fullPrompt = entry.template.apply(
                        userPrompt: prompt,
                        instructions: instructions
                    )
                    for try await event in engine.stream(prompt: fullPrompt, maxNewTokens: maxNewTokens) {
                        switch event {
                        case .token(let piece):
                            continuation.yield(piece)
                        case .finished:
                            break
                        }
                    }
                    continuation.finish()
                } catch let error as LocalChatEngineError {
                    switch error {
                    case .promptTooLong:
                        continuation.finish(throwing: QuickChatError.exceededContextWindow)
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
            continuation.onTermination = { [self] termination in
                if case .cancelled = termination {
                    #if canImport(EpistemosLlama)
                    engine.cancel()
                    #endif
                }
                task.cancel()
            }
            #else
            continuation.finish(throwing: QuickChatError.engineUnavailable(.noLocalModelInstalled))
            #endif
        }
    }

    func cancel() {
        #if canImport(EpistemosLlama)
        engine.cancel()
        #endif
    }

    /// ONLY legitimate unload path (§12 #5): real memory pressure, never a
    /// tab switch.
    func unloadForMemoryPressure() {
        #if canImport(EpistemosLlama)
        Task.detached(priority: .utility) { [self] in
            await engine.unload()
            stateLock.withLock { loadedModelID = nil }
            Self.log.info("QuickChat GGUF model unloaded under memory pressure")
        }
        #endif
    }
}
