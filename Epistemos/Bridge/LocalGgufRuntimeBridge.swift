import Foundation

// Pro-only on-device GGUF runtime engine, backed by the hardened one-shot
// `llama-cli` subprocess in agent_core (the proven path: Gemma 4 E2B QAT
// ~64 tok/s, 12B coder ~18.5 tok/s on Apple M2 Pro Metal, verified
// 2026-06-16; see artifacts/runtime_receipts/).
//
// The `runLocalGgufGeneration` FFI symbol is compiled ONLY into the pro-build
// of agent_core (build-agent-core.sh selects mas-build for the App Store
// target, pro-build otherwise; the Rust fn is `#[cfg(feature = "pro-build")]`).
// The MAS sandbox + hardened runtime forbid the subprocess, so this whole
// surface is gated by `!EPISTEMOS_APP_STORE` to mirror that cargo split.
//
// It is an ALTERNATE `LocalGGUFInProcessRuntime` engine builder, NOT a
// replacement for `defaultEngineBuilder` — that one stays reserved for the
// future true in-process `GGUFRuntimeBridge` module (zero-copy, no subprocess).
// This subprocess engine is gated OFF by default behind the
// `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0` flag: the seam compiles + is reachable,
// but nothing runs it until the owner (or an explicit validation run) opts in.
// Honest-capability-gating holds: the agent loop still refuses Local providers,
// so Gemma stays non-agent; this only serves plain chat / fast / thinking.

#if !EPISTEMOS_APP_STORE

/// Minimal `AgentEventDelegate` that forwards on-device GGUF text deltas into a
/// raw `AsyncThrowingStream<String, Error>`. Deliberately does NOT emit an
/// AnswerPacket (that belongs to the higher-level chat path, matching the MLX
/// local lane) — it is a plain token producer for `LocalGGUFEngine`.
nonisolated final class LocalGgufTextStreamDelegate: AgentStreamEventDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, Error>.Continuation

    init(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
    }

    func onThinkingDelta(thought: String) { continuation.yield(thought) }
    func onTextDelta(delta: String) { continuation.yield(delta) }
    func onToolInputDelta(index: UInt32, partialJson: String) {}
    func onToolStarted(toolUseId: String, name: String, inputJson: String) {}
    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {}
    func onSubagentSpawned(agentId: String, role: String) {}
    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    ) {}
    func onContextCompacting(currentTokens: UInt32) {}
    func onContextCompacted(newMessageCount: UInt32) {}
    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {}
    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        continuation.finish()
    }
    func onError(message: String) {
        continuation.finish(throwing: AgentRuntimeError(message: message))
    }
    func executeComputerAction(actionJson: String) -> String { "{}" }
    func waitForPermission(permissionId: String) -> Bool { false }
    func askUserQuestion(questionJson: String) -> String { "{}" }
    func perceiveApp(appName: String, depth: String) -> String { "{}" }
    func interactWithApp(actionJson: String) -> String { "{}" }
    func startScreenWatch(watchJson: String) -> String { "{}" }
    func manageSsmState(actionJson: String) -> String { "{}" }
    func generateConstrained(prompt: String, grammarJson: String) -> String { "{}" }
    func generateImage(prompt: String, aspectRatio: String) -> String { "{}" }
    func triggerNightbrainJob(jobType: String, priority: String) -> String { "{}" }
    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String { "{}" }
}

/// Stream raw text chunks from a local GGUF model on disk through the hardened
/// `llama-cli` subprocess. Errors arrive in-band as the stream's terminal throw.
nonisolated func streamLocalGgufText(
    modelPath: String,
    prompt: String,
    systemPrompt: String?,
    maxTokens: Int,
    temperature: Float
) -> AsyncThrowingStream<String, Error> {
    StreamingBufferPolicy.throwingStream { (continuation: AsyncThrowingStream<String, Error>.Continuation) in
        let trimmedPath = modelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            continuation.finish(throwing: LocalGGUFRuntimeError.modelNotPrepared)
            return
        }
        let delegate = LocalGgufTextStreamDelegate(continuation: continuation)
        let maxOutputTokens: UInt32? = maxTokens > 0 ? UInt32(clamping: maxTokens) : nil
        let task = Task.detached {
            do {
                try await invokeLocalGgufGeneration(
                    modelPath: trimmedPath,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxOutputTokens: maxOutputTokens,
                    temperature: temperature,
                    delegate: delegate
                )
                // onComplete already finished; this is a no-op safety net for a
                // return without a terminal MessageStop.
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// Pro-only, flag-gated factory for the subprocess-backed GGUF engine.
enum LocalGgufCliRuntime {
    /// Default-OFF runtime flag. Set the env var to "1" or the UserDefaults
    /// bool to true to arm the subprocess engine for on-device validation.
    static let runtimeFlagKey = "EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0"

    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment[runtimeFlagKey] == "1" { return true }
        return UserDefaults.standard.bool(forKey: runtimeFlagKey)
    }

    /// The injectable engine builder when armed; `nil` otherwise (so
    /// `LocalGGUFInProcessRuntime` falls back to its reserved default builder,
    /// which honestly reports `backendUnavailable`).
    static func engineBuilderIfEnabled() -> LocalGGUFInProcessRuntime.EngineBuilder? {
        guard isEnabled else { return nil }
        return { modelURL, _, reasoningMode in
            let path = modelURL.path
            // Map the reasoning mode to a sampler temperature. Fast stays
            // greedy/deterministic (matches the gate command card + receipt);
            // thinking gets a little exploration headroom.
            let temperature = Self.temperature(for: reasoningMode)
            return LocalGGUFEngine(
                generate: { prompt, systemPrompt, maxTokens in
                    var output = ""
                    let stream = streamLocalGgufText(
                        modelPath: path,
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )
                    for try await chunk in stream { output += chunk }
                    return output
                },
                stream: { prompt, systemPrompt, maxTokens in
                    streamLocalGgufText(
                        modelPath: path,
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )
                }
            )
        }
    }

    /// Reasoning-mode → sampler temperature. Fast = greedy/deterministic
    /// (gate-aligned default); thinking gets mild exploration. `nonisolated`
    /// so the `@Sendable` engine-builder closure can call it off the main actor.
    nonisolated static func temperature(for reasoningMode: LocalReasoningMode) -> Float {
        switch reasoningMode {
        case .thinking:
            return 0.7
        default:
            return 0.0
        }
    }
}

#if canImport(agent_coreFFI)
/// Real pro-build path: drive the generated UniFFI symbol.
private func invokeLocalGgufGeneration(
    modelPath: String,
    prompt: String,
    systemPrompt: String?,
    maxOutputTokens: UInt32?,
    temperature: Float?,
    jsonSchema: String? = nil,
    delegate: LocalGgufTextStreamDelegate
) async throws {
    _ = try await runLocalGgufGeneration(
        modelPath: modelPath,
        prompt: prompt,
        systemPrompt: systemPrompt,
        maxOutputTokens: maxOutputTokens,
        temperature: temperature,
        jsonSchema: jsonSchema,
        delegate: delegate
    )
}
#else
/// Fallback for targets that don't link `agent_coreFFI` (unit-test hosts):
/// honest "no in-process GGUF backend" — same error the reserved default uses.
private func invokeLocalGgufGeneration(
    modelPath: String,
    prompt: String,
    systemPrompt: String?,
    maxOutputTokens: UInt32?,
    temperature: Float?,
    jsonSchema: String? = nil,
    delegate: LocalGgufTextStreamDelegate
) async throws {
    throw LocalGGUFRuntimeError.backendUnavailable
}
#endif

#endif // !EPISTEMOS_APP_STORE
