import SwiftUI
import os

// MARK: - Font Registration
// Registers custom fonts bundled with the app (RetroGaming, etc.)

enum EpistemosFont {
    private static let logger = Logger(subsystem: "com.epistemos", category: "Font")

    /// Call once at app launch to register custom fonts from the bundle.
    static func registerFonts() {
        registerFont(named: "RetroGaming", extension: "ttf")
    }

    private static func registerFont(named name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            logger.warning("Font \(name, privacy: .public).\(ext, privacy: .public) not found in bundle")
            return
        }
        guard let provider = CGDataProvider(url: url as CFURL) else {
            logger.warning("Failed to create data provider for \(name, privacy: .public)")
            return
        }
        guard let font = CGFont(provider) else {
            logger.warning("Failed to create CGFont for \(name, privacy: .public)")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            let desc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            // Already registered is fine — happens in previews
            if !desc.contains("already registered") {
                logger.warning("Failed to register \(name, privacy: .public): \(desc, privacy: .private)")
            }
        }
    }
}
