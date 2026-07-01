# Goose on MAS — BUILD CANON (converged 2026-06-30)

> **THE reference for the MAS portion of Plan 1.** Converged from **6 independent research efforts** — Epistemos internal
> deep-research (`wf_7d57fe20-003`, 24/25 claims verified) + owner-supplied Gemini-1, Gemini-2, GPT-1, GPT-2, and a
> Goose-embedding synthesis. Where the six agree, it's marked **[CONSENSUS]**; where they diverge or Apple is silent,
> it's marked **[OPEN]**. Focused on the decisions that matter — read the individual reports only for code samples.
> **Companion:** `GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md` (Epistemos foundation + build order + proof bar).
> **Do NOT start MAS work until the owner green-lights it** (gate: `EPISTEMOS_MAS_GOOSE_V0`, default off).

## VERDICT — CONDITIONAL YES [CONSENSUS, 6/6]
A bounded, cloud-first in-process agent behind a WKWebView **can ship on the Mac App Store** under the standard App
Sandbox + hardened runtime. The primitives are proven in shipping apps; the *assembly* (a real in-process multi-step
tool-using agent) has **no confirmed MAS precedent** — you'd likely be a first. **You win or lose review on Guideline
2.5.2** (self-contained; no downloaded/executed code). Everything below is in service of that.

---

## 1. TRANSPORT — the one place the research CORRECTS the earlier plan [CONSENSUS, 6/6]
My first single-source pass leaned `WKURLSchemeHandler`. **All five additional reports converge the other way, and they're
right.** The canonical MAS transport is:

- **CONTROL PLANE → `WKScriptMessageHandlerWithReply`** (macOS 11+) for JS→native request/reply (start turn, cancel,
  pick vault, get config). Register on an isolated `WKContentWorld` so page scripts can't spoof the bridge.
- **DATA PLANE (streaming tokens/tool-state) → native push via `callAsyncJavaScript(_:arguments:in:in:)`** (preferred over
  `evaluateJavaScript` string-interpolation — it passes the payload as a real JS argument, no escaping/injection bugs).
  One call per streamed event.
- **`WKURLSchemeHandler` → RESOURCE VIRTUALIZATION ONLY** (e.g. an `app-vault://` scheme for read-only vault file
  previews). **NOT the primary RPC channel.**
- **NO loopback HTTP/WebSocket server** on the MAS build.

**WHY (the nuance that flips the earlier call):** custom URL schemes are treated by WebKit as **insecure contexts** — they
lose `crypto.subtle` (Web Crypto), Service Workers, and other secure-context APIs; the only fix is the **private**
`_registerURLSchemeAsSecure:` selector, which is banned under **2.5.1 (public APIs only)**. Custom-scheme POST bodies also
have historical edge cases (blob bodies still unreliable). The message-handler + event-push path keeps the UI on a secure
origin (bundle `file://`) and uses only first-class public APIs. A loopback server additionally needs
`com.apple.security.network.server`, exposes a **local port any other process in the shared namespace can probe**, and
invites reviewer questions ("why does a self-contained app open a listener?").

### ⚠️ EPISTEMOS-SPECIFIC DECISION — Goose WebUI speaks ACP over a WebSocket [OPEN → owner/architect call]
The kept Goose WebUI's client talks ACP over `ws://…/acp` — i.e. it *wants a server*. Two paths for MAS:
- **(A) PREFERRED — adapt the Goose WebUI's ACP transport to the WebKit bridge.** Point its ACP client at the
  message-handler (control) + `callAsyncJavaScript` (stream) shim → agent_core FFI. Cleaner for review, no `network.server`,
  no attack surface. More up-front work (touch the Goose web transport layer). This is what the 6-source consensus favors.
- **(B) FALLBACK — keep an in-app loopback ACP server on MAS** (Epistemos already declares `network.server` + has the
  `WorkSPAServer` pattern). Shippable *with hardening*: bind 127.0.0.1 only · random ephemeral port · **per-launch
  unguessable bearer token required on every frame** · strict `Origin`/`Host` allowlist (anti-DNS-rebinding) · tear down
  on session end. Higher review + security surface; use only if adapting the ACP transport proves too invasive.
- **Default: pursue (A); fall back to (B) with the full hardening list if (A) is blocked.** Do NOT ship an unauthenticated
  loopback (the OpenClaw RCE precedent: unauth loopback → credential exfiltration).

---

## 2. ENTITLEMENTS — all already declared in `Epistemos-AppStore.entitlements` [CONSENSUS, 6/6]
| Key | Value | Purpose |
|---|---|---|
| `com.apple.security.app-sandbox` | `true` | Required for MAS (Guideline 2.4.5(i)). |
| `com.apple.security.network.client` | `true` | ALL outbound HTTPS — cloud LLM APIs + remote HTTP MCP. |
| `com.apple.security.files.user-selected.read-write` | `true` | The vault (NSOpenPanel/NSSavePanel picks only). |
| `com.apple.security.files.bookmarks.app-scope` | `true` | Persist vault access across launches (**[OPEN]**: Apple DTS 2025 says often unnecessary for the single-process NSOpenPanel flow — keep it, it's defensible + documents intent). |
| `com.apple.security.cs.allow-jit` | `true` **only if local MLX** | Hardened-runtime JIT. Omit if cloud-only. |
| `com.apple.security.network.server` | **omit / `<false/>`** unless loopback fallback (path B) | Listener; avoid it with transport (A). |
| `com.apple.security.automation.apple-events` | **omit / `<false/>`** | No AppleScript on MAS. |
| `Info.plist: ITSAppUsesNonExemptEncryption` | `<false/>` | Standard HTTPS via URLSession is export-exempt. |

**Security-scoped bookmark lifecycle (non-negotiable):** resolve with `.withSecurityScope`, call
`startAccessingSecurityScopedResource()` **each session**, always balance with `stopAccessingSecurityScopedResource()`
(defer). Stored bookmarks do NOT auto-extend the sandbox. Handle the macOS 15.x `ScopedBookmarksAgent` hang (keychain-lock
race) gracefully — fall back to re-authorization, don't freeze.

---

## 3. FORBIDDEN — Pro-gate these exact `agent_core` tools (this IS the NO-HIDDEN-SIDECAR canon) [CONSENSUS, 6/6]
Barred by **2.5.2** (+ 2.4.5(iii)/(iv)): subprocess spawn · shell/command exec · runtime dependency install (pip/npm/npx/uvx)
· **local stdio MCP servers** · downloaded/executed tool/plugin code · arbitrary filesystem · AppleScript/Apple Events ·
Accessibility. → gate off on MAS: `cli_passthrough`, `terminal`, `registry` bash, `stdio_mcp`, `imessage`, `apple`,
`code_execution`. **Keep on MAS:** vault r/w (security-scoped), **remote HTTP MCP over a FIXED HTTPS allowlist**, cloud
model APIs, in-app caps (PDF→md / search / graph / provenance). Honest "Pro only" gate — never a crash or silent fail.

### ⚠️ EPISTEMOS-SPECIFIC — the Goose WebUI's own extensibility surface must be GATED on MAS [CONSENSUS, high-priority]
This is the sharpest 2.5.2 trap and it's easy to miss: the kept Goose WebUI ships **runtime-extensibility UI** — an
"Extensions / add MCP server" surface, `goose://` **deeplink installers** (one-click install of MCP servers from web
pages), and recipes. **That UI is exactly what 2.5.2 forbids.** On the MAS build you MUST hide/disable: the add-extension
/ add-MCP-server UI, `goose://` deeplink install, any "install from GitHub/URL", and stdio-extension config. MAS shows only
the fixed, in-binary allowlist of remote HTTPS tools. (Reference the iSH "Fixing Section 2.5.2" story: a reviewer used
`wget` to re-download a removed package manager and rejected the app for functionality *they* re-added — 2.5.2 is enforced
aggressively against anything that *looks* runtime-extensible.)

---

## 4. LOCAL MODELS [CONSENSUS, 6/6]
- **In-process MLX-Swift is MAS-legal** (first-party Apple; WWDC25 s298). Model **weights = DATA, not code** → downloading
  them at runtime does NOT violate 2.5.2 (keep the *engine* bundled; treat weights as opaque data; download NO
  interpreters/plugins/executables). Fits the M2 Pro 16 GB / 4-bit-7B budget. Cap MLX cache (`MLX.GPU.set(cacheLimit:)`),
  memory-gate by machine class, support cancel/unload (2.4.2 resource-strain).
- **Apple Foundation Models** (macOS 26+) = cleanest review path, OS-bundled, zero app size — **BUT [CONSENSUS caveat]** a
  hard **~4,096-token combined input+output limit per session** makes it **unsuitable for deep multi-turn agent loops**.
  Use it for bounded sub-tasks, not the main loop.
- ⛔ Do NOT use the WWDC2026 s232 `pip install mlx-lm` + `mlx_lm.server` subprocess recipe — pip + subprocess, both forbidden.
- For MAS, **cloud models are the lightest default** (no download/RAM); MLX is the offline option when green-lit.

---

## 5. RANKED APP-REVIEW RISKS [CONSENSUS ordering, 6/6]
1. **2.5.2 — self-containment (HIGHEST).** Actively enforced 2026 (Apple pulled "Anything"; the iSH story). Goose's
   extensibility DNA is the exact target. **MITIGATION:** hard-code the tool/extension surface; remote MCP = fixed HTTPS
   allowlist; no add-server UI, no `goose://` installer, no user-installable extensions; recipes (if any) are inert data
   that only call already-embedded tools.
2. **5.1.2(i) — third-party-AI consent (HIGH; NEW Nov-2025).** Must disclose + get **explicit permission BEFORE** the first
   byte of prompt/vault data leaves the device, **per provider**. A privacy-policy link is NOT enough. **MITIGATION → NEW
   BUILD ITEM:** an in-app consent gate naming each cloud LLM + each remote MCP endpoint, revocable in Settings; accurate
   App Privacy nutrition labels.
3. **4.2 — minimum functionality (WKWebView "repackaged website" trap).** A webview-first app risks "just a website in a
   shell." **MITIGATION:** make native capabilities unmistakable — native vault picker + persistent security-scoped access,
   native file previews, native streaming UI, provider config, Keychain secrets, native window/menu chrome; document in review notes.
4. **4.7 — chatbots / non-embedded software.** Open-ended AI chat triggers moderation duties (4.7.1: content filtering +
   reporting + block abusive users) and **4.7.2: do NOT expose native APIs to non-embedded/third-party code** (keep the FFI
   bridge serving only *your own* embedded UI). **MITIGATION:** treat the agent as embedded functionality; add
   report/block/filter for open chat.
5. **Loopback friction (only if path B).** Not banned, but adds the entitlement + attack surface. Mitigate per §1(B).
6. **Age rating.** Open-ended AI + web access → conservative rating (17+/high); declare accurately.
7. **2.5.1 — public APIs only (hard gate).** Why `_registerURLSchemeAsSecure:` is off-limits; the recommended transport uses only public APIs.

---

## 6. PRIOR ART — honest read [CONSENSUS, 6/6]
The **primitives** ship on MAS (in-process MLX: Pico AI Server, Local LLM Server; native chat clients: MindMac, BoltAI).
**BUT no confirmed MAS app runs a full in-process multi-step tool-using agent.** Corroborating the rarity:
**Cursor explicitly rejected App Sandbox for agents** ("would require signing every binary an agent might execute… opened
new abuse vectors"); **ChatGPT's macOS app shipped NOT sandboxed**. BoltAI is prior art for the cloud/remote pattern but
its *local* MCP uses stdio launchers (the exact thing to exclude). **Treat BonzAI/OpenCat/On-Device-AI/SmallClaw/Maple and
similar as UNVERIFIED — do NOT cite as precedent** (several may be conflated or local-only). **Takeaway:** optimize for
**reviewer comprehensibility**, not claimed precedent. This absence = the rare moat, confirmed.

### Ready-to-submit App Review notes (adapt at submission)
> "[App] is a self-contained, sandboxed AI assistant. All agent logic and tools are compiled into the app; it does not
> download, install, or execute code at runtime and cannot be extended with user-supplied code or local plug-ins. It makes
> only outgoing HTTPS connections to the cloud AI providers and the fixed set of remote services listed below; it runs no
> local server and opens no listening ports [omit this clause if path B]. It does not spawn subprocesses, run a shell, use
> AppleScript/Apple Events, or use the Accessibility API. The user selects a folder ('vault') via the standard open panel;
> all file access is confined to it via security-scoped bookmarks. Before any user content is transmitted, an in-app
> consent screen names each third-party AI provider [list] and remote service [list]; users can review/revoke in Settings;
> privacy policy [URL]. The UI is WKWebView; native capabilities beyond a website include folder selection with persistent
> security-scoped access, local previews, native streaming, provider config, and Keychain credential storage. Standard
> HTTPS only (ITSAppUsesNonExemptEncryption=false). Open-ended chat includes filtering and a report/block mechanism."

---

## 7. IF you ever route to BLOCK'S Goose Rust core (Epistemos routes to `agent_core` instead) [reference]
Epistemos's MAS path uses **`agent_core`** (your own in-process Rust runtime) — so §3's tool-gating is the operative list.
But if the Goose Rust core is ever embedded directly, the synthesis verified: embed the **`goose` core crate** (the
`Agent` + `reply()` → stream of `AgentEvent`), **exclude `goose-server`/`goosed` entirely**; compile out `developer`
(shell), `computercontroller` (osascript), stdio extensions, the `goose://` installer, sub-recipe CLI spawns, CLI
self-update; keep the Agent loop + cloud providers + **remote (Sse/StreamableHttp) MCP only** + in-process builtin tools
that run over in-memory `tokio::io::duplex` (async tasks, NOT subprocesses = safe) + Keychain (`keyring` apple-native).
**Pin + vendor a specific commit** (upstream is migrating to client/server `goose serve` + ACP + Tauri, which erodes the
in-process ergonomics). `crates.io/goose` is a DIFFERENT project — consume via git/path by SHA. No built-in FFI — write the
`extern "C"` shim yourself (`catch_unwind` at the boundary; UTF-8 JSON C-strings).

---

## 8. GENUINE OPEN QUESTIONS (Apple is silent — do not over-promise) [OPEN]
- **Remote HTTP-MCP under 2.5.2:** a *fixed, in-binary* HTTPS-allowlisted remote MCP is defensible as data/tool I/O; a
  *dynamically discovered / add-server* surface risks being read as "functionality change." → allowlist in the binary, no add-server UI.
- **Accessibility in the sandbox:** no clean entitlement path + 2025-26 forum reports of trust-prompt failure → keep it OUT of MAS (you already do).
- **Downloaded LLM weights = data not code:** strong inference + shipping precedent, but Apple has published no explicit
  sentence blessing it → state it in review notes ("model parameter files consumed by the built-in engine; no executables/scripts/plugins").
- **`bookmarks.app-scope` necessity** for the single-process flow (DTS says often no-op) → keep it; test on target OS.

---

## CONVERGENCE LEDGER (why this is robust, not one opinion)
| Decision | Internal DR | Gemini-1 | Gemini-2 | GPT-1 | GPT-2 | Goose-synth |
|---|---|---|---|---|---|---|
| Native WebKit bridge over loopback | ✓(scheme) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Msg-handler(control)+JS-push(stream), scheme=resource-only | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Entitlement set (client + user-selected + bookmarks; omit server) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2.5.2 = #1 risk; gate subprocess/shell/stdio-MCP/downloaded-code | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 5.1.2(i) explicit consent before third-party-AI send | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| In-process MLX legal; weights=data; FMF 4k-token limit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No confirmed full-agent MAS precedent (rare moat) | ✓ | ~ | ~ | ✓ | ✓ | ✓ |
| Gate Goose WebUI's add-extension/deeplink surface | — | — | — | — | — | ✓ (unique, critical) |

**The consensus that matters, in one line:** *WebKit message-bridge (no loopback) · the entitlements you already have ·
hard-code the tool surface + hide Goose's extensibility UI (2.5.2) · consent-gate before any cloud send (5.1.2(i)) ·
cloud-first with in-process MLX optional · prove it in a sandboxed build · optimize review notes for comprehensibility.*
