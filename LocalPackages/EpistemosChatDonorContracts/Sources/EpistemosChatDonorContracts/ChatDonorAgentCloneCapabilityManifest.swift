import Foundation

public enum ChatDonorAgentCloneCapabilityKind: String, CaseIterable, Codable, Sendable {
    case provider
    case tool
    case toolGroup = "tool-group"
    case mcp
    case sessionHistory = "session-history"
    case settings
    case permissionApproval = "permission-approval"
    case rollback
    case usage
    case automation
    case messages
    case dependencyRisk = "dependency-risk"
}

public enum ChatDonorAgentCloneCapabilityValidationFailure: String, Codable, Hashable, Sendable, CustomStringConvertible {
    case emptyIdentifier = "empty-identifier"
    case emptyDisplayName = "empty-display-name"
    case emptySourceAnchors = "empty-source-anchors"
    case emptySourcePath = "empty-source-path"
    case emptySourceMarker = "empty-source-marker"
    case emptyDestinationSeams = "empty-destination-seams"
    case removalWithoutOwnerApproval = "removal-without-owner-approval"

    public var description: String { rawValue }
}

public struct ChatDonorAgentCloneSourceAnchor: Codable, Hashable, Sendable {
    public var path: String
    public var requiredMarkers: [String]

    public init(path: String, requiredMarkers: [String]) {
        self.path = path
        self.requiredMarkers = requiredMarkers
    }

    public var validationFailures: [ChatDonorAgentCloneCapabilityValidationFailure] {
        var failures: [ChatDonorAgentCloneCapabilityValidationFailure] = []
        if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptySourcePath)
        }
        if requiredMarkers.isEmpty ||
            requiredMarkers.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            failures.append(.emptySourceMarker)
        }
        return failures
    }
}

public struct ChatDonorAgentCloneCapability: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var nativeName: String?
    public var displayName: String
    public var kind: ChatDonorAgentCloneCapabilityKind
    public var destinationSeams: [ChatDonorDestinationSeam]
    public var sourceAnchors: [ChatDonorAgentCloneSourceAnchor]
    public var mustPreserve: Bool
    public var requiresOwnerApprovalBeforeRemoval: Bool
    public var notes: String

    public init(
        id: String,
        nativeName: String? = nil,
        displayName: String,
        kind: ChatDonorAgentCloneCapabilityKind,
        destinationSeams: [ChatDonorDestinationSeam],
        sourceAnchors: [ChatDonorAgentCloneSourceAnchor],
        mustPreserve: Bool = true,
        requiresOwnerApprovalBeforeRemoval: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.nativeName = nativeName
        self.displayName = displayName
        self.kind = kind
        self.destinationSeams = destinationSeams
        self.sourceAnchors = sourceAnchors
        self.mustPreserve = mustPreserve
        self.requiresOwnerApprovalBeforeRemoval = requiresOwnerApprovalBeforeRemoval
        self.notes = notes
    }

    public var validationFailures: [ChatDonorAgentCloneCapabilityValidationFailure] {
        var failures: [ChatDonorAgentCloneCapabilityValidationFailure] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyIdentifier)
        }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyDisplayName)
        }
        if destinationSeams.isEmpty {
            failures.append(.emptyDestinationSeams)
        }
        if sourceAnchors.isEmpty {
            failures.append(.emptySourceAnchors)
        }
        if mustPreserve && !requiresOwnerApprovalBeforeRemoval {
            failures.append(.removalWithoutOwnerApproval)
        }
        for anchor in sourceAnchors {
            failures.append(contentsOf: anchor.validationFailures)
        }
        return failures
    }

    public var isValid: Bool {
        validationFailures.isEmpty
    }
}

public enum ChatDonorAgentCloneCapabilityManifest: Sendable {
    public static let providerCapabilities: [ChatDonorAgentCloneCapability] = [
        provider("claude", displayName: "Claude", setupMarker: "static let claude", settingsMarker: "selectedProvider == .claude"),
        provider("openAI", displayName: "OpenAI", setupMarker: "static let openAI", settingsMarker: "selectedProvider == .openAI"),
        provider("codex", displayName: "Codex", setupMarker: "static let codex", settingsMarker: "selectedProvider == .codex"),
        provider("deepSeek", displayName: "DeepSeek", setupMarker: "static let deepSeek", settingsMarker: "selectedProvider == .deepSeek"),
        provider("huggingFace", displayName: "Hugging Face", setupMarker: "static let huggingFace", settingsMarker: "selectedProvider == .huggingFace"),
        provider("zAI", displayName: "Z.ai", setupMarker: "static let zAI", settingsMarker: "selectedProvider == .zAI"),
        provider("bigModel", displayName: "BigModel", setupMarker: "static let bigModel", settingsMarker: "selectedProvider == .bigModel"),
        provider("miniMax", displayName: "MiniMax", setupMarker: "static let miniMax", settingsMarker: "selectedProvider == .miniMax"),
        provider("openRouter", displayName: "OpenRouter", setupMarker: "static let openRouter", settingsMarker: "selectedProvider == .openRouter"),
        provider("qwen", displayName: "Qwen", setupMarker: "static let qwen", settingsMarker: "selectedProvider == .qwen"),
        provider("gemini", displayName: "Google Gemini", setupMarker: "static let gemini", settingsMarker: "selectedProvider == .gemini"),
        provider("grok", displayName: "Grok", setupMarker: "static let grok", settingsMarker: "selectedProvider == .grok"),
        provider("mistral", displayName: "Mistral", setupMarker: "static let mistral", settingsMarker: "selectedProvider == .mistral"),
        provider("codestral", displayName: "Codestral", setupMarker: "static let codestral", settingsMarker: "selectedProvider == .codestral"),
        provider("vibe", displayName: "Mistral Vibe", setupMarker: "static let vibe", settingsMarker: "selectedProvider == .vibe"),
        provider("ollama", displayName: "Ollama Cloud", setupMarker: "static let ollama", settingsMarker: "selectedProvider == .ollama"),
        provider("localOllama", displayName: "Local Ollama", setupMarker: "static let localOllama", settingsMarker: #"Text("Local Ollama")"#),
        provider("vLLM", displayName: "vLLM", setupMarker: "static let vLLM", settingsMarker: "selectedProvider == .vLLM"),
        provider("lmStudio", displayName: "LM Studio", setupMarker: "static let lmStudio", settingsMarker: "selectedProvider == .lmStudio"),
        ChatDonorAgentCloneCapability(
            id: "agentclone.provider.foundationModel",
            nativeName: "foundationModel",
            displayName: "Apple Intelligence",
            kind: .provider,
            destinationSeams: [.providerPicker, .providerRuntime, .modelUX, .settingsSurface],
            sourceAnchors: [
                anchor(
                    "LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift",
                    "static let appleIntelligence",
                    #"id: "foundationModel""#
                ),
                anchor(
                    "LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/AppleIntelligencePopover.swift",
                    "struct AppleIntelligencePopover",
                    "Accessibility intent parsing"
                )
            ],
            notes: "On-device Apple provider must stay visible and availability-gated, not collapsed into a generic cloud provider."
        )
    ]

    public static let toolCapabilities: [ChatDonorAgentCloneCapability] = [
        tool("task_complete", slug: "task-complete", displayName: "Task complete", marker: "static let done"),
        tool("list_native_tools", slug: "list-native-tools", displayName: "List native tools", marker: "static let tools"),
        tool("web_search", slug: "web-search", displayName: "Web search", marker: "static let search"),
        tool("project_folder", slug: "project-folder", displayName: "Project folder", marker: "static let folder"),
        tool("conversation", slug: "conversation", displayName: "Conversation", marker: "static let chat"),
        tool("send_message", slug: "send-message", displayName: "Send message", marker: "static let msg"),
        tool("agent_script", slug: "agent-script", displayName: "Agent script", marker: "static let agent"),
        tool("plan_mode", slug: "plan-mode", displayName: "Plan mode", marker: "static let plan"),
        tool("index", slug: "index", displayName: "Project index", marker: "static let index"),
        tool("git", slug: "git", displayName: "Git", marker: "static let git"),
        tool("batch_commands", slug: "batch-commands", displayName: "Batch commands", marker: "static let batch"),
        tool("batch_tools", slug: "batch-tools", displayName: "Batch tools", marker: "static let multi"),
        tool("file_manager", slug: "file-manager", displayName: "File manager", marker: "static let file"),
        tool("xcode", slug: "xcode", displayName: "Xcode", marker: "static let xc"),
        tool("run_shell_script", slug: "run-shell-script", displayName: "Shell", marker: "static let sh"),
        tool("apple_script", slug: "apple-script", displayName: "AppleScript", marker: "static let `as`"),
        tool("accessibility", slug: "accessibility", displayName: "Accessibility", marker: "static let ax"),
        tool("javascript", slug: "javascript", displayName: "JavaScript", marker: "static let js"),
        tool("execute_agent_command", slug: "user-shell", displayName: "User shell", marker: "static let user"),
        tool("execute_daemon_command", slug: "root-shell", displayName: "Root daemon shell", marker: "static let root"),
        tool("safari", slug: "safari", displayName: "Safari automation", marker: "static let web"),
        tool("selenium", slug: "selenium", displayName: "Selenium", marker: "static let sel"),
        tool("memory", slug: "memory", displayName: "Memory", marker: #"static let mem = "memory""#),
        tool("skill", slug: "skill", displayName: "Skills", marker: #"static let skill = "skill""#),
        tool("spawn_agent", slug: "spawn-agent", displayName: "Spawn agent", marker: #"static let spawn = "spawn_agent""#),
        tool("tell_agent", slug: "tell-agent", displayName: "Tell agent", marker: #"static let messageAgent = "tell_agent""#),
        tool("ask_user", slug: "ask-user", displayName: "Ask user", marker: #"static let ask = "ask_user""#),
        tool("fetch", slug: "web-fetch", displayName: "Web fetch", marker: #"static let webFetch = "fetch""#)
    ]

    public static let toolGroupCapabilities: [ChatDonorAgentCloneCapability] = [
        toolGroup("Core", marker: "Tool.Group.core:"),
        toolGroup("Work", marker: "Tool.Group.work:"),
        toolGroup("Code", marker: "Tool.Group.code:"),
        toolGroup("Auto", marker: "Tool.Group.auto:"),
        toolGroup("User", marker: "Tool.Group.user:"),
        toolGroup("Root", marker: "Tool.Group.root:"),
        toolGroup("Sub-agents", marker: "Tool.Group.subAgents:"),
        toolGroup("Experimental", marker: "Tool.Group.exp:")
    ]

    public static let surfaceCapabilities: [ChatDonorAgentCloneCapability] = [
        surface(
            id: "agentclone.surface.mcp",
            nativeName: "mcp",
            displayName: "MCP servers, import/export, discovered tools",
            kind: .mcp,
            seams: [.mcpBridge, .toolRegistry, .settingsSurface],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPConfig.swift", "struct MCPServerConfig", "final class MCPServerRegistry"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift", "final class MCPService", "discoveredTools"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPServersView.swift", "struct MCPServersView", "Import server configuration"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/AgentTools+AppBridge.swift", "filteredMCP", "mcpTools")
            ]
        ),
        surface(
            id: "agentclone.surface.sessions-history-recents",
            nativeName: "sessions-history-recents",
            displayName: "Sessions, prompt history, recents",
            kind: .sessionHistory,
            seams: [.sessionStore, .recentsBridge, .sidePanel],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift", "final class SessionStore", "listSessions"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Models/ChatModels.swift", "final class ChatHistoryStore", "buildLLMContext"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Tools/HistoryView.swift", "struct HistoryView", "Task Summaries"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Tools/RecentAgentsService.swift", "final class RecentAgentsService", "removeById")
            ]
        ),
        surface(
            id: "agentclone.surface.settings",
            nativeName: "settings",
            displayName: "Provider settings, coding preferences, options",
            kind: .settings,
            seams: [.settingsSurface, .providerPicker, .modelUX],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/SettingsView.swift", "struct SettingsView", "LLM Provider"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/AgentOptionsView.swift", "struct AgentOptionsView", "In-process + user helper + privileged helper"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/CodingPreferencesView.swift", "struct CodingPreferencesView", "Coding Preferences"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/FallbackChainView.swift", "struct FallbackChainView", "Fallback Chain"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/HUDOptionsView.swift", "struct HUDOptionsView", "HUD")
            ]
        ),
        surface(
            id: "agentclone.surface.permissions-approval",
            nativeName: "permissions-approval",
            displayName: "Shell safety, helper services, permissions, user approval",
            kind: .permissionApproval,
            seams: [.permissionEngine, .toolRegistry, .settingsSurface],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/ShellSafetyService.swift", "enum ShellSafetyService", "rootDaemon"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/UserService.swift", "requiresApproval", "ShellSafetyService.check"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/HelperService.swift", "SafeSMAppServiceDaemon", "registerDaemon"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/AccessibilitySettingsView.swift", "AccessibilitySettingsView", "requestAccessibilityPermission"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/NativeToolHandlers/NTH-Misc.swift", "case \"ask_user\"", "awaitUserAnswer")
            ]
        ),
        surface(
            id: "agentclone.surface.rollback",
            nativeName: "rollback",
            displayName: "File backup and rollback",
            kind: .rollback,
            seams: [.toolRegistry, .sidePanel],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/FileBackupService.swift", "func snapshot(filePath:", "func rollback(filePath:"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Shared/RollbackView.swift", "struct RollbackView", "File Backups")
            ]
        ),
        surface(
            id: "agentclone.surface.usage",
            nativeName: "usage",
            displayName: "Token usage, budget, cost readback",
            kind: .usage,
            seams: [.observability, .settingsSurface],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/TokenUsageStore.swift", "final class TokenUsageStore", "TokenBudgetTracker"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Header/LLMUsageView.swift", "struct LLMUsageView", "Token usage per model"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/TaskExecution.swift", "TokenUsageStore.shared.recordModelUsage", "isCostExceeded")
            ]
        ),
        surface(
            id: "agentclone.surface.automation",
            nativeName: "automation",
            displayName: "Web, AppleScript, Accessibility, JavaScript, Selenium, Xcode automation",
            kind: .automation,
            seams: [.toolRegistry, .permissionEngine, .workflow],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/WebAutomationService.swift", "Unified web automation service", "Selenium"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/NSAppleScriptService.swift", "NSAppleScript", "execute"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/TE-Selenium.swift", "selenium", "Selenium"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/XcodeService.swift", "Xcode automation", "grant permission")
            ]
        ),
        surface(
            id: "agentclone.surface.messages",
            nativeName: "messages",
            displayName: "Messages/iMessage monitor and reply tab",
            kind: .messages,
            seams: [.workflow, .sidePanel, .toolRegistry],
            anchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentScriptTabs/ScriptTab.swift", "isMessagesTab", "replyHandle"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift", "messagesMonitorEnabled", "startMessagesMonitor"),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/NativeToolHandlers/Conversation.swift", "tell application \"Messages\"", "ensureMessagesTab")
            ]
        )
    ]

    public static let dependencyRiskCapabilities: [ChatDonorAgentCloneCapability] = [
        ChatDonorAgentCloneCapability(
            id: "agentclone.risk.closed-agent-packages",
            nativeName: "Agent* closed packages",
            displayName: "Pinned Agent* package dependency risk",
            kind: .dependencyRisk,
            destinationSeams: [.visibleShell, .providerRuntime, .toolRegistry, .mcpBridge, .permissionEngine],
            sourceAnchors: [
                anchor("LocalPackages/AgentClone/Package.swift", "https://github.com/macOS26/AgentTools.git", "https://github.com/macOS26/AgentMCP.git"),
                anchor("LocalPackages/AgentClone/VENDOR.md", "Do not call the Chat lane complete", "explicitly accepted by the owner")
            ],
            notes: "This risk is not a deletion permit. Any package removal or replacement needs source-backed proof and owner approval because these packages currently carry provider, MCP, tool, audit, terminal, and access behavior."
        )
    ]

    public static var allCapabilities: [ChatDonorAgentCloneCapability] {
        providerCapabilities + toolCapabilities + toolGroupCapabilities + surfaceCapabilities + dependencyRiskCapabilities
    }

    public static var providerIDs: [String] {
        providerCapabilities.compactMap(\.nativeName)
    }

    public static var toolNames: [String] {
        toolCapabilities.compactMap(\.nativeName)
    }

    public static var validationFailures: [String: [ChatDonorAgentCloneCapabilityValidationFailure]] {
        Dictionary(uniqueKeysWithValues: allCapabilities.map { ($0.id, $0.validationFailures) })
            .filter { !$0.value.isEmpty }
    }

    public static func capabilities(kind: ChatDonorAgentCloneCapabilityKind) -> [ChatDonorAgentCloneCapability] {
        allCapabilities.filter { $0.kind == kind }
    }

    private static func provider(
        _ providerID: String,
        displayName: String,
        setupMarker: String,
        settingsMarker: String
    ) -> ChatDonorAgentCloneCapability {
        ChatDonorAgentCloneCapability(
            id: "agentclone.provider.\(providerID)",
            nativeName: providerID,
            displayName: displayName,
            kind: .provider,
            destinationSeams: [.providerPicker, .providerRuntime, .settingsSurface],
            sourceAnchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift", setupMarker, #"id: "\#(providerID)""#),
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/SettingsView.swift", settingsMarker)
            ],
            notes: "Provider must remain selectable and configured in the Epistemos chat surface unless a future contract explicitly blocks it with proof."
        )
    }

    private static func tool(
        _ nativeName: String,
        slug: String,
        displayName: String,
        marker: String
    ) -> ChatDonorAgentCloneCapability {
        ChatDonorAgentCloneCapability(
            id: "agentclone.tool.\(slug)",
            nativeName: nativeName,
            displayName: displayName,
            kind: .tool,
            destinationSeams: [.toolRegistry],
            sourceAnchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift", marker)
            ],
            notes: "Native tool name must stay reachable through the tool registry or be formally blocked with proof."
        )
    }

    private static func toolGroup(_ name: String, marker: String) -> ChatDonorAgentCloneCapability {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return ChatDonorAgentCloneCapability(
            id: "agentclone.tool-group.\(slug)",
            nativeName: name,
            displayName: "\(name) tool group",
            kind: .toolGroup,
            destinationSeams: [.toolRegistry, .settingsSurface],
            sourceAnchors: [
                anchor("LocalPackages/AgentClone/Sources/AgentClone/Services/ToolPreferencesService.swift", marker)
            ],
            notes: "Tool group progressive disclosure is allowed; deleting the underlying capability is not."
        )
    }

    private static func surface(
        id: String,
        nativeName: String,
        displayName: String,
        kind: ChatDonorAgentCloneCapabilityKind,
        seams: [ChatDonorDestinationSeam],
        anchors: [ChatDonorAgentCloneSourceAnchor]
    ) -> ChatDonorAgentCloneCapability {
        ChatDonorAgentCloneCapability(
            id: id,
            nativeName: nativeName,
            displayName: displayName,
            kind: kind,
            destinationSeams: seams,
            sourceAnchors: anchors,
            notes: "Surface may be flattened or moved into a side panel, but the capability must remain reachable."
        )
    }

    private static func anchor(_ path: String, _ markers: String...) -> ChatDonorAgentCloneSourceAnchor {
        ChatDonorAgentCloneSourceAnchor(path: path, requiredMarkers: markers)
    }
}
