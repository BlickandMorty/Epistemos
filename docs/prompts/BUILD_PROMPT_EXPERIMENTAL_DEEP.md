# Build Prompt — 1Code Experimental: The Embedded-Agent Frontier

## ⚡ READ-FIRST PRIORITY LEDGER (if you skim nothing else, obey these)
1. **No native SwiftUI — extend the 1Code web UI + backend fork only.**
2. **Never touch the MAS-June lane or the data/knowledge core (vault / graph / notes).**
3. **"Build green" ≠ done — verify in the RUNNING app; never stop while a DoD is unmet; never fake capability.**
4. **Every cycle (from Cycle 2): USE ≥1 prior skill, SHIP a profound build, FORGE a new reusable skill.**
5. **Ship Prompt Forge (§ Feature Mandate) — deeply upgrade the user's prompt at submission, vault-grounded.**
6. **CLOUD engines FIRST (local second); WIRE the PROVEN deterministic substrate + a user Skills library — see § Finalization Mandate + `docs/research/DETERMINISTIC_SUBSTRATE_INFUSION.md`.**

## ❌ FAILURE MODES — worked anti-examples of "done wrong" (never do these)
- **Skim-and-declare** (the #1 failure this project keeps hitting): read the ledger, skip the body, ship a shallow change, say "nothing left." → A DoD is unmet; re-read.
- **Plumbing-as-done:** wire the backend/shim/env and call it done while the visible, vault-deep integration is missing. Build-green ≠ done.
- **SwiftUI relapse / boundary breach:** add native chrome, or make "one tiny edit" to the June lane or the data core. → Forbidden; flag it.
- **Fake capability:** ship a dead provider button or a faked state to close a row. → Gate it honestly.
- **Trophy skill:** forge a SKILL.md nothing reuses, or run a cycle that ignores the library. → Under-compounded.

> A research-and-build assignment. Not a task list — a mandate. Read every word before you write a line.
> This SUPERSEDES the native-SwiftUI direction of the earlier P2 prompt. **There is no more SwiftUI
> chrome. You extend the 1Code web UI itself.** Everything else the owner asked for still holds.
>
> **This is a FOREVER LOOP.** It does not finish — it compounds. Every cycle you scout the deepest
> frontier, forge it, temper it, and **crystallize the breakthrough into a new reusable skill**, then
> raise your own bar. The five phases below are **Cycle 1**. Then you loop, forever, godlier each turn.
> See §∞.

You own the **1Code Experimental surface** (`Epistemos/ExperimentalAgent/**` for the thin Swift host, and
the vendored 1Code fork under `.research-clones/1code/**`). A separate agent owns MAS June — **do not
touch `Epistemos/JuneAgent/**` or the June lane.** Your surface embeds 1Code's React renderer in a
WKWebView over a headless Node backend. That embedding is built and works. Your job now is far larger
than finishing it: **make it the best agent surface that exists** — more robust, more hardened, more
deeply connected than Codex, than the Claude Desktop app, than opencode, goose, Cursor, or aider — by
researching the field, auditing yourself to the bone, inventing the features only Epistemos can have,
and hardening to a tier no standalone agent app can match.

---

## THE ONE RULE (why prior passes fell short)
**"Build green" is not done. "It compiles" is not "it works." "The plumbing is wired" is not "it is
better than Codex."** Done is defined only by the DoD below, each proven in the **running app** with a
real transcript/screenshot, plus a thermonuclear review with zero open HIGHs. Do not stop on
plumbing, do not declare done while any DoD is unmet, do not fake a capability to close a row.

## THE PIVOT — no native SwiftUI; extend the web UI
- **Do NOT build native AppKit/SwiftUI chrome, pickers, sidebars, or settings.** The prior "lift chrome
  to native" direction is RETIRED. New user-facing features live **in the 1Code React renderer** (the
  vendored fork's `src/renderer`, via overlay files + `PATCH_LEDGER.md` rows, rebuilt by
  `build-experimental-web.sh`).
- **Keep the thin Swift host** exactly as-is: the WKWebView, the supervisor, the script-message bridge,
  the native NSOpenPanel/NSSavePanel the shim requires, the theme injection, Keychain. That is
  infrastructure, not chrome — it stays. You add to the *web app*, and to the *backend fork*, not to
  native SwiftUI views.
- **§0 physics still holds:** the transcript, terminal, and agent loop stay in their existing lanes.
  Never reload the WebView URL (it reboots the SPA and kills the live session) — drive the UI in-app.

## THE FOUNDATION (must be true before the frontier; all web/backend-side, no SwiftUI)
These were already required and remain non-negotiable prerequisites — verify or finish each:
1. **It is Epistemos, not 1Code.** Zero `21st`/`1code`/`twentyfirst` reaching the screen (de-brand at
   bundle time in `build-experimental-web.sh`; grep-gate the dist to 0 user-facing hits; keep
   LICENSE/NOTICE).
2. **It boots into your vault.** On launch: no folder picker — auto-load the app's chosen vault folder
   (`AppBootstrap.shared.vaultSync.vaultURL`) as the active project, land in a ready chat.
3. **All six engines are selectable and real** (Claude Code, Codex, Kimi, GLM, Gemini, OpenCode-free-Zen)
   with the live model catalog (`models.dev` + per-provider `/models` + pinned fallback), per
   `BUILD_PROMPT_EXPERIMENTAL_FINAL.md` §5. Keychain key-paste per provider.
4. **The Epistemos theme is worn** (inject `:root` CSS custom-property tokens via a WKUserScript,
   MutationObserver re-assert, live light/dark; reuse the `ProAgentThemeBridge` pattern; header font on
   landmarks only, Monaco/xterm legible; kill the donor gradient).
5. **The vault MCP is actually present to the engine** (router-level injection into the forked backend;
   the agent can search/read/write the user's notes), not just an env var.

## FEATURE MANDATE — Prompt Forge (submission-time prompt upgrader; build this, DoD-gated)
A first-class feature: when the user submits a prompt in the Experimental composer, **deeply upgrade it
before it reaches the engine** — more robust/useful/effective — while preserving their intent and voice.
Full spec: `docs/research/PROMPT_UPGRADING_FIELD_STUDY.md` Part 3. Pipeline: intent+gaps → clarity+
structure (keep the user's nouns/constraints/voice) → task-matched technique injection (CoT/decomposition/
output-format — never over-applied) → **vault-grounding** (retrieve relevant notes/graph via the vault
MCP, inject the highest-priority context that fits the engine's window, cite) → budget-aware assembly →
clarify-don't-guess (≤3 questions only on real ambiguity). UX: original→upgraded diff, one-click
Accept/Edit/Retry/Revert, never silent, fast (small model, streamed), show what changed. Build it in the
renderer composer + a backend enhance step. **Ships as a real feature (a live "underspecified prompt →
upgraded, vault-cited prompt" transcript), not a stub** — it's on the feature ledger + DoD-Foundation.

## FEATURE MANDATE — System Prompt Forge + Pattern Library (companion to Prompt Forge; build this, DoD-gated)
Prompt Forge upgrades the USER prompt; this upgrades the SYSTEM-prompt / behavior layer. Two parts: (1) a
curated, composable **Pattern Library** (Fabric-model, markdown, task/persona-scoped) the user or app
applies + composes per agent; (2) a system-prompt **upgrader** that meta-improves a custom system prompt
into the layered frontier architecture — **identity → capability-honesty → tool contract → refusal
framing → output contract → priority budgeting → worked failure examples** — preserving intent/voice,
with the diff UX. Vault-grounded (personalize the agent's system prompt to how THIS user works). Full
spec + the architecture lessons: `docs/research/SYSTEM_PROMPT_FIELD_STUDY.md`. **⚠️ IP: learn the
PATTERNS from frontier/leaked prompts, NEVER copy proprietary system-prompt TEXT into the product.** Build
it in renderer settings + backend; each of the six engines/personas can be Pattern-driven; keep per-engine
system prompts honest. Ships DoD-gated (a custom system prompt measurably upgraded + a Pattern applied),
not a stub.

## FINALIZATION MANDATE — cloud-first · substrate-as-capabilities · a user skill library
Backed by `docs/research/DETERMINISTIC_SUBSTRATE_INFUSION.md` (the determinism is BUILT + tested +
FFI-exposed, just under-wired; ~90% of this is wiring proven `agent_core` code, not rebuilding).
1. **CLOUD FIRST, local second.** Default the composer to a **cloud provider** (Claude Code / Codex /
   Kimi / GLM / Gemini) at full agentic capability; local/Ollama is the secondary/offline lane. Never
   default to local; never fake agentic capability on local.
2. **Substrate-as-capabilities — wire the proven primitives as web-side tools/schemas** over the
   `epistemos` reply channel: `run.export-bundle` (ReplayBundle → a verifiable `.epbundle` checkable by
   `epistemos-trace`), `vault.cite-check` (Eidos closed-citation), a RunEventLog capture of the opaque CLI
   tool-calls, EML-reranked `vault:search-ranked` (`EPISTEMOS_EML_RERANK_RECALL_V0=1`), and the
   ACS-anchored VRM "Verified/Plausible/Speculative" chip (rides the AnswerPacket JSON — no native chrome).
   Grounding floor: RRF → EML → confidence-floor → (VariantLadder) → ACS anchor. **NEVER ship research-only
   layers (sketch / mutations / neocortex-gist / neural-substrate) as green.**
3. **User skill library — promote only the good ones (kernel is BUILT).** Record each CLI-agent turn's
   tool sequence over the `epistemos` channel → `record_skill_outcome` / `observe_composition`; the
   deterministic gates (`skill_discovery` novelty + frequency≥4× + acceptance; `mutation_proposer`
   size≤15KB + cosine>0.80; `self_evolution` repetition) draft it; user-review via `SkillEvolutionService`;
   a **Skills browser** in the web UI shows/invokes ONLY gate-passed skills. Land the two missing wires if
   absent (`observe_composition` FFI + the nightbrain `skill_evolution_analysis` body).
**DoD additions:** the cloud provider is the running default; ≥1 proven substrate primitive shipped as a
tool/schema; the Skills browser shows a gate-passed skill AND withholds an unproven one.

---

## §1 THE THESIS (this is why you can beat them — internalize it)
Every standalone agent app — Codex, Claude Desktop, opencode, goose, Cursor, aider — is **an agent with
no memory of the user.** It boots cold each session; its "context" is whatever it can grep in the
current repo. It cannot cite your knowledge, write back to it, or reason over it, because it does not
live inside a second brain.

**The Experimental surface is different in kind: it is an agent embedded in a knowledge substrate** — the
Epistemos vault (the user's notes), the graph (their links), the provenance ledger (what is true and
why), and cross-session memory. That is a *structural* advantage no standalone app can replicate. So the
mandate is **not** to clone Codex's UI. It is to build the agent that only makes sense inside Epistemos —
one that grounds answers in the user's own notes with citations, writes its work back to the vault with
provenance, remembers across sessions via the graph, and assembles context from knowledge, not just from
`grep` — **while matching or beating the standalone apps on the baseline** (reliability, streaming, diff
review, worktrees, tool approval, observability, cost, DX).

You will be judged on three axes: **(1) Depth of embedding** (features with no equivalent in Codex /
Claude Desktop), **(2) Baseline excellence** (the things the field does well, done at least as well),
**(3) Hardening & trust** (the deepest tier; every action auditable, nothing silent, crash-safe, secure).

---

## PHASE A — DEEP RESEARCH (two fronts; this is the "studied for generations" part)
Use the deepest research method you have. Two fronts, both producing committed corpora.

**A1 — Research the field.** Clone the best open agent apps into `.research-clones/` (gitignored, NEVER
committed, NEVER `git add`) and read their real source. At minimum: `openai/codex` (Codex CLI),
`anthropics/anthropic-quickstarts` + the Claude Desktop / DXT extension patterns, `sst/opencode` (or the
current opencode remote), `block/goose`, `zed-industries/zed` (ACP agent), `cline/cline`,
`continuedev/continue`, `paul-gauthier/aider`. For each, extract with file:line: their agent loop, their
tool-approval + sandbox model, their context-assembly strategy, their diff/review UX, their
observability/cost surfaces, their reliability/error-recovery, and — critically — **what they
structurally CANNOT do because they are not embedded in a knowledge base.** Deliverable:
`docs/research/AGENT_APP_FIELD_STUDY.md` — a comparative map: what to match, what to beat, what only we
can do. Cite everything; web-verify current capabilities where the repo lags the product.

**A2 — Research your own code (thermonuclear self-audit).** A 7-layer audit of the whole Experimental
stack — the Swift host, the shim, the headless backend fork, the renderer overlays, the provider lane,
the MCP path, the theme, the boot flow. For every seam: what it's meant to do, what it actually does
(file:line), verdict CONNECTED / HALF-WIRED / DISCONNECTED / DEAD, and the reliability/security/leak
risk. Find every orphan, every silent no-op, every place a failure is swallowed. Deliverable:
`docs/research/EXPERIMENTAL_DEEP_AUDIT.md`. Append to `EXPERIMENTAL_R.md`'s cycle log.

## PHASE B — THERMONUCLEAR CODE REVIEW
Run the deepest code review you can invoke (the `/code-review` skill at the highest effort / a multi-
agent adversarial pass) over the entire diff of the Experimental surface + the backend fork + the
renderer overlays. Triage every finding by the four lenses (correctness, security, memory/data-leak,
robustness). **Fix every CONFIRMED HIGH before Phase C.** Re-review after fixing. A HIGH open = not done.

## PHASE C — INVENT & INTEGRATE THE FRONTIER (in the web UI + backend, no SwiftUI)
From the A1 field study and the §1 thesis, build two classes of feature, each as a real addition to the
1Code renderer / backend fork (overlay files + PATCH_LEDGER rows):

**C1 — The embedded-agent features (the unfair advantage; these are the point).** Invent and ship
features that are only possible because the agent lives in Epistemos. Strong candidates — justify/refine
each against the thesis, don't cargo-cult:
- **Vault-grounded answers with citations** — the agent searches the user's notes mid-task and cites
  them inline (built on the vault MCP).
- **Provenance write-back** — every substantive agent action/edit can be written back to the vault as a
  provenance-linked note (what changed, why, which sources), feeding the graph.
- **Cross-session memory** — the agent recalls prior sessions/decisions via the graph, so it doesn't
  start cold. Surface "what we decided last time" in-context.
- **Graph-aware context assembly** — pull the *right* notes into the agent's context via the graph +
  RRF fusion, not just repo grep. This is the feature Codex/Cursor cannot build.
- **A provenance/observability console** for the agent's own actions (tool calls, costs, decisions) —
  in the web UI.
Every C1 feature must answer: "why can no standalone agent app do this?" If it has no good answer, it's a
C2 feature, not C1.

**C2 — Baseline excellence (match/beat the field).** From A1, take the best baseline patterns the field
proved and ensure the Experimental surface has them at least as good: robust tool-approval + sandbox,
first-class diff/review, worktree/parallel-run ergonomics, streaming fidelity (text + thinking),
per-provider cost/rate tracking, crash-recovery, honest error surfaces. Close any gap the field study
exposed.

## PHASE D — CONNECT EVERYTHING (as connected as it theoretically can be)
Wire every DISCONNECTED/HALF-WIRED item from A2. Fuse the surface into Epistemos as deeply as the
architecture allows: the vault, the graph, provenance, RRF search, cross-surface state. The bar is
literal — "as connected as it theoretically can be" — every seam the audit found open, closed; every
Epistemos capability the agent could use, reachable. Nothing bolted-on; everything integrated.

## PHASE E — DEEPEST HARDENING (the enterprise tier — a named deliverable)
The four lenses over everything Phases C/D touched, reported thermonuclear (`N HIGH/MED/LOW`, file:line,
FIXED/DEFERRED; a HIGH blocks the commit). Security: CSP locked to the custom scheme + localhost backend
+ active provider endpoints; every tool call passes an allow/deny policy with append-only NDJSON audit;
secrets Keychain-only, never in JS; every `WKScriptMessageHandler` payload validated. Reliability:
crash-safe session/state (SQLite WAL), process/worktree reaping, per-turn error boundaries + retry,
runaway guards. Memory/energy: bounded streams, WebView teardown, heap ceilings, idle unload. Perf: the
`[experimental_surface]` budgets hold. Zero test regressions.

---

## §∞ THE FOREVER LOOP — the self-evolving engine (this is the heart; it never ends)
This is not a project with an end state, and it is NOT a skill-collecting exercise. It is a **loop of
profound BUILDS** — real features and deep connections shipped into the app every cycle — where **skills
are the compounding leverage you USE to build, never trophies you collect.** Each cycle both *stands on*
the skills forged before it and *leaves behind* one more, so the app gets deeper AND each build gets
faster and more profound than the last. Phases A–E above are **Cycle 1**. Then you loop — forever — each
cycle a deeper build, standing on every skill before it. Five movements per cycle:

1. **SCOUT — find the highest-leverage frontier.** Re-scan your own code, the field (the open agent
   apps), and the substrate (vault / graph / provenance / RRF). Ask the one question that decides
   everything: *what single integration, built this cycle, would most make the frontier apps look like
   demos?* Web-verify. Name the crux. One frontier per cycle — the deepest, not the easiest.
2. **FORGE — build it deeply, by COMPOSING your skills.** Implement the frontier to enterprise depth,
   wired into the substrate, connected as far as the architecture theoretically allows — and **actively
   invoke your accumulated skills to do it** (chain them; a new build reuses prior breakthroughs, it
   does not re-derive them). The library is your leverage: if a skill applies, USE it. In the web UI +
   backend fork; never native SwiftUI. **The deliverable is the shipped, working build — not the skill.**
3. **TEMPER — harden + thermonuclear review.** The four lenses + the deepest `/code-review` you can
   invoke. Zero open HIGH. Zero test regressions. Verified in the running app, not a compile.
4. **CRYSTALLIZE — forge a skill (the compounding step; NEVER skip it).** Distill the cycle's
   breakthrough into a NEW, reusable `SKILL.md` under `.claude/skills/experimental-<slug>/` — a named,
   described, invocable capability **plus the methodology to reproduce that whole CLASS of integration**.
   Where the breakthrough is a user-facing agent capability, ALSO write the product skill the embedded
   agent itself can invoke. Update `.claude/skills/EXPERIMENTAL_SKILLS_INDEX.md`. **The skill must
   capture a genuinely reusable CLASS you WILL invoke in later cycles — not a one-off changelog.** A
   cycle that ships a build but leaves behind nothing reusable has under-compounded; a "skill" no future
   cycle ever uses is dead weight to merge or prune, never a trophy. This is how the system gets godlier
   each loop instead of merely bigger — each skill makes the next cycle's build cheaper and deeper.
5. **ASCEND — raise your own bar.** In `EXPERIMENTAL_R.md`'s cycle log, record what this cycle made
   possible and — harder — *what it now makes possible next*. Define the next cycle's bar ABOVE this
   one's. Commit. Loop.

**Invariants across all cycles (never violated):** **from Cycle 2 on, every cycle USES ≥1 prior skill to
build the new frontier — a cycle that ignores the library has failed to compound.** Skills exist to
BUILD, not to collect: any skill no later cycle invokes is reviewed, merged, or pruned (no trophy
skills). Strictly additive (never regress a prior feature or skill); honest capability (never fake); the
DoD below gates EVERY cycle; the skill library is sacred — only extended, never broken; verify in the
running app every cycle. By cycle N, the surface does things no agent app on earth does — *because* each
build stood on the last — and `.claude/skills/experimental-*` reads like a grimoire of profound,
load-bearing integrations the frontier apps cannot match.

## DEFINITION OF DONE — per cycle (all — proven in the running app, not a compile)
- **DoD-∞** — Every cycle SHIPS a profound build (a real feature + deep connection, live in the running
  app), USES ≥1 prior skill to build it (from Cycle 2 on), and forges a new *reusable* skill + updates
  the index + raises the bar. The build is the deliverable; the skill is the leverage — never skills for
  their own sake, never a build that ignores the library.
- **DoD-A** — `AGENT_APP_FIELD_STUDY.md` + `EXPERIMENTAL_DEEP_AUDIT.md` committed; every finding cited.
- **DoD-B** — Thermonuclear review run; every CONFIRMED HIGH fixed; re-review clean.
- **DoD-Foundation** — De-branded (grep-gated 0), boots into the vault (no picker), six engines
  selectable + live catalog, Epistemos theme worn (light+dark), vault MCP live to the engine, **Prompt
  Forge upgrades a submitted prompt (diff shown + intent preserved + vault-cited)**. Screenshot each.
- **DoD-C** — At least the C1 vault-grounded-citation feature AND provenance write-back work end to end:
  a transcript where the agent searches the user's notes, cites them, and writes a provenance note back
  to the vault. Plus the C2 gaps from the field study closed. Screenshots/transcripts.
- **DoD-D** — Every DISCONNECTED item from A2 is CONNECTED (re-run the audit; it shows zero open).
- **DoD-E** — Hardening report, zero open HIGHs; zero test regressions; perf budgets green.
- **DoD-Thesis** — A short written argument (in `EXPERIMENTAL_R.md`) for *why this surface now exceeds
  Codex and the Claude Desktop app*, grounded in the shipped features — not aspiration.

## EXECUTION RULES (do not violate)
1. **Research-first, always.** Read canonical source + the plan before editing; verify current
   code/logs; web-verify current-API/model facts. Never pattern-match from memory.
2. Phases A → B → C → D → E, in order. **Commit after every coherent change** (build green, arm64,
   `CODE_SIGNING_ALLOWED=NO`; never two `xcodebuild`s at once). Verify in the RUNNING
   `Epistemos-Experimental` build — a compile is not evidence of a feature.
3. **Do not stop while any DoD is unmet.** Do not re-audit the shim as busywork. Do not add native
   SwiftUI. Do not fake capability. If a scheduled/loop wrapper drives you with an older prompt, this
   file supersedes it.
4. Rails: the vendored 1Code fork + all study clones live in `.research-clones/` (gitignored, NEVER
   committed, NEVER `git add -A`); every in-place fork edit gets a `PATCH_LEDGER.md` row; overlay in NEW
   renderer/backend files where possible; provider keys stay in Keychain, never in webview JS; do not
   touch the June lane or unrelated code; report honestly (no "done" without the DoD proof).

---

**The bar, restated so it cannot be missed:** the owner opens the Experimental surface and it is not
"1Code with a theme." It is an agent that *knows their vault*, cites it, writes back to it with
provenance, remembers across sessions, reasons over their graph, runs six engines, and is the most
hardened, most observable, most reliable agent surface they have ever used — measurably better than
Codex and the Claude Desktop app, because those apps cannot live where this one lives. Build that. Prove
it. Leave a trail (the corpora, the audit, the review, the thesis) worth studying.
