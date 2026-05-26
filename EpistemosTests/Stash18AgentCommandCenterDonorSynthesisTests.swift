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
        #expect(doc.contains("ChatBrainSnapshot"))
        #expect(doc.contains("LocalModelToolbarMenu"))
        #expect(doc.contains("MainChatSubmissionRouter"))
    }

    @Test("legacy agent command center donor files stay absent from live source")
    func legacyAgentCommandCenterDonorFilesStayAbsentFromLiveSource() {
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift"))
        #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift"))
    }

    @Test("donor UX maps to current fused chat and landing surfaces")
    func donorUXMapsToCurrentFusedChatAndLandingSurfaces() throws {
        let chatCoordinator = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
        let chatInput = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let chatPicker = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let messageBubble = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let capabilityPill = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ChatCapabilityPill.swift")

        #expect(chatCoordinator.contains("private func buildMainChatBrainSnapshot("))
        #expect(chatCoordinator.contains("ChatBrainSection(title: \"Active Agent\""))
        #expect(chatCoordinator.contains("ChatBrainSection(title: \"Execution Plan\""))
        #expect(chatCoordinator.contains("ChatBrainSection(title: \"Workspace Awareness\""))

        #expect(chatPicker.contains("LocalModelToolbarMenu("))
        #expect(chatPicker.contains("preferSplitToolbarControls"))
        #expect(chatInput.contains("ChatBrainPickerMenu("))
        #expect(chatInput.contains("SlashCommandPopover("))
        #expect(chatInput.contains("ContextWindowCompactBadge("))
        #expect(chatInput.contains("ChatCapabilityPill("))
        #expect(chatInput.contains("permissionVisibilityChip"))

        #expect(landing.contains("landingSearchBrainTool"))
        #expect(landing.contains("landingSearchCommandTool"))
        #expect(landing.contains("ChatBrainPickerMenu("))
        #expect(landing.contains("SlashCommandPopover("))
        #expect(landing.contains("MainChatSubmissionRouter.submit("))

        #expect(messageBubble.contains("private struct ToolExecutionPreviewCard: View"))
        #expect(messageBubble.contains("ProcessDisclosureHeader("))
        #expect(capabilityPill.contains("struct ChatCapabilityPill: View"))
        #expect(capabilityPill.contains("let detail: String?"))
    }
}
