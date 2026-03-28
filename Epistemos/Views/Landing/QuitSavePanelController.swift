import AppKit
import SwiftData
import SwiftUI

// MARK: - Global Overlay Controller
// Manages floating NSPanel overlays that appear above ALL windows (note editors, mini chats, etc.).
// Used for workspace switcher, session intelligence, time machine, save workspace, and quit dialog.
// Borderless panel with frosted glass blur and rounded corners — no traffic lights.

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

    /// Show a SwiftUI view as a global floating overlay with scrim.
    func show<Content: View>(
        width: CGFloat = 480,
        height: CGFloat = 500,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        guard panel == nil else { return }
        guard let screen = NSScreen.main else { return }
        self.dismissHandler = onDismiss

        let isDark = AppBootstrap.shared?.uiState.theme.isDark ?? (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)

        // Scrim — full-screen dim
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

        let scrimColor = isDark ? NSColor.black.withAlphaComponent(0.35) : NSColor.gray.withAlphaComponent(0.15)
        let scrimView = NSView(frame: screen.frame)
        scrimView.wantsLayer = true
        scrimView.layer?.backgroundColor = scrimColor.cgColor
        scrim.contentView = scrimView

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(scrimClicked))
        scrimView.addGestureRecognizer(clickRecognizer)
        scrim.orderFront(nil)
        self.scrimWindow = scrim

        // Panel — borderless, rounded corners, frosted glass
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
        floatingPanel.isMovableByWindowBackground = true
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

        // Frosted glass backdrop with rounded corners
        let cornerRadius: CGFloat = 16
        let blurView = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelRect.size))
        blurView.material = isDark ? .hudWindow : .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = cornerRadius
        blurView.layer?.masksToBounds = true

        swiftUIView.translatesAutoresizingMaskIntoConstraints = false
        blurView.addSubview(swiftUIView)
        NSLayoutConstraint.activate([
            swiftUIView.topAnchor.constraint(equalTo: blurView.topAnchor),
            swiftUIView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
            swiftUIView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            swiftUIView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
        ])

        // Container view with shadow and rounded clip
        let containerView = NSView(frame: NSRect(origin: .zero, size: panelRect.size))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.masksToBounds = true
        containerView.addSubview(blurView)
        blurView.frame = containerView.bounds
        blurView.autoresizingMask = [.width, .height]

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

// MARK: - Session Intelligence (uses GlobalOverlayController)

@MainActor
enum GlobalSessionIntelligence {
    static func show() {
        GlobalOverlayController.shared.show(width: 620, height: 540) {
            GlobalSessionIntelligenceContent(onDismiss: {
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
    @State private var saveMode: SaveMode = .saveNew
    @State private var workspaceName = ""
    @State private var sessionNote = ""
    @State private var existingWorkspaces: [SDWorkspace] = []
    @State private var selectedExistingId: String?
    @State private var aiSuggestion = ""
    @State private var isLoadingAISuggestion = false

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
                    HStack(spacing: 8) {
                        ForEach(SaveMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { saveMode = mode }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.icon).font(.system(size: 11, weight: .medium))
                                    Text(mode.rawValue).font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(saveMode == mode ? theme.resolved.accent.color.opacity(0.12) : theme.resolved.foreground.color.opacity(0.04), in: Capsule())
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
                                    .background(selectedExistingId == ws.id ? theme.resolved.accent.color.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 8))
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

                    // AI summary suggestion
                    if isLoadingAISuggestion {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text("Generating summary...").font(.system(size: 11, design: .rounded)).foregroundStyle(theme.textTertiary)
                        }
                    } else if !aiSuggestion.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("AI Suggestion").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(theme.textTertiary)
                                Spacer()
                                Button("Use This") {
                                    sessionNote = aiSuggestion
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.resolved.accent.color)
                            }
                            Text(aiSuggestion)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                                .italic()
                                .lineLimit(3)
                        }
                        .padding(10)
                        .background(theme.resolved.foreground.color.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
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
                    .padding(.horizontal, 14).padding(.vertical, 8).background(theme.resolved.foreground.color.opacity(0.05), in: Capsule())
                Button(isQuitFlow ? "Save & Quit" : "Save") { performSave() }
                    .buttonStyle(.plain).foregroundStyle(.white).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8).background(theme.resolved.accent.color, in: Capsule())
                    .disabled(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(saveMode == .saveNew && workspaceName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
        }
        .foregroundStyle(theme.resolved.foreground.color)
        .onAppear {
            existingWorkspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
            selectedExistingId = existingWorkspaces.first?.id
            // Pre-fill from existing workspace summary if updating
            if !existingWorkspaces.isEmpty {
                saveMode = .updateCurrent
            }
            // Generate AI summary suggestion
            Task { @MainActor in
                isLoadingAISuggestion = true
                let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
                if let ws = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(
                    FetchDescriptor(predicate: predicate)
                ).first, !ws.summary.isEmpty {
                    aiSuggestion = ws.summary
                }
                isLoadingAISuggestion = false
            }
        }
    }

    private var statePreview: some View {
        let n = NoteWindowManager.shared.orderedPageIds().count
        let c = MiniChatWindowController.shared.openChatIds.count
        let g = HologramController.shared.isVisible
        return HStack(spacing: 16) {
            if n > 0 { Label("\(n) note\(n == 1 ? "" : "s")", systemImage: "doc.text.fill") }
            if c > 0 { Label("\(c) chat\(c == 1 ? "" : "s")", systemImage: "bubble.left.and.bubble.right.fill") }
            if g { Label("Graph", systemImage: "point.3.connected.trianglepath.dotted") }
        }.font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(theme.textTertiary)
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
            if let id = selectedExistingId, let existing = existingWorkspaces.first(where: { $0.id == id }) {
                if let data = try? JSONEncoder().encode(ws.captureSnapshot()) {
                    existing.snapshotData = data; existing.updatedAt = Date()
                    if !note.isEmpty { existing.userNote = note }
                    try? AppBootstrap.shared?.modelContainer.mainContext.save()
                }
            } else { ws.autoSave() }
        }
        onComplete(true)
    }
}

// MARK: - Thin wrappers that delegate to existing overlay views with a dismiss callback

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

struct GlobalSessionIntelligenceContent: View {
    let onDismiss: () -> Void
    @State private var isPresented = true
    var body: some View {
        SessionIntelligenceOverlay(isPresented: $isPresented)
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
