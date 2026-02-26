import AppKit

// MARK: - ClickableTextView
// Bare NSTextView subclass with wikilink click handling.
// This is the ONLY NSTextView subclass in the app.
//
// In v3, this sits inside an NSScrollView (created by ProseEditorRepresentable).
// The NSScrollView handles all scrolling natively — no SwiftUI ScrollView wrapping.
// This eliminates the SwiftUI ↔ AppKit layout feedback loop that caused 100% CPU
// on resize/Enter, because NSTextView manages its own height internally.
//
// Pitfall guarantees:
// - #1: No layout() override. EVER.
// - #2: draw() clears dirty rect before super.draw(). Required because
//       drawsBackground = false (for SwiftUI theme transparency). Without
//       clearing, old glyph images persist as ghost artifacts at scroll edges.
//       CGContext.clear is a cheap memset, not a draw call.
// - #9: Deferred reflow — text freezes during live resize (window drag / sidebar drag).
//       Reflows once on mouse-up. Same technique Apple Notes uses.

final class ClickableTextView: NSTextView {

    // MARK: - Notifications (Right-Click → Ideas / Brain Dumps)
    // Posted when user selects "New Idea" or "New Brain Dump" from the editor context menu.
    // NoteTabView observes these to open the IdeasPanel with the correct tab.
    static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")

    // MARK: - Wikilink Click Handling

    /// Closure called when user clicks a [[wikilink]]. Receives the link title.
    var onWikilinkClick: ((String) -> Void)?

    // MARK: - Per-Page Undo Manager
    // Override the default undo manager (which comes from the window's responder chain)
    // so each page has its own isolated undo history. Set by the Coordinator on page swap.
    var pageUndoManager: UndoManager?

    override var undoManager: UndoManager? {
        pageUndoManager ?? super.undoManager
    }

    // MARK: - Deferred Reflow (Pitfall #9)
    // During live resize, freeze the text container width so NSLayoutManager
    // doesn't reflow O(document) on every frame. Reflow once on mouse-up.

    private var frozenWidth: CGFloat?

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        // Freeze: stop the text container from tracking the view width
        textContainer?.widthTracksTextView = false
        frozenWidth = textContainer?.containerSize.width
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        // Unfreeze: let the text container track width again, reflow once
        textContainer?.widthTracksTextView = true
        let newWidth = bounds.width - (textContainerInset.width * 2)
        textContainer?.containerSize = NSSize(width: max(newWidth, 0),
                                              height: CGFloat.greatestFiniteMagnitude)
        frozenWidth = nil
    }

    // MARK: - Pitfall #1: NEVER override layout()
    // layout() fires on every @Observable mutation anywhere in the app.
    // Calling ensureLayout() here causes O(document) text layout per SwiftUI pass.

    // MARK: - Ghost Line Fix (drawsBackground = false requires manual clear)

    override func draw(_ dirtyRect: NSRect) {
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.clear(dirtyRect)
        }
        super.draw(dirtyRect)
    }

    // Expand invalidation rects to cover emoji glyph overflow — but ONLY during
    // text edits. During scroll, the system's invalidation rects are already correct
    // and expanding them causes ~2x overdraw (16pt expansion on every scroll step).
    //
    // The emoji overflow issue only occurs when content CHANGES (typing/pasting emoji).
    // During scroll, line fragments are already laid out and emoji is pre-rendered.
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        if let mds = textStorage as? MarkdownTextStorage, mds.isProcessingEdits {
            let expanded = NSRect(
                x: invalidRect.origin.x,
                y: max(0, invalidRect.origin.y - 8),
                width: invalidRect.width,
                height: min(bounds.height - max(0, invalidRect.origin.y - 8),
                            invalidRect.height + 16)
            )
            super.setNeedsDisplay(expanded)
        } else {
            super.setNeedsDisplay(invalidRect)
        }
    }

    override var isOpaque: Bool { false }

    // MARK: - Find & Replace Key Handling
    // SwiftUI's responder chain doesn't route Cmd+F to embedded NSTextViews.
    // We catch it here and trigger NSTextFinder's built-in find bar.

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Z — Undo
        // Handle directly because SwiftUI's NSHostingView can intercept
        // the responder chain's undo: action, preventing it from reaching
        // this NSTextView. Same pattern as Cmd+F below.
        if flags == .command, event.charactersIgnoringModifiers == "z" {
            if undoManager?.canUndo == true {
                undoManager?.undo()
                return true
            }
            return false
        }

        // Cmd+Shift+Z — Redo
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "Z" {
            if undoManager?.canRedo == true {
                undoManager?.redo()
                return true
            }
            return false
        }

        // Cmd+F — Show Find bar
        if flags == .command, event.charactersIgnoringModifiers == "f" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+G — Find Next
        if flags == .command, event.charactersIgnoringModifiers == "g" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.nextMatch.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+Shift+G — Find Previous
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "G" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.previousMatch.rawValue
            performTextFinderAction(item)
            return true
        }

        // Cmd+Option+F — Show Replace bar
        if flags == [.command, .option], event.charactersIgnoringModifiers == "f" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showReplaceInterface.rawValue
            performTextFinderAction(item)
            return true
        }

        // Esc — Hide Find bar (if visible)
        if event.keyCode == 53 { // Esc key
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.hideFindInterface.rawValue
            performTextFinderAction(item)
            // Don't return true — let Esc propagate for other uses too
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Wikilink Mouse Handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let idx = characterIndexForInsertion(at: point)

        if idx < string.utf16.count,
           let attrs = textStorage?.attributes(at: idx, effectiveRange: nil),
           let linkTitle = attrs[NSAttributedString.Key("EpistemosWikilink")] as? String {
            onWikilinkClick?(linkTitle)
            return
        }
        super.mouseDown(with: event)
    }

    // MARK: - Context Menu (Right-Click → Ideas / Brain Dumps)

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        menu.addItem(NSMenuItem.separator())

        let ideaItem = NSMenuItem(
            title: "New Idea at This Line",
            action: #selector(createIdeaAtLine),
            keyEquivalent: ""
        )
        ideaItem.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Idea")
        ideaItem.target = self
        menu.addItem(ideaItem)

        let dumpItem = NSMenuItem(
            title: "New Brain Dump at This Line",
            action: #selector(createBrainDumpAtLine),
            keyEquivalent: ""
        )
        dumpItem.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Brain Dump")
        dumpItem.target = self
        menu.addItem(dumpItem)

        return menu
    }

    @objc private func createIdeaAtLine() {
        NotificationCenter.default.post(name: Self.createIdeaNotification, object: nil)
    }

    @objc private func createBrainDumpAtLine() {
        NotificationCenter.default.post(name: Self.createBrainDumpNotification, object: nil)
    }
}
