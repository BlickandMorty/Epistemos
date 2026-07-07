import Foundation
import Network

nonisolated final class GooseLoopbackTestServer: @unchecked Sendable {
    enum Status: Sendable {
        case idle
        case running(URL)
        case failed(String)
    }

    private let root: URL
    private let advertisedHost: String
    private let queue = DispatchQueue(label: "com.epistemos.tests.goose-loopback")
    private let lock = NSLock()
    private var listener: NWListener?
    private var storedStatus: Status = .idle

    init(root: URL, advertisedHost: String = "127.0.0.1") {
        self.root = root
        self.advertisedHost = advertisedHost
    }

    var status: Status {
        lock.lock()
        defer { lock.unlock() }
        return storedStatus
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard let port = listener.port else {
                    self.setStatus(.failed("Loopback server did not publish a port."))
                    return
                }
                self.setStatus(.running(URL(string: "http://\(self.advertisedHost):\(port.rawValue)/")!))
            case .failed(let error):
                self.setStatus(.failed(error.localizedDescription))
            case .cancelled:
                self.setStatus(.idle)
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        setStatus(.idle)
    }

    private func setStatus(_ status: Status) {
        lock.lock()
        storedStatus = status
        lock.unlock()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let response = self.response(for: data ?? Data())
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for requestData: Data) -> Data {
        guard let request = String(data: requestData, encoding: .utf8),
              let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else {
            return Self.errorResponse(status: 400)
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            return Self.errorResponse(status: 400)
        }
        let method = String(parts[0])
        guard method == "GET" || method == "HEAD" else {
            return Self.errorResponse(status: 405)
        }
        guard let relativePath = safeRelativePath(String(parts[1])) else {
            return Self.errorResponse(status: 403)
        }
        let fileURL = root.appendingPathComponent(relativePath, isDirectory: false)
        guard let body = try? Data(contentsOf: fileURL) else {
            return Self.errorResponse(status: 404)
        }
        return Self.response(status: 200, body: method == "HEAD" ? Data() : body, contentLength: body.count)
    }

    private func safeRelativePath(_ rawPath: String) -> String? {
        let pathOnly = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath
        let normalized = pathOnly == "/" ? "/index.html" : pathOnly
        guard normalized.hasPrefix("/") else { return nil }
        let components = normalized.split(separator: "/").map(String.init)
        guard !components.contains("..") else { return nil }
        return components.joined(separator: "/")
    }

    private static func response(status: Int, body: Data, contentLength: Int) -> Data {
        let reason = status == 200 ? "OK" : "Error"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Length: \(contentLength)\r\n"
        header += "Connection: close\r\n"
        header += "Content-Type: text/html; charset=utf-8\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }

    private static func errorResponse(status: Int) -> Data {
        let body = Data("HTTP \(status)".utf8)
        return response(status: status, body: body, contentLength: body.count)
    }
}
