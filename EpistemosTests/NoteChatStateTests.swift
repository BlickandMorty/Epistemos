import Foundation
import Testing
@testable import Epistemos

@Suite("NoteChatState")
struct NoteChatStateTests {

    @Test("init sets pageId and defaults")
    @MainActor func initDefaults() {
        let state = NoteChatState(pageId: "page-1")
        #expect(state.pageId == "page-1")
        #expect(state.inputText.isEmpty)
        #expect(state.responseText.isEmpty)
        #expect(!state.isStreaming)
        #expect(!state.hasResponse)
        #expect(state.error == nil)
    }

    @Test("appendStreamingText accumulates tokens and flushes on stop")
    @MainActor func tokenAccumulation() {
        let state = NoteChatState(pageId: "page-2")
        state.isStreaming = true
        state.hasResponse = true

        var flushedDeltas: [String] = []
        state.onTokenFlush = { delta in flushedDeltas.append(delta) }

        state.appendStreamingText("Hello ")
        state.appendStreamingText("World")

        // stopStreaming forces synchronous flush — no timer dependency
        state.stopStreaming()

        #expect(state.responseText == "Hello World")
        #expect(!flushedDeltas.isEmpty)
    }

    @Test("appendStreamingText flushes immediately at 64KB threshold")
    @MainActor func largeTokenFlush() {
        let state = NoteChatState(pageId: "page-3")
        state.isStreaming = true
        state.hasResponse = true

        var flushCount = 0
        state.onTokenFlush = { _ in flushCount += 1 }

        // Send a chunk larger than 64KB
        let bigChunk = String(repeating: "x", count: 70_000)
        state.appendStreamingText(bigChunk)

        // Should have flushed synchronously (no timer wait needed)
        #expect(state.responseText == bigChunk)
        #expect(flushCount == 1)
    }

    @Test("acceptResponse resets state and calls onAccept")
    @MainActor func acceptLifecycle() {
        let state = NoteChatState(pageId: "page-4")
        state.responseText = "AI response"
        state.hasResponse = true

        var acceptCalled = false
        state.onAccept = { acceptCalled = true }

        state.acceptResponse()

        #expect(acceptCalled)
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("discardResponse resets state and calls onDiscard")
    @MainActor func discardLifecycle() {
        let state = NoteChatState(pageId: "page-5")
        state.responseText = "AI response"
        state.hasResponse = true

        var discardCalled = false
        state.onDiscard = { discardCalled = true }

        state.discardResponse()

        #expect(discardCalled)
        #expect(!state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("stopStreaming cancels task and flushes remaining tokens")
    @MainActor func stopStreamingFlush() async throws {
        let state = NoteChatState(pageId: "page-6")
        state.isStreaming = true
        state.hasResponse = true

        state.appendStreamingText("partial ")
        // Don't wait for timer — stop immediately
        state.stopStreaming()

        #expect(!state.isStreaming)
        #expect(state.responseText == "partial ")
    }

    @Test("clear resets everything")
    @MainActor func clearResetsAll() {
        let state = NoteChatState(pageId: "page-7")
        state.inputText = "query"
        state.responseText = "response"
        state.error = "something went wrong"
        state.hasResponse = true
        state.isStreaming = true

        state.clear()

        #expect(state.inputText.isEmpty)
        #expect(state.responseText.isEmpty)
        #expect(state.error == nil)
        #expect(!state.hasResponse)
        #expect(!state.isStreaming)
    }

    @Test("chatMode persists to UserDefaults")
    @MainActor func chatModePersistence() {
        let state = NoteChatState(pageId: "page-8")
        state.chatMode = .cloudOnly
        #expect(UserDefaults.standard.string(forKey: "noteChatMode") == "cloudOnly")

        state.chatMode = .auto
        #expect(UserDefaults.standard.string(forKey: "noteChatMode") == "auto")
    }

    @Test("overrideProvider persists to UserDefaults")
    @MainActor func providerPersistence() {
        let state = NoteChatState(pageId: "page-9")
        state.overrideProvider = .openai
        #expect(UserDefaults.standard.string(forKey: "noteChatProvider") == "openai")

        state.overrideProvider = nil
        // Setting nil stores nil (removes key)
    }
}
