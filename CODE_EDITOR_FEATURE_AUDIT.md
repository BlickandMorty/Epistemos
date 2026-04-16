# Code Editor Feature Implementation Audit
## Epistemos — 2026-04-07

---

## Verification Status (2026-04-15)

| Metric | Count |
|--------|-------|
| **Total claimed features** | 8 top-level + 6 sub-features flagged as suspect |
| **✅ Verified active** | 3 top-level (Indentation Guides, Go to Line, Font Size Controls) |
| **⚠️ Partially active / modified** | 4 top-level (Persisted Prefs, Search Bar, View Options, Editor Config) |
| **❌ Reverted / replaced** | 1 top-level (Status Bar → Breadcrumb Bar) |

### Flagged Features (GPT research suspects)

| Feature | Verdict | Detail |
|---------|---------|--------|
| **Minimap** | ❌ Reverted | Removed entirely. Comment at L1232: "Minimap removed — outline navigator replaces it." `showMinimap: false` hardcoded. Old MinimapView deleted (L1963-1970). |
| **Search bar** | ⚠️ UI only | `SearchBar` view renders (L3590). But `performSearch()` is a stub (L1505-1511): `_ = direction`. No actual text search executes. |
| **Go-to-line** | ✅ Active | `GoToLineSheet` (L3670) with input validation. `goToLine()` sets `editorState.cursorPositions` (L1358-1361). |
| **Semantic sidebar** | ⚠️ Disabled | `CodeSemanticSidebar` (L2593) and `CodeContextBridge` (L2364) exist. Gated by `CodeEditorReleasePolicy.semanticSidebarEnabled = false` (L291). Never visible at runtime. |
| **Indentation guides** | ✅ Active | `SegmentedIndentationGuideView` (separate file) is wired by `EpistemosEditorCoordinator.setupIndentationGuides()` (L1774). Active guide highlighting, scroll tracking, cursor-aware. |
| **Persisted prefs** | ⚠️ 5 of 6 | `showMinimap` pref removed. Remaining 5 (`wrapLines`, `showInvisibles`, `fontSize`, `useSpaces`, `tabWidth`) are active and wired to `editorConfiguration`. |

### Key Architecture Changes Since Original Audit

1. **Underlying editor replaced:** Original claimed NSViewRepresentable wrapping NSTextView + LineNumberGutter + MinimapView. Current code uses **CodeEditSourceEditor** (`SourceEditor` SwiftUI view, L1441) with tree-sitter highlighting.
2. **Status bar → Breadcrumb bar:** The claimed `statusBar` computed property with `[Ln X, Col Y] [N lines] | [Search] ... [Settings] [View] [AI] [Language] [Encoding]` does not exist. Replaced by `EditorBreadcrumbBar` (separate file) with an inline toolbar overlay.
3. **Minimap → Outline Navigator:** `OutlineNavigatorView` (separate file) replaces the minimap. Parses code structure and shows a navigable outline panel.
4. **Code file lines: ~3,755** (not ~3,600 as claimed).

---

## Features — Detailed Verification

### 1. VS Code-Style Indentation Guides

**Original claim:** `IndentationGuideView` class with `draw(_:)` override, `zPosition = -1`.

**Verification: ✅ Verified active — implementation differs from description**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| Vertical guide lines at each indent level | ✅ Active | `SegmentedIndentationGuideView` (separate file, L30) |
| Active guide highlighting (cursor indent level) | ✅ Active | `setActiveLine()` called from `updateActiveIndentationGuideLevel()` (L1866-1868) |
| Configurable indent width | ✅ Active | `guideView.indentWidth = 16` (L1780) |
| Subtle gray color scheme (15%/35% opacity) | ⚠️ Modified | Uses `NSColor.systemGray * 0.2` normal, `controlAccentColor * 0.4` active (SegmentedIndentationGuideView L38-44) |
| Real-time updates on cursor movement and scroll | ✅ Active | Cursor: L1912; Scroll: L1809-1816 with debounce |
| Custom `NSView` with `draw(_:)` override | ⚠️ Modified | Uses `SegmentedIndentationGuideView` (NSView subclass) not `IndentationGuideView` |
| `zPosition = -1` | ⚠️ Modified | `zPosition = -1000` (L1790) |

---

### 2. Editor Preferences (Persisted)

**Original claim:** 6 `@AppStorage` properties including `showMinimap`.

**Verification: ⚠️ 5 of 6 active — showMinimap removed**

| Setting | Key | Claimed Default | Actual Status | Evidence |
|---------|-----|-----------------|---------------|----------|
| Word Wrap | `codeEditor.wrapLines` | `false` | ✅ Active | L1231, wired to config L1687 |
| Show Minimap | `codeEditor.showMinimap` | `true` | ❌ Removed | L1232 comment: "Minimap removed — outline navigator replaces it" |
| Show Invisibles | `codeEditor.showInvisibles` | `false` | ✅ Active | L1233, wired to view options menu L1568 |
| Font Size | `codeEditor.fontSize` | `13` | ✅ Active | L1234, wired to config L1685 |
| Use Spaces | `codeEditor.useSpaces` | `true` | ✅ Active | L1235, in settings menu L1525 |
| Tab Width | `codeEditor.tabWidth` | `4` | ✅ Active | L1236, wired to config L1688 |

**Note:** `showInvisibles` is stored and toggled in the menu, but it is NOT passed to `SourceEditorConfiguration`. Its effect on the actual editor rendering is unverified — the `EditorTheme` has an `invisibles` color field, but no `showInvisibles` boolean is passed to `SourceEditor`.

---

### 3. Status Bar Enhancements

**Original claim:** `statusBar` computed property with Search Button (⌘F), Settings Menu (gear), View Menu (eye), clickable Cursor Position → Go to Line. Layout: `[Ln X, Col Y] [N lines] | [Search] ... [Settings] [View] [AI] [Language] [Encoding]`.

**Verification: ❌ Reverted — replaced by Breadcrumb Bar**

There is no `statusBar` computed property anywhere in `CodeEditorView.swift`. The claimed status bar layout `[Ln X, Col Y] [N lines] | [Search] ... [Settings] [View] [AI] [Language] [Encoding]` does not exist.

**What exists instead:** A `breadcrumbBar` (L1365-1416) containing:
- File path / code structure breadcrumbs via `EditorBreadcrumbBar` (separate file)
- Inline toolbar overlay with: search toggle, outline toggle, view options menu (eye), settings menu (gear)
- Go to Line sheet attached to breadcrumb bar (L1406-1416)

| Claimed Control | Actual Status | Evidence |
|-----------------|---------------|----------|
| Search Button (⌘F) | ✅ In breadcrumb bar | L1381-1388 |
| Settings Menu (gear) | ✅ In breadcrumb bar | L1402 `editorSettingsMenu` |
| View Menu (eye) | ✅ In breadcrumb bar | L1401 `viewOptionsMenu` |
| Cursor Position → Go to Line | ⚠️ Modified | No clickable "Ln X, Col Y" button. Go to Line in gear menu (L1517-1521) |
| Language display | ❌ Not present | No language indicator in breadcrumb bar |
| Encoding display | ❌ Not present | No encoding indicator |
| Line count display | ❌ Not present | No "N lines" display |

---

### 4. Search/Find Bar

**Original claim:** Slide-in overlay, text field, case sensitive toggle, find next/prev, close, material background, auto-focus, ⌘F/Enter/Escape shortcuts.

**Verification: ⚠️ UI exists — search logic is a non-functional stub**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| Slide-in overlay from top | ✅ Active | L1464-1467 `.transition(.move(edge: .top))` |
| Search query text field | ✅ Active | L3604 `TextField("Find", text: $query)` |
| Case sensitive toggle | ✅ Active | L3624-3631 |
| Find Next/Previous buttons | ✅ UI exists | L3633-3647 |
| Close button | ✅ Active | L3649-3654 |
| Material design background | ✅ Active | L3658 `.ultraThinMaterial` |
| Auto-focus on appear | ✅ Active | L3662-3664 `isFocused = true` |
| ⌘F: Toggle search bar | ⚠️ No keyboard shortcut | Toggle button exists (L1381) but no `.keyboardShortcut("f", modifiers: .command)` |
| Enter: Find next | ✅ Active | L3607-3609 `.onSubmit { onFindNext() }` |
| Escape: Close search | ❌ Not implemented | No escape key handler |
| **Actual search execution** | ❌ **Stub** | `performSearch()` at L1505-1511 is empty: `_ = direction`. No text is found. |

---

### 5. Go to Line Sheet

**Original claim:** Modal sheet, line number input with validation, "of N" total lines, Cancel/Go buttons, Enter/Escape shortcuts.

**Verification: ✅ Verified active**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| Modal sheet interface | ✅ Active | L1406 `.sheet(isPresented: $showGoToLineSheet)` |
| Line number input with validation | ✅ Active | L3716-3721 `parseLineNumber()` validates > 0 && <= totalLines |
| Shows "of N" total lines | ✅ Active | L3692 `Text("of \(totalLines)")` |
| Cancel and Go buttons | ✅ Active | L3697-3707 |
| Enter → Go | ✅ Active | L3705 `.keyboardShortcut(.defaultAction)` |
| Escape → Cancel | ✅ Active | L3700 `.keyboardShortcut(.cancelAction)` |
| Click cursor position in status bar | ❌ No status bar | Accessible via gear menu (L1517-1521) |
| ⌘L shortcut | ❌ Not implemented | Listed as "planned" in original audit |
| Actual line navigation | ✅ Active | `goToLine()` sets `editorState.cursorPositions` (L1358-1361) |

---

### 6. Font Size Controls

**Original claim:** Settings menu access, ⌘+/⌘-/⌘0 shortcuts (planned), min 8pt, max 32pt.

**Verification: ✅ Verified active**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| Settings menu access | ✅ Active | Gear menu L1534-1552 |
| Decrease font size | ✅ Active | `max(8, fontSize - 1)` (L1536) |
| Increase font size | ✅ Active | `min(32, fontSize + 1)` (L1542) |
| Reset to default (13pt) | ✅ Active | `fontSize = 13` (L1548) |
| Minimum: 8pt | ✅ Active | L1536 |
| Maximum: 32pt | ✅ Active | L1542 |
| ⌘+/⌘-/⌘0 shortcuts | ❌ Not implemented | Listed as "planned" in original audit |
| Font wired to editor | ✅ Active | `editorConfiguration` L1685 |

---

### 7. View Options Menu

**Original claim:** Eye icon with Word Wrap, Minimap toggle, Show Invisibles toggle.

**Verification: ⚠️ Modified — minimap toggle replaced by outline navigator toggle**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| Eye icon in status bar | ⚠️ In breadcrumb bar, not status bar | L1572 `Image(systemName: "eye")` |
| Word Wrap toggle | ✅ Active | L1566 |
| Minimap toggle | ❌ Replaced | "Outline Navigator" toggle at L1567 |
| Show Invisibles toggle | ✅ Active (UI only) | L1568 — but see note on Pref #2 about unverified editor wiring |

---

### 8. Editor Configuration Integration

**Original claim:** `editorConfiguration` computed property with dynamic font size, line wrapping, tab width, minimap visibility from `@AppStorage`.

**Verification: ⚠️ Partially active — minimap hardcoded off**

| Claimed Detail | Actual Status | Evidence |
|----------------|---------------|----------|
| `editorConfiguration` computed property | ✅ Active | L1680-1698 |
| Font size from `@AppStorage` | ✅ Active | L1685 `.monospacedSystemFont(ofSize: fontSize, ...)` |
| Line wrapping from `@AppStorage` | ✅ Active | L1687 `wrapLines: wrapLines` |
| Tab width from `@AppStorage` | ✅ Active | L1688 `tabWidth: tabWidth` |
| Minimap visibility from `@AppStorage` | ❌ Hardcoded off | L1694 `showMinimap: false` (not reading from pref) |

**Additional configuration not mentioned in original audit:**
- `lineHeightMultiple: 1.35` (L1686)
- `bracketPairEmphasis: .flash` (L1689)
- `showGutter: true` (L1693) — line numbers via CodeEditSourceEditor
- `showFoldingRibbon: true` (L1695) — code folding UI

---

## Architecture — Original Claims vs Reality

### Body Refactoring

| Claimed Computed Property | Actual Status | Evidence |
|---------------------------|---------------|----------|
| `editorContent` | ✅ Active | L1338 |
| `mainEditorPane` | ✅ Active | L1351 |
| `editorWithSearch` | ✅ Active | L1439 |
| `editorCoordinator` | ❌ Not a computed property | Coordinator managed via `sourceEditorCoordinator` state + `ensureEditorCoordinator()` |
| `searchBarOverlay` | ✅ Active | L1455 |
| `semanticSidebar` | ⚠️ Exists but runtime-disabled | L1471 — gated by `CodeEditorReleasePolicy.semanticSidebarEnabled = false` (L291) |
| `companionToast` | ❌ Not in CodeEditorView body | `CodeCompanionToast` struct exists (L1127) but not used in main editor layout |

### Underlying Editor Stack

| Original Claim | Actual Code |
|----------------|-------------|
| NSViewRepresentable → NSScrollView → CodeTextView (NSTextView) | `SourceEditor` from CodeEditSourceEditor package (L1441) |
| LineNumberGutter (NSView, 48pt, left) | Built-in to `SourceEditor` via `showGutter: true` |
| MinimapView (NSView, 80pt, right) | Removed. `showMinimap: false`. Replaced by `OutlineNavigatorView`. |
| TextKit 1 (NSLayoutManager + NSTextStorage) | CodeEditSourceEditor uses TextKit 2 with tree-sitter |

---

## Features NOT in Original Audit (Present in Code)

| Feature | Status | Evidence |
|---------|--------|----------|
| **Outline Navigator** | ✅ Active | `OutlineNavigatorView` (separate file), toggle in breadcrumb bar L1390-1399 |
| **Breadcrumb Bar** | ✅ Active | `EditorBreadcrumbBar` (separate file), L1365-1416 |
| **Code Folding Ribbon** | ✅ Active | `showFoldingRibbon: true` (L1695) |
| **Bracket Pair Flash** | ✅ Active | `bracketPairEmphasis: .flash` (L1689) |
| **Tree-sitter Syntax Highlighting** | ✅ Active | Via CodeEditSourceEditor + CodeEditLanguages, 20+ languages (L1653-1675) |
| **Metal Compute Engine** | ✅ Active (dormant) | `MetalComputeEngine` actor (L380) for GPU-accelerated semantic search — used by `CodeCompanionService` which is release-gated |
| **AI Code Companion** | ⚠️ Disabled | `CodeCompanionService` (L739), `CodeEditorReleasePolicy.aiPartnerEnabled = false` (L292) |
| **Code Context Bridge** | ⚠️ Disabled | `CodeContextBridge` (L2364) — only initialized when semantic sidebar is visible, which is release-gated |
| **Code Inspector Views** | ✅ Active | `CodeInspectorPreview` (L1977), `CodeInspectorEditor` for graph node code display |

---

## Code Statistics — Corrected

| Metric | Original Claim | Actual (2026-04-15) |
|--------|---------------|---------------------|
| Total file lines | ~3,600 | ~3,755 |
| New views added | 2 (SearchBar, GoToLineSheet) | 2 confirmed + OutlineNavigatorView, EditorBreadcrumbBar, SegmentedIndentationGuideView in separate files |
| New classes | 3 (IndentationGuideView, IndentationStructure, helpers) | `SegmentedIndentationGuideView` (separate file), `EpistemosEditorCoordinator`, `MetalComputeEngine`, `AnalysisQueue`, `ComputePerformanceMonitor`, `CodeCompanionService`, `CodeContextBridge` |
| Computed properties added | 7 | 6 confirmed in CodeEditorView (`editorContent`, `mainEditorPane`, `editorWithSearch`, `searchBarOverlay`, `semanticSidebar`, `editorConfiguration`) |
| @AppStorage properties | 6 | 5 (showMinimap removed) |

---

## NoteDetailWorkspaceView Routing (Verified)

Code vs prose routing at `NoteDetailWorkspaceView.swift` L981-1001:

```swift
@ViewBuilder
private func noteEditorSurface(page: SDPage) -> some View {
    if let path = page.filePath,
       let lang = CodeLanguage.detect(from: path) {
        CodeEditorView(content: ..., language: lang, filePath: path, onContentChange: ...)
    } else {
        ProseEditorView(page: page, isEditable: true, ...)
    }
}
```

`CodeLanguage.detect(from:)` (L299-341) returns non-nil for 30+ file extensions, nil for `.md`, `.markdown`, `.txt` (routed to prose editor).

---

## Future Enhancements (Not Implemented) — Updated

1. ~~**Keyboard Shortcuts:** Full implementation with Commands menu~~ — Still not implemented (⌘F, ⌘L, ⌘+/- not wired)
2. ~~**Find Integration:** Connect to CodeEditSourceEditor's built-in find~~ — `performSearch()` is still a stub
3. ~~**Go to Line:** Implement actual line navigation~~ — ✅ **Done.** `goToLine()` works via `editorState.cursorPositions`
4. **Whitespace Visualization:** `showInvisibles` pref exists but may not be wired to the editor
5. **Split Editor:** Side-by-side editing — not implemented
6. **Breadcrumbs:** ~~File path navigation~~ — ✅ **Done.** `EditorBreadcrumbBar` with `BreadcrumbBuilder`
7. ~~**Status Bar Info:** File size, encoding detection~~ — No status bar exists; encoding/file size not shown
8. **Minimap:** Removed. Could be re-enabled via `showMinimap: true` in `editorConfiguration` since CodeEditSourceEditor supports it

---

## Conclusion — Updated (2026-04-15)

The original audit from 2026-04-07 described a feature set that was **partially implemented, partially aspirational, and partially reverted** by subsequent refactoring. The editor stack was replaced from a custom NSTextView + NSViewRepresentable to the CodeEditSourceEditor package, which brought better tree-sitter support and eliminated the Tahoe `drawBackground` rendering bug, but also removed the custom minimap and status bar.

**What genuinely works:**
- VS Code-style indentation guides (via SegmentedIndentationGuideView)
- Go to Line navigation
- Font size controls (8-32pt, persisted)
- Word wrap toggle (persisted)
- Tab width / spaces-vs-tabs settings (persisted)
- Outline navigator (replacement for minimap)
- Breadcrumb bar with code structure navigation
- Code folding ribbon
- Bracket pair flash highlighting
- Tree-sitter syntax highlighting (20+ languages)

**What exists as UI but doesn't function:**
- Search bar renders but `performSearch()` is a stub
- Show Invisibles toggle exists but may not reach the editor

**What is code-complete but runtime-disabled:**
- Semantic sidebar (release-gated)
- AI Code Companion (release-gated)
- Metal Compute Engine (only used by disabled companion)

**What was removed:**
- Minimap (replaced by outline navigator)
- Custom status bar (replaced by breadcrumb bar)
- Custom NSTextView/LineNumberGutter/MinimapView (replaced by CodeEditSourceEditor)
