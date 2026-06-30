# Plan 3 — browser-use Pro vendor codepack (staged Pro code, Pass 7)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §2/§9`. This records the landed Pro-only vendor/runtime staging lane
> for the Chromium robot. browser-use drives Chromium over CDP; it is deliberately separate from the MAS-safe
> `BrowserView` WKWebView tab and does not and must not drive the native WKWebView Browser.

## Current upstream pins `[WEB]`
Authoritative source is the official `browser-use/*` GitHub organization, checked on 2026-06-28 with `git ls-remote`
and local vendored source inspection:

| Component | Repo | Pin | License | Role |
|---|---|---:|---|---|
| browser-use | `https://github.com/browser-use/browser-use.git` | `2454d3e2551705232333c906ded8fc31ab0fc9f2` | MIT | agent/runtime/CLI |
| web-ui | `https://github.com/browser-use/web-ui.git` | `61962296c38a0d064e0ba02c827192b7a81d1819` | MIT | Gradio browser-use UI |
| cdp-use | `https://github.com/browser-use/cdp-use.git` | `a318684daab5ab3a9a516fcab447ed4bdfb92be9` | MIT | typed CDP client |

Verified package facts:
- `browser-use` `pyproject.toml`: package version `0.13.2`, `requires-python = ">=3.11,<4.0"`, MIT classifier,
  scripts `browser-use`, `browseruse`, `bu`, `browser`, and `browser-use-tui`; dependencies include `cdp-use==1.4.5`,
  `mcp==1.26.0`, `browser-use-sdk==3.4.2`, provider clients, document helpers, and optional `browser-use-core==0.13.2`
  wheels for darwin/linux/win platforms.
- `web-ui` `README.md`/`requirements.txt`: Gradio UI, `python webui.py --ip 127.0.0.1 --port 7788`, persistent
  browser sessions, own-browser mode, browser settings, many LLM providers. Its current `requirements.txt` pins
  `browser-use==0.1.48`; Epistemos must override that to the vendored `browser-use` source, not install the stale PyPI
  wheel.
- `cdp-use` `pyproject.toml`: version `1.4.5`, `requires-python >=3.11`, MIT, `httpx`, `typing-extensions`,
  `websockets`; tree includes generated `cdp_use/cdp/*` domains and the generator. Vendor the generated domains too.

## Current local vendor state `[VERIFIED-CODE]`
The full source trees are now staged under `agent_core/vendor/browser-use/` with no nested `.git` directories:

| Component | Local path | File count | Full source content retained |
|---|---|---:|---|
| browser-use | `agent_core/vendor/browser-use/browser-use/` | 501 | package, tests, examples, skills, static assets, docker docs, `.env.example` |
| web-ui | `agent_core/vendor/browser-use/web-ui/` | 42 | `webui.py`, `src/`, tests, assets, Docker/supervisor files, `.env.example` |
| cdp-use | `agent_core/vendor/browser-use/cdp-use/` | 357 | package, generated `cdp_use/cdp/*` domains, generator, examples, runbook |

`agent_core/vendor/browser-use/VENDOR_MANIFEST.json` records repo URL, commit SHA, license, license hash, package-file
hash, upstream file count, included path families, excluded `.git`, `full_clone: true`, and the MAS SourceMirror
exclusion. It also records the Epistemos `web_ui_runtime_compatibility` overlay: narrow browser-use compatibility shims
for old web-ui imports (`browser_use.browser.browser`, `browser_use.browser.context`, `browser_use.controller.*`) while
the upstream browser-use source pin and file count remain separately auditable. The manifest separately records
`web_ui_dry_run_submit`, the opt-in no-provider hook used only by the real Gradio WKWebView task-submit smoke.
`agent_core/vendor/browser-use/requirements.in` installs local editable `./browser-use` and `./cdp-use`, then repeats
web-ui dependencies while overriding stale pins that conflict with the vendored `browser-use` 0.13.2 tree:
`browser-use==0.1.48` is replaced by the local source, `gradio==5.27.0` is raised to `6.19.0` for Pillow 12.2.0
compatibility, and `langchain_mcp_adapters==0.0.9` is raised to `0.2.0` for `mcp==1.26.0` compatibility. It also
pins `playwright==1.60.0` as a Pro packaging dependency so Chromium can be staged at build time even though current
browser-use automation drives CDP through `cdp-use`.
`agent_core/vendor/browser-use/build-pro-payload.sh` is the Pro-only packaging script: it creates a Python 3.11 venv
under `build/browser-use-pro/.venv`, compiles `requirements.lock` with hashes from the vendored paths, syncs the venv,
staged third-party and local package wheels under `agent_core/vendor/browser-use/wheels/` (177 wheel files), staged
Playwright Chromium under `agent_core/vendor/browser-use/playwright/` (`chromium-1223`, `chromium_headless_shell-1223`,
and `ffmpeg-1011`), and writes a JSON-escaped, non-secret `BUILD_MANIFEST.json` outside MAS/App Store build phases.

Loopback server smoke harness landed at `scripts/browser-use-pro-loopback-smoke.sh`: it starts the staged
`build/browser-use-pro/.venv/bin/python agent_core/vendor/browser-use/web-ui/webui.py --ip 127.0.0.1 --port <ephemeral>
--theme Ocean`, probes the Gradio root document over loopback with a 5-600 second timeout bound, writes non-secret
evidence, and always tears down the child process. A local WKWebView fixture dry-run shell smoke also landed: it loads a loopback fixture in the
non-persistent shell, submits a no-provider fixture action, and verifies non-loopback navigation blocking. A real
Gradio WKWebView shell/control smoke also landed: it starts the staged loopback Gradio server, loads it in the
non-persistent shell, opens the Run Agent tab, fills the task box without clicking Submit, and verifies non-loopback
navigation blocking. A full real Gradio WKWebView task-submit smoke also landed with the Epistemos-only
`EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT` no-provider hook: it clicks the real Submit Task event, completes before
LLM/provider/browser setup, observes the deterministic `Epistemos browser-use WebUI dry-run task-submit complete` marker,
and verifies non-loopback navigation blocking. Still pending: signing/notarization into final Pro resources. The
manifest marks the build script and adapter contract as `landed`, and marks the generated lock/build manifest,
wheelhouse, and Playwright payload as staged instead of pretending the signed Pro package exists.

`Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift` is now the always-compiled honest gate and manifest reader:
MAS returns unavailable; Pro returns off unless `EPISTEMOS_BROWSER_USE_PRO_V0=1`; with the staged payload manifest it
can report `browser-use Pro: packaged payload ready` only after the declared `requirements.lock`, wheelhouse, Chromium
payload, and `BUILD_MANIFEST.json` exist beside the manifest; the manifest file itself is regular-file checked,
symlink-path rejected, read through a no-follow descriptor, and capped at 1 MiB before JSON decode; manifest-declared
artifact paths are relative-only and cannot escape the vendor root; artifact symlink aliases are rejected before shape
checks; file artifacts must be files and directory artifacts must be directories. Launch remains user-initiated and
separate from the native WKWebView Browser.
`Epistemos/Views/Settings/BrowserUseSettingsView.swift` mounts the Settings diagnostics surface under Extensions:
it reads the same gate/manifest, lists full-clone pins and packaging gaps, states the two-browser boundary, and exposes
no runtime launch control. It also reports the settings contract for the Pro lane.
`Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift` is now the non-secret settings and environment-rendering
contract: provider endpoints, browser profile/CDP/resolution settings, logging/telemetry/cloud/proxy flags, and
browser-use/web-ui environment names are Codable settings; API keys, cloud keys, proxy credentials, AWS credentials,
IBM project ID, and VNC password are bound to Keychain environment keys. Defaults keep telemetry, cloud sync, and
version checks off.
`EpistemosTests/BrowserUseSettingsStoreTests.swift` verifies privacy-first `.env` rendering, injected Keychain secret
binding, non-secret JSON round-trip behavior, owner-only settings file permissions, regular-file settings JSON reads,
and symlink rejection before the settings store reads or writes disk. `Epistemos/BrowserUsePro/BrowserUseSymlinkPathGuard.swift` is the shared path
guard that rejects final symlinks plus symlink components in parent paths, while allowing macOS `/var`/`/tmp`/`/etc`
compatibility links used by temporary directories.
`Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift` now lands the Pro runtime launch contract: it validates
the browser-use gate plus staged payload artifacts, validates loopback host/port plus a bounded Web UI theme, builds the
exact `web-ui/webui.py --ip 127.0.0.1 --port 7788 --theme Ocean` loopback plan, rejects non-executable Python, file/directory artifact shape mismatches, and runtime
artifact symlink escapes before launch planning, writes the Keychain-combined launch `.env` under Application Support
with owner-only permissions while rejecting symlinked env directories/files and symlinked parent components before
secrets are written, launches the Pro process only after an injected loopback health probe can validate
`http://127.0.0.1:<port>/`, keeps rejected-redirect health diagnostics origin-only so hostile Location URLs cannot echo
credentials, query tokens, fragments, or path contents, terminates the launched process if the loopback health probe fails, and compiles the actual
`Process()` launch only in
`#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
`scripts/browser-use-pro-loopback-smoke.sh` now exercises that staged server shape outside the app host by launching the
vendored Gradio UI on `127.0.0.1`, setting `PYTHON_DOTENV_DISABLED=true`, `PLAYWRIGHT_BROWSERS_PATH` to the staged
Chromium payload, and writing a bounded `result.json` plus `webui.log` in a caller-selected or temporary artifact
directory without recording secrets. `[VERIFIED-CODE]`
The smoke forced web-ui compatibility fixes now landed in the vendored Pro payload: optional LangChain MCP/provider
packages are no longer imported at UI module load, missing optional provider packages fail only when that provider is
selected, `ToolCallingMethod`/`is_model_without_tool_support`/`BrowserState` compatibility exports exist for the pinned
web-ui, and the Chatbot constructor uses the installed Gradio 6 `buttons=["copy"]` API instead of removed
`type="messages"` / `show_copy_button` arguments. `[VERIFIED-CODE]`
Runtime path discovery prefers a signed bundled `BrowserUsePro/` resource payload when present, then falls back to the
development source checkout layout, so Settings and launch planning resolve the same packaged Pro artifact.
The launched Python/Chromium process inherits only a small POSIX environment allowlist (PATH/HOME/locale/temp/user
basics); provider keys, proxy credentials, DYLD/PYTHON injection vectors, and the Pro gate flag are rendered only from
typed settings plus Keychain-backed secret bindings. The launch environment sets `PYTHON_DOTENV_DISABLED=true` so
browser-use consumes the exact `Process.environment` values and does not re-interpolate Keychain-rendered values from
the generated `.env` file.
App Store builds return an honest unavailable readiness and keep the native Browser tab separate.
`EpistemosTests/BrowserUseRuntimeSupervisorTests.swift` verifies packaged/unpackaged readiness, loopback launch-plan
shape, Keychain environment propagation, secure `.env` file permissions, and source boundaries.
`Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift` is the Pro loopback shell: it refreshes settings/readiness in a
detached worker using the injected `BrowserUseSettingsStore`, starts the supervisor only from a user action, loads only
`http://127.0.0.1:<port>` / `localhost` / `[::1]` Gradio URLs in a non-persistent WKWebView, cancels non-loopback
navigations, surfaces settings load failures instead of silently falling back, tears down delegates on dismantle, stops
the runtime if a start plan ever returns a non-loopback URL, stops the runtime on disappear, and stops an already-launched runtime if a readiness refresh finds the Pro gate invalid. It
does not reuse or drive the native `BrowserView`. `[VERIFIED-CODE]`
`EpistemosTests/BrowserUseWebUIViewTests.swift` verifies the loopback URL guard, the local WKWebView fixture dry-run
shell smoke, the real Gradio WKWebView shell/control and task-submit dry-run smokes, and the source boundary.
`[VERIFIED-CODE]`
`agent_core/vendor/browser-use/epistemos_agent_browser.py` is the source-only Plan 3 Pro adapter contract landed for the
existing `agent-browser --json <command>` shape. It maps `open/snapshot/click/fill/scroll/back/press/close/eval/
screenshot` to browser-use's `skill_cli` daemon. The `console/errors` commands are bounded compatibility stubs because
the vendored `skill_cli` has no matching console/error stream actions yet; these console/errors compatibility stubs avoid browser-use runtime import until upstream exposes matching stream actions. The adapter keeps session files under
`AGENT_BROWSER_SOCKET_DIR` via `BROWSER_USE_HOME`, lazily imports browser-use only for runtime commands, and exposes a
no-runtime `contract` check for packaging tests. `AGENT_BROWSER_SOCKET_DIR` overrides any ambient `BROWSER_USE_HOME`
after validating that it is an absolute existing directory, so direct adapter invocation cannot redirect browser-use
session files away from the private socket root; the adapter also rejects symlinked runtime-directory routes below
the macOS `/tmp`/`/var`/`/etc` compatibility symlinks and requires current-user owner-only permissions. Session names are capped at 64 safe characters before browser-use
derives daemon/socket files.
Rust `find_agent_browser()` now discovers the bundled executable through
`EPISTEMOS_BROWSER_USE_AGENT_BROWSER` or `EPISTEMOS_BROWSER_USE_VENDOR_ROOT` before falling back to a user-installed
`agent-browser`; live fixture smoke opened `https://example.com`, captured an `Example Domain` snapshot, and closed the
isolated session with `PLAYWRIGHT_BROWSERS_PATH` pointed at the staged payload; adapter argument errors remain generic and
JSON-bounded before runtime import, so invalid or missing `--json` commands produce the same machine-readable failure
shape without importing browser-use or emitting argparse usage on stderr. Direct adapter `--cdp` values are also
validated before runtime import and must be loopback-only with no URL credentials, query, or fragment. Direct adapter
`snapshot` responses cap snapshot text and refs before returning JSON, matching the Rust tool-output boundary. `[VERIFIED-CODE]`

## Existing Epistemos seams `[VERIFIED-CODE]`
- Native MAS browser tab: `Epistemos/Views/Browser/BrowserView.swift` is human-driven `WKWebView` with
  `WKWebsiteDataStore.nonPersistent()` and `BrowserURLGuard` http/https gating. It remains independent.
- Agent browser tools: `agent_core/src/tools/browser.rs` shells out to the bundled browser-use adapter when
  `EPISTEMOS_BROWSER_USE_AGENT_BROWSER` or `EPISTEMOS_BROWSER_USE_VENDOR_ROOT` is set, otherwise to a user-installed
  `agent-browser` binary. It applies hardened subprocess env clearing, timeouts, redacted output, SSRF/private URL
  blocking, owner-only browser daemon/socket/screenshot directories, and `PYTHON_DOTENV_DISABLED=true` for the
  subprocess environment. Non-empty JSON output is accepted as success only when it carries `success: true` and the
  process exits successfully. The command runner, bounded strict-UTF-8 output reader, socket directory naming, and local
  daemon cleanup
  are isolated in `agent_core/src/tools/browser_command.rs`; cleanup revalidates the socket root as a real current-user,
  owner-only directory before reading pid files or removing it. Input-shape parsing, ref normalization, and snapshot
  truncation are isolated in `agent_core/src/tools/browser_input.rs`. The executable discovery and CDP override policy is
  isolated in `agent_core/src/tools/browser_executable.rs`: explicit `EPISTEMOS_BROWSER_USE_AGENT_BROWSER` wins before the vendored
  root lookup and both win before `PATH`, while `EPISTEMOS_BROWSER_USE_CDP_URL` requires valid UTF-8, is loopback-only,
  and rejects URL credentials, queries, and fragments. Rust passes the private Epistemos `--session` name even when a
  validated CDP override is present, so CDP-backed runs do not fall back to the adapter's default session. The redaction policy
  is isolated in `agent_core/src/tools/browser_redaction.rs` and covers credential-assignment redaction for token/api-key/password/secret variants, split credential assignments, and split/compact auth-scheme follower tokens. It also covers OAuth-style
  client-secret/id-token/auth-code assignments and URL credential/query/fragment tokens. The screenshot path policy
  is isolated in `agent_core/src/tools/browser_screenshot.rs`: screenshots are created under an owner-only private root,
  the adapter receives `AGENT_BROWSER_SCREENSHOT_DIR`, stdout path parsing stays bounded to length-capped,
  quote/punctuation-tolerant `.png` tokens, and returned
  paths must resolve inside that owner-only, non-symlink-routed root before vision sees them. The browser tool schema definitions are isolated in
  `agent_core/src/tools/browser_schema.rs` and re-exported by the runtime bridge so the registry surface stays
  unchanged. The private directory policy is isolated in `agent_core/src/tools/browser_private.rs`: Rust rejects
  pre-existing symlink paths and non-current-user ownership for those private browser directories before launch or chmod, so
  session/socket/screenshot roots cannot be redirected through `/tmp` symlinks or hostile pre-created
  directories. Rust browser bridge also sets `PYTHON_DOTENV_DISABLED=true` before invoking the adapter, so browser-use
  cannot re-interpolate ambient `.env` values on this path. For screenshot commands, the adapter receives
  `AGENT_BROWSER_SCREENSHOT_DIR` and rejects requested or returned screenshot paths that resolve outside that private
  directory; if browser-use returns base64 image bytes instead of a saved file for a requested path, the adapter writes only
  valid PNG bytes into the confined path, and screenshot size metadata is normalized to numeric width/height only. It
  also rejects multiple screenshot output paths before runtime import. More generally, command-specific
  argument validation runs before browser-use daemon startup, so malformed `open`, `snapshot`, `click`, `fill`,
  `scroll`, `press`, `eval`, and `screenshot` inputs stay JSON-bounded without importing browser-use. Rust bounds refs
  to short safe tokens before adapter execution. Extra positional
  arguments and unexpected console/error flags are rejected before daemon startup without echoing rejected values. The console/errors compatibility
  stubs avoid browser-use runtime import until upstream exposes matching stream actions; they only accept optional
  `--clear`. Command arguments after `--json <command>` are preserved even when they begin with `--`. The adapter
  `fill`/`press` results and Rust `browser_type`/`browser_press` results acknowledge success and report only character
  counts; they never echo submitted text/key input back into tool output. Runtime
  environment setup happens only after adapter arguments are accepted. The Rust bridge never trusts ambient
  `BROWSER_CDP_URL`; the only CDP override env is `EPISTEMOS_BROWSER_USE_CDP_URL`, and it must be valid UTF-8, point at
  localhost, 127.0.0.1, or [::1] with no URL username/password credentials, query, or fragment. The browser output
  policy uses `agent_core/src/tools/browser_output.rs` for normalization and bounds: `browser_get_images` asks the page
  for a pre-capped image payload, normalizes page-controlled image metadata, caps returned image count, truncates image
  text fields, sanitizes image `src` URLs before the image text cap, and preserves page/adapter truncation flags;
  `browser_snapshot` caps snapshot text, derives refs only
  from that bounded text, and preserves adapter truncation flags before returning capped refs;
  and `browser_console` caps page-controlled
  console/error/evaluation arrays, object fields, and strings before returning tool output. Direct adapter `eval`
  responses also cap nested result arrays, object fields, keys, and strings, and replace non-string eval keys with a
  fixed placeholder before returning JSON. Browser URL result fields from
  `open`/`back`/`browser_navigate`/`browser_back` drop credentials, queries, and fragments, redact non-HTTP(S) URL
  schemes, then cap long URL/path strings before returning tool output. Adapter JSON error responses pre-bound the error
  input before sanitizer regex work, then redact common secret assignments, token/api-key aliases, OAuth-style
  refresh/authorization codes, Bearer/Basic auth-scheme tokens, and URL credential/query/fragment tokens before applying
  an error length cap.
  Runtime responses require `success is True`; non-string runtime error payloads are not stringified into adapter output.
  `browser_vision` also rejects screenshot
  paths that resolve outside the private screenshot directory before handing the image to any external vision provider,
  deletes the temporary screenshot after the provider call returns, and does not return the absolute screenshot path in
  success or validation error output. The
  registry exposes the 11 `browser_*` tools only under `#[cfg(feature = "pro-build")]`
  (`browser_navigate/snapshot/click/type/scroll/back/press/close/get_images/vision/console`).
- MAS boundary tests already forbid `browser_use`/process tools in core App Store surfaces. This codepack must preserve
  that split.

## Product boundary
Two browsers, two promises:
- **App Store:** `BrowserView` WKWebView tab, user-driven only. No Python, no subprocess, no Chromium, no CDP, no
  browser-use, no automation seam. `WebKitBrowserEngine` and `ObscuraBrowserEngine` stay `NotConfigured`.
- **Pro / Developer ID:** full browser-use app, Gradio web UI in a `WKWebView`, Python 3.11 environment, bundled
  Playwright Chromium, CDP robot, and Goose-accessible MCP/tool bridge. It drives Chromium, not the native WKWebView.

## FULL-CLONE vendor layout
Vendor the complete app and keep source provenance visible:

```text
agent_core/vendor/browser-use/
  VENDOR_MANIFEST.json
  browser-use/          # full source checkout at 2454d3e...
  web-ui/               # full source checkout at 619622...
  cdp-use/              # full source checkout at a31868...
  wheels/               # hash-pinned Python wheels, produced at build time
  playwright/           # Chromium/browser payload staged at build time
  patches/              # minimal Epistemos launch/config patches only
```

`VENDOR_MANIFEST.json` must record repo URL, commit SHA, license, clone timestamp, included/excluded paths, wheel lock
hash, Playwright browser revision, and a `full_clone: true` assertion for all three repos. Do not cherry-pick only
`webui.py` or only selected browser-use modules; the owner required settings and capabilities intact.

Exclusions are limited to `.git`, caches, virtualenvs, build artifacts, and downloaded test output. Keep tests, examples,
generated CDP modules, `.env.example`, Docker docs, assets, and README files for auditability.

Critical packaging guard: this repo's build copies `agent_core` into an app `SourceMirror` resource. Before vendoring
browser-use under `agent_core/vendor/browser-use/`, exclude that directory from SourceMirror and every MAS/App Store
resource-copy phase, or stage the clone in a Pro-only resource root that the MAS target never sees. Source-visible Python
is fine for the Pro packaging job; it is not fine as an accidental MAS app resource.

## Dependency and Chromium packaging
Build the Pro payload as a deterministic bundle:
1. Create a Python 3.11 virtualenv at build time, outside MAS targets.
2. Generate a hash-pinned requirements lock from the vendored sources. The lock must install local paths for
   `browser-use` and `cdp-use`, and constraints-override stale web-ui pins that conflict with the vendored
   `browser-use` tree (`browser-use==0.1.48`, `gradio==5.27.0`, `langchain_mcp_adapters==0.0.9`).
3. Use binary wheels where available; build sdist-only dependencies into wheels under the Pro packaging lane and record
   every exception in the manifest with license and build proof.
4. Run Playwright's Chromium install during the Pro build, copy the browser payload into the signed Pro resources, and
   record the exact browser revision. No runtime browser download.
5. Code-sign/notarize Python, native extensions, and Chromium with the Developer ID profile. This lane is not App Store
   eligible.

Suggested commands for the implementation script (names are placeholders, not runtime app behavior):

```bash
uv venv --python 3.11 --seed build/browser-use-pro/.venv
uv pip compile --python-version 3.11 --generate-hashes --quiet agent_core/vendor/browser-use/requirements.in -o agent_core/vendor/browser-use/requirements.lock
uv pip sync --python build/browser-use-pro/.venv/bin/python agent_core/vendor/browser-use/requirements.lock
build/browser-use-pro/.venv/bin/python -m pip wheel --require-hashes --wheel-dir agent_core/vendor/browser-use/wheels --requirement build/browser-use-pro/requirements.third-party.lock
build/browser-use-pro/.venv/bin/python -m pip wheel --no-deps --wheel-dir agent_core/vendor/browser-use/wheels agent_core/vendor/browser-use/browser-use agent_core/vendor/browser-use/cdp-use
PLAYWRIGHT_BROWSERS_PATH=agent_core/vendor/browser-use/playwright build/browser-use-pro/.venv/bin/python -m playwright install chromium
```

The landed script is `agent_core/vendor/browser-use/build-pro-payload.sh`. It must never be referenced by Xcode MAS
targets, runtime launch paths, app resources, or SourceMirror copies.

## Settings preservation
Mirror web-ui/browser-use settings instead of flattening them into a thin "task" box. Minimum surfaced settings:
- LLM provider/API endpoints: OpenAI, Anthropic, Google, Azure OpenAI, DeepSeek, Mistral, Ollama, Alibaba, ModelScope,
  Moonshot, Unbound, SiliconFlow, IBM, Grok, and `DEFAULT_LLM`.
- Browser settings: `BROWSER_PATH`, `BROWSER_USER_DATA`, `BROWSER_DEBUGGING_HOST`, `BROWSER_DEBUGGING_PORT`,
  `KEEP_BROWSER_OPEN`, `USE_OWN_BROWSER`, `BROWSER_CDP`, resolution width/height/depth, headless/executable/user-data
  settings from browser-use (`BROWSER_USE_HEADLESS`, `BROWSER_USE_EXECUTABLE_PATH`, `BROWSER_USE_USER_DATA_DIR`).
- Runtime settings: telemetry, logging level, debug/info log files, proxy server/no-proxy/credentials, browser-use cloud
  URL/API key/sync flags, version-check flag, `ANONYMIZED_TELEMETRY`, `BROWSER_USE_LOGGING_LEVEL`,
  `BROWSER_USE_PROXY_SERVER`, `BROWSER_USE_PROXY_URL`, `BROWSER_USE_NO_PROXY`, `RESOLUTION`, `RESOLUTION_WIDTH`, and
  `RESOLUTION_HEIGHT`.
- Web UI tabs: agent settings, browser settings, browser-use agent, deep research agent, load/save config. Reskin CSS,
  but do not remove controls.

Secrets go to Keychain only. Generate a per-profile `.env` at launch from Keychain + non-secret settings; never write API
keys, proxy passwords, browser-use cloud keys, or bearer tokens into UserDefaults, logs, JSON manifests, or the source
tree. Default telemetry/cloud sync should be off unless the user explicitly enables it.

**Landed settings contract `[VERIFIED-CODE]`:** `BrowserUseSettingsStore.swift` preserves the non-secret web-ui and
browser-use environment shape as typed Codable settings and renders a launch-time `.env` by combining those values with
`BrowserUseSecretBinding` values loaded from Keychain. It covers `DEFAULT_LLM`, provider endpoints, own-browser/CDP,
resolution, browser-use executable/profile/headless fields, logging, proxy, cloud URLs, and privacy flags. Browser debugging
host and non-empty CDP URLs are loopback-constrained and reject URL credentials, queries, and fragments; non-empty proxy
server URLs must use supported proxy schemes and keep credentials, paths, queries, and fragments out of non-secret JSON.
Settings JSON reads require a regular file before size checks or decode. It does not launch Python, Chromium,
Playwright, or `webui.py`. The `.env` renderer quotes and escapes multiline/CRLF values before writing the launch file.

## Pro runtime shape
New Plan 3 files should live outside Plan 1/Plan 2 ownership, for example:
- `Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift` — compile/distribution gate; MAS returns unavailable. **Landed.**
- `Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift` — non-secret Codable settings + Keychain secret binding.
  **Landed settings contract/env renderer.**
- `Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift` — Pro-only hardened subprocess owner for
  `python webui.py --ip 127.0.0.1 --port <chosen>`, lazy-started by user action, killed on idle/app exit.
  **Launch-plan, secure `.env`, Pro-only subprocess branch, staged payload, loopback server smoke harness, and live
  fixture smoke landed.**
- `Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift` — WKWebView shell for the loopback Gradio UI with honest status.
  **Loopback guard, user-initiated shell, local WKWebView fixture dry-run shell smoke, and real Gradio WKWebView
  shell/control plus task-submit dry-run smokes landed.**
- `Epistemos/Views/Settings/BrowserUseSettingsView.swift` — settings mirror + diagnostics.

Do not edit `Epistemos/Goose/*`, `Epistemos/Agent/*`, or Plan 2 editor surfaces for the Pro shell. Goose access should
come through the existing tool/MCP registry seam once the Pro runtime is registered.

## Tool bridge
The existing `browser_*` tools are the compatibility bridge. The source-only adapter contract now exists at
`agent_core/vendor/browser-use/epistemos_agent_browser.py` and speaks the same JSON action contract as the user-installed
`agent-browser` binary. `find_agent_browser()` now discovers that bundled executable before `PATH` fallback through
`EPISTEMOS_BROWSER_USE_AGENT_BROWSER` or `EPISTEMOS_BROWSER_USE_VENDOR_ROOT`, and fails loudly if an explicit bundled
path is missing or non-executable. The bridge keeps the existing `browser_*` tool names behind `#[cfg(feature =
"pro-build")]`. In both cases:
- MAS builds compile without the adapter and expose no browser-use tools.
- Navigation keeps the existing SSRF/private-network guard before any CDP navigation.
- Actions that click/type/press remain high-risk and approval-gated.
- Output is redacted and bounded exactly like the current `agent-browser` path.
- Browser-use profile state is separate from the native Browser WKWebView profile.
- Current state: adapter contract, Pro Rust discovery wiring, and live browser-use fixture smoke landed.

## Honest gates and failure states
- MAS: visible Browser button opens the native WKWebView tab; browser-use settings/actions show "Pro only" and launch
  nothing.
- Pro missing payload: "browser-use runtime not installed" with repair instructions; launch nothing.
- Pro payload present but Python/Chromium signature check fails: block launch and show diagnostics.
- Web UI starts but health probe fails: stop the subprocess, redact logs, surface the first bounded error.
- User uses own browser: show that Epistemos cannot guarantee profile isolation for external Chrome and require opt-in.
- CAPTCHA/login/anti-bot: honest limitation, not a retry loop that pretends reliability.

## Verification gates
- Source guards: no `browser-use`, Python, Playwright, Chromium, or subprocess launch on MAS paths; no `BrowserUsePro`
  references from `BrowserView`; `WebKitBrowserEngine` still returns `NotConfigured`.
- Vendor manifest test: pins match the three SHAs above, licenses are MIT, and `full_clone` is true.
- Gate artifact test: an armed manifest that claims staged packaging but lacks the declared runtime artifacts remains
  inactive and reports `browser-use Pro: packaged payload incomplete`; absolute or parent-relative artifact paths are
  rejected before disk checks; manifest symlinks and oversized/no-follow manifest files are rejected before decode;
  file-vs-directory mismatches, artifact symlink aliases, and symlink escapes are rejected before ready.
- Packaging script test: shell syntax passes; script requires `uv`, uses Python 3.11, compiles with
  `--generate-hashes`, stages third-party wheels under `--require-hashes --only-binary=:all:`, stages local vendored
  package wheels with `--no-deps`, installs Playwright Chromium into the Pro staging directory, writes only non-secret
  JSON-escaped `BUILD_MANIFEST.json`, and says it is not for MAS/App Store build phases.
- Settings contract test: `BrowserUseSettingsStore.swift` includes typed non-secret provider/browser/runtime settings,
  loopback-only browser debugging/CDP validation, a launch-time environment renderer, Keychain-backed secret bindings
  for provider/cloud/proxy/AWS/VNC values, privacy defaults with telemetry/cloud/version checks off, and no runtime launch seam.
- Behavior test: `BrowserUseSettingsStoreTests.swift` renders defaults without secret keys, appends only non-empty
  injected Keychain secrets, deletes empty secret values, and proves the JSON store omits API/proxy/VNC secret names.
- Runtime launch contract test: `BrowserUseRuntimeSupervisorTests.swift` keeps unpackaged payloads inactive, proves the
  staged launch plan uses `web-ui/webui.py`, loopback `127.0.0.1`, Keychain-combined environment values, and owner-only
  launch `.env` permissions, rejects a non-executable Python runtime and runtime artifact symlink escapes before
  launch planning, rejects launch `.env` paths below symlinked parent directories before secrets are written, verifies
  bundled `BrowserUsePro/` resources are preferred over source-checkout discovery, verifies ambient process
  secrets/injection variables are not inherited, verifies dotenv loading is disabled for exact Keychain-rendered values,
  verifies a failed loopback health probe terminates the launched process before surfacing a bounded error, and verifies
  the subprocess branch is Pro-only.
- Loopback server smoke harness: `scripts/browser-use-pro-loopback-smoke.sh` starts the staged Pro `webui.py` on
  `127.0.0.1`, forces the staged Playwright browser path, disables dotenv reloading and Gradio analytics, polls only the
  loopback root URL with a 5-600 second timeout bound, writes non-secret `result.json`/`webui.log` evidence, and kills the
  child process on pass, timeout, or early exit. This is landed, but it is not a WKWebView or task-submit smoke.
- Web-ui compatibility guard: the vendor manifest must record the Epistemos overlay shims separately from upstream
  source counts, including the `web_ui_dry_run_submit` no-provider hook; the pinned web-ui must import/build a Gradio
  Blocks object without eager LangChain MCP/provider package imports; and the staged Gradio 6 Chatbot constructor must not
  use removed `type="messages"` or `show_copy_button` parameters.
- Web UI shell test: `BrowserUseWebUIViewTests.swift` allows only loopback Gradio URLs, keeps the WKWebView
  non-persistent, refreshes readiness off the SwiftUI path through the injected settings store, cancels non-loopback
  navigation, loads a local loopback fixture, submits a no-provider fixture action, starts the staged real Gradio UI,
  opens its Run Agent tab, fills the task input without submitting, submits a separate no-provider dry-run task through
  the real Gradio Submit Task event, tears down delegates/processes, and proves it does not reference native Browser,
  Goose/Agent, or Plan 2 editor/PDF surfaces.
- Adapter source test: `BrowserUseAdapterPlan3Tests.swift` verifies `epistemos_agent_browser.py` supports the existing
  `agent-browser --json` command set, delegates to `browser_use.skill_cli` only after runtime commands begin, keeps
  session files under `AGENT_BROWSER_SOCKET_DIR`/`BROWSER_USE_HOME`, keeps console/errors compatibility stubs runtime
  free until upstream exposes stream actions, and contains no Plan 1 Goose/Agent or Plan 2 editor/PDF/native Browser
  references.
- Python lock test after script execution: `browser-use`, `web-ui`, and `cdp-use` import from vendored/local paths;
  stale `browser-use==0.1.48` from web-ui is not installed.
- Full task-submit smoke landed: `BrowserUseWebUIViewTests.swift` submits an agent task through the real Gradio UI using
  the `EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT` no-provider hook, observes the completion marker, then stops cleanly.
- Tool smoke: `browser_navigate` to a local fixture, `browser_snapshot`, `browser_click`, `browser_close`; prove session
  reuse, owner-only session/screenshot directories, and bounded/redacted output.
- App Store audit: the `EPISTEMOS_APP_STORE MAS_SANDBOX` compile branch returns unavailable before launch planning,
  strips the `Process()` branch, and contains no Python, Playwright, Chromium, browser-use resources, or
  `agent_core/vendor/browser-use` SourceMirror output.

## Delivery order
1. Add the codepack + source guards (this file). **Landed.**
2. Vendor full source into `agent_core/vendor/browser-use/` and write `VENDOR_MANIFEST.json`. **Landed.**
3. Add Pro-only packaging scripts and hash-locked wheel/Chromium staging. **Packaging script, generated lock,
   wheelhouse, and Chromium payload landed; signing and notarization still pending.**
4. Add `BrowserUseProGateStatus` + Settings gate; MAS says Pro only. **Gate, diagnostic Settings surface, and
   settings/env contract landed.**
5. Add runtime supervisor + loopback WebView shell. **Runtime launch contract and WKWebView loopback shell landed;
   loopback health gating, loopback server smoke harness, local WKWebView fixture dry-run shell smoke, and real Gradio
   WKWebView shell/control plus task-submit dry-run smokes landed.**
6. Bridge the existing Pro `browser_*` tools to the bundled browser-use adapter or add sibling Pro-only tools.
   **Source-only adapter contract, Rust discovery wiring, and live tool smoke landed.**
7. Run the full Pro smoke suite, then the MAS boundary audit.
