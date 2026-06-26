import Foundation
import Testing

@Suite("Stash 18 Agent Command Center Donor Synthesis")
struct Stash18AgentCommandCenterDonorSynthesisTests {
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

    @Test("stash 18 donor synthesis is archived without raw legacy restore")
    func stash18DonorSynthesisIsArchivedWithoutRawLegacyRestore() throws {
        let doc = try loadMirroredSourceTextFile(
            "docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md"
        )

        #expect(doc.contains("stash@{18}"))
        #expect(doc.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(doc.contains("not restored as live UI"))
        #expect(doc.contains("AgentCommandCenterView.swift"))
        #expect(doc.contains("BrainPickerMenu.swift"))
        #expect(doc.contains("CommandBarView.swift"))
        #expect(doc.contains("InspectorPanelView.swift"))
        #expect(doc.contains("SuggestionPopoverView.swift"))
        #expect(doc.contains("Do not create another page shell."))
        #expect(doc.contains("AgentClone/fusion owns the live chat path"))
        #expect(doc.contains("LocalModelToolbarMenu"))
        #expect(doc.contains("Keep landing and main chat off the deleted native chat backend."))
        #expect(!doc.contains("routes through `MainChatSubmissionRouter`"))
    }

    @Test("legacy agent command center donor files stay absent from live source")
    func legacyAgentCommandCenterDonorFilesStayAbsentFromLiveSource() {
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift"))
    }
}
