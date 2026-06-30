import AppKit
import SwiftUI

nonisolated enum LiveTextImageAnalysisPolicy {
    static let maxPointDimension: CGFloat = 8_192
    static let maxPixelDimension = 8_192
    static let maxPixelCount = 48_000_000

    static func isEligibleForAnalysis(_ image: NSImage?) -> Bool {
        guard let image,
              isValidDimension(image.size.width),
              isValidDimension(image.size.height) else {
            return false
        }

        guard !image.representations.isEmpty else {
            return false
        }

        return image.representations.allSatisfy { representation in
            guard isValidDimension(representation.size.width),
                  isValidDimension(representation.size.height) else {
                return false
            }

            let pixelWidth = representation.pixelsWide
            let pixelHeight = representation.pixelsHigh
            guard pixelWidth > 0 || pixelHeight > 0 else {
                return true
            }

            guard pixelWidth > 0,
                  pixelHeight > 0,
                  pixelWidth <= maxPixelDimension,
                  pixelHeight <= maxPixelDimension else {
                return false
            }

            return pixelWidth <= maxPixelCount / pixelHeight
        }
    }

    private static func isValidDimension(_ dimension: CGFloat) -> Bool {
        dimension.isFinite && dimension > 0 && dimension <= maxPointDimension
    }
}

#if canImport(VisionKit)
import VisionKit

struct LiveTextImageView: NSViewRepresentable {
    let image: NSImage?
    var imageScaling: NSImageScaling = .scaleProportionallyUpOrDown
    var onTextRecognized: (String) -> Void = { _ in }

    func makeNSView(context: Context) -> LiveTextImageContainerView {
        let view = LiveTextImageContainerView()
        view.imageView.imageScaling = imageScaling
        view.imageView.image = image
        context.coordinator.analyze(image: image, overlay: view.overlay)
        return view
    }

    func updateNSView(_ nsView: LiveTextImageContainerView, context: Context) {
        context.coordinator.onTextRecognized = onTextRecognized
        nsView.imageView.imageScaling = imageScaling
        nsView.imageView.image = image
        context.coordinator.analyze(image: image, overlay: nsView.overlay)
    }

    static func dismantleNSView(_ nsView: LiveTextImageContainerView, coordinator: Coordinator) {
        coordinator.cancel()
        nsView.overlay.analysis = nil
        nsView.overlay.trackingImageView = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized)
    }

    @MainActor
    final class Coordinator {
        var onTextRecognized: (String) -> Void
        private var analysisTask: Task<Void, Never>?
        private var currentImage: NSImage?

        init(onTextRecognized: @escaping (String) -> Void) {
            self.onTextRecognized = onTextRecognized
        }

        func analyze(image: NSImage?, overlay: ImageAnalysisOverlayView) {
            if let currentImage,
               let image,
               currentImage === image {
                return
            }
            if currentImage == nil, image == nil {
                return
            }

            currentImage = image
            analysisTask?.cancel()

            guard ImageAnalyzer.isSupported,
                  let image,
                  LiveTextImageAnalysisPolicy.isEligibleForAnalysis(image) else {
                overlay.analysis = nil
                return
            }

            overlay.analysis = nil
            analysisTask = Task { [weak self, weak overlay] in
                let analyzer = ImageAnalyzer()
                let configuration = ImageAnalyzer.Configuration([.text])

                do {
                    let analysis = try await analyzer.analyze(
                        image,
                        orientation: .up,
                        configuration: configuration
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self,
                              let overlay else {
                            return
                        }
                        overlay.analysis = analysis
                        let transcript = analysis.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !transcript.isEmpty {
                            self.onTextRecognized(transcript)
                        }
                    }
                } catch {
                    await MainActor.run {
                        overlay?.analysis = nil
                    }
                }
            }
        }

        func cancel() {
            analysisTask?.cancel()
            analysisTask = nil
            currentImage = nil
        }
    }
}

@MainActor
final class LiveTextImageContainerView: NSView {
    let imageView = NSImageView()
    let overlay = ImageAnalysisOverlayView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.trackingImageView = imageView
        overlay.preferredInteractionTypes = .automatic

        addSubview(imageView)
        addSubview(overlay)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
#else
struct LiveTextImageView: View {
    let image: NSImage?
    var imageScaling: NSImageScaling = .scaleProportionallyUpOrDown
    var onTextRecognized: (String) -> Void = { _ in }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
