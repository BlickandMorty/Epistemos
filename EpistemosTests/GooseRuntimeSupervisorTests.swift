import Foundation
import Testing
@testable import Epistemos

/// Deterministic health-probe sequence: reports the port UP for the first
/// `upProbes` calls, then DOWN — models our own just-terminated `goose serve`
/// releasing the socket during a restart.
private actor GoosePortProbeSequence {
    private var index = 0
    private let upProbes: Int
    init(upProbes: Int) { self.upProbes = upProbes }
    func probe() -> Bool {
        index += 1
        return index <= upProbes
    }
}

@Suite("Goose runtime supervisor")
struct GooseRuntimeSupervisorTests {
    @Test("MAS in-process ACP WebSocket accept key matches RFC 6455")
    func masWebSocketAcceptKeyMatchesRFC6455() {
        #expect(
            GooseInProcessACPFraming.webSocketAcceptKey(for: "dGhlIHNhbXBsZSBub25jZQ==")
                == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
        )
    }

    @Test("MAS in-process ACP decodes browser-masked text frames")
    func masWebSocketDecodesMaskedClientTextFrame() throws {
        let payload = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8)
        let frame = Self.maskedClientTextFrame(payload)

        switch GooseInProcessACPFraming.parseClientFrame(frame) {
        case .complete(let parsed, let consumed):
            #expect(consumed == frame.count)
            #expect(parsed.opcode == 0x1)
            #expect(parsed.payload == payload)
        default:
            Issue.record("Expected complete masked WebSocket frame")
        }
    }

    @Test("App Store Goose branch stays owner-gated before in-process ACP")
    func appStoreGooseBranchStaysOwnerGatedBeforeInProcessACP() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        let appStoreStart = try #require(source.range(of: "#if EPISTEMOS_APP_STORE"))
        let appStoreEnd = try #require(source.range(
            of: "#else",
            range: appStoreStart.upperBound..<source.endIndex
        ))
        let appStoreBranch = source[appStoreStart.lowerBound..<appStoreEnd.lowerBound]
        let ownerGate = try #require(appStoreBranch.range(of: #"EPISTEMOS_MAS_GOOSE_V0"] == "1""#))
        let inProcessStart = try #require(appStoreBranch.range(of: "runInProcessAgentCore"))
        #expect(ownerGate.lowerBound < inProcessStart.lowerBound)
        #expect(appStoreBranch.contains("MAS Goose (in-process) is owner-gated and in development"))
        #expect(appStoreBranch.contains("runInProcessAgentCore"))
        #expect(source.contains("let server = GooseInProcessACPServer"))
        #expect(!appStoreBranch.contains("Goose is available in the Pro / Developer-ID build"))
        #expect(!appStoreBranch.contains("Process("))
    }

    @Test("MAS in-process ACP implements the WebUI config methods used during first render")
    func masInProcessACPImplementsWebUIConfigMethods() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        for snippet in [
            #""_goose/unstable/providers/config/read""#,
            #""_goose/unstable/providers/config/save""#,
            #""_goose/unstable/providers/config/authenticate""#,
            #""_goose/unstable/providers/config/delete""#,
            #""_goose/unstable/providers/supported-models/list""#,
            #""_goose/unstable/providers/catalog/template""#,
            #""_goose/unstable/preferences/read""#,
            #""_goose/unstable/preferences/save""#,
            #""_goose/unstable/preferences/remove""#,
            #""_goose/unstable/defaults/read""#,
            #""_goose/unstable/defaults/save""#,
            #"configValues["GOOSE_PROVIDER"]"#,
            #"configValues["GOOSE_MODEL"]"#,
        ] {
            #expect(source.contains(snippet), "missing MAS ACP WebUI config method: \(snippet)")
        }
    }

    @Test("MAS in-process ACP scheduler list returns the jobs array the WebUI expects")
    func masInProcessACPSchedulerListUsesWebUIShape() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        #expect(source.contains(#"case "_goose/unstable/schedules/list":"#))
        #expect(source.contains(#"emptySchedulesResult()"#))
        #expect(source.contains(#""jobs": []"#))
    }

    @Test("serve argv pins Goose ACP to loopback port 3284 with an explicit builtin")
    func serveArgumentsPinLoopbackACP() {
        let args = GooseRuntimeSupervisor.serveArguments(
            host: "127.0.0.1",
            port: 3284,
            builtins: ["developer"]
        )
        #expect(args == ["serve", "--host", "127.0.0.1", "--port", "3284", "--with-builtin", "developer"])
        #expect(!args.contains("--cors"))
        #expect(!args.contains("-hf"))
        #expect(!args.contains("llama-server"))
    }

    private static func maskedClientTextFrame(_ payload: Data) -> Data {
        let mask: [UInt8] = [0x37, 0xFA, 0x21, 0x3D]
        var frame = Data([0x81])
        if payload.count < 126 {
            frame.append(0x80 | UInt8(payload.count))
        } else {
            frame.append(0x80 | 126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        }
        frame.append(contentsOf: mask)
        for (index, byte) in payload.enumerated() {
            frame.append(byte ^ mask[index % mask.count])
        }
        return frame
    }

    @Test("child env is hardened, injects the Goose server secret, and prepends the binary directory")
    func processEnvironmentWiresSecretAndPath() {
        let binary = URL(fileURLWithPath: "/Runtime/goose/bin/goose")
        let env = GooseRuntimeSupervisor.processEnvironment(
            binary: binary,
            secretKey: "secret-123",
            gooseMode: "approve",
            base: [
                "PATH": "/usr/bin",
                "HOME": "/Users/jojo",
                "LANG": "en_US.UTF-8",
                "GOOSE_MODE": "auto",
                "OPENWORK_MANAGE_OPENCODE": "1",
                "OPENCODE_SERVER_PASSWORD": "password",
                "GOOSE_PROVIDER__TYPE": "openai",
                "GOOSE_PROVIDER": "openai",
                "GOOSE_MODEL": "gpt-4o",
                "HF_TOKEN": "secret-token",
                "HUGGINGFACE_API_KEY": "secret-token",
                "OPENAI_API_KEY": "secret-token",
                "ZHIPU_API_KEY": "secret-token",
                "ZAI_API_KEY": "secret-token",
                "MOONSHOT_API_KEY": "secret-token",
                "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
                "NODE_OPTIONS": "--require /tmp/inject.js",
            ]
        )
        let path = env["PATH"] ?? ""
        #expect(path.hasPrefix("/Runtime/goose/bin:/usr/bin"))
        #expect(path.contains("/opt/homebrew/bin"))
        #expect(path.contains("/usr/local/bin"))
        #expect(env["GOOSE_PROVIDER"] == "openai")
        #expect(env["GOOSE_MODEL"] == "gpt-4o")
        #expect(env["HOME"] == "/Users/jojo")
        #expect(env["LANG"] == "en_US.UTF-8")
        #expect(env["GOOSE_SERVER__SECRET_KEY"] == "secret-123")
        #expect(env["GOOSE_MODE"] == "approve")
        #expect(env["GOOSE_PROVIDER__TYPE"] == nil)
        #expect(env["OPENWORK_MANAGE_OPENCODE"] == nil)
        #expect(env["OPENCODE_SERVER_PASSWORD"] == nil)
        #expect(env["HF_TOKEN"] == nil)
        #expect(env["HUGGINGFACE_API_KEY"] == nil)
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["ZHIPU_API_KEY"] == nil)
        #expect(env["ZAI_API_KEY"] == nil)
        #expect(env["MOONSHOT_API_KEY"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)

        let inheritedOnlyEnv = GooseRuntimeSupervisor.processEnvironment(
            binary: binary,
            secretKey: "secret-456",
            base: ["GOOSE_MODE": "approve"]
        )
        #expect(inheritedOnlyEnv["GOOSE_MODE"] == nil)
    }

    @Test("child env drops oversized inherited values and bounds PATH")
    func processEnvironmentBoundsInheritedValuesAndPath() {
        let binary = URL(fileURLWithPath: "/Runtime/goose/bin/goose")
        let oversizedValue = String(
            repeating: "x",
            count: GooseRuntimeSupervisor.maxSubprocessEnvironmentValueCharacters + 1
        )
        let env = GooseRuntimeSupervisor.processEnvironment(
            binary: binary,
            secretKey: "secret-oversized",
            base: [
                "PATH": oversizedValue,
                "HOME": oversizedValue,
                "LANG": oversizedValue,
                "USER": "bad\0actor",
                "GOOSE_PROVIDER": oversizedValue,
            ]
        )
        let path = env["PATH"] ?? ""

        #expect(path.hasPrefix("/Runtime/goose/bin"))
        #expect(path.count <= GooseRuntimeSupervisor.maxSubprocessPathCharacters)
        #expect(!path.contains(oversizedValue))
        #expect(env["HOME"] == nil)
        #expect(env["LANG"] == nil)
        #expect(env["USER"] == nil)
        #expect(env["GOOSE_PROVIDER"] == nil)
        #expect(env["GOOSE_SERVER__SECRET_KEY"] == "secret-oversized")
    }

    @Test("child env can isolate Goose home and force file-backed secrets for live mutation proofs")
    func processEnvironmentCanIsolateHomeAndSecrets() {
        let binary = URL(fileURLWithPath: "/Runtime/goose/bin/goose")
        let isolatedHome = URL(fileURLWithPath: "/tmp/epistemos-goose-home")
        let env = GooseRuntimeSupervisor.processEnvironment(
            binary: binary,
            secretKey: "secret-789",
            homeDirectory: isolatedHome,
            disableKeyring: true,
            base: [
                "PATH": "/usr/bin",
                "HOME": "/Users/jojo",
                "GOOSE_DISABLE_KEYRING": "false",
            ]
        )

        #expect(env["HOME"] == isolatedHome.path)
        #expect(env["GOOSE_DISABLE_KEYRING"] == "true")
        #expect(env["GOOSE_SERVER__SECRET_KEY"] == "secret-789")
    }

    @Test("supervisor refuses to reuse a stale health endpoint before spawning")
    @MainActor
    func supervisorRefusesStaleHealthEndpoint() async throws {
        let supervisor = GooseRuntimeSupervisor()
        supervisor.start(
            binary: URL(fileURLWithPath: "/bin/echo"),
            secretKey: "secret-123",
            healthCheck: { _ in true }
        )

        try await waitUntilSupervisorStatus {
            guard case .failed(let message) = supervisor.status else { return false }
            return message.contains("3284") && message.contains("already")
        }
    }

    @Test("supervisor tolerates a port that releases within the restart grace window")
    @MainActor
    func supervisorToleratesPortReleaseWithinGraceWindow() async throws {
        // The port answers on the first pre-launch probe (our own just-killed
        // `goose serve` still releasing the socket on a restart) then goes down.
        // The supervisor must NOT declare the port occupied; it proceeds to launch
        // (and then fails on the immediately-exiting /bin/echo, not on "already").
        let probes = GoosePortProbeSequence(upProbes: 1)
        let supervisor = GooseRuntimeSupervisor()
        supervisor.start(
            binary: URL(fileURLWithPath: "/bin/echo"),
            secretKey: "secret-123",
            healthCheck: { _ in await probes.probe() }
        )

        try await waitUntilSupervisorStatus {
            guard case .failed(let message) = supervisor.status else { return false }
            return !message.contains("already")
        }
    }

    @Test("listening lines parse only loopback Goose ACP base URLs")
    func parsesListeningURL() {
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: "INFO Starting ACP server on 127.0.0.1:3284",
                expectedPort: 3284
            ) == URL(string: "http://127.0.0.1:3284")
        )
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: "Starting ACP server on http://localhost:3284/.",
                expectedPort: 3284
            ) == URL(string: "http://localhost:3284")
        )
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: "Starting ACP server on http://example.com:3284",
                expectedPort: 3284
            ) == nil
        )
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: "Starting ACP server on http://127.0.0.1:9999",
                expectedPort: 3284
            ) == nil
        )
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: "unrelated http://127.0.0.1:3284",
                expectedPort: 3284
            ) == nil
        )
        #expect(
            GooseRuntimeSupervisor.parseListeningURL(
                from: String(repeating: "x", count: GooseRuntimeSupervisor.maxListeningLogLineCharacters + 1)
                    + " Starting ACP server on 127.0.0.1:3284",
                expectedPort: 3284
            ) == nil
        )
    }

    @Test("listening logs stay diagnostic while health gates readiness")
    func listeningLogsDoNotShortCircuitHealthReadiness() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        let forbiddenEarlyResume = #"if\s+let\s+url\s*=\s*Self\.parseListeningURL\(from:\s*line,\s*expectedPort:\s*Self\.defaultPort\)\s*\{\s*await\s+state\.resume\(url\)"#
        #expect(source.contains("let defaultPortHealthy = await effectiveHealthCheck(defaultBaseURL)"))
        #expect(source.contains("let defaultPortBusy = !Self.isLoopbackTCPPortAvailable(launchPort)"))
        #expect(source.contains("if defaultPortHealthy || defaultPortBusy"))
        #expect(source.contains("Self.isLoopbackTCPPortAvailable(launchPort)"))
        #expect(source.contains("let fallbackPort = await Self.firstAvailableFallbackPort("))
        #expect(source.contains("status = .failed(Self.occupiedPortMessage(base: defaultBaseURL))"))
        #expect(source.range(of: forbiddenEarlyResume, options: .regularExpression) == nil)
    }

    @Test("launched Goose process is registered with orphan cleanup")
    func launchedGooseProcessIsTrackedForTerminationCleanup() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        #expect(source.contains("AppBootstrap.shared?.orphanCleanup.track(proc)"))
        #expect(source.contains("AppBootstrap.shared?.orphanCleanup.cleanupProcessTree(rootPID: pid)"))
        #expect(source.contains("AppBootstrap.shared?.orphanCleanup.untrack(pid)"))
    }

    @Test("process diagnostics are memory and storage bounded")
    func processDiagnosticsAreBounded() throws {
        let blank = GooseProcessDiagnostics.boundedLine(buffer: Array(" \n\t ".utf8), truncated: false)
        #expect(blank == nil)

        let storageCapped = GooseProcessDiagnostics.boundedLine(
            buffer: Array(
                String(
                    repeating: "d",
                    count: GooseProcessDiagnostics.maxStoredDiagnosticCharacters + 20
                ).utf8
            ),
            truncated: false
        )
        #expect(storageCapped?.count == GooseProcessDiagnostics.maxStoredDiagnosticCharacters)
        #expect(storageCapped?.hasSuffix(" ... [truncated]") == true)

        let truncated = GooseProcessDiagnostics.boundedLine(
            buffer: Array(
                String(
                    repeating: "d",
                    count: GooseProcessDiagnostics.maxBufferedLineBytes
                ).utf8
            ),
            truncated: true
        )
        #expect(truncated?.count == GooseProcessDiagnostics.maxStoredDiagnosticCharacters)
        #expect(truncated?.hasSuffix(" ... [truncated]") == true)

        let supervisor = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        let launcher = try loadRepoTextFile("Epistemos/Goose/GooseElectronFallbackLauncher.swift")
        #expect(supervisor.contains("GooseProcessDiagnostics.consume"))
        #expect(launcher.contains("GooseProcessDiagnostics.consume"))
        #expect(!supervisor.contains("bytes.lines"))
        #expect(!launcher.contains("bytes.lines"))
    }

    @Test("runtime supervisor status messages are bounded")
    func runtimeSupervisorStatusMessagesAreBounded() throws {
        let oversized = String(
            repeating: "s",
            count: GooseRuntimeSupervisor.maxStatusMessageCharacters + 40
        )

        #expect(GooseRuntimeSupervisor.boundedStatusMessage(" \n\(oversized)\n ").count == GooseRuntimeSupervisor.maxStatusMessageCharacters)
        #expect(GooseRuntimeSupervisor.boundedStatusMessage(" \n\t ", fallback: "fallback") == "fallback")

        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        #expect(source.contains("Self.boundedStatusMessage(\"Failed to launch \\(name): \\(error.localizedDescription)\""))
        #expect(!source.contains("status = .failed(\"Failed to launch \\(name): \\(error.localizedDescription)\""))
        #expect(!source.contains("status = .failed(message)"))
    }

    @Test("checkout-relative goose binary candidates are DEBUG-only (no code-exec-from-cwd in release)")
    func checkoutBinaryCandidatesAreDebugGuarded() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        // The cwd-relative `.research-clones` checkout binaries are EXECUTED by
        // resolvedGooseBinary; a shipped (Release) build must resolve only the
        // trusted AppSupport/bundle candidates. Prove the checkout block is wrapped
        // in a #if DEBUG guard, and the AppSupport/bundle candidates stay unconditional.
        let marker = "binary-resolution candidate safety.)"
        #expect(source.contains(marker))
        if let m = source.range(of: marker) {
            let after = source[m.upperBound...]
            let ifIdx = after.range(of: "#if DEBUG")
            let checkoutIdx = after.range(of: ".research-clones/work/goose/target")
            let endifIdx = after.range(of: "#endif")
            #expect(ifIdx != nil && checkoutIdx != nil && endifIdx != nil)
            if let i = ifIdx, let c = checkoutIdx, let e = endifIdx {
                #expect(i.lowerBound < c.lowerBound, "#if DEBUG must precede the checkout candidates")
                #expect(c.lowerBound < e.lowerBound, "checkout candidates must precede #endif")
            }
        }
        // AppSupport + bundle candidates remain unconditional (real-install path).
        #expect(source.contains("Epistemos/GooseRuntime/\\(binaryName)"))
        #expect(source.contains("bundle?.url(forResource: binaryName, withExtension: nil)"))
    }

    @Test("checkout-relative web index candidate is DEBUG-only (no cwd content in the privileged WebView in release)")
    func checkoutWebIndexCandidateIsDebugGuarded() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebUIResolver.swift")
        // The cwd `.research-clones` index.html is loaded into the ACP-bridged
        // WebView; Release must resolve only explicit-env / bundled / AppSupport.
        // Prove the checkout-index append is wrapped in #if DEBUG.
        let marker = "web-index candidate safety.)"
        #expect(source.contains(marker))
        if let m = source.range(of: marker) {
            let after = source[m.upperBound...]
            let ifIdx = after.range(of: "#if DEBUG")
            let checkoutIdx = after.range(of: ".research-clones/work/goose/ui/desktop/dist/index.html")
            let endifIdx = after.range(of: "#endif")
            #expect(ifIdx != nil && checkoutIdx != nil && endifIdx != nil)
            if let i = ifIdx, let c = checkoutIdx, let e = endifIdx {
                #expect(i.lowerBound < c.lowerBound, "#if DEBUG must precede the checkout index")
                #expect(c.lowerBound < e.lowerBound, "checkout index must precede #endif")
            }
        }
        // AppSupport staged index stays unconditional (real-install path).
        #expect(source.contains("Epistemos/GooseWebUI/index.html"))
    }

    @Test("Goose surface has no native details panel chrome")
    func gooseSurfaceHasNoNativeDetailsPanelChrome() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        #expect(source.contains("nativeACPOverlay"))
        #expect(!source.contains("detailsPanel"))
        #expect(!source.contains("detailsButton"))
        #expect(!source.contains("detailRow(\"native ACP Goose\""))
        #expect(!source.contains("detailRow(\"custom ACP Goose\""))
        #expect(!source.contains("\"Goose ACP ready\""))
        #expect(!source.contains("detailRow(\"Goose ACP\""))
        #expect(!source.contains("detailRow(\"Goose\","))
    }

    @Test("native prompt overlay is cancelled on every teardown path + ready-loops honor cancellation")
    func surfaceTeardownCancelsPromptsAndHonorsCancellation() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        // A permission/elicitation overlay must NOT survive a goose death/retry:
        // cancelPendingPrompts() must run on onDisappear, runtime-failure,
        // load-failure, and retry paths (>= 4 sites), not just onDisappear —
        // otherwise an orphaned native overlay sticks on screen after a reconnect.
        let cancelCount = source.components(separatedBy: "nativePromptBridge.cancelPendingPrompts()").count - 1
        #expect(cancelCount >= 4, "cancelPendingPrompts must cover teardown + runtime-failure + load-failure + retry; found \(cancelCount)")
        // The ready-polling loops must honor Task cancellation so a disappeared view
        // does not busy-spin or do post-teardown work (connect/load against a torn-down surface).
        let guardCount = source.components(separatedBy: "guard !Task.isCancelled else { return }").count - 1
        #expect(guardCount >= 3, "expected cancellation guards in loadWhenReady + loadGooseUIWhenReady + native ACP loop; found \(guardCount)")
    }

    @Test("ACP reconnect budget resets on a successful connect (transient flaps don't exhaust the lifetime)")
    func acpReconnectBudgetResetsOnSuccessfulConnect() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseACPEventBridge.swift")
        // The handshake-retry budget must bound CONSECUTIVE failures, not lifetime
        // reconnects: a successful initialize MUST reset the attempt counter, else a
        // long-lived connection that flaps `attempts` times over its life permanently
        // fail()s and stops listening (killing native overlays/diagnostics) even though
        // every reconnect succeeded. Assert the reset lands after a successful connect
        // and before the receive loop, and that terminal failure is gated on the bound.
        #expect(source.contains("if let attempts, attempt >= attempts {"))
        #expect(source.contains("markConnected(agent: response.agentInfo)"))
        if let mc = source.range(of: "markConnected(agent: response.agentInfo)") {
            let afterConnect = source[mc.upperBound...]
            #expect(afterConnect.contains("attempt = 0"), "the attempt counter must reset to 0 after a successful connect")
            if let resetRange = afterConnect.range(of: "attempt = 0"),
               let receiveRange = afterConnect.range(of: "client.receiveEvent()") {
                #expect(resetRange.lowerBound < receiveRange.lowerBound, "the reset must precede the receive loop")
            }
        }
    }

    @Test("production ACP URL bridge retries until ready with capped backoff")
    func productionACPURLBridgeRetriesUntilReady() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseACPEventBridge.swift")
        #expect(source.contains("initialHandshakeAttempts: nil"))
        #expect(source.contains("urlHandshakeInitialRetryDelayNanoseconds"))
        #expect(source.contains("urlHandshakeMaximumRetryDelayNanoseconds"))
        #expect(source.contains("handshakeRetryDelayNanoseconds("))
        #expect(source.contains("if let attempts, attempt >= attempts {"))
    }

    @Test("default provider activation uses bounded typed provider inventory")
    func defaultProviderActivationUsesTypedInventory() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseACPEventBridge.swift")
        #expect(source.contains("client.listGooseProviderInventory(providerIDs: [providerId])"))
        #expect(!source.contains("client.listGooseProviders(providerIDs: [providerId])"))
        #expect(!source.contains("object[\"defaultModel\"]"))
        #expect(!source.contains("object[\"default_model\"]"))
    }

    @Test("launched MCP-app windows are closed on surface teardown (no orphaned top-level windows)")
    func mcpAppWindowsClosedOnSurfaceTeardown() throws {
        let bridge = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        // launchApp opens top-level NSWindows tracked in appWindows/appWebViews/
        // appWindowDelegates; without a teardown sweep they orphan when the Goose
        // surface disappears. closeAllApps must snapshot + clear the registries BEFORE
        // closing (window.close() fires windowWillClose, which mutates them).
        #expect(bridge.contains("func closeAllApps()"))
        #expect(bridge.contains("let windows = Array(appWindows.values)"))
        #expect(bridge.contains("appWindows.removeAll()"))
        #expect(bridge.contains("appWebViews.removeAll()"))
        #expect(bridge.contains("appWindowDelegates.removeAll()"))
        #expect(bridge.contains("isolated deinit"))
        if let deinitRange = bridge.range(of: "isolated deinit"),
           let closeRange = bridge[deinitRange.upperBound...].range(of: "closeAllApps()"),
           let releaseRange = bridge[deinitRange.upperBound...].range(of: "IOPMAssertionRelease") {
            #expect(closeRange.lowerBound < releaseRange.lowerBound, "deinit must close guest windows before releasing remaining native resources")
        } else {
            Issue.record("affordance bridge deinit must close launched app windows")
        }
        // The clear must precede the close loop (snapshot-then-clear-then-close).
        if let clearRange = bridge.range(of: "appWindows.removeAll()"),
           let closeRange = bridge.range(of: "for window in windows") {
            #expect(clearRange.lowerBound < closeRange.lowerBound, "registries must be cleared before closing the snapshot")
        }
        // Goose surface teardown must invoke it.
        let view = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(view.contains("nativeAffordanceBridge.closeAllApps()"))
    }

    @Test("Goose WebView navigation gate is deny-by-default + loopback-only (no file:/external nav)")
    func gooseSurfaceNavigationIsLoopbackOnly() throws {
        let view = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        let support = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        // GooseNavigationDecider is the privileged (ACP-bridged) WebView's navigation gate. It
        // must deny by default and only allow the custom goose scheme + registered loopback
        // http(s) document navigation. `file:`, ws(s), and external hosts must never be navigable.
        #expect(view.contains("Self.makePage("))
        #expect(support.contains("navigationDecider: GooseNavigationDecider(trustedOrigins: trustedOrigins)"))
        #expect(support.contains("func decidePolicy("))
        #expect(support.contains("case \"http\", \"https\":"))
        #expect(!support.contains("case \"http\", \"https\", \"ws\", \"wss\":"))
        #expect(support.contains("normalizedHost == \"127.0.0.1\" || normalizedHost == \"localhost\" || normalizedHost == \"::1\""))
        #expect(support.contains("maxLoopbackHostCharacters"))
        #expect(support.contains("trustedOrigins.isAllowed(url) ? .allow : .cancel"))
        #expect(support.contains("default:"))
        #expect(support.contains("return .cancel"))
        // `file:` must NOT be allow-listed; the registered-port deny intent stays.
        #expect(!support.contains("case \"file\":"))
        #expect(support.contains("pin to the exact registered ports"))
    }

    @Test("MCP app guest navigation delegate keeps the Swift 6 WebKit signature")
    func mcpAppGuestNavigationDelegateKeepsSwift6Signature() throws {
        let bridge = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(bridge.contains("private final class GooseWebNativeAppGuestNavigationDelegate: NSObject, WKNavigationDelegate"))
        #expect(bridge.contains("decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void"))
        #expect(!bridge.contains("decisionHandler: @escaping (WKNavigationActionPolicy) -> Void"))
        #expect(bridge.contains("case \"http\", \"https\":"))
        #expect(!bridge.contains("case \"http\", \"https\", \"ws\", \"wss\":"))

        // The target builds with default MainActor isolation. The background pipe drain must opt out
        // explicitly instead of mutating actor-isolated state from a Sendable closure.
        #expect(bridge.contains("private nonisolated final class GooseAffordanceDataBox: @unchecked Sendable"))
        #expect(bridge.contains("readBoundedPipeData("))
        #expect(bridge.contains("maxGitWorktreeListBytes"))
        #expect(bridge.contains("maxGitWorktreePathCharacters"))
        #expect(bridge.contains("let outputData = drainBox.load()"))
        #expect(bridge.contains("String(data: outputData, encoding: .utf8)"))
        #expect(!bridge.contains("readDataToEndOfFile()"))
        #expect(!bridge.contains("drainBox.data = stdoutHandle.readDataToEndOfFile()"))
    }

    @Test("ACP per-frame decode is contained — a drifted known-method payload becomes unhandled*, not fatal")
    func acpPerFrameDecodeContainment() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseACPClient.swift")
        // A KNOWN method whose payload drifted (a future goose serve renaming/dropping
        // a required field) must fall back to the unhandled-diagnostic path, never throw
        // out of event(from:) and tear down the whole ACP connection. Lock the `try?`
        // containment + the unhandled fallback for each typed method so a regression
        // (try? -> try) that reintroduces the fatal path fails here.
        #expect(source.contains("Per-frame decode containment"))
        #expect(source.contains("if let notification = try? params.decoded(GooseACPSessionNotification.self)"))
        #expect(source.contains("return .unhandledNotification(method: .sessionUpdate, params: params)"))
        #expect(source.contains("if let permission = try? params.decoded(GooseACPRequestPermissionRequest.self)"))
        #expect(source.contains("return .unhandledRequest(id: id, method: .requestPermission, params: params)"))
        #expect(source.contains("if let elicitation = try? params.decoded(GooseACPCreateElicitationRequest.self)"))
    }

    @Test("ACP WebSocket URL uses /acp token query and health URL uses /health")
    func acpAndHealthURLs() {
        let base = URL(string: "http://127.0.0.1:3284")!
        #expect(GooseRuntimeSupervisor.healthURL(base: base) == URL(string: "http://127.0.0.1:3284/health"))
        #expect(
            GooseRuntimeSupervisor.acpWebSocketURL(base: base, secretKey: "secret key")?
                .absoluteString == "ws://127.0.0.1:3284/acp?token=secret%20key"
        )
        #expect(
            GooseRuntimeSupervisor.acpWebSocketURL(base: base, secretKey: "secret+key/=")?
                .absoluteString == "ws://127.0.0.1:3284/acp?token=secret%2Bkey%2F%3D"
        )
    }

    @Test("resolver finds Goose cargo binaries built for the host Apple target")
    func resolvesTargetSpecificCheckoutBinary() throws {
        let root = try temporaryDirectory()
        let hostTriple = GooseRuntimeSupervisor.hostCargoTargetTriple
        let binary = root
            .appendingPathComponent(".research-clones/work/goose/target")
            .appendingPathComponent(hostTriple)
            .appendingPathComponent("debug/goose")
        try FileManager.default.createDirectory(
            at: binary.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: binary.path, contents: Data())
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: binary.path
        )

        #expect(
            GooseRuntimeSupervisor.resolvedGooseBinary(
                bundle: nil,
                appSupportDirectory: nil,
                currentDirectory: root.path
            ) == binary
        )
    }
}

@Suite("Goose Web UI resolver")
struct GooseWebUIResolverTests {
    @Test("resolver prefers an explicit staged Goose Web UI index")
    func resolverUsesExplicitIndex() throws {
        let root = try temporaryDirectory()
        let explicit = root.appendingPathComponent("explicit/index.html")
        try FileManager.default.createDirectory(
            at: explicit.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeGooseACPWebUIArtifact(at: explicit)

        let resolved = GooseWebUIResolver.indexURL(
            appSupportDirectory: nil,
            currentDirectory: root.appendingPathComponent("checkout").path,
            environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path]
        )

        #expect(resolved == explicit)
    }

    @Test("resolver bounds environment path candidates and diagnostics")
    func resolverBoundsEnvironmentPathCandidatesAndDiagnostics() throws {
        let root = try temporaryDirectory()
        let oversizedPath = "/" + String(
            repeating: "u",
            count: GooseWebUIResolver.maxEnvironmentPathCharacters + 1
        )
        let environment = [
            GooseWebUIResolver.explicitIndexEnvironmentKey: oversizedPath,
            GooseWebUIResolver.explicitDirectoryEnvironmentKey: "bad\0path",
            "TEST_HOST": oversizedPath,
            "XCInjectBundleInto": "bad\0bundle",
            "BUILT_PRODUCTS_DIR": oversizedPath,
            "TARGET_BUILD_DIR": oversizedPath,
            "WRAPPER_NAME": oversizedPath,
        ]

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: environment,
                includeBundledCandidates: false
            ) == nil
        )

        let diagnostics = GooseWebUIResolver.diagnosticSummary(
            appSupportDirectory: nil,
            currentDirectory: root.path,
            environment: environment,
            includeBundledCandidates: false
        )
        #expect(diagnostics.count <= GooseWebUIResolver.maxDiagnosticSummaryCharacters)
        #expect(!diagnostics.contains(oversizedPath))
        #expect(!diagnostics.contains("bad\0path"))
        #expect(!diagnostics.contains("bad\0bundle"))

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebUIResolver.swift")
        #expect(source.contains("safeEnvironmentPath(environment[explicitIndexEnvironmentKey])"))
        #expect(source.contains("diagnosticValue(environment[\"TEST_HOST\"])"))
    }

    @Test("resolver finds a bundled Goose Web UI index in the goose-desktop resource subdirectory")
    func resolverUsesBundledGooseDesktopSubdirectory() throws {
        let root = try temporaryDirectory()
        let bundleRoot = root.appendingPathComponent("EpistemosTest.bundle", isDirectory: true)
        let resources = bundleRoot.appendingPathComponent("Contents/Resources", isDirectory: true)
        let index = resources.appendingPathComponent("goose-desktop/index.html")
        try FileManager.default.createDirectory(
            at: index.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.epistemos.tests.goose-web-ui</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """.write(
            to: bundleRoot.appendingPathComponent("Contents/Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        try writeGooseACPWebUIArtifact(at: index)
        let bundle = try #require(Bundle(url: bundleRoot))

        #expect(
            GooseWebUIResolver.indexURL(
                bundle: bundle,
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: [:]
            ) == index
        )
    }

    @Test("resolver finds bundled Goose Web UI from the Xcode test host app executable")
    func resolverUsesXcodeTestHostAppBundle() throws {
        let root = try temporaryDirectory()
        let app = root.appendingPathComponent("Epistemos.app", isDirectory: true)
        let executable = app.appendingPathComponent("Contents/MacOS/Epistemos")
        let index = app.appendingPathComponent("Contents/Resources/goose-desktop/index.html")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: index.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        try writeGooseACPWebUIArtifact(at: index)

        #expect(
            GooseWebUIResolver.indexURL(
                bundle: nil,
                appSupportDirectory: nil,
                currentDirectory: root.appendingPathComponent("checkout").path,
                environment: ["TEST_HOST": executable.path]
            ) == index
        )
    }

    @Test("resolver finds bundled Goose Web UI from a nested Xcode test bundle")
    func resolverUsesNestedXcodeTestBundle() throws {
        let root = try temporaryDirectory()
        let app = root.appendingPathComponent("Epistemos.app", isDirectory: true)
        let index = app.appendingPathComponent("Contents/Resources/goose-desktop/index.html")
        let testBundle = app.appendingPathComponent(
            "Contents/PlugIns/EpistemosTests.xctest",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: index.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: testBundle.appendingPathComponent("Contents/Resources", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.epistemos.tests</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """.write(
            to: testBundle.appendingPathComponent("Contents/Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        try writeGooseACPWebUIArtifact(at: index)
        let bundle = try #require(Bundle(url: testBundle))

        #expect(
            GooseWebUIResolver.indexURL(
                bundle: bundle,
                appSupportDirectory: nil,
                currentDirectory: root.appendingPathComponent("checkout").path,
                environment: [:]
            ) == index
        )
    }

    @Test("resolver supports Application Support staging and checkout dist fallback")
    func resolverUsesStagedThenCheckoutDist() throws {
        let root = try temporaryDirectory()
        let appSupport = root.appendingPathComponent("Application Support")
        let staged = appSupport.appendingPathComponent("Epistemos/GooseWebUI/index.html")
        let checkout = root.appendingPathComponent(".research-clones/work/goose/ui/desktop/dist/index.html")
        try FileManager.default.createDirectory(
            at: staged.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: checkout.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeGooseACPWebUIArtifact(at: staged)
        try writeGooseACPWebUIArtifact(at: checkout)

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: appSupport,
                currentDirectory: root.path,
                environment: [:],
                includeBundledCandidates: false
            ) == staged
        )

        try FileManager.default.removeItem(at: staged)
        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: appSupport,
                currentDirectory: root.path,
                environment: [:],
                includeBundledCandidates: false
            ) == checkout
        )
    }

    @Test("resolver rejects Goose Web UI indexes without the ACP artifact manifest")
    func resolverRejectsNonACPArtifact() throws {
        let root = try temporaryDirectory()
        let explicit = root.appendingPathComponent("dist/index.html")
        try FileManager.default.createDirectory(
            at: explicit.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: explicit.path, contents: Data())

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
                includeBundledCandidates: false
            ) == nil
        )
    }

    @Test("resolver rejects oversized ACP artifact files before reading")
    func resolverRejectsOversizedACPArtifactFilesBeforeReading() throws {
        let root = try temporaryDirectory()

        let oversizedManifestIndex = root.appendingPathComponent("oversized-manifest/index.html")
        try FileManager.default.createDirectory(
            at: oversizedManifestIndex.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: oversizedManifestIndex.path, contents: Data())
        try createSparseFile(
            oversizedManifestIndex.deletingLastPathComponent()
                .appendingPathComponent(GooseWebUIResolver.artifactManifestFileName),
            size: GooseWebUIResolver.maxArtifactManifestBytes + 1
        )

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": oversizedManifestIndex.path],
                includeBundledCandidates: false
            ) == nil
        )

        let oversizedIndex = root.appendingPathComponent("oversized-index/index.html")
        try FileManager.default.createDirectory(
            at: oversizedIndex.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeGooseACPWebUIManifest(nextTo: oversizedIndex)
        try createSparseFile(
            oversizedIndex,
            size: GooseWebUIResolver.maxArtifactTextFileBytes + 1
        )

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": oversizedIndex.path],
                includeBundledCandidates: false
            ) == nil
        )
    }

    @Test("resolver bounds artifact reference scanning and actual file reads")
    func resolverBoundsArtifactReferenceScanningAndReads() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebUIResolver.swift")
        #expect(source.contains("regex.enumerateMatches(in: html"))
        #expect(!source.contains("regex.matches(in: html"))
        #expect(source.contains("missingLocalAssetReferences"))
        #expect(source.contains("missing-referenced-asset"))
        #expect(source.contains("maxLocalAssetReferenceCount"))
        #expect(source.contains("maxLocalAssetReferenceCharacters"))
        #expect(source.contains("maxBundledAssetEnumerationItems"))
        #expect(source.contains("handle.read(upToCount: maxBytes + 1)"))
        #expect(source.contains("type == .typeRegular"))
        #expect(!source.contains("Data(contentsOf: url)"))

        let root = try temporaryDirectory()
        let directoryIndex = root.appendingPathComponent("directory-index/index.html", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryIndex, withIntermediateDirectories: true)
        try writeGooseACPWebUIManifest(nextTo: directoryIndex)
        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": directoryIndex.path],
                includeBundledCandidates: false
            ) == nil
        )

        let oversizedReferenceIndex = root.appendingPathComponent("oversized-reference/index.html")
        try FileManager.default.createDirectory(
            at: oversizedReferenceIndex.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let oversizedReference = "assets/" + String(
            repeating: "a",
            count: GooseWebUIResolver.maxLocalAssetReferenceCharacters + 1
        ) + ".js"
        try """
        <!doctype html>
        <script type="module" src="\(oversizedReference)"></script>
        <script>
        \(gooseACPWebUIBridgeFixtureSource)
        </script>
        """.write(to: oversizedReferenceIndex, atomically: true, encoding: .utf8)
        try writeGooseACPWebUIManifest(nextTo: oversizedReferenceIndex)
        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": oversizedReferenceIndex.path],
                includeBundledCandidates: false
            ) == nil
        )
    }

    @Test("resolver rejects stale ACP artifacts without the provider catalog bridge")
    func resolverRejectsStaleProviderCatalogArtifact() throws {
        let root = try temporaryDirectory()
        let explicit = root.appendingPathComponent("dist/index.html")
        try FileManager.default.createDirectory(
            at: explicit.deletingLastPathComponent().appendingPathComponent("assets"),
            withIntermediateDirectories: true
        )
        try """
        <!doctype html>
        <script type="module" src="./assets/index-stale.js"></script>
        """.write(to: explicit, atomically: true, encoding: .utf8)
        try """
        providersCatalogList_unstable
        providersCatalogTemplate_unstable
        """.write(
            to: explicit.deletingLastPathComponent().appendingPathComponent("assets/index-stale.js"),
            atomically: true,
            encoding: .utf8
        )
        try writeGooseACPWebUIManifest(nextTo: explicit)

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
                includeBundledCandidates: false
            ) == nil
        )
    }

    @Test("resolver accepts provider bridge markers in Vite dynamic chunks")
    func resolverAcceptsProviderBridgeMarkersInDynamicChunks() throws {
        let root = try temporaryDirectory()
        let explicit = root.appendingPathComponent("dist/index.html")
        let assets = explicit.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try """
        <!doctype html>
        <script type="module" src="./assets/index-live.js"></script>
        """.write(to: explicit, atomically: true, encoding: .utf8)
        try """
        providersList_unstable
        providersCatalogList_unstable
        providersSetupCatalogList_unstable
        providersCatalogTemplate_unstable
        shared-getAcpClient-provider-inventory
        local-acp-config-GOOSE_TELEMETRY_ENABLED
        """.write(
            to: assets.appendingPathComponent("index-live.js"),
            atomically: true,
            encoding: .utf8
        )
        try """
        __epistemosGooseProviderInventoryEvents
        __epistemosGooseACPRequestSerialization
        __epistemosGooseProviderCatalogEvents
        provider-catalog-template-choice
        """.write(
            to: assets.appendingPathComponent("App-dynamic.js"),
            atomically: true,
            encoding: .utf8
        )
        try writeGooseACPWebUIManifest(nextTo: explicit)

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
                includeBundledCandidates: false
            ) == explicit
        )
    }

    @Test("resolver rejects ACP Goose Web UI indexes with missing local assets")
    func resolverRejectsMissingLocalAssets() throws {
        let root = try temporaryDirectory()
        let explicit = root.appendingPathComponent("dist/index.html")
        try FileManager.default.createDirectory(
            at: explicit.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        <!doctype html>
        <script type="module" src="./assets/index-live.js"></script>
        """.write(to: explicit, atomically: true, encoding: .utf8)
        try writeGooseACPWebUIManifest(nextTo: explicit)

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
                includeBundledCandidates: false
            ) == nil
        )
        let diagnostics = GooseWebUIResolver.diagnosticSummary(
            appSupportDirectory: nil,
            currentDirectory: root.path,
            environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
            includeBundledCandidates: false
        )
        #expect(diagnostics.contains("missing-referenced-asset:assets/index-live.js"))

        try FileManager.default.createDirectory(
            at: explicit.deletingLastPathComponent().appendingPathComponent("assets"),
            withIntermediateDirectories: true
        )
        try gooseACPWebUIBridgeFixtureSource.write(
            to: explicit.deletingLastPathComponent().appendingPathComponent("assets/index-live.js"),
            atomically: true,
            encoding: .utf8
        )
        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: nil,
                currentDirectory: root.path,
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path],
                includeBundledCandidates: false
            ) == explicit
        )
    }
}

@Suite("Goose Web UI staging")
struct GooseWebUIStagingTests {
    @Test("staging script forces file-relative renderer assets")
    func stagingScriptForcesRelativeRendererAssets() throws {
        let script = try loadRepoTextFile("stage-goose-web-ui.sh")
        #expect(script.contains("vite.renderer.config.mts"))
        #expect(script.contains("base: './'"))
        #expect(script.contains("Goose Web UI artifact references a missing local asset"))
        #expect(script.contains("acpChatFeatureFlag.ts"))
        #expect(script.contains("export const USE_ACP_CHAT = true;"))
        #expect(script.contains("goose.providersList_unstable({ providerIds: [] })"))
        #expect(script.contains("getProviderInventoryAcpClient()"))
        #expect(script.contains("getProviderCatalogAcpClient()"))
        #expect(script.contains("shared-getAcpClient-provider-inventory"))
        #expect(script.contains("function getProviderInventoryAcpClient(): ReturnType<typeof getAcpClient>"))
        #expect(script.contains("return getAcpClient();"))
        #expect(script.contains("__epistemosGooseACPRequestSerialization"))
        #expect(script.contains("return serializeACPRequests(client);"))
        #expect(script.contains("__epistemosGooseProviderInventoryEvents"))
        #expect(script.contains("Goose ACP provider inventory failed:"))
        #expect(script.contains("Goose ACP client initialization for provider inventory"))
        #expect(script.contains("Goose ACP provider inventory returned zero providers."))
        #expect(script.contains("goose.providersCatalogList_unstable({"))
        #expect(script.contains("goose.providersSetupCatalogList_unstable({})"))
        #expect(script.contains("goose.providersCatalogTemplate_unstable({ providerId })"))
        #expect(script.contains("epistemos-acp-full-catalog-provider-surface"))
        #expect(script.contains("catalogEntries.map(catalogEntryProviderDetails)"))
        #expect(script.contains("listAcpProviderCatalog(format)"))
        #expect(script.contains("readAcpProviderCatalogTemplate(providerId)"))
        #expect(script.contains("goose.providersSupportedModelsList_unstable({ providerId })"))
        #expect(script.contains("listAcpProviderModels(p.name)"))
        #expect(script.contains("name: model.id || model.name"))
        #expect(script.contains("const inventoryModels = new Map(p.metadata.known_models.map"))
        #expect(script.contains("Goose ACP supported model inventory returned zero models"))
        #expect(script.contains("LM Studio is not reachable at http://localhost:1234"))
        #expect(script.contains("src/epistemos/appsBridge.ts"))
        #expect(script.contains("Epistemos Apps bridge unavailable"))
        #expect(script.contains("import { exportApp, importApp, listApps } from '../../epistemos/appsBridge';"))
        #expect(script.contains("import { listApps } from '../epistemos/appsBridge';"))
        #expect(script.contains("import { listApps } from '../../epistemos/appsBridge';"))
        #expect(script.contains("readFile?: (path: string) => Promise<NativeFileReadResult>;"))
        #expect(script.contains("filters: [{ name: 'HTML', extensions: ['html', 'htm'] }]"))
        #expect(script.contains("await importHtmlApp(fileResponse.file);"))
        #expect(script.contains("Native file contents were unavailable"))
        #expect(script.contains("goose.defaultsRead_unstable({})"))
        #expect(script.contains("goose.defaultsSave_unstable({"))
        #expect(script.contains("await saveAcpProviderDefaults(providerName, modelName)"))
        #expect(script.contains("client.setSessionConfigOption({ sessionId, configId: 'model', value: modelId })"))
        #expect(script.contains("client.setSessionConfigOption({ sessionId, configId: 'provider', value: providerId })"))
        #expect(script.contains("await saveAcpSessionModel(sessionId, modelName)"))
        #expect(script.contains("await saveAcpSessionProvider(sessionId, providerName)"))
        #expect(script.contains("isSecret?: boolean"))
        #expect(script.contains("showOpenDialog?: (options?: unknown)"))
        #expect(script.contains("EPISTEMOS_GOOSE_UI_VALIDATE_ONLY"))
        #expect(script.contains("EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK"))
        #expect(script.contains("../node_modules/.bin/tsc --noEmit"))
        #expect(script.contains("Validated ACP Goose Web UI staging overlay without building."))
        #expect(script.contains("! grep -q \"Changing provider for an active ACP session is not wired yet.\""))
        #expect(script.contains("replaceRequired("))
        #expect(script.contains("'provider catalog ACP branch'"))
        #expect(script.contains("ConfigContext staged source is missing required ACP provider snippet"))
        #expect(script.contains("localAcpConfigKeys = new Set"))
        #expect(script.contains("GOOSE_TELEMETRY_ENABLED"))
        #expect(script.contains("local-acp-config-GOOSE_TELEMETRY_ENABLED"))
        #expect(script.contains("local-acp-native-config-persistence"))
        #expect(script.contains("LOCAL_ACP_NATIVE_CONFIG_PREFIX = 'acp.localConfig.'"))
        #expect(script.contains("async function readNativeLocalAcpConfigValue"))
        #expect(script.contains("await bridge.getSetting(`${LOCAL_ACP_NATIVE_CONFIG_PREFIX}${key}`)"))
        #expect(script.contains("async function saveNativeLocalAcpConfigValue"))
        #expect(script.contains("await bridge.setSetting(`${LOCAL_ACP_NATIVE_CONFIG_PREFIX}${key}`, configValue(value))"))
        #expect(script.contains("async function removeNativeLocalAcpConfigValue"))
        #expect(script.contains("await bridge.setSetting(`${LOCAL_ACP_NATIVE_CONFIG_PREFIX}${key}`, null)"))
        #expect(script.contains("const nativeValue = await readNativeLocalAcpConfigValue(key)"))
        #expect(script.contains("await saveNativeLocalAcpConfigValue(key, stringValue)"))
        #expect(script.contains("await removeNativeLocalAcpConfigValue(key)"))
        #expect(script.contains("ProviderSettingsPage.tsx"))
        #expect(script.contains("'initial ACP provider load'"))
        #expect(script.contains("Provider catalog failed:"))
        #expect(script.contains("ProviderSettingsPage staged source is missing required ACP provider snippet"))
        #expect(script.contains("ProviderCatalogPicker.tsx"))
        #expect(script.contains("'ACP provider catalog list'"))
        #expect(script.contains("'ACP provider catalog template'"))
        #expect(script.contains("__epistemosGooseProviderCatalogError"))
        #expect(script.contains("__epistemosGooseProviderCatalogEvents"))
        #expect(script.contains("ProviderCatalogPicker staged source is missing required ACP catalog snippet"))
        #expect(script.contains("provider-catalog-template-choice"))
        #expect(script.contains("Goose Web UI artifact is missing required ACP provider catalog marker"))
        #expect(!script.contains("OnboardingGuard.tsx"))
        #expect(!script.contains("return <>{children}</>"))
        #expect(script.contains("permissionRequests.ts"))
        #expect(script.contains("requestPermission(request)"))
        #expect(script.contains("elicitationRequests.ts"))
        #expect(script.contains("requestElicitation(request)"))
    }

    @Test("staging grafts wire live config-status, model capabilities, and thinking-effort/mode through ACP (feature-parity gate)")
    func stagingGraftsWireLiveParityFeatures() throws {
        let script = try loadRepoTextFile("stage-goose-web-ui.sh")
        // #1 live provider config-status overlay: fixes the empty Switch-Models provider
        // dropdown, the missing green checks, and ready-by-default. is_configured must be
        // overlaid live, never left hardcoded false on the catalog surface.
        #expect(script.contains("async function overlayConfiguredStatus"))
        #expect(script.contains("config-status-overlay"))
        #expect(script.contains("async function getAcpProvidersBase"))
        #expect(script.contains("epistemos-acp-authenticate-status-cache-reset"))
        // Model capabilities (reasoning + context_limit) sourced from the live provider
        // INVENTORY, not the capability-less supported-models list. Unblocks the Thinking
        // Effort selector (gated on reasoning===true) and the context-window denominator.
        #expect(script.contains("epistemos-acp-inventory-model-capabilities"))
        #expect(script.contains("providersList_unstable({ providerIds: [providerId] })"))
        #expect(script.contains("(entry?.models ?? []).map(modelInfo)"))
        // Thinking Effort + Mode applied LIVE to the session via setSessionConfigOption.
        #expect(script.contains("export async function saveAcpSessionThinkingEffort"))
        #expect(script.contains("configId: 'thinking_effort'"))
        #expect(script.contains("export async function saveAcpSessionMode"))
        #expect(script.contains("configId: 'mode'"))
        #expect(script.contains("await saveAcpSessionThinkingEffort(sessionId, String(thinkingEffort))"))
        // In-chat model switch (#9): the global-default provider guard must be removed so
        // selecting a model on the default provider still applies its provider.
        #expect(!script.contains("providerName !== currentProvider"))
        // Provider OAuth sign-in surfaced from the live setupMethod (was hardcoded false).
        #expect(script.contains("epistemos-acp-oauth-setup-method"))
        #expect(script.contains("const isOauth = method.includes('oauth')"))
        // Credential delete in Settings -> Auth wired to the live ACP delete path.
        #expect(script.contains("can_delete: true"))
        #expect(script.contains("'ACP provider secret delete'"))
        #expect(script.contains("await deleteAcpProviderConfig(secretToDelete.provider)"))
        // Settings config map reconstructed live from ACP (un-blocks Chat/Security UI).
        #expect(script.contains("export async function reconstructAcpConfig"))
        #expect(script.contains("'ACP config map reconstruction'"))
        #expect(script.contains("setConfig(await reconstructAcpConfig())"))
        // Preference-backed config persists ACROSS RESTART through the live
        // preferences/save+read ACP methods (Thinking Effort was the owner-flagged
        // case: "what about the model of effort... I don't see effort"). Without this
        // the value was written to an in-memory map that reset every load and never
        // reached Goose. PreferenceKey must come from the SDK type, the key map must
        // cover the four persisted keys, and the read MUST be timeout-bounded so it
        // can't block route renders (same regression class the config-status overlay hit).
        #expect(script.contains("epistemos-acp-preference-backed-config"))
        #expect(script.contains("const preferenceBackedConfigKeys: Record<string, PreferenceKey>"))
        #expect(script.contains("GOOSE_THINKING_EFFORT: 'gooseThinkingEffort'"))
        #expect(script.contains("GOOSE_AUTO_COMPACT_THRESHOLD: 'autoCompactThreshold'"))
        #expect(script.contains("VOICE_DICTATION_PROVIDER: 'voiceDictationProvider'"))
        #expect(script.contains("VOICE_DICTATION_PREFERRED_MIC: 'voiceDictationPreferredMic'"))
        #expect(script.contains("async function savePreferenceConfig"))
        #expect(script.contains("client.goose.preferencesSave_unstable({ values: [{ key: prefKey"))
        #expect(script.contains("async function readPreferenceConfig"))
        #expect(script.contains("client.goose.preferencesRead_unstable({ keys: [prefKey] })"))
        #expect(script.contains("'Goose ACP preference read'"))
        #expect(script.contains("async function removePreferenceConfig"))
        #expect(script.contains("client.goose.preferencesRemove_unstable({ keys: [prefKey] })"))
        #expect(script.contains("await removePreferenceConfig(key)"))
        #expect(script.contains("if (key in preferenceBackedConfigKeys)"))
        #expect(script.contains("""
  if (key in preferenceBackedConfigKeys) {
    await removePreferenceConfig(key);
    return;
  }
  if (isLocalAcpConfigKey(key)) {
"""))
        // First-run welcome provider grid (OnboardingGuard -> ProviderSelector)
        // populated from the live ACP catalog. The upstream REST /config/providers
        // does not exist in ACP mode, so the un-grafted fetchProviders threw and the
        // grid rendered EMPTY -- the owner-reported "my app is not doing that at all"
        // (real Goose shows ~7 providers, the configured ones marked ready). Must NOT
        // bypass onboarding (the OnboardingGuard passthrough is separately forbidden).
        #expect(script.contains("epistemos-acp-onboarding-provider-grid"))
        #expect(script.contains("import { createAcpCustomProvider, getAcpProviders } from '../../acp/providers';"))
        #expect(script.contains("setProviderList(await getAcpProviders())"))
        #expect(script.contains("ProviderSelector import anchor not found"))
        #expect(script.contains("ProviderSelector load anchor not found"))
        // Custom-provider CRUD (create/read/update/delete) bridged onto the live
        // providersCustom*_unstable methods. Upstream used dead REST
        // /config/custom-providers (404 in ACP mode) -> adding or editing a custom
        // provider threw silently. ProviderGrid (Settings) + ProviderSelector
        // (onboarding "Add a custom provider") are both covered; the desktop
        // snake_case body is mapped to the ACP camelCase wire shape and the read
        // DTO mapped back into the DeclarativeProviderConfig the edit form consumes.
        #expect(script.contains("epistemos-acp-custom-provider-crud"))
        #expect(script.contains("export async function createAcpCustomProvider"))
        #expect(script.contains("export async function updateAcpCustomProvider"))
        #expect(script.contains("export async function deleteAcpCustomProvider"))
        #expect(script.contains("export async function readAcpCustomProvider"))
        #expect(script.contains("client.goose.providersCustomCreate_unstable("))
        #expect(script.contains("client.goose.providersCustomUpdate_unstable("))
        #expect(script.contains("client.goose.providersCustomDelete_unstable({ providerId })"))
        #expect(script.contains("client.goose.providersCustomRead_unstable({ providerId })"))
        #expect(script.contains("await updateAcpCustomProvider(editingProvider.id, data)"))
        #expect(script.contains("await deleteAcpCustomProvider(editingProvider.id)"))
        #expect(script.contains("providerId = await createAcpCustomProvider(data)"))
        #expect(script.contains("ProviderGrid import anchor not found"))
        // Paseo phase-5 provider picker: surface the already-live ACP/CLI engine
        // family in Goose's own provider/model UI instead of rebuilding a native rail.
        #expect(script.contains("epistemos-provider-engine-picker-acp-family"))
        #expect(script.contains("epistemosProviderEngineLabel(provider)"))
        #expect(script.contains("data-testid=\"epistemos-provider-engine-label\""))
        #expect(script.contains("epistemos-provider-engine-picker-grouped"))
        #expect(script.contains("data-epistemos-provider-engine-group"))
        #expect(script.contains("data-epistemos-provider-engine-option"))
        #expect(script.contains("options={providerOptionGroups}"))
        // Paseo phase-5 session tabs: Goose already keeps active sessions mounted;
        // surface that as fast WebUI tabs and keyboard switching instead of native chrome.
        #expect(script.contains("data-epistemos-session-tabs"))
        #expect(script.contains("data-epistemos-session-tabs-command-switch"))
        #expect(script.contains("isOnPairRoute && <SessionTabsStrip activeSessions={activeSessions} />"))
        #expect(script.contains("REMOVE_ACTIVE_SESSION = 'remove-active-session'"))
        #expect(script.contains("const removeActiveSession ="))
        #expect(script.contains("const handleRemoveActiveSession ="))
        #expect(script.contains("const closeSessionTab ="))
        #expect(script.contains("const pairPathForSession = useCallback"))
        #expect(script.contains("const splitPeerPathForSession = useCallback"))
        #expect(script.contains("searchParams.get('epistemosSplitPeer')"))
        #expect(script.contains("const cycleSplitPeer = useCallback"))
        #expect(script.contains("const isSplitPeer ="))
        #expect(script.contains("data-epistemos-session-split-peer"))
        #expect(script.contains("Show \\${label} beside current session"))
        #expect(script.contains("Show ${label} beside current session"))
        #expect(script.contains("data-epistemos-session-split-toggle"))
        #expect(script.contains("event.key.toLowerCase() === 'd'"))
        #expect(script.contains("event.shiftKey"))
        #expect(script.contains("data-epistemos-session-split"))
        #expect(script.contains("requestedSplitPartner"))
        #expect(script.contains("grid h-full w-full grid-cols-2 gap-2"))
        // Anti-silent-drift: the five formerly-silent ACP grafts (which would revert
        // to dead-in-ACP REST endpoints if upstream reformats their anchors) must
        // hard-FAIL the build on anchor drift, like the rest of the file. Lock each
        // throw so they cannot regress back to the silent `if (includes) replace` form
        // -- the systemic "feature silently goes missing" root cause.
        #expect(script.contains("epistemos-acp-graft-hardfail"))
        #expect(script.contains("DefaultSubmitHandler readConfig ACP anchor not found"))
        #expect(script.contains("DefaultSubmitHandler getProviderModels ACP anchor not found"))
        #expect(script.contains("ProviderConfigurationModal OAuth ACP anchor not found"))
        #expect(script.contains("ProviderConfigurationModal delete-cleanup ACP anchor not found"))
        #expect(script.contains("ProviderConfigForm onboarding OAuth ACP anchor not found"))
        // Missing-feature audit gap #7: AlertBox auto-compact threshold SAVE routed
        // off the dead REST upsertConfig onto the ACP-wired ConfigContext.upsert (so
        // it persists via preferences instead of throwing "Failed to save threshold").
        #expect(script.contains("epistemos-acp-alertbox-threshold"))
        #expect(script.contains("const { read, upsert } = useConfig();"))
        #expect(script.contains("await upsert('GOOSE_AUTO_COMPACT_THRESHOLD', newThreshold, false)"))
        #expect(script.contains("AlertBox threshold upsertConfig anchor not found"))
        // Missing-feature audit gap #1: tool list (MCP-apps + tool-call rendering)
        // routed off the dead REST getTools onto the live toolsList_unstable via
        // listAcpSessionTools (extension-prefix scope + full-list fallback so it can
        // never be worse than the REST path it replaces).
        #expect(script.contains("epistemos-acp-session-tools"))
        #expect(script.contains("export async function listAcpSessionTools"))
        #expect(script.contains("client.goose.toolsList_unstable({ sessionId })"))
        #expect(script.contains("scoped.length > 0 ? scoped : all"))
        #expect(script.contains("epistemos-acp-tools-cache"))
        #expect(script.contains("listAcpSessionTools(sessionId, extensionName)"))
        #expect(script.contains("toolsCache getTools call anchor not found"))
    }

    @Test("Goose Swift surface does not carry a provider or model roster")
    func gooseSwiftSurfaceDoesNotHardcodeProviderModelRoster() throws {
        let files = try mirroredSourceFileURLs(
            under: "Epistemos/Goose",
            includingExtensions: ["swift"]
        )
        let forbiddenRosterTokens = [
            "Anthropic",
            "Claude",
            "Gemini",
            "Google",
            "GPT-",
            "Groq",
            "Mistral",
            "OpenAI",
            "OpenRouter",
            "Perplexity",
            "xAI",
        ]
        // #9/#17/#28: the case-sensitive provider-name set above is blind to a hardcoded MODEL
        // roster (lowercase model ids). Add hyphenated model-id stems + Claude/OpenAI model
        // families, matched case-insensitively. These are SAFE against false-positives on the
        // legitimate UPPERCASE `*_API_KEY` credential-passthrough env-var lists (which use
        // underscores, e.g. GEMINI_API_KEY, never the hyphenated `gemini-` model-id form).
        let forbiddenModelStems = [
            "gpt-", "claude-", "gemini-", "llama-", "deepseek-", "o1-", "o3-",
            "mixtral", "qwen", "sonnet", "haiku", "opus",
        ]
        var hits: [String] = []
        for file in files {
            let relativePath = file.path.components(separatedBy: "/Epistemos/").last.map { "Epistemos/\($0)" } ?? file.lastPathComponent
            let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                for token in forbiddenRosterTokens where line.contains(token) {
                    hits.append("\(relativePath):\(index + 1):\(token)")
                }
                let lowercased = line.lowercased()
                for stem in forbiddenModelStems where lowercased.contains(stem) {
                    hits.append("\(relativePath):\(index + 1):\(stem)")
                }
                if line.contains("Ollama"), !line.contains("checkForOllama") {
                    hits.append("\(relativePath):\(index + 1):Ollama")
                }
            }
        }
        #expect(hits.isEmpty, "Goose provider/model inventory must be ACP-derived, not hardcoded in Swift: \(hits.joined(separator: ", "))")
    }
}

@Suite("Goose WebView boot shim")
struct GooseWebViewBootShimTests {
    @Test("bootstrap script exposes only the narrow Goose boot affordances")
    func bootstrapScriptIsNarrow() {
        let bootstrap = GooseWebBootstrap(
            baseURL: URL(string: "http://127.0.0.1:3284")!,
            secretKey: "secret-123",
            config: GooseWebConfig(version: "test-version")
        )
        let script = GooseWebBootShim.bootstrapScript(for: bootstrap)
        #expect(script.contains("getGoosedHostPort"))
        #expect(script.contains("getSecretKey"))
        #expect(script.contains("getAcpUrl"))
        #expect(script.contains("getConfig"))
        #expect(script.contains("appConfig"))
        #expect(script.contains("requestPermission"))
        #expect(script.contains("requestElicitation"))
        #expect(script.contains("epistemosGoosePrompt"))
        #expect(script.contains("epistemosGooseNative"))
        #expect(script.contains("acpTrace: acpTrace.snapshot"))
        #expect(script.contains("consoleEvents: () => consoleEvents.slice()"))
        #expect(script.contains("traceSocket: (state, detail = null)"))
        #expect(script.contains("window.WebSocket = TracedWebSocket"))
        #expect(script.contains("outgoingMethodCounts: methodCounts('out')"))
        #expect(!script.contains("ipcRenderer"))
        #expect(!script.contains("require("))
    }

    @Test("default config still emits a valid bootstrap payload")
    func defaultConfigBootstrapIsValid() {
        let bootstrap = GooseWebBootstrap(
            baseURL: URL(string: "http://127.0.0.1:3284")!,
            secretKey: "secret-123"
        )
        let script = GooseWebBootShim.bootstrapScript(for: bootstrap)
        #expect(script.contains("http:\\/\\/127.0.0.1:3284"))
        #expect(script.contains("ws:\\/\\/127.0.0.1:3284\\/acp?token=secret-123"))
        #expect(script.contains("USE_ACP_CHAT"))
        #expect(script.contains("GOOSE_API_HOST"))
        #expect(script.contains("getConfig: { configurable: true, value: () => Object.assign({}, runtimeConfig) }"))
        #expect(!script.contains("getConfig: { configurable: true, value: async"))
    }

    @Test("bootstrap script bounds imported MCP app storage")
    func bootstrapScriptBoundsImportedMCPAppStorage() {
        let bootstrap = GooseWebBootstrap(
            baseURL: URL(string: "http://127.0.0.1:3284")!,
            secretKey: "secret-123"
        )
        let script = GooseWebBootShim.bootstrapScript(for: bootstrap)

        #expect(script.contains("const maxImportedApps = 32;"))
        #expect(script.contains("const maxImportedAppHtmlBytes = 16 * 1024 * 1024;"))
        #expect(script.contains("const maxImportedAppNameCharacters = 128;"))
        #expect(script.contains("utf8ByteLength(html) > maxImportedAppHtmlBytes"))
        #expect(script.contains("apps.slice(-maxImportedApps)"))
        #expect(script.contains("boundedImportedAppName(title)"))
    }

    @Test("bootstrap script bounds runtime buffers and native bridge payloads")
    func bootstrapScriptBoundsRuntimeBuffersAndNativeBridgePayloads() {
        let bootstrap = GooseWebBootstrap(
            baseURL: URL(string: "http://127.0.0.1:3284")!,
            secretKey: "secret-123"
        )
        let script = GooseWebBootShim.bootstrapScript(for: bootstrap)

        #expect(script.contains("const maxConsoleMessageCharacters = 4096;"))
        #expect(script.contains("const maxACPTraceFrameCharacters = 1024 * 1024;"))
        #expect(script.contains("const maxNativeBridgePayloadBytes = 16 * 1024 * 1024;"))
        #expect(script.contains("const maxNativePromptPayloadBytes = 1024 * 1024;"))
        #expect(script.contains("if (data.length > maxACPTraceFrameCharacters) return null;"))
        #expect(script.contains("boundedJSONClone(request, maxNativePromptPayloadBytes, 'native prompt')"))
        #expect(script.contains("boundedNativeAffordanceName(name)"))
        #expect(script.contains("boundedJSONClone(Array.isArray(args) ? args : [], maxNativeBridgePayloadBytes, 'native affordance')"))
        #expect(script.contains("postNativeAffordance('getSetting', [key])"))
        #expect(script.contains("postNativeAffordance('setSetting', [key, value])"))
        #expect(!script.contains("localStorage.getItem(settingsStorageKey)"))
        #expect(!script.contains("localStorage.setItem(settingsStorageKey"))
    }

    @Test("bootstrap payload serialization failure stays loud")
    func bootstrapSerializationFailureStaysLoud() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebBootShim.swift")
        #expect(!source.contains(#"return "{}""#))
        #expect(source.contains("assertionFailure(bootstrapSerializationFailureMessage)"))
        #expect(source.contains(#"throw new Error("Epistemos failed to serialize the Goose Web boot payload.")"#))
    }

    @Test("traced WebSocket proxy keeps method identity stable")
    func tracedWebSocketMethodIdentityIsStable() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebBootShim.swift")
        #expect(source.contains("const tracedSend = (data) =>"))
        #expect(source.contains("const boundMethods = new Map();"))
        #expect(source.contains("cached?.source === value"))
        #expect(source.contains("Reflect.get(target, property, target)"))
        #expect(!source.contains("value.bind(target) : value"))
    }

    @Test("Goose Web UI loads through the hash route used by the Electron renderer")
    func gooseWebUIBootURLUsesHashRoute() throws {
        let index = URL(fileURLWithPath: "/tmp/goose-web-ui/index.html")
        let url = GooseWebSurfaceView.bootURL(for: index)
        #expect(url.scheme?.hasPrefix("epistemos-goose-") == true)
        #expect(url.host?.hasPrefix("app-") == true)
        #expect(url.path.hasPrefix("/__epistemos-goose/"))
        #expect(url.query?.hasPrefix("v=") == true)
        #expect(url.fragment == "/?")

        let loopback = GooseWebSurfaceView.loopbackURL(
            baseURL: URL(string: "http://localhost:54444/")!,
            route: "/configure-providers"
        )
        #expect(loopback.scheme == "http")
        #expect(loopback.host == "localhost")
        #expect(loopback.query?.hasPrefix("v=") == true)
        #expect(loopback.fragment == "/configure-providers")

        let relativeURL = GooseWebSurfaceView.routeURL("settings?section=models")
        #expect(relativeURL.fragment == "/settings?section=models")

        let oversizedRoute = "/" + String(
            repeating: "r",
            count: GooseWebSurfaceView.maxGooseRouteCharacters + 256
        )
        let boundedRouteURL = GooseWebSurfaceView.routeURL(oversizedRoute)
        #expect(boundedRouteURL.fragment?.count == GooseWebSurfaceView.maxGooseRouteCharacters)
        let boundedLoopbackURL = GooseWebSurfaceView.loopbackURL(
            baseURL: URL(string: "http://127.0.0.1:54445")!,
            route: oversizedRoute
        )
        #expect(boundedLoopbackURL.fragment?.count == GooseWebSurfaceView.maxGooseRouteCharacters)

        let oversizedStatus = String(
            repeating: "s",
            count: GooseWebSurfaceView.maxPlaceholderStatusCharacters + 40
        )
        #expect(
            GooseWebSurfaceView.boundedPlaceholderStatus(" \n\(oversizedStatus)\n ")
                .count == GooseWebSurfaceView.maxPlaceholderStatusCharacters
        )
        #expect(GooseWebSurfaceView.boundedPlaceholderStatus(" \n\t ") == "Goose surface unavailable.")

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(source.contains("let boundedStatus = boundedPlaceholderStatus(status)"))
        #expect(!source.contains("escapeHTML(status)"))
    }

    @Test("Goose Web UI load waits until the loopback server can serve the index")
    func gooseWebUILoadWaitsForServedIndex() async throws {
        let missingRoot = try temporaryDirectory()
        let missingServer = WorkSPAServer(root: missingRoot, advertisedHost: "127.0.0.1")
        defer {
            missingServer.stop()
            try? FileManager.default.removeItem(at: missingRoot)
        }
        let missingBaseURL = try await startGooseSurfaceTestServer(missingServer)
        #expect(await GooseWebSurfaceView.gooseUIReady(baseURL: missingBaseURL) == false)

        let readyRoot = try temporaryDirectory()
        try "<!doctype html><html><head><title>goose</title></head><body>ready</body></html>".write(
            to: readyRoot.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        let readyServer = WorkSPAServer(root: readyRoot, advertisedHost: "127.0.0.1")
        defer {
            readyServer.stop()
            try? FileManager.default.removeItem(at: readyRoot)
        }
        let readyBaseURL = try await startGooseSurfaceTestServer(readyServer)
        #expect(await GooseWebSurfaceView.gooseUIReady(baseURL: readyBaseURL) == true)

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        #expect(source.contains("while true"))
        #expect(source.contains("await Self.gooseUIReady(baseURL: baseURL)"))
        #expect(source.contains("request.httpMethod = \"HEAD\""))
        #expect(source.contains("@State private var loadedUIForConnectionKey"))
        #expect(source.contains("loadedUIForConnectionKey == key"))
        #expect(source.contains("loadedUIForConnectionKey = connectionKey"))
        #expect(!source.contains("Goose Web UI server timed out"))
    }

    @Test("Goose Web UI first render waits for runtime health without blocking on native ACP")
    func gooseWebUIFirstRenderWaitsForRuntimeHealthWithoutBlockingOnNativeACP() throws {
        let surface = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        let bridge = try loadRepoTextFile("Epistemos/Goose/GooseACPEventBridge.swift")

        #expect(surface.contains("await Self.runtimeHealthReady(baseURL: connection.baseURL)"))
        #expect(surface.contains("case .connected:"))
        #expect(!surface.contains("await runtimeACPReady(connection: connection)"))
        #expect(!surface.contains("private func runtimeACPReady(connection: GooseRuntimeConnection)"))
        #expect(surface.contains("Goose Web UI waiting for runtime"))
        #expect(surface.contains("webUILoadTask = Task { await loadGooseUI(connection: connection) }"))
        #expect(surface.contains("loadedUIForConnectionKey = connectionKey"))
        #expect(bridge.contains("initialHandshakeAttempts: nil"))
        #expect(bridge.contains("maxRetryDelayNanoseconds: Self.urlHandshakeMaximumRetryDelayNanoseconds"))
    }

    @Test("Goose surface does not render blank while retrying runtime startup")
    func gooseSurfaceShowsStartupPlaceholderAndRetriesRuntime() throws {
        let surface = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")

        #expect(surface.contains("_ = page.load(html: Self.placeholderHTML(status: Self.startingStatus, acpURL: \"\"))"))
        #expect(surface.contains("loadPlaceholder(status: Self.startingStatus)"))
        #expect(surface.contains("@State private var runtimeRetryTask"))
        #expect(surface.contains("scheduleRuntimeRetry(reason: message)"))
        #expect(surface.contains("runtimeRetryDelayNanoseconds(for: retryAttempt)"))
        #expect(surface.contains("supervisor.start(secretKey: secretKey, allowPortFallback: true)"))
        #expect(surface.contains("rebuildPageIfNeeded(for: connection)"))
        #expect(surface.contains("pageBootstrapConnectionKey != key"))
        #expect(surface.contains("GooseWebBootstrap(baseURL: connection.baseURL, secretKey: secretKey)"))
        #expect(surface.contains("@State private var webUILoadTask"))
        #expect(surface.contains("@State private var webUIRenderOverlayStatus"))
        #expect(surface.contains("@State private var surfaceStarted"))
        #expect(surface.contains("guard !surfaceStarted else"))
        #expect(surface.contains("surfaceStarted = false"))
        #expect(surface.contains("_ = page.load(request)"))
        #expect(surface.contains("waitForRenderedGooseUI(connectionKey: connectionKey)"))
        #expect(surface.contains("page.callJavaScript(Self.gooseUIRenderProbeScript)"))
        #expect(surface.contains("Goose Web UI stayed blank ("))
        #expect(surface.contains("loadedUIForConnectionKey = connectionKey"))
    }

    @Test("surface availability requires both Goose runtime and ACP Web UI")
    func surfaceAvailabilityRequiresPortableRuntimeAndWebUI() throws {
        let root = try temporaryDirectory()
        let appSupport = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let runtimeDir = appSupport.appendingPathComponent("Epistemos/GooseRuntime", isDirectory: true)
        let webDir = appSupport.appendingPathComponent("Epistemos/GooseWebUI", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: webDir, withIntermediateDirectories: true)

        let unavailable = GooseSurfaceAvailability.current(
            bundle: nil,
            appSupportDirectory: appSupport,
            currentDirectory: root.path,
            environment: [:],
            includeBundledWebUICandidates: false
        )
        #expect(!unavailable.isReady)
        #expect(unavailable.menuTitle == "Epistemos Goose (runtime/UI missing)")

        let binary = runtimeDir.appendingPathComponent("goose")
        try Data("#!/bin/sh\n".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)

        let runtimeOnly = GooseSurfaceAvailability.current(
            bundle: nil,
            appSupportDirectory: appSupport,
            currentDirectory: root.path,
            environment: [:],
            includeBundledWebUICandidates: false
        )
        #expect(!runtimeOnly.isReady)
        #expect(runtimeOnly.unavailableMessage == "Goose Web UI is not bundled or staged for this build.")

        let index = webDir.appendingPathComponent("index.html")
        try writeGooseACPWebUIArtifact(at: index)

        let ready = GooseSurfaceAvailability.current(
            bundle: nil,
            appSupportDirectory: appSupport,
            currentDirectory: root.path,
            environment: [:],
            includeBundledWebUICandidates: false
        )
        #expect(ready.isReady)
        #expect(ready.menuTitle == "Open Epistemos Goose")
    }

    @Test("surface keeps the Goose runtime secret stable across SwiftUI view reloads")
    func gooseSurfaceSecretLivesInState() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        #expect(source.contains("@State private var secretKey: String"))
        #expect(!source.contains("private let secretKey"))
    }

    @Test("surface replaces the loaded Goose Web UI when the runtime exits")
    func gooseSurfaceHandlesPostLoadRuntimeExit() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(source.contains(".onChange(of: supervisor.status)"))
        #expect(source.contains("handleRuntimeStatusChange"))
        #expect(source.contains("runtimeHealthTask"))
        #expect(source.contains("beginRuntimeHealthMonitor"))
        #expect(source.contains("GooseRuntimeSupervisor.healthCheck(base: baseURL)"))
        #expect(source.contains("supervisor.markRuntimeFailed"))
        #expect(source.contains("gooseUIServer?.stop()"))
        #expect(source.contains("Task { await acpBridge.disconnect() }"))
        #expect(source.contains("loadPlaceholder()"))
    }

    @Test("surface coordinator does not own native ACP prompt panel implementation")
    func gooseSurfaceCoordinatorDoesNotOwnNativePromptPanels() throws {
        let surface = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        let panels = try loadRepoTextFile("Epistemos/Goose/GooseACPNativePromptPanels.swift")

        #expect(!surface.contains("struct GooseACPPermissionPanel"))
        #expect(!surface.contains("struct GooseACPElicitationPanel"))
        #expect(panels.contains("struct GooseACPPermissionPanel"))
        #expect(panels.contains("struct GooseACPElicitationPanel"))
        #expect(panels.contains("private enum GooseNativePromptPanelBounds"))
        #expect(panels.contains("Array(request.options.prefix(GooseNativePromptPanelBounds.maxPermissionOptions))"))
        #expect(panels.contains("LazyVGrid(columns: permissionButtonColumns"))
        #expect(panels.contains(".adaptive(minimum: 122, maximum: 180)"))
        #expect(panels.contains(".lineLimit(1)"))
        #expect(panels.contains("maxElicitationInputCharacters"))
        #expect(panels.contains(".frame(maxHeight: 260)"))
        #expect(panels.contains("panelShape.fill(panelFill)"))
        #expect(panels.contains(".shadow(color: .black.opacity(theme.isDark ? 0.20 : 0.08), radius: 18, y: 8)"))
        #expect(!panels.contains(".ultraThinMaterial"))
        #expect(!panels.contains(".regularMaterial"))
        #expect(!panels.contains("radius: 7, y: 3"))
        #expect(!panels.contains("strokeBorder"))
        #expect(!panels.contains("glassBorder"))
    }

    @Test("affordance disposition ledger marks native file and URL calls as implemented")
    func dispositionLedgerCoversKnownAffordances() {
        let ledger = GooseWebBootShim.dispositionLedger
        #expect(!ledger.values.contains(.deferredWithVisibleError))
        #expect(ledger["getGoosedHostPort"] == .implementedRuntime)
        #expect(ledger["getSecretKey"] == .implementedRuntime)
        #expect(ledger["getAcpUrl"] == .implementedRuntime)
        #expect(ledger["getConfig"] == .implementedNative)
        #expect(ledger["getSetting"] == .implementedNative)
        #expect(ledger["setSetting"] == .implementedNative)
        #expect(ledger["checkForUpdates"] == .hiddenShell)
        #expect(ledger["createChatWindow"] == .implementedRuntime)
        #expect(ledger["closeWindow"] == .implementedRuntime)
        #expect(ledger["reloadApp"] == .implementedRuntime)
        #expect(ledger["showOpenDialog"] == .implementedNative)
        #expect(ledger["showSaveDialog"] == .implementedNative)
        #expect(ledger["directoryChooser"] == .implementedNative)
        #expect(ledger["selectFileOrDirectory"] == .implementedNative)
        #expect(ledger["selectImportSessionFile"] == .implementedNative)
        #expect(ledger["openExternal"] == .implementedNative)
        #expect(ledger["openInChrome"] == .implementedNative)
        #expect(ledger["openDirectoryInExplorer"] == .implementedNative)
        #expect(ledger["showMessageBox"] == .implementedNative)
        #expect(ledger["readFile"] == .implementedNative)
        #expect(ledger["readFileDataURL"] == .implementedNative)
        #expect(ledger["writeFile"] == .implementedNative)
        #expect(ledger["ensureDirectory"] == .implementedNative)
        #expect(ledger["listFiles"] == .implementedNative)
        #expect(ledger["listGitWorktreeDirs"] == .implementedNative)
        #expect(ledger["launchApp"] == .implementedNative)
        #expect(ledger["refreshApp"] == .implementedNative)
        #expect(ledger["closeApp"] == .implementedNative)
        #expect(ledger["openNotificationsSettings"] == .implementedNative)
        #expect(ledger["showNotification"] == .implementedNative)
        #expect(ledger["setMenuBarIcon"] == .implementedNative)
        #expect(ledger["getMenuBarIconState"] == .implementedNative)
        #expect(ledger["setDockIcon"] == .implementedNative)
        #expect(ledger["getDockIconState"] == .implementedNative)
        #expect(ledger["setWakelock"] == .implementedNative)
        #expect(ledger["getWakelockState"] == .implementedNative)
        #expect(ledger["setSpellcheck"] == .implementedNative)
        #expect(ledger["getSpellcheckState"] == .implementedNative)
        #expect(ledger["addRecentDir"] == .implementedNative)
        #expect(ledger["listRecentDirs"] == .implementedNative)
        #expect(ledger["hasAcceptedRecipeBefore"] == .implementedNative)
        #expect(ledger["recordRecipeHash"] == .implementedNative)
        #expect(ledger["apps.list"] == .implementedRuntime)
        #expect(ledger["apps.import"] == .implementedRuntime)
        #expect(ledger["apps.export"] == .implementedRuntime)
    }

    @Test("bootstrap routes file and URL affordances through the native bridge")
    func bootstrapRoutesNativeAffordances() {
        let bootstrap = GooseWebBootstrap(
            baseURL: URL(string: "http://127.0.0.1:3284")!,
            secretKey: "secret-123"
        )
        let script = GooseWebBootShim.bootstrapScript(for: bootstrap)

        #expect(script.contains("postNativeAffordance"))
        #expect(script.contains("requestNativeAffordance"))
        #expect(script.contains("postNativeAffordance('showOpenDialog', [options])"))
        #expect(script.contains("postNativeAffordance('showSaveDialog', [options])"))
        #expect(script.contains("postNativeAffordance('directoryChooser')"))
        #expect(script.contains("postNativeAffordance('selectImportSessionFile')"))
        #expect(script.contains("postNativeAffordance('openExternal', [url])"))
        #expect(script.contains("postNativeAffordance('showMessageBox', [options])"))
        #expect(script.contains("postNativeAffordance('readFile', [filePath])"))
        #expect(script.contains("postNativeAffordance('readFileDataURL', [filePath])"))
        #expect(script.contains("postNativeAffordance('writeFile', [filePath, content])"))
        #expect(script.contains("postNativeAffordance('ensureDirectory', [dirPath])"))
        #expect(script.contains("postNativeAffordance('listFiles', extension === undefined ? [dirPath] : [dirPath, extension])"))
        #expect(script.contains("postNativeAffordance('listGitWorktreeDirs', [dir])"))
        #expect(script.contains("const createChatWindow = async (options = {}) =>"))
        #expect(script.contains("window.location.hash = `${appPath}?${searchParams.toString()}`"))
        #expect(script.contains("emitEvent('set-initial-message', initialMessage"))
        #expect(script.contains("postNativeAffordance('launchApp', [app])"))
        #expect(script.contains("const epistemosGooseApps = Object.freeze"))
        #expect(script.contains("listApps: async () => ({ apps: loadImportedApps() })"))
        #expect(script.contains("importApp: async (html) =>"))
        #expect(script.contains("exportApp: async (name) =>"))
        #expect(script.contains("apps: epistemosGooseApps"))
        #expect(script.contains("postNativeAffordance('refreshApp', [app])"))
        #expect(script.contains("postNativeAffordance('closeApp', [appName])"))
        #expect(script.contains("postNativeAffordance('openNotificationsSettings')"))
        #expect(script.contains("postNativeAffordance('showNotification', [data || {}])"))
        #expect(script.contains("postNativeAffordance('getSetting', [key])"))
        #expect(script.contains("postNativeAffordance('setSetting', [key, value])"))
        #expect(script.contains("postNativeAffordance('setMenuBarIcon', [show])"))
        #expect(script.contains("postNativeAffordance('getMenuBarIconState')"))
        #expect(script.contains("postNativeAffordance('setDockIcon', [show])"))
        #expect(script.contains("postNativeAffordance('getDockIconState')"))
        #expect(script.contains("postNativeAffordance('setWakelock', [enabled])"))
        #expect(script.contains("postNativeAffordance('getWakelockState')"))
        #expect(script.contains("postNativeAffordance('setSpellcheck', [enabled])"))
        #expect(script.contains("postNativeAffordance('getSpellcheckState')"))
        #expect(script.contains("postNativeAffordance('addRecentDir', [dir])"))
        #expect(script.contains("postNativeAffordance('listRecentDirs')"))
        #expect(script.contains("postNativeAffordance('hasAcceptedRecipeBefore', [recipe])"))
        #expect(script.contains("postNativeAffordance('recordRecipeHash', [recipe])"))
        #expect(!script.contains("visibleError('showOpenDialog')"))
        #expect(!script.contains("visibleError('showSaveDialog')"))
        #expect(!script.contains("visibleError('showMessageBox')"))
        #expect(!script.contains("visibleError('directoryChooser')"))
        #expect(!script.contains("visibleError('selectImportSessionFile')"))
        #expect(!script.contains("visibleError('openExternal')"))
        #expect(!script.contains("visibleError('readFile')"))
        #expect(!script.contains("visibleError('readFileDataURL')"))
        #expect(!script.contains("visibleError('writeFile')"))
        #expect(!script.contains("visibleError('ensureDirectory')"))
        #expect(!script.contains("visibleError('listFiles')"))
        #expect(!script.contains("visibleError('listGitWorktreeDirs')"))
        #expect(!script.contains("visibleError('launchApp')"))
        #expect(!script.contains("visibleError('refreshApp')"))
        #expect(!script.contains("visibleError('closeApp')"))
        #expect(!script.contains("visibleError('openNotificationsSettings')"))
        #expect(!script.contains("visibleError('showNotification')"))
        #expect(!script.contains("visibleError('getSetting')"))
        #expect(!script.contains("visibleError('setSetting')"))
        #expect(!script.contains("visibleError('setMenuBarIcon')"))
        #expect(!script.contains("visibleError('getMenuBarIconState')"))
        #expect(!script.contains("visibleError('setDockIcon')"))
        #expect(!script.contains("visibleError('getDockIconState')"))
        #expect(!script.contains("visibleError('setWakelock')"))
        #expect(!script.contains("visibleError('getWakelockState')"))
        #expect(!script.contains("visibleError('setSpellcheck')"))
        #expect(!script.contains("visibleError('getSpellcheckState')"))
    }

    @Test("surface registers the native affordance bridge separately from prompt replies")
    func surfaceRegistersNativeAffordanceBridge() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        #expect(source.contains("@State private var nativeAffordanceBridge: GooseWebNativeAffordanceBridge"))
        #expect(source.contains("name: \"epistemosGoosePrompt\""))
        #expect(source.contains("name: \"epistemosGooseNative\""))
        #expect(source.contains("nativeAffordanceBridge: nativeAffordanceBridge"))
        #expect(source.contains("private var contentHost: some View"))
        #expect(source.contains("WebView(page)"))
        #expect(!source.contains(".opacity(nativeModelsRouteIsActive ? 0 : 1)"))
        #expect(!source.contains(".allowsHitTesting(!nativeModelsRouteIsActive)"))
        #expect(!source.contains("private var nativeModelsRouteIsActive: Bool"))
        #expect(!source.contains("GooseNativeModelsView(bridge: acpBridge)"))
        #expect(source.contains("@State private var activeWebRoute: String"))
        #expect(source.contains("private func setWebRoute"))
        #expect(source.contains("route: activeWebRoute"))
        #expect(!source.contains("handleRouteSelection(\"/configure-providers\")"))
        #expect(source.contains("maxGooseRouteCharacters = 4096"))
        let modelsURL = GooseWebSurfaceView.routeURL("/settings?section=models")
        #expect(modelsURL.scheme?.hasPrefix("epistemos-goose-") == true)
        #expect(modelsURL.host?.hasPrefix("app-") == true)
        #expect(modelsURL.path.hasPrefix("/__epistemos-goose/"))
        #expect(modelsURL.query?.hasPrefix("v=") == true)
        #expect(modelsURL.fragment == "/settings?section=models")
    }
}

@MainActor
@Suite("Goose Web native affordance bridge")
struct GooseWebNativeAffordanceBridgeTests {
    @Test("bridge dispatches injected handlers with Electron-compatible results")
    func bridgeDispatchesInjectedHandlers() throws {
        let bridge = GooseWebNativeAffordanceBridge(handlers: [
            "directoryChooser": { _ in
                ["canceled": false, "filePaths": ["/Users/jojo/Downloads/Epistemos"]]
            },
            "selectFileOrDirectory": { args in
                args.first as? String
            },
        ])

        let directoryResult = try #require(
            bridge.handleAffordance(name: "directoryChooser", args: []) as? [String: Any]
        )
        #expect(directoryResult["canceled"] as? Bool == false)
        #expect(directoryResult["filePaths"] as? [String] == ["/Users/jojo/Downloads/Epistemos"])
        #expect(
            try bridge.handleAffordance(name: "selectFileOrDirectory", args: ["/tmp/example"]) as? String
            == "/tmp/example"
        )
    }

    @Test("external URL policy mirrors Goose blocked and web protocol rules")
    func externalURLPolicyMirrorsGooseRules() {
        let oversizedURL = "https://block.github.io/goose/" + String(
            repeating: "u",
            count: GooseWebNativeAffordanceBridge.maxNativeOpenURLCharacters + 1
        )

        #expect(GooseWebNativeAffordanceBridge.shouldOpenExternalURL("https://block.github.io/goose"))
        #expect(GooseWebNativeAffordanceBridge.shouldOpenExternalURL("mailto:hello@example.com"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("file:///tmp/secret"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("javascript:alert(1)"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("data:text/plain,hello"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL(oversizedURL))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("https://block.github.io/goose\0"))
        #expect(GooseWebNativeAffordanceBridge.shouldOpenBrowserURL("https://block.github.io/goose"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenBrowserURL("mailto:hello@example.com"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenBrowserURL(oversizedURL))
    }

    @Test("bridge persists recents, recipe trust, and scoped file edits")
    func bridgePersistsRecentsRecipeTrustAndScopedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        let projectPath = (project.path as NSString).standardizingPath
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let bridge = GooseWebNativeAffordanceBridge(applicationSupportRoot: root)

        #expect(try bridge.handleAffordance(name: "addRecentDir", args: [projectPath]) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "listRecentDirs", args: []) as? [String] == [projectPath])

        let goosehints = project.appendingPathComponent(".goosehints", isDirectory: false)
        #expect(try bridge.handleAffordance(name: "writeFile", args: [goosehints.path, "phase0"]) as? Bool == true)
        let read = try #require(bridge.handleAffordance(name: "readFile", args: [goosehints.path]) as? [String: Any])
        #expect(read["file"] as? String == "phase0")
        #expect(read["found"] as? Bool == true)
        let files = try #require(bridge.handleAffordance(name: "listFiles", args: [project.path]) as? [String])
        #expect(files.contains(".goosehints"))
        #expect(try bridge.handleAffordance(name: "listFiles", args: [project.path, ".goosehints"]) as? [String] == [".goosehints"])
        let image = project.appendingPathComponent("pixel.png", isDirectory: false)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let dataURL = try #require(bridge.handleAffordance(name: "readFileDataURL", args: [image.path]) as? String)
        #expect(dataURL.hasPrefix("data:image/png;base64,"))

        let oversized = project.appendingPathComponent("oversized.txt", isDirectory: false)
        _ = FileManager.default.createFile(atPath: oversized.path, contents: nil)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(GooseWebNativeAffordanceBridge.maxNativeFileReadBytes + 1))
        try handle.close()
        let oversizedRead = try #require(bridge.handleAffordance(name: "readFile", args: [oversized.path]) as? [String: Any])
        #expect(oversizedRead["file"] as? String == "")
        #expect(oversizedRead["found"] as? Bool == false)
        #expect((oversizedRead["error"] as? String)?.contains("\(GooseWebNativeAffordanceBridge.maxNativeFileReadBytes)") == true)
        let oversizedDataURL = try bridge.handleAffordance(name: "readFileDataURL", args: [oversized.path]) as? String
        #expect(oversizedDataURL == nil)

        let nested = project.appendingPathComponent("schedules", isDirectory: true)
        #expect(try bridge.handleAffordance(name: "ensureDirectory", args: [nested.path]) as? Bool == true)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: nested.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)

        let recipe: [String: Any] = ["id": "recipe.phase0", "version": 1]
        #expect(try bridge.handleAffordance(name: "hasAcceptedRecipeBefore", args: [recipe]) as? Bool == false)
        #expect(try bridge.handleAffordance(name: "recordRecipeHash", args: [recipe]) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "hasAcceptedRecipeBefore", args: [recipe]) as? Bool == true)
        try? FileManager.default.removeItem(at: root)
    }

    @Test("selected import session files are bounded before native reads")
    func selectedImportSessionFilesAreBoundedBeforeNativeReads() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let session = root.appendingPathComponent("session.jsonl", isDirectory: false)
        try #"{"role":"user","content":"hello"}"#.write(to: session, atomically: true, encoding: .utf8)

        let imported = GooseWebNativeAffordanceBridge.importSessionFileResult(filePath: session.path)
        #expect(imported["filePath"] as? String == session.path)
        #expect(imported["contents"] as? String == #"{"role":"user","content":"hello"}"#)
        #expect(imported["error"] == nil)

        let oversized = root.appendingPathComponent("oversized-session.json", isDirectory: false)
        _ = FileManager.default.createFile(atPath: oversized.path, contents: nil)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(GooseWebNativeAffordanceBridge.maxNativeFileReadBytes + 1))
        try handle.close()

        let blocked = GooseWebNativeAffordanceBridge.importSessionFileResult(filePath: oversized.path)
        #expect(blocked["filePath"] as? String == oversized.path)
        #expect(blocked["contents"] as? String == "")
        #expect((blocked["error"] as? String)?.contains("\(GooseWebNativeAffordanceBridge.maxNativeFileReadBytes)") == true)
    }

    @Test("native file data URL reads are bounded regular file reads")
    func nativeFileDataURLReadsAreBoundedRegularFileReads() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(source.contains("readNativeFileData(expandedPath)"))
        #expect(source.contains("readRegularFileData("))
        #expect(source.contains("readRegularFileData(\n                recentDirsURL.path"))
        #expect(source.contains("resourceValues.isRegularFile == true"))
        #expect(source.contains("let readLimit = maxBytes == Int.max ? Int.max : maxBytes + 1"))
        #expect(source.contains("handle.read(upToCount: readLimit)"))
        #expect(source.contains("String(data: data, encoding: .utf8)"))
        #expect(!source.contains("Data(contentsOf: fileURL)"))
        #expect(!source.contains("Data(contentsOf: recentDirsURL)"))
        #expect(!source.contains("String(contentsOfFile: expandedPath"))

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("pixel.png", isDirectory: false)
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])
        try bytes.write(to: file)
        #expect(GooseWebNativeAffordanceBridge.readNativeFileData(file.path) == bytes)
        #expect(GooseWebNativeAffordanceBridge.readRegularFileData(file.path, maxBytes: 2) == nil)
        #expect(GooseWebNativeAffordanceBridge.readNativeFileData(root.path) == nil)

        let oversized = root.appendingPathComponent("oversized.bin", isDirectory: false)
        try createSparseFile(
            oversized,
            size: GooseWebNativeAffordanceBridge.maxNativeFileReadBytes + 1
        )
        #expect(GooseWebNativeAffordanceBridge.readNativeFileData(oversized.path) == nil)
    }

    @Test("native dialog text and buttons are normalized and bounded")
    func nativeDialogTextAndButtonsAreNormalizedAndBounded() {
        let longMessage = "\u{0007}  " + String(
            repeating: "m",
            count: GooseWebNativeAffordanceBridge.maxNativeDialogMessageCharacters + 12
        ) + "  \n"
        let boundedMessage = GooseWebNativeAffordanceBridge.boundedNativeDialogText(
            longMessage,
            maxCharacters: GooseWebNativeAffordanceBridge.maxNativeDialogMessageCharacters,
            fallback: "Goose"
        )
        #expect(boundedMessage?.count == GooseWebNativeAffordanceBridge.maxNativeDialogMessageCharacters)
        #expect(boundedMessage?.first == "m")

        let rawButtons = (0..<(GooseWebNativeAffordanceBridge.maxNativeDialogButtons + 5)).map { index in
            "\u{0008} " + String(
                repeating: "\(index)",
                count: GooseWebNativeAffordanceBridge.maxNativeDialogButtonCharacters + 3
            )
        }
        let boundedButtons = GooseWebNativeAffordanceBridge.boundedNativeDialogButtons([""] + rawButtons)
        #expect(boundedButtons.count == GooseWebNativeAffordanceBridge.maxNativeDialogButtons)
        #expect(boundedButtons.allSatisfy { $0.count <= GooseWebNativeAffordanceBridge.maxNativeDialogButtonCharacters })
        #expect(boundedButtons.allSatisfy { !$0.contains("\u{0008}") })
        #expect(GooseWebNativeAffordanceBridge.boundedNativeDialogButtons(["", "  "]) == ["OK"])
    }

    @Test("native bridge bounds notification text and file dialog filters")
    func nativeBridgeBoundsNotificationTextAndFileDialogFilters() {
        let longTitle = "\u{0007} " + String(
            repeating: "t",
            count: GooseWebNativeAffordanceBridge.maxNativeNotificationTitleCharacters + 7
        )
        let boundedTitle = GooseWebNativeAffordanceBridge.boundedNativeDialogText(
            longTitle,
            maxCharacters: GooseWebNativeAffordanceBridge.maxNativeNotificationTitleCharacters,
            fallback: "Epistemos"
        )
        #expect(boundedTitle?.count == GooseWebNativeAffordanceBridge.maxNativeNotificationTitleCharacters)
        #expect(boundedTitle?.first == "t")

        let rawExtensions = (0..<(GooseWebNativeAffordanceBridge.maxNativeFileDialogExtensions + 12))
            .map { " type\($0) " }
        let boundedExtensions = GooseWebNativeAffordanceBridge.boundedNativeFileDialogExtensions(
            from: [["extensions": rawExtensions]]
        )
        #expect(boundedExtensions?.count == GooseWebNativeAffordanceBridge.maxNativeFileDialogExtensions)
        #expect(boundedExtensions?.first == "type0")
        #expect(
            GooseWebNativeAffordanceBridge.boundedNativeFileDialogExtensions(
                from: [["extensions": ["TXT", ".md", "\u{0008}json", "has space", String(repeating: "x", count: 64)]]]
            ) == ["txt", "md", "json"]
        )
        #expect(GooseWebNativeAffordanceBridge.boundedNativeFileDialogExtensions(from: [["extensions": ["*"]]]) == nil)

        #expect(GooseWebNativeAffordanceBridge.boundedNativeAffordanceName("\u{0007} readFile \n") == "readFile")
        #expect(
            GooseWebNativeAffordanceBridge.boundedNativeAffordanceName(
                String(repeating: "n", count: GooseWebNativeAffordanceBridge.maxNativeAffordanceNameCharacters + 1)
            ) == nil
        )
    }

    @Test("git worktree native affordance paths are bounded")
    func gitWorktreeNativeAffordancePathsAreBounded() {
        let oversizedPath = "/" + String(
            repeating: "w",
            count: GooseWebNativeAffordanceBridge.maxGitWorktreePathCharacters + 1
        )

        #expect(GooseWebNativeAffordanceBridge.boundedGitWorktreePath(" \n/tmp/project\n ") == "/tmp/project")
        #expect(GooseWebNativeAffordanceBridge.boundedGitWorktreePath(" \n\t ") == nil)
        #expect(GooseWebNativeAffordanceBridge.boundedGitWorktreePath(oversizedPath) == nil)
    }

    @Test("native binary lookup bounds inherited PATH")
    func nativeBinaryLookupBoundsInheritedPATH() throws {
        let defaultDirectories = GooseWebNativeAffordanceBridge.defaultNativeBinarySearchDirectories
        let oversizedPath = "/" + String(
            repeating: "p",
            count: GooseWebNativeAffordanceBridge.maxNativeBinarySearchPathCharacters + 1
        )
        let manyDirectories = (0..<(GooseWebNativeAffordanceBridge.maxNativeBinarySearchPathEntries + 7))
            .map { "/tmp/tool-\($0)" }
            .joined(separator: ":")
        let oversizedEntry = "/" + String(
            repeating: "e",
            count: GooseWebNativeAffordanceBridge.maxNativeBinarySearchPathEntryCharacters + 1
        )

        #expect(GooseWebNativeAffordanceBridge.nativeBinarySearchDirectories(environment: [:]) == defaultDirectories)
        #expect(
            GooseWebNativeAffordanceBridge.nativeBinarySearchDirectories(environment: ["PATH": oversizedPath])
            == defaultDirectories
        )
        #expect(
            GooseWebNativeAffordanceBridge.nativeBinarySearchDirectories(environment: ["PATH": "bad\0path:/usr/bin"])
            == defaultDirectories
        )
        #expect(
            GooseWebNativeAffordanceBridge.nativeBinarySearchDirectories(
                environment: ["PATH": "\(oversizedEntry):/usr/bin"]
            ) == ["/usr/bin"]
        )

        let bounded = GooseWebNativeAffordanceBridge.nativeBinarySearchDirectories(
            environment: ["PATH": manyDirectories]
        )
        #expect(bounded.count == GooseWebNativeAffordanceBridge.maxNativeBinarySearchPathEntries)
        #expect(bounded.first == "/tmp/tool-0")
        #expect(
            bounded.last == "/tmp/tool-\(GooseWebNativeAffordanceBridge.maxNativeBinarySearchPathEntries - 1)"
        )

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(source.contains("nativeBinarySearchDirectories()"))
        #expect(source.contains(".prefix(maxNativeBinarySearchPathEntries)"))
    }

    @Test("native affordance error messages are bounded and external errors are redacted")
    func nativeAffordanceErrorMessagesAreBoundedAndExternalErrorsAreRedacted() throws {
        let privatePath = "/Users/example/private-vault/session.jsonl"
        let externalError = NSError(
            domain: privatePath,
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "failed to read \(privatePath)"]
        )
        let message = GooseWebNativeAffordanceBridge.nativeErrorMessage(
            for: externalError,
            fallback: "file read failed"
        )
        let oversized = String(
            repeating: "e",
            count: GooseWebNativeAffordanceBridge.maxNativeErrorMessageCharacters + 40
        )

        #expect(message.contains("file read failed"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=42"))
        #expect(!message.contains(privatePath))
        #expect(!message.contains("failed to read"))
        #expect(message.count <= GooseWebNativeAffordanceBridge.maxNativeErrorMessageCharacters)
        #expect(
            GooseWebNativeAffordanceBridge.boundedNativeErrorMessage(oversized)
                .count == GooseWebNativeAffordanceBridge.maxNativeErrorMessageCharacters
        )
        #expect(
            GooseWebNativeAffordanceBridge.safeNativeErrorDomain(
                String(repeating: "d", count: GooseWebNativeAffordanceBridge.maxNativeErrorDomainCharacters + 12)
            ).count == GooseWebNativeAffordanceBridge.maxNativeErrorDomainCharacters
        )

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(source.contains("nativeErrorMessage(for: error"))
        #expect(!source.contains("replyHandler(nil, error.localizedDescription)"))
        #expect(!source.contains(#""error": error.localizedDescription"#))
    }

    @Test("bridge ignores oversized native persistence inputs")
    func bridgeIgnoresOversizedNativePersistenceInputs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let recentFile = root
            .appendingPathComponent("recent-dirs", isDirectory: true)
            .appendingPathComponent("recent-dirs.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: recentFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try createSparseFile(
            recentFile,
            size: GooseWebNativeAffordanceBridge.maxRecentDirsFileBytes + 1
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let bridge = GooseWebNativeAffordanceBridge(applicationSupportRoot: root)
        #expect(try bridge.handleAffordance(name: "listRecentDirs", args: []) as? [String] == [])

        let oversizedRecipe = String(
            repeating: "r",
            count: GooseWebNativeAffordanceBridge.maxRecipeHashInputBytes + 1
        )
        #expect(try bridge.handleAffordance(name: "recordRecipeHash", args: [oversizedRecipe]) as? Bool == false)
        #expect(try bridge.handleAffordance(name: "hasAcceptedRecipeBefore", args: [oversizedRecipe]) as? Bool == false)
    }

    @Test("file bridge rejects oversized WebView writes")
    func fileBridgeRejectsOversizedWebViewWrites() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bridge = GooseWebNativeAffordanceBridge(
            initialScopedFileRoots: [project],
            applicationSupportRoot: root
        )
        let target = project.appendingPathComponent("oversized-write.txt", isDirectory: false)
        let oversizedContent = String(
            repeating: "a",
            count: GooseWebNativeAffordanceBridge.maxNativeFileWriteBytes + 1
        )

        #expect(try bridge.handleAffordance(name: "writeFile", args: [target.path, oversizedContent]) as? Bool == false)
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test("listFiles caps scoped directory results")
    func listFilesCapsScopedDirectoryResults() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let limit = GooseWebNativeAffordanceBridge.maxNativeDirectoryListEntries
        for index in 0..<(limit + 7) {
            let name = String(format: "entry-%05d.txt", index)
            if !FileManager.default.createFile(
                atPath: project.appendingPathComponent(name, isDirectory: false).path,
                contents: nil
            ) {
                Issue.record("Failed to create \(name)")
            }
        }
        let bridge = GooseWebNativeAffordanceBridge(
            initialScopedFileRoots: [project],
            applicationSupportRoot: root
        )

        let listed = try #require(bridge.handleAffordance(name: "listFiles", args: [project.path]) as? [String])
        #expect(listed.count == limit)
        #expect(listed.first == "entry-00000.txt")
        #expect(listed.last == String(format: "entry-%05d.txt", limit - 1))

        let filtered = try #require(bridge.handleAffordance(name: "listFiles", args: [project.path, ".txt"]) as? [String])
        #expect(filtered.count == limit)
        #expect(filtered.first == "entry-00000.txt")
        #expect(filtered.last == String(format: "entry-%05d.txt", limit - 1))
    }

    @Test("binary lookup and MCP app affordances fail closed instead of silently no-oping")
    func binaryLookupAndMCPAppAffordancesFailClosed() throws {
        let bridge = GooseWebNativeAffordanceBridge()

        #expect(try bridge.handleAffordance(name: "getBinaryPath", args: ["../goose"]) as? String == "")
        #expect(try bridge.handleAffordance(name: "refreshApp", args: [["name": "missing_app"]]) == nil)
        #expect(try bridge.handleAffordance(name: "closeApp", args: ["missing_app"]) == nil)

        do {
            _ = try bridge.handleAffordance(name: "launchApp", args: [["name": "missing_app"]])
            Issue.record("launchApp without URI/text/blob should fail closed instead of no-oping")
        } catch {
            #expect(error.localizedDescription.contains("Missing renderable MCP app content"))
        }

        let cappedBridge = GooseWebNativeAffordanceBridge(maxLaunchedAppWindows: 0)
        do {
            _ = try cappedBridge.handleAffordance(
                name: "launchApp",
                args: [["name": "over_cap", "text": "<!doctype html><title>cap</title>"]]
            )
            Issue.record("launchApp should fail closed when the MCP app window cap is reached")
        } catch {
            #expect(error.localizedDescription.contains("MCP app window"))
            #expect(error.localizedDescription.contains("limit: 0"))
        }
    }

    @Test("MCP app launch clamps untrusted window dimensions")
    func mcpAppLaunchClampsUntrustedWindowDimensions() throws {
        let bridge = GooseWebNativeAffordanceBridge()
        let appName = "oversized_window_\(UUID().uuidString)"
        _ = try bridge.handleAffordance(
            name: "launchApp",
            args: [[
                "name": appName,
                "text": "<!doctype html><title>window</title>",
                "width": 50_000,
                "height": -12,
            ]]
        )
        defer { _ = try? bridge.handleAffordance(name: "closeApp", args: [appName]) }

        let window = try #require(NSApp.windows.first { $0.title == "Oversized Window \(appName.suffix(36))" })
        let contentSize = try #require(window.contentView?.frame.size)
        #expect(contentSize.width == CGFloat(GooseWebNativeAffordanceBridge.maxLaunchedAppWindowWidth))
        #expect(contentSize.height == CGFloat(GooseWebNativeAffordanceBridge.minLaunchedAppWindowHeight))
    }

    @Test("MCP app launch rejects oversized inline content before opening a window")
    func mcpAppLaunchRejectsOversizedInlineContent() throws {
        let bridge = GooseWebNativeAffordanceBridge()
        let appName = "oversized_content_\(UUID().uuidString)"
        let title = "Oversized Content \(appName.suffix(36))"
        let oversizedHTML = String(
            repeating: "x",
            count: GooseWebNativeAffordanceBridge.maxLaunchedAppContentBytes + 1
        )

        do {
            _ = try bridge.handleAffordance(
                name: "launchApp",
                args: [[
                    "name": appName,
                    "text": oversizedHTML,
                ]]
            )
            Issue.record("launchApp should reject oversized inline MCP app content")
        } catch {
            #expect(error.localizedDescription.contains("oversized MCP app content"))
            #expect(error.localizedDescription.contains("\(GooseWebNativeAffordanceBridge.maxLaunchedAppContentBytes)"))
        }
        #expect(!NSApp.windows.contains { $0.title == title })
    }

    @Test("MCP app launch rejects oversized URI before opening a window")
    func mcpAppLaunchRejectsOversizedURIBeforeOpeningWindow() throws {
        let bridge = GooseWebNativeAffordanceBridge()
        let appName = "oversized_uri_\(UUID().uuidString)"
        let title = "Oversized Uri \(appName.suffix(36))"
        let oversizedURI = "https://127.0.0.1/" + String(
            repeating: "u",
            count: GooseWebNativeAffordanceBridge.maxNativeOpenURLCharacters + 1
        )

        do {
            _ = try bridge.handleAffordance(
                name: "launchApp",
                args: [[
                    "name": appName,
                    "uri": oversizedURI,
                ]]
            )
            Issue.record("launchApp should reject oversized MCP app URIs")
        } catch {
            #expect(error.localizedDescription.contains("Missing renderable MCP app content"))
        }
        #expect(!NSApp.windows.contains { $0.title == title })

        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(source.contains("Self.shouldOpenBrowserURL(rawURI),\n                  let url = URL(string: rawURI)"))
    }

    @Test("MCP app launch normalizes and bounds untrusted app names")
    func mcpAppLaunchNormalizesAndBoundsUntrustedAppNames() throws {
        let bridge = GooseWebNativeAffordanceBridge()
        let rawName = "\u{0007} normalized_app_\(UUID().uuidString) \n"
        let normalizedName = String(String.UnicodeScalarView(rawName.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        })).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try bridge.handleAffordance(
            name: "launchApp",
            args: [[
                "name": rawName,
                "text": "<!doctype html><title>name</title>",
            ]]
        )
        defer { _ = try? bridge.handleAffordance(name: "closeApp", args: [rawName]) }

        let title = "Normalized App \(normalizedName.suffix(36))"
        #expect(NSApp.windows.contains { $0.title == title })

        let oversizedName = String(
            repeating: "a",
            count: GooseWebNativeAffordanceBridge.maxLaunchedAppNameCharacters + 1
        )
        do {
            _ = try bridge.handleAffordance(
                name: "launchApp",
                args: [[
                    "name": oversizedName,
                    "text": "<!doctype html><title>too long</title>",
                ]]
            )
            Issue.record("launchApp should reject oversized MCP app names")
        } catch {
            #expect(error.localizedDescription.contains("name over"))
            #expect(error.localizedDescription.contains("\(GooseWebNativeAffordanceBridge.maxLaunchedAppNameCharacters)"))
        }
    }

    @Test("settings affordances persist through the native host")
    func settingsAffordancesPersistThroughNativeHost() throws {
        let suiteName = "epistemos-goose-native-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bridge = GooseWebNativeAffordanceBridge(preferences: defaults)

        #expect(try bridge.handleAffordance(name: "getMenuBarIconState", args: []) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "getDockIconState", args: []) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "getWakelockState", args: []) as? Bool == false)
        #expect(try bridge.handleAffordance(name: "getSpellcheckState", args: []) as? Bool == true)

        #expect(try bridge.handleAffordance(name: "setSpellcheck", args: [false]) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "getSpellcheckState", args: []) as? Bool == false)
        #expect(try bridge.handleAffordance(name: "setWakelock", args: [false]) as? Bool == true)
        #expect(try bridge.handleAffordance(name: "getWakelockState", args: []) as? Bool == false)

        #expect(try bridge.handleAffordance(
            name: "setSetting",
            args: ["responseStyle", "detailed"]
        ) as? Bool == true)
        let stored = try #require(bridge.handleAffordance(name: "getSetting", args: ["responseStyle"]) as? [String: Any])
        #expect(stored["found"] as? Bool == true)
        #expect(stored["value"] as? String == "detailed")

        let reloadedBridge = GooseWebNativeAffordanceBridge(preferences: defaults)
        let reloaded = try #require(
            reloadedBridge.handleAffordance(name: "getSetting", args: ["responseStyle"]) as? [String: Any]
        )
        #expect(reloaded["found"] as? Bool == true)
        #expect(reloaded["value"] as? String == "detailed")

        #expect(try reloadedBridge.handleAffordance(
            name: "setSetting",
            args: ["responseStyle", NSNull()]
        ) as? Bool == true)
        let removed = try #require(
            reloadedBridge.handleAffordance(name: "getSetting", args: ["responseStyle"]) as? [String: Any]
        )
        #expect(removed["found"] as? Bool == false)

        let removalReloadedBridge = GooseWebNativeAffordanceBridge(preferences: defaults)
        let removedAfterReload = try #require(
            removalReloadedBridge.handleAffordance(name: "getSetting", args: ["responseStyle"]) as? [String: Any]
        )
        #expect(removedAfterReload["found"] as? Bool == false)

        let missing = try #require(
            reloadedBridge.handleAffordance(name: "getSetting", args: ["missingSetting"]) as? [String: Any]
        )
        #expect(missing["found"] as? Bool == false)

        let oversizedSetting = String(
            repeating: "s",
            count: GooseWebNativeAffordanceBridge.maxNativeSettingJSONBytes + 1
        )
        #expect(try reloadedBridge.handleAffordance(
            name: "setSetting",
            args: ["oversized", oversizedSetting]
        ) as? Bool == false)
    }

    @Test("file bridge denies unscoped paths")
    func fileBridgeDeniesUnscopedPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let bridge = GooseWebNativeAffordanceBridge(applicationSupportRoot: root)
        let blocked = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("epistemos-goose-blocked-\(UUID().uuidString).txt", isDirectory: false)

        #expect(try bridge.handleAffordance(name: "writeFile", args: [blocked.path, "blocked"]) as? Bool == false)
        let read = try #require(bridge.handleAffordance(name: "readFile", args: [blocked.path]) as? [String: Any])
        #expect(read["found"] as? Bool == false)
        #expect((read["error"] as? String)?.contains("outside scoped roots") == true)
        let blockedDataURL = try bridge.handleAffordance(name: "readFileDataURL", args: [blocked.path]) as? String
        #expect(blockedDataURL == nil)
        try? FileManager.default.removeItem(at: root)
    }

    @Test("file bridge resolves symlinks before scoped reads and writes")
    func fileBridgeRejectsSymlinkEscapes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("project", isDirectory: true)
        let outside = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("epistemos-goose-native-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let outsideSecret = outside.appendingPathComponent("secret.txt", isDirectory: false)
        try "secret".write(to: outsideSecret, atomically: true, encoding: .utf8)
        let symlink = project.appendingPathComponent("linked-secret.txt", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outsideSecret)
        let bridge = GooseWebNativeAffordanceBridge(
            initialScopedFileRoots: [project],
            applicationSupportRoot: root
        )

        let read = try #require(bridge.handleAffordance(name: "readFile", args: [symlink.path]) as? [String: Any])
        #expect(read["found"] as? Bool == false)
        #expect((read["error"] as? String)?.contains("outside scoped roots") == true)
        #expect(try bridge.handleAffordance(name: "writeFile", args: [symlink.path, "changed"]) as? Bool == false)
        #expect(try String(contentsOf: outsideSecret, encoding: .utf8) == "secret")
        try? FileManager.default.removeItem(at: root)
    }

    @Test("unsupported native affordances fail closed")
    func unsupportedAffordanceFailsClosed() {
        let bridge = GooseWebNativeAffordanceBridge()
        do {
            _ = try bridge.handleAffordance(name: "unknownAffordance", args: [])
            Issue.record("unknown affordances should fail closed")
        } catch {
            #expect(error.localizedDescription.contains("Unsupported Epistemos Goose native affordance"))
        }
    }
}

#if !EPISTEMOS_APP_STORE
@Suite("Goose Electron fallback launcher")
struct GooseElectronFallbackLauncherTests {
    @Test("resolver finds an explicit Goose UI workspace and Hermit pnpm")
    func resolverFindsExplicitWorkspace() throws {
        let workspace = try makeGooseElectronFallbackWorkspace()

        let resolved = GooseElectronFallbackLauncher.resolveWorkspace(
            environment: [
                GooseElectronFallbackLauncher.uiRootEnvironmentKey: workspace.uiRoot.path,
            ],
            currentDirectory: "/tmp/not-the-repo",
            homeDirectory: "/tmp/not-home"
        )

        #expect(resolved == workspace)
    }

    @Test("launcher command uses workspace pnpm from the UI workspace")
    func launcherCommandUsesHermitWorkspace() throws {
        let workspace = try makeGooseElectronFallbackWorkspace()

        #expect(GooseElectronFallbackLauncher.launchArguments() == ["--filter", "goose-app", "run", "start-gui"])
        #expect(workspace.pnpm.lastPathComponent == "pnpm")
        #expect(workspace.uiRoot.lastPathComponent == "ui")
    }

    @Test("electron fallback status messages are bounded")
    func electronFallbackStatusMessagesAreBounded() throws {
        let oversized = String(
            repeating: "e",
            count: GooseElectronFallbackLauncher.maxStatusMessageCharacters + 40
        )

        #expect(
            GooseElectronFallbackLauncher.boundedStatusMessage(" \n\(oversized)\n ")
                .count == GooseElectronFallbackLauncher.maxStatusMessageCharacters
        )
        #expect(GooseElectronFallbackLauncher.boundedStatusMessage(" \n\t ", fallback: "fallback") == "fallback")

        let source = try loadRepoTextFile("Epistemos/Goose/GooseElectronFallbackLauncher.swift")
        #expect(source.contains("Self.boundedStatusMessage("))
        #expect(!source.contains("status = .failed(\"Failed to launch real Goose Electron fallback: \\(error.localizedDescription)\""))
    }

    @Test("launcher environment is sanitized and opt-in for Playwright debug")
    func launcherEnvironmentIsSanitized() throws {
        let workspace = try makeGooseElectronFallbackWorkspace()
        let env = GooseElectronFallbackLauncher.processEnvironment(
            workspace: workspace,
            debugPort: 9330,
            base: [
                "PATH": "/usr/bin",
                "HOME": "/Users/jojo",
                "LANG": "en_US.UTF-8",
                "OPENAI_API_KEY": "secret",
                "HF_TOKEN": "secret",
                "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
                "NODE_OPTIONS": "--require /tmp/inject.js",
            ]
        )

        #expect(env["PATH"] == "\(workspace.pnpm.deletingLastPathComponent().path):/usr/bin")
        #expect(env["HOME"] == "/Users/jojo")
        #expect(env["LANG"] == "en_US.UTF-8")
        #expect(env["ELECTRON_IS_DEV"] == "1")
        #expect(env["NODE_ENV"] == "development")
        // GOOSE_ALLOWLIST_BYPASS must NOT be forwarded: the allowlist URL
        // (GOOSE_ALLOWLIST) is never forwarded to the child, so a bypass flag would
        // be a misleading no-op now and a latent security hole if forwarding is added.
        #expect(env["GOOSE_ALLOWLIST_BYPASS"] == nil)
        #expect(env["GOOSE_ALLOWLIST"] == nil)
        #expect(env["HERMIT_ENV"] == workspace.repoRoot.path)
        #expect(env["ENABLE_PLAYWRIGHT"] == "true")
        #expect(env["PLAYWRIGHT_DEBUG_PORT"] == "9330")
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["HF_TOKEN"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)
    }

    @Test("launcher environment drops oversized inherited values and bounds PATH")
    func launcherEnvironmentBoundsInheritedValuesAndPath() throws {
        let workspace = try makeGooseElectronFallbackWorkspace()
        let oversizedValue = String(
            repeating: "e",
            count: GooseElectronFallbackLauncher.maxSubprocessEnvironmentValueCharacters + 1
        )
        let env = GooseElectronFallbackLauncher.processEnvironment(
            workspace: workspace,
            base: [
                "PATH": oversizedValue,
                "HOME": oversizedValue,
                "LANG": oversizedValue,
                "USER": "bad\0actor",
                "SHELL": "/bin/zsh",
            ]
        )
        let path = env["PATH"] ?? ""

        #expect(path == workspace.pnpm.deletingLastPathComponent().path)
        #expect(path.count <= GooseElectronFallbackLauncher.maxSubprocessPathCharacters)
        #expect(!path.contains(oversizedValue))
        #expect(env["HOME"] == nil)
        #expect(env["LANG"] == nil)
        #expect(env["USER"] == nil)
        #expect(env["SHELL"] == "/bin/zsh")
        #expect(env["HERMIT_ENV"] == workspace.repoRoot.path)
    }

    @Test("debug port parsing rejects unsafe or malformed values")
    func debugPortParsingIsBounded() {
        #expect(
            GooseElectronFallbackLauncher.debugPortFromEnvironment([
                GooseElectronFallbackLauncher.debugPortEnvironmentKey: "9331",
            ]) == 9331
        )
        #expect(
            GooseElectronFallbackLauncher.debugPortFromEnvironment([
                GooseElectronFallbackLauncher.debugPortEnvironmentKey: "1024",
            ]) == nil
        )
        #expect(
            GooseElectronFallbackLauncher.debugPortFromEnvironment([
                GooseElectronFallbackLauncher.debugPortEnvironmentKey: "not-a-port",
            ]) == nil
        )
        #expect(
            GooseElectronFallbackLauncher.debugPortFromEnvironment([
                GooseElectronFallbackLauncher.debugPortEnvironmentKey: String(
                    repeating: "9",
                    count: GooseElectronFallbackLauncher.maxSubprocessEnvironmentValueCharacters + 1
                ),
            ]) == nil
        )
    }

    @Test("Pro menu wires the real Goose Electron fallback through the launcher")
    func menuWiresElectronFallbackLauncher() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let launcher = try loadRepoTextFile("Epistemos/Goose/GooseElectronFallbackLauncher.swift")

        #expect(app.contains("Open Real Goose Electron Fallback"))
        #expect(app.contains("GooseElectronFallbackLauncher.shared.launchFromMenu()"))
        #expect(launcher.contains("proc.standardInput = inputPipe"))
        #expect(launcher.contains("closeInputPipe()"))
        #expect(launcher.contains("cleanup.track(proc)"))
        #expect(launcher.contains("cleanup.cleanupProcessTree(rootPID: pid)"))
    }
}
#endif

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("EpistemosGooseTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private enum GooseSurfaceTestError: Error {
    case serverDidNotStart
}

private func startGooseSurfaceTestServer(_ server: WorkSPAServer) async throws -> URL {
    try server.start()
    for _ in 0..<100 {
        if case .running(let baseURL) = server.status {
            return baseURL
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    throw GooseSurfaceTestError.serverDidNotStart
}

#if !EPISTEMOS_APP_STORE
private func makeGooseElectronFallbackWorkspace() throws -> GooseElectronFallbackWorkspace {
    let repoRoot = try temporaryDirectory()
        .appendingPathComponent("goose", isDirectory: true)
    let uiRoot = repoRoot.appendingPathComponent("ui", isDirectory: true)
    let binRoot = repoRoot.appendingPathComponent("bin", isDirectory: true)
    let pnpm = binRoot.appendingPathComponent("pnpm")
    try FileManager.default.createDirectory(
        at: uiRoot.appendingPathComponent("desktop", isDirectory: true),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: binRoot, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: uiRoot.appendingPathComponent("package.json").path, contents: Data("{}".utf8))
    FileManager.default.createFile(
        atPath: uiRoot.appendingPathComponent("desktop/package.json").path,
        contents: Data("{}".utf8)
    )
    FileManager.default.createFile(atPath: pnpm.path, contents: Data("#!/bin/sh\n".utf8))
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pnpm.path)
    return GooseElectronFallbackWorkspace(repoRoot: repoRoot, uiRoot: uiRoot, pnpm: pnpm)
}
#endif

private let gooseACPWebUIBridgeFixtureSource = """
providersList_unstable
providersCatalogList_unstable
providersSetupCatalogList_unstable
providersCatalogTemplate_unstable
shared-getAcpClient-provider-inventory
local-acp-config-GOOSE_TELEMETRY_ENABLED
__epistemosGooseACPRequestSerialization
__epistemosGooseProviderInventoryEvents
__epistemosGooseProviderCatalogEvents
provider-catalog-template-choice
"""

private func writeGooseACPWebUIArtifact(at indexURL: URL) throws {
    let assets = indexURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try """
    <!doctype html>
    <script type="module" src="./assets/index-live.js"></script>
    """.write(to: indexURL, atomically: true, encoding: .utf8)
    try gooseACPWebUIBridgeFixtureSource.write(
        to: assets.appendingPathComponent("index-live.js"),
        atomically: true,
        encoding: .utf8
    )
    try writeGooseACPWebUIManifest(nextTo: indexURL)
}

private func writeGooseACPWebUIManifest(nextTo indexURL: URL) throws {
    let manifest = indexURL.deletingLastPathComponent()
        .appendingPathComponent(GooseWebUIResolver.artifactManifestFileName)
    try """
    {"schemaVersion":1,"source":"test","acpMode":true}
    """.write(to: manifest, atomically: true, encoding: .utf8)
}

private func createSparseFile(_ url: URL, size: Int) throws {
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: UInt64(size))
    try handle.close()
}

private func loadRepoTextFile(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

@MainActor
private func waitUntilSupervisorStatus(_ condition: @escaping @MainActor () -> Bool) async throws {
    // Up to ~5s: covers the supervisor's portReleaseGrace window (2s) before it
    // declares a still-answering port occupied, plus margin.
    for _ in 0..<250 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    Issue.record("supervisor status was not satisfied")
}
