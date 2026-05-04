# Recovery loop findings — 2026-05-04

Autonomous canonical recovery loop run by Claude (Opus 4.7) starting from
the user directive: *"i want you to take over weeryrhtin i jsut want yyo
to do all the work literally dont wait for me to test or anything just
build run those tests and do the recovery and therest of the stuff …
keep going i want to finish everything in the proepr orer we spoek
about make sure the helios v3 is still the final ultimate goal …"*

The loop is now closed. This doc summarizes every shippable change, the
audit findings that didn't need a fix, and the wait-for-signal stop
point. Per `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` §5 the loop
does **not** auto-start V2.1 (Cognitive DAG). The user must type
**"RESUME SUBSTRATE V2"** to begin V2.1, or **"RESUME RESEARCH TIER"**
to skip ahead to V3 (Helios v3 + SCOPE-Rex + Ternary substrate).

---

## Shippable changes landed (chronological)

| # | Commit | Stage | What |
|---|---|---|---|
| 1 | `b46e1966` | E.2 | Pixel-art companion renderer per Invariant I-16 — discrete 48-cell grid, stepped circle for Orb, parameterized Block aspects, humanoid Sage; CompanionAnimationState 13-state machine + `gate` pose. |
| 2 | `0a6e582f` | E.2 | Hermes Snake graph faculty pixel-art coil — three stacked rings + bronze-stripe segmentation + Slit eyes + canonical gold palette (#D4AF37 / #A07028 / #FFCC00) per character-DNA/hermes_snake.md. |
| 3 | `2b129368` | E.2 | Canonical 4-companion farm seed (Sage / Orbit / Brick / Scribe) on first launch — one of each Simulation v1.6 §5.1 body family so the Landing Farm reads as a populated tomagotchi farm. |
| 4 | `65da1d32` | B.2 | Apple Intelligence Agent-mode error message clarified — explains the SDK limitation (FoundationModels has no tool-calling protocol) and lists the 6 in-process AFM call sites so users know AFM is real, not stub. |
| 5 | `70a3c74f` | B.3 | Cross-runtime tool tier parity tests — 2 contract tests pin the Swift⇄Rust capability lattice; caught + handled one real conditional-registration case (web_search needs a backend env var). |
| 6 | `191b2042` | E.0 | Fonts: silent system-font fallback fix on every Hermes surface — both Inter .ttf files shipped with PSName `InterVariable`, so `.custom("Inter-Regular"/"Inter-SemiBold", …)` was resolving to system fonts. Fix: use real PSName + `.weight()` axis. Removed duplicate Inter-SemiBold.ttf binary (-880 KB bundle). Added runtime PSName-resolution test that reads each .ttf header directly. |
| 7 | `456784f4` | F | Hid custom-tool registration card from MAS users — they could register tools that the runtime executor would always reject, leaving them with a dead-end UI. |

**Total**: 7 shippable commits, 1 doctrine doc (this file) + 1 triage
doc (`QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md`), green xcodebuild
+ green cargo check throughout.

---

## Audit findings that did NOT need a fix

These were investigated and deliberately left alone with rationale.

### Stage A — Cognitive kernel + GenUI dispatcher
Both already complete in earlier Codex commits. GenUI dispatcher uses
typed switch over `GenUISchema` (no AnyView in hot path per Invariant
I-15). Hermes Expert Mode renderers are all on typed `GenUIPayload`
(status / tokens / cost / config / model / search migrations done).

### Stage B.1 — Hermes-in-Rust scaffold
6 modules at `agent_core/src/hermes/`, 737 LOC, 15 tests pass. Scaffold
is solid; full implementation is multi-week and not on the critical
recovery path.

### Stage B.2 — AFM integration
Production-grade across 6 in-process call sites
(AFMSidecarGenerator, AFMSessionPool, OntologyClassifier,
EntityExtractor, IntakeValve, SessionTelemetryClassifier,
ConversationStateClassifier). The Agent-mode exclusion at
`ChatCoordinator.swift:383` is an Apple SDK limitation
(FoundationModels has no tool-calling protocol), not a wiring gap.
Only the error message needed clarification (commit #4 above).

### Stage F MAS readiness
- TEMP-FREE-TIER restoration trail in `Epistemos-AppStore.entitlements`
  is exemplary: 7-step restoration list at the top of the file +
  cross-references to `MAS_FIRST_FOCUS_DOCTRINE` §4.5 + memory entry.
- `grep -rn TEMP-FREE-TIER` in source returns exactly 4 hits, all in
  the entitlements file — matches the canon contract from
  `CODEX_HACKATHON_FINAL_CHECK_2026_05_03.md`.
- iMessage driver is gated behind 3 layers of `#if !EPISTEMOS_APP_STORE`
  (instance creation, environment binding, sidebar visibility) +
  `safeDetailSelection` redirects deep-link navigation back to .general
  in MAS. Defense in depth; no leak.

---

## Quick Capture salvage — triaged, not ported

`docs/fusion/QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` (new) inventories
the 25 Rust files (5,656 LOC across 10 modules) salvaged from the
`vigorous-goldberg` worktree and categorizes them into 4 tiers:

- **Tier A** (~1,700 LOC) — integration-ready today: `format/`,
  `canon/`, `grammar/`, `undo/`. Self-contained data types or
  deterministic algorithms.
- **Tier B** (~3,900 LOC) — integration-ready with named host wiring:
  `nightbrain/`, `heal/`, `route/`, `effect/`. Each lists exactly which
  Swift / trait wiring it needs.
- **Tier C** (~430 LOC) — DAG-blocked: `skill_discovery/`. Reads three
  provenance facts (tool-sequence-hash, user-accepted, latency-met)
  that only become typed once V2.1 Phase 8 lands.
- **Tier D** (~470 LOC) — Pro-only / Wave 6+: `browser_engine/`. Trait
  + WebKit-MAS-safe / Obscura-Pro-only / Mock adapters; beyond V2 scope.

The triage doc lists the recommended landing order within each tier so
a future agent can pick a slice and land it without redoing the
categorization work. No port was attempted in this loop — per the
recovery directive, the goal was triage, not implementation.

---

## Wait-for-signal stop point

The recovery loop stops here. Per `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`
§5 the next move requires an explicit user signal:

- **"RESUME SUBSTRATE V2"** → begins V2.1 (Cognitive DAG Phase 8.A-H,
  6-10 weeks). Unblocks Tier C in the salvage triage.
- **"RESUME RESEARCH TIER"** → skips ahead to V3 (Helios v3 +
  SCOPE-Rex + Ternary substrate + KV-Direct gate). Gated independently
  on a successful Week-0 ternary experiment.

Until one of those signals arrives, no V2 / V3 work begins. The user
can also redirect to any specific Tier A / Tier B salvage slice without
the umbrella signal — those land independently per the five-question PR
discipline.

---

## What stays true through V2 and V3

- **Helios v3 + SCOPE-Rex remains the ultimate goal.** This loop did
  not advance V3 work; the substrate fixes here are pre-requisites
  (silent-font-fallback fix, MAS UI gating, capability lattice contract
  tests) that close gaps the Helios path would otherwise inherit.
- **Five-question PR discipline carries unchanged**: every PR declares
  Stage / GenUI route / Sovereign / Pro impact / TEMP-FREE-TIER. No
  exceptions through V2 or V3.
- **MAS-first focus doctrine carries unchanged**: Pro stays "part of the
  plan, not on the critical path." `#if EPISTEMOS_APP_STORE || MAS_SANDBOX`
  remains the canonical gate; new Pro features go behind it from day
  one.
- **The Substrate Track Register stays the master backlog.** V2 / V3
  are moves through it, not parallel maps.

End of recovery loop.
