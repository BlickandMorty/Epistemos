import Testing
import Foundation
@testable import Epistemos

/// Epistemos Work settings tab.
/// Verifies the tab is wired through the SettingsView surface AND that it mounts the REAL native terminal
/// host (WorkTerminalHostView) + the honest seam health rows — so the work terminal infrastructure is
/// reachable, not a dead component. The exhaustive SettingsSection switches staying compilable is proven
/// by the build itself.
@Suite("Integrated settings — Epistemos Work tab")
struct WorkCloneSettingsTests {
    @Test("the work-clone tab is wired through SettingsView (enum + list + detail)")
    func tabWiredIntoSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(src.contains("case workClone = \"Epistemos Work\""))
        #expect(src.contains(".workClone,"))                       // appears in the sections list
        #expect(src.contains("case .workClone: WorkCloneSettingsView()"))  // detail wired
    }

    @Test("the work-clone view mounts the REAL terminal host + honest seam rows (no dead surface)")
    func mountsTerminalHostAndHealth() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkCloneSettingsView.swift")
        #expect(src.contains("WorkTerminalHostView("))    // the real native terminal, now reachable
        #expect(src.contains("WorkOpenCodeShellHealthRow")) // shell seam status
        #expect(src.contains("WorkBackendHealthRow"))       // secondary backend seam status
        // Honest runtime guidance, not a fake "it works".
        #expect(src.contains("honestly inert"))
    }

    @Test("visible launch buttons foreground Epistemos Work while engine names stay backgrounded")
    func launchButtonsUseEpistemosBranding() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkCloneSettingsView.swift")
        #expect(src.contains(#"Button("Open Epistemos Work preview")"#))
        #expect(src.contains(#"Button("Open Epistemos Work")"#))
        #expect(src.contains("Settings stay in Epistemos"))
        #expect(!src.contains("Each clone keeps its own settings"))
        #expect(!src.contains(#"Button("Open Work · OpenGUI engine workbench"#))
        #expect(!src.contains(#"Button("Open Work surface"#))
        #expect(!src.contains(#"Button("Open Epistemos Work engine bench")"#))
        #expect(!src.contains("Epistemos Work runs the OpenCode engine"))
        #expect(!src.contains("EPISTEMOS_WORK_TERMINAL_SMOKE"))
    }

    @Test("foreground runtime/status copy says Epistemos Work while engine contracts keep their real names")
    func foregroundRuntimeStatusCopyUsesEpistemosBranding() throws {
        let shell = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeShell.swift")
        let supervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkRuntimeSupervisor.swift")
        let strings = try loadMirroredSourceTextFile("Epistemos/Resources/Localizable.xcstrings")

        #expect(shell.contains("Epistemos Work runtime is unavailable on this build"))
        #expect(supervisor.contains("Epistemos Work runtime is not bundled yet"))
        #expect(supervisor.contains("WorkRuntimeListeningState"))
        #expect(supervisor.contains("outputTask?.cancel()"))
        #expect(strings.contains("Settings stay in Epistemos. Engine names stay in pickers and diagnostics"))
        #expect(strings.contains("The bundled default runtime is live"))
        #expect(strings.contains("Runtime identities stay in the picker and diagnostics"))
        #expect(!strings.contains("Open Epistemos Work engine bench"))

        for stale in [
            "Work terminal not wired yet",
            "terminal runtime off (opt-in, Pro)",
            "OpenCode work shell is not wired yet",
            "OpenCode runtime is not bundled yet",
            "OpenCode remains the first Work engine",
            "The OpenCode engine is bundled and live",
            "local OpenCode runtime supervisor",
            "OpenCode is first; donor runtimes",
            "The OpenCode runtime isn't linked",
        ] {
            #expect(!shell.contains(stale))
            #expect(!supervisor.contains(stale))
            #expect(!strings.contains(stale))
        }

        // Protected background contracts must remain named; these are not product-facing labels.
        let runtime = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        #expect(runtime.contains("OPENCODE_CONFIG"))
        #expect(runtime.contains("opencode.json"))
    }

    @Test("foreground Work chrome hides infrastructure names, but protected runtime contracts stay named")
    func foregroundChromeHidesInfrastructureNamesWithoutRenamingContracts() throws {
        let workURLs = try mirroredSourceFileURLs(
            under: "Epistemos/Work",
            includingExtensions: ["swift"])
        let settingsURLs = try mirroredSourceFileURLs(
            under: "Epistemos/Views/Settings",
            includingExtensions: ["swift"])
            .filter { $0.lastPathComponent.hasPrefix("Work") }
        let entryPointURLs = [
            try sourceMirrorURL(for: "Epistemos/App/EpistemosApp.swift"),
            try sourceMirrorURL(for: "Epistemos/Views/Settings/SettingsView.swift"),
        ]

        let foregroundPatterns = [
            #"Text\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Text\(\s*verbatim:\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Button\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Label\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"LabeledContent\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Picker\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Toggle\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"Menu\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"ProgressView\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"MotionTitle\(\s*text:\s*[^,\n]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"headline:\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"detail:\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"\.help\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"\.accessibilityLabel\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"\.navigationTitle\(\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
            #"window\.title\s*=\s*"[^"]*(OpenGUI|OpenCode|OpenWork|Goose|Work =|Open Work)"#,
        ]
        for url in workURLs + settingsURLs + entryPointURLs {
            let src = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            for pattern in foregroundPatterns {
                #expect(src.range(of: pattern, options: .regularExpression) == nil)
            }
        }

        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(settings.contains(#"case workClone = "Epistemos Work""#))
        #expect(settings.contains(#"case .workClone: WorkCloneSettingsView()"#))
        #expect(!settings.contains(#"case workClone = "Work (OpenCode)""#))

        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        #expect(app.contains(#"Button("Open Epistemos Work")"#))
        #expect(app.contains("WorkEngineSurfaceWindowController.shared.open()"))
        #expect(!app.contains("WorkWebSurfaceWindowController.shared.open()"))
        #expect(!app.contains(#"Button("Open Work"#))
        #expect(!app.contains(#"Button("Open OpenGUI"#))

        let webFallback = try loadMirroredSourceTextFile("Epistemos/Work/WorkWebSurfaceView.swift")
        #expect(webFallback.contains(#""Epistemos Work surface""#))
        #expect(webFallback.contains("nativeMCPStatusLabel"))
        #expect(webFallback.contains(#"detailRow("native tools", nativeMCPStatusLabel)"#))
        #expect(webFallback.contains("ScrollView {"))
        #expect(webFallback.contains(".truncationMode(.middle)"))
        #expect(!webFallback.contains(#""Epistemos Work SPA""#))

        let openCodeRuntime = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        #expect(openCodeRuntime.contains("OPENCODE_CONFIG"))
        #expect(openCodeRuntime.contains("opencode.json"))
        #expect(openCodeRuntime.contains("epistemos-vault"))

        let openGUISupervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUISupervisor.swift")
        #expect(openGUISupervisor.contains("WorkOpenGUISupervisor"))
        #expect(openGUISupervisor.contains("EPISTEMOS_OPENGUI_SIDECAR_ROOT"))
        #expect(openGUISupervisor.contains(#""opencode""#))
        #expect(openGUISupervisor.contains("startDrainingStderr"))
        #expect(openGUISupervisor.contains("stderrTask?.cancel()"))
        #expect(openGUISupervisor.contains("validatedConnectedHarnesses"))
        #expect(openGUISupervisor.contains("init connected no Work engines"))

        let openWorkSupervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenWorkSupervisor.swift")
        #expect(openWorkSupervisor.contains("OPENWORK_MANAGE_OPENCODE"))
        #expect(openWorkSupervisor.contains("OPENWORK_OPENCODE_BIN"))
        #expect(openWorkSupervisor.contains("WorkOpenWorkListeningState"))
        #expect(openWorkSupervisor.contains("outputTask?.cancel()"))

        let openCodeGate = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeShellGateStatus.swift")
        #expect(openCodeGate.contains("EPISTEMOS_WORK_OPENCODE_V0"))
        #expect(openCodeGate.contains("Other app modes"))
        #expect(!openCodeGate.contains("Chat and Act are unaffected"))
        #expect(!openCodeGate.contains("Chat/Act stay on their own engines"))
        #expect(!openCodeGate.contains("Chat/Act are unchanged"))

        let backendGate = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackendGateStatus.swift")
        #expect(backendGate.contains("EPISTEMOS_WORK_BACKEND_V0"))
        #expect(backendGate.contains("Other app modes"))
        #expect(!backendGate.contains("Chat and Act are unaffected"))
        #expect(!backendGate.contains("Chat and Act stay on their own engines"))
        #expect(!backendGate.contains("Chat and Act are unchanged"))
    }

    @Test("native Work surface keeps controls reachable while staying flat/minimal")
    func nativeWorkSurfaceKeepsControlsReachableWhileMinimal() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")
        let queue = try loadMirroredSourceTextFile("Epistemos/Work/WorkQueueListView.swift")
        let rail = try loadMirroredSourceTextFile("Epistemos/Work/WorkSessionRailView.swift")
        let engines = try loadMirroredSourceTextFile("Epistemos/Work/WorkEnginesPanelView.swift")
        let slash = try loadMirroredSourceTextFile("Epistemos/Work/WorkSlashCommandPopover.swift")

        for requiredSurfaceControl in [
            "WorkSessionRailView(store: sessions",
            "onNewMini: createMiniSession",
            "enginePicker",
            "modelPicker",
            "agentPicker",
            "WorkSlashCommandPopover(",
            "WorkQueueListView(queue: queue",
            "WorkPermissionCardView(",
            "WorkQuestionCardView(",
            "Button(action: submit)",
            #"Ask Epistemos Work…"#,
            "onQueue: queueInput",
            "onAfterPart: handleAfterPart",
            "showEnginesPanel = true",
            "startNewSession()",
            "supervisor.abort(sessionId:",
            ".frame(width: 22, height: 22)",
            ".frame(width: 24, height: 24)",
            #"help("Send prompt")"#,
            "supervisor.respondPermission",
            "supervisor.respondQuestion",
            "supervisor.rejectQuestion",
            "request.harnessID ?? (selectedEngine.isEmpty ? \"opencode\" : selectedEngine)",
            "scheduleLiveDiffRefresh",
            "surfaceActionError",
            "surfaceRuntimeError",
            "loadReadyEngines",
            "ScrollView {",
            "context: appContext",
            "refreshAppContext(nativeToolsAvailable: false)",
            "refreshAppContext(nativeToolsAvailable: provisioned)",
            "WorkNativeMCPHost.shared.updateContext(snapshot)",
            ".onChange(of: selectedModelID) { _, _ in refreshAppContext() }",
            ".onChange(of: selectedAgent) { _, _ in refreshAppContext() }",
            ".onChange(of: activeSessionID) { _, _ in refreshAppContext() }",
            ".onChange(of: queue.count) { _, _ in refreshAppContext() }",
            "preserveSessionOnEngineChange",
            "connectAndLoadResources(for: engine)",
            "selectedEngine = owningEngine",
            "try await supervisor.connect(owningEngine)",
            "guard activeSessionID == nil || activeSessionID == sessionID else { return }",
            "private func createMiniSession(parent: WorkSession)",
            "WorkSession.mini(id: sessionID, parent: parent",
            "sessions.focus(id: sessionID)",
            "afterPartAbortTriggeredSessionIDs",
            "triggerAfterPartIfNeeded(sessionID: sessionID)",
            #"eventType == "part.started" || eventType == "message.finished""#,
            "private func handleAfterPart",
            "Couldn't provision Epistemos native tools",
            "Couldn't reopen session: missing engine identity.",
            "Couldn't create mini session: missing engine identity.",
        ] {
            #expect(surface.contains(requiredSurfaceControl))
        }
        #expect(!surface.contains("try? await supervisor.respondPermission"))
        #expect(!surface.contains("try? await supervisor.respondQuestion"))
        #expect(!surface.contains("try? await supervisor.rejectQuestion"))
        #expect(!surface.contains("Task { try? await supervisor.abort(sessionId: active) }"))
        #expect(!surface.contains("_ = try? await supervisor.connect(engine)"))
        #expect(!surface.contains("(try? await supervisor.loadResources"))
        #expect(!surface.contains("(try? await supervisor.diagnose())"))
        #expect(!surface.contains("if let existing = try? await supervisor.listSessions"))
        #expect(!surface.contains("if let data = try? await supervisor.messages(sessionId: sessionID)"))
        #expect(!surface.contains(#"Message \(engineDisplayName(selectedEngine))…"#))

        for requiredQueueControl in [
            #"Button("Edit")"#,
            #"Button("Move to top")"#,
            #"Button("Move to bottom")"#,
            #"Button("Interrupt (abort + send next)")"#,
            #"Button("Steer after current part")"#,
            #"Button("Queue (cancel steer)")"#,
            #"Button("Remove", role: .destructive)"#,
            #"TextField("queued prompt""#,
            "queue.edit(id: id, text: trimmed)",
            #"case .afterPart: return "steer""#,
            "onSendNow(taken)",
        ] {
            #expect(queue.contains(requiredQueueControl))
        }

        for requiredRailControl in [
            #"Image(systemName: "plus.circle")"#,
            ".frame(width: 18, height: 18)",
            ".frame(width: 14, height: 14)",
            ".truncationMode(.tail)",
            #"Button("Promote to tab")"#,
            #"Button("Close", role: .destructive)"#,
        ] {
            #expect(rail.contains(requiredRailControl))
        }

        for requiredEngineEntry in [
            #""opencode", "OpenCode", true"#,
            #""codex", "Codex", true"#,
            #""claude-code", "Claude Code", true"#,
            "providerRow(provider)",
            #"label("EPISTEMOS CONTEXT")"#,
            "contextRow(row)",
            #"statusText = "not wired""#,
            ".frame(minHeight: 20)",
            ".frame(minHeight: 18)",
            ".fixedSize(horizontal: true, vertical: false)",
            ".truncationMode(.middle)",
            ".frame(maxWidth: 180, alignment: .trailing)",
        ] {
            #expect(engines.contains(requiredEngineEntry))
        }
        #expect(!engines.contains("adapter soon"))

        for requiredSlashPopoverGuard in [
            "ScrollView {",
            "LazyVStack(alignment: .leading, spacing: 0)",
            ".frame(maxHeight: 220)",
            ".frame(maxWidth: 460, alignment: .leading)",
            ".frame(maxWidth: 190, alignment: .leading)",
            ".frame(minHeight: 26)",
            ".truncationMode(.tail)",
        ] {
            #expect(slash.contains(requiredSlashPopoverGuard))
        }

        #expect(!surface.contains("display:none"))
        #expect(!surface.contains("hidden until owner"))
    }

    @Test("Epistemos surface branding does not rename donor runtime contracts")
    func epistemosBrandingDoesNotRenameDonorContracts() throws {
        let openCodeRuntime = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        for requiredContract in [
            "opencode-runtime",
            "opencode",
            "opencode.json",
            "OPENCODE_CONFIG",
            ".config/opencode",
            "epistemos-vault",
            "epistemos-native",
            ".posixPermissions: 0o600",
        ] {
            #expect(openCodeRuntime.contains(requiredContract))
        }
        for forbiddenRename in [
            "epistemos-runtime",
            "epistemos.json",
            "EPISTEMOS_CONFIG",
            ".config/epistemos",
        ] {
            #expect(!openCodeRuntime.contains(forbiddenRename))
        }

        let spaServer = try loadMirroredSourceTextFile("Epistemos/Work/WorkSPAServer.swift")
        for requiredContract in [
            "openwork.server.token",
            "openwork.server.active",
            "openwork.server.list",
            "openwork.preferences",
            "openwork.themePref",
        ] {
            #expect(spaServer.contains(requiredContract))
        }
        for forbiddenRename in [
            "epistemos.server.token",
            "epistemos.server.active",
            "epistemos.server.list",
            "epistemos.preferences",
            "epistemos.themePref",
        ] {
            #expect(!spaServer.contains(forbiddenRename))
        }

        let openWorkSupervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenWorkSupervisor.swift")
        for requiredContract in [
            "openwork-server",
            "OPENWORK_MANAGE_OPENCODE",
            "OPENWORK_OPENCODE_BIN",
        ] {
            #expect(openWorkSupervisor.contains(requiredContract))
        }
        for forbiddenRename in [
            "epistemos-server",
            "EPISTEMOS_MANAGE_OPENCODE",
            "EPISTEMOS_OPENCODE_BIN",
        ] {
            #expect(!openWorkSupervisor.contains(forbiddenRename))
        }

        let openGUISupervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUISupervisor.swift")
        #expect(openGUISupervisor.contains("OPENGUI_OPENCODE_PORT"))
        #expect(openGUISupervisor.contains("EPISTEMOS_OPENGUI_SIDECAR_ROOT"))
        #expect(!openGUISupervisor.contains("EPISTEMOS_OPENCODE_PORT"))
    }

    @Test("hidden OpenGUI storage paths stay stable until there is an explicit migration")
    func hiddenOpenGUIStoragePathsStayStableUntilMigration() throws {
        let supervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUISupervisor.swift")
        let workspace = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUIWorkspace.swift")

        #expect(supervisor.contains("Epistemos/OpenGUIRuntime"))
        #expect(workspace.contains("Epistemos/WorkOpenGUI/workspace"))

        for unsafeSilentRename in [
            "Epistemos/WorkRuntime/opengui",
            "Epistemos/WorkRuntime/opengui-runtime",
            "Epistemos/WorkRuntime/open-gui",
            "Epistemos/WorkRuntime/workspace",
        ] {
            #expect(!supervisor.contains(unsafeSilentRename))
            #expect(!workspace.contains(unsafeSilentRename))
        }
    }
}
