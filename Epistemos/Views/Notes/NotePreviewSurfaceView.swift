import AppKit
import SwiftUI

enum NotePreviewPerformancePolicy {
    static let showsOverlayBadge = false
}

enum NotePreviewChromeMetrics {
    static let fallbackSingleTopInset: CGFloat = 46
    static let fallbackTabbedTopInset: CGFloat = 96

    static func backdropHeight(
        titlebarInset: CGFloat,
        hasMultipleTabs: Bool,
        minimumHeight: CGFloat = 0
    ) -> CGFloat {
        let fallback = hasMultipleTabs ? fallbackTabbedTopInset : fallbackSingleTopInset
        let baseHeight: CGFloat
        guard titlebarInset > 0 else {
            baseHeight = fallback
            return max(baseHeight, minimumHeight)
        }
        // Owner 2026-07-03: when the titlebar inset is actually measured, cover EXACTLY
        // that — the previous `max(titlebarInset, fallback)` forced the chrome to at
        // least 46 (single) / 96 (tabbed) even when the real titlebar was ~28px, which
        // read as a solid empty pad above the content (the persistent "top padding").
        // The fallback now only applies when the inset can't be measured (guard above).
        baseHeight = titlebarInset
        return max(baseHeight, minimumHeight)
    }

    static func contentTopInset(
        chromeBackdropHeight: CGFloat,
        chromeMinimumHeight: CGFloat
    ) -> CGFloat {
        guard chromeMinimumHeight > 0 else { return 0 }
        return max(0, max(chromeBackdropHeight, chromeMinimumHeight))
    }

    static func titlebarInset(for window: NSWindow) -> CGFloat {
        let inset = max(0, window.frame.height - window.contentLayoutRect.maxY)
        return inset.isFinite ? inset : 0
    }
}

enum NoteDualPreviewLayout {
    static let minimumWidth: CGFloat = 1180
    static let pageSpacing: CGFloat = 28
    static let pageMaxWidth: CGFloat = 580
    static let defaultSinglePageMaxWidth: CGFloat = 920
    static let defaultEditorSurfaceMaxWidth: CGFloat = 1080
    static let tableSinglePageMaxWidth: CGFloat = 840
    static let tableReadableMaxWidth: CGFloat = 740
    static let tableEditorReadableMaxWidth: CGFloat = 520
    static let previewTextReadableMaxWidth: CGFloat = 760
    static let editorTextReadableMaxWidth: CGFloat = 960
    static let minimumTextHorizontalInset: CGFloat = 60
    // Owner 2026-07-03: top space below the titlebar DELETED (was 28) so the
    // preview matches the editor/prose top edge. The see-through-title fix is
    // separate (the top chrome backdrop opacity), not padding.
    static let outerPadding = EdgeInsets(top: 0, leading: 32, bottom: 40, trailing: 32)
    // Owner 2026-07-03: the top separation IS the prose editor's own vertical inset
    // (ProseEditorRepresentable2.verticalInset, the NSTextView textContainerInset height)
    // — same value, same "space on the content layer" the editor uses, not an added
    // padding band. Preview and Edit line up exactly.
    static let pagePadding = EdgeInsets(
        top: ProseEditorRepresentable2.verticalInset,
        leading: 38,
        bottom: 36,
        trailing: 38
    )
    static let sectionTargetCharacterCount = 900
    static let sectionSoftOverflowFloor = 160

    private enum PreviewBlockKind {
        case heading
        case prose
        case isolated
    }

    static func usesDualColumns(for availableWidth: CGFloat) -> Bool {
        availableWidth >= minimumWidth
    }

    static func containsTable(in markdown: String) -> Bool {
        paragraphBlocks(in: markdown).contains(where: isTableBlock)
    }

    static func singlePageMaxWidth(for markdown: String) -> CGFloat {
        containsTable(in: markdown) ? tableSinglePageMaxWidth : defaultSinglePageMaxWidth
    }

    static func singlePageWidth(for markdown: String, availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(0, availableWidth - outerPadding.leading - outerPadding.trailing)
        return min(singlePageMaxWidth(for: markdown), usableWidth)
    }

    static func dualPageWidth(for availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(
            0,
            availableWidth - outerPadding.leading - outerPadding.trailing - pageSpacing
        )
        return min(pageMaxWidth, usableWidth / 2)
    }

    static func readableWidth(for markdown: String, defaultWidth: CGFloat) -> CGFloat {
        containsTable(in: markdown) ? min(defaultWidth, tableReadableMaxWidth) : defaultWidth
    }

    static func editorReadableWidth(for markdown: String, defaultWidth: CGFloat) -> CGFloat {
        if containsTable(in: markdown) {
            return min(defaultWidth, tableEditorReadableMaxWidth)
        }
        return min(defaultWidth, defaultEditorSurfaceMaxWidth)
    }

    static func centeredTextInset(
        for availableWidth: CGFloat,
        markdown: String,
        maxReadableWidth: CGFloat
    ) -> CGFloat {
        guard availableWidth.isFinite else { return minimumTextHorizontalInset }
        guard !containsTable(in: markdown) else { return minimumTextHorizontalInset }

        let clampedWidth = max(0, availableWidth)
        return max(minimumTextHorizontalInset, (clampedWidth - maxReadableWidth) / 2)
    }

    static func paragraphBlocks(in markdown: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        var isInsideCodeFence = false

        func flushCurrent() {
            let block = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty {
                blocks.append(block)
            }
            current.removeAll(keepingCapacity: true)
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let currentLine = String(line)
            let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                current.append(currentLine)
                isInsideCodeFence.toggle()
                continue
            }
            if !isInsideCodeFence && trimmed.isEmpty {
                flushCurrent()
                continue
            }
            current.append(currentLine)
        }

        flushCurrent()
        return blocks
    }

    static func bookSections(
        in markdown: String,
        targetCharacterCount: Int = sectionTargetCharacterCount
    ) -> [String] {
        let blocks = paragraphBlocks(in: markdown)
        guard !blocks.isEmpty else { return [] }

        var sections: [String] = []
        var current: [String] = []
        var currentWeight = 0

        func flushCurrent() {
            let section = current.joined(separator: "\n\n").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !section.isEmpty {
                sections.append(section)
            }
            current.removeAll(keepingCapacity: true)
            currentWeight = 0
        }

        for block in blocks {
            let kind = classify(block)
            let blockWeight = sectionWeight(block)

            switch kind {
            case .heading:
                flushCurrent()
                current = [block]
                currentWeight = blockWeight

            case .prose:
                if current.isEmpty {
                    current = [block]
                    currentWeight = blockWeight
                } else if shouldAppend(
                    blockWeight: blockWeight,
                    to: current,
                    currentWeight: currentWeight,
                    targetCharacterCount: targetCharacterCount
                ) {
                    current.append(block)
                    currentWeight += blockWeight
                } else {
                    flushCurrent()
                    current = [block]
                    currentWeight = blockWeight
                }

            case .isolated:
                if current.count == 1, classify(current[0]) == .heading {
                    current.append(block)
                    flushCurrent()
                } else {
                    flushCurrent()
                    sections.append(block)
                }
            }
        }

        flushCurrent()
        return sections
    }

    static func columnContents(
        in markdown: String,
        targetCharacterCount: Int = sectionTargetCharacterCount
    ) -> [String] {
        let sections = bookSections(in: markdown, targetCharacterCount: targetCharacterCount)
        guard !sections.isEmpty else { return [] }
        guard sections.count > 1 else { return sections }

        let weights = sections.map(sectionWeight)
        let target = weights.reduce(0, +) / 2
        var running = 0
        var bestSplit = 1
        var bestDelta = Int.max

        for index in 0..<(sections.count - 1) {
            running += weights[index]
            let delta = abs(target - running)
            if delta < bestDelta {
                bestDelta = delta
                bestSplit = index + 1
            }
        }

        return [
            sections[..<bestSplit].joined(separator: "\n\n"),
            sections[bestSplit...].joined(separator: "\n\n"),
        ]
    }

    private static func classify(_ block: String) -> PreviewBlockKind {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return .heading
        }
        if trimmed.hasPrefix("```")
            || trimmed == "---"
            || trimmed == "***"
            || trimmed == "___"
            || isTableBlock(trimmed)
        {
            return .isolated
        }
        return .prose
    }

    private static func isTableBlock(_ block: String) -> Bool {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
        }
    }

    private static func sectionWeight(_ section: String) -> Int {
        let lineCount = section.split(separator: "\n", omittingEmptySubsequences: false).count
        return section.count + max(0, lineCount - 1) * 20
    }

    private static func shouldAppend(
        blockWeight: Int,
        to current: [String],
        currentWeight: Int,
        targetCharacterCount: Int
    ) -> Bool {
        let combinedWeight = currentWeight + blockWeight
        if combinedWeight <= targetCharacterCount {
            return true
        }
        if current.count == 1, classify(current[0]) == .heading {
            return true
        }
        if currentWeight < targetCharacterCount {
            let overflowAllowance = max(targetCharacterCount / 3, sectionSoftOverflowFloor)
            return combinedWeight <= targetCharacterCount + overflowAllowance
        }
        return false
    }
}

struct AdaptiveNotePreviewView2: View {
    let content: String
    let theme: EpistemosTheme
    let hasMultipleTabs: Bool
    let surfaceBackground: Color?
    let chromeMinimumHeight: CGFloat
    private let pageContents: [String]
    @State private var titlebarInset: CGFloat = 0

    init(
        content: String,
        theme: EpistemosTheme,
        hasMultipleTabs: Bool,
        surfaceBackground: Color? = nil,
        chromeMinimumHeight: CGFloat = 0
    ) {
        self.content = content
        self.theme = theme
        self.hasMultipleTabs = hasMultipleTabs
        self.surfaceBackground = surfaceBackground
        self.chromeMinimumHeight = chromeMinimumHeight
        self.pageContents = NoteDualPreviewLayout.columnContents(in: content)
    }

    var body: some View {
        GeometryReader { proxy in
            let usesDualColumns = NoteDualPreviewLayout.usesDualColumns(for: proxy.size.width)
                && pageContents.count > 1
            let dualPageWidth = NoteDualPreviewLayout.dualPageWidth(for: proxy.size.width)
            let chromeBackdropHeight = NotePreviewChromeMetrics.backdropHeight(
                titlebarInset: titlebarInset,
                hasMultipleTabs: hasMultipleTabs,
                minimumHeight: chromeMinimumHeight
            )
            let contentTopInset = NotePreviewChromeMetrics.contentTopInset(
                chromeBackdropHeight: chromeBackdropHeight,
                chromeMinimumHeight: chromeMinimumHeight
            )
            let outerPadding = EdgeInsets(
                top: NoteDualPreviewLayout.outerPadding.top + contentTopInset,
                leading: NoteDualPreviewLayout.outerPadding.leading,
                bottom: NoteDualPreviewLayout.outerPadding.bottom,
                trailing: NoteDualPreviewLayout.outerPadding.trailing
            )

            ScrollView {
                if usesDualColumns {
                    HStack(alignment: .top, spacing: NoteDualPreviewLayout.pageSpacing) {
                        ForEach(Array(pageContents.enumerated()), id: \.offset) { _, pageContent in
                            NoteBookPreviewPage(markdown: pageContent, theme: theme)
                                .equatable()
                                .frame(
                                    width: dualPageWidth,
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(outerPadding)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    NoteBookPreviewPage(markdown: content, theme: theme)
                        .equatable()
                        .frame(
                            maxWidth: NoteDualPreviewLayout.singlePageWidth(
                                for: content,
                                availableWidth: proxy.size.width
                            ),
                            alignment: .topLeading
                        )
                        .padding(outerPadding)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .background { previewBackdrop }
            .overlay(alignment: .top) {
                // Regular note preview (chromeMinimumHeight == 0): NO chrome band — match
                // the prose editor exactly. "Color behind the title" comes from the
                // workspace background layer (NoteDetailWorkspaceView draws
                // noteWorkspaceBackground.ignoresSafeArea() behind everything), and the
                // top separation is pagePadding.top (== the editor's verticalInset 40) —
                // space on the content layer, not a padding band. Only the graph-embedded
                // preview keeps the chrome and pushes scroll content below the floating
                // graph toolbar area.
                if chromeMinimumHeight > 0 {
                    previewTopChrome(height: chromeBackdropHeight)
                        .zIndex(10)
                }
            }
            .background {
                NotePreviewTitlebarInsetReader(titlebarInset: $titlebarInset)
                    .frame(width: 0, height: 0)
            }
            .overlay(alignment: .topTrailing) {
                if NotePreviewPerformancePolicy.showsOverlayBadge {
                    notePreviewBadge
                        .padding(.top, NoteDualPreviewLayout.outerPadding.top)
                        .padding(.trailing, NoteDualPreviewLayout.outerPadding.trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var previewBackdrop: some View {
        if let surfaceBackground {
            surfaceBackground
        } else {
            // #15 (owner 2026-07-03): use the SOLID surface (matching
            // previewChromeBackdrop + the editor body) so the title never reads as
            // see-through on dark/blur themes, where canvasBackground(for:) is
            // translucent and let the desktop/window show through behind the title.
            MarkdownPreviewSurfaceStyle.solidFlatBackground(for: theme.surfaceVariant(.other))
        }
    }

    private func previewTopChrome(height: CGFloat) -> some View {
        previewChromeBackdrop
            .frame(maxWidth: .infinity)
            .frame(height: max(0, height))
            .allowsHitTesting(false)
    }

    private var previewChromeBackdrop: some View {
        MarkdownPreviewSurfaceStyle.solidFlatBackground(for: theme.surfaceVariant(.other))
    }

    private var notePreviewBadge: some View {
        HStack(spacing: 8) {
            ASCIIFrameAnimationText(
                configuration: .previewScanner,
                font: .system(size: 10, weight: .semibold, design: .monospaced),
                color: theme.fontAccent.opacity(0.78)
            )
            Text("Preview")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.045) : Color.black.opacity(0.03))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
    }
}

private struct NotePreviewTitlebarInsetReader: NSViewRepresentable {
    @Binding var titlebarInset: CGFloat

    func makeNSView(context: Context) -> NotePreviewTitlebarInsetView {
        let view = NotePreviewTitlebarInsetView()
        view.onChange = { inset in
            guard abs(titlebarInset - inset) > 0.5 else { return }
            titlebarInset = inset
        }
        return view
    }

    func updateNSView(_ nsView: NotePreviewTitlebarInsetView, context: Context) {
        nsView.onChange = { inset in
            guard abs(titlebarInset - inset) > 0.5 else { return }
            titlebarInset = inset
        }
        nsView.refreshInset()
    }
}

private final class NotePreviewTitlebarInsetView: NSView {
    var onChange: ((CGFloat) -> Void)?
    private var lastReportedInset: CGFloat = -1

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshInset()
    }

    override func layout() {
        super.layout()
        refreshInset()
    }

    func refreshInset() {
        guard let window else { return }
        let inset = NotePreviewChromeMetrics.titlebarInset(for: window)
        guard abs(lastReportedInset - inset) > 0.5 else { return }
        lastReportedInset = inset
        onChange?(inset)
    }
}

private struct NoteBookPreviewPage: View, Equatable {
    let markdown: String
    let theme: EpistemosTheme

    var body: some View {
        MarkdownTextView(
            content: markdown,
            theme: theme,
            rippleStyle: .none
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NoteDualPreviewLayout.pagePadding)
    }
}
