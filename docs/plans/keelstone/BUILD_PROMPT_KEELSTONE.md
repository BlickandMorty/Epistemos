# BUILD PROMPT — KEELSTONE

ID: EPI-RP-07-KEELSTONE · Codename: KEELSTONE

> Paste this to the implementing/reviewing agent. It is scoped to one plan and one ID. Do not absorb scope from any other plan (EPI-RP-02/04/05/06/08); cross-plan needs are named seams, not inline scope.

## Your job

Implement the KEELSTONE spine for Epistemos — the vault-sync durability layer, the two-config build collapse, and the v1 release gate — against `PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md`. The spine files in `Epistemos/` and `config/` are your starting skeleton; extend them, don't reinvent them. When the plan and your instinct disagree, the plan wins unless you can show the plan is wrong, in which case flag it in the §1 ledger terms and stop for review.

## Ground truth you must never violate

1. **Files are truth. The index is a recoverable cache.** Never write a code path where the SQLite index can become authoritative or silently diverge. On any doubt, reconcile deterministically from disk.
2. **Never silently clobber an external edit.** A dirty open note changed on disk enters a conflict flow (merge-review or visible conflict-copy). Silent "replace disk" only ever happens by explicit user choice.
3. **No proprietary sync server.** Coexist with iCloud/Dropbox/Syncthing; don't fight them.
4. **MAS file discipline.** All vault IO through security-scoped bookmarks + `NSFileCoordinator`. Handle stale bookmarks, permission loss, volume unmount.
5. **Never block `@MainActor`.** All vault IO and reconcile run off the main thread (actors). Secrets in Keychain. GRDB migrations forward-only; `eraseDatabaseOnSchemaChange` never enabled in a shipping build.
6. **Two surfaces, no third.** The surface macro (`EPISTEMOS_EXPERIMENTAL` / `EPISTEMOS_APP_STORE`) is scoped to each target's `SWIFT_ACTIVE_COMPILATION_CONDITIONS` — never in shared base. A flag-less build must fail to compile.

## Hard "do not" list (these are landmines, verified)

- **Do NOT** poll for iCloud download with `Thread.sleep`. Use the async `NSMetadataQuery` pattern in `iCloudMaterializer.swift`. A blocking wait risks watchdog termination and starves the sync daemon.
- **Do NOT** call `evictUbiquitousItem` inside an `NSFileCoordinator` block (deadlock).
- **Do NOT** use `Data.write(atomically:)` or `String.write(to:)` directly on a vault file. Use `AtomicVaultWriter` (coordinate → temp-on-same-volume → `replaceItemAt`).
- **Do NOT** make `NSFilePresenter` the primary change source. FSEvents is the wide-area spine; the presenter is the coordination participant.
- **Do NOT** hash every file on every event. Quick-field (size+mtime) first; hash only on a quick-field change or content-vs-metadata disambiguation. This is the difference between working and not working at 100k notes.
- **Do NOT** put `EPISTEMOS_EXPERIMENTAL` in shared/base build settings — the App Store target inherits it via `$(inherited)` and you resurrect the ghost surface.

## Excision safety (you confirmed OpenChamber/ProAgent is dead — verify anyway)

Before deleting anything, run the Phase 0 inventory: grep `OpenChamber`, `ProAgent`, `PRO_BUILD`, `openchamber` across sources, `project.yml`, scripts, tests. Produce a kill-list AND a keep-list of anything referenced by non-OpenChamber code. If the keep-list is non-empty, STOP and surface it — do not prune a feature that turns out to be load-bearing. Then follow §6.1's exact order: replace the live default path BEFORE removing the infrastructure behind it, `BUILD SUCCEEDED` after every step.

## Build in this order, and only check a box when the behavior is real

Follow the Phase 0–8 tracker in the plan. Each phase's done-bar is a witnessable behavior — a passing `kill -9` soak, a convergence-equality assertion, a fired `#error`, a green archive lane — never "it compiles." Report each phase by demonstrating its bar.

The gate (plan §9) is the finish line: it must block the archive lane exactly like a failing test, including the data-safety soak (external-edit storm + sync race + `kill -9` during write) and the first-run/upgrade matrix on both lanes.

## What to hand back

- Working spine wired into the real `Epistemos/Sync/*`, `Epistemos/App/*`, `project.yml`.
- The reconcile convergence-equality test (incremental == fresh rebuild) as an executable assertion.
- The `kill -9`-during-write soak in `EpistemosTests/AppStoreHardeningTests.swift`.
- CI drift guardrails (plan §9.4).
- A short note on each open question (plan §12) you touched, and any place the plan was wrong.

## Scale bar

Design every path for 10k–100k+ notes under sustained external churn, on BOTH lanes. If a design only works at 1k notes, it's not done.

---

## REPO REALITY ADDENDUM (read FIRST — verified against the live repo 2026-07-06)

These amend the plan per §15 and bind like the "do not" list:

1. **Do NOT replace `project.yml` with `spine/project-pattern.yml`.** The real file is ~23KB with
   the Rust preBuild chain, local packages, widgets/tests targets, macOS 26.0, three configs. The
   actual change: add `EPISTEMOS_EXPERIMENTAL` to the `Epistemos` target's Debug + Release configs
   (preserving `DEBUG` + `EPISTEMOS_LINK_SUBSTRATE_RT`), keep the AppStore target as-is, keep
   surface macros OUT of shared base. Then `xcodegen generate` (NEVER hand-edit the .xcodeproj).
2. **Sequencing: scope the macros BEFORE landing AppSurface.swift** — Guard 2 otherwise #errors
   every Debug build (Debug currently has no surface macro). Order: macros → showBuildSettings
   verify → AppSurface → LandingView collapse → infra removal.
3. **Refactor, don't duplicate:** `VaultSyncService` already runs FSEvents + watching
   (startWatching :2397) and `VaultIndexActor` already reconciles. Wire the spine INTO/OVER that
   path. One stream + one reconciler per vault. Same for the index: extend the existing GRDB
   (`SearchIndexService`/`ReadableBlocksIndex`) with manifest/heal/checkpoint; hook the Rust
   shadow index (`RustShadowFFIClient`) into the same rebuild path. No parallel DB, no second
   stream.
4. **Body truth — OWNER-MANDATED PHASE 4.5 (plan §15.5), not optional**: converge to
   vault-`.md`-only — `SDPage` metadata-only, `NoteFileStorage` note-bodies retired-or-journal.
   It sits in the §8 tracker between Phases 4 and 5 with a four-leg witnessable bar (file-first
   writes proven by grep; external-edit reflects in-app; in-app edit reflects in Finder/vim;
   convergence green before/after + zero-loss legacy migration). KEELSTONE is not done without
   this box checked.
5. **Budgets**: merge `spine/perf-budgets-keelstone.toml` into `docs/perf-budgets.toml` as
   `[keelstone.*]` sections.
6. **Spine fixes are already applied** in `docs/plans/keelstone/spine/` (SHA-256 hash, FSEvents
   extended-data keys, materializer await, external-documents metadata scope, per-vault checkpoint
   key, `.md`+`.json` indexed set). Use THESE copies, not the raw research wave.
7. **Build discipline**: isolated DerivedData; BUILD SUCCEEDED on BOTH targets per phase; never two
   xcodebuilds at once; commit per green step with pathspec-scoped commits (`git commit --only -- <files>`).

---

## CROSS-PLAN COORDINATION UPDATE (2026-07-06, post-LUMENLENS audit — additive; nothing above is invalidated)

Plan 2 (LUMENLENS, `docs/plans/lumenlens/`) was audited after you started. Three items now bind:

1. **Add `KINDRED_ENABLED` while you're already scoping macros (§15.1).** In the same project.yml
   edit where you add `EPISTEMOS_EXPERIMENTAL` to the `Epistemos` target's Debug/Release configs,
   ALSO add `KINDRED_ENABLED` to that target's conditions (all its configs) — never on
   `Epistemos-AppStore`, never in shared base. It is LUMENLENS's companion-edit feature flag,
   subordinate to the surface macro (guards live in
   `docs/plans/lumenlens/spine/CompanionEditGate.swift`, landed by the LUMENLENS agent — you only
   place the flag). Include it in your `-showBuildSettings` verification, and extend the §9.4 CI
   drift guardrails: assert `KINDRED_ENABLED` appears on the Epistemos target only. If you have
   ALREADY passed the macro-scoping step: make this a small follow-up edit + `xcodegen generate`
   at your next clean point — do not interrupt a mid-phase state.
2. **Keep `ActiveEditorBridge` a THIN protocol seam — do not build the editor side.** Implement
   only a minimal stub adapter over the current editor (enough to witness your Phase 4 conflict
   done-bar: dirty-never-clobbered / clean-reload). The REAL implementation is LUMENLENS's
   `LensSessionCoordinator` (its session state machine + write-lease), which will replace your
   stub. Do not build a session machine, write-lease, or rich conflict UI into
   NoteDetailWorkspaceView — that is LUMENLENS scope; a merge-review surface beyond the minimal
   conflict-copy prompt is theirs too.
3. **`AtomicVaultWriter` contract is now load-bearing for two plans — keep it stable.** LUMENLENS
   minimal-diff writeback will pass pre-composed WHOLE-buffer contents (splice happens in memory;
   the write is always full-buffer atomic). Keep the `write(_ content:, to:)` whole-content
   signature; don't add partial/streaming write variants.
