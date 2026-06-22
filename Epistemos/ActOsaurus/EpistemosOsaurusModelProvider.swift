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

    /// Build the provider from the app's live inference + prepared-model state and
    /// register it with OsaurusCore. Exposes the prepared generator(s) — the
    /// models the owner has actually prepared for generation. Call once at
    /// bootstrap, after the inference service + registry state exist.
    @MainActor
    static func register(service: MLXInferenceService, state: PreparedModelRegistryState) {
        let descriptors = [state.primaryGenerator, state.speculativeDraftGenerator].compactMap { $0 }
        var seen = Set<String>()
        let models: [EpistemosBridgedModel] = descriptors.compactMap { desc -> EpistemosBridgedModel? in
            guard let dir = desc.resolvedDownloadPath, seen.insert(desc.servedModelID).inserted else { return nil }
            return EpistemosBridgedModel(id: desc.servedModelID, directory: URL(fileURLWithPath: dir))
        }
        guard !models.isEmpty else { return }
        EpistemosModelBridge.register(EpistemosOsaurusModelProvider(service: service, models: models))

        // Make it WORK (option b): the act surface drives the old Epistemos chat
        // through the Osaurus engine, which streams via CoreModelService ->
        // `coreModelIdentifier` (there is no per-request model). If no core model is
        // configured yet, default it to the owner's model so the act send has a
        // valid model — routed back to this bridge. `coreModelIdentifier` is computed
        // from the stored `coreModelName`, so set that. ONLY fill if unset; never
        // override the owner's own choice.
        var config = ChatConfigurationStore.load()
        if (config.coreModelIdentifier ?? "").isEmpty, let first = models.first?.id {
            config.coreModelName = first
            ChatConfigurationStore.save(config)
        }
    }
}

#endif
