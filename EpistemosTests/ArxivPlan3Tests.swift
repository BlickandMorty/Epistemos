import Foundation
import SwiftData
import Testing

@testable import Epistemos

@Suite("Plan 3 arXiv pull")
struct ArxivPlan3Tests {
    @Test("search request defaults to all-field submitted-date query")
    func searchRequest() throws {
        let request = try ArxivClient.searchRequest(query: "retrieval augmented generation", maxResults: 75)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(url.scheme == "https")
        #expect(url.host == "export.arxiv.org")
        #expect(items["search_query"] == "all:retrieval augmented generation")
        #expect(items["sortBy"] == "submittedDate")
        #expect(items["max_results"] == "50")
    }

    @Test("Atom parser extracts paper metadata and PDF link")
    func parsesAtom() throws {
        let papers = try ArxivClient.parseSearchResponse(Data(Self.atomFixture.utf8))
        #expect(papers.count == 1)
        let paper = try #require(papers.first)

        #expect(paper.shortID == "2401.12345")
        #expect(paper.title == "A Useful Paper")
        #expect(paper.authors == ["Ada Lovelace", "Grace Hopper"])
        #expect(paper.summary == "Line one. Line two.")
        #expect(paper.pdfURL.absoluteString == "https://arxiv.org/pdf/2401.12345v2")
        #expect(paper.categories == ["cs.AI", "cs.CL"])
        #expect(paper.published != nil)
    }

    @Test("gate defaults on and honors explicit kill switch")
    func gateStatus() {
        #expect(ArxivPullGateStatus.status(environment: [:]).isActive)
        #expect(!ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "0"]).isActive)
        #expect(ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "1"]).isActive)
    }

    @Test("draft includes arXiv frontmatter and parsed full text")
    func noteDraft() throws {
        let paper = try Self.paper()
        let draft = ArxivNoteDraft(paper: paper, parsedMarkdown: "## Body\n\nParsed text.")

        #expect(draft.safeBaseName.contains("A Useful Paper"))
        #expect(draft.safeBaseName.contains("2401.12345"))
        #expect(draft.frontMatter["source"] == "arxiv")
        #expect(draft.frontMatter["source_kind"] == "pdf")
        #expect(draft.frontMatter["arxiv_id"] == "2401.12345")
        #expect(draft.markdownBody.contains("## Abstract"))
        #expect(draft.markdownBody.contains("## Parsed Full Text"))
        #expect(draft.markdownBody.contains("Parsed text."))
    }

    @MainActor
    @Test("ingest writes PDF, markdown note, and source_pdf frontmatter")
    func ingestWritesVaultNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let sourcePDF = root.appendingPathComponent("download.pdf")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let outcome = await ArxivIngestService.ingest(
            paper: try Self.paper(),
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: FakeArxivImporter(result: .markdown("Converted full text.")),
            downloader: FakeArxivDownloader(fileURL: sourcePDF)
        )

        guard case .imported = outcome else {
            Issue.record("Expected arXiv ingest to import, got \(String(describing: outcome))")
            return
        }

        let pages = try context.fetch(FetchDescriptor<SDPage>())
        let page = try #require(pages.first)
        let filePath = try #require(page.filePath)
        let noteText = try String(contentsOfFile: filePath, encoding: .utf8)

        #expect(page.subfolder == ArxivIngestService.importDirectory)
        #expect(page.frontMatter["source"] == "arxiv")
        #expect(page.frontMatter["source_pdf"]?.hasPrefix("arXiv/") == true)
        #expect(noteText.contains("Converted full text."))

        let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
        #expect(FileManager.default.fileExists(atPath: vault.appendingPathComponent(sourcePDFRelative).path))
    }

    private static func paper() throws -> ArxivPaper {
        try #require(try ArxivClient.parseSearchResponse(Data(atomFixture.utf8)).first)
    }

    private static let atomFixture = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <entry>
        <id>https://arxiv.org/abs/2401.12345v2</id>
        <updated>2024-01-04T00:00:00Z</updated>
        <published>2024-01-03T12:34:56Z</published>
        <title>A Useful Paper</title>
        <summary>
          Line one.
          Line two.
        </summary>
        <author><name>Ada Lovelace</name></author>
        <author><name>Grace Hopper</name></author>
        <category term="cs.AI" />
        <category term="cs.CL" />
        <link title="pdf" href="https://arxiv.org/pdf/2401.12345v2" type="application/pdf" />
      </entry>
    </feed>
    """
}

private struct FakeArxivDownloader: ArxivPDFDownloading {
    let fileURL: URL

    func download(from _: URL) async throws -> URL {
        fileURL
    }
}

private struct FakeArxivImporter: LiteParsePDFImporter {
    let result: LiteParseImportResult

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        result
    }
}
