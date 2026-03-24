import SwiftData
import SwiftUI

// MARK: - Time Machine View
// Full-screen overlay for temporal state exploration. Shows a session timeline,
// lets users scrub to any past date, and displays a mass diff against the present.
// Non-destructive restore: creates a new workspace from the historical state.

struct TimeMachineView: View {
    @Environment(UIState.self) private var ui
    @Binding var isPresented: Bool

    @State private var timeline: [EventStore.SnapshotMeta] = []
    @State private var selectedSnapshot: EventStore.SnapshotMeta?
    @State private var historicalState: TimeMachineService.HistoricalState?
    @State private var diff: TimeMachineService.StateDiff?
    @State private var isLoading = false
    @State private var appeared = false
    @State private var eventDensity: [Date: Int] = [:]

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Time Machine")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(timeline.count) session\(timeline.count == 1 ? "" : "s") recorded")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                    Text("esc to close")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.leading, 12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider().opacity(0.3)

                if timeline.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(theme.textTertiary)
                        Text("No session history yet")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                        Text("Sessions are recorded when you quit the app. Use it normally and come back here later.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // Left: Session list (timeline)
                        sessionList
                            .frame(width: 260)

                        Divider().opacity(0.3)

                        // Right: State detail + diff
                        if let historicalState, let diff {
                            stateDetailView(state: historicalState, diff: diff)
                        } else if isLoading {
                            VStack {
                                ProgressView()
                                    .controlSize(.regular)
                                Text("Reconstructing state...")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundStyle(theme.textTertiary)
                                Text("Select a session to explore")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxHeight: 520)
                }
            }
            .frame(width: 720)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .foregroundStyle(theme.foreground)
        }
        .background {
            Button(action: { dismiss() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            loadTimeline()
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(timeline) { meta in
                    sessionRow(meta)
                }
            }
            .padding(8)
        }
    }

    private func sessionRow(_ meta: EventStore.SnapshotMeta) -> some View {
        Button {
            selectSnapshot(meta)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(meta.timestamp, style: .date)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(meta.timestamp, style: .time)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)

                if !meta.summary.isEmpty {
                    Text(meta.summary)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedSnapshot?.id == meta.id
                          ? theme.accent.opacity(0.12)
                          : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State Detail

    private func stateDetailView(state: TimeMachineService.HistoricalState, diff: TimeMachineService.StateDiff) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                if !state.summary.isEmpty {
                    Text(state.summary)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(theme.fontAccent.opacity(0.85))
                        .italic()
                        .padding(.horizontal, 20)
                }

                // Diff stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Changes Since Then")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textTertiary)

                    HStack(spacing: 20) {
                        diffStat(label: "Notes Added", value: diff.addedNotes.count, color: .green)
                        diffStat(label: "Notes Removed", value: diff.removedNotes.count, color: .red)
                        diffStat(label: "Notes Modified", value: diff.modifiedNotes.count, color: .orange)
                        diffStat(label: "Graph Nodes", value: diff.graphNodeDelta, color: diff.graphNodeDelta >= 0 ? .green : .red, showSign: true)
                    }
                }
                .padding(.horizontal, 20)

                Divider().opacity(0.2).padding(.horizontal, 20)

                // Modified notes detail
                if !diff.modifiedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Modified Notes")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textTertiary)

                        ForEach(diff.modifiedNotes) { note in
                            HStack {
                                Text(note.title)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                                Spacer()
                                Text(note.wordCountDelta > 0 ? "+\(note.wordCountDelta) words" : "\(note.wordCountDelta) words")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(note.wordCountDelta > 0 ? .green : .red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Note snapshots from that time
                if !state.noteSnapshots.isEmpty {
                    Divider().opacity(0.2).padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes Open at That Time")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textTertiary)

                        ForEach(state.noteSnapshots) { note in
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.accent)
                                Text(note.title)
                                    .font(.system(size: 12, design: .rounded))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(note.wordCount) words")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Restore button
                Button {
                    restoreAsWorkspace(state)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("Restore as New Workspace")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
    }

    private func diffStat(label: String, value: Int, color: Color, showSign: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(showSign && value > 0 ? "+\(value)" : "\(value)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(value == 0 ? theme.textTertiary : color)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Actions

    private func loadTimeline() {
        timeline = AppBootstrap.shared?.workspaceService.timeMachineService?.sessionTimeline() ?? []
        eventDensity = AppBootstrap.shared?.workspaceService.timeMachineService?.eventDensity() ?? [:]
    }

    private func selectSnapshot(_ meta: EventStore.SnapshotMeta) {
        selectedSnapshot = meta
        isLoading = true
        Task { @MainActor in
            guard let service = AppBootstrap.shared?.workspaceService.timeMachineService else {
                isLoading = false
                return
            }
            let state = service.reconstructState(at: meta.timestamp)
            let stateDiff = service.computeDiff(from: state)
            historicalState = state
            diff = stateDiff
            isLoading = false
        }
    }

    private func restoreAsWorkspace(_ state: TimeMachineService.HistoricalState) {
        guard let snapshot = state.snapshot else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let name = "Restored: \(formatter.string(from: state.timestamp))"
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        let context = AppBootstrap.shared?.modelContainer.mainContext
        let ws = SDWorkspace(name: name, isAutoSave: false)
        ws.snapshotData = data
        ws.summary = state.summary
        ws.userNote = "Restored from Time Machine"
        context?.insert(ws)
        try? context?.save()

        // Load the workspace
        AppBootstrap.shared?.workspaceService.loadWorkspace(ws)
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}
