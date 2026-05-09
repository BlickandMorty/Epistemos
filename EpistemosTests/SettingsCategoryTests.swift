import Testing
@testable import Epistemos
import Foundation

// MARK: - Settings Category Tests (Phase 7 Step 7)
//
// Phase 7 simplifies the settings sidebar from 12 flat sections into 6
// ordered categories (Capture, Models, Graph, Automation, Privacy &
// Storage, Advanced). The underlying `SettingsSection` enum is kept
// whole so every existing detail view stays reachable — the only
// changes are sidebar grouping and row subtitles. Phase S.6 adds a
// thirteenth visible section (.privacy) under the Privacy & Storage
// category to surface the App Privacy manifest to the user; the
// Provenance Console adds the fourteenth visible section under that
// same category. HELIOS research scaffold remains source-preserved but
// is not visible in the v1 runtime sidebar.
//
// These tests lock in:
//   - the six-category shape (count, order, labels)
//   - every visible section maps to exactly one category
//   - every section has a non-empty row description
//   - no category ends up empty
//   - nothing was dropped from the visible sections list

@Suite("Settings Categories — Phase 7 Simplification")
@MainActor
struct SettingsCategoryTests {

    @Test("Exactly six categories exist in the expected order")
    func sixCategoriesInOrder() {
        let labels = SettingsView.SettingsCategory.orderedCases.map(\.rawValue)
        #expect(labels == [
            "Capture",
            "Models",
            "Graph",
            "Automation",
            "Privacy & Storage",
            "Advanced",
        ])
    }

    @Test("Every visible section maps to exactly one category")
    func everyVisibleSectionHasCategory() {
        for section in SettingsView.SettingsSection.visibleSections {
            // `category` is non-optional by construction; this test is
            // mostly a compile-time guarantee that the switch is total.
            _ = section.category
        }
        // 14 visible after Agent consolidation + S.6 privacy pane +
        // the Provenance Console:
        // agentControl + authority + overseer rolled up into a single
        // .agent entry; .privacy and .provenance live under Privacy & Storage.
        #expect(SettingsView.SettingsSection.visibleSections.count == 14)
    }

    @Test("Category mapping matches the Phase 7 spec")
    func categoryMappingMatchesSpec() {
        let expected: [SettingsView.SettingsSection: SettingsView.SettingsCategory] = [
            .landing:         .capture,
            .cognitive:       .models,
            .inference:       .models,
            .modelVaults:     .models,
            .knowledgeFusion: .models,
            .appearance:      .graph,
            .channels:        .automation,
            .iMessageDriver:  .automation,
            .skills:          .automation,
            .agent:           .automation,
            // Legacy entries still map to .automation for deep-link
            // compatibility but are hidden from the sidebar.
            .agentControl:    .automation,
            .authority:       .automation,
            .overseer:        .automation,
            .vault:           .privacyStore,
            .privacy:         .privacyStore,
            .general:         .advanced,
            .heliosV5:        .advanced,
        ]
        for (section, category) in expected {
            #expect(section.category == category, "\(section.rawValue) should map to \(category.rawValue)")
        }
    }

    @Test("No category is empty")
    func noEmptyCategories() {
        for category in SettingsView.SettingsCategory.orderedCases {
            let sections = SettingsView.SettingsSection.visibleSections
                .filter { $0.category == category }
            #expect(!sections.isEmpty, "Category \(category.rawValue) has no sections")
        }
    }

    @Test("Every section has a non-empty row description under 120 chars")
    func everyRowDescriptionIsConcise() {
        for section in SettingsView.SettingsSection.visibleSections {
            let description = section.rowDescription
            #expect(!description.isEmpty, "\(section.rawValue) has empty description")
            #expect(
                description.count <= 120,
                "\(section.rawValue) description is too long: \(description.count) chars"
            )
        }
    }

    @Test("All 14 visible sections are reachable (Agent consolidation + privacy/provenance)")
    func allVisibleSectionsAreReachable() {
        // .agent replaces .agentControl + .authority + .overseer in the
        // sidebar; the legacy entries remain enum cases for deep-link
        // compatibility but are not in visibleSections. Privacy and
        // provenance both surface under Privacy & Storage. HELIOS remains
        // source-preserved but hidden for the v1 runtime freeze.
        let expected: Set<SettingsView.SettingsSection> = [
            .general, .channels, .cognitive, .inference,
            .knowledgeFusion, .modelVaults, .iMessageDriver,
            .skills, .agent,
            .landing, .appearance, .vault, .privacy, .provenance,
        ]
        #expect(Set(SettingsView.SettingsSection.visibleSections) == expected)
    }

    @Test("Legacy agent deep-links preserve the matching consolidated tab")
    func legacyAgentDeepLinksPreserveMatchingTab() throws {
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let agentSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentSectionDetailView.swift")

        #expect(agentSource.contains("initialTab: AgentTab = .control"))
        #expect(settingsSource.contains("initialTab: .control"))
        #expect(settingsSource.contains("initialTab: .authority"))
        #expect(settingsSource.contains("initialTab: .overseer"))
    }

    @Test("Spend dashboard never reports untracked costs as zero")
    func spendDashboardNeverReportsUntrackedCostsAsZero() throws {
        let agentSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentSectionDetailView.swift")
        let costSource = try loadMirroredSourceTextFile("Epistemos/Views/Cost/CostDashboardView.swift")

        #expect(costSource.contains("public let estimatedCostUSD: Double?"))
        #expect(costSource.contains("guard hasTrackedCosts else { return \"—\" }"))
        #expect(costSource.contains("return \"Not tracked\""))
        #expect(costSource.contains("Text(\"Token usage and tracked spend\")"))
        #expect(agentSource.contains("estimatedCostUSD: nil"))
        #expect(agentSource.contains("provider: nil"))
        #expect(!agentSource.contains("estimatedCostUSD: 0.0"))
        #expect(!agentSource.contains("provider: \"—\""))
        #expect(!agentSource.contains("$0.00 placeholder"))
        #expect(!agentSource.contains("intentionally left as placeholders"))
    }

    @Test("Disconnected vault diagnostics close Halo and label cached rows honestly")
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

    @Test("Background indexing unavailable detail preserves cache-only reason")
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

    @Test("Night Brain power setting copy matches canonical healthy-battery runner policy")
    func nightBrainPowerCopyMatchesCanonicalPolicy() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/CognitiveSettingsSection.swift")

        #expect(source.contains("Require Healthy Power"))
        #expect(source.contains("battery above 50%"))
        #expect(!source.contains("Require AC Power"))
        #expect(!source.contains("Requiring AC power"))
    }
}
