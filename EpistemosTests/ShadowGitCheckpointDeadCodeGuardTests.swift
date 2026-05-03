import Foundation
import Testing

/// Source guard for the Omega safety cleanup slice. ShadowGitCheckpoint was
/// gated out of Core and had no callers; keeping the surface around invited a
/// future tool to wire `/usr/bin/git` subprocesses back into the app.
@Suite("ShadowGitCheckpoint Dead Code Guard")
struct ShadowGitCheckpointDeadCodeGuardTests {

    @Test("ShadowGitCheckpoint production source remains deleted")
    func shadowGitCheckpointSourceRemainsDeleted() throws {
        let deletedURL = try sourceMirrorURL(for: "Epistemos/Omega/Safety/ShadowGitCheckpoint.swift")

        #expect(!FileManager.default.fileExists(atPath: deletedURL.path))
    }

    @Test("production Swift no longer references the deleted shadow git surface")
    func productionSwiftDoesNotReferenceShadowGitCheckpoint() throws {
        let sourceURLs = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )

        for url in sourceURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(!source.contains("ShadowGitCheckpoint"),
                    "\(url.path) must not reference the deleted ShadowGitCheckpoint surface")
            #expect(!source.contains("shadow_git"),
                    "\(url.path) must not expose a shadow_git tool name")
            #expect(!source.contains("shadow git checkpoint"),
                    "\(url.path) must not retain shadow git checkpoint copy")
        }
    }
}
