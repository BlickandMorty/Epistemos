# DEEP-RESEARCH PROMPT — PLAN 2: EDITOR (lens model + Epdoc companion-edit layer + PDF)

**ID:** `EPI-RP-02-LUMENLENS` · **Codename:** LUMENLENS · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> Paste everything below `─── BEGIN ───` into a top-tier deep-research model. Output = a
> **build-ready dossier**. Same rigor as the agent-surface dossiers. Owner authored 2026-07-06.
>
> **Build split:** the **base editor lens model** ships in **both builds (MAS + 1Code)**. The
> **Epdoc companion-edit sidebar minichat + streamed diff/trace editing** layer is **1Code-only**
> (it is the editor side of Plan 5 Companions — hidden on MAS). Design the two layers so the base
> is shared and the companion layer is a cleanly-gated 1Code addition.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal editor-architecture researcher. Produce a build-ready dossier for the Epistemos note
editor. External primary sources only (ProseMirror/Tiptap/CodeMirror/PDFKit docs & source, real
"AI edits your prose" products). Cite every external claim; never invent APIs. You do not have the
private repo, but design against the exact architecture + file names below.

## 1. Product context (ground truth)
Epistemos = macOS-native PKM (Swift 6 + Rust `agent_core` + GRDB). Notes are **markdown files in a
vault** = the single source of truth. The editor shows one markdown file as **synced "lenses"**:
- **Prose** — a native TextKit-based rich editor (`ProseEditorView`).
- **Document / "Epdoc"** — a **Tiptap (ProseMirror) editor in a WKWebView**, the *default* lens,
  with a Swift↔JS bridge. Rich blocks (headings, code w/ lowlight, tables, charts, images, math).
- **Preview** — rendered read view.
- **Source** — raw markdown / code (`CodeMirror`-class) for code files.
Switching lenses must never lose data — all edit the **same markdown body**. (Epdoc just became the
default view for every note across the app.)

Two builds: **MAS** (sandboxed, no subprocess) and **1Code/Experimental** (Developer ID). The
**companion** (Plan 5) is a 1Code-only agent that will edit notes *through this editor*.

## 2. Thesis
**One markdown truth, several perfectly-synced lenses — plus, on 1Code, a docked companion that
edits the live document with visible, reviewable, provenance-tracked changes.** The editor must be
(a) a rock-solid multi-lens markdown surface that never corrupts or de-syncs a note, and (b) the
substrate that lets a Plan-5 companion stream edits into the doc as accept/reject tracked-changes
while the user watches — the revived, superseded "Tolaria" editing experience.

## 3. Hard constraints
1. **One source of truth = the markdown file.** Every lens is a projection; round-tripping through
   any lens must be lossless. Define the canonical markdown ⇄ ProseMirror-JSON mapping and prove
   round-trip fidelity for every block type.
2. **Loading ≠ editing.** Pushing content into Tiptap on open must NOT emit change/autosave events
   (a known past bug). Specify the load-vs-edit protocol on the bridge.
3. **Agent edits via ProseMirror transactions** — never a shadow editor, never blind `setContent`
   that clobbers cursor/selection/unsaved work. Concurrent user typing must be safe.
4. **Companion-edit layer is 1Code-only** and cleanly gated off on MAS.
5. **WKWebView custom-scheme reality:** the editor is served through a custom scheme that does NOT
   auto-decompress `Content-Encoding: br` — assets are brotli-decompressed server-side. Respect the
   existing asset/bridge model; don't assume HTTPS behavior.
6. Platform hygiene: `@Observable`; never block `@MainActor`; keys in Keychain; no subprocess on MAS;
   never touch the graph subsystem; never edit `.xcodeproj` by hand (xcodegen).

## 4. What exists today (design to extend)
- **Lens host:** `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` (`NoteWorkspaceMode` enum +
  `resolvedNoteMode` graceful fallback + `noteModeOptions`), `MarkdownDocumentSurface.swift` (mounts
  Epdoc over a note body + writes back through the markdown pipeline), `ProseEditorView.swift`.
- **Epdoc/Tiptap:** `js-editor/` (`src/index.ts`, `src/bridge/inbound.ts` + `outbound.ts` +
  `document-load-state.ts`, extensions: code-block-lowlight, chart, image, table, math, markdown
  input rules, paste classifier), `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` + toolbar +
  bubble, `Epistemos/Engine/EpdocEditorBridge.swift` (URL-scheme handler, brotli, package assets).
- **Provenance:** `agent_core/src/provenance/ledger.rs` + `replay.rs` (attributed changeset backing).
- **Canon:** `docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md` (the lens model decision).
- **PDF:** the master plan places the PDF viewer in this plan (see D5).

## 5. Research dimensions
### D1 — The lens-sync engine (correctness core, both builds)
- The canonical **markdown ⇄ ProseMirror-JSON** mapping for every block (headings, lists, tables,
  fenced code, math, images, task lists, callouts, wikilinks, highlights). Prove lossless round-trip;
  enumerate the lossy edge cases and how to preserve or quarantine them. Cite Tiptap/ProseMirror
  schema + a markdown serializer (prosemirror-markdown / remark) reality.
- **Sync model between lenses:** when the user edits in Prose vs Epdoc vs Source, how does the
  shared markdown truth update without race/clobber? Debounce, dirty-tracking, autosave, conflict
  when two lenses open. Define the state machine.
- **Load-vs-edit protocol** (the "blank/overwrite on open" class of bug): exact handshake so a
  content-load never emits `contentDidChange`/autosave. Cite the existing `document-load-state.ts`
  concept and harden it.

### D2 — Agent/companion editing into the live doc (1Code-only; partner to Plan 5 D2/D10)
- How agent edits enter a live Tiptap doc as **tracked-changes / suggestions** with inline diffs and
  per-change accept/reject: survey real ProseMirror track-changes implementations (prosemirror-
  changeset, prosemirror-suggest-changes, Tiptap Pro comments/track-changes, CKEditor). Verdict +
  why, with the schema for a suggested change.
- **Streaming edits** so the user watches the companion write/revise token-by-token while undo stays
  coherent and autosave correct; cancellation + conflicting user edit + malformed partial markdown.
- **The attributed changeset** ("press mascot → see its edits", revert-all-by-companion): map to the
  `agent_core` provenance ledger; schema (author/turn/ranges/before-after/rationale/source/accept-
  state); render richly in the WebView (inline + side-by-side prose diff UX; cite a word/char diff lib).
- **Embodied editing hook** (feeds Plan 5 D10): expose the live edit position via
  `view.coordsAtPos` so a companion sprite can follow the words. Specify the coordinate/scroll API
  the presence layer consumes. Keep this a thin, documented seam — the mascot itself is Plan 5.

### D3 — The Epdoc sidebar minichat dock (1Code-only)
- Design the **docked mini-agent panel** inside Epdoc: layout, focus behavior, how it shares
  session/context with the 1Code main agent (continuity, not a second chat), how a message becomes a
  document edit, how it shows the diff/accept flow. Because Epdoc is a WebView you have full web
  latitude — exploit it. Cite Tolaria/Cursor-Composer/Notion-AI side-panel patterns.
- Cross-editor consistency: if the minichat exists, it must feel identical wherever Epdoc mounts
  (main pane, window, graph embed). Don't fragment.

### D4 — Prose (native TextKit) & Source lenses (both builds)
- Best practices for the native TextKit prose lens: performance on large notes, live markdown
  affordances, image handling, and staying in lock-step with the markdown truth. Where should Prose
  vs Epdoc each be the better tool? (owner made Epdoc default — validate/refine.)
- Source lens for code files (CodeMirror-class): syntax, and how `.source` coexists with the md lens.

### D5 — PDF viewing (both builds)
- The PDFKit-based viewer for notes/attachments: annotation, text selection→note, provenance from a
  PDF into a note, performance on large PDFs, sandbox constraints. Cite PDFKit reality. How it
  relates to Plan 3's PDF→markdown capability (don't duplicate; define the boundary).

### D6 — Performance & robustness ("instant", never-corrupt)
- Budgets: open-to-editable latency, keystroke latency in a large doc, streamed-edit smoothness,
  lens-switch latency. WebView warmup/reuse. Failure table: bridge message drop, WebView reload with
  unsaved edits, brotli/asset failure, agent crash mid-edit, external file change while open.

### D7 — Competitive synthesis
- Cited comparison: Obsidian (md truth + plugins), Notion (block model + AI), Tolaria, Cursor
  Composer, iA Writer/Ulysses (prose lenses), Craft, Typora (WYSIWYG md). Columns: md fidelity,
  multi-lens, agent editing, diff/provenance, performance. What to copy, avoid, and the novel edge.

### D★ — Deep Fabric Integration (F1–F6) — MANDATORY (`INTEGRATION_FABRIC.md`)
The editor is where several fabric contracts meet — design them, don't stub:
- **F1 vault:** every lens edits the one vault markdown file; changes reflect app-wide.
- **F2 capability:** "edit / restructure / summarize / cite into this note" are agent capabilities
  that drive the editor (June + 1Code companion), honestly gated. Define the tool schema.
- **F3 presence:** the companion mascot appears in Epdoc and (D2 embodied seam) follows the words.
- **F4 graph:** typed wikilinks/edits update graph nodes/edges via the public API.
- **F5 provenance:** agent edits are attributed, citable, and revertible through the ledger.
- **F6 state bus:** streamed edits + live edit-position publish on the bus (feeds F3 word-following).
State exactly which side (native / agent_core / 1Code / Tiptap JS) owns each seam. These six briefs
form a **single integrated product built one plan at a time**, not six apps.

## 6. Primary-source discipline
Cite ProseMirror/Tiptap/CodeMirror/PDFKit APIs and real product material. Flag version-gated or
uncertain capabilities with a fallback. Distinguish observed vs inferred.

## 7. Deliverable
1. Executive thesis. 2. **Lens-sync engine** (D1) — mapping tables + round-trip proof + state machine
(longest base section). 3. **Companion editing engine** (D2) — mechanism, rejected alternatives,
schemas, streaming, provenance, embodied-edit seam (longest 1Code section). 4. Minichat dock (D3).
5. Prose/Source lenses (D4). 6. PDF viewer (D5). 7. Perf + robustness/failure table (D6).
8. Competitive table + novel edge (D7). 9. **Phased build order** (base lens hardening → load-vs-edit
→ companion tracked-changes → streaming → provenance → minichat → PDF), each with a *witnessable*
proven-done bar; flag Plan 5 (Companion) + Plan 3 (PDF→md) dependencies. 10. Open questions.

## 8. Anti-patterns
No generic "rich text editor" boilerplate. No invented ProseMirror APIs. No design that loses md
fidelity, clobbers the user on load/edit, builds a shadow editor, or leaks the companion layer onto
MAS. Don't silently resolve Prose-vs-Epdoc default (owner set Epdoc; validate, note trade-offs).

─── END RESEARCH BRIEF ───
