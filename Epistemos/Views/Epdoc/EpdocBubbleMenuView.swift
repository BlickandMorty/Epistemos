import SwiftUI

// MARK: - EpdocBubbleMenuView
//
// Wave 7.17.b SwiftUI bubble menu — appears above the cursor when
// the user makes a selection in the Tiptap WKWebView. Mirrors
// Notion / Bear's "selection toolbar" but adds two buttons
// Alexandrie (and most editors) lack: **Ask agent** and **Capture
// as RawThought** — both wire into Epistemos's existing agent
// runtime + raw-thoughts substrate.
//
// Triggered by `EpdocBridgeMessage.requestBubbleMenu(selection,
// anchor)`. The host positions the panel at the anchor + dismisses
// when selection collapses (via the same bridge stream).

@MainActor
public struct EpdocBubbleMenuView: View {

    /// The selected text — surfaces in the agent prompt + the
    /// captured RawThought body.
    public let selectedText: String
    /// Tiptap mark-active flags so Bold/Italic/etc. show selected.
    public let isBoldActive: Bool
    public let isItalicActive: Bool
    public let isHighlightActive: Bool
    public let isCodeActive: Bool

    public let onCommand: @Sendable @MainActor (EpdocEditorCommand) -> Void
    /// Open the agent inspector with the selected text as the prompt.
    public let onAskAgent: @Sendable @MainActor (String) -> Void
    /// Capture the selected text as a new RawThought attached to the
    /// current document. Wires into RawThoughtsState (Wave 3.1).
    public let onCaptureAsRawThought: @Sendable @MainActor (String) -> Void
    /// RCA7-P1-005 honesty switch (2026-05-13): when both `onAskAgent`
    /// and `onCaptureAsRawThought` are left at their no-op defaults,
    /// the host hasn't wired the EXCEED actions. In that case the two
    /// buttons are HIDDEN rather than rendered as broken no-ops.
    /// Production hosts that wire either callback must also pass
    /// `agentActionsWired: true` so the buttons surface.
    public let agentActionsWired: Bool

    public init(
        selectedText: String,
        isBoldActive: Bool = false,
        isItalicActive: Bool = false,
        isHighlightActive: Bool = false,
        isCodeActive: Bool = false,
        onCommand: @escaping @Sendable @MainActor (EpdocEditorCommand) -> Void = { _ in },
        onAskAgent: @escaping @Sendable @MainActor (String) -> Void = { _ in },
        onCaptureAsRawThought: @escaping @Sendable @MainActor (String) -> Void = { _ in },
        agentActionsWired: Bool = false
    ) {
        self.selectedText = selectedText
        self.isBoldActive = isBoldActive
        self.isItalicActive = isItalicActive
        self.isHighlightActive = isHighlightActive
        self.isCodeActive = isCodeActive
        self.agentActionsWired = agentActionsWired
        self.onCommand = onCommand
        self.onAskAgent = onAskAgent
        self.onCaptureAsRawThought = onCaptureAsRawThought
    }

    public var body: some View {
        HStack(spacing: 4) {
            formatButton(symbol: "bold",          isActive: isBoldActive,
                         tip: "Bold (⌘B)",         command: .runCommand(name: "toggleBold",      argsJSON: emptyArgs))
            formatButton(symbol: "italic",        isActive: isItalicActive,
                         tip: "Italic (⌘I)",       command: .runCommand(name: "toggleItalic",    argsJSON: emptyArgs))
            formatButton(symbol: "chevron.left.forwardslash.chevron.right", isActive: isCodeActive,
                         tip: "Inline code (⌘E)",  command: .runCommand(name: "toggleCode",      argsJSON: emptyArgs))
            formatButton(symbol: "curlybraces",    isActive: false,
                         tip: "Code block (⌘⇧C)",  command: .runCommand(name: "toggleCodeBlock", argsJSON: emptyArgs))
            formatButton(symbol: "highlighter",   isActive: isHighlightActive,
                         tip: "Highlight (⌘⇧H)",   command: .runCommand(name: "toggleHighlight", argsJSON: emptyArgs))
            divider
            formatButton(symbol: "link",          isActive: false,
                         tip: "Insert link (⌘K)",  command: .runCommand(name: "setLink",         argsJSON: emptyArgs))
            // EXCEED features — agent + thought capture. Per
            // RCA7-P1-005 fix-pass these are hidden until the host
            // wires the callbacks (no more visible-broken no-ops).
            if agentActionsWired {
                divider
                actionButton(symbol: "sparkles", tip: "Ask agent about selection") {
                    onAskAgent(selectedText)
                }
                actionButton(symbol: "bolt.badge.clock", tip: "Capture as Raw Thought (⚡)") {
                    onCaptureAsRawThought(selectedText)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func formatButton(
        symbol: String,
        isActive: Bool,
        tip: String,
        command: EpdocEditorCommand
    ) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, height: 22)
                .foregroundStyle(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        }
        .buttonStyle(.borderless)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .help(tip)
    }

    @ViewBuilder
    private func actionButton(
        symbol: String,
        tip: String,
        action: @escaping @Sendable @MainActor () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, height: 22)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.borderless)
        .help(tip)
    }

    private var divider: some View {
        Rectangle().fill(.separator).frame(width: 0.5, height: 16).padding(.horizontal, 2)
    }

    private var emptyArgs: Data { "[]".data(using: .utf8) ?? Data() }
}

#if DEBUG
#Preview("Plain selection") {
    EpdocBubbleMenuView(selectedText: "the selected words")
        .padding()
}

#Preview("Bold + highlight active") {
    EpdocBubbleMenuView(
        selectedText: "important text",
        isBoldActive: true,
        isHighlightActive: true
    )
    .padding()
}
#endif
