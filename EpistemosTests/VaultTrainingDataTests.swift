import Testing
import Foundation
@testable import Epistemos

/// DATA + FINETUNE part (2) — locks the native vault data-gen core: typed
/// training examples with auditable PROVENANCE, a STABLE content hash, DEDUP, and
/// inspectable counts, emitting the {"messages":[…]} chat JSONL the native trainer
/// consumes (round-trips into LoRAChatDataConverter). No Python.
@Suite("Vault training data")
struct VaultTrainingDataTests {

    private func ex(_ q: String, _ a: String, src: String = "n1") -> TrainingExample {
        TrainingExample(
            messages: [.init(role: "user", content: q), .init(role: "assistant", content: a)],
            provenance: .init(sourceKind: .note, sourceID: src)
        )
    }

    @Test("content hash is deterministic, content-sensitive, provenance-independent")
    func contentHash() {
        let a = ex("Q", "A", src: "note-1")
        let b = ex("Q", "A", src: "note-2")   // same content, different source
        let c = ex("Q", "B", src: "note-1")   // different content
        #expect(a.contentHash == b.contentHash)   // provenance-independent
        #expect(a.contentHash != c.contentHash)   // content-sensitive
        #expect(a.contentHash == TrainingExample.hash(of: a.messages))  // stable/recomputable
        #expect(a.contentHash.count == 64)         // SHA-256 hex
    }

    @Test("qaExample builds system-anchored Q&A and skips blanks")
    func qaBuilder() {
        let prov = TrainingProvenance(sourceKind: .symbol, sourceID: "foo()")
        let full = VaultTrainingDataGenerator.qaExample(system: "You are X.", question: "What?", answer: "Y.", provenance: prov)
        #expect(full?.messages.map(\.role) == ["system", "user", "assistant"])
        // No system → just user+assistant.
        let noSys = VaultTrainingDataGenerator.qaExample(system: "  ", question: "Q", answer: "A", provenance: prov)
        #expect(noSys?.messages.map(\.role) == ["user", "assistant"])
        // Blank question or answer → nil.
        #expect(VaultTrainingDataGenerator.qaExample(system: "S", question: "  ", answer: "A", provenance: prov) == nil)
        #expect(VaultTrainingDataGenerator.qaExample(system: "S", question: "Q", answer: " ", provenance: prov) == nil)
    }

    @Test("set dedups by content hash and reports honest counts")
    func dedupAndCounts() {
        var set = TrainingExampleSet()
        let added1 = set.add(ex("Q1", "A1", src: "a"))        // new
        let addedDup = set.add(ex("Q1", "A1", src: "b"))      // content-dup (diff source) → dropped
        let added2 = set.add(ex("Q2", "A2", src: "a"))        // new
        #expect(added1)
        #expect(!addedDup)
        #expect(added2)
        #expect(set.uniqueCount == 2)
        #expect(set.duplicatesDropped == 1)
        #expect(set.totalSeen == 3)
    }

    @Test("per-source breakdown is inspectable")
    func perSourceCounts() {
        var set = TrainingExampleSet()
        set.add(TrainingExample(messages: [.init(role: "user", content: "a"), .init(role: "assistant", content: "1")],
                                provenance: .init(sourceKind: .note, sourceID: "n")))
        set.add(TrainingExample(messages: [.init(role: "user", content: "b"), .init(role: "assistant", content: "2")],
                                provenance: .init(sourceKind: .symbol, sourceID: "s")))
        set.add(TrainingExample(messages: [.init(role: "user", content: "c"), .init(role: "assistant", content: "3")],
                                provenance: .init(sourceKind: .note, sourceID: "n2")))
        let counts = set.countsBySource()
        #expect(counts[.note] == 2)
        #expect(counts[.symbol] == 1)
    }

    @Test("chat JSONL output round-trips through LoRAChatDataConverter (native pipeline)")
    func nativePipelineRoundTrip() {
        var set = TrainingExampleSet()
        set.add(ex("How does X work?", "It does Y.", src: "n"))
        set.add(ex("And Z?", "Z is W.", src: "n2"))
        let jsonl = set.toChatJSONL()
        #expect(jsonl.contains("\"messages\""))
        // The native trainer's converter parses the same JSONL into training texts.
        let texts = LoRAChatDataConverter.texts(fromChatJSONL: jsonl)
        #expect(texts.count == 2)
        #expect(texts[0].contains("How does X work?") && texts[0].contains("It does Y."))
    }
}
