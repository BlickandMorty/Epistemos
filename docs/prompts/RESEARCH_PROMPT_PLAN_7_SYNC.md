# DEEP-RESEARCH PROMPT — PLAN 7: SYNC + v1 RELEASE QUALITY GATE

> Paste below `─── BEGIN ───` into a deep-research model. Output = build-ready dossier. Owner
> authored 2026-07-06. **Build split: both builds (MAS + 1Code).** MAS is the strict constraint
> surface (sandbox + file coordination).

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal data-durability & release-readiness researcher. Produce a build-ready dossier for (a)
**robust vault sync** and (b) the **v1 release quality gate** of a macOS-native PKM. External
primary sources (NSFileCoordinator/NSFilePresenter, security-scoped bookmarks, FSEvents, iCloud/
FileProvider, SQLite/GRDB durability, macOS release/notarization). Cite everything; invent nothing.
Design against the file names below.

## 1. Product context (ground truth)
Epistemos = macOS-native PKM. The **vault = markdown files on disk** (chosen by the user, accessed
via a security-scoped bookmark) is the single source of truth; a **derived index** (FTS/embeddings)
mirrors it for search. The vault may live in iCloud Drive / Dropbox / a plain folder and be edited
by **other apps** concurrently. Two builds: **MAS** (sandbox + hardened runtime; file access only
via security-scoped bookmarks + `NSFileCoordinator`) and **1Code/Experimental** (Developer ID).
Ships in **both**. There is **no proprietary cloud** — "sync" = coexisting safely with the user's
own file-sync + keeping the derived index consistent, not building a server.

## 2. Thesis
**The vault on disk is truth; Epistemos coexists safely with external edits and third-party file
sync, keeps its derived index perfectly consistent, never loses or corrupts a note — and the v1
quality gate proves that before release.** Robustness and honest release-readiness over features.

## 3. Hard constraints
1. **Files are truth; the index is derived** — never let the index become authoritative or diverge
   silently; reconcile deterministically after any external change.
2. **MAS file discipline** — all vault IO through security-scoped bookmarks + `NSFileCoordinator`
   / `NSFilePresenter`; handle bookmark staleness, permission loss, volume unmount.
3. **Zero data loss / corruption** — atomic writes, conflict-safe, crash-safe; an external edit made
   while a note is open must not be silently clobbered (detect + merge/prompt).
4. **No proprietary sync server** — coexist with iCloud/Dropbox/Syncthing/etc.; do not fight them.
5. Platform hygiene: `@Observable`; never block `@MainActor`; keys in Keychain; don't touch the graph
   engine internals; GRDB migrations are forward-only + tested.

## 4. What exists today (extend, don't reinvent)
- `Epistemos/Sync/VaultSyncService.swift` (vault CRUD, `createPage`, materialize-markdown-before-
  return), `Epistemos/Sync/VaultIndexActor.swift`, `Epistemos/Sync/SearchIndexService.swift`
  (FTS/PRAGMA tuning), `Epistemos/Sync/ReadableBlocksIndex.swift` (schema + migrations),
  the RRF fusion search layer.
- Vault mount/bookmark UX: `Epistemos/Views/Onboarding/VaultReprompSheet.swift` +
  `SetupAssistantView.swift`; prior fixes for "sheet fires when vault IS set" + "disconnect doesn't
  disconnect" (memory: 2026-05-12 vault bug fixes) — build on these, don't regress.
- Release context: MAS hardening tests (`EpistemosTests/AppStoreHardeningTests.swift`), the
  subprocess-hardening + memory-pressure work, notarization/entitlements.

## 5. Research dimensions
### D1 — External-change detection & reconciliation (core)
- The correct macOS mechanism to observe vault changes made by other apps/sync: `NSFilePresenter`/
  `NSFileCoordinator` vs `FSEvents` vs `DispatchSource` file watching — trade-offs, sandbox behavior,
  coalescing, rename/move/delete detection, large-batch (sync pulls a thousand files) handling. Cite.
- **Reconciliation**: after external changes, deterministically re-derive the index (incremental,
  not full-rescan when avoidable); detect content vs metadata change; handle a note open in the
  editor changing on disk (the open-editor conflict). Define the state machine.

### D2 — Conflict model & durability
- Atomic/crash-safe note writes (write-temp-then-rename, `NSFileCoordinator` writing intents).
- Conflict when Epistemos and an external app both edit: detection (mtime/hash/`fileVersion`),
  resolution (last-write-wins vs 3-way merge vs conflict-copy like iCloud's), and the honest UX.
- iCloud/FileProvider specifics: `.icloud` placeholder/undownloaded files, coordinated download,
  ubiquitous item states. Third-party sync (Dropbox/Syncthing) gotchas. Cite.

### D3 — Index consistency & recovery
- Keeping FTS + embeddings + RRF fusion in lock-step with files; detecting drift; a **self-heal /
  rebuild** path; bounded memory (the writer-heap/PRAGMA tuning already done). GRDB migration
  discipline (forward-only, tested, recoverable). Corruption recovery.

### D4 — Vault lifecycle & bookmark robustness
- Mount/disconnect/re-mount, stale bookmark refresh, permission-loss recovery, multi-vault, volume
  unmount mid-write. Harden the repromp/disconnect flows (don't regress the known fixes).

### D5 — The v1 RELEASE QUALITY GATE (the second half of this plan) ★
- Define the **release-readiness gate**: the concrete, automatable checks that must pass before a v1
  ship — data-integrity (round-trip, no-loss, reconciliation), crash-free key flows, MAS
  entitlements/sandbox/hardened-runtime/notarization, memory/energy budgets, performance budgets,
  accessibility, localization sanity, upgrade/migration from a prior install, and a "no fake
  feature / honest capability gating" audit. Cite Apple's App Store review + notarization reality.
- Model it as a **gate that blocks release like a broken build** — checklist + automated harness +
  manual sign-off items. Include a data-safety soak test (external-edit storm, sync race, kill-9
  during write) and a first-run/upgrade matrix.

### D6 — Competitive synthesis
- How Obsidian (no server, file truth, Sync add-on), iCloud-based apps (Bear/Apple Notes), and
  Logseq handle file truth + external edits + conflict. What to copy/avoid; the novel edge (honest
  file-truth coexistence + a real release gate).

## 6. Primary-source discipline
Cite NSFileCoordinator/NSFilePresenter/FSEvents/FileProvider, GRDB/SQLite durability, App Store
review + notarization docs. Flag sandbox-gated behaviors. Distinguish observed vs inferred.

## 7. Deliverable
1. Executive thesis. 2. **External-change detection + reconciliation** (D1 — headline). 3. Conflict
+ durability model (D2). 4. Index consistency + self-heal (D3). 5. Vault lifecycle/bookmark harden
(D4). 6. **The v1 release quality gate** (D5 — headline: checklist + automated harness + soak/upgrade
matrix). 7. Competitive table + novel edge (D6). 8. Phased build order (durable write core → external
detection → reconciliation → conflict UX → index self-heal → release gate), each with a witnessable
proven-done bar; flag Plan 6 (Capture writes) dependency. 9. Open questions.

## 8. Anti-patterns
No proprietary sync server. No design where the index can silently become authoritative. No silent
clobber of external edits. No "release-ready" claim without the automatable gate + data-safety soak
test. Don't regress the known vault repromp/disconnect fixes.

─── END RESEARCH BRIEF ───
