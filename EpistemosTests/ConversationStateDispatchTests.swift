import Testing
import Foundation
@testable import Epistemos

/// Source-guard tests for AR2/W10.16 ConversationState dispatch read-site repair.
///
/// Verifies:
///   1. Stable `conversationStateId` derivation is separate from per-run `sessionId`.
///   2. `effectiveConversationHistory` compacts to a recent-turn tail when prior state exists.
///   3. The compacted history preserves the most recent messages and excludes old ones.
@Suite("ConversationStateDispatch (AR2/W10.16)")
struct ConversationStateDispatchTests {

  // MARK: - Stable ID Derivation

  @Test
  func deriveConversationStateId_prefersChatId() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: "chat-123",
      parentSessionID: "parent-456",
      sessionId: "session-789"
    )
    #expect(id == "chat-123")
  }

  @Test
  func deriveConversationStateId_fallsBackToParentSessionID() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: nil,
      parentSessionID: "parent-456",
      sessionId: "session-789"
    )
    #expect(id == "parent-456")
  }

  @Test
  func deriveConversationStateId_fallsBackToSessionId() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: nil,
      parentSessionID: nil,
      sessionId: "session-789"
    )
    #expect(id == "session-789")
  }

  @Test
  func deriveConversationStateId_ignoresEmptyChatId() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: "",
      parentSessionID: "parent-456",
      sessionId: "session-789"
    )
    #expect(id == "parent-456")
  }

  @Test
  func deriveConversationStateId_trimsWhitespaceOnlyIds() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: "   \n",
      parentSessionID: "  parent-456  ",
      sessionId: "session-789"
    )
    #expect(id == "parent-456")
  }

  @Test
  func deriveConversationStateId_ignoresEmptyParentSessionID() {
    let id = ChatCoordinator.deriveConversationStateId(
      chatId: nil,
      parentSessionID: "",
      sessionId: "session-789"
    )
    #expect(id == "session-789")
  }

  // MARK: - History Compaction

  @MainActor
  @Test
  func effectiveConversationHistory_returnsFullHistoryWhenNoPriorState() {
    let chatState = ChatState()
    chatState.messages = [
      ChatMessage(id: "1", chatId: "c", role: .user, content: "Hello"),
      ChatMessage(id: "2", chatId: "c", role: .assistant, content: "Hi there"),
      ChatMessage(id: "3", chatId: "c", role: .user, content: "What's up?")
    ]

    let fullHistory = chatState.serializedConversationHistory(maxCharacters: 10_000, maxMessages: 20)
    let effective = ChatCoordinator.effectiveConversationHistory(
      fullHistory: fullHistory,
      chatState: chatState,
      hasPriorState: false
    )

    #expect(effective == fullHistory)
  }

  @MainActor
  @Test
  func effectiveConversationHistory_compactsWhenPriorStateExists() throws {
    let chatState = ChatState()
    // Seed 10 prior message pairs so the full history is definitely larger than the compact tail.
    for i in 0..<10 {
      chatState.messages.append(ChatMessage(
        id: "u\(i)", chatId: "c", role: .user, content: "User turn \(i)"
      ))
      chatState.messages.append(ChatMessage(
        id: "a\(i)", chatId: "c", role: .assistant,
        content: "Assistant response \(i) with some padding to ensure the block is non-trivial"
      ))
    }
    // Append the current user message (dropped by serializedConversationHistory)
    chatState.messages.append(ChatMessage(
      id: "current", chatId: "c", role: .user, content: "Current query"
    ))

    let fullHistory = try #require(
      chatState.serializedConversationHistory(maxCharacters: 50_000, maxMessages: 20)
    )
    let effective = try #require(ChatCoordinator.effectiveConversationHistory(
      fullHistory: fullHistory,
      chatState: chatState,
      hasPriorState: true
    ))

    // The compacted version must be shorter (or at most equal) because we bound maxMessages to 4.
    #expect(effective != fullHistory)
    #expect(effective.count < fullHistory.count)
  }

  @MainActor
  @Test
  func effectiveConversationHistory_preservesMostRecentMessagesWhenCompacting() {
    let chatState = ChatState()
    for i in 0..<8 {
      chatState.messages.append(ChatMessage(
        id: "u\(i)", chatId: "c", role: .user, content: "User turn \(i)"
      ))
      chatState.messages.append(ChatMessage(
        id: "a\(i)", chatId: "c", role: .assistant, content: "Assistant response \(i)"
      ))
    }
    chatState.messages.append(ChatMessage(
      id: "current", chatId: "c", role: .user, content: "Current query"
    ))

    let effective = ChatCoordinator.effectiveConversationHistory(
      fullHistory: "ignored",
      chatState: chatState,
      hasPriorState: true
    )

    // The compacted tail should include the most recent assistant message.
    #expect(effective?.contains("Assistant response 6") == true)
    // It should not include the oldest messages.
    #expect(effective?.contains("User turn 0") == false)
  }

  @Test
  func runRustAgentPathUsesStableConversationStateIdForLoadSave() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(source.contains("let conversationStateId = Self.deriveConversationStateId("))
    #expect(source.contains(".loadConversationStateJSON(conversationId: conversationStateId)"))
    #expect(source.contains("saveConversationState(\n                  conversationId: conversationStateId"))
    #expect(source.contains("updated, for: conversationStateId"))
  }

  @Test
  func runRustAgentPathBuildsObjectiveFromEffectiveHistory() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
    let objective = try #require(source.range(of: "let objective = PipelineService.buildPromptEnvelope("))
    let envelopeTail = String(source[objective.lowerBound...])
    let end = try #require(envelopeTail.range(of: "\n    )"))
    let envelopeBlock = String(envelopeTail[..<end.upperBound])

    #expect(envelopeBlock.contains("conversationHistory: effectiveConversationHistory"))
    #expect(!envelopeBlock.contains("conversationHistory: conversationHistory"))
  }
}
