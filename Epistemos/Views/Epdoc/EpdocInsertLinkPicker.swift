import SwiftUI

// MARK: - EpdocInsertLinkPicker
//
// Wave 7.17.b graph-aware "Insert link to…" picker. Replaces the
// vanilla Tiptap link command's URL prompt with a SwiftUI popover
// that hits the Halo Shadow backend (W8.4) so 3 chars surface
// semantically-related docs / chats / thoughts. Picking an entry
// inserts a `[[wikilink]]` so the W7.14 graph projector adds the
// edge on the next save.
//
// Backend contract: takes a `search` closure that returns
// `[EpdocLinkSuggestion]` for a query string. The host wires that
// closure to the W8.4 RealBackend.search(...). In tests we pass a
// stub that returns deterministic results.

public struct EpdocLinkSuggestion: Identifiable, Sendable, Hashable {
    public let id: String          // doc / chat / thought id
    public let title: String
    public let snippet: String     // pre-truncated body excerpt
    public let kind: Kind
    public let score: Double

    public enum Kind: Sendable, Hashable {
        case document
        case chat
        case thought
    }

    public init(id: String, title: String, snippet: String, kind: Kind, score: Double) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.kind = kind
        self.score = score
    }

    /// SF Symbol the picker shows next to each row.
    public var iconSymbol: String {
        switch kind {
        case .document: return "doc.text"
        case .chat:     return "bubble.left.and.bubble.right"
        case .thought:  return "bolt"
        }
    }

    /// Wikilink text inserted into the document body when picked.
    /// `[[<title>]]` is the canonical Obsidian/Logseq form the
    /// W7.14 EpdocGraphProjector wikilink scanner reads.
    public var wikilinkText: String {
        "[[\(title)]]"
    }
}

@MainActor
public struct EpdocInsertLinkPicker: View {

    /// Async search closure — wires into the W8.4 RealBackend in
    /// production; tests pass a deterministic stub.
    public let search: @Sendable @MainActor (String) async -> [EpdocLinkSuggestion]
    /// Fired when the user picks a suggestion. Host inserts the
    /// `[[wikilink]]` into the editor.
    public let onPick: @Sendable @MainActor (EpdocLinkSuggestion) -> Void
    /// Optional: insert a plain-URL link (the Tiptap default behaviour)
    /// when the user types a URL-shaped query.
    public let onInsertURL: @Sendable @MainActor (String) -> Void

    @State private var query: String = ""
    @State private var results: [EpdocLinkSuggestion] = []
    @State private var isSearching: Bool = false

    public init(
        search: @escaping @Sendable @MainActor (String) async -> [EpdocLinkSuggestion],
        onPick: @escaping @Sendable @MainActor (EpdocLinkSuggestion) -> Void,
        onInsertURL: @escaping @Sendable @MainActor (String) -> Void = { _ in }
    ) {
        self.search = search
        self.onPick = onPick
        self.onInsertURL = onInsertURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Link to a doc, chat, or thought…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        if EpdocInsertLinkPicker.looksLikeURL(query) {
                            onInsertURL(query)
                        }
                    }
                if isSearching {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if EpdocInsertLinkPicker.looksLikeURL(query) {
                Button {
                    onInsertURL(query)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text("Insert URL: \(query)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
            } else if results.isEmpty && !query.isEmpty && !isSearching {
                Text("No matches for \"\(query)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(results) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        .onChange(of: query) { _, newQuery in
            Task { @MainActor in
                guard !newQuery.isEmpty,
                      !EpdocInsertLinkPicker.looksLikeURL(newQuery) else {
                    results = []
                    return
                }
                isSearching = true
                results = await search(newQuery)
                isSearching = false
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ s: EpdocLinkSuggestion) -> some View {
        Button {
            onPick(s)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: s.iconSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(s.snippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    /// Quick URL-detection heuristic — used to switch the picker to
    /// "Insert URL" mode when the user pastes a link.
    static func looksLikeURL(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("http://")
            || lower.hasPrefix("https://")
            || lower.hasPrefix("file://")
            || (lower.contains(".") && !lower.contains(" ") && lower.count > 4 && lower.contains("/") == false && (lower.hasSuffix(".com") || lower.hasSuffix(".net") || lower.hasSuffix(".org") || lower.hasSuffix(".io") || lower.hasSuffix(".dev") || lower.hasSuffix(".app")))
    }
}

#if DEBUG
#Preview("Empty state") {
    EpdocInsertLinkPicker(
        search: { _ in [] },
        onPick: { _ in }
    )
    .padding()
}
#endif
