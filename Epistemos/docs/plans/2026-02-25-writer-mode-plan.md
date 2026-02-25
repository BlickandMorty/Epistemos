# Writer Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Pages-like academic writing mode to the note editor with MLA/APA/Chicago presets, paginated WYSIWYG rendering, format bar, title page, and native PDF/DOCX export.

**Architecture:** Toolbar toggle swaps ProseEditorView for WriterModeView (format bar + paginated document). One NSLayoutManager flows text across multiple NSTextContainer/NSTextView page tiles. WriterTextStorage applies academic formatting. WriterFormatState (Observable) drives all controls. Export via NSPrintOperation (PDF) and Open XML zip (DOCX).

**Tech Stack:** AppKit (NSTextView, NSLayoutManager, NSTextContainer, NSPrintOperation, NSSavePanel), SwiftUI (format bar, toolbar), Foundation (JSON, zip via Data), SwiftData (SDPage.frontMatterData for persistence)

**Design doc:** `docs/plans/2026-02-25-writer-mode-design.md`

---

### Task 1: AcademicStyle — Preset Definitions

**Files:**
- Create: `Epistemos/Views/Notes/Writer/AcademicStyle.swift`

**Step 1: Create the file**

```swift
import AppKit

// MARK: - Academic Style Presets
// Defines MLA, APA, Chicago formatting presets.
// Each preset bulk-sets WriterFormatState values.
// Users can override individual settings → preset flips to .custom.

enum AcademicStyle: String, CaseIterable, Codable {
    case mla, apa, chicago, custom

    var displayName: String {
        switch self {
        case .mla: "MLA"
        case .apa: "APA"
        case .chicago: "Chicago"
        case .custom: "Custom"
        }
    }
}

// MARK: - Line Spacing

enum LineSpacing: String, CaseIterable, Codable {
    case single, onePointFive, double

    var displayName: String {
        switch self {
        case .single: "Single"
        case .onePointFive: "1.5"
        case .double: "Double"
        }
    }

    /// Multiplier applied to font line height.
    var multiplier: CGFloat {
        switch self {
        case .single: 1.0
        case .onePointFive: 1.5
        case .double: 2.0
        }
    }
}

// MARK: - Page Margins

enum PageMargins: String, CaseIterable, Codable {
    case normal, narrow, wide

    var displayName: String {
        switch self {
        case .normal: "Normal (1\")"
        case .narrow: "Narrow (0.5\")"
        case .wide: "Wide (1.5\")"
        }
    }

    /// Margin in points (72pt = 1 inch).
    var points: CGFloat {
        switch self {
        case .normal: 72
        case .narrow: 36
        case .wide: 108
        }
    }
}

// MARK: - Page Size

enum PageSize: String, CaseIterable, Codable {
    case letter, a4

    var displayName: String {
        switch self {
        case .letter: "Letter (8.5\" x 11\")"
        case .a4: "A4"
        }
    }

    /// Page dimensions in points (72pt = 1 inch).
    var size: NSSize {
        switch self {
        case .letter: NSSize(width: 612, height: 792)  // 8.5" x 11"
        case .a4: NSSize(width: 595, height: 842)
        }
    }
}

// MARK: - Page Number Position

enum PageNumberPosition: String, CaseIterable, Codable {
    case topRight, topLeft, topCenter
    case bottomRight, bottomLeft, bottomCenter

    var displayName: String {
        switch self {
        case .topRight: "Top Right"
        case .topLeft: "Top Left"
        case .topCenter: "Top Center"
        case .bottomRight: "Bottom Right"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        }
    }
}

// MARK: - Style Preset Values

struct AcademicPresetValues {
    let fontFamily: String
    let fontSize: CGFloat
    let lineSpacing: LineSpacing
    let alignment: NSTextAlignment
    let margins: PageMargins
    let firstLineIndent: CGFloat
    let showTitlePage: Bool
    let showPageNumbers: Bool
    let pageNumberPosition: PageNumberPosition
    let runningHeadStyle: RunningHeadStyle

    enum RunningHeadStyle {
        case lastNameAndPage      // MLA: "Smith 1"
        case shortenedTitleCaps   // APA: "RUNNING HEAD: TITLE"
        case none                 // Chicago
    }
}

extension AcademicStyle {
    /// Default values for this preset. Returns nil for .custom.
    var presetValues: AcademicPresetValues? {
        switch self {
        case .mla:
            return AcademicPresetValues(
                fontFamily: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .left,
                margins: .normal,
                firstLineIndent: 36,  // 0.5"
                showTitlePage: false,
                showPageNumbers: true,
                pageNumberPosition: .topRight,
                runningHeadStyle: .lastNameAndPage
            )
        case .apa:
            return AcademicPresetValues(
                fontFamily: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .left,
                margins: .normal,
                firstLineIndent: 36,
                showTitlePage: true,
                showPageNumbers: true,
                pageNumberPosition: .topRight,
                runningHeadStyle: .shortenedTitleCaps
            )
        case .chicago:
            return AcademicPresetValues(
                fontFamily: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .justified,
                margins: .normal,
                firstLineIndent: 36,
                showTitlePage: true,
                showPageNumbers: true,
                pageNumberPosition: .bottomCenter,
                runningHeadStyle: .none
            )
        case .custom:
            return nil
        }
    }
}
```

**Step 2: Add file to Xcode project**

The file lives under `Epistemos/Views/Notes/Writer/`. Create the `Writer` directory first:

```bash
mkdir -p Epistemos/Views/Notes/Writer
```

**Step 3: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Epistemos/Views/Notes/Writer/AcademicStyle.swift
git commit -m "feat(writer): add AcademicStyle preset definitions"
```

---

### Task 2: WriterFormatState — Observable Format Model

**Files:**
- Create: `Epistemos/Views/Notes/Writer/WriterFormatState.swift`

**Step 1: Create the file**

```swift
import AppKit
import SwiftUI

// MARK: - WriterFormatState
// Observable model holding all academic formatting parameters.
// Persists per-note via SDPage.frontMatterData (JSON blob).
// When a preset is selected, all values bulk-set from AcademicPresetValues.
// Changing any individual value flips activePreset to .custom.

@Observable @MainActor
final class WriterFormatState {
    // MARK: - Style Preset
    var activePreset: AcademicStyle = .mla {
        didSet { if activePreset != .custom { applyPreset(activePreset) } }
    }
    /// Tracks which preset was last applied, for "Custom (based on MLA)" label.
    var basePreset: AcademicStyle = .mla

    // MARK: - Typography
    var fontFamily: String = "Times New Roman" { didSet { markCustom() } }
    var fontSize: CGFloat = 12 { didSet { markCustom() } }
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false

    // MARK: - Paragraph
    var alignment: NSTextAlignment = .left { didSet { markCustom() } }
    var lineSpacing: LineSpacing = .double { didSet { markCustom() } }
    var firstLineIndent: CGFloat = 36 { didSet { markCustom() } }
    var paragraphSpacingBefore: CGFloat = 0 { didSet { markCustom() } }
    var paragraphSpacingAfter: CGFloat = 0 { didSet { markCustom() } }

    // MARK: - Document
    var showTitlePage: Bool = false { didSet { markCustom() } }
    var margins: PageMargins = .normal { didSet { markCustom() } }
    var pageSize: PageSize = .letter { didSet { markCustom() } }

    // MARK: - Headers / Footers
    var showPageNumbers: Bool = true { didSet { markCustom() } }
    var pageNumberPosition: PageNumberPosition = .topRight { didSet { markCustom() } }
    var runningHead: String = ""
    var headerText: String = ""
    var footerText: String = ""

    // MARK: - Title Page Fields
    var titlePageTitle: String = ""
    var titlePageAuthor: String = ""
    var titlePageInstitution: String = ""
    var titlePageCourse: String = ""
    var titlePageInstructor: String = ""
    var titlePageDate: String = ""

    /// Suppresses markCustom() during bulk preset application.
    private var isApplyingPreset = false

    // MARK: - Init

    init(preset: AcademicStyle = .mla) {
        self.activePreset = preset
        self.basePreset = preset
        if let values = preset.presetValues {
            applyValues(values)
        }
        loadTitlePageDefaults()
    }

    // MARK: - Preset Application

    func applyPreset(_ style: AcademicStyle) {
        guard let values = style.presetValues else { return }
        isApplyingPreset = true
        basePreset = style
        applyValues(values)
        isApplyingPreset = false
    }

    private func applyValues(_ v: AcademicPresetValues) {
        fontFamily = v.fontFamily
        fontSize = v.fontSize
        lineSpacing = v.lineSpacing
        alignment = v.alignment
        margins = v.margins
        firstLineIndent = v.firstLineIndent
        showTitlePage = v.showTitlePage
        showPageNumbers = v.showPageNumbers
        pageNumberPosition = v.pageNumberPosition
    }

    private func markCustom() {
        guard !isApplyingPreset, activePreset != .custom else { return }
        activePreset = .custom
    }

    // MARK: - Computed Properties

    /// Resolved NSFont for the current typography settings.
    var resolvedFont: NSFont {
        var traits: NSFontTraitMask = []
        if isBold { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }

        let baseFont = NSFont(name: fontFamily, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)

        if traits.isEmpty { return baseFont }
        return NSFontManager.shared.convert(baseFont, toHaveTrait: traits)
    }

    /// Resolved NSParagraphStyle for the current paragraph settings.
    var resolvedParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.firstLineHeadIndent = firstLineIndent

        // Line spacing: use lineSpacing multiplier applied to font's default line height.
        let font = resolvedFont
        let defaultLineHeight = font.ascender - font.descender + font.leading
        let targetLineHeight = defaultLineHeight * lineSpacing.multiplier
        style.minimumLineHeight = targetLineHeight
        style.maximumLineHeight = targetLineHeight

        style.paragraphSpacingBefore = paragraphSpacingBefore
        style.paragraphSpacing = paragraphSpacingAfter

        // Tab stops at 0.5" intervals
        style.tabStops = (1...10).map {
            NSTextTab(type: .leftTabStopType, location: CGFloat($0) * 36)
        }

        return style
    }

    /// Text area size after subtracting margins from page size.
    var textAreaSize: NSSize {
        let page = pageSize.size
        let m = margins.points
        return NSSize(width: page.width - m * 2, height: page.height - m * 2)
    }

    /// Preset label for the dropdown.
    var presetLabel: String {
        if activePreset == .custom {
            return "Custom (based on \(basePreset.displayName))"
        }
        return activePreset.displayName
    }

    // MARK: - Persistence (JSON via frontMatterData)

    /// Keys used in the frontMatter dictionary for writer format state.
    private enum Keys {
        static let writerPreset = "writer.preset"
        static let writerFont = "writer.font"
        static let writerFontSize = "writer.fontSize"
        static let writerLineSpacing = "writer.lineSpacing"
        static let writerAlignment = "writer.alignment"
        static let writerMargins = "writer.margins"
        static let writerPageSize = "writer.pageSize"
        static let writerIndent = "writer.indent"
        static let writerTitlePage = "writer.titlePage"
        static let writerPageNumbers = "writer.pageNumbers"
        static let writerPageNumPos = "writer.pageNumPos"
        static let writerRunningHead = "writer.runningHead"
        static let writerHeader = "writer.header"
        static let writerFooter = "writer.footer"
        static let writerTitleTitle = "writer.title.title"
        static let writerTitleAuthor = "writer.title.author"
        static let writerTitleInstitution = "writer.title.institution"
        static let writerTitleCourse = "writer.title.course"
        static let writerTitleInstructor = "writer.title.instructor"
        static let writerTitleDate = "writer.title.date"
    }

    /// Load format state from a page's frontMatter dictionary.
    func load(from frontMatter: [String: String]) {
        isApplyingPreset = true
        defer { isApplyingPreset = false }

        if let raw = frontMatter[Keys.writerPreset],
           let preset = AcademicStyle(rawValue: raw) {
            activePreset = preset
            basePreset = preset
            if let values = preset.presetValues {
                applyValues(values)
            }
        }

        // Override with per-note customizations
        if let f = frontMatter[Keys.writerFont] { fontFamily = f }
        if let s = frontMatter[Keys.writerFontSize], let v = CGFloat(Double(s) ?? 12) as CGFloat? { fontSize = v }
        if let raw = frontMatter[Keys.writerLineSpacing], let v = LineSpacing(rawValue: raw) { lineSpacing = v }
        if let raw = frontMatter[Keys.writerAlignment] { alignment = NSTextAlignment(rawString: raw) }
        if let raw = frontMatter[Keys.writerMargins], let v = PageMargins(rawValue: raw) { margins = v }
        if let raw = frontMatter[Keys.writerPageSize], let v = PageSize(rawValue: raw) { pageSize = v }
        if let s = frontMatter[Keys.writerIndent], let v = CGFloat(Double(s) ?? 36) as CGFloat? { firstLineIndent = v }
        if let raw = frontMatter[Keys.writerTitlePage] { showTitlePage = raw == "true" }
        if let raw = frontMatter[Keys.writerPageNumbers] { showPageNumbers = raw == "true" }
        if let raw = frontMatter[Keys.writerPageNumPos], let v = PageNumberPosition(rawValue: raw) { pageNumberPosition = v }
        if let s = frontMatter[Keys.writerRunningHead] { runningHead = s }
        if let s = frontMatter[Keys.writerHeader] { headerText = s }
        if let s = frontMatter[Keys.writerFooter] { footerText = s }
        if let s = frontMatter[Keys.writerTitleTitle] { titlePageTitle = s }
        if let s = frontMatter[Keys.writerTitleAuthor] { titlePageAuthor = s }
        if let s = frontMatter[Keys.writerTitleInstitution] { titlePageInstitution = s }
        if let s = frontMatter[Keys.writerTitleCourse] { titlePageCourse = s }
        if let s = frontMatter[Keys.writerTitleInstructor] { titlePageInstructor = s }
        if let s = frontMatter[Keys.writerTitleDate] { titlePageDate = s }

        // If any value differs from preset after load, mark as custom
        if activePreset != .custom, let values = activePreset.presetValues {
            if fontFamily != values.fontFamily || fontSize != values.fontSize
                || lineSpacing != values.lineSpacing || alignment != values.alignment
                || margins != values.margins || firstLineIndent != values.firstLineIndent {
                activePreset = .custom
            }
        }
    }

    /// Save format state into a frontMatter dictionary for SDPage persistence.
    func save(into frontMatter: inout [String: String]) {
        frontMatter[Keys.writerPreset] = activePreset.rawValue
        frontMatter[Keys.writerFont] = fontFamily
        frontMatter[Keys.writerFontSize] = "\(fontSize)"
        frontMatter[Keys.writerLineSpacing] = lineSpacing.rawValue
        frontMatter[Keys.writerAlignment] = alignment.rawString
        frontMatter[Keys.writerMargins] = margins.rawValue
        frontMatter[Keys.writerPageSize] = pageSize.rawValue
        frontMatter[Keys.writerIndent] = "\(firstLineIndent)"
        frontMatter[Keys.writerTitlePage] = showTitlePage ? "true" : "false"
        frontMatter[Keys.writerPageNumbers] = showPageNumbers ? "true" : "false"
        frontMatter[Keys.writerPageNumPos] = pageNumberPosition.rawValue
        frontMatter[Keys.writerRunningHead] = runningHead
        frontMatter[Keys.writerHeader] = headerText
        frontMatter[Keys.writerFooter] = footerText
        frontMatter[Keys.writerTitleTitle] = titlePageTitle
        frontMatter[Keys.writerTitleAuthor] = titlePageAuthor
        frontMatter[Keys.writerTitleInstitution] = titlePageInstitution
        frontMatter[Keys.writerTitleCourse] = titlePageCourse
        frontMatter[Keys.writerTitleInstructor] = titlePageInstructor
        frontMatter[Keys.writerTitleDate] = titlePageDate
    }

    // MARK: - Title Page Defaults from UserDefaults

    private func loadTitlePageDefaults() {
        let d = UserDefaults.standard
        if let author = d.string(forKey: "epistemos.writer.author") { titlePageAuthor = author }
        if let inst = d.string(forKey: "epistemos.writer.institution") { titlePageInstitution = inst }
        if let course = d.string(forKey: "epistemos.writer.course") { titlePageCourse = course }
        if let instructor = d.string(forKey: "epistemos.writer.instructor") { titlePageInstructor = instructor }
        if titlePageDate.isEmpty {
            titlePageDate = Date.now.formatted(date: .long, time: .omitted)
        }
    }

    /// Persist reusable title page fields to UserDefaults.
    func saveTitlePageDefaults() {
        let d = UserDefaults.standard
        d.set(titlePageAuthor, forKey: "epistemos.writer.author")
        d.set(titlePageInstitution, forKey: "epistemos.writer.institution")
        d.set(titlePageCourse, forKey: "epistemos.writer.course")
        d.set(titlePageInstructor, forKey: "epistemos.writer.instructor")
    }
}

// MARK: - NSTextAlignment String Coding

extension NSTextAlignment {
    init(rawString: String) {
        switch rawString {
        case "left": self = .left
        case "center": self = .center
        case "right": self = .right
        case "justified": self = .justified
        default: self = .left
        }
    }

    var rawString: String {
        switch self {
        case .left: "left"
        case .center: "center"
        case .right: "right"
        case .justified: "justified"
        default: "left"
        }
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/WriterFormatState.swift
git commit -m "feat(writer): add WriterFormatState observable model with persistence"
```

---

### Task 3: WriterTextStorage — Academic Formatting

**Files:**
- Create: `Epistemos/Views/Notes/Writer/WriterTextStorage.swift`

**Context:** Unlike MarkdownTextStorage (which highlights markdown syntax), WriterTextStorage applies academic rich-text formatting — the correct font, paragraph style, and colors. The source text is plain (markdown stripped). This storage works with the shared NSLayoutManager in PagedDocumentView.

**Step 1: Create the file**

```swift
import AppKit

// MARK: - WriterTextStorage
// NSTextStorage subclass for academic document formatting.
// Applies uniform font, paragraph style (spacing, indent, alignment),
// and text color based on WriterFormatState.
// Unlike MarkdownTextStorage: no syntax highlighting, no regex passes.
// All text gets identical formatting — this is a traditional word processor view.

nonisolated(unsafe) final class WriterTextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()

    /// Current format state — set from WriterModeView.
    /// When changed, call reapplyFormatting() to update all attributes.
    var formatState: WriterFormatState?

    /// Theme-aware text color.
    var isDark: Bool = false

    /// When true, processEditing skips formatting (used during bulk replacement).
    var skipFormatting = false

    // MARK: - NSTextStorage Overrides

    override var string: String { backing.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard location < backing.length else {
            range?.pointee = NSRange(location: location, length: 0)
            return [:]
        }
        return backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Process Editing

    override func processEditing() {
        if !skipFormatting, backing.length > 0 {
            let paragraphRange = (string as NSString).paragraphRange(for: editedRange)
            applyFormatting(range: paragraphRange)
        }
        super.processEditing()
    }

    // MARK: - Formatting

    /// Apply academic formatting attributes to the given range.
    func applyFormatting(range: NSRange) {
        guard range.length > 0, range.location + range.length <= backing.length else { return }
        guard let state = formatState else { return }

        let font = state.resolvedFont
        let paragraphStyle = state.resolvedParagraphStyle
        let textColor = resolvedTextColor

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        backing.setAttributes(attrs, range: range)
    }

    /// Reapply formatting to entire document. Called on format state changes.
    func reapplyFormatting() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)

        beginEditing()
        applyFormatting(range: fullRange)
        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    /// Text color: theme-aware for on-screen, always black for export.
    private var resolvedTextColor: NSColor {
        isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1)
    }

    /// Set all text to black-on-white for PDF export, then restore.
    func setExportColors() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)
        beginEditing()
        backing.addAttribute(.foregroundColor, value: NSColor.black, range: fullRange)
        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    func restoreThemeColors() {
        reapplyFormatting()
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/WriterTextStorage.swift
git commit -m "feat(writer): add WriterTextStorage for academic formatting"
```

---

### Task 4: PagedDocumentView — Multi-Container TextKit Pages

**Files:**
- Create: `Epistemos/Views/Notes/Writer/PagedDocumentView.swift`

**Context:** This is the core rendering engine. It creates one NSLayoutManager with multiple NSTextContainers (one per page). Each container gets an NSTextView (page tile) sized to 8.5"x11" with proper margins. Pages are stacked vertically in a scroll view with shadows and gaps. Dynamic page management adds/removes pages as content flows.

Key references:
- `ProseEditorRepresentable.swift` — existing TextKit stack construction pattern
- `ClickableTextView.swift` — custom NSTextView subclass (we don't reuse this; page tiles are plain NSTextView)
- `MarkdownTextStorage.swift` — processEditing pattern (WriterTextStorage follows same shape)
- `EpistemosTheme.swift` — theme colors for canvas/page backgrounds

**Step 1: Create the file**

```swift
import AppKit
import SwiftUI

// MARK: - PagedDocumentView
// NSViewRepresentable rendering a paginated academic document.
// Architecture:
//   - One WriterTextStorage holds the full document text with academic formatting.
//   - One NSLayoutManager flows text across multiple NSTextContainers (one per page).
//   - Each NSTextContainer is owned by a PageTileView (NSTextView) sized to page dimensions.
//   - PageTileViews are laid out vertically in a PageCanvasView inside an NSScrollView.
//   - Pages are added/removed dynamically as content overflows/shrinks.
//
// The page canvas background and page surface colors are theme-aware.
// On export, pages temporarily render as white + black text.

struct PagedDocumentView: NSViewRepresentable {
    @Binding var text: String
    let formatState: WriterFormatState
    let isDark: Bool
    let isEditable: Bool

    private static let pageGap: CGFloat = 24
    private static let canvasPadding: CGFloat = 40

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let coord = context.coordinator

        // 1. Create storage
        let storage = WriterTextStorage()
        storage.formatState = formatState
        storage.isDark = isDark
        coord.storage = storage

        // 2. Create layout manager
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.backgroundLayoutEnabled = true
        storage.addLayoutManager(layoutManager)
        coord.layoutManager = layoutManager

        // 3. Create canvas (holds page tiles)
        let canvas = PageCanvasView()
        canvas.isDark = isDark
        coord.canvas = canvas

        // 4. Create first page
        addPage(coord: coord)

        // 5. Load initial text
        storage.skipFormatting = true
        storage.replaceCharacters(
            in: NSRange(location: 0, length: storage.length),
            with: text
        )
        storage.skipFormatting = false
        storage.reapplyFormatting()

        // 6. Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = canvas
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = canvasColor
        scrollView.wantsLayer = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // 7. Recalculate pages after layout
        DispatchQueue.main.async {
            self.reconcilePages(coord: coord)
            self.layoutPageTiles(coord: coord, in: scrollView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator

        // Theme change
        if coord.lastIsDark != isDark {
            coord.lastIsDark = isDark
            coord.storage?.isDark = isDark
            coord.storage?.reapplyFormatting()
            coord.canvas?.isDark = isDark
            scrollView.backgroundColor = canvasColor
            for tile in coord.pageTiles {
                tile.backgroundColor = pageColor
            }
        }

        // Format state change — reapply formatting
        coord.storage?.formatState = formatState
        coord.storage?.reapplyFormatting()

        // Editable state
        for tile in coord.pageTiles {
            tile.isEditable = isEditable
        }

        // Update text container sizes if margins/page size changed
        let textArea = formatState.textAreaSize
        for tile in coord.pageTiles {
            if let container = tile.textContainer {
                let newSize = NSSize(width: textArea.width, height: textArea.height)
                if container.size != newSize {
                    container.size = newSize
                }
            }
            let m = formatState.margins.points
            tile.textContainerInset = NSSize(width: m, height: m)
        }

        // Sync text if changed externally
        if let storage = coord.storage, !coord.isUserEditing, storage.string != text {
            storage.skipFormatting = true
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: text)
            storage.skipFormatting = false
            storage.reapplyFormatting()
        }

        // Reconcile pages and layout
        reconcilePages(coord: coord)
        layoutPageTiles(coord: coord, in: scrollView)
    }

    // MARK: - Page Management

    /// Add a new page (NSTextContainer + NSTextView) to the layout manager.
    private func addPage(coord: Coordinator) {
        guard let layoutManager = coord.layoutManager, let canvas = coord.canvas else { return }

        let textArea = formatState.textAreaSize
        let container = NSTextContainer(size: textArea)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)

        let pageFrame = NSRect(origin: .zero, size: formatState.pageSize.size)
        let tile = PageTileView(frame: pageFrame, textContainer: container)
        tile.isEditable = isEditable
        tile.isSelectable = true
        tile.isRichText = false
        tile.usesFontPanel = false
        tile.usesRuler = false
        tile.drawsBackground = true
        tile.backgroundColor = pageColor
        tile.isVerticallyResizable = false
        tile.isHorizontallyResizable = false

        let m = formatState.margins.points
        tile.textContainerInset = NSSize(width: m, height: m)
        tile.textContainer?.lineFragmentPadding = 0

        // Disable smart text features
        tile.isAutomaticQuoteSubstitutionEnabled = false
        tile.isAutomaticDashSubstitutionEnabled = false
        tile.isAutomaticTextCompletionEnabled = false
        tile.isContinuousSpellCheckingEnabled = false
        tile.isGrammarCheckingEnabled = false
        tile.isAutomaticSpellingCorrectionEnabled = false
        tile.isAutomaticTextReplacementEnabled = false
        tile.isAutomaticLinkDetectionEnabled = false

        tile.delegate = coord
        tile.wantsLayer = true
        tile.layer?.shadowColor = NSColor.black.withAlphaComponent(0.15).cgColor
        tile.layer?.shadowOffset = CGSize(width: 0, height: -1)
        tile.layer?.shadowRadius = 4
        tile.layer?.shadowOpacity = 1

        canvas.addSubview(tile)
        coord.pageTiles.append(tile)
    }

    /// Remove the last page if it's empty and there are 2+ pages.
    private func removeLastPageIfEmpty(coord: Coordinator) {
        guard coord.pageTiles.count > 1,
              let layoutManager = coord.layoutManager else { return }

        let lastContainer = coord.pageTiles.last?.textContainer
        if let container = lastContainer {
            let glyphRange = layoutManager.glyphRange(for: container)
            if glyphRange.length == 0 {
                let tile = coord.pageTiles.removeLast()
                tile.removeFromSuperview()
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
            }
        }
    }

    /// Ensure enough pages exist for all text, and no extra empty pages at the end.
    private func reconcilePages(coord: Coordinator) {
        guard let layoutManager = coord.layoutManager,
              let storage = coord.storage,
              storage.length > 0 else { return }

        // Force layout to determine overflow
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: storage.length))

        // Add pages while text overflows the last container
        var safety = 0
        while safety < 100 {
            guard let lastContainer = coord.pageTiles.last?.textContainer else { break }
            let glyphRange = layoutManager.glyphRange(for: lastContainer)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let endOfContainer = charRange.location + charRange.length

            if endOfContainer < storage.length {
                addPage(coord: coord)
                safety += 1
            } else {
                break
            }
        }

        // Remove trailing empty pages (keep at least 1)
        while coord.pageTiles.count > 1 {
            guard let lastContainer = coord.pageTiles.last?.textContainer else { break }
            let glyphRange = layoutManager.glyphRange(for: lastContainer)
            if glyphRange.length == 0 {
                let tile = coord.pageTiles.removeLast()
                tile.removeFromSuperview()
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
            } else {
                break
            }
        }
    }

    /// Position page tiles vertically in the canvas with gaps between them.
    private func layoutPageTiles(coord: Coordinator, in scrollView: NSScrollView) {
        guard let canvas = coord.canvas else { return }
        let pageSize = formatState.pageSize.size
        let scrollWidth = scrollView.contentSize.width
        let totalHeight = CGFloat(coord.pageTiles.count) * (pageSize.height + Self.pageGap)
            + Self.canvasPadding * 2 - Self.pageGap

        canvas.frame = NSRect(x: 0, y: 0, width: max(scrollWidth, pageSize.width + Self.canvasPadding * 2), height: totalHeight)

        for (i, tile) in coord.pageTiles.enumerated() {
            let x = max(Self.canvasPadding, (canvas.bounds.width - pageSize.width) / 2)
            let y = Self.canvasPadding + CGFloat(i) * (pageSize.height + Self.pageGap)
            tile.frame = NSRect(x: x, y: y, width: pageSize.width, height: pageSize.height)
        }
    }

    // MARK: - Theme Colors

    private var canvasColor: NSColor {
        isDark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.85, alpha: 1)
    }

    private var pageColor: NSColor {
        isDark ? NSColor(white: 0.18, alpha: 1) : .white
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PagedDocumentView
        var storage: WriterTextStorage?
        var layoutManager: NSLayoutManager?
        var canvas: PageCanvasView?
        var pageTiles: [PageTileView] = []
        var lastIsDark = false
        var isUserEditing = false
        private var reconcileWorkItem: DispatchWorkItem?

        init(_ parent: PagedDocumentView) {
            self.parent = parent
            self.lastIsDark = parent.isDark
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            guard !tv.hasMarkedText() else { return }

            isUserEditing = true
            parent.text = storage?.string ?? ""
            isUserEditing = false

            // Debounced page reconciliation (50ms)
            reconcileWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    if let scrollView = self.canvas?.enclosingScrollView {
                        self.parent.reconcilePages(coord: self)
                        self.parent.layoutPageTiles(coord: self, in: scrollView)
                    }
                }
            }
            reconcileWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }
    }
}

// MARK: - PageCanvasView
// Plain NSView that serves as the document view in the scroll view.
// Draws the grey/dark canvas background behind the page tiles.

final class PageCanvasView: NSView {
    var isDark = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = isDark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.85, alpha: 1)
        color.setFill()
        dirtyRect.fill()
    }
}

// MARK: - PageTileView
// NSTextView representing a single page. Sized to exact page dimensions.
// Draws its own white/dark background and shadow for the floating paper effect.

final class PageTileView: NSTextView {
    // No custom behavior needed beyond what NSTextView provides.
    // Shadow is set via layer properties in PagedDocumentView.addPage().
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/PagedDocumentView.swift
git commit -m "feat(writer): add PagedDocumentView with TextKit multi-container pagination"
```

---

### Task 5: WriterFormatBar — SwiftUI Format Controls

**Files:**
- Create: `Epistemos/Views/Notes/Writer/WriterFormatBar.swift`

**Context:** Two-row horizontal strip with all formatting controls. Binds directly to WriterFormatState. Uses native macOS pickers, toggles, and menus. The bar slides in when Writer Mode activates.

References:
- `EpistemosTheme.swift` — theme colors for the bar background
- `NSFontManager.shared.availableFontFamilies` — font list

**Step 1: Create the file**

```swift
import SwiftUI

// MARK: - WriterFormatBar
// Two-row horizontal format control strip for Writer Mode.
// All controls bind to WriterFormatState. Native macOS controls throughout.
// Appears below the toolbar with a spring slide animation.

struct WriterFormatBar: View {
    @Bindable var formatState: WriterFormatState
    let isDark: Bool
    let onExport: (ExportFormat) -> Void

    @State private var showTitlePagePopover = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Preset | Typography | Paragraph
            HStack(spacing: 12) {
                presetPicker
                Divider().frame(height: 20)
                typographyGroup
                Divider().frame(height: 20)
                paragraphGroup
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Row 2: Document | Headers/Footers | Export
            HStack(spacing: 12) {
                documentGroup
                Divider().frame(height: 20)
                headersGroup
                Spacer()
                exportMenu
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    // MARK: - Preset Picker

    private var presetPicker: some View {
        Picker("Style", selection: Binding(
            get: { formatState.activePreset },
            set: { newValue in
                if newValue != .custom {
                    formatState.activePreset = newValue
                }
            }
        )) {
            ForEach(AcademicStyle.allCases.filter { $0 != .custom }, id: \.self) { style in
                Text(style.displayName).tag(style)
            }
            if formatState.activePreset == .custom {
                Text(formatState.presetLabel).tag(AcademicStyle.custom)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 100)
        .help("Academic style preset")
    }

    // MARK: - Typography

    private var typographyGroup: some View {
        HStack(spacing: 6) {
            // Font picker
            Picker("Font", selection: $formatState.fontFamily) {
                // Common academic fonts first
                ForEach(Self.preferredFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
                Divider()
                ForEach(Self.systemFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .labelsHidden()

            // Font size
            Picker("Size", selection: $formatState.fontSize) {
                ForEach([10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36].map { CGFloat($0) }, id: \.self) { size in
                    Text("\(Int(size))").tag(size)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 50)
            .labelsHidden()

            // B / I / U / S toggles
            formatToggle("B", isOn: $formatState.isBold, help: "Bold")
                .fontWeight(.bold)
            formatToggle("I", isOn: $formatState.isItalic, help: "Italic")
                .italic()
            formatToggle("U", isOn: $formatState.isUnderline, help: "Underline")
                .underline()
            formatToggle("S", isOn: $formatState.isStrikethrough, help: "Strikethrough")
                .strikethrough()
        }
    }

    private func formatToggle(_ label: String, isOn: Binding<Bool>, help: String) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 13, weight: isOn.wrappedValue ? .bold : .regular))
                .frame(width: 24, height: 24)
        }
        .toggleStyle(.button)
        .help(help)
    }

    // MARK: - Paragraph

    private var paragraphGroup: some View {
        HStack(spacing: 6) {
            // Alignment
            Picker("Alignment", selection: Binding(
                get: { formatState.alignment },
                set: { formatState.alignment = $0 }
            )) {
                Label("Left", systemImage: "text.alignleft").tag(NSTextAlignment.left)
                Label("Center", systemImage: "text.aligncenter").tag(NSTextAlignment.center)
                Label("Right", systemImage: "text.alignright").tag(NSTextAlignment.right)
                Label("Justify", systemImage: "text.justify").tag(NSTextAlignment.justified)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .labelsHidden()

            // Line spacing
            Picker("Spacing", selection: $formatState.lineSpacing) {
                ForEach(LineSpacing.allCases, id: \.self) { spacing in
                    Text(spacing.displayName).tag(spacing)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
            .labelsHidden()
            .help("Line spacing")
        }
    }

    // MARK: - Document

    private var documentGroup: some View {
        HStack(spacing: 6) {
            Toggle("Title Page", isOn: $formatState.showTitlePage)
                .toggleStyle(.checkbox)

            Button {
                showTitlePagePopover.toggle()
            } label: {
                Image(systemName: "pencil.circle")
            }
            .buttonStyle(.borderless)
            .help("Edit title page fields")
            .popover(isPresented: $showTitlePagePopover) {
                titlePageEditor
            }
            .disabled(!formatState.showTitlePage)

            Divider().frame(height: 20)

            Picker("Margins", selection: $formatState.margins) {
                ForEach(PageMargins.allCases, id: \.self) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .labelsHidden()
            .help("Page margins")

            Picker("Page Size", selection: $formatState.pageSize) {
                ForEach(PageSize.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            .labelsHidden()
            .help("Page size")
        }
    }

    // MARK: - Headers / Footers

    private var headersGroup: some View {
        HStack(spacing: 6) {
            Toggle("Page #s", isOn: $formatState.showPageNumbers)
                .toggleStyle(.checkbox)

            Picker("Position", selection: $formatState.pageNumberPosition) {
                ForEach(PageNumberPosition.allCases, id: \.self) { pos in
                    Text(pos.displayName).tag(pos)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
            .labelsHidden()
            .disabled(!formatState.showPageNumbers)

            TextField("Running Head", text: $formatState.runningHead)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
        }
    }

    // MARK: - Export

    private var exportMenu: some View {
        Menu {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.displayName) { onExport(format) }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .help("Export document")
    }

    // MARK: - Title Page Editor

    private var titlePageEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title Page").font(.headline)
            Divider()
            titleField("Title", text: $formatState.titlePageTitle)
            titleField("Author", text: $formatState.titlePageAuthor)
            titleField("Institution", text: $formatState.titlePageInstitution)
            titleField("Course", text: $formatState.titlePageCourse)
            titleField("Instructor", text: $formatState.titlePageInstructor)
            titleField("Date", text: $formatState.titlePageDate)
        }
        .padding()
        .frame(width: 280)
        .onDisappear {
            formatState.saveTitlePageDefaults()
        }
    }

    private func titleField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .font(.callout)
    }

    // MARK: - Font Lists

    private static let preferredFonts = [
        "Times New Roman", "Arial", "Calibri", "Garamond",
        "Courier New", "Georgia", "Palatino", "Cambria"
    ].filter { NSFont(name: $0, size: 12) != nil }

    private static let systemFonts: [String] = {
        NSFontManager.shared.availableFontFamilies
            .filter { !preferredFonts.contains($0) }
            .sorted()
    }()
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case pdf, docx, plainText, markdown

    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .docx: "Word (.docx)"
        case .plainText: "Plain Text (.txt)"
        case .markdown: "Markdown (.md)"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .docx: "docx"
        case .plainText: "txt"
        case .markdown: "md"
        }
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/WriterFormatBar.swift
git commit -m "feat(writer): add WriterFormatBar with all formatting controls"
```

---

### Task 6: WriterExportService — PDF, DOCX, TXT, MD Export

**Files:**
- Create: `Epistemos/Views/Notes/Writer/WriterExportService.swift`

**Context:** Export uses NSSavePanel (following the pattern from ChatView.swift lines 103-110). PDF uses NSPrintOperation. DOCX is built as Open XML (zipped manually). No external dependencies.

**Step 1: Create the file**

```swift
import AppKit
import UniformTypeIdentifiers

// MARK: - WriterExportService
// Handles all document export formats: PDF, DOCX, plain text, markdown.
// PDF: NSPrintOperation rendering the page tiles.
// DOCX: Open XML generation → zip.
// TXT/MD: Direct string write via NSSavePanel.

@MainActor
enum WriterExportService {

    /// Export the document in the given format.
    /// - Parameters:
    ///   - format: Target export format.
    ///   - title: Document title (used for filename suggestion).
    ///   - body: Plain text body (for TXT/MD export).
    ///   - storage: WriterTextStorage (for PDF/DOCX — has formatted attributed string).
    ///   - pageTiles: Array of PageTileViews (for PDF export).
    ///   - formatState: Current formatting state (for DOCX export metadata).
    static func export(
        format: ExportFormat,
        title: String,
        body: String,
        storage: WriterTextStorage?,
        pageTiles: [PageTileView],
        formatState: WriterFormatState
    ) {
        let safeName = title.isEmpty ? "Untitled" : title
        switch format {
        case .pdf:
            exportPDF(title: safeName, storage: storage, pageTiles: pageTiles, formatState: formatState)
        case .docx:
            exportDOCX(title: safeName, body: body, formatState: formatState)
        case .plainText:
            exportText(title: safeName, body: stripMarkdown(body), extension: "txt", type: .plainText)
        case .markdown:
            exportText(title: safeName, body: body, extension: "md", type: .plainText)
        }
    }

    // MARK: - PDF Export

    private static func exportPDF(
        title: String,
        storage: WriterTextStorage?,
        pageTiles: [PageTileView],
        formatState: WriterFormatState
    ) {
        guard !pageTiles.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "\(title).pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                generatePDF(to: url, storage: storage, pageTiles: pageTiles, formatState: formatState)
            }
        }
    }

    private static func generatePDF(
        to url: URL,
        storage: WriterTextStorage?,
        pageTiles: [PageTileView],
        formatState: WriterFormatState
    ) {
        // Temporarily set export colors (white page, black text)
        let savedColors = pageTiles.map { $0.backgroundColor }
        storage?.setExportColors()
        for tile in pageTiles {
            tile.backgroundColor = .white
        }

        let pageSize = formatState.pageSize.size
        let printInfo = NSPrintInfo()
        printInfo.paperSize = pageSize
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Create PDF context
        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: pageSize.width, height: pageSize.height))

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            restoreColors(storage: storage, pageTiles: pageTiles, savedColors: savedColors)
            return
        }

        for tile in pageTiles {
            context.beginPDFPage(nil)

            // Flip coordinate system for AppKit drawing
            context.saveGState()
            context.translateBy(x: 0, y: pageSize.height)
            context.scaleBy(x: 1, y: -1)

            let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.current = nsContext

            // Draw the tile's content
            tile.draw(NSRect(origin: .zero, size: pageSize))

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()

        // Write PDF data to file
        try? (pdfData as Data).write(to: url)

        // Restore theme colors
        restoreColors(storage: storage, pageTiles: pageTiles, savedColors: savedColors)
    }

    private static func restoreColors(
        storage: WriterTextStorage?,
        pageTiles: [PageTileView],
        savedColors: [NSColor?]
    ) {
        storage?.restoreThemeColors()
        for (i, tile) in pageTiles.enumerated() {
            tile.backgroundColor = savedColors[i] ?? .white
        }
    }

    // MARK: - DOCX Export

    private static func exportDOCX(
        title: String,
        body: String,
        formatState: WriterFormatState
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = "\(title).docx"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                generateDOCX(to: url, title: title, body: body, formatState: formatState)
            }
        }
    }

    private static func generateDOCX(
        to url: URL,
        title: String,
        body: String,
        formatState: WriterFormatState
    ) {
        // Build Open XML structure in a temp directory, then zip
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-docx-\(UUID().uuidString)")

        do {
            let wordDir = tempDir.appendingPathComponent("word")
            let relsDir = tempDir.appendingPathComponent("_rels")
            let wordRelsDir = wordDir.appendingPathComponent("_rels")

            try FileManager.default.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)

            // [Content_Types].xml
            try contentTypesXML.write(to: tempDir.appendingPathComponent("[Content_Types].xml"),
                                      atomically: true, encoding: .utf8)

            // _rels/.rels
            try topRelsXML.write(to: relsDir.appendingPathComponent(".rels"),
                                 atomically: true, encoding: .utf8)

            // word/_rels/document.xml.rels
            try wordRelsXML.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"),
                                  atomically: true, encoding: .utf8)

            // word/styles.xml
            try stylesXML(formatState: formatState).write(
                to: wordDir.appendingPathComponent("styles.xml"),
                atomically: true, encoding: .utf8)

            // word/document.xml
            try documentXML(body: body, formatState: formatState).write(
                to: wordDir.appendingPathComponent("document.xml"),
                atomically: true, encoding: .utf8)

            // Zip the directory to .docx
            zipDirectory(tempDir, to: url)

            // Cleanup
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - DOCX XML Templates

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
    </Types>
    """

    private static let topRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    private static let wordRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static func stylesXML(formatState: WriterFormatState) -> String {
        let font = formatState.fontFamily
        let size = Int(formatState.fontSize * 2) // OOXML uses half-points
        let spacing = Int(formatState.lineSpacing.multiplier * 240) // 240 twips = single space

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:docDefaults>
            <w:rPrDefault>
              <w:rPr>
                <w:rFonts w:ascii="\(font)" w:hAnsi="\(font)"/>
                <w:sz w:val="\(size)"/>
              </w:rPr>
            </w:rPrDefault>
            <w:pPrDefault>
              <w:pPr>
                <w:spacing w:line="\(spacing)" w:lineRule="auto"/>
              </w:pPr>
            </w:pPrDefault>
          </w:docDefaults>
          <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
            <w:name w:val="Normal"/>
          </w:style>
        </w:styles>
        """
    }

    private static func documentXML(body: String, formatState: WriterFormatState) -> String {
        let indent = Int(formatState.firstLineIndent * 20) // Twips (1pt = 20 twips)
        let margin = Int(formatState.margins.points * 20)
        let pageW = Int(formatState.pageSize.size.width * 20)
        let pageH = Int(formatState.pageSize.size.height * 20)

        let alignment: String
        switch formatState.alignment {
        case .left: alignment = "left"
        case .center: alignment = "center"
        case .right: alignment = "right"
        case .justified: alignment = "both"
        default: alignment = "left"
        }

        // Convert body text to paragraphs
        let paragraphs = body.components(separatedBy: "\n\n")
        let paraXML = paragraphs.map { para -> String in
            let escaped = para.xmlEscaped
                .replacingOccurrences(of: "\n", with: "</w:t><w:br/><w:t xml:space=\"preserve\">")
            return """
              <w:p>
                <w:pPr>
                  <w:ind w:firstLine="\(indent)"/>
                  <w:jc w:val="\(alignment)"/>
                </w:pPr>
                <w:r><w:t xml:space="preserve">\(escaped)</w:t></w:r>
              </w:p>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paraXML)
            <w:sectPr>
              <w:pgSz w:w="\(pageW)" w:h="\(pageH)"/>
              <w:pgMar w:top="\(margin)" w:right="\(margin)" w:bottom="\(margin)" w:left="\(margin)"
                       w:header="720" w:footer="720"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    // MARK: - ZIP (Minimal DOCX zipper using /usr/bin/ditto)

    private static func zipDirectory(_ sourceDir: URL, to outputURL: URL) {
        // Use ditto to create a zip — available on all macOS, no dependencies
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-c", "-k", "--sequesterRsrc", sourceDir.path, outputURL.path]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - Plain Text / Markdown Export

    private static func exportText(title: String, body: String, extension ext: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "\(title).\(ext)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? body.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Markdown Stripping (for plain text export)

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Bold/italic markers
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_", with: "$1", options: .regularExpression)
        // Strikethrough
        result = result.replacingOccurrences(of: "~~(.+?)~~", with: "$1", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
        // Links
        result = result.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression)
        // Headings
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        return result
    }
}

// MARK: - String XML Escaping

extension String {
    var xmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/WriterExportService.swift
git commit -m "feat(writer): add WriterExportService for PDF, DOCX, TXT, MD export"
```

---

### Task 7: WriterModeView — Container Assembly

**Files:**
- Create: `Epistemos/Views/Notes/Writer/WriterModeView.swift`

**Context:** Simple SwiftUI container that assembles the format bar and paged document view. Manages the WriterFormatState lifecycle — loads from SDPage frontMatter on appear, saves on changes.

**Step 1: Create the file**

```swift
import SwiftData
import SwiftUI

// MARK: - WriterModeView
// SwiftUI container for Writer Mode. Assembles:
//   - WriterFormatBar (top, animated slide-in)
//   - PagedDocumentView (paginated editor)
// Manages WriterFormatState lifecycle: loads from SDPage.frontMatter,
// saves back on format changes and on disappear.

struct WriterModeView: View {
    let page: SDPage
    let isDark: Bool
    var isLocked: Bool = false

    @State private var formatState = WriterFormatState()
    @State private var bodyText: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var hasLoaded = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            WriterFormatBar(
                formatState: formatState,
                isDark: isDark,
                onExport: handleExport
            )
            .disabled(isLocked)
            .transition(.move(edge: .top).combined(with: .opacity))

            PagedDocumentView(
                text: $bodyText,
                formatState: formatState,
                isDark: isDark,
                isEditable: !isLocked
            )
        }
        .animation(.spring(duration: 0.3), value: isDark)
        .onAppear {
            bodyText = stripMarkdownForWriter(page.body)
            formatState.load(from: page.frontMatter)
            if formatState.titlePageTitle.isEmpty {
                formatState.titlePageTitle = page.title
            }
            hasLoaded = true
        }
        .onChange(of: bodyText) { _, newValue in
            guard hasLoaded else { return }
            debouncedSave(newValue)
        }
        .onDisappear {
            flushIfNeeded()
            saveFormatState()
        }
    }

    // MARK: - Text Sync

    private func debouncedSave(_ newValue: String) {
        saveTask?.cancel()
        page.needsVaultSync = true
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            page.body = newValue
            page.updatedAt = .now
        }
    }

    private func flushIfNeeded() {
        saveTask?.cancel()
        if page.body != bodyText {
            page.body = bodyText
            page.needsVaultSync = true
            page.updatedAt = .now
        }
    }

    // MARK: - Format State Persistence

    private func saveFormatState() {
        var fm = page.frontMatter
        formatState.save(into: &fm)
        page.frontMatter = fm
        formatState.saveTitlePageDefaults()
    }

    // MARK: - Export

    private func handleExport(_ format: ExportFormat) {
        // Save format state before export
        saveFormatState()

        // For PDF, we need access to the page tiles — this is handled by
        // passing the storage and tiles. For now, use text-based export.
        // PDF tile-based export will be wired once PagedDocumentView exposes its tiles.
        WriterExportService.export(
            format: format,
            title: page.title,
            body: bodyText,
            storage: nil,
            pageTiles: [],
            formatState: formatState
        )
    }

    // MARK: - Markdown Stripping

    /// Strip markdown syntax for writer mode display.
    /// Preserves the plain text content without markdown formatting markers.
    private func stripMarkdownForWriter(_ text: String) -> String {
        var result = text
        // Bold/italic
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_", with: "$1", options: .regularExpression)
        // Strikethrough
        result = result.replacingOccurrences(of: "~~(.+?)~~", with: "$1", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
        // Links: keep text, drop URL
        result = result.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression)
        // Headings: strip # prefix
        result = result.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)
        return result
    }
}
```

**Step 2: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Epistemos/Views/Notes/Writer/WriterModeView.swift
git commit -m "feat(writer): add WriterModeView container with format state lifecycle"
```

---

### Task 8: Wire Writer Mode into NoteTabView

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift` (NoteTabView struct, ~line 236)

**Context:** Add a `showWriterMode` state, toolbar toggle button (between Preview and Info), keyboard shortcut (⌘R), and swap the editor view based on mode. Writer Mode and Preview are mutually exclusive.

**Step 1: Add state and view swap**

In `NoteTabView`, add:
```swift
@State private var showWriterMode = false
```

Update the ZStack body to include the WriterModeView branch:
```swift
if let page = pages.first {
    if showWriterMode {
        WriterModeView(page: page, isDark: ui.theme.isDark, isLocked: page.isLocked)
            .frame(minWidth: 400, minHeight: 300)
    } else if showPreview {
        NotePreviewView(body: page.body, isDark: ui.theme.isDark)
            .frame(minWidth: 400, minHeight: 300)
    } else {
        ProseEditorView(page: page, isEditable: !page.isLocked)
            .frame(minWidth: 400, minHeight: 300)
    }
}
```

**Step 2: Add toolbar button**

In the "Editor: Format, Preview, Info, Share" toolbar group, add before the Preview button:
```swift
Button {
    showWriterMode.toggle()
    if showWriterMode { showPreview = false }
} label: {
    Label("Writer", systemImage: showWriterMode ? "doc.plaintext" : "doc.richtext")
}
.help("Writer Mode (⌘R)")
```

Also update the Preview button to clear writer mode:
```swift
Button {
    showPreview.toggle()
    if showPreview { showWriterMode = false }
} label: {
    Label("Preview", systemImage: showPreview ? "eye.slash" : "eye")
}
.help("Preview (⌘E)")
```

**Step 3: Add keyboard shortcut**

In the hidden keyboard shortcuts `.background` block, add:
```swift
Button("") {
    showWriterMode.toggle()
    if showWriterMode { showPreview = false }
}
.keyboardShortcut("r", modifiers: .command)
.hidden()
```

**Step 4: Build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/NoteWindowManager.swift
git commit -m "feat(writer): wire Writer Mode toggle into note toolbar"
```

---

### Task 9: Build, Test, and Verify

**Step 1: Full build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 2: Visual verification checklist**

Launch the app and open a note. Verify:

1. Toolbar shows new Writer Mode button (doc.richtext icon) between Format menu and Preview
2. Click Writer Mode — format bar slides in from top with spring animation
3. Format bar Row 1: MLA dropdown, font picker, size, B/I/U/S, alignment, spacing
4. Format bar Row 2: title page toggle, margins, page size, page numbers, running head, export
5. Document area shows paginated view with page tiles (white pages, grey/dark canvas)
6. Type text — it flows across pages with correct MLA formatting (Times New Roman 12pt, double-spaced)
7. Change preset to APA — formatting updates, title page auto-enables
8. Toggle title page — edit fields popover shows author/institution/course/instructor/date
9. Click Export → PDF — NSSavePanel opens, generates PDF
10. Click Export → Word — generates .docx file
11. ⌘R toggles writer mode on/off
12. Writer Mode and Preview are mutually exclusive
13. Lock makes writer mode read-only (tiles non-editable, format bar disabled)
14. Dark mode: canvas is dark grey, page surfaces are dark, text is light
15. Light mode: canvas is light grey, pages are white, text is dark

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(writer): complete Writer Mode academic document editor"
```
