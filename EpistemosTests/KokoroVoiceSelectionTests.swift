import Foundation
import Testing

@testable import Epistemos

// Proves the VERIFIABLE half of Kokoro voice selection (commits 2591f2211 + e7c7ee12b):
// voice enumeration, display-name/language derivation, and safe-name / path-traversal
// rejection. Actual audio for a selected voice needs the installed Kokoro model (owner-verify)
// and is out of scope here — this locks the logic that decides WHICH voice is loaded.
@Suite("Kokoro voice selection")
struct KokoroVoiceSelectionTests {

    /// A temp model root with fake voices/*.bin files. installedKokoroVoices lists + parses
    /// names; it does not read bytes, so empty files are fine for enumeration.
    private func makeModelRoot(voiceFiles: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-voice-test-\(UUID().uuidString)", isDirectory: true)
        let voicesDir = root
            .appendingPathComponent("kokoro-82m-coreml", isDirectory: true)
            .appendingPathComponent("voices", isDirectory: true)
        try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)
        for file in voiceFiles {
            try Data([0, 0, 0, 0]).write(to: voicesDir.appendingPathComponent(file))
        }
        return root
    }

    @Test("enumerates installed voices with derived display names + languages")
    func enumeratesVoices() throws {
        let root = try makeModelRoot(voiceFiles: ["af_heart.bin", "am_adam.bin", "bf_alice.bin"])
        defer { try? FileManager.default.removeItem(at: root) }

        let voices = EpistemosSpeechSynthesizer.installedKokoroVoices(modelRoot: root)
        #expect(voices.count == 3)

        let byId = Dictionary(uniqueKeysWithValues: voices.map { ($0.identifier, $0) })
        #expect(byId["af_heart"]?.displayName == "Heart")
        #expect(byId["af_heart"]?.language == "American English · Female")
        #expect(byId["am_adam"]?.language == "American English · Male")
        #expect(byId["bf_alice"]?.displayName == "Alice")
        #expect(byId["bf_alice"]?.language == "British English · Female")

        let englishIDs = Set(EpistemosSpeechSynthesizer.installedEnglishKokoroVoices(modelRoot: root).map(\.identifier))
        #expect(englishIDs == ["af_heart", "am_adam", "bf_alice"])
    }

    @Test("default Kokoro voice stays on an installed English voice")
    func defaultKokoroVoiceStaysEnglish() throws {
        let voices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "Spanish · Female",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "am_michael",
                displayName: "Michael",
                language: "American English · Male",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "af_heart",
                displayName: "Heart",
                language: "American English · Female",
                quality: .premium
            )
        ]

        #expect(
            EpistemosSpeechSynthesizer.preferredEnglishKokoroVoiceIdentifier(from: voices)
                == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "ef_dora",
                globalDefault: "com.apple.speech.synthesis.voice.not-kokoro",
                installedVoices: voices
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: nil,
                globalDefault: nil,
                installedVoices: []
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
    }

    @Test("English-only Kokoro catalogue filters non-English installed voices")
    func englishOnlyCatalogueFiltersNonEnglishVoices() throws {
        let root = try makeModelRoot(voiceFiles: ["af_heart.bin", "ef_dora.bin", "jf_alpha.bin", "bm_george.bin"])
        defer { try? FileManager.default.removeItem(at: root) }

        let allIDs = Set(EpistemosSpeechSynthesizer.installedKokoroVoices(modelRoot: root).map(\.identifier))
        #expect(allIDs == ["af_heart", "bm_george", "ef_dora", "jf_alpha"])

        let englishIDs = Set(EpistemosSpeechSynthesizer.installedEnglishKokoroVoices(modelRoot: root).map(\.identifier))
        #expect(englishIDs == ["af_heart", "bm_george"])
    }

    @Test("normalizes stale picker selections to installed English Kokoro voices")
    func normalizesStalePickerSelectionsToEnglishKokoroVoices() {
        let voices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "af_heart",
                displayName: "Heart",
                language: "American English · Female",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "am_michael",
                displayName: "Michael",
                language: "American English · Male",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "Spanish · Female",
                quality: .premium
            )
        ]

        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "am_michael",
                installedVoices: voices
            ) == "am_michael"
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "ef_dora",
                installedVoices: voices
            ) == nil
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "com.apple.speech.synthesis.voice.samantha",
                installedVoices: voices
            ) == nil
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                nil,
                installedVoices: voices
            ) == nil
        )
    }

    @Test("MAS read-aloud effect policy forces clean shipped output")
    func masReadAloudEffectPolicyForcesCleanShippedOutput() {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(!VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .clean)
        #else
        #expect(VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .pixelArt)
        #endif
    }

    @Test("Kokoro preview text is phonemized instead of sent as raw English letters")
    func previewTextUsesEnglishPhonemes() {
        let symbols = ["k", "ˈ", "O", "ə", "ɹ", "ɪ", "z", " ", "ɛ", "d", "i", "."]
        let vocabulary = Dictionary(uniqueKeysWithValues: symbols.enumerated().map { ($0.element, Int32($0.offset + 1)) })

        let phonemes = KokoroCoreMLSynthesizer.englishPhonemeSymbols(
            for: "Kokoro is ready.",
            vocabulary: vocabulary
        )

        #expect(phonemes.contains("ə"))
        #expect(phonemes.contains("ɹ"))
        #expect(phonemes.contains("ɛ"))
        #expect(!phonemes.starts(with: ["k", "o", "k", "o", "r", "o"]))
    }

    @Test("excludes non-.bin files and unsafe voice names")
    func excludesUnsafe() throws {
        let root = try makeModelRoot(voiceFiles: ["af_heart.bin", "bad-name.bin", "notavoice.txt"])
        defer { try? FileManager.default.removeItem(at: root) }

        let ids = Set(EpistemosSpeechSynthesizer.installedKokoroVoices(modelRoot: root).map(\.identifier))
        #expect(ids.contains("af_heart"))
        #expect(!ids.contains("bad-name"))   // hyphen → unsafe name, excluded
        #expect(!ids.contains("notavoice"))  // .txt → not a voice pack
    }

    @Test("missing voices directory yields no voices (no crash)")
    func missingDirectory() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-missing-\(UUID().uuidString)", isDirectory: true)
        #expect(EpistemosSpeechSynthesizer.installedKokoroVoices(modelRoot: root).isEmpty)
    }

    @Test("voiceEmbedding rejects unsafe / path-traversal voice names")
    func voiceEmbeddingRejectsUnsafe() throws {
        let root = try makeModelRoot(voiceFiles: ["af_heart.bin"])
        defer { try? FileManager.default.removeItem(at: root) }
        let modelDir = root.appendingPathComponent("kokoro-82m-coreml", isDirectory: true)

        // Traversal / separators / empty must return nil BEFORE touching disk.
        #expect(KokoroCoreMLRuntimeLoader.voiceEmbedding(named: "../secret", in: modelDir) == nil)
        #expect(KokoroCoreMLRuntimeLoader.voiceEmbedding(named: "a/b", in: modelDir) == nil)
        #expect(KokoroCoreMLRuntimeLoader.voiceEmbedding(named: "", in: modelDir) == nil)
    }
}

@Suite("Speech text prep")
struct SpeechTextPrepTests {
    @Test("strips markdown so read-aloud speaks content, not syntax")
    func stripsMarkdown() {
        let md = """
        # Section
        Some **bold** and *italic* and `code` and a [link](https://x.com).
        - item one
        > quote
        """
        let out = EpistemosSpeechSynthesizer.plainTextForSpeech(fromMarkdown: md)
        #expect(!out.contains("#"))
        #expect(!out.contains("**"))
        #expect(!out.contains("`"))
        #expect(!out.contains("https://x.com"))
        for kept in ["Section", "bold", "italic", "code", "link", "item one", "quote"] {
            #expect(out.contains(kept))
        }
    }

    @Test("leaves non-markdown prose (arithmetic, snake_case) intact")
    func leavesProseIntact() {
        let out = EpistemosSpeechSynthesizer.plainTextForSpeech(
            fromMarkdown: "compute 5 * 3 then read snake_case_name"
        )
        #expect(out.contains("5 * 3"))
        #expect(out.contains("snake_case_name"))
    }
}
