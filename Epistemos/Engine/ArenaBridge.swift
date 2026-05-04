import Foundation

enum ArenaOp: UInt16, CaseIterable, Sendable {
    case retrieve = 1
    case plan = 2
    case execute = 3
    case escalate = 4
}

struct ArenaArtefactRef: Equatable, Sendable {
    let blobId: Data
    let offset: UInt64
    let length: UInt64
    let flags: UInt32
}

struct ArenaResponse: Equatable, Sendable {
    let sequence: UInt64
    let status: UInt16
    let payload: Data
    let refs: [ArenaArtefactRef]
}

actor ArenaBridge {
    static let arenaVersion: UInt32 = 2
    static let slotCount = 16
    static let maxInlinePayloadBytes = 2_048
    static let maxInlineResponseBytes = 4_096
    static let maxArtefactRefs = 8

    let arenaURL: URL

    private var nextSequence: UInt64 = 1
    private var submittedRequests: [UInt64: ArenaSubmittedRequest] = [:]
    private var pendingResponses: [UInt64: ArenaResponse] = [:]

    init(arenaURL: URL) {
        self.arenaURL = arenaURL
    }

    @MainActor
    static func open(container: AppGroupContainer = .shared) throws -> ArenaBridge {
        ArenaBridge(arenaURL: try ArenaPathResolver.resolve(container: container))
    }

    func submitRequest(op: ArenaOp, payload: Data) throws -> UInt64 {
        guard submittedRequests.count < 1_024 else {
            throw ArenaBridgeError.ringFull
        }

        let sequence = nextSequence
        nextSequence &+= 1

        submittedRequests[sequence] = ArenaSubmittedRequest(
            sequence: sequence,
            op: op,
            payload: Data(payload.prefix(Self.maxInlinePayloadBytes))
        )
        return sequence
    }

    func submittedRequest(sequence: UInt64) -> ArenaSubmittedRequest? {
        submittedRequests[sequence]
    }

    func ingestResponse(_ response: ArenaResponse) {
        pendingResponses[response.sequence] = ArenaResponse(
            sequence: response.sequence,
            status: response.status,
            payload: Data(response.payload.prefix(Self.maxInlineResponseBytes)),
            refs: Array(response.refs.prefix(Self.maxArtefactRefs))
        )
        submittedRequests.removeValue(forKey: response.sequence)
    }

    func pollResponse(sequence: UInt64) -> ArenaResponse? {
        pendingResponses.removeValue(forKey: sequence)
    }

    func awaitResponse(
        sequence: UInt64,
        timeout: Duration = .seconds(30),
        pollInterval: Duration = .milliseconds(5)
    ) async throws -> ArenaResponse {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while clock.now < deadline {
            if let response = pollResponse(sequence: sequence) {
                return response
            }
            try await clock.sleep(for: pollInterval)
        }

        throw ArenaBridgeError.timeout(sequence: sequence)
    }

    func readSignalEpoch() -> UInt64 {
        0
    }
}

struct ArenaSubmittedRequest: Equatable, Sendable {
    let sequence: UInt64
    let op: ArenaOp
    let payload: Data
}

enum ArenaBridgeError: Error, LocalizedError, Equatable {
    case ringFull
    case timeout(sequence: UInt64)

    var errorDescription: String? {
        switch self {
        case .ringFull:
            return "Arena request ring is full."
        case .timeout(let sequence):
            return "Timeout waiting for arena response sequence \(sequence)."
        }
    }
}
