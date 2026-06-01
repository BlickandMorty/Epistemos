import SwiftUI

/// Landing AgentBlueprint creation/edit wizard.
///
/// This is the public "AGENTS +" surface: it keeps the visible avatar/persona
/// controls users already know, then binds each agent to the canonical
/// AgentBlueprint contract (model/provider, tools, scope, approval). The
/// runtime still owns truth, writes, and tool gates.
struct CompanionCreationFlow: View {
    @Bindable var companionState: CompanionState
    var theme: EpistemosTheme
    var editingEntry: CompanionRosterEntry?
    var availableBrains: [ACCBrainSelection] = []
    var availableTools: [OmegaToolDefinition] = []
    var onDismiss: () -> Void = {}

    @State private var step: Int = 0
    @State private var bodyKind: CompanionBodyKind = .blockCompact
    @State private var name: String = ""
    @State private var tagline: String = ""
    @State private var accentHex: String = AgentColorPreset.presets[0].hex
    @State private var personaPrompt: String = ""
    @State private var selectedModelRoutingID: String = AgentBlueprintModelChoice.autoConstellation.routingID
    @State private var selectedToolNames: Set<String> = []
    @State private var scope: AgentBlueprintScope = .currentVault
    @State private var approvalMode: AgentBlueprintApprovalMode = .approveOncePerSession
    @State private var hydratedEditingEntryID: String?

    private let stepCount = 5

    private var isEditing: Bool { editingEntry != nil }

    private struct AgentColorPreset: Hashable {
        let name: String
        let hex: String

        static let presets: [AgentColorPreset] = [
            .init(name: "clay", hex: "#D97757"),
            .init(name: "mint", hex: "#5EC2B7"),
            .init(name: "lilac", hex: "#9C8FE5"),
            .init(name: "gold", hex: "#E5B94E"),
            .init(name: "sky", hex: "#5B8DEF"),
            .init(name: "rose", hex: "#D85E8E"),
            .init(name: "lime", hex: "#8BCB4A"),
            .init(name: "ink", hex: "#7C8798"),
        ]
    }

    private var selectedAccentColor: Color {
        Self.color(fromHex: accentHex) ?? theme.resolved.accent.color
    }

    private var headStyleBinding: Binding<CompanionHeadStyle> {
        Binding(
            get: { bodyKind.resolvedHeadStyle },
            set: { bodyKind = bodyKind.customized(headStyle: $0) }
        )
    }

    private var armStyleBinding: Binding<CompanionArmStyle> {
        Binding(
            get: { bodyKind.resolvedArmStyle },
            set: { bodyKind = bodyKind.customized(armStyle: $0) }
        )
    }

    private var eyeShapeBinding: Binding<CompanionEyeShape> {
        Binding(
            get: { bodyKind.resolvedEyeShape },
            set: { bodyKind = bodyKind.customized(eyeShape: $0) }
        )
    }

    private var accessoryStyleBinding: Binding<CompanionAccessoryStyle> {
        Binding(
            get: { bodyKind.resolvedAccessoryStyle },
            set: { bodyKind = bodyKind.customized(accessoryStyle: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            Divider().opacity(0.18)
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(minHeight: 340)
            Divider().opacity(0.18)
            footer
        }
        .frame(width: 580)
        .foregroundStyle(theme.resolved.foreground.color)
        .pixelPanel(theme: theme)
        .settingsAppleCardChrome(theme: theme, accent: theme.resolved.accent.color)
        .onAppear(perform: hydrateFromEditingEntryIfNeeded)
    }

    // MARK: - Header / Footer

    private var stepHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: isEditing ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
            PixelPanelTitle(text: isEditing ? "Edit Agent" : "New Agent", theme: theme, size: 15)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { idx in
                    Rectangle()
                        .fill(idx == step
                              ? theme.resolved.accent.color
                              : theme.textTertiary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
            }
            Spacer()
            if step < stepCount - 1 {
                Button {
                    step += 1
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(theme.resolved.accent.color.opacity(canAdvance ? 0.15 : 0.06), in: Rectangle())
                    .foregroundStyle(canAdvance
                                     ? theme.resolved.accent.color
                                     : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance)
            } else {
                Button {
                    submit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isEditing ? "checkmark" : "sparkles")
                        Text(isEditing ? "Save Agent" : "Create Agent")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(theme.resolved.accent.color, in: Rectangle())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: true
        case 1: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: true
        case 3: true
        default: true
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: bodyStep
        case 1: nameStep
        case 2: modelStep
        case 3: contractStep
        case 4: confirmStep
        default: EmptyView()
        }
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Choose an agent body", subtitle: "Each grammar shapes the silhouette and animation vocabulary.")
            HStack(alignment: .center, spacing: 16) {
                CompanionAvatarGlyph(
                    kind: bodyKind,
                    accent: selectedAccentColor,
                    phase: 0.65,
                    state: .think,
                    reduceMotionOverride: true
                )
                .frame(width: 76, height: 76)
                .padding(10)
                .background(PixelPanelBackground.actionSurface(for: theme), in: Rectangle())
                .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.18 : 0.24), lineWidth: theme.isDark ? 0.75 : 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text(bodyKind.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text(bodyKind.hint)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                    colorSwatches
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(CompanionBodyKind.creationPresets, id: \.self) { kind in
                    Button {
                        bodyKind = kind.customized(
                            headStyle: bodyKind.resolvedHeadStyle,
                            armStyle: bodyKind.resolvedArmStyle,
                            eyeShape: bodyKind.resolvedEyeShape,
                            accessoryStyle: bodyKind.resolvedAccessoryStyle
                        )
                    } label: {
                        VStack(spacing: 8) {
                            CompanionAvatarGlyph(
                                kind: kind,
                                accent: bodyKind == kind ? theme.resolved.accent.color : theme.textSecondary,
                                phase: bodyKind == kind ? 0.65 : 0.5,
                                reduceMotionOverride: true
                            )
                            .frame(width: 42, height: 42)
                            Text(kind.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            Text(kind.hint)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 94)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            Rectangle()
                                .fill(bodyKind == kind
                                      ? theme.resolved.accent.color.opacity(theme.isDark ? 0.13 : 0.10)
                                      : PixelPanelBackground.actionSurface(for: theme))
                        )
                        .overlay(
                            Rectangle()
                                .stroke(bodyKind == kind
                                        ? theme.resolved.accent.color.opacity(theme.isDark ? 0.34 : 0.40)
                                        : theme.textTertiary.opacity(theme.isDark ? 0.16 : 0.22),
                                        lineWidth: theme.isDark ? 0.75 : 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            bodyStyleControls
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: 7) {
            ForEach(AgentColorPreset.presets, id: \.self) { preset in
                Button {
                    accentHex = preset.hex
                } label: {
                    Rectangle()
                        .fill(Self.color(fromHex: preset.hex) ?? theme.resolved.accent.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Rectangle()
                                .stroke(accentHex == preset.hex ? theme.textPrimary : theme.textTertiary.opacity(0.32), lineWidth: accentHex == preset.hex ? 1.5 : 0.75)
                        )
                        .accessibilityLabel(Text(preset.name))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyStyleControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            styleChipRow("Head", selection: headStyleBinding) { $0.displayName }
            styleChipRow("Arms", selection: armStyleBinding) { $0.displayName }
            styleChipRow("Eyes", selection: eyeShapeBinding) { $0.displayName }
            styleChipRow("Gear", selection: accessoryStyleBinding) { $0.displayName }
        }
        .padding(10)
        .background(PixelPanelBackground.actionSurface(for: theme), in: Rectangle())
        .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.16 : 0.22), lineWidth: theme.isDark ? 0.75 : 1))
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Name + role", subtitle: "One short role makes the active agent obvious in the dock and prompt.")
            labeledTextField("Name", text: $name, prompt: "e.g. Scout, Quill, Nova")
            labeledTextField("Role", text: $tagline, prompt: "e.g. careful code reviewer")
            VStack(alignment: .leading, spacing: 6) {
                Text("Behavior")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: $personaPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 96, maxHeight: 132)
                    .padding(6)
                    .background(Rectangle().fill(PixelPanelBackground.actionSurface(for: theme)))
                    .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.18 : 0.26), lineWidth: theme.isDark ? 0.75 : 1))
            }
        }
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Provider + model", subtitle: "Choose Auto or pin this agent to a local, Apple, or provider-native runtime.")
            VStack(alignment: .leading, spacing: 8) {
                Text("Runtime")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Picker("Runtime", selection: $selectedModelRoutingID) {
                    ForEach(modelChoices, id: \.routingID) { choice in
                        Label(choice.displayName, systemImage: modelIcon(for: choice))
                            .tag(choice.routingID)
                    }
                }
                .pickerStyle(.menu)
                modelBadgeStrip(for: selectedModelChoice)
                Text(selectedModelFootnote(for: selectedModelChoice))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(10)
            .background(PixelPanelBackground.actionSurface(for: theme), in: Rectangle())
            .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.16 : 0.24), lineWidth: theme.isDark ? 0.75 : 1))
        }
    }

    private var contractStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Tools + guardrails", subtitle: "Bind the agent to a scope and approval mode. Runtime gates still verify every action.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Scope")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Picker("Scope", selection: $scope) {
                    ForEach(AgentBlueprintScope.allCases, id: \.rawValue) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Approval")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Picker("Approval", selection: $approvalMode) {
                    ForEach(AgentBlueprintApprovalMode.allCases, id: \.rawValue) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tools")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Text("\(selectedToolNames.count) selected")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                if availableTools.isEmpty {
                    Text("No tools are available for this build profile yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(availableTools.sorted(by: toolSort), id: \.name) { tool in
                                toolToggle(tool)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 128)
                }
            }
        }
    }

    private var confirmStep: some View {
        let preview = CompanionRosterEntry(from: CompanionModel(
            name: name.isEmpty ? "Untitled" : name,
            tagline: tagline,
            bodyKind: bodyKind,
            accentHex: accentHex,
            personaPrompt: personaPrompt,
            agentModelChoice: selectedModelChoice,
            agentToolNames: Array(selectedToolNames),
            agentScope: scope,
            agentApprovalMode: approvalMode
        ))
        return VStack(alignment: .center, spacing: 16) {
            stepTitle("Confirm", subtitle: "This is the visible agent plus the runtime contract behind it.")
            CompanionView(entry: preview, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("Body: \(bodyKind.displayName)")
                Text("Runtime: \(selectedModelChoice.displayName)")
                Text("Scope: \(scope.displayName)")
                Text("Approval: \(approvalMode.displayName)")
                Text("Tools: \(selectedToolNames.isEmpty ? "none" : selectedToolNames.sorted().joined(separator: ", "))")
                if !personaPrompt.isEmpty {
                    Text("Behavior: \(personaPrompt.prefix(80))...")
                        .lineLimit(2)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Local controls

    private func labeledTextField(
        _ title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            TextField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(PixelPanelBackground.actionSurface(for: theme), in: Rectangle())
                .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.18 : 0.26), lineWidth: theme.isDark ? 0.75 : 1))
        }
    }

    private func styleChipRow<Style>(
        _ title: String,
        selection: Binding<Style>,
        label: @escaping (Style) -> String
    ) -> some View where Style: CaseIterable & Hashable, Style.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(Style.allCases), id: \.self) { value in
                        let isSelected = selection.wrappedValue == value
                        Button {
                            selection.wrappedValue = value
                        } label: {
                            Text(label(value))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 30)
                                .background(
                                    isSelected
                                    ? selectedAccentColor.opacity(theme.isDark ? 0.22 : 0.16)
                                    : theme.textTertiary.opacity(theme.isDark ? 0.08 : 0.06),
                                    in: Rectangle()
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            isSelected
                                            ? selectedAccentColor.opacity(theme.isDark ? 0.56 : 0.48)
                                            : theme.textTertiary.opacity(theme.isDark ? 0.14 : 0.20),
                                            lineWidth: theme.isDark ? 0.75 : 1
                                        )
                                )
                                .foregroundStyle(isSelected ? selectedAccentColor : theme.textSecondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                HStack(spacing: 5) {
                    Text(tool.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    if tool.requiresConfirmation || tool.destructive {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
                Text(tool.description)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .toggleStyle(.checkbox)
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(PixelPanelBackground.actionSurface(for: theme), in: Rectangle())
        .overlay(Rectangle().stroke(theme.textTertiary.opacity(theme.isDark ? 0.14 : 0.22), lineWidth: theme.isDark ? 0.75 : 1))
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func modelBadgeStrip(for choice: AgentBlueprintModelChoice) -> some View {
        HStack(spacing: 6) {
            ForEach(choice.badges, id: \.title) { badge in
                Text(badge.title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badgeTint(badge.tone).opacity(0.12), in: Capsule())
                    .foregroundStyle(badgeTint(badge.tone))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Model/tool helpers

    private var modelChoices: [AgentBlueprintModelChoice] {
        var choices = [AgentBlueprintModelChoice.autoConstellation]
        if let editingEntry {
            choices.append(editingEntry.agentModelChoice)
        }
        choices.append(contentsOf: availableBrains.map { AgentBlueprintBrainResolver.modelChoice(for: Optional($0)) })

        var seen = Set<String>()
        return choices.filter { seen.insert($0.routingID).inserted }
    }

    private var selectedModelChoice: AgentBlueprintModelChoice {
        modelChoices.first { $0.routingID == selectedModelRoutingID }
            ?? editingEntry?.agentModelChoice
            ?? .autoConstellation
    }

    private func hydrateFromEditingEntryIfNeeded() {
        guard hydratedEditingEntryID != editingEntry?.id else { return }
        hydratedEditingEntryID = editingEntry?.id
        guard let editingEntry else { return }
        bodyKind = editingEntry.bodyKind
        name = editingEntry.name
        tagline = editingEntry.tagline
        accentHex = editingEntry.accentHex
        personaPrompt = editingEntry.personaPrompt ?? ""
        selectedModelRoutingID = editingEntry.agentModelChoice.routingID
        selectedToolNames = Set(editingEntry.agentToolNames)
        scope = editingEntry.agentScope
        approvalMode = editingEntry.agentApprovalMode
    }

    private func modelIcon(for choice: AgentBlueprintModelChoice) -> String {
        switch choice {
        case .autoConstellation:
            "point.3.connected.trianglepath.dotted"
        case .local:
            "memorychip"
        case .cloud:
            "cloud"
        case .appleIntelligence:
            "apple.logo"
        }
    }

    private func selectedModelFootnote(for choice: AgentBlueprintModelChoice) -> String {
        switch choice {
        case .autoConstellation:
            "Auto keeps Epistemos local-first and lets the router choose the safest available runtime."
        case .local:
            "Local model preference is applied before Landing chat submission when this agent is active."
        case .cloud:
            "Cloud provider preference is explicit. Missing credentials keep routing on the safe local fallback."
        case .appleIntelligence:
            "Apple Intelligence is fast-only and has no tool authority."
        }
    }

    private func badgeTint(_ tone: AgentBlueprintModelBadgeTone) -> Color {
        switch tone {
        case .good:
            .green
        case .neutral:
            theme.textSecondary
        case .warning:
            .orange
        case .disabled:
            .red
        }
    }

    private func toolSort(_ lhs: OmegaToolDefinition, _ rhs: OmegaToolDefinition) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedPersona = personaPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTools = Array(selectedToolNames).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .sorted()

        if let editingEntry {
            _ = companionState.updateCompanion(
                id: editingEntry.id,
                name: trimmedName,
                tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
                bodyKind: bodyKind,
                accentHex: accentHex,
                personaPrompt: trimmedPersona.isEmpty ? nil : trimmedPersona,
                agentModelChoice: selectedModelChoice,
                agentToolNames: cleanedTools,
                agentScope: scope,
                agentApprovalMode: approvalMode
            )
        } else {
            _ = companionState.createCompanion(
                name: trimmedName,
                tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
                bodyKind: bodyKind,
                accentHex: accentHex,
                personaPrompt: trimmedPersona.isEmpty ? nil : trimmedPersona,
                agentModelChoice: selectedModelChoice,
                agentToolNames: cleanedTools,
                agentScope: scope,
                agentApprovalMode: approvalMode,
                activateOnCreate: true
            )
        }
        onDismiss()
    }

    private static func color(fromHex rawValue: String) -> Color? {
        var cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return nil
        }
        return Color(hex: value)
    }
}
