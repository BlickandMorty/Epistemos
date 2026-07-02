import Foundation

private final class SourceMirrorBundleLocator {}

nonisolated func sourceMirrorRootURL() throws -> URL {
    let bundle = Bundle(for: SourceMirrorBundleLocator.self)
    guard let resourceURL = bundle.resourceURL else {
        throw CocoaError(.fileNoSuchFile)
    }

    let rootURL = resourceURL.appendingPathComponent("SourceMirror", isDirectory: true)
    guard FileManager.default.fileExists(atPath: rootURL.path) else {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: rootURL.path])
    }

    return rootURL
}

nonisolated func sourceMirrorURL(for relativePath: String) throws -> URL {
    let mirroredURL = try sourceMirrorRootURL().appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: mirroredURL.path) {
        return mirroredURL
    }

    if let checkoutRootURL = sourceCheckoutRootURL() {
        let checkoutURL = checkoutRootURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: checkoutURL.path) {
            return checkoutURL
        }
    }

    return mirroredURL
}

nonisolated private func sourceCheckoutRootURL() -> URL? {
    let fileURL = URL(fileURLWithPath: #filePath)
    let candidateStarts = [
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        fileURL.deletingLastPathComponent().deletingLastPathComponent(),
    ]

    for startURL in candidateStarts {
        var cursor = startURL
        for _ in 0..<8 {
            let agentsURL = cursor.appendingPathComponent("AGENTS.md")
            let editorManifestURL = cursor.appendingPathComponent("js-editor/package.json")
            if FileManager.default.fileExists(atPath: agentsURL.path),
               FileManager.default.fileExists(atPath: editorManifestURL.path) {
                return cursor
            }

            let parentURL = cursor.deletingLastPathComponent()
            guard parentURL.path != cursor.path else { break }
            cursor = parentURL
        }
    }

    return nil
}

nonisolated func loadMirroredSourceDataFile(_ relativePath: String) throws -> Data {
    let url = try regularMirroredSourceFileURL(for: relativePath)
    let handle = try FileHandle(forReadingFrom: url)
    defer {
        try? handle.close()
    }
    return try handle.readToEnd() ?? Data()
}

nonisolated func loadMirroredSourceTextFile(_ relativePath: String) throws -> String {
    String(decoding: try loadMirroredSourceDataFile(relativePath), as: UTF8.self)
}

nonisolated func loadHTMLWorkspaceEditorSourceBundle() throws -> String {
    try [
        "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift",
        "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPackageActions.swift",
    ]
    .map(loadMirroredSourceTextFile)
    .joined(separator: "\n")
}

nonisolated private func regularMirroredSourceFileURL(for relativePath: String) throws -> URL {
    let url = try sourceMirrorURL(for: relativePath)
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
    }
    return url
}

nonisolated func mirroredSourceFileURLs(
    under relativeDirectory: String,
    includingExtensions fileExtensions: Set<String>
) throws -> [URL] {
    let rootURL = try sourceMirrorURL(for: relativeDirectory)
    guard let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: nil
    ) else {
        return []
    }

    var urls: [URL] = []
    while let url = enumerator.nextObject() as? URL {
        guard fileExtensions.contains(url.pathExtension) else { continue }
        urls.append(url)
    }

    return urls.sorted { $0.path < $1.path }
}
