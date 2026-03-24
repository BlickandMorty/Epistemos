import SwiftData
import SwiftUI

// MARK: - Workspace Save Panel
// A rich overlay panel for saving workspaces. Used for both Cmd+Ctrl+S (manual save)
// and Cmd+Q (save-on-quit). Provides clear options: save new, update existing, or branch.
// Includes name field, session note, and shows current workspace context.

struct WorkspaceSavePanel: View {
    @Environment(UIState.self) private var ui
    @Binding var isPresented: Bool

    /// If true, quitting the app after save. Shows "Quit Without Saving" option.
    var isQuitFlow: Bool = false
    /// Called when the panel completes (save or cancel). For quit flow, passes true to proceed with quit.
    var onComplete: ((Bool) -> Void)?

    @State private var saveMode: SaveMode = .saveNew
    @State private var workspaceName = ""
    @State private var sessionNote = ""
    @State private var existingWorkspaces: [SDWorkspace] = []
    @State private var selectedExistingId: String?
    @State private var appeared = false

    private var theme: EpistemosTheme { ui.theme }
    private var scrimColor: Color { theme.isDark ? .black : .gray }
    private var scrimOpacity: Double { theme.isDark ? 0.4 : 0.2 }
    private var panelShadow: Color { theme.isDark ? .black.opacity(0.3) : .black.opacity(0.1) }
    private var panelStroke: Color { theme.isDark ? .white.opacity(0.08) : .black.opacity(0.06) }

    enum SaveMode: String, CaseIterable {
        case saveNew = "Save as New"
        case updateCurrent = "Update Current"

        var icon: String {
            switch self {
            case .saveNew: "plus.square"
            case .updateCurrent: "arrow.triangle.2.circlepath"
            }
        }
    }

    var body: some View {
        ZStack {
            scrimColor.opacity(appeared ? scrimOpacity : 0)
                .ignoresSafeArea()
                .onTapGesture { cancel() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isQuitFlow ? "Save Before Quitting?" : "Save Workspace")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider().opacity(0.3)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Save mode picker
                        HStack(spacing: 8) {
                            ForEach(SaveMode.allCases, id: \.self) { mode in
                                saveModeButton(mode)
                            }
                        }
                        .padding(.top, 4)

                        // Context: what's currently open
                        currentStatePreview

                        // Name field
                        if saveMode == .saveNew {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Workspace Name")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                                TextField("e.g. Essay Research, Sprint Planning", text: $workspaceName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                            }
                        } else {
                            // Show existing workspaces to update
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Select Workspace to Update")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)

                                if existingWorkspaces.isEmpty {
                                    Text("No saved workspaces yet. Switch to 'Save as New'.")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(theme.textTertiary)
                                } else {
                                    ForEach(existingWorkspaces, id: \.id) { ws in
                                        existingWorkspaceRow(ws)
                                    }
                                }
                            }
                        }

                        // Session note
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Session Note")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.textTertiary)
                            TextField("What were you working on? (optional)", text: $sessionNote, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .frame(maxHeight: 360)

                Divider().opacity(0.3)

                // Action buttons
                HStack(spacing: 12) {
                    if isQuitFlow {
                        Button("Quit Without Saving") {
                            dismiss()
                            onComplete?(true)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    }

                    Spacer()

                    Button("Cancel") { cancel() }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.foreground.opacity(0.05), in: Capsule())

                    Button(isQuitFlow ? "Save & Quit" : "Save") {
                        performSave()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(theme.accent, in: Capsule())
                    .disabled(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .frame(width: 460)
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
            .foregroundStyle(theme.foreground)
        }
        .background {
            Button(action: { cancel() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            existingWorkspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
            if !existingWorkspaces.isEmpty {
                selectedExistingId = existingWorkspaces.first?.id
            }
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    // MARK: - Components

    private func saveModeButton(_ mode: SaveMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { saveMode = mode }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(mode.rawValue)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                saveMode == mode
                    ? theme.accent.opacity(0.12)
                    : theme.foreground.opacity(0.04),
                in: Capsule()
            )
            .foregroundStyle(saveMode == mode ? theme.accent : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var currentStatePreview: some View {
        let noteCount = NoteWindowManager.shared.orderedPageIds().count
        let chatCount = MiniChatWindowController.shared.openChatIds.count
        let graphOpen = HologramController.shared.isVisible

        return HStack(spacing: 16) {
            if noteCount > 0 {
                Label("\(noteCount) note\(noteCount == 1 ? "" : "s")", systemImage: "doc.text.fill")
            }
            if chatCount > 0 {
                Label("\(chatCount) chat\(chatCount == 1 ? "" : "s")", systemImage: "bubble.left.and.bubble.right.fill")
            }
            if graphOpen {
                Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textTertiary)
    }

    private func existingWorkspaceRow(_ ws: SDWorkspace) -> some View {
        Button {
            selectedExistingId = ws.id
        } label: {
            HStack {
                Image(systemName: selectedExistingId == ws.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedExistingId == ws.id ? theme.accent : theme.textTertiary)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ws.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    Text(ws.updatedAt, style: .relative)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedExistingId == ws.id
                    ? theme.accent.opacity(0.06)
                    : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func performSave() {
        guard let ws = AppBootstrap.shared?.workspaceService else { return }
        let note = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)

        switch saveMode {
        case .saveNew:
            let name = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            ws.saveWorkspace(name: name)
            if !note.isEmpty, let saved = ws.listWorkspaces().first(where: { $0.name == name }) {
                saved.userNote = note
                try? AppBootstrap.shared?.modelContainer.mainContext.save()
            }
        case .updateCurrent:
            if let existingId = selectedExistingId,
               let existing = existingWorkspaces.first(where: { $0.id == existingId }) {
                // Update existing workspace with current snapshot
                let snapshot = ws.captureSnapshot()
                if let data = try? JSONEncoder().encode(snapshot) {
                    existing.snapshotData = data
                    existing.updatedAt = Date()
                    if !note.isEmpty { existing.userNote = note }
                    try? AppBootstrap.shared?.modelContainer.mainContext.save()
                }
            } else {
                // No existing selected — fall back to auto-save
                ws.autoSave()
            }
        }

        dismiss()
        onComplete?(true)
    }

    private func cancel() {
        dismiss()
        onComplete?(false)
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}
