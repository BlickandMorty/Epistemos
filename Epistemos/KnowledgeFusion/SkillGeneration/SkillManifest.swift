import Foundation

// MARK: - Skill Types

struct SkillEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let type: SkillType
    let filePath: String       // Relative to skills directory
    let generatedAt: Date
    let sourceVault: String
    let sourceAdapter: String?
    let confidence: Double     // 0-1, based on how many examples contributed
    let wordCount: Int
}

enum SkillType: String, Codable, Sendable, CaseIterable {
    case codingStyle = "coding-style"
    case toolRegistry = "tools"
    case guardrails = "guardrails"
    case writingVoice = "writing"
    case domainKnowledge = "domain-knowledge"

    nonisolated var displayName: String {
        switch self {
        case .codingStyle: "Coding Style"
        case .toolRegistry: "Tools & APIs"
        case .guardrails: "Guardrails"
        case .writingVoice: "Writing Voice"
        case .domainKnowledge: "Domain Knowledge"
        }
    }

    var icon: String {
        switch self {
        case .codingStyle: "chevron.left.forwardslash.chevron.right"
        case .toolRegistry: "wrench.and.screwdriver"
        case .guardrails: "shield.checkered"
        case .writingVoice: "pencil.and.outline"
        case .domainKnowledge: "book.closed"
        }
    }
}

// MARK: - Skill Manifest

/// Persistent registry of all generated skill files.
/// Stored as JSON in the skills directory.
nonisolated struct SkillManifest: Codable, Sendable {
    var version: Int = 1
    var skills: [SkillEntry] = []
    var lastGeneratedAt: Date?

    static let fileName = "manifest.json"

    nonisolated static var skillsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Epistemos/skills")
    }

    static var manifestURL: URL {
        skillsDirectory.appendingPathComponent(fileName)
    }

    static func load() -> SkillManifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(SkillManifest.self, from: data)
        else { return SkillManifest() }
        return manifest
    }

    func save() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.skillsDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.manifestURL, options: .atomic)
    }

    mutating func addSkill(_ entry: SkillEntry) {
        // Replace existing skill of same type and name
        skills.removeAll { $0.type == entry.type && $0.name == entry.name }
        skills.append(entry)
        lastGeneratedAt = Date()
    }

    /// Get all skill file paths for a given type, for injection into system prompt.
    func skillPaths(for type: SkillType) -> [URL] {
        skills.filter { $0.type == type }.map {
            Self.skillsDirectory.appendingPathComponent($0.filePath)
        }
    }

    /// Load skill file contents for system prompt injection.
    /// Respects a token budget to avoid overflowing context.
    func loadSkillContent(types: [SkillType], maxChars: Int = 8000) -> String {
        var result = ""
        var remaining = maxChars

        for type in types {
            for path in skillPaths(for: type) {
                guard remaining > 0 else { break }
                if let content = try? String(contentsOf: path, encoding: .utf8) {
                    let trimmed = String(content.prefix(remaining))
                    result += "\n--- \(type.displayName) ---\n\(trimmed)\n"
                    remaining -= trimmed.count
                }
            }
        }

        return result
    }
}
