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

struct NoteTableOfContents: View {
    let markdown: String
    let isDark: Bool
    let onNavigate: (Int) -> Void  // charOffset to scroll to

    @State private var items: [TOCItem] = []
    @State private var parseTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Contents", systemImage: "list.bullet.indent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if items.isEmpty {
                Text("No headings found")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(items) { item in
                            tocRow(item)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 220)
        .background(isDark ? Color(white: 0.14) : Color(white: 0.96))
        .onChange(of: markdown) { _, newBody in
            debounceParseBody(newBody)
        }
        .task {
            items = TOCParser.parse(markdown)
        }
    }

    @ViewBuilder
    private func tocRow(_ item: TOCItem) -> some View {
        Button {
            onNavigate(item.charOffset)
        } label: {
            HStack(spacing: 6) {
                if item.kind == .citation {
                    Image(systemName: "text.quote")
                        .font(.system(size: 8))
                        .foregroundStyle(.purple.opacity(0.7))
                } else if item.kind == .source {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundStyle(.green.opacity(0.7))
                }

                Text(item.title)
                    .font(.system(size: item.kind == .heading ? fontSize(for: item.level) : 10))
                    .fontWeight(item.level <= 2 ? .medium : .regular)
                    .foregroundStyle(item.kind == .heading ? .primary : .secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.leading, indentation(for: item))
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 12
        case 2: return 11.5
        case 3: return 11
        default: return 10.5
        }
    }

    private func indentation(for item: TOCItem) -> CGFloat {
        switch item.kind {
        case .heading:
            return 12 + CGFloat(item.level - 1) * 12
        case .citation, .source:
            return 24
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
