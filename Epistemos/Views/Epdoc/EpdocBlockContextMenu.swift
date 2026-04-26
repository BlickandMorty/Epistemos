import SwiftUI

// MARK: - EpdocBlockContextMenu
//
// Wave 7.17.b right-click block context menu. Alexandrie has zero
// in-block context menu (CodeMirror's default text menu only).
// This is the SwiftUI surface the host attaches via `.contextMenu`
// to each block node — the JS side emits the active block id +
// kind on right-click; the host renders this menu against that.
//
// Per the W7.17.b plan: convert to / duplicate / move / wrap in
// callout / comment / ask agent / cite as source. Each closure-
// based action lets the host decide how to wire into Tiptap
// commands or the agent runtime.

@MainActor
public struct EpdocBlockContextMenu: View {

    /// The block kind under the cursor (e.g. "paragraph", "heading",
    /// "code_block", "callout"). Drives which "Convert to…" entries
    /// appear (don't offer "Convert to paragraph" when the block
    /// IS already a paragraph).
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

    /// Convert-to candidates filtered by the active block kind.
    /// Excludes the current kind so the user can't no-op convert.
    public var convertCandidates: [(String, String, String)] {
        // (target_id, label, SF Symbol)
        let all: [(String, String, String)] = [
            ("paragraph",   "Paragraph",      "text.alignleft"),
            ("heading-1",   "Heading 1",      "h.square"),
            ("heading-2",   "Heading 2",      "h.square"),
            ("heading-3",   "Heading 3",      "h.square"),
            ("blockquote",  "Quote",          "text.quote"),
            ("code-block",  "Code block",     "curlybraces"),
            ("bullet-list", "Bulleted list",  "list.bullet"),
            ("numbered-list","Numbered list", "list.number"),
            ("task-list",   "Task list",      "checklist"),
            ("math-display","Math (block)",   "function"),
            ("mermaid",     "Mermaid diagram","flowchart"),
        ]
        return all.filter { $0.0 != blockKind }
    }

    public var body: some View {
        Group {
            Menu {
                ForEach(convertCandidates, id: \.0) { (id, label, symbol) in
                    Button {
                        onConvertTo(id)
                    } label: {
                        Label(label, systemImage: symbol)
                    }
                }
            } label: {
                Label("Convert to…", systemImage: "arrow.triangle.2.circlepath")
            }

            Menu {
                Button { onWrapInCallout("tip") }     label: { Label("Tip",     systemImage: "lightbulb") }
                Button { onWrapInCallout("info") }    label: { Label("Info",    systemImage: "info.circle") }
                Button { onWrapInCallout("warning") } label: { Label("Warning", systemImage: "exclamationmark.triangle") }
                Button { onWrapInCallout("danger") }  label: { Label("Danger",  systemImage: "octagon") }
                Button { onWrapInCallout("details") } label: { Label("Details", systemImage: "rectangle.expand.vertical") }
            } label: {
                Label("Wrap in callout", systemImage: "rectangle.on.rectangle")
            }

            Divider()

            Button {
                onDuplicate()
            } label: {
                Label("Duplicate block", systemImage: "doc.on.doc")
            }

            Button {
                onMoveUp()
            } label: {
                Label("Move up", systemImage: "arrow.up")
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .shift])

            Button {
                onMoveDown()
            } label: {
                Label("Move down", systemImage: "arrow.down")
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])

            Divider()

            // EXCEED features — agent + sourcing.
            Button {
                onAskAgent()
            } label: {
                Label("Ask agent about this block", systemImage: "sparkles")
            }

            Button {
                onCiteAsSource()
            } label: {
                Label("Cite as source", systemImage: "quote.bubble")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete block", systemImage: "trash")
            }
        }
    }
}
