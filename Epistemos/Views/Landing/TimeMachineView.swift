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

    private var scrimColor: Color { theme.isDark ? .black : .gray }
    private var scrimOpacity: Double { theme.isDark ? 0.45 : 0.2 }
    private var panelShadow: Color { theme.isDark ? .black.opacity(0.3) : .black.opacity(0.1) }
    private var panelStroke: Color { theme.isDark ? .white.opacity(0.08) : .black.opacity(0.06) }

    var body: some View {
        ZStack {
            scrimColor.opacity(appeared ? scrimOpacity : 0)
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
            .frame(width: 680)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: panelShadow, radius: 24, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(panelStroke)
            }
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .foregroundStyle(theme.resolved.foreground.color)
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
                          ? theme.resolved.accent.color.opacity(0.12)
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
                        diffStat(label: "Notes Added", value: diff.addedNotes.count, color: theme.emerald)
                        diffStat(label: "Notes Removed", value: diff.removedNotes.count, color: theme.coral)
                        diffStat(label: "Notes Modified", value: diff.modifiedNotes.count, color: theme.amber)
                        diffStat(label: "Graph Nodes", value: diff.graphNodeDelta, color: diff.graphNodeDelta >= 0 ? theme.emerald : theme.coral, showSign: true)
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
                                    .foregroundStyle(note.wordCountDelta > 0 ? theme.emerald : theme.coral)
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
                                    .foregroundStyle(theme.resolved.accent.color)
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
                    .background(theme.resolved.accent.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(theme.resolved.accent.color)
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
        // Yield to let SwiftUI render the loading state before heavy work.
        Task { @MainActor in
            // Small yield so the spinner becomes visible before the synchronous work blocks.
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch is CancellationError {
                isLoading = false
                return
            } catch {
                Log.app.error(
                    "TimeMachineView: snapshot selection delay failed: \(error.localizedDescription, privacy: .public)"
                )
                isLoading = false
                return
            }
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
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            Log.app.error(
                "TimeMachineView: failed to encode restored workspace snapshot: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        guard let context = AppBootstrap.shared?.modelContainer.mainContext else {
            Log.app.error("TimeMachineView: missing main context for workspace restore")
            return
        }
        let ws = SDWorkspace(name: name, isAutoSave: false)
        ws.snapshotData = data
        ws.summary = state.summary
        ws.userNote = "Restored from Time Machine"
        context.insert(ws)
        do {
            try context.save()
        } catch {
            Log.app.error(
                "TimeMachineView: failed to persist restored workspace: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        // Load the workspace
        AppBootstrap.shared?.workspaceService.loadWorkspace(ws)
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch is CancellationError {
                return
            } catch {
                Log.app.error(
                    "TimeMachineView: dismiss delay failed: \(error.localizedDescription, privacy: .public)"
                )
                isPresented = false
                return
            }
            isPresented = false
        }
    }
}
