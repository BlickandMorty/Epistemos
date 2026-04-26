import SwiftUI

// MARK: - EpdocBlockGutterMenu
//
// Wave 7.17.b block-action gutter menu. The Tiptap drag-handle
// extension renders a `⋮⋮ ＋` affordance to the left of every
// block on hover; clicking the ⋯ button opens this SwiftUI menu.
// (The hover-track + the ＋ "add block above" path are JS-side
// W7.17.b runtime work; this is the menu surface.)
//
// Reuses `EpdocBlockContextMenu`'s callback shape since both
// surfaces dispatch the same actions; this view is a presentation
// wrapper that reads + renders into a labeled `.menu` button
// instead of being attached via `.contextMenu`.

@MainActor
public struct EpdocBlockGutterMenu: View {

    public let blockKind: String
    public let onConvertTo: @Sendable @MainActor (String) -> Void
    public let onDuplicate: @Sendable @MainActor () -> Void
    public let onMoveUp: @Sendable @MainActor () -> Void
    public let onMoveDown: @Sendable @MainActor () -> Void
    public let onWrapInCallout: @Sendable @MainActor (String) -> Void
    public let onAskAgent: @Sendable @MainActor () -> Void
    public let onCiteAsSource: @Sendable @MainActor () -> Void
    public let onDelete: @Sendable @MainActor () -> Void

    public init(
        blockKind: String,
        onConvertTo: @escaping @Sendable @MainActor (String) -> Void = { _ in },
        onDuplicate: @escaping @Sendable @MainActor () -> Void = {},
        onMoveUp: @escaping @Sendable @MainActor () -> Void = {},
        onMoveDown: @escaping @Sendable @MainActor () -> Void = {},
        onWrapInCallout: @escaping @Sendable @MainActor (String) -> Void = { _ in },
        onAskAgent: @escaping @Sendable @MainActor () -> Void = {},
        onCiteAsSource: @escaping @Sendable @MainActor () -> Void = {},
        onDelete: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.blockKind = blockKind
        self.onConvertTo = onConvertTo
        self.onDuplicate = onDuplicate
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onWrapInCallout = onWrapInCallout
        self.onAskAgent = onAskAgent
        self.onCiteAsSource = onCiteAsSource
        self.onDelete = onDelete
    }

    public var body: some View {
        Menu {
            EpdocBlockContextMenu(
                blockKind: blockKind,
                onConvertTo: onConvertTo,
                onDuplicate: onDuplicate,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onWrapInCallout: onWrapInCallout,
                onAskAgent: onAskAgent,
                onCiteAsSource: onCiteAsSource,
                onDelete: onDelete
            )
        } label: {
            Image(systemName: "ellipsis")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .help("Block actions")
    }
}
