# PLAN 5 — Companions build prompt (SAVED — paste later)

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: this plan is
> parked as a Kindred/companion runtime plan. Read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. Do not build
> Kindred, 1Code companion runtime, per-editor 1Code minichat, Node-backed
> presence, or Developer-ID companion authority. Salvage only MAS-safe patterns:
> real June run-state display, native status/mascot accents, identity/history
> profile, note-edit provenance, and press-to-see-changes, all backed by
> MAS/June + `agent_core`.

> 🔴 **OWNER OVERRIDE — 2026-07-06 (READ FIRST; SUPERSEDES ALL CONTRADICTORY TEXT BELOW).**
> OpenChamber/ProAgent are deletion targets, not current surfaces. The 2026-07-06 two-surface
> wording is superseded by the 2026-07-07 MAS-only lock: the active surface is **MAS/June**.
> So every "reskinned Goose WebView panel / Option-1 /
> OpenChamber / native = frame + Models only / add NO native controls" line below is **STALE** —
> reconcile, don't obey it literally. Companions in the CURRENT canon:
> 1. **MAS-safe status mascot = a STATIC + EMOTIVE status layer** (poses + reactive emotes: thinking/reading/editing/done/blocked — NOT animated wandering the UI) that is a **skin over REAL June/agent_core state** (never fake animation). Each visible identity has an **IDENTITY + OBLIGATION PROFILE**: id, job, current activity, and a history of what it has done. Selecting a status accent opens that profile.
> 2. **Seen in 3 places** — (a) Experimental/1Code chat and MAS/June where applicable, (b) the native editors (Prose/Epdoc/Source), (c) the LANDING page (the roster where the owner watches agents chilling/working) — **PLUS** pinned on ANY button/surface where that agent is actively working (e.g. the mascot on the arXiv button while it reads arXiv; landing shows "currently reading arXiv"). arXiv + Obscura stay DEDICATED features (not demoted).
> 3. **Two genuinely-new builds** (the rest is presentation over existing state): **(i) note-edit PROVENANCE** — track the agent's edits to a note as an attributed changeset so "press the mascot → see all changes it made" works (extends the session-notes author/lastEditedBy design); **(ii) ONE data source, TWO presentation layers** — the mascot renders as a WEB overlay inside the current web agent surfaces (Experimental/1Code, MAS/June where applicable) and as a NATIVE SwiftUI bubble on Prose/Epdoc/Source; same underlying data (agent state + note changeset).
> 4. **Native mascot chrome is now WANTED** — the old "add NO native SwiftUI controls" rule is superseded for the mascot bubbles + the native pill nav. (Chat content still lives in the current web agent surfaces; the mascots are thin native overlays, not a native transcript.)
> 5. **SURFACE A ("Note Companion" mini-Goose-chat embedded in Epdoc) is DEFERRED** — the owner cut the per-editor minichat (a second agent entry point re-fragments the app). The agent works on notes via SHARED VAULT FILES (edits reflect live in the open editor, Cursor-style) + the pinned mascot + press-to-see-changes, NOT an embedded chat panel. Revisit an inline-assist only later, consistently across ALL editors, or never.
> 6. **CREATION DEFAULT (owner-flow re-anchored):** landing remains a calm roster/query surface with a thin `+` deep-link into the 1Code creator unless the owner explicitly reverses it. Do not wait for an owner call.
> The EXISTING landing Farm code (`CompanionModel`/`CompanionView`/`Farm/`, `companions.rs` CompanionRegistry) is historical grounding only while MAS-only is active. Only the "mini-Goose-chat panel / reskinned Goose WebView / Option-1 / OpenChamber" framing is replaced by MAS-June state + native status/provenance accents above.

> 🎨 **OWNER DESIGN DIRECTIVE — 2026-06-30 (CURRENT CANON, identical in EVERY plan):** the look = **HIGH-QUALITY FLAT · MINIMAL · THEME-AWARE · OPTIMIZED.** KEEP the Apple-native **FRAME** — rounded-corner window, vibrancy, traffic-lights, the calibrated springs (the curved-white native window the owner likes STAYS). **SURFACES (panels · buttons · lists · inputs) are FLAT + BORDERLESS:** NO thick outlines, NO hard box borders, NO 1px rules — differentiate by a subtle background tint + spacing + a very soft shadow only. NOT the old thick-outline pixel-art look, and NOT translucent-glass on every surface. **TOTAL THEME-AWARENESS:** every surface (native + editor-web + Goose-web) reads the Epistemos tokens for ALL palettes incl. the user CUSTOM palette; no hardcoded color; two-token-sources in lock-step. Full doctrine: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

> 🛑 **SAVED / NOT YET ACTIVE (owner 2026-06-29).** Do NOT launch until the owner says go. Drafted to the same
> strictness as Plan 1/2/3 and parked. ONE Companion concept, TWO surfaces:
> **(A) Note Companion** — the note-scoped mini-Goose-chat panel embedded in the Epdoc editor (the "Tolaria mini-chat").
> Plan 2 builds the note-context PLUMBING but explicitly NOT the panel UI (EDITOR_CANONICAL_PLAN:310); Plan 1 owns the
> main Goose surface but not an embedded note panel — so today this falls between them and would NOT ship.
> **(B) Landing Companions** — the EXISTING landing "Farm" mascots (`CompanionModel`/`CompanionView`/`Farm/`) are today
> COSMETIC ONLY ("does NOT own model/prompt/tool/MCP/approval/runtime authority" — Simulation Mode v1.6 doctrine). Owner
> 2026-06-29 wants them FUNCTIONAL: create/manage from the landing page + select → directly chat in a minimal mini-Goose
> panel (companion mascot = the agent icon on top, compact chat below). ⚠️ This is a DELIBERATE doctrine evolution
> (companions GAIN gated chat authority) — flag it, gate it honestly, do not silently cross it.
> Plan 5 owns both panels + the wiring. Detail lives in the existing codepack + Companion code (below) — this paste is lean.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

WORK MODE — DEEP CODE, NOT TEST VOLUME: primary activity each cycle = deep code review + edge-case hardening of the real companion code paths. Write a test ONLY to lock a specific bug you just fixed — no coverage-padding suites. Commit at every clean point (main-only, never lose work). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

You are building PLAN 5 = COMPANIONS. A companion is a STATIC + EMOTIVE mascot that is a SKIN OVER REAL AGENT STATE (never fake animation) and the connective tissue that makes the app feel like ONE living thing. Full spec = the OWNER OVERRIDE header at the top of this file + memory `project_product_shape_agent_center_2026_07_02`. In brief:
  - IDENTITY + OBLIGATION PROFILE per companion: id, job, current activity, history of what it has done. Selecting a companion (on any surface) opens that profile.
  - SEEN IN 3 PLACES: (a) the current agent surfaces (Experimental/1Code and MAS/June where applicable), (b) the native editors (Prose/Epdoc/Source), (c) the LANDING page (the roster where you watch agents chilling/working). PLUS pinned on ANY button/surface an agent is actively working (e.g. the mascot on the arXiv button while it reads; landing shows "currently reading arXiv").
  - Emotes reflect REAL run state (thinking/reading/editing/done/blocked) streamed from the agent — one agent per task → one mascot.

READ FIRST:
  - The OWNER OVERRIDE header at the top of THIS file (current canon; supersedes any stale detail).
  - EXISTING Companion code — GROUND here, do NOT reinvent: Epistemos/Models/Companion/CompanionModel.swift (SwiftData @Model; name/tagline/bodyKind/accent/identityHash + create/archive/trash lifecycle; carries the "cosmetic-only, NO model/prompt/tool/MCP/runtime authority" v1.6 doctrine you are deliberately extending), Epistemos/Views/Landing/Farm/CompanionView.swift + Epistemos/Views/Landing/Farm/* (mascot render, roster, onActivate), Epistemos/State/Companion/CompanionState.swift, agent_core/src/cognitive_dag/companions.rs (CompanionRegistry: base-model + LoRA lineage). READ the v1.6 doctrine before changing CompanionModel authority.
  - docs/prompts/PROMPT_PLAN_4_ICONS.md (the mascot emote/model/tool marks come from Plan 4's mono set).
  - Project rules: CLAUDE.md (STREAM EVERYTHING; PRESERVE THINKING BLOCKS; no subprocess on MAS; keys in Keychain; @Observable; never block @MainActor; DispatchQueue.main.async in UniFFI callbacks).
  - ⚠️ The precise hooks into the Agent surface's live run-state come from the current MAS/June and Experimental/1Code plans — coordinate; do not hardcode a stale goose-web or OpenChamber assumption.

BUILD ORDER (verify-first; check live code before building):
  (1) IDENTITY + PROFILE — extend CompanionModel with the obligation profile (id/job/current-activity/history) + read/update accessors. Ground in the existing lifecycle; do not fork it.
  (2) MASCOT PRESENTATION — ONE data source (agent run-state + the note changeset from step 4), TWO thin presentation layers: a WEB overlay inside the current agent surface and a NATIVE SwiftUI bubble on Prose/Epdoc/Source. Static pose + reactive emotes. NO animated wandering.
  (3) PIN-ON-WORKING-SURFACE — when an agent is working a feature (arXiv/browser/etc.), show its mascot on that feature's button/surface + reflect it on the landing roster ("currently reading arXiv"). Driven by real activity state.
  (4) NOTE-EDIT PROVENANCE — track an agent's edits to a note as an attributed changeset so "press the mascot → see all changes it made" works. Extends the session-notes author/lastEditedBy design (see product-shape memory).
  (5) LANDING ROSTER — create/manage/select companions from the landing page (small create affordance + per-companion edit popover, NOT a settings panel); clicking a mascot opens its profile.
  (6) GATED-CHAT DOCTRINE EVOLUTION (honest) — a companion MAY hold an OPTIONAL persona-scoped agent session (persona preamble + vault MCP), re-scoped per companion. Explicitly extend the CompanionModel v1.6 doctrine in code comments: a companion may now hold a GATED chat binding; it does NOT silently gain tool/approval/autonomous-runtime authority beyond what the user approves per-turn. MAS honest gate: show "chat" only when a runtime is available.
  (7) ICONS — mascot emote badges + model/tool marks use Plan 4's themified mono set (until active, the existing ProviderLogoView/IntegrationBrandMarkView).

DEFERRED (owner 2026-07-02): the embedded Epdoc "Note Companion" mini-chat panel + its editor dock slot are CUT (a per-editor chat re-fragments the app). The agent works on notes via SHARED VAULT FILES + the pinned mascot + press-mascot→see-changes — NOT an embedded chat panel. Revisit inline-assist later, consistently across all editors, or never.

HARD GATES / FORBIDDEN:
  × FAKE animation — the mascot is a skin over REAL agent state; never animate emotes the agent isn't actually in.
  × Silently granting companions tool/MCP/approval/autonomous-runtime authority — gated CHAT binding ONLY; anything beyond stays user-approved per-turn. State the doctrine change in code + the model.
  × Animated mascots wandering the whole UI (deliberately out of scope — static + emotive only).
  × Buffering streamed tokens or stripping thinking blocks (STREAM EVERYTHING; PRESERVE THINKING BLOCKS).
  × Subprocess/Python on the MAS path; keys in UserDefaults (Keychain); editing .xcodeproj (xcodegen); committing model files.
  × Touching the graph (DO NOT TOUCH).
  × Build-green ≠ done. PROVEN-DONE: mascot live in-app reflecting a REAL agent turn's state on all 3 surfaces, profile opens on click, note provenance shows real changes, witnessed live. Zero regressions.

PARALLELISM: You OWN Epistemos/Models/Companion/* + Epistemos/State/Companion/* + Epistemos/Views/Landing/Farm/* + the mascot presentation layers. COORDINATE the Agent-surface run-state hooks with the current MAS/June and Experimental/1Code plans, the native-editor mascot bubble with Plan 2, the landing shell with Plan 3, the icons with Plan 4. Do NOT duplicate the agent surface or build a second chat UI.
```
