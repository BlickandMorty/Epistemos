import Darwin
import AppKit
import Quartz
import SwiftUI

nonisolated enum FilePreviewURLPolicy {
    static let maxPreviewFileBytes = 512 * 1024 * 1024

    static func isReadableRegularFileURL(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard url.isFileURL,
              (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil,
              fileManager.isReadableFile(atPath: url.path) else {
            return false
        }

        return descriptorConfirmsReadableRegularFile(url)
    }

    private static func descriptorConfirmsReadableRegularFile(_ url: URL) -> Bool {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return false
        }
        defer { close(fd) }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            return false
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            return false
        }
        guard fileStatus.st_nlink <= 1 else {
            return false
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxPreviewFileBytes) else {
            return false
        }
        return true
    }
}

nonisolated enum FilePreviewDisplayBounds {
    static let maxPreviewItems = 50
    static let maxTitleCharacters = 160

    static func title(_ value: String) -> String {
        let bounded = String(value.prefix(maxTitleCharacters + 32))
        let trimmed = normalizedDisplayText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxTitleCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxTitleCharacters - 3)) + "..."
    }

    static func normalizedDisplayText(_ value: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    normalized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        return normalized
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
    var previewItemTitle: String? {
        FilePreviewDisplayBounds.title(title ?? url.lastPathComponent)
    }
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
        present(items: urls
            .prefix(FilePreviewDisplayBounds.maxPreviewItems)
            .map { FilePreviewItem(url: $0) })
    }

    func present(items: [FilePreviewItem]) {
        previewItems = items
            .prefix(FilePreviewDisplayBounds.maxPreviewItems)
            .filter { Self.isPreviewableURL($0.url) }
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

struct FilePreviewButton: View {
    let url: URL
    let title: String?
    var buttonTitle: String?
    var systemImage: String

    init(
        url: URL,
        title: String? = nil,
        buttonTitle: String? = "Quick Look",
        systemImage: String = "eye"
    ) {
        self.url = url
        self.title = title
        self.buttonTitle = buttonTitle
        self.systemImage = systemImage
    }

    var body: some View {
        ToolbarCapsuleButton(
            title: buttonTitle,
            systemImage: systemImage,
            role: .toolbarUtility,
            chromePolicy: .bareUntilPressed,
            helpText: "Quick Look",
            accessibilityLabel: "Quick Look"
        ) {
            FilePreviewController.shared.present(url: url, title: title)
        }
        .disabled(!FilePreviewController.isPreviewableURL(url))
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
