import Foundation
import OSLog

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
    private static let log = Logger(subsystem: "com.epistemos", category: "SkillManifest")

    var version: Int = 1
    var skills: [SkillEntry] = []
    var lastGeneratedAt: Date?

    static let fileName = "manifest.json"

    nonisolated static var skillsDirectory: URL {
        FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos/skills")
    }

    static var manifestURL: URL {
        skillsDirectory.appendingPathComponent(fileName)
    }

    static func load() -> SkillManifest {
        // App-side storage first: the process-wide SkillContentStore caches the
        // manifest so the common path (every agent turn + direct-chat injection)
        // never re-reads the manifest file. The raw file read is the fallback
        // that populates the store on a cold cache.
        if let cached = SkillContentStore.shared.cachedManifest() {
            return cached
        }
        guard let data = try? Data(contentsOf: manifestURL) else {
            Self.log.warning("Failed to read skill manifest at \(manifestURL.path, privacy: .public)")
            return SkillManifest()
        }
        guard let manifest = try? JSONDecoder().decode(SkillManifest.self, from: data) else {
            Self.log.error("Failed to decode skill manifest at \(manifestURL.path, privacy: .public)")
            return SkillManifest()
        }
        SkillContentStore.shared.storeManifest(manifest)
        return manifest
    }

    func save() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.skillsDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.manifestURL, options: .atomic)
        // Keep the app-side store the source of truth after a write: refresh the
        // cached manifest and drop stale content so regenerated skills are seen
        // on the next load without a process restart.
        SkillContentStore.shared.storeManifest(self)
        SkillContentStore.shared.invalidateContent()
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
                // App-side storage first: hit the in-process content store; the
                // disk read is the fallback that populates it on a miss.
                let key = path.path
                let content: String?
                if let cached = SkillContentStore.shared.content(forPath: key) {
                    content = cached
                } else if let fileContent = try? String(contentsOf: path, encoding: .utf8) {
                    SkillContentStore.shared.store(content: fileContent, forPath: key)
                    content = fileContent
                } else {
                    content = nil
                }
                if let content {
                    let trimmed = String(content.prefix(remaining))
                    result += "\n--- \(type.displayName) ---\n\(trimmed)\n"
                    remaining -= trimmed.count
                }
            }
        }

        return result
    }
}

// MARK: - App-Side Skill Content Store

/// Process-wide, app-side cache for the skill manifest and generated skill
/// content. The skill-injection path (`SkillManifest.load` +
/// `loadSkillContent`) consults this FIRST so the common case — every agent
/// turn and every direct-chat system-prompt injection — reads from app-side
/// storage instead of re-globbing the skills directory on disk. Raw file reads
/// only happen on a cache miss, and they populate the store. `save()`
/// refreshes the cached manifest and drops stale content so regenerated skills
/// are reflected without a process restart.
///
/// Backed by an in-process lock rather than a database: the on-disk files
/// remain the durable backing/export, and this is the fast app-side layer in
/// front of them. (`@unchecked Sendable` is justified — every access goes
/// through `lock`.)
nonisolated final class SkillContentStore: @unchecked Sendable {
    static let shared = SkillContentStore()

    private let lock = NSLock()
    private var manifest: SkillManifest?
    private var contentByPath: [String: String] = [:]

    private init() {}

    func cachedManifest() -> SkillManifest? {
        lock.lock()
        defer { lock.unlock() }
        return manifest
    }

    func storeManifest(_ manifest: SkillManifest) {
        lock.lock()
        defer { lock.unlock() }
        self.manifest = manifest
    }

    func content(forPath path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return contentByPath[path]
    }

    func store(content: String, forPath path: String) {
        lock.lock()
        defer { lock.unlock() }
        contentByPath[path] = content
    }

    /// Drop cached skill-file content (e.g. after regeneration) while keeping
    /// the refreshed manifest. The next `loadSkillContent` re-reads from disk
    /// once and repopulates.
    func invalidateContent() {
        lock.lock()
        defer { lock.unlock() }
        contentByPath.removeAll()
    }

    /// Full reset — drops both the cached manifest and content.
    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        manifest = nil
        contentByPath.removeAll()
    }
}
