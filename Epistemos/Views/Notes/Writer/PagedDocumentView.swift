import AppKit
import SwiftUI

// MARK: - PagedDocumentView
// NSViewRepresentable that creates a paginated academic document using TextKit's
// multi-container layout. One NSLayoutManager flows text across multiple
// NSTextContainers, each owned by a PageTileView (NSTextView).
//
// Architecture:
//   NSScrollView
//   +-- PageCanvasView (NSView, isFlipped, grey/dark background)
//       +-- PageTileView[0] (NSTextView, 612x792pt, white/dark surface, shadow)
//       +-- PageTileView[1]
//       +-- ...

struct PagedDocumentView: NSViewRepresentable {

    @Binding var text: String
    let formatState: WriterFormatState
    let isDark: Bool
    let isEditable: Bool

    // MARK: - Constants

    private static let pageGap: CGFloat = 24
    private static let canvasPadding: CGFloat = 40

    // MARK: - Theme Colors

    private var canvasColor: NSColor {
        isDark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.85, alpha: 1)
    }

    private var pageColor: NSColor {
        isDark ? NSColor(white: 0.18, alpha: 1) : .white
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - makeNSView

    func makeNSView(context: Context) -> NSScrollView {
        let coord = context.coordinator

        // 1. Create WriterTextStorage
        let storage = WriterTextStorage()
        storage.formatState = formatState
        storage.isDark = isDark
        coord.storage = storage

        // 2. Create NSLayoutManager
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.backgroundLayoutEnabled = true
        coord.layoutManager = layoutManager

        // 3. Attach storage to layout manager
        storage.addLayoutManager(layoutManager)

        // 4. Create PageCanvasView
        let canvas = PageCanvasView(isDark: isDark)
        coord.canvas = canvas

        // 5. Add the first page
        addPage(coord: coord)

        // 6. Load text into storage
        storage.skipFormatting = true
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.replaceCharacters(in: fullRange, with: text)
        storage.skipFormatting = false
        storage.reapplyFormatting()

        // 7. Wrap canvas in NSScrollView
        let scrollView = NSScrollView()
        scrollView.documentView = canvas
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = canvasColor
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // 8. Observe clip view frame changes so we re-center on window resize
        scrollView.contentView.postsFrameChangedNotifications = true
        coord.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak coord] _ in
            guard let coord else { return }
            MainActor.assumeIsolated {
                if let sv = coord.canvas?.enclosingScrollView {
                    PagedDocumentView.layoutPageTiles(coord: coord, in: sv)
                }
            }
        }

        // 9. After one frame delay, reconcile pages and layout tiles.
        // Two passes: immediate async catches most cases, 150ms delayed pass
        // catches late frame updates when cycling between note/writer modes.
        DispatchQueue.main.async {
            Self.reconcilePages(coord: coord)
            Self.layoutPageTiles(coord: coord, in: scrollView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak coord] in
            guard let coord else { return }
            Self.layoutPageTiles(coord: coord, in: scrollView)
        }

        return scrollView
    }

    // MARK: - updateNSView

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
        // Refresh the struct snapshot so static helpers (layoutPageTiles,
        // reconcilePages) read current isDark / formatState values.
        coord.parent = self
        guard let storage = coord.storage,
              let canvas = coord.canvas
        else { return }

        // Theme update
        if coord.lastIsDark != isDark {
            coord.lastIsDark = isDark
            storage.isDark = isDark
            storage.reapplyFormatting()
            canvas.isDark = isDark
            scrollView.backgroundColor = canvasColor
            for tile in coord.pageTiles {
                tile.backgroundColor = pageColor
                tile.isDark = isDark
            }
            coord.titlePageView?.isDark = isDark
        }

        // Spread mode may need horizontal scrolling
        scrollView.hasHorizontalScroller = formatState.isSpreadView

        // Format state update
        storage.formatState = formatState
        storage.reapplyFormatting()
        let textAreaSize = formatState.textAreaSize
        let marginPoints = formatState.margins.points
        for tile in coord.pageTiles {
            tile.textContainer?.size = textAreaSize
            tile.textContainerInset = NSSize(width: marginPoints, height: marginPoints)
            tile.frame = NSRect(origin: tile.frame.origin, size: formatState.pageSize.size)
        }

        // Editable update
        for tile in coord.pageTiles {
            tile.isEditable = isEditable
        }

        // Text sync — only if not user-editing and text differs
        if !coord.isUserEditing && storage.string != text {
            storage.skipFormatting = true
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullRange, with: text)
            storage.skipFormatting = false
            storage.reapplyFormatting()
        }

        // Reconcile pages + layout tiles
        Self.reconcilePages(coord: coord)
        Self.layoutPageTiles(coord: coord, in: scrollView)
    }

    // MARK: - addPage

    private func addPage(coord: Coordinator) {
        guard let layoutManager = coord.layoutManager,
              let canvas = coord.canvas
        else { return }

        let textAreaSize = formatState.textAreaSize
        let pageSize = formatState.pageSize.size
        let marginPoints = formatState.margins.points

        // Create text container
        let container = NSTextContainer(size: textAreaSize)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)

        // Create PageTileView
        let tile = PageTileView(frame: NSRect(origin: .zero, size: pageSize),
                                textContainer: container)
        tile.isEditable = isEditable
        tile.isSelectable = true
        tile.drawsBackground = true
        tile.backgroundColor = pageColor
        tile.isVerticallyResizable = false
        tile.isHorizontallyResizable = false
        tile.textContainerInset = NSSize(width: marginPoints, height: marginPoints)
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

        // Shadow via layer
        tile.wantsLayer = true
        if let layer = tile.layer {
            layer.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
            layer.shadowOpacity = 1
            layer.shadowOffset = CGSize(width: 0, height: -2)
            layer.shadowRadius = 8
        }

        // Wire delegate and format state for header/footer rendering
        tile.delegate = coord
        tile.formatState = formatState
        tile.isDark = isDark
        tile.pageIndex = coord.pageTiles.count

        // Add to canvas
        canvas.addSubview(tile)
        coord.pageTiles.append(tile)
    }

    // MARK: - reconcilePages

    private static func reconcilePages(coord: Coordinator) {
        guard let layoutManager = coord.layoutManager,
              let storage = coord.storage
        else { return }

        // Force layout to completion
        guard let lastContainer = layoutManager.textContainers.last else { return }
        layoutManager.ensureLayout(for: lastContainer)

        // Add pages while text overflows the last container
        while let tailContainer = layoutManager.textContainers.last {
            let charRange = layoutManager.characterRange(forGlyphRange:
                layoutManager.glyphRange(for: tailContainer), actualGlyphRange: nil)
            if charRange.location + charRange.length < storage.length {
                coord.parent.addPage(coord: coord)
                guard let newTail = layoutManager.textContainers.last else { break }
                layoutManager.ensureLayout(for: newTail)
            } else {
                break
            }
        }

        // Remove trailing empty pages (keep at least 1)
        while coord.pageTiles.count > 1 {
            guard let lastContainer = layoutManager.textContainers.last else { break }
            let glyphRange = layoutManager.glyphRange(for: lastContainer)
            if glyphRange.length == 0 {
                coord.pageTiles.last?.removeFromSuperview()
                coord.pageTiles.removeLast()
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
            } else {
                break
            }
        }
    }

    // MARK: - layoutPageTiles

    /// Gap between left and right pages in spread (book) view.
    private static let spineGap: CGFloat = 8

    private static func layoutPageTiles(coord: Coordinator, in scrollView: NSScrollView) {
        guard let canvas = coord.canvas else { return }

        let formatState = coord.parent.formatState
        let pageHeight = formatState.pageSize.size.height
        let pageWidth = formatState.pageSize.size.width
        let gap = PagedDocumentView.pageGap
        let padding = PagedDocumentView.canvasPadding
        let hasTitlePage = formatState.showTitlePage
        let isSpread = formatState.isSpreadView

        // In spread mode, the canvas must fit two pages side by side + spine gap
        let spreadWidth = pageWidth * 2 + spineGap
        let minContentWidth = isSpread
            ? spreadWidth + padding * 2
            : pageWidth + padding * 2
        let canvasWidth = max(scrollView.contentSize.width, minContentWidth)

        // Collect all views (title + body) for unified spread layout
        var allViews: [NSView] = []

        // — Title page —
        if hasTitlePage {
            if coord.titlePageView == nil {
                let tpv = TitlePageView()
                tpv.formatState = formatState
                tpv.isDark = coord.parent.isDark
                tpv.wantsLayer = true
                if let layer = tpv.layer {
                    layer.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
                    layer.shadowOpacity = 1
                    layer.shadowOffset = CGSize(width: 0, height: -2)
                    layer.shadowRadius = 8
                }
                canvas.addSubview(tpv)
                coord.titlePageView = tpv
            }
            coord.titlePageView?.formatState = formatState
            coord.titlePageView?.isDark = coord.parent.isDark
            coord.titlePageView?.needsDisplay = true
            if let tpv = coord.titlePageView {
                allViews.append(tpv)
            }
        } else {
            coord.titlePageView?.removeFromSuperview()
            coord.titlePageView = nil
        }

        // — Body page tiles —
        let pageOffset = hasTitlePage ? 1 : 0
        for (index, tile) in coord.pageTiles.enumerated() {
            tile.pageIndex = index + pageOffset
            tile.isTitlePage = false
            tile.formatState = formatState
            tile.isDark = coord.parent.isDark
            tile.needsDisplay = true
            allViews.append(tile)
        }

        // — Position all pages —
        var yOffset = padding

        if isSpread {
            // Spread (book) layout: pages in pairs, left + right
            let spreadCenterX = canvasWidth / 2
            let leftX = spreadCenterX - pageWidth - spineGap / 2
            let rightX = spreadCenterX + spineGap / 2

            var i = 0
            while i < allViews.count {
                // Left page
                allViews[i].frame = NSRect(
                    x: max(padding, leftX), y: yOffset,
                    width: pageWidth, height: pageHeight
                )

                // Right page (if exists)
                if i + 1 < allViews.count {
                    allViews[i + 1].frame = NSRect(
                        x: max(padding + pageWidth + spineGap, rightX), y: yOffset,
                        width: pageWidth, height: pageHeight
                    )
                    i += 2
                } else {
                    i += 1
                }

                yOffset += pageHeight + gap
            }
        } else {
            // Single-page layout (original behavior)
            let x = max(padding, (canvasWidth - pageWidth) / 2)
            for view in allViews {
                view.frame = NSRect(x: x, y: yOffset, width: pageWidth, height: pageHeight)
                yOffset += pageHeight + gap
            }
        }

        // Canvas size
        let canvasHeight = yOffset - gap + padding
        canvas.frame = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    }

    // MARK: - dismantleNSView

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        // Remove frame change observer
        if let obs = coordinator.frameObserver {
            NotificationCenter.default.removeObserver(obs)
            coordinator.frameObserver = nil
        }

        // Cancel any pending reconciliation
        coordinator.reconcileWorkItem?.cancel()

        // Remove title page view
        coordinator.titlePageView?.removeFromSuperview()
        coordinator.titlePageView = nil

        // Tear down TextKit stack to prevent dangling references
        if let layoutManager = coordinator.layoutManager {
            coordinator.storage?.removeLayoutManager(layoutManager)
            for container in layoutManager.textContainers {
                layoutManager.removeTextContainer(at: 0)
                _ = container
            }
        }

        // Remove all page tiles from canvas
        for tile in coordinator.pageTiles {
            tile.delegate = nil
            tile.removeFromSuperview()
        }
        coordinator.pageTiles.removeAll()
        coordinator.layoutManager = nil
        coordinator.storage = nil
        coordinator.canvas = nil
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PagedDocumentView
        var storage: WriterTextStorage?
        var layoutManager: NSLayoutManager?
        var canvas: PageCanvasView?
        var pageTiles: [PageTileView] = []
        var titlePageView: TitlePageView?
        var lastIsDark: Bool
        var lastShowTitlePage: Bool = false
        var isUserEditing = false
        // SAFETY: Only accessed from MainActor (textDidChange delegate + DispatchQueue.main).
        // nonisolated(unsafe) satisfies the compiler since Coordinator is not @MainActor.
        nonisolated(unsafe) var reconcileWorkItem: DispatchWorkItem?
        /// Observes clip view frame changes to re-center pages on window resize.
        var frameObserver: NSObjectProtocol?

        init(_ parent: PagedDocumentView) {
            self.parent = parent
            self.lastIsDark = parent.isDark
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }

            // Don't sync during IME composition
            guard !tv.hasMarkedText() else { return }

            isUserEditing = true
            parent.text = storage?.string ?? tv.string
            isUserEditing = false

            // Debounced page reconciliation (50ms)
            reconcileWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    PagedDocumentView.reconcilePages(coord: self)
                    if let scrollView = self.canvas?.enclosingScrollView {
                        PagedDocumentView.layoutPageTiles(coord: self, in: scrollView)
                    }
                }
            }
            reconcileWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
        }
    }
}

// MARK: - PageCanvasView

/// The background view that holds all page tiles.
/// Uses `isFlipped = true` for top-to-bottom layout.
final class PageCanvasView: NSView {

    var isDark: Bool {
        didSet { needsDisplay = true }
    }

    init(isDark: Bool) {
        self.isDark = isDark
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isDark
            ? NSColor(white: 0.15, alpha: 1)
            : NSColor(white: 0.85, alpha: 1)
        color.setFill()
        dirtyRect.fill()
    }
}

// MARK: - PageTileView

/// A single page tile — an NSTextView representing one page of the document.
/// Draws page numbers, running head, and header/footer text in the margin areas.
/// Shadow is set externally via its layer.
final class PageTileView: NSTextView {

    /// Page index (0-based). Set by PagedDocumentView during layout.
    var pageIndex: Int = 0

    /// Whether this is a title page (skips header on first page for some styles).
    var isTitlePage: Bool = false

    /// Weak reference to format state for header/footer rendering.
    // SAFETY: nonisolated(unsafe) because NSTextView is not @MainActor but
    // formatState is only set from MainActor (layoutPageTiles / addPage).
    // draw() is always called on the main thread by AppKit.
    nonisolated(unsafe) var formatState: WriterFormatState?

    /// Whether currently rendering for export (forces black text).
    var isExporting: Bool = false

    /// Dark mode flag, set by PagedDocumentView during layout.
    var isDark: Bool = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let state = formatState else { return }
        drawHeaderFooter(state: state)
    }

    // MARK: - Header / Footer Drawing

    private func drawHeaderFooter(state: WriterFormatState) {
        let margin = state.margins.points
        let pageWidth = bounds.width
        let font = NSFont(name: state.fontFamily, size: state.fontSize - 2)
            ?? NSFont.systemFont(ofSize: state.fontSize - 2)
        let textColor: NSColor = isExporting
            ? .black
            : (isDark ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.3, alpha: 1))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]

        let pageNumber = pageIndex + 1
        let inset: CGFloat = margin  // align with text area

        // Draw page numbers
        if state.showPageNumbers && !isTitlePage {
            let pageNumStr: String
            // Running head + page number (MLA style: "Smith 1")
            if !state.runningHead.isEmpty {
                pageNumStr = "\(state.runningHead) \(pageNumber)"
            } else {
                pageNumStr = "\(pageNumber)"
            }
            let attrStr = NSAttributedString(string: pageNumStr, attributes: attrs)
            let size = attrStr.size()

            let pos = state.pageNumberPosition
            let y: CGFloat
            let x: CGFloat

            switch pos {
            case .topLeft, .topCenter, .topRight:
                y = (margin - size.height) / 2  // center in top margin
            case .bottomLeft, .bottomCenter, .bottomRight:
                y = bounds.height - margin + (margin - size.height) / 2
            }

            switch pos {
            case .topLeft, .bottomLeft:
                x = inset
            case .topCenter, .bottomCenter:
                x = (pageWidth - size.width) / 2
            case .topRight, .bottomRight:
                x = pageWidth - inset - size.width
            }

            attrStr.draw(at: NSPoint(x: x, y: y))
        }

        // Draw header text (top, centered) — skip on title page
        if !state.headerText.isEmpty && !isTitlePage {
            let attrStr = NSAttributedString(string: state.headerText, attributes: attrs)
            let size = attrStr.size()
            let x = (pageWidth - size.width) / 2
            let y = (margin - size.height) / 2
            attrStr.draw(at: NSPoint(x: x, y: y))
        }

        // Draw footer text (bottom, centered) — skip on title page
        if !state.footerText.isEmpty && !isTitlePage {
            let attrStr = NSAttributedString(string: state.footerText, attributes: attrs)
            let size = attrStr.size()
            let x = (pageWidth - size.width) / 2
            let y = bounds.height - margin + (margin - size.height) / 2
            attrStr.draw(at: NSPoint(x: x, y: y))
        }
    }
}

// MARK: - TitlePageView

/// A standalone NSView rendering the title page content.
/// Not part of the layout manager text flow — rendered from metadata fields.
final class TitlePageView: NSView {

    var formatState: WriterFormatState?
    var isDark: Bool = false
    var isExporting: Bool = false

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw page background
        let bgColor: NSColor = isExporting ? .white : (isDark ? NSColor(white: 0.18, alpha: 1) : .white)
        bgColor.setFill()
        bounds.fill()

        guard let state = formatState else { return }
        drawTitlePageContent(state: state)
    }

    private func drawTitlePageContent(state: WriterFormatState) {
        let pageWidth = bounds.width
        let pageHeight = bounds.height
        let margin = state.margins.points

        let font = NSFont(name: state.fontFamily, size: state.fontSize)
            ?? NSFont.systemFont(ofSize: state.fontSize)
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let textColor: NSColor = isExporting ? .black
            : (isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1))

        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.lineSpacing = font.pointSize * 0.5  // approximate double spacing

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centered,
        ]

        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: boldFont,
            .foregroundColor: textColor,
            .paragraphStyle: centered,
        ]

        let textWidth = pageWidth - margin * 2

        switch state.activePreset == .custom ? state.basePreset : state.activePreset {
        case .apa:
            // APA: Title bold at ~1/3, author, institution, course, instructor, date
            let startY = pageHeight * 0.33
            var y = startY
            let lineHeight = font.pointSize * 2.4  // double-spaced

            drawCenteredLine(state.titlePageTitle, attrs: boldAttrs, at: y, width: textWidth, margin: margin)
            y += lineHeight

            if !state.titlePageAuthor.isEmpty {
                drawCenteredLine(state.titlePageAuthor, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
                y += lineHeight
            }
            if !state.titlePageInstitution.isEmpty {
                drawCenteredLine(state.titlePageInstitution, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
                y += lineHeight
            }
            if !state.titlePageCourse.isEmpty {
                drawCenteredLine(state.titlePageCourse, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
                y += lineHeight
            }
            if !state.titlePageInstructor.isEmpty {
                drawCenteredLine(state.titlePageInstructor, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
                y += lineHeight
            }
            if !state.titlePageDate.isEmpty {
                drawCenteredLine(state.titlePageDate, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
            }

        case .chicago:
            // Chicago: Title at ~1/3, author at ~2/3, course+instructor+date at bottom
            let lineHeight = font.pointSize * 2.4
            let titleY = pageHeight * 0.33
            drawCenteredLine(state.titlePageTitle, attrs: baseAttrs, at: titleY, width: textWidth, margin: margin)

            let authorY = pageHeight * 0.60
            drawCenteredLine(state.titlePageAuthor, attrs: baseAttrs, at: authorY, width: textWidth, margin: margin)

            var bottomY = pageHeight - margin - lineHeight * 3
            if !state.titlePageCourse.isEmpty {
                drawCenteredLine(state.titlePageCourse, attrs: baseAttrs, at: bottomY, width: textWidth, margin: margin)
                bottomY += lineHeight
            }
            if !state.titlePageInstructor.isEmpty {
                drawCenteredLine(state.titlePageInstructor, attrs: baseAttrs, at: bottomY, width: textWidth, margin: margin)
                bottomY += lineHeight
            }
            if !state.titlePageDate.isEmpty {
                drawCenteredLine(state.titlePageDate, attrs: baseAttrs, at: bottomY, width: textWidth, margin: margin)
            }

        case .mla, .custom:
            // MLA: Everything centered vertically
            let lineHeight = font.pointSize * 2.4
            let lines = [
                state.titlePageTitle,
                state.titlePageAuthor,
                state.titlePageInstructor,
                state.titlePageCourse,
                state.titlePageDate,
            ].filter { !$0.isEmpty }

            let totalHeight = CGFloat(lines.count) * lineHeight
            var y = (pageHeight - totalHeight) / 2

            for line in lines {
                drawCenteredLine(line, attrs: baseAttrs, at: y, width: textWidth, margin: margin)
                y += lineHeight
            }
        }
    }

    private func drawCenteredLine(_ text: String, attrs: [NSAttributedString.Key: Any], at y: CGFloat, width: CGFloat, margin: CGFloat) {
        guard !text.isEmpty else { return }
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()
        let x = margin + (width - size.width) / 2
        attrStr.draw(at: NSPoint(x: x, y: y))
    }
}
