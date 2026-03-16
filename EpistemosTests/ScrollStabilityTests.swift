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
}
