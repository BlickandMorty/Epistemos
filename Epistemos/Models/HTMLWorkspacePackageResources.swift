import Foundation

nonisolated public enum HTMLWorkspacePreviewResourceMode: Sendable, Hashable {
    case packageLocal
    case inlinePackageAssets
}

nonisolated struct HTMLWorkspacePackageResource: Sendable, Equatable {
    var data: Data
    var mimeType: String
    var textEncodingName: String?

    static func text(_ value: String, mimeType: String) -> HTMLWorkspacePackageResource {
        HTMLWorkspacePackageResource(
            data: Data(value.utf8),
            mimeType: mimeType,
            textEncodingName: "utf-8"
        )
    }
}

nonisolated enum HTMLWorkspacePackageResources {
    static func resource(
        for resourcePath: String,
        in package: HTMLWorkspacePackage
    ) -> HTMLWorkspacePackageResource? {
        switch resourcePath {
        case HTMLWorkspacePackageEntry.indexHTML:
            return .text(
                HTMLWorkspacePreviewDocument.render(package: package),
                mimeType: "text/html"
            )
        case HTMLWorkspacePackageEntry.styleCSS:
            return .text(package.styleCSS, mimeType: "text/css")
        case HTMLWorkspacePackageEntry.scriptJS, HTMLWorkspacePackageEntry.legacyScriptJS:
            return .text(package.scriptJS, mimeType: "application/javascript")
        case HTMLWorkspacePackageEntry.dataJSON:
            return .text(package.dataJSON, mimeType: "application/json")
        default:
            if let routeName = packageRouteName(for: resourcePath),
               let routeDocument = routeDocument(routeName: routeName, in: package) {
                return .text(
                    routeDocument,
                    mimeType: "text/html"
                )
            }
            guard let assetName = packageAssetName(for: resourcePath),
                  let data = package.assets[assetName] else {
                return nil
            }
            let mimeType = mimeType(for: assetName)
            return HTMLWorkspacePackageResource(
                data: data,
                mimeType: mimeType,
                textEncodingName: textEncodingName(for: mimeType)
            )
        }
    }

    private static func routeDocument(routeName: String, in package: HTMLWorkspacePackage) -> String? {
        if routeName == HTMLWorkspacePackageEntry.indexHTML {
            return HTMLWorkspacePreviewDocument.render(package: package)
        }
        guard package.routes[routeName] != nil else { return nil }
        return HTMLWorkspacePreviewDocument.render(package: package, routeName: routeName)
    }

    static func packageWithInlineAssets(_ package: HTMLWorkspacePackage) -> HTMLWorkspacePackage {
        guard !package.assets.isEmpty else { return package }
        var inlined = package
        inlined.indexHTML = inlinePackageAssetReferences(in: package.indexHTML, package: package)
        inlined.styleCSS = inlinePackageAssetReferences(in: package.styleCSS, package: package)
        inlined.routes = package.routes.mapValues { routeHTML in
            inlinePackageAssetReferences(in: routeHTML, package: package)
        }
        return inlined
    }

    static func inlinePackageAssetReferences(
        in source: String,
        package: HTMLWorkspacePackage
    ) -> String {
        guard !package.assets.isEmpty else { return source }
        var rendered = source
        for (name, data) in package.assets.sorted(by: { $0.key.count > $1.key.count }) {
            let dataURL = dataURL(for: name, data: data)
            for candidate in referenceCandidates(for: name).sorted(by: { $0.count > $1.count }) {
                rendered = replaceDelimitedReference(candidate, with: dataURL, in: rendered)
            }
        }
        return rendered
    }

    static func packageAssetName(for resourcePath: String) -> String? {
        let prefix = "\(HTMLWorkspacePackageEntry.assets)/"
        guard resourcePath.hasPrefix(prefix) else { return nil }
        let name = String(resourcePath.dropFirst(prefix.count))
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains("\\"),
              name != ".",
              name != "..",
              !name.hasPrefix("."),
              !name.contains("\0"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return name
    }

    static func packageRouteName(for resourcePath: String) -> String? {
        let prefix = "\(HTMLWorkspacePackageEntry.routes)/"
        guard resourcePath.hasPrefix(prefix) else { return nil }
        let name = String(resourcePath.dropFirst(prefix.count))
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains("\\"),
              name != ".",
              name != "..",
              !name.hasPrefix("."),
              !name.contains("\0"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return name
    }

    static func dataURL(for name: String, data: Data) -> String {
        "data:\(mimeType(for: name));base64,\(data.base64EncodedString())"
    }

    static func mimeType(for name: String) -> String {
        switch name.split(separator: ".").last?.lowercased() {
        case "css": "text/css"
        case "js", "mjs": "application/javascript"
        case "json": "application/json"
        case "html", "htm": "text/html"
        case "svg": "image/svg+xml"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "webp": "image/webp"
        case "avif": "image/avif"
        case "mp4": "video/mp4"
        case "webm": "video/webm"
        case "mp3": "audio/mpeg"
        case "wav": "audio/wav"
        case "wasm": "application/wasm"
        case "zip": "application/zip"
        case "woff": "font/woff"
        case "woff2": "font/woff2"
        case "ttf": "font/ttf"
        case "otf": "font/otf"
        default: "application/octet-stream"
        }
    }

    static func textEncodingName(for mimeType: String) -> String? {
        if mimeType.hasPrefix("text/") ||
            mimeType == "application/javascript" ||
            mimeType == "application/json" ||
            mimeType == "image/svg+xml" {
            return "utf-8"
        }
        return nil
    }

    private static func referenceCandidates(for name: String) -> Set<String> {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let rawPaths = [
            "\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "./\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "../\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "/\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "\(HTMLWorkspacePackageEntry.routes)/\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "/\(HTMLWorkspacePackageEntry.routes)/\(HTMLWorkspacePackageEntry.assets)/\(name)",
            "\(HTMLWorkspaceLocalResourceScheme.scheme)://workspace/\(HTMLWorkspacePackageEntry.assets)/\(name)",
        ]
        let encodedPaths = [
            "\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "./\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "../\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "/\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "\(HTMLWorkspacePackageEntry.routes)/\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "/\(HTMLWorkspacePackageEntry.routes)/\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
            "\(HTMLWorkspaceLocalResourceScheme.scheme)://workspace/\(HTMLWorkspacePackageEntry.assets)/\(encodedName)",
        ]
        return Set(rawPaths + encodedPaths)
    }

    private static func replaceDelimitedReference(
        _ candidate: String,
        with replacement: String,
        in source: String
    ) -> String {
        let escapedCandidate = NSRegularExpression.escapedPattern(for: candidate)
        let pattern = #"(^|[\s"'(=])(\#(escapedCandidate))(?=$|[\s"')<>])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return source
        }
        let matches = expression.matches(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source)
        )
        guard !matches.isEmpty else { return source }

        var rendered = ""
        var cursor = source.startIndex
        for match in matches {
            guard let referenceRange = Range(match.range(at: 2), in: source) else { continue }
            rendered.append(contentsOf: source[cursor..<referenceRange.lowerBound])
            rendered.append(replacement)
            cursor = referenceRange.upperBound
        }
        rendered.append(contentsOf: source[cursor...])
        return rendered
    }
}
