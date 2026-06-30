# Goose on the Mac App Store — in-process backend readiness spec (2026-06-30)

> **The plan to ship Goose on MAS:** keep the reskinned Goose WebUI; swap the `goose serve` *subprocess* for an
> **in-process ACP backend over `agent_core`** (Rust, via FFI), behind `EPISTEMOS_APP_STORE`. **DEFERRED + OWNER-GATED —
> do this ONLY after ALL the visible Goose work (reskin + features) is done and good.** Deep-research run
> `wf_7d57fe20-003` is validating the transport + App-Review risk; its findings fold into §6 on completion.

## Why this is achievable — the foundation already exists (verified 2026-06-30)
- **MAS entitlements already declared** (`Epistemos/Epistemos-AppStore.entitlements`): `app-sandbox` · `cs.allow-jit` (for MLX) · `files.bookmarks.app-scope` + `files.user-selected.read-write` (vault via security-scoped bookmarks) · `network.client` (cloud APIs + HTTP MCP) · **`network.server` (the in-app loopback ACP)**. ✅
- **`agent_core` is a mature in-process Rust runtime** — 758 lib tests; owns the agentic loop, streaming, tool execution, sessions, memory, security, prompt caching, compaction — with a **UniFFI bridge** (`agent_core/src/bridge.rs`: `#[uniffi::export]` + a `callback_interface` for streaming). ✅
- **The loopback-server pattern is proven** — `WorkSPAServer` (an in-app `NWListener` loopback) already serves the Goose WebUI today. ✅
- **The gate exists** — `GooseRuntimeSupervisor` `#if EPISTEMOS_APP_STORE` (`:179`, `:253`); the subprocess is excluded on MAS (`:403`). It just needs **re-wiring** from "unavailable" → in-process. ✅

So MAS ≠ from-scratch. The engine, the entitlements, the loopback pattern, and the gate are here. The MAS work is the **ACP adapter + the tool-boundary split + the gate flip.**

## The architecture — ONE WebUI, TWO backends behind `EPISTEMOS_APP_STORE`
- **Pro / Developer-ID:** Goose WebUI → `goose serve` subprocess → full autonomy (shell, install, local stdio MCP). Works today.
- **MAS / App Store:** Goose WebUI → **in-app loopback ACP endpoint** (Swift `NWListener`, the `WorkSPAServer` pattern) → Swift **FFI** → **`agent_core`** (Rust, in-process). Bounded, sandbox-legal toolset + honest "Pro only" gate. **No subprocess.**

## Build order — the deferred MAS workstream (do LAST, in this order)
1. **ACP adapter.** Make `agent_core` (via FFI) answer the ACP the WebUI expects: `initialize`, `session/new`, `prompt`, streaming chunks, `permission`/`tool-result`, and the `_goose/unstable/*` methods (providers / models / settings). The loop exists — this is the *translation layer* from agent_core ↔ Goose-ACP.
2. **In-process transport.** Stand up an **in-app loopback ACP server** (reuse the `WorkSPAServer` `NWListener` pattern — `network.server` entitlement is already declared) that bridges WebUI ACP ↔ `agent_core` FFI. **No subprocess.** *(Transport decision — loopback-server vs `WKScriptMessageHandler`/`WKURLSchemeHandler` bridge — is pending research §6.)*
3. **Tool-boundary split (the critical MAS gate).** Pro-gate the sandbox-illegal `agent_core` tools: `cli_passthrough`, `terminal`, the bash in `registry`, `stdio_mcp`, `imessage`, `apple` (osascript), `code_execution`. **Keep on MAS:** vault read/write (security-scoped bookmarks), HTTP MCP, cloud model APIs, in-app caps (PDF→md / search / graph / provenance). Honest "Pro only" message — never a crash or silent fail.
4. **Flip the gate.** Re-wire `GooseRuntimeSupervisor`'s `#if EPISTEMOS_APP_STORE` branch from `status = .unavailable(...)` → route the WebUI to the in-process `agent_core` ACP.
5. **Models on MAS.** Cloud APIs (sandbox-legal; keys already in Keychain) and/or local **MLX** in-process (`cs.allow-jit` already declared). Decide the MAS default (cloud is lightest; MLX is heavier but offline).
6. **Parity decision (GOLDEN RULE).** Either `agent_core` exposes the full catalog the WebUI shows (providers/models/skills), OR ship **honest bounded-parity** (fewer options on MAS). Decide it; never fake it.
7. **Third-party-AI consent — REQUIRED (Guideline 5.1.2(i), NEW Nov-2025; surfaced by §6 research).** Before any cloud-model call sends vault/personal data off-device, show a clear disclosure and get **explicit user permission** — App Review now mandates this for "third-party AI." Plus declare `ITSAppUsesNonExemptEncryption` + App Privacy nutrition labels at submission. *(This is the one genuinely new build item the research added — don't skip it.)*

> **TRANSPORT NOTE (§6 result):** for step 2, **prefer `WKURLSchemeHandler`** (in-process, no socket, no `network.server` entitlement, lowest attack surface) over the loopback `NWListener` for the ACP transport — the loopback is the proven-shipping alternative if you need the HTTP/WS shape.

## The "truly good" loop rules (non-negotiable — these are why a previous loop "didn't work at all")
- **Preserve thinking blocks + signatures** — on `tool_use`, pass the *entire* content array back (dropping them kills the agent).
- **Stream every token immediately** — no buffering.
- **Agent decides termination** — trust `stop_reason == end_turn`; `max_turns` is a safety rail.
- **FFI threading** — `DispatchQueue.main.async` in UniFFI callbacks, **never** `.sync` (deadlock).

## PROOF BAR — how you KNOW it's truly good (not "it compiles")
Cold-launch a **MAS-configured, sandboxed** build (`EPISTEMOS_APP_STORE` on) and prove the real path:
> Goose WebUI loads → connects to **in-process `agent_core`** — **confirm there is NO `goose serve` process and port 3284 is dead** → new session → prompt → stream (thinking + answer + a *real sandbox-legal* tool call, e.g. `vault.search` or an HTTP MCP) → permission → result → `end_turn`.

Plus: prove a **sandbox-illegal** tool (e.g. `terminal`) shows the **honest "Pro only" gate**, not a crash or silent fall-through. Witness it with a re-runnable artifact. **Re-verify in a real sandboxed/notarized build**, not just a Debug build (Debug is non-sandboxed and will lie to you).

## §6 — RESEARCH FINDINGS (deep-research `wf_7d57fe20-003`, COMPLETE — 24/25 claims verified, mostly 3-0)

**VERDICT: a bounded, genuinely useful in-process agent CAN ship on the Mac App Store.** Real prior art proves the
primitives — **Pico AI Server** and **Local LLM Server** both ship on MAS running in-process MLX inference + an in-app
local server. The architecture below is assembled from individually-verified Apple primitives.

### Architecture recommendation — TRANSPORT
- **PREFERRED: `WKURLSchemeHandler`.** The official WebKit protocol for custom (non-`http/https`) schemes, registered via
  `setURLSchemeHandler(_:forURLScheme:)` on the `WKWebViewConfiguration` *before* the WebView is created. A **pure
  in-process bridge — NO socket, NO `network.server` entitlement, lowest attack surface.** The WebView's ACP requests hand
  straight to native code (→ FFI → `agent_core`) as `WKURLSchemeTask` callbacks. *(primary: developer.apple.com/documentation/webkit/wkurlschemehandler)*
- **PROVEN ALTERNATIVE: in-app loopback `NWListener`** (HTTP/WS on 127.0.0.1, needs `network.server`). Demonstrably ships
  on MAS (Local LLM Server, Pico AI Server). You already have the `WorkSPAServer` loopback + the entitlement — but for the
  ACP transport, **lean `WKURLSchemeHandler`** (cleaner, no server, smaller attack surface).

### Entitlements checklist — ALL already declared in `Epistemos-AppStore.entitlements` ✅
- `com.apple.security.app-sandbox` (required) · `com.apple.security.network.client` (ALL outgoing HTTPS — cloud LLM +
  HTTP-MCP; without it URLSession + WKWebView are blocked) · `com.apple.security.files.user-selected.read-write` (vault,
  granted only for NSOpenPanel/NSSavePanel picks) · `com.apple.security.files.bookmarks.app-scope` + a **security-scoped
  bookmark** (`.withSecurityScope`) for cross-launch vault access — **must `startAccessingSecurityScopedResource()` each
  session** (stored bookmarks don't auto-extend the sandbox) · `com.apple.security.cs.allow-jit` (in-process MLX) ·
  `com.apple.security.network.server` (ONLY if loopback transport).

### Forbidden — must be Pro-gated (this IS the project's NO-HIDDEN-SIDECAR canon, confirmed by Apple)
Barred by **Guideline 2.5.2** (apps self-contained; may NOT download/install/execute code that changes features, nor
read/write outside the container): **subprocess spawn · shell/command exec · pip/npm install · local stdio MCP servers ·
downloaded tool/plugin code.** `files.user-selected.*` grants DATA access, NOT execute. Apple-events/AppleScript, global
Mach lookup, absolute-path access exist only as **review-gated temporary exceptions** that are rejection-prone. → exactly
the `agent_core` tools to gate: `cli_passthrough`, `terminal`, `registry` bash, `stdio_mcp`, `imessage`, `apple`, `code_execution`.

### Local models on MAS
- **In-process MLX-Swift is MAS-legal** — first-party Apple (ml-explore); WWDC25 session 298 shows a 28-line load+generate
  for 4-bit Mistral 7B, in-process, no cloud. **Pico AI Server proves it ships on MAS.** Model **weights are DATA, not
  code**, so downloading them at runtime does NOT violate 2.5.2. (Fits the M2 Pro 16 GB / 4-bit-7B budget.)
- Also viable: **Apple Foundation Models** (macOS 26+) — OS-bundled, zero app-size cost.
- ⛔ Do NOT use the WWDC2026 session-232 `pip install mlx-lm` + `mlx_lm.server` subprocess recipe — pip + subprocess, both
  forbidden. Use the native in-process MLX-Swift path.

### Ranked App-Review risks
1. **Guideline 2.5.2 — self-containment (HIGHEST).** Apple is actively enforcing it in 2026 (pulled the "Anything"
   vibe-coding app, 2026-03-30). MITIGATION: you already honor this (no-sidecar, all logic bundled) — keep it. **OPEN
   line to watch:** does App Review treat a *remote HTTP-MCP* tool call as data/network I/O (fine) or as "downloading code
   that changes functionality" (2.5.2 risk)? Lean conservative — frame remote MCP as tool/data I/O, never plugin loading.
2. **Guideline 5.1.2(i) — third-party-AI consent (HIGH; NEW Nov-2025 rule).** You must clearly disclose AND get **explicit
   user permission BEFORE** sending personal/vault data to a third-party AI (your cloud model provider is exactly this).
   MITIGATION → **NEW BUILD ITEM:** a clear consent + disclosure UI gating any cloud call.
3. **Export compliance + privacy labels (MEDIUM; submission-time).** `ITSAppUsesNonExemptEncryption` in Info.plist (covers
   linked third-party libs) + App Privacy nutrition labels for data sent to model providers. Declare at submission.

### Honest caveats
- Prior art proves the **primitives** (in-process MLX + in-app server ship on MAS) but **no confirmed MAS app ships a FULL
  multi-step tool-using agentic loop** yet — you'd be assembling verified primitives, likely a first (consistent with the
  rare-moat thesis).
- Entitlement-existing ≠ review-accepted (temporary exceptions are rejection-prone — don't rely on them).
- Recency: WWDC2026, macOS 26, and the 5.1.2(i) rule are 2025-2026 and enforcement is tightening — **re-check the
  guidelines at submission time.**

### Open questions to resolve before submission
- Does App Review treat a remote HTTP-MCP tool surface as data I/O or as forbidden downloaded-code under 2.5.2?
- Measured perf/security tradeoff: `WKURLSchemeHandler` bridge vs loopback `NWListener` for streaming tokens at scale?
- Any confirmed shipping MAS in-process *multi-step agent* + what its plist declares?

### Primary sources
WKURLSchemeHandler docs · App Sandbox Entitlement Key Reference · accessing-files-from-the-macos-app-sandbox · App Review
Guidelines (2.5.2, 5.1.2(i)) · WWDC25 s298 (MLX) · ITSAppUsesNonExemptEncryption · Pico AI Server + Local LLM Server (MAS
prior art) · 9to5Mac 2026-03-30 (2.5.2 enforcement).
