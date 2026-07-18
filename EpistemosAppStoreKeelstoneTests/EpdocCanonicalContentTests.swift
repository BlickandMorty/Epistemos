import AppKit
import Foundation
import Testing

@testable import Epistemos

@MainActor
@Suite("KEELSTONE Canonical Epdoc and Native Viewport", .serialized)
struct EpdocCanonicalContentTests {
    private static func canonicalEnvelope(
        documentID: String = "epdoc-native-session",
        revision: UInt64 = 11
    ) -> EpdocContentEnvelope {
        EpdocContentEnvelope(
            documentID: documentID,
            revision: revision,
            root: EpdocRichNode(
                id: "\(documentID):root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "block-a",
                        type: .heading,
                        attributes: ["level": .int(1)],
                        children: [
                            EpdocRichNode(
                                type: .text,
                                text: "Alpha untouched",
                                marks: [EpdocTextMark(type: .bold)]
                            ),
                        ]
                    ),
                    EpdocRichNode(
                        id: "block-b",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "Beta")]
                    ),
                ]
            )
        )
    }

    private static func flattened(_ node: EpdocRichNode) -> [EpdocRichNode] {
        [node] + node.children.flatMap(flattened)
    }

    private static func plainText(_ node: EpdocRichNode) -> String {
        if node.type == .text { return node.text ?? "" }
        if node.type == .hardBreak { return "\n" }
        return node.children.map(plainText).joined()
    }

    private static func largeEnvelope(
        documentID: String = "epdoc-viewport-fixture",
        blockCount: Int = 4_500,
        wordsPerBlock: Int = 15
    ) -> EpdocContentEnvelope {
        let line = Array(repeating: "viewport", count: wordsPerBlock).joined(separator: " ")
        return EpdocContentEnvelope(
            documentID: documentID,
            root: EpdocRichNode(
                id: "\(documentID):root",
                type: .document,
                children: (0..<blockCount).map { index in
                    EpdocRichNode(
                        id: "block-\(index)",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "\(index) \(line)")]
                    )
                }
            )
        )
    }

    @Test("canonical rich JSON round-trips and rejects duplicate block identity")
    func canonicalEnvelopeRoundTripsAndFailsClosed() throws {
        let envelope = Self.canonicalEnvelope()
        try envelope.validate()

        let data = try JSONEncoder.epdocCanonical.encode(envelope)
        let decoded = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: data
        )

        #expect(decoded == envelope)
        #expect(decoded.root.children.first?.attributes["level"] == .int(1))
        #expect(decoded.root.children.first?.children.first?.marks.map(\.type) == [.bold])

        let invalid = EpdocContentEnvelope(
            documentID: "duplicate-blocks",
            root: EpdocRichNode(
                id: "duplicate-blocks:root",
                type: .document,
                children: [
                    EpdocRichNode(id: "same-block", type: .paragraph),
                    EpdocRichNode(id: "same-block", type: .heading),
                ]
            )
        )
        #expect(throws: EpdocContentValidationError.self) {
            try invalid.validate()
        }
    }

    @Test("NSDocument writes one canonical Epdoc package then closes and reopens it")
    func epdocDocumentWritesClosesAndReopensCanonicalPackage() throws {
        let document = EpdocDocument()
        let documentID = document.package.manifest.id
        let initial = Self.canonicalEnvelope(documentID: documentID, revision: 41)
        let session = try EpdocTextKit2EditorSession(
            contentJSON: JSONEncoder.epdocCanonical.encode(initial)
        )
        try session.replaceInlineContent(
            blockID: "block-b",
            children: [
                EpdocRichNode(
                    type: .text,
                    text: "Saved 🧠 package",
                    marks: [EpdocTextMark(type: .italic)]
                ),
            ]
        )
        var liveFlushCount = 0
        document.bindLiveEditorSnapshotFlush {
            liveFlushCount += 1
            guard let checkpoint = try? session.checkpointData() else { return }
            #expect(document.setContentJSON(checkpoint))
        }
        document.package.assets["diagram.bin"] = Data([0x45, 0x50, 0x44, 0x4f, 0x43])

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "epdoc-document-reopen-\(UUID().uuidString)",
            isDirectory: true
        )
        let url = root.appendingPathComponent("Viewport.epdoc", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try document.write(to: url, ofType: "com.epistemos.epdoc")
        #expect(liveFlushCount > 0)
        document.updateChangeCount(.changeCleared)
        document.close()

        let diskWrapper = try FileWrapper(url: url, options: .immediate)
        let reopened = EpdocDocument()
        try reopened.read(from: diskWrapper, ofType: "com.epistemos.epdoc")
        defer { reopened.close() }

        #expect(reopened.package.manifest.id == documentID)
        #expect(reopened.package.assets["diagram.bin"] == Data([0x45, 0x50, 0x44, 0x4f, 0x43]))
        #expect(reopened.package.shadowMarkdown == nil)
        let reopenedSession = try EpdocTextKit2EditorSession(
            contentJSON: reopened.package.contentJSON
        )
        #expect(reopenedSession.revision == initial.revision + 1)
        #expect(
            Self.plainText(try #require(reopenedSession.node(id: "block-b")))
                == "Saved 🧠 package"
        )
        #expect(
            reopenedSession.node(id: "block-b")?.children.first?.marks.map(\.type)
                == [.italic]
        )
    }

    @Test("NSDocument rejects a canonical checkpoint owned by another Epdoc")
    func epdocDocumentRejectsMismatchedCanonicalCheckpoint() throws {
        let document = EpdocDocument()
        let original = document.package.contentJSON
        let foreign = Self.canonicalEnvelope(documentID: "different-epdoc")

        #expect(
            !document.setContentJSON(
                try JSONEncoder.epdocCanonical.encode(foreign)
            )
        )
        #expect(document.package.contentJSON == original)
        #expect(!document.isDocumentEdited)
    }

    @Test("Epdoc package rejects canonical content owned by another manifest")
    func epdocPackageRejectsMismatchedCanonicalContentOwnership() throws {
        let document = EpdocDocument()
        let package = EpdocPackage(
            manifest: document.package.manifest,
            contentJSON: try JSONEncoder.epdocCanonical.encode(
                Self.canonicalEnvelope(documentID: "foreign-content-owner")
            )
        )
        let wrapper = try package.makeFileWrapper()

        do {
            _ = try EpdocPackage(fileWrapper: wrapper)
            Issue.record("A package must not accept content owned by another document ID")
        } catch let error as EpdocPackageError {
            guard case let .mismatchedContentDocumentID(manifestID, contentID) = error else {
                Issue.record("Unexpected package error: \(error)")
                return
            }
            #expect(manifestID == document.package.manifest.id)
            #expect(contentID == "foreign-content-owner")
        }
    }

    @Test("legacy ProseMirror migration preserves semantics bytes and opaque payload receipt")
    func legacyMigrationPreservesSemanticsAndReceipt() throws {
        let legacy = #"""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": {"id": "legacy-title", "level": 2},
              "content": [{
                "type": "text",
                "text": "Viewport title",
                "marks": [
                  {"type": "bold"},
                  {"type": "link", "attrs": {"href": "https://example.com"}}
                ]
              }]
            },
            {
              "type": "vendorWidget",
              "attrs": {"asset": "assets/widget.bin"},
              "content": [{"type": "text", "text": "Widget fallback"}]
            }
          ]
        }
        """#.data(using: .utf8)!

        let result = try EpdocLegacyProseMirrorMigrator.migrate(
            legacy,
            documentID: "legacy-viewport-document",
            migratedAt: 1_700_000_001_234
        )
        try result.envelope.validate()
        let nodes = Self.flattened(result.envelope.root)
        let heading = try #require(nodes.first { $0.id == "legacy-title" })
        let opaque = try #require(nodes.first { $0.type == .opaqueLegacy })

        #expect(result.originalContent == legacy)
        #expect(heading.attributes["level"] == .int(2))
        #expect(heading.children.first?.marks.map(\.type) == [.bold, .link])
        #expect(
            heading.children.first?.marks.last?.attributes["href"]
                == .string("https://example.com")
        )
        #expect(opaque.attributes["legacy_type"] == .string("vendorWidget"))
        #expect(opaque.attributes["legacy_payload"] != nil)
        #expect(result.receipt.targetFormat == EpdocContentEnvelope.formatIdentifier)
        #expect(result.receipt.sourceByteCount == legacy.count)
        #expect(result.receipt.sourceSHA256.count == 64)
        #expect(result.receipt.opaqueNodeCount == 1)
        #expect(result.receipt.warnings.count == 1)
        #expect(result.receipt.sourcePlainTextSHA256 == result.receipt.targetPlainTextSHA256)
    }

    @Test("canonical bold and italic survive the derived Markdown projection")
    func canonicalBoldItalicSurviveMarkdownProjection() throws {
        let envelope = EpdocContentEnvelope(
            documentID: "epdoc-markdown-marks",
            root: EpdocRichNode(
                id: "epdoc-markdown-marks:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "styled-block",
                        type: .paragraph,
                        children: [
                            EpdocRichNode(
                                type: .text,
                                text: "Styled",
                                marks: [
                                    EpdocTextMark(type: .bold),
                                    EpdocTextMark(type: .italic),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(envelope)
        let projected = try #require(
            EpdocContentCompatibilityProjection.proseMirrorNode(from: data)
        )

        #expect(projected.content?.first?.content?.first?.marks?.map(\.type) == ["strong", "em"])
        #expect(ProseMirrorMarkdownProjector.project(projected) == "***Styled***\n")
    }

    @Test("native session changes one stable block and reopens an exact checkpoint")
    func nativeSessionChangesOnlyAffectedBlock() throws {
        let initial = Self.canonicalEnvelope()
        let initialData = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: initialData)
        let untouchedBefore = try #require(session.node(id: "block-a"))
        let originalCharacters = "Alpha untouched".count + "Beta".count

        #expect(session.revision == 11)
        #expect(session.blockCount == 2)
        #expect(session.wordCount == 3)
        #expect(session.characterCount == originalCharacters)

        try session.replaceInlineContent(
            blockID: "block-b",
            children: [
                EpdocRichNode(
                    type: .text,
                    text: "Beta becomes edited",
                    marks: [EpdocTextMark(type: .italic)]
                ),
            ]
        )

        #expect(session.node(id: "block-a") == untouchedBefore)
        #expect(session.node(id: "block-b")?.id == "block-b")
        #expect(session.node(id: "block-b")?.children.first?.text == "Beta becomes edited")
        #expect(session.revision == 12)
        #expect(session.blockCount == 2)
        #expect(session.wordCount == 5)
        #expect(
            session.characterCount
                == "Alpha untouched".count + "Beta becomes edited".count
        )

        let checkpoint = try session.checkpointData()
        let decoded = try JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: checkpoint
        )
        try decoded.validate()
        #expect(decoded.root.children.map(\.id) == ["block-a", "block-b"])
        #expect(decoded.root.children.first == untouchedBefore)

        let reopened = try EpdocTextKit2EditorSession(contentJSON: checkpoint)
        #expect(reopened.revision == 12)
        #expect(reopened.blockCount == 2)
        #expect(reopened.wordCount == 5)
        #expect(reopened.node(id: "block-b")?.children.first?.text == "Beta becomes edited")
    }

    @Test("native session splits and merges one sibling block with stable identity")
    func nativeSessionSplitsAndMergesStableSiblingBlocks() throws {
        let initial = EpdocContentEnvelope(
            documentID: "epdoc-structural-session",
            revision: 40,
            root: EpdocRichNode(
                id: "epdoc-structural-session:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "block-a",
                        type: .paragraph,
                        children: [
                            EpdocRichNode(
                                type: .text,
                                text: "Alpha ",
                                marks: [EpdocTextMark(type: .bold)]
                            ),
                            EpdocRichNode(
                                type: .text,
                                text: "Beta",
                                marks: [EpdocTextMark(type: .italic)]
                            ),
                        ]
                    ),
                    EpdocRichNode(
                        id: "block-b",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "Untouched")]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)

        let splitID = try session.splitBlock(
            blockID: "block-a",
            atUTF16Offset: "Alpha ".utf16.count,
            newBlockID: "block-a-split"
        )

        #expect(splitID == "block-a-split")
        #expect(session.orderedEditableNodes().map(\.id) == ["block-a", "block-a-split", "block-b"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha ")
        #expect(Self.plainText(try #require(session.node(id: splitID))) == "Beta")
        #expect(session.node(id: "block-a")?.children.first?.marks.map(\.type) == [.bold])
        #expect(session.node(id: splitID)?.children.first?.marks.map(\.type) == [.italic])
        #expect(session.node(id: "block-b") == initial.root.children.last)
        #expect(session.revision == 41)
        #expect(session.blockCount == 3)

        try session.mergeBlocks(leadingBlockID: "block-a", trailingBlockID: splitID)

        #expect(session.orderedEditableNodes().map(\.id) == ["block-a", "block-b"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha Beta")
        #expect(session.node(id: splitID) == nil)
        #expect(session.node(id: "block-b") == initial.root.children.last)
        #expect(session.revision == 42)
        #expect(session.blockCount == 2)
        #expect(session.wordCount == 3)
        #expect(session.characterCount == "Alpha Beta".count + "Untouched".count)

        let checkpoint = try session.checkpointData()
        let reopened = try EpdocTextKit2EditorSession(contentJSON: checkpoint)
        #expect(reopened.orderedEditableNodes().map(\.id) == ["block-a", "block-b"])
        #expect(Self.plainText(try #require(reopened.node(id: "block-a"))) == "Alpha Beta")
        #expect(reopened.revision == 42)
    }

    @Test("native session rejects a split through a Unicode scalar without mutation")
    func nativeSessionRejectsInvalidUnicodeSplit() throws {
        let initial = EpdocContentEnvelope(
            documentID: "epdoc-unicode-split",
            revision: 5,
            root: EpdocRichNode(
                id: "epdoc-unicode-split:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "emoji-block",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "A🧠B")]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)

        #expect(throws: EpdocTextKit2EditorSessionError.self) {
            try session.splitBlock(
                blockID: "emoji-block",
                atUTF16Offset: 2,
                newBlockID: "invalid-split"
            )
        }
        #expect(session.revision == initial.revision)
        #expect(session.blockCount == 1)
        #expect(session.node(id: "invalid-split") == nil)
        #expect(Self.plainText(try #require(session.node(id: "emoji-block"))) == "A🧠B")
    }

    @Test("native session replaces a cross-block range as one canonical mutation")
    func nativeSessionReplacesCrossBlockRangeAtomically() throws {
        let initial = EpdocContentEnvelope(
            documentID: "epdoc-cross-block-session",
            revision: 20,
            root: EpdocRichNode(
                id: "epdoc-cross-block-session:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "leading-block",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "Alpha untouched")]
                    ),
                    EpdocRichNode(
                        id: "trailing-block",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "Beta")]
                    ),
                    EpdocRichNode(
                        id: "untouched-block",
                        type: .paragraph,
                        children: [EpdocRichNode(type: .text, text: "Gamma")]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)

        let removed = try session.replaceAcrossBlocks(
            leadingBlockID: "leading-block",
            leadingUTF16Offset: "Alpha ".utf16.count,
            trailingBlockID: "trailing-block",
            trailingUTF16Offset: "Be".utf16.count,
            replacement: [EpdocRichNode(type: .text, text: "joined")]
        )

        #expect(removed == ["trailing-block"])
        #expect(session.orderedEditableNodes().map(\.id) == ["leading-block", "untouched-block"])
        #expect(
            Self.plainText(try #require(session.node(id: "leading-block")))
                == "Alpha joinedta"
        )
        #expect(session.node(id: "trailing-block") == nil)
        #expect(session.node(id: "untouched-block") == initial.root.children.last)
        #expect(session.revision == 21)
        #expect(session.blockCount == 2)

        let checkpoint = try session.checkpointData()
        let reopened = try EpdocTextKit2EditorSession(contentJSON: checkpoint)
        #expect(
            Self.plainText(try #require(reopened.node(id: "leading-block")))
                == "Alpha joinedta"
        )
        #expect(reopened.node(id: "trailing-block") == nil)
        #expect(reopened.revision == 21)
    }

    @Test("native Epdoc canvas owns a TextKit 2 viewport layout controller")
    func nativeCanvasUsesTextKit2ViewportLayout() throws {
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let layoutManager = try #require(textView.textLayoutManager)

        #expect(scrollView.documentView === textView)
        #expect(layoutManager.textContentManager is NSTextContentStorage)
        #expect(layoutManager.textViewportLayoutController.textLayoutManager === layoutManager)
        #expect(textView.isVerticallyResizable)
        #expect(!textView.isHorizontallyResizable)
        #expect(textView.textContainer?.widthTracksTextView == true)
    }

    @Test("72k-word native Epdoc lays out a bounded TextKit 2 viewport")
    func largeNativeCanvasKeepsViewportRangeBounded() throws {
        let content = Self.largeEnvelope()
        let data = try JSONEncoder.epdocCanonical.encode(content)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let projection = EpdocAttributedProjection.make(session: session, theme: .oled)
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        scrollView.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        scrollView.autoresizingMask = [.width, .height]
        window.contentView = scrollView
        textView.textStorage?.setAttributedString(projection)
        window.layoutIfNeeded()
        scrollView.layoutSubtreeIfNeeded()

        let layoutManager = try #require(textView.textLayoutManager)
        let contentStorage = try #require(
            layoutManager.textContentManager as? NSTextContentStorage
        )
        let viewportController = layoutManager.textViewportLayoutController
        viewportController.layoutViewport()
        let viewportRange = try #require(viewportController.viewportRange)
        let documentRange = contentStorage.documentRange
        let documentLength = contentStorage.offset(
            from: documentRange.location,
            to: documentRange.endLocation
        )
        let viewportLength = contentStorage.offset(
            from: viewportRange.location,
            to: viewportRange.endLocation
        )

        #expect(session.wordCount >= 67_500)
        #expect(documentLength == projection.length)
        #expect(viewportLength > 0)
        #expect(viewportLength < documentLength)
        #expect(viewportLength < 100_000)
        withExtendedLifetime(window) {}
    }

    @Test("72k-word native Epdoc edits and backspaces across bounded viewports then reopens")
    func largeNativeCanvasEditsAcrossViewportsAndReopens() throws {
        let initial = Self.largeEnvelope(documentID: "epdoc-viewport-edit-fixture")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        scrollView.frame = window.contentView?.bounds
            ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        scrollView.autoresizingMask = [.width, .height]
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))
        window.layoutIfNeeded()
        scrollView.layoutSubtreeIfNeeded()

        let layoutManager = try #require(textView.textLayoutManager)
        let contentStorage = try #require(
            layoutManager.textContentManager as? NSTextContentStorage
        )
        let viewportController = layoutManager.textViewportLayoutController
        let documentRange = contentStorage.documentRange
        let documentLength = contentStorage.offset(
            from: documentRange.location,
            to: documentRange.endLocation
        )

        func viewportOffsets(at utf16Location: Int) throws -> Range<Int> {
            textView.scrollRangeToVisible(
                NSRange(
                    location: max(0, min(utf16Location, textView.string.utf16.count - 1)),
                    length: 0
                )
            )
            window.layoutIfNeeded()
            scrollView.layoutSubtreeIfNeeded()
            viewportController.layoutViewport()
            let viewportRange = try #require(viewportController.viewportRange)
            let lower = contentStorage.offset(
                from: documentRange.location,
                to: viewportRange.location
            )
            let upper = contentStorage.offset(
                from: documentRange.location,
                to: viewportRange.endLocation
            )
            #expect(upper > lower)
            #expect(upper - lower < documentLength)
            #expect(upper - lower < 100_000)
            return lower..<upper
        }

        let startViewport = try viewportOffsets(at: 0)
        let middleMarker = "2250 viewport"
        let middleMarkerRange = (textView.string as NSString).range(of: middleMarker)
        #expect(middleMarkerRange.location != NSNotFound)
        let middleViewport = try viewportOffsets(at: middleMarkerRange.location)
        let endViewport = try viewportOffsets(at: textView.string.utf16.count - 1)

        #expect(startViewport.lowerBound < middleViewport.lowerBound)
        #expect(middleViewport.lowerBound < endViewport.lowerBound)

        textView.setSelectedRange(
            NSRange(location: middleMarkerRange.location, length: 0)
        )
        textView.moveToEndOfDocumentAndModifySelection(nil)
        let responderSelection = textView.selectedRange()
        #expect(responderSelection.location == middleMarkerRange.location)
        #expect(responderSelection.length > middleViewport.count)
        #expect(session.revision == initial.revision)
        let selectionEndViewport = try viewportOffsets(
            at: NSMaxRange(responderSelection) - 1
        )
        #expect(selectionEndViewport.count < documentLength)

        _ = try viewportOffsets(at: middleMarkerRange.location)
        let wordRange = (textView.string as NSString).range(
            of: "viewport",
            options: [],
            range: middleMarkerRange
        )
        #expect(wordRange.location != NSNotFound)
        textView.insertText("durable", replacementRange: wordRange)
        let insertedEnd = wordRange.location + "durable".utf16.count
        textView.setSelectedRange(NSRange(location: insertedEnd, length: 0))
        textView.deleteBackward(nil)

        let edited = try #require(session.node(id: "block-2250"))
        let editedText = Self.plainText(edited)
        #expect(editedText.hasPrefix("2250 durabl viewport"))
        #expect(!editedText.hasPrefix("2250 viewport"))
        #expect(session.revision == initial.revision + 2)
        #expect(controller.toolbarModel.isDirty)

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        let reopenedBlock = try #require(reopened.node(id: "block-2250"))
        #expect(Self.plainText(reopenedBlock) == editedText)
        #expect(reopened.revision == session.revision)
        #expect(controller.toolbarModel.isDirty)
        withExtendedLifetime(window) {}
    }

    @Test("native multi-block selection preserves stable blocks and semantic marks")
    func nativeMultiBlockSelectionPreservesStableBlocksAndMarks() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-selection-fixture")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let selection = (textView.string as NSString).range(of: "Alpha untouched\nBeta")
        #expect(selection.location != NSNotFound)
        textView.setSelectedRange(selection)
        controller.dispatch(.runCommand(name: "toggleItalic", argsJSON: Data("[]".utf8)))

        let heading = try #require(session.node(id: "block-a"))
        let paragraph = try #require(session.node(id: "block-b"))
        #expect(heading.id == "block-a")
        #expect(paragraph.id == "block-b")
        #expect(heading.children.first?.marks.map(\.type).contains(.italic) == true)
        #expect(paragraph.children.first?.marks.map(\.type).contains(.italic) == true)
        #expect(textView.selectedRange() == selection)
        #expect(session.revision == initial.revision + 1)

        let undoManager = try #require(textView.undoManager)
        undoManager.undo()
        #expect(session.node(id: "block-a") == initial.root.children.first)
        #expect(session.node(id: "block-b") == initial.root.children.last)
        #expect(session.revision == initial.revision)
        undoManager.redo()
        #expect(
            session.node(id: "block-a")?.children.first?.marks.map(\.type).contains(.italic)
                == true
        )
        #expect(
            session.node(id: "block-b")?.children.first?.marks.map(\.type).contains(.italic)
                == true
        )
        #expect(session.revision == initial.revision + 1)

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(reopened.node(id: "block-a")?.id == "block-a")
        #expect(reopened.node(id: "block-b")?.id == "block-b")
        #expect(
            reopened.node(id: "block-a")?.children.first?.marks.map(\.type).contains(.italic)
                == true
        )
        #expect(
            reopened.node(id: "block-b")?.children.first?.marks.map(\.type).contains(.italic)
                == true
        )
        withExtendedLifetime(window) {}
    }

    @Test("native cross-block replacement commits one canonical survivor")
    func nativeCrossBlockReplacementCommitsOneCanonicalSurvivor() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-cross-block-ui")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let selection = (textView.string as NSString).range(of: "untouched\nBe")
        #expect(selection.location != NSNotFound)
        textView.insertText("joined", replacementRange: selection)

        #expect(session.orderedEditableNodes().map(\.id) == ["block-a"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha joinedta")
        #expect(session.node(id: "block-b") == nil)
        #expect(session.revision == initial.revision + 1)
        #expect(textView.string == "Alpha joinedta\n")
        #expect(textView.selectedRange().location == "Alpha joined".utf16.count)

        let undoManager = try #require(textView.undoManager)
        undoManager.undo()
        #expect(session.orderedEditableNodes().map(\.id) == ["block-a", "block-b"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha untouched")
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == "Beta")
        #expect(session.revision == initial.revision)
        #expect(textView.string == "Alpha untouched\nBeta\n")

        undoManager.redo()
        #expect(session.orderedEditableNodes().map(\.id) == ["block-a"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha joinedta")
        #expect(session.node(id: "block-b") == nil)
        #expect(session.revision == initial.revision + 1)
        #expect(textView.string == "Alpha joinedta\n")

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(reopened.orderedEditableNodes().map(\.id) == ["block-a"])
        #expect(Self.plainText(try #require(reopened.node(id: "block-a"))) == "Alpha joinedta")
        withExtendedLifetime(window) {}
    }

    @Test("native Return splits and boundary Backspace merges with stable identity")
    func nativeReturnSplitsAndBoundaryBackspaceMerges() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-structural-ui")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let splitLocation = "Alpha ".utf16.count
        textView.setSelectedRange(NSRange(location: splitLocation, length: 0))
        textView.insertNewline(nil)

        let splitOrder = session.orderedEditableNodes().compactMap(\.id)
        #expect(splitOrder.count == 3)
        #expect(splitOrder.first == "block-a")
        #expect(splitOrder.last == "block-b")
        let newBlockID = try #require(splitOrder.dropFirst().first)
        #expect(newBlockID != "block-a")
        #expect(newBlockID != "block-b")
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha ")
        #expect(Self.plainText(try #require(session.node(id: newBlockID))) == "untouched")
        #expect(session.revision == initial.revision + 1)
        #expect(textView.selectedRange().location == splitLocation + 1)

        let undoManager = try #require(textView.undoManager)
        undoManager.undo()
        #expect(session.orderedEditableNodes().compactMap(\.id) == ["block-a", "block-b"])
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha untouched")
        #expect(session.node(id: newBlockID) == nil)
        #expect(session.revision == initial.revision)
        undoManager.redo()
        #expect(
            session.orderedEditableNodes().compactMap(\.id)
                == ["block-a", newBlockID, "block-b"]
        )
        #expect(Self.plainText(try #require(session.node(id: newBlockID))) == "untouched")
        #expect(session.revision == initial.revision + 1)

        textView.deleteBackward(nil)

        #expect(session.orderedEditableNodes().compactMap(\.id) == ["block-a", "block-b"])
        #expect(session.node(id: newBlockID) == nil)
        #expect(Self.plainText(try #require(session.node(id: "block-a"))) == "Alpha untouched")
        #expect(session.node(id: "block-b") == initial.root.children.last)
        #expect(session.revision == initial.revision + 2)
        #expect(textView.selectedRange().location == splitLocation)

        undoManager.undo()
        #expect(
            session.orderedEditableNodes().compactMap(\.id)
                == ["block-a", newBlockID, "block-b"]
        )
        #expect(Self.plainText(try #require(session.node(id: newBlockID))) == "untouched")
        undoManager.redo()
        #expect(session.orderedEditableNodes().compactMap(\.id) == ["block-a", "block-b"])
        #expect(session.node(id: newBlockID) == nil)

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(reopened.orderedEditableNodes().compactMap(\.id) == ["block-a", "block-b"])
        #expect(reopened.node(id: newBlockID) == nil)
        #expect(Self.plainText(try #require(reopened.node(id: "block-a"))) == "Alpha untouched")
        withExtendedLifetime(window) {}
    }

    @Test("native multiline paste creates sibling blocks and heading stays selection-scoped")
    func nativeMultilinePasteAndHeadingAreStructuralAndScoped() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-paste-heading-fixture")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))
        let undoManager = try #require(textView.undoManager)
        undoManager.groupsByEvent = false

        let beta = (textView.string as NSString).range(of: "Beta")
        #expect(beta.location != NSNotFound)
        undoManager.beginUndoGrouping()
        textView.insertText("Title\nBody\nTail", replacementRange: beta)
        undoManager.endUndoGrouping()

        let pastedIDs = session.orderedEditableNodes().compactMap(\.id)
        try #require(pastedIDs.count == 4)
        #expect(pastedIDs.first == "block-a")
        #expect(pastedIDs[1] == "block-b")
        let pastedTexts = try pastedIDs.dropFirst().map { blockID in
            Self.plainText(try #require(session.node(id: blockID)))
        }
        #expect(pastedTexts == ["Title", "Body", "Tail"])
        #expect(session.revision == initial.revision + 1)

        let bodyRange = (textView.string as NSString).range(of: "Body")
        #expect(bodyRange.location != NSNotFound)
        textView.setSelectedRange(bodyRange)
        undoManager.beginUndoGrouping()
        controller.dispatch(.runCommand(
            name: "setHeadingLevel",
            argsJSON: Data(#"[{"level":2}]"#.utf8)
        ))
        undoManager.endUndoGrouping()

        #expect(session.node(id: pastedIDs[1])?.type == .paragraph)
        #expect(session.node(id: pastedIDs[2])?.type == .heading)
        #expect(session.node(id: pastedIDs[2])?.attributes["level"] == .int(2))
        #expect(session.node(id: pastedIDs[3])?.type == .paragraph)
        #expect(session.node(id: "block-a") == initial.root.children.first)
        #expect(session.revision == initial.revision + 2)

        undoManager.undo()
        #expect(session.node(id: pastedIDs[2])?.type == .paragraph)
        undoManager.redo()
        #expect(session.node(id: pastedIDs[2])?.type == .heading)

        coordinator.flushCheckpoint()
        let reopened = try EpdocTextKit2EditorSession(contentJSON: try #require(checkpoint))
        #expect(reopened.orderedEditableNodes().compactMap(\.id) == pastedIDs)
        #expect(reopened.node(id: pastedIDs[2])?.type == .heading)
        withExtendedLifetime(window) {}
    }

    @Test("native width changes recenter without mutating canonical content")
    func nativeWidthChangesArePresentationOnly() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-width-fixture")
        let session = try EpdocTextKit2EditorSession(
            contentJSON: JSONEncoder.epdocCanonical.encode(initial)
        )
        let controller = EpdocEditorChromeController()
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { _ in }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        scrollView.frame = NSRect(x: 0, y: 0, width: 1_200, height: 700)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_200, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        textView.setSelectedRange(NSRange(location: 2, length: 3))
        let originalJSON = try session.checkpointData()

        controller.dispatch(.setContentWidth(mode: .normal))
        let normalInset = textView.textContainerInset.width
        controller.dispatch(.setContentWidth(mode: .wide))
        let wideInset = textView.textContainerInset.width
        controller.dispatch(.setContentWidth(mode: .normal))

        #expect(normalInset > wideInset)
        #expect(textView.textContainerInset.width == normalInset)
        #expect(textView.selectedRange() == NSRange(location: 2, length: 3))
        #expect(try session.checkpointData() == originalJSON)
        #expect(session.revision == initial.revision)
        #expect(!controller.toolbarModel.isDirty)
        withExtendedLifetime(window) {}
    }

    @Test("native Unicode edit undo and redo remain canonical")
    func nativeUnicodeEditUndoRedoRemainsCanonical() throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-unicode-undo-fixture")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let beta = (textView.string as NSString).range(of: "Beta")
        #expect(beta.location != NSNotFound)
        let replacement = "🧠漢字e\u{301}"
        textView.insertText(replacement, replacementRange: beta)
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == replacement)

        textView.undoManager?.undo()
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == "Beta")

        textView.undoManager?.redo()
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == replacement)
        #expect(session.node(id: "block-a") == initial.root.children.first)
        #expect(textView.selectedRange().location <= textView.string.utf16.count)

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(Self.plainText(try #require(reopened.node(id: "block-b"))) == replacement)
        #expect(reopened.node(id: "block-a") == initial.root.children.first)
        withExtendedLifetime(window) {}
    }

    @Test("native marked text does not mutate or checkpoint until IME commit")
    func nativeMarkedTextWaitsForIMECommit() async throws {
        let initial = Self.canonicalEnvelope(documentID: "epdoc-ime-fixture")
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let beta = (textView.string as NSString).range(of: "Beta")
        #expect(beta.location != NSNotFound)
        textView.setMarkedText(
            "漢",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: beta
        )
        textView.setMarkedText(
            "漢字",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )

        #expect(textView.hasMarkedText())
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == "Beta")
        #expect(session.revision == initial.revision)
        try await Task.sleep(for: .milliseconds(400))
        #expect(checkpoint == nil)
        #expect(session.revision == initial.revision)

        textView.insertText(
            "漢字",
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(!textView.hasMarkedText())
        #expect(Self.plainText(try #require(session.node(id: "block-b"))) == "漢字")
        #expect(session.revision == initial.revision + 1)

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(Self.plainText(try #require(reopened.node(id: "block-b"))) == "漢字")
        withExtendedLifetime(window) {}
    }

    @Test("native inline attachment survives an adjacent edit and reopen")
    func nativeInlineAttachmentSurvivesAdjacentEditAndReopen() throws {
        let image = EpdocRichNode(
            id: "inline-image",
            type: .image,
            attributes: [
                "src": .string("assets/image.png"),
                "alt": .string("A retained image"),
            ]
        )
        let initial = EpdocContentEnvelope(
            documentID: "epdoc-inline-attachment",
            root: EpdocRichNode(
                id: "epdoc-inline-attachment:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "attachment-block",
                        type: .paragraph,
                        children: [
                            EpdocRichNode(type: .text, text: "Before "),
                            image,
                            EpdocRichNode(type: .text, text: " after"),
                        ]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let controller = EpdocEditorChromeController()
        var checkpoint: Data?
        let coordinator = EpdocTextKit2EditorRepresentable.Coordinator(
            session: session,
            controller: controller,
            theme: .oled,
            onCheckpoint: { checkpoint = $0 }
        )
        let (scrollView, textView) = EpdocTextView.makeTextKit2()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        coordinator.attach(textView: textView, scrollView: scrollView)
        defer { coordinator.detach() }
        #expect(window.makeFirstResponder(textView))

        let before = (textView.string as NSString).range(of: "Before")
        #expect(before.location != NSNotFound)
        textView.insertText("Earlier", replacementRange: before)

        let edited = try #require(session.node(id: "attachment-block"))
        #expect(edited.children.contains(image))
        #expect(session.node(id: "inline-image") == image)
        #expect(textView.string.contains("Earlier"))
        #expect(textView.string.contains("\u{FFFC}"))

        coordinator.flushCheckpoint()
        let saved = try #require(checkpoint)
        let reopened = try EpdocTextKit2EditorSession(contentJSON: saved)
        #expect(reopened.node(id: "inline-image") == image)
        #expect(reopened.node(id: "attachment-block")?.children.contains(image) == true)
        withExtendedLifetime(window) {}
    }

    @Test("native nested rich blocks project each editable leaf exactly once")
    func nativeNestedRichBlocksProjectEachLeafOnce() throws {
        let initial = EpdocContentEnvelope(
            documentID: "epdoc-nested-rich-blocks",
            root: EpdocRichNode(
                id: "epdoc-nested-rich-blocks:root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "bullet-list",
                        type: .bulletList,
                        children: [
                            EpdocRichNode(
                                id: "list-item",
                                type: .listItem,
                                children: [
                                    EpdocRichNode(
                                        id: "list-paragraph",
                                        type: .paragraph,
                                        children: [
                                            EpdocRichNode(type: .text, text: "Nested list leaf")
                                        ]
                                    ),
                                    EpdocRichNode(
                                        id: "list-paragraph-continuation",
                                        type: .paragraph,
                                        children: [
                                            EpdocRichNode(type: .text, text: "Same item continuation")
                                        ]
                                    ),
                                ]
                            ),
                        ]
                    ),
                    EpdocRichNode(
                        id: "checklist",
                        type: .checklist,
                        children: [
                            EpdocRichNode(
                                id: "check-item",
                                type: .checklistItem,
                                attributes: ["checked": .bool(false)],
                                children: [
                                    EpdocRichNode(type: .text, text: "Direct checklist leaf")
                                ]
                            ),
                        ]
                    ),
                    EpdocRichNode(
                        id: "table",
                        type: .table,
                        children: [
                            EpdocRichNode(
                                id: "table-row",
                                type: .tableRow,
                                children: [
                                    EpdocRichNode(
                                        id: "table-cell",
                                        type: .tableCell,
                                        children: [
                                            EpdocRichNode(
                                                id: "cell-paragraph",
                                                type: .paragraph,
                                                children: [
                                                    EpdocRichNode(type: .text, text: "Nested cell leaf")
                                                ]
                                            ),
                                        ]
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        let data = try JSONEncoder.epdocCanonical.encode(initial)
        let session = try EpdocTextKit2EditorSession(contentJSON: data)
        let attributed = EpdocAttributedProjection.make(session: session, theme: .oled)
        let projected = attributed.string

        #expect(session.orderedEditableNodes().map(\.id) == [
            "list-paragraph",
            "list-paragraph-continuation",
            "check-item",
            "cell-paragraph",
        ])
        #expect(projected.components(separatedBy: "Nested list leaf").count - 1 == 1)
        #expect(projected.components(separatedBy: "Same item continuation").count - 1 == 1)
        #expect(projected.components(separatedBy: "Direct checklist leaf").count - 1 == 1)
        #expect(projected.components(separatedBy: "Nested cell leaf").count - 1 == 1)

        let listPresentation = try #require(
            session.presentation(blockID: "list-paragraph")
        )
        let checklistPresentation = try #require(
            session.presentation(blockID: "check-item")
        )
        let listContinuationPresentation = try #require(
            session.presentation(blockID: "list-paragraph-continuation")
        )
        let tablePresentation = try #require(
            session.presentation(blockID: "cell-paragraph")
        )
        #expect(listPresentation.listMarker == .bullet)
        #expect(listPresentation.listNestingLevel == 1)
        #expect(listContinuationPresentation.listMarker == nil)
        #expect(listContinuationPresentation.listNestingLevel == 1)
        #expect(checklistPresentation.listMarker == .checklist(isChecked: false))
        #expect(checklistPresentation.listNestingLevel == 1)
        #expect(tablePresentation.tableRole == .cell)

        let listRange = (projected as NSString).range(of: "Nested list leaf")
        let checklistRange = (projected as NSString).range(of: "Direct checklist leaf")
        let listContinuationRange = (projected as NSString).range(of: "Same item continuation")
        let listStyle = attributed.attribute(
            .paragraphStyle,
            at: listRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        let checklistStyle = attributed.attribute(
            .paragraphStyle,
            at: checklistRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        let listContinuationStyle = attributed.attribute(
            .paragraphStyle,
            at: listContinuationRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(listStyle?.textLists.count == 1)
        #expect(listContinuationStyle?.textLists.isEmpty == true)
        #expect(checklistStyle?.textLists.count == 1)
    }
}
