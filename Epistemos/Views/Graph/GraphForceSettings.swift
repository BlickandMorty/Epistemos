import SwiftUI

// MARK: - GraphForceSettings
// Popover with presets, physics, display, filters, and advanced tuning.
// Each slider change pushes updated params to the Rust engine via GraphState.

enum GraphForceSettingsLayout {
    static let panelWidth: CGFloat = 320
}

private enum GraphForceSettingsSection: String, CaseIterable, Identifiable {
    case presets = "Presets"
    case physics = "Physics"
    case display = "Display"
    case filters = "Filters"
    case advanced = "Advanced"

    var id: Self { self }

    var icon: String {
        switch self {
        case .presets: return "sparkles"
        case .physics: return "bolt"
        case .display: return "rectangle.on.rectangle"
        case .filters: return "line.3.horizontal.decrease.circle"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct GraphForceSettings: View {
    @Environment(GraphState.self) private var graphState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLaboratory = false
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var renameTargetId: UUID? = nil
    @State private var renameDraft = ""
    @State private var selectedSection: GraphForceSettingsSection = .presets
    /// "Reset to Defaults" confirmation gate. Set true to surface the
    /// confirmation dialog before clobbering the user's custom force
    /// settings.
    @State private var showResetConfirmation = false

    private var isStatic: Bool { graphState.isStaticLayout }

    var body: some View {
        @Bindable var gs = graphState

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isStatic {
                    staticLayoutBanner
                }

                sectionBar

                Group {
                    switch selectedSection {
                    case .presets:
                        presetsPanel(gs: $gs)
                    case .physics:
                        physicsPanel(gs: $gs)
                    case .display:
                        displayPanel(gs: $gs)
                    case .filters:
                        filtersPanel
                    case .advanced:
                        advancedPanel(gs: $gs)
                    }
                }
                .opacity(isStatic && selectedSection != .display && selectedSection != .filters ? 0.4 : 1.0)
                .allowsHitTesting(!isStatic || selectedSection == .display || selectedSection == .filters)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: GraphForceSettingsLayout.panelWidth)
        .frame(maxHeight: 720)
    }

    // MARK: - Top Sections

    private var sectionBar: some View {
        HStack(spacing: 6) {
            ForEach(GraphForceSettingsSection.allCases) { section in
                let isSelected = selectedSection == section
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(section.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Graph settings sections")
    }

    private func presetsPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            renderModeSection(gs: gs)
            Divider().opacity(0.3)
            presetSection
            customPresetsSection
            Divider().opacity(0.3)
            resetButton
        }
    }

    private func physicsPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            basicSection(gs: gs)
            Divider().opacity(0.3)
            advancedSection(gs: gs)
            Divider().opacity(0.3)
            clusterSection(gs: gs)
            Divider().opacity(0.3)
            resetButton
        }
    }

    private func displayPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            titleOverlaySection(gs: gs)
            Divider().opacity(0.3)
            cameraSection(gs: gs)
            Divider().opacity(0.3)
            labelsSection(gs: gs)
            Divider().opacity(0.3)
            resetButton
        }
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Node Types", icon: "line.3.horizontal.decrease.circle")

            HStack(spacing: 8) {
                Button("Content Only") {
                    graphState.applyContentFocusedNodeVisibility()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Show All") {
                    graphState.showAllUserFilterableNodeTypes()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(GraphState.userFilterableNodeTypes, id: \.self) { type in
                    Toggle(isOn: Binding(
                        get: { graphState.isNodeTypeVisible(type) },
                        set: { graphState.setNodeTypeVisibility(type, isVisible: $0) }
                    )) {
                        Text(type.settingsDisplayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }

            settingNote("Hidden types stay in the vault and can be restored instantly.")
        }
    }

    /// User-tunable camera behavior (deselect zoom tightness + camera lerp
    /// speed). Live-pushes to the Rust engine via cameraConfigVersion.
    private func cameraSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Camera")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
                .textCase(.uppercase)
                .tracking(0.6)

            forceSlider(
                label: "Deselect zoom",
                value: gs.cameraDeselectZoomMultiplier,
                range: 1.0...3.0,
                format: "%.2f×",
                subtitle: "tighter →",
                onChange: { }
            )

            forceSlider(
                label: "Camera speed",
                value: gs.cameraSpeedLambda,
                range: 4.0...22.0,
                format: "%.1f",
                subtitle: "snappier →",
                onChange: { }
            )
        }
    }

    private func advancedPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            schedulerSection(gs: gs)
            Divider().opacity(0.3)
            laboratoryToggle
            if showLaboratory {
                laboratorySection(gs: gs)
            }
        }
    }

    // MARK: - Static Layout Banner

    private var staticLayoutBanner: some View {
        let userFrozen = graphState.isPhysicsFrozen
        return HStack(spacing: 8) {
            Image(systemName: userFrozen ? "pause.circle.fill" : "gauge.with.dots.needle.0percent")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Physics Frozen")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(userFrozen
                     ? "Physics frozen by user. Use the toolbar toggle to resume."
                     : "Physics is paused for this graph state.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Presets

    private func renderModeSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Mode", icon: graphState.performanceModeEnabled ? "speedometer" : "square.grid.3x3")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(graphState.performanceModeEnabled ? "Performance" : "Cinematic")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(graphState.performanceModeEnabled
                         ? "Simple shading and straight edges for the fastest large-graph view."
                         : "Hard stepped pixel nodes with the full graph surface.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Performance", isOn: gs.performanceModeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 6) {
                // Featured filter keeps the main picker intentional.
                // Hidden built-ins still exist in code so saved
                // scheduler steps and lookup-by-name keep working.
                ForEach(PhysicsPreset.allCases.filter { $0.isFeatured }) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    // MARK: - Custom Presets

    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    newPresetName = ""
                    showSavePresetAlert = true
                } label: {
                    Label("Save current", systemImage: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(graphState.customPhysicsPresets.count >= 32)
            }

            if graphState.customPhysicsPresets.isEmpty {
                Text("No custom presets yet. Save the current physics setup to reuse it later.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    ForEach(graphState.customPhysicsPresets) { preset in
                        customPresetRow(preset)
                    }
                }
            }
        }
        .alert("Save Custom Preset", isPresented: $showSavePresetAlert) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") {
                let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    _ = graphState.saveCurrentAsCustomPreset(name: String(trimmed.prefix(40)))
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Captures all current physics, clustering, lab, and scheduler settings.")
        }
        .alert("Rename Preset", isPresented: Binding(
            get: { renameTargetId != nil },
            set: { if !$0 { renameTargetId = nil } }
        )) {
            TextField("New name", text: $renameDraft)
            Button("Save") {
                if let id = renameTargetId {
                    let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        graphState.renameCustomPreset(id: id, newName: String(trimmed.prefix(40)))
                    }
                }
                renameTargetId = nil
            }
            Button("Cancel", role: .cancel) { renameTargetId = nil }
        }
    }

    private func customPresetRow(_ preset: CustomPhysicsPresetSnapshot) -> some View {
        Button {
            graphState.applyCustomPreset(preset)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(preset.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .contextMenu {
            Button("Rename") {
                renameDraft = preset.name
                renameTargetId = preset.id
            }
            Button("Delete", role: .destructive) {
                graphState.deleteCustomPreset(id: preset.id)
            }
        }
    }

    private func presetButton(_ preset: PhysicsPreset) -> some View {
        let isSelected = graphState.selectedPhysicsPreset == preset
        return Button {
            graphState.applyPreset(preset)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: preset.icon)
                    .font(.system(size: 14))
                Text(preset.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }

    // MARK: - Basic Forces

    private func basicSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Forces", icon: "bolt")

            forceSlider(
                label: "Link Distance",
                value: gs.linkDistance,
                range: 20...500,
                format: "%.0f",
                onChange: { graphState.pushForceChange() }
            )

            forceSlider(
                label: "Charge Strength",
                value: gs.chargeStrength,
                range: -3000...0,
                format: "%.0f",
                onChange: { graphState.pushForceChange() }
            )

            forceSlider(
                label: "Charge Range",
                value: gs.chargeRange,
                range: 100...3000,
                format: "%.0f",
                onChange: { graphState.pushForceChange() }
            )

            forceSlider(
                label: "Link Strength",
                value: gs.linkStrength,
                range: 0...2,
                format: "%.2f",
                subtitle: "0 = auto",
                onChange: { graphState.pushForceChange() }
            )
        }
    }

    // MARK: - Advanced Section

    private func advancedSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Dynamics", icon: "waveform.path")

            forceSlider(
                label: "Friction",
                value: gs.velocityDecay,
                range: 0.05...0.95,
                format: "%.2f",
                subtitle: "Low = bouncy, High = viscous",
                onChange: { graphState.pushExtendedForceChange() }
            )

            forceSlider(
                label: "Center Gravity",
                value: gs.centerStrength,
                range: 0...0.1,
                format: "%.3f",
                onChange: { graphState.pushExtendedForceChange() }
            )

            forceSlider(
                label: "Node Spacing",
                value: gs.collisionRadius,
                range: 0...100,
                format: "%.0f px",
                onChange: { graphState.pushExtendedForceChange() }
            )
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Clustering

    private func clusterSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Clustering", icon: "circle.grid.3x3")

            Toggle(isOn: gs.disableClusteringAndSemantics) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disable clustering + semantics")
                        .font(.system(size: 11, weight: .medium))
                    Text("Zero both forces; toggle off to restore previous values")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            let clusterDisabled = graphState.disableClusteringAndSemantics

            forceSlider(
                label: "Cluster Bubbles",
                value: gs.clusterStrength,
                range: 0...1,
                format: "%.2f",
                subtitle: "0 = off, 1 = strong bubbles",
                onChange: { graphState.pushClusterChange() }
            )
            .disabled(clusterDisabled)
            .opacity(clusterDisabled ? 0.35 : 1.0)

            forceSlider(
                label: "Semantic Attraction",
                value: gs.semanticStrength,
                range: 0...1,
                format: "%.2f",
                subtitle: "Similarity pull",
                onChange: { graphState.pushSemanticChange() }
            )
            .disabled(clusterDisabled)
            .opacity(clusterDisabled ? 0.35 : 1.0)

            if graphState.semanticStrength > 0.001 && !clusterDisabled {
                forceSlider(
                    label: "Cohesion",
                    value: gs.boidsCohesion,
                    range: 0...1,
                    format: "%.2f",
                    subtitle: "Loose \u{2194} Swarm",
                    onChange: { graphState.pushLabChange() }
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Center Force")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("Center Force", selection: gs.centerMode) {
                    Text("Attract").tag(UInt8(0))
                    Text("Off").tag(UInt8(1))
                    Text("Repel").tag(UInt8(2))
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .onChange(of: graphState.centerMode) {
                    graphState.pushClusterChange()
                }
            }
        }
    }

    // MARK: - Scheduler

    private func schedulerSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Startup Scheduler", icon: "timer")

            // 2026-05-19: master enable toggle. When OFF, the scheduler
            // does not run on graph open, so the user's saved physics
            // settings are honored as-is. Off by default per user spec.
            Toggle("Enable startup scheduler", isOn: gs.schedulerEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("When off, the graph opens with your saved physics settings and does not auto-apply an opening preset.")

            if graphState.schedulerEnabled {
                Picker("Mode", selection: gs.schedulerMode) {
                    Text("Simple").tag(PhysicsSchedulerMode.simple)
                    Text("Timeline").tag(PhysicsSchedulerMode.timeline)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .onChange(of: graphState.schedulerMode) { graphState.pushSchedulerChange() }

                if graphState.schedulerMode == .simple {
                    schedulerSimpleControls(gs: gs)
                } else {
                    schedulerTimelineControls(gs: gs)
                }
            }

            Divider().opacity(0.3)

            Text("Interaction")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            forceSlider(
                label: "Motion Hold",
                value: Binding(
                    get: { Float(graphState.interactionMotionHoldSeconds) },
                    set: { graphState.interactionMotionHoldSeconds = Double($0) }
                ),
                range: 0...120,
                format: "%.0fs",
                subtitle: "How long interaction sustains motion",
                onChange: { graphState.pushSchedulerChange() }
            )

            forceSlider(
                label: "Interaction Alpha",
                value: gs.interactionMotionAlphaTarget,
                range: 0.001...0.1,
                format: "%.3f",
                subtitle: "Energy level during interaction",
                onChange: { graphState.pushSchedulerChange() }
            )
        }
    }

    private func schedulerSimpleControls(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            presetKeyPicker(
                label: "Opening",
                selection: gs.simpleOpeningPresetKey,
                onChange: { graphState.pushSchedulerChange() }
            )
            forceSlider(
                label: "Opening Duration",
                value: Binding(
                    get: { Float(graphState.simpleOpeningDelaySeconds) },
                    set: { graphState.simpleOpeningDelaySeconds = Double($0) }
                ),
                range: 0...60,
                format: "%.1fs",
                subtitle: "Delay before switching to resting",
                onChange: { graphState.pushSchedulerChange() }
            )
            presetKeyPicker(
                label: "Resting",
                selection: gs.simpleRestingPresetKey,
                onChange: { graphState.pushSchedulerChange() }
            )
        }
    }

    private func schedulerTimelineControls(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if graphState.timelineSteps.isEmpty {
                Text("No steps yet. Add steps to sequence preset changes over time.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                // Iterate by stable `\.id` (PhysicsScheduleStep.id: UUID)
                // rather than `\.indices, id: \.self`. The latter crashes
                // on delete: SwiftUI re-evaluates the row body for the
                // pre-removal index before the diff fires, and
                // `timelineSteps[staleIndex]` reads past the shrunk
                // array. Identity-keyed iteration removes that hazard
                // because the deleted row disappears from the layout
                // cycle atomically with the array shrink.
                ForEach(graphState.timelineSteps) { step in
                    timelineStepRow(stepID: step.id)
                }
            }
            Button {
                let newStep = PhysicsScheduleStep(
                    delaySeconds: 4.0,
                    presetKey: "chaos"
                )
                graphState.timelineSteps.append(newStep)
                graphState.pushSchedulerChange()
            } label: {
                Label("Add step", systemImage: "plus.circle")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .disabled(graphState.timelineSteps.count >= 16)
        }
    }

    @ViewBuilder
    private func timelineStepRow(stepID: UUID) -> some View {
        // Resolve the live index on every evaluation; bail out cleanly if
        // the step was removed during the same render pass. This is
        // belt-and-suspenders alongside the identity-keyed ForEach above:
        // even if a context-menu callback fires after the step has been
        // removed by another path, we never crash.
        if let index = graphState.timelineSteps.firstIndex(where: { $0.id == stepID }) {
            let step = graphState.timelineSteps[index]
            HStack(spacing: 6) {
                Text("#\(index + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .leading)
                Text("+\(String(format: "%.1f", step.delaySeconds))s")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
                Text(displayNameForPresetKey(step.presetKey))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button {
                    // Re-resolve at click time. Without the recheck, a
                    // double-click race could try to remove an already-
                    // removed row.
                    if let idx = graphState.timelineSteps.firstIndex(where: { $0.id == stepID }) {
                        graphState.timelineSteps.remove(at: idx)
                        graphState.pushSchedulerChange()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contextMenu {
                ForEach(PhysicsPreset.allCases.filter { $0.isFeatured }) { preset in
                    Button(preset.rawValue) {
                        if let idx = graphState.timelineSteps.firstIndex(where: { $0.id == stepID }) {
                            graphState.timelineSteps[idx].presetKey = String(describing: preset)
                            graphState.pushSchedulerChange()
                        }
                    }
                }
            }
        }
    }

    private func presetKeyPicker(
        label: String,
        selection: Binding<String>,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Picker(label, selection: selection) {
                ForEach(PhysicsPreset.allCases.filter { $0.isFeatured }) { preset in
                    Text(preset.rawValue).tag(String(describing: preset))
                }
                if !graphState.customPhysicsPresets.isEmpty {
                    Divider()
                    ForEach(graphState.customPhysicsPresets) { custom in
                        Text("Custom: \(custom.name)").tag("custom:\(custom.id.uuidString)")
                    }
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .onChange(of: selection.wrappedValue) { onChange() }
        }
    }

    private func displayNameForPresetKey(_ key: String) -> String {
        if key.hasPrefix("custom:") {
            let uuidStr = String(key.dropFirst("custom:".count))
            if let uuid = UUID(uuidString: uuidStr),
               let custom = graphState.customPhysicsPresets.first(where: { $0.id == uuid }) {
                return "Custom: \(custom.name)"
            }
            return "Custom: (missing)"
        }
        if let builtin = PhysicsPreset.allCases.first(where: { String(describing: $0) == key }) {
            return builtin.rawValue
        }
        return key
    }

    // MARK: - Laboratory Toggle

    private var laboratoryToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { showLaboratory.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showLaboratory ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Experimental Motion")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Laboratory Section

    private func laboratorySection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── World Rules ──
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("World Rules", icon: "water.waves")

                labToggle(
                    label: "Fluid Wake Physics",
                    isOn: gs.enableFluidDynamics,
                    onChange: { graphState.pushLabChange() }
                )
                if graphState.enableFluidDynamics {
                    settingNote("Wake only appears while dragging nodes.")
                    forceSlider(
                        label: "Viscosity",
                        value: gs.fluidViscosity,
                        range: 0...1,
                        format: "%.2f",
                        subtitle: "Water \u{2194} Honey",
                        onChange: { graphState.pushLabChange() }
                    )
                }
            }

            Divider().opacity(0.2)

            // ── Structure ──
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Structure", icon: "cube.transparent")

                labToggle(
                    label: "Crystalline Angular Tension",
                    isOn: gs.enableTorsionalSprings,
                    onChange: { graphState.pushLabChange() }
                )
                if graphState.enableTorsionalSprings {
                    forceSlider(
                        label: "Rigidity",
                        value: gs.torsionRigidity,
                        range: 0...1,
                        format: "%.2f",
                        subtitle: "Organic Blob \u{2194} Snowflake",
                        onChange: { graphState.pushLabChange() }
                    )
                }

                labToggle(
                    label: "Elastic Edges",
                    isOn: gs.enableElasticEdges,
                    onChange: { graphState.pushLabChange() }
                )
                if graphState.enableElasticEdges {
                    forceSlider(
                        label: "Edge Elasticity",
                        value: gs.edgeElasticity,
                        range: 0...1,
                        format: "%.2f",
                        subtitle: "Loose \u{2194} Taut",
                        onChange: { graphState.pushLabChange() }
                    )
                }
            }

            Divider().opacity(0.2)

            // ── Forces ──
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Forces", icon: "wind")

                forceSlider(
                    label: "Wind X",
                    value: gs.windX,
                    range: -50...50,
                    format: "%.1f",
                    subtitle: "Left \u{2194} Right drift",
                    onChange: { graphState.pushLabChange() }
                )
                forceSlider(
                    label: "Wind Y",
                    value: gs.windY,
                    range: -50...50,
                    format: "%.1f",
                    subtitle: "Up \u{2194} Down drift",
                    onChange: { graphState.pushLabChange() }
                )

                labToggle(
                    label: "Orbital Hierarchies",
                    isOn: gs.enableOrbital,
                    onChange: { graphState.pushLabChange() }
                )
                if graphState.enableOrbital {
                    settingNote("Only affects contains/authored links.")
                    forceSlider(
                        label: "Orbital Speed",
                        value: gs.orbitalSpeed,
                        range: 0...1,
                        format: "%.2f",
                        subtitle: "Still \u{2194} Fast",
                        onChange: { graphState.pushLabChange() }
                    )
                }
            }

        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Title Overlay

    private func titleOverlaySection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Title Overlay", icon: "textformat")

            VStack(alignment: .leading, spacing: 4) {
                Text("Show Title")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Show Title", selection: gs.graphTitleMode) {
                    ForEach(GraphTitleMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Labels

    private func labelsSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Labels", icon: "textformat.abc")

            forceSlider(
                label: "Outer Labels",
                value: Binding(
                    get: { Float(graphState.labelMaxNodes) },
                    set: { graphState.labelMaxNodes = UInt32($0) }
                ),
                range: 0...80,
                format: "%.0f",
                subtitle: "Labels visible before zoom",
                onChange: { graphState.labelPolicyVersion += 1; graphState.saveLabelPolicy() }
            )

            forceSlider(
                label: "Base Size",
                value: gs.labelFontSizePx,
                range: 10...44,
                format: "%.0f px",
                subtitle: "SDF label size",
                onChange: { graphState.labelPolicyVersion += 1; graphState.saveLabelPolicy() }
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Label Bubbles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Automatic")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("Long labels expand node spacing without changing the force model.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            forceSlider(
                label: "Focus Shrink",
                value: gs.labelFocusShrink,
                range: 0...1,
                format: "%.2f",
                subtitle: "Wide \u{2194} Tight focus",
                onChange: { graphState.labelPolicyVersion += 1; graphState.saveLabelPolicy() }
            )

            forceSlider(
                label: "Dead Zone",
                value: gs.labelInnerOffset,
                range: 0...3,
                format: "%.2f",
                subtitle: "Gap between outer and inner labels",
                onChange: { graphState.labelPolicyVersion += 1; graphState.saveLabelPolicy() }
            )

            forceSlider(
                label: "Max Inner Labels",
                value: Binding(
                    get: { Float(graphState.labelMaxInnerNodes) },
                    set: { graphState.labelMaxInnerNodes = UInt32($0) }
                ),
                range: 0...20,
                format: "%.0f",
                subtitle: "Labels visible when zoomed in",
                onChange: { graphState.labelPolicyVersion += 1; graphState.saveLabelPolicy() }
            )
        }
    }

    // MARK: - Reset

    /// "Reset to Defaults" — the canonical recovery path. Calls
    /// `GraphState.resetPhysicsToCanonicalDefaults()` which restores
    /// the V3 boot defaults (Gravity Well preset + center force off +
    /// linkDistance 500 + fluid off) and clears every user-overlay
    /// (cursor force, shape bound, lab tunables, timeline). Per user
    /// 2026-05-12: there was no "go back to defaults" path before
    /// this; once any value was edited the user was stuck with
    /// their custom state forever.
    private var resetButton: some View {
        HStack {
            Spacer()
            Button {
                showResetConfirmation = true
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Restore the Gravity Well boot defaults (center force off, linkDistance 500, fluid off). Clears cursor force, shape bound, lab tunables, and the timeline.")
            .confirmationDialog(
                "Reset all physics to defaults?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    graphState.resetPhysicsToCanonicalDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores the Gravity Well boot defaults and clears every customization: cursor force, shape bound, lab tunables, scheduler timeline, frozen state, and camera knobs. Custom presets and node-type filters are preserved.")
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func forceSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        subtitle: String? = nil,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range) { editing in
                if !editing { onChange() }
            }
            .controlSize(.small)
        }
    }

    private func labToggle(
        label: String,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .onChange(of: isOn.wrappedValue) { onChange() }
    }

    private func settingNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension GraphNodeType {
    var settingsDisplayName: String {
        switch self {
        case .document:
            return "Epdoc"
        default:
            return displayName
        }
    }
}
