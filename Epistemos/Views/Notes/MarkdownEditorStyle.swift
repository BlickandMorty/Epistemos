import AppKit

enum MarkdownBlockChromeKind: String, Sendable {
    case codeBlock
    case quote
    case callout
}

enum MarkdownEditorStyle {
    nonisolated static let noteBaseFontSize: CGFloat = 15
    nonisolated static let blockChromeKindAttribute = NSAttributedString.Key("EpistemosBlockChromeKind")
    nonisolated static let blockChromeAccentAttribute = NSAttributedString.Key("EpistemosBlockChromeAccent")
    nonisolated static let blockChromeFillAttribute = NSAttributedString.Key("EpistemosBlockChromeFill")

    enum TableLineRole {
        case first
        case continuation
        case separator
    }

    nonisolated static let leadingH1SpacingBefore: CGFloat = 36
    nonisolated static let sectionH1SpacingBefore: CGFloat = 30
    nonisolated static let bodyIndent: CGFloat = 28

    nonisolated static func accentColor(isDark: Bool) -> NSColor {
        isDark
            ? NSColor(red: 0.40, green: 0.65, blue: 1.0, alpha: 1)
            : NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1)
    }

    nonisolated static func mutedColor(isDark: Bool) -> NSColor {
        isDark
            ? .white.withAlphaComponent(0.35)
            : NSColor(white: 0.5, alpha: 1)
    }

    private nonisolated static func frozenParagraphStyle(
        configure: (NSMutableParagraphStyle) -> Void
    ) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        configure(paragraphStyle)
        return (paragraphStyle.copy() as? NSParagraphStyle) ?? paragraphStyle
    }

    nonisolated static func bodyParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.lineSpacing = 5
            $0.paragraphSpacing = 8
            $0.paragraphSpacingBefore = 0
            $0.firstLineHeadIndent = bodyIndent
            $0.headIndent = bodyIndent
        }
    }

    nonisolated static func headingParagraphStyle(
        level: Int,
        isLeadingDocumentHeading: Bool
    ) -> NSParagraphStyle {
        switch level {
        case 1:
            return frozenParagraphStyle {
                $0.paragraphSpacingBefore = isLeadingDocumentHeading
                    ? leadingH1SpacingBefore
                    : sectionH1SpacingBefore
                $0.paragraphSpacing = 6
                $0.lineSpacing = 0
            }
        case 2:
            return frozenParagraphStyle {
                $0.paragraphSpacingBefore = 12
                $0.paragraphSpacing = 2
                $0.lineSpacing = 2
                $0.firstLineHeadIndent = bodyIndent
                $0.headIndent = bodyIndent
            }
        case 3:
            return frozenParagraphStyle {
                $0.paragraphSpacingBefore = 8
                $0.paragraphSpacing = 2
                $0.lineSpacing = 2
                $0.firstLineHeadIndent = bodyIndent
                $0.headIndent = bodyIndent
            }
        case 4:
            return frozenParagraphStyle {
                $0.paragraphSpacingBefore = 6
                $0.paragraphSpacing = 2
                $0.lineSpacing = 2
                $0.firstLineHeadIndent = bodyIndent
                $0.headIndent = bodyIndent
            }
        default:
            return frozenParagraphStyle {
                $0.paragraphSpacingBefore = 4
                $0.paragraphSpacing = 2
                $0.lineSpacing = 2
                $0.firstLineHeadIndent = bodyIndent
                $0.headIndent = bodyIndent
            }
        }
    }

    nonisolated static func calloutParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.lineSpacing = 4
            $0.paragraphSpacing = 6
            $0.paragraphSpacingBefore = 6
            $0.headIndent = bodyIndent + 26
            $0.firstLineHeadIndent = bodyIndent + 26
        }
    }

    nonisolated static func codeBlockParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.lineSpacing = 4
            $0.paragraphSpacing = 4
            $0.paragraphSpacingBefore = 4
            $0.headIndent = bodyIndent + 22
            $0.firstLineHeadIndent = bodyIndent + 22
        }
    }

    nonisolated static func quoteParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.lineSpacing = 4
            $0.paragraphSpacing = 5
            $0.paragraphSpacingBefore = 5
            $0.headIndent = bodyIndent + 22
            $0.firstLineHeadIndent = bodyIndent + 22
        }
    }

    nonisolated static func listParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.lineSpacing = 3
            $0.paragraphSpacing = 1
            $0.firstLineHeadIndent = bodyIndent
            $0.headIndent = bodyIndent + 16
        }
    }

    nonisolated static func tableParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.minimumLineHeight = 26
            $0.maximumLineHeight = 26
            $0.lineSpacing = 0
            $0.paragraphSpacing = 1
            $0.paragraphSpacingBefore = 1
            $0.firstLineHeadIndent = bodyIndent
            $0.headIndent = bodyIndent
        }
    }

    nonisolated static func tablePlaceholderParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.minimumLineHeight = 22
            $0.maximumLineHeight = 22
            $0.lineSpacing = 0
            $0.paragraphSpacing = 0
            $0.paragraphSpacingBefore = 0
            $0.firstLineHeadIndent = bodyIndent
            $0.headIndent = bodyIndent
        }
    }

    nonisolated static func tableCollapsedParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.minimumLineHeight = 1
            $0.maximumLineHeight = 1
            $0.lineSpacing = 0
            $0.paragraphSpacing = 0
            $0.paragraphSpacingBefore = 0
            $0.firstLineHeadIndent = bodyIndent
            $0.headIndent = bodyIndent
        }
    }

    nonisolated static func tableSeparatorParagraphStyle() -> NSParagraphStyle {
        frozenParagraphStyle {
            $0.minimumLineHeight = 1
            $0.maximumLineHeight = 1
            $0.lineSpacing = 0
            $0.paragraphSpacing = 0
            $0.paragraphSpacingBefore = 0
        }
    }

    private nonisolated static func isTableLine(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("|") && trimmedLine.hasSuffix("|") && trimmedLine.count >= 3
    }

    private nonisolated static func isTableSeparatorLine(_ trimmedLine: String) -> Bool {
        guard isTableLine(trimmedLine) else { return false }
        return trimmedLine.dropFirst().dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .allSatisfy { column in
                column.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" }
            }
    }

    nonisolated static func tableLineRole(at range: NSRange, in text: NSString) -> TableLineRole {
        let trimmedLine = text.substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isTableSeparatorLine(trimmedLine) {
            return .separator
        }
        guard range.location > 0 else { return .first }
        let previousLineRange = text.lineRange(for: NSRange(location: range.location - 1, length: 0))
        let previousTrimmedLine = text.substring(with: previousLineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return isTableLine(previousTrimmedLine) ? .continuation : .first
    }

    nonisolated static func blockChromeFill(
        from attributes: [NSAttributedString.Key: Any],
        fallback: NSColor = .controlBackgroundColor
    ) -> NSColor {
        (attributes[blockChromeFillAttribute] as? NSColor) ?? fallback
    }

    struct BlockChromeSpan {
        let kind: MarkdownBlockChromeKind
        let fill: NSColor
        let accent: NSColor
        let lineRange: NSRange
    }

    nonisolated static func blockChromeStyleRange(in text: NSString, lineRange: NSRange) -> NSRange {
        let lineEnd = lineRange.location + lineRange.length
        let hasTrailingNewline = lineEnd > 0
            && lineEnd <= text.length
            && text.character(at: lineEnd - 1) == 0x0A
        return NSRange(
            location: lineRange.location,
            length: max(0, hasTrailingNewline ? lineRange.length - 1 : lineRange.length)
        )
    }

    nonisolated static func blockChromeSpan(
        in attributedString: NSAttributedString,
        text: NSString,
        aroundLineRange lineRange: NSRange
    ) -> BlockChromeSpan? {
        guard let descriptor = blockChromeDescriptor(
            in: attributedString,
            text: text,
            lineRange: lineRange
        ) else {
            return nil
        }

        var startLine = lineRange
        while startLine.location > 0 {
            let previousLine = text.lineRange(for: NSRange(location: startLine.location - 1, length: 0))
            guard let previousDescriptor = blockChromeDescriptor(
                in: attributedString,
                text: text,
                lineRange: previousLine
            ), blockChromeDescriptorMatches(previousDescriptor, descriptor) else {
                break
            }
            startLine = previousLine
        }

        var endLine = lineRange
        while NSMaxRange(endLine) < text.length {
            let nextLine = text.lineRange(for: NSRange(location: NSMaxRange(endLine), length: 0))
            guard let nextDescriptor = blockChromeDescriptor(
                in: attributedString,
                text: text,
                lineRange: nextLine
            ), blockChromeDescriptorMatches(nextDescriptor, descriptor) else {
                break
            }
            endLine = nextLine
        }

        return BlockChromeSpan(
            kind: descriptor.kind,
            fill: descriptor.fill,
            accent: descriptor.accent,
            lineRange: NSRange(
                location: startLine.location,
                length: NSMaxRange(endLine) - startLine.location
            )
        )
    }

    private struct BlockChromeDescriptor {
        let kind: MarkdownBlockChromeKind
        let fill: NSColor
        let accent: NSColor
    }

    private nonisolated static func blockChromeDescriptor(
        in attributedString: NSAttributedString,
        text: NSString,
        lineRange: NSRange
    ) -> BlockChromeDescriptor? {
        let styleRange = blockChromeStyleRange(in: text, lineRange: lineRange)
        guard styleRange.length > 0, NSMaxRange(styleRange) <= attributedString.length else {
            return nil
        }
        guard let kindRaw = attributedString.attribute(
            blockChromeKindAttribute,
            at: styleRange.location,
            effectiveRange: nil
        ) as? String, let kind = MarkdownBlockChromeKind(rawValue: kindRaw) else {
            return nil
        }

        let attributes = attributedString.attributes(at: styleRange.location, effectiveRange: nil)
        let fill = blockChromeFill(from: attributes)
        let accent = (attributes[blockChromeAccentAttribute] as? NSColor) ?? fill
        return BlockChromeDescriptor(kind: kind, fill: fill, accent: accent)
    }

    private nonisolated static func blockChromeDescriptorMatches(
        _ lhs: BlockChromeDescriptor,
        _ rhs: BlockChromeDescriptor
    ) -> Bool {
        lhs.kind == rhs.kind && lhs.fill.isEqual(rhs.fill) && lhs.accent.isEqual(rhs.accent)
    }

    nonisolated static func blockChromeFrame(
        textContainerOrigin: NSPoint,
        containerWidth: CGFloat,
        boundsWidth: CGFloat
    ) -> NSRect {
        let leadingInset = max(bodyIndent - 8, 14)
        let trailingInset = MarkdownPreviewSurfaceMetrics.default.rightEdgeWidth
        let availableWidth = min(containerWidth, max(0, boundsWidth - (textContainerOrigin.x * 2)))
        let width = max(0, availableWidth - leadingInset - trailingInset)
        return NSRect(
            x: textContainerOrigin.x + leadingInset,
            y: 0,
            width: width,
            height: 0
        )
    }

    nonisolated static func drawBlockChrome(
        kind: MarkdownBlockChromeKind,
        fill: NSColor,
        accent: NSColor,
        in rect: NSRect
    ) {
        let metrics = MarkdownPreviewSurfaceMetrics.default
        let insetRect = rect.insetBy(dx: metrics.borderWidth / 2, dy: metrics.borderWidth / 2)
        let cornerRadius = metrics.cornerRadius
        let path = NSBezierPath(
            roundedRect: insetRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.04)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        let surfaceFill: NSColor
        let borderColor: NSColor
        let sheenColor: NSColor
        let railWidth: CGFloat
        let railAlpha: CGFloat
        switch kind {
        case .callout:
            surfaceFill = fill.blended(withFraction: 0.18, of: accent.withAlphaComponent(0.16)) ?? fill
            borderColor = accent.withAlphaComponent(0.16)
            sheenColor = NSColor.white.withAlphaComponent(0.12)
            railWidth = 3.5
            railAlpha = 0.34
        case .quote:
            surfaceFill = fill.blended(withFraction: 0.10, of: accent.withAlphaComponent(0.12)) ?? fill
            borderColor = accent.withAlphaComponent(0.10)
            sheenColor = NSColor.white.withAlphaComponent(0.10)
            railWidth = 2.5
            railAlpha = 0.20
        case .codeBlock:
            surfaceFill = fill.blended(withFraction: 0.06, of: accent.withAlphaComponent(0.08)) ?? fill
            borderColor = accent.withAlphaComponent(0.08)
            sheenColor = NSColor.white.withAlphaComponent(0.08)
            railWidth = 0
            railAlpha = 0
        }
        surfaceFill.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        if let sheen = NSGradient(colors: [sheenColor, .clear]) {
            sheen.draw(in: path, angle: 90)
        }

        borderColor.setStroke()
        path.lineWidth = metrics.borderWidth
        path.stroke()

        guard railWidth > 0 else { return }
        let accentRect = NSRect(
            x: insetRect.minX + 8,
            y: insetRect.minY + 7,
            width: railWidth,
            height: max(0, insetRect.height - 14)
        )
        let accentPath = NSBezierPath(
            roundedRect: accentRect,
            xRadius: railWidth / 2,
            yRadius: railWidth / 2
        )
        accent.withAlphaComponent(railAlpha).setFill()
        accentPath.fill()
    }
}

extension NSFont {
    nonisolated var italic: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
}
