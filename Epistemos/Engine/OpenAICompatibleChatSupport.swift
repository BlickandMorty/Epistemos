import Foundation

nonisolated enum OpenAICompatibleChatSupport {
    private static let defaultMaxTokens = 4_096

    static func completionBody(
        modelID: String,
        prompt: String,
        systemPrompt: String?,
        imagePayloads: [CloudLLMClient.VisionPayload] = [],
        maxTokens: Int,
        stream: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": modelID,
            "messages": CloudLLMClient.compatibleChatMessages(
                prompt: prompt,
                systemPrompt: systemPrompt,
                imagePayloads: imagePayloads
            ),
            "stream": stream,
        ]
        body["max_tokens"] = maxTokens > 0 ? maxTokens : defaultMaxTokens
        return body
    }

    static func messageText(from json: [String: Any]) -> String? {
        let choices = json["choices"] as? [[String: Any]] ?? []
        let text = choices.compactMap { choice -> String? in
            guard let message = choice["message"] as? [String: Any] else { return nil }
            if let content = message["content"] as? String, !content.isEmpty {
                return content
            }
            return nil
        }
        .joined()
        return text.isEmpty ? nil : text
    }
}
