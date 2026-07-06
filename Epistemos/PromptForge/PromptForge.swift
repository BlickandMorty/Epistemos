import Foundation

nonisolated struct PromptForgeContextSnippet: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let source: String
    let excerpt: String
    let priority: Int

    init(
        id: String,
        title: String,
        source: String,
        excerpt: String,
        priority: Int = 0
    ) {
        let cleanedTitle = Self.clean(title, limit: 160)
        let cleanedSource = Self.clean(source, limit: 120)
        let cleanedExcerpt = Self.clean(excerpt, limit: PromptForgeService.maxContextSnippetCharacters)
        let fallbackID = Self.clean(id, limit: 80)
            ?? Self.stableFallbackID(title: cleanedTitle, source: cleanedSource, excerpt: cleanedExcerpt)
        self.id = fallbackID
        self.title = cleanedTitle ?? fallbackID
        self.source = cleanedSource ?? "Epistemos"
        self.excerpt = cleanedExcerpt ?? ""
        self.priority = priority
    }

    private static func clean(_ value: String, limit: Int) -> String? {
        PromptForgeText.clean(value, limit: limit)
    }

    private static func stableFallbackID(title: String?, source: String?, excerpt: String?) -> String {
        let raw = [title, source, excerpt].compactMap(\.self).joined(separator: " ")
        var output = ""
        var previousWasDash = false
        for scalar in raw.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash, !output.isEmpty {
                output.append("-")
                previousWasDash = true
            }
            if output.count >= 80 { break }
        }
        let trimmed = output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "context" : trimmed
    }
}

struct PromptForgeCitation: Equatable, Sendable {
    let marker: String
    let title: String
    let source: String
}

struct PromptForgeChange: Equatable, Sendable {
    let label: String
    let detail: String
}

struct PromptForgeRequest: Equatable, Sendable {
    var originalPrompt: String
    var surface: String
    var taskHint: String?
    var contextSnippets: [PromptForgeContextSnippet]
    var maxOutputCharacters: Int
    var variant: Int

    init(
        originalPrompt: String,
        surface: String,
        taskHint: String? = nil,
        contextSnippets: [PromptForgeContextSnippet] = [],
        maxOutputCharacters: Int = 6_000,
        variant: Int = 0
    ) {
        self.originalPrompt = originalPrompt
        self.surface = surface
        self.taskHint = taskHint
        self.contextSnippets = contextSnippets
        self.maxOutputCharacters = max(1_200, maxOutputCharacters)
        self.variant = max(0, variant)
    }
}

struct PromptForgeResult: Equatable, Sendable {
    var originalPrompt: String
    var upgradedPrompt: String
    var changes: [PromptForgeChange]
    var citations: [PromptForgeCitation]
    var clarifyingQuestions: [String]
    var groundingStatus: String

    var didChange: Bool {
        originalPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            != upgradedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PromptForgeService {
    nonisolated static let maxOriginalPromptCharacters = 12_000
    nonisolated static let maxContextSnippetCharacters = 900
    nonisolated static let maxClarifyingQuestions = 3

    nonisolated static func upgrade(_ request: PromptForgeRequest) -> PromptForgeResult {
        let original = PromptForgeText.clean(
            request.originalPrompt,
            limit: maxOriginalPromptCharacters
        ) ?? ""
        guard !original.isEmpty else {
            return PromptForgeResult(
                originalPrompt: "",
                upgradedPrompt: "",
                changes: [],
                citations: [],
                clarifyingQuestions: ["What would you like the agent to accomplish?"],
                groundingStatus: "No prompt supplied."
            )
        }

        let taskKind = inferTaskKind(original: original, taskHint: request.taskHint)
        let questions = clarifyingQuestions(for: original, taskKind: taskKind)
        let snippets = selectedContextSnippets(
            request.contextSnippets,
            maxOutputCharacters: request.maxOutputCharacters
        )
        let citations = snippets.enumerated().map { index, snippet in
            PromptForgeCitation(marker: "[PF\(index + 1)]", title: snippet.title, source: snippet.source)
        }
        let groundingStatus = citations.isEmpty
            ? "No vault or app context was supplied; this upgrade is structure-only."
            : "Grounded with \(citations.count) Epistemos context snippet\(citations.count == 1 ? "" : "s")."
        let upgraded = assembledPrompt(
            original: original,
            surface: request.surface,
            taskKind: taskKind,
            questions: questions,
            snippets: snippets,
            citations: citations,
            maxOutputCharacters: request.maxOutputCharacters,
            variant: request.variant
        )

        return PromptForgeResult(
            originalPrompt: original,
            upgradedPrompt: upgraded,
            changes: changes(
                original: original,
                taskKind: taskKind,
                questions: questions,
                citations: citations,
                variant: request.variant
            ),
            citations: citations,
            clarifyingQuestions: questions,
            groundingStatus: groundingStatus
        )
    }

    private nonisolated static func inferTaskKind(original: String, taskHint: String?) -> String {
        let haystack = "\(original) \(taskHint ?? "")".lowercased()
        if haystack.contains("code") || haystack.contains("bug") || haystack.contains("refactor")
            || haystack.contains("test") || haystack.contains("build") {
            return "software engineering"
        }
        if haystack.contains("summarize") || haystack.contains("research") || haystack.contains("compare")
            || haystack.contains("analyze") {
            return "research synthesis"
        }
        if haystack.contains("write") || haystack.contains("draft") || haystack.contains("email")
            || haystack.contains("copy") {
            return "writing"
        }
        return "general task"
    }

    private nonisolated static func clarifyingQuestions(
        for original: String,
        taskKind: String
    ) -> [String] {
        var questions: [String] = []
        let words = original.split(whereSeparator: \.isWhitespace)
        let lower = original.lowercased()

        if words.count < 7 {
            questions.append("What concrete outcome should the agent produce?")
        }
        if taskKind == "software engineering",
           !lower.contains("test") && !lower.contains("verify") && !lower.contains("build") {
            questions.append("What verification should prove the change worked?")
        }
        if !lower.contains("done") && !lower.contains("success") && !lower.contains("acceptance") {
            questions.append("What is the done bar or acceptance criterion?")
        }
        return Array(questions.prefix(maxClarifyingQuestions))
    }

    private nonisolated static func selectedContextSnippets(
        _ snippets: [PromptForgeContextSnippet],
        maxOutputCharacters: Int
    ) -> [PromptForgeContextSnippet] {
        let contextBudget = max(600, min(2_400, maxOutputCharacters / 3))
        var used = 0
        var selected: [PromptForgeContextSnippet] = []
        for snippet in snippets
            .filter({ !$0.excerpt.isEmpty })
            .sorted(by: { lhs, rhs in
                if lhs.priority == rhs.priority { return lhs.title < rhs.title }
                return lhs.priority > rhs.priority
            }) {
            let projected = used + snippet.title.count + snippet.source.count + snippet.excerpt.count + 16
            guard projected <= contextBudget || selected.isEmpty else { continue }
            selected.append(snippet)
            used = projected
        }
        return selected
    }

    private nonisolated static func changes(
        original: String,
        taskKind: String,
        questions: [String],
        citations: [PromptForgeCitation],
        variant: Int
    ) -> [PromptForgeChange] {
        var out: [PromptForgeChange] = [
            PromptForgeChange(label: "intent", detail: "Preserved the original request verbatim."),
            PromptForgeChange(label: "structure", detail: "Added goal, constraints, output, and quality-bar sections."),
            PromptForgeChange(label: "technique", detail: "Applied a \(taskKind) prompting scaffold."),
        ]
        if !citations.isEmpty {
            out.append(PromptForgeChange(label: "context", detail: "Injected cited Epistemos context."))
        }
        if !questions.isEmpty {
            out.append(PromptForgeChange(label: "clarify", detail: "Raised \(questions.count) ambiguity question\(questions.count == 1 ? "" : "s")."))
        }
        if variant > 0 {
            out.append(PromptForgeChange(label: "retry", detail: "Generated alternate structure variant \(variant + 1)."))
        }
        return out
    }

    private nonisolated static func assembledPrompt(
        original: String,
        surface: String,
        taskKind: String,
        questions: [String],
        snippets: [PromptForgeContextSnippet],
        citations: [PromptForgeCitation],
        maxOutputCharacters: Int,
        variant: Int
    ) -> String {
        let contextLines = zip(snippets, citations).map { snippet, citation in
            "\(citation.marker) \(snippet.title) (\(snippet.source)): \(snippet.excerpt)"
        }
        let technique = techniqueLine(for: taskKind)
        let body: String
        if variant.isMultiple(of: 2) {
            body = markdownPrompt(
                original: original,
                surface: surface,
                taskKind: taskKind,
                technique: technique,
                questions: questions,
                contextLines: contextLines
            )
        } else {
            body = taggedPrompt(
                original: original,
                surface: surface,
                taskKind: taskKind,
                technique: technique,
                questions: questions,
                contextLines: contextLines
            )
        }
        return PromptForgeText.clean(body, limit: maxOutputCharacters) ?? original
    }

    private nonisolated static func markdownPrompt(
        original: String,
        surface: String,
        taskKind: String,
        technique: String,
        questions: [String],
        contextLines: [String]
    ) -> String {
        var lines: [String] = [
            "# Upgraded request",
            "",
            "## Intent",
            original,
            "",
            "## Task frame",
            "- Surface: \(PromptForgeText.clean(surface, limit: 80) ?? "Epistemos")",
            "- Task type: \(taskKind)",
            "- Preserve the user's nouns, constraints, and voice.",
            "",
            "## Context",
        ]
        if contextLines.isEmpty {
            lines.append("- No Epistemos vault/app context was supplied. Do not invent citations.")
        } else {
            lines.append(contentsOf: contextLines.map { "- \($0)" })
        }
        lines += [
            "",
            "## Method",
            "- \(technique)",
            "- State assumptions explicitly.",
            "- Ask only the clarifying questions that would change the outcome.",
            "",
            "## Output contract",
            "- Deliver the requested artifact first.",
            "- Include verification or evidence appropriate to the task.",
            "- Keep the answer concise unless the task requires detail.",
        ]
        if !questions.isEmpty {
            lines += ["", "## Clarifying questions if needed"]
            lines.append(contentsOf: questions.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated static func taggedPrompt(
        original: String,
        surface: String,
        taskKind: String,
        technique: String,
        questions: [String],
        contextLines: [String]
    ) -> String {
        var lines: [String] = [
            "<request>",
            "<intent>\(PromptForgeText.xmlEscaped(original))</intent>",
            "<surface>\(PromptForgeText.xmlEscaped(PromptForgeText.clean(surface, limit: 80) ?? "Epistemos"))</surface>",
            "<task_type>\(PromptForgeText.xmlEscaped(taskKind))</task_type>",
            "<context>",
        ]
        if contextLines.isEmpty {
            lines.append("No Epistemos vault/app context was supplied. Do not invent citations.")
        } else {
            lines.append(contentsOf: contextLines.map(PromptForgeText.xmlEscaped))
        }
        lines += [
            "</context>",
            "<method>\(PromptForgeText.xmlEscaped(technique)) State assumptions explicitly and preserve the user's voice.</method>",
            "<output_contract>Deliver the requested artifact first, then verification or evidence.</output_contract>",
        ]
        if !questions.isEmpty {
            lines.append("<clarifying_questions>")
            lines.append(contentsOf: questions.map { "<question>\(PromptForgeText.xmlEscaped($0))</question>" })
            lines.append("</clarifying_questions>")
        }
        lines.append("</request>")
        return lines.joined(separator: "\n")
    }

    private nonisolated static func techniqueLine(for taskKind: String) -> String {
        switch taskKind {
        case "software engineering":
            return "Use a read-first implementation plan, call out constraints, make the smallest safe change, and name the verification checkpoint."
        case "research synthesis":
            return "Compare sources, separate evidence from inference, cite context, and state uncertainty."
        case "writing":
            return "Preserve audience and tone, clarify structure, and make the desired format explicit."
        default:
            return "Decompose the task into goal, constraints, context, deliverable, and done bar."
        }
    }
}

enum PromptForgeText {
    nonisolated static func clean(_ value: String?, limit: Int) -> String? {
        let bounded = String((value ?? "").prefix(limit + 32))
        let withoutNUL = bounded.replacingOccurrences(of: "\0", with: "")
        let collapsed = withoutNUL
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard limit > 3, collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit - 3)) + "..."
    }

    nonisolated static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
