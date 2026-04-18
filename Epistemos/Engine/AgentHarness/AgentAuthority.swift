import Foundation
import Observation

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
}

/// Observable store that UI can bind to. Persistence is pluggable so tests
/// can drop in an in-memory backing; the production app uses a vault-relative
/// JSON file alongside approval_policy.json.
@MainActor @Observable
final class AgentAuthorityStore {
    var snapshot: AgentAuthorityPolicySnapshot = .default

    private let persistence: AgentAuthorityPersistence

    init(persistence: AgentAuthorityPersistence = InMemoryAgentAuthorityPersistence()) {
        self.persistence = persistence
        self.snapshot = persistence.load() ?? .default
    }

    func setDecision(_ decision: AuthorityDecision, for category: AgentAuthorityCategory) {
        var updated = snapshot
        updated.decisions[category] = decision
        updated.lastModified = Date()
        snapshot = updated
        persistence.save(updated)
    }

    func reset(to defaults: AgentAuthorityPolicySnapshot = .default) {
        snapshot = defaults
        persistence.save(defaults)
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
        self.snapshot = snapshot
    }
}
