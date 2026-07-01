import Darwin
import CryptoKit
import Foundation

nonisolated enum KokoroVoiceGateStatus {
    static let flagName = "EPISTEMOS_KOKORO_VOICE_PRO_V0"
    static let modelDirectoryName = "kokoro-82m-coreml"
    static let manifestFileName = "KokoroRuntimeManifest.json"
    static let hostedManifestFileName = "HostedManifest.json"
    static let sdkReleaseManifestPath = "sdk/SDKReleaseManifest.json"
    static let manifestSchemaVersion = 1
    static let modelIdentifier = "kokoro-82m"
    static let upstreamRepositoryID = "mattmireles/kokoro-coreml"
    static let runtimeIdentifier = "coreml"
    static let coreMLDirectoryPrefix = "coreml/"
    static let coreMLDataPathPrefix = "Data/com.apple.CoreML/"
    static let packageManifestFileName = "Manifest.json"
    static let runtimeVocabPath = "runtime/kokoro-vocab.json"
    static let runtimeHNSFWeightsPath = "runtime/hnsf_weights.json"
    static let starterVoicePath = "voices/af_heart.bin"
    static let starterVoiceIdentifier = "af_heart"
    static let sampleRateHz = 24_000
    static let starterVoiceEmbeddingDimensions = 256
    static let maxManifestBytes = 256 * 1024
    static let maxManifestFileCount = 4_096
    static let maxPackageEntryCount = 250_000
    static let maxPackageFileBytes = UInt64(2) * 1024 * 1024 * 1024
    static let maxPackageTotalBytes = UInt64(4) * 1024 * 1024 * 1024
    private static let maxPathDiagnosticLength = 160
    private static let maxPackageFilePathLength = 280
    private static let maxManifestMetadataCharacters = 96
    private static let manifestMetadataAllowedPunctuation = CharacterSet(charactersIn: "._-")
    private static let hashReadChunkBytes = 1024 * 1024
    private static let requiredDurationTokenSizes: Set<Int> = [32, 64, 128, 256, 320, 384, 512]
    private static let allowedBuckets: Set<Int> = [3, 7, 10, 15, 30]
    private static let f0FrameCountsByBucket: [Int: Int] = [
        3: 120,
        7: 280,
        10: 400,
        15: 600,
        30: 1_200,
    ]

    enum State: String, Equatable, Sendable {
        case unavailable
        case missingModel
        case packageReady
    }

    struct Status: Equatable, Sendable {
        let state: State
        /// Runtime readiness, not merely model-package readiness. True only
        /// when the checked package can feed the native Kokoro playback path.
        let isReady: Bool
        let headline: String
        let detail: String
        var packageEvidence: PackageEvidence? = nil
    }

    struct PackageEvidence: Equatable, Sendable {
        let modelDirectoryName: String
        let manifestFileName: String
        let runtimeIdentifier: String
        let hfRepositoryID: String
        let bundleProfile: String
        let modelPackageCount: Int
        let voiceCount: Int
        let runtimeAssetCount: Int
        let manifestFileCount: Int
        let declaredPackageBytes: UInt64

        var settingsSummary: String {
            let packageLabel = modelPackageCount == 1 ? "Core ML package" : "Core ML packages"
            let voiceLabel = voiceCount == 1 ? "voice" : "voices"
            let fileLabel = manifestFileCount == 1 ? "file" : "files"
            return "\(manifestFileName): \(modelPackageCount) checked \(packageLabel), \(voiceCount) \(voiceLabel), \(runtimeAssetCount) runtime assets, \(manifestFileCount) checked \(fileLabel), \(declaredPackageBytes) declared bytes, \(runtimeIdentifier) native bundle. Kokoro playback uses this native bundle when the Pro runtime is active."
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
            detail: "Text-to-speech is Kokoro-only. The App Store build does not include the Pro Kokoro runtime package; Apple AVSpeech is not used as a fallback."
        )
        #else
        guard isEnabled(environment[flagName]) else {
            return Status(
                state: .unavailable,
                isReady: false,
                headline: "Kokoro voice: off",
                detail: "Set \(flagName)=1 in a Pro build after installing the checked \(upstreamRepositoryID) CoreML bundle. Off means text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
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
        let manifestCheck = runtimeManifestProblem(
            name: manifestFileName,
            url: manifestURL,
            rootURL: modelDirectory,
            fileManager: fileManager
        )

        var problems = [String]()
        if let manifestProblem = manifestCheck.problem {
            problems.append(manifestProblem)
        }
        if let manifest = manifestCheck.manifest,
           let contentsProblem = runtimeBundleContentsProblem(
                manifest: manifest,
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
                detail: "Expected \(modelDirectoryName) from \(upstreamRepositoryID), but \(problems.joined(separator: ", ")). Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
            )
        }

        let packageEvidence = manifestCheck.manifest.map(packageEvidence(from:))
        let runtimeLinked = KokoroCoreMLRuntimeLoader.isLinked
        return Status(
            state: .packageReady,
            isReady: runtimeLinked,
            headline: runtimeLinked
                ? "Kokoro voice: native CoreML playback ready"
                : "Kokoro voice: CoreML runtime package ready, runtime not linked",
            detail: runtimeLinked
                ? "The checked Pro \(upstreamRepositoryID) runtime manifest, segmented CoreML packages, runtime assets, and starter voice digests match in \(modelDirectoryName). Native Swift/CoreML Kokoro playback is available; Apple AVSpeech is not used as a fallback."
                : "The checked Pro \(upstreamRepositoryID) runtime manifest, segmented CoreML packages, runtime assets, and starter voice digests match in \(modelDirectoryName), but KokoroPipeline is not linked in this build. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback.",
            packageEvidence: packageEvidence
        )
        #endif
    }

    private struct RuntimeManifest {
        let hfRepositoryID: String
        let bundleProfile: String
        let durationTokenSizes: Set<Int>
        let buckets: Set<Int>
        let modelPackages: [ModelPackage]
        let voices: [PackageFile]
        let runtimeAssets: [PackageFile]
    }

    private struct ManifestCheck {
        let manifest: RuntimeManifest?
        let problem: String?
    }

    private struct ModelPackage {
        let path: String
        let fileCount: Int
        let bytes: UInt64
        let files: [PackageFile]
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

    private static func packageEvidence(from manifest: RuntimeManifest) -> PackageEvidence {
        let declaredFiles = declaredBundleFiles(from: manifest)
        return PackageEvidence(
            modelDirectoryName: modelDirectoryName,
            manifestFileName: manifestFileName,
            runtimeIdentifier: runtimeIdentifier,
            hfRepositoryID: manifest.hfRepositoryID,
            bundleProfile: manifest.bundleProfile,
            modelPackageCount: manifest.modelPackages.count,
            voiceCount: manifest.voices.count,
            runtimeAssetCount: manifest.runtimeAssets.count,
            manifestFileCount: declaredFiles.count,
            declaredPackageBytes: declaredFiles.reduce(UInt64(0)) { $0 + $1.bytes }
        )
    }

    private static func runtimeManifestProblem(
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
        return runtimeManifest(from: dictionary)
    }

    private static func runtimeManifest(from object: [String: Any]) -> ManifestCheck {
        guard unsignedIntegerValue(object["schema_version"]) == UInt64(manifestSchemaVersion) else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) schema_version must be \(manifestSchemaVersion)")
        }
        guard requiredString(object["hf_repo_id"]) == upstreamRepositoryID else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) hf_repo_id must be \(upstreamRepositoryID)")
        }
        let bundleProfile: String
        if object.keys.contains("bundle_profile") {
            guard let profile = manifestMetadataString(object["bundle_profile"]) else {
                return ManifestCheck(manifest: nil, problem: "\(manifestFileName) bundle_profile is invalid")
            }
            bundleProfile = profile
        } else {
            bundleProfile = "unknown"
        }

        guard let minimumPlatforms = object["minimum_platforms"] as? [String: Any],
              let macOSMinimum = requiredString(minimumPlatforms["macOS"]),
              compareVersion(macOSMinimum, minimum: "15.0") else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) minimum_platforms.macOS must be at least 15.0")
        }
        guard let languages = object["supported_languages"] as? [String],
              languages.contains("en-US") else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) supported_languages must include en-US")
        }
        guard let durationTokenSizes = integerSet(object["duration_token_sizes"]),
              requiredDurationTokenSizes.isSubset(of: durationTokenSizes) else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) duration_token_sizes must include 32,64,128,256,320,384,512")
        }
        guard let buckets = integerSet(object["buckets"]),
              !buckets.isEmpty,
              buckets.isSubset(of: allowedBuckets) else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) buckets must be one or more of 3,7,10,15,30")
        }
        guard let packageObjects = object["model_packages"] as? [[String: Any]],
              !packageObjects.isEmpty,
              packageObjects.count <= maxManifestFileCount else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) model_packages must list Core ML packages")
        }
        let packageParse = modelPackages(from: packageObjects)
        if let problem = packageParse.problem {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) \(problem)")
        }
        let modelPackages = packageParse.packages
        if let familyProblem = modelPackageFamilyProblem(
            modelPackages,
            durationTokenSizes: durationTokenSizes,
            buckets: buckets
        ) {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) \(familyProblem)")
        }

        guard let voiceObjects = object["voices"] as? [[String: Any]],
              !voiceObjects.isEmpty,
              voiceObjects.count <= 128 else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) voices must list Kokoro voice embeddings")
        }
        let voiceParse = packageFiles(
            from: voiceObjects,
            fieldName: "voices",
            pathPolicy: isSafeVoicePath
        )
        if let problem = voiceParse.problem {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) \(problem)")
        }
        guard voiceParse.files.contains(where: { $0.path == starterVoicePath }) else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) voices must include \(starterVoiceIdentifier)")
        }

        guard let runtimeAssetObject = object["runtime_assets"] as? [String: Any] else {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) runtime_assets must list tokenizer and hnsf weights")
        }
        let runtimeAssets = runtimeAssetFiles(from: runtimeAssetObject)
        if let problem = runtimeAssets.problem {
            return ManifestCheck(manifest: nil, problem: "\(manifestFileName) \(problem)")
        }

        let manifest = RuntimeManifest(
            hfRepositoryID: upstreamRepositoryID,
            bundleProfile: bundleProfile,
            durationTokenSizes: durationTokenSizes,
            buckets: buckets,
            modelPackages: modelPackages,
            voices: voiceParse.files,
            runtimeAssets: runtimeAssets.files
        )
        return ManifestCheck(manifest: manifest, problem: nil)
    }

    private static func modelPackages(
        from objects: [[String: Any]]
    ) -> (packages: [ModelPackage], problem: String?) {
        var packages = [ModelPackage]()
        var seenPaths = Set<String>()
        var totalManifestBytes: UInt64 = 0

        for (index, object) in objects.enumerated() {
            guard let path = requiredString(object["path"]),
                  isSafeModelPackagePath(path) else {
                return ([], "model_packages[\(index)].path must be a coreml/*.mlpackage directory")
            }
            guard seenPaths.insert(path).inserted else {
                return ([], "model_packages[\(index)].path duplicates \(pathDiagnostic(path))")
            }
            guard let fileCount = unsignedIntegerValue(object["file_count"]),
                  fileCount > 0,
                  fileCount <= UInt64(maxManifestFileCount) else {
                return ([], "model_packages[\(index)].file_count is invalid")
            }
            guard let bytes = unsignedIntegerValue(object["bytes"]),
                  bytes > 0,
                  bytes <= maxPackageTotalBytes,
                  totalManifestBytes <= maxPackageTotalBytes - bytes else {
                return ([], "model_packages[\(index)].bytes exceeds package size limit")
            }
            totalManifestBytes += bytes
            guard let fileObjects = object["files"] as? [[String: Any]],
                  fileObjects.count == Int(fileCount) else {
                return ([], "model_packages[\(index)].files must match file_count")
            }
            let filesParse = packageFiles(
                from: fileObjects,
                fieldName: "model_packages[\(index)].files",
                pathPolicy: isSafeModelPackageRelativeFilePath
            )
            if let problem = filesParse.problem {
                return ([], problem)
            }
            let packageRelativePaths = Set(filesParse.files.map(\.path))
            let hasPackageManifest = packageRelativePaths.contains(packageManifestFileName)
            let hasCoreMLPayload = packageRelativePaths.contains { $0.hasPrefix(coreMLDataPathPrefix) }
            guard hasPackageManifest, hasCoreMLPayload else {
                return ([], "model_packages[\(index)].files must include \(packageManifestFileName) and Core ML data")
            }
            let declaredBytes = filesParse.files.reduce(UInt64(0)) { $0 + $1.bytes }
            guard declaredBytes == bytes else {
                return ([], "model_packages[\(index)].bytes must equal declared file bytes")
            }
            packages.append(ModelPackage(
                path: path,
                fileCount: Int(fileCount),
                bytes: bytes,
                files: filesParse.files
            ))
        }
        return (packages, nil)
    }

    private static func packageFiles(
        from objects: [[String: Any]],
        fieldName: String,
        pathPolicy: (String) -> Bool
    ) -> (files: [PackageFile], problem: String?) {
        var files = [PackageFile]()
        var seenPaths = Set<String>()
        var totalBytes: UInt64 = 0

        for (index, object) in objects.enumerated() {
            guard let path = requiredString(object["path"]),
                  pathPolicy(path) else {
                return ([], "\(fieldName)[\(index)].path is invalid")
            }
            guard seenPaths.insert(path).inserted else {
                return ([], "\(fieldName)[\(index)].path duplicates \(pathDiagnostic(path))")
            }
            guard let bytes = unsignedIntegerValue(object["bytes"]), bytes > 0 else {
                return ([], "\(fieldName)[\(index)].bytes must be a positive integer")
            }
            guard bytes <= maxPackageFileBytes,
                  totalBytes <= maxPackageTotalBytes - bytes else {
                return ([], "\(fieldName)[\(index)].bytes exceeds package size limit")
            }
            totalBytes += bytes
            guard let sha256 = object["sha256"] as? String,
                  isValidSHA256Hex(sha256) else {
                return ([], "\(fieldName)[\(index)].sha256 must be a SHA-256 hex digest")
            }
            files.append(PackageFile(path: path, bytes: bytes, sha256: sha256.lowercased()))
        }
        return (files, nil)
    }

    private static func runtimeAssetFiles(
        from object: [String: Any]
    ) -> (files: [PackageFile], problem: String?) {
        let expected: [(key: String, path: String)] = [
            ("vocab", runtimeVocabPath),
            ("hnsf_weights", runtimeHNSFWeightsPath),
        ]
        var files = [PackageFile]()
        for item in expected {
            guard let asset = object[item.key] as? [String: Any] else {
                return ([], "runtime_assets.\(item.key) is missing")
            }
            let parsed = packageFiles(
                from: [asset],
                fieldName: "runtime_assets.\(item.key)",
                pathPolicy: { $0 == item.path }
            )
            if let problem = parsed.problem {
                return ([], problem)
            }
            files.append(contentsOf: parsed.files)
        }
        return (files, nil)
    }

    private static func modelPackageFamilyProblem(
        _ packages: [ModelPackage],
        durationTokenSizes: Set<Int>,
        buckets: Set<Int>
    ) -> String? {
        let names = Set(packages.map { URL(fileURLWithPath: $0.path).lastPathComponent })
        let missingDurationSizes = durationTokenSizes.sorted().filter { tokenSize in
            !names.contains("kokoro_duration_t\(tokenSize).mlpackage")
                && !names.contains("kokoro_duration_exact_t\(tokenSize).mlpackage")
        }
        if !missingDurationSizes.isEmpty {
            return "model_packages must include duration Core ML packages for token sizes \(missingDurationSizes.map(String.init).joined(separator: ","))"
        }

        var missingBucketPackages = [String]()
        for bucket in buckets.sorted() {
            guard let frameCount = f0FrameCountsByBucket[bucket] else {
                return "model_packages bucket \(bucket) has no known f0ntrain frame count"
            }
            let requiredNames = [
                "kokoro_f0ntrain_t\(frameCount).mlpackage",
                "kokoro_decoder_pre_\(bucket)s.mlpackage",
                "kokoro_decoder_har_post_\(bucket)s.mlpackage",
            ]
            missingBucketPackages.append(contentsOf: requiredNames.filter { !names.contains($0) })
        }
        if !missingBucketPackages.isEmpty {
            return "model_packages must include f0ntrain, decoder_pre, and decoder_har_post Core ML packages for buckets \(buckets.sorted().map(String.init).joined(separator: ",")); missing \(missingBucketPackages.joined(separator: ","))"
        }
        return nil
    }

    private static func runtimeBundleContentsProblem(
        manifest: RuntimeManifest,
        modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> String? {
        let declaredFiles = declaredBundleFiles(from: manifest)
        guard declaredFiles.count <= maxManifestFileCount else {
            return "\(manifestFileName) declares too many files"
        }

        for package in manifest.modelPackages {
            let packageURL = modelDirectoryURL.appendingPathComponent(package.path, isDirectory: true)
            if let shapeProblem = artifactProblem(
                name: pathDiagnostic(package.path),
                url: packageURL,
                kind: .directory,
                rootURL: modelDirectoryURL,
                fileManager: fileManager
            ) {
                return shapeProblem
            }
            for file in package.files {
                let fullPath = package.path + "/" + file.path
                if let problem = verifiedDeclaredFileProblem(
                    declaredFile: PackageFile(path: fullPath, bytes: file.bytes, sha256: file.sha256),
                    modelDirectoryURL: modelDirectoryURL,
                    fileManager: fileManager
                ) {
                    return problem
                }
            }
        }

        for file in manifest.runtimeAssets + manifest.voices {
            if let problem = verifiedDeclaredFileProblem(
                declaredFile: file,
                modelDirectoryURL: modelDirectoryURL,
                fileManager: fileManager
            ) {
                return problem
            }
        }

        if let coverageProblem = bundleCoverageProblem(
            declaredFiles: Set(declaredFiles.map(\.path)),
            modelDirectoryURL: modelDirectoryURL,
            fileManager: fileManager
        ) {
            return coverageProblem
        }
        return nil
    }

    private static func verifiedDeclaredFileProblem(
        declaredFile: PackageFile,
        modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> String? {
        let fileURL = modelDirectoryURL.appendingPathComponent(declaredFile.path, isDirectory: false)
        let displayName = pathDiagnostic(declaredFile.path)
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
        guard fileSize == declaredFile.bytes else {
            return "\(displayName) size mismatch"
        }
        guard let digest = fileDigestNoFollow(at: fileURL, expectedBytes: declaredFile.bytes) else {
            return "\(displayName) could not be read safely"
        }
        guard digest.sha256 == declaredFile.sha256 else {
            return "\(displayName) digest mismatch"
        }
        return nil
    }

    private static func bundleCoverageProblem(
        declaredFiles: Set<String>,
        modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> String? {
        guard let enumerator = fileManager.enumerator(
            at: modelDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return "\(modelDirectoryName) could not be enumerated"
        }

        var visited = 0
        var seenFiles = Set<String>()
        for case let url as URL in enumerator {
            visited += 1
            guard visited <= maxPackageEntryCount else {
                return "\(modelDirectoryName) contains too many entries"
            }
            guard let relativePath = bundleRelativePath(url, relativeTo: modelDirectoryURL) else {
                return "\(modelDirectoryName) contains an unreadable path"
            }

            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            } catch {
                return "\(pathDiagnostic(relativePath)) attributes unavailable"
            }
            if values.isSymbolicLink == true {
                return "\(pathDiagnostic(relativePath)) is a symlink"
            }
            if values.isDirectory == true {
                continue
            }
            guard values.isRegularFile == true else {
                return "\(pathDiagnostic(relativePath)) is not a regular file"
            }
            if relativePath == manifestFileName || optionalMetadataPath(relativePath) {
                continue
            }
            guard declaredFiles.contains(relativePath) else {
                return "\(pathDiagnostic(relativePath)) is not listed in \(manifestFileName)"
            }
            seenFiles.insert(relativePath)
        }

        guard seenFiles == declaredFiles else {
            return "\(manifestFileName) manifest does not match package contents"
        }
        return nil
    }

    private static func declaredBundleFiles(from manifest: RuntimeManifest) -> [PackageFile] {
        var files = [PackageFile]()
        for package in manifest.modelPackages {
            files.append(contentsOf: package.files.map {
                PackageFile(path: package.path + "/" + $0.path, bytes: $0.bytes, sha256: $0.sha256)
            })
        }
        files.append(contentsOf: manifest.runtimeAssets)
        files.append(contentsOf: manifest.voices)
        return files
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

    private static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func manifestMetadataString(_ value: Any?) -> String? {
        guard let value = requiredString(value),
              value.count <= maxManifestMetadataCharacters,
              value.rangeOfCharacter(from: .controlCharacters) == nil,
              value.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet.alphanumerics.contains(scalar)
                      || manifestMetadataAllowedPunctuation.contains(scalar)
              }) else {
            return nil
        }
        return value
    }

    private static func integerSet(_ value: Any?) -> Set<Int>? {
        guard let array = value as? [Any] else {
            return nil
        }
        var result = Set<Int>()
        for item in array {
            guard let integer = unsignedIntegerValue(item),
                  integer <= UInt64(Int.max) else {
                return nil
            }
            result.insert(Int(integer))
        }
        return result
    }

    private static func compareVersion(_ version: String, minimum: String) -> Bool {
        let lhs = version.split(separator: ".").compactMap { Int($0) }
        let rhs = minimum.split(separator: ".").compactMap { Int($0) }
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return false
        }
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return true
    }

    private static func isSafeModelPackagePath(_ path: String) -> Bool {
        guard isSafeBundleRelativePath(path),
              path.hasPrefix(coreMLDirectoryPrefix),
              path.hasSuffix(".mlpackage") else {
            return false
        }
        return path.split(separator: "/", omittingEmptySubsequences: false).count == 2
    }

    private static func isSafeModelPackageRelativeFilePath(_ path: String) -> Bool {
        guard isSafeBundleRelativePath(path) else {
            return false
        }
        return path == packageManifestFileName || path.hasPrefix(coreMLDataPathPrefix)
    }

    private static func isSafeVoicePath(_ path: String) -> Bool {
        isSafeBundleRelativePath(path) && path.hasPrefix("voices/") && path.hasSuffix(".bin")
    }

    private static func isSafeBundleRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              path.count <= maxPackageFilePathLength,
              path.rangeOfCharacter(from: .controlCharacters) == nil,
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

    private static func optionalMetadataPath(_ path: String) -> Bool {
        path == hostedManifestFileName || path == sdkReleaseManifestPath || path == "LICENSE" || path == "README.md"
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

    private static func bundleRelativePath(_ url: URL, relativeTo modelDirectoryURL: URL) -> String? {
        let root = modelDirectoryURL.standardizedFileURL.path
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
