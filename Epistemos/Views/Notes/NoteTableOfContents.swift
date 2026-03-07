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
// Hover-reveal floating panel on the left edge (mirrors wikilink breadcrumb pattern).
// Collapsed: vertical dots. Hover: glass card with heading list.

struct NoteTableOfContents: View {
    let markdown: String
    let isDark: Bool
    let onNavigate: (Int) -> Void

    @Environment(UIState.self) private var ui
    @State private var items: [TOCItem] = []
    @State private var parseTask: Task<Void, Never>?
    @State private var isHovering = false

    private var headings: [TOCItem] {
        items.filter { $0.kind == .heading }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isHovering {
                // Expanded: heading list
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(headings) { item in
                        Button {
                            onNavigate(item.charOffset)
                        } label: {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(levelColor(item.level).opacity(0.5))
                                    .frame(width: 2, height: 12)

                                Text(item.title)
                                    .font(.system(size: fontSize(for: item.level),
                                                  weight: item.level <= 2 ? .medium : .regular))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .padding(.leading, CGFloat(item.level - 1) * 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    if headings.isEmpty {
                        Text("No headings")
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                }
                .padding(8)
                .frame(width: 220)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
            } else {
                // Collapsed: dot stack
                VStack(spacing: 6) {
                    ForEach(headings.prefix(8)) { item in
                        Circle()
                            .fill(ui.theme.accent.opacity(item.level == 1 ? 0.8 : 0.3))
                            .frame(
                                width: item.level == 1 ? 5 : 3.5,
                                height: item.level == 1 ? 5 : 3.5
                            )
                    }
                    if headings.count > 8 {
                        Circle()
                            .fill(ui.theme.accent.opacity(0.2))
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .shadow(color: ui.theme.accent.opacity(0.4), radius: 6)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: isHovering)
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

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 12
        case 2: return 11.5
        case 3: return 11
        default: return 10.5
        }
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1: return .blue
        case 2: return .cyan
        case 3: return .teal
        default: return .gray
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
