import Foundation

// SS-LS 1b (native KTO port, brick 2): the KTO training DATA prep — parse the
// feedback JSONL into typed examples the native KTO loop will consume in place of
// the train_kto.py subprocess. KTO trains from BINARY desirable/undesirable signals
// (FeedbackLogger logs accept/copy/thumbs-up as desirable, delete/discard/heavy-edit
// as undesirable). This brick is pure + unit-witnessed; it does NOT touch KTOTrainer's
// Python path — that spawn is removed only once the full native loop (this data →
// policy/reference log-ratios → NativeKTOLoss → grad step → adapter) is built and the
// owner can witness convergence.

/// One KTO training example: a binary-labeled (prompt, completion) pair.
nonisolated struct KTOExample: Sendable, Equatable {
    let prompt: String
    let completion: String
    /// true = desirable (reinforce), false = undesirable (discourage).
    let desirable: Bool
}

nonisolated enum NativeKTODataPrep {
    /// One JSONL row, the exact shape FeedbackLogger.exportToJSONL writes and
    /// train_kto.py reads: {"prompt": String, "completion": String, "label": Bool}.
    private struct Row: Decodable {
        let prompt: String
        let completion: String
        let label: Bool
    }

    /// Parse KTO feedback JSONL (one object per line) into typed examples. Malformed,
    /// empty, or field-missing lines are SKIPPED (robust — one bad row never fails the
    /// batch), matching the loader's tolerance. Order is preserved.
    static func parseFeedbackJSONL(_ text: String) -> [KTOExample] {
        let decoder = JSONDecoder()
        return text.split(whereSeparator: \.isNewline).compactMap { line -> KTOExample? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard
                !trimmed.isEmpty,
                let data = trimmed.data(using: .utf8),
                let row = try? decoder.decode(Row.self, from: data)
            else {
                return nil
            }
            return KTOExample(prompt: row.prompt, completion: row.completion, desirable: row.label)
        }
    }

    /// Parse the KTO feedback JSONL at `url`. Returns [] if the file is unreadable.
    static func loadFeedbackExamples(at url: URL) -> [KTOExample] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseFeedbackJSONL(text)
    }

    /// Split the examples by label — the native KTO loop weights desirable vs
    /// undesirable separately (λ_D / λ_U) and the KL baseline is over the whole batch.
    static func partition(_ examples: [KTOExample]) -> (desirable: [KTOExample], undesirable: [KTOExample]) {
        (examples.filter(\.desirable), examples.filter { !$0.desirable })
    }
}
