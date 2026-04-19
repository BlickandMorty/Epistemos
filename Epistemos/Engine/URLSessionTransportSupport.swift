import Foundation

nonisolated enum StreamingBufferPolicy {
    private static let limit = 256

    static func throwingStream<Element>(
        _ build: @escaping (AsyncThrowingStream<Element, Error>.Continuation) -> Void
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream(
            bufferingPolicy: .bufferingNewest(limit),
            build
        )
    }
}

nonisolated enum URLSessionTransportSupport {
    static func sendJSON(
        using urlSession: URLSession,
        request: URLRequest,
        invalidResponse: @escaping @Sendable () -> Error
    ) async throws -> [String: Any] {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw invalidResponse()
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: httpResponse.statusCode, body: body)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw invalidResponse()
        }
        return json
    }

    static func streamSSE(
        using urlSession: URLSession,
        request: URLRequest,
        invalidResponse: @escaping @Sendable () -> Error,
        chunkExtractor: @escaping @Sendable ([String: Any]) -> String?
    ) -> AsyncThrowingStream<String, Error> {
        ProcessActivity.makeStream(reason: "Streaming OpenAI-compatible response") { continuation in
            do {
                let (bytes, response) = try await urlSession.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw invalidResponse()
                }
                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    let body = try await collectAsyncBytes(bytes)
                    throw LLMError.apiError(statusCode: httpResponse.statusCode, body: body)
                }

                var eventName: String?
                var dataLines: [String] = []

                func flushEvent() throws {
                    guard !dataLines.isEmpty else {
                        eventName = nil
                        return
                    }

                    let payload = dataLines.joined(separator: "\n")
                    let currentEventName = eventName
                    eventName = nil
                    dataLines.removeAll(keepingCapacity: true)

                    if payload == "[DONE]" {
                        return
                    }

                    guard let jsonData = payload.data(using: .utf8),
                          let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        throw invalidResponse()
                    }

                    if let error = CloudStreamingParser.streamError(from: json, eventName: currentEventName) {
                        throw error
                    }

                    if let chunk = chunkExtractor(json), !chunk.isEmpty {
                        continuation.yield(chunk)
                    }
                }

                for try await line in bytes.lines {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    if line.isEmpty {
                        try flushEvent()
                        continue
                    }

                    if line.hasPrefix("event:") {
                        if !dataLines.isEmpty {
                            try flushEvent()
                        }
                        eventName = sseFieldValue(from: line)
                        continue
                    }

                    if line.hasPrefix("data:") {
                        dataLines.append(sseFieldValue(from: line))
                    }
                }

                try flushEvent()
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    private static func sseFieldValue(from line: String) -> String {
        let value = line.drop { $0 != ":" }.dropFirst()
        if value.first == " " {
            return String(value.dropFirst())
        }
        return String(value)
    }

    private static func collectAsyncBytes(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
