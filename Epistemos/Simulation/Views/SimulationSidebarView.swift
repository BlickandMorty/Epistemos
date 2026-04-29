//
//  SimulationSidebarView.swift
//  Simulation Mode S6 — top-level Notes Sidebar surface.
//
//  Per DOCTRINE §3.4 v1.4 + §3.4.1–§3.4.5 v1.6: the sidebar is
//  the app's knowledge-brick centerpiece. Composition:
//
//    [Mascot pin (active workspace)]   ← top
//    [Sidebar title ('<Active>'s Vault')]
//    [Companions picker — three-level w/ multi-toggle]
//    [Per-toggled-entity vault tree    ← scrollable]
//
//  Re-skin transitions on workspace change use the canonical
//  250 ms cross-fade from KnowledgeBrickStyle.reskinAnimation.
//

import SwiftUI

public struct SimulationSidebarView: View {
    @Bindable var toggleState: SidebarToggleState
    let bridge: CompanionRegistryBridge

    @State private var activeAgent: CompanionFarmEntry?
    @State private var allAgents: [CompanionFarmEntry] = []

    public init(toggleState: SidebarToggleState, bridge: CompanionRegistryBridge) {
        self.toggleState = toggleState
        self.bridge = bridge
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            mascotPin
                .padding(.top, 12)
                .padding(.horizontal, 12)

            sidebarTitle
                .padding(.horizontal, 12)

            CompanionsPickerView(
                toggleState: toggleState,
                bridge: bridge
            ) { agent in
                withAnimation(KnowledgeBrickStyle.reskinAnimation) {
                    activeAgent = agent
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .padding(.horizontal, 8)

            // Per-toggled-entity content tree (multi-toggle union
            // per §3.4.2). For S6 substrate we render the
            // per-agent Vaults disclosure for every toggled
            // agent; nested file rendering is a follow-up slice.
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let toggledAgents = allAgents.filter { agent in
                        toggleState.isToggled(.agent(id: agent.id))
                    }
                    if toggledAgents.isEmpty {
                        emptyToggleHint
                            .padding(.horizontal, 12)
                            .padding(.top, 24)
                    } else {
                        ForEach(toggledAgents) { agent in
                            agentSection(agent)
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)
        }
        .frame(
            minWidth: KnowledgeBrickStyle.sidebarMinWidth,
            idealWidth: KnowledgeBrickStyle.sidebarDefaultWidth,
            maxWidth: KnowledgeBrickStyle.sidebarMaxWidth
        )
        .task { await refresh() }
    }

    // MARK: - Mascot pin

    @ViewBuilder
    private var mascotPin: some View {
        HStack(spacing: 10) {
            mascotImage
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(activeAgent?.name ?? "No workspace")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let agent = activeAgent {
                    Text(activitySummary(agent.activity))
                        .font(KnowledgeBrickStyle.summaryLineFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Click a companion in the picker to switch in.")
                        .font(KnowledgeBrickStyle.summaryLineFont)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var mascotImage: some View {
        let brand: Color = {
            guard let agent = activeAgent else { return .accentColor }
            return KnowledgeBrickStyle.brandColor(hex: paletteHex(agent.paletteRef))
        }()
        ZStack {
            // Active halo per §5.7 — separate additive-style glow.
            Circle()
                .fill(brand.opacity(0.30))
                .blur(radius: 6)
            RoundedRectangle(cornerRadius: 6)
                .fill(brand)
                .frame(width: 26, height: 26)
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
                .frame(width: 28, height: 28)
        }
    }

    // MARK: - Title strip

    @ViewBuilder
    private var sidebarTitle: some View {
        let brand: Color = activeAgent.flatMap {
            KnowledgeBrickStyle.brandColor(hex: paletteHex($0.paletteRef))
        } ?? .accentColor
        VStack(alignment: .leading, spacing: 2) {
            Text(activeAgent.map { "\($0.name)'s Vault" } ?? "Simulation Sidebar")
                .font(KnowledgeBrickStyle.sidebarTitleFont)
            KnowledgeBrickStyle.activeUnderline(brand: brand)
        }
    }

    // MARK: - Per-toggled-agent section

    @ViewBuilder
    private func agentSection(_ agent: CompanionFarmEntry) -> some View {
        let brand = KnowledgeBrickStyle.brandColor(hex: paletteHex(agent.paletteRef))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(brand)
                    .frame(width: 12, height: 12)
                Text(agent.name)
                    .font(KnowledgeBrickStyle.modelRowFont)
                    .foregroundStyle(.primary)
                Spacer()
                if toggleState.activeWorkspace == agent.id {
                    KnowledgeBrickStyle.accentDot(brand: brand)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: KnowledgeBrickStyle.modelRowHeight)
            EntityVaultsView(entity: agent, bridge: bridge)
                .padding(.leading, 12)
        }
    }

    // MARK: - Empty / fallback

    @ViewBuilder
    private var emptyToggleHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No companions toggled.")
                .font(KnowledgeBrickStyle.noteTitleFont)
                .foregroundStyle(.secondary)
            Text("Use the chips in the picker above to show one or more companions' vaults here.")
                .font(KnowledgeBrickStyle.summaryLineFont)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func activitySummary(_ state: ActivityState) -> String {
        switch state {
        case .active: return "Working now"
        case .recent: return "Active a moment ago"
        case .dormant: return "Dormant"
        case .parked: return "Parked"
        case .justAcquired: return "Newly acquired"
        }
    }

    private func paletteHex(_ ref: String) -> String {
        switch ref {
        case "claude_warm_v1": return "#D97757"
        case "kimi_indigo_v1": return "#5B8DEF"
        case "local_teal_v1":  return "#33A89C"
        case "hermes_gold_v1": return "#D4AF37"
        case "gpt_neutral_v1": return "#9C9C9C"
        default: return "#6F6F6F"
        }
    }

    private func refresh() async {
        let agents = await bridge.listActive()
        await MainActor.run {
            self.allAgents = agents
            if let active = toggleState.activeWorkspace,
               let agent = agents.first(where: { $0.id == active }) {
                self.activeAgent = agent
            }
        }
    }
}

// MARK: - Standalone preview shell

/// Wrapper for the S6 acceptance gate — opens a scratch
/// CompanionRegistryBridge against a per-user vault root and
/// hosts the SimulationSidebarView. Same pattern as
/// LandingFarmPreviewView (S5).
public struct SimulationSidebarPreviewView: View {
    @State private var bridge: CompanionRegistryBridge?
    @State private var toggleState = SidebarToggleState(windowId: "preview")
    @State private var setupError: String?

    public init() {}

    public var body: some View {
        Group {
            if let bridge = bridge {
                SimulationSidebarView(toggleState: toggleState, bridge: bridge)
            } else if let err = setupError {
                VStack {
                    Text("Initialisation failed")
                        .font(.headline)
                    Text(err).foregroundStyle(.red)
                }
            } else {
                ProgressView("Loading registry…")
                    .task { await initialise() }
            }
        }
    }

    private func initialise() async {
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let vaultRoot = supportDir
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("SimulationPreviewVault")
        do {
            try FileManager.default.createDirectory(
                at: vaultRoot, withIntermediateDirectories: true
            )
        } catch {
            self.setupError = error.localizedDescription
            return
        }
        guard let b = CompanionRegistryBridge(vaultRoot: vaultRoot) else {
            self.setupError = "Could not open companion registry"
            return
        }
        self.bridge = b
    }
}
