import CoreGraphics
import Foundation
import Testing
@testable import Epistemos

@Suite("Note Toolbar Glow")
struct NoteToolbarGlowTests {

    @Test("idle phase disables outer halo")
    func idlePhaseDisablesOuterHalo() {
        let style = AssistantComposerHaloStyle.resolve(for: .idle)

        #expect(style == nil)
    }

    @Test("empty toolbar field shows phase-aware label text")
    func emptyToolbarFieldShowsPhaseAwareLabelText() throws {
        let idle = try #require(
            AssistantComposerStatusLabelState.resolve(
                inputText: "",
                phase: .idle,
                idleText: "Ask this note"
            )
        )
        let analyzing = try #require(
            AssistantComposerStatusLabelState.resolve(
                inputText: "",
                phase: .analyzing,
                idleText: "Ask this note"
            )
        )
        let typing = try #require(
            AssistantComposerStatusLabelState.resolve(
                inputText: "",
                phase: .typing,
                idleText: "Ask this note"
            )
        )

        #expect(idle.text == "Ask this note")
        #expect(!idle.usesSweepHighlight)
        #expect(analyzing.text == "Thinking…")
        #expect(analyzing.usesSweepHighlight)
        #expect(typing.text == "Responding…")
        #expect(typing.usesSweepHighlight)
    }

    @Test("typed input hides animated label")
    func typedInputHidesAnimatedLabel() {
        let state = AssistantComposerStatusLabelState.resolve(
            inputText: "Hello",
            phase: .analyzing,
            idleText: "Ask this note"
        )

        #expect(state == nil)
    }

    @Test("analyzing phase carries the strongest cool halo")
    func analyzingPhaseCarriesStrongestCoolHalo() throws {
        let style = try #require(AssistantComposerHaloStyle.resolve(for: .analyzing))

        #expect(style.tone == .cool)
        #expect(style.lineWidth > 1.5)
        #expect(style.primaryOpacity > 0.3)
        #expect(style.secondaryOpacity > 0.18)
    }

    @Test("typing phase warms up but stays calmer than analyzing")
    func typingPhaseWarmsUpButStaysCalmerThanAnalyzing() throws {
        let typing = try #require(AssistantComposerHaloStyle.resolve(for: .typing))
        let analyzing = try #require(AssistantComposerHaloStyle.resolve(for: .analyzing))

        #expect(typing.tone == .warm)
        #expect(typing.primaryOpacity < analyzing.primaryOpacity)
        #expect(typing.secondaryOpacity < analyzing.secondaryOpacity)
        #expect(typing.expansion < analyzing.expansion)
    }

    @Test("outline stroke stays softer than the glow bloom")
    func outlineStrokeStaysSofterThanGlowBloom() throws {
        let analyzing = try #require(AssistantComposerHaloStyle.resolve(for: .analyzing))
        let typing = try #require(AssistantComposerHaloStyle.resolve(for: .typing))

        #expect(analyzing.strokeOpacity < 0.20)
        #expect(typing.strokeOpacity < 0.15)
        #expect(analyzing.primaryOpacity > 0.3)
        #expect(typing.primaryOpacity > 0.2)
    }

    @Test("note ask bar chrome tuning calms the outline and adds subtle shadow depth")
    func noteAskBarChromeTuningCalmsOutlineAndAddsSubtleShadowDepth() throws {
        let chrome = AssistantToolbarAskBarChromeTuning.noteAskBar
        let noteWorkspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(chrome.haloStrokeOpacityMultiplier < 1.0)
        #expect(chrome.haloLineWidthMultiplier < 1.0)
        #expect(chrome.borderOpacityMultiplier < 1.0)
        #expect(chrome.surfaceShadowOpacity > 0.0)
        #expect(chrome.outlineShadowOpacity > 0.0)
        #expect(noteWorkspace.contains("chromeTuning: .noteAskBar"))
    }

    @Test("streaming status stays analyzing until visible tokens arrive")
    func streamingStatusStaysAnalyzingUntilVisibleTokensArrive() {
        #expect(AssistantComposerStatusPhase.resolve(isActive: false, streamingText: "") == .idle)
        #expect(AssistantComposerStatusPhase.resolve(isActive: true, streamingText: "") == .analyzing)
        #expect(
            AssistantComposerStatusPhase.resolve(isActive: true, streamingText: "Thinking Process")
                == .analyzing
        )
        #expect(
            AssistantComposerStatusPhase.resolve(isActive: true, streamingText: "Visible answer")
                == .typing
        )
    }

    @Test("active note toolbar label avoids a duplicated base text layer")
    func activeNoteToolbarLabelAvoidsDuplicatedBaseTextLayer() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(
            !source.contains(
                """
                ZStack(alignment: .leading) {
                                labelText
                                    .foregroundStyle(baseTextColor)

                                if reduceMotion {
                """
            )
        )
        #expect(source.contains("private var alignedLabelMask: some View"))
        #expect(source.contains(".mask(alignedLabelMask)"))
        #expect(!source.contains(".mask(labelText)"))
    }

    @Test("active composer treatment warms into glow instead of snapping on")
    func activeComposerTreatmentWarmsIntoGlowInsteadOfSnappingOn() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(source.contains("private enum AssistantComposerWarmup"))
        #expect(source.contains("@State private var activationProgress: CGFloat = 0"))
        #expect(source.contains("withAnimation(AssistantComposerWarmup.animation(for: phase))"))
        #expect(source.contains(".blur(radius: (1 - activationProgress) * 6)"))
        #expect(source.contains(".opacity(Double(activationProgress))"))
    }

    @Test("main and mini chat composers use the shared animated status treatment")
    func mainAndMiniChatComposersUseSharedAnimatedStatusTreatment() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(mainChat.contains("AssistantAnimatedStatusLabel("))
        #expect(mainChat.contains("AssistantComposerOuterHalo("))
        #expect(mainChat.contains("cornerRadius: composerMetrics.cornerRadius"))
        #expect(miniChat.contains("AssistantAnimatedStatusLabel("))
        #expect(miniChat.contains("AssistantComposerOuterHalo("))
        #expect(miniChat.contains("cornerRadius: composerMetrics.cornerRadius"))
        #expect(sharedStatus.contains("RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)"))
    }

    @Test("main and mini chat use the lighter halo path on large composers")
    func mainAndMiniChatUseLighterHaloPath() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(sharedStatus.contains("let animatesContinuously: Bool"))
        #expect(sharedStatus.contains("if reduceMotion || !animatesContinuously"))
        #expect(sharedStatus.contains("TimelineView(.animation(minimumInterval: 1.0 / 24.0))"))
        #expect(mainChat.contains("animatesContinuously: false"))
        #expect(miniChat.contains("animatesContinuously: false"))
        #expect(!mainChat.contains(".compositingGroup()"))
        #expect(!miniChat.contains(".compositingGroup()"))
    }

    @Test("status shimmer no longer scales with the full composer width")
    func statusShimmerNoLongerScalesWithFullComposerWidth() throws {
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(sharedStatus.contains("private var sweepWidth: CGFloat"))
        #expect(sharedStatus.contains("CGFloat(state.text.count) * 14"))
        #expect(!sharedStatus.contains("GeometryReader { proxy in"))
        #expect(!sharedStatus.contains("let width = max(proxy.size.width, 120)"))
    }

    @Test("main and mini chat composers pin the text area to its real height")
    func mainAndMiniChatComposersPinTheTextAreaToItsRealHeight() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(mainChat.contains("private var composerTextAreaHeight: CGFloat"))
        #expect(mainChat.contains(".frame(height: composerTextAreaHeight, alignment: .topLeading)"))
        #expect(!mainChat.contains(".frame(minHeight: ChatComposerInputMetrics.minHeight, alignment: .topLeading)"))
        #expect(!mainChat.contains(".layoutPriority(1)"))

        #expect(miniChat.contains("private var composerTextAreaHeight: CGFloat"))
        #expect(miniChat.contains(".frame(height: composerTextAreaHeight, alignment: .topLeading)"))
        #expect(!miniChat.contains(".frame(minHeight: ChatComposerInputMetrics.minHeight, alignment: .topLeading)"))
        #expect(!miniChat.contains(".layoutPriority(1)"))
    }

    @Test("main and mini chat status labels stay out of the text editor layout pass")
    func mainAndMiniChatStatusLabelsStayOutOfTheTextEditorLayoutPass() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(
            !mainChat.contains(
                """
                private var composerTextArea: some View {
                    ZStack(alignment: .topLeading) {
                """
            )
        )
        #expect(
            !miniChat.contains(
                """
                private var composerTextArea: some View {
                    ZStack(alignment: .topLeading) {
                """
            )
        )
        #expect(mainChat.contains(".overlay(alignment: .topLeading) {"))
        #expect(miniChat.contains(".overlay(alignment: .topLeading) {"))
    }

    @Test("main and mini chat status labels share the text editor horizontal inset")
    func mainAndMiniChatStatusLabelsShareTheTextEditorHorizontalInset() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(mainChat.contains("static let horizontalInset: CGFloat"))
        #expect(mainChat.contains("textView.textContainerInset = NSSize("))
        #expect(mainChat.contains("width: ChatComposerInputMetrics.horizontalInset"))
        #expect(mainChat.contains(".padding(.leading, ChatComposerInputMetrics.horizontalInset)"))
        #expect(miniChat.contains(".padding(.leading, ChatComposerInputMetrics.horizontalInset)"))
    }

    @Test("chat composer native height updates are coalesced before they hit SwiftUI state")
    func chatComposerNativeHeightUpdatesAreCoalescedBeforeTheyHitSwiftUIState() throws {
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

        #expect(mainChat.contains("private var pendingHeight: CGFloat?"))
        #expect(mainChat.contains("if abs(parent.height - clampedHeight) > 0.5, pendingHeight != clampedHeight"))
        #expect(mainChat.contains("self.pendingHeight = nil"))
    }

    @Test("shared note ask bar keeps animated labels out of the toolbar field layout")
    func sharedNoteAskBarKeepsAnimatedLabelsOutOfTheToolbarFieldLayout() throws {
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(
            !sharedStatus.contains(
                """
                ZStack(alignment: .leading) {
                                if let labelState {
                                    AssistantAnimatedStatusLabel(
                """
            )
        )
        #expect(sharedStatus.contains("TextField(\"\", text: $text)"))
        #expect(sharedStatus.contains(".overlay(alignment: .leading) {"))
    }

    @Test("transcript loading state uses a dot bubble instead of a responding label")
    func transcriptLoadingStateUsesADotBubbleInsteadOfARespondingLabel() throws {
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")
        let mainChat = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(sharedStatus.contains("struct AssistantTypingIndicatorDots: View"))
        #expect(sharedStatus.contains("TimelineView(.animation(minimumInterval: 1.0 / 12.0))"))
        #expect(mainChat.contains("AssistantTypingIndicatorDots("))
        #expect(miniChat.contains("AssistantTypingIndicatorDots("))
        #expect(!mainChat.contains("Text(\"Responding\")"))
        #expect(!miniChat.contains("Text(\"Responding…\")"))
        #expect(!miniChat.contains("ProgressView().controlSize(.small)"))
    }

    @Test("graph chat lives in the sidebar and uses the note style ask bar")
    func graphChatLivesInSidebarAndUsesTheNoteStyleAskBar() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let noteWorkspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(sidebar.contains("case notes, query, chat"))
        #expect(sidebar.contains("AssistantToolbarAskBar("))
        #expect(sidebar.contains("sendGraphChatMessage()"))
        #expect(!sidebar.contains("ChatComposerTextEditor("))
        #expect(!inspector.contains("TextField(\"Ask…\""))
        #expect(overlay.contains("HologramSearchSidebar("))
        #expect(overlay.contains("inspectorState: inspectorState"))
        #expect(noteWorkspace.contains("AssistantToolbarAskBar("))
        #expect(sharedStatus.contains("struct AssistantToolbarAskBar<Leading: View>: View"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
