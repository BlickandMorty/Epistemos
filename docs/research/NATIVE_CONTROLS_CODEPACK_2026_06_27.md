# Maximize-Nativeness — Native Controls CODE PACK (2026-06-27)

> Pass-4c deliverable. Make every editor CONTROL native AppKit/SwiftUI driving the WebView over the bridge
> (owner: "native buttons like MarkEdit, as much as possible"); the text stack stays web. Tags [VERIFIED-CODE]/[INFERRED].

## ★ Good news: Epdoc ALREADY follows MarkEdit's pattern
Epistemos's note editor chrome is **already** native SwiftUI dispatching a typed `EpdocEditorCommand` enum →
`evaluateJavaScript` → `window.epistemos.*` JS shim (`js-editor/src/bridge/inbound.ts`). That IS MarkEdit's
model. The gaps to close: Find/Replace, note-width toggle, panel-toggle shortcuts, a unified command registry
+ Cmd+K palette, and bringing the code editor up to the same shape.

## Three editor stacks (recommendations differ)
| Stack | File | Engine | Native chrome today |
|---|---|---|---|
| **Epdoc notes** | `EpdocEditorChromeView.swift`+`EpdocEditorToolbar.swift` | Tiptap in WKWebView | toolbar/slash/bubble/footer/copilot — all native |
| **Code editor** | `CodeEditorView.swift`+`WebKitCodeEditorView.swift` | textarea (NOT CM6) in WKWebView | native top bar/SearchBar/GoToLineSheet/Outline |
| **Legacy markdown** | `ProseEditorRepresentable2.swift` | `NSTextView` (TextKit 2) | fully native already (out of scope) |

## Control-by-control native-vs-web map
✅ native · 🟡 needs upgrade · 🔴 missing · ⬛ must stay web
| Control | Epdoc | Code | Action |
|---|---|---|---|
| Toolbar bold/italic/heading/list/link/code/table | ✅ | 🔴 n/a | Epdoc done |
| Panel toggles | 🟡 | 🟡 | native segmented control + Cmd-shortcuts |
| **Note-width toggle** | 🔴 (CSS var exists, no UI) | n/a | **Add** native toggle → bridge CSS var |
| **Find/Replace** | 🔴 | 🟡 (find-only) | native panel both stacks |
| Goto-Line | n/a | ✅ | done |
| Outline/ToC | 🟡 native popover | ✅ native sidebar | unify via registry |
| Backlinks/Properties/AI panels | ✅ native (scattered @State) | n/a | add Cmd+1/2/3 + ⇧I/T/L |
| **Command palette (Cmd+K)** | 🔴 | 🔴 | **BUILD** registry+palette |
| Menu/shortcuts | 🟡 hand-rolled NotificationCenter | same | derive from registry |
| Settings | ✅ `SettingsView` NavigationSplitView | same | done |
| FontPicker | 🟡 family Picker | n/a | optional NSFontPanel |
| Statistics/status bar | ✅ footer (Epdoc) | 🟡 JS-rendered | move code status native |
| Slash menu trigger / bubble / drag-handle / KaTeX | ⬛ trigger+geometry in JS, **panel is native** | n/a | stays caret-anchored |

## The canonical pattern — native button → bridge → WebView (Epdoc, already wired)
```swift
// EpdocEditorToolbar.swift — native SwiftUI button
toolButton(symbol: "bold", shortcut: "⌘B", isActive: model.isBoldActive,
           command: .runCommand(name: "toggleBold", argsJSON: emptyArgs))
// → model.dispatch → EpdocEditorChromeView coordinator:
webView.evaluateJavaScript(cmd.javaScriptExpression())   // -> window.epistemos.runCommand("toggleBold", ...)
// → js-editor/src/bridge/inbound.ts runCommand(): editor.chain().focus()[name](...args).run()
```
Upgrade: feed active-mark state BACK (add `marks:{bold,italic,...}` to the `caretChanged` payload in
`outbound.ts`, decode in `EpdocBridgeMessage.caretChanged`, set `toolbarModel.isBoldActive`) so buttons
reflect state like MarkEdit's `validateMenuItem`.
**Code editor analogue:** mirror the enum — add `CodeEditorCommand { selectRange, highlightMatches,
replaceRange, setWrap }` with `javaScriptExpression()` + matching methods on `window.epistemosCodeEditor`.

## Note-width toggle (CSS var `--epdoc-content-max-width: 820px` ALREADY exists)
```swift
case setContentWidth(wide: Bool)   // EpdocEditorCommand
// js: document.documentElement.style.setProperty('--epdoc-content-max-width', wide ? '1180px' : '820px')
// toolbar: native toggle button persists UserDefaults "epdoc.note.wide" + model.dispatch(.setContentWidth(wide:))
```

## Panel toggles — native segmented control + focus-scoped shortcuts
```swift
@Observable @MainActor final class NotePanelState {
    enum Panel: String, CaseIterable { case properties, toc, backlinks, ai }
    var active: Set<Panel> = []
    func toggle(_ p: Panel) { active.contains(p) ? active.remove(p) : active.insert(p) }
}
// segmented buttons in toolbar + hidden .keyboardShortcut("1"/"2"/"3"/.command, ⇧I/T/L)
```
⚠️ Cmd+1/2/3 are taken app-level (Home/Notes/Goose, `EpistemosApp.swift:1468`) → scope note shortcuts via
`@FocusedValue` (fire only when a note window is key) or pick free combos.

## ★ Unified CommandRegistry (palette + menu + shortcuts) — biggest win, entirely missing today
```swift
struct EditorCommand: Identifiable {
    let id: String; let title: String; let subtitle: String?; let symbol: String
    let shortcut: KeyboardShortcut?; let scope: Scope
    let isEnabled: @MainActor () -> Bool; let run: @MainActor () -> Void
    enum Scope { case global, note, code }
}
@Observable @MainActor final class CommandRegistry {
    static let shared = CommandRegistry()
    private(set) var commands: [EditorCommand] = []
    func register(_ c: EditorCommand) { commands.append(c) }
    func matching(_ q: String, scope: EditorCommand.Scope?) -> [EditorCommand] {
        commands.filter { scope == nil || $0.scope == scope || $0.scope == .global }
                .filter { $0.isEnabled() }
                .filter { q.isEmpty || $0.title.localizedCaseInsensitiveContains(q) }
    }
}
// register once (incl. bridge commands):
CommandRegistry.shared.register(.init(id:"epdoc.bold", title:"Bold", subtitle:"Toggle bold", symbol:"bold",
    shortcut:.init("b", modifiers:.command), scope:.note, isEnabled:{true},
    run:{ chromeController.dispatch(.runCommand(name:"toggleBold", argsJSON:.emptyArgs)) }))
```
→ Menu bar `CommandMenu` derives from the registry; a native Cmd+K `CommandPaletteView` (SwiftUI sheet,
`.regularMaterial`, fuzzy filter) reads the same registry. One registry → 3 surfaces. `isEnabled` =
MarkEdit's `validateMenuItem`. Cmd+K is currently FREE (verified).

## What MUST stay in the WebView (caret/selection/DOM-anchored, per-keystroke geometry)
Slash menu TRIGGER (`/`), bubble/selection menu anchor, drag-handle hover hit-testing, inline KaTeX anchor,
syntax highlighting/IME/undo/input-rules. **But their PANELS are already native SwiftUI** (EpdocSlashMenuView,
EpdocBubbleMenuView, EpdocBlockGutterMenu, EpdocKaTeXPreview) positioned from a bridged anchor rect — the
hybrid is correct. Rule: caret-anchored trigger+geometry stays in JS; the panel UI is native.

## Recommended build order
1. **CommandRegistry + Cmd+K palette** (highest leverage, entirely missing). 2. Find/Replace (code: extend
SearchBar to find+replace + `highlightMatches`/`replaceRange`; Epdoc: ProseMirror search ext + native panel).
3. Note-width toggle (trivial). 4. Panel-toggle segmented control + focus-scoped shortcuts. 5. Active-mark
feedback + native code status bar. 6. FontPicker NSFontPanel (optional polish).

**Bottom line:** Epdoc is already MarkEdit-shaped; add the missing native controls (Find/Replace, width,
panel segmented control) and unify everything behind one CommandRegistry powering menu+shortcuts+Cmd+K.
Keep the 4 caret-anchored surfaces in the WebView (their panels are already native).
