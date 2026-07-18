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
        #expect(closeout.contains("Landing Wave source files are now retired from live product source."))
        #expect(ledger.contains("`stash@{17}` - parallel landing wave session"))
        #expect(ledger.contains("historical landing/session UI donor reference"))
        #expect(recoveryStatus.contains("Landing Wave source files from `#87` are now retired"))
        #expect(recoveryStatus.contains("closed by `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md`"))
        #expect(livingIndex.contains("`stash@{17}` Landing Wave / Session Intelligence recovery is closed"))
        #expect(livingIndex.contains("Landing Wave source family is retired from live product source"))
        #expect(!ledger.contains("1. `stash@{17}` - landing wave UI and missing Wave view files."))
    }

    @Test("current landing wave donor files stay retired")
    func currentLandingWaveDonorFilesStayRetired() {
        let retiredFiles = [
            "Epistemos/Views/Landing/Wave/LandingWaveDesign.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveSearchBar.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveGlyphAtlas.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveHaptics.swift",
            "Epistemos/Views/Landing/Wave/LandingWavePerformancePolicy.swift",
        ]

        for path in retiredFiles {
            #expect(!repoFileExists(path), "\(path) should stay retired from current product source")
        }
    }

    @Test("current landing surface keeps plain home route")
    func currentLandingSurfaceKeepsPlainHomeRoute() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landing.contains("@Environment(AgentChatState.self)"))
        #expect(!landing.contains("AgentPortalContextSnapshot.landing("))
        #expect(!landing.contains("agentChat.startNewSession"))
        #expect(!landing.contains("agentChat.submitAgentQuery"))
        #expect(!landing.contains("AgentCloneBridge.submitPrompt"))
        #expect(!landing.contains("MainChatSubmissionRouter.submit("))
        #expect(!landing.contains("ChatBrainPickerMenu("))
        #expect(!landing.contains("title: \"search\""))
        #expect(landing.contains("AmbientFrequencyPlaybackState"))
        #expect(!landing.contains("LandingFarmView("))
        #expect(!landing.contains("ContextualShadowsButton(scopeKind: .chat"))
        #expect(!landing.contains("ContextualShadowsPanel("))
        #expect(!landing.contains("LandingWaveOverlay("))
        #expect(!landing.contains("LandingWaveHaptics.fireBeat"))
    }
}
