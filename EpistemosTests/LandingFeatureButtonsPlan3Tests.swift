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
        #expect(buttons.contains("maxUnavailableMessageCharacters"))
        #expect(buttons.contains("maxHelpTextCharacters"))
        #expect(buttons.contains("String(value.prefix(limit + 1))"))
        #expect(buttons.contains("String(bounded.prefix(limit - 3))"))
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
        #expect(landing.contains("showingArxivSearch = true"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .provenance)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .skills)"))
        #expect(landing.contains("UtilityWindowManager.shared.showSettings(section: .voice)"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.browser)"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.browserUsePro)"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.meetingNote)"))

        #expect(buttons.contains("LiteParseImportGateStatus.status().isActive"))
        #expect(buttons.contains("ArxivPullGateStatus.status().isActive"))
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
    }

    @Test("voice landing shortcut opens the real voice settings pane")
    func voiceShortcutOpensVoiceSettingsPane() throws {
        let settings = try Self.loadSource("Epistemos/Views/Settings/SettingsView.swift")
        let windows = try Self.loadSource("Epistemos/App/UtilityWindowManager.swift")
        let landing = try Self.loadSource("Epistemos/Views/Landing/LandingView.swift")

        #expect(settings.contains("case voice = \"Voice\""))
        #expect(settings.contains("VoicePreferencesSection()"))
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
        #expect(plan.contains("UtilityWindowManager.show(.browser)"))
        #expect(plan.contains("UtilityWindowManager.show(.meetingNote)"))
        #expect(plan.contains("browser/browserUsePro/"))
        #expect(plan.contains("unavailable/help/status text is raw-bounded before trim"))
        #expect(plan.contains("LiteParsePDFImportController.importPage"))
        #expect(plan.contains("PLAN 3 CODEPACK STATUS"))
        #expect(plan.contains("shipped/staged codepacks"))
        #expect(plan.contains("Scope recovery complete"))
        #expect(plan.contains("Follow-up hardening order (within Plan 3)"))
        #expect(!plan.contains("five capabilities the owner explicitly chose to keep"))
        #expect(!plan.contains("CLONE-READY CODE PACKS"))
        #expect(!plan.contains("Pending owner confirm" + " of the full list"))
        #expect(!plan.contains("## Suggested " + "build order"))
        #expect(codepack.contains("UtilityWindowManager.shared.show(.browser)"))
        #expect(codepack.contains("browserUsePro"))
        #expect(codepack.contains("UtilityWindowManager.shared.show(.meetingNote)"))
        #expect(codepack.contains(".provenance`→`UtilityWindowManager.shared.showSettings(section: .provenance)"))
        #expect(codepack.contains(".extensions/.vaultMCP`→`UtilityWindowManager.shared.showSettings(section: .skills)"))
        #expect(codepack.contains(".voice`→`UtilityWindowManager.shared.showSettings(section: .voice)"))
        #expect(codepack.contains("`.vaultMCP` and `.browserUsePro`"))
        #expect(codepack.contains("presentLandingFeatureStatus(feature.unavailableMessage)"))
        #expect(codepack.contains("bounded status alert in MAS"))
        #expect(codepack.contains("Feature unavailable/help text is raw-bounded before trim"))
        #expect(codepack.contains("showingArxivSearch = true"))
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
