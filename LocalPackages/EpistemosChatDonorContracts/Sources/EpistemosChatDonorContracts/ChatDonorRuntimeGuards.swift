import Foundation

public enum ChatDonorYieldResult: Codable, Hashable, Sendable {
    case enqueued(remainingCapacity: Int)
    case dropped
    case terminated

    init<Event>(_ result: AsyncStream<Event>.Continuation.YieldResult) {
        switch result {
        case .enqueued(let remainingCapacity):
            self = .enqueued(remainingCapacity: remainingCapacity)
        case .dropped:
            self = .dropped
        case .terminated:
            self = .terminated
        @unknown default:
            self = .terminated
        }
    }
}

public enum ChatDonorRuntimeTermination: String, Codable, Hashable, Sendable {
    case active
    case completed
    case cancelled
    case consumerFinished = "consumer-finished"
    case consumerCancelled = "consumer-cancelled"
    case failedValidation = "failed-validation"
}

public struct ChatDonorRuntimeReceipt: Codable, Hashable, Sendable {
    public var contractID: String
    public var donor: ChatDonorID
    public var featureID: String
    public var startedAtUnixSeconds: TimeInterval
    public var finishedAtUnixSeconds: TimeInterval?
    public var enqueuedEventCount: Int
    public var droppedEventCount: Int
    public var terminatedYieldCount: Int
    public var maxBufferedEvents: Int
    public var maxInMemoryAttachmentBytes: Int
    public var cancellationObserved: Bool
    public var termination: ChatDonorRuntimeTermination
    public var validationFailures: [ChatDonorContractValidationFailure]

    public init(
        contractID: String,
        donor: ChatDonorID,
        featureID: String,
        startedAtUnixSeconds: TimeInterval,
        finishedAtUnixSeconds: TimeInterval?,
        enqueuedEventCount: Int,
        droppedEventCount: Int,
        terminatedYieldCount: Int,
        maxBufferedEvents: Int,
        maxInMemoryAttachmentBytes: Int,
        cancellationObserved: Bool,
        termination: ChatDonorRuntimeTermination,
        validationFailures: [ChatDonorContractValidationFailure]
    ) {
        self.contractID = contractID
        self.donor = donor
        self.featureID = featureID
        self.startedAtUnixSeconds = startedAtUnixSeconds
        self.finishedAtUnixSeconds = finishedAtUnixSeconds
        self.enqueuedEventCount = enqueuedEventCount
        self.droppedEventCount = droppedEventCount
        self.terminatedYieldCount = terminatedYieldCount
        self.maxBufferedEvents = maxBufferedEvents
        self.maxInMemoryAttachmentBytes = maxInMemoryAttachmentBytes
        self.cancellationObserved = cancellationObserved
        self.termination = termination
        self.validationFailures = validationFailures
    }

    public var eventCount: Int {
        enqueuedEventCount + droppedEventCount + terminatedYieldCount
    }

    public var isContractValid: Bool {
        validationFailures.isEmpty
    }

    public var provesBoundedStream: Bool {
        maxBufferedEvents > 0 && !validationFailures.contains(.unboundedStream)
    }
}

public actor ChatDonorRuntimeRecorder {
    private let contract: ChatDonorFeatureContract
    private let startedAtUnixSeconds: TimeInterval
    private var finishedAtUnixSeconds: TimeInterval?
    private var enqueuedEventCount = 0
    private var droppedEventCount = 0
    private var terminatedYieldCount = 0
    private var cancellationObserved = false
    private var termination: ChatDonorRuntimeTermination

    public init(
        contract: ChatDonorFeatureContract,
        startedAt: Date = Date()
    ) {
        self.contract = contract
        self.startedAtUnixSeconds = startedAt.timeIntervalSince1970
        self.termination = contract.isValid ? .active : .failedValidation
        if !contract.isValid {
            self.finishedAtUnixSeconds = startedAt.timeIntervalSince1970
        }
    }

    public func record(_ result: ChatDonorYieldResult) {
        switch result {
        case .enqueued:
            enqueuedEventCount += 1
        case .dropped:
            droppedEventCount += 1
        case .terminated:
            terminatedYieldCount += 1
        }
    }

    public func cancel(at date: Date = Date()) {
        cancellationObserved = true
        finish(.cancelled, at: date)
    }

    public func complete(at date: Date = Date()) {
        finish(.completed, at: date)
    }

    public func noteConsumerFinished(at date: Date = Date()) {
        finish(.consumerFinished, at: date)
    }

    public func noteConsumerCancelled(at date: Date = Date()) {
        cancellationObserved = true
        finish(.consumerCancelled, at: date)
    }

    public func receipt() -> ChatDonorRuntimeReceipt {
        ChatDonorRuntimeReceipt(
            contractID: contract.id,
            donor: contract.donor,
            featureID: contract.featureID,
            startedAtUnixSeconds: startedAtUnixSeconds,
            finishedAtUnixSeconds: finishedAtUnixSeconds,
            enqueuedEventCount: enqueuedEventCount,
            droppedEventCount: droppedEventCount,
            terminatedYieldCount: terminatedYieldCount,
            maxBufferedEvents: contract.memory.maxBufferedEvents,
            maxInMemoryAttachmentBytes: contract.memory.maxInMemoryAttachmentBytes,
            cancellationObserved: cancellationObserved,
            termination: termination,
            validationFailures: contract.validationFailures
        )
    }

    private func finish(_ newTermination: ChatDonorRuntimeTermination, at date: Date) {
        guard termination == .active else { return }
        termination = newTermination
        finishedAtUnixSeconds = date.timeIntervalSince1970
    }
}

public struct ChatDonorBoundedStream<Event: Sendable>: Sendable {
    public let stream: AsyncStream<Event>
    public let recorder: ChatDonorRuntimeRecorder

    private let continuation: AsyncStream<Event>.Continuation

    public init(contract: ChatDonorFeatureContract) {
        precondition(contract.memory.maxBufferedEvents > 0, "Chat donor streams must have a positive buffer budget.")

        let recorder = ChatDonorRuntimeRecorder(contract: contract)
        let pair = Self.makeStream(
            bufferingNewest: contract.memory.maxBufferedEvents,
            recorder: recorder
        )

        self.stream = pair.stream
        self.continuation = pair.continuation
        self.recorder = recorder
    }

    @discardableResult
    public func yield(_ event: Event) async -> ChatDonorYieldResult {
        let result = ChatDonorYieldResult(continuation.yield(event))
        await recorder.record(result)
        return result
    }

    public func finish() async {
        await recorder.complete()
        continuation.finish()
    }

    public func cancel() async {
        await recorder.cancel()
        continuation.finish()
    }

    public func receipt() async -> ChatDonorRuntimeReceipt {
        await recorder.receipt()
    }

    private static func makeStream(
        bufferingNewest maxBufferedEvents: Int,
        recorder: ChatDonorRuntimeRecorder
    ) -> (stream: AsyncStream<Event>, continuation: AsyncStream<Event>.Continuation) {
        let pair = AsyncStream<Event>.makeStream(
            of: Event.self,
            bufferingPolicy: .bufferingNewest(maxBufferedEvents)
        )
        pair.continuation.onTermination = { @Sendable termination in
            Task {
                switch termination {
                case .finished:
                    await recorder.noteConsumerFinished()
                case .cancelled:
                    await recorder.noteConsumerCancelled()
                @unknown default:
                    await recorder.noteConsumerCancelled()
                }
            }
        }
        return (pair.stream, pair.continuation)
    }
}
