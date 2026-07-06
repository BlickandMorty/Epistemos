#if EPISTEMOS_APP_STORE
import Foundation

nonisolated struct JuneSystemPromptForgePattern: Sendable {
    let id: String
    let title: String
    let summary: String
    let body: String

    var dictionary: [String: String] {
        [
            "id": id,
            "title": title,
            "summary": summary,
            "body": body,
        ]
    }
}

nonisolated struct JuneSystemPromptForgePreviewPayload: Sendable {
    let originalText: String
    let upgradedText: String
    let changed: Bool
    let mode: String
    let groundingStatus: String
    let changeSummary: [String]
    let clarifyingQuestions: [String]
    let patternsApplied: [String]
    let citations: [JunePromptForgeCitationPayload]

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
            "citations": citations.map(\.dictionary),
        ]
    }
}

nonisolated struct JuneSystemPromptForge: Sendable {
    private struct StoredState: Codable, Sendable {
        var customPrompt: String
        var acceptedPrompt: String
        var patternIDs: [String]
    }

    static let mode = "On-device deterministic System Prompt Forge"
    private static let maxPromptCharacters = 20_000
    private static let maxAcceptedCharacters = 32_000
    private static let maxRuntimeLayerCharacters = 36_000

    private static let emptyState = StoredState(
        customPrompt: "",
        acceptedPrompt: "",
        patternIDs: []
    )

    private static let patterns: [JuneSystemPromptForgePattern] = [
        JuneSystemPromptForgePattern(
            id: "vault-native-researcher",
            title: "Vault-native researcher",
            summary: "Prefer active-vault evidence, citations, and provenance-aware writeback.",
            body: """
            Act as a vault-native research partner. Prefer the user's active vault as the first knowledge substrate, cite relative note paths when vault context is used, keep assumptions separate from sourced claims, and route any vault-changing action through the approved June permission path.
            """
        ),
        JuneSystemPromptForgePattern(
            id: "compact-local-lane",
            title: "Compact local lane",
            summary: "Compress behavior for lower-context on-device models without pretending they have tools.",
            body: """
            When the selected lane is local, use a compact answer contract: preserve the user's nouns and constraints, avoid broad scaffolding, ask at most three outcome-changing questions, and state plainly that local mode is chat-only if tool use or vault mutation is requested.
            """
        ),
        JuneSystemPromptForgePattern(
            id: "enterprise-change-discipline",
            title: "Enterprise change discipline",
            summary: "Read first, scope tightly, verify deliberately, and report remaining proof gaps.",
            body: """
            For engineering or agentic build work, read the owning source before changing it, keep edits inside the requested lane, prefer existing APIs over parallel implementations, verify with the smallest meaningful check first, and name any build/runtime proof that remains open.
            """
        ),
    ]

    static func settingsPayload() -> [String: Any] {
        let state = loadState()
        return [
            "customPrompt": state.customPrompt,
            "acceptedPrompt": state.acceptedPrompt,
            "appliedPatternIds": boundedPatternIDs(state.patternIDs),
            "patterns": patterns.map(\.dictionary),
            "mode": mode,
            "groundingStatus": state.acceptedPrompt.isEmpty
                ? "No accepted System Prompt Forge layer is active."
                : "Accepted System Prompt Forge layer will be composed into June instructions.",
        ]
    }

    static func previewPayload(
        originalText: String,
        patternIDs: [String],
        activeVaultURL: URL?
    ) -> JuneSystemPromptForgePreviewPayload {
        let original = boundedPrompt(originalText, maxCharacters: maxPromptCharacters)
        let selectedPatterns = selectedPatterns(from: patternIDs)
        let groundingPrompt = ([original] + selectedPatterns.map { "\($0.title): \($0.summary)" })
            .joined(separator: "\n")
        let grounding = JunePromptForge().previewPayload(
            originalText: groundingPrompt.isEmpty ? "June system behavior" : groundingPrompt,
            modelID: JuneModelID.cloud,
            activeVaultURL: activeVaultURL
        )
        let upgraded = upgradedSystemPrompt(
            from: original,
            selectedPatterns: selectedPatterns,
            citations: grounding.citations
        )
        let patternTitles = selectedPatterns.map(\.title)
        let groundingStatus = grounding.citations.isEmpty
            ? "No active-vault behavior notes matched; no citations were invented."
            : "Grounded with \(grounding.citations.count) active-vault note\(grounding.citations.count == 1 ? "" : "s")."
        var summary = [
            "Layered the behavior into identity, capability honesty, tool contract, refusal framing, output contract, and priority budget.",
            "Preserved the user's custom behavior text inside an explicit intent block.",
            "Added a local-lane override so on-device models stay chat-tier and compact-context.",
        ]
        summary.append(patternTitles.isEmpty ? "No library pattern was applied." : "Applied \(patternTitles.joined(separator: ", ")).")
        summary.append(grounding.citations.isEmpty ? "Left vault grounding empty honestly." : "Injected bounded vault citations from the active vault.")

        return JuneSystemPromptForgePreviewPayload(
            originalText: original,
            upgradedText: upgraded,
            changed: upgraded != original,
            mode: mode,
            groundingStatus: groundingStatus,
            changeSummary: summary,
            clarifyingQuestions: clarifyingQuestions(for: original),
            patternsApplied: patternTitles,
            citations: grounding.citations
        )
    }

    static func savePayload(
        originalText: String,
        acceptedText: String,
        patternIDs: [String]
    ) -> [String: Any] {
        let state = StoredState(
            customPrompt: boundedPrompt(originalText, maxCharacters: maxPromptCharacters),
            acceptedPrompt: boundedPrompt(acceptedText, maxCharacters: maxAcceptedCharacters),
            patternIDs: boundedPatternIDs(patternIDs)
        )
        let saved = saveState(state)
        var payload = settingsPayload()
        payload["saved"] = saved
        return payload
    }

    static func resetPayload() -> [String: Any] {
        clearState()
        var payload = settingsPayload()
        payload["reset"] = true
        return payload
    }

    static func runtimeLayer(isLocal: Bool) -> String {
        let state = loadState()
        let accepted = boundedPrompt(
            state.acceptedPrompt,
            maxCharacters: maxRuntimeLayerCharacters
        )
        guard !accepted.isEmpty else { return "" }
        let laneGuard: String
        if isLocal {
            laneGuard = """
            Local lane override: this model is chat-tier only. Do not claim tool use, vault mutation, web browsing, background jobs, code execution, or function calling. Keep responses compact for lower-context local models and ask up to three questions only when ambiguity changes the outcome.
            """
        } else {
            laneGuard = """
            Cloud lane contract: cloud is the agentic lane. Use only MAS-approved in-process tools, surface permission requests before vault reads or writes, preserve streamed thinking/tool evidence, and cite vault-derived facts when they affect the answer.
            """
        }
        return """
        <epistemos_system_prompt_forge>
        <lane_guard>
        \(laneGuard)
        </lane_guard>
        <accepted_behavior>
        \(accepted)
        </accepted_behavior>
        </epistemos_system_prompt_forge>
        """
    }

    private static func upgradedSystemPrompt(
        from original: String,
        selectedPatterns: [JuneSystemPromptForgePattern],
        citations: [JunePromptForgeCitationPayload]
    ) -> String {
        var lines: [String] = [
            "Use this behavior layer while preserving the user's original intent and voice.",
            "",
            "<identity>",
            "June is an Epistemos-native assistant embedded in the user's vault, graph, and provenance workflow.",
            "</identity>",
            "",
            "<capability_honesty>",
            "- Local lanes are private chat lanes with compact context and no tools.",
            "- Cloud lanes are agentic only through configured providers and MAS-approved in-process tools.",
            "- If a requested capability is unavailable in the selected lane, say so plainly and offer the honest next step.",
            "</capability_honesty>",
            "",
            "<tool_contract>",
            "- Never invent tool results, vault citations, files, or approvals.",
            "- Ask for permission before reading or writing vault data through the cloud-agent path.",
            "- Preserve streamed thinking/tool evidence for replay without exposing private raw chain-of-thought.",
            "</tool_contract>",
            "",
            "<refusal_framing>",
            "- Refuse or redirect unsafe, unavailable, or sandbox-forbidden requests briefly.",
            "- Keep the useful part of the request alive when a safe alternative exists.",
            "</refusal_framing>",
            "",
            "<output_contract>",
            "- Answer the user's actual request first.",
            "- Separate sourced facts, assumptions, and next actions.",
            "- Prefer concise structure over generic explanation.",
            "</output_contract>",
            "",
            "<priority_budget>",
            "1. Safety, sandbox law, and capability truth.",
            "2. The user's explicit constraints and voice.",
            "3. Vault-grounded evidence and reversible write paths.",
            "4. Brevity and context discipline for the selected model.",
            "</priority_budget>",
        ]

        lines.append("")
        lines.append("<user_behavior_intent>")
        lines.append(original.isEmpty ? "No custom system prompt text was provided." : original)
        lines.append("</user_behavior_intent>")

        if !selectedPatterns.isEmpty {
            lines.append("")
            lines.append("<pattern_library>")
            for pattern in selectedPatterns {
                lines.append("- \(pattern.title): \(pattern.body)")
            }
            lines.append("</pattern_library>")
        }

        lines.append("")
        lines.append("<vault_grounding>")
        if citations.isEmpty {
            lines.append("No active-vault behavior notes matched. Do not invent vault citations.")
        } else {
            for citation in citations {
                lines.append("\(citation.marker) \(citation.path): \(citation.excerpt)")
            }
        }
        lines.append("</vault_grounding>")
        return lines.joined(separator: "\n")
    }

    private static func selectedPatterns(from ids: [String]) -> [JuneSystemPromptForgePattern] {
        let allowedIDs = Set(boundedPatternIDs(ids))
        return patterns.filter { allowedIDs.contains($0.id) }
    }

    private static func boundedPatternIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        let allowed = Set(patterns.map(\.id))
        var bounded: [String] = []
        for id in ids {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= 80,
                  allowed.contains(trimmed),
                  seen.insert(trimmed).inserted else {
                continue
            }
            bounded.append(trimmed)
            if bounded.count == patterns.count { break }
        }
        return bounded
    }

    private static func clarifyingQuestions(for text: String) -> [String] {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return [
            "What enduring role, tone, or constraints should June preserve?",
            "Should this behavior apply to both cloud agentic work and local chat?",
        ]
    }

    private static func boundedPrompt(_ text: String, maxCharacters: Int) -> String {
        String(text.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadState() -> StoredState {
        guard let url = stateURL(),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else {
            return emptyState
        }
        return StoredState(
            customPrompt: boundedPrompt(state.customPrompt, maxCharacters: maxPromptCharacters),
            acceptedPrompt: boundedPrompt(state.acceptedPrompt, maxCharacters: maxAcceptedCharacters),
            patternIDs: boundedPatternIDs(state.patternIDs)
        )
    }

    private static func saveState(_ state: StoredState) -> Bool {
        guard let url = stateURL() else { return false }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
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
