import SwiftUI

// MARK: - EpdocThoughtAttachedBadge
//
// Wave 7.17.b SwiftUI thought-attached badge. Surfaces the W7.15
// `ThoughtAttachmentBridge` count next to the doc title — a small
// "⚡ N thoughts" pip that expands to a list of every RawThought
// run that touched the doc, with click-through into the agent
// inspector.
//
// Per the user's 2026-04-26 direction: "documents are attached to all
// thoughts in the pro system." The badge makes that connection
// instantly visible — every doc carries its agent-run history right
// at the title.
//
// Alexandrie has no equivalent. Notion / Obsidian / Craft have no
// equivalent — this is a unique Epistemos surface that depends on
// the W7.15 bridge being populated.

@MainActor
public struct EpdocThoughtAttachedBadge: View {

    /// Run ids attached to this doc (typically populated from
    /// `ThoughtAttachmentBridge.runs(thatGenerated documentID:)`).
    public let attachedRunIDs: [String]
    /// Closure fired when the user clicks a run id in the popover.
    /// The host opens the matching `RawThoughts` inspector tab.
    public let onPickRun: @Sendable @MainActor (String) -> Void

    @State private var isPopoverShown: Bool = false

    public init(
        attachedRunIDs: [String],
        onPickRun: @escaping @Sendable @MainActor (String) -> Void = { _ in }
    ) {
        self.attachedRunIDs = attachedRunIDs
        self.onPickRun = onPickRun
    }

    public var body: some View {
        Button {
            isPopoverShown.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(attachedRunIDs.isEmpty ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(Color.yellow))
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(attachedRunIDs.isEmpty ? Color.clear : Color.yellow.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .disabled(attachedRunIDs.isEmpty)
        .popover(isPresented: $isPopoverShown, arrowEdge: .bottom) {
            popoverContents
                .frame(width: 260)
                .padding(.vertical, 6)
        }
    }

    private var label: String {
        switch attachedRunIDs.count {
        case 0:  return "0 thoughts"
        case 1:  return "1 thought"
        default: return "\(attachedRunIDs.count) thoughts"
        }
    }

    private var tooltip: String {
        if attachedRunIDs.isEmpty {
            return "No agent runs have touched this doc yet"
        }
        return "Click to see the \(attachedRunIDs.count) agent runs that touched this doc"
    }

    @ViewBuilder
    private var popoverContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Attached agent runs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            ForEach(attachedRunIDs, id: \.self) { runID in
                Button {
                    onPickRun(runID)
                    isPopoverShown = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 10))
                        Text(runID.prefix(20))
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.clear)
            }
        }
    }
}

#if DEBUG
#Preview("0 thoughts (disabled)") {
    EpdocThoughtAttachedBadge(attachedRunIDs: [])
        .padding()
}

#Preview("1 thought") {
    EpdocThoughtAttachedBadge(attachedRunIDs: ["run-01HMV5K2K9XJ4N0ABCDE"])
        .padding()
}

#Preview("Multiple thoughts") {
    EpdocThoughtAttachedBadge(attachedRunIDs: [
        "run-01HMV5K2K9XJ4N0ABCDE",
        "run-01HMV5K2K9XJ4N0FGHIJ",
        "run-01HMV5K2K9XJ4N0KLMNO",
    ])
    .padding()
}
#endif
