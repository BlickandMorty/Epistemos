import Foundation

// Plan 1-MAS §11 R1: ONE façade protocol for the embedded llama.cpp lane and
// nothing more — load(modelURL, contextTokens) · stream(prompt, onToken) ·
// cancel() · unload() + window accounting.
//
// Contract notes:
// - The caller provides the FULL prompt string (chat-template application is
//   the caller's concern; Surface A owns per-model templating).
// - Every heavy call runs off the main actor inside the engine; callers hop
//   token events to the main actor themselves when driving UI.

public struct LocalChatWindowAccounting: Sendable, Equatable {
    public let contextTokens: Int
    public let promptTokens: Int
    public let generatedTokens: Int

    public var remainingTokens: Int {
        max(0, contextTokens - promptTokens - generatedTokens)
    }

    public init(contextTokens: Int, promptTokens: Int, generatedTokens: Int) {
        self.contextTokens = contextTokens
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
    }
}

public struct LocalChatRunStats: Sendable, Equatable {
    public enum FinishReason: String, Sendable {
        case endOfGeneration
        case maxTokens
        case contextFull
        case cancelled
    }

    public let promptTokens: Int
    public let generatedTokens: Int
    public let finishReason: FinishReason
    public let tokensPerSecond: Double

    public init(
        promptTokens: Int,
        generatedTokens: Int,
        finishReason: FinishReason,
        tokensPerSecond: Double
    ) {
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.finishReason = finishReason
        self.tokensPerSecond = tokensPerSecond
    }
}

public enum LocalChatStreamEvent: Sendable, Equatable {
    case token(String)
    case finished(LocalChatRunStats)
}

public enum LocalChatEngineError: Error, Sendable, Equatable {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case contextCreationFailed
    case notLoaded
    case busy
    case tokenizationFailed
    case promptTooLong(promptTokens: Int, contextTokens: Int)
    case decodeFailed(code: Int32)
    case streamBackpressure
}

public protocol LocalChatEngine: AnyObject, Sendable {
    var isLoaded: Bool { get }
    var windowAccounting: LocalChatWindowAccounting? { get }

    func load(modelURL: URL, contextTokens: Int) async throws
    func stream(prompt: String, maxNewTokens: Int) -> AsyncThrowingStream<LocalChatStreamEvent, Error>
    func cancel()
    func unload() async
}
