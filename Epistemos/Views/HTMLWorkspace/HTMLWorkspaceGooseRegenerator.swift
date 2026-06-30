import Darwin
import Foundation

@MainActor
final class HTMLWorkspaceGooseRegenerator {
    private static let preferredPortRange = 3294...3394
    private static let runtimeWaitAttempts = 700
    private static let runtimeWaitNanoseconds: UInt64 = 100_000_000

    private let supervisor = GooseRuntimeSupervisor()
    private let secretKey = GooseRuntimeSupervisor.randomSecretKey()
    private var runtimePort: Int?
    private var activeClient: GooseACPClient?

    func stop() {
        if let activeClient {
            Task { await activeClient.close() }
        }
        activeClient = nil
        supervisor.stop()
        runtimePort = nil
    }

    func streamRegeneration(
        systemPrompt: String,
        prompt: String,
        workspaceURL: URL?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let connection = try await self.runningConnection()
                    guard let acpURL = connection.acpWebSocketURL else {
                        throw HTMLWorkspaceGooseRegeneratorError.missingACPURL
                    }

                    let client = GooseACPClient(
                        transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                        clientVersion: Bundle.main.shortVersionString ?? "Epistemos"
                    )
                    self.activeClient = client
                    defer {
                        if self.activeClient === client {
                            self.activeClient = nil
                        }
                        Task { await client.close() }
                    }

                    _ = try await client.initialize()
                    let cwd = Self.sessionWorkingDirectory(for: workspaceURL)
                    let session = try await client.newSession(
                        cwd: cwd,
                        metadata: [
                            "epistemos_surface": .string("html_workspace"),
                            "epistemos_operation": .string("full_surface_regenerate"),
                        ]
                    )

                    let eventTask = Task { [sessionID = session.sessionId] in
                        while !Task.isCancelled {
                            let event = try await client.receiveEvent()
                            try await Self.handle(
                                event,
                                sessionID: sessionID,
                                client: client,
                                continuation: continuation
                            )
                        }
                    }
                    defer { eventTask.cancel() }

                    let response = try await client.prompt(
                        sessionId: session.sessionId,
                        text: Self.composedPrompt(systemPrompt: systemPrompt, prompt: prompt)
                    )
                    eventTask.cancel()
                    guard response.stopReason == .endTurn else {
                        throw HTMLWorkspaceGooseRegeneratorError.nonTerminalStop(response.stopReason.rawValue)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func runningConnection() async throws -> GooseRuntimeConnection {
        if case .running(let connection) = supervisor.status {
            return connection
        }

        let port = runtimePort ?? Self.availableLoopbackPort() ?? GooseRuntimeSupervisor.defaultPort + 10
        runtimePort = port
        supervisor.start(
            secretKey: secretKey,
            gooseMode: "chat",
            port: port,
            allowPortFallback: true,
            builtins: []
        )

        for _ in 0..<Self.runtimeWaitAttempts {
            if Task.isCancelled { throw CancellationError() }
            switch supervisor.status {
            case .running(let connection):
                return connection
            case .failed(let message), .unavailable(let message):
                throw HTMLWorkspaceGooseRegeneratorError.runtimeUnavailable(message)
            default:
                try await Task.sleep(nanoseconds: Self.runtimeWaitNanoseconds)
            }
        }
        throw HTMLWorkspaceGooseRegeneratorError.runtimeUnavailable("Goose did not become ready for HTML Workspace regenerate.")
    }

    private static func handle(
        _ event: GooseACPClientEvent,
        sessionID: String,
        client: GooseACPClient,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        switch event {
        case .sessionUpdate(let notification):
            guard notification.sessionId == sessionID else { return }
            switch notification.update {
            case .agentMessageChunk(let chunk):
                if case .text(let text) = chunk.content, !text.isEmpty {
                    continuation.yield(text)
                }
            default:
                break
            }
        case .permissionRequest(let id, let request):
            if let reject = request.option(for: .rejectOnce) {
                try await client.respondToPermission(
                    requestId: id,
                    response: .selected(optionId: reject.optionId)
                )
            } else {
                try await client.respondToPermission(requestId: id, response: .cancelled())
            }
        case .elicitationRequest(let id, _):
            try await client.respondToElicitation(requestId: id, response: .cancel())
        case .unhandledRequest(let id, let method, _):
            try await client.respondUnsupportedRequest(requestId: id, method: method)
        case .serverError, .unhandledNotification:
            break
        }
    }

    private static func composedPrompt(systemPrompt: String, prompt: String) -> String {
        """
        \(systemPrompt)

        \(prompt)
        """
    }

    private static func sessionWorkingDirectory(for workspaceURL: URL?) -> String {
        if let workspaceURL {
            return workspaceURL.deletingLastPathComponent().path
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    private static func availableLoopbackPort() -> Int? {
        for port in preferredPortRange {
            if isLoopbackPortAvailable(port) {
                return port
            }
        }
        return nil
    }

    private static func isLoopbackPortAvailable(_ port: Int) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var reuse = Int32(1)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr(GooseRuntimeSupervisor.defaultHost))

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
}

nonisolated enum HTMLWorkspaceGooseRegeneratorError: LocalizedError, Equatable {
    case missingACPURL
    case runtimeUnavailable(String)
    case nonTerminalStop(String)

    var errorDescription: String? {
        switch self {
        case .missingACPURL:
            "Goose ACP URL is unavailable."
        case .runtimeUnavailable(let message):
            "Goose regenerate runtime unavailable: \(message)"
        case .nonTerminalStop(let stopReason):
            "Goose stopped before completing regenerate: \(stopReason)"
        }
    }
}
