# LUMENLENS — Deliberate pre-build review (Claude, 2026-07-06)

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS
Reviewed: the owner's research wave (Integration Spine + Plan + Build Prompt — delivered as text,
NO spine code files this time), juxtaposed against the live repo across 3 verification cycles.
**Verdict: GO — with the amendments below, and with the missing spine authored in `spine/`** (the
wave's binding verdicts translated into skeletons, same treatment KEELSTONE got).

## A. What is genuinely good (keep exactly as designed)
- **Fork A** (first-party suggestion engine on `prosemirror-changeset` + provenance IDs, behind a
  swappable `SuggestionAdapter`, hwc mark schema as reference) — correct: neither library carries
  our provenance span (author/turn/rationale/accept-state), and changeset's arbitrary span metadata
  is the right substrate. Tiptap's paid-alpha tracked-changes correctly ruled out.
- **Fork B** (canonical-normalized round-trip + tiered harness + minimal-diff writeback; never
  reserialize the whole doc) — the DesktopCommander #440 corruption class as regression fixtures is
  exactly right for a git-tracked vault.
- **Fork D** (loadEpoch nonce + suppression + `filterTransaction`; never trust `emitUpdate`) —
  matches the repo's Tiptap **3.24.0**, where the v3 `emitUpdate` default flip + #1715/#4828 apply.
- The CI leak-detector matrix as *the proof* of gating, not the intent.
- OQ-1 (diff3 now, CRDT deferred with a named trigger), OQ-3 (one DB per vault + WAL caveat),
  OQ-4 (stale-bookmark re-auth; aligns with KEELSTONE's VaultBookmarkStore).

## B. Repo-reality amendments (all binding; found by juxtaposition)

### L1 — Gating must align with KEELSTONE's AppSurface (S1 amended)
`KINDRED_ENABLED` exists nowhere in the repo; the surface schema is KEELSTONE's
`EPISTEMOS_APP_STORE`/`EPISTEMOS_EXPERIMENTAL` (AppSurface + Guards 1–2). Amendments:
1. `KINDRED_ENABLED` is a **feature flag subordinate to the surface macro**: defined ONLY on the
   `Epistemos` (Experimental) target alongside `EPISTEMOS_EXPERIMENTAL`; never on AppStore; never
   in shared base (KEELSTONE §6 rule).
2. The research's guard `#if !KINDRED_ENABLED && <companion symbol> #error` is **not valid Swift**
   (`#if` cannot test symbols). The correct repo-proven pattern (see
   `ExperimentalRuntimeSupervisor.swift:1`): wrap companion files in `#if KINDRED_ENABLED … #endif`
   AND add the combo guard `#if KINDRED_ENABLED && EPISTEMOS_APP_STORE #error(…)`. Encoded in
   `spine/CompanionEditGate.swift`.
3. SwiftPM **package traits are OPTIONAL hardening, not the binding mechanism**: companion code
   lives in the app target today (`Epistemos/Models/Companion/`, `State/Companion/`,
   `ExperimentalAgent/`), not a package. Binding = target-scoped compilation condition + wrapped
   files + combo `#error` + CI row B (build `Epistemos-AppStore`, then `nm`/`strings` the binary
   and assert zero companion symbols). Traits can come later if companion code is ever packaged.

### L2 — Search already exists; OQ-2's verdict is behind reality
The repo ALREADY ships hybrid search: GRDB FTS (`SearchIndexService`) + the Rust `epistemos-shadow`
index (tantivy BM25 + usearch HNSW) + **RRF fusion** (`RRFFusionQuery.swift`, k=60, behind
`EPISTEMOS_RRF_FUSION_V1`). LUMENLENS does not build search — **P13 Phase 5 "Search (FTS5)" is a
wiring/verification task** against the existing stack (editor → index freshness → query). The
"FTS5 first, embeddings later" verdict stands only as *release-gating priority*, not as build work.

### L3 — The asset pipeline is already built; do NOT create `epdoc://`
`EpdocEditorBridge.swift` already implements the custom scheme (`epistemos-doc://`,
`epdocEditorURLScheme`) with server-side brotli decompression (`decompressBrotli`,
Compression.framework) — and `EpdocVisibilitySourceGuardTests` pins these symbols. P10/S4's pipeline
item is **done**; the only live caveat is the MAS `_registerURLSchemeAsSecure` prohibition, which
the existing design already respects (editor root loads via the scheme; no https↔scheme bridging).

### L4 — Fork D extends an existing gate; source-guard tests pin exact strings
`document-load-state.ts` with `markHostDocumentLoaded()`/`hasHostDocumentLoaded()` already exists
and is asserted by `EpdocVisibilitySourceGuardTests` (exact-string source guards, incl. the
`setContent(parsed, { emitUpdate: false })` load sequence). The epoch protocol **extends** this
module; any refactor must update the guard tests **deliberately in the same commit** — a green
build with failed source-guards is a blocked phase, not a nuisance.

### L5 — Fork C: the write-lease is justified, but the undo assumption is FALSE today
- Justified: two live editors on one note are real (window registry is one-per-note via
  `windows[page.id]`, but `GraphNotePage` embeds `NoteDetailWorkspaceView` independently → graph
  embed + window can coexist). The lease/follower model stands.
- FALSE assumption: "the WKWebView Tiptap instance is not torn down [on lens switch], so its
  history is preserved." Today `NoteDetailWorkspaceView` conditionally mounts the surface per
  `resolvedNoteMode` and `EpdocEditorChromeView.dismantleNSView` + `Coordinator.shutdown()`
  release the WKWebView. **Amendment:** Phase 2 must EITHER (a) retain the WKWebView per note
  session across lens switches (offscreen, one per lease; mind the memory budget — the repo
  deliberately reclaims 40–60 MB per closed editor), OR (b) accept documented undo-loss on lens
  switch for v1 and keep PM-JSON authority only. Explicit decision at Phase 2 start; (b) is the
  safe default; (a) is the better product. Do not assume (a) silently.
- Autosave: `EpdocEditorSavePipeline` (debouncer) + NSDocument autosave wiring already exist —
  Fork C's 800ms/5s policy CONFIGURES that pipeline; it does not add a second one.

### L6 — KEELSTONE is the hard dependency, and the seams are exact
KEELSTONE is reviewed (#1) but NOT yet built — `AtomicVaultWriter` etc. are docs skeletons. The
seams line up precisely and must be named in code:
- LUMENLENS **minimal-diff writeback** produces the new file content; the WRITE goes through
  KEELSTONE's `AtomicVaultWriter` (coordinate → temp → replace). Minimal-diff means *which bytes
  differ* (git-diff minimality), NOT partial file IO — the disk write is always the full buffer,
  atomically (L7).
- LUMENLENS's **note-session machine is the implementation of KEELSTONE's `ActiveEditorBridge`**
  (`activeRelativePath`/`baseHash`/`isDirty`/`reload`/`enterConflict`) — Fork C's Clean-reload /
  Dirty-conflict branches are that protocol, verbatim. One implementation serves both plans.
- Build order: KEELSTONE Phases 0–4 land before LUMENLENS Phases 1–2 build on them (owner is
  sequencing plans one at a time — KEELSTONE first is already the order; LUMENLENS's agent codes
  against the seam interfaces if any KEELSTONE piece is still pending).

### L7 — Minimal-diff writeback ≠ partial file IO (clarified in spine)
Splice touched-block output into the in-memory disk buffer, then write the WHOLE buffer atomically
via AtomicVaultWriter. Never seek-and-patch the file in place.

### L8 — Ledger state: in-memory Phase 1
`agent_core` `ClaimLedger` is in-memory (GRDB persistence is a later phase per project canon). The
per-span suggestion provenance therefore persists in a GRDB **editor-domain table**
(`spine/EditorProvenanceStore.swift`) with a `claim_id` linkage column for when the ledger gains
persistence — do not assume a Rust-side durable ledger exists today.

### L9/L10 — Lenses map to EXISTING implementations
Source lens = the **vendored MarkEdit CoreEditor (CodeMirror 6)** (`LocalPackages/MarkEdit`,
`MarkEditCoreEditorCoordinator.swift`) — the CM6 verdict lands by extending it; never add a second
CM6. Prose lens = the existing TextKit2 stack (`ProseEditorView` / `ProseTextView2`). Preview =
existing `NotePreviewSurfaceView`. Epdoc = existing `EpdocEditorChromeView` + `js-editor/`
(serializer home: `js-editor/src/markdown/epdoc-markdown-nodes.ts`; save path:
`MarkdownDocumentSurface.saveMarkdownDocumentSurfaceContent`). LUMENLENS hardens these; it
rebuilds none of them.

## C. The missing spine — authored in `spine/` (7 skeletons)
The wave shipped verdicts but no code. Authored from the binding decisions, KEELSTONE-style:
- `CompanionEditGate.swift` — L1's corrected gating (flag subordination, combo #error, Capabilities
  derived from AppSurface).
- `LensSessionCoordinator.swift` — Fork C machine + write-lease (GRDB `note_session`) +
  the KEELSTONE `ActiveEditorBridge` conformance seam + autosave policy constants.
- `EditorProvenanceStore.swift` — the per-span provenance schema (author/turn/ranges/before-after/
  rationale/source/accept-state) + retention/compaction sketch + `claim_id` linkage (L8).
- `suggestion-adapter.ts` — Fork A: the `SuggestionAdapter` interface, hwc-reference mark names,
  full provenance attrs, changeset wiring points.
- `load-epoch.ts` — Fork D: epoch counter + suppression window + `filterTransaction` guard,
  explicitly extending `document-load-state.ts` (L4 source-guard warning inline).
- `minimal-diff-writeback.ts` — Fork B: `changedRange` → touched-block reserialize → buffer splice
  (+ L7 atomic-write note + Tier A/B/C classification map).
- `RoundTripTierTests.swift` — the tiered harness skeleton with the four #440 corruption fixtures
  (frontmatter, GFM tables, wikilinks, spurious escapes) as named regression tests.

## D. Sequencing note for the owner
One agent for LUMENLENS (same reasoning as KEELSTONE: shared core, both targets) — but do NOT start
LUMENLENS Phases 1–2 until KEELSTONE Phases 0–4 are demonstrated; the write path and conflict
branches are KEELSTONE's. Phases 0 (gating) and 3 (ledger schema) of LUMENLENS can start anytime.
