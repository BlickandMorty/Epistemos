import SwiftUI

// MARK: - W9.13 — Daily Notes UI + FSRS due-review section
//
// One note per calendar day (à la Logseq / Roam) plus the FSRS-6
// "due for review" surface. SDPage already has `isJournal: Bool`
// + `journalDate: String?` (W10.2 schema); this view binds to those
// fields via the existing `JournalIntents` data layer.
//
// Today's note auto-creates on first edit (lazy creation matches
// Reflect's pattern — no empty journal pollution). The FSRS section
// pulls from `FSRSDecayStore.notesDueForReview(date:)` (per AP5
// actor refactor) and surfaces 3-5 due notes inline.
//
// Wiring: drop into the workspace alongside `NoteDetailWorkspaceView`
// or as a dedicated tab. The calendar sidebar (`JournalCalendarSidebar`)
// is a peer view that drives the date binding.

@MainActor
public struct DailyNoteView: View {

    public struct DueReviewItem: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let lastReviewedAt: Date?
        public let intervalDays: Int

        public init(id: String, title: String, lastReviewedAt: Date?, intervalDays: Int) {
            self.id = id
            self.title = title
            self.lastReviewedAt = lastReviewedAt
            self.intervalDays = intervalDays
        }
    }

    @Binding var date: Date
    let body_: String
    let dueReview: [DueReviewItem]
    let onChangeBody: (String) -> Void
    let onOpenReview: (DueReviewItem) -> Void

    public init(
        date: Binding<Date>,
        body: String,
        dueReview: [DueReviewItem],
        onChangeBody: @escaping (String) -> Void,
        onOpenReview: @escaping (DueReviewItem) -> Void
    ) {
        self._date = date
        self.body_ = body
        self.dueReview = dueReview
        self.onChangeBody = onChangeBody
        self.onOpenReview = onOpenReview
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider()
                editor
                if !dueReview.isEmpty {
                    Divider()
                    reviewSection
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday(.wide).month().day().year())
                    .font(.title2.weight(.semibold))
                Text(relativeDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var editor: some View {
        TextEditor(
            text: Binding(
                get: { body_ },
                set: { onChangeBody($0) }
            )
        )
        .font(.body)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 200)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(.tint)
                Text("Due for review (\(dueReview.count))")
                    .font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(dueReview) { item in
                    Button {
                        onOpenReview(item)
                    } label: {
                        HStack {
                            Text(item.title)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                            Text("every \(item.intervalDays)d")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var relativeDateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return ""
    }
}

#if DEBUG
#Preview {
    @Previewable @State var date = Date()
    return DailyNoteView(
        date: $date,
        body: "## Morning notes\n\n- Shipped W9.13 daily-note view\n- TODO: wire FSRS source",
        dueReview: [
            .init(id: "n1", title: "Smart approval contract", lastReviewedAt: nil, intervalDays: 7),
            .init(id: "n2", title: "Mamba-2 prefill notes", lastReviewedAt: nil, intervalDays: 14),
        ],
        onChangeBody: { _ in },
        onOpenReview: { _ in }
    )
    .frame(width: 600, height: 700)
}
#endif
