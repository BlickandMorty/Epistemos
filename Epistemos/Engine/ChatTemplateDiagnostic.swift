import Foundation

/// P0 (owner 2026-06-21/22) — reasoning-model refusal diagnosis. The live-chat refusal ("I can't assist…" on
/// every query) is the model's GENUINE output, which points to a MALFORMED prompt: a local model whose tokenizer
/// has no chat_template gets a raw, un-role-wrapped prompt and tends to refuse / produce garbage. This is the
/// automatic version of the owner's asked-for "confirm the chat-template" runtime check: at model load, inspect
/// `<modelDir>/tokenizer_config.json` and LOG loudly when no chat_template is present (the prime refusal suspect),
/// so the cause is pinned the moment a model loads — no manual prompt-string logging needed.
///
/// The detection is a PURE function over the JSON text (unit-tested); the load path just reads the file + logs.
nonisolated enum ChatTemplateDiagnostic {
    /// True iff `tokenizer_config.json` text carries a usable `chat_template`. Handles BOTH on-disk shapes:
    /// a non-empty STRING (`"chat_template": "{% … %}"`), or the newer ARRAY-of-named-templates
    /// (`"chat_template": [{"name": "default", "template": "…"}]`). Absent / empty / wrong-type → false.
    static func chatTemplatePresent(inTokenizerConfigJSON json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = obj["chat_template"] else {
            return false
        }
        if let s = value as? String {
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let arr = value as? [[String: Any]] {
            // any entry with a non-empty `template` counts.
            return arr.contains { entry in
                if let t = entry["template"] as? String {
                    return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return false
            }
        }
        return false
    }

    /// Read `<modelDir>/tokenizer_config.json` and report whether a chat_template is present. `nil` when the
    /// file is absent/unreadable (not a chat model, or a GGUF dir where llama.cpp owns the template) — the
    /// caller treats nil as "can't tell, don't warn".
    static func tokenizerConfigHasChatTemplate(inModelDirectory dir: URL) -> Bool? {
        let url = dir.appendingPathComponent("tokenizer_config.json")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return chatTemplatePresent(inTokenizerConfigJSON: text)
    }

    /// The diagnostic log line for a just-loaded model, or `nil` when nothing noteworthy (template present, or
    /// undeterminable). A non-nil result is the LOUD warning: this model will likely refuse / emit garbage
    /// because its prompt isn't chat-template-wrapped — the P0 refusal signature.
    static func loadWarning(modelID: String, modelDirectory: URL) -> String? {
        switch tokenizerConfigHasChatTemplate(inModelDirectory: modelDirectory) {
        case .some(false):
            return "P0 chat-template: model \(modelID) has NO chat_template in tokenizer_config.json — its prompt "
                + "will NOT be role-wrapped, the likely cause of universal refusals / garbage output. "
                + "Verify the model's tokenizer_config.json carries a chat_template."
        case .some(true), .none:
            return nil
        }
    }
}
