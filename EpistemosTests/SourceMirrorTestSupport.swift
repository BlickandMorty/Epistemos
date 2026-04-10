import Foundation

private final class SourceMirrorBundleLocator {}

func sourceMirrorRootURL() throws -> URL {
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

func sourceMirrorURL(for relativePath: String) throws -> URL {
    try sourceMirrorRootURL().appendingPathComponent(relativePath)
}

func loadMirroredSourceDataFile(_ relativePath: String) throws -> Data {
    try Data(contentsOf: sourceMirrorURL(for: relativePath))
}

func loadMirroredSourceTextFile(_ relativePath: String) throws -> String {
    try String(contentsOf: sourceMirrorURL(for: relativePath), encoding: .utf8)
}

func mirroredSourceFileURLs(
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
