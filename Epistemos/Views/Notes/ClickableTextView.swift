import AppKit
import UniformTypeIdentifiers

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
    /// Block property edit from context menu. userInfo: ["lineText": String, "lineRange": NSRange, "pageId": String?]
    static let blockPropertyNotification = Notification.Name("EpistemosBlockPropertyEdit")

    // MARK: - Wikilink Click Handling

    /// Closure called when user clicks a [[wikilink]]. Receives the link title.
    var onWikilinkClick: ((String) -> Void)?

    /// Closure called when user clicks a ((block-ref)). Receives the block ID.
    var onBlockRefClick: ((String) -> Void)?

    /// Closure called when user selects "Open in Graph" from context menu.
    /// Receives a page ID (current note or wikilink target).
    var onOpenInGraph: ((String) -> Void)?

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

    // MARK: - Key Handling

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Z — Undo
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

        // Cmd+= / Cmd++ — Zoom In
        if flags == .command, let chars = event.charactersIgnoringModifiers,
           chars == "=" || chars == "+" {
            zoomIn()
            return true
        }

        // Cmd+- — Zoom Out
        if flags == .command, event.charactersIgnoringModifiers == "-" {
            zoomOut()
            return true
        }

        // Cmd+0 — Reset Zoom
        if flags == .command, event.charactersIgnoringModifiers == "0" {
            resetZoom()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Zoom

    private static let minZoom: CGFloat = 0.5
    private static let maxZoom: CGFloat = 2.0
    private static let zoomStep: CGFloat = 0.1

    override func magnify(with event: NSEvent) {
        guard let sv = enclosingScrollView else { return }
        let newMag = max(Self.minZoom, min(Self.maxZoom, sv.magnification + event.magnification))
        sv.magnification = newMag
    }

    private func zoomIn() {
        guard let sv = enclosingScrollView else { return }
        sv.magnification = min(Self.maxZoom, sv.magnification + Self.zoomStep)
    }

    private func zoomOut() {
        guard let sv = enclosingScrollView else { return }
        sv.magnification = max(Self.minZoom, sv.magnification - Self.zoomStep)
    }

    private func resetZoom() {
        enclosingScrollView?.magnification = 1.0
    }

    // MARK: - Insert Image

    @objc func insertImage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.insertImageAttachment(from: url)
        }
    }

    func insertImageAttachment(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }

        let attachment = NSTextAttachment()
        // Scale to fit readable width — max 600px, maintain aspect ratio
        let maxWidth: CGFloat = 600
        let imageSize = image.size
        let displaySize: NSSize
        if imageSize.width > maxWidth {
            let scale = maxWidth / imageSize.width
            displaySize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        } else {
            displaySize = imageSize
        }
        image.size = displaySize
        let cell = NSTextAttachmentCell(imageCell: image)
        attachment.attachmentCell = cell

        let attrStr = NSMutableAttributedString(attachment: attachment)
        attrStr.addAttribute(NSAttributedString.Key("EpistemosImagePath"),
                             value: url.lastPathComponent,
                             range: NSRange(location: 0, length: attrStr.length))

        let insertLoc = selectedRange().location
        let insertRange = NSRange(location: insertLoc, length: 0)
        if shouldChangeText(in: insertRange, replacementString: attrStr.string) {
            textStorage?.insert(attrStr, at: insertLoc)
            didChangeText()
        }
    }

    // MARK: - Insert Table

    @objc func insertMarkdownTable(_ sender: Any?) {
        let table = "\n| Column 1 | Column 2 | Column 3 |\n| -------- | -------- | -------- |\n| cell     | cell     | cell     |\n"
        let insertLoc = selectedRange().location
        let insertRange = NSRange(location: insertLoc, length: 0)
        if shouldChangeText(in: insertRange, replacementString: table) {
            textStorage?.replaceCharacters(in: insertRange, with: table)
            didChangeText()
            // Place cursor in first data cell
            if let offset = table.range(of: "| cell") {
                let charOffset = table.distance(from: table.startIndex, to: offset.lowerBound) + 2
                setSelectedRange(NSRange(location: insertLoc + charOffset, length: 4))
            }
        }
    }

    // MARK: - Drag & Drop Images

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]
        ) as? [URL], let url = fileURLs.first {
            insertImageAttachment(from: url)
            return true
        }
        return super.performDragOperation(sender)
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

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        // Reveal in Graph
        if let pid = pageId {
            menu.addItem(NSMenuItem.separator())

            let graphItem = NSMenuItem(
                title: "Reveal in Graph",
                action: #selector(contextRevealInGraph(_:)),
                keyEquivalent: ""
            )
            graphItem.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Graph")
            graphItem.target = self
            graphItem.representedObject = pid
            menu.addItem(graphItem)
        }

        // Set Property
        let propItem = NSMenuItem(
            title: "Set Property\u{2026}",
            action: #selector(openBlockPropertySheet),
            keyEquivalent: ""
        )
        propItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "Property")
        propItem.target = self
        menu.addItem(propItem)

        // Insert submenu
        menu.addItem(NSMenuItem.separator())

        let insertMenu = NSMenu(title: "Insert")
        let tableItem = NSMenuItem(title: "Table", action: #selector(insertMarkdownTable(_:)), keyEquivalent: "")
        tableItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Table")
        tableItem.target = self
        insertMenu.addItem(tableItem)

        let imageItem = NSMenuItem(title: "Image\u{2026}", action: #selector(insertImage(_:)), keyEquivalent: "")
        imageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        imageItem.target = self
        insertMenu.addItem(imageItem)

        let insertSubmenuItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertSubmenuItem.submenu = insertMenu
        insertSubmenuItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Insert")
        menu.addItem(insertSubmenuItem)

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

        // AI Assistant submenu
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

    @objc private func contextRevealInGraph(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? String else { return }
        onOpenInGraph?(pid)
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

    @objc private func openBlockPropertySheet() {
        let nsStr = string as NSString
        let cursorLoc = selectedRange().location
        let lineRange = nsStr.lineRange(for: NSRange(location: cursorLoc, length: 0))
        let lineText = nsStr.substring(with: lineRange).trimmingCharacters(in: .newlines)

        var userInfo: [String: Any] = [
            "lineText": lineText,
            "lineRange": lineRange
        ]
        if let pageId { userInfo["pageId"] = pageId }
        NotificationCenter.default.post(
            name: Self.blockPropertyNotification, object: nil, userInfo: userInfo
        )
    }
}
