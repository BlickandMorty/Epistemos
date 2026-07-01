import Foundation

@main
struct LandingFeatureButtonsSmoke {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let buttons = read("Epistemos/Views/Landing/LandingFeatureButtons.swift", root: root)
        let landing = read("Epistemos/Views/Landing/LandingView.swift", root: root)
        let brands = read("Epistemos/Views/Shared/IntegrationBrandMark.swift", root: root)

        let featureBrands = [
            "pdfImport": "pdfImport",
            "arxiv": "arxiv",
            "provenance": "provenance",
            "extensions": "extensions",
            "vaultMCP": "vaultMCP",
            "browser": "browser",
            "browserUsePro": "browserUse",
            "meetingNote": "meetingNote",
            "voice": "voice",
        ]

        for feature in [
            "pdfImport",
            "arxiv",
            "provenance",
            "extensions",
            "vaultMCP",
            "browser",
            "browserUsePro",
            "meetingNote",
            "voice",
        ] {
            require(buttons.contains("case \(feature)"), "missing LandingFeatureButton.\(feature)")
            let brand = featureBrands[feature] ?? feature
            require(brands.contains("case \(brand)"), "missing IntegrationBrand.\(brand)")
        }

        require(buttons.contains("LiteParseImportGateStatus.status().isActive"), "PDF import must be gated by LiteParse status")
        require(buttons.contains("ArxivPullGateStatus.status().isActive"), "arXiv must be gated by arXiv status")
        require(buttons.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"), "vault MCP must stay Pro/MAS gated")
        require(
            buttons.contains("case .vaultMCP, .browserUsePro:\n            return true"),
            "vault MCP and browser-use Pro should be marked Pro-only"
        )

        require(landing.contains("ForEach(LandingFeatureButton.allCases)"), "landing must render all feature buttons")
        require(landing.contains("LandingFeatureButtonTile(feature: feature"), "landing must render feature tiles")
        require(landing.contains(".sheet(isPresented: $showingArxivSearch)"), "landing must present arXiv sheet")
        require(landing.contains("ArxivSearchView()"), "arXiv button must open live search UI")

        let routeChecks = [
            "case .pdfImport:\n            runLandingPDFImport()",
            "case .arxiv:\n            showingArxivSearch = true",
            "case .provenance:\n            UtilityWindowManager.shared.showSettings(section: .provenance)",
            "case .extensions, .vaultMCP:\n            UtilityWindowManager.shared.showSettings(section: .skills)",
            "case .voice:\n            UtilityWindowManager.shared.showSettings(section: .voice)",
            "case .browser:\n            UtilityWindowManager.shared.show(.browser)",
            "case .browserUsePro:\n            UtilityWindowManager.shared.show(.browserUsePro)",
            "case .meetingNote:\n            UtilityWindowManager.shared.show(.meetingNote)",
        ]
        for route in routeChecks {
            require(landing.contains(route), "missing landing route: \(route)")
        }

        require(landing.contains("LiteParsePDFImportController.importPage"), "PDF landing route must call LiteParse import")
        print("landing feature buttons smoke OK: buttons=9 arxiv_sheet=true gates_honest=true routes_live=true")
    }

    private static func read(_ relativePath: String, root: URL) -> String {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fail("could not read \(relativePath)")
        }
        return text
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("landing feature buttons smoke failed: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
