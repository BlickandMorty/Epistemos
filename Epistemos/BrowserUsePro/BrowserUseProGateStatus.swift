import Darwin
import Foundation

nonisolated struct BrowserUseVendorManifest: Decodable, Equatable, Sendable {
    static let maxManifestBytes = 1 * 1024 * 1024
    private static let maxPathDiagnosticLength = 160

    struct Component: Decodable, Equatable, Sendable {
        let name: String
        let repo: String
        let commit: String
        let license: String
        let fullClone: Bool
        let fileCount: Int

        enum CodingKeys: String, CodingKey {
            case name
            case repo
            case commit
            case license
            case fullClone = "full_clone"
            case fileCount = "file_count"
        }
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
        let requirementsLock: PackagingArtifact
        let wheelhouse: PackagingArtifact
        let playwrightChromium: PackagingArtifact

        enum CodingKeys: String, CodingKey {
            case requirementsLock = "requirements_lock"
            case wheelhouse
            case playwrightChromium = "playwright_chromium"
        }
    }

    struct PackagingArtifact: Decodable, Equatable, Sendable {
        let status: String
        let expectedPath: String
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case status
            case expectedPath = "expected_path"
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
        let required: [String: (repo: String, commit: String, fileCount: Int)] = [
            "browser-use": (
                "https://github.com/browser-use/browser-use.git",
                "2454d3e2551705232333c906ded8fc31ab0fc9f2",
                501
            ),
            "web-ui": (
                "https://github.com/browser-use/web-ui.git",
                "61962296c38a0d064e0ba02c827192b7a81d1819",
                42
            ),
            "cdp-use": (
                "https://github.com/browser-use/cdp-use.git",
                "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
                357
            ),
        ]

        let byName = Dictionary(uniqueKeysWithValues: components.map { ($0.name, $0) })
        for (name, expected) in required {
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
            if !component.fullClone {
                problems.append("\(name) is not marked full_clone")
            }
            if component.fileCount != expected.fileCount {
                problems.append("\(name) file count mismatch")
            }
        }

        if components.count != required.count {
            problems.append("unexpected component count \(components.count)")
        }
        if masSafe {
            problems.append("manifest incorrectly marks browser-use as MAS-safe")
        }
        if sourceMirrorGuard.requiredExclude != "--exclude='vendor/browser-use/'" {
            problems.append("missing SourceMirror browser-use exclusion")
        }
        return problems
    }

    var hasExpectedFullClonePins: Bool {
        pinnedSourceProblems.isEmpty
    }

    var isProPayloadStaged: Bool {
        packagingArtifacts.requirementsLock.status == "generated"
            && packagingArtifacts.wheelhouse.status == "staged"
            && packagingArtifacts.playwrightChromium.status == "staged"
    }

    func stagedArtifactProblems(
        relativeTo manifestRoot: URL,
        fileManager: FileManager = .default
    ) -> [String] {
        guard isProPayloadStaged else {
            return []
        }

        return [
            artifactProblem(
                name: "requirements.lock",
                relativePath: packagingArtifacts.requirementsLock.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: false,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "wheelhouse",
                relativePath: packagingArtifacts.wheelhouse.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: true,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "Playwright Chromium payload",
                relativePath: packagingArtifacts.playwrightChromium.expectedPath,
                relativeTo: manifestRoot,
                requiresDirectory: true,
                fileManager: fileManager
            ),
            artifactProblem(
                name: "BUILD_MANIFEST.json",
                relativePath: "BUILD_MANIFEST.json",
                relativeTo: manifestRoot,
                requiresDirectory: false,
                fileManager: fileManager
            ),
        ].compactMap(\.self)
    }

    var packagingSummary: String {
        "requirements.lock=\(packagingArtifacts.requirementsLock.status), wheels=\(packagingArtifacts.wheelhouse.status), browser payload=\(packagingArtifacts.playwrightChromium.status)"
    }

    private func artifactProblem(
        name: String,
        relativePath: String,
        relativeTo manifestRoot: URL,
        requiresDirectory: Bool,
        fileManager: FileManager
    ) -> String? {
        guard let url = artifactURL(
            relativePath: relativePath,
            relativeTo: manifestRoot,
            isDirectory: requiresDirectory
        ) else {
            return "\(name) has unsafe path \(Self.pathDiagnostic(relativePath))"
        }
        if let component = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) {
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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? "[empty path]" : trimmed
        guard description.count > maxPathDiagnosticLength else {
            return description
        }
        return String(description.prefix(maxPathDiagnosticLength)) + "..."
    }
}

private enum BrowserUseVendorManifestError: Error, LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let reason):
            return reason
        }
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
        if let resourceURL = bundle.resourceURL {
            let bundled = resourceURL.appendingPathComponent("BrowserUsePro/VENDOR_MANIFEST.json")
            if fileManager.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        var cursor = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = cursor.appendingPathComponent("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = cursor.deletingLastPathComponent()
            guard parent.path != cursor.path else { break }
            cursor = parent
        }
        return nil
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

            return Status(
                isActive: true,
                headline: "browser-use Pro: packaged payload ready",
                detail: "Pinned browser-use source and packaged Pro runtime are present. Launch remains user-initiated and separate from the native WKWebView Browser."
            )
        } catch {
            return Status(
                isActive: false,
                headline: "browser-use Pro: vendor manifest unreadable",
                detail: "Could not read \(manifestURL.lastPathComponent): \(error.localizedDescription). No automation runtime is launched."
            )
        }
        #endif
    }
}
