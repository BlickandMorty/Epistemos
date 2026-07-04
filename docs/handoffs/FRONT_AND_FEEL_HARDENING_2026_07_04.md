# Front & Feel Hardening — Session 2026-07-04 (unbounded agent)

Scope: landing/Metal/wake-field, browser, notes, Epdoc/KaTeX, meeting, onboarding. Excludes
Goose, AI agents/June, OpenChamber. All fixes below are **build-verified** (Debug/Epistemos,
isolated DerivedData) and committed; nothing here is an unverified completion claim.

## Fixes landed (commit — what)

- `6fbb052fd` / `bed7b1080` / `b12b41266` — **landing+graph perf regression (HIGH)**. Root cause
  (confirmed by two independent investigators + code read): `MetalGraphView.deinit` ran a
  synchronous `group.wait()` ON THE MAIN THREAD (draining detached embedding tasks before engine
  destroy), which stalled *every* main-thread-driven surface — the graph AND the landing's Metal
  `TimelineView` — amplified 10-50× by the Debug `-Onone` Run scheme and re-fired on every view
  recreation. Fix: `EmbeddingService.drainAndDestroyEngineOffMain(_:)` drains + destroys off-main;
  main-thread deinit returns instantly; UAF-safety preserved. Also restored the graph-clustering
  parallelism a concurrency-safety lock had defeated (per-instance `NLContextualEmbedding` pool).
  Owner confirmed resolved on a Release build.
- `596e73cf1` / `6cd571df2` — **FSRS spaced-repetition review (opt-in)**, owner-approved. Was a
  live consumer with no producer + no persistence. Now: dedicated `fsrs.sqlite` (survives
  relaunch), bootstrap call, both import paths (arXiv + PDF) enroll behind
  `@AppStorage("epistemos.fsrs.autoEnroll")` (default OFF), Settings → Review toggle. Ships dark
  until the user opts in.
- `21aa308da` / `9f5025a84` — **unbounded main-thread file reads** (freeze/OOM on a large or
  malicious file): HexViewer (whole-file read + Rust FFI on `.onAppear`) and ProseTextView2 image
  paste. Both now size-guarded (50 MB / 20 MB), matching EpdocEditorToolbar's existing cap.
- `c9b42c217` — **HC-2/HC-3**: HaloController's per-keystroke `extractQueryContext` did two O(n)
  full-doc operations; now bounded to the trailing 2048 chars (O(1)/keystroke).
- `2a71824b9` (ARX-UX-1 stale category chip) · `320761a2e` (SS-2 trimmed FFI query) ·
  `9445bf565` (ARX-DEAD-2 dead wrapper) · `9eea6a53a` (SkillEvolutionView nav) ·
  `ecf719534` (browser download cancel) · `29fd7b891` (DATA-IMPORT-1 child-context, UNVERIFIED
  headless — needs an in-app import spot-check) · `f3ca719df` (transcript-loss guard).

## Verified-clean hardening axes (Front & Feel surfaces)

Systematic sweeps, each found clean (or fixed above):
1. Unbounded file reads — 2 gaps fixed; EpdocEditorToolbar already guarded.
2. Synchronous main-thread blocks (`.sync`/`group.wait`/`semaphore.wait`) — the graph deinit was
   the only one; now off-main.
3. Crash vectors (`try!`/`as!`/`fatalError`) — clean; the one `preconditionFailure` (OutlineParser)
   is an unreachable dev-guard on hardcoded regex constants, not user input.
4. Web→native bridge (boundary B1) — every message handler cast-guards name + payload; the Epdoc
   asset write uses a generated `image-<contenthash>.<ext>` key + allowlisted extensions + dict
   storage (no path traversal); read side rejects traversal.
5. Observer/timer leaks — clean; CodeEditorView is selector-based (auto-removed), NoteWindowManager
   block observers are centrally cleaned (handleWindowClose + resetForVaultRebuild).
6. Deep-link / custom-URL-scheme — no `epistemos://` handler exists; only the Spotlight continuation
   (opens a note by the app's own donated pageId, graceful on miss). No unvalidated entry.

## Deferred — DOCUMENTED, not unpatched-and-undocumented

- **#41 DataviewService renderer / #42 EpdocBlockTemplateStore→slash-menu** — Epdoc **feature-builds**,
  not wires. The slash insert is a JS `blockType` contract (`insertSlashChoice`) with no path for
  arbitrary template/DQL content, so both need a new Tiptap JS node/handler + a
  `build-tiptap-bundle.sh` rebuild (npm) + WKWebView **runtime** verification not possible headless.
- **#40 Recall "Open Chat"** — needs the off-limits chat-navigation mount.
- **#46 VaultIndexActor FTS-delete restructure** — most-critical data path; test suite is
  Goose-blocked, so it would ship build-verified but NOT test-verified. Audit deliberately defers.

## Owner decisions to unblock further progress
(a) OK the JS-bundle feature-builds (accepting runtime verification is yours), (b) authorize the
Vault restructure build-verified-only, or (c) open the chat-nav mount. Absent these, the
trust-critical Front & Feel surfaces are in strong shape.
