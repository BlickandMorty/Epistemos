# EPISTEMOS MASTER LOOP PROMPT (2026-06-17)

> ‼️ **READ-FIRST — LIVE AUTHORITY (added 2026-06-19, SUPERSEDES the P1–P6 backlog below for new owner asks).**
> The P1–P6 plan below is still valid, but the owner has streamed MANY newer requests captured verbatim in the
> AUTHORITY LEDGER. **At the top of EVERY pass, read these in order and treat them as the live build commitment
> (every item gets coded end-to-end + hardened each cycle — nothing is research-only):**
> 1. `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md` — **THE authority** (~129 items, all owner concerns verbatim).
> 2. `docs/research/SETTINGS_SIMPLIFICATION_HUB_2026_06_19.md` — research hub (slices SS-A … SS-Z, findings log,
>    each with exact file:line repair/build plans). Read the slice doc before coding its item.
> 3. `docs/research/MASTER_SYNTHESIS_2026_06_19.md` + `docs/research/DEEP_PLAN_AUDIT_HUB_2026_06_19.md` — synthesis.
> 4. `docs/research/IMPLEMENTATION_SEQUENCE_2026_06_19.md` — **CODE-NEXT ORDER** (tiered ready-to-code [S] wins across all 28 slices; Tier 0 = models install+run, in progress). Pick the next build target from here.
> **HARD CONSTRAINTS (owner 2026-06-19):** MAIN-ONLY — no worktree/branch/merge, commit+push every slice, never
> lose work. Everything must actually WORK in-app (flag-OFF ≠ done). Simplify/automate presentation but NEVER
> delete/hide functionality (progressive-disclosure ≠ hiding). App-native by embedding (clone source, never run
> a foreign sidecar). Honest/no-fake. Preserve ALL IP. Use subagents for parallelizable work. Run the
> adversarial "thermo-nuclear" review (SS-V) at deliberate checkpoints. PRIORITY by request frequency: model
> install/run actually works + per-model engineering (SS-W/Z, Qwen, MODEL-INSTALL) → skills/tools work
> everywhere + repaired/hardened (SS-H) → simplify UI/settings/chat-bar without breaking (SS-A/B/X) → visible
> wins (logos✅, install-CTA✅) → editors (SS-O/P) → native features (SS-J/K/M/N/T). ALL get coded; frequency
> only orders.
>
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
   tree before — this is non-negotiable). THEN PUSH (owner mandate 2026-06-18):
   after each commit run `git push origin HEAD` so every slice is backed to GitHub
   immediately (origin = github.com/BlickandMorty/Epistemos, branch main). If push
   fails (auth / non-fast-forward / CI gate), log it to docs/AGENT_PROGRESS.md and
   CONTINUE — a failed push never blocks the loop, but never leave commits unpushed
   on purpose.
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
6. HARDEN AFTER EVERY PHASE — DEEPLY (owner mandate 2026-06-17e, reinforced
   2026-06-18: "every phase should be [hardened] deeply"). Not a shallow pass:
   actually finish unfinished/orphaned work, promote to T4+ (real/reachable/
   visible/verified/logged), and verify in a build — not a checkbox. When a
   priority/phase finishes, before starting the next: (a) re-read THIS file + re-scan ALL owner
   hotfixes so no requested item silently drops — the owner's rule is "make sure
   none of my requests are missed"; (b) run the full build + Rust tests +
   compile-verify Swift tests and fix any regression; (c) grep the honesty
   constraints on what you just shipped (no hidden route, no fake config, MAS/Pro
   boundary intact, keys in Keychain); (d) append a one-line "HARDENED <phase>"
   entry to docs/AGENT_PROGRESS.md naming what you verified. A phase is NOT done
   until it is hardened. PER-FEATURE (owner 2026-06-18): harden EACH feature/item
   individually too — its own regression tests + a re-verify that the items it
   touches still work — not just a phase-level pass. This per-item hardening is the
   ANTI-DRIFT / anti-drop mechanism: an item isn't done until it's hardened AND
   protected from later regression. GUARDRAIL: a new backend (e.g. Goose into Work)
   must be isolated behind its mode + flag with regression proof that Chat/Act are
   unchanged — additions make the app better, never destabilize working surfaces.
7. RECURSIVELY IMPROVE THIS PROMPT (owner 2026-06-17e). Each pass, also ask: does
   this file still aim at the NORTH STAR? If a priority is vague, mis-ordered, or
   missing a step toward "stellar local-first brain / real Codex+Claude
   replacement / determinism + verifiability," sharpen it — append or clarify,
   NEVER silently delete an owner item — and note the prompt edit in
   AGENT_PROGRESS.md. The backlog should get better every loop, not just consumed.
8. DONE = WORKS IN THE APP, NOT "COMMITTED" (owner mandate 2026-06-18, the loop has
   been too lazy — features were committed but gated into invisibility or not
   wired end-to-end, and the owner could not use them). A line is DONE only when
   the OWNER can SEE + USE it in the rebuilt app, on their ACTUAL setup
   (LOCAL-FIRST, frequently NO cloud configured). Rules: (a) never gate a feature
   into invisibility — if it depends on cloud/Pro/state, still make the local path
   work and, when truly gated, show WHY (honest, visible), never vanish; (b) trace
   the real UX path before claiming done; (c) **LOCAL FOR ALL MODES** — Chat AND
   Act AND every cowork affordance must run on the owner's LOCAL models via
   `LocalAgentLoop`; NEVER auto-route to GPT/cloud unless the owner explicitly
   enabled cloud (kill the silent `chatAutoRouteToCloud`→cloud fallback when local
   simply didn't resolve); (d) the authoritative checklist is
   docs/OWNER_REQUESTS_LEDGER_2026_06_18.md — run a REALITY-AUDIT pass against it
   NOW, fix the REOPENED items first (local-for-all-modes is #1), verify each in a
   real build, before any new feature.

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
OWNER HOTFIX 2026-06-17f (HIGH PRIORITY — HIDDEN REROUTE; do this NEXT, before
more P2 UI): when the user ATTACHES notes or uses a TOOL mode ("Read + Search
vault"), chat silently routes to QWEN 3 8B even though the picked model is
Think / VibeThinker — and the memory blocker reads "Qwen 3 8B needs ~12 GB…
pick a smaller local model like Qwen 3 4B." Qwen is supposed to be GONE from the
lineup; this is the exact no-hidden-route violation (owner screenshot 2026-06-17).
ROOT: the local-agent / tool loop resolves its text model via
inferenceState.effectiveLocalAgentTextModelID (ChatCoordinator.swift ~1374) →
LocalModelCatalog.fallbackPrimaryAgentModel = Qwen 3 8B 4-bit (InferenceState.swift
~314, ~3661, ~4343) instead of the foundation tier. FIX: under
simplifiedLineupActive the agent / tool / attachment path MUST use the user's
foundation selection (Think→VibeThinker-3B, Code→Gemma 4 12B coder, Fast→sized
Gemma), NEVER Qwen; if it can't fit, show the P1.4 honest blocker NAMING THE REAL
foundation model + foundation ways out (free memory / smaller Fast size / cloud),
never "Qwen 3 4B." Audit ConfidenceRouter selectedLocalModelID, ChatTypes label
copy (~256), and every effective*AgentTextModel / fallbackPrimaryAgentModel seam.
See P1.10.

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
  P1.10 OWNER HOTFIX (HIGH) — kill the stale QWEN reroute on the TOOL / AGENT /
        ATTACHMENT path. effectiveLocalAgentTextModelID + fallbackPrimaryAgentModel
        must resolve to the foundation tier (Think/Code/Fast), NEVER Qwen 3 8B/4B,
        when simplifiedLineupActive. Reuse P1.6's tier-representative pinning + the
        P1.4 blocker (named for the REAL foundation model, foundation ways out).
        REPRO (owner): pick Think, set composer to "Read + Search vault", send
        "analyze" on low free memory → must blocker on VibeThinker/foundation, NOT
        Qwen. Add a regression at the agent-path model-resolution + blocker-copy
        seam (and fix the ChatTypes ~256 / blocker ~4343 Qwen-named copy).
  P1.11 PICKER REDESIGN (owner 2026-06-18, REOPENS P1.9 — the low/med/high effort
        labels NEVER showed for the owner; replace them with EXPLICIT model picks).
        Under the simplified popover (RootView.swift simplifiedRuntimePopover ~1500
        / modelPopover ~1216, in LocalModelToolbarMenu):
          • FAST → 4 selectable options: Gemma 2B (E2B), Gemma 4B (E4B), Gemma 12B,
            and Apple Intelligence. (Auto-size can stay as the default/"Auto" pick,
            but the 4 explicit choices must be VISIBLE + selectable — not invisible
            effort tiers.)
          • THINK → one model (VibeThinker-3B).
          • CODE → one model (Gemma 4 12B coder).
          • QWEN 3 4B + 8B BOTH SELECTABLE (owner 2026-06-18): keep `qwen3_4B4Bit`
            AND re-expose `qwen3_8B4Bit` as EXPLICIT, user-selectable options under
            Fast OR Think — NEITHER is the auto-default (default = Fast Gemma). Slot — pick the slot
            that fits its real capability profile (it's a general, native-tool-call
            agentic model — check RuntimeRouter.agentCapabilityBadgeData; likely
            Fast as a larger general option, or Think if its reasoning fits better).
            This is an EXPLICIT pick, NOT a reversal of P1.10 — the no-hidden-Qwen
            rule still holds (never a SILENT fallback); a visible user choice is
            honest. Memory-gate it (P1.4 blocker if it can't fit).
        TOTAL REBUILD (owner 2026-06-18): "the popover needs to GO — too many old
        labels — I want a total restart, do not keep anything, rebuild it with
        pixel-art UI to match the app." So DELETE the old popover wholesale
        (simplifiedRuntimePopover + modelPopover + the legacy Runtime/Routing/
        Fallback/per-model/Advanced sections and their old labels) — do NOT
        preserve any of it — and build a FRESH, clean PIXEL-ART picker panel from
        scratch, integrated into the app's pixel-art look (not an intrusive
        overlay). Content of the new panel: the Fast(2B/4B/12B/Apple)/Think/Code
        choices above + the one Cloud toggle, and nothing else at top level. Honest:
        Apple Intelligence only shown when available; 12B only when memory fits
        (else the P1.4 blocker). Verify in a real build that the 4 Fast options +
        Think/Code actually appear and switch the model.

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
  P2.7  SKILL/TOOL/MCP INSTALL + MANAGEMENT (owner 2026-06-18 — Settings appendage).
        Better skill CREATION (improve P2.4) AND an INSTALL surface: install skills/
        tools/superpowers/MCP servers FROM external sources — GitHub repos + MCP
        registries (modelcontextprotocol registry, Smithery, mcp.so, glama,
        awesome-mcp-servers, etc.). The app must actually PERSIST installed ones
        (survive restarts) and USE them once installed (wired into the tool catalog
        / executionPlan / MCPBridge, not just listed). A SETTINGS management pane:
        browse/install/enable/disable/update/remove, with provenance + honest
        gating (Pro/MAS, Keychain for any tokens, security.rs for subprocess). Pairs
        with the BEST-OF PRESET (ship good defaults) + P2.3 MCP + P2.4 skills.

────────────────────────────────────────────────────────────────────────
PRIORITY 3 — OSAURUS = ACT MODE: FULL IMPORT (owner DECISION 2026-06-18 — REVERSES
the old "cherry-pick, never fork"). Owner's goal is COMPLETENESS: bring in ALL of
Osaurus, INCLUDING its SwiftUI frontend, with ZERO cherry-picking (picking pieces
out of Swift is messy and silently drops edge cases — the owner does NOT want to
miss anything). Osaurus BECOMES Act mode. IMPLICATION: STOP hand-building the
home-grown cowork/Act affordances (P7.6 Progress/Working-folder/etc.) — Act's
functionality comes FROM Osaurus now; do not keep polishing a parallel Act.
────────────────────────────────────────────────────────────────────────
  P3.0  FULL OSAURUS IMPORT (the main event; do as the next major workstream after
        the Chat reality-audit). (1) CLONE the complete official Osaurus repo (MIT)
        locally — it is NOT on disk yet; resolve the real URL (the repo the loop
        already researched). (2) Bring the ENTIRE repo in as a complete, vendored
        subtree/module — EVERY file incl. the SwiftUI frontend — and PRESERVE
        Osaurus's Xcode settings / Info.plist / .entitlements verbatim (those
        entitlements are what let its agent loop escape the sandbox safely — do
        NOT overwrite them with Epistemos's). (3) HOST = keep EPISTEMOS as root so
        the 319K-line IP + 5,342 tests stay home; embed the COMPLETE Osaurus as the
        ACT substrate. This delivers "no code left un-added" without re-homing
        Epistemos. (4) Get it building alongside Epistemos. (5) THEN reskin Act's UI
        to the app's pixel-art look, binding to the REAL Osaurus agent state
        (frontend reskin = UI work, not systems work). Reconcile duplicates
        honestly; drop nothing.
  P3.1  After the import builds: map Osaurus's state entry points (root
        EnvironmentObject / agent-loop coordinators) so the three-mode router
        (Chat = Epistemos chat / Act = Osaurus / Work = OpenCode) binds cleanly.
        Document the import + integration in docs/OSAURUS_DEEP_DIVE_2026_06_17.md
        (now an IMPORT/INTEGRATION map, not a cherry-pick list).
        THE ONLY "CHERRY-PICK" IS THE UI (owner 2026-06-18): import ALL the code;
        the only selective work is reskinning Osaurus's frontend to the app's
        MINIMAL pixel-art look. KEEP Osaurus's AGENT-CREATION capability, but FRONT
        it with the Epistemos TAMAGOTCHI / Companion (the fluid-animation companion,
        P2.6) as the agent-creation UI/identity — adopt the tamagotchi as the face
        of agent creation, bound to Osaurus's hardened agent state.
  P3.1b POST-IMPORT ENHANCEMENTS (owner 2026-06-18 — the work the owner planned to
        add to Osaurus). After the full import builds: add the upgrades ON TOP of
        the ported Osaurus — MORE MCP servers/connectors, EASIER + MORE ROBUST
        agents, and anything that strengthens Act. ALSO bring key Osaurus
        capabilities into a MAS-SAFE version so the App Store build gets as much
        Osaurus value as the sandbox honestly allows (Pro/dev keeps the full
        unsandboxed agent power). Honest gating throughout.
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
  • P5.H  DEEP-HARDEN + FINISH THE SUBSTRATE RESEARCH (owner 2026-06-18 — "the
    Cognitive DAG etc., all the things I researched a while back to add to my chat,
    are UNFINISHED — harden them, deeply"). AUDIT-FIRST (don't assume finished or
    unfinished — many claims have hidden PASSes): for EACH substrate track
    (Cognitive DAG incl. the orphaned macaroons→dispatch wiring, Provenance ledger
    + console, Knowledge Core, Halo/shadow, Simulation, Schema-First GenUI, XPC),
    grep its real status + tier. FINISH the genuinely-incomplete/orphaned ones and
    DEEP-HARDEN to T4+ (compiled-in-scope, reachable, VISIBLE, verified, logged,
    rollback-bound, AnswerPacket-visible) — not L1/blue metadata passes. The owner
    researched these TO ADD TO CHAT, so SURFACE the finished ones in Chat (P8.1).
    Build + test each; one slice per track; record the honest before/after tier.
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
P6.1  Real AI provider logos in Settings + chat + model picker, BIASED TO
      BLACK-AND-WHITE (monochrome, fill="currentColor" so they tint per theme).
      OWNER RE-EMPHASIZED 2026-06-17e + PROVIDED ASSETS — "as many logos as I can
      get, coherent, bias to the black-and-white ones I have."
      OWNER ASSETS (use these FIRST; dedup the numbered "(1)/(2)" copies): the
      owner's downloaded lobehub SVGs are staged in docs/brand-assets/lobehub/ —
      claudecode.svg (mono), claudecode-color.svg, claudecode-text.svg,
      hermesagent-color.svg, kimi-color.svg.
      COMPLETE the set from lobehub @lobehub/icons (MIT; mono+color;
      <title>/viewBox="0 0 24 24"/fill="currentColor"), preferring the MONO
      variant — for BOTH cloud AND local models: Anthropic, Claude, OpenAI/ChatGPT,
      Codex, Google, Gemini, Google Gemma, QWEN (local), LiquidAI/LFM (local),
      Apple, Kimi, Hermes — coherent set, mono default.
      CONTEXT-SPECIFIC wiring (logo MUST match what is actually serving the turn):
        • Claude Code logo → the app's Claude Code CLI surface in chat.
        • Codex logo → the app's Codex surface.
        • Regular chat → the plain provider chat icons (Claude/Anthropic,
          ChatGPT/OpenAI, Gemini/Google) per the active provider.
        • Gemma logo → local Gemma models (Fast/Code) in the picker.
        • Qwen logo → the local Qwen 3 8B pick (Think, P1.11) in the picker.
        • Apple logo → the Apple Intelligence route (P1.7).
      Wire per-provider in the model picker rows, Settings inference rows, and
      chat message headers. Import via the asset catalog + xcodegen (NEVER edit
      .xcodeproj directly). HONEST: only show a logo for the provider actually
      serving that turn; default mono, theme-aware tint.
      BROADER ICONOGRAPHY (owner 2026-06-17e): use REAL, legit lobehub icons for
      brand/feature rows across SETTINGS too — not just provider logos — and keep
      them BLACK-AND-WHITE for theme coherence so nothing looks placeholder/fake.
      BIAS TO PIXEL-ART variants where lobehub offers them (the owner believes
      there is a pixel-art Claude logo + other pixel-art icons), since the app's
      look is PIXEL-ART MINIMAL: research lobehub for the pixel-art variant, prefer
      it when it genuinely exists and fits, else fall back to the clean mono line
      icon. NEVER ship a fake/placeholder glyph — only a real asset that looks
      legit. Keep the entire icon set coherent and theme-aware.
P6.2  "Run complex things from a simple query" polish: once P1.5 + P2 land,
      verify a plain user prompt actually drives the multi-step agent loop end to
      end (tools + memory + skills) and reads as useful, not a single shot.
P6.3  Dependencies/package tooling as an agent capability (Pro): if the owner
      wants the chat to manage project deps (npm/cargo/etc.), surface it as an
      explicit Pro tool with security.rs hardening — NOT on the MAS path.
P6.4  THEME/SETTINGS FIXES (owner 2026-06-18, REAL BUG — prioritize). Three parts:
      (a) BUG: custom-theme FONT won't change — picking a font in the custom theme
          has no effect. The font getters already read
          `AppDisplayTypography.headingFontOverride(level:)` when
          `AppCustomTheme.isActive` (Theme/EpistemosTheme.swift displayFontName ~410
          / headingFontName ~430 / panelFontName ~500 / ~1918), so the break is on
          the WRITE side: the Settings custom-theme font picker
          (Views/Settings/SettingsView.swift ~4263–4685, previewFontName/fontName)
          isn't persisting into the headingFontOverride store, or the control is
          disabled, or the UI doesn't re-render on change. Fix the picker→override
          write + persistence + live re-render so every level (display/H1–H3/panel/
          mono) actually applies. Add a regression that setting a custom font
          changes the resolved font name.
          ◐ INVESTIGATED + REGRESSION-LOCKED 2026-06-19 (owner re-verifies in-app —
          report may predate the re-render fix): traced ALL THREE suspected causes,
          all CORRECT in current code. (1) PERSIST: `setHeadingFontOverride` stores
          any `displayFontOption`-valid postScriptName; the Picker tags each row with
          exactly that, so a pick can't silently no-op. (2) CONTROL DISABLED: no — the
          heading-font Pickers render + are interactive, gated to `themeMode==.custom
          && activePair==.custom` (SettingsView ~4484). (3) RE-RENDER: FIXED — the
          `UIState.theme` getter reads `_ = typographySettingsRevision` (UIState.swift
          ~286) with an explicit comment naming THIS exact symptom ("picking a font
          does nothing… override persisted but nothing re-rendered"), and the
          binding setter bumps it. Added the requested regression: NEW
          `HeadingFontOverrideTests` (5 tests — round-trip honored under Custom, every
          Picker option persists, custom-gating, clear, unknown-name rejected); the
          persistence/gating layer had ZERO prior coverage. build-for-testing green.
          STILL OPEN: if the owner still sees it, the remaining surface is the Tiptap
          NOTE-heading CSS re-injection (epdocHeadingFontFamily) on a typography bump —
          the editor-integration path, not the model layer (now locked).
      (b) THEME PREVIEW is ugly — replace the busy preview UI with a clean COLOR
          PALETTE swatch (the theme's key colors as a simple row/grid), per owner.
          Drop the heavy mock-UI preview; palette-only is the preview.
          ✅ DONE 2026-06-19: the busy cinematic mock-UI card was already replaced by a
          palette swatch for ALL theme pairs (ThemePairCard → CustomThemePaletteSwatch
          for custom, ThemePairPaletteSwatch for every other pair). This pass made it
          PIXEL-ART per owner ("the new pixel-art palette preview"): both swatches + the
          card chrome now use hard `Rectangle()` (no rounding), hard 1px swatch borders
          + 1.5px container border, tighter grid — matching the app identity. ALSO
          caught + fixed a stale-RED test: ThemePickerRestorationTests still asserted
          the DELETED ThemePairCinematicPreview/Half tokens; retargeted to the palette
          tokens + negative locks. build-for-testing green.
      (c) SETTINGS is messy — tidy the theme/appearance section (and obvious
          nearby clutter): group related rows, remove dead/duplicate controls,
          align with the pixel-art-minimal look. Honest — don't hide real settings,
          just declutter.
          ◐ MOSTLY DONE 2026-06-19: grouping/reordering already landed + locked
          (appearanceForm mirrors AppearanceSection.canonical, AppearanceSectionOrder
          Tests — "declutter only reorders, every real setting stays"). This pass did
          the pixel-art ALIGN: the custom-theme editor (CustomThemeColorTile +
          CustomThemeLivePreview) went from RoundedRectangle/Capsule → hard Rectangle,
          matching the (b) palette identity (no deletions — the live preview stays).
          +2 marker assertions. build-for-testing green. REMAINING (owner in-app pass):
          any genuinely dead/duplicate control to remove (DELETION GUARDRAIL — grep-
          prove + own commit) + broader pixel-art alignment of other Settings panels.

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
  P7.4  "WORK" MODE — the THIRD clean chat mode (owner DECISION 2026-06-18). There
        are THREE distinct, clean modes — do NOT cram OpenCode into Act (that was
        the messy decision the owner rejected):
            CHAT  — conversational, bounded read/search.
            ACT   — the multi-step agent loop (plans, tools, progress).
            WORK  — the deep code/terminal surface (the "OpenCode" one), named WORK
                    to avoid colliding with the Fast/Think/CODE model tier (which
                    stays unchanged).
        "Mode" (Chat/Act/Work) and "model tier" (Fast/Think/Code) are SEPARATE axes
        (see P7.4a). WORK vision (owner): local AND cloud models with DEEP TERMINAL
        access to the on-disk notes + research on the laptop, and access to ALL the
        app's skills + tools from chat. CRITICAL: WORK (and Act) must run on the
        owner's LOCAL models with FULL local=cloud capability parity (rule #8 / the
        ledger #1) — never silent GPT. Pro/dev-gated for shell/terminal,
        security.rs hardened, MAS-honest. Theme-aware, pixel-art minimal. Build on
        the shared ChatCoordinator + agent loop (P7.6), never a fork-shell.
        TOGGLE PLACEMENT (owner 2026-06-18): the Work toggle is NOT on the search
        bar — put it UPWARD, at the TOP of the search page (above the search bar).
        Flipping it transforms the SEARCH PAGE INTO the Work/OpenCode surface
        (themed, pixel-art minimal), and back.
        BACKEND (owner DECISION 2026-06-18): Work / Open Code is powered by the
        EXTRACTED GOOSE RUST CORE (R-GOOSE) — full engine (repo loops, git,
        test-and-fix self-correction, parallel subagents), in the shared Rust
        backend via UniFFI; NOT the Node/TS Goose desktop. Own SwiftUI skin.
        Sequence: AFTER P7.1✅ / P7.5 / P7.6 / Osaurus(P3) / Unsloth(P4.1) /
        minimal-UI + the deterministic-schema substrate work — everything else first.
  P7.4a UNRAVEL / UX MAP — REVISE for the 3-mode decision (owner 2026-06-18, GATES
        P7.4). Update docs/CHAT_UX_MAP_2026_06_18.md to the owner's final model:
        Axis 1 MODE = THREE clean modes Chat / Act / WORK (NOT OpenCode-buried-in-Act
        — undo that). Axis 2 MODEL TIER = Fast/Think/Code + Apple Intelligence +
        cloud. Axis 3 SURFACE = Main/Mini/Note/Graph/cowork. Key invariant: LOCAL
        models give the SAME capabilities as cloud in EVERY mode (no silent GPT;
        ledger #1 / rule #8). Keep it the simplest coherent mental model; this map
        de-black-boxes the UX and gates the Work build.
  P7.5  CHAT SURFACE PARITY (owner 2026-06-17, HIGH — do alongside P7.1, the
        capability ceiling must hold on EVERY surface, not just Main). MiniChat and
        Note chat are OUTDATED / inconsistent with Main chat. Bring every chat
        surface to parity with the Main chat (ChatCoordinator.swift) capability
        stack: simplified Fast/Think/Code picker, no-hidden-Qwen routing (P1.10),
        honest memory blocker (P1.4), Fast effort visibility (P1.9), Apple
        Intelligence route (P1.7), tool toggles (P2.1), memory/vault search (P2.2),
        skills (P2.4). TARGETS: Epistemos/Views/MiniChat/MiniChatView.swift +
        MiniChatWindowController.swift; Epistemos/State/NoteChatState.swift +
        Views/Notes/NoteChatSidebar.swift; Graph chat already routes into Main via
        AppBootstrap.routeGraphChatRequestIntoMainChat — VERIFY it stays consistent.
        Prefer routing these surfaces THROUGH the shared ChatCoordinator capability
        path rather than duplicating logic, so they never drift again. Add parity
        regressions. Honest gating per surface (no fake capability where a surface
        genuinely can't host it).
  P7.6  CLAUDE-DESKTOP "COWORK" PARITY, FUSED WITH CODE (owner 2026-06-18,
        screenshot). The NORTH-STAR surface: bring Claude Desktop's agentic cowork
        affordances INTO the chat, fused with the Code/Claude-Code capabilities, so
        one chat has EVERYTHING. Every panel must reflect REAL runtime state — never
        a mockup. Affordances (build on the existing agent loop + executionPlan +
        AgentCommandCenterState + MCP; surface, don't fork):
          • ACT vs CHAT mode toggle — Act runs the real multi-step agent loop
            (tools/memory/skills via executionPlan); Chat is single-turn. Real, not
            a label.
          • PROGRESS panel — live task steps (the checkmark step chain) for longer
            agentic runs, sourced from the agent loop's actual plan/steps.
          • WORKING FOLDER panel — the real files the run created/modified
            (file_ops outputs), openable. Pro/file-access gated; MAS-honest.
          • CONTEXT panel — the real tools invoked + files referenced this run
            (agent-loop telemetry / tool catalog), not a static list.
          • QUEUE — queue user messages while the agent is working (send-later).
          • CONNECTORS — Slack / Gmail / Google Drive (+ more) via MCP (extends
            P2.3). Only show connectors actually wired; OAuth tokens/keys in
            Keychain; honest "connect" affordance, no fake data access.
          • Keep voice input + thought-process/thinking display.
        Theme-aware, pixel-art minimal. Gate each affordance honestly (MAS vs Pro).
        This is the same shared ChatCoordinator stack as P7.5 — extend it, and let
        the "Code" toggle (P7.4) flip this same surface into code mode.
  P7.7  VOICE (owner 2026-06-18; research-back via PHASE R-VOICE first). Add ONE
        real voice model (TTS, plus STT for speak-to-AI) — honest, no fake voice.
        SETTINGS auto-mode with GRANULAR toggles: (a) AUTO-READ-SCREEN — always
        read what's on screen (reuse the existing ScreenCaptureService /
        Screen2AXFusion computer-use capture; permission-gated, never silent
        background capture); (b) READ-AI-REPLIES — speak the AI's responses when I
        text it; (c) VOICE-INPUT — speak to the AI (STT). Each independently
        on/off. PIXEL-ART RETRO VOICE FILTER: a selectable voice that runs the TTS
        output through a retro-game/anime DSP filter (bitcrush / formant shift) so
        it sounds like a pixel-art retro character — fits the app's pixel-art theme.
        Prefer on-device/offline if a good model exists; keys in Keychain if cloud.
        Theme-aware, pixel-art minimal UI. MAS/Pro-honest (mic + screen entitlements).
        OWNER DECISION 2026-06-18: ship BOTH voices. (a) Kokoro-82M = the everyday
        on-device voice (R-VOICE pick), with AVSpeechSynthesizer as instant
        fallback. (b) MOSS-TTS-PNY = a SPECIAL "reading voice" the owner explicitly
        wants — selectable for reading a page in ANY note type and for in-chat
        reading. Pursue a REAL on-device path for MOSS (CoreML/MLX conversion); if
        none exists, gate it Pro/dev or surface an honest blocker — never fake it,
        never a hidden Python subprocess on MAS. Both selectable in the voice
        picker; the retro filter applies over either.
  P3.5  OSAURUS FULL-REPLACE EVALUATION (escalation of P3). After P3.1's deep
        dive + P7.1, decide full-adopt vs pattern-adopt per piece via the
        ProvenanceGate, with the explicit goal of Epistemos being a COMPLETE
        Osaurus replacement (local OpenAI/Ollama server + agent builder). Write
        the decision + plan into docs/OSAURUS_DEEP_DIVE_2026_06_17.md, then land
        the chosen slices with deep optimization. MAS/Pro boundary intact.
        SURFACE IN THE MODES (owner 2026-06-18): the Osaurus cherry-picks/full-port
        (local server + agent capabilities) must POWER Act/Work mode's local agent
        loop — and where it fits, Chat mode — not be a standalone feature. Likewise
        Unsloth (P4.1) model training must be reachable FROM the chat/Act, not a
        separate silo. Wire both into the shared mode stack with local=cloud parity.

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
                OWNER 2026-06-18: also DEEP-MINE the LIVING INDEX
                (EPISTEMOS_LIVING_INDEX_2026_05_24.md) + the LATTICE EXPLAINER —
                "lots of things there." Focus on the NON-70B work: the theoretical
                + app upgrades that use EML and the OTHER PRIMITIVES (not the large
                local model). Pull every such upgrade into PRIORITY 5 / P8 / the
                ledger and BUILD it; the 70B alone stays owner-gated.
  PHASE R-VOICE  (owner 2026-06-18, feeds P7.7) Voice models + filter. Owner wants
                BOTH Kokoro-82M (everyday) AND MOSS-TTS-PNY
                (https://huggingface.co/ZDisket/MOSS-TTS-PNY) as a special reading
                voice. DEEPEN the MOSS investigation: find a real on-device path
                (CoreML/MLX conversion, model card, license, sample quality); if it
                only runs via Python, plan a Pro/dev lane or an honest blocker — no
                hidden subprocess on MAS. Also spec the retro/anime VOICE FILTER
                (bitcrush/formant DSP). Verdict per option: free?, license,
                on-device vs cloud, UX quality.
  PHASE R-EVE   (owner 2026-06-18) "eve" agent framework — "Next.js for agents"
                (agent/agent.ts, instructions.md, tools/, skills/, sandbox/,
                schedules/). What maps onto our agent_core agent loop / Companion
                agent-builder / skills? Adopt patterns natively, ProvenanceGate.
  PHASE R-OKF   (owner 2026-06-18) Open Knowledge Format + DEDUP + PRIVACY — pick
                the BEST system for duplicate-handling AND privacy for the vault/
                Knowledge Core. Sources: Google Cloud OKF blog +
                github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf,
                buildwithmatija.com/okf, specdog.github.io, barrasindustries.com/
                okfind, and github.com/localai-org/privacy-filter.cpp. Verdict:
                which to take, free?, license, best UX, MAS-safe.
  PHASE R-PROMPT (owner 2026-06-18) Prompt/context-construction libs that sharpen
                the FOUNDING THESIS determinism: anysphere/priompt
                (github.com/anysphere/priompt) + composer-api.formkit.workers.dev.
                What improves our hyper-deterministic schema / context engineering?
  PHASE R-APPS  (owner 2026-06-18) STUDY THE BEST CHAT/AGENT APPS — besides Osaurus,
                deep-read the top open-source chat/agent apps on GitHub: LM Studio,
                HuggingFace (chat-ui / transformers / candle), Unsloth, and the best
                others (Jan, Ollama, Open WebUI, Cherry Studio, LibreChat, etc.).
                Extract: their SYSTEM PROMPTS, agent-loop architecture, tool/MCP
                handling, local-model + structured-output patterns, and UX. Write a
                verdict doc (what to adopt natively vs skip, license, via the
                ProvenanceGate). Goal: take the best system-prompt + architecture
                ideas into Epistemos honestly.
  PHASE R-HERMES (owner 2026-06-18) DEEP-STUDY the owner's HERMES AGENT research
                (HERMES_AGENT_CORE_2_0_DESIGN, EPISTEMOS_HERMES_MANIFESTO, etc.) for
                ideas to PERFECT native capabilities — but adopt NATIVELY with NO
                Hermes naming (CLAUDE.md "Hermes parity, not Hermes agent"; the
                namespace stays purged). Study deeply, take the good architecture.
  PHASE R-OPENCLAW (owner 2026-06-18) STUDY OpenClaw — LOCAL repo at
                /Users/jojo/Downloads/openclaw-main (TS/Node + ui/ + container
                setup). Mine it to perfect native capabilities; verdict doc on what
                to adopt natively (ProvenanceGate; it's not Swift, so port patterns).
  PHASE R-GOOSE (owner DECISION 2026-06-18) GOOSE = the OPEN CODE / WORK backend via
                ENGINE EXTRACTION. Goose (Block, github.com/block/goose, Apache-2.0)
                has a high-perf RUST CORE. EXTRACT the raw Goose Rust core as a
                dependency crate into the Epistemos Rust backend (agent_core) and
                expose it via UniFFI — you get the FULL engine (MCP dispatchers,
                repo indexing, git lifecycle, multi-file diffs, the DETERMINISTIC
                test-and-fix self-correction loop, parallel subagents, YAML
                Recipes). Do NOT import the Node/TS Goose DESKTOP (dual-process =
                18GB-RAM swap death on M2 Pro) — use the owner's own SwiftUI.
                MAPPING: Goose powers WORK / Open Code mode (repo loops); Osaurus
                powers ACT (macOS accessibility + Virtualization-framework sandbox
                VM, P3); Chat = the Epistemos engine. The Goose engine lives in the
                shared Rust core, so Act/Chat can tap its MCP/subagent pieces too —
                full backend power, surfaced primarily through Work. Validate Goose
                patches against the P8.2 deterministic schemas. Deep verdict + the
                extraction.
  PHASE R-CODEREVIEW (owner 2026-06-18) "THERMONUCLEAR" CODE-QUALITY REVIEW — it's
                just a NAME (community/Cursor term) for an EXTREMELY aggressive,
                exhaustive code review. Research the best such review prompt/method,
                then deliver it TWO ways: (1) a LOOP PROCESS step that runs a deep
                thermonuclear-grade quality review across the whole Epistemos app
                (correctness, dead/stale code, honesty-constraint violations, perf,
                arch drift) and files findings; (2) an IN-APP code-review feature in
                WORK/Open Code mode (review the open repo, gated by P8.2 schemas +
                Goose's self-correction loop). Honest, real findings only.
                RUN IT MULTIPLE TIMES (owner 2026-06-18): the review is RECURRING —
                run a thermonuclear pass periodically (e.g. each phase + a full app
                pass every few iterations), not once.
                ⚠ DELETION GUARDRAIL (owner 2026-06-18, CRITICAL — do NOT rely on
                the skill having this caveat; enforce it): the review/hardening may
                DEEPLY HARDEN, DEDUPE, and refactor, but DELETION IS A LAST RESORT.
                NEVER delete NEW or IN-PROGRESS features (they often look "unused"
                precisely because they're mid-build and not wired yet) or any
                owner-requested item from the ledger. Prefer dedupe / consolidate /
                wire-it-up over removal. Only delete code that is PROVABLY dead AND
                confirmed not part of any in-flight ledger item; when uncertain,
                KEEP + flag, never delete. Commit deletions separately so they're
                easy to revert.
  PHASE R-AGENTFW (owner 2026-06-18) AGENT-CREATION FRAMEWORKS — research + DELIBERATE
                what to do for Epistemos agent creation given Vercel AI SDK (TS,
                MIT), Google ADK / Agent Builder (Python/Java, open), and Cursor's
                agent (proprietary — UX/approach only, not an importable SDK). For a
                native Swift/Rust app the likely answer is ADOPT PATTERNS + the
                agent-creation UX natively (tie into the Companion/tamagotchi
                builder P2.6 + Osaurus agent config + Goose subagents), NOT import
                their SDKs. Verdict doc: per framework — usable IP vs patterns-only,
                license, what to take, and the recommended native design.
  Also sweep GitHub / HuggingFace / arXiv / Twitter(X) for anything that
  strengthens the above and combine it INTO the app, honestly. For EACH research
  phase write a short docs/ note that says: take or skip, free vs paid, license,
  on-device vs cloud, and the best-UX recommendation — so the owner can choose.

────────────────────────────────────────────────────────────────────────
PRIORITY 8 — CHAT MODE = FULL EPISTEMOS CEILING + DETERMINISTIC SCHEMA ENGINE
(owner 2026-06-18 — this is the FOUNDING THESIS made concrete; do NOT let it get
buried). Spec: docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md.
────────────────────────────────────────────────────────────────────────
  P8.1  CHAT MODE = the FULL Epistemos capability ceiling. Chat is the owner's
        everyday Epistemos chat — give it AS MUCH capability as honestly possible
        on the MAS build (what it SHOULD be + what it CAN be on MAS), PLUS the Pro
        additions, WITHOUT bleeding into the Osaurus/Act stuff. Keep all Epistemos
        IP in Chat (Eidos, Knowledge Core, Halo, memory, skills, tools). Local
        models must work GREAT here — see P8.2. (Act = Osaurus, P3; Work = OpenCode,
        P7.4 — keep them distinct.)
  P8.1b CHAT IS MESSY — DEEP-REPAIR IT USING OSAURUS AS REFERENCE (owner 2026-06-18).
        The Epistemos chat code is messy. Once Osaurus is imported (P3.0), STUDY its
        chat implementation (its message/stream/coordinator structure) and use it as
        the reference pattern to deeply repair + de-clutter the Epistemos Chat —
        refactor toward Osaurus's cleaner structure WITHOUT losing Epistemos IP
        (Eidos/Knowledge Core/etc.). Goal: a clean, maintainable Chat that keeps all
        capability. Identify what to replace vs keep; document the repair plan, then
        refactor in safe, tested slices (no behavior regressions).
  P8.2  DETERMINISTIC SCHEMA ENGINE (the thesis core; RESEARCH-FIRST on the owner's
        EXISTING local research/plans + the existing grammar/json-schema FFI —
        LocalToolGrammar, with_json_schema, P4.3 — build ON them, not greenfield):
        (a) Rust engine parses files/ASTs/tool payloads → type-safe deterministic
            JSON schemas (the "universal knowledge core"); type-safe bridge across
            Swift/Rust/Python/C.
        (b) AST QUALITY GATE: validate local tool output against the schema BEFORE
            any disk write / compile loop. Model targets an immutable typed schema,
            never guesses.
        (c) UniFFI boundary streams schemas Rust→Swift as async events, never
            blocking the main SwiftUI thread.
        (d) RAG PREFLIGHT TOOL SELECTION (Rust): pick ONLY the ~3–5 tools the turn
            needs via local embeddings, not the whole suite — preserves Gemma 4
            focus, prevents logic loops.
        (e) Structured-generation constraints force Gemma 4 + Coder Adapter to emit
            valid JSON matching the schemas (near-100% tool fidelity on Apple
            Silicon).
        (f) Isolate Gemma 4 reasoning tokens for UI tracing while extracting tool
            args for execution (PRESERVE thinking blocks — never strip).
        Deliverables per the spec doc: systems blueprint, Rust core contracts
        (Schema Validator + Tool Router), Swift actor/coordinator integration,
        phased checklist (stability + determinism FIRST). SURFACE the determinism
        visibly ("why this route", schema-gated calls) — it's the app's edge.

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
| P1.8 | Model download/install progress UI | ✅ DONE (2026-06-17) — `ModelInstallProgressDisplay.from(fraction:)` honest determinate/indeterminate mapping (0%→Starting, 100%→Finalizing, never frozen); per-model row + foundation one-tap aggregate spinner; +4 tests |
| P1.9 | Fast effort visibility: low/medium/high route reason | ✅ DONE (2026-06-17) — `EpistemosFastEffortSizing.effort` (low/med/high) + `fastEffortRouteReason` + live composer hint "Fast · Medium effort → Gemma 4 E4B"; +2 tests |
| P1.10 | Kill stale Qwen reroute on tool/agent/attachment path (hidden route) | ✅ DONE (2026-06-17) — root: `supportedAvailableLocalAgentModels` filtered to foundation tiers under simplifiedLineupActive (Qwen excluded → agent fallback nil → tool loop degrades to direct stream on the selected foundation model, never a hidden swap); blocker copy `TriageService.insufficientMemory` now names the real GGUF foundation model + foundation ways out (no "Qwen 3 4B") under the simplified lineup. +2 regression tests reproducing the owner's exact Think+tools case. |
| P2.1 | In-chat tool toggles | ✅ DONE (2026-06-17) — backend gate `executionPlanGatedByUserToolToggles` (`a731469a6`, +3 tests) + UI `AgentToolTogglePanel` opened from a composer capsule button (`slider.horizontal.3`), grouped tools with on/off, destructive/asks-first badges, all-on/all-off, honest capability footer; only shown when the catalog is non-empty; toggles genuinely gate runtime (not fake config). |
| P2.2 | Agents search memory (verify + surface), including "best essay in my vault" acceptance query | ◐ VERIFIED + REGRESSION (2026-06-17) — traced: "essay"+vault cue → `queryContainsExplicitNoteContext` true → `hasExplicitContext` → `buildContextAttachments`/`resolveNotesContext` implicit vault search inlines candidates AND route = `.overseerLocalExecution` (vault tools, not tool-less localOnly); locked by `ChatVaultLookupRoutingTests`. FOLLOW-UP (rule #7): superlative ranking ("the BEST essay") still keyword-searches rather than enumerate-essays-then-rank-by-evidence; and the search→rank→title/path/reason fallback only fires on pipeline error, not when a degraded direct-stream "succeeds" — add a proactive ranked answer / explicit "vault unindexed" blocker for vault-lookup turns that don't run a real tool loop. |
| P2.3 | MCP management UI in chat | ◐ READ-ONLY SURFACE DONE (2026-06-17) — HONESTY FINDING: there is NO Swift external-MCP-server registry and no mutation path; MCPBridge is the in-process dispatcher; the only real external wiring is `discover_url_mcp_servers()` reading `~/.config/mcp/url_servers.json` + `.epistemos/mcp_url_servers.json` (forwarded to Claude `mcp_servers`). Built `MCPUrlServerDirectory` (mirrors the Rust source, +7 tests) + a read-only "MCP servers wired" section in the in-chat tool panel (host + auth badge, honest empty-state → edit the config; tokens never shown). FOLLOW-UP: add/enable/disable = a Pro config-file editor (MAS sandbox can't write ~/.config; stdio/subprocess servers are Pro-only) — a separate gated slice, NOT fake config. |
| P2.4 | In-chat skill creation + browser | ◐ BROWSE + RUN DONE (2026-06-17) — Skills section in the in-chat tool panel lists discovered skills (SkillDiscoveryCatalog/availableSkills) with one-tap Run that primes the composer with the real `/identifier` slash token (same run path as the slash menu); honest create pointer to the real authoring (Settings → Skills `SkillAuthoringDraft`→SKILL.md, or the agent's `skill_manage` tool) rather than a duplicated half-wired form. FOLLOW-UP: an in-chat create form would be a real slice only if wired to `SkillAuthoringDraft.createPayload`→vault write (Settings already does it; the agent tool already does it) — surfaced honestly for now. |
| P2.5 | Git + diff as Pro tools | ◐ BOUNDARY VERIFIED + HONEST SURFACE (2026-06-17) — research: git/shell/CLI-agent (Codex, Claude Code) tools are already Pro-only (`#[cfg(feature = "pro-build")]` registration + `enable_bash` Pro-gated + `mas_forbidden_tool_name`), and the MAS exclusion is locked by cargo test `mas_sandbox_registry_excludes_unbounded_tools` (ran live: PASS). Default features = `mas-build` (no pro-build). No DEDICATED git tools exist — git runs on Pro via cli_passthrough/bash. Added an honest "git/diff/shell/CLI-agent run only in the Pro build" disclosure in the capability explorer, gated on `ToolSurfacePolicy.resolvedDistribution == .coreAppStore`. FOLLOW-UP (Founding Thesis): a dedicated schema'd READ-ONLY git tool (status/diff/log/branch, no mutation, security.rs-hardened, Pro-gated, cargo-tested) would be more deterministic than raw bash passthrough — a separate Rust slice. |
| P2.6 | Agent meta-builder on Companion (#47) | ✅ DONE (2026-06-17) — verified the builder's fields ARE wired (name/role/runtime/scope/approval/tools/system-prompt + `outputStructureJSON` stored on CompanionModel + injected as a response contract at CompanionState:284 — not fake config). Hardened the one risk: output-schema JSON is now validated (`CompanionOutputSchemaValidation`, +5 tests) — inline error + save-disabled so a malformed schema is never stored as a broken contract. FOLLOW-UP (Founding Thesis): wire `outputStructureJSON` to the json_schema FFI (run_local_gguf_generation with_json_schema) so local Companion agents are grammar-CONSTRAINED to the schema, not just prompt-nudged. |
| P3.1 | osaurus deep-dive doc | ☐ TODO |
| P3.2–3.4 | osaurus server verify / sentinel stream / sandbox | ☐ TODO |
| P4.1 | unsloth fine-tune lane (research) (#44) — ESCALATED 2026-06-17e: evaluate full Unsloth port + desktop training UI (pixel-art, theme-aware, Pro/offline) | ☐ TODO |
| P4.2 | EAGLE3 spec decoding (#49) | ☐ TODO |
| P4.3 | Grammar tool loop on-device validation (#41) | ◐ FFI wired |
| P4.4 | Explicit honest routing rules | ☐ TODO |
| P5 | Non-large-model architecture, then 70B (#17) | ☐ TODO |
| P6.1 | Provider logos (mono/B&W) in Settings + picker + chat, context-specific; owner assets staged in docs/brand-assets/lobehub/ | ☐ TODO |
| P7.1 | Capability ceiling: Fast→tools all legit, absolute MAS limit + Pro variant | ✅ DONE (2026-06-17) — made explicit + cargo-locked (`fast_chat_lite_capability_ceiling_is_explicit`, ran live PASS): Fast/chat_lite HAS real read/search/reason (think, vault.search, vault.read, file.read, knowledge.recall) via `apply_tier_overrides` CHAT_LITE; CANNOT mutate (no vault.write/file.patch/memory); Pro/chat_pro LIFTS to gated vault.write while keeping the reads; and the ABSOLUTE MAS limit (action.bash/action.terminal/system.process) holds across EVERY tier — it's build-gated (`not(feature="pro-build")` mas_forbidden), never tier-gated. Capability explorer already surfaces the build-scoped tools + Pro-developer note (P2.5). |
| P7.2 | HTML workspace fix + canvas live-viewer (chat drives the screen) | ☐ TODO |
| P7.5 | Chat surface parity: MiniChat / Note / Graph chat match Main chat stack | ☐ TODO — HIGH, owner 2026-06-17 (minichat outdated/inconsistent) |
| P7.6 | Claude-Desktop "cowork" parity fused w/ Code: Act/Chat, Progress, Working folder, Context, Queue, connectors (Slack/Gmail/Drive via MCP) | ☐ TODO — owner 2026-06-18 screenshot |
| P6.4 | Theme/Settings: fix custom-theme font (won't set), theme preview → color palette, declutter Settings | ◐ (a) font: investigated all 3 causes (persist/disabled/re-render) — all correct; re-render fix at UIState:286 documents the exact symptom; added the requested regression (HeadingFontOverrideTests, 5 tests); owner re-verifies (note-heading CSS re-inject is the only untested surface left). (b) ✅ palette preview is PIXEL-ART for ALL themes (hard Rectangle, no rounding; swatches + card chrome) + fixed a stale-RED ThemePicker test (asserted deleted cinematic tokens). (c) ◐ grouping done+locked; custom-theme editor aligned to pixel-art (hard Rectangle, matches palette); remaining = owner in-app dead/duplicate sweep + broader panel alignment |
| P7.7 | Voice model + auto-read-screen/replies/STT granular settings + pixel-art retro voice filter | ☐ TODO — owner 2026-06-18 (research R-VOICE first) |
| R-VOICE/R-EVE/R-OKF/R-PROMPT | Research: voice+filter / eve agent fw / OKF+dedup+privacy / priompt+composer | ☐ TODO — owner 2026-06-18, verdict docs (take?/free?/UX) |
| P7.3 | Terminal + console actually work (Pro/dev) | ☐ TODO |
| P7.4 | "Code" toggle on search → OpenCode-style themed code chat | ☐ TODO |
| P3.5 | Osaurus full-replace evaluation (complete replacement decision + slices) | ☐ TODO |
| R-* | Research phases: Osaurus / Unsloth / OpenCode / HTML-canvas / non-LM arch | ☐ TODO |
