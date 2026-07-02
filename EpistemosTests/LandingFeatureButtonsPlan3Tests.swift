import AVFoundation
import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 landing feature buttons")
struct LandingFeatureButtonsPlan3Tests {
    @Test("landing declares the Plan 3 feature shortcuts")
    func declaresPlan3FeatureShortcuts() {
        #expect(
            LandingFeatureButton.allCases.map(\.rawValue) == [
                "pdfImport",
                "arxiv",
                "provenance",
                "extensions",
                "vaultMCP",
                "browser",
                "browserUsePro",
                "meetingNote",
                "voice",
            ]
        )
    }

    @Test("landing feature buttons have registry-backed integration brands")
    func landingFeatureButtonsHaveIntegrationBrands() {
        #expect(LandingFeatureButton.pdfImport.integrationBrand == .pdfImport)
        #expect(LandingFeatureButton.arxiv.integrationBrand == .arxiv)
        #expect(LandingFeatureButton.provenance.integrationBrand == .provenance)
        #expect(LandingFeatureButton.extensions.integrationBrand == .extensions)
        #expect(LandingFeatureButton.vaultMCP.integrationBrand == .vaultMCP)
        #expect(LandingFeatureButton.browser.integrationBrand == .browser)
        #expect(LandingFeatureButton.browserUsePro.integrationBrand == .browserUse)
        #expect(LandingFeatureButton.meetingNote.integrationBrand == .meetingNote)
        #expect(LandingFeatureButton.voice.integrationBrand == .voice)
        #expect(LandingFeatureButton.vaultMCP.shortcut == nil)
        #expect(LandingFeatureButton.browserUsePro.shortcut == nil)
    }

    @Test("landing feature button tiles render the registry-backed brand mark")
    func landingFeatureButtonTilesRenderIntegrationBrandMarks() throws {
        let buttons = try Self.loadSource("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let pixelComponents = try Self.loadSource("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(buttons.contains("brand: feature.integrationBrand"))
        #expect(buttons.contains("LandingFeatureButtonTextPolicy"))
        #expect(buttons.contains("MeetingNoteLandingGateStatus"))
        #expect(buttons.contains("maxUnavailableMessageCharacters"))
        #expect(buttons.contains("maxHelpTextCharacters"))
        #expect(buttons.contains("String(value.prefix(limit + 1))"))
        #expect(buttons.contains("String(bounded.prefix(limit - 3))"))
        #expect(buttons.contains("normalizedDisplayText(clipped)"))
        #expect(buttons.contains("CharacterSet.controlCharacters"))
        #expect(buttons.contains("LandingFeatureButtonTextPolicy.helpText(unavailableMessage)"))
        #expect(buttons.contains("func accent(in theme: EpistemosTheme)"))
        #expect(buttons.contains("feature.accent(in: theme)"))
        #expect(buttons.contains("theme.resolved.accent.color"))
        #expect(buttons.contains("theme.resolved.headingAccent.color"))
        #expect(!buttons.contains("Color(hex:"))
        #expect(!buttons.contains("case .vaultMCP, .browserUsePro: \"PRO\""))
        #expect(pixelComponents.contains("var brand: IntegrationBrand? = nil"))
        #expect(pixelComponents.contains("IntegrationBrandMarkView(brand: brand, size: 15)"))
    }

    @Test("landing shortcuts route to real Plan 3 surfaces and honest unavailable states")
    func routesToPlan3Surfaces() throws {
        let landing = try Self.loadSource("Epistemos/Views/Landing/LandingView.swift")
        let buttons = try Self.loadSource("Epistemos/Views/Landing/LandingFeatureButtons.swift")

        #expect(landing.contains("landingFeatureShortcuts"))
        #expect(landing.contains("ForEach(LandingFeatureButton.allCases)"))
        #expect(landing.contains(".sheet(isPresented: $showingArxivSearch)"))
        #expect(landing.contains("ArxivSearchView()"))
        #expect(landing.contains("runLandingPDFImport()"))
        #expect(landing.contains("LiteParsePDFImportController.importPage"))
        #expect(landing.contains("maxLandingFeatureStatusCharacters"))
        #expect(landing.contains("maxLandingPDFImportStatusRows"))
        #expect(landing.contains("maxLandingPDFImportStatusLineCharacters"))
        #expect(landing.contains("presentLandingFeatureStatus(feature.unavailableMessage)"))
        #expect(landing.contains("presentLandingFeatureStatus("))
        #expect(landing.contains("landingPDFImportSummary(imported: imported, total: urls.count, lines: lines)"))
        #expect(landing.contains("boundedLandingFeatureStatus"))
        #expect(landing.contains("boundedLandingPDFImportStatusLine"))
        #expect(landing.contains("rawBoundedLandingStatus("))
        #expect(landing.contains("String(value.prefix(limit + 1))"))
        #expect(landing.contains("String(bounded.prefix(limit - 3))"))
        #expect(landing.contains("LandingFeatureButtonTextPolicy.normalizedDisplayText(clipped)"))
        #expect(landing.contains("ui.homeContent = .arxiv"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .provenance)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .skills)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .voice)"))
        #expect(landing.contains("ui.homeContent = .browser"))
        #expect(landing.contains("ui.homeContent = .browserUsePro"))
        #expect(landing.contains("ui.homeContent = .meeting"))

        #expect(buttons.contains("LiteParseImportGateStatus.status().isActive"))
        #expect(buttons.contains("ArxivPullGateStatus.status().isActive"))
        #expect(buttons.contains("BrowserUseProGateStatus.status().isActive"))
        #expect(buttons.contains("BrowserUseProGateStatus.status().detail"))
        #expect(buttons.contains("MeetingNoteLandingGateStatus.status().isActive"))
        #expect(buttons.contains("MeetingNoteLandingGateStatus.status().detail"))
        #expect(buttons.contains("AVCaptureDevice.authorizationStatus(for: .audio)"))
        #expect(buttons.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(buttons.contains("case .browser:"))
        #expect(buttons.contains("case .browserUsePro:"))
        #expect(buttons.contains("case .meetingNote:"))
        #expect(buttons.contains("case .voice:"))
        #expect(buttons.contains("return true"))
        #expect(!landing.contains("GooseSurfaceWindowController"))
        #expect(!buttons.contains("GooseSurfaceWindowController"))
    }

    @Test("landing feature text policy bounds unavailable and help text")
    func landingFeatureTextPolicyBoundsUnavailableAndHelpText() {
        let longStatus = String(repeating: "s", count: LandingFeatureButtonTextPolicy.maxUnavailableMessageCharacters + 32)
        let longHelp = String(repeating: "h", count: LandingFeatureButtonTextPolicy.maxHelpTextCharacters + 32)

        #expect(
            LandingFeatureButtonTextPolicy.unavailableMessage(longStatus).count ==
                LandingFeatureButtonTextPolicy.maxUnavailableMessageCharacters
        )
        #expect(
            LandingFeatureButtonTextPolicy.helpText(longHelp).count ==
                LandingFeatureButtonTextPolicy.maxHelpTextCharacters
        )
        #expect(LandingFeatureButtonTextPolicy.unavailableMessage(" \n ") == "Feature status unavailable.")
        #expect(LandingFeatureButtonTextPolicy.helpText(" \n ") == "Feature unavailable.")
        #expect(LandingFeatureButtonTextPolicy.unavailableMessage("Pro\nfeature\tlocked\u{0007}") == "Pro feature locked")
        #expect(LandingFeatureButtonTextPolicy.helpText("Open\nfeature\tsettings\u{0007}") == "Open feature settings")
    }

    @Test("meeting landing gate honors SpeechAnalyzer and microphone authorization")
    func meetingLandingGateHonorsSpeechAnalyzerAndMicrophoneAuthorization() {
        let sdkUnavailable = MeetingNoteLandingGateStatus.status(
            speechAnalyzerAvailable: false,
            audioAuthorizationStatus: .authorized
        )
        #expect(!sdkUnavailable.isActive)
        #expect(sdkUnavailable.detail.contains("macOS 26 SpeechAnalyzer"))

        let denied = MeetingNoteLandingGateStatus.status(
            speechAnalyzerAvailable: true,
            audioAuthorizationStatus: .denied
        )
        #expect(!denied.isActive)
        #expect(denied.detail.contains("microphone access"))

        let restricted = MeetingNoteLandingGateStatus.status(
            speechAnalyzerAvailable: true,
            audioAuthorizationStatus: .restricted
        )
        #expect(!restricted.isActive)
        #expect(restricted.headline.contains("microphone unavailable"))

        #expect(MeetingNoteLandingGateStatus.status(
            speechAnalyzerAvailable: true,
            audioAuthorizationStatus: .notDetermined
        ).isActive)
        #expect(MeetingNoteLandingGateStatus.status(
            speechAnalyzerAvailable: true,
            audioAuthorizationStatus: .authorized
        ).isActive)
    }

    @Test("voice landing shortcut opens the real voice settings pane")
    func voiceShortcutOpensVoiceSettingsPane() throws {
        let settings = try Self.loadSource("Epistemos/Views/Settings/SettingsView.swift")
        let voiceSettings = try Self.loadSource("Epistemos/Views/Settings/VoiceSettingsDetailView.swift")
        let windows = try Self.loadSource("Epistemos/App/UtilityWindowManager.swift")
        let landing = try Self.loadSource("Epistemos/Views/Landing/LandingView.swift")

        #expect(settings.contains("case voice = \"Voice\""))
        #expect(voiceSettings.contains("VoicePreferencesSection()"))
        #expect(settings.contains("static let selectSettingsSection"))
        #expect(windows.contains("func showSettings(section: SettingsView.SettingsSection)"))
        #expect(windows.contains("SettingsView(initialSelection: initialSettingsSection)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .provenance)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .skills)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .voice)"))
        #expect(!settings.contains("Epistemos/Goose"))
        #expect(!settings.contains("Epistemos/Agent"))
    }

    @Test("PDF import entry points hold security-scoped access while importing")
    func pdfImportEntryPointsHoldSecurityScopedAccess() throws {
        let landing = try Self.loadSource("Epistemos/Views/Landing/LandingView.swift")
        let sidebarButton = try Self.loadSource("Epistemos/LiteParse/LiteParsePDFImportButton.swift")

        for source in [landing, sidebarButton] {
            #expect(source.contains("startAccessingSecurityScopedResource()"))
            #expect(source.contains("stopAccessingSecurityScopedResource()"))
            #expect(source.contains("let gainedSecurityScope"))
            #expect(source.contains("Source PDF:"))
        }
    }

    @Test("Plan 3 landing docs do not claim Goose-owned routes")
    func landingDocsStayInPlan3Scope() throws {
        let plan = try Self.loadSource("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let codepack = try Self.loadSource("docs/research/PLAN_3_LANDING_BUTTONS_CODEPACK_2026_06_28.md")

        #expect(!plan.contains("GooseSurfaceWindowController"))
        #expect(!codepack.contains("GooseSurfaceWindowController"))
        #expect(!codepack.contains("WorkWebSurfaceWindowController"))
        #expect(plan.contains("UtilityWindowManager.showSettings(section: .provenance)"))
        #expect(plan.contains("UtilityWindowManager.showSettings(section: .skills)"))
        #expect(plan.contains("UtilityWindowManager.showSettings(section: .voice)"))
        #expect(plan.contains("embedded home surfaces for browser/browserUsePro/meeting/arXiv"))
        #expect(plan.contains("ui.homeContent = .browser"))
        #expect(plan.contains("ui.homeContent = .meeting"))
        #expect(plan.contains("unavailable/help/status text is bounded and control/whitespace-normalized"))
        #expect(plan.contains("LiteParsePDFImportController.importPage"))
        #expect(plan.contains("PLAN 3 CODEPACK STATUS"))
        #expect(plan.contains("shipped/staged codepacks"))
        #expect(plan.contains("Scope recovery complete"))
        #expect(plan.contains("Follow-up hardening order (within Plan 3)"))
        #expect(!plan.contains("five capabilities the owner explicitly chose to keep"))
        #expect(!plan.contains("CLONE-READY CODE PACKS"))
        #expect(!plan.contains("Pending owner confirm" + " of the full list"))
        #expect(!plan.contains("## Suggested " + "build order"))
        #expect(codepack.contains("ui.homeContent = .browser"))
        #expect(codepack.contains("browserUsePro"))
        #expect(codepack.contains("ui.homeContent = .meeting"))
        #expect(codepack.contains(".provenance`→`UtilityWindowManager.shared.showSettings(section: .provenance)"))
        #expect(codepack.contains(".extensions/.vaultMCP`→`UtilityWindowManager.shared.showSettings(section: .skills)"))
        #expect(codepack.contains(".voice`→`UtilityWindowManager.shared.showSettings(section: .voice)"))
        #expect(codepack.contains("`.vaultMCP` is MAS-gated"))
        #expect(codepack.contains("`.browserUsePro` is signed-Pro-gated"))
        #expect(codepack.contains("presentLandingFeatureStatus(feature.unavailableMessage)"))
        #expect(codepack.contains("bounded status alert when unavailable"))
        #expect(codepack.contains("Feature unavailable/help text is bounded and control/whitespace-normalized"))
        #expect(codepack.contains("ui.homeContent = .arxiv"))
        #expect(codepack.contains("LandingFeatureButtons.swift` [DELIVERED]"))
        #expect(!codepack.contains("showToast"))
        #expect(!codepack.contains("toast in MAS"))
        #expect(!codepack.contains("only `.extensions` is Pro-gated"))
        #expect(plan.contains("Landing-page feature buttons (owner requirement, shipped Pass 6)"))
        #expect(!codepack.contains("## NEW `Epistemos/Views/Landing/LandingFeatureButtons.swift`"))
    }

    private static func loadSource(_ relativePath: String) throws -> String {
        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0..<10 {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }
}
