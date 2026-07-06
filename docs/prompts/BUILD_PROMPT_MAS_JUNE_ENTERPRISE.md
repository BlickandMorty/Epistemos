# Build Prompt — MAS "June" Agent Surface: Deep Audit, Connect, and Harden to Enterprise Grade

**Read this whole file before touching anything. This is the parallel track to the 1Code Experimental
build — you own the MAS June surface; do not touch `Epistemos/ExperimentalAgent/**` or the 1Code fork.**

This surface already exists (`Epistemos/JuneAgent/**`, ~2,773 lines, MAS-sandboxed). Your job is **not**
to rebuild it. It is to (A) **deeply research your own code** and map every seam, (B) **connect the
disconnected parts** so it becomes genuinely agentic and useful — not just a chat box, and (C) **harden
it to the deepest enterprise grade in the codebase.** The canonical plan you extend (do not contradict)
is `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md` — read it in full first.

## THE ONE RULE (why past passes fell short)
**"Build green" is not done, and "it compiles" is not "it works."** Done is defined only by the DoD
below — each verified in the **running MAS (sandboxed) build** with a real end-to-end task, plus a
hardening report with zero open HIGHs and **zero regressions against the test suite**. Do not declare
done on plumbing, do not stop while any DoD is unmet, and do not fake capability to close a row.

## §0 MAS NON-NEGOTIABLES (absolute — these are the enterprise spine, not suggestions)
From the project canon (`CLAUDE.md`). A violation is a HIGH that blocks the commit:
1. **In-process ONLY. NO hidden sidecar, NO subprocess.** The engine is `agent_core` via Rust FFI +
   MLX/llama.cpp/Apple Foundation Models in-process. The legacy agent subprocess was removed — never
   reintroduce one. (This is the hard line the whole MAS lane exists to honor.)
2. **HONEST CAPABILITY GATING.** Local models = chat/fast/thinking tier — **never advertise or fake
   function-calling/agentic tools on a local model.** Cloud = full agentic (agent/liveAgent). `June`'s
   `modelSupportsTools` gate is the truth boundary — keep it honest. Absent capability is *absent*,
   with one honest "bounded on MAS" note, never a dead button.
3. **PRESERVE THINKING BLOCKS.** When `stop_reason == "tool_use"`, pass the ENTIRE content array back
   including thinking blocks + signatures. Dropping them kills the agent.
4. **STREAM EVERYTHING.** Forward every token/delta to the UI immediately. No buffering. `AsyncStream`
   uses `.bufferingNewest(256)`, never `.unbounded`.
5. **AGENT DECIDES TERMINATION.** `max_turns` is a safety rail, not a schedule. Trust `end_turn`.
6. **Keychain for all secrets** (SecItem…), NEVER UserDefaults. Secrets never enter webview JS.
7. **UniFFI callbacks: `DispatchQueue.main.async`, NEVER `.sync`** (deadlock). All inference on
   background actors — never block `@MainActor`. `@Observable` not `ObservableObject`. No `try!`, no
   force-unwraps, no `print()` in production paths; every `unsafe` block gets a `// SAFETY:` comment.
8. **MAS sandbox law.** Sandboxed + App Store entitlements only. Vault access via **security-scoped
   bookmarks**. MCP is **HTTP over a fixed HTTPS allowlist — NEVER stdio.** **Forbidden tools
   (Pro-only, must be absent on MAS):** `cli_passthrough`, `terminal`, bash `registry`, `stdio_mcp`,
   `imessage`, `apple`/osascript, `code_execution`, schedule/extension-installer UIs. Cloud calls go
   through the **receipt-gated proxy** with a short-lived, rotated Keychain bearer token.
9. **Zero test regressions.** `swift test` + `cargo test --manifest-path agent_core/Cargo.toml` stay green.

## §1 The real June architecture (grounded — verify each before you change it)
- **Surface:** `JuneAgentSurfaceView.swift` (847) — WKWebView host + theme injection + eager-webview
  instant-open + placeholder. Serves the vendored June SPA via `JuneSchemeHandler.swift` (custom
  scheme). Native chrome: `JuneAgentChrome.swift` (all-chats, menu-bar, side-features),
  `JuneAgentNavBar.swift`.
- **Bridge:** `JuneAgentBridge.swift` (371) — `WKScriptMessageHandler`; the `epistemosGateway`
  JSON-RPC channel + the Tauri shim (`window.__EPISTEMOS_TAURI_SHIM__` / `window.__TAURI__` polyfill).
- **Engine lane:** `JuneAgentGateway.swift` (884) — the in-process gateway. Resolves per conversation:
  **local** (`AppleFMQuickChatBackend` macOS 26+, `LocalGGUFQuickChatBackend`/`LocalChatEngine`
  llama.cpp — chat tier) and **cloud** (`JuneCloudEngine.swift`, provider stack). Durable session
  store (`store.allSessions`, `autoTitleIfPlaceholder`, persisted).
- **Everything is `#if EPISTEMOS_APP_STORE`.** Build/verify under the `Epistemos-AppStore` scheme.

## PHASE A — DEEP SELF-RESEARCH: the connection audit (the "research its own code" deliverable)
Produce `docs/research/JUNE_MAS_CONNECTION_AUDIT.md` — a 7-layer audit that maps the surface honestly.
Use deep, systematic reading of the actual code (and web-verify any current-API assumptions:
FoundationModels availability, StoreKit 2 receipt validation, security-scoped bookmark lifecycle,
WKWebView sandbox behavior). For EVERY seam below, state: what it's *supposed* to do (per the plan),
what it *actually* does (file:line), and the **verdict — CONNECTED / HALF-WIRED / DISCONNECTED / DEAD**:
1. **June SPA → bridge** (the 13 invokes + the Hermes/Tauri client): which UI calls are serviced, which
   hit an honest no-op, which silently drop.
2. **Bridge → gateway → engine**: the `session/new · prompt · stream · abort` path end to end.
3. **⭐ The cloud agentic loop** — THE prime suspect. Does the cloud lane run the full `agent_core`
   `runAgentSession` + `AgentEventDelegate` (`on_text_delta`/`on_thinking_delta`/`on_tool_started`/
   `on_permission_required`), or only **direct chat turns** (`directCloudProviders`/
   `directCloudInstructions`)? If the latter, June is a chat box, not an agent — that is the #1
   disconnected part to fix in Phase B.
4. **The MAS tool catalog** (plan §4): are vault I/O (security-scoped), PDF→md, search/graph/provenance,
   and the HTTP-MCP allowlist actually reachable by the agent, or defined-but-unwired?
5. **Capability truth**: local vs cloud gating, `modelSupportsTools`, the picker/composer chip.
6. **Session store + history**: durability, crash-safety, thinking-block round-trip, all-chats parity.
7. **Paywall/proxy + Keychain**: receipt gate, token rotation, cloud-not-configured handling.
Also flag: orphaned code (built, never called), placeholders (`autoTitleIfPlaceholder`, mascot presence,
Plan-5 stubs), and any `#if EPISTEMOS_APP_STORE` path that can't actually run under the sandbox.
**Commit the audit before Phase B.** This is DoD-1.

## PHASE B — CONNECT the disconnected parts (make it truly useful, honestly)
Wire what the audit found broken, in priority order. The through-line: **June's cloud lane must be a
real agent**, and the agent must be able to *do things with the user's vault* — not just chat.
1. **Wire the full `agent_core` agentic loop into the cloud lane** (plan §3): `session/new·prompt·
   stream·abort` → `runAgentSession` + `AgentEventDelegate` deltas, translated to June's event shape.
   Stream text AND thinking deltas; surface tool-started; route `on_permission_required` to June's
   approval UI (dry-run → confirm). Preserve thinking blocks across tool_use turns (§0.3).
2. **Connect the MAS tool catalog** (plan §4) to that loop — vault read/write/search (security-scoped
   bookmarks), PDF→md, search/graph/provenance, and HTTP-MCP over the HTTPS allowlist. The vault MCP
   (`omega_mcp_stdio`'s MAS-legal HTTP equivalent — **never stdio on MAS**) so the agent can search and
   cite the user's notes. Verify with a real task: "find and summarize my notes on X, then write a new
   note" — end to end, in the sandboxed build.
3. **Keep local honest** (§0.2): local stays chat-tier; do not wire tools into local; the picker shows
   the honest capability per lane. If cloud isn't configured, the honest `cloudNotConfigured` message
   guides to Settings — never a silent failure or a faked answer.
4. **Close the orphans/placeholders** the audit found: either wire them or remove them (dead code is a
   liability in an enterprise build) — each decision noted.
This is DoD-2 + DoD-3.

## PHASE C — DEEPEST HARDENING (the enterprise differentiator — a named deliverable, per-lens)
Run the four hardening lenses over everything Phase B touched, reported in the thermonuclear shape
(`N HIGH / N MED / N LOW`, file:line, FIXED/DEFERRED). A HIGH blocks the commit. Read-first the
doctrines the plan names (`AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`,
`AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`).
- **Security / data-leak:** sandbox entitlements are the minimal set; vault access only via
  security-scoped bookmarks (start/stop-accessing balanced, persisted, revalidated); CSP locks the
  webview to the custom scheme + the HTTPS MCP allowlist + the proxy — nothing else; secrets in Keychain
  only, never in JS, logs, or UserDefaults; every `WKScriptMessageHandler` payload shape+length
  validated; the proxy bearer token short-lived + rotated; no forbidden tool reachable (§0.8).
- **Memory-leak / energy:** WKWebView teardown (handlers, observers, process pool), non-persistent data
  store, keep-webview-alive-across-tab-switch without leaking; local model RAM-gate at launch (refuse
  oversized loads gracefully, never swap/crash); `AsyncStream` bounded; no retain cycles in the gateway
  delegate closures; idle unload of the local engine.
- **Robustness / crash-safety:** the session store survives a mid-write crash (transactional /
  checkpointed); runaway-guard on a stuck local loop or hostile cloud stream (already partially present
  — `:284`, `:447` — make it complete); every FFI boundary is honest-handle + versioned; UniFFI
  callbacks `.async` never `.sync`; no `try!`/force-unwrap/`print()` in production paths; graceful
  degradation when FoundationModels is unavailable (→ GGUF → honest message).
- **Perf gate:** instant-open preserved (eager webview + placeholder, off-main spawn, alive across
  tabs); first-token + cold-open within the `[agent_surface]`/June budgets in `docs/perf-budgets.toml`.
This is DoD-4.

## DEFINITION OF DONE (all five — verified in the running MAS build, not a compile)
- **DoD-1** — `JUNE_MAS_CONNECTION_AUDIT.md` committed: every seam mapped, every disconnected/orphaned
  part listed file:line with a CONNECTED/HALF-WIRED/DISCONNECTED/DEAD verdict.
- **DoD-2** — June's cloud lane is a **real agent**: a task that requires tools + the vault runs end to
  end (streamed text + thinking, a tool call, a permission prompt, a vault read/write) in the sandboxed
  build. Screenshot/transcript proof.
- **DoD-3** — Capability truth intact: local = chat (no faked tools), cloud = agentic; the picker/gating
  is honest; `cloudNotConfigured` guides, never fails silently.
- **DoD-4** — Hardening report across the four lenses with **zero open HIGHs**; all §0 non-negotiables
  verified (grep/proof for: no subprocess, thinking-blocks preserved, streaming bounded, Keychain-only
  secrets, no `.sync` UniFFI, no forbidden tools, security-scoped vault, minimal entitlements).
- **DoD-5** — **Zero test regressions** (`swift test` + `cargo test`), build green under the App Store
  scheme, and the end-to-end task from DoD-2 demonstrably works.

## EXECUTION RULES (do not violate)
1. **Research-first, always** (project canon): before editing a subsystem, read its canonical source +
   the plan section; verify current code/logs; web-verify any current-OS/API/StoreKit fact. Do not
   pattern-match from memory.
2. Phase A → B → C, in order. **Commit after every coherent change** (build green, App Store scheme,
   `CODE_SIGNING_ALLOWED=NO` for headless compile checks). Never two `xcodebuild`s at once (16 GB).
3. **Verify in the RUNNING sandboxed build**, not just a green compile. A compile is not evidence of a
   connected feature.
4. **Do not stop, do not report done, do not idle on "nothing left" while any DoD is unmet.** If a
   scheduled/loop wrapper drives you with an older prompt, this file supersedes it.
5. Never fake capability to close a row (§0.2). Never reintroduce a subprocess (§0.1). Report honestly —
   no "done" without the DoD proof.
6. Rails: you own `Epistemos/JuneAgent/**` + the MAS engine lane; **do not touch the 1Code Experimental
   surface** (the other agent owns it) or unrelated lanes; never `git add -A`; commit narrowly.

**Definition of success, restated:** a MAS user opens June and it is a genuinely useful, deeply
integrated agent — it streams thinking, uses tools against their vault, honestly says what it can't do
on-device, and is the most hardened surface in the app — not a chat box wired to a web view.
