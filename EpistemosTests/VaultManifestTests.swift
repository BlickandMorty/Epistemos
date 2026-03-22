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

        return VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: entries,
            recentBodies: recentBodies,
            generatedAt: now
        )
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

        #expect(context.contains("## Vault"))
        #expect(context.contains("- title: my mind"))
        #expect(context.contains("- notes: 2"))
        #expect(context.contains("## Vault Overview (2 listed notes)"))
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

        #expect(compact.contains("## Vault"))
        #expect(compact.contains("- title: my mind"))
        #expect(compact.contains("- notes: 2"))
        #expect(compact.contains("## Vault Overview (2 listed notes)"))
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

    @Test("context pack keeps vault stages ordered and deduplicated")
    func contextPackStagesAreDeterministic() throws {
        let manifest = makeManifest()
        let pack = VaultContextPack(
            manifest: manifest,
            includeManifest: true,
            referencedNotes: [
                VaultManifest.NoteBody(pageId: "p1", title: "Quantum Notes", body: "Referenced body A"),
            ],
            matchedVaultNotes: [],
            cleanedQuery: "Compare Quantum Notes"
        )

        let rendered = try #require(pack.renderedContext())
        let nsRendered = rendered as NSString
        let manifestRange = nsRendered.range(of: "## Vault")
        let referencedRange = nsRendered.range(of: "### Referenced Note: Quantum Notes")

        #expect(manifestRange.location != NSNotFound)
        #expect(referencedRange.location != NSNotFound)
        #expect(manifestRange.location < referencedRange.location)
        #expect(!rendered.contains("### Previously Referenced:"))
        #expect(pack.cleanedQuery == "Compare Quantum Notes")
    }

    @Test("context pack returns nil when no staged context exists")
    func contextPackOmitsEmptyContext() {
        let pack = VaultContextPack(
            manifest: nil,
            includeManifest: false,
            referencedNotes: [],
            matchedVaultNotes: [],
            cleanedQuery: "Hello"
        )

        #expect(pack.renderedContext() == nil)
        #expect(pack.cleanedQuery == "Hello")
    }
}
