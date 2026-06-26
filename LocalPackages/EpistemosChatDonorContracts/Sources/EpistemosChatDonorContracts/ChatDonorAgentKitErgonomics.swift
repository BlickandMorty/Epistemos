import Foundation

public enum ChatDonorAgentKitRetryTermination: String, Codable, Hashable, Sendable {
    case success
    case attemptsExhausted = "attempts-exhausted"
    case nonRetryableFailure = "non-retryable-failure"
    case cancelled
}

public struct ChatDonorAgentKitRetryPolicy: Codable, Hashable, Sendable {
    public var maxAttempts: Int
    public var baseDelayNanoseconds: UInt64
    public var maxDelayNanoseconds: UInt64
    public var jitterPermille: UInt16

    public init(
        maxAttempts: Int = 3,
        baseDelayNanoseconds: UInt64 = 100_000_000,
        maxDelayNanoseconds: UInt64 = 2_000_000_000,
        jitterPermille: UInt16 = 0
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.maxDelayNanoseconds = max(baseDelayNanoseconds, maxDelayNanoseconds)
        self.jitterPermille = min(jitterPermille, 1_000)
    }

    public func shouldStartAttempt(_ attempt: Int) -> Bool {
        attempt >= 1 && attempt <= maxAttempts
    }

    public func shouldRetry(afterAttempt attempt: Int, errorIsRetryable: Bool = true) -> Bool {
        errorIsRetryable && attempt >= 1 && attempt < maxAttempts
    }

    public func delayNanoseconds(afterAttempt attempt: Int, jitterSeed: UInt64? = nil) -> UInt64 {
        let exponentialDelay = cappedExponentialDelay(afterAttempt: attempt)
        guard jitterPermille > 0, let jitterSeed else {
            return exponentialDelay
        }

        let draw = jitterSeed % (UInt64(jitterPermille) + 1)
        let jitter = Self.scaledPermille(exponentialDelay, by: draw)
        let sum = exponentialDelay.addingReportingOverflow(jitter)
        guard !sum.overflow else { return maxDelayNanoseconds }
        return min(sum.partialValue, maxDelayNanoseconds)
    }

    private func cappedExponentialDelay(afterAttempt attempt: Int) -> UInt64 {
        guard attempt > 0 else { return 0 }
        guard baseDelayNanoseconds > 0 else { return 0 }

        var delay = baseDelayNanoseconds
        if attempt > 1 {
            for _ in 1..<attempt {
                if delay >= maxDelayNanoseconds {
                    return maxDelayNanoseconds
                }
                let doubled = delay.multipliedReportingOverflow(by: 2)
                delay = doubled.overflow ? maxDelayNanoseconds : min(doubled.partialValue, maxDelayNanoseconds)
            }
        }
        return min(delay, maxDelayNanoseconds)
    }

    private static func scaledPermille(_ value: UInt64, by permille: UInt64) -> UInt64 {
        guard value > 0, permille > 0 else { return 0 }
        return (value / 1_000) * permille + ((value % 1_000) * permille) / 1_000
    }
}

public struct ChatDonorAgentKitRetryReceipt: Codable, Hashable, Sendable {
    public var attemptsStarted: Int
    public var retryDelaysNanoseconds: [UInt64]
    public var termination: ChatDonorAgentKitRetryTermination
    public var lastErrorDescription: String?
    public var cancellationObserved: Bool

    public init(
        attemptsStarted: Int,
        retryDelaysNanoseconds: [UInt64],
        termination: ChatDonorAgentKitRetryTermination,
        lastErrorDescription: String? = nil,
        cancellationObserved: Bool = false
    ) {
        self.attemptsStarted = attemptsStarted
        self.retryDelaysNanoseconds = retryDelaysNanoseconds
        self.termination = termination
        self.lastErrorDescription = lastErrorDescription
        self.cancellationObserved = cancellationObserved
    }
}

public enum ChatDonorAgentKitRetryRunOutput<Success: Sendable>: Sendable {
    case success(Success, ChatDonorAgentKitRetryReceipt)
    case failure(ChatDonorAgentKitRetryReceipt)

    public var receipt: ChatDonorAgentKitRetryReceipt {
        switch self {
        case .success(_, let receipt), .failure(let receipt):
            receipt
        }
    }
}

public struct ChatDonorAgentKitRetrier: Sendable {
    public var policy: ChatDonorAgentKitRetryPolicy

    public init(policy: ChatDonorAgentKitRetryPolicy = ChatDonorAgentKitRetryPolicy()) {
        self.policy = policy
    }

    public func run<Success: Sendable>(
        operation: @Sendable (Int) async throws -> Success,
        shouldRetryError: @Sendable (Error) -> Bool = { _ in true },
        sleep: @Sendable (UInt64) async throws -> Void = { nanoseconds in
            guard nanoseconds > 0 else { return }
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) async -> ChatDonorAgentKitRetryRunOutput<Success> {
        var attempt = 1
        var attemptsStarted = 0
        var retryDelays: [UInt64] = []
        var lastErrorDescription: String?

        while policy.shouldStartAttempt(attempt) {
            if Task.isCancelled {
                return .failure(Self.receipt(
                    attemptsStarted: attemptsStarted,
                    retryDelays: retryDelays,
                    termination: .cancelled,
                    lastErrorDescription: lastErrorDescription,
                    cancellationObserved: true
                ))
            }

            attemptsStarted += 1
            do {
                let value = try await operation(attempt)
                return .success(value, Self.receipt(
                    attemptsStarted: attemptsStarted,
                    retryDelays: retryDelays,
                    termination: .success,
                    lastErrorDescription: nil
                ))
            } catch is CancellationError {
                return .failure(Self.receipt(
                    attemptsStarted: attemptsStarted,
                    retryDelays: retryDelays,
                    termination: .cancelled,
                    lastErrorDescription: lastErrorDescription,
                    cancellationObserved: true
                ))
            } catch {
                lastErrorDescription = String(describing: error)
                let retryable = shouldRetryError(error)
                guard policy.shouldRetry(afterAttempt: attempt, errorIsRetryable: retryable) else {
                    return .failure(Self.receipt(
                        attemptsStarted: attemptsStarted,
                        retryDelays: retryDelays,
                        termination: retryable ? .attemptsExhausted : .nonRetryableFailure,
                        lastErrorDescription: lastErrorDescription
                    ))
                }

                let delay = policy.delayNanoseconds(afterAttempt: attempt)
                retryDelays.append(delay)
                do {
                    try await sleep(delay)
                } catch {
                    return .failure(Self.receipt(
                        attemptsStarted: attemptsStarted,
                        retryDelays: retryDelays,
                        termination: .cancelled,
                        lastErrorDescription: String(describing: error),
                        cancellationObserved: true
                    ))
                }
                attempt += 1
            }
        }

        return .failure(Self.receipt(
            attemptsStarted: attemptsStarted,
            retryDelays: retryDelays,
            termination: .attemptsExhausted,
            lastErrorDescription: lastErrorDescription
        ))
    }

    private static func receipt(
        attemptsStarted: Int,
        retryDelays: [UInt64],
        termination: ChatDonorAgentKitRetryTermination,
        lastErrorDescription: String?,
        cancellationObserved: Bool = false
    ) -> ChatDonorAgentKitRetryReceipt {
        ChatDonorAgentKitRetryReceipt(
            attemptsStarted: attemptsStarted,
            retryDelaysNanoseconds: retryDelays,
            termination: termination,
            lastErrorDescription: lastErrorDescription,
            cancellationObserved: cancellationObserved
        )
    }
}

public struct ChatDonorAgentKitConversationWindow: Codable, Hashable, Sendable {
    public var maxEntries: Int
    public var reductionStride: Int
    public var maxToolOutputCharacters: Int
    public var truncationMarker: String
    public private(set) var removedEntryCount: Int

    public init(
        maxEntries: Int = 20,
        reductionStride: Int? = nil,
        maxToolOutputCharacters: Int = 2_000,
        truncationMarker: String = "\n\n[Tool output truncated by AgentKit window policy.]",
        removedEntryCount: Int = 0
    ) {
        let boundedMaxEntries = max(0, maxEntries)
        self.maxEntries = boundedMaxEntries
        self.reductionStride = max(1, reductionStride ?? max(1, boundedMaxEntries / 4))
        self.maxToolOutputCharacters = max(1, maxToolOutputCharacters)
        self.truncationMarker = truncationMarker
        self.removedEntryCount = max(0, removedEntryCount)
    }

    public mutating func apply(to transcript: ChatDonorTranscript) -> ChatDonorTranscript {
        var entries = removeDanglingEntries(from: transcript.entries)

        guard maxEntries > 0 else {
            removedEntryCount += entries.count
            return ChatDonorTranscript()
        }

        if entries.count > maxEntries {
            let removalCount = entries.count - maxEntries
            entries.removeFirst(removalCount)
            removedEntryCount += removalCount
        }

        return ChatDonorTranscript(entries: entries)
    }

    public mutating func reduceContext(for transcript: ChatDonorTranscript) -> ChatDonorTranscript {
        var entries = removeDanglingEntries(from: transcript.entries)

        if entries.count > 1 {
            let removalCount = min(reductionStride, entries.count - 1)
            entries.removeFirst(removalCount)
            removedEntryCount += removalCount
        } else if maxEntries == 0 {
            removedEntryCount += entries.count
            entries.removeAll()
        }

        return ChatDonorTranscript(entries: truncateToolOutputs(in: entries))
    }

    private mutating func removeDanglingEntries(from entries: [ChatDonorTranscriptEntry]) -> [ChatDonorTranscriptEntry] {
        var hasPrompt = false
        var kept: [ChatDonorTranscriptEntry] = []
        kept.reserveCapacity(entries.count)

        for entry in entries {
            if entry.role == .prompt {
                hasPrompt = true
                kept.append(entry)
            } else if hasPrompt {
                kept.append(entry)
            } else {
                removedEntryCount += 1
            }
        }

        return kept
    }

    private func truncateToolOutputs(in entries: [ChatDonorTranscriptEntry]) -> [ChatDonorTranscriptEntry] {
        entries.map { entry in
            guard (entry.role == .toolCall || entry.role == .toolOutput),
                  entry.text.count > maxToolOutputCharacters else {
                return entry
            }

            var truncated = entry
            truncated.text = String(entry.text.prefix(maxToolOutputCharacters)) + truncationMarker
            return truncated
        }
    }
}

public enum ChatDonorAgentKitCallbackKind: String, Codable, Hashable, Sendable {
    case text
    case toolUse = "tool-use"
    case message
    case metadata
    case end
}

public struct ChatDonorAgentKitCallbackEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: Int { sequence }
    public var sequence: Int
    public var kind: ChatDonorAgentKitCallbackKind
    public var payload: String

    public init(sequence: Int, kind: ChatDonorAgentKitCallbackKind, payload: String = "") {
        self.sequence = sequence
        self.kind = kind
        self.payload = payload
    }
}

public enum ChatDonorAgentKitCallbackAppendResult: Codable, Hashable, Sendable {
    case appended(sequence: Int)
    case rejectedAfterEnd
}

public struct ChatDonorAgentKitCallbackLog: Codable, Hashable, Sendable {
    public private(set) var events: [ChatDonorAgentKitCallbackEvent]

    public init(events: [ChatDonorAgentKitCallbackEvent] = []) {
        self.events = events
    }

    public var isTerminated: Bool {
        events.last?.kind == .end
    }

    public var hasValidOrdering: Bool {
        var sawEnd = false
        for (index, event) in events.enumerated() {
            guard event.sequence == index else { return false }
            if sawEnd { return false }
            if event.kind == .end { sawEnd = true }
        }
        return true
    }

    @discardableResult
    public mutating func append(
        kind: ChatDonorAgentKitCallbackKind,
        payload: String = ""
    ) -> ChatDonorAgentKitCallbackAppendResult {
        guard !isTerminated else {
            return .rejectedAfterEnd
        }

        let sequence = events.count
        events.append(ChatDonorAgentKitCallbackEvent(
            sequence: sequence,
            kind: kind,
            payload: payload
        ))
        return .appended(sequence: sequence)
    }
}
