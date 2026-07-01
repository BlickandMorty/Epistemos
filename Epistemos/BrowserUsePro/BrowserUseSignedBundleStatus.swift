import Darwin
import Foundation
import Security

nonisolated enum BrowserUseSignedBundleStatus {
    static let signatureManifestName = "SIGNATURE_MANIFEST.json"
    static let bundleName = "BrowserUsePro.bundle"
    private static let maxSignatureManifestBytes = 1 * 1024 * 1024
    private static let maxStatusMessageCharacters = 360
    private static let maxPayloadFileCount = 250_000
    private static let maxPayloadEnumerationEntries = maxPayloadFileCount + 25_000
    private static let expectedPythonVersionPrefix = "Python 3.11."
    private static let expectedCodesignContract = "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime."
    private static let allowedSignatureTypes: Set<String> = [
        "ad-hoc",
        "apple-development",
        "developer-id",
    ]

    struct Status: Equatable, Sendable {
        let isValid: Bool
        let detail: String
    }

    private struct SignatureManifest: Decodable {
        let schemaVersion: Int
        let packageName: String
        let runtimeLane: String
        let signatureType: String
        let signingIdentity: String
        let payloadRoot: String
        let fileCount: Int
        let pythonVersion: String?
        let browserUseVersion: String?
        let componentRepos: [String: String]?
        let componentCommits: [String: String]?
        let componentVersions: [String: String?]?
        let playwrightRevisions: [String: String]?
        let createdUTC: String
        let codesignContract: String

        enum CodingKeys: String, CodingKey, CaseIterable {
            case schemaVersion = "schema_version"
            case packageName = "package_name"
            case runtimeLane = "runtime_lane"
            case signatureType = "signature_type"
            case signingIdentity = "signing_identity"
            case payloadRoot = "payload_root"
            case fileCount = "file_count"
            case pythonVersion = "python"
            case browserUseVersion = "browser_use_version"
            case componentRepos = "component_repos"
            case componentCommits = "component_commits"
            case componentVersions = "component_versions"
            case playwrightRevisions = "playwright_revisions"
            case createdUTC = "created_utc"
            case codesignContract = "codesign_contract"
        }

        private struct DynamicCodingKey: CodingKey {
            let stringValue: String
            let intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
                intValue = nil
            }

            init?(intValue: Int) {
                stringValue = "\(intValue)"
                self.intValue = intValue
            }
        }

        init(from decoder: Decoder) throws {
            let rawContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            let actualKeys = Set(rawContainer.allKeys.map(\.stringValue))
            let expectedKeys = Set(CodingKeys.allCases.map(\.stringValue))
            guard actualKeys == expectedKeys else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "signature manifest top-level keys mismatch"
                    )
                )
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            packageName = try container.decode(String.self, forKey: .packageName)
            runtimeLane = try container.decode(String.self, forKey: .runtimeLane)
            signatureType = try container.decode(String.self, forKey: .signatureType)
            signingIdentity = try container.decode(String.self, forKey: .signingIdentity)
            payloadRoot = try container.decode(String.self, forKey: .payloadRoot)
            fileCount = try container.decode(Int.self, forKey: .fileCount)
            pythonVersion = try container.decodeIfPresent(String.self, forKey: .pythonVersion)
            browserUseVersion = try container.decodeIfPresent(String.self, forKey: .browserUseVersion)
            componentRepos = try container.decodeIfPresent([String: String].self, forKey: .componentRepos)
            componentCommits = try container.decodeIfPresent([String: String].self, forKey: .componentCommits)
            componentVersions = try container.decodeIfPresent([String: String?].self, forKey: .componentVersions)
            playwrightRevisions = try container.decodeIfPresent([String: String].self, forKey: .playwrightRevisions)
            createdUTC = try container.decode(String.self, forKey: .createdUTC)
            codesignContract = try container.decode(String.self, forKey: .codesignContract)
        }
    }

    static func bundleURL(containingManifest manifestURL: URL) -> URL? {
        var cursor = manifestURL.standardizedFileURL.deletingLastPathComponent()
        while true {
            if cursor.lastPathComponent == bundleName,
               cursor.pathExtension == "bundle" {
                return cursor
            }
            let parent = cursor.deletingLastPathComponent()
            guard parent.path != cursor.path else { return nil }
            cursor = parent
        }
    }

    static func status(
        bundleURL: URL,
        payloadRootURL: URL,
        fileManager: FileManager = .default
    ) -> Status {
        let signatureManifestURL = payloadRootURL.appendingPathComponent(signatureManifestName, isDirectory: false)
        do {
            guard payloadRootMatchesExpectedBundleLayout(bundleURL: bundleURL, payloadRootURL: payloadRootURL) else {
                return invalid("signature payload root path mismatch")
            }
            let manifest = try loadSignatureManifest(from: signatureManifestURL, fileManager: fileManager)
            guard manifest.schemaVersion == 1 else {
                return invalid("signature manifest schema \(manifest.schemaVersion) is unsupported")
            }
            guard manifest.packageName == "BrowserUsePro" else {
                return invalid("signature manifest package mismatch")
            }
            guard manifest.runtimeLane == "pro-developer-id-only" else {
                return invalid("signature manifest runtime lane mismatch")
            }
            guard manifest.payloadRoot == "Contents/Resources/BrowserUsePro" else {
                return invalid("signature manifest payload root mismatch")
            }
            guard allowedSignatureTypes.contains(manifest.signatureType) else {
                return invalid("signature manifest signature type is unsupported")
            }
            guard !manifest.signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return invalid("signature manifest signing identity is empty")
            }
            guard manifest.fileCount > 0 else {
                return invalid("signature manifest has no recorded files")
            }
            guard manifest.pythonVersion?.hasPrefix(expectedPythonVersionPrefix) == true else {
                return invalid("signature manifest Python version mismatch")
            }
            guard manifest.browserUseVersion == BrowserUseVendorManifest.browserUsePackageVersion else {
                return invalid("signature manifest browser-use version mismatch")
            }
            guard isSecondPrecisionUTCTimestamp(manifest.createdUTC) else {
                return invalid("signature manifest created_utc mismatch")
            }
            guard manifest.codesignContract == expectedCodesignContract else {
                return invalid("signature manifest codesign contract mismatch")
            }
            guard let componentRepos = manifest.componentRepos else {
                return invalid("signature manifest is missing component repo evidence")
            }
            guard let componentCommits = manifest.componentCommits else {
                return invalid("signature manifest is missing component pin evidence")
            }
            guard let componentVersions = manifest.componentVersions else {
                return invalid("signature manifest is missing component version evidence")
            }
            let componentProblems = componentEvidenceProblems(
                repos: componentRepos,
                commits: componentCommits,
                versions: componentVersions
            )
            guard componentProblems.isEmpty else {
                return invalid("signature manifest component evidence mismatch: \(componentProblems.joined(separator: "; "))")
            }
            guard let playwrightRevisions = manifest.playwrightRevisions else {
                return invalid("signature manifest is missing Playwright revision evidence")
            }
            let playwrightProblems = playwrightRevisionProblems(playwrightRevisions)
            guard playwrightProblems.isEmpty else {
                return invalid("signature manifest Playwright revision mismatch: \(playwrightProblems.joined(separator: "; "))")
            }
            if let countProblem = payloadFileCountProblem(
                in: payloadRootURL,
                expectedFileCount: manifest.fileCount,
                fileManager: fileManager
            ) {
                return invalid(countProblem)
            }
            guard let signatureProblem = codeSignatureProblem(for: bundleURL) else {
                return Status(
                    isValid: true,
                    detail: "Signed \(bundleName) verified (\(manifest.signatureType), identity \(bounded(manifest.signingIdentity)))."
                )
            }
            return invalid(signatureProblem)
        } catch {
            return invalid("signature manifest unreadable: \(BrowserUseDiagnostics.statusMessage(for: error, fallback: "signature manifest read failed"))")
        }
    }

    private static func payloadRootMatchesExpectedBundleLayout(bundleURL: URL, payloadRootURL: URL) -> Bool {
        let expectedPayloadRoot = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
            .standardizedFileURL
            .path
        return payloadRootURL.standardizedFileURL.path == expectedPayloadRoot
    }

    private static func loadSignatureManifest(
        from url: URL,
        fileManager: FileManager
    ) throws -> SignatureManifest {
        if let component = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) {
            throw BrowserUseVendorManifestError.invalid(
                "browser-use signature manifest path must not include symlink component \(pathDiagnostic(component))"
            )
        }
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw BrowserUseVendorManifestError.invalid("browser-use signature manifest must not be a symlink")
        }

        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw BrowserUseVendorManifestError.invalid("browser-use signature manifest could not be opened safely")
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid("browser-use signature manifest attributes unavailable")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid("browser-use signature manifest must be a regular file")
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxSignatureManifestBytes) else {
            close(fd)
            throw BrowserUseVendorManifestError.invalid(
                "browser-use signature manifest exceeds \(maxSignatureManifestBytes) bytes"
            )
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= maxSignatureManifestBytes else {
            throw BrowserUseVendorManifestError.invalid(
                "browser-use signature manifest exceeds \(maxSignatureManifestBytes) bytes"
            )
        }
        return try JSONDecoder().decode(SignatureManifest.self, from: data)
    }

    private static func payloadFileCountProblem(
        in payloadRootURL: URL,
        expectedFileCount: Int,
        fileManager: FileManager
    ) -> String? {
        guard expectedFileCount > 0 else {
            return "signature manifest has no recorded files"
        }
        guard expectedFileCount <= maxPayloadFileCount else {
            return "signature manifest file count exceeds \(maxPayloadFileCount)"
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: payloadRootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return "signature payload root is missing"
        }

        let resolvedRoot = payloadRootURL.standardizedFileURL.resolvingSymlinksInPath()
        var enumerationProblem: String?
        guard let enumerator = fileManager.enumerator(
            at: payloadRootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { url, _ in
                enumerationProblem = "signature payload could not be inspected at \(payloadPathDiagnostic(url, relativeTo: payloadRootURL))"
                return false
            }
        ) else {
            return "signature payload root could not be enumerated"
        }

        var actualFileCount = 0
        var visitedEntryCount = 0
        let signatureManifestPath = payloadRootURL
            .appendingPathComponent(signatureManifestName, isDirectory: false)
            .standardizedFileURL
            .path
        for case let fileURL as URL in enumerator {
            if let enumerationProblem {
                return enumerationProblem
            }
            visitedEntryCount += 1
            guard visitedEntryCount <= maxPayloadEnumerationEntries else {
                return "signature payload contains too many entries"
            }

            if (try? fileManager.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
                enumerator.skipDescendants()
                let resolvedURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
                guard isInside(resolvedURL, root: resolvedRoot) else {
                    return "signature payload symlink resolves outside package at \(payloadPathDiagnostic(fileURL, relativeTo: payloadRootURL))"
                }
                guard fileManager.fileExists(atPath: resolvedURL.path) else {
                    return "signature payload symlink target is missing at \(payloadPathDiagnostic(fileURL, relativeTo: payloadRootURL))"
                }
                continue
            }

            let values: URLResourceValues
            do {
                values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            } catch {
                return "signature payload file could not be inspected at \(payloadPathDiagnostic(fileURL, relativeTo: payloadRootURL))"
            }

            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true else {
                return "signature payload contains unsupported file type at \(payloadPathDiagnostic(fileURL, relativeTo: payloadRootURL))"
            }
            guard fileURL.standardizedFileURL.path != signatureManifestPath else {
                continue
            }

            actualFileCount += 1
            if actualFileCount > expectedFileCount {
                return "signature manifest file count mismatch: expected \(expectedFileCount), found more"
            }
        }

        if let enumerationProblem {
            return enumerationProblem
        }
        guard actualFileCount == expectedFileCount else {
            return "signature manifest file count mismatch: expected \(expectedFileCount), found \(actualFileCount)"
        }
        return nil
    }

    private static func componentEvidenceProblems(
        repos: [String: String],
        commits: [String: String],
        versions: [String: String?]
    ) -> [String] {
        var problems: [String] = []
        let requiredPins = BrowserUseVendorManifest.requiredComponentPins

        for name in requiredPins.keys.sorted() {
            guard let expected = requiredPins[name] else { continue }
            problems.append(
                contentsOf: [
                    requiredEvidenceProblem(
                        name: name,
                        evidence: repos,
                        expected: expected.repo,
                        label: "repo"
                    ),
                    requiredEvidenceProblem(
                        name: name,
                        evidence: commits,
                        expected: expected.commit,
                        label: "commit"
                    ),
                    packageVersionProblem(
                        name: name,
                        versions: versions,
                        expected: expected.packageVersion
                    ),
                ].compactMap(\.self)
            )
        }

        let allNames = Set(repos.keys).union(commits.keys).union(versions.keys)
        for name in allNames.sorted() where requiredPins[name] == nil {
            problems.append("unexpected \(name)")
        }
        return problems
    }

    private static func requiredEvidenceProblem(
        name: String,
        evidence: [String: String],
        expected: String,
        label: String
    ) -> String? {
        guard let actual = evidence[name] else {
            return "missing \(name) \(label)"
        }
        guard actual == expected else {
            return "\(name) \(label) mismatch"
        }
        return nil
    }

    private static func packageVersionProblem(
        name: String,
        versions: [String: String?],
        expected: String?
    ) -> String? {
        guard versions.keys.contains(name) else {
            return "missing \(name) package version"
        }
        let actual = versions[name] ?? nil
        guard actual == expected else {
            return "\(name) package version mismatch"
        }
        return nil
    }

    private static func playwrightRevisionProblems(_ revisions: [String: String]) -> [String] {
        var problems: [String] = []
        let expectedRevisions = BrowserUseVendorManifest.requiredPlaywrightPayloadRevisions
        for name in expectedRevisions.keys.sorted() {
            guard let expected = expectedRevisions[name] else { continue }
            guard let actual = revisions[name] else {
                problems.append("missing \(name)")
                continue
            }
            guard actual == expected else {
                problems.append("\(name) mismatch")
                continue
            }
        }
        for name in revisions.keys.sorted() where expectedRevisions[name] == nil {
            problems.append("unexpected \(name)")
        }
        return problems
    }

    private static func codeSignatureProblem(for bundleURL: URL) -> String? {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return "code signature object unavailable (status \(createStatus))"
        }

        let verifyStatus = SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures),
            nil
        )
        guard verifyStatus == errSecSuccess else {
            return "code signature verification failed (status \(verifyStatus))"
        }
        return nil
    }

    private static func isSecondPrecisionUTCTimestamp(_ value: String) -> Bool {
        let bounded = String(value.prefix(32))
        let scalars = Array(bounded.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        guard scalars.count == 20 else {
            return false
        }

        let punctuation: [Int: UInt32] = [
            4: 45,  // -
            7: 45,  // -
            10: 84, // T
            13: 58, // :
            16: 58, // :
            19: 90, // Z
        ]
        for (index, scalar) in scalars.enumerated() {
            if let expected = punctuation[index] {
                guard scalar.value == expected else {
                    return false
                }
            } else {
                guard scalar.value >= 48, scalar.value <= 57 else {
                    return false
                }
            }
        }
        return true
    }

    private static func invalid(_ detail: String) -> Status {
        Status(isValid: false, detail: bounded(detail))
    }

    private static func bounded(_ detail: String) -> String {
        rawBoundedDiagnostic(
            detail,
            maxCharacters: maxStatusMessageCharacters,
            fallback: "signature verification failed"
        )
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

    private static func isInside(_ url: URL, root: URL) -> Bool {
        let path = url.path
        let rootPath = root.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func payloadPathDiagnostic(_ url: URL, relativeTo rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        let description: String
        if candidatePath == rootPath {
            description = "."
        } else if candidatePath.hasPrefix(rootPath + "/") {
            description = String(candidatePath.dropFirst(rootPath.count + 1))
        } else {
            description = pathDiagnostic(url)
        }
        return bounded(description)
    }

    private static func pathDiagnostic(_ url: URL) -> String {
        let label = url.lastPathComponent.isEmpty ? "[path]" : url.lastPathComponent
        return bounded(label)
    }
}
