import SwiftUI
import SwiftData

// MARK: - KnowledgeCoreOutlinePreview
//
// KC cutover Slice 3 (step 3 — read path). The first SwiftUI surface driven by
// the KnowledgeCore projection: it reads a real vault page's outline through the
// on-demand content read API (KnowledgeCoreShadowRuntime.pageOutline ->
// graph_engine_kc_page_outline_json) and renders it indented by depth. This is
// deliberately separate from the zero-copy diff poller — content is materialized
// only here, on demand, not on the streaming hot path.
//
// Read-only + flag-gated (no runtime unless knowledgeCoreRuntimeV0). Proves the
// cutover read path end-to-end; binding the production Notes outline to it is the
// dev-cert Product-Run step.

@MainActor
struct KnowledgeCoreOutlinePreview: View {
    @Environment(\.modelContext) private var modelContext

    @State private var pages: [PageRef] = []
    @State private var index = 0
    @State private var rows: [KnowledgeCoreOutlineRow] = []
    @State private var isLoading = false
    @State private var didLoad = false

    private struct PageRef: Identifiable, Equatable {
        let id: String
        let title: String
    }

    private var runtimeStanding: Bool {
        AppBootstrap.shared?.knowledgeCoreRuntime != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !runtimeStanding {
                hint("KC runtime not running — enable EPISTEMOS_KNOWLEDGECORE_RUNTIME_V0 and reopen a vault.")
            } else if pages.isEmpty {
                hint("No vault pages found.")
            } else {
                pageBar
                outlineBody
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task { loadPagesIfNeeded() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.indent")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("KC outline preview")
                    .font(.system(size: 13, weight: .medium))
                Text("Renders a page from the KnowledgeCore projection (read-only)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var pageBar: some View {
        HStack(spacing: 8) {
            Button {
                cyclePage(-1)
            } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .disabled(pages.count < 2)
            Text(currentTitle)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                cyclePage(1)
            } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .disabled(pages.count < 2)
            Button {
                load()
            } label: {
                Label(isLoading ? "Reading…" : "Read", systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
    }

    @ViewBuilder
    private var outlineBody: some View {
        if isLoading {
            hint("Reading outline…")
        } else if didLoad && rows.isEmpty {
            hint("KnowledgeCore has no outline for this page.")
        } else if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(rows) { row in
                    Text(row.content.isEmpty ? "—" : row.content)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.leading, CGFloat(min(row.depth, 6)) * 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 2)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Data

    private var currentTitle: String {
        guard pages.indices.contains(index) else { return "—" }
        return pages[index].title
    }

    private func loadPagesIfNeeded() {
        guard pages.isEmpty, runtimeStanding else { return }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        pages = fetched.prefix(50).map { PageRef(id: $0.id, title: $0.title.isEmpty ? $0.id : $0.title) }
        if !pages.isEmpty { load() }
    }

    private func cyclePage(_ delta: Int) {
        guard !pages.isEmpty else { return }
        index = (index + delta + pages.count) % pages.count
        load()
    }

    private func load() {
        guard !isLoading,
              pages.indices.contains(index),
              let runtime = AppBootstrap.shared?.knowledgeCoreRuntime else { return }
        let pageId = pages[index].id
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            rows = await runtime.pageOutline(pageId: pageId)
            didLoad = true
        }
    }
}
