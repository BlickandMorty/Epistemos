# DOCUMENT 1 — INTEGRATION SPINE (LUMENLENS)

ID: EPI-RP-02-LUMENLENS · Codename: LUMENLENS · Received 2026-07-06 (owner research wave, verbatim)
Amendments: §S5 (appended after repo review — binding; see `LUMENLENS_REVIEW_2026_07_06.md`).

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. This spine is active
> for MAS editor correctness only. The older 1Code/KINDRED gating research remains
> provenance and leak-check material, not an active build target.

### The shared architectural contract every future editor plan plugs into, hardened for scale

## S0. Purpose & scale invariants (binding)
The Spine is the contract the MAS editor plan plugs into. Active target:
- **MAS** (Mac App Store, sandboxed, no subprocess): full multi-lens editor + June agent capabilities. **NO** KINDRED companion presence/streaming layer.
- **1Code / Experimental**: parked by the 2026-07-07 MAS-only pivot; keep only as historical leak-check provenance.

Scale invariants (all binding, all cited in S4):
- **SI-1** Vault = 100k+ notes/files; individual docs multi-MB markdown.
- **SI-2** Provenance ledger has a real retention/compaction/archival story — never an append-forever table.
- **SI-3** Graph writes must not choke at a 100k-note vault.
- **SI-4** Round-trip serializer fast enough that autosave on a huge doc never hitches.
- **SI-5** State/event bus must not become a bottleneck.
- **SI-6** GRDB indexing strategy is explicit.

## S1. Parked companion gating seam — provenance + MAS leak check

Swift has no C-style preprocessor macros; it uses `#if` conditional compilation driven by the `SWIFT_ACTIVE_COMPILATION_CONDITIONS` build setting, and the compiler *physically removes* non-matching branches from the binary — so no dead companion code path is reachable on MAS (Swift by Sundell, "Using compiler directives in Swift", swiftbysundell.com/articles/using-compiler-directives-in-swift/; Reintech, "How to use Swift's #if compiler", reintech.io/blog/mastering-swifts-if-compiler-directives: "the compiler literally removes code branches that don't match your conditions—they won't exist in your compiled binary"). SwiftPM 6.1+ *package traits* go further: a trait "makes `#if TraitName` valid in source, and it can gate dependency targets out of the build… By the time your binary runs, the trait has already shaped what SwiftPM prepared for compilation" (Tomasz Kubiak, "Build-Time Feature Flags with SwiftPM Package Traits + CI Matrix", medium.com/@tomasz.kubiak.dev/build-time-feature-flags-with-swiftpm-package-traits-ci-matrix-9b42d190df77).

Active MAS-only design:
1. Do not define `KINDRED_ENABLED` for active MAS work.
2. All parked companion code remains absent from `Epistemos-AppStore`.
3. CI/leak proof builds `Epistemos-AppStore` and asserts zero companion/presence symbols.
4. Runtime MAS UI derives capability truth from June/agent_core state, not from hidden companion flags.

Rationale for choosing compile-time over runtime gating: Kubiak documents a real shipped App Store incident where an internal debug overlay leaked into a Release build because a gate was rewritten `#if DEBUG || INTERNAL` and "CI stayed green because it ran `-configuration Release` with no custom flags. The developer's local scheme was not CI's scheme." Loose/runtime gating is a genuine review-and-leak risk; compile-time + a CI matrix is the auditable path that satisfies the owner's "no leak of 1Code-only features onto MAS" requirement.

## S2. Per-seam ownership (Deep Fabric F1–F6) — BINDING
| Seam | Owner (language/module) | Scale note |
|---|---|---|
| **F1 Vault bus** | native Swift (GRDB) | file watch, security-scoped bookmarks, write-lease |
| **F2 Agent capability registry** | agent_core (Rust) | June is the active MAS driver |
| **F3 Status/provenance** | native/agent_core state | Kindred companion presence is parked; MAS asserts zero presence symbols |
| **F4 Knowledge graph** | agent_core (Rust) + GRDB | 100k-note batched writes, short txns |
| **F5 Provenance/citation** | agent_core `provenance/ledger.rs` + `replay.rs` | retention/compaction (S4) |
| **F6 State/event bus** | native Swift | debounced, backpressure |
| Round-trip serializer | js-editor (Tiptap/PM JS) | canonical + quarantine tiers |
| Lens rendering | native TextKit2 / WKWebView / CodeMirror6 | viewport-based |

## S3. Hardened verdicts on Forks A–D (binding decisions)

### FORK A — Tracked-changes / suggestion verdict
**VERDICT: Build a first-party suggestion engine on raw ProseMirror transactions + `prosemirror-changeset` + provenance IDs, behind a swappable `SuggestionAdapter` seam. Adopt the `@handlewithcare/prosemirror-suggest-changes` mark schema (`insertion` / `deletion` / `modification` + the block-mark trick) as the reference/default adapter. Treat Tiptap AI Toolkit + Tracked Changes as reference only.**

Primary-source state of each option (verified this session):
- **`@handlewithcare/prosemirror-suggest-changes`** (github.com/handlewithcarecollective/prosemirror-suggest-changes): three marks — `insertion` ("newly inserted content, including new text and new block nodes"), `deletion`, `modification` ("nodes whose marks or attrs have changed, but whose content has not"). MIT. Suggestions are keyed by a **numeric auto-incrementing `id`** (type `SuggestionId`) supplied by `generateId`; the public docs show **no built-in author or timestamp attr**. It works via a `dispatchTransaction` decorator (`withSuggestChanges`) plus decorations, with commands `applySuggestion(s)`, `revertSuggestion(s)`, `revertSuggestionsInRange`, `selectSuggestion`. Latest **v0.1.8 (Nov 18, 2025)**, 136 commits, actively maintained. Schema requires allowing marks as block marks on the doc node: `marks: "insertion modification deletion"` "to support block-level suggestions, like inserting a new list item." *Inferred (not read from `schema.ts` — GitHub raw/CDN fetch was blocked this session): the mark attr is literally an integer `id` with no author/timestamp.*
- **It is also mirrored** as `@blocknote/prosemirror-suggest-changes` on npm (npmjs.com/package/@blocknote/prosemirror-suggest-changes) — an **older 0.1.3** copy pinned for BlockNote/TypeCell's internal use (maintainers yousefed/matthewlipski/nperez0111), MIT. The authoritative, actively-updated package is the `@handlewithcare/…` one.
- **`davefowler/prosemirror-suggestion-mode`** (github.com/davefowler/prosemirror-suggestion-mode): marks `suggestion_insert` / `suggestion_delete`; MIT; the plugin factory `suggestionModePlugin({ username, data })` writes a **`username` attr + arbitrary `data` JSON object** onto the marks ("custom metadata that will get added to the attrs of the mark nodes"). Status banner: **"WIP, still known issues in a few scenarios"; no GitHub releases** (release notes tracked in a `/releases` markdown file). 310 commits.
- **Tiptap AI Toolkit + Tracked Changes**: a **paid add-on, currently alpha** (`@tiptap-pro/ai-toolkit@3.0.0-alpha.x`, private npm registry), **not included in Start/Team/Business plans, contact-sales pricing** (tiptap.dev/pricing; Eddyter, "TipTap Pricing 2026": "AI Toolkit and Tracked Changes are separate paid add-ons"). It *does* support streaming (`streamTool`, `streamHtml`) with `reviewOptions.mode: 'trackedChanges' | 'review' | 'preview'`; per the AI Toolkit changelog, "When streaming content with tracked changes, streaming support does not show a 'typing effect'. Instead, it streams content on a per-operation basis." License + alpha status rule it out as a dependency; keep as design reference.
- **`prosemirror-changeset`** (MIT, **v2.4.1, Apr 14 2026**; github.com/ProseMirror/prosemirror-changeset): "turn a sequence of document changes into a set of insertions and deletions… built up incrementally… in a halfway performant way during live editing." It lets us "associate arbitrary data values with such spans, for example to track the user that made the change, the timestamp… the step data necessary to invert it again." It adopted a "more efficient diffing algorithm (Meyers), so that large replacements can be accurately diffed using reasonable time and memory" and exposes `changedRange`, `startDoc`, and a `TokenEncoder`.

Why first-party: our provenance ledger requires **author / turn / ranges / before-after / rationale / source / accept-state** per span. hwc models only a numeric id; davefowler models `username`+`data`. Neither is a superset of our needs, but `prosemirror-changeset` already carries arbitrary per-span metadata — so the correct architecture is our own engine feeding the ledger, wrapping the changeset. Adopting hwc's mark *names + block-mark trick* as the reference schema keeps the choice swappable. `SuggestionAdapter` (JS) exposes `applySuggestion / revertSuggestion / renderDecorations / markAttrs`; swapping to the hwc package or (post-license) Tiptap touches only the adapter, never the ledger.

### FORK B — Round-trip verdict
**VERDICT: Canonical-normalized round-trip is the honest, achievable target for our full schema. Byte-for-byte is achievable only for a restricted node set and MUST be enforced by a tiered harness + minimal-diff writeback. NEVER reserialize the whole document on save.**

Primary-source basis:
- Milkdown's "Human Markdown" VS Code extension claims a byte-for-byte suite: "The test suite parses markdown through Milkdown and verifies the output matches the input byte-for-byte. If an edit touches only one paragraph, the diff shows only one paragraph." It attributes this to sitting on remark's real markdown AST "not a rich-text-to-markdown converter that's guessing at formatting" (dev.to/jeffreese/i-released-a-markdown-editor…). *This is a first-party author claim, not independently reproduced here (flagged in self-critique).* An independent Python survey corroborates that byte-exact round-trip is possible but rare: mistletoe ≥1.1.0 does "byte-exact round-trips" while "All other libraries… very significantly normalize your document" (codeberg.org/scy/python-markdown-roundtrip-test).
- **prosemirror-markdown** serializer options (github.com/ProseMirror/prosemirror-markdown, `to_markdown.ts`): `tightLists` (default false), `escapeExtraCharacters` (RegExp), `hardBreakNodeName` (default "hard_break"), `strict` (ignore unknown nodes). CommonMark scope; single-newline soft breaks become spaces; code blocks always wrapped in triple backticks.
- **Tiptap `@tiptap/markdown`** (MarkedJS-based) is explicitly "CommonMark" and "an early release… can be subject to change or may have edge cases" (tiptap.dev/docs/editor/markdown). Known round-trip bug: table-cell `<br>` lost on serialize (Issue #7731). The paid Conversion extension states plainly: "Anything that doesn't map to CommonMark is dropped."
- **DesktopCommanderMCP #440 / fixed in #445**: v0.2.39 "silently rewrites .md files via Tiptap-based markdown round-trip," corrupting YAML frontmatter, "collapsing GFM tables, rewriting Obsidian wikilinks ([[Note]] → [Note](http://Note)), corrupting YAML frontmatter, and adding spurious `\[`, `\]`, `\~`, `\_` escapes." This is the canonical proof that an implicit full-document round-trip on save is a data-loss bug class we must design against.

Round-trip proof/test harness (tiered, binding):
- **Tier A (canonical-lossless):** headings, paragraphs, bold/italic, inline code, bullet/ordered/task lists, fenced code w/ lowlight, blockquotes, HR, images, links. Requirement: canonically idempotent after first normalization.
- **Tier B (custom-extension, explicit serializers + tests):** tables, inline+block math, callouts, wikilinks, highlights, charts, YAML frontmatter. Frontmatter is **parsed and passed through verbatim**, never reserialized by the markdown engine.
- **Tier C (byte-preserving opaque quarantine):** any node the schema doesn't own is stored as an opaque byte-span and written back unchanged.
- **Minimal-diff writeback (git-tracked vault):** never reserialize the whole doc on autosave. Use `prosemirror-changeset` (`changedRange`) to find the touched block range, reserialize only those blocks, splice into the on-disk buffer, and preserve original line endings, indent style, and list markers everywhere else. A one-paragraph edit → a one-paragraph git diff.

### FORK C — Multi-lens sync state machine (one write-lease per note session)
**Canonical machine:** `Idle → Loading → Clean → Dirty → Autosaving → Clean`, with `ExternalChange` and `Conflict` side-states.
- **Write-lease / follower model:** the first window/lens to open a note acquires the write lease (persisted in a GRDB `note_session` row). Additional windows open as **followers** — read-only mirrors, live-updated via the F6 bus. A follower requesting an edit triggers a lease-handoff; the lease releases on blur/idle timeout.
- **Autosave debounce:** 800 ms after last keystroke, or a 5 s max-in-flight ceiling, whichever fires first; force-flush on blur, lens-switch, and app-background.
- **External-file-change conflict handling:** file watcher fires → if the note is Clean, reload; if Dirty, enter `Conflict` and hand to the merge engine (OQ-1).
- **Authoritative undo stack (the explicit open question — resolved):** ONE undo stack per note session, held by the ProseMirror/Tiptap history plugin of the lease owner. **Agent and user edits share that single stack but are tagged** in transaction metadata (`source: 'agent' | 'user'`, `turn`, `suggestionId`). Agent edits enter as tracked-change *suggestions* (not applied to base), so "revert-all-by-companion" = revert every span with `source:'agent'` for a turn. On lens switch, PM-JSON is authoritative and travels with the lease; the WKWebView Tiptap instance is not torn down, so its history is preserved, and the Prose/Source lenses read the same PM-JSON plus an undo-depth marker rather than recreating state.

### FORK D — Load-vs-edit bridge handshake
**VERDICT: nonce/`loadEpoch` + suppression window + `filterTransaction` guard. Do NOT rely on `emitUpdate:false`.**

Primary-source basis (why the flag is untrustworthy):
- `setContent`'s `emitUpdate` default **flipped from false→true in v3**. Verbatim (tiptap.dev/docs/editor/api/commands/content/set-content): "`emitUpdate?: boolean (true)` Whether to emit an update event. Defaults to true (Note: This changed from false in v2)."
- Issue #1715 (ueberdosis/tiptap): "According to the doc, the emitUpdate is equal to false by default. I have tried omitting or setting it to false, but in both cases I actually get the update event" — i.e. **`setContent` emits an update anyway when a node view is present.**
- Issue #4828: "in a ~20% chance, `editor.setEditable` gets called first, emitting an update event which updates the parent state with an empty document… In the end, the content in parent state is replaced by an empty document."

Hardened protocol (idempotent, survives both bugs):
1. Every programmatic load gets a monotonic `loadEpoch` (nonce); native increments and passes it in the inbound bridge message.
2. Before `setContent`, set `suppressUntilEpoch = loadEpoch` and open a suppression window.
3. A ProseMirror `filterTransaction` guard drops/marks any programmatic-origin transaction whose epoch ≤ `suppressUntilEpoch` that carries no user-input meta.
4. Outbound `update` events carry the current `loadEpoch`; native ignores any outbound whose epoch ≠ the latest requested. Correctness no longer depends on `emitUpdate` honoring the flag.
5. `document-load-state.ts` owns the epoch counter + suppression window; `inbound.ts` / `outbound.ts` stamp epochs.

## S4. Scale mechanisms (binding, cited)
- **Ledger retention/compaction (SI-2):** GRDB in **WAL mode via `DatabasePool`** ("Database pools open your SQLite database in the WAL mode"; groue/GRDB.swift README). Ledger table compacted periodically into an ATTACHed `archive` DB with checkpoints; `replay.rs` reconstructs from checkpoint + tail. Use a hard-cap-then-rolling-trim pattern (DesktopCommander capped its tool-history "at 5 MiB with a rolling trim down to 4 MiB keeping the most recent entries"). Caveat: "If there are too many accumulated data in the WAL, writing to the database can result in degraded performance" — checkpoint regularly.
- **Graph writes at 100k (SI-3):** short write transactions ("Prefer DatabasePool with WAL for concurrency. Keep write transactions short"; Medium, "Query-based Databases in iOS — Why GRDB is a Great Fit"), B-tree indexes on filtered columns (`CREATE INDEX idx_note_createdAt ON note(createdAt DESC)`), and large blobs stored as file references, not in-DB.
- **Round-trip speed (SI-4):** minimal-diff writeback (Fork B) + changeset Meyers diff.
- **Source lens (CodeMirror 6):** viewport rendering is fundamental and non-disableable — "CodeMirror doesn't render the entire document, when that document is big… only render that plus a margin around it. This is called the viewport" (codemirror.net/docs/guide). CM6 maintainer Marijn: "Viewporting is a rather fundamental aspect… not something that can be turned off" — do **not** set `viewportMargin: Infinity`. This is why CM6, not ProseMirror, owns the Source lens for multi-MB docs (a ProseMirror forum test found ~50,000-line docs "very laggy" while CodeMirror "renders and edits with no conceivable delay").
- **WKWebView asset pipeline:** `epdoc://` custom scheme via `WKURLSchemeHandler` (iOS 11+ / macOS) in `EpdocEditorBridge.swift`, serving brotli-compressed package assets. **MAS caveat (version-gated / fallback):** treating a custom scheme as "secure" for cross-origin https requires the *private* `WKProcessPool._registerURLSchemeAsSecure` — "you can't do this in an app you're going to submit to the App Store because it involves using a private API" (dev.to/alastaircoote). Fallback: on MAS, load the editor root itself via the custom scheme and avoid https↔custom cross-origin bridging.

---

## S5. REPO-INTEGRATION AMENDMENTS (owner review 2026-07-06 — BINDING; these override S1–S4 where they conflict)

Full rationale: `LUMENLENS_REVIEW_2026_07_06.md`. Summary of the binding deltas:

1. **S1 gating (L1), amended by 2026-07-07 MAS-only pivot:** `KINDRED_ENABLED` and
   `EPISTEMOS_EXPERIMENTAL` are parked. Active proof = build `Epistemos-AppStore` and assert zero
   companion/presence symbols in the binary.
2. **S2/S4 search:** hybrid search ALREADY EXISTS (GRDB FTS + Rust tantivy/usearch shadow + RRF
   fusion behind `EPISTEMOS_RRF_FUSION_V1`). The editor consumes it; no search build work.
3. **S4 asset pipeline:** ALREADY BUILT as `epistemos-doc://` + `decompressBrotli` in
   `EpdocEditorBridge.swift` (source-guard-tested). Do not create `epdoc://`.
4. **Fork D:** extends the EXISTING `document-load-state.ts` (`markHostDocumentLoaded`) — and
   `EpistemosVisibilitySourceGuardTests` pins exact strings; update guards deliberately in the
   same commit as any refactor.
5. **Fork C:** the "WKWebView not torn down on lens switch" claim is FALSE today
   (`dismantleNSView`/`Coordinator.shutdown`). Phase 2 makes an explicit choice: retain-per-session
   (better, memory-budgeted) vs documented undo-loss on lens switch (safe default). The write-lease
   is justified (graph-embed + window = two live editors). Autosave wires into the existing
   `EpdocEditorSavePipeline`, not a new pipeline.
6. **F1/write path:** minimal-diff writeback SPLICES in memory, then writes the WHOLE buffer
   atomically through KEELSTONE's `AtomicVaultWriter`. The session machine implements KEELSTONE's
   `ActiveEditorBridge` protocol — one implementation serves both plans. KEELSTONE Phases 0–4
   precede LUMENLENS Phases 1–2.
7. **F5 ledger (L8):** `ClaimLedger` is in-memory Phase 1 — span provenance persists in the GRDB
   editor-domain table (`EditorProvenanceStore`) with a `claim_id` linkage; no durable Rust ledger
   is assumed.
8. **Lens rendering:** Source = vendored MarkEdit CoreEditor (CM6) via
   `MarkEditCoreEditorCoordinator`; Prose = existing TextKit2 stack; Epdoc = existing chrome +
   `js-editor/` (serializer: `src/markdown/epdoc-markdown-nodes.ts`). Extend; never duplicate.
