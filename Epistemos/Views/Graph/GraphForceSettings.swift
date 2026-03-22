import SwiftUI

// MARK: - GraphForceSettings
// Popover with two sections: Physics Presets + Force Parameter Sliders.
// Basic section: 4 core params (link distance, charge strength/range, link strength).
// Advanced section: 5 extended params (friction, gravity, collision, warmth, orbital).
// Each slider change pushes updated params to the Rust engine via GraphState.

enum GraphForceSettingsLayout {
    static let panelWidth: CGFloat = 320
}

struct GraphForceSettings: View {
    @Environment(GraphState.self) private var graphState

    @State private var showAdvanced = false
    @State private var showLaboratory = false

    private var isStatic: Bool { graphState.isStaticLayout }

    var body: some View {
        @Bindable var gs = graphState

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ── Static Layout Banner ──
                if isStatic {
                    staticLayoutBanner
                }

                performanceSection(gs: $gs)

                Divider().opacity(0.3)

                // ── Presets ──
                presetSection
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)

                Divider().opacity(0.3)

                // ── Basic Forces ──
                basicSection(gs: $gs)
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)

                // ── Advanced Toggle ──
                advancedToggle
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)

                if showAdvanced {
                    Divider().opacity(0.3)
                    VStack(alignment: .leading, spacing: 16) {
                        advancedSection(gs: $gs)
                        clusterSection(gs: $gs)
                    }
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)
                }

                Divider().opacity(0.3)
                laboratoryToggle
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)

                if showLaboratory {
                    laboratorySection(gs: $gs)
                        .opacity(isStatic ? 0.4 : 1.0)
                        .allowsHitTesting(!isStatic)
                }

                Divider().opacity(0.3)
                resetButton
                    .opacity(isStatic ? 0.4 : 1.0)
                    .allowsHitTesting(!isStatic)



            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: GraphForceSettingsLayout.panelWidth)
        .frame(maxHeight: 900)
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

    private func performanceSection(gs: Bindable<GraphState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Rendering", icon: "speedometer")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Performance Mode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Straight edges, near-default node shading, and no cinematic glow or blur effects.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: gs.performanceModeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
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
                ForEach(PhysicsPreset.allCases) { preset in
                    presetButton(preset)
                }
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

    // MARK: - Advanced Toggle

    private var advancedToggle: some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { showAdvanced.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Layout & Clustering")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
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

            forceSlider(
                label: "Cluster Bubbles",
                value: gs.clusterStrength,
                range: 0...1,
                format: "%.2f",
                subtitle: "0 = off, 1 = strong bubbles",
                onChange: { graphState.pushClusterChange() }
            )

            forceSlider(
                label: "Semantic Attraction",
                value: gs.semanticStrength,
                range: 0...1,
                format: "%.2f",
                subtitle: "Similarity pull",
                onChange: { graphState.pushSemanticChange() }
            )

            if graphState.semanticStrength > 0.001 {
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

    // MARK: - Laboratory Toggle

    private var laboratoryToggle: some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { showLaboratory.toggle() }
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

    // MARK: - Reset

    private var resetButton: some View {
        HStack {
            Spacer()
            Button("Reset to Crystal") {
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
