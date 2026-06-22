import Testing
import Foundation
@testable import Epistemos

/// P0 (owner 2026-06-21/22): the chat-template detection behind the load-time refusal diagnostic. A local model
/// whose tokenizer_config.json has no chat_template gets an un-role-wrapped prompt → the likely cause of the
/// universal "I can't assist" refusal. This locks the pure detection (the load path just reads the file + logs).
@Suite("Chat-template diagnostic — detect a missing chat_template (P0 refusal pin)")
struct ChatTemplateDiagnosticTests {
    @Test("a non-empty string chat_template is present")
    func stringTemplatePresent() {
        let json = #"{"chat_template": "{% for m in messages %}{{ m.content }}{% endfor %}", "bos_token": "<s>"}"#
        #expect(ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: json))
    }

    @Test("the array-of-named-templates shape is present when any template is non-empty")
    func arrayTemplatePresent() {
        let json = #"{"chat_template": [{"name": "default", "template": "{{ x }}"}, {"name": "tool", "template": ""}]}"#
        #expect(ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: json))
    }

    @Test("absent / empty / wrong-type chat_template is NOT present (the refusal signature)")
    func absentTemplate() {
        #expect(!ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: #"{"bos_token": "<s>"}"#))
        #expect(!ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: #"{"chat_template": ""}"#))
        #expect(!ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: #"{"chat_template": "   "}"#))
        #expect(!ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: #"{"chat_template": []}"#))
        #expect(!ChatTemplateDiagnostic.chatTemplatePresent(inTokenizerConfigJSON: "not json"))
    }

    @Test("loadWarning fires for a model dir with a template-less tokenizer_config.json, stays silent otherwise")
    func loadWarningFromDirectory() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cttest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cfg = dir.appendingPathComponent("tokenizer_config.json")

        // template-less → a warning naming the model + the refusal cause.
        try #"{"bos_token": "<s>"}"#.write(to: cfg, atomically: true, encoding: .utf8)
        let warning = ChatTemplateDiagnostic.loadWarning(modelID: "vibethinker-3b", modelDirectory: dir)
        #expect(warning != nil)
        #expect(warning?.contains("vibethinker-3b") == true)
        #expect(warning?.contains("chat_template") == true)

        // template present → silent.
        try #"{"chat_template": "{{ x }}"}"#.write(to: cfg, atomically: true, encoding: .utf8)
        #expect(ChatTemplateDiagnostic.loadWarning(modelID: "vibethinker-3b", modelDirectory: dir) == nil)

        // no file at all (e.g. a GGUF dir) → can't tell → silent (nil).
        let empty = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cttest-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        #expect(ChatTemplateDiagnostic.loadWarning(modelID: "x", modelDirectory: empty) == nil)
    }
}
