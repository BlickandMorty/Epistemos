# KEELSTONE — Deliberate pre-build review (Claude, 2026-07-06)

ID: EPI-RP-07-KEELSTONE · Codename: KEELSTONE
Reviewed: the owner's research wave (plan + build prompt + 7 spine files + 2 configs), juxtaposed
against the live repo across 4 verification cycles. **Verdict: GO — with the amendments below
applied.** The plan's architecture is sound and matches the repo's direction; the deliverables
needed repo-integration corrections before an agent could build without stepping on live systems.

## A. What is genuinely good (keep exactly as designed)
- The §1 resolved-contradiction ledger (blocking-iCloud-poll killed; FSEvents primary / presenter
  participant; WAL+NORMAL for a derived cache; quarantine-over-recovery; conflict-copy over
  last-write-wins; inode rename correlation; target-scoped macros; coordinated temp-then-replace).
  Every row checks out against Apple/SQLite reality.
- The reconcile invariant (incremental == fresh rebuild) as the witnessable gate.
- Guard 2 (`#error` on flag-less builds) — the right forcing function for the two-surface collapse.
- Quick-field-first (size+mtime before hash) as the 100k-note scale strategy.
- The release gate structure (soak + upgrade matrix + drift guardrails + honest-gating audit).

## B. Integration landmines found (all fixed in this package)

### B1. The delivered `project.yml` is a PATTERN, not a replacement — CRITICAL
The real `project.yml` is ~23KB: macOS **26.0** (not 14.0), xcodeVersion 16, **three configs**
(Debug/Release/Experimental), Rust preBuild chain (8 build scripts), local packages
(EpistemosLlama/MarkEdit/SwiftTerm/Kokoro/GRDB/Grape), widgets + tests targets, team signing,
`EPISTEMOS_LINK_SUBSTRATE_RT` + `MAS_SANDBOX` + `DEBUG` compilation conditions. Applying the
delivered 68-line file verbatim would destroy the build. The spine copy now carries a DO-NOT-REPLACE
header; the real change is three lines in the existing file (see B2).

### B2. §6.1 sequencing bug — Guard 2 breaks Debug builds if landed first
Today the `Epistemos` target's Debug/Release configs have **no surface macro** (only the
Experimental config defines `EPISTEMOS_EXPERIMENTAL`). Landing `AppSurface.swift` (Guard 2) at
§6.1 step 2 as written → instant `#error` on every Debug build. **Corrected order (plan §15):**
first scope the macro into the `Epistemos` target's Debug/Release configs — preserving the existing
tokens (`DEBUG`, `EPISTEMOS_LINK_SUBSTRATE_RT`) — verify with `xcodebuild -showBuildSettings`, and
only then land AppSurface with both guards. This is also exactly the owner's "Experimental is the
base default" decision: all configs of the `Epistemos` target become the 1Code surface.

### B3. A second FSEvents stream would double-reconcile — adapt, don't add
`Epistemos/Sync/VaultSyncService.swift` **already has** an FSEvents pipeline (flags handling incl.
MustScanSubDirs/KernelDropped/UserDropped/RootChanged/Mount/Unmount near line 266; `startWatching`
at :2397; `stopWatching(preserveData:)`), plus `VaultIndexActor`. The spine's
`VaultEventStream`/`VaultReconciler` must REPLACE-or-refactor that path — one stream, one
reconciler per vault, never two. The build prompt addendum makes this explicit.

### B4. The derived layer is plural — manifest/heal must cover the real stores
Real derived stores: GRDB (`SearchIndexService` + `ReadableBlocksIndex`, with existing PRAGMA
tuning + migrations), the Rust `epistemos-shadow` index (tantivy BM25 + usearch HNSW via
`RustShadowFFIClient`), SwiftData `SDPage` metadata, Spotlight. `DerivedIndexDatabase`'s schema
sketch overlaps `ReadableBlocksIndex` — the agent extends the EXISTING GRDB DB (manifest table +
quick_check/quarantine + TRUNCATE checkpoint + `PRAGMA optimize`), and wires the shadow index into
the same rebuild hook. Two parallel GRDB files = two truths = the exact drift KEELSTONE forbids.

### B5. Compile errors in the spine (fixed in `spine/`)
1. `VaultReconciler`: `while let … where …` — removed from Swift (Swift 3); rewritten.
2. `VaultReconciler`: `materializer.state(of:)` called without `await` (actor) — fixed.
3. `VaultReconciler.hash` used `String.hashValue` — **randomized per launch**, so every persisted
   manifest hash would mismatch on next launch and every note would re-index every start. Replaced
   with real CryptoKit SHA-256.
4. `VaultEventStream`: `kFSEventStreamEventExtendedDataKeyInode` does not exist. The real constants
   are `kFSEventStreamEventExtendedDataPathKey` + `kFSEventStreamEventExtendedFileIDKey`. Fixed,
   with proper `as String` bridging.
5. `iCloudMaterializer`: `NSMetadataQueryUbiquitousDocumentsScope` only sees the app's own iCloud
   container — a user-selected iCloud Drive vault needs
   `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope`. Both scopes now set. Also noted:
   hydration completion produces an FSEvents change anyway, so `whenLocal` is a latency
   optimization — correctness survives without it.
6. `VaultReconciler` md-only filter: the real vault also indexes `chats/**/*.json`
   (ShadowVaultBootstrapper) — predicate must match the real indexed set (noted inline).
7. `persistCheckpoint`: last-event-ID key must be per-vault (multi-vault isolation, plan §5) —
   parameterized in the copy.
8. Entitlement paths + deployment target corrected to repo reality (`Epistemos/*.entitlements`,
   macOS 26.0) in comments.

### B6. `perf-budgets.toml` must MERGE, not replace
`docs/perf-budgets.toml` already exists with `[binary]/[appstore]/[runtime]/[agent_surface]/
[experimental_surface]/[meta]`. The KEELSTONE budgets land as new `[keelstone.*]` sections in that
file. The spine copy carries the merge header.

### B7. Guard-2 blast radius: targets that cherry-pick `Epistemos/` files
`EpistemosWidgets` compiles individual files from `Epistemos/` (Intents/Engine picks). Rule added:
`AppSurface.swift` must never be added to a cherry-picking target unless that target defines a
surface macro. `EpistemosTests` links `@testable import` (own sources only) — unaffected.

## C. The owner's md-truth question — answered with repo evidence
The refactor direction is **correct and industry-consensus** (Obsidian model; the plan's §2 thesis).
Current repo reality found in review: **three body locations** —
1. the vault `.md` (真 truth target; `page.filePath`),
2. `~/Library/Application Support/Epistemos/note-bodies/` (pageId-keyed `NoteFileStorage`, mmap
   reads, integrity xattrs — the mid-migration store),
3. legacy `SDPage.body` ("cleared after saveBody(); loadBody() falls back for pre-migration rows").

KEELSTONE's end-state (now stated in plan §15): **vault `.md` is the sole body truth.** All writes
go file-first through `AtomicVaultWriter` to the vault path; `SDPage` becomes metadata-only (title,
tags, filePath, hashes — no live body); `note-bodies/` is either retired or reduced to a
crash-safety write-staging journal (which Phase 1 wants anyway); external edits auto-reconcile in
(Phases 2–4). `SDPageVersion.body` snapshots are fine (history, not live truth). This is strictly
better than both the old app-side-truth model and the current three-way split — the owner's
instinct is validated, and the migration is precisely KEELSTONE Phases 1–4.

## D. One agent or two?
**One agent for KEELSTONE.** The keel is one shared spine (Sync/, App/, project.yml) compiled into
both targets — territory overlap between a "MAS agent" and an "Experimental agent" would be ~100%,
and only one xcodebuild can run at a time anyway. The agent verifies each phase bar on BOTH targets
alternately (June + 1Code). Two agents become sensible again only for later surface-scoped plans
(e.g. KINDRED is 1Code-only).

## E. Package contents (what to hand the build agent)
- `PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md` — the plan, verbatim, + **§15 repo-integration
  amendments** (accepted).
- `BUILD_PROMPT_KEELSTONE.md` — the prompt, verbatim, + **Repo Reality Addendum** (the agent's
  first read).
- `spine/` — the 7 Swift skeletons with the B5 fixes applied (marked `KEELSTONE-REVIEW:`), plus the
  two config files re-headed as PATTERN/MERGE references.
Hand the agent the whole `docs/plans/keelstone/` directory; the prompt tells it the reading order.
