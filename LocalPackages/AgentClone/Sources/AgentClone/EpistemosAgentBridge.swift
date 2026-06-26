import Foundation

public struct AgentCloneHostContext: Equatable, Sendable {
    public var appName: String
    public var workspaceRootPath: String?
    public var vaultRootPath: String?
    public var appSupportRootPath: String?
    public var mode: String?
    public var presentation: String?

    public init(
        appName: String,
        workspaceRootPath: String? = nil,
        vaultRootPath: String? = nil,
        appSupportRootPath: String? = nil,
        mode: String? = nil,
        presentation: String? = nil
    ) {
        self.appName = appName
        self.workspaceRootPath = Self.normalized(workspaceRootPath)
        self.vaultRootPath = Self.normalized(vaultRootPath)
        self.appSupportRootPath = Self.normalized(appSupportRootPath)
        self.mode = Self.normalized(mode)
        self.presentation = Self.normalized(presentation)
    }

    public var preferredProjectFolder: String? {
        vaultRootPath ?? workspaceRootPath
    }

    public var summary: String {
        var parts = [appName]
        if let mode {
            parts.append(mode)
        }
        if let presentation {
            parts.append("surface: \(presentation)")
        }
        if let vaultRootPath {
            parts.append("vault: \(vaultRootPath)")
        }
        if let workspaceRootPath {
            parts.append("workspace: \(workspaceRootPath)")
        }
        return parts.joined(separator: " | ")
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct AgentClonePendingPrompt: Equatable, Sendable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

private final class AgentClonePendingPromptStore: @unchecked Sendable {
    private let lock = NSLock()
    private var prompts: [AgentClonePendingPrompt] = []

    func append(_ prompt: AgentClonePendingPrompt) {
        lock.lock()
        defer { lock.unlock() }
        prompts.append(prompt)
    }

    func remove(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        prompts.removeAll { $0.id == id }
    }

    func drain() -> [AgentClonePendingPrompt] {
        lock.lock()
        defer { lock.unlock() }
        let drained = prompts
        prompts.removeAll()
        return drained
    }
}

public enum AgentCloneBridge {
    public static let submitPromptNotification = Notification.Name("epistemos.agentclone.submitPrompt")
    public static let hostContextNotification = Notification.Name("epistemos.agentclone.hostContext")
    public static let promptUserInfoKey = "prompt"
    public static let promptIDUserInfoKey = "promptID"
    public static let hostContextUserInfoKey = "hostContext"
    private static let pendingPromptStore = AgentClonePendingPromptStore()

    @MainActor public private(set) static var currentHostContext: AgentCloneHostContext?

    @discardableResult
    public static func submitPrompt(_ prompt: String) -> UUID {
        let pendingPrompt = AgentClonePendingPrompt(text: prompt)
        pendingPromptStore.append(pendingPrompt)
        NotificationCenter.default.post(
            name: submitPromptNotification,
            object: nil,
            userInfo: [
                promptUserInfoKey: prompt,
                promptIDUserInfoKey: pendingPrompt.id
            ]
        )
        return pendingPrompt.id
    }

    public static func markPromptConsumed(id: UUID) {
        pendingPromptStore.remove(id: id)
    }

    public static func drainPendingPrompts() -> [AgentClonePendingPrompt] {
        pendingPromptStore.drain()
    }

    @MainActor
    public static func updateHostContext(_ context: AgentCloneHostContext) {
        currentHostContext = context
        NotificationCenter.default.post(
            name: hostContextNotification,
            object: nil,
            userInfo: [hostContextUserInfoKey: context]
        )
    }
}
