import Testing
import Foundation
@testable import Epistemos

/// Data + finetune substrate (owner 2026-06-18) — locks the native chat→text
/// bridge that lets mlx-swift-lm's LoRA trainer consume Epistemos's chat JSONL
/// WITHOUT Python. The native `loadJSONL` reads only `{"text": …}`; Epistemos
/// emits `{"messages": […]}`, so this converter is the gap-closer.
@Suite("LoRA chat data converter")
struct LoRAChatDataConverterTests {

    @Test("parses a real Epistemos chat line into messages")
    func parsesChatLine() throws {
        let line = #"{"messages": [{"role": "system", "content": "You are Epistemos."}, {"role": "user", "content": "What is X?"}, {"role": "assistant", "content": "X is Y."}]}"#
        let messages = try #require(LoRAChatDataConverter.parseChatLine(line))
        #expect(messages.count == 3)
        #expect(messages[0].role == "system")
        #expect(messages[1].content == "What is X?")
        #expect(messages[2].role == "assistant")
    }

    @Test("skips blank, non-object, text-only, and empty-messages lines (no crash)")
    func skipsInvalidLines() {
        #expect(LoRAChatDataConverter.parseChatLine("") == nil)
        #expect(LoRAChatDataConverter.parseChatLine("   ") == nil)
        #expect(LoRAChatDataConverter.parseChatLine("not json") == nil)
        #expect(LoRAChatDataConverter.parseChatLine(#"{"text": "raw"}"#) == nil)   // already text-format
        #expect(LoRAChatDataConverter.parseChatLine(#"{"messages": []}"#) == nil)  // empty
        #expect(LoRAChatDataConverter.parseChatLine(#"{"messages": [{"role":"user"}]}"#) == nil)  // missing content
    }

    @Test("flattens messages into a ChatML training string")
    func flattensToChatML() {
        let messages = [
            LoRAChatMessage(role: "user", content: "Hi"),
            LoRAChatMessage(role: "assistant", content: "Hello"),
        ]
        let text = LoRAChatDataConverter.flatten(messages)
        #expect(text == "<|im_start|>user\nHi<|im_end|>\n<|im_start|>assistant\nHello<|im_end|>")
    }

    @Test("texts(fromChatJSONL:) keeps valid examples and drops invalid ones")
    func convertsMultilineContent() {
        let content = [
            #"{"messages": [{"role": "user", "content": "A"}, {"role": "assistant", "content": "B"}]}"#,
            "",                                   // blank → skipped
            #"{"text": "stray"}"#,                // text-only → skipped
            #"{"messages": [{"role": "user", "content": "C"}, {"role": "assistant", "content": "D"}]}"#,
        ].joined(separator: "\n")
        let texts = LoRAChatDataConverter.texts(fromChatJSONL: content)
        #expect(texts.count == 2)
        #expect(texts[0].contains("A") && texts[0].contains("B"))
        #expect(texts[1].contains("C") && texts[1].contains("D"))
    }

    @Test("toTextJSONL emits lines the native loadJSONL Line struct can decode")
    func emitsNativeReadableTextJSONL() throws {
        let jsonl = LoRAChatDataConverter.toTextJSONL(["hello world", "second"])
        let lines = jsonl.split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        // Each line must decode against the native `{ text: String? }` shape.
        struct NativeLine: Codable { let text: String? }
        for line in lines {
            let decoded = try JSONDecoder().decode(NativeLine.self, from: Data(line.utf8))
            #expect(decoded.text != nil)
        }
    }

    @Test("convertFile bridges a chat-JSONL file to a text-JSONL file on disk")
    func convertFileRoundTrips() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-lora-conv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("chat.jsonl")
        let dest = dir.appendingPathComponent("train.jsonl")
        try #"{"messages": [{"role": "user", "content": "Q"}, {"role": "assistant", "content": "A"}]}"#
            .write(to: source, atomically: true, encoding: .utf8)

        let written = try LoRAChatDataConverter.convertFile(from: source, to: dest)
        #expect(written == 1)
        let out = try String(contentsOf: dest, encoding: .utf8)
        #expect(out.contains("\"text\""))
        #expect(out.contains("<|im_start|>user"))
    }
}
