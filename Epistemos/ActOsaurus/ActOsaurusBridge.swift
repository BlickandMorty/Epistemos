import Foundation
// MAS dual-build fix (2026-06-22): guard the OsaurusCore import with the BUILD-CONFIG
// condition, not bare `canImport`. `canImport(OsaurusCore)` can be TRUE on the App
// Store (MAS) target when the module is built in shared DerivedData even though MAS
// does NOT link it — so a bare-canImport import compiled on MAS and pulled OsaurusCore's
// transitive deps (OsaurusSQLCipher/Sentry/Sparkle/CGRPCNIOTransportZlib/…) that MAS
// can't resolve. OsaurusCore is used ONLY inside the `#if !EPISTEMOS_APP_STORE` seam
// below, so MAS never needs it; gate the import on `!EPISTEMOS_APP_STORE` too.
#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
import OsaurusCore  // S4: the LINKED Osaurus engine — driven in-process (owner: full Osaurus).
#endif

enum ActOsaurusStreamEvent: Sendable, Equatable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolStarted(id: String, name: String, inputJson: String)
    case toolCompleted(id: String, result: String, isError: Bool)
    /// 0.33a — final-turn generation telemetry (TTFT / tokens-per-second / token count) for the
    /// native act stats chip. Structured, never visible-text — so the send path stays clean.
    case generationStats(ttftSeconds: Double?, tokensPerSecond: Double?, tokenCount: Int?)
}

// Osaurus Act import — Seam A bridge (P3.0). The protocol Act drives against the
// vendored Osaurus substrate, using the vendored `ServerHealth` enum. Pro-only
// (`#if !EPISTEMOS_APP_STORE`) — the whole Osaurus seam (server/VM/relay) is outside
// the MAS sandbox. The INERT stub is the default until S3 links OsaurusCore + wires
// the runtime behind the no-hidden-fallback bar; the real conformer is the growth
// point. REAL APIs ONLY — nothing here claims a runtime it doesn't have.
#if !EPISTEMOS_APP_STORE

/// The seam Act drives against Osaurus.
protocol ActOsaurusBridge: Sendable {
    /// Current health of the Osaurus local server (the vendored `ServerHealth`).
    func serverHealth() -> ServerHealth
    /// True only when a real Osaurus runtime is wired AND live. Honest gate — never
    /// reports live for the inert seam.
    var isLive: Bool { get }
    /// Whether the osaurus-pattern local OpenAI-compatible server is enabled.
    var localServerEnabled: Bool { get }
    /// The REAL OpenAI-compatible endpoint Act would POST to (loopback :defaultPort),
    /// or nil when the local server isn't enabled. Honest — it points at the actual
    /// osaurus-pattern `LocalModelServer`; it claims no running state it can't confirm.
    var openAICompatibleEndpoint: URL? { get }
    /// Shape a chat message in Osaurus's vendored wire format (`OsaurusVendor.Message`).
    func makeRequestMessage(role: OsaurusVendor.MessageRole, content: String) -> OsaurusVendor.Message

    /// S4 — drive a REAL Act turn through the osaurus-pattern local OpenAI-compatible
    /// server (loopback :defaultPort) and return the assistant text. Throws an HONEST
    /// `ActOsaurusError` when the server isn't enabled/running — NEVER a silent
    /// cloud/GPT fallback (owner #1).
    func runTurn(model: String, messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String

    /// S4 (in-process) — run a REAL act turn through the LINKED OsaurusCore engine in-process
    /// (`CoreModelService`), NOT the loopback server. This is the canonical act-turn API the act
    /// composer consumes. Throws an HONEST `ActOsaurusError` when OsaurusCore isn't linked/usable —
    /// NEVER a silent cloud/GPT fallback (owner #1).
    func runTurnInProcess(messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String

    /// S4 (in-process STREAMING) — run a REAL act turn through the LINKED OsaurusCore chat session
    /// engine and yield visible assistant deltas. This keeps Osaurus tool execution, prompt
    /// composition, secret/clarify pauses, sandbox state, and model routing underneath the
    /// Epistemos chat UI. Throws an HONEST `ActOsaurusError` when OsaurusCore isn't linked/usable —
    /// NEVER a silent cloud/GPT fallback (owner #1).
    func runTurnStreamingInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String?) async throws -> AsyncThrowingStream<String, Error>

    /// S4 (in-process SEMANTIC STREAMING) — same engine as the text stream, but preserves
    /// Osaurus thinking/tool/result events so Epistemos can render them as native message
    /// blocks instead of leaking protocol metadata into the assistant text.
    func runTurnEventStreamInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String?) async throws -> AsyncThrowingStream<ActOsaurusStreamEvent, Error>

    /// S4 — a REAL, human-readable status of the linked OsaurusCore engine (resolved model /
    /// unavailable reason / breaker), or nil when OsaurusCore isn't linked. Drives the visible
    /// ActOsaurusHealthRow honestly — the act surface reflects real engine state, not a stub.
    func osaurusCoreStatusDescription() async -> String?
}

/// Honest errors for an Act-Osaurus turn — the local server is off, the POST failed,
/// or the response was empty. The caller surfaces these; it NEVER silently falls
/// back to a cloud/GPT route.
///
/// LocalizedError (owner 2026-06-22 P0-A): without it these bridge to the raw,
/// undiagnosable "Epistemos.ActOsaurusError error 2" the owner saw on a real send.
/// Each case now carries a friendly, ACTIONABLE message so the chat surfaces what
/// went wrong + what to do — never a bare error code.
enum ActOsaurusError: Error, Equatable, LocalizedError {
    case serverNotEnabled
    case transport(String)
    case requestFailed(status: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .serverNotEnabled:
            return "Act's Osaurus engine isn't available on this build. Open Settings → Models to set up a local model."
        case .transport(let detail):
            return "Act couldn't reach the Osaurus engine: \(detail). Retry, or reselect your model in the picker."
        case .requestFailed(let status):
            // Act runs IN-PROCESS — a requestFailed means a turn unexpectedly hit the local HTTP
            // server path. Tell the owner it's recoverable + how, instead of a raw code.
            return "Act's local model server returned an error (HTTP \(status)). Act normally runs in-process — retry the message; if it persists, reselect your model in the picker."
        case .emptyResponse:
            return "Act's Osaurus engine returned an empty response. Retry, or pick a different model in the picker."
        }
    }
}

/// OpenAI-compatible chat-completions wire shapes (match LocalModelServer's route).
private struct ActOsaurusChatRequest: Encodable {
    struct Msg: Encodable { let role: String; let content: String }
    let model: String
    let messages: [Msg]
    let stream: Bool
    let max_tokens: Int
}
private struct ActOsaurusChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

/// INERT default — the seam exists + compiles + reports `ServerHealth.stopped`, and
/// is not live. The honest state until S3 vendors+links OsaurusCore and wires the
/// runtime. NEVER silently routes anything.
struct InertActOsaurusBridge: ActOsaurusBridge {
    func serverHealth() -> ServerHealth { .stopped }
    var isLive: Bool { false }
    var localServerEnabled: Bool { false }
    var openAICompatibleEndpoint: URL? { nil }
    func makeRequestMessage(role: OsaurusVendor.MessageRole, content: String) -> OsaurusVendor.Message {
        OsaurusVendor.Message(role: role, content: content)
    }
    func runTurn(model: String, messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String {
        // Inert: it owns no running server, so it HONESTLY refuses — never a silent
        // cloud/GPT route.
        throw ActOsaurusError.serverNotEnabled
    }
    func runTurnInProcess(messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String {
        // Inert / OsaurusCore not linked (e.g. MAS target) — HONESTLY refuses; never a cloud route.
        throw ActOsaurusError.serverNotEnabled
    }
    func runTurnStreamingInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        // Inert — HONESTLY refuses (throws before yielding a single token); never a cloud route.
        throw ActOsaurusError.serverNotEnabled
    }
    func runTurnEventStreamInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String? = nil) async throws -> AsyncThrowingStream<ActOsaurusStreamEvent, Error> {
        // Inert — HONESTLY refuses (throws before yielding an event); never a cloud route.
        throw ActOsaurusError.serverNotEnabled
    }
    func osaurusCoreStatusDescription() async -> String? { nil }  // not linked → no real status.
}

/// The real conformer's growth point (S3+: link OsaurusCore, drive the local
/// server). Today it delegates to the inert stub so the type exists end-to-end
/// WITHOUT claiming a runtime it doesn't have (no fake "running"). When OsaurusCore
/// is linked, this drives the actual server; until then it is honestly inert.
struct OsaurusActBridge: ActOsaurusBridge {
    private let backing = InertActOsaurusBridge()
    func serverHealth() -> ServerHealth { backing.serverHealth() }
    var isLive: Bool { false }

    /// S4 — REAL in-process OsaurusCore drive: true when the linked Osaurus engine is
    /// present in this build (the main direct-distribution target). Honest — distinct from
    /// `isLive` (whose semantics are "the runtime/server is actually serving").
    var isOsaurusCoreLinked: Bool {
        #if canImport(OsaurusCore)
        return true
        #else
        return false
        #endif
    }

    /// S4 — drive a REAL OsaurusCore service in-process: the remote-provider types the linked
    /// Osaurus engine actually supports (openai/anthropic/ollama/…), read straight from
    /// `OsaurusCore.RemoteProviderType`. Proves act drives the real engine, not the inert
    /// stub. Empty when OsaurusCore isn't linked (e.g. the MAS target).
    var osaurusCoreRemoteProviders: [String] {
        #if canImport(OsaurusCore)
        return OsaurusCore.RemoteProviderType.allCases.map(\.rawValue).sorted()
        #else
        return []
        #endif
    }

    /// S4 — drive a REAL act generation turn IN-PROCESS through the linked OsaurusCore engine
    /// (`CoreModelService.shared.generate`), NOT the loopback server. The system message becomes
    /// the systemPrompt; the rest of the conversation folds into the prompt. Every failure throws an
    /// HONEST `ActOsaurusError` carrying OsaurusCore's own error — NEVER a silent cloud/GPT route
    /// (owner #1). Throws `serverNotEnabled` when OsaurusCore isn't linked (e.g. the MAS target).
    func runTurnInProcess(messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String {
        #if canImport(OsaurusCore)
        let system = messages.first(where: { $0.role == .system })?.content
        let conversation = messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n")
        do {
            return try await OsaurusCore.CoreModelService.shared.generate(
                prompt: conversation,
                systemPrompt: system,
                maxTokens: maxTokens
            )
        } catch {
            // OsaurusCore failed (no model loaded / load error) → surface it HONESTLY, never cloud.
            throw ActOsaurusError.transport("OsaurusCore generate failed: \(error.localizedDescription)")
        }
        #else
        throw ActOsaurusError.serverNotEnabled
        #endif
    }

    /// S4 (STREAMING) — drive a REAL act turn IN-PROCESS through OsaurusCore's headless chat-session
    /// bridge. That preserves the Osaurus agent/tool loop while Epistemos owns the visible chat.
    /// Throws an HONEST `ActOsaurusError` (never a silent cloud route); `serverNotEnabled` when
    /// OsaurusCore isn't linked.
    func runTurnStreamingInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        let events = try await runTurnEventStreamInProcess(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            requestedModel: requestedModel
        )
        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    for try await event in events {
                        if case .textDelta(let text) = event {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// S4 (SEMANTIC STREAMING) — drive a REAL act turn IN-PROCESS through OsaurusCore's
    /// headless chat-session bridge and keep thinking/tool/result events structured for
    /// Epistemos-native rendering.
    func runTurnEventStreamInProcess(prompt: String, systemPrompt: String?, maxTokens: Int, requestedModel: String? = nil) async throws -> AsyncThrowingStream<ActOsaurusStreamEvent, Error> {
        #if canImport(OsaurusCore)
        let fusedPrompt = [systemPrompt, prompt]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let osaurusEvents = await MainActor.run {
            OsaurusCore.EpistemosOsaurusChatSessionBridge.streamTurnEvents(
                prompt: fusedPrompt.isEmpty ? prompt : fusedPrompt,
                requestedModel: requestedModel,
                maxTokens: maxTokens
            )
        }
        return AsyncThrowingStream<ActOsaurusStreamEvent, Error> { continuation in
            let task = Task {
                do {
                    for try await event in osaurusEvents {
                        switch event {
                        case .textDelta(let text):
                            continuation.yield(.textDelta(text))
                        case .thinkingDelta(let text):
                            continuation.yield(.thinkingDelta(text))
                        case .toolStarted(let id, let name, let inputJson):
                            continuation.yield(.toolStarted(id: id, name: name, inputJson: inputJson))
                        case .toolCompleted(let id, let result, let isError):
                            continuation.yield(.toolCompleted(id: id, result: result, isError: isError))
                        case .generationStats(let ttft, let tps, let count):
                            continuation.yield(.generationStats(ttftSeconds: ttft, tokensPerSecond: tps, tokenCount: count))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        throw ActOsaurusError.serverNotEnabled
        #endif
    }

    /// S4 — REAL OsaurusCore engine status from `CoreModelService.resolveStatus()` (safe: resolves
    /// config/route, no model load). Drives the visible ActOsaurusHealthRow so the act surface shows
    /// the real engine state. Nil when OsaurusCore isn't linked.
    func osaurusCoreStatusDescription() async -> String? {
        #if canImport(OsaurusCore)
        switch await OsaurusCore.CoreModelService.shared.resolveStatus() {
        case .unset:
            return "OsaurusCore engine: no core model configured"
        case .available(let modelId, _, let effectiveModel):
            return "OsaurusCore engine: \(effectiveModel.isEmpty ? modelId : effectiveModel) available"
        case .unavailable(let modelId, let reason):
            return "OsaurusCore engine: \(modelId) unavailable — \(reason)"
        case .breakerOpen(let modelId, _):
            return "OsaurusCore engine: breaker open for \(modelId ?? "core model")"
        }
        #else
        return nil
        #endif
    }

    /// REAL: reflects whether Epistemos's osaurus-pattern OpenAI-compatible server
    /// (LocalModelServer) is enabled — no overclaim of a running state.
    var localServerEnabled: Bool { LocalModelServer.isEnabled }

    /// REAL: the actual loopback OpenAI-compatible endpoint when the server is
    /// enabled, else nil. This is the first concrete "working Act path" wiring —
    /// the bridge now publishes where Act would POST, honestly gated.
    var openAICompatibleEndpoint: URL? {
        guard LocalModelServer.isEnabled else { return nil }
        return URL(string: "http://127.0.0.1:\(LocalModelServer.defaultPort)/v1/chat/completions")
    }

    func makeRequestMessage(role: OsaurusVendor.MessageRole, content: String) -> OsaurusVendor.Message {
        OsaurusVendor.Message(role: role, content: content)
    }

    /// S4 — the REAL Act turn: POST an OpenAI-compatible chat-completions request to
    /// the loopback osaurus-pattern server and return the assistant text. Every
    /// failure path throws an HONEST `ActOsaurusError` (server off / transport /
    /// non-200 / empty) — it NEVER silently escalates to a cloud/GPT route.
    func runTurn(model: String, messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String {
        guard let endpoint = openAICompatibleEndpoint else {
            throw ActOsaurusError.serverNotEnabled
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ActOsaurusChatRequest(
            model: model,
            messages: messages.map { ActOsaurusChatRequest.Msg(role: $0.role.rawValue, content: $0.content) },
            stream: false,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // The server isn't running / refused → HONEST transport error, no cloud.
            throw ActOsaurusError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ActOsaurusError.requestFailed(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(ActOsaurusChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ActOsaurusError.emptyResponse
        }
        return content
    }
}

/// Resolves the bridge from the same shared act-routing decision that mounts the
/// UI and builds the local-agent generators. Do not read the old opt-in flag here:
/// that split let the chrome say "Osaurus" while sends used an inert bridge.
enum ActOsaurusBridgeFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ActOsaurusBridge {
        LocalAgentLoop.shouldRouteActThroughOsaurus(environment: environment)
            ? OsaurusActBridge()
            : InertActOsaurusBridge()
    }
}

#endif
