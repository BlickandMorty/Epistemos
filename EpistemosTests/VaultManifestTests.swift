import Foundation
import Testing
@testable import Epistemos

@Suite("VaultManifest")
struct VaultManifestTests {
    private func makeManifest() -> VaultManifest {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            VaultManifest.ManifestEntry(
                pageId: "p1",
                title: "Quantum Notes",
                tags: ["physics", "math"],
                folderName: "Research",
                wordCount: 420,
                snippet: "Renormalization and field operators",
                updatedAt: now,
                createdAt: now.addingTimeInterval(-1000)
            ),
            VaultManifest.ManifestEntry(
                pageId: "p2",
                title: "Daily Journal",
                tags: [],
                folderName: nil,
                wordCount: 120,
                snippet: "Morning planning and review",
                updatedAt: now.addingTimeInterval(-3600),
                createdAt: now.addingTimeInterval(-7200)
            ),
        ]

        let recentBodies = [
            VaultManifest.NoteBody(pageId: "p1", title: "Quantum Notes", body: "Full body A"),
            VaultManifest.NoteBody(pageId: "p2", title: "Daily Journal", body: "Full body B"),
        ]

        return VaultManifest(entries: entries, recentBodies: recentBodies, generatedAt: now)
    }

    @Test("manifest entry id maps to pageId")
    func manifestEntryIdUsesPageId() {
        let entry = VaultManifest.ManifestEntry(
            pageId: "entry-123",
            title: "T",
            tags: [],
            folderName: nil,
            wordCount: 0,
            snippet: "",
            updatedAt: .now,
            createdAt: .now
        )
        #expect(entry.id == "entry-123")
    }

    @Test("asContext includes overview entries and recent note bodies")
    func asContextIncludesSections() {
        let manifest = makeManifest()
        let context = manifest.asContext()

        #expect(context.contains("## Vault Overview (2 notes)"))
        #expect(context.contains("**Quantum Notes** in Research [tags: physics, math]"))
        #expect(context.contains("Renormalization and field operators"))
        #expect(context.contains("## Recent Notes (full content)"))
        #expect(context.contains("### Quantum Notes"))
        #expect(context.contains("Full body B"))
    }

    @Test("asManifestOnly omits snippets and full body section")
    func asManifestOnlyIsCompact() {
        let manifest = makeManifest()
        let compact = manifest.asManifestOnly()

        #expect(compact.contains("## Vault Overview (2 notes)"))
        #expect(compact.contains("**Daily Journal**"))
        #expect(!compact.contains("## Recent Notes (full content)"))
        #expect(!compact.contains("Renormalization and field operators"))
        #expect(!compact.contains("Full body A"))
    }

    @Test("asManifestOnly includes all entries")
    func asManifestOnlyIncludesAllEntries() {
        let manifest = makeManifest()
        let compact = manifest.asManifestOnly()

        let lines = compact.components(separatedBy: "\n")
            .filter { $0.hasPrefix("- **") }

        #expect(lines.count == 2)
    }
}

