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
