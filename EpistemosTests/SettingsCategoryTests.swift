import Foundation
import Testing
@testable import Epistemos

@Suite("Settings Categories — Post-Purge Simplification")
@MainActor
struct SettingsCategoryTests {
    private static var expectedCategoryLabels: [String] {
        var labels = [
            "Capture",
            "Graph",
        ]
        labels += [
            "Privacy & Storage",
            "Advanced",
        ]
        return labels
    }

    private static var expectedVisibleSections: Set<SettingsView.SettingsSection> {
        let sections: Set<SettingsView.SettingsSection> = [
            .general,
            .ambientFrequencies,
            .voice,
            .landing,
            .appearance,
            .vault,
            .privacy,
        ]
        return sections
    }

    @Test("categories match the simplified app")
    func categoriesMatchSimplifiedApp() {
        #expect(SettingsView.SettingsCategory.orderedCases.map(\.rawValue) == Self.expectedCategoryLabels)
    }

    @Test("visible settings expose only current surfaces")
    func visibleSettingsExposeOnlyCurrentSurfaces() {
        #expect(Set(SettingsView.SettingsSection.visibleSections) == Self.expectedVisibleSections)
    }

    @Test("visible sections stay reachable and categorized")
    func visibleSectionsStayReachableAndCategorized() {
        for section in SettingsView.SettingsSection.visibleSections {
            _ = section.category
            #expect(!section.rowDescription.isEmpty, "\(section.rawValue) has empty description")
            #expect(section.rowDescription.count <= 120, "\(section.rawValue) description is too long")
        }
        for category in SettingsView.SettingsCategory.orderedCases {
            let sections = SettingsView.SettingsSection.visibleSections.filter { $0.category == category }
            #expect(!sections.isEmpty, "Category \(category.rawValue) has no sections")
        }
    }

    @Test("category mapping preserves the current settings architecture")
    func categoryMappingPreservesCurrentArchitecture() {
        let expected: [SettingsView.SettingsSection: SettingsView.SettingsCategory] = [
            .landing: .capture,
            .ambientFrequencies: .capture,
            .voice: .capture,
            .appearance: .graph,
            .vault: .privacyStore,
            .privacy: .privacyStore,
            .general: .advanced,
        ]
        for (section, category) in expected {
            #expect(section.category == category, "\(section.rawValue) should map to \(category.rawValue)")
        }
    }

    @Test("stale agent, substrate, and deferred settings do not leak back into Settings")
    func staleSettingsDoNotLeakBackIntoSettings() throws {
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let powerGuard = try loadMirroredSourceTextFile("Epistemos/State/PowerGuard.swift")
        let config = try loadMirroredSourceTextFile("Epistemos/State/EpistemosConfig.swift")
        #expect(!settingsSource.contains("ExperimentalFeaturesSettingsPanel"))
        #expect(!settingsSource.contains("case experimentalFeatures"))
        #expect(!settingsSource.contains("ModelVaultsSettingsView"))
        #expect(!settingsSource.contains("ModelStackSettingsView"))
        #expect(!settingsSource.contains("AgentSectionDetailView"))
        #expect(!settingsSource.contains("KnowledgeFusionDetailView"))
        #expect(!settingsSource.contains("CognitiveSettingsSection"))
        #expect(!settingsSource.contains("ChannelsSettingsView"))
        #expect(!settingsSource.contains("NightBrain"))
        #expect(!settingsSource.contains("SubstrateHealthPanel()"))
        #expect(!settingsSource.contains("RuntimeLanesSection()"))
        #expect(!settingsSource.contains("PerformanceSettingsSection()"))
        #expect(!settingsSource.contains("Section(\"Diagnostics\")"))
        #expect(!settingsSource.contains("Eco Mode"))
        #expect(!powerGuard.contains("ecoModeEnabled"))
        #expect(!powerGuard.contains("case eco"))
        #expect(!config.contains("epistemos.ecoMode"))
    }

    @Test("legacy deep links resolve to General instead of exposing retired settings")
    func legacySettingsDeepLinksResolveToGeneral() {
        for section in [
            SettingsView.SettingsSection.skills,
            .cloudModels,
            .provenance,
            .substrateHealth,
        ] {
            #expect(SettingsView.SettingsSection.safeDetailSelection(for: section) == .general)
        }
    }

    @Test("disconnected vault diagnostics close Halo and label cached rows honestly")
    func disconnectedVaultDiagnosticsCloseHaloAndLabelCachedRows() throws {
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let editorHealth = try loadMirroredSourceTextFile("Epistemos/Views/Settings/EditorBundleHealthRow.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let notesSidebar = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(bootstrap.contains("EditorBundleHealthRow.recordHaloClosed()"))
        #expect(bootstrap.contains("cached local note/graph data only"))
        #expect(editorHealth.contains("No active vault selected - Shadow/Halo closed"))
        #expect(settings.contains("Cached local notes or graph rows may still be visible"))
        #expect(notesSidebar.contains("Disconnected Local Cache"))
        #expect(notesSidebar.contains("Rows below are cached local note/graph data"))
        #expect(notesSidebar.contains("Select Vault to Create Page"))
    }

    @Test("background indexing unavailable detail preserves cache-only reason")
    func backgroundIndexingUnavailableDetailPreservesCacheOnlyReason() throws {
        let suiteName = "SettingsCategoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let reason = "No active vault selected - cached local note/graph data only"
        BackgroundIndexingHealthRow.recordUnavailable(reason: reason, defaults: defaults)

        let snapshot = BackgroundIndexingHealthRow.snapshot(defaults: defaults)
        #expect(snapshot.phase == .unavailable)
        #expect(snapshot.detail == reason)
    }
}
