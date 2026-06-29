import AppKit
import Darwin
import Foundation
import Testing
import WebKit
@testable import Epistemos

@Suite("Goose live integration", .serialized)
struct GooseLiveIntegrationTests {
    @Test(
        "live Goose serve accepts Swift ACP initialize over WebSocket"
    )
    @MainActor
    func liveGooseServeAcceptsSwiftACPInitialize() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-initialize.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(proofName: "acp-initialize") { binary, connection, client, progressURL in
            appendLiveProgress("before initialize", to: progressURL)
            let initialized = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize response",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )
            appendLiveProgress("after initialize protocol=\(initialized.protocolVersion)", to: progressURL)
            await client.close()

            let proof = [
                "phase0_live_acp_initialize=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "protocol_version=\(initialized.protocolVersion)",
                "agent_name=\(initialized.agentInfo?.name ?? "unknown")",
                "agent_version=\(initialized.agentInfo?.version ?? "unknown")",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard initialized.protocolVersion == 1 else {
                throw GooseLiveIntegrationError.runtimeFailed("Unexpected ACP protocol version \(initialized.protocolVersion).")
            }
            guard let agentInfo = initialized.agentInfo,
                  !agentInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !agentInfo.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("ACP initialize response did not include a complete agent identity.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_initialize=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live ACP initialize proof log was not written.")
            }
        }
    }

    @Test(
        "live Goose serve creates a session, streams a prompt, and reaches end_turn"
    )
    @MainActor
    func liveGooseServeCompletesPromptEndTurn() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-prompt.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(proofName: "acp-prompt") { binary, connection, client, progressURL in
            let session = try await initializeLiveSession(client: client, progressURL: progressURL)
            let promptText = "Reply with exactly this phrase and no markdown: phase0 live goose prompt ready"
            appendLiveProgress("before session/prompt", to: progressURL)
            let response = try await withLiveTimeout(
                seconds: 90,
                description: "ACP prompt end_turn response",
                onTimeout: { await client.close() },
                operation: { try await client.prompt(sessionId: session.sessionId, text: promptText) }
            )
            let events = await client.drainQueuedEvents()
            let agentText = agentMessageText(from: events)
            appendLiveProgress(
                "after prompt stop=\(response.stopReason.rawValue) events=\(events.count) agent_chars=\(agentText.count)",
                to: progressURL
            )

            let proof = [
                "phase0_live_acp_prompt=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "session_id=\(session.sessionId)",
                "stop_reason=\(response.stopReason.rawValue)",
                "event_count=\(events.count)",
                "saw_agent_message=\(containsAgentMessage(events))",
                "saw_agent_thought=\(containsAgentThought(events))",
                "saw_tool_call=\(containsToolCall(events))",
                "saw_permission_request=\(containsPermissionRequest(events))",
                "agent_text_chars=\(agentText.count)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard response.stopReason == .endTurn else {
                throw GooseLiveIntegrationError.runtimeFailed("Prompt stopped with \(response.stopReason.rawValue), not end_turn.")
            }
            guard containsAgentMessage(events) else {
                throw GooseLiveIntegrationError.runtimeFailed("Prompt completed without an agent_message_chunk session update.")
            }
            guard !agentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Prompt completed without non-empty agent text.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_prompt=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live ACP prompt proof log was not written.")
            }
        }
    }

    @Test(
        "live Goose serve routes a tool permission request and emits a tool result"
    )
    @MainActor
    func liveGooseServeRoutesToolPermission() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-permission.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(
            proofName: "acp-permission",
            gooseMode: "approve"
        ) { binary, connection, client, progressURL in
            let session = try await initializeLiveSession(client: client, progressURL: progressURL)
            let promptText = "Use the developer shell tool to run `printf phase0_permission_probe`, then tell me the exact output."
            appendLiveProgress("before permission prompt", to: progressURL)
            let promptTask = Task {
                try await client.prompt(sessionId: session.sessionId, text: promptText)
            }
            defer { promptTask.cancel() }

            var events: [GooseACPClientEvent] = []
            var selectedOptionID: String?
            var permissionToolCallID: String?
            for _ in 0..<80 {
                let event = try await withLiveTimeout(
                    seconds: 45,
                    description: "ACP permission request",
                    onTimeout: { await client.close() },
                    operation: { try await client.receiveEvent() }
                )
                events.append(event)
                guard case .permissionRequest(let requestID, let request) = event else {
                    continue
                }
                guard let optionID = permissionAllowOptionID(for: request) else {
                    throw GooseLiveIntegrationError.runtimeFailed("Permission request did not include an allow option.")
                }
                appendLiveProgress("permission request option=\(optionID)", to: progressURL)
                permissionToolCallID = request.toolCall.toolCallId
                try await client.respondToPermission(
                    requestId: requestID,
                    response: .selected(optionId: optionID)
                )
                selectedOptionID = optionID
                break
            }

            guard let selectedOptionID else {
                throw GooseLiveIntegrationError.runtimeFailed("Prompt did not request native permission.")
            }
            guard let permissionToolCallID else {
                throw GooseLiveIntegrationError.runtimeFailed("Permission request did not include a tool call id.")
            }

            let resultEvents = try await withLiveTimeout(
                seconds: 90,
                description: "ACP permission tool result update",
                onTimeout: { await client.close() },
                operation: {
                    try await waitForPermissionToolResult(
                        client: client,
                        toolCallID: permissionToolCallID,
                        progressURL: progressURL
                    )
                }
            )
            events += resultEvents
            events += await client.drainQueuedEvents()
            let agentText = agentMessageText(from: events)
            appendLiveProgress(
                "after permission result events=\(events.count) agent_chars=\(agentText.count)",
                to: progressURL
            )

            let proof = [
                "phase0_live_acp_permission=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "session_id=\(session.sessionId)",
                "goose_mode=approve",
                "event_count=\(events.count)",
                "saw_agent_message=\(containsAgentMessage(events))",
                "saw_agent_thought=\(containsAgentThought(events))",
                "saw_tool_call=\(containsToolCall(events))",
                "saw_tool_result=\(containsToolResult(events, toolCallID: permissionToolCallID))",
                "saw_permission_request=\(containsPermissionRequest(events))",
                "selected_permission_option=\(selectedOptionID)",
                "agent_text_chars=\(agentText.count)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard containsPermissionRequest(events) else {
                throw GooseLiveIntegrationError.runtimeFailed("Permission prompt completed without a permission request.")
            }
            guard containsToolCall(events) else {
                throw GooseLiveIntegrationError.runtimeFailed("Permission prompt completed without a tool call update.")
            }
            guard containsToolResult(events, toolCallID: permissionToolCallID) else {
                throw GooseLiveIntegrationError.runtimeFailed("Permission prompt completed without a tool result update.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_permission=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live ACP permission proof log was not written.")
            }
        }
    }

    @Test(
        "live Goose serve answers the Phase 0 read-only custom ACP subset"
    )
    @MainActor
    func liveGooseServeAnswersReadOnlyCustomACPSubset() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-custom-readonly.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(proofName: "acp-custom-readonly") { binary, connection, client, progressURL in
            let session = try await initializeLiveSession(client: client, progressURL: progressURL)
            appendLiveProgress("before custom ACP reads", to: progressURL)
            try await proveLiveGooseCustomACPReadOnlySubset(
                binary: binary,
                connection: connection,
                client: client,
                progressURL: progressURL,
                proofURL: proofURL,
                session: session
            )
        }
    }

    @Test(
        "live Goose WebView boots the staged web UI through the narrow shim"
    )
    @MainActor
    func liveGooseWebViewBootsStagedUIThroughNarrowShim() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-webview-boot.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withFreshGooseWebUIArtifact(proofName: "webview-boot") { index in
            try await withLiveGooseRuntime(proofName: "webview-boot") { binary, connection, progressURL in
            let bootstrap = GooseWebBootstrap(
                baseURL: connection.baseURL,
                secretKey: connection.secretKey,
                config: GooseWebConfig(version: "phase0-webview-boot")
            )
            let page = GooseWebSurfaceView.makeBootProbePage(
                bootstrap: bootstrap,
                gooseUIRoot: index.deletingLastPathComponent()
            )
            let uiServer = try await startGooseWebUILoopbackServer(root: index.deletingLastPathComponent())
            defer { uiServer.server.stop() }
            appendLiveProgress("before webview boot", to: progressURL)
            _ = page.load(URLRequest(url: GooseWebSurfaceView.loopbackURL(baseURL: uiServer.baseURL, route: "/?")))
            let probe = try await waitForGooseWebBootProbe(page: page, progressURL: progressURL)

            let proof = [
                "phase0_live_webview_boot=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_binary_path=\(binary.path)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "web_ui_index=\(index.path)",
                "web_ui_root=\(index.deletingLastPathComponent().path)",
                "web_ui_origin=\(uiServer.baseURL.absoluteString)",
                "webview_url=\(probe.href)",
                "ready_state=\(probe.readyState)",
                "root_children=\(probe.rootChildren)",
                "has_electron=\(probe.hasElectron)",
                "has_epistemos_goose=\(probe.hasEpistemosGoose)",
                "config_use_acp_chat=\(probe.configUseACPChat)",
                "config_host=\(probe.configHost)",
                "ledger_get_acp_url=\(probe.ledgerGetAcpUrl)",
                "ledger_directory_chooser=\(probe.ledgerDirectoryChooser)",
                "ledger_open_external=\(probe.ledgerOpenExternal)",
                "acp_bridge=\(probe.acpBridge)",
                "permission_bridge=\(probe.permissionBridge)",
                "native_affordance_bridge=\(probe.nativeAffordanceBridge)",
                "acp_trace_bridge=\(probe.acpTraceBridge)",
                "directory_chooser_bridge=\(probe.directoryChooserBridge)",
                "open_external_bridge=\(probe.openExternalBridge)",
                "secret_bridge=\(probe.secretBridge)",
                "acp_url_matches_runtime=\(probe.acpUrl == connection.acpWebSocketURL?.absoluteString)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard probe.readyState == "interactive" || probe.readyState == "complete" else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot did not reach a loaded document.")
            }
            guard probe.rootChildren > 0 else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot did not mount the React root.")
            }
            guard probe.hasElectron, probe.hasEpistemosGoose else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot did not expose the narrow host shim.")
            }
            guard probe.configUseACPChat,
                  probe.configHost == connection.baseURL.absoluteString.trimmedTrailingSlash else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot did not receive the runtime ACP config.")
            }
            guard probe.acpUrl == connection.acpWebSocketURL?.absoluteString else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot ACP URL did not match the runtime.")
            }
            guard probe.ledgerGetAcpUrl == GooseWebAffordanceDisposition.implementedRuntime.rawValue,
                  probe.ledgerDirectoryChooser == GooseWebAffordanceDisposition.implementedNative.rawValue,
                  probe.ledgerOpenExternal == GooseWebAffordanceDisposition.implementedNative.rawValue,
                  probe.acpBridge,
                  probe.permissionBridge,
                  probe.nativeAffordanceBridge,
                  probe.acpTraceBridge,
                  probe.directoryChooserBridge,
                  probe.openExternalBridge,
                  probe.secretBridge else {
                throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot did not expose required shim affordances.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_webview_boot=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live WebView boot proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.hostIOSurface, .portableSurfaceAssets],
                proofURL: proofURL,
                via: "embedded WebView boot shim ledger + native affordance bridge",
                details: [
                    "acp_url_matches_runtime": "\(probe.acpUrl == connection.acpWebSocketURL?.absoluteString)",
                    "web_ui_index": index.path,
                    "goose_binary": binary.path,
                ]
            )
            await settleGooseWebPageForLiveSuite(page, progressURL: progressURL)
            }
        }
    }

    @Test(
        "live Goose WebView drives native file, recipe, recents, and handler-routed window affordances"
    )
    @MainActor
    func liveGooseWebViewDrivesNativeHostAffordances() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-webview-native-affordances.log")
        try? FileManager.default.removeItem(at: proofURL)

        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-affordances-\(UUID().uuidString)", isDirectory: true)
        let supportRoot = testRoot.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let projectRoot = testRoot.appendingPathComponent("Project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let suiteName = "Epistemos.Goose.NativeAffordance.Live.\(UUID().uuidString)"
        guard let preferences = UserDefaults(suiteName: suiteName) else {
            throw GooseLiveIntegrationError.runtimeFailed("Could not create isolated native affordance preferences.")
        }
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let nativeBridge = GooseWebNativeAffordanceBridge(
            handlers: [
                "showMessageBox": { _ in
                    [
                        "response": 0,
                        "checkboxChecked": false,
                        "epistemosHostedModalBypass": true,
                    ]
                },
                "launchApp": { _ in true },
                "refreshApp": { _ in true },
                "closeApp": { _ in true },
            ],
            initialScopedFileRoots: [projectRoot],
            applicationSupportRoot: supportRoot,
            preferences: preferences
        )

        try await withFreshGooseWebUIArtifact(proofName: "webview-native-affordances") { index in
            try await withLiveGooseRuntime(proofName: "webview-native-affordances") { binary, connection, progressURL in
            let bootstrap = GooseWebBootstrap(
                baseURL: connection.baseURL,
                secretKey: connection.secretKey,
                config: GooseWebConfig(version: "phase0-webview-native-affordances")
            )
            let page = GooseWebSurfaceView.makeBootProbePage(
                bootstrap: bootstrap,
                gooseUIRoot: index.deletingLastPathComponent(),
                nativeAffordanceBridge: nativeBridge
            )
            let uiServer = try await startGooseWebUILoopbackServer(root: index.deletingLastPathComponent())
            defer { uiServer.server.stop() }
            appendLiveProgress("before webview native affordance boot", to: progressURL)
            _ = page.load(URLRequest(url: GooseWebSurfaceView.loopbackURL(baseURL: uiServer.baseURL, route: "/?")))
            _ = try await waitForGooseWebBootProbe(page: page, progressURL: progressURL)

            appendLiveProgress("before webview native affordance probe", to: progressURL)
            let probe = try await runGooseWebNativeAffordanceProbe(
                page: page,
                projectRoot: projectRoot
            )
            appendLiveProgress("after webview native affordance probe pass=\(probe.passes)", to: progressURL)

            let proof = [
                "phase0_live_webview_native_affordances=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_binary_path=\(binary.path)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "web_ui_index=\(index.path)",
                "web_ui_origin=\(uiServer.baseURL.absoluteString)",
                "project_root=\(projectRoot.path)",
                "confirm_response=\(probe.confirmResponse)",
                "confirm_handler_override=true",
                "mcp_app_handler_override=true",
                "goosehints_write=\(probe.writeOK)",
                "goosehints_read_found=\(probe.readFound)",
                "goosehints_read_matches=\(probe.readMatches)",
                "goosehints_listed=\(probe.listContainsGoosehints)",
                "recent_added=\(probe.recentAdded)",
                "recent_listed=\(probe.recentListed)",
                "recipe_trust_before=\(probe.recipeTrustBefore)",
                "recipe_trust_recorded=\(probe.recipeTrustRecorded)",
                "recipe_trust_after=\(probe.recipeTrustAfter)",
                "mcp_app_launch=\(probe.launchOK)",
                "mcp_app_refresh=\(probe.refreshOK)",
                "mcp_app_close=\(probe.closeOK)",
                "request_native_affordance_bridge=\(probe.requestNativeAffordanceBridge)",
                "errors=\(probe.errors.joined(separator: "|"))",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard probe.passes else {
                throw GooseLiveIntegrationError.runtimeFailed(
                    "Goose WebView native affordance probe failed: \(probe.errors.joined(separator: "; "))"
                )
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_webview_native_affordances=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live WebView native affordance proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.gooseHintsEdit, .recipeTrustPersistence],
                proofURL: proofURL,
                via: "embedded WebView Electron shim -> native host affordances",
                details: [
                    "confirm_response": "\(probe.confirmResponse)",
                    "confirm_handler_override": "true",
                    "mcp_app_handler_override": "true",
                    "project_root": projectRoot.path,
                    "mcp_app_lifecycle": "\(probe.launchOK && probe.refreshOK && probe.closeOK)",
                ]
            )
            await settleGooseWebPageForLiveSuite(page, progressURL: progressURL)
            }
        }
    }

    #if !EPISTEMOS_APP_STORE
    @Test(
        "live real Goose Electron fallback launches through the Swift menu launcher"
    )
    @MainActor
    func liveGooseElectronFallbackLaunchesThroughSwiftLauncher() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-electron-launcher.log")
        let progressURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-electron-launcher-progress.log")
        try? FileManager.default.removeItem(at: proofURL)
        try? FileManager.default.removeItem(at: progressURL)

        guard let workspace = GooseElectronFallbackLauncher.resolveWorkspace() else {
            throw GooseLiveIntegrationError.runtimeFailed("No real Goose Electron fallback workspace was found.")
        }
        let debugPort = try await availableElectronDebugPort()
        let launcher = GooseElectronFallbackLauncher()
        defer { launcher.stop() }

        appendLiveProgress("start cwd=\(workspace.uiRoot.path) debug_port=\(debugPort)", to: progressURL)
        guard launcher.launch(workspace: workspace, debugPort: debugPort) else {
            throw GooseLiveIntegrationError.runtimeFailed("Swift launcher did not start real Goose Electron fallback.")
        }
        appendLiveProgress("launched status=\(launcher.status)", to: progressURL)

        let version: ElectronCDPVersion
        let pageCount: Int
        do {
            version = try await waitForElectronCDPVersion(port: debugPort, progressURL: progressURL)
            pageCount = try await waitForElectronCDPPageCount(port: debugPort, progressURL: progressURL)
        } catch {
            appendLiveProgress("launcher_diagnostic=\(launcher.lastDiagnostic ?? "<none>")", to: progressURL)
            throw error
        }
        let pid: Int32
        switch launcher.status {
        case .running(let runningPID):
            pid = runningPID
        default:
            throw GooseLiveIntegrationError.runtimeFailed("Swift launcher did not report a running Electron fallback process.")
        }

        let proof = [
            "phase0_goose_electron_launcher=pass",
            "cwd=\(workspace.uiRoot.path)",
            "command=pnpm \(GooseElectronFallbackLauncher.launchArguments().joined(separator: " "))",
            "debug_port=\(debugPort)",
            "browser=\(version.browser)",
            "page_count=\(pageCount)",
            "pid=\(pid)",
            "cleanup=launcher_stop_process_tree",
        ].joined(separator: "\n") + "\n"
        try proof.write(to: proofURL, atomically: true, encoding: .utf8)

        guard pageCount > 0 else {
            throw GooseLiveIntegrationError.runtimeFailed("Real Goose Electron fallback launched without a renderer page.")
        }
        guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_goose_electron_launcher=pass") else {
            throw GooseLiveIntegrationError.runtimeFailed("Live Electron launcher proof log was not written.")
        }
    }
    #endif
}

@MainActor
private func runGooseWebNativeAffordanceProbe(
    page: WebPage,
    projectRoot: URL
) async throws -> GooseWebNativeAffordanceProbe {
    let result = try await page.callJavaScript(
        """
        const projectRoot = \(gooseLiveJavaScriptStringLiteral(projectRoot.path));
        const gooseHintsPath = `${projectRoot}/.goosehints`;
        const gooseHintsBody = "phase0 goosehints webview native affordance proof";
        const recipe = {
          id: "phase0-native-affordance-recipe",
          title: "Phase 0 native affordance recipe",
          description: "Live proof recipe trust persists through the Goose WebView shim.",
          instructions: "Return phase0.",
          activities: [{ id: "phase0", title: "Phase 0", prompt: "Return phase0." }]
        };
        const app = {
          name: "phase0_mcp_app",
          title: "Phase 0 MCP App",
          text: "<!doctype html><html><body><main id='probe'>phase0 mcp app</main></body></html>",
          width: 240,
          height: 160,
          resizable: false
        };
        const errors = [];
        const out = {
          confirmResponse: -1,
          writeOK: false,
          readFound: false,
          readMatches: false,
          listContainsGoosehints: false,
          recentAdded: false,
          recentListed: false,
          recipeTrustBefore: true,
          recipeTrustRecorded: false,
          recipeTrustAfter: false,
          launchOK: false,
          refreshOK: false,
          closeOK: false,
          requestNativeAffordanceBridge: typeof window.epistemos?.goose?.requestNativeAffordance === "function",
          errors
        };
        try {
          const message = await window.electron.showMessageBox({
            type: "question",
            message: "Epistemos Phase 0 confirm dialog proof",
            detail: "This dialog is auto-accepted by the live WebView test.",
            buttons: ["Allow", "Cancel"],
            defaultId: 0,
            cancelId: 1
          });
          out.confirmResponse = Number(message?.response ?? -1);
        } catch (error) {
          errors.push(`showMessageBox:${error?.message || error}`);
        }
        try {
          out.writeOK = await window.electron.writeFile(gooseHintsPath, gooseHintsBody);
          const read = await window.electron.readFile(gooseHintsPath);
          out.readFound = read?.found === true;
          out.readMatches = read?.file === gooseHintsBody;
          const files = await window.electron.listFiles(projectRoot);
          out.listContainsGoosehints = Array.isArray(files) && files.includes(".goosehints");
        } catch (error) {
          errors.push(`goosehints:${error?.message || error}`);
        }
        try {
          out.recentAdded = await window.electron.addRecentDir(projectRoot);
          const recents = await window.electron.listRecentDirs();
          out.recentListed = Array.isArray(recents) && recents.includes(projectRoot);
        } catch (error) {
          errors.push(`recents:${error?.message || error}`);
        }
        try {
          out.recipeTrustBefore = await window.electron.hasAcceptedRecipeBefore(recipe);
          out.recipeTrustRecorded = await window.electron.recordRecipeHash(recipe);
          out.recipeTrustAfter = await window.electron.hasAcceptedRecipeBefore(recipe);
        } catch (error) {
          errors.push(`recipeTrust:${error?.message || error}`);
        }
        try {
          await window.electron.launchApp(app);
          out.launchOK = true;
          await window.electron.refreshApp(app);
          out.refreshOK = true;
          await window.electron.closeApp(app.name);
          out.closeOK = true;
        } catch (error) {
          errors.push(`mcpApp:${error?.message || error}`);
        }
        return JSON.stringify(out);
        """
    )
    guard let json = result as? String,
          let data = json.data(using: .utf8) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose WebView native affordance probe did not return JSON.")
    }
    return try JSONDecoder().decode(GooseWebNativeAffordanceProbe.self, from: data)
}

nonisolated private func gooseLiveJavaScriptStringLiteral(_ value: String) -> String {
    let data = try? JSONEncoder().encode(value)
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
}

nonisolated private func liveGooseBinaryURL() -> URL? {
    if let binaryPath = ProcessInfo.processInfo.environment["EPISTEMOS_GOOSE_BINARY"],
       FileManager.default.isExecutableFile(atPath: binaryPath) {
        return URL(fileURLWithPath: binaryPath)
    }

    let targetRoot = liveRepoRootURL().appendingPathComponent(".research-clones/work/goose/target")
    let hostTriple = GooseRuntimeSupervisor.hostCargoTargetTriple
    let candidates = [
        targetRoot.appendingPathComponent("\(hostTriple)/debug/goose"),
        targetRoot.appendingPathComponent("\(hostTriple)/release/goose"),
        targetRoot.appendingPathComponent("debug/goose"),
        targetRoot.appendingPathComponent("release/goose"),
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

nonisolated func liveRepoRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@MainActor
func withFreshGooseWebUIArtifact<T>(
    proofName: String,
    operation: (URL) async throws -> T
) async throws -> T {
    let fileManager = FileManager.default
    let repoRoot = liveRepoRootURL()
    let tempRoot = fileManager.temporaryDirectory
        .appendingPathComponent("epistemos-goose-webui-live-\(proofName)-\(UUID().uuidString)", isDirectory: true)
    let outputDirectory = tempRoot.appendingPathComponent("goose-desktop", isDirectory: true)
    try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: tempRoot) }

    try stageFreshGooseWebUIArtifact(outputDirectory: outputDirectory, repoRoot: repoRoot)

    let index = outputDirectory.appendingPathComponent("index.html")
    let environment = [GooseWebUIResolver.explicitIndexEnvironmentKey: index.path]
    guard let resolvedIndex = GooseWebUIResolver.indexURL(
        bundle: nil,
        appSupportDirectory: nil,
        currentDirectory: repoRoot.path,
        environment: environment,
        includeBundledCandidates: false
    ) else {
        let diagnostics = GooseWebUIResolver.diagnosticSummary(
            bundle: nil,
            appSupportDirectory: nil,
            currentDirectory: repoRoot.path,
            environment: environment,
            includeBundledCandidates: false
        )
        throw GooseLiveIntegrationError.runtimeFailed(
            "Fresh staged ACP-mode Goose Web UI artifact was rejected. \(diagnostics)"
        )
    }
    guard resolvedIndex.standardizedFileURL.path == index.standardizedFileURL.path else {
        throw GooseLiveIntegrationError.runtimeFailed(
            "Fresh Goose Web UI resolver selected \(resolvedIndex.path), expected \(index.path)."
        )
    }
    return try await operation(resolvedIndex)
}

private func stageFreshGooseWebUIArtifact(outputDirectory: URL, repoRoot: URL) throws {
    let script = repoRoot.appendingPathComponent("stage-goose-web-ui.sh")
    guard FileManager.default.fileExists(atPath: script.path) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose Web UI staging script is missing at \(script.path).")
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script.path, outputDirectory.path]
    process.currentDirectoryURL = repoRoot
    var environment = ProcessInfo.processInfo.environment
    let pathParts = [
        environment["PATH"],
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ].compactMap { part in
        let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
    environment["PATH"] = pathParts.joined(separator: ":")
    process.environment = environment
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(
        data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let stderr = String(
        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    guard process.terminationStatus == 0 else {
        throw GooseLiveIntegrationError.runtimeFailed(
            [
                "Goose Web UI staging failed with status \(process.terminationStatus).",
                "script=\(script.path)",
                "output=\(outputDirectory.path)",
                "stdout=\(String(stdout.prefix(4_000)))",
                "stderr=\(String(stderr.prefix(4_000)))",
            ].joined(separator: "\n")
        )
    }
}

@MainActor
func withLiveGooseACPClient<T>(
    proofName: String,
    gooseMode: String? = nil,
    operation: (URL, GooseRuntimeConnection, GooseACPClient, URL) async throws -> T
) async throws -> T {
    try await withLiveGooseRuntime(proofName: proofName, gooseMode: gooseMode) { binary, connection, progressURL in
        guard let acpURL = connection.acpWebSocketURL else {
            throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
        }
        appendLiveProgress("acp url=\(redactedACPURL(acpURL))", to: progressURL)
        let liveClient = GooseACPClient(
            transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
            clientVersion: "phase0-live-test"
        )
        do {
            let result = try await operation(binary, connection, liveClient, progressURL)
            await liveClient.close()
            return result
        } catch {
            await liveClient.close()
            throw error
        }
    }
}

@MainActor
func withLiveGooseRuntime<T>(
    proofName: String,
    gooseMode: String? = nil,
    homeDirectory: URL? = nil,
    disableKeyring: Bool = false,
    operation: (URL, GooseRuntimeConnection, URL) async throws -> T
) async throws -> T {
    guard let binary = liveGooseBinaryURL(),
          FileManager.default.isExecutableFile(atPath: binary.path) else {
        throw GooseLiveIntegrationError.runtimeFailed("No executable Goose binary found for live integration test.")
    }

    let progressURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-\(proofName)-progress.log")
    try? FileManager.default.removeItem(at: progressURL)
    appendLiveProgress("start binary=\(binary.lastPathComponent)", to: progressURL)

    let supervisor = GooseRuntimeSupervisor()
    let port = try liveGooseAvailableTCPPort()
    appendLiveProgress("using isolated port=\(port)", to: progressURL)
    supervisor.start(
        binary: binary,
        secretKey: "phase0-live-acp-secret",
        gooseMode: gooseMode,
        homeDirectory: homeDirectory,
        port: port,
        disableKeyring: disableKeyring
    )
    defer {
        appendLiveProgress("stop supervisor", to: progressURL)
        supervisor.stop()
    }

    do {
        appendLiveProgress("waiting runtime", to: progressURL)
        let connection = try await waitForLiveGooseRuntime(supervisor)
        appendLiveProgress("runtime running base=\(connection.baseURL.absoluteString)", to: progressURL)
        return try await operation(binary, connection, progressURL)
    } catch {
        appendLiveProgress("error=\(error.localizedDescription)", to: progressURL)
        throw error
    }
}

private func liveGooseAvailableTCPPort() throws -> Int {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw GooseLiveIntegrationError.runtimeFailed("Could not allocate a live Goose TCP socket.")
    }
    defer { close(fd) }

    var reuse: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(0).bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr(GooseRuntimeSupervisor.defaultHost))

    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
            bind(fd, rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw GooseLiveIntegrationError.runtimeFailed("Could not bind an isolated live Goose TCP port.")
    }

    var resolved = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &resolved) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
            getsockname(fd, rebound, &length)
        }
    }
    guard nameResult == 0 else {
        throw GooseLiveIntegrationError.runtimeFailed("Could not resolve the isolated live Goose TCP port.")
    }
    return Int(UInt16(bigEndian: resolved.sin_port))
}

@MainActor
private func waitForLiveGooseRuntime(_ supervisor: GooseRuntimeSupervisor) async throws -> GooseRuntimeConnection {
    for _ in 0..<240 {
        switch supervisor.status {
        case .running(let connection):
            return connection
        case .failed(let message), .unavailable(let message):
            throw GooseLiveIntegrationError.runtimeFailed(message)
        default:
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for live Goose runtime.")
}

func initializeLiveSession(
    client: GooseACPClient,
    progressURL: URL
) async throws -> GooseACPNewSessionResponse {
    appendLiveProgress("before initialize", to: progressURL)
    _ = try await withLiveTimeout(
        seconds: 12,
        description: "ACP initialize response",
        onTimeout: { await client.close() },
        operation: { try await client.initialize() }
    )

    appendLiveProgress("before session/new", to: progressURL)
    let session = try await withLiveTimeout(
        seconds: 12,
        description: "ACP session/new response",
        onTimeout: { await client.close() },
        operation: { try await client.newSession(cwd: liveRepoRootURL().path) }
    )
    appendLiveProgress("session id=\(session.sessionId)", to: progressURL)
    return session
}

nonisolated private func waitForPermissionToolResult(
    client: GooseACPClient,
    toolCallID: String,
    progressURL: URL
) async throws -> [GooseACPClientEvent] {
    var events: [GooseACPClientEvent] = []
    while true {
        let event = try await client.receiveEvent()
        events.append(event)
        appendLiveProgress(eventProgressSummary(event), to: progressURL)
        if isToolResult(event, toolCallID: toolCallID) {
            return events
        }
    }
}

@MainActor
func waitForGooseWebBootProbe(
    page: WebPage,
    progressURL: URL
) async throws -> GooseWebBootProbe {
    var lastError = "not evaluated"
    for _ in 0..<220 {
        try await Task.sleep(nanoseconds: 100_000_000)
        do {
            let probe = try await readGooseWebBootProbe(page)
            appendLiveProgress(
                "webview ready=\(probe.readyState) root_children=\(probe.rootChildren) shim=\(probe.hasElectron)",
                to: progressURL
            )
            if probe.isBooted {
                return probe
            }
            lastError = "document ready=\(probe.readyState), root_children=\(probe.rootChildren), shim=\(probe.hasElectron)"
        } catch {
            lastError = error.localizedDescription
        }
    }
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for Goose WebView boot: \(lastError).")
}

@MainActor
func startGooseWebUILoopbackServer(root: URL) async throws -> (server: WorkSPAServer, baseURL: URL) {
    let server = WorkSPAServer(root: root, advertisedHost: "127.0.0.1")
    try server.start()
    for _ in 0..<80 {
        switch server.status {
        case .running(let baseURL):
            return (server, baseURL)
        case .failed(let message):
            server.stop()
            throw GooseLiveIntegrationError.runtimeFailed("Goose Web UI loopback server failed: \(message)")
        default:
            try await Task.sleep(nanoseconds: 80_000_000)
        }
    }
    server.stop()
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for Goose Web UI loopback server.")
}

@MainActor
private func settleGooseWebPageForLiveSuite(_ page: WebPage, progressURL: URL) async {
    let deadline = ContinuousClock.now.advanced(by: .nanoseconds(2_000_000_000))
    do {
        for try await event in page.load(html: "<!doctype html><meta charset=\"utf-8\"><title>goose-live-settled</title>") {
            if event == .finished {
                appendLiveProgress("webview settle finished", to: progressURL)
                break
            }
            if ContinuousClock.now >= deadline {
                appendLiveProgress("webview settle timed out", to: progressURL)
                break
            }
        }
    } catch {
        appendLiveProgress("webview settle error=\(error.localizedDescription)", to: progressURL)
    }
    try? await Task.sleep(nanoseconds: 300_000_000)
}

@MainActor
private func readGooseWebBootProbe(_ page: WebPage) async throws -> GooseWebBootProbe {
    let result = try await page.callJavaScript(
        """
        const electron = window.electron || {};
        const config = typeof electron.getConfig === 'function' ? electron.getConfig() : {};
        const acpUrl = window.epistemos?.goose?.acpUrl ?? '';
        return JSON.stringify({
          readyState: document.readyState,
          href: window.location.href,
          rootChildren: document.getElementById('root')?.children?.length ?? -1,
          hasElectron: typeof window.electron === 'object',
          hasEpistemosGoose: !!window.epistemos?.goose,
          acpUrl,
          configUseACPChat: config?.USE_ACP_CHAT === true,
          configHost: config?.GOOSE_API_HOST ?? '',
          ledgerGetAcpUrl: window.epistemos?.goose?.dispositionLedger?.getAcpUrl ?? '',
          ledgerDirectoryChooser: window.epistemos?.goose?.dispositionLedger?.directoryChooser ?? '',
          ledgerOpenExternal: window.epistemos?.goose?.dispositionLedger?.openExternal ?? '',
          acpBridge: typeof electron.getAcpUrl === 'function',
          permissionBridge: typeof window.epistemos?.goose?.requestPermission === 'function',
          nativeAffordanceBridge: typeof window.epistemos?.goose?.requestNativeAffordance === 'function',
          acpTraceBridge: typeof window.epistemos?.goose?.acpTrace === 'function',
          directoryChooserBridge: typeof electron.directoryChooser === 'function',
          openExternalBridge: typeof electron.openExternal === 'function',
          secretBridge: typeof electron.getSecretKey === 'function'
        });
        """
    )
    guard let json = result as? String,
          let data = json.data(using: .utf8) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose WebView boot probe did not return JSON.")
    }
    return try JSONDecoder().decode(GooseWebBootProbe.self, from: data)
}

#if !EPISTEMOS_APP_STORE
private func availableElectronDebugPort() async throws -> Int {
    for port in 9330...9340 {
        if await electronCDPData(path: "json/version", port: port) == nil {
            return port
        }
    }
    throw GooseLiveIntegrationError.runtimeFailed("No free Electron fallback debug port was found.")
}

private func waitForElectronCDPVersion(port: Int, progressURL: URL) async throws -> ElectronCDPVersion {
    for attempt in 0..<600 {
        if let data = await electronCDPData(path: "json/version", port: port),
           let version = try? JSONDecoder().decode(ElectronCDPVersion.self, from: data) {
            appendLiveProgress("electron_cdp_version_ready attempt=\(attempt) browser=\(version.browser)", to: progressURL)
            return version
        }
        if attempt % 50 == 0 {
            appendLiveProgress("waiting_electron_cdp_version attempt=\(attempt)", to: progressURL)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for real Goose Electron CDP version.")
}

private func waitForElectronCDPPageCount(port: Int, progressURL: URL) async throws -> Int {
    for attempt in 0..<180 {
        if let data = await electronCDPData(path: "json/list", port: port),
           let pages = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
            if !pages.isEmpty {
                appendLiveProgress("electron_cdp_pages_ready attempt=\(attempt) count=\(pages.count)", to: progressURL)
                return pages.count
            }
        }
        if attempt % 30 == 0 {
            appendLiveProgress("waiting_electron_cdp_pages attempt=\(attempt)", to: progressURL)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for real Goose Electron CDP page list.")
}

private func electronCDPData(path: String, port: Int) async -> Data? {
    guard let url = URL(string: "http://127.0.0.1:\(port)/\(path)") else {
        return nil
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 0.5
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return data
    } catch {
        return nil
    }
}
#endif

func redactedACPURL(_ url: URL) -> String {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return "<invalid-url>"
    }
    components.percentEncodedQuery = "token=redacted"
    return components.string ?? "<invalid-url>"
}

nonisolated func withLiveTimeout<T: Sendable>(
    seconds: UInt64,
    description: String,
    onTimeout: @escaping @Sendable () async -> Void,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            await onTimeout()
            throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for \(description).")
        }

        guard let result = try await group.next() else {
            throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for \(description).")
        }
        group.cancelAll()
        return result
    }
}

nonisolated func appendLiveProgress(_ message: String, to url: URL) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let next = "\(timestamp) \(message)\n"
    let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    try? (existing + next).write(to: url, atomically: true, encoding: .utf8)
}

private func agentMessageText(from events: [GooseACPClientEvent]) -> String {
    events.compactMap { event in
        guard case .sessionUpdate(let notification) = event,
              case .agentMessageChunk(let chunk) = notification.update,
              case .text(let text) = chunk.content else {
            return nil
        }
        return text
    }.joined()
}

private func containsAgentMessage(_ events: [GooseACPClientEvent]) -> Bool {
    events.contains { event in
        guard case .sessionUpdate(let notification) = event,
              case .agentMessageChunk = notification.update else {
            return false
        }
        return true
    }
}

private func containsAgentThought(_ events: [GooseACPClientEvent]) -> Bool {
    events.contains { event in
        guard case .sessionUpdate(let notification) = event,
              case .agentThoughtChunk = notification.update else {
            return false
        }
        return true
    }
}

private func containsToolCall(_ events: [GooseACPClientEvent]) -> Bool {
    events.contains { event in
        guard case .sessionUpdate(let notification) = event else {
            return false
        }
        switch notification.update {
        case .toolCall, .toolCallUpdate:
            return true
        default:
            return false
        }
    }
}

nonisolated private func containsToolResult(_ events: [GooseACPClientEvent], toolCallID: String) -> Bool {
    events.contains { isToolResult($0, toolCallID: toolCallID) }
}

nonisolated private func isToolResult(_ event: GooseACPClientEvent, toolCallID: String) -> Bool {
    guard case .sessionUpdate(let notification) = event else {
        return false
    }
    switch notification.update {
    case .toolCall(let call):
        return call.toolCallId == toolCallID && isTerminalToolStatus(call.status)
    case .toolCallUpdate(let update):
        return update.toolCallId == toolCallID && isTerminalToolStatus(update.status)
    default:
        return false
    }
}

nonisolated private func isTerminalToolStatus(_ status: GooseACPToolCallStatus?) -> Bool {
    status == .completed || status == .failed
}

private func containsPermissionRequest(_ events: [GooseACPClientEvent]) -> Bool {
    events.contains { event in
        guard case .permissionRequest = event else {
            return false
        }
        return true
    }
}

private func permissionAllowOptionID(for request: GooseACPRequestPermissionRequest) -> String? {
    request.option(for: .allowOnce)?.optionId ??
        request.option(for: .allowAlways)?.optionId ??
        request.options.first { !$0.kind.isReject }?.optionId
}

nonisolated private func eventProgressSummary(_ event: GooseACPClientEvent) -> String {
    switch event {
    case .sessionUpdate(let notification):
        switch notification.update {
        case .agentMessageChunk:
            "event=agent_message_chunk"
        case .agentThoughtChunk:
            "event=agent_thought_chunk"
        case .toolCall(let call):
            "event=tool_call id=\(call.toolCallId) status=\(call.status?.rawValue ?? "unknown")"
        case .toolCallUpdate(let update):
            "event=tool_call_update id=\(update.toolCallId) status=\(update.status?.rawValue ?? "unknown")"
        case .userMessageChunk:
            "event=user_message_chunk"
        case .sessionInfoUpdate:
            "event=session_info_update"
        case .usageUpdate:
            "event=usage_update"
        case .unknown(let kind, _):
            "event=unknown kind=\(kind)"
        }
    case .permissionRequest:
        "event=permission_request"
    case .elicitationRequest:
        "event=elicitation_request"
    case .unhandledRequest(_, let method, _):
        "event=unhandled_request method=\(method.rawValue)"
    case .unhandledNotification(let method, _):
        "event=unhandled_notification method=\(method.rawValue)"
    case .serverError(let code, let message, _):
        "event=server_error code=\(code) message=\(message)"
    }
}

nonisolated func jsonValueKind(_ value: JSONValue) -> String {
    switch value {
    case .object:
        "object"
    case .array:
        "array"
    case .string:
        "string"
    case .int, .double:
        "number"
    case .bool:
        "bool"
    case .null:
        "null"
    }
}

private extension GooseACPPermissionOptionKind {
    var isReject: Bool {
        switch self {
        case .rejectOnce, .rejectAlways:
            true
        case .allowOnce, .allowAlways:
            false
        }
    }
}

enum GooseLiveIntegrationError: LocalizedError {
    case runtimeFailed(String)

    var errorDescription: String? {
        switch self {
        case .runtimeFailed(let message):
            message
        }
    }
}

struct GooseWebBootProbe: Decodable, Sendable {
    let readyState: String
    let href: String
    let rootChildren: Int
    let hasElectron: Bool
    let hasEpistemosGoose: Bool
    let acpUrl: String
    let configUseACPChat: Bool
    let configHost: String
    let ledgerGetAcpUrl: String
    let ledgerDirectoryChooser: String
    let ledgerOpenExternal: String
    let acpBridge: Bool
    let permissionBridge: Bool
    let nativeAffordanceBridge: Bool
    let acpTraceBridge: Bool
    let directoryChooserBridge: Bool
    let openExternalBridge: Bool
    let secretBridge: Bool

    var isBooted: Bool {
        (readyState == "interactive" || readyState == "complete")
            && rootChildren > 0
            && hasElectron
            && hasEpistemosGoose
            && configUseACPChat
            && acpBridge
            && permissionBridge
            && nativeAffordanceBridge
            && acpTraceBridge
            && directoryChooserBridge
            && openExternalBridge
            && secretBridge
            && !acpUrl.isEmpty
    }
}

private struct GooseWebNativeAffordanceProbe: Decodable, Sendable {
    let confirmResponse: Int
    let writeOK: Bool
    let readFound: Bool
    let readMatches: Bool
    let listContainsGoosehints: Bool
    let recentAdded: Bool
    let recentListed: Bool
    let recipeTrustBefore: Bool
    let recipeTrustRecorded: Bool
    let recipeTrustAfter: Bool
    let launchOK: Bool
    let refreshOK: Bool
    let closeOK: Bool
    let requestNativeAffordanceBridge: Bool
    let errors: [String]

    var passes: Bool {
        confirmResponse == 0
            && writeOK
            && readFound
            && readMatches
            && listContainsGoosehints
            && recentAdded
            && recentListed
            && recipeTrustBefore == false
            && recipeTrustRecorded
            && recipeTrustAfter
            && launchOK
            && refreshOK
            && closeOK
            && requestNativeAffordanceBridge
            && errors.isEmpty
    }
}

#if !EPISTEMOS_APP_STORE
private struct ElectronCDPVersion: Decodable, Sendable {
    let browser: String

    private enum CodingKeys: String, CodingKey {
        case browser = "Browser"
    }
}
#endif

private extension String {
    var trimmedTrailingSlash: String {
        var value = self
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }
}
