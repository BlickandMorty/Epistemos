# LUMENLENS — Review V2 (Claude, 2026-07-06) — the dual-wave redo

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS
Supersedes `LUMENLENS_REVIEW_2026_07_06.md` (V1) where they differ; V1 remains the record of the
first wave. Reviewed: the redone plan + prompt + 15-file spine (dual wave with KINDRED), juxtaposed
against the live repo via the 5-auditor fan-out. **Verdict: GO — with the amendments below.**

## A. What the redo fixed (V1 amendments absorbed — credit where due)
- Brotli decode server-side + no `_registerURLSchemeAsSecure` on MAS is now IN the prompt (L0).
- The invalid `#if !FLAG && <symbol>` guard is gone; K-side gating moved to file-wrapping.
- hwc adopted as *reference schema* for a first-party engine (matches V1's Fork A framing).
- Done-bars are witnessable; NoopSuggestionAdapter swap test added; #440 corruption fixtures kept.
- The embodied-edit seam, minichat dock, and provenance schema are now explicit LUMENLENS↔KINDRED
  external interfaces with a shipping order.

## B. What still needed correction (V2 binding amendments — in the plan appendix + spine headers)

### B1 — SwiftPM traits: REFUTED for this repo; the real mechanism ALREADY LANDED
No root `Package.swift` exists (only LocalPackages/*); the app is two xcodegen targets; Xcode's
package integration has no per-target trait selection. The "locked" traits verdict is **struck**.
The real mechanism is target-scoped `SWIFT_ACTIVE_COMPILATION_CONDITIONS` — and it **shipped in
KEELSTONE commit `8a1ca87d1`**: `KINDRED_ENABLED`+`EPISTEMOS_EXPERIMENTAL` on all Epistemos-target
configs, absent from AppStore, with `AppSurface.swift` `#error` guards. Plan OQ3 → CLOSED as moot.
`spine/Package.swift.NOT-APPLICABLE` + `spine/ci-matrix.REFERENCE.yml` carry the re-mapping (the
repo has REAL CI — 5 workflows incl. ci.yml on macos-15 — implement the leak detector as a job
there: build `Epistemos-AppStore` + nm/strings scan for companion symbols).

### B2 — The emitUpdate:false ban collides with a pinned guard test — reworded
`EpdocVisibilitySourceGuardTests.swift:270` pins the EXACT loader block **including**
`setContent(parsed, { emitUpdate: false })` as a multiline literal. The live loader uses the flag
correctly (as a belt). Amendment: the ban is on **relying** on `emitUpdate:false` for correctness —
the epoch/`filterTransaction` guard is the correctness layer; keep the flag at the load site; any
loader reflow updates the pinned guard test IN THE SAME COMMIT.

### B3 — document-load-state.ts: EXTEND the live 14-line module
The live file is the boolean gate (`hostDocumentLoaded` + mark/has functions) consumed by
index.ts:55 and inbound.ts:15. The spine's Plugin-based file LAYERS the epoch protocol onto it —
never deletes the existing exports (guard tests pin them: :272-277).

### B4 — Dependency reality for L1
`prosemirror-changeset` **2.4.1 is already installed** (js-editor/package.json:65).
`@handlewithcare/prosemirror-suggest-changes` is **NOT installed** — L1 starts with an `npm add`
(reference adapter) or implements the marks first-party per the locked verdict. All @tiptap/* are
3.24.0 (Fork D's v3 semantics apply); PM access via @tiptap/pm.

### B5 — The serializer to extend EXISTS
PM-JSON→markdown already runs through the vendored `@tiptap/markdown` pipeline +
`js-editor/src/markdown/epdoc-markdown-nodes.ts` `renderMarkdown` hooks (wikilinks already
round-trip `[[target]]` via EpdocLink — #440-3 partly defended today), invoked via
`editor.getMarkdown()`; a `check:markdown-roundtrip` script exists. Tier A/B/C hardens THIS
pipeline; no new serializer. (Also: the js-editor toolchain is **webpack 5**, not esbuild — the
repo CLAUDE.md is stale.)

### B6 — Three spine files are DELTA contracts over big live files (renamed *.DELTA.swift)
`EpdocEditorChromeView` (~1000+ live lines, autosave pipeline, guard-pinned),
`MarkdownDocumentSurface` (live, guard-pinned save path), `EpdocEditorBridge` (live scheme
**`epistemos-doc://`** + decompressBrotli — the skeleton's `epdoc://` is WRONG). The skeletons
express additions only; never replace the live file. Headers mark this.

### B7 — KEELSTONE seams (carried from V1, still absent from the redo's text)
The write path goes through KEELSTONE's `AtomicVaultWriter` (whole-buffer atomic; splice in
memory); `NoteSessionStateMachine` IS the `ActiveEditorBridge` implementation (seam header ported
onto the spine file); the `note_session` lease row joins the EXISTING per-vault GRDB (never a
second DB); KEELSTONE Phases 0–4 precede L3/L4. Fork C's follower model is justified by repo
reality (window registry is one-per-note, but GraphNotePage embeds the workspace independently).

### B8 — Ledger placement (V1 L8, refined by the audit)
`ClaimLedger` is in-memory Phase 1 — but it ALREADY carries the idiom to copy: append-only
`events: Vec<LedgerEvent>` + monotonic sequence (ledger.rs:443-456), `events_since()` cursor
(:512), `snapshot()`→ReplayBundle (BLAKE3, FFI-exported). `suggestion_schema.rs` adds Suggestion
as a parallel event stream using THAT pattern; the DURABLE side persists in the GRDB editor-domain
table (`spine/EditorProvenanceStore.swift`, kept from V1) with `claim_id` linkage.

### B9 — Undo-across-lens-switch (V1 L5, still open)
The live code tears down the WKWebView on lens switch (`dismantleNSView`). L4 opens with the
explicit decision: retain-per-session (memory-budgeted) vs documented v1 undo-loss. Autosave
CONFIGURES the existing `EpdocEditorSavePipeline`; never a second pipeline.

## C. Spine reconciliation (what superseded what)
V2 spine adopted wholesale; from the V1 authored spine, **kept**: `EditorProvenanceStore.swift`
(GRDB durable side — no V2 equivalent), `RoundTripTierTests.swift` (Swift-side harness — no V2
equivalent). **Superseded + removed**: LensSessionCoordinator.swift (→ NoteSessionStateMachine +
ported seam header), load-epoch.ts (→ document-load-state.ts), minimal-diff-writeback.ts v1 (→
serializer version), suggestion-adapter.ts v1 (→ SuggestionAdapter.ts). **Moved**:
CompanionEditGate.swift → `../kindred/spine/` (it was always KINDRED's). Full map:
`SPINE_MANIFEST.md`.
