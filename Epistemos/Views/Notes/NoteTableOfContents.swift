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
}

// MARK: - NoteOutlineOverlay
// Hover-triggered glass panel on the right edge showing document outline.

struct NoteOutlineOverlay: View {
    let markdown: String
    let theme: EpistemosTheme
    let onNavigate: (Int) -> Void

    @State private var items: [TOCItem] = []
    @State private var isHovering = false

    private var headings: [TOCItem] {
        items.filter { $0.kind == .heading }
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .trailing) {
                // Invisible hover trigger strip along right edge
                Color.clear
                    .frame(width: 16)
                    .contentShape(Rectangle())

                // Glass outline panel
                if isHovering && !headings.isEmpty {
                    outlinePanel
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .task { items = TOCParser.parse(markdown) }
        .onChange(of: markdown) { items = TOCParser.parse(markdown) }
    }

    private var outlinePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10, weight: .semibold))
                Text("Outline")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(headings) { item in
                        Button {
                            onNavigate(item.charOffset)
                        } label: {
                            Text(item.title)
                                .font(.system(size: tocFontSize(for: item.level),
                                              weight: item.level <= 2 ? .medium : .regular))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                                .padding(.leading, CGFloat(item.level - 1) * 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 200)
        .frame(maxHeight: 400)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .padding(.trailing, 8)
        .padding(.vertical, 40)
    }

    private func tocFontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: 13
        case 2: 12
        case 3: 11
        default: 10.5
        }
    }
}
