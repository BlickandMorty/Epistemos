import Testing
@testable import Epistemos

@MainActor
@Suite("Agent Plan Documents")
struct AgentPlanDocumentTests {
    private func makeSeed(summary: String = "Keep the work tight and tool-aware.") -> AgentPlanDocumentSeed {
        AgentPlanDocumentSeed(
            query: "Ship the editable plan side panel",
            summary: summary,
            operatingMode: "Agent",
            route: "Managed Agent",
            experts: ["notes", "files"],
            budgets: [
                AgentPlanDocumentBudget(label: "Turns", value: 6),
                AgentPlanDocumentBudget(label: "Tool calls", value: 10),
            ]
        )
    }

    @Test("structured H1 responses become plan candidates")
    func structuredH1ResponsesBecomePlanCandidates() {
        let response = """
        # Future Sessions

        ## Session 1
        - [ ] Bridge the panel
        - [ ] Reuse the prose editor
        """

        #expect(AgentPlanDocumentBuilder.extractPlanCandidate(from: response) == response)
    }

    @Test("checklists inside prose are lifted into the plan panel")
    func checklistsInsideProseAreLiftedIntoThePlanPanel() {
        let response = """
        Here is the plan for the next pass:

        - [ ] Add the side panel editor
        - [ ] Keep the header retro
        - [ ] Preserve direct editing
        """

        let candidate = AgentPlanDocumentBuilder.extractPlanCandidate(from: response)

        #expect(candidate?.contains("- [ ] Add the side panel editor") == true)
        #expect(candidate?.contains("Here is the plan") == false)
    }

    @Test("agent chat seeds a writable plan document from execution policy")
    func agentChatSeedsAWritablePlanDocumentFromExecutionPolicy() {
        let state = AgentChatState()

        state.seedPlanDocument(makeSeed())

        #expect(state.planDocumentText.contains("# Agent Plan"))
        #expect(state.planDocumentText.contains("## Objective"))
        #expect(state.planDocumentText.contains("Ship the editable plan side panel"))
        #expect(state.planDocumentText.contains("## Runtime"))
        #expect(state.planDocumentText.contains("Managed Agent"))
    }

    @Test("manual plan edits are not overwritten by later auto-sync")
    func manualPlanEditsAreNotOverwrittenByLaterAutoSync() {
        let state = AgentChatState()
        state.seedPlanDocument(makeSeed())
        state.absorbAgentResponseIntoPlanDocument(
            """
            # Build Plan

            ## Next
            - [ ] Hook up the editor
            """
        )

        #expect(state.planDocumentText.contains("# Build Plan"))

        state.userEditedPlanDocument("Custom panel draft")
        state.absorbAgentResponseIntoPlanDocument(
            """
            # Replacement Plan

            - [ ] This should not replace user edits
            """
        )

        #expect(state.planDocumentText == "Custom panel draft")
    }

    @Test("plan surfaces support rendered document and raw markdown modes")
    func planSurfacesSupportRenderedDocumentAndRawMarkdownModes() throws {
        let editorSource = try loadMirroredSourceTextFile("Epistemos/Views/AgentCommandCenter/AgentPlanEditorView.swift")
        let toggleSource = try loadMirroredSourceTextFile("Epistemos/Views/Shared/MarkdownDocumentModeToggle.swift")

        #expect(editorSource.contains("TextEditor(text: $text)"))
        #expect(toggleSource.contains("case rendered"))
        #expect(toggleSource.contains("case markdown"))
    }
}
