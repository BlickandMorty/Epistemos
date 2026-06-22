# OpenCode vs Goose — the WORK-mode ENGINE head-to-head (2026-06-21)

**Owner question (verbatim intent):** the WORK-mode **engine** is undecided. Be SMART:
maintain PERFORMANCE, KEEP ALL BENEFITS (lose no capability), and weigh that **Goose is
Rust** (generally more robust, links into `agent_core`) vs **OpenCode is TypeScript/Bun**
(bundled runtime). Decide engine = OpenCode, Goose, or a specific hybrid.

**SCOPE NOTE — what is and isn't being re-opened.** The addendum already RESOLVED + SET-IN-
STONE that **WORK keeps OpenCode's REAL terminal UI** (`OSAURUS_P3_IMPORT_PLAN_2026_06_21_
addendum.md:170-198, 449-454`). That UI decision is the authority and is NOT reconsidered
here. What this doc decides is the layer *underneath* the terminal UI — **which agent-loop
ENGINE actually runs the work** (drives providers, tools, the ReAct loop, compaction,
subagents, retries). The UI shell and the engine are separable; §3 shows the three real
ways to combine "OpenCode terminal UI on top" with an engine beneath.

**ANTI-HALLUCINATION.** Every web claim is labeled **[verified web]** (primary/official:
the GitHub repos, opencode.ai/docs, deepwiki) or **[inferred]** (my reasoning over verified
facts). In-repo claims cite the file read this session. Memory: "PLAN_V2 is authority; fix
code to match plan, owner directives override research recs." This doc is an INPUT; on any
clash the owner's directive wins.

---

## 0. Grounded in-repo state (read this session)

Both engine seams already exist in-tree, isolated, honest-inert, GUARDRAIL-locked (nothing
in `agent_loop`/`agent_runtime` touches them — Chat/Act unchanged):

- **Goose engine seam (Rust):** `agent_core/src/work.rs` — `WorkRequest`/`WorkResult`/
  `WorkError`, `run_work_session()` returns `EngineNotWired` (honest, no fallback),
  `work_backend_status_json()` UniFFI export, plus already-landed vendored/clean-room leaf
  types: `SourceRoot`, `permission::Permission`, `recipe::{RecipeParameter,Settings}`,
  `retry::{RetryConfig,SuccessCheck}`, `message::Role`, `RepetitionGuard` (clean-room of
  goose `tool_monitor.rs`), `RetryManager`/`drive_retry_cycle` (clean-room of goose
  `agents/retry.rs`), `ShellRetryExecutor` (`#[cfg(feature="pro-build")]`, hardened
  subprocess). A **SUPERSEDED banner** (`work.rs:16-21`) says leaf-by-leaf hand-porting is
  replaced by a FULL CLONE of `block/goose` as a real Cargo dep.
- **Goose Swift seam:** `Epistemos/Work/WorkBackend.swift` — `WorkBackend` protocol +
  `InertWorkBackend` + `GooseWorkBackend` growth point (delegates to inert today, `isLive=
  false`), `WorkBackendFactory.resolve()`, flag `EPISTEMOS_WORK_GOOSE_V0`. Pro-only
  (`#if !EPISTEMOS_APP_STORE`).
- **OpenCode shell seam (Swift):** `Epistemos/Work/WorkOpenCode{Runtime,Shell,ShellGate
  Status}.swift` + `WorkTerminalView.swift` — `WorkOpenCodeShell` protocol +
  `InertWorkOpenCodeShell` + `BundledWorkOpenCodeShell`, resolver checks for a bundled
  `Resources/opencode-runtime/bin/opencode` launcher (honest nil until vendored), spawns the
  real `opencode` TUI in a PTY, pins `OPENCODE_HOST=127.0.0.1`/`PORT=4096`, idle timeout
  300s. Health row + settings views wired.
- **RustLSP-into-work seam:** `agent_core/src/work_lsp_tools.rs` — lowers work-agent tool
  calls onto the EXISTING `lsp_runtime::LspKernel` (hover/definition/doc-lifecycle), honest
  gating (no fake diagnostics/edit tool). Confirms the convergence decision: don't import
  OpenCode's LSP; reuse the in-process Rust one.
- **Cost finding (read):** `docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md` —
  full-cloning the `goose` crate = **179-dep graph**, **reqwest 0.12 (agent_core) vs 0.13.2
  (goose) major clash**, rmcp/tokio/sqlx/oauth2 surface, 660 MB source → multi-iteration,
  build-red-prone, belongs in a worktree, not a single green main iteration.

**Takeaway:** the repo's current architecture already treats them as **two layers**:
OpenCode = work SHELL + (its own) engine via bundled Bun; Goose = a Rust work ENGINE seam.
The owner's question is exactly the unresolved tension between those two seams.

---

## 1. Head-to-head — capability / perf / robustness / integration / license / MAS-fit

Legend: ✅ strong / first-class · ⚠️ partial / awkward · ❌ absent. All rows **[verified
web]** unless marked.

| Dimension | **OpenCode** (sst/opencode, TS/Bun, MIT) | **Goose** (block/goose, Rust, Apache-2.0) | Edge |
|---|---|---|---|
| **Language / runtime** | TypeScript ~69%, **Bun** runtime; Hono HTTP, Drizzle ORM, Vercel AI SDK | **Rust ~64%** (+ TS/Electron desktop); Axum server, sqlx/SQLite | Goose for in-process Rust fit |
| **Agent loop** | `SessionPrompt.loop()` → `Provider.getModel()` via Vercel `ai` SDK; iterative tool-call cycle | `Agent` core "orchestrates conversation turns + tool execution"; `MessageStream = Pin<Box<dyn Stream>>` (zero-copy note, `GOOSE_REPLACEMENT_STRATEGY.md`) | ~Even (both mature ReAct) |
| **Providers** | **75+** via Vercel AI SDK + models.dev catalog; managed "OpenCode Zen" | **15+** (Anthropic/OpenAI/Google/Ollama/Bedrock/Vertex/Azure/xAI/LiteLLM…) | **OpenCode** (breadth) |
| **Tool calling** | Tool System + Permission System subsystems; build/plan agents | Tool Execution Pipeline; builtin extensions zero-IPC, compiled-in | ~Even |
| **MCP** | ✅ MCP client (tool system 5.6) | ✅ MCP client to **70+ extensions** + `goose-mcp` builtin servers | **Goose** (breadth) |
| **Extensions / recipes** | Plugins (`@opencode-ai/plugin`, Zod/Effect) | **Recipes = declarative YAML + minijinja templates** (Recipe Engine) | **Goose** (recipes are a SWE-work pillar) |
| **Permissions** | Permission + Question system; plan agent asks before bash | `Permission{AlwaysAllow,AllowOnce,Cancel,DenyOnce,AlwaysDeny}` + modes/approval | ~Even (Goose's enum already vendored in `work.rs`) |
| **Sessions** | Create/list/**fork**/share; explicit share links; persisted (Drizzle) | Session mgmt; persisted history in **SQLite/sqlx**; unified per-session agent pipeline | **OpenCode** (fork + share links) |
| **Subagents** | `@general` subagent + `@mention`; delegation = **child session, resumable/inspectable**; **multi parallel sessions** | **`Agent::new()` + `TaskConfig{provider,max_turns,extensions}`**; subagents can use cheaper providers (cost-effective delegation) | ~Even — different strengths (OpenCode=session-shaped; Goose=provider-isolated) |
| **Planning** | Built-in **plan** (read-only) vs **build** agents | Recipes + scheduler + tasks unified pipeline | ~Even |
| **Retries / test-and-fix** | Retry subsystem (not detailed in overview) | **`RetryConfig` + success checks + on_failure** = deterministic test-and-fix loop (already clean-roomed in `work.rs`) | **Goose** (explicit SWE self-correction) |
| **Context / compaction** | "Context Management and Compaction" subsystem (2.4) | "Context Management and Compaction" subsystem (4.6) | ~Even (both have it) |
| **LSP-for-agents** | ✅ **built-in LSP integration** auto-loads language servers (40+), feeds diagnostics/defs/refs into the loop (headline differentiator) | ❌ **"No LSP or code intelligence capabilities" [verified web, deepwiki]** | **OpenCode** — BUT Epistemos already has `lsp_runtime` (`work_lsp_tools.rs`) → dedup |
| **Repo index / git / multi-file diff** | File search/read/tracked-status endpoints; **/undo /redo without git** | Git lifecycle, multi-file diffs, repo work; git-based undo | ~Even (the SWE surface both target) |
| **Undo/redo of AI edits** | ✅ `/undo` `/redo` **without git** | ⚠️ git-based | **OpenCode** |
| **Maturity / community** | **~177k stars, 21.6k forks**; very active; **aggressive re-arch** (Go→OpenTUI, Tauri→Electron) | Block-backed; Rust core + Electron desktop; active; `goose-acp` ACP server | OpenCode (reach); Goose (backing) |
| **License** | **MIT** → `direct_import` | **Apache-2.0** → `direct_import` | Both clean |
| **In-process fit (`agent_core` UniFFI)** | ❌ TS — cannot be a Cargo crate; runs as bundled Bun loopback server | ✅ **Rust — links into `agent_core` natively via UniFFI** | **Goose** (decisive for the IP-brain doctrine) |
| **MAS-fit** | Bundled Bun runtime = subprocess/sidecar → **Pro/direct-dist only** (owner confirmed, addendum §420-421) | In-process Rust; only the `ShellRetryExecutor` (code exec) is Pro-gated → **engine itself is MAS-grantable** | **Goose** |
| **Footprint / startup** | **~90 MB Bun binary on disk** (Pro only) + RAM when work active + PTY bridge; lazy-launch/kill-on-idle mitigates | Compiled into the app binary; no extra runtime; cold-start native | **Goose** (no bundled runtime) |

### Capability summary (who does what BETTER)
- **OpenCode wins on:** provider breadth (75+ vs 15+), LSP-for-agents (built-in vs Goose=
  none), session fork + share links, /undo-/redo without git, multi-parallel-session UX,
  raw community polish/maturity.
- **Goose wins on:** in-process Rust fit (the single biggest integration lever), YAML
  recipes, deterministic test-and-fix retry loop, MCP/extension breadth (70+), MAS-fit,
  footprint/startup (no bundled runtime), robustness (Rust type/memory safety).
- **~Even:** the core ReAct loop, tool calling, permissions, context compaction, planning.

---

## 2. Performance + footprint (Rust vs Bun/TS) — grounded reasoning

**Verified facts:** OpenCode = Bun runtime, ~90 MB single Bun binary bundled (cost doc +
addendum §473), loopback HTTP server (`opencode serve`, 127.0.0.1:4096), agent loop runs
server-side, clients talk over HTTP+SSE. Goose = Rust, compiles into `agent_core`, runs
in-process via UniFFI, no extra runtime, server (`goosed`/Axum) is optional.

**[inferred] from those facts:**
- **Runtime weight:** Goose adds ~0 MB beyond its compiled object code in the existing
  `agent_core` dylib. OpenCode adds a ~90 MB Bun binary to the Pro bundle + a spawned
  process. Goose is strictly lighter on disk and in process count.
- **Memory:** Goose shares `agent_core`'s allocator/tokio runtime; no second VM. OpenCode
  runs a Bun (V8-class JS) process with its own heap + GC + node_modules — real RAM only
  while work is active (mitigated by spawn-on-open / kill-on-idle, already in
  `WorkOpenCodeRuntime.idleTimeout=300`).
- **Startup / latency:** in-process Rust = a function call across UniFFI. OpenCode =
  spawn Bun → boot Hono server → HTTP/SSE round-trips on loopback. The HTTP hop is small
  on loopback but non-zero, and the **cold spawn of Bun is the real latency tax** on the
  first work action of a session.
- **Concurrency:** Goose uses `agent_core`'s tokio; Goose subagents are `Agent::new()`
  instances. OpenCode multi-session concurrency lives in the Bun event loop + server.
  Both scale; Goose's is in the process you already own.
- **Honest caveat:** OpenCode's Bun server is well-engineered and the loopback HTTP cost is
  modest; "Bun is heavy" is overstated for a lazy-launched, kill-on-idle loopback server
  (addendum §462-478 makes exactly this point — the Electron/Tauri bloat is the GUI we
  DON'T ship; the headless Bun server is comparatively light). The footprint delta is real
  but **bounded**, not catastrophic.

**Net:** on pure perf+footprint, **Goose (in-process Rust) wins clearly** — no bundled
runtime, no second VM, no spawn latency, no loopback hop. OpenCode's cost is bounded and
mitigable but strictly additive.

---

## 3. Robustness

- **Type safety:** Rust's type system + ownership (Goose) is materially stronger than
  TypeScript-on-Bun (OpenCode) for crash-safety and data-race freedom. **[inferred,
  well-grounded]** This is the owner's "Rust = more robust" intuition, and it is correct
  for the *engine* layer.
- **Crash-safety / isolation:** OpenCode's out-of-process server is actually a robustness
  *plus* in one narrow sense — a Bun crash can't take down the host app (process boundary).
  Goose in-process means a Goose panic must be caught at the FFI boundary (UniFFI + Rust
  `catch_unwind` discipline) or it can abort the app. So: Rust is safer per-line; the
  process boundary is safer per-blast-radius. **[inferred]**
- **Maintenance / velocity:** OpenCode re-architects aggressively (Go→OpenTUI TUI,
  Tauri→Electron desktop) — a heavier upstream-tracking tax if forked. **[verified web]**
  Goose's Rust core is comparatively stable; the churn is in its TS/Electron desktop, which
  Epistemos does NOT take.
- **Test coverage / community:** OpenCode ~177k stars (huge real-world exercise). Goose is
  Block-backed with a serious Rust test surface. Both mature. **[verified web]**

**Net:** for the ENGINE, **Rust/Goose is the more robust substrate** (the owner's instinct
holds), with the one honest asterisk that an in-process engine needs disciplined panic
isolation at the FFI seam (which the `work.rs` honest-error design already anticipates).

---

## 4. Integration fit with Epistemos

The standing doctrine (convergence research §2; addendum §138, §553-572 ADOPT-vs-IP-LAYER;
`ActOsaurusBridge`/`WorkBackend` seam shape): **ONE owner-IP brain rides ON TOP; the engine
is a swappable executor BELOW the generation closure.** The cleaner the engine slots under
that brain, the better the fit.

- **Goose:** Rust → vendors into `agent_core::work`, exported via UniFFI to
  `GooseWorkBackend`. The brain (`LocalAgentLoop` + `agent_runtime`: Eidos citation, vault
  tools, cognitive DAG, provenance, honesty gating, prompt tiers) stays in-process ABOVE
  it — **byte-identical to the Act/Osaurus pattern already proven**. The IP brain reaches
  the engine by direct Rust call, not a bridge. **Cleanest fit.** [in-repo: `work.rs`,
  `WorkBackend.swift`, `work_lsp_tools.rs` already model exactly this.]
- **OpenCode:** TS headless server driven over HTTP/SSE. The IP brain must reach OpenCode's
  loop via **MCP/plugin** (re-expose Eidos/vault/honesty as TS plugins or MCP tools the
  Bun loop calls) OR the brain stays above and only *orchestrates* OpenCode as a delegated
  executor. Either way the brain is at **arm's length over a local bridge**, not in-process.
  More moving parts; the "one brain on top" intent is honored less cleanly. **[inferred]**

**Net:** **Goose fits "one brain on top + owner IP layered" decisively cleaner.** OpenCode-
as-engine puts a process boundary between the brain and the loop.

---

## 5. OVERLAP / DEDUP — what they DUPLICATE vs what is UNIQUE

**Duplicated (do NOT clone both — pick one source of record):**
- Core ReAct agent loop · tool calling · MCP client · permissions · sessions ·
  context/compaction · subagent delegation · provider abstraction. Both engines ship all of
  these. Running BOTH full engines = two agent loops of record = exactly the "muddiness"
  the owner banned (addendum §131 "one fused work stack, not 4 parallel ones").

**Unique to OpenCode (the genuine reasons to want it):**
1. **The real terminal UI** (OpenTUI) — already an OWNER-CHOSEN, set-in-stone requirement
   (addendum §170-198). This is a UI asset, separable from the engine.
2. **LSP-for-agents** — built-in; Goose has none. BUT **Epistemos already has its own
   in-process Rust LSP** wired via `work_lsp_tools.rs` → this is a DEDUP win, not a reason
   to take OpenCode's engine.
3. **75+ providers + /undo-redo + session fork/share** — provider breadth and UX niceties.

**Unique to Goose (the genuine reasons to want it):**
1. **In-process Rust engine** — the only one that links into `agent_core` natively.
2. **YAML recipes + deterministic test-and-fix retry loop** — SWE-work pillars (recipe +
   `RetryConfig` already partially in-tree).
3. **70+ MCP extensions + provider-isolated subagents** (cheaper provider per subagent).

**Key dedup conclusion:** OpenCode's two real engine-level edges over Goose are **provider
breadth** and **LSP-for-agents**. LSP is already covered by Epistemos's own `lsp_runtime`.
Provider breadth is the one capability the owner would actually trade away by NOT running
OpenCode's engine — and it is recoverable (Goose has 15+ incl. all the majors; the brain's
own provider layer + Osaurus's MLX serving cover local). So **the union of benefits does
NOT require running two full engines.**

---

## 6. "Keep ALL benefits" without two full engines — the real options

The owner wants the UNION: OpenCode's terminal UI (hard requirement) + the most robust/
performant engine + no lost capability. The UI and the engine are **separable** (OpenCode is
headless-first; the TUI is one client of the server — addendum §462-466 [verified web]).
That separability is what makes "keep all benefits with one engine" achievable. The three
real architectures:

### Architecture A — **OpenCode engine drives work; Goose contributes only unique bits**
**Shape.** Ship OpenCode headless (bundled Bun, lazy/kill-on-idle) as the work engine of
record. Its real terminal UI is the shell (owner requirement, satisfied directly). Goose is
NOT a second engine — its *unique bits* (recipes, the deterministic test-and-fix retry loop)
are exposed to OpenCode's loop as **MCP tools / a delegated subagent**, OR simply re-created
from the already-vendored `work.rs` clean-room types. The IP brain wires in via OpenCode
plugins/MCP.
- **Keeps OpenCode's real terminal UI:** ✅ natively (it IS OpenCode's UI).
- **Perf/footprint:** ⚠️ worst — bundled ~90 MB Bun + spawned server + loopback HTTP +
  first-action spawn latency. Bounded/mitigated, but the heaviest of the three.
- **Robustness:** ⚠️ engine is TS/Bun (owner's robustness concern lands here); + process
  boundary is a blast-radius plus.
- **What's lost:** Goose's Rust in-process engine + clean brain-on-top fit. The IP brain is
  at arm's length over MCP. The `work.rs` Rust seam becomes vestigial (engine is TS).
- **Effort:** MEDIUM — vendor Bun runtime + bundle step; expose brain over MCP; the Swift
  shell/terminal/resolver already exist (`WorkOpenCode*`). The `GOOSE_FULL_CLONE` reqwest
  pain is AVOIDED (Goose isn't the engine).

### Architecture B — **Goose Rust engine (in-process, links `agent_core`) drives work UNDER OpenCode's terminal UI**
**Shape.** Goose is the work engine of record, vendored into `agent_core::work`, UniFFI →
`GooseWorkBackend`, brain on top (the Act/Osaurus pattern). OpenCode's **terminal UI is kept
as the shell**, but instead of pointing the TUI at OpenCode's own Bun server, it is driven
against the **Goose engine**. Two honest sub-variants for the UI wire:
- **B1 (real OpenCode TUI, Goose behind an OpenCode-shaped API):** stand up a thin
  Goose-backed server that speaks enough of OpenCode's OpenAPI surface for the real TUI to
  drive it. Keeps the literal OpenCode TUI; high glue cost (re-implement the slice of
  OpenCode's HTTP/SSE contract the TUI uses).
- **B2 (terminal-look view, Goose direct):** render the work surface in a native
  terminal-style view (SwiftTerm or a pixel-art terminal render — the addendum's
  §479-481 "ultra-light fallback") driven directly by `GooseWorkBackend` over UniFFI. Keeps
  the *terminal aesthetic the owner likes* without OpenCode's literal TUI binary.
- **Keeps OpenCode's real terminal UI:** B1 ✅ literal TUI (heavy glue) · B2 ⚠️ terminal
  *look*, not OpenCode's actual TUI (mild tension with the set-in-stone "keep the real UI").
- **Perf/footprint:** ✅ best — no bundled Bun (B2) / minimal (B1 still needs a server but
  Rust, not Bun). In-process engine, native latency.
- **Robustness:** ✅ Rust engine (owner's instinct satisfied); brain in-process.
- **What's lost:** OpenCode's 75+ provider catalog (Goose has 15+ incl. majors — recoverable
  via the brain's provider layer); /undo-redo + session-fork-share UX unless rebuilt; B1's
  glue is brittle vs OpenCode's churning OpenAPI; B2 deviates from "literal OpenCode UI."
- **Effort:** HIGH for the engine (the `GOOSE_FULL_CLONE` reqwest 0.12→0.13 + 179-dep
  reconciliation in a worktree) + MEDIUM-HIGH for the UI wire (B1 OpenAPI-shim is the
  expensive part; B2 reuses the existing terminal-view seam).

### Architecture C — **HYBRID of record: OpenCode = SHELL + headless engine; Goose = unique-bits delegated executor; brain on top; ONE engine of record, the other demoted to a tool** *(refines A; the dedup-honest middle)*
**Shape.** This is Architecture A's shape but stated as the explicit dedup contract that
keeps ALL benefits with ONE engine of record:
- **OpenCode = the work shell (real terminal UI, owner requirement) AND the engine of
  record** (headless Bun, lazy/kill-on-idle) — because the UI and engine are the same
  upstream and shipping the engine that natively backs the chosen UI is the lowest-friction
  way to keep the literal UI live.
- **Goose is NOT a parallel engine.** Its genuinely-unique value (recipes, deterministic
  test-and-fix retry loop, provider-isolated subagents) is delivered EITHER as (a) MCP
  tools/subagent OpenCode delegates to, OR (b) — preferred for footprint — *not as Goose at
  all* but as the **already-vendored `work.rs` clean-room Rust** (`RetryManager`,
  `RepetitionGuard`, recipe types) surfaced to the work loop. This means the owner keeps the
  *capability* (test-and-fix, recipes, repetition-guard) WITHOUT vendoring the heavy 660 MB /
  179-dep `goose` crate at all.
- **LSP** = the existing `lsp_runtime` via `work_lsp_tools.rs` (already done in-tree), wired
  to the OpenCode loop as tools — NOT OpenCode's LSP, NOT a Goose LSP.
- **Brain** = IP layer over MCP/plugin (same as A).
- **Keeps OpenCode's real terminal UI:** ✅ natively.
- **Perf/footprint:** ⚠️ carries the Bun runtime (the unavoidable cost of keeping the
  literal OpenCode UI+engine), but AVOIDS the second heavy Goose-crate vendor.
- **Robustness:** ⚠️ engine is TS/Bun; mitigated by process isolation + the owner's accepted
  Pro-only/MAS-leniency posture.
- **What's lost:** Goose's Rust *engine* (we keep its *ideas* as in-tree Rust clean-room, not
  the crate); the brain is at arm's length over MCP (same as A).
- **Effort:** LOWEST overall — uses the already-built `WorkOpenCode*` Swift shell + the
  already-vendored `work.rs` clean-room types; NO `goose` heavy-crate vendor (skips the
  reqwest/179-dep saga entirely); the work is "vendor Bun + bundle step + brain-over-MCP +
  wire `work_lsp_tools`."

---

## 7. RECOMMENDATION

**Lean: Architecture C — OpenCode is the WORK ENGINE OF RECORD (headless Bun, behind its
own real terminal UI), the owner's IP brain layers on top via MCP/plugin, the existing
`lsp_runtime` provides code intelligence, and Goose is NOT vendored as a second engine — its
genuinely-unique capabilities are kept as the already-in-tree Rust clean-room (`work.rs`
RetryManager/RepetitionGuard/recipe types) surfaced to the work loop.**

**Why this is the SMART answer given the constraints:**

1. **It honors the set-in-stone UI decision with zero friction.** The owner chose "keep
   OpenCode's REAL terminal UI" (addendum §170-198, §449-454). The lowest-risk way to keep
   the literal UI live is to ship the engine that natively backs it. Architecture B (Goose
   under the real TUI) fights that — it forces a brittle OpenAPI-shim (B1) or deviates to a
   terminal-*look* (B2, mild tension with "the real UI"). **C removes UI risk entirely.**

2. **It KEEPS ALL benefits without two engines.** OpenCode's only engine-level edges over
   Goose are provider breadth (75+) and LSP — and LSP is already covered by Epistemos's own
   `lsp_runtime`. Goose's unique edges (test-and-fix retry, recipes, repetition guard) are
   ALREADY in-tree as clean-room Rust in `work.rs` and ride along as work-loop tools. So the
   UNION of capabilities is preserved with ONE engine of record. **No capability is lost.**

3. **It avoids the single biggest integration landmine.** `GOOSE_FULL_CLONE_INTEGRATION_
   COST` proves vendoring the `goose` crate = reqwest 0.12↔0.13.2 major clash + 179-dep
   graph + 660 MB, multi-iteration build-red work. **C never pays that** — Goose-the-crate
   isn't the engine.

**Honest cost of leaning C (where the owner's Rust/perf instinct is conceded):** the engine
is TS/Bun, so the owner's "Rust = more robust + lighter" intuition is NOT satisfied at the
engine layer. Mitigations make this bounded, not catastrophic: headless-only (no
Electron/Chromium — addendum §466-468), single ~90 MB Bun binary, lazy-launch + kill-on-idle
(already in `WorkOpenCodeRuntime`), loopback-only, Pro/direct-dist only (MAS unaffected),
process isolation (a Bun crash can't abort the app). The robustness the owner cares about
most — the **IP brain** — stays in-process Rust/Swift regardless of engine.

**If the owner weights Rust-robustness + footprint ABOVE UI-literalness**, the answer flips
to **Architecture B2**: Goose Rust engine in-process + a native terminal-look view. This is
the more *performant and robust* build, but it (a) pays the heavy goose-crate vendor and
(b) renders a terminal *aesthetic* rather than OpenCode's literal TUI — a direct tension
with the set-in-stone UI decision. **This is the core trade and the #1 owner question
below.** My lean is C because the UI decision is already set in stone and C loses no
capability; but B2 is the legitimately-better answer IF the UI literalness is negotiable.

**What to do with the existing superseded Goose leaf-ports (`work.rs` `vendored_goose`):**
**KEEP them — they become load-bearing under recommendation C, not vestigial.** Their
SUPERSEDED banner (which points to a full goose-crate vendor) should be re-scoped: under C
there is **no full goose-crate vendor**, so the clean-room `RetryManager` / `RepetitionGuard`
/ `RetryConfig` / recipe types ARE the permanent home of Goose's unique capability inside
Epistemos (surfaced to the OpenCode work loop as tools/MCP). Re-label the banner from
"superseded by full clone" to "clean-room is the chosen home; no goose-crate vendor under
the Architecture-C decision." If instead the owner picks B/B2, then the banner stands and
the leaf-ports are the interim until the real crate lands. **Do not delete them under any
option** (they are the test-and-fix/loop-guard capability and are GUARDRAIL-isolated).

---

## 8. EXPLICIT PLAN ADDITIONS (paste-ready, no nuance lost)

```
## 🆕 WORK ENGINE DECISION — OpenCode engine of record; Goose as in-tree clean-room bits (2026-06-21)

DECISION (pending owner confirm of §Open-Questions Q1): The WORK-mode ENGINE OF RECORD is
OpenCode's headless engine (bundled Bun, Pro/direct-dist only), running BENEATH OpenCode's
real terminal UI (the set-in-stone UI decision, addendum §170-198/§449-454 — unchanged). The
owner's IP brain layers ON TOP via MCP/plugin. Goose is NOT vendored as a second engine.

- ONE work engine of record = OpenCode. No second agent loop. (Honors "one fused work stack,
  not 4 parallel" — addendum §131.)
- KEEP ALL BENEFITS without two engines:
  - OpenCode unique edges retained natively: real terminal UI (kept), 75+ providers, session
    fork/share, /undo-/redo.
  - OpenCode's LSP edge is DEDUP'd to Epistemos's EXISTING lsp_runtime via
    agent_core/src/work_lsp_tools.rs (already in-tree) — do NOT import OpenCode's LSP.
  - Goose's unique edges retained as ALREADY-IN-TREE clean-room Rust in agent_core/src/work.rs
    (RetryManager / drive_retry_cycle = deterministic test-and-fix; RepetitionGuard = loop
    guard; recipe::{RecipeParameter,Settings} = recipe params; ShellRetryExecutor = Pro-gated
    hardened exec) — surfaced to the OpenCode work loop as MCP tools. NO heavy goose-crate
    vendor (avoids the reqwest 0.12↔0.13.2 + 179-dep + 660MB saga, per
    GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md).
- RE-SCOPE the work.rs SUPERSEDED banner: under this decision the clean-room types are the
  PERMANENT home of Goose's unique capability inside Epistemos, NOT an interim awaiting a full
  goose-crate vendor. Re-label accordingly. NEVER delete (GUARDRAIL-isolated; Chat/Act
  unchanged).
- FALLBACK on owner override (Q1 = "Rust engine please"): switch to Architecture B2 — Goose
  Rust engine in-process (vendor block/goose in a worktree, reconcile reqwest, UniFFI →
  GooseWorkBackend) under a native terminal-LOOK view; accept that this renders a terminal
  aesthetic rather than OpenCode's literal TUI, and pays the heavy goose-crate vendor cost.
- Perf/footprint honesty: ~90MB Bun (Pro build only), lazy-launch + kill-on-idle
  (WorkOpenCodeRuntime.idleTimeout=300), loopback-only, headless (NO Electron/Chromium). The
  IP brain stays in-process Rust/Swift regardless of engine.
- Sequencing UNCHANGED: Osaurus/ACT first (dual-MLX → link → Act turn → shared composer); WORK
  engine work starts only after the ACT gates clear. Heavy vendors (Bun bundle step, OR the
  goose-crate fallback) run in an iterate-able worktree, NEVER committed red to main.
```

---

## 9. PROMPT FOR THE BUILD AGENT (ready-to-paste)

```
WORK ENGINE — BUILD DIRECTIVE (2026-06-21). Authority: OSAURUS_P3_IMPORT_PLAN_2026_06_21_
addendum.md (owner directives WIN over research recs) + OPENCODE_VS_GOOSE_WORK_ENGINE_2026_06_21.md.

DO NOT start WORK-engine work until the ACT gates clear (dual-MLX consolidation → OsaurusCore
link → Act turn through Osaurus → shared composer). Osaurus-first stands.

ENGINE DECISION (Architecture C — confirm with owner via Q1 before the heavy step):
  OpenCode = WORK ENGINE OF RECORD (headless Bun, beneath its REAL terminal UI). Goose is NOT
  a second engine. The owner IP brain layers on top via MCP/plugin.

BUILD STEPS (each: green, isolated, GUARDRAIL test "Chat/Act unchanged" stays passing; heavy
vendor steps in a worktree, never red on main):

1. (already in-tree — verify, don't rebuild) Confirm the Swift OpenCode shell seam compiles
   and stays honest-inert until the runtime is bundled: Epistemos/Work/WorkOpenCode{Runtime,
   Shell,ShellGateStatus}.swift + WorkTerminalView.swift. Confirm WorkOpenCodeShellGateStatus
   flag + health row report "armed, INERT" honestly.

2. VENDOR OpenCode headless runtime (Pro/direct-dist only) into Resources/opencode-runtime/:
   bundle the single Bun binary + opencode launcher; add the build-phase step; keep it OUT of
   the MAS target (CI guard: MAS target does NOT link/ship opencode-runtime). The moment the
   bundle lands, WorkOpenCodeShellFactory.resolve() goes LIVE with no further wiring (the
   resolver already checks bundledRuntimeURL()). Measure Bun disk + RAM (idle/active) and
   record in the health row.

3. Render OpenCode's REAL terminal TUI in the native terminal view (SwiftTerm/PTY per
   WorkOpenCodeRuntime.shellEnvironment), palette-bridged LIVE to the app theme system (incl.
   custom themes — hard requirement, addendum §162-168). Lazy-launch on WORK open; kill-on-idle
   (idleTimeout=300) = PTY lifecycle. Loopback-only (OPENCODE_HOST=127.0.0.1).

4. DEDUP LSP: wire agent_core/src/work_lsp_tools.rs (existing lsp_runtime) into the OpenCode
   work loop as code-intelligence tools (hover/definition/doc-lifecycle). Do NOT import
   OpenCode's LSP. Keep honest gating (no fake diagnostics/edit tool).

5. SURFACE Goose's unique capability WITHOUT vendoring the goose crate: expose the existing
   agent_core/src/work.rs clean-room types (RetryManager/drive_retry_cycle test-and-fix,
   RepetitionGuard loop guard, recipe params, Pro-gated ShellRetryExecutor) to the OpenCode
   work loop as MCP tools. RE-LABEL the work.rs SUPERSEDED banner: clean-room is the chosen
   permanent home; no goose-crate vendor under this decision. NEVER delete the seam.

6. WIRE the IP brain (Eidos citation, vault/Knowledge-Core tools, cognitive DAG, provenance,
   honesty gating, prompt tiers) to the OpenCode loop via MCP/plugin — brain stays in-process
   Rust/Swift; OpenCode reaches it over the local bridge. No silent fallback; honest errors
   only (mirror WorkBackendError/WorkShellError). RunEventLog + AnswerPacket on every work run.

7. SETTINGS: per-clone "work" settings tab carrying OpenCode's real settings, reskinned
   pixel-art, theme-aware (addendum §279-290). Health row shows engine state honestly.

IF OWNER OVERRIDES Q1 ("Rust engine of record / footprint+robustness over UI literalness"):
  Switch to Architecture B2. In a worktree: vendor block/goose as a real Cargo dep behind a
  `goose-clone` feature (OFF by default so mas-build stays green), reconcile reqwest 0.12→0.13.2
  (or isolate goose behind FFI so the majors don't unify), replace work.rs leaf-ports with
  re-exports of the real goose types, UniFFI-export run_work_session → light up GooseWorkBackend
  (isLive=true only when real). Drive a NATIVE terminal-LOOK view from GooseWorkBackend (accept:
  terminal aesthetic, not OpenCode's literal TUI). Keep the OpenCode shell seam inert/removed
  per owner call. Land only when `cargo build --features goose-clone` is green.

NON-NEGOTIABLES (all options): one engine of record; brain on top; no hidden fallback; honest
capability gating; GUARDRAIL (Chat/Act unchanged); heavy vendors in a worktree not red on main;
OpenCode never shown as "OpenCode" (labeled "work"); theme-responsive incl. custom themes.
```

---

## 10. OPEN QUESTIONS FOR THE OWNER

1. **THE core trade (decide first).** Architecture **C** (OpenCode = engine of record, ~90MB
   Bun, keeps your literal terminal UI with zero risk, loses no capability) vs Architecture
   **B2** (Goose Rust engine in-process — lighter + more robust per your instinct — but a
   native terminal-*look* view instead of OpenCode's literal TUI, and it pays the heavy
   goose-crate vendor). Your set-in-stone UI decision points to **C**; your Rust/perf
   instinct points to **B2**. Which weight wins?
2. **Goose as a tool vs not at all.** Under C, do you want Goose's unique bits delivered as
   (a) the already-in-tree `work.rs` clean-room Rust surfaced as tools (lightest — recommended),
   or (b) a bundled `goosed` (Rust) the OpenCode loop delegates to (heavier, but the *real*
   Goose recipes/subagents)?
3. **Provider breadth.** OpenCode = 75+ providers; Goose = 15+ (all majors). Under B2 you'd
   lean on your brain's own provider layer + Osaurus MLX for local. Is 15+ acceptable, or is
   the 75+ catalog a must-have that argues for C?
4. **Brain-at-arm's-length tolerance.** Under C the IP brain talks to the engine over MCP
   (process boundary) rather than in-process. Acceptable, or is in-process brain↔engine
   (only achievable with the Goose Rust engine, B2) a hard requirement?
5. **Superseded leaf-ports.** Confirm: re-label `work.rs` `vendored_goose` banner to
   "clean-room is the chosen permanent home (no goose-crate vendor)" under C — vs keep the
   "interim until full clone" banner under B2. (Never delete either way.)
6. **Footprint ceiling.** Is a ~90MB Bun binary in the Pro build (lazy/kill-on-idle,
   loopback, headless, no Electron) acceptable as the price of keeping OpenCode's literal UI?

---

## Sources

- **In-repo (read this session):** `agent_core/src/work.rs`, `agent_core/src/work_lsp_tools.rs`,
  `Epistemos/Work/WorkBackend.swift`, `Epistemos/Work/WorkBackendGateStatus.swift`,
  `Epistemos/Work/WorkOpenCodeRuntime.swift`, `Epistemos/Work/WorkOpenCodeShell.swift`,
  `Epistemos/Work/WorkOpenCodeShellGateStatus.swift`, `Epistemos/Work/WorkTerminalView.swift`,
  `docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md`,
  `docs/research/OPENCODE_FULL_CLONE_FEASIBILITY_2026_06_21.md`,
  `docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md`,
  `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md`, `CLAUDE.md`.
- **Web (primary/official):** [github.com/sst/opencode](https://github.com/sst/opencode) ·
  [github.com/block/goose](https://github.com/block/goose) ·
  [deepwiki sst/opencode](https://deepwiki.com/sst/opencode) ·
  [deepwiki block/goose](https://deepwiki.com/block/goose) ·
  [goose Unify Agent Execution discussion #4389](https://github.com/block/goose/discussions/4389) ·
  [opencode.ai/docs/server](https://opencode.ai/docs/server/).
- **Labels:** repo language/runtime/provider/LSP/architecture facts = [verified web] from the
  sources above; perf/footprint/integration/robustness *judgments* = [inferred] and labeled inline.
```
