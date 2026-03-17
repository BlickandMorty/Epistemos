import AppKit
import SwiftUI
import Testing
@testable import Epistemos

@Suite("Scroll Stability")
struct ScrollStabilityTests {
    private static let testDocumentExtent: CGFloat = 10_000

    @Test("auto-follow detaches when the user scrolls well away from bottom")
    func autoFollowDetachesAwayFromBottom() {
        var state = ScrollAutoFollowState()

        state.update(distanceToBottom: 140)

        #expect(!state.isFollowingBottom)
    }

    @Test("auto-follow stays attached inside the hysteresis band")
    func autoFollowStaysAttachedNearBottom() {
        var state = ScrollAutoFollowState()

        state.update(distanceToBottom: 48)

        #expect(state.isFollowingBottom)
    }

    @Test("auto-follow reattaches when the viewport returns near the bottom")
    func autoFollowReattachesNearBottom() {
        var state = ScrollAutoFollowState()
        state.update(distanceToBottom: 140)

        state.update(distanceToBottom: 12)

        #expect(state.isFollowingBottom)
    }

    @Test("programmatic bottom scroll restores follow mode")
    func programmaticScrollRestoresFollowMode() {
        var state = ScrollAutoFollowState()
        state.update(distanceToBottom: 140)

        state.markProgrammaticScrollToBottom()

        #expect(state.isFollowingBottom)
    }

    @Test("scroll distance to bottom is derived from native scroll geometry")
    func distanceToBottomUsesScrollGeometry() {
        let geometry = ScrollGeometry(
            contentOffset: CGPoint(x: 0, y: 72),
            contentSize: CGSize(width: 320, height: 400),
            contentInsets: EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0),
            containerSize: CGSize(width: 320, height: 240)
        )

        #expect(ScrollStability.distanceToBottom(for: geometry) == 100)
    }

    @Test("chat scroll follow policy uses the shared hysteresis thresholds")
    func chatScrollFollowPolicyUsesSharedThresholds() {
        let state = ChatScrollFollowPolicy.defaultAutoFollowState

        #expect(state == ScrollAutoFollowState(attachThreshold: 24, detachThreshold: 72))
        #expect(ChatScrollFollowPolicy.streamingThrottle == .milliseconds(250))
    }

    @Test("scroll follow mode helper preserves hysteresis")
    func scrollFollowModeHelperPreservesHysteresis() {
        let geometry = ScrollGeometry(
            contentOffset: CGPoint(x: 0, y: 124),
            contentSize: CGSize(width: 320, height: 400),
            contentInsets: EdgeInsets(),
            containerSize: CGSize(width: 320, height: 240)
        )
        var detached = ScrollAutoFollowState()
        detached.update(distanceToBottom: 140)

        #expect(ScrollStability.followMode(for: geometry, from: ScrollAutoFollowState()))
        #expect(!ScrollStability.followMode(for: geometry, from: detached))
    }

    @MainActor
    @Test("classic transclusion overlay refresh is coalesced during scroll")
    func classicTransclusionRefreshIsCoalesced() async throws {
        let textView = makeClassicTextView(text: "Intro\n\n((abc))\n")
        let manager = TransclusionOverlayManager(textView: textView)
        let key = NSAttributedString.Key("EpistemosBlockRef")
        textView.textStorage?.addAttribute(key, value: "abc", range: NSRange(location: 7, length: 7))
        manager.refreshAfterTextChange()

        var refreshCount = 0
        manager.onDidRefresh = { refreshCount += 1 }
        manager.refreshForScroll()
        manager.refreshForScroll()
        manager.refreshForScroll()
        try await waitUntilRefreshObserved { refreshCount == 1 }

        #expect(refreshCount == 1)
    }

    @MainActor
    @Test("classic rendered table overlay refresh is coalesced during scroll")
    func classicRenderedTableRefreshIsCoalesced() async throws {
        let textView = makeClassicTextView(
            text: """
            | Name | Value |
            | --- | --- |
            | A | B |
            """
        )
        let manager = RenderedTableOverlayManager(textView: textView, theme: .platinum)
        manager.refreshAfterTextChange()

        var refreshCount = 0
        manager.onDidRefresh = { refreshCount += 1 }
        manager.refreshForScroll()
        manager.refreshForScroll()
        manager.refreshForScroll()
        try await waitUntilRefreshObserved { refreshCount == 1 }

        #expect(refreshCount == 1)
    }

    @MainActor
    @Test("TK2 transclusion overlay refresh skips small scrolls inside the buffered viewport")
    func textKit2TransclusionRefreshSkipsSmallBufferedScroll() async throws {
        let (scrollView, textView) = makeTextKit2TextView(text: "Intro\n\n((abc))\n")
        let manager = TransclusionOverlayManager2(textView: textView)
        manager.refreshAfterTextChange()

        var refreshCount = 0
        manager.onDidRefresh = { refreshCount += 1 }

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 24))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        manager.refreshForScroll()
        try await Task.sleep(for: .milliseconds(80))

        #expect(refreshCount == 0)
    }

    @MainActor
    @Test("TK2 rendered table overlay refresh skips small scrolls inside the buffered viewport")
    func textKit2RenderedTableRefreshSkipsSmallBufferedScroll() async throws {
        let (scrollView, textView) = makeTextKit2TextView(
            text: """
            Intro

            | Name | Value |
            | --- | --- |
            | A | B |
            """
        )
        let manager = RenderedTableOverlayManager2(textView: textView, theme: .nativeDefault)
        manager.refresh()

        var refreshCount = 0
        manager.onDidRefresh = { refreshCount += 1 }

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 24))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        manager.refreshForScroll()
        try await Task.sleep(for: .milliseconds(80))

        #expect(refreshCount == 0)
    }

    @MainActor
    private func waitUntilRefreshObserved(
        timeout: Duration = .milliseconds(250),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while clock.now < deadline {
            if condition() {
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @MainActor
    private func makeClassicTextView(text: String) -> ClickableTextView {
        let storage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: NSSize(width: 320, height: Self.testDocumentExtent)
        )
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = ClickableTextView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 600),
            textContainer: container
        )
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: Self.testDocumentExtent,
            height: Self.testDocumentExtent
        )
        textView.minSize = NSSize.zero

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 220))
        scrollView.documentView = textView
        scrollView.contentView.scroll(to: NSPoint.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
        layoutManager.ensureLayout(for: container)
        return textView
    }

    @MainActor
    private func makeTextKit2TextView(text: String) -> (NSScrollView, ProseTextView2) {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()
        scrollView.frame = NSRect(x: 0, y: 0, width: 480, height: 220)
        textView.frame = NSRect(x: 0, y: 0, width: 480, height: 2400)

        let textStorage = textView.textStorage!
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
        textStorage.endEditing()
        textView.reparseAndInvalidate()

        if let contentStorage = textView.textLayoutManager?.textContentManager as? NSTextContentStorage {
            textView.textLayoutManager?.ensureLayout(for: contentStorage.documentRange)
        }

        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return (scrollView, textView)
    }
}
