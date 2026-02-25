import AppKit

// MARK: - AcademicStyle

/// The four academic formatting presets available in Writer Mode.
/// `.custom` carries no preset — the user defines every property manually.
enum AcademicStyle: String, Codable, CaseIterable, Sendable {
    case mla
    case apa
    case chicago
    case custom

    var displayName: String {
        switch self {
        case .mla:      "MLA"
        case .apa:      "APA"
        case .chicago:  "Chicago"
        case .custom:   "Custom"
        }
    }
}

// MARK: - LineSpacing

enum LineSpacing: String, Codable, CaseIterable, Sendable {
    case single
    case onePointFive
    case double

    var displayName: String {
        switch self {
        case .single:       "Single"
        case .onePointFive: "1.5"
        case .double:       "Double"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .single:       1.0
        case .onePointFive: 1.5
        case .double:       2.0
        }
    }
}

// MARK: - PageMargins

enum PageMargins: String, Codable, CaseIterable, Sendable {
    case normal  // 72 pt  (1")
    case narrow  // 36 pt  (0.5")
    case wide    // 108 pt (1.5")

    var displayName: String {
        switch self {
        case .normal: "Normal (1\")"
        case .narrow: "Narrow (0.5\")"
        case .wide:   "Wide (1.5\")"
        }
    }

    var points: CGFloat {
        switch self {
        case .normal: 72
        case .narrow: 36
        case .wide:   108
        }
    }
}

// MARK: - PageSize

enum PageSize: String, Codable, CaseIterable, Sendable {
    case letter  // 612 × 792 pt (US Letter)
    case a4      // 595 × 842 pt (ISO A4)

    var displayName: String {
        switch self {
        case .letter: "US Letter"
        case .a4:     "A4"
        }
    }

    var size: NSSize {
        switch self {
        case .letter: NSSize(width: 612, height: 792)
        case .a4:     NSSize(width: 595, height: 842)
        }
    }
}

// MARK: - PageNumberPosition

enum PageNumberPosition: String, Codable, CaseIterable, Sendable {
    case topRight
    case topLeft
    case topCenter
    case bottomRight
    case bottomLeft
    case bottomCenter

    var displayName: String {
        switch self {
        case .topRight:     "Top Right"
        case .topLeft:      "Top Left"
        case .topCenter:    "Top Center"
        case .bottomRight:  "Bottom Right"
        case .bottomLeft:   "Bottom Left"
        case .bottomCenter: "Bottom Center"
        }
    }
}

// MARK: - AcademicPresetValues

/// A complete snapshot of every formatting parameter that a preset defines.
/// When `AcademicStyle.custom` is selected, `presetValues` returns `nil`
/// and the user controls each field individually.
struct AcademicPresetValues: Codable, Sendable, Equatable {

    // MARK: Running Head Style

    enum RunningHeadStyle: String, Codable, CaseIterable, Sendable {
        case lastNameAndPage
        case shortenedTitleCaps
        case none

        var displayName: String {
            switch self {
            case .lastNameAndPage:     "Last Name + Page #"
            case .shortenedTitleCaps:  "Shortened Title (CAPS)"
            case .none:                "None"
            }
        }
    }

    // MARK: Properties

    let fontName: String
    let fontSize: CGFloat
    let lineSpacing: LineSpacing
    let alignment: NSTextAlignment
    let margins: PageMargins
    let firstLineIndent: CGFloat   // in points
    let hasTitlePage: Bool
    let hasPageNumbers: Bool
    let pageNumberPosition: PageNumberPosition
    let runningHeadStyle: RunningHeadStyle
}

// MARK: - NSTextAlignment + Codable

/// `NSTextAlignment` is a raw-value type (`UInt`) but does not ship with
/// `Codable` conformance. We add it here so `AcademicPresetValues` can be
/// fully `Codable` without a custom implementation.
extension NSTextAlignment: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = NSTextAlignment(rawValue: rawValue) ?? .natural
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - AcademicStyle + Presets

extension AcademicStyle {

    /// Returns the canonical preset values for this style, or `nil` for `.custom`.
    var presetValues: AcademicPresetValues? {
        switch self {
        case .mla:
            AcademicPresetValues(
                fontName: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .left,
                margins: .normal,
                firstLineIndent: 36,  // 0.5"
                hasTitlePage: false,
                hasPageNumbers: true,
                pageNumberPosition: .topRight,
                runningHeadStyle: .lastNameAndPage
            )

        case .apa:
            AcademicPresetValues(
                fontName: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .left,
                margins: .normal,
                firstLineIndent: 36,  // 0.5"
                hasTitlePage: true,
                hasPageNumbers: true,
                pageNumberPosition: .topRight,
                runningHeadStyle: .shortenedTitleCaps
            )

        case .chicago:
            AcademicPresetValues(
                fontName: "Times New Roman",
                fontSize: 12,
                lineSpacing: .double,
                alignment: .justified,
                margins: .normal,
                firstLineIndent: 36,  // 0.5"
                hasTitlePage: true,
                hasPageNumbers: true,
                pageNumberPosition: .bottomCenter,
                runningHeadStyle: .none
            )

        case .custom:
            nil
        }
    }
}
