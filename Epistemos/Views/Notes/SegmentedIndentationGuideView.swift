// SegmentedIndentationGuideView.swift
//
// VS Code-style segmented indentation guides for the code editor.
// Draws vertical lines only where code exists at that indent level,
// with Apple-native styling (subtle colors, smooth lines).
//
// Unlike continuous lines, these show the actual structure of your code
// and highlight the active indentation level.
//
// 2026-04-07.

import AppKit

// MARK: - Indent Line Info

/// Information about indentation for a single line
struct IndentLineInfo {
    let lineNumber: Int
    let indentLevel: Int
    let hasContent: Bool
    let isBlockStart: Bool
    let isBlockEnd: Bool
    let yPosition: CGFloat
    let lineHeight: CGFloat
}

// MARK: - Segmented Indentation Guide View

/// Renders VS Code-style segmented indentation guides
final class SegmentedIndentationGuideView: NSView {
    
    // Configuration
    var indentWidth: CGFloat = 16
    var lineHeight: CGFloat = 17
    var tabWidth: Int = 4
    
    // Apple-native colors
    var guideColor: NSColor {
        NSColor.systemGray.withAlphaComponent(NSColor.systemGray.alphaComponent * 0.2)
    }
    
    var activeGuideColor: NSColor {
        NSColor.controlAccentColor.withAlphaComponent(0.4)
    }
    
    // Data
    private var lineInfos: [IndentLineInfo] = []
    private var maxIndentLevel: Int = 0
    private var activeIndentLevel: Int = -1
    
    // Scrolling
    private var visibleRange: NSRange = NSRange(location: 0, length: 0)
    private var scrollOffset: CGFloat = 0
    
    override var isFlipped: Bool { true }
    
    // MARK: - Update Methods
    
    /// Updates indentation info from text content.
    /// Line y-positions are stored relative (no scroll offset baked in).
    /// The offset is applied at draw time for performance.
    func updateFromText(_ text: String, cursorLine: Int, scrollOffset: CGFloat = 0) {
        self.scrollOffset = scrollOffset

        let lines = text.components(separatedBy: .newlines)
        var newLineInfos: [IndentLineInfo] = []
        var maxIndent = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let leadingWhitespace = line.prefix(while: { $0.isWhitespace })
            let indentLevel = leadingWhitespace.count / tabWidth

            // Detect block structure
            let isBlockStart = trimmed.hasSuffix("{") ||
                              trimmed.hasSuffix("(") ||
                              trimmed.hasSuffix("[") ||
                              trimmed.hasSuffix(":")

            let firstChar = trimmed.first
            let isBlockEnd = firstChar == "}" ||
                            firstChar == ")" ||
                            firstChar == "]"

            maxIndent = max(maxIndent, indentLevel)

            // Store yPosition relative (without scroll offset)
            let info = IndentLineInfo(
                lineNumber: index + 1,
                indentLevel: indentLevel,
                hasContent: !trimmed.isEmpty,
                isBlockStart: isBlockStart,
                isBlockEnd: isBlockEnd,
                yPosition: CGFloat(index) * lineHeight,
                lineHeight: lineHeight
            )

            newLineInfos.append(info)

            // Track active level from cursor
            if index + 1 == cursorLine {
                activeIndentLevel = indentLevel
            }
        }

        lineInfos = newLineInfos
        maxIndentLevel = maxIndent

        needsDisplay = true
    }

    /// Updates visible range for optimization
    func updateVisibleRange(_ range: NSRange) {
        visibleRange = range
        needsDisplay = true
    }

    /// Updates scroll offset — just stores the value and redraws.
    /// No array remapping needed since offset is applied at draw time.
    func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
        needsDisplay = true
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard maxIndentLevel > 0 else { return }
        
        let context = NSGraphicsContext.current?.cgContext
        
        // Draw guides for each indent level
        for level in 1...maxIndentLevel {
            let x = CGFloat(level) * indentWidth
            let isActive = level == activeIndentLevel
            
            drawIndentGuide(
                atX: x,
                level: level,
                isActive: isActive,
                in: context,
                dirtyRect: dirtyRect
            )
        }
    }
    
    private func drawIndentGuide(
        atX x: CGFloat,
        level: Int,
        isActive: Bool,
        in context: CGContext?,
        dirtyRect: NSRect
    ) {
        // Apply scroll offset at draw time (not baked into lineInfos)
        let offset = scrollOffset

        // Find all line segments at this indent level
        var segments: [(startY: CGFloat, endY: CGFloat)] = []
        var currentStart: CGFloat?

        for info in lineInfos {
            let y = info.yPosition + offset
            let hasIndentAtLevel = info.indentLevel >= level && info.hasContent

            if hasIndentAtLevel {
                if currentStart == nil {
                    currentStart = y
                }
            } else {
                if let start = currentStart {
                    let endY = y - lineHeight / 2
                    if endY > start {
                        segments.append((startY: start, endY: endY))
                    }
                    currentStart = nil
                }
            }
        }

        // Close final segment
        if let start = currentStart, let lastInfo = lineInfos.last {
            segments.append((startY: start, endY: lastInfo.yPosition + offset + lineHeight))
        }

        // Draw segments
        let color = isActive ? activeGuideColor : guideColor
        color.setStroke()

        let lineWidth: CGFloat = isActive ? 1.5 : 1.0

        for segment in segments {
            // Skip if outside dirty rect
            if segment.endY < dirtyRect.minY || segment.startY > dirtyRect.maxY {
                continue
            }

            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round

            path.move(to: NSPoint(x: x, y: max(segment.startY, dirtyRect.minY)))
            path.line(to: NSPoint(x: x, y: min(segment.endY, dirtyRect.maxY)))

            path.stroke()
        }

        // Draw connection dots at block starts/ends for visual clarity
        if isActive {
            for info in lineInfos where info.indentLevel == level {
                if info.isBlockStart || info.isBlockEnd {
                    let y = info.yPosition + offset
                    let dotRect = NSRect(
                        x: x - 2,
                        y: y + lineHeight / 2 - 2,
                        width: 4,
                        height: 4
                    )

                    if dirtyRect.intersects(dotRect) {
                        let dotPath = NSBezierPath(ovalIn: dotRect)
                        activeGuideColor.setFill()
                        dotPath.fill()
                    }
                }
            }
        }
    }
    
    // MARK: - Active Level Tracking
    
    func setActiveIndentLevel(_ level: Int) {
        if activeIndentLevel != level {
            activeIndentLevel = level
            needsDisplay = true
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
import SwiftUI

struct SegmentedIndentGuidePreview: NSViewRepresentable {
    func makeNSView(context: Context) -> SegmentedIndentationGuideView {
        let view = SegmentedIndentationGuideView()
        
        let sampleCode = """
struct Example {
    let property: String
    
    func method() {
        if condition {
            doSomething()
        }
        
        for item in items {
            process(item)
        }
    }
    
    var computed: Int {
        get {
            return 42
        }
    }
}
"""
        
        view.updateFromText(sampleCode, cursorLine: 5)
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 300)
        
        return view
    }
    
    func updateNSView(_ nsView: SegmentedIndentationGuideView, context: Context) {}
}

#Preview("Segmented Indent Guides") {
    SegmentedIndentGuidePreview()
        .frame(width: 200, height: 300)
        .background(Color(NSColor.textBackgroundColor))
}
#endif
