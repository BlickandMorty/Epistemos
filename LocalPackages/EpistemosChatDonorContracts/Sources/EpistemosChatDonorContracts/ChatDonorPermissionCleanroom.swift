import Foundation

public struct ChatDonorToolInvocation: Codable, Hashable, Sendable {
    public var toolName: String
    public var arguments: [String: String]
    public var metadata: [String: String]
    public var sessionID: String?
    public var toolUseID: String?

    public init(
        toolName: String,
        arguments: [String: String] = [:],
        metadata: [String: String] = [:],
        sessionID: String? = nil,
        toolUseID: String? = nil
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.metadata = metadata
        self.sessionID = sessionID
        self.toolUseID = toolUseID
    }

    public var command: String? {
        arguments["command"]
    }

    public var filePath: String? {
        arguments["file_path"] ?? arguments["path"]
    }

    public var operationDescription: String {
        switch toolName {
        case "Bash", "ExecuteCommand":
            return command.map { "Execute: \($0)" } ?? "Execute shell command"
        case "Write":
            return filePath.map { "Write to: \($0)" } ?? "Write file"
        case "Edit", "MultiEdit":
            return filePath.map { "Edit: \($0)" } ?? "Edit file"
        case "Read":
            return filePath.map { "Read: \($0)" } ?? "Read file"
        default:
            return "Execute \(toolName)"
        }
    }

    public var riskLevel: ChatDonorPermissionRisk {
        switch toolName {
        case "Read", "Glob", "Grep":
            .low
        case "Write", "Edit", "MultiEdit":
            .medium
        case "Bash", "ExecuteCommand":
            Self.shellRisk(command ?? "")
        default:
            .medium
        }
    }

    public var sessionMemoryKey: String {
        switch toolName {
        case "Bash", "ExecuteCommand":
            let firstWord = command?.split(separator: " ").first.map(String.init) ?? command ?? ""
            return firstWord.isEmpty ? toolName : "\(toolName):\(firstWord)"
        case "Read", "Write", "Edit", "MultiEdit", "Glob", "Grep":
            guard let filePath else { return toolName }
            let directory = (filePath as NSString).deletingLastPathComponent
            return "\(toolName):\(directory)"
        default:
            return toolName
        }
    }

    private static func shellRisk(_ command: String) -> ChatDonorPermissionRisk {
        if command.contains("rm ") || command.contains("sudo") || command.contains("chmod") {
            return .critical
        }
        if command.contains("git push") || command.contains("npm publish") {
            return .high
        }
        return .high
    }
}

public enum ChatDonorPermissionRisk: String, Codable, Hashable, Sendable {
    case low
    case medium
    case high
    case critical
}

public struct ChatDonorPermissionRule: Codable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public var pattern: String

    public init(_ pattern: String) {
        self.pattern = pattern
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String { pattern }

    public var toolName: String {
        guard let open = pattern.firstIndex(of: "(") else { return pattern }
        return String(pattern[..<open])
    }

    public var argumentPattern: String? {
        guard let open = pattern.firstIndex(of: "("),
              let close = pattern.lastIndex(of: ")"),
              open < close else {
            return nil
        }
        return String(pattern[pattern.index(after: open)..<close])
    }

    public func matches(_ invocation: ChatDonorToolInvocation) -> Bool {
        guard Self.matchesPattern(toolName, value: invocation.toolName) else {
            return false
        }
        guard let argumentPattern else {
            return true
        }

        let candidates = argumentCandidates(for: invocation)
        return candidates.contains { Self.matchesArgumentPattern(argumentPattern, value: $0) }
    }

    public static func tool(_ name: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule(name)
    }

    public static func bash(_ commandPattern: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule("Bash(\(commandPattern))")
    }

    public static func write(_ pathPattern: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule("Write(\(pathPattern))")
    }

    public static func edit(_ pathPattern: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule("Edit(\(pathPattern))")
    }

    public static func read(_ pathPattern: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule("Read(\(pathPattern))")
    }

    public static func mcp(_ serverName: String) -> ChatDonorPermissionRule {
        ChatDonorPermissionRule("mcp:\(serverName):*")
    }

    public static func parse(_ value: String) -> [ChatDonorPermissionRule] {
        var rules: [ChatDonorPermissionRule] = []
        var buffer = ""
        var depth = 0

        for character in value {
            if character == "(" {
                depth += 1
                buffer.append(character)
            } else if character == ")" {
                depth = max(0, depth - 1)
                buffer.append(character)
            } else if character.isWhitespace && depth == 0 {
                if !buffer.isEmpty {
                    rules.append(ChatDonorPermissionRule(buffer))
                    buffer.removeAll(keepingCapacity: true)
                }
            } else {
                buffer.append(character)
            }
        }

        if !buffer.isEmpty {
            rules.append(ChatDonorPermissionRule(buffer))
        }
        return rules
    }

    private func argumentCandidates(for invocation: ChatDonorToolInvocation) -> [String] {
        switch invocation.toolName {
        case "Bash", "ExecuteCommand":
            return invocation.command.map { [$0] } ?? []
        case "Read", "Write", "Edit", "MultiEdit", "Glob", "Grep":
            if let filePath = invocation.filePath {
                return [Self.normalizedPath(filePath)]
            }
            return []
        default:
            return Array(invocation.arguments.values)
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardized.path
    }

    private static let prefixSeparators: Set<Character> = [" ", "-", "\t", ";", "|", "&", "\n", "/"]

    private static func matchesArgumentPattern(_ pattern: String, value: String) -> Bool {
        if pattern.hasSuffix(":*") {
            let prefix = String(pattern.dropLast(2))
            guard !prefix.isEmpty else { return true }
            if value == prefix { return true }
            guard value.hasPrefix(prefix), value.count > prefix.count else { return false }
            let nextIndex = value.index(value.startIndex, offsetBy: prefix.count)
            return prefixSeparators.contains(value[nextIndex])
        }
        return matchesPattern(pattern, value: value)
    }

    private static func matchesPattern(_ pattern: String, value: String) -> Bool {
        if pattern == "*" { return true }
        guard pattern.contains("*") else { return pattern == value }

        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        var searchStart = value.startIndex

        if let first = parts.first, !first.isEmpty {
            guard value.hasPrefix(first) else { return false }
            searchStart = value.index(value.startIndex, offsetBy: first.count)
        }

        for part in parts.dropFirst().dropLast() where !part.isEmpty {
            guard let range = value.range(of: part, range: searchStart..<value.endIndex) else {
                return false
            }
            searchStart = range.upperBound
        }

        if let last = parts.last, !last.isEmpty {
            if parts.count == 1 { return value == last }
            guard let range = value.range(of: last, range: searchStart..<value.endIndex) else {
                return false
            }
            return range.upperBound == value.endIndex
        }

        return true
    }
}

public enum ChatDonorPermissionDefaultDecision: String, Codable, Hashable, Sendable {
    case allow
    case deny
    case ask
}

public enum ChatDonorPermissionMode: String, Codable, Hashable, Sendable, Comparable, CaseIterable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"
    case prompt
    case allow

    private var rank: Int {
        switch self {
        case .readOnly: 0
        case .workspaceWrite: 1
        case .dangerFullAccess: 2
        case .prompt: 3
        case .allow: 4
        }
    }

    public static func < (lhs: ChatDonorPermissionMode, rhs: ChatDonorPermissionMode) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum ChatDonorPluginToolPermission: String, Codable, Hashable, Sendable, CaseIterable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"

    public var requiredMode: ChatDonorPermissionMode {
        switch self {
        case .readOnly: .readOnly
        case .workspaceWrite: .workspaceWrite
        case .dangerFullAccess: .dangerFullAccess
        }
    }
}

public struct ChatDonorPermissionPolicy: Codable, Hashable, Sendable {
    public var allow: [ChatDonorPermissionRule]
    public var deny: [ChatDonorPermissionRule]
    public var finalDeny: [ChatDonorPermissionRule]
    public var overrides: [ChatDonorPermissionRule]
    public var dynamicAllow: [ChatDonorPermissionRule]
    public var defaultDecision: ChatDonorPermissionDefaultDecision
    public var enableSessionMemory: Bool
    public var mode: ChatDonorPermissionMode?

    public init(
        allow: [ChatDonorPermissionRule] = [],
        deny: [ChatDonorPermissionRule] = [],
        finalDeny: [ChatDonorPermissionRule] = [],
        overrides: [ChatDonorPermissionRule] = [],
        dynamicAllow: [ChatDonorPermissionRule] = [],
        defaultDecision: ChatDonorPermissionDefaultDecision = .ask,
        enableSessionMemory: Bool = true,
        mode: ChatDonorPermissionMode? = nil
    ) {
        self.allow = allow
        self.deny = deny
        self.finalDeny = finalDeny
        self.overrides = overrides
        self.dynamicAllow = dynamicAllow
        self.defaultDecision = defaultDecision
        self.enableSessionMemory = enableSessionMemory
        self.mode = mode
    }

    public static let readOnly = ChatDonorPermissionPolicy(
        allow: [.tool("Read"), .tool("Glob"), .tool("Grep")],
        deny: [.tool("Write"), .tool("Edit"), .tool("MultiEdit"), .tool("Bash"), .tool("Git")],
        defaultDecision: .deny,
        enableSessionMemory: false,
        mode: .readOnly
    )

    public static let standard = ChatDonorPermissionPolicy(
        allow: [
            .tool("Read"), .tool("Glob"), .tool("Grep"),
            .bash("git status"), .bash("git log:*"), .bash("git diff:*"),
            .bash("git branch:*"), .bash("git show:*"),
            .bash("ls:*"), .bash("cat:*"), .bash("head:*"), .bash("tail:*"),
            .bash("wc:*"), .bash("pwd")
        ],
        deny: [
            .bash("rm -rf:*"), .bash("rm -fr:*"), .bash("sudo:*"),
            .bash("chmod 777:*"), .bash("dd:*")
        ],
        defaultDecision: .ask,
        enableSessionMemory: true,
        mode: .workspaceWrite
    )

    public func merged(with other: ChatDonorPermissionPolicy) -> ChatDonorPermissionPolicy {
        ChatDonorPermissionPolicy(
            allow: Self.deduplicated(allow + other.allow),
            deny: Self.deduplicated(deny + other.deny),
            finalDeny: Self.deduplicated(finalDeny + other.finalDeny),
            overrides: Self.deduplicated(overrides + other.overrides),
            dynamicAllow: Self.deduplicated(dynamicAllow + other.dynamicAllow),
            defaultDecision: other.defaultDecision,
            enableSessionMemory: other.enableSessionMemory,
            mode: other.mode ?? mode
        )
    }

    public func evaluate(
        _ invocation: ChatDonorToolInvocation,
        sessionMemory: ChatDonorPermissionSessionMemory = .none,
        approvalID: String = UUID().uuidString
    ) -> ChatDonorPermissionEvaluation {
        if let rule = finalDeny.first(where: { $0.matches(invocation) }) {
            return .denied(reason: .finalDeny, matchedRule: rule)
        }

        switch sessionMemory {
        case .alwaysAllowed:
            return .allowed(reason: .sessionMemory, matchedRule: nil)
        case .blocked:
            return .denied(reason: .sessionMemory, matchedRule: nil)
        case .none:
            break
        }

        let isOverridden = overrides.contains { $0.matches(invocation) }
        if !isOverridden, let rule = deny.first(where: { $0.matches(invocation) }) {
            return .denied(reason: .denyRule, matchedRule: rule)
        }

        for rule in dynamicAllow + allow where rule.matches(invocation) {
            return .allowed(reason: dynamicAllow.contains(rule) ? .dynamicAllowRule : .allowRule, matchedRule: rule)
        }

        if let requiredMode = invocation.requiredPermissionMode,
           let mode {
            if mode == .allow || mode >= requiredMode {
                return .allowed(reason: .permissionMode, matchedRule: nil)
            }
            if mode == .prompt || (mode == .workspaceWrite && requiredMode == .dangerFullAccess) {
                let request = ChatDonorApprovalRequest(
                    approvalID: approvalID,
                    invocation: invocation,
                    reason: "Requires \(requiredMode.rawValue) permission from \(mode.rawValue) mode."
                )
                return .requiresApproval(request)
            }
            return .denied(reason: .permissionMode, matchedRule: nil)
        }

        switch defaultDecision {
        case .allow:
            return .allowed(reason: .defaultAllow, matchedRule: nil)
        case .deny:
            return .denied(reason: .defaultDeny, matchedRule: nil)
        case .ask:
            return .requiresApproval(ChatDonorApprovalRequest(
                approvalID: approvalID,
                invocation: invocation,
                reason: "No permission rule matched."
            ))
        }
    }

    private static func deduplicated(_ rules: [ChatDonorPermissionRule]) -> [ChatDonorPermissionRule] {
        var seen = Set<ChatDonorPermissionRule>()
        return rules.filter { seen.insert($0).inserted }
    }
}

private extension ChatDonorToolInvocation {
    var requiredPermissionMode: ChatDonorPermissionMode? {
        metadata["requiredPermissionMode"].flatMap(ChatDonorPermissionMode.init(rawValue:))
    }
}

public enum ChatDonorPermissionSessionMemory: String, Codable, Hashable, Sendable {
    case none
    case alwaysAllowed = "always-allowed"
    case blocked
}

public enum ChatDonorPermissionAllowReason: String, Codable, Hashable, Sendable {
    case allowRule = "allow-rule"
    case dynamicAllowRule = "dynamic-allow-rule"
    case defaultAllow = "default-allow"
    case sessionMemory = "session-memory"
    case permissionMode = "permission-mode"
}

public enum ChatDonorPermissionDenyReason: String, Codable, Hashable, Sendable {
    case finalDeny = "final-deny"
    case denyRule = "deny-rule"
    case defaultDeny = "default-deny"
    case sessionMemory = "session-memory"
    case permissionMode = "permission-mode"
}

public enum ChatDonorPermissionEvaluation: Codable, Hashable, Sendable {
    case allowed(reason: ChatDonorPermissionAllowReason, matchedRule: ChatDonorPermissionRule?)
    case denied(reason: ChatDonorPermissionDenyReason, matchedRule: ChatDonorPermissionRule?)
    case requiresApproval(ChatDonorApprovalRequest)

    public var requiresApproval: Bool {
        if case .requiresApproval = self { true } else { false }
    }
}

public enum ChatDonorPermissionResponse: String, Codable, Hashable, Sendable {
    case allowOnce = "allow-once"
    case alwaysAllow = "always-allow"
    case deny
    case denyAndBlock = "deny-and-block"
}

public struct ChatDonorApprovalRequest: Codable, Hashable, Sendable {
    public var approvalID: String
    public var invocation: ChatDonorToolInvocation
    public var reason: String
    public var risk: ChatDonorPermissionRisk

    public init(approvalID: String, invocation: ChatDonorToolInvocation, reason: String) {
        self.approvalID = approvalID
        self.invocation = invocation
        self.reason = reason
        self.risk = invocation.riskLevel
    }
}

public struct ChatDonorApprovalReceipt: Codable, Hashable, Sendable {
    public var approvalID: String
    public var response: ChatDonorPermissionResponse
    public var allowedExecution: Bool
    public var rememberedSessionDecision: ChatDonorPermissionSessionMemory
    public var risk: ChatDonorPermissionRisk
    public var reason: String

    public init(
        approvalID: String,
        response: ChatDonorPermissionResponse,
        allowedExecution: Bool,
        rememberedSessionDecision: ChatDonorPermissionSessionMemory,
        risk: ChatDonorPermissionRisk,
        reason: String
    ) {
        self.approvalID = approvalID
        self.response = response
        self.allowedExecution = allowedExecution
        self.rememberedSessionDecision = rememberedSessionDecision
        self.risk = risk
        self.reason = reason
    }
}

public actor ChatDonorPermissionSession {
    private var alwaysAllowed: Set<String> = []
    private var blocked: Set<String> = []

    public init() {}

    public func evaluate(
        _ invocation: ChatDonorToolInvocation,
        policy: ChatDonorPermissionPolicy,
        approvalID: String = UUID().uuidString
    ) -> ChatDonorPermissionEvaluation {
        let key = invocation.sessionMemoryKey
        let memory: ChatDonorPermissionSessionMemory
        if alwaysAllowed.contains(key) {
            memory = .alwaysAllowed
        } else if blocked.contains(key) {
            memory = .blocked
        } else {
            memory = .none
        }
        return policy.evaluate(invocation, sessionMemory: memory, approvalID: approvalID)
    }

    public func resolve(
        _ evaluation: ChatDonorPermissionEvaluation,
        response: ChatDonorPermissionResponse
    ) -> ChatDonorApprovalReceipt? {
        guard case .requiresApproval(let request) = evaluation else { return nil }
        let key = request.invocation.sessionMemoryKey
        var remembered: ChatDonorPermissionSessionMemory = .none

        switch response {
        case .alwaysAllow:
            alwaysAllowed.insert(key)
            blocked.remove(key)
            remembered = .alwaysAllowed
        case .denyAndBlock:
            blocked.insert(key)
            alwaysAllowed.remove(key)
            remembered = .blocked
        case .allowOnce, .deny:
            break
        }

        return ChatDonorApprovalReceipt(
            approvalID: request.approvalID,
            response: response,
            allowedExecution: response == .allowOnce || response == .alwaysAllow,
            rememberedSessionDecision: remembered,
            risk: request.risk,
            reason: request.reason
        )
    }

    public func reset() {
        alwaysAllowed.removeAll()
        blocked.removeAll()
    }

    public var memorySnapshot: [String: ChatDonorPermissionSessionMemory] {
        var snapshot = Dictionary(uniqueKeysWithValues: alwaysAllowed.map { ($0, ChatDonorPermissionSessionMemory.alwaysAllowed) })
        for key in blocked {
            snapshot[key] = .blocked
        }
        return snapshot
    }
}

public enum ChatDonorSandboxNetworkPolicy: String, Codable, Hashable, Sendable {
    case none
    case local
    case full
}

public enum ChatDonorSandboxFilePolicy: Codable, Hashable, Sendable {
    case readOnly
    case workingDirectoryOnly
    case custom(read: [String], write: [String])
}

public struct ChatDonorSandboxPolicy: Codable, Hashable, Sendable {
    public static let maxTimeoutSeconds: TimeInterval = 86_400

    public var networkPolicy: ChatDonorSandboxNetworkPolicy
    public var filePolicy: ChatDonorSandboxFilePolicy
    public var allowSubprocesses: Bool
    public var enabled: Bool

    public init(
        networkPolicy: ChatDonorSandboxNetworkPolicy = .local,
        filePolicy: ChatDonorSandboxFilePolicy = .workingDirectoryOnly,
        allowSubprocesses: Bool = true,
        enabled: Bool = true
    ) {
        self.networkPolicy = networkPolicy
        self.filePolicy = filePolicy
        self.allowSubprocesses = allowSubprocesses
        self.enabled = enabled
    }

    public static let standard = ChatDonorSandboxPolicy()
    public static let restrictive = ChatDonorSandboxPolicy(networkPolicy: .none, filePolicy: .readOnly, allowSubprocesses: false)
    public static let disabled = ChatDonorSandboxPolicy(networkPolicy: .full, filePolicy: .workingDirectoryOnly, allowSubprocesses: true, enabled: false)

    public var isEffectivelyDisabled: Bool {
        !enabled || (networkPolicy == .full && allowSubprocesses && filePolicy == .workingDirectoryOnly)
    }

    public func requirement(timeoutSeconds: TimeInterval) -> ChatDonorSandboxRequirement {
        let timeoutDecision: ChatDonorTimeoutDecision
        if timeoutSeconds <= 0 {
            timeoutDecision = .invalidNonPositive
        } else if timeoutSeconds > Self.maxTimeoutSeconds {
            timeoutDecision = .exceedsMaximum(maximum: Self.maxTimeoutSeconds)
        } else {
            timeoutDecision = .valid
        }

        return ChatDonorSandboxRequirement(
            requiresSandbox: !isEffectivelyDisabled,
            networkPolicy: networkPolicy,
            filePolicy: filePolicy,
            allowSubprocesses: allowSubprocesses,
            timeoutDecision: timeoutDecision
        )
    }
}

public enum ChatDonorTimeoutDecision: Codable, Hashable, Sendable {
    case valid
    case invalidNonPositive
    case exceedsMaximum(maximum: TimeInterval)
}

public struct ChatDonorSandboxRequirement: Codable, Hashable, Sendable {
    public var requiresSandbox: Bool
    public var networkPolicy: ChatDonorSandboxNetworkPolicy
    public var filePolicy: ChatDonorSandboxFilePolicy
    public var allowSubprocesses: Bool
    public var timeoutDecision: ChatDonorTimeoutDecision

    public var canStart: Bool {
        timeoutDecision == .valid
    }
}

public struct ChatDonorTurnCancellationError: Error, Equatable, Sendable, LocalizedError {
    public var reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }

    public var errorDescription: String? {
        reason.map { "Turn cancelled: \($0)" } ?? "Turn cancelled"
    }
}

public struct ChatDonorTurnCancellationReceipt: Codable, Hashable, Sendable {
    public var isCancelled: Bool
    public var reason: String?
    public var cancellationCount: Int

    public init(isCancelled: Bool, reason: String?, cancellationCount: Int) {
        self.isCancelled = isCancelled
        self.reason = reason
        self.cancellationCount = cancellationCount
    }
}

public actor ChatDonorTurnCancellationToken {
    private var reason: String?
    private var cancellationCount = 0

    public init() {}

    public var isCancelled: Bool {
        reason != nil
    }

    public func cancel(reason: String? = nil) {
        cancellationCount += 1
        if self.reason == nil {
            self.reason = reason ?? "cancelled"
        }
    }

    public func checkCancellation() throws {
        if let reason {
            throw ChatDonorTurnCancellationError(reason: reason)
        }
    }

    public func receipt() -> ChatDonorTurnCancellationReceipt {
        ChatDonorTurnCancellationReceipt(
            isCancelled: reason != nil,
            reason: reason,
            cancellationCount: cancellationCount
        )
    }
}
