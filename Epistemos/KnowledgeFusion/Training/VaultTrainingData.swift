import Foundation
import CryptoKit

// DATA + FINETUNE part (2) DATA-STRUCTURING (owner 2026-06-18: "I feel like my
// app does not do a good job structuring the data … real schemas, provenance,
// dedup, inspectable"). The NATIVE replacement for the MOHAWK generate_*.py
// data-gen: typed training examples with PROVENANCE + a stable content-hash for
// DEDUP, emitted as the {"messages":[…]} chat JSONL the native trainer consumes
// (via LoRAChatDataConverter → NativeLoRATrainer). Pure, always-compiled,
// unit-tested. No Python. Vault→train-data→LoRA becomes fully native end-to-end.

/// Where a training example came from — auditable provenance per example.
struct TrainingProvenance: Codable, Sendable, Equatable {
    enum SourceKind: String, Codable, Sendable, CaseIterable {
        case note      // a vault note
        case symbol    // a code symbol
        case concept   // a distilled concept
        case chat      // a past chat turn
        case manual    // hand-authored
    }
    let sourceKind: SourceKind
    let sourceID: String   // note path / symbol name / concept id / chat id
    var offset: Int?       // char/line offset within the source, if applicable

    init(sourceKind: SourceKind, sourceID: String, offset: Int? = nil) {
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.offset = offset
    }
}

/// One native training example in the chat format the trainer consumes (matches
/// ReplayJSONL / what LoRAChatDataConverter parses). Carries provenance + a
/// STABLE content hash (CryptoKit SHA-256, deterministic across runs) for dedup.
struct TrainingExample: Codable, Sendable, Identifiable, Equatable {
    struct Message: Codable, Sendable, Equatable {
        let role: String     // "system" | "user" | "assistant"
        let content: String
    }
    let messages: [Message]
    let provenance: TrainingProvenance
    /// Stable hash over the messages only (provenance-independent) → two examples
    /// with identical content but different sources dedup to one.
    let contentHash: String
    var id: String { contentHash }

    init(messages: [Message], provenance: TrainingProvenance) {
        self.messages = messages
        self.provenance = provenance
        self.contentHash = TrainingExample.hash(of: messages)
    }

    /// Deterministic content hash — NOT Swift's per-run-randomized Hasher.
    static func hash(of messages: [Message]) -> String {
        let canonical = messages
            .map { "\($0.role)\u{1}\($0.content)" }
            .joined(separator: "\u{2}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// A deduplicated, INSPECTABLE set of training examples — dedup by contentHash
/// (first provenance wins), with honest counts (unique / dropped / per-source).
struct TrainingExampleSet: Sendable, Equatable {
    private(set) var examples: [TrainingExample] = []
    private(set) var duplicatesDropped = 0
    private var seen: Set<String> = []

    /// Add an example; a content-duplicate is dropped (and counted), not stored.
    @discardableResult
    mutating func add(_ example: TrainingExample) -> Bool {
        guard !seen.contains(example.contentHash) else {
            duplicatesDropped += 1
            return false
        }
        seen.insert(example.contentHash)
        examples.append(example)
        return true
    }

    var uniqueCount: Int { examples.count }
    var totalSeen: Int { examples.count + duplicatesDropped }

    /// Per-source-kind breakdown — the inspectable "where did the data come from".
    func countsBySource() -> [TrainingProvenance.SourceKind: Int] {
        var counts: [TrainingProvenance.SourceKind: Int] = [:]
        for example in examples { counts[example.provenance.sourceKind, default: 0] += 1 }
        return counts
    }

    /// Emit the {"messages":[…]} chat JSONL the native trainer reads (the format
    /// LoRAChatDataConverter consumes). Provenance + hash stay in-memory (the
    /// trainer only needs the messages).
    func toChatJSONL() -> String {
        struct Line: Encodable { let messages: [TrainingExample.Message] }
        let encoder = JSONEncoder()
        return examples.compactMap { example -> String? in
            guard let data = try? encoder.encode(Line(messages: example.messages)) else { return nil }
            return String(data: data, encoding: .utf8)
        }.joined(separator: "\n")
    }
}

/// Native vault → training-example builder. The typed core; the vault-iteration
/// (read notes/symbols → Q&A) wiring is a follow-on that calls these.
enum VaultTrainingDataGenerator {
    /// A system-anchored Q&A example (system → user question → assistant answer),
    /// tagged with provenance. Blank turns are skipped (returns nil) so the set
    /// never carries empty examples.
    static func qaExample(
        system: String,
        question: String,
        answer: String,
        provenance: TrainingProvenance
    ) -> TrainingExample? {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { return nil }
        var messages: [TrainingExample.Message] = []
        let sys = system.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty { messages.append(.init(role: "system", content: sys)) }
        messages.append(.init(role: "user", content: q))
        messages.append(.init(role: "assistant", content: a))
        return TrainingExample(messages: messages, provenance: provenance)
    }
}
