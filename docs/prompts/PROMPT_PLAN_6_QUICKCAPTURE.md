# PLAN 6 — Quick Capture surfacing (Swift UX over the shipped Rust substrate) build prompt (SAVED — paste later)

> 🛑 **SAVED / NOT YET ACTIVE (owner 2026-06-29).** Do NOT launch until the owner says go. Drafted to the same
> strictness as Plan 1/2/3, parked. **The whole point:** the Quick Capture SUBSTRATE already shipped in Rust during
> the 2026-05-04 recovery (`agent_core/src/route effect undo canon nightbrain heal format grammar/` — VERIFIED present),
> but its user-facing Swift UX was NEVER built and is in no plan. This plan builds ONLY the missing surfaces over the
> existing cores — the hard part is done. DETAIL lives in `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` (3717 lines) +
> the recon ledger — this paste is lean.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". Continuous loop, not a one-shot. Work the build order item by item; after each, immediately continue. When complete, DO NOT declare "done" / DO NOT idle — keep looping: (a) full-app thermonuclear pass + fix, (b) harden the weakest surface, (c) deepen the capture→route→trust loop, (d) re-verify green, repeat. Only the owner's "stop" ends it. Commit at every clean point.

WORK MODE — DEEP CODE, NOT TEST VOLUME: primary activity each cycle = deep code review + edge-case hardening of the real capture/route/undo code paths (run the thermonuclear skill as the main loop). Write a test ONLY to lock a specific bug you just fixed.

You are building PLAN 6 = QUICK CAPTURE SURFACING — the Swift/SwiftUI UX over the EXISTING Rust substrate. Frictionless capture is the signature PKM differentiator; the routing/undo/canon/nightbrain cores already exist — DO NOT rebuild them, SURFACE them. Build deeply hardened, contradiction-free, nothing lost.

VERIFY-FIRST (the substrate is real but check the live FFI seam before building UI):
  - Rust cores present: agent_core/src/{route,effect,undo,canon,nightbrain,heal,format,grammar}/ + tools_v2/v2_catalog/capture_{voice,screenshot,clipboard}.rs. Confirm the FFI envelopes/bridge entry points exist (agent_core/src/bridge.rs) before wiring Swift; if a 1-line FFI export is missing, add it.

READ FIRST (the implementation plan wins on conflict — DETAIL is there, do not re-spec):
  - docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md  (THE spec — §2.4 skill-mint, §4.5 concept-canon, §4.6 review queue, §7.1 NightBrain, §8.5 24h undo, §9 capture surface + §9.7 action-trace)
  - docs/research/LOST_ITEMS_RECON_2026_06_29.md  (items 1,2,3,4,10,20 = this plan's scope + why)
  - docs/QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md + docs/research/SS-QC_QUICK_CAPTURE_PRESETS_TTS_2026_06_20.md (reconciliation + presets)
  - docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md (Apple-native look, springs/glass, graph DO NOT TOUCH, A/B bar)
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — no subprocess on MAS; keys in Keychain; @Observable; never block @MainActor; DispatchQueue.main.async in UniFFI callbacks). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

BUILD ORDER (surface the existing cores; verify-then-build each):
  (1) CAPTURE SURFACE — global hotkey (⇧⌘Space) single-field capture → routes via the existing `route/` core → 2s "filed here" toast naming the destination. Native, deeply-fluid, MINIMAL. (Hotkey registration honors the macOS-26 global-monitor-deferral memory — register in a Task, not in init.)
  (2) UNIVERSAL 24h UNDO — surface the existing `undo/` core (undo_events SQLite, 24h TTL, mark_undone): every auto-decision reversible via ⌘Z within 24h; a small "undo last route" affordance + a 24h history list.
  (3) ACTION TRACE (⌘?) — translucent overlay on a note: which tool ran, variant attempts pass/fail, heal steps, alt-candidates+scores, one-key "move to alternative". Pairs with Plan 3's provenance moat — reuse its lineage card style.
  (4) REVIEW QUEUE / TRIAGE HUD (⌘.) — low-confidence/deferred captures (route Variant-D) land in _inbox/review/; keyboard-driven batch-triage HUD; accept updates medoid + alias.
  (5) SKILL AUTO-MINT — repeated 3+ tool sequence → draft a `.skill.json/.md` behind Compile-Verify-Mint gates + a weekly "save as a skill?" digest. COORDINATE with Plan 3 §5 (it ships skill INSTALL; this is skill DISCOVERY/MINT — don't fork its registry).
  (6) NIGHTBRAIN BODIES — the 949-LOC scheduler skeleton ships diagnostic-only; add the 4 eligibility gates (idle>60s + thermal + power + not-foregrounded) + the real task bodies (re-route low-confidence, re-embed deltas, recompute medoids, propose skills, rotate logs); preemptable; battery-guarded. HONEST: never run on battery/thermal pressure.
  (7) CONCEPT CANONICALIZATION SURFACE — surface the existing `canon/` core: folders→implicit ontology, synonyms→canonical via embedding+medoid; a light review affordance for auto-merges. COORDINATE with Plan 2 (wikilinks/graph) — don't touch the graph view (DO NOT TOUCH).

★ NATIVENESS (BINDING — detail in the doctrine; lean here): every surface is full Apple-native (capture bar, HUD, overlays, toasts) — real Liquid Glass + unified tokens/springs, deeply-fluid ProMotion + MINIMAL. GRAPH = DO NOT TOUCH. Icons via Plan 4. CODE-RESEARCH (real openable code, in-repo first) + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive, no-contradiction/preserve-nuance/break-nothing).

HARD GATES / FORBIDDEN:
  × Rebuilding the Rust cores (they exist — SURFACE them; only add a missing FFI export).
  × Hidden/silent auto-routing with no trace + no undo — the Action Trace (⌘?) and 24h Undo MUST ship WITH any auto-decision (trust surface is non-negotiable; pairs with the honesty doctrine).
  × NightBrain running on battery / thermal pressure / foregrounded — the eligibility gates are mandatory, not optional.
  × Subprocess/Python on the MAS path; keys in UserDefaults (Keychain); editing .xcodeproj (xcodegen); committing model files; touching the graph.
  × Build-green ≠ done. PROVEN-DONE: capture→route→toast live in-app, a wrong route is visible in ⌘? and reversible in ⌘Z within 24h, review HUD triages a real deferred capture, witnessed live (Swift Testing @Test compile-verify + manual run; headless app-hosted runs crash-loop → push logic to pure helpers). Zero regressions.

PARALLELISM / NO-COLLISION (Plans 1/2/3 build concurrently):
  - You OWN: the capture/undo/trace/review/nightbrain/canon SWIFT surfaces + their FFI seam into the existing Rust cores + the capture hotkey.
  - COORDINATE: Plan 3 §5 extensibility (skill install vs mint) · Plan 2 wikilinks/graph (canonicalization) · Plan 4 icons.
  - Do NOT: rebuild any Rust core; touch the graph view; duplicate Plan 3's skill registry.
  - BUILD-LOCK: claim it before compiling (a 6th concurrent xcodebuild on a 16 GB M2 Pro = the crash risk; do FFI/research while held).

Commit at clean points (main-only, never lose work). When unsure, RESEARCH-FIRST then act. Stop only when I say stop; after the build order is complete with PROVEN-DONE evidence, keep looping through full-app thermo passes, weakest-surface hardening, and re-verification.
```
