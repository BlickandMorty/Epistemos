import AppKit
import Observation

// MARK: - NSTextAlignment + String Serialization

extension NSTextAlignment {
    init(rawString: String) {
        switch rawString.lowercased() {
        case "left":      self = .left
        case "center":    self = .center
        case "right":     self = .right
        case "justified": self = .justified
        default:          self = .left
        }
    }

    var rawString: String {
        switch self {
        case .left:      "left"
        case .center:    "center"
        case .right:     "right"
        case .justified: "justified"
        default:         "left"
        }
    }
}

// MARK: - WriterFormatState

/// Observable format model holding all academic formatting parameters.
/// Drives WriterFormatBar, WriterTextStorage, PagedDocumentView, and WriterModeView.
@MainActor @Observable
final class WriterFormatState {

    // MARK: - Preset

    var activePreset: AcademicStyle = .mla {
        didSet {
            guard !isApplyingPreset else { return }
            if activePreset != .custom {
                applyPreset(activePreset)
            }
        }
    }

    /// The last non-custom preset that was active. Used for labelling "Custom (based on X)".
    var basePreset: AcademicStyle = .mla

    // MARK: - Typography

    var fontFamily: String = "Times New Roman" {
        didSet { markCustom() }
    }

    var fontSize: CGFloat = 12 {
        didSet { markCustom() }
    }

    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false

    // MARK: - Paragraph

    var alignment: NSTextAlignment = .left {
        didSet { markCustom() }
    }

    var lineSpacing: LineSpacing = .double {
        didSet { markCustom() }
    }

    var firstLineIndent: CGFloat = 36 {
        didSet { markCustom() }
    }

    var paragraphSpacingBefore: CGFloat = 0 {
        didSet { markCustom() }
    }

    var paragraphSpacingAfter: CGFloat = 0 {
        didSet { markCustom() }
    }

    // MARK: - Document

    var showTitlePage: Bool = false {
        didSet { markCustom() }
    }

    var margins: PageMargins = .normal {
        didSet { markCustom() }
    }

    var pageSize: PageSize = .letter {
        didSet { markCustom() }
    }

    /// Two-up "book spread" layout — pages shown in pairs side by side.
    var isSpreadView: Bool = false

    /// Zoom level for the document view (0.5 – 2.0, default 1.0).
    var zoomLevel: CGFloat = 1.0

    /// Show horizontal ruler above pages.
    var showRuler: Bool = false

    // MARK: - Headers / Footers

    var showPageNumbers: Bool = true {
        didSet { markCustom() }
    }

    var pageNumberPosition: PageNumberPosition = .topRight {
        didSet { markCustom() }
    }

    var runningHead: String = "" {
        didSet { markCustom() }
    }

    var headerText: String = "" {
        didSet { markCustom() }
    }

    var footerText: String = "" {
        didSet { markCustom() }
    }

    // MARK: - Title Page Fields

    var titlePageTitle: String = ""
    var titlePageAuthor: String = ""
    var titlePageInstitution: String = ""
    var titlePageCourse: String = ""
    var titlePageInstructor: String = ""
    var titlePageDate: String = ""

    // MARK: - Internal

    /// When true, `markCustom()` is suppressed so bulk preset application
    /// does not flip `activePreset` to `.custom`.
    private var isApplyingPreset = false

    // MARK: - Init

    init() {
        // Apply MLA defaults (the initial values above already match MLA,
        // but calling applyPreset ensures consistency).
        applyPreset(.mla)
    }

    // MARK: - Preset Application

    /// Bulk-sets all formatting values from the given academic style's preset.
    func applyPreset(_ style: AcademicStyle) {
        guard let values = style.presetValues else { return }

        isApplyingPreset = true
        defer { isApplyingPreset = false }

        fontFamily = values.fontName
        fontSize = values.fontSize
        lineSpacing = values.lineSpacing
        alignment = values.alignment
        margins = values.margins
        firstLineIndent = values.firstLineIndent
        showTitlePage = values.hasTitlePage
        showPageNumbers = values.hasPageNumbers
        pageNumberPosition = values.pageNumberPosition

        // Reset inline styles to defaults on preset change
        isBold = false
        isItalic = false
        isUnderline = false
        isStrikethrough = false

        // Reset paragraph spacing to defaults
        paragraphSpacingBefore = 0
        paragraphSpacingAfter = 0

        // Reset page size to letter
        pageSize = .letter

        // Reset header/footer text
        runningHead = ""
        headerText = ""
        footerText = ""

        activePreset = style
        basePreset = style
    }

    // MARK: - Custom Detection

    /// Flips `activePreset` to `.custom` when any individual value changes.
    /// Guarded by `isApplyingPreset` so bulk preset application does not trigger this.
    private func markCustom() {
        guard !isApplyingPreset else { return }
        if activePreset != .custom {
            basePreset = activePreset
            activePreset = .custom
        }
    }

    // MARK: - Computed: Resolved Font

    /// Builds an `NSFont` from the current fontFamily, fontSize, isBold, and isItalic.
    var resolvedFont: NSFont {
        var font = NSFont(name: fontFamily, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)

        let manager = NSFontManager.shared
        if isBold {
            font = manager.convert(font, toHaveTrait: .boldFontMask)
        }
        if isItalic {
            font = manager.convert(font, toHaveTrait: .italicFontMask)
        }

        return font
    }

    // MARK: - Computed: Resolved Paragraph Style

    /// Builds an `NSParagraphStyle` from alignment, line spacing, indent, and tab stops.
    var resolvedParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment

        // Line height: use the font's default line height times the spacing multiplier
        let font = resolvedFont
        let defaultLineHeight = font.ascender + abs(font.descender) + font.leading
        let desiredLineHeight = defaultLineHeight * lineSpacing.multiplier

        style.minimumLineHeight = desiredLineHeight
        style.maximumLineHeight = desiredLineHeight

        style.firstLineHeadIndent = firstLineIndent
        style.paragraphSpacingBefore = paragraphSpacingBefore
        style.paragraphSpacing = paragraphSpacingAfter

        // Tab stops at 0.5" (36 pt) intervals, up to 12 stops
        style.tabStops = (1...12).map { i in
            NSTextTab(textAlignment: .left, location: CGFloat(i) * 36)
        }

        return style
    }

    // MARK: - Computed: Text Area Size

    /// The usable text area after subtracting margins from the page size.
    var textAreaSize: NSSize {
        let page = pageSize.size
        let margin = margins.points
        return NSSize(
            width: max(page.width - margin * 2, 0),
            height: max(page.height - margin * 2, 0)
        )
    }

    // MARK: - Computed: Preset Label

    /// A user-facing label: "MLA", "APA", "Chicago", or "Custom (based on MLA)".
    var presetLabel: String {
        if activePreset == .custom {
            return "Custom (based on \(basePreset.displayName))"
        }
        return activePreset.displayName
    }

    // MARK: - Persistence: Front-Matter

    /// Front-matter key prefix for writer format state.
    private static let keyPrefix = "writer."

    /// Reads format state from an SDPage's frontMatter dictionary using "writer.*" keys.
    func load(from frontMatter: [String: String]) {
        isApplyingPreset = true
        defer { isApplyingPreset = false }

        if let v = frontMatter[Self.keyPrefix + "preset"],
           let style = AcademicStyle(rawValue: v) {
            if style != .custom, let values = style.presetValues {
                // Apply the preset values as base, then override with any custom keys
                fontFamily = values.fontName
                fontSize = values.fontSize
                lineSpacing = values.lineSpacing
                alignment = values.alignment
                margins = values.margins
                firstLineIndent = values.firstLineIndent
                showTitlePage = values.hasTitlePage
                showPageNumbers = values.hasPageNumbers
                pageNumberPosition = values.pageNumberPosition
            }
            activePreset = style
            if style != .custom {
                basePreset = style
            }
        }

        if let v = frontMatter[Self.keyPrefix + "basePreset"],
           let style = AcademicStyle(rawValue: v) {
            basePreset = style
        }

        // Typography
        if let v = frontMatter[Self.keyPrefix + "fontFamily"] {
            fontFamily = v
        }
        if let v = frontMatter[Self.keyPrefix + "fontSize"],
           let f = Double(v) {
            fontSize = CGFloat(f)
        }
        if let v = frontMatter[Self.keyPrefix + "isBold"] {
            isBold = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "isItalic"] {
            isItalic = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "isUnderline"] {
            isUnderline = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "isStrikethrough"] {
            isStrikethrough = v == "true"
        }

        // Paragraph
        if let v = frontMatter[Self.keyPrefix + "alignment"] {
            alignment = NSTextAlignment(rawString: v)
        }
        if let v = frontMatter[Self.keyPrefix + "lineSpacing"],
           let ls = LineSpacing(rawValue: v) {
            lineSpacing = ls
        }
        if let v = frontMatter[Self.keyPrefix + "firstLineIndent"],
           let f = Double(v) {
            firstLineIndent = CGFloat(f)
        }
        if let v = frontMatter[Self.keyPrefix + "paragraphSpacingBefore"],
           let f = Double(v) {
            paragraphSpacingBefore = CGFloat(f)
        }
        if let v = frontMatter[Self.keyPrefix + "paragraphSpacingAfter"],
           let f = Double(v) {
            paragraphSpacingAfter = CGFloat(f)
        }

        // Document
        if let v = frontMatter[Self.keyPrefix + "showTitlePage"] {
            showTitlePage = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "margins"],
           let m = PageMargins(rawValue: v) {
            margins = m
        }
        if let v = frontMatter[Self.keyPrefix + "pageSize"],
           let ps = PageSize(rawValue: v) {
            pageSize = ps
        }
        if let v = frontMatter[Self.keyPrefix + "isSpreadView"] {
            isSpreadView = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "zoomLevel"],
           let f = Double(v) {
            zoomLevel = max(0.5, min(2.0, CGFloat(f)))
        }
        if let v = frontMatter[Self.keyPrefix + "showRuler"] {
            showRuler = v == "true"
        }

        // Headers / Footers
        if let v = frontMatter[Self.keyPrefix + "showPageNumbers"] {
            showPageNumbers = v == "true"
        }
        if let v = frontMatter[Self.keyPrefix + "pageNumberPosition"],
           let p = PageNumberPosition(rawValue: v) {
            pageNumberPosition = p
        }
        if let v = frontMatter[Self.keyPrefix + "runningHead"] {
            runningHead = v
        }
        if let v = frontMatter[Self.keyPrefix + "headerText"] {
            headerText = v
        }
        if let v = frontMatter[Self.keyPrefix + "footerText"] {
            footerText = v
        }

        // Title Page Fields
        if let v = frontMatter[Self.keyPrefix + "titlePageTitle"] {
            titlePageTitle = v
        }
        if let v = frontMatter[Self.keyPrefix + "titlePageAuthor"] {
            titlePageAuthor = v
        }
        if let v = frontMatter[Self.keyPrefix + "titlePageInstitution"] {
            titlePageInstitution = v
        }
        if let v = frontMatter[Self.keyPrefix + "titlePageCourse"] {
            titlePageCourse = v
        }
        if let v = frontMatter[Self.keyPrefix + "titlePageInstructor"] {
            titlePageInstructor = v
        }
        if let v = frontMatter[Self.keyPrefix + "titlePageDate"] {
            titlePageDate = v
        }
    }

    /// Writes format state to an SDPage's frontMatter dictionary using "writer.*" keys.
    func save(into frontMatter: inout [String: String]) {
        frontMatter[Self.keyPrefix + "preset"] = activePreset.rawValue
        frontMatter[Self.keyPrefix + "basePreset"] = basePreset.rawValue

        // Typography
        frontMatter[Self.keyPrefix + "fontFamily"] = fontFamily
        frontMatter[Self.keyPrefix + "fontSize"] = String(Double(fontSize))
        frontMatter[Self.keyPrefix + "isBold"] = String(isBold)
        frontMatter[Self.keyPrefix + "isItalic"] = String(isItalic)
        frontMatter[Self.keyPrefix + "isUnderline"] = String(isUnderline)
        frontMatter[Self.keyPrefix + "isStrikethrough"] = String(isStrikethrough)

        // Paragraph
        frontMatter[Self.keyPrefix + "alignment"] = alignment.rawString
        frontMatter[Self.keyPrefix + "lineSpacing"] = lineSpacing.rawValue
        frontMatter[Self.keyPrefix + "firstLineIndent"] = String(Double(firstLineIndent))
        frontMatter[Self.keyPrefix + "paragraphSpacingBefore"] = String(Double(paragraphSpacingBefore))
        frontMatter[Self.keyPrefix + "paragraphSpacingAfter"] = String(Double(paragraphSpacingAfter))

        // Document
        frontMatter[Self.keyPrefix + "showTitlePage"] = String(showTitlePage)
        frontMatter[Self.keyPrefix + "margins"] = margins.rawValue
        frontMatter[Self.keyPrefix + "pageSize"] = pageSize.rawValue
        frontMatter[Self.keyPrefix + "isSpreadView"] = String(isSpreadView)
        frontMatter[Self.keyPrefix + "zoomLevel"] = String(Double(zoomLevel))
        frontMatter[Self.keyPrefix + "showRuler"] = String(showRuler)

        // Headers / Footers
        frontMatter[Self.keyPrefix + "showPageNumbers"] = String(showPageNumbers)
        frontMatter[Self.keyPrefix + "pageNumberPosition"] = pageNumberPosition.rawValue
        frontMatter[Self.keyPrefix + "runningHead"] = runningHead
        frontMatter[Self.keyPrefix + "headerText"] = headerText
        frontMatter[Self.keyPrefix + "footerText"] = footerText

        // Title Page Fields
        frontMatter[Self.keyPrefix + "titlePageTitle"] = titlePageTitle
        frontMatter[Self.keyPrefix + "titlePageAuthor"] = titlePageAuthor
        frontMatter[Self.keyPrefix + "titlePageInstitution"] = titlePageInstitution
        frontMatter[Self.keyPrefix + "titlePageCourse"] = titlePageCourse
        frontMatter[Self.keyPrefix + "titlePageInstructor"] = titlePageInstructor
        frontMatter[Self.keyPrefix + "titlePageDate"] = titlePageDate
    }

    // MARK: - Persistence: UserDefaults (Title Page Defaults)

    /// Reads author/institution/course/instructor from UserDefaults.
    func loadTitlePageDefaults() {
        let defaults = UserDefaults.standard
        if let v = defaults.string(forKey: "epistemos.writer.author"), !v.isEmpty {
            titlePageAuthor = v
        }
        if let v = defaults.string(forKey: "epistemos.writer.institution"), !v.isEmpty {
            titlePageInstitution = v
        }
        if let v = defaults.string(forKey: "epistemos.writer.course"), !v.isEmpty {
            titlePageCourse = v
        }
        if let v = defaults.string(forKey: "epistemos.writer.instructor"), !v.isEmpty {
            titlePageInstructor = v
        }
    }

    /// Writes author/institution/course/instructor to UserDefaults for reuse across documents.
    func saveTitlePageDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(titlePageAuthor, forKey: "epistemos.writer.author")
        defaults.set(titlePageInstitution, forKey: "epistemos.writer.institution")
        defaults.set(titlePageCourse, forKey: "epistemos.writer.course")
        defaults.set(titlePageInstructor, forKey: "epistemos.writer.instructor")
    }
}
