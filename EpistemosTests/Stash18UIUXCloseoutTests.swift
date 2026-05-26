import Foundation
import Testing

@Suite("Stash 18 UI UX Closeout")
struct Stash18UIUXCloseoutTests {
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

    @Test("closeout doc records stash 18 as preserved not raw applied")
    func closeoutDocRecordsPreservationRule() throws {
        let doc = try loadMirroredSourceTextFile(
            "docs/audits/STASH18_UI_UX_CLOSEOUT_2026_05_26.md"
        )

        #expect(doc.contains("stash@{18}"))
        #expect(doc.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(doc.contains("closed for current product UI/UX recovery"))
        #expect(doc.contains("no\nlonger an active product-recovery queue item"))
    }

    @Test("current fused surfaces stay present instead of raw stash downgrade")
    func currentFusedSurfacesStayPresent() {
        let requiredCurrentFiles = [
            "Epistemos/Views/Chat/AgentRunTimelineView.swift",
            "Epistemos/Views/Chat/AnswerPacketBadge.swift",
            "Epistemos/Views/Chat/ChatBrainPickerMenu.swift",
            "Epistemos/Views/Chat/ComposerMicButton.swift",
            "Epistemos/Views/Chat/ContextWindowCompactBadge.swift",
            "Epistemos/Views/Chat/ProcessDisclosureViews.swift",
            "Epistemos/Views/Chat/SlashCommandPopover.swift",
            "Epistemos/Views/Chat/VaultRecallProvenanceCard.swift",
            "Epistemos/Views/Landing/Farm/LandingFarmView.swift",
            "Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift",
            "Epistemos/Views/Graph/GraphFPSHUD.swift",
            "Epistemos/Views/Notes/EditableTransclusionView.swift",
        ]

        for path in requiredCurrentFiles {
            #expect(repoFileExists(path), "\(path) should remain on current main")
        }
    }

    @Test("old stash 18 donor shells stay absent from live source")
    func oldDonorShellsStayAbsent() {
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift"))
        #expect(!repoFileExists("Epistemos/Views/Notes/TransclusionOverlayView.swift"))
    }
}
