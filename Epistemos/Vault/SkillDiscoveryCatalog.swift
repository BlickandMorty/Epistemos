import Foundation
import OSLog

nonisolated enum SkillDiscoverySource: String, Sendable {
    case bundled
    case codex

    var title: String {
        switch self {
        case .bundled: "Bundled"
        case .codex: "Codex"
        }
    }
}

nonisolated struct SkillDiscoveryRoot: Sendable {
    let url: URL
    let source: SkillDiscoverySource
}

nonisolated struct SkillDiscoveryEntry: Identifiable, Hashable, Sendable {
    let identifier: String
    let description: String
    let category: String
    let tags: [String]
    let source: SkillDiscoverySource
    let sourcePath: String

    var id: String { sourcePath }

    var title: String {
        SkillDiscoveryCatalog.humanized(identifier: identifier)
    }
}

nonisolated enum SkillDiscoveryCatalog {
    private static let log = Logger(subsystem: "com.epistemos", category: "SkillDiscovery")

    static func discoverSkillEntries(
        inRoots roots: [SkillDiscoveryRoot] = defaultRoots(),
        fileManager: FileManager = .default
    ) -> [SkillDiscoveryEntry] {
        roots
            .flatMap { root in
                discoverSkillEntries(in: root, fileManager: fileManager)
            }
            .sorted {
                if $0.identifier == $1.identifier {
                    return $0.source.rawValue < $1.source.rawValue
                }
                return $0.identifier < $1.identifier
            }
    }

    static func derivedIdentifier(forLocalPath path: String) -> String {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            return "skill"
        }

        let url = URL(fileURLWithPath: normalizedPath)
        let baseURL = url.lastPathComponent.caseInsensitiveCompare("SKILL.md") == .orderedSame
            ? url.deletingLastPathComponent()
            : url
        let candidate = baseURL.lastPathComponent.lowercased()
        let filtered = candidate
            .map { character -> Character in
                if character.isASCII,
                   character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." {
                    return character
                }
                return "-"
            }
        let identifier = String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return identifier.isEmpty ? "skill" : identifier
    }

    static func derivedIdentifier(forRemoteLocation location: String) -> String {
        guard let url = URL(string: location),
              let host = url.host, !host.isEmpty else {
            return derivedIdentifier(forLocalPath: location)
        }
        return derivedIdentifier(forLocalPath: url.path)
    }

    static func humanized(identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { fragment in
                fragment.prefix(1).uppercased() + fragment.dropFirst()
            }
            .joined(separator: " ")
    }

    static func normalizedIdentifier(forName rawValue: String) -> String {
        normalizedIdentifier(rawValue)
    }

    private static func defaultRoots(fileManager: FileManager = .default) -> [SkillDiscoveryRoot] {
        var roots: [SkillDiscoveryRoot] = []
        let home = fileManager.homeDirectoryForCurrentUser
        let codexRoot = home
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
        if fileManager.fileExists(atPath: codexRoot.path) {
            roots.append(SkillDiscoveryRoot(url: codexRoot, source: .codex))
        }

        let currentRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".agents", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
        if fileManager.fileExists(atPath: currentRoot.path) {
            roots.append(SkillDiscoveryRoot(url: currentRoot, source: .bundled))
        }

        // Shipped skills bundled with the app. This is what makes note-first
        // skills available to the agent in a deployed build — the cwd root
        // above is only reachable when running from the repo directly, and
        // most user launches will not have a matching layout there.
        if let resourceURL = Bundle.main.resourceURL {
            let bundledRoot = resourceURL
                .appendingPathComponent("DefaultSkills", isDirectory: true)
            if fileManager.fileExists(atPath: bundledRoot.path) {
                roots.append(SkillDiscoveryRoot(url: bundledRoot, source: .bundled))
            }
        }

        return roots
    }

    private static func discoverSkillEntries(
        in root: SkillDiscoveryRoot,
        fileManager: FileManager
    ) -> [SkillDiscoveryEntry] {
        guard let enumerator = fileManager.enumerator(
            at: root.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [SkillDiscoveryEntry] = []
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "SKILL.md" {
            if let entry = parseSkillEntry(skillURL: fileURL, source: root.source) {
                entries.append(entry)
            }
        }
        return entries
    }

    private static func parseSkillEntry(
        skillURL: URL,
        source: SkillDiscoverySource
    ) -> SkillDiscoveryEntry? {
        guard let content = try? String(contentsOf: skillURL, encoding: .utf8) else {
            log.warning("Skipping unreadable skill file at \(skillURL.path, privacy: .public)")
            return nil
        }
        let frontmatter = parseFrontmatter(content)
        let identifier = normalizedIdentifier(
            frontmatter["name"] ?? skillURL.deletingLastPathComponent().lastPathComponent
        )
        guard !identifier.isEmpty else {
            return nil
        }

        let description = frontmatter["description"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = frontmatter["category"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "general"
        let tags = parseTags(frontmatter["tags"])

        return SkillDiscoveryEntry(
            identifier: identifier,
            description: (description?.isEmpty == false ? description : nil) ?? "No description provided.",
            category: category,
            tags: tags,
            source: source,
            sourcePath: skillURL.deletingLastPathComponent().path
        )
    }

    private static func normalizedIdentifier(_ rawValue: String) -> String {
        let lowered = rawValue.lowercased()
        let filtered = lowered.map { character -> Character in
            if character.isASCII,
               character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." {
                return character
            }
            return "-"
        }
        return String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
    }

    private static func parseFrontmatter(_ content: String) -> [String: String] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---" else {
            return [:]
        }

        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            if line == "---" {
                break
            }
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    private static func parseTags(_ rawValue: String?) -> [String] {
        guard let rawValue else {
            return []
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            return trimmed.isEmpty ? [] : [trimmed]
        }

        let inner = trimmed.dropFirst().dropLast()
        return inner
            .split(separator: ",")
            .map { item in
                String(item).trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"'")))
            }
            .filter { !$0.isEmpty }
    }
}
