import Foundation
import UniformTypeIdentifiers
import WebKit

// Spike-B step 4 infra (2026-06-24): serves the built OpenWork SPA (`apps/app/dist/`) to the macOS-26 `WebPage`
// over a CUSTOM URL scheme. Why a scheme handler and not `page.load(fileURL)`: the SPA ships ES-module scripts
// (`<script type="module" src="./assets/app-*.js">`), which the `file://` origin blocks; a custom scheme is a
// normal web origin, so modules + fetch work. The bundle was built with `OPENWORK_ELECTRON_BUILD=1` → relative
// (`./`) asset URLs, so every asset request resolves under the served root.
//
// Decoupled from WHERE `dist/` lives (the bundling decision is still open — synchronized-folder Resources vs the
// loopback `apps/server` runtime): this handler just serves a configurable `root` directory, so it works for the
// spike (serve the donor `dist/`) and for the shipped bundle alike, and its mapping logic is unit-testable from a
// temp dir with no WebView. Path-traversal guarded — a request can never escape `root`.
nonisolated struct WorkSPASchemeHandler: URLSchemeHandler {
    /// The directory the SPA bundle (`dist/`, containing `index.html` + `assets/`) lives in.
    let root: URL
    let virtualBasePath: String?

    init(root: URL, virtualBasePath: String? = nil) {
        self.root = root
        self.virtualBasePath = Self.normalizedVirtualBasePath(virtualBasePath)
    }

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, Error> {
        let root = self.root
        let virtualBasePath = self.virtualBasePath
        return AsyncThrowingStream { continuation in
            do {
                let fileURL = try Self.resolve(request: request, root: root, virtualBasePath: virtualBasePath)
                let data = try Self.readServedFile(fileURL)
                continuation.yield(.response(Self.response(requestURL: request.url ?? fileURL, fileURL: fileURL, byteCount: data.count)))
                continuation.yield(.data(data))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - Pure, testable mapping

    enum HandlerError: Error, Equatable { case outsideRoot, notFound, fileTooLarge }
    static let maxServedFileBytes = 128 * 1024 * 1024

    /// Map a request URL → a concrete file under `root`. Rules: empty/`/` → `index.html`; an existing file →
    /// itself; a non-existent EXTENSION-LESS path → `index.html` (SPA client-side routing deep links). Guards
    /// against path traversal (the resolved file must stay within `root`).
    static func resolve(request: URLRequest, root: URL, virtualBasePath: String? = nil) throws -> URL {
        try resolve(path: request.url?.path ?? "/", root: root, virtualBasePath: virtualBasePath)
    }

    /// Path-based variant (reused by `WorkSPAServer`, which parses the request line itself).
    static func resolve(path rawPath: String, root: URL, virtualBasePath: String? = nil) throws -> URL {
        let rootStd = root.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedPath = stripVirtualBasePath(
            from: rawPath,
            virtualBasePath: normalizedVirtualBasePath(virtualBasePath)
        )
        var relative = resolvedPath.hasPrefix("/") ? String(resolvedPath.dropFirst()) : resolvedPath
        if let decoded = relative.removingPercentEncoding {
            relative = decoded
        }
        guard !relative.contains("\0") else { throw HandlerError.outsideRoot }
        if relative.isEmpty { relative = "index.html" }

        var candidate = root.standardizedFileURL.appendingPathComponent(relative).standardizedFileURL
        guard isInside(candidate, root: root.standardizedFileURL) else {
            throw HandlerError.outsideRoot
        }

        if !FileManager.default.fileExists(atPath: candidate.path), candidate.pathExtension.isEmpty {
            candidate = rootStd.appendingPathComponent("index.html")
        }
        guard FileManager.default.fileExists(atPath: candidate.path) else { throw HandlerError.notFound }
        let resolved = candidate.resolvingSymlinksInPath()
        guard isInside(resolved, root: rootStd) else { throw HandlerError.outsideRoot }
        return resolved
    }

    private static func isInside(_ candidate: URL, root: URL) -> Bool {
        candidate.path == root.path || candidate.path.hasPrefix(root.path + "/")
    }

    private static func normalizedVirtualBasePath(_ raw: String?) -> String? {
        guard var path = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        guard !path.contains("\0"), !path.split(separator: "/").contains("..") else { return nil }
        return path
    }

    private static func stripVirtualBasePath(from rawPath: String, virtualBasePath: String?) -> String {
        guard let virtualBasePath else { return rawPath }
        if rawPath == virtualBasePath {
            return "/"
        }
        if rawPath.hasPrefix(virtualBasePath + "/") {
            return String(rawPath.dropFirst(virtualBasePath.count))
        }
        return rawPath
    }

    /// Content-Type for the served file (explicit map for the SPA's asset kinds; UTType fallback otherwise).
    static func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json", "map": return "application/json; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "wasm": return "application/wasm"
        case let ext:
            return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    static func readServedFile(_ fileURL: URL, maxBytes: Int = maxServedFileBytes) throws -> Data {
        guard let size = regularFileSize(fileURL),
              size <= UInt64(maxBytes) else {
            throw HandlerError.fileTooLarge
        }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: maxBytes + 1),
              data.count <= maxBytes else {
            throw HandlerError.fileTooLarge
        }
        return data
    }

    private static func regularFileSize(_ fileURL: URL) -> UInt64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.uint64Value
    }

    static func response(requestURL: URL, fileURL: URL, byteCount: Int) -> HTTPURLResponse {
        let isHTML = fileURL.pathExtension.lowercased() == "html"
        return HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType(for: fileURL),
                "Content-Length": String(byteCount),
                "Cache-Control": isHTML ? "no-store" : "no-cache",
                "X-Content-Type-Options": "nosniff",
            ]) ?? HTTPURLResponse()
    }
}
