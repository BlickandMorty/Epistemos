import SwiftUI

// MARK: - FSRSReviewSidebar (AR7 — master plan Phase 2 / Wave 13 §"Phase 2")
//
// Surfaces the highest-risk notes from `FSRSDecayStore.shared` so the
// user can clear the morning review queue without leaving the
// Sessions sidebar context. Reads the top-K via `topAtRisk()` and
// commits user grades back through `recordReview(noteId:grade:)`.
//
// `FSRSDecayStore` is an `actor` (post-AP5), so every call site is
// `await` and runs off the @MainActor. The view itself is
// @MainActor-bound for SwiftUI binding; the actor-hop only happens
// during the explicit `Task { … }` boundary in `refresh()` /
// `recordReview(...)`.
//
// Surface threshold + DSR semantics live in `FSRSDecayState.swift`
// — this view is a pure read / record-back chrome.

@MainActor
@Observable
final class FSRSReviewSidebarModel {

    /// Snapshot of the top-K at-risk notes. Refreshed via
    /// `refresh()` and after every recorded grade so the sidebar
    /// reflects the new heap immediately.
    private(set) var atRisk: [FSRSHighRisk] = []

    /// Surfacing window. Default mirrors the actor's own default
    /// (`limit: 25`) so the sidebar shows the same shoulder
    /// NightBrain consumes.
    var limit: Int = 25

    /// Note IDs the user has already graded in the current session.
    /// Tracked locally so the row briefly disappears before the next
    /// `topAtRisk()` snapshot lands.
    private(set) var pendingDismissalIds: Set<String> = []

    /// Re-pull the top-K snapshot from the actor.
    func refresh() async {
        let snapshot = await FSRSDecayStore.shared.topAtRisk(limit: limit)
        self.atRisk = snapshot
        self.pendingDismissalIds.removeAll()
    }

    /// Record an explicit user grade on the actor. After the grade
    /// commits, refresh the snapshot so the row drops out of the
    /// sidebar.
    func recordReview(noteId: String, grade: FSRSGrade) async {
        pendingDismissalIds.insert(noteId)
        await FSRSDecayStore.shared.recordReview(noteId: noteId, grade: grade)
        await refresh()
    }

    /// Visible rows — at-risk minus the locally-dismissed set.
    var visibleRows: [FSRSHighRisk] {
        atRisk.filter { !pendingDismissalIds.contains($0.noteId) }
    }
}

// MARK: - View

/// Sidebar/sheet that lists notes whose retrievability has decayed
/// past `FSRSHighRisk.surfaceThreshold` (= 0.80 by default). Each
/// row exposes a one-tap "Reviewed" button (graded `.good`) plus a
/// disclosure-style row of the four FSRS grades for fine-grained
/// recording.
struct FSRSReviewSidebar: View {

    @State private var model = FSRSReviewSidebarModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .task { await model.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tint)
            Text("Forgotten Notes")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Re-pull top-at-risk snapshot")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if model.visibleRows.isEmpty {
            ContentUnavailableView(
                "No notes due for review",
                systemImage: "checkmark.seal",
                description: Text(
                    "Notes will appear here when retrievability falls below "
                    + String(format: "%.0f%%", FSRSHighRisk.surfaceThreshold * 100)
                    + "."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(model.visibleRows, id: \.noteId) { row in
                    FSRSReviewRow(
                        risk: row,
                        onGrade: { grade in
                            Task { await model.recordReview(noteId: row.noteId, grade: grade) }
                        }
                    )
                }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Row

private struct FSRSReviewRow: View {

    let risk: FSRSHighRisk
    let onGrade: (FSRSGrade) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(risk.noteId)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                retrievabilityChip
            }

            HStack(spacing: 4) {
                Text(elapsedSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Reviewed") { onGrade(.good) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .help("Record a 'Good' review and reset retrievability")
                Menu {
                    ForEach(FSRSGrade.allCases, id: \.self) { grade in
                        Button(grade.label) { onGrade(grade) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.small)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
                .help("Record an explicit grade (Again / Hard / Good / Easy)")
            }
        }
        .padding(.vertical, 4)
    }

    private var retrievabilityChip: some View {
        Text(String(format: "%.0f%%", risk.retrievability * 100))
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(retrievabilityColor.opacity(0.18), in: Capsule())
            .foregroundStyle(retrievabilityColor)
    }

    /// Cool→warm gradient: low retrievability = red (very forgotten),
    /// approaching threshold = amber, threshold-edge = yellow.
    private var retrievabilityColor: Color {
        switch risk.retrievability {
        case ..<0.40: return .red
        case ..<0.65: return .orange
        default:      return .yellow
        }
    }

    private var elapsedSummary: String {
        let days = risk.elapsedDays
        if days < 1 { return "Reviewed today" }
        if days < 2 { return "1 day ago" }
        if days < 30 { return "\(Int(days)) days ago" }
        let months = days / 30
        if months < 12 { return String(format: "%.1f months ago", months) }
        return String(format: "%.1f years ago", months / 12)
    }
}
