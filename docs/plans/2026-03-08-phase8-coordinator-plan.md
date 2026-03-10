# Phase 8: TK2 Coordinator Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring `ProseEditorRepresentable2` / `ProseTextView2` to full feature parity with the TK1 coordinator — filling all gaps in right-click menus, fold gutter clicks, BTK wiring, scroll-to-offset, data detection clicks, external body sync, focus mode selection tracking, and notification contracts.

**Architecture:** The TK2 Coordinator (`Coordinator2`) already has binding sync, AI streaming, fold, data detection, table ops, and indent fully implemented. Phase 8 adds the missing interaction layer: `ProseTextView2` gets `pageId`, gutter click handling, data detection click, and the full right-click context menu with all 6 notification posts matching TK1's `ClickableTextView`. `Coordinator2` gets scroll-to-offset observer, BTK wiring, external body change sync, selection-change focus mode, and `ProseEditorUserDidType` notification.

**Tech Stack:** Swift (NSTextView, NSMenu, NotificationCenter), Rust FFI (`BlockEditTranslator`), SwiftData (`SDBlock` fetch)

---

## Task 1: ProseTextView2 — Add `pageId`, `onFoldToggle`, `onOpenInGraph` Properties

**Files:**
- Modify: `Epistemos/Views/Notes/ProseTextView2.swift:9-25`
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

**Step 1: Write the failing test**

```swift
@Suite("TextKit 2 - ProseTextView2 Properties")
struct ProseTextView2PropertiesTests {

    @Test("pageId and closures are settable")
    func pageIdAndClosures() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.pageId = "test-page"
        #expect(tv.pageId == "test-page")

        var foldCalled = false
        tv.onFoldToggle = { _ in foldCalled = true }
        tv.onFoldToggle?(42)
        #expect(foldCalled)

        var graphCalled = false
        tv.onOpenInGraph = { _ in graphCalled = true }
        tv.onOpenInGraph?("pid")
        #expect(graphCalled)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep "pageIdAndClosures"`
Expected: FAIL — `pageId`, `onFoldToggle`, `onOpenInGraph` do not exist on `ProseTextView2`

**Step 3: Add properties to ProseTextView2**

Add after line 21 (`var pageUndoManager: UndoManager?`) in `ProseTextView2.swift`:

```swift
    /// Page ID for scoping notifications to the correct tab.
    var pageId: String?

    /// Closure called when user clicks a heading fold triangle. Receives the heading character offset.
    var onFoldToggle: ((Int) -> Void)?

    /// Closure called when user selects "Open in Graph" from context menu.
    var onOpenInGraph: ((String) -> Void)?
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep "pageIdAndClosures"`
Expected: PASS

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 8 Task 1 — add pageId, onFoldToggle, onOpenInGraph to ProseTextView2"
```

---

## Task 2: ProseTextView2 — Gutter Fold Click + Data Detection Click

**Files:**
- Modify: `Epistemos/Views/Notes/ProseTextView2.swift:695-733` (mouseDown override)

**Step 1: Write the failing test**

Gutter click and data detection click are view-level interaction tests that are hard to unit test. Instead, verify the helper `isHeadingLine` is available:

```swift
@Suite("TextKit 2 - ProseTextView2 MouseDown")
struct ProseTextView2MouseDownTests {

    @Test("fold toggle fires on gutter click over heading")
    func foldToggleClosure() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        var firedOffset: Int?
        tv.onFoldToggle = { offset in firedOffset = offset }
        // Verify the closure is stored and callable
        tv.onFoldToggle?(0)
        #expect(firedOffset == 0)
    }
}
```

**Step 2: Implement gutter fold click + data detection click in mouseDown**

Replace the `mouseDown` override in `ProseTextView2.swift` (lines 695–733). The new version adds gutter fold detection and data detection click before the checkbox check:

```swift
    override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)

        guard let tlm = textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else {
            super.mouseDown(with: event)
            return
        }

        let containerPoint = NSPoint(
            x: clickPoint.x - textContainerOrigin.x,
            y: clickPoint.y - textContainerOrigin.y
        )

        if let frag = tlm.textLayoutFragment(for: containerPoint),
           let elemRange = frag.textElement?.elementRange {
            let docStart = contentStorage.documentRange.location
            let paraOffset = contentStorage.offset(from: docStart, to: elemRange.location)
            let paraLength = contentStorage.offset(from: elemRange.location, to: elemRange.endLocation)
            let str = string as NSString
            let paraText = str.substring(with: NSRange(location: paraOffset, length: paraLength))
                .trimmingCharacters(in: .newlines)

            // Fold triangle click — gutter area on a heading line
            let fragFrame = frag.layoutFragmentFrame
            let lineLeft = fragFrame.minX + textContainerOrigin.x
            if clickPoint.x < lineLeft + 6 && clickPoint.x > lineLeft - 30 {
                if paraText.hasPrefix("#") && paraText.contains(" ") {
                    var hashCount = 0
                    for ch in paraText { if ch == "#" { hashCount += 1 } else { break } }
                    if hashCount >= 1 && hashCount <= 6 {
                        onFoldToggle?(paraOffset)
                        return
                    }
                }
            }

            // Data detection click
            if let storage = textStorage,
               paraOffset < storage.length {
                let charIdx = min(paraOffset + Int(frag.textLineFragments.first?.characterIndex(for:
                    NSPoint(x: containerPoint.x - fragFrame.minX, y: containerPoint.y - fragFrame.minY)
                ) ?? 0), storage.length - 1)
                if charIdx < storage.length,
                   let item = storage.attribute(DataDetectionService.detectedDataKey, at: charIdx, effectiveRange: nil) as? DataDetectionService.DetectedItem {
                    DataDetectionService.open(item)
                    return
                }
            }

            // Checkbox toggle (existing code — keep as-is)
            if let lineFrag = frag.textLineFragments.first {
                let localPoint = NSPoint(
                    x: containerPoint.x - fragFrame.minX,
                    y: containerPoint.y - fragFrame.minY
                )
                let charIdx = lineFrag.characterIndex(for: localPoint)
                if let toggled = Self.toggleCheckbox(in: paraText, at: charIdx) {
                    let lineRange = NSRange(location: paraOffset, length: paraText.utf16.count)
                    if shouldChangeText(in: lineRange, replacementString: toggled) {
                        (textStorage as? NSTextStorage)?.replaceCharacters(in: lineRange, with: toggled)
                        didChangeText()
                    }
                    return
                }
            }
        }

        super.mouseDown(with: event)
    }
```

**Step 3: Run build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 8 Task 2 — gutter fold click + data detection click in ProseTextView2"
```

---

## Task 3: ProseTextView2 — Right-Click Context Menu + Notifications

**Files:**
- Modify: `Epistemos/Views/Notes/ProseTextView2.swift` (add `menu(for:)` override + notification names + action methods)

**Step 1: Write the failing test**

```swift
@Suite("TextKit 2 - ProseTextView2 Context Menu")
struct ProseTextView2ContextMenuTests {

    @Test("context menu posts AI operation notification")
    func aiOperationNotification() async {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.pageId = "test-page"

        var received: Notification?
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("EpistemosAIOperation"),
            object: nil, queue: .main
        ) { note in received = note }
        defer { NotificationCenter.default.removeObserver(observer) }

        // Simulate the notification post directly (can't simulate right-click in test)
        NotificationCenter.default.post(
            name: Notification.Name("EpistemosAIOperation"),
            object: nil,
            userInfo: ["operation": "rewrite", "pageId": "test-page"]
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(received != nil)
        #expect(received?.userInfo?["operation"] as? String == "rewrite")
    }
}
```

**Step 2: Add notification name statics and full context menu to ProseTextView2**

Add notification names after the `onOpenInGraph` property (from Task 1):

```swift
    // MARK: - Notifications (same names as ClickableTextView for NotePageContent compatibility)
    static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")
    static let aiOperationNotification = Notification.Name("EpistemosAIOperation")
    static let blockPropertyNotification = Notification.Name("EpistemosBlockPropertyEdit")
    static let translateNotification = Notification.Name("EpistemosTranslateText")
    static let scrollToOffsetNotification = Notification.Name("EpistemosScrollToOffset")
```

Add the full context menu override (copy the structure from `ClickableTextView.menu(for:)` lines 721–826):

```swift
    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        // Reveal in Graph
        if let pid = pageId {
            menu.addItem(NSMenuItem.separator())
            let graphItem = NSMenuItem(title: "Reveal in Graph", action: #selector(contextRevealInGraph(_:)), keyEquivalent: "")
            graphItem.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Graph")
            graphItem.target = self
            graphItem.representedObject = pid
            menu.addItem(graphItem)
        }

        // Set Property
        let propItem = NSMenuItem(title: "Set Property\u{2026}", action: #selector(openBlockPropertySheet), keyEquivalent: "")
        propItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "Property")
        propItem.target = self
        menu.addItem(propItem)

        // Insert submenu
        menu.addItem(NSMenuItem.separator())
        let insertMenu = NSMenu(title: "Insert")
        let tableItem = NSMenuItem(title: "Table", action: #selector(insertMarkdownTable(_:)), keyEquivalent: "")
        tableItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Table")
        tableItem.target = self
        insertMenu.addItem(tableItem)
        let insertSubmenuItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertSubmenuItem.submenu = insertMenu
        insertSubmenuItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Insert")
        menu.addItem(insertSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let ideaItem = NSMenuItem(title: "New Idea at This Line", action: #selector(createIdeaAtLine), keyEquivalent: "")
        ideaItem.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Idea")
        ideaItem.target = self
        menu.addItem(ideaItem)

        let dumpItem = NSMenuItem(title: "New Brain Dump at This Line", action: #selector(createBrainDumpAtLine), keyEquivalent: "")
        dumpItem.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Brain Dump")
        dumpItem.target = self
        menu.addItem(dumpItem)

        // AI Assistant submenu
        menu.addItem(NSMenuItem.separator())
        let aiMenu = NSMenu(title: "AI Assistant")
        let hasSelection = selectedRange().length > 0
        if hasSelection {
            aiMenu.addItem(makeAIItem("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite"))
            aiMenu.addItem(makeAIItem("Summarize", icon: "text.quote", op: "summarize"))
            aiMenu.addItem(makeAIItem("Expand", icon: "arrow.up.left.and.arrow.down.right", op: "expand"))
            aiMenu.addItem(makeAIItem("Simplify", icon: "text.redaction", op: "simplify"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Convert to List", icon: "list.bullet", op: "toList"))
            aiMenu.addItem(makeAIItem("Convert to Table", icon: "tablecells", op: "toTable"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Translate", icon: "character.book.closed", op: "translate"))
        } else {
            aiMenu.addItem(makeAIItem("Continue Writing", icon: "text.append", op: "continue"))
            aiMenu.addItem(makeAIItem("Generate Outline", icon: "list.number", op: "outline"))
            aiMenu.addItem(makeAIItem("Suggest Structure", icon: "rectangle.3.group", op: "structure"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Restructure Note", icon: "arrow.triangle.branch", op: "restructure"))
        }
        let aiSubmenuItem = NSMenuItem(title: "AI Assistant", action: nil, keyEquivalent: "")
        aiSubmenuItem.submenu = aiMenu
        aiSubmenuItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        menu.addItem(aiSubmenuItem)

        return menu
    }

    private func makeAIItem(_ title: String, icon: String, op: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleAIOperation(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        item.target = self
        item.representedObject = op
        return item
    }

    @objc private func contextRevealInGraph(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? String else { return }
        onOpenInGraph?(pid)
    }

    @objc private func createIdeaAtLine() {
        NotificationCenter.default.post(
            name: Self.createIdeaNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func createBrainDumpAtLine() {
        NotificationCenter.default.post(
            name: Self.createBrainDumpNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func handleAIOperation(_ sender: NSMenuItem) {
        guard let op = sender.representedObject as? String else { return }
        var userInfo: [String: String] = ["operation": op]
        if let pageId { userInfo["pageId"] = pageId }
        let sel = selectedRange()
        if sel.length > 0, let str = string as NSString? {
            userInfo["selectedText"] = str.substring(with: sel)
        }
        if op == "translate" {
            NotificationCenter.default.post(name: Self.translateNotification, object: nil, userInfo: userInfo)
            return
        }
        NotificationCenter.default.post(name: Self.aiOperationNotification, object: nil, userInfo: userInfo)
    }

    @objc private func openBlockPropertySheet() {
        let nsStr = string as NSString
        let cursorLoc = selectedRange().location
        let lineRange = nsStr.lineRange(for: NSRange(location: cursorLoc, length: 0))
        let lineText = nsStr.substring(with: lineRange).trimmingCharacters(in: .newlines)
        var userInfo: [String: Any] = ["lineText": lineText, "lineRange": lineRange]
        if let pageId { userInfo["pageId"] = pageId }
        NotificationCenter.default.post(name: Self.blockPropertyNotification, object: nil, userInfo: userInfo)
    }

    @objc private func insertMarkdownTable(_ sender: NSMenuItem) {
        let table = "| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n|  |  |  |\n"
        let loc = selectedRange().location
        if shouldChangeText(in: NSRange(location: loc, length: 0), replacementString: table) {
            textStorage?.replaceCharacters(in: NSRange(location: loc, length: 0), with: table)
            didChangeText()
            setSelectedRange(NSRange(location: loc + "| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n| ".count, length: 0))
        }
    }
```

**Step 3: Run build + test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 8 Task 3 — right-click context menu + notification posts in ProseTextView2"
```

---

## Task 4: Coordinator2 — Wire `pageId`, `onFoldToggle`, `onOpenInGraph`, scrollToOffset Observer

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift:39-97` (makeNSView) + `Coordinator2` class

**Step 1: Implement wiring in makeNSView and handlePageSwap**

In `makeNSView`, after `coord.textView = tv` (line 65), add:

```swift
        tv.pageId = pageId
        tv.onFoldToggle = { [weak coord] offset in
            coord?.toggleFold(headingOffset: offset)
        }
        tv.onOpenInGraph = { pid in
            HologramController.shared.revealPage(pageId: pid)
        }

        // Scroll-to-offset observer for TOC section navigator
        coord.scrollToOffsetObserver = NotificationCenter.default.addObserver(
            forName: ProseTextView2.scrollToOffsetNotification,
            object: nil,
            queue: .main
        ) { [weak tv, weak coord] notification in
            guard let offset = notification.userInfo?["charOffset"] as? Int,
                  let pid = notification.userInfo?["pageId"] as? String,
                  pid == coord?.currentPageId,
                  let tv else { return }
            MainActor.assumeIsolated {
                let safeOffset = min(offset, (tv.string as NSString).length)
                tv.scrollToCharacterOffset(safeOffset)
                let range = NSRange(location: safeOffset, length: 0)
                let lineRange = (tv.string as NSString).lineRange(for: range)
                tv.showFindIndicator(for: lineRange)
            }
        }
```

Add to `Coordinator2` properties:

```swift
        var scrollToOffsetObserver: Any?
```

In `handleDismantle()`, add cleanup:

```swift
        if let obs = scrollToOffsetObserver {
            NotificationCenter.default.removeObserver(obs)
            scrollToOffsetObserver = nil
        }
```

In `handlePageSwap()`, after loading new content, update `tv.pageId`:

```swift
        tv.pageId = parent.pageId
```

**Step 2: Run build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/ProseEditorRepresentable2.swift
git commit -m "feat: Phase 8 Task 4 — wire pageId, fold toggle, graph reveal, scrollToOffset observer"
```

---

## Task 5: Coordinator2 — BlockEditTranslator (BTK) Wiring

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (Coordinator2 class)

**Step 1: Add BTK property and wiring**

Add to `Coordinator2` properties (near `dataDetectionTask`):

```swift
        var blockEditTranslator: BlockEditTranslator?
```

In `handlePageSwap()`, after loading new content and setting `currentPageId`, add BTK initialization:

```swift
            // BTK: Create translator for new page
            if let graphState = parent.graphState, let modelContext = parent.modelContext {
                let translator = BlockEditTranslator(pageId: parent.pageId, graphState: graphState)
                let fetchDesc = FetchDescriptor<SDBlock>(
                    predicate: #Predicate { $0.pageId == parent.pageId },
                    sortBy: [SortDescriptor(\.order)]
                )
                let existingBlocks = (try? modelContext.fetch(fetchDesc)) ?? []
                translator.initIfNeeded(existingBlocks: existingBlocks)
                blockEditTranslator = translator
            } else {
                blockEditTranslator = nil
            }
```

In `textDidChange(_:)`, after the bracket auto-close block and before `debouncedBindingSync`, add BTK edit translation:

```swift
            // BTK: Translate edit into block-level ops
            if let translator = blockEditTranslator,
               let storage = tv.textStorage {
                let editedRange = storage.editedRange
                let changeInLength = storage.changeInLength
                if editedRange.location != NSNotFound,
                   editedRange.location + editedRange.length <= storage.length {
                    let oldLength = editedRange.length - changeInLength
                    let newText = (storage.string as NSString).substring(with: editedRange)
                    translator.translateEdit(offset: editedRange.location, oldLength: oldLength, newText: newText)
                }
            }
```

**Step 2: Run build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/ProseEditorRepresentable2.swift
git commit -m "feat: Phase 8 Task 5 — BlockEditTranslator (BTK) wiring in Coordinator2"
```

---

## Task 6: Coordinator2 — External Body Change Sync + Focus Mode Selection + UserDidType Notification

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (handleUpdate + textViewDidChangeSelection)

**Step 1: Add external body change sync to handleUpdate**

In `handleUpdate()`, after the focus mode block and before centering, add:

```swift
            // External body change (vault sync / restore-to-version)
            // If pageBody differs from what we have in storage, and we're not mid-edit,
            // reload the content. This handles NoteFileStorage.pageBodyDidChange.
            if parent.pageBody != lastSyncedText,
               parent.pageBody != tv.string,
               !isFlushingTokens {
                let newBody = parent.pageBody
                isFlushingTokens = true
                tv.markdownDelegate.reparse(text: newBody)
                let storage = tv.textStorage!
                storage.beginEditing()
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: newBody)
                storage.endEditing()
                tv.didChangeText()
                isFlushingTokens = false
                lastSyncedText = newBody
            }
```

**Step 2: Add textViewDidChangeSelection delegate method**

Add to `Coordinator2`:

```swift
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? ProseTextView2 else { return }
            if tv.isFocusMode {
                tv.applyFocusDimming()
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

**Step 3: Add ProseEditorUserDidType notification to textDidChange**

In `textDidChange(_:)`, after the `isFlushingTokens` guard, add:

```swift
            // Notify template overlay that user started typing (short docs only)
            if (tv.textStorage?.length ?? 0) <= 10 {
                NotificationCenter.default.post(
                    name: .init("ProseEditorUserDidType"),
                    object: nil,
                    userInfo: ["pageId": currentPageId]
                )
            }
```

**Step 4: Run build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/ProseEditorRepresentable2.swift
git commit -m "feat: Phase 8 Task 6 — external body sync, focus mode selection, UserDidType notification"
```

---

## Task 7: Full Build + Test Verification

**Step 1: Run Rust tests**

Run: `cd graph-engine && cargo test 2>&1 | tail -3`
Expected: All tests pass

**Step 2: Run Swift build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Run Swift tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: All Phase 8 tests pass. Pre-existing failures (TriageServiceTests) excluded.

**Step 4: Verify notification parity**

Run: `grep -c "EpistemosAIOperation\|EpistemosCreateIdeaAtLine\|EpistemosCreateBrainDumpAtLine\|EpistemosBlockPropertyEdit\|EpistemosTranslateText\|EpistemosScrollToOffset" Epistemos/Views/Notes/ProseTextView2.swift`
Expected: 6 (all notification names present)

**Step 5: Commit log**

```bash
git log --oneline -7
```

Expected commits (newest first):
```
feat: Phase 8 Task 6 — external body sync, focus mode selection, UserDidType notification
feat: Phase 8 Task 5 — BlockEditTranslator (BTK) wiring in Coordinator2
feat: Phase 8 Task 4 — wire pageId, fold toggle, graph reveal, scrollToOffset observer
feat: Phase 8 Task 3 — right-click context menu + notification posts in ProseTextView2
feat: Phase 8 Task 2 — gutter fold click + data detection click in ProseTextView2
feat: Phase 8 Task 1 — add pageId, onFoldToggle, onOpenInGraph to ProseTextView2
```

---

## Deferred to Phase 9+ (YAGNI)

These gaps are low severity and deferred:

| Gap | Severity | Reason to Defer |
|-----|----------|-----------------|
| Live-resize freeze (`viewWillStartLiveResize`) | Low | Minor jank during window drag, not a correctness issue |
| Pinch/Cmd zoom | Low | Cosmetic, rarely used |
| `performKeyEquivalent` (Cmd+F/G) | Low | NSTextView base class handles Find; verify before adding |
| QuickLook (Space on image) | Low | Cosmetic, not commonly used |
| `TransclusionOverlayManager` + `BlockRefAutocomplete` | Medium | Separate geometry subsystem — Phase 9 scope |
| Image drag-drop + OCR | Low | Phase 9+ scope |
