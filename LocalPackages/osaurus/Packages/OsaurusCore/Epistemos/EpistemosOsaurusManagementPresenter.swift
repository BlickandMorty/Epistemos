//  EpistemosOsaurusManagementPresenter.swift
//  OsaurusCore

import AppKit
import SwiftUI

public struct EpistemosOsaurusModelPick: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let subtitle: String
    public let sectionTitle: String
    public let systemImage: String
    /// 0.33f model detail (native, reachable from act): on-device download state +
    /// context window — surfaced so the act model stack shows real model detail, not
    /// just a name. Defaulted so existing call sites stay source-compatible.
    public let isDownloaded: Bool
    public let contextLength: Int?

    public init(
        id: String,
        displayName: String,
        subtitle: String,
        sectionTitle: String,
        systemImage: String,
        isDownloaded: Bool = false,
        contextLength: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.subtitle = subtitle
        self.sectionTitle = sectionTitle
        self.systemImage = systemImage
        self.isDownloaded = isDownloaded
        self.contextLength = contextLength
    }
}

public struct EpistemosOsaurusToolSecretRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let pluginName: String
    public let secretLabel: String
    public let secretDescription: String?
    public let isSet: Bool

    public init(id: String, pluginName: String, secretLabel: String, secretDescription: String?, isSet: Bool) {
        self.id = id
        self.pluginName = pluginName
        self.secretLabel = secretLabel
        self.secretDescription = secretDescription
        self.isSet = isSet
    }
}

public struct EpistemosOsaurusSkillRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let sourceLabel: String
    public let category: String?
    public let enabled: Bool

    public init(id: String, name: String, detail: String, sourceLabel: String, category: String?, enabled: Bool) {
        self.id = id
        self.name = name
        self.detail = detail
        self.sourceLabel = sourceLabel
        self.category = category
        self.enabled = enabled
    }
}

public struct EpistemosOsaurusIdentityStorageStatus: Hashable, Sendable {
    public let identityConfigured: Bool
    public let mnemonicBackedUp: Bool
    public let savedSessionCount: Int

    public init(identityConfigured: Bool, mnemonicBackedUp: Bool, savedSessionCount: Int) {
        self.identityConfigured = identityConfigured
        self.mnemonicBackedUp = mnemonicBackedUp
        self.savedSessionCount = savedSessionCount
    }
}

public struct EpistemosOsaurusVoiceStatus: Hashable, Sendable {
    public let transcriptionEnabled: Bool
    public let transcriptionStateLabel: String
    public let vadEnabled: Bool
    public let ttsModelReady: Bool

    public init(transcriptionEnabled: Bool, transcriptionStateLabel: String, vadEnabled: Bool, ttsModelReady: Bool) {
        self.transcriptionEnabled = transcriptionEnabled
        self.transcriptionStateLabel = transcriptionStateLabel
        self.vadEnabled = vadEnabled
        self.ttsModelReady = ttsModelReady
    }
}

public struct EpistemosOsaurusPluginRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let toolCount: Int
    public let skillCount: Int
    public let routeCount: Int
    public let hasSecrets: Bool
    public let hasWeb: Bool

    public init(
        id: String, name: String, toolCount: Int, skillCount: Int,
        routeCount: Int, hasSecrets: Bool, hasWeb: Bool
    ) {
        self.id = id
        self.name = name
        self.toolCount = toolCount
        self.skillCount = skillCount
        self.routeCount = routeCount
        self.hasSecrets = hasSecrets
        self.hasWeb = hasWeb
    }
}

public struct EpistemosOsaurusAgentRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let modelLabel: String
    public let toolsEnabled: Bool
    public let memoryEnabled: Bool
    public let autonomousEnabled: Bool
    public let isDefault: Bool
    public let isActive: Bool

    public init(
        id: String, name: String, modelLabel: String, toolsEnabled: Bool,
        memoryEnabled: Bool, autonomousEnabled: Bool, isDefault: Bool, isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.modelLabel = modelLabel
        self.toolsEnabled = toolsEnabled
        self.memoryEnabled = memoryEnabled
        self.autonomousEnabled = autonomousEnabled
        self.isDefault = isDefault
        self.isActive = isActive
    }
}

public struct EpistemosOsaurusManagementEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let systemImage: String

    public init(id: String, label: String, systemImage: String) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
    }
}

public struct EpistemosOsaurusQuickAction: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let systemImage: String
    public let managementTabID: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        managementTabID: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.managementTabID = managementTabID
    }
}

public struct EpistemosOsaurusActSettingsSnapshot: Equatable, Sendable {
    public let selectedModelID: String?
    public let selectedModelDisplayName: String?
    public let globalWorkingFolderPath: String?
    public let toolsEnabled: Bool
    public let memoryEnabled: Bool
    public let computerUseEnabled: Bool
    public let sandboxAvailable: Bool
    public let sandboxRunning: Bool
    public let sandboxStatusLabel: String
    public let sandboxAvailabilityLabel: String
    public let toolSelectionModeID: String
    public let toolSelectionModeLabel: String
    public let registeredToolCount: Int
    public let enabledToolCount: Int
    public let toolAllowlistCount: Int?
    public let registeredSkillCount: Int
    public let enabledSkillCount: Int
    public let skillAllowlistCount: Int?
    public let memoryModeLabel: String
    public let memoryBudgetLabel: String
    public let computerUsePolicyLabel: String
    public let computerUseAllowlistLabel: String
    public let managementSurfaceCount: Int

    public init(
        selectedModelID: String?,
        selectedModelDisplayName: String?,
        globalWorkingFolderPath: String?,
        toolsEnabled: Bool,
        memoryEnabled: Bool,
        computerUseEnabled: Bool,
        sandboxAvailable: Bool,
        sandboxRunning: Bool,
        sandboxStatusLabel: String,
        sandboxAvailabilityLabel: String,
        toolSelectionModeID: String,
        toolSelectionModeLabel: String,
        registeredToolCount: Int,
        enabledToolCount: Int,
        toolAllowlistCount: Int?,
        registeredSkillCount: Int,
        enabledSkillCount: Int,
        skillAllowlistCount: Int?,
        memoryModeLabel: String,
        memoryBudgetLabel: String,
        computerUsePolicyLabel: String,
        computerUseAllowlistLabel: String,
        managementSurfaceCount: Int
    ) {
        self.selectedModelID = selectedModelID
        self.selectedModelDisplayName = selectedModelDisplayName
        self.globalWorkingFolderPath = globalWorkingFolderPath
        self.toolsEnabled = toolsEnabled
        self.memoryEnabled = memoryEnabled
        self.computerUseEnabled = computerUseEnabled
        self.sandboxAvailable = sandboxAvailable
        self.sandboxRunning = sandboxRunning
        self.sandboxStatusLabel = sandboxStatusLabel
        self.sandboxAvailabilityLabel = sandboxAvailabilityLabel
        self.toolSelectionModeID = toolSelectionModeID
        self.toolSelectionModeLabel = toolSelectionModeLabel
        self.registeredToolCount = registeredToolCount
        self.enabledToolCount = enabledToolCount
        self.toolAllowlistCount = toolAllowlistCount
        self.registeredSkillCount = registeredSkillCount
        self.enabledSkillCount = enabledSkillCount
        self.skillAllowlistCount = skillAllowlistCount
        self.memoryModeLabel = memoryModeLabel
        self.memoryBudgetLabel = memoryBudgetLabel
        self.computerUsePolicyLabel = computerUsePolicyLabel
        self.computerUseAllowlistLabel = computerUseAllowlistLabel
        self.managementSurfaceCount = managementSurfaceCount
    }
}

public struct EpistemosOsaurusPolicyOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let detail: String

    public init(id: String, label: String, detail: String) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct EpistemosOsaurusSystemPermissionRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let systemImage: String
    public let isGranted: Bool
    public let usesSystemSettings: Bool

    public init(
        id: String,
        displayName: String,
        description: String,
        systemImage: String,
        isGranted: Bool,
        usesSystemSettings: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.systemImage = systemImage
        self.isGranted = isGranted
        self.usesSystemSettings = usesSystemSettings
    }
}

public struct EpistemosOsaurusToolPermissionRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultPolicyID: String
    public let effectivePolicyID: String
    public let configuredPolicyID: String?
    public let requirementsLabel: String
    public let missingGrantCount: Int
    public let isDestructive: Bool

    public init(
        id: String,
        displayName: String,
        description: String,
        defaultPolicyID: String,
        effectivePolicyID: String,
        configuredPolicyID: String?,
        requirementsLabel: String,
        missingGrantCount: Int,
        isDestructive: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultPolicyID = defaultPolicyID
        self.effectivePolicyID = effectivePolicyID
        self.configuredPolicyID = configuredPolicyID
        self.requirementsLabel = requirementsLabel
        self.missingGrantCount = missingGrantCount
        self.isDestructive = isDestructive
    }
}

public struct EpistemosOsaurusComputerUsePolicySnapshot: Equatable, Sendable {
    public let globalPresetID: String
    public let globalPresetLabel: String
    public let globalPresetDetail: String
    public let allowlistedApps: [String]
    public let perAppOverrideCount: Int

    public init(
        globalPresetID: String,
        globalPresetLabel: String,
        globalPresetDetail: String,
        allowlistedApps: [String],
        perAppOverrideCount: Int
    ) {
        self.globalPresetID = globalPresetID
        self.globalPresetLabel = globalPresetLabel
        self.globalPresetDetail = globalPresetDetail
        self.allowlistedApps = allowlistedApps
        self.perAppOverrideCount = perAppOverrideCount
    }
}

public struct EpistemosOsaurusSandboxDiagnosticRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let passed: Bool
    public let detail: String

    public init(id: String, name: String, passed: Bool, detail: String) {
        self.id = id
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public struct EpistemosOsaurusProviderRuntimeSnapshot: Equatable, Sendable {
    public let remoteProviderCount: Int
    public let remoteEnabledCount: Int
    public let remoteConnectedCount: Int
    public let remoteConnectingCount: Int
    public let remoteErrorCount: Int
    public let remoteModelCount: Int
    public let osaurusRouterEnabled: Bool
    public let mcpProviderCount: Int
    public let mcpEnabledCount: Int
    public let mcpConnectedCount: Int
    public let mcpConnectingCount: Int
    public let mcpAuthNeededCount: Int
    public let mcpErrorCount: Int
    public let mcpDiscoveredToolCount: Int

    public init(
        remoteProviderCount: Int,
        remoteEnabledCount: Int,
        remoteConnectedCount: Int,
        remoteConnectingCount: Int,
        remoteErrorCount: Int,
        remoteModelCount: Int,
        osaurusRouterEnabled: Bool,
        mcpProviderCount: Int,
        mcpEnabledCount: Int,
        mcpConnectedCount: Int,
        mcpConnectingCount: Int,
        mcpAuthNeededCount: Int,
        mcpErrorCount: Int,
        mcpDiscoveredToolCount: Int
    ) {
        self.remoteProviderCount = remoteProviderCount
        self.remoteEnabledCount = remoteEnabledCount
        self.remoteConnectedCount = remoteConnectedCount
        self.remoteConnectingCount = remoteConnectingCount
        self.remoteErrorCount = remoteErrorCount
        self.remoteModelCount = remoteModelCount
        self.osaurusRouterEnabled = osaurusRouterEnabled
        self.mcpProviderCount = mcpProviderCount
        self.mcpEnabledCount = mcpEnabledCount
        self.mcpConnectedCount = mcpConnectedCount
        self.mcpConnectingCount = mcpConnectingCount
        self.mcpAuthNeededCount = mcpAuthNeededCount
        self.mcpErrorCount = mcpErrorCount
        self.mcpDiscoveredToolCount = mcpDiscoveredToolCount
    }
}

public struct EpistemosOsaurusPrivacyFilterSnapshot: Equatable, Sendable {
    public let enabled: Bool
    public let skipCodeBlocks: Bool
    public let alwaysApproveByDefault: Bool
    public let requireReviewForNonInteractive: Bool
    public let confidenceThreshold: Float
    public let enabledBuiltinPatternCount: Int
    public let builtinPatternCount: Int
    public let enabledPresetRuleCount: Int
    public let customRuleCount: Int

    public init(
        enabled: Bool,
        skipCodeBlocks: Bool,
        alwaysApproveByDefault: Bool,
        requireReviewForNonInteractive: Bool,
        confidenceThreshold: Float,
        enabledBuiltinPatternCount: Int,
        builtinPatternCount: Int,
        enabledPresetRuleCount: Int,
        customRuleCount: Int
    ) {
        self.enabled = enabled
        self.skipCodeBlocks = skipCodeBlocks
        self.alwaysApproveByDefault = alwaysApproveByDefault
        self.requireReviewForNonInteractive = requireReviewForNonInteractive
        self.confidenceThreshold = confidenceThreshold
        self.enabledBuiltinPatternCount = enabledBuiltinPatternCount
        self.builtinPatternCount = builtinPatternCount
        self.enabledPresetRuleCount = enabledPresetRuleCount
        self.customRuleCount = customRuleCount
    }
}

public struct EpistemosOsaurusDependencySnapshot: Equatable, Sendable {
    public let sandboxPluginRecipeCount: Int
    public let dependencyRecipeCount: Int
    public let installedPluginCount: Int
    public let readyPluginCount: Int
    public let failedPluginCount: Int
    public let installingPluginCount: Int
    public let activeInstallCount: Int

    public init(
        sandboxPluginRecipeCount: Int,
        dependencyRecipeCount: Int,
        installedPluginCount: Int,
        readyPluginCount: Int,
        failedPluginCount: Int,
        installingPluginCount: Int,
        activeInstallCount: Int
    ) {
        self.sandboxPluginRecipeCount = sandboxPluginRecipeCount
        self.dependencyRecipeCount = dependencyRecipeCount
        self.installedPluginCount = installedPluginCount
        self.readyPluginCount = readyPluginCount
        self.failedPluginCount = failedPluginCount
        self.installingPluginCount = installingPluginCount
        self.activeInstallCount = activeInstallCount
    }
}

public struct EpistemosOsaurusNativeToolPermissionRequest: Equatable, Sendable {
    public let toolName: String
    public let description: String
    public let argumentsJSON: String

    public init(toolName: String, description: String, argumentsJSON: String) {
        self.toolName = toolName
        self.description = description
        self.argumentsJSON = argumentsJSON
    }
}

public enum EpistemosOsaurusNativeToolPermissionDecision: Equatable, Sendable {
    case allowOnce
    case alwaysAllow
    case deny
}

public typealias EpistemosOsaurusNativeToolPermissionPresenter =
    @MainActor @Sendable (EpistemosOsaurusNativeToolPermissionRequest) async -> EpistemosOsaurusNativeToolPermissionDecision

public typealias EpistemosOsaurusNativeProviderCredentialPresenter =
    @MainActor @Sendable (ProviderCredentialRequest) async -> ProviderCredentialResult?

public struct EpistemosOsaurusNativePairingRequest: Equatable, Sendable {
    public let connectorAddress: String
    public let agentName: String

    public init(connectorAddress: String, agentName: String) {
        self.connectorAddress = connectorAddress
        self.agentName = agentName
    }
}

public enum EpistemosOsaurusNativePairingDecision: Equatable, Sendable {
    case approveTemporary
    case approvePermanent
    case deny
}

public typealias EpistemosOsaurusNativePairingPresenter =
    @MainActor @Sendable (EpistemosOsaurusNativePairingRequest) async -> EpistemosOsaurusNativePairingDecision

public struct EpistemosOsaurusNativePrivacyReviewEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let categoryRawValue: String
    public let original: String
    public let placeholderToken: String
    public let containingText: String?
    public var approved: Bool

    public init(
        id: UUID,
        categoryRawValue: String,
        original: String,
        placeholderToken: String,
        containingText: String?,
        approved: Bool
    ) {
        self.id = id
        self.categoryRawValue = categoryRawValue
        self.original = original
        self.placeholderToken = placeholderToken
        self.containingText = containingText
        self.approved = approved
    }
}

public struct EpistemosOsaurusNativePrivacyReviewRequest: Identifiable, Sendable {
    public let id: UUID
    public let sessionId: String
    public let entities: [EpistemosOsaurusNativePrivacyReviewEntity]
    public let alwaysApprove: Bool

    public init(
        id: UUID,
        sessionId: String,
        entities: [EpistemosOsaurusNativePrivacyReviewEntity],
        alwaysApprove: Bool
    ) {
        self.id = id
        self.sessionId = sessionId
        self.entities = entities
        self.alwaysApprove = alwaysApprove
    }
}

public enum EpistemosOsaurusNativePrivacyReviewDecision: Sendable {
    case approved(rows: [EpistemosOsaurusNativePrivacyReviewEntity], alwaysApprove: Bool)
    case canceled
}

public struct EpistemosOsaurusNativePrivacyReviewPresenterToken: Hashable, Sendable {
    fileprivate let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public typealias EpistemosOsaurusNativePrivacyReviewPresenter =
    @MainActor @Sendable (EpistemosOsaurusNativePrivacyReviewRequest) async -> EpistemosOsaurusNativePrivacyReviewDecision

@MainActor
enum EpistemosOsaurusNativePromptPresenterStore {
    static var toolPermissionPresenter: EpistemosOsaurusNativeToolPermissionPresenter?
    static var providerCredentialPresenter: EpistemosOsaurusNativeProviderCredentialPresenter?
    static var pairingPresenter: EpistemosOsaurusNativePairingPresenter?
    static var privacyReviewTokens: [UUID: PresenterToken] = [:]
}

@MainActor
enum EpistemosOsaurusManagementPresenter {
    private static let serverController = ServerController()
    private static let updater = UpdaterViewModel()

    static func show(
        initialTab: ManagementTab? = nil,
        deeplinkModelId: String? = nil,
        deeplinkFile: String? = nil,
        deeplinkAgentId: UUID? = nil
    ) {
        if let appDelegate = AppDelegate.shared {
            appDelegate.showManagementWindow(
                initialTab: initialTab,
                deeplinkModelId: deeplinkModelId,
                deeplinkFile: deeplinkFile,
                deeplinkAgentId: deeplinkAgentId
            )
            return
        }

        Task.detached(priority: .utility) {
            ExternalModelLocator.pruneMissing()
        }

        let shownTab = initialTab ?? ManagementStateManager.shared.selectedTab
        CrashReportingService.recordBreadcrumb(
            category: "navigation",
            message: "embedded.management.window \(shownTab.rawValue)"
        )

        let windowManager = WindowManager.shared
        let themeManager = ThemeManager.shared
        let root = ManagementView(
            initialTab: initialTab,
            deeplinkModelId: deeplinkModelId,
            deeplinkFile: deeplinkFile,
            deeplinkAgentId: deeplinkAgentId
        )
        .environmentObject(serverController)
        .environmentObject(updater)
        .environment(\.theme, themeManager.currentTheme)

        let themeAppearance = NSAppearance(
            named: themeManager.currentTheme.isDark ? .darkAqua : .aqua
        )

        if let existingWindow = windowManager.window(for: .management) {
            let hasDeeplink =
                deeplinkModelId != nil || deeplinkFile != nil || deeplinkAgentId != nil
            if hasDeeplink {
                existingWindow.contentViewController = NSHostingController(rootView: root)
            } else if let initialTab {
                ManagementStateManager.shared.selectedTab = initialTab
            }
            existingWindow.appearance = themeAppearance
            windowManager.show(.management, center: false)
            return
        }

        let window = windowManager.createWindow(config: .management) {
            root
        }
        window.isReleasedWhenClosed = false
        window.appearance = themeAppearance
        window.title = "Osaurus Settings"
        windowManager.show(.management)
    }
}

public enum EpistemosOsaurusManagementBridge {
    @MainActor
    public static func showSettings() {
        EpistemosOsaurusManagementPresenter.show()
    }

    @MainActor
    public static func showManagement(tabID: String) {
        let tab = ManagementTab.resolved(from: tabID) ?? .settings
        EpistemosOsaurusManagementPresenter.show(initialTab: tab)
    }

    @MainActor
    public static func managementEntries() -> [EpistemosOsaurusManagementEntry] {
        ManagementTab.allCases.map {
            EpistemosOsaurusManagementEntry(
                id: $0.rawValue,
                label: $0.label,
                systemImage: $0.icon
            )
        }
    }

    @MainActor
    public static func nativeSettingsQuickActions() -> [EpistemosOsaurusQuickAction] {
        [
            quickAction(
                .models,
                title: "Models",
                subtitle: "Local, provider, and Epistemos Pick model rows."
            ),
            quickAction(
                .providers,
                title: "Providers",
                subtitle: "API keys, remote providers, and model access."
            ),
            quickAction(
                .agents,
                title: "Agents",
                subtitle: "Agent defaults, prompts, features, and folders."
            ),
            quickAction(
                .tools,
                title: "Tools",
                subtitle: "All callable tools, including dynamic plugin tools."
            ),
            quickAction(
                .skills,
                title: "Skills",
                subtitle: "Skill library entries available to Act."
            ),
            quickAction(
                .commands,
                title: "Commands",
                subtitle: "Slash-command catalog and command routing."
            ),
            quickAction(
                .permissions,
                title: "Permissions",
                subtitle: "Tool approvals, permission prompts, and grants."
            ),
            quickAction(
                .computerUse,
                title: "Computer Use",
                subtitle: "Native action policy, confirmations, and app allowlist."
            ),
            quickAction(
                .sandbox,
                title: "Sandbox",
                subtitle: "Linux sandbox setup, state, and safe execution."
            ),
            quickAction(
                .memory,
                title: "Memory",
                subtitle: "Recall, distillation, retention, and context budgets."
            ),
            quickAction(
                .watchers,
                title: "Watchers",
                subtitle: "File watchers and background automation."
            ),
            quickAction(
                .schedules,
                title: "Schedules",
                subtitle: "Timed agent runs and notification rules."
            ),
            quickAction(
                .voice,
                title: "Voice",
                subtitle: "Microphone, transcription, and speech settings."
            ),
            quickAction(
                .server,
                title: "Server",
                subtitle: "Local server, OpenAI-compatible routes, and ports."
            ),
            quickAction(
                .privacy,
                title: "Privacy",
                subtitle: "Local data, capture boundaries, and retention."
            ),
            quickAction(
                .identity,
                title: "Identity",
                subtitle: "Biometric identity, keys, and agent credentials."
            ),
            quickAction(
                .storage,
                title: "Storage",
                subtitle: "Databases, cache, recovery, and cleanup."
            ),
            quickAction(
                .plugins,
                title: "Plugins",
                subtitle: "Plugin installs and imported capability bundles."
            ),
            quickAction(
                .themes,
                title: "UI Theme",
                subtitle: "Osaurus UI theme controls kept reachable."
            ),
            quickAction(
                .insights,
                title: "Insights",
                subtitle: "Runtime diagnostics and capability visibility."
            ),
            quickAction(
                .credits,
                title: "Credits",
                subtitle: "Account, credits, and usage details."
            ),
            quickAction(
                .settings,
                title: "General",
                subtitle: "Core Osaurus configuration."
            ),
        ]
    }

    @MainActor
    public static func actSettingsSnapshot() async -> EpistemosOsaurusActSettingsSnapshot {
        let agentManager = AgentManager.shared
        let capabilities = agentManager.effectiveCapabilities(for: Agent.defaultId)
        let memoryConfig = MemoryConfigurationStore.load()
        let sandboxState = SandboxManager.State.shared
        let computerUsePolicy = ComputerUsePolicyStore.load()
        let toolSelectionMode = agentManager.effectiveToolSelectionMode(for: Agent.defaultId)
        let enabledToolNames = agentManager.effectiveEnabledToolNames(for: Agent.defaultId)
        let enabledSkillNames = agentManager.effectiveEnabledSkillNames(for: Agent.defaultId)
        let selectedModelID = currentModel()
        let selectedModelDisplayName: String?
        if let selectedModelID {
            selectedModelDisplayName = await currentModelDisplayName() ?? displayName(for: selectedModelID)
        } else {
            selectedModelDisplayName = nil
        }

        let registeredTools = ToolRegistry.shared.toolCount
        let enabledTools = ToolRegistry.shared.listTools().filter(\.enabled).count
        let registeredSkills = SkillManager.shared.skills.count
        let enabledSkills = SkillManager.shared.enabledCount
        let allowlist = computerUsePolicy.allowlist ?? []
        let availabilityLabel: String
        switch sandboxState.availability {
        case .available:
            availabilityLabel = "Available"
        case .unavailable(let reason):
            availabilityLabel = reason
        }

        return EpistemosOsaurusActSettingsSnapshot(
            selectedModelID: selectedModelID,
            selectedModelDisplayName: selectedModelDisplayName,
            globalWorkingFolderPath: FolderContextService.shared.currentContext?.rootPath.path,
            toolsEnabled: capabilities.toolsEnabled,
            memoryEnabled: capabilities.memoryEnabled,
            computerUseEnabled: capabilities.computerUseEnabled,
            sandboxAvailable: sandboxState.availability.isAvailable,
            sandboxRunning: sandboxState.status.isRunning,
            sandboxStatusLabel: sandboxState.status.label,
            sandboxAvailabilityLabel: availabilityLabel,
            toolSelectionModeID: toolSelectionMode.rawValue,
            toolSelectionModeLabel: toolSelectionMode == .manual ? "Manual" : "Auto",
            registeredToolCount: registeredTools,
            enabledToolCount: enabledTools,
            toolAllowlistCount: enabledToolNames?.count,
            registeredSkillCount: registeredSkills,
            enabledSkillCount: enabledSkills,
            skillAllowlistCount: enabledSkillNames?.count,
            memoryModeLabel: memoryConfig.extractionMode.rawValue,
            memoryBudgetLabel: "\(memoryConfig.memoryBudgetTokens) tokens",
            computerUsePolicyLabel: computerUsePolicy.globalPreset.displayLabel,
            computerUseAllowlistLabel: allowlist.isEmpty ? "All apps" : "\(allowlist.count) apps",
            managementSurfaceCount: ManagementTab.allCases.count
        )
    }

    @MainActor
    @discardableResult
    public static func selectGlobalWorkingFolder() async -> String? {
        await FolderContextService.shared.selectFolder()?.rootPath.path
    }

    @MainActor
    public static func clearGlobalWorkingFolder() {
        FolderContextService.shared.clearFolder()
    }

    @MainActor
    @discardableResult
    public static func startSandbox() async -> String? {
        do {
            try await SandboxManager.shared.startContainer()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    @discardableResult
    public static func stopSandbox() async -> String? {
        do {
            try await SandboxManager.shared.stopContainer()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    @discardableResult
    public static func provisionSandbox() async -> String? {
        do {
            try await SandboxManager.shared.provision()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    public static func runSandboxDiagnostics() async -> [EpistemosOsaurusSandboxDiagnosticRow] {
        await SandboxManager.shared.runDiagnostics().map { result in
            EpistemosOsaurusSandboxDiagnosticRow(
                id: result.name,
                name: result.name,
                passed: result.passed,
                detail: result.detail
            )
        }
    }

    @MainActor
    public static func setDefaultAgentToolsEnabled(_ enabled: Bool) {
        var config = DefaultAgentConfigurationStore.load()
        let shouldDisableTools = !enabled
        guard config.disableTools != shouldDisableTools else { return }
        config.disableTools = shouldDisableTools
        DefaultAgentConfigurationStore.save(config)
        NotificationCenter.default.post(name: .agentUpdated, object: Agent.defaultId)
    }

    @MainActor
    public static func setMemoryEnabled(_ enabled: Bool) {
        var config = MemoryConfigurationStore.load()
        guard config.enabled != enabled else { return }
        config.enabled = enabled
        MemoryConfigurationStore.save(config)
        NotificationCenter.default.post(name: .agentUpdated, object: Agent.defaultId)
    }

    @MainActor
    public static func setToolSelectionMode(_ rawValue: String) {
        guard let mode = ToolSelectionMode(rawValue: rawValue) else { return }
        AgentManager.shared.updateToolSelectionMode(mode, for: Agent.defaultId)
    }

    @MainActor
    public static func systemPermissionRows() -> [EpistemosOsaurusSystemPermissionRow] {
        let service = SystemPermissionService.shared
        return SystemPermission.allCases.map { permission in
            EpistemosOsaurusSystemPermissionRow(
                id: permission.rawValue,
                displayName: permission.displayName,
                description: permission.description,
                systemImage: permission.systemIconName,
                isGranted: service.cachedIsGranted(permission),
                usesSystemSettings: permission.systemSettingsURL != nil
            )
        }
    }

    @MainActor
    public static func refreshSystemPermissions() {
        SystemPermissionService.shared.refreshAllPermissions()
    }

    @MainActor
    public static func requestSystemPermission(_ id: String) {
        guard let permission = SystemPermission(rawValue: id) else { return }
        SystemPermissionService.shared.requestPermission(permission)
    }

    @MainActor
    public static func openSystemPermissionSettings(_ id: String) {
        guard let permission = SystemPermission(rawValue: id) else { return }
        SystemPermissionService.shared.openSystemSettings(for: permission)
    }

    @MainActor
    public static func toolPermissionOptions() -> [EpistemosOsaurusPolicyOption] {
        [
            EpistemosOsaurusPolicyOption(
                id: ToolPermissionPolicy.auto.rawValue,
                label: ToolPermissionPolicy.auto.displayName,
                detail: "Run automatically when requirements are satisfied."
            ),
            EpistemosOsaurusPolicyOption(
                id: ToolPermissionPolicy.ask.rawValue,
                label: ToolPermissionPolicy.ask.displayName,
                detail: "Ask before the tool runs."
            ),
            EpistemosOsaurusPolicyOption(
                id: ToolPermissionPolicy.deny.rawValue,
                label: ToolPermissionPolicy.deny.displayName,
                detail: "Block this tool."
            ),
        ]
    }

    @MainActor
    public static func toolPermissionRows(maxCount: Int = 18) -> [EpistemosOsaurusToolPermissionRow] {
        ToolRegistry.shared.listTools()
            .sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
            .prefix(maxCount)
            .map { entry in
                let info = ToolRegistry.shared.policyInfo(for: entry.name)
                let requirements = info?.requirements ?? []
                let systemNames = info?.systemPermissions.map(\.displayName) ?? []
                let nonSystemCount = requirements.count - systemNames.count
                var requirementParts: [String] = []
                if !systemNames.isEmpty {
                    requirementParts.append(systemNames.joined(separator: ", "))
                }
                if nonSystemCount > 0 {
                    requirementParts.append("\(nonSystemCount) tool grant\(nonSystemCount == 1 ? "" : "s")")
                }

                let missingSystemCount = info?.systemPermissionStates.values.filter { !$0 }.count ?? 0
                let missingGrantCount = info?.grantsByRequirement.values.filter { !$0 }.count ?? 0
                let effective = info?.effectivePolicy ?? .auto
                let defaultPolicy = info?.defaultPolicy ?? .auto

                return EpistemosOsaurusToolPermissionRow(
                    id: entry.name,
                    displayName: displayName(forToolName: entry.name),
                    description: entry.description,
                    defaultPolicyID: defaultPolicy.rawValue,
                    effectivePolicyID: effective.rawValue,
                    configuredPolicyID: info?.configuredPolicy?.rawValue,
                    requirementsLabel: requirementParts.isEmpty
                        ? "No extra grants"
                        : requirementParts.joined(separator: " + "),
                    missingGrantCount: missingSystemCount + missingGrantCount,
                    isDestructive: isDestructiveToolName(entry.name, defaultPolicy: defaultPolicy)
                )
            }
    }

    @MainActor
    public static func setToolPermissionPolicy(toolName: String, policyID: String) {
        guard let policy = ToolPermissionPolicy(rawValue: policyID) else { return }
        ToolRegistry.shared.setPolicy(policy, for: toolName)
    }

    @MainActor
    public static func resetToolPermissionPolicy(toolName: String) {
        ToolRegistry.shared.clearPolicy(for: toolName)
    }

    /// 0.33h — TOOL SECRETS (native, reachable from act): each loaded plugin's required
    /// credential specs + whether the secret is already stored in the Keychain for the act
    /// default agent. Read-only inventory so the act surface shows what credentials its tools
    /// need and which are configured — the native expression of Osaurus's ToolSecretsSheet.
    @MainActor
    public static func toolSecretRows() -> [EpistemosOsaurusToolSecretRow] {
        var rows: [EpistemosOsaurusToolSecretRow] = []
        for loaded in PluginManager.shared.plugins {
            let ext = loaded.plugin
            guard let specs = ext.manifest.secrets, !specs.isEmpty else { continue }
            let pluginId = ext.id
            let pluginName = ext.manifest.name ?? pluginId
            for spec in specs {
                let isSet = ToolSecretsKeychain.getSecret(
                    id: spec.id, for: pluginId, agentId: Agent.defaultId
                ) != nil
                rows.append(
                    EpistemosOsaurusToolSecretRow(
                        id: "\(pluginId).\(spec.id)",
                        pluginName: pluginName,
                        secretLabel: spec.label,
                        secretDescription: spec.description,
                        isSet: isSet
                    )
                )
            }
        }
        return rows
    }

    /// 0.33g — SKILLS catalog (native, reachable from act): the real `SkillManager` skill
    /// inventory (name, description, built-in vs plugin vs custom, enabled) so the act surface
    /// shows the full skill library natively instead of a bare count — the native expression
    /// of Osaurus's SkillsView.
    @MainActor
    public static func skillRows() -> [EpistemosOsaurusSkillRow] {
        SkillManager.shared.skills.map { skill in
            let source: String
            if skill.isBuiltIn {
                source = "Built-in"
            } else if skill.isFromPlugin {
                source = "Plugin"
            } else {
                source = "Custom"
            }
            return EpistemosOsaurusSkillRow(
                id: skill.id.uuidString,
                name: skill.name,
                detail: skill.description,
                sourceLabel: source,
                category: skill.category,
                enabled: skill.enabled
            )
        }
    }

    /// 0.33j — IDENTITY & STORAGE status (native, reachable from act): Osaurus identity presence
    /// (NEVER key material — presence only), recovery-mnemonic backup state, and saved chat-session
    /// count. The native expression of Osaurus's Identity + Storage surfaces for act.
    @MainActor
    public static func identityStorageStatus() -> EpistemosOsaurusIdentityStorageStatus {
        EpistemosOsaurusIdentityStorageStatus(
            identityConfigured: OsaurusIdentity.existsCached(),
            mnemonicBackedUp: MasterMnemonicStore.exists(),
            savedSessionCount: ChatSessionsManager.shared.sessions.count
        )
    }

    /// 0.33e — VOICE status (native, reachable from act): the real transcription / VAD / TTS
    /// state so the act surface shows its voice capabilities natively (composer mic already works;
    /// this surfaces the modes Osaurus's Voice tabs configure).
    @MainActor
    public static func voiceStatus() -> EpistemosOsaurusVoiceStatus {
        let svc = TranscriptionModeService.shared
        let stateLabel: String
        switch svc.state {
        case .idle: stateLabel = "Idle"
        case .starting: stateLabel = "Starting"
        case .transcribing: stateLabel = "Transcribing"
        case .stopping: stateLabel = "Stopping"
        case .error(let message): stateLabel = "Error: \(message)"
        }
        return EpistemosOsaurusVoiceStatus(
            transcriptionEnabled: svc.isEnabled,
            transcriptionStateLabel: stateLabel,
            vadEnabled: VADConfigurationStore.load().vadModeEnabled,
            ttsModelReady: TTSService.shared.isModelReady
        )
    }

    /// 0.33c — PLUGINS inventory (native, reachable from act): the real `PluginManager` loaded
    /// plugins with their tool/skill/route counts + secret/web capability flags — the native
    /// expression of Osaurus's PluginsView (was counts-only on the act surface).
    @MainActor
    public static func pluginRows() -> [EpistemosOsaurusPluginRow] {
        PluginManager.shared.plugins.map { loaded in
            let ext = loaded.plugin
            return EpistemosOsaurusPluginRow(
                id: ext.id,
                name: ext.manifest.name ?? ext.id,
                toolCount: loaded.tools.count,
                skillCount: loaded.skills.count,
                routeCount: loaded.routes.count,
                hasSecrets: (ext.manifest.secrets?.isEmpty == false),
                hasWeb: loaded.webConfig != nil
            )
        }
    }

    /// 0.33d — AGENTS inventory (native, reachable from act): the real `AgentManager` agents
    /// with each agent's effective model, tools/memory/autonomous state, and default/active
    /// markers — the native expression of Osaurus's AgentsView so the act surface shows what
    /// agents exist and how each is configured ("the agent was never the same").
    @MainActor
    public static func agentRows() -> [EpistemosOsaurusAgentRow] {
        let mgr = AgentManager.shared
        let activeId = mgr.activeAgentId
        return mgr.agents.map { agent in
            let model = mgr.effectiveModel(for: agent.id)
            let autonomous = mgr.effectiveAutonomousExec(for: agent.id)?.enabled == true
            return EpistemosOsaurusAgentRow(
                id: agent.id.uuidString,
                name: agent.name,
                modelLabel: (model?.isEmpty == false) ? model! : "Core default",
                toolsEnabled: agent.toolsEnabled,
                memoryEnabled: agent.memoryEnabled,
                autonomousEnabled: autonomous,
                isDefault: agent.id == Agent.defaultId,
                isActive: agent.id == activeId
            )
        }
    }

    @MainActor
    public static func installNativeToolPermissionPresenter(
        _ presenter: EpistemosOsaurusNativeToolPermissionPresenter?
    ) {
        EpistemosOsaurusNativePromptPresenterStore.toolPermissionPresenter = presenter
    }

    @MainActor
    public static func installNativeProviderCredentialPresenter(
        _ presenter: EpistemosOsaurusNativeProviderCredentialPresenter?
    ) {
        EpistemosOsaurusNativePromptPresenterStore.providerCredentialPresenter = presenter
    }

    @MainActor
    public static func installNativePairingPresenter(
        _ presenter: EpistemosOsaurusNativePairingPresenter?
    ) {
        EpistemosOsaurusNativePromptPresenterStore.pairingPresenter = presenter
    }

    @MainActor
    public static func registerNativePrivacyReviewPresenter(
        _ presenter: @escaping EpistemosOsaurusNativePrivacyReviewPresenter
    ) -> EpistemosOsaurusNativePrivacyReviewPresenterToken {
        let publicToken = EpistemosOsaurusNativePrivacyReviewPresenterToken()
        let serviceToken = PrivacyReviewService.shared.registerPresenter { state in
            Task { @MainActor in
                let request = EpistemosOsaurusNativePrivacyReviewRequest(
                    id: state.id,
                    sessionId: state.sessionId,
                    entities: state.entities.map(nativePrivacyEntity(from:)),
                    alwaysApprove: state.alwaysApprove
                )
                let decision = await presenter(request)
                resolvePrivacyReview(state, decision: decision)
            }
        }
        EpistemosOsaurusNativePromptPresenterStore.privacyReviewTokens[publicToken.id] = serviceToken
        return publicToken
    }

    @MainActor
    public static func unregisterNativePrivacyReviewPresenter(
        _ token: EpistemosOsaurusNativePrivacyReviewPresenterToken?
    ) {
        guard let token,
              let serviceToken = EpistemosOsaurusNativePromptPresenterStore.privacyReviewTokens.removeValue(forKey: token.id)
        else { return }
        PrivacyReviewService.shared.unregisterPresenter(serviceToken)
    }

    @MainActor
    public static func computerUsePolicyOptions() -> [EpistemosOsaurusPolicyOption] {
        AutonomyPreset.allCases.map { preset in
            EpistemosOsaurusPolicyOption(
                id: preset.rawValue,
                label: preset.displayLabel,
                detail: preset.detail
            )
        }
    }

    @MainActor
    public static func computerUsePolicySnapshot() -> EpistemosOsaurusComputerUsePolicySnapshot {
        let policy = ComputerUsePolicyStore.load()
        return EpistemosOsaurusComputerUsePolicySnapshot(
            globalPresetID: policy.globalPreset.rawValue,
            globalPresetLabel: policy.globalPreset.displayLabel,
            globalPresetDetail: policy.globalPreset.detail,
            allowlistedApps: policy.allowlist ?? [],
            perAppOverrideCount: policy.perApp.count
        )
    }

    @MainActor
    public static func setComputerUseGlobalPreset(_ rawValue: String) {
        guard let preset = AutonomyPreset(rawValue: rawValue) else { return }
        var policy = ComputerUsePolicyStore.load()
        guard policy.globalPreset != preset else { return }
        policy.globalPreset = preset
        ComputerUsePolicyStore.save(policy)
    }

    @MainActor
    public static func setComputerUseAllowlistedApps(_ apps: [String]) {
        var policy = ComputerUsePolicyStore.load()
        let normalized = apps
            .map(AutonomyPolicy.normalize)
            .filter { !$0.isEmpty }
        let unique = Array(Set(normalized)).sorted()
        policy.allowlist = unique.isEmpty ? nil : unique
        ComputerUsePolicyStore.save(policy)
    }

    @MainActor
    public static func providerRuntimeSnapshot() -> EpistemosOsaurusProviderRuntimeSnapshot {
        let remote = RemoteProviderManager.shared
        let remoteProviders = remote.configuration.providers
        let remoteStates = remote.providerStates
        let remoteConnected = remoteStates.values.filter(\.isConnected).count
        let remoteConnecting = remoteStates.values.filter(\.isConnecting).count
        let remoteErrors = remoteStates.values.filter { state in
            state.lastError?.isEmpty == false
        }.count
        let remoteModelCount = remoteStates.values.reduce(0) { partial, state in
            partial + state.discoveredModels.count
        }

        let mcp = MCPProviderManager.shared
        let mcpProviders = mcp.configuration.providers
        let mcpStates = mcp.providerStates
        let mcpConnected = mcpStates.values.filter(\.isConnected).count
        let mcpConnecting = mcpStates.values.filter(\.isConnecting).count
        let mcpErrors = mcpStates.values.filter { state in
            state.lastError?.isEmpty == false
        }.count
        let mcpAuthNeeded = mcpStates.values.filter(\.requiresAuth).count
        let mcpToolCount = mcpStates.values.reduce(0) { partial, state in
            partial + state.discoveredToolCount
        }

        return EpistemosOsaurusProviderRuntimeSnapshot(
            remoteProviderCount: remoteProviders.count,
            remoteEnabledCount: remoteProviders.filter(\.enabled).count,
            remoteConnectedCount: remoteConnected,
            remoteConnectingCount: remoteConnecting,
            remoteErrorCount: remoteErrors,
            remoteModelCount: remoteModelCount,
            osaurusRouterEnabled: remote.isOsaurusRouterEnabled,
            mcpProviderCount: mcpProviders.count,
            mcpEnabledCount: mcpProviders.filter(\.enabled).count,
            mcpConnectedCount: mcpConnected,
            mcpConnectingCount: mcpConnecting,
            mcpAuthNeededCount: mcpAuthNeeded,
            mcpErrorCount: mcpErrors,
            mcpDiscoveredToolCount: mcpToolCount
        )
    }

    @MainActor
    public static func setOsaurusRouterEnabled(_ enabled: Bool) {
        RemoteProviderManager.shared.setOsaurusRouterEnabled(enabled)
    }

    @MainActor
    public static func connectRemoteProviders() async {
        await RemoteProviderManager.shared.connectEnabledProviders()
    }

    @MainActor
    public static func disconnectRemoteProviders() {
        RemoteProviderManager.shared.disconnectAll()
    }

    @MainActor
    public static func connectMCPProviders() async {
        await MCPProviderManager.shared.connectEnabledProviders()
    }

    @MainActor
    public static func disconnectMCPProviders() {
        MCPProviderManager.shared.disconnectAll()
    }

    @MainActor
    public static func privacyFilterSnapshot() -> EpistemosOsaurusPrivacyFilterSnapshot {
        let configuration = PrivacyFilterStore.snapshot()
        let builtinCount = PrivacyFilterConfiguration.builtinPatternCategories.count
        let enabledBuiltinCount = PrivacyFilterConfiguration.builtinPatternCategories.filter {
            configuration.isBuiltinPatternEnabled($0)
        }.count

        return EpistemosOsaurusPrivacyFilterSnapshot(
            enabled: configuration.enabled,
            skipCodeBlocks: configuration.skipCodeBlocks,
            alwaysApproveByDefault: configuration.alwaysApproveByDefault,
            requireReviewForNonInteractive: configuration.requireReviewForNonInteractive,
            confidenceThreshold: configuration.confidenceThreshold,
            enabledBuiltinPatternCount: enabledBuiltinCount,
            builtinPatternCount: builtinCount,
            enabledPresetRuleCount: configuration.presetRules.values.filter { $0 }.count,
            customRuleCount: configuration.customRules.count
        )
    }

    @MainActor
    public static func setPrivacyFilterEnabled(_ enabled: Bool) {
        var configuration = PrivacyFilterStore.snapshot()
        guard configuration.enabled != enabled else { return }
        configuration.enabled = enabled
        PrivacyFilterStore.save(configuration)
    }

    @MainActor
    public static func setPrivacyFilterSkipCodeBlocks(_ enabled: Bool) {
        var configuration = PrivacyFilterStore.snapshot()
        guard configuration.skipCodeBlocks != enabled else { return }
        configuration.skipCodeBlocks = enabled
        PrivacyFilterStore.save(configuration)
    }

    @MainActor
    public static func setPrivacyFilterAlwaysApprove(_ enabled: Bool) {
        var configuration = PrivacyFilterStore.snapshot()
        guard configuration.alwaysApproveByDefault != enabled else { return }
        configuration.alwaysApproveByDefault = enabled
        PrivacyFilterStore.save(configuration)
    }

    @MainActor
    public static func setPrivacyFilterRequireInteractiveReview(_ enabled: Bool) {
        var configuration = PrivacyFilterStore.snapshot()
        guard configuration.requireReviewForNonInteractive != enabled else { return }
        configuration.requireReviewForNonInteractive = enabled
        PrivacyFilterStore.save(configuration)
    }

    @MainActor
    public static func setPrivacyFilterConfidenceThreshold(_ threshold: Float) {
        var configuration = PrivacyFilterStore.snapshot()
        let bounded = min(max(threshold, 0), 1)
        guard configuration.confidenceThreshold != bounded else { return }
        configuration.confidenceThreshold = bounded
        PrivacyFilterStore.save(configuration)
    }

    @MainActor
    public static func dependencySnapshot() -> EpistemosOsaurusDependencySnapshot {
        let recipes = SandboxPluginLibrary.shared.plugins
        let installed = SandboxPluginManager.shared.installedPlugins.values.flatMap { $0 }
        let readyCount = installed.filter { $0.status == .ready }.count
        let failedCount = installed.filter { $0.status == .failed }.count
        let installingCount = installed.filter { $0.status == .installing || $0.status == .uninstalling }.count

        return EpistemosOsaurusDependencySnapshot(
            sandboxPluginRecipeCount: recipes.count,
            dependencyRecipeCount: recipes.filter { $0.dependencies?.isEmpty == false }.count,
            installedPluginCount: installed.count,
            readyPluginCount: readyCount,
            failedPluginCount: failedCount,
            installingPluginCount: installingCount,
            activeInstallCount: SandboxPluginManager.shared.installProgress.count
        )
    }

    @MainActor
    @discardableResult
    public static func repairSandboxPluginDependencies() async -> String? {
        do {
            try await SandboxManager.shared.startContainer()
            await SandboxPluginManager.shared.verifyAndRepairAllPlugins()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    public static func currentModel() -> String? {
        AgentManager.shared.effectiveModel(for: Agent.defaultId)
    }

    @MainActor
    public static func currentModelDisplayName() async -> String? {
        guard let current = currentModel() else { return nil }
        let picks = await modelPicks()
        return picks.first(where: { $0.id == current })?.displayName ?? displayName(for: current)
    }

    @MainActor
    public static func setCurrentModel(_ id: String?) {
        AgentManager.shared.updateDefaultModel(for: Agent.defaultId, model: id)
    }

    @MainActor
    public static func modelPicks() async -> [EpistemosOsaurusModelPick] {
        var rows: [EpistemosOsaurusModelPick] = []
        var seen = Set<String>()

        // 0.33f: cheap pre-synced on-device map (no per-model file scan) so the act model
        // stack can show a real "On Device" badge.
        let downloadStates = await MainActor.run { ModelManager.shared.downloadService.downloadStates }
        let isDownloaded: (String) -> Bool = { downloadStates[$0] == .completed }

        for id in EpistemosModelBridge.providedModelIds() where seen.insert(id).inserted {
            rows.append(
                EpistemosOsaurusModelPick(
                    id: id,
                    displayName: displayName(for: id),
                    subtitle: "Epistemos Pick routed through Osaurus Act",
                    sectionTitle: "Epistemos Picks",
                    systemImage: "sparkles",
                    isDownloaded: isDownloaded(id)
                )
            )
        }

        let nativeItems = await ModelPickerItemCache.shared.buildModelPickerItems()
        for item in nativeItems where seen.insert(item.id).inserted {
            rows.append(
                EpistemosOsaurusModelPick(
                    id: item.id,
                    displayName: item.displayName,
                    subtitle: nativeSubtitle(for: item),
                    sectionTitle: "Osaurus Native",
                    systemImage: nativeSystemImage(for: item),
                    isDownloaded: isDownloaded(item.id),
                    contextLength: item.contextLength
                )
            )
        }

        return rows
    }

    private static func nativeSubtitle(for item: ModelPickerItem) -> String {
        var parts: [String] = [item.source.displayName]
        if let parameterCount = item.parameterCount, !parameterCount.isEmpty {
            parts.append(parameterCount)
        }
        if let quantization = item.quantization, !quantization.isEmpty {
            parts.append(quantization)
        }
        if item.isVLM {
            parts.append("Vision")
        }
        if let description = item.description, !description.isEmpty {
            parts.append(description)
        }
        return parts.joined(separator: " · ")
    }

    private static func nativeSystemImage(for item: ModelPickerItem) -> String {
        switch item.source {
        case .foundation:
            return "apple.intelligence"
        case .local:
            return "memorychip"
        case .remote:
            return "cloud"
        }
    }

    private static func quickAction(
        _ tab: ManagementTab,
        title: String,
        subtitle: String
    ) -> EpistemosOsaurusQuickAction {
        EpistemosOsaurusQuickAction(
            id: tab.rawValue,
            title: title,
            subtitle: subtitle,
            systemImage: tab.icon,
            managementTabID: tab.rawValue
        )
    }

    private static func displayName(for id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.lastIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: slashIndex)...])
    }

    private static func displayName(forToolName name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return "" }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func isDestructiveToolName(_ name: String, defaultPolicy: ToolPermissionPolicy) -> Bool {
        if defaultPolicy == .ask { return true }
        let lowered = name.lowercased()
        return lowered.contains("delete")
            || lowered.contains("remove")
            || lowered.contains("shell")
            || lowered.contains("exec")
            || lowered.contains("commit")
            || lowered.contains("write")
    }

    @MainActor
    private static func nativePrivacyEntity(
        from entity: DetectedEntity
    ) -> EpistemosOsaurusNativePrivacyReviewEntity {
        EpistemosOsaurusNativePrivacyReviewEntity(
            id: entity.id,
            categoryRawValue: entity.category.rawValue,
            original: entity.original,
            placeholderToken: entity.placeholder.token,
            containingText: entity.containingText,
            approved: entity.approved
        )
    }

    @MainActor
    private static func resolvePrivacyReview(
        _ state: RedactionReviewState,
        decision: EpistemosOsaurusNativePrivacyReviewDecision
    ) {
        switch decision {
        case .approved(let rows, let alwaysApprove):
            let approvals = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.approved) })
            for entity in state.entities {
                if let approved = approvals[entity.id] {
                    state.setApproval(entity, to: approved)
                }
            }
            state.alwaysApprove = alwaysApprove
            state.confirm()
        case .canceled:
            state.cancel()
        }
    }
}
