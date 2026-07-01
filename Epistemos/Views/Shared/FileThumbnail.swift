import AppKit
import QuickLookThumbnailing
import SwiftUI

enum FileThumbnailer {
    static let maxThumbnailDimension: CGFloat = 2_048
    static let maxThumbnailScale: CGFloat = 4

    static func thumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage? {
        guard FilePreviewURLPolicy.isReadableRegularFileURL(url),
              let validSize = validatedSize(size),
              isValidScale(scale) else {
            return nil
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: validSize,
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

    static func validatedSize(_ size: CGSize) -> CGSize? {
        guard isValidDimension(size.width),
              isValidDimension(size.height) else {
            return nil
        }
        return size
    }

    private static func isValidDimension(_ dimension: CGFloat) -> Bool {
        dimension.isFinite && dimension > 0 && dimension <= maxThumbnailDimension
    }

    private static func isValidScale(_ scale: CGFloat) -> Bool {
        scale.isFinite && scale > 0 && scale <= maxThumbnailScale
    }
}

struct FileThumbnailView: View {
    @Environment(UIState.self) private var ui

    let url: URL
    var size: CGSize
    var fallbackSystemImage = "doc"

    @State private var image: NSImage?

    private var fallbackTint: Color {
        ui.theme.surfaceVariant(.other).resolved.mutedForeground.color
    }

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
                    .foregroundStyle(fallbackTint)
                    .padding(2)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .task(id: thumbnailIdentity) {
            await loadThumbnail()
        }
    }

    private var displaySize: CGSize {
        FileThumbnailer.validatedSize(size) ?? CGSize(width: 32, height: 32)
    }

    private var thumbnailIdentity: String {
        "\(url.path)|\(Int(displaySize.width))x\(Int(displaySize.height))"
    }

    @MainActor
    private func loadThumbnail() async {
        image = nil
        guard let validSize = FileThumbnailer.validatedSize(size) else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        image = await FileThumbnailer.thumbnail(for: url, size: validSize, scale: scale)
    }
}
