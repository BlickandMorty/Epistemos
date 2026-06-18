# OWNER REQUESTS LEDGER (2026-06-18) — the authoritative checklist

The owner's words: *"everything I have been asking is not being done. it's being
lazy… go back and look at my queries and requests and actually do them."* This is
the complete list of EVERY owner request this session. **A line is DONE only when
the owner can SEE and USE it in the rebuilt app** — visible, reachable, and
functional for the owner's ACTUAL setup (local-first, frequently NO cloud
configured). "Compiles + committed + tests pass" is NOT done. "Gated into
invisibility" is NOT done. Re-audit each against the running app; fix until real.

**BUILD-FROM-RESEARCH / 100% MANDATE (owner 2026-06-18):** every item in this
ledger and the plan is something the owner WANTS — 100% of it is to be
IMPLEMENTED, not just researched. Research FEEDS the build: each research verdict
(R-*) must turn into shipped, in-app-verified slices. Nothing here is optional or
"nice to have." Keep going until all of it is done and hardened (rule #6/#8).

**PER-FEATURE HARDENING + NO-DRIFT GUARANTEE (owner 2026-06-18):** EVERY feature/
item added gets its OWN hardening phase — not just a phase-level pass. For each
shipped item: add regression tests, re-verify the prior items it touches still
work in-app, and log "HARDENED <item>" in AGENT_PROGRESS.md. This is the
anti-drop/anti-drift mechanism the owner is worried about: an item is not done
until it's hardened AND can't regress later. Re-run the recurring corpus sweep so
nothing silently disappears under compression.

**CHAT DEEP-REPAIR IS A FIRST-CLASS GOAL (owner 2026-06-18):** the messy Epistemos
Chat must be deeply repaired (P8.1b) — clean, maintainable, full-capability.

**DELETION GUARDRAIL (owner 2026-06-18, CRITICAL — enforce; don't assume any skill
has this caveat):** review/hardening/dedupe may NOT delete NEW or IN-PROGRESS
features (they look "unused" because they're mid-build / not-wired-yet) or any
owner-requested ledger item. DELETION IS A LAST RESORT — prefer dedupe / consolidate
/ wire-it-up. Only remove code that is PROVABLY dead AND confirmed not part of any
in-flight item; when uncertain, KEEP + flag. Commit deletions separately
(revertible). The "thermonuclear" code review is RECURRING (run multiple times).

**OPEN CODE = GOOSE (Rust, compiles in) — NOT a non-Swift app (owner 2026-06-18):**
no non-Swift app needed. Goose's Rust core links into agent_core via UniFFI.
Vercel(TS)/Google(Py)/Cursor(proprietary) are NOT Swift/Rust → adopt their PATTERNS
natively; never run them as Node/Python sidecars (NO-SIDECAR/MAS + memory).

**GOOSE-INTO-OPEN-CODE GUARDRAIL (owner 2026-06-18):** adding Goose (R-GOOSE) as
the Work/Open-Code backend must NOT break Chat or Act. Isolate the extracted Goose
core behind the Work mode + a feature flag; keep Chat/Act on their own engines;
add regression coverage proving Chat + Act are unchanged after Goose lands. Goose
should make the codebase MUCH better, never destabilize the working chat.

## REALITY-AUDIT RULE (applies to every line)
1. Build the app; actually trace the UX path the owner would take.
2. If a feature is hidden unless cloud/Pro/some-state — that's a FAIL for a
   local-first owner. Make it reachable + functional on LOCAL by default; gate
   only the genuinely-cloud/Pro-only pieces, and when gated, show WHY (honest,
   visible), never just vanish.
3. No feature is "done" until the owner can demonstrably use it.

## REOPENED — owner reports these DON'T WORK (fix first, verify in-app)
- [ ] **PICKER IS STILL A POPOVER — REOPENED (owner 2026-06-18, verified in code)**
      P1.11 changed the popover's CONTENT (Fast/Think/Code picks) but did NOT
      delete the popover. RootView.swift:1216 `modelPopover` + :1576
      `simplifiedRuntimePopover` are STILL `.popover(...)` overlays — that's why the
      owner still sees a messy floating popover. REQUIRED: DELETE the popover
      presentation entirely; rebuild the picker as a FLAT, INLINE, pixel-art panel
      that is a visual EXTENSION OF THE THEME / the search-composer surface (not a
      floating overlay). VERIFY VISUALLY in a rebuilt app that the popover is gone
      and the flat panel renders. This is the core of the owner's repeated request.
- [ ] **HARNESS SYSTEMS — port the best (or a mixture) of everything an LLM app does
      for the model, beyond the model (owner 2026-06-18)** — RAG, MEMORY systems,
      CONTEXT management/compaction, TOOL-USE plumbing, MCP-server ROUTING, prompt
      caching, etc. Deep-research the best LLM harnesses/desktop apps (R-APPS /
      R-ASSISTANTS), and PORT the best implementation OR a clever MIXTURE/mesh of
      them natively — don't hand-roll from scratch; lift the proven code/patterns
      (grep/extract, ProvenanceGate). SYSTEM PROMPT = an ANCHOR the loop EXTENDS
      (strong base system prompt, then extend), not a one-off. Make it deeply
      exquisite; wire into Chat/Act/Work. Verdict doc → port + harden.
- [~] **#1 LOCAL FOR ALL MODES (route fix landed 2026-06-18; verify in-app) — STOP THE HIDDEN GPT ROUTE.** Owner (verbatim):
      *"not even having cloud selected it goes to gpt, you should be able to use
      my local for all modes."* This is the #1 honesty-constraint violation: with
      NO cloud selected, Act/agentic still routes to GPT (cloud). FIX: the LOCAL
      agent loop (`LocalAgentLoop`, `canRunLocalAgentLoop`) must back Act / agentic
      / cowork on the owner's LOCAL models by default — Chat AND Act AND every
      cowork affordance work on local. NEVER auto-route to GPT/any cloud unless
      the owner EXPLICITLY enabled cloud or pressed "route to cloud" for that turn.
      If a local model can't do a step, show the honest P1.4-style blocker (free
      memory / smaller tier / optionally route to cloud) — never silently use GPT.
      Audit EVERY route seam: TriageService, ConfidenceRouter, RuntimeRouter,
      ChatCoordinator agent path, `availableOperatingModes`, `CoworkChatMode`,
      `usesAutomaticCloudRouteForChatSurfaces`, `preferredAutoRouteCloudProvider`,
      `effectiveChatSurfaceSelection`. Regression: no-cloud + Act → local, not GPT.
- [ ] **ACT mode** — reported not working. Root: gated behind cloud/Pro
      (`CoworkChatMode.actAvailable` / `availableOperatingModes`) AND the auto-cloud
      route above. FIX: Act runs the LOCAL multi-step agent loop by default (see
      #1); cloud only augments when explicitly chosen. Visible + togglable + works
      with zero cloud configured.
- [ ] **QUEUE** — reported not working. Only appears while `isProcessing` + draft
      non-empty. Make it discoverable and prove the staged message actually sends
      on completion in the running app.
- [ ] **CONTEXT** — reported not working. Only shows when tools were used + as a
      tiny composer strip. Assemble it as a real, visible panel; populate from
      actual run telemetry; show an honest empty state, not nothing.
- [ ] **COWORK SURFACE** — the Act/Progress/Working-folder/Context/Queue/Connectors
      pieces are scattered into the composer, NOT the cohesive cowork LAYOUT from
      the owner's Claude-Desktop screenshot. Assemble the real surface (panels),
      reachable from chat. (P7.6)
- [ ] **Local models "not working" → showing GPT instead of local** in Settings.
      Investigate WHY other local models don't load/resolve; fix the label so
      local rows show the real local model, never a cloud/GPT fallback unless
      cloud is the genuine active route. (SettingsView activeChatModelDisplayName /
      activeLocalTextModelDisplayName / `?? .openAI` ~1542; AgentBlueprint /
      Constellation / ModelProfile rows.)
- [ ] **Qwen 3 8B visible again (P1.11)** — re-expose as an EXPLICIT pick under Fast
      or Think (whichever fits); visible user choice, NOT a silent fallback (P1.10
      still holds). Memory-gated.
- [ ] **Chat is messy → deep-repair using Osaurus as reference (P8.1b)** — study
      Osaurus's chat structure, refactor Epistemos Chat cleaner without losing IP.
- [ ] **PICKER REDESIGN (P1.11)** — low/med/high effort STILL not visible. Replace
      with explicit picks: FAST → Gemma 2B / 4B / 12B / Apple Intelligence (4
      options), THINK → VibeThinker, CODE → Gemma 12B coder, + one Cloud toggle.
      TOTAL RESTART: delete the old popover wholesale (keep NOTHING — all the old
      labels go), rebuild from scratch as a pixel-art panel matching the app (not
      an intrusive overlay). Verify the options appear + switch the model in a build.
- [ ] **DEFAULT STILL = QWEN 4B — REPAIR (owner 2026-06-18, in rebuilt app)** — the
      picker/chat still DEFAULTS to Qwen 3 4B. Root: `InferenceState.swift:3256`
      `var preferredLocalTextModelID = LocalTextModelID.qwen3_4B4Bit.rawValue` +
      the "validated default stays Qwen" logic (lines ~41, ~649) + AgentCommandCenter
      brain default lists (~580-600). Under simplifiedLineupActive the DEFAULT must
      be a foundation FAST model (headroom-aware Gemma E2B/E4B), NEVER Qwen 4B as
      the DEFAULT. Qwen 3 4B AND Qwen 3 8B both stay available as EXPLICIT,
      user-selectable local picks (owner wants BOTH) — just not the auto-default.
      Fix the hardcoded default + migration + agent-brain defaults to foundation;
      regression.
- [ ] **MEMORY BYPASS for 12B (owner 2026-06-18) — "I generally have enough; I used
      to run bigger models."** Two parts: (1) ADD an explicit owner OVERRIDE — a
      "Run anyway / use it anyway" toggle/button on the memory blocker (P1.4) so the
      user can FORCE the Gemma 12B coder + regular 12B even when the gate flags it.
      Honest: it warns it may be slow / swap, but RESPECTS the choice (explicit
      user-forced load is NOT a silent swap). (2) AUDIT the estimate — it's too
      conservative: the gate uses *free* memory + a 4 GB headroom
      (`InferenceState.swift` ~4187/4259 `headroomGB = 4`;
      `localAgentModelFitsCurrentMemoryBudget`; the P1.4 blocker). On macOS "free"
      undercounts AVAILABLE memory (cached/purgeable/compressed is reclaimable) —
      compute available = free + reclaimable, and don't over-state the 12B
      footprint, so legit 12B runs aren't blocked. Keep the honest blocker as the
      DEFAULT, but make the override real + the estimate accurate. Regression.
- [ ] **Palette preview for ALL themes** — currently gated `if pair == .custom`
      (SettingsView ~4081). Generalize `CustomThemePaletteSwatch` to every
      `ThemePairCard` so every theme shows the palette preview.
- [ ] **Custom-theme font** — claimed fixed (4b0a5e59e); VERIFY in-app that picking
      a font on the custom theme actually changes rendered text, every level.

## Picker / routing / honesty
- [x] Think → VibeThinker, never Gemma 12B (P1.6) — verify still true on all paths.
- [x] No hidden Qwen on tool/attachment seam (P1.10) — verify in-app with attach.
- [x] Apple Intelligence selectable native route (P1.7) — verify visible.
- [x] Download/install progress visible (P1.8) — verify a real install shows it.
- [x] Fast low/med/high effort visible (P1.9) — verify the composer hint shows.
- [ ] Vault "best essay in my vault" returns ranked answer w/ title/path/reason,
      not a generic reply or empty "no vault retrieval" (P2.2 — still partial).

## Chat capability + parity
- [ ] Capability ceiling Fast→tools, real on LOCAL (P7.1) — verify tools actually
      run from chat on a local model, not just documented.
- [ ] MiniChat / Note / Graph chat parity — verify each surface really has the
      Main-chat capabilities in-app (P7.5).
- [ ] Tool toggles actually gate the runtime AND are visible/usable (P2.1).
- [ ] In-chat skills run; MCP/connectors (Slack/Gmail/Drive/Notion) actually
      connect + are usable (P2.3/P2.4/P7.6 connectors).
- [ ] **Skill/tool/MCP INSTALL + management in Settings (P2.7, owner 2026-06-18)** —
      better skill CREATION + INSTALL skills/tools/superpowers/MCP servers from
      GitHub + MCP registries (MCP registry, Smithery, mcp.so, glama,
      awesome-mcp-servers). PERSIST installed ones (survive restarts) and actually
      USE them (wired into tool catalog/executionPlan/MCPBridge). Settings pane:
      browse/install/enable/disable/update/remove; honest gating, Keychain tokens.
- [ ] **BEST-OF PRESET — ship a curated default set of the best superpowers /
      skills / tools / MCP servers (owner 2026-06-18).** Research + bundle a
      starting PRESET of the best available agent powers (skills, tools, MCP
      servers — e.g. filesystem, web/fetch, browser+stealth, git, memory/vault,
      code-exec, popular MCPs) so the app ships powerful out of the box, not empty.
      HONEST: only include real, working ones; Pro/MAS-gate each appropriately;
      let the user toggle. Research-back the picks (which are best/free/safe) and
      document the preset. Wire into the tool catalog / capability explorer (P2.1).

## Surfaces the owner asked for
- [ ] HTML workspace is BROKEN (can't see code) → fix + HTML canvas live-viewer the
      chat can drive (P7.2). NOT STARTED — owner flagged broken.
- [ ] Terminal + console actually work (Pro/dev) (P7.3).
- [ ] "WORK" mode (the OpenCode surface) = THREE clean modes Chat / Act / Work
      (NOT buried in Act). Work = deep terminal access to on-disk notes/research +
      ALL app skills/tools from chat, local=cloud parity. Toggle lives UPWARD at
      the TOP of the search page (not on the search bar) and turns the search page
      INTO Work/OpenCode. After the revised UX map (P7.4/P7.4a).
- [ ] Provider logos (B&W lobehub, prefer pixel-art), context-specific, in Settings
      + picker + chat (P6.1) — for BOTH cloud AND local models: Claude, ChatGPT,
      Gemini, Claude Code, Codex, Gemma, Qwen, Apple, Kimi, Hermes. NOT DONE —
      assets staged in docs/brand-assets/lobehub.
- [ ] Voice: Kokoro + MOSS (special reading voice) + auto-read-screen / read-replies
      / STT granular toggles + pixel-art retro filter (P7.7). NOT BUILT (research only).

- [ ] **Browser use — SURFACE the existing (built, Pro) browser automation** in the
      chat modes (Act/Work). agent_core/src/tools/browser.rs (agent-browser + chrome
      MCP, shipped Pro) + LocalAgentCapabilityRegistry `browser` toolset already
      exist but aren't reachable from chat. Wire it in honestly (Pro-gated), so the
      agent can drive a browser / do anything on the web from chat. Primary target:
      the agent controls MY APP's in-app browser (Obscura, below). Also pairs with
      the HTML canvas (P7.2).
- [ ] **Stealth / undetected browsing (owner 2026-06-18)** — the "non-scrape" thing:
      sites should NOT detect that an agent/bot is on the page. Research the best
      GitHub stealth-browser skill (puppeteer/playwright-stealth, undetected-
      chromedriver, rebrowser, nodriver, etc.); if it isn't Rust-native, USE IT
      ANYWAY via the agent-browser/chrome-MCP path and VENDOR/save it in the app.
      Wire stealth as an option on browser-use + the Obscura browser. Pro/dev-gated.
      (Honest: authorized use; no fake "undetectable" claims beyond what the lib does.)
- [ ] **OBSCURA BUILT-IN BROWSER (owner researched before; runtime never built)** —
      build the actual working in-app Obscura browser (Rust browser backend /
      WKWebView built-in browser). PRIOR RESEARCH IN-REPO (read first, build on it):
      docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md (Tier-1 lifts LANDED),
      HELIOS_V5_INTEGRATION_PLAN §B3 "W6-A..W6-I runtime work (Obscura + deno_core +
      Eidos) — queued", EPISTEMOS_HERMES_MANIFESTO "WKWebView built-in browser". The
      W6 runtime was never built — BUILD it. Pairs with Work mode + HTML canvas
      (P7.2) + browser-use. Pro/dev-gated where it needs network/subprocess.
- [ ] **RESEARCH-CORPUS COMPLETENESS SWEEP (owner 2026-06-18)** — the owner fears
      researched/queried items are silently dropped. The loop must SWEEP the
      owner's local research (docs/fusion/* + prior plans) AND this session's full
      query history, and ADD any researched/requested-but-untracked capability to
      THIS ledger. Recurring task — keep the ledger complete against the corpus.
      SPECIFIC RANGE (owner 2026-06-18): cover the OBSCURA era, the SIMULATION era,
      and the EML era — and BEYOND, up to now. **EXCLUDE HERMES** (the owner purged
      it — do NOT resurrect Hermes-named work; naming-reconciliation only). Focus on
      LOCAL research + CHAT-related research (lots got dropped). Extract every
      "queued / candidate / deferred / runtime phases / NOT IMPLEMENTED / W6-*" item
      from at least: B2/B3 lift targets (B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS,
      B3_OBSCURA_BROWSER_LIFT_TARGETS), HELIOS_V5/V6 plans, SUBSTRATE_TRACK_REGISTER
      + fusion/* state docs, Eidos (EIDOS_V0_*), SIMULATION (SIMULATION_DONOR_MINING_
      STATUS + docs/simulation/*), EML era (EML-IR / episodic-memory-lattice, the
      T5/T7 EML work), the LATTICE EXPLAINER + EPISTEMOS_LIVING_INDEX_2026_05_24.md,
      KNOWN_ISSUES_REGISTER, HARDENING_TRACKER, FEATURE_CHANGE_TRACKER,
      V1_5_IMPLEMENTATION_TRACKER, PHASE_CHECKLIST. Each unfinished item → a ledger
      line + finish it deeply (rule #6/P5.H). Write
      docs/UNFINISHED_RESEARCH_SWEEP_2026_06_18.md.

## Architecture / process
- [ ] **Living Index + Lattice Explainer — non-70B upgrades (owner 2026-06-18)** —
      deep-mine EPISTEMOS_LIVING_INDEX_2026_05_24.md + the lattice explainer ("lots
      of things there") for theoretical + app upgrades using EML + other PRIMITIVES
      (NOT the 70B). Pull each into the ledger + BUILD; 70B alone stays owner-gated.
- [ ] Founding thesis everywhere: determinism + verifiability on small local models;
      substrate health + Knowledge Core (P5/R-ARCH) — more important than 70B.
- [ ] **P5.H — DEEP-HARDEN + FINISH the substrate research** (Cognitive DAG incl.
      orphaned macaroons→dispatch, Provenance ledger+console, Knowledge Core, Halo,
      Simulation, Schema-First GenUI, XPC). Audit-first (hidden PASSes), finish the
      unbuilt/orphaned, promote to T4+ (reachable/visible/verified/logged), surface
      in Chat. The owner researched these to add to chat; they're unfinished.
- [ ] **CHAT = FULL EPISTEMOS CEILING (P8.1)** — Chat gets max capability on MAS +
      Pro additions, keep all IP (Eidos etc.), don't bleed into Osaurus/Act.
- [ ] **DETERMINISTIC SCHEMA ENGINE (P8.2, founding thesis — DON'T BURY)** — Rust
      schema engine + AST quality gate (validate before disk write/compile) +
      UniFFI async stream + RAG preflight tool selection (~3-5 tools) + structured
      gen for Gemma 4 + Coder Adapter + reasoning-token isolation. RESEARCH-FIRST on
      the owner's EXISTING local plans + grammar/json-schema FFI; build ON them.
      Spec: docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md. Make local models
      work GREAT; surface the determinism visibly.
- [ ] **Post-Osaurus enhancements (P3.1b)** — after import: more MCP, easier+robust
      agents, and a MAS-safe version of key Osaurus capabilities.
- [ ] **GOOSE = OPEN CODE / WORK backend via ENGINE EXTRACTION (R-GOOSE, owner
      DECISION 2026-06-18)** — extract Goose's RUST CORE (Block, Apache-2.0) as a
      crate into agent_core via UniFFI = the FULL engine (repo indexing, git, multi-
      file diffs, deterministic test-and-fix self-correction loop, parallel
      subagents, YAML recipes). Do NOT import the Node/TS Goose DESKTOP (18GB swap
      death) — own SwiftUI skin. Powers WORK mode; engine in shared core so Act/Chat
      tap MCP/subagents too. Osaurus stays the ACT backend. Validate patches vs P8.2.
- [ ] **OpenClaw — FULL PORT, ALL OF IT (R-OPENCLAW, owner DECISION 2026-06-18:
      "don't care about native anymore, I want ALL the other stuff")** — bring in
      the COMPLETE OpenClaw (~/Downloads/openclaw-main, TS/Node + ui), not a
      cherry-pick. Since it's TS/Node, host the full app via WEBKIT (WKWebView) so
      every feature comes along with no rewrite; RESKIN to the pixel-art theme
      (CSS/theme injection) with the TAMAGOTCHI/Companion mascot. If it needs a Node
      backend, gate that Pro/dev (bundled local service); MAS build shows the honest
      "Pro only" state. Owner accepts the heavier footprint for completeness. It's
      the AGENT-EXTENSION slot (separate from Work/Goose; NOT an OpenCode replacement).
      Still evaluate OpenClaw vs Hermes for the LOCAL-model agent (R-HERMES), but
      default to shipping the full OpenClaw. Verdict doc → WebKit-host port + reskin
      + wire to local/cloud models + harness systems; per-feature harden.
- [ ] **Hermes agent — DEEP study (R-HERMES), adopt NATIVELY, NO Hermes name** —
      study HERMES_AGENT_CORE_2_0_DESIGN + manifesto; compare vs OpenClaw for the
      LOCAL-model agent extension (see R-OPENCLAW); namespace stays purged.
- [ ] **Study the best chat/agent apps (R-APPS, owner 2026-06-18)** — besides
      Osaurus: LM Studio, HuggingFace (chat-ui/transformers/candle), Unsloth, Jan,
      Ollama, Open WebUI, Cherry Studio, LibreChat, etc. Mine their SYSTEM PROMPTS
      + architectures + agent/tool/MCP handling; verdict doc on what to adopt.
- [x] Auto-commit + push every slice to GitHub — verify still pushing.
- [ ] **OSAURUS = ACT, FULL IMPORT (owner DECISION 2026-06-18, P3.0)** — bring in
      ALL of Osaurus incl. frontend, ZERO cherry-pick (completeness; don't miss
      code). Clone the full MIT repo (not on disk yet), embed the COMPLETE repo as
      the Act substrate inside Epistemos (Epistemos stays root → tests/IP stay
      home), preserve Osaurus's entitlements/Info.plist/build verbatim, build it,
      then reskin Act's UI to the app. STOP hand-building parallel cowork/Act
      (P7.6) — Act comes from Osaurus. Unsloth (P4.1) training surfaces in the modes.
- [ ] **Osaurus + Unsloth feed the MODES** (owner 2026-06-18): the Osaurus
      deep-cherry-picks/full-port (local server + agent capabilities) and Unsloth
      (model training) must SURFACE INSIDE Act mode — and where it fits, Chat mode
      — not as standalone features. Act/Work run the local agent loop powered by
      the Osaurus-adopted capabilities; training is reachable from the chat. Wire
      them into the shared mode stack, local=cloud parity.
- [ ] Settings decluttered + coherent (P6.4c) — verify it reads clean in-app.

## Settings / staleness / substrate-finish (owner 2026-06-18)
- [ ] **DEEP SETTINGS REPAIR** — beyond the declutter (P6.4c): AUDIT every Settings
      row/toggle/section for things that DON'T WORK or encode OLD ASSUMPTIONS that
      no longer apply and actively mess things up. Fix or remove the stale ones;
      verify each remaining control is wired to real runtime. (Views/Settings/*.)
- [ ] **APP-WIDE STALENESS SWEEP** — there are instances around the app of
      super-old code/assumptions. Grep for stale flags/model names/dead paths/old
      copy and repair or remove them; honest, with regressions. Not just Settings.
- [ ] **SUBSTRATE HEALTH PAGE makes the window SUPER LONG** — layout bug in
      Epistemos/Views/Settings/SubstrateHealthPanel.swift (too many health rows
      stacked). Fix: scrollable/collapsible/paginated so it doesn't blow out the
      window height. Quick, visible win.
- [ ] **SUBSTRATE COMPLETELY FINISHED (except the 70B runtime)** — finish ALL of
      P5/P5.H substrate to T4+ (Cognitive DAG, provenance, Knowledge Core, Halo,
      Simulation, GenUI, XPC, Eidos, EML). ONLY the large-local-model (70B/System G)
      RUNTIME stays owner-gated; everything else gets done.
- [ ] **MINE SYSTEM G LOGIC → apply to beneficial app parts (non-runtime)** —
      Epistemos/SystemG/* (SystemGRunSeam / RealSystemGRunSeam / SystemGWiring) +
      AnswerPacket/SovereignGate/RuntimeRouter patterns. Extract the reusable LOGIC
      (verifiability, AnswerPacket provenance, run-event logging, sovereign gating,
      router) and apply it to the parts of the app that truly benefit — WITHOUT
      arming the gated 70B runtime itself.
- [ ] **INFUSE EPISTEMOS IP INTO ACT (Osaurus) + WORK (Goose)** — Act and Work are
      not vanilla Osaurus/Goose: wire the owner's specific capabilities/IP into
      them (deterministic schemas P8.2, Eidos, Knowledge Core, memory/vault, the
      determinism/verifiability gates, theme). They inherit hardening from the
      engines AND gain Epistemos's superpowers.

## Code review + agent frameworks (owner 2026-06-18)
- [ ] **"Thermonuclear" code-quality review (R-CODEREVIEW)** — it's a NAME for an
      ultra-aggressive exhaustive review. Deliver BOTH: (1) a LOOP process step that
      deep-reviews the whole app's quality (correctness/dead-code/honesty/perf/drift)
      and files findings; (2) an IN-APP code-review feature in Work/Open Code mode
      (gated by P8.2 schemas + Goose self-correction). Real findings only.
- [ ] **Agent-creation frameworks deliberation (R-AGENTFW)** — research Vercel AI
      SDK (TS, MIT), Google ADK/Agent Builder (open), Cursor agent (proprietary,
      UX-only). Verdict per framework: usable IP vs patterns-only + license. Likely
      adopt PATTERNS + agent-creation UX natively (Companion/tamagotchi P2.6 +
      Osaurus config + Goose subagents), not import SDKs. Recommend the native design.

## Models (owner 2026-06-18)
- [ ] **IN-APP HUGGINGFACE + GITHUB MARKETPLACE (owner 2026-06-18)** — bring the HF
      Hub experience into the app: SEARCH/BROWSE models, ADAPTERS/LoRAs, and quants
      (HF public API huggingface.co/api/models + GitHub search API), with one-click
      INSTALL via the bring-your-own-model importer (MLX/GGUF lanes). Show size +
      format + whether it fits (memory gate + Run-anyway). Adapters tie into the
      Unsloth/training + MoLoRA lanes. Honest: only install/run on-device-supported
      formats. This is the "HuggingFace system in the app" the owner wants.
- [ ] **ARXIV PULL SYSTEM (owner 2026-06-18)** — easily search + pull from arXiv
      (arxiv.org API) directly into the app; ingest papers (PDF/abstract/metadata)
      into the vault / Knowledge Core so they're searchable + usable by chat/agents.
      Pairs with HuggingFace (pull a paper's model) + the autoresearch loop. Honest
      ingestion (real fetch + index), MAS-safe.

- [ ] **BRING-YOUR-OWN-MODEL — import ANY model from HuggingFace/GitHub (owner 2026-06-18)**
      Open-ended model import: paste a HF repo (or GitHub) URL, DETECT the format +
      list available files/quants (MLX, GGUF Q2..Q8/IQ, safetensors), pick one, then
      INSTALL + RUN it via the matching on-device lane — MLX-Swift (in-process, MAS-OK)
      or the GGUF llama-cli lane (Pro, flag-gated). Reuse ModelDownloadManager + the
      P1.8 progress UI; memory-gate honestly + the new "Run anyway" override so the
      user can attempt larger community quants. HONEST about what actually runs
      on-device: MLX + GGUF supported; raw PyTorch/safetensors needs an offline
      mlx_lm.convert step (Pro/dev) — surface that, don't fake a load. This lets the
      owner upgrade/swap to any model + grab community quants of bigger models.

- [ ] **Add Unsloth Gemma 4 12B 2-BIT GGUF (low-RAM)** — owner wants the very-low-RAM
      2-bit (Q2_K / IQ2) GGUF of Gemma 4 12B from Unsloth (~4-5 GB vs ~8+ at 4-bit),
      so 12B-class quality fits comfortably on the 16 GB Mac. Find the exact Unsloth
      repo/file (e.g. unsloth/gemma-4-12b-it-GGUF Q2_K/IQ2), wire into the GGUF lane
      as an installable candidate alongside the existing 12B; honest memory-gate
      (it's small so it should just fit). Pairs with the Variant Ladder + memory
      work. Verify it loads + generates.
- [ ] **Add an on-device VISION RUNTIME for Holo (mlx-vlm or best) (owner 2026-06-18)**
      — R-HOLO verdict: the GGUF lane is text-only, so Holo-3.1-4B (VLM) needs a real
      vision runtime. Research the best on-device option (mlx-vlm is the leading
      Apple-Silicon VLM runtime; also consider llama.cpp multimodal/mmproj). Wire it
      as a new vision-inference lane, then run Holo through it into the computer-use
      stack (DeviceAgentService / VisualVerifyLoop / Screen2AXFusion) for GUI
      grounding. Honest (real vision, no faking), Pro/MAS gating, memory-gated.
      Verdict doc + wire-in + verify it actually does image→action grounding.
- [ ] **Add Holo-3.1-4B as a computer-use VL model (huggingface.co/Hcompany/Holo-3.1-4B)**
      — H Company's Holo is a VISION-LANGUAGE model for COMPUTER USE / GUI grounding
      (screen/web-agent navigation). Research the readme; wire it into the existing
      computer-use/vision stack (Omega/Inference DeviceAgentService, VisualVerifyLoop,
      Screen2AXFusion, ScreenCaptureService) as the visual-grounding model for the
      agent driving the screen. 4B VLM → needs a vision runtime (mlx-vlm or similar);
      evaluate on-device feasibility + Pro/MAS gating. Verdict doc + wire-in; honest.
- [ ] **Add LiquidAI LFM2.5-8B-A1B GGUF (huggingface.co/LiquidAI/LFM2.5-8B-A1B-GGUF)**
      — MoE, 8B total / ~1B ACTIVE = very light + fast (well within 16 GB, likely
      MAS-viable not just Pro). Wire into the GGUF lane as an installable candidate;
      EVALUATE best role (dedicated fast/quick local model? a Fast-tier option? a
      cheap tool/triage model?) and document the verdict. Memory-gate honestly (it's
      small so it should just fit). Add the LiquidAI/LFM logo to P6.1. Verify it
      loads + generates.
- [ ] **Add Gemma 4 26B-A4B QAT GGUF (unsloth/gemma-4-26B-A4B-it-qat-GGUF)** — owner
      wants this MoE (26B total / ~4B active) running. The MLX 4-bit variant is
      already cataloged (`gemma4_27BA4B4Bit` = mlx-community/gemma-4-26b-a4b-it-4bit,
      InferenceState.swift:44) but it's gated at 18 GB min (line ~287) so it's
      blocked on the 16 GB Mac. WIRE the Unsloth QAT **GGUF** variant into the Pro
      GGUF runtime lane (llama-cli, flag-gated EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0,
      MAS-forbidden) — QAT GGUF is smaller than MLX 4-bit and is what the GGUF lane
      runs. Add as an installable candidate; memory-gate honestly but allow the new
      "Run anyway" override + the corrected available-memory estimate so a 16 GB Mac
      can attempt it (MoE = ~4B active so it's lighter than a dense 26B). Verify it
      loads + generates via the GGUF lane. Pairs with the B1 Variant Ladder.

## Full-port targets (owner 2026-06-18 — deeply analyze/research, then FULL port)
- [ ] **R-ASSISTANTS — survey the TOP assistant/agent apps on GitHub (owner 2026-06-18)**
      Beyond R-APPS: deep-scan the best open-source ASSISTANT-class apps and mine
      their system-prompts + architectures + UX. Cover: PERPLEXITY-style answer
      engines (Perplexica, Morphic, Khoj, scira, Farfalle, Onyx), COMPUTER-USE
      agents (Open Interpreter, self-operating-computer, UI-TARS, Agent-S,
      browser-use, OpenClaw), and general assistant/agent apps. Verdict doc: per app
      what to adopt natively (patterns/prompts/UX) vs skip, license. Feed the best
      into Chat/Act/Work + the deep-research (DeerFlow) + computer-use stacks.
- [ ] **DeerFlow 2.0 — research + (likely) FULL port (R-DEERFLOW)** — ByteDance's
      multi-agent DEEP-RESEARCH framework (planner→researcher→reporter, web+tools).
      Owner wants it ported completely, reskinned to the app's pixel-art theme, and
      connected DEEPLY to the app to add research dynamics. Deeply research first
      (clone + read; it's Python/LangGraph → adopt the multi-agent deep-research
      ORCHESTRATION natively into agent_core, NOT a Python sidecar). Wire it into
      the existing autoresearch loop + agents + arXiv/HF/Knowledge-Core pulls so a
      query can spin a real multi-agent research run. Verdict doc → native port +
      reskin, ProvenanceGate + honest gating, per-feature harden.
- [ ] **PORT github.com/kuku-mom/kuku (R-KUKU)** — owner wants a FULL port; deeply
      research first (not local — clone + read; I don't know it off-hand). EVALUATE
      where it best fits — likely a VISUALIZATION surface (the Eidos visualizer /
      graph / live theater) or wherever its strength lies. Verdict doc (what it is,
      stack, license, native-vs-WebKit, best home in the app), then full port +
      pixel-art reskin, ProvenanceGate + honest gating, per-feature harden.
- [ ] **LiteLLM Agent Control Plane (R-LITELLM-CP)** — github.com/LiteLLM-Labs/
      litellm-agent-control-plane. Deeply research; maps onto our agent
      orchestration / routing / control (RuntimeRouter + agent_core loop + Act).
      It's LiteLLM/Python → adopt the PATTERNS natively (control-plane design,
      routing policy), don't run a Python sidecar (NO-SIDECAR/MAS). Verdict doc +
      port the adoptable parts; honest gating, per-feature harden.
- [ ] **vercel-labs/json-render (R-JSONRENDER)** — github.com/vercel-labs/json-render.
      Deeply research; maps onto Schema-First GenUI (P5 substrate) + the deterministic
      schema engine (P8.2): render JSON/typed-schema payloads → UI. It's TS → adopt
      the pattern natively (SwiftUI) or via WebKit. Verdict doc + port; ties our
      deterministic schemas to a real render layer. Honest, per-feature harden.
- [ ] **PORT github.com/Alphanimble/htmlstream (R-HTMLSTREAM)** — owner wants a FULL
      port. Deeply analyze/research first (not local — clone + read). Likely pairs
      with P7.2 (HTML workspace + chat-drivable canvas / live viewer). Verdict doc
      (what it is, stack, license, native-vs-WebKit mapping), then full port +
      pixel-art reskin, ProvenanceGate + honest gating, per-feature harden.

## Field Theory port (owner 2026-06-18)
- [ ] **PORT github.com/afar1/fieldtheory (R-FIELDTHEORY)** — owner wants the WHOLE
      thing ported into Epistemos, deeply researched first (it's not local — clone +
      read it). Reskin to the app's PIXEL-ART look (FONTS mainly) and update anything
      visually inconsistent. WebKit is OK if the surface needs it. Verdict doc first:
      what it is, language/stack, license, how it maps in (native vs WebKit), then
      port + reskin. ProvenanceGate + honest gating; per-feature harden.

## Verdict docs already produced (decisions, not yet built)
R-VOICE (Kokoro+MOSS+filter), R-EVE (pattern only), R-OKF (export+privacy+dedup),
R-PROMPT (cache-stable prefix + lean schemas), CHAT_UX_MAP (3 axes). These are
DECISIONS — the BUILD + in-app verification still has to happen.

## Surfaces — web / browser / HTML (researched; tracked so not dropped, 2026-06-18)
- [ ] **P7.2 HTML WORKSPACE CANVAS** — fix the broken HTML workspace
      (`Epistemos/Models/HTMLWorkspacePackage.swift`) + an HTML `<canvas>` the
      chat can DRIVE ("be in the HTML page, do anything with HTML"). Queued
      behind the picker/chat audit.
- [ ] **SURFACE BROWSER USE in Act/Work** — `agent_core/src/tools/browser.rs`
      (~52 KB, shipped Pro: browser_navigate / snapshot / click / type / scroll /
      press / close) EXISTS but is NOT reachable from chat. Surface it in
      Act/Work so the agent can drive a browser / act on the web from chat.
      Pro-gated. (Will land naturally with the Osaurus Act import + tool exposure.)
- [ ] **P-OBSCURA: build the in-app Obscura browser** — researched, runtime
      NEVER built. READ FIRST: `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`
      + `docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md` §B3 (W6-A..W6-I: Obscura +
      deno_core + Eidos runtime, queued) + EPISTEMOS_HERMES_MANIFESTO (WKWebView
      built-in browser). BUILD the working in-app browser (Rust backend /
      WKWebView), tied to WORK mode + the HTML canvas + browser-use. Pro/dev-gated.

## Research-corpus completeness (RECURRING — owner mandate 2026-06-18)
- [ ] **Recurring corpus sweep**: each loop pass, scan `docs/fusion/*` (131 files)
      + the owner's prior plans + this session's queries, and ADD any
      researched/requested-but-untracked item to THIS ledger so nothing the owner
      researched is silently dropped. Do it incrementally (a few docs/pass) — this
      is a standing task, never "done".

## Stealth browsing + Best-of preset (researched 2026-06-18 → docs/RESEARCH_STEALTH_AND_BESTOF_PRESET_2026_06_18.md)
- [ ] **P-STEALTH: undetected/stealth browsing** — VERDICT: vendor
      `vibheksoni/stealth-browser-mcp` (MIT; nodriver + CDP + FastMCP; 97 tools;
      bypasses Cloudflare/Queue-It) via the EXISTING MCP path (MCPUrlServerDirectory/
      MCPBridge). Pro/dev-gated (Python subprocess), pinned + hardened, authorized
      use. Wire a `stealth` option on browser-use (browser.rs) + an Obscura
      WKWebView "fingerprint hardening" toggle; browser-use mainly drives the
      in-app Obscura browser, stealth-MCP is the escalation for protected sites.
      Engines: nodriver (Chrome), Camoufox (Firefox), SeleniumBase UC Mode.
- [ ] **P-BESTOF: best-of preset (powerful out of the box)** — curated default
      set of the BEST real working superpowers, each Pro/MAS-gated + user-toggle,
      wired into the P2.1 tool panel / capability explorer. Baseline = Anthropic's
      7 reference servers + GitHub MCP + Context7 + Playwright. KEY FINDING: most
      is ALREADY native in Epistemos (file_ops, web_fetch/search, browser.rs, Pro
      git, code_execution, memory+vault+Knowledge Core+Eidos+Halo, think) — so the
      preset = curate + gate + EXPOSE, not import-everything. Deliverable: a pure
      tested EpistemosBestOfPreset manifest {id, capability, gate, source, license}
      + a one-tap "Enable recommended power set" in P2.1 (MAS-safe subset; Pro adds
      shell/git/browser/CLI); external MCP picks only when actually wired (Keychain),
      never a fake-on toggle; prefer vendor-maintained MCPs.

## Unfinished-research sweep top items (2026-06-18 → docs/UNFINISHED_RESEARCH_SWEEP_2026_06_18.md)
Local/chat, verified-against-code, not-blocked (full list + eras in the sweep doc):
- [ ] **OBS-1/2/3 Eidos→chat wiring** — EidosBridge FFI (W-46) + closed-citation
      emit-gate into ChatCoordinator (W-47) + "Retrieved by Eidos" panel (W-48).
      Eidos substrate done (~472 tests); chat wiring not. HIGH value.
- [ ] **OBS-5 Eidos cold-build Swift-6 isolation fix** — the EidosBridge/Wiring
      MainActor-UniFFI bug (cold/CI build only). Quick win; already flagged.
- [ ] **EML-2 / EML-3** — inject shipped EML energy into ConfidenceRouter routing
      + vault-recall re-rank (≥2pp on F-VaultRecall-50).
- [ ] **LF-1/2/3 kill MoLoRA/QLoRA Python subprocess** — NO-SIDECAR breach
      (molora_inference.py + __pycache__ live); port to in-process MLX-Swift.
- [ ] **REG-1 KV-Direct-Gate harness**, **REG-3 NightBrain bodies**, **REG-2 T20
      Variant Ladder** (honest local routing), **REG-6 per-model memory folder +
      chat-as-graph-node**, **SIM-4 real MLX-Swift LoRA hot-swap**, **LI-2/LI-3
      Residency PatternBoost + ColdStream** (newest local-routing research).
- NOTE: "EML" = elementary-math IR, NOT episodic memory (separate CoALA episode
  track). Simulation donor mining is BLOCKED (Hermes coupling). Don't conflate/revive.

## More owner asks (2026-06-18)
- [ ] **R-APPS: study the best OSS chat/agent apps** — LM Studio, HuggingFace
      (chat-ui / transformers / candle), Unsloth, Jan, Ollama, Open WebUI, Cherry
      Studio, LibreChat + best others. Deep-read SYSTEM PROMPTS, architectures,
      agent loops, tool/MCP handling, local-model + structured-output patterns, UX.
      Write a verdict doc (adopt-natively vs skip, license, via ProvenanceGate);
      take the best system-prompt + architecture ideas honestly. (Research phase.)
- [ ] **P2.7: skill/tool/superpower/MCP INSTALL + MANAGEMENT surface** — install
      from external sources (GitHub repos AND MCP registries: modelcontextprotocol
      registry, Smithery, mcp.so, glama, awesome-mcp-servers). Must PERSIST
      installed ones (survive restarts) AND USE them once installed (wired into the
      tool catalog / executionPlan / MCPBridge — not just listed). Settings
      management pane: browse / install / enable / disable / update / remove. Honest
      gating (Pro/MAS, Keychain for tokens, security.rs for subprocess). Pairs with
      P-BESTOF preset + P2.3 MCP + P2.4 skills.
- [ ] **default-Qwen-4B bug repair** — something auto-defaults to Qwen 4B instead
      of a Fast Gemma; fix the default-resolution seam (effectiveLocalTextModelID /
      sanitizedStoredLocalChatModelID), keep both Qwens explicit-only.

## OWNER FINAL DIRECTIVE 2026-06-18 — BUILD FROM THE RESEARCH (100% wanted)
Every R-* verdict + ledger item must become a SHIPPED, in-app-verified slice —
nothing optional. Loop is now BUILD-FIRST: each pass ships a verified code slice
from the TOP sweep items / R-verdicts BEFORE any new research (cap: ≤1 verdict doc
per pass). Keep until all done + hardened (rule #6/#8).
- [ ] **R-GOOSE: port/vendor Block's Goose into agent_core** — github.com/block/goose
      (Apache-2.0, Rust). Owner wants it absolutely-or-almost-entirely PORTED (it's
      Rust → vendor into agent_core, not just the existing CLI passthrough
      GooseHandler). Evaluate fusing its WebKit UI with chat. Research-first +
      ProvenanceGate (F-ProprietaryCompression-ProvenanceGate: quarantine→inspect→
      benchmark→choose direct_import/adapter_wrap/clean_room). Honest, Apache-2.0
      attribution.
- [ ] **R-OPENCLAW: study ~/Downloads/openclaw-main (LOCAL, TS/Node + ui)** — perfect
      native capabilities from its patterns (sandbox Dockerfiles, agent loop, UI).
      Adopt natively (no TS fork); ProvenanceGate.
- [ ] **R-HERMES: deep-study docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md +
      manifesto for native-capability ideas** — adopt NATIVELY with ZERO Hermes
      naming (namespace stays purged; use LocalAgent/Runtime prefixes). Ideas only,
      not the name.
- [ ] **R-APPS** (from prior msg): study LM Studio / HF chat-ui+transformers+candle /
      Unsloth / Jan / Ollama / Open WebUI / Cherry Studio / LibreChat — system
      prompts, architectures, agent loops, tool/MCP, local+structured-output, UX →
      verdict doc (adopt-natively vs skip, license, ProvenanceGate).

## OWNER 2026-06-18 — Goose engine-extraction + per-feature hardening + guardrails
- [ ] **R-GOOSE refined = ENGINE EXTRACTION** (CONFIRMED arch: Chat=Epistemos engine,
      Act=Osaurus, Work/OpenCode=GOOSE). Pull the raw Goose RUST CORE (Apache-2.0,
      github.com/block/goose) into agent_core as a crate via UniFFI = the FULL engine
      (repo indexing, git lifecycle, multi-file diffs, deterministic test-and-fix
      self-correction loop, parallel subagents, YAML recipes). Do NOT import the
      Node/TS Goose DESKTOP (dual-process would swap-kill the 18GB M2 Pro) — own
      SwiftUI skin. Goose engine lives in the shared Rust core so Act/Chat can tap
      its MCP/subagent pieces; surfaced primarily through Work. Validate Goose code
      patches against the P8.2 deterministic schemas. ProvenanceGate the vendor.
- [ ] **GOOSE GUARDRAIL** — isolate the extracted Goose core behind Work mode + a
      feature flag; keep Chat/Act on their own engines; add regression coverage
      PROVING Chat + Act are unchanged after Goose lands. Must make Work much better,
      NEVER destabilize the working chat.
- [ ] **PER-FEATURE HARDENING + NO-DRIFT GUARANTEE (rule #6 extension, applies to
      ALL items)** — every feature/item gets its OWN hardening phase: own regression
      tests + re-verify the items it touches still work in-app + a "HARDENED <item>"
      log line. An item isn't done until hardened AND protected from later
      regression. Keep re-running the recurring corpus sweep so nothing disappears
      under compression.
- [ ] **P8.1b CHAT DEEP-REPAIR (first-class)** — deeply repair the messy Epistemos
      Chat: clean + maintainable + FULL capability, no IP loss (Eidos/KC/Halo/memory/
      skills). Use Osaurus chat structure as the refactor reference (after import).
- [ ] **P5.H deep-harden + FINISH the substrate research** — Cognitive DAG,
      provenance, Knowledge Core, Halo, Simulation, GenUI, XPC: finish + deep-harden
      each (per-feature hardening). 100% mandate.

## Primitive-upgrades mine → P5/P8 (2026-06-18 → docs/PRIMITIVE_UPGRADES_MINE_2026_06_18.md)
- [ ] **FIRST DOMINO (owner decision)**: the entire agent_core/src/research/* tree is
      #[cfg(feature="research")] default-OFF, NEVER compiled into the app. Cores are
      real + 1,800+ tests, but reaching bridge.rs needs: decide `research` compiles
      into the MAS/Pro lib (or promote modules out of research/) + UniFFI export +
      Swift call-site. SIGN-OFF NEEDED before the EML/primitive batch can ship.
- [ ] **Tier-1 fast wins** (real Rust + LOCAL, M each after the domino): A1 EML-2
      ConfidenceRouter scoring, A2 EML-3 VaultRecall re-rank, A4 EML-1 FFI+HealthRow,
      B1 T20 Variant Ladder (mostly live), F1 Active-Assembly minimizer, F3 Sinkhorn
      brain_routing, F4 confidence_floors, F5 interrupt_calibration, F6 hybrid_memory
      folder, C1 info_ir→AnswerPacket.confidence, D1 ternary KV/steering.
- [ ] Tier-2 (perf/proof/gated) + Tier-3 (E1/E2 residency, capability-ceiling, must
      NOT move bytes until owner-gated) — see the mine doc.

## Settings / staleness / substrate-finish (owner 2026-06-18)
- [ ] **DEEP SETTINGS REPAIR** — audit EVERY Settings row/toggle for broken or
      stale-assumption controls; fix/remove; verify each remaining control wired to
      real runtime. (✓ first slice: SubstrateHealthPanel collapsible 13d2b5307.)
- [ ] **APP-WIDE STALENESS SWEEP** — find + repair/remove super-old instances
      (stale flags/model names/dead paths/old copy) with regressions, not just
      Settings.
- [ ] **FINISH SUBSTRATE to T4+ (P5/P5.H)** — Cognitive DAG, provenance, Knowledge
      Core, Halo, Simulation, GenUI, XPC, Eidos, EML all to T4+. Only the 70B/System
      G RUNTIME stays owner-gated.
- [ ] **MINE SYSTEM G LOGIC → app** — extract reusable logic from Epistemos/SystemG/*
      (AnswerPacket/SovereignGate/RuntimeRouter/run-event-log/verifiability) and
      apply to app parts that truly benefit, WITHOUT arming the gated 70B runtime.
- [ ] **INFUSE EPISTEMOS IP INTO ACT (Osaurus) + WORK (Goose)** — wire in the
      deterministic schemas (P8.2), Eidos, Knowledge Core, memory/vault, the
      determinism/verifiability gates, and theme, so Act/Work inherit the engines'
      hardening AND gain Epistemos superpowers (not vanilla).

## R-CODEREVIEW + R-AGENTFW (owner 2026-06-18)
- [ ] **R-CODEREVIEW ("thermonuclear" = a NAME for ultra-aggressive exhaustive
      review)** — research the best deep-review method; deliver TWO ways: (a) a LOOP
      PROCESS step that runs a whole-app deep review (correctness, dead/stale code,
      honesty-constraint violations, perf, arch drift) → files findings; (b) an
      IN-APP code-review feature in Work/OpenCode (review the open repo, gated by
      P8.2 schemas + Goose's self-correction loop). Real findings only.
- [ ] **R-AGENTFW agent-creation frameworks** — research + DELIBERATE: Vercel AI SDK
      (TS, MIT), Google ADK/Agent Builder (open), Cursor agent (proprietary —
      approach/UX only). Likely = ADOPT PATTERNS + agent-creation UX natively (tie
      into Companion/tamagotchi builder + Osaurus agent config + Goose subagents),
      NOT import SDKs. Verdict doc per framework: usable-IP vs patterns-only,
      license, what to take, recommended native design.

## GUARDRAILS — ENFORCE ON EVERY PASS (owner 2026-06-18, CRITICAL)
1. **DELETION GUARDRAIL** — thermonuclear review / hardening / dedupe may NOT
   delete NEW or IN-PROGRESS features (they look "unused" because they're mid-build
   / not yet wired) or ANY owner-requested ledger item. DELETION IS A LAST RESORT —
   prefer dedupe / consolidate / WIRE-IT-UP. Only remove code that is PROVABLY dead
   AND confirmed not part of any in-flight ledger item; when uncertain → KEEP + flag.
   Commit deletions SEPARATELY (own commit, easy revert). (✓ already applied: the
   appleIntelligenceSection removal was provably dead [1 self-ref] + capability
   preserved+tested + its own commit; the legacy popovers were uncertain → KEPT +
   flagged, not deleted.)
2. **CODE REVIEW IS RECURRING** — run the deep whole-app review MULTIPLE times
   (each phase + a periodic full-app pass), not once. R-CODEREVIEW loop step recurs.
3. **NO-SIDECAR clarification (Open Code)** — NO non-Swift app. Goose is RUST →
   compiles into agent_core via UniFFI (that's why it's the Open Code backend).
   Vercel(TS)/Google(Py)/Cursor(proprietary) are NOT Swift/Rust → adopt their
   PATTERNS natively, NEVER run Node/Python sidecars (NO-SIDECAR / MAS / 18GB
   memory). Same for R-OPENCLAW (TS) and R-APPS picks: patterns only, no sidecar.

## Full-port + model targets (owner 2026-06-18, batch)
Same posture for all ports: deeply research first (clone+read, NOT local), verdict
doc (what it is / stack / license / native-Swift-Rust-vs-WebKit mapping), then FULL
port + pixel-art reskin (fonts mainly), ProvenanceGate + honest gating, per-feature
harden. NO-SIDECAR: TS/Py = adopt patterns natively (or WebKit where the surface
needs it), never run a Node/Python sidecar.
- [ ] **R-FIELDTHEORY** — github.com/afar1/fieldtheory: research + FULL port into
      Epistemos, reskin to pixel-art (fonts), fix visual inconsistencies. WebKit OK
      if the surface needs it.
- [ ] **R-HTMLSTREAM** — github.com/Alphanimble/htmlstream: research + FULL port;
      likely pairs with P7.2 (HTML workspace + chat-drivable canvas / live viewer).
- [ ] **R-LITELLM-CP** — github.com/LiteLLM-Labs/litellm-agent-control-plane: maps
      onto our agent orchestration/routing (RuntimeRouter + agent_core loop + Act).
      Python → adopt the control-plane/routing-policy PATTERNS natively, NO sidecar.
      Verdict doc + port the adoptable parts.
- [ ] **R-JSONRENDER** — github.com/vercel-labs/json-render: maps onto Schema-First
      GenUI (P5) + the deterministic schema engine (P8.2) — render JSON/typed-schema
      payloads → UI. TS → adopt natively (SwiftUI) or via WebKit. Ties our
      deterministic schemas to a real render layer. Verdict doc + port.
- [ ] **LFM2.5-8B-A1B model** — huggingface.co/LiquidAI/LFM2.5-8B-A1B-GGUF: light MoE
      (8B total / ~1B ACTIVE, well within 16GB → likely MAS-viable, not just Pro).
      Wire into the GGUF lane as an installable candidate (CLEAN follow-on to the
      26B-A4B pattern just landed — fetch real HF provenance, new stage or reuse,
      memory-gate honestly [small, should fit]). EVALUATE + document its best role
      (dedicated fast/quick local? Fast-tier option? cheap tool/triage model?). Add
      the LiquidAI/LFM logo to the P6.1 lobehub logo set. Verify loads+generates.

## R-HOLO — Holo-3.1-4B VL for computer-use (2026-06-18 → docs/RESEARCH_HOLO_VL_2026_06_18.md)
- HONEST VERDICT: Holo-3.1-4B is a VISION-language model; the GGUF lane is text-only
  (gguf_cli.rs:348 supports_vision=false). NOT added as a fake text-GGUF candidate
  (would fake vision). REAL GAP to build:
- [ ] **Vision GGUF lane** (Pro) — GgufVisionCliProvider via llama-mtmd-cli + the
      model's mmproj-*.gguf (or an MLX-VLM Swift path); supports_vision=true; behind
      the GGUF flag + Pro gate, security.rs hardened. Then add Holo as a REAL vision
      candidate (fetch HF provenance for both the weights + mmproj).
- [ ] **Wire Holo → computer-use** — local vision policy in DeviceAgentService/
      ComputerUseBridge/VisualVerifyLoop (screenshot → Holo → grounded action/
      function-call); function-calls validated vs P8.2 deterministic schemas; honest
      gating (Pro/dev; MAS keeps the bounded/native computer-use path).

## R-KUKU verdict (2026-06-18 → docs/RESEARCH_KUKU_2026_06_18.md)
Kuku (kuku.mom / github.com/kukume) = a local-first AI note-taking app (Tauri +
SolidJS/WebKit, ProseMirror, local Whisper STT, graph, wikilinks, .md; client MIT
/ server AGPL) — Epistemos's closest sibling. VERDICT: SKIP the code (Tauri/TS, not
native; AGPL server). ADOPT 2 patterns natively:
- [ ] **AI MEMORY SHARING** — expose the vault/Knowledge Core/Eidos as a read-only
      LOCAL memory endpoint (local OpenAI/Ollama server OR an MCP "epistemos-memory"
      server) so any AI tool (Claude Desktop/Cursor/MCP clients) can query the
      user's notes as long-term memory. Keychain-token, localhost-only, user-toggled.
      Pairs with P-BESTOF + P2.7. (Epistemos's moat, made outward-facing.)
- [ ] **MEETING/LECTURE NOTE** — record → on-device STT (Apple Speech / local
      Whisper audio lane) → Epdoc note + AI summary. Slots into R-VOICE. On-device only.
