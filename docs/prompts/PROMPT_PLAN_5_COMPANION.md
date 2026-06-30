# PLAN 5 — Companions (mini-Goose-chat: note companion + landing-Farm companions) build prompt (SAVED — paste later)

> 🎨 **OWNER DESIGN DIRECTIVE — 2026-06-30 (in EVERY plan):** **FLAT PIXEL-ART · MINIMAL · still NATIVE · TOTAL THEME-AWARENESS.** Every surface you build or touch (companion panels, Farm, the reskinned mini-Goose WebView, mascots) must use **flat, theme-tinted pixel-art surfaces** (crisp edges, no frosted-glass blur; extend `Epistemos/Views/Landing/PixelSurfaceComponents.swift`) and be **fully theme-aware of the Epistemos tokens for ALL palettes incl. the user CUSTOM palette** — NOTHING off-theme, native surfaces included; no hardcoded color (tokens only; two-token-sources). Authority: the 🎨 OWNER DESIGN AMENDMENT atop `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

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

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". Continuous loop, not a one-shot. Work the build order item by item; after each, immediately continue. When complete, DO NOT declare "done" / DO NOT idle — keep looping: (a) full-app thermonuclear pass + fix, (b) harden the weakest companion/plumbing path, (c) deepen the note-aware affordances, (d) re-verify green, repeat. Only the owner's "stop" ends it. Commit at every clean point.

WORK MODE — DEEP CODE, NOT TEST VOLUME: primary activity each cycle = deep code review + edge-case hardening of the real companion/plumbing code paths (run the thermonuclear skill as the main loop). Write a test ONLY to lock a specific bug you just fixed — no coverage-padding suites.

You are building PLAN 5 = COMPANIONS — a compact mini-Goose-chat panel for TWO surfaces: (A) NOTE COMPANION scoped to the open note + EMBEDDED in the Epdoc editor (the "Tolaria mini-chat"); (B) LANDING COMPANIONS — wiring the EXISTING cosmetic Farm mascots into selectable, chattable agent personas (create/manage/select-and-chat from the landing page; the companion mascot = the agent icon on TOP, a compact chat BELOW it; minimal controls). Both are reskinned Goose WEBVIEW panels scoped by context — NOT native chat UIs (Option 1). Same panel core, two context bindings (note vs companion). Build deeply hardened, contradiction-free, nothing lost.

READ FIRST (the codepack + plan win on conflict — DETAIL is there; do not re-spec it):
  - docs/research/GOOSE_MINICHAT_CODEPACK_2026_06_27.md  (THE detail — §3 ActiveEpdocTracker/NoteContextProvider, §4 the exact Goose/MCP gaps, §5 historical VM sketch = plumbing semantics ONLY, §6 build-vs-exists ledger)
  - docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md §6 (Goose note-context plumbing — superseded-in-scope 2026-06-29) + the MiniChatTarget note (line ~434)
  - docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md (Option 1: chat stays Goose WebView; native = frame + Models only — NO native chat)
  - docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md (transparent-over-glass, tokens/springs, graph DO NOT TOUCH, A/B bar)
  - docs/prompts/PROMPT_PLAN_4_ICONS.md (the companion's model/provider/tool icons come from Plan 4's mono set)
  - EXISTING Companion code — GROUND the landing surface here, do NOT reinvent: Epistemos/Models/Companion/CompanionModel.swift (SwiftData @Model; name/tagline/bodyKind/accent/identityHash + create/archive/trash lifecycle; carries the "cosmetic-only, NO model/prompt/tool/MCP/runtime authority" v1.6 doctrine you are deliberately extending), Epistemos/Views/Landing/Farm/CompanionView.swift + Epistemos/Views/Landing/Farm/* (mascot render, roster, onActivate), Epistemos/State/Companion/CompanionState.swift, agent_core/src/cognitive_dag/companions.rs (CompanionRegistry: base-model + LoRA lineage). READ the v1.6 doctrine before changing CompanionModel authority.
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — STREAM EVERYTHING / forward every token; PRESERVE THINKING BLOCKS; no subprocess on MAS; keys in Keychain; @Observable; never block @MainActor; DispatchQueue.main.async in UniFFI callbacks). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

OPTION 1 COMPLIANCE (LOCKED — do not relitigate): the companion is the Plan-1-owned Goose WebView/reskin, SCOPED to the open note and mounted compactly in the editor. Do NOT build a separate native transcript/composer. The historical native MiniChatViewModel sketch (codepack §5) is mined for SESSION/CONTEXT SEMANTICS ONLY (scoping, cancel, context refresh) — never shipped as a native chat surface.

BUILD ORDER (verify-first; much is specced-but-unbuilt per the codepack §6 — check live code before building):
  (1) PLUMBING (build-now, zero-Goose-dep; codepack §3) — ActiveEpdocTracker (frontmost EpdocDocument via NSWindow key) + NoteContextProvider (bounded head/tail body via the EXISTING ProseMirrorMarkdownProjector) → WorkNativeMCPHost.updateContext on note change. (VERIFY: these are NOT in code today — build + test them.)
  (2) THE PANEL — mount a COMPACT, note-scoped reskinned Goose WebView in a dock slot in the Epdoc editor chrome (Plan-2 host slot; coordinate). Dock/undock + "open in full Goose" escape hatch (GooseSurfaceWindowController). Transparent-over-glass + unified tokens/springs (reskin, do not restyle Goose's logic).
  (3) SESSION SCOPING (codepack §2/§4) — ONE shared Goose session, cwd=vault root constant, re-scoped per note via _meta {epistemos.note} + a re-seed preamble + the live epistemos.context.snapshot MCP pull. Tear down on panel close / vault switch; keep alive across note switches.
  (4) GOOSE-BOUNDARY GAPS (codepack §4, coordinate with Plan 1) — newSession passes mcpServers (1-line; today dropped); add session/cancel (no cancel today); add Epdoc UI-steering affordances open_note/highlightEditor/replaceSelection on GooseWebNativeAffordanceBridge (EXISTS); AGENTS.md vault guidance.
  (5) EDITOR AFFORDANCES — [[wikilink]] reference resolve (EpdocDocumentLocator), selection-aware "explain this" from caretChanged, inline per-edit approval via the EXISTING GooseACPPermissionPanel.
  (6) ICONS — the companion header model badge + tool-card provider/tool marks use Plan 4's themified mono SVGs (when Plan 4 is active; until then, the existing ProviderLogoView/IntegrationBrandMarkView).
  --- LANDING COMPANIONS (surface B — reuse the SAME panel core from steps 2-5) ---
  (7) WIRE THE FARM — CompanionView.onActivate (today just visual) → open the SAME mini-Goose panel scoped to that companion: mascot/agent-icon on TOP, compact chat BELOW. Reuse the note-companion panel; swap the context binding (companion persona ↔ note). Dock on the landing page; deeply-fluid, MINIMAL.
  (8) CREATE/MANAGE (minimal controls) — companion create already exists (CompanionModel: name/bodyKind/accent/lifecycle); ADD an optional per-companion persona/system-preamble + model choice; rename/archive/restore from the Farm. Keep controls minimal — a small create affordance + a per-companion edit popover, NOT a settings panel.
  (9) COMPANION→AGENT BINDING (DOCTRINE EVOLUTION — GATED, honest) — give a companion an OPTIONAL Goose session scoped to its persona (cwd=vault root, _meta {epistemos.companion}, persona preamble + the same vault MCP). ONE shared session re-scoped per companion (like the note re-scope). Explicitly extend the CompanionModel v1.6 doctrine: a companion MAY now hold a gated CHAT binding — it still does NOT silently gain tool/approval/autonomous-runtime authority beyond what the user approves in-chat. MAS honest gate: show "chat" only when a Goose runtime is available.

★ NATIVENESS (BINDING — detail in the doctrine; lean here): the panel is a WebView made INDISTINGUISHABLE from native — transparent-over-real-glass (non-opaque WKWebView over NSVisualEffectView), unified tokens, deeply-fluid ProMotion + MINIMAL springs, A/B pixel-diff = the bar. GRAPH = DO NOT TOUCH. CODE-RESEARCH (real openable code, in-repo first) + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive, no-contradiction/preserve-nuance/break-nothing).

HARD GATES / FORBIDDEN:
  × A separate NATIVE chat UI (Option 1 violation) — the companion is the reskinned Goose WebView only.
  × Silently granting Farm companions tool/MCP/approval/autonomous-runtime authority — the v1.6 doctrine extension allows a GATED chat binding ONLY; anything beyond chat stays user-approved per-turn. State the doctrine change explicitly in code comments + the companion model.
  × A Goose process/session per note (explodes count + loses continuity) — ONE session, re-scoped via _meta + MCP snapshot.
  × Buffering streamed tokens or stripping thinking blocks (STREAM EVERYTHING; PRESERVE THINKING BLOCKS).
  × Subprocess/Python on the MAS path; keys in UserDefaults (Keychain); editing .xcodeproj (xcodegen); committing model files.
  × Touching the graph (DO NOT TOUCH).
  × Build-green ≠ done. PROVEN-DONE: panel live in-app, scoped to the frontmost note, streams a real Goose turn that can read the note via epistemos.context.snapshot, cancel works, affordances route into Epdoc, witnessed live (Swift Testing @Test compile-verify + manual run; headless app-hosted runs crash-loop → push logic to pure helpers). Zero regressions.

PARALLELISM / NO-COLLISION (sits BETWEEN Plan 1 and Plan 2 — coordinate, do not stomp):
  - You OWN: the embedded companion panel + its compact chrome (both surfaces), the note-context plumbing (ActiveEpdocTracker/NoteContextProvider/_meta builders/snapshot wiring), the editor affordance routes, session scoping/cancel semantics, AND the landing Farm chat wiring (CompanionView.onActivate→panel, the create/manage-persona controls, the CompanionModel authority extension + companion-context binding) — Epistemos/Models/Companion/* + Epistemos/State/Companion/* + Epistemos/Views/Landing/Farm/*.
  - COORDINATE (shared seams): the Epdoc host dock slot (Plan 2 editor chrome) · the Goose WebView/reskin + Epistemos/Goose/* + the newSession/cancel/affordance Goose-side changes (Plan 1) · the landing page shell (Plan 3 owns LandingFeatureButtons — don't stomp them; the Farm is yours) · Plan 4 supplies the icons.
  - Do NOT: restyle Goose's internal chat logic (reskin only); build a second chat UI anywhere; duplicate the main Goose surface.

Commit at clean points (main-only, never lose work). When unsure, RESEARCH-FIRST then act. Stop only when I say stop; after the build order is complete with PROVEN-DONE evidence, keep looping through full-app thermo passes, weakest-path hardening, deeper note-aware affordances, and re-verification.
```
