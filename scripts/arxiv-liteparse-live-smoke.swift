import Foundation

@main
enum ArxivLiteParseLiveSmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("arXiv liteparse live smoke failed: \(message)\n".utf8))
        exit(1)
    }

    static func main() {
        guard CommandLine.arguments.count == 2 else {
            fail("usage: arxiv-liteparse-live-smoke <pdf>")
        }

        let pdfPath = CommandLine.arguments[1]
        let status = liteparseStatusJson()
        guard
            let statusData = status.data(using: .utf8),
            let statusJSON = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any]
        else {
            fail("liteparse status was not JSON: \(status)")
        }

        guard statusJSON["engine_wired"] as? Bool == true else {
            fail("liteparse engine is not wired: \(status)")
        }

        let result = LiveLiteParsePDFImporter().importToMarkdown(pdfPath: pdfPath)
        guard case .markdown(let markdown) = result else {
            fail("live importer returned \(result)")
        }

        guard markdown.localizedCaseInsensitiveContains("Sample PDF") else {
            fail("markdown did not contain fixture text")
        }

        print("arXiv liteparse live smoke OK: engine_wired=true markdown_chars=\(markdown.count)")
    }
}
