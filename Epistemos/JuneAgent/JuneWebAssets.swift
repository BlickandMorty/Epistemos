#if EPISTEMOS_APP_STORE
import Foundation
import os

/// Locates the vendored June web bundle (Plan 1-MAS §1).
///
/// MAS builds are self-contained: the only valid source is
/// `Contents/Resources/JuneWeb`. There is intentionally no environment or
/// development-fork fallback in this resolver.
nonisolated enum JuneWebAssets {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneWebAssets")

    struct Location {
        let distRoot: URL
        let shimURL: URL
    }

    static func resolve() -> Location? {
        guard let resources = Bundle.main.resourceURL else {
            log.error("June web bundle not found (Bundle.main.resourceURL is nil)")
            return nil
        }

        let bundled = resources.appendingPathComponent("JuneWeb", isDirectory: true)
        let dist = bundled.appendingPathComponent("dist", isDirectory: true)
        let shim = bundled.appendingPathComponent("tauri-internals-shim.js")
        let index = dist.appendingPathComponent("index.html")
        let fm = FileManager.default
        if fm.fileExists(atPath: index.path), fm.fileExists(atPath: shim.path) {
            return Location(distRoot: dist, shimURL: shim)
        }

        log.error("June web bundle not found in bundled Resources/JuneWeb")
        return nil
    }
}
#endif
