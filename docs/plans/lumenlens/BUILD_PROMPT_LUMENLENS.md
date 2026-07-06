# DOCUMENT 3 — BUILD PROMPT (LUMENLENS)

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS · Received 2026-07-06 (owner research wave, verbatim)
**READ THE "REPO REALITY ADDENDUM" AT THE BOTTOM FIRST — it binds like the phase list.**

### Doubles as a proposal for reviewing agents to vet AND an instruction set for a coding agent (Claude Code)

## Instructions to the coding agent (Claude Code) — build phase by phase
You are building LUMENLENS (EPI-RP-02-LUMENLENS). Stack: Swift 6 + Rust agent_core + GRDB + WKWebView + Tiptap/ProseMirror + CodeMirror6 + PDFKit, Apple Silicon. Two builds: MAS (sandboxed, no subprocess, no KINDRED) and 1Code (Developer ID, all features).

**Phase 0 — Gating seam.** Define `KINDRED_ENABLED` in Active Compilation Conditions on the 1Code target only. Put all companion code in a SwiftPM target behind a package trait so it gates *out of the build*, not just at runtime. Add `#if !KINDRED_ENABLED && <companion symbol> #error(...)`. Stand up the CI matrix: row A (defaults), row B (`--disable-default-traits`, the leak detector), row C (defaults + KINDRED, anti-rot). DONE when all three compile and MAS contains no companion symbol.

**Phase 1 — Round-trip + minimal-diff writeback.** Implement the Tier A/B/C harness and minimal-diff writeback using `prosemirror-changeset` `changedRange`: reserialize only touched blocks; preserve line endings/indent/list markers elsewhere; YAML frontmatter verbatim passthrough. Use prosemirror-markdown options (`tightLists`, `escapeExtraCharacters`, `strict`) deliberately. DONE when a one-paragraph edit on a multi-MB file yields a one-region git diff and the DesktopCommander #440 corruption cases do NOT reproduce.

**Phase 2 — Lenses + load-vs-edit.** Build the four lenses and the loadEpoch/suppression-window/`filterTransaction` handshake in `document-load-state.ts`. DONE when the #1715 and #4828 repros cannot clobber state.

**Phase 3 — Ledger + suggestion engine.** Provenance ledger (`ledger.rs`/`replay.rs`) + first-party suggestion engine behind `SuggestionAdapter` (default schema = hwc `insertion`/`deletion`/`modification` marks + the doc-node block-mark trick). Per-span metadata: author/turn/ranges/before-after/rationale/source/accept-state. DONE per P13 Phase 3.

**Phase 4 — Companion (gated).** Streaming via chunked token application at block boundaries; cancellation; conflict remap via changeset step-maps; malformed-partial buffering. DONE when the MAS binary is unchanged with the companion trait off.

**Phase 5 — Search + PDF.** FTS5 (BM25) + PDFKit (`PDFPageOverlayViewProvider`, honoring the annotation-immutable-after-save caveat). DONE per P13 Phase 5.

## Reviewing agents — pressure-test these named assumptions
1. **Fork A:** Is a first-party engine justified vs adopting `@handlewithcare/prosemirror-suggest-changes` wholesale? Fetch `src/schema.ts` of both libraries and confirm exact `attrs`/`toDOM`. Does hwc's numeric-id model + our ledger beat davefowler's `username`+`data` model for our provenance needs?
2. **Fork B:** Independently reproduce or refute Milkdown's byte-for-byte claim on a corpus including GFM tables, wikilinks, and frontmatter. Measure our minimal-diff writeback on a 5 MB doc.
3. **Fork C:** Stress the write-lease handoff with two windows editing the same note; does the shared undo stack + `source` tagging reconcile correctly on lens switch?
4. **Fork D:** Confirm current Tiptap v3 `setContent`/`emitUpdate`/`setEditable` semantics against the latest release; does the epoch guard fully survive #1715/#4828?
5. **OQ-1:** Is diff3 sufficient, or does multi-window editing already demand a CRDT? Quantify conflict frequency.
6. **OQ-3:** Validate WAL `-wal`/`-shm` write-access behavior in the MAS sandbox for a bookmarked vault location.
7. **OQ-4:** Test a moved-vault + stale-bookmark scenario end-to-end; confirm zero data loss and a clean re-auth.

## Embedded open-ended research questions for the agents
- What is the real memory/CPU cost of `prosemirror-changeset` diffing on multi-MB docs during live streaming?
- Does CodeMirror6 viewport rendering interact badly with Source-lens provenance decorations at multi-MB scale?
- Can `PDFPageOverlayViewProvider` be reconciled with the "annotations immutable after save" caveat for persistent provenance overlays (or must overlays be re-derived on each open)?

## CONSOLIDATED OPEN RESEARCH QUESTIONS (sharp, answerable threads)
1. **Merge engine:** diff3 vs block-level 3-way vs CRDT — quantify multi-window/offline conflict frequency and define the concrete trigger threshold to adopt Yjs/Automerge/Loro (KEELSTONE dependency).
2. **FTS5 vs embeddings:** at what vault size and query type does FTS5-only recall degrade enough to require hybrid RRF? Measure semantic-query recall at 100k notes.
3. **DB-per-vault vs shared:** confirm WAL sandbox write-access + ATTACH-DB archival-compaction interplay at 100k notes + high ledger volume.
4. **Volume-move re-auth:** end-to-end stale-bookmark + moved-vault test; finalize the MAS review posture on bookmark entitlements.
5. **Suggestion-lib schema:** fetch the actual `schema.ts` of `@handlewithcare/prosemirror-suggest-changes` and `davefowler/prosemirror-suggestion-mode` for exact `attrs`/`toDOM` to lock the `SuggestionAdapter` default.
6. **Serializer budget:** measure minimal-diff writeback latency on 5–20 MB docs to confirm (or revise) the < 16 ms autosave budget.
7. **Streaming performance:** changeset diff cost during token streaming, and the boundary heuristics for malformed-partial-markdown buffering.

---

## REPO REALITY ADDENDUM (read FIRST — verified against the live repo 2026-07-06)

These amend the phases above per plan §P16 / spine §S5 and bind like the phase list. The audited
spine skeletons live in `docs/plans/lumenlens/spine/` — use THOSE as your starting points.

1. **Phase 0 corrected.** There is no SwiftPM companion package and no `KINDRED_ENABLED` today.
   Do: add `KINDRED_ENABLED` to the `Epistemos` target's `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in
   the real `project.yml` (all its configs), NEVER to `Epistemos-AppStore`, NEVER to shared base —
   this rides on KEELSTONE's macro-scoping work (its §15.1). The `#if !FLAG && <symbol>` guard in
   Phase 0 is invalid Swift; use the pattern in `spine/CompanionEditGate.swift` (file-wrapping
   `#if KINDRED_ENABLED` + `#if KINDRED_ENABLED && EPISTEMOS_APP_STORE #error`). CI row B =
   build `Epistemos-AppStore` and assert zero companion symbols (nm/strings scan). SwiftPM traits:
   optional later; not the mechanism now. Then `xcodegen generate` — never hand-edit the pbxproj.
2. **Phase 1 write path.** Splice in memory; write the WHOLE buffer atomically via KEELSTONE's
   `AtomicVaultWriter` (docs/plans/keelstone/spine/). **KEELSTONE Phases 0–4 must be landed first**
   — if they aren't, stop and surface it. Your session machine implements KEELSTONE's
   `ActiveEditorBridge` protocol; see `spine/LensSessionCoordinator.swift`.
3. **Phase 2 amendments.** (a) The four lenses EXIST — Prose=`ProseTextView2` (TextKit2),
   Epdoc=`EpdocEditorChromeView`+js-editor, Preview=`NotePreviewSurfaceView`, Source=vendored
   MarkEdit CoreEditor (CM6, `MarkEditCoreEditorCoordinator`). You harden and wire; you do not
   rebuild. (b) The load-vs-edit gate EXISTS (`document-load-state.ts`,
   `markHostDocumentLoaded`) — extend it with the epoch protocol per `spine/load-epoch.ts`.
   (c) `EpistemosVisibilitySourceGuardTests` pins exact strings around this code — update the
   guards deliberately in the same commit as any refactor. (d) "Lens switch preserves undo" is NOT
   currently true (the WKWebView is torn down on switch). Open Phase 2 with the explicit decision:
   retain-per-session (memory-budgeted) vs documented v1 undo-loss; amend the done-bar to match.
4. **Phase 3 ledger.** `ClaimLedger` is in-memory Phase 1. Persist span provenance in the GRDB
   editor-domain table per `spine/EditorProvenanceStore.swift` (with `claim_id` linkage). Do not
   build against a durable Rust ledger that doesn't exist yet.
5. **Phase 5 search.** Hybrid search ALREADY EXISTS (GRDB FTS + Rust tantivy/usearch + RRF fusion
   behind `EPISTEMOS_RRF_FUSION_V1`). Phase 5's search half is wiring + verification (editor
   changes searchable within freshness budget; <50 ms @100k verifies the existing stack).
6. **Asset pipeline.** Already built: `epistemos-doc://` + `decompressBrotli` in
   `EpdocEditorBridge.swift` (source-guard-tested). No `epdoc://` work.
7. **Build discipline.** Isolated DerivedData; BUILD SUCCEEDED on BOTH targets per phase; never two
   xcodebuilds at once; commit per green step with pathspec-scoped commits
   (`git commit --only -- <files>`); never commit `.research-clones/`; no worktrees.
