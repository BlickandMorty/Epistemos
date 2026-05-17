//! Source:
//! - Lu/DeepONet arXiv:1910.03193 Thm 2 — the universal-approximation
//!   theorem for operators. Forward pass:
//!     G(u)(y) ≈ Σ_{k=1}^p branch_k(u) · trunk_k(y)
//!   This module computes that inner product for the Identity
//!   kernel; the Fourier kernel lowering lands iter-38.
//! - Doctrine §4.4 — Operator-IR first lowering target.
//! - Companion: [`super::grammar`] (the OperatorExpr we evaluate).
//!
//! # DeepONet baseline (Identity kernel)
//!
//! Given an [`super::grammar::OperatorExpr`] with
//! `kernel = Identity`, [`evaluate_operator_at`] computes the
//! scalar output value at a single (branch_input, trunk_input)
//! pair as the dot product of the branch + trunk outputs.

use super::grammar::{KernelTransform, LinearNetwork, OperatorExpr};

#[derive(Clone, Debug, PartialEq)]
pub enum OperatorEvalError {
    BranchInputDimMismatch { expected: usize, actual: usize },
    TrunkInputDimMismatch { expected: usize, actual: usize },
    NonFiniteResult { value: f64 },
    FourierNotYetImplemented,
}

/// Apply a single affine layer: `y = W·x + b`. Out-of-range input
/// dim rejected; non-finite inputs propagate to result and the
/// finiteness check below catches them.
pub fn evaluate_linear(
    network: &LinearNetwork,
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if input.len() != network.input_dim() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: input.len(),
        });
    }
    let mut out = Vec::with_capacity(network.output_dim());
    for (row, bias) in network.weights.iter().zip(network.biases.iter()) {
        let mut s = *bias;
        for (w, x) in row.iter().zip(input.iter()) {
            s += w * x;
        }
        out.push(s);
    }
    Ok(out)
}

/// DeepONet baseline forward pass — Identity kernel only.
/// Output: scalar G(u)(y) ≈ Σ_k branch_k(u) · trunk_k(y).
pub fn evaluate_operator_at(
    op: &OperatorExpr,
    branch_input: &[f64],
    trunk_input: &[f64],
) -> Result<f64, OperatorEvalError> {
    let b = evaluate_linear(&op.branch, branch_input)?;
    let t = match evaluate_linear(&op.trunk, trunk_input) {
        Ok(v) => v,
        Err(OperatorEvalError::BranchInputDimMismatch { expected, actual }) => {
            // re-tag as trunk-side mismatch for clarity
            return Err(OperatorEvalError::TrunkInputDimMismatch { expected, actual });
        }
        Err(e) => return Err(e),
    };
    let v: f64 = match op.kernel {
        KernelTransform::Identity => b.iter().zip(t.iter()).map(|(bi, ti)| bi * ti).sum(),
        KernelTransform::Fourier { modes } => {
            let t_spectral = super::fourier_kernel::fno_spectral_block(&t, modes);
            b.iter().zip(t_spectral.iter()).map(|(bi, ti)| bi * ti).sum()
        }
    };
    if !v.is_finite() {
        return Err(OperatorEvalError::NonFiniteResult { value: v });
    }
    Ok(v)
}

/// Compose two LinearNetworks `L2 ∘ L1` into a single equivalent
/// LinearNetwork representing `y = L2(L1(x))`:
///
/// `y = W2 · (W1 · x + b1) + b2 = (W2 · W1) · x + (W2 · b1 + b2)`.
///
/// Requires `L1.output_dim == L2.input_dim`.
///
/// Iter-89 — algebraic fusion of two affine maps; closes the
/// monoid structure on LinearNetwork.
pub fn compose_linear_layers(
    l1: &LinearNetwork,
    l2: &LinearNetwork,
) -> Result<LinearNetwork, OperatorEvalError> {
    if l1.output_dim() != l2.input_dim() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: l2.input_dim(),
            actual: l1.output_dim(),
        });
    }

    let in_dim = l1.input_dim();
    let mid_dim = l1.output_dim();
    let out_dim = l2.output_dim();

    let w1 = l1.weights();
    let w2 = l2.weights();
    let b1 = l1.biases();
    let b2 = l2.biases();

    // W = W2 · W1 (out × in).
    let mut w = vec![vec![0.0; in_dim]; out_dim];
    for i in 0..out_dim {
        for j in 0..in_dim {
            let mut acc = 0.0;
            for k in 0..mid_dim {
                acc += w2[i][k] * w1[k][j];
            }
            w[i][j] = acc;
        }
    }

    // b = W2 · b1 + b2 (length out).
    let mut bias = vec![0.0; out_dim];
    for i in 0..out_dim {
        let mut acc = b2[i];
        for k in 0..mid_dim {
            acc += w2[i][k] * b1[k];
        }
        bias[i] = acc;
    }

    LinearNetwork::new(w, bias).map_err(|_| OperatorEvalError::NonFiniteResult {
        value: f64::NAN,
    })
}

/// Apply a linear layer with a residual / skip connection:
/// `y = W·x + b + x` (requires output_dim == input_dim).
///
/// Iter-89 — residual block primitive. Standard in ResNet and
/// transformer architectures.
pub fn evaluate_with_residual(
    network: &LinearNetwork,
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if network.input_dim() != network.output_dim() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: network.output_dim(),
        });
    }
    let mut out = evaluate_linear(network, input)?;
    for (o, x) in out.iter_mut().zip(input.iter()) {
        *o += x;
    }
    Ok(out)
}

/// Concatenate outputs of multiple LinearNetworks evaluated against
/// the same input.
///
/// `output = [L_1(input), L_2(input), …, L_n(input)]` flattened
/// into a single vector.
///
/// All layers must share the same input dimension. Output
/// dimensions may differ per layer.
///
/// Iter-141 — multi-head attention building block. Each layer
/// represents one head; concatenation produces the
/// pre-output-projection multi-head vector.
pub fn apply_layer_concat(
    layers: &[LinearNetwork],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if layers.is_empty() {
        return Ok(Vec::new());
    }
    let mut out: Vec<f64> = Vec::new();
    for l in layers {
        let v = evaluate_linear(l, input)?;
        out.extend(v);
    }
    Ok(out)
}

/// Apply a single LinearNetwork to a batch of input vectors.
///
/// All inputs must share the network's input dimensionality.
/// Returns one output vector per input.
///
/// Iter-136 — batched-inference primitive. Allocates a fresh
/// output vector per input; for large batches consider a
/// caller-provided output buffer (out of scope here).
pub fn evaluate_linear_batch(
    network: &LinearNetwork,
    inputs: &[Vec<f64>],
) -> Result<Vec<Vec<f64>>, OperatorEvalError> {
    let mut out = Vec::with_capacity(inputs.len());
    for input in inputs {
        out.push(evaluate_linear(network, input)?);
    }
    Ok(out)
}

/// Apply a layer with an external skip connection: `y = L(x) + skip`.
///
/// Unlike `evaluate_with_residual` (iter-89) which uses the layer's
/// own input as the skip, this function takes a separate `skip`
/// vector. Useful for U-Net / DenseNet style cross-layer skips.
///
/// Requires `network.output_dim == skip.len()`.
///
/// Iter-166 — external-skip primitive.
pub fn apply_skip_connection(
    network: &LinearNetwork,
    input: &[f64],
    skip: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if network.output_dim() != skip.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.output_dim(),
            actual: skip.len(),
        });
    }
    let mut out = evaluate_linear(network, input)?;
    for (o, s) in out.iter_mut().zip(skip.iter()) {
        *o += s;
    }
    Ok(out)
}

/// Element-wise sum of multiple LinearNetwork outputs evaluated
/// against the same input. Useful for ensemble averaging and
/// branch-merge architectures.
///
/// All layers must share the same input dimension and output
/// dimension. Returns the sum vector.
///
/// Iter-127 — companion to apply_linear_sequence + compose_linear_layers.
pub fn apply_layer_sum(
    layers: &[LinearNetwork],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if layers.is_empty() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: 0,
            actual: 0,
        });
    }
    let out_dim = layers[0].output_dim();
    for l in layers.iter().skip(1) {
        if l.output_dim() != out_dim {
            return Err(OperatorEvalError::BranchInputDimMismatch {
                expected: out_dim,
                actual: l.output_dim(),
            });
        }
    }
    let mut acc = vec![0.0; out_dim];
    for l in layers {
        let v = evaluate_linear(l, input)?;
        for (a, x) in acc.iter_mut().zip(v.iter()) {
            *a += x;
        }
    }
    Ok(acc)
}

/// Pre-LN transformer block: `y = x + L(LN(x))`.
///
/// Layer-normalization applied BEFORE the linear layer, then
/// residual addition. The "Pre-LN" convention has better gradient
/// flow than Post-LN in deep transformers (Xiong et al. 2020).
///
/// Requires `network.input_dim == network.output_dim == input.len()`.
///
/// Iter-156 — transformer-block primitive (Pre-LN variant).
pub fn apply_pre_norm_block(
    network: &LinearNetwork,
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    if network.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: input.len(),
        });
    }
    if network.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: network.output_dim(),
        });
    }
    let normed = apply_layer_norm(input, gain, bias, eps)?;
    let layer_out = evaluate_linear(network, &normed)?;
    Ok(input.iter().zip(layer_out.iter()).map(|(x, y)| x + y).collect())
}

/// Post-LN transformer block: `y = LN(x + L(x))`.
///
/// Residual addition first, layer-normalization after. The "Post-LN"
/// is the original Vaswani 2017 convention. Less stable than
/// Pre-LN for very deep models but matches the canonical transformer
/// formulation.
///
/// Iter-156 — transformer-block primitive (Post-LN variant).
pub fn apply_post_norm_block(
    network: &LinearNetwork,
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    if network.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: input.len(),
        });
    }
    if network.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: network.output_dim(),
        });
    }
    let layer_out = evaluate_linear(network, input)?;
    let sum: Vec<f64> = input.iter().zip(layer_out.iter()).map(|(x, y)| x + y).collect();
    apply_layer_norm(&sum, gain, bias, eps)
}

/// LayerNorm forward pass: normalize a vector to zero mean and
/// unit variance, then apply per-element gain `γ` and bias `β`.
///
/// `y_i = γ_i · (x_i − μ) / √(σ² + ε) + β_i`
///
/// where `μ = (1/N) Σ x`, `σ² = (1/N) Σ (x - μ)²` are computed
/// from the input. `ε` is the numerical-stability constant
/// (typically 1e-5 or 1e-6).
///
/// `gain` and `bias` must each be either empty (default to all-ones
/// and all-zeros respectively) or have length equal to `input`.
///
/// Iter-121 — Ba-Kiros-Hinton 2016 "Layer Normalization". Standard
/// transformer normalization layer.
pub fn apply_layer_norm(
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    if !gain.is_empty() && gain.len() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: gain.len(),
        });
    }
    if !bias.is_empty() && bias.len() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: bias.len(),
        });
    }
    if input.is_empty() {
        return Ok(Vec::new());
    }

    let n = input.len() as f64;
    let mean: f64 = input.iter().sum::<f64>() / n;
    let var: f64 = input.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / n;
    let inv_std = 1.0 / (var + eps).sqrt();

    Ok(input
        .iter()
        .enumerate()
        .map(|(i, x)| {
            let normalized = (x - mean) * inv_std;
            let g = if gain.is_empty() { 1.0 } else { gain[i] };
            let b = if bias.is_empty() { 0.0 } else { bias[i] };
            g * normalized + b
        })
        .collect())
}

/// Numerically-stable softmax over a row of logits:
///
/// `softmax(x)_i = exp(x_i - max(x)) / Σ_j exp(x_j - max(x))`
///
/// The max-shift trick prevents overflow for large logits while
/// yielding the same mathematical result.
///
/// Returns an empty vector for empty input.
///
/// Iter-121 — standard prediction head primitive. Companion to
/// the closure-form variants `closure_categorical_softmax_*`
/// for use cases needing raw numerical output (not a closure tree).
pub fn apply_softmax(input: &[f64]) -> Vec<f64> {
    if input.is_empty() {
        return Vec::new();
    }
    let max_val = input.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let shifted: Vec<f64> = input.iter().map(|x| (x - max_val).exp()).collect();
    let sum: f64 = shifted.iter().sum();
    shifted.iter().map(|x| x / sum).collect()
}

/// Apply a LinearNetwork then inverted dropout to the output.
///
/// `y = dropout(L(x), mask, keep_prob)`.
///
/// Composes `evaluate_linear` + `apply_dropout`. The mask must
/// have length equal to the network's output_dim.
///
/// Iter-147 — common training-time primitive named for clarity.
pub fn apply_layer_with_dropout(
    network: &LinearNetwork,
    input: &[f64],
    mask: &[bool],
    keep_prob: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let pre = evaluate_linear(network, input)?;
    apply_dropout(&pre, mask, keep_prob)
}

/// Apply a LinearNetwork then clamp each output value to `[lo, hi]`.
///
/// `y_i = clamp(L(x)_i, lo, hi)` for `i = 0..output_dim`.
///
/// Iter-161 — common pattern for bounded-output models
/// (e.g. action-space limits in RL, image-pixel constraints).
pub fn apply_layer_clamp(
    network: &LinearNetwork,
    input: &[f64],
    lo: f64,
    hi: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let mut out = evaluate_linear(network, input)?;
    for v in out.iter_mut() {
        if *v < lo {
            *v = lo;
        } else if *v > hi {
            *v = hi;
        }
    }
    Ok(out)
}

/// Apply inverted dropout to a tensor of activations:
/// `y_i = (x_i · mask_i) / keep_prob` where `mask_i ∈ {0, 1}`.
///
/// During training, randomly zero a fraction `1 - keep_prob` of
/// activations and scale the survivors by `1 / keep_prob` so the
/// expected output magnitude is preserved. At inference time the
/// caller should skip this op (or pass all-ones mask + keep_prob=1).
///
/// Caller supplies the mask (typically from a Bernoulli RNG); this
/// keeps the function pure and deterministic.
///
/// Iter-115 — Hinton et al. 2012 "Dropout"; Srivastava et al. 2014
/// formalization. Standard training-time regularization.
pub fn apply_dropout(
    input: &[f64],
    mask: &[bool],
    keep_prob: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    if mask.len() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: mask.len(),
        });
    }
    if keep_prob <= 0.0 || keep_prob > 1.0 {
        return Err(OperatorEvalError::NonFiniteResult { value: keep_prob });
    }
    let scale = 1.0 / keep_prob;
    Ok(input
        .iter()
        .zip(mask.iter())
        .map(|(x, keep)| if *keep { x * scale } else { 0.0 })
        .collect())
}

/// Apply a single-layer residual with element-wise activation:
/// `y = x + σ(L(x))`.
///
/// Differs from `apply_residual_mlp_block` (iter-109, two layers
/// with intermediate activation) and from `evaluate_with_residual`
/// (iter-89, no activation).
///
/// Requires `input.len() == network.input_dim == network.output_dim`
/// for the residual to dimensionally close.
///
/// Iter-173 — single-layer activated residual primitive.
pub fn apply_linear_with_activation_then_residual<F>(
    network: &LinearNetwork,
    input: &[f64],
    activation: F,
) -> Result<Vec<f64>, OperatorEvalError>
where
    F: Fn(f64) -> f64,
{
    if network.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: input.len(),
        });
    }
    if network.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: network.output_dim(),
        });
    }
    let mut y = evaluate_linear(network, input)?;
    for v in y.iter_mut() {
        *v = activation(*v);
    }
    for (yi, xi) in y.iter_mut().zip(input.iter()) {
        *yi += xi;
    }
    Ok(y)
}

/// Apply full transformer FFN sub-block: `y = x + σ(L(LN(x)))`.
///
/// Pre-LN style sub-block composing apply_layer_norm,
/// evaluate_linear, element-wise activation, and residual addition.
/// Requires input_dim == output_dim == input.len() for residual
/// closure.
///
/// Iter-178 — full transformer FFN sub-block primitive.
pub fn apply_norm_layer_activation_residual<F>(
    network: &LinearNetwork,
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
    activation: F,
) -> Result<Vec<f64>, OperatorEvalError>
where
    F: Fn(f64) -> f64,
{
    if network.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: network.input_dim(),
            actual: input.len(),
        });
    }
    if network.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: network.output_dim(),
        });
    }
    let normed = apply_layer_norm(input, gain, bias, eps)?;
    let mut y = evaluate_linear(network, &normed)?;
    for v in y.iter_mut() {
        *v = activation(*v);
    }
    for (yi, xi) in y.iter_mut().zip(input.iter()) {
        *yi += xi;
    }
    Ok(y)
}

/// Apply a 2-layer residual MLP block: `y = x + L2(σ(L1(x)))`.
///
/// This is the canonical transformer-FFN / ResNet block pattern:
/// - L1: input expansion (e.g. d_model → 4·d_model).
/// - σ: element-wise activation (ReLU, GELU, SwiGLU, etc.).
/// - L2: projection back (e.g. 4·d_model → d_model).
/// - Add residual: y = x + projected.
///
/// Requires `L1.input_dim == L2.output_dim == input.len()` (the
/// residual connection must dimensionally close).
///
/// Iter-109 — names the residual MLP block as a first-class
/// Operator-IR operation.
pub fn apply_residual_mlp_block<F>(
    l1: &LinearNetwork,
    l2: &LinearNetwork,
    input: &[f64],
    activation: F,
) -> Result<Vec<f64>, OperatorEvalError>
where
    F: Fn(f64) -> f64,
{
    if l1.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: l1.input_dim(),
            actual: input.len(),
        });
    }
    if l1.output_dim() != l2.input_dim() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: l2.input_dim(),
            actual: l1.output_dim(),
        });
    }
    if l2.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: l2.output_dim(),
        });
    }

    // L1 forward → activation → L2 forward → residual add.
    let mut hidden = evaluate_linear(l1, input)?;
    for v in hidden.iter_mut() {
        *v = activation(*v);
    }
    let projected = evaluate_linear(l2, &hidden)?;
    Ok(projected
        .iter()
        .zip(input.iter())
        .map(|(p, x)| p + x)
        .collect())
}

/// Apply a sequence of LinearNetwork layers without activation:
/// `y = L_n(L_{n-1}(… L_1(x) …))`.
///
/// No fusion: each layer's matrix-vector product is computed
/// separately. Use [`compose_linear_layers`] if you want to
/// pre-fuse layers into a single equivalent network.
///
/// Iter-101 — convenience wrapper for chained linear evaluation.
pub fn apply_linear_sequence(
    layers: &[LinearNetwork],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    let mut current = input.to_vec();
    for layer in layers {
        current = evaluate_linear(layer, &current)?;
    }
    Ok(current)
}

/// Apply a sequence of layers with an element-wise activation
/// function applied BETWEEN consecutive layers (not after the
/// final layer):
///
/// `y = L_n(σ(L_{n-1}(σ(… σ(L_1(x)) …))))`.
///
/// The activation is applied element-wise via the caller-supplied
/// closure. Standard MLP forward pass with no activation on the
/// final logits.
///
/// Iter-101 — multi-layer MLP primitive. Pair with closure-form
/// activations (sigmoid, softplus, swish, mish, etc.) at the
/// Rust level via the closure argument.
pub fn apply_linear_sequence_with_activation<F>(
    layers: &[LinearNetwork],
    input: &[f64],
    activation: F,
) -> Result<Vec<f64>, OperatorEvalError>
where
    F: Fn(f64) -> f64,
{
    if layers.is_empty() {
        return Ok(input.to_vec());
    }
    let mut current = input.to_vec();
    for (i, layer) in layers.iter().enumerate() {
        current = evaluate_linear(layer, &current)?;
        // Apply activation BETWEEN layers (not after the last one).
        if i + 1 < layers.len() {
            for v in current.iter_mut() {
                *v = activation(*v);
            }
        }
    }
    Ok(current)
}

/// Transpose a LinearNetwork: swap input and output dimensions.
/// The new biases default to zero (the transpose of an affine map
/// drops the bias term in the standard linear-algebra sense).
///
/// Iter-89 — useful for autoencoder tied-weights, attention K^T,
/// and back-propagation analogues.
pub fn transpose_linear_layer(network: &LinearNetwork) -> LinearNetwork {
    let in_dim = network.input_dim();
    let out_dim = network.output_dim();
    let w = network.weights();
    let mut t = vec![vec![0.0; out_dim]; in_dim];
    for i in 0..out_dim {
        for j in 0..in_dim {
            t[j][i] = w[i][j];
        }
    }
    // Zero biases — the transpose of an affine map is the
    // transposed linear part with no bias.
    LinearNetwork::new(t, vec![0.0; in_dim])
        .expect("transposed weights of a valid network are also valid")
}

#[cfg(test)]
mod iter_89_tests {
    use super::*;
    use crate::research::operator_ir::grammar::LinearNetwork;

    fn id_2() -> LinearNetwork {
        LinearNetwork::new(vec![vec![1.0, 0.0], vec![0.0, 1.0]], vec![0.0, 0.0]).unwrap()
    }

    // ── iter-141: apply_layer_concat ──────────────────────────────

    #[test]
    fn apply_layer_concat_empty_list() {
        assert!(apply_layer_concat(&[], &[1.0, 2.0]).unwrap().is_empty());
    }

    #[test]
    fn apply_layer_concat_two_heads() {
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![2.0, 0.0]],
            vec![0.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        // L1(3, 4) = (4, 3); L2(3, 4) = (6).
        let out = apply_layer_concat(&[l1, l2], &input).unwrap();
        assert_eq!(out, vec![4.0, 3.0, 6.0]);
    }

    #[test]
    fn apply_layer_concat_different_output_dims_ok() {
        let l1 = LinearNetwork::new(vec![vec![1.0], vec![2.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![3.0]], vec![0.0]).unwrap();
        let l3 = LinearNetwork::new(
            vec![vec![1.0], vec![1.0], vec![1.0]],
            vec![10.0, 20.0, 30.0],
        ).unwrap();
        let input = vec![1.0];
        let out = apply_layer_concat(&[l1, l2, l3], &input).unwrap();
        // L1(1) = (1, 2). L2(1) = (3). L3(1) = (11, 21, 31).
        assert_eq!(out, vec![1.0, 2.0, 3.0, 11.0, 21.0, 31.0]);
    }

    #[test]
    fn apply_layer_concat_dim_mismatch_rejected() {
        let l1 = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![1.0, 0.0, 0.0]], vec![0.0]).unwrap();
        let input = vec![1.0, 2.0];
        assert!(apply_layer_concat(&[l1, l2], &input).is_err());
    }

    // ── iter-136: evaluate_linear_batch ───────────────────────────

    #[test]
    fn evaluate_linear_batch_empty_returns_empty() {
        let l = LinearNetwork::new(vec![vec![1.0], vec![0.0]], vec![0.0, 0.0]).unwrap();
        let out = evaluate_linear_batch(&l, &[]).unwrap();
        assert!(out.is_empty());
    }

    #[test]
    fn evaluate_linear_batch_three_inputs() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let inputs = vec![
            vec![1.0, 0.0],
            vec![0.0, 1.0],
            vec![2.0, 3.0],
        ];
        let out = evaluate_linear_batch(&l, &inputs).unwrap();
        assert_eq!(out.len(), 3);
        // Layer: y_0 = x_0 + 1, y_1 = x_1 - 1.
        assert_eq!(out[0], vec![2.0, -1.0]);
        assert_eq!(out[1], vec![1.0, 0.0]);
        assert_eq!(out[2], vec![3.0, 2.0]);
    }

    #[test]
    fn evaluate_linear_batch_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let inputs = vec![vec![1.0, 2.0], vec![1.0]]; // second has wrong dim
        assert!(evaluate_linear_batch(&l, &inputs).is_err());
    }

    #[test]
    fn evaluate_linear_batch_matches_individual_calls() {
        let l = LinearNetwork::new(
            vec![vec![2.0, 0.5], vec![-1.0, 3.0]],
            vec![1.0, -0.5],
        ).unwrap();
        let inputs = vec![
            vec![1.0, 0.0],
            vec![0.0, 1.0],
            vec![3.0, 2.0],
        ];
        let batch_out = evaluate_linear_batch(&l, &inputs).unwrap();
        for (input, b_out) in inputs.iter().zip(batch_out.iter()) {
            let direct = evaluate_linear(&l, input).unwrap();
            assert_eq!(*b_out, direct);
        }
    }

    // ── iter-166: apply_skip_connection ───────────────────────────

    #[test]
    fn apply_skip_connection_known() {
        // L(input) + skip.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        let skip = vec![10.0, 20.0];
        let out = apply_skip_connection(&l, &input, &skip).unwrap();
        // L(3, 4) = (4, 3); add skip (10, 20) → (14, 23).
        assert_eq!(out, vec![14.0, 23.0]);
    }

    #[test]
    fn apply_skip_connection_zero_skip_matches_evaluate_linear() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![5.0, 7.0];
        let out = apply_skip_connection(&l, &input, &[0.0, 0.0]).unwrap();
        assert_eq!(out, vec![5.0, 7.0]);
    }

    #[test]
    fn apply_skip_connection_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0], vec![0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0];
        let skip = vec![1.0, 2.0, 3.0]; // wrong dim
        assert!(apply_skip_connection(&l, &input, &skip).is_err());
    }

    // ── iter-127: apply_layer_sum ─────────────────────────────────

    #[test]
    fn apply_layer_sum_single_layer_matches_evaluate_linear() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        let sum = apply_layer_sum(std::slice::from_ref(&l), &input).unwrap();
        let direct = evaluate_linear(&l, &input).unwrap();
        assert_eq!(sum, direct);
    }

    #[test]
    fn apply_layer_sum_two_layers_sums_outputs() {
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, 1.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![0.0, 1.0], vec![1.0, 0.0]],
            vec![-1.0, -1.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        // L1(3, 4) = (4, 5); L2(3, 4) = (3, 2). Sum = (7, 7).
        let sum = apply_layer_sum(&[l1, l2], &input).unwrap();
        assert_eq!(sum, vec![7.0, 7.0]);
    }

    #[test]
    fn apply_layer_sum_empty_rejected() {
        let layers: Vec<LinearNetwork> = vec![];
        assert!(apply_layer_sum(&layers, &[1.0, 2.0]).is_err());
    }

    #[test]
    fn apply_layer_sum_dim_mismatch_rejected() {
        // L1 output 2, L2 output 3.
        let l1 = LinearNetwork::new(vec![vec![1.0], vec![0.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![1.0], vec![1.0], vec![1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        assert!(apply_layer_sum(&[l1, l2], &[5.0]).is_err());
    }

    // ── iter-156: Pre-LN / Post-LN transformer blocks ─────────────

    #[test]
    fn pre_norm_block_zero_layer_returns_input_after_residual() {
        // L = 0, LN scales differences; residual adds input back.
        // With γ=1, β=0, LN(x) → standardized x. L(LN(x)) = 0.
        // y = x + 0 = x.
        let l = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_pre_norm_block(&l, &input, &[], &[], 1e-9).unwrap();
        assert_eq!(out, input);
    }

    #[test]
    fn pre_norm_block_dim_mismatch_rejected() {
        // 2 → 3 layer rejected (input_dim != output_dim).
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        assert!(apply_pre_norm_block(&l, &input, &[], &[], 1e-9).is_err());
    }

    #[test]
    fn post_norm_block_zero_layer_returns_normalized_input() {
        // L = 0, residual gives back x, then LN(x) standardizes.
        // For x = (1, 2): mean = 1.5, var = 0.25, std = 0.5.
        // Normalized: ((1-1.5)/0.5, (2-1.5)/0.5) = (-1, 1).
        let l = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_post_norm_block(&l, &input, &[], &[], 1e-9).unwrap();
        assert!((out[0] - (-1.0)).abs() < 1e-3);
        assert!((out[1] - 1.0).abs() < 1e-3);
    }

    #[test]
    fn post_norm_block_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        assert!(apply_post_norm_block(&l, &input, &[], &[], 1e-9).is_err());
    }

    // ── iter-121: apply_layer_norm + apply_softmax ────────────────

    #[test]
    fn apply_layer_norm_zero_mean_unit_variance_output() {
        // After normalization (γ=1, β=0), output has zero mean
        // and unit variance.
        let input = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let out = apply_layer_norm(&input, &[], &[], 1e-9).unwrap();
        let n = out.len() as f64;
        let mean: f64 = out.iter().sum::<f64>() / n;
        let var: f64 = out.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / n;
        assert!(mean.abs() < 1e-9, "mean = {}", mean);
        assert!((var - 1.0).abs() < 1e-6, "variance = {}", var);
    }

    #[test]
    fn apply_layer_norm_with_gain_and_bias() {
        // y_i = γ_i · norm(x_i) + β_i.
        let input = vec![1.0, 2.0, 3.0];
        let gain = vec![2.0, 1.0, 0.5];
        let bias = vec![10.0, -5.0, 100.0];
        let out = apply_layer_norm(&input, &gain, &bias, 1e-9).unwrap();
        // After norm, each element x_i is normalized so that mean = 0 var = 1.
        // The bias offsets each output by the corresponding β.
        assert_eq!(out.len(), 3);
        // Verify the bias is applied properly: out_i - γ_i · norm(x_i) = β_i.
        // Mean of input = 2, var = 2/3, std ≈ 0.8165.
        // norm = ((1-2), (2-2), (3-2)) / 0.8165 ≈ (-1.2247, 0, 1.2247)
        // After γ: (-2.4494, 0, 0.6124)
        // After β: (10 - 2.4494, -5 + 0, 100 + 0.6124) ≈ (7.55, -5, 100.61).
        assert!((out[0] - 7.5505102572168225).abs() < 1e-6);
        assert!((out[1] - (-5.0)).abs() < 1e-6);
        assert!((out[2] - 100.61237243569579).abs() < 1e-6);
    }

    #[test]
    fn apply_layer_norm_constant_input_with_eps_returns_bias() {
        // If x is constant, variance = 0; normalized = 0 / √ε ≈ 0;
        // output = γ · 0 + β = β.
        let input = vec![5.0, 5.0, 5.0];
        let out = apply_layer_norm(&input, &[], &[2.0, 3.0, -1.0], 1e-9).unwrap();
        assert!((out[0] - 2.0).abs() < 1e-3);
        assert!((out[1] - 3.0).abs() < 1e-3);
        assert!((out[2] - (-1.0)).abs() < 1e-3);
    }

    #[test]
    fn apply_layer_norm_dimension_mismatch_rejected() {
        let input = vec![1.0, 2.0, 3.0];
        let gain = vec![1.0, 1.0];
        let err = apply_layer_norm(&input, &gain, &[], 1e-9).unwrap_err();
        assert!(matches!(err, OperatorEvalError::BranchInputDimMismatch { .. }));
    }

    #[test]
    fn apply_softmax_empty_input() {
        assert_eq!(apply_softmax(&[]), Vec::<f64>::new());
    }

    #[test]
    fn apply_softmax_uniform_logits_uniform_probs() {
        let out = apply_softmax(&[3.0, 3.0, 3.0]);
        for p in &out {
            assert!((p - 1.0 / 3.0).abs() < 1e-12);
        }
    }

    #[test]
    fn apply_softmax_probabilities_sum_to_one() {
        for logits in [
            vec![0.0_f64, 1.0, 2.0],
            vec![-100.0, 100.0],
            vec![1e6, 0.0, -1e6], // extreme values; max-shift critical
        ] {
            let probs = apply_softmax(&logits);
            let sum: f64 = probs.iter().sum();
            assert!((sum - 1.0).abs() < 1e-10);
        }
    }

    #[test]
    fn apply_softmax_argmax_dominates() {
        let probs = apply_softmax(&[1.0, 5.0, 2.0]);
        assert!(probs[1] > probs[0]);
        assert!(probs[1] > probs[2]);
    }

    // ── iter-161: apply_layer_clamp ───────────────────────────────

    #[test]
    fn apply_layer_clamp_within_range_unchanged() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![0.3, -0.5];
        let out = apply_layer_clamp(&l, &input, -1.0, 1.0).unwrap();
        assert_eq!(out, vec![0.3, -0.5]);
    }

    #[test]
    fn apply_layer_clamp_above_high_truncated() {
        let l = LinearNetwork::new(vec![vec![10.0]], vec![0.0]).unwrap();
        let input = vec![5.0];
        let out = apply_layer_clamp(&l, &input, 0.0, 1.0).unwrap();
        assert_eq!(out, vec![1.0]);
    }

    #[test]
    fn apply_layer_clamp_below_low_truncated() {
        let l = LinearNetwork::new(vec![vec![-10.0]], vec![0.0]).unwrap();
        let input = vec![5.0];
        let out = apply_layer_clamp(&l, &input, 0.0, 1.0).unwrap();
        assert_eq!(out, vec![0.0]);
    }

    // ── iter-147: apply_layer_with_dropout ────────────────────────

    #[test]
    fn apply_layer_with_dropout_full_keep_matches_evaluate_linear() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        let mask = vec![true, true];
        let out = apply_layer_with_dropout(&l, &input, &mask, 1.0).unwrap();
        let direct = evaluate_linear(&l, &input).unwrap();
        assert_eq!(out, direct);
    }

    #[test]
    fn apply_layer_with_dropout_zeros_masked_outputs() {
        let l = LinearNetwork::new(
            vec![vec![1.0], vec![1.0], vec![1.0]],
            vec![1.0, 2.0, 3.0],
        ).unwrap();
        let input = vec![5.0];
        // L(5) = (6, 7, 8). Mask drops position 1.
        let mask = vec![true, false, true];
        let out = apply_layer_with_dropout(&l, &input, &mask, 0.5).unwrap();
        // Survivors scaled by 2; position 1 zeroed.
        assert_eq!(out, vec![12.0, 0.0, 16.0]);
    }

    #[test]
    fn apply_layer_with_dropout_mask_length_must_match_output_dim() {
        let l = LinearNetwork::new(
            vec![vec![1.0], vec![1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0];
        let mask = vec![true]; // wrong length
        assert!(apply_layer_with_dropout(&l, &input, &mask, 0.5).is_err());
    }

    // ── iter-115: apply_dropout ───────────────────────────────────

    #[test]
    fn apply_dropout_all_ones_mask_unchanged_at_keep_one() {
        // keep_prob = 1.0 + all-ones mask → output ≡ input.
        let input = vec![1.0, 2.0, 3.0, 4.0];
        let mask = vec![true, true, true, true];
        let out = apply_dropout(&input, &mask, 1.0).unwrap();
        assert_eq!(out, input);
    }

    #[test]
    fn apply_dropout_zero_mask_returns_zeros() {
        let input = vec![1.0, 2.0, 3.0];
        let mask = vec![false, false, false];
        let out = apply_dropout(&input, &mask, 0.5).unwrap();
        assert_eq!(out, vec![0.0, 0.0, 0.0]);
    }

    #[test]
    fn apply_dropout_partial_mask_scales_survivors() {
        // keep_prob = 0.5; survivors are scaled by 2.
        let input = vec![1.0, 2.0, 3.0, 4.0];
        let mask = vec![true, false, true, false];
        let out = apply_dropout(&input, &mask, 0.5).unwrap();
        assert_eq!(out, vec![2.0, 0.0, 6.0, 0.0]);
    }

    #[test]
    fn apply_dropout_expected_magnitude_preserved() {
        // In expectation: E[mask_i] = keep_prob → E[output_i] = input_i.
        // Verify on a deterministic example: half-and-half mask + keep=0.5.
        let input = vec![10.0_f64; 4];
        let mask = vec![true, false, true, false];
        let out = apply_dropout(&input, &mask, 0.5).unwrap();
        // Sum should be 2 · (10 / 0.5) = 40, same as sum of input = 40.
        let sum: f64 = out.iter().sum();
        assert_eq!(sum, 40.0);
    }

    #[test]
    fn apply_dropout_rejects_mismatched_mask_length() {
        let input = vec![1.0, 2.0, 3.0];
        let mask = vec![true, false];
        let err = apply_dropout(&input, &mask, 0.5).unwrap_err();
        assert!(matches!(err, OperatorEvalError::BranchInputDimMismatch { .. }));
    }

    #[test]
    fn apply_dropout_rejects_invalid_keep_prob() {
        let input = vec![1.0];
        let mask = vec![true];
        for bad in [0.0_f64, -0.1, 1.5, 2.0] {
            assert!(apply_dropout(&input, &mask, bad).is_err());
        }
    }

    // ── iter-178: apply_norm_layer_activation_residual ────────────

    #[test]
    fn norm_layer_activation_residual_zero_layer_returns_input() {
        // L = 0, σ = identity → projected = 0 → y = x.
        let l = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_norm_layer_activation_residual(
            &l, &input, &[], &[], 1e-9, |x| x,
        ).unwrap();
        assert_eq!(out, input);
    }

    #[test]
    fn norm_layer_activation_residual_relu() {
        // Pre-LN normalized (1, 3) has mean=2, var=1 → standardized (-1, 1).
        // L = I (with bias 0): output (-1, 1). ReLU: (0, 1). Add input (1, 3) → (1, 4).
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 3.0];
        let out = apply_norm_layer_activation_residual(
            &l, &input, &[], &[], 1e-9, |x| x.max(0.0),
        ).unwrap();
        assert!((out[0] - 1.0).abs() < 1e-6);
        assert!((out[1] - 4.0).abs() < 1e-6);
    }

    #[test]
    fn norm_layer_activation_residual_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        assert!(apply_norm_layer_activation_residual(
            &l, &input, &[], &[], 1e-9, |x| x
        ).is_err());
    }

    // ── iter-173: apply_linear_with_activation_then_residual ──────

    #[test]
    fn apply_lar_relu_known() {
        // L(x) = x + b, σ = ReLU, y = x + max(0, L(x)).
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![-5.0, 5.0],
        ).unwrap();
        let input = vec![1.0, -3.0];
        // L(1, -3) = (-4, 2). ReLU: (0, 2). + input: (1, -1).
        let out = apply_linear_with_activation_then_residual(&l, &input, |x| x.max(0.0)).unwrap();
        assert_eq!(out, vec![1.0, -1.0]);
    }

    #[test]
    fn apply_lar_identity_activation_matches_evaluate_with_residual() {
        let l = LinearNetwork::new(
            vec![vec![2.0, 0.0], vec![0.0, 0.5]],
            vec![1.0, -1.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        let lar = apply_linear_with_activation_then_residual(&l, &input, |x| x).unwrap();
        let residual = evaluate_with_residual(&l, &input).unwrap();
        assert_eq!(lar, residual);
    }

    #[test]
    fn apply_lar_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let input = vec![1.0, 2.0];
        assert!(apply_linear_with_activation_then_residual(&l, &input, |x| x).is_err());
    }

    // ── iter-109: apply_residual_mlp_block ────────────────────────

    #[test]
    fn residual_mlp_block_identity_collapses_to_input_plus_zero() {
        // L1 = 0, σ = identity, L2 = 0 → projected = 0 → y = x.
        let zero_2x2 = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![1.5, -2.0];
        let out = apply_residual_mlp_block(&zero_2x2, &zero_2x2, &input, |x| x).unwrap();
        assert_eq!(out, input);
    }

    #[test]
    fn residual_mlp_block_with_relu_known_value() {
        // L1: 2-dim → 3-dim hidden.
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, -5.0],
        ).unwrap();
        // L2: 3-dim → 2-dim projection.
        let l2 = LinearNetwork::new(
            vec![vec![1.0, 0.0, 0.0], vec![0.0, 1.0, 0.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let input = vec![2.0, 3.0];
        // L1 output: (2, 3, 0). ReLU same: (2, 3, 0).
        // L2 output: (2, 3).
        // Residual: input + projected = (2+2, 3+3) = (4, 6).
        let out = apply_residual_mlp_block(&l1, &l2, &input, |x| x.max(0.0)).unwrap();
        assert_eq!(out, vec![4.0, 6.0]);
    }

    #[test]
    fn residual_mlp_block_rejects_dimension_mismatch() {
        // L1: 2 → 3. L2: 3 → 2. Input: 2-dim. Valid.
        // L1: 2 → 3. L2: 3 → 4. Input: 2-dim. Invalid (output 4 ≠ input 2).
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let l2_bad = LinearNetwork::new(
            vec![
                vec![1.0, 0.0, 0.0],
                vec![0.0, 1.0, 0.0],
                vec![0.0, 0.0, 1.0],
                vec![1.0, 1.0, 1.0],
            ],
            vec![0.0; 4],
        ).unwrap();
        let err = apply_residual_mlp_block(&l1, &l2_bad, &[1.0, 2.0], |x| x).unwrap_err();
        assert!(matches!(err, OperatorEvalError::BranchInputDimMismatch { .. }));
    }

    #[test]
    fn residual_mlp_block_with_zero_activation_returns_input_only() {
        // If σ(x) = 0 for all x, then projected = 0, so y = x.
        let l1 = LinearNetwork::new(
            vec![vec![5.0, 5.0], vec![5.0, 5.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![1.0, 1.0], vec![1.0, 1.0]],
            vec![100.0, 100.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        // With σ(x) = 0, hidden = 0. L2(0) = bias = (100, 100).
        // y = input + (100, 100) = (103, 104).
        let out = apply_residual_mlp_block(&l1, &l2, &input, |_| 0.0).unwrap();
        assert_eq!(out, vec![103.0, 104.0]);
    }

    // ── iter-101: apply_linear_sequence + with_activation ─────────

    #[test]
    fn apply_linear_sequence_empty_returns_input() {
        let layers: Vec<LinearNetwork> = vec![];
        let out = apply_linear_sequence(&layers, &[1.0, 2.0, 3.0]).unwrap();
        assert_eq!(out, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn apply_linear_sequence_single_layer_matches_evaluate_linear() {
        let l = LinearNetwork::new(
            vec![vec![2.0, 0.0], vec![0.0, 3.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let input = vec![1.5, 2.0];
        let via_seq = apply_linear_sequence(std::slice::from_ref(&l), &input).unwrap();
        let via_direct = evaluate_linear(&l, &input).unwrap();
        assert_eq!(via_seq, via_direct);
    }

    #[test]
    fn apply_linear_sequence_two_layers_matches_chained_call() {
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 1.0], vec![1.0, -1.0]],
            vec![0.0, 0.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![2.0, 0.0], vec![0.0, 0.5]],
            vec![1.0, -1.0],
        ).unwrap();
        let input = vec![3.0, 4.0];
        let via_seq = apply_linear_sequence(&[l1.clone(), l2.clone()], &input).unwrap();
        let intermediate = evaluate_linear(&l1, &input).unwrap();
        let via_chain = evaluate_linear(&l2, &intermediate).unwrap();
        assert_eq!(via_seq, via_chain);
    }

    #[test]
    fn apply_linear_sequence_with_activation_relu_2_layer_mlp() {
        // 2-layer MLP with ReLU activation between.
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![-1.0, -1.0]],
            vec![0.0, 0.0, 5.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![1.0, 1.0, 1.0]],
            vec![0.0],
        ).unwrap();
        let input = vec![2.0, 3.0];
        // L1 output: (2, 3, 0) before activation.
        // After ReLU: (2, 3, 0).
        // L2 output: 2 + 3 + 0 + 0 = 5.
        let out = apply_linear_sequence_with_activation(
            &[l1, l2],
            &input,
            |x| x.max(0.0),
        ).unwrap();
        assert_eq!(out, vec![5.0]);
    }

    #[test]
    fn apply_linear_sequence_with_activation_no_activation_on_final_layer() {
        // Verify activation is applied BETWEEN layers but not after
        // the last one. Use a layer that produces a negative output;
        // confirm it propagates (not zeroed by an over-applied ReLU).
        let l = LinearNetwork::new(
            vec![vec![-1.0]],
            vec![-5.0],
        ).unwrap();
        let input = vec![3.0];
        // y = -1 · 3 + (-5) = -8.
        let out = apply_linear_sequence_with_activation(
            &[l],
            &input,
            |x| x.max(0.0),
        ).unwrap();
        assert_eq!(out, vec![-8.0]);
    }

    #[test]
    fn apply_linear_sequence_with_sigmoid_activation() {
        // 2 layers with sigmoid activation between.
        let l1 = LinearNetwork::new(
            vec![vec![10.0]],
            vec![0.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![1.0]],
            vec![0.0],
        ).unwrap();
        let input = vec![5.0];
        // L1: 10·5 = 50. sigmoid(50) ≈ 1.0.
        // L2: 1·sigmoid(50) ≈ 1.0.
        let out = apply_linear_sequence_with_activation(
            &[l1, l2],
            &input,
            |x| 1.0 / (1.0 + (-x).exp()),
        ).unwrap();
        assert!((out[0] - 1.0).abs() < 1e-6);
    }

    #[test]
    fn compose_with_identity_is_identity() {
        let l = LinearNetwork::new(
            vec![vec![2.0, 0.5], vec![-1.0, 3.0]],
            vec![1.0, -0.5],
        ).unwrap();
        let id = id_2();
        let composed = compose_linear_layers(&l, &id).unwrap();
        // composed should equal l (W2=I, b2=0).
        assert_eq!(composed.weights(), l.weights());
        assert_eq!(composed.biases(), l.biases());
    }

    #[test]
    fn compose_dimensions_match() {
        // 2→3 then 3→4 should give 2→4.
        let l1 = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![
                vec![1.0, 1.0, 1.0],
                vec![1.0, -1.0, 1.0],
                vec![0.0, 1.0, 0.0],
                vec![0.5, 0.5, 0.5],
            ],
            vec![0.0, 0.0, 0.0, 0.0],
        ).unwrap();
        let composed = compose_linear_layers(&l1, &l2).unwrap();
        assert_eq!(composed.input_dim(), 2);
        assert_eq!(composed.output_dim(), 4);
    }

    #[test]
    fn compose_matches_chained_evaluation() {
        // y = L2(L1(x)) must equal composed_layer(x).
        let l1 = LinearNetwork::new(
            vec![vec![2.0, 1.0], vec![0.0, 3.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let l2 = LinearNetwork::new(
            vec![vec![1.0, 0.5], vec![-1.0, 1.0]],
            vec![0.5, 0.0],
        ).unwrap();
        let composed = compose_linear_layers(&l1, &l2).unwrap();

        for input in [vec![1.0, 0.0], vec![0.0, 1.0], vec![2.0, -1.0]] {
            let chained = evaluate_linear(&l2, &evaluate_linear(&l1, &input).unwrap()).unwrap();
            let direct = evaluate_linear(&composed, &input).unwrap();
            for (c, d) in chained.iter().zip(direct.iter()) {
                assert!((c - d).abs() < 1e-12, "chained = {}, direct = {}", c, d);
            }
        }
    }

    #[test]
    fn residual_connection_adds_input_to_output() {
        // y = Wx + b + x.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.5, -0.5],
        ).unwrap();
        let input = vec![2.0, 3.0];
        let out = evaluate_with_residual(&l, &input).unwrap();
        // Without residual: (2 + 0.5, 3 - 0.5) = (2.5, 2.5).
        // With residual: (2.5 + 2, 2.5 + 3) = (4.5, 5.5).
        assert_eq!(out, vec![4.5, 5.5]);
    }

    #[test]
    fn residual_rejects_non_square_layers() {
        // 2 → 3 cannot have a residual connection.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        ).unwrap();
        let err = evaluate_with_residual(&l, &[1.0, 2.0]).unwrap_err();
        assert!(matches!(err, OperatorEvalError::BranchInputDimMismatch { .. }));
    }

    #[test]
    fn transpose_swaps_dimensions() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 2.0, 3.0], vec![4.0, 5.0, 6.0]],
            vec![1.0, -1.0],
        ).unwrap();
        let t = transpose_linear_layer(&l);
        assert_eq!(t.input_dim(), 2);
        assert_eq!(t.output_dim(), 3);
        // (W^T)[j][i] = W[i][j].
        assert_eq!(t.weights()[0], vec![1.0, 4.0]);
        assert_eq!(t.weights()[1], vec![2.0, 5.0]);
        assert_eq!(t.weights()[2], vec![3.0, 6.0]);
        // Transpose drops bias.
        assert_eq!(t.biases(), &[0.0, 0.0, 0.0]);
    }

    #[test]
    fn transpose_is_involution_on_weights() {
        let l = LinearNetwork::new(
            vec![vec![1.5, -0.3, 2.0], vec![0.7, 1.1, -1.0]],
            vec![0.5, -0.5],
        ).unwrap();
        let t = transpose_linear_layer(&l);
        let tt = transpose_linear_layer(&t);
        // (W^T)^T = W on the weights side.
        assert_eq!(tt.weights(), l.weights());
        // (but biases were zeroed by the first transpose).
        assert_eq!(tt.biases(), &[0.0, 0.0]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::operator_ir::grammar::LinearNetwork;

    fn linear_2_to_3() -> LinearNetwork {
        // y = ((1,0), (0,1), (1,1)) * x + (0, 0, 0)
        LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
            vec![0.0, 0.0, 0.0],
        )
        .unwrap()
    }

    #[test]
    fn evaluate_linear_simple_affine() {
        let l = linear_2_to_3();
        let y = evaluate_linear(&l, &[3.0, 5.0]).unwrap();
        assert_eq!(y, vec![3.0, 5.0, 8.0]);
    }

    #[test]
    fn evaluate_linear_with_biases() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.5, -0.5],
        )
        .unwrap();
        let y = evaluate_linear(&l, &[2.0, 3.0]).unwrap();
        assert_eq!(y, vec![2.5, 2.5]);
    }

    #[test]
    fn evaluate_linear_dim_mismatch_rejected() {
        let l = linear_2_to_3();
        let err = evaluate_linear(&l, &[1.0]).unwrap_err();
        assert_eq!(
            err,
            OperatorEvalError::BranchInputDimMismatch {
                expected: 2,
                actual: 1,
            }
        );
    }

    #[test]
    fn evaluate_operator_identity_dot_product() {
        // branch(u=[2,3]) = [2, 3, 5]
        // trunk(y=[4,1])  = [4, 1, 5]
        // dot: 2*4 + 3*1 + 5*5 = 8 + 3 + 25 = 36
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let v = evaluate_operator_at(&op, &[2.0, 3.0], &[4.0, 1.0]).unwrap();
        assert_eq!(v, 36.0);
    }

    #[test]
    fn evaluate_operator_at_zero_yields_zero() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let v = evaluate_operator_at(&op, &[0.0, 0.0], &[1.0, 1.0]).unwrap();
        assert_eq!(v, 0.0);
    }

    #[test]
    fn evaluate_operator_branch_dim_mismatch_rejected() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let err = evaluate_operator_at(&op, &[1.0], &[1.0, 1.0]).unwrap_err();
        assert!(matches!(err, OperatorEvalError::BranchInputDimMismatch { .. }));
    }

    #[test]
    fn evaluate_operator_trunk_dim_mismatch_rejected() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let err =
            evaluate_operator_at(&op, &[1.0, 1.0], &[1.0]).unwrap_err();
        assert!(matches!(err, OperatorEvalError::TrunkInputDimMismatch { .. }));
    }

    #[test]
    fn evaluate_operator_fourier_full_modes_matches_identity_within_tolerance() {
        // Fourier with modes == trunk.output_dim() is a full
        // round-trip → should approximately match Identity-kernel
        // result (within DFT round-off).
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op_identity = OperatorExpr::new(
            branch.clone(),
            trunk.clone(),
            KernelTransform::Identity,
        )
        .unwrap();
        let op_fourier = OperatorExpr::new(
            branch,
            trunk,
            KernelTransform::Fourier { modes: 3 },
        )
        .unwrap();
        let u = vec![2.0, 3.0];
        let y = vec![1.0, 1.0];
        let v_id = evaluate_operator_at(&op_identity, &u, &y).unwrap();
        let v_fo = evaluate_operator_at(&op_fourier, &u, &y).unwrap();
        assert!(
            (v_id - v_fo).abs() < 1e-9 * v_id.abs().max(1.0),
            "identity={} fourier={}", v_id, v_fo
        );
    }

    #[test]
    fn evaluate_operator_bilinear_in_inputs() {
        // Scaling each input by a, b should scale output by a*b.
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let v1 = evaluate_operator_at(&op, &[1.0, 1.0], &[1.0, 1.0]).unwrap();
        let v2 = evaluate_operator_at(&op, &[2.0, 2.0], &[3.0, 3.0]).unwrap();
        // Both branch and trunk are linear (zero bias) — outputs scale
        // by 2 and 3 respectively, so dot product scales by 6.
        assert_eq!(v2, v1 * 6.0);
    }

    #[test]
    fn evaluate_operator_at_two_distinct_trunk_inputs() {
        // For fixed branch input, output is linear in the trunk output;
        // here trunk(y=[1,0]) = [1, 0, 1], trunk(y=[0,1]) = [0, 1, 1].
        // branch(u=[1,1]) = [1, 1, 2]. Dots: 1+0+2=3 and 0+1+2=3.
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        let v1 = evaluate_operator_at(&op, &[1.0, 1.0], &[1.0, 0.0]).unwrap();
        let v2 = evaluate_operator_at(&op, &[1.0, 1.0], &[0.0, 1.0]).unwrap();
        assert_eq!(v1, 3.0);
        assert_eq!(v2, 3.0);
    }
}
