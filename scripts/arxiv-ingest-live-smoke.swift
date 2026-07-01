import Foundation
import SwiftData

@main
enum ArxivIngestLiveSmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("arXiv ingest live smoke failed: \(message)\n".utf8))
        exit(1)
    }

    @MainActor
    static func main() async {
        let pdfURL = URL(string: CommandLine.arguments.dropFirst().first ?? "https://arxiv.org/pdf/2106.14834")!
        let paper = ArxivPaper(
            id: pdfURL.absoluteString.replacingOccurrences(of: "/pdf/", with: "/abs/"),
            title: "Epistemos arXiv Live Smoke",
            authors: ["Epistemos Smoke"],
            summary: "Live arXiv ingest smoke.",
            published: nil,
            pdfURL: pdfURL,
            categories: ["cs.AI"]
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-arxiv-live-smoke-\(UUID().uuidString)", isDirectory: true)
        let vault = root.appendingPathComponent("Vault", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        } catch {
            fail("could not create temp vault: \(error)")
        }

        let container: ModelContainer
        do {
            let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fail("could not create SwiftData container: \(error)")
        }

        let context = ModelContext(container)
        let outcome = await ArxivIngestService.ingest(
            paper: paper,
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: LiveLiteParsePDFImporter(),
            downloader: URLSessionArxivPDFDownloader()
        )

        guard case .imported(_, _, let outcomeSourcePDF) = outcome else {
            fail("ingest returned \(outcome)")
        }

        let pages: [SDPage]
        do {
            pages = try context.fetch(FetchDescriptor<SDPage>())
        } catch {
            fail("could not fetch imported page: \(error)")
        }
        guard let page = pages.first else {
            fail("no SDPage inserted")
        }

        guard page.subfolder == ArxivIngestService.importDirectory else {
            fail("unexpected subfolder: \(page.subfolder ?? "nil")")
        }
        guard let sourcePDF = page.frontMatter["source_pdf"], sourcePDF.hasPrefix("arXiv/") else {
            fail("missing source_pdf frontmatter: \(page.frontMatter)")
        }
        guard outcomeSourcePDF == sourcePDF else {
            fail("outcome source_pdf \(outcomeSourcePDF) did not match frontmatter \(sourcePDF)")
        }
        let copiedPDF = vault.appendingPathComponent(sourcePDF, isDirectory: false)
        guard copiedPDF.pathExtension.lowercased() == "pdf",
              FileManager.default.fileExists(atPath: copiedPDF.path) else {
            fail("copied source_pdf is missing or not a PDF: \(sourcePDF)")
        }
        guard let filePath = page.filePath,
              FileManager.default.fileExists(atPath: filePath) else {
            fail("note file was not written")
        }
        let noteText = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
        guard noteText.contains("## Parsed Full Text"), !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail("note markdown missing parsed full text")
        }

        print("arXiv ingest live smoke OK: downloaded=true parsed=true note=true outcome_source_pdf=true source_pdf=\(sourcePDF)")
    }
}
