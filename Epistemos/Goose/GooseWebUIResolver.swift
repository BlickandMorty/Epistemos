import Foundation

enum GooseWebUIResolver {
    private final class BundleProbe {}

    nonisolated static let explicitIndexEnvironmentKey = "EPISTEMOS_GOOSE_UI_INDEX"
    nonisolated static let explicitDirectoryEnvironmentKey = "EPISTEMOS_GOOSE_UI_DIR"
    nonisolated static let artifactManifestFileName = ".epistemos-goose-webui.json"
    nonisolated static let maxArtifactManifestBytes = 256 * 1024
    nonisolated static let maxArtifactTextFileBytes = 64 * 1024 * 1024
    nonisolated static let maxBundledTextAssetCount = 512
    nonisolated static let maxBundledAssetEnumerationItems = 8192
    nonisolated static let maxLocalAssetReferenceCount = 4096
    nonisolated static let maxLocalAssetReferenceCharacters = 2048
    nonisolated static let maxEnvironmentPathCharacters = 4_096
    nonisolated static let maxDiagnosticValueCharacters = 512
    nonisolated static let maxDiagnosticSummaryCharacters = 8_192
    nonisolated private static let requiredBridgeMarkers = [
        "providersList_unstable",
        "providersCatalogList_unstable",
        "providersSetupCatalogList_unstable",
        "providersCatalogTemplate_unstable",
        "shared-getAcpClient-provider-inventory",
        "local-acp-config-GOOSE_TELEMETRY_ENABLED",
        "__epistemosGooseACPRequestSerialization",
        "__epistemosGooseProviderInventoryEvents",
        "__epistemosGooseProviderCatalogEvents",
        "provider-catalog-template-choice",
    ]

    nonisolated static func indexURL(
        bundle: Bundle? = .main,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = defaultAppSupportDirectory(fileManager: .default),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeBundledCandidates: Bool = true
    ) -> URL? {
        var resolved: URL?
        forEachCandidateIndexURL(
            bundle: bundle,
            appSupportDirectory: appSupportDirectory,
            currentDirectory: currentDirectory,
            environment: environment,
            includeBundledCandidates: includeBundledCandidates
        ) { candidate in
            guard isACPModeArtifact(indexURL: candidate, fileManager: fileManager) else {
                return false
            }
            resolved = candidate
            return true
        }
        return resolved
    }

    nonisolated static func diagnosticSummary(
        bundle: Bundle? = .main,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = defaultAppSupportDirectory(fileManager: .default),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeBundledCandidates: Bool = true
    ) -> String {
        let candidates = candidateIndexURLs(
            bundle: bundle,
            appSupportDirectory: appSupportDirectory,
            currentDirectory: currentDirectory,
            environment: environment,
            includeBundledCandidates: includeBundledCandidates
        )
        let roots = [
            "bundle=\(diagnosticValue(bundle?.bundleURL.path))",
            "main=\(diagnosticValue(Bundle.main.bundleURL.path))",
            "probe=\(diagnosticValue(Bundle(for: BundleProbe.self).bundleURL.path))",
            "appBundle=\(diagnosticValue(Bundle(identifier: "com.epistemos.app")?.bundleURL.path))",
            "TEST_HOST=\(diagnosticValue(environment["TEST_HOST"]))",
            "XCInjectBundleInto=\(diagnosticValue(environment["XCInjectBundleInto"]))",
            "BUILT_PRODUCTS_DIR=\(diagnosticValue(environment["BUILT_PRODUCTS_DIR"]))",
            "TARGET_BUILD_DIR=\(diagnosticValue(environment["TARGET_BUILD_DIR"]))",
            "WRAPPER_NAME=\(diagnosticValue(environment["WRAPPER_NAME"]))",
            "currentDirectory=\(diagnosticValue(currentDirectory))",
            "candidates=\(candidates.count)",
        ]
        let candidateLines = candidates.enumerated().map { offset, candidate in
            let reasons = artifactRejectionReasons(indexURL: candidate, fileManager: fileManager)
            let verdict = reasons.isEmpty ? "valid" : reasons.joined(separator: "+")
            return "\(offset):\(diagnosticValue(candidate.path))=\(diagnosticValue(verdict))"
        }
        return diagnosticSummary((roots + candidateLines).joined(separator: " | "))
    }

    nonisolated private static func candidateIndexURLs(
        bundle: Bundle?,
        appSupportDirectory: URL?,
        currentDirectory: String,
        environment: [String: String],
        includeBundledCandidates: Bool
    ) -> [URL] {
        var candidates: [URL] = []
        forEachCandidateIndexURL(
            bundle: bundle,
            appSupportDirectory: appSupportDirectory,
            currentDirectory: currentDirectory,
            environment: environment,
            includeBundledCandidates: includeBundledCandidates
        ) { candidate in
            candidates.append(candidate)
            return false
        }
        return candidates
    }

    nonisolated private static func forEachCandidateIndexURL(
        bundle: Bundle?,
        appSupportDirectory: URL?,
        currentDirectory: String,
        environment: [String: String],
        includeBundledCandidates: Bool,
        visit: (URL) -> Bool
    ) {
        var accumulator = UniqueURLAccumulator()

        func emit(_ url: URL?) -> Bool {
            guard let candidate = accumulator.append(url) else { return false }
            return visit(candidate)
        }

        if let explicitIndex = safeEnvironmentPath(environment[explicitIndexEnvironmentKey]) {
            if emit(fileURL(explicitIndex)) { return }
        }

        if let explicitDirectory = safeEnvironmentPath(environment[explicitDirectoryEnvironmentKey]) {
            if emit(fileURL(explicitDirectory).appendingPathComponent("index.html")) { return }
        }

        if let appSupportDirectory {
            if emit(appSupportDirectory.appendingPathComponent("Epistemos/GooseWebUI/index.html")) {
                return
            }
        }

        if includeBundledCandidates {
            if forEachBundledIndexURL(primary: bundle, environment: environment, visit: emit) {
                return
            }
        }

        // The cwd-relative `.research-clones` index is loaded into the ACP-bridged
        // (privileged) WebView. A shipped (Release) build must never source its web
        // content from a process-cwd path — that would let an influenced cwd inject
        // markup into a window that holds the native Goose bridge. Release resolves
        // only explicit-env / bundled / AppSupport candidates (where the UI is
        // actually staged); DEBUG keeps the checkout index for local dev + the live
        // test suites. (Thermonuclear finding [11] remainder: web-index candidate safety.)
        #if DEBUG
        _ = emit(
            URL(fileURLWithPath: currentDirectory)
                .appendingPathComponent(".research-clones/work/goose/ui/desktop/dist/index.html")
        )
        #endif
    }

    nonisolated private static func bundledIndexURLs(primary: Bundle?, environment: [String: String]) -> [URL] {
        var urls: [URL] = []
        _ = forEachBundledIndexURL(primary: primary, environment: environment) { url in
            guard let url else { return false }
            urls.append(url)
            return false
        }
        return urls
    }

    nonisolated private static func forEachBundledIndexURL(
        primary: Bundle?,
        environment: [String: String],
        visit: (URL?) -> Bool
    ) -> Bool {
        if forEachBundleGooseWebUIIndex(primary, visit: visit) { return true }
        for executablePath in bundledExecutablePaths(environment: environment) {
            if visit(appBundleGooseWebUIIndex(fromPathInsideBundle: executablePath)) { return true }
        }
        for resourceIndex in buildProductGooseWebUIIndexes(environment: environment) {
            if visit(resourceIndex) { return true }
        }

        let bundles = (
            [
                primary,
                Bundle.main,
                Bundle(for: BundleProbe.self),
                Bundle(identifier: "com.epistemos.app"),
            ] + Bundle.allBundles + Bundle.allFrameworks
        ).compactMap(\.self)
        for bundle in bundles {
            if forEachBundleGooseWebUIIndex(bundle, visit: visit) { return true }
        }
        return false
    }

    nonisolated private static func forEachBundleGooseWebUIIndex(
        _ bundle: Bundle?,
        visit: (URL?) -> Bool
    ) -> Bool {
        guard let bundle else { return false }
        if visit(appBundleGooseWebUIIndex(fromPathInsideBundle: bundle.bundleURL.path)) { return true }
        if visit(appBundleGooseWebUIIndex(fromPathInsideBundle: bundle.resourceURL?.path)) { return true }
        if visit(appBundleGooseWebUIIndex(fromPathInsideBundle: bundle.executableURL?.path)) { return true }
        if visit(bundle.url(forResource: "index", withExtension: "html", subdirectory: "goose-desktop")) {
            return true
        }
        if visit(bundle.url(forResource: "goose-desktop/index", withExtension: "html")) { return true }
        if visit(bundle.resourceURL?.appendingPathComponent("goose-desktop/index.html")) { return true }
        return false
    }

    nonisolated private static func bundledExecutablePaths(environment: [String: String]) -> [String] {
        [
            environment["TEST_HOST"],
            environment["XCInjectBundleInto"],
            Bundle.main.executableURL?.path,
            CommandLine.arguments.first,
        ].compactMap(safeEnvironmentPath)
    }

    nonisolated private static func buildProductGooseWebUIIndexes(environment: [String: String]) -> [URL] {
        var urls: [URL] = []
        if let builtProducts = safeEnvironmentPath(environment["BUILT_PRODUCTS_DIR"]) {
            urls.append(
                fileURL(builtProducts)
                    .appendingPathComponent("Epistemos.app/Contents/Resources/goose-desktop/index.html")
            )
        }
        if let targetBuildDirectory = safeEnvironmentPath(environment["TARGET_BUILD_DIR"]),
           let wrapperName = safeEnvironmentPath(environment["WRAPPER_NAME"]) {
            urls.append(
                fileURL(targetBuildDirectory)
                    .appendingPathComponent(wrapperName)
                    .appendingPathComponent("Contents/Resources/goose-desktop/index.html")
            )
        }
        return urls
    }

    nonisolated private static func appBundleGooseWebUIIndex(fromPathInsideBundle path: String?) -> URL? {
        guard let path = safeEnvironmentPath(path) else { return nil }
        let expanded = (path as NSString).expandingTildeInPath
        guard let appRange = expanded.range(of: ".app", options: [.backwards]) else {
            return nil
        }
        guard appRange.upperBound == expanded.endIndex || expanded[appRange.upperBound] == "/" else {
            return nil
        }
        let appPath = String(expanded[..<appRange.upperBound])
        return URL(fileURLWithPath: appPath, isDirectory: true)
            .appendingPathComponent("Contents/Resources/goose-desktop/index.html")
    }

    nonisolated private struct UniqueURLAccumulator {
        private var seenPaths: Set<String> = []

        mutating func append(_ url: URL?) -> URL? {
            guard let url else { return nil }
            let path = normalizedFilePath(url)
            guard seenPaths.insert(path).inserted else { return nil }
            return url
        }
    }

    nonisolated private static func normalizedFilePath(_ url: URL) -> String {
        (url.path as NSString).standardizingPath
    }

    nonisolated private static func isContainedInDirectory(_ fileURL: URL, rootPath: String) -> Bool {
        let filePath = normalizedFilePath(fileURL)
        if rootPath == "/" {
            return filePath.hasPrefix("/") && filePath != "/"
        }
        return filePath.hasPrefix(rootPath + "/")
    }

    nonisolated private static func defaultAppSupportDirectory(fileManager: FileManager) -> URL? {
        try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    nonisolated private static func fileURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    nonisolated private static func safeEnvironmentPath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= maxEnvironmentPathCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        return trimmed
    }

    nonisolated private static func diagnosticValue(_ value: String?) -> String {
        guard let value else { return "<nil>" }
        return String(value.prefix(maxDiagnosticValueCharacters).filter { $0 != "\0" })
    }

    nonisolated private static func diagnosticSummary(_ value: String) -> String {
        guard value.count > maxDiagnosticSummaryCharacters else { return value }
        return String(value.prefix(maxDiagnosticSummaryCharacters))
    }

    nonisolated private static func isACPModeArtifact(
        indexURL: URL,
        fileManager: FileManager
    ) -> Bool {
        artifactRejectionReasons(indexURL: indexURL, fileManager: fileManager).isEmpty
    }

    nonisolated private static func artifactRejectionReasons(
        indexURL: URL,
        fileManager: FileManager
    ) -> [String] {
        guard fileManager.fileExists(atPath: indexURL.path) else { return ["missing-index"] }
        let manifestURL = indexURL.deletingLastPathComponent()
            .appendingPathComponent(artifactManifestFileName)
        guard let data = readDataFile(
            manifestURL,
            fileManager: fileManager,
            maxBytes: maxArtifactManifestBytes
        ) else {
            return ["missing-manifest:\(manifestURL.path)"]
        }
        guard let manifest = try? JSONDecoder().decode(ArtifactManifest.self, from: data) else {
            return ["manifest-decode-failed:\(manifestURL.path)"]
        }
        var reasons: [String] = []
        if !manifest.acpMode {
            reasons.append("manifest-acpMode-false")
        }
        let missingAssetReferences = missingLocalAssetReferences(in: indexURL, fileManager: fileManager)
        if !missingAssetReferences.isEmpty {
            reasons.append(contentsOf: missingAssetReferences.map { "missing-referenced-asset:\($0)" })
        }
        let missingMarkers = missingRequiredBridgeMarkers(indexURL: indexURL, fileManager: fileManager)
        if !missingMarkers.isEmpty {
            reasons.append("missing-markers:\(missingMarkers.joined(separator: ","))")
        }
        return reasons
    }

    nonisolated private static func missingLocalAssetReferences(
        in indexURL: URL,
        fileManager: FileManager
    ) -> [String] {
        guard let html = readTextFile(indexURL, fileManager: fileManager) else {
            return ["index-unreadable"]
        }
        let root = indexURL.deletingLastPathComponent()
        let rootPath = normalizedFilePath(root)
        var missing: [String] = []
        for reference in localResourceReferences(in: html) {
            guard let path = localFilePath(from: reference) else { continue }
            let fileURL = root.appendingPathComponent(path)
            guard isContainedInDirectory(fileURL, rootPath: rootPath),
                  fileManager.fileExists(atPath: fileURL.path) else {
                missing.append(diagnosticValue(path))
                continue
            }
        }
        return missing
    }

    nonisolated private static func localResourceReferences(in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:src|href)\s*=\s*["']([^"']+)["']"#,
            options: [.caseInsensitive]
        ) else {
            return []
        }
        var references: [String] = []
        references.reserveCapacity(min(maxLocalAssetReferenceCount, 64))
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, range: range) { match, _, stop in
            guard references.count < maxLocalAssetReferenceCount else {
                stop.pointee = true
                return
            }
            guard let match,
                  match.numberOfRanges > 1,
                  let matchRange = Range(match.range(at: 1), in: html) else {
                return
            }
            let reference = html[matchRange]
            references.append(
                reference.count <= maxLocalAssetReferenceCharacters
                    ? String(reference)
                    : "__oversized_asset_reference__"
            )
        }
        return references
    }

    nonisolated private static func localFilePath(from reference: String) -> String? {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("#"),
              !trimmed.hasPrefix("data:"),
              !trimmed.hasPrefix("blob:"),
              !trimmed.hasPrefix("http://"),
              !trimmed.hasPrefix("https://"),
              !trimmed.hasPrefix("ws://"),
              !trimmed.hasPrefix("wss://"),
              !trimmed.hasPrefix("//") else {
            return nil
        }
        guard !trimmed.hasPrefix("/") else { return "__missing_absolute_asset__" }
        let withoutFragment = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
        let withoutQuery = withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? withoutFragment
        let normalized = withoutQuery.hasPrefix("./") ? String(withoutQuery.dropFirst(2)) : withoutQuery
        guard !normalized.isEmpty,
              !normalized.contains("../") else {
            return "__missing_relative_asset__"
        }
        return normalized
    }

    nonisolated private static func artifactContainsRequiredBridgeMarkers(
        indexURL: URL,
        fileManager: FileManager
    ) -> Bool {
        missingRequiredBridgeMarkers(indexURL: indexURL, fileManager: fileManager).isEmpty
    }

    nonisolated private static func missingRequiredBridgeMarkers(
        indexURL: URL,
        fileManager: FileManager
    ) -> [String] {
        guard let html = readTextFile(indexURL, fileManager: fileManager) else {
            return ["index-unreadable"]
        }
        let root = indexURL.deletingLastPathComponent()
        let rootPath = normalizedFilePath(root)
        var missing = Set(requiredBridgeMarkers)
        removeRequiredBridgeMarkers(foundIn: html, from: &missing)
        for reference in localResourceReferences(in: html) {
            guard !missing.isEmpty else { break }
            guard let path = localFilePath(from: reference) else { continue }
            let fileURL = root.appendingPathComponent(path)
            guard isContainedInDirectory(fileURL, rootPath: rootPath),
                  fileManager.fileExists(atPath: fileURL.path),
                  let text = readTextFile(fileURL, fileManager: fileManager) else {
                continue
            }
            removeRequiredBridgeMarkers(foundIn: text, from: &missing)
        }
        for fileURL in bundledTextAssetURLs(root: root, fileManager: fileManager) {
            guard !missing.isEmpty else { break }
            guard let text = readTextFile(fileURL, fileManager: fileManager) else { continue }
            removeRequiredBridgeMarkers(foundIn: text, from: &missing)
        }
        return requiredBridgeMarkers.filter { missing.contains($0) }
    }

    nonisolated private static func removeRequiredBridgeMarkers(
        foundIn text: String,
        from missing: inout Set<String>
    ) {
        for marker in Array(missing) where text.contains(marker) {
            missing.remove(marker)
        }
    }

    nonisolated private static func bundledTextAssetURLs(
        root: URL,
        fileManager: FileManager
    ) -> [URL] {
        let assetsURL = root.appendingPathComponent("assets", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: assetsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var urls: [URL] = []
        var scannedItems = 0
        for item in enumerator {
            guard scannedItems < maxBundledAssetEnumerationItems else { break }
            scannedItems += 1
            guard urls.count < maxBundledTextAssetCount else { break }
            guard let fileURL = item as? URL else { continue }
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            switch fileURL.pathExtension.lowercased() {
            case "css", "html", "js", "json", "mjs":
                urls.append(fileURL)
            default:
                continue
            }
        }
        return urls
    }

    nonisolated private static func readTextFile(
        _ url: URL,
        fileManager: FileManager
    ) -> String? {
        guard let data = readDataFile(url, fileManager: fileManager, maxBytes: maxArtifactTextFileBytes) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func readDataFile(
        _ url: URL,
        fileManager: FileManager,
        maxBytes: Int
    ) -> Data? {
        guard let size = fileSize(url, fileManager: fileManager),
              size <= UInt64(maxBytes) else {
            return nil
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes + 1),
              data.count <= maxBytes else {
            return nil
        }
        return data
    }

    nonisolated private static func fileSize(_ url: URL, fileManager: FileManager) -> UInt64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.uint64Value
    }

    nonisolated private struct ArtifactManifest: Decodable {
        let acpMode: Bool
    }
}
