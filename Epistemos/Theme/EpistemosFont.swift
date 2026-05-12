import SwiftUI
import os

// MARK: - Font Registration
// Registers custom fonts bundled with the app (display, mono, and pixel families).

enum EpistemosFont {
    private static let logger = Logger(subsystem: "com.epistemos", category: "Font")
    private final class BundleProbe {}
    private static let claudeFontCandidatePaths = [
        "/Applications/Claude.app/Contents/Resources/fonts/AnthropicSerif-Romans-Variable-25x258.ttf",
        "/Applications/Claude.app/Contents/Resources/fonts/AnthropicSerif-Italics-Variable-25x258.ttf",
        "/Applications/Claude.app/Contents/Resources/fonts/AnthropicSans-Romans-Variable-25x258.ttf",
        "/Applications/Claude.app/Contents/Resources/fonts/AnthropicSans-Italics-Variable-25x258.ttf",
    ]

    /// Call once at app launch to register custom fonts from the bundle.
    /// `Inter-Regular.ttf` is the variable Inter font (PSName
    /// `InterVariable`); pick weight axes via `.weight()` on the variable font. We
    /// don't ship a separate `Inter-SemiBold.ttf` because it would be the
    /// same 880KB binary with the same PSName — wasted bundle space.
    static func registerFonts() {
        registerFont(named: "RetroGaming", extension: "ttf")
        registerFont(named: "CoralPixels-Regular", extension: "ttf")
        registerFont(named: "BitPap", extension: "ttf")
        registerFont(named: "ColorBasic-Regular", extension: "otf")
        registerFont(named: "Pixelon", extension: "otf")
        registerFont(named: "Inter-Regular", extension: "ttf")
        registerFont(named: "JetBrainsMono-Regular", extension: "ttf")
        registerClaudeReferenceFontsIfAvailable()
    }

    static func isBenignRegistrationErrorDescription(_ description: String) -> Bool {
        let normalized = description.lowercased()
        return normalized.contains("already registered")
            || normalized.contains("already been registered")
    }

    private static func registerFont(named name: String, extension ext: String) {
        guard let url = fontURL(named: name, extension: ext) else {
            logger.warning("Font \(name, privacy: .public).\(ext, privacy: .public) not found in bundle")
            return
        }
        registerFont(at: url, label: "\(name).\(ext)")
    }

    private static func registerClaudeReferenceFontsIfAvailable(
        fileManager: FileManager = .default
    ) {
        for path in Self.claudeFontCandidatePaths where fileManager.fileExists(atPath: path) {
            registerFont(at: URL(fileURLWithPath: path), label: URL(fileURLWithPath: path).lastPathComponent)
        }
    }

    private static func registerFont(at url: URL, label: String) {
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let desc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            // Already registered is fine — happens in previews
            if !isBenignRegistrationErrorDescription(desc) {
                logger.warning("Failed to register \(label, privacy: .public): \(desc, privacy: .private)")
            }
        }
    }

    private static func fontURL(named name: String, extension ext: String) -> URL? {
        let bundleCandidates = [Bundle.main, Bundle(for: BundleProbe.self)] + Bundle.allBundles + Bundle.allFrameworks
        var seenBundlePaths = Set<String>()

        for bundle in bundleCandidates {
            let bundlePath = bundle.bundleURL.path
            if !seenBundlePaths.insert(bundlePath).inserted {
                continue
            }

            if let resourceURL = bundle.url(forResource: name, withExtension: ext) {
                return resourceURL
            }

            if let fontsDirectory = bundle.resourceURL?.appendingPathComponent("Fonts", isDirectory: true) {
                let nestedURL = fontsDirectory.appendingPathComponent("\(name).\(ext)")
                if FileManager.default.fileExists(atPath: nestedURL.path) {
                    return nestedURL
                }
            }
        }

        return nil
    }
}
