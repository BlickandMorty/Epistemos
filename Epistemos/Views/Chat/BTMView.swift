import SwiftUI

// MARK: - HELIOS V5 W5.b — Semantic Brain Time Machine V1.5 history scrubber.
//
// HELIOS-W5b guard
//
// Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W5 +
// `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §F:
//
//   "operates over claim-graph deltas only, NEVER tensor checkpoints"
//
// Tier 1: pure UI; never inspects model weights. Reads
// `agent_core::scope_rex::btm_semantic::SemanticDelta` history via
// the Swift mirror types in this file (a thin Codable bridge that
// matches the Rust wire format).
//
// Cross-references:
// - agent_core/src/scope_rex/btm_semantic.rs (Rust authoritative)
// - Epistemos/Models/AnswerPacket.swift (Swift Claim mirror)
// - docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1 (E1-E7 provenance)

/// Swift mirror of Rust `SemanticDelta`. Strictly additive; no
/// tensor / weights / checkpoint field per the W5 contract.
public struct SemanticDeltaView: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var addedClaims: [Claim]
    public var modifiedClaims: [Claim]
    public var removedClaimIds: [String]

    public init(
        id: String,
        addedClaims: [Claim] = [],
        modifiedClaims: [Claim] = [],
        removedClaimIds: [String] = []
    ) {
        self.id = id
        self.addedClaims = addedClaims
        self.modifiedClaims = modifiedClaims
        self.removedClaimIds = removedClaimIds
    }

    /// Total number of operations in this delta.
    public var opCount: Int {
        addedClaims.count + modifiedClaims.count + removedClaimIds.count
    }

    /// Compact label suitable for the timeline slider tick.
    public var compactLabel: String {
        "+\(addedClaims.count) ✏️\(modifiedClaims.count) -\(removedClaimIds.count)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case addedClaims = "added_claims"
        case modifiedClaims = "modified_claims"
        case removedClaimIds = "removed_claim_ids"
    }
}

/// SwiftUI view rendering a history scrubber over a sequence of
/// [`SemanticDeltaView`]. The slider rewinds to any point in
/// history; the current state shows the claim count + last applied
/// delta's compact label.
public struct BTMView: View {
    public let deltas: [SemanticDeltaView]
    public let initialClaimCount: Int

    @State private var currentIndex: Double = 0

    public init(deltas: [SemanticDeltaView], initialClaimCount: Int = 0) {
        self.deltas = deltas
        self.initialClaimCount = initialClaimCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Brain Time Machine V1.5")
                    .font(.headline)
                Spacer()
                Text("Semantic only — never tensors")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if deltas.isEmpty {
                Text("No semantic deltas in this conversation yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Slider(
                    value: $currentIndex,
                    in: 0...Double(deltas.count),
                    step: 1
                )
                .tint(.purple)

                HStack(spacing: 12) {
                    Text("Step \(Int(currentIndex)) / \(deltas.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Claims: \(claimsAtCurrentStep)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let last = lastAppliedDelta {
                        Text(last.compactLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if let last = lastAppliedDelta {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delta \(last.id)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 16) {
                                StatColumn(label: "Added", value: last.addedClaims.count, color: .green)
                                StatColumn(label: "Modified", value: last.modifiedClaims.count, color: .blue)
                                StatColumn(label: "Removed", value: last.removedClaimIds.count, color: .red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.20), lineWidth: 0.5)
                )
        )
    }

    private var lastAppliedDelta: SemanticDeltaView? {
        let i = Int(currentIndex)
        guard i > 0, i <= deltas.count else { return nil }
        return deltas[i - 1]
    }

    /// Net claim count after applying the first N deltas onto the
    /// initial state.
    private var claimsAtCurrentStep: Int {
        let n = Int(currentIndex)
        let applied = deltas.prefix(n)
        var total = initialClaimCount
        for d in applied {
            total += d.addedClaims.count
            total -= d.removedClaimIds.count
        }
        return max(total, 0)
    }
}

private struct StatColumn: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

#if DEBUG
#Preview("BTMView — 3 deltas") {
    let claim = { (id: String, text: String) in
        Claim(id: id, text: text, status: .active, createdAtMs: 1_745_000_000_000)
    }
    BTMView(
        deltas: [
            SemanticDeltaView(
                id: "d-0",
                addedClaims: [claim("c1", "first claim"), claim("c2", "second")]
            ),
            SemanticDeltaView(
                id: "d-1",
                modifiedClaims: [claim("c1", "first claim updated")]
            ),
            SemanticDeltaView(
                id: "d-2",
                removedClaimIds: ["c2"]
            ),
        ],
        initialClaimCount: 0
    )
    .frame(width: 480)
    .padding()
}

#Preview("BTMView — empty") {
    BTMView(deltas: [], initialClaimCount: 0)
        .frame(width: 480)
        .padding()
}
#endif
