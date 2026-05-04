# Research Prompt: Optimize Epistemos Code Editor to Xcode-Grade Performance

## Goal
Make the Epistemos code editor scroll, type, and render at 120fps on ProMotion displays with zero stuttering, matching Xcode's fluidity for files of any size.

## Current Stack
- **Editor engine:** CodeEditApp/CodeEditSourceEditor (v0.12.0) — custom CoreText-based text engine with lazy viewport layout
- **Syntax highlighting:** Tree-sitter via SwiftTreeSitter + CodeEditLanguages (20+ languages)
- **Theme:** Custom `EditorTheme` mapped from Epistemos's `XcodeCodeColors` (Xcode Default Dark/Light palette)
- **Integration:** SwiftUI `SourceEditor` view with `TextViewCoordinator` for cursor tracking
- **File:** `Epistemos/Views/Notes/CodeEditorView.swift`

## Key Source Files to Read
1. `Epistemos/Views/Notes/CodeEditorView.swift` — Main editor integration (SourceEditor + theme + coordinator)
2. `Epistemos/Theme/EpistemosTheme.swift` — XcodeCodeColors struct with exact Xcode plist colors (~line 194-273)
3. CodeEditSourceEditor sources (in DerivedData/SourcePackages/checkouts/):
   - `CodeEditSourceEditor/Sources/CodeEditSourceEditor/SourceEditor/SourceEditor.swift` — SwiftUI view
   - `CodeEditSourceEditor/Sources/CodeEditSourceEditor/Controller/TextViewController.swift` — Main controller
   - `CodeEditSourceEditor/Sources/CodeEditSourceEditor/Theme/EditorTheme.swift` — Theme definition
   - `CodeEditSourceEditor/Sources/CodeEditSourceEditor/TreeSitter/TreeSitterClient.swift` — Syntax highlighting engine
4. CodeEditTextView sources:
   - `CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift` — The CoreText-based text view
   - `CodeEditTextView/Sources/CodeEditTextView/TextLayoutManager/` — Lazy viewport layout engine

## What to Research
1. **Profiling:** Where are the remaining bottlenecks? Is it tree-sitter query execution, CoreText shaping, minimap rendering, or SwiftUI diffing?
2. **Tree-sitter optimization:** Can we move tree-sitter parsing to a background thread? The `TreeSitterClient` already has some async support — is it being used correctly?
3. **Minimap rendering:** Is the minimap re-rendering on every scroll? Can it be cached/composited via CALayer?
4. **SwiftUI $text binding:** The `$text: Binding<String>` diffs the entire file content on every keystroke. Is there a way to use `NSTextStorage` binding instead to avoid O(n) string comparison?
5. **Metal acceleration:** Could the minimap or gutter be rendered via Metal for zero-CPU-cost compositing?
6. **How Zed does it:** Zed uses CoreText for shaping + Metal glyph atlas for drawing. Could we integrate a similar pipeline into CodeEditTextView?
7. **Incremental highlighting:** Does CodeEditSourceEditor re-highlight the entire file or just the changed range? If full-file, how to make it incremental?

## Reference Architecture (Zed)
Zed's pipeline: CoreText shapes glyphs → alpha-only rasterization → GPU texture atlas → instanced Metal draw call. Result: rendering is GPU-bandwidth-bound, not CPU-bound. Text changes only reshape the changed glyphs. See: https://zed.dev/blog/videogame

## Constraint
- Must stay native macOS (no web views)
- Must use Swift (Epistemos is Swift 6 + Rust FFI)
- Must work on macOS 14+ (Sonoma/Tahoe)
- Cannot break the prose editor (ProseEditorView is separate)
