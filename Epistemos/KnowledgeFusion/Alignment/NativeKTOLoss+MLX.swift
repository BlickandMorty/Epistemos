#if !EPISTEMOS_APP_STORE
import Foundation
import MLX

// SS-LS 1b (native KTO port, brick 3): the KTO loss on MLXArrays — the DIFFERENTIABLE
// form the native training loop backprops through (MLX.valueAndGrad over the LoRA
// params). Same math as the pure scalar `NativeKTOLoss.batchLoss`, so the scalar is
// its oracle: the test eval-compares the two. Pro-gated (training is Apple-Silicon /
// Pro-only). KTOTrainer's Python path is untouched by this brick.
extension NativeKTOLoss {
    /// KTO loss over a batch, on MLXArrays.
    /// - Parameters:
    ///   - logratios: shape [N], logπ_θ(y|x) − logπ_ref(y|x) per example.
    ///   - desirable: shape [N], 1.0 = desirable, 0.0 = undesirable.
    /// - Returns: the scalar mean loss as an MLXArray (keeps the graph for valueAndGrad).
    ///
    /// The KL baseline z = max(0, mean(β·logratio)) is DETACHED (`stopGradient`) per
    /// the KTO definition — gradients flow through `logratios`, not through z.
    nonisolated func mlxBatchLoss(logratios: MLXArray, desirable: MLXArray) -> MLXArray {
        let b = Float(beta)
        // z_ref = max(0, mean(β·logratio)), DETACHED (KTO's KL baseline doesn't backprop).
        let z = MLX.stopGradient(maximum(MLXArray(Float(0)), b * logratios.mean()))
        // σ via exp (1/(1+e^-x)): a bare `sigmoid(...)` here would resolve to the scalar
        // NativeKTOLoss.sigmoid(Double), not the MLX op (it's shadowed in this extension).
        let sigDesirable = 1 / (1 + MLX.exp(-(b * (logratios - z))))
        let sigUndesirable = 1 / (1 + MLX.exp(-(b * (z - logratios))))
        let lossDesirable = Float(lambdaDesirable) * (1 - sigDesirable)
        let lossUndesirable = Float(lambdaUndesirable) * (1 - sigUndesirable)
        let perExample = desirable * lossDesirable + (1 - desirable) * lossUndesirable
        return perExample.mean()
    }
}
#endif
