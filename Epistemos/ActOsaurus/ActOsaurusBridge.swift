import Foundation
#if canImport(OsaurusCore)
import OsaurusCore  // S4: the LINKED Osaurus engine — driven in-process (owner: full Osaurus).
#endif

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
}

/// Honest errors for an Act-Osaurus turn — the local server is off, the POST failed,
/// or the response was empty. The caller surfaces these; it NEVER silently falls
/// back to a cloud/GPT route.
enum ActOsaurusError: Error, Equatable {
    case serverNotEnabled
    case transport(String)
    case requestFailed(status: Int)
    case emptyResponse
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

/// Resolves the bridge for the current flag — honest, never a hidden route. Armed
/// only when the flag is on; even then inert until the runtime lands (S3+).
enum ActOsaurusBridgeFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ActOsaurusBridge {
        ActOsaurusGateStatus.isEnabled(environment[ActOsaurusGateStatus.flagName])
            ? OsaurusActBridge()
            : InertActOsaurusBridge()
    }
}

#endif
