import SwiftUI

// MARK: - Table of Contents Item

struct TOCItem: Identifiable, Equatable {
    let id = UUID()
    let level: Int          // 1-6 for H1-H6
    let title: String
    let charOffset: Int     // Character offset in the document
    let kind: TOCKind

    enum TOCKind: Equatable {
        case heading
        case citation
        case source
    }
}

// MARK: - Table of Contents Parser

enum TOCParser {

    /// Extract headings (H1-H5), citations, and source links from markdown text.
    static func parse(_ markdown: String) -> [TOCItem] {
        var items: [TOCItem] = []
        var charOffset = 0

        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Headings: # through #####
            if let level = headingLevel(trimmed), level <= 5 {
                let title = headingTitle(trimmed, level: level)
                if !title.isEmpty {
                    items.append(TOCItem(level: level, title: title, charOffset: charOffset, kind: .heading))
                }
            }

            // Blockquote citations: lines starting with >
            if trimmed.hasPrefix("> ") {
                let quote = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !quote.isEmpty && quote.count > 10 {
                    let preview = String(quote.prefix(50)) + (quote.count > 50 ? "…" : "")
                    items.append(TOCItem(level: 6, title: preview, charOffset: charOffset, kind: .citation))
                }
            }

            // Markdown links as sources: [text](url) where url starts with http
            if trimmed.contains("](http") {
                let links = extractLinks(from: trimmed)
                for link in links {
                    items.append(TOCItem(level: 6, title: link, charOffset: charOffset, kind: .source))
                }
            }

            charOffset += line.utf16.count + 1 // +1 for newline
        }

        return items
    }

    private static func headingLevel(_ line: String) -> Int? {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 }
            else if ch == " " && count > 0 { return count }
            else { return nil }
        }
        return nil
    }

    private static func headingTitle(_ line: String, level: Int) -> String {
        let dropped = String(line.dropFirst(level + 1)) // Drop "## " etc.
        return dropped
            .replacingOccurrences(of: "\\*\\*|\\*|`|\\[|\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractLinks(from line: String) -> [String] {
        var results: [String] = []
        let pattern = "\\[([^\\]]+)\\]\\((https?://[^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return results }
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                let title = nsLine.substring(with: match.range(at: 1))
                results.append(title)
            }
        }
        return results
    }
}

// MARK: - NoteTableOfContents View
// Hover-reveal floating panel on the left edge (DeepSeek-style).
// Collapsed: segmented horizontal dashes. Hover: glass card with heading list.

struct NoteTableOfContents: View {
    let markdown: String
    let isDark: Bool
    let onNavigate: (Int) -> Void

    @Environment(UIState.self) private var ui
    @State private var items: [TOCItem] = []
    @State private var parseTask: Task<Void, Never>?
    @State private var isHovering = false
    @State private var hoveredItemId: UUID?

    private var headings: [TOCItem] {
        items.filter { $0.kind == .heading }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isHovering {
                expandedPanel
            } else {
                collapsedDashes
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.arrow.push()
            } else {
                NSCursor.pop()
            }
        }
        .onChange(of: markdown) { _, newBody in
            debounceParseBody(newBody)
        }
        .task {
            items = TOCParser.parse(markdown)
        }
    }

    // MARK: - Expanded Panel

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(headings) { item in
                let isItemHovered = hoveredItemId == item.id

                Button {
                    onNavigate(item.charOffset)
                } label: {
                    HStack(spacing: 0) {
                        Text(item.title)
                            .font(.system(size: 12, weight: item.level <= 2 ? .medium : .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(isItemHovered ? .white : .primary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .padding(.leading, CGFloat(item.level - 1) * 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if isItemHovered {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ui.theme.accent.opacity(0.7))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { h in hoveredItemId = h ? item.id : nil }
            }

            if headings.isEmpty {
                Text("No headings")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .padding(6)
        .frame(width: 240)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
    }

    // MARK: - Collapsed Dashes

    private var collapsedDashes: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(headings.prefix(10).enumerated()), id: \.element.id) { _, item in
                RoundedRectangle(cornerRadius: 1)
                    .fill(ui.theme.accent.opacity(item.level == 1 ? 0.9 : 0.5))
                    .frame(width: dashWidth(for: item.level), height: 2)
            }
            if headings.count > 10 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ui.theme.accent.opacity(0.3))
                    .frame(width: 6, height: 2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 3)
        .transition(.opacity)
    }

    private func dashWidth(for level: Int) -> CGFloat {
        switch level {
        case 1: return 16
        case 2: return 12
        case 3: return 9
        default: return 6
        }
    }

    private func debounceParseBody(_ text: String) {
        parseTask?.cancel()
        parseTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let parsed = TOCParser.parse(text)
            items = parsed
        }
    }
}
