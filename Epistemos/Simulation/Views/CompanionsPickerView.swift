//
//  CompanionsPickerView.swift
//  Simulation Mode S6 — three-level Company → Model → Agent
//  picker with multi-toggle chips.
//
//  Per DOCTRINE §3.4 v1.4 + §3.4.2 v1.6 + §3.4.3 v1.6:
//
//   - Three-level disclosure: Company section header → Model
//     subsection → Agent leaf with pixel-art mascot tile.
//   - Per-row toggle chip on the LEFT for the multi-toggle
//     display tree.
//   - Active workspace is set by clicking the agent leaf NAME
//     (not the toggle chip) — the chip is for display tree only.
//   - Brand-color accents from `provenance.json` (DOCTRINE
//     §10.7) on the active workspace's section underline +
//     accent dot.
//   - Empty company sections hidden (§3.4 v1.4).
//

import SwiftUI

public struct CompanionsPickerView: View {
    @Bindable var toggleState: SidebarToggleState
    let bridge: CompanionRegistryBridge
    let onSelectAgent: (CompanionFarmEntry) -> Void

    @State private var companies: [Company] = []
    @State private var modelsByCompany: [String: [Model]] = [:]
    @State private var agentsByModel: [String: [CompanionFarmEntry]] = [:]
    @State private var expandedCompanies: Set<String> = []
    @State private var expandedModels: Set<String> = []

    public init(
        toggleState: SidebarToggleState,
        bridge: CompanionRegistryBridge,
        onSelectAgent: @escaping (CompanionFarmEntry) -> Void
    ) {
        self.toggleState = toggleState
        self.bridge = bridge
        self.onSelectAgent = onSelectAgent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader
            ForEach(companies) { company in
                companyDisclosure(company)
            }
        }
        .task { await refresh() }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Companions")
                .font(KnowledgeBrickStyle.companyHeaderFont)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(companies.reduce(0) { $0 + $1.agentCount })")
                .font(KnowledgeBrickStyle.companyHeaderFont)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .frame(height: KnowledgeBrickStyle.companyHeaderHeight)
    }

    // MARK: - Per-company disclosure

    @ViewBuilder
    private func companyDisclosure(_ company: Company) -> some View {
        let isExpanded = expandedCompanies.contains(company.slug)
        let isActiveCompany = isCompanyActive(company)
        let brand = KnowledgeBrickStyle.brandColor(hex: company.brandColorHex)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                toggleChip(
                    isOn: toggleState.isToggled(.company(slug: company.slug)),
                    brand: brand
                ) {
                    withAnimation(KnowledgeBrickStyle.toggleChipAnimation) {
                        toggleState.toggle(.company(slug: company.slug))
                    }
                }
                disclosureChevron(expanded: isExpanded)
                Text(company.displayName)
                    .font(KnowledgeBrickStyle.companyHeaderFont)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(isActiveCompany ? .primary : .secondary)
                Spacer()
                Text("\(company.agentCount)")
                    .font(KnowledgeBrickStyle.companyHeaderFont)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: KnowledgeBrickStyle.companyHeaderHeight)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(KnowledgeBrickStyle.disclosureAnimation) {
                    if isExpanded {
                        expandedCompanies.remove(company.slug)
                    } else {
                        expandedCompanies.insert(company.slug)
                    }
                }
            }
            if isActiveCompany {
                KnowledgeBrickStyle.activeUnderline(brand: brand)
            }
            if isExpanded {
                ForEach(modelsByCompany[company.slug] ?? []) { model in
                    modelRow(model)
                }
                .padding(.leading, KnowledgeBrickStyle.indentStep)
            }
        }
    }

    // MARK: - Per-model row

    @ViewBuilder
    private func modelRow(_ model: Model) -> some View {
        let isExpanded = expandedModels.contains(model.id)
        let brand = KnowledgeBrickStyle.brandColor(hex: model.brandColorHex)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                toggleChip(
                    isOn: toggleState.isToggled(.model(id: model.id)),
                    brand: brand
                ) {
                    withAnimation(KnowledgeBrickStyle.toggleChipAnimation) {
                        toggleState.toggle(.model(id: model.id))
                    }
                }
                disclosureChevron(expanded: isExpanded)
                Text(model.displayName)
                    .font(KnowledgeBrickStyle.modelRowFont)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(model.agentCount)")
                    .font(KnowledgeBrickStyle.modelRowFont)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: KnowledgeBrickStyle.modelRowHeight)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(KnowledgeBrickStyle.disclosureAnimation) {
                    if isExpanded {
                        expandedModels.remove(model.id)
                    } else {
                        expandedModels.insert(model.id)
                    }
                }
            }
            if isExpanded {
                ForEach(agentsByModel[model.id] ?? []) { agent in
                    agentLeaf(agent, brand: brand)
                }
                .padding(.leading, KnowledgeBrickStyle.indentStep)
            }
        }
    }

    // MARK: - Per-agent leaf

    @ViewBuilder
    private func agentLeaf(_ agent: CompanionFarmEntry, brand: Color) -> some View {
        let isActive = (toggleState.activeWorkspace == agent.id)

        HStack(spacing: 8) {
            toggleChip(
                isOn: toggleState.isToggled(.agent(id: agent.id)),
                brand: brand
            ) {
                withAnimation(KnowledgeBrickStyle.toggleChipAnimation) {
                    toggleState.toggle(.agent(id: agent.id))
                }
            }
            // Mascot — placeholder rounded rect with palette color
            // (S10 replaces with the real Tamagotchi atlas tile).
            mascotPlaceholder(for: agent)
                .frame(width: 20, height: 20)
            Text(agent.name)
                .font(KnowledgeBrickStyle.agentLeafFont)
                .foregroundStyle(isActive
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(Color.primary.opacity(0.85)))
                .lineLimit(1)
            Spacer()
            if isActive {
                KnowledgeBrickStyle.accentDot(brand: brand)
            }
        }
        .frame(height: KnowledgeBrickStyle.agentLeafHeight)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? brand.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleState.setActiveWorkspace(agent.id)
            onSelectAgent(agent)
        }
    }

    // MARK: - Visual primitives

    private func toggleChip(
        isOn: Bool, brand: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(isOn ? brand : .secondary.opacity(0.4), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn ? brand.opacity(0.20) : Color.clear)
                )
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide from sidebar" : "Show in sidebar")
    }

    private func disclosureChevron(expanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .animation(KnowledgeBrickStyle.disclosureAnimation, value: expanded)
    }

    private func mascotPlaceholder(for agent: CompanionFarmEntry) -> some View {
        let hex: String
        switch agent.paletteRef {
        case "claude_warm_v1": hex = "#D97757"
        case "kimi_indigo_v1": hex = "#5B8DEF"
        case "local_teal_v1":  hex = "#33A89C"
        case "hermes_gold_v1": hex = "#D4AF37"
        case "gpt_neutral_v1": hex = "#9C9C9C"
        default: hex = "#6F6F6F"
        }
        return RoundedRectangle(cornerRadius: 4)
            .fill(KnowledgeBrickStyle.brandColor(hex: hex))
    }

    // MARK: - Active-state helpers

    private func isCompanyActive(_ company: Company) -> Bool {
        guard let active = toggleState.activeWorkspace else { return false }
        let agent = (modelsByCompany[company.slug] ?? [])
            .flatMap { agentsByModel[$0.id] ?? [] }
            .first { $0.id == active }
        return agent != nil
    }

    // MARK: - Refresh

    private func refresh() async {
        let comps = bridge.listCompanies()
        var modelsBy: [String: [Model]] = [:]
        var agentsBy: [String: [CompanionFarmEntry]] = [:]
        for c in comps {
            let models = bridge.listModels(for: c)
            modelsBy[c.slug] = models
            for m in models {
                agentsBy[m.id] = bridge.listAgents(for: m)
            }
        }
        await MainActor.run {
            self.companies = comps
            self.modelsByCompany = modelsBy
            self.agentsByModel = agentsBy
            // Auto-expand the company + model hosting the active
            // workspace so the user sees their agent immediately.
            if let active = toggleState.activeWorkspace {
                for c in comps {
                    for m in modelsBy[c.slug] ?? [] {
                        if (agentsBy[m.id] ?? []).contains(where: { $0.id == active }) {
                            expandedCompanies.insert(c.slug)
                            expandedModels.insert(m.id)
                        }
                    }
                }
            }
        }
    }
}
