import Foundation

nonisolated enum OpenAICompatibleChatSupport {
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
        if maxTokens > 0 {
            body["max_tokens"] = maxTokens
        }
        return body
    }

    static func messageText(from json: [String: Any]) -> String? {
        let choices = json["choices"] as? [[String: Any]] ?? []
        let text = choices.compactMap { choice -> String? in
            guard let message = choice["message"] as? [String: Any] else { return nil }
            if let content = message["content"] as? String, !content.isEmpty {
                return content
            }
            if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
                return reasoning
            }
            return nil
        }
        .joined()
        return text.isEmpty ? nil : text
    }
}
