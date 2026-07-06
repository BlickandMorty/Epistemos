import Foundation

struct PromptPattern: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let sections: [String]
}

enum PromptPatternLibrary {
    nonisolated static let authoredPatterns: [PromptPattern] = [
        PromptPattern(
            id: "careful-refactorer",
            title: "Careful Refactorer",
            summary: "Small, source-first code changes with explicit verification.",
            sections: ["identity", "capability honesty", "tool contract", "output contract", "priority", "failure examples"]
        ),
        PromptPattern(
            id: "vault-librarian",
            title: "Vault Librarian",
            summary: "Grounded synthesis from user-owned notes without mutating the vault.",
            sections: ["identity", "boundaries", "citation contract", "privacy", "priority", "failure examples"]
        ),
        PromptPattern(
            id: "research-analyst",
            title: "Research Analyst",
            summary: "Evidence-first comparison with uncertainty and source separation.",
            sections: ["identity", "evidence contract", "tool contract", "output contract", "priority", "failure examples"]
        ),
    ]

    nonisolated static func pattern(id: String) -> PromptPattern? {
        authoredPatterns.first { $0.id == id }
    }
}

struct SystemPromptForgeRequest: Equatable, Sendable {
    var originalSystemPrompt: String
    var patternIDs: [String]
    var contextSnippets: [PromptForgeContextSnippet]
    var maxOutputCharacters: Int

    init(
        originalSystemPrompt: String,
        patternIDs: [String] = [],
        contextSnippets: [PromptForgeContextSnippet] = [],
        maxOutputCharacters: Int = 8_000
    ) {
        self.originalSystemPrompt = originalSystemPrompt
        self.patternIDs = patternIDs
        self.contextSnippets = contextSnippets
        self.maxOutputCharacters = max(1_500, maxOutputCharacters)
    }
}

struct SystemPromptForgeResult: Equatable, Sendable {
    var originalSystemPrompt: String
    var upgradedSystemPrompt: String
    var appliedPatterns: [PromptPattern]
    var citations: [PromptForgeCitation]
    var changes: [PromptForgeChange]

    var didChange: Bool {
        originalSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            != upgradedSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SystemPromptForgeService {
    nonisolated static func upgrade(_ request: SystemPromptForgeRequest) -> SystemPromptForgeResult {
        let original = PromptForgeText.clean(request.originalSystemPrompt, limit: 12_000) ?? ""
        let patterns = selectedPatterns(request.patternIDs)
        let snippets = selectedContextSnippets(request.contextSnippets, maxOutputCharacters: request.maxOutputCharacters)
        let citations = snippets.enumerated().map { index, snippet in
            PromptForgeCitation(marker: "[SPF\(index + 1)]", title: snippet.title, source: snippet.source)
        }
        let upgraded = assemble(
            original: original,
            patterns: patterns,
            snippets: snippets,
            citations: citations,
            maxOutputCharacters: request.maxOutputCharacters
        )
        return SystemPromptForgeResult(
            originalSystemPrompt: original,
            upgradedSystemPrompt: upgraded,
            appliedPatterns: patterns,
            citations: citations,
            changes: changes(patterns: patterns, citations: citations)
        )
    }

    private nonisolated static func selectedPatterns(_ ids: [String]) -> [PromptPattern] {
        let selected = ids.compactMap(PromptPatternLibrary.pattern(id:))
        return selected.isEmpty ? [PromptPatternLibrary.authoredPatterns[0]] : selected
    }

    private nonisolated static func selectedContextSnippets(
        _ snippets: [PromptForgeContextSnippet],
        maxOutputCharacters: Int
    ) -> [PromptForgeContextSnippet] {
        let budget = max(500, min(2_000, maxOutputCharacters / 4))
        var used = 0
        var out: [PromptForgeContextSnippet] = []
        for snippet in snippets
            .filter({ !$0.excerpt.isEmpty })
            .sorted(by: { $0.priority > $1.priority }) {
            let projected = used + snippet.title.count + snippet.excerpt.count + 16
            guard projected <= budget || out.isEmpty else { continue }
            out.append(snippet)
            used = projected
        }
        return out
    }

    private nonisolated static func assemble(
        original: String,
        patterns: [PromptPattern],
        snippets: [PromptForgeContextSnippet],
        citations: [PromptForgeCitation],
        maxOutputCharacters: Int
    ) -> String {
        let patternLines = patterns.map { "- \($0.title): \($0.summary)" }
        let contextLines = zip(snippets, citations).map { snippet, citation in
            "- \(citation.marker) \(snippet.title) (\(snippet.source)): \(snippet.excerpt)"
        }
        let lines: [String] = [
            "# System prompt",
            "",
            "## Identity",
            original.isEmpty ? "You are a careful Epistemos agent." : original,
            "",
            "## Capability honesty",
            "State what you can and cannot do. Do not claim access to tools, files, vault data, realtime data, or user state unless the host has actually supplied it.",
            "",
            "## Tool contract",
            "Use only the tools the host exposes. Follow each tool's invocation and safety contract exactly.",
            "",
            "## Refusal and boundary framing",
            "Decline unsafe or out-of-scope requests briefly, then offer the closest safe alternative.",
            "",
            "## Output contract",
            "Answer in the format the user requested. If no format is requested, lead with the useful result, then include evidence, assumptions, and verification.",
            "",
            "## Priority",
            "In conflicts, prioritize user safety, data boundaries, factual accuracy, preserved intent, and concise usefulness in that order.",
            "",
            "## Applied patterns",
        ] + patternLines + [
            "",
            "## Epistemos context",
        ] + (contextLines.isEmpty ? ["- No vault/app context supplied. Do not invent citations."] : contextLines) + [
            "",
            "## Worked failure examples",
            "- Wrong: silently invent a capability or citation. Correction: state the missing capability/context and continue honestly.",
            "- Wrong: rewrite the user's goal into a different task. Correction: preserve intent and ask a clarifying question when ambiguity changes the outcome.",
            "- Wrong: ignore a protected boundary. Correction: stop at the boundary and report what public API or owner action is needed.",
        ]
        return PromptForgeText.clean(lines.joined(separator: "\n"), limit: maxOutputCharacters)
            ?? original
    }

    private nonisolated static func changes(
        patterns: [PromptPattern],
        citations: [PromptForgeCitation]
    ) -> [PromptForgeChange] {
        var out = [
            PromptForgeChange(label: "architecture", detail: "Layered identity, capability honesty, tools, refusal, output, priority, and failure examples."),
            PromptForgeChange(label: "patterns", detail: "Applied \(patterns.count) authored Epistemos pattern\(patterns.count == 1 ? "" : "s")."),
        ]
        if !citations.isEmpty {
            out.append(PromptForgeChange(label: "context", detail: "Added cited Epistemos context."))
        }
        return out
    }
}
