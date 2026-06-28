# Epistemos Editor — CANONICAL PLAN (2026-06-27)

> **★ THE single source of truth for the editor work.** Consolidates the Tolaria-supersede research loop
> (passes 1–5) into one contradiction-free plan. Where any other editor doc disagrees, **this wins.** Code
> detail lives in the four code packs (linked per section). Research provenance: `TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md`.
>
> **Doc status map:** CANONICAL → this doc + the 4 codepacks (`TOLARIA_ONTOLOGY_UPGRADE_CODEPACK`,
> `MARKEDIT_EMBED_CODEPACK`, `NATIVE_CONTROLS_CODEPACK`, `GOOSE_MINICHAT_CODEPACK`) + `EPDOC_MD_V2_BUILD_SEQUENCE`
> (note-editor build content) + `SS-P_TOLARIA_V2_MD_EDITOR` (note-editor patterns/license) + `SURFACE...§16`
> (markdown-as-truth). HISTORICAL → `SS-CM_CODEMIRROR_MD_SOURCE_SURFACE` + `CODEMIRROR_MD_V2_BUILD_AND_POLISH`
> (CodeMirror-as-note-editor was reversed; their CM6/MarkEdit research now applies to the CODE lane only).

---

## 0. OPEN QUESTIONS — owner decisions needed (do not paper over)
These are surfaced, not silently resolved. The plan proceeds on the marked defaults until the owner rules.
1. **JSON-vs-markdown source-of-truth fork (biggest).** Epdoc stores ProseMirror JSON in `.epdoc` packages
   TODAY; §16 wants vault `.md` write-through; the `@tiptap/markdown` serializer is UNBUILT. *Default:*
   serializer-first → canonical-`.md` flip → HTML-in-markdown fallback for rich-only blocks (charts/mermaid/
   math); until then Goose `update_note` writes JSON into the package.
2. **Minichat shape.** Research recommends **native SwiftUI over the Goose ACP bridge + an "Open in Goose"
   webview escape hatch**; owner's phrasing was "native webview shell." *Default:* native-chat + escape-hatch
   (note-context plumbing is identical either way). **Needs owner confirm.**
3. **Note-width values.** *Default:* normal = ~720px readable column, wide = `max-width:none`; ship binary
   first, a width SLIDER is a later differentiator.
4. **Code-editor swap scope.** *Default:* Option A (keep Epistemos's SwiftUI code chrome, swap the engine
   textarea→MarkEdit CoreEditor) + selectively graft MarkEdit's native Find/FontPicker/Statistics/Goto-Line.
5. **`@codemirror/merge` for the CODE editor.** *Default:* yes — it's the natural diff engine for the CM6 code
   editor (it was only wrong for the *note* editor).
6. **Cleanup fate.** *Default:* after the CoreEditor swap, delete the 3 dead code-editor impls
   (`WebKitCodeEditorView` textarea, dormant `CodeEditSourceEditor`, scaffold `LiveCodeEditorController`).
   Epdoc/TipTap is KEPT (it's the note editor). Prose/TK2 is KEPT (frozen).

---

## 1. The surface model (THREE editors, each to its strength)
| Surface | Engine | Role | Status |
|---|---|---|---|
| **Note editor = Epdoc** | TipTap/ProseMirror in WKWebView | Tolaria-like WYSIWYG notes — the primary writing surface | LIVE, exists; revamp it |
| **Code editor = MarkEdit CoreEditor** | CodeMirror 6 in WKWebView (vendored from MarkEdit) | code/text files; replaces the current textarea code editor | BUILD (swap) |
| **Prose = TK2** | TextKit 2 / `ProseTextView2` (native) | 🔒 frozen hard-gate, long-form/focus | UNTOUCHED |
| **(embedded) Full MarkEdit app** | MarkEdit Swift modules | full settings + native chrome; "another feature later" | EMBED, inert behind a flag |

Why: TipTap = the rendered/WYSIWYG "looks like Tolaria on edit" feel (Tolaria's editor *is* BlockNote = TipTap+
Notion-UI underneath); CodeMirror = purpose-built for code (the current code editor is a textarea with
highlighting DISABLED — see `MARKEDIT_EMBED_CODEPACK` §0); TextKit = best for very large docs.

---

## 2. Locked decisions (consolidated from passes 1–5)
1. **Note editor = TipTap on the existing Epdoc.** NOT BlockNote (React-only, 8.8× bundle, primitives-only
   props hostile to the ontology, `xl-ai` is GPL). NOT CodeMirror (that decision was reversed). "Look like
   Tolaria" = a CSS/chrome polish task on Epdoc, not an engine swap.
2. **Code editor = MarkEdit's CoreEditor (CodeMirror 6).** Keep CoreEditor (this updated the earlier
   "drop it" call). Epdoc stays the note editor; the two coexist (two scheme handlers, distinct schemes).
3. **MarkEdit = FULL app embedded** (Route D): vendor `MarkEditCore` + `MarkEditKit` + `MarkEditMac/Modules`
   (11 libs incl. SettingsUI/FontPicker/Statistics) + `Sources/{Editor,Panels,Settings}` + `CoreEditor`;
   DROP its `@main`/`AppDocumentController`/`.xcodeproj`/`Info.entitlements`/both `.appex`; re-host
   `EditorViewController` via `NSViewControllerRepresentable` against the EXISTING `EpistemosDocumentController`
   (Epistemos is already a document app). Full Settings present-but-inert behind `#if EPISTEMOS_MARKEDIT_EMBED`.
4. **Prose/TK2 = frozen hard-gate, never touched.**
5. **Note AI-diff = `prosemirror-changeset` (MIT) + `@handlewithcare/prosemirror-suggest-changes` (MIT).**
   NOT `@codemirror/merge` (that's the code-lane diff), NOT TipTap AI Toolkit (paid), NOT BlockNote xl-ai (GPL).
   Diff per settled chunk, never per token (Zed #58037 lesson).
6. **Markdown round-trip = official `@tiptap/markdown` v3.27.x (MIT)** + custom `marked` tokenizers for
   callouts/wikilinks/frontmatter. (NOT the deprecated community `tiptap-markdown`; NOT the nonexistent
   `@tiptap/extension-markdown`.) See open question #1 for the JSON-fork.
7. **AI = Goose** (engine), grafting Tolaria's editing doctrine; minichat note-aware, Phase-0 gated.
8. **Ontology = Tolaria clean-room on SDPage + frontmatter + the unified graph.** Tolaria is AGPL-3.0 →
   clone-forbidden, ZERO code, behavioral reimplementation only.
9. **Review model = hybrid** (git-diff/file-level spine + opt-in in-editor diff for small edits).

---

## 3. Note editor (Epdoc / TipTap) — the Tolaria revamp
- **Look like Tolaria:** CSS/chrome polish on Epdoc (it already has slash menu, drag handles, bubble menu).
- **Markdown:** add `@tiptap/markdown` + tokenizers; resolve the JSON-fork (open Q1).
- **AI-diff trail (yellow=add/red=delete):** `prosemirror-changeset` two-doc diff (snapshot original → stream
  into staging, batched per chunk → `ChangeSet.addSteps` → decorations: insertions yellow `mark`, deletions
  red strikethrough `widget`) → per-chunk accept/reject via `EpdocCopilotDockView`. Carry a `claimId` in each
  span's `data` (→ provenance, §6).
- **Live-preview note:** TipTap is already WYSIWYG (tables/code/etc. render + edit in place, no syntax shown,
  no shift) — this is the "edit-on-preview" feel the owner wanted; no CodeMirror reveal-at-cursor needed.

## 4. Code editor (MarkEdit CoreEditor) — `MARKEDIT_EMBED_CODEPACK_2026_06_27.md`
- **Swap (Option A, default):** replace `WebKitCodeEditorView` (textarea) with a `MarkEditCodeEditorRepresentable`
  hosting CoreEditor (CM6) at `CodeEditorView.codeEditorSurface`; keep Epistemos's native chrome (top bar, Find,
  Go-to-Line, Outline, Live-Preview, LSP-hover, theming, prefs). Then selectively graft MarkEdit's native
  Find/FontPicker/Statistics/Goto-Line.
- **LSP:** keep the one-shot Swift `CodeEditorSemanticLSP` over `RustLSPTransport` (engine-agnostic); a CM6
  LSP-client extension bridged to `lspSendMessageJson`/`lspPollResponseJson` is a later slice.
- **Code-lane diff:** `@codemirror/merge` (open Q5).

## 5. MarkEdit full embed (Route D) — `MARKEDIT_EMBED_CODEPACK_2026_06_27.md`
Vendor/drop/re-host map + build plan in the codepack. Build (`build-coreeditor-bundle.sh` cloned from
`build-tiptap-bundle.sh`, vite+yarn, lock-hash gate); keep `chunk-loader://` first (brotli-unify later);
adopt Epistemos entitlements (reject MarkEdit's MAS-hostile keys); xcodegen `project.yml`. Coexistence: two
scheme handlers, shared (no-op-on-12+) process pool routed through the memory-pressure handler.

## 6. AI / minichat (Goose) — `GOOSE_MINICHAT_CODEPACK_2026_06_27.md`
- **Shape (open Q2):** native SwiftUI over `GooseACPEventBridge` + "Open in Goose" webview escape hatch.
- **Auto-init on note open:** `ActiveEpdocTracker` (frontmost note) + `NoteContextProvider` (bounded head/tail
  body via existing `ProseMirrorMarkdownProjector`) → `WorkNativeMCPHost.updateContext`. One shared Goose
  session re-scoped per note (cwd=vault constant).
- **Graft Tolaria's doctrine onto Goose:** vault-root `AGENTS.md` guidance, per-turn context snapshot (MCP-pull
  via `epistemos.context.snapshot` + a thin "current note" preamble), honest head/tail truncation, UI-steering
  MCP tools (`open_note`/`highlight_editor`), convention-frontmatter. Goose BEATS Tolaria's CLI-shell:
  in-process, real per-edit approval (`session/request_permission`), provenance, no port sprawl.
- **Goose-boundary gaps to close:** `GooseACPClient.newSession` drops `mcpServers` (1-line), NO cancel method
  (add `session/cancel`), NO Epdoc UI-steering affordances (add to `GooseWebNativeAffordanceBridge`).
- **Phase-0 GATED:** scaffold + note-context plumbing now (zero Goose dep, testable); flip live after the Goose
  §7 sign-off; mirror the `#if EPISTEMOS_APP_STORE` Pro gate on the minichat surface.
- **Provenance (supersede Tolaria's git-only):** per accepted edit → `EditClaim` in the existing `ClaimLedger`
  (agent/model/runtimeKind/capability_tier/confidence/approver/generatedAt vs acceptedAt) + content-address in
  the `cognitive_dag` (DerivesFrom/AttributedTo/ApprovedBy/Evidence, Merkle); `claimId` ties UI↔git↔DAG;
  retraction propagation beats `git revert`.

## 7. Native controls — `NATIVE_CONTROLS_CODEPACK_2026_06_27.md`
Epdoc is ALREADY MarkEdit-shaped (native SwiftUI chrome → `EpdocEditorCommand` → `window.epistemos.*`). Gaps:
- **Unified `CommandRegistry`** (one registry → menu bar + shortcuts + a NEW **Cmd+K palette**; Cmd+K is free) —
  highest-leverage, build first.
- **Find/Replace** (native panel → ProseMirror search for notes / CM6 search for code).
- **Note-width toggle** (native button → CSS var `--epdoc-content-max-width`, already exists; persist `_width`
  only if frontmatter exists — see ontology §8).
- **Panel-toggle segmented control** (Properties/ToC/Backlinks/AI) with focus-scoped Cmd-shortcuts.
- **MUST stay in WebView:** the 4 caret-anchored TRIGGERS (slash/bubble/drag-handle/KaTeX) — but their PANELS
  are already native SwiftUI positioned from a bridged anchor rect.

## 8. Ontology — `TOLARIA_ONTOLOGY_UPGRADE_CODEPACK_2026_06_27.md`
7 clean-room Swift/Rust snippets, each on a real Epistemos type: `NoteOntologyParser` (typed parse over the
existing flat parser), `FrontmatterRelationshipReconciler` (persist forward+inverse typed edges into the graph),
`SystemKeys` (`_`-convention enforced across FTS+HNSW+graph), `ViewDefinition`/`ViewCompiler`/`ViewEvaluator`
(all/any tree → indexed GRDB SQL + a `semantic:` op RRF-fused with HNSW), `NoteWidthResolver`, `TypeRegistry`
(in-memory over SDPage + advisory schema-light validation), `incrementalCrawl` (per-note content-hash deltas).
SUPERSEDE: persisted typed relationship graph, schema-light validation, semantic+structured hybrid views,
provenance-aware incremental reindex, real trash+undo (Tolaria deletes permanently).

## 9. Minimal-but-best toggle curation (owner: "minimal but the best things")
KEEP (top): note-width toggle · Cmd+K unified command registry · rich↔(future)source on one `.md` · files-first
truth · `[[wikilink]]` autocomplete+rename+backlinks · round-trip-only slash menu · layout presets · Inspector
(Properties/Relationships/Backlinks/Git-history) · git first-class (AutoGit opt-in) · Inbox+mark-organized ·
Types as light lenses · saved Views (visual builder) · ToC · Light/Dark/System no-flash · global RRF search ·
math+code(fix the fence bug) · Mermaid · keyboard-first+surface-aware shortcuts · drag-handle blocks ·
open-in-new-window focus. DROP/DEFER: whiteboards, spreadsheets, bundled multi-agent CLIs, Pulse/Neighborhood,
multi-vault graph, hand-YAML views, telemetry. ADD (beat Tolaria): real focus/typewriter mode, width slider,
real trash+undo, semantic search, mobile.

---

## 10. Build sequence (dependency-ordered)
Stage gates; each is independently shippable where possible. Goose-dependent items wait for Phase-0 sign-off.
1. **[S] Ontology core** (codepack 4a): `NoteOntologyParser` + `SystemKeys` + `NoteWidthResolver` + the
   frontmatter→graph reconciler. Pure Swift, testable, no UI risk.
2. **[S] Native CommandRegistry + Cmd+K palette** (codepack 4c) — unifies menu/shortcuts; wire existing Epdoc
   dispatch into it.
3. **[M] Note-editor revamp** (Epdoc): Tolaria CSS/chrome polish + note-width toggle + Find/Replace + panel
   segmented control. Add `@tiptap/markdown` + resolve the JSON-fork (open Q1).
4. **[M] Note AI-diff** (`prosemirror-changeset` + suggest-changes) via `EpdocCopilotDockView`.
5. **[M] MarkEdit embed + code-editor swap** (codepack 4b): vendor MarkEdit, `build-coreeditor-bundle.sh`,
   swap textarea→CoreEditor (Option A), graft native Find/FontPicker/Statistics; full Settings inert.
   Then cleanup the 3 dead code-editor impls (open Q6).
6. **[M] Views + Type registry + incremental crawl** (codepack 4a) over GRDB/graph/shadow.
7. **[L, Phase-0 gated] Goose minichat** (codepack 4d): build the note-context plumbing now; flip the live
   agent surface after Goose §7 sign-off. Close the 3 Goose-boundary gaps. Provenance EditClaim wiring.
8. **[L] Supersede polish:** real trash+undo, focus/typewriter mode, width slider, semantic view op.

## 11. License ledger (all live-verified)
SHIP-CLOSED: MarkEdit (MIT), CodeMirror 6 + `@codemirror/*` (MIT), TipTap core + `@tiptap/markdown` (MIT),
`prosemirror-changeset` (MIT), `@handlewithcare/prosemirror-suggest-changes` (MIT), `@codemirror/merge` (MIT,
code-lane). FORBIDDEN closed: Tolaria (AGPL — clean-room only, ZERO code), BlockNote `xl-*` (GPL), Vrite
(AGPL), TipTap Pro AI Toolkit (paid). CAUTION: `prosemirror-suggestion-mode` (MIT per npm only, no LICENSE file).
Every lift → `F-ProprietaryCompression-ProvenanceGate` (MIT/Apache=clean-import; AGPL/GPL=research_only).
