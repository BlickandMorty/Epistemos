#if EPISTEMOS_APP_STORE
import Foundation

nonisolated struct JuneSystemPromptForgePreviewPayload: Sendable {
    let originalText: String
    let upgradedText: String
    let changed: Bool
    let mode: String
    let groundingStatus: String
    let changeSummary: [String]
    let clarifyingQuestions: [String]
    let patternsApplied: [String]

    var dictionary: [String: Any] {
        [
            "originalText": originalText,
            "upgradedText": upgradedText,
            "changed": changed,
            "mode": mode,
            "groundingStatus": groundingStatus,
            "changeSummary": changeSummary,
            "clarifyingQuestions": clarifyingQuestions,
            "patternsApplied": patternsApplied,
            "citations": [[String: String]](),
        ]
    }
}

nonisolated struct JuneSystemPromptForge: Sendable {
    static let mode = "System Prompt Forge disabled in MAS"
    private static let maxPromptCharacters = 20_000
    private static let disabledStatus = "System Prompt Forge is disabled in this MAS build. June sends prompts unchanged."

    static func settingsPayload() -> [String: Any] {
        return [
            "customPrompt": "",
            "acceptedPrompt": "",
            "appliedPatternIds": [String](),
            "patterns": [[String: String]](),
            "mode": mode,
            "groundingStatus": disabledStatus,
            "disabled": true,
        ]
    }

    static func previewPayload(
        originalText: String,
        patternIDs _: [String],
        activeVaultURL _: URL?
    ) -> JuneSystemPromptForgePreviewPayload {
        let original = boundedPrompt(originalText, maxCharacters: maxPromptCharacters)

        return JuneSystemPromptForgePreviewPayload(
            originalText: original,
            upgradedText: original,
            changed: false,
            mode: mode,
            groundingStatus: disabledStatus,
            changeSummary: ["Prompt rewriting is disabled; the submitted prompt remains literal."],
            clarifyingQuestions: [],
            patternsApplied: []
        )
    }

    static func savePayload(
        originalText _: String,
        acceptedText _: String,
        patternIDs _: [String]
    ) -> [String: Any] {
        clearState()
        var payload = settingsPayload()
        payload["saved"] = false
        payload["error"] = disabledStatus
        return payload
    }

    static func resetPayload() -> [String: Any] {
        clearState()
        var payload = settingsPayload()
        payload["reset"] = true
        return payload
    }

    static func runtimeLayer(isLocal _: Bool) -> String {
        ""
    }

    private static func boundedPrompt(_ text: String, maxCharacters: Int) -> String {
        String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clearState() {
        guard let url = stateURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func stateURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("JuneAgent", isDirectory: true)
            .appendingPathComponent("system-prompt-forge.json")
    }
}
#endif
