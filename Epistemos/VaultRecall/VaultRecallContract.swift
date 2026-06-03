import Foundation

nonisolated public enum VaultRecallContract {
    public static func trace(
        query: String,
        eidosPacket: EidosContextPacket,
        generatedAtMs: UInt64? = nil
    ) -> VaultRecallTrace {
        let effectiveQuery = effectiveQuery(query)
        let candidates = eidosPacket.hits.map(candidate(from:))
        return VaultRecallTrace(
            query: query,
            effectiveQuery: effectiveQuery,
            ladderTier: ladderTier(for: eidosPacket),
            candidatePoolSize: eidosPacket.hits.count,
            candidatesRetained: candidates.count,
            candidates: candidates,
            signalSummary: signalSummary(for: candidates),
            generatedAtMs: generatedAtMs ?? packetGeneratedAtMs(eidosPacket),
            notes: [
                "T21 unified retrieval contract: Eidos packet projected into VaultRecallTrace",
                "closed-citation source ids preserved in selection reasons",
                "PageGather dense restore remains deferred; trace marks vault escalation only"
            ],
            allChatterFallback: !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && effectiveQuery.isEmpty,
            pageGather: PageGatherEscalationTrace(
                source: "QueryRuntime.Eidos",
                candidatePoolSize: eidosPacket.hits.count,
                candidatesRetained: candidates.count
            )
        )
    }

    @discardableResult
    public static func recordEidosPacket(
        query: String,
        packet: EidosContextPacket,
        latencyMs: Double
    ) -> VaultRecallTrace {
        let trace = trace(query: query, eidosPacket: packet)
        VaultRecallBridge.recordProductionTrace(trace, latencyMs: latencyMs)
        return trace
    }

    private static func candidate(from hit: EidosHit) -> VaultRecallCandidate {
        VaultRecallCandidate(
            path: hit.documentId.raw,
            title: nil,
            snippet: nil,
            fusedScore: boundedUnitScore(hit.confidence),
            signals: signalScores(for: hit),
            selectionReason: "Eidos \(hit.provenance.mode.rawValue) closed-citation hit \(hit.sourceId.raw)"
        )
    }

    private static func signalScores(for hit: EidosHit) -> [VaultRecallSignalScore] {
        var scores: [VaultRecallSignalScore] = []
        scores.reserveCapacity(4)
        append(score: hit.score.lexical, signal: .lexical, to: &scores)
        append(score: hit.score.semantic, signal: .semantic, to: &scores)
        append(score: hit.score.graph, signal: .graph, to: &scores)
        append(score: hit.score.recency, signal: .recency, to: &scores)
        if scores.isEmpty {
            scores.append(
                VaultRecallSignalScore(
                    signal: fallbackSignal(for: hit.provenance.mode),
                    raw: boundedFiniteScore(hit.confidence),
                    normalized: boundedUnitScore(hit.confidence)
                )
            )
        }
        return scores
    }

    private static func append(
        score: Float,
        signal: VaultRecallSignal,
        to scores: inout [VaultRecallSignalScore]
    ) {
        guard score.isFinite, score != 0 else { return }
        scores.append(
            VaultRecallSignalScore(
                signal: signal,
                raw: Double(score),
                normalized: boundedUnitScore(score)
            )
        )
    }

    private static func signalSummary(for candidates: [VaultRecallCandidate]) -> [VaultRecallSignal] {
        let present = Set(candidates.flatMap { candidate in
            candidate.signals.map(\.signal)
        })
        return VaultRecallSignal.allCases.filter(present.contains)
    }

    private static func fallbackSignal(for mode: EidosRetrievalMode) -> VaultRecallSignal {
        switch mode {
        case .lexical, .rawArchive:
            return .lexical
        case .semantic, .hybrid, .claimEvidence, .provenanceVerified:
            return .semantic
        case .codeSymbol, .graphNeighborhood:
            return .graph
        case .recency:
            return .recency
        }
    }

    private static func ladderTier(for eidosPacket: EidosContextPacket) -> String {
        switch EidosBridge.detectedBackend(from: eidosPacket) {
        case .real:
            return "vault-eidos-v0"
        case .fixture:
            return "eidos-fixture-v0"
        case .unknown:
            return "eidos-unknown-v0"
        }
    }

    private static func effectiveQuery(_ query: String) -> String {
        var terms: [String] = []
        terms.reserveCapacity(8)
        var current = String()
        current.reserveCapacity(32)

        func flushCurrentTerm() {
            guard current.count >= 2 else {
                current.removeAll(keepingCapacity: true)
                return
            }
            terms.append(current)
            current.removeAll(keepingCapacity: true)
        }

        for scalar in query.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                flushCurrentTerm()
            }
            if terms.count >= 20 {
                current.removeAll(keepingCapacity: true)
                break
            }
        }
        flushCurrentTerm()
        return terms.prefix(20).joined(separator: " ")
    }

    private static func packetGeneratedAtMs(_ packet: EidosContextPacket) -> UInt64 {
        if let maxHitTime = packet.hits.map(\.provenance.retrievedAtUnixMs).max(), maxHitTime > 0 {
            return maxHitTime
        }
        let value = Date().timeIntervalSince1970 * 1000
        guard value.isFinite, value > 0 else { return 0 }
        return UInt64(value)
    }

    private static func boundedFiniteScore(_ value: Float) -> Double {
        guard value.isFinite else { return 0 }
        return Double(value)
    }

    private static func boundedUnitScore(_ value: Float) -> Double {
        let finite = boundedFiniteScore(value)
        return min(1, max(0, finite))
    }
}
