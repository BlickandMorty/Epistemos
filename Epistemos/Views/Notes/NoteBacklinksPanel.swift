import SwiftUI
import SwiftData

// MARK: - Backlinks Popover
// Native popover content showing notes that link TO the current note via [[wikilinks]].

struct NoteBacklinksPopover: View {
    let pageTitle: String
    let onNavigate: (String) -> Void // pageId

    @Environment(\.modelContext) private var modelContext
    @State private var backlinks: [(id: String, title: String)] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(backlinks.count) Backlink\(backlinks.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                ForEach(backlinks, id: \.id) { link in
                    Button {
                        onNavigate(link.id)
                    } label: {
                        Text(link.title.isEmpty ? "Untitled" : link.title)
                            .font(.system(size: 12, weight: .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if backlinks.isEmpty {
                    Text("No backlinks found")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            .padding(6)
        }
        .frame(width: 240).frame(maxHeight: 350)
        .task { await scanBacklinks() }
    }

    private func scanBacklinks() async {
        guard !pageTitle.isEmpty else { return }
        let target = "[[\(pageTitle)]]"
        let titleToFind = pageTitle

        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.isArchived == false }
        )
        guard let allPages = try? modelContext.fetch(descriptor) else { return }

        var results: [(id: String, title: String)] = []
        for page in allPages where page.title != titleToFind {
            let body = page.loadBody()
            if body.contains(target) {
                results.append((id: page.id, title: page.title))
            }
        }
        results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        if !Task.isCancelled {
            backlinks = results
        }
    }
}
