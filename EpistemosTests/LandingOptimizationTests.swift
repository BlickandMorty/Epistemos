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

    @Test("landing does not carry the retired native search composer")
    func landingDoesNotCarryRetiredSearchComposer() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landing.contains("private var landingSearchInputLine: some View"))
        #expect(!landing.contains("ChatComposerTextEditor("))
        #expect(!landing.contains("landingSearchText"))
        #expect(!landing.contains("landingSearchToolsToggle"))
        #expect(!landing.contains("landingSearchExpandedToolRow"))
        #expect(!landing.contains("Rectangle()\n                    .fill(PixelPanelBackground.actionSurface(for: theme))"))
    }

    @Test("landing diagnostics redact thrown error details")
    func landingDiagnosticsRedactThrownErrorDetails() throws {
        let error = NSError(
            domain: "NSCocoaErrorDomain\n/Users/jojo/PrivateVault",
            code: 513,
            userInfo: [
                NSLocalizedDescriptionKey: "/Users/jojo/PrivateVault/session.swift failed"
            ]
        )

        let message = LandingDiagnostics.logMessage(
            for: error,
            fallback: "LandingView: failed to save welcome-back summary note"
        )

        #expect(message.contains("LandingView: failed to save welcome-back summary note"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=513"))
        #expect(message.count <= LandingDiagnostics.maxLogMessageCharacters)
        #expect(!message.contains("/Users/jojo"))
        #expect(!message.contains("PrivateVault"))
        #expect(!message.contains("session.swift"))
    }

    @Test("landing log sites route through redacted diagnostics")
    func landingLogSitesRouteThroughRedactedDiagnostics() throws {
        let paths = [
            "Epistemos/Views/Landing/TimeMachineView.swift",
            "Epistemos/Views/Landing/QuitSavePanelController.swift",
            "Epistemos/Views/Landing/LandingView.swift",
            "Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift",
            "Epistemos/Views/Landing/SessionIntelligenceOverlay.swift",
        ]

        for path in paths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("LandingDiagnostics.logMessage"))
            #expect(!source.contains("error.localizedDescription"))
            #expect(!source.contains("String(describing: error)"))
        }
    }
}
