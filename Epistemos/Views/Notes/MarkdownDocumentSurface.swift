import AppKit
import SwiftUI

struct MarkdownDocumentSurface: View {
    let pageId: String
    let title: String
    let markdown: String
    let theme: EpistemosTheme
    let saveMarkdown: @Sendable @MainActor (String) -> Void
    let surfaceToolbarAccessory: AnyView?

    init(
        pageId: String,
        title: String,
        markdown: String,
        theme: EpistemosTheme,
        saveMarkdown: @escaping @Sendable @MainActor (String) -> Void,
        surfaceToolbarAccessory: AnyView? = nil
    ) {
        self.pageId = pageId
        self.title = title
        self.markdown = markdown
        self.theme = theme
        self.saveMarkdown = saveMarkdown
        self.surfaceToolbarAccessory = surfaceToolbarAccessory
    }

    @State private var coordinator = MarkdownDocumentSurfaceCoordinator()

    var body: some View {
        EpdocEditorChromeView(
            controller: coordinator.controller,
            surfaceToolbarAccessory: surfaceToolbarAccessory
        )
            .onAppear {
                configureCoordinator()
            }
            .onChange(of: markdown) { _, _ in
                configureCoordinator()
            }
            .onChange(of: title) { _, newTitle in
                coordinator.updateTitle(newTitle)
            }
            .onDisappear {
                coordinator.flushPendingMarkdown()
            }
    }

    @MainActor
    private func configureCoordinator() {
        coordinator.configure(
            pageId: pageId,
            title: title,
            markdown: markdown,
            theme: theme,
            saveMarkdown: saveMarkdown
        )
    }
}

@MainActor
@Observable
private final class MarkdownDocumentSurfaceCoordinator {
    let controller = EpdocEditorChromeController()
    private var configuredPageId: String?
    private var latestMarkdown: String = ""
    private var lastFlushedMarkdown: String = ""
    private var saveTask: Task<Void, Never>?
    private var saveMarkdown: (@Sendable @MainActor (String) -> Void)?

    func configure(
        pageId: String,
        title: String,
        markdown: String,
        theme: EpistemosTheme,
        saveMarkdown: @escaping @Sendable @MainActor (String) -> Void
    ) {
        controller.theme = theme
        self.saveMarkdown = saveMarkdown
        controller.onMarkdownChanged = { [weak self] markdown in
            self?.scheduleMarkdownSave(markdown)
        }
        controller.onSave = { [weak self] in
            self?.flushPendingMarkdown()
            self?.controller.toolbarModel.isDirty = false
        }
        controller.onShowProjectionInfo = {
            MarkdownDocumentProjectionInfoPresenter.present()
        }

        guard configuredPageId != pageId else {
            updateTitle(title)
            guard markdown != latestMarkdown,
                  latestMarkdown == lastFlushedMarkdown,
                  !controller.toolbarModel.isDirty else {
                return
            }
            latestMarkdown = markdown
            lastFlushedMarkdown = markdown
            controller.loadInitialContent(
                Self.emptyDocumentJSON,
                title: title,
                markdownSource: markdown
            )
            return
        }

        configuredPageId = pageId
        latestMarkdown = markdown
        lastFlushedMarkdown = markdown
        controller.loadInitialContent(
            Self.emptyDocumentJSON,
            title: title,
            markdownSource: markdown
        )
    }

    func updateTitle(_ title: String) {
        controller.documentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title
    }

    func flushPendingMarkdown() {
        saveTask?.cancel()
        saveTask = nil
        guard latestMarkdown != lastFlushedMarkdown else { return }
        saveMarkdown?(latestMarkdown)
        lastFlushedMarkdown = latestMarkdown
    }

    private func scheduleMarkdownSave(_ markdown: String) {
        latestMarkdown = markdown
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            guard markdown != self.lastFlushedMarkdown else { return }
            self.saveMarkdown?(markdown)
            self.lastFlushedMarkdown = markdown
            self.controller.toolbarModel.isDirty = false
        }
    }

    private static let emptyDocumentJSON = Data(
        #"{"type":"doc","content":[{"type":"paragraph"}]}"#.utf8
    )
}

@MainActor
private enum MarkdownDocumentProjectionInfoPresenter {
    static func present() {
        let alert = NSAlert()
        alert.messageText = "Markdown Document Surface"
        alert.informativeText = """
        This Document view is another editor surface for the same Markdown note. It projects the .md body into rich blocks for editing, then saves Markdown back to the vault path used by Prose, Preview, and Source.

        The projection does not turn this note into a separate package.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
