import Foundation

extension HTMLWorkspaceDataFeedContextSources {
    static func provenanceClaimResults(
        query: String?,
        limit: Int,
        store: AnswerPacketStore? = AnswerPacketStore.defaultEpistemosStore()
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let store else { return [] }
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let packets = (try? store.loadRecent(limit: max(effectiveLimit * 8, 24))) ?? []
        return provenanceClaimResults(
            query: query,
            packets: packets,
            limit: effectiveLimit
        )
    }

    static func provenanceClaimResults(
        query: String?,
        packets: [AnswerPacket],
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        let terms = provenanceClaimSearchTerms(from: query)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        return packets
            .flatMap { packet in
                packet.activeClaims.map { claim in
                    ProvenanceClaimCandidate(packet: packet, claim: claim)
                }
            }
            .filter { candidate in
                terms.isEmpty || terms.allSatisfy { candidate.searchText.contains($0) }
            }
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.pageID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - Double(index) * 0.01),
                    contextKind: "provenance_claim",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUseProvenanceClaimResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedProvenanceQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("claim:") || normalizedQuery.hasPrefix("claims:")
            || normalizedQuery.hasPrefix("provenance:") || normalizedQuery.hasPrefix("lineage:") {
            return true
        }
        if normalizedQuery.hasPrefix("claim ") || normalizedQuery.hasPrefix("claims ")
            || normalizedQuery.hasPrefix("provenance ") || normalizedQuery.hasPrefix("lineage ")
            || normalizedQuery.hasPrefix("answer packet ") || normalizedQuery.hasPrefix("answer packets ") {
            return true
        }
        return [
            "claim",
            "claims",
            "provenance",
            "provenance claims",
            "lineage",
            "answer packet",
            "answer packets",
            "verification claims",
        ].contains(normalizedQuery)
    }

    private struct ProvenanceClaimCandidate {
        var packet: AnswerPacket
        var claim: Claim

        var pageID: String {
            "answer-packet:\(packet.id):claim:\(claim.id)"
        }

        var title: String {
            "\(claim.kind.displayLabel) claim"
        }

        var snippet: String {
            let text = normalizedProvenanceText(claim.text)
            return text.isEmpty ? "No claim text available." : boundedProvenanceText(text, limit: 420)
        }

        var sourceLabel: String {
            if let label = VRMLabel.honestLabel(for: packet)?.shortLabel {
                return "Provenance claim: \(label)"
            }
            return "Provenance claim"
        }

        var provenance: String {
            [
                "AnswerPacketStore",
                "packet:\(packet.id)",
                "claim:\(claim.id)",
                "kind:\(claim.kind.rawValue)",
                "status:\(claim.status.rawValue)",
                "created_at_ms:\(claim.createdAtMs)",
                acsAnchorText,
                uasAddressText,
                "attention:\(packet.attentionMode.rawValue)",
                "interrupt:\(packet.interruptBucket.rawValue)",
            ]
                .compactMap { normalizedProvenanceText($0).isEmpty ? nil : $0 }
                .joined(separator: " / ")
        }

        var searchText: String {
            [
                packet.id,
                packet.witnessedStateRef,
                packet.semanticDeltaRef,
                packet.mutationEnvelopeRef,
                claim.id,
                claim.text,
                claim.kind.rawValue,
                claim.status.rawValue,
                claim.acsAnchor?.theoremId,
                claim.uasAddress?.kind,
            ]
                .compactMap { $0 }
                .map { normalizedProvenanceText($0).lowercased() }
                .joined(separator: " ")
        }

        private var acsAnchorText: String {
            guard let anchor = claim.acsAnchor else { return "" }
            return "acs:\(anchor.anchorId):\(anchor.theoremId)"
        }

        private var uasAddressText: String {
            guard let uas = claim.uasAddress else { return "" }
            return "uas:\(uas.kind):\(uas.createdAtMs)"
        }
    }

    private static func provenanceClaimSearchTerms(from query: String?) -> [String] {
        var value = normalizedProvenanceQuery(query)
        for prefix in ["claim:", "claims:", "provenance:", "lineage:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = [
            "answer",
            "packet",
            "packets",
            "claim",
            "claims",
            "lineage",
            "provenance",
            "verification",
        ]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func normalizedProvenanceQuery(_ value: String?) -> String {
        normalizedProvenanceText(value).lowercased()
    }

    private static func normalizedProvenanceText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedProvenanceText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedProvenanceText(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }
}

private extension ClaimKind {
    var displayLabel: String {
        switch self {
        case .empirical: return "Empirical"
        case .mathematical: return "Mathematical"
        case .codeInvariant: return "Code invariant"
        case .causal: return "Causal"
        case .speculative: return "Speculative"
        case .staticFallbackAcknowledged: return "Static fallback acknowledged"
        }
    }
}
