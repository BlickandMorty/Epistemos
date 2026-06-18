# EPISTEMOS MASTER LOOP PROMPT (2026-06-17)

> **How to run this:** open a terminal in `/Users/jojo/Downloads/Epistemos`, run
> `claude`, and paste everything from the line `=== BEGIN LOOP ===` to the end.
> The prompt itself encodes the loop discipline. If you want it self-paced, run
> `/loop` first and paste it as the loop body. Do **not** add an interval — let
> it self-pace one slice at a time.
>
> This file is the source of truth for the backlog. The loop should re-read it
> at the top of each pass and update the "STATUS LEDGER" at the bottom as items
> land.

---

```
=== BEGIN LOOP ===

You are Claude Code working on Epistemos, a macOS-native PKM with on-device +
cloud AI. You are in a FOREVER LOOP. Your owner (Jordan, solo dev, M2 Pro 16GB)
has told you repeatedly: keep working and hardening, build + commit each slice,
and DO NOT stop to ask for permission or say "done and waiting." Only stop for a
genuinely destructive/irreversible action or an architecture fork you cannot
resolve from the code + docs.

────────────────────────────────────────────────────────────────────────
NORTH STAR + FOUNDING THESIS (OWNER 2026-06-17e — read EVERY pass; this is WHY)
────────────────────────────────────────────────────────────────────────
Ambition: make Epistemos STELLAR — "as complex as a brain, as simple as an app,
as fast as a jet." End-state = REAL AGENTS and a genuine CODEX + CLAUDE(-Code/
desktop) REPLACEMENT, local-first, that you can also TRAIN (Unsloth) and serve
(Osaurus parity): a true brain you use → train → run.
FOUNDING THESIS (the owner's original research — honor it in every architecture
choice): local AI is made USEFUL by being DYNAMICALLY DETERMINISTIC + VERIFIABLE,
NOT by scaling a giant local model. So bias ALL substrate/architecture work toward
the owner's HYPER-DETERMINISTIC SCHEMA + verifiability machinery from the custom
runtime — grammar / json-schema-constrained generation (LocalToolGrammar + the
json_schema FFI), deterministic provenance (ClaimLedger / AnswerPacket / replay),
the Cognitive DAG, the Knowledge Core, and an explicit "why this route" — applied
to the SMALL local models (Fast/Think/Code). Use ALL of that custom-runtime
determinism work EXCEPT the large-local-model (70B / System G) runtime, which
stays owner-gated (PRIORITY 5 "THEN large-model"). Determinism + proof over raw
size is the app's edge.

READ FIRST (one time, before the first slice): CLAUDE.md (auto-loaded — project
rules + file map + constraints); then these memory files for current state —
memory/foundation_lineup_pivot_2026_06_16.md, memory/gguf_runtime_seam_2026_06_16.md,
memory/mlx_gemma4_unsupported_2026_06_16.md, memory/gemma_qwen_oom_swap_fix_2026_06_16.md,
memory/osaurus_agent_builder_direction_2026_06_16.md, memory/system_g_runtime_map_2026_06_14.md.
Run `git log --oneline -30` to see the latest landed work. Then start at P1.5.

────────────────────────────────────────────────────────────────────────
LOOP DISCIPLINE (every pass)
────────────────────────────────────────────────────────────────────────
1. RESEARCH-FIRST (CLAUDE.md rule): before touching anything, grep
   docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md, read the canonical source it
   names, then verify against current code + logs. Quick pass for simple edits,
   deep pass for architecture.
2. ONE SLICE = one focused change + its build + its commit. Never batch unrelated
   changes. Commit after EVERY change (the owner has lost work to an un-committed
   tree before — this is non-negotiable).
3. BUILD before commit:
   `xcodebuild -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | xcbeautify`
   Reaching CodeSign/link with 0 compile errors == compile OK. For tests:
   `xcodebuild build-for-testing -scheme Epistemos -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO`.
   Rust: `cargo test --manifest-path agent_core/Cargo.toml` (REAL execution —
   use it for backend hardening; never pkill cargo mid-run).
   NOTE: headless Swift TEST EXECUTION hangs — you can only COMPILE-verify Swift
   tests; the owner runs Product▸Test. So reason every test assertion to
   certainty before committing; a red unrunnable test is worse than none.
4. After each slice append one line to docs/AGENT_PROGRESS.md and tick the STATUS
   LEDGER in docs/EPISTEMOS_MASTER_LOOP_PROMPT_2026_06_17.md.
5. The owner is usually on an UN-rebuilt binary, so UI you can't see is risky.
   When you ship UI, ground it in the existing component (read the file), keep it
   behind the existing simplified-lineup flag where one exists, and never break
   the default local-only experience.
6. HARDEN AFTER EVERY PHASE (owner mandate 2026-06-17e). When a priority/phase
   finishes, before starting the next: (a) re-read THIS file + re-scan ALL owner
   hotfixes so no requested item silently drops — the owner's rule is "make sure
   none of my requests are missed"; (b) run the full build + Rust tests +
   compile-verify Swift tests and fix any regression; (c) grep the honesty
   constraints on what you just shipped (no hidden route, no fake config, MAS/Pro
   boundary intact, keys in Keychain); (d) append a one-line "HARDENED <phase>"
   entry to docs/AGENT_PROGRESS.md naming what you verified. A phase is NOT done
   until it is hardened.
7. RECURSIVELY IMPROVE THIS PROMPT (owner 2026-06-17e). Each pass, also ask: does
   this file still aim at the NORTH STAR? If a priority is vague, mis-ordered, or
   missing a step toward "stellar local-first brain / real Codex+Claude
   replacement / determinism + verifiability," sharpen it — append or clarify,
   NEVER silently delete an owner item — and note the prompt edit in
   AGENT_PROGRESS.md. The backlog should get better every loop, not just consumed.

────────────────────────────────────────────────────────────────────────
NON-NEGOTIABLE HONESTY CONSTRAINTS (CLAUDE.md — these beat any task)
────────────────────────────────────────────────────────────────────────
• NEVER silently route to a model the user didn't pick. No hidden Qwen, no
  invisible fallback. If the selected local model can't run, surface a VISIBLE
  blocker (see P1.4) — never substitute silently.
• REAL APIs only. No fake features, no config UI for fields not wired to runtime.
• HONEST capability gating. Local models = chat + reasoning; multi-step tools via
  cloud or the Pro harness. Never fake agent capability for a local model.
• NO HIDDEN SIDECAR. GGUF/llama-cli is Pro-only + flag-gated
  (EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0), MAS-forbidden. In-process only on the
  MAS path. Runtime-plural / 70B is owner-gated.
• Keys in Keychain, NEVER UserDefaults. Stream every token. Preserve thinking
  blocks on tool_use. No try!, no force-unwrap, no print() in prod. Zero test
  regressions against the 2,679-test suite. Never commit model files.

────────────────────────────────────────────────────────────────────────
WHAT'S ALREADY DONE (do NOT redo — verify only if you touch it)
────────────────────────────────────────────────────────────────────────
Qwen removed from the picker + stored-selection migration onto the foundation
lineup; Fast/Think/Code tier source of truth (EpistemosFoundationLineup.swift);
mode buttons Fast/Think/Code; one-tap foundation-package install; Settings tier
display; icon-only collapsed model button; in-chat agent switcher (model popover
"Agents" section); Companion advanced config (custom system prompt + output
JSON); proven GGUF llama-cli runtime seam wired (Pro, flag-off); local
OpenAI/Ollama-compatible server (#46); VibeThinker-3B added as Think; Gemma
MLX/GGUF honest reconciliation; loop budgets raised 1/1/3 → 5/10/15; agentic
system-prompt manifest when tools present; main-chat context sidebar visible;
foundation-lineup regression tests.
DONE 2026-06-17: PICKER SIMPLIFIED — the runtime popover now shows three mode
rows (Fast/Think/Code) + ONE "Use cloud" toggle; Routing/Fallback/per-model
rows/cloud detail/Temporary Chat fold under an "Advanced" disclosure
(simplifiedRuntimePopover + cloudToggleSection in RootView, gated on
simplifiedLineupActive). Root-cause fix: operatingModeCapabilities now offers all
three efforts under simplified+foundation (a GGUF Gemma used to collapse modes to
Fast-only). Search-page button shows the tier ("Epistemos Fast"), not the model.
"Gemma 12B always selected" fixed: migration now picks the headroom-aware Fast
model (E4B on 16 GB) not the largest; a stored 12B pick falls to E4B under Fast
when memory-tight. Composer "Send on cloud" button (switches to cloud; strict
per-turn-no-default-change deferred). So P1.1/P1.2/P1.3 below are ALREADY DONE.
OWNER HOTFIX 2026-06-17: stale Think routes/prompts still exist in old paths.
Think is the actual reasoner, VibeThinker-3B. It must NEVER resolve, label, route,
or prompt as Gemma 4 12B. Gemma 4 12B is allowed only as Fast's hard-query size
or the Code/coder tier. Audit all `.thinking`, `Think`, `reasoning`, prompt,
label, fallback, migration, and effective-selection paths after P1.4.
OWNER HOTFIX 2026-06-17b: preserve Apple Intelligence. The simplified picker must
NOT erase Apple Intelligence. Treat it as a first-class native Apple/Foundation
route: selectable when macOS reports it available, visibly unavailable when it is
not, never counted as "cloud", and never silently substituted for a chosen local
or cloud model. It can be the basis for OS/Foundation features that are already
wired (rewrites, summaries, classifiers, device/sidecar generation), but do not
fake tool-calling/agent capability for it.
OWNER HOTFIX 2026-06-17c: visible installs + understandable Fast effort. Model
downloads/installations need a real progress UI (bytes/percent/stage when the
provider exposes it; honest indeterminate progress only when it does not). Fast
mode's per-query sizing must be visible/explainable as low / medium / high effort
or equivalent, so the user can tell why a query ran E2B vs E4B vs 12B.
OWNER HOTFIX 2026-06-17d: simple vault questions must resolve. The exact prompt
"please tell me the best essay I have in my vault" is an acceptance test: chat
must search the active vault/memory/knowledge index, inspect candidate essays,
rank with visible evidence, and answer with title/path/reason. If no vault is
connected or indexed, it must say that visibly and offer the next action. It must
not answer from model priors or claim it cannot access the vault when the vault
is available.
OWNER HOTFIX 2026-06-17e: BIG ROBUSTNESS BATCH ("make my app feel robust frl —
NO COMPROMISE, miss nothing"). Capture EVERY item below; new build work lives in
PRIORITY 7 + the RESEARCH PHASES block, and it ESCALATES P3 (Osaurus) and P4.1
(Unsloth). All non-negotiable honesty + MAS/Pro constraints still beat every task.
  1. HARDEN AFTER EVERY PHASE — see Loop Discipline #6. After each phase, re-scan
     these hotfixes so nothing the owner asked for drops.
  2. OSAURUS — DEEPER dive. Deep-read ALL of it (esp. the large Swift surface),
     truly reading every candidate, and evaluate making Epistemos a COMPLETE
     Osaurus REPLACEMENT (full local OpenAI/Ollama server + agent-builder parity).
     Osaurus is mature, MIT — a full adopt is now ON THE TABLE, not just patterns.
     Still cherry-pick, but DEEPLY; weigh full-adopt vs pattern-adopt for each
     piece via F-ProprietaryCompression-ProvenanceGate (quarantine→inspect→
     benchmark→choose direct_import/adapter_wrap/clean_room_rewrite). Apply deep
     optimizations on what lands. (Escalates P3 — see P3.5.)
  3. UNSLOTH — evaluate porting the WHOLE thing to add on-device/desktop MODEL
     TRAINING / fine-tuning, so the app becomes a true "brain" (use → train →
     run a model you trained). UI must be PIXEL-ART MINIMAL + THEME-AWARE like the
     rest of the app. Honest gating: training is Pro/dev-only, OFFLINE, never on
     the MAS path; it produces GGUF the existing llama-cli lane already runs. Never
     fake a training capability. (Escalates P4.1 — see P4.1 note + PHASE R-UNS.)
  4. CAPABILITY CEILING — make EVERY chat capability legit from Fast → tools: push
     the ABSOLUTE limit of what the MAS build can honestly do, PLUS the Pro
     variant's extra reach. Audit + close every gap FIRST (P7.1) — this gates the
     Code chat and the Osaurus full-port decision.
  5. HTML WORKSPACE is BROKEN (owner can't see the code, has been broken a while).
     Fix it, then upgrade to a robust HTML + CANVAS workspace with a LIVE VIEWER
     where chat can directly drive an HTML <canvas> "screen" (like the popular
     GitHub html-canvas-chat projects). Theme-aware, pixel-art minimal. (P7.2.)
  6. TERMINAL + CONSOLE must ACTUALLY WORK (currently don't). Pro/dev-gated, real
     I/O, security.rs hardening; honest "not available" on MAS. (P7.3.)
  7. "CODE" TOGGLE on the SEARCH screen → flips the chat into an OpenCode-style
     code chat themed to the app (pixel-art minimal, theme-aware) — port that
     surface. Build only AFTER the capability ceiling (P7.1) is met. (P7.4.)
  Research-first: run the RESEARCH PHASES (GitHub / HuggingFace / arXiv / X) to
  source each item before building, and re-read the LOCAL non-large-model research
  + docs canon. Combine findings INTO the app — honestly, no fake surfaces.

────────────────────────────────────────────────────────────────────────
PRIORITY 1 — THE SIMPLE PICKER  (P1.1/P1.2/P1.3 ✅ DONE 2026-06-17. Remaining:
P1.4 honesty blocker, P1.5 per-query effort sizing. START THE LOOP AT P1.5.)
────────────────────────────────────────────────────────────────────────
For history — current state was (owner screenshot 2026-06-17): the popover showed a "Runtime"
header, a "Routing → Fast → Gemma 4 12B QAT GGUF" row, a "Fallback on failure"
toggle, three separate Gemma model rows (E2B/E4B/12B each with "Agent OFF /
On-device model / info"), separate "Cloud Provider" + "Cloud Model" expanders,
and "Temporary Chat" — all in the main picker. The owner's words: "i dont want
taee see the messy model picker shit i literally want it ti be simple… it should
say fast and three efforts think and then code… it should not even have the
model… cloud can be like a toggle… when i send a query i can have a button that
says route to cloud model with the selected cloud one."

TARGET (the whole point):
  The default popover is THREE mode rows and almost nothing else:
     ⚡ Fast    — "Gemma 4, sized to the task"
     🧠 Think   — "VibeThinker reasoning"
     ⌘ Code    — "Gemma 4 12B coder"
  + one clean **Cloud** toggle (off by default).
  + Apple Intelligence stays reachable/selectable as a native Apple route when
    available (not hidden behind Cloud, not removed by the simplified picker).
  + Fast shows the current/expected effort size (low / medium / high or similar)
    instead of making E2B/E4B/12B routing invisible.
  + Model installs show progress in the install sheet and model rows.
  + a per-send **Route to cloud** button (only when a cloud provider is
    configured) that sends THIS query to the selected cloud model without
    changing the local default.
  Everything else (Runtime/Routing/Fallback/per-model rows/Cloud Provider+Model
  detail/Temporary Chat) moves behind a single collapsed "Advanced ▸" disclosure
  or into Settings. The model itself is NEVER shown as a required choice.

SLICES (build + commit each):
  P1.1  ✅ DONE. RootView.swift → LocalModelToolbarMenu.modelPopover: when
        EpistemosFoundationLineup.simplifiedLineupActive, render ONLY the three
        mode rows (Fast/Think/Code) + Cloud toggle. Move Runtime header, Routing
        row, Fallback toggle, the per-Gemma model rows, and Temporary Chat into a
        collapsed "Advanced ▸" DisclosureGroup (default closed). Keep the legacy
        full popover for the non-simplified flag.
  P1.2  ✅ DONE. Cloud as a single toggle: replace the "Cloud Provider / Cloud Model"
        twin expanders with one "Use cloud" Toggle bound to
        inference.setCloudModelsEnabled / activeAIProvider. When ON, show ONE
        compact "GPT-4o ▸" line that opens the provider/model detail (the
        existing pickerCloudSection) inside Advanced — not at top level.
  P1.3  ✅ DONE (basic). "Send on cloud" button beside Send in ChatInputBar,
        visible only when a cloud provider is configured. CURRENT behavior:
        switches the chat to cloud (toggle reflects/reverses it). FOLLOW-UP (not
        yet done): strict per-turn override that leaves the local default
        untouched — thread an optional `routeOverride: ChatModelSelection?`
        through submitQuery → the ~11 effectiveChatSurfaceSelection resolution
        sites so one send goes cloud while the default stays local.
  P1.4  Honesty blocker (#43): when the effective local selection can't actually
        run (dynamic free memory too low — mirror fittingLocalAgentTextModelID's
        localAgentModelFitsCurrentMemoryBudget for the primary chat model),
        DISABLE Send and show a one-line reason ("Not enough free memory for
        Gemma 4 12B — free memory, pick a smaller tier, or route to cloud").
        Never silently swap. Add a pure-logic helper + reasoned compile-verified
        test.
  P1.5  Fast "three efforts" = per-query complexity sizing: Fast auto-picks
        E2B (trivial) → E4B (medium) → 12B (hard) per query via
        OverseerComplexityRouter. Needs a streamGeneral seam that passes the
        per-turn sized model down. Keep the explicit within-tier pick override
        (already respected by effectiveLocalTextModelID(for:)).
  P1.6  OWNER HOTFIX — Think stale-route audit. Search + fix every old path where
        `.thinking` / Think / reasoning still routes, labels, migrates, or
        prompts as Gemma 4 12B. Under the simplified foundation lineup:
        Fast = Gemma sized by complexity, Think = VibeThinker-3B, Code = Gemma 4
        12B coder. Add regression tests at the effective selection, prompt/label,
        and migration/fallback seams so Think can never silently fall back to
        Gemma 12B again.
  P1.7  OWNER HOTFIX — Apple Intelligence preservation/selectability audit. Keep
        Apple Intelligence as a visible native route in the simplified picker and
        chat/runtime labels when `appleIntelligenceAvailable` is true; show the
        existing unavailable reason when false. It is NOT cloud and NOT a hidden
        fallback. Audit RootView picker rows, ChatCoordinator effective selection,
        TriageService auto-routing, AgentCommandCenter brain list, PipelineService
        labels, NoteChatState, AFMSidecarGenerator/AppleIntelligenceService
        feature use, and tests. Preserve the current honest gate: Apple
        Intelligence cannot drive Agent/tool-calling mode unless Apple exposes a
        real tool protocol.
  P1.8  OWNER HOTFIX — model download/install progress UI. Audit
        LocalModelManagerSheet, one-tap foundation-package install, model rows,
        ModelDownloadManager / LocalModelInfrastructure progress surfaces, and
        any async download streams. Show per-model progress while installing
        (percent/bytes/stage when known; honest spinner + status when unknown),
        persist/resume/cancel state where existing runtime supports it, and add
        tests for progress-state mapping so downloads never look frozen.
  P1.9  OWNER HOTFIX — Fast effort visibility. The simplified Fast mode must make
        the per-query effort understandable: low/trivial → E2B, medium → E4B,
        high/hard → 12B (subject to memory headroom). Surface the effort in the
        composer/picker/diagnostic route reason without exposing raw model choice
        as the required default decision. Add a pure route-reason helper + tests.

────────────────────────────────────────────────────────────────────────
PRIORITY 2 — FULL AGENTIC CHAT (Codex / Claude-desktop parity)
"make my chat an actual codex or claude desktop app with full agentic behavior,
using local AND cloud models, diff + git access, skills/superpowers, mcps,
dependencies — all of it, accessible through the chat. agents + app search the
memory, give it all the control it can get." (OpenCode comes LATER, only once the
chat has everything.)
────────────────────────────────────────────────────────────────────────
The BACKEND already exists — agent loop, tools (agent_core/src/tools/registry.rs:
memory / knowledge.recall / skills / file_ops / web_fetch / shell / browser), MCP
backend (omega-mcp + MCPBridge), Companion system, AgentCommandCenterState tool
catalog (toolToggles / availableTools / toggleTool / refreshToolCatalog). The gap
is CHAT SURFACING. Build a "capability explorer" reachable from the composer:
  P2.1  In-chat TOOL TOGGLES: a compact panel (reuse AgentCommandCenterState)
        listing available tools with on/off, so the user sees + controls what an
        agent can do. Honest gating: tools that need cloud/Pro are labeled.
  P2.2  MEMORY access affordance: confirm memory + knowledge.recall tools are
        available to agents by default and surface a visible "Searching memory…"
        capability (the owner explicitly wants agents to search memory). Verify
        the tools actually read the app-side vault/Knowledge Core.
        ACCEPTANCE QUERY: "please tell me the best essay I have in my vault"
        must search the active vault/memory/Knowledge Core, inspect candidate
        essays, rank with evidence, and answer with title/path/reason. If the
        vault is unavailable or unindexed, surface that blocker and next action
        instead of a generic chat answer. Add an integration-style regression
        around the route planner/tool-selection path.
  P2.3  MCP MANAGEMENT UI in chat: add/enable/disable MCP servers via MCPBridge
        (Pro). Honest: only show servers actually wired.
  P2.4  In-chat SKILL creation + browser (agent_core/src/agent_runtime skills +
        procedural memory). Let the user create/run a skill from chat.
  P2.5  GIT + DIFF as tools (Pro): surface git status / diff / commit / branch as
        agent tools with the subprocess hardening in agent_core/src/security.rs.
        MAS build must not expose shell/git; Pro only.
  P2.6  Agent meta-builder (#47): extend the Companion (the tamagotchi — KEEP the
        fluid animation) with an osaurus-style Agent config (name, system prompt,
        tool selection, output schema). Foundation landed 2f3ae4a5c +
        CompanionCreationFlow advanced config. Only expose fields wired to
        runtime (no fake config).

────────────────────────────────────────────────────────────────────────
PRIORITY 3 — OSAURUS DEEP DIVE (cherry-pick, NEVER fork)
"so many things in osaurus that I know can be copied or cherry-picked… 400k of
swift." Adopt patterns natively (native Swift, MIT) — do NOT port the repo.
────────────────────────────────────────────────────────────────────────
  P3.1  Deep-read osaurus; write docs/OSAURUS_DEEP_DIVE_2026_06_17.md mapping
        every reusable pattern → where it lands in Epistemos (agent_core / Omega
        / Companion / local server). ~80% overlaps the existing stack; extract
        the 20% that's genuinely new.
  P3.2  Verify the local OpenAI/Ollama server (#46, ResponseWriters/OsaurusServer
        shape) is wired + MAS-safe (no subprocess from the notarized app).
  P3.3  Sentinel stream + dynamic-tool schema → fold into agent_core tool-call
        parsing where it beats the current path.
  P3.4  Containerization sandbox (Pro-only) for isolated tool execution — gate
        behind pro-build, never on the MAS path.

────────────────────────────────────────────────────────────────────────
PRIORITY 4 — MODEL SUBSTRATE POLISH
────────────────────────────────────────────────────────────────────────
  P4.1  unsloth for Gemma fine-tuning (#44): research + document an OFFLINE
        fine-tune lane (NOT runtime) that produces GGUF the existing llama-cli
        lane already runs. docs/ only until owner approves a model.
  P4.2  EAGLE3 speculative decoding (#49, llama.cpp #18039) for 2-3× GGUF
        speedup — research + a flag-gated draft-model seam in the GGUF runtime.
  P4.3  Grammar tool loop on-device validation (#41): FFI json_schema is wired
        (run_local_gguf_generation + with_json_schema); validate the local Pro
        tool loop end-to-end with `llama-cli --json-schema` honest Gemma tools.
  P4.4  Routing rules: make local-vs-cloud + complexity routing explicit and
        honest (TriageService / ConfidenceRouter / OverseerComplexityRouter) —
        a readable "why this route" the picker/diagnostics can show.

────────────────────────────────────────────────────────────────────────
PRIORITY 5 — ARCHITECTURE  (owner: the NON-large-model work is MORE important
than the 70B — do it FIRST, then the 70B.)
────────────────────────────────────────────────────────────────────────
"NON-LARGE-MODEL architecture" = the owner's local research: SUBSTRATE HEALTH +
the ENTIRE SUBSTRATE, the KNOWLEDGE CORE, and ALL architectural / optimization /
performance work that does NOT rest on the large-model runtime — driven by the
FOUNDING THESIS (dynamic determinism + verifiability; see NORTH STAR). Make local
AI useful via hyper-deterministic schemas + proof, not size. This is MORE
important than the 70B. Pick from the canonical register, research-first:
  • Substrate health + the whole substrate: keep every track honest, measured,
    promoted only at T4+ (ARCHITECTURE_TIER_PROMOTION_CANON); push the
    determinism/verifiability seams (grammar/json-schema, provenance, "why this
    route") onto the SMALL-model paths (Fast/Think/Code).
  • App-wide optimization + performance (memory / energy / latency) as
    first-class architecture slices, not afterthoughts.
  • Knowledge Core cutover (flag knowledgeCoreRuntimeV0): production-UI binding
    decision + content-subscription (see memory kc_cutover_slice3).
  • Cognitive DAG (Phase 8) + Provenance console + Halo + Simulation assets +
    Schema-First GenUI dispatcher + XPC mastery — per docs/fusion canon and the
    Substrate Track Register T0–T15. Each is a real, shippable, MAS-scoped slice;
    promote only to T4+ per ARCHITECTURE_TIER_PROMOTION_CANON (compiled in the
    right scope, reachable, visible, verified, logged, rollback-bound,
    AnswerPacket-visible).
THEN large-model:
  • P4/#17 70B System G custom runtime — already BUILT + owner-gated
    (agent_runtime_v2/system_g_runtime.rs + RealSystemGRunSeam.swift /
    RuntimeRouter / AnswerPacket / SovereignGate). Runtime acceleration stays a
    CANDIDATE until explicit owner approval + MAS/Pro boundary review +
    no-hidden-fallback proof + RunEventLog + AnswerPacket + rollback + harness
    witnesses land. Do NOT arm without the owner.

────────────────────────────────────────────────────────────────────────
PRIORITY 6 — BRAND / POLISH (owner de-prioritized — do AFTER P1–P3, or when a
slice naturally touches Settings/chat headers)
────────────────────────────────────────────────────────────────────────
P6.1  Real AI provider logos in Settings + chat, in a STRATEGIC BLACK-AND-WHITE
      (monochrome) style so the app "feels legit": Google, Claude, Claude Code,
      Anthropic, OpenAI, Apple, Kimi, Hermes. Use the Claude Code logo for
      agent-mode-when-on-Claude. Source: lobehub @lobehub/icons (MIT, mono+color,
      <title>/viewBox="0 0 24 24"/fill="currentColor"). The owner handed specific
      assets to a past chat (not recoverable as files) — do NOT hunt for them;
      complete the set from lobehub. Wire per-provider in the model picker rows,
      Settings inference rows, and chat message headers. Honest: only show a logo
      for the provider actually serving the turn.
P6.2  "Run complex things from a simple query" polish: once P1.5 + P2 land,
      verify a plain user prompt actually drives the multi-step agent loop end to
      end (tools + memory + skills) and reads as useful, not a single shot.
P6.3  Dependencies/package tooling as an agent capability (Pro): if the owner
      wants the chat to manage project deps (npm/cargo/etc.), surface it as an
      explicit Pro tool with security.rs hardening — NOT on the MAS path.

────────────────────────────────────────────────────────────────────────
PRIORITY 7 — ROBUSTNESS SURFACES (OWNER HOTFIX 2026-06-17e — "make my app feel
robust frl, no compromise"). Honesty + MAS/Pro boundary apply to ALL of P7:
anything needing shell/subprocess/training/git is Pro/dev-only + flag-gated; on
the MAS path surface the honest capability, never a fake one.
────────────────────────────────────────────────────────────────────────
  P7.1  CAPABILITY CEILING audit (do FIRST — gates P7.4 + P3 full-port). Enumerate
        the full chat stack — Fast/Think/Code, memory, knowledge.recall, skills,
        file_ops, web_fetch, shell, browser, git/diff, MCP — and for EACH answer:
        is it really wired to runtime, MAS-honest, and reachable from the chat
        composer? Push the absolute MAS limit; document precisely what only the Pro
        variant can reach. Close every gap or file it honestly in
        docs/CAPABILITY_CEILING_2026_06_17.md. No fake config, no hidden route.
  P7.2  HTML WORKSPACE — broken (owner can't see the code). (a) Diagnose + fix the
        existing workspace so code is visible again (read the current HTML/Epdoc
        workspace + WKWebView wiring; editors share a WKProcessPool — check for a
        blank/dead webview, broken bundle path, or CSP). (b) Upgrade to a robust
        HTML + CANVAS workspace with a LIVE VIEWER: a rendered <canvas> "screen"
        the chat can drive directly (write/patch HTML+JS → live re-render),
        modeled on the popular GitHub html-canvas-chat projects (PHASE R-HTML).
        Theme-aware, pixel-art minimal. Stream edits; NO runtime npm (MAS sandbox).
  P7.3  TERMINAL + CONSOLE must actually work (currently don't). Wire a real
        terminal/console surface (Pro/dev build; agent_core terminal.rs already
        carries the env-clear/allowlist subprocess hardening) with the security.rs
        guarantees. On MAS show the honest "not available in this build" state.
        Add tests for the I/O + hardening seam.
  P7.4  "CODE" TOGGLE on the SEARCH screen — a toggle at the top of the search
        screen that flips the chat into an OpenCode-style code chat, themed to the
        app (pixel-art minimal, theme-aware). Port that surface/UX, wired to the
        SAME honest capability stack from P7.1 (local + cloud, diff/git as Pro
        tools). Build only AFTER P7.1 passes so it is real, not a shell.
  P3.5  OSAURUS FULL-REPLACE EVALUATION (escalation of P3). After P3.1's deep
        dive + P7.1, decide full-adopt vs pattern-adopt per piece via the
        ProvenanceGate, with the explicit goal of Epistemos being a COMPLETE
        Osaurus replacement (local OpenAI/Ollama server + agent builder). Write
        the decision + plan into docs/OSAURUS_DEEP_DIVE_2026_06_17.md, then land
        the chosen slices with deep optimization. MAS/Pro boundary intact.

────────────────────────────────────────────────────────────────────────
RESEARCH PHASES (OWNER HOTFIX 2026-06-17e — research-first, source everything;
write a short docs/ note with primary/official sources + the decision before
building each surface). Web validates; the LOCAL research corpus leads on the
non-large-model architecture.
────────────────────────────────────────────────────────────────────────
  PHASE R-OSA   Osaurus: deep-read the repo + its issues/releases. Map
                full-replace vs cherry-pick → docs/OSAURUS_DEEP_DIVE_2026_06_17.md.
  PHASE R-UNS   Unsloth (GitHub + HuggingFace + arXiv): QLoRA/fine-tune → GGUF
                lane, desktop training-UI feasibility, license posture → P4.1 doc.
  PHASE R-OC    OpenCode + similar code-chat UIs: the surface/UX to port for P7.4.
  PHASE R-HTML  GitHub html-canvas-chat projects: pick the live-viewer + canvas
                pattern for P7.2.
  PHASE R-ARCH  NON-LARGE-MODEL architecture = SUBSTRATE HEALTH + entire substrate
                + KNOWLEDGE CORE + app-wide optimization/perf, driven by the
                FOUNDING THESIS (dynamic determinism + verifiability / hyper-
                deterministic schemas for the SMALL local models). MORE important
                than the 70B. Re-read the LOCAL canon —
                docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md, the Substrate
                Track Register T0–T15, the TURBOVEC/QAT canon, and the Knowledge
                Core + Cognitive DAG + provenance/AnswerPacket docs — and feed
                PRIORITY 5. EXCLUDE the large-local-model runtime (owner-gated).
  Also sweep GitHub / HuggingFace / arXiv / Twitter(X) for anything that
  strengthens the above and combine it INTO the app, honestly.

────────────────────────────────────────────────────────────────────────
KEY FILES
────────────────────────────────────────────────────────────────────────
Picker/UI:      Epistemos/App/RootView.swift (LocalModelToolbarMenu, modelPopover,
                splitToolbarControls, ChatBrainPickerMenu),
                Epistemos/Views/Chat/ChatInputBar.swift,
                Epistemos/Views/Settings/SettingsView.swift (LocalModelManagerSheet)
Lineup truth:   Epistemos/Engine/EpistemosFoundationLineup.swift,
                Epistemos/Engine/LocalModelInfrastructure.swift (GemmaQATRuntimeLadder),
                Epistemos/State/InferenceState.swift (effective/fitting model resolution)
Apple AI:       Epistemos/App/RootView.swift, Epistemos/App/ChatCoordinator.swift,
                Epistemos/Engine/PipelineService.swift, Epistemos/Engine/AFMSidecarGenerator.swift,
                Epistemos/State/AgentCommandCenterState.swift, Epistemos/State/NoteChatState.swift,
                EpistemosTests/TriageServiceTests.swift, EpistemosTests/PipelineServiceTests.swift
Agentic:        agent_core/src/tools/registry.rs, agent_core/src/agent_loop.rs,
                Epistemos/State/AgentCommandCenterState.swift,
                Epistemos/Omega/MCPBridge.swift, Epistemos/App/ChatCoordinator.swift,
                Epistemos/State/Companion/CompanionState.swift,
                Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift
Runtime seam:   agent_core/src/bridge.rs (run_local_gguf_generation),
                Epistemos/Bridge/LocalGgufRuntimeBridge.swift,
                Epistemos/Engine/LocalGgufCliRuntime / PipelineService.swift
Research index:  docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
Progress:        docs/AGENT_PROGRESS.md, docs/APP_ISSUES_AUTO_FIX.md
Acceptance:      "please tell me the best essay I have in my vault" must trigger
                 vault/memory search and produce an evidence-backed answer.

────────────────────────────────────────────────────────────────────────
START NOW. P1.1/P1.2/P1.3 are DONE (picker simplified, cloud toggle, Send-on-cloud
button, search button shows the tier, 12B no longer pinned). Begin at P1.5 (Fast
per-query effort sizing: trivial→E2B, medium→E4B, hard→12B via
OverseerComplexityRouter + a streamGeneral seam), then P1.4 (honesty blocker),
then PRIORITY 2 (agentic chat surfacing). Build, verify, commit each slice, and
continue down the list WITHOUT stopping to ask. Keep going until every priority is
done, then re-read this file and harden.
=== END LOOP ===
```

---

## STATUS LEDGER (the loop updates this)

| ID | Item | Status |
|----|------|--------|
| P1.1 | Picker → three mode rows + Advanced disclosure | ✅ DONE (2026-06-17) |
| P1.1b | Fix root cause: GGUF Gemma collapsed modes to Fast-only | ✅ DONE — `operatingModeCapabilities` offers Fast/Think/Code under simplified+foundation |
| P1.2 | Cloud as one clean toggle | ✅ DONE (folded into P1.1) |
| P1.3 | Per-query "Route to cloud" button | ✅ DONE (2026-06-17) — composer "Send on cloud" button; strict no-default-change per-turn deferred |
| P1.3b | Search button shows tier not model; stop pinning 12B | ✅ DONE (2026-06-17) — labelText→tier, migration + Fast headroom override |
| P1.4 | Honesty blocker: visible when local model can't run (#43) | ✅ DONE (2026-06-17) — `localChatModelMemoryBlocker` + `LocalChatModelMemoryGate`; disables Send + orange banner, "Send on cloud" stays open; Fast gates on smallest size; +5 tests |
| P1.5 | Fast "three efforts" per-query complexity sizing | ✅ DONE (2026-06-17) — `sizedFastLocalTextModelID` at the `routeDecision`/`effectivePolicyContext` seam; trivial→E2B/medium→E4B/hard→12B, memory-safe (16 GB caps at E4B), honors explicit picks; +6 tests |
| P1.6 | Think stale-route audit: Think must be VibeThinker, not Gemma 4 12B | ✅ DONE (2026-06-17) — fixed resolution nil-out, tier-representative pinning, and Overseer `.pro`→`.thinking` collapse; +1 regression |
| P1.7 | Apple Intelligence preservation: native selectable route, not cloud, not hidden fallback | ✅ DONE (2026-06-17) — `appleIntelligenceSection` top-level in the simplified popover; selectable/unavailable-with-reason; runtime audit confirms AI never erased; +1 test |
| P1.8 | Model download/install progress UI | ☐ TODO |
| P1.9 | Fast effort visibility: low/medium/high route reason | ✅ DONE (2026-06-17) — `EpistemosFastEffortSizing.effort` (low/med/high) + `fastEffortRouteReason` + live composer hint "Fast · Medium effort → Gemma 4 E4B"; +2 tests |
| P2.1 | In-chat tool toggles | ☐ TODO — ⚠️ HONESTY GATE: main chat tools come from `executionPlan.allowedToolNames` (Overseer plan), NOT `agentCommandCenter.toolToggles`. Wire the user's enabled set into the main-chat allowed-tool computation (ChatCoordinator) FIRST, then the UI — toggles must really gate runtime, not be fake config |
| P2.2 | Agents search memory (verify + surface), including "best essay in my vault" acceptance query | ☐ TODO |
| P2.3 | MCP management UI in chat | ☐ TODO |
| P2.4 | In-chat skill creation + browser | ☐ TODO |
| P2.5 | Git + diff as Pro tools | ☐ TODO |
| P2.6 | Agent meta-builder on Companion (#47) | ◐ foundation landed |
| P3.1 | osaurus deep-dive doc | ☐ TODO |
| P3.2–3.4 | osaurus server verify / sentinel stream / sandbox | ☐ TODO |
| P4.1 | unsloth fine-tune lane (research) (#44) — ESCALATED 2026-06-17e: evaluate full Unsloth port + desktop training UI (pixel-art, theme-aware, Pro/offline) | ☐ TODO |
| P4.2 | EAGLE3 spec decoding (#49) | ☐ TODO |
| P4.3 | Grammar tool loop on-device validation (#41) | ◐ FFI wired |
| P4.4 | Explicit honest routing rules | ☐ TODO |
| P5 | Non-large-model architecture, then 70B (#17) | ☐ TODO |
| P7.1 | Capability ceiling: Fast→tools all legit, absolute MAS limit + Pro variant | ☐ TODO |
| P7.2 | HTML workspace fix + canvas live-viewer (chat drives the screen) | ☐ TODO |
| P7.3 | Terminal + console actually work (Pro/dev) | ☐ TODO |
| P7.4 | "Code" toggle on search → OpenCode-style themed code chat | ☐ TODO |
| P3.5 | Osaurus full-replace evaluation (complete replacement decision + slices) | ☐ TODO |
| R-* | Research phases: Osaurus / Unsloth / OpenCode / HTML-canvas / non-LM arch | ☐ TODO |
