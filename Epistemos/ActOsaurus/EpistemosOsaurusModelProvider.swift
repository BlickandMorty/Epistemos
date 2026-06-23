//  EpistemosOsaurusModelProvider.swift
//  Epistemos — owner's models in the Osaurus act chat (item 4b).
//
//  Implements the OsaurusCore `EpistemosModelProvider` seam (4a) over the app's
//  REAL local inference (`MLXInferenceService`), so the owner's prepared models
//  (the QAT ladder; GGUF or MLX — `stream(request:)` routes by runtime kind and
//  auto-loads the container) are routable from the Osaurus chat's `ChatEngine`.
//  Real bridge, no stub: it streams from the actual inference actor.
//
//  Pro / direct-distribution only — OsaurusCore (and this seam) is not linked
//  into the App Store (MAS) target, so the whole file is gated.

#if !EPISTEMOS_APP_STORE

import Foundation
import OsaurusCore

/// One model the bridge exposes: its served id + on-disk directory. Captured as
/// Sendable values at registration so the provider needs no reference to the
/// (non-Sendable) registry state.
private struct EpistemosBridgedModel: Sendable {
    let id: String
    let directory: URL
}

/// Bridges the owner's prepared models into the Osaurus chat. `Sendable`: holds
/// the inference `actor` + value-typed model descriptors only.
struct EpistemosOsaurusModelProvider: EpistemosModelProvider {
    private let service: MLXInferenceService
    private let models: [EpistemosBridgedModel]

    func availableModelIds() -> [String] { models.map(\.id) }

    func streamGenerate(prompt: String, modelId: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        let service = self.service
        let directory = models.first(where: { $0.id == modelId })?.directory
        return AsyncThrowingStream { continuation in
            guard let directory else {
                continuation.finish(throwing: ProviderError.modelNotPrepared(modelId))
                return
            }
            let task = Task {
                let request = LocalMLXRequest(
                    modelID: modelId,
                    modelDirectory: directory,
                    prompt: prompt,
                    systemPrompt: nil,
                    maxTokens: maxTokens,
                    reasoningMode: .fast,
                    steeringHintsJSON: nil,
                    imageURLs: []
                )
                let stream = await service.stream(request: request)
                do {
                    for try await delta in stream { continuation.yield(delta) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    enum ProviderError: Error, LocalizedError {
        case modelNotPrepared(String)
        var errorDescription: String? {
            switch self {
            case .modelNotPrepared(let id): return "Model '\(id)' is not prepared on this device."
            }
        }
    }

    /// Build the provider from the app's live inference + the prepared generation
    /// config and register it with OsaurusCore. P0-A (owner 2026-06-22): expose
    /// the INTERACTIVE local text model ids — the SAME ids the act surface's model
    /// picker selects — so the model threaded through `generateStream(requestedModel:)`
    /// is actually handled by the bridge (registering only the 1–2 prepared
    /// generators missed the owner's other selectable models). Call at bootstrap
    /// after the snapshot applies; idempotent (replaces).
    @MainActor
    static func register(service: MLXInferenceService, generationConfig: PreparedGenerationRuntimeConfiguration?) {
        guard let config = generationConfig else {
            // No prepared generation config → act has no Osaurus text model. HONEST
            // (the Osaurus badge's resolveStatus shows "no core model configured" and
            // the send surfaces modelUnavailable — never silent). Logged for diagnosis.
            NSLog("[act=Osaurus] register: no prepared generation config — no model registered for act")
            return
        }
        var seen = Set<String>()
        var models: [EpistemosBridgedModel] = []
        for id in config.interactiveLocalTextModelIDs() where !id.isEmpty && seen.insert(id).inserted {
            if let dir = config.resolvedModelDirectory(for: id) {
                models.append(EpistemosBridgedModel(id: id, directory: dir))
            }
        }
        guard !models.isEmpty else {
            NSLog("[act=Osaurus] register: no installed interactive text model — act has no Osaurus model")
            return
        }
        EpistemosModelBridge.register(EpistemosOsaurusModelProvider(service: service, models: models))

        // Make Osaurus send work through the Epistemos model bridge. Osaurus streams
        // via CoreModelService -> `coreModelIdentifier` (there is no per-request
        // model). If no core model is configured yet, default it to the owner's
        // installed model so act send has a valid model routed back to this bridge.
        // `coreModelIdentifier` is computed from stored `coreModelName`, so set
        // that. ONLY fill if unset; never override the owner's own choice.
        var chatConfig = ChatConfigurationStore.load()
        if (chatConfig.coreModelIdentifier ?? "").isEmpty, let first = models.first?.id {
            chatConfig.coreModelName = first
            ChatConfigurationStore.save(chatConfig)
        }
    }
}

#endif
