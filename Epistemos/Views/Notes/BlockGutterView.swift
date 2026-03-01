import AppKit

// MARK: - BlockGutterView
// NSRulerView subclass that draws bullet dots and fold triangles in the editor gutter.
//
// Visual spec:
//   - Bullet dot: small circle at each list item line (-, *, numbered)
//   - Fold triangle: disclosure triangle for items with indented children
//   - Click triangle → fold/unfold children in the text
//
// Positioning: Uses NSLayoutManager to map line ranges to glyph rects,
// drawing at the correct vertical position even during scrolling.

final class BlockGutterView: NSRulerView {

    /// Width of the gutter column.
    static let gutterWidth: CGFloat = 24

    /// Collapsed line ranges — set of line start indices whose children are hidden.
    var collapsedRanges: Set<Int> = []

    /// Callback when user clicks a fold triangle.
    /// Receives the character index of the line to toggle.
    var onFoldToggle: ((Int) -> Void)?

    override var isFlipped: Bool { true }

    override var requiredThickness: CGFloat { Self.gutterWidth }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let str = storage.string as NSString
        let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let dotColor: NSColor = isDark
            ? .white.withAlphaComponent(0.25)
            : .black.withAlphaComponent(0.20)
        let triangleColor: NSColor = isDark
            ? .white.withAlphaComponent(0.35)
            : .black.withAlphaComponent(0.30)

        // Walk each line in the visible character range.
        var lineStart = charRange.location
        let rangeEnd = charRange.location + charRange.length

        while lineStart < rangeEnd && lineStart < str.length {
            let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = str.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Determine if this is a list item line.
            let isList = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
                || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil

            if isList {
                // Get the vertical position of this line.
                let glyphIdx = layoutManager.glyphIndexForCharacter(at: lineStart)
                var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                // Convert from text view coords to ruler view coords.
                lineRect.origin.y -= visibleRect.origin.y
                lineRect.origin.y += convert(.zero, from: textView).y

                let midY = lineRect.origin.y + lineRect.height / 2

                // Check if this line has indented children (next line has deeper indent).
                let hasChildren = lineHasChildren(at: lineStart, in: str)

                if hasChildren {
                    // Draw disclosure triangle.
                    let isCollapsed = collapsedRanges.contains(lineStart)
                    drawTriangle(at: midY, collapsed: isCollapsed, color: triangleColor)
                } else {
                    // Draw bullet dot.
                    drawDot(at: midY, color: dotColor)
                }
            }

            // Advance to next line.
            let nextStart = lineRange.location + lineRange.length
            if nextStart <= lineStart { break }
            lineStart = nextStart
        }
    }

    // MARK: - Hit Testing

    override func mouseDown(with event: NSEvent) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            super.mouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        // Only handle clicks in the gutter area (left 24px).
        guard point.x < Self.gutterWidth else {
            super.mouseDown(with: event)
            return
        }

        // Convert ruler Y to text view Y.
        let visibleRect = textView.visibleRect
        let tvPoint = NSPoint(x: 0, y: point.y - convert(.zero, from: textView).y + visibleRect.origin.y)

        // Find which character index this Y corresponds to.
        let glyphIdx = layoutManager.glyphIndex(for: tvPoint, in: textContainer)
        let charIdx = layoutManager.characterIndexForGlyph(at: glyphIdx)

        let str = textView.string as NSString
        let lineRange = str.lineRange(for: NSRange(location: charIdx, length: 0))

        // Only toggle if the line has children.
        if lineHasChildren(at: lineRange.location, in: str) {
            onFoldToggle?(lineRange.location)
            setNeedsDisplay(bounds)
        }
    }

    // MARK: - Hidden Range Computation

    /// Compute the character ranges that should be hidden (children of collapsed parents).
    /// Returns sorted, non-overlapping NSRanges suitable for glyph hiding.
    func computeHiddenRanges(in str: NSString) -> [NSRange] {
        guard !collapsedRanges.isEmpty else { return [] }
        var ranges: [NSRange] = []

        for lineStart in collapsedRanges {
            guard lineStart < str.length else { continue }
            let parentRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
            let parentLine = str.substring(with: parentRange)
            let parentIndent = measureIndent(parentLine)

            // Walk subsequent lines, collecting those with deeper indent.
            var childStart = parentRange.location + parentRange.length
            let rangeStart = childStart

            while childStart < str.length {
                let nextRange = str.lineRange(for: NSRange(location: childStart, length: 0))
                let nextLine = str.substring(with: nextRange)
                let trimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)

                // Empty lines within a block are considered children.
                if trimmed.isEmpty {
                    childStart = nextRange.location + nextRange.length
                    continue
                }

                // Stop when we reach a line at the same or lower indent.
                if measureIndent(nextLine) <= parentIndent {
                    break
                }

                childStart = nextRange.location + nextRange.length
            }

            let rangeEnd = childStart
            if rangeEnd > rangeStart {
                ranges.append(NSRange(location: rangeStart, length: rangeEnd - rangeStart))
            }
        }

        // Sort and merge overlapping ranges.
        ranges.sort { $0.location < $1.location }
        var merged: [NSRange] = []
        for r in ranges {
            if let last = merged.last, last.location + last.length >= r.location {
                merged[merged.count - 1] = NSUnionRange(last, r)
            } else {
                merged.append(r)
            }
        }
        return merged
    }

    // MARK: - Helpers

    /// Check if the line at `lineStart` has indented children (next non-empty line has deeper indent).
    private func lineHasChildren(at lineStart: Int, in str: NSString) -> Bool {
        let lineRange = str.lineRange(for: NSRange(location: lineStart, length: 0))
        let line = str.substring(with: lineRange)
        let currentIndent = measureIndent(line)

        // Look at the next line.
        let nextStart = lineRange.location + lineRange.length
        guard nextStart < str.length else { return false }

        let nextLineRange = str.lineRange(for: NSRange(location: nextStart, length: 0))
        let nextLine = str.substring(with: nextLineRange)
        let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nextTrimmed.isEmpty else { return false }

        return measureIndent(nextLine) > currentIndent
    }

    /// Count leading spaces / tabs as indent level.
    private func measureIndent(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 2 }
            else { break }
        }
        return count / 2 // Normalize to 2-space tabs
    }

    /// Draw a small filled circle (bullet dot).
    private func drawDot(at midY: CGFloat, color: NSColor) {
        let dotSize: CGFloat = 4
        let x = (Self.gutterWidth - dotSize) / 2
        let rect = NSRect(x: x, y: midY - dotSize / 2, width: dotSize, height: dotSize)
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    /// Draw a disclosure triangle (right-pointing if collapsed, down-pointing if expanded).
    private func drawTriangle(at midY: CGFloat, collapsed: Bool, color: NSColor) {
        let size: CGFloat = 7
        let x = (Self.gutterWidth - size) / 2
        let path = NSBezierPath()

        if collapsed {
            // Right-pointing triangle ▶
            path.move(to: NSPoint(x: x, y: midY - size / 2))
            path.line(to: NSPoint(x: x + size, y: midY))
            path.line(to: NSPoint(x: x, y: midY + size / 2))
        } else {
            // Down-pointing triangle ▼
            path.move(to: NSPoint(x: x, y: midY - size / 3))
            path.line(to: NSPoint(x: x + size, y: midY - size / 3))
            path.line(to: NSPoint(x: x + size / 2, y: midY + size * 2 / 3))
        }

        path.close()
        color.setFill()
        path.fill()
    }
}
