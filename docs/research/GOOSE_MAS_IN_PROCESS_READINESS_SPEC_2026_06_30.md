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

## The "truly good" loop rules (non-negotiable — these are why a previous loop "didn't work at all")
- **Preserve thinking blocks + signatures** — on `tool_use`, pass the *entire* content array back (dropping them kills the agent).
- **Stream every token immediately** — no buffering.
- **Agent decides termination** — trust `stop_reason == end_turn`; `max_turns` is a safety rail.
- **FFI threading** — `DispatchQueue.main.async` in UniFFI callbacks, **never** `.sync` (deadlock).

## PROOF BAR — how you KNOW it's truly good (not "it compiles")
Cold-launch a **MAS-configured, sandboxed** build (`EPISTEMOS_APP_STORE` on) and prove the real path:
> Goose WebUI loads → connects to **in-process `agent_core`** — **confirm there is NO `goose serve` process and port 3284 is dead** → new session → prompt → stream (thinking + answer + a *real sandbox-legal* tool call, e.g. `vault.search` or an HTTP MCP) → permission → result → `end_turn`.

Plus: prove a **sandbox-illegal** tool (e.g. `terminal`) shows the **honest "Pro only" gate**, not a crash or silent fall-through. Witness it with a re-runnable artifact. **Re-verify in a real sandboxed/notarized build**, not just a Debug build (Debug is non-sandboxed and will lie to you).

## §6 — DEEP-RESEARCH FINDINGS (pending `wf_7d57fe20-003`; fold in on completion)
To be filled from the cited research report:
- **Transport** — loopback `NWListener` (HTTP/WS, `network.server`) **vs** `WKScriptMessageHandler` / `WKURLSchemeHandler` bridge: which App Review accepts, security/perf tradeoffs, whether an in-app localhost server is clean for MAS.
- **App Review risk** — Guidelines **2.5.2** (self-contained, no downloading/executing code — critical for the agent + any model/tool fetching), 4.7, **ITSAppUsesNonExemptEncryption**/export compliance, privacy **nutrition labels** for sending data to model providers, age rating.
- **MLX** in a sandboxed notarized app — model download/size/RAM constraints on Apple Silicon.
- **Prior art** — any shipping MAS apps with a *real* in-process agent + how they architect it.

*(This section is the whole point of researching before building — so when MAS is green-lit, the transport + review path is already de-risked.)*
