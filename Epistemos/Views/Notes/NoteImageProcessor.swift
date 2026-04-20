import AppKit
import ImageIO
import Vision

enum NoteImageProcessor {
    nonisolated static let maxDisplayWidth: CGFloat = 600

    struct DisplayImage: Sendable {
        let cgImage: CGImage
        let displaySize: CGSize
    }

    nonisolated static func loadDisplayImage(from url: URL) async -> DisplayImage? {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let originalSize = sourceImageSize(source)
                else { return nil }

                let displaySize = scaledSize(for: originalSize, maxWidth: maxDisplayWidth)
                let cgImage: CGImage?
                if originalSize.width > maxDisplayWidth {
                    let maxDimension = max(displaySize.width, displaySize.height)
                    let maxPixelSize = maxDimension.isFinite
                        ? Int(ceil(maxDimension))
                        : Int(maxDisplayWidth)
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    ]
                    cgImage = CGImageSourceCreateThumbnailAtIndex(
                        source,
                        0,
                        options as CFDictionary
                    )
                } else {
                    cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                }

                guard let cgImage else { return nil }
                return DisplayImage(cgImage: cgImage, displaySize: displaySize)
            }
        }.value
    }

    nonisolated static func extractText(from url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                else { return nil }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    Log.notes.error(
                        "NoteImageProcessor: OCR failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }

                let extractedText = request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let extractedText, !extractedText.isEmpty else { return nil }
                return extractedText
            }
        }.value
    }

    private nonisolated static func sourceImageSize(_ source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else { return nil }

        let size = CGSize(width: width.doubleValue, height: height.doubleValue)
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private nonisolated static func scaledSize(
        for originalSize: CGSize,
        maxWidth: CGFloat
    ) -> CGSize {
        guard originalSize.width > maxWidth else { return originalSize }
        let scale = maxWidth / originalSize.width
        return CGSize(width: maxWidth, height: originalSize.height * scale)
    }
}
