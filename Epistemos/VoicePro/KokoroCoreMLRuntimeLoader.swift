import Darwin
import Foundation

#if canImport(KokoroPipeline)
import KokoroPipeline

private nonisolated final class KokoroCoreMLPipelineCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: KokoroPipeline] = [:]

    func pipeline(
        for resources: KokoroCoreMLRuntimeLoader.RuntimeResources,
        builder: () throws -> KokoroPipeline
    ) throws -> KokoroPipeline {
        let key = cacheKey(for: resources)
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let pipeline = try builder()
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        cache[key] = pipeline
        lock.unlock()
        return pipeline
    }

    private func cacheKey(for resources: KokoroCoreMLRuntimeLoader.RuntimeResources) -> String {
        let manifestStamp = fileStamp(at: resources.manifestURL)
        return [
            resources.coreMLDirectoryURL.resolvingSymlinksInPath().path,
            manifestStamp,
            "\(resources.buckets)",
            "\(resources.durationTokenSizes)",
        ].joined(separator: "|")
    }

    private func fileStamp(at url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return "missing"
        }
        let size = attrs[.size] as? NSNumber
        let modified = attrs[.modificationDate] as? Date
        return "\(size?.uint64Value ?? 0):\(modified?.timeIntervalSince1970 ?? 0)"
    }
}
#endif

nonisolated enum KokoroCoreMLRuntimeLoader {
    static let maxRuntimeAssetBytes = 2 * 1024 * 1024
    private static let maxRuntimeProblemCharacters = 160

    struct HNSFWeights: Equatable, Sendable {
        let linearWeights: [Float]
        let linearBias: Float
    }

    struct RuntimeResources: Equatable, Sendable {
        let modelDirectoryURL: URL
        let coreMLDirectoryURL: URL
        let manifestURL: URL
        let vocabularyURL: URL
        let hnsfWeightsURL: URL
        let starterVoiceURL: URL
        let vocabulary: [String: Int32]
        let hnsfWeights: HNSFWeights
        let starterVoiceEmbedding: [Float]
        let buckets: [Int]
        let durationTokenSizes: [Int]
        let sampleRateHz: Int
    }

    private struct RuntimeManifestShape {
        let buckets: [Int]
        let durationTokenSizes: [Int]
    }

    enum LoadError: Equatable, Error, LocalizedError, Sendable {
        case packageNotReady(String)
        case runtimeNotLinked
        case runtimeAssetUnreadable(String)
        case invalidVocabulary(String)
        case invalidHNSFWeights(String)
        case invalidStarterVoice(String)
        case pipelineLoadFailed(String)

        var errorDescription: String? {
            switch self {
            case .packageNotReady(let detail):
                return "Kokoro package is not ready: \(detail)"
            case .runtimeNotLinked:
                return "KokoroPipeline is not linked in this build."
            case .runtimeAssetUnreadable(let detail):
                return "Kokoro runtime asset could not be read: \(detail)"
            case .invalidVocabulary(let detail):
                return "Kokoro vocabulary is invalid: \(detail)"
            case .invalidHNSFWeights(let detail):
                return "Kokoro HNSF weights are invalid: \(detail)"
            case .invalidStarterVoice(let detail):
                return "Kokoro starter voice is invalid: \(detail)"
            case .pipelineLoadFailed(let detail):
                return "Kokoro CoreML pipeline could not be loaded: \(detail)"
            }
        }
    }

    static var isLinked: Bool {
        #if canImport(KokoroPipeline)
        true
        #else
        false
        #endif
    }

    static func resources(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) throws -> RuntimeResources {
        let status = KokoroVoiceGateStatus.status(
            environment: environment,
            modelRoot: modelRoot,
            fileManager: fileManager
        )
        guard status.state == .packageReady, let modelRoot else {
            throw LoadError.packageNotReady(status.detail)
        }

        let modelDirectory = modelRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        let coreMLDirectory = modelDirectory.appendingPathComponent("coreml", isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(
            KokoroVoiceGateStatus.manifestFileName,
            isDirectory: false
        )
        let vocabularyURL = modelDirectory.appendingPathComponent(
            KokoroVoiceGateStatus.runtimeVocabPath,
            isDirectory: false
        )
        let hnsfURL = modelDirectory.appendingPathComponent(
            KokoroVoiceGateStatus.runtimeHNSFWeightsPath,
            isDirectory: false
        )
        let voiceURL = modelDirectory.appendingPathComponent(
            KokoroVoiceGateStatus.starterVoicePath,
            isDirectory: false
        )

        let manifestShape = try readRuntimeManifestShape(at: manifestURL)
        let vocabulary = try readVocabulary(at: vocabularyURL)
        let hnsfWeights = try readHNSFWeights(at: hnsfURL)
        let starterVoiceEmbedding = try validateStarterVoice(at: voiceURL)

        return RuntimeResources(
            modelDirectoryURL: modelDirectory,
            coreMLDirectoryURL: coreMLDirectory,
            manifestURL: manifestURL,
            vocabularyURL: vocabularyURL,
            hnsfWeightsURL: hnsfURL,
            starterVoiceURL: voiceURL,
            vocabulary: vocabulary,
            hnsfWeights: hnsfWeights,
            starterVoiceEmbedding: starterVoiceEmbedding,
            buckets: manifestShape.buckets,
            durationTokenSizes: manifestShape.durationTokenSizes,
            sampleRateHz: KokoroVoiceGateStatus.sampleRateHz
        )
    }

    /// Load + validate a specific installed voice embedding by its bare Kokoro voice name
    /// (e.g. "af_heart", "am_adam"). Returns nil for an unsafe / unknown / invalid voice so the
    /// caller falls back to the starter voice — voice SELECTION must never break synthesis.
    /// The embedding is validated identically to the starter (same [rows, 256] shape), so a
    /// valid voice pack renders through the exact same reference-style path.
    static func voiceEmbedding(named voiceName: String, in modelDirectoryURL: URL) -> [Float]? {
        guard isSafeVoiceName(voiceName) else { return nil }
        let url = modelDirectoryURL.appendingPathComponent("voices/\(voiceName).bin", isDirectory: false)
        return try? validateStarterVoice(at: url)
    }

    /// A bare voice name — no path separators / traversal, ASCII alphanumeric + underscore only.
    private static func isSafeVoiceName(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= 64
            && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }

    static func runtimeResourceShapeProblem(modelDirectoryURL: URL) -> String? {
        let manifestURL = modelDirectoryURL.appendingPathComponent(
            KokoroVoiceGateStatus.manifestFileName,
            isDirectory: false
        )
        let vocabularyURL = modelDirectoryURL.appendingPathComponent(
            KokoroVoiceGateStatus.runtimeVocabPath,
            isDirectory: false
        )
        let hnsfURL = modelDirectoryURL.appendingPathComponent(
            KokoroVoiceGateStatus.runtimeHNSFWeightsPath,
            isDirectory: false
        )
        let voiceURL = modelDirectoryURL.appendingPathComponent(
            KokoroVoiceGateStatus.starterVoicePath,
            isDirectory: false
        )

        do {
            _ = try readRuntimeManifestShape(at: manifestURL)
            _ = try readVocabulary(at: vocabularyURL)
            _ = try readHNSFWeights(at: hnsfURL)
            _ = try validateStarterVoice(at: voiceURL)
            return nil
        } catch let error as LoadError {
            return boundedRuntimeProblem(runtimeResourceProblemDetail(error))
        } catch {
            return "runtime assets are invalid"
        }
    }

    #if canImport(KokoroPipeline)
    private static let pipelineCache = KokoroCoreMLPipelineCache()

    static func loadPipeline(resources: RuntimeResources) throws -> KokoroPipeline {
        do {
            return try pipelineCache.pipeline(for: resources) {
                try KokoroPipeline(
                    modelsDirectory: resources.coreMLDirectoryURL,
                    buckets: resources.buckets,
                    linearWeights: resources.hnsfWeights.linearWeights,
                    linearBias: resources.hnsfWeights.linearBias
                )
            }
        } catch {
            throw LoadError.pipelineLoadFailed(runtimeDiagnostic(error))
        }
    }
    #else
    static func loadPipeline(resources _: RuntimeResources) throws -> Never {
        throw LoadError.runtimeNotLinked
    }
    #endif

    private static func readVocabulary(at url: URL) throws -> [String: Int32] {
        let data = try readRuntimeAssetDataNoFollow(at: url, name: KokoroVoiceGateStatus.runtimeVocabPath)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw LoadError.invalidVocabulary("JSON decode failed")
        }
        guard let dictionary = object as? [String: Any],
              let rawVocabulary = dictionary["vocab"] as? [String: Any],
              !rawVocabulary.isEmpty else {
            throw LoadError.invalidVocabulary("expected non-empty vocab object")
        }

        var vocabulary = [String: Int32]()
        vocabulary.reserveCapacity(rawVocabulary.count)
        for (symbol, rawTokenID) in rawVocabulary {
            guard !symbol.isEmpty else {
                throw LoadError.invalidVocabulary("vocab symbols must be non-empty")
            }
            guard let tokenID = integerValue(rawTokenID),
                  tokenID > 0,
                  tokenID <= Int(Int32.max) else {
                throw LoadError.invalidVocabulary("vocab token ids must be positive Int32 values")
            }
            vocabulary[symbol] = Int32(tokenID)
        }
        guard vocabulary[" "] == 16 else {
            throw LoadError.invalidVocabulary("whitespace token id is missing")
        }
        return vocabulary
    }

    private static func readHNSFWeights(at url: URL) throws -> HNSFWeights {
        let data = try readRuntimeAssetDataNoFollow(at: url, name: KokoroVoiceGateStatus.runtimeHNSFWeightsPath)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw LoadError.invalidHNSFWeights("JSON decode failed")
        }
        guard let dictionary = object as? [String: Any] else {
            throw LoadError.invalidHNSFWeights("expected JSON object")
        }
        guard let rawWeights = dictionary["linear_weights"] as? [Any],
              rawWeights.count == 9 else {
            throw LoadError.invalidHNSFWeights("linear_weights must contain 9 values")
        }
        var weights = [Float]()
        weights.reserveCapacity(rawWeights.count)
        for value in rawWeights {
            guard let double = finiteDouble(value) else {
                throw LoadError.invalidHNSFWeights("linear_weights must be finite numbers")
            }
            weights.append(Float(double))
        }
        guard let linearBias = finiteDouble(dictionary["linear_bias"]) else {
            throw LoadError.invalidHNSFWeights("linear_bias must be a finite number")
        }
        return HNSFWeights(linearWeights: weights, linearBias: Float(linearBias))
    }

    private static func readRuntimeManifestShape(at url: URL) throws -> RuntimeManifestShape {
        let data = try readRuntimeAssetDataNoFollow(at: url, name: KokoroVoiceGateStatus.manifestFileName)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw LoadError.runtimeAssetUnreadable(KokoroVoiceGateStatus.manifestFileName)
        }
        guard let dictionary = object as? [String: Any],
              let buckets = integerArray(dictionary["buckets"]),
              !buckets.isEmpty,
              let durationTokenSizes = integerArray(dictionary["duration_token_sizes"]),
              !durationTokenSizes.isEmpty else {
            throw LoadError.runtimeAssetUnreadable(KokoroVoiceGateStatus.manifestFileName)
        }
        return RuntimeManifestShape(
            buckets: buckets.sorted(),
            durationTokenSizes: durationTokenSizes.sorted()
        )
    }

    private static func validateStarterVoice(at url: URL) throws -> [Float] {
        let data = try readRuntimeAssetDataNoFollow(at: url, name: KokoroVoiceGateStatus.starterVoicePath)
        let byteCount = UInt64(data.count)
        guard byteCount % UInt64(MemoryLayout<Float>.size) == 0 else {
            throw LoadError.invalidStarterVoice("voice embedding bytes must align to Float32")
        }
        let floatCount = byteCount / UInt64(MemoryLayout<Float>.size)
        // Kokoro voice packs ship the full per-length style tensor of shape
        // [rows, 256] (one 256-float reference vector per input length), so the
        // embedding is any positive whole number of 256-float rows. The single
        // 256-float refS handed to the pipeline is sliced per chunk at synthesis
        // time (see KokoroCoreMLSynthesizer.referenceStyleVector).
        let embeddingDimensions = UInt64(KokoroVoiceGateStatus.starterVoiceEmbeddingDimensions)
        guard embeddingDimensions > 0,
              floatCount >= embeddingDimensions,
              floatCount % embeddingDimensions == 0 else {
            throw LoadError.invalidStarterVoice("voice embedding must be a positive multiple of \(embeddingDimensions) Float32 values")
        }

        var values = [Float](repeating: 0, count: Int(floatCount))
        _ = values.withUnsafeMutableBytes { buffer in
            data.copyBytes(to: buffer)
        }
        guard values.allSatisfy(\.isFinite) else {
            throw LoadError.invalidStarterVoice("voice embedding must contain finite Float32 values")
        }
        return values
    }

    private static func readRuntimeAssetDataNoFollow(at url: URL, name: String) throws -> Data {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw LoadError.runtimeAssetUnreadable(name)
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw LoadError.runtimeAssetUnreadable(name)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink <= 1,
              fileStatus.st_size > 0,
              UInt64(fileStatus.st_size) <= UInt64(maxRuntimeAssetBytes) else {
            close(fd)
            throw LoadError.runtimeAssetUnreadable(name)
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              !data.isEmpty,
              data.count <= maxRuntimeAssetBytes else {
            throw LoadError.runtimeAssetUnreadable(name)
        }
        return data
    }

    private static func regularFileByteCountNoFollow(at url: URL, name: String) throws -> UInt64 {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw LoadError.runtimeAssetUnreadable(name)
        }
        defer { close(fd) }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0,
              (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink <= 1,
              fileStatus.st_size > 0,
              UInt64(fileStatus.st_size) <= UInt64(KokoroVoiceGateStatus.maxPackageFileBytes) else {
            throw LoadError.runtimeAssetUnreadable(name)
        }
        return UInt64(fileStatus.st_size)
    }

    private static func finiteDouble(_ value: Any?) -> Double? {
        if let value = value as? Double, value.isFinite {
            return value
        }
        if let value = value as? Float, value.isFinite {
            return Double(value)
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? NSNumber {
            guard CFGetTypeID(value as CFTypeRef) != CFBooleanGetTypeID() else {
                return nil
            }
            let doubleValue = value.doubleValue
            return doubleValue.isFinite ? doubleValue : nil
        }
        return nil
    }

    private static func integerArray(_ value: Any?) -> [Int]? {
        guard let array = value as? [Any] else {
            return nil
        }
        var integers = [Int]()
        integers.reserveCapacity(array.count)
        for item in array {
            guard let integer = integerValue(item) else {
                return nil
            }
            integers.append(integer)
        }
        return integers
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int, value > 0 {
            return value
        }
        if let value = value as? NSNumber {
            guard CFGetTypeID(value as CFTypeRef) != CFBooleanGetTypeID() else {
                return nil
            }
            let doubleValue = value.doubleValue
            guard doubleValue.isFinite,
                  doubleValue > 0,
                  doubleValue.rounded(.towardZero) == doubleValue,
                  doubleValue <= Double(Int.max) else {
                return nil
            }
            return Int(doubleValue)
        }
        return nil
    }

    private static func runtimeDiagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(VoiceCaptureDiagnostics.safeDomain(nsError.domain)) code=\(nsError.code)"
    }

    private static func runtimeResourceProblemDetail(_ error: LoadError) -> String {
        switch error {
        case .packageNotReady(let detail):
            return "runtime asset validation could not start: \(detail)"
        case .runtimeNotLinked:
            return "runtime is not linked"
        case .runtimeAssetUnreadable(let detail):
            return "runtime asset could not be read: \(detail)"
        case .invalidVocabulary(let detail):
            return "runtime vocabulary is invalid: \(detail)"
        case .invalidHNSFWeights(let detail):
            return "runtime HNSF weights are invalid: \(detail)"
        case .invalidStarterVoice(let detail):
            return "runtime starter voice is invalid: \(detail)"
        case .pipelineLoadFailed(let detail):
            return "runtime pipeline could not be loaded: \(detail)"
        }
    }

    private static func boundedRuntimeProblem(_ value: String) -> String {
        let limit = max(0, maxRuntimeProblemCharacters)
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = VoiceCapturePresentationBounds.normalizedDisplayText(clipped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "runtime assets are invalid" : trimmed
    }
}
