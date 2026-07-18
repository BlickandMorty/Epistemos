import Foundation
import Testing

@testable import Epistemos

/// Wave 7.17.a source-guard for the SwiftUI top-toolbar shell.
/// We can't render-test SwiftUI views from Swift Testing without
/// an XCUITest harness — instead we pin the model contract +
/// command-dispatch round-trip.
@Suite("EpdocEditorToolbar (Wave 7.17.a)")
@MainActor
struct EpdocEditorToolbarTests {

    @Test("Default toolbar model starts in the canonical idle state")
    func defaultModelIsIdle() {
        let model = EpdocEditorToolbarModel()
        #expect(model.wordCount == 0)
        #expect(model.characterCount == 0)
        #expect(model.isDirty == false)
        #expect(model.isSaving == false)
        #expect(model.activeHeadingLevel == nil)
        #expect(model.isBoldActive == false)
        #expect(model.isItalicActive == false)
        #expect(model.isStrikeActive == false)
        #expect(model.isCodeActive == false)
        #expect(model.isHighlightActive == false)
        #expect(model.widthMode == .normal)
        #expect(model.isFindReplacePresented == false)
    }

    @Test("Setting word/char count updates @Observable surface")
    func observableWordCount() {
        let model = EpdocEditorToolbarModel()
        model.wordCount = 142
        model.characterCount = 856
        #expect(model.wordCount == 142)
        #expect(model.characterCount == 856)
    }

    @Test("Dispatch closure surfaces the EpdocEditorCommand the button fires")
    func dispatchCapturesCommand() async {
        let model = EpdocEditorToolbarModel()

        // Use an actor for thread-safe capture across the @Sendable boundary
        // — `dispatch` is annotated @Sendable @MainActor so the closure
        // body is allowed to mutate MainActor-isolated state.
        actor CaptureBox {
            var captured: [EpdocEditorCommand] = []
            func append(_ cmd: EpdocEditorCommand) { captured.append(cmd) }
            func snapshot() -> [EpdocEditorCommand] { captured }
        }
        let box = CaptureBox()
        model.dispatch = { cmd in
            Task { await box.append(cmd) }
        }

        // Simulate a user pressing the Bold button.
        let argsJSON = "[]".data(using: .utf8)!
        model.dispatch(.runCommand(name: "toggleBold", argsJSON: argsJSON))

        // Drain any async tasks the dispatch closure spawned
        try? await Task.sleep(nanoseconds: 50_000_000)
        let captured = await box.snapshot()
        #expect(captured.count == 1)
        if case let .runCommand(name, _) = captured.first {
            #expect(name == "toggleBold")
        } else {
            #expect(Bool(false), "expected .runCommand(name: 'toggleBold')")
        }
    }

    @Test("Dirty + saving flags drive separate UI states (button selectors don't conflate them)")
    func dirtyAndSavingAreOrthogonal() {
        let model = EpdocEditorToolbarModel()
        model.isDirty = true
        model.isSaving = false
        // Both flags exist + are independent
        #expect(model.isDirty)
        #expect(!model.isSaving)

        model.isSaving = true
        #expect(model.isDirty)  // dirty stays set during save
        #expect(model.isSaving)
    }

    @Test("Active heading level surfaces 1...6 + nil for paragraph-mode")
    func headingLevelTracking() {
        let model = EpdocEditorToolbarModel()
        for level in 1...6 {
            model.activeHeadingLevel = level
            #expect(model.activeHeadingLevel == level)
        }
        model.activeHeadingLevel = nil
        #expect(model.activeHeadingLevel == nil)
    }

    @Test("Heading control exposes H1-H6 and dispatches through the scoped heading command")
    func headingControlUsesScopedHeadingMenu() throws {
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")

        #expect(toolbar.contains("Menu {"))
        #expect(toolbar.contains("ForEach(1...6"))
        #expect(toolbar.contains(#"name: "setHeadingLevel""#))
        #expect(toolbar.contains(#"name: "setParagraph""#))
        #expect(!toolbar.contains(#"command: .insertSlashChoice(blockType: "heading-1")"#))
    }

    @Test("Note width control exposes normal, wide, and custom slider commands")
    func noteWidthControlUsesBridgeCommand() throws {
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")

        #expect(toolbar.contains("widthGroup"))
        #expect(toolbar.contains("EditorContentWidthControl"))
        #expect(toolbar.contains(#"apply(.custom(px: Int(rounded)))"#))
        #expect(toolbar.contains(#"Slider("#))
        #expect(toolbar.contains(#".setContentWidth(mode: mode)"#))
    }

    @Test("full Epdoc toolbar remains reachable in narrow windows")
    func fullToolbarUsesHorizontalOverflowInsteadOfClipping() throws {
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")

        #expect(toolbar.contains("ScrollView(.horizontal)"))
        #expect(toolbar.contains(".scrollIndicators(.hidden)"))
        #expect(toolbar.contains("formattingGroup"))
        #expect(toolbar.contains("extendedFormattingGroup"))
        #expect(toolbar.contains("insertGroup"))
        #expect(toolbar.contains("structureGroup"))
    }

    @Test("Find and Replace control exposes native popover commands")
    func findReplaceControlUsesBridgeCommands() throws {
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")

        #expect(toolbar.contains("findGroup"))
        #expect(toolbar.contains(#".keyboardShortcut("f", modifiers: .command)"#))
        #expect(toolbar.contains(#".setFindQuery(query: findQuery, caseSensitive: findCaseSensitive)"#))
        #expect(toolbar.contains(#".findNext(query: findQuery, caseSensitive: findCaseSensitive)"#))
        #expect(toolbar.contains(#".replaceCurrent("#))
        #expect(toolbar.contains(#".replaceAll("#))
        #expect(toolbar.contains(#".clearFindHighlights"#))
    }

    @Test("Epdoc Find and Replace is wired to ProseMirror decorations, not CodeMirror search")
    func findReplaceUsesProseMirrorSearchExtension() throws {
        let index = try loadMirroredSourceTextFile("js-editor/src/index.ts")
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")
        let findReplace = try loadMirroredSourceTextFile("js-editor/src/extensions/find-replace.ts")

        #expect(index.contains("EpdocFindReplace"))
        #expect(inbound.contains("setFindQuery(editor, query"))
        #expect(findReplace.contains("new Plugin<FindReplaceState>"))
        #expect(findReplace.contains("Decoration.inline("))
        #expect(findReplace.contains("replaceAll("))
        #expect(!findReplace.contains("@codemirror/search"))
    }

    @Test("Inbound heading command scopes formatting to the active text block")
    func inboundHeadingCommandScopesToActiveTextBlock() throws {
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")

        #expect(inbound.contains("setHeadingLevel(editor, level)"))
        #expect(inbound.contains("function setHeadingLevel(editor: Editor, level: number): boolean"))
        #expect(inbound.contains("function textblockDepth("))
        #expect(inbound.contains("state.tr.setNodeMarkup("))
        #expect(inbound.contains("headingLevelFromArgs(args)"))
    }

    @Test("Inbound heading command isolates hard-break visual lines before changing style")
    func inboundHeadingCommandIsolatesHardBreakLines() throws {
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")

        #expect(inbound.contains("function splitTextblockAroundHardBreaks(editor: Editor, depth: number): boolean"))
        #expect(inbound.contains("child.type.name !== 'hardBreak'"))
        #expect(inbound.contains("Fragment.fromArray(pieces)"))
        #expect(inbound.contains("return setHeadingLevel(editor, level);"))
        #expect(inbound.contains("return setParagraph(editor);"))
    }
}
