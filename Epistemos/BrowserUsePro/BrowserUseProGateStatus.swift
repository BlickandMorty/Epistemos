import Darwin
import Foundation

nonisolated struct BrowserUseVendorManifest: Decodable, Equatable, Sendable {
    static let maxManifestBytes = 1 * 1024 * 1024
    private static let maxPathDiagnosticLength = 160
    private static let chromiumRevisionAllowedCharacters = CharacterSet(charactersIn: "0123456789")
    private static let expectedSchemaVersion = 1
    private static let expectedName = "plan3-browser-use-pro"
    private static let expectedRuntimeLane = "pro-developer-id-only"
    private static let expectedNativeWKWebViewBoundary =
        "browser-use drives bundled Chromium over CDP; it does not drive Epistemos BrowserView WKWebView"

    struct Component: Decodable, Equatable, Sendable {
        let name: String
        let repo: String
        let commit: String
        let license: String
        let packageVersion: String?
        let fullClone: Bool
        let fileCount: Int

        enum CodingKeys: String, CodingKey {
            case name
            case repo
            case commit
            case license
            case packageVersion = "package_version"
            case fullClone = "full_clone"
            case fileCount = "file_count"
        }
    }

    struct RequiredComponentPin: Equatable, Sendable {
        let repo: String
        let commit: String
        let packageVersion: String?
        let fileCount: Int
    }

    static let requiredComponentPins: [String: RequiredComponentPin] = [
        "browser-use": RequiredComponentPin(
            repo: "https://github.com/browser-use/browser-use.git",
            commit: "2454d3e2551705232333c906ded8fc31ab0fc9f2",
            packageVersion: "0.13.2",
            fileCount: 501
        ),
        "web-ui": RequiredComponentPin(
            repo: "https://github.com/browser-use/web-ui.git",
            commit: "61962296c38a0d064e0ba02c827192b7a81d1819",
            packageVersion: nil,
            fileCount: 42
        ),
        "cdp-use": RequiredComponentPin(
            repo: "https://github.com/browser-use/cdp-use.git",
            commit: "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
            packageVersion: "1.4.5",
            fileCount: 357
        ),
    ]

    static let requiredPlaywrightPayloadRevisions: [String: String] = [
        "chromium": "1223",
        "chromium_headless_shell": "1223",
        "ffmpeg": "1011",
    ]

    static var browserUsePackageVersion: String {
        requiredComponentPins["browser-use"]?.packageVersion ?? ""
    }

    struct SourceMirrorGuard: Decodable, Equatable, Sendable {
        let sourceOfTruth: String
        let requiredExclude: String
        let reason: String

        enum CodingKeys: String, CodingKey {
            case sourceOfTruth = "source_of_truth"
            case requiredExclude = "required_exclude"
            case reason
        }
    }

    struct PackagingArtifacts: Decodable, Equatable, Sendable {
        static let agentBrowserAdapterReadyStatus = "landed"
        static let buildScriptReadyStatus = "landed"
        static let buildManifestReadyStatus = "generated"
        static let requirementsLockReadyStatus = "generated"
        static let wheelhouseReadyStatus = "staged"
        static let playwrightChromiumReadyStatus = "staged"
        static let webUIRuntimeCompatibilityReadyStatus = "landed"
        static let webUIDryRunSubmitReadyStatus = "landed"
        static let expectedDryRunSubmitEnvVar = "EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT"
        static let expectedDryRunSubmitMarker = "Epistemos browser-use WebUI dry-run task-submit complete"

        let agentBrowserAdapter: PackagingPathListArtifact
        let webUIRuntimeCompatibility: PackagingPathListArtifact
        let webUIDryRunSubmit: WebUIDryRunSubmitArtifact
        let buildScript: PackagingArtifact
        let buildManifest: PackagingArtifact
        let requirementsLock: PackagingArtifact
        let wheelhouse: PackagingArtifact
        let playwrightChromium: PackagingArtifact

        enum CodingKeys: String, CodingKey {
            case agentBrowserAdapter = "agent_browser_adapter"
            case webUIRuntimeCompatibility = "web_ui_runtime_compatibility"
            case webUIDryRunSubmit = "web_ui_dry_run_submit"
            case buildScript = "build_script"
            case buildManifest = "build_manifest"
            case requirementsLock = "requirements_lock"
            case wheelhouse
            case playwrightChromium = "playwright_chromium"
        }
    }

    struct PackagingArtifact: Decodable, Equatable, Sendable {
        let status: String
        let expectedPath: String
        let fileCount: Int?
        let chromiumRevision: String?
        let headlessShellRevision: String?
        let ffmpegRevision: String?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case status
            case expectedPath = "expected_path"
            case fileCount = "file_count"
            case chromiumRevision = "chromium_revision"
            case headlessShellRevision = "headless_shell_revision"
            case ffmpegRevision = "ffmpeg_revision"
            case notes
        }
    }

    struct PackagingPathListArtifact: Decodable, Equatable, Sendable {
        let status: String
        let expectedPaths: [String]
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case status
            case expectedPaths = "expected_paths"
            case notes
        }
    }

    struct WebUIDryRunSubmitArtifact: Decodable, Equatable, Sendable {
        let status: String
        let expectedPath: String
        let envVar: String
        let marker: String
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case status
            case expectedPath = "expected_path"
            case envVar = "env_var"
            case marker
            case notes
        }
    }

    let schemaVersion: Int
    let name: String
    let runtimeLane: String
    let masSafe: Bool
    let nativeWKWebViewBoundary: String
    let sourceMirrorGuard: SourceMirrorGuard
    let components: [Component]
    let packagingArtifacts: PackagingArtifacts

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case name
        case runtimeLane = "runtime_lane"
        case masSafe = "mas_safe"
        case nativeWKWebViewBoundary = "native_wkwebview_boundary"
        case sourceMirrorGuard = "source_mirror_guard"
        case components
        case packagingArtifacts = "packaging_artifacts"
    }

    static func load(from url: URL) throws -> BrowserUseVendorManifest {
        let data = try readManifestData(at: url)
        return try JSONDecoder().decode(BrowserUseVendorManifest.self, from: data)
    }

    private static func readManifestData(
        at url: URL,
        fileManager: FileManager = .default
    ) throws -> Data {
        try validateManifestFile(at: url, fileManager: fileManager)

        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest could not be opened safely")
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest attributes unavailable")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest must be a regular file")
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxManifestBytes) else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid(
                "browser-use vendor manifest exceeds \(maxManifestBytes) bytes"
            )
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= maxManifestBytes else {
            throw BrowserUseVendorManifestError.invalid(
                "browser-use vendor manifest exceeds \(maxManifestBytes) bytes"
            )
        }
        return data
    }

    private static func validateManifestFile(
        at url: URL,
        fileManager: FileManager = .default
    ) throws {
        if let component = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) {
            throw BrowserUseVendorManifestError.invalid(
                "browser-use vendor manifest path must not include symlink component \(pathDiagnostic(component.lastPathComponent))"
            )
        }
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest must not be a symlink")
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest must be a regular file")
        }
        guard let size = (attributes[.size] as? NSNumber)?.uint64Value else {
            throw BrowserUseVendorManifestError.invalid("browser-use vendor manifest size is unavailable")
        }
        guard size <= UInt64(maxManifestBytes) else {
            throw BrowserUseVendorManifestError.invalid(
                "browser-use vendor manifest exceeds \(maxManifestBytes) bytes"
            )
        }
    }

    var pinnedSourceProblems: [String] {
        var problems: [String] = []

        if schemaVersion != Self.expectedSchemaVersion {
            problems.append("manifest schema \(schemaVersion) is unsupported")
        }
        if name != Self.expectedName {
            problems.append("manifest name mismatch")
        }
        if runtimeLane != Self.expectedRuntimeLane {
            problems.append("manifest runtime lane mismatch")
        }
        if nativeWKWebViewBoundary != Self.expectedNativeWKWebViewBoundary {
            problems.append("manifest native Browser boundary mismatch")
        }

        var byName: [String: Component] = [:]
        for component in components {
            let name = component.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                problems.append("component name is empty")
                continue
            }
            if byName[name] != nil {
                problems.append("duplicate \(name)")
                continue
            }
            byName[name] = component
        }

        for name in Self.requiredComponentPins.keys.sorted() {
            guard let expected = Self.requiredComponentPins[name] else { continue }
            guard let component = byName[name] else {
                problems.append("missing \(name)")
                continue
            }
            if component.repo != expected.repo {
                problems.append("\(name) repo mismatch")
            }
            if component.commit != expected.commit {
                problems.append("\(name) commit mismatch")
            }
            if component.license != "MIT" {
                problems.append("\(name) license mismatch")
            }
            if component.packageVersion != expected.packageVersion {
                problems.append("\(name) package version mismatch")
            }
            if !component.fullClone {
                problems.append("\(name) is not marked full_clone")
            }
            if component.fileCount != expected.fileCount {
                problems.append("\(name) file count mismatch")
            }
        }

        if components.count != Self.requiredComponentPins.count {
            problems.append("unexpected component count \(components.count)")
        }
        if masSafe {
            problems.append("manifest incorrectly marks browser-use as MAS-safe")
        }
        if sourceMirrorGuard.requiredExclude != "--exclude='vendor/browser-use/'" {
            problems.append("missing SourceMirror browser-use exclusion")
        }
        if packagingArtifacts.webUIRuntimeCompatibility.expectedPaths.isEmpty {
            problems.append("web-ui runtime compatibility helper list is empty")
        }
        if packagingArtifacts.webUIDryRunSubmit.envVar != PackagingArtifacts.expectedDryRunSubmitEnvVar {
            problems.append("web-ui dry-run submit env var mismatch")
        }
        if packagingArtifacts.webUIDryRunSubmit.marker != PackagingArtifacts.expectedDryRunSubmitMarker {
            problems.append("web-ui dry-run submit marker mismatch")
        }
        return problems
    }

    var hasExpectedFullClonePins: Bool {
        pinnedSourceProblems.isEmpty
    }

    var isProPayloadStaged: Bool {
        packagingArtifacts.agentBrowserAdapter.status == PackagingArtifacts.agentBrowserAdapterReadyStatus
            && packagingArtifacts.buildScript.status == PackagingArtifacts.buildScriptReadyStatus
            && packagingArtifacts.buildManifest.status == PackagingArtifacts.buildManifestReadyStatus
            && packagingArtifacts.requirementsLock.status == PackagingArtifacts.requirementsLockReadyStatus
            && packagingArtifacts.wheelhouse.status == PackagingArtifacts.wheelhouseReadyStatus
            && packagingArtifacts.playwrightChromium.status == PackagingArtifacts.playwrightChromiumReadyStatus
            && packagingArtifacts.webUIRuntimeCompatibility.status == PackagingArtifacts.webUIRuntimeCompatibilityReadyStatus
            && packagingArtifacts.webUIDryRunSubmit.status == PackagingArtifacts.webUIDryRunSubmitReadyStatus
    }

    func stagedArtifactProblems(
        relativeTo manifestRoot: URL,
        fileManager: FileManager = .default
    ) -> [String] {
        guard isProPayloadStaged else {
            return []
        }

        var problems = [
            artifactProblem(
                name: "agent-browser adapter",
                relativePath: packagingArtifacts.agentBrowserAdapter.expectedPaths.first ?? "",
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: true,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "build-pro-payload.sh",
                relativePath: packagingArtifacts.buildScript.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: true,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "requirements.lock",
                relativePath: packagingArtifacts.requirementsLock.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: false,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "wheelhouse",
                relativePath: packagingArtifacts.wheelhouse.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: true,
                requiresExecutable: false,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "Playwright Chromium payload",
                relativePath: packagingArtifacts.playwrightChromium.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: true,
                requiresExecutable: false,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "BUILD_MANIFEST.json",
                relativePath: packagingArtifacts.buildManifest.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: false,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "web-ui dry-run submit hook",
                relativePath: packagingArtifacts.webUIDryRunSubmit.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: false,
                fileManager: fileManager
            ),
        ].compactMap(\.self) + agentBrowserAdapterHelperProblems(
            relativeTo: manifestRoot,
            fileManager: fileManager
        ) + pathListArtifactProblems(
            name: "web-ui compatibility shim",
            relativePaths: packagingArtifacts.webUIRuntimeCompatibility.expectedPaths,
            relativeTo: manifestRoot,
            fileManager: fileManager
        )

        if let wheelhouseURL = artifactURL(
            relativePath: packagingArtifacts.wheelhouse.expectedPath,
            relativeTo: manifestRoot,
            isDirectory: true
        ), let wheelhouseProblem = directoryFileCountProblem(
            name: "wheelhouse",
            url: wheelhouseURL,
            expectedFileCount: packagingArtifacts.wheelhouse.fileCount,
            fileManager: fileManager
        ) {
            problems.append(wheelhouseProblem)
        }

        if let playwrightURL = artifactURL(
            relativePath: packagingArtifacts.playwrightChromium.expectedPath,
            relativeTo: manifestRoot,
            isDirectory: true
        ), let playwrightProblem = playwrightPayloadRevisionProblem(
            rootURL: playwrightURL,
            artifact: packagingArtifacts.playwrightChromium,
            fileManager: fileManager
        ) {
            problems.append(playwrightProblem)
        }

        return problems
    }

    var packagingSummary: String {
        [
            "adapter=\(packagingArtifacts.agentBrowserAdapter.status)",
            "build script=\(packagingArtifacts.buildScript.status)",
            "build manifest=\(packagingArtifacts.buildManifest.status)",
            "requirements.lock=\(packagingArtifacts.requirementsLock.status)",
            "wheels=\(packagingArtifacts.wheelhouse.status)",
            "browser payload=\(packagingArtifacts.playwrightChromium.status)",
            "web-ui shims=\(packagingArtifacts.webUIRuntimeCompatibility.status)",
            "dry-run hook=\(packagingArtifacts.webUIDryRunSubmit.status)",
        ].joined(separator: ", ")
    }

    private func pathListArtifactProblems(
        name: String,
        relativePaths: ArraySlice<String>,
        relativeTo manifestRoot: URL,
        fileManager: FileManager
    ) -> [String] {
        pathListArtifactProblems(
            name: name,
            relativePaths: Array(relativePaths),
            relativeTo: manifestRoot,
            fileManager: fileManager)
    }

    private func pathListArtifactProblems(
        name: String,
        relativePaths: [String],
        relativeTo manifestRoot: URL,
        fileManager: FileManager
    ) -> [String] {
        guard !relativePaths.isEmpty else {
            return ["\(name) list is empty"]
        }
        return relativePaths.compactMap { relativePath in
            artifactProblem(
                name: name,
                relativePath: relativePath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                requiresExecutable: false,
                fileManager: fileManager
            )
        }
    }

    private func agentBrowserAdapterHelperProblems(
        relativeTo manifestRoot: URL,
        fileManager: FileManager
    ) -> [String] {
        let helperPaths = packagingArtifacts.agentBrowserAdapter.expectedPaths.dropFirst()
        return pathListArtifactProblems(
            name: "agent-browser adapter helper",
            relativePaths: helperPaths,
            relativeTo: manifestRoot,
            fileManager: fileManager)
    }

    private func artifactProblem(
        name: String,
        relativePath: String,
        relativeTo manifestRoot: URL,
        requiresDirectory: Bool,
        requiresExecutable: Bool,
        fileManager: FileManager
    ) -> String? {
        guard let url = artifactURL(
            relativePath: relativePath,
            relativeTo: manifestRoot,
            isDirectory: requiresDirectory
        ) else {
            return "\(name) has unsafe path \(Self.pathDiagnostic(relativePath))"
        }
        if BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) != nil {
            return "\(name) path must not include symlink component at \(Self.pathDiagnostic(relativePath))"
        }
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name) at \(Self.pathDiagnostic(relativePath))"
        }
        guard resolvesInsideVendorRoot(url, relativeTo: manifestRoot) else {
            return "\(name) resolves outside vendor root at \(Self.pathDiagnostic(relativePath))"
        }
        if requiresDirectory && !isDirectory.boolValue {
            return "\(name) is not a directory at \(Self.pathDiagnostic(relativePath))"
        }
        if !requiresDirectory && isDirectory.boolValue {
            return "\(name) is a directory at \(Self.pathDiagnostic(relativePath))"
        }
        if requiresExecutable && !fileManager.isExecutableFile(atPath: url.path) {
            return "\(name) is not executable at \(Self.pathDiagnostic(relativePath))"
        }
        return nil
    }

    private func directoryFileCountProblem(
        name: String,
        url: URL,
        expectedFileCount: Int?,
        fileManager: FileManager
    ) -> String? {
        guard let expectedFileCount else {
            return "\(name) manifest is missing file_count"
        }
        guard expectedFileCount > 0 else {
            return "\(name) manifest has invalid file_count \(expectedFileCount)"
        }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: []
            )
        } catch {
            return "\(name) contents could not be inspected"
        }

        var actualFileCount = 0
        for child in children {
            if (try? fileManager.destinationOfSymbolicLink(atPath: child.path)) != nil {
                return "\(name) contains symlink entry \(Self.pathDiagnostic(child.lastPathComponent))"
            }

            let values: URLResourceValues
            do {
                values = try child.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            } catch {
                return "\(name) entry could not be inspected at \(Self.pathDiagnostic(child.lastPathComponent))"
            }

            if values.isDirectory == true {
                return "\(name) contains unexpected directory \(Self.pathDiagnostic(child.lastPathComponent))"
            }
            guard values.isRegularFile == true else {
                return "\(name) contains unsupported entry \(Self.pathDiagnostic(child.lastPathComponent))"
            }

            actualFileCount += 1
            if actualFileCount > expectedFileCount {
                return "\(name) file_count mismatch: expected \(expectedFileCount), found more"
            }
        }

        guard actualFileCount == expectedFileCount else {
            return "\(name) file_count mismatch: expected \(expectedFileCount), found \(actualFileCount)"
        }
        return nil
    }

    private func playwrightPayloadRevisionProblem(
        rootURL: URL,
        artifact: PackagingArtifact,
        fileManager: FileManager
    ) -> String? {
        return playwrightRevisionMarkerProblem(
            label: "Chromium",
            directoryPrefix: "chromium",
            rootURL: rootURL,
            revision: artifact.chromiumRevision,
            expectedRevision: Self.requiredPlaywrightPayloadRevisions["chromium"],
            missingRevisionMessage: "Playwright Chromium manifest is missing chromium_revision",
            fileManager: fileManager
        ) ?? playwrightRevisionMarkerProblem(
            label: "Chromium headless shell",
            directoryPrefix: "chromium_headless_shell",
            rootURL: rootURL,
            revision: artifact.headlessShellRevision,
            expectedRevision: Self.requiredPlaywrightPayloadRevisions["chromium_headless_shell"],
            missingRevisionMessage: "Playwright Chromium manifest is missing headless_shell_revision",
            fileManager: fileManager
        ) ?? playwrightRevisionMarkerProblem(
            label: "ffmpeg",
            directoryPrefix: "ffmpeg",
            rootURL: rootURL,
            revision: artifact.ffmpegRevision,
            expectedRevision: Self.requiredPlaywrightPayloadRevisions["ffmpeg"],
            missingRevisionMessage: "Playwright Chromium manifest is missing ffmpeg_revision",
            fileManager: fileManager
        )
    }

    private func playwrightRevisionMarkerProblem(
        label: String,
        directoryPrefix: String,
        rootURL: URL,
        revision: String?,
        expectedRevision: String?,
        missingRevisionMessage: String,
        fileManager: FileManager
    ) -> String? {
        guard let expectedRevision else {
            return "Playwright \(label) expected revision is not pinned"
        }
        guard let revision = revision?.trimmingCharacters(in: .whitespacesAndNewlines),
              !revision.isEmpty else {
            return missingRevisionMessage
        }
        guard revision.unicodeScalars.allSatisfy({ Self.chromiumRevisionAllowedCharacters.contains($0) }) else {
            return "Playwright \(label) manifest has invalid revision"
        }
        guard revision == expectedRevision else {
            return "Playwright \(label) revision mismatch"
        }

        let markerURL = rootURL
            .appendingPathComponent("\(directoryPrefix)-\(revision)", isDirectory: true)
            .appendingPathComponent("INSTALLATION_COMPLETE", isDirectory: false)
        if BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: markerURL, fileManager: fileManager) != nil {
            return "Playwright \(label) revision marker path must not include symlink component"
        }
        guard resolvesInsideVendorRoot(markerURL, relativeTo: rootURL) else {
            return "Playwright \(label) revision marker resolves outside payload"
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: markerURL.path, isDirectory: &isDirectory) else {
            return "missing Playwright \(label) revision \(revision)"
        }
        guard !isDirectory.boolValue else {
            return "Playwright \(label) revision marker is a directory"
        }
        let attributes = try? fileManager.attributesOfItem(atPath: markerURL.path)
        guard attributes?[.type] as? FileAttributeType == .typeRegular else {
            return "Playwright \(label) revision marker is not a regular file"
        }
        return nil
    }

    private func artifactURL(
        relativePath: String,
        relativeTo manifestRoot: URL,
        isDirectory: Bool
    ) -> URL? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else {
            return nil
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty,
              components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            return nil
        }

        return manifestRoot.appendingPathComponent(trimmed, isDirectory: isDirectory)
    }

    private func resolvesInsideVendorRoot(_ url: URL, relativeTo manifestRoot: URL) -> Bool {
        let root = manifestRoot.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        return resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }

    private static func pathDiagnostic(_ value: String) -> String {
        rawBoundedDiagnostic(value, maxCharacters: maxPathDiagnosticLength, fallback: "[empty path]")
    }

    private static func rawBoundedDiagnostic(
        _ value: String,
        maxCharacters: Int,
        fallback: String
    ) -> String {
        let limit = max(0, maxCharacters)
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = clipped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

nonisolated enum BrowserUseDiagnostics {
    static let maxStatusMessageCharacters = 360
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func statusMessage(_ message: String, fallback: String) -> String {
        bounded(message, fallback: fallback)
    }

    static func statusMessage(for error: Error, fallback: String) -> String {
        if let manifestError = error as? BrowserUseVendorManifestError {
            return bounded(manifestError.errorDescription ?? fallback, fallback: fallback)
        }
        if let settingsError = error as? BrowserUseSettingsStoreError {
            return bounded(settingsError.errorDescription ?? fallback, fallback: fallback)
        }
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return bounded("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
    }

    private static func bounded(_ message: String, fallback: String) -> String {
        rawBoundedDiagnostic(message, maxCharacters: maxStatusMessageCharacters, fallback: fallback)
    }

    static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let bounded = String(value.prefix(maxDomainCharacters))
        return bounded.isEmpty ? "Error" : bounded
    }

    private static func rawBoundedDiagnostic(
        _ value: String,
        maxCharacters: Int,
        fallback: String
    ) -> String {
        let limit = max(0, maxCharacters)
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = clipped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

nonisolated enum BrowserUseProGateStatus {
    static let flagName = "EPISTEMOS_BROWSER_USE_PRO_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        FeatureGateOverride.isTruthy(raw)
    }

    static func defaultManifestURL(
        filePath: String = #filePath,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return nil
        #else
        if let resourceURL = bundle.resourceURL {
            let signedBundlePayload = resourceURL
                .appendingPathComponent(BrowserUseSignedBundleStatus.bundleName, isDirectory: true)
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
                .appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
            if fileManager.fileExists(atPath: signedBundlePayload.path) {
                return signedBundlePayload
            }
        }

        var cursor = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let developmentSignedBundle = cursor
                .appendingPathComponent("build/browser-use-pro", isDirectory: true)
                .appendingPathComponent(BrowserUseSignedBundleStatus.bundleName, isDirectory: true)
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
                .appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
            if fileManager.fileExists(atPath: developmentSignedBundle.path) {
                return developmentSignedBundle
            }

            let candidate = cursor.appendingPathComponent("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = cursor.deletingLastPathComponent()
            guard parent.path != cursor.path else { break }
            cursor = parent
        }
        return nil
        #endif
    }

    static func status(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        manifestURL: URL? = defaultManifestURL(),
        fileManager: FileManager = .default
    ) -> Status {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return Status(
            isActive: false,
            headline: "browser-use Pro: unavailable in App Store build",
            detail: "The App Store build keeps the native Browser tab human-driven. browser-use automation is Pro/Developer ID only and cannot drive the native WKWebView Browser."
        )
        #else
        guard isEnabled(environment[flagName]) else {
            return Status(
                isActive: false,
                headline: "browser-use Pro: off",
                detail: "Set \(flagName)=1 in the Pro build to arm the browser-use runtime check. Off means no automation runtime is launched."
            )
        }

        guard let manifestURL else {
            return Status(
                isActive: false,
                headline: "browser-use Pro: vendor manifest missing",
                detail: "The Pro browser-use source payload is not installed. No automation runtime is launched."
            )
        }

        do {
            let manifest = try BrowserUseVendorManifest.load(from: manifestURL)
            let problems = manifest.pinnedSourceProblems
            guard problems.isEmpty else {
                return Status(
                    isActive: false,
                    headline: "browser-use Pro: vendor manifest invalid",
                    detail: "Manifest failed validation: \(problems.joined(separator: "; ")). No automation runtime is launched."
                )
            }

            guard manifest.isProPayloadStaged else {
                return Status(
                    isActive: false,
                    headline: "browser-use Pro: source vendored, payload not packaged",
                    detail: "Pinned full source is present, but the runnable Pro payload is not staged yet (\(manifest.packagingSummary)). No automation runtime is launched."
                )
            }

            let artifactProblems = manifest.stagedArtifactProblems(
                relativeTo: manifestURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
            guard artifactProblems.isEmpty else {
                return Status(
                    isActive: false,
                    headline: "browser-use Pro: packaged payload incomplete",
                    detail: "Manifest claims the Pro payload is staged, but \(artifactProblems.joined(separator: "; ")). No automation runtime is launched."
                )
            }

            if let bundleURL = BrowserUseSignedBundleStatus.bundleURL(containingManifest: manifestURL) {
                let signedStatus = BrowserUseSignedBundleStatus.status(
                    bundleURL: bundleURL,
                    payloadRootURL: manifestURL.deletingLastPathComponent(),
                    fileManager: fileManager
                )
                guard signedStatus.isValid else {
                    return Status(
                        isActive: false,
                        headline: "browser-use Pro: signed package invalid",
                        detail: "\(signedStatus.detail). No automation runtime is launched."
                    )
                }

                return Status(
                    isActive: true,
                    headline: "browser-use Pro: signed packaged payload ready",
                    detail: "Pinned browser-use source and signed Pro runtime are present. \(signedStatus.detail) Launch remains user-initiated and separate from the native WKWebView Browser."
                )
            }

            return Status(
                isActive: false,
                headline: "browser-use Pro: signed package missing",
                detail: "Pinned browser-use source and staged Pro artifacts are present, but the manifest is not inside a signed BrowserUsePro.bundle. No automation runtime is launched."
            )
        } catch {
            return Status(
                isActive: false,
                headline: "browser-use Pro: vendor manifest unreadable",
                detail: "Could not read \(manifestURL.lastPathComponent): \(BrowserUseDiagnostics.statusMessage(for: error, fallback: "manifest read failed")). " +
                    "No automation runtime is launched."
            )
        }
        #endif
    }
}
