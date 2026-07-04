#if EPISTEMOS_APP_STORE
import Foundation
import os

/// Locates the vendored June web bundle (Plan 1-MAS §1). Resolution order:
/// 1. Bundled resources (`Resources/JuneWeb/dist`) — the shipping path, staged
///    by a future build script from the pinned fork.
/// 2. `EPISTEMOS_JUNE_WEBROOT` env override (points at a `dist/`).
/// 3. DEBUG-only: the development fork working copy.
/// The Tauri-internals shim ships next to the dist in the fork's `epistemos/`
/// overlay and is resolved relative to it (or bundled under `JuneWeb/`).
nonisolated enum JuneWebAssets {
    private static let log = Logger(subsystem: "com.epistemos", category: "JuneWebAssets")

    /// The fork working copy used during development (Plan 1-MAS §6: the fork
    /// lives OUTSIDE the Epistemos tree).
    private static let devForkRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("dev/june-epistemos", isDirectory: true)

    struct Location {
        let distRoot: URL
        let shimURL: URL
    }

    static func resolve() -> Location? {
        var candidates: [(dist: URL, shim: URL)] = []

        if let resources = Bundle.main.resourceURL {
            let bundled = resources.appendingPathComponent("JuneWeb", isDirectory: true)
            candidates.append((
                dist: bundled.appendingPathComponent("dist", isDirectory: true),
                shim: bundled.appendingPathComponent("tauri-internals-shim.js")
            ))
        }

        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_JUNE_WEBROOT"],
           !override.isEmpty {
            let dist = URL(fileURLWithPath: override, isDirectory: true)
            candidates.append((
                dist: dist,
                shim: dist.deletingLastPathComponent()
                    .appendingPathComponent("epistemos/tauri-internals-shim.js")
            ))
        }

        #if DEBUG
        candidates.append((
            dist: devForkRoot.appendingPathComponent("dist", isDirectory: true),
            shim: devForkRoot.appendingPathComponent("epistemos/tauri-internals-shim.js")
        ))
        #endif

        let fm = FileManager.default
        for candidate in candidates {
            let index = candidate.dist.appendingPathComponent("index.html")
            if fm.fileExists(atPath: index.path), fm.fileExists(atPath: candidate.shim.path) {
                return Location(distRoot: candidate.dist, shimURL: candidate.shim)
            }
        }
        log.error("June web bundle not found (no bundled JuneWeb, no override, no dev fork)")
        return nil
    }
}
#endif
