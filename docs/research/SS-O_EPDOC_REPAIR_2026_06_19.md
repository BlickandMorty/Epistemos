# SS-O — Epdoc editor repair (root-cause the glitches/failures) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the EPDOC-REPAIR ledger item. Owner: *"Epdoc seems less
robust ... editing is very demo-ish, it glitches and fails ... repair the current Epdoc."* **HARD CONSTRAINT:
do NOT touch TK2/Prose** (`Views/Notes/ProseEditorView.swift`, `ProseTextView2.swift`,
`ProseEditorRepresentable2.swift`) — separate, working editor. Pairs with SS-P (Tolaria v2).

## Headline
Epdoc = Tiptap **3.24** rich editor in a `WKWebView`, SwiftUI-hosted. It is a **real, complete Tiptap
integration** (NOT a demo bundle) — built + staged at `Resources/Editor/editor.js.br` (259 KB). The "demo-ish/
glitches/fails" is a set of concrete fragilities: (1) floating panels positioned with **hardcoded pixel fudge
offsets + NO viewport→window coordinate translation** — the most visible glitch; (2) **JS errors fail
silently** — no `WKNavigationDelegate`, no `window.onerror` bridge, empty Swift `.error` case; (3) stacked
debounce (JS 200ms + Swift 300ms) + an `editorReady`-gated initial flush → dropped-keystroke / lost-edit /
blank-editor windows; (4) lossy markdown round-trip. None of this touches TK2/Prose.

## Architecture map
- **WebView host** `EpdocEditorChromeView.swift:605-649 makeNSView` — `WKWebViewConfiguration`, registers
  `"epdoc"` script-message handler (`:612`), injects theme user-script (`:613-619`), `websiteDataStore=
  .nonPersistent()` (`:629`), custom-scheme handler (`:630-635`), loads `epistemos-doc:///editor.html`
  (`:644-646`).
- **Asset serving** `EpdocEditorBridge.swift:187-329` `EpdocEditorURLSchemeHandler` serves `Resources/Editor/*`
  over `epistemos-doc`; brotli-decompresses `.br` server-side off-actor (`:277-303`) — the fix for the prior
  blank-editor bug (`:258-267`).
- **Bridge inbound (JS→Swift)** `EpdocEditorChromeView.swift:790-833 userContentController` →
  `MainActor.assumeIsolated`→`handleInbound`, AP1 `{type:'batch'}` envelope (`:812-819`), AR5 `classifyPaste`
  (`:822-827`); decode `EpdocEditorBridge.swift:453-513`. JS posts via `js-editor/src/bridge/outbound.ts:204
  postBridge`, rAF-coalesced (`:147-175`).
- **Bridge outbound (Swift→JS)** `EpdocEditorCommand` (`EpdocEditorBridge.swift:564-617`) → `window.epistemos.*`
  expressions (`:593-616`) via `evaluateJavaScript`; JS shim `js-editor/src/bridge/inbound.ts:22-152`.
- **AP1 display-link pipeline** `EpdocEditorChromeView.swift:869-932` — enqueue (`:869`), flush on `CADisplayLink`
  (`:874-897`), coalesced IIFE eval (`:899-932`).
- **Autosave** JS debounce 200ms (`index.ts:73,84-94`) → Swift debounce 300ms (`EpdocEditorBridge.swift:650-719`)
  → host writes `package.contentJSON` (`EpdocDocument.swift:504-511`); shutdown drain (`:687-718`).
- **Teardown** `dismantleNSView` (`:675-683`) + `Coordinator.shutdown()` (`:774-788`). Ownership
  `EpdocDocument.makeWindowControllers() :460-518`.

## Glitch/failure roots (ranked)
1. **Floating panels: NO viewport→window coord translation; hardcoded offsets.** `EpdocEditorChromeView.swift
   :417` slash `.position(x: anchor.x+140, y: anchor.y+200)`; bubble `:431` `(x, y-30)`; KaTeX `:442`
   `(x+180, y-80)`. The JS emitter assumes Swift converts coords (`caret-rect-emitter.ts:70-72`) **but grep for
   `convert(`/`frame.origin`/`bounds` in the chrome file is EMPTY** → panels drift/misalign on scroll/resize.
   **Highest-likelihood "demo-ish glitch."**
2. **JS failures are SILENT.** Bundle never posts `{type:'error'}`; no `window.onerror`/`unhandledrejection`;
   **no `WKNavigationDelegate`** (no `didFail`/`webContentProcessDidTerminate`); Swift `.error` case is
   `break // host logs` (`:304-305`); `inbound.ts:31-33,147` swallows with `console.warn`. If Tiptap throws /
   bundle 404s / web-content process is killed → **blank/frozen editor, zero signal** = "it fails."
3. **Initial-content flush race → lost edits.** Initial `setContent` only fires when `editorIsReady &&
   bridgeDispatchInstalled && !didPushInitialContent` (`:223-234`); `markHostDocumentLoaded()` set JS-side only
   inside `setContent` (`inbound.ts:28`), and `onUpdate` suppresses `contentDidChange` until then (`index.ts
   :175`). If `setContent` is ever dropped (bridge race / re-mount), autosave is **permanently gated off** —
   typing never persists. *Unverified — needs runtime repro; fragile by construction.*
4. **`setContent({emitUpdate:false})` desyncs dirty flag** (`inbound.ts:27`) → stale complexity/word counts
   after a programmatic swap (`:236-246` bails if `isDirty`). "Numbers don't update."
5. **Window-close keystroke DROP (concrete bug).** Two debounce layers ≈500ms keystroke→bytes; the shutdown
   drain (`:687-718`) covers app-quit only. Window/doc close goes through `shutdown()`→`detachAutosavePipeline()`
   (`:784`) **without** calling `flushNow()` first → the in-flight last keystroke is dropped on window close.
6. **Lossy markdown round-trip.** `parseMarkdownPaste` (`markdown-paste.ts:20-123`) handles a fixed block set;
   unrecognized → `parseParagraph` (`:116`); inline only `INLINE_TOKEN_RE` (`:18`). **No Tiptap→markdown
   serializer in `src/` at all** (canonical body = ProseMirror JSON, `outbound.ts:36`) → lossy-in, no md-out.
7. **`coordsAtPos` after content swap can throw** (`caret-rect-emitter.ts:73-74`, no try/catch) → unhandled JS
   error (invisible per root #2). *Unverified — needs runtime repro.*

## JS bundle state
**Real + complete, with dead deps.** `js-editor/package.json` pins Tiptap **3.24.0** + full extension set
(StarterKit, UniqueId, Link, Highlight, Table, TaskList, CharacterCount, Mathematics/KaTeX, BubbleMenu,
FloatingMenu, DragHandle, footnotes) + custom nodes (EpdocCodeBlock/ChartNode/ImageNode/CalloutNode/
LegacyDiagramNode), all wired `index.ts:116-168`. Built + staged (`editor.js.br` 259KB, `editor.html` present).
Build path = **webpack** (`build-tiptap-bundle.sh:104-111`) — CLAUDE.md:72 "esbuild" is **stale doc**. Dead
weight: `@tiptap/extension-collaboration` + `@tiptap/y-tiptap` declared (`package.json:38,57`) but **never
imported** — collab unwired, inflates bundle.

## Robustness gaps vs Notion/Tolaria-class
Undo/redo = only StarterKit default history, no toolbar UI / bridge command; collaborative cursor absent (deps
unwired); block-drag configured but unparameterized; paste lossy (root #6), `EpdocPasteClassifier` runs
out-of-band and never repairs inserted content (`:841-860`); image handling OK (`storeImageAsset`
`EpdocEditorBridge.swift:328-333`). **Critical gap = silent failure end-to-end (root #2): no process-termination
reload, no error toast, no runtime health surface.**

## Repair plan [S]/[M]/[L] — NOT touching TK2/Prose
1. **[S] Surface JS errors honestly** — `window.onerror`+`unhandledrejection`→`postBridge({type:'error'})`;
   try/catch `coordsAtPos`/`setContent`/`applySlashChoice`; replace empty Swift `.error break` (`:304-305`) with
   OSLog + non-blocking banner.
2. **[S] Fix window-close keystroke drop** — `Coordinator.shutdown()` (`:774-788`) calls `flushNow()` BEFORE
   `detachAutosavePipeline()`.
3. **[M] Fix floating-panel positioning** — translate WKWebView viewport rect → window coords via the live
   WebView frame instead of `+140/+200/+180/-30/-80` (`:417,431,442`); track scroll + resize. Dominant glitch.
4. **[M] Harden initial-content/ready handshake** — make `editorReady` idempotent + re-assertable; gate autosave
   on an explicit ack not the one-shot `didPushInitialContent`; add a watchdog (reload `editor.html` once if no
   `editorReady` within N ms, report via the new error channel).
5. **[M] Add WKNavigationDelegate + process-termination reload** — `webContentProcessDidTerminate` reloads +
   re-pushes content; `didFail*` surfaces bundle-load failures (today `EpdocEditorBridge.swift:205-254`
   `didFailWithError` has no consumer).
6. **[M] Epdoc runtime health/witness row** mirroring `EditorBundleHealthRow.swift` — last `editorReady`, last
   error, last autosave success, `EpdocWebViewShared.liveWebViewCount` (`:37`). Honest "is it broken now."
7. **[S] Doc/dep hygiene** — drop unused collaboration/y-tiptap deps (or wire in SS-P); fix CLAUDE.md:72
   esbuild→webpack.
8. **[L → SS-P] Tolaria-class rich UI/UX** (collab cursors, real undo/redo UI, md-out serializer, block-drag
   feedback) layers on the stabilized bridge — SEPARATE slice, not SS-O.

Key files: `Views/Epdoc/EpdocEditorChromeView.swift` (host/bridge/AP1/teardown/positioning — roots #1,2,3,5) ·
`Engine/EpdocEditorBridge.swift` (scheme/asset/brotli, `EpdocEditorCommand`, `EpdocEditorSavePipeline`) ·
`Engine/EpdocDocument.swift:460-518` · `js-editor/src/index.ts` (mount + extensions + JS debounce) ·
`js-editor/src/bridge/{inbound,outbound}.ts` · `js-editor/src/extensions/caret-rect-emitter.ts` (roots #1,#7) ·
`js-editor/src/markdown/markdown-paste.ts` (root #6) · `js-editor/package.json` + `build-tiptap-bundle.sh`
(webpack, Tiptap 3.24, real) · `Views/Settings/EditorBundleHealthRow.swift` (health-row template). OUT OF SCOPE:
`Views/Notes/ProseEditorView.swift`, `ProseTextView2.swift`, `ProseEditorRepresentable2.swift`.
