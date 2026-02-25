# Writer Mode — Academic Document Editor

## Overview

Writer Mode is a toolbar toggle in NoteTabView that transforms the markdown prose editor into a paginated, Pages-like academic document view. The underlying data stays the same — `SDPage.body` (plain markdown) is the single source of truth. Writer Mode is purely a rendering/editing layer with full export to PDF, DOCX, plain text, and markdown.

## Architecture

```
NoteTabView
├── [Normal Mode] ProseEditorView (existing)
├── [Preview]     NotePreviewView (existing)
└── [Writer Mode] WriterModeView (new)
    ├── WriterFormatBar          — top strip with formatting controls
    ├── PagedDocumentView        — NSViewRepresentable: scrollable page stack
    │   ├── NSScrollView
    │   │   └── PageCanvasView   — custom NSView containing page tiles
    │   │       ├── PageTileView[0] — NSTextView sized to 8.5"×11"
    │   │       ├── PageTileView[1]
    │   │       └── ...          — pages added/removed dynamically
    │   └── Shared NSLayoutManager + WriterTextStorage
    └── WriterFormatState        — Observable model: style, spacing, margins, etc.
```

## New Files

- `WriterModeView.swift` — SwiftUI container (format bar + paged document)
- `PagedDocumentView.swift` — NSViewRepresentable managing TextKit page stack
- `WriterTextStorage.swift` — NSTextStorage subclass for academic formatting
- `WriterFormatState.swift` — Observable model for all format settings
- `WriterExportService.swift` — PDF, DOCX, plain text, markdown export
- `AcademicStyle.swift` — MLA, APA, Chicago preset definitions

## Files Modified

- `NoteWindowManager.swift` — Add Writer Mode toolbar button, wire toggle
- `SDPage.swift` — Format state stored in existing `frontMatterData` JSON blob

## WriterFormatState

```swift
@Observable class WriterFormatState {
    // Style preset
    var activePreset: AcademicStyle = .mla  // .mla, .apa, .chicago, .custom

    // Typography
    var fontFamily: String = "Times New Roman"
    var fontSize: CGFloat = 12
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false

    // Paragraph
    var alignment: NSTextAlignment = .left
    var lineSpacing: LineSpacing = .double  // .single, .onePointFive, .double
    var firstLineIndent: CGFloat = 36       // 0.5" in points
    var paragraphSpacingBefore: CGFloat = 0
    var paragraphSpacingAfter: CGFloat = 0

    // Document
    var showTitlePage: Bool = false
    var margins: PageMargins = .normal      // .normal(1"), .narrow(0.5"), .wide(1.5")
    var pageSize: PageSize = .letter        // .letter, .a4

    // Headers/Footers
    var showPageNumbers: Bool = true
    var pageNumberPosition: PageNumberPosition = .topRight
    var runningHead: String = ""
    var headerText: String = ""
    var footerText: String = ""

    // Title Page Fields
    var titlePageTitle: String = ""
    var titlePageAuthor: String = ""
    var titlePageInstitution: String = ""
    var titlePageCourse: String = ""
    var titlePageInstructor: String = ""
    var titlePageDate: String = ""
}
```

## Academic Style Presets

| Setting | MLA | APA | Chicago |
|---|---|---|---|
| Font | Times New Roman 12pt | Times New Roman 12pt | Times New Roman 12pt |
| Spacing | Double | Double | Double |
| Margins | 1" all sides | 1" all sides | 1" all sides |
| First-line indent | 0.5" | 0.5" | 0.5" |
| Alignment | Left | Left | Justified |
| Title page | Off (header block) | On (separate) | On (separate) |
| Page numbers | Top-right, last name + # | Top-right, # only | Bottom-center |
| Running head | Last name | Shortened title (caps) | None |

Selecting a preset bulk-sets all values. Changing any individual value flips preset to "Custom (based on MLA)".

## PagedDocumentView — TextKit Page Stack

One `NSLayoutManager` flows text across multiple `NSTextContainer`s (one per page). Each container is owned by a `PageTileView` (NSTextView).

- **Letter:** 612×792pt (8.5"×11" at 72dpi)
- **A4:** 595×842pt
- **Margins:** Applied via `NSTextView.textContainerInset` (1" = 72pt)
- **Page gap:** 20pt between pages
- **Canvas:** Grey/dark background matching app theme
- **Page surface:** Theme-aware (white in light mode, dark in dark mode). Exports always render white+black.

### Dynamic page management
- After every text change (debounced 50ms), check if last container overflows → add page
- If last page empty and 2+ pages → remove page

### Page tile rendering
- Theme-aware background (white in light, dark surface in dark mode)
- NSShadow with 2pt blur for floating paper effect
- Header/footer as overlay subviews at top/bottom margins

### Additional formatting
- Block quotes: indented 0.5" from left margin
- Hanging indent for Works Cited / References
- Proper 0.5" tab stops
- Widow/orphan control
- Section headings per APA levels

## WriterFormatBar

Two-row horizontal strip below toolbar, appears with spring animation.

**Row 1:** Style preset dropdown | Font picker, size, B/I/U/S | Alignment, line spacing, indent
**Row 2:** Title page toggle (with popover for fields) | Margins | Page numbers | Running head | Header | Footer | Export button

- Height: ~72pt (two rows of 28pt controls + padding)
- All native macOS controls (Picker, Toggle, TextField, Button)
- Appears: `.transition(.move(edge: .top).combined(with: .opacity))` + `.spring(duration: 0.3)`
- Font picker shows common academic fonts at top, full system list below

## Title Page

Standalone NSTextView (not in layout manager flow). Content auto-generated from metadata fields. Body text starts on page 2 when title page is on.

Layout varies per preset (MLA centered block, APA ⅓ from top with bold title, Chicago ⅓/⅔ split).

Title page fields persist in UserDefaults (author, institution, course carry across notes).

## Export Service

| Format | Method | Dependencies |
|---|---|---|
| PDF | `NSPrintOperation` on page tiles | Native (AppKit) |
| DOCX | Open XML generation → zip | Native (Foundation) |
| Plain Text | Strip markdown syntax | None |
| Markdown | `SDPage.body` as-is | None |

### PDF flow
1. Temporarily set pages to white background + black text
2. Create `NSPrintInfo` with matching page size/margins
3. `NSPrintOperation` → PDF data
4. Restore theme colors
5. `NSSavePanel` → save

### DOCX flow
1. Build Open XML in memory (document.xml, styles.xml, header/footer, sectPr)
2. Zip into .docx via Foundation
3. `NSSavePanel` → save

No external dependencies for any format.

## Integration

- Writer Mode toggle: toolbar button between Preview and Info (`doc.richtext` / `doc.plaintext`, ⌘R)
- Writer Mode and Preview are mutually exclusive
- Lock makes Writer Mode read-only (tiles non-editable, format bar disabled)
- Format state persisted per-note in `SDPage.frontMatterData`
- Text sync: Normal→Writer strips markdown to plain text + applies formatting. Writer→Normal strips formatting, re-wraps markdown. 5s debounced sync to SDPage.body while in Writer Mode.

## Animations
- Format bar: slide in from top with `.spring(duration: 0.3)`
- Editor swap: cross-fade with `.opacity` transition
- Page add/remove: fade in/out
- Title page popover: native macOS `.popover`
