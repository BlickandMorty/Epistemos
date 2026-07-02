import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 browser-use runtime supervisor")
struct BrowserUseRuntimeSupervisorTests {
    @Test("readiness stays unavailable until the packaged Pro payload is staged")
    func readinessStaysUnavailableUntilPackagedPayloadIsStaged() throws {
        let paths = try runtimeFixture(packaged: false)
        defer { removeFixture(paths) }

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("payload not packaged"))
    }

    @Test("ready launch plan preserves web-ui entrypoint, loopback, settings, and Keychain secrets")
    func readyLaunchPlanPreservesWebUIEntrypointLoopbackSettingsAndSecrets() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        let secrets = [
            BrowserUseSecretBinding.openAIAPIKey.keychainKey: "sk-${HOME}-runtime",
        ]
        var settings = BrowserUseSettings.default
        settings.providers.defaultLLM = "anthropic"
        settings.browser.debuggingPort = 9333
        settings.runtime.proxyServer = "http://proxy.example.com:8080"

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: settings,
            secretStore: BrowserUseSecretStore(loadValue: { secrets[$0] }),
            processEnvironment: [
                BrowserUseProGateStatus.flagName: "1",
                "PATH": "/usr/bin",
                "OPENAI_API_KEY": "ambient-should-not-leak",
                "DYLD_INSERT_LIBRARIES": "/tmp/injected.dylib",
                "PYTHONPATH": "/tmp/python-inject",
                "PLAYWRIGHT_BROWSERS_PATH": "/tmp/ambient-playwright",
                "GRADIO_ANALYTICS_ENABLED": "True",
                "EPISTEMOS_BROWSER_USE_ENV_FILE": "/tmp/ambient.env",
            ],
            host: "127.0.0.1",
            port: 7878,
            theme: "Ocean"
        )

        guard case .ready(let plan) = readiness else {
            Issue.record("Expected ready runtime plan, got \(readiness.message)")
            return
        }

        #expect(plan.pythonExecutableURL.path.hasSuffix(".venv/bin/python"))
        #expect(plan.webUIEntrypointURL.path.hasSuffix("web-ui/webui.py"))
        #expect(plan.workingDirectoryURL == paths.stateRoot)
        #expect(plan.environmentFileURL == paths.environmentFileURL)
        #expect(plan.loopbackURL.absoluteString == "http://127.0.0.1:7878/")
        #expect(readiness.message == "browser-use Pro runtime ready at http://127.0.0.1:7878")
        #expect(plan.arguments == [
            paths.webUIEntrypointURL.path,
            "--ip", "127.0.0.1",
            "--port", "7878",
            "--theme", "Ocean",
        ])
        #expect(plan.environment["DEFAULT_LLM"] == "anthropic")
        #expect(plan.environment["BROWSER_DEBUGGING_PORT"] == "9333")
        #expect(plan.environment["BROWSER_USE_PROXY_URL"] == "http://proxy.example.com:8080")
        #expect(plan.environment["OPENAI_API_KEY"] == "sk-${HOME}-runtime")
        #expect(plan.environment["PATH"] == "/usr/bin")
        #expect(plan.environment["PYTHON_DOTENV_DISABLED"] == "true")
        #expect(plan.environment["PYTHONDONTWRITEBYTECODE"] == "1")
        #expect(plan.environment["PLAYWRIGHT_BROWSERS_PATH"] == paths.playwrightURL.path)
        #expect(plan.environment["GRADIO_ANALYTICS_ENABLED"] == "False")
        #expect(plan.environment["BROWSER_USE_SETUP_LOGGING"] == "false")
        #expect(plan.environment["EPISTEMOS_BROWSER_USE_ENV_FILE"] == paths.environmentFileURL.path)
        #expect(plan.environment[BrowserUseProGateStatus.flagName] == nil)
        #expect(plan.environment["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(plan.environment["PYTHONPATH"] == nil)
        #expect(plan.environmentFileContents.contains(#"OPENAI_API_KEY="sk-${HOME}-runtime""#))
        #expect(!plan.environmentFileURL.path.contains("agent_core/vendor/browser-use"))
    }

    @Test("ready launch plan snapshots Keychain secrets once")
    func readyLaunchPlanSnapshotsKeychainSecretsOnce() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        let secrets = RotatingBrowserUseSecretHarness()

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { secrets.load($0) }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: "127.0.0.1",
            port: 7878
        )

        guard case .ready(let plan) = readiness else {
            Issue.record("Expected ready runtime plan, got \(readiness.message)")
            return
        }

        #expect(plan.environment["OPENAI_API_KEY"] == "sk-rotating-1")
        #expect(plan.environmentFileContents.contains("OPENAI_API_KEY=sk-rotating-1\n"))
        #expect(!plan.environmentFileContents.contains("sk-rotating-2"))
        #expect(secrets.openAILoadCount == 1)
    }

    @Test("ready launch plan bounds inherited allowlist environment values")
    func readyLaunchPlanBoundsInheritedAllowlistEnvironmentValues() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [
                BrowserUseProGateStatus.flagName: "1",
                "HOME": "/Users/me",
                "PATH": String(repeating: "x", count: 4097),
                "LANG": "en_US\nINJECTED=1",
            ],
            host: "127.0.0.1",
            port: 7878
        )

        guard case .ready(let plan) = readiness else {
            Issue.record("Expected ready runtime plan, got \(readiness.message)")
            return
        }

        #expect(plan.environment["HOME"] == "/Users/me")
        #expect(plan.environment["PATH"] == nil)
        #expect(plan.environment["LANG"] == nil)
    }

    @Test("readiness rejects non-loopback hosts before launch planning")
    func readinessRejectsNonLoopbackHostsBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        for host in ["example.com", "127.0.0.1.evil.test", "0.0.0.0", ""] {
            let readiness = BrowserUseRuntimeSupervisor.readiness(
                paths: paths,
                settings: .default,
                secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
                processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
                host: host,
                port: 7878
            )

            #expect(!readiness.isReady)
            #expect(readiness.message.contains("invalid loopback address"))
        }

        let secretBearingHost = "https://user:pass@example.com/private/path?token=secret#frag"
        let secretReadiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: secretBearingHost,
            port: 7878
        )
        #expect(!secretReadiness.isReady)
        #expect(secretReadiness.message.contains("invalid loopback address"))
        #expect(secretReadiness.message.count <= 180)
        #expect(secretReadiness.message.contains("https://example.com"))
        #expect(!secretReadiness.message.contains("user"))
        #expect(!secretReadiness.message.contains("pass"))
        #expect(!secretReadiness.message.contains("private"))
        #expect(!secretReadiness.message.contains("token"))
        #expect(!secretReadiness.message.contains("secret"))
        #expect(!secretReadiness.message.contains("frag"))
    }

    @Test("ready launch plan uses normalized loopback host argument")
    func readyLaunchPlanUsesNormalizedLoopbackHostArgument() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        let localhost = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: " LOCALHOST ",
            port: 7878
        )
        guard case .ready(let localhostPlan) = localhost else {
            Issue.record("Expected ready localhost runtime plan, got \(localhost.message)")
            return
        }
        #expect(localhostPlan.loopbackURL.absoluteString == "http://localhost:7878/")
        #expect(localhostPlan.arguments == [
            paths.webUIEntrypointURL.path,
            "--ip", "localhost",
            "--port", "7878",
            "--theme", "Ocean",
        ])

        let ipv6 = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: " [::1] ",
            port: 7878
        )
        guard case .ready(let ipv6Plan) = ipv6 else {
            Issue.record("Expected ready IPv6 loopback runtime plan, got \(ipv6.message)")
            return
        }
        #expect(ipv6Plan.loopbackURL.absoluteString == "http://[::1]:7878/")
        #expect(ipv6Plan.arguments == [
            paths.webUIEntrypointURL.path,
            "--ip", "::1",
            "--port", "7878",
            "--theme", "Ocean",
        ])
    }

    @Test("readiness rejects malformed Web UI themes before launch planning")
    func readinessRejectsMalformedWebUIThemesBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        for theme in ["", "Ocean\n--server-name=0.0.0.0", String(repeating: "a", count: 65)] {
            let readiness = BrowserUseRuntimeSupervisor.readiness(
                paths: paths,
                settings: .default,
                secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
                processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
                host: "127.0.0.1",
                port: 7878,
                theme: theme
            )

            #expect(!readiness.isReady)
            #expect(readiness.message.contains("invalid Web UI theme"))
        }

        let trimmed = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: "127.0.0.1",
            port: 7878,
            theme: "  gradio/ocean  "
        )
        guard case .ready(let plan) = trimmed else {
            Issue.record("Expected trimmed browser-use theme to produce a launch plan")
            return
        }
        #expect(Array(plan.arguments.suffix(2)) == ["--theme", "gradio/ocean"])
    }

    @Test("readiness rejects malformed browser settings before launch planning")
    func readinessRejectsMalformedBrowserSettingsBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        var settings = BrowserUseSettings.default
        settings.browser.debuggingPort = 70_000

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: settings,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: "127.0.0.1",
            port: 7878
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("settings invalid"))
        #expect(readiness.message.contains("debugging port"))
    }

    @Test("readiness rejects secret-bearing provider and cloud endpoint URLs before launch planning")
    func readinessRejectsSecretBearingEndpointURLsBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        var providerSettings = BrowserUseSettings.default
        providerSettings.providers.openAIEndpoint = "https://user:pass@example.com/v1"
        let providerReadiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: providerSettings,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: "127.0.0.1",
            port: 7878
        )
        #expect(!providerReadiness.isReady)
        #expect(providerReadiness.message.contains("settings invalid"))
        #expect(providerReadiness.message.contains("OPENAI_ENDPOINT"))
        #expect(providerReadiness.message.contains("username or password credentials"))

        var cloudSettings = BrowserUseSettings.default
        cloudSettings.runtime.cloudAPIURL = "https://api.example.com/v1?token=secret"
        let cloudReadiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: cloudSettings,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
            host: "127.0.0.1",
            port: 7878
        )
        #expect(!cloudReadiness.isReady)
        #expect(cloudReadiness.message.contains("settings invalid"))
        #expect(cloudReadiness.message.contains("BROWSER_USE_CLOUD_API_URL"))
        #expect(cloudReadiness.message.contains("URL query"))
        #expect(!cloudReadiness.message.contains("secret"))
    }

    @Test("readiness rejects non-executable Python payload before launch planning")
    func readinessRejectsNonExecutablePythonPayloadBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: paths.pythonExecutableURL.path
        )
        try refreshSignedRuntimeFixtureSignature(paths)

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("Python 3.11 executable is not executable"))
    }

    @Test("readiness rejects signed payload symlink escapes before launch planning")
    func readinessRejectsSignedPayloadSymlinkEscapesBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        let outsidePython = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-outside-python-\(UUID().uuidString)", isDirectory: false)
        defer {
            removeFixture(paths)
            try? FileManager.default.removeItem(at: outsidePython)
        }

        try Data("#!/usr/bin/env python3\n".utf8).write(to: outsidePython)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outsidePython.path)
        try FileManager.default.removeItem(at: paths.pythonExecutableURL)
        try FileManager.default.createSymbolicLink(at: paths.pythonExecutableURL, withDestinationURL: outsidePython)

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("signed package invalid"))
        #expect(readiness.message.contains("signature payload symlink resolves outside package"))
        #expect(readiness.message.contains(".venv/bin/python"))
        #expect(!readiness.message.contains(outsidePython.path))
        #expect(!readiness.message.contains(paths.buildRoot.path))
    }

    @Test("runtime artifact diagnostics use bounded relative paths")
    func runtimeArtifactDiagnosticsUseBoundedRelativePaths() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        try FileManager.default.removeItem(at: paths.webUIEntrypointURL)
        try refreshSignedRuntimeFixtureSignature(paths)

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("missing web-ui entrypoint at web-ui/webui.py"))
        #expect(!readiness.message.contains(paths.vendorRoot.path))
    }

    @Test("readiness rechecks runtime-critical web-ui shims even when manifest narrows its list")
    func readinessRechecksRuntimeCriticalWebUIShims() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        let missingRelativePath = "browser-use/browser_use/browser/chrome.py"
        try FileManager.default.removeItem(
            at: paths.vendorRoot.appendingPathComponent(missingRelativePath, isDirectory: false)
        )
        let narrowedManifest = vendorManifestJSON(packaged: true).replacingOccurrences(
            of: "\"\(missingRelativePath)\",\n",
            with: ""
        )
        try Data(narrowedManifest.utf8).write(to: paths.vendorManifestURL)
        try refreshSignedRuntimeFixtureSignature(paths)

        let gate = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: paths.vendorManifestURL
        )
        #expect(gate.isActive, "Fixture manifest intentionally omits the missing shim so only runtime readiness catches it")

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("missing web-ui compatibility shim at \(missingRelativePath)"))
        #expect(!readiness.message.contains(paths.vendorRoot.path))
    }

    @Test("default paths prefer signed bundled Pro resources before source checkout layout")
    func defaultPathsPreferSignedBundledProResourcesBeforeSourceCheckoutLayout() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-bundled-\(UUID().uuidString)", isDirectory: true)
        let resourceRoot = root.appendingPathComponent("Resources", isDirectory: true)
        let signedBundleURL = resourceRoot.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
        let bundledRoot = signedBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: bundledRoot, withIntermediateDirectories: true)
        try Data(vendorManifestJSON(packaged: true).utf8).write(
            to: bundledRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        let paths = try #require(BrowserUseRuntimePaths.defaultPaths(
            filePath: root.appendingPathComponent("NoSourceLayout.swift").path,
            resourceRootURL: resourceRoot
        ))

        #expect(paths.vendorRoot == bundledRoot)
        #expect(paths.buildRoot == bundledRoot)
        #expect(paths.signedBundleURL == signedBundleURL)
        #expect(paths.webUIEntrypointURL.path.hasSuffix("BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/web-ui/webui.py"))
        #expect(paths.pythonExecutableURL.path.hasSuffix("BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/.venv/bin/python"))
    }

    @Test("default paths reject raw bundled Pro resources outside signed bundle")
    func defaultPathsRejectRawBundledProResourcesOutsideSignedBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-raw-bundled-\(UUID().uuidString)", isDirectory: true)
        let resourceRoot = root.appendingPathComponent("Resources", isDirectory: true)
        let bundledRoot = resourceRoot.appendingPathComponent("BrowserUsePro", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: bundledRoot, withIntermediateDirectories: true)
        try Data(vendorManifestJSON(packaged: true).utf8).write(
            to: bundledRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        let paths = BrowserUseRuntimePaths.defaultPaths(
            filePath: root.appendingPathComponent("NoSourceLayout.swift").path,
            resourceRootURL: resourceRoot
        )

        #expect(paths == nil)
    }

    @Test("environment file writer stores launch-time env outside source with owner-only permissions")
    func environmentFileWriterStoresLaunchTimeEnvOutsideSourceWithOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-env-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent(".env", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        try BrowserUseEnvironmentFileWriter.write("OPENAI_API_KEY=sk-test\n", to: url)

        let contents = try String(contentsOf: url, encoding: .utf8)
        let directoryMode = try mode(for: directory)
        let fileMode = try mode(for: url)
        #expect(contents == "OPENAI_API_KEY=sk-test\n")
        #expect(directoryMode == 0o700)
        #expect(fileMode == 0o600)
    }

    @Test("environment file writer rejects symlinked launch env paths")
    func environmentFileWriterRejectsSymlinkedLaunchEnvPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-env-symlink-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let symlinkDirectory = root.appendingPathComponent("state-link", isDirectory: true)
        let safeDirectory = root.appendingPathComponent("safe", isDirectory: true)
        let outsideFile = root.appendingPathComponent("outside.env", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: safeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkDirectory, withDestinationURL: realDirectory)
        try Data("OPENAI_API_KEY=outside\n".utf8).write(to: outsideFile)

        do {
            try BrowserUseEnvironmentFileWriter.write(
                "OPENAI_API_KEY=sk-test\n",
                to: symlinkDirectory.appendingPathComponent(".env", isDirectory: false)
            )
            Issue.record("Expected symlinked browser-use env directory to be rejected")
        } catch let error as BrowserUseRuntimeSupervisorError {
            #expect(error.errorDescription?.contains("environment directory must not be a symlink") == true)
        }

        do {
            try BrowserUseEnvironmentFileWriter.write(
                "OPENAI_API_KEY=sk-test\n",
                to: symlinkDirectory
                    .appendingPathComponent("write-through", isDirectory: true)
                    .appendingPathComponent(".env", isDirectory: false)
            )
            Issue.record("Expected browser-use env path below symlinked parent to be rejected")
        } catch let error as BrowserUseRuntimeSupervisorError {
            #expect(error.errorDescription?.contains("environment directory path must not include symlink component") == true)
        }
        #expect(!FileManager.default.fileExists(
            atPath: realDirectory
                .appendingPathComponent("write-through", isDirectory: true)
                .appendingPathComponent(".env", isDirectory: false)
                .path
        ))

        let symlinkFile = safeDirectory.appendingPathComponent(".env", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkFile, withDestinationURL: outsideFile)
        do {
            try BrowserUseEnvironmentFileWriter.write("OPENAI_API_KEY=sk-test\n", to: symlinkFile)
            Issue.record("Expected symlinked browser-use env file to be rejected")
        } catch let error as BrowserUseRuntimeSupervisorError {
            #expect(error.errorDescription?.contains("environment file must not be a symlink") == true)
        }

        let outsideContents = try String(contentsOf: outsideFile, encoding: .utf8)
        #expect(outsideContents == "OPENAI_API_KEY=outside\n")
    }

    @Test("environment file writer rejects hardlinked launch env paths")
    func environmentFileWriterRejectsHardlinkedLaunchEnvPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-env-hardlink-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("safe", isDirectory: true)
        let outsideFile = root.appendingPathComponent("outside.env", isDirectory: false)
        let hardlinkedFile = directory.appendingPathComponent(".env", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("OPENAI_API_KEY=outside\n".utf8).write(to: outsideFile)
        guard (try? FileManager.default.linkItem(at: outsideFile, to: hardlinkedFile)) != nil else {
            return
        }

        do {
            try BrowserUseEnvironmentFileWriter.write("OPENAI_API_KEY=sk-test\n", to: hardlinkedFile)
            Issue.record("Expected hardlinked browser-use env file to be rejected before replacement")
        } catch let error as BrowserUseRuntimeSupervisorError {
            #expect(error.errorDescription?.contains("environment file has multiple hard links") == true)
        }

        BrowserUseEnvironmentFileWriter.removeIfCurrent("OPENAI_API_KEY=outside\n", at: hardlinkedFile)
        #expect(FileManager.default.fileExists(atPath: hardlinkedFile.path))
        let outsideContents = try String(contentsOf: outsideFile, encoding: .utf8)
        #expect(outsideContents == "OPENAI_API_KEY=outside\n")
    }

    @Test("start terminates the existing Pro runtime before relaunch")
    func startTerminatesExistingProRuntimeBeforeRelaunch() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        let firstProcess = FakeBrowserUseRuntimeProcess()
        let secondProcess = FakeBrowserUseRuntimeProcess()
        var pendingProcesses: [FakeBrowserUseRuntimeProcess] = [firstProcess, secondProcess]
        var launchedPlans: [BrowserUseRuntimeLaunchPlan] = []
        let supervisor = BrowserUseRuntimeSupervisor(
            paths: paths,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            launchProcess: { plan in
                launchedPlans.append(plan)
                let process = pendingProcesses.removeFirst()
                return BrowserUseRuntimeProcessHandle {
                    process.terminate()
                }
            },
            healthProbe: { _, _ in }
        )

        try supervisor.start(processEnvironment: [BrowserUseProGateStatus.flagName: "1"])
        #expect(firstProcess.terminationCount == 0)

        try supervisor.start(processEnvironment: [BrowserUseProGateStatus.flagName: "1"])
        #expect(firstProcess.terminationCount == 1)
        #expect(secondProcess.terminationCount == 0)
        #expect(launchedPlans.count == 2)

        supervisor.stop()
        #expect(secondProcess.terminationCount == 1)
        #else
        #expect(true)
        #endif
    }

    @Test("start terminates launched Pro runtime when loopback health probe fails")
    func startTerminatesLaunchedProRuntimeWhenLoopbackHealthProbeFails() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        let launchedProcess = FakeBrowserUseRuntimeProcess()
        var launchedPlans: [BrowserUseRuntimeLaunchPlan] = []
        let supervisor = BrowserUseRuntimeSupervisor(
            paths: paths,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            launchProcess: { plan in
                launchedPlans.append(plan)
                return BrowserUseRuntimeProcessHandle {
                    launchedProcess.terminate()
                }
            },
            healthProbe: { plan, _ in
                throw BrowserUseRuntimeSupervisorError.unavailable(
                    "browser-use Pro Web UI health probe failed at \(plan.loopbackURL.absoluteString): synthetic failure"
                )
            }
        )

        do {
            try supervisor.start(processEnvironment: [BrowserUseProGateStatus.flagName: "1"])
            Issue.record("Expected browser-use runtime start to fail when health probe fails")
        } catch let error as BrowserUseRuntimeSupervisorError {
            #expect(error.errorDescription?.contains("health probe failed") == true)
            #expect(error.errorDescription?.contains("synthetic failure") == true)
        } catch {
            Issue.record("Expected BrowserUseRuntimeSupervisorError, got \(error)")
        }

        #expect(launchedPlans.count == 1)
        #expect(launchedProcess.terminationCount == 1)
        supervisor.stop()
        #expect(launchedProcess.terminationCount == 1)
        #else
        #expect(true)
        #endif
    }

    @Test("loopback health rejects client and server errors")
    func loopbackHealthRejectsClientAndServerErrors() {
        for statusCode in [200, 204, 302] {
            #expect(BrowserUseRuntimeSupervisor.loopbackHTTPStatusProblem(statusCode) == nil)
        }

        for statusCode in [400, 404, 500, 503] {
            #expect(BrowserUseRuntimeSupervisor.loopbackHTTPStatusProblem(statusCode) == "HTTP \(statusCode)")
        }
    }

    @Test("loopback health refuses non-loopback redirects")
    func loopbackHealthRefusesNonLoopbackRedirects() throws {
        let loopback = try #require(URL(string: "http://127.0.0.1:7788/queue"))
        let root = try #require(URL(string: "http://127.0.0.1:7788/"))
        let differentPort = try #require(URL(string: "http://127.0.0.1:8787/"))
        let differentLoopbackHost = try #require(URL(string: "http://localhost:7788/"))
        let remote = try #require(URL(string: "https://example.com/"))
        let remoteWithSecrets = try #require(URL(string: "https://user:pass@example.com/private/path?token=secret#frag"))
        let differentPortWithSensitiveTail = try #require(URL(string: "http://127.0.0.1:8787/private/path?token=secret#frag"))
        let origin = try #require(BrowserUseLoopbackPolicy.origin(for: root))

        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(loopback) == nil)
        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(remote)?.contains("non-loopback") == true)
        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(nil)?.contains("Location URL") == true)
        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(loopback, expectedOrigin: origin) == nil)
        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(differentPort, expectedOrigin: origin)?.contains("different loopback origin") == true)
        #expect(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(differentLoopbackHost, expectedOrigin: origin)?.contains("different loopback origin") == true)

        let remoteSecretProblem = try #require(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(remoteWithSecrets))
        #expect(remoteSecretProblem.contains("https://example.com"))
        #expect(!remoteSecretProblem.contains("user"))
        #expect(!remoteSecretProblem.contains("pass"))
        #expect(!remoteSecretProblem.contains("private"))
        #expect(!remoteSecretProblem.contains("token"))
        #expect(!remoteSecretProblem.contains("secret"))
        #expect(!remoteSecretProblem.contains("frag"))
        #expect(!remoteSecretProblem.contains("@"))
        #expect(!remoteSecretProblem.contains("?"))
        #expect(!remoteSecretProblem.contains("#"))

        let differentPortSecretProblem = try #require(BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(
            differentPortWithSensitiveTail,
            expectedOrigin: origin
        ))
        #expect(differentPortSecretProblem.contains("http://127.0.0.1:8787"))
        #expect(!differentPortSecretProblem.contains("private"))
        #expect(!differentPortSecretProblem.contains("token"))
        #expect(!differentPortSecretProblem.contains("secret"))
        #expect(!differentPortSecretProblem.contains("frag"))
        #expect(!differentPortSecretProblem.contains("?"))
        #expect(!differentPortSecretProblem.contains("#"))
    }

    @Test("start honors cancellation before launching Pro runtime")
    func startHonorsCancellationBeforeLaunchingProRuntime() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }

        var launched = false
        let supervisor = BrowserUseRuntimeSupervisor(
            paths: paths,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            launchProcess: { _ in
                launched = true
                return BrowserUseRuntimeProcessHandle {}
            }
        )

        do {
            _ = try supervisor.start(
                processEnvironment: [BrowserUseProGateStatus.flagName: "1"],
                shouldCancel: { true }
            )
            Issue.record("Expected browser-use runtime start cancellation to throw")
        } catch is CancellationError {
            // Expected: cancelled before env write or subprocess launch.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }

        #expect(!launched)
        #expect(!FileManager.default.fileExists(atPath: paths.environmentFileURL.path))
        #else
        #expect(true)
        #endif
    }

    @Test("runtime supervisor source keeps subprocess launch out of MAS branch and browser boundary")
    func runtimeSupervisorSourceKeepsSubprocessLaunchOutOfMASBranchAndBrowserBoundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift")

        for required in [
            "BrowserUseRuntimeSupervisor",
            "BrowserUseRuntimePaths",
            "BrowserUseRuntimeLaunchPlan",
            "BrowserUseEnvironmentFileWriter",
            "BrowserUseRuntimeHealthProbe",
            "BrowserUseRuntimeArtifactKind",
            "BrowserUseRuntimeArtifactRequirement",
            "isExecutableFile(atPath:",
            "resolvesInsideRuntimeRoot",
            "resolves outside browser-use runtime root",
            "PYTHON_DOTENV_DISABLED",
            "PYTHONDONTWRITEBYTECODE",
            "PLAYWRIGHT_BROWSERS_PATH",
            "GRADIO_ANALYTICS_ENABLED",
            "BROWSER_USE_SETUP_LOGGING",
            "proEnvironmentFilePathEnvironmentName",
            "inheritedEnvironmentAllowlist",
            "inheritedRuntimeEnvironment(from:",
            "sanitizedInheritedEnvironmentValue",
            "maxInheritedEnvironmentValueLength",
            "maxThemeLength",
            "normalizedThemeArgument",
            "invalid Web UI theme",
            "resourceRootURL: URL? = Bundle.main.resourceURL",
            "BrowserUsePro.bundle",
            "signedBundlePayloadRoot",
            "signedBundleURL: signedBundleURL",
            "appendingPathComponent(\"BrowserUsePro\", isDirectory: true)",
            "fileManager: fileManager",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)",
            "BrowserUseLoopbackPolicy.loopbackURL",
            "private let lifecycleLock = NSLock()",
            "shouldCancel: @Sendable () -> Bool",
            "throw CancellationError()",
            "rejectEnvironmentSymlink",
            "browser-use environment \\(label) must not be a symlink",
            "private static let defaultHealthProbe",
            "private static func defaultHealthProbeImpl",
            "loopbackHealthProblem(for:",
            "BrowserUseLoopbackPolicy.allows(url:",
            "BrowserUseDiagnostics.statusMessage(for: error, fallback: \"request failed\")",
            "redactedURLDescription",
            "maxURLDiagnosticLength",
            "BrowserUseLoopbackPolicy.redactedDescription(for: plan.loopbackURL)",
            "BrowserUseLoopbackPolicy.redactedDescription(for: url, maxLength: maxURLDiagnosticLength)",
            "loopbackAddressDiagnostic(host: host, port: port)",
            "loopbackHostDiagnostic(_ host: String)",
            "cappedDiagnostic(",
            "normalizedDiagnostic(value)",
            "CharacterSet.controlCharacters",
            "maxPathDiagnosticLength",
            "private static func pathDiagnostic(_ url: URL)",
            "runtimeArtifactPathDescription",
            "fileType(at:",
            ".typeRegular",
            "is not a regular file",
            "try healthProbe(plan, shouldCancel)",
            "launchedProcess.terminate()",
            "stop()",
            "stopLocked()",
            "activeEnvironmentFileCleanup",
            "BrowserUseEnvironmentFileWriter.removeIfCurrent",
            "readEnvironmentFileNoFollow",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "S_IFREG",
            "st_nlink <= 1",
            "environment file has multiple hard links",
            "launchedProcess = try launchProcess(plan)",
            "process = launchedProcess",
            "private static func defaultLaunchProcess",
            "let runtime = Process()",
            "runtime.executableURL = plan.pythonExecutableURL",
            "web-ui entrypoint",
            "Playwright Chromium payload",
            "BrowserUseEnvironmentRenderer.dictionary",
        ] {
            #expect(source.contains(required), "Missing runtime supervisor contract string: \(required)")
        }
        #expect(!source.contains("request failed: \\(error.localizedDescription)"))
        #expect(!source.contains("plan.loopbackURL.absoluteString"))
        #expect(!source.contains("invalid loopback address \\(host):\\(port)"))

        for forbidden in [
            "NSWorkspace",
            "BrowserView(",
            "WebKitBrowserEngine",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView",
        ] {
            #expect(!source.contains(forbidden), "browser-use runtime crossed boundary: \(forbidden)")
        }
    }

    private func runtimeFixture(packaged: Bool) throws -> BrowserUseRuntimePaths {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-runtime-\(UUID().uuidString)", isDirectory: true)
        let stateRoot = root.appendingPathComponent("state", isDirectory: true)

        if packaged {
            let signedBundleURL = root.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
            let vendorRoot = signedBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
            try FileManager.default.createDirectory(at: vendorRoot, withIntermediateDirectories: true)
            try Data(runtimeInfoPlist.utf8).write(
                to: signedBundleURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("Info.plist", isDirectory: false)
            )
            try writeRuntimePayloadFixture(vendorRoot: vendorRoot, buildRoot: vendorRoot, packaged: true)
            let fileCount = try payloadFixtureFileCount(in: vendorRoot)
            try Data(signatureManifestJSON(fileCount: fileCount).utf8).write(
                to: vendorRoot.appendingPathComponent("SIGNATURE_MANIFEST.json", isDirectory: false)
            )
            try Data(packageResultJSON.utf8).write(
                to: root.appendingPathComponent("PACKAGE_RESULT.json", isDirectory: false)
            )
            try runProcess("/usr/bin/codesign", arguments: [
                "--force",
                "--sign",
                "-",
                signedBundleURL.path,
            ])
            return BrowserUseRuntimePaths(
                vendorRoot: vendorRoot,
                buildRoot: vendorRoot,
                stateRoot: stateRoot,
                signedBundleURL: signedBundleURL
            )
        }

        let vendorRoot = root.appendingPathComponent("agent_core/vendor/browser-use", isDirectory: true)
        let buildRoot = root.appendingPathComponent("build/browser-use-pro", isDirectory: true)
        try writeRuntimePayloadFixture(vendorRoot: vendorRoot, buildRoot: buildRoot, packaged: false)

        return BrowserUseRuntimePaths(vendorRoot: vendorRoot, buildRoot: buildRoot, stateRoot: stateRoot)
    }

    private func writeRuntimePayloadFixture(
        vendorRoot: URL,
        buildRoot: URL,
        packaged: Bool
    ) throws {
        try FileManager.default.createDirectory(
            at: vendorRoot.appendingPathComponent("web-ui", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: buildRoot.appendingPathComponent(".venv/bin", isDirectory: true),
            withIntermediateDirectories: true
        )

        let pythonExecutable = buildRoot
            .appendingPathComponent(".venv/bin", isDirectory: true)
            .appendingPathComponent("python", isDirectory: false)
        try Data("#!/usr/bin/env python3\n".utf8).write(to: pythonExecutable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pythonExecutable.path)
        try Data("print('webui')\n".utf8).write(
            to: vendorRoot
                .appendingPathComponent("web-ui", isDirectory: true)
                .appendingPathComponent("webui.py", isDirectory: false)
        )
        try writeExecutableFixture(vendorRoot.appendingPathComponent("epistemos_agent_browser.py", isDirectory: false))
        try Data("env\n".utf8).write(
            to: vendorRoot.appendingPathComponent("epistemos_browser_env.py", isDirectory: false)
        )
        try Data("task\n".utf8).write(
            to: vendorRoot.appendingPathComponent("epistemos_browser_task.py", isDirectory: false)
        )
        try writeExecutableFixture(vendorRoot.appendingPathComponent("build-pro-payload.sh", isDirectory: false))

        if packaged {
            try FileManager.default.createDirectory(
                at: vendorRoot.appendingPathComponent("wheels", isDirectory: true),
                withIntermediateDirectories: true
            )
            try writeWheelhouseFixtureFiles(in: vendorRoot.appendingPathComponent("wheels", isDirectory: true))
            try FileManager.default.createDirectory(
                at: vendorRoot.appendingPathComponent("playwright", isDirectory: true),
                withIntermediateDirectories: true
            )
            try writePlaywrightRevisionMarkers(in: vendorRoot.appendingPathComponent("playwright", isDirectory: true))
            try Data("{\"schema_version\":1}\n".utf8).write(
                to: vendorRoot.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false)
            )
            try Data("# generated test lock\n".utf8).write(
                to: vendorRoot.appendingPathComponent("requirements.lock", isDirectory: false)
            )
            try writeWebUICompatibilityFixtureFiles(in: vendorRoot)
        }

        try Data(vendorManifestJSON(packaged: packaged).utf8).write(
            to: vendorRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )
    }

    private func vendorManifestJSON(packaged: Bool) -> String {
        let buildScriptStatus = packaged ? "landed" : "not_landed"
        let buildManifestStatus = packaged ? "generated" : "not_generated"
        let requirementsStatus = packaged ? "generated" : "not_generated"
        let wheelhouseStatus = packaged ? "staged" : "not_staged"
        let chromiumStatus = packaged ? "staged" : "not_staged"

        return """
        {
          "schema_version": 1,
          "name": "plan3-browser-use-pro",
          "runtime_lane": "pro-developer-id-only",
          "mas_safe": false,
          "native_wkwebview_boundary": "browser-use drives bundled Chromium over CDP; it does not drive Epistemos BrowserView WKWebView",
          "source_mirror_guard": {
            "source_of_truth": "project.yml",
            "required_exclude": "--exclude='vendor/browser-use/'",
            "reason": "Python, Playwright, Chromium, and browser-use source must not be copied into MAS SourceMirror resources"
          },
          "components": [
            {
              "name": "browser-use",
              "repo": "https://github.com/browser-use/browser-use.git",
              "commit": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
              "license": "MIT",
              "package_version": "0.13.2",
              "full_clone": true,
              "file_count": 501
            },
            {
              "name": "web-ui",
              "repo": "https://github.com/browser-use/web-ui.git",
              "commit": "61962296c38a0d064e0ba02c827192b7a81d1819",
              "license": "MIT",
              "package_version": null,
              "full_clone": true,
              "file_count": 42
            },
            {
              "name": "cdp-use",
              "repo": "https://github.com/browser-use/cdp-use.git",
              "commit": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
              "license": "MIT",
              "package_version": "1.4.5",
              "full_clone": true,
              "file_count": 357
            }
          ],
          "packaging_artifacts": {
            "agent_browser_adapter": {
              "status": "\(buildScriptStatus)",
              "expected_paths": [
                "epistemos_agent_browser.py",
                "epistemos_browser_env.py",
                "epistemos_browser_task.py"
              ]
            },
            "web_ui_runtime_compatibility": {
              "status": "\(buildScriptStatus)",
              "expected_paths": [
                "browser-use/browser_use/browser/browser.py",
                "browser-use/browser_use/browser/context.py",
                "browser-use/browser_use/browser/chrome.py",
                "browser-use/browser_use/browser/utils/__init__.py",
                "browser-use/browser_use/browser/utils/screen_resolution.py",
                "browser-use/browser_use/controller/service.py",
                "browser-use/browser_use/controller/registry/__init__.py",
                "browser-use/browser_use/controller/registry/service.py",
                "browser-use/browser_use/controller/registry/views.py",
                "browser-use/browser_use/controller/views.py"
              ]
            },
            "web_ui_dry_run_submit": {
              "status": "\(buildScriptStatus)",
              "expected_path": "web-ui/src/webui/components/browser_use_agent_tab.py",
              "env_var": "EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT",
              "marker": "Epistemos browser-use WebUI dry-run task-submit complete"
            },
            "build_script": {
              "status": "\(buildScriptStatus)",
              "expected_path": "build-pro-payload.sh"
            },
            "build_manifest": {
              "status": "\(buildManifestStatus)",
              "expected_path": "BUILD_MANIFEST.json"
            },
            "requirements_lock": {
              "status": "\(requirementsStatus)",
              "expected_path": "requirements.lock"
            },
            "wheelhouse": {
              "status": "\(wheelhouseStatus)",
              "expected_path": "wheels",
              "file_count": 177
            },
            "playwright_chromium": {
              "status": "\(chromiumStatus)",
              "expected_path": "playwright",
              "chromium_revision": "1223",
              "headless_shell_revision": "1223",
              "ffmpeg_revision": "1011"
            }
          }
        }
        """
    }

    private func writeWebUICompatibilityFixtureFiles(in payloadRoot: URL) throws {
        for relativePath in [
            "browser-use/browser_use/browser/browser.py",
            "browser-use/browser_use/browser/context.py",
            "browser-use/browser_use/browser/chrome.py",
            "browser-use/browser_use/browser/utils/__init__.py",
            "browser-use/browser_use/browser/utils/screen_resolution.py",
            "browser-use/browser_use/controller/service.py",
            "browser-use/browser_use/controller/registry/__init__.py",
            "browser-use/browser_use/controller/registry/service.py",
            "browser-use/browser_use/controller/registry/views.py",
            "browser-use/browser_use/controller/views.py",
        ] {
            try writeTextFixture(relativePath, in: payloadRoot, contents: "shim\n")
        }
        try writeTextFixture(
            "web-ui/src/webui/components/browser_use_agent_tab.py",
            in: payloadRoot,
            contents: "dry run hook\n"
        )
    }

    private func writeTextFixture(_ relativePath: String, in root: URL, contents: String) throws {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }

    private func writeWheelhouseFixtureFiles(in wheelhouseURL: URL) throws {
        for index in 0..<177 {
            try Data("wheel \(index)\n".utf8).write(
                to: wheelhouseURL.appendingPathComponent("fixture-\(index).whl", isDirectory: false)
            )
        }
    }

    private func writePlaywrightRevisionMarkers(in playwrightURL: URL) throws {
        for directoryName in [
            "chromium-1223",
            "chromium_headless_shell-1223",
            "ffmpeg-1011",
        ] {
            let directoryURL = playwrightURL.appendingPathComponent(directoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try Data("ok\n".utf8).write(
                to: directoryURL.appendingPathComponent("INSTALLATION_COMPLETE", isDirectory: false)
            )
        }
    }

    private func writeExecutableFixture(_ url: URL) throws {
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func payloadFixtureFileCount(in payloadRoot: URL) throws -> Int {
        var fileCount = 0
        let enumerator = try #require(FileManager.default.enumerator(
            at: payloadRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ))
        for case let url as URL in enumerator {
            guard url.lastPathComponent != "SIGNATURE_MANIFEST.json" else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                fileCount += 1
            }
        }
        return fileCount
    }

    private func refreshSignedRuntimeFixtureSignature(_ paths: BrowserUseRuntimePaths) throws {
        guard let signedBundleURL = paths.signedBundleURL else { return }
        let signatureURL = paths.vendorRoot.appendingPathComponent("SIGNATURE_MANIFEST.json", isDirectory: false)
        try? FileManager.default.removeItem(at: signatureURL)
        let fileCount = try payloadFixtureFileCount(in: paths.vendorRoot)
        try Data(signatureManifestJSON(fileCount: fileCount).utf8).write(to: signatureURL)
        if let signedBundleURL = paths.signedBundleURL {
            let packageResultURL = signedBundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("PACKAGE_RESULT.json", isDirectory: false)
            if !FileManager.default.fileExists(atPath: packageResultURL.path) {
                try Data(packageResultJSON.utf8).write(to: packageResultURL)
            }
        }
        try runProcess("/usr/bin/codesign", arguments: [
            "--force",
            "--sign",
            "-",
            signedBundleURL.path,
        ])
    }

    private func signatureManifestJSON(fileCount: Int) -> String {
        """
        {
          "schema_version": 1,
          "package_name": "BrowserUsePro",
          "runtime_lane": "pro-developer-id-only",
          "signature_type": "ad-hoc",
          "signing_identity": "-",
          "payload_root": "Contents/Resources/BrowserUsePro",
          "file_count": \(fileCount),
          "python": "Python 3.11.15",
          "browser_use_version": "0.13.2",
          "component_repos": {
            "browser-use": "https://github.com/browser-use/browser-use.git",
            "web-ui": "https://github.com/browser-use/web-ui.git",
            "cdp-use": "https://github.com/browser-use/cdp-use.git"
          },
          "component_commits": {
            "browser-use": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
            "web-ui": "61962296c38a0d064e0ba02c827192b7a81d1819",
            "cdp-use": "a318684daab5ab3a9a516fcab447ed4bdfb92be9"
          },
          "component_versions": {
            "browser-use": "0.13.2",
            "web-ui": null,
            "cdp-use": "1.4.5"
          },
          "playwright_revisions": {
            "chromium": "1223",
            "chromium_headless_shell": "1223",
            "ffmpeg": "1011"
          },
          "created_utc": "2026-06-30T00:00:00Z",
          "codesign_contract": "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime."
        }
        """
    }

    private var packageResultJSON: String {
        """
        {
          "schema_version": 1,
          "package_name": "BrowserUsePro",
          "bundle": "BrowserUsePro.bundle",
          "signature_manifest": "BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json",
          "signature_type": "ad-hoc",
          "python": "Python 3.11.15",
          "codesign_verified": true,
          "smoke_suite_entrypoint": "scripts/browser-use-pro-smoke-suite.sh",
          "smoke_suite_args": ["--signed-bundle", "BrowserUsePro.bundle"],
          "notarization": "not recorded; release notarization remains distribution ops",
          "secrets": "not recorded",
          "created_utc": "2026-06-30T00:00:01Z"
        }
        """
    }

    private var runtimeInfoPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>com.epistemos.browserusepro.runtime-test</string>
          <key>CFBundleName</key>
          <string>BrowserUsePro</string>
          <key>CFBundlePackageType</key>
          <string>BNDL</string>
          <key>CFBundleVersion</key>
          <string>1</string>
        </dict>
        </plist>
        """
    }

    private func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "BrowserUseRuntimeSupervisorTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
    }

    private func mode(for url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        return mode.intValue
    }

    private func removeFixture(_ paths: BrowserUseRuntimePaths) {
        if let signedBundleURL = paths.signedBundleURL {
            try? FileManager.default.removeItem(at: signedBundleURL.deletingLastPathComponent())
            return
        }
        let root = paths.vendorRoot
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        try? FileManager.default.removeItem(at: root)
    }
}

private final class FakeBrowserUseRuntimeProcess {
    private(set) var terminationCount = 0

    func terminate() {
        terminationCount += 1
    }
}

private nonisolated final class RotatingBrowserUseSecretHarness: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func load(_ key: String) -> String? {
        guard key == BrowserUseSecretBinding.openAIAPIKey.keychainKey else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        count += 1
        return "sk-rotating-\(count)"
    }

    var openAILoadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
