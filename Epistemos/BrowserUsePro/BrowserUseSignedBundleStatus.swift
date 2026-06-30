import Darwin
import Foundation
import Security

nonisolated enum BrowserUseSignedBundleStatus {
    static let signatureManifestName = "SIGNATURE_MANIFEST.json"
    static let bundleName = "BrowserUsePro.bundle"
    private static let maxSignatureManifestBytes = 1 * 1024 * 1024
    private static let maxStatusMessageCharacters = 360
    private static let maxPayloadFileCount = 250_000
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

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case packageName = "package_name"
            case runtimeLane = "runtime_lane"
            case signatureType = "signature_type"
            case signingIdentity = "signing_identity"
            case payloadRoot = "payload_root"
            case fileCount = "file_count"
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
            guard manifest.fileCount > 0 else {
                return invalid("signature manifest has no recorded files")
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
        let signatureManifestPath = payloadRootURL
            .appendingPathComponent(signatureManifestName, isDirectory: false)
            .standardizedFileURL
            .path
        for case let fileURL as URL in enumerator {
            if let enumerationProblem {
                return enumerationProblem
            }

            if (try? fileManager.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
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

    private static func codeSignatureProblem(for bundleURL: URL) -> String? {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return "code signature object unavailable (status \(createStatus))"
        }

        let verifyStatus = SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSStrictValidate),
            nil
        )
        guard verifyStatus == errSecSuccess else {
            return "code signature verification failed (status \(verifyStatus))"
        }
        return nil
    }

    private static func invalid(_ detail: String) -> Status {
        Status(isValid: false, detail: bounded(detail))
    }

    private static func bounded(_ detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "signature verification failed" : trimmed
        guard value.count > maxStatusMessageCharacters else {
            return value
        }
        return String(value.prefix(maxStatusMessageCharacters)) + "..."
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
