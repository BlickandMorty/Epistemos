import Foundation
import Testing

@Suite("Plan 3 whole-app logos codepack")
struct WholeAppLogosCodepackPlan3Tests {
    @Test("codepack locks non-model logo scope and boundaries")
    func codepackLocksScopeAndBoundaries() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md")

        for required in [
            "non-model brand-logo coverage",
            "engines, integrations, MCP, marketplace, tools, and landing-button audit",
            "Do not touch Plan 1 files",
            "Do not touch Plan 2 editor surfaces",
            "Do not download logos at runtime",
            "Do not fake official logos",
            "IntegrationBrand",
            "IntegrationBrandMarkView",
            "Installed URL MCP servers",
            "Marketplace search results",
            "Best-of preset items",
            "Connectors"
        ] {
            #expect(plan.contains(required), "Missing whole-app logos codepack string: \(required)")
        }
    }

    @Test("registry is shared, render-safe, and does not fetch logo assets at runtime")
    func registryIsSharedRenderSafeAndLocalOnly() throws {
        let registry = try loadMirroredSourceTextFile("Epistemos/Views/Shared/IntegrationBrandMark.swift")

        for required in [
            "nonisolated enum IntegrationBrand",
            "struct IntegrationBrandMarkView",
            "from `ProviderBrand`, which remains the model-provider logo registry",
            "var assetName: String? { nil }",
            "NSImage(named: assetName)",
            "brand mark",
            "static func installedMCPServer",
            "static func mcpRegistry",
            "static func bestOfPreset",
            "static func connector",
            "static func skillDiscovery",
            "static func skillInstallSource",
            "static func skillInventory",
            "static func landingFeature"
        ] {
            #expect(registry.contains(required), "Missing IntegrationBrand registry string: \(required)")
        }

        for forbidden in [
            "URLSession",
            "Process(",
            "subprocess",
            "curl ",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "Epdoc",
            "HTMLWorkspace"
        ] {
            #expect(!registry.contains(forbidden), "IntegrationBrand registry crossed a forbidden boundary: \(forbidden)")
        }
    }

    @Test("extensibility settings rows use registry-backed brand marks")
    func extensibilityRowsUseRegistryBackedMarks() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ExtensionsDetailView.swift")

        for required in [
            "brand: .installedMCPServer(name: server.name, host: server.host)",
            "brand: .mcpRegistry(",
            "source: entry.source.rawValue",
            "installKind: entry.installKind.rawValue",
            "brand: .bestOfPreset(",
            "kind: item.kind.rawValue",
            "brand: .connector(",
            "id: status.connector.id",
            "displayName: status.connector.displayName"
        ] {
            #expect(source.contains(required), "ExtensionsDetailView missing registry-backed mark: \(required)")
        }

        #expect(!source.contains("Image(systemName: status.connector.systemImage)"))
    }

    @Test("skills settings and Plan 3 utility headers use registry-backed brand marks")
    func skillsAndUtilityHeadersUseRegistryBackedMarks() throws {
        let skills = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SkillsSettingsView.swift")
        let arxiv = try loadMirroredSourceTextFile("Epistemos/Views/Arxiv/ArxivSearchView.swift")
        let browser = try loadMirroredSourceTextFile("Epistemos/Views/Browser/BrowserView.swift")
        let browserUse = try loadMirroredSourceTextFile("Epistemos/Views/Settings/BrowserUseSettingsView.swift")
        let meeting = try loadMirroredSourceTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let landingButtons = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let pixelComponents = try loadMirroredSourceTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        for required in [
            "brand: .skillDiscovery(",
            "source: skill.source.rawValue",
            "brand: .skillInstallSource(rawValue: installSource.rawValue)",
            "brand: .skillInventory(",
            "identifier: skill.name",
            "description: skill.description"
        ] {
            #expect(skills.contains(required), "SkillsSettingsView missing registry-backed mark: \(required)")
        }

        #expect(arxiv.contains("IntegrationBrandMarkView(brand: .arxiv"))
        #expect(browser.contains("IntegrationBrandMarkView(brand: .browser"))
        #expect(browserUse.contains("IntegrationBrandMarkView(brand: .browserUse"))
        #expect(meeting.contains("IntegrationBrandMarkView(brand: .meetingNote"))
        #expect(landingButtons.contains("var integrationBrand: IntegrationBrand"))
        #expect(landingButtons.contains(".landingFeature(rawValue: rawValue)"))
        #expect(landingButtons.contains("brand: feature.integrationBrand"))
        #expect(pixelComponents.contains("var brand: IntegrationBrand? = nil"))
        #expect(pixelComponents.contains("IntegrationBrandMarkView(brand: brand, size: 15)"))
        #expect(pixelComponents.contains("foregroundStyle(accent.opacity"))
    }
}
