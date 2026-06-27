# SS-P — v2 WebKit Markdown editor: Tolaria-cloned + best-of-breed (2026-06-19)

> ⛔ **OWNER OVERRIDE (2026-06-27) — surface recommendation SUPERSEDED; the rest of this doc
> stands (protected research/pattern reference).** Canonical now:
> `SS-CM_CODEMIRROR_MD_SOURCE_SURFACE_2026_06_27.md`. This doc recommends *against* a second
> WebKit surface ("do NOT add a second WebKit surface… GRAFT onto Epdoc/Tiptap"). **The owner
> decided the opposite AND went further: drop TipTap as the active editor entirely.** FINAL model:
> **CodeMirror-6 markdown-source (new WebView) = PRIMARY**; **Prose (TK2) = 🔒 hard-gate, frozen,
> long-docs**; **Epdoc/TipTap = ⛔ demoted to legacy (parked, not deleted, removal-candidate).**
> Rationale: TipTap was wanted only for rendered tables, which CM6 live-preview covers; the
> AI-diff trail (yellow=add/red=delete) is native to CodeMirror decorations + `@codemirror/merge`,
> second-class on TipTap's node tree; files-as-truth (§16) makes it correctness-safe; and CM's
> buffer *being* markdown deletes the lossy JSON↔md round-trip problem. **Tolaria itself stays
> CLONE-FORBIDDEN: it is AGPL-3.0 (verified twice, live GitHub API) — patterns/clean-room only,
> ZERO code. Permissive substitute = SilverBullet (MIT) + the CodeMirror 6 stack (MIT) +
> atomic-editor (MIT).** Everything else here (agent-MD pattern, pixel-art/macOS-26 skin
> mechanism, license-gating, harvest list) remains canonical and carries to the CM surface.


Read-only research (subagent, web + repo). Feeds the EPDOC/TOLARIA-v2 + dynamic-HTML-DOM + best-of-GitHub-MD +
agent-MD items (covers SS-P AND SS-P+). Pairs with **SS-O** (Epdoc repair). **HARD CONSTRAINT honored: nothing
here touches TK2/Prose** (`Views/Notes/ProseEditorView.swift`, `ProseTextView2.swift`,
`ProseEditorRepresentable2.swift`).

## Headline
**Tolaria is real, and its "Notion-like" editor is literally BlockNote** (Tauri v2 + React 19 + Rust +
**BlockNote** + CodeMirror, **AGPL-3.0**). Crucially: **Tolaria's creator started Tolaria in Swift, hit "very
real limitations in the Markdown editor part," and switched to a web editor** — the EXACT lesson Epistemos
already learned by putting Tiptap in a WKWebView for Epdoc. **Recommended v2: do NOT clone Tolaria's stack
(AGPL-3.0 is incompatible with a closed MAS app), and do NOT add a second WebKit surface. GRAFT Tolaria-class
rich UI/UX onto the SS-O-stabilized Epdoc/Tiptap bridge**, harvesting *patterns* (not code) from
permissively-licensed editors. Epdoc is already a complete Tiptap 3.24 integration (SS-O) — the missing piece is
Notion-grade UX + agent hooks + the pixel/macOS-26 skin, all natively supported by Tiptap. A second WKWebView
host is unjustified cost (duplicates the brotli scheme handler, theme injector, AP1 pipeline).

## Tolaria identified
Local-first, files-first Markdown KB app (macOS/Win/Linux) by Luca Rossi (Refactoring). Every note = clean `.md`
+ YAML frontmatter; vault = git repo; first-class CLI-agent integration (Claude Code/Codex/OpenCode/Gemini) + MCP
where **AI agents appear as git contributors** with diff attribution. Repo `github.com/refactoringhq/tolaria`,
**AGPL-3.0-or-later → NOT cloneable into a closed/MAS app** (ProvenanceGate: `research_only` for code; patterns
fair). Stack: Tauri v2 + React 19 + Rust (filesystem = SOT, Rust IO over Tauri IPC). 4-panel UI: Sidebar · Note
List · **Editor (BlockNote + CodeMirror)** · Inspector. **The "Notion feel" is BlockNote's, not bespoke** →
"make Epdoc look like Tolaria" ≈ "give Epdoc BlockNote-grade block UX on Tiptap," which Tiptap does directly via
DragHandle + slash/BubbleMenu (most ALREADY loaded in Epdoc per SS-O).

## Best GitHub MD editors to harvest (ranked, license-gated)
1. **Tiptap (MIT)** — Epdoc's base. Harvest its first-party **Notion-like template** + DragHandle/slash/
   BubbleMenu patterns. Same engine, zero migration. **Strongest fit.**
2. **Novel `steven-tey/novel` (Apache-2.0)** — Notion-style WYSIWYG **built on Tiptap** + slash + **AI
   autocomplete** + image upload, headless. Same engine, Apple-friendly license. **Best agent+UX reference.**
3. **Milkdown/Crepe (MIT)** — plugin WYSIWYG on ProseMirror; harvest plugin ideas (different engine).
4. **BlockNote `TypeCellOS/BlockNote` (core MPL-2.0; XL incl. AI/multi-column/exporters = GPL-3.0)** — the
   Notion-feel engine Tolaria uses (ProseMirror+Tiptap). **Core MPL-2.0 usable closed (file-level copyleft); the
   AI/agent XL packages are GPL-3.0 → the parts SS-P wants are the parts you CAN'T ship closed.** Gold-standard UX
   reference; do NOT bundle XL.
5. **Plate (MIT, Slate)**, **Lexical (MIT — but `lexical-ios` = TextKit, out of scope by doctrine)**, **Editor.js
   (Apache-2.0, JSON block model = agent-drivable reference)**, **CodeMirror 6 (MIT — the markdown *source* half
   Tolaria pairs with BlockNote)**, **AFFiNE/BlockSuite (architecture reference only)**.
- **Clean (MIT/Apache) for direct lift:** Tiptap, Novel, Milkdown/Crepe, Plate, Editor.js, CodeMirror 6.
  **AVOID for closed MAS code:** Tolaria (AGPL-3.0), BlockNote-XL (GPL-3.0).

## Agent MD editor pattern
Convergent across Tiptap AI Toolkit / Novel / BlockNote AI / Tolaria: **expose the doc as a structured
schema-validated JSON model + give the agent a small set of editing tools (insert/replace/diff blocks) it calls
like any tool, streaming results into the doc.**
- **Tiptap AI Toolkit (closest match):** JSON content model + schema validation; `AIAgentToolkit` exposes the
  doc to an LLM as text-editing tools (generate sections/tables/citations), token-streaming OR wait-for-done,
  inline-apply OR show-diff, **BYO LLM provider**, **combine with your own custom tools** (web/RAG/orchestration)
  — exactly the `agent_core` + MCP seam.
- **Tolaria (filesystem-as-API):** agent never touches UI; reads/writes `.md` via CLI/MCP, shows as git
  contributor. Epistemos has the in-process `agent_core::agent_runtime` loop + MCP bridge; Epdoc's canonical body
  is ProseMirror JSON + `EpdocDocument` persists `package.contentJSON` → agent can drive it two ways.
- **How Epistemos's loop drives Epdoc:** add a Swift→JS command family (extend `EpdocEditorCommand`,
  `EpdocEditorBridge.swift:564-617`, same `window.epistemos.*` eval path): **insertBlock / replaceRange /
  streamInto(blockId) / showDiff** — agent emits tool calls, the bridge applies via the AP1 display-link. The
  rich version of the existing `EpdocCopilotDockView`. **Prereq: SS-O roots #2/#3 (error surfacing + ready
  handshake) MUST land first or streamed agent writes drop silently.**

## Native embedding design — graft onto Epdoc (single surface), NOT a 2nd host
| | (a) 2nd WKWebView (BlockNote/Milkdown) | (b) Graft onto repaired Epdoc/Tiptap ✅ |
|---|---|---|
| License | BlockNote-XL GPL-3.0 (blocked); Milkdown MIT ok | Tiptap MIT + Novel Apache — clean |
| Engine | new ProseMirror/Slate runtime to maintain | same Tiptap 3.24 already shipping |
| Reuse | re-impl brotli handler/theme injector/AP1/autosave/teardown | **reuses all as-is** |
| SS-O work | wasted | directly leveraged |
| Risk | two bridges, 2× WKWebView process cost | one hardened path |
**Reuse map (SS-O):** host `EpdocEditorChromeView.makeNSView:605-649` · pixel CSS injector
`EpdocEditorThemeStyle.applyScript/cssVariables:536-582` (WKUserScript injecting `--epdoc-*` vars + fonts) ·
brotli scheme handler `EpdocEditorBridge.swift:187-329` · shared `WKProcessPool`. Every lift → `F-Proprietary
Compression-ProvenanceGate` (Tolaria/BlockNote-XL → research_only; Tiptap/Novel/Milkdown/CodeMirror →
clean-import).
**"GitHub-grade dynamic HTML/DOM":** richer DOM via Tiptap custom NodeViews Epdoc already scaffolds
(`EpdocChartNode/ImageNode/CalloutNode/CodeBlock`) — add collapsibles, GitHub-style code blocks (copy + lang
pills), Mermaid (wire the unwired `LegacyDiagramNode`), ToC, `[[wikilink]]` hover-cards, drag-reorder feedback
(DragHandle loaded but unparameterized, SS-O gap), CodeMirror-6 raw-md toggle. **No new surface needed.**

## Pixel-art + macOS-26 styling (MAS-safe, in-process)
- **Mechanism EXISTS:** pixel/theme skin = a `WKUserScript` setting `--epdoc-*` CSS vars + per-theme fonts
  (`EpdocEditorThemeStyle`, `EpdocEditorChromeView.swift:536-582`). SS-P extends the SAME injector — no new
  mechanism, MAS-safe by construction.
- **Pixel-art:** pixel fonts (`image-rendering:pixelated`, integer-scaled bitmap typefaces), 1px borders,
  dithered backgrounds, stepped shadows — pure CSS over `--epdoc-*`; ProvenanceGate any bundled font.
- **macOS-26 "Liquid Glass":** macOS 26 reportedly adds `backdrop-filter` compositing behind a transparent
  WKWebView → translucent chrome with `backdrop-filter:blur()` over `nonPersistent()` web content; pair with an
  SVG `feDisplacementMap` for the refraction (CSS-only Liquid-Glass recipe). Availability-gate + theme toggle so
  pixel-art and Liquid-Glass are mutually-selectable skins. **[unverified: confirm `backdrop-filter`-behind-
  WKWebView against Apple/WebKit release notes before relying on it.]**

## Ordered plan (never touches TK2/Prose)
1. **[S, PREREQ]** Land SS-O roots #2/#3 (JS error surfacing + ready-handshake) — else streamed agent writes drop
   silently.
2. **[S]** Harvest Tiptap's Notion-like template + parameterize the loaded DragHandle (drag-reorder) — closes an
   SS-O gap, zero new deps.
3. **[S]** Extend `EpdocEditorThemeStyle`: pixel-art font/border skin as a selectable theme; ProvenanceGate fonts.
4. **[M]** Agent editing command family (`insertBlock`/`replaceRange`/`streamInto`/`showDiff`) on the existing
   bridge — Tiptap-AI-Toolkit pattern, driven by `agent_core` + MCP; richer `EpdocCopilotDockView`.
5. **[M]** macOS-26 Liquid-Glass theme (`backdrop-filter` + SVG `feDisplacementMap`), availability-gated, toggle
   vs pixel-art.
6. **[M]** GitHub-grade DOM: code-block copy/lang-pill, collapsibles, Mermaid (wire `LegacyDiagramNode`), ToC,
   wikilink hover-cards via custom NodeViews.
7. **[L]** CodeMirror-6 (MIT) raw-markdown source toggle + Tiptap→markdown serializer (closes SS-O root #6 lossy
   round-trip).
8. **[L]** Optional collab cursors — Epdoc's `@tiptap/extension-collaboration`+`y-tiptap` deps are
   declared-but-unwired (SS-O); SS-P is where they land, NOT a 2nd surface.

## Flagged / unverified
Novel = Apache-2.0 (repo-verified); Editor.js = Apache-2.0 (not byte-verified, reference-only); BlockNote core
MPL-2.0 vs XL GPL-3.0 confirmed but re-check the exact XL boundary at integration (the licensing landmine);
macOS-26 `backdrop-filter`-behind-WKWebView reported by a secondary source — VERIFY vs Apple/WebKit notes; Epdoc
extension inventory assumed current per SS-O.

Sources: github.com/refactoringhq/tolaria (+ ADR/ARCHITECTURE; HN #47882697 creator note) · refactoring.fm/p/
introducing-tolaria · TypeCellOS/BlockNote + blocknotejs.org (MPL/GPL split) · steven-tey/novel (Apache) ·
Milkdown/milkdown (MIT) · tiptap.dev AI-Toolkit + Notion-like-template · udecode/plate · facebook/lexical ·
codex-team/editor.js · toeverything/blocksuite · LogRocket/nikdelvin/medium Liquid-Glass-CSS. Cross-ref SS-O.

## ‼️ OWNER DECISION (2026-06-19) — Epdoc = MARKDOWN-FIRST auto-mirror (Option B), NOT a separate v2 surface
The owner's original intention is **markdown-canonical Epdoc with a forever auto-mirror** (md ↔ ProseMirror-JSON
↔ HTML), one editor with rich + source views (the Tolaria model), NOT a confusing second "v2" editor. Today Epdoc
is JSON-canonical + HTML-rendered with no md serializer. **Build order (serializer-first, de-risked):** Stage 1 =
the lossless Tiptap↔markdown serializer + CodeMirror-6 source-mode toggle (closes SS-O root #6, gives md import/
export immediately); Stage 2 = flip the stored source of truth to clean `.md` + YAML frontmatter, Epdoc maintains
the live auto-mirror. **Rich-only blocks (charts/complex tables/callouts) → HTML-in-markdown fallback** (valid
clean `.md`, nothing lost; Tolaria/Obsidian pattern). Study + replicate Tolaria's MD patterns (wikilinks,
frontmatter, clean-md-to-disk, WYSIWYG↔source) — patterns not AGPL code. NEVER touch TK2/Prose. Prereq: SS-O
roots #2/#3. (Supersedes SS-P's earlier 'graft rich UI' framing where it conflicts: the canonical-md flip is now
in scope, sequenced after the serializer.) See ledger: "EPDOC = MARKDOWN-FIRST + FOREVER AUTO-MIRROR".

