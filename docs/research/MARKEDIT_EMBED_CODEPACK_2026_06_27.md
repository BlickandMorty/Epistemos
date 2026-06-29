# MarkEdit Full-App Embed + MarkEdit-as-Code-Editor — CODE PACK (2026-06-27)

> Pass-4b deliverable. (A) Embed the FULL MarkEdit app (MIT) inside Epistemos — full settings, closed-in,
> buildable, doesn't need to RUN yet. (B) Use MarkEdit's `CoreEditor` (CodeMirror 6) as the CODE editor,
> replacing the current one. **UPDATES Pass-2 Decision 5 ("drop CoreEditor") — we now KEEP CoreEditor as the
> code surface.** Epdoc/TipTap stays the NOTE editor. Tags: [VERIFIED-CODE] read this session, [INFERRED].

## 0a. ★ FAIL-PROOF CLONE METHOD (owner: "literally clone it, don't add manually")
**The whole `.app` CANNOT be dropped in as-is — macOS forbids it, this is not a choice:** a binary has ONE
`@main`/`NSApplicationMain` and ONE shared `NSDocumentController`; Epistemos already has both. Two `@main` = it
won't compile; two doc-controllers = crash. So "place the whole app and run it" is the BROKEN path, not the safe one.
**The fail-proof method = clone the ENTIRE MarkEdit source, then DELETE only the 4 categories of shell items (@main/AppDelegate · AppDocumentController · .xcodeproj · both .appex) that physically can't
coexist** (its `@main`/`AppDelegate`/`Application`, its `AppDocumentController`, its `.xcodeproj`, its 2 `.appex`
extensions). Everything else — 100% of the editor + ALL Settings panes + FontPicker + Statistics + Find + every
Module — is cloned VERBATIM and you mount its one top-level `EditorViewController` in an Epistemos window. **Zero
editing/settings capability lost** — only the duplicate app-shell Epistemos already provides.
- **Make the clone mechanical (a script), so it can't drift:** `git clone <markedit> LocalPackages/MarkEdit` →
  remove the 4 shell items → add the package products to `project.yml` → done. The ONLY hand-written part is the one
  VC-mount seam (§2–§3). The clone is deterministic; nothing is cherry-picked.
- **Completeness gate (so nothing silently goes missing):** enumerate MarkEdit's Modules products + Settings panes
  from the real source; assert EVERY one is vendored + reachable in Epistemos (under a mode). A pane present in
  MarkEdit but absent in Epistemos = a FAIL (Plan-2 §14). This is the "100% capability, settings and all" proof.
- **Why not a bundled subprocess `MarkEdit.app`:** it would be a separate WINDOW + a subprocess (violates no-sidecar /
  App-Store rules) + can't share your vault/theme. The source-clone is both more fail-proof AND actually "in your app."

### ★ Each dropped shell item HAS an Epistemos equivalent — functionality is NOT lost, and we HARVEST MarkEdit's hardening
**This is the "as hardened as the standalone app you tried" step — do NOT blind-drop; map every dropped item to its
Epistemos equivalent and PORT the hardening config across:**
| MarkEdit drop | Epistemos EQUIVALENT (keeps the function) | HARVEST from MarkEdit so it stays as hardened |
|---|---|---|
| `@main`/`AppDelegate`/`Application` | Epistemos's `@main` `EpistemosApp` + `AppBootstrap` | Port any MarkEdit `AppDelegate`/`applicationDidFinishLaunching` setup (editor defaults registration, theme/appearance init, font/markdown prefs, window-restoration opts) INTO `AppBootstrap` — so nothing MarkEdit did at launch is lost. |
| `AppDocumentController` (`NSDocumentController`) | Epistemos's `EpistemosDocumentController` (existing) | Register MarkEdit's document types + new-document/file-version/autosave behavior with the EXISTING controller (it already manages `.epdoc`); copy MarkEdit's `CFBundleDocumentTypes`/UTI handling so it opens the same file types with the same options. |
| `.xcodeproj` (build blueprint) | Epistemos's `project.yml` (xcodegen) | **★ Harvest the hardening:** MarkEdit's build settings (Swift version, deployment target, **hardened-runtime** flags, optimization, linker flags), its **Info.plist** (document-type/UTI declarations, `NSServices`, capabilities), and its **entitlements** → port the editor-relevant ones into Epistemos's `project.yml`/Info.plist/entitlements, ADOPTING MAS-safe keys and mapping/rejecting MAS-hostile ones (`temporary-exception.files.home-relative-path`, `files.user-selected.executable`). This is what makes the embed *as hardened as the real MarkEdit*, just inside Epistemos's signed bundle. |
| 2 `.appex` (Finder/Quick Look extensions) | Epistemos's OWN Finder/Quick Look extensions (optional, later) | Harvest the `.appex` Info.plist (supported UTIs, Quick Look config) so Epistemos equivalents can be built when wanted. Loses only *Finder* integration today, not editor capability. |
**Rule: a MarkEdit capability that lived in a dropped item must reappear via its Epistemos equivalent (ported), or be
explicitly listed as a deliberate loss (only the 2 `.appex` Finder bits). No silent loss.**

## 0. ★ DISCOVERY — Epistemos's PRE-SWAP code editor was a plain textarea with highlighting DISABLED
Historical pre-swap state before the Plan 2 MarkEdit replacement:
- **REMOVED: `Epistemos/Views/Notes/WebKitCodeEditorView.swift`** — was an `NSViewRepresentable` over a `WKWebView`
  hosting a `<textarea id="source">` + aria-hidden `<pre id="highlight">` overlay. **It is NOT CodeMirror.**
  The highlighter is **dead code** — `renderHighlight()` starts with a bare `return;` (line 757) — so it's
  effectively a monospace textarea with a line-number gutter + status line. Bridge = one handler
  `epistemosCodeEditor` (`ready`/`change`/`cursor`); loads `epistemos-doc:///code-editor.html` via the SHARED
  `EpdocEditorURLSchemeHandler`. `CodeEditorView.usesWebKitEditor` is hardcoded `true` (`:1831`).
- **REMOVED fallback:** `CodeEditSourceEditor` (TextKit/tree-sitter) — was compiled, gated off, self-healed to off.
- **REMOVED scaffold:** `LiveCodeEditorController` (+ `SwiftTreeSitterLiveHighlighter`) — no production view bound it.

**So MarkEdit's real CodeMirror 6 is a strict upgrade of the SURFACE.** And Epistemos's surrounding *chrome*
is genuinely nice and worth keeping: `CodeEditorView` provides a native SwiftUI top bar (file/lang/Ln-Col,
Live-Preview toggle, Find, Go-to-Line, view-options, editor-settings), a Swift `CodeEditorSearchEngine` +
`searchBarOverlay`, `GoToLineSheet`, `OutlineNavigatorView`+`OutlineParserCache`, breadcrumbs,
`HTMLWorkspacePreviewView` Live Preview, and **semantic LSP** (`CodeEditorSemanticLSP` hover/go-to-def for
rust/swift via in-process `RustLSPTransport` → Rust `LspKernel`, no subprocess; one-shot per query).

## 1. MarkEdit structure (live GitHub API) — vendor/drop map
```
MarkEditCore/      core value types (shared)              -> VENDOR
MarkEditKit/       the BRIDGE (ts-gyb): EditorMessageHandler ("bridge" handler),
                   Bridge/Web/Generated (Swift->JS), Bridge/Native/Generated (JS->Swift) -> VENDOR (transport)
MarkEditMac/Modules/  SwiftPM "Modules": AppKitControls, AppKitExtensions, DiffKit, FileDrop,
                   FileVersion, FontPicker, Previewer, SettingsUI, Statistics, TextBundle, TextCompletion -> VENDOR
MarkEditMac/Sources/Editor/    EditorChunkLoader (chunk-loader:// scheme), EditorWindow,
                   EditorViewController (+~16 ext: +TextFinder/+GotoLine/+Statistics/+Completion/+Config/...) -> VENDOR
MarkEditMac/Sources/Panels|Settings|Scripting|Shortcuts/  chrome -> VENDOR (selective)
MarkEditMac/Sources/Main/Application/ (@NSApplicationMain/AppDelegate), AppDocumentController.swift -> DROP
CoreEditor/        CodeMirror 6 (TS, vite+yarn; base '/chunk-loader/' in prod, code-split dist/chunks/) -> VENDOR (KEEP)
MarkEdit.xcodeproj -> DROP (xcodegen owns project)   MarkEditMac/Info.entitlements -> DROP (MAS-hostile)
FinderExtension/ PreviewExtension/  (.appex) -> DROP
```
Swap seam = `EditorViewController.lazy var webView` block (builds WKWebView, registers `"bridge"` handler +
`EditorChunkLoader`+`EditorImageLoader`, `loadHTMLString(baseURL: EditorWebView.baseURL)`). `lazy var bridge =
WebModuleBridge(webView:)` = typed Swift→JS (ts-gyb generated — verify selectors against vendored `Generated/`).

## 2. The two-@main reconciliation (Epistemos is ALREADY a document app)
`EpistemosDocumentController: NSDocumentController` + `EpdocDocument`/`HTMLWorkspaceDocument` already exist →
MarkEdit's doc/window/menu layer is not foreign. But one binary can't have two `@main`/`NSApplicationMain`/
`NSDocumentController`. So: DROP MarkEdit's app lifecycle, RE-HOST `EditorViewController` via
`NSViewControllerRepresentable` in Epistemos's SwiftUI `WindowGroup`, against the EXISTING controller.
**Namespace watch:** MarkEdit's `Main/*` has `AppDocumentController`/`AppTheme`/`AppPreferences` (vendor
`Main/*` selectively — you mostly want Editor/Panels/Settings/Modules); `AppKitExtensions` may clash with
Epistemos `NSView`/`NSColor` extensions (namespace-check on first build).

```swift
// NEW Epistemos/Views/MarkEdit/MarkEditCodeEditorRepresentable.swift
import SwiftUI; import MarkEditKit
struct MarkEditCodeEditorRepresentable: NSViewControllerRepresentable {
    @Binding var text: String
    let language: CodeEditorLanguage
    let theme: EpistemosTheme
    let onContentChange: (String) -> Void
    func makeNSViewController(context: Context) -> EditorViewController {
        let vc = EditorViewController(preloadDelay: nil)
        context.coordinator.controller = vc
        context.coordinator.applyInitial(text: text, language: language)
        return vc
    }
    func updateNSViewController(_ vc: EditorViewController, context: Context) {
        context.coordinator.applyTheme(theme)
        context.coordinator.applyLanguage(language)
        context.coordinator.applyExternalTextIfChanged(text)   // only push non-editor-originated changes
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    @MainActor final class Coordinator {
        let parent: MarkEditCodeEditorRepresentable; weak var controller: EditorViewController?
        private var lastPushed: String?
        init(_ p: MarkEditCodeEditorRepresentable) { parent = p }
        func applyInitial(text: String, language: CodeEditorLanguage) {
            controller?.bridge.core.resetEditor(text: text) { _ in }; lastPushed = text   // ts-gyb shape; verify selector
        }
        func applyExternalTextIfChanged(_ t: String) {
            guard t != lastPushed else { return }
            controller?.bridge.core.resetEditor(text: t) { _ in }; lastPushed = t
        }
        func applyLanguage(_ l: CodeEditorLanguage) { /* bridge.config.setLanguage(...) */ }
        func applyTheme(_ t: EpistemosTheme) { /* CSS-var injection */ }
    }
}
```
FULL settings, present-but-inert (buildable, not menu-wired):
```swift
// NEW Epistemos/Views/Settings/MarkEditSettingsSection.swift  (#if EPISTEMOS_MARKEDIT_EMBED)
import SwiftUI; import SettingsUI
struct MarkEditSettingsRepresentable: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> NSViewController { MarkEditSettingsRootViewController() } // vendored
    func updateNSViewController(_ vc: NSViewController, context: Context) {}
}
```
"Closed-in / doesn't run yet" = compiles + renders behind a flag; no `Settings` scene / `Cmd+,` wired this pass.

## 3. Code-editor swap — ★ CANONICAL (REVISED 2026-06-29): MarkEdit ENGINE+POLISH for both; MD=MarkEdit chrome verbatim, CODE=v1-minimal look reimplemented on MarkEdit; the Prose/Source/Note LENS MODEL
★ OWNER DECISIONS (2026-06-29): see plan **L3 / L3-CHROME / L4**.
MarkEdit's CoreEditor (CM6) is the ONE engine and **MarkEdit's innate POLISH is kept for both** code + markdown.
The CHROME differs by lens:

- **MD lens → MarkEdit's chrome VERBATIM.** Host MarkEdit's `EditorViewController` chrome — toolbar, Find/Replace,
  FontPicker, Statistics, Goto-Line, Previewer, live Settings — exactly like the standalone MarkEdit.app (visual
  fidelity §3a). Epistemos additions ADD only, never subtract MarkEdit polish.
- **CODE → REIMPLEMENT the old v1 code editor's MINIMAL look ON the MarkEdit engine** (owner 2026-06-29 clarified:
  built on MarkEdit for its polish, but it should LOOK like the old minimal code editor — NOT MarkEdit's full
  standalone toolbar, and **NOT a restore of v1's code** — reimplement the look fresh on MarkEdit). Reproduce:
  - the **nested-box container** (the inset rounded-card editor panel — exactly like v1),
  - the **title styling** (filename + subtitle e.g. "Swift · N lines"),
  - **real per-language FILE-TYPE LOGOS** — the Swift bird, Rust gear, the specific icon per code file type — NOT
    the generic `</>` glyph (needs a file-extension→logo map; mind trademark — prefer a clean language-icon set or
    `NSWorkspace`/`UTType` system icons).
  - **THEME-AWARE to Epistemos** (today it only takes MarkEdit's theme): the code chrome + CoreEditor must follow
    the app's theme (light/dark/custom/accent via Epistemos theme tokens), not be hardcoded to MarkEdit's github
    light/dark. (See §3a theme injection.)
  - Graft the PRESERVE-LIST (below) into this minimal chrome.
- **PRESERVE-LIST — graft these Epistemos code-editor-v1 affordances INTO MarkEdit's chrome (never lose them):**
  the **Live-Preview / HTML preview button** (`HTMLWorkspacePreviewView`, engine-agnostic — needs only `$text`),
  **LSP hover/go-to-def** (`CodeEditorSemanticLSP` over `RustLSPTransport`), the **Outline** navigator, + the other
  critical v1 buttons. (MarkEdit natively supplies Find/GoToLine/FontPicker/Statistics → those REPLACE the
  Epistemos equivalents.)
- **OLD CODE EDITOR = KEPT as "v1 legacy" (do NOT delete — supersedes the old L3 deletion):** reachable from
  **Settings** + a **toggle inside the MarkEdit surface** so the owner can fall back to `WebKitCodeEditorView`.
- **SIZING (§3a):** MD matches MarkEdit's full default font size; **CODE is a few ticks SMALLER than MarkEdit's MD
  default but MORE spacious/larger than today's code editor** (real-code density). Inherit MarkEdit's defaults
  (`FontPicker.defaultFontSize`, `AppPreferences.Editor.lineHeight`) — do NOT substitute a smaller Epistemos value
  or hardcode line-height.
- **THE LENS MODEL (plan L4):** markdown-on-disk is the ONE truth; a `.md` opens in any of three cross-synced
  lenses — **Note** (Epdoc WYSIWYG, standalone isolated module) · **Source** (this MarkEdit surface) · **Prose**
  (TK2 focus, wired last). A CODE file = **Source only**. Ship **Source ↔ Note** toggle first; add Prose later.
  - **Data-loss containment:** Source + Prose edit raw text (near-zero loss). The ONLY loss boundary is **Note/Epdoc
    serializing back to markdown**. 4 guardrails: (1) Epdoc writes ONLY via the full-fidelity `getMarkdown()` bridge;
    (2) preserve-unknown passthrough; (3) write only on a real edit; (4) round-trip test fails loud on edge
    constructs (raw HTML / footnotes / exotic tables / callouts / frontmatter).
- **★ ROUTING FIX — the MarkEdit MD surface is currently ORPHANED.** `MarkEditVerbatimMarkdownChromeRepresentable`
  (`mode: .markdownChrome`) is built but UNREACHABLE: the language detector at `CodeEditorView.swift:706` returns
  nil for markdown → routes `.md` to the PROSE editor, so MarkEdit's MD chrome is never entered (owner: "I don't
  see a way to access the MD version — it all routes to Prose"). WIRE the per-document lens toggle so `.md` can open
  in the Source (MarkEdit) lens; do NOT force-route markdown away from it.
  ```swift
  // ONE MarkEdit CoreEditor surface for code + markdown; lens toggle picks Note/Source/Prose for .md.
  @ViewBuilder private var codeEditorSurface: some View {
      MarkEditCoreEditorView(text: $text, mode: isMarkdownDocument ? .markdownChrome : .codeChrome,
          language: CodeEditorLanguage(epistemos: language), theme: ui.theme, fontSize: codeFontSize,
          onContentChange: { ensureContentDebouncer().enqueue($0) })
  }
  ```
- **LSP attach:** (1) keep the current one-shot Swift `CodeEditorSemanticLSP` over `RustLSPTransport` (engine-
  agnostic — needs only `$text`+cursor, which CoreEditor provides). (2) Later: a CM6 LSP-client extension in
  the CoreEditor bundle bridged to `lspSendMessageJson`/`lspPollResponseJson` (rust/swift only) — defer.

## 3a. ★ VISUAL FIDELITY — the embed MUST look like the finished MarkEdit app (owner: "looks way different — larger, higher quality")
The current embed renders SMALLER/plainer than the standalone app. Verified causes + fixes:
- **Font size is substituted, not inherited.** `MarkEditCoreEditorView.swift:364` clamps an Epistemos-supplied
  `fontSize`. The real app uses `AppPreferences.Editor.fontSize` defaulting to `FontPicker.defaultFontSize`
  (`AppPreferences.swift:86`) — LARGER. FIX: MD path inherits `FontPicker.defaultFontSize` verbatim; CODE path uses
  it minus a few ticks (still larger than today's code editor) per the §3 sizing rule.
- **Line height is hardcoded** to `1.45` (`:831`). FIX: use `AppPreferences.Editor.lineHeight` (default `.normal`).
- **MarkEdit default-prefs harvest was never done.** Port MarkEdit's `AppDelegate`/`AppPreferences`/`FontPicker`
  default registration (font, size, line-height, theme) into `AppBootstrap` (the §0a harvest-hardening item).
- **Content insets / window size:** match MarkEdit's roomy editor margins + default window dimensions; don't let
  Epistemos theme CSS shrink/override MarkEdit's own styling on the MD path.
- **THEME AWARENESS (CODE path):** today the editor only takes MarkEdit's theme (e.g. `github-dark`/`github-light`
  at `:363`). The CODE chrome + CoreEditor must follow the **Epistemos app theme** — inject Epistemos theme tokens /
  CSS-vars (background, text, accent, gutter, selection) mapped from the active app theme, including custom/accent,
  not just MarkEdit's two github presets. (MD path stays on MarkEdit's own theme to preserve verbatim fidelity.)
- **FILE-TYPE LOGOS (CODE path):** the title bar shows a **real per-language logo** (Swift bird, Rust gear, etc.),
  not the generic `</>` glyph — build a file-extension→icon map (clean language-icon set or `NSWorkspace`/`UTType`
  system icons; mind trademark).
- **Acceptance:** (MD) a `.md` side-by-side with MarkEdit.app matches font/spacing/margins; (CODE) the surface
  shows the v1 nested-box look + correct file-type logo + the active Epistemos theme.

## 4. Build / signing
xcodegen `project.yml` (NEVER hand-edit `.xcodeproj`): add local-path packages + products.
```yaml
packages:
  MarkEditModules: { path: LocalPackages/MarkEdit/MarkEditMac/Modules }
  MarkEditKit:     { path: LocalPackages/MarkEdit/MarkEditKit }
  MarkEditCore:    { path: LocalPackages/MarkEdit/MarkEditCore }
targets:
  Epistemos:
    sources:
      - { path: Epistemos, type: syncedFolder }
      - path: LocalPackages/MarkEdit/MarkEditMac/Sources
        type: group
        excludes: [ "Main/Application/**", "Main/AppDocumentController.swift" ]
    dependencies:
      - { package: MarkEditKit }
      - { package: MarkEditCore }
      - { package: MarkEditModules, product: SettingsUI }
      - { package: MarkEditModules, product: FontPicker }
      - { package: MarkEditModules, product: Statistics }
      - { package: MarkEditModules, product: FileVersion }
      - { package: MarkEditModules, product: DiffKit }
      - { package: MarkEditModules, product: AppKitControls }
      - { package: MarkEditModules, product: AppKitExtensions }
      - { package: MarkEditModules, product: TextCompletion }
```
- MarkEdit's `Modules/Package.swift` uses a SwiftLint plugin on every target → strip the `plugins:` from the
  vendored `Package.swift` (or vendor `MarkEditTools`) so the lint plugin doesn't enter Epistemos's build.
- **CoreEditor build:** clone `build-tiptap-bundle.sh` → `build-coreeditor-bundle.sh` (PATH-harden + npm/yarn
  check + lock-hash gate on `CoreEditor/yarn.lock`; `yarn install --immutable && yarn build` (vite →
  dist/+dist/chunks/); rsync → `Epistemos/Resources/CoreEditor/`); append to `preBuildScripts`. CI must run it
  before xcodebuild.
- **Scheme:** keep MarkEdit's `chunk-loader://` for the code editor first landing (CoreEditor's vite `base:
  '/chunk-loader/'` already emits the matching layout; `EditorChunkLoader`+`EditorImageLoader` come free).
  Brotli-unify to `epistemos-doc://` later (optional optimization).
- **Entitlements:** adopt Epistemos's (has `app-sandbox`,`network.client`,`cs.allow-jit`,`files.user-selected.
  read-write`,`files.bookmarks.app-scope`). **REJECT MarkEdit's MAS-hostile keys** (`temporary-exception.files.
  home-relative-path.read-write=["/"]`, `files.user-selected.executable`). Never copy MarkEdit's `Info.entitlements`.
- **Drop both `.appex`** (Finder/Preview).

## 5. Coexistence (code=CoreEditor + notes=Epdoc, one app)
- Two scheme handlers, distinct schemes: `epistemos-doc://` (Epdoc/TipTap + current code-editor HTML, brotli)
  and `chunk-loader://` (CoreEditor) — registered only on their own WKWebView config; no collision.
- Shared `WKProcessPool` (`EpdocWebViewShared.processPool`) on CoreEditor's config too — but it's a no-op on
  macOS 12+; real lever = the existing `DispatchSourceMemoryPressure` handler (`resetPoolIfIdle()` + Rust
  `respondToMemoryPressure`). Route CoreEditor's WebView through it.
- Two bridges, distinct handler names (`epdoc`/`bridge`/`epistemosCodeEditor` vs MarkEdit's `"bridge"` scoped
  to its own content controller) — just never register two same-named handlers on one content controller.
- **Routing:** `CodeLanguage.detect(from:)` already returns nil for `.md`/`.txt` (→ note path) and a language
  for code extensions (`:935`). Code ext → CoreEditor; markdown/notes → Epdoc/TipTap; MarkEdit's own markdown
  mode = "a different mode" on the code surface, not the default note path.

## 6. Risks / do-avoid
Risks: (1) verify ts-gyb `bridge.core.*` selectors vs vendored `Bridge/Web/Generated/` first; (2)
`AppKitExtensions` symbol clashes; (3) MarkEdit chrome is now used for BOTH code + markdown (L3-CHROME REVISED) —
the risk is LOSING grafted v1 affordances (preview button/LSP/Outline), so verify each is wired into MarkEdit's
chrome; (4) MAS entitlement leakage — never sign with MarkEdit's `Info.entitlements`; (5) 3rd WKWebView family
memory — route through the pressure handler; (6) CoreEditor vite/yarn must run before xcodebuild (lock-hash gate).
DO: vendor under `LocalPackages/MarkEdit/`, keep MIT `LICENSE`, ProvenanceGate clean-import; keep CoreEditor (updated
decision); keep Epdoc as the note editor. AVOID: 2nd `@main`/`NSDocumentController`, hand-editing `.xcodeproj`,
copying MarkEdit entitlements, shipping `.appex`s, runtime npm/yarn.

**Key files:** current editor `Epistemos/Views/Notes/WebKitCodeEditorView.swift` + `CodeEditorView.swift`
(swap seam `codeEditorSurface` ~`:2332`); LSP `Epistemos/Engine/RustLSPTransport.swift`+`LSPClient/LSPMessage/
LSPTransport.swift`; host plumbing `Epistemos/Engine/EpdocEditorBridge.swift`+`build-tiptap-bundle.sh`; app
`Epistemos/App/EpistemosApp.swift`+`EpistemosDocumentController.swift`; `project.yml`+`Epistemos.entitlements`.
