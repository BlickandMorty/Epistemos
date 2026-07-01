import AppKit
import Foundation
import ImageIO
import WebKit

private enum GooseABVisualHarness {
    @MainActor
    static func run() async {
        do {
            let options = try HarnessOptions(arguments: CommandLine.arguments)
            try FileManager.default.createDirectory(
                at: options.outputDirectory,
                withIntermediateDirectories: true
            )

            let nativeImage = try NativeControlRenderer(options: options).render()
            let webImage = try await WebControlRenderer(options: options).render()
            let result = try PixelDiff.diff(nativeImage: nativeImage, webImage: webImage, options: options)

            try result.native.writePNG(to: options.outputDirectory.appendingPathComponent("native.png"))
            try result.web.writePNG(to: options.outputDirectory.appendingPathComponent("web.png"))
            try result.diff.writePNG(to: options.outputDirectory.appendingPathComponent("diff.png"))

            print(
                "goose ab visual harness: control=\(options.control.rawValue) " +
                "theme=\(options.theme.rawValue) state=\(options.state.rawValue) " +
                "mismatch=\(String(format: "%.4f", result.mismatchRatio)) " +
                "threshold=\(String(format: "%.4f", options.maxMismatchRatio))"
            )

            guard result.mismatchRatio <= options.maxMismatchRatio else {
                throw HarnessError.failed(
                    "pixel mismatch exceeded gate; see \(options.outputDirectory.path)/diff.png"
                )
            }
            Foundation.exit(0)
        } catch {
            FileHandle.standardError.write(Data("goose ab visual harness failed: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}

private struct HarnessOptions {
    let htmlFile: URL
    let outputDirectory: URL
    let control: NativeControlKind
    let theme: VisualTheme
    let state: ControlState
    let pointSize: CGSize
    let scale: CGFloat
    let maxMismatchRatio: Double
    let channelThreshold: Int

    var pixelWidth: Int { max(1, Int((pointSize.width * scale).rounded())) }
    var pixelHeight: Int { max(1, Int((pointSize.height * scale).rounded())) }

    init(arguments: [String]) throws {
        if arguments.contains("--help") || arguments.contains("-h") {
            throw HarnessError.failed(Self.usage)
        }

        guard let htmlPath = Self.value(after: "--html", in: arguments) else {
            throw HarnessError.failed(Self.usage)
        }

        htmlFile = URL(fileURLWithPath: htmlPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: htmlFile.path) else {
            throw HarnessError.failed("missing --html file at \(htmlFile.path)")
        }

        let output = Self.value(after: "--out", in: arguments) ?? ".goose-ab-visual-harness"
        outputDirectory = URL(fileURLWithPath: output, isDirectory: true).standardizedFileURL
        control = try NativeControlKind(rawValue: Self.value(after: "--control", in: arguments) ?? "button")
            .orThrow("--control must be one of: button, input, segmented, switch")
        theme = try VisualTheme(rawValue: Self.value(after: "--theme", in: arguments) ?? "light")
            .orThrow("--theme must be light or dark")
        state = try ControlState(rawValue: Self.value(after: "--state", in: arguments) ?? "default")
            .orThrow("--state must be one of: default, selected, disabled, focused, pressed")

        let width = try Self.doubleValue(after: "--width", in: arguments) ?? 220
        let height = try Self.doubleValue(after: "--height", in: arguments) ?? 56
        pointSize = CGSize(width: width, height: height)
        scale = CGFloat(try Self.doubleValue(after: "--scale", in: arguments) ?? 2)
        maxMismatchRatio = try Self.doubleValue(after: "--max-mismatch", in: arguments) ?? 0.02
        channelThreshold = Int(try Self.doubleValue(after: "--threshold", in: arguments) ?? 18)
    }

    private static let usage = """
    usage: swift scripts/goose-ab-visual-harness.swift --html fixture.html [options]

    options:
      --out DIR             output directory for native.png, web.png, diff.png
      --control KIND        button | input | segmented | switch
      --theme THEME         light | dark
      --state STATE         default | selected | disabled | focused | pressed
      --width POINTS        snapshot width, default 220
      --height POINTS       snapshot height, default 56
      --scale FACTOR        backing scale, default 2
      --max-mismatch RATIO  gate, default 0.02
      --threshold CHANNEL   per-channel tolerance, default 18
    """

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func doubleValue(after flag: String, in arguments: [String]) throws -> Double? {
        guard let rawValue = value(after: flag, in: arguments) else { return nil }
        guard let value = Double(rawValue), value > 0 else {
            throw HarnessError.failed("\(flag) must be a positive number")
        }
        return value
    }
}

private enum NativeControlKind: String {
    case button
    case input
    case segmented
    case `switch`
}

private enum VisualTheme: String {
    case light
    case dark

    var backgroundColor: NSColor {
        switch self {
        case .light:
            NSColor(calibratedWhite: 1.0, alpha: 1.0)
        case .dark:
            NSColor(calibratedWhite: 0.02, alpha: 1.0)
        }
    }
}

private enum ControlState: String {
    case `default`
    case selected
    case disabled
    case focused
    case pressed
}

private struct NativeControlRenderer {
    let options: HarnessOptions

    @MainActor
    func render() throws -> CGImage {
        let container = ControlBackdropView(frame: CGRect(origin: .zero, size: options.pointSize))
        container.backgroundColor = options.theme.backgroundColor
        container.addSubview(makeControl(in: container.bounds))
        return try Snapshotter.snapshot(view: container, options: options)
    }

    @MainActor
    private func makeControl(in bounds: CGRect) -> NSView {
        switch options.control {
        case .button:
            let button = NSButton(title: "Continue", target: nil, action: nil)
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.isEnabled = options.state != .disabled
            button.frame = centeredRect(width: 120, height: 34, in: bounds)
            if options.state == .pressed {
                button.highlight(true)
            }
            return button

        case .input:
            let field = NSTextField(string: "Message Goose")
            field.controlSize = .large
            field.font = .systemFont(ofSize: 13)
            field.isEnabled = options.state != .disabled
            field.isBezeled = true
            field.focusRingType = options.state == .focused ? .default : .none
            field.frame = centeredRect(width: 176, height: 34, in: bounds)
            return field

        case .segmented:
            let segmented = NSSegmentedControl(
                labels: ["Chat", "Code"],
                trackingMode: .selectOne,
                target: nil,
                action: nil
            )
            segmented.controlSize = .large
            segmented.font = .systemFont(ofSize: 13, weight: .medium)
            segmented.isEnabled = options.state != .disabled
            segmented.selectedSegment = options.state == .selected ? 1 : 0
            segmented.frame = centeredRect(width: 150, height: 34, in: bounds)
            return segmented

        case .switch:
            let toggle = NSSwitch(frame: centeredRect(width: 48, height: 32, in: bounds))
            toggle.controlSize = .regular
            toggle.isEnabled = options.state != .disabled
            toggle.state = options.state == .selected ? .on : .off
            return toggle
        }
    }

    private func centeredRect(width: CGFloat, height: CGFloat, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        ).integral
    }
}

private final class ControlBackdropView: NSView {
    var backgroundColor: NSColor = .clear

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

private struct WebControlRenderer {
    let options: HarnessOptions

    @MainActor
    func render() async throws -> CGImage {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: options.pointSize),
            configuration: configuration
        )
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -10_000, y: -10_000), size: options.pointSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderBack(nil)
        defer { window.close() }

        let delegate = WebLoadDelegate()
        webView.navigationDelegate = delegate
        _ = webView.loadHTMLString(try fixtureHTML(), baseURL: options.htmlFile.deletingLastPathComponent())
        try await delegate.waitForLoad()
        try await Task.sleep(nanoseconds: 120_000_000)

        let snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.rect = webView.bounds
        guard let image = try await WebSnapshotter.takeSnapshot(
            webView: webView,
            configuration: snapshotConfiguration
        ),
              let cgImage = image.cgImageCopy()
        else {
            throw HarnessError.failed("WKWebView.takeSnapshot did not produce an image")
        }
        return cgImage
    }

    private func fixtureHTML() throws -> String {
        let source = try String(contentsOf: options.htmlFile, encoding: .utf8)
        if source.localizedCaseInsensitiveContains("<html") {
            return source
        }

        let background = options.theme == .light ? "#ffffff" : "#050505"
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <style>
              html, body {
                width: 100%;
                height: 100%;
                margin: 0;
                background: \(background);
              }
              body {
                display: grid;
                place-items: center;
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
              }
            </style>
          </head>
          <body>\(source)</body>
        </html>
        """
    }
}

private enum WebSnapshotter {
    @MainActor
    static func takeSnapshot(
        webView: WKWebView,
        configuration: WKSnapshotConfiguration
    ) async throws -> NSImage? {
        try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

private final class WebLoadDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForLoad() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

private enum Snapshotter {
    @MainActor
    static func snapshot(view: NSView, options: HarnessOptions) throws -> CGImage {
        view.frame = CGRect(origin: .zero, size: options.pointSize)
        view.layoutSubtreeIfNeeded()

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: options.pixelWidth,
            pixelsHigh: options.pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw HarnessError.failed("could not allocate native bitmap")
        }

        representation.size = options.pointSize
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let cgImage = representation.cgImage else {
            throw HarnessError.failed("bitmapImageRepForCachingDisplay produced no CGImage")
        }
        return cgImage
    }
}

private struct PixelDiff {
    let native: RasterImage
    let web: RasterImage
    let diff: RasterImage
    let mismatchRatio: Double

    static func diff(nativeImage: CGImage, webImage: CGImage, options: HarnessOptions) throws -> PixelDiff {
        let native = try RasterImage(cgImage: nativeImage, width: options.pixelWidth, height: options.pixelHeight)
        let web = try RasterImage(cgImage: webImage, width: options.pixelWidth, height: options.pixelHeight)
        var diffPixels = [UInt8](repeating: 0, count: native.pixels.count)
        var mismatches = 0

        for index in stride(from: 0, to: native.pixels.count, by: 4) {
            let deltaR = abs(Int(native.pixels[index]) - Int(web.pixels[index]))
            let deltaG = abs(Int(native.pixels[index + 1]) - Int(web.pixels[index + 1]))
            let deltaB = abs(Int(native.pixels[index + 2]) - Int(web.pixels[index + 2]))
            let deltaA = abs(Int(native.pixels[index + 3]) - Int(web.pixels[index + 3]))
            let isMismatch = max(deltaR, deltaG, deltaB, deltaA) > options.channelThreshold

            if isMismatch {
                mismatches += 1
                diffPixels[index] = 255
                diffPixels[index + 1] = 49
                diffPixels[index + 2] = 49
                diffPixels[index + 3] = 255
            } else {
                let gray = UInt8(
                    min(
                        255,
                        (Int(native.pixels[index]) + Int(native.pixels[index + 1]) + Int(native.pixels[index + 2])) / 3
                    )
                )
                diffPixels[index] = gray
                diffPixels[index + 1] = gray
                diffPixels[index + 2] = gray
                diffPixels[index + 3] = 96
            }
        }

        let ratio = Double(mismatches) / Double(options.pixelWidth * options.pixelHeight)
        return PixelDiff(
            native: native,
            web: web,
            diff: RasterImage(width: options.pixelWidth, height: options.pixelHeight, pixels: diffPixels),
            mismatchRatio: ratio
        )
    }
}

private struct RasterImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(cgImage: CGImage, width: Int, height: Int) throws {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { pointer in
            guard let context = CGContext(
                data: pointer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw HarnessError.failed("could not allocate raster context")
            }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func writePNG(to url: URL) throws {
        try pixels.withUnsafeBytes { pointer in
            guard let provider = CGDataProvider(
                data: Data(bytes: pointer.baseAddress!, count: pixels.count) as CFData
            ),
                  let image = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                  ),
                  let destination = CGImageDestinationCreateWithURL(
                    url as CFURL,
                    "public.png" as CFString,
                    1,
                    nil
                  )
            else {
                throw HarnessError.failed("could not create PNG at \(url.path)")
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw HarnessError.failed("could not write PNG at \(url.path)")
            }
        }
    }
}

private enum HarnessError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private extension Optional {
    func orThrow(_ message: String) throws -> Wrapped {
        guard let value = self else {
            throw HarnessError.failed(message)
        }
        return value
    }
}

private extension NSImage {
    func cgImageCopy() -> CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

Task { @MainActor in
    await GooseABVisualHarness.run()
}

RunLoop.main.run()
