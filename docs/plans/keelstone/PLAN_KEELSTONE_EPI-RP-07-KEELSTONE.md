# PLAN — KEELSTONE

ID: EPI-RP-07-KEELSTONE · Codename: KEELSTONE
Authored: 2026-07-06 · Status: build-ready v1 spine · Supersedes the three source dossiers where they conflict (see §1 ledger)

> KEELSTONE is the keel the other plans rest on. It is not a feature. It is the structural integrity of the whole product: the vault stays truth, the derived index stays a recoverable mirror, no note is ever lost or silently clobbered, the build collapses to exactly two honest surfaces, and nothing ships until an automatable gate proves all of it. Everything below is designed to survive enterprise scale — vaults from 10k to 100k+ notes under sustained external churn — on both the MAS and Experimental lanes.

---

## 0. How to read this file

This plan is the source of truth. The Swift spine files under `Epistemos/` and `config/` are the load-bearing skeleton that encodes the decisions here — they compile the invariants into code so they can't drift. The build prompt (`BUILD_PROMPT_KEELSTONE.md`) is what you hand to an implementing agent. An agent reviewing this work checks itself against §1 (nothing reverted), §8 (the phase bars are real behaviors, not "compiles"), and §9 (the gate blocks like a broken build).

Two things this plan refuses to do, because getting them wrong is how the product quietly breaks: it never lets the index become authoritative over the files, and it never silently overwrites an external edit. Every design choice bends to those two.

---

## 1. Resolved-contradiction ledger

The three source dossiers agreed on the spine and disagreed on specifics. Some of those specifics were dangerous. This is where each fracture resolves, so no future edit reintroduces the landmine.

| # | The disagreement | Resolution | Why |
|---|---|---|---|
| 1 | **iCloud materialization**: one dossier used a blocking `while … { Thread.sleep(0.1) }` loop up to 15s | **Killed.** Async `NSMetadataQuery` observation (`iCloudMaterializer.swift`) with `startDownloadingUbiquitousItem`, resumed by download-status notifications. Timeout resumes a Task, never blocks a thread. | A 15s blocking wait on a coordination queue risks watchdog termination on suspend, beachballs if it ever touches the main actor, and starves the sync daemon of a coordination slot. |
| 2 | **FSEvents vs NSFilePresenter primacy** | **FSEvents is the wide-area spine; NSFilePresenter is the coordination participant, not the change source.** | FSEvents sees *all* mutations (vim, VS Code, Syncthing, git). NSFilePresenter only hears changes made through `NSFileCoordinator` — blind to non-coordinating editors, which are the normal case. |
| 3 | **Index durability**: `synchronous=FULL` vs `NORMAL` | **WAL + `NORMAL`** for the derived DB, gated by a startup reconcile that re-derives any suspect rows. | The index is re-derivable from truth. NORMAL is corruption-safe and only risks the trailing transaction — which reconcile rebuilds. FULL costs write throughput we need at 100k notes and buys durability we don't. |
| 4 | **Corruption handling**: recover the DB vs rebuild | **Quarantine-and-rebuild from the vault.** Recovery is diagnostics-only. | Recovered data from a corrupt SQLite file is salvage, not truth. We already hold truth on disk. Never risk note bytes to save a cache. |
| 5 | **Conflict policy** | **Optimistic concurrency + explicit conflict.** Clean editor → silent reload. Dirty editor + disk moved → 3-way merge attempt, else visible conflict-copy. Never silent "replace disk" unless the user picks it. | Last-write-wins on note *body* is data loss. Conflict copies beat silent annihilation — the mature-sync consensus (Syncthing, Dropbox, iCloud/NSFileVersion). |
| 6 | **Rename detection** | **Inode correlation via `kFSEventStreamCreateFlagUseExtendedData`**, falling back to content classification when no inode. | Avoids needless re-embedding of moved-but-unchanged files at scale; bare rename flags arrive out of order. |
| 7 | **Surface macro placement** | **`SWIFT_ACTIVE_COMPILATION_CONDITIONS` scoped to each target only**, never in shared `base`. | Project-level settings propagate to all targets via `$(inherited)`. A macro in base is exactly how the ghost third surface returns. |
| 8 | **Atomic write mechanism** | **Coordinated `replaceItemAt` from an item-replacement dir on the same volume, off `@MainActor`.** | APFS atomic rename → old-or-new-never-truncated on crash. Plain `Data.write(atomically:)` doesn't coordinate with the iCloud daemon or a presenter. |

If a future change reverts any row of this table, it is a regression, not a refactor.

---

## 2. Executive thesis

The vault directory is the only authoritative state. Everything else — FTS, embeddings, the RRF fusion layer, the graph projection — is recoverable machinery arranged around it. On macOS that splits into two cooperating layers. The first is *safe access and safe writes*: security-scoped bookmark resolution plus `NSFileCoordinator` for every mutation Epistemos performs. The second is *advisory external-change detection*: an FSEvents per-disk stream over the whole vault, because FSEvents is the only mechanism that catches edits from non-coordinating tools and edits that happened while the app was closed. Coordinated I/O for correctness, FSEvents for breadth, deterministic rescans for truth.

The base-app question has a clean answer: **no.** Epistemos does not need a flag-less base surface. It needs a neutral shared codebase and exactly two shipping surfaces — Experimental (Developer ID, base default) and MAS (App Store) — with the surface macro scoped to each target so a third can't reappear by inheritance. The vestigial OpenChamber `#else` path is excised, not deprecated.

And release-readiness is not a claim, it's a gate. With the gate below wired as a hard CI blocker plus narrow manual sign-off, Epistemos earns a differentiated posture that isn't "better sync" — it's honest file-truth coexistence that survives third-party sync, external edits, crashes, and build-surface drift, proven rather than asserted.

---

## 3. External-change detection and reconciliation

The stack is layered, not singular. At the vault root: a directory-scoped `NSFilePresenter` registered on mount, the coordination participant for moves/deletes and iCloud-daemon cooperation. Across the whole tree: a per-disk FSEvents stream (`VaultEventStream.swift`) with `FileEvents | UseExtendedData | WatchRoot | NoDefer`, the wide-area spine. Optionally, for the single open note: a vnode watcher for sub-second conflict surfacing — a latency nicety, never a correctness dependency.

FSEvents is a *trigger*, never a transcript. It coalesces, collapses parent-and-child into one event, and can drop events — when it does it sets `MustScanSubDirs` and you rescan. `WatchRoot` gives a `RootChanged` event if the vault root is moved or deleted. Persist the last per-disk event ID and resume from it after relaunch so changes made while the app was closed still reconcile.

The reconciliation state machine (`VaultReconciler.swift`, a Swift actor that never touches `@MainActor`) is deterministic:

- **Mounted** → resolve bookmark, begin scope, register presenter, start FSEvents, prime the manifest.
- **Event batch** → debounce ~120ms, accumulate. A 1k–100k sync pull arrives as many batches; the debounce is what keeps it from spinning the writer.
- **Escalation flags first** → any `MustScanSubDirs`/`KernelDropped`/`UserDropped` → rescan the smallest affected subtree; `RootChanged` → full reconcile + remount check; `Unmount` → freeze.
- **Classify delta** → the manifest row is `{relativePath, inode, size, mtime, contentHash, tombstone}`. Cheap discriminator first: size+mtime unchanged → attribute touch → no-op. Only hash when a quick field moved or when disambiguating content-vs-metadata. **At 100k notes you cannot hash every file on every event — quick-field-first is the scale strategy, not an optimization.**
- **Apply** → added → parse+index; deleted → tombstone (but guard against iCloud dehydration masquerading as deletion — if the file still exists, it's not gone); moved → update path mapping, skip re-embed if content unchanged; content change → reparse + transactionally replace; **open editor changed on disk → conflict branch, never auto-reload over a dirty buffer.**

The invariant the whole gate tests: **incremental reconcile of a change set must equal a fresh rebuild from disk.** If those ever diverge, the index has silently become authoritative. That equality is the witnessable done-bar for the reconcile phase.

---

## 4. Conflict, durability, and index self-heal

**Writes** go through the three-part contract in `AtomicVaultWriter.swift`: coordinate (`NSFileCoordinator` `.forReplacing`), write to a scratch file in an item-replacement directory on the same volume, then `replaceItemAt`. On APFS that replace is an atomic rename — a mid-write `kill -9` leaves either the old full file or the new full file, never a truncated interleave. All of it off the main thread, wrapped in a `ProcessInfo` activity so a suspended/App-Nap'd process can't be torn down mid-commit.

**Conflicts** use a base snapshot captured on open (`{path, size, mtime, hash}`). Before save, re-read cheap metadata under coordination. Matches → write normally. Differs but editor clean → silent reload. Differs and editor dirty → conflict state: attempt diff3 three-way merge (base = snapshot on open, local = buffer, remote = disk), present the merged draft for review if clean; if not clean, write a visible conflict-copy and prompt. No silent "replace disk" ever, unless the user explicitly chooses it.

**iCloud/FileProvider**: assume a path can exist while bytes are not local. Never read/reconcile a dehydrated placeholder as if empty, and never read a hydration failure as deletion. `iCloudMaterializer.swift` probes `ubiquitousItemDownloadingStatus`, triggers download, and awaits completion via `NSMetadataQuery` — no polling. Preserve filename case exactly; case-only renames on case-insensitive volumes get flagged, not silently folded.

**The derived index** (`DerivedIndexDatabase.swift`) is WAL + `NORMAL`. Single write transaction per reconciled batch updates the manifest row, FTS rows (external-content FTS5 — body stored once in `pages`, FTS holds only the inverted index, which matters at scale), and embedding rows together; any failure rolls back and the vault file is untouched. Migrations are forward-only via `DatabaseMigrator`; `eraseDatabaseOnSchemaChange` is never enabled in a shipping build. On launch after an unclean shutdown: `quick_check`; on failure, quarantine the file and rebuild from the vault. `integrity_check` is soak/diagnostics only. Bound WAL growth under a sync storm with `wal_autocheckpoint` plus an explicit `wal_checkpoint(TRUNCATE)` after bulk reconcile, and run `PRAGMA optimize` (3.46.0+) at maintenance points rather than hot-path `ANALYZE`.

---

## 5. Vault lifecycle and bookmark hardening

The MAS vault is a user-selected folder held by an app-scoped bookmark (`VaultBookmarkStore.swift`). Entitlements: `user-selected.read-write` + `bookmarks.app-scope`. The lifecycle machine: **Disconnected → BookmarkResolved** (refresh eagerly if stale, while access is still valid) **→ Accessing → Operational** (presenter + FSEvents live, initial reconcile done). Failure edges: **PermissionLost** (writes blocked, reprompt) and **VolumeUnavailable** (root gone or `RootChanged` — writes blocked, editor stays dirty in memory, resume only after remount + reconcile).

Disconnect is a *real teardown*, not a setting flip — this is the "disconnect doesn't disconnect" bug class. Order matters: unregister the presenter, stop FSEvents, reject queued writes, invalidate editor bindings, then end the security scope. A registered presenter is retained until removed; skip that and you get zombie access behind a "disconnected" UI. `startAccessing…`/`stopAccessing…` are balanced exactly once each (`VaultAccessHandle.end()` is idempotent and fires on deinit as a backstop). The reprompt sheet shows only when access can't be recovered after a user action — don't regress the "sheet fires when vault IS set" fix.

Multi-vault isolates per vault: one bookmark, one presenter set, one FSEvents stream, one reconcile actor, one write queue, one index namespace. Don't share event IDs or manifest state across vaults.

---

## 6. Build-schema solidification — the two-config collapse

The answer to the owner's question, stated once, plainly: **no flag-less base surface. A neutral shared codebase plus exactly two target-scoped shipping surfaces.** The authoritative schema:

| Lane / target | Surface macro (target-scoped) | Signing + runtime | Entitlements posture | Distribution |
|---|---|---|---|---|
| **Epistemos** (Experimental / 1Code) | `EPISTEMOS_EXPERIMENTAL` | Developer ID, hardened runtime, notarized | no App Sandbox; subprocess capabilities allowed + supervised | direct / 1Code |
| **Epistemos-AppStore** (June / MAS) | `EPISTEMOS_APP_STORE` | App Store, App Sandbox, hardened as required | sandbox on; `user-selected.read-write`; `bookmarks.app-scope`; minimal extras; no arbitrary subprocess | Mac App Store |
| **Shared base** | *none* | shared compiler/linker/warnings | no surface-defining macros or entitlements | not shippable |

Debug/Release/Experimental are **build configs, not product surfaces**. Three Xcode configs must still map to exactly two surfaces. The compile-time guard lives in `AppSurface.swift`: `#error` if both macros are set, and — the new one — `#error` if neither is set. That second guard is what makes the vestigial base surface uncompilable rather than merely discouraged.

### 6.1 OpenChamber / ProAgent excision — safe sequence

You confirmed this code is dead. It's still tangled (LandingView, UIState, SubstrateHealthPanel, tests, a clone + prebuild script), so the excision is a *clean* excision — `BUILD SUCCEEDED` verified per step — and it front-loads an inventory pass so nothing load-bearing gets pruned by accident even though we believe it's all dead. Delete order is deliberately: replace the live default path *before* removing the infrastructure behind it, so at no point is a running default depending on something already deleted.

1. **Inventory (no deletion).** `grep -r` for `OpenChamber`, `ProAgent`, `PRO_BUILD`, `openchamber` across sources, `project.yml`, scripts, tests. Produce a kill-list and a *keep-list* of anything referenced by non-OpenChamber code. If the keep-list is non-empty, stop and resolve before proceeding. → bar: kill-list reviewed, keep-list empty or salvaged.
2. **Introduce `AppSurface`.** Add the enum + guards. Nothing routes through it yet. → bar: BUILD SUCCEEDED, both targets.
3. **Collapse LandingView** from `#if APP_STORE / #elseif EXPERIMENTAL / #else OpenChamber` to a two-way switch on `AppSurface.current`. The `#else` branch is gone. → bar: both targets launch to the correct surface; no OpenChamber view instantiated.
4. **Scope the macro.** Ensure `EPISTEMOS_EXPERIMENTAL` is in the Epistemos target's `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and *not* in base. → bar: `xcodebuild -showBuildSettings` shows each target with exactly its own macro; neither inherits the other's.
5. **Remove infrastructure.** Delete `.research-clones/openchamber` and the `build-openchamber-web.sh` prebuild step from `project.yml` — only now, after the default path no longer needs it. → bar: BUILD SUCCEEDED with no prebuild reference.
6. **Remove code + tests.** Drop `Epistemos/ProAgent/*` from target membership then the repo; clean `UIState`/`SubstrateHealthPanel` of third-surface modeling; rewrite tests that expected OpenChamber symbols. → bar: BUILD + full test suite green.
7. **Drift guardrails in CI** (§9.2).

---

## 7. Performance and hardening floor

The floor is measured, not described (`config/perf-budgets.toml`, source-controlled and release-blocking). Every budgeted path emits an `os_signpost` span; CI computes p50/p95 from Instruments/MetricKit and fails on unbudgeted regression. The reference envelope is a 10k-note vault on M2 Pro; a separate, looser-but-bounded enterprise envelope covers 100k notes, where the rule shifts from "fast" to "the UI shell never waits on the index" — lazy index load, embeddings allowed to lag with visible staleness, WAL size bounded.

Hardening is a per-release gate with four audit lenses — data-core integrity, external-boundary integrity, runtime integrity, capability integrity — and **a HIGH finding blocks ship exactly like a failing test.** Runtime integrity on the Experimental lane specifically covers the embedded 1Code child process: a child-process ledger, supervision-not-polling, clean reap on quit and on crash-restart, no orphan helper surviving app exit. MAS specifics: sandbox on, bookmark + user-selected entitlements only, no temporary exceptions unless reviewed. Helper tools on the MAS lane inherit the sandbox with `app-sandbox` + `inherit` and *nothing else* — adding any other entitlement to an inheriting helper is a launch-failure crash loop.

---

## 8. Phased build order (the checkable tracker)

Each phase has a **witnessable proven-done bar** — a real behavior, not "it compiles." Check a box only when the bar is demonstrated. The Plan 6 / EMBERCATCH dependency is flagged at Phase 1.

- [ ] **Phase 0 — Excision inventory.** Grep kill-list + keep-list produced; keep-list empty or salvaged. *(Do this before touching anything — §6.1 step 1.)*
- [ ] **Phase 1 — Durable write core.** Every save uses coordinate → temp → replace; a `kill -9` injected mid-write leaves the note as either the full old or full new version across 1,000 trials, never truncated. **Dependency: Plan 6 / EMBERCATCH capture-writes** — if not landed, add a minimal internal save-journal so the reconciler can tell "my just-committed write" from "external unknown write" without racey heuristics.
- [ ] **Phase 2 — External detection.** Presenter + per-disk FSEvents run together; a forced dropped-event and a root-move each trigger the correct rescan/escalation; last-event-ID replay picks up a change made while the app was quit.
- [ ] **Phase 3 — Deterministic reconciliation.** After external add/edit/delete/rename storms and a 1,000-file sync-pull burst, incremental reconcile converges to *exactly* the fresh-rebuild snapshot (file manifest and derived index both equal).
- [ ] **Phase 4 — Conflict UX.** A dirty open note changed on disk always enters an inspectable conflict path (merge-review or conflict-copy) and never silently clobbers either side; a clean open note reloads silently.
- [ ] **Phase 5 — Index self-heal.** A deliberately corrupted index DB is quarantined and rebuilt from the vault with zero user-facing note loss; `quick_check`/`integrity_check` are wired into support diagnostics; a forced-fail migration recovers by rebuild.
- [ ] **Phase 6 — Schema collapse + OpenChamber retirement.** Only two app surfaces remain; the flag-less surface *cannot compile* (Guard 2 fires); no `OpenChamber`/`ProAgent` residue in sources, `project.yml`, or scripts; full test suite green.
- [ ] **Phase 7 — Perf + hardening floor.** `perf-budgets.toml` gates CI (a seeded regression fails the pipeline); a seeded HIGH hardening finding blocks the archive lane; on Experimental, no child process survives app quit across 100 launch/quit cycles.
- [ ] **Phase 8 — Release gate.** The full gate (§9) blocks the archive lane exactly as a failing test does; the data-safety soak (external-edit storm + sync race + `kill -9` during write) and the first-run/upgrade matrix both pass on both lanes.

---

## 9. The v1 release quality gate

The gate behaves like a broken build: any required item fails → release stops. Five blocking categories plus a soak suite and an upgrade matrix.

**9.1 Blocking categories.**
- *Data integrity & reconciliation* (the thesis test): round-trip create/edit/rename/move/delete/restore in plain, iCloud, and one third-party-sync folder; deterministic reconcile after storms; clean-editor safe-reload; dirty-editor conflict-never-clobber; `kill -9` during write → no truncation; forced dropped-event → rescan converges; root move → `VolumeUnavailable` not data loss; corrupt DB → quarantine+rebuild.
- *Packaging & distribution*: MAS — sandbox on, minimal entitlements, no unjustified temporary exceptions. Developer ID — hardened runtime on, notarized + stapled before distribution (`notarytool` + `stapler`, not the deprecated altool path).
- *Stability/performance/resource*: zero main-thread file IO in mount/save/reconcile; budgets met; no runaway WAL/cache; no long-lived child process after quit (Experimental).
- *Accessibility/localization/upgrade*: VoiceOver + keyboard sanity on landing, onboarding, mount, editor, search, settings, conflict dialog; localization sanity on onboarding/permissions/conflict copy; first-run + upgrade matrix across prior versions and both lanes.
- *Honest capability-gating audit* (separate sign-off): a truth table per capability — available in MAS / in Experimental / nowhere / gated by disconnect / gated by non-hydration. Any copy, affordance, or screenshot implying a capability that isn't actually available blocks release.

**9.2 Soak suite** (the heart of the gate): 10k-file initial mount; 1k-file sync-pull burst; repeated external edits while open; nested rename storms; sustained idle-open on battery; repeated mount/disconnect/reconnect without stale-prompt regression; `kill -9` at random points in save/rename/index-transaction boundaries. Done-bar: after each soak, a full rescan equals a clean rebuild.

**9.3 Upgrade matrix**: fresh install empty vault; fresh install large existing vault; upgrade from prior index schema; bookmark survives relaunch; bookmark goes stale (refreshes); permission revoked post-install; vault volume absent at launch; both lanes on one account with isolated containers.

**9.4 CI drift guardrails**: assert exactly two app targets; assert each defines exactly one surface macro and neither inherits the other's; assert no source/script/`project.yml` path references `OpenChamber`/`ProAgent`; assert built entitlements match the approved matrix per lane.

---

## 10. Deep fabric integration (F1–F6)

KEELSTONE is the fabric's structural integrity — it hardens the contracts every other plan plugs into, which is why "it feels like one app" is a *consequence* of this plan rather than a separate feature.

- **F1 — vault bus.** Reconciliation *is* the vault bus's integrity. A capture (EMBERCATCH), a research save (LODESTAR), an agent edit (LUMENLENS/KINDRED) are all vault writes; KEELSTONE guarantees none is ever lost or desynced, and a change by one feature reflects live everywhere. Seam: features write through `AtomicVaultWriter`; KEELSTONE owns coordination, atomicity, and propagation. No feature may invent a private store authoritative over the vault.
- **F2 — capability registry.** The release gate verifies every capability's honest gating, and the two-config schema defines exactly which surfaces host the registry: June/MAS and 1Code/Experimental, no third. Seam: `AppSurface.allowsSubprocessCapabilities` is the honest gate the registry reads; subprocess-backed capabilities are Experimental-only, enforced at compile time.
- **F3 — companion presence.** The hardening floor covers presence-layer robustness (supervision-not-polling). Presence renders on Experimental only; MAS shows the feature without the companion. Seam: reconcile run-state (mounting/indexing/reconciling/blocked) is emitted on the state bus for KINDRED to render.
- **F4 — knowledge graph.** File mutations detected by reconcile update graph nodes/edges through the graph's public API only — never its internals. Seam: rename/tombstone events map to node/edge updates without corrupting relational links.
- **F5 — provenance ledger.** Every agent-originated vault write is attributed on the shared ledger (timestamp, rationale, path, diff). "Press the companion → see what it did" works because reconcile records origin. Seam: KEELSTONE distinguishes app-origin from external-origin writes (the save-journal from Phase 1) so provenance is honest.
- **F6 — state/event bus.** Reconcile and lifecycle state stream to all surfaces (native SwiftUI + June/1Code WebViews) in lock-step, no double source of truth. Seam: no polling — the bus carries run-state; consumers degrade to "index stale / rebuilding" rather than ever treating the derived layer as truth.

Schema-solidification guarantees exactly two consistent fabric hosts, which is what lets the other five contracts stabilize honestly. These six briefs are one integrated product built one plan at a time — KEELSTONE first, because it's the substrate.

---

## 11. Competitive edge

Obsidian shows the appeal of local markdown truth with a rebuildable metadata cache; Syncthing shows the conservative habits worth copying (watcher + full-scan redundancy, temp-then-move, conflict copies over silent overwrite); Apple's iCloud model shows that transport sophistication never erases app-owned conflict handling; Logseq's own docs warning users to back up before its new sync is a reminder not to ship an ambitious sync story ahead of the durability proof. Epistemos's edge isn't "better sync." It's honest file-truth coexistence plus a release gate that's part of the product's trust model. Nobody in this space makes the gate itself a promise.

---

## 12. Open questions (preserved — not silently resolved)

These are real forks that need your judgment or a follow-up research cycle; I have opinions but won't pretend they're settled.

1. **Automatic merge aggressiveness.** Ship diff3 auto-merge for clean cases, or always route non-trivial merges to a review screen? (Leaning: attempt, but default to review whenever the merge isn't trivially clean. Safer than feeling smart.)
2. **Are embeddings release-critical like FTS?** (Leaning: no — hard-gate FTS + block-index consistency; let embeddings lag with *visible* staleness so an external storm doesn't become an embedding bottleneck. But this needs a call on how stale is too stale.)
3. **One DB per vault, or one namespaced DB for all vaults?** Per-vault is cleaner for teardown, corruption isolation, and support bundles; shared is more efficient but couples failure domains. (Leaning: per-vault at v1.)
4. **Case-only rename policy** on case-insensitive volumes: warn + require a two-step rename, or handle silently? (Leaning: warn — the edge is real per Apple + Syncthing.)
5. **Does Experimental ship subprocess-backed features in v1?** If yes, child-process supervision + entitlement review join the gate from day one, not as a retrofit.
6. **Volume-move re-authorization** (owner-raised): app-scoped bookmarks resolve renames on the same volume but not a move to a different disk. When the user moves the vault to an external drive, do we auto-request parent-directory authorization (better UX, broader entitlement, harder MAS review) or fall back to a re-mount prompt? Needs a research + review-risk pass.
7. **Large-batch coalescing latency tuning.** The 120ms debounce and 0.15s FSEvents latency are starting points. At a 20k–100k-file pull, what window minimizes write-amplification without making the user think sync is stuck? Needs measurement on real hardware, not a guessed constant.
8. **Embedding index under sustained churn** — batch vs realtime, and whether the vector store should be a separate DB from FTS so an embedding rebuild never touches the search-critical path. Follow-up research cycle.

---

## 13. Self-critique

Three weakest points, honestly. First, the three-way merge is a stub — `diff3`/`diff-match-patch` is named but not implemented, and merge quality is where a conflict UX lives or dies; that needs its own focused build + test pass. Second, the enterprise envelope (100k notes) is reasoned from mechanism, not yet measured — the perf budgets for that tier are educated placeholders until they run on real hardware with a real 100k-note corpus, and FSEvents/WAL/FTS5 behavior at that scale is exactly where surprises hide. Third, the Experimental child-process supervision (pseudo-terminal SIGHUP-on-parent-death) is sketched at the plan level but the spine doesn't yet include the supervisor file — it's the one load-bearing piece I described rather than skeletoned, and it deserves the same treatment as the sync files before you lean on it.

A follow-up cycle should: implement and stress the merge engine against a corpus of real conflict cases; run the 100k soak and replace the placeholder budgets with measured ones; and build out the subprocess supervisor spine with its child-process ledger and reap-on-quit tests.

---

## 14. Rubric self-scores

| Axis | Score | Note |
|---|---:|---|
| Grounded | 4.5 | Resolutions tie to Apple/SQLite/GRDB/xcodegen primary sources via the research passes; a few enterprise-scale numbers are reasoned, not yet measured. |
| Alternatives named | 4.7 | Every §1 fracture names the rejected option and why it lost. |
| Build-actionable | 4.8 | Real files, real seams, per-step BUILD-SUCCEEDED bars, a checkable tracker, a definitive config table. |
| No fabrication | 4.6 | Stubs (merge, supervisor) are flagged as stubs; the iCloud landmine is named and replaced rather than papered over. |
| Constraint-fidelity | 4.9 | Files-are-truth, no proprietary server, no silent clobber, MAS discipline, forward-only migrations, don't-regress-known-fixes all held. |
| Integration depth | 4.5 | F1–F6 seams are concrete (who owns what), grounded in the fabric brief. |
| Depth/novelty | 4.4 | The quick-field-first scale strategy, the compile-time Guard 2, the quarantine-over-recovery stance, and the gate-as-trust-model are the genuinely load-bearing moves. |

All axes ≥4.

---

## 15. Repo-integration amendments (owner review, 2026-07-06 — accepted; these bind like §1)

Verified against the live repo before build-start. Full detail: `KEELSTONE_REVIEW_2026_07_06.md`.

1. **§6.1 sequencing fix (Guard 2 would break Debug).** Today the `Epistemos` target defines
   `EPISTEMOS_EXPERIMENTAL` ONLY in its Experimental config; Debug/Release have no surface macro.
   Corrected order: **(a)** add `EPISTEMOS_EXPERIMENTAL` to the `Epistemos` target's Debug AND
   Release configs in the real `project.yml` — PRESERVING the existing tokens (`DEBUG`,
   `EPISTEMOS_LINK_SUBSTRATE_RT`); verify via `xcodebuild -showBuildSettings`; **(b)** only then
   land `AppSurface.swift` with both guards; **(c)** then collapse LandingView. This also enacts
   the owner decision "Experimental/1Code is the base default."
2. **The delivered `project.yml` is a PATTERN, not a replacement.** The real file is ~23KB
   (macOS 26.0, three configs, Rust preBuild chain, local packages, widgets/tests targets, signing).
   Apply the PRINCIPLE (target-scoped macros, no surface macro in shared base) as a 3-line edit to
   the existing file + `xcodegen generate`. Never regenerate from the pattern file.
3. **One FSEvents pipeline, ever.** `VaultSyncService` already runs FSEvents (startWatching :2397,
   escalation-flag handling ~:266) + `VaultIndexActor`. The spine REPLACES/refactors that path; it
   never runs beside it.
4. **The derived layer is plural.** GRDB (`SearchIndexService`+`ReadableBlocksIndex`) + Rust
   `epistemos-shadow` (tantivy/usearch) + SwiftData `SDPage` + Spotlight are ALL derived. The
   manifest/heal/checkpoint work extends the EXISTING GRDB DB; the shadow index joins the same
   rebuild hook. No second GRDB file.
5. **Body-truth end-state (answers the owner's md-truth question).** Today there are THREE body
   locations: vault `.md` (`page.filePath`), `Application Support/Epistemos/note-bodies/`
   (`NoteFileStorage`, pageId-keyed), and legacy `SDPage.body` (being cleared). End-state: the
   vault `.md` is the SOLE body truth; all writes go file-first through `AtomicVaultWriter` to the
   vault path; `SDPage` is metadata-only; `note-bodies/` is retired or reduced to the Phase-1
   write-staging journal. `SDPageVersion` snapshots (history) are exempt.
6. **Spine code fixes applied** (see spine headers): Swift `while let … where` removed; missing
   `await` on the materializer actor; `String.hashValue` → CryptoKit SHA-256 (hashValue is
   per-launch randomized — persisted manifests would thrash); FSEvents extended-data keys corrected
   to `…DataPathKey`/`…FileIDKey`; NSMetadataQuery external-documents scope added; per-vault
   checkpoint key; indexed-set predicate covers `.md` + `.json` (chats).
7. **perf budgets MERGE** into the existing `docs/perf-budgets.toml` as `[keelstone.*]` sections
   alongside `[agent_surface]`/`[experimental_surface]` — never replace the file.
8. **Guard-2 blast radius.** `EpistemosWidgets` cherry-picks individual `Epistemos/` files —
   `AppSurface.swift` must never join a cherry-picking target unless that target defines a surface
   macro. `EpistemosTests` (@testable import, own sources) is unaffected.
