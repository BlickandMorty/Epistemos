import Foundation
import Testing
@testable import Epistemos

@Suite("Cloud LLM Client Vision")
struct CloudLLMClientVisionTests {

    @Test("vision payloads preserve mime type and embed base64 data URLs")
    func visionPayloadsPreserveMimeTypeAndDataURL() throws {
        let imageURL = try temporaryImageURL(named: "diagram.png", bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let payloads = try CloudLLMClient.visionPayloads(from: [imageURL])

        #expect(payloads.count == 1)
        #expect(payloads[0].mimeType == "image/png")
        #expect(payloads[0].base64Data == "iVBORw0K")
        #expect(payloads[0].dataURL == "data:image/png;base64,iVBORw0K")
    }

    @Test("OpenAI vision input includes typed text and image blocks")
    func openAIVisionInputIncludesTypedBlocks() throws {
        let imageURL = try temporaryImageURL(named: "diagram.png", bytes: [0x89, 0x50, 0x4E, 0x47])
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let payloads = try CloudLLMClient.visionPayloads(from: [imageURL])
        let content = CloudLLMClient.openAIUserContent(prompt: "Describe the graph.", imagePayloads: payloads)

        #expect(content.count == 2)
        #expect(content[0]["type"] as? String == "input_text")
        #expect(content[0]["text"] as? String == "Describe the graph.")
        #expect(content[1]["type"] as? String == "input_image")
        #expect((content[1]["image_url"] as? String)?.hasPrefix("data:image/png;base64,") == true)
    }

    @Test("Anthropic vision input includes base64 image source blocks")
    func anthropicVisionInputIncludesBase64SourceBlocks() throws {
        let imageURL = try temporaryImageURL(named: "photo.jpg", bytes: [0xFF, 0xD8, 0xFF, 0xE0])
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let payloads = try CloudLLMClient.visionPayloads(from: [imageURL])
        let content = CloudLLMClient.anthropicMessageContent(prompt: "Summarize the screenshot.", imagePayloads: payloads)

        #expect(content.count == 2)
        #expect(content[0]["type"] as? String == "text")
        #expect(content[0]["text"] as? String == "Summarize the screenshot.")
        #expect(content[1]["type"] as? String == "image")
        let source = try #require(content[1]["source"] as? [String: String])
        #expect(source["type"] == "base64")
        #expect(source["media_type"] == "image/jpeg")
        #expect(source["data"] == "/9j/4A==")
    }

    @Test("Google vision parts include inline base64 image data")
    func googleVisionPartsIncludeInlineImageData() throws {
        let imageURL = try temporaryImageURL(named: "board.webp", bytes: [0x52, 0x49, 0x46, 0x46])
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let payloads = try CloudLLMClient.visionPayloads(from: [imageURL])
        let parts = CloudLLMClient.googleParts(prompt: "Read the whiteboard.", imagePayloads: payloads)

        #expect(parts.count == 2)
        #expect(parts[0]["text"] as? String == "Read the whiteboard.")
        let inlineData = try #require(parts[1]["inlineData"] as? [String: String])
        #expect(inlineData["mimeType"] == "image/webp")
        #expect(inlineData["data"] == "UklGRg==")
    }

    @Test("OpenAI-compatible vision chat messages keep system text and image_url content")
    func openAICompatibleVisionMessagesIncludeImageURLContent() throws {
        let imageURL = try temporaryImageURL(named: "scene.heic", bytes: [0x68, 0x65, 0x69, 0x63])
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let payloads = try CloudLLMClient.visionPayloads(from: [imageURL])
        let messages = CloudLLMClient.compatibleChatMessages(
            prompt: "What changed in this scene?",
            systemPrompt: "Be concise.",
            imagePayloads: payloads
        )

        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[0]["content"] as? String == "Be concise.")
        #expect(messages[1]["role"] as? String == "user")
        let content = try #require(messages[1]["content"] as? [[String: Any]])
        #expect(content.count == 2)
        #expect(content[0]["type"] as? String == "text")
        let imageURLBlock = try #require(content[1]["image_url"] as? [String: String])
        #expect(content[1]["type"] as? String == "image_url")
        #expect(imageURLBlock["url"] == "data:image/heic;base64,aGVpYw==")
    }

    private func temporaryImageURL(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cloud-vision-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name, isDirectory: false)
        try Data(bytes).write(to: url, options: .atomic)
        return url
    }
}
