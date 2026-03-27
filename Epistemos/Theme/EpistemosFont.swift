import SwiftUI
import os

// MARK: - Font Registration
// Registers custom fonts bundled with the app (RetroGaming, etc.)

enum EpistemosFont {
    private static let logger = Logger(subsystem: "com.epistemos", category: "Font")
    private final class BundleProbe {}

    /// Call once at app launch to register custom fonts from the bundle.
    static func registerFonts() {
        registerFont(named: "RetroGaming", extension: "ttf")
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
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let desc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            // Already registered is fine — happens in previews
            if !isBenignRegistrationErrorDescription(desc) {
                logger.warning("Failed to register \(name, privacy: .public): \(desc, privacy: .private)")
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
