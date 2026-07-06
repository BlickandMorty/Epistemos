#if EPISTEMOS_APP_STORE
import Foundation
import os

/// The cloud lane behind June (Plan 1-MAS §2/§5): streams an OpenAI-compatible
/// chat completion from the receipt-gated proxy. The bearer is the short-lived
/// Keychain session token from EpistemosProxyClient (minted by the Phase-4
/// StoreKit → verify-receipt flow); provider keys exist only server-side.
nonisolated final class JuneCloudEngine: @unchecked Sendable {
    static let shared = JuneCloudEngine()

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneCloudEngine")

    enum CloudError: LocalizedError {
        case notSubscribed
        case authExpired
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .notSubscribed:
                return "Epistemos Cloud requires an active subscription. On-device models are free."
            case .authExpired:
                return "Your cloud session expired. Reopen Settings to refresh your subscription."
            case .httpStatus(let code):
                return "The cloud service returned an error (\(code)). Try again shortly."
            }
        }
    }

    private init() {}

    /// `messages` is the OpenAI-compatible role-tagged conversation (system +
    /// history), so the cloud agent sees the full thread, not just the latest
    /// message.
    func stream(messages: [[String: String]]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let task = Task {
                do {
                    try await self.run(messages: messages, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        messages: [[String: String]],
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let base = EpistemosProxyClient.chatCompletionsBaseURL else {
            throw JuneGatewayError.cloudNotConfigured
        }
        guard let session = try await EpistemosProxyClient.shared.sessionForCloudRequest() else {
            throw CloudError.notSubscribed
        }

        var request = URLRequest(url: base.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": "epistemos-default", // the proxy resolves the concrete provider model
            "stream": true,
            "messages": messages,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudError.httpStatus(-1)
        }
        if http.statusCode == 401 {
            // Token rejected: drop it so the next attempt re-verifies cleanly.
            EpistemosProxyClient.shared.clearSession()
            throw CloudError.authExpired
        }
        guard http.statusCode == 200 else {
            Self.log.warning("proxy chat completion HTTP \(http.statusCode)")
            throw CloudError.httpStatus(http.statusCode)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard
                let data = payload.data(using: .utf8),
                let frame = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                let choices = frame["choices"] as? [[String: Any]],
                let delta = choices.first?["delta"] as? [String: Any]
            else { continue } // keep-alives / role frames are expected noise
            if let content = delta["content"] as? String, !content.isEmpty {
                continuation.yield(content)
            }
        }
    }
}
#endif
