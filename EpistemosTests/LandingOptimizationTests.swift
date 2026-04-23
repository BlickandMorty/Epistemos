import Foundation
import Testing
@testable import Epistemos

@Suite("Landing Optimization Helpers")
struct LandingOptimizationTests {
    @MainActor
    @Test("home window identity can tag untitled main windows for landing lifecycle checks")
    func homeWindowIdentityCanTagUntitledMainWindows() {
        let window = NSWindow()
        defer { window.close() }

        window.title = ""
        window.identifier = nil

        #expect(!HomeWindowIdentity.matches(window))

        HomeWindowIdentity.apply(to: window)

        #expect(window.identifier?.rawValue == HomeWindowIdentity.sceneIdentifier)
        #expect(HomeWindowIdentity.matches(window))
    }

    @MainActor
    @Test("landing home appearance reasserts the home panel when state drifted")
    func landingHomeAppearanceReassertsHomePanelWhenStateDrifted() {
        let uiState = UIState()
        uiState.setActivePanel(.settings)

        LandingViewStateSync.reassertHomeSurface(uiState)

        #expect(uiState.activePanel == .home)
        #expect(uiState.homeTab == .home)
    }

    @Test("session intelligence note lookup extracts deduplicated note candidates")
    func sessionIntelligenceNoteLookupExtractsDeduplicatedCandidates() {
        let candidates = SessionIntelligenceNoteLookup.candidateTitles(in: """
        open note Research Plan
        Created and opened note: "Research Plan"
        [NAVIGATE_GRAPH: Graph Deep Dive]
        close note 'Research Plan'
        """)

        #expect(candidates.contains("Research Plan"))
        #expect(candidates.contains("Graph Deep Dive"))
        #expect(candidates.filter { $0 == "Research Plan" }.count == 1)
    }

    @Test("liquid greeting timing cycles deterministically")
    func liquidGreetingTimingCyclesDeterministically() {
        #expect(LiquidGreetingTiming.typingDelay(forStep: 1) == LiquidGreetingTiming.typingDelay(forStep: 5))
        #expect(LiquidGreetingTiming.untypingDelay(forStep: 0) == LiquidGreetingTiming.untypingDelay(forStep: 4))
        #expect(LiquidGreetingTiming.typingDelay(forStep: 1) != LiquidGreetingTiming.typingDelay(forStep: 2))
        #expect(LiquidGreetingTiming.untypingDelay(forStep: 0) != LiquidGreetingTiming.untypingDelay(forStep: 1))
    }

    @Test("session intelligence chat summary orders groups deterministically and caps results")
    func sessionIntelligenceChatSummaryOrdersGroupsDeterministicallyAndCapsResults() {
        let groups = [
            "chat-b": ["b1"],
            "chat-a": ["a1", "a2"],
            "chat-c": ["c1", "c2"],
            "chat-d": ["d1", "d2", "d3"]
        ]

        let orderedGroups = SessionIntelligenceChatSummary.orderedGroups(from: groups, limit: 3)

        #expect(orderedGroups.map(\.chatId) == ["chat-d", "chat-a", "chat-c"])
        #expect(orderedGroups.map(\.snippets.count) == [3, 2, 2])
    }
}
