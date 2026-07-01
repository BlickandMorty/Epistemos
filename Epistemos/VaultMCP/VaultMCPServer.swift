import Foundation
import Network
import os

nonisolated enum VaultMCPServerDiagnostics {
    static let maxStatusMessageCharacters = 240
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func statusMessage(for error: Error, fallback: String = "listener failed") -> String {
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return statusMessage("\(fallback) (domain=\(domain) code=\(nsError.code))")
    }

    static func statusMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? "listener failed" : trimmed
        guard description.count > maxStatusMessageCharacters else {
            return description
        }
        return String(description.prefix(maxStatusMessageCharacters)) + "..."
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Network"
        }
        let value = trimmed.isEmpty ? "Network" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Network"
        }
        let safeDomain = String(value.prefix(maxDomainCharacters))
        return safeDomain.isEmpty ? "Network" : safeDomain
    }
}

nonisolated final class VaultMCPServer: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case idle
        case starting
        case running(WorkNativeMCPRegistration)
        case failed(String)
        case stopped
    }

    private static let logger = Logger(subsystem: "com.epistemos.server", category: "VaultMCPServer")
    private static let maxRequestBytes = 8 * 1024 * 1024

    private let core: VaultMCPCore
    private let token: String
    private let sessionID = WorkNativeMCPServer.randomToken()
    private let queue = DispatchQueue(label: "com.epistemos.vaultmcp", qos: .userInitiated)
    private var listener: NWListener?

    private let statusLock = NSLock()
    private var _status: Status = .idle

    var status: Status { statusLock.withLock { _status } }
    private func setStatus(_ newValue: Status) { statusLock.withLock { _status = newValue } }

    init(
        vaultRoot: URL?,
        executor: @escaping LocalAgentToolExecutor,
        token: String,
        resourceDispatcher: (any VaultMCPResourceDispatcher)? = nil
    ) {
        self.core = VaultMCPCore(
            vaultRoot: vaultRoot,
            executor: executor,
            resourceDispatcher: resourceDispatcher)
        self.token = token
    }

    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let port = listener.port?.rawValue {
                    let registration = WorkNativeMCPRegistration(
                        url: "http://127.0.0.1:\(port)\(WorkNativeMCPServer.mcpPath)",
                        token: self.token)
                    self.setStatus(.running(registration))
                    Self.logger.info("VaultMCPServer ready on 127.0.0.1:\(port, privacy: .public)\(WorkNativeMCPServer.mcpPath, privacy: .public)")
                } else {
                    self.setStatus(.failed("listener ready but no bound port"))
                }
            case .failed(let error):
                let message = VaultMCPServerDiagnostics.statusMessage(for: error)
                Self.logger.error("\(message, privacy: .public)")
                self.setStatus(.failed(message))
            case .cancelled:
                self.setStatus(.stopped)
            default:
                break
            }
        }

        setStatus(.starting)
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        setStatus(.stopped)
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                let message = VaultMCPServerDiagnostics.statusMessage(for: error, fallback: "receive failed")
                Self.logger.debug("\(message, privacy: .public)")
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > Self.maxRequestBytes {
                self.respond(connection, WorkNativeMCPServer.httpResponse(
                    status: 413,
                    json: #"{"error":"request too large"}"#))
                return
            }

            switch WorkMCPHTTPRequest.parse(buffer, maxContentLength: Self.maxRequestBytes) {
            case .needMore:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receive(connection, accumulated: buffer)
                }
            case .tooLarge:
                self.respond(connection, WorkNativeMCPServer.httpResponse(
                    status: 413,
                    json: #"{"error":"request too large"}"#))
            case .invalid:
                self.respond(connection, WorkNativeMCPServer.httpResponse(
                    status: 400,
                    json: #"{"error":"bad request"}"#))
            case .complete(let request):
                self.handle(request, on: connection)
            }
        }
    }

    private func handle(_ request: WorkMCPHTTPRequest, on connection: NWConnection) {
        switch WorkNativeMCPServer.routeOutcome(
            method: request.method,
            path: request.path,
            headers: request.headers,
            token: token
        ) {
        case .unauthorized:
            respond(connection, WorkNativeMCPServer.httpResponse(status: 401, json: #"{"error":"unauthorized"}"#))
        case .notFound:
            respond(connection, WorkNativeMCPServer.httpResponse(status: 404, json: #"{"error":"not found"}"#))
        case .methodNotAllowed:
            respond(connection, WorkNativeMCPServer.httpResponse(status: 405, json: #"{"error":"method not allowed"}"#))
        case .dispatch:
            let requestJSON = String(data: request.body, encoding: .utf8) ?? "{}"
            if WorkNativeMCPServer.isNotification(requestJSON: requestJSON) {
                respond(connection, WorkNativeMCPServer.acceptedResponse(sessionID: sessionID))
                return
            }

            Task { [weak self] in
                guard let self else { return }
                let responseJSON = await self.core.handle(requestJSON: requestJSON)
                self.respond(
                    connection,
                    WorkNativeMCPServer.httpResponse(status: 200, json: responseJSON, sessionID: self.sessionID))
            }
        }
    }

    private func respond(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }
}
