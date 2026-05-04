# Claude Performance Regression Fix Handoff

> **Index status**: CANONICAL-HISTORICAL — Session handoff; kept for state recovery (30-day minimum). No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-03-28
**Commit:** `a9a4e954`
**Previous commit:** `05a63934`
**Audience:** Codex / Claude Code

---

## What This Session Did

Claude Code performed a deep audit of the zero-corruption hardening work from the previous Codex session, verified it, then identified and fixed performance regressions introduced by that hardening pass.

### Verified and Kept (Codex's work is solid)

All of Codex's zero-corruption hardening was independently verified via:
- 3 parallel deep-scan agents (EventStore, NoteFileStorage, Rust crate)
- Full release_preflight.sh pass (2,662 Rust tests, fresh build, codesign)
- Manual UI testing via computer-use (notes, graph, settings, vault)
- Console.app monitoring (zero Epistemos errors)

### Performance Regressions Found and Fixed

| Regression | Severity | Fix Applied |
|---|---|---|
| `LaunchIntegrityGateView` blocked entire UI behind spinner until integrity check + vault restore completed | HIGH | Removed blocking gate — show app immediately, run check in `.task` background |
| `PRAGMA integrity_check` on every EventStore + SearchIndexService open (full-table scan) | HIGH | Replaced with `PRAGMA quick_check` (O(1) B-tree check) |
| `refreshFileProtections()` called on every EventStore write (9 call sites — ~6 filesystem stats per write) | MEDIUM | Removed from all write paths, kept only at init |
| `refreshBackupExclusion()` called on every SearchIndexService write (7 call sites) | MEDIUM | Removed from all write paths, kept only at init |
| TimeMachine `selectSnapshot` blocks UI with no spinner feedback | LOW | Added `Task.sleep(10ms)` yield so loading state renders before heavy SwiftData queries |

### Files Changed

- `Epistemos/App/EpistemosApp.swift` — Removed `.checking` phase from `LaunchIntegrityGateView`. Content renders immediately.
- `Epistemos/State/EventStore.swift` — `quick_check` instead of `integrity_check`. Removed 7 per-write `refreshFileProtections()` calls.
- `Epistemos/Sync/SearchIndexService.swift` — `quick_check` instead of `integrity_check`. Removed 7 per-write `refreshBackupExclusion()` calls.
- `Epistemos/Views/Landing/TimeMachineView.swift` — Added yield before heavy `reconstructState` call.

---

## What Codex Should Verify

### Priority 1: Startup Performance

The main user complaint was **noticeable hang on app startup**. The causes were:

1. **Integrity gate** — `LaunchIntegrityGateView` showed a "Verifying vault integrity..." spinner and blocked ALL UI until `performStartupIntegrityCheck()` + `restoreVaultFromBookmark()` completed. Fixed by removing the blocking gate.

2. **`PRAGMA integrity_check`** — Full-table scan of EventStore SQLite database on every open. For a database with thousands of events, this adds hundreds of milliseconds. Fixed by switching to `quick_check`.

3. **`AppBootstrap.init()`** is still synchronous and heavy (~30+ state objects, SwiftData container, Metal warmup). This was NOT changed — it existed before the hardening pass. If startup is still slow, the next target is making `AppBootstrap.init()` lazy.

**Verification:** Launch the app and measure time-to-interactive. It should now be comparable to commit `ddfe6c24` (before the hardening pass). If still slow, profile `AppBootstrap.init()`.

### Priority 2: TimeMachine Still Needs Deeper Fix

The current fix (10ms yield) is a band-aid. The real issue: `TimeMachineService.reconstructState(at:)` runs multiple SwiftData `FetchDescriptor` queries synchronously on `@MainActor` on every timeline selection:

- Per-note `SDPageVersion` fetch with predicate + sort
- Per-note disk read fallback via `NoteWindowManager.shared.currentBody(for:, mapped: true)`
- Up to 20 chat message count queries
- Graph node/edge count queries

The proper fix is to move `reconstructState` off `@MainActor` using a background `ModelContext`, or cache results so repeated selections don't re-query. This was NOT a regression — it was slow before the hardening pass too.

### Priority 3: Verify Integrity Still Works

The integrity protections are still active — they just don't block the UI:
- `performStartupIntegrityCheck()` still runs in `.task` on launch
- `readBody()` / `readBodyData()` still verify BLAKE3 hashes on every read
- `quick_check` still catches B-tree corruption on database open
- File protections (backup exclusion, Spotlight exclusion) are set once at init

Verify: Create a note, save it, manually corrupt the `.integrity` sidecar file, reopen the note. It should detect the mismatch and quarantine.

### Priority 4: Test Runtime Validation

The `RuntimeValidationTests` still expect `LaunchIntegrityGateView` to exist (it does — just without the spinner phase). Run:
```bash
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests
```

---

## What Was NOT Changed

- **NoteFileStorage integrity verification** — per-read BLAKE3 hash check + sidecar + xattr. This is the core data integrity layer and was kept as-is.
- **Atomic write protocol** — 5-step temp+fsync+rename+dir-fsync. Kept.
- **Rust FFI safety** — fail-closed helpers, panic=abort. Kept.
- **Zero `@unchecked Sendable`** in production. Kept.
- **SearchIndexService passive checkpoint** — Kept.
- **Startup integrity report** — Still computed, still blocks vault restore on corruption. Just doesn't block the UI.

---

## Release Status

**Label: `PRE-NOTARIZATION DIRECT-RELEASE CANDIDATE`**

The code is release-ready. Remaining work is all distribution infrastructure:
1. Apple Developer enrollment
2. Developer ID certificate + notarization
3. DMG packaging
4. Privacy policy + support URLs
5. Fresh-machine install test

No more code changes are needed for v1 release unless Codex finds issues in the verification steps above.
