import AppKit
import Quartz
import SwiftUI

nonisolated enum FilePreviewURLPolicy {
    static func isReadableRegularFileURL(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard url.isFileURL,
              (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else {
            return false
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: url.path) else {
            return false
        }
        return true
    }
}

final class FilePreviewItem: NSObject, QLPreviewItem {
    let url: URL
    private let title: String?

    init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title
    }

    var previewItemURL: URL? { url }
    var previewItemTitle: String? { title ?? url.lastPathComponent }
}

@MainActor
final class FilePreviewController: NSObject, @MainActor QLPreviewPanelDataSource, @MainActor QLPreviewPanelDelegate {
    static let shared = FilePreviewController()

    private var previewItems: [FilePreviewItem] = []

    private override init() {
        super.init()
    }

    func present(url: URL, title: String? = nil) {
        present(items: [FilePreviewItem(url: url, title: title)])
    }

    func present(urls: [URL]) {
        present(items: urls.map { FilePreviewItem(url: $0) })
    }

    func present(items: [FilePreviewItem]) {
        previewItems = items.filter { Self.isPreviewableURL($0.url) }
        guard !previewItems.isEmpty,
              let panel = QLPreviewPanel.shared() else {
            return
        }

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    static func isPreviewableURL(_ url: URL) -> Bool {
        FilePreviewURLPolicy.isReadableRegularFileURL(url)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewItems.indices.contains(index) else { return nil }
        return previewItems[index]
    }

    func previewPanelDidClose(_ panel: QLPreviewPanel!) {
        previewItems = []
    }
}

struct FilePreviewButton<LabelContent: View>: View {
    let url: URL
    let title: String?
    @ViewBuilder let label: () -> LabelContent

    init(
        url: URL,
        title: String? = nil,
        @ViewBuilder label: @escaping () -> LabelContent
    ) {
        self.url = url
        self.title = title
        self.label = label
    }

    var body: some View {
        Button {
            FilePreviewController.shared.present(url: url, title: title)
        } label: {
            label()
        }
        .disabled(!FilePreviewController.isPreviewableURL(url))
        .help("Quick Look")
    }
}

extension FilePreviewButton where LabelContent == Label<Text, Image> {
    init(url: URL, title: String? = nil) {
        self.init(url: url, title: title) {
            Label("Quick Look", systemImage: "eye")
        }
    }
}

private struct FilePreviewModifier: ViewModifier {
    @Binding var previewURL: URL?

    func body(content: Content) -> some View {
        content
            .onChange(of: previewURL) { _, newURL in
                guard let newURL else { return }
                FilePreviewController.shared.present(url: newURL)
                previewURL = nil
            }
    }
}

extension View {
    func filePreview(_ previewURL: Binding<URL?>) -> some View {
        modifier(FilePreviewModifier(previewURL: previewURL))
    }
}
