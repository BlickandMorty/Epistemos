import Foundation
import Testing
@testable import Epistemos

@Suite("Plan 3 whole-app logos codepack")
struct WholeAppLogosCodepackPlan3Tests {
    @Test("codepack locks non-model logo scope and boundaries")
    func codepackLocksScopeAndBoundaries() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md")

        for required in [
            "shipped code",
            "## Shipped Verified State",
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
            "Connectors",
            "The delivered implementation wires"
        ] {
            #expect(plan.contains(required), "Missing whole-app logos codepack string: \(required)")
        }
        #expect(!plan.contains("The first implementation slice should wire"))
        #expect(!plan.contains("## Build Order"))
    }

    @Test("capability rollup marks whole-app logo coverage shipped")
    func capabilityRollupMarksWholeAppLogoCoverageShipped() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        #expect(plan.contains("Whole-app brand-logo coverage — SHIPPED"))
        #expect(plan.contains("the non-model `IntegrationBrand` registry"))
        #expect(plan.contains("without runtime logo downloads or official-logo claims"))
        #expect(!plan.contains("Whole-app brand-logo coverage** — the non-model pass"))
        #expect(!plan.contains("Cross-cutting UI polish."))
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
            "static func landingFeature",
            "maxClassifierInputCharacters"
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

    @Test("settings sidebar uses registry-backed marks where sections have brands")
    func settingsSidebarUsesRegistryBackedMarksWhereSectionsHaveBrands() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let components = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsSurfaceComponents.swift")
        let codepack = try loadMirroredSourceTextFile(
            "docs/research/PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md"
        )

        for required in [
            "var sidebarBrand: IntegrationBrand?",
            "case .voice:\n                .voice",
            "case .skills:\n                .extensions",
            "case .vault:\n                .vault",
            "case .provenance:\n                .provenance",
            "SettingsIntegrationBrandBadge(",
            "brand: brand",
            "SettingsPixelGlyphBadge("
        ] {
            #expect(settings.contains(required), "Settings sidebar missing brand mark path: \(required)")
        }

        #expect(components.contains("struct SettingsIntegrationBrandBadge"))
        #expect(components.contains("IntegrationBrandMarkView(brand: brand"))
        #expect(components.contains(".accessibilityHidden(true)"))
        #expect(codepack.contains("settings sidebar marks"))
        #expect(codepack.contains("Settings sidebar branded rows now use `SettingsIntegrationBrandBadge`"))
    }

    @Test("integration brand registry has render-safe behavior mappings")
    func integrationBrandRegistryHasRenderSafeBehaviorMappings() {
        for brand in IntegrationBrand.allCases {
            #expect(!brand.displayName.isEmpty)
            #expect(brand.assetName == nil)
            #expect(!brand.systemSymbol.isEmpty)
            #expect(!brand.monogram.isEmpty)
        }

        #expect(IntegrationBrand.installedMCPServer(name: "Context7 MCP", host: "context7.com") == .context7)
        #expect(IntegrationBrand.installedMCPServer(name: "Gmail", host: "googlemail.test") == .gmail)
        #expect(IntegrationBrand.mcpRegistry(source: "mcp.so", installKind: "remoteURL", name: "Search") == .mcpSO)
        #expect(IntegrationBrand.bestOfPreset(kind: "remoteMCP", id: "vault", displayName: "Vault") == .vault)
        #expect(IntegrationBrand.connector(id: "google-drive", displayName: "Drive") == .googleDrive)
        #expect(IntegrationBrand.skillDiscovery(source: "codex", identifier: "docs", category: "research") == .codexSkills)
        #expect(IntegrationBrand.skillInstallSource(rawValue: "localPath") == .localSkill)
        #expect(IntegrationBrand.skillInventory(identifier: "github-helper", description: "GitHub tools") == .github)

        let longTail = String(repeating: "x", count: IntegrationBrand.maxClassifierInputCharacters + 64)
        #expect(IntegrationBrand.connector(id: "slack-\(longTail)", displayName: "") == .slack)
        #expect(IntegrationBrand.connector(id: longTail + "-slack", displayName: "") == .remoteMCP)
        #expect(IntegrationBrand.skillInventory(identifier: "github-\(longTail)", description: "") == .github)
        #expect(IntegrationBrand.skillInventory(identifier: longTail + "-github", description: "") == .skillRepo)

        for feature in LandingFeatureButton.allCases {
            #expect(feature.integrationBrand != .generic)
        }
    }
}
