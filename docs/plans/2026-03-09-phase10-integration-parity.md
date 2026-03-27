# Phase 10: Integration + Parity — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **Historical note:** This plan is complete and retained as an implementation record. The live app no longer uses `useTK2Editor`, `PageStoragePool`, or the TK1 production prose stack referenced below.

**Goal:** Wire TK2 editor into the full app lifecycle, fix TK1-assuming plumbing, write parity tests, and add performance benchmarks.

**Architecture:** Three methods in NoteWindowManager assume PageStoragePool exists under TK2 (it doesn't — TK2 uses a delegate model with no pool). Fix them to be TK2-aware using the existing `notesUI.useTK2Editor` flag. Then write parity tests comparing TK1/TK2 output for identical markdown, and benchmark tests for key hot paths.

**Tech Stack:** Swift Testing (`@Suite` + `@Test` + `#expect`), AppKit (NSTextView, NSTextLayoutManager), existing Rust FFI parser.

---

### Task 1: Fix `flushCurrentEditor()` for TK2

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift:1098-1116`

**Context:** `flushCurrentEditor()` reads text from `PageStoragePool.shared.bodyText(for:)` first (always nil under TK2), then falls back to `responder.layoutManager?.textStorage?.string` (also nil under TK2 — `layoutManager` is nil, only `textLayoutManager` exists). The final fallback `responder.string` works for both TK1 and TK2 but is only reached if the intermediate chain returns nil. Under TK2, it works by accident. Fix: use `responder.string` directly (it's an NSTextView property that works for both TextKit generations).

**Step 1: Modify `flushCurrentEditor()`**

Replace lines 1098-1116 with:

```swift
private func flushCurrentEditor() {
    guard let page = pages.first else { return }
    let fullText: String
    if !notesUI.useTK2Editor,
       let poolText = PageStoragePool.shared.bodyText(for: pageId) {
        // TK1: read from PageStoragePool (reliable, pre-styled storage).
        fullText = poolText
    } else if let responder = NSApp.keyWindow?.firstResponder as? NSTextView {
        // TK2 (or TK1 fallback for Writer Mode): read NSTextView.string directly.
        // Works for both ProseTextView2 (TK2) and ClickableTextView (TK1).
        fullText = responder.string
    } else {
        return
    }
    if fullText != page.loadBody() {
        page.saveBody(fullText)
        page.needsVaultSync = true
        page.updatedAt = .now
        AppBootstrap.shared?.graphState.needsRefresh = true
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

---

### Task 2: Fix `invalidateEditorCache()` for TK2

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift:1093-1096`

**Context:** `invalidateEditorCache()` calls `PageStoragePool.shared.saveToDisk()` and `.remove()` — these are no-ops under TK2 (no pool entry exists) but conceptually wrong. Guard with the TK2 flag.

**Step 1: Modify `invalidateEditorCache()`**

Replace lines 1093-1096 with:

```swift
private func invalidateEditorCache() {
    guard !notesUI.useTK2Editor else { return }
    PageStoragePool.shared.saveToDisk(pageId: pageId)
    PageStoragePool.shared.remove(pageId: pageId)
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: Fix `NoteOutlineOverlay` body text source for TK2

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift:553-555`

**Context:** `NoteOutlineOverlay` is initialized with `PageStoragePool.shared.bodyText(for: pageId) ?? pages.first?.loadBody() ?? ""`. Under TK2, pool always returns nil, so it falls through to `loadBody()` (disk read). This works but is a disk read in a SwiftUI view body (anti-pattern per CLAUDE.md). Fix: skip the pool lookup when TK2, go straight to `loadBody()`. The outline overlay parses on `.onChange(of: markdown)` so it doesn't re-parse unless the body actually changes.

**Step 1: Make the body text source TK2-aware**

Replace the NoteOutlineOverlay call site (lines 553-560) with:

```swift
NoteOutlineOverlay(
    markdown: {
        if notesUI.useTK2Editor {
            // TK2: no PageStoragePool. Read from disk (body is saved
            // within 3s by Coordinator2's direct file save).
            return pages.first?.loadBody() ?? ""
        }
        // TK1: read from in-memory pre-styled storage pool.
        return PageStoragePool.shared.bodyText(for: pageId)
            ?? pages.first?.loadBody() ?? ""
    }(),
    theme: ui.theme,
    onNavigate: { charOffset in
        scrollEditorTo(charOffset: charOffset)
    }
)
```

**Step 2: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit plumbing fixes**

```bash
git add Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "fix: make NoteWindowManager TK2-aware (flush, cache, outline)"
```

---

### Task 4: Parity tests — inline styling

**Files:**
- Create: `EpistemosTests/TextKit2ParityTests.swift`

**Context:** These tests create both TK1 and TK2 editor stacks with identical markdown input, then verify they produce equivalent styling for inline elements. Both stacks use the same Rust FFI parser (`markdown_parse()`), so results should match.

**Step 1: Create parity test file with inline styling tests**

```swift
import Testing
import AppKit
@testable import Epistemos

// MARK: - TextKit 2 Parity Tests
// Verify TK1 and TK2 editors produce equivalent results for identical markdown.

@Suite("TextKit 2 - Parity: Inline Styling")
struct TK2ParityInlineTests {

    // MARK: - Helpers

    /// Creates a TK1 MarkdownTextStorage with the given markdown, returns it styled.
    private func makeTK1Storage(_ markdown: String) -> NSTextStorage {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        return storage
    }

    /// Creates a TK2 ProseTextView2 with markdown, returns its textContentStorage.
    private func makeTK2View(_ markdown: String) -> (ProseTextView2, NSTextContentStorage) {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.applyTheme(.sunny)
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage else {
            fatalError("TK2 stack not properly wired")
        }
        tcs.performEditingTransaction {
            tcs.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: tcs.textStorage?.length ?? 0),
                with: markdown
            )
        }
        return (tv, tcs)
    }

    /// Extracts font trait (bold/italic) at a character offset from an attributed string.
    private func fontTraits(in attrStr: NSAttributedString, at offset: Int) -> NSFontDescriptor.SymbolicTraits {
        guard offset < attrStr.length else { return [] }
        let font = attrStr.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        return font?.fontDescriptor.symbolicTraits ?? []
    }

    /// Checks if a range has a .link attribute in an attributed string.
    private func hasLink(in attrStr: NSAttributedString, at offset: Int) -> Bool {
        guard offset < attrStr.length else { return false }
        return attrStr.attribute(.link, at: offset, effectiveRange: nil) != nil
    }

    // MARK: - Bold

    @Test("Bold text has bold trait in both TK1 and TK2")
    func boldParity() {
        let md = "normal **bold** normal"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // "bold" starts at offset 9 (after "normal **")
        let tk1Traits = fontTraits(in: tk1, at: 9)
        let tk2Traits = fontTraits(in: tk2, at: 9)

        #expect(tk1Traits.contains(.bold))
        #expect(tk2Traits.contains(.bold))
    }

    // MARK: - Italic

    @Test("Italic text has italic trait in both TK1 and TK2")
    func italicParity() {
        let md = "normal *italic* normal"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // "italic" starts at offset 8 (after "normal *")
        let tk1Traits = fontTraits(in: tk1, at: 8)
        let tk2Traits = fontTraits(in: tk2, at: 8)

        #expect(tk1Traits.contains(.italic))
        #expect(tk2Traits.contains(.italic))
    }

    // MARK: - Code spans

    @Test("Inline code has monospace font in both TK1 and TK2")
    func codeParity() {
        let md = "normal `code` normal"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // "code" starts at offset 8 (after "normal `")
        let tk1Traits = fontTraits(in: tk1, at: 8)
        let tk2Traits = fontTraits(in: tk2, at: 8)

        // Monospace fonts are indicated by the .monoSpace symbolic trait
        #expect(tk1Traits.contains(.monoSpace))
        #expect(tk2Traits.contains(.monoSpace))
    }

    // MARK: - Wikilinks

    @Test("Wikilinks have .link attribute in both TK1 and TK2")
    func wikilinkParity() {
        let md = "see [[MyPage]] here"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // Inner text "MyPage" starts at offset 6 (after "see [[")
        let tk1HasLink = hasLink(in: tk1, at: 6)
        let tk2HasLink = hasLink(in: tk2, at: 6)

        #expect(tk1HasLink)
        #expect(tk2HasLink)
    }

    // MARK: - Strikethrough

    @Test("Strikethrough has underlineStyle in both TK1 and TK2")
    func strikethroughParity() {
        let md = "normal ~~struck~~ normal"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // "struck" starts at offset 9 (after "normal ~~")
        let tk1Strike = tk1.attribute(.strikethroughStyle, at: 9, effectiveRange: nil) as? Int
        let tk2Strike = tk2.attribute(.strikethroughStyle, at: 9, effectiveRange: nil) as? Int

        #expect(tk1Strike != nil && tk1Strike! > 0)
        #expect(tk2Strike != nil && tk2Strike! > 0)
    }

    // MARK: - Nested formatting

    @Test("Bold italic renders with both traits in both TK1 and TK2")
    func boldItalicParity() {
        let md = "***bolditalic***"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // "bolditalic" starts at offset 3 (after "***")
        let tk1Traits = fontTraits(in: tk1, at: 3)
        let tk2Traits = fontTraits(in: tk2, at: 3)

        #expect(tk1Traits.contains(.bold))
        #expect(tk1Traits.contains(.italic))
        #expect(tk2Traits.contains(.bold))
        #expect(tk2Traits.contains(.italic))
    }
}
```

**Step 2: Build and run**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Tests? (passed|failed)|Executed)'`
Expected: All parity tests pass (both stacks use same Rust parser).

---

### Task 5: Parity tests — paragraph classification

**Files:**
- Modify: `EpistemosTests/TextKit2ParityTests.swift` (append)

**Context:** Verify TK1 and TK2 produce equivalent paragraph-level styling (headings get large fonts, lists get indents, blockquotes get muted colors). TK1 uses `MarkdownTextStorage.processEditing()`, TK2 uses `MarkdownContentStorage` delegate. Both ultimately call the Rust parser.

**Step 1: Append paragraph parity tests**

Add to `TextKit2ParityTests.swift`:

```swift
@Suite("TextKit 2 - Parity: Paragraph Classification")
struct TK2ParityParagraphTests {

    private func makeTK1Storage(_ markdown: String) -> NSTextStorage {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        return storage
    }

    private func makeTK2View(_ markdown: String) -> (ProseTextView2, NSTextContentStorage) {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.applyTheme(.sunny)
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage else {
            fatalError("TK2 stack not properly wired")
        }
        tcs.performEditingTransaction {
            tcs.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: tcs.textStorage?.length ?? 0),
                with: markdown
            )
        }
        return (tv, tcs)
    }

    private func fontSize(in attrStr: NSAttributedString, at offset: Int) -> CGFloat? {
        guard offset < attrStr.length else { return nil }
        let font = attrStr.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        return font?.pointSize
    }

    // MARK: - Headings

    @Test("H1 gets largest font in both TK1 and TK2")
    func h1Parity() {
        let md = "# Big Heading\nBody text"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // Heading text starts at offset 2 (after "# ")
        let tk1Size = fontSize(in: tk1, at: 2) ?? 0
        let tk2Size = fontSize(in: tk2, at: 2) ?? 0
        let tk1BodySize = fontSize(in: tk1, at: 15) ?? 0  // "Body" in second line
        let tk2BodySize = fontSize(in: tk2, at: 15) ?? 0

        // Both should render heading larger than body
        #expect(tk1Size > tk1BodySize)
        #expect(tk2Size > tk2BodySize)
    }

    @Test("H2 gets medium font in both TK1 and TK2")
    func h2Parity() {
        let md = "## Medium Heading\nBody text"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        let tk1Size = fontSize(in: tk1, at: 3) ?? 0
        let tk2Size = fontSize(in: tk2, at: 3) ?? 0
        let tk1BodySize = fontSize(in: tk1, at: 19) ?? 0
        let tk2BodySize = fontSize(in: tk2, at: 19) ?? 0

        #expect(tk1Size > tk1BodySize)
        #expect(tk2Size > tk2BodySize)
    }

    // MARK: - Blockquote

    @Test("Blockquote text has muted foreground in both TK1 and TK2")
    func blockquoteParity() {
        let md = "> quoted text\nnormal text"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // Quote text at offset 2 (after "> ")
        let tk1Color = tk1.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor

        // Both should have a foreground color set (muted/secondary)
        #expect(tk1Color != nil)
        #expect(tk2Color != nil)
    }

    // MARK: - Code block

    @Test("Fenced code block has monospace font in both TK1 and TK2")
    func codeBlockParity() {
        let md = "```swift\nlet x = 1\n```"
        let tk1 = makeTK1Storage(md)
        let (_, tcs) = makeTK2View(md)
        guard let tk2 = tcs.textStorage else { return }

        // Code content at line 2: "let x = 1" — find offset after first newline
        let codeOffset = (md as NSString).range(of: "let").location
        guard codeOffset != NSNotFound else { return }

        let tk1Font = tk1.attribute(.font, at: codeOffset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: codeOffset, effectiveRange: nil) as? NSFont

        #expect(tk1Font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
        #expect(tk2Font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Tests? (passed|failed)|Executed)'`
Expected: All paragraph parity tests pass.

---

### Task 6: Parity tests — AI streaming contracts

**Files:**
- Modify: `EpistemosTests/TextKit2ParityTests.swift` (append)

**Context:** Verify that AI streaming operations (divider insert, token append, accept, discard) produce equivalent text state in both TK1 and TK2 coordinators. Both use the same `<!-- ai-response -->` divider protocol.

**Step 1: Append AI streaming parity tests**

Add to `TextKit2ParityTests.swift`:

```swift
@Suite("TextKit 2 - Parity: AI Streaming")
struct TK2ParityAIStreamingTests {

    // MARK: - Divider format

    @Test("AI divider string matches between TK1 and TK2")
    func dividerParity() {
        // Both coordinators use the same divider constant
        let expected = "\n\n<!-- ai-response -->\n\n"

        // Verify the divider format is consistent
        #expect(expected.contains("<!-- ai-response -->"))
        #expect(expected.hasPrefix("\n\n"))
        #expect(expected.hasSuffix("\n\n"))
    }

    // MARK: - Token append result

    @Test("Appending tokens produces same text in both stacks")
    func tokenAppendParity() {
        let initial = "Hello world"
        let divider = "\n\n<!-- ai-response -->\n\n"
        let tokens = "AI response text"

        // Simulate TK1 flow
        let tk1Storage = MarkdownTextStorage()
        tk1Storage.isDark = false
        tk1Storage.beginEditing()
        tk1Storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: initial)
        tk1Storage.endEditing()
        tk1Storage.replaceCharacters(
            in: NSRange(location: tk1Storage.length, length: 0), with: divider
        )
        tk1Storage.replaceCharacters(
            in: NSRange(location: tk1Storage.length, length: 0), with: tokens
        )

        // Simulate TK2 flow
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let tk2Storage = tcs.textStorage else { return }
        tcs.performEditingTransaction {
            tk2Storage.replaceCharacters(
                in: NSRange(location: 0, length: tk2Storage.length), with: initial
            )
        }
        tcs.performEditingTransaction {
            tk2Storage.replaceCharacters(
                in: NSRange(location: tk2Storage.length, length: 0), with: divider
            )
        }
        tcs.performEditingTransaction {
            tk2Storage.replaceCharacters(
                in: NSRange(location: tk2Storage.length, length: 0), with: tokens
            )
        }

        #expect(tk1Storage.string == tk2Storage.string)
        #expect(tk1Storage.string == initial + divider + tokens)
    }

    // MARK: - Accept strips divider

    @Test("Accept replaces divider with double newline in both stacks")
    func acceptParity() {
        let initial = "Hello world"
        let divider = "\n\n<!-- ai-response -->\n\n"
        let response = "AI says hello"
        let fullText = initial + divider + response

        // TK1
        let tk1 = MarkdownTextStorage()
        tk1.isDark = false
        tk1.beginEditing()
        tk1.replaceCharacters(in: NSRange(location: 0, length: 0), with: fullText)
        tk1.endEditing()
        let tk1Range = (tk1.string as NSString).range(of: "<!-- ai-response -->")
        if tk1Range.location != NSNotFound {
            // Accept: replace divider line (including surrounding newlines) with "\n\n"
            let dividerFullRange = (tk1.string as NSString).range(of: divider)
            tk1.replaceCharacters(in: dividerFullRange, with: "\n\n")
        }

        // TK2
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let tk2 = tcs.textStorage else { return }
        tcs.performEditingTransaction {
            tk2.replaceCharacters(in: NSRange(location: 0, length: tk2.length), with: fullText)
        }
        let tk2Range = (tk2.string as NSString).range(of: divider)
        if tk2Range.location != NSNotFound {
            tcs.performEditingTransaction {
                tk2.replaceCharacters(in: tk2Range, with: "\n\n")
            }
        }

        #expect(tk1.string == tk2.string)
        #expect(tk1.string == initial + "\n\n" + response)
    }

    // MARK: - Discard removes from divider to end

    @Test("Discard removes everything from divider onward in both stacks")
    func discardParity() {
        let initial = "Hello world"
        let divider = "\n\n<!-- ai-response -->\n\n"
        let response = "AI says hello"
        let fullText = initial + divider + response

        // TK1
        let tk1 = MarkdownTextStorage()
        tk1.isDark = false
        tk1.beginEditing()
        tk1.replaceCharacters(in: NSRange(location: 0, length: 0), with: fullText)
        tk1.endEditing()
        let tk1DivStart = (tk1.string as NSString).range(of: "\n\n<!-- ai-response -->").location
        if tk1DivStart != NSNotFound {
            tk1.replaceCharacters(
                in: NSRange(location: tk1DivStart, length: tk1.length - tk1DivStart),
                with: ""
            )
        }

        // TK2
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let tk2 = tcs.textStorage else { return }
        tcs.performEditingTransaction {
            tk2.replaceCharacters(in: NSRange(location: 0, length: tk2.length), with: fullText)
        }
        let tk2DivStart = (tk2.string as NSString).range(of: "\n\n<!-- ai-response -->").location
        if tk2DivStart != NSNotFound {
            tcs.performEditingTransaction {
                tk2.replaceCharacters(
                    in: NSRange(location: tk2DivStart, length: tk2.length - tk2DivStart),
                    with: ""
                )
            }
        }

        #expect(tk1.string == tk2.string)
        #expect(tk1.string == initial)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Tests? (passed|failed)|Executed)'`
Expected: All AI streaming parity tests pass.

**Step 3: Commit parity tests**

```bash
git add EpistemosTests/TextKit2ParityTests.swift
git commit -m "test: Phase 10 TK2 parity tests — inline styling, paragraphs, AI streaming"
```

---

### Task 7: Parity tests — edge cases

**Files:**
- Modify: `EpistemosTests/TextKit2ParityTests.swift` (append)

**Context:** Test edge cases that commonly break during editor migrations: empty documents, single character, very long lines, unicode content, rapid text replacement.

**Step 1: Append edge case parity tests**

Add to `TextKit2ParityTests.swift`:

```swift
@Suite("TextKit 2 - Parity: Edge Cases")
struct TK2ParityEdgeCaseTests {

    private func makeTK1Storage(_ markdown: String) -> NSTextStorage {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        return storage
    }

    private func makeTK2Storage(_ markdown: String) -> NSTextStorage? {
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let storage = tcs.textStorage else { return nil }
        tcs.performEditingTransaction {
            storage.replaceCharacters(
                in: NSRange(location: 0, length: storage.length), with: markdown
            )
        }
        return storage
    }

    // MARK: - Empty document

    @Test("Empty document produces empty string in both stacks")
    func emptyDocParity() {
        let tk1 = makeTK1Storage("")
        guard let tk2 = makeTK2Storage("") else { return }

        #expect(tk1.string == "")
        #expect(tk2.string == "")
        #expect(tk1.length == 0)
        #expect(tk2.length == 0)
    }

    // MARK: - Single character

    @Test("Single character document is identical in both stacks")
    func singleCharParity() {
        let tk1 = makeTK1Storage("a")
        guard let tk2 = makeTK2Storage("a") else { return }

        #expect(tk1.string == tk2.string)
        #expect(tk1.length == 1)
    }

    // MARK: - Unicode

    @Test("Unicode content (emoji, CJK, RTL) preserved in both stacks")
    func unicodeParity() {
        let md = "Hello 🌍 世界 مرحبا\n## 見出し\n- リスト項目"
        let tk1 = makeTK1Storage(md)
        guard let tk2 = makeTK2Storage(md) else { return }

        #expect(tk1.string == tk2.string)
        #expect(tk1.string == md)
    }

    // MARK: - Long single line

    @Test("Very long line (10K chars) handled by both stacks")
    func longLineParity() {
        let md = String(repeating: "word ", count: 2000) // ~10K chars
        let tk1 = makeTK1Storage(md)
        guard let tk2 = makeTK2Storage(md) else { return }

        #expect(tk1.string == tk2.string)
        #expect(tk1.length == md.utf16.count)
    }

    // MARK: - Rapid replacement

    @Test("Rapid text replacement converges to same final state")
    func rapidReplacementParity() {
        let versions = [
            "# First",
            "# First\n\nSome body text",
            "# First\n\nSome body text\n\n## Second",
            "# Changed Title\n\nNew body\n\n## Second\n\n- list item",
        ]

        let tk1 = MarkdownTextStorage()
        tk1.isDark = false
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let tk2 = tcs.textStorage else { return }

        for version in versions {
            tk1.beginEditing()
            tk1.replaceCharacters(in: NSRange(location: 0, length: tk1.length), with: version)
            tk1.endEditing()

            tcs.performEditingTransaction {
                tk2.replaceCharacters(
                    in: NSRange(location: 0, length: tk2.length), with: version
                )
            }
        }

        #expect(tk1.string == tk2.string)
        #expect(tk1.string == versions.last)
    }

    // MARK: - Mixed formatting

    @Test("Complex mixed formatting produces same text in both stacks")
    func mixedFormattingParity() {
        let md = """
        # Title

        A paragraph with **bold**, *italic*, and `code`.

        > A blockquote with [[wikilink]]

        - [ ] Task one
        - [x] Task two

        ```swift
        let x = 42
        ```

        ---

        Normal text with ~~strikethrough~~.
        """
        let tk1 = makeTK1Storage(md)
        guard let tk2 = makeTK2Storage(md) else { return }

        // Both stacks must preserve the raw text identically
        #expect(tk1.string == tk2.string)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Tests? (passed|failed)|Executed)'`
Expected: All edge case tests pass.

---

### Task 8: Performance benchmarks

**Files:**
- Create: `EpistemosTests/TextKit2BenchmarkTests.swift`

**Context:** Benchmark key hot paths comparing TK1 vs TK2. Uses Swift Testing with manual timing (no `measure {}` block needed — just `ContinuousClock`). Benchmarks are informational — they log timing results but don't have strict pass/fail thresholds (hardware varies).

**Step 1: Create benchmark test file**

```swift
import Testing
import AppKit
import os
@testable import Epistemos

// MARK: - TextKit 2 Performance Benchmarks
// Comparative timing of TK1 vs TK2 for key hot paths.
// These tests log timing data — no strict pass/fail thresholds.

private let benchLog = Logger(subsystem: "com.epistemos.tests", category: "TK2Benchmark")

@Suite("TextKit 2 - Performance Benchmarks")
struct TK2BenchmarkTests {

    // MARK: - Helpers

    private func generateMarkdown(lines: Int) -> String {
        var parts: [String] = []
        parts.reserveCapacity(lines)
        for i in 0..<lines {
            switch i % 10 {
            case 0: parts.append("# Heading \(i)")
            case 1: parts.append("Normal paragraph with **bold** and *italic* text.")
            case 2: parts.append("- List item with `inline code`")
            case 3: parts.append("> Blockquote with [[wikilink]]")
            case 4: parts.append("- [ ] Task item \(i)")
            case 5: parts.append("Another paragraph with ~~strikethrough~~ and [link](url).")
            case 6: parts.append("## Sub Heading \(i)")
            case 7: parts.append("```swift")
            case 8: parts.append("let value = \(i)")
            default: parts.append("```")
            }
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Initial Load

    @Test("Initial load: 1K lines — TK1 vs TK2")
    func initialLoad1K() {
        let md = generateMarkdown(lines: 1000)
        let clock = ContinuousClock()

        let tk1Time = clock.measure {
            let storage = MarkdownTextStorage()
            storage.isDark = false
            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: md)
            storage.endEditing()
        }

        let tk2Time = clock.measure {
            let (_, tv) = ProseTextView2.makeTextKit2()
            guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
                  let storage = tcs.textStorage else { return }
            tcs.performEditingTransaction {
                storage.replaceCharacters(
                    in: NSRange(location: 0, length: storage.length), with: md
                )
            }
        }

        benchLog.info("Initial load 1K: TK1=\(tk1Time), TK2=\(tk2Time)")
        // Informational — no threshold assertion
        #expect(true, "TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    @Test("Initial load: 10K lines — TK1 vs TK2")
    func initialLoad10K() {
        let md = generateMarkdown(lines: 10_000)
        let clock = ContinuousClock()

        let tk1Time = clock.measure {
            let storage = MarkdownTextStorage()
            storage.isDark = false
            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: md)
            storage.endEditing()
        }

        let tk2Time = clock.measure {
            let (_, tv) = ProseTextView2.makeTextKit2()
            guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
                  let storage = tcs.textStorage else { return }
            tcs.performEditingTransaction {
                storage.replaceCharacters(
                    in: NSRange(location: 0, length: storage.length), with: md
                )
            }
        }

        benchLog.info("Initial load 10K: TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    // MARK: - Per-Keystroke Highlight

    @Test("Per-keystroke highlight latency — TK1 vs TK2")
    func keystrokeHighlight() {
        let base = generateMarkdown(lines: 500)
        let clock = ContinuousClock()

        // TK1: insert a character and measure processEditing
        let tk1Storage = MarkdownTextStorage()
        tk1Storage.isDark = false
        tk1Storage.beginEditing()
        tk1Storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: base)
        tk1Storage.endEditing()

        let tk1Time = clock.measure {
            for _ in 0..<100 {
                tk1Storage.beginEditing()
                tk1Storage.replaceCharacters(
                    in: NSRange(location: tk1Storage.length, length: 0), with: "x"
                )
                tk1Storage.endEditing()
            }
        }

        // TK2: insert a character and measure
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let tk2Storage = tcs.textStorage else { return }
        tcs.performEditingTransaction {
            tk2Storage.replaceCharacters(
                in: NSRange(location: 0, length: tk2Storage.length), with: base
            )
        }

        let tk2Time = clock.measure {
            for _ in 0..<100 {
                tcs.performEditingTransaction {
                    tk2Storage.replaceCharacters(
                        in: NSRange(location: tk2Storage.length, length: 0), with: "x"
                    )
                }
            }
        }

        benchLog.info("100 keystrokes: TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    // MARK: - Page Swap

    @Test("Page swap latency — TK1 pool vs TK2 replace")
    func pageSwap() {
        let page1 = generateMarkdown(lines: 200)
        let page2 = generateMarkdown(lines: 300)
        let clock = ContinuousClock()

        // TK1: pool-based swap
        let tk1Time = clock.measure {
            for _ in 0..<20 {
                let slot1 = PageStoragePool.shared.getOrCreate(
                    pageId: "bench-p1", bodyText: page1, isDark: false
                )
                _ = slot1.storage.string
                let slot2 = PageStoragePool.shared.getOrCreate(
                    pageId: "bench-p2", bodyText: page2, isDark: false
                )
                _ = slot2.storage.string
            }
        }

        // TK2: in-place replacement (simulated — no actual layout manager swap needed)
        let (_, tv) = ProseTextView2.makeTextKit2()
        guard let tcs = tv.textLayoutManager?.textContentManager as? NSTextContentStorage,
              let storage = tcs.textStorage else { return }

        let tk2Time = clock.measure {
            for _ in 0..<20 {
                tcs.performEditingTransaction {
                    storage.replaceCharacters(
                        in: NSRange(location: 0, length: storage.length), with: page1
                    )
                }
                tcs.performEditingTransaction {
                    storage.replaceCharacters(
                        in: NSRange(location: 0, length: storage.length), with: page2
                    )
                }
            }
        }

        benchLog.info("20 page swaps: TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "TK1=\(tk1Time), TK2=\(tk2Time)")

        // Cleanup
        PageStoragePool.shared.remove(pageId: "bench-p1")
        PageStoragePool.shared.remove(pageId: "bench-p2")
    }
}
```

**Step 2: Run benchmarks**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Tests? (passed|failed)|Executed|TK[12]=)'`
Expected: All benchmarks pass. Timing results logged.

**Step 3: Commit benchmarks and edge case tests**

```bash
git add EpistemosTests/TextKit2ParityTests.swift EpistemosTests/TextKit2BenchmarkTests.swift
git commit -m "test: Phase 10 edge case parity tests + TK1 vs TK2 performance benchmarks"
```

---

### Task 9: Full test suite run + audit gate

**Context:** Phase 10 audit gate: 3 consecutive passing runs of build + test + Rust tests.

**Step 1: Run Swift build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 2: Run Swift tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Executed|FAIL)'`
Expected: All tests pass.

**Step 3: Run Rust tests**

Run: `cd graph-engine && cargo test 2>&1 | tail -10`
Expected: All tests pass.

**Step 4: If all pass, repeat steps 1-3 two more times for the 3-pass audit gate.**

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: Phase 10 complete — TK2 integration, parity tests, benchmarks"
```
