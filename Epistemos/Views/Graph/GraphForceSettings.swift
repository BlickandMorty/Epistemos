import SwiftUI

// MARK: - GraphForceSettings
// Popover with two sections: Physics Presets + Force Parameter Sliders.
// Basic section: 4 core params (link distance, charge strength/range, link strength).
// Advanced section: 5 extended params (friction, gravity, collision, warmth, orbital).
// Each slider change pushes updated params to the Rust engine via GraphState.

enum GraphForceSettingsLayout {
    static let panelWidth: CGFloat = 320
}

private enum GraphForceSettingsSection: String, CaseIterable, Identifiable {
    case presets = "Presets"
    case physics = "Physics"
    case display = "Display"
    case advanced = "Advanced"

    var id: Self { self }

    var icon: String {
        switch self {
        case .presets: return "sparkles"
        case .physics: return "bolt"
        case .display: return "rectangle.on.rectangle"
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
                    case .advanced:
                        advancedPanel(gs: $gs)
                    }
                }
                .opacity(isStatic && selectedSection != .display ? 0.4 : 1.0)
                .allowsHitTesting(!isStatic || selectedSection == .display)
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
        }
    }

    private func physicsPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            basicSection(gs: gs)
            Divider().opacity(0.3)
            advancedSection(gs: gs)
            Divider().opacity(0.3)
            clusterSection(gs: gs)
        }
    }

    private func displayPanel(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            titleOverlaySection(gs: gs)
            Divider().opacity(0.3)
            labelsSection(gs: gs)
            Divider().opacity(0.3)
            resetButton
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
                Text("Physics Paused")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(userFrozen
                     ? "Physics frozen by user. Use the toolbar toggle to resume."
                     : "Graph exceeds \(GraphState.staticLayoutThreshold) nodes. Focus on a node to enable physics for that cluster.")
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
            sectionHeader("Mode", icon: graphState.performanceModeEnabled ? "speedometer" : "water.waves")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(graphState.performanceModeEnabled ? "Performance" : "Cinematic")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(graphState.performanceModeEnabled
                         ? "Simple shading and straight edges for the fastest large-graph view."
                         : "Water nodes are on by default with the full graph surface.")
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
                ForEach(graphState.timelineSteps.indices, id: \.self) { idx in
                    timelineStepRow(index: idx)
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

    private func timelineStepRow(index: Int) -> some View {
        let step = graphState.timelineSteps[index]
        return HStack(spacing: 6) {
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
                graphState.timelineSteps.remove(at: index)
                graphState.pushSchedulerChange()
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
                    graphState.timelineSteps[index].presetKey = String(describing: preset)
                    graphState.pushSchedulerChange()
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

    private var resetButton: some View {
        HStack {
            Spacer()
            Button("Reset to Deep Sea") {
                graphState.startOverlayPhysicsCycle()
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
