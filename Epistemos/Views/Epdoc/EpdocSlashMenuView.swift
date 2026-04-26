import SwiftUI

// MARK: - EpdocSlashMenuView
//
// Wave 7.17.b SwiftUI slash-menu picker. Responds to the JS-side
// `requestSlashMenu` bridge message — when the user types `/` in
// the Tiptap WKWebView, the JS Suggestion plugin fires
// `EpdocBridgeMessage.requestSlashMenu(query, anchor)`; the host
// constructs this view + positions it at the anchor rect.
//
// On pick → host fires `EpdocEditorCommand.insertSlashChoice(blockType:)`
// back to the JS side, which runs the matching Tiptap command.
//
// Per the W7.17.b plan: this is one of the EXCEED-Alexandrie features
// — Alexandrie's editor has NO slash menu. The catalogue mirrors
// `js-editor/src/extensions/slash-menu.ts::DEFAULT_SLASH_ITEMS` so
// both surfaces stay in sync.

/// One slash-menu entry. Mirrors `SlashMenuItem` in
/// `js-editor/src/extensions/slash-menu.ts`.
public struct EpdocSlashMenuItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let label: String
    public let symbol: String        // SF Symbol name
    public let hint: String?         // optional shortcut hint (cosmetic)

    public init(id: String, label: String, symbol: String, hint: String? = nil) {
        self.id = id
        self.label = label
        self.symbol = symbol
        self.hint = hint
    }
}

public extension EpdocSlashMenuItem {
    /// Default catalogue — mirrors `DEFAULT_SLASH_ITEMS` in the JS
    /// slash-menu extension byte-for-byte (id field is the contract).
    static let defaultCatalogue: [EpdocSlashMenuItem] = [
        .init(id: "heading-1",      label: "Heading 1",        symbol: "h.square",                          hint: "⌘1"),
        .init(id: "heading-2",      label: "Heading 2",        symbol: "h.square",                          hint: "⌘2"),
        .init(id: "heading-3",      label: "Heading 3",        symbol: "h.square",                          hint: "⌘3"),
        .init(id: "bullet-list",    label: "Bulleted list",    symbol: "list.bullet",                       hint: "⌘⇧8"),
        .init(id: "numbered-list",  label: "Numbered list",    symbol: "list.number",                       hint: "⌘⇧7"),
        .init(id: "task-list",      label: "Task list",        symbol: "checklist",                         hint: "⌘⇧9"),
        .init(id: "blockquote",     label: "Quote",            symbol: "text.quote",                        hint: "⌘⇧."),
        .init(id: "code-block",     label: "Code block",       symbol: "curlybraces",                       hint: "⌘⇧C"),
        .init(id: "math-display",   label: "Math (block)",     symbol: "function"),
        .init(id: "mermaid",        label: "Mermaid diagram",  symbol: "flowchart"),
        .init(id: "callout-tip",    label: "Callout — Tip",      symbol: "lightbulb"),
        .init(id: "callout-warning",label: "Callout — Warning",  symbol: "exclamationmark.triangle"),
        .init(id: "callout-danger", label: "Callout — Danger",   symbol: "octagon"),
        .init(id: "table-3x3",      label: "Table 3×3",        symbol: "tablecells"),
        .init(id: "divider",        label: "Divider",          symbol: "minus",                             hint: "⌘⇧R"),
    ]

    /// Filter by case-insensitive prefix on the label OR id.
    static func matching(prefix: String, in catalogue: [EpdocSlashMenuItem] = defaultCatalogue) -> [EpdocSlashMenuItem] {
        if prefix.isEmpty { return catalogue }
        let needle = prefix.lowercased()
        return catalogue.filter { item in
            item.label.lowercased().contains(needle) || item.id.contains(needle)
        }
    }
}

/// Slash-menu picker panel. Position via the host's frame overlay;
/// this view doesn't manage its own placement.
@MainActor
public struct EpdocSlashMenuView: View {

    public let query: String
    public let onPick: @Sendable @MainActor (EpdocSlashMenuItem) -> Void
    public let onDismiss: @Sendable @MainActor () -> Void

    @State private var selectedIndex: Int = 0

    public init(
        query: String,
        onPick: @escaping @Sendable @MainActor (EpdocSlashMenuItem) -> Void,
        onDismiss: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.query = query
        self.onPick = onPick
        self.onDismiss = onDismiss
    }

    private var matches: [EpdocSlashMenuItem] {
        EpdocSlashMenuItem.matching(prefix: query)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if matches.isEmpty {
                Text("No matches for /\(query)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(Array(matches.enumerated()), id: \.element.id) { idx, item in
                    row(item, isSelected: idx == selectedIndex)
                        .onTapGesture { onPick(item) }
                        .onHover { hovered in
                            if hovered { selectedIndex = idx }
                        }
                }
            }
        }
        .frame(width: 280)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        .onChange(of: query) { _, _ in
            // Reset selection when the query changes so the user
            // doesn't see a stale highlight.
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if !matches.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !matches.isEmpty {
                selectedIndex = min(matches.count - 1, selectedIndex + 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if matches.indices.contains(selectedIndex) {
                onPick(matches[selectedIndex])
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    @ViewBuilder
    private func row(_ item: EpdocSlashMenuItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(isSelected ? .white : .primary)
            Text(item.label)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
            if let hint = item.hint {
                Text(hint)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
    }
}

#if DEBUG
#Preview("Empty query — full catalogue") {
    EpdocSlashMenuView(query: "", onPick: { _ in }, onDismiss: { })
        .frame(width: 320, height: 400)
        .padding()
}

#Preview("Filtered — `head`") {
    EpdocSlashMenuView(query: "head", onPick: { _ in }, onDismiss: { })
        .frame(width: 320, height: 200)
        .padding()
}

#Preview("No matches") {
    EpdocSlashMenuView(query: "zzz", onPick: { _ in }, onDismiss: { })
        .frame(width: 320, height: 100)
        .padding()
}
#endif
