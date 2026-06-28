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
            BrowserUseSecretBinding.openAIAPIKey.keychainKey: "sk-runtime",
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
        #expect(plan.environment["OPENAI_API_KEY"] == "sk-runtime")
        #expect(plan.environment["PATH"] == "/usr/bin")
        #expect(plan.environmentFileContents.contains("OPENAI_API_KEY=sk-runtime\n"))
        #expect(!plan.environmentFileURL.path.contains("agent_core/vendor/browser-use"))
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

    @Test("runtime supervisor source keeps subprocess launch out of MAS branch and browser boundary")
    func runtimeSupervisorSourceKeepsSubprocessLaunchOutOfMASBranchAndBrowserBoundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift")

        for required in [
            "BrowserUseRuntimeSupervisor",
            "BrowserUseRuntimePaths",
            "BrowserUseRuntimeLaunchPlan",
            "BrowserUseEnvironmentFileWriter",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)",
            """
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            throw BrowserUseRuntimeSupervisorError.appStoreBuild
            #else
            let runtime = Process()
            """,
            "runtime.executableURL = plan.pythonExecutableURL",
            "web-ui entrypoint",
            "Playwright Chromium payload",
            "BrowserUseEnvironmentRenderer.dictionary",
        ] {
            #expect(source.contains(required), "Missing runtime supervisor contract string: \(required)")
        }

        for forbidden in [
            "NSWorkspace",
            "URLSession",
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

        try Data("#!/usr/bin/env python3\n".utf8).write(
            to: buildRoot
                .appendingPathComponent(".venv/bin", isDirectory: true)
                .appendingPathComponent("python", isDirectory: false)
        )
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
