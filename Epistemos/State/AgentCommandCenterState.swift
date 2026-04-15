import Foundation
import Observation
import os

// MARK: - Agent Command Center State
// Central @Observable state object for the Agent Command Center overlay.
// Manages presentation lifecycle, unified slash/skill parsing, brain/model selection,
// tool/MCP capability toggles, skill discovery, context providers, and inspector panel state.
// This state is SEPARATE from ChatState — the Agent home is a dedicated surface.

@MainActor @Observable
final class AgentCommandCenterState {
    typealias ToolCatalogLoader = @MainActor (_ vaultPath: String, _ operatingMode: EpistemosOperatingMode) -> [OmegaToolDefinition]

    private let log = Logger(subsystem: "com.epistemos", category: "AgentCommandCenter")
    @ObservationIgnored private let toolCatalogLoader: ToolCatalogLoader
    @ObservationIgnored private var catalogVaultPath: String = ""

    // MARK: - Presentation

    var isPresented: Bool = false

    func present() {
        guard !isPresented else { return }
        isPresented = true
        refreshCatalogs()
        log.info("[ACC] Presented")
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        suggestionMenuState = .hidden
        log.info("[ACC] Dismissed")
    }

    // MARK: - Input & Parsed State

    var inputText: String = "" {
        didSet { scheduleInputParse() }
    }

    /// The resolved slash token — either a builtin mode/command or a discovered skill.
    var activeSlashToken: ParsedSlashToken? = nil

    /// Resolved @-mention attachments.
    var activeMentions: [ACCContextMention] = []

    /// Current suggestion dropdown state.
    var suggestionMenuState: ACCSuggestionMenuState = .hidden

    /// Index of the currently highlighted suggestion (keyboard navigation).
    var highlightedSuggestionIndex: Int = 0

    // MARK: - Operating Mode

    /// Start in a middle lane: capable, but not full destructive-agent scope.
    /// The user can explicitly choose Agent when they want the full tier.
    var selectedOperatingMode: EpistemosOperatingMode = .pro {
        didSet {
            rebuildToolCatalog()
        }
    }

    /// Visual density for the command center. This changes presentation only;
    /// execution policy still comes from `selectedOperatingMode`.
    var presentationMode: ACCPresentationMode = .standard

    /// Provider-native reasoning/search effort for runtimes that expose it.
    /// This is separate from `selectedOperatingMode`: Fast/Thinking/Pro/Agent
    /// controls Epistemos routing and permissions, while this controls the
    /// selected provider's own budget knob when the runtime supports one.
    var nativeProviderEffort: ACCNativeProviderEffort = .medium

    // MARK: - Brain / Model Selection (registry-backed)

    /// Explicit brain override. nil = auto-route via TriageService.
    var selectedBrain: ACCBrainSelection? = nil

    var supportedNativeProviderEfforts: [ACCNativeProviderEffort] {
        selectedBrain?.supportedNativeProviderEfforts ?? []
    }

    var selectedNativeProviderEffort: ACCNativeProviderEffort? {
        supportedNativeProviderEfforts.contains(nativeProviderEffort) ? nativeProviderEffort : nil
    }

    /// All available brains, populated from InferenceState + cloud providers.
    var availableBrains: [ACCBrainSelection] = []

    // MARK: - Tool & MCP Toggles (registry-backed)

    /// Per-tool enabled/disabled state. Key = tool name from OmegaToolRegistry.
    var toolToggles: [String: Bool] = [:]

    /// Active tool catalog for the current operating mode, derived from the
    /// Rust `ToolRegistry` through the tier bridge.
    var availableTools: [OmegaToolDefinition] = []

    /// Tool count from the Rust dispatcher.
    var mcpToolCount: Int = 0

    /// Execution count from the Rust dispatcher.
    var mcpExecutionCount: Int = 0

    /// Tools grouped by agent name for the inspector Capabilities tab.
    var mcpToolsByAgent: [String: [OmegaToolDefinition]] = [:]

    /// Set of currently enabled tool names — convenience for submission.
    var enabledToolNames: Set<String> {
        Set(toolToggles.filter(\.value).map(\.key))
    }

    // MARK: - Skill Discovery (registry-backed)

    /// Skills discovered from the filesystem via SkillDiscoveryCatalog.
    var availableSkills: [SkillDiscoveryEntry] = []

    // MARK: - Context Providers (registry for @ suggestions)

    /// Known @-mention targets: agents, vault tokens, open notes, folders.
    var contextProviders: [ACCContextProvider] = []

    // MARK: - Inspector Panel

    var inspectorState: ACCInspectorPanelState = .expanded(.capabilities)

    /// Authoritative runtime diagnostics for the inspector — populated only by
    /// the CommandCenterRequestCompiler (at compile time) and the Rust streaming
    /// delegate (during execution). The inspector reads these fields; it must not
    /// infer execution truth from local UI state.
    var diagnostics: CommandCenterExecutionDiagnostics = CommandCenterExecutionDiagnostics()

    // MARK: - Debouncing (50ms anti-cascade)

    @ObservationIgnored
    private var parseDebounceTask: Task<Void, Never>?

    init(toolCatalogLoader: @escaping ToolCatalogLoader = AgentCommandCenterState.defaultToolCatalogLoader) {
        self.toolCatalogLoader = toolCatalogLoader
    }

    private func scheduleInputParse() {
        parseDebounceTask?.cancel()
        parseDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self else { return }
            let result = CommandInputParser.parse(
                self.inputText,
                availableSkills: self.availableSkills,
                contextProviders: self.contextProviders
            )
            self.activeSlashToken = result.slashToken
            self.activeMentions = result.mentions
            self.suggestionMenuState = result.suggestionState
            self.highlightedSuggestionIndex = 0
        }
    }

    // MARK: - Tool Toggle

    func toggleTool(_ name: String) {
        toolToggles[name]?.toggle()
    }

    func enableAllTools() {
        for key in toolToggles.keys {
            toolToggles[key] = true
        }
    }

    func disableAllTools() {
        for key in toolToggles.keys {
            toolToggles[key] = false
        }
    }

    // MARK: - Catalog Refresh

    func refreshToolCatalog(from mcpBridge: MCPBridge, vaultPath: String) {
        catalogVaultPath = vaultPath
        mcpToolCount = mcpBridge.toolCount
        mcpExecutionCount = mcpBridge.executionCount
        rebuildToolCatalog()
        log.info("[ACC] Tool catalog refreshed: \(self.mcpToolCount) tools, \(self.mcpExecutionCount) executions")
    }

    func refreshSkillCatalog() {
        availableSkills = SkillDiscoveryCatalog.discoverSkillEntries()
        log.info("[ACC] Skill catalog refreshed: \(self.availableSkills.count) skills")
    }

    func refreshBrainCatalog(from inference: InferenceState) {
        var brains: [ACCBrainSelection] = []

        // Local models — only installed ones
        for modelId in LocalTextModelID.allCases where inference.installedLocalTextModelIDs.contains(modelId.rawValue) {
            brains.append(.local(
                modelId: modelId.rawValue,
                displayName: modelId.compactDisplayName,
                supportsThinking: modelId.supportsThinkingMode,
                supportsVision: modelId.supportsVision,
                supportsTools: modelId.supportsNativeToolCalling
            ))
        }

        // Apple Intelligence
        brains.append(.appleIntelligence)

        // Cloud providers with configured keys
        for provider in CloudModelProvider.allCases {
            if inference.configuredCloudProviders.contains(provider) {
                brains.append(.cloud(provider: provider))
            }
        }

        availableBrains = brains
        log.info("[ACC] Brain catalog refreshed: \(brains.count) brains")
    }

    func refreshContextProviders(vaultNoteCount: Int, openNoteTitles: [String]) {
        var providers: [ACCContextProvider] = []

        // Built-in agents
        let agents: [(String, String)] = [
            ("Safari", "safari"), ("Terminal", "terminal"),
            ("Notes", "notes"), ("Files", "file"), ("Automation", "automation"),
        ]
        for (token, id) in agents {
            providers.append(ACCContextProvider(id: "agent:\(id)", token: token, category: .agent))
        }

        // Vault-level tokens
        providers.append(ACCContextProvider(id: "vault:all", token: "AllNotes", category: .vault))
        providers.append(ACCContextProvider(id: "vault:graph", token: "CurrentGraph", category: .graph))

        // Open notes
        for title in openNoteTitles {
            providers.append(ACCContextProvider(id: "note:\(title)", token: title, category: .openNote))
        }

        contextProviders = providers
    }

    /// Refresh all catalogs at once (called on present()).
    private func refreshCatalogs() {
        refreshSkillCatalog()
        // Brain and tool catalogs require external state — those are refreshed
        // by AppBootstrap when the command center is presented.
    }

    private func rebuildToolCatalog() {
        let tools = toolCatalogLoader(catalogVaultPath, selectedOperatingMode)
        let previousToggles = toolToggles
        availableTools = tools
        toolToggles = Dictionary(
            uniqueKeysWithValues: tools.map { tool in
                (tool.name, previousToggles[tool.name] ?? true)
            }
        )
        mcpToolsByAgent = Dictionary(grouping: tools, by: \.agent)
    }

    private static func defaultToolCatalogLoader(
        vaultPath: String,
        operatingMode: EpistemosOperatingMode
    ) -> [OmegaToolDefinition] {
        let tier = ChatToolTier.from(operatingMode: operatingMode)
        return ToolTierBridge(vaultPath: vaultPath, tier: tier).loadTools()
    }

    // MARK: - Submission

    /// Build a normalized command request from the current state.
    func buildCommandRequest() -> ACCCommandRequest {
        let cleanedQuery = CommandInputParser.parse(
            inputText,
            availableSkills: availableSkills,
            contextProviders: contextProviders
        ).cleanedQuery

        return ACCCommandRequest(
            query: cleanedQuery,
            slashToken: activeSlashToken,
            mentions: activeMentions,
            enabledToolNames: enabledToolNames,
            brainOverride: selectedBrain,
            operatingMode: selectedOperatingMode
        )
    }

    /// Reset input state after submission.
    func clearInput() {
        inputText = ""
        activeSlashToken = nil
        activeMentions = []
        suggestionMenuState = .hidden
        highlightedSuggestionIndex = 0
    }
}

// MARK: - Supporting Types

/// Unified slash token — either a builtin mode/command or a discovered skill.
enum ParsedSlashToken: Equatable, Hashable {
    case builtinMode(ACCSlashCommand)
    case skill(SkillDiscoveryEntry)

    var displayName: String {
        switch self {
        case .builtinMode(let cmd): cmd.displayName
        case .skill(let entry): entry.title
        }
    }

    var icon: String {
        switch self {
        case .builtinMode(let cmd): cmd.icon
        case .skill: "wand.and.stars"
        }
    }
}

/// Built-in slash commands for modes and common operations.
enum ACCSlashCommand: String, CaseIterable, Identifiable, Hashable {
    case ask
    case debug
    case plan
    case research
    case review
    case summarize
    case readBranch = "read-branch"
    case explain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ask: "Ask"
        case .debug: "Debug"
        case .plan: "Plan"
        case .research: "Research"
        case .review: "Review"
        case .summarize: "Summarize"
        case .readBranch: "Read Branch"
        case .explain: "Explain"
        }
    }

    var icon: String {
        switch self {
        case .ask: "questionmark.circle"
        case .debug: "ladybug"
        case .plan: "list.bullet.clipboard"
        case .research: "magnifyingglass"
        case .review: "eye"
        case .summarize: "doc.text.magnifyingglass"
        case .readBranch: "arrow.triangle.branch"
        case .explain: "lightbulb"
        }
    }

    var defaultOperatingMode: EpistemosOperatingMode {
        switch self {
        case .ask: .fast
        case .debug: .thinking
        case .plan: .agent
        case .research: .pro
        case .review: .thinking
        case .summarize: .fast
        case .readBranch: .fast
        case .explain: .fast
        }
    }

    var helpText: String {
        switch self {
        case .ask: "Quick conversational answer"
        case .debug: "Deep analysis with reasoning trace"
        case .plan: "Multi-step agent task planning"
        case .research: "Thorough research with multiple sources"
        case .review: "Review and critique content"
        case .summarize: "Condense content to key points"
        case .readBranch: "Read and understand a code branch"
        case .explain: "Explain a concept clearly"
        }
    }
}

/// Resolved @-mention in the command bar.
struct ACCContextMention: Identifiable, Hashable, Sendable {
    let id: String
    let token: String
    let resolvedLabel: String
    let mentionType: MentionType

    nonisolated enum MentionType: String, Sendable, Hashable {
        case agent, vault, folder, graph, skill, openNote, custom
    }
}

/// State of the suggestion dropdown.
enum ACCSuggestionMenuState: Equatable {
    case hidden
    case slashMenu(filter: String)       // Unified: modes + commands + skills
    case contextMentions(filter: String) // @mentions
    case brains(filter: String)          // Brain picker typeahead
}

/// Presentation density for the command center shell.
enum ACCPresentationMode: String, CaseIterable, Identifiable, Hashable {
    case compact
    case standard
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .advanced: "Advanced"
        }
    }

    var detail: String {
        switch self {
        case .compact: "Input and transcript only"
        case .standard: "Simple default controls"
        case .advanced: "Inspector and terminal rail"
        }
    }

    var icon: String {
        switch self {
        case .compact: "rectangle.compress.vertical"
        case .standard: "rectangle.split.1x2"
        case .advanced: "sidebar.right"
        }
    }
}

/// Provider-native effort values surfaced only for runtimes that consume them.
/// OpenAI/Codex `xhigh` is intentionally not listed here until the Command
/// Center path uses the Responses/Codex runtime that can honor it.
enum ACCNativeProviderEffort: String, CaseIterable, Identifiable, Hashable {
    case low
    case medium
    case high
    case max

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .max: "Max"
        }
    }

    var detail: String {
        switch self {
        case .low: "Lowest native reasoning budget"
        case .medium: "Balanced native reasoning"
        case .high: "Deeper native reasoning"
        case .max: "Maximum native reasoning budget"
        }
    }

    var rustValue: String { rawValue }
}

/// Brain/model selection in the command center.
enum ACCBrainSelection: Hashable, Identifiable {
    case local(modelId: String, displayName: String, supportsThinking: Bool, supportsVision: Bool, supportsTools: Bool)
    case appleIntelligence
    case cloud(provider: CloudModelProvider)

    var id: String {
        switch self {
        case .local(let modelId, _, _, _, _): "local:\(modelId)"
        case .appleIntelligence: "apple"
        case .cloud(let provider): "cloud:\(provider.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .local(_, let name, _, _, _): name
        case .appleIntelligence: "Apple Intelligence"
        case .cloud(let provider): provider.displayName
        }
    }

    var icon: String {
        switch self {
        case .local: "memorychip"
        case .appleIntelligence: "apple.logo"
        case .cloud: "cloud"
        }
    }

    var supportedNativeProviderEfforts: [ACCNativeProviderEffort] {
        switch self {
        case .cloud(.anthropic), .cloud(.google):
            ACCNativeProviderEffort.allCases
        case .local, .appleIntelligence, .cloud:
            []
        }
    }
}

/// Known @-mention context providers for the suggestion dropdown.
struct ACCContextProvider: Identifiable, Hashable, Sendable {
    let id: String
    let token: String
    let category: Category

    nonisolated enum Category: String, Sendable, Hashable {
        case agent, vault, folder, graph, openNote
    }

    var icon: String {
        switch category {
        case .agent: "person.crop.rectangle"
        case .vault: "tray.full"
        case .folder: "folder"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .openNote: "doc.text"
        }
    }
}

/// Inspector panel collapse/expand state.
enum ACCInspectorPanelState: Equatable {
    case collapsed
    case expanded(ACCInspectorTab)
}

/// Inspector panel tabs.
enum ACCInspectorTab: String, CaseIterable, Identifiable {
    case context
    case capabilities
    case plan
    case execution
    case hierarchy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .context: "Context"
        case .capabilities: "Capabilities"
        case .plan: "Plan"
        case .execution: "Execution"
        case .hierarchy: "Hierarchy"
        }
    }

    var icon: String {
        switch self {
        case .context: "doc.text.below.ecg"
        case .capabilities: "wrench.and.screwdriver"
        case .plan: "list.bullet.clipboard"
        case .execution: "play.circle"
        case .hierarchy: "point.3.connected.trianglepath.dotted"
        }
    }
}

/// Record of a single tool execution for the inspector history.
struct ACCToolExecutionRecord: Identifiable {
    let id: String
    let toolName: String
    let inputSummary: String
    let resultSummary: String
    let durationMs: UInt64
    let isError: Bool
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        toolName: String,
        inputSummary: String,
        resultSummary: String,
        durationMs: UInt64,
        isError: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.inputSummary = inputSummary
        self.resultSummary = resultSummary
        self.durationMs = durationMs
        self.isError = isError
        self.timestamp = timestamp
    }
}

/// Normalized command request ready for submission to ChatCoordinator.
struct ACCCommandRequest {
    let query: String
    let slashToken: ParsedSlashToken?
    let mentions: [ACCContextMention]
    let enabledToolNames: Set<String>
    let brainOverride: ACCBrainSelection?
    let operatingMode: EpistemosOperatingMode
}
