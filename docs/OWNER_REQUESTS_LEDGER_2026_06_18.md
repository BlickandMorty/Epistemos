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

## REALITY-AUDIT RULE (applies to every line)
1. Build the app; actually trace the UX path the owner would take.
2. If a feature is hidden unless cloud/Pro/some-state — that's a FAIL for a
   local-first owner. Make it reachable + functional on LOCAL by default; gate
   only the genuinely-cloud/Pro-only pieces, and when gated, show WHY (honest,
   visible), never just vanish.
3. No feature is "done" until the owner can demonstrably use it.

## REOPENED — owner reports these DON'T WORK (fix first, verify in-app)
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
- [ ] **GOOSE — research + LIKELY PORT (R-GOOSE, owner 2026-06-18)** — Block's Rust
      agent (github.com/block/goose, Apache-2.0). Owner wants it "absolutely or
      almost entirely ported" — Rust ⇒ real port/vendor into agent_core feasible;
      evaluate fusing its WebKit UI with the chat. Deep verdict + port.
- [ ] **OpenClaw — study to perfect native capabilities (R-OPENCLAW)** — LOCAL repo
      ~/Downloads/openclaw-main (TS/Node + ui). Mine for native-capability ideas.
- [ ] **Hermes agent — DEEP study (R-HERMES), adopt NATIVELY, NO Hermes name** —
      study HERMES_AGENT_CORE_2_0_DESIGN + manifesto for ideas; namespace stays purged.
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
