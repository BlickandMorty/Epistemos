# Writer v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove academic writer mode, add prose writing features (focus mode, typewriter scroll, word targets, section navigator), and build a new TextKit 2 rich text document editor with DOCX import/export.

**Architecture:** Three workstreams executed in order. (C) Delete the 8-file Writer directory and clean NoteWindowManager references. (A) Bolt four writing features onto the existing ClickableTextView/ProseEditorRepresentable stack. (B) Build a new TextKit 2 document editor as a third mode alongside Editor and Preview, with RTFD persistence, format bar, and DOCX support.

**Tech Stack:** Swift, AppKit (NSTextView, NSTextContentStorage, NSTextLayoutManager, NSTextTable, NSTextList, NSTextAttachment), SwiftUI, SwiftData

**Design doc:** `docs/plans/2026-03-08-writer-v2-design.md`

---

## Task 1: Delete Writer Mode Files

**Files:**
- Delete: `Epistemos/Views/Notes/Writer/WriterModeView.swift`
- Delete: `Epistemos/Views/Notes/Writer/PagedDocumentView.swift`
- Delete: `Epistemos/Views/Notes/Writer/WriterTextStorage.swift`
- Delete: `Epistemos/Views/Notes/Writer/WriterFormatState.swift`
- Delete: `Epistemos/Views/Notes/Writer/WriterFormatBar.swift`
- Delete: `Epistemos/Views/Notes/Writer/WriterExportService.swift`
- Delete: `Epistemos/Views/Notes/Writer/WriterPDFPreview.swift`
- Delete: `Epistemos/Views/Notes/Writer/AcademicStyle.swift`
- Modify: `Epistemos.xcodeproj/project.pbxproj` (remove file references)

**Step 1: Delete all 8 Writer files**

```bash
rm Epistemos/Views/Notes/Writer/WriterModeView.swift
rm Epistemos/Views/Notes/Writer/PagedDocumentView.swift
rm Epistemos/Views/Notes/Writer/WriterTextStorage.swift
rm Epistemos/Views/Notes/Writer/WriterFormatState.swift
rm Epistemos/Views/Notes/Writer/WriterFormatBar.swift
rm Epistemos/Views/Notes/Writer/WriterExportService.swift
rm Epistemos/Views/Notes/Writer/WriterPDFPreview.swift
rm Epistemos/Views/Notes/Writer/AcademicStyle.swift
rmdir Epistemos/Views/Notes/Writer
```

**Step 2: Remove file references from Xcode project**

Remove the 8 file references from `Epistemos.xcodeproj/project.pbxproj`. Each file has entries in `PBXBuildFile`, `PBXFileReference`, and `PBXGroup` sections. Also remove the `Writer` group.

**Step 3: Clean NoteWindowManager references**

Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`

Remove:
- Line 438: `@State private var showWriterMode = false`
- Lines 478-483: The `if showWriterMode { WriterModeView(...) }` branch
- Lines 593, 600, 621: The `!showWriterMode &&` guards on toolbar items
- Lines 664-666: The `Button("") { toggleWriterMode() }` hidden keyboard shortcut
- Lines 1056-1064: The `toggleWriterMode()` function
- Line 1068: The `guard !showWriterMode else { return }` in `togglePreviewMode()`
- Lines 1324-1330: The Writer Mode context menu button

The `import AppKit` for `WriterModeView` is not needed here since the file imports `SwiftUI`.

**Step 4: Clean test references**

Modify: `EpistemosTests/SOARTests.swift` — remove `MassGeneratedLibraryWriterStyle1000Tests` suite (lines 684-699+).
Modify: `EpistemosTests/NoteChatParserTests.swift` — remove the line referencing `AcademicStyle` (line 138) and its enclosing test if it only tests writer types.

**Step 5: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED with no errors related to Writer/AcademicStyle/WriterFormat.

**Step 6: Commit**

```bash
git add -A Epistemos/Views/Notes/Writer/
git add Epistemos.xcodeproj/project.pbxproj
git add Epistemos/Views/Notes/NoteWindowManager.swift
git add EpistemosTests/SOARTests.swift EpistemosTests/NoteChatParserTests.swift
git commit -m "Remove Writer mode (8 files) — replaced by prose writing features + TextKit 2 document mode"
```

---

## Task 2: Focus Mode — State + Drawing

**Files:**
- Modify: `Epistemos/State/NotesUIState.swift:9`
- Modify: `Epistemos/Views/Notes/ClickableTextView.swift:25`
- Test: `EpistemosTests/FocusModeTests.swift`

**Step 1: Write failing tests**

Create `EpistemosTests/FocusModeTests.swift`:

```swift
import Testing
@testable import Epistemos

@Suite("Focus Mode")
struct FocusModeTests {

    @Test("Focus mode state toggles correctly")
    @MainActor func focusModeToggle() {
        let state = NotesUIState()
        #expect(!state.isFocusMode)
        state.isFocusMode = true
        #expect(state.isFocusMode)
        state.isFocusMode = false
        #expect(!state.isFocusMode)
    }

    @Test("Focus mode active paragraph detection")
    func activeParagraphRange() {
        let text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        let nsText = text as NSString

        // Cursor in second paragraph (position 18 = start of "Second")
        let cursorPos = 18
        let range = nsText.paragraphRange(for: NSRange(location: cursorPos, length: 0))
        #expect(range.location == 18)
        #expect(nsText.substring(with: range).hasPrefix("Second"))
    }

    @Test("Session word target tracks delta")
    @MainActor func sessionWordTarget() {
        let state = NotesUIState()
        state.sessionStartWordCount = 100
        state.sessionWordTarget = 500
        // After writing 200 words (current = 300):
        let current = 300
        let delta = current - state.sessionStartWordCount
        #expect(delta == 200)
        let progress = Double(delta) / Double(state.sessionWordTarget!)
        #expect(progress > 0.39 && progress < 0.41)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'FocusMode|FAIL'`
Expected: FAIL — `isFocusMode` property doesn't exist.

**Step 3: Add state properties to NotesUIState**

Modify `Epistemos/State/NotesUIState.swift` — add after the `debouncedSearchQuery` property (around line 23):

```swift
    // MARK: - Focus Mode

    /// When true, dims all paragraphs except the one containing the cursor.
    var isFocusMode = false

    // MARK: - Session Word Target

    /// Word count at the start of the current writing session.
    var sessionStartWordCount = 0

    /// Target word count for the session (nil = no target).
    var sessionWordTarget: Int?
```

**Step 4: Add focus mode drawing to ClickableTextView**

Modify `Epistemos/Views/Notes/ClickableTextView.swift` — add property and drawing method:

Add property at line 48 (after `var pageId: String?`):

```swift
    /// When true, dim all paragraphs except the one containing the insertion point.
    nonisolated(unsafe) var isFocusMode = false
```

Add method after `drawFoldIndicators` (find the end of the existing drawing methods):

```swift
    // MARK: - Focus Mode Dim

    /// Apply temporary foreground attributes to dim non-active paragraphs.
    /// Called by Coordinator on selection change when focus mode is active.
    func applyFocusDimming() {
        guard isFocusMode, let lm = layoutManager, let ts = textStorage else {
            // Clear any existing dimming
            layoutManager?.removeTemporaryAttribute(.foregroundColor,
                forCharacterRange: NSRange(location: 0, length: (string as NSString).length))
            return
        }

        let fullRange = NSRange(location: 0, length: ts.length)
        let cursorRange = selectedRange()
        let activeParaRange = (string as NSString).paragraphRange(for: cursorRange)

        // Dim everything
        lm.addTemporaryAttribute(.foregroundColor,
            value: NSColor.textColor.withAlphaComponent(0.25),
            forCharacterRange: fullRange)

        // Restore active paragraph
        lm.removeTemporaryAttribute(.foregroundColor,
            forCharacterRange: activeParaRange)
    }

    /// Clear all focus mode dimming.
    func clearFocusDimming() {
        layoutManager?.removeTemporaryAttribute(.foregroundColor,
            forCharacterRange: NSRange(location: 0, length: (string as NSString).length))
    }
```

**Step 5: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'FocusMode|PASS|FAIL'`
Expected: All 3 FocusModeTests PASS.

**Step 6: Commit**

```bash
git add Epistemos/State/NotesUIState.swift Epistemos/Views/Notes/ClickableTextView.swift EpistemosTests/FocusModeTests.swift
git commit -m "Add focus mode state + paragraph dimming via temporary attributes"
```

---

## Task 3: Focus Mode — Wiring + Typewriter Scroll

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift:702` (Coordinator)
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift` (keyboard shortcut)

**Step 1: Wire focus mode in Coordinator**

Modify `Epistemos/Views/Notes/ProseEditorRepresentable.swift` — in the Coordinator's `textViewDidChangeSelection`:

```swift
func textViewDidChangeSelection(_ notification: Notification) {
    guard let tv = notification.object as? ClickableTextView else { return }
    if tv.isFocusMode {
        tv.applyFocusDimming()
        // Typewriter scroll: center the cursor line in the scroll view
        if let scrollView = tv.enclosingScrollView {
            let insertionRect = tv.firstRect(forCharacterRange: tv.selectedRange(), actualRange: nil)
            let localRect = tv.convert(insertionRect, from: nil)
            let visibleHeight = scrollView.contentView.bounds.height
            var scrollPoint = localRect.origin
            scrollPoint.y -= visibleHeight / 2
            scrollPoint.y = max(0, scrollPoint.y)
            tv.scroll(scrollPoint)
        }
    }
}
```

**Step 2: Sync isFocusMode from NotesUIState to ClickableTextView**

In the Coordinator's `updateNSView` (or wherever `isDark` is synced to the text view), add:

```swift
// Find where the text view's properties are synced from parent state
// Add alongside existing property sync:
if let tv = textView as? ClickableTextView {
    let wasFocus = tv.isFocusMode
    tv.isFocusMode = notesUI.isFocusMode  // notesUI is the NotesUIState from environment
    if wasFocus && !tv.isFocusMode {
        tv.clearFocusDimming()
    } else if tv.isFocusMode {
        tv.applyFocusDimming()
    }
}
```

Note: Check how `ProseEditorRepresentable` accesses `NotesUIState`. It may need to be passed as a parameter or read from the parent. Check existing property sync patterns in `updateNSView`.

**Step 3: Add keyboard shortcut in NoteWindowManager**

Add Cmd+Shift+F hidden button alongside the existing Cmd+R and Cmd+E shortcuts:

```swift
Button("") { notesUI.isFocusMode.toggle() }
    .keyboardShortcut("f", modifiers: [.command, .shift])
    .hidden()
```

Note: `notesUI` is `NotesUIState` from environment. Check how NoteWindowManager accesses it — it's `@Environment(NotesUIState.self) private var notesUI`.

**Step 4: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/ProseEditorRepresentable.swift Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "Wire focus mode toggle (Cmd+Shift+F) with typewriter scroll"
```

---

## Task 4: Session Word Target UI

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift` (bottom toolbar)
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift` (word count tracking)

**Step 1: Add word target UI to bottom toolbar**

Find the existing word count display in NoteWindowManager's bottom toolbar. Add a progress indicator next to it when a session target is set:

```swift
// In the bottom toolbar area where wordCount is displayed:
if let target = notesUI.sessionWordTarget, target > 0 {
    let delta = max(0, wordCount - notesUI.sessionStartWordCount)
    let progress = min(1.0, Double(delta) / Double(target))
    HStack(spacing: 4) {
        ProgressView(value: progress)
            .frame(width: 60)
            .tint(progress >= 1.0 ? .green : .accentColor)
        Text("\(delta)/\(target)")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
```

**Step 2: Add "Set Word Target" to context menu or toolbar**

Add a menu item or toolbar button that lets the user set a session word target. On activation, capture the current word count as `sessionStartWordCount`:

```swift
Button {
    notesUI.sessionStartWordCount = wordCount
    notesUI.sessionWordTarget = 500  // Default, or show a sheet to pick
} label: {
    Label("Set Word Target", systemImage: "target")
}
```

For clearing the target:

```swift
Button {
    notesUI.sessionWordTarget = nil
} label: {
    Label("Clear Word Target", systemImage: "xmark.circle")
}
```

**Step 3: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "Add session word target with progress indicator in bottom toolbar"
```

---

## Task 5: Section Navigator (Extend Table of Contents)

**Files:**
- Modify: `Epistemos/Views/Notes/NoteTableOfContents.swift:21`
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`
- Test: `EpistemosTests/FocusModeTests.swift` (extend)

**Step 1: Write test for TOC parser**

Add to `EpistemosTests/FocusModeTests.swift`:

```swift
@Test("TOC parser extracts headings with correct offsets")
func tocParserHeadings() {
    let md = "# Title\n\nSome text\n\n## Section A\n\nMore text\n\n### Subsection\n\n## Section B"
    let items = TOCParser.parse(md)
    let headings = items.filter { $0.kind == .heading }
    #expect(headings.count == 4)
    #expect(headings[0].title == "Title")
    #expect(headings[0].level == 1)
    #expect(headings[1].title == "Section A")
    #expect(headings[1].level == 2)
    #expect(headings[2].title == "Subsection")
    #expect(headings[2].level == 3)
    #expect(headings[3].title == "Section B")
    #expect(headings[3].level == 2)
}
```

**Step 2: Run test — should pass already (TOCParser exists)**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep tocParserHeadings`
Expected: PASS (TOCParser.parse already works).

**Step 3: Add section navigator dropdown to NoteWindowManager toolbar**

Add a toolbar item that shows headings from the current page body. On click, scroll the editor to the heading's character offset by posting a notification or calling through the Coordinator:

```swift
// Toolbar item — section navigator
Menu {
    let body = pages.first?.loadBody() ?? ""
    let headings = TOCParser.parse(body).filter { $0.kind == .heading }
    if headings.isEmpty {
        Text("No headings")
    } else {
        ForEach(headings) { item in
            Button {
                scrollToCharOffset(item.charOffset)
            } label: {
                HStack {
                    Text(String(repeating: "  ", count: item.level - 1) + item.title)
                }
            }
        }
    }
} label: {
    Label("Sections", systemImage: "list.bullet.indent")
}
```

Important: Do NOT call `loadBody()` in the view body — this reads from disk on every SwiftUI re-evaluation. Instead, compute the TOC items on text change (debounced) and store as `@State private var tocItems: [TOCItem] = []`.

**Step 4: Add scroll-to-offset mechanism**

Post a notification with the character offset. The Coordinator receives it and calls `textView.scrollRangeToVisible(NSRange(location: offset, length: 0))`:

```swift
// In ClickableTextView or via notification:
static let scrollToOffsetNotification = Notification.Name("EpistemosScrollToOffset")

// In Coordinator, observe this notification and scroll:
func handleScrollToOffset(_ notification: Notification) {
    guard let offset = notification.userInfo?["charOffset"] as? Int,
          let pageId = notification.userInfo?["pageId"] as? String,
          pageId == self.currentPageId,
          let tv = textView else { return }
    tv.scrollRangeToVisible(NSRange(location: offset, length: 0))
    tv.setSelectedRange(NSRange(location: offset, length: 0))
}
```

**Step 5: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 6: Commit**

```bash
git add Epistemos/Views/Notes/NoteWindowManager.swift Epistemos/Views/Notes/NoteTableOfContents.swift EpistemosTests/FocusModeTests.swift
git commit -m "Add section navigator dropdown with scroll-to-heading"
```

---

## Task 6: SDPage Format Property + NoteFileStorage RTFD

**Files:**
- Modify: `Epistemos/Models/SDPage.swift:14`
- Modify: `Epistemos/Sync/NoteFileStorage.swift`
- Test: `EpistemosTests/DocumentModeTests.swift`

**Step 1: Write failing tests**

Create `EpistemosTests/DocumentModeTests.swift`:

```swift
import Testing
import AppKit
@testable import Epistemos

@Suite("Document Mode - Storage")
struct DocumentModeStorageTests {

    @Test("RTFD round-trip preserves attributed string")
    func rtfdRoundTrip() throws {
        let pageId = "test-rtfd-\(UUID().uuidString)"
        let original = NSAttributedString(string: "Hello bold world", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ])

        NoteFileStorage.writeRichText(pageId: pageId, content: original)
        let loaded = NoteFileStorage.readRichText(pageId: pageId)
        #expect(loaded != nil)
        #expect(loaded?.string == "Hello bold world")

        // Cleanup
        NoteFileStorage.deleteRichText(pageId: pageId)
    }

    @Test("readRichText returns nil for nonexistent page")
    func rtfdMissing() {
        let result = NoteFileStorage.readRichText(pageId: "nonexistent-page-id")
        #expect(result == nil)
    }

    @Test("deleteRichText removes RTFD bundle")
    func rtfdDelete() {
        let pageId = "test-rtfd-delete-\(UUID().uuidString)"
        let content = NSAttributedString(string: "Delete me")
        NoteFileStorage.writeRichText(pageId: pageId, content: content)
        #expect(NoteFileStorage.readRichText(pageId: pageId) != nil)
        NoteFileStorage.deleteRichText(pageId: pageId)
        #expect(NoteFileStorage.readRichText(pageId: pageId) == nil)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'DocumentMode|FAIL'`
Expected: FAIL — `writeRichText`/`readRichText` don't exist.

**Step 3: Add format property to SDPage**

Modify `Epistemos/Models/SDPage.swift` — add after `var wordCount: Int = 0` (around line 34):

```swift
    /// Page format: "markdown" (default) or "richtext" (TextKit 2 document mode).
    var format: String = "markdown"

    /// True if this page uses rich text (TextKit 2 document mode).
    var isRichText: Bool { format == "richtext" }
```

**Step 4: Add RTFD methods to NoteFileStorage**

Modify `Epistemos/Sync/NoteFileStorage.swift` — add after `bodyExists` (around line 96):

```swift
    // MARK: - Rich Text (RTFD) Storage

    /// Read a rich text document from disk. Returns nil if file doesn't exist.
    nonisolated static func readRichText(pageId: String) -> NSAttributedString? {
        guard isValidPageId(pageId) else { return nil }
        let url = storageDirectory().appendingPathComponent("\(pageId).rtfd")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
    }

    /// Write a rich text document to disk as RTFD bundle.
    nonisolated static func writeRichText(pageId: String, content: NSAttributedString) {
        guard isValidPageId(pageId) else {
            logger.error("Invalid pageId rejected in writeRichText: \(pageId.prefix(20))")
            return
        }
        let url = storageDirectory().appendingPathComponent("\(pageId).rtfd")
        let range = NSRange(location: 0, length: content.length)
        do {
            let wrapper = try content.fileWrapper(from: range, documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtfd
            ])
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        } catch {
            logger.error("Failed to write RTFD for \(pageId): \(error.localizedDescription)")
        }
    }

    /// Delete a rich text document bundle.
    nonisolated static func deleteRichText(pageId: String) {
        guard isValidPageId(pageId) else { return }
        let url = storageDirectory().appendingPathComponent("\(pageId).rtfd")
        try? FileManager.default.removeItem(at: url)
    }

    /// Check if an RTFD file exists on disk.
    nonisolated static func richTextExists(pageId: String) -> Bool {
        guard isValidPageId(pageId) else { return false }
        let url = storageDirectory().appendingPathComponent("\(pageId).rtfd")
        return FileManager.default.fileExists(atPath: url.path)
    }
```

**Step 5: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'DocumentMode|PASS|FAIL'`
Expected: All 3 DocumentModeStorageTests PASS.

**Step 6: Commit**

```bash
git add Epistemos/Models/SDPage.swift Epistemos/Sync/NoteFileStorage.swift EpistemosTests/DocumentModeTests.swift
git commit -m "Add SDPage.format property + NoteFileStorage RTFD read/write/delete"
```

---

## Task 7: DocumentTextView (TextKit 2 NSTextView Subclass)

**Files:**
- Create: `Epistemos/Views/Notes/Document/DocumentTextView.swift`

**Step 1: Create the TextKit 2 text view subclass**

```swift
import AppKit

// MARK: - DocumentTextView
// NSTextView subclass backed by TextKit 2 (NSTextLayoutManager).
// Continuous scroll, single container, viewport-based rendering.
// Used for rich text editing with tables, lists, inline images.

final class DocumentTextView: NSTextView {

    /// WritingTools integration — enabled by default.
    override var writingToolsBehavior: NSWritingToolsBehavior { .default }

    // MARK: - Init

    /// Create a TextKit 2-backed text view with a single container.
    static func makeTextKit2() -> (NSScrollView, DocumentTextView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let container = NSTextContainer()
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.textContainer = container

        let tv = DocumentTextView(frame: .zero, textContainer: container)
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = true
        tv.allowsUndo = true
        tv.isAutomaticSpellingCorrectionEnabled = true
        tv.isGrammarCheckingEnabled = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.textContainerInset = NSSize(width: 40, height: 40)

        // Default paragraph style
        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 4
        tv.defaultParagraphStyle = defaultParagraph
        tv.typingAttributes = [
            .font: NSFont(name: "New York", size: 15) ?? .systemFont(ofSize: 15),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: defaultParagraph
        ]

        scrollView.documentView = tv

        return (scrollView, tv)
    }

    // MARK: - Image Drag-Drop

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        // Handle image paste/drop via NSTextAttachment
        if pboard.canReadObject(forClasses: [NSImage.self]) {
            if let images = pboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
               let image = images.first {
                let attachment = NSTextAttachment()
                let cell = NSTextAttachmentCell(imageCell: image)
                attachment.attachmentCell = cell
                let attrStr = NSAttributedString(attachment: attachment)
                insertText(attrStr, replacementRange: selectedRange())
                return true
            }
        }
        return super.readSelection(from: pboard, type: type)
    }
}
```

**Step 2: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED (file compiles but isn't used yet).

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentTextView.swift
git commit -m "Add DocumentTextView — TextKit 2 NSTextView subclass with RTFD support"
```

---

## Task 8: DocumentEditorRepresentable (NSViewRepresentable)

**Files:**
- Create: `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift`

**Step 1: Create the NSViewRepresentable wrapper**

```swift
import SwiftUI
import SwiftData

// MARK: - DocumentEditorRepresentable
// NSViewRepresentable wrapping DocumentTextView (TextKit 2).
// Handles: rich text loading/saving, binding sync, RTFD persistence.

struct DocumentEditorRepresentable: NSViewRepresentable {

    let pageId: String
    let isDark: Bool
    let isEditable: Bool
    let modelContext: ModelContext

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = DocumentTextView.makeTextKit2()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        context.coordinator.textView = textView

        // Load content
        if let content = NoteFileStorage.readRichText(pageId: pageId) {
            textView.textStorage?.setAttributedString(content)
        }
        context.coordinator.currentPageId = pageId
        context.coordinator.lastPersistedHash = textView.textStorage?.string.hashValue ?? 0

        updateAppearance(textView, isDark: isDark)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Page swap
        if context.coordinator.currentPageId != pageId {
            context.coordinator.flushIfNeeded()
            context.coordinator.currentPageId = pageId
            if let content = NoteFileStorage.readRichText(pageId: pageId) {
                textView.textStorage?.setAttributedString(content)
            } else {
                textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            }
            context.coordinator.lastPersistedHash = textView.textStorage?.string.hashValue ?? 0
        }

        textView.isEditable = isEditable
        updateAppearance(textView, isDark: isDark)
    }

    private func updateAppearance(_ textView: DocumentTextView, isDark: Bool) {
        textView.backgroundColor = isDark
            ? NSColor(white: 0.12, alpha: 1)
            : .textBackgroundColor
        textView.insertionPointColor = isDark ? .white : .textColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(modelContext: modelContext)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var textView: DocumentTextView?
        var currentPageId = ""
        var lastPersistedHash = 0
        var saveTask: Task<Void, Never>?
        let modelContext: ModelContext

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }

        func textDidChange(_ notification: Notification) {
            debouncedSave()
        }

        private func debouncedSave() {
            saveTask?.cancel()
            let pageId = currentPageId
            saveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                self.persistContent(pageId: pageId)
            }
        }

        func flushIfNeeded() {
            saveTask?.cancel()
            saveTask = nil
            guard let ts = textView?.textStorage else { return }
            let currentHash = ts.string.hashValue
            guard currentHash != lastPersistedHash else { return }
            persistContent(pageId: currentPageId)
        }

        private func persistContent(pageId: String) {
            guard let ts = textView?.textStorage else { return }
            let content = NSAttributedString(attributedString: ts)
            lastPersistedHash = ts.string.hashValue

            Task.detached(priority: .utility) {
                NoteFileStorage.writeRichText(pageId: pageId, content: content)
            }

            Task { @MainActor [weak self] in
                self?.markPageDirty(pageId: pageId)
                NoteFileStorage.notifyBodyChanged(pageId: pageId)
            }
        }

        @MainActor private func markPageDirty(pageId: String) {
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            if let page = try? modelContext.fetch(desc).first {
                page.needsVaultSync = true
                try? modelContext.save()
            }
        }
    }
}
```

**Step 2: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift
git commit -m "Add DocumentEditorRepresentable — NSViewRepresentable with RTFD save pipeline"
```

---

## Task 9: Document Format Bar

**Files:**
- Create: `Epistemos/Views/Notes/Document/DocumentFormatBar.swift`

**Step 1: Create the format bar**

Build a SwiftUI toolbar strip with `.ultraThinMaterial` (matching the existing app style). The format bar reads the current selection's attributes from the text view and applies formatting changes.

Key controls:
- Bold/Italic/Underline/Strikethrough toggles
- Heading level picker (H1-H6, Body)
- Alignment (left, center, right, justified)
- List insert (bullet `NSTextList`, numbered `NSTextList`)
- Table insert (`NSTextTable`)
- Image insert (via file panel)
- Link insert (via popover)

Each action calls the standard `NSTextView` API:
- Bold: `NSFontManager.shared.addTrait(.boldFontMask, textView)`
- Italic: `NSFontManager.shared.addTrait(.italicFontMask, textView)`
- Underline: `textView.underline(nil)`
- Alignment: modify `NSMutableParagraphStyle` on selection

Table insert uses `NSTextTable` + `NSTextTableBlock` to create a native text table at the cursor position.

The bar communicates with the `DocumentTextView` via a binding or notification.

**Step 2: Build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentFormatBar.swift
git commit -m "Add DocumentFormatBar — rich text formatting toolbar"
```

---

## Task 10: Wire Document Mode into NoteWindowManager

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`
- Modify: `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift` (if needed)

**Step 1: Add showDocumentMode state**

Replace the deleted `showWriterMode` with:

```swift
@State private var showDocumentMode = false
```

**Step 2: Add Document mode branch in view body**

In the ZStack where Editor/Preview are toggled (around line 476), add:

```swift
if showDocumentMode {
    VStack(spacing: 0) {
        DocumentFormatBar(textView: /* binding or ref */)
        DocumentEditorRepresentable(
            pageId: pageId,
            isDark: ui.theme.isDark,
            isEditable: !(pages.first?.isLocked ?? false),
            modelContext: modelContext
        )
    }
    .frame(minWidth: 400, minHeight: 300)
} else if showPreview {
    // ... existing preview
} else {
    // ... existing prose editor
}
```

**Step 3: Add Cmd+R shortcut for Document mode**

```swift
Button("") { toggleDocumentMode() }
    .keyboardShortcut("r", modifiers: .command)
    .hidden()
```

```swift
private func toggleDocumentMode() {
    guard !isTransitioning else { return }
    guard !showPreview else { return }
    flushCurrentEditor()
    performGreetingTransition {
        invalidateEditorCache()
        showDocumentMode.toggle()
    }
}
```

**Step 4: Add context menu button**

```swift
Button {
    toggleDocumentMode()
} label: {
    Label(
        showDocumentMode ? "Editor (⌘R)" : "Document Mode (⌘R)",
        systemImage: showDocumentMode ? "pencil" : "doc.richtext")
}
```

**Step 5: Guard preview mode**

In `togglePreviewMode()`, add `guard !showDocumentMode else { return }`.

**Step 6: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 7: Commit**

```bash
git add Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "Wire Document mode into NoteWindowManager with Cmd+R toggle"
```

---

## Task 11: DOCX Import / Export

**Files:**
- Create: `Epistemos/Views/Notes/Document/DocumentImportExport.swift`
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift` (menu items)
- Test: `EpistemosTests/DocumentModeTests.swift` (extend)

**Step 1: Write failing tests**

Add to `EpistemosTests/DocumentModeTests.swift`:

```swift
@Suite("Document Mode - DOCX")
struct DocumentModeDOCXTests {

    @Test("DOCX export produces valid data")
    func docxExport() throws {
        let content = NSAttributedString(string: "Test document for DOCX export", attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ])
        let range = NSRange(location: 0, length: content.length)
        let data = try content.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ])
        #expect(data.count > 0)
        // DOCX is a zip file — check magic bytes
        #expect(data[0] == 0x50) // 'P'
        #expect(data[1] == 0x4B) // 'K'
    }

    @Test("DOCX import reads attributed string")
    func docxImport() throws {
        // Create a DOCX in memory, then read it back
        let original = NSAttributedString(string: "Round trip test")
        let range = NSRange(location: 0, length: original.length)
        let data = try original.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ])

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-import.docx")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let imported = try NSAttributedString(url: tmpURL, options: [:], documentAttributes: nil)
        #expect(imported.string.contains("Round trip test"))
    }
}
```

**Step 2: Run tests to verify they fail (or pass — these test native APIs)**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'DOCX|PASS|FAIL'`

**Step 3: Create import/export service**

Create `Epistemos/Views/Notes/Document/DocumentImportExport.swift`:

```swift
import AppKit

enum DocumentImportExport {

    /// Import a DOCX file and return its attributed string content.
    static func importDOCX(from url: URL) throws -> NSAttributedString {
        try NSAttributedString(url: url, options: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ], documentAttributes: nil)
    }

    /// Export an attributed string to DOCX data.
    static func exportDOCX(_ content: NSAttributedString) throws -> Data {
        let range = NSRange(location: 0, length: content.length)
        return try content.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ])
    }

    /// Export an attributed string to PDF data via NSPrintOperation rendering.
    static func exportPDF(_ content: NSAttributedString, pageSize: NSSize = NSSize(width: 612, height: 792)) throws -> Data {
        let printInfo = NSPrintInfo()
        printInfo.paperSize = pageSize
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        let tv = NSTextView(frame: NSRect(origin: .zero, size: NSSize(
            width: pageSize.width - 144,
            height: pageSize.height - 144
        )))
        tv.textStorage?.setAttributedString(content)
        tv.sizeToFit()

        let data = NSMutableData()
        let printOp = NSPrintOperation(view: tv, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        // Use PDF representation
        guard let pdfData = tv.dataWithPDF(inside: tv.bounds) as NSData? else {
            throw NSError(domain: "DocumentExport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate PDF"
            ])
        }
        return pdfData as Data
    }
}
```

**Step 4: Wire import/export into NoteWindowManager menus**

Add File menu items for Import Document (.docx) and Export as Word/PDF.

**Step 5: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
Expected: All document mode tests pass.

**Step 6: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentImportExport.swift EpistemosTests/DocumentModeTests.swift
git commit -m "Add DOCX import/export + PDF export for document mode"
```

---

## Task 12: Final Integration Test + Build Verification

**Files:**
- Modify: `EpistemosTests/DocumentModeTests.swift` (integration tests)

**Step 1: Add integration tests**

```swift
@Suite("Document Mode - Integration")
struct DocumentModeIntegrationTests {

    @Test("SDPage format defaults to markdown")
    @MainActor func defaultFormat() {
        // SDPage requires ModelContainer — test the property directly
        #expect(SDPage().format == "markdown")
        #expect(!SDPage().isRichText)
    }

    @Test("SDPage richtext format detected")
    @MainActor func richTextFormat() {
        let page = SDPage()
        page.format = "richtext"
        #expect(page.isRichText)
    }
}
```

**Step 2: Run full test suite**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
Expected: All tests pass. No regressions.

**Step 3: Run Rust tests (no changes expected, but verify)**

Run: `cd graph-engine && cargo test`
Expected: All 2282 tests pass.

**Step 4: Commit**

```bash
git add EpistemosTests/DocumentModeTests.swift
git commit -m "Add integration tests for document mode format property"
```

---

## Summary

| Task | Workstream | What |
|------|------------|------|
| 1 | C | Delete Writer mode (8 files), clean NoteWindowManager |
| 2 | A | Focus mode state + paragraph dimming |
| 3 | A | Focus mode wiring + typewriter scroll |
| 4 | A | Session word target UI |
| 5 | A | Section navigator (extend TOC) |
| 6 | B | SDPage.format + NoteFileStorage RTFD |
| 7 | B | DocumentTextView (TextKit 2 subclass) |
| 8 | B | DocumentEditorRepresentable (NSViewRepresentable) |
| 9 | B | DocumentFormatBar |
| 10 | B | Wire into NoteWindowManager |
| 11 | B | DOCX import/export |
| 12 | — | Integration tests + final verification |
