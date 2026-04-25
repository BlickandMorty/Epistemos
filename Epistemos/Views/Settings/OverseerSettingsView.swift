import SwiftUI

/// Transparency-only diagnostics panel for the Overseer routing layer.
/// Shows what `OverseerComplexityRouter` has been deciding on recent
/// main-chat turns so you can audit the auto-router without exposing
/// user-editable controls. See docs/MASTER_MODEL_STACK_PLAN.md §3
/// "Overseer" for the longer-term control plan.
struct OverseerSettingsView: View {
    @Environment(OverseerAuditState.self) private var audit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                introCard

                if audit.recentPlans.isEmpty {
                    emptyState
                } else {
                    ForEach(audit.recentPlans) { entry in
                        OverseerAuditEntryCard(entry: entry)
                    }
                }

                footer
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header / intro

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overseer")
                .font(.title2.weight(.semibold))
            Text("The auto-router that decides between local, overseer-local, and managed-agent routes on every main-chat turn. Read-only audit trail of its recent decisions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var introCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                OverseerFactRow(
                    label: "Active",
                    value: "Yes — runs on every main-chat turn",
                    symbol: "checkmark.seal.fill",
                    tint: .green
                )
                OverseerFactRow(
                    label: "Logic home",
                    value: "Epistemos/Engine/OverseerProtocol.swift",
                    symbol: "brain.head.profile",
                    tint: .purple
                )
                OverseerFactRow(
                    label: "User controls",
                    value: "None — transparency-only for now",
                    symbol: "eye",
                    tint: .blue
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("No turns recorded yet", systemImage: "clock")
                    .font(.headline)
                Text("Run a prompt in main chat to see the Overseer's route selection, depth budget, mask plan, and tool permissions appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack {
            Text("Showing the \(audit.recentPlans.count) most recent \(audit.recentPlans.count == 1 ? "turn" : "turns"). Capped at \(OverseerAuditState.capacity) for memory hygiene.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !audit.recentPlans.isEmpty {
                Button("Reset history") {
                    audit.clear()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Fact row

private struct OverseerFactRow: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Entry card

private struct OverseerAuditEntryCard: View {
    let entry: OverseerAuditEntry

    @State private var isExpanded = false

    var body: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(entry.headline)
                        .font(.footnote.weight(.medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer()
                    OverseerRoutePill(route: entry.plan.route, label: entry.routeDisplayName)
                }

                HStack(spacing: 14) {
                    OverseerMetric(label: "Turns", value: "\(entry.plan.plan.depthBudget.maxTurns)")
                    OverseerMetric(label: "Reasoning steps", value: "\(entry.plan.plan.depthBudget.maxReasoningSteps)")
                    OverseerMetric(label: "Tool calls", value: "\(entry.plan.plan.depthBudget.maxToolCalls)")
                    OverseerMetric(label: "Output tokens", value: "\(entry.plan.plan.depthBudget.maxOutputTokens)")
                    Spacer()
                    Text(entry.recordedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                DisclosureGroup(
                    isExpanded: $isExpanded,
                    content: { detailSection },
                    label: {
                        Text(isExpanded ? "Hide plan detail" : "Show plan detail")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !entry.plan.plan.maskPlan.expertAllowlist.isEmpty {
                factBlock(
                    title: "Mask — expert allowlist",
                    rows: entry.plan.plan.maskPlan.expertAllowlist
                )
            }

            if !entry.plan.plan.loraBlendCoefficients.isEmpty {
                factBlock(
                    title: "LoRA blend",
                    rows: entry.plan.plan.loraBlendCoefficients.map {
                        "\($0.adapterID) × \(String(format: "%.2f", $0.coefficient))"
                    }
                )
            }

            if !entry.plan.plan.toolPermissions.isEmpty {
                factBlock(
                    title: "Tool permissions",
                    rows: entry.plan.plan.toolPermissions.map {
                        "\($0.toolName) — \($0.mode.rawValue)"
                    }
                )
            }

            factBlock(
                title: "KV cache policy",
                rows: [entry.plan.plan.kvPolicyFlag.rawValue]
            )

            if !entry.plan.plan.contextSummary.summary.isEmpty {
                factBlock(
                    title: "Context summary",
                    rows: [entry.plan.plan.contextSummary.summary]
                )
            }

            if let rationale = entry.plan.plan.maskPlan.rationale, !rationale.isEmpty {
                factBlock(title: "Rationale", rows: [rationale])
            }
        }
        .padding(.top, 4)
    }

    private func factBlock(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Text(row)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.85))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Route pill

private struct OverseerRoutePill: View {
    let route: OverseerExecutionRoute
    let label: String

    var body: some View {
        Text(label)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.75))
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch route {
        case .localOnly: .green
        case .overseerLocalExecution: .indigo
        case .managedAgentSession: .purple
        }
    }
}

private struct OverseerMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview("Empty") {
    OverseerSettingsView()
        .environment(OverseerAuditState())
        .frame(width: 720, height: 640)
}
