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

        // 8. After one frame delay, reconcile pages and layout tiles
        DispatchQueue.main.async {
            Self.reconcilePages(coord: coord)
            Self.layoutPageTiles(coord: coord, in: scrollView)
        }

        return scrollView
    }

    // MARK: - updateNSView

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coord = context.coordinator
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
            }
        }

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

        // Wire delegate
        tile.delegate = coord

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
        layoutManager.ensureLayout(for: layoutManager.textContainers.last!)

        // Add pages while text overflows the last container
        while let lastContainer = layoutManager.textContainers.last {
            let charRange = layoutManager.characterRange(forGlyphRange:
                layoutManager.glyphRange(for: lastContainer), actualGlyphRange: nil)
            if charRange.location + charRange.length < storage.length {
                coord.parent.addPage(coord: coord)
                layoutManager.ensureLayout(for: layoutManager.textContainers.last!)
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

    private static func layoutPageTiles(coord: Coordinator, in scrollView: NSScrollView) {
        guard let canvas = coord.canvas else { return }

        let pageHeight = coord.parent.formatState.pageSize.size.height
        let pageWidth = coord.parent.formatState.pageSize.size.width
        let gap = PagedDocumentView.pageGap
        let padding = PagedDocumentView.canvasPadding
        let pageCount = CGFloat(coord.pageTiles.count)

        // Canvas height: all pages + gaps + padding
        let canvasHeight = pageCount * (pageHeight + gap) + padding * 2
        let canvasWidth = max(scrollView.contentSize.width, pageWidth + padding * 2)
        canvas.frame = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        // Position each tile centered horizontally
        for (index, tile) in coord.pageTiles.enumerated() {
            let x = max(padding, (canvasWidth - pageWidth) / 2)
            let y = padding + CGFloat(index) * (pageHeight + gap)
            tile.frame = NSRect(x: x, y: y, width: pageWidth, height: pageHeight)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PagedDocumentView
        var storage: WriterTextStorage?
        var layoutManager: NSLayoutManager?
        var canvas: PageCanvasView?
        var pageTiles: [PageTileView] = []
        var lastIsDark: Bool
        var isUserEditing = false
        nonisolated(unsafe) var reconcileWorkItem: DispatchWorkItem?

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
/// Shadow is set externally via its layer.
final class PageTileView: NSTextView {
    // Empty subclass — shadow is configured externally via layer properties.
}
