import Foundation
import SwiftData
import Testing
@testable import Epistemos

// MARK: - Per-provider reasoning summary persistence
//
// Patch 10 / USER_WIRING_GAPS G15.
//
// Verifies that the per-provider reasoning surface is wired end-to-end:
// 1. Anthropic   `content_block_delta { thinking_delta }`
// 2. OpenAI      `response.reasoning_summary_text.{delta,done,part.done}`
// 3. Google      `parts[*].thought == true`
//
// All three must route through CloudStreamingParser → AgentChatState
// .appendStreamingThinking → SDMessage.thinkingTrace, persist to
// SwiftData, and survive a reload via SDMessage.chatMessage(chatId:).
//
// These tests are deterministic: they feed synthesized JSON event
// dictionaries (matching the wire schema documented in
// agent_core/src/providers/{claude,openai,gemini}.rs) into the parser
// and the live AgentChatState, then round-trip through an in-memory
// SwiftData store. No live network calls. No runtime code is mutated.

@Suite("Per-Provider Reasoning Summary Persistence")
@MainActor
struct PerProviderReasoningPersistenceTests {

    // MARK: - SwiftData container helper

    private func makePersistenceContainer() throws -> ModelContainer {
        let schema = Schema([SDChat.self, SDMessage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - 1. Anthropic — thinking_delta + signature_delta + tool_use + text_delta

    @Test(
        "Anthropic thinking_delta + signature_delta route into the thinking trace, then text_delta finalizes the visible answer"
    )
    func anthropicThinkingDeltaRoutesThroughPipeline() {
        // Wire schema mirrored from agent_core/src/providers/claude.rs
        // event mapping: ThinkingDelta is yielded for `thinking_delta`
        // content-block deltas; signature_delta is preserved on the
        // tool-use turn so the signed thinking block can be rehydrated.
        let thinkingChunkA: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "thinking_delta",
                "thinking": "Inspect the vault graph"
            ]
        ]
        let thinkingChunkB: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "thinking_delta",
                "thinking": " for kant references."
            ]
        ]
        // Anthropic signs the thinking block at the end with a
        // signature_delta. The parser intentionally does NOT surface
        // signatures as thinking text — they are opaque tokens. This
        // assertion guards that contract: the signature delta must
        // produce nil from anthropicThinkingDelta so it doesn't leak
        // bytes into the visible thinking lane.
        let signatureChunk: [String: Any] = [
            "type": "content_block_delta",
            "index": 0,
            "delta": [
                "type": "signature_delta",
                "signature": "EnYxYWZkZmcyMDM5OWY4M2Y3..."
            ]
        ]
        let textChunk: [String: Any] = [
            "type": "content_block_delta",
            "index": 1,
            "delta": [
                "type": "text_delta",
                "text": "Found one note."
            ]
        ]

        // Parser-level contracts
        #expect(
            CloudStreamingParser.anthropicThinkingDelta(from: thinkingChunkA)
                == "Inspect the vault graph"
        )
        #expect(
            CloudStreamingParser.anthropicThinkingDelta(from: thinkingChunkB)
                == " for kant references."
        )
        #expect(CloudStreamingParser.anthropicThinkingDelta(from: signatureChunk) == nil)
        #expect(CloudStreamingParser.anthropicThinkingDelta(from: textChunk) == nil)
        #expect(CloudStreamingParser.anthropicTextDelta(from: thinkingChunkA) == nil)
        #expect(CloudStreamingParser.anthropicTextDelta(from: textChunk) == "Found one note.")

        // Drive the live state with parsed deltas as the runtime would.
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()

        for chunk in [thinkingChunkA, thinkingChunkB, signatureChunk] {
            if let thinking = CloudStreamingParser.anthropicThinkingDelta(from: chunk) {
                state.appendStreamingThinking(thinking, explicit: true)
            }
        }
        if let visible = CloudStreamingParser.anthropicTextDelta(from: textChunk) {
            state.appendStreamingText(visible)
        }

        #expect(state.streamingThinking == "Inspect the vault graph for kant references.")
        #expect(state.thinkingStartedAt != nil)
        #expect(!state.streamingThinking.contains("EnYxYWZk"))

        state.completeProcessing(mode: .api, resolvedModelLabel: "Claude Opus 4.7")

        let last = state.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.thinkingTrace == "Inspect the vault graph for kant references.")
        #expect(last?.thinkingDurationSeconds != nil)
        #expect(last?.content.contains("Found one note.") == true)
    }

    // MARK: - 2. OpenAI — response.reasoning_summary_text.delta routes via thinking pipeline (NOT text)

    @Test(
        "OpenAI reasoning_summary_text.delta routes through the thinking pipeline, never the visible text channel"
    )
    func openAIReasoningSummaryRoutesThroughThinkingPipeline() {
        // Wire schema mirrored from agent_core/src/providers/openai.rs:
        // `response.reasoning_summary_text.delta` and the documented
        // completion variants `.done` / `summary_part.done` are the only
        // events that should ever surface as visible reasoning.
        // `response.reasoning_text.delta` (raw private chain-of-thought)
        // must NOT leak into the popover.
        let summaryDelta: [String: Any] = [
            "type": "response.reasoning_summary_text.delta",
            "delta": "Plan the search query"
        ]
        let summaryDelta2: [String: Any] = [
            "type": "response.reasoning_summary_text.delta",
            "delta": " across notes."
        ]
        let summaryDone: [String: Any] = [
            "type": "response.reasoning_summary_text.done",
            "text": "Plan the search query across notes."
        ]
        let rawReasoning: [String: Any] = [
            "type": "response.reasoning_text.delta",
            "delta": "Private chain of thought that must stay hidden"
        ]
        let outputText: [String: Any] = [
            "type": "response.output_text.delta",
            "delta": "Here is the result."
        ]

        // Parser contracts
        #expect(
            CloudStreamingParser.openAIResponsesReasoningDelta(from: summaryDelta)
                == "Plan the search query"
        )
        #expect(
            CloudStreamingParser.openAIResponsesReasoningDelta(from: summaryDelta2)
                == " across notes."
        )
        #expect(
            CloudStreamingParser.openAIResponsesReasoningDelta(from: summaryDone)
                == "Plan the search query across notes."
        )
        // Critical contract: raw reasoning must NEVER surface.
        #expect(CloudStreamingParser.openAIResponsesReasoningDelta(from: rawReasoning) == nil)
        // And the visible text parser must never echo reasoning summaries.
        #expect(CloudStreamingParser.openAITextDelta(from: summaryDelta) == nil)
        #expect(CloudStreamingParser.openAITextDelta(from: outputText) == "Here is the result.")

        // Drive live state.
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()

        for chunk in [summaryDelta, summaryDelta2] {
            if let thinking = CloudStreamingParser.openAIResponsesReasoningDelta(from: chunk) {
                state.appendStreamingThinking(thinking, explicit: true)
            }
        }
        // Raw reasoning should be a no-op when fed through the same path.
        if let leakage = CloudStreamingParser.openAIResponsesReasoningDelta(from: rawReasoning) {
            state.appendStreamingThinking(leakage, explicit: true)
        }
        if let visible = CloudStreamingParser.openAITextDelta(from: outputText) {
            state.appendStreamingText(visible)
        }

        #expect(state.streamingThinking == "Plan the search query across notes.")
        #expect(!state.streamingThinking.contains("Private chain of thought"))

        state.completeProcessing(mode: .api, resolvedModelLabel: "GPT-5.4")

        let last = state.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.thinkingTrace == "Plan the search query across notes.")
        #expect(last?.thinkingDurationSeconds != nil)
        #expect(last?.content.contains("Here is the result.") == true)
    }

    // MARK: - 3. Google — parts[*].thought == true routes via thinking pipeline

    @Test(
        "Google parts[*].thought == true routes through the thinking pipeline; non-thought parts stay visible"
    )
    func googleThoughtPartRoutesThroughThinkingPipeline() {
        // Wire schema mirrored from agent_core/src/providers/gemini.rs:
        // a candidate emits multiple `parts`, each with optional
        // `thought: true`. Thought parts must be pulled into the
        // thinking lane via googleReasoningDelta; the visible-text
        // parser explicitly filters them out.
        let thoughtChunkA: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": "Outline the answer.", "thought": true]
                        ]
                    ]
                ]
            ]
        ]
        let thoughtChunkB: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": " Confirm vault search.", "thought": true]
                        ]
                    ]
                ]
            ]
        ]
        let mixedChunk: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": "Internal step.", "thought": true],
                            ["text": "Visible answer."]
                        ]
                    ]
                ]
            ]
        ]

        // Parser contracts
        #expect(
            CloudStreamingParser.googleReasoningDelta(from: thoughtChunkA)
                == "Outline the answer."
        )
        #expect(
            CloudStreamingParser.googleReasoningDelta(from: thoughtChunkB)
                == " Confirm vault search."
        )
        // Thought-only chunk must NOT show in the visible text path.
        #expect(CloudStreamingParser.googleTextDelta(from: thoughtChunkA) == nil)
        // A mixed chunk yields each channel separately.
        #expect(CloudStreamingParser.googleReasoningDelta(from: mixedChunk) == "Internal step.")
        #expect(CloudStreamingParser.googleTextDelta(from: mixedChunk) == "Visible answer.")

        // Drive live state.
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()

        for chunk in [thoughtChunkA, thoughtChunkB] {
            if let thinking = CloudStreamingParser.googleReasoningDelta(from: chunk) {
                state.appendStreamingThinking(thinking, explicit: true)
            }
        }
        if let visible = CloudStreamingParser.googleTextDelta(from: mixedChunk) {
            state.appendStreamingText(visible)
        }
        if let mixedThinking = CloudStreamingParser.googleReasoningDelta(from: mixedChunk) {
            // Late thinking after visible answer must still be retained
            // (ChatState routes it to the post-answer lane).
            state.appendStreamingThinking(mixedThinking)
        }

        #expect(state.streamingThinking.contains("Outline the answer."))
        #expect(state.streamingThinking.contains(" Confirm vault search."))
        #expect(state.streamingThinking.contains("Internal step."))
        // The visible-channel content must never have absorbed the thought parts.
        #expect(!state.streamingText.contains("Outline the answer."))

        state.completeProcessing(mode: .api, resolvedModelLabel: "Gemini 3.1 Pro")

        let last = state.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.thinkingTrace?.contains("Outline the answer.") == true)
        #expect(last?.thinkingTrace?.contains(" Confirm vault search.") == true)
        #expect(last?.thinkingDurationSeconds != nil)
        #expect(last?.content.contains("Visible answer.") == true)
    }

    // MARK: - 4. Round-trip: SDMessage thinkingTrace persists through SwiftData reload

    @Test(
        "SDMessage thinkingTrace + thinkingDurationSeconds round-trip through an in-memory SwiftData container"
    )
    func sdMessageThinkingTraceRoundTripsThroughSwiftData() throws {
        let container = try makePersistenceContainer()
        let context = ModelContext(container)

        // Build a chat with an assistant message that has an explicit
        // thinking trace + duration, simulating a finalized cloud turn.
        let chat = SDChat(title: "G15 reasoning persistence")
        context.insert(chat)

        let assistant = SDMessage(
            role: MessageRole.assistant.rawValue,
            content: "Found the kant note."
        )
        assistant.thinkingTrace =
            "Searched vault for kant; matched note kant_lecture.md."
        assistant.thinkingDurationSeconds = 3.25
        assistant.authoredByProviderID = "anthropic"
        assistant.authoredByModelID = "claude-opus-4-7"
        assistant.chat = chat

        context.insert(assistant)
        try context.save()

        // Reload via a brand-new ModelContext on the same container —
        // mirrors the cold-start path the user hits after relaunching.
        let reloadedContext = ModelContext(container)
        let chats = try reloadedContext.fetch(FetchDescriptor<SDChat>())
        #expect(chats.count == 1)
        let reloadedChat = try #require(chats.first)
        let reloadedMessages = (reloadedChat.messages ?? []).sorted { $0.createdAt < $1.createdAt }
        #expect(reloadedMessages.count == 1)

        let reloadedAssistant = try #require(reloadedMessages.first)
        #expect(reloadedAssistant.thinkingTrace ==
                "Searched vault for kant; matched note kant_lecture.md.")
        #expect(reloadedAssistant.thinkingDurationSeconds == 3.25)
        #expect(reloadedAssistant.authoredByProviderID == "anthropic")
        #expect(reloadedAssistant.authoredByModelID == "claude-opus-4-7")

        // The presentation conversion must propagate the trace into the
        // ChatMessage so the popover renders after reload.
        let projection = reloadedAssistant.chatMessage(chatId: reloadedChat.id)
        #expect(projection.thinkingTrace ==
                "Searched vault for kant; matched note kant_lecture.md.")
        #expect(projection.thinkingDurationSeconds == 3.25)
    }

    // MARK: - 5. Streaming buffer policy source-guard

    @Test(
        "StreamingDelegate-side AgentStreamEvent producers use .bufferingNewest(256), never .unbounded"
    )
    func streamingDelegateUsesBoundedBufferingPolicy() throws {
        let bridgeSource = try loadMirroredSourceTextFile("Epistemos/Bridge/StreamingDelegate.swift")
        let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

        // The delegate itself just owns a Continuation — the actual
        // AsyncStream<AgentStreamEvent> is constructed at the call sites
        // in ChatCoordinator (the only producers of that stream type).
        // Both producer sites and the delegate file together must:
        // (a) explicitly opt into .bufferingNewest(256), and
        // (b) never use .unbounded for AgentStreamEvent.
        let producerPattern = "AsyncStream<AgentStreamEvent>(bufferingPolicy: .bufferingNewest(256))"
        #expect(coordinatorSource.contains(producerPattern))

        // Defensive guard: nobody should regress to .unbounded for this
        // event stream — that's the buffer-policy non-negotiable.
        #expect(!coordinatorSource.contains("AsyncStream<AgentStreamEvent>(bufferingPolicy: .unbounded)"))
        #expect(!bridgeSource.contains("AsyncStream<AgentStreamEvent>(bufferingPolicy: .unbounded)"))
        #expect(!bridgeSource.contains(".unbounded)"))
    }
}
