import Foundation

// SS-LS 1b (native KTO port, brick 4): the sequence-scoring helpers the native KTO
// loop uses — pure, unit-witnessed. The KTO log-ratio is
//   logπ_θ(completion|prompt) − logπ_ref(completion|prompt),
// where each sequence log-prob = Σ of the per-token log-probs over the COMPLETION
// positions (the prompt tokens are masked out — KTO scores the model's completion,
// not the prompt). The MLX forward pass that produces the per-token log-probs lives
// in the trainer (brick 5: logits → crossEntropy → −per-token CE = log-prob); this is
// the pure mask/sum + log-ratio + mask-construction core. KTOTrainer's Python path is
// untouched by this brick.
nonisolated enum NativeKTOSequenceScore {
    /// logπ(completion|prompt) = Σ over the completion-masked positions of the
    /// per-token log-prob. Prompt positions (mask=false) are excluded. Mismatched
    /// lengths → 0.
    static func sequenceLogProb(perTokenLogProbs: [Float], completionMask: [Bool]) -> Float {
        guard perTokenLogProbs.count == completionMask.count else { return 0 }
        return zip(perTokenLogProbs, completionMask).reduce(Float(0)) { acc, pair in
            pair.1 ? acc + pair.0 : acc
        }
    }

    /// The KTO log-ratio logπ_θ(y|x) − logπ_ref(y|x) from the two sequence log-probs.
    static func logRatio(policyLogProb: Float, referenceLogProb: Float) -> Float {
        policyLogProb - referenceLogProb
    }

    /// The completion mask over a [prompt ++ completion] token sequence of length
    /// `totalTokenCount`: the first `promptTokenCount` positions are prompt (false),
    /// the rest are completion (true) — KTO scores only the completion. Clamped to
    /// valid bounds; totalTokenCount <= 0 → [].
    static func completionMask(promptTokenCount: Int, totalTokenCount: Int) -> [Bool] {
        guard totalTokenCount > 0 else { return [] }
        let p = max(0, min(promptTokenCount, totalTokenCount))
        return (0..<totalTokenCount).map { $0 >= p }
    }
}
