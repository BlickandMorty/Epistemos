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
                "meetingNote",
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
        #expect(LandingFeatureButton.meetingNote.integrationBrand == .meetingNote)
    }

    @Test("landing feature button tiles render the registry-backed brand mark")
    func landingFeatureButtonTilesRenderIntegrationBrandMarks() throws {
        let buttons = try Self.loadSource("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let pixelComponents = try Self.loadSource("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(buttons.contains("brand: feature.integrationBrand"))
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
        #expect(landing.contains("showingArxivSearch = true"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.settings)"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.browser)"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.meetingNote)"))

        #expect(buttons.contains("LiteParseImportGateStatus.status().isActive"))
        #expect(buttons.contains("ArxivPullGateStatus.status().isActive"))
        #expect(buttons.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(buttons.contains("case .browser:"))
        #expect(buttons.contains("case .meetingNote:"))
        #expect(buttons.contains("return true"))
        #expect(!landing.contains("GooseSurfaceWindowController"))
        #expect(!buttons.contains("GooseSurfaceWindowController"))
    }

    @Test("Plan 3 landing docs do not claim Goose-owned routes")
    func landingDocsStayInPlan3Scope() throws {
        let plan = try Self.loadSource("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let codepack = try Self.loadSource("docs/research/PLAN_3_LANDING_BUTTONS_CODEPACK_2026_06_28.md")

        #expect(!plan.contains("GooseSurfaceWindowController"))
        #expect(!codepack.contains("GooseSurfaceWindowController"))
        #expect(!codepack.contains("WorkWebSurfaceWindowController"))
        #expect(plan.contains("UtilityWindowManager.show(.browser)"))
        #expect(plan.contains("UtilityWindowManager.show(.meetingNote)"))
        #expect(plan.contains("LiteParsePDFImportController.importPage"))
        #expect(codepack.contains("UtilityWindowManager.shared.show(.browser)"))
        #expect(codepack.contains("UtilityWindowManager.shared.show(.meetingNote)"))
        #expect(codepack.contains("showingArxivSearch = true"))
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
