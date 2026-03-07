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
// Left sidebar, DeepSeek-style: clean, minimal, hover-highlighted rows.

struct NoteTableOfContents: View {
    let markdown: String
    let isDark: Bool
    let onNavigate: (Int) -> Void

    @State private var items: [TOCItem] = []
    @State private var parseTask: Task<Void, Never>?
    @State private var hoveredItemId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("Contents")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(items.filter { $0.kind == .heading }.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 20))
                        .foregroundStyle(.quaternary)
                    Text("No headings")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(items) { item in
                            tocRow(item)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(width: 230)
        .background {
            if isDark {
                Color(white: 0.11)
            } else {
                Color(white: 0.975)
            }
        }
        .onChange(of: markdown) { _, newBody in
            debounceParseBody(newBody)
        }
        .task {
            items = TOCParser.parse(markdown)
        }
    }

    @ViewBuilder
    private func tocRow(_ item: TOCItem) -> some View {
        let isHovered = hoveredItemId == item.id

        Button {
            onNavigate(item.charOffset)
        } label: {
            HStack(spacing: 6) {
                // Level indicator bar for headings
                if item.kind == .heading {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(levelColor(item.level).opacity(isHovered ? 0.8 : 0.35))
                        .frame(width: 2, height: fontSize(for: item.level) + 4)
                } else if item.kind == .citation {
                    Image(systemName: "text.quote")
                        .font(.system(size: 8))
                        .foregroundStyle(.purple.opacity(0.6))
                } else if item.kind == .source {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundStyle(.green.opacity(0.6))
                }

                Text(item.title)
                    .font(.system(size: fontSize(for: item.level)))
                    .fontWeight(item.level == 1 ? .semibold : item.level == 2 ? .medium : .regular)
                    .foregroundStyle(isHovered ? .primary : (item.kind == .heading ? .secondary : .tertiary))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.leading, indentation(for: item))
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered
                          ? (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                          : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItemId = hovering ? item.id : nil
        }
    }

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 12.5
        case 2: return 11.5
        case 3: return 11
        case 4, 5: return 10.5
        default: return 10
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

    private func indentation(for item: TOCItem) -> CGFloat {
        switch item.kind {
        case .heading:
            return 8 + CGFloat(item.level - 1) * 10
        case .citation, .source:
            return 18
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
