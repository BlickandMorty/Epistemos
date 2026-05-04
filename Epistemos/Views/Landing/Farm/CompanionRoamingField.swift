import SwiftUI

/// Deterministic Landing Farm roaming layer for active companions.
///
/// The field is deliberately local to the Landing Farm: companions get
/// seeded idle walks here before any graph-presence work touches graph
/// physics or Metal rendering.
struct CompanionRoamingField: View {
    let entries: [CompanionRosterEntry]
    let activeCompanionID: String?
    var onActivate: (CompanionRosterEntry) -> Void = { _ in }
    var onApplyAdapter: (CompanionRosterEntry) -> Void = { _ in }
    var onRequestDelete: (CompanionRosterEntry) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated private static let nodeSize: CGFloat = 96
    nonisolated private static let tileSpan: CGFloat = 132

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if reduceMotion {
                    nodes(at: .distantPast, in: proxy.size, reduceMotion: true)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                        nodes(at: context.date, in: proxy.size, reduceMotion: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .frame(height: Self.fieldHeight(for: entries.count))
    }

    @ViewBuilder
    private func nodes(at date: Date, in size: CGSize, reduceMotion: Bool) -> some View {
        ForEach(entries.indices, id: \.self) { index in
            let entry = entries[index]
            companionNode(entry)
                .frame(width: Self.tileSpan, height: Self.tileSpan)
                .position(Self.roamingPosition(
                    for: entry,
                    index: index,
                    count: entries.count,
                    in: size,
                    at: date,
                    reduceMotion: reduceMotion
                ))
                .zIndex(entry.id == activeCompanionID ? 1 : 0)
        }
    }

    private func companionNode(_ entry: CompanionRosterEntry) -> some View {
        CompanionView(
            entry: entry,
            size: Self.nodeSize,
            isActive: entry.id == activeCompanionID,
            onActivate: { onActivate(entry) }
        )
        .contextMenu {
            Button {
                onActivate(entry)
            } label: {
                Label("Activate", systemImage: "circle.dashed.inset.filled")
            }
            Button {
                onApplyAdapter(entry)
            } label: {
                Label("Apply Adapter...", systemImage: "wand.and.stars")
            }
            Divider()
            Button(role: .destructive) {
                onRequestDelete(entry)
            } label: {
                Label("Delete \(entry.name)", systemImage: "trash")
            }
        }
    }

    nonisolated static func fieldHeight(for count: Int) -> CGFloat {
        let rows = max(1, min(3, (max(count, 1) + 2) / 3))
        return CGFloat(rows) * 136.0
    }

    nonisolated static func roamingPosition(
        for entry: CompanionRosterEntry,
        index: Int,
        count: Int,
        in size: CGSize,
        at date: Date,
        reduceMotion: Bool
    ) -> CGPoint {
        let width = safeDimension(size.width, minimum: tileSpan)
        let height = safeDimension(size.height, minimum: fieldHeight(for: count))
        let paddingX = min(width / 2.0, nodeSize * 0.72)
        let paddingY = min(height / 2.0, nodeSize * 0.64)
        let availableWidth = max(tileSpan, width)
        let estimatedColumns = Int(max(1.0, floor(Double(availableWidth / tileSpan))))
        let columns = max(1, min(max(count, 1), estimatedColumns))
        let rows = max(1, Int(ceil(Double(max(count, 1)) / Double(columns))))
        let column = index % columns
        let row = index / columns
        let anchor = CGPoint(
            x: axisAnchor(slot: column, slots: columns, lower: paddingX, upper: width - paddingX),
            y: axisAnchor(slot: row, slots: rows, lower: paddingY, upper: height - paddingY)
        )

        guard !reduceMotion else { return anchor }

        var prng = DeterministicPRNG(seedString: "\(entry.identityHash):landing-roam")
        let xRadius = CGFloat(12.0 + prng.unitDouble() * 24.0)
        let yRadius = CGFloat(8.0 + prng.unitDouble() * 18.0)
        let xPeriod = 22.0 + prng.unitDouble() * 18.0
        let yPeriod = 28.0 + prng.unitDouble() * 20.0
        let xPhase = prng.unitDouble() * .pi * 2.0
        let yPhase = prng.unitDouble() * .pi * 2.0
        let t = date.timeIntervalSinceReferenceDate
        let x = anchor.x + cos(t * .pi * 2.0 / xPeriod + xPhase) * xRadius
        let y = anchor.y + sin(t * .pi * 2.0 / yPeriod + yPhase) * yRadius

        return CGPoint(
            x: clamp(x, lower: paddingX, upper: width - paddingX),
            y: clamp(y, lower: paddingY, upper: height - paddingY)
        )
    }

    nonisolated private static func safeDimension(_ value: CGFloat, minimum: CGFloat) -> CGFloat {
        guard value.isFinite else { return minimum }
        return max(value, minimum)
    }

    nonisolated private static func axisAnchor(
        slot: Int,
        slots: Int,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat {
        guard slots > 1 else { return (lower + upper) / 2.0 }
        let fraction = CGFloat(slot) / CGFloat(slots - 1)
        return lower + (upper - lower) * fraction
    }

    nonisolated private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
