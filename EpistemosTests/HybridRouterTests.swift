import Testing
@testable import Epistemos

@Suite("HybridRouter")
@MainActor
struct HybridRouterTests {

    let router = HybridRouter()

    // MARK: - CLI Routing

    @Test("CLI keywords route to terminal agent")
    func cliRouting() {
        let step = makeStep(description: "git status to check for changes", agent: "notes", tool: "search_notes")
        let decision = router.classify(step: step)
        #expect(decision.arm == .cli)
        #expect(decision.suggestedAgent == "terminal")
    }

    @Test("Build keywords route to CLI")
    func buildKeywordsRouteCli() {
        let step = makeStep(description: "cargo build the project", agent: "notes", tool: "create_note")
        let decision = router.classify(step: step)
        #expect(decision.arm == .cli)
    }

    @Test("npm commands route to CLI")
    func npmRoutesToCli() {
        let step = makeStep(description: "npm install dependencies", agent: "notes", tool: "create_note")
        let decision = router.classify(step: step)
        #expect(decision.arm == .cli)
    }

    // MARK: - GUI Routing

    @Test("Click keywords route to computer agent")
    func guiRouting() {
        let step = makeStep(description: "click the submit button", agent: "notes", tool: "search_notes")
        let decision = router.classify(step: step)
        #expect(decision.arm == .gui)
        #expect(decision.suggestedAgent == "computer")
    }

    @Test("Screenshot keywords route to GUI")
    func screenshotRoutesToGui() {
        let step = makeStep(description: "take a screenshot of the page", agent: "notes", tool: "create_note")
        let decision = router.classify(step: step)
        #expect(decision.arm == .gui)
    }

    // MARK: - Pre-assigned Agents

    @Test("Pre-assigned terminal agent is respected")
    func preAssignedTerminal() {
        let step = makeStep(description: "do something", agent: "terminal", tool: "run_command")
        let decision = router.classify(step: step)
        #expect(decision.arm == .cli)
        #expect(decision.confidence == 1.0)
        #expect(decision.suggestedAgent == nil)
    }

    @Test("Pre-assigned computer agent is respected")
    func preAssignedComputer() {
        let step = makeStep(description: "do something", agent: "computer", tool: "see")
        let decision = router.classify(step: step)
        #expect(decision.arm == .gui)
        #expect(decision.confidence == 1.0)
    }

    // MARK: - Ambiguous

    @Test("Ambiguous description defaults to CLI")
    func ambiguousDefaultsCli() {
        let step = makeStep(description: "check the status", agent: "notes", tool: "search_notes")
        let decision = router.classify(step: step)
        // No strong CLI or GUI signals, should be .either or .cli
        #expect(decision.arm == .either || decision.arm == .cli)
    }

    // MARK: - Rerouting

    @Test("rerouteIfNeeded preserves step ID")
    func reroutePreservesId() {
        let step = makeStep(description: "git push to remote", agent: "notes", tool: "create_note")
        let routed = router.rerouteIfNeeded(step)
        #expect(routed.id == step.id)
        #expect(routed.assignedAgent == "terminal")
    }

    @Test("rerouteIfNeeded does not reroute pre-assigned agents")
    func noRerouteForPreAssigned() {
        let step = makeStep(description: "click something", agent: "terminal", tool: "run_command")
        let routed = router.rerouteIfNeeded(step)
        #expect(routed.assignedAgent == "terminal")
    }

    // MARK: - Helpers

    private func makeStep(description: String, agent: String, tool: String) -> AgentStep {
        AgentStep(
            id: UUID(),
            description: description,
            assignedAgent: agent,
            toolName: tool,
            argumentsJson: "{}",
            riskLevel: .low,
            dependsOn: []
        )
    }
}
