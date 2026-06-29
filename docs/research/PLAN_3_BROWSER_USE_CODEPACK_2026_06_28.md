# Plan 3 — browser-use Pro vendor codepack (staged Pro code, Pass 7)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §2/§9`. This records the landed Pro-only vendor/runtime staging lane
> for the Chromium robot. It is deliberately separate from the MAS-safe `BrowserView` WKWebView tab: browser-use drives
> Chromium over CDP; it does not and must not drive the native WKWebView Browser.

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
hash, file count, included path families, excluded `.git`, `full_clone: true`, and the MAS SourceMirror exclusion.
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
and `ffmpeg-1011`), and wrote a non-secret `BUILD_MANIFEST.json` outside MAS/App Store build phases.

Still pending: signing/notarization into final Pro resources and full loopback UI smoke. The manifest marks the build
script and adapter contract as `landed`, and marks the generated lock/build manifest, wheelhouse, and Playwright payload
as staged instead of pretending the signed Pro package exists.

`Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift` is now the always-compiled honest gate and manifest reader:
MAS returns unavailable; Pro returns off unless `EPISTEMOS_BROWSER_USE_PRO_V0=1`; with the staged payload manifest it
can report `browser-use Pro: packaged payload ready` only after the declared `requirements.lock`, wheelhouse, Chromium
payload, and `BUILD_MANIFEST.json` exist beside the manifest; manifest-declared artifact paths are relative-only and
cannot escape the vendor root; artifact symlinks must resolve inside the vendor root; file artifacts must be files and
directory artifacts must be directories. Launch remains user-initiated and separate from the native WKWebView Browser.
`Epistemos/Views/Settings/BrowserUseSettingsView.swift` mounts the Settings diagnostics surface under Extensions:
it reads the same gate/manifest, lists full-clone pins and packaging gaps, states the two-browser boundary, and exposes
no runtime launch control. It also reports the settings contract for the Pro lane.
`Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift` is now the non-secret settings and environment-rendering
contract: provider endpoints, browser profile/CDP/resolution settings, logging/telemetry/cloud/proxy flags, and
browser-use/web-ui environment names are Codable settings; API keys, cloud keys, proxy credentials, AWS credentials,
IBM project ID, and VNC password are bound to Keychain environment keys. Defaults keep telemetry, cloud sync, and
version checks off.
`EpistemosTests/BrowserUseSettingsStoreTests.swift` verifies privacy-first `.env` rendering, injected Keychain secret
binding, and non-secret JSON round-trip behavior.
`Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift` now lands the Pro runtime launch contract: it validates
the browser-use gate plus staged payload artifacts, builds the exact `web-ui/webui.py --ip 127.0.0.1 --port 7788
--theme Ocean` loopback plan, rejects non-executable Python, file/directory artifact shape mismatches, and runtime
artifact symlink escapes before launch planning, writes the Keychain-combined launch `.env` under Application Support
with owner-only permissions, and compiles the actual `Process()` launch only in
`#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
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
navigations, tears down delegates on dismantle, stops the runtime on disappear, and stops an already-launched runtime
if a readiness refresh finds the Pro gate invalid. It does not reuse or drive the native `BrowserView`. `[VERIFIED-CODE]`
`EpistemosTests/BrowserUseWebUIViewTests.swift` verifies the loopback URL guard and the source boundary. `[VERIFIED-CODE]`
`agent_core/vendor/browser-use/epistemos_agent_browser.py` is the source-only Plan 3 Pro adapter contract landed for the
existing `agent-browser --json <command>` shape. It maps `open/snapshot/click/fill/scroll/back/press/close/eval/
screenshot` to browser-use's `skill_cli` daemon. The `console/errors` commands are bounded compatibility stubs because
the vendored `skill_cli` has no matching console/error stream actions yet; these console/errors compatibility stubs
avoid browser-use runtime import until upstream exposes matching stream actions. The adapter keeps session files under
`AGENT_BROWSER_SOCKET_DIR` via `BROWSER_USE_HOME`, lazily imports browser-use only for runtime commands, and exposes a
no-runtime `contract` check for packaging tests. `AGENT_BROWSER_SOCKET_DIR` overrides any ambient `BROWSER_USE_HOME`
after validating that it is an absolute existing directory, so direct adapter invocation cannot redirect browser-use
session files away from the private socket root; session names are capped at 64 safe characters before browser-use
derives daemon/socket files.
Rust `find_agent_browser()` now discovers the bundled executable through
`EPISTEMOS_BROWSER_USE_AGENT_BROWSER` or `EPISTEMOS_BROWSER_USE_VENDOR_ROOT` before falling back to a user-installed
`agent-browser`; live fixture smoke opened `https://example.com`, captured an `Example Domain` snapshot, and closed the
isolated session with `PLAYWRIGHT_BROWSERS_PATH` pointed at the staged payload; adapter argument errors remain
JSON-bounded before runtime import, so invalid or missing `--json` commands produce the same machine-readable failure
shape without importing browser-use or emitting argparse usage on stderr. `[VERIFIED-CODE]`

## Existing Epistemos seams `[VERIFIED-CODE]`
- Native MAS browser tab: `Epistemos/Views/Browser/BrowserView.swift` is human-driven `WKWebView` with
  `WKWebsiteDataStore.nonPersistent()` and `BrowserURLGuard` http/https gating. It remains independent.
- Agent browser tools: `agent_core/src/tools/browser.rs` shells out to the bundled browser-use adapter when
  `EPISTEMOS_BROWSER_USE_AGENT_BROWSER` or `EPISTEMOS_BROWSER_USE_VENDOR_ROOT` is set, otherwise to a user-installed
  `agent-browser` binary. It applies hardened subprocess env clearing, timeouts, redacted output, SSRF/private URL
  blocking, credential-assignment redaction for token/api-key/password/secret variants, owner-only browser
  daemon/socket/screenshot directories, and `PYTHON_DOTENV_DISABLED=true` for the subprocess environment. The private
  directory policy is isolated in `agent_core/src/tools/browser_private.rs`: Rust rejects pre-existing symlink paths
  and non-current-user ownership for those private browser directories before launch or chmod, so
  session/socket/screenshot roots cannot be redirected through `/tmp` symlinks or hostile pre-created
  directories. Rust browser bridge also sets `PYTHON_DOTENV_DISABLED=true` before invoking the adapter, so browser-use
  cannot re-interpolate ambient `.env` values on this path. For screenshot commands, the adapter receives
  `AGENT_BROWSER_SCREENSHOT_DIR` and rejects requested or returned screenshot paths that resolve outside that private
  directory; it also rejects multiple screenshot output paths before runtime import. More generally, command-specific
  argument validation runs before browser-use daemon startup, so malformed `open`, `snapshot`, `click`, `fill`,
  `scroll`, `press`, `eval`, and `screenshot` inputs stay JSON-bounded without importing browser-use. Extra positional
  arguments and unexpected console/error flags are rejected before daemon startup. The console/errors compatibility
  stubs avoid browser-use runtime import until upstream exposes matching stream actions; they only accept optional
  `--clear`. Command arguments after `--json <command>` are preserved even when they begin with `--`. Runtime
  environment setup happens only after adapter arguments are accepted. The Rust bridge never trusts ambient
  `BROWSER_CDP_URL`; the only CDP override env is `EPISTEMOS_BROWSER_USE_CDP_URL`, and it must point at localhost,
  127.0.0.1, or [::1]. `browser_vision` also rejects screenshot paths that resolve outside the private screenshot
  directory before handing the image to any external vision provider. The
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
resolution, browser-use executable/profile/headless fields, logging, proxy, cloud URLs, and privacy flags. It does not
launch Python, Chromium, Playwright, or `webui.py`. The `.env` renderer quotes and escapes multiline/CRLF values before
writing the launch file.

## Pro runtime shape
New Plan 3 files should live outside Plan 1/Plan 2 ownership, for example:
- `Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift` — compile/distribution gate; MAS returns unavailable. **Landed.**
- `Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift` — non-secret Codable settings + Keychain secret binding.
  **Landed settings contract/env renderer.**
- `Epistemos/BrowserUsePro/BrowserUseRuntimeSupervisor.swift` — Pro-only hardened subprocess owner for
  `python webui.py --ip 127.0.0.1 --port <chosen>`, lazy-started by user action, killed on idle/app exit.
  **Launch-plan, secure `.env`, Pro-only subprocess branch, staged payload, and live fixture smoke landed.**
- `Epistemos/Views/BrowserUse/BrowserUseWebUIView.swift` — WKWebView shell for the loopback Gradio UI with honest status.
  **Loopback guard and user-initiated shell landed; full UI smoke still pending.**
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
  rejected before disk checks; file-vs-directory mismatches and symlink escapes are rejected before ready.
- Packaging script test: shell syntax passes; script requires `uv`, uses Python 3.11, compiles with
  `--generate-hashes`, stages third-party wheels under `--require-hashes --only-binary=:all:`, stages local vendored
  package wheels with `--no-deps`, installs Playwright Chromium into the Pro staging directory, writes only non-secret
  `BUILD_MANIFEST.json`, and says it is not for MAS/App Store build phases.
- Settings contract test: `BrowserUseSettingsStore.swift` includes typed non-secret provider/browser/runtime settings,
  a launch-time environment renderer, Keychain-backed secret bindings for provider/cloud/proxy/AWS/VNC values, privacy
  defaults with telemetry/cloud/version checks off, and no runtime launch seam.
- Behavior test: `BrowserUseSettingsStoreTests.swift` renders defaults without secret keys, appends only non-empty
  injected Keychain secrets, deletes empty secret values, and proves the JSON store omits API/proxy/VNC secret names.
- Runtime launch contract test: `BrowserUseRuntimeSupervisorTests.swift` keeps unpackaged payloads inactive, proves the
  staged launch plan uses `web-ui/webui.py`, loopback `127.0.0.1`, Keychain-combined environment values, and owner-only
  launch `.env` permissions, rejects a non-executable Python runtime and runtime artifact symlink escapes before
  launch planning, verifies bundled `BrowserUsePro/` resources are preferred over source-checkout discovery, verifies
  ambient process secrets/injection variables are not inherited, verifies dotenv loading is disabled for exact
  Keychain-rendered values, and verifies the subprocess branch is Pro-only.
- Web UI shell test: `BrowserUseWebUIViewTests.swift` allows only loopback Gradio URLs, keeps the WKWebView
  non-persistent, refreshes readiness off the SwiftUI path through the injected settings store, cancels non-loopback
  navigation, tears down delegates, and proves it does not reference native Browser, Goose/Agent, or Plan 2 editor/PDF
  surfaces.
- Adapter source test: `BrowserUseAdapterPlan3Tests.swift` verifies `epistemos_agent_browser.py` supports the existing
  `agent-browser --json` command set, delegates to `browser_use.skill_cli` only after runtime commands begin, keeps
  session files under `AGENT_BROWSER_SOCKET_DIR`/`BROWSER_USE_HOME`, keeps console/errors compatibility stubs runtime
  free until upstream exposes stream actions, and contains no Plan 1 Goose/Agent or Plan 2 editor/PDF/native Browser
  references.
- Python lock test after script execution: `browser-use`, `web-ui`, and `cdp-use` import from vendored/local paths;
  stale `browser-use==0.1.48` from web-ui is not installed.
- Pro runtime smoke: start loopback Gradio on `127.0.0.1`, load it in the WKWebView shell, submit a dry-run task with a
  local fixture page, then stop cleanly.
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
   full UI smoke still pending.**
6. Bridge the existing Pro `browser_*` tools to the bundled browser-use adapter or add sibling Pro-only tools.
   **Source-only adapter contract, Rust discovery wiring, and live tool smoke landed.**
7. Run the full Pro smoke suite, then the MAS boundary audit.
