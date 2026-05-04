# Replacing `$text` Binding with `NSTextStorage` Bridge in Epistemos CodeEditorView

## Executive Summary

The `Binding<String>` wired into `SourceEditor` is the single most impactful per-keystroke bottleneck in Epistemos's code editor. On every character insertion, SwiftUI performs a full O(n) string equality check, re-evaluates `updateNSViewController`, and may trigger a layout pass — all on the main thread. CodeEditSourceEditor already ships a first-class `NSTextStorage` initialiser (`SourceEditor(_ text: NSTextStorage, …)`) that completely bypasses this pipeline. Switching to that path — combined with a lightweight `NSTextStorageDelegate` write-back that performs a surgical `replaceSubrange` on the `Binding<String>` only when the editor is saved — eliminates the per-keystroke O(n) diff and unlocks the headroom needed for 120 fps ProMotion rendering.[^1][^2]

***

## Why `Binding<String>` Kills Keystroke Performance

### The Full O(n) Diff on Every Character

SwiftUI's `updateNSViewController(_:context:)` is called every time any observed state in the ancestor view tree changes. For a code editor, that ancestor tree almost certainly holds `@State var text: String` — the binding passed down. When the user types a character:[^2]

1. `textViewDidChangeText` fires in `SourceEditor.Coordinator`.
2. The coordinator writes `binding.wrappedValue = textView.string` — a full string copy from the text engine to the Swift heap.
3. SwiftUI detects the state mutation and schedules a view update.
4. On the next run-loop tick, `updateNSViewController` is called again.
5. Inside `updateNSViewController`, `paramsAreEqual` runs — which itself guards against a `setText` round-trip, but the *entrance cost* (the full string copy at step 2 and SwiftUI's equality check) is already paid.

For a 100 KB Swift file (~3,500 lines), `textView.string` allocates and copies ~100 KB of UTF-16 data on **every keystroke**. At 120 fps with sustained typing at 10 keystrokes/sec, this is 1 MB/s of unnecessary heap allocation on the main thread.

### Swift String's CoW Does Not Help Here

Swift `String` implements copy-on-write, meaning reads are O(1) when the buffer has a single owner. However, `NSTextView.string` is a **bridged Objective-C string** — it crosses the Swift/ObjC bridge on every call, which forces a copy of the backing UTF-16 buffer regardless of ownership. CoW semantics do not apply across the bridge boundary.[^3][^4][^5]

### The Secondary `updateNSView` Re-highlight Loop

The existing `CodeEditorView.swift` has an additional bug documented in `CODE_EDITOR_ROOT_CAUSE-3.md`: `updateNSView` calls `textView?.highlightSyntax(theme: theme)` unconditionally. Since `cursorLine`/`cursorCol` are `@State` bindings that change on *every* selection change, this means `beginEditing/endEditing` wrapping a full syntax re-highlight fires on cursor moves as well as keystrokes. This has been independently confirmed as a root cause in the research notes.

***

## The Fix: `NSTextStorage` as the Source of Truth

### CodeEditSourceEditor's Built-in Storage API

`SourceEditor` already has two init paths:

```swift
// Path A — current, problematic
SourceEditor($text, language: language, …)

// Path B — new, storage-based
SourceEditor(myTextStorage, language: language, …)
```

When the `.storage` path is used, `makeNSViewController` calls `controller.textView.setTextStorage(textStorage)` instead of `setText`. The `NSTextStorage` object is shared by reference — both the AppKit text engine and your SwiftUI model layer hold a pointer to the *same* object. There is no copy, no bridge, no string diff.

In the coordinator's `textViewDidChangeText`, the storage path is explicitly a no-op for write-back:

```swift
@objc func textViewDidChangeText(_ notification: Notification) {
    // A plain string binding is one-way so it's not in the state binding
    if case .binding(let binding) = text {
        binding.wrappedValue = textView.string  // ← only fires for .binding path
    }
    // .storage path: nothing. Zero cost.
}
```

This means switching to `.storage` eliminates the per-keystroke `binding.wrappedValue = textView.string` allocation entirely.

### Architecture of the New Bridge

The new design moves the `NSTextStorage` object up to the document model layer — the view that owns the vault note — and passes it by reference into `SourceEditor`. Persistence (saving to disk) is handled asynchronously via `NSTextStorageDelegate`, not synchronously on every keystroke.

```
┌─────────────────────────────────────────────────────────┐
│  NoteEditorView (SwiftUI)                               │
│  @StateObject var doc: NoteDocument                     │
│    doc.textStorage: NSTextStorage  ←── single owner     │
│                                                          │
│  SourceEditor(doc.textStorage, language: …)             │
│      │                                                   │
│      └── TextViewController                             │
│              │                                           │
│              └── CodeEditTextView (CoreText engine)     │
│                      ↕ zero-copy shared reference       │
│              doc.textStorage                            │
└─────────────────────────────────────────────────────────┘
         │ NSTextStorageDelegate.didProcessEditing
         │ (fires only on actual text changes,
         │  NOT on cursor moves or scroll)
         ▼
  doc.markDirty()   ← debounce 500ms → save to disk
```

### Step-by-Step Implementation

#### Step 1 — Create a `NoteDocument` model

```swift
@MainActor
final class NoteDocument: ObservableObject {
    let textStorage = NSTextStorage()
    private var saveTask: Task<Void, Never>?
    var onSave: ((String) -> Void)?

    init(initialText: String) {
        textStorage.append(NSAttributedString(string: initialText))
    }

    /// Called by NSTextStorageDelegate after every edit.
    /// Debounces saves to avoid disk I/O on every keystroke.
    func scheduleWrite() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            onSave?(textStorage.string)
        }
    }
}
```

#### Step 2 — Make `NoteDocument` an `NSTextStorageDelegate`

```swift
extension NoteDocument: NSTextStorageDelegate {
    nonisolated func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Only fire on character changes, not attribute-only changes
        guard editedMask.contains(.editedCharacters) else { return }
        Task { @MainActor in
            self.scheduleWrite()
        }
    }
}
```

The `editedRange` and `delta` parameters tell you the exact range that changed — this is the same information that `TreeSitterClient` needs to run an incremental parse. You can route this directly to the tree-sitter client as well, avoiding a second full-document scan.[^6][^7]

#### Step 3 — Wire up the delegate and connect to `SourceEditor`

```swift
struct CodeEditorView: View {
    @StateObject private var doc: NoteDocument
    
    init(initialText: String, onSave: @escaping (String) -> Void) {
        let document = NoteDocument(initialText: initialText)
        document.onSave = onSave
        document.textStorage.delegate = document
        _doc = StateObject(wrappedValue: document)
    }

    var body: some View {
        SourceEditor(
            doc.textStorage,         // ← storage path, no Binding<String>
            language: language,
            configuration: config,
            state: $editorState
        )
    }
}
```

#### Step 4 — Fix the `updateNSView` re-highlight guard

Apply the guard documented in `CODE_EDITOR_ROOT_CAUSE-3.md` to prevent `highlightSyntax` from firing on cursor state changes:

```swift
func updateNSView(_ nsView: NSView, context: Context) {
    // Only re-apply theme when it actually changes
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```

Add `var lastAppliedTheme: EpistemosTheme?` to `TextViewCoordinator`.

***

## What This Eliminates Per-Keystroke

| Operation | Before (`Binding<String>`) | After (`NSTextStorage`) |
|---|---|---|
| String copy from text engine | ~100 KB heap alloc (O(n)) | **Zero** — shared reference |
| SwiftUI state mutation | `wrappedValue = textView.string` every keystroke | Only on 500ms debounce save |
| `updateNSViewController` re-entrance | Every keystroke + every cursor move | Only on language/config change |
| `highlightSyntax` re-apply | Every cursor move (bug) | Only on theme change |
| `NSTextStorage` delegate callback | Not used | `didProcessEditing(range:)` — O(1) |

***

## How Incremental Write-Back Works for Persistence

The `NSTextStorageDelegate` approach mirrors the pattern described by Oliver Epper and confirmed by Apple's own TextKit documentation: rather than copying the whole string on every keystroke, apply the `editedRange` and `delta` to produce a surgical splice on the persisted string.[^8][^9]

```swift
// In NSTextStorageDelegate.didProcessEditing:
// editedRange = the range of characters AFTER the edit
// delta = change in length (positive = insert, negative = delete)
//
// Characters to delete from old string = editedRange.length - delta
let charsToDelete = editedRange.length - delta
```

For a single character insertion into a 100 KB file, this is a O(1) operation on the persisted model — only a few bytes change. Compare this to the current approach which copies all 100 KB on every character.[^1]

### Unicode/Emoji Safety

`NSTextStorage` internally uses UTF-16. The `editedRange` is also UTF-16. When translating back to Swift's `String` (which uses UTF-8 internally), use the `utf16` index view:

```swift
let insertIndex = text.utf16.index(
    text.utf16.startIndex,
    offsetBy: editedRange.lowerBound
)
let endIndex = text.utf16.index(
    insertIndex,
    offsetBy: charsToDelete
)
let newChunk = textStorage.attributedSubstring(from: editedRange).string
text.replaceSubrange(insertIndex..<endIndex, with: newChunk)
```

This pattern handles emoji and other multi-scalar Unicode correctly, as demonstrated in the reference implementation.[^8]

***

## Avoiding the Infinite Update Loop

A critical subtlety: when SwiftUI's `updateNSViewController` runs (e.g., due to an external text change pushed from outside the editor), it must not re-trigger `didProcessEditing` → `scheduleWrite` → another state mutation. The standard guard is a boolean flag on the coordinator:[^10][^8]

```swift
class Coordinator {
    var isApplyingExternalChange = false
}

// In updateNSViewController, when setting text externally:
context.coordinator.isApplyingExternalChange = true
controller.textView.setTextStorage(newStorage)
context.coordinator.isApplyingExternalChange = false

// In didProcessEditing:
guard !coordinator.isApplyingExternalChange else { return }
scheduleWrite()
```

`SourceEditor`'s own coordinator already implements this with `isUpdatingFromRepresentable` and `isUpdateFromTextView` flags, so if you use the storage path you inherit this protection for free.

***

## Routing `editedRange` to Tree-Sitter

The most powerful secondary benefit of the `NSTextStorageDelegate` path is that `editedRange` and `delta` are exactly the inputs needed by `TreeSitterClient` for an incremental parse. Currently, `TreeSitterClient` receives edit notifications through `CodeEditTextView`'s internal path. But if you have a direct `NSTextStorageDelegate`, you can route the range immediately without waiting for the layout manager to process the edit:

```swift
func textStorage(
    _ textStorage: NSTextStorage,
    willProcessEditing editedMask: NSTextStorageEditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
) {
    // willProcess fires BEFORE layout; use for tree-sitter incremental parse
    guard editedMask.contains(.editedCharacters) else { return }
    treeSitterClient?.applyEdit(
        edit: InputEdit(
            startByte: UInt32(editedRange.location * 2),
            oldEndByte: UInt32((editedRange.location + editedRange.length - delta) * 2),
            newEndByte: UInt32((editedRange.location + editedRange.length) * 2),
            startPoint: …, oldEndPoint: …, newEndPoint: …
        )
    )
}
```

`TreeSitterClient.queryHighlightsForRange(range:)` already performs range-scoped queries — it does not re-highlight the full document. The bottleneck is whether the tree *parse* is incremental. The `applyEdit` call above ensures the tree is updated only for the changed region before the highlight query runs.

***

## What Does Not Change

- **The ProseEditorView** (`ProseEditorView` is a separate view with its own text engine) is completely unaffected — it has no `SourceEditor` integration.
- **The Rust FFI tree-sitter** path can continue to be used as a `HighlightProviding` implementation. The storage bridge does not change how highlight providers work.
- **The minimap** rendering path in `CodeEditSourceEditor` is unaffected. Minimap re-rendering is driven by `TextViewController`'s internal scroll/layout notifications, not by the SwiftUI binding.
- **`SourceEditorState` bindings** (cursor position, scroll position, find panel) continue to work through the existing `@Binding<SourceEditorState>` path, which is a lightweight struct, not a string.

***

## Migration Checklist

- [ ] Create `NoteDocument: ObservableObject, NSTextStorageDelegate` with a shared `NSTextStorage` instance
- [ ] Set `textStorage.delegate = doc` before passing to `SourceEditor`
- [ ] Switch `SourceEditor` initialiser from `(_ text: Binding<String>, …)` to `(_ text: NSTextStorage, …)`
- [ ] Add 500ms debounce save via `scheduleWrite()` in `didProcessEditing`
- [ ] Add `lastAppliedTheme` guard to `updateNSView` to stop re-highlighting on cursor moves
- [ ] Add `isApplyingExternalChange` flag to prevent infinite update loop on programmatic text injection
- [ ] Validate UTF-16 index math with emoji/multi-scalar Unicode test cases
- [ ] Profile with Instruments Time Profiler: confirm `textViewDidChangeText` → `binding.wrappedValue` no longer appears in the hot path

---

## References

1. [Speed Up TextEditing on Long Text - swiftui - Stack Overflow](https://stackoverflow.com/questions/70296086/speed-up-textediting-on-long-text) - With the following code performance degrades drastically as the text gets longer due to the view get...

2. [SwiftUI updateUIView seems redundant in many cases - Reddit](https://www.reddit.com/r/SwiftUI/comments/ejjnwz/swiftui_updateuiview_seems_redundant_in_many_cases/) - The updateUIView method is necessary to conform to UIViewRepresentable, but upon closer inspection i...

3. [How to prove "copy-on-write" on String type in Swift - Stack Overflow](https://stackoverflow.com/questions/46747363/how-to-prove-copy-on-write-on-string-type-in-swift) - I tried to prove myself that COW(copy on write) is supported for String in Swift. But I cannot find ...

4. [Copy-on-Write(CoW) in Swift - How It Works and Why It Optimizes ...](https://www.sagarunagar.com/blog/copy-on-write-swift) - Performance Characteristics. The uniqueness check: Is O(1); Reads ARC metadata; Does not allocate me...

5. [copy-on-write(CoW) in swift value type - Dev Genius](https://blog.devgenius.io/swift-copy-on-write-e3551848c743) - Copy-on-write (CoW) is a powerful technique for optimizing the performance and memory usage of value...

6. [textStorage(_:didProcessEditing:range:changeInLength:)](https://developer.apple.com/documentation/appkit/nstextstoragedelegate/textstorage(_:didprocessediting:range:changeinlength:)) - textStorage(_:didProcessEditing:range:changeInLength:) The method the framework calls when a text st...

7. [NSTextStorageDelegate's textStorage(_,willProcessEditing:,range ...](https://stackoverflow.com/questions/45126948/nstextstoragedelegates-textstorage-willprocessediting-range-changeinlength) - TL;DR Problem: NSTextStorage collects edited calls and combines the ranges, starting with the user-e...

8. [Wrap NSTextView in SwiftUI | oliep - Oliver Epper](https://oliver-epper.de/posts/wrap-nstextview-in-swiftui) - The basic idea is to use a NSTextStorageDelegate to apply the edit that was done to the textView.tex...

9. [Changing Text Storage - Apple Developer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextStorageLayer/Tasks/ChangingTextStorage.html) - Changing Text Storage. The behavior of an NSTextStorage object is best illustrated by following the ...

10. [Building a rich text editor for UIKit, AppKit and SwiftUI - Daniel Saidi](https://danielsaidi.com/blog/2022/06/13/building-a-rich-text-editor-for-uikit-appkit-and-swiftui) - In this article, we'll look at how to extend the rich text support in UIKit, AppKit & SwiftUI by ext...

