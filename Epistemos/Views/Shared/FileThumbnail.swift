import AppKit
import QuickLookThumbnailing
import SwiftUI

enum FileThumbnailer {
    static func thumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage? {
        guard FilePreviewURLPolicy.isReadableRegularFileURL(url),
              size.width > 0,
              size.height > 0,
              scale.isFinite,
              scale > 0 else {
            return nil
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            return nil
        }
    }
}

struct FileThumbnailView: View {
    let url: URL
    var size: CGSize
    var fallbackSystemImage = "doc"

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(2)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: thumbnailIdentity) {
            await loadThumbnail()
        }
    }

    private var thumbnailIdentity: String {
        "\(url.path)|\(Int(size.width))x\(Int(size.height))"
    }

    @MainActor
    private func loadThumbnail() async {
        image = nil
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        image = await FileThumbnailer.thumbnail(for: url, size: size, scale: scale)
    }
}
