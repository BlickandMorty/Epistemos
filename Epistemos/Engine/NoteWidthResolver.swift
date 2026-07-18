import Foundation

nonisolated public enum NoteWidthMode: Sendable, Hashable {
    case normal
    case wide
    case custom(px: Int)

    public static let normalPixels = 720
    public static let defaultCustomPixels = 960
    public static let minimumCustomPixels = 560
    public static let maximumCustomPixels = 1600

    public init(customPixels: Int) {
        self = .custom(px: Self.clampedPixels(customPixels))
    }

    public init?(frontmatterValue: String?) {
        guard let frontmatterValue else { return nil }
        let cleaned = Self.clean(frontmatterValue)
        guard !cleaned.isEmpty else { return nil }

        switch cleaned {
        case "normal", "readable", "default":
            self = .normal
        case "wide", "full", "none":
            self = .wide
        default:
            let numeric = cleaned
                .replacingOccurrences(of: "custom:", with: "")
                .replacingOccurrences(of: "custom=", with: "")
                .replacingOccurrences(of: "px", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let pixels = Int(numeric) else { return nil }
            self = .custom(px: Self.clampedPixels(pixels))
        }
    }

    public var normalized: NoteWidthMode {
        switch self {
        case .normal, .wide:
            return self
        case .custom(let pixels):
            return .custom(px: Self.clampedPixels(pixels))
        }
    }

    public var cssMaxWidthValue: String {
        switch normalized {
        case .normal:
            return "\(Self.normalPixels)px"
        case .wide:
            return "none"
        case .custom(let pixels):
            return "\(pixels)px"
        }
    }

    public var frontmatterValue: String {
        switch normalized {
        case .normal:
            return "normal"
        case .wide:
            return "wide"
        case .custom(let pixels):
            return "\(pixels)px"
        }
    }

    public var displayTitle: String {
        switch normalized {
        case .normal:
            return "Normal"
        case .wide:
            return "Wide"
        case .custom(let pixels):
            return "\(pixels) px"
        }
    }

    public var customPixelsOrDefault: Int {
        switch normalized {
        case .custom(let pixels):
            return pixels
        default:
            return Self.defaultCustomPixels
        }
    }

    public static func clampedPixels(_ pixels: Int) -> Int {
        min(max(pixels, minimumCustomPixels), maximumCustomPixels)
    }

    private static func clean(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .lowercased()
    }
}

/// Pure presentation geometry shared by the native Epdoc, Prose, and Source
/// canvases. Width never participates in document serialization or editing.
nonisolated public enum EditorContentWidthPolicy {
    public static let minimumHorizontalInset: CGFloat = 60

    public static func readableWidth(
        availableWidth: CGFloat,
        mode: NoteWidthMode
    ) -> CGFloat {
        let usableWidth = max(0, availableWidth - (minimumHorizontalInset * 2))
        switch mode.normalized {
        case .normal:
            return min(CGFloat(NoteWidthMode.normalPixels), usableWidth)
        case .wide:
            return usableWidth
        case .custom(let pixels):
            return min(CGFloat(pixels), usableWidth)
        }
    }

    public static func horizontalInset(
        availableWidth: CGFloat,
        mode: NoteWidthMode
    ) -> CGFloat {
        let width = readableWidth(availableWidth: availableWidth, mode: mode)
        return max(minimumHorizontalInset, (availableWidth - width) / 2)
    }
}

@MainActor
public final class NoteWidthResolver {
    public static let defaultUserDefaultsKey = "epistemos.noteWidth.defaultMode"

    private var sessionModes: [String: NoteWidthMode] = [:]
    private let defaults: UserDefaults
    private let defaultKey: String

    public init(
        defaults: UserDefaults = FoundationSafety.runtimeUserDefaults,
        defaultKey: String = NoteWidthResolver.defaultUserDefaultsKey
    ) {
        self.defaults = defaults
        self.defaultKey = defaultKey
    }

    public func setSessionWidth(_ mode: NoteWidthMode, noteID: String) {
        sessionModes[noteID] = mode.normalized
    }

    public func clearSessionWidth(noteID: String) {
        sessionModes.removeValue(forKey: noteID)
    }

    public func resolve(noteID: String, frontmatterValue: String?) -> NoteWidthMode {
        if let session = sessionModes[noteID] {
            return session
        }
        if let parsed = NoteWidthMode(frontmatterValue: frontmatterValue) {
            return parsed
        }
        return settingsDefault
    }

    public var settingsDefault: NoteWidthMode {
        NoteWidthMode(frontmatterValue: defaults.string(forKey: defaultKey)) ?? .normal
    }

    public func setSettingsDefault(_ mode: NoteWidthMode) {
        defaults.set(mode.frontmatterValue, forKey: defaultKey)
    }

    /// Width is session presentation state. It never rewrites Markdown.
    public func setWidth(_ mode: NoteWidthMode, noteID: String, markdown: String) -> String? {
        _ = markdown
        setSessionWidth(mode, noteID: noteID)
        return nil
    }

    private struct FrontmatterBlock {
        let contentRange: Range<String.Index>
        let closingDelimiterStart: String.Index
        let lineEnding: String
    }

    private static func frontmatterBlock(in markdown: String) -> FrontmatterBlock? {
        var cursor = markdown.startIndex
        if markdown[cursor...].hasPrefix("\u{feff}") {
            cursor = markdown.index(after: cursor)
        }

        guard let opening = lineBounds(in: markdown, start: cursor),
              markerLine(in: markdown, bounds: opening) == "---" else {
            return nil
        }

        var lineStart = opening.nextLineStart
        while lineStart < markdown.endIndex {
            guard let bounds = lineBounds(in: markdown, start: lineStart) else { return nil }
            if markerLine(in: markdown, bounds: bounds) == "---" {
                return FrontmatterBlock(
                    contentRange: opening.nextLineStart..<lineStart,
                    closingDelimiterStart: lineStart,
                    lineEnding: opening.lineEnding.isEmpty ? "\n" : opening.lineEnding
                )
            }
            lineStart = bounds.nextLineStart
        }
        return nil
    }

    private struct LineBounds {
        let contentStart: String.Index
        let contentEnd: String.Index
        let nextLineStart: String.Index
        let lineEnding: String
    }

    private static func lineBounds(in text: String, start: String.Index) -> LineBounds? {
        guard start <= text.endIndex else { return nil }
        let scalars = text.unicodeScalars
        guard let scalarStart = start.samePosition(in: scalars) else { return nil }
        let newline = "\n".unicodeScalars.first!
        let carriageReturn = "\r".unicodeScalars.first!

        var index = scalarStart
        while index < scalars.endIndex {
            let scalar = scalars[index]
            if scalar == newline {
                guard let contentEnd = String.Index(index, within: text),
                      let nextLineStart = String.Index(scalars.index(after: index), within: text) else {
                    return nil
                }
                return LineBounds(
                    contentStart: start,
                    contentEnd: contentEnd,
                    nextLineStart: nextLineStart,
                    lineEnding: "\n"
                )
            }
            if scalar == carriageReturn {
                let afterReturn = scalars.index(after: index)
                guard let contentEnd = String.Index(index, within: text) else { return nil }
                if afterReturn < scalars.endIndex, scalars[afterReturn] == newline {
                    guard let nextLineStart = String.Index(scalars.index(after: afterReturn), within: text) else {
                        return nil
                    }
                    return LineBounds(
                        contentStart: start,
                        contentEnd: contentEnd,
                        nextLineStart: nextLineStart,
                        lineEnding: "\r\n"
                    )
                }
                guard let nextLineStart = String.Index(afterReturn, within: text) else { return nil }
                return LineBounds(
                    contentStart: start,
                    contentEnd: contentEnd,
                    nextLineStart: nextLineStart,
                    lineEnding: "\r"
                )
            }
            index = scalars.index(after: index)
        }
        return LineBounds(
            contentStart: start,
            contentEnd: text.endIndex,
            nextLineStart: text.endIndex,
            lineEnding: ""
        )
    }

    private static func markerLine(in text: String, bounds: LineBounds) -> String {
        String(text[bounds.contentStart..<bounds.contentEnd])
            .trimmingCharacters(in: .whitespaces)
    }

    private static func widthLineRange(
        in markdown: String,
        contentRange: Range<String.Index>
    ) -> Range<String.Index>? {
        var lineStart = contentRange.lowerBound
        while lineStart < contentRange.upperBound {
            guard let bounds = lineBounds(in: markdown, start: lineStart) else { return nil }
            let line = String(markdown[lineStart..<bounds.contentEnd])
            if isWidthLine(line) {
                return lineStart..<bounds.nextLineStart
            }
            lineStart = bounds.nextLineStart
        }
        return nil
    }

    private static func isWidthLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("_width:")
    }
}
