import Foundation
import Testing

@Suite("Stash 17 Landing Wave Closeout")
struct Stash17LandingWaveCloseoutTests {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }

    @Test("closeout records stash 17 as preserved not raw applied")
    func closeoutRecordsStash17AsPreservedNotRawApplied() throws {
        let closeout = try loadMirroredSourceTextFile(
            "docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md"
        )
        let ledger = try loadMirroredSourceTextFile(
            "docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md"
        )
        let recoveryStatus = try loadMirroredSourceTextFile(
            "docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md"
        )
        let livingIndex = try loadMirroredSourceTextFile(
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md"
        )

        #expect(closeout.contains("stash@{17}"))
        #expect(closeout.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(closeout.contains("closed for current product UI recovery"))
        #expect(closeout.contains("no longer an active recovery queue item"))
        #expect(ledger.contains("`stash@{17}` - parallel landing wave session"))
        #expect(ledger.contains("historical landing/session UI donor reference"))
        #expect(recoveryStatus.contains("Landing Wave source files and Session Intelligence source: restored in `#87`"))
        #expect(recoveryStatus.contains("closed by `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md`"))
        #expect(livingIndex.contains("`stash@{17}` Landing Wave / Session Intelligence recovery is closed"))
        #expect(!ledger.contains("1. `stash@{17}` - landing wave UI and missing Wave view files."))
    }

    @Test("current landing wave and session intelligence files remain present")
    func currentLandingWaveAndSessionIntelligenceFilesRemainPresent() {
        let requiredFiles = [
            "Epistemos/Views/Landing/Wave/LandingWaveDesign.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveSearchBar.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift",
            "Epistemos/Views/Landing/SessionIntelligenceOverlay.swift",
        ]

        for path in requiredFiles {
            #expect(repoFileExists(path), "\(path) should remain on current main")
        }
    }

    @Test("current landing surface keeps newer fused route")
    func currentLandingSurfaceKeepsNewerFusedRoute() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let overlay = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift")
        let renderer = try loadMirroredSourceTextFile("Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift")

        #expect(landing.contains("MainChatSubmissionRouter.submit("))
        #expect(landing.contains("ChatBrainPickerMenu("))
        #expect(landing.contains("SlashCommandPopover("))
        #expect(landing.contains("AmbientFrequencyPlaybackState"))
        #expect(landing.contains("LandingFarmView("))
        #expect(overlay.contains("LandingWaveMetalView("))
        #expect(renderer.contains("LandingWaveChoreography.makeSequence"))
    }
}
