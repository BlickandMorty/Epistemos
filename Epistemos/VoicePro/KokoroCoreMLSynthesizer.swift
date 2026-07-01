import Foundation

#if canImport(KokoroPipeline)
import KokoroPipeline
#endif

nonisolated enum KokoroCoreMLSynthesizer {
    static let maxInputCharacters = 12_000

    struct RenderedAudio: Equatable, Sendable {
        let samples: [Float]
        let sampleRateHz: Int
        let synthesizedChunkCount: Int
    }

    private struct TokenizedChunk: Equatable, Sendable {
        let inputIDs: [Int32]
        let attentionMask: [Int32]
    }

    enum SynthesisError: Equatable, Error, LocalizedError, Sendable {
        case runtimeNotLinked
        case inputTooLong(Int)
        case unsupportedInput
        case synthesisFailed(String)

        var errorDescription: String? {
            switch self {
            case .runtimeNotLinked:
                return "KokoroPipeline is not linked in this build."
            case .inputTooLong(let count):
                return "Kokoro text-to-speech input is too long: \(count) characters."
            case .unsupportedInput:
                return "Kokoro text-to-speech input did not contain vocabulary-supported characters."
            case .synthesisFailed(let detail):
                return "Kokoro text-to-speech synthesis failed: \(detail)"
            }
        }
    }

    static func renderRawText(
        _ text: String,
        speed: Float = 1.0,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) throws -> RenderedAudio {
        #if canImport(KokoroPipeline)
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw SynthesisError.unsupportedInput
        }
        guard cleaned.count <= maxInputCharacters else {
            throw SynthesisError.inputTooLong(cleaned.count)
        }

        let resources = try KokoroCoreMLRuntimeLoader.resources(
            environment: environment,
            modelRoot: modelRoot,
            fileManager: fileManager
        )
        let pipeline = try KokoroCoreMLRuntimeLoader.loadPipeline(resources: resources)
        let chunks = try rawVocabularyChunks(
            for: cleaned,
            vocabulary: resources.vocabulary,
            maxTokenCount: resources.durationTokenSizes.max() ?? 512
        )
        let clampedSpeed = Self.clampedSpeed(speed)

        let segments = try chunks.map { chunk in
            do {
                return try pipeline.synthesize(
                    inputIds: chunk.inputIDs,
                    attentionMask: chunk.attentionMask,
                    refS: resources.starterVoiceEmbedding,
                    speed: clampedSpeed
                ).audio
            } catch {
                throw SynthesisError.synthesisFailed(runtimeDiagnostic(error))
            }
        }

        let samples = PcmJoiner.join(
            segments: segments,
            sampleRate: resources.sampleRateHz,
            crossfadeMs: PcmJoiner.defaultCrossfadeMs
        )
        guard !samples.isEmpty else {
            throw SynthesisError.synthesisFailed("empty audio")
        }
        return RenderedAudio(
            samples: samples,
            sampleRateHz: resources.sampleRateHz,
            synthesizedChunkCount: chunks.count
        )
        #else
        throw SynthesisError.runtimeNotLinked
        #endif
    }

    private static func rawVocabularyChunks(
        for text: String,
        vocabulary: [String: Int32],
        maxTokenCount: Int
    ) throws -> [TokenizedChunk] {
        let symbols = rawVocabularySymbols(for: text, vocabulary: vocabulary)
        guard !symbols.isEmpty else {
            throw SynthesisError.unsupportedInput
        }

        let payloadLimit = max(1, maxTokenCount - 2)
        var chunks = [[String]]()
        var current = [String]()
        current.reserveCapacity(payloadLimit)

        for symbol in symbols {
            if current.count >= payloadLimit {
                appendTrimmedChunk(current, to: &chunks)
                current.removeAll(keepingCapacity: true)
            }
            if current.isEmpty, symbol == " " {
                continue
            }
            current.append(symbol)
        }
        appendTrimmedChunk(current, to: &chunks)

        let tokenized = chunks.compactMap { chunk -> TokenizedChunk? in
            let tokenIDs = chunk.compactMap { vocabulary[$0] }
            guard !tokenIDs.isEmpty else { return nil }
            let inputIDs = [Int32(0)] + tokenIDs + [Int32(0)]
            return TokenizedChunk(
                inputIDs: inputIDs,
                attentionMask: Array(repeating: Int32(1), count: inputIDs.count)
            )
        }
        guard !tokenized.isEmpty else {
            throw SynthesisError.unsupportedInput
        }
        return tokenized
    }

    private static func rawVocabularySymbols(
        for text: String,
        vocabulary: [String: Int32]
    ) -> [String] {
        var symbols = [String]()
        var previousWasSpace = true

        func append(_ rawSymbol: String) {
            guard let symbol = vocabularySymbol(rawSymbol, vocabulary: vocabulary) else { return }
            if symbol == " " {
                guard !previousWasSpace else { return }
                previousWasSpace = true
            } else {
                previousWasSpace = false
            }
            symbols.append(symbol)
        }

        for character in text {
            for symbol in replacementSymbols(for: character) {
                append(symbol)
            }
        }

        while symbols.last == " " {
            symbols.removeLast()
        }
        return symbols
    }

    private static func replacementSymbols(for character: Character) -> [String] {
        switch character {
        case "\n", "\r", "\t":
            return [" "]
        case "-":
            return ["\u{2014}"]
        case "0":
            return Array(" zero ").map(String.init)
        case "1":
            return Array(" one ").map(String.init)
        case "2":
            return Array(" two ").map(String.init)
        case "3":
            return Array(" three ").map(String.init)
        case "4":
            return Array(" four ").map(String.init)
        case "5":
            return Array(" five ").map(String.init)
        case "6":
            return Array(" six ").map(String.init)
        case "7":
            return Array(" seven ").map(String.init)
        case "8":
            return Array(" eight ").map(String.init)
        case "9":
            return Array(" nine ").map(String.init)
        case "'", "\u{2019}", "`":
            return []
        default:
            return [String(character)]
        }
    }

    private static func vocabularySymbol(
        _ symbol: String,
        vocabulary: [String: Int32]
    ) -> String? {
        if vocabulary[symbol] != nil {
            return symbol
        }
        let folded = symbol
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        if vocabulary[folded] != nil {
            return folded
        }
        return nil
    }

    private static func appendTrimmedChunk(_ chunk: [String], to chunks: inout [[String]]) {
        var trimmed = chunk
        while trimmed.first == " " {
            trimmed.removeFirst()
        }
        while trimmed.last == " " {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else { return }
        chunks.append(trimmed)
    }

    private static func clampedSpeed(_ speed: Float) -> Float {
        guard speed.isFinite else { return 1.0 }
        return min(1.6, max(0.6, speed))
    }

    private static func runtimeDiagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(VoiceCaptureDiagnostics.safeDomain(nsError.domain)) code=\(nsError.code)"
    }
}
