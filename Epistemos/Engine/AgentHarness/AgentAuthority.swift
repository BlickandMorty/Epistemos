import Foundation
import Observation
import os

/// User-facing category that groups agent tool calls by blast radius.
/// The Authority & Installs settings panel shows one decision per category
/// instead of one decision per tool call, so the user can set "Network
/// fetch: auto-allow" once and stop being prompted for every web read.
///
/// Independent of the tool's RiskLevel (ReadOnly / Modification / Destructive)
/// which lives Rust-side. RiskLevel is about whether the action changes state
/// on disk; AuthorityCategory is about where the action reaches.
nonisolated enum AgentAuthorityCategory: String, Codable, Hashable, Sendable, CaseIterable {
    /// Read inside the vault / chosen workspaces.
    case vaultRead = "vault_read"
    /// Write inside the vault / chosen workspaces.
    case vaultWrite = "vault_write"
    /// Read / write outside approved folders (e.g., `/Users/.../Documents`).
    case outOfVaultFileAccess = "out_of_vault_file"
    /// Network fetch (HTTP / DNS / web search / GitHub API).
    case networkFetch = "network_fetch"
    /// Download model weights, plugins, or other assets into app support.
    case downloadArtifact = "download_artifact"
    /// `git clone` / `git pull` / `git push` against user-scope repos.
    case gitOperation = "git_operation"
    /// Package-manager installs: `brew`, `pip`, `cargo`, `npm`, etc.
    case packageInstall = "package_install"
    /// Run an arbitrary downloaded shell script the agent produced.
    case runDownloadedScript = "run_downloaded_script"
    /// App automation outside Epistemos (Apple Events, AppleScript, UI taps).
    case externalAppAutomation = "external_app_automation"
    /// Destructive file operations (`rm`, overwrite without read).
    case destructiveFileOp = "destructive_file_op"
    /// Anything that touches /System, /Library, firmware, keychain dumps, sudo.
    case systemProtected = "system_protected"
}

extension AgentAuthorityCategory {
    var displayName: String {
        switch self {
        case .vaultRead: "Vault read"
        case .vaultWrite: "Vault write"
        case .outOfVaultFileAccess: "File access outside vault"
        case .networkFetch: "Network fetch"
        case .downloadArtifact: "Download models & assets"
        case .gitOperation: "Git repo operations"
        case .packageInstall: "Package installs (brew / pip / cargo / npm)"
        case .runDownloadedScript: "Run downloaded scripts"
        case .externalAppAutomation: "Control other apps"
        case .destructiveFileOp: "Destructive file operations"
        case .systemProtected: "System / protected paths"
        }
    }

    var shortExplanation: String {
        switch self {
        case .vaultRead: "Read notes, folders, and metadata inside your vault."
        case .vaultWrite: "Create, edit, and move notes inside your vault."
        case .outOfVaultFileAccess: "Read or write files outside the vault."
        case .networkFetch: "Fetch web pages, GitHub repos, and remote docs."
        case .downloadArtifact: "Download model weights or plugin bundles into app support."
        case .gitOperation: "Clone, pull, or push against a git repo in a workspace."
        case .packageInstall: "Install user-scope developer packages via brew / pip / cargo / npm."
        case .runDownloadedScript: "Execute a shell script the agent produced or fetched."
        case .externalAppAutomation: "Automate other macOS apps via Apple Events / Accessibility."
        case .destructiveFileOp: "Delete, move-to-trash, or overwrite files without reading them first."
        case .systemProtected: "Touch /System, /Library, firmware, keychain dumps, or anything sudo-level."
        }
    }
}

/// Per-category decision. Persisted per-workspace so approvals get smoother
/// over time — allowing an install in one workspace doesn't implicitly allow
/// it elsewhere.
nonisolated enum AuthorityDecision: String, Codable, Hashable, Sendable, CaseIterable {
    /// Always allow without prompting.
    case autoAllow = "auto_allow"
    /// Prompt the user before executing.
    case askFirst = "ask_first"
    /// Refuse without prompting — Destructive paths where the user never wants auto.
    case neverAllow = "never_allow"
}

extension AuthorityDecision {
    var displayName: String {
        switch self {
        case .autoAllow: "Auto-allow"
        case .askFirst: "Ask first"
        case .neverAllow: "Never"
        }
    }
}

/// Default policy per category. Matches the user's stated defaults:
/// Auto-allow vault ops + web fetch + github + model downloads; ask first
/// for installs / downloaded scripts / external app automation / destructive
/// file ops / writing outside vault; never auto-allow anything system-level.
nonisolated enum AgentAuthorityDefaults {
    static func decision(for category: AgentAuthorityCategory) -> AuthorityDecision {
        switch category {
        case .vaultRead,
             .vaultWrite,
             .networkFetch,
             .downloadArtifact,
             .gitOperation:
            return .autoAllow
        case .packageInstall,
             .runDownloadedScript,
             .externalAppAutomation,
             .destructiveFileOp,
             .outOfVaultFileAccess:
            return .askFirst
        case .systemProtected:
            return .neverAllow
        }
    }

    static func defaultPolicy() -> [AgentAuthorityCategory: AuthorityDecision] {
        var policy: [AgentAuthorityCategory: AuthorityDecision] = [:]
        for category in AgentAuthorityCategory.allCases {
            policy[category] = decision(for: category)
        }
        return policy
    }
}

nonisolated enum AgentAuthorityQuickSetupPreset: String, CaseIterable, Identifiable, Sendable {
    case recommended = "Recommended"
    case lessInterruptions = "Less Interruptions"
    case cautious = "Review More"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .recommended:
            "Use the default trust boundaries Epistemos ships with."
        case .lessInterruptions:
            "Auto-allow normal vault, workspace, network, and git work, while still asking before installs, app control, or destructive actions."
        case .cautious:
            "Keep normal reads flowing, but ask before most writes or external actions."
        }
    }

    var decisions: [AgentAuthorityCategory: AuthorityDecision] {
        switch self {
        case .recommended:
            return AgentAuthorityDefaults.defaultPolicy()
        case .lessInterruptions:
            return [
                .vaultRead: .autoAllow,
                .vaultWrite: .autoAllow,
                .outOfVaultFileAccess: .autoAllow,
                .networkFetch: .autoAllow,
                .downloadArtifact: .autoAllow,
                .gitOperation: .autoAllow,
                .packageInstall: .askFirst,
                .runDownloadedScript: .askFirst,
                .externalAppAutomation: .askFirst,
                .destructiveFileOp: .askFirst,
                .systemProtected: .neverAllow,
            ]
        case .cautious:
            return [
                .vaultRead: .autoAllow,
                .vaultWrite: .askFirst,
                .outOfVaultFileAccess: .askFirst,
                .networkFetch: .autoAllow,
                .downloadArtifact: .askFirst,
                .gitOperation: .askFirst,
                .packageInstall: .askFirst,
                .runDownloadedScript: .askFirst,
                .externalAppAutomation: .askFirst,
                .destructiveFileOp: .askFirst,
                .systemProtected: .neverAllow,
            ]
        }
    }
}

/// Workspace-scoped snapshot of the authority policy. Codable so we can
/// round-trip it through vault JSON, the same way the existing
/// AgentApprovalPolicyStore persists allow/block pattern lists.
nonisolated struct AgentAuthorityPolicySnapshot: Codable, Equatable, Sendable {
    var decisions: [AgentAuthorityCategory: AuthorityDecision]
    var lastModified: Date?

    static let `default` = AgentAuthorityPolicySnapshot(
        decisions: AgentAuthorityDefaults.defaultPolicy(),
        lastModified: nil
    )

    func decision(for category: AgentAuthorityCategory) -> AuthorityDecision {
        decisions[category] ?? AgentAuthorityDefaults.decision(for: category)
    }

    func normalized() -> AgentAuthorityPolicySnapshot {
        var normalizedDecisions = AgentAuthorityDefaults.defaultPolicy()
        for category in AgentAuthorityCategory.allCases {
            let proposed = decisions[category] ?? normalizedDecisions[category] ?? .askFirst
            normalizedDecisions[category] = Self.normalizedDecision(proposed, for: category)
        }
        return AgentAuthorityPolicySnapshot(
            decisions: normalizedDecisions,
            lastModified: lastModified
        )
    }

    fileprivate static func normalizedDecision(
        _ decision: AuthorityDecision,
        for category: AgentAuthorityCategory
    ) -> AuthorityDecision {
        if category == .systemProtected, decision == .autoAllow {
            return .neverAllow
        }
        return decision
    }
}

/// Observable store that UI can bind to. Persistence is pluggable so tests
/// can drop in an in-memory backing; the production app uses a vault-relative
/// JSON file alongside approval_policy.json.
@MainActor @Observable
final class AgentAuthorityStore {
    var snapshot: AgentAuthorityPolicySnapshot = .default

    private let persistence: AgentAuthorityPersistence

    /// Per RCA13 P1-025: default to file-backed persistence so that any
    /// site that forgets to specify the persistence flavor still gets
    /// durable decisions instead of silently dropping them on quit.
    /// Tests + previews explicitly opt into
    /// `InMemoryAgentAuthorityPersistence()` when they want ephemeral
    /// behavior.
    init(persistence: AgentAuthorityPersistence = FileBackedAgentAuthorityPersistence()) {
        self.persistence = persistence
        self.snapshot = persistence.load()?.normalized() ?? .default
    }

    func setDecision(_ decision: AuthorityDecision, for category: AgentAuthorityCategory) {
        var updated = snapshot
        updated.decisions[category] = AgentAuthorityPolicySnapshot.normalizedDecision(
            decision,
            for: category
        )
        updated.lastModified = Date()
        snapshot = updated.normalized()
        persistence.save(snapshot)
    }

    func applyPreset(_ decisions: [AgentAuthorityCategory: AuthorityDecision]) {
        var updated = snapshot
        for (category, decision) in decisions {
            updated.decisions[category] = decision
        }
        updated.lastModified = Date()
        snapshot = updated.normalized()
        persistence.save(snapshot)
    }

    func reset(to defaults: AgentAuthorityPolicySnapshot = .default) {
        snapshot = defaults.normalized()
        persistence.save(snapshot)
    }
}

nonisolated protocol AgentAuthorityPersistence: Sendable {
    func load() -> AgentAuthorityPolicySnapshot?
    func save(_ snapshot: AgentAuthorityPolicySnapshot)
}

/// Non-persistent backing used in tests and by the initial boot path before
/// a vault has been resolved. Safe to keep as the default because it never
/// reads or writes the filesystem — any state lives only for the lifetime of
/// the store.
final class InMemoryAgentAuthorityPersistence: AgentAuthorityPersistence, @unchecked Sendable {
    private var snapshot: AgentAuthorityPolicySnapshot?

    init(initial: AgentAuthorityPolicySnapshot? = nil) {
        self.snapshot = initial
    }

    func load() -> AgentAuthorityPolicySnapshot? { snapshot }

    func save(_ snapshot: AgentAuthorityPolicySnapshot) {
        self.snapshot = snapshot.normalized()
    }
}

/// JSON file backed at ApplicationSupport/Epistemos/agent_authority.json so
/// the user's allow / ask / deny decisions survive app restarts. The store's
/// default was `InMemoryAgentAuthorityPersistence` which silently dropped
/// those decisions on quit — research 3 called it out as a live bug.
/// Failures to decode or write fall back to the defaults so a corrupt file
/// never breaks the permission flow; the file is just overwritten next save.
final class FileBackedAgentAuthorityPersistence: AgentAuthorityPersistence, @unchecked Sendable {
    private let storageURL: URL
    private let log = os.Logger(subsystem: "com.epistemos", category: "AgentAuthority")

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
            return
        }
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
        self.storageURL = appSupport.appendingPathComponent("agent_authority.json")
    }

    func load() -> AgentAuthorityPolicySnapshot? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AgentAuthorityPolicySnapshot.self, from: data).normalized()
        } catch {
            log.error(
                "Failed to decode agent_authority.json; falling back to defaults: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    func save(_ snapshot: AgentAuthorityPolicySnapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot.normalized())
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            log.error(
                "Failed to write agent_authority.json: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

extension AgentPermissionRequest {
    nonisolated private static let networkFetchTools: Set<String> = [
        "browser",
        "browser_open",
        "browser_snapshot",
        "fetch_url",
        "github_search",
        "http_fetch",
        "search_web",
        "tavily_search",
        "web_fetch",
        "web_search",
    ]

    nonisolated private static let gitOperationTools: Set<String> = [
        "git",
        "git_clone",
        "git_pull",
        "git_push",
    ]

    nonisolated private static let downloadArtifactTools: Set<String> = [
        "download",
        "download_artifact",
        "download_file",
        "install_model",
        "model_download",
        "plugin_install",
    ]

    nonisolated private static let externalAutomationTools: Set<String> = [
        "apple_script",
        "applescript",
        "computer",
        "computer_use",
        "ui_automation",
    ]

    nonisolated func authorityCategory(vaultPath: String?) -> AgentAuthorityCategory {
        if riskLevel == .destructive {
            return .destructiveFileOp
        }

        let normalizedToolName = Self.trimmed(toolName).lowercased()
        if Self.networkFetchTools.contains(normalizedToolName) {
            return .networkFetch
        }
        if Self.gitOperationTools.contains(normalizedToolName) {
            return .gitOperation
        }
        if Self.downloadArtifactTools.contains(normalizedToolName) {
            return .downloadArtifact
        }
        if Self.externalAutomationTools.contains(normalizedToolName) {
            return .externalAppAutomation
        }

        if let command = normalizedCommand {
            if Self.isPackageInstallCommand(command) {
                return .packageInstall
            }
            if Self.isDownloadedScriptCommand(command) {
                return .runDownloadedScript
            }
        }

        switch permissionCategory {
        case .localDataRead:
            return targetsOutOfVaultPath(vaultPath: vaultPath) ? .outOfVaultFileAccess : .vaultRead
        case .localDataWrite:
            return targetsOutOfVaultPath(vaultPath: vaultPath) ? .outOfVaultFileAccess : .vaultWrite
        case .genericRead:
            return .networkFetch
        case .modification:
            return .externalAppAutomation
        case .destructive:
            return .destructiveFileOp
        }
    }

    nonisolated private var normalizedCommand: String? {
        guard let command = authorityJSONObject?["command"] as? String else {
            return nil
        }
        let trimmed = Self.trimmed(command).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private func targetsOutOfVaultPath(vaultPath: String?) -> Bool {
        let normalizedToolName = Self.trimmed(toolName).lowercased()
        if normalizedToolName.hasPrefix("vault_") {
            return false
        }

        guard let rawPath = (authorityJSONObject?["path"] as? String).map(Self.trimmed),
              !rawPath.isEmpty else {
            return false
        }

        // Relative note titles and workspace-relative paths should stay in the
        // vault/workspace approval bucket so remembered approvals apply to the
        // common note-read/write flows.
        guard rawPath.hasPrefix("/") else {
            return false
        }

        guard let vaultPath,
              !Self.trimmed(vaultPath).isEmpty else {
            return true
        }

        let standardizedPath = URL(fileURLWithPath: rawPath).standardizedFileURL.path
        let standardizedVaultPath = URL(fileURLWithPath: vaultPath).standardizedFileURL.path
        if standardizedPath == standardizedVaultPath {
            return false
        }
        return !standardizedPath.hasPrefix(standardizedVaultPath + "/")
    }

    nonisolated private static func isPackageInstallCommand(_ command: String) -> Bool {
        [
            "brew ",
            "pip ",
            "pip3 ",
            "python -m pip ",
            "uv pip ",
            "cargo install ",
            "npm install ",
            "pnpm add ",
            "yarn add ",
        ].contains { command.hasPrefix($0) }
    }

    nonisolated private static func isDownloadedScriptCommand(_ command: String) -> Bool {
        command.hasPrefix("bash ") || command.hasPrefix("sh ") || command.hasPrefix("zsh ")
    }

    nonisolated private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private var authorityJSONObject: [String: Any]? {
        guard let data = inputJson.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return value
    }
}
