import SwiftUI

// MARK: - EpdocEditorToolbar
//
// Wave 7.17.a SwiftUI top toolbar shell — the Material-3-flavoured
// chrome surface that floats above the .epdoc Tiptap WKWebView. Per
// the user's 2026-04-26 direction: "I want it to look really opulent
// … flat design kind of like Google Material 3."
//
// Hybrid render decision (W7.17.a in the plan):
//   - SwiftUI for the chrome (this file): top toolbar, right inspector,
//     left outliner, command palette, complexity meter, thought-attached
//     badge — all benefit from native macOS Material-3 polish, free
//     dark mode, accessibility, opulent feel.
//   - Tiptap WKWebView for the caret-glued tools: slash menu,
//     formatting bubble, KaTeX live preview, drag-handle gutter.
//     Position those across the SwiftUI/WebView bridge stutters; they
//     stay inside the WebView where ProseMirror owns the geometry.
//
// This commit ships the toolbar SHELL — every button is wired to an
// `EpdocEditorCommand` that the host can dispatch into the live editor
// (W7.17 implementation lands next; today the toolbar is consumable
// in isolation via `EpdocEditorToolbar(model:)` in any SwiftUI scope).
//
// Cross-references:
//   - Bridge contract: `Epistemos/Engine/EpdocEditorBridge.swift`
//   - Slash-menu catalogue: `js-editor/src/extensions/slash-menu.ts`
//   - Inventory borrowed from Alexandrie's Toolbar.vue:2-117 +
//     editorKeymaps.ts:1-228 (2026-04-26 scan)

// MARK: - Toolbar state model

/// View model for the top toolbar. Owns the live word/char/line
/// counts (driven off the JS-side `CharacterCount` extension) +
/// surfaces a `dispatch` closure the buttons fire commands into.
@MainActor
@Observable
public final class EpdocEditorToolbarModel {
    /// Live word count (drives the right-cluster stats badge).
    public var wordCount: Int = 0
    /// Live character count.
    public var characterCount: Int = 0
    /// Whether the document is dirty (unsaved). Flips the Save
    /// button's accent state.
    public var isDirty: Bool = false
    /// True while a save is in flight; flips the Save button to a
    /// progress spinner.
    public var isSaving: Bool = false
    /// Active heading level (1...6) when the cursor is inside a
    /// heading; nil otherwise. Drives the H button's selected state.
    public var activeHeadingLevel: Int? = nil
    /// Whether the bold mark is active at the current selection.
    public var isBoldActive: Bool = false
    public var isItalicActive: Bool = false
    public var isStrikeActive: Bool = false
    public var isCodeActive: Bool = false
    public var isHighlightActive: Bool = false

    /// Fire a Swift → JS command. The host installs the closure when
    /// it constructs the toolbar; `EpdocEditorChromeView` defaults to
    /// a no-op so the toolbar is renderable in isolation (previews +
    /// snapshot tests).
    public var dispatch: @Sendable @MainActor (EpdocEditorCommand) -> Void = { _ in }

    public init() {}
}

// MARK: - Toolbar SwiftUI view

@MainActor
public struct EpdocEditorToolbar: View {

    @Bindable public var model: EpdocEditorToolbarModel
    /// Triggered when the user hits ⌘S or the Save button. The host
    /// runs the actual NSDocument save coordinator.
    public var onSave: @Sendable @MainActor () -> Void = {}

    public init(
        model: EpdocEditorToolbarModel,
        onSave: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.model = model
        self.onSave = onSave
    }

    public var body: some View {
        HStack(spacing: 12) {
            formattingGroup
            divider
            extendedFormattingGroup
            divider
            insertGroup
            divider
            structureGroup
            Spacer()
            statsBadge
            saveButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }

    // MARK: - Groups

    @ViewBuilder
    private var formattingGroup: some View {
        toolButton(symbol: "bold",          shortcut: "⌘B", isActive: model.isBoldActive,
                   tip: "Bold (⌘B)",       command: .runCommand(name: "toggleBold",      argsJSON: emptyArgs))
        toolButton(symbol: "italic",        shortcut: "⌘I", isActive: model.isItalicActive,
                   tip: "Italic (⌘I)",     command: .runCommand(name: "toggleItalic",    argsJSON: emptyArgs))
        toolButton(symbol: "strikethrough", shortcut: "⌘⇧S", isActive: model.isStrikeActive,
                   tip: "Strikethrough",   command: .runCommand(name: "toggleStrike",    argsJSON: emptyArgs))
        toolButton(symbol: "highlighter",   shortcut: "⌘⇧H", isActive: model.isHighlightActive,
                   tip: "Highlight",       command: .runCommand(name: "toggleHighlight", argsJSON: emptyArgs))
        toolButton(symbol: "chevron.left.forwardslash.chevron.right", shortcut: "⌘E",
                   isActive: model.isCodeActive,
                   tip: "Inline code (⌘E)", command: .runCommand(name: "toggleCode",     argsJSON: emptyArgs))
    }

    @ViewBuilder
    private var extendedFormattingGroup: some View {
        toolButton(symbol: "function",      shortcut: "⌘M",
                   tip: "Inline math",    command: .insertSlashChoice(blockType: "math-display"))
        toolButton(symbol: "link",          shortcut: "⌘K",
                   tip: "Link (⌘K)",      command: .runCommand(name: "setLink",        argsJSON: emptyArgs))
    }

    @ViewBuilder
    private var insertGroup: some View {
        toolButton(symbol: "photo",         shortcut: "⌘⇧I",
                   tip: "Image",          command: .insertSlashChoice(blockType: "image"))
        toolButton(symbol: "tablecells",
                   tip: "Table 3×3",      command: .insertSlashChoice(blockType: "table-3x3"))
        toolButton(symbol: "flowchart",
                   tip: "Mermaid diagram", command: .insertSlashChoice(blockType: "mermaid"))
        toolButton(symbol: "minus",         shortcut: "⌘⇧R",
                   tip: "Divider",        command: .insertSlashChoice(blockType: "divider"))
    }

    @ViewBuilder
    private var structureGroup: some View {
        // H1...H6 cycle button — long-press surfaces the level picker;
        // single click toggles paragraph ↔ H1.
        toolButton(symbol: "h.square",      shortcut: "⌘1...6",
                   isActive: model.activeHeadingLevel != nil,
                   tip: model.activeHeadingLevel.map { "Heading \($0)" } ?? "Heading 1",
                   command: .insertSlashChoice(blockType: "heading-1"))
        toolButton(symbol: "text.quote",    shortcut: "⌘⇧.",
                   tip: "Quote",          command: .insertSlashChoice(blockType: "blockquote"))
        toolButton(symbol: "list.bullet",   shortcut: "⌘⇧8",
                   tip: "Bulleted list",  command: .insertSlashChoice(blockType: "bullet-list"))
        toolButton(symbol: "list.number",   shortcut: "⌘⇧7",
                   tip: "Numbered list",  command: .insertSlashChoice(blockType: "numbered-list"))
        toolButton(symbol: "checklist",     shortcut: "⌘⇧9",
                   tip: "Task list",      command: .insertSlashChoice(blockType: "task-list"))
    }

    // MARK: - Right cluster

    @ViewBuilder
    private var statsBadge: some View {
        Text("\(model.wordCount) words · \(model.characterCount) chars")
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .help("Word + character counts")
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            onSave()
        } label: {
            if model.isSaving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "tray.and.arrow.down")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .buttonStyle(.borderless)
        .keyboardShortcut("s", modifiers: .command)
        .tint(model.isDirty ? .accentColor : .secondary)
        .help(model.isDirty ? "Save (⌘S)" : "All changes saved")
        .disabled(model.isSaving)
        .frame(width: 28, height: 28)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func toolButton(
        symbol: String,
        shortcut: String? = nil,
        isActive: Bool = false,
        tip: String,
        command: EpdocEditorCommand
    ) -> some View {
        Button {
            model.dispatch(command)
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .help(tip + (shortcut.map { " (\($0))" } ?? ""))
        .accessibilityLabel(tip)
    }

    private var divider: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 0.5, height: 18)
            .padding(.horizontal, 2)
    }

    /// Convenience constant for commands that don't take args.
    private var emptyArgs: Data {
        "[]".data(using: .utf8) ?? Data()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("EpdocEditorToolbar — clean") {
    let model = EpdocEditorToolbarModel()
    model.wordCount = 142
    model.characterCount = 856
    return EpdocEditorToolbar(model: model)
        .frame(width: 920)
        .preferredColorScheme(.light)
}

#Preview("EpdocEditorToolbar — dirty + active marks") {
    let model = EpdocEditorToolbarModel()
    model.wordCount = 1240
    model.characterCount = 7_812
    model.isDirty = true
    model.isBoldActive = true
    model.activeHeadingLevel = 2
    return EpdocEditorToolbar(model: model)
        .frame(width: 920)
        .preferredColorScheme(.dark)
}
#endif
