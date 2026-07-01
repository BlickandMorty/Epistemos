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

        #expect(throws: ArxivClientError.invalidQuery) {
            _ = try ArxivClient.searchRequest(query: String(repeating: "q", count: ArxivClient.maxSearchQueryCharacters + 1))
        }
    }

    @Test("search rejects redirected non-arXiv Atom responses")
    func searchRejectsRedirectedAtomResponses() async throws {
        let client = ArxivClient { _ in
            let responseURL = try #require(URL(string: "https://example.com/api/query"))
            let response = try #require(HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (Data(Self.atomFixture.utf8), response)
        }

        do {
            _ = try await client.search(query: "retrieval augmented generation")
            Issue.record("Expected redirected arXiv Atom response to be rejected")
        } catch let error as ArxivClientError {
            #expect(error == .invalidResponse)
        }
    }

    @Test("search rejects same-host Atom response query rewrites")
    func searchRejectsSameHostAtomResponseQueryRewrites() async throws {
        let client = ArxivClient { request in
            let requestURL = try #require(request.url)
            var components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
            components.queryItems = [
                URLQueryItem(name: "search_query", value: "all:rewritten"),
                URLQueryItem(name: "sortBy", value: "submittedDate"),
                URLQueryItem(name: "sortOrder", value: "descending"),
                URLQueryItem(name: "start", value: "0"),
                URLQueryItem(name: "max_results", value: "12"),
            ]
            let responseURL = try #require(components.url)
            let response = try #require(HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (Data(Self.atomFixture.utf8), response)
        }

        do {
            _ = try await client.search(query: "retrieval augmented generation", maxResults: 12)
            Issue.record("Expected same-host arXiv Atom query rewrite to be rejected")
        } catch let error as ArxivClientError {
            #expect(error == .invalidResponse)
        }
    }

    @Test("search diagnostics redact path-leaking transport errors")
    func searchDiagnosticsRedactPathLeakingTransportErrors() async throws {
        let privatePath = "/private/var/folders/arxiv/token.xml"
        let injected = NSError(
            domain: privatePath,
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let client = ArxivClient { _ in
            throw injected
        }

        do {
            _ = try await client.search(query: "retrieval augmented generation")
            Issue.record("Expected arXiv search transport failure to be rejected")
        } catch let error as ArxivClientError {
            guard case .requestFailed(let message) = error else {
                Issue.record("Expected .requestFailed, got \(error)")
                return
            }
            #expect(message.contains("request failed"))
            #expect(message.contains("domain=Error"))
            #expect(message.contains("code=42"))
            #expect(message.count <= ArxivSearchDiagnostics.maxFailureReasonCharacters)
            #expect(!message.contains(privatePath))
            #expect(!message.contains("failed to open"))
            #expect(!error.localizedDescription.contains(privatePath))
        }
    }

    @Test("arXiv display text normalizes embedded control characters")
    func arxivDisplayTextNormalizesEmbeddedControlCharacters() throws {
        let requestMessage = ArxivSearchDiagnostics.statusMessage(
            for: ArxivClientError.requestFailed("bad\nrequest\t\u{0007}")
        )
        let ingestMessage = ArxivIngestDiagnostics.failureReason(
            "download\nfailed\t\u{0007}",
            fallback: "download failed"
        )
        let paper = try Self.paper(
            id: "https://arxiv.org/abs/2401.12345v2\n",
            title: "Control\nTitle\t\u{0007}",
            summary: "Line\none\tline\u{0007}two",
            authors: ["Ada\nLovelace", "Grace\tHopper"],
            categories: ["cs.AI\n", "cs.CL\t"]
        )
        let draft = ArxivNoteDraft(paper: paper, parsedMarkdown: "Parsed text.")

        #expect(requestMessage == "arXiv request failed: bad request")
        #expect(ingestMessage == "download failed")
        #expect(ArxivSearchPresentation.title("Graph\nRAG\t\u{0007}") == "Graph RAG")
        #expect(ArxivSearchPresentation.authors(["Ada\nLovelace", "Grace\tHopper"]) == "Ada Lovelace, Grace Hopper")
        #expect(ArxivSearchDiagnostics.safeDomain("NS\nCocoa\tError") == "Error")
        #expect(paper.shortID == "2401.12345")
        #expect(draft.markdownBody.contains("# Control Title"))
        #expect(draft.markdownBody.contains("Line one line two"))
        #expect(draft.frontMatter["authors"] == "Ada Lovelace; Grace Hopper")
        #expect(draft.frontMatter["categories"] == "cs.AI, cs.CL")
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

    @Test("Atom parser rejects oversized responses before XML parsing")
    func rejectsOversizedAtomResponse() throws {
        let oversized = Data(repeating: 0x20, count: ArxivClient.maxSearchResponseBytes + 1)
        do {
            _ = try ArxivClient.parseSearchResponse(oversized)
            Issue.record("Expected oversized arXiv Atom response to be rejected")
        } catch let error as ArxivClientError {
            #expect(error == .parseFailed("Atom response exceeds 5 MiB limit."))
        }
    }

    @Test("Atom parser caps parsed papers and repeated values")
    func atomParserCapsParsedPapersAndRepeatedValues() throws {
        let entries = (0..<(ArxivClient.maxParsedPapers + 5))
            .map { Self.atomEntry(index: $0) }
            .joined(separator: "\n")
        let papers = try ArxivClient.parseSearchResponse(Data(Self.atomFeed(entries: entries).utf8))

        #expect(papers.count == ArxivClient.maxParsedPapers)
        #expect(papers.first?.shortID == "2401.10000")
        #expect(papers.last?.shortID == "2401.10049")

        let authors = (0..<(ArxivClient.maxAtomRepeatedValues + 5)).map { "Author \($0)" }
        let categories = (0..<(ArxivClient.maxAtomRepeatedValues + 5)).map { "cs.\($0)" }
        let repeatedValuesAtom = Self.atomFeed(entries: Self.atomEntry(
            index: 0,
            authors: authors,
            categories: categories
        ))
        let repeatedValuesPaper = try #require(
            try ArxivClient.parseSearchResponse(Data(repeatedValuesAtom.utf8)).first
        )

        #expect(repeatedValuesPaper.authors.count == ArxivClient.maxAtomRepeatedValues)
        #expect(repeatedValuesPaper.categories.count == ArxivClient.maxAtomRepeatedValues)
    }

    @Test("Atom parser caps element text before paper materialization")
    func atomParserCapsElementTextBeforeMaterialization() throws {
        let oversizedSummary = String(
            repeating: "s",
            count: ArxivClient.maxAtomElementTextCharacters + 1024
        )
        let atom = Self.atomFeed(entries: Self.atomEntry(index: 0, summary: oversizedSummary))
        let paper = try #require(try ArxivClient.parseSearchResponse(Data(atom.utf8)).first)

        #expect(paper.summary.count == ArxivClient.maxAtomElementTextCharacters)
    }

    @Test("search presentation caps network-fed display strings")
    func searchPresentationCapsNetworkFedDisplayStrings() {
        #expect(ArxivSearchPresentation.title(String(repeating: "t", count: ArxivSearchPresentation.maxTitleCharacters + 32)).count == ArxivSearchPresentation.maxTitleCharacters)
        #expect(ArxivSearchPresentation.authors([String(repeating: "a", count: ArxivSearchPresentation.maxAuthorsCharacters + 32)]).count == ArxivSearchPresentation.maxAuthorsCharacters)
        #expect(ArxivSearchPresentation.summary(String(repeating: "s", count: ArxivSearchPresentation.maxSummaryCharacters + 32)).count == ArxivSearchPresentation.maxSummaryCharacters)
        #expect(ArxivSearchPresentation.metadata(String(repeating: "m", count: ArxivSearchPresentation.maxMetadataCharacters + 32)).count == ArxivSearchPresentation.maxMetadataCharacters)
        #expect(ArxivSearchPresentation.status(String(repeating: "e", count: ArxivSearchPresentation.maxStatusMessageCharacters + 32)).count == ArxivSearchPresentation.maxStatusMessageCharacters)
    }

    @Test("arXiv external diagnostics redact malformed domains")
    func arxivExternalDiagnosticsRedactMalformedDomains() {
        let privatePath = "/private/var/folders/arxiv/download.pdf"
        let error = NSError(
            domain: privatePath,
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "download failed at \(privatePath)"]
        )
        let search = ArxivSearchDiagnostics.externalErrorDescription(error, fallback: "request failed")
        let ingest = ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "download failed")

        for message in [search, ingest] {
            #expect(message.contains("domain=Error"))
            #expect(message.contains("code=7"))
            #expect(!message.contains(privatePath))
            #expect(!message.contains("download failed at"))
        }
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

    @Test("normalizes arXiv PDF links to HTTPS and rejects downgraded final URLs")
    func normalizesArxivPDFLinksToHTTPS() throws {
        let atom = Self.atomFixture.replacingOccurrences(
            of: "https://arxiv.org/pdf/2401.12345v2",
            with: "http://arxiv.org/pdf/2401.12345v2")
        let paper = try #require(try ArxivClient.parseSearchResponse(Data(atom.utf8)).first)
        #expect(paper.pdfURL.absoluteString == "https://arxiv.org/pdf/2401.12345v2")

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-download-downgrade-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let tempPDF = root.appendingPathComponent("CFNetworkDownload_http.tmp")
        try Data("%PDF-1.7\n".utf8).write(to: tempPDF)
        let responseURL = try #require(URL(string: "http://arxiv.org/pdf/2401.12345v2"))
        let response = try #require(HTTPURLResponse(
            url: responseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))

        do {
            try URLSessionArxivPDFDownloader.validateDownloadResponse(response, downloadedFileURL: tempPDF)
            Issue.record("Expected final HTTP arXiv PDF response to be rejected")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed(ArxivPDFURLPolicy.rejectedFinalURLMessage))
        }
        #expect(!FileManager.default.fileExists(atPath: tempPDF.path))
    }

    @Test("PDF URL policy rejects non-canonical arXiv download links")
    func rejectsNonCanonicalPDFLinks() throws {
        let oldStylePDF = try #require(URL(string: "https://arxiv.org/pdf/hep-th/9901001v2"))
        #expect(ArxivPDFURLPolicy.normalizedAllowedURL(oldStylePDF)?.absoluteString == "https://arxiv.org/pdf/hep-th/9901001v2")

        for href in [
            "https://token@arxiv.org/pdf/2401.12345v2",
            "https://arxiv.org/pdf/2401.12345v2?download=1",
            "https://arxiv.org/pdf/2401.12345v2#page=1",
            "https://arxiv.org/pdf/../../abs/2401.12345",
            "https://arxiv.org/pdf/2401.12345v2/extra",
            "https://arxiv.org/pdf/2401.12345%2Fsecret",
            "https://arxiv.org/pdf/not-an-arxiv-id",
            "https://arxiv.org/pdf/",
        ] {
            let url = try #require(URL(string: href))
            #expect(ArxivPDFURLPolicy.normalizedAllowedURL(url) == nil)

            let atom = Self.atomFixture.replacingOccurrences(
                of: "https://arxiv.org/pdf/2401.12345v2",
                with: href)
            #expect(try ArxivClient.parseSearchResponse(Data(atom.utf8)).isEmpty)
        }
    }

    @Test("gate defaults on and honors explicit kill switch")
    func gateStatus() {
        #expect(ArxivPullGateStatus.isEnabled(nil))
        #expect(ArxivPullGateStatus.isEnabled("1"))
        #expect(ArxivPullGateStatus.isEnabled(" On "))
        #expect(!ArxivPullGateStatus.isEnabled("0"))
        #expect(!ArxivPullGateStatus.isEnabled(" false "))
        #expect(ArxivPullGateStatus.status(environment: [:]).isActive)
        #expect(!ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "0"]).isActive)
        #expect(ArxivPullGateStatus.status(environment: [ArxivPullGateStatus.flagName: "1"]).isActive)
    }

    @Test("Plan 3 arXiv docs describe shipped ingest state")
    func plan3ArxivDocsDescribeShippedIngestState() throws {
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_ARXIV_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let client = try loadMirroredSourceTextFile("Epistemos/Arxiv/ArxivClient.swift")
        let ingest = try loadMirroredSourceTextFile("Epistemos/Arxiv/ArxivIngestService.swift")
        let searchView = try loadMirroredSourceTextFile("Epistemos/Views/Arxiv/ArxivSearchView.swift")

        #expect(codepack.contains("shipped code"))
        #expect(codepack.contains("ArxivIngestService.swift` [DELIVERED]"))
        #expect(codepack.contains("showingArxivSearch = true"))
        #expect(codepack.contains("parser rejection with no note"))
        #expect(codepack.contains("conversion and file materialization run off"))
        #expect(codepack.contains("exceeds the 128 MiB cap"))
        #expect(codepack.contains("request/XML parser failures are reported as bounded domain/code diagnostics"))
        #expect(codepack.contains("requested HTTPS host/path/query"))
        #expect(codepack.contains("search or ingest status"))
        #expect(codepack.contains("sheet status reports that copied PDF"))
        #expect(codepack.contains("sheet disappearance cancels live work and immediately clears busy indicators"))
        #expect(codepack.contains("abstract body text is bounded before the note write"))
        #expect(codepack.contains("imported outcome's\n  vault-relative `source_pdf` matches"))
        #expect(codepack.contains("raw diagnostic and\n  metadata-label strings are bounded, control/whitespace-normalized"))
        #expect(codepack.contains("kept with ellipsis inside configured caps before display"))
        #expect(capabilities.contains("arXiv pull — SHIPPED (Pass 6)"))
        #expect(capabilities.contains("source_pdf` pointing at the copied PDF under `<vault>/arXiv/`"))
        #expect(capabilities.contains("successful ingest status reports the vault-relative `source_pdf` path"))
        #expect(capabilities.contains("capped at 128 MiB"))
        #expect(capabilities.contains("network-fed SwiftUI display strings are bounded and\n  control/whitespace-normalized before display"))
        #expect(capabilities.contains("abstract text written into the note body is bounded"))
        #expect(capabilities.contains("request/parser/status failures are mapped to bounded domain/code diagnostics"))
        #expect(capabilities.contains("requested HTTPS\n  host/path/query"))
        #expect(landing.contains(".sheet(isPresented: $showingArxivSearch)"))
        #expect(landing.contains("ArxivSearchView()"))
        #expect(client.contains("isCanonicalPDFPath"))
        #expect(client.contains("newStyleIDPattern"))
        #expect(client.contains("oldStyleIDPattern"))
        #expect(client.contains("validateSearchResponse(response, requestURL: request.url)"))
        #expect(client.contains("response.percentEncodedQuery == request.percentEncodedQuery"))
        #expect(client.contains("response.percentEncodedFragment == nil"))
        #expect(client.contains("parser.shouldResolveExternalEntities = false"))
        #expect(client.contains("maxParsedPapers"))
        #expect(client.contains("maxSearchQueryCharacters"))
        #expect(client.contains("maxAtomElementTextCharacters"))
        #expect(client.contains("maxAtomRepeatedValues"))
        #expect(client.contains("ArxivSearchDiagnostics"))
        #expect(client.contains("String(message.prefix(maxFailureReasonCharacters + 32))"))
        #expect(client.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(client.contains("normalizedDisplayText(bounded)"))
        #expect(client.contains("CharacterSet.controlCharacters"))
        #expect(client.contains("maxFailureReasonCharacters - 3"))
        #expect(client.contains("externalErrorDescription(error, fallback: \"request failed\")"))
        #expect(!client.contains("requestFailed(error.localizedDescription)"))
        #expect(!client.contains("parser.parserError?.localizedDescription"))
        #expect(searchView.contains("ArxivSearchPresentation"))
        #expect(searchView.contains("maxStatusMessageCharacters"))
        #expect(searchView.contains("String(value.prefix(limit + 32))"))
        #expect(searchView.contains("ArxivSearchDiagnostics.normalizedDisplayText(bounded)"))
        #expect(searchView.contains("String(trimmed.prefix(limit - 3))"))
        #expect(searchView.contains("ArxivSearchDiagnostics.statusMessage(for: error)"))
        #expect(searchView.contains("ToolbarCapsuleButton("))
        #expect(searchView.contains("@Environment(UIState.self)"))
        #expect(searchView.contains("ui.theme.resolved.mutedForeground.color"))
        #expect(searchView.contains("private var inputBackground: Color"))
        #expect(searchView.contains("ui.theme.surfaceVariant(.other).resolved.card.color.opacity"))
        #expect(searchView.contains(".textFieldStyle(.plain)"))
        #expect(searchView.contains("private var rowGap: some View"))
        #expect(searchView.contains("ingestActionImage(for:"))
        #expect(searchView.contains("chromePolicy: .alwaysSurface"))
        #expect(searchView.contains("Source PDF: \\(sourcePDFRelativePath)"))
        #expect(searchView.contains("ingestTasks.removeAll()\n        isSearching = false\n        ingestingIDs.removeAll()"))
        #expect(!searchView.contains("error.localizedDescription"))
        #expect(!searchView.contains(".foregroundStyle(.secondary)"))
        #expect(!searchView.contains(".foregroundStyle(.tertiary)"))
        #expect(!searchView.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!searchView.contains(".buttonStyle(.plain)"))
        #expect(!searchView.contains(".buttonStyle(.borderless)"))
        #expect(!searchView.contains("Divider()"))
        #expect(ingest.contains("materializeImportedFiles"))
        #expect(ingest.contains("maxAbstractCharacters"))
        #expect(ingest.contains("private var summaryLabel"))
        #expect(ingest.contains("ArxivSearchDiagnostics.normalizedDisplayText(bounded)"))
        #expect(ingest.contains("sourcePDFRelativePath: materializedFiles.sourcePDFRelativePath"))
        #expect(ingest.contains("maxDownloadedPDFBytes"))
        #expect(ingest.contains("destinationOfSymbolicLink"))
        #expect(ingest.contains("open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)"))
        #expect(ingest.contains("fstat(fd"))
        #expect(ingest.contains("S_IFREG"))
        #expect(ingest.contains("try validateDownloadedPDF(fileURL)"))
        #expect(ingest.contains("try validateDownloadedPDF(pdfURL)"))
        #expect(ingest.contains("Task.detached(priority: .userInitiated)"))
        #expect(ingest.contains("Plan3ImportFileIO.reservePairedFileURLs"))
        #expect(ingest.contains("Plan3ImportFileIO.writeData"))
        #expect(ingest.contains("ArxivIngestDiagnostics"))
        #expect(ingest.contains("externalErrorDescription"))
        #expect(ingest.contains("ArxivSearchDiagnostics.safeDomain"))
        #expect(ingest.contains("maxFailureReasonCharacters"))
        #expect(ingest.contains("String(message.prefix(maxFailureReasonCharacters + 32))"))
        #expect(ingest.contains("maxFailureReasonCharacters - 3"))
        #expect(ingest.contains("maxAuthorsLabelCharacters"))
        #expect(ingest.contains("maxCategoriesLabelCharacters"))
        #expect(ingest.contains("maxSourceURLCharacters"))
        #expect(ingest.contains("String(value.prefix(limit + 32))"))
        #expect(!ingest.contains("error.localizedDescription"))

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

    @Test("draft bounds persisted metadata labels")
    func noteDraftBoundsPersistedMetadataLabels() throws {
        let paper = try Self.paper(
            title: String(repeating: "T", count: ArxivNoteDraft.maxTitleCharacters + 32),
            summary: String(repeating: "S", count: ArxivNoteDraft.maxAbstractCharacters + 32),
            authors: [
                String(repeating: "A", count: ArxivNoteDraft.maxAuthorsLabelCharacters + 32),
                "Second author",
            ],
            categories: [String(repeating: "cs.", count: ArxivNoteDraft.maxCategoriesLabelCharacters)]
        )
        let draft = ArxivNoteDraft(paper: paper, parsedMarkdown: "Parsed text.")

        #expect(draft.markdownBody.contains("# \(String(repeating: "T", count: ArxivNoteDraft.maxTitleCharacters - 3))..."))
        #expect(draft.markdownBody.contains("\(String(repeating: "S", count: ArxivNoteDraft.maxAbstractCharacters - 3))..."))
        #expect(draft.frontMatter["authors"]?.count == ArxivNoteDraft.maxAuthorsLabelCharacters)
        #expect(draft.frontMatter["categories"]?.count == ArxivNoteDraft.maxCategoriesLabelCharacters)
        #expect(draft.safeBaseName.count < ArxivNoteDraft.maxTitleCharacters)
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

        let collidingTempPDF = root.appendingPathComponent("CFNetworkDownload_collision.tmp")
        let staleSiblingPDF = root.appendingPathComponent("CFNetworkDownload_collision.pdf")
        let staleSiblingBytes = Data("keep this sibling".utf8)
        try Data("%PDF-1.7\n".utf8).write(to: collidingTempPDF)
        try staleSiblingBytes.write(to: staleSiblingPDF)
        let collisionPrepared = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: collidingTempPDF)

        #expect(collisionPrepared.pathExtension == "pdf")
        #expect(collisionPrepared.lastPathComponent != staleSiblingPDF.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: collisionPrepared.path))
        #expect(!FileManager.default.fileExists(atPath: collidingTempPDF.path))
        #expect((try? Data(contentsOf: staleSiblingPDF)) == staleSiblingBytes)

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

    @Test("downloader rejects oversized and symlinked temp PDFs")
    func downloaderRejectsUnsafeTempPDFEnvelope() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-download-envelope-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let oversized = root.appendingPathComponent("CFNetworkDownload_oversized.tmp")
        try Data("%PDF-1.7\n".utf8).write(to: oversized)
        let oversizedHandle = try FileHandle(forWritingTo: oversized)
        try oversizedHandle.truncate(atOffset: UInt64(URLSessionArxivPDFDownloader.maxDownloadedPDFBytes + 1))
        try oversizedHandle.close()
        do {
            _ = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: oversized)
            Issue.record("Expected oversized arXiv PDF download to be rejected")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed("downloaded PDF exceeds 128 MiB limit"))
        }
        #expect(!FileManager.default.fileExists(atPath: oversized.path))

        let targetPDF = root.appendingPathComponent("target.pdf")
        let symlinkPDF = root.appendingPathComponent("CFNetworkDownload_symlink.tmp")
        try Data("%PDF-1.7\n".utf8).write(to: targetPDF)
        try FileManager.default.createSymbolicLink(at: symlinkPDF, withDestinationURL: targetPDF)
        do {
            _ = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: symlinkPDF)
            Issue.record("Expected symlinked arXiv PDF download to be rejected")
        } catch let error as ArxivIngestError {
            #expect(error == .downloadFailed("downloaded file is not a regular file"))
        }
        #expect(!FileManager.default.fileExists(atPath: symlinkPDF.path))
        #expect(FileManager.default.fileExists(atPath: targetPDF.path))
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
            #expect(error == .downloadFailed(ArxivPDFURLPolicy.rejectedFinalURLMessage))
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

        guard case .imported(_, _, let outcomeSourcePDFRelative) = outcome else {
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
        #expect(outcomeSourcePDFRelative == sourcePDFRelative)
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

        guard case .imported(_, _, let outcomeSourcePDFRelative) = outcome else {
            Issue.record("Expected arXiv ingest to import, got \(String(describing: outcome))")
            return
        }

        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)
        let filePath = try #require(page.filePath)
        let noteBaseName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
        #expect(outcomeSourcePDFRelative == sourcePDFRelative)
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
    @Test("concurrent ingests keep each note paired with its source PDF")
    func concurrentIngestsKeepPairedFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-concurrent-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let sourcePDF = root.appendingPathComponent("download.pdf")
        let importDir = vault.appendingPathComponent(ArxivIngestService.importDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let paper = try Self.paper()
        let importer = BarrierArxivImporter(expectedCalls: 2)
        let downloader = CopyingArxivDownloader(sourcePDF: sourcePDF, outputDirectory: root)

        let firstTask = Task { @MainActor in
            await ArxivIngestService.ingest(
                paper: paper,
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: importer,
                downloader: downloader
            )
        }
        let secondTask = Task { @MainActor in
            await ArxivIngestService.ingest(
                paper: paper,
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: importer,
                downloader: downloader
            )
        }

        let firstOutcome = await firstTask.value
        let secondOutcome = await secondTask.value
        guard case .imported = firstOutcome, case .imported = secondOutcome else {
            Issue.record("Expected both arXiv ingests to import, got \(firstOutcome) and \(secondOutcome)")
            return
        }

        let files = try FileManager.default.contentsOfDirectory(at: importDir, includingPropertiesForKeys: nil)
        let mdBases = Set(files.filter { $0.pathExtension == "md" }.map { $0.deletingPathExtension().lastPathComponent })
        let pdfBases = Set(files.filter { $0.pathExtension == "pdf" }.map { $0.deletingPathExtension().lastPathComponent })

        #expect(mdBases.count == 2)
        #expect(pdfBases.count == 2)
        #expect(mdBases == pdfBases)
        for base in mdBases {
            #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("\(base).md").path))
            #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("\(base).pdf").path))
        }
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

    @MainActor
    @Test("ingest redacts unexpected external download error descriptions")
    func ingestRedactsUnexpectedExternalDownloadErrorDescriptions() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("arxiv-ingest-redacted-download-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let privatePath = root.appendingPathComponent("private/download.pdf").path
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
            downloader: PathLeakingArxivDownloader(privatePath: privatePath)
        )

        guard case .rejected(.downloadFailed(let message)) = outcome else {
            Issue.record("Expected redacted download failure, got \(String(describing: outcome))")
            return
        }

        #expect(message.contains("download failed"))
        #expect(message.contains("PathLeakDownload"))
        #expect(message.contains(root.path) == false)
        #expect(message.contains(privatePath) == false)
        #expect(message.count <= ArxivIngestDiagnostics.maxFailureReasonCharacters)
        #expect(ArxivIngestError.downloadFailed(message).localizedDescription.contains(root.path) == false)
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(ArxivIngestService.importDirectory).path))
    }

    private static func paper(
        id: String = "https://arxiv.org/abs/2401.12345v2",
        title: String = "A Useful Paper",
        summary: String = "Line one. Line two.",
        authors: [String] = ["Ada Lovelace", "Grace Hopper"],
        categories: [String] = ["cs.AI", "cs.CL"]
    ) throws -> ArxivPaper {
        ArxivPaper(
            id: id,
            title: title,
            authors: authors,
            summary: summary,
            published: try #require(ISO8601DateFormatter.arxivIngest.date(from: "2024-01-03T12:34:56Z")),
            pdfURL: try #require(URL(string: "https://arxiv.org/pdf/2401.12345v2")),
            categories: categories
        )
    }

    private nonisolated static let atomFixture = """
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

    private static func atomFeed(entries: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
        \(entries)
        </feed>
        """
    }

    private static func atomEntry(
        index: Int,
        summary: String = "A bounded summary.",
        authors: [String] = ["Ada Lovelace"],
        categories: [String] = ["cs.AI"]
    ) -> String {
        let numericID = String(format: "2401.%05d", 10000 + index)
        let authorXML = authors
            .map { "<author><name>\($0)</name></author>" }
            .joined(separator: "\n")
        let categoryXML = categories
            .map { "<category term=\"\($0)\" />" }
            .joined(separator: "\n")
        return """
          <entry>
            <id>https://arxiv.org/abs/\(numericID)v1</id>
            <published>2024-01-03T12:34:56Z</published>
            <title>Paper \(index)</title>
            <summary>\(summary)</summary>
            \(authorXML)
            \(categoryXML)
            <link title="pdf" href="https://arxiv.org/pdf/\(numericID)v1" type="application/pdf" />
          </entry>
        """
    }
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

private final class BarrierArxivImporter: LiteParsePDFImporter, @unchecked Sendable {
    private let expectedCalls: Int
    private let lock = NSLock()
    private let release = DispatchSemaphore(value: 0)
    private var calls = 0

    init(expectedCalls: Int) {
        self.expectedCalls = expectedCalls
    }

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        lock.lock()
        calls += 1
        let shouldRelease = calls == expectedCalls
        lock.unlock()

        if shouldRelease {
            for _ in 0..<expectedCalls {
                release.signal()
            }
        }
        _ = release.wait(timeout: .now() + .seconds(2))
        return .markdown("Converted full text.")
    }
}

private final class CopyingArxivDownloader: ArxivPDFDownloading, @unchecked Sendable {
    private let sourcePDF: URL
    private let outputDirectory: URL
    private let lock = NSLock()
    private var nextIndex = 0

    init(sourcePDF: URL, outputDirectory: URL) {
        self.sourcePDF = sourcePDF
        self.outputDirectory = outputDirectory
    }

    func download(from _: URL) async throws -> URL {
        let index = lock.withLock {
            nextIndex += 1
            return nextIndex
        }

        let copy = outputDirectory.appendingPathComponent("download-\(index).pdf")
        try FileManager.default.copyItem(at: sourcePDF, to: copy)
        return copy
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

private struct PathLeakingArxivDownloader: ArxivPDFDownloading {
    let privatePath: String

    func download(from _: URL) async throws -> URL {
        throw NSError(
            domain: "PathLeakDownload",
            code: 17,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
    }
}
