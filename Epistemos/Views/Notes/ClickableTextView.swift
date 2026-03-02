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

    // MARK: - Notifications (Right-Click → Ideas / Brain Dumps / AI)
    // Posted when user selects context menu actions.
    // NoteTabView observes these to open IdeasPanel or trigger Note Chat.
    static let createIdeaNotification = Notification.Name("EpistemosCreateIdeaAtLine")
    static let createBrainDumpNotification = Notification.Name("EpistemosCreateBrainDumpAtLine")
    /// AI operation from context menu. userInfo: ["operation": String, "selectedText": String?]
    static let aiOperationNotification = Notification.Name("EpistemosAIOperation")

    // MARK: - Wikilink Click Handling

    /// Closure called when user clicks a [[wikilink]]. Receives the link title.
    var onWikilinkClick: ((String) -> Void)?

    /// Closure called when user clicks a ((block-ref)). Receives the block ID.
    var onBlockRefClick: ((String) -> Void)?

    /// Closure called when user clicks in the left gutter (fold disclosure area).
    /// Receives click point in text view coordinates. Returns true if handled.
    var onGutterClick: ((CGPoint) -> Bool)?

    /// Closure called when user presses Cmd+. to toggle fold at cursor position.
    var onFoldToggle: (() -> Void)?

    /// Page ID for scoping notifications to the correct tab.
    var pageId: String?

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

        // Cmd+. — Toggle fold at cursor
        if flags == .command, event.charactersIgnoringModifiers == "." {
            onFoldToggle?()
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

    // MARK: - Wikilink Hover Glow

    /// Character range currently highlighted by mouse hover. nil = no hover.
    private var hoveredLinkRange: NSRange?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Ensure we get mouseMoved for hover detection
        for area in trackingAreas where area.owner === self && area.options.contains(.mouseMoved) {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let idx = characterIndexForInsertion(at: point)

        var effectiveRange = NSRange(location: 0, length: 0)
        let isLink: Bool
        if idx < (textStorage?.length ?? 0),
           let attrs = textStorage?.attributes(at: idx, effectiveRange: &effectiveRange) {
            isLink = attrs[NSAttributedString.Key("EpistemosWikilink")] != nil
                || attrs[NSAttributedString.Key("EpistemosBlockRef")] != nil
        } else {
            isLink = false
        }

        let newRange = isLink ? effectiveRange : nil

        if newRange != hoveredLinkRange {
            // Clear old hover
            if let old = hoveredLinkRange, old.location + old.length <= (textStorage?.length ?? 0) {
                textStorage?.removeAttribute(.backgroundColor, range: old)
                // Re-apply base styling by triggering a restyle of just this range
                if let mds = textStorage as? MarkdownTextStorage {
                    mds.reapplyStyles(in: old)
                }
            }
            // Apply new hover glow
            if let new = newRange, new.location + new.length <= (textStorage?.length ?? 0) {
                let glowBg: NSColor = (textStorage as? MarkdownTextStorage)?.isDark == true
                    ? NSColor(red: 0.40, green: 0.65, blue: 1.0, alpha: 0.22)
                    : NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.16)
                textStorage?.addAttribute(.backgroundColor, value: glowBg, range: new)
            }
            hoveredLinkRange = newRange
        }

        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        if let old = hoveredLinkRange, old.location + old.length <= (textStorage?.length ?? 0) {
            textStorage?.removeAttribute(.backgroundColor, range: old)
            if let mds = textStorage as? MarkdownTextStorage {
                mds.reapplyStyles(in: old)
            }
        }
        hoveredLinkRange = nil
        super.mouseExited(with: event)
    }

    // MARK: - Wikilink Mouse Handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Check gutter click (fold disclosure triangles) before anything else
        if point.x < textContainerInset.width, onGutterClick?(point) == true {
            return
        }

        let idx = characterIndexForInsertion(at: point)

        if idx < string.utf16.count,
           let attrs = textStorage?.attributes(at: idx, effectiveRange: nil) {
            if let linkTitle = attrs[NSAttributedString.Key("EpistemosWikilink")] as? String {
                onWikilinkClick?(linkTitle)
                return
            }
            if let blockId = attrs[NSAttributedString.Key("EpistemosBlockRef")] as? String {
                onBlockRefClick?(blockId)
                return
            }
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

        // MARK: AI Assistant submenu
        menu.addItem(NSMenuItem.separator())

        let aiMenu = NSMenu(title: "AI Assistant")
        let hasSelection = selectedRange().length > 0

        if hasSelection {
            aiMenu.addItem(makeAIItem("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite"))
            aiMenu.addItem(makeAIItem("Summarize", icon: "text.quote", op: "summarize"))
            aiMenu.addItem(makeAIItem("Expand", icon: "arrow.up.left.and.arrow.down.right", op: "expand"))
            aiMenu.addItem(makeAIItem("Simplify", icon: "text.redaction", op: "simplify"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Convert to List", icon: "list.bullet", op: "toList"))
            aiMenu.addItem(makeAIItem("Convert to Table", icon: "tablecells", op: "toTable"))
        } else {
            aiMenu.addItem(makeAIItem("Continue Writing", icon: "text.append", op: "continue"))
            aiMenu.addItem(makeAIItem("Generate Outline", icon: "list.number", op: "outline"))
            aiMenu.addItem(makeAIItem("Suggest Structure", icon: "rectangle.3.group", op: "structure"))
            aiMenu.addItem(NSMenuItem.separator())
            aiMenu.addItem(makeAIItem("Restructure Note", icon: "arrow.triangle.branch", op: "restructure"))
        }

        let aiSubmenuItem = NSMenuItem(title: "AI Assistant", action: nil, keyEquivalent: "")
        aiSubmenuItem.submenu = aiMenu
        aiSubmenuItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI")
        menu.addItem(aiSubmenuItem)

        return menu
    }

    private func makeAIItem(_ title: String, icon: String, op: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleAIOperation(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        item.target = self
        item.representedObject = op
        return item
    }

    @objc private func createIdeaAtLine() {
        NotificationCenter.default.post(
            name: Self.createIdeaNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func createBrainDumpAtLine() {
        NotificationCenter.default.post(
            name: Self.createBrainDumpNotification, object: nil,
            userInfo: pageId.map { ["pageId": $0] }
        )
    }

    @objc private func handleAIOperation(_ sender: NSMenuItem) {
        guard let op = sender.representedObject as? String else { return }
        var userInfo: [String: String] = ["operation": op]
        if let pageId { userInfo["pageId"] = pageId }
        let sel = selectedRange()
        if sel.length > 0, let str = string as NSString? {
            userInfo["selectedText"] = str.substring(with: sel)
        }
        NotificationCenter.default.post(name: Self.aiOperationNotification, object: nil, userInfo: userInfo)
    }
}
