import SwiftUI

struct AgentBlueprintSettingsView: View {
    @Environment(AgentCommandCenterState.self) private var commandCenter
    @Environment(AgentChatState.self) private var agentChat
    @Environment(InferenceState.self) private var inference
    @Environment(MCPBridge.self) private var mcpBridge
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var name = "Research Assistant"
    @State private var role = "Local research assistant that retrieves evidence, drafts a note, and emits a typed answer packet."
    @State private var objective = "Research the selected topic in the active vault, synthesize the strongest claims, create a note artifact, and cite the evidence used."
    @State private var selectedBrain: ACCBrainSelection?
    @State private var selectedToolNames: Set<String> = []
    @State private var scope: AgentBlueprintScope = .currentVault
    @State private var approvalMode: AgentBlueprintApprovalMode = .approveOncePerSession
    @State private var lastMissionPacket: AgentMissionPacket?
    @State private var recentMissionRecords: [AgentBlueprintRunRecord] = []
    @State private var recentRunEvents: [AgentProvenanceEvent] = []
    @State private var submissionStatus: String?
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedToolNames.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                formCard
                toolsCard
                missionPacketCard
                recentMissionRunsCard
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .topLeading)
        }
        .task {
            refreshRuntimeCatalogs()
            recentMissionRecords = AgentBlueprintRunStore.load()
            refreshRecentRunEvents()
            seedDefaultToolsIfNeeded()
            refreshMissionPacket()
        }
        .onChange(of: name) { _, _ in refreshMissionPacket() }
        .onChange(of: role) { _, _ in refreshMissionPacket() }
        .onChange(of: objective) { _, _ in refreshMissionPacket() }
        .onChange(of: selectedBrain) { _, _ in refreshMissionPacket() }
        .onChange(of: selectedToolNames) { _, _ in refreshMissionPacket() }
        .onChange(of: scope) { _, _ in refreshMissionPacket() }
        .onChange(of: approvalMode) { _, _ in refreshMissionPacket() }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("AgentBlueprint", systemImage: "person.crop.rectangle.stack")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    ChannelStatusPill(title: diagnosticsStateLabel, tint: diagnosticsStateTint)
                }

                Text("Blueprint submission runs through the same Command Center compiler and agent runtime path as live tool sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        submitBlueprint()
                    } label: {
                        Label(isSubmitting ? "Submitting" : "Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canSubmit || isSubmitting)

                    Button {
                        refreshRuntimeCatalogs()
                        refreshRecentRunEvents()
                        seedDefaultToolsIfNeeded()
                        refreshMissionPacket()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let submissionStatus {
                        Text(submissionStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var formCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Blueprint")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Name")
                            .foregroundStyle(.secondary)
                        TextField("Research Assistant", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("Role")
                            .foregroundStyle(.secondary)
                        TextField("Research role", text: $role, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    GridRow {
                        Text("Model")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Model", selection: $selectedBrain) {
                                modelPickerRow(
                                    title: AgentBlueprintModelChoice.autoConstellation.displayName,
                                    systemImage: "point.3.connected.trianglepath.dotted",
                                    badges: AgentBlueprintModelChoice.autoConstellation.badges
                                )
                                .tag(Optional<ACCBrainSelection>.none)
                                ForEach(commandCenter.availableBrains) { brain in
                                    let choice = modelChoice(for: brain)
                                    modelPickerRow(
                                        title: brain.displayName,
                                        systemImage: brain.icon,
                                        badges: choice.badges
                                    )
                                    .tag(Optional(brain))
                                }
                            }
                            .pickerStyle(.menu)

                            modelBadgeStrip(for: modelChoice)
                        }
                    }

                    GridRow {
                        Text("Scope")
                            .foregroundStyle(.secondary)
                        Picker("Scope", selection: $scope) {
                            ForEach(AgentBlueprintScope.allCases, id: \.rawValue) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    GridRow {
                        Text("Approval")
                            .foregroundStyle(.secondary)
                        Picker("Approval", selection: $approvalMode) {
                            ForEach(AgentBlueprintApprovalMode.allCases, id: \.rawValue) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mission")
                        .font(.subheadline.weight(.semibold))
                    TextField("Mission objective", text: $objective, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5...8)
                }
            }
        }
    }

    private var toolsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tools")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: "\(selectedToolNames.count) selected", tint: selectedToolNames.isEmpty ? .orange : .green)
                }

                if commandCenter.availableTools.isEmpty {
                    Text("No runtime tools are available for the active vault and build profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(commandCenter.availableTools.sorted(by: toolSort), id: \.name) { tool in
                            toolToggle(tool)
                        }
                    }
                }
            }
        }
    }

    private var missionPacketCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("MissionPacket")
                        .font(.headline)
                    Spacer()
                    if let lastMissionPacket {
                        Text(lastMissionPacket.id.prefix(8))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastMissionPacket {
                    modelBadgeStrip(for: lastMissionPacket.model)
                    runtimeContractGrid(for: lastMissionPacket)

                    Text(lastMissionPacket.commandCenterQuery)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var recentMissionRunsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent Runs")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(
                        title: "\(recentMissionRecords.count) stored",
                        tint: recentMissionRecords.isEmpty ? .secondary : .green
                    )
                    if !recentMissionRecords.isEmpty {
                        Button {
                            AgentBlueprintRunStore.clear()
                            recentMissionRecords = []
                            refreshRecentRunEvents()
                            submissionStatus = "Cleared stored MissionPackets."
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if recentMissionRecords.isEmpty {
                    Text("Run a blueprint to persist a replayable MissionPacket here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recentMissionRecords) { record in
                            recentMissionRunRow(record)
                        }
                    }
                }
            }
        }
    }

    private func toolToggle(_ tool: OmegaToolDefinition) -> some View {
        Toggle(isOn: Binding(
            get: { selectedToolNames.contains(tool.name) },
            set: { enabled in
                if enabled {
                    selectedToolNames.insert(tool.name)
                } else {
                    selectedToolNames.remove(tool.name)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tool.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    if tool.requiresConfirmation || tool.destructive {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .help("Requires approval")
                    }
                }
                Text(tool.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .toggleStyle(.checkbox)
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func modelPickerRow(
        title: String,
        systemImage: String,
        badges: [AgentBlueprintModelBadge]
    ) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
            Spacer()
            ForEach(badges, id: \.title) { badge in
                Text(badge.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badgeTint(badge.tone))
            }
        }
    }

    private func modelBadgeStrip(for choice: AgentBlueprintModelChoice) -> some View {
        HStack(spacing: 6) {
            ForEach(choice.badges, id: \.title) { badge in
                Text(badge.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badgeTint(badge.tone).opacity(0.12), in: Capsule())
                    .foregroundStyle(badgeTint(badge.tone))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func recentMissionRunRow(_ record: AgentBlueprintRunRecord) -> some View {
        let replaySnapshot = record.replaySnapshot(from: recentRunEvents)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(record.packet.blueprintName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(record.packet.id.prefix(8))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(record.queuedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    loadMissionRecord(record)
                } label: {
                    Label("Replay", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    queueMissionPacket(record.packet, statusPrefix: "Replayed", persist: true)
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSubmitting)
            }

            modelBadgeStrip(for: record.packet.model)
            runtimeContractStrip(for: record.packet)
            runEventLogReplayStrip(for: record, replaySnapshot: replaySnapshot)
            if let replaySnapshot {
                AgentRunTimelineView(runID: replaySnapshot.runID)
            }

            Text(record.packet.objective)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func runEventLogReplayStrip(
        for record: AgentBlueprintRunRecord,
        replaySnapshot: AgentBlueprintRunReplaySnapshot?
    ) -> some View {
        HStack(spacing: 8) {
            Label("RunEventLog", systemImage: "timeline.selection")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let replaySnapshot {
                Text("\(replaySnapshot.shortRunID) · \(replaySnapshot.summary)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("waiting for committed events · \(record.packet.id.prefix(8))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button {
                refreshRecentRunEvents()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Refresh RunEventLog replay status")
            .accessibilityLabel("Refresh RunEventLog replay status")
        }
    }

    private func runtimeContractGrid(for packet: AgentMissionPacket) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(packet.runtimeContractFields, id: \.label) { field in
                VStack(alignment: .leading, spacing: 3) {
                    Text(field.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(field.value)
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(badgeTint(field.tone))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    badgeTint(field.tone).opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
        }
    }

    private func runtimeContractStrip(for packet: AgentMissionPacket) -> some View {
        HStack(spacing: 6) {
            ForEach(packet.runtimeContractFields.prefix(3), id: \.label) { field in
                Text(field.value)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(badgeTint(field.tone))
                    .background(badgeTint(field.tone).opacity(0.1), in: Capsule())
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func submitBlueprint() {
        refreshMissionPacket()
        guard let packet = lastMissionPacket else { return }
        queueMissionPacket(packet, statusPrefix: "Queued", persist: true)
    }

    private func queueMissionPacket(
        _ packet: AgentMissionPacket,
        statusPrefix: String,
        persist: Bool
    ) {
        guard let bootstrap = AppBootstrap.shared else {
            submissionStatus = "Runtime unavailable."
            return
        }
        let packetBrain = AgentBlueprintBrainResolver.brainSelection(
            for: packet.model,
            availableBrains: commandCenter.availableBrains
        )
        guard !packet.model.requiresExplicitBrainOverride || packetBrain != nil else {
            submissionStatus = "Cannot run \(packet.id.prefix(8)); \(packet.model.displayName) is unavailable."
            return
        }

        isSubmitting = true
        commandCenter.selectedOperatingMode = .agent
        selectedBrain = packetBrain
        commandCenter.selectedBrain = packetBrain
        commandCenter.inputText = packet.commandCenterQuery
        commandCenter.inspectorState = .expanded(.execution)
        commandCenter.present()

        bootstrap.coordinator.chatCoordinator.handleCommandCenterSubmission(
            query: packet.commandCenterQuery,
            slashToken: nil,
            mentions: [],
            toolRestrictions: Set(packet.toolNames),
            brainOverride: packetBrain,
            pipeline: bootstrap.coordinator.pipelineService,
            agentChat: agentChat,
            accState: commandCenter
        )

        if persist {
            recentMissionRecords = AgentBlueprintRunStore.record(packet)
        }
        refreshRecentRunEvents()
        submissionStatus = "\(statusPrefix) \(packet.id.prefix(8)) through agent runtime."
        isSubmitting = false
    }

    private func loadMissionRecord(_ record: AgentBlueprintRunRecord) {
        let packet = record.packet
        name = packet.blueprintName
        role = packet.role
        objective = packet.objective
        selectedToolNames = Set(packet.toolNames)
        scope = packet.scope
        approvalMode = packet.approvalMode
        selectedBrain = brainSelection(for: packet.model)
        lastMissionPacket = packet

        commandCenter.selectedOperatingMode = .agent
        commandCenter.selectedBrain = selectedBrain
        commandCenter.inputText = packet.commandCenterQuery
        commandCenter.inspectorState = .expanded(.execution)
        commandCenter.present()
        refreshRecentRunEvents()
        submissionStatus = "Replayed \(packet.id.prefix(8)) into Command Center."
    }

    private func refreshRuntimeCatalogs() {
        commandCenter.refreshBrainCatalog(from: inference)
        commandCenter.selectedOperatingMode = .agent
        commandCenter.refreshToolCatalog(
            from: mcpBridge,
            vaultPath: vaultSync.vaultURL?.path ?? ""
        )
    }

    private func refreshRecentRunEvents() {
        recentRunEvents = EventStore.shared?.recentAgentEvents(limit: 200) ?? []
    }

    private func seedDefaultToolsIfNeeded() {
        guard selectedToolNames.isEmpty else { return }
        let preferred = ["vault.search", "vault.recall", "note.create", "note.edit", "graph.expand", "web.fetch"]
        let availableByCanonical = commandCenter.availableTools.reduce(into: [String: String]()) { result, tool in
            result[AgentToolNameAliases.canonical(tool.name), default: tool.name] = tool.name
        }
        selectedToolNames = Set(preferred.compactMap { availableByCanonical[$0] })
        if selectedToolNames.isEmpty {
            selectedToolNames = Set(commandCenter.availableTools.prefix(4).map(\.name))
        }
    }

    private func refreshMissionPacket() {
        lastMissionPacket = currentDraft.missionPacket(
            id: lastMissionPacket?.id ?? UUID().uuidString,
            createdAt: lastMissionPacket?.createdAt ?? Date()
        )
    }

    private var currentDraft: AgentBlueprintDraft {
        AgentBlueprintDraft(
            name: name,
            role: role,
            objective: objective,
            model: modelChoice,
            toolNames: Array(selectedToolNames),
            scope: scope,
            approvalMode: approvalMode
        )
    }

    private var modelChoice: AgentBlueprintModelChoice {
        modelChoice(for: selectedBrain)
    }

    private func modelChoice(for brain: ACCBrainSelection?) -> AgentBlueprintModelChoice {
        guard let brain else { return .autoConstellation }
        switch brain {
        case .local(let modelID, let displayName, _, _, _):
            return .local(modelID: modelID, displayName: displayName)
        case .cloud(let provider):
            return .cloud(provider: provider.rawValue, displayName: provider.displayName)
        case .appleIntelligence:
            return .appleIntelligence
        }
    }

    private func brainSelection(for choice: AgentBlueprintModelChoice) -> ACCBrainSelection? {
        AgentBlueprintBrainResolver.brainSelection(
            for: choice,
            availableBrains: commandCenter.availableBrains
        )
    }

    private func badgeTint(_ tone: AgentBlueprintModelBadgeTone) -> Color {
        switch tone {
        case .good:
            .green
        case .neutral:
            .secondary
        case .warning:
            .orange
        case .disabled:
            .red
        }
    }

    private func toolSort(_ lhs: OmegaToolDefinition, _ rhs: OmegaToolDefinition) -> Bool {
        if lhs.agent != rhs.agent {
            return lhs.agent < rhs.agent
        }
        return lhs.name < rhs.name
    }

    private var diagnosticsStateLabel: String {
        switch commandCenter.diagnostics.state {
        case .idle:
            "Idle"
        case .compiling:
            "Compiling"
        case .running:
            "Running"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        }
    }

    private var diagnosticsStateTint: Color {
        switch commandCenter.diagnostics.state {
        case .idle:
            .secondary
        case .compiling, .running:
            .blue
        case .completed:
            .green
        case .failed:
            .orange
        }
    }
}
