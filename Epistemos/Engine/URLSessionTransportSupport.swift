import Foundation

/// Tiny actor used by the SSE watchdog to track the last time activity
/// (any incoming byte or line, including heartbeats) was seen on the
/// stream. An actor so the monitor task and the read loop can update /
/// inspect the timestamp without races.
actor LastActivityTracker {
    private var last: ContinuousClock.Instant = .now

    func touch() {
        last = .now
    }

    func secondsSinceTouch() -> Double {
        let elapsed = ContinuousClock.Instant.now - last
        return Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
    }
}

nonisolated enum StreamingBufferPolicy {
    static let controlLimit = 256
    // Cloud providers can burst hundreds of tiny text fragments before
    // the main-actor UI loop drains them. Keep text-bearing streams
    // large enough to preserve ordering without going unbounded.
    static let textLimit = 16_384

    static func throwingStream<Element>(
        limit: Int = controlLimit,
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

    /// How long the stream may go idle (no bytes, no heartbeat) before
    /// we abort with a watchdog error. Deep reasoning turns can now sit
    /// silently for multiple minutes before the provider emits the first
    /// answer token, so give them a full five-minute idle budget while
    /// still eventually surfacing a dropped connection.
    private static let streamIdleWatchdogSeconds: Double = 300

    /// Streaming SSE read that can optionally emit reasoning deltas
    /// through a side-channel callback in addition to the main string
    /// stream. Used by providers whose wire format carries reasoning in
    /// a separate field (OpenAI Responses `response.reasoning_summary_text.delta`,
    /// chat-completions `delta.reasoning_content`, Gemini
    /// `parts[*].thought: true`). Callers that don't care about
    /// reasoning pass nil for `reasoningExtractor` / `onReasoning` and
    /// the behavior is identical to the legacy form.
    /// Usage snapshot extracted from a provider's streaming `usage`
    /// payload. Input + output totals + how many of the input tokens
    /// were served from the prompt cache. Used to compute the
    /// `ChatMessage.cacheHitPercent` badge.
    struct UsageSnapshot: Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
    }

    static func streamSSE(
        using urlSession: URLSession,
        request: URLRequest,
        invalidResponse: @escaping @Sendable () -> Error,
        chunkExtractor: @escaping @Sendable ([String: Any]) -> String?,
        reasoningExtractor: (@Sendable ([String: Any]) -> String?)? = nil,
        onReasoning: (@Sendable (String) -> Void)? = nil,
        usageExtractor: (@Sendable ([String: Any]) -> UsageSnapshot?)? = nil,
        onUsage: (@Sendable (UsageSnapshot) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        ProcessActivity.makeStream(
            reason: "Streaming OpenAI-compatible response",
            bufferLimit: StreamingBufferPolicy.textLimit
        ) { continuation in
            // Shared watchdog state: last time we saw any bytes from
            // the stream. The monitor task polls this and aborts the
            // run if we've been silent past `streamIdleWatchdogSeconds`.
            let lastActivity = LastActivityTracker()
            await lastActivity.touch()

            let watchdog = Task.detached { [lastActivity] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    if Task.isCancelled { return }
                    let idle = await lastActivity.secondsSinceTouch()
                    if idle > Self.streamIdleWatchdogSeconds {
                        continuation.finish(
                            throwing: LLMError.apiError(
                                statusCode: 504,
                                body: "Model stream went idle for \(Int(idle))s. The provider may be overloaded — try again or switch models."
                            )
                        )
                        return
                    }
                }
            }
            defer { watchdog.cancel() }

            do {
                let (bytes, response) = try await urlSession.bytes(for: request)
                await lastActivity.touch()

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

                    // Reasoning side-channel: if the caller provided a
                    // reasoning extractor, pipe any extracted reasoning
                    // chunk through `onReasoning` so it lands in the
                    // thinking popover rather than the visible stream.
                    if let reasoningExtractor,
                       let onReasoning,
                       let reasoning = reasoningExtractor(json),
                       !reasoning.isEmpty {
                        onReasoning(reasoning)
                    }

                    // Usage side-channel: provider emits a final usage
                    // event (Anthropic `message_delta`, OpenAI Responses
                    // `response.completed`) carrying cache-read tokens.
                    // Caller uses it to badge the bubble with cache hit %.
                    if let usageExtractor,
                       let onUsage,
                       let usage = usageExtractor(json) {
                        onUsage(usage)
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
                    // Any line (even an empty SSE keep-alive) counts as
                    // activity for the watchdog. Providers send `\n`
                    // heartbeats during long reasoning phases
                    // specifically so intermediaries don't kill idle
                    // connections.
                    await lastActivity.touch()

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
