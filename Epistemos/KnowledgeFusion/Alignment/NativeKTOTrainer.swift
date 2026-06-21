import Foundation

// SS-LS 1b (native KTO port, brick 6): the native KTO LoRA fine-tune — the in-process
// replacement for KTOTrainer's train_kto.py subprocess. Composes the verified bricks:
// NativeKTODataPrep (data) → NativeKTOSequenceScore (next-token tensors + completion
// mask) → a base-model REFERENCE pass (frozen) → trainable LoRA → NativeKTOLoss
// mlxBatchLoss over (policy − reference) log-ratios via valueAndGrad/Adam → save.
//
// Convergence (the loss actually descends / the adapter improves the model) is PENDING
// OWNER VERIFICATION — an on-device training run; it can't be witnessed headless. This
// brick is compile-verified + composes pieces each unit-witnessed; KTOTrainer's Python
// spawn is wired to this + removed in the next brick (with a no-spawn test).
#if !EPISTEMOS_APP_STORE
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN
import MLXOptimizers
#if canImport(MLXHuggingFace)
import MLXHuggingFace  // vmlx consolidation: `#huggingFaceTokenizerLoader()` for loadContainer.
import VMLXTokenizers  // the macro expansion fully-qualifies `VMLXTokenizers.*`.
#endif
// (Tokenizers import removed in the vmlx-swift consolidation: vmlx folds the `Tokenizer`
// protocol + `encode(text:)` into MLXLMCommon, which is already imported above.)

enum NativeKTOTrainerError: Error, LocalizedError {
    case emptyData
    var errorDescription: String? { "No usable KTO feedback examples to train on." }
}

struct NativeKTOTrainResult: Sendable {
    let adapterURL: URL
    let examplesUsed: Int
    let finalLoss: Float?
}

enum NativeKTOTrainer {
    /// Native KTO fine-tune over binary-labeled feedback. `loraConfiguration` controls
    /// rank/scale/target layers; `kto` carries β / λ. The adapter is written to
    /// `adapterURL` (adapters.safetensors) for NativeAdapterApply to load at inference.
    static func train(
        modelDirectory: URL,
        examples: [KTOExample],
        adapterURL: URL,
        loraConfiguration: LoRAConfiguration,
        kto: NativeKTOLoss = NativeKTOLoss(),
        learningRate: Float = 1e-5,
        iterations: Int = 200
    ) async throws -> NativeKTOTrainResult {
        guard !examples.isEmpty else { throw NativeKTOTrainerError.emptyData }

        let container = try await LLMModelFactory.shared.loadContainer(
            from: modelDirectory, using: #huggingFaceTokenizerLoader())

        let finalLoss: Float? = try await container.perform { (context: ModelContext) -> Float? in
            let tokenizer = context.tokenizer

            // Tokenize → padded next-token batch. Padding positions get mask 0, so (like
            // the vendored LoraTrain.loss) they never contribute to the loss.
            let rows = examples.compactMap {
                ex -> (inputs: [Int], targets: [Int], mask: [Float], desirable: Float)? in
                let fullIds = tokenizer.encode(text: ex.prompt + ex.completion)
                let promptIds = tokenizer.encode(text: ex.prompt)
                let (inp, tgt, m) = NativeKTOSequenceScore.nextTokenTraining(
                    promptTokenCount: promptIds.count, fullIds: fullIds
                )
                guard !inp.isEmpty else { return nil }
                return (inp, tgt, m.map { $0 ? Float(1) : Float(0) }, ex.desirable ? Float(1) : Float(0))
            }
            guard !rows.isEmpty else { throw NativeKTOTrainerError.emptyData }

            let maxLen = rows.map { $0.inputs.count }.max() ?? 0
            let n = rows.count
            func padInts(_ a: [Int]) -> [Int32] {
                (a + Array(repeating: 0, count: maxLen - a.count)).map(Int32.init)
            }
            func padFloats(_ a: [Float]) -> [Float] {
                a + Array(repeating: Float(0), count: maxLen - a.count)
            }
            let inputsArr = MLXArray(rows.flatMap { padInts($0.inputs) }).reshaped([n, maxLen])
            let targetsArr = MLXArray(rows.flatMap { padInts($0.targets) }).reshaped([n, maxLen])
            let maskArr = MLXArray(rows.flatMap { padFloats($0.mask) }).reshaped([n, maxLen])
            let desirableArr = MLXArray(rows.map { $0.desirable })

            // Completion sequence log-probs = −Σ(crossEntropy · completionMask) per row.
            func seqLogProbs(_ model: any LLMModel) -> MLXArray {
                let logits = model(inputsArr, cache: nil).asType(.float32)
                return -(crossEntropy(logits: logits, targets: targetsArr) * maskArr).sum(axis: 1)
            }

            // 1) FROZEN reference log-probs from the BASE model (before LoRA), detached.
            let baseModel = context.model as! any LLMModel
            let refLP = seqLogProbs(baseModel)
            eval(refLP)
            let refArr = MLXArray(refLP.asArray(Float.self))

            // 2) attach trainable LoRA + optimizer.
            _ = try LoRAContainer.from(model: context.model, configuration: loraConfiguration)
            let optimizer = Adam(learningRate: learningRate)

            // 3) minimize the KTO loss over (policy − reference) log-ratios. The closure
            // takes everything via `arrays` and captures only the Sendable `kto`.
            let lossValueGrad = valueAndGrad(model: context.model) { model, arrays in
                let m = model as! any LLMModel
                let logits = m(arrays[0], cache: nil).asType(.float32)
                let policy = -(crossEntropy(logits: logits, targets: arrays[1]) * arrays[2]).sum(axis: 1)
                let logratios = policy - arrays[3]
                return [kto.mlxBatchLoss(logratios: logratios, desirable: arrays[4])]
            }

            var loss: Float = 0
            for _ in 0 ..< max(1, iterations) {
                let (result, grad) = lossValueGrad(
                    context.model, [inputsArr, targetsArr, maskArr, refArr, desirableArr]
                )
                optimizer.update(model: context.model, gradients: grad)
                eval(context.model, optimizer, result[0])
                loss = result[0].item(Float.self)
            }

            // 4) save the adapter — weights + adapter_config.json — so NativeAdapterApply
            // (LoRAContainer.from(directory:)) can load it natively for inference.
            try LoRATrain.saveLoRAWeights(model: context.model, url: adapterURL)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(loraConfiguration)
                .write(to: NativeAdapterDirectory.configURL(in: adapterURL.deletingLastPathComponent()))
            return loss
        }

        return NativeKTOTrainResult(
            adapterURL: adapterURL, examplesUsed: examples.count, finalLoss: finalLoss
        )
    }
}
#endif
