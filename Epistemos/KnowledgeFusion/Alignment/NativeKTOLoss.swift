import Foundation

// SS-LS slice 1b (native KTO port, brick 1): the pure KTO loss math — the
// algorithm core of migrating KTOTrainer off its /usr/bin/python3 subprocess to a
// native MLX LoRATrain loop. KTO (Kahneman–Tversky Optimization, Ethayarajh et al.
// 2024) aligns a policy from BINARY desirable/undesirable feedback — no paired
// preferences, the reference enters only through a detached KL baseline. This is a
// CLEAN-ROOM implementation from the published loss definition, NOT a port of the
// vendored Python trainer (NO-HIDDEN-SIDECAR / MAS-safe). It is pure + deterministic
// so it is unit-witnessed here; the full training loop (model forward pass →
// log-ratios → backprop through the LoRA params, reusing NativeLoRATrainer's
// attach/optimizer/save) wires this into LoRATrain in a later slice. KTOTrainer
// keeps its existing path until that loop is proven — no regression, no fake.
//
// Per-example loss (λ defaults to 1):
//   logratio = logπ_θ(y|x) − logπ_ref(y|x)
//   z_ref    = max(0, mean_i[β·logratio_i])              // detached KL baseline
//   desirable:   loss = λ_D · (1 − σ(β·(logratio − z_ref)))
//   undesirable: loss = λ_U · (1 − σ(β·(z_ref − logratio)))

nonisolated struct NativeKTOLoss: Sendable, Equatable {
    /// KTO temperature β (the studio/Python default is 0.1).
    var beta: Double = 0.1
    /// Loss weight for desirable examples (λ_D).
    var lambdaDesirable: Double = 1.0
    /// Loss weight for undesirable examples (λ_U).
    var lambdaUndesirable: Double = 1.0

    static func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    /// The detached KL baseline z_ref = max(0, mean(β·logratio)) over the batch.
    func klBaseline(logratios: [Double]) -> Double {
        guard !logratios.isEmpty else { return 0 }
        let mean = logratios.reduce(0, +) / Double(logratios.count)
        return max(0, beta * mean)
    }

    /// KTO loss for a single example given its policy−reference log-ratio and the
    /// (detached) batch KL baseline.
    func perExampleLoss(logratio: Double, desirable: Bool, klBaseline: Double) -> Double {
        if desirable {
            return lambdaDesirable * (1 - Self.sigmoid(beta * (logratio - klBaseline)))
        } else {
            return lambdaUndesirable * (1 - Self.sigmoid(beta * (klBaseline - logratio)))
        }
    }

    /// Mean KTO loss over a batch. `labels[i] == true` ⇒ desirable. The KL baseline
    /// is computed from the batch's log-ratios (detached). Returns 0 for an empty or
    /// mismatched batch (the caller skips — KTOTrainer already guards a minimum batch
    /// size before training).
    func batchLoss(logratios: [Double], labels: [Bool]) -> Double {
        guard !logratios.isEmpty, logratios.count == labels.count else { return 0 }
        let z = klBaseline(logratios: logratios)
        let total = zip(logratios, labels).reduce(0.0) { acc, pair in
            acc + perExampleLoss(logratio: pair.0, desirable: pair.1, klBaseline: z)
        }
        return total / Double(logratios.count)
    }
}
