import Foundation
import Observation

// MARK: - LLMClientProtocol

@MainActor
protocol LLMClientProtocol: AnyObject {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    func testConnection() async -> ConnectionTestResult
    func configSnapshot() -> LLMSnapshot
}

@MainActor
protocol LocalConfigurableLLMClient: LLMClientProtocol {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String
    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error>
}

extension LocalConfigurableLLMClient {
    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: nil
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: nil
        )
    }
}

extension LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
        try await generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }

    func stream(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 0) -> AsyncThrowingStream<String, Error> {
        stream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }
}

// MARK: - LLM Service

/// Shared text generation gateway for older subsystems that still expect
/// a single generation service. It exposes the current Apple Intelligence vs.
/// local Qwen snapshot without duplicating the higher-level triage engine.
@MainActor @Observable
final class LLMService: LLMClientProtocol {
    private let inference: InferenceState
    private let localLLMClient: (any LLMClientProtocol)?

    init(
        inference: InferenceState,
        localLLMClient: (any LLMClientProtocol)? = nil
    ) {
        self.inference = inference
        self.localLLMClient = localLLMClient
    }

    func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
        let snapshot = configSnapshot()
        return try await Self.generate(
            snapshot: snapshot,
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens
        )
    }

    func stream(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 0) -> AsyncThrowingStream<String, Error> {
        let snapshot = configSnapshot()
        switch snapshot.provider {
        case .appleIntelligence:
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let result = try await AppleIntelligenceService.shared.generate(
                            prompt: prompt,
                            systemPrompt: systemPrompt
                        )
                        continuation.yield(result)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }

        case .localMLX:
            guard let localLLMClient else {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
                }
            }

            if let configurable = localLLMClient as? any LocalConfigurableLLMClient {
                return configurable.stream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: snapshot.reasoningMode,
                    modelID: snapshot.model.isEmpty ? nil : snapshot.model
                )
            }

            return localLLMClient.stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
    }

    func testConnection() async -> ConnectionTestResult {
        if inference.hasUsableLocalTextModel,
           let localLLMClient {
            return await localLLMClient.testConnection()
        }

        let availability = AppleIntelligenceService.shared.checkAvailability()
        if availability.available {
            return ConnectionTestResult(
                success: true,
                message: "Apple Intelligence available"
            )
        }

        return ConnectionTestResult(
            success: false,
            message: availability.reason ?? "No local model is available and Apple Intelligence is unavailable."
        )
    }

    func configSnapshot() -> LLMSnapshot {
        resolvedSnapshot()
    }

    private func resolvedSnapshot() -> LLMSnapshot {
        if let localLLMClient {
            let localSnapshot = localLLMClient.configSnapshot()
            if localSnapshot.provider != .appleIntelligence || inference.hasUsableLocalTextModel {
                return localSnapshot
            }
        }

        if let modelID = inference.activeLocalTextModelID {
            return LLMSnapshot(provider: .localMLX, model: modelID, reasoningMode: .fast)
        }

        return LLMSnapshot(
            provider: .appleIntelligence,
            model: "",
            reasoningMode: .fast
        )
    }

    nonisolated static func generate(
        snapshot: LLMSnapshot,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        _ = timeout
        switch snapshot.provider {
        case .appleIntelligence:
            return try await AppleIntelligenceService.shared.generate(
                prompt: prompt,
                systemPrompt: systemPrompt
            )

        case .localMLX:
            return try await sharedLocalGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: snapshot.reasoningMode,
                modelID: snapshot.model.isEmpty ? nil : snapshot.model
            )
        }
    }

    @MainActor
    private static func sharedLocalGenerate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        guard let localLLMClient = AppBootstrap.shared?.localLLMClient else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        return try await localLLMClient.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: reasoningMode,
            modelID: modelID
        )
    }
}

// MARK: - LLM Snapshot

nonisolated struct LLMSnapshot: Sendable {
    let provider: LLMProviderType
    let model: String
    let reasoningMode: LocalReasoningMode
}

nonisolated struct ProcessActivityToken: @unchecked Sendable {
    fileprivate let raw: NSObjectProtocol

    init(raw: NSObjectProtocol) {
        self.raw = raw
    }
}

nonisolated struct ProcessActivityManager: Sendable {
    let begin: @Sendable (String, ProcessInfo.ActivityOptions) -> ProcessActivityToken
    let end: @Sendable (ProcessActivityToken) -> Void

    static let live = ProcessActivityManager(
        begin: { reason, options in
            ProcessActivityToken(
                raw: ProcessInfo.processInfo.beginActivity(options: options, reason: reason)
            )
        },
        end: { token in
            ProcessInfo.processInfo.endActivity(token.raw)
        }
    )
}

nonisolated enum ProcessActivity {
    @MainActor
    static func withActivityOnMainActor<T>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let token = manager.begin(reason, options)
        defer { manager.end(token) }
        return try await operation()
    }

    static func withActivity<T>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let token = manager.begin(reason, options)
        defer { manager.end(token) }
        return try await operation()
    }

    static func makeStream<Element>(
        reason: String,
        options: ProcessInfo.ActivityOptions = .userInitiatedAllowingIdleSystemSleep,
        manager: ProcessActivityManager = .live,
        _ operation: @escaping @Sendable (AsyncThrowingStream<Element, Error>.Continuation) async -> Void
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let token = manager.begin(reason, options)
            let task = Task.detached(priority: .userInitiated) {
                defer { manager.end(token) }
                await operation(continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Errors

nonisolated enum LLMError: LocalizedError {
    case apiError(statusCode: Int, body: String)

    var isTransient: Bool {
        switch self {
        case .apiError(let code, _): code == 429 || code == 529 || code == 503 || code == 502
        }
    }

    var isAuthError: Bool {
        false
    }

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body):
            if code == 0, !body.isEmpty {
                return body
            }
            switch code {
            case 429: return "The local runtime is throttled right now. Please wait a moment and try again."
            case 503: return "The local runtime is temporarily unavailable. Please try again shortly."
            default: return "Local AI error \(code)."
            }
        }
    }
}

nonisolated struct ConnectionTestResult: Sendable {
    var success: Bool
    var message: String
}
