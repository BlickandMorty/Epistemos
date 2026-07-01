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

        #expect(plan.contains("browser-use vendor codepack, staged payload, signed `BrowserUsePro.bundle` packaging"))
        #expect(!plan.contains("final signed Pro packaging still remaining"))
        #expect(plan.contains("task-submit dry-run UI smokes have landed"))
        #expect(plan.contains("vendor codepack, settings contract, staged payload, runtime shell, and adapter lane have landed"))
        #expect(codepack.contains("signed Pro payload"))
        #expect(codepack.contains("This records the landed Pro-only vendor/runtime staging lane"))
        #expect(codepack.contains("Loopback server smoke harness landed at `scripts/browser-use-pro-loopback-smoke.sh`"))
        #expect(codepack.contains("A local WKWebView fixture dry-run shell smoke also landed"))
        #expect(codepack.contains("A real Gradio WKWebView shell/control smoke also landed"))
        #expect(codepack.contains("A full real Gradio WKWebView task-submit smoke also landed"))
        #expect(codepack.contains("scripts/browser-use-pro-smoke-suite.sh"))
        #expect(codepack.contains("bounded Pro smoke-suite entrypoint without `xcodebuild` or the full test suite"))
        #expect(codepack.contains("EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT"))
        #expect(codepack.contains("Signed `BrowserUsePro.bundle` packaging now exists"))
        #expect(codepack.contains("release notarization remains distribution ops"))
        #expect(plan.contains("signature payload enumeration is capped with symlink descendants skipped before target resolution"))
        #expect(plan.contains("Browser-use Pro gate/settings/runtime diagnostics bound raw status/domain/path strings"))
        #expect(plan.contains("invalid loopback address failures use a bounded secret-aware host diagnostic"))
        #expect(!codepack.contains("Still pending: signing/notarization into final Pro resources"))
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
        #expect(codepack.contains("Runtime path discovery prefers a signed `BrowserUsePro.bundle` resource payload"))
        #expect(codepack.contains("verifies the signed `BrowserUsePro.bundle` payload is preferred over source-checkout discovery"))
        #expect(codepack.contains("rejects packaged adapters outside `BrowserUsePro.bundle/Contents/Resources/BrowserUsePro`"))
        #expect(codepack.contains("inherits only a bounded POSIX environment allowlist"))
        #expect(codepack.contains("oversized or control-character values dropped"))
        #expect(codepack.contains("verifies ambient process secrets/injection variables are not inherited"))
        #expect(codepack.contains("provider and browser-use cloud endpoints reject embedded URL credentials"))
        #expect(codepack.contains("non-secret environment settings are bounded before launch"))
        #expect(codepack.contains("leading/trailing whitespace before the browser-use process environment is built"))
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
        #expect(codepack.contains("Loaded proxy and endpoint environment URLs are validated before runtime import"))
        #expect(codepack.contains("allowed browser-use Pro environment values are capped to 4 KiB"))
        #expect(codepack.contains("reject control characters plus leading/trailing whitespace"))
        #expect(codepack.contains("Pro `.env` files are read through a no-follow descriptor"))
        #expect(codepack.contains("keeping Keychain proxy username/password bindings separate from proxy server URLs"))
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
        #expect(codepack.contains("browser open URL policy blocks legacy IPv4 literal forms"))
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
        #expect(codepack.contains("Rust bounds refs plus type text, press key, and eval expression inputs"))
        #expect(codepack.contains("bare `completed` status without `is_done=true` or `successful=true` no longer marks"))
        #expect(codepack.contains("non-empty bounded task errors downgrade completed-looking outcomes to failed"))
        #expect(codepack.contains("Final result and delegated task error truncation markers are kept inside their configured caps"))
        #expect(codepack.contains("redacts delegated task error strings"))
        #expect(codepack.contains("rejects missing `DEFAULT_LLM` with a bounded `browser.complete_task` configuration error"))
        #expect(codepack.contains("non-empty `error` / `errors`"))
        #expect(codepack.contains("loopback Origin and native-MCP registration URL validators reject embedded credentials, bearer tokens outside the generated token alphabet"))
        #expect(codepack.contains("rejected JSON-RPC method/tool identifiers are bounded and secret-aware"))
        #expect(codepack.contains("Bearer authorization parser accepts standard HTTP space/tab optional whitespace"))
        #expect(codepack.contains("MCP HTTP transport refuses query-bearing `/mcp` request targets"))
        #expect(codepack.contains("malformed or non-HTTP/1.1 single-space request lines, duplicate headers, transfer-encoded bodies, or trailing-byte request frames"))
        #expect(codepack.contains("native MCP bearer are forced to owner-only `0700` directories"))
        #expect(codepack.contains("owner-only `0600` file permissions"))
        #expect(codepack.contains("exclusive owner-only temporary files"))
        #expect(codepack.contains("negative/out-of-range click/scroll coordinates"))
        #expect(codepack.contains("unsupported computer-use tool names"))
        #expect(codepack.contains("can report `browser-use Pro: signed packaged payload ready` only after"))
        #expect(codepack.contains("`SIGNATURE_MANIFEST.json`"))
        #expect(codepack.contains("`PACKAGE_RESULT.json`"))
        #expect(codepack.contains("package-result checkpoint evidence"))
        #expect(codepack.contains("enclosing `BrowserUsePro.bundle` signature verify"))
        #expect(codepack.contains("nested-code and all-architecture checks"))
        #expect(codepack.contains("signed payload root to be exactly `Contents/Resources/BrowserUsePro`"))
        #expect(codepack.contains("Signature payload enumeration counts every visited entry"))
        #expect(codepack.contains("skips symlink descendants before resolving/checking the symlink target"))
        #expect(codepack.contains("bounds loopback host normalization and redacted URL diagnostics before trimming/comparison"))
        #expect(codepack.contains("invalid loopback address failures through a bounded secret-aware host diagnostic"))
        #expect(codepack.contains("app resource bundler parses `SIGNATURE_MANIFEST.json` as JSON"))
        #expect(codepack.contains("rejects symlinked signature manifests and symlink components before parsing"))
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
        #expect(codepack.contains("raw status/domain/path strings bounded before trimming"))
        #expect(codepack.contains("ellipsis kept inside configured caps"))
        #expect(codepack.contains("same bounded diagnostics helper as the gate"))
        #expect(codepack.contains("rejects non-executable Python, file/directory artifact shape mismatches"))
        #expect(codepack.contains("uses ad-hoc\n  signed `BrowserUsePro.bundle` fixtures for ready-path launch planning"))
        #expect(codepack.contains("lets the signed-payload\n  gate reject symlink escapes before runtime launch planning"))
        #expect(codepack.contains("rejects final symlinks plus symlink components in parent paths"))
        #expect(codepack.contains("rejecting symlinked env directories/files and symlinked parent components"))
        #expect(codepack.contains("removes that exact generated `.env` again through a no-follow descriptor/`fstat` exact-content check"))
        #expect(codepack.contains("rejects launch `.env` paths below symlinked parent directories before secrets are written"))
        #expect(codepack.contains("loopback health probe"))
        #expect(codepack.contains("maps health request failures to bounded domain/code diagnostics"))
        #expect(codepack.contains("terminates the launched process if the loopback health probe fails"))
        #expect(codepack.contains("Loopback server smoke harness"))
        #expect(codepack.contains("verifies any supplied signed bundle with deep strict `codesign`"))
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
        #expect(codepack.contains("wheelhouse, Chromium payload, signed `BrowserUsePro.bundle`, and gate smoke landed"))
        #expect(codepack.contains("rebuilds this staged payload by default before signing"))
        #expect(codepack.contains("live browser-use fixture smoke landed"))
        #expect(codepack.contains("complemented by the real Gradio WKWebView shell/control smoke"))
        #expect(codepack.contains("Full task-submit smoke landed"))
        #expect(codepack.contains("web_ui_dry_run_submit"))
    }

    @Test("browser.complete_task v2 catalog advertises the bounded task envelope")
    func browserCompleteTaskV2CatalogAdvertisesBoundedTaskEnvelope() throws {
        let catalog = try Self.loadSource("agent_core/src/tools_v2/v2_catalog/browser_complete_task.rs")
        let runtime = try Self.loadSource("agent_core/src/tools/browser_complete_task.rs")

        #expect(catalog.contains("pub fn output_schema() -> &'static Value"))
        #expect(catalog.contains("output_schema,"))
        #expect(!catalog.contains("generic_text_or_object_output_schema"))
        #expect(catalog.contains(#""additionalProperties": false"#))
        #expect(catalog.contains(#""enum": ["completed", "failed", "incomplete", "unknown"]"#))
        #expect(catalog.contains(#""required": ["error"]"#))

        for field in [
            "success",
            "adapter_success",
            "task_success",
            "status",
            "final_result",
            "errors",
            "steps",
            "max_steps",
            "task_chars",
            "is_done",
            "successful",
            "used_browser_use_agent",
            "dry_run",
            "truncated",
        ] {
            #expect(catalog.contains(#""\#(field)""#), "Catalog output schema missing \(field)")
            #expect(runtime.contains(#""\#(field)": "#), "Runtime output envelope missing \(field)")
        }
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
        #expect(codepack.contains("schema/name/runtime-lane/two-browser-boundary mismatches"))
        #expect(codepack.contains("vendor manifest schema, name, runtime lane, and two-browser boundary"))
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
            "BrowserUseDiagnostics.statusMessage(",
            "BrowserUseDiagnostics.statusMessage(joined, fallback: \"browser-use settings status\")",
            "ToolbarCapsuleButton(",
            "role: .primaryAction",
            "role: .secondaryGhost",
            "BrowserUseSettingsInputChrome",
            ".textFieldStyle(.plain)",
            "theme.resolved.card.color.opacity",
            "private var foregroundTint: Color",
            "private var mutedTint: Color",
            "private var rowGap: some View",
            "headless_shell_revision=",
            "ffmpeg_revision=",
            "Reset browser-use Pro settings to defaults",
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
        #expect(!settings.contains(".foregroundStyle(.secondary)"))
        #expect(!settings.contains(".foregroundStyle(.tertiary)"))
        #expect(!settings.contains(".foregroundStyle(.primary)"))
        #expect(!settings.contains(".buttonStyle(.plain)"))
        #expect(!settings.contains(".buttonStyle(.borderless)"))
        #expect(!settings.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!settings.contains("Divider()"))
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
            "OPENAI_ENDPOINT must not include username or password credentials",
            "BROWSER_USE_CLOUD_API_URL must not include a URL query",
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
            "BrowserUseLoopbackPolicy.redactedDescription(for: plan.loopbackURL)",
            "BrowserUseLoopbackPolicy.redactedDescription(for: url, maxLength: maxURLDiagnosticLength)",
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
        #expect(!supervisor.contains("plan.loopbackURL.absoluteString"))

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
            "WKWebsiteDataStore(forIdentifier:",
            "websiteDataStoreIdentifier",
            "BrowserUseLoopbackPolicy.allows",
            "self.settingsStore = settingsStore",
            "Task.detached(priority: .userInitiated)",
            "settingsStore.load()",
            "browser-use Pro settings could not be loaded",
            "BrowserUseDiagnostics.statusMessage(",
            "fallback: \"settings load failed\"",
            "fallback: \"runtime start failed\"",
            "readinessWorker?.cancel()",
            "supervisor.start",
            "shouldCancel: { Task.isCancelled }",
            "supervisor?.stop()",
            "BrowserUseLoopbackPolicy.redactedDescription(for: url, maxLength: maxNavigationDiagnosticLength)",
            "return BrowserUseLoopbackGuard.redactedDescription(for: loadedURL)",
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
        #expect(!shell.contains("error.localizedDescription"))
        #expect(!shell.contains("url.absoluteString)"))
        #expect(!shell.contains("loadedURL.absoluteString"))

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
        let expectedPackageVersions: [String: String?] = [
            "browser-use": "0.13.2",
            "web-ui": nil,
            "cdp-use": "1.4.5",
        ]

        for component in components {
            let name = try #require(component["name"] as? String)
            #expect(component["repo"] as? String == "https://github.com/browser-use/\(name).git")
            #expect(component["commit"] as? String == expectedPins[name])
            #expect(component["license"] as? String == "MIT")
            let expectedPackageVersion = expectedPackageVersions[name] ?? nil
            #expect(component["package_version"] as? String == expectedPackageVersion)
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
        #expect(playwrightChromium["headless_shell_revision"] as? String == "1223")
        #expect(playwrightChromium["ffmpeg_revision"] as? String == "1011")
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
        #expect(generated["headless_shell_revision"] as? String == "1223")
        #expect(generated["ffmpeg_revision"] as? String == "1011")
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
        #expect(FileManager.default.fileExists(
            atPath: vendorRoot.appendingPathComponent("playwright/chromium_headless_shell-1223").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: vendorRoot.appendingPathComponent("playwright/ffmpeg-1011").path
        ))
    }

    @Test("browser-use Pro packaging script is deterministic, Pro-only, and non-secret")
    func browserUseProPackagingScriptIsDeterministicAndProOnly() throws {
        let script = try Self.loadSource("agent_core/vendor/browser-use/build-pro-payload.sh")
        let releaseScript = try Self.loadSource("scripts/package-browser-use-pro.sh")
        let manifest = try Self.loadSource("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")

        for required in [
            "set -euo pipefail",
            "Plan 3 browser-use Pro packaging only",
            "Do not invoke this from MAS/App Store build phases",
            "PACKAGE_RESULT.json non-secret checkpoint evidence beside the bundle",
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
            "require_playwright_marker",
            "INSTALLATION_COMPLETE",
            "HEADLESS_SHELL_REVISION",
            "FFMPEG_REVISION",
            "BUILD_MANIFEST.json",
            "BUILD_MANIFEST=\"$build_manifest\"",
            "write_text_no_follow(",
            "os.open(path, flags, 0o644)",
            "os.fstat(fd)",
            "O_NOFOLLOW",
            "Path(os.environ[\"BUILD_MANIFEST\"])",
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
        #expect(releaseScript.contains("if [[ \"$skip_build\" -eq 0 ]]; then"))
        #expect(releaseScript.contains("read_text_no_follow"))
        #expect(releaseScript.contains("write_text_no_follow"))
        #expect(releaseScript.contains("os.open(path, flags)"))
        #expect(releaseScript.contains("os.fstat(fd)"))
        #expect(releaseScript.contains("O_NOFOLLOW"))
        #expect(releaseScript.contains("lines = read_text_no_follow(path, \"pyvenv.cfg\", MAX_PYVENV_CFG_BYTES).splitlines()"))
        #expect(releaseScript.contains("json.loads(read_text_no_follow(Path(os.environ[\"VENDOR_MANIFEST\"]), \"VENDOR_MANIFEST.json\"))"))
        #expect(releaseScript.contains("json.loads(read_text_no_follow(Path(os.environ[\"BUILD_MANIFEST\"]), \"BUILD_MANIFEST.json\"))"))
        #expect(releaseScript.contains("write_text_no_follow("))
        #expect(releaseScript.contains("Path(os.environ[\"SIGNATURE_MANIFEST\"])"))
        #expect(releaseScript.contains("package_result=\"$output_root/PACKAGE_RESULT.json\""))
        #expect(releaseScript.contains("Path(os.environ[\"PACKAGE_RESULT\"])"))
        #expect(releaseScript.contains("\"smoke_suite_entrypoint\": \"scripts/browser-use-pro-smoke-suite.sh\""))
        #expect(releaseScript.contains("\"smoke_suite_args\": [\"--signed-bundle\", \"BrowserUsePro.bundle\"]"))
        #expect(releaseScript.contains("\"notarization\": \"not recorded; release notarization remains distribution ops\""))
        #expect(releaseScript.contains("browser-use Pro package result: $package_result"))
        #expect(!releaseScript.contains("&& ! -x \"$venv_python\""))
        #expect(!releaseScript.contains("Path(os.environ[\"VENDOR_MANIFEST\"]).read_text"))
        #expect(!releaseScript.contains("Path(os.environ[\"BUILD_MANIFEST\"]).read_text"))
    }

    @Test("browser-use app resource bundler validates signed manifest as structured JSON")
    func browserUseAppResourceBundlerValidatesSignedManifestAsStructuredJSON() throws {
        let script = try Self.loadSource("bundle-app-runtime-assets.sh")

        for required in [
            "signature_manifest_has_required_browser_use_pro_evidence",
            "package_result_has_required_browser_use_pro_evidence",
            "BROWSER_USE_PRO_PACKAGE_RESULT_DEST",
            "path_has_symlink_component",
            "current.is_symlink()",
            "path_has_symlink_component(manifest_path) or manifest_path.is_symlink() or not manifest_path.is_file()",
            "path_has_symlink_component(package_result_path) or package_result_path.is_symlink() or not package_result_path.is_file()",
            "read_manifest_no_follow",
            "read_result_no_follow",
            "os.open(path, flags)",
            "os.fstat(fd)",
            "O_NOFOLLOW",
            "json.loads(read_manifest_no_follow(manifest_path))",
            "json.loads(read_result_no_follow(package_result_path))",
            "required_string(manifest, \"package_name\") != \"BrowserUsePro\"",
            "required_string(manifest, \"runtime_lane\") != \"pro-developer-id-only\"",
            "required_string(manifest, \"payload_root\") != \"Contents/Resources/BrowserUsePro\"",
            "required_string(result, \"signature_manifest\") != \"BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json\"",
            "result.get(\"codesign_verified\") is not True",
            "result.get(\"smoke_suite_args\") != [\"--signed-bundle\", \"BrowserUsePro.bundle\"]",
            "type(file_count) is not int or file_count <= 0 or file_count > 250000",
            "required_string(manifest, \"python\").startswith(\"Python 3.11.\")",
            "required_string(manifest, \"browser_use_version\") != \"0.13.2\"",
            "required_string(result, \"python\").startswith(\"Python 3.11.\")",
            "required_string(result, \"smoke_suite_entrypoint\") != \"scripts/browser-use-pro-smoke-suite.sh\"",
            "not isinstance(manifest, dict)",
            "not isinstance(result, dict)",
            "set(manifest.keys()) != expected_manifest_keys",
            "set(result.keys()) != expected_result_keys",
            "is_second_precision_utc_timestamp",
            "required_string(manifest, \"created_utc\")",
            "required_string(result, \"created_utc\")",
            "not is_second_precision_utc_timestamp(created_utc)",
            "required_string(manifest, \"codesign_contract\") != expected_codesign_contract",
            "manifest.get(\"component_repos\") != expected_repos",
            "manifest.get(\"component_commits\") != expected_commits",
            "manifest.get(\"component_versions\") != expected_versions",
            "manifest.get(\"playwright_revisions\") != expected_playwright",
            "[ ! -L \"$signature_manifest\" ]",
            "[ ! -L \"$package_result\" ]",
            "rsync -a \"$package_result_source\" \"$BROWSER_USE_PRO_PACKAGE_RESULT_DEST\"",
            "/usr/bin/codesign --verify --deep --strict --verbose=2 \"$candidate\"",
        ] {
            #expect(script.contains(required), "Missing browser-use app resource bundler guard: \(required)")
        }

        #expect(!script.contains("grep -q \"$pattern\" \"$signature_manifest\""))
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
            "/usr/bin/codesign --verify --deep --strict --verbose=2",
            "signature_manifest=\"$payload_root/SIGNATURE_MANIFEST.json\"",
            "Missing regular signed package evidence",
            "127.0.0.1",
            "--ip 127.0.0.1",
            "--theme Ocean",
            "PLAYWRIGHT_BROWSERS_PATH",
            "PYTHON_DOTENV_DISABLED=true",
            "GRADIO_ANALYTICS_ENABLED=False",
            "BROWSER_USE_HOME",
            "result.json",
            "webui.log",
            "state_log_file=\"$state_root/webui.log\"",
            "probe_body_file=\"$state_root/root.html\"",
            "MAX_BODY_SAMPLE_BYTES",
            "read_body_sample_no_follow",
            "write_text_no_follow",
            "copy_evidence_no_follow",
            "body_has_marker_no_follow",
            "DESTINATION_PATH",
            "MAX_EVIDENCE_BYTES",
            "os.open(path, flags, 0o600)",
            "os.fstat(fd)",
            "O_NOFOLLOW",
            "Artifact directory must not be a symlink",
            "artifact_dir=\"$(cd -P -- \"$artifact_dir\" && pwd)\"",
            "body_truncated",
            "secrets\": \"not recorded\"",
            "curl -fsS --max-time 2",
            "curl -fsS --max-time 2 -o \"$probe_body_file\"",
            ">\"$state_log_file\" 2>&1",
            "sync_log_evidence",
            "sync_body_evidence",
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
            "-o \"$body_file\"",
            ">\"$log_file\" 2>&1",
            "grep -qi",
        ] {
            #expect(!script.contains(forbidden), "browser-use loopback smoke crossed boundary: \(forbidden)")
        }
    }

    @Test("browser-use Pro smoke suite composes signed gate and loopback smokes only")
    func browserUseProSmokeSuiteComposesGateAndLoopbackSmokesOnly() throws {
        let script = try Self.loadSource("scripts/browser-use-pro-smoke-suite.sh")
        let gateSmoke = try Self.loadSource("scripts/browser-use-pro-gate-smoke.swift")

        for required in [
            "Plan 3 browser-use Pro smoke suite",
            "This script intentionally does not run xcodebuild or the full test suite.",
            "swiftc",
            "browser-use-pro-gate-smoke-stubs.swift",
            "FeatureGateOverride.swift",
            "BrowserUseManifestError.swift",
            "BrowserUseSymlinkPathGuard.swift",
            "BrowserUseProGateStatus.swift",
            "BrowserUseSignedBundleStatus.swift",
            "browser-use-pro-gate-smoke.swift",
            "-framework Security",
            "browser-use-pro-loopback-smoke.sh",
            "--signed-bundle",
            "--payload-root",
            "--skip-gate",
            "--skip-loopback",
            "--repo-root",
            "--artifact-dir",
            "Timeout must be an integer from 5 through 600 seconds",
            "Port must be an integer from 1024 through 65535",
            "--signed-bundle is required for the gate smoke; pass --skip-gate",
            "At least one smoke must run.",
            "Artifact directory must not be a symlink",
            "artifact_dir=\"$(cd -P -- \"$artifact_dir\" && pwd)\"",
            "browser-use Pro smoke suite OK",
        ] {
            #expect(script.contains(required), "Missing browser-use Pro suite string: \(required)")
        }

        for required in [
            "Package result verified",
            "browser-use-pro-smoke-suite.sh",
            "expected package-result evidence in signed packaged gate detail",
        ] {
            #expect(gateSmoke.contains(required), "Missing browser-use gate smoke string: \(required)")
        }

        for forbidden in [
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "UserDefaults",
            "BrowserView",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "PDFView",
            "xcodebuild -",
            "swift test",
            "cargo test",
        ] {
            #expect(!script.contains(forbidden), "browser-use Pro suite crossed boundary: \(forbidden)")
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
