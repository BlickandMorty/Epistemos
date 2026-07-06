# DEEP-RESEARCH PROMPT — PLAN 7 (KEELSTONE): SYNC + BUILD-SCHEMA SOLIDIFICATION + DEEP HARDENING + v1 RELEASE

**ID:** `EPI-RP-07-KEELSTONE` · **Codename:** KEELSTONE · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape.

> Paste below `─── BEGIN ───` into a deep-research model. Output = build-ready dossier. Owner
> authored 2026-07-06; scope expanded the same day to fold in **build-schema/config solidification +
> deep performance-optimization/hardening + release-readiness** — this plan is the app's structural
> *keel*. **Build split: both builds (MAS + 1Code/Experimental).** MAS is the strict constraint
> surface (sandbox + file coordination).
>
> **Surfaces today = MAS/June + 1Code/Experimental ONLY. There is no live "Pro" surface — but the
> flag-less base build config still mounts the deprecated OpenChamber/ProAgent surface
> (`LandingView` `#else` branch). Resolving that (retire OpenChamber/ProAgent + collapse to two
> configs + make Experimental the base) is explicitly IN SCOPE here.**

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
sync, keeps its derived index perfectly consistent, never loses or corrupts a note — sits on a
solidified two-config build schema (MAS + Experimental, no vestigial third surface), is hardened and
performance-optimized to a shippable floor, and passes a v1 release gate that proves all of it.**
Robustness, structural clarity, and honest release-readiness over features — this is the keel the
other plans rest on.

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

### D6 — Build-schema / config solidification + the base-app question ★ (owner-asked)
Ground truth to design against: Epistemos builds via **compile flags** — `EPISTEMOS_APP_STORE`
(→ June, MAS) and `EPISTEMOS_EXPERIMENTAL` (→ 1Code, Developer-ID). `xcodegen` `project.yml` is the
source of truth (two app targets: `Epistemos` (Dev-ID) + `Epistemos-AppStore` (MAS); configs
Debug/Release/Experimental). A hard `#error` forbids `EXPERIMENTAL && APP_STORE`. Today the
**flag-less base config still mounts the deprecated OpenChamber/ProAgent surface** via
`LandingView`'s `#else` branch. `PRO_BUILD` is dead (3 comment-only refs).
- **Answer the owner's question explicitly: is a flag-less "base app" needed, or just two configs?**
  Research the cleanest end-state: collapse to exactly **two shipping configurations** —
  **Experimental (Developer-ID, base default)** and **MAS (App Store)** — and eliminate the vestigial
  flag-less/OpenChamber path. Detail the safest migration: retire `Epistemos/ProAgent/*`, the
  `.research-clones/openchamber` clone + `build-openchamber-web.sh` preBuild step, collapse
  `LandingView`'s `#if APP_STORE / #elseif EXPERIMENTAL / #else OpenChamber` to a clean two-way, and
  make Experimental the base — WITHOUT tripping the `#error` (never add EXPERIMENTAL to the shared
  base config the App Store target inherits via `$(inherited)`; scope it to the `Epistemos` target).
- **Solidify the schema:** one authoritative table of {config → flags → surface → signing/entitlements
  → distribution}. Guardrails (a lint/`#error` matrix) so the two configs can never drift or a third
  reappear. Cite xcodegen + Xcode build-setting inheritance reality.
- Sequence + risk for the OpenChamber retirement (it's wired into `LandingView`, `UIState`,
  `SubstrateHealthPanel`, tests) — do it like a clean excision, verified BUILD SUCCEEDED per step.

### D7 — Deep performance optimization + hardening (shippable floor) ★
Fold the owner's perf/hardening doctrine into the release keel. Research + specify a **hardening &
performance floor** both configs must clear before v1:
- **Performance:** the "instant open" budget (agent surface, editor, landing), memory/energy floors
  (the app already does memory-pressure relief, bounded caches, lazy-init, WebView pooling — extend
  to a measured budget in `perf-budgets.toml`), cold-start, large-vault (10k+ notes) behavior,
  thermal. Define the metrics + how they're gated in CI. Cite Instruments/os_signpost/MetricKit.
- **Hardening:** the four audit lenses + robustness patterns already in canon (FFI truth boundary,
  supervision-not-polling, ring-buffer circuit breaker, thermal↔breaker, loopback-origin pinning,
  agent-destructive-op safety, untrusted-ingest, data-core integrity, subprocess hardening on the
  Dev-ID lane). Turn them into a **per-release gate** where a HIGH finding blocks ship like a broken
  build. Include the embedded-1Code-backend supervision (child-process ledger, clean reap on quit).
- MAS specifics: sandbox, hardened runtime, entitlements minimalism, notarization; Experimental
  (Dev-ID) subprocess hardening. Cite Apple's hardened-runtime/notarization + App Sandbox docs.

### D8 — Competitive synthesis
- How Obsidian (no server, file truth, Sync add-on), iCloud-based apps (Bear/Apple Notes), and
  Logseq handle file truth + external edits + conflict. What to copy/avoid; the novel edge (honest
  file-truth coexistence + a real release gate). Plus: how mature two-config (free/pro, or
  sandboxed/direct) macOS apps keep build schemas clean + hardened.

## 6. Primary-source discipline
Cite NSFileCoordinator/NSFilePresenter/FSEvents/FileProvider, GRDB/SQLite durability, App Store
review + notarization docs. Flag sandbox-gated behaviors. Distinguish observed vs inferred.

## 7. Deliverable
1. Executive thesis. 2. **External-change detection + reconciliation** (D1 — headline). 3. Conflict +
durability model (D2). 4. Index consistency + self-heal (D3). 5. Vault lifecycle/bookmark harden (D4).
6. **The v1 release quality gate** (D5 — headline: checklist + automated harness + soak/upgrade
matrix). 7. **Build-schema solidification** (D6 — headline: the definitive {config → flag → surface →
signing → distribution} table + the base-app answer + the OpenChamber/ProAgent retirement + drift
guardrails). 8. **Performance + hardening floor** (D7 — headline: budgets + the per-release hardening
gate where a HIGH blocks ship). 9. Competitive table + novel edge (D8). 10. **Phased build order**
(durable write core → external detection → reconciliation → conflict UX → index self-heal → schema
collapse + OpenChamber retirement → perf/hardening floor → release gate), each with a witnessable
proven-done bar; flag Plan 6 (Capture writes) dependency. 11. Open questions.

## 8. Anti-patterns
No proprietary sync server. No design where the index can silently become authoritative. No silent
clobber of external edits. No "release-ready" claim without the automatable gate + data-safety soak
test. Don't regress the known vault repromp/disconnect fixes.

─── END RESEARCH BRIEF ───
