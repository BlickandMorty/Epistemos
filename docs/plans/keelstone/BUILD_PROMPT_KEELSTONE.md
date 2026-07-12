# BUILD PROMPT — KEELSTONE

ID: EPI-RP-07-KEELSTONE · Codename: KEELSTONE

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. KEELSTONE now
> serves the single MAS/App Store product line. Collapse prior two-surface
> language into App Store vault durability, security-scoped access, release
> gates, and parked-lane leak/symbol checks. Do not add `EPISTEMOS_EXPERIMENTAL`
> or `KINDRED_ENABLED` to active build settings unless the owner later reopens
> those lanes.

> Paste this to the implementing/reviewing agent. It is scoped to one plan and one ID. Do not absorb scope from any other plan (EPI-RP-02/04/05/06/08); cross-plan needs are named seams, not inline scope.

## Your job

Implement the KEELSTONE spine for Epistemos — the vault-sync durability layer, the two-config build collapse, and the v1 release gate — against `PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md`. The spine files in `Epistemos/` and `config/` are your starting skeleton; extend them, don't reinvent them. When the plan and your instinct disagree, the plan wins unless current code evidence proves the plan is wrong. If evidence proves a plan line wrong, record the contradiction in the phase notes, choose the smallest non-destructive path that preserves the plan's intent, and keep going. Ask the owner only for a destructive, irreversible, or scope-changing choice; otherwise do not wait.

## Ground truth you must never violate

1. **Files are truth. The index is a recoverable cache.** Never write a code path where the SQLite index can become authoritative or silently diverge. On any doubt, reconcile deterministically from disk.
2. **Never silently clobber an external edit.** A dirty open note changed on disk enters a conflict flow (merge-review or visible conflict-copy). Silent "replace disk" only ever happens by explicit user choice.
3. **No proprietary sync server.** Coexist with iCloud/Dropbox/Syncthing; don't fight them.
4. **MAS file discipline.** All vault IO through security-scoped bookmarks + `NSFileCoordinator`. Handle stale bookmarks, permission loss, volume unmount.
5. **Never block `@MainActor`.** All vault IO and reconcile run off the main thread (actors). Secrets in Keychain. GRDB migrations forward-only; `eraseDatabaseOnSchemaChange` never enabled in a shipping build.
6. **One active MAS surface, no ghost base.** `EPISTEMOS_APP_STORE` is the only active shipping
   surface while `MAS-ONLY-SHIP-LOCK-2026-07-07` is active. Parked macros such as
   `EPISTEMOS_EXPERIMENTAL` and `KINDRED_ENABLED` must stay out of shared/base build settings and
   out of the App Store archive unless the owner explicitly reopens those lanes. A flag-less build
   must fail to compile instead of silently becoming a hidden third surface.

## Hard "do not" list (these are landmines, verified)

- **Do NOT** poll for iCloud download with `Thread.sleep`. Use the async `NSMetadataQuery` pattern in `iCloudMaterializer.swift`. A blocking wait risks watchdog termination and starves the sync daemon.
- **Do NOT** call `evictUbiquitousItem` inside an `NSFileCoordinator` block (deadlock).
- **Do NOT** use `Data.write(atomically:)` or `String.write(to:)` directly on a vault file. Use `AtomicVaultWriter` (coordinate → temp-on-same-volume → `replaceItemAt`).
- **Do NOT** make `NSFilePresenter` the primary change source. FSEvents is the wide-area spine; the presenter is the coordination participant.
- **Do NOT** hash every file on every event. Quick-field (size+mtime) first; hash only on a quick-field change or content-vs-metadata disambiguation. This is the difference between working and not working at 100k notes.
- **Do NOT** put `EPISTEMOS_EXPERIMENTAL` in shared/base build settings — the App Store target inherits it via `$(inherited)` and you resurrect the ghost surface.

## Deletion safety (owner-locked: OpenChamber/ProAgent are not kept)

Owner directive, 2026-07-06: **delete ProAgent/OpenChamber.** Before deleting files, run the Phase
0 inventory: grep `OpenChamber`, `ProAgent`, `PRO_BUILD`, `openchamber` across sources,
`project.yml`, scripts, tests. Produce a deletion plan with three buckets: immediate deletes,
dependencies that must first be renamed/neutralized, and tests/scripts to rewrite or remove. Do
not mark anything for preservation; references are work to remove, not a reason to preserve the branded
surface. You may temporarily migrate reusable runtime primitives behind neutral names only to keep
the build green on the way to deletion. Then follow §6.1's exact order: replace the live default
path BEFORE removing the infrastructure behind it, neutralize shared dependencies, delete branded
code/resources/scripts/tests, and prove `BUILD SUCCEEDED` after every step.

## Build in this order, and only check a box when the behavior is real

Follow the Phase 0–8 tracker in the plan. Each phase's done-bar is a witnessable behavior — a passing `kill -9` soak, a convergence-equality assertion, a fired `#error`, a green archive lane — never "it compiles." Report each phase by demonstrating its bar.

The gate (plan §9) is the finish line: it must block the MAS archive lane exactly like a failing test, including the data-safety soak (external-edit storm + sync race + `kill -9` during write), parked-lane leak checks, and the first-run/upgrade matrix on the MAS lane.

## Continuing hardening loop (owner-locked)

When Phase 0-8 and the release gate appear complete, do not stop at the last
checked box. Invoke `deep-hardening-loop` and continue auditing, hardening,
researching, testing, and improving the KEELSTONE scope until the owner
explicitly stops or a real blocker prevents useful progress. Combine it with
`thermo-nuclear-code-quality-review`, `Recursive App Audit`, `Epistemos Release
Audit`, Playwright/browser/screenshot tooling where runtime evidence matters,
and security/threat-model skills where persistence, permissions, or release
risk warrants it. Keep the loop scoped to KEELSTONE seams, tests, evidence,
docs, release risk, and regressions; do not absorb unrelated LUMENLENS,
KINDRED, RECKONER, or Experimental renderer scope.

Before each substantive KEELSTONE batch, keep a scoped owner-intent and
verification-debt checkpoint in the phase notes: verbatim owner query/excerpt,
interpreted intent, constraints, non-goals, acceptance checks, deferred
commands, files touched, risk reason, expected proof, and checkpoint trigger.
Edit surgically, re-read changed regions after editing, and batch builds/tests
only at meaningful checkpoints unless risky/shared behavior needs an immediate
narrow check.

## What to hand back

- Working spine wired into the real `Epistemos/Sync/*`, `Epistemos/App/*`, `project.yml`.
- The reconcile convergence-equality test (incremental == fresh rebuild) as an executable assertion.
- The `kill -9`-during-write soak in `EpistemosTests/AppStoreHardeningTests.swift`.
- CI drift guardrails (plan §9.4).
- A short note on each open question (plan §12) you touched, and any place the plan was wrong.

## Scale bar

Design every path for 10k-100k+ notes under sustained external churn on the MAS/App Store lane. If
a design only works at 1k notes, it's not done.

---

## REPO REALITY ADDENDUM (read FIRST — verified against the live repo 2026-07-06)

These amend the plan per §15 and bind like the "do not" list:

1. **Do NOT replace `project.yml` with `spine/project-pattern.yml`.** The real file is ~23KB with
   the Rust preBuild chain, local packages, widgets/tests targets, macOS 26.0, and existing configs.
   The MAS-only pivot supersedes the older instruction to add `EPISTEMOS_EXPERIMENTAL`.
   Current change shape: verify the AppStore target and MAS macro path, keep parked macros OUT of
   shared base and active archive settings, then `xcodegen generate` (NEVER hand-edit the .xcodeproj).
2. **Sequencing: prove MAS archive truth BEFORE landing guard/collapse changes.** Order:
   showBuildSettings verify → AppSurface/MAS guard → LandingView MAS collapse → parked infra removal
   → archive leak checks.
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

1. **Do not add parked-lane macros while MAS-only is active.** The older instruction to add
   `KINDRED_ENABLED`/`EPISTEMOS_EXPERIMENTAL` is superseded by
   `MAS-ONLY-SHIP-LOCK-2026-07-07`. Current verification is inverted: prove those macros and
   companion symbols do not leak into `Epistemos-AppStore`; keep shared/base free of surface macros;
   leave Kindred/Experimental guards as parked provenance unless the owner later reopens those lanes.
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
4. **Dataset artifacts (RECKONER, additive — fold in at your next clean point, do not interrupt a
   mid-phase state):** plan §15.10 — make the indexed-set/artifact routing EXTENSIBLE
   (csv/xlsx/icalc -> dataset hook; *.dataset.md -> dataset metadata parser, not the note indexer), add the
   artifact conflict-delegation branch, extend the gate soak per §15.10(c), and give
   AtomicVaultWriter a Data overload. If you have already passed the reconciler phases, land the
   extensibility seam + overload now and leave the dataset-specific routes as clearly-marked stubs
   for the RECKONER agent.
