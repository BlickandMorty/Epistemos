import AppKit
import SwiftData
import SwiftUI

// MARK: - Global Overlay Controller
// Manages floating NSPanel overlays that appear above ALL windows (note editors, mini chats, etc.).
// Used for workspace switcher, time machine, save workspace, and quit dialog.
// Borderless panel with SwiftUI pixel-panel chrome — no traffic lights.

/// NSPanel subclass that accepts key status for text input in floating overlays.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        // ESC key dismisses the overlay
        Task { @MainActor in
            GlobalOverlayController.shared.dismiss()
        }
    }
}

@MainActor
final class GlobalOverlayController {
    static let shared = GlobalOverlayController()

    private var panel: NSPanel?
    private var scrimWindow: NSWindow?
    var dismissHandler: (() -> Void)?

    private init() {}

    var isShowing: Bool { panel != nil }

    /// Show a SwiftUI view as a global floating overlay with an invisible outside-click layer.
    func show<Content: View>(
        width: CGFloat = 480,
        height: CGFloat = 500,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        guard panel == nil else { return }
        guard let screen = NSScreen.main else { return }
        self.dismissHandler = onDismiss

        // Outside-click layer. It stays visually clear so command panels do not dim the home surface.
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
        scrim.isRestorable = false
        scrim.ignoresMouseEvents = false

        let scrimView = NSView(frame: screen.frame)
        scrimView.wantsLayer = true
        scrimView.layer?.backgroundColor = NSColor.clear.cgColor
        scrim.contentView = scrimView

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(scrimClicked))
        scrimView.addGestureRecognizer(clickRecognizer)
        scrim.orderFront(nil)
        self.scrimWindow = scrim

        // Panel — borderless, SwiftUI draws the pixel panel.
        let panelRect = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.midY - height / 2,
            width: width,
            height: height
        )

        let floatingPanel = KeyablePanel(
            contentRect: panelRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        floatingPanel.isOpaque = false
        floatingPanel.backgroundColor = .clear
        floatingPanel.hasShadow = true
        floatingPanel.level = .modalPanel
        floatingPanel.isReleasedWhenClosed = false
        floatingPanel.isRestorable = false
        floatingPanel.isMovableByWindowBackground = false
        floatingPanel.becomesKeyOnlyIfNeeded = false
        floatingPanel.hidesOnDeactivate = false
        floatingPanel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]

        // Build the SwiftUI hosting view
        let swiftUIContent = content()
        let swiftUIView: NSView
        if let bootstrap = AppBootstrap.shared {
            swiftUIView = NSHostingView(rootView:
                swiftUIContent
                    .withAppEnvironment(bootstrap)
                    .modelContainer(bootstrap.modelContainer)
            )
        } else {
            swiftUIView = NSHostingView(rootView: swiftUIContent)
        }

        swiftUIView.translatesAutoresizingMaskIntoConstraints = false

        let containerView = NSView(frame: NSRect(origin: .zero, size: panelRect.size))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(swiftUIView)
        NSLayoutConstraint.activate([
            swiftUIView.topAnchor.constraint(equalTo: containerView.topAnchor),
            swiftUIView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            swiftUIView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            swiftUIView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        floatingPanel.contentView = containerView
        floatingPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = floatingPanel
    }

    func dismiss() {
        panel?.close()
        panel = nil
        scrimWindow?.close()
        scrimWindow = nil
        let handler = dismissHandler
        dismissHandler = nil
        handler?()
    }

    @objc private func scrimClicked() {
        dismiss()
    }
}

// MARK: - Quit Save Panel (uses GlobalOverlayController)

@MainActor
enum QuitSavePanelController {
    static func showQuitSave(onComplete: @escaping (Bool) -> Void) {
        GlobalOverlayController.shared.show(width: 460, height: 480, onDismiss: {
            // If dismissed via scrim click, treat as cancel
            NSApp.reply(toApplicationShouldTerminate: false)
        }) {
            QuitSaveContent(isQuitFlow: true) { shouldQuit in
                GlobalOverlayController.shared.dismissHandler = nil // prevent double-fire
                GlobalOverlayController.shared.dismiss()
                onComplete(shouldQuit)
            }
        }
    }

    static func showSave() {
        GlobalOverlayController.shared.show(width: 460, height: 480) {
            QuitSaveContent(isQuitFlow: false) { _ in
                GlobalOverlayController.shared.dismiss()
            }
        }
    }
}

// MARK: - Workspace Switcher (uses GlobalOverlayController)

@MainActor
enum GlobalWorkspaceSwitcher {
    static func show() {
        GlobalOverlayController.shared.show(width: 500, height: 520) {
            GlobalWorkspaceSwitcherContent(onDismiss: {
                GlobalOverlayController.shared.dismiss()
            })
        }
    }
}

// MARK: - Time Machine (uses GlobalOverlayController)

@MainActor
enum GlobalTimeMachine {
    static func show() {
        GlobalOverlayController.shared.show(width: 740, height: 560) {
            GlobalTimeMachineContent(onDismiss: {
                GlobalOverlayController.shared.dismiss()
            })
        }
    }
}

// MARK: - Inline Save Content

private struct QuitSaveContent: View {
    let isQuitFlow: Bool
    let onComplete: (Bool) -> Void

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saveMode: SaveMode = .saveNew
    @State private var workspaceName = ""
    @State private var sessionNote = ""
    @State private var existingWorkspaces: [SDWorkspace] = []
    @State private var selectedExistingId: String?
    @State private var appearFrame = 0

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
            HStack {
                PixelGlyph(kind: .save, accent: theme.resolved.accent.color)
                    .frame(width: 24, height: 24)
                PixelPanelTitle(
                    text: isQuitFlow ? "Save Before Quitting?" : "Save Workspace",
                    theme: theme,
                    size: 15
                )
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(SaveMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { saveMode = mode }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.icon).font(.system(size: 11, weight: .medium))
                                    Text(mode.rawValue).font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(saveMode == mode ? theme.resolved.accent.color.opacity(0.12) : theme.resolved.foreground.color.opacity(0.04), in: Rectangle())
                                .foregroundStyle(saveMode == mode ? theme.resolved.accent.color : theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    statePreview

                    if saveMode == .saveNew {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Workspace Name").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(theme.textTertiary)
                            TextField("e.g. Essay Research", text: $workspaceName).textFieldStyle(.roundedBorder).font(.system(size: 13))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Update Existing").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(theme.textTertiary)
                            ForEach(existingWorkspaces, id: \.id) { ws in
                                Button { selectedExistingId = ws.id } label: {
                                    HStack {
                                        Image(systemName: selectedExistingId == ws.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedExistingId == ws.id ? theme.resolved.accent.color : theme.textTertiary)
                                        Text(ws.name).font(.system(size: 12, weight: .medium, design: .rounded))
                                        Spacer()
                                        Text(ws.updatedAt, style: .relative).font(.system(size: 10, design: .rounded)).foregroundStyle(theme.textTertiary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(selectedExistingId == ws.id ? theme.resolved.accent.color.opacity(0.06) : .clear, in: Rectangle())
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session Note").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(theme.textTertiary)
                        TextField("What were you working on?", text: $sessionNote, axis: .vertical)
                            .textFieldStyle(.roundedBorder).font(.system(size: 13)).lineLimit(3, reservesSpace: true)
                    }

                }
                .padding(.horizontal, 24).padding(.vertical, 16)
            }

            Divider().opacity(0.3)

            HStack(spacing: 12) {
                if isQuitFlow {
                    Button("Quit Without Saving") { onComplete(true) }
                        .buttonStyle(.plain).foregroundStyle(theme.textTertiary).font(.system(size: 12, weight: .medium, design: .rounded))
                }
                Spacer()
                Button("Cancel") { onComplete(false) }
                    .buttonStyle(.plain).foregroundStyle(theme.textSecondary).font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8).background(theme.resolved.foreground.color.opacity(0.05), in: Rectangle())
                Button(isQuitFlow ? "Save & Quit" : "Save") { performSave() }
                    .buttonStyle(.plain).foregroundStyle(.white).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8).background(theme.resolved.accent.color, in: Rectangle())
                    .disabled(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
        }
        .foregroundStyle(theme.resolved.foreground.color)
        .pixelPanel(theme: theme)
        .pixelStepAppear(frame: appearFrame)
        .background(Color.clear)
        .onAppear {
            Task { @MainActor in
                await PixelStepMotion.play(reduceMotion: reduceMotion) { frame in
                    appearFrame = frame
                }
            }
            existingWorkspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
            selectedExistingId = existingWorkspaces.first?.id
            // Default to updating the latest workspace when one already exists.
            if !existingWorkspaces.isEmpty {
                saveMode = .updateCurrent
            }
        }
    }

    private var statePreview: some View {
        let n = NoteWindowManager.shared.orderedPageIds().count
        let g = HologramController.shared.isVisible
        return HStack(spacing: 16) {
            if n > 0 { Label("\(n) note\(n == 1 ? "" : "s")", systemImage: "doc.text.fill") }
            if g { Label("Graph", systemImage: "point.3.connected.trianglepath.dotted") }
        }.font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(theme.textTertiary)
    }

    private func performSave() {
        guard let bootstrap = AppBootstrap.shared else {
            Log.app.error("QuitSavePanelController: missing app bootstrap during workspace save")
            onComplete(false)
            return
        }
        let ws = bootstrap.workspaceService
        let modelContext = bootstrap.modelContainer.mainContext
        let note = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        switch saveMode {
        case .saveNew:
            let name = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            guard let saved = ws.saveWorkspace(name: name) else {
                Log.app.error("QuitSavePanelController: failed to save workspace")
                onComplete(false)
                return
            }
            if !note.isEmpty {
                let originalSavedUserNote = saved.userNote
                saved.userNote = note
                do {
                    try modelContext.save()
                } catch {
                    saved.userNote = originalSavedUserNote
                    let message = LandingDiagnostics.logMessage(
                        for: error,
                        fallback: "QuitSavePanelController: failed to persist session note"
                    )
                    Log.app.error(
                        "\(message, privacy: .public)"
                    )
                    onComplete(false)
                    return
                }
            }
        case .updateCurrent:
            if let id = selectedExistingId, let existing = existingWorkspaces.first(where: { $0.id == id }) {
                let data: Data
                let snapshot = ws.captureSnapshot()
                let liveSummary = WorkspaceSynthesisBuilder.summary(for: snapshot)
                do {
                    data = try JSONEncoder().encode(snapshot)
                } catch {
                    let message = LandingDiagnostics.logMessage(
                        for: error,
                        fallback: "QuitSavePanelController: failed to encode workspace update"
                    )
                    Log.app.error("\(message, privacy: .public)")
                    onComplete(false)
                    return
                }
                let originalSnapshotData = existing.snapshotData
                let originalUpdatedAt = existing.updatedAt
                let originalExistingUserNote = existing.userNote
                let originalSummary = existing.summary
                let originalLastSummaryAt = existing.lastSummaryAt
                existing.snapshotData = data
                existing.updatedAt = Date()
                existing.summary = liveSummary
                existing.lastSummaryAt = Date()
                if !note.isEmpty {
                    existing.userNote = note
                }
                do {
                    try modelContext.save()
                } catch {
                    existing.snapshotData = originalSnapshotData
                    existing.updatedAt = originalUpdatedAt
                    existing.userNote = originalExistingUserNote
                    existing.summary = originalSummary
                    existing.lastSummaryAt = originalLastSummaryAt
                    let message = LandingDiagnostics.logMessage(
                        for: error,
                        fallback: "QuitSavePanelController: failed to save updated workspace"
                    )
                    Log.app.error(
                        "\(message, privacy: .public)"
                    )
                    onComplete(false)
                    return
                }
            } else {
                ws.autoSave()
            }
        }
        onComplete(true)
    }
}

// MARK: - Thin wrappers that delegate to existing overlay views with a dismiss callback

struct SaveWorkspaceInlineView: View {
    @Binding var isPresented: Bool

    var body: some View {
        QuitSaveContent(isQuitFlow: false) { _ in
            isPresented = false
            HomeWindowInputFocus.restoreAfterOverlayDismiss()
        }
    }
}

struct GlobalWorkspaceSwitcherContent: View {
    let onDismiss: () -> Void
    @State private var isPresented = true
    var body: some View {
        WorkspaceSwitcherOverlay(isPresented: $isPresented)
            .onChange(of: isPresented) { _, new in
                if !new { onDismiss() }
            }
    }
}

struct GlobalTimeMachineContent: View {
    let onDismiss: () -> Void
    @State private var isPresented = true
    var body: some View {
        TimeMachineView(isPresented: $isPresented)
            .onChange(of: isPresented) { _, new in
                if !new { onDismiss() }
            }
    }
}
