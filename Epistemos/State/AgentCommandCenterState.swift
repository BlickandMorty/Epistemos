import Foundation
import Observation
import os

// MARK: - Agent Command Center State
// Central @Observable state object for the legacy Agent Command Center overlay.
// Manages presentation lifecycle, unified slash/skill parsing, brain/model selection,
// tool/MCP capability toggles, skill discovery, context providers, and inspector panel state.
// Fused main chat is the live user surface; this state remains for compat paths,
// diagnostics, and the dormant dedicated workspace.

@MainActor @Observable
final class AgentCommandCenterState {
    typealias ToolCatalogLoader = @MainActor (_ vaultPath: String, _ operatingMode: EpistemosOperatingMode) -> [OmegaToolDefinition]

    private let log = Logger(subsystem: "com.epistemos", category: "AgentCommandCenter")
    @ObservationIgnored private let toolCatalogLoader: ToolCatalogLoader
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var catalogVaultPath: String = ""
    @ObservationIgnored private var isApplyingSpecialistConfiguration = false

    private enum PersistenceKey {
        static let activeSpecialistPreset = "epistemos.agent.specialist.active"
        static let specialistBrainPrefix = "epistemos.agent.specialist.brain."
    }

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

    /// Persistent specialist preset. Unlike the transient slash token, this
    /// survives submissions so the agent page behaves like a purpose-built
    /// harness rather than a one-off command shortcut.
    var activeSpecialistPreset: ACCSlashCommand? = nil {
        didSet {
            guard !isApplyingSpecialistConfiguration else { return }
            persistActiveSpecialistPreset()
        }
    }

    // MARK: - Operating Mode

    /// Start in a middle lane: capable, but not full destructive-agent scope.
    /// The user can explicitly choose Agent when they want the full tier.
    var selectedOperatingMode: EpistemosOperatingMode = .pro {
        didSet {
            let sanitizedMode = sanitizedOperatingMode(selectedOperatingMode)
            guard sanitizedMode == selectedOperatingMode else {
                selectedOperatingMode = sanitizedMode
                return
            }
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
    var selectedBrain: ACCBrainSelection? = nil {
        didSet {
            let sanitizedMode = sanitizedOperatingMode(selectedOperatingMode)
            if sanitizedMode != selectedOperatingMode {
                selectedOperatingMode = sanitizedMode
            }
            guard !isApplyingSpecialistConfiguration else { return }
            persistSelectedBrainForActiveSpecialist()
        }
    }

    var availableOperatingModes: [EpistemosOperatingMode] {
        selectedBrain?.supportedOperatingModes ?? EpistemosOperatingMode.allCases
    }

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

    var harnessHeadline: String? {
        activeSpecialistPreset?.displayName
    }

    var harnessFocusLine: String? {
        activeSpecialistPreset?.focusSummary
    }

    var harnessPostureLine: String? {
        guard let preset = activeSpecialistPreset else { return nil }
        let toolCount = enabledToolNames.count
        let toolSummary = toolCount == 1 ? "1 tool enabled" : "\(toolCount) tools enabled"
        return "\(preset.postureSummary) · \(preset.brainPreferenceSummary) · \(toolSummary)"
    }

    // MARK: - Skill Discovery (registry-backed)

    /// Skills discovered from the filesystem via SkillDiscoveryCatalog.
    var availableSkills: [SkillDiscoveryEntry] = []

    // MARK: - Context Providers (registry for @ suggestions)

    /// Known @-mention targets: agents, vault tokens, open notes, folders.
    var contextProviders: [ACCContextProvider] = []

    // MARK: - Inspector Panel

    /// Default collapsed so the agent page reads as a chat, not a dashboard.
    /// The plan/execution inspector only appears on explicit user request
    /// (toolbar toggle) or when the request compiler / streaming delegate
    /// surfaces real plan/tool activity worth showing.
    var inspectorState: ACCInspectorPanelState = .collapsed

    /// Authoritative runtime diagnostics for the inspector — populated only by
    /// the CommandCenterRequestCompiler (at compile time) and the Rust streaming
    /// delegate (during execution). The inspector reads these fields; it must not
    /// infer execution truth from local UI state.
    var diagnostics: CommandCenterExecutionDiagnostics = CommandCenterExecutionDiagnostics()

    // MARK: - Debouncing (50ms anti-cascade)

    @ObservationIgnored
    private var parseDebounceTask: Task<Void, Never>?

    init(
        toolCatalogLoader: @escaping ToolCatalogLoader = AgentCommandCenterState.defaultToolCatalogLoader,
        userDefaults: UserDefaults = .standard
    ) {
        self.toolCatalogLoader = toolCatalogLoader
        self.userDefaults = userDefaults

        if let rawValue = userDefaults.string(forKey: PersistenceKey.activeSpecialistPreset),
           let preset = ACCSlashCommand(rawValue: rawValue) {
            activeSpecialistPreset = preset
            selectedOperatingMode = preset.defaultOperatingMode
        }
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
            self.syncSpecialistPreset(with: result.slashToken)
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

        // Local models — only installed, release-validated interactive
        // chat tiers. Preview-gated families like Gemma 4 should never
        // surface here because ACC submits real interactive turns.
        for modelId in LocalTextModelID.allCases where inference.installedLocalTextModelIDs.contains(modelId.rawValue) {
            guard modelId.isReleaseValidatedForInteractiveChat else { continue }
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
        if let selectedBrain, !brains.contains(selectedBrain) {
            withSpecialistConfigurationMutation {
                self.selectedBrain = nil
            }
        }
        if activeSpecialistPreset != nil {
            reapplyActiveSpecialistConfiguration()
        }
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
        if let preset = activeSpecialistPreset {
            applySpecialistToolBundle(for: preset)
        }
    }

    private static func defaultToolCatalogLoader(
        vaultPath: String,
        operatingMode: EpistemosOperatingMode
    ) -> [OmegaToolDefinition] {
        let tier = ChatToolTier.from(operatingMode: operatingMode)
        return ToolTierBridge(vaultPath: vaultPath, tier: tier).loadTools()
    }

    // MARK: - Graph Chat Receiver

    @ObservationIgnored
    private var graphChatObserver: (any NSObjectProtocol)?

    /// Begin listening for `.graphChatRequested` notifications posted by
    /// `GraphState.askGraphChat(nodeId:)`. On receipt the command center
    /// presents itself and prefills the input with a contextual query
    /// about the graph node. This is an intent receiver, not a second
    /// control plane — Rust still owns execution once the user submits.
    func startObservingGraphChatRequests() {
        if graphChatObserver != nil {
            stopObservingGraphChatRequests()
        }
        graphChatObserver = NotificationCenter.default.addObserver(
            forName: .graphChatRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let request = GraphChatRequest.fromNotification(notification) else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleGraphChatRequest(request)
            }
        }
    }

    func stopObservingGraphChatRequests() {
        if let observer = graphChatObserver {
            NotificationCenter.default.removeObserver(observer)
            graphChatObserver = nil
        }
    }

    /// Prefill the legacy command state with context from a graph node and
    /// hand the request off to the fused main chat. The structured graph
    /// request is still retained here so any dormant compat callers that
    /// compile ACC requests keep the same payload shape.
    func handleGraphChatRequest(_ request: GraphChatRequest) {
        let label = request.nodeLabel.isEmpty ? request.nodeType : request.nodeLabel
        inputText = "Tell me about \(label)"

        pendingGraphChatRequest = request
        AppBootstrap.shared?.routeGraphChatRequestIntoMainChat(request)

        log.info("[ACC] Graph chat request received for node \(request.graphNodeId, privacy: .public) type=\(request.nodeType, privacy: .public)")
    }

    /// The most recent graph chat request, available for receivers that
    /// need to attach graph context to the compiled command.
    var pendingGraphChatRequest: GraphChatRequest?

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
            operatingMode: selectedOperatingMode,
            graphContext: pendingGraphChatRequest
        )
    }

    /// Reset input state after submission.
    func clearInput() {
        inputText = ""
        activeSlashToken = nil
        activeMentions = []
        pendingGraphChatRequest = nil
        suggestionMenuState = .hidden
        highlightedSuggestionIndex = 0
    }

    /// Seed the agent composer with a string and synchronously mirror the
    /// parsed slash/mention state so callers can submit immediately without
    /// waiting for the debounce loop.
    func primeInput(_ text: String) {
        inputText = text

        let result = CommandInputParser.parse(
            text,
            availableSkills: availableSkills,
            contextProviders: contextProviders
        )
        activeSlashToken = result.slashToken
        activeMentions = result.mentions
        suggestionMenuState = result.suggestionState
        highlightedSuggestionIndex = 0
        syncSpecialistPreset(with: result.slashToken)
    }

    func applySpecialist(_ command: ACCSlashCommand) {
        withSpecialistConfigurationMutation {
            activeSpecialistPreset = command
            activeSlashToken = .builtinMode(command)
            selectedBrain = preferredBrain(for: command)
            selectedOperatingMode = command.defaultOperatingMode
            applySpecialistToolBundle(for: command)
        }
        persistActiveSpecialistPreset()
        persistSelectedBrainForActiveSpecialist()
    }

    func clearSpecialistPreset() {
        withSpecialistConfigurationMutation {
            activeSpecialistPreset = nil
        }
        persistActiveSpecialistPreset()
    }

    private func sanitizedOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard availableOperatingModes.contains(mode) else {
            return availableOperatingModes.first ?? .fast
        }
        return mode
    }

    private func rebuildSpecialistToolToggles(for command: ACCSlashCommand) {
        var nextToggles: [String: Bool] = [:]
        for tool in availableTools {
            nextToggles[tool.name] = command.preferredToolNames.contains(tool.name)
        }
        if nextToggles.values.contains(true) {
            toolToggles = nextToggles
        }
    }

    private func applySpecialistToolBundle(for command: ACCSlashCommand) {
        guard !availableTools.isEmpty else { return }
        rebuildSpecialistToolToggles(for: command)
    }

    private func reapplyActiveSpecialistConfiguration() {
        guard let preset = activeSpecialistPreset else { return }
        withSpecialistConfigurationMutation {
            if let preferred = preferredBrain(for: preset) {
                selectedBrain = preferred
            }
            selectedOperatingMode = sanitizedOperatingMode(preset.defaultOperatingMode)
            applySpecialistToolBundle(for: preset)
        }
    }

    private func syncSpecialistPreset(with token: ParsedSlashToken?) {
        guard case .builtinMode(let command) = token else { return }
        applySpecialist(command)
    }

    private func preferredBrain(for command: ACCSlashCommand) -> ACCBrainSelection? {
        if let stored = storedBrainSelection(for: command) {
            return stored
        }
        return recommendedBrain(for: command)
    }

    private func recommendedBrain(for command: ACCSlashCommand) -> ACCBrainSelection? {
        switch command {
        case .notes:
            return localBrain(preferredModels: [.deepseekR1Distill7B, .qwen3_4B4Bit, .bonsai8B2Bit])
                ?? cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? availableBrains.first
        case .code:
            return localBrain(preferredModels: [.qwen36_35BA3B4Bit, .deepseekR1Distill7B])
                ?? cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? availableBrains.first
        case .debug:
            return localBrain(preferredModels: [.deepseekR1Distill7B, .qwen36_35BA3B4Bit])
                ?? cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? availableBrains.first
        case .plan, .review:
            return localBrain(preferredModels: [.deepseekR1Distill7B, .qwen3_4B4Bit, .qwen36_35BA3B4Bit])
                ?? cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? availableBrains.first
        case .research, .securityReview:
            return cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? localBrain(preferredModels: [.deepseekR1Distill7B, .qwen36_35BA3B4Bit])
                ?? availableBrains.first
        case .ask, .summarize, .explain, .readBranch:
            return localBrain(preferredModels: [.qwen3_4B4Bit, .bonsai4B2Bit, .bonsai8B2Bit, .deepseekR1Distill7B])
                ?? cloudBrain(preferredProviders: [.openAI, .anthropic, .google])
                ?? availableBrains.first
        case .image:
            // Image gen runs through the `image_generate` tool, not a
            // chat brain. Return nil so the picker defers to whichever
            // brain the user was already using; the tool call itself
            // doesn't care which model the outer agent is.
            return nil
        }
    }

    private func localBrain(preferredModels: [LocalTextModelID]) -> ACCBrainSelection? {
        for model in preferredModels {
            if let match = availableBrains.first(where: { $0.matches(localModel: model) }) {
                return match
            }
        }
        return availableBrains.first(where: \.isLocal)
    }

    private func cloudBrain(preferredProviders: [CloudModelProvider]) -> ACCBrainSelection? {
        for provider in preferredProviders {
            if let match = availableBrains.first(where: { $0.matches(cloudProvider: provider) }) {
                return match
            }
        }
        return availableBrains.first(where: \.isCloud)
    }

    private func storedBrainSelection(for command: ACCSlashCommand) -> ACCBrainSelection? {
        let key = PersistenceKey.specialistBrainPrefix + command.rawValue
        guard let storedID = userDefaults.string(forKey: key), storedID != "auto" else {
            return nil
        }
        return availableBrains.first(where: { $0.id == storedID })
    }

    private func persistActiveSpecialistPreset() {
        let key = PersistenceKey.activeSpecialistPreset
        if let preset = activeSpecialistPreset {
            userDefaults.set(preset.rawValue, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func persistSelectedBrainForActiveSpecialist() {
        guard let preset = activeSpecialistPreset else { return }
        guard !availableBrains.isEmpty else { return }
        let key = PersistenceKey.specialistBrainPrefix + preset.rawValue
        if let selectedBrain {
            userDefaults.set(selectedBrain.id, forKey: key)
        } else {
            userDefaults.set("auto", forKey: key)
        }
    }

    private func withSpecialistConfigurationMutation(_ updates: () -> Void) {
        let previous = isApplyingSpecialistConfiguration
        isApplyingSpecialistConfiguration = true
        updates()
        isApplyingSpecialistConfiguration = previous
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
    case notes
    case code
    case debug
    case plan
    case research
    case review
    case securityReview = "security-review"
    case summarize
    case readBranch = "read-branch"
    case explain
    /// Generate an image via the `image_generate` tool — MLX-first
    /// (Apple-native Flux pipeline) with Fal as an explicit cloud
    /// opt-in. Routes through Agent mode so the generated image card
    /// renders inline.
    case image

    var id: String { rawValue }

    static let featuredAgentQuickActions: [ACCSlashCommand] = [
        .plan, .notes, .code, .debug, .research, .securityReview,
    ]

    static func availableCommands(for availableOperatingModes: [EpistemosOperatingMode]) -> [ACCSlashCommand] {
        let availableModes = Set(availableOperatingModes)
        return allCases.filter { $0.isAvailable(for: availableModes) }
    }

    var displayName: String {
        switch self {
        case .ask: "Ask"
        case .notes: "Notes"
        case .code: "Code"
        case .debug: "Debug"
        case .plan: "Plan"
        case .research: "Research"
        case .review: "Review"
        case .securityReview: "Security Review"
        case .summarize: "Summarize"
        case .readBranch: "Read Branch"
        case .explain: "Explain"
        case .image: "Image"
        }
    }

    var icon: String {
        switch self {
        case .ask: "questionmark.circle"
        case .notes: "book.closed"
        case .code: "hammer"
        case .debug: "ladybug"
        case .plan: "list.bullet.clipboard"
        case .research: "magnifyingglass"
        case .review: "eye"
        case .securityReview: "lock.shield"
        case .summarize: "doc.text.magnifyingglass"
        case .readBranch: "arrow.triangle.branch"
        case .explain: "lightbulb"
        case .image: "photo"
        }
    }

    var defaultOperatingMode: EpistemosOperatingMode {
        switch self {
        case .ask: .fast
        case .notes: .agent
        case .code: .agent
        case .debug: .thinking
        case .plan: .agent
        case .research: .pro
        case .review: .thinking
        case .securityReview: .pro
        case .summarize: .fast
        case .readBranch: .fast
        case .explain: .fast
        case .image: .agent
        }
    }

    func isAvailable(for availableOperatingModes: Set<EpistemosOperatingMode>) -> Bool {
        availableOperatingModes.contains(defaultOperatingMode)
    }

    var helpText: String {
        switch self {
        case .ask: "Quick conversational answer"
        case .notes: "Work with notes and folders"
        case .code: "Make focused repo changes"
        case .debug: "Trace failures from logs and repros"
        case .plan: "Break work into steps"
        case .research: "Use notes plus cited sources"
        case .review: "Read-only critique"
        case .securityReview: "Audit code and config"
        case .summarize: "Condense content to key points"
        case .readBranch: "Read and understand a code branch"
        case .explain: "Explain a concept clearly"
        case .image: "Generate an image"
        }
    }

    var focusSummary: String {
        switch self {
        case .ask:
            "Fast note-aware help without opening the full tool belt."
        case .notes:
            "Work directly with notes, folders, and graph context before reaching for generic file tools."
        case .code:
            "Implement focused changes while keeping vault context and repo state in reach."
        case .debug:
            "Trace failures from logs, files, and repeatable repro steps."
        case .plan:
            "Plan from notes and graph context before the agent starts acting."
        case .research:
            "Synthesize notes, graph context, and external sources into useful research."
        case .review:
            "Stay read-only and critique drafts, notes, or code before changing anything."
        case .securityReview:
            "Inspect code and configuration with a tight, audit-first posture."
        case .summarize:
            "Condense attached or recalled context into the shortest useful summary."
        case .readBranch:
            "Orient on code changes before deciding whether to review or edit them."
        case .explain:
            "Turn complex context into a clearer explanation anchored in your notes."
        case .image:
            "Generate an image on-device via MLX Flux, or explicitly route to Fal when asked."
        }
    }

    var postureSummary: String {
        switch self {
        case .ask, .summarize, .explain:
            "Minimal tools, minimal interruption"
        case .notes:
            "Vault-first, asks before destructive note changes"
        case .plan:
            "Notes first, asks before external actions"
        case .research:
            "Notes and sources first, asks before external actions"
        case .review:
            "Read-only by default"
        case .securityReview:
            "Read-only by default, tighter approvals"
        case .debug:
            "Asks before shell and external actions"
        case .code:
            "Asks before risky writes"
        case .readBranch:
            "Read-only branch orientation"
        case .image:
            "On-device first; Fal only when explicitly named"
        }
    }

    var suggestedPrompt: String {
        switch self {
        case .ask:
            "Help me with "
        case .notes:
            "Find or update notes about "
        case .code:
            "Implement this change: "
        case .debug:
            "Debug this issue: "
        case .plan:
            "Create a step-by-step plan for "
        case .research:
            "Research this topic and cite strong sources: "
        case .review:
            "Review this and flag the biggest issues: "
        case .securityReview:
            "Do a security review and flag the risks in "
        case .summarize:
            "Summarize this: "
        case .readBranch:
            "Read this branch and summarize what changed: "
        case .explain:
            "Explain this clearly: "
        case .image:
            "Generate an image of "
        }
    }

    var brainPreferenceSummary: String {
        switch self {
        case .notes:
            "Reasoning local with vault context preferred"
        case .code:
            "Coder stack preferred"
        case .research:
            "Cloud plus sources preferred"
        case .securityReview:
            "Reasoning model preferred"
        case .debug:
            "Reasoning local preferred"
        case .plan, .review:
            "Reasoning local with note context preferred"
        case .ask, .summarize, .explain:
            "Fast local preferred"
        case .readBranch:
            "Local review brain preferred"
        case .image:
            "MLX Flux preferred (Fal when explicit)"
        }
    }

    var preferredToolNames: Set<String> {
        switch self {
        case .ask, .summarize, .explain:
            return [
                "vault_search",
                "vault_read",
                "graph_query",
                "pkm_graph_neighbors",
            ]
        case .notes:
            return [
                "vault_search",
                "vault_read",
                "vault_write",
                "vault_navigate",
                "graph_query",
                "pkm_graph_neighbors",
            ]
        case .plan:
            return [
                "vault_search",
                "vault_read",
                "graph_query",
                "pkm_graph_neighbors",
                "vault_navigate",
                "todo",
            ]
        case .research:
            return [
                "vault_search",
                "vault_read",
                "graph_query",
                "pkm_graph_neighbors",
                "vault_navigate",
                "web_search",
                "web_extract",
                "web_fetch",
            ]
        case .review:
            return [
                "vault_search",
                "vault_read",
                "graph_query",
                "pkm_graph_neighbors",
                "read_file",
                "search_files",
                "web_search",
                "web_extract",
            ]
        case .securityReview:
            return [
                "vault_search",
                "vault_read",
                "read_file",
                "search_files",
                "graph_query",
                "pkm_graph_neighbors",
            ]
        case .debug:
            return [
                "vault_search",
                "vault_read",
                "read_file",
                "search_files",
                "bash_execute",
                "run_command",
                "terminal",
                "process",
                "execute_code",
            ]
        case .code:
            return [
                "vault_search",
                "vault_read",
                "read_file",
                "search_files",
                "write_file",
                "patch",
                "bash_execute",
                "run_command",
                "process",
                "execute_code",
            ]
        case .readBranch:
            return [
                "read_file",
                "search_files",
                "vault_search",
                "vault_read",
            ]
        case .image:
            return [
                "image_generate",
            ]
        }
    }

    var expertAllowlist: [String] {
        switch self {
        case .ask:
            ["general"]
        case .notes:
            ["note-taking", "vault-editing", "knowledge-management"]
        case .code:
            ["coding", "implementation", "refactoring", "tool-use"]
        case .debug:
            ["debugging", "code-analysis", "error-diagnosis"]
        case .plan:
            ["planning", "task-decomposition", "agent-orchestration"]
        case .research:
            ["research", "web-search", "summarization"]
        case .review:
            ["code-review", "critique", "analysis"]
        case .securityReview:
            ["security-review", "threat-modeling", "vulnerability-analysis"]
        case .summarize:
            ["summarization", "distillation"]
        case .readBranch:
            ["branch-analysis", "codebase-orientation", "review"]
        case .explain:
            ["teaching", "explanation", "simplification"]
        case .image:
            ["image-generation", "diffusion"]
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

    var supportedOperatingModes: [EpistemosOperatingMode] {
        switch self {
        case .local(let modelId, _, let supportsThinking, _, let supportsTools):
            if let model = LocalTextModelID(rawValue: modelId) {
                var modes: [EpistemosOperatingMode] = []
                if !model.cannotDisableThinkingInFast {
                    modes.append(.fast)
                }
                if model.supportsThinkingMode {
                    modes.append(.thinking)
                } else if supportsThinking {
                    modes.append(.thinking)
                }
                if model.canRunLocalAgentLoop || supportsTools {
                    modes.append(.agent)
                }
                return modes.isEmpty ? [.fast] : modes
            }

            var modes: [EpistemosOperatingMode] = [.fast]
            if supportsThinking {
                modes.append(.thinking)
            }
            if supportsTools {
                modes.append(.agent)
            }
            return modes
        case .appleIntelligence:
            return [.fast]
        case .cloud(let provider):
            let providerModes = Set(
                CloudTextModelID.models(for: provider).flatMap(\.supportedOperatingModes)
            )
            return EpistemosOperatingMode.allCases.filter(providerModes.contains)
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

    var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    var isCloud: Bool {
        if case .cloud = self { return true }
        return false
    }

    func matches(localModel: LocalTextModelID) -> Bool {
        if case .local(let modelId, _, _, _, _) = self {
            return modelId == localModel.rawValue
        }
        return false
    }

    func matches(cloudProvider: CloudModelProvider) -> Bool {
        if case .cloud(let provider) = self {
            return provider == cloudProvider
        }
        return false
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
    /// Graph context when the request originated from a graph-workspace
    /// "Ask Graph Chat" action. Carries graph node id, backing source id,
    /// node type, node label, and current route per PLAN_V2 §4.1.
    let graphContext: GraphChatRequest?
}
