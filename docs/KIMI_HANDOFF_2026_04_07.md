# Kimi Handoff: Code Editor — All Remaining Issues

## Date: 2026-04-07
## Priority: HIGH — these are blocking user experience

---

## Current State

The code editor uses **CodeEditSourceEditor v0.15.2** (CoreText-based, tree-sitter powered). Text renders correctly, line numbers work, status bar works, fold indicators show. BUT:

1. **No syntax highlighting** — all text is plain monochrome
2. **No minimap content** — minimap area exists but shows nothing
3. **Theme feels heavy** — user wants light feel matching the note system
4. **Outline navigation is hard to use** — no scrollable TOC, no section labels, not legible enough
5. **Line count display works** but user wants more IDE-like features

## What Was Fixed This Session

### Text Rendering (FIXED)
Changed from `@State private var text: String = ""` with `.onAppear` to `_text = State(initialValue: content)` in init. The SourceEditor's `makeNSViewController` calls `setText(binding.wrappedValue)` ONCE — text MUST be non-empty at creation.

### NSTextStorage Path (ATTEMPTED, REVERTED)
Tried replacing `Binding<String>` with `NSTextStorage` for O(1) per-keystroke performance. CodeEditSourceEditor's `setTextStorage()` overwrites `textStorage.delegate` with its own `MultiStorageDelegate`, breaking tree-sitter highlighting. Reverted to `Binding<String>`.

---

## Issue 1: No Syntax Highlighting

### What's happening
- `language: .swift` is passed to SourceEditor
- Tree-sitter grammar files present in app bundle (`tree-sitter-swift/highlights.scm`, `locals.scm`, `tags.scm`)
- `TextViewController.setUpHighlighter()` is called in `viewDidLoad`
- No error messages in console
- BUT all text renders in plain text color — no keywords, strings, or comments colored

### Debug Steps
1. Add breakpoint in `TextViewController+Highlighter.swift:12` (`setUpHighlighter`)
2. Verify `self.highlighter` is non-nil after setup
3. Check `highlighter.providers.count` — should be ≥ 1
4. Check if the `TreeSitterClient` is producing any highlights:
   ```swift
   // In debugger after highlighter setup:
   po self.highlighter
   po self.highlighter?.providers.count
   po self.language.tsName  // should be "swift"
   ```
5. Check if `attributesFor(_:)` is being called with non-nil captures:
   ```swift
   // Add temp breakpoint in TextViewController extension:
   func attributesFor(_ capture: CaptureName?) -> [NSAttributedString.Key: Any] {
       NSLog("[Highlight] capture: \(String(describing: capture))")
       // ... existing code
   }
   ```

### Possible Fixes
- If `highlighter` is nil: `setUpHighlighter()` isn't being called. Check `viewDidLoad` execution.
- If providers count is 0: tree-sitter client isn't being created. Check `CodeLanguage.swift.tsName`.
- If `attributesFor` never called: tree-sitter is parsing but not finding any captures. Check `highlights.scm` query correctness.
- If `attributesFor` called with `.none`: the capture names don't match `CaptureName` enum cases.

### File: `Epistemos/Views/Notes/CodeEditorView.swift`
- Line 251: `codeEditLanguage` returns `.swift` — verified correct
- No file size threshold — was removed

---

## Issue 2: Minimap Empty

### Root Cause
The minimap uses `MinimapLineFragmentView` which draws colored rectangles based on tree-sitter token colors. If the highlighter isn't producing tokens (Issue 1), the minimap draws nothing.

**Fix Issue 1 first → minimap should populate automatically.**

### Configuration
```swift
peripherals: .init(
    showGutter: true,
    showMinimap: true,        // ← enabled
    showFoldingRibbon: true
)
```

### Debug
```swift
// In prepareCoordinator:
NSLog("[CodeEditor] showMinimap: \(controller.showMinimap)")
// Check if minimapView is present and visible
```

---

## Issue 3: Theme Feels Heavy

### User Feedback
- "everything should feel light it still feels heavy"
- "have the theme of the code be fixed to be like the note system"
- "the top should either extend to cover the gap"

### Current Implementation
```swift
@MainActor private var editorTheme: EditorTheme {
    ui.theme.isDark ? .xcodeDark : .xcodeLight
}
```

### Recommended Fix
Use `useThemeBackground: false` to let the editor blend with the window:
```swift
appearance: .init(
    theme: editorTheme,
    useThemeBackground: false,  // ← use window background instead of hardcoded theme bg
    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
    lineHeightMultiple: 1.35,
    wrapLines: false,
    tabWidth: 4,
    bracketPairEmphasis: .flash
)
```

This removes the hard-coded background color and lets the editor use the window's natural appearance, matching the note system.

### Top Gap
The gap between the tab bar and code content comes from the SwiftUI `VStack(spacing: 0)` containing the `SourceEditor`. The SourceEditor itself has content insets. To minimize:
- Set `layout: .init(contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))` if available
- Or adjust the `SourceEditorConfiguration.Layout`

---

## Issue 4: Outline Navigation Not Legible Enough

### User Feedback
- "the outline does not look more obvious"
- "it should be more visual its hard to navigate because there are no labels on things"
- "make it much more legible and easy to use"
- "scrolling outlines and stuff like real IDEs"

### What Exists
The CodeEditSourceEditor has a folding ribbon (triangles next to foldable blocks). But there's no persistent scrollable outline/TOC panel showing function names, class definitions, `// MARK:` sections.

### Recommended Implementation
Add a `SymbolOutlineView` as a sidebar panel (like Xcode's "Document Items" or VS Code's Outline panel):

1. **Extract symbols from tree-sitter** — functions, classes, structs, enums, MARK comments
2. **Display as scrollable list** in a sidebar or panel
3. **Click to navigate** — scroll the editor to that symbol
4. **Highlight current section** based on cursor position

This could use our existing Rust FFI `code_parse_symbols()` (spec in `docs/FEATURE_SPEC_TOC_AND_FOLDING.md`) or CodeEditSourceEditor's tree-sitter to extract symbols.

### Quick Win
If the user just wants the existing gutter to be more visible:
- Increase gutter font contrast
- Add horizontal separator line between gutter and code
- Make fold triangles larger and more visible

---

## Issue 5: AppKit vs SwiftUI

### User Feedback
- "can i not use swiftui why not appkit"

### Answer
CodeEditSourceEditor IS AppKit internally — `TextViewController` is an `NSViewController`, the text view is a custom `NSView` subclass using CoreText. The SwiftUI `SourceEditor` is just an `NSViewControllerRepresentable` wrapper. The actual rendering is 100% AppKit/CoreText.

The user could use `TextViewController` directly in AppKit without the SwiftUI wrapper, but the rest of Epistemos's note detail workspace is SwiftUI. The current approach is correct.

---

## Files to Read

| File | Purpose |
|------|---------|
| `Epistemos/Views/Notes/CodeEditorView.swift` | Main editor — all changes here |
| `docs/PERF_BASELINE.md` | Performance profiling checklist |
| `docs/GPU_RENDERER_SEAM.md` | Future Metal/Rope architecture |
| `docs/FEATURE_SPEC_TOC_AND_FOLDING.md` | Symbol TOC + code folding spec |
| `docs/KIMI_AUDIT_PROMPT.md` | Previous audit checklist |

## Build Command

```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build -skipPackagePluginValidation -disableAutomaticPackageResolution
```

## Priority Order

1. **Debug and fix syntax highlighting** — runtime debugging needed
2. **Verify minimap populates** once highlighting works
3. **Set `useThemeBackground: false`** for lighter feel
4. **Add scrollable symbol outline** panel
5. **Polish gutter/outline legibility**
