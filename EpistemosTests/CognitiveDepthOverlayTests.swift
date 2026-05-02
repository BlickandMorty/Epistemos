import Foundation
import Testing

@testable import Epistemos

@Suite("CognitiveDepthOverlay (Phase 8)")
@MainActor
struct CognitiveDepthOverlayTests {

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cognitive-depth-overlay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private func markdownFile(named name: String = "note.md", in dir: URL) throws -> URL {
        let source = dir.appendingPathComponent(name)
        try "# Note".write(to: source, atomically: true, encoding: .utf8)
        return source
    }

    @Test("Missing sidecar defaults to surface depth")
    func missingSidecarDefaultsToSurface() throws {
        let overlay = CognitiveDepthOverlay.shared
        overlay.resetCache()
        let dir = try tempDir()
        defer {
            overlay.resetCache()
            try? FileManager.default.removeItem(at: dir)
        }
        let source = try markdownFile(in: dir)

        #expect(overlay.depth(for: source) == .surface)
    }

    @Test("Sidecar depth drives overlay lookup")
    func sidecarDepthDrivesLookup() throws {
        let overlay = CognitiveDepthOverlay.shared
        overlay.resetCache()
        let dir = try tempDir()
        defer {
            overlay.resetCache()
            try? FileManager.default.removeItem(at: dir)
        }
        let source = try markdownFile(in: dir)
        var sidecar = EpistemosSidecarStore.mintStub(for: source)
        sidecar.schemaVersion = EpistemosSidecar.currentSchemaVersion
        sidecar.depth = .coreBelief
        try EpistemosSidecarStore.write(sidecar, for: source)

        #expect(overlay.depth(for: source) == .coreBelief)
    }

    @Test("Pending preview override wins over cached sidecar until discarded")
    func pendingPreviewOverrideWinsOverCachedSidecarUntilDiscarded() throws {
        let overlay = CognitiveDepthOverlay.shared
        overlay.resetCache()
        let dir = try tempDir()
        defer {
            overlay.resetCache()
            try? FileManager.default.removeItem(at: dir)
        }
        let source = try markdownFile(in: dir)
        var sidecar = EpistemosSidecarStore.mintStub(for: source)
        sidecar.schemaVersion = EpistemosSidecar.currentSchemaVersion
        sidecar.depth = .surface
        try EpistemosSidecarStore.write(sidecar, for: source)

        #expect(overlay.depth(for: source) == .surface)

        overlay.setDepth(.coreBelief, for: source, persist: false)
        #expect(overlay.depth(for: source) == .coreBelief)

        overlay.discardPendingOverrides()
        #expect(overlay.depth(for: source) == .surface)
    }

    @Test("Corrupt sidecar falls back to surface instead of throwing")
    func corruptSidecarFallsBackToSurface() throws {
        let overlay = CognitiveDepthOverlay.shared
        overlay.resetCache()
        let dir = try tempDir()
        defer {
            overlay.resetCache()
            try? FileManager.default.removeItem(at: dir)
        }
        let source = try markdownFile(in: dir)
        let sidecarURL = try #require(EpistemosSidecarStore.sidecarURL(for: source))
        try "{".write(to: sidecarURL, atomically: true, encoding: .utf8)

        #expect(overlay.depth(for: source) == .surface)
    }

    @Test("Visualization mapping preserves L1 to L3 hierarchy")
    func visualizationMappingPreservesDepthHierarchy() {
        let overlay = CognitiveDepthOverlay.shared

        #expect(overlay.altitude(for: .surface) < overlay.altitude(for: .synthesized))
        #expect(overlay.altitude(for: .synthesized) < overlay.altitude(for: .coreBelief))
        #expect(overlay.radiusScale(for: .surface) < overlay.radiusScale(for: .synthesized))
        #expect(overlay.radiusScale(for: .synthesized) < overlay.radiusScale(for: .coreBelief))
    }
}
