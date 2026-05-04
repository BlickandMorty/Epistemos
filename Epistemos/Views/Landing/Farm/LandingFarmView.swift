import SwiftUI

/// The Companion Farm — Simulation Mode v1.6's home surface
/// (Invariant I-1: single base substrate; the Farm is the user's
/// portal into per-companion personas riding on that substrate).
///
/// Rendered as an inline section on the landing page (under the
/// greeting / above the shortcut chips). Per the user's emphasis,
/// "the Landing Farm = home window" — this surface is the default
/// thing the user sees when they land in Epistemos.
///
/// Three regions:
/// - **Header**: "Companions" title + "+ New Companion" chip
/// - **Roster grid**: every active companion as a CompanionView
/// - **Trash hint** (only if there are archived companions): a
///   subtle "N in trash" link that opens the Restore sheet
///
/// Doctrinal posture:
/// - Reads from `companionState.roster` snapshot — never holds a
///   SwiftData model directly
/// - Tap = activate (foreground persona for next chat)
/// - Long-press / right-click = context menu (Delete, Apply Adapter)
/// - Visual chrome matches the rest of landing — liquid-glass panel,
///   subtle entrance spring per CommandHint pattern
struct LandingFarmView: View {
    @Bindable var companionState: CompanionState
    var theme: EpistemosTheme
    var onCreate: () -> Void = {}
    var onOpenTrash: () -> Void = {}
    var onApplyAdapter: (CompanionRosterEntry) -> Void = { _ in }
    var onRequestDelete: (CompanionRosterEntry) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 132, maximum: 168), spacing: 18)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if companionState.roster.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                    ForEach(companionState.roster) { entry in
                        CompanionView(
                            entry: entry,
                            isActive: entry.id == companionState.activeCompanionID,
                            onActivate: { companionState.activate(entry.id) }
                        )
                        .contextMenu {
                            Button {
                                companionState.activate(entry.id)
                            } label: {
                                Label("Activate", systemImage: "circle.dashed.inset.filled")
                            }
                            Button {
                                onApplyAdapter(entry)
                            } label: {
                                Label("Apply Adapter…", systemImage: "wand.and.stars")
                            }
                            Divider()
                            Button(role: .destructive) {
                                onRequestDelete(entry)
                            } label: {
                                Label("Delete \(entry.name)", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            if !companionState.trashed.isEmpty {
                trashHint
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(panelBackground)
        .frame(maxWidth: 720)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                   value: companionState.roster.count)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
            Text("Companions")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary.opacity(0.85))
            if let activeID = companionState.activeCompanionID,
               let active = companionState.roster.first(where: { $0.id == activeID }) {
                Text("· active: \(active.name)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button(action: onCreate) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("New Companion")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(theme.resolved.accent.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(theme.resolved.accent.color.opacity(0.10))
                )
                .overlay(
                    Capsule().stroke(theme.resolved.accent.color.opacity(0.22), lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty + Trash

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No companions yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Button("Create your first one") { onCreate() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 18)
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

    // MARK: - Background

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.04 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.resolved.accent.color.opacity(0.18), lineWidth: 0.6)
            )
    }
}
