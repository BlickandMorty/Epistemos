import AppKit
import SwiftUI

// MARK: - Quit Save Panel Controller
// Manages a floating NSPanel that appears above ALL windows (note editors, mini chats, etc.)
// when the user quits the app. Uses the same floating panel pattern as the graph overlay
// so the user always sees the save dialog regardless of which window has focus.

@MainActor
final class QuitSavePanelController {
    static let shared = QuitSavePanelController()

    private var panel: NSPanel?
    private var scrimWindow: NSWindow?

    private init() {}

    func show(isQuitFlow: Bool, onComplete: @escaping (Bool) -> Void) {
        guard panel == nil else { return }

        // Create a full-screen scrim behind the panel
        guard let screen = NSScreen.main else {
            onComplete(false)
            return
        }

        // Scrim window — covers entire screen with semi-transparent background
        let scrim = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        scrim.isOpaque = false
        scrim.backgroundColor = .clear
        scrim.level = .floating
        scrim.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        scrim.isReleasedWhenClosed = false
        scrim.ignoresMouseEvents = false

        let isDark = AppBootstrap.shared?.uiState.theme.isDark ?? true
        let scrimColor = isDark ? NSColor.black.withAlphaComponent(0.4) : NSColor.gray.withAlphaComponent(0.2)
        let scrimView = NSView(frame: screen.frame)
        scrimView.wantsLayer = true
        scrimView.layer?.backgroundColor = scrimColor.cgColor
        scrim.contentView = scrimView

        // Click scrim to cancel (for non-quit flow)
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(scrimClicked))
        scrimView.addGestureRecognizer(clickRecognizer)

        scrim.orderFront(nil)
        self.scrimWindow = scrim

        // Panel window — centered floating panel with the SwiftUI save UI
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 480
        let panelRect = NSRect(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let floatingPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        floatingPanel.isOpaque = false
        floatingPanel.backgroundColor = .clear
        floatingPanel.hasShadow = true
        floatingPanel.level = .floating + 1 // Above scrim
        floatingPanel.isReleasedWhenClosed = false
        floatingPanel.titlebarAppearsTransparent = true
        floatingPanel.titleVisibility = .hidden
        floatingPanel.isMovableByWindowBackground = true
        floatingPanel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]

        // Wrap WorkspaceSavePanel in an NSHostingView
        // Using a simpler inline SwiftUI view since WorkspaceSavePanel manages its own Binding
        let saveView = QuitSaveContent(
            isQuitFlow: isQuitFlow,
            onComplete: { [weak self] shouldQuit in
                self?.dismiss()
                onComplete(shouldQuit)
            }
        )

        let hostingView: NSView
        if let bootstrap = AppBootstrap.shared {
            let themed = saveView
                .withAppEnvironment(bootstrap)
                .modelContainer(bootstrap.modelContainer)
            hostingView = NSHostingView(rootView: themed)
        } else {
            hostingView = NSHostingView(rootView: saveView)
        }

        floatingPanel.contentView = hostingView
        floatingPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = floatingPanel
    }

    func dismiss() {
        panel?.close()
        panel = nil
        scrimWindow?.close()
        scrimWindow = nil
    }

    @objc private func scrimClicked() {
        // Cancel — don't quit
        dismiss()
        NSApp.reply(toApplicationShouldTerminate: false)
    }
}

// MARK: - Inline Save Content (for the floating panel)

private struct QuitSaveContent: View {
    let isQuitFlow: Bool
    let onComplete: (Bool) -> Void

    @Environment(UIState.self) private var ui
    @State private var saveMode: SaveMode = .saveNew
    @State private var workspaceName = ""
    @State private var sessionNote = ""
    @State private var existingWorkspaces: [SDWorkspace] = []
    @State private var selectedExistingId: String?

    private var theme: EpistemosTheme { ui.theme }

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
                    // Mode picker
                    HStack(spacing: 8) {
                        ForEach(SaveMode.allCases, id: \.self) { mode in
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
                    }

                    // Current state preview
                    currentStatePreview

                    // Name or existing picker
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Select Workspace to Update")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.textTertiary)
                            if existingWorkspaces.isEmpty {
                                Text("No saved workspaces yet.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                            } else {
                                ForEach(existingWorkspaces, id: \.id) { ws in
                                    Button {
                                        selectedExistingId = ws.id
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedExistingId == ws.id ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedExistingId == ws.id ? theme.accent : theme.textTertiary)
                                            Text(ws.name)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                            Spacer()
                                            Text(ws.updatedAt, style: .relative)
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(theme.textTertiary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            selectedExistingId == ws.id ? theme.accent.opacity(0.06) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
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

            Divider().opacity(0.3)

            // Action buttons
            HStack(spacing: 12) {
                if isQuitFlow {
                    Button("Quit Without Saving") { onComplete(true) }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                Spacer()
                Button("Cancel") { onComplete(false) }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.foreground.opacity(0.05), in: Capsule())

                Button(isQuitFlow ? "Save & Quit" : "Save") { performSave() }
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
        .frame(width: 460, height: 460)
        .onAppear {
            existingWorkspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
            selectedExistingId = existingWorkspaces.first?.id
        }
    }

    private var currentStatePreview: some View {
        let noteCount = NoteWindowManager.shared.orderedPageIds().count
        let chatCount = MiniChatWindowController.shared.openChatIds.count
        let graphOpen = HologramController.shared.isVisible

        return HStack(spacing: 16) {
            if noteCount > 0 { Label("\(noteCount) note\(noteCount == 1 ? "" : "s")", systemImage: "doc.text.fill") }
            if chatCount > 0 { Label("\(chatCount) chat\(chatCount == 1 ? "" : "s")", systemImage: "bubble.left.and.bubble.right.fill") }
            if graphOpen { Label("Graph", systemImage: "point.3.connected.trianglepath.dotted") }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textTertiary)
    }

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
                let snapshot = ws.captureSnapshot()
                if let data = try? JSONEncoder().encode(snapshot) {
                    existing.snapshotData = data
                    existing.updatedAt = Date()
                    if !note.isEmpty { existing.userNote = note }
                    try? AppBootstrap.shared?.modelContainer.mainContext.save()
                }
            } else {
                ws.autoSave()
            }
        }
        onComplete(true)
    }
}
