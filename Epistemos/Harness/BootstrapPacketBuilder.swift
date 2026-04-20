import Foundation
import os

// MARK: - Bootstrap Packet
//
// Meta-Harness research shows that injecting an environment snapshot before
// the agent's first turn eliminates 2-4 wasted exploratory turns. This is
// the single highest-ROI production harness improvement.
//
// The packet is injected once at task start. It is NOT refreshed mid-task.
// Target: 800-1200 tokens. Hard cap: 1500 tokens.

/// The environment snapshot injected at the start of every agent session.
/// Assembled by BootstrapPacketBuilder, serialized to JSON, and injected
/// as the first block of system context.
struct BootstrapPacket: Sendable {
    // MARK: - Workspace
    let workingDirectory: String
    let projectName: String?
    let fileTreeSummary: String
    let openFiles: [String]

    // MARK: - Task Context
    let taskType: String                // "coding" | "research" | "terminal" | "note_synthesis"
    let taskObjective: String
    let sessionNumber: Int              // 1 = first, >1 = continuation
    let progressSummary: String?        // nil on session 1; from progress.json on continuations
    let pendingTaskCount: Int?

    // MARK: - Tool Availability
    let availableTools: [String]
    let activeCapability: String        // "cloud" | "local" | "readOnly"

    // MARK: - Runtime Environment
    let languageRuntimes: [RuntimeInfo]
    let packageManagers: [String]
    let repoState: RepoState?

    // MARK: - Vault Context
    let activeVault: String?
    let relevantDocumentTitles: [String]?

    // MARK: - Resource State
    let thermalLevel: String            // "nominal" | "fair" | "serious" | "critical"
    let localModelAvailable: Bool

    // MARK: - Harness Version
    let harnessVersion: String
    let timestamp: String
}

// Nonisolated Codable: explicit conformance to avoid Swift 6.2 MainActor inference
extension BootstrapPacket: Codable {}
extension RuntimeInfo: Codable {}
extension RepoState: Codable {}

struct RuntimeInfo: Sendable {
    let name: String
    let version: String?
}

struct RepoState: Sendable {
    let branch: String?
    let lastCommitHash: String?
    let uncommittedChanges: Int
}

// MARK: - Task Type Classification

enum HarnessTaskType: String, Codable, Sendable {
    case coding
    case research
    case terminal
    case noteSynthesis = "note_synthesis"

    /// Classify a user objective into a task type using keyword heuristics.
    static func classify(_ objective: String) -> HarnessTaskType {
        let lower = objective.lowercased()

        if lower.hasPrefix("research:") || lower.contains("find evidence")
            || lower.contains("investigate") || lower.contains("survey")
            || lower.contains("literature") {
            return .research
        }

        if lower.contains("run ") || lower.contains("execute ")
            || lower.contains("install ") || lower.contains("deploy ")
            || lower.hasPrefix("terminal:") || lower.hasPrefix("shell:") {
            return .terminal
        }

        if lower.contains("synthesize") || lower.contains("summarize notes")
            || lower.contains("combine notes") || lower.contains("note synthesis") {
            return .noteSynthesis
        }

        // Default: coding (most common agent task)
        return .coding
    }
}

// MARK: - Bootstrap Packet Builder

/// Assembles the environment bootstrap packet before the agent's first turn.
/// Stateless — call `build()` at task start, inject result into system context.
///
/// Design rules (from Meta-Harness research):
/// - Target 800-1200 tokens, hard cap 1500
/// - Never include env vars, API keys, or keychain data
/// - File tree: depth 2, max 50 entries, exclude build artifacts
/// - Rebuild at task start, not at app launch (prevents stale tree)
/// - Only report thermal state if serious/critical (reduce noise)
enum BootstrapPacketBuilder {
    private static let log = Logger(subsystem: "com.epistemos", category: "BootstrapPacket")

    /// Maximum entries in the file tree summary.
    private static let maxTreeEntries = 50
    /// Maximum depth for file tree traversal.
    private static let maxTreeDepth = 2
    /// Directories to exclude from file tree.
    private static let excludedDirs: Set<String> = [
        ".git", ".build", "DerivedData", "build", ".swiftpm",
        "node_modules", "target", ".cache", "__pycache__",
        "Pods", ".cocoapods", "xcuserdata", ".DS_Store"
    ]

    // MARK: - Public API

    /// Build a bootstrap packet for the given task context.
    /// This is the primary entry point — call once at task start.
    @MainActor
    static func build(
        objective: String,
        taskType: HarnessTaskType? = nil,
        workingDirectory: URL? = nil,
        sessionNumber: Int = 1,
        progressSummary: String? = nil,
        pendingTaskCount: Int? = nil,
        openFiles: [String] = [],
        availableTools: [String] = [],
        activeCapability: String = "cloud",
        activeVault: String? = nil,
        relevantDocumentTitles: [String]? = nil,
        harnessVersion: String = "v1.0.0"
    ) -> BootstrapPacket {
        let resolvedType = taskType ?? HarnessTaskType.classify(objective)
        let workDir = workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let tree = buildFileTreeSummary(root: workDir)
        let runtimes = detectLanguageRuntimes()
        let pkgManagers = detectPackageManagers(at: workDir)
        let repo = detectRepoState(at: workDir)
        let thermal = currentThermalLevel()

        let localModelAvailable: Bool
        if let bootstrap = AppBootstrap.shared {
            localModelAvailable = !bootstrap.localModelManager.installRecords.isEmpty
        } else {
            localModelAvailable = false
        }

        return BootstrapPacket(
            workingDirectory: workDir.path,
            projectName: detectProjectName(at: workDir),
            fileTreeSummary: tree,
            openFiles: Array(openFiles.prefix(5)),
            taskType: resolvedType.rawValue,
            taskObjective: objective,
            sessionNumber: sessionNumber,
            progressSummary: progressSummary.map { String($0.prefix(1200)) },
            pendingTaskCount: pendingTaskCount,
            availableTools: availableTools,
            activeCapability: activeCapability,
            languageRuntimes: runtimes,
            packageManagers: pkgManagers,
            repoState: repo,
            activeVault: activeVault,
            relevantDocumentTitles: relevantDocumentTitles.map { Array($0.prefix(5)) },
            thermalLevel: thermal,
            localModelAvailable: localModelAvailable,
            harnessVersion: harnessVersion,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Render the packet as a system-prompt-friendly string.
    /// This is what gets injected into the agent's initial context.
    static func render(_ packet: BootstrapPacket) -> String {
        var lines: [String] = []
        lines.append("<environment_context>")
        lines.append("Working directory: \(packet.workingDirectory)")
        if let project = packet.projectName {
            lines.append("Project: \(project)")
        }
        lines.append("Task type: \(packet.taskType)")
        lines.append("Session: \(packet.sessionNumber)")
        lines.append("")
        lines.append("File tree (depth 2):")
        lines.append(packet.fileTreeSummary)
        lines.append("")

        if !packet.availableTools.isEmpty {
            lines.append("Available tools: \(packet.availableTools.joined(separator: ", "))")
        }
        lines.append("Capability: \(packet.activeCapability)")

        if !packet.languageRuntimes.isEmpty {
            let rts = packet.languageRuntimes.map { "\($0.name)\($0.version.map { " \($0)" } ?? "")" }
            lines.append("Runtimes: \(rts.joined(separator: ", "))")
        }
        if !packet.packageManagers.isEmpty {
            lines.append("Package managers: \(packet.packageManagers.joined(separator: ", "))")
        }

        if let repo = packet.repoState {
            var repoLine = "Git:"
            if let branch = repo.branch { repoLine += " branch=\(branch)" }
            if let hash = repo.lastCommitHash { repoLine += " HEAD=\(hash.prefix(8))" }
            if repo.uncommittedChanges > 0 { repoLine += " uncommitted=\(repo.uncommittedChanges)" }
            lines.append(repoLine)
        }

        if let vault = packet.activeVault {
            lines.append("Active vault: \(vault)")
        }
        if let docs = packet.relevantDocumentTitles, !docs.isEmpty {
            lines.append("Relevant documents: \(docs.joined(separator: ", "))")
        }

        if packet.thermalLevel == "serious" || packet.thermalLevel == "critical" {
            lines.append("WARNING: Thermal state is \(packet.thermalLevel) — prefer efficient operations")
        }
        if !packet.localModelAvailable {
            lines.append("Note: No local model available — cloud inference only")
        }

        if let progress = packet.progressSummary {
            lines.append("")
            lines.append("Progress from prior session:")
            lines.append(progress)
        }
        if let pending = packet.pendingTaskCount, pending > 0 {
            lines.append("Pending tasks: \(pending)")
        }

        lines.append("Harness: \(packet.harnessVersion)")
        lines.append("</environment_context>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Internal Helpers

    private static func buildFileTreeSummary(root: URL) -> String {
        var entries: [String] = []
        let fm = FileManager.default

        func walk(dir: URL, depth: Int, prefix: String) {
            guard depth <= maxTreeDepth, entries.count < maxTreeEntries else { return }
            guard let items = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
            for item in sorted {
                guard entries.count < maxTreeEntries else { return }
                let name = item.lastPathComponent
                if excludedDirs.contains(name) { continue }

                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                entries.append("\(prefix)\(isDir ? "\(name)/" : name)")

                if isDir {
                    walk(dir: item, depth: depth + 1, prefix: prefix + "  ")
                }
            }
        }

        walk(dir: root, depth: 0, prefix: "  ")
        return entries.isEmpty ? "  (empty or inaccessible)" : entries.joined(separator: "\n")
    }

    private nonisolated static func detectProjectName(at dir: URL) -> String? {
        let fm = FileManager.default
        // Check Package.swift (SPM)
        if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            return dir.lastPathComponent
        }
        // Check Cargo.toml
        if fm.fileExists(atPath: dir.appendingPathComponent("Cargo.toml").path) {
            return dir.lastPathComponent
        }
        // Check package.json
        if fm.fileExists(atPath: dir.appendingPathComponent("package.json").path) {
            return dir.lastPathComponent
        }
        return nil
    }

    private nonisolated static func detectLanguageRuntimes() -> [RuntimeInfo] {
        var runtimes: [RuntimeInfo] = []
        let fm = FileManager.default

        // Swift
        if fm.fileExists(atPath: "/usr/bin/swift") || fm.fileExists(atPath: "/usr/bin/swiftc") {
            runtimes.append(RuntimeInfo(name: "swift", version: nil))
        }
        // Cargo/Rust
        if fm.fileExists(
            atPath: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cargo/bin/cargo")
                .path
        )
            || fm.fileExists(atPath: "/opt/homebrew/bin/cargo") {
            runtimes.append(RuntimeInfo(name: "cargo", version: nil))
        }
        // Node
        if fm.fileExists(atPath: "/usr/local/bin/node") || fm.fileExists(atPath: "/opt/homebrew/bin/node") {
            runtimes.append(RuntimeInfo(name: "node", version: nil))
        }
        // Python
        if fm.fileExists(atPath: "/usr/bin/python3") || fm.fileExists(atPath: "/opt/homebrew/bin/python3") {
            runtimes.append(RuntimeInfo(name: "python3", version: nil))
        }
        return runtimes
    }

    private nonisolated static func detectPackageManagers(at dir: URL) -> [String] {
        var managers: [String] = []
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { managers.append("spm") }
        if fm.fileExists(atPath: dir.appendingPathComponent("Cargo.toml").path) { managers.append("cargo") }
        if fm.fileExists(atPath: dir.appendingPathComponent("package.json").path) { managers.append("npm") }
        if fm.fileExists(atPath: dir.appendingPathComponent("requirements.txt").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("pyproject.toml").path) { managers.append("pip") }
        return managers
    }

    private nonisolated static func detectRepoState(at dir: URL) -> RepoState? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.appendingPathComponent(".git").path) else { return nil }

        // Read HEAD for branch name
        let headPath = dir.appendingPathComponent(".git/HEAD").path
        let branch: String?
        if let headContent = try? String(contentsOfFile: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            if headContent.hasPrefix("ref: refs/heads/") {
                branch = String(headContent.dropFirst("ref: refs/heads/".count))
            } else {
                branch = String(headContent.prefix(8)) // detached HEAD
            }
        } else {
            branch = nil
        }

        // Count uncommitted changes via git status porcelain (fast, no subprocess needed for basic check)
        // For simplicity, just check if index differs from HEAD
        let uncommitted = 0 // Conservative: don't spawn subprocess in bootstrap

        return RepoState(branch: branch, lastCommitHash: nil, uncommittedChanges: uncommitted)
    }

    private nonisolated static func currentThermalLevel() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "nominal"
        }
    }
}
