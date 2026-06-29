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

    @Test("rejects non-arXiv PDF URLs before download")
    func rejectsNonArxivPDFURLs() async throws {
        for href in [
            "file:///tmp/private.pdf",
            "https://example.com/pdf/2401.12345v2",
        ] {
            let atom = Self.atomFixture.replacingOccurrences(
                of: "https://arxiv.org/pdf/2401.12345v2",
                with: href)
            #expect(try ArxivClient.parseSearchResponse(Data(atom.utf8)).isEmpty)
        }

        do {
            _ = try await URLSessionArxivPDFDownloader().download(from: URL(fileURLWithPath: "/tmp/private.pdf"))
            Issue.record("Expected downloader to reject a non-arXiv PDF URL before transport")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed(ArxivPDFURLPolicy.rejectedMessage))
        }
    }

    @Test("gate defaults on and honors explicit kill switch")
    func gateStatus() {
        #expect(ArxivPullGateStatus.status(environment: [:]).isActive)
        #expect(!ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "0"]).isActive)
        #expect(ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "1"]).isActive)
    }

    @Test("Plan 3 arXiv docs describe shipped ingest state")
    func plan3ArxivDocsDescribeShippedIngestState() throws {
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_ARXIV_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let ingest = try loadMirroredSourceTextFile("Epistemos/Arxiv/ArxivIngestService.swift")

        #expect(codepack.contains("shipped code"))
        #expect(codepack.contains("ArxivIngestService.swift` [DELIVERED]"))
        #expect(codepack.contains("showingArxivSearch = true"))
        #expect(codepack.contains("parser rejection with no note"))
        #expect(codepack.contains("conversion and file materialization run off"))
        #expect(capabilities.contains("arXiv pull — SHIPPED (Pass 6)"))
        #expect(capabilities.contains("source_pdf` pointing at the copied PDF under `<vault>/arXiv/`"))
        #expect(landing.contains(".sheet(isPresented: $showingArxivSearch)"))
        #expect(landing.contains("ArxivSearchView()"))
        #expect(ingest.contains("materializeImportedFiles"))
        #expect(ingest.contains("Task.detached(priority: .userInitiated)"))
        #expect(ingest.contains("nonisolated private static func uniquePairedFileURLs"))

        for stale in [
            "clone-ready code",
            "[INFERRED]",
            "until the\n  PDF engine (EdgeParse §1) lands",
        ] where codepack.contains(stale) {
            Issue.record("arXiv codepack still contains stale phrase: \(stale)")
        }
        for stale in [
            "Was **omitted entirely** from the curation",
            "arXiv pull** — search arXiv",
        ] where capabilities.contains(stale) {
            Issue.record("Plan 3 capabilities still contains stale arXiv phrase: \(stale)")
        }
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

    @Test("downloader prepares extensionless temp PDFs and rejects non-PDF bodies")
    func downloaderPreparesExtensionlessPDF() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-download-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let tempPDF = root.appendingPathComponent("CFNetworkDownload_123.tmp")
        try Data("%PDF-1.7\n".utf8).write(to: tempPDF)
        let prepared = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: tempPDF)

        #expect(prepared.pathExtension == "pdf")
        #expect(FileManager.default.fileExists(atPath: prepared.path))
        #expect(!FileManager.default.fileExists(atPath: tempPDF.path))

        let htmlTemp = root.appendingPathComponent("CFNetworkDownload_html.tmp")
        try Data("<html>rate limited</html>".utf8).write(to: htmlTemp)
        do {
            _ = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: htmlTemp)
            Issue.record("Expected non-PDF arXiv download body to be rejected")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed("downloaded file is not a PDF (%PDF- header missing)"))
        }
        #expect(!FileManager.default.fileExists(atPath: htmlTemp.path))
    }

    @Test("downloader rejects redirected non-arXiv final URLs")
    func downloaderRejectsRedirectedNonArxivFinalURLs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-download-redirect-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let tempPDF = root.appendingPathComponent("CFNetworkDownload_456.tmp")
        try Data("%PDF-1.7\n".utf8).write(to: tempPDF)
        let redirectedURL = try #require(URL(string: "https://example.com/pdf/2401.12345"))
        let response = try #require(HTTPURLResponse(
            url: redirectedURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))

        do {
            try URLSessionArxivPDFDownloader.validateDownloadResponse(response, downloadedFileURL: tempPDF)
            Issue.record("Expected non-arXiv final response URL to be rejected")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed("final response URL is not an allowed arXiv PDF URL"))
        }
        #expect(!FileManager.default.fileExists(atPath: tempPDF.path))
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

    @MainActor
    @Test("ingest keeps duplicate note and source PDF basenames paired")
    func ingestKeepsDuplicateNoteAndSourcePDFBasenamesPaired() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-collision-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let importDir = vault.appendingPathComponent(ArxivIngestService.importDirectory, isDirectory: true)
        let sourcePDF = root.appendingPathComponent("download.pdf")
        let paper = try Self.paper()
        let baseName = ArxivNoteDraft(paper: paper, parsedMarkdown: "").safeBaseName
        try FileManager.default.createDirectory(at: importDir, withIntermediateDirectories: true)
        try Data("existing imported note".utf8).write(to: importDir.appendingPathComponent("\(baseName).md"))
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let outcome = await ArxivIngestService.ingest(
            paper: paper,
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

        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)
        let filePath = try #require(page.filePath)
        let noteBaseName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
        let sourcePDFBaseName = vault
            .appendingPathComponent(sourcePDFRelative)
            .deletingPathExtension()
            .lastPathComponent

        #expect(noteBaseName == "\(baseName) 2")
        #expect(sourcePDFBaseName == noteBaseName)
        #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("\(baseName) 2.md").path))
        #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("\(baseName) 2.pdf").path))
    }

    @MainActor
    @Test("ingest rejects a symlinked arXiv import directory")
    func ingestRejectsSymlinkedImportDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-symlink-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        let importLink = vault.appendingPathComponent(ArxivIngestService.importDirectory, isDirectory: true)
        let sourcePDF = root.appendingPathComponent("download.pdf")
        let paper = try Self.paper()
        let baseName = ArxivNoteDraft(paper: paper, parsedMarkdown: "").safeBaseName
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: importLink, withDestinationURL: outside)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let outcome = await ArxivIngestService.ingest(
            paper: paper,
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: FakeArxivImporter(result: .markdown("Converted full text.")),
            downloader: FakeArxivDownloader(fileURL: sourcePDF)
        )

        #expect(outcome == .rejected(.fileWriteFailed(Plan3VaultPath.outsideVaultMessage)))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("\(baseName).md").path))
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("\(baseName).pdf").path))
    }

    @MainActor
    @Test("ingest rejects parser failure without writing a vault note")
    func ingestRejectsParserFailureWithoutVaultNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-reject-\(UUID().uuidString)")
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
            importer: FakeArxivImporter(result: .notWired),
            downloader: FakeArxivDownloader(fileURL: sourcePDF)
        )

        #expect(outcome == .rejected(.pdfImportRejected(.notWired)))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(ArxivIngestService.importDirectory).path))
    }

    @MainActor
    @Test("cancelled ingest does not materialize a vault note")
    func cancelledIngestDoesNotMaterializeVaultNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-cancel-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let sourcePDF = root.appendingPathComponent("download.pdf")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let task = Task { @MainActor in
            await ArxivIngestService.ingest(
                paper: try Self.paper(),
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: SlowArxivImporter(delay: 0.12),
                downloader: FakeArxivDownloader(fileURL: sourcePDF)
            )
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()

        let outcome = try await task.value
        #expect(outcome == .rejected(.cancelled))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(ArxivIngestService.importDirectory).path))
    }

    @MainActor
    @Test("ingest rejects download failure without writing a vault note")
    func ingestRejectsDownloadFailureWithoutVaultNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-download-reject-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
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
            importer: FakeArxivImporter(result: .markdown("Should not run.")),
            downloader: FailingArxivDownloader()
        )

        #expect(outcome == .rejected(.downloadFailed("offline")))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(ArxivIngestService.importDirectory).path))
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

private struct SlowArxivImporter: LiteParsePDFImporter {
    let delay: TimeInterval

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        Thread.sleep(forTimeInterval: delay)
        return .markdown("Converted after cancellation.")
    }
}

private struct FailingArxivDownloader: ArxivPDFDownloading {
    func download(from _: URL) async throws -> URL {
        throw ArxivIngestError.downloadFailed("offline")
    }
}
