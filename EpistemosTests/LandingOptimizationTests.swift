import Foundation
import Testing
@testable import Epistemos

@Suite("Landing Optimization Helpers")
struct LandingOptimizationTests {
    @MainActor
    @Test("home window identity can tag untitled main windows for landing lifecycle checks")
    func homeWindowIdentityCanTagUntitledMainWindows() {
        let window = NSWindow()
        window.isReleasedWhenClosed = false
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

    @Test("liquid greeting timing cycles deterministically")
    func liquidGreetingTimingCyclesDeterministically() {
        #expect(LiquidGreetingTiming.typingDelay(forStep: 1) == LiquidGreetingTiming.typingDelay(forStep: 5))
        #expect(LiquidGreetingTiming.untypingDelay(forStep: 0) == LiquidGreetingTiming.untypingDelay(forStep: 4))
        #expect(LiquidGreetingTiming.typingDelay(forStep: 1) != LiquidGreetingTiming.typingDelay(forStep: 2))
        #expect(LiquidGreetingTiming.untypingDelay(forStep: 0) != LiquidGreetingTiming.untypingDelay(forStep: 1))
    }

    @Test("session intelligence landing feature is detached from the live landing path")
    func sessionIntelligenceLandingFeatureIsDetachedFromLivePath() throws {
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!app.contains("toggleSessionIntelligence"))
        #expect(!root.contains("SessionIntelligenceOverlay"))
        #expect(!landing.contains("SessionIntelligenceOverlay"))
    }

    @Test("landing search composer uses the label line and hides secondary tools behind Tools")
    func landingSearchComposerUsesLabelLineAndToolsReveal() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landing.contains("private var landingSearchInputLine: some View"))
        #expect(landing.contains("ChatComposerTextEditor(\n                        text: $landingSearchText"))
        #expect(landing.contains("preferSplitToolbarControls: false"))
        #expect(landing.contains("landingSearchToolsToggle"))
        #expect(landing.contains("if landingToolsExpanded {\n                landingSearchExpandedToolRow"))
        #expect(landing.contains("landingSearchCommandTool\n                landingSearchMentionTool\n                landingSearchAttachTool\n                landingSearchSavedTool"))
        #expect(!landing.contains("Rectangle()\n                    .fill(PixelPanelBackground.actionSurface(for: theme))"))
    }
}
