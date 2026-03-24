import SwiftData
import SwiftUI

// MARK: - Workspace Switcher Overlay
// A centered command-palette-style overlay for cycling through saved workspaces.
// Triggered by Cmd+Ctrl+W. Keyboard navigation: arrow keys to cycle, Enter to load, Esc to dismiss.

struct WorkspaceSwitcherOverlay: View {
    @Environment(UIState.self) private var ui
    @Binding var isPresented: Bool

    @State private var workspaces: [SDWorkspace] = []
    @State private var selectedIndex: Int = 0
    @State private var appeared = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Workspaces")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("esc to close")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider()
                    .opacity(0.3)

                if workspaces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(theme.textTertiary)
                        Text("No saved workspaces")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                        Text("Save your current layout with \u{2318}\u{2303}S")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
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
                            withAnimation(.easeOut(duration: 0.1)) {
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
            .frame(width: 480)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
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
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    private func keyHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.foreground.opacity(0.06))
                )
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
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
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
            isPresented = false
        }
    }

    private func loadWorkspaceInSpace(_ workspace: SDWorkspace) {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
            // Set all restored windows to follow the active space
            for window in NoteWindowManager.shared.openPageIds.compactMap({ NoteWindowManager.shared.window(for: $0) }) {
                window.collectionBehavior.insert(.moveToActiveSpace)
            }
            for chatId in MiniChatWindowController.shared.openChatIds {
                // Mini chat windows already have .moveToActiveSpace by default
            }
            isPresented = false
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}

// MARK: - Workspace Row

private struct WorkspaceRow: View {
    let workspace: SDWorkspace
    let isSelected: Bool
    let theme: EpistemosTheme
    let action: () -> Void
    let onOpenInSpace: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    .frame(width: 20)

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

                    // AI summary
                    if !workspace.summary.isEmpty {
                        Text(workspace.summary)
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
                                .foregroundStyle(theme.accent.opacity(0.6))
                            Text(workspace.userNote)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? theme.accent.opacity(0.12)
                            : (isHovered ? theme.foreground.opacity(0.04) : .clear)
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var snapshotSummary: String {
        guard let snapshot = try? JSONDecoder().decode(
            WorkspaceSnapshot.self, from: workspace.snapshotData
        ) else { return "—" }
        var parts: [String] = []
        if !snapshot.openNoteTabs.isEmpty {
            parts.append("\(snapshot.openNoteTabs.count) note\(snapshot.openNoteTabs.count == 1 ? "" : "s")")
        }
        if !snapshot.openMiniChatIds.isEmpty {
            parts.append("\(snapshot.openMiniChatIds.count) chat\(snapshot.openMiniChatIds.count == 1 ? "" : "s")")
        }
        if snapshot.graphOverlay.visibility != .hidden {
            parts.append("graph")
        }
        return parts.isEmpty ? "empty workspace" : parts.joined(separator: ", ")
    }
}
