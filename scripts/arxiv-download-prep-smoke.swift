import Foundation

@main
enum ArxivDownloadPrepSmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("arXiv download prep smoke failed: \(message)\n".utf8))
        exit(1)
    }

    static func main() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-arxiv-download-prep-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            fail("could not create temp directory: \(error)")
        }

        let tempPDF = root.appendingPathComponent("CFNetworkDownload_collision.tmp")
        let staleSiblingPDF = root.appendingPathComponent("CFNetworkDownload_collision.pdf")
        let staleSiblingBytes = Data("keep this sibling".utf8)

        do {
            try Data("%PDF-1.7\n".utf8).write(to: tempPDF)
            try staleSiblingBytes.write(to: staleSiblingPDF)
        } catch {
            fail("could not write fixtures: \(error)")
        }

        let prepared: URL
        do {
            prepared = try URLSessionArxivPDFDownloader.prepareDownloadedPDF(from: tempPDF)
        } catch {
            fail("prepareDownloadedPDF rejected valid temp PDF: \(error)")
        }

        guard prepared.pathExtension == "pdf" else {
            fail("prepared file did not get .pdf extension: \(prepared.lastPathComponent)")
        }
        guard prepared.lastPathComponent != staleSiblingPDF.lastPathComponent else {
            fail("prepared file reused the stale sibling destination")
        }
        guard !FileManager.default.fileExists(atPath: tempPDF.path) else {
            fail("original temp file still exists")
        }
        guard FileManager.default.fileExists(atPath: prepared.path) else {
            fail("prepared PDF missing at \(prepared.path)")
        }
        guard (try? Data(contentsOf: staleSiblingPDF)) == staleSiblingBytes else {
            fail("stale sibling PDF was modified or removed")
        }

        print("arXiv download prep smoke OK: prepared=\(prepared.lastPathComponent) stale_sibling_preserved=true")
    }
}
