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
        #expect(plan.environment[BrowserUseProGateStatus.flagName] == nil)
        #expect(plan.environment["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(plan.environment["PYTHONPATH"] == nil)
        #expect(plan.environmentFileContents.contains(#"OPENAI_API_KEY="sk-${HOME}-runtime""#))
        #expect(!plan.environmentFileURL.path.contains("agent_core/vendor/browser-use"))
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
    }

    @Test("readiness rejects non-executable Python payload before launch planning")
    func readinessRejectsNonExecutablePythonPayloadBeforeLaunchPlanning() throws {
        let paths = try runtimeFixture(packaged: true)
        defer { removeFixture(paths) }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: paths.pythonExecutableURL.path
        )

        let readiness = BrowserUseRuntimeSupervisor.readiness(
            paths: paths,
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil }),
            processEnvironment: [BrowserUseProGateStatus.flagName: "1"]
        )

        #expect(!readiness.isReady)
        #expect(readiness.message.contains("Python 3.11 executable is not executable"))
    }

    @Test("readiness rejects runtime artifact symlinks outside packaged roots before launch planning")
    func readinessRejectsRuntimeArtifactSymlinksOutsidePackagedRootsBeforeLaunchPlanning() throws {
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
        #expect(readiness.message.contains("Python 3.11 executable resolves outside browser-use runtime root"))
    }

    @Test("default paths prefer bundled Pro resources before source checkout layout")
    func defaultPathsPreferBundledProResourcesBeforeSourceCheckoutLayout() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-bundled-\(UUID().uuidString)", isDirectory: true)
        let resourceRoot = root.appendingPathComponent("Resources", isDirectory: true)
        let bundledRoot = resourceRoot.appendingPathComponent("BrowserUsePro", isDirectory: true)
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
        #expect(paths.webUIEntrypointURL.path.hasSuffix("BrowserUsePro/web-ui/webui.py"))
        #expect(paths.pythonExecutableURL.path.hasSuffix("BrowserUsePro/.venv/bin/python"))
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
            "inheritedEnvironmentAllowlist",
            "inheritedRuntimeEnvironment(from:",
            "resourceRootURL: URL? = Bundle.main.resourceURL",
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
            "private static func defaultHealthProbe",
            "loopbackHealthProblem(for:",
            "BrowserUseLoopbackPolicy.allows(url:",
            "try healthProbe(plan, shouldCancel)",
            "launchedProcess.terminate()",
            "stop()",
            "stopLocked()",
            "let launchedProcess = try launchProcess(plan)",
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
        let vendorRoot = root.appendingPathComponent("agent_core/vendor/browser-use", isDirectory: true)
        let buildRoot = root.appendingPathComponent("build/browser-use-pro", isDirectory: true)
        let stateRoot = root.appendingPathComponent("state", isDirectory: true)

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

        if packaged {
            try FileManager.default.createDirectory(
                at: vendorRoot.appendingPathComponent("wheels", isDirectory: true),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: vendorRoot.appendingPathComponent("playwright", isDirectory: true),
                withIntermediateDirectories: true
            )
            try Data("{\"schema_version\":1}\n".utf8).write(
                to: vendorRoot.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false)
            )
            try Data("# generated test lock\n".utf8).write(
                to: vendorRoot.appendingPathComponent("requirements.lock", isDirectory: false)
            )
        }

        try Data(vendorManifestJSON(packaged: packaged).utf8).write(
            to: vendorRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        return BrowserUseRuntimePaths(vendorRoot: vendorRoot, buildRoot: buildRoot, stateRoot: stateRoot)
    }

    private func vendorManifestJSON(packaged: Bool) -> String {
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
              "full_clone": true,
              "file_count": 501
            },
            {
              "name": "web-ui",
              "repo": "https://github.com/browser-use/web-ui.git",
              "commit": "61962296c38a0d064e0ba02c827192b7a81d1819",
              "license": "MIT",
              "full_clone": true,
              "file_count": 42
            },
            {
              "name": "cdp-use",
              "repo": "https://github.com/browser-use/cdp-use.git",
              "commit": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
              "license": "MIT",
              "full_clone": true,
              "file_count": 357
            }
          ],
          "packaging_artifacts": {
            "requirements_lock": {
              "status": "\(requirementsStatus)",
              "expected_path": "requirements.lock"
            },
            "wheelhouse": {
              "status": "\(wheelhouseStatus)",
              "expected_path": "wheels/"
            },
            "playwright_chromium": {
              "status": "\(chromiumStatus)",
              "expected_path": "playwright/"
            }
          }
        }
        """
    }

    private func mode(for url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        return mode.intValue
    }

    private func removeFixture(_ paths: BrowserUseRuntimePaths) {
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
