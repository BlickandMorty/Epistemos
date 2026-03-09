# Phase 7: Callouts + LaTeX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add callout block rendering (colored borders, icons, type detection) and display math support to the TextKit 2 prose editor, porting existing TK1 callout logic and extending the Rust parser.

**Architecture:** Callout type detection moves to Rust (encode type ID in `StructureSpan.metadata` high byte for `ParaType::BlockQuote` lines). Swift reads the type ID and applies callout-specific styling (left border, background, icon) via custom `drawBackground` rendering in ProseTextView2. Display math (`$$...$$`) gets a new `StyleKind` in Rust and styled rendering in `applySpanStyle`. LaTeX→image rendering deferred to Phase 9 (YAGNI: styled text is sufficient for v1).

**Tech Stack:** Rust (pulldown-cmark structure parser), Swift (TextKit 2 NSTextLayoutFragment, NSTextContentStorageDelegate, Core Graphics drawing)

---

## Sub-Phase 7a: Callout Detection in Rust

### Task 1: Callout Type ID in Structure Parser

**Files:**
- Modify: `graph-engine/src/markdown.rs:497-505` (blockquote classification)
- Test: `graph-engine/src/markdown.rs` (inline tests)

**Step 1: Write the failing test**

Add to the structure parser test section in `markdown.rs`:

```rust
#[test]
fn structure_callout_note() {
    let spans = structure("> [!note] Important\n> Body line\n> More body");
    assert_eq!(spans.len(), 3);
    assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
    // High byte = callout type (1 = note), low byte = depth
    assert_eq!(spans[0].metadata & 0xFF, 1); // depth
    assert_eq!((spans[0].metadata >> 8) & 0xFF, 1); // callout type: note
    // Continuation lines inherit callout type
    assert_eq!((spans[1].metadata >> 8) & 0xFF, 1);
    assert_eq!((spans[2].metadata >> 8) & 0xFF, 1);
}

#[test]
fn structure_callout_warning() {
    let spans = structure("> [!warning]\n> Be careful");
    assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
    assert_eq!((spans[0].metadata >> 8) & 0xFF, 3); // warning
}

#[test]
fn structure_callout_plain_blockquote() {
    let spans = structure("> Just a quote\n> Second line");
    assert_eq!(spans[0].para_type, ParaType::BlockQuote as u8);
    assert_eq!((spans[0].metadata >> 8) & 0xFF, 0); // no callout type
}

#[test]
fn structure_callout_danger() {
    let spans = structure("> [!danger] Watch out\n> Details here\nPlain text");
    assert_eq!((spans[0].metadata >> 8) & 0xFF, 7); // danger
    assert_eq!((spans[1].metadata >> 8) & 0xFF, 7); // continuation inherits
    assert_eq!(spans[2].para_type, ParaType::Body as u8); // non-quote line resets
}
```

**Step 2: Run test to verify it fails**

Run: `cd graph-engine && cargo test structure_callout -- --nocapture 2>&1 | tail -10`
Expected: FAIL — metadata high byte is 0

**Step 3: Implement callout detection**

Add callout type ID mapping function after `count_blockquote_depth`:

```rust
/// Detect callout type from a blockquote line: `> [!type]` or `> [!type] Title`.
/// Returns 0 for plain blockquote, 1-9 for callout types.
fn detect_callout_type(trimmed: &str) -> u8 {
    // Strip leading `>` and whitespace to find `[!type]`
    let inner = trimmed.trim_start_matches(|c: char| c == '>' || c == ' ');
    if !inner.starts_with("[!") { return 0; }
    let after = &inner[2..];
    let end = match after.find(']') {
        Some(i) => i,
        None => return 0,
    };
    let raw = after[..end].trim();
    match raw {
        "note" | "info" => 1,
        "tip" | "hint" | "important" => 2,
        "warning" | "caution" | "attention" => 3,
        "success" | "check" | "done" => 4,
        "question" | "help" | "faq" => 5,
        "quote" | "cite" => 6,
        "danger" | "error" | "bug" | "fail" | "failure" => 7,
        "example" => 8,
        "abstract" | "summary" | "tldr" => 9,
        _ => 1, // unknown callout defaults to "note"
    }
}
```

Modify the blockquote section in `parse_structure` to detect callouts and propagate type to continuation lines. Add a `callout_type: u8` state variable alongside `in_code_block`:

```rust
// At the top of parse_structure, alongside existing state:
let mut active_callout_type: u8 = 0;

// Replace the existing blockquote block (lines ~497-505):
// Blockquote
if trimmed.starts_with('>') {
    let depth = count_blockquote_depth(trimmed);
    let callout = detect_callout_type(trimmed);
    if callout > 0 {
        active_callout_type = callout;
    }
    // Encode: low byte = depth, high byte = callout type
    let metadata = (depth as u16) | ((active_callout_type as u16) << 8);
    spans.push(StructureSpan {
        para_type: ParaType::BlockQuote as u8,
        _pad: 0,
        metadata,
    });
    continue;
}

// For non-blockquote lines, reset callout tracking:
active_callout_type = 0;
```

Add the `active_callout_type = 0;` reset BEFORE the first classification check (after `in_html_comment` but before heading detection). Since each classification ends with `continue`, the reset only fires for lines that fall through to being classified — but actually, we need it to reset whenever we encounter a non-`>` line. Place it right before the heading check:

```rust
// Reset callout tracking on any non-blockquote line
// (the blockquote branch above already continues past this)
active_callout_type = 0;
```

**Step 4: Run tests**

Run: `cd graph-engine && cargo test structure_callout -- --nocapture 2>&1 | tail -10`
Expected: All 4 callout tests PASS

Run: `cd graph-engine && cargo test 2>&1 | tail -3`
Expected: All tests pass (no regressions)

**Step 5: Commit**

```bash
git add graph-engine/src/markdown.rs
git commit -m "feat: Phase 7 Task 1 — callout type detection in Rust structure parser"
```

---

### Task 2: Display Math Detection in Rust

**Files:**
- Modify: `graph-engine/src/markdown.rs` (StyleKind enum + post-parse extraction)
- Test: `graph-engine/src/markdown.rs` (inline tests)

**Step 1: Write the failing test**

```rust
#[test]
fn extract_display_math() {
    let text = "before\n$$\nx^2 + y^2 = z^2\n$$\nafter";
    let spans = parse(text);
    let display_math: Vec<_> = spans.iter().filter(|s| s.style == 26).collect();
    assert_eq!(display_math.len(), 1);
    // Should span from first $$ to closing $$
    let dm = display_math[0];
    let captured = &text[dm.start as usize..dm.end as usize];
    assert!(captured.starts_with("$$"));
    assert!(captured.ends_with("$$"));
}

#[test]
fn inline_math_not_display() {
    let text = "The formula $x^2$ is inline";
    let spans = parse(text);
    let inline: Vec<_> = spans.iter().filter(|s| s.style == 19).collect();
    let display: Vec<_> = spans.iter().filter(|s| s.style == 26).collect();
    assert_eq!(inline.len(), 1);
    assert_eq!(display.len(), 0);
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL — StyleKind 26 does not exist

**Step 3: Implement display math**

Add `DisplayMath = 26` to the `StyleKind` enum:

```rust
pub enum StyleKind {
    // ... existing variants ...
    BlockReferenceBrackets = 25,
    DisplayMath = 26,       // $$...$$
}
```

Add `extract_display_math()` function alongside `extract_inline_math()`:

```rust
/// Extract display math blocks: $$...$$ (possibly multi-line).
/// Returns byte ranges in the original text.
fn extract_display_math(text: &str, spans: &mut Vec<StyleSpan>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 1 < bytes.len() {
        if bytes[i] == b'$' && bytes[i + 1] == b'$' {
            // Found opening $$
            let start = i;
            let mut j = i + 2;
            // Find closing $$
            while j + 1 < bytes.len() {
                if bytes[j] == b'$' && bytes[j + 1] == b'$' {
                    let end = j + 2;
                    spans.push(StyleSpan {
                        start: start as u32,
                        end: end as u32,
                        style: StyleKind::DisplayMath as u8,
                        depth: 0,
                        group: 0,
                        _pad: 0,
                    });
                    i = end;
                    break;
                }
                j += 1;
            }
            if j + 1 >= bytes.len() {
                break; // no closing found
            }
        } else {
            i += 1;
        }
    }
}
```

Call `extract_display_math(text, &mut spans)` in `parse()` BEFORE `extract_inline_math()` (so display math spans take priority and inline math extraction can skip `$$` regions).

In `extract_inline_math()`, add a check to skip positions inside existing display math spans:

```rust
// At the top of extract_inline_math, before the main loop:
let display_ranges: Vec<(u32, u32)> = spans.iter()
    .filter(|s| s.style == StyleKind::DisplayMath as u8)
    .map(|s| (s.start, s.end))
    .collect();

// Inside the loop, when a `$` is found at position i:
// Skip if inside a display math range
if display_ranges.iter().any(|(s, e)| (i as u32) >= *s && (i as u32) < *e) {
    i += 1;
    continue;
}
```

**Step 4: Run tests**

Run: `cd graph-engine && cargo test display_math -- --nocapture`
Expected: PASS

Run: `cd graph-engine && cargo test inline_math -- --nocapture`
Expected: All inline math tests still PASS (no regression)

**Step 5: Commit**

```bash
git add graph-engine/src/markdown.rs
git commit -m "feat: Phase 7 Task 2 — display math detection in Rust parser"
```

---

### Task 3: Update C Header + Swift Visibility

**Files:**
- Modify: `graph-engine-bridge/graph_engine.h` (if needed — check if StyleKind 26 needs header changes)
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

The `StyleKind` enum isn't exposed in the C header — it's just a `u8` in `StyleSpan.style`. No header change needed. But add a Swift-side test to verify the FFI returns display math spans.

**Step 1: Write the failing test**

```swift
@Test("Display math $$...$$ detected by Rust parser")
func displayMathDetection() {
    let text = "$$x^2$$"
    let storage = MarkdownContentStorage()
    storage.reparse(text: text)
    // Parse inline spans
    var spansPtr: UnsafeMutablePointer<StyleSpan>?
    var count: UInt32 = 0
    text.withCString { cStr in
        let result = markdown_parse(cStr, UInt32(strlen(cStr)), &spansPtr, &count)
        #expect(result == 0)
    }
    guard let spans = spansPtr, count > 0 else {
        #expect(Bool(false), "No spans returned")
        return
    }
    defer { markdown_free_spans(spans, count) }

    let displayMath = (0..<Int(count)).filter { spans[$0].style == 26 }
    #expect(!displayMath.isEmpty, "Expected DisplayMath (style=26) span")
}
```

**Step 2: Run test, verify it fails, then passes after Rust changes from Task 2**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep "displayMath"`

**Step 3: Commit**

```bash
git add EpistemosTests/TextKit2FoundationTests.swift
git commit -m "test: Phase 7 Task 3 — display math FFI detection test"
```

---

## Sub-Phase 7b: Callout Styling in TK2

### Task 4: Callout Colors in EpistemosTheme

**Files:**
- Modify: `Epistemos/Theme/EpistemosTheme.swift`
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

**Step 1: Write the failing test**

```swift
@Suite("TextKit 2 - Callout Colors")
struct CalloutColorTests {

    @Test("callout color for each type returns non-nil")
    func calloutColorTypes() {
        for typeId: UInt8 in 1...9 {
            let colors = EpistemosTheme.light.calloutColors(typeId: typeId)
            #expect(colors.accent != .clear)
            #expect(colors.background != .clear)
        }
    }

    @Test("plain blockquote (type 0) returns nil")
    func plainBlockquote() {
        let colors = EpistemosTheme.light.calloutColors(typeId: 0)
        #expect(colors == nil)
    }

    @Test("dark theme callout colors differ from light")
    func darkThemeCalloutColors() {
        let lightColors = EpistemosTheme.light.calloutColors(typeId: 1)!
        let darkColors = EpistemosTheme.sunset.calloutColors(typeId: 1)!
        #expect(lightColors.background != darkColors.background)
    }
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `calloutColors(typeId:)` not defined

**Step 3: Implement callout colors**

Add to `EpistemosTheme` (at the bottom, near `nsColorForTokenType`):

```swift
struct CalloutStyle {
    let accent: NSColor
    let background: NSColor
    let icon: String  // SF Symbol name
}

/// Returns callout styling for a callout type ID from the Rust parser.
/// Type 0 = plain blockquote (no callout). Types 1-9 map to callout categories.
func calloutColors(typeId: UInt8) -> CalloutStyle? {
    guard typeId > 0 else { return nil }
    let dark = isDark
    let base: NSColor
    let icon: String

    switch typeId {
    case 1: // note, info
        base = NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1)
        icon = "info.circle.fill"
    case 2: // tip, hint, important
        base = NSColor(red: 0.25, green: 0.75, blue: 0.55, alpha: 1)
        icon = "lightbulb.fill"
    case 3: // warning, caution, attention
        base = NSColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 1)
        icon = "exclamationmark.triangle.fill"
    case 4: // success, check, done
        base = NSColor(red: 0.25, green: 0.75, blue: 0.35, alpha: 1)
        icon = "checkmark.circle.fill"
    case 5: // question, help, faq
        base = NSColor(red: 0.65, green: 0.50, blue: 0.90, alpha: 1)
        icon = "questionmark.circle.fill"
    case 6: // quote, cite
        base = NSColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        icon = "quote.opening"
    case 7: // danger, error, bug, fail
        base = NSColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1)
        icon = "xmark.octagon.fill"
    case 8: // example
        base = NSColor(red: 0.60, green: 0.45, blue: 0.85, alpha: 1)
        icon = "list.clipboard.fill"
    case 9: // abstract, summary, tldr
        base = NSColor(red: 0.30, green: 0.70, blue: 0.85, alpha: 1)
        icon = "doc.text.fill"
    default:
        return nil
    }

    let background = dark ? base.withAlphaComponent(0.07) : base.withAlphaComponent(0.05)
    return CalloutStyle(accent: base, background: background, icon: icon)
}
```

**Step 4: Run tests**

Expected: All 3 callout color tests PASS

**Step 5: Commit**

```bash
git add Epistemos/Theme/EpistemosTheme.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 7 Task 4 — theme-aware callout color palette"
```

---

### Task 5: Callout-Aware Blockquote Styling

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift:241-251` (blockquote case)
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

**Step 1: Write the failing test**

```swift
@Test("callout blockquote gets accent foreground color")
func calloutBlockquoteStyling() {
    let storage = MarkdownContentStorage()
    // Metadata: low byte = 1 (depth), high byte = 1 (note callout)
    let metadata: UInt16 = (1 << 8) | 1
    let attrStr = NSMutableAttributedString(string: "> [!note] Important info")
    let range = NSRange(location: 0, length: attrStr.length)
    storage.applyStructuralStyleForTest(to: attrStr, range: range, paraType: 5, metadata: metadata)

    let fg = attrStr.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? NSColor
    // Callout note should use blue-tinted foreground, not plain 0.8 alpha
    #expect(fg != nil)
    // The accent should be bluer than plain blockquote gray
    let blueComponent = fg!.usingColorSpace(.sRGB)!.blueComponent
    #expect(blueComponent > 0.5, "Callout note should have blue-tinted text")
}

@Test("plain blockquote retains original muted styling")
func plainBlockquoteStyling() {
    let storage = MarkdownContentStorage()
    let attrStr = NSMutableAttributedString(string: "> Just a quote")
    let range = NSRange(location: 0, length: attrStr.length)
    storage.applyStructuralStyleForTest(to: attrStr, range: range, paraType: 5, metadata: 1)

    let fg = attrStr.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? NSColor
    #expect(fg != nil)
    // Plain blockquote uses foreground at 0.8 alpha — not accent-tinted
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL — all blockquotes currently get the same 0.8 alpha foreground

**Step 3: Update blockquote styling**

In `MarkdownContentStorage.applyStructuralStyle`, modify case 5:

```swift
case 5: // BlockQuote (plain or callout)
    let depth = metadata & 0xFF
    let calloutTypeId = UInt8((metadata >> 8) & 0xFF)

    let quoteParagraph = NSMutableParagraphStyle()
    quoteParagraph.lineSpacing = 4
    quoteParagraph.headIndent = 20
    quoteParagraph.firstLineHeadIndent = 20
    quoteParagraph.paragraphSpacing = 4

    if let callout = theme.calloutColors(typeId: calloutTypeId) {
        // Callout: accent-tinted text, background handled by drawBackground
        attrStr.addAttributes([
            .font: bodyFont,
            .foregroundColor: theme.isDark ? callout.accent.withAlphaComponent(0.9) : callout.accent,
            .paragraphStyle: quoteParagraph,
        ], range: range)
    } else {
        // Plain blockquote: muted foreground
        attrStr.addAttributes([
            .font: bodyFont,
            .foregroundColor: foreground.withAlphaComponent(0.8),
            .paragraphStyle: quoteParagraph,
        ], range: range)
    }
```

**Step 4: Run tests**

Expected: Both callout styling tests PASS + no regressions in existing blockquote tests

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 7 Task 5 — callout-aware blockquote styling"
```

---

### Task 6: Callout Background + Left Border Drawing

**Files:**
- Modify: `Epistemos/Views/Notes/ProseTextView2.swift` (add `drawCalloutBackgrounds`)
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

**Step 1: Write the failing test**

Testing drawing is hard to unit test, so write an integration test for callout metadata detection:

```swift
@Test("callout metadata round-trip: Rust parser → Swift type ID")
func calloutMetadataRoundTrip() {
    let storage = MarkdownContentStorage()
    storage.reparse(text: "> [!warning] Be careful\n> Details here\nPlain")

    // Line 0: callout header
    let meta0 = storage.paragraphMetadata(at: 0)!
    let type0 = (meta0 >> 8) & 0xFF
    #expect(type0 == 3, "Expected warning type (3)")

    // Line 1: continuation inherits callout type
    let meta1 = storage.paragraphMetadata(at: 1)!
    let type1 = (meta1 >> 8) & 0xFF
    #expect(type1 == 3, "Continuation should inherit warning type")

    // Line 2: plain body, not a blockquote
    #expect(storage.paragraphType(at: 2) == 0, "Plain text should be Body")
}
```

**Step 2: Run tests (test passes once Rust Task 1 is done)**

**Step 3: Implement callout background drawing**

In `ProseTextView2`, add `drawCalloutBackgrounds(in:)` to `drawBackground`:

```swift
override func drawBackground(in rect: NSRect) {
    super.drawBackground(in: rect)
    drawCalloutBackgrounds(in: rect)  // NEW — before tables
    drawTableFills(in: rect)
    drawTableGridLines(in: rect)
    drawFoldIndicators(in: rect)
}
```

Implement `drawCalloutBackgrounds`:

```swift
private func drawCalloutBackgrounds(in dirtyRect: NSRect) {
    guard let contentStorage = textLayoutManager?.textContentManager
            as? NSTextContentStorage else { return }
    guard (string as NSString).length > 0 else { return }

    enumerateVisibleFragments(in: dirtyRect) { fragment, fragFrame in
        guard let (_, nsRange) = self.paragraphInfo(
            for: fragment, contentStorage: contentStorage
        ) else { return true }

        let lineIdx = self.markdownDelegate.lineIndex(at: nsRange.location)
        guard self.markdownDelegate.paragraphType(at: lineIdx) == 5 else { return true }

        guard let metadata = self.markdownDelegate.paragraphMetadata(at: lineIdx) else { return true }
        let calloutTypeId = UInt8((metadata >> 8) & 0xFF)
        guard let callout = self.markdownDelegate.theme.calloutColors(typeId: calloutTypeId) else {
            return true
        }

        // Background fill
        let bgRect = NSRect(
            x: fragFrame.minX + 16,
            y: fragFrame.minY,
            width: fragFrame.width - 16,
            height: fragFrame.height
        )
        callout.background.setFill()
        bgRect.fill()

        // Left accent border (3pt wide)
        let borderRect = NSRect(
            x: fragFrame.minX + 16,
            y: fragFrame.minY,
            width: 3,
            height: fragFrame.height
        )
        callout.accent.setFill()
        borderRect.fill()

        return true
    }
}
```

**Step 4: Run build + tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "callout|Callout" | head -10`
Expected: All callout tests PASS

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/ProseTextView2.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 7 Task 6 — callout background + left border drawing"
```

---

## Sub-Phase 7c: Display Math Styling

### Task 7: Display Math Styling in applySpanStyle

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift` (add `inlineStyleKinds` entry + `applySpanStyle` case)
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

**Step 1: Write the failing test**

```swift
@Test("Display math $$...$$ gets centered italic styling")
func displayMathStyling() {
    let storage = MarkdownContentStorage()
    let text = "$$E = mc^2$$"
    storage.reparse(text: text)
    let attrStr = NSMutableAttributedString(string: text)
    let range = NSRange(location: 0, length: attrStr.length)
    storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: false)

    // Content between $$ markers should be italic
    if attrStr.length > 4 {
        let contentFont = attrStr.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        #expect(contentFont != nil)
        let traits = NSFontManager.shared.traits(of: contentFont!)
        #expect(traits.contains(.italicFontMask), "Display math content should be italic")
    }
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL — style 26 not in `inlineStyleKinds`, so it's skipped

**Step 3: Implement display math styling**

Add `26` to `inlineStyleKinds`:

```swift
private static let inlineStyleKinds: Set<UInt8> = [
    4, 5, 6, 7, 13, 14, 15, 16, 17, 19, 24, 25,
    26, // DisplayMath
]
```

Add case 26 to `applySpanStyle`:

```swift
case 26: // DisplayMath $$...$$ — muted delimiters, accent italic content, centered
    attrStr.addAttributes([.foregroundColor: muted], range: range)
    if range.length > 4 {
        let content = NSRange(location: range.location + 2, length: range.length - 4)
        let mathSize = max(size + 1, 13)
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.lineSpacing = 6
        centered.paragraphSpacingBefore = 8
        centered.paragraphSpacing = 8
        attrStr.addAttributes([
            .font: NSFont(name: "NewYork-RegularItalic", size: mathSize)
                ?? NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask),
            .foregroundColor: accent.withAlphaComponent(0.85),
            .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.06 : 0.04),
            .paragraphStyle: centered,
        ], range: content)
    }
```

**Step 4: Run tests**

Expected: Display math styling test PASSES

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: Phase 7 Task 7 — display math styling with centered italic"
```

---

## Final Verification

### Task 8: Full Build + Test Suite

**Step 1: Run Swift build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 2: Run Swift tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: All tests PASS

**Step 3: Run Rust tests**

Run: `cd graph-engine && cargo test 2>&1 | tail -10`
Expected: All tests PASS

**Step 4: Verify no regressions**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "FAIL|error" | head -20`
Expected: No new failures

**Step 5: Commit summary**

```bash
git log --oneline -8
```

Expected commits (newest first):
```
feat: Phase 7 Task 7 — display math styling with centered italic
feat: Phase 7 Task 6 — callout background + left border drawing
feat: Phase 7 Task 5 — callout-aware blockquote styling
feat: Phase 7 Task 4 — theme-aware callout color palette
test: Phase 7 Task 3 — display math FFI detection test
feat: Phase 7 Task 2 — display math detection in Rust parser
feat: Phase 7 Task 1 — callout type detection in Rust structure parser
```
