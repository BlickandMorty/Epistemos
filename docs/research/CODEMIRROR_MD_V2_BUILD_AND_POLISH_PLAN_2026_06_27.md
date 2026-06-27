# CodeMirror md-v2 — build, clone & polish plan (2026-06-27)

> **The working doc.** This is the doc to iterate on. It is the deep build/clone/polish companion
> to the decision doc `SS-CM_CODEMIRROR_MD_SOURCE_SURFACE_2026_06_27.md` (which locks *what* and
> *why*). This doc locks *which to clone* and *how to make it feel premium*, backed by four deep
> research passes (2026-06-27): Tolaria deep-dive, AI-edit UX, Mac-native polish, and the
> Tauri/webview-reification architecture. Protected pattern references (do not contradict, do not
> delete): `SS-P_TOLARIA_V2_MD_EDITOR_*`, `EPDOC_MD_V2_BUILD_SEQUENCE_*`, and the SS-O/EM/FM/IR slices.

## TL;DR — the answers

- **Clone target = MarkEdit (MIT), not Tolaria.** MarkEdit (`github.com/MarkEdit-app/MarkEdit`) is a
  shipping, MIT-licensed, **native macOS AppKit app that is CodeMirror 6 in a WKWebView** — our exact
  "webview reification" architecture. It already solves nearly every gotcha (focus sync, IME, scroll,
  clipboard, native Edit menu, Compartment config, CSS-var theming). **Clone/study it before writing
  code.** Tolaria is **AGPL-3.0 → clean-room patterns only, ZERO code** (verified twice).
- **Supporting donors (all permissive):** `@codemirror/merge` (MIT, the AI-diff engine),
  `kenforthewin/atomic-editor` (MIT, Obsidian-style live preview + wikilinks),
  `@marimo-team/codemirror-ai` (Apache-2.0, AI-edit accept/reject flow), `blueberrycongee/
  codemirror-live-markdown` (MIT, live-preview design doc). SilverBullet (MIT) for files-as-truth
  *patterns* (it's a web server, not a Tauri app — don't model the shell on it).
- **Architecture:** native Swift frame + custom native tab bar + WKWebView CM6 panes + brotli-served
  bundle + FSEvents watcher. Reuse our existing host plumbing (brotli scheme handler, CSS-var
  injector, Swift↔JS bridge). On macOS, **Tauri *is* WKWebView under the hood** — there is no engine
  to gain by going Tauri; we keep Swift+AppKit and mirror only Tauri's *conventions*.
- **AI diff trail (yellow=add / red=delete):** decoration-driven *preview*, atomic commit on accept.
  This is a real market gap (Cursor + Zed both shipped live in-editor agent typing and *removed* it;
  users want it back). Doing it well, inline, live = best-in-class differentiator.

## 1. Clone & license ledger (verified vs live GitHub API)

| Project | License | Use | What for |
|---|---|---|---|
| **MarkEdit** | **MIT** ✅ | **CLONE/STUDY — primary blueprint** | native Swift + WKWebView + CM6; focus/IME/scroll/clipboard/Edit-menu/Compartment/CSS-var patterns |
| **@codemirror/merge** (`unifiedMergeView`) | **MIT** ✅ | vendor | the AI add/delete diff + per-chunk accept/reject engine |
| **kenforthewin/atomic-editor** | **MIT** ✅ | vendor/harvest | Obsidian-style live preview + `[[wikilinks]]` + click-to-edit tables; byte-exact round-trip |
| **@marimo-team/codemirror-ai** | **Apache-2.0** ✅ (+NOTICE) | harvest | AI-edit flow; `next-edit-prediction/decorations.ts` = mark-removed + widget-added (invert colors) |
| **blueberrycongee/codemirror-live-markdown** | **MIT** ✅ | harvest | live-preview design doc + the stability guards |
| **asadm/codemirror-copilot** / **saminzadeh/...inline-suggestion** | **MIT** ✅ | harvest | ghost-text StateField/ViewPlugin pattern |
| **Smart Composer** (glowingjade) | **MIT** ✅ | patterns | "lazy edit + fast-apply" pipeline, `@`-mention RAG |
| **SilverBullet** | **MIT** ✅ | patterns | files-as-truth space + rebuildable index (it's a web server, not a shell model) |
| **Tolaria** | **AGPL-3.0** ⛔ | **patterns/clean-room ONLY, ZERO code** | UX, 4-panel layout, git-as-AI-audit, method, watcher design |
| **Zed / Copilot for Obsidian / Khoj / Reor / Notesnook** | GPL/AGPL ⛔ | patterns only | edit-prediction UX, yellow-preview, RAG |
| **Vrite** | AGPL-3.0 ⛔ | disqualified | — |
| **BlockNote** | core MPL-2.0 / `xl-*` GPL-3.0 ⚠️ | core OK, **exclude `xl-*`** | (not needed — we're source-first) |

**License hygiene:** every lift → `F-ProprietaryCompression-ProvenanceGate`. GitHub API `NOASSERTION`
is NOT a license — open the LICENSE file (Foam returns NOASSERTION but is MIT; Joplin returns it but
is AGPL). **Do not read Tolaria's source while implementing** — keep the reimplementation independent.

## 2. Architecture — "webview reification" (native Swift frame, web content)

**Framing correction (from research):** "Tauri vs WKWebView" is a false dichotomy on macOS — Tauri's
WRY layer *is* a Rust wrapper over the same `WKWebView` / `WKURLSchemeHandler` / `WKScriptMessageHandler`
we call from Swift. For a macOS-only commercial app with existing Swift plumbing, **the Swift shell
wins** (no second toolchain, native chrome, MAS-clean). Mirror Tauri's *conventions*, not its machinery.

**Recommended shape:**
- **Shell & tabs:** native AppKit/SwiftUI window; a **custom tab bar driving a single content area**
  (NOT SwiftUI `TabView` — eager render, no discard hook; NOT single-controller NSWindow tabbing —
  "do not use in production"). Optional secondary "open in new tabbed window" via NSWindow tabbing.
- **Webview ownership:** an `@Observable` `EditorPaneStore` holding `panes: [Tab.ID: WKWebView]`,
  lazily created, **bounded live set (active + 2–3 MRU) with LRU discard** driven by the existing
  `DispatchSourceMemoryPressure` handler. A thin `NSViewRepresentable` returns a stable container and
  installs the right webview in `updateNSView`. (SwiftUI identity churn recreates webviews + orphans
  them — own them in the model, keyed by tab id.)
- **Bundle:** **reuse the brotli scheme handler verbatim** — serve the CM6 bundle single-origin
  (`epdoc://localhost/...` or a new `cmsource://`). NO `file://` (opaque origin breaks `fetch`/ESM),
  NO localhost server / subprocess (MAS + hardened runtime forbid it; matches CLAUDE.md).
- **Bridge:** reuse the Swift↔JS bridge. Three tiers (mirror Tauri): `WKScriptMessageHandlerWithReply`
  for commands (load/save/getText → `Result`); injected JS event bus via `callAsyncJavaScript` for
  native→JS pushes (file-changed, theme-changed); streaming/custom-scheme response for large payloads.
  **Register handlers through a weak proxy + explicit `removeScriptMessageHandler` in teardown**
  (otherwise the handler strongly retains and leaks the entire WebContent process). Batch/debounce —
  edit loop stays in JS, sync to native on idle/save.
- **Theming:** reuse the CSS-var injector — push native colors as `:root` custom properties referenced
  by a CM6 `EditorView.theme`; inject high-frequency changes as `<style>` rules (cheaper than reconfigure).
- **Filesystem (files-as-truth, §16):** FSEvents tree-watch (or the Rust `notify` core) over the vault.

**Correction to SS-CM's "shared WKProcessPool" note:** `WKProcessPool` is a **no-op on macOS 12+**
(WebKit manages process placement itself). Keep sharing it (harmless, helps older OSes) but **the real
memory lever is the bounded live-set + LRU discard**, not the pool. Each WKWebView spawns 2 extra OS
processes (~200 MB possible); there is no in-place "hibernate" — discard = release + recreate, and save
state eagerly (no "tab discarded" event fires).

**Entitlements (both builds):** `com.apple.security.network.client` (**required for WKWebView even for
local content** — WebContent is out-of-process), `com.apple.security.cs.allow-jit` (Apple Silicon
JavaScriptCore), Hardened Runtime (notarization), App Sandbox (MAS). Gate `webView.isInspectable`
behind `#if DEBUG`.

## 3. Editor experience — Obsidian-style live preview (CM6)

The buffer is **always raw markdown**; rendering is a pure view-layer overlay → copy/save/export stay
byte-for-byte identical. `@codemirror/lang-markdown` alone does NOT render — build the effect with
decorations:

- **The reveal rule** (run per node every transaction): show raw syntax when a selection range overlaps
  the node, else render. `shouldShowSource(state, from, to)`.
- **Four decoration types:** `mark` (style inline emphasis; hide `**`/`_` via `max-width:0;opacity:0` +
  transition — **never `display:none`**, avoids reflow); `replace` (hide range, optional `WidgetType`:
  images/tables/math→KaTeX/`[[wikilink]]`→pill; drop when cursor enters); `widget` (insert DOM without
  removing text — checkbox next to `- [ ]`); `line` (heading sizing via `font-size:0.01em` on the `#`,
  blockquote/callout backgrounds).
- **Hard rule:** layout-changing decorations (block widgets, heading sizing, multi-line replace) MUST
  come from a **StateField**, not a ViewPlugin (ViewPlugin runs after layout). Narrow invalidation:
  re-decorate only changed lines.
- **Atomic ranges:** feed `EditorView.atomicRanges` the same range set as the replace decorations so
  rendered chips arrow as one unit. `WidgetType.eq()` lets CM6 reuse widget DOM.
- **Two stability guards:** mouse-freeze guard (suppress rebuilds during drag-select → no flicker) +
  zero layout shift (every line same height raw-or-rendered → smooth WKWebView scrolling).
- **Study:** `kenforthewin/atomic-editor` (end-to-end) + `blueberrycongee/codemirror-live-markdown`
  (design doc, source of the guards) + `segphault/codemirror-rich-markdoc` (block-replace).

## 4. The AI diff trail — yellow=add / red=delete (the differentiator)

**Market gap:** Cursor + Zed both shipped a live moving-cursor agent-edit experience and **removed it**
for reliability/tokens; users file issues asking for it back. Nobody currently paints a *live* in-doc
diff with strikethrough deletions as the agent writes. **Do this well = best-in-class + on-brand for pixel-art.**

**Color note (decide with eyes open):** red+strikethrough IS the universal delete signal (VS Code, Word,
Docs). Green=add is the universal add signal. **Yellow=add diverges** — yellow/amber is the established
"changed/modified/attention" color. An AI rewrite *is* a modification, so yellow reads as "AI touched
this — review it." Defensible **brand** choice; just know no major editor uses yellow for additions.

**Architecture: decoration-driven preview, atomic commit on accept** (avoids the reliability trap that
made Cursor/Zed retreat). Don't mutate the saved buffer token-by-token — render the *visual* trail with
decorations over a staging layer; apply real `view.dispatch` changes only on accept.

**Fast path — `@codemirror/merge` `unifiedMergeView` (MIT):** keeps inserted/changed text in the live
doc (highlight → restyle yellow), re-injects deleted text as `<del>` widgets (→ restyle red
strikethrough), built-in `acceptChunk`/`rejectChunk` + `mergeControls` hook for pixel-art buttons.
- Drive the base live as the stream arrives via `originalDocChangeEffect` injected through
  **`EditorState.transactionFilter`** (NOT a `transactionExtender` — extenders miss the merge
  extension's own changes; maintainer-confirmed).
- CSS hooks to restyle: `cm-changedText`, `cm-changedLine`, `cm-insertedLine`, `cm-deletedText`/
  `cm-deletedChunk`, `cm-changeGutter`, `cm-chunkButtons` (default green `#2a2` / red `#d43` → override).

**Hand-rolled path (max control):** added → `Decoration.mark({class:"cm-ai-added"})`; deleted →
`Decoration.widget({side:1})` rendering `<del class="cm-ai-deleted">` (deleted text isn't in the doc, so
it must be a widget). Held in a `StateField<DecorationSet>`. **Two non-negotiable rules:** (1)
`deco.map(tr.changes)` FIRST every update; (2) any position-carrying `StateEffect` must define `map()`.
Stream tokens with `view.dispatch({changes, effects})`; batch under high throughput; use
`change.mapPos(pos, assoc)` with the right `-1/1` bias so the yellow span grows with appended text.
- **Borrow:** `@marimo-team/codemirror-ai` (Apache-2.0) `next-edit-prediction/decorations.ts` (added→
  widget ghost, removed→mark line-through) — invert to yellow/red.

**Accept/reject UX (table-stakes — implement all three tiers; users revolt when removed):**
- per-chunk ✓/✗ (pixel-art buttons via `mergeControls`) → per-note → whole agent turn (Keep All / Undo
  All) with a turn-level checkpoint.
- keys: `Tab`/`Cmd+Enter` accept chunk, `Esc`/`Cmd+Backspace` reject, `Cmd+→` accept next word.
- live caret: a blinking **pixel-block caret widget** at the stream head ("AI is writing here"); gutter
  arrow to off-screen active edits (Copilot NES pattern).
- "Explore vs Execute" mode toggle (Craft): approve-first vs live-apply, as a setting.
- context chip: when the edit used `[[wikilinks]]`/vault RAG, show a small "context: 3 notes" chip
  (Copilot-for-Obsidian's backlink-weighted relevance is the reference). All driven by `agent_core` + MCP.

## 5. Polish — typography, modes, micro-interactions

**Polish checklist (the ~15 that separate premium from mediocre):** enforced measure (cap column ~66ch;
offer 64/72/80 like iA Writer); a purpose-chosen typeface; generous leading 1.4–1.5 + `#333` on `#fff`
(not pure black/white); inline hide-markdown live preview with **no layout shift**; sub-frame input
latency (the biggest "feel" lever — Zed's lesson); typewriter scrolling; focus mode (dim non-active
sentence/paragraph via `color` in dark mode); hover-revealed block handles + whole-row highlight; strict
single-owner slash menu (opens only on typed `/`); in-place empty states (one faint line, vanishes on
keystroke); refined caret + glyph-only selection; ONE signature delight animation (Craft's tilt) on
`transform`/`opacity` only; layered design-token theme system (foundation→semantic→component CSS vars;
relative `--font-*` in editor, fixed `--font-ui-*` in chrome); markdown niceties (input rules, smart
lists, auto-pair, autolink, smart quotes); accessibility (honor `prefers-reduced-motion` /
`-reduced-transparency` / increase-contrast).

**Typography — clean theme (default):**
```
--font-text: "iA Writer Duo","IBM Plex Mono",ui-monospace,"SF Mono",monospace;  /* duospace draft feel */
--font-read: "New York","Iowan Old Style",Georgia,serif;     /* reading/preview */
--font-ui:   -apple-system,"SF Pro Text",system-ui,sans-serif;
--font-text-size: 16px;  --line-height-normal: 1.5;  --line-height-tight: 1.3;
measure: 66ch (toggle 64/72/80);  body #333 on #fff (dark #f2f2f2 on ~#1e1e20);  --font-ui-size: 13px;
```
(iA Writer's Duo/Quattro fonts are open-source IBM Plex mods — OFL, embeddable.)

**Typography — pixel-art theme:**
```
--font-text: "Departure Mono","Pixel Code",ui-monospace,monospace;  /* OFL — body + UI */
--font-display: "Pixelify Sans","Press Start 2P";   /* headings/branding ONLY */
--font-text-size: 22px;  /* 2× Departure Mono's 11px grid — MUST be integer multiple */
line-height: 1.45;  letter-spacing: 0;  measure: ~52–60ch;  -webkit-font-smoothing: none; /* SCOPE to .pixel-text */
borders: 1px solid; box-shadow: 2–4px 2–4px 0 0 (no blur/spread);  caret: animation: blink 1s steps(1) infinite;
palette: limited named flavor (Catppuccin-style) over the token system
```
**Pixel-art fonts (licensing):** Departure Mono (OFL — the tasteful default, crisp at 11px multiples),
Monocraft (OFL, ligatures), Pixel Code (OFL, ligatures), Cozette (MIT), Tamzen (permissive), Pixelify
Sans/Press Start 2P/Silkscreen (OFL, display only). **Berkeley Mono is the only paid one + its EULA
gates editor/IDE products — clear it first or skip.** OFL/MIT/BSD all safe to embed in a notarized app.
**CSS techniques:** `image-rendering:pixelated` (WebKit-supported, integer scales only); `steps(n)`
animation for 8-bit motion; `box-shadow: 4px 4px 0 0 #000` (hard, blur 0); dithering via banded
gradients + scanline `repeating-linear-gradient` + `mix-blend-mode:multiply`; keep elements on integer
pixel boundaries (no fractional scale/letter-spacing).

**Modes & micro-interactions:** typewriter scrolling (pin caret to a vertical fraction; bottom padding so
last lines reach center; debounce during fast typing); focus mode (dim non-active unit to `opacity:.28`
light / `color:#6b6b6b` dark, `--dim-opacity` tunable, sentence scope via `Intl.Segmenter`); zen mode
(fullscreen, `max-width:70ch`, fade chrome out after idle); smooth caret (custom bar on `transform`,
shorten during fast typing); glyph-only `::selection`; live word-count in a fading status bar; subtle
"Saved" checkmark (not a modal).

**macOS-26 "Liquid Glass" skin — CRITICAL WKWebView constraint:** the SVG `feDisplacementMap` refraction
trick (`backdrop-filter: url(#filter)`) is **Chromium-only — does NOT render in WebKit/WKWebView**
(corrects SS-P's "[unverified]" note). Reliable baseline = **blur + specular stack**:
`-webkit-backdrop-filter: blur(20px) saturate(180%) brightness(1.05)` + layered inset `box-shadow`
specular highlights + generous concentric `border-radius`. Apple's rules: **glass on chrome/toolbars/
panels ONLY — never the text canvas**; default *regular* variant; ≤4 glass layers/screen; honor Reduce
Transparency (`@media (prefers-reduced-transparency: reduce)` → solid fill); verify ≥4.5:1 contrast
after blur. Make pixel-art and Liquid-Glass mutually-selectable skins via the token system.

## 6. Clone-this-experience checklist (from Tolaria — clean-room, behavior only)

1. **Four-panel resizable layout** — Sidebar (Inbox/Types/Views/Favorites/Folders) · Note List (sortable
   by any property) · Editor (source/preview, no rich-tree) · Inspector (properties + relationships +
   per-note git history). This shell is the feel.
2. **Git as the AI audit trail** — every AI edit is a normal commit/diff with attribution; AutoGit
   checkpoints + a Pulse/history view + inline diff mode → "AI edited my notes" is reviewable, never
   magic. (Highest-leverage differentiator vs Obsidian. Maps onto our provenance ledger.)
3. **CM6 round-trip fidelity** — frontmatter split + wikilink pre/post-processing + "durable markdown"
   normalization; idle-debounce disk-first save. (Simpler for us — CM's buffer *is* markdown.)
4. **Save-suppressing file watcher** — app-owned vs external writes; hot-refresh clean editors, protect
   dirty ones, re-dispatch focus after remount. (Without it, agent edits fight the cursor.)
5. **Unified command system** — one registry → command palette (`Cmd+K`, fuzzy) + native menu + shortcuts.
6. **Convention-over-configuration metadata** — semantic frontmatter (`type:`, `status:`, `[[wikilink]]`-
   valued relations) auto-drives UI; `_`-prefixed system props hidden; overridable via in-vault config.
7. **Types + Inbox→organize method, seeded** — ship default types + a getting-started vault (structure,
   not blank canvas). Inbox Zero as a first-class flow.
8. **Normalized multi-agent stream + MCP** — common event shape (`TextDelta`/`ThinkingDelta`/`ToolStart`/
   `ToolDone`/`Done`) across backends; vault as MCP context source; Safe vs Power tiers; secrets in
   Keychain (never the vault). Maps onto `agent_core::agent_runtime`.
9. **Block affordances on CM6** — slash commands, drag-reorder, wikilink autocomplete, inline/display
   math, Mermaid, Shiki code highlighting, arrow ligatures, rich-HTML clipboard, constant readable width.
10. **Beat Tolaria where it's weak:** ship a **real trash + undo** (Tolaria deletes permanently); **beat
    its keyword search** with our RRF/shadow semantic lane; cover full editor keymap (it's missing
    `Ctrl+E` etc.); friendly "history/checkpoints" framing over raw git verbs for mainstream users.

## 7. Build sequence (never touches Prose; Epdoc/TipTap frozen)

1. **[S] Clone & study MarkEdit** (MIT) — stand up the skeleton it proves: native Swift window +
   WKWebView + CM6 bundle via the brotli scheme handler (single-origin), reusing the CSS-var injector +
   bridge. Real Edit NSMenu. `Compartment`-wrap every runtime setting. Read/write `content.md` directly.
2. **[S] Files-as-truth core** — FSEvents watcher + echo-suppression (recent-writes hash set + ignore
   `.git`/temp) + debounced atomic save (temp→fsync→rename) + stale-save guard + clean/dirty
   reconciliation (clean→silent reload, dirty→conflict; **content-hash the active file** — agents
   produce equal-length edits that mtime+size misses). Path canonicalize + containment check.
3. **[M] Obsidian-style live preview** — harvest `atomic-editor` (MIT): the four decorations,
   `shouldShowSource`, StateField-vs-ViewPlugin split, atomicRanges, the two stability guards.
4. **[M] Theme system + skins** — token layers (foundation→semantic→component); clean theme; pixel-art
   skin (OFL fonts, `image-rendering:pixelated`, `steps()`, hard shadows); macOS-26 Liquid-Glass skin
   (blur+specular, chrome-only, availability-gated). Reserve yellow/red tokens for the diff trail.
5. **[M] AI diff trail** — `@codemirror/merge` `unifiedMergeView` (or hand-rolled StateField) driven by
   `agent_core` + MCP; `view.dispatch` streaming per token (no buffering); decoration-preview + atomic
   commit; three-tier accept/reject; pixel-block stream caret; context chip.
6. **[L] Wikilinks/backlinks/frontmatter/properties** — `[[ ]]` resolver + Halo autocomplete; backlinks
   panel (`WikilinkResolver` over shadow index + `SDPage`); YAML frontmatter (`EpdocFrontmatter` reused);
   typed properties panel; tag index. Unified command palette (`Cmd+K`).
7. **[L] Native-tabbed note workspace** — custom tab bar + `@Observable` pane store keyed by tab id +
   bounded live-set/LRU discard via memory-pressure source. Inspector rail. Git-as-AI-audit Pulse view.

## 8. Top gotchas / risks (plan for these)

1. WebContent-process memory at scale (2 procs/webview, ~200 MB) → bounded live-set + LRU discard is mandatory.
2. SwiftUI identity recreating webviews → own them in the model keyed by tab id; no stray `.id()`.
3. `WKScriptMessageHandler` retain cycle → weak proxy + explicit removal (else leaks WebContent process).
4. Echo-suppression / reload loops → recent-writes hash set; filter temp + `.git`.
5. mtime+size false-negative on equal-length agent edits → content-hash the active/dirty file.
6. WebKit IME/dead-key fragility → latest `@codemirror/view` + a `transactionFilter` (MarkEdit's pattern).
   `EditContext` is Chrome-only — we're on the legacy contenteditable path.
7. Mac Catalyst clipboard is broken → avoid Catalyst (we're AppKit anyway).
8. `WKProcessPool` is a no-op on macOS 12+ → don't hinge memory on it.
9. `isInspectable` left on in release → exposes editor internals via Safari; `#if DEBUG` only.
10. No "tab discarded" event + no in-place hibernation → save state eagerly; discard = release + recreate.
11. Path traversal (real Tauri CVE-2022-39215) → canonicalize + containment-check every path.
12. CSS `transform: scale()` on the editor desyncs CM6 coords → set real `font-size` at native DPR.

## 9. Open decisions for you to work on

- **Color scheme:** yellow=add / red=delete (brand) vs the universal green=add / red=delete? (Yellow is
  defensible as "changed/attention" but non-standard.)
- **Preview model:** full Obsidian-style live preview (inline render in source) vs a simpler source +
  separate reading-render? (Live preview is more work but is the premium feel.)
- **Epdoc/TipTap:** keep frozen-as-legacy indefinitely, or schedule removal once CM6 ships? (SS-CM says
  freeze, don't delete now.)
- **Native tabs now or later:** ship single-pane CM6 first (steps 1–6), add the tabbed workspace (step 7)
  after it's proven?
- **Method layer:** adopt Tolaria's Types/Inbox/Views method (seeded vault), or keep our existing
  note/graph model and only borrow the editor?

## Cross-refs
- Decision: `SS-CM_CODEMIRROR_MD_SOURCE_SURFACE_2026_06_27.md`
- Protected pattern refs: `SS-P_TOLARIA_V2_MD_EDITOR_2026_06_19.md`,
  `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md`, SS-O/EM/FM/IR slices.
- Markdown source-of-truth: `SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` §16.
- External blueprints: MarkEdit (MIT), atomic-editor (MIT), @codemirror/merge (MIT),
  @marimo-team/codemirror-ai (Apache-2.0), SilverBullet (MIT, patterns). Tolaria (AGPL, clean-room only).
