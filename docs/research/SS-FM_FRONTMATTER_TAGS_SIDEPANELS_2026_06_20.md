# SS-FM — Frontmatter · properties · tags · backlinks · side-panels for md-first Epdoc (2026-06-20)

Read-only research (subagent), repo + web. Feeds the EPDOC md-v2 frontmatter/tags/side-panels ledger item.
Owner: *"frontmatter, tags etc. — all the things Obsidian/Notion/Logseq/Tolaria have, with the side panels like
the frontmatter [panel]."* NEVER touches TK2/Prose, vault, or graph (those are reference/resolution-targets only).
Cross-refs SS-EM (md-first), SS-O/SS-P.

## Headline — what exists vs net-new
Epistemos **ALREADY OWNS a complete Notion-style typed-property data model + query engine for `.epdoc`**
(`EpdocProperty.swift`, `EpdocDatabase.swift`) — 8 property kinds, stable-id options, manifest-backed persistence,
sort/group/schema-union — but **ZERO property/inspector UI** and **no YAML-frontmatter parse** (properties live in
`manifest.metadata`, not a markdown frontmatter block). Separately there's a battle-tested **wikilink/backlink
substrate** (`WikilinkResolver`, `SDPage.wikilinkReferences`, `NoteBacklinksPopover`) + a JS wikilink extractor —
but **none wired into Epdoc's chrome** (which has only floating caret-glued panels, NO right-rail inspector). So
SS-FM is mostly **surface + wiring on top of a strong existing model** + one real net-new piece: a YAML-frontmatter
↔ `manifest.metadata` bridge (gated on the SS-EM md-canonical flip) + an inline `#tag` Tiptap node.

## Epdoc metadata/tags/links today
- **Typed property MODEL — rich, ~100% reusable:** `Engine/EpdocProperty.swift` — `PropertyKind` 8 cases
  (select/multiSelect/date/number/checkbox/url/email/text `:34-43`); `PropertyDef` + stable-id `PropertyOption`s
  (`:124-205`); `EpdocPropertyValue` tagged union (`:279-344`); `EpdocPropertyMetadata` reads/writes into
  `manifest.metadata` under `"properties.<id>"` (`:351-414`). Tested (`EpdocPropertyTests.swift`).
- **Property QUERY engine — exists:** `Engine/EpdocDatabase.swift` — `EpdocDatabaseRow` (`:33-49`),
  `sorted(byPropertyID:) :107`, `grouped(byPropertyID:)` (multiSelect → one row/tag = **free tag index** `:126`),
  `schemaUnion() :141-153`.
- **Metadata bag:** `Models/EpdocManifest.swift:126 metadata:[String:String]?` (current property home). NO
  frontmatter, NO `tags` field, NO wikilink/backlink manifest fields.
- **NO YAML frontmatter parse in Epdoc** — `ProseMirrorMarkdownProjector.swift:247` emits `---` only as an
  `<hr>`, never a frontmatter fence (SS-EM confirmed no md serializer).
- **Wikilinks: render-only in JS, NOT resolved** — `js-editor/src/graph/document-graph.ts` extracts `[[...]]` for
  the Mermaid doc-graph (`wikilinkLabels :221-231`); `markdown-paste.ts:389` recognizes `[[` on paste. No
  clickable node, no hover-card, no backlink resolution in Epdoc.
- **Chrome has NO inspector rail** — `Views/Epdoc/EpdocEditorChromeView.swift` body = `ZStack` of WKWebView +
  floating panels (slash `:410`, bubble `:422`, KaTeX `:436`) + footer/copilot overlays + `.toolbar`. No
  `HSplitView`/right rail. Swift→JS extension point = `EpdocEditorCommand.runCommand(name:argsJSON:)`
  (`EpdocEditorBridge.swift:586`), AP1 batched eval (`:869-932`).
- **NO inline `#tag` Tiptap node** (grep empty). Existing extensions: slash/callout/chart/code-block/image/
  mermaid/markdown-input-rules/paste-classifier.

## Reusable app substrate (NOT graph — reference/resolution only)
- **`Engine/WikilinkResolver.swift` = the reusable backlink/resolution engine** — `extractDestinations(from:)`
  parses `[[wikilinks]]` + `](md-links)` (`:14-30`); `canonicalDestination` strips `|alias`/`^block`/`#heading`
  (`:127-141`); `lookupKeys`/`lookupKeysForPage` (`:147-177`). Pure, `nonisolated`, no SwiftData/TK2 dep — **safe
  to call from Epdoc** for backlinks.
- **Vault note shape (mirror-only, TK2 — don't modify):** `Models/SDPage.swift` — `tags:[String] :34`,
  `frontMatter:[String:String] :144-171`, `wikilinkReferences:[String] :90-93`. The proven shape + the link
  resolution TARGET (Epdoc↔vault-note links).
- **Vault backlink indexing pattern:** `Sync/VaultIndexActor.swift:1683-1723` (crawl→`WikilinkResolver
  .extractDestinations`→persist) — imitate read-only for Epdoc.
- **Backlinks UI to mirror (don't modify):** `Views/Notes/NoteBacklinksPanel.swift` `NoteBacklinksPopover`
  (`BacklinkSource={.wikilink,.graphEdge}`).
- **Halo shadow index = cross-doc resolution backbone** — `[[note]]` autocomplete can reuse `onSearchLinks`
  already in the chrome controller (`EpdocEditorChromeView.swift:146-147`, the W8.4 Halo-backed Insert-link
  picker).
- `App/ChatCoordinator.detectLinkedPageId:6280-6320` — the agent already understands `[[wikilink]]`/`Note:` →
  `SDPage` (SS-P chat integration).
- **Graph `EntityExtractor`/Ontology — REFERENCE ONLY, never depend on it.**

## Proven patterns (web)
- **Obsidian Properties** — YAML frontmatter ↔ typed Properties UI (text/number/checkbox/date/datetime/list/
  links); date ISO-sortable, list→YAML array; Epistemos's 8 `PropertyKind`s already cover this.
- **Logseq** — `key:: value` page vs block properties; linked/unlinked references panel; `:closed-values` =
  basis for `PropertyOption` (`EpdocProperty.swift:54-56`).
- **Notion** — right-side properties panel (hidden by default, "View details").
- **Tolaria (CLOSEST fit, md-first desktop)** — `EditorRightPanel` mounts **Properties** + **TOC** as
  MUTUALLY-EXCLUSIVE right panels (200-500px/hidden) via `useRightPanelExclusion`; Properties edits frontmatter
  (toggle **Cmd+Shift+I**); blank scalar renders as editable empty row; bottom read-only derived metadata.
  **Exactly the owner's "side panels like the frontmatter panel."**
- **Best fit:** Obsidian typed-property model + Tolaria right-rail inspector + exclusive panels; tags as inline
  `#tag` AND frontmatter `tags:`; Logseq/Obsidian linked-references for backlinks.

## The design (pixel-art, native, md-first)
- **(a) Properties right-inspector panel** = net-new SwiftUI `EpdocPropertiesPanel` (mirror `NoteBacklinksPopover`
  styling + `EpdocSlashMenuView` pixel-art chrome `:114-169`) rendering `EpdocPropertyMetadata.properties(in:
  manifest)` (`EpdocProperty.swift:378`); per-kind native control (select→menu, multiSelect→token, date→DatePicker,
  number→stepper, checkbox→Toggle, text/url/email→TextField); writes → `withProperty(...)` → `replacingMetadata`
  (`:393-401`) → existing autosave (`EpdocEditorChromeView.attachAutosavePipeline:260-269`). **~100% model reuse;
  only the view + frontmatter bridge are new.**
- **Frontmatter↔properties bridge (the one real net-new model piece, SS-EM-coupled):** when SS-EM promotes
  `content.md` canonical, add a `---\n…\n---` YAML block = on-disk serialization of `manifest.metadata` props
  (+ `tags:`). Net-new: a small `EpdocFrontmatter` parse/serialize + a projector change so `---`-at-doc-start is
  frontmatter not `<hr>` (`:247`). `manifest.metadata` stays in-memory authority; frontmatter = its md projection
  (SS-EM "one writer").
- **(b) Tags** — frontmatter `tags:` (a `multiSelect` property — already supported; `EpdocDatabase.grouped` =
  free tag index `:126`) + inline `#tag` net-new Tiptap node (input-rule + node, pixel-art via `--epdoc-*` CSS
  `:536-587`) + a native Tag-index panel.
- **(c) Wikilinks + backlinks** — clickable `[[note]]` Tiptap node (net-new; the `[[` recognizer + `wikilinkLabels`
  regex already exist to seed it) + Halo autocomplete reusing `onSearchLinks:146`; **Backlinks panel reuses
  `WikilinkResolver`** against shadow index + `SDPage` (mirror `VaultIndexActor:1683/1715` read-only); UI mirrors
  `NoteBacklinksPopover`.
- **(d) Mount** — add a **right inspector rail** to `EpdocEditorChromeView.body`: wrap the `ZStack` in an
  `HSplitView`/trailing collapsible rail (200-500px, Tolaria model) with exclusive tabs **Properties/Backlinks/
  Tag-index/TOC** (one `@Observable` enum on the controller); toggle **Cmd+Shift+I** alongside Cmd-S (`:482-487`).
  All pixel-art via theme tokens.
- **(e) Agent (chat) read/write (SS-P):** the agent already reads `[[wikilinks]]` (`ChatCoordinator:6280`);
  property edits from chat go through the SAME `EpdocPropertyMetadata.withProperty` writer (single source of
  truth) via `runCommand(name:argsJSON:)` (`EpdocEditorBridge.swift:586`) — no divergent writers (honors SS-EM).

## Ordered plan
1. **[S]** Read-only Properties panel + frontmatter parse — `EpdocPropertiesPanel` (read-only) +
   `EpdocFrontmatter` YAML parse (`content.md` frontmatter → `manifest.metadata`) + `---`-at-start = frontmatter
   in the projector. **~95% reuse**; net-new = 1 view + 1 small parser. Gated on SS-EM Stage-1 (`getMarkdown`).
2. **[M]** Editable typed properties + tags + tag index — wire each kind's control → `withProperty` → autosave;
   add/remove defs; frontmatter `tags:` + inline `#tag` Tiptap node (net-new JS) + Tag-index panel via
   `EpdocDatabase.grouped`. Net-new: JS tag node + CSS + inspector rail + Cmd+Shift+I.
3. **[L]** Wikilinks + backlinks panel + full inspector — clickable `[[note]]` node + Halo autocomplete (reuse
   `onSearchLinks`); backlinks via `WikilinkResolver` + shadow index + `SDPage`; Backlinks panel mirroring
   `NoteBacklinksPopover`; exclusive-panel inspector (Properties/Backlinks/Tags/TOC). Net-new: JS wikilink node,
   Epdoc backlink index, panel chrome.

## Flags
The frontmatter↔`manifest.metadata` bridge is COUPLED to + gated on SS-EM's md-canonical flip (`content.md` +
`getMarkdown` must land first); until then properties persist only in `manifest.metadata`, not on-disk YAML.
Tolaria internals from public docs/commit, not the repo. Nothing touches TK2/Prose, vault, or graph (SDPage/
NoteBacklinksPopover/EntityExtractor cited as reference/resolution targets only).

Key files (reuse): `Engine/EpdocProperty.swift:34-414` · `Engine/EpdocDatabase.swift:33-153` · `Models/Epdoc
Manifest.swift:126` · `Engine/WikilinkResolver.swift:14-177` · `Views/Notes/NoteBacklinksPanel.swift` (mirror) ·
`Models/SDPage.swift:34,90-93,144-171` (mirror, TK2) · `Sync/VaultIndexActor.swift:1683-1723` (pattern) ·
`Views/Epdoc/EpdocEditorChromeView.swift:146-147,404-491,536-587` · `Engine/EpdocEditorBridge.swift:586` ·
`Models/ProseMirrorMarkdownProjector.swift:247` · `js-editor/src/graph/document-graph.ts:119-231` +
`markdown/markdown-paste.ts:389` + `extensions/` (add tag+wikilink nodes). Net-new: `EpdocFrontmatter`,
`EpdocPropertiesPanel`/rail, `tag-node.ts`, `wikilink-node.ts`, Epdoc backlink index. Sources: Obsidian Properties;
Logseq built-in properties; Notion database properties; Tolaria Properties/Editor docs. Cross-ref SS-EM, SS-O,
SS-P.
