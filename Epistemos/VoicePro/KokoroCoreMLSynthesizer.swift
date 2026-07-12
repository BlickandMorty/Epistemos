import Foundation

#if canImport(KokoroPipeline)
import KokoroPipeline
#endif

nonisolated enum KokoroCoreMLSynthesizer {
    static let maxInputCharacters = 12_000
    private static let responsiveDurationTokenCeiling = 32
    private static let synthesisExecutionLock = NSLock()

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
        voiceIdentifier: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) throws -> RenderedAudio {
        #if canImport(KokoroPipeline)
        try Task.checkCancellation()
        synthesisExecutionLock.lock()
        defer { synthesisExecutionLock.unlock() }
        try Task.checkCancellation()
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
        try Task.checkCancellation()
        // Voice SELECTION: use the chosen installed voice if it loads + validates, else fall
        // back to the starter voice — a bad/unknown selection must never break synthesis.
        let voiceEmbedding: [Float]
        if let voiceIdentifier,
           isEnglishKokoroVoiceIdentifier(voiceIdentifier),
           let selected = KokoroCoreMLRuntimeLoader.voiceEmbedding(
               named: voiceIdentifier,
               in: resources.modelDirectoryURL
           ) {
            voiceEmbedding = selected
        } else {
            voiceEmbedding = resources.starterVoiceEmbedding
        }
        let pipeline = try KokoroCoreMLRuntimeLoader.loadPipeline(resources: resources)
        let chunks = try rawVocabularyChunks(
            for: cleaned,
            vocabulary: resources.vocabulary,
            maxTokenCount: responsiveDurationTokenLimit(from: resources.durationTokenSizes)
        )
        let clampedSpeed = Self.clampedSpeed(speed)

        var segments: [[Float]] = []
        segments.reserveCapacity(chunks.count)
        for chunk in chunks {
            try Task.checkCancellation()
            // Kokoro selects the reference style vector by phoneme-sequence
            // length. chunk.inputIDs is [0] + phonemeIDs + [0], so the phoneme
            // count is inputIDs.count - 2.
            let refS = Self.referenceStyleVector(
                from: voiceEmbedding,
                phonemeCount: chunk.inputIDs.count - 2
            )
            let audio: [Float]
            do {
                audio = try pipeline.synthesize(
                    inputIds: chunk.inputIDs,
                    attentionMask: chunk.attentionMask,
                    refS: refS,
                    speed: clampedSpeed
                ).audio
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw SynthesisError.synthesisFailed(runtimeDiagnostic(error))
            }
            try Task.checkCancellation()
            segments.append(audio)
        }

        let samples = PcmJoiner.join(
            segments: segments,
            sampleRate: resources.sampleRateHz,
            crossfadeMs: PcmJoiner.defaultCrossfadeMs
        )
        try Task.checkCancellation()
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
        let symbols = englishPhonemeSymbols(for: text, vocabulary: vocabulary)
        let resolvedSymbols = symbols.isEmpty
            ? rawVocabularySymbols(for: text, vocabulary: vocabulary)
            : symbols
        guard !resolvedSymbols.isEmpty else {
            throw SynthesisError.unsupportedInput
        }

        let payloadLimit = max(1, maxTokenCount - 2)
        var chunks = [[String]]()
        var current = [String]()
        current.reserveCapacity(payloadLimit)

        for symbol in resolvedSymbols {
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

    private static func responsiveDurationTokenLimit(from durationTokenSizes: [Int]) -> Int {
        let sorted = durationTokenSizes.filter { $0 > 2 }.sorted()
        if let responsive = sorted.last(where: { $0 <= responsiveDurationTokenCeiling }) {
            return responsive
        }
        return sorted.first ?? responsiveDurationTokenCeiling
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

    private nonisolated static func isEnglishKokoroVoiceIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("af_")
            || identifier.hasPrefix("am_")
            || identifier.hasPrefix("bf_")
            || identifier.hasPrefix("bm_")
    }

    nonisolated static func englishPhonemeSymbols(
        for text: String,
        vocabulary: [String: Int32]
    ) -> [String] {
        var symbols = [String]()
        var currentWord = ""
        var previousWasSpace = true

        func appendSymbol(_ rawSymbol: String) {
            guard let symbol = vocabularySymbol(rawSymbol, vocabulary: vocabulary) else { return }
            if symbol == " " {
                guard !previousWasSpace else { return }
                previousWasSpace = true
            } else {
                previousWasSpace = false
            }
            symbols.append(symbol)
        }

        func appendPhonemeString(_ phonemes: String) {
            for character in phonemes {
                appendSymbol(String(character))
            }
        }

        func flushWord() {
            guard !currentWord.isEmpty else { return }
            let phonemes = englishPhonemes(forWord: currentWord)
            appendPhonemeString(phonemes)
            currentWord.removeAll(keepingCapacity: true)
        }

        for character in text {
            if character.isLetter {
                currentWord.append(contentsOf: String(character).lowercased())
            } else if character.isNumber {
                flushWord()
                appendPhonemeString(englishPhonemes(forWord: String(character)))
                appendSymbol(" ")
            } else {
                flushWord()
                switch character {
                case "'", "\u{2019}", "`":
                    continue
                case ".", ",", "!", "?", ":", ";", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}":
                    let normalized = character == "\u{2010}"
                        || character == "\u{2011}"
                        || character == "\u{2012}"
                        || character == "\u{2013}"
                        ? "—"
                        : String(character)
                    appendSymbol(normalized)
                    appendSymbol(" ")
                case "\n", "\r", "\t", " ", "\u{00a0}":
                    appendSymbol(" ")
                case "&":
                    appendPhonemeString(englishPhonemes(forWord: "and"))
                    appendSymbol(" ")
                case "%":
                    appendPhonemeString(englishPhonemes(forWord: "percent"))
                    appendSymbol(" ")
                case "+":
                    appendPhonemeString(englishPhonemes(forWord: "plus"))
                    appendSymbol(" ")
                case "/":
                    appendPhonemeString(englishPhonemes(forWord: "slash"))
                    appendSymbol(" ")
                default:
                    appendSymbol(" ")
                }
            }
        }
        flushWord()
        while symbols.last == " " {
            symbols.removeLast()
        }
        return symbols
    }

    private nonisolated static func englishPhonemes(forWord word: String) -> String {
        if let phonemes = englishPronunciationLexicon[word] {
            return phonemes
        }
        return approximateEnglishPhonemes(forWord: word)
    }

    private nonisolated static let englishPronunciationLexicon: [String: String] = [
        "0": "zˈiɹO",
        "1": "wˈʌn",
        "2": "tˈu",
        "3": "θɹˈi",
        "4": "fˈOɹ",
        "5": "fˈaIv",
        "6": "sˈɪks",
        "7": "sˈɛvən",
        "8": "ˈeIt",
        "9": "nˈaIn",
        "a": "ə",
        "about": "əbˈaUt",
        "agent": "ˈeIʤənt",
        "all": "ˈOl",
        "an": "ən",
        "and": "ænd",
        "app": "ˈæp",
        "are": "ˈɑɹ",
        "as": "æz",
        "assistant": "əsˈɪstənt",
        "at": "æt",
        "back": "bˈæk",
        "be": "bˈi",
        "body": "bˈɑdi",
        "capture": "kˈæpʧɚ",
        "chat": "ʧˈæt",
        "code": "kˈOd",
        "document": "dˈɑkjəmənt",
        "editor": "ˈɛdɪtɚ",
        "english": "ˈɪŋɡlɪʃ",
        "epdoc": "ˈɛpdɑk",
        "epistemos": "ɛpˈɪstɛmOs",
        "for": "fɚ",
        "from": "fɹʌm",
        "graph": "ɡɹˈæf",
        "hello": "hɛlˈO",
        "home": "hˈOm",
        "i": "ˈaI",
        "in": "ɪn",
        "is": "ɪz",
        "it": "ɪt",
        "june": "ʤˈun",
        "kokoro": "kˈOkəɹO",
        "latest": "lˈeItəst",
        "note": "nˈOt",
        "notes": "nˈOts",
        "of": "əv",
        "on": "ɑn",
        "open": "ˈOpən",
        "preview": "pɹˈivju",
        "prose": "pɹˈOz",
        "quick": "kwˈɪk",
        "read": "ɹˈid",
        "ready": "ɹˈɛdi",
        "reply": "ɹɪplˈaI",
        "researcher": "ɹˈisɚʧɚ",
        "screen": "skɹˈin",
        "selected": "səlˈɛktəd",
        "settings": "sˈɛtɪŋz",
        "surface": "sˈɚfəs",
        "text": "tˈɛkst",
        "the": "ðə",
        "this": "ðˈɪs",
        "to": "tə",
        "vault": "vˈOlt",
        "visible": "vˈɪzəbəl",
        "voice": "vˈOIs",
        "welcome": "wˈɛlkəm",
        "with": "wɪð",
        "workspace": "wˈɚkspˌes",
        "you": "jˈu"
    ]

    private nonisolated static func approximateEnglishPhonemes(forWord word: String) -> String {
        var output = ""
        let characters = Array(word)
        var index = 0
        while index < characters.count {
            let current = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let afterNext = index + 2 < characters.count ? characters[index + 2] : nil
            let pair = next.map { "\(current)\($0)" } ?? String(current)

            switch pair {
            case "th":
                output += ["the", "this", "that", "there", "they", "them", "then", "with"].contains(word) ? "ð" : "θ"
                index += 2
            case "sh":
                output += "ʃ"
                index += 2
            case "ch":
                output += "ʧ"
                index += 2
            case "ph":
                output += "f"
                index += 2
            case "ng":
                output += "ŋ"
                index += 2
            case "qu":
                output += "kw"
                index += 2
            case "ck":
                output += "k"
                index += 2
            case "ee", "ea":
                output += "i"
                index += 2
            case "oo":
                output += "u"
                index += 2
            case "ou", "ow":
                output += "aU"
                index += 2
            case "ai", "ay":
                output += "eI"
                index += 2
            case "oi", "oy":
                output += "OI"
                index += 2
            case "er", "ir", "ur":
                output += "ɚ"
                index += 2
            default:
                switch current {
                case "a":
                    output += next == "r" ? "ɑ" : "æ"
                case "b":
                    output += "b"
                case "c":
                    output += next == "e" || next == "i" || next == "y" ? "s" : "k"
                case "d":
                    output += "d"
                case "e":
                    output += index == characters.count - 1 ? "" : "ɛ"
                case "f":
                    output += "f"
                case "g":
                    output += next == "e" || next == "i" || next == "y" ? "ʤ" : "ɡ"
                case "h":
                    output += "h"
                case "i":
                    output += afterNext == "e" ? "aI" : "ɪ"
                case "j":
                    output += "ʤ"
                case "k":
                    output += "k"
                case "l":
                    output += "l"
                case "m":
                    output += "m"
                case "n":
                    output += "n"
                case "o":
                    output += next == "r" ? "O" : "ɑ"
                case "p":
                    output += "p"
                case "q":
                    output += "k"
                case "r":
                    output += "ɹ"
                case "s":
                    output += "s"
                case "t":
                    output += "t"
                case "u":
                    output += "ʌ"
                case "v":
                    output += "v"
                case "w":
                    output += "w"
                case "x":
                    output += "ks"
                case "y":
                    output += index == characters.count - 1 ? "i" : "j"
                case "z":
                    output += "z"
                default:
                    break
                }
                index += 1
            }
        }
        return output.isEmpty ? word : output
    }

    private static func replacementSymbols(for character: Character) -> [String] {
        switch character {
        case "\n", "\r", "\t":
            return [" "]
        case "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2212}":
            return ["\u{2014}"]
        case "&":
            return Array(" and ").map(String.init)
        case "%":
            return Array(" percent ").map(String.init)
        case "+":
            return Array(" plus ").map(String.init)
        case "/":
            return Array(" slash ").map(String.init)
        case "@":
            return Array(" at ").map(String.init)
        case "#":
            return Array(" number ").map(String.init)
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

    /// Select the 256-float reference style vector for a chunk from the full
    /// Kokoro voice tensor (shape [rows, 256]). Standard Kokoro indexes the
    /// style row by phoneme-sequence length; the row is clamped into range so a
    /// single-row (legacy 256-float) embedding also works unchanged.
    static func referenceStyleVector(from voiceEmbedding: [Float], phonemeCount: Int) -> [Float] {
        let dimensions = KokoroVoiceGateStatus.starterVoiceEmbeddingDimensions
        guard dimensions > 0, voiceEmbedding.count >= dimensions else {
            return voiceEmbedding
        }
        let rowCount = voiceEmbedding.count / dimensions
        let row = min(max(phonemeCount, 0), rowCount - 1)
        let start = row * dimensions
        return Array(voiceEmbedding[start ..< start + dimensions])
    }

    private static func runtimeDiagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(VoiceCaptureDiagnostics.safeDomain(nsError.domain)) code=\(nsError.code)"
    }
}
