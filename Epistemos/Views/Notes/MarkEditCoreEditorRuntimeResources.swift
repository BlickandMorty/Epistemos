import Foundation
import WebKit

enum MarkEditCoreEditorDocument {
    static func html(for state: MarkEditCoreEditorState) -> String {
        guard let template = templateHTML,
              let configJSON = state.configJSON else {
            return fallbackHTML
        }
        return template
            .replacingOccurrences(of: "/chunk-loader/", with: "\(MarkEditCoreEditorBridge.chunkScheme)://")
            .replacingOccurrences(of: "\"{{EDITOR_CONFIG}}\"", with: configJSON)
            .replacingOccurrences(of: "\"{{USER_SETTINGS}}\"", with: "{}")
    }

    private static var templateHTML: String? {
        if let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: MarkEditCoreEditorBridge.resourceSubpath
        ),
           let html = try? String(contentsOf: url, encoding: .utf8) {
            return html
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Epistemos/Resources")
            .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath)
            .appendingPathComponent("index.html")
        return try? String(contentsOf: repoURL, encoding: .utf8)
    }

    private static let fallbackHTML = """
    <!doctype html>
    <html>
    <body style="font: 13px -apple-system; padding: 16px;">
      MarkEdit CoreEditor bundle is missing.
    </body>
    </html>
    """
}

final class MarkEditCoreEditorChunkLoader: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let relativePath = Self.relativePath(for: url),
              let fileURL = Self.fileURL(relativePath: relativePath),
              let mimeType = Self.mimeTypes[fileURL.pathExtension.lowercased()],
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(Self.error(for: urlSchemeTask.request.url))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Access-Control-Allow-Origin": "*",
                "Content-Type": mimeType,
            ]
        ) ?? URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func relativePath(for url: URL) -> String? {
        guard url.scheme == MarkEditCoreEditorBridge.chunkScheme,
              let host = url.host,
              host == "chunks" else { return nil }
        let pathComponents = url.path
            .split(separator: "/")
            .map(String.init)
        guard !pathComponents.isEmpty,
              pathComponents.allSatisfy(Self.isSafeRelativePathComponent) else { return nil }
        return ([host] + pathComponents).joined(separator: "/")
    }

    private static func fileURL(relativePath: String) -> URL? {
        let repoResourcesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Epistemos/Resources", isDirectory: true)
        let roots = [
            Bundle.main.resourceURL?
                .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath, isDirectory: true),
            Bundle.main.resourceURL,
            repoResourcesURL
                .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath, isDirectory: true),
            repoResourcesURL,
        ].compactMap { $0?.resolvingSymlinksInPath().standardizedFileURL }

        for root in roots {
            let candidate = root
                .appendingPathComponent(relativePath)
                .resolvingSymlinksInPath()
                .standardizedFileURL
            if isDescendant(candidate, of: root),
               isRegularFile(candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func isSafeRelativePathComponent(_ component: String) -> Bool {
        !component.isEmpty &&
            component != "." &&
            component != ".." &&
            !component.contains("\\")
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = candidate.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func error(for url: URL?) -> NSError {
        NSError(
            domain: "MarkEditCoreEditorChunkLoader",
            code: 1,
            userInfo: [NSURLErrorKey: url?.absoluteString ?? ""]
        )
    }

    private static let mimeTypes = [
        "js": "text/javascript",
        "css": "text/css",
        "woff2": "font/woff2",
    ]
}
