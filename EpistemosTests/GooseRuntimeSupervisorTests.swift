import Foundation
import Testing
@testable import Epistemos

@Suite("Goose runtime supervisor")
struct GooseRuntimeSupervisorTests {
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
                "HF_TOKEN": "secret-token",
                "OPENAI_API_KEY": "secret-token",
                "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
                "NODE_OPTIONS": "--require /tmp/inject.js",
            ]
        )
        #expect(env["PATH"] == "/Runtime/goose/bin:/usr/bin")
        #expect(env["HOME"] == "/Users/jojo")
        #expect(env["LANG"] == "en_US.UTF-8")
        #expect(env["GOOSE_SERVER__SECRET_KEY"] == "secret-123")
        #expect(env["GOOSE_MODE"] == "approve")
        #expect(env["GOOSE_PROVIDER__TYPE"] == nil)
        #expect(env["OPENWORK_MANAGE_OPENCODE"] == nil)
        #expect(env["OPENCODE_SERVER_PASSWORD"] == nil)
        #expect(env["HF_TOKEN"] == nil)
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)

        let inheritedOnlyEnv = GooseRuntimeSupervisor.processEnvironment(
            binary: binary,
            secretKey: "secret-456",
            base: ["GOOSE_MODE": "approve"]
        )
        #expect(inheritedOnlyEnv["GOOSE_MODE"] == nil)
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
    }

    @Test("listening logs stay diagnostic while health gates readiness")
    func listeningLogsDoNotShortCircuitHealthReadiness() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        let forbiddenEarlyResume = #"if\s+let\s+url\s*=\s*Self\.parseListeningURL\(from:\s*line,\s*expectedPort:\s*Self\.defaultPort\)\s*\{\s*await\s+state\.resume\(url\)"#
        #expect(source.contains("if await healthCheck(defaultBaseURL)"))
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
        FileManager.default.createFile(atPath: explicit.path, contents: Data())
        try writeGooseACPWebUIManifest(nextTo: explicit)

        let resolved = GooseWebUIResolver.indexURL(
            appSupportDirectory: nil,
            currentDirectory: root.appendingPathComponent("checkout").path,
            environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path]
        )

        #expect(resolved == explicit)
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
        FileManager.default.createFile(atPath: staged.path, contents: Data())
        FileManager.default.createFile(atPath: checkout.path, contents: Data())
        try writeGooseACPWebUIManifest(nextTo: staged)
        try writeGooseACPWebUIManifest(nextTo: checkout)

        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: appSupport,
                currentDirectory: root.path,
                environment: [:]
            ) == staged
        )

        try FileManager.default.removeItem(at: staged)
        #expect(
            GooseWebUIResolver.indexURL(
                appSupportDirectory: appSupport,
                currentDirectory: root.path,
                environment: [:]
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
                environment: ["EPISTEMOS_GOOSE_UI_INDEX": explicit.path]
            ) == nil
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
        #expect(script.contains("OnboardingGuard.tsx"))
        #expect(script.contains("if (USE_ACP_CHAT)"))
        #expect(script.contains("permissionRequests.ts"))
        #expect(script.contains("requestPermission(request)"))
        #expect(script.contains("elicitationRequests.ts"))
        #expect(script.contains("requestElicitation(request)"))
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
        #expect(script.contains("getConfig: { configurable: true, value: () => epistemosGoose.config }"))
        #expect(!script.contains("getConfig: { configurable: true, value: async"))
    }

    @Test("Goose Web UI loads through the hash route used by the Electron renderer")
    func gooseWebUIBootURLUsesHashRoute() {
        let index = URL(fileURLWithPath: "/tmp/goose-web-ui/index.html")
        #expect(GooseWebSurfaceView.bootURL(for: index).absoluteString == "epistemos-goose://app/#/?")
    }

    @Test("surface keeps the Goose runtime secret stable across SwiftUI view reloads")
    func gooseSurfaceSecretLivesInState() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(source.contains("@State private var secretKey: String"))
        #expect(!source.contains("private let secretKey"))
    }

    @Test("surface coordinator does not own native ACP prompt panel implementation")
    func gooseSurfaceCoordinatorDoesNotOwnNativePromptPanels() throws {
        let surface = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        let panels = try loadRepoTextFile("Epistemos/Goose/GooseACPNativePromptPanels.swift")

        #expect(!surface.contains("struct GooseACPPermissionPanel"))
        #expect(!surface.contains("struct GooseACPElicitationPanel"))
        #expect(panels.contains("struct GooseACPPermissionPanel"))
        #expect(panels.contains("struct GooseACPElicitationPanel"))
    }

    @Test("affordance disposition ledger marks native file and URL calls as implemented")
    func dispositionLedgerCoversKnownAffordances() {
        let ledger = GooseWebBootShim.dispositionLedger
        #expect(ledger["getGoosedHostPort"] == .implementedRuntime)
        #expect(ledger["getSecretKey"] == .implementedRuntime)
        #expect(ledger["getAcpUrl"] == .implementedRuntime)
        #expect(ledger["getConfig"] == .implementedNative)
        #expect(ledger["checkForUpdates"] == .hiddenShell)
        #expect(ledger["showOpenDialog"] == .implementedNative)
        #expect(ledger["showSaveDialog"] == .implementedNative)
        #expect(ledger["directoryChooser"] == .implementedNative)
        #expect(ledger["selectFileOrDirectory"] == .implementedNative)
        #expect(ledger["selectImportSessionFile"] == .implementedNative)
        #expect(ledger["openExternal"] == .implementedNative)
        #expect(ledger["openInChrome"] == .implementedNative)
        #expect(ledger["openDirectoryInExplorer"] == .implementedNative)
        #expect(ledger["showMessageBox"] == .deferredWithVisibleError)
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
        #expect(!script.contains("visibleError('showOpenDialog')"))
        #expect(!script.contains("visibleError('showSaveDialog')"))
        #expect(!script.contains("visibleError('directoryChooser')"))
        #expect(!script.contains("visibleError('selectImportSessionFile')"))
        #expect(!script.contains("visibleError('openExternal')"))
    }

    @Test("surface registers the native affordance bridge separately from prompt replies")
    func surfaceRegistersNativeAffordanceBridge() throws {
        let source = try loadRepoTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(source.contains("@State private var nativeAffordanceBridge: GooseWebNativeAffordanceBridge"))
        #expect(source.contains("name: \"epistemosGoosePrompt\""))
        #expect(source.contains("name: \"epistemosGooseNative\""))
        #expect(source.contains("nativeAffordanceBridge: nativeAffordanceBridge"))
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
        #expect(GooseWebNativeAffordanceBridge.shouldOpenExternalURL("https://block.github.io/goose"))
        #expect(GooseWebNativeAffordanceBridge.shouldOpenExternalURL("mailto:hello@example.com"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("file:///tmp/secret"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("javascript:alert(1)"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenExternalURL("data:text/plain,hello"))
        #expect(GooseWebNativeAffordanceBridge.shouldOpenBrowserURL("https://block.github.io/goose"))
        #expect(!GooseWebNativeAffordanceBridge.shouldOpenBrowserURL("mailto:hello@example.com"))
    }

    @Test("unsupported native affordances fail closed")
    func unsupportedAffordanceFailsClosed() {
        let bridge = GooseWebNativeAffordanceBridge()
        do {
            _ = try bridge.handleAffordance(name: "readFile", args: [])
            Issue.record("readFile should stay deferred until a scoped file bridge exists")
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
        #expect(env["GOOSE_ALLOWLIST_BYPASS"] == "true")
        #expect(env["HERMIT_ENV"] == workspace.repoRoot.path)
        #expect(env["ENABLE_PLAYWRIGHT"] == "true")
        #expect(env["PLAYWRIGHT_DEBUG_PORT"] == "9330")
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["HF_TOKEN"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)
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

private func writeGooseACPWebUIManifest(nextTo indexURL: URL) throws {
    let manifest = indexURL.deletingLastPathComponent()
        .appendingPathComponent(GooseWebUIResolver.artifactManifestFileName)
    try """
    {"schemaVersion":1,"source":"test","acpMode":true}
    """.write(to: manifest, atomically: true, encoding: .utf8)
}

private func loadRepoTextFile(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

@MainActor
private func waitUntilSupervisorStatus(_ condition: @escaping @MainActor () -> Bool) async throws {
    for _ in 0..<50 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    Issue.record("supervisor status was not satisfied")
}
