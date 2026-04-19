import Foundation

struct AgentPlanDocumentBudget: Equatable, Sendable {
    let label: String
    let value: Int
}

struct AgentPlanDocumentSeed: Equatable, Sendable {
    let query: String
    let summary: String
    let operatingMode: String
    let route: String
    let experts: [String]
    let budgets: [AgentPlanDocumentBudget]
}

nonisolated enum AgentPlanDocumentBuilder {
    static func makeDocument(
        seed: AgentPlanDocumentSeed?,
        planCandidate: String? = nil
    ) -> String {
        let normalizedCandidate = normalizePlanCandidate(planCandidate)

        guard let seed else {
            return normalizedCandidate ?? ""
        }

        var sections = ["# Agent Plan"]

        let query = trimmed(seed.query)
        if !query.isEmpty {
            sections.append("""
            ## Objective
            \(query)
            """)
        }

        var runtimeLines: [String] = []
        let operatingMode = trimmed(seed.operatingMode)
        if !operatingMode.isEmpty {
            runtimeLines.append("- Mode: \(operatingMode)")
        }
        let route = trimmed(seed.route)
        if !route.isEmpty {
            runtimeLines.append("- Route: \(route)")
        }
        if !runtimeLines.isEmpty {
            sections.append("""
            ## Runtime
            \(runtimeLines.joined(separator: "\n"))
            """)
        }

        if !seed.experts.isEmpty {
            sections.append("""
            ## Experts
            \(seed.experts.map { "- \($0)" }.joined(separator: "\n"))
            """)
        }

        if !seed.budgets.isEmpty {
            sections.append("""
            ## Budgets
            \(seed.budgets.map { "- \($0.label): \($0.value)" }.joined(separator: "\n"))
            """)
        }

        if let normalizedCandidate {
            sections.append(normalizedCandidate)
        } else {
            let summary = trimmed(seed.summary)
            if !summary.isEmpty {
                sections.append("""
                ## Working Plan
                \(summary)
                """)
            }
        }

        return sections.joined(separator: "\n\n")
    }

    static func extractPlanCandidate(from response: String) -> String? {
        let text = trimmed(response)
        guard !text.isEmpty else { return nil }

        let lines = text.components(separatedBy: .newlines)
        guard let firstNonEmptyLine = lines.first(where: { !trimmed($0).isEmpty }) else {
            return nil
        }

        if isMarkdownHeading(firstNonEmptyLine) {
            return text
        }

        if let headingIndex = lines.firstIndex(where: isPlanHeading) {
            let tail = lines[headingIndex...].joined(separator: "\n")
            return trimmed(tail)
        }

        if let checklistIndex = firstChecklistIndex(in: lines) {
            let tail = lines[checklistIndex...].joined(separator: "\n")
            return trimmed(tail)
        }

        let numberedLines = lines.filter(isNumberedListLine)
        if numberedLines.count >= 2,
           text.localizedCaseInsensitiveContains("plan")
                || text.localizedCaseInsensitiveContains("next step")
                || text.localizedCaseInsensitiveContains("todo")
                || text.localizedCaseInsensitiveContains("to-do"),
           let firstNumberedIndex = lines.firstIndex(where: isNumberedListLine) {
            let tail = lines[firstNumberedIndex...].joined(separator: "\n")
            return trimmed(tail)
        }

        return nil
    }

    private static func normalizePlanCandidate(_ text: String?) -> String? {
        let text = trimmed(text ?? "")
        guard !text.isEmpty else { return nil }
        if isMarkdownHeading(text.components(separatedBy: .newlines).first ?? "") {
            return text
        }
        return """
        ## Working Plan
        \(text)
        """
    }

    private static func firstChecklistIndex(in lines: [String]) -> Int? {
        let matches = lines.enumerated().filter { isChecklistLine($0.element) }
        guard matches.count >= 2 else { return nil }
        return matches.first?.offset
    }

    private static func isPlanHeading(_ line: String) -> Bool {
        let cleaned = trimmed(
            line.replacingOccurrences(
                of: #"^#{1,6}\s*"#,
                with: "",
                options: .regularExpression
            )
        ).lowercased()

        return cleaned.hasPrefix("plan")
            || cleaned.hasPrefix("todo")
            || cleaned.hasPrefix("to-do")
            || cleaned.hasPrefix("next steps")
            || cleaned.hasPrefix("execution plan")
            || cleaned.hasPrefix("implementation plan")
            || cleaned.hasPrefix("tasks")
            || cleaned.hasPrefix("checklist")
    }

    private static func isMarkdownHeading(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        return trimmedLine.hasPrefix("# ")
            || trimmedLine.hasPrefix("## ")
            || trimmedLine.hasPrefix("### ")
            || trimmedLine.hasPrefix("#### ")
            || trimmedLine.hasPrefix("##### ")
            || trimmedLine.hasPrefix("###### ")
    }

    private static func isChecklistLine(_ line: String) -> Bool {
        trimmed(line).range(
            of: #"^[-*+]\s+\[[ xX]\]\s+"#,
            options: .regularExpression
        ) != nil
    }

    private static func isNumberedListLine(_ line: String) -> Bool {
        trimmed(line).range(
            of: #"^\d+\.\s+"#,
            options: .regularExpression
        ) != nil
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
