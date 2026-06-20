# SS-EM — Epdoc format convergence: markdown-canonical, HTML/JSON/package = dynamic projections (2026-06-19)

Read-only research (subagent, repo + web), all repo claims file:line-verified against the working tree. Feeds
the EPDOC-FORMAT-CONVERGENCE ledger item + the locked EPDOC=MARKDOWN-FIRST decision. Owner: *"md first, then
html/json/package are dynamical projections of md; verify the HTML workspace actually mirrors Epdoc; harden+
repair the whole format stack after the md flip; keep pixel-art, more dynamic, native."* NEVER touches TK2/Prose.

## Headline
Today Epdoc's canonical body is **ProseMirror JSON** (`content.pm.json` in the `.epdoc` package), NOT markdown.
Markdown exists only as a **lossy, one-way, write-only shadow** (`projections/shadow.md`) regenerated each save;
there is **NO markdown-in serializer of record** (only a regex paste parser) and **NO HTML is stored or even
generated** (HTML = the live WKWebView render only). **KEY FINDING: the HTML Workspace is a SEPARATE, independent
document type — NOT a projection of Epdoc** (owner's suspicion confirmed). **De-risker:** the repo is on **Tiptap
3.24.0**, and Tiptap shipped a **first-party Markdown extension + MarkdownManager in 3.7.0** → a real
bidirectional md serializer is an **in-version dependency add, not a custom build.**

## Current format stack
- **`.epdoc` package** (`Models/EpdocPackage.swift:14-52`): `manifest.json` + `content.pm.json` (required,
  canonical ProseMirror JSON) + optional `projections/{shadow.md, plain.txt, search_blocks.jsonl}` + `assets/` +
  `exports/`. Doc-comment states the CURRENT rule: *"Markdown is DERIVED, never canonical"* (`:33`,
  `ProseMirrorMarkdownProjector.swift:15-19`). **No HTML file in the package.**
- **Canonical = ProseMirror JSON.** Bridge body `contentDidChange { json }` = "the canonical .epdoc body"
  (`js-editor/src/bridge/outbound.ts:34-38`), emitted `JSON.stringify(editor.getJSON())` (`index.ts:92`); Swift
  stores verbatim into `package.contentJSON` (`EpdocDocument.swift:278-281`, byte-for-byte `EpdocPackage.swift
  :135-141`).
- **Swift→JS only sends JSON** — one entry `setContent(json)`→`JSON.parse`→`editor.commands.setContent`
  (`inbound.ts:24-33`). **NO `setMarkdown`/`getMarkdown`/`getHTML`** in `js-editor/src` (grep empty).
- **Markdown-IN lossy + regex, paste-only** (`markdown/markdown-paste.ts:20-123`) — not CommonMark/GFM, not used
  for doc load.
- **Markdown-OUT lossy, one-way** — each save `ProseMirrorMarkdownProjector.project()` → `shadowMarkdown`
  (`EpdocDocument.swift:236-238`); explicitly lossy (*"Block IDs, custom marks, embedded extensions don't survive
  the round-trip"* `:20-23`; unknown nodes degrade to raw text `:348-354`). Bidirectional FORBIDDEN today
  (external shadow.md edits imported as reviewable conversion, never silently overwrite `:230-235`).
- **HTML = live render only** (no `getHTML`/`innerHTML` serialize; Tiptap render in the WKWebView).

## HTML workspace — mirror or separate? (THE key finding)
**SEPARATE — its own surface, NOT an Epdoc projection.** Evidence: distinct UTI/NSDocument
`com.epistemos.html-workspace` (`HTMLWorkspaceDocument.swift:74-76`); its package stores RAW authored
`indexHTML`/`styleCSS`/`scriptJS`/`dataJSON` (`:128-135`, `HTMLWorkspacePackage.swift:322-358`); **zero data flow
from Epdoc** (grep `Views/HTMLWorkspace/` + the package for `EpdocPackage|contentJSON|content.pm|ProseMirror` =
nothing). The "open" path proves it: Epdoc fires `requestHTMLWorkspace` (`outbound.ts:73-76`) → `openHTMLWorkspace()`
(`EpdocEditorChromeView.swift:334-335`) → `createUntitledHTMLWorkspaceDocument` (`EpistemosDocumentController
.swift:256-257`) → a **blank starter template** (`HTMLWorkspacePackage.defaultPackage()`). **No Epdoc content is
passed** — it's "launch a fresh HTML scratchpad," not "show this doc as HTML." So: real hand-authored HTML, but
mirrors NOTHING — a sibling editor orphaned from the doc model.

## Best convergence architecture (web, cited)
- **Single-source-of-truth markdown + derived views (Obsidian/Tolaria model)** = the proven, least-muddy pattern:
  `.md` = truth; rich editor + HTML preview are derived + disposable.
- **Tiptap's official Markdown extension (3.7.0; repo on 3.24.0)** = native bidirectional md↔JSON: `getMarkdown()`
  + `setContent(md,{contentType:'markdown'})` + per-node `renderMarkdown()/parseMarkdown()` hooks; built on
  `marked` + a `MarkdownManager`. **In-version add.**
- **Known lossy constructs** (plan fallbacks): table-cell `<br>` dropped (tiptap #7731); consecutive empty
  paragraphs need `&nbsp;`; custom nodes (charts/mermaid/callouts/math/footnotes) need explicit fallback.
- **CRDT (Yjs/y-prosemirror) = WRONG here** — it makes JSON/CRDT the truth (inverts the owner's md-first model)
  + is for multi-peer concurrent editing; adds muddiness for a single-author local doc. **Do NOT adopt.**
- **Pandoc-AST** = gold for EXPORT breadth (md→AST→{html,docx,pdf}) but lossy + less expressive → reserve for
  `exports/` only (repo already uses Pandoc for docx, `EpdocPackage.swift:26`).
- **Verdict:** markdown-canonical with **Tiptap MarkdownManager** as the single md↔JSON serializer; JSON = derived
  editor cache (not truth); HTML = pure render; Pandoc for `exports/` only.

## Recommended convergence design for Epistemos — ONE-WAY DERIVE + serialize-back (NOT bidirectional/CRDT)
Markdown is the authority; one closed loop, ONE writer:
```
content.md (TRUTH) ──parse──▶ ProseMirror JSON (editor cache) ──render──▶ HTML (WKWebView, ephemeral)
      ▲                                                                                  
      └────────────────── serialize on save (getMarkdown) ──────────────────────────────┘
```
- **Canonical md = a real file in the package:** promote `content.md` (was `projections/shadow.md`) to REQUIRED;
  demote `content.pm.json` → `projections/content.pm.json` (regenerable cache). The `.epdoc` envelope stays
  (single Finder icon + assets/manifest/provenance).
- **Editing:** Tiptap mutates JSON live; on the 300ms debounced save (`EpdocDocument.swift:493-511`) call
  `getMarkdown()` → write `content.md` (canonical) + rewrite `content.pm.json` (cache); `manifest.contentHash`
  computed over the **markdown** (replaces SHA-over-JSON `:256-259`).
- **Loading:** read `content.md` → `setContent(md,{contentType:'markdown'})`. If the JSON cache's stored hash
  matches `content.md`'s hash → fast path; else re-derive (self-healing).
- **HTML stays a render**, never stored (except on-demand `exports/*.html` via StaticRenderer/Pandoc).
- **NO CRDT, NO bidirectional sync** — exactly one writer of `content.md`; external md edits = reviewable import
  (keeps the existing `:230-235` rule). Prevents "two writers fighting" muddiness.
- **HTML Workspace → make it a TRUE opt-in projection:** when `requestHTMLWorkspace` fires FROM a doc, seed the
  workspace's `index.html` from a **Tiptap StaticRenderer HTML projection of the current Epdoc** + pixel-art CSS.
  Turns "open blank scratchpad" into "open this doc as editable HTML" (a genuine derived view); standalone HTML
  workspaces unchanged; one-way (HTML-workspace edits don't flow back into md-canonical Epdoc — export/remix
  surface).

## Hardening the format stack (post-flip)
1. **Round-trip idempotency tests** (the core net): `md→JSON→md` byte-stable for the corpus; `JSON→md→JSON`
   semantically equal; cover the lossy cases (table `<br>` #7731, empty paragraphs `&nbsp;`, nested lists). Add
   alongside `ProseMirrorMarkdownProjectorTests` + `EpdocPropertyTests`.
2. **Schema validation + NO silent corruption:** validate JSON vs the Tiptap schema on load+save; on parse
   failure **FAIL LOUD** (END the current silent-degrade `ProseMirrorMarkdownProjector.swift:348-354`); keep
   last-good cache + surface a repair prompt, never write corrupt bytes.
3. **Lossy-construct fallback = HTML-in-markdown:** rich-only nodes → typed fenced block (projector already does
   ```` ```mermaid ````/```` ```epdoc-chart ````/`:::callout`/`$$…$$`/`[^id]`, `:273-345`); where attributes
   would still drop, embed a raw HTML block (CommonMark/GFM allow inline HTML). **No node ever dropped** — worst
   case round-trips as opaque-but-preserved HTML.
4. **Versioned package + migration:** `manifest.schemaVersion` gates forward-incompat (`:208-210`); bump for the
   md-canonical layout (old readers refuse vs misread); one-time migration: existing JSON-canonical `.epdoc` →
   generate `content.md` + bump version on first open.
5. **Hash-pinned consistency:** `contentHash` over `content.md` + a `pmCacheHash` so a stale `content.pm.json` is
   detected + re-derived (the drift detector that keeps projections honest).
6. **Pixel-art, more dynamic, native:** keep the pixel-art CSS in the render + pass it to any HTML projection/
   export; drive from theme tokens (window already tints from theme `:555-557`) so it reacts to theme natively.

## Ordered plan
1. **[S]** Add `@tiptap/extension-markdown` (3.24-compatible first-party) to `js-editor/package.json`; expose
   `getMarkdown()` + `setContent(md,{contentType:'markdown'})` through the bridge (`inbound.ts` + a new
   `contentDidChangeMarkdown` in `outbound.ts`). Pure additive — JSON path untouched. (= SS-O serializer-first.)
2. **[S]** Author the **round-trip + idempotency test suite** BEFORE any truth-flip — the flip is gated on green.
3. **[M]** Flip canonical: promote `content.md` to required, demote `content.pm.json` to cache, move `contentHash`
   onto markdown, add `pmCacheHash` drift detector, bump `schemaVersion` + migration-on-open; replace
   silent-degrade with fail-loud + last-good-cache repair.
4. **[M]** Replace the regex `markdown-paste.ts` document-LOAD path with the real Tiptap markdown parser (keep
   regex only as a paste-time fast path if desired).
5. **[L]** HTML Workspace = true opt-in projection: seed `index.html` from a StaticRenderer HTML projection of the
   current Epdoc + pixel-art CSS on the `requestHTMLWorkspace`-from-doc path; reserve Pandoc for `exports/`. One-way.

## Flags
SS-O/SS-P/the locked decision exist as `docs/research/SS-O_EPDOC_REPAIR_*`, `SS-P_TOLARIA_V2_MD_EDITOR_*`, and the
ledger "EPDOC=MARKDOWN-FIRST" item (the subagent didn't grep that path; its repo findings are verified
file:line). Tiptap markdown-extension version (≥3.7, present in the 3.24 line) is from Tiptap docs, not the repo
(no md dep yet). Constraint honored: nothing touches TK2/Prose — all changes confined to Epdoc (`js-editor/`,
`Models/Epdoc*`, `Engine/Epdoc*`, `Views/Epdoc/`, `Views/HTMLWorkspace/`).

Key files: `Models/EpdocPackage.swift:14-52,135-141,208-210,256-259` · `Models/EpdocDocument.swift:230-238,278-281,
493-511,555-557` · `Engine/ProseMirrorMarkdownProjector.swift:15-23,273-345,348-354` · `js-editor/src/bridge/
{outbound.ts:34-38,73-76, inbound.ts:24-33}` + `index.ts:92` + `markdown/markdown-paste.ts:20-123` · `Views/
HTMLWorkspace/HTMLWorkspaceDocument.swift:66,74-76,128-135` + `HTMLWorkspacePackage.swift:322-358` · `App/
EpistemosDocumentController.swift:256-257` · `Views/Epdoc/EpdocEditorChromeView.swift:334-335`. Sources: Tiptap
3 Markdown docs + 3.0-stable release notes + MarkdownManager API; tiptap #7731; Yjs/y-prosemirror; Pandoc
manual+AST; Obsidian markdown guide. Cross-ref SS-O, SS-P, EPDOC=MARKDOWN-FIRST decision.
