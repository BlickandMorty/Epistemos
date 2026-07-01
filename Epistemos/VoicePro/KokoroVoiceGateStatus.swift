import Darwin
import CryptoKit
import Foundation

nonisolated enum KokoroVoiceGateStatus {
    static let flagName = "EPISTEMOS_KOKORO_VOICE_PRO_V0"
    static let modelDirectoryName = "kokoro-82m-coreml"
    static let manifestFileName = "manifest.json"
    static let modelPackageName = "Kokoro82M.mlpackage"
    static let packageManifestFileName = "Manifest.json"
    static let manifestSchemaVersion = 1
    static let modelIdentifier = "kokoro-82m"
    static let runtimeIdentifier = "coreml"
    static let maxManifestBytes = 64 * 1024
    static let maxManifestFileCount = 128
    static let maxPackageEntryCount = 250_000
    static let maxPackageFileBytes = UInt64(2) * 1024 * 1024 * 1024
    static let maxPackageTotalBytes = UInt64(4) * 1024 * 1024 * 1024
    private static let maxPathDiagnosticLength = 160
    private static let maxPackageFilePathLength = 240
    private static let hashReadChunkBytes = 1024 * 1024

    enum State: String, Equatable, Sendable {
        case unavailable
        case missingModel
        case packageReady
    }

    struct Status: Equatable, Sendable {
        let state: State
        /// Runtime readiness, not merely model-package readiness. Keep false
        /// until neural synthesis is actually wired and selectable.
        let isReady: Bool
        let headline: String
        let detail: String
        var packageEvidence: PackageEvidence? = nil
    }

    struct PackageEvidence: Equatable, Sendable {
        let modelDirectoryName: String
        let manifestFileName: String
        let modelPackageName: String
        let runtimeIdentifier: String
        let manifestFileCount: Int
        let declaredPackageBytes: UInt64

        var settingsSummary: String {
            let fileLabel = manifestFileCount == 1 ? "file" : "files"
            return "\(modelPackageName): \(manifestFileCount) checked \(fileLabel), \(declaredPackageBytes) declared bytes, \(runtimeIdentifier) package. Kokoro synthesis remains unavailable until the native engine is wired."
        }
    }

    static func isEnabled(_ raw: String?) -> Bool {
        FeatureGateOverride.isTruthy(raw)
    }

    static func defaultModelRoot(fileManager: FileManager = .default) -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("VoicePro", isDirectory: true)
    }

    static func status(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = defaultModelRoot(),
        fileManager: FileManager = .default
    ) -> Status {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return Status(
            state: .unavailable,
            isReady: false,
            headline: "Kokoro voice: unavailable in App Store build",
            detail: "Text-to-speech is Kokoro-only. The App Store build has no shipped TTS until native Kokoro synthesis is wired; Apple AVSpeech is not used as a fallback."
        )
        #else
        guard isEnabled(environment[flagName]) else {
            return Status(
                state: .unavailable,
                isReady: false,
                headline: "Kokoro voice: off",
                detail: "Set \(flagName)=1 in a Pro build after installing the checked model package. Off means text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
            )
        }

        guard let modelRoot else {
            return Status(
                state: .missingModel,
                isReady: false,
                headline: "Kokoro voice: model location unavailable",
                detail: "Application Support could not be resolved. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
            )
        }

        let modelDirectory = modelRoot.appendingPathComponent(modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(manifestFileName, isDirectory: false)
        let modelPackageURL = modelDirectory.appendingPathComponent(modelPackageName, isDirectory: true)
        let manifestCheck = manifestProblem(
            name: manifestFileName,
            url: manifestURL,
            rootURL: modelDirectory,
            fileManager: fileManager
        )
        let packageShapeProblem = artifactProblem(
            name: modelPackageName,
            url: modelPackageURL,
            kind: .directory,
            rootURL: modelDirectory,
            fileManager: fileManager
        )

        var problems = [String]()
        if let manifestProblem = manifestCheck.problem {
            problems.append(manifestProblem)
        }
        if let packageShapeProblem {
            problems.append(packageShapeProblem)
        }
        if let manifest = manifestCheck.manifest, packageShapeProblem == nil,
           let contentsProblem = packageContentsProblem(
                manifest: manifest,
                packageURL: modelPackageURL,
                modelDirectoryURL: modelDirectory,
                fileManager: fileManager
           ) {
            problems.append(contentsProblem)
        }

        guard problems.isEmpty else {
            return Status(
                state: .missingModel,
                isReady: false,
                headline: "Kokoro voice: model package missing",
                detail: "Expected \(modelDirectoryName), but \(problems.joined(separator: ", ")). Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
            )
        }

        let packageEvidence = manifestCheck.manifest.map(packageEvidence(from:))
        return Status(
            state: .packageReady,
            isReady: false,
            headline: "Kokoro voice: model package ready, runtime deferred",
            detail: "The checked Pro model package manifest and package file digests match in \(modelDirectoryName), but native Kokoro synthesis is not wired yet. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback.",
            packageEvidence: packageEvidence
        )
        #endif
    }

    private struct InstallManifest {
        let files: [PackageFile]
    }

    private struct ManifestCheck {
        let manifest: InstallManifest?
        let problem: String?
    }

    private struct PackageFile {
        let path: String
        let bytes: UInt64
        let sha256: String
    }

    private struct FileDigest {
        let bytes: UInt64
        let sha256: String
    }

    private enum ArtifactKind {
        case file
        case directory
    }

    private static func packageEvidence(from manifest: InstallManifest) -> PackageEvidence {
        PackageEvidence(
            modelDirectoryName: modelDirectoryName,
            manifestFileName: manifestFileName,
            modelPackageName: modelPackageName,
            runtimeIdentifier: runtimeIdentifier,
            manifestFileCount: manifest.files.count,
            declaredPackageBytes: manifest.files.reduce(UInt64(0)) { $0 + $1.bytes }
        )
    }

    private static func manifestProblem(
        name: String,
        url: URL,
        rootURL: URL,
        fileManager: FileManager
    ) -> ManifestCheck {
        if let shapeProblem = artifactProblem(
            name: name,
            url: url,
            kind: .file,
            rootURL: rootURL,
            fileManager: fileManager
        ) {
            return ManifestCheck(manifest: nil, problem: shapeProblem)
        }
        guard let data = readManifestDataNoFollow(at: url) else {
            return ManifestCheck(manifest: nil, problem: "\(name) could not be read safely")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return ManifestCheck(manifest: nil, problem: "\(name) is not a JSON object")
        }
        if let contractProblem = manifestContractProblem(dictionary) {
            return ManifestCheck(manifest: nil, problem: "\(name) \(contractProblem)")
        }
        return ManifestCheck(
            manifest: InstallManifest(files: packageFiles(from: dictionary)),
            problem: nil
        )
    }

    private static func manifestContractProblem(_ object: [String: Any]) -> String? {
        guard unsignedIntegerValue(object["schemaVersion"]) == UInt64(manifestSchemaVersion) else {
            return "schemaVersion must be \(manifestSchemaVersion)"
        }
        guard object["modelId"] as? String == modelIdentifier else {
            return "modelId must be \(modelIdentifier)"
        }
        guard object["runtime"] as? String == runtimeIdentifier else {
            return "runtime must be \(runtimeIdentifier)"
        }
        guard object["modelPackageName"] as? String == modelPackageName else {
            return "modelPackageName must be \(modelPackageName)"
        }
        guard let files = object["files"] as? [[String: Any]],
              files.count >= 2,
              files.count <= maxManifestFileCount else {
            return "files must list \(packageManifestFileName) plus model data"
        }

        var seenPaths = Set<String>()
        var hasPackageManifest = false
        var hasModelPayload = false
        var totalManifestBytes: UInt64 = 0
        for (index, file) in files.enumerated() {
            guard let path = file["path"] as? String,
                  isSafePackageRelativePath(path) else {
                return "files[\(index)].path must be a package-relative file"
            }
            guard seenPaths.insert(path).inserted else {
                return "files[\(index)].path duplicates \(pathDiagnostic(path))"
            }
            guard let bytes = unsignedIntegerValue(file["bytes"]), bytes > 0 else {
                return "files[\(index)].bytes must be a positive integer"
            }
            guard bytes <= maxPackageFileBytes else {
                return "files[\(index)].bytes exceeds package file limit"
            }
            guard totalManifestBytes <= maxPackageTotalBytes - bytes else {
                return "files total exceeds package size limit"
            }
            totalManifestBytes += bytes
            guard let sha256 = file["sha256"] as? String,
                  isValidSHA256Hex(sha256) else {
                return "files[\(index)].sha256 must be a SHA-256 hex digest"
            }
            hasPackageManifest = hasPackageManifest || path == packageManifestFileName
            hasModelPayload = hasModelPayload || path != packageManifestFileName
        }

        guard hasPackageManifest, hasModelPayload else {
            return "files must include \(packageManifestFileName) and at least one model payload file"
        }
        return nil
    }

    private static func packageFiles(from object: [String: Any]) -> [PackageFile] {
        guard let files = object["files"] as? [[String: Any]] else {
            return []
        }
        return files.compactMap { file in
            guard let path = file["path"] as? String,
                  let bytes = unsignedIntegerValue(file["bytes"]),
                  let sha256 = file["sha256"] as? String else {
                return nil
            }
            return PackageFile(path: path, bytes: bytes, sha256: sha256.lowercased())
        }
    }

    private static func packageContentsProblem(
        manifest: InstallManifest,
        packageURL: URL,
        modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> String? {
        var verifiedPayloadFile = false
        let declaredPaths = Set(manifest.files.map(\.path))
        for file in manifest.files {
            let fileURL = packageURL.appendingPathComponent(file.path, isDirectory: false)
            let displayName = "\(modelPackageName)/\(pathDiagnostic(file.path))"
            if let shapeProblem = artifactProblem(
                name: displayName,
                url: fileURL,
                kind: .file,
                rootURL: modelDirectoryURL,
                fileManager: fileManager
            ) {
                return shapeProblem
            }
            guard let fileSize = regularFileSizeNoFollow(at: fileURL) else {
                return "\(displayName) could not be read safely"
            }
            guard fileSize == file.bytes else {
                return "\(displayName) size mismatch"
            }
            guard fileSize <= maxPackageFileBytes else {
                return "\(displayName) exceeds package file limit"
            }
            guard let digest = fileDigestNoFollow(at: fileURL, expectedBytes: file.bytes) else {
                return "\(displayName) could not be read safely"
            }
            guard digest.sha256 == file.sha256 else {
                return "\(displayName) digest mismatch"
            }
            verifiedPayloadFile = verifiedPayloadFile || file.path != packageManifestFileName
        }
        if let coverageProblem = packageCoverageProblem(
            declaredPaths: declaredPaths,
            packageURL: packageURL,
            fileManager: fileManager
        ) {
            return coverageProblem
        }
        return verifiedPayloadFile ? nil : "\(modelPackageName) has no verified model payload file"
    }

    private static func packageCoverageProblem(
        declaredPaths: Set<String>,
        packageURL: URL,
        fileManager: FileManager
    ) -> String? {
        guard let enumerator = fileManager.enumerator(
            at: packageURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return "\(modelPackageName) could not be enumerated"
        }

        var visited = 0
        var seenFiles = Set<String>()
        for case let url as URL in enumerator {
            visited += 1
            guard visited <= maxPackageEntryCount else {
                return "\(modelPackageName) contains too many entries"
            }
            guard let relativePath = packageRelativePath(url, relativeTo: packageURL) else {
                return "\(modelPackageName) contains an unreadable path"
            }

            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            } catch {
                return "\(modelPackageName)/\(pathDiagnostic(relativePath)) attributes unavailable"
            }
            if values.isSymbolicLink == true {
                return "\(modelPackageName)/\(pathDiagnostic(relativePath)) is a symlink"
            }
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true else {
                return "\(modelPackageName)/\(pathDiagnostic(relativePath)) is not a regular file"
            }
            guard declaredPaths.contains(relativePath) else {
                return "\(modelPackageName)/\(pathDiagnostic(relativePath)) is not listed in manifest"
            }
            seenFiles.insert(relativePath)
        }

        guard seenFiles == declaredPaths else {
            return "\(modelPackageName) manifest does not match package contents"
        }
        return nil
    }

    private static func readManifestDataNoFollow(at url: URL) -> Data? {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            return nil
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxManifestBytes) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count <= maxManifestBytes else {
            return nil
        }
        return data
    }

    private static func regularFileSizeNoFollow(at url: URL) -> UInt64? {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_size > 0 else {
            close(fd)
            return nil
        }
        close(fd)
        return UInt64(fileStatus.st_size)
    }

    private static func fileDigestNoFollow(at url: URL, expectedBytes: UInt64) -> FileDigest? {
        guard expectedBytes > 0,
              expectedBytes <= maxPackageFileBytes else {
            return nil
        }

        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_size > 0,
              UInt64(fileStatus.st_size) == expectedBytes else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }

        var hasher = SHA256()
        var bytesRead: UInt64 = 0
        while true {
            let chunk: Data
            do {
                guard let nextChunk = try handle.read(upToCount: hashReadChunkBytes) else {
                    break
                }
                chunk = nextChunk
            } catch {
                return nil
            }
            guard !chunk.isEmpty else {
                break
            }
            bytesRead += UInt64(chunk.count)
            guard bytesRead <= expectedBytes else {
                return nil
            }
            hasher.update(data: chunk)
        }
        guard bytesRead == expectedBytes else {
            return nil
        }

        return FileDigest(
            bytes: bytesRead,
            sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }

    private static func artifactProblem(
        name: String,
        url: URL,
        kind: ArtifactKind,
        rootURL: URL,
        fileManager: FileManager
    ) -> String? {
        if let component = firstSymlinkComponent(in: url, fileManager: fileManager) {
            return "\(name) path must not include symlink component at \(pathDiagnostic(component, relativeTo: rootURL))"
        }
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name)"
        }
        guard resolvesInsideModelDirectory(url, relativeTo: rootURL) else {
            return "\(name) resolves outside \(modelDirectoryName)"
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            return "\(name) attributes unavailable"
        }
        switch kind {
        case .file:
            guard !isDirectory.boolValue else {
                return "\(name) is a directory"
            }
            return attributes[.type] as? FileAttributeType == .typeRegular
                ? nil
                : "\(name) is not a regular file"
        case .directory:
            guard isDirectory.boolValue else {
                return "\(name) is not a directory"
            }
            return attributes[.type] as? FileAttributeType == .typeDirectory
                ? nil
                : "\(name) is not a real directory"
        }
    }

    private static func unsignedIntegerValue(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int, value >= 0 {
            return UInt64(value)
        }
        if let value = value as? NSNumber {
            guard CFGetTypeID(value as CFTypeRef) != CFBooleanGetTypeID() else {
                return nil
            }
            let doubleValue = value.doubleValue
            guard doubleValue.isFinite,
                  doubleValue >= 0,
                  doubleValue.rounded(.towardZero) == doubleValue,
                  doubleValue <= Double(UInt64.max) else {
                return nil
            }
            return UInt64(doubleValue)
        }
        return nil
    }

    private static func isSafePackageRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              path.count <= maxPackageFilePathLength,
              !path.hasPrefix("/"),
              !path.hasSuffix("/") else {
            return false
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else {
            return false
        }
        for component in components {
            guard component != "." && component != ".." && !component.isEmpty else {
                return false
            }
        }
        return true
    }

    private static func isValidSHA256Hex(_ value: String) -> Bool {
        guard value.count == 64 else {
            return false
        }
        return value.allSatisfy { character in
            character >= "0" && character <= "9" || character >= "a" && character <= "f"
        }
    }

    private static func firstSymlinkComponent(
        in url: URL,
        fileManager: FileManager
    ) -> URL? {
        var cursor = URL(fileURLWithPath: "/", isDirectory: true)
        for component in URL(fileURLWithPath: url.path).standardizedFileURL.pathComponents.dropFirst() {
            cursor = cursor.appendingPathComponent(component)
            guard !isMacOSCompatibilitySymlink(cursor) else {
                continue
            }
            if (try? fileManager.destinationOfSymbolicLink(atPath: cursor.path)) != nil {
                return cursor
            }
        }
        return nil
    }

    private static func isMacOSCompatibilitySymlink(_ url: URL) -> Bool {
        switch url.path {
        case "/etc", "/tmp", "/var":
            return true
        default:
            return false
        }
    }

    private static func resolvesInsideModelDirectory(_ url: URL, relativeTo rootURL: URL) -> Bool {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        return resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }

    private static func packageRelativePath(_ url: URL, relativeTo packageURL: URL) -> String? {
        let root = packageURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        let prefix = root + "/"
        guard path.hasPrefix(prefix) else {
            return nil
        }
        return String(path.dropFirst(prefix.count))
    }

    private static func pathDiagnostic(_ url: URL, relativeTo rootURL: URL) -> String {
        let component = url.standardizedFileURL.path
        let root = rootURL.standardizedFileURL.path
        let description: String
        if component == root {
            description = modelDirectoryName
        } else if component.hasPrefix(root + "/") {
            description = String(component.dropFirst(root.count + 1))
        } else {
            description = url.lastPathComponent
        }
        return pathDiagnostic(description)
    }

    private static func pathDiagnostic(_ value: String) -> String {
        rawBoundedDiagnostic(value, maxCharacters: maxPathDiagnosticLength, fallback: "[path]")
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
