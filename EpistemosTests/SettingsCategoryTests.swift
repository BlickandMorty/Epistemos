import Testing
@testable import Epistemos
import Foundation

// MARK: - Settings Category Tests (Phase 7 Step 7)
//
// Phase 7 simplifies the settings sidebar from 12 flat sections into 6
// ordered categories (Capture, Models, Graph, Automation, Privacy &
// Storage, Advanced). The underlying `SettingsSection` enum is kept
// whole so every existing detail view stays reachable — the only
// changes are sidebar grouping and row subtitles.
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
        #expect(SettingsView.SettingsSection.visibleSections.count == 12)
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
            .agentControl:    .automation,
            .vault:           .privacyStore,
            .general:         .advanced,
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

    @Test("All 12 original sections are still visible")
    func twelveSectionsStillReachable() {
        let expected: Set<SettingsView.SettingsSection> = [
            .general, .channels, .cognitive, .inference,
            .knowledgeFusion, .modelVaults, .iMessageDriver,
            .skills, .agentControl, .landing, .appearance, .vault,
        ]
        #expect(Set(SettingsView.SettingsSection.visibleSections) == expected)
    }
}
