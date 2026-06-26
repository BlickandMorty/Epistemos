import Foundation

public enum ChatDonorFragmentBufferMutation: Codable, Hashable, Sendable {
    case appended(index: Int, totalCharacters: Int)
    case assigned(index: Int, totalCharacters: Int)
    case rejected(reason: ChatDonorFragmentBufferRejection)
}

public enum ChatDonorFragmentBufferRejection: String, Codable, Hashable, Sendable {
    case negativeIndex = "negative-index"
    case indexExceedsFragmentBudget = "index-exceeds-fragment-budget"
    case characterBudgetExceeded = "character-budget-exceeded"
}

public struct ChatDonorContentFragmentBuffer: Codable, Hashable, Sendable {
    public private(set) var fragments: [String]
    public let maxFragmentCount: Int
    public let maxTotalCharacters: Int

    public init(
        maxFragmentCount: Int = 64,
        maxTotalCharacters: Int = ChatDonorMemoryPolicy.nativeChatDefault.maxVisibleTranscriptCharacters,
        fragments: [String] = []
    ) {
        precondition(maxFragmentCount > 0, "Fragment buffers need at least one slot.")
        precondition(maxTotalCharacters > 0, "Fragment buffers need a positive character budget.")
        self.maxFragmentCount = maxFragmentCount
        self.maxTotalCharacters = maxTotalCharacters
        self.fragments = Array(fragments.prefix(maxFragmentCount))
    }

    public var totalCharacters: Int {
        fragments.reduce(0) { partial, fragment in
            partial + fragment.count
        }
    }

    public var nonEmptyFragments: [String] {
        fragments.filter { !$0.isEmpty }
    }

    public func joined(separator: String = "") -> String {
        fragments.joined(separator: separator)
    }

    @discardableResult
    public mutating func append(_ text: String, at index: Int) -> ChatDonorFragmentBufferMutation {
        mutate(text, at: index) { existing, incoming in
            existing + incoming
        }.mapSuccess { .appended(index: index, totalCharacters: totalCharacters) }
    }

    @discardableResult
    public mutating func assign(_ text: String, at index: Int) -> ChatDonorFragmentBufferMutation {
        mutate(text, at: index) { _, incoming in
            incoming
        }.mapSuccess { .assigned(index: index, totalCharacters: totalCharacters) }
    }

    private mutating func mutate(
        _ text: String,
        at index: Int,
        transform: (String, String) -> String
    ) -> ChatDonorFragmentBufferMutation {
        guard index >= 0 else {
            return .rejected(reason: .negativeIndex)
        }
        guard index < maxFragmentCount else {
            return .rejected(reason: .indexExceedsFragmentBudget)
        }

        ensureCapacity(for: index)
        let current = fragments[index]
        let next = transform(current, text)
        let projectedTotal = totalCharacters - current.count + next.count
        guard projectedTotal <= maxTotalCharacters else {
            return .rejected(reason: .characterBudgetExceeded)
        }

        fragments[index] = next
        return .assigned(index: index, totalCharacters: projectedTotal)
    }

    private mutating func ensureCapacity(for index: Int) {
        if fragments.count <= index {
            fragments.append(contentsOf: Array(repeating: "", count: index - fragments.count + 1))
        }
    }
}

private extension ChatDonorFragmentBufferMutation {
    func mapSuccess(_ transform: () -> ChatDonorFragmentBufferMutation) -> ChatDonorFragmentBufferMutation {
        switch self {
        case .rejected:
            self
        case .appended, .assigned:
            transform()
        }
    }
}

public struct ChatDonorTokenUsage: Codable, Hashable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var cachedTokens: Int?
    public var reasoningTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        cachedTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
    }

    public static let zero = ChatDonorTokenUsage()

    public var resolvedTotalTokens: Int? {
        if let totalTokens {
            totalTokens
        } else {
            Self.safeSum(inputTokens, outputTokens)
        }
    }

    public mutating func merge(_ other: ChatDonorTokenUsage) {
        inputTokens = Self.safeSum(inputTokens, other.inputTokens)
        outputTokens = Self.safeSum(outputTokens, other.outputTokens)
        totalTokens = Self.safeSum(totalTokens, other.totalTokens)
        cachedTokens = Self.safeSum(cachedTokens, other.cachedTokens)
        reasoningTokens = Self.safeSum(reasoningTokens, other.reasoningTokens)
    }

    public func merged(with other: ChatDonorTokenUsage) -> ChatDonorTokenUsage {
        var copy = self
        copy.merge(other)
        return copy
    }

    private static func safeSum(_ first: Int?, _ second: Int?) -> Int? {
        switch (first, second) {
        case let (left?, right?):
            let result = left.addingReportingOverflow(right)
            return result.overflow ? Int.max : result.partialValue
        case (nil, let right?):
            return right
        case (let left?, nil):
            return left
        case (nil, nil):
            return nil
        }
    }
}

public enum ChatDonorTranscriptRole: String, Codable, Hashable, Sendable {
    case prompt
    case reasoning
    case toolCall = "tool-call"
    case toolOutput = "tool-output"
    case response
}

public enum ChatDonorTranscriptStatus: String, Codable, Hashable, Sendable {
    case pending
    case streaming
    case completed
    case failed
    case cancelled
}

public struct ChatDonorTranscriptEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var role: ChatDonorTranscriptRole
    public var status: ChatDonorTranscriptStatus
    public var text: String
    public var tokenUsage: ChatDonorTokenUsage?

    public init(
        id: String = UUID().uuidString,
        role: ChatDonorTranscriptRole,
        status: ChatDonorTranscriptStatus,
        text: String,
        tokenUsage: ChatDonorTokenUsage? = nil
    ) {
        self.id = id
        self.role = role
        self.status = status
        self.text = text
        self.tokenUsage = tokenUsage
    }
}

public struct ChatDonorTranscript: Codable, Hashable, Sendable {
    public private(set) var entries: [ChatDonorTranscriptEntry]

    public init(entries: [ChatDonorTranscriptEntry] = []) {
        self.entries = entries
    }

    public mutating func upsert(_ entry: ChatDonorTranscriptEntry) {
        if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[existingIndex] = entry
        } else {
            entries.append(entry)
        }
    }

    public subscript(id id: String) -> ChatDonorTranscriptEntry? {
        entries.first { $0.id == id }
    }
}
