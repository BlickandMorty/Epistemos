# Document Mode Gap Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire wikilinks, AI chat, data detection, and TOC into the TextKit 2 document editor so it has feature parity with the prose editor's integration points.

**Architecture:** All 4 features bolt onto the existing `DocumentEditorRepresentable.Coordinator`. Wikilinks and data detection run as debounced post-edit passes in `textDidChange`. AI chat uses the same `NoteChatState` callback pattern as `ProseEditorRepresentable`. TOC scans font sizes in attributed text (since document mode has no `#` markers).

**Tech Stack:** Swift, TextKit 2, NSTextStorage, DataDetectionService, NoteChatState, NLAnalysisService

---

### Task 1: Wikilink Detection + Click Handling

**Files:**
- Modify: `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift`
- Modify: `Epistemos/Views/Notes/Document/DocumentTextView.swift`
- Test: `EpistemosTests/DocumentModeTests.swift`

Wikilinks in document mode work two ways:
1. **Detection:** If the user types `[[Some Note]]` in rich text, detect the pattern and apply a `.link` attribute with `wikilink://` scheme. Debounced 300ms in `textDidChange`.
2. **Markdown conversion:** When a markdown note is opened in doc mode, the converter already strips `#`/`**` but does NOT preserve wikilinks. Fix `markdownToAttributedString` to convert `[[text]]` to clickable links.
3. **Click handling:** Add `textView(_:clickedOnLink:at:)` delegate method to Coordinator.

**Step 1: Write the failing test**

Add to `EpistemosTests/DocumentModeTests.swift`:

```swift
@Test("Wikilink detection applies link attribute")
func wikilinkDetection() {
    let (_, textView) = DocumentTextView.makeTextKit2()
    textView.textStorage?.setAttributedString(
        NSAttributedString(string: "See [[My Note]] for details", attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ])
    )

    DocumentEditorRepresentable.Coordinator.applyWikilinkAttributes(to: textView.textStorage!)

    // "My Note" should have a link attribute
    let linkRange = NSRange(location: 6, length: 9) // "My Note" inside [[]]
    let link = textView.textStorage?.attribute(.link, at: 7, effectiveRange: nil) as? String
    #expect(link == "wikilink://My Note")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "Wikilink detection"`
Expected: FAIL — `applyWikilinkAttributes` does not exist

**Step 3: Implement wikilink detection**

Add static method to `DocumentEditorRepresentable.Coordinator`:

```swift
/// Scan text storage for [[wikilink]] patterns and apply .link attributes.
static func applyWikilinkAttributes(to storage: NSTextStorage) {
    let text = storage.string as NSString
    let fullRange = NSRange(location: 0, length: text.length)

    // Clear old wikilink links (only those with wikilink:// scheme)
    storage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
        if let str = value as? String, str.hasPrefix("wikilink://") {
            storage.removeAttribute(.link, range: range)
        }
    }

    // Detect [[...]] patterns
    let pattern = "\\[\\[([^\\]]+)\\]\\]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    let matches = regex.matches(in: text as String, range: fullRange)

    storage.beginEditing()
    for match in matches {
        guard match.numberOfRanges >= 2 else { continue }
        let innerRange = match.range(at: 1)  // The text inside [[ ]]
        let title = text.substring(with: innerRange)
        storage.addAttribute(.link, value: "wikilink://\(title)", range: innerRange)

        // Dim the brackets
        let openRange = NSRange(location: match.range.location, length: 2)
        let closeRange = NSRange(location: NSMaxRange(innerRange), length: 2)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
    }
    storage.endEditing()
}
```

Add to Coordinator:

```swift
private var wikilinkTask: Task<Void, Never>?

private func scheduleWikilinkDetection() {
    wikilinkTask?.cancel()
    wikilinkTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(300))
        guard let self, !Task.isCancelled else { return }
        guard let ts = self.textView?.textStorage else { return }
        Self.applyWikilinkAttributes(to: ts)
    }
}
```

Call `scheduleWikilinkDetection()` at the end of `textDidChange`.

Add `onWikilinkClick` callback to `DocumentEditorRepresentable`:

```swift
var onWikilinkClick: ((String) -> Void)?
```

Add delegate method to Coordinator:

```swift
func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
    guard let urlString = link as? String else { return false }
    if urlString.hasPrefix("wikilink://") {
        let title = String(urlString.dropFirst("wikilink://".count))
        onWikilinkClick?(title)
        return true
    }
    return false
}
```

Store `onWikilinkClick` on Coordinator (set from parent in `makeNSView`/`updateNSView`).

**Step 4: Fix markdown conversion to preserve wikilinks**

In `markdownToAttributedString`, after the line cleaning that strips `**`, add wikilink conversion:

```swift
// After creating the cleaned/attributed line, scan for [[wikilinks]]
Self.applyWikilinkAttributes(to: result)
```

Actually, call it once after the full result is built, before returning.

**Step 5: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "Wikilink detection"`
Expected: PASS

**Step 6: Wire onWikilinkClick in NoteWindowManager**

In `NoteWindowManager.swift`, where `DocumentEditorRepresentable` is created, add:

```swift
DocumentEditorRepresentable(
    pageId: page.id,
    pageFormat: page.format,
    theme: ui.theme,
    isEditable: !page.isLocked,
    modelContext: modelContext,
    onWikilinkClick: { title in
        // Same navigation as prose editor wikilink click
        navigateToNote(title: title)
    },
    onTextViewCreated: { tv in
        documentTextView = tv
    }
)
```

**Step 7: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift
git add Epistemos/Views/Notes/Document/DocumentTextView.swift
git add Epistemos/Views/Notes/NoteWindowManager.swift
git add EpistemosTests/DocumentModeTests.swift
git commit -m "feat: wire wikilink detection + click handling in document mode"
```

---

### Task 2: AI Chat Integration

**Files:**
- Modify: `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift`
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`

Wire `NoteChatState` into the document editor using the same callback pattern as `ProseEditorRepresentable`.

**Step 1: Add noteChatState parameter to DocumentEditorRepresentable**

```swift
struct DocumentEditorRepresentable: NSViewRepresentable {
    let pageId: String
    let pageFormat: String
    let theme: EpistemosTheme
    let isEditable: Bool
    let modelContext: ModelContext
    var noteChatState: NoteChatState?
    var onWikilinkClick: ((String) -> Void)?
    var onTextViewCreated: ((DocumentTextView) -> Void)?
```

**Step 2: Add AI streaming properties to Coordinator**

```swift
var noteChatState: NoteChatState?
var isFlushingTokens = false
private static let aiDivider = "\n\n<!-- ai-response -->\n\n"
```

**Step 3: Add AI streaming methods to Coordinator**

These mirror `ProseEditorRepresentable.Coordinator` lines 1189-1248:

```swift
func startNoteChatStream(_ query: String) {
    guard let ts = textView?.textStorage else { return }
    isFlushingTokens = true
    ts.replaceCharacters(
        in: NSRange(location: ts.length, length: 0),
        with: Self.aiDivider
    )
    isFlushingTokens = false
    textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
}

func appendNoteChatTokens(_ delta: String) {
    guard let ts = textView?.textStorage else { return }
    isFlushingTokens = true
    ts.replaceCharacters(
        in: NSRange(location: ts.length, length: 0),
        with: delta
    )
    isFlushingTokens = false
    textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
}

func acceptNoteChatResponse() {
    guard let ts = textView?.textStorage else { return }
    let str = ts.string as NSString
    guard let swiftRange = (str as String).range(of: Self.aiDivider, options: .backwards) else { return }
    let nsRange = NSRange(swiftRange, in: str as String)
    ts.replaceCharacters(in: nsRange, with: "\n\n")
    debouncedSave()
}

func discardNoteChatResponse() {
    guard let ts = textView?.textStorage else { return }
    let str = ts.string as NSString
    guard let swiftRange = (str as String).range(of: Self.aiDivider, options: .backwards) else { return }
    let nsRange = NSRange(swiftRange, in: str as String)
    let deleteRange = NSRange(location: nsRange.location, length: ts.length - nsRange.location)
    ts.replaceCharacters(in: deleteRange, with: "")
}
```

**Step 4: Wire callbacks in updateNSView**

In `updateNSView`, after the page swap check:

```swift
// Wire NoteChatState callbacks
if let noteChat = noteChatState, context.coordinator.noteChatState !== noteChat {
    context.coordinator.noteChatState = noteChat
    context.coordinator.onWikilinkClick = onWikilinkClick
    noteChat.onStreamStart = { [weak coord = context.coordinator] query in
        coord?.startNoteChatStream(query)
    }
    noteChat.onTokenFlush = { [weak coord = context.coordinator] delta in
        coord?.appendNoteChatTokens(delta)
    }
    noteChat.onAccept = { [weak coord = context.coordinator] in
        coord?.acceptNoteChatResponse()
    }
    noteChat.onDiscard = { [weak coord = context.coordinator] in
        coord?.discardNoteChatResponse()
    }
    noteChat.noteBodyProvider = { [weak coord = context.coordinator] in
        coord?.textView?.string ?? ""
    }
}
```

**Step 5: Guard textDidChange against token flushing**

In `textDidChange`, add the same guard the prose editor has:

```swift
func textDidChange(_ notification: Notification) {
    guard !isFlushingTokens else { return }
    debouncedSave()
    scheduleWikilinkDetection()
}
```

**Step 6: Pass noteChatState from NoteWindowManager**

In `NoteWindowManager.swift`, pass the chat state to `DocumentEditorRepresentable`:

```swift
DocumentEditorRepresentable(
    pageId: page.id,
    pageFormat: page.format,
    theme: ui.theme,
    isEditable: !page.isLocked,
    modelContext: modelContext,
    noteChatState: noteChatState,
    onWikilinkClick: { title in
        navigateToNote(title: title)
    },
    onTextViewCreated: { tv in
        documentTextView = tv
    }
)
```

Verify that the chat orb/sidebar is visible in document mode. If `NoteChatSidebar` is only shown outside `showDocumentMode`, add it alongside the document editor.

**Step 7: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift
git add Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "feat: wire AI chat (NoteChatState) into document mode editor"
```

---

### Task 3: Data Detection

**Files:**
- Modify: `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift`
- Test: `EpistemosTests/DocumentModeTests.swift`

Wire `DataDetectionService` into document mode with a 1-second debounce (same as prose editor).

**Step 1: Write the failing test**

```swift
@Test("Data detection applies underline to detected items")
func dataDetection() {
    let (_, textView) = DocumentTextView.makeTextKit2()
    let text = "Call me at 555-123-4567 tomorrow"
    textView.textStorage?.setAttributedString(
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)])
    )

    let items = DataDetectionService.detect(in: text)
    DataDetectionService.styleDetectedRanges(in: textView.textStorage!, items: items, isDark: false)

    // Phone number should have the detected data attribute
    let phoneRange = (text as NSString).range(of: "555-123-4567")
    let detected = textView.textStorage?.attribute(
        DataDetectionService.detectedDataKey, at: phoneRange.location, effectiveRange: nil
    )
    #expect(detected != nil)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "Data detection"`
Expected: FAIL (or PASS if DataDetectionService.styleDetectedRanges already works — in that case, the test validates existing behavior and we just need to wire the debounce)

**Step 3: Add data detection debounce to Coordinator**

Add to Coordinator:

```swift
private var dataDetectionTask: Task<Void, Never>?

private func scheduleDataDetection() {
    dataDetectionTask?.cancel()
    dataDetectionTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(1))
        guard let self, !Task.isCancelled else { return }
        guard let ts = self.textView?.textStorage else { return }
        let text = ts.string
        let isDark = self.currentTheme?.isDark ?? false
        let items = DataDetectionService.detect(in: text)
        // Clear old detection attributes
        let fullRange = NSRange(location: 0, length: ts.length)
        ts.enumerateAttribute(DataDetectionService.detectedDataKey, in: fullRange) { val, range, _ in
            guard val != nil else { return }
            ts.removeAttribute(DataDetectionService.detectedDataKey, range: range)
            ts.removeAttribute(.underlineStyle, range: range)
            ts.removeAttribute(.underlineColor, range: range)
        }
        DataDetectionService.styleDetectedRanges(in: ts, items: items, isDark: isDark)
    }
}
```

**Step 4: Call from textDidChange**

Update `textDidChange`:

```swift
func textDidChange(_ notification: Notification) {
    guard !isFlushingTokens else { return }
    debouncedSave()
    scheduleWikilinkDetection()
    scheduleDataDetection()
}
```

Also call `scheduleDataDetection()` at the end of `loadContent` (after setting lastPersistedHash) so detection runs on page load.

**Step 5: Add click handling for detected items**

Add to `DocumentTextView`:

```swift
override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let idx = characterIndexForInsertion(at: point)
    if idx < (textStorage?.length ?? 0),
       let attrs = textStorage?.attributes(at: idx, effectiveRange: nil),
       let item = attrs[DataDetectionService.detectedDataKey] as? DataDetectionService.DetectedItem {
        DataDetectionService.handleClick(item)
        return
    }
    super.mouseDown(with: event)
}
```

**Step 6: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "Data detection"`
Expected: PASS

**Step 7: Commit**

```bash
git add Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift
git add Epistemos/Views/Notes/Document/DocumentTextView.swift
git add EpistemosTests/DocumentModeTests.swift
git commit -m "feat: wire DataDetectionService into document mode (debounced 1s)"
```

---

### Task 4: NL Entity Extraction + Rich Text TOC

**Files:**
- Modify: `Epistemos/Views/Notes/NoteTableOfContents.swift`
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`
- Test: `EpistemosTests/DocumentModeTests.swift`

**NL Entity Extraction:** Already works indirectly. `GraphBuilder.buildPageSubgraph()` reads the page body via `NoteFileStorage.readBody()`. Since document mode writes a plain-text body mirror on every save (via `markPageDirty`), and posts `NoteFileStorage.notifyBodyChanged`, the graph builder will pick up entities when it rebuilds. **No code changes needed** — verify with a test.

**Rich Text TOC:** The current `TOCParser.parse()` scans for `#` markers in markdown. Document mode has no `#` markers — headings are styled via font sizes (28pt H1, 22pt H2, 18pt H3). Add a second parser method that scans attributed text.

**Step 1: Write the TOC test**

```swift
@Test("TOC parser extracts headings from rich text by font size")
func richTextTOC() {
    let text = NSMutableAttributedString()
    let bodyFont = NSFont.systemFont(ofSize: 16)
    let h1Font = NSFont.systemFont(ofSize: 28, weight: .bold)
    let h2Font = NSFont.systemFont(ofSize: 22, weight: .semibold)

    text.append(NSAttributedString(string: "Introduction\n", attributes: [.font: h1Font]))
    text.append(NSAttributedString(string: "Some body text here.\n", attributes: [.font: bodyFont]))
    text.append(NSAttributedString(string: "Methods\n", attributes: [.font: h2Font]))
    text.append(NSAttributedString(string: "More body text.\n", attributes: [.font: bodyFont]))

    let items = TOCParser.parseRichText(text)
    #expect(items.count == 2)
    #expect(items[0].title == "Introduction")
    #expect(items[0].level == 1)
    #expect(items[1].title == "Methods")
    #expect(items[1].level == 2)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "TOC parser extracts headings from rich text"`
Expected: FAIL — `parseRichText` does not exist

**Step 3: Implement rich text TOC parser**

Add to `NoteTableOfContents.swift` inside `TOCParser`:

```swift
/// Extract headings from rich text by scanning font sizes.
/// H1: >= 26pt, H2: >= 20pt, H3: >= 17pt.
static func parseRichText(_ attributedText: NSAttributedString) -> [TOCItem] {
    var items: [TOCItem] = []
    let string = attributedText.string as NSString
    let fullRange = NSRange(location: 0, length: string.length)

    string.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, paraRange, _, _ in
        guard let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Check the font at the start of the paragraph
        guard paraRange.location < attributedText.length else { return }
        let attrs = attributedText.attributes(at: paraRange.location, effectiveRange: nil)
        guard let font = attrs[.font] as? NSFont else { return }

        let level: Int?
        if font.pointSize >= 26 { level = 1 }
        else if font.pointSize >= 20 { level = 2 }
        else if font.pointSize >= 17 { level = 3 }
        else { level = nil }

        if let level {
            let title = substring.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(TOCItem(
                level: level,
                title: title,
                charOffset: paraRange.location,
                kind: .heading
            ))
        }
    }
    return items
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "TOC parser extracts headings from rich text"`
Expected: PASS

**Step 5: Wire TOC into NoteWindowManager for document mode**

In `NoteWindowManager.swift`, the section navigator dropdown currently only shows for prose mode. Add a `documentTocItems` state and compute it when in document mode:

```swift
@State private var documentTocItems: [TOCItem] = []
```

In the document mode branch, add a debounced TOC refresh. The simplest approach: compute TOC in `DocumentEditorRepresentable.Coordinator` after each save and expose via a callback:

Add to `DocumentEditorRepresentable`:
```swift
var onTocChanged: (([TOCItem]) -> Void)?
```

In Coordinator's `persistContent`, after saving:
```swift
if let ts = textView?.textStorage {
    let tocItems = TOCParser.parseRichText(ts)
    Task { @MainActor [weak self] in
        self?.onTocChanged?(tocItems)
    }
}
```

Wire in NoteWindowManager:
```swift
onTocChanged: { items in
    documentTocItems = items
}
```

Use `documentTocItems` in the section navigator dropdown when `showDocumentMode` is true.

**Step 6: Wire scroll-to-offset for TOC clicks**

When a TOC item is clicked in document mode, scroll to the heading. Add to `DocumentTextView`:

```swift
func scrollToCharacterOffset(_ offset: Int) {
    let range = NSRange(location: offset, length: 0)
    scrollRangeToVisible(range)
    setSelectedRange(range)
}
```

**Step 7: Verify NL entities work via existing chain**

Since `markPageDirty` already writes the plain-text body mirror via `NoteFileStorage.writeBody` and posts `NoteFileStorage.notifyBodyChanged`, verify that `GraphBuilder.buildPageSubgraph()` picks up entities from document mode edits. This should work without code changes.

**Step 8: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build && xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "TOC|Data detection|Wikilink"`
Expected: BUILD SUCCEEDED, all new tests PASS

**Step 9: Commit**

```bash
git add Epistemos/Views/Notes/NoteTableOfContents.swift
git add Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift
git add Epistemos/Views/Notes/Document/DocumentTextView.swift
git add Epistemos/Views/Notes/NoteWindowManager.swift
git add EpistemosTests/DocumentModeTests.swift
git commit -m "feat: wire rich text TOC + verify NL entity extraction in document mode"
```

---

## Verification

After all 4 tasks:

```bash
# Full build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Full test suite
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust tests (should be unaffected)
cd graph-engine && cargo test
```

**Manual testing checklist:**
- [ ] Open a note in document mode, type `[[Some Note]]` → becomes a clickable link
- [ ] Click a wikilink in document mode → navigates to target note
- [ ] Open chat in document mode → AI streaming works (tokens appear, accept/discard works)
- [ ] Type a phone number in document mode → gets underlined after 1s
- [ ] Click detected phone number → opens Phone/FaceTime
- [ ] Add headings via format bar → section navigator shows them
- [ ] Click a heading in section navigator → scrolls to it
- [ ] Save in document mode → graph shows entities from the note body
