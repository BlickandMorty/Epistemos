import Foundation
import Darwin
import OSLog

nonisolated enum SkillDiscoverySource: String, Sendable {
    case bundled
    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    case codex
    #endif

    var title: String {
        switch self {
        case .bundled: "Bundled"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codex:
            "Codex"
        #endif
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
    static let maxSkillFileBytes = 1024 * 1024

    static func discoverSkillEntries(
        inRoots roots: [SkillDiscoveryRoot]? = nil,
        fileManager: FileManager = .default,
        forceRefresh: Bool = false
    ) -> [SkillDiscoveryEntry] {
        // App-side storage first: the default (no explicit roots) production
        // path — `AgentCommandCenterState.refreshSkillCatalog()` re-runs this on
        // every command-center present() — serves from the process-wide
        // SkillDiscoveryCache instead of re-walking + re-parsing every SKILL.md
        // on disk. Disk is only touched on a cold cache, an explicit
        // forceRefresh, or when a caller passes its own roots (tests stay
        // isolated). Skill creation and the Settings "Refresh" repopulate the
        // cache with ground truth via forceRefresh.
        let usesDefaultRoots = (roots == nil)
        if usesDefaultRoots, !forceRefresh, let cached = SkillDiscoveryCache.shared.cached() {
            return cached
        }
        let resolvedRoots = roots ?? defaultRoots(fileManager: fileManager)
        let sortedEntries = resolvedRoots
            .flatMap { root in
                discoverSkillEntries(in: root, fileManager: fileManager)
            }
            .sorted {
                if $0.identifier == $1.identifier {
                    let leftPriority = sourcePriority($0.source)
                    let rightPriority = sourcePriority($1.source)
                    if leftPriority == rightPriority {
                        return $0.sourcePath < $1.sourcePath
                    }
                    return leftPriority < rightPriority
                }
                return $0.identifier < $1.identifier
            }
        var seenIdentifiers: Set<String> = []
        let deduped = sortedEntries.filter { entry in
            seenIdentifiers.insert(entry.identifier).inserted
        }
        if usesDefaultRoots {
            SkillDiscoveryCache.shared.store(deduped)
        }
        return deduped
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
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let home = fileManager.homeDirectoryForCurrentUser
        let codexRoot = home
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
        if fileManager.fileExists(atPath: codexRoot.path) {
            roots.append(SkillDiscoveryRoot(url: codexRoot, source: .codex))
        }
        #endif

        if ProcessInfo.processInfo.environment["EPISTEMOS_ENABLE_CWD_SKILL_DISCOVERY"] == "1",
           let workingDirectory = ProcessInfo.processInfo.environment["PWD"],
           !workingDirectory.isEmpty {
            let currentRoot = URL(fileURLWithPath: workingDirectory, isDirectory: true)
                .appendingPathComponent(".agents", isDirectory: true)
                .appendingPathComponent("skills", isDirectory: true)
            if fileManager.fileExists(atPath: currentRoot.path) {
                roots.append(SkillDiscoveryRoot(url: currentRoot, source: .bundled))
            }
        }

        roots.append(contentsOf: bundledSkillRoots(resourceURL: Bundle.main.resourceURL, fileManager: fileManager))

        return roots
    }

    static func bundledSkillRoots(
        resourceURL: URL?,
        fileManager: FileManager = .default
    ) -> [SkillDiscoveryRoot] {
        guard let resourceURL else { return [] }

        let candidates = [
            resourceURL.appendingPathComponent("DefaultSkills", isDirectory: true),
            resourceURL
                .appendingPathComponent("SourceMirror", isDirectory: true)
                .appendingPathComponent(".agents", isDirectory: true)
                .appendingPathComponent("skills", isDirectory: true),
        ]

        return candidates.compactMap { url in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return SkillDiscoveryRoot(url: url, source: .bundled)
        }
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
        guard let content = safeSkillFileContent(skillURL) else {
            log.warning("Skipping unreadable skill file at \(skillURL.path, privacy: .private)")
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

    private static func safeSkillFileContent(_ skillURL: URL) -> String? {
        guard firstExistingSymlinkComponent(in: skillURL.deletingLastPathComponent()) == nil else {
            return nil
        }

        let fd = skillURL.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink <= 1,
              fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxSkillFileBytes) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count <= maxSkillFileBytes else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func firstExistingSymlinkComponent(in url: URL) -> URL? {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        var current = path.hasPrefix("/")
            ? URL(fileURLWithPath: "/", isDirectory: true)
            : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        for component in components {
            current = current.appendingPathComponent(String(component), isDirectory: false)
            var fileStatus = stat()
            guard lstat(current.path, &fileStatus) == 0 else {
                if errno == ENOENT || errno == ENOTDIR {
                    return nil
                }
                return current
            }
            if (fileStatus.st_mode & S_IFMT) == S_IFLNK,
               !isAllowedSystemSymlinkComponent(current, fileStatus: fileStatus) {
                return current
            }
        }
        return nil
    }

    private static func isAllowedSystemSymlinkComponent(_ url: URL, fileStatus: stat) -> Bool {
        url.deletingLastPathComponent().path == "/" && fileStatus.st_uid == 0
    }

    private static func normalizedIdentifier(_ rawValue: String) -> String {
        let lowered = rawValue.lowercased()
        var normalized: [Character] = []
        normalized.reserveCapacity(lowered.count)

        for character in lowered {
            let nextCharacter: Character
            if character.isASCII,
               character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." {
                nextCharacter = character
            } else {
                nextCharacter = "-"
            }

            if let previous = normalized.last,
               isIdentifierSeparator(previous),
               isIdentifierSeparator(nextCharacter) {
                continue
            }
            normalized.append(nextCharacter)
        }

        return String(normalized).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
    }

    private static func isIdentifierSeparator(_ character: Character) -> Bool {
        character == "-" || character == "_" || character == "."
    }

    private static func sourcePriority(_ source: SkillDiscoverySource) -> Int {
        switch source {
        case .bundled: 0
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codex: 1
        #endif
        }
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
            let value = unquotedFrontmatterValue(
                String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
            values[key] = value
        }
        return values
    }

    private static func unquotedFrontmatterValue(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              (first == "\"" || first == "'"),
              first == last else {
            return value
        }
        return String(value.dropFirst().dropLast())
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

// MARK: - App-Side Skill Discovery Cache

/// Process-wide, app-side cache for the discovered SKILL.md catalog. The
/// command-center hot path (`AgentCommandCenterState.refreshSkillCatalog()`,
/// invoked on every present()) consults this FIRST so repeated opens serve the
/// already-parsed catalog from app-side storage instead of re-walking the
/// discovery roots and re-reading + re-parsing every `SKILL.md` on disk. Disk
/// is touched only on a cold cache, an explicit `forceRefresh`, or a caller
/// supplying its own roots. Skill creation and the Settings "Refresh" both go
/// through `forceRefresh`, which repopulates this store with ground truth, so
/// the cache never goes stale against an in-app mutation.
///
/// Backed by an in-process lock rather than a database: the discovery roots on
/// disk remain the durable source, and this is the fast app-side layer in front
/// of them. (`@unchecked Sendable` is justified — every access goes through
/// `lock`.) Mirrors `SkillContentStore` so both skill subsystems — generated
/// (manifest) and authored (SKILL.md) — share one "app-side first" shape.
nonisolated final class SkillDiscoveryCache: @unchecked Sendable {
    static let shared = SkillDiscoveryCache()

    private let lock = NSLock()
    private var entries: [SkillDiscoveryEntry]?

    private init() {}

    /// The last discovered default-root catalog, or nil on a cold cache.
    func cached() -> [SkillDiscoveryEntry]? {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    /// Replace the cached catalog with a freshly discovered one.
    func store(_ entries: [SkillDiscoveryEntry]) {
        lock.lock()
        defer { lock.unlock() }
        self.entries = entries
    }

    /// Drop the cached catalog so the next default-root discovery re-walks disk
    /// once and repopulates. Call after a skill mutation that this process did
    /// not route through `forceRefresh`.
    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        entries = nil
    }
}
