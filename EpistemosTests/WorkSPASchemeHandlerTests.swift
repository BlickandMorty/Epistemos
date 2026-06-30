import Foundation
import Testing
@testable import Epistemos

@Suite("Work SPA scheme handler — bundle path mapping (Spike-B embed infra)")
struct WorkSPASchemeHandlerTests {
    /// A temp `dist/`-shaped root: `index.html` + `assets/app.js`.
    private func makeRoot() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-spa-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try "<html>root</html>".write(
            to: base.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try "console.log(1)".write(
            to: base.appendingPathComponent("assets/app.js"), atomically: true, encoding: .utf8)
        try "console.log(2)".write(
            to: base.appendingPathComponent("assets/app space.js"), atomically: true, encoding: .utf8)
        return base
    }

    private func request(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }

    @Test("root path `/` serves index.html")
    func rootServesIndex() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let resolved = try WorkSPASchemeHandler.resolve(request: request("epwork://app/"), root: root)
        #expect(resolved.lastPathComponent == "index.html")
    }

    @Test("an existing asset path serves that asset")
    func assetPathServesAsset() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let resolved = try WorkSPASchemeHandler.resolve(request: request("epwork://app/assets/app.js"), root: root)
        #expect(resolved.lastPathComponent == "app.js")
        #expect(resolved.deletingLastPathComponent().lastPathComponent == "assets")
    }

    @Test("percent-encoded asset paths are decoded before lookup")
    func percentEncodedAssetPathServesAsset() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let resolved = try WorkSPASchemeHandler.resolve(request: request("epwork://app/assets/app%20space.js"), root: root)
        #expect(resolved.lastPathComponent == "app space.js")
    }

    @Test("extension-less deep link (SPA client-side route) falls back to index.html")
    func deepLinkFallsBackToIndex() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let resolved = try WorkSPASchemeHandler.resolve(request: request("epwork://app/settings/models"), root: root)
        #expect(resolved.lastPathComponent == "index.html")
    }

    @Test("optional virtual base path maps cache-isolated SPA URLs back to the bundle root")
    func virtualBasePathMapsBackToBundleRoot() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let index = try WorkSPASchemeHandler.resolve(
            request: request("epwork://app/__epistemos-goose/test-build/"),
            root: root,
            virtualBasePath: "/__epistemos-goose/test-build"
        )
        #expect(index.lastPathComponent == "index.html")

        let asset = try WorkSPASchemeHandler.resolve(
            request: request("epwork://app/__epistemos-goose/test-build/assets/app.js"),
            root: root,
            virtualBasePath: "/__epistemos-goose/test-build"
        )
        #expect(asset.lastPathComponent == "app.js")
        #expect(asset.deletingLastPathComponent().lastPathComponent == "assets")
    }

    @Test("a missing file WITH an extension is notFound (no silent index fallback)")
    func missingAssetIsNotFound() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: WorkSPASchemeHandler.HandlerError.notFound) {
            try WorkSPASchemeHandler.resolve(request: request("epwork://app/assets/missing.js"), root: root)
        }
    }

    @Test("path traversal can never escape the served root")
    func pathTraversalNeverEscapes() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // Whether URL keeps `..` (our guard throws) or collapses it (stays in-root), it must never serve /etc.
        do {
            let resolved = try WorkSPASchemeHandler.resolve(
                request: request("epwork://app/../../../etc/hosts"), root: root)
            #expect(resolved.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path))
        } catch let error as WorkSPASchemeHandler.HandlerError {
            #expect(error == .outsideRoot || error == .notFound)
        }
    }

    @Test("percent-encoded traversal is decoded and still cannot escape root")
    func encodedPathTraversalNeverEscapes() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: WorkSPASchemeHandler.HandlerError.outsideRoot) {
            try WorkSPASchemeHandler.resolve(request: request("epwork://app/%2E%2E/%2E%2E/etc/hosts"), root: root)
        }
    }

    @Test("symlinks inside the served root cannot point outside the root")
    func symlinkTraversalNeverEscapes() throws {
        let root = try makeRoot()
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-spa-outside-\(UUID().uuidString).txt")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try "outside".write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside.txt"),
            withDestinationURL: outside)

        #expect(throws: WorkSPASchemeHandler.HandlerError.outsideRoot) {
            try WorkSPASchemeHandler.resolve(request: request("epwork://app/outside.txt"), root: root)
        }
    }

    @Test("MIME types cover the SPA's asset kinds")
    func mimeTypes() {
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/index.html")).hasPrefix("text/html"))
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/app.js")).hasPrefix("text/javascript"))
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/s.css")).hasPrefix("text/css"))
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/i.svg")) == "image/svg+xml")
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/m.wasm")) == "application/wasm")
        #expect(WorkSPASchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/f.woff2")) == "font/woff2")
    }

    @Test("served file reads are bounded before loading into memory")
    func servedFileReadsAreBounded() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let oversized = root.appendingPathComponent("assets/oversized.js")
        try createSparseFile(oversized, size: WorkSPASchemeHandler.maxServedFileBytes + 1)

        #expect(throws: WorkSPASchemeHandler.HandlerError.fileTooLarge) {
            try WorkSPASchemeHandler.readServedFile(oversized)
        }
        #expect(try WorkSPASchemeHandler.readServedFile(root.appendingPathComponent("assets/app.js")).count > 0)
    }

    @Test("response carries 200 + Content-Type + Content-Length")
    func responseShape() {
        let response = WorkSPASchemeHandler.response(
            requestURL: URL(string: "epwork://app/assets/app.js")!,
            fileURL: URL(fileURLWithPath: "/x/app.js"), byteCount: 42)
        #expect(response.statusCode == 200)
        #expect((response.value(forHTTPHeaderField: "Content-Type") ?? "").hasPrefix("text/javascript"))
        #expect(response.value(forHTTPHeaderField: "Content-Length") == "42")
        #expect(response.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        #expect(response.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff")

        let htmlResponse = WorkSPASchemeHandler.response(
            requestURL: URL(string: "epwork://app/")!,
            fileURL: URL(fileURLWithPath: "/x/index.html"), byteCount: 10)
        #expect(htmlResponse.value(forHTTPHeaderField: "Cache-Control") == "no-store")
    }
}

private func createSparseFile(_ url: URL, size: Int) throws {
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: UInt64(size))
    try handle.close()
}
