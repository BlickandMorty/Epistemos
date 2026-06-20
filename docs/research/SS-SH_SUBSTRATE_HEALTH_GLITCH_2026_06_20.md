# SS-SH — Substrate Health page glitched / not working in Settings (2026-06-20)

Read-only research (subagent), code-grounded. Feeds the SUBSTRATE-HEALTH-GLITCH bug item. Owner: *"the substrate
health page is still glitched, it is not working in settings."* Cross-refs SS-PERF (#1 timer collapse), SS-F
(orphan rows), SS-B (sprawl).

> **⚠️ VERIFIED-CODE UPDATE 2026-06-20 (loop, supersedes the "sync-FFI-on-MainActor" root below).**
> Ground-truth re-read of the *current* row code: the synchronous-FFI-on-MainActor freeze root this doc
> identified is **already fixed** — the per-row FFI now polls **OFF the MainActor**:
> `SystemGHealthRow.refresh()` (:106-122) wraps the FFI in `await Task.detached { … }.value`;
> `EmlObservatoryHealthRow.refresh()` (:70-73) calls `SubstrateHealthUnifiedClient.snapshotAsync()`.
> So the panel's actual *freeze/beachball* root (main-thread blocking on a slow/hung sync FFI) is gone —
> matching `IMPLEMENTATION_SEQUENCE_2026_06_19.md:98` ("freeze fix completed across ALL health rows,
> off-MainActor polling"). **Remaining SS-SH work is now only the marginal perf collapse** of the ~15
> still-separate per-row 1Hz `startTimer()` clocks into one shared clock (15 invalidations/sec → 1) — a
> ~15-file UI refactor whose correctness is **runtime-validated + SwiftUI-version-dependent** (the
> collapse-vs-`onDisappear` question below), so it should land with the owner present to repro the panel,
> NOT blind/unattended. The orphan rows (#3) are re-verified dead: `CognitiveDagHealthRow` +
> `HyperdynamicLoopHealthRow` have **0 mount sites** outside their own files (still ship a dead 1Hz timer
> loop) → recommend owner-approved retirement (files I did not author → surfaced, not deleted blind).
> Net: the owner's reported *glitch* is most likely already resolved; verify by opening
> Settings → Substrate Health. The text below is the original subagent research, kept for provenance.

> **✅ COLLAPSE LANDED 2026-06-20 (slices 1-5, owner-directed).** All 17 per-row 1 Hz
> timers now run on ONE shared `SubstrateHealthClock` (new `SubstrateHealthClock.swift`:
> an `@Observable` tick + a `.substrateHealthPoll` modifier, driven by a single `.task`
> on the panel `Form` and injected via `.environment`). 16 rows subscribe through the
> modifier; the tick-based `ActiveConstellationRow` reads the shared `tick` directly.
> Deterministic teardown (the one `.task` auto-cancels when the panel leaves). Each row's
> `refresh()` (already off-MainActor where it mattered) is unchanged, so this is a pure
> timer/scheduler collapse — the further dedup of the 6 *identical* unified-snapshot fetches
> (6 FFI/sec → 1) is a separate follow-up. Source-guarded in `SubstrateHealthClockTests`
> (no row retains a `startTimer`/`Task.sleep` self-timer). Commits 561495822 → (this).
> Live "panel no longer stutters" pass = owner-runtime (the app-hosted UI can't run headless).
>
> **What is NOT collapsed (and why that's correct).** A grep of `startTimer`/`Task.sleep`
> across `*HealthRow.swift` still matches **3 files that are NOT SubstrateHealthPanel rows**:
> (a) `CognitiveDagHealthRow` (the orphan — distinct from the migrated
> `CognitiveDagCountsHealthRow`) and (b) `HyperdynamicLoopHealthRow` are both **dead**
> (0 live mount sites anywhere — verified) and ship a dead 1 Hz timer → recommend
> owner-approved retirement (files not authored by this loop → surfaced, not deleted
> blind); (c) `BackgroundIndexingHealthRow` is a **separate live row** mounted in
> `SettingsView.swift:988` (a different Settings section, its own `refreshInterval` poll) —
> one lone timer, not part of the panel's ~17-timer pileup, so out of scope. A source guard
> in `SubstrateHealthClockTests` asserts none of the 3 is mounted in `SubstrateHealthPanel`,
> so none can silently re-enter the panel's contention set.

## Headline (verified root)
The panel renders structurally fine (`Form` + 3 collapsible `Section(isExpanded:)`, no broken `ForEach`/id, no
`EmptyView`, NOT flag-gated). **The glitch = MainActor contention from ~15 simultaneous 1Hz polling timers, each
doing a SYNCHRONOUS Rust FFI round-trip ON THE MAINACTOR + a SwiftUI invalidation — every second, forever, even
while their section is collapsed.** That's the classic "panel looks frozen / beachballs / stutters / won't
scroll" signature, and it **violates the CLAUDE.md rule "never block @MainActor."** Verified from code; the exact
visual symptom severity needs runtime repro.

## Panel structure — NOT the root (verified clean)
- `SubstrateHealthPanel.swift:24-147` `body` = `Form` + 3 `Section(_,isExpanded:)`: "Retrieval and Indexing"
  (`:26`, expanded), "Agent Runtime" (`:48`, expanded), "Substrate Floor" (`:111`, collapsed `showSubstrateFloor
  =false :22`).
- Rows listed inline (no `ForEach`/dynamic id) via `surface(falsifier:wRow:weight:)` `@ViewBuilder` (`:149-166`)
  → no broken-id render bug. No `EmptyView`/early-return/missing `@State` (3 `@State` bools `:20-22`; layout-guard
  test `SubstrateHealthPanelLayoutGuardTests.swift:11-24` asserts this — the prior "blew out window height" fix
  via collapsing Substrate Floor is a DIFFERENT old fix, not the current glitch).
- Mount `SettingsView.swift:498 case .substrateHealth: SubstrateHealthPanel()` — outside any `#if`, only
  `.settingsThemedBlurPage`. `Form` supplies its own scrolling.

## The ~15-timer overload (the likely root, verified)
Every mounted row uses the identical anti-pattern: `.onAppear { refresh(); startTimer() }` where:
```
refreshTask = Task { @MainActor in
  while !Task.isCancelled {
    try? await Task.sleep(for: .seconds(1))
    _ = <SomeBridge>.status()/snapshot()   // SYNCHRONOUS FFI on MainActor
    refresh()                              // mutates @State → invalidate
  }
}
```
- Sites: `EmlObservatoryHealthRow.swift:74-83`, `ACSAdmissionHealthRow.swift:94-104`, `SystemGHealthRow.swift
  :128-138` (`_ = SystemGBridge.status()`), + 13 others. **16 files contain the 1Hz `Task.sleep(.seconds(1))`
  loop**; one is the orphan `HyperdynamicLoopHealthRow` (never mounted) → **~15 active timers** when the panel is
  open. `AnswerPacketHealthRow` adds a 2nd `Task` (`:157` + `:167`).
- **The FFI is SYNCHRONOUS + runs ON the MainActor:** `SubstrateHealthUnifiedClient.snapshot()` (`SubstrateHealth
  Support.swift:313-329`) + `SystemGBridge.status()` (`SystemGWiring.swift:194-212`) are plain `do { try ...Json();
  JSONDecoder().decode() }` — no `await`, no background actor. Each `Task { @MainActor in }` runs the FFI + decode
  + `refresh()` on the main thread. = ~15-16 sync FFI round-trips + ~15-16 invalidations/sec on one panel. **A
  single slow/hanging FFI call (e.g. agent_core mutex contention) FREEZES the whole panel** (blocks main thread).
  Mechanism verified; beachball/freeze observation = needs runtime repro.
- **Cancellation gap (SS-PERF):** cancellation is correct per-row (`.onDisappear { refreshTask?.cancel() }`) BUT
  with `Section(isExpanded:)` in a `Form`, **collapsing a section does NOT reliably fire `.onDisappear` on its
  children** (collapsed subviews kept alive, just hidden) → the ~10 Substrate-Floor timers keep polling FFI at
  1Hz even though that section opens collapsed. So the height-fix did NOT reduce the timer/FFI load — all ~15 run
  on open. (Collapse-vs-onDisappear is SwiftUI-version-dependent → needs repro to confirm which stop.)

## Orphan / broken rows (cleanup, not a render-breaker)
- `CognitiveDagHealthRow` + `HyperdynamicLoopHealthRow` NEVER instantiated (0 mount sites outside their files);
  not in `SubstrateHealthPanel.body` → can't directly glitch the panel; dead code shipping a timer loop
  (`HyperdynamicLoopHealthRow.swift:91-103`) if ever mounted (confirms SS-F). `graphIndexChats` is unrelated
  (a General toggle `SettingsView.swift:1386`, not this panel).
- **Error handling is PER-ROW, not panel-wide:** a failed FFI → `.unavailable(error)` (`SubstrateHealthSupport
  .swift:323-327`) → the row shows an honest "unavailable/(no read yet)" line; one erroring row does NOT break
  the layout. No spinner-forever path.

## Data-source failures + flag gating (both honest, NOT roots)
- All rows degrade honestly: `snapshot()` is `#if canImport(agent_coreFFI)` (`:315`), returns `.unavailable`
  when FFI absent (gray dashed); `SystemGBridge.status()` returns nil → keeps last-good (`SystemGWiring.swift
  :191`). Only hang vector = the synchronous-FFI-on-MainActor above.
- Panel NOT `#if !EPISTEMOS_APP_STORE` gated (`SettingsView.swift:498` outside the `#if`); MAS+Pro both render
  it; rows self-report "Pro only" honestly. Flag gating is NOT a glitch root.

## Ranked roots + fix
1. **(MOST LIKELY) ~15× 1Hz synchronous-FFI-on-MainActor timers → main-thread contention/freeze/stutter.** Fix
   (= SS-PERF #1): replace ALL per-row `startTimer()` loops with ONE shared clock — a single
   `TimelineView(.periodic(from:by:1))` (or one shared `@Observable` poller) at the panel level that fetches
   `SubstrateHealthUnifiedClient.snapshot()` **OFF the MainActor** (FFI+decode on a `nonisolated`/background
   actor, hop back to set `@State`) and fans the result to rows. Collapses ~15 FFI/sec → 1, ~15 invalidations →
   1. Rip out the 16 `startTimer()` funcs. Precedent: `ApprovalModalView` was converted Timer.publish →
   `TimelineView(.periodic)` (CLAUDE.md perf log).
2. **(Contributing) Collapsed-section timers keep polling** → the shared-clock fix moots this; else gate each
   row's polling on its section's `isExpanded`.
3. **(Cleanup) Orphan rows** — remove/honestly-retire `CognitiveDagHealthRow` + `HyperdynamicLoopHealthRow`
   (never mounted; `HyperdynamicLoopMetrics.ingest` no callers, SS-F).

## Verified vs needs-repro
VERIFIED from code: the timer count, the synchronous-FFI-on-MainActor mechanism, per-row honest degradation,
ungated mount, dead orphan rows. NEEDS RUNTIME REPRO: the exact visual symptom (beachball vs stale vs blank) +
which collapsed rows actually fire `.onDisappear` (open Settings→Substrate Health, Instruments Time Profiler on
main + count active `refreshTask`s).

Key files: `Views/Settings/SubstrateHealthPanel.swift:24-166` · `SubstrateHealthSupport.swift:313-329` (sync FFI),
`:360-432` (UI primitives) · `SettingsView.swift:498` (ungated mount) · timer exemplars `EmlObservatoryHealthRow
.swift:74-83`, `ACSAdmissionHealthRow.swift:94-104`, `SystemGHealthRow.swift:128-138`, `AnswerPacketHealthRow
.swift:157-176` · FFI bridges (sync, MainActor) `SystemGWiring.swift:194-212`, `ACSAdmission/ACSAdmissionWiring
.swift:139-149` · orphans `CognitiveDagHealthRow.swift`, `HyperdynamicLoopHealthRow.swift` · guard test
`SubstrateHealthPanelLayoutGuardTests.swift`.
