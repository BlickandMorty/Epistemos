import SwiftUI

/// Compact Landing agent dock.
///
/// The dock is a small top-right surface: no large panel, no decorative
/// orb/chrome, and no hidden fake runtime. Tapping an agent activates its
/// persisted persona for the next main-chat turn.
///
/// Three regions:
/// - **Header**: retro "AGENTS" label + compact "+" button
/// - **Cluster**: active agents breathing in one location
/// - **Trash hint** (only if there are archived companions): a
///   subtle "N in trash" link that opens the Restore sheet
///
/// Doctrinal posture:
/// - Reads from `companionState.roster` snapshot — never holds a
///   SwiftData model directly
/// - Tap = activate (foreground persona for next chat)
/// - Long-press / right-click = context menu (Activate, Delete)
/// - No card/panel wrapper; this sits as quiet landing chrome
struct LandingFarmView: View {
    @Bindable var companionState: CompanionState
    var theme: EpistemosTheme
    var isAnimationActive: Bool = true
    var onCreate: () -> Void = {}
    var onOpenTrash: () -> Void = {}
    var onRequestDelete: (CompanionRosterEntry) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 7) {
            header
            if companionState.roster.isEmpty {
                emptyState
            } else {
                CompanionRoamingField(
                    entries: companionState.roster,
                    activeCompanionID: companionState.activeCompanionID,
                    isAnimationActive: isAnimationActive,
                    onActivate: { companionState.activate($0.id) },
                    onRequestDelete: onRequestDelete
                )
            }
            if !companionState.trashed.isEmpty {
                trashHint
            }
        }
        .frame(width: 246, alignment: .trailing)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                   value: companionState.roster.count)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            if let activeID = companionState.activeCompanionID,
               let active = companionState.roster.first(where: { $0.id == activeID }) {
                Text(active.name.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            Text("AGENTS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.textPrimary.opacity(0.86))
                .tracking(1.4)
            Button(action: onCreate) {
                Text("+")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 19, height: 19)
                    .foregroundStyle(theme.resolved.accent.color)
                    .overlay(
                        Rectangle()
                            .stroke(theme.resolved.accent.color.opacity(0.55), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Add agent")
        }
    }

    // MARK: - Empty + Trash

    private var emptyState: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("NO AGENTS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary.opacity(0.8))
            Button("+ add agent") { onCreate() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.resolved.accent.color)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
    }

    private var trashHint: some View {
        Button(action: onOpenTrash) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                Text("\(companionState.trashed.count) in trash")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(theme.textTertiary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}
