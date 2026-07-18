import Foundation
import Testing
@testable import Epistemos

@Suite("Epdoc notebook manifest")
struct EpdocNotebookManifestTests {
    private let sheetA = "11111111-1111-4111-8111-111111111111"
    private let sheetB = "22222222-2222-4222-8222-222222222222"
    private let chat = "33333333-3333-4333-8333-333333333333"
    private let unknown = "44444444-4444-4444-8444-444444444444"
    private let embed = "55555555-5555-4555-8555-555555555555"
    private let chatEmbed = "66666666-6666-4666-8666-666666666666"

    @Test("fenced tab manifest parses references only and preserves unknown tabs as tombstones")
    func fencedManifestParsesReferencesOnly() {
        let manifest = EpdocNotebookManifest.parse(in: notebookMarkdown)

        #expect(manifest.tabs.count == 4)
        #expect(manifest.tabs.map(\.id) == [sheetA, sheetB, chat, unknown])
        #expect(manifest.tabs[0].kind == .sheet)
        #expect(manifest.tabs[0].title == "Metrics")
        #expect(manifest.tabs[0].reference == "dataset:metrics.dataset.md")
        #expect(manifest.tabs[2].kind == .chat)
        #expect(manifest.tabs[2].reference == "session:analysis-thread")
        #expect(manifest.tabs[3].kind == .unknown("chart3d"))
        #expect(manifest.tabs[3].needsTombstone)
        #expect(EpdocNotebookManifest.normalizedFreeV1SelectedTabID(sheetA) == EpdocNotebookManifest.bodyTabID)
        #expect(EpdocNotebookManifest.normalizedFreeV1SelectedTabID(chat) == EpdocNotebookManifest.bodyTabID)
        #expect(EpdocNotebookManifest.normalizedFreeV1SelectedTabID(unknown) == EpdocNotebookManifest.bodyTabID)
    }

    @Test("manifest parsing is bounded so ordinary large documents do not scan the whole body")
    func manifestParsingIsBoundedForLargeDocuments() {
        let lateManifest = String(repeating: "ordinary body line\n", count: 5_000) + """
        ```epistemos-notebook
        version: 1
        tab: id=\(sheetA) type=sheet version=1 title="Too Late" ref="dataset:late.dataset.md"
        ```
        """

        let parsed = EpdocNotebookManifest.parse(in: lateManifest)

        #expect(parsed.tabs.isEmpty)
        #expect(parsed.source == .none)
    }

    @Test("frontmatter manifest edits replace only the notebook block")
    func frontmatterManifestEditsReplaceOnlyNotebookBlock() throws {
        let markdown = """
        ---
        title: "[[Do not rewrite]]"
        tags: [raw_tag, keep~tilde]
        ---

        # Body
        """
        let tab = EpdocNotebookTab(
            id: sheetA,
            kind: .sheet,
            version: 1,
            title: "Metrics",
            reference: "dataset:metrics.dataset.md",
            line: 0,
            charOffset: 0,
            rawLine: ""
        )

        let inserted = try #require(EpdocNotebookManifest.upsertingFrontmatterManifest(tabs: [tab], in: markdown))
        #expect(inserted.hasPrefix("""
        ---
        title: "[[Do not rewrite]]"
        tags: [raw_tag, keep~tilde]
        _epistemos_notebook: |
          version: 1
        """))
        #expect(inserted.contains("""
        ---

        # Body
        """))

        let replacement = EpdocNotebookTab(
            id: sheetA,
            kind: .sheet,
            version: 1,
            title: "Renamed Metrics",
            reference: "dataset:metrics.dataset.md",
            line: 0,
            charOffset: 0,
            rawLine: ""
        )
        let updated = try #require(EpdocNotebookManifest.upsertingFrontmatterManifest(tabs: [replacement], in: inserted))
        #expect(updated.contains("title: \"[[Do not rewrite]]\"\ntags: [raw_tag, keep~tilde]\n"))
        #expect(updated.contains("title=\"Renamed Metrics\""))
        #expect(!updated.contains("title=Metrics ref="))

        let parsed = EpdocNotebookManifest.parse(in: updated)
        #expect(parsed.tabs.count == 1)
        #expect(parsed.tabs[0].title == "Renamed Metrics")
        #expect(parsed.tabs[0].reference == "dataset:metrics.dataset.md")
        let tabRange = try #require(updated.range(of: "tab: id=\(sheetA)"))
        #expect(parsed.tabs[0].charOffset == updated[..<tabRange.lowerBound].utf16.count)
    }

    @Test("legacy notebook metadata cannot restore shared TOC rows")
    func legacyNotebookMetadataCannotRestoreTOCRows() {
        let items = TOCParser.parse(notebookMarkdown)

        #expect(items.map(\.title) == ["Notebook"])
    }

    @Test("legacy notebook metadata cannot restore Lens disclosure or export surfaces")
    func legacyNotebookMetadataCannotRestoreLensSurfaces() {
        let items = LensFidelityDisclosure.items(in: notebookMarkdown, lens: .edit)

        #expect(items.isEmpty)
    }

    @Test("disclosure previews and exports use typed rendered providers")
    func disclosurePreviewsAndExportsUseTypedRenderedProviders() throws {
        let markdown = """
        ```chart
        {"type":"bar","title":"Evidence","provenance":{"kind":"dataset","datasetId":"dataset:metrics.dataset.md","range":"A1:B3","ledgerPointer":"claim:chart-evidence"},"bars":[{"label":"Alpha","value":2},{"label":"Beta","value":5}]}
        ```

        | Name | Score |
        | --- | ---: |
        | Alpha | 2 |
        | Beta, Inc | 5 |

        <!-- epistemos-quarantine:start type="future" -->
        {"future":true}
        <!-- epistemos-quarantine:end -->

        \(notebookMarkdown)
        """
        let items = LensFidelityDisclosure.items(
            in: markdown,
            lens: .edit,
            datasetExportProvider: FixtureDatasetExportProvider()
        )

        let chart = try #require(items.first { $0.type == "epdocChart" })
        if case .chart(let preview) = chart.preview {
            #expect(preview.title == "Evidence")
            #expect(preview.provenance == "claim:chart-evidence")
            #expect(preview.points.count == 2)
        } else {
            Issue.record("Chart disclosure should carry a rendered chart preview model")
        }
        #expect(chart.primaryExport?.kind == .image)
        #expect(chart.exportSuggestedFilename.hasSuffix(".svg"))
        #expect(chart.exportText.contains("<svg"))
        #expect(chart.exportText.contains("<rect"))
        #expect(chart.exportText.contains("provenance: claim:chart-evidence"))

        let table = try #require(items.first { $0.type == "table" })
        if case .table(let headers, let rows) = table.preview {
            #expect(headers == ["Name", "Score"])
            #expect(rows.count == 2)
        } else {
            Issue.record("Table disclosure should carry a rendered table preview model")
        }
        #expect(table.primaryExport?.kind == .csv)
        #expect(table.exportText.contains("Name,Score"))
        #expect(table.exportText.contains("\"Beta, Inc\",5"))

        let quarantine = try #require(items.first { $0.type == "opaqueQuarantine" })
        #expect(quarantine.primaryExport?.kind == .raw)
        #expect(quarantine.exportText.contains(#"{"future":true}"#))
        #expect(quarantine.exportText.contains("epistemos-quarantine:end"))

        #expect(!items.contains { $0.type == "notebookSheetTab" })
        #expect(!items.contains { $0.type == "datasetEmbed" })
        #expect(!items.contains { $0.type == "notebookChatTab" })
    }

    @Test("dataset references expose artifact handles without inline row payloads")
    func datasetReferencesExposeHandlesWithoutInlineRows() throws {
        let leakySheet = "77777777-7777-4777-8777-777777777777"
        let leakyEmbed = "88888888-8888-4888-8888-888888888888"
        let markdown = """
        # Notebook

        ```epistemos-notebook
        version: 1
        tab: id=\(leakySheet) type=sheet version=1 title="Leaky Metrics" ref="dataset:leaky.dataset.md" rows="Alpha,2"
        ```

        {{epistemos-ref id=\(leakyEmbed) type=sheet version=1 title="Inline Dataset" ref="dataset:inline.dataset.md" values="Beta,5"}}
        """

        let manifest = EpdocNotebookManifest.parse(in: markdown)
        let tab = try #require(manifest.tabs.first)
        #expect(tab.containsInlineRowData)
        #expect(tab.canonicalReferenceLine.contains("dataset:leaky.dataset.md"))
        #expect(!tab.canonicalReferenceLine.contains("rows"))
        #expect(!tab.canonicalReferenceLine.contains("Alpha"))

        let embed = try #require(EpdocNotebookReferenceParser.blockEmbeds(in: markdown).first)
        #expect(embed.containsInlineRowData)
        #expect(embed.canonicalReferenceLine.contains("dataset:inline.dataset.md"))
        #expect(!embed.canonicalReferenceLine.contains("values"))
        #expect(!embed.canonicalReferenceLine.contains("Beta"))

        let items = LensFidelityDisclosure.items(in: markdown, lens: .edit)
        #expect(!items.contains { $0.type == "notebookSheetTab" })
        #expect(!items.contains { $0.type == "datasetEmbed" })
    }

    @Test("chart disclosure requires provenance before rendered preview")
    func chartDisclosureRequiresProvenanceBeforeRenderedPreview() throws {
        let markdown = """
        ```chart
        {"type":"bar","title":"No provenance","bars":[{"label":"Alpha","value":2}]}
        ```
        """

        let chart = try #require(LensFidelityDisclosure.items(in: markdown, lens: .edit).first { $0.type == "epdocChart" })

        if case .raw(let raw) = chart.preview {
            #expect(raw.contains(#""type":"bar""#))
        } else {
            Issue.record("Chart without provenance should remain a raw unresolved disclosure item")
        }
        #expect(chart.primaryExport?.kind == .raw)
        #expect(!chart.exportText.contains("<svg"))
    }

    @Test("free V1 document lens does not restore chat or sheet reference surfaces")
    func freeV1DocumentLensDoesNotRestoreChatAndSheetReferenceSurfaces() throws {
        let markdown = """
        \(notebookMarkdown)

        {{epistemos-ref id=\(chatEmbed) type=chat version=1 title="Inline Chat" ref="session:inline-thread"}}
        """

        #expect(LensFidelityDisclosure.items(in: markdown, lens: .document).isEmpty)
    }

    private struct FixtureDatasetExportProvider: LensFidelityDatasetExportProviding {
        func exports(for dataset: LensFidelityDatasetReference) -> [LensFidelityExport] {
            [
                LensFidelityExport(
                    kind: .csv,
                    filename: "\(dataset.title).csv",
                    text: "reference,title\n\(dataset.reference),\(dataset.title)\n"
                ),
                LensFidelityExport(
                    kind: .xlsx,
                    filename: "\(dataset.title).xlsx",
                    data: Data([0x50, 0x4B, 0x03, 0x04])
                ),
            ]
        }
    }

    private var notebookMarkdown: String {
        """
        # Notebook

        ```epistemos-notebook
        version: 1
        tab: id=\(sheetA) type=sheet version=1 title="Metrics" ref="dataset:metrics.dataset.md"
        tab: id=\(sheetB) type=sheet version=1 title="Scratch" ref="dataset:scratch.dataset.md"
        tab: id=\(chat) type=chat version=1 title="Analysis chat" ref="session:analysis-thread"
        tab: id=\(unknown) type=chart3d version=9 title="Future chart" ref="chart:future"
        ```

        {{epistemos-ref id=\(embed) type=sheet version=1 title="Inline Dataset" ref="dataset:inline.dataset.md"}}
        """
    }
}
