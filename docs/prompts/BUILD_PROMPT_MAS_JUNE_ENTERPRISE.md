# Build Prompt — MAS "June" Agent Surface: Deep Audit, Connect, and Harden to Enterprise Grade

**Read this whole file before touching anything. This is the parallel track to the 1Code Experimental
build — you own the MAS June surface; do not touch `Epistemos/ExperimentalAgent/**` or the 1Code fork.**

This surface already exists (`Epistemos/JuneAgent/**`, ~2,773 lines, MAS-sandboxed). Your job is **not**
to rebuild it. It is to (A) **deeply research your own code** and map every seam, (B) **connect the
disconnected parts** so it becomes genuinely agentic and useful — not just a chat box, and (C) **harden
it to the deepest enterprise grade in the codebase.** The canonical plan you extend (do not contradict)
is `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md` — read it in full first.

**This is a FOREVER LOOP.** It does not finish — it compounds. Every cycle you scout the deepest
frontier, forge it, temper it, and **crystallize the breakthrough into a new reusable skill**, then
raise your own bar. Phases A–C below are **Cycle 1**. Then you loop, forever, godlier each turn — see §∞.

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

## §1.5 THE THESIS — June's unfair advantage (internalize it; this is why you can beat them)
Every cloud agent app — Codex, the Claude Desktop app, Cursor, opencode — sends the user's work to a
server and remembers nothing of *who they are*. June is different in kind on **two axes at once**: it
runs **fully on-device** (Apple Foundation Models / embedded llama.cpp, in-process, no subprocess —
nothing leaves the Mac on the local lane) AND it lives **inside the user's knowledge substrate** (the
vault, the graph, the provenance ledger). No frontier app is both private-by-architecture and
embedded-in-a-second-brain. That is June's structural moat: a **trustworthy, on-device, vault-native
agent** that reasons over the user's own knowledge, cites it, writes back to it with provenance, and
remembers across sessions — without a byte leaving the machine unless the user chooses the paid cloud
lane. The mandate is not to imitate Codex; it is to build the agent Codex *cannot* be: private, local,
and one with the vault. You are judged on: **(1) depth of embedding** (features only a vault-native agent
can have), **(2) on-device excellence** (local-lane quality that rivals cloud), **(3) hardening & trust**
(the deepest tier — private, auditable, crash-safe, sandbox-pure).

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

## §∞ THE FOREVER LOOP — the self-evolving engine (this is the heart; it never ends)
June is not a project with an end state, and it is NOT a skill-collecting exercise. It is a **loop of
profound BUILDS** — real features and deep connections shipped into the running app every cycle — where
**skills are the compounding leverage you USE to build, never trophies you collect.** Each cycle both
*stands on* the skills forged before it and *leaves behind* one more, so June gets deeper AND each build
gets faster and more profound than the last. Phases A–C above are **Cycle 1**. Then you loop — forever —
each cycle a deeper build, standing on every skill before it. Five movements per cycle:

1. **SCOUT — find the highest-leverage frontier.** Re-scan your own code, the field (how cloud agent
   apps work — and what they can't do on-device / in a vault), and the substrate (vault / graph /
   provenance / on-device models). Ask: *what single integration, built this cycle, would most make the
   frontier apps look like demos — using June's private, on-device, vault-native moat?* Web-verify
   (current FoundationModels / StoreKit / sandbox facts). Name the crux. One frontier per cycle — the
   deepest, not the easiest. Never at the cost of a §0 non-negotiable.
2. **FORGE — build it deeply, by COMPOSING your skills.** Implement to enterprise depth, wired into the
   substrate, connected as far as the sandbox architecture theoretically allows — and **actively invoke
   your accumulated skills to do it** (chain them; reuse prior breakthroughs, don't re-derive them). The
   library is your leverage: if a skill applies, USE it. In-process only; honest capability always.
   **The deliverable is the shipped, working build — not the skill.**
3. **TEMPER — harden + thermonuclear review.** The four lenses + the deepest `/code-review` you can
   invoke. Zero open HIGH. **Zero test regressions** (`swift test` + `cargo test`). Verified in the
   running sandboxed build, not a compile.
4. **CRYSTALLIZE — forge a skill (the compounding step; NEVER skip it).** Distill the cycle's
   breakthrough into a NEW, reusable `SKILL.md` under `.claude/skills/june-<slug>/` — a named,
   described, invocable capability **plus the methodology to reproduce that whole CLASS of integration**.
   Where the breakthrough is a user-facing, MAS-legal agent capability, ALSO write the product skill the
   in-process engine can invoke (SKILL.md format, `~/.claude/skills`) — respecting the tool allowlist
   (§0.8). Update `.claude/skills/JUNE_SKILLS_INDEX.md`. **The skill must capture a genuinely reusable
   CLASS you WILL invoke in later cycles — not a one-off changelog.** A cycle that ships a build but
   leaves behind nothing reusable has under-compounded; a "skill" no future cycle ever uses is dead
   weight to merge or prune, never a trophy. This is how June gets godlier each loop instead of merely
   bigger — each skill makes the next cycle's build cheaper and deeper.
5. **ASCEND — raise your own bar.** In the cycle log, record what this cycle made possible and — harder
   — *what it now makes possible next*. Define the next cycle's bar ABOVE this one's. Commit. Loop.

**Invariants across all cycles (never violated):** **from Cycle 2 on, every cycle USES ≥1 prior skill to
build the new frontier — a cycle that ignores the library has failed to compound.** Skills exist to
BUILD, not to collect: any skill no later cycle invokes is reviewed, merged, or pruned (no trophy
skills). Strictly additive (never regress a prior feature or skill); honest capability (never fake tools
on local); every §0 non-negotiable holds every cycle; the skill library is sacred — only extended, never
broken; verify in the running MAS build every cycle. By cycle N, June is the most trustworthy, most
vault-native agent in existence — *because* each build stood on the last — and `.claude/skills/june-*`
reads like a grimoire of profound, load-bearing on-device integrations no cloud app can match.

## DEFINITION OF DONE — per cycle (verified in the running MAS build, not a compile)
- **DoD-∞** — Every cycle SHIPS a profound build (a real feature + deep connection, live in the running
  MAS build), USES ≥1 prior skill to build it (from Cycle 2 on), and forges a new *reusable* skill +
  updates the index + raises the bar. The build is the deliverable; the skill is the leverage — never
  skills for their own sake, never a build that ignores the library.
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
