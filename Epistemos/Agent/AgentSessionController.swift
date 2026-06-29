import Foundation
import Observation

// Phase 1 (Step 3) — native chat session controller.
//
// Owns ONE ACP session over a Swift `GooseACPClient` connected to the SAME `goose serve` the rest of
// the surface uses (a second WebSocket to the shared server — NOT a second spawn; GOLDEN RULE intact).
// Drives the native chat loop: initialize → newSession → prompt + a concurrent `receiveEvent` stream
// that feeds `AgentTranscript`. No WebView. No Electron IPC. No REST.
//
// `@MainActor @Observable` (mirrors `GooseACPEventBridge`) so SwiftUI observes `transcript`/`status`
// and the pending permission/elicitation prompts. Transport is injectable so the loop is unit-testable
// against `GooseACPMemoryTransport` (same pattern as `GooseACPClientTests`).

@MainActor
@Observable
final class AgentSessionController {
    enum Status: Equatable {
        case idle
        case connecting
        case ready
        case streaming
        case failed(String)
    }

    private(set) var transcript = AgentTranscript()
    private(set) var status: Status = .idle
    private(set) var sessionId: String?
    private(set) var pendingPermission: GooseACPPermissionPrompt?
    private(set) var pendingElicitation: GooseACPElicitationPrompt?

    private let cwd: String
    private let clientVersion: String
    private let transportFactory: @Sendable (URL) -> any GooseACPTransport

    private var client: GooseACPClient?
    private var lifecycleTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var promptTask: Task<Void, Never>?

    init(
        cwd: String = FileManager.default.currentDirectoryPath,
        clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
        transportFactory: @escaping @Sendable (URL) -> any GooseACPTransport = { GooseACPURLSessionWebSocketTransport(url: $0) }
    ) {
        self.cwd = cwd
        self.clientVersion = clientVersion
        self.transportFactory = transportFactory
    }

    /// Connect to the shared goose serve, initialize ACP, open a session, and start the stream loop.
    func start(connection: GooseRuntimeConnection) {
        switch status {
        case .connecting, .ready, .streaming:
            return
        case .idle, .failed:
            break
        }
        guard let acpURL = connection.acpWebSocketURL else {
            status = .failed("Goose ACP WebSocket URL unavailable.")
            return
        }
        status = .connecting
        let factory = transportFactory
        let version = clientVersion
        lifecycleTask = Task { [weak self] in
            await self?.run(acpURL: acpURL, factory: factory, clientVersion: version)
        }
    }

    private func run(
        acpURL: URL,
        factory: @Sendable (URL) -> any GooseACPTransport,
        clientVersion: String
    ) async {
        let client = GooseACPClient(transport: factory(acpURL), clientVersion: clientVersion)
        self.client = client
        do {
            _ = try await client.initialize()
            let session = try await client.newSession(cwd: cwd)
            guard !Task.isCancelled else { await client.close(); return }
            sessionId = session.sessionId
            status = .ready
            streamTask = Task { [weak self] in await self?.streamLoop(client: client) }
        } catch {
            status = .failed(error.localizedDescription)
            await client.close()
            self.client = nil
        }
    }

    private func streamLoop(client: GooseACPClient) async {
        while !Task.isCancelled {
            do {
                let event = try await client.receiveEvent()
                handle(event)
            } catch {
                if !Task.isCancelled, case .failed = status {} else if !Task.isCancelled {
                    status = .failed(error.localizedDescription)
                }
                return
            }
        }
    }

    private func handle(_ event: GooseACPClientEvent) {
        switch event {
        case .sessionUpdate(let notification):
            transcript.apply(notification.update)
        case .permissionRequest(let id, let request):
            pendingPermission = GooseACPPermissionPrompt(requestID: id, request: request)
        case .elicitationRequest(let id, let request):
            pendingElicitation = GooseACPElicitationPrompt(requestID: id, request: request)
        case .unhandledRequest, .unhandledNotification, .serverError:
            // Surfaced as diagnostics by the transport/bridge layer; not chat content. Never silently
            // swallowed at the protocol layer (the client answers unknown requests with -32601/-32602).
            break
        }
    }

    /// Submit a user turn: show it optimistically, then prompt + let the stream loop render the reply.
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let client, let sessionId else { return }
        transcript.apply(.userMessageChunk(GooseACPContentChunk(content: .text(trimmed))))
        status = .streaming
        promptTask = Task { [weak self] in
            do {
                _ = try await client.prompt(sessionId: sessionId, text: trimmed)
            } catch {
                self?.appendError(error.localizedDescription)
            }
            self?.markReadyIfStreaming()
        }
    }

    func respondPermission(optionId: String?) {
        guard let prompt = pendingPermission, let client else { return }
        pendingPermission = nil
        let response = optionId.map(GooseACPRequestPermissionResponse.selected(optionId:))
            ?? GooseACPRequestPermissionResponse.cancelled()
        Task { try? await client.respondToPermission(requestId: prompt.requestID, response: response) }
    }

    func respondElicitation(_ response: GooseACPCreateElicitationResponse) {
        guard let prompt = pendingElicitation, let client else { return }
        pendingElicitation = nil
        Task { try? await client.respondToElicitation(requestId: prompt.requestID, response: response) }
    }

    /// Cancel the in-flight turn (stops awaiting the prompt result; the stream loop stays alive for the
    /// next turn). A full ACP `session/cancel` is a later refinement.
    func cancel() {
        promptTask?.cancel()
        promptTask = nil
        markReadyIfStreaming()
    }

    /// Tear down the session + connection (window close).
    func stop() async {
        promptTask?.cancel(); promptTask = nil
        streamTask?.cancel(); streamTask = nil
        lifecycleTask?.cancel(); lifecycleTask = nil
        await client?.close()
        client = nil
        sessionId = nil
        if case .failed = status {} else { status = .idle }
    }

    private func appendError(_ message: String) {
        transcript.apply(.unknown(kind: "error", payload: .string(message)))
        // `.unknown` is metadata in the reducer; surface the error as a visible error part instead.
        transcript.applyErrorText(message)
    }

    private func markReadyIfStreaming() {
        if case .streaming = status { status = .ready }
    }
}
