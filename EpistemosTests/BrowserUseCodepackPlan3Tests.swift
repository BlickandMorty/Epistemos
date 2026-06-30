import Foundation
import Testing

@Suite("Plan 3 browser-use codepack")
struct BrowserUseCodepackPlan3Tests {
    @Test("capability doc reflects landed browser-use vendor state")
    func capabilityDocReflectsLandedBrowserUseVendorState() throws {
        let plan = Self.normalizedWhitespace(try Self.loadSource("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md"))
        let codepack = Self.normalizedWhitespace(
            try Self.loadSource("docs/research/PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md")
        )

        #expect(plan.contains("browser-use vendor codepack and staged"))
        #expect(plan.contains("final signed Pro packaging still remaining"))
        #expect(plan.contains("task-submit dry-run UI smokes have landed"))
        #expect(plan.contains("vendor codepack, settings contract, staged payload, runtime shell, and adapter lane have landed"))
        #expect(codepack.contains("staged Pro code"))
        #expect(codepack.contains("This records the landed Pro-only vendor/runtime staging lane"))
        #expect(codepack.contains("Loopback server smoke harness landed at `scripts/browser-use-pro-loopback-smoke.sh`"))
        #expect(codepack.contains("A local WKWebView fixture dry-run shell smoke also landed"))
        #expect(codepack.contains("A real Gradio WKWebView shell/control smoke also landed"))
        #expect(codepack.contains("A full real Gradio WKWebView task-submit smoke also landed"))
        #expect(codepack.contains("EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT"))
        #expect(codepack.contains("Still pending: signing/notarization into final Pro resources"))
        #expect(!codepack.contains("Still pending: signing/notarization into final Pro resources and full real Gradio WKWebView task-submit smoke"))
        #expect(!codepack.contains("Still pending: signing/notarization into final Pro resources and live browser tool smoke"))
        #expect(codepack.contains("web_ui_runtime_compatibility"))
        #expect(codepack.contains("upstream browser-use source pin and file count remain separately auditable"))
        #expect(!plan.contains("browser-use vendor = the owed Pro codepack"))
        #expect(!plan.contains("Needs a vendor codepack (owed)"))
        #expect(!plan.contains("Needs a landed vendor codepack/settings/payload/adapter lane"))
        #expect(!codepack.contains("clone-ready"))
        #expect(!codepack.contains("[INFERRED]"))
        #expect(!codepack.contains("This is the owed Pro-only vendor plan"))
    }

    @Test("browser-use vendor plan is pinned, full-clone, and Pro-only")
    func browserUseCodepackIsPinnedAndGated() throws {
        let codepack = Self.normalizedWhitespace(
            try Self.loadSource("docs/research/PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md")
        )

        #expect(codepack.contains("https://github.com/browser-use/browser-use.git"))
        #expect(codepack.contains("2454d3e2551705232333c906ded8fc31ab0fc9f2"))
        #expect(codepack.contains("https://github.com/browser-use/web-ui.git"))
        #expect(codepack.contains("61962296c38a0d064e0ba02c827192b7a81d1819"))
        #expect(codepack.contains("https://github.com/browser-use/cdp-use.git"))
        #expect(codepack.contains("a318684daab5ab3a9a516fcab447ed4bdfb92be9"))
        #expect(codepack.contains("full_clone: true"))
        #expect(codepack.contains("requires-python = \">=3.11,<4.0\""))
        #expect(codepack.contains("browser-use==0.1.48"))
        #expect(codepack.contains("override that to the vendored `browser-use` source"))
        #expect(codepack.contains("Current local vendor state"))
        #expect(codepack.contains("VENDOR_MANIFEST.json"))
        #expect(codepack.contains("requirements.in"))
        #expect(codepack.contains("build-pro-payload.sh"))
        #expect(codepack.contains("epistemos_agent_browser.py"))
        #expect(codepack.contains("Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift"))
        #expect(codepack.contains("Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift"))
        #expect(codepack.contains("Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift"))
        #expect(codepack.contains("Epistemos/BrowserUsePro/BrowserUseSymlinkPathGuard.swift"))
        #expect(codepack.contains("Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift"))
        #expect(codepack.contains("EpistemosTests/BrowserUseSettingsStoreTests.swift"))
        #expect(codepack.contains("EpistemosTests/BrowserUseRuntimeSupervisorTests.swift"))
        #expect(codepack.contains("EpistemosTests/BrowserUseWebUIViewTests.swift"))
        #expect(codepack.contains("EPISTEMOS_BROWSER_USE_PRO_V0"))
        #expect(codepack.contains("BrowserUseSettingsView.swift"))
        #expect(codepack.contains("Gate, diagnostic Settings surface"))
        #expect(codepack.contains("settings/env contract landed"))
        #expect(codepack.contains("Settings JSON reads require a regular file"))
        #expect(codepack.contains("Runtime launch contract and WKWebView loopback shell landed"))
        #expect(codepack.contains("WKWebView loopback shell landed"))
        #expect(codepack.contains("Runtime path discovery prefers a signed bundled `BrowserUsePro/` resource payload"))
        #expect(codepack.contains("verifies bundled `BrowserUsePro/` resources are preferred over source-checkout discovery"))
        #expect(codepack.contains("inherits only a small POSIX environment allowlist"))
        #expect(codepack.contains("verifies ambient process secrets/injection variables are not inherited"))
        #expect(codepack.contains("sets `PYTHON_DOTENV_DISABLED=true`"))
        #expect(codepack.contains("does not re-interpolate Keychain-rendered values"))
        #expect(codepack.contains("Rust browser bridge also sets `PYTHON_DOTENV_DISABLED=true`"))
        #expect(codepack.contains("Non-empty JSON output is accepted as success only when it carries `success: true`"))
        #expect(codepack.contains("agent_core/src/tools/browser_command.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_executable.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_input.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_private.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_redaction.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_schema.rs"))
        #expect(codepack.contains("agent_core/src/tools/browser_screenshot.rs"))
        #expect(codepack.contains("credential-assignment redaction for token/api-key/password/secret variants, split credential assignments, and split/compact auth-scheme follower tokens"))
        #expect(codepack.contains("Rust rejects pre-existing symlink paths and non-current-user ownership for those private browser directories"))
        #expect(codepack.contains("non-current-user ownership for those private browser directories"))
        #expect(codepack.contains("owner-only browser daemon/socket/screenshot directories"))
        #expect(codepack.contains("owner-only session/screenshot directories"))
        #expect(codepack.contains("AGENT_BROWSER_SOCKET_DIR` overrides any ambient `BROWSER_USE_HOME` after validating"))
        #expect(codepack.contains("session names are capped at 64 safe characters"))
        #expect(codepack.contains("adapter argument errors remain generic and JSON-bounded before runtime import"))
        #expect(codepack.contains("adapter receives `AGENT_BROWSER_SCREENSHOT_DIR`"))
        #expect(codepack.contains("rejects requested or returned screenshot paths that resolve outside"))
        #expect(codepack.contains("screenshot size metadata is normalized to numeric width/height only"))
        #expect(codepack.contains("rejects multiple screenshot output paths before runtime import"))
        #expect(codepack.contains("command-specific argument validation runs before browser-use daemon startup"))
        #expect(codepack.contains("Rust bounds refs to short safe tokens before adapter execution"))
        #expect(codepack.contains("unexpected console/error flags are rejected before daemon startup without echoing rejected values"))
        #expect(codepack.contains("console/errors compatibility stubs avoid browser-use runtime import"))
        #expect(codepack.contains("Command arguments after `--json <command>` are preserved even when they begin with `--`"))
        #expect(codepack.contains("Runtime environment setup happens only after adapter arguments are accepted"))
        #expect(codepack.contains("never trusts ambient `BROWSER_CDP_URL`"))
        #expect(codepack.contains("EPISTEMOS_BROWSER_USE_CDP_URL"))
        #expect(codepack.contains("`browser_vision` also rejects screenshot paths that resolve outside"))
        #expect(codepack.contains("image `src` URLs are sanitized before the image text cap"))
        #expect(codepack.contains("redact non-HTTP(S) URL schemes"))
        #expect(codepack.contains("responses also cap nested result arrays"))
        #expect(codepack.contains("replace non-string eval keys"))
        #expect(codepack.contains("Adapter JSON error responses redact common secret assignments"))
        #expect(codepack.contains("token/api-key aliases, OAuth-style refresh/authorization codes"))
        #expect(codepack.contains("Bearer/Basic auth-scheme tokens"))
        #expect(codepack.contains("pre-bound before sanitizer regex work"))
        #expect(codepack.contains("runtime responses require `success is True`"))
        #expect(codepack.contains("preserves adapter truncation flags before returning capped refs"))
        #expect(codepack.contains("can report `browser-use Pro: packaged payload ready` only after"))
        #expect(codepack.contains("the manifest file itself is regular-file checked"))
        #expect(codepack.contains("capped at 1 MiB before JSON decode"))
        #expect(codepack.contains("browser-use Pro: packaged payload incomplete"))
        #expect(codepack.contains("manifest-declared artifact paths are relative-only"))
        #expect(codepack.contains("file artifacts must be files and directory artifacts must be directories"))
        #expect(codepack.contains("artifact symlinks must resolve inside the vendor root"))
        #expect(codepack.contains("absolute or parent-relative artifact paths are"))
        #expect(codepack.contains("file-vs-directory mismatches and symlink escapes are rejected before ready"))
        #expect(codepack.contains("manifest symlinks and oversized manifest files are rejected before decode"))
        #expect(codepack.contains("symlink escapes are rejected before ready"))
        #expect(codepack.contains("unexpected external manifest read failures are mapped to bounded domain/code diagnostics"))
        #expect(codepack.contains("same bounded diagnostics helper as the gate"))
        #expect(codepack.contains("rejects non-executable Python, file/directory artifact shape mismatches"))
        #expect(codepack.contains("runtime artifact symlink escapes before launch planning"))
        #expect(codepack.contains("rejects a non-executable Python runtime and runtime artifact symlink escapes before launch planning"))
        #expect(codepack.contains("rejects final symlinks plus symlink components in parent paths"))
        #expect(codepack.contains("rejecting symlinked env directories/files and symlinked parent components"))
        #expect(codepack.contains("rejects launch `.env` paths below symlinked parent directories before secrets are written"))
        #expect(codepack.contains("loopback health probe"))
        #expect(codepack.contains("terminates the launched process if the loopback health probe fails"))
        #expect(codepack.contains("Loopback server smoke harness"))
        #expect(codepack.contains("local WKWebView fixture dry-run shell smoke also landed"))
        #expect(codepack.contains("real Gradio WKWebView shell/control smoke also landed"))
        #expect(codepack.contains("real Gradio WKWebView shell/control plus task-submit dry-run smokes landed"))
        #expect(codepack.contains("optional LangChain MCP/provider packages are no longer imported at UI module load"))
        #expect(codepack.contains("Gradio 6 `buttons=[\"copy\"]` API"))
        #expect(codepack.contains("detached worker using the injected `BrowserUseSettingsStore`"))
        #expect(codepack.contains("adapter contract landed"))
        #expect(codepack.contains("keeps console/errors compatibility stubs runtime"))
        #expect(codepack.contains("Behavior test"))
        #expect(codepack.contains("generated lock"))
        #expect(codepack.contains("wheelhouse, and Chromium payload landed"))
        #expect(codepack.contains("live browser-use fixture smoke landed"))
        #expect(codepack.contains("This is landed, but it is not a WKWebView or task-submit smoke"))
        #expect(codepack.contains("Full task-submit smoke landed"))
        #expect(codepack.contains("web_ui_dry_run_submit"))
    }

    @Test("browser-use plan preserves browser settings and MAS boundary")
    func browserUseCodepackPreservesSettingsAndBoundary() throws {
        let codepack = Self.normalizedWhitespace(
            try Self.loadSource("docs/research/PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md")
        )

        for setting in [
            "BROWSER_PATH",
            "BROWSER_USER_DATA",
            "BROWSER_DEBUGGING_HOST",
            "BROWSER_DEBUGGING_PORT",
            "KEEP_BROWSER_OPEN",
            "USE_OWN_BROWSER",
            "BROWSER_CDP",
            "DEFAULT_LLM",
            "ANONYMIZED_TELEMETRY",
            "BROWSER_USE_LOGGING_LEVEL",
            "BROWSER_USE_EXECUTABLE_PATH",
            "BROWSER_USE_USER_DATA_DIR",
            "BROWSER_USE_PROXY_URL",
            "RESOLUTION_WIDTH",
            "RESOLUTION_HEIGHT",
        ] {
            #expect(codepack.contains(setting))
        }

        #expect(codepack.contains("App Store"))
        #expect(codepack.contains("Pro / Developer ID"))
        #expect(codepack.contains("Secrets go to Keychain only"))
        #expect(codepack.contains("browser-use drives Chromium"))
        #expect(codepack.contains("does not and must not drive the native WKWebView Browser"))
        #expect(codepack.contains("WebKitBrowserEngine` still returns `NotConfigured"))
        #expect(codepack.contains("Do not edit `Epistemos/Goose/*`"))
        #expect(codepack.contains("Do not edit `Epistemos/Goose/*`, `Epistemos/Agent/*`"))
        #expect(codepack.contains("MAS builds compile without the adapter and expose no browser-use tools"))
        #expect(codepack.contains("SourceMirror"))
        #expect(codepack.contains("exclude that directory from SourceMirror"))
        #expect(codepack.contains("MAS/App Store"))
        #expect(codepack.contains("resource-copy phase"))
    }

    @Test("browser-use Settings surface is diagnostic-only and keeps the two-browser boundary")
    func browserUseSettingsSurfaceIsDiagnosticOnly() throws {
        let settings = try Self.loadSource("Epistemos/Views/Settings/BrowserUseSettingsView.swift")
        let extensions = try Self.loadSource("Epistemos/Views/Settings/ExtensionsDetailView.swift")

        for required in [
            "BrowserUseProGateStatus.status()",
            "BrowserUseProGateStatus.defaultManifestURL()",
            "BrowserUseVendorManifest.load",
            "IntegrationBrandMarkView(brand: .browserUse",
            "Settings Contract",
            "BrowserUseSettings.default",
            "BrowserUseSecretBinding.allCases.count",
            "defaults.nonSecretEnvironmentPairs.count",
            "Env renderer",
            "Keychain secrets",
            "BrowserUseDiagnostics.statusMessage(for: error",
            "Native Browser tab",
            "browser-use does not drive it",
            "Python, Playwright, Chromium, and subprocess launch remain outside the MAS path",
            "Keychain, not manifests or logs"
        ] {
            #expect(settings.contains(required), "Missing browser-use Settings boundary string: \(required)")
        }

        for forbidden in [
            "Process(",
            "NSTask",
            "NSWorkspace",
            "URLSession",
            "launch(",
            "webui.py",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView"
        ] {
            #expect(!settings.contains(forbidden), "browser-use Settings surface crossed boundary: \(forbidden)")
        }

        #expect(extensions.contains("case .browserUse:"))
        #expect(extensions.contains("BrowserUseSettingsView()"))
        #expect(!settings.contains("error.localizedDescription"))
    }

    @Test("browser-use settings contract preserves environment shape without launching runtime")
    func browserUseSettingsContractPreservesEnvironmentShape() throws {
        let store = try Self.loadSource("Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift")

        for required in [
            "nonisolated struct BrowserUseSettings",
            "BrowserUseProviderSettings",
            "BrowserUseBrowserSettings",
            "BrowserUseRuntimeSettings",
            "BrowserUseSettingsStore",
            "BrowserUseSecretBinding",
            "BrowserUseSecretStore",
            "BrowserUseEnvironmentRenderer",
            "BrowserUseSettingsValidation",
            "BrowserUseLoopbackPolicy.allowsHost",
            "browserCDPProblem",
            "proxyServerProblem",
            "allowedProxyServerSchemes",
            "static func pairs",
            "static func dictionary",
            "settings.json",
            "JSONEncoder",
            "JSONDecoder",
            "attributes[.type] as? FileAttributeType == .typeRegular",
            "browser-use settings file must be a regular file",
            "Keychain.load",
            "Keychain.save",
            "Keychain.delete",
            "DEFAULT_LLM",
            "OPENAI_ENDPOINT",
            "ANTHROPIC_ENDPOINT",
            "AZURE_OPENAI_ENDPOINT",
            "AZURE_OPENAI_API_VERSION",
            "DEEPSEEK_ENDPOINT",
            "MISTRAL_ENDPOINT",
            "OLLAMA_ENDPOINT",
            "ALIBABA_ENDPOINT",
            "MODELSCOPE_ENDPOINT",
            "MOONSHOT_ENDPOINT",
            "UNBOUND_ENDPOINT",
            "SiliconFLOW_ENDPOINT",
            "IBM_ENDPOINT",
            "GROK_ENDPOINT",
            "BROWSER_PATH",
            "BROWSER_USER_DATA",
            "BROWSER_DEBUGGING_PORT",
            "BROWSER_DEBUGGING_HOST",
            "KEEP_BROWSER_OPEN",
            "USE_OWN_BROWSER",
            "BROWSER_CDP",
            "RESOLUTION",
            "RESOLUTION_WIDTH",
            "RESOLUTION_HEIGHT",
            "BROWSER_USE_EXECUTABLE_PATH",
            "BROWSER_USE_HEADLESS",
            "BROWSER_USE_USER_DATA_DIR",
            "ANONYMIZED_TELEMETRY",
            "BROWSER_USE_LOGGING_LEVEL",
            "BROWSER_USE_DEBUG_LOG_FILE",
            "BROWSER_USE_INFO_LOG_FILE",
            "CDP_LOGGING_LEVEL",
            "BROWSER_USE_CLOUD_API_URL",
            "BROWSER_USE_CLOUD_UI_URL",
            "BROWSER_USE_CLOUD_BASE_URL",
            "BROWSER_USE_CLOUD_SYNC",
            "BROWSER_USE_VERSION_CHECK",
            "BROWSER_USE_PROXY_SERVER",
            "BROWSER_USE_PROXY_URL",
            "BROWSER_USE_NO_PROXY",
            "BROWSER_USE_API_KEY",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "GOOGLE_API_KEY",
            "AZURE_OPENAI_API_KEY",
            "DEEPSEEK_API_KEY",
            "MISTRAL_API_KEY",
            "IBM_PROJECT_ID",
            "NOVITA_API_KEY",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN",
            "BROWSER_USE_PROXY_USERNAME",
            "BROWSER_USE_PROXY_PASSWORD",
            "VNC_PASSWORD",
            "browser debugging host must be localhost",
            "browser CDP URL must point at localhost",
            "browser CDP URL must not include username or password credentials",
            "browser-use proxy server must not include username or password credentials",
        ] {
            #expect(store.contains(required), "Missing browser-use settings contract string: \(required)")
        }

        #expect(store.contains("anonymizedTelemetry: Bool = false"))
        #expect(store.contains("cloudSync: Bool = false"))
        #expect(store.contains("versionCheck: Bool = false"))
        #expect(store.contains("browser_use_pro.env."))

        for forbidden in [
            "UserDefaults",
            "@AppStorage",
            "Process(",
            "NSTask",
            "NSWorkspace",
            "URLSession",
            "launch(",
            "webui.py",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView"
        ] {
            #expect(!store.contains(forbidden), "browser-use settings contract crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use runtime supervisor is Pro-only and writes launch env outside source")
    func browserUseRuntimeSupervisorIsProOnlyAndWritesLaunchEnvOutsideSource() throws {
        let supervisor = try Self.loadSource("Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift")

        for required in [
            "BrowserUseRuntimeSupervisor",
            "BrowserUseRuntimePaths",
            "BrowserUseRuntimeLaunchPlan",
            "BrowserUseRuntimeReadiness",
            "BrowserUseEnvironmentFileWriter",
            "BrowserUseRuntimeHealthProbe",
            "BrowserUseLoopbackPolicy.loopbackURL",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)",
            "throw BrowserUseRuntimeSupervisorError.appStoreBuild",
            "let runtime = Process()",
            "runtime.executableURL = plan.pythonExecutableURL",
            "try runtime.run()",
            "private let lifecycleLock = NSLock()",
            "shouldCancel: @Sendable () -> Bool",
            "throw CancellationError()",
            "stopLocked()",
            "private static func defaultHealthProbe",
            "loopbackHealthProblem(for:",
            "BrowserUseLoopbackPolicy.allows(url:",
            "try healthProbe(plan, shouldCancel)",
            "launchedProcess.terminate()",
            "web-ui entrypoint",
            "BUILD_MANIFEST.json",
            "wheelhouse",
            "Playwright Chromium payload",
            "BrowserUseEnvironmentRenderer.dictionary",
            "BrowserUseRuntimeArtifactKind",
            "isExecutableFile(atPath:",
            "inheritedEnvironmentAllowlist",
            "inheritedRuntimeEnvironment(from:",
            ".posixPermissions: 0o700",
            ".posixPermissions: 0o600",
            "--ip",
            "--port",
            "--theme",
        ] {
            #expect(supervisor.contains(required), "Missing runtime supervisor string: \(required)")
        }

        for forbidden in [
            "NSWorkspace",
            "BrowserView(",
            "WebKitBrowserEngine",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView"
        ] {
            #expect(!supervisor.contains(forbidden), "browser-use runtime supervisor crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use Web UI shell is loopback-only and separate from native Browser")
    func browserUseWebUIShellIsLoopbackOnlyAndSeparateFromNativeBrowser() throws {
        let shell = try Self.loadSource("Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift")

        for required in [
            "BrowserUseWebUIView",
            "BrowserUseLoopbackGuard",
            "BrowserUseRuntimeSupervisor",
            "BrowserUseLoopbackWebView",
            "WKWebsiteDataStore.nonPersistent()",
            "BrowserUseLoopbackPolicy.allows",
            "self.settingsStore = settingsStore",
            "Task.detached(priority: .userInitiated)",
            "settingsStore.load()",
            "browser-use Pro settings could not be loaded",
            "readinessWorker?.cancel()",
            "supervisor.start",
            "shouldCancel: { Task.isCancelled }",
            "supervisor?.stop()",
            "startWorker?.cancel()",
            "if !readiness.isReady",
            "startRequestID = UUID()",
            "isStarting = false",
            "webView.stopLoading()",
            "navigationDelegate = nil",
            "uiDelegate = nil",
        ] {
            #expect(shell.contains(required), "Missing browser-use Web UI shell string: \(required)")
        }
        #expect(!shell.contains("loadOrDefault()"))

        for forbidden in [
            "BrowserView(",
            "BrowserURLGuard",
            "WebKitBrowserEngine",
            "ObscuraBrowserEngine",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView",
            "EpdocWebViewShared",
            "NSWorkspace",
            "NSTask",
            "URLSession",
        ] {
            #expect(!shell.contains(forbidden), "browser-use Web UI shell crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use Web UI tests cover real Gradio shell and task-submit dry-run smokes")
    func browserUseWebUITestsCoverRealGradioShellAndTaskSubmitDryRunSmokes() throws {
        let tests = try Self.loadSource("EpistemosTests/BrowserUseWebUIViewTests.swift")

        for required in [
            "BrowserUseGradioWebUISmokeProcess",
            "wkWebViewLoadsRealGradioShellControlsWithoutSubmitting",
            "wkWebViewSubmitsRealGradioDryRunTask",
            "dryRunSubmit: true",
            "EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT",
            "Epistemos browser-use WebUI dry-run task-submit complete",
            "clickGradioSubmitTask",
            "web-ui/webui.py",
            "--ip",
            "127.0.0.1",
            "--theme",
            "Ocean",
            "PLAYWRIGHT_BROWSERS_PATH",
            "PYTHON_DOTENV_DISABLED",
            "GRADIO_ANALYTICS_ENABLED",
            "Browser Use WebUI",
            "Run Agent",
            "role=\"tab\"",
            ".visually-hidden",
            "Your Task or Response",
            "Submit Task",
            "document.querySelector('#user_input textarea')",
            "http://example.com:7788/browser-use-gradio-webview-smoke",
            "http://example.com:7788/browser-use-gradio-submit-smoke",
        ] {
            #expect(tests.contains(required), "Missing browser-use Web UI real Gradio smoke string: \(required)")
        }

        for forbidden in [
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "submit_wrapper",
            "start_wrapper",
            "api_name=\\\"start_wrapper\\\"",
        ] {
            #expect(!tests.contains(forbidden), "browser-use Web UI real Gradio smoke crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use vendor root is excluded from SourceMirror source of truth")
    func browserUseVendorRootIsExcludedFromSourceMirrorSourceOfTruth() throws {
        let projectSpec = try Self.loadSource("project.yml")
        let mirroredVendorRoot = try sourceMirrorRootURL()
            .appendingPathComponent("agent_core/vendor/browser-use", isDirectory: true)

        #expect(projectSpec.contains("Bundle Test Source Mirror"))
        #expect(projectSpec.contains("copy_tree \"agent_core\""))
        #expect(projectSpec.contains("--exclude='vendor/browser-use/'"))
        #expect(
            !FileManager.default.fileExists(atPath: mirroredVendorRoot.path),
            "browser-use Pro vendor payload must stay out of SourceMirror resources"
        )
    }

    @Test("browser-use vendor manifest matches the staged full source trees")
    func browserUseVendorManifestMatchesStagedSourceTrees() throws {
        let manifestData = try Self.loadData("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")
        let manifest = try #require(
            try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        let components = try #require(manifest["components"] as? [[String: Any]])

        let expectedPins = [
            "browser-use": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
            "web-ui": "61962296c38a0d064e0ba02c827192b7a81d1819",
            "cdp-use": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
        ]
        let expectedFileCounts = [
            "browser-use": 501,
            "web-ui": 42,
            "cdp-use": 357,
        ]

        for component in components {
            let name = try #require(component["name"] as? String)
            #expect(component["repo"] as? String == "https://github.com/browser-use/\(name).git")
            #expect(component["commit"] as? String == expectedPins[name])
            #expect(component["license"] as? String == "MIT")
            #expect(component["full_clone"] as? Bool == true)
            #expect(component["file_count"] as? Int == expectedFileCounts[name])
            #expect(FileManager.default.fileExists(
                atPath: try Self.sourceURL("agent_core/vendor/browser-use/\(name)").path
            ))
        }

        let packaging = try #require(manifest["packaging_artifacts"] as? [String: Any])
        let agentBrowserAdapter = try #require(packaging["agent_browser_adapter"] as? [String: Any])
        let webUIRuntimeCompatibility = try #require(packaging["web_ui_runtime_compatibility"] as? [String: Any])
        let webUIDryRunSubmit = try #require(packaging["web_ui_dry_run_submit"] as? [String: Any])
        let buildScript = try #require(packaging["build_script"] as? [String: Any])
        let buildManifest = try #require(packaging["build_manifest"] as? [String: Any])
        let requirementsLock = try #require(packaging["requirements_lock"] as? [String: Any])
        let wheelhouse = try #require(packaging["wheelhouse"] as? [String: Any])
        let playwrightChromium = try #require(packaging["playwright_chromium"] as? [String: Any])
        #expect(agentBrowserAdapter["status"] as? String == "landed")
        #expect(agentBrowserAdapter["expected_path"] as? String == "epistemos_agent_browser.py")
        #expect(webUIRuntimeCompatibility["status"] as? String == "landed")
        let compatibilityPaths = try #require(webUIRuntimeCompatibility["expected_paths"] as? [String])
        #expect(compatibilityPaths.count == 10)
        for relativePath in compatibilityPaths {
            #expect(FileManager.default.fileExists(
                atPath: try Self.sourceURL("agent_core/vendor/browser-use/\(relativePath)").path
            ))
        }
        #expect(webUIDryRunSubmit["status"] as? String == "landed")
        #expect(
            webUIDryRunSubmit["expected_path"] as? String
                == "web-ui/src/webui/components/browser_use_agent_tab.py"
        )
        #expect(webUIDryRunSubmit["env_var"] as? String == "EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT")
        #expect(
            webUIDryRunSubmit["marker"] as? String
                == "Epistemos browser-use WebUI dry-run task-submit complete"
        )
        #expect(buildScript["status"] as? String == "landed")
        #expect(buildScript["expected_path"] as? String == "build-pro-payload.sh")
        #expect(buildManifest["status"] as? String == "generated")
        #expect(buildManifest["expected_path"] as? String == "BUILD_MANIFEST.json")
        #expect(requirementsLock["status"] as? String == "generated")
        #expect(wheelhouse["status"] as? String == "staged")
        #expect(wheelhouse["file_count"] as? Int == 177)
        #expect(playwrightChromium["status"] as? String == "staged")
        #expect(playwrightChromium["chromium_revision"] as? String == "1223")
        let adapterURL = try Self.sourceURL("agent_core/vendor/browser-use/epistemos_agent_browser.py")
        let adapterMode = try #require(
            FileManager.default.attributesOfItem(atPath: adapterURL.path)[.posixPermissions] as? NSNumber
        ).intValue
        #expect(adapterMode & 0o111 != 0)

        let generatedManifest = try Self.loadData("agent_core/vendor/browser-use/BUILD_MANIFEST.json")
        let generated = try #require(try JSONSerialization.jsonObject(with: generatedManifest) as? [String: Any])
        #expect(generated["runtime_lane"] as? String == "pro-developer-id-only")
        #expect(generated["mas_safe"] as? Bool == false)
        #expect(generated["chromium_revision"] as? String == "1223")
        #expect(generated["secrets"] as? String == "not recorded; runtime secrets must come from Keychain")

        let requirements = try Self.loadSource("agent_core/vendor/browser-use/requirements.lock")
        #expect(requirements.contains("playwright==1.60.0"))
        #expect(requirements.contains("browser-use @ file://") || requirements.contains("-e ./browser-use"))

        let vendorRoot = try Self.sourceURL("agent_core/vendor/browser-use")
        let wheelURLs = try FileManager.default.contentsOfDirectory(
            at: vendorRoot.appendingPathComponent("wheels"),
            includingPropertiesForKeys: nil
        )
        #expect(wheelURLs.filter { $0.pathExtension == "whl" }.count == 177)
        #expect(FileManager.default.fileExists(
            atPath: vendorRoot.appendingPathComponent("playwright/chromium-1223").path
        ))
    }

    @Test("browser-use Pro packaging script is deterministic, Pro-only, and non-secret")
    func browserUseProPackagingScriptIsDeterministicAndProOnly() throws {
        let script = try Self.loadSource("agent_core/vendor/browser-use/build-pro-payload.sh")
        let manifest = try Self.loadSource("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")

        for required in [
            "set -euo pipefail",
            "Plan 3 browser-use Pro packaging only",
            "Do not invoke this from MAS/App Store build phases",
            "uv venv --clear --python 3.11 --seed",
            "uv pip compile --python-version 3.11 --generate-hashes --quiet requirements.in -o requirements.lock",
            "cd \"$vendor_root\"",
            "uv pip sync --python \"$venv_python\" \"$lock_file\"",
            "rm -rf \"$wheels_dir\" \"$playwright_dir\"",
            "wheels_dir=\"$vendor_root/wheels\"",
            "--require-hashes",
            "--no-deps",
            "PLAYWRIGHT_BROWSERS_PATH=\"$playwright_dir\"",
            "-m playwright install chromium",
            "BUILD_MANIFEST.json",
            "BUILD_MANIFEST=\"$build_manifest\"",
            "json.dumps(payload, indent=2, sort_keys=True)",
            "\"wheelhouse\": \"agent_core/vendor/browser-use/wheels\"",
            "\"sdist_wheel_exceptions\": [",
            "ibm-cos-sdk==2.14.3",
            "ibm-cos-sdk-core==2.14.3",
            "ibm-cos-sdk-s3transfer==2.14.3",
            "pyperclip==1.9.0",
            "\"secrets\": \"not recorded; runtime secrets must come from Keychain\"",
        ] {
            #expect(script.contains(required), "Missing browser-use Pro packaging script string: \(required)")
        }

        for forbidden in [
            "UserDefaults",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "BrowserView",
            "xcodebuild",
            "webui.py --ip",
        ] {
            #expect(!script.contains(forbidden), "browser-use Pro packaging script crossed boundary: \(forbidden)")
        }

        #expect(manifest.contains("\"build_script\""))
        #expect(manifest.contains("\"status\": \"landed\""))
        #expect(manifest.contains("\"expected_path\": \"build-pro-payload.sh\""))
        #expect(manifest.contains("\"build_manifest\""))
        #expect(manifest.contains("\"expected_path\": \"BUILD_MANIFEST.json\""))
    }

    @Test("browser-use loopback smoke harness is bounded, loopback-only, and non-secret")
    func browserUseLoopbackSmokeHarnessIsBoundedLoopbackOnlyAndNonSecret() throws {
        let script = try Self.loadSource("scripts/browser-use-pro-loopback-smoke.sh")

        for required in [
            "Plan 3 browser-use Pro loopback smoke",
            "build/browser-use-pro/.venv/bin/python",
            "web-ui/webui.py",
            "BUILD_MANIFEST.json",
            "wheelhouse_dir",
            "playwright_dir",
            "127.0.0.1",
            "--ip 127.0.0.1",
            "--theme Ocean",
            "PLAYWRIGHT_BROWSERS_PATH",
            "PYTHON_DOTENV_DISABLED=true",
            "GRADIO_ANALYTICS_ENABLED=False",
            "BROWSER_USE_HOME",
            "result.json",
            "webui.log",
            "secrets\": \"not recorded\"",
            "curl -fsS --max-time 2",
            "timeout_seconds > 600",
            "Timeout must be an integer from 5 through 600 seconds",
            "loopback_url=\"http://127.0.0.1:$port/\"",
            "kill \"$webui_pid\"",
            "kill -9 \"$webui_pid\"",
            "it does not load the Epistemos WKWebView shell or submit an agent task",
        ] {
            #expect(script.contains(required), "Missing browser-use loopback smoke string: \(required)")
        }

        for forbidden in [
            "0.0.0.0",
            "localhost:",
            "BrowserView",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "UserDefaults",
        ] {
            #expect(!script.contains(forbidden), "browser-use loopback smoke crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use web-ui compatibility shims are manifested and import-safe")
    func browserUseWebUICompatibilityShimsAreManifestedAndImportSafe() throws {
        let browserShim = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/browser/browser.py"
        )
        let contextShim = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/browser/context.py"
        )
        let controllerService = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/controller/service.py"
        )
        let controllerViews = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/controller/views.py"
        )
        let agentViews = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/agent/views.py"
        )
        let messageUtils = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/agent/message_manager/utils.py"
        )
        let browserViews = try Self.loadSource(
            "agent_core/vendor/browser-use/browser-use/browser_use/browser/views.py"
        )
        let mcpClient = try Self.loadSource("agent_core/vendor/browser-use/web-ui/src/utils/mcp_client.py")
        let llmProvider = try Self.loadSource("agent_core/vendor/browser-use/web-ui/src/utils/llm_provider.py")
        let agentTab = try Self.loadSource(
            "agent_core/vendor/browser-use/web-ui/src/webui/components/browser_use_agent_tab.py"
        )
        let webUIManager = try Self.loadSource("agent_core/vendor/browser-use/web-ui/src/webui/webui_manager.py")

        for required in [
            "Legacy browser-use import compatibility",
            "class BrowserConfig(BrowserProfile)",
            "class Browser(BrowserSession)",
            "IN_DOCKER",
        ] {
            #expect(browserShim.contains(required), "Missing browser shim string: \(required)")
        }
        #expect(contextShim.contains("class BrowserContextConfig(BrowserProfile)"))
        #expect(contextShim.contains("class BrowserContext"))
        #expect(controllerService.contains("from browser_use.tools.service import Controller"))
        #expect(controllerViews.contains("GoToUrlAction = NavigateAction"))
        #expect(controllerViews.contains("SearchGoogleAction = SearchAction"))
        #expect(agentViews.contains("ToolCallingMethod = Literal"))
        #expect(messageUtils.contains("def is_model_without_tool_support"))
        #expect(browserViews.contains("BrowserState = BrowserStateSummary"))
        #expect(mcpClient.contains("if TYPE_CHECKING:"))
        #expect(mcpClient.contains("from langchain_mcp_adapters.client import MultiServerMCPClient"))
        #expect(llmProvider.contains("def _missing_provider_class"))
        #expect(llmProvider.contains("is not staged in the browser-use Pro payload"))
        #expect(agentTab.contains("buttons=[\"copy\"]"))
        #expect(agentTab.contains("EPISTEMOS_DRY_RUN_SUBMIT_ENV"))
        #expect(agentTab.contains("EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT"))
        #expect(agentTab.contains("Epistemos browser-use WebUI dry-run task-submit complete"))
        #expect(agentTab.contains("if _epistemos_dry_run_submit_enabled():"))
        let dryRunHook = try #require(agentTab.range(of: "if _epistemos_dry_run_submit_enabled():"))
        let llmSetup = try #require(agentTab.range(of: "main_llm = await _initialize_llm"))
        let browserSetup = try #require(agentTab.range(of: "Launching new browser instance."))
        #expect(dryRunHook.lowerBound < llmSetup.lowerBound)
        #expect(dryRunHook.lowerBound < browserSetup.lowerBound)
        #expect(!agentTab.contains("type=\"messages\""))
        #expect(!agentTab.contains("show_copy_button"))
        #expect(!webUIManager.contains("type=\"messages\""))

        for source in [
            browserShim,
            contextShim,
            controllerService,
            controllerViews,
            mcpClient,
            llmProvider,
            agentTab,
            webUIManager,
        ] {
            for forbidden in ["Epistemos/Goose", "Epistemos/Agent", "BrowserView", "HTMLWorkspace", "PDFView"] {
                #expect(!source.contains(forbidden), "browser-use web-ui compatibility crossed boundary: \(forbidden)")
            }
        }
    }

    @Test("browser-use requirements seed uses vendored paths and skips stale web-ui pin")
    func browserUseRequirementsSeedUsesVendoredPaths() throws {
        let requirements = try Self.loadSource("agent_core/vendor/browser-use/requirements.in")

        #expect(requirements.contains("-e ./browser-use"))
        #expect(requirements.contains("-e ./cdp-use"))
        #expect(requirements.contains("playwright==1.60.0"))
        #expect(requirements.contains("gradio==6.19.0"))
        #expect(requirements.contains("langchain_mcp_adapters==0.2.0"))
        #expect(requirements.contains("langgraph==0.3.34"))
        #expect(requirements.contains("Do not include web-ui/requirements.txt directly"))
        #expect(!requirements.contains("-r ./web-ui/requirements.txt"))
        #expect(!requirements.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("browser-use==0.1.48")
        })
        #expect(!requirements.contains("gradio==5.27.0"))
        #expect(!requirements.contains("langchain_mcp_adapters==0.0.9"))
    }

    @Test("browser-use vendored trees contain no nested git repositories")
    func browserUseVendoredTreesContainNoNestedGitRepositories() throws {
        let vendorRoot = try Self.sourceURL("agent_core/vendor/browser-use")
        let enumerator = try #require(FileManager.default.enumerator(at: vendorRoot, includingPropertiesForKeys: nil))

        while let url = enumerator.nextObject() as? URL {
            #expect(url.lastPathComponent != ".git")
        }
    }

    private static func loadSource(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private static func loadData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: sourceURL(relativePath))
    }

    private static func normalizedWhitespace(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func sourceURL(_ relativePath: String) throws -> URL {
        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0..<10 {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }
}
