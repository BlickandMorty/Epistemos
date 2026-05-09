import SwiftUI

/// Landing-only agent shelf for active companions.
///
/// The field is deliberately local to the Landing surface: agents stay in a
/// compact top-right cluster. They do not roam, walk, or own periodic clocks
/// while the Landing page is idle.
struct CompanionRoamingField: View {
    let entries: [CompanionRosterEntry]
    let activeCompanionID: String?
    var isAnimationActive: Bool = false
    var onActivate: (CompanionRosterEntry) -> Void = { _ in }
    var onRequestDelete: (CompanionRosterEntry) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated private static let nodeSize: CGFloat = 38
    nonisolated private static let tileSpan: CGFloat = 46
    nonisolated private static let maxVisibleAgents: Int = 6
    nonisolated private static let breathingRefreshInterval: TimeInterval = 0.75
    nonisolated private static let staticSampleDate = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if reduceMotion || !isAnimationActive {
                    nodes(at: Self.staticSampleDate, in: proxy.size)
                } else {
                    TimelineView(.periodic(from: .now, by: Self.breathingRefreshInterval)) { context in
                        nodes(at: context.date, in: proxy.size)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .frame(height: Self.fieldHeight(for: entries.count))
    }

    @ViewBuilder
    private func nodes(at date: Date, in size: CGSize) -> some View {
        let visibleEntries = Array(entries.prefix(Self.maxVisibleAgents))
        ForEach(visibleEntries.indices, id: \.self) { index in
            let entry = visibleEntries[index]
            companionNode(entry, at: date)
                .frame(width: Self.tileSpan, height: Self.tileSpan)
                .position(Self.shelfPosition(
                    index: index,
                    count: entries.count,
                    in: size
                ))
                .zIndex(entry.id == activeCompanionID ? 1 : 0)
        }
    }

    private func companionNode(_ entry: CompanionRosterEntry, at date: Date?) -> some View {
        CompanionView(
            entry: entry,
            size: Self.nodeSize,
            isActive: entry.id == activeCompanionID,
            sampledAnimationDate: date,
            showsMetadata: false,
            onActivate: { onActivate(entry) }
        )
        .help(agentHelpText(for: entry))
        .contextMenu {
            Button {
                onActivate(entry)
            } label: {
                Label("Activate", systemImage: "circle.dashed.inset.filled")
            }
            Button(role: .destructive) {
                onRequestDelete(entry)
            } label: {
                Label("Delete \(entry.name)", systemImage: "trash")
            }
        }
    }

    nonisolated static func fieldHeight(for count: Int) -> CGFloat {
        let rows = max(1, min(2, (min(max(count, 1), maxVisibleAgents) + 3) / 4))
        return CGFloat(rows) * 46.0
    }

    nonisolated static func shelfPosition(
        index: Int,
        count: Int,
        in size: CGSize
    ) -> CGPoint {
        let visibleCount = min(max(count, 1), maxVisibleAgents)
        let width = safeDimension(size.width, minimum: tileSpan * CGFloat(min(visibleCount, 4)))
        let height = safeDimension(size.height, minimum: fieldHeight(for: count))
        let paddingX = min(width / 2.0, nodeSize * 0.62)
        let paddingY = min(height / 2.0, nodeSize * 0.56)
        let columns = min(4, visibleCount)
        let rows = max(1, Int(ceil(Double(visibleCount) / Double(columns))))
        let column = index % columns
        let row = index / columns
        let anchor = CGPoint(
            x: width - paddingX - CGFloat(column) * tileSpan,
            y: axisAnchor(slot: row, slots: rows, lower: paddingY, upper: height - paddingY)
        )
        return CGPoint(
            x: clamp(anchor.x, lower: paddingX, upper: width - paddingX),
            y: clamp(anchor.y, lower: paddingY, upper: height - paddingY)
        )
    }

    private func agentHelpText(for entry: CompanionRosterEntry) -> String {
        let status = entry.id == activeCompanionID ? "Active" : "Available"
        if entry.tagline.isEmpty {
            return "\(status) agent: \(entry.name)"
        }
        return "\(status) agent: \(entry.name) — \(entry.tagline)"
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
