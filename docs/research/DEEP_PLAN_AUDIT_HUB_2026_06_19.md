# DEEP PLAN AUDIT — Research Hub (READ-FIRST) — 2026-06-19

> **MASTER-LOOP READ-FIRST MANDATE (owner 2026-06-19):** before ANY editing or
> building, the loop MUST read this hub AND every research doc indexed below. The owner:
> *"it must read all research before editing and building."* Research is deliberate and
> continuous; build on top of it, never ahead of it.

**Why this exists (owner 2026-06-19, verbatim intent):** run a continuous deep-research
loop over the ENTIRE plan to make sure there are NO issues — nuanced things like the
Hermes/Osaurus overlap, OpenClaw, the best proven reskin approach, how to handle the
SETTINGS of each cloned thing (e.g. OpenClaw) and give it a deep Epistemos revamp; go
through ALL current app parts that can be researched for what's to come, and ALL the
plan/prompt/ledgers/directives. Do as much Hermes + OpenClaw + Osaurus research as
possible. Find where the app should STOP reinventing and just USE the proven LOGIC from
the cloned ones. Things have been BROKEN — make sure it's all fixed, explicitly debugged,
and pruned of unnecessary things. Make the chats truly engage with the app's skills/tools
(all working). Target: an AI-native note-taking app that SUPERSEDES Obsidian-fused-with-
Codex / Claude-desktop / its-own-terminal, Tolaria, Notion CLI, etc. — deeply integrated.

## Index of ALL research docs (read every one before building)
- `docs/research/HERMES_ACT_FUSION_MAP_2026_06_19.md` — Hermes capabilities → seams.
- `docs/research/OSAURUS_ACT_CONNECTION_MAP_2026_06_19.md` — Osaurus as Act engine.
- `docs/research/OPENCLAW_UI_EMBED_MAP_2026_06_19.md` — OpenClaw WebKit-host plan.
- `docs/research/HERMES_OSAURUS_OVERLAP_AND_DESTINATION_2026_06_19.md` — the 4-item
  Hermes lift, no Osaurus overlap, in-process destination.
- `docs/RESEARCH_CUA_2026_06_18.md` — trycua/cua computer-use verdict.
- `docs/research/RESKIN_PLAYBOOK_2026_06_19.md` — (S2) pixel-art reskin across SwiftUI + WebKit; consolidation not new system.
- `docs/research/COMPETITOR_SUPERSESSION_2026_06_19.md` — (S5) gaps vs Obsidian/Claude/Codex/Tolaria/Notion + killer differentiators.
- `docs/research/SETTINGS_REVAMP_CLONES_2026_06_19.md` — (S3) absorb OpenClaw/Osaurus/Goose settings into one native pixel-art model; consolidate MCP-install.
- `docs/research/CHAT_TOOLS_INTEGRATION_AUDIT_2026_06_19.md` — (S4) **REAL root cause of broken tools/skills: chats never ENTER the tool loop** (Gemma gated out, non-OpenAI/Anthropic cloud gets no tools); skills 3-store path mismatch; prune list.
- `docs/research/STOP_REINVENTING_AUDIT_2026_06_19.md` — (S1) **KEYSTONE: the 4 broken areas are BUILT-THEN-NOT-WIRED** — dead RuntimeRouter (=Qwen-pin root), fake constrained decoder (T1), skills compiled-out/path-mismatch, dead self-evolution, staging-purge defeats download-resume (=corrupt root). Mostly WIRE/DELETE, not import-a-clone.
- `docs/research/HERMES_OSAURUS_OPENCLAW_WIRING_R2_2026_06_19.md` — (S8/R2 deepen) code-level wiring for the 4 Hermes lifts + OpenClaw bridge table + Osaurus generator-swap; session-search ~70% built but wrong dir; ship compaction deterministic; 6 open questions.
- `docs/research/COMPUTER_BROWSER_USE_2026_06_19.md` — (S10) browser-use hardened-but-starved; computer-use mature native stack; cua Lume lift + Apple-container tiers; Holo-3.1 vision lane; stealth nodriver=AGPL flag; Act=home.
- `docs/research/PLAN_CONSISTENCY_SWEEP_2026_06_19.md` — (S7) **FIX-THE-PLAN list**: false [x] un-ticks, picker contradiction C3, 6 gaps (incl. RuntimeRouter as its own line), 5 risks (P3.0 would break MAS sandbox; flag-OFF ≠ done), duplicate consolidation.
- `docs/research/WHOLE_APP_FORWARD_AUDIT_2026_06_19.md` — (S6) surface inventory + readiness; **3-engine toggle doesn't exist as a primitive yet** (top prep); orphans to prune-in-pairs; ChatCoordinator+InferenceState convergence risk.
- `docs/research/TOOL_SELECTION_COLBERT_2026_06_19.md` — (S12) lexical selector today (right shape, weak scorer); LFM2-ColBERT-350M as a learned retriever via a `ToolScorer` trait swap; in-process GGUF FFI, Pro-gated; downstream of loop-entry; LFM Open License → ProvenanceGate.
- `docs/research/SUPERSESSION_GAPS_PLANS_2026_06_19.md` — (S16) buildable specs for the 4 unmapped gaps: R-WEBCLIP (share-ext clipper, MAS), R-VAULT-MCP-SERVER (stdio MCP over the existing dispatcher, anti-Tolaria, Pro — lowest-risk win), R-SYNC (iCloud-Drive + invert SoT, high blast radius — do later), R-LIVE-ARTIFACTS (revive ArtifactHostView via HTMLWorkspace+data.json — lowest-risk win). Added as ledger items.
- (Appended as the loop produces them — keep this index complete.)

## METHODOLOGY — ITERATIVE DEEPENING + BREADTH (owner 2026-06-19)
Owner: *"iterate on that research and produce more research from other things I mentioned —
after a round of research, iteratively go deeper, but add in more topics."* So each round:
1. **DEEPEN** — take a completed slice's doc and go a level deeper (edge cases, exact wiring,
   failure modes, concrete code-level plan, open questions surfaced last round). Mark the
   doc with a "ROUND N DEEPENING" section; don't just re-summarize.
2. **BROADEN** — also advance a NOT-yet-researched topic from the expanded backlog below.
Rotate: alternate a DEEPEN pass and a new-topic pass so the research both widens and
sharpens. Never re-do a slice at the same depth; either go deeper or pick a new topic.

## Research-slice backlog (the loop works these; mark status each pass)
| # | Slice | Status |
|---|---|---|
| S1 | STOP-REINVENTING audit — where Epistemos hand-rolls what Osaurus/Hermes/OpenClaw/Goose already do better → switch to their proven logic | ✅ done → STOP_REINVENTING_AUDIT |
| S2 | Best PROVEN reskin approach (pixel-art revamp) across native + WebKit-hosted surfaces | ✅ done → RESKIN_PLAYBOOK |
| S3 | SETTINGS revamp per cloned thing (OpenClaw, Osaurus, Goose) → deep Epistemos revamp; one coherent settings model | ✅ done → SETTINGS_REVAMP_CLONES |
| S4 | CHAT ↔ skills/tools end-to-end integration audit + BROKEN-things debug + PRUNE unnecessary | ✅ done → CHAT_TOOLS_INTEGRATION_AUDIT |
| S5 | COMPETITOR SUPERSESSION — Obsidian, Claude-desktop, Codex/terminal-integrated, Tolaria, Notion CLI → feature gaps to beat them | ✅ done → COMPETITOR_SUPERSESSION |
| S6 | WHOLE-APP forward audit — current parts researched for "what's to come" | ✅ done → WHOLE_APP_FORWARD_AUDIT |
| S7 | PLAN/LEDGER/DIRECTIVE consistency sweep — contradictions, gaps, dead items | ✅ done → PLAN_CONSISTENCY_SWEEP |
| S8 | OpenClaw + Osaurus + Hermes deeper passes (continuing) — nuance, edge cases | ☐ |
| S9 | MODEL SYSTEM deep — download/install robustness, selection-honored, the "stack", per-model vaults hardening, picker simplify, catalog completeness (LFM2/VibeThinker/Gemma) | ☐ |
| S10 | COMPUTER-USE + BROWSER-USE — trycua/cua fusion, Holo-3.1 VL lane, AXorcist/ScreenCaptureKit, stealth/Obscura browser, first-class browser-use skill, Lume VM sandbox | ✅ done → COMPUTER_BROWSER_USE |
| S11 | VOICE — R-VOICE (Kokoro TTS / MOSS / Whisper STT), meeting/lecture note, EVE/OKF, on-device only | ☐ |
| S12 | TOOL-SELECTION & ROUTING — LFM2-ColBERT-350M as tool selector, ConfidenceRouter/RuntimeRouter/TriageService, RAG-preflight (P8.2), Hermes-3 grammar | ✅ done → TOOL_SELECTION_COLBERT |
| S13 | DATA + FINETUNE substrate — marketplace for data/finetune packs, MLX training, NightBrain, per-model vaults, FineTunePackImporter | ☐ |
| S14 | UI PORTS — AI-Elements (R-ELEMENTS), Streamdown, json-render (R-JSONRENDER), HTML canvas (P7.2), terminal (P7.3); WebKit-host vs native per port | ☐ |
| S15 | DEEP RESEARCH engine — DeerFlow 2.0, multi-agent orchestration, LiveSubAgentResearcher | ☐ |
| S16 | NEW GAPS from S5 — web clipper, multi-device sync, live Artifacts/dashboards, expose-vault-over-MCP + AGENTS.md (anti-Tolaria), MCP install/connectors UI | ✅ done → SUPERSESSION_GAPS_PLANS (+ 4 ledger items added) |
| S17 | ENGINE-ISOLATION verification — engines connect only via memory+capability, never shared logic; MiniChat=MainChat ontology; session-as-native-tab | ☐ |
| S18 | APPLE INTELLIGENCE retention + foundation models for foundational features; capability ceiling (P7.1); honest gating doctrine | ☐ |
| S19 | PROVENANCE/HONESTY moat — Eidos closed-citation, cognitive DAG, ReplayBundle, AnswerPacket, RunEventLog — surface everywhere | ☐ |

## FINDINGS LOG (appended each research pass — newest at bottom)

**Pass 1 (2026-06-19):**
- **S2 RESKIN** → the reskin is a CONSOLIDATION, not a new system: `EpistemosTheme.resolved` is the one token source; `EpdocEditorThemeStyle.applyScript` is the proven WebKit CSS-injection precedent. Missing pieces: a `PixelSkinTokens` group (border/corner=0/shadow/image-rendering/pixel-font), hoisting `pixelPanel` out of Landing + making it theme-UNCONDITIONAL, generalizing the injector to `EpistemosWebTheme.applyScript(for:namespace:)`, a static `pixel-theme.css` per web surface. No `image-rendering:pixelated` exists yet; avoid the self-stamping DEMO fonts. Full: RESKIN_PLAYBOOK.
- **S5 COMPETITORS** → Epistemos LEADS on architecture (in-process MLX/no-sidecar, provenance/Eidos, native computer-use substrate, in-process PDF→md) but is BEHIND on shipped-working execution (the agent tool-loop is REOPENED-broken = the #1 blocker) and has true GAPS: web-clipper, voice, sync, working canvas, MCP-install UX. Anti-Tolaria move: expose the vault over MCP + an AGENTS.md convention while keeping the in-process brain as default. Moat = local-agent-over-YOUR-vault + honest provenance + three-engine fusion. Full: COMPETITOR_SUPERSESSION.
- **S3 SETTINGS-REVAMP** → clones get NO new settings panels: absorb each one's real knobs into existing native surfaces (model→one stack, permissions→AuthoritySettingsView, recipes/plugins→SkillsSettingsView), HIDE/HARDCODE the rest, status via the proven GateStatus+HealthRow triad in SubstrateHealthPanel. Highest-leverage move = CONSOLIDATE the scattered MCP-install into ONE surface. OpenClaw's auto-generated config-form (~20 Zod sections) must be HIDDEN (CSS + don't wire config.* bridge), never embedded. Full: SETTINGS_REVAMP_CLONES.
- **S4 CHAT↔TOOLS (major)** → the REAL reason tools/skills look broken is NOT the marshaling bug (real but repaired): **chats never ENTER the tool loop** for the owner's common selections — local Gemma is gated out (`canActAsAgent=false`, no backup Qwen), and non-OpenAI/Anthropic cloud never gets tools attached for plain chat (`supportsAgentTier` only OpenAI/Anthropic). All auto-route fixes are flag-OFF. UI boxes wire is intact — gone only because no tool calls fire. Skills: 3 disjoint stores never reconcile; 7 authored SKILL.md in `.agents/skills/` (a path no loader reads). Real fixes: (1) attach tools for plain chat on ALL cloud providers; (2) Swift live-wire the GGUF-Gemma tool path + allow canActAsAgent; (3) reconcile skills stores/paths. Full: CHAT_TOOLS_INTEGRATION_AUDIT. (Fed into the TOOLS/SKILLS ledger item.)
- **S1 STOP-REINVENTING (keystone)** → the owner's 4 broken areas share ONE cause: **built-then-not-wired**, not missing. Roots: (a) `RuntimeRouter.swift:580` is DEAD (zero callers) = the Qwen-pin root → WIRE it (collapse the 4-router sprawl to R1+R2, delete dead R4); (b) `LocalModelInfrastructure.purgeStaleStagingDirectories` 30-min purge DEFEATS download-resume on big models = the "corrupted/incomplete" root → condition on active-download + add retry; (c) T1 the Swift constrained decoder is a FAKE stub (no masking) → bridge the working Rust `llguidance` grammar into MLX (the one real "adopt proven engine" win); (d) skills: progressive-disclosure compiled-OUT of MAS (pro-build only) + 4 disjoint storage dirs (path mismatch) + dead self_evolution/skill_discovery (procedural_memory never written) → un-gate honestly + unify dir + wire one auto-skill. Download transport itself (HF HubClient) is fine. Mostly WIRE/DELETE, not import. Full: STOP_REINVENTING_AUDIT. **Fed to the Qwen-selection + model-download + TOOLS/SKILLS ledger items.**

### Pass-2 (rotation: deepen + broaden)
- **DEEPEN Hermes/Osaurus/OpenClaw (R2)** → `docs/research/HERMES_OSAURUS_OPENCLAW_WIRING_R2_2026_06_19.md` (code-level). NEW: **lift #1 session-search is ~70% built** (`SessionSearchHandler` exists) but does a plaintext scan of `<vault>/sessions/` while the shadow index crawls `<vault>/chats/` → **may return zero hits today (OQ-1, verify vault layout first)**. Ship #2 compaction as DETERMINISTIC (a model-summarize call mid-turn would deadlock the single MainActor client). Tiering: folded-skills must be CONTEXT not stable (cache busts). OpenClaw bridge contract fully maps to existing `AgentStreamEventDelegate` (NO new FFI). Osaurus = parallel `osaurusLoop` swapping ONLY the generator closure; `.osaurusLocal` decision stays in the Act picker (RuntimeLane has no `.osaurus` case). 6 open questions logged. Full doc.
- **S10 COMPUTER/BROWSER-USE** → `COMPUTER_BROWSER_USE_2026_06_19.md`. Browser-use is a real hardened Pro tool family (11 tools, browser.rs) but STARVED (chats don't enter the loop, S4) — highest-value win = surface it via the shared registry. Computer-use = mature native host-intercept stack (DeviceAgentService/AXorcist/ScreenCaptureKit), honestly MAS-stubbed; Holo vision lane doesn't exist yet. Act = primary home (Act⊇Chat), Work = Lume-VM sandbox tier. cua: LIFT Lume natively (Swift MIT, the macOS-desktop-guest VM) + Apple Containerization = Linux tier (two tiers, one Sandbox seam, no overlap); adopt cua's action-schema + composed grounding. Holo-3.1 = local grounding via a new GgufVisionCliProvider+mmproj (Pro). Stealth via stealth-browser-mcp (MCP path). **LEDGER CORRECTIONS: Holo base = Qwen3.5 not Qwen3-VL-4B; browser-use = MIT + Rust-cored; stealth's nodriver engine = AGPL (Pro-internal OK, swap to Patchright/playwright-stealth if shipping as a service).** Full doc.
- **S7 PLAN-CONSISTENCY (de-risk)** → `PLAN_CONSISTENCY_SWEEP_2026_06_19.md`. The big reversals are cleanly marked, BUT: false `[x]` ticks to undo (1024 no-hidden-Qwen contradicted by open ❌; 1026 progress; 1027 effort; R-LITEPARSE 643→[~]); live picker contradiction C3 (1170 says move effort OUT, 402/458 still say carry-everything); 6 gaps incl. **G-1 make WIRE-RuntimeRouter its own top line** (Qwen root, only a sub-note now) + **G-4 staging-purge still UNCONDITIONAL = partial-fix masquerading as fix**; 5 risks: **R-1 P3.0 "import Osaurus frontend+entitlements verbatim" would BREAK the MAS sandbox** (point it at OSAURUS_ACT_CONNECTION_MAP); **R-3 all tool-loop fixes are flag-OFF = NOT visible = NOT done** (add a FLIP+VERIFY gating slice, block the TOOLS/SKILLS tick); R-4 prune-vs-deletion-guardrail (ConfidenceRouter in-flight, keep); R-5 isolation-vs-shared-Goose-core. 8-item fix-the-plan list. **The build loop should action these on its own ledger.** Full doc.
- **S2 RESKIN R2 (deepen)** → appended to RESKIN_PLAYBOOK. Correction: pixel components already used in 8 sites/5 areas (not Landing-scoped); the gap is the theme-conditional 3-way branch (`PixelPanelModifier:208`) — collapse it. Exact `PixelSkinTokens` struct on `ResolvedTheme` (default `.standard` so the ~30-param init isn't forced); `EpistemosWebTheme.applyScript(for:namespace:)` keeps Epdoc byte-identical; WebKitCodeEditor gets additive setState (don't switch it). Failure modes: cache-bust if skin is a global toggle (keep theme-derived; diff on (theme,skin)); **JetBrainsMono has no @font-face/served option → mono falls back**; WKWebView teardown leak on a 2nd surface. 6 open questions (chief: theme-derived vs global toggle). Code-level, buildable.
- **S6 WHOLE-APP FORWARD AUDIT** → `WHOLE_APP_FORWARD_AUDIT_2026_06_19.md`. **STRUCTURAL: the 3-engine Chat/Act/Work toggle does NOT exist as a primitive yet** — `CoworkChatMode` is only chat/act, Act=`operatingMode==.agent` (not Osaurus), no `.work`, no ActEngine enum. #1 prep item: model the axis in CoworkChatMode/ChatCoordinator/InferenceState BEFORE Osaurus/Goose lanes surface. Content surfaces (Notes/Epdoc, Graph, Vault, Eidos, provenance, search, computer-use) solid; agent/engine surfaces (Act/Work/OpenClaw/canvas) stubbed/missing. Voice already real (Apple TTS/STT) — R-VOICE is additive. Orphans to prune-in-pairs (SkillEvolutionView↔dead self-evolution, ResearchRequestView, ArtifactHostView, etc.). Top risk: ChatCoordinator+InferenceState are the convergence point of 3 workstreams — sequence them. Full doc.
- **S12 COLBERT TOOL-SELECTOR** → `TOOL_SELECTION_COLBERT_2026_06_19.md`. Today's selector is a LEXICAL preflight (`tool_preflight.rs:79`, flag-OFF) — wired into Swift, right shape, weak scorer (no semantics). LFM2-ColBERT-350M = a late-interaction RETRIEVER (not generator); cleanest drop-in = swap ONLY the `score` fn behind a `ToolScorer{lexical|colbert}` trait (the doctrine comment reserves this exact seam). Runs as an in-process GGUF embedding FFI (NO sidecar; Pro-gated). **STRICTLY downstream of the loop-entry fixes — improves nothing until chats enter the loop.** No Osaurus/Hermes overlap (genuinely new retrieval layer). Same retriever can also upgrade vault RAG (one install, two consumers). License = "LFM Open License v1.0" (not MIT/Apache → ProvenanceGate). Catalog has LFM2.5 generators but NOT the ColBERT retriever (gap). Full doc.
