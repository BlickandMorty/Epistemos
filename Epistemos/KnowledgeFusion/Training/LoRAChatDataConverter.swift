import Foundation

// Data + finetune substrate (owner 2026-06-18): first NATIVE slice toward killing
// the Python QLoRA black box (QLoRATrainer spawns /usr/bin/python3 — NO-SIDECAR).
//
// mlx-swift-lm ALREADY vendors native LoRA training (MLXLLM.LoRATrain.train +
// loadLoRAData + MLXLMCommon LoRAConfiguration/LoRAContainer), so the kill is
// WIRING, not a from-scratch port. The one real data gap: the native
// `loadJSONL` decodes only `{"text": ...}`, while Epistemos emits CHAT JSONL
// (`{"messages": [{"role","content"}, …]}`). This pure converter bridges that
// gap — flatten each chat example into one training string the native trainer
// reads — entirely in Swift, no Python. Pure + unit-tested; INERT until the
// native trainer slice consumes it.

/// One chat turn from an Epistemos training example.
struct LoRAChatMessage: Codable, Sendable, Equatable {
    let role: String
    let content: String
}

enum LoRAChatDataConverter {
    /// Decode one JSONL line into chat messages. Returns nil for a blank line, a
    /// non-object line, or a line without a non-empty `messages` array (so a
    /// stray `{"text": …}` line or malformed JSON is skipped, not crashed on).
    static func parseChatLine(_ line: String) -> [LoRAChatMessage]? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", let data = trimmed.data(using: .utf8) else { return nil }
        struct Line: Codable { let messages: [LoRAChatMessage]? }
        guard let decoded = try? JSONDecoder().decode(Line.self, from: data),
              let messages = decoded.messages, !messages.isEmpty else { return nil }
        return messages
    }

    /// Flatten chat messages into a single training string using a ChatML-style
    /// template (`<|im_start|>role\ncontent<|im_end|>` per turn). Most instruct
    /// models accept this; the native trainer slice may later substitute the
    /// model's exact tokenizer chat template. Content is used verbatim.
    static func flatten(_ messages: [LoRAChatMessage]) -> String {
        messages
            .map { "<|im_start|>\($0.role)\n\($0.content)<|im_end|>" }
            .joined(separator: "\n")
    }

    /// Pure transform: Epistemos chat-JSONL content → the flattened training
    /// texts (one per valid example). Invalid / blank lines are skipped.
    static func texts(fromChatJSONL content: String) -> [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { parseChatLine(String($0)) }
            .map(flatten)
    }

    /// Encode flattened texts as `{"text": …}` JSONL — the EXACT format
    /// mlx-swift-lm's `loadJSONL` / `LoRATrain` consume.
    static func toTextJSONL(_ texts: [String]) -> String {
        struct TextLine: Encodable { let text: String }
        let encoder = JSONEncoder()
        return texts.compactMap { text -> String? in
            guard let data = try? encoder.encode(TextLine(text: text)) else { return nil }
            return String(data: data, encoding: .utf8)
        }.joined(separator: "\n")
    }

    /// Convert an Epistemos chat-JSONL file into a `{"text": …}` JSONL file the
    /// native trainer reads. Returns the number of examples written. Throws on IO
    /// failure; produces an empty file (0) when no line is a valid chat example.
    @discardableResult
    static func convertFile(from source: URL, to destination: URL) throws -> Int {
        let content = try String(contentsOf: source, encoding: .utf8)
        let converted = texts(fromChatJSONL: content)
        try toTextJSONL(converted).write(to: destination, atomically: true, encoding: .utf8)
        return converted.count
    }
}
