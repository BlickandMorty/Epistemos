// VENDORED VERBATIM from ml-explore/mlx-swift-lm @ e3cb1e1b (synced 2026-06-14) — Apple Inc., MIT.
// Do not hand-edit; re-sync from upstream. Brings native Gemma 4 (gemma4 / gemma4_text)
// support into the Epistemos fork, replacing the prior Gemma-3n alias. Apple-tested port.

import MLX

package enum Gemma4SharedKVState {
    case regular(keys: MLXArray, values: MLXArray)
    case quantized(
        keys: (MLXArray, MLXArray, MLXArray?),
        values: (MLXArray, MLXArray, MLXArray?),
        groupSize: Int,
        bits: Int,
        mode: QuantizationMode
    )

    package var sequenceLength: Int {
        switch self {
        case .regular(let keys, _):
            keys.dim(2)
        case .quantized(let keys, _, _, _, _):
            keys.0.dim(-2)
        }
    }
}
