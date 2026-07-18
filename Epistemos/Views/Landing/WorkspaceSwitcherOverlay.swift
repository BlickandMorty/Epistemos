import SwiftData
import SwiftUI

private enum WorkspaceSwitcherOverlayTiming {
    nonisolated static func dismissDelay() -> Duration { .milliseconds(150) }
}

enum WorkspaceSwitcherPresentation: Equatable {
    case overlay
    case inline
}

// MARK: - Workspace Switcher Overlay
// A centered command-palette-style overlay for cycling through saved workspaces.
// Triggered by Cmd+Ctrl+W. Keyboard navigation: arrow keys to cycle, Enter to load, Esc to dismiss.

struct WorkspaceSwitcherOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let presentation: WorkspaceSwitcherPresentation

    @State private var workspaces: [SDWorkspace] = []
    @State private var selectedIndex: Int = 0
    @State private var appearFrame = 0

    private var theme: EpistemosTheme { ui.theme }

    init(
        isPresented: Binding<Bool>,
        presentation: WorkspaceSwitcherPresentation = .overlay
    ) {
        _isPresented = isPresented
        self.presentation = presentation
    }

    var body: some View {
        Group {
            if presentation == .overlay {
                ZStack {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { dismiss() }

                    panel
                }
            } else {
                panel
            }
        }
        .onKeyPress(.upArrow) { cycleSelection(-1); return .handled }
        .onKeyPress(.downArrow) { cycleSelection(1); return .handled }
        .onKeyPress(.return) { loadSelected(); return .handled }
        .background {
            Button(action: { dismiss() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            refreshWorkspaces()
            Task { @MainActor in
                await PixelStepMotion.play(reduceMotion: reduceMotion) { frame in
                    appearFrame = frame
                }
            }
        }
    }

    private var panel: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    PixelGlyph(kind: .workspace, accent: theme.resolved.accent.color)
                        .frame(width: 24, height: 24)
                    PixelPanelTitle(text: "Workspaces", theme: theme, size: 15)
                    Spacer()
                    Text("esc to close")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider()
                    .opacity(0.3)

                if workspaces.isEmpty {
                    VStack(spacing: 12) {
                        PixelGlyph(kind: .workspace, accent: theme.textTertiary)
                            .frame(width: 40, height: 40)
                        Text("No saved workspaces")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                        Text("Save your current layout with \u{2318}\u{2303}S")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 2) {
                                ForEach(Array(workspaces.enumerated()), id: \.element.id) { index, workspace in
                                    WorkspaceRow(
                                        workspace: workspace,
                                        isSelected: index == selectedIndex,
                                        theme: theme,
                                        presentation: presentation,
                                        action: { loadWorkspace(workspace) },
                                        onOpenInSpace: { loadWorkspaceInSpace(workspace) }
                                    )
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 320)
                        .onChange(of: selectedIndex) { _, newIndex in
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.1)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }

                    Divider()
                        .opacity(0.3)

                    // Footer hints
                    HStack(spacing: 16) {
                        keyHint(key: "\u{2191}\u{2193}", label: "navigate")
                        keyHint(key: "\u{21A9}", label: "load")
                        keyHint(key: "\u{2318}\u{2303}S", label: "save current")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .frame(width: presentation == .inline ? 500 : 480)
            .pixelPanel(theme: theme)
            .pixelStepAppear(frame: appearFrame)
            .foregroundStyle(theme.resolved.foreground.color)
        }
    }

    private func keyHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Rectangle()
                        .fill(theme.resolved.foreground.color.opacity(0.06))
                )
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func refreshWorkspaces() {
        workspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
        selectedIndex = 0
    }

    private func cycleSelection(_ delta: Int) {
        guard !workspaces.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + workspaces.count) % workspaces.count
    }

    private func loadSelected() {
        guard !workspaces.isEmpty else { return }
        loadWorkspace(workspaces[selectedIndex])
    }

    private func loadWorkspace(_ workspace: SDWorkspace) {
        performAfterDismiss {
            AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
        }
    }

    private func loadWorkspaceInSpace(_ workspace: SDWorkspace) {
        performAfterDismiss {
            AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
            // Set all restored windows to follow the active space
            for window in NoteWindowManager.shared.openPageIds.compactMap({ NoteWindowManager.shared.window(for: $0) }) {
                window.collectionBehavior.insert(.moveToActiveSpace)
            }
        }
    }

    private func dismiss() {
        performAfterDismiss()
    }

    private func performAfterDismiss(_ action: (@MainActor () -> Void)? = nil) {
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.15)) { appearFrame = 0 }
        if reduceMotion {
            action?()
            isPresented = false
            return
        }
        Task { @MainActor in
            guard await pause(WorkspaceSwitcherOverlayTiming.dismissDelay()) else { return }
            action?()
            isPresented = false
        }
    }

    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Workspace Row

private struct WorkspaceRow: View {
    let workspace: SDWorkspace
    let isSelected: Bool
    let theme: EpistemosTheme
    let presentation: WorkspaceSwitcherPresentation
    let action: () -> Void
    let onOpenInSpace: () -> Void

    @State private var isHovered = false
    @State private var decodedSnapshot: WorkspaceSnapshot?
    @State private var cachedDiff: WorkspaceDiffSummary?

    init(
        workspace: SDWorkspace,
        isSelected: Bool,
        theme: EpistemosTheme,
        presentation: WorkspaceSwitcherPresentation,
        action: @escaping () -> Void,
        onOpenInSpace: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.isSelected = isSelected
        self.theme = theme
        self.presentation = presentation
        self.action = action
        self.onOpenInSpace = onOpenInSpace
        _decodedSnapshot = State(initialValue: Self.decodeSnapshot(from: workspace.snapshotData))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PixelGlyph(
                    kind: .workspace,
                    accent: isSelected ? theme.resolved.accent.color : theme.textSecondary
                )
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(workspace.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        Text(workspace.updatedAt, style: .relative)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.textTertiary)
                    }

                    Text(snapshotSummary)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)

                    let summary = workspace.presentedSummary
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.textSecondary.opacity(0.8))
                            .lineLimit(2)
                            .italic()
                    }

                    // User note
                    if !workspace.userNote.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.resolved.accent.color.opacity(0.6))
                            Text(workspace.userNote)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Drift indicator — shows how workspace diverged from current state
                    driftIndicator
                }

                // Open in Space button
                if isHovered || isSelected {
                    Button {
                        onOpenInSpace()
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in current desktop space")
                    .padding(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Rectangle()
                    .fill(
                        isSelected
                            ? theme.resolved.accent.color.opacity(0.12)
                            : (isHovered ? theme.resolved.foreground.color.opacity(0.04) : .clear)
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover {
            isHovered = $0
            refreshDiffIfNeeded()
        }
        .onAppear {
            refreshDiffIfNeeded()
        }
        .onChange(of: isSelected) { _, _ in
            refreshDiffIfNeeded()
        }
        .onChange(of: workspace.snapshotData) { _, newValue in
            decodedSnapshot = Self.decodeSnapshot(from: newValue)
            cachedDiff = nil
            refreshDiffIfNeeded()
        }
    }

    private var snapshotSummary: String {
        guard let snapshot = decodedSnapshot else { return "—" }
        var parts: [String] = []
        if !snapshot.openNoteTabs.isEmpty {
            parts.append("\(snapshot.openNoteTabs.count) note\(snapshot.openNoteTabs.count == 1 ? "" : "s")")
        }
        if snapshot.graphOverlay.visibility != .hidden {
            parts.append("graph")
        }
        return parts.isEmpty ? "empty workspace" : parts.joined(separator: ", ")
    }

    /// Shows how the saved workspace differs from the current live state.
    @ViewBuilder
    private var driftIndicator: some View {
        if shouldShowDriftIndicator,
           let diff = cachedDiff,
           diff.hasPresentedChanges {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.5))
                    Text("Changes since save:")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary.opacity(0.7))
                }
                let parts = buildDiffParts(diff)
                if !parts.isEmpty {
                    Text(parts.joined(separator: " \u{2022} "))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary.opacity(0.7))
                }
                // Word count deltas
                ForEach(diff.wordCountDeltas.prefix(2), id: \.title) { entry in
                    Text("\(entry.title): \(entry.delta > 0 ? "+" : "")\(entry.delta) words")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(entry.delta > 0 ? theme.resolved.accent.color.opacity(0.6) : theme.textTertiary.opacity(0.6))
                }
            }
        } else {
            let drift = computeDrift()
            if !drift.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.5))
                    Text(drift)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary.opacity(0.7))
                }
            }
        }
    }

    private var shouldShowDriftIndicator: Bool {
        presentation == .overlay || isHovered || isSelected
    }

    private func refreshDiffIfNeeded() {
        guard shouldShowDriftIndicator, cachedDiff == nil else { return }
        cachedDiff = AppBootstrap.shared?.workspaceService.changesSinceLastSave(for: workspace)
    }

    private func buildDiffParts(_ diff: WorkspaceDiffSummary) -> [String] {
        var parts: [String] = []
        let chatActivity = diff.presentedChatActivity
        if diff.notesOpened > 0 { parts.append("+\(diff.notesOpened) opened") }
        if diff.notesClosed > 0 { parts.append("-\(diff.notesClosed) closed") }
        if chatActivity.started > 0 { parts.append("+\(chatActivity.started) chats") }
        if chatActivity.messagesSent > 0 { parts.append("\(chatActivity.messagesSent) msgs") }
        if diff.graphNodesAdded > 0 { parts.append("+\(diff.graphNodesAdded) nodes") }
        return parts
    }

    /// Compares saved workspace snapshot against current live state.
    private func computeDrift() -> String {
        guard let snapshot = decodedSnapshot else { return "" }

        let currentPageIds = Set(NoteWindowManager.shared.orderedPageIds())
        let savedPageIds = Set(snapshot.openNoteTabs.map(\.rootPageId))
        let addedNotes = currentPageIds.subtracting(savedPageIds).count
        let removedNotes = savedPageIds.subtracting(currentPageIds).count

        var parts: [String] = []
        if addedNotes > 0 { parts.append("+\(addedNotes) note\(addedNotes == 1 ? "" : "s")") }
        if removedNotes > 0 { parts.append("-\(removedNotes) note\(removedNotes == 1 ? "" : "s")") }

        // Time drift
        let hours = Int(Date().timeIntervalSince(workspace.updatedAt) / 3600)
        if hours > 0 && parts.isEmpty {
            parts.append("\(hours)h since save")
        }

        return parts.joined(separator: " \u{2022} ")
    }

    private static func decodeSnapshot(from data: Data) -> WorkspaceSnapshot? {
        do {
            return try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        } catch {
            let message = LandingDiagnostics.logMessage(
                for: error,
                fallback: "WorkspaceSwitcherOverlay: failed to decode workspace snapshot"
            )
            Log.app.error(
                "\(message, privacy: .public)"
            )
            return nil
        }
    }
}
