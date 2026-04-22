import Foundation

struct SkillAuthoringDraft: Sendable, Equatable {
    var title: String = ""
    var description: String = ""
    var category: String = ""
    var tagsText: String = ""
    var instructionSheet: String = ""

    var identifier: String {
        SkillDiscoveryCatalog.normalizedIdentifier(forName: title)
    }

    var normalizedCategory: String {
        let normalized = SkillDiscoveryCatalog.normalizedIdentifier(forName: category)
        return normalized.isEmpty ? "general" : normalized
    }

    var tags: [String] {
        tagsText
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { fragment in
                SkillDiscoveryCatalog.normalizedIdentifier(forName: String(fragment))
            }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { partialResult, tag in
                if !partialResult.contains(tag) {
                    partialResult.append(tag)
                }
            }
    }

    func createPayload() throws -> [String: Any] {
        [
            "action": "create",
            "name": try validatedIdentifier(),
            "content": try skillMarkdown(),
        ]
    }

    func skillMarkdown() throws -> String {
        let identifier = try validatedIdentifier()
        let description = try validatedDescription()
        let instructionSheet = try validatedInstructionSheet()
        let title = validatedTitle()

        var lines: [String] = [
            "---",
            "name: \(yamlScalar(identifier))",
            "description: \(yamlScalar(description))",
            "category: \(yamlScalar(normalizedCategory))",
        ]

        if !tags.isEmpty {
            let tagList = tags.map { "\"\($0)\"" }.joined(separator: ", ")
            lines.append("tags: [\(tagList)]")
        }

        lines.append("---")
        lines.append("# \(title)")
        lines.append("")
        lines.append("Use this skill when the task matches \(title.lowercased()) and the instruction sheet below is relevant.")
        lines.append("")
        lines.append("## Instruction Sheet")
        lines.append("")
        lines.append(contentsOf: instructionSheet.components(separatedBy: .newlines))
        return lines.joined(separator: "\n")
    }

    private func yamlScalar(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func validatedIdentifier() throws -> String {
        let normalized = identifier
        guard !normalized.isEmpty else {
            throw SkillAuthoringDraftError.titleRequired
        }
        return normalized
    }

    private func validatedTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Custom Skill" : trimmed
    }

    private func validatedDescription() throws -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkillAuthoringDraftError.descriptionRequired
        }
        return trimmed
    }

    private func validatedInstructionSheet() throws -> String {
        let trimmed = instructionSheet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkillAuthoringDraftError.instructionsRequired
        }
        return trimmed
    }
}

enum SkillAuthoringDraftError: LocalizedError {
    case titleRequired
    case descriptionRequired
    case instructionsRequired

    var errorDescription: String? {
        switch self {
        case .titleRequired:
            "Add a skill title before creating it."
        case .descriptionRequired:
            "Add a short description so the skill can be discovered later."
        case .instructionsRequired:
            "Add an instruction sheet so the model has guidance to follow."
        }
    }
}
