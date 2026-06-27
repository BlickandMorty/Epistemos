# EPDOC md-v2 — consolidated build sequence (2026-06-20)

> ✅ **OWNER DECISION (2026-06-27) — THIRD SURFACE, PROSE IS A HARD GATE.**
> The owner chose **three editor surfaces**, NOT the "graft CodeMirror into Epdoc"
> single-surface recommendation SS-P made:
> 1. **Prose (TK2 / TextKit / `ProseTextView2`)** — **HARD GATE: NEVER TOUCHED.** Frozen
>    legacy / user-only editor. No surgery, no parity obligation.
> 2. **Epdoc (TipTap / WKWebView)** — rich-tree editor, this build sequence.
> 3. **NEW: standalone CodeMirror-6 markdown-SOURCE editor (its own WebView surface)** —
>    canonical home for markdown-source editing + the pixel-art AI-diff trail
>    (yellow=add / red=delete). Safe because files-as-truth (§16): all surfaces
>    read/write the same `<vault>/*.md`. Accepted cost: a 2nd WKWebView — mitigated by a
>    shared `WKProcessPool` + reuse of the `EpdocEditorThemeStyle` CSS-var injector.
> Consequence: **Phase 6 step 19 (CodeMirror-into-Epdoc source toggle) is TOMBSTONED**
> (see strikethrough below) so CodeMirror is not built twice.


Synthesis of the 5 Epdoc slices into ONE ordered, dependency-aware build plan: SS-O (repair), SS-EM (md-first
convergence), SS-FM (frontmatter/tags/properties/backlinks), SS-IR (instant-recall popup), SS-P (Tolaria rich-UI
+ agent-MD). Owner decisions locked: **Epdoc = markdown-first auto-mirror** (md canonical; JSON/HTML/package are
dynamic projections); pixel-art + more-dynamic + native; agent-integrated; **NEVER touch TK2/Prose** (its own
editor — now non-invasively touchable per the 2026-06-20 policy update, but separate from Epdoc). The HTML
workspace is a SEPARATE surface (SS-EM) — converge it to a true projection LAST. This is the "make it explicit"
build order; each phase gates the next.

## The dependency spine (why this order)
```
SS-O bridge repair (errors+ready handshake)  ──┐
                                               ├─▶  SS-EM serializer (getMarkdown)  ──▶  SS-EM canonical flip
SS-EM round-trip tests ─────────────────────────┘                                            │
                                                                                              ├─▶ SS-FM frontmatter/properties/tags
                                                                                              ├─▶ SS-IR recall bubble→popover on Epdoc
                                                                                              └─▶ SS-P rich-UI + agent editing commands
```
**Hard prereq:** SS-O roots #2/#3 (surface JS errors + idempotent ready-handshake) MUST land first — else streamed
agent writes (SS-P) + the serializer round-trip (SS-EM) drop silently.

## PHASE 1 — Repair the bridge (SS-O) [prereq, S]
1. [S] Surface JS errors honestly — `window.onerror`+`unhandledrejection`→`postBridge({type:'error'})`; replace
   the empty Swift `.error break` (`EpdocEditorChromeView.swift:304-305`) with OSLog + a non-blocking banner.
2. [S] Fix the window-close keystroke drop — `Coordinator.shutdown()` calls `flushNow()` before
   `detachAutosavePipeline()` (`:774-788`).
3. [M] Fix floating-panel positioning — viewport→window coord translation instead of hardcoded `+140/+200/…`
   (`:417,431,442`); the dominant visible glitch.
4. [M] Harden the ready handshake (idempotent `editorReady` + watchdog) + add a `WKNavigationDelegate` +
   process-termination reload + an Epdoc runtime health row.

## PHASE 2 — Markdown serializer + round-trip tests (SS-EM Stage 1) [S]
5. [S] Add `@tiptap/extension-markdown` (3.24-compatible first-party `MarkdownManager`) to `js-editor/package
   .json`; expose `getMarkdown()` + `setContent(md,{contentType:'markdown'})` through the bridge (`inbound.ts` +
   a new `contentDidChangeMarkdown` in `outbound.ts`). Pure additive — JSON path untouched.
6. [S] Author the round-trip + idempotency test suite (`md→JSON→md` byte-stable, `JSON→md→JSON` semantically
   equal) covering the known-lossy cases (table-cell `<br>` tiptap#7731, consecutive empty paragraphs `&nbsp;`,
   nested lists). **The canonical flip (Phase 3) is GATED on this going green.**

## PHASE 3 — Flip the source of truth to markdown (SS-EM Stage 2) [M]
7. [M] Promote `content.md` to the REQUIRED package member; demote `content.pm.json` → `projections/content.pm
   .json` (derived cache). Move `manifest.contentHash` onto the markdown; add a `pmCacheHash` drift detector.
8. [M] Loading: `content.md`→`setContent(md)`; if the JSON cache hash matches `content.md` → fast path, else
   re-derive (self-healing). Saving (300ms debounce): `getMarkdown()`→write `content.md` + rewrite cache.
9. [M] Replace the silent-degrade path (`ProseMirrorMarkdownProjector.swift:348-354`) with **fail-loud + last-
   good-cache repair**; rich-only blocks (charts/mermaid/callouts/math) → **HTML-in-markdown fallback** (nothing
   dropped). Bump `manifest.schemaVersion` + write migration-on-open (JSON-canonical `.epdoc` → generate
   `content.md`). HTML stays a render (no stored HTML except on-demand `exports/*.html`).

## PHASE 4 — Frontmatter + properties + tags (SS-FM) [S→M]  (~95% reuse of existing model)
10. [S] `EpdocFrontmatter` YAML parse/serialize (`content.md` frontmatter ↔ `manifest.metadata`); make `---`-at-
    doc-start frontmatter (not `<hr>`) in the projector (`:247`). `manifest.metadata` stays the in-memory
    authority; frontmatter = its md projection (SS-EM one-writer).
11. [S] Read-only **Properties panel** `EpdocPropertiesPanel` rendering `EpdocPropertyMetadata.properties(in:
    manifest)` (the existing 8-kind typed model `EpdocProperty.swift:34-414`) — pixel-art, mirrors `NoteBacklinks
    Popover`/`EpdocSlashMenuView` styling.
12. [M] Editable typed properties (per-kind native control → `withProperty` → autosave); frontmatter `tags:`
    (multiSelect — free tag index via `EpdocDatabase.grouped`) + an inline `#tag` Tiptap node (net-new JS) + a
    Tag-index panel.

## PHASE 5 — Instant-recall bubble→popover on Epdoc (SS-IR) [S→L]
13. [S] (App-wide, independent) Stop Surface B auto-show (`ContextualShadowsState.swift:465` — lights bubble, not
    box); remove from chat/landing/mini-chat; glow ring on `HaloButton`.
14. [M] Slim `ShadowPanelContent` / wrap results in an `NSPopover` anchored to the bubble, `.transient`; accuracy-
    tune (longer debounce + wider limit + dual-domain RRF merge, SS-UMA).
15. [L] Mount the bubble+popover on **Epdoc** via a SwiftUI overlay + `HaloEditorBridge.feed(text:)` off the
    Tiptap content-change/autosave hook. (TK2 already has it non-invasively.)

## PHASE 6 — Rich UI + agent editing + macOS-26 skin (SS-P) [S→L]
16. [S] Harvest Tiptap's first-party Notion-like template + parameterize the loaded DragHandle (drag-reorder);
    pixel-art font/border skin via the existing `EpdocEditorThemeStyle` CSS injector (ProvenanceGate any fonts).
17. [M] Agent editing command family (`insertBlock`/`replaceRange`/`streamInto`/`showDiff`) on the existing
    bridge — Tiptap-AI-Toolkit pattern, driven by `agent_core` + MCP (the "literally integrated with all chats"
    ask). Single property/content writer (no divergent writers, SS-EM).
18. [M] macOS-26 Liquid-Glass theme (`backdrop-filter` + SVG `feDisplacementMap`), availability-gated, toggle vs
    pixel-art. GitHub-grade DOM: code-block copy/lang-pills, collapsibles, Mermaid (wire `LegacyDiagramNode`),
    ToC, wikilink hover-cards via custom NodeViews.
19. ⛔ ~~[L] CodeMirror-6 raw-markdown SOURCE-MODE toggle (the WYSIWYG↔source pattern, reskinned pixel-art) — pairs
    with the Phase-2 serializer.~~ **TOMBSTONED 2026-06-27 (owner: third-surface decision).** CodeMirror-6
    markdown source is no longer an Epdoc *toggle* — it is the **standalone third surface** (its own WebView).
    Build it once, there. Epdoc stays rich-tree-only. The Phase-2 markdown serializer still feeds both surfaces
    via the shared `content.md` (files-as-truth).

## PHASE 7 — Wikilinks + backlinks + HTML-workspace projection (SS-FM/IR/EM) [L]
20. [L] Clickable `[[note]]` Tiptap node + Halo autocomplete (reuse `onSearchLinks`); **Backlinks panel** reusing
    `WikilinkResolver` against the shadow index + `SDPage` (read-only mirror of `VaultIndexActor`).
21. [L] Right inspector rail (Tolaria model): exclusive **Properties/Backlinks/Tag-index/TOC** tabs, Cmd+Shift+I.
22. [L] HTML Workspace → a true opt-in projection (seed `index.html` from a StaticRenderer projection of the
    current Epdoc + pixel-art CSS on the `requestHTMLWorkspace`-from-doc path); reserve Pandoc for `exports/`.
    One-way.

## Cross-cutting constraints (every phase)
- **NEVER load heavy/embedded UI into TK2/Prose** — TK2 is the separate focused-writing editor (name = "Prose");
  it gets only NON-INVASIVE additions (frontmatter via the same `EpdocFrontmatter` parser, hardening, the recall
  bubble) — never the rich-UI / agent-canvas / inspector rail (those are Epdoc-only).
- **One writer** for `content.md` (SS-EM): the editor on save; agent edits + property panel both route through
  the same writer. No CRDT (it would invert the md-first truth model).
- **Pixel-art kept + theme-token-driven** (more dynamic, native, reacts to theme).
- **License-check every JS lift via ProvenanceGate** (Tiptap MIT, Novel Apache, Milkdown MIT, CodeMirror MIT OK;
  Tolaria AGPL + BlockNote-XL GPL = patterns only).
- **Test-at-end** each phase (round-trip tests, property persistence, recall accuracy, agent-write fidelity).
- **Perf before+after** each phase (the owner's standing gate).

Source slices: `SS-O_EPDOC_REPAIR_*`, `SS-EM_EPDOC_FORMAT_CONVERGENCE_*`, `SS-FM_FRONTMATTER_TAGS_SIDEPANELS_*`,
`SS-IR_INSTANT_RECALL_POPUP_REDESIGN_*`, `SS-P_TOLARIA_V2_MD_EDITOR_*`. Ledger items: EPDOC=MARKDOWN-FIRST,
EPDOC FORMAT CONVERGENCE, EPDOC md-v2 (codemirror/frontmatter/chat), INSTANT-RECALL/HALO POPUP, TK2/PROSE
non-invasive. Cross-ref `IMPLEMENTATION_SEQUENCE_2026_06_19.md` (Tier 3 #18 = the Epdoc entry, expanded here).
