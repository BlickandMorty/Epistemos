import AppKit
import SwiftUI

extension NSAttributedString.Key {
    static let epdocBlockID = NSAttributedString.Key("com.epistemos.epdoc.block-id")
    static let epdocNodeType = NSAttributedString.Key("com.epistemos.epdoc.node-type")
    static let epdocSemanticMarks = NSAttributedString.Key("com.epistemos.epdoc.semantic-marks")
    static let epdocInlineNodeJSON = NSAttributedString.Key("com.epistemos.epdoc.inline-node-json")
}

@MainActor
enum EpdocAttributedProjection {
    static func make(
        session: EpdocTextKit2EditorSession,
        theme: EpistemosTheme
    ) -> NSAttributedString {
        let output = NSMutableAttributedString(string: "")
        for presentation in session.orderedEditableBlockPresentations() {
            output.append(
                makeBlock(
                    node: presentation.node,
                    presentation: presentation,
                    theme: theme
                )
            )
        }
        if output.length == 0 {
            output.append(NSAttributedString(string: "\n", attributes: bodyAttributes(theme: theme)))
        }
        return output
    }

    static func makeBlock(
        node: EpdocRichNode,
        presentation: EpdocEditableBlockPresentation? = nil,
        theme: EpistemosTheme
    ) -> NSAttributedString {
        guard let blockID = node.id else { return NSAttributedString(string: "") }
        let block = NSMutableAttributedString(string: "")
        appendInlineChildren(
            node.children,
            to: block,
            theme: theme,
            block: node,
            presentation: presentation
        )
        if block.length == 0 {
            block.append(
                NSAttributedString(
                    string: "",
                    attributes: baseAttributes(
                        for: node,
                        presentation: presentation,
                        theme: theme
                    )
                )
            )
        }
        block.append(
            NSAttributedString(
                string: "\n",
                attributes: baseAttributes(
                    for: node,
                    presentation: presentation,
                    theme: theme
                )
            )
        )
        block.addAttributes(
            [
                .epdocBlockID: blockID,
                .epdocNodeType: node.type.rawValue,
            ],
            range: NSRange(location: 0, length: block.length)
        )
        return block
    }

    static func restyleBlock(
        in storage: NSTextStorage,
        range: NSRange,
        node: EpdocRichNode,
        presentation: EpdocEditableBlockPresentation? = nil,
        theme: EpistemosTheme
    ) {
        guard range.length > 0, NSMaxRange(range) <= storage.length else { return }
        let base = baseAttributes(
            for: node,
            presentation: presentation,
            theme: theme
        )
        storage.addAttributes(base, range: range)
        storage.addAttributes(
            [
                .epdocBlockID: node.id ?? "",
                .epdocNodeType: node.type.rawValue,
            ],
            range: range
        )
        storage.enumerateAttribute(
            .epdocSemanticMarks,
            in: range,
            options: []
        ) { value, markRange, _ in
            let markTypes = Set((value as? [String]) ?? [])
            storage.addAttributes(
                visualMarkAttributes(markTypes, baseFont: base[.font] as? NSFont, theme: theme),
                range: markRange
            )
        }
    }

    private static func appendInlineChildren(
        _ children: [EpdocRichNode],
        to output: NSMutableAttributedString,
        theme: EpistemosTheme,
        block: EpdocRichNode,
        presentation: EpdocEditableBlockPresentation?
    ) {
        for child in children {
            switch child.type {
            case .text:
                let semanticMarks = child.marks.map(\.type.rawValue)
                var attributes = baseAttributes(
                    for: block,
                    presentation: presentation,
                    theme: theme
                )
                attributes[.epdocSemanticMarks] = semanticMarks
                attributes.merge(
                    visualMarkAttributes(
                        Set(semanticMarks),
                        baseFont: attributes[.font] as? NSFont,
                        theme: theme
                    )
                ) { _, new in new }
                if let link = child.marks.first(where: { $0.type == .link })?.attributes["href"],
                   case .string(let href) = link {
                    attributes[.link] = href
                }
                output.append(NSAttributedString(string: child.text ?? "", attributes: attributes))
            case .hardBreak:
                output.append(
                    NSAttributedString(
                        string: "\n",
                        attributes: baseAttributes(
                            for: block,
                            presentation: presentation,
                            theme: theme
                        )
                    )
                )
            case .image, .audio, .drawing, .footnote:
                var attributes = baseAttributes(
                    for: block,
                    presentation: presentation,
                    theme: theme
                )
                attributes[.epdocSemanticMarks] = child.marks.map(\.type.rawValue)
                if let data = try? JSONEncoder.epdocCanonical.encode(child) {
                    attributes[.epdocInlineNodeJSON] = data
                }
                output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
            default:
                appendInlineChildren(
                    child.children,
                    to: output,
                    theme: theme,
                    block: block,
                    presentation: presentation
                )
            }
        }
    }

    private static func baseAttributes(
        for node: EpdocRichNode,
        presentation: EpdocEditableBlockPresentation? = nil,
        theme: EpistemosTheme
    ) -> [NSAttributedString.Key: Any] {
        var attributes = bodyAttributes(theme: theme)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 13
        switch node.type {
        case .heading:
            let level = max(1, min(6, node.attributes["level"]?.integerValue ?? 1))
            let sizes: [CGFloat] = [38, 30, 24, 21, 19, 18]
            attributes[.font] = AppDisplayTypography.nsHeadingFont(
                size: sizes[level - 1],
                weight: level == 1 ? .bold : .semibold,
                theme: theme,
                level: min(level, 3)
            )
            attributes[.foregroundColor] = theme.resolved.headingAccent.nsColor
            paragraph.paragraphSpacingBefore = level == 1 ? 22 : 14
            paragraph.paragraphSpacing = 10
        case .codeBlock:
            attributes[.font] = AppDisplayTypography.monoUIFont(size: 16)
            attributes[.backgroundColor] = theme.resolved.card.nsColor
            paragraph.headIndent = 14
            paragraph.firstLineHeadIndent = 14
            paragraph.tailIndent = -14
        case .blockquote, .callout:
            attributes[.foregroundColor] = theme.resolved.mutedForeground.nsColor
            paragraph.headIndent = 20
            paragraph.firstLineHeadIndent = 20
        case .listItem, .checklistItem:
            paragraph.headIndent = 24
            paragraph.firstLineHeadIndent = 5
        default:
            break
        }
        if let presentation, let marker = presentation.listMarker {
            let textList: NSTextList
            switch marker {
            case .bullet:
                textList = NSTextList(markerFormat: .disc, options: 0)
            case .ordered(let itemNumber):
                textList = NSTextList(
                    markerFormat: .decimal,
                    options: [],
                    startingItemNumber: itemNumber
                )
            case .checklist(let isChecked):
                textList = NSTextList(
                    markerFormat: isChecked ? .check : .box,
                    options: 0
                )
            }
            paragraph.textLists = [textList]
            let nestingOffset = CGFloat(max(0, presentation.listNestingLevel - 1) * 18)
            paragraph.headIndent = 30 + nestingOffset
            paragraph.firstLineHeadIndent = 8 + nestingOffset
        }
        if let tableRole = presentation?.tableRole {
            attributes[.backgroundColor] = theme.resolved.card.nsColor.withAlphaComponent(0.55)
            paragraph.headIndent = max(paragraph.headIndent, 12)
            paragraph.firstLineHeadIndent = max(paragraph.firstLineHeadIndent, 12)
            paragraph.tailIndent = -12
            if tableRole == .header {
                let font = attributes[.font] as? NSFont
                    ?? AppDisplayTypography.regularUIFont(size: 18)
                attributes[.font] = NSFontManager.shared.convert(
                    font,
                    toHaveTrait: .boldFontMask
                )
            }
        }
        attributes[.paragraphStyle] = paragraph
        return attributes
    }

    private static func bodyAttributes(theme: EpistemosTheme) -> [NSAttributedString.Key: Any] {
        [
            .font: AppDisplayTypography.regularUIFont(size: 18),
            .foregroundColor: theme.resolved.foreground.nsColor,
            .backgroundColor: NSColor.clear,
        ]
    }

    private static func visualMarkAttributes(
        _ marks: Set<String>,
        baseFont: NSFont?,
        theme: EpistemosTheme
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        var font = baseFont ?? AppDisplayTypography.regularUIFont(size: 18)
        if marks.contains(EpdocMarkType.bold.rawValue) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if marks.contains(EpdocMarkType.italic.rawValue) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        if marks.contains(EpdocMarkType.code.rawValue) {
            font = AppDisplayTypography.monoUIFont(size: font.pointSize)
            attributes[.backgroundColor] = theme.resolved.card.nsColor
        }
        attributes[.font] = font
        if marks.contains(EpdocMarkType.strikethrough.rawValue) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if marks.contains(EpdocMarkType.underline.rawValue) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if marks.contains(EpdocMarkType.highlight.rawValue) {
            attributes[.backgroundColor] = theme.resolved.accent.nsColor.withAlphaComponent(0.22)
        }
        return attributes
    }
}

private extension EpdocJSONValue {
    var integerValue: Int? {
        guard case .int(let value) = self else { return nil }
        return value
    }
}

@MainActor
final class EpdocTextView: NSTextView {
    var onInsertParagraph: (@MainActor () -> Bool)?
    var onDeleteBackwardAtBlockBoundary: (@MainActor () -> Bool)?

    override func insertNewline(_ sender: Any?) {
        if onInsertParagraph?() == true { return }
        super.insertNewline(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        if onDeleteBackwardAtBlockBoundary?() == true { return }
        super.deleteBackward(sender)
    }

    static func makeTextKit2() -> (NSScrollView, EpdocTextView) {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = EpdocTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 760, height: 1000)
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 64, height: 46)
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        #if EPISTEMOS_FREE_V1
        textView.writingToolsBehavior = .none
        #endif
        scrollView.documentView = textView
        return (scrollView, textView)
    }
}

nonisolated enum EpdocContentWidthUpdatePolicy {
    static func requiresMutation(current: NSSize, proposed: NSSize) -> Bool {
        current != proposed
    }
}

nonisolated enum EpdocCheckpointSchedulingPolicy {
    static func quietWindowMilliseconds(characterCount: Int) -> Int64 {
        switch characterCount {
        case 500_000...:
            return 900
        case 100_000...:
            return 650
        default:
            return 350
        }
    }
}

@MainActor
struct EpdocTextKit2EditorRepresentable: NSViewRepresentable {
    let session: EpdocTextKit2EditorSession
    let controller: EpdocEditorChromeController
    let theme: EpistemosTheme
    let onCheckpoint: @MainActor (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            session: session,
            controller: controller,
            theme: theme,
            onCheckpoint: onCheckpoint
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        context.coordinator.attach(textView: textView, scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(theme: theme)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.flushCheckpoint()
        coordinator.detach()
        scrollView.documentView = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let session: EpdocTextKit2EditorSession
        private weak var controller: EpdocEditorChromeController?
        private let onCheckpoint: @MainActor (Data) -> Void
        private weak var textView: EpdocTextView?
        private weak var scrollView: NSScrollView?
        private var theme: EpistemosTheme
        private var isApplyingProjection = false
        private var pendingBlockID: String?
        private var pendingEditLocation: Int?
        private var pendingUndoBlockSnapshot: EpdocEditableBlockSnapshot?
        private var pendingUndoSelection: NSRange?
        private var pendingInsertedSemanticMarks: [String]?
        private var pendingInsertedSemanticRange: NSRange?
        private var isNativeUndoRegistrationDisabled = false
        private var checkpointTask: Task<Void, Never>?
        private var frameObserver: (any NSObjectProtocol)?
        private var contentWidthMode: NoteWidthMode = .normal

        private struct SelectedBlockRecord {
            let blockID: String
            let blockRange: NSRange

            var editableRange: NSRange {
                NSRange(
                    location: blockRange.location,
                    length: max(0, blockRange.length - 1)
                )
            }
        }

        init(
            session: EpdocTextKit2EditorSession,
            controller: EpdocEditorChromeController,
            theme: EpistemosTheme,
            onCheckpoint: @escaping @MainActor (Data) -> Void
        ) {
            self.session = session
            self.controller = controller
            self.theme = theme
            self.onCheckpoint = onCheckpoint
        }

        deinit {
            checkpointTask?.cancel()
        }

        func attach(textView: EpdocTextView, scrollView: NSScrollView) {
            self.textView = textView
            self.scrollView = scrollView
            textView.delegate = self
            textView.onInsertParagraph = { [weak self] in
                self?.splitSelectedBlock() == true
            }
            textView.onDeleteBackwardAtBlockBoundary = { [weak self] in
                self?.mergeWithPreviousBlockAtCaret() == true
            }
            scrollView.contentView.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.applyContentWidth()
                }
            }
            applyProjection(preservingSelection: false)
            controller?.installEditorDispatch { [weak self] command in
                self?.handle(command)
            }
            syncControllerState(markDirty: false)
            applyContentWidth(controller?.toolbarModel.widthMode ?? .normal)
            syncSelectionState()
        }

        func detach() {
            checkpointTask?.cancel()
            checkpointTask = nil
            enableNativeUndoRegistrationIfNeeded()
            pendingUndoBlockSnapshot = nil
            pendingUndoSelection = nil
            pendingInsertedSemanticMarks = nil
            pendingInsertedSemanticRange = nil
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
                self.frameObserver = nil
            }
            controller?.detachEditorDispatch()
            textView?.delegate = nil
            textView?.onInsertParagraph = nil
            textView?.onDeleteBackwardAtBlockBoundary = nil
            textView = nil
            scrollView = nil
        }

        func update(theme: EpistemosTheme) {
            guard theme != self.theme else { return }
            self.theme = theme
            applyProjection(preservingSelection: true)
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard !isApplyingProjection,
                  let storage = textView.textStorage,
                  storage.length > 0 else { return true }
            let location = min(affectedCharRange.location, max(0, storage.length - 1))
            var leadingAttributeRange = NSRange()
            let leadingBlockID = storage.attribute(
                .epdocBlockID,
                at: location,
                effectiveRange: &leadingAttributeRange
            ) as? String
            let leadingRange = leadingBlockID.flatMap {
                range(of: $0, in: storage, near: location)
            } ?? leadingAttributeRange
            if let replacementString,
               replacementString.contains(where: { $0 == "\n" || $0 == "\r" }),
               let leadingBlockID,
               replaceMultilineTextBeforeNativeMutation(
                    blockID: leadingBlockID,
                    blockRange: leadingRange,
                    affectedRange: affectedCharRange,
                    replacement: replacementString,
                    inheritedMarks: semanticMarks(in: storage, at: location)
               ) {
                return false
            }
            pendingBlockID = leadingBlockID
            pendingEditLocation = location
            if affectedCharRange.length > 0 {
                let trailingLocation = min(
                    max(location, NSMaxRange(affectedCharRange) - 1),
                    storage.length - 1
                )
                var trailingRange = NSRange()
                let trailingBlockID = storage.attribute(
                    .epdocBlockID,
                    at: trailingLocation,
                    effectiveRange: &trailingRange
                ) as? String
                if let leadingBlockID,
                   let trailingBlockID,
                   leadingBlockID != trailingBlockID {
                    pendingBlockID = nil
                    pendingEditLocation = nil
                    let handled = replaceAcrossBlocksBeforeNativeMutation(
                        leadingBlockID: leadingBlockID,
                        leadingUTF16Offset: affectedCharRange.location - leadingRange.location,
                        trailingBlockID: trailingBlockID,
                        trailingUTF16Offset: NSMaxRange(affectedCharRange) - trailingRange.location,
                        affectedRange: affectedCharRange,
                        replacement: replacementString ?? "",
                        inheritedMarks: semanticMarks(
                            in: storage,
                            at: location
                        )
                    )
                    if !handled { NSSound.beep() }
                    return false
                }
            }
            if let replacementString, !replacementString.isEmpty {
                pendingInsertedSemanticMarks =
                    (textView.typingAttributes[.epdocSemanticMarks] as? [String]) ?? []
                pendingInsertedSemanticRange = NSRange(
                    location: affectedCharRange.location,
                    length: replacementString.utf16.count
                )
            } else {
                pendingInsertedSemanticMarks = nil
                pendingInsertedSemanticRange = nil
            }
            if pendingUndoBlockSnapshot == nil, let leadingBlockID {
                pendingUndoBlockSnapshot = try? session.editableBlockSnapshot(
                    blockIDs: [leadingBlockID]
                )
                pendingUndoSelection = affectedCharRange
            }
            if let undoManager = textView.undoManager,
               !undoManager.isUndoing,
               !undoManager.isRedoing,
               !isNativeUndoRegistrationDisabled {
                undoManager.disableUndoRegistration()
                isNativeUndoRegistrationDisabled = true
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProjection, textView?.hasMarkedText() != true else { return }
            reconcilePendingTextChange(fallbackToSelection: true)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingProjection else { return }
            syncSelectionState()
        }

        func flushCheckpoint() {
            if textView?.hasMarkedText() == true {
                textView?.unmarkText()
                guard textView?.hasMarkedText() != true else { return }
                reconcilePendingTextChange(fallbackToSelection: false)
            }
            checkpointTask?.cancel()
            checkpointTask = nil
            guard let data = try? session.checkpointData() else { return }
            onCheckpoint(data)
        }

        private func scheduleCheckpoint() {
            checkpointTask?.cancel()
            checkpointTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let quietWindow = EpdocCheckpointSchedulingPolicy.quietWindowMilliseconds(
                        characterCount: self.session.characterCount
                    )
                    try await Task.sleep(for: .milliseconds(quietWindow))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                let envelope = self.session.checkpointSnapshot()
                let data = await Task.detached(priority: .utility) {
                    try? EpdocCheckpointEncoder.encode(envelope)
                }.value
                guard !Task.isCancelled, let data else { return }
                self.onCheckpoint(data)
            }
        }

        private func reconcilePendingTextChange(fallbackToSelection: Bool) {
            let blockID = pendingBlockID ?? (fallbackToSelection ? selectedBlockID() : nil)
            let editLocation = pendingEditLocation
            let undoSnapshot = pendingUndoBlockSnapshot
            let undoSelection = pendingUndoSelection
            let insertedSemanticMarks = pendingInsertedSemanticMarks
            let insertedSemanticRange = pendingInsertedSemanticRange
            pendingBlockID = nil
            pendingEditLocation = nil
            pendingUndoBlockSnapshot = nil
            pendingUndoSelection = nil
            pendingInsertedSemanticMarks = nil
            pendingInsertedSemanticRange = nil
            enableNativeUndoRegistrationIfNeeded()
            if let storage = textView?.textStorage,
               let insertedSemanticMarks,
               let insertedSemanticRange,
               insertedSemanticRange.length > 0,
               NSMaxRange(insertedSemanticRange) <= storage.length {
                storage.addAttribute(
                    .epdocSemanticMarks,
                    value: insertedSemanticMarks,
                    range: insertedSemanticRange
                )
            }
            guard let blockID,
                  reconcile(blockID: blockID, near: editLocation) else { return }
            if let undoSnapshot {
                registerBlockUndo(
                    snapshot: undoSnapshot,
                    selection: undoSelection ?? NSRange(location: editLocation ?? 0, length: 0),
                    actionName: "Edit Text"
                )
            }
            syncControllerState(markDirty: true)
            syncSelectionState()
            scheduleCheckpoint()
        }

        private func enableNativeUndoRegistrationIfNeeded() {
            guard isNativeUndoRegistrationDisabled else { return }
            textView?.undoManager?.enableUndoRegistration()
            isNativeUndoRegistrationDisabled = false
        }

        private func replaceAcrossBlocksBeforeNativeMutation(
            leadingBlockID: String,
            leadingUTF16Offset: Int,
            trailingBlockID: String,
            trailingUTF16Offset: Int,
            affectedRange: NSRange,
            replacement: String,
            inheritedMarks: [EpdocTextMark]
        ) -> Bool {
            guard let textView, let storage = textView.textStorage else { return false }
            let replacementChildren = inlineChildren(
                from: replacement,
                marks: inheritedMarks
            )
            do {
                let undoSnapshot = try session.checkpointEnvelope()
                try session.replaceAcrossBlocks(
                    leadingBlockID: leadingBlockID,
                    leadingUTF16Offset: leadingUTF16Offset,
                    trailingBlockID: trailingBlockID,
                    trailingUTF16Offset: trailingUTF16Offset,
                    replacement: replacementChildren
                )
                guard let leading = session.node(id: leadingBlockID),
                      let leadingRange = range(
                          of: leadingBlockID,
                          in: storage,
                          near: affectedRange.location
                      ),
                      let trailingRange = range(
                          of: trailingBlockID,
                          in: storage,
                          near: max(affectedRange.location, NSMaxRange(affectedRange) - 1)
                      ) else {
                    try session.restore(undoSnapshot)
                    return false
                }
                let combinedRange = NSUnionRange(leadingRange, trailingRange)
                let projected = EpdocAttributedProjection.makeBlock(
                    node: leading,
                    presentation: session.presentation(blockID: leadingBlockID),
                    theme: theme
                )
                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: combinedRange, with: projected)
                storage.endEditing()
                textView.didChangeText()
                isApplyingProjection = false
                textView.setSelectedRange(
                    NSRange(
                        location: min(
                            combinedRange.location
                                + leadingUTF16Offset
                                + replacement.utf16.count,
                            storage.length
                        ),
                        length: 0
                    )
                )
                registerSessionUndo(
                    snapshot: undoSnapshot,
                    selection: affectedRange,
                    actionName: "Replace Text"
                )
                syncControllerState(markDirty: true)
                scheduleCheckpoint()
                return true
            } catch {
                isApplyingProjection = false
                return false
            }
        }

        private func replaceMultilineTextBeforeNativeMutation(
            blockID: String,
            blockRange: NSRange,
            affectedRange: NSRange,
            replacement: String,
            inheritedMarks: [EpdocTextMark]
        ) -> Bool {
            guard let textView,
                  let storage = textView.textStorage,
                  affectedRange.location >= blockRange.location,
                  NSMaxRange(affectedRange) <= max(blockRange.location, NSMaxRange(blockRange) - 1)
            else { return false }

            let normalized = replacement
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
            guard lines.count > 1 else { return false }
            let localRange = NSRange(
                location: affectedRange.location - blockRange.location,
                length: affectedRange.length
            )

            do {
                let undoSnapshot = try session.checkpointEnvelope()
                let blockIDs = try session.replaceInlineRangeWithBlocks(
                    blockID: blockID,
                    range: localRange,
                    replacementBlocks: lines.map { line in
                        inlineChildren(from: String(line), marks: inheritedMarks)
                    }
                )
                let replacementProjection = NSMutableAttributedString()
                for pastedBlockID in blockIDs {
                    guard let node = session.node(id: pastedBlockID) else {
                        try session.restore(undoSnapshot)
                        return false
                    }
                    replacementProjection.append(
                        EpdocAttributedProjection.makeBlock(
                            node: node,
                            presentation: session.presentation(blockID: pastedBlockID),
                            theme: theme
                        )
                    )
                }

                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: blockRange, with: replacementProjection)
                storage.endEditing()
                textView.didChangeText()
                isApplyingProjection = false

                let lastBlockID = blockIDs[blockIDs.count - 1]
                let lastBlockRange = range(
                    of: lastBlockID,
                    in: storage,
                    near: blockRange.location + replacementProjection.length - 1
                )
                let caret = min(
                    (lastBlockRange?.location ?? blockRange.location)
                        + (lines.last?.utf16.count ?? 0),
                    storage.length
                )
                textView.setSelectedRange(NSRange(location: caret, length: 0))
                registerSessionUndo(
                    snapshot: undoSnapshot,
                    selection: affectedRange,
                    actionName: "Paste Text"
                )
                syncControllerState(markDirty: true)
                syncSelectionState()
                scheduleCheckpoint()
                return true
            } catch {
                isApplyingProjection = false
                return false
            }
        }

        private func splitSelectedBlock() -> Bool {
            guard let textView,
                  !textView.hasMarkedText(),
                  let storage = textView.textStorage else { return false }
            let selection = textView.selectedRange()
            guard selection.length == 0,
                  let blockID = selectedBlockID(),
                  let blockRange = range(of: blockID, in: storage, near: selection.location),
                  selection.location >= blockRange.location,
                  selection.location <= NSMaxRange(blockRange) - 1 else { return false }
            let splitOffset = selection.location - blockRange.location
            do {
                let undoSnapshot = try session.checkpointEnvelope()
                let newBlockID = try session.splitBlock(
                    blockID: blockID,
                    atUTF16Offset: splitOffset
                )
                guard let leading = session.node(id: blockID),
                      let trailing = session.node(id: newBlockID) else { return false }
                let leadingProjection = EpdocAttributedProjection.makeBlock(
                    node: leading,
                    presentation: session.presentation(blockID: blockID),
                    theme: theme
                )
                let trailingProjection = EpdocAttributedProjection.makeBlock(
                    node: trailing,
                    presentation: session.presentation(blockID: newBlockID),
                    theme: theme
                )
                let replacement = NSMutableAttributedString(attributedString: leadingProjection)
                replacement.append(trailingProjection)
                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: blockRange, with: replacement)
                storage.endEditing()
                isApplyingProjection = false
                textView.setSelectedRange(
                    NSRange(
                        location: blockRange.location + leadingProjection.length,
                        length: 0
                    )
                )
                registerSessionUndo(
                    snapshot: undoSnapshot,
                    selection: selection,
                    actionName: "Split Paragraph"
                )
                syncControllerState(markDirty: true)
                scheduleCheckpoint()
                return true
            } catch {
                return false
            }
        }

        private func mergeWithPreviousBlockAtCaret() -> Bool {
            guard let textView,
                  !textView.hasMarkedText(),
                  let storage = textView.textStorage else { return false }
            let selection = textView.selectedRange()
            guard selection.length == 0,
                  let trailingBlockID = selectedBlockID(),
                  let trailingRange = range(
                      of: trailingBlockID,
                      in: storage,
                      near: selection.location
                  ),
                  selection.location == trailingRange.location,
                  let leadingBlockID = session.previousEditableBlockID(
                      before: trailingBlockID
                  ),
                  let leadingRange = range(
                      of: leadingBlockID,
                      in: storage,
                      near: max(0, trailingRange.location - 1)
                  ) else { return false }
            let insertionOffset = max(0, leadingRange.length - 1)
            do {
                let undoSnapshot = try session.checkpointEnvelope()
                try session.mergeBlocks(
                    leadingBlockID: leadingBlockID,
                    trailingBlockID: trailingBlockID
                )
                guard let leading = session.node(id: leadingBlockID) else { return false }
                let combinedRange = NSUnionRange(leadingRange, trailingRange)
                let projected = EpdocAttributedProjection.makeBlock(
                    node: leading,
                    presentation: session.presentation(blockID: leadingBlockID),
                    theme: theme
                )
                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: combinedRange, with: projected)
                storage.endEditing()
                isApplyingProjection = false
                textView.setSelectedRange(
                    NSRange(
                        location: leadingRange.location + insertionOffset,
                        length: 0
                    )
                )
                registerSessionUndo(
                    snapshot: undoSnapshot,
                    selection: selection,
                    actionName: "Merge Paragraphs"
                )
                syncControllerState(markDirty: true)
                scheduleCheckpoint()
                return true
            } catch {
                return false
            }
        }

        private func registerSessionUndo(
            snapshot: EpdocContentEnvelope,
            selection: NSRange,
            actionName: String
        ) {
            guard let undoManager = textView?.undoManager else { return }
            undoManager.registerUndo(withTarget: self) { target in
                target.restoreSessionUndo(
                    snapshot: snapshot,
                    selection: selection,
                    actionName: actionName
                )
            }
            undoManager.setActionName(actionName)
        }

        private func registerBlockUndo(
            snapshot: EpdocEditableBlockSnapshot,
            selection: NSRange,
            actionName: String
        ) {
            guard let undoManager = textView?.undoManager else { return }
            undoManager.registerUndo(withTarget: self) { target in
                target.restoreBlockUndo(
                    snapshot: snapshot,
                    selection: selection,
                    actionName: actionName
                )
            }
            undoManager.setActionName(actionName)
        }

        private func restoreBlockUndo(
            snapshot: EpdocEditableBlockSnapshot,
            selection: NSRange,
            actionName: String
        ) {
            guard let textView,
                  let storage = textView.textStorage else { return }
            let blockIDs = snapshot.nodes.compactMap(\.id)
            guard blockIDs.count == snapshot.nodes.count,
                  let inverse = try? session.editableBlockSnapshot(blockIDs: blockIDs) else {
                return
            }
            let currentSelection = textView.selectedRange()
            let ranges = blockIDs.compactMap { blockID in
                range(of: blockID, in: storage, near: currentSelection.location).map {
                    (blockID: blockID, range: $0)
                }
            }
            guard ranges.count == blockIDs.count else { return }
            let origin = scrollView?.contentView.bounds.origin ?? .zero
            do {
                try session.restoreEditableBlockSnapshot(snapshot)
            } catch {
                return
            }

            isApplyingProjection = true
            storage.beginEditing()
            for target in ranges.sorted(by: { $0.range.location > $1.range.location }) {
                guard let node = session.node(id: target.blockID) else { continue }
                let projected = EpdocAttributedProjection.makeBlock(
                    node: node,
                    presentation: session.presentation(blockID: target.blockID),
                    theme: theme
                )
                storage.replaceCharacters(in: target.range, with: projected)
            }
            storage.endEditing()
            isApplyingProjection = false

            let location = min(selection.location, storage.length)
            textView.setSelectedRange(
                NSRange(
                    location: location,
                    length: min(selection.length, max(0, storage.length - location))
                )
            )
            scrollView?.contentView.scroll(to: origin)
            if let scrollView {
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            registerBlockUndo(
                snapshot: inverse,
                selection: currentSelection,
                actionName: actionName
            )
            syncControllerState(markDirty: true)
            syncSelectionState()
            scheduleCheckpoint()
        }

        private func restoreSessionUndo(
            snapshot: EpdocContentEnvelope,
            selection: NSRange,
            actionName: String
        ) {
            guard let textView,
                  let inverse = try? session.checkpointEnvelope() else { return }
            let inverseSelection = textView.selectedRange()
            let origin = scrollView?.contentView.bounds.origin ?? .zero
            do {
                try session.restore(snapshot)
            } catch {
                return
            }
            applyProjection(preservingSelection: false)
            let storageLength = textView.textStorage?.length ?? 0
            let location = min(selection.location, storageLength)
            textView.setSelectedRange(
                NSRange(
                    location: location,
                    length: min(selection.length, max(0, storageLength - location))
                )
            )
            scrollView?.contentView.scroll(to: origin)
            if let scrollView {
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            registerSessionUndo(
                snapshot: inverse,
                selection: inverseSelection,
                actionName: actionName
            )
            syncControllerState(markDirty: true)
            syncSelectionState()
            scheduleCheckpoint()
        }

        private func applyProjection(preservingSelection: Bool) {
            guard let textView, let storage = textView.textStorage else { return }
            let selection = textView.selectedRange()
            let origin = scrollView?.contentView.bounds.origin ?? .zero
            let projection = EpdocAttributedProjection.make(session: session, theme: theme)
            isApplyingProjection = true
            storage.beginEditing()
            storage.setAttributedString(projection)
            storage.endEditing()
            isApplyingProjection = false
            if preservingSelection {
                textView.setSelectedRange(
                    NSRange(
                        location: min(selection.location, storage.length),
                        length: min(selection.length, max(0, storage.length - min(selection.location, storage.length)))
                    )
                )
                scrollView?.contentView.scroll(to: origin)
                if let scrollView {
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        }

        private func reconcile(blockID: String, near location: Int? = nil) -> Bool {
            guard let textView,
                  let storage = textView.textStorage,
                  let blockRange = range(of: blockID, in: storage, near: location),
                  let node = session.node(id: blockID) else { return false }
            let editableLength = max(0, blockRange.length - 1)
            let editableRange = NSRange(location: blockRange.location, length: editableLength)
            let children = inlineChildren(from: storage, range: editableRange)
            let typingAttributes = textView.typingAttributes
            do {
                try session.replaceInlineContent(blockID: blockID, children: children)
                EpdocAttributedProjection.restyleBlock(
                    in: storage,
                    range: blockRange,
                    node: session.node(id: blockID) ?? node,
                    presentation: session.presentation(blockID: blockID),
                    theme: theme
                )
                if textView.selectedRange().length == 0 {
                    textView.typingAttributes = typingAttributes
                }
                return true
            } catch {
                return false
            }
        }

        private func inlineChildren(
            from storage: NSTextStorage,
            range: NSRange
        ) -> [EpdocRichNode] {
            guard range.length > 0 else { return [] }
            var children: [EpdocRichNode] = []
            storage.enumerateAttributes(in: range, options: []) { attributes, runRange, _ in
                let text = (storage.string as NSString).substring(with: runRange)
                if text == "\u{FFFC}",
                   let encoded = attributes[.epdocInlineNodeJSON] as? Data,
                   let node = try? JSONDecoder.epdocCanonical.decode(
                       EpdocRichNode.self,
                       from: encoded
                   ) {
                    children.append(node)
                    return
                }
                let marks = ((attributes[.epdocSemanticMarks] as? [String]) ?? []).map { raw in
                    if raw == EpdocMarkType.link.rawValue,
                       let href = attributes[.link] as? String {
                        return EpdocTextMark(
                            type: .link,
                            attributes: ["href": .string(href)]
                        )
                    }
                    return EpdocTextMark(type: EpdocMarkType(rawValue: raw))
                }
                let pieces = text.split(separator: "\n", omittingEmptySubsequences: false)
                for (index, piece) in pieces.enumerated() {
                    if !piece.isEmpty {
                        children.append(
                            EpdocRichNode(type: .text, text: String(piece), marks: marks)
                        )
                    }
                    if index < pieces.count - 1 {
                        children.append(EpdocRichNode(type: .hardBreak))
                    }
                }
            }
            return children
        }

        private func inlineChildren(
            from text: String,
            marks: [EpdocTextMark]
        ) -> [EpdocRichNode] {
            let pieces = text.split(separator: "\n", omittingEmptySubsequences: false)
            var children: [EpdocRichNode] = []
            for (index, piece) in pieces.enumerated() {
                if !piece.isEmpty {
                    children.append(
                        EpdocRichNode(type: .text, text: String(piece), marks: marks)
                    )
                }
                if index < pieces.count - 1 {
                    children.append(EpdocRichNode(type: .hardBreak))
                }
            }
            return children
        }

        private func semanticMarks(
            in storage: NSTextStorage,
            at location: Int
        ) -> [EpdocTextMark] {
            guard storage.length > 0 else { return [] }
            let safeLocation = min(max(0, location), storage.length - 1)
            let attributes = storage.attributes(at: safeLocation, effectiveRange: nil)
            return ((attributes[.epdocSemanticMarks] as? [String]) ?? []).map { raw in
                if raw == EpdocMarkType.link.rawValue,
                   let href = attributes[.link] as? String {
                    return EpdocTextMark(type: .link, attributes: ["href": .string(href)])
                }
                return EpdocTextMark(type: EpdocMarkType(rawValue: raw))
            }
        }

        private func range(
            of blockID: String,
            in storage: NSTextStorage,
            near location: Int? = nil
        ) -> NSRange? {
            let fullRange = NSRange(location: 0, length: storage.length)
            if storage.length > 0, let location {
                for candidate in [location, location - 1] {
                    guard candidate >= 0, candidate < storage.length else { continue }
                    var longestRange = NSRange()
                    let value = storage.attribute(
                        .epdocBlockID,
                        at: candidate,
                        longestEffectiveRange: &longestRange,
                        in: fullRange
                    ) as? String
                    if value == blockID {
                        return longestRange
                    }
                }
            }
            var foundLocation: Int?
            storage.enumerateAttribute(
                .epdocBlockID,
                in: fullRange,
                options: []
            ) { value, range, stop in
                guard value as? String == blockID else { return }
                foundLocation = range.location
                stop.pointee = true
            }
            guard let foundLocation else { return nil }
            var longestRange = NSRange()
            let value = storage.attribute(
                .epdocBlockID,
                at: foundLocation,
                longestEffectiveRange: &longestRange,
                in: fullRange
            ) as? String
            return value == blockID ? longestRange : nil
        }

        private func selectedBlockID() -> String? {
            selectedBlockRecords().first?.blockID
        }

        private func selectedBlockIDs() -> [String] {
            selectedBlockRecords().map(\.blockID)
        }

        private func selectedBlockRecords() -> [SelectedBlockRecord] {
            guard let textView,
                  let storage = textView.textStorage,
                  storage.length > 0 else { return [] }
            let selection = textView.selectedRange()
            if selection.length == 0 {
                let candidates = [
                    min(selection.location, storage.length - 1),
                    min(max(0, selection.location - 1), storage.length - 1),
                ]
                for location in candidates {
                    if let blockID = storage.attribute(
                        .epdocBlockID,
                        at: location,
                        effectiveRange: nil
                    ) as? String,
                       let blockRange = range(
                           of: blockID,
                           in: storage,
                           near: location
                       ) {
                        return [
                            SelectedBlockRecord(
                                blockID: blockID,
                                blockRange: blockRange
                            )
                        ]
                    }
                }
                return []
            }

            let clipped = NSIntersectionRange(
                selection,
                NSRange(location: 0, length: storage.length)
            )
            guard clipped.length > 0 else { return [] }
            var ordered: [SelectedBlockRecord] = []
            var seen = Set<String>()
            storage.enumerateAttribute(.epdocBlockID, in: clipped, options: []) { value, runRange, _ in
                guard let blockID = value as? String,
                      seen.insert(blockID).inserted,
                      let blockRange = range(
                          of: blockID,
                          in: storage,
                          near: runRange.location
                      ) else { return }
                ordered.append(
                    SelectedBlockRecord(
                        blockID: blockID,
                        blockRange: blockRange
                    )
                )
            }
            return ordered
        }

        private func selectedEditableRanges(
            records: [SelectedBlockRecord]
        ) -> [NSRange] {
            guard let textView else { return [] }
            let selection = textView.selectedRange()
            return records.compactMap { record in
                let selected = NSIntersectionRange(selection, record.editableRange)
                return selected.length > 0 ? selected : nil
            }
        }

        private func syncControllerState(markDirty: Bool) {
            guard let controller else { return }
            controller.toolbarModel.wordCount = session.wordCount
            controller.toolbarModel.characterCount = session.characterCount
            if markDirty {
                controller.markDurableEdit()
            }
        }

        private func syncSelectionState() {
            guard let controller,
                  let textView,
                  let storage = textView.textStorage,
                  storage.length > 0 else { return }
            let records = selectedBlockRecords()
            let blockNodes = records.compactMap { session.node(id: $0.blockID) }
            if !blockNodes.isEmpty,
               blockNodes.allSatisfy({ $0.type == .heading }),
               let firstLevel = Self.headingLevel(in: blockNodes[0]),
               blockNodes.allSatisfy({ Self.headingLevel(in: $0) == firstLevel }) {
                controller.toolbarModel.activeHeadingLevel = firstLevel
            } else {
                controller.toolbarModel.activeHeadingLevel = nil
            }

            let selection = textView.selectedRange()
            let markNames: Set<String>
            if selection.length == 0 {
                markNames = Set(
                    (textView.typingAttributes[.epdocSemanticMarks] as? [String]) ?? []
                )
            } else {
                var intersection: Set<String>?
                for range in selectedEditableRanges(records: records) {
                    storage.enumerateAttribute(.epdocSemanticMarks, in: range, options: []) { value, _, _ in
                        let current = Set((value as? [String]) ?? [])
                        intersection = intersection.map { $0.intersection(current) } ?? current
                    }
                }
                markNames = intersection ?? []
            }
            controller.toolbarModel.isBoldActive = markNames.contains(EpdocMarkType.bold.rawValue)
            controller.toolbarModel.isItalicActive = markNames.contains(EpdocMarkType.italic.rawValue)
            controller.toolbarModel.isStrikeActive = markNames.contains(EpdocMarkType.strikethrough.rawValue)
            controller.toolbarModel.isCodeActive = markNames.contains(EpdocMarkType.code.rawValue)
            controller.toolbarModel.isHighlightActive = markNames.contains(EpdocMarkType.highlight.rawValue)
        }

        private func applyContentWidth(_ mode: NoteWidthMode? = nil) {
            guard let textView, let scrollView else { return }
            if let mode {
                contentWidthMode = mode.normalized
            }
            let availableWidth = max(0, scrollView.contentSize.width)
            guard availableWidth > 0 else { return }
            let selection = textView.selectedRange()
            let origin = scrollView.contentView.bounds.origin
            let inset = EditorContentWidthPolicy.horizontalInset(
                availableWidth: availableWidth,
                mode: contentWidthMode
            )
            let nextInset = NSSize(width: inset, height: 46)
            guard EpdocContentWidthUpdatePolicy.requiresMutation(
                current: textView.textContainerInset,
                proposed: nextInset
            ) else { return }
            textView.textContainerInset = nextInset
            textView.needsDisplay = true
            textView.setSelectedRange(selection)
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func handle(_ command: EpdocEditorCommand) {
            guard let textView else { return }
            switch command {
            case .focusStart:
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                textView.window?.makeFirstResponder(textView)
            case .focusEnd:
                textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
                textView.window?.makeFirstResponder(textView)
            case .flushDocumentSnapshot:
                flushCheckpoint()
            case .runCommand(let name, let args):
                handleRunCommand(name: name, args: args)
            case .setContentWidth(let mode):
                applyContentWidth(mode)
            case .setFindQuery(let query, let caseSensitive),
                 .findNext(let query, let caseSensitive):
                selectFindMatch(
                    query: query,
                    forward: true,
                    caseSensitive: caseSensitive
                )
            case .findPrevious(let query, let caseSensitive):
                selectFindMatch(
                    query: query,
                    forward: false,
                    caseSensitive: caseSensitive
                )
            case .clearFindHighlights:
                break
            default:
                break
            }
        }

        private func selectFindMatch(
            query: String,
            forward: Bool,
            caseSensitive: Bool
        ) {
            guard let textView else { return }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return }
            let haystack = textView.string as NSString
            let selection = textView.selectedRange()
            var options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            if !forward {
                options.insert(.backwards)
            }

            let primaryRange: NSRange
            let wrappedRange: NSRange
            if forward {
                let start = min(NSMaxRange(selection), haystack.length)
                primaryRange = NSRange(location: start, length: haystack.length - start)
                wrappedRange = NSRange(location: 0, length: start)
            } else {
                let end = min(selection.location, haystack.length)
                primaryRange = NSRange(location: 0, length: end)
                wrappedRange = NSRange(location: end, length: haystack.length - end)
            }

            var match = haystack.range(
                of: needle,
                options: options,
                range: primaryRange
            )
            if match.location == NSNotFound {
                match = haystack.range(
                    of: needle,
                    options: options,
                    range: wrappedRange
                )
            }
            guard match.location != NSNotFound else {
                NSSound.beep()
                return
            }
            textView.setSelectedRange(match)
            textView.scrollRangeToVisible(match)
        }

        private func handleRunCommand(name: String, args: Data) {
            switch name {
            case "toggleBold": toggleMark(.bold)
            case "toggleItalic": toggleMark(.italic)
            case "toggleStrike": toggleMark(.strikethrough)
            case "toggleHighlight": toggleMark(.highlight)
            case "toggleCode": toggleMark(.code)
            case "toggleCodeBlock": toggleCodeBlock()
            case "setParagraph": setSelectedBlockType(.paragraph, attributes: [:])
            case "setHeadingLevel":
                let level = Self.headingLevel(from: args) ?? 1
                setSelectedBlockType(.heading, attributes: ["level": .int(level)])
            case "setLink":
                guard let href = Self.linkHref(from: args) else { return }
                setLink(href: href)
            case "insertEpdocImage":
                guard let image = Self.imageAttributes(from: args) else { return }
                insertInlineImage(src: image.src, alt: image.alt)
            default:
                break
            }
        }

        private func setLink(href: String) {
            guard let textView,
                  let storage = textView.textStorage else { return }
            let selection = textView.selectedRange()
            guard NSMaxRange(selection) <= storage.length else { return }
            if selection.length == 0 {
                var attributes = textView.typingAttributes
                var marks = Set((attributes[.epdocSemanticMarks] as? [String]) ?? [])
                marks.insert(EpdocMarkType.link.rawValue)
                attributes[.epdocSemanticMarks] = marks.sorted()
                attributes[.link] = href
                textView.typingAttributes = attributes
                syncSelectionState()
                return
            }

            let records = selectedBlockRecords()
            let selectedRanges = selectedEditableRanges(records: records)
            guard !records.isEmpty,
                  !selectedRanges.isEmpty,
                  let undoSnapshot = try? session.editableBlockSnapshot(
                      blockIDs: records.map(\.blockID)
                  ) else { return }

            var runs: [(range: NSRange, marks: Set<String>)] = []
            for selectedRange in selectedRanges {
                storage.enumerateAttribute(
                    .epdocSemanticMarks,
                    in: selectedRange,
                    options: []
                ) { value, range, _ in
                    runs.append(
                        (range, Set((value as? [String]) ?? []))
                    )
                }
            }
            storage.beginEditing()
            for run in runs {
                var marks = run.marks
                marks.insert(EpdocMarkType.link.rawValue)
                storage.addAttributes(
                    [
                        .epdocSemanticMarks: marks.sorted(),
                        .link: href,
                    ],
                    range: run.range
                )
            }
            storage.endEditing()
            guard reconcileBlockRecords(records) else { return }
            textView.setSelectedRange(selection)
            registerBlockUndo(
                snapshot: undoSnapshot,
                selection: selection,
                actionName: "Add Link"
            )
            syncControllerState(markDirty: true)
            syncSelectionState()
            scheduleCheckpoint()
        }

        private func insertInlineImage(src: String, alt: String) {
            guard let textView,
                  let storage = textView.textStorage else { return }
            let selection = textView.selectedRange()
            let records = selectedBlockRecords()
            guard records.count == 1,
                  let record = records.first,
                  selection.location >= record.editableRange.location,
                  NSMaxRange(selection) <= NSMaxRange(record.editableRange),
                  let undoSnapshot = try? session.editableBlockSnapshot(
                      blockIDs: [record.blockID]
                  ) else { return }

            let localRange = NSRange(
                location: selection.location - record.blockRange.location,
                length: selection.length
            )
            let image = EpdocRichNode(
                type: .image,
                attributes: [
                    "src": .string(src),
                    "alt": .string(alt),
                ]
            )
            do {
                _ = try session.replaceInlineRangeWithBlocks(
                    blockID: record.blockID,
                    range: localRange,
                    replacementBlocks: [[image]]
                )
                guard let node = session.node(id: record.blockID) else { return }
                let projected = EpdocAttributedProjection.makeBlock(
                    node: node,
                    presentation: session.presentation(blockID: record.blockID),
                    theme: theme
                )
                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: record.blockRange, with: projected)
                storage.endEditing()
                isApplyingProjection = false
                textView.setSelectedRange(
                    NSRange(
                        location: min(selection.location + 1, storage.length),
                        length: 0
                    )
                )
                registerBlockUndo(
                    snapshot: undoSnapshot,
                    selection: selection,
                    actionName: "Insert Image"
                )
                syncControllerState(markDirty: true)
                syncSelectionState()
                scheduleCheckpoint()
            } catch {
                isApplyingProjection = false
                NSSound.beep()
            }
        }

        private func toggleMark(_ mark: EpdocMarkType) {
            guard let textView,
                  let storage = textView.textStorage else { return }
            let range = textView.selectedRange()
            guard NSMaxRange(range) <= storage.length else { return }
            if range.length == 0 {
                var attributes = textView.typingAttributes
                var marks = Set((attributes[.epdocSemanticMarks] as? [String]) ?? [])
                if marks.contains(mark.rawValue) {
                    marks.remove(mark.rawValue)
                } else {
                    marks.insert(mark.rawValue)
                }
                attributes[.epdocSemanticMarks] = marks.sorted()
                textView.typingAttributes = attributes
                syncSelectionState()
                return
            }
            let records = selectedBlockRecords()
            let selectedRanges = selectedEditableRanges(records: records)
            guard !records.isEmpty,
                  !selectedRanges.isEmpty,
                  let undoSnapshot = try? session.editableBlockSnapshot(
                      blockIDs: records.map(\.blockID)
                  ) else { return }

            var runs: [(range: NSRange, marks: Set<String>)] = []
            for selectedRange in selectedRanges {
                storage.enumerateAttribute(
                    .epdocSemanticMarks,
                    in: selectedRange,
                    options: []
                ) { value, runRange, _ in
                    runs.append(
                        (
                            range: runRange,
                            marks: Set((value as? [String]) ?? [])
                        )
                    )
                }
            }
            guard !runs.isEmpty else { return }
            let allMarked = runs.allSatisfy { $0.marks.contains(mark.rawValue) }
            storage.beginEditing()
            for run in runs {
                var marks = run.marks
                if allMarked {
                    marks.remove(mark.rawValue)
                } else {
                    marks.insert(mark.rawValue)
                }
                storage.addAttribute(
                    .epdocSemanticMarks,
                    value: marks.sorted(),
                    range: run.range
                )
            }
            storage.endEditing()
            guard reconcileBlockRecords(records) else { return }
            textView.setSelectedRange(range)
            registerBlockUndo(
                snapshot: undoSnapshot,
                selection: range,
                actionName: allMarked ? "Remove Format" : "Apply Format"
            )
            syncControllerState(markDirty: true)
            syncSelectionState()
            scheduleCheckpoint()
        }

        private func setSelectedBlockType(
            _ type: EpdocNodeType,
            attributes: [String: EpdocJSONValue]
        ) {
            guard let textView,
                  let storage = textView.textStorage,
                  !selectedBlockRecords().isEmpty else { return }
            let selection = textView.selectedRange()
            let records = selectedBlockRecords()
            let blockIDs = records.map(\.blockID)
            guard let undoSnapshot = try? session.editableBlockSnapshot(
                blockIDs: blockIDs
            ) else { return }
            do {
                try session.setBlockTypes(blockIDs: blockIDs, type: type, attributes: attributes)
                for record in records {
                    guard let node = session.node(id: record.blockID) else { continue }
                    EpdocAttributedProjection.restyleBlock(
                        in: storage,
                        range: record.blockRange,
                        node: node,
                        presentation: session.presentation(blockID: record.blockID),
                        theme: theme
                    )
                }
                textView.setSelectedRange(selection)
                registerBlockUndo(
                    snapshot: undoSnapshot,
                    selection: selection,
                    actionName: "Change Block Style"
                )
                syncControllerState(markDirty: true)
                syncSelectionState()
                scheduleCheckpoint()
            } catch {
                return
            }
        }

        private func toggleCodeBlock() {
            guard let textView,
                  let storage = textView.textStorage else { return }
            let selection = textView.selectedRange()
            let records = selectedBlockRecords()
            let nodes = records.compactMap { session.node(id: $0.blockID) }
            guard !records.isEmpty, nodes.count == records.count else { return }
            if nodes.allSatisfy({ $0.type == .codeBlock }) {
                setSelectedBlockType(.paragraph, attributes: [:])
                return
            }
            guard nodes.allSatisfy({ node in
                node.children.allSatisfy {
                    $0.type == .text || $0.type == .hardBreak
                }
            }), let undoSnapshot = try? session.checkpointEnvelope() else {
                NSSound.beep()
                return
            }

            var children: [EpdocRichNode] = []
            for (index, node) in nodes.enumerated() {
                if index > 0 {
                    children.append(EpdocRichNode(type: .hardBreak))
                }
                children.append(contentsOf: node.children.map { child in
                    guard child.type == .text else { return child }
                    return EpdocRichNode(type: .text, text: child.text ?? "")
                })
            }
            let replacementRange = records.dropFirst().reduce(records[0].blockRange) {
                NSUnionRange($0, $1.blockRange)
            }
            do {
                let blockID = try session.replaceEditableBlockRange(
                    blockIDs: records.map(\.blockID),
                    type: .codeBlock,
                    attributes: ["language": .string("swift")],
                    children: children
                )
                guard let node = session.node(id: blockID) else {
                    try session.restore(undoSnapshot)
                    return
                }
                let projected = EpdocAttributedProjection.makeBlock(
                    node: node,
                    presentation: session.presentation(blockID: blockID),
                    theme: theme
                )
                isApplyingProjection = true
                storage.beginEditing()
                storage.replaceCharacters(in: replacementRange, with: projected)
                storage.endEditing()
                isApplyingProjection = false
                let restoredSelection = NSRange(
                    location: replacementRange.location,
                    length: max(0, projected.length - 1)
                )
                textView.setSelectedRange(restoredSelection)
                registerSessionUndo(
                    snapshot: undoSnapshot,
                    selection: selection,
                    actionName: "Toggle Code Block"
                )
                syncControllerState(markDirty: true)
                syncSelectionState()
                scheduleCheckpoint()
            } catch {
                isApplyingProjection = false
                NSSound.beep()
            }
        }

        private func reconcileBlockRecords(
            _ records: [SelectedBlockRecord]
        ) -> Bool {
            guard let storage = textView?.textStorage else { return false }
            let replacements = records.map { record in
                (
                    blockID: record.blockID,
                    children: inlineChildren(from: storage, range: record.editableRange)
                )
            }
            do {
                try session.replaceInlineContents(replacements)
                for record in records {
                    guard let node = session.node(id: record.blockID) else { continue }
                    EpdocAttributedProjection.restyleBlock(
                        in: storage,
                        range: record.blockRange,
                        node: node,
                        presentation: session.presentation(blockID: record.blockID),
                        theme: theme
                    )
                }
                return true
            } catch {
                return false
            }
        }

        private static func headingLevel(from data: Data) -> Int? {
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let raw = array.first?["level"] as? Int else { return nil }
            return max(1, min(6, raw))
        }

        private static func linkHref(from data: Data) -> String? {
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let raw = array.first?["href"] as? String else { return nil }
            let href = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return href.isEmpty ? nil : href
        }

        private static func imageAttributes(from data: Data) -> (src: String, alt: String)? {
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let raw = array.first?["src"] as? String else { return nil }
            let src = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !src.isEmpty else { return nil }
            return (src, array.first?["alt"] as? String ?? "")
        }

        private static func headingLevel(in node: EpdocRichNode) -> Int? {
            guard case .int(let level)? = node.attributes["level"] else { return nil }
            return level
        }
    }
}
