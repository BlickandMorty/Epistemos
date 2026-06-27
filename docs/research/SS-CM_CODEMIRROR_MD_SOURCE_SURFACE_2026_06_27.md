# SS-CM — CodeMirror markdown-source editor: the primary note surface (2026-06-27)

> 🛠️ **Build/clone/polish detail lives in `CODEMIRROR_MD_V2_BUILD_AND_POLISH_PLAN_2026_06_27.md`**
> (the working doc — clone target = MarkEdit MIT, AI-diff-trail spec, typography, pixel-art +
> Liquid-Glass skins, webview-reification architecture, gotchas). This SS-CM doc is the short
> decision; that one is the deep plan.
>
> **Canonical owner decision doc for the new editor surface.** This doc SUPERSEDES the
> "graft into Epdoc / 2nd surface" framing in `SS-P_TOLARIA_V2_MD_EDITOR_2026_06_19.md` and the
> "three surfaces + step-19 toggle" framing in `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md`.
> Those two docs are PROTECTED and kept as research/pattern references (agent-MD pattern,
> pixel-art skin mechanism, license gating, harvest list). Where they disagree with this doc on
> *surface topology*, THIS doc wins. New doc on purpose — prevents in-place contradiction.
>
> Research basis: two deep web+GitHub passes (2026-06-27), license facts verified against the
> live GitHub REST API (`license.spdx_id`).

## The decision (locked)

Two **living** editor surfaces; one **parked**:

| Surface | Engine | Role | Status |
|---|---|---|---|
| **CodeMirror md-source** | CodeMirror 6 in a WKWebView | **PRIMARY** — most work, markdown-source editing, AI-diff trail | **NEW — build this** |
| **Prose** | TextKit 2 / `ProseTextView2` (native) | Long-form / focus / "very long docs" | 🔒 **HARD GATE — frozen, never touched** |
| ~~Epdoc~~ | TipTap / ProseMirror in WKWebView | — | ⛔ **DEMOTED to legacy — parked, no new investment, removal-candidate once CodeMirror is proven** |

Rationale:
- TipTap was wanted for ONE thing: rendered tables. CodeMirror 6 + `@codemirror/lang-markdown`
  gives Obsidian-style **live preview** (tables/headings/links render inline over raw markdown).
  The only thing TipTap adds beyond that is full Notion-style WYSIWYG block editing — which the
  owner does not use. So TipTap has no remaining active justification.
- **Do NOT delete Epdoc/TipTap now** (working, integrated code; deletion is destructive). Freeze
  it at legacy status alongside Prose; remove later, deliberately, once CodeMirror ships.
- The owner's surface split plays to each engine's strength: **native TextKit 2 handles very
  large documents better than a WebView** (Prose = long docs); WebView CodeMirror is best for
  inline rendering + the streaming AI-diff trail (CodeMirror = working surface).

## Why this SIMPLIFIES files-as-truth (the hidden win)

`EPDOC_MD_V2_BUILD_SEQUENCE` Phases 2–3 (markdown serializer + "canonical flip" + lossy
`JSON↔md` round-trip + `pmCacheHash` drift detector) exist ONLY because TipTap stores a
ProseMirror **JSON tree**, not markdown. **CodeMirror's editor buffer *is* the markdown string** —
there is no tree, no serializer, no round-trip loss, no drift detector. Files-as-truth (§16) gets
*simpler*: the editor reads `content.md` into the buffer and writes the buffer back. Rich blocks
(tables/math/mermaid) are just markdown / fenced blocks / HTML-in-markdown, rendered by decorations.

## License reality — clone Tolaria? NO. (verified twice, live GitHub API)

- **Tolaria is AGPL-3.0.** Cloning/vendoring even one line into a closed App Store / Pro app would
  legally force the ENTIRE app open-source under AGPL. **Non-starter. Patterns/architecture only,
  clean-room, ZERO code.** "It's already hardened" does not transfer by copying — you cannot
  legally inherit Tolaria's hardening.
- **You get the Tolaria experience with a clean license anyway** — because Tolaria itself is built
  on CodeMirror 6 (under BlockNote), and so is Obsidian. Vendor the engine directly:

### The donor stack (all permissive, shippable in closed App Store + Pro builds)
| Component | License | Vendor closed? | Role |
|---|---|---|---|
| **CodeMirror 6 core + view + state** | MIT | ✅ | the editor engine (same as Obsidian) |
| **`@codemirror/lang-markdown`** | MIT | ✅ | markdown parse + highlight (Lezer) |
| **`@codemirror/merge` (`unifiedMergeView`)** | MIT | ✅ | inline add/delete diff + accept/reject — the AI-diff trail |
| **`kenforthewin/atomic-editor`** | MIT | ✅ | ready-made Obsidian-style live preview + `[[wikilinks]]` + click-to-edit tables; byte-exact round-trip. Young/small → pin a version, own the fork |
| **`marimo-team/codemirror-ai`** | Apache-2.0 (+NOTICE) | ✅ | reference for AI suggestion → accept/reject decoration flow |
| **SilverBullet** (architecture only, MIT) | MIT | ✅ patterns | the permissive **clone-as-playbook** twin of Tolaria: files-as-truth `.md` + CM6 + Rust backend |

### Clone-as-playbook target: SilverBullet (MIT), NOT Tolaria
SilverBullet is the closest permissively-licensed architectural twin to Tolaria — files-as-truth
`.md` space + CodeMirror 6 editor + Rust backend. Borrow its CM6 editor setup + space/file-API
design; swap its HTTP file layer for native macOS FS + an FSEvents watcher. Study Tolaria and
Zettlr (GPL — blueprint only) for ideas; copy their code never.

### Landmines (do not trip)
- **Vrite = AGPL-3.0** — disqualified.
- **BlockNote** — core is MPL-2.0 (OK, file-level copyleft) but `packages/xl-*` (the AI bits) are
  GPL-3.0. If ever borrowed, EXCLUDE `xl-*`.
- **GitHub API `NOASSERTION` is not a license** — always open the LICENSE file (Foam returns
  NOASSERTION but is genuinely MIT; Joplin returns NOASSERTION but is AGPL).
- Every JS/Rust lift goes through `F-ProprietaryCompression-ProvenanceGate` (MIT/Apache →
  clean-import; AGPL/GPL/no-license → research_only).

## The AI-diff trail (yellow=add / red=delete) — first-class in CodeMirror

This is the requirement that decisively favors source-first CM6 over any rich-tree editor:
- **Stream edits in:** `view.dispatch({ changes: { from, to, insert: chunk } })` per token; positions
  auto-map across transactions via `ChangeSet`. No buffering — forward every token (STREAM-EVERYTHING).
- **Inline diff decorations:** `@codemirror/merge` `unifiedMergeView({ original, allowInlineDiffs: true })`
  renders deletions as red/strikethrough widgets + additions as green/added marks, with per-chunk
  `acceptChunk`/`rejectChunk`. Or hand-roll `Decoration.mark({class:'cm-ai-added'})` /
  `cm-ai-deleted` driven by a `StateField` for full accept/reject lifecycle control. Pixel-art skin
  (yellow add / red delete) = CSS over those classes.
- In rich-tree editors (TipTap/Lexical/Milkdown) none of this is first-class — diffs would be a
  custom tree-space plugin, and TipTap's change-tracking is a PAID Pro extension.

## Obsidian-style live preview — how it actually works (so we build it right)

`@codemirror/lang-markdown` alone does NOT render — it's parser + highlight + keymaps only
(`**bold**` stays literal). The Obsidian effect is built on CM6 decorations:
- `Decoration.replace` → hide syntax markers (`#`, `**`, `[]()`), optionally swap a widget
- `Decoration.mark` → style visible text (big/bold heading text)
- `Decoration.widget` → render block elements (tables, images, math) as real HTML
- `Decoration.line` → style line wrappers
- `EditorView.atomicRanges` so the cursor skips hidden ranges
- a `ViewPlugin`/`StateField` that reveals markers only on the cursor's current line
`atomic-editor` (MIT) already implements this — vendor or harvest it rather than rebuild.

## Sync / latency design (two surfaces, one `.md`)

- **Single source of truth:** `<vault>/<note>.md` (§16). The editor buffer ⇄ that file.
- **One-writer + debounced autosave** (~300ms) → write `content.md`.
- **FSEvents watcher with echo-suppression** (ignore self-writes via a recently-written-hash set)
  → detect external changes (agent edits OR the other editor).
- **External change while clean → reload; while dirty → non-destructive conflict affordance.**
  Same note open in both at once is rare; if it happens, a soft "open elsewhere" indicator.
- **Honest caveat:** data integrity across both surfaces is fully solvable (one `.md` file).
  Pixel-identical visual parity between a native TextKit editor and a WebView CodeMirror editor is
  NOT achievable (different renderers). Target = **data-consistent + visually-coherent** (shared
  theme tokens / pixel-art CSS vars on CM; native theming on Prose), not identical.

## What carries over from the protected docs (still canonical)

- **Pixel-art + macOS-26 skin mechanism** (SS-P §"Pixel-art + macOS-26 styling"): the same
  `WKUserScript` CSS-var injector pattern (`EpdocEditorThemeStyle`) applies to the CodeMirror
  WebView. Reuse the mechanism; no new mechanism needed.
- **Agent-MD editing pattern** (SS-P §"Agent MD editor pattern"): expose the doc + give the agent
  insert/replace/diff tools, stream results in. In CodeMirror this is `view.dispatch` + the diff
  decorations above, driven by `agent_core` + MCP.
- **License gating + harvest list** (SS-P §"Best GitHub MD editors"): unchanged.
- **Wikilinks/backlinks/frontmatter/properties** (EPDOC_MD_V2 Phases 4 + 7): same features, now
  built on CM6 decorations + the native FS layer instead of TipTap NodeViews.
- **Reusable WebView host plumbing** (brotli scheme handler, shared `WKProcessPool`, theme
  injector, autosave pipeline): the CodeMirror surface reuses these host pieces — they are
  editor-agnostic. (The host is the "backend that does the work"; the editor library is swappable.)

## Build sequence (CodeMirror surface) — never touches Prose

1. **[S]** Stand up a new WKWebView surface hosting CodeMirror 6 + `@codemirror/lang-markdown`
   from the JS bundle (reuse the brotli scheme handler + shared `WKProcessPool` + theme injector).
   Read/write `content.md` directly (no serializer). Add to the JS bundle build.
2. **[S]** Round-trip safety: buffer→`content.md`→buffer is byte-stable by construction; add a
   test asserting it, plus the FSEvents watcher + echo-suppression + dirty/clean reconciliation.
3. **[M]** Obsidian-style live preview via decorations (harvest `atomic-editor`, MIT): hide-markers,
   inline heading/bold/link styling, table widget, task lists. ProvenanceGate the lift.
4. **[M]** Pixel-art skin via the existing `EpdocEditorThemeStyle` CSS-var injector (yellow/red
   tokens reserved for the diff trail); macOS-26 Liquid-Glass theme toggle (availability-gated).
5. **[M]** AI-diff trail: `@codemirror/merge` `unifiedMergeView` (or the hand-rolled StateField)
   driven by `agent_core` + MCP; `view.dispatch` streaming per token; per-chunk accept/reject.
6. **[L]** `[[wikilinks]]` (atomic-editor's resolver + Halo autocomplete) + backlinks panel
   (`WikilinkResolver` over the shadow index + `SDPage`) + YAML frontmatter parse/edit
   (`EpdocFrontmatter` reused) + properties panel + tag index.
7. **[L]** Native-tabbed note workspace hosting CodeMirror panes (same "native frame, web content"
   architecture as the Goose surface) — optional, when the surface is proven.

## Cross-cutting constraints (every step)
- **NEVER touch TK2/Prose** — hard gate.
- **One writer** for `content.md`; agent edits + property panel route through the same writer.
- **No buffering** of streamed agent edits — `view.dispatch` per token.
- **License-check every lift via ProvenanceGate** (CM6/lang-markdown/merge/atomic-editor = MIT;
  SilverBullet/Zettlr/Tolaria = patterns only).
- **Perf before+after each step** (owner's standing gate).
- **Do not delete Epdoc/TipTap** until CodeMirror is proven; freeze, don't surgery.

## Cross-refs
- Protected research kept as pattern references: `SS-P_TOLARIA_V2_MD_EDITOR_2026_06_19.md`,
  `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md`, `SS-O_EPDOC_REPAIR_2026_06_19.md`,
  `SS-EM_EPDOC_FORMAT_CONVERGENCE_2026_06_19.md`, `SS-2S_TWO_SURFACE_FIDELITY_PROSE_EPDOC_2026_06_20.md`.
- Markdown-source-of-truth: `SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` §16.
