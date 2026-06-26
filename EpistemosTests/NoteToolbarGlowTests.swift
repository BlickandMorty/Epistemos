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
        #expect(!idle.animatesRetroEllipsis)
        #expect(analyzing.text == "Thinking…")
        #expect(analyzing.animatesRetroEllipsis)
        #expect(typing.text == "Responding…")
        #expect(typing.animatesRetroEllipsis)
    }

    @Test("toolbar ask bar supports a custom loading label for analyzing state")
    func toolbarAskBarSupportsCustomLoadingLabel() throws {
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")
        let noteWorkspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(sharedStatus.contains("let analyzingText: String"))
        #expect(sharedStatus.contains("analyzingText: String = \"Thinking…\""))
        #expect(sharedStatus.contains("analyzingText: analyzingText"))
        #expect(noteWorkspace.contains("analyzingText: \"Loading \\(inference.activeChatModelDisplayName)…\""))
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

    @Test("active note toolbar label uses the retro ellipsis path instead of the old shimmer sweep")
    func activeNoteToolbarLabelUsesTheRetroEllipsisPathInsteadOfTheOldShimmerSweep() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(source.contains("let animatesRetroEllipsis: Bool"))
        #expect(source.contains("private func animatedStatusText(at date: Date) -> String"))
        #expect(source.contains("TimelineView(.animation(minimumInterval: 1.0 / 4.0))"))
        #expect(source.contains("activeLabel(animatedStatusText(at:"))
        #expect(!source.contains("private var alignedLabelMask: some View"))
        #expect(!source.contains("LinearGradient(colors: palette"))
        #expect(!source.contains("private func shimmerBand("))
    }

    @Test("active composer treatment still eases in instead of snapping on")
    func activeComposerTreatmentStillEasesInInsteadOfSnappingOn() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(source.contains("private enum AssistantComposerWarmup"))
        #expect(source.contains("@State private var activationProgress: CGFloat = 0"))
        #expect(source.contains("withAnimation(AssistantComposerWarmup.animation(for: phase))"))
        #expect(source.contains(".blur(radius: (1 - activationProgress) * 1.4)"))
        #expect(source.contains(".opacity(Double(activationProgress))"))
    }

    @Test("status label now animates retro ellipsis instead of shimmer sweep math")
    func statusLabelNowAnimatesRetroEllipsisInsteadOfShimmerSweepMath() throws {
        let sharedStatus = try loadRepoTextFile("Epistemos/Theme/AssistantComposerStatusViews.swift")

        #expect(sharedStatus.contains("private func animatedOpacity(at date: Date) -> Double"))
        #expect(sharedStatus.contains("date.timeIntervalSinceReferenceDate * 2.15"))
        #expect(!sharedStatus.contains("private var sweepWidth: CGFloat"))
        #expect(!sharedStatus.contains("private func shimmerOffset("))
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

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
