import AppKit
import Foundation
import Testing

@testable import Epistemos

@MainActor
@Suite("KEELSTONE Native Epdoc Toolbar", .serialized)
struct EpdocNativeToolbarTests {
    private struct Harness {
        let session: EpdocTextKit2EditorSession
        let controller: EpdocEditorChromeController
        let coordinator: EpdocTextKit2EditorRepresentable.Coordinator
        let scrollView: NSScrollView
        let textView: EpdocTextView
        let window: NSWindow

        func close() {
            coordinator.detach()
            window.close()
        }
    }

    private static func envelope(
        documentID: String,
        blocks: [EpdocRichNode]
    ) -> EpdocContentEnvelope {
        EpdocContentEnvelope(
            documentID: documentID,
            revision: 17,
            root: EpdocRichNode(
                id: "\(documentID):root",
                type: .document,
                children: blocks
            )
        )
    }

    private static func block(
        id: String,
        type: EpdocNodeType = .paragraph,
        level: Int? = nil,
        text: String,
        marks: [EpdocTextMark] = []
    ) -> EpdocRichNode {
        EpdocRichNode(
            id: id,
            type: type,
            attributes: level.map { ["level": .int($0)] } ?? [:],
            children: [EpdocRichNode(type: .text, text: text, marks: marks)]
        )
    }

    private static func makeHarness(_ envelope: EpdocContentEnvelope) throws -> Harness {
        let session = try EpdocTextKit2EditorSession(
            contentJSON: JSONEncoder.epdocCanonical.encode(envelope)
        )
        let controller = EpdocEditorChromeController()
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { _ in }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        #expect(window.makeFirstResponder(textView))
        return Harness(
            session: session,
            controller: controller,
            coordinator: coordinator,
            scrollView: scrollView,
            textView: textView,
            window: window
        )
    }

    private static func plainText(_ node: EpdocRichNode) -> String {
        if node.type == .text { return node.text ?? "" }
        if node.type == .hardBreak { return "\n" }
        return node.children.map(plainText).joined()
    }

    private static func markTypes(
        in block: EpdocRichNode,
        atUTF16Offset targetOffset: Int
    ) -> Set<EpdocMarkType>? {
        var offset = targetOffset
        for child in block.children {
            let length: Int
            if child.type == .text {
                length = (child.text ?? "").utf16.count
            } else if child.type == .hardBreak {
                length = 1
            } else {
                length = 1
            }
            if offset < length {
                return Set(child.marks.map(\.type))
            }
            offset -= length
        }
        return nil
    }

    @Test("collapsed-caret mark state follows typing attributes before canonical mutation")
    func collapsedCaretMarkStateFollowsTypingAttributes() throws {
        let initial = Self.envelope(
            documentID: "epdoc-caret-mark-state",
            blocks: [
                Self.block(id: "sentinel", text: "Sentinel"),
                Self.block(id: "target", text: "Beta"),
            ]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }

        let beta = (harness.textView.string as NSString).range(of: "Beta")
        #expect(beta.location != NSNotFound)
        harness.textView.setSelectedRange(
            NSRange(location: beta.location + 2, length: 0)
        )
        harness.coordinator.textViewDidChangeSelection(
            Notification(name: NSTextView.didChangeSelectionNotification)
        )

        harness.controller.dispatch(
            .runCommand(name: "toggleBold", argsJSON: Data("[]".utf8))
        )

        let typingMarks = Set(
            (harness.textView.typingAttributes[.epdocSemanticMarks] as? [String]) ?? []
        )
        #expect(typingMarks.contains(EpdocMarkType.bold.rawValue))
        #expect(harness.controller.toolbarModel.isBoldActive)
        #expect(harness.session.revision == initial.revision)
        #expect(harness.session.node(id: "sentinel") == initial.root.children[0])

        harness.textView.insertText(
            "X",
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        let targetAfterBold = try #require(harness.session.node(id: "target"))
        #expect(Self.plainText(targetAfterBold) == "BeXta")
        #expect(
            targetAfterBold.children.contains { child in
                child.text == "X" && child.marks.map(\.type).contains(.bold)
            }
        )

        harness.controller.dispatch(
            .runCommand(name: "toggleBold", argsJSON: Data("[]".utf8))
        )
        #expect(!harness.controller.toolbarModel.isBoldActive)
        harness.textView.insertText(
            "Y",
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        let targetAfterPlain = try #require(harness.session.node(id: "target"))
        #expect(Self.plainText(targetAfterPlain) == "BeXYta")
        #expect(Self.markTypes(in: targetAfterPlain, atUTF16Offset: 2)?.contains(.bold) == true)
        #expect(Self.markTypes(in: targetAfterPlain, atUTF16Offset: 3)?.contains(.bold) == false)
        #expect(harness.session.node(id: "sentinel") == initial.root.children[0])
    }

    @Test("selection state ignores structural delimiters and resynchronizes undo")
    func selectionStateIgnoresDelimitersAndResynchronizesUndo() throws {
        let bold = EpdocTextMark(type: .bold)
        let italic = EpdocTextMark(type: .italic)
        let initial = Self.envelope(
            documentID: "epdoc-selection-toolbar-state",
            blocks: [
                Self.block(id: "h2-a", type: .heading, level: 2, text: "First", marks: [bold]),
                Self.block(id: "h2-b", type: .heading, level: 2, text: "Second", marks: [bold]),
                Self.block(id: "italic", text: "Third", marks: [italic]),
                Self.block(id: "plain", text: "Fourth"),
            ]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }
        let undoManager = try #require(harness.textView.undoManager)
        undoManager.groupsByEvent = false

        let boldHeadings = (harness.textView.string as NSString).range(of: "First\nSecond")
        #expect(boldHeadings.location != NSNotFound)
        harness.textView.setSelectedRange(boldHeadings)
        harness.coordinator.textViewDidChangeSelection(
            Notification(name: NSTextView.didChangeSelectionNotification)
        )
        #expect(harness.controller.toolbarModel.activeHeadingLevel == 2)
        #expect(harness.controller.toolbarModel.isBoldActive)

        let mixed = (harness.textView.string as NSString).range(of: "First\nSecond\nThird")
        harness.textView.setSelectedRange(mixed)
        harness.coordinator.textViewDidChangeSelection(
            Notification(name: NSTextView.didChangeSelectionNotification)
        )
        #expect(harness.controller.toolbarModel.activeHeadingLevel == nil)
        #expect(!harness.controller.toolbarModel.isBoldActive)
        #expect(!harness.controller.toolbarModel.isItalicActive)

        let plain = (harness.textView.string as NSString).range(of: "Fourth")
        harness.textView.setSelectedRange(plain)
        harness.coordinator.textViewDidChangeSelection(
            Notification(name: NSTextView.didChangeSelectionNotification)
        )
        undoManager.beginUndoGrouping()
        harness.controller.dispatch(
            .runCommand(name: "toggleBold", argsJSON: Data("[]".utf8))
        )
        undoManager.endUndoGrouping()
        #expect(harness.controller.toolbarModel.isBoldActive)
        #expect(harness.session.node(id: "h2-a") == initial.root.children[0])
        #expect(harness.session.node(id: "h2-b") == initial.root.children[1])
        #expect(harness.session.node(id: "italic") == initial.root.children[2])

        undoManager.undo()
        #expect(!harness.controller.toolbarModel.isBoldActive)
        undoManager.redo()
        #expect(harness.controller.toolbarModel.isBoldActive)
    }

    @Test("code-block toggle creates one canonical block for a multiline selection")
    func codeBlockToggleIsSelectionScopedAndValidated() throws {
        let initial = Self.envelope(
            documentID: "epdoc-code-block-toggle",
            blocks: [
                Self.block(id: "sentinel-before", text: "Before"),
                Self.block(id: "target-a", text: "Alpha"),
                Self.block(id: "target-b", text: "Beta"),
                Self.block(id: "sentinel-after", text: "After"),
            ]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }

        let selection = (harness.textView.string as NSString).range(of: "Alpha\nBeta")
        #expect(selection.location != NSNotFound)
        harness.textView.setSelectedRange(selection)
        harness.controller.dispatch(
            .runCommand(name: "toggleCodeBlock", argsJSON: Data("[]".utf8))
        )

        #expect(harness.session.node(id: "target-a")?.type == .codeBlock)
        #expect(harness.session.node(id: "target-b") == nil)
        #expect(Self.plainText(try #require(harness.session.node(id: "target-a"))) == "Alpha\nBeta")
        #expect(harness.session.node(id: "sentinel-before") == initial.root.children[0])
        #expect(harness.session.node(id: "sentinel-after") == initial.root.children[3])
        #expect(harness.textView.selectedRange() == selection)
        #expect(try harness.session.checkpointEnvelope().revision == initial.revision + 1)

        harness.controller.dispatch(
            .runCommand(name: "toggleCodeBlock", argsJSON: Data("[]".utf8))
        )
        #expect(harness.session.node(id: "target-a")?.type == .paragraph)
        #expect(harness.session.node(id: "target-b") == nil)
    }

    @Test("durable save state clears only the revision AppKit actually saved")
    func durableSaveStateTracksCompletionAndInterveningEdits() {
        let controller = EpdocEditorChromeController()

        controller.markDurableEdit()
        let firstSave = controller.beginDurableSave()
        #expect(controller.toolbarModel.isDirty)
        #expect(controller.toolbarModel.isSaving)

        controller.completeDurableSave(firstSave, succeeded: false)
        #expect(controller.toolbarModel.isDirty)
        #expect(!controller.toolbarModel.isSaving)

        let secondSave = controller.beginDurableSave()
        controller.markDurableEdit()
        controller.completeDurableSave(secondSave, succeeded: true)
        #expect(controller.toolbarModel.isDirty)
        #expect(!controller.toolbarModel.isSaving)

        let thirdSave = controller.beginDurableSave()
        controller.completeDurableSave(thirdSave, succeeded: true)
        #expect(!controller.toolbarModel.isDirty)
        #expect(!controller.toolbarModel.isSaving)
    }

    @Test("unchanged Epdoc width inset is a strict no-op")
    func unchangedWidthInsetDoesNotRequestViewportRestoration() {
        #expect(
            !EpdocContentWidthUpdatePolicy.requiresMutation(
                current: NSSize(width: 120, height: 46),
                proposed: NSSize(width: 120, height: 46)
            )
        )
        #expect(
            EpdocContentWidthUpdatePolicy.requiresMutation(
                current: NSSize(width: 120, height: 46),
                proposed: NSSize(width: 121, height: 46)
            )
        )
    }

    @Test("large Epdocs use a longer coalescing window before full checkpoints")
    func checkpointSchedulingScalesWithDocumentSize() {
        #expect(EpdocCheckpointSchedulingPolicy.quietWindowMilliseconds(characterCount: 20_000) == 350)
        #expect(EpdocCheckpointSchedulingPolicy.quietWindowMilliseconds(characterCount: 150_000) == 650)
        #expect(EpdocCheckpointSchedulingPolicy.quietWindowMilliseconds(characterCount: 750_000) == 900)
    }

    @Test("checkpoint encoder validates and preserves the canonical envelope")
    func checkpointEncoderPreservesCanonicalEnvelope() throws {
        let envelope = Self.envelope(
            documentID: "epdoc-off-main-checkpoint",
            blocks: [Self.block(id: "body", text: "Large-document checkpoint")]
        )

        let data = try EpdocCheckpointEncoder.encode(envelope)
        let reopened = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: data
        )
        #expect(reopened == envelope)
    }

    @Test("native Epdoc link command applies only to the selected text")
    func nativeLinkCommandIsSelectionScoped() throws {
        let initial = Self.envelope(
            documentID: "epdoc-native-link",
            blocks: [Self.block(id: "body", text: "Alpha Beta Gamma")]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }

        let beta = (harness.textView.string as NSString).range(of: "Beta")
        harness.textView.setSelectedRange(beta)
        harness.controller.dispatch(
            .runCommand(
                name: "setLink",
                argsJSON: Data(#"[{"href":"https://example.com"}]"#.utf8)
            )
        )

        let node = try #require(harness.session.node(id: "body"))
        let linkedText = try #require(node.children.first(where: { $0.text == "Beta" }))
        #expect(
            linkedText.marks.contains {
                $0.type == .link && $0.attributes["href"] == .string("https://example.com")
            }
        )
        #expect(Self.plainText(node) == "Alpha Beta Gamma")
    }

    @Test("native Epdoc image command inserts one canonical inline image")
    func nativeImageCommandInsertsCanonicalImage() throws {
        let initial = Self.envelope(
            documentID: "epdoc-native-image",
            blocks: [Self.block(id: "body", text: "Alpha")]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }

        harness.textView.setSelectedRange(NSRange(location: 5, length: 0))
        harness.controller.dispatch(
            .runCommand(
                name: "insertEpdocImage",
                argsJSON: Data(#"[{"src":"assets/example.png","alt":"Example"}]"#.utf8)
            )
        )

        let node = try #require(harness.session.node(id: "body"))
        let image = try #require(node.children.first(where: { $0.type == .image }))
        #expect(image.attributes["src"] == .string("assets/example.png"))
        #expect(image.attributes["alt"] == .string("Example"))
        #expect(Self.plainText(node) == "Alpha")
    }

    @Test("native Epdoc find navigation selects the requested match")
    func nativeFindNavigationSelectsMatch() throws {
        let initial = Self.envelope(
            documentID: "epdoc-native-find",
            blocks: [Self.block(id: "body", text: "Alpha Beta alpha")]
        )
        let harness = try Self.makeHarness(initial)
        defer { harness.close() }

        harness.textView.setSelectedRange(NSRange(location: 0, length: 0))
        harness.controller.dispatch(.findNext(query: "Beta", caseSensitive: true))
        let selected = (harness.textView.string as NSString).substring(
            with: harness.textView.selectedRange()
        )
        #expect(selected == "Beta")

        harness.controller.dispatch(.findPrevious(query: "ALPHA", caseSensitive: false))
        let previous = (harness.textView.string as NSString).substring(
            with: harness.textView.selectedRange()
        )
        #expect(previous.lowercased() == "alpha")
    }
}
