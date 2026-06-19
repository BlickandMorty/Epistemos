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
| S6 | WHOLE-APP forward audit — current parts researched for "what's to come" | ☐ |
| S7 | PLAN/LEDGER/DIRECTIVE consistency sweep — contradictions, gaps, dead items | ☐ |
| S8 | OpenClaw + Osaurus + Hermes deeper passes (continuing) — nuance, edge cases | ☐ |
| S9 | MODEL SYSTEM deep — download/install robustness, selection-honored, the "stack", per-model vaults hardening, picker simplify, catalog completeness (LFM2/VibeThinker/Gemma) | ☐ |
| S10 | COMPUTER-USE + BROWSER-USE — trycua/cua fusion, Holo-3.1 VL lane, AXorcist/ScreenCaptureKit, stealth/Obscura browser, first-class browser-use skill, Lume VM sandbox | ☐ |
| S11 | VOICE — R-VOICE (Kokoro TTS / MOSS / Whisper STT), meeting/lecture note, EVE/OKF, on-device only | ☐ |
| S12 | TOOL-SELECTION & ROUTING — LFM2-ColBERT-350M as tool selector, ConfidenceRouter/RuntimeRouter/TriageService, RAG-preflight (P8.2), Hermes-3 grammar | ☐ |
| S13 | DATA + FINETUNE substrate — marketplace for data/finetune packs, MLX training, NightBrain, per-model vaults, FineTunePackImporter | ☐ |
| S14 | UI PORTS — AI-Elements (R-ELEMENTS), Streamdown, json-render (R-JSONRENDER), HTML canvas (P7.2), terminal (P7.3); WebKit-host vs native per port | ☐ |
| S15 | DEEP RESEARCH engine — DeerFlow 2.0, multi-agent orchestration, LiveSubAgentResearcher | ☐ |
| S16 | NEW GAPS from S5 — web clipper, multi-device sync, live Artifacts/dashboards, expose-vault-over-MCP + AGENTS.md (anti-Tolaria), MCP install/connectors UI | ☐ |
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
- (in flight: DEEPEN Hermes/Osaurus/OpenClaw code-level wiring; BROADEN S10 computer-use + browser-use)
