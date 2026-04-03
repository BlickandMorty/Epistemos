import Foundation
import os

// MARK: - Harness Registry
//
// Versioned storage of harness artifacts: system prompts, tool policies,
// completion checker configs, and metadata. Supports both the production
// runtime (promoted harness) and the developer-only Harness Lab (candidates).
//
// Filesystem layout:
//   ~/Library/Application Support/com.epistemos.app/harness/
//   +-- production/
//   |   +-- current -> v1.0.0/           (symlink to active version)
//   |   +-- v1.0.0/
//   |       +-- metadata.json
//   |       +-- system_prompts/
//   |       |   +-- coding.md
//   |       |   +-- research.md
//   |       |   +-- terminal.md
//   |       |   +-- note_synthesis.md
//   |       +-- tool_policies/
//   |       |   +-- coding.json
//   |       |   +-- research.json
//   |       +-- completion_checkers/
//   |           +-- coding.json
//   |           +-- research.json
//   +-- lab/                              (developer-only)
//       +-- candidates/
//       |   +-- candidate_001/
//       |   |   +-- harness/             (same structure as v1.0.0/)
//       |   |   +-- scores.json
//       |   |   +-- ancestry.json
//       |   +-- candidate_002/
//       +-- task_suite/
//       |   +-- search/
//       |   +-- held_out/
//       +-- search_log.jsonl

/// Metadata for a harness version.
struct HarnessMetadata: Sendable {
    let version: String
    let createdAt: String
    let promotedAt: String?
    let promotedBy: String?
    let parentVersion: String?
    let description: String?
    let scores: HarnessScores?
}

struct HarnessScores: Sendable {
    let searchSetPassRate: Double?
    let testSetPassRate: Double?
    let averageTokenCost: Int?
    let evaluatedAt: String?
}

/// A resolved harness configuration loaded from disk.
struct HarnessConfig: Sendable {
    let version: String
    let metadata: HarnessMetadata
    let systemPrompts: [HarnessTaskType: String]
    let toolPolicies: [HarnessTaskType: String]
}

// MARK: - Harness Registry

/// Manages versioned harness artifacts on disk.
/// Production harness is loaded at app startup; lab candidates are developer-only.
actor HarnessRegistry {
    static let shared = HarnessRegistry()

    private static let log = Logger(subsystem: "com.epistemos", category: "HarnessRegistry")
    private nonisolated static func timestampString(_ date: Date = Date()) -> String {
        date.ISO8601Format()
    }

    private let baseDir: URL
    private var cachedProductionConfig: HarnessConfig?

    init() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        self.baseDir = appSupport.appendingPathComponent("com.epistemos.app/harness")
    }

    /// For testing: custom base directory.
    init(baseDir: URL) {
        self.baseDir = baseDir
    }

    /// Nonisolated encode helper — avoids MainActor-inferred Codable conformance issue.
    nonisolated private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    /// Nonisolated decode helper.
    nonisolated private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Production Harness

    private var productionDir: URL { baseDir.appendingPathComponent("production") }
    private var currentLink: URL { productionDir.appendingPathComponent("current") }

    /// Load the current production harness config.
    /// Creates default v1.0.0 if none exists.
    func loadProductionConfig() throws -> HarnessConfig {
        if let cached = cachedProductionConfig { return cached }

        ensureDefaultHarnessExists()

        let resolvedDir: URL
        let fm = FileManager.default

        // Resolve "current" symlink or directory
        let currentPath = currentLink.path
        if let dest = try? fm.destinationOfSymbolicLink(atPath: currentPath) {
            resolvedDir = productionDir.appendingPathComponent(dest)
        } else if fm.fileExists(atPath: currentPath) {
            resolvedDir = currentLink
        } else {
            // Fallback to v1.0.0
            resolvedDir = productionDir.appendingPathComponent("v1.0.0")
        }

        let config = try loadConfig(from: resolvedDir)
        cachedProductionConfig = config
        return config
    }

    /// Get the current production harness version string.
    func productionVersion() -> String {
        (try? loadProductionConfig().version) ?? "v1.0.0"
    }

    // MARK: - Lab Candidates

    private var labDir: URL { baseDir.appendingPathComponent("lab") }
    private var candidatesDir: URL { labDir.appendingPathComponent("candidates") }
    var proposalArtifactsDir: URL { labDir.appendingPathComponent("proposals") }

    /// Create a new candidate harness directory.
    /// Returns the candidate ID and directory URL.
    func createCandidate(
        parentVersion: String,
        description: String
    ) throws -> (id: String, directory: URL) {
        let fm = FileManager.default
        try fm.createDirectory(at: candidatesDir, withIntermediateDirectories: true)

        // Find next candidate number
        let existing = (try? fm.contentsOfDirectory(atPath: candidatesDir.path)) ?? []
        let nextNum = existing.count + 1
        let candidateId = String(format: "candidate_%03d", nextNum)
        let candidateDir = candidatesDir.appendingPathComponent(candidateId)

        try fm.createDirectory(at: candidateDir.appendingPathComponent("harness/system_prompts"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: candidateDir.appendingPathComponent("harness/tool_policies"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: candidateDir.appendingPathComponent("harness/completion_checkers"),
                               withIntermediateDirectories: true)

        // Write ancestry
        let ancestry = CandidateAncestry(
            candidateId: candidateId,
            parentVersion: parentVersion,
            createdAt: Self.timestampString(),
            description: description
        )
        let ancestryData = try Self.encode(ancestry)
        try ancestryData.write(to: candidateDir.appendingPathComponent("ancestry.json"))

        Self.log.info("Created candidate harness: \(candidateId)")
        return (candidateId, candidateDir)
    }

    /// List all candidate IDs.
    func listCandidates() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: candidatesDir.path) else { return [] }
        return contents.sorted()
    }

    // MARK: - Promotion Pipeline

    /// Promote a candidate to become the new production harness.
    /// This is the human-review gate. Call only after explicit developer approval.
    func promote(
        candidateId: String,
        newVersion: String,
        promotedBy: String
    ) throws {
        let fm = FileManager.default
        let candidateDir = candidatesDir.appendingPathComponent(candidateId).appendingPathComponent("harness")
        guard fm.fileExists(atPath: candidateDir.path) else {
            throw HarnessError.candidateNotFound(candidateId)
        }

        let newVersionDir = productionDir.appendingPathComponent(newVersion)
        try fm.copyItem(at: candidateDir, to: newVersionDir)

        // Write metadata
        let metadata = HarnessMetadata(
            version: newVersion,
            createdAt: Self.timestampString(),
            promotedAt: Self.timestampString(),
            promotedBy: promotedBy,
            parentVersion: candidateId,
            description: "Promoted from \(candidateId)",
            scores: nil
        )
        let metadataData = try Self.encode(metadata)
        try metadataData.write(to: newVersionDir.appendingPathComponent("metadata.json"))

        // Update symlink
        let linkPath = currentLink.path
        try? fm.removeItem(atPath: linkPath)
        try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: newVersion)

        // Invalidate cache
        cachedProductionConfig = nil

        Self.log.notice("Promoted \(candidateId) as \(newVersion)")
    }

    // MARK: - Candidate Scores

    /// Save evaluation results for a candidate.
    /// Creates `scores_{setName}.json` in the candidate directory.
    func saveCandidateScores(
        candidateId: String,
        setName: String,
        suiteResult: EvalSuiteResult
    ) throws {
        let fm = FileManager.default
        let candidateDir = candidatesDir.appendingPathComponent(candidateId)
        guard fm.fileExists(atPath: candidateDir.path) else {
            throw HarnessError.candidateNotFound(candidateId)
        }

        // Build JSON manually to avoid Swift 6.2 MainActor Codable inference
        let resultDicts: [[String: Any]] = suiteResult.results.map { r in
            var d: [String: Any] = [
                "taskId": r.taskId,
                "harnessVersion": r.harnessVersion,
                "passed": r.passed,
                "score": r.score,
                "tokenCost": r.tokenCost,
                "turns": r.turns,
                "evidence": r.evidence,
                "timestamp": r.timestamp
            ]
            if let tp = r.tracePath { d["tracePath"] = tp.path }
            return d
        }

        let payload: [String: Any] = [
            "harnessVersion": suiteResult.harnessVersion,
            "setName": setName,
            "passRate": suiteResult.passRate,
            "averageScore": suiteResult.averageScore,
            "averageTokenCost": suiteResult.averageTokenCost,
            "evaluatedAt": Self.timestampString(),
            "results": resultDicts
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let scoresPath = candidateDir.appendingPathComponent("scores_\(setName).json")
        try data.write(to: scoresPath)
    }

    /// Load evaluation scores for a candidate.
    func loadCandidateScores(candidateId: String, setName: String) -> [String: Any]? {
        let scoresPath = candidatesDir
            .appendingPathComponent(candidateId)
            .appendingPathComponent("scores_\(setName).json")
        guard let data = try? Data(contentsOf: scoresPath),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    // MARK: - Candidate Harness Diff

    /// Generate a unified diff between the production harness and a candidate harness.
    /// Returns an array of per-file diffs.
    func diffCandidate(_ candidateId: String) throws -> [HarnessDiff] {
        let fm = FileManager.default
        let candidateHarnessDir = candidatesDir.appendingPathComponent(candidateId).appendingPathComponent("harness")
        guard fm.fileExists(atPath: candidateHarnessDir.path) else {
            throw HarnessError.candidateNotFound(candidateId)
        }

        ensureDefaultHarnessExists()
        let prodDir: URL
        let currentPath = currentLink.path
        if let dest = try? fm.destinationOfSymbolicLink(atPath: currentPath) {
            prodDir = productionDir.appendingPathComponent(dest)
        } else {
            prodDir = productionDir.appendingPathComponent("v1.0.0")
        }

        var diffs: [HarnessDiff] = []

        // Collect all files from both directories
        let prodFiles = collectFiles(in: prodDir, relativeTo: prodDir)
        let candFiles = collectFiles(in: candidateHarnessDir, relativeTo: candidateHarnessDir)
        let allPaths = Set(prodFiles.keys).union(candFiles.keys)

        for path in allPaths.sorted() {
            let prodContent = prodFiles[path]
            let candContent = candFiles[path]

            if prodContent == candContent { continue }

            let status: HarnessDiff.Status
            if prodContent == nil {
                status = .added
            } else if candContent == nil {
                status = .removed
            } else {
                status = .modified
            }

            diffs.append(HarnessDiff(
                relativePath: path,
                status: status,
                productionContent: prodContent,
                candidateContent: candContent
            ))
        }

        return diffs
    }

    private func collectFiles(in dir: URL, relativeTo base: URL) -> [String: String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return [:]
        }
        var result: [String: String] = [:]
        while let url = enumerator.nextObject() as? URL {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }
            let relative = url.path.replacingOccurrences(of: base.path + "/", with: "")
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                result[relative] = content
            }
        }
        return result
    }

    // MARK: - Internal

    private func loadConfig(from dir: URL) throws -> HarnessConfig {
        let fm = FileManager.default

        // Load metadata
        let metadataPath = dir.appendingPathComponent("metadata.json")
        let metadata: HarnessMetadata
        if let data = fm.contents(atPath: metadataPath.path) {
            metadata = try Self.decode(HarnessMetadata.self, from: data)
        } else {
            metadata = HarnessMetadata(
                version: dir.lastPathComponent, createdAt: "", promotedAt: nil,
                promotedBy: nil, parentVersion: nil, description: nil, scores: nil
            )
        }

        // Load system prompts
        var prompts: [HarnessTaskType: String] = [:]
        let promptsDir = dir.appendingPathComponent("system_prompts")
        for type in [HarnessTaskType.coding, .research, .terminal, .noteSynthesis] {
            let filename = "\(type.rawValue).md"
            let path = promptsDir.appendingPathComponent(filename)
            if let content = try? String(contentsOf: path, encoding: .utf8) {
                prompts[type] = content
            }
        }

        // Load tool policies
        var policies: [HarnessTaskType: String] = [:]
        let policiesDir = dir.appendingPathComponent("tool_policies")
        for type in [HarnessTaskType.coding, .research, .terminal, .noteSynthesis] {
            let filename = "\(type.rawValue).json"
            let path = policiesDir.appendingPathComponent(filename)
            if let content = try? String(contentsOf: path, encoding: .utf8) {
                policies[type] = content
            }
        }

        return HarnessConfig(
            version: metadata.version,
            metadata: metadata,
            systemPrompts: prompts,
            toolPolicies: policies
        )
    }

    /// Ensure a default harness directory exists for first-time setup.
    private func ensureDefaultHarnessExists() {
        let fm = FileManager.default
        let defaultDir = productionDir.appendingPathComponent("v1.0.0")
        guard !fm.fileExists(atPath: defaultDir.path) else { return }

        do {
            try fm.createDirectory(at: defaultDir.appendingPathComponent("system_prompts"),
                                   withIntermediateDirectories: true)
            try fm.createDirectory(at: defaultDir.appendingPathComponent("tool_policies"),
                                   withIntermediateDirectories: true)
            try fm.createDirectory(at: defaultDir.appendingPathComponent("completion_checkers"),
                                   withIntermediateDirectories: true)

            let metadata = HarnessMetadata(
                version: "v1.0.0",
                createdAt: Self.timestampString(),
                promotedAt: nil, promotedBy: nil, parentVersion: nil,
                description: "Default initial harness",
                scores: nil
            )
            let data = try Self.encode(metadata)
            try data.write(to: defaultDir.appendingPathComponent("metadata.json"))

            // Create symlink
            let linkPath = currentLink.path
            if !fm.fileExists(atPath: linkPath) {
                try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: "v1.0.0")
            }

            Self.log.info("Created default harness v1.0.0")
        } catch {
            Self.log.error("Failed to create default harness: \(error.localizedDescription)")
        }
    }
}

// MARK: - Support Types

struct CandidateAncestry: Sendable {
    let candidateId: String
    let parentVersion: String
    let createdAt: String
    let description: String
}

// MARK: - Nonisolated Codable Conformances
// Swift 6.2 with approachable concurrency infers MainActor isolation on
// auto-synthesized Codable conformances. We implement them explicitly
// with nonisolated to allow use inside non-MainActor actors.

extension HarnessMetadata: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        promotedAt = try c.decodeIfPresent(String.self, forKey: .promotedAt)
        promotedBy = try c.decodeIfPresent(String.self, forKey: .promotedBy)
        parentVersion = try c.decodeIfPresent(String.self, forKey: .parentVersion)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        scores = try c.decodeIfPresent(HarnessScores.self, forKey: .scores)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(promotedAt, forKey: .promotedAt)
        try c.encodeIfPresent(promotedBy, forKey: .promotedBy)
        try c.encodeIfPresent(parentVersion, forKey: .parentVersion)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(scores, forKey: .scores)
    }
    enum CodingKeys: String, CodingKey {
        case version, createdAt, promotedAt, promotedBy, parentVersion, description, scores
    }
}

extension HarnessScores: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        searchSetPassRate = try c.decodeIfPresent(Double.self, forKey: .searchSetPassRate)
        testSetPassRate = try c.decodeIfPresent(Double.self, forKey: .testSetPassRate)
        averageTokenCost = try c.decodeIfPresent(Int.self, forKey: .averageTokenCost)
        evaluatedAt = try c.decodeIfPresent(String.self, forKey: .evaluatedAt)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(searchSetPassRate, forKey: .searchSetPassRate)
        try c.encodeIfPresent(testSetPassRate, forKey: .testSetPassRate)
        try c.encodeIfPresent(averageTokenCost, forKey: .averageTokenCost)
        try c.encodeIfPresent(evaluatedAt, forKey: .evaluatedAt)
    }
    enum CodingKeys: String, CodingKey {
        case searchSetPassRate, testSetPassRate, averageTokenCost, evaluatedAt
    }
}

extension CandidateAncestry: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        candidateId = try c.decode(String.self, forKey: .candidateId)
        parentVersion = try c.decode(String.self, forKey: .parentVersion)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        description = try c.decode(String.self, forKey: .description)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(candidateId, forKey: .candidateId)
        try c.encode(parentVersion, forKey: .parentVersion)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(description, forKey: .description)
    }
    enum CodingKeys: String, CodingKey {
        case candidateId, parentVersion, createdAt, description
    }
}

/// A per-file diff between production and candidate harness.
struct HarnessDiff: Sendable {
    enum Status: String, Sendable { case added, removed, modified }

    let relativePath: String
    let status: Status
    let productionContent: String?
    let candidateContent: String?

    /// Human-readable diff summary.
    nonisolated var summary: String {
        switch status {
        case .added: return "+ \(relativePath) (new file)"
        case .removed: return "- \(relativePath) (removed)"
        case .modified: return "~ \(relativePath) (modified)"
        }
    }
}

enum HarnessError: Error, LocalizedError {
    case candidateNotFound(String)
    case promotionFailed(String)
    case invalidHarnessStructure(String)

    var errorDescription: String? {
        switch self {
        case .candidateNotFound(let id): "Candidate not found: \(id)"
        case .promotionFailed(let reason): "Promotion failed: \(reason)"
        case .invalidHarnessStructure(let reason): "Invalid harness: \(reason)"
        }
    }
}
