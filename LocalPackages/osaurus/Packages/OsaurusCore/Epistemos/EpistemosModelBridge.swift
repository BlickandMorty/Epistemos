//  EpistemosModelBridge.swift
//  OsaurusCore — EPISTEMOS MODEL BRIDGE SEAM
//
//  Owner directive 2026-06-22 ("OWNER'S MODELS IN CHAT"): the owner's custom
//  GGUF/QAT models (the "Epistemos Picks" / QAT ladder) must work IN the Osaurus
//  act chat. Osaurus's `ChatEngine` only knows `FoundationModelService` (Apple
//  on-device) + `MLXService` (MLX-format only) + remote providers; it can't load
//  GGUF and can't import the Epistemos app module. This file is the cross-module
//  seam: Epistemos registers a provider (PRIMITIVE types only — no Osaurus
//  internal type crosses the boundary), and the in-module
//  `EpistemosBridgedModelService` adapts it into the Osaurus `ModelService`
//  protocol so `ChatEngine` can route generation to the owner's models. Real
//  bridge, no stub: when no provider is registered it is honestly inert
//  (`isAvailable()==false`, `handles()==false`), so default behaviour is byte-
//  identical until the Epistemos app wires its inference in.

import Foundation

/// Implemented by the Epistemos app to expose the owner's models to the Osaurus
/// chat. Uses only `Sendable` primitives so the Epistemos module never needs any
/// OsaurusCore internal type.
public protocol EpistemosModelProvider: Sendable {
    /// The model ids this provider can serve. These are matched against the
    /// chat's `requestedModel` and surfaced to the picker catalog.
    func availableModelIds() -> [String]

    /// Stream a completion for the flattened `prompt` using `modelId`. Tokens
    /// are yielded as they decode; throwing ends the stream honestly (no fake
    /// completion). `maxTokens` is the engine's resolved cap.
    func streamGenerate(prompt: String, modelId: String, maxTokens: Int) -> AsyncThrowingStream<String, Error>
}

/// Process-global registry for the Epistemos model provider. The app registers
/// once at bootstrap; OsaurusCore reads it from the bridged service.
public enum EpistemosModelBridge {
    nonisolated(unsafe) private static var _provider: EpistemosModelProvider?
    private static let lock = NSLock()

    /// Register (or replace) the Epistemos model provider. Idempotent.
    public static func register(_ provider: EpistemosModelProvider) {
        lock.lock(); defer { lock.unlock() }
        _provider = provider
    }

    /// The registered provider, or nil when the app has not wired its models in.
    static func current() -> EpistemosModelProvider? {
        lock.lock(); defer { lock.unlock() }
        return _provider
    }

    /// Model ids contributed by the registered provider (empty when none).
    /// Public so the act UI can SURFACE the owner's Osaurus models (P0-B model stack).
    public static func providedModelIds() -> [String] {
        current()?.availableModelIds() ?? []
    }

    #if DEBUG
    /// Test-only: clear the registered provider so a test's registration can't leak into other
    /// tests (the registry is a process-global). Excluded from release builds — never production.
    static func resetForTesting() {
        lock.lock(); defer { lock.unlock() }
        _provider = nil
    }
    #endif
}

/// In-module `ModelService` that routes generation to the registered Epistemos
/// provider. Inert (declines everything) until a provider is registered.
struct EpistemosBridgedModelService: ModelService {
    nonisolated var id: String { "epistemos" }

    func isAvailable() -> Bool { EpistemosModelBridge.current() != nil }

    func handles(requestedModel: String?) -> Bool {
        guard let requestedModel, let provider = EpistemosModelBridge.current() else { return false }
        return provider.availableModelIds().contains(requestedModel)
    }

    func generateOneShot(
        messages: [ChatMessage],
        parameters: GenerationParameters,
        requestedModel: String?
    ) async throws -> String {
        var out = ""
        let stream = try await streamDeltas(
            messages: messages, parameters: parameters, requestedModel: requestedModel, stopSequences: [])
        for try await delta in stream { out += delta }
        return out
    }

    func streamDeltas(
        messages: [ChatMessage],
        parameters: GenerationParameters,
        requestedModel: String?,
        stopSequences: [String]
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let provider = EpistemosModelBridge.current(), let modelId = requestedModel else {
            throw EpistemosModelBridgeError.noProvider
        }
        let prompt = Self.flatten(messages)
        return provider.streamGenerate(prompt: prompt, modelId: modelId, maxTokens: parameters.maxTokens)
    }

    /// Flatten the OpenAI-style message history into a single prompt string
    /// (`role: content`, newline-separated, trailing `assistant:` cue). Keeps the
    /// boundary primitive so the Epistemos provider applies its own chat template.
    static func flatten(_ messages: [ChatMessage]) -> String {
        var lines: [String] = []
        for m in messages {
            let content = m.content ?? ""
            if content.isEmpty { continue }
            lines.append("\(m.role): \(content)")
        }
        lines.append("assistant:")
        return lines.joined(separator: "\n")
    }
}

enum EpistemosModelBridgeError: Error, LocalizedError {
    case noProvider
    var errorDescription: String? {
        "No Epistemos model provider is registered, or no model id was supplied."
    }
}
