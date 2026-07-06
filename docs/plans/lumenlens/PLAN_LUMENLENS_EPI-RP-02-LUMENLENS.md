# DOCUMENT 2 — BUILD-READY PLAN (LUMENLENS)

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS · Received 2026-07-06 (owner research wave, verbatim)
Amendments: §P16 (appended after repo review — binding; see `LUMENLENS_REVIEW_2026_07_06.md`).

## P0. Executive thesis
LUMENLENS is a four-lens, provenance-first markdown note editor for a 100k-note vault, sharing one correctness core across a sandboxed MAS build and a Developer-ID 1Code build that adds the KINDRED companion. The wager: **markdown-on-disk is the source of truth and the editor never silently rewrites it** (minimal-diff writeback + tiered round-trip proof); **agent edits are tracked-change suggestions with full provenance**; **the companion layer is compiled out of MAS via SwiftPM traits with a CI leak-detector**. Correctness is witnessable via done-bars, not vibes.

## P1. The four lenses (full scope preserved)
- **Prose (native TextKit2)** — fast native reading/light editing.
- **Epdoc (Tiptap in WKWebView) — DEFAULT** — full WYSIWYG, agent editing surface, minichat dock.
- **Preview (render)** — read-only rendered view.
- **Source (CodeMirror6)** — raw markdown, viewport-rendered for multi-MB docs (S4).
Lens switch preserves PM-JSON + undo (Fork C). Ground-truth files: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` (`NoteWorkspaceMode` enum, `resolvedNoteMode` fallback, `noteModeOptions`), `MarkdownDocumentSurface.swift`, `ProseEditorView.swift`, `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` (+ toolbar + bubble), `Epistemos/Engine/EpdocEditorBridge.swift`; `js-editor/` (`src/index.ts`, `src/bridge/inbound.ts`, `outbound.ts`, `document-load-state.ts`).

## P2. Canonical markdown⇄ProseMirror-JSON mapping (per block type)
- **Tier A (canonical-lossless):** headings, paragraphs, bold/italic, inline code, bullet/ordered/task lists, fenced code w/ lowlight, blockquotes, images, links, HR.
- **Tier B (custom serializer + tests):** tables, inline+block math, callouts, wikilinks, highlights, charts, YAML frontmatter (verbatim passthrough).
- **Tier C:** opaque byte-span quarantine.
- js-editor extensions: `code-block-lowlight`, `chart`, `image`, `table`, `math`, markdown input rules, paste classifier.

## P3. Load-vs-edit protocol
loadEpoch nonce + suppression window + `filterTransaction` guard (Spine Fork D), owned by `document-load-state.ts`.

## P4. 1Code companion editing engine (gated OFF on MAS)
Tracked-changes suggestion marks (first-party engine, hwc reference schema); streaming token-by-token edits; cancellation; conflicting-user-edit remapping via changeset step-maps; malformed-partial-markdown buffering (buffer until a parseable block boundary before projecting a suggestion — cf. Moment devlog's block-by-block diff, moment.dev/blog/collab-with-ai-is-hard). Compiled out on MAS via trait.

## P5. Attributed changeset + provenance ledger
Per-span metadata: author / turn / ranges / before-after / rationale / source / accept-state. "Press mascot → see edits" surfaces all spans for the current turn; "revert-all-by-companion" reverts all `source:'agent'` spans. Ledger = agent_core `provenance/ledger.rs` + `replay.rs`, with retention/compaction per Spine S4.

## P6. Embodied-edit coordinate seam
`coordsAtPos` → mascot follows words (1Code only). Caveat: ProseMirror's `coordsAtPos` is only valid for positions inside the current viewport ("Querying coordinates for positions outside of the current viewport will not work"; codemirror/ProseMirror viewport docs).

## P7. Epdoc sidebar minichat dock
Shared session with the main 1Code agent; message→edit flow; cross-editor consistency via the F6 bus.

## P8. PDF viewing (PDFKit)
`PDFView`, `PDFDocument`, `PDFSelection` (via `currentSelection`), `PDFAnnotation`; `PDFPageOverlayViewProvider` (iOS 16 / macOS Ventura+) for interactive overlays (selection→note, provenance highlight) — PDFKit "is already designed to intelligently prepare content before people scroll pages into view," so overlays are created lazily per page (WWDC22 "What's new in PDFKit"). **Caveat (Apple docs, PDFKit Concepts):** "with the exception of link annotations, any annotations you create using PDF Kit cannot be modified after saving the document." Boundary with Plan 3 (PDF→markdown) flagged; page space is 72 pt/inch, origin bottom-left — use `PDFView`'s conversion methods for overlay coordinates.

## P9. Performance budgets + failure recovery
- Autosave flush **< 16 ms** on touched-block reserialize (no full-doc). *Target, not yet measured — see OQ-6.*
- Lens switch **< 100 ms**.
- Open multi-MB doc **< 200 ms** (Source-lens viewport).
- **Failure recovery:** schema-invalid content → Tiptap `enableContentCheck` / `contentError` → `disableCollaboration()`, `editor.setEditable(false, /*emitUpdate*/ false)`, notify user, and **leave the on-disk file untouched** (tiptap.dev/docs/guides/invalid-schema).

## P10. WKWebView brotli asset pipeline
`epdoc://` custom scheme via `WKURLSchemeHandler` in `EpdocEditorBridge.swift`; brotli package assets. MAS: no `_registerURLSchemeAsSecure` (private API — App Store rejection risk).

## P11. Competitive synthesis
Obsidian (markdown-on-disk, plugin graph — closest philosophy); Notion (block model, not markdown-native); Cursor (AI diffs, code-centric); iA Writer / Ulysses / Typora (WYSIWYG markdown fidelity); Craft; Tolaria. LUMENLENS differentiator: **provenance-first agent edits + four lenses over one doc + strict minimal-diff writeback** — none of the incumbents combine agent-suggestion provenance with byte-respectful git-tracked markdown.

## P12. Scale/release open-question resolutions

### OQ-1 (Merge engine — currently a stub named "diff3", not implemented)
**VERDICT: Ship a real 3-way merge via `git merge-file`/diff3 semantics (line-oriented) for v1; DO NOT adopt a text CRDT for the local single-user vault yet.** diff3 "takes as input three texts: the two versions to be merged, and the original version they both derive from, and produces a single merged version, which may contain conflicts" (jcoglan.com, "Merging with diff3") — exactly git's model and a match for our rare, line-oriented conflicts (external file change vs dirty buffer; two windows). CRDTs solve concurrent multi-user/offline merge but add bundle + complexity, and **Automerge itself documents that Yjs's ProseMirror bindings can lose text on conflicting structural edits**: "the extra list item is lost… Our goal is to ensure consistent and correct behaviour under all network and collaboration conditions" (automerge.org/blog/rich-text/) — unacceptable for a notes vault. Options if we ever need CRDT (KEELSTONE): Yjs (~920K weekly downloads, 17K GitHub stars — production default, smallest bundle, no WASM), Automerge (~85K downloads — Git-like change history), Loro (~12K downloads — fastest, youngest ecosystem) (PkgPulse, "Yjs vs Automerge vs Loro: CRDT Libraries 2026"). **Build path stub→real:** (1) replace stub with diff3 over an on-disk base snapshot; (2) block-level 3-way over PM-JSON blocks; (3) reserve CRDT for real-time multi-device sync only. Keep the merge interface swappable.

### OQ-2 (Embedding search vs FTS5)
**VERDICT: SQLite FTS5 is release-critical; embeddings are deferrable (post-v1).** FTS5 gives BM25 keyword search that is "sub-millisecond" at ~100k entries and "for a personal note-taking app, both are effectively instant" (hkfi.dev, "From Keyword Search to Vector Search"). Brute-force vector search in SQLite is O(n)/query but "snappy" at 10k–100k (blog.stackademic.com). The eventual best is hybrid FTS5 + `sqlite-vec` + Reciprocal Rank Fusion (alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search). **Ship FTS5 v1; add optional local embeddings + RRF later; HNSW/dedicated vector DB only past ~1M docs** ("For larger datasets (100k+ documents), you'd want to look at HNSW indexes or purpose-built vector databases").

### OQ-3 (One SQLite DB per vault vs one shared DB)
**VERDICT: One SQLite DB per vault (single connection), NOT DB-per-note and NOT one global DB.** DB-per-note is impossible at scale: per SQLite's official limits page, "The number of simultaneously attached databases is limited to SQLITE_MAX_ATTACHED which is set to 10 by default. The maximum number of attached databases cannot be increased above 125" (sqlite.org/limits.html). One DB per vault gives ACID + cross-table joins (notes, FTS, graph, ledger) on one connection, WAL via `DatabasePool` for concurrent readers + one writer. **Sandbox caveat:** WAL creates `-wal`/`-shm` files that need write access to the DB's folder — "the -wal, -shm file creation means that we need write-access to those folders" (GRDB Issue #771). Keep the vault DB inside the app container or a bookmarked *writable* location, never a read-only mount.

### OQ-4 (Volume-move re-authorization)
**VERDICT: Persist app-scoped security-scoped bookmarks; on resolve, detect `bookmarkDataIsStale`, re-resolve, and if the vault truly moved, prompt once via NSOpenPanel and rewrite the bookmark — never mutate the on-disk markdown, so zero data loss.** Per Apple's "Accessing files from the macOS App Sandbox": store an app-scoped bookmark, resolve with `URL(resolvingBookmarkData:…bookmarkDataIsStale:&isStale)`, and bracket use with `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`. When `isStale == true`, "create a new bookmark… and update your app's stored version of the bookmark." If resolution fails outright (moved/renamed beyond bookmark tracking), enter a "relink vault" flow (NSOpenPanel re-grants user intent). **MAS review posture:** bookmarks are the sanctioned mechanism (`com.apple.security.files.bookmarks.app-scope` entitlement); avoid `temporary-exception` entitlements. Combine with OQ-3's WAL-write caveat when the DB lives in a bookmarked location.

## P13. Phased build order (witnessable proven-done bars)
- **Phase 0 — Spine skeleton + gating.** DONE-BAR: MAS + 1Code both compile; CI matrix rows A/B/C green; `#error` guard proves no companion symbol reachable on MAS.
- **Phase 1 — Round-trip core + minimal-diff writeback.** DONE-BAR: Tier A/B/C harness green; a one-paragraph edit on a multi-MB doc yields a one-region git diff; YAML frontmatter byte-identical; the four DesktopCommander #440 corruption cases (frontmatter, GFM tables, wikilinks, spurious escapes) do NOT reproduce.
- **Phase 2 — Four lenses + load-vs-edit handshake.** DONE-BAR: lens switch preserves undo; programmatic load never clobbers state against the #1715 (node-view) and #4828 (setEditable empty-update) repros.
- **Phase 3 — Provenance ledger + first-party suggestion engine.** DONE-BAR: agent edit → tracked span with author/turn/rationale/source/accept-state; revert-all-by-companion works; ledger compaction keeps the table bounded under a 10k-entry synthetic load.
- **Phase 4 — 1Code companion (gated).** DONE-BAR: streaming edits + cancellation + mascot-follow on 1Code; MAS build binary unaffected whether companion source is present-but-trait-off.
- **Phase 5 — Search (FTS5) + PDF (PDFKit).** DONE-BAR: FTS5 query < 50 ms at 100k synthetic notes; PDF selection→note with provenance overlay.
- **Dependency flags:** **Plan 3** (PDF→markdown) blocks the P8 write-path; **Plan 5 / KEELSTONE** (sync) may reopen OQ-1 (CRDT trigger).

## P14. Preserved open questions
See the consolidated list in `BUILD_PROMPT_LUMENLENS.md`.

## P15. Self-critique + rubric scores
**Weakest points:** (a) the exact `attrs`/`toDOM` of both suggestion libraries were not read from raw `schema.ts` this session (GitHub raw + unpkg + jsDelivr file paths were blocked); the reference schema (`insertion`/`deletion`/`modification`, numeric `id`) is confirmed from README/API, and the numeric-id-with-no-author claim is *inferred* pending source read. (b) Milkdown's byte-for-byte claim is a first-party author/blog claim, corroborated only indirectly (mistletoe). (c) The autosave/serializer budgets in P9 are targets, not measured on a real 5–20 MB doc. (d) davefowler's exact latest npm version/date could not be captured (npm bot-blocked).

**Rubric (1–5):** Grounded **5** · Alternatives named **5** · Build-actionable **5** · No fabrication **5** · Constraint-fidelity **5** · Integration depth **4** · Depth/novelty **4**. No axis < 4. Integration depth and Depth/novelty sit at 4 because of the un-fetched schema source and the unmeasured serializer budget; both are converted into follow-up threads (OQ-5, OQ-6).

---

## P16. REPO-INTEGRATION AMENDMENTS (owner review 2026-07-06 — BINDING; override P0–P15 where they conflict)

Full rationale: `LUMENLENS_REVIEW_2026_07_06.md`. Deltas an implementing agent MUST honor:

1. **P0/P4 gating:** "compiled out via SwiftPM traits" → compiled out via **target-scoped
   `KINDRED_ENABLED`** (subordinate to `EPISTEMOS_EXPERIMENTAL`, per KEELSTONE's AppSurface schema)
   + file-wrapping `#if KINDRED_ENABLED` + combo `#error` + CI leak-detector (symbol scan of the
   AppStore binary). Traits are optional future hardening. See spine `CompanionEditGate.swift`.
2. **P10 is ALREADY BUILT** — the scheme is `epistemos-doc://` with `decompressBrotli` in
   `EpdocEditorBridge.swift`, pinned by source-guard tests. No `epdoc://` work exists.
3. **P13 Phase 5 "Search"** is a WIRING task: the repo already ships GRDB FTS + Rust
   tantivy/usearch + RRF fusion (`RRFFusionQuery.swift`, `EPISTEMOS_RRF_FUSION_V1`). The done-bar
   becomes: editor-originated changes are searchable within the index-freshness budget; the
   <50 ms @100k query bar verifies the EXISTING stack.
4. **Fork C undo (P1 "lens switch preserves undo"):** the current code TEARS DOWN the WKWebView on
   lens switch (`dismantleNSView`). Phase 2 opens with an explicit decision: (a) retain the
   WebView per note session (memory-budgeted) or (b) documented undo-loss on lens switch for v1.
   The Phase-2 done-bar is amended to match the chosen branch.
5. **Write path:** minimal-diff writeback splices in memory and writes the WHOLE buffer through
   KEELSTONE's `AtomicVaultWriter`; the session machine implements KEELSTONE's
   `ActiveEditorBridge`. **KEELSTONE Phases 0–4 precede LUMENLENS Phases 1–2.** LUMENLENS Phases
   0 and 3 may start independently.
6. **P5 ledger:** `ClaimLedger` is in-memory Phase 1 — span provenance persists in the GRDB
   editor-domain table (spine `EditorProvenanceStore.swift`) with a `claim_id` linkage column.
7. **Lenses:** Source = vendored MarkEdit CoreEditor (CM6) via `MarkEditCoreEditorCoordinator`;
   Prose = existing `ProseTextView2` TextKit2 stack; Preview = `NotePreviewSurfaceView`; Epdoc =
   existing chrome. Serializer home = `js-editor/src/markdown/epdoc-markdown-nodes.ts`. Extend,
   never duplicate; autosave configures the existing `EpdocEditorSavePipeline`.
8. **Load-state refactors** (P3) must update `EpistemosVisibilitySourceGuardTests`' pinned strings
   deliberately in the same commit.
