import SwiftUI

// MARK: - RawThoughtsSection
// Patch 5 / UI_PRODUCT_EXPRESSION_PLAN U3 — file-type-driven entry that lives
// UNDER each existing model vault row in the Notes sidebar. NOT a new
// top-level sidebar silo (canon).
//
// Hidden when the `EPISTEMOS_RAW_THOUGHTS_V0` env flag is unset. When
// expanded, the section lists per-run summaries (newest first); clicking a
// row opens `RawThoughtsInspectorView` as a popover/sheet.

struct RawThoughtsSection: View {
    /// The vault root that should be scanned for `Raw Thoughts/<provider>/...`.
    let vaultRoot: URL

    /// Provider hint (e.g. "anthropic", "openai") used to scope this section
    /// to a single model vault. Empty = show every run.
    let providerHint: String

    @Environment(RawThoughtsState.self) private var state

    @State private var isExpanded = false
    @State private var selectedRun: RawThoughtsState.RunSummary?
    @State private var hasRequestedInitialRefresh = false

    private var scopedRuns: [RawThoughtsState.RunSummary] {
        RawThoughtsState.runs(in: state.runs, matching: providerHint)
    }

    var body: some View {
        if !state.isEnabled {
            EmptyView()
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                content
            } label: {
                label
            }
            .padding(.leading, 28)
            .padding(.trailing, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .onChange(of: isExpanded) { _, nowExpanded in
                guard nowExpanded else { return }
                requestRefresh()
            }
            .onAppear {
                guard !hasRequestedInitialRefresh else { return }
                hasRequestedInitialRefresh = true
                if isExpanded {
                    requestRefresh()
                }
            }
            .sheet(item: $selectedRun) { run in
                RawThoughtsInspectorView(run: run)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Raw Thoughts")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Per-run thinking + tools")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if !scopedRuns.isEmpty {
                Text("\(scopedRuns.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        if scopedRuns.isEmpty {
            Text("No runs yet")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
                .padding(.bottom, 2)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groupedByDate(scopedRuns), id: \.id) { group in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        ForEach(group.runs) { run in
                            RawThoughtRow(run: run) {
                                selectedRun = run
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func requestRefresh() {
        let root = vaultRoot
        Task { @MainActor in
            await state.refresh(vaultRoot: root)
        }
    }

    private struct DateGroup: Identifiable {
        let id: String
        let title: String
        let runs: [RawThoughtsState.RunSummary]
    }

    private func groupedByDate(_ runs: [RawThoughtsState.RunSummary]) -> [DateGroup] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var ordering: [String] = []
        var buckets: [String: [RawThoughtsState.RunSummary]] = [:]
        for run in runs {
            let day = calendar.startOfDay(for: run.startedAt)
            let key = formatter.string(from: day)
            if buckets[key] == nil {
                ordering.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(run)
        }
        return ordering.map { key in
            DateGroup(id: key, title: key, runs: buckets[key] ?? [])
        }
    }
}

// MARK: - Row

private struct RawThoughtRow: View {
    let run: RawThoughtsState.RunSummary
    let onSelect: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusTint)
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(run.model.isEmpty ? run.provider : run.model)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(Self.timeFormatter.string(from: run.startedAt)) · \(run.status)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: String {
        switch run.status {
        case "completed": return "checkmark.circle"
        case "errored":   return "exclamationmark.circle"
        case "cancelled": return "minus.circle"
        case "running":   return "circle.dotted"
        default:          return "circle"
        }
    }

    private var statusTint: Color {
        switch run.status {
        case "completed": return .green
        case "errored":   return .red
        case "cancelled": return .secondary
        case "running":   return .blue
        default:          return .secondary
        }
    }
}
