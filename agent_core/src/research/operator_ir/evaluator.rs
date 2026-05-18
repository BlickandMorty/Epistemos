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

/// Layer followed by activation: `y = φ(L(x))`.
///
/// The classic neuron primitive: a linear projection followed by
/// a pointwise nonlinearity. Distinct from
/// `apply_linear_sequence_with_activation` (which alternates
/// `L → φ → L → φ → …` across many layers) — this is the
/// single-step variant.
///
/// Requires `layer.input_dim == input.len()`. No constraint on
/// `layer.output_dim` (activation is pointwise).
///
/// Iter-227 — basic L → φ neuron, distinct from
/// `apply_layernorm_then_linear` (LN → L) and
/// `apply_two_layer_mlp` (L → φ → L).
pub fn apply_layer_with_activation<F>(
    layer: &LinearNetwork,
    input: &[f64],
    activation: F,
) -> Result<Vec<f64>, OperatorEvalError>
where
    F: Fn(f64) -> f64,
{
    let mut out = evaluate_linear(layer, input)?;
    for v in out.iter_mut() {
        *v = activation(*v);
    }
    Ok(out)
}

/// Linear interpolation between two layers' outputs:
/// `y = (1 − t) · L₀(x) + t · L₁(x)`.
///
/// At `t = 0` returns `L₀(x)`; at `t = 1` returns `L₁(x)`; at
/// `t = 0.5` returns the uniform mean. Both layers must share the
/// same `output_dim` and accept the same input shape.
///
/// Iter-221 — model-interpolation primitive (the "weight-space
/// LERP" used in model souping). Reduces to
/// `apply_layer_weighted_sum` with weights `(1-t, t)` but has a
/// cleaner call site.
pub fn apply_lerp_layers(
    l0: &LinearNetwork,
    l1: &LinearNetwork,
    t: f64,
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    apply_layer_weighted_sum(&[l0.clone(), l1.clone()], &[1.0 - t, t], input)
}

/// Input dropout then linear projection: `y = L(dropout(x; mask, keep))`.
///
/// Bernoulli feature-dropout on the input dimensions before the
/// linear projection. Distinct from
/// [`apply_layer_with_dropout`] (iter-?), which applies dropout
/// to the layer's *output*. Input-side dropout regularizes the
/// feature inputs (DropConnect / sparse-input training).
///
/// `mask.len()` must equal `input.len()`; `keep_prob` must lie
/// in `(0, 1]`. Surviving inputs are scaled by `1/keep_prob`
/// (inverted-dropout convention).
///
/// Iter-245 — companion to `apply_layer_with_dropout` (output-
/// side); together they cover the two standard "where in the
/// layer pipeline does dropout live" choices.
pub fn apply_input_dropout_then_layer(
    layer: &LinearNetwork,
    input: &[f64],
    mask: &[bool],
    keep_prob: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let masked = apply_dropout(input, mask, keep_prob)?;
    evaluate_linear(layer, &masked)
}

/// Layer with output L²-norm clipping: `y = clip(L(x), max_norm)`.
///
/// If `||L(x)|| > max_norm`, scales the output by
/// `max_norm / ||L(x)||`; otherwise passes through. The
/// gradient-clipping primitive applied at the activation level —
/// distinct from element-wise clamping (`apply_layer_clamp`), it
/// preserves direction and shrinks magnitude.
///
/// `max_norm <= 0` returns a zero vector of the layer's
/// `output_dim`.
///
/// Iter-239 — pairs with `apply_layer_clamp` (elementwise) and
/// `apply_layer_norm` (per-feature standardization); this
/// primitive is the magnitude-only Lipschitz-control variant
/// used in Wasserstein-GAN gradient penalty enforcement and in
/// adversarial-training projection.
pub fn apply_layer_l2_clip(
    layer: &LinearNetwork,
    input: &[f64],
    max_norm: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let mut out = evaluate_linear(layer, input)?;
    if max_norm <= 0.0 {
        for v in out.iter_mut() {
            *v = 0.0;
        }
        return Ok(out);
    }
    let norm: f64 = out.iter().map(|v| v * v).sum::<f64>().sqrt();
    if norm > max_norm {
        let scale = max_norm / norm;
        for v in out.iter_mut() {
            *v *= scale;
        }
    }
    Ok(out)
}

/// Concat-style skip block: `y = concat(input, L(input))`.
///
/// Output is the input followed by the layer's output —
/// equivalent to the DenseNet feature-concatenation skip and to
/// each rung of a U-Net decoder. Distinct from `evaluate_with_
/// residual` (additive skip): the channel count of `y` is
/// `input.len() + layer.output_dim`, not `input.len()`.
///
/// Requires `layer.input_dim == input.len()`.
///
/// Iter-257 — concat-skip primitive; pairs with the additive-
/// skip family (evaluate_with_residual, apply_scaled_residual_
/// block, apply_residual_subtract_block, apply_residual_mlp_block).
pub fn apply_residual_concat(
    layer: &LinearNetwork,
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    let projected = evaluate_linear(layer, input)?;
    let mut out = Vec::with_capacity(input.len() + projected.len());
    out.extend_from_slice(input);
    out.extend(projected);
    Ok(out)
}

/// Iterative-refinement / anti-residual block: `y = x − L(x)`.
///
/// The "subtract the prediction's residual" formulation used in
/// iterative refinement algorithms — given an approximate solution
/// `x` and a residual-predictor `L`, the new estimate `y = x −
/// L(x)` should be a better approximation when `L` is trained to
/// predict the error `x − x*`.
///
/// Equivalent to [`apply_scaled_residual_block`] with `α = −1`.
/// Requires `layer.input_dim == layer.output_dim == input.len()`.
///
/// Iter-233 — companion to `evaluate_with_residual` (`y = x +
/// L(x)`) and `apply_scaled_residual_block` (`y = x + α·L(x)`).
pub fn apply_residual_subtract_block(
    layer: &LinearNetwork,
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    apply_scaled_residual_block(layer, input, -1.0)
}

/// LayerScale-style scaled residual block: `y = x + α · L(x)`.
///
/// Adds a per-call scalar `alpha` to the branch path before the
/// residual add. `alpha = 1` reduces to a plain residual; `alpha
/// = 0` returns `x` unchanged (the layer is "deactivated"). The
/// CaiT / Stable-LayerScale paper initializes `alpha` to a small
/// positive ε (e.g., 0.1) and trains it, recovering plain
/// residual at convergence.
///
/// Requires `layer.input_dim == layer.output_dim == input.len()`.
///
/// Iter-215 — scalar-gated residual companion to
/// `evaluate_with_residual` (un-scaled residual) and
/// `apply_residual_mlp_block` (two-layer residual block).
pub fn apply_scaled_residual_block(
    layer: &LinearNetwork,
    input: &[f64],
    alpha: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    if layer.input_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: layer.input_dim(),
            actual: input.len(),
        });
    }
    if layer.output_dim() != input.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: input.len(),
            actual: layer.output_dim(),
        });
    }
    let mut branch = evaluate_linear(layer, input)?;
    for (b, x) in branch.iter_mut().zip(input.iter()) {
        *b = x + alpha * *b;
    }
    Ok(branch)
}

/// Linear then layer-norm: `y = LN(L(x); γ, β, ε)`.
///
/// The dual of `apply_layernorm_then_linear` (iter-209). LN is
/// applied to the *output* of the linear projection. Common in
/// older transformer designs (the original "Post-LN" variant)
/// and in some hybrid Pre/Post normalization stacks.
///
/// Constraints: `layer.input_dim == input.len()`. Gain `γ` /
/// bias `β` broadcast per the same rules as `apply_layer_norm`.
///
/// Iter-251 — closes the (LN-then-L, L-then-LN) pair around the
/// existing `apply_layer_norm` + `evaluate_linear` primitives.
pub fn apply_linear_then_layernorm(
    layer: &LinearNetwork,
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let projected = evaluate_linear(layer, input)?;
    apply_layer_norm(&projected, gain, bias, eps)
}

/// Layer-norm then linear: `y = L(LN(x; γ, β, ε))`.
///
/// "Pre-LN without the residual side path." Useful as an
/// output-projection block (final classifier head in many
/// transformer variants) and as the inner mapping of a Pre-LN
/// sandwich when the residual is added externally.
///
/// Composes `apply_layer_norm` + `evaluate_linear`. Gain `γ` and
/// bias `β` follow the same broadcast rules as `apply_layer_norm`
/// (empty slice → no scale / shift). `eps` guards the variance
/// term against div-by-zero.
///
/// Constraints: `layer.input_dim == input.len()`.
///
/// Iter-209 — composes existing primitives; surfaces the
/// no-residual variant cleanly so callers don't have to inline.
pub fn apply_layernorm_then_linear(
    layer: &LinearNetwork,
    input: &[f64],
    gain: &[f64],
    bias: &[f64],
    eps: f64,
) -> Result<Vec<f64>, OperatorEvalError> {
    let normalized = apply_layer_norm(input, gain, bias, eps)?;
    evaluate_linear(layer, &normalized)
}

/// Two-layer feedforward block `y = L₂(φ(L₁(x)))`.
///
/// The classic feedforward primitive: a linear projection,
/// pointwise activation, then another linear projection — without
/// a residual connection. Compared to `apply_residual_mlp_block`
/// (iter-?), there's no skip path, so output_dim is **not** required
/// to match input_dim.
///
/// Dimensional requirements:
///   l1.input_dim  == input.len();
///   l2.input_dim  == l1.output_dim;
///   no constraint on l2.output_dim relative to input.
///
/// Iter-203 — foundational 2-layer MLP without the residual side
/// channel; useful for output projections, dimension-reducing
/// adapters, and the FFN sub-block of a transformer when used
/// with a SiLU/GELU activation.
pub fn apply_two_layer_mlp<F>(
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
    let mut hidden = evaluate_linear(l1, input)?;
    for v in hidden.iter_mut() {
        *v = activation(*v);
    }
    evaluate_linear(l2, &hidden)
}

/// Uniform-weighted mean of layer outputs: `y = (1/k) Σᵢ Lᵢ(x)`.
///
/// Equivalent to `apply_layer_weighted_sum(layers, [1/k]·k, x)`
/// or `apply_layer_sum(layers, x) / k`. Layers must share
/// `output_dim`; empty list is an error.
///
/// Iter-197 — clean ensemble-mean primitive companion to
/// apply_layer_sum (raw) and apply_layer_weighted_sum (custom).
pub fn apply_layer_average(
    layers: &[LinearNetwork],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if layers.is_empty() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: 1,
            actual: 0,
        });
    }
    let mut sum = apply_layer_sum(layers, input)?;
    let inv_n = 1.0 / layers.len() as f64;
    for v in sum.iter_mut() {
        *v *= inv_n;
    }
    Ok(sum)
}

/// Gated linear combination — softmax-gated mixture of experts.
///
/// Given logits `g`, computes `w = softmax(g)`, then returns
/// `Σᵢ wᵢ · Lᵢ(x)`.
///
/// Composes [`apply_softmax`] + [`apply_layer_weighted_sum`]. The
/// scalar interpretation is a Shazeer-style sparsely-gated MoE
/// without the top-k truncation (which is a learned-routing
/// optimization, not a primitive).
///
/// Constraints: gate length must match layers length; all layers
/// must share output_dim; non-empty.
///
/// Iter-191 — MoE / mixture-routing primitive.
pub fn apply_gated_linear_combination(
    layers: &[LinearNetwork],
    gate_logits: &[f64],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if gate_logits.len() != layers.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: layers.len(),
            actual: gate_logits.len(),
        });
    }
    let weights = apply_softmax(gate_logits);
    apply_layer_weighted_sum(layers, &weights, input)
}

/// Weighted ensemble: `y = Σ wᵢ · Lᵢ(x)`.
///
/// Each layer must share the same output_dim; weights vector length
/// must match the number of layers. Empty layer list is an error.
///
/// Generalizes [`apply_layer_sum`] (uniform weights = 1). Common in
/// mixture-of-experts gating and model-averaging ensembles.
///
/// Iter-185 — companion to apply_layer_sum + apply_layer_concat.
pub fn apply_layer_weighted_sum(
    layers: &[LinearNetwork],
    weights: &[f64],
    input: &[f64],
) -> Result<Vec<f64>, OperatorEvalError> {
    if layers.is_empty() || weights.len() != layers.len() {
        return Err(OperatorEvalError::BranchInputDimMismatch {
            expected: layers.len(),
            actual: weights.len(),
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
    for (l, &w) in layers.iter().zip(weights.iter()) {
        let v = evaluate_linear(l, input)?;
        for (a, x) in acc.iter_mut().zip(v.iter()) {
            *a += w * x;
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

    // ── iter-257: apply_residual_concat ───────────────────────────

    #[test]
    fn residual_concat_zero_layer_returns_input_then_bias() {
        // L = 0; y = concat(x, bias).
        let l = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![3.0, -1.0],
        )
        .unwrap();
        let out = apply_residual_concat(&l, &[5.0, 6.0]).unwrap();
        assert_eq!(out, vec![5.0, 6.0, 3.0, -1.0]);
    }

    #[test]
    fn residual_concat_output_length_is_sum() {
        // input_dim + output_dim total length.
        let l = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap();
        let out = apply_residual_concat(&l, &[2.0, 3.0]).unwrap();
        assert_eq!(out.len(), 3); // 2 + 1.
    }

    #[test]
    fn residual_concat_preserves_input_prefix() {
        let l = LinearNetwork::new(
            vec![vec![100.0, 200.0], vec![300.0, 400.0]],
            vec![1.0, 1.0],
        )
        .unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_residual_concat(&l, &input).unwrap();
        assert_eq!(&out[..2], &input[..]);
    }

    #[test]
    fn residual_concat_dim_mismatch_rejected() {
        let l = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap();
        assert!(apply_residual_concat(&l, &[1.0]).is_err());
    }

    // ── iter-251: apply_linear_then_layernorm ─────────────────────

    #[test]
    fn linear_then_layernorm_matches_sequential() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let input = vec![5.0, 11.0];
        let g = vec![1.0, 1.0];
        let b = vec![0.0, 0.0];
        let composed = apply_linear_then_layernorm(&l, &input, &g, &b, 1e-12).unwrap();
        let projected = evaluate_linear(&l, &input).unwrap();
        let direct = apply_layer_norm(&projected, &g, &b, 1e-12).unwrap();
        for (a, d) in composed.iter().zip(direct.iter()) {
            assert!((a - d).abs() < 1e-12);
        }
    }

    #[test]
    fn linear_then_layernorm_outputs_mean_zero_with_default_gain_bias() {
        // Identity layer; LN with γ=1, β=0, ε≈0 → mean of LN output is 0.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out =
            apply_linear_then_layernorm(&l, &[5.0, 11.0], &[1.0, 1.0], &[0.0, 0.0], 1e-12)
                .unwrap();
        let mean: f64 = out.iter().sum::<f64>() / 2.0;
        assert!(mean.abs() < 1e-9);
    }

    #[test]
    fn linear_then_layernorm_input_dim_mismatch_rejected() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let r =
            apply_linear_then_layernorm(&l, &[1.0, 2.0, 3.0], &[1.0, 1.0], &[0.0, 0.0], 1e-5);
        assert!(r.is_err());
    }

    // ── iter-245: apply_input_dropout_then_layer ──────────────────

    #[test]
    fn input_dropout_all_keep_unit_scale_matches_plain_linear() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 1.0], vec![0.0, 2.0]],
            vec![0.0, 1.0],
        )
        .unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_input_dropout_then_layer(&l, &input, &[true, true], 1.0).unwrap();
        let direct = evaluate_linear(&l, &input).unwrap();
        assert_eq!(out, direct);
    }

    #[test]
    fn input_dropout_full_drop_returns_layer_bias() {
        // Drop everything: input becomes (0, 0); L(0, 0) = bias.
        let l = LinearNetwork::new(
            vec![vec![1.0, 1.0], vec![0.0, 2.0]],
            vec![3.0, -1.0],
        )
        .unwrap();
        let input = vec![1.0, 2.0];
        let out = apply_input_dropout_then_layer(&l, &input, &[false, false], 0.5).unwrap();
        assert_eq!(out, vec![3.0, -1.0]);
    }

    #[test]
    fn input_dropout_keep_prob_scales_surviving_inputs() {
        // mask = (true, false), keep = 0.5: input → (2·1.0, 0).
        // L = (1, 0; 0, 1), bias = 0 → output = (2, 0).
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out =
            apply_input_dropout_then_layer(&l, &[1.0, 1.0], &[true, false], 0.5).unwrap();
        assert_eq!(out, vec![2.0, 0.0]);
    }

    #[test]
    fn input_dropout_mask_dim_mismatch_rejected() {
        let l = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap();
        assert!(
            apply_input_dropout_then_layer(&l, &[1.0, 2.0], &[true], 1.0).is_err()
        );
    }

    // ── iter-239: apply_layer_l2_clip ─────────────────────────────

    #[test]
    fn layer_l2_clip_below_threshold_passes_through() {
        // L(1) = (3, 4); ||·|| = 5; max_norm = 10 → no clipping.
        let l = LinearNetwork::new(vec![vec![3.0], vec![4.0]], vec![0.0, 0.0]).unwrap();
        let out = apply_layer_l2_clip(&l, &[1.0], 10.0).unwrap();
        assert_eq!(out, vec![3.0, 4.0]);
    }

    #[test]
    fn layer_l2_clip_above_threshold_scales_to_max() {
        // L(1) = (3, 4); ||·|| = 5; max_norm = 1 → scale to 0.6, 0.8.
        let l = LinearNetwork::new(vec![vec![3.0], vec![4.0]], vec![0.0, 0.0]).unwrap();
        let out = apply_layer_l2_clip(&l, &[1.0], 1.0).unwrap();
        let norm: f64 = out.iter().map(|v| v * v).sum::<f64>().sqrt();
        assert!((norm - 1.0).abs() < 1e-9);
        assert!((out[0] - 0.6).abs() < 1e-9);
        assert!((out[1] - 0.8).abs() < 1e-9);
    }

    #[test]
    fn layer_l2_clip_zero_threshold_returns_zero() {
        let l = LinearNetwork::new(vec![vec![3.0], vec![4.0]], vec![0.0, 0.0]).unwrap();
        let out = apply_layer_l2_clip(&l, &[1.0], 0.0).unwrap();
        assert_eq!(out, vec![0.0, 0.0]);
    }

    #[test]
    fn layer_l2_clip_preserves_direction_above_threshold() {
        // After clipping, output should be parallel to pre-clip vector.
        let l = LinearNetwork::new(vec![vec![6.0], vec![8.0]], vec![0.0, 0.0]).unwrap();
        // L(1) = (6, 8); ||·|| = 10.
        let pre = evaluate_linear(&l, &[1.0]).unwrap();
        let post = apply_layer_l2_clip(&l, &[1.0], 5.0).unwrap();
        // post ⊥ pre iff cross = 0; for 2D the test is post.x · pre.y == post.y · pre.x.
        assert!((post[0] * pre[1] - post[1] * pre[0]).abs() < 1e-9);
    }

    // ── iter-233: apply_residual_subtract_block ───────────────────

    #[test]
    fn residual_subtract_zero_layer_returns_input() {
        let l = LinearNetwork::new(
            vec![vec![0.0, 0.0], vec![0.0, 0.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out = apply_residual_subtract_block(&l, &[3.0, 4.0]).unwrap();
        assert_eq!(out, vec![3.0, 4.0]);
    }

    #[test]
    fn residual_subtract_identity_layer_is_zero() {
        // L = identity → y = x - x = 0.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out = apply_residual_subtract_block(&l, &[3.0, 4.0]).unwrap();
        assert_eq!(out, vec![0.0, 0.0]);
    }

    #[test]
    fn residual_subtract_matches_scaled_residual_minus_one() {
        // y = x - L(x) ≡ apply_scaled_residual_block(L, x, -1).
        let l = LinearNetwork::new(
            vec![vec![2.0, 0.0], vec![0.0, 0.5]],
            vec![1.0, -1.0],
        )
        .unwrap();
        let x = vec![1.0, 4.0];
        let direct = apply_residual_subtract_block(&l, &x).unwrap();
        let via_scaled = apply_scaled_residual_block(&l, &x, -1.0).unwrap();
        for (a, b) in direct.iter().zip(via_scaled.iter()) {
            assert!((a - b).abs() < 1e-12);
        }
    }

    // ── iter-227: apply_layer_with_activation ─────────────────────

    #[test]
    fn layer_with_activation_identity_phi_matches_linear() {
        let l = LinearNetwork::new(vec![vec![1.0, 2.0]], vec![1.0]).unwrap();
        let with_id = apply_layer_with_activation(&l, &[1.0, 1.0], |x| x).unwrap();
        let direct = evaluate_linear(&l, &[1.0, 1.0]).unwrap();
        assert_eq!(with_id, direct);
    }

    #[test]
    fn layer_with_activation_relu_zeros_negative_preactivation() {
        // L(1) = -2 (negative); ReLU(-2) = 0.
        let l = LinearNetwork::new(vec![vec![-2.0]], vec![0.0]).unwrap();
        let out = apply_layer_with_activation(&l, &[1.0], |x| x.max(0.0)).unwrap();
        assert_eq!(out, vec![0.0]);
    }

    #[test]
    fn layer_with_activation_tanh_squashes() {
        // L(1) = 100; tanh(100) ≈ 1.
        let l = LinearNetwork::new(vec![vec![100.0]], vec![0.0]).unwrap();
        let out = apply_layer_with_activation(&l, &[1.0], |x| x.tanh()).unwrap();
        assert!((out[0] - 1.0).abs() < 1e-9);
    }

    #[test]
    fn layer_with_activation_input_dim_mismatch_rejected() {
        let l = LinearNetwork::new(vec![vec![1.0, 2.0]], vec![0.0]).unwrap();
        assert!(apply_layer_with_activation(&l, &[1.0], |x| x).is_err());
    }

    // ── iter-221: apply_lerp_layers ───────────────────────────────

    #[test]
    fn lerp_at_zero_returns_l0() {
        let l0 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l1 = LinearNetwork::new(vec![vec![5.0]], vec![0.0]).unwrap();
        let out = apply_lerp_layers(&l0, &l1, 0.0, &[3.0]).unwrap();
        assert_eq!(out, vec![3.0]);
    }

    #[test]
    fn lerp_at_one_returns_l1() {
        let l0 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l1 = LinearNetwork::new(vec![vec![5.0]], vec![0.0]).unwrap();
        let out = apply_lerp_layers(&l0, &l1, 1.0, &[3.0]).unwrap();
        assert_eq!(out, vec![15.0]);
    }

    #[test]
    fn lerp_at_half_is_uniform_mean() {
        let l0 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l1 = LinearNetwork::new(vec![vec![5.0]], vec![0.0]).unwrap();
        let lerp = apply_lerp_layers(&l0, &l1, 0.5, &[2.0]).unwrap();
        let avg = apply_layer_average(&[l0, l1], &[2.0]).unwrap();
        assert!((lerp[0] - avg[0]).abs() < 1e-12);
    }

    #[test]
    fn lerp_three_eighths_known() {
        // L0(2) = 2; L1(2) = 10; lerp_{3/8} = 0.625·2 + 0.375·10 = 1.25 + 3.75 = 5.
        let l0 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l1 = LinearNetwork::new(vec![vec![5.0]], vec![0.0]).unwrap();
        let out = apply_lerp_layers(&l0, &l1, 0.375, &[2.0]).unwrap();
        assert!((out[0] - 5.0).abs() < 1e-12);
    }

    // ── iter-215: apply_scaled_residual_block ─────────────────────

    #[test]
    fn scaled_residual_alpha_zero_returns_input() {
        let l = LinearNetwork::new(
            vec![vec![100.0, 0.0], vec![0.0, 100.0]],
            vec![5.0, -3.0],
        )
        .unwrap();
        let out = apply_scaled_residual_block(&l, &[1.0, 2.0], 0.0).unwrap();
        assert_eq!(out, vec![1.0, 2.0]);
    }

    #[test]
    fn scaled_residual_alpha_one_matches_plain_residual() {
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![1.0, -1.0],
        )
        .unwrap();
        let x = vec![3.0, 4.0];
        let scaled = apply_scaled_residual_block(&l, &x, 1.0).unwrap();
        let plain = evaluate_with_residual(&l, &x).unwrap();
        for (s, p) in scaled.iter().zip(plain.iter()) {
            assert!((s - p).abs() < 1e-12);
        }
    }

    #[test]
    fn scaled_residual_alpha_half_known() {
        // L(x) = x; α = 0.5 → y = x + 0.5x = 1.5x.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out = apply_scaled_residual_block(&l, &[2.0, 4.0], 0.5).unwrap();
        assert_eq!(out, vec![3.0, 6.0]);
    }

    #[test]
    fn scaled_residual_dim_mismatch_rejected() {
        let l = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap();
        assert!(apply_scaled_residual_block(&l, &[1.0, 2.0], 0.5).is_err());
    }

    // ── iter-209: apply_layernorm_then_linear ─────────────────────

    #[test]
    fn layernorm_then_linear_matches_sequential() {
        // Composition equivalence on a small case.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let input = vec![1.0, 2.0];
        let g = vec![1.0, 1.0];
        let b = vec![0.0, 0.0];
        let composed =
            apply_layernorm_then_linear(&l, &input, &g, &b, 1e-5).unwrap();
        let normalized = apply_layer_norm(&input, &g, &b, 1e-5).unwrap();
        let direct = evaluate_linear(&l, &normalized).unwrap();
        for (a, d) in composed.iter().zip(direct.iter()) {
            assert!((a - d).abs() < 1e-12);
        }
    }

    #[test]
    fn layernorm_then_linear_centers_first() {
        // LN with γ=1, β=0 centers and standardizes; then identity-
        // weight L should produce mean-zero output for any input.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let out =
            apply_layernorm_then_linear(&l, &[5.0, 11.0], &[1.0, 1.0], &[0.0, 0.0], 1e-12)
                .unwrap();
        let mean: f64 = out.iter().sum::<f64>() / 2.0;
        assert!(mean.abs() < 1e-9, "mean = {}", mean);
    }

    #[test]
    fn layernorm_then_linear_input_dim_mismatch_rejected() {
        // L expects 2D input; supply 3D → evaluate_linear rejects.
        let l = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![0.0, 1.0]],
            vec![0.0, 0.0],
        )
        .unwrap();
        let r =
            apply_layernorm_then_linear(&l, &[1.0, 2.0, 3.0], &[1.0; 3], &[0.0; 3], 1e-5);
        assert!(r.is_err());
    }

    // ── iter-203: apply_two_layer_mlp ─────────────────────────────

    #[test]
    fn two_layer_mlp_identity_activation_matches_compose() {
        // φ = identity collapses MLP into the composition L2∘L1.
        let l1 = LinearNetwork::new(vec![vec![1.0, 0.0], vec![0.0, 1.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![1.0, 1.0]], vec![0.0]).unwrap();
        let input = vec![2.0, 3.0];
        let mlp = apply_two_layer_mlp(&l1, &l2, &input, |x| x).unwrap();
        // L1(2, 3) = (2, 3); L2(2, 3) = 5.
        assert_eq!(mlp, vec![5.0]);
    }

    #[test]
    fn two_layer_mlp_relu_known() {
        // L1(2) = (-1, 3); ReLU → (0, 3); L2(0, 3) = 6.
        let l1 = LinearNetwork::new(vec![vec![-1.0], vec![1.5]], vec![1.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![1.0, 2.0]], vec![0.0]).unwrap();
        // Verify L1(2): row 0 = -1·2 + 1 = -1; row 1 = 1.5·2 + 0 = 3.
        let mlp = apply_two_layer_mlp(&l1, &l2, &[2.0], |x| x.max(0.0)).unwrap();
        assert_eq!(mlp, vec![6.0]);
    }

    #[test]
    fn two_layer_mlp_dim_mismatch_at_input_rejected() {
        let l1 = LinearNetwork::new(vec![vec![1.0, 2.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        assert!(apply_two_layer_mlp(&l1, &l2, &[1.0], |x| x).is_err());
    }

    #[test]
    fn two_layer_mlp_dim_mismatch_at_bridge_rejected() {
        // L1.output_dim != L2.input_dim.
        let l1 = LinearNetwork::new(vec![vec![1.0], vec![2.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![1.0, 2.0, 3.0]], vec![0.0]).unwrap();
        assert!(apply_two_layer_mlp(&l1, &l2, &[1.0], |x| x).is_err());
    }

    // ── iter-197: apply_layer_average ─────────────────────────────

    #[test]
    fn apply_layer_average_single_layer_equals_layer() {
        let l = LinearNetwork::new(vec![vec![2.0], vec![3.0]], vec![1.0, -1.0]).unwrap();
        let avg = apply_layer_average(&[l.clone()], &[4.0]).unwrap();
        let direct = evaluate_linear(&l, &[4.0]).unwrap();
        for (a, d) in avg.iter().zip(direct.iter()) {
            assert!((a - d).abs() < 1e-12);
        }
    }

    #[test]
    fn apply_layer_average_two_layers_known() {
        // L1(x) = x, L2(x) = 3x. Avg at x = 4 → (4 + 12) / 2 = 8.
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![3.0]], vec![0.0]).unwrap();
        let avg = apply_layer_average(&[l1, l2], &[4.0]).unwrap();
        assert!((avg[0] - 8.0).abs() < 1e-12);
    }

    #[test]
    fn apply_layer_average_matches_uniform_weighted_sum() {
        let l1 = LinearNetwork::new(vec![vec![1.0, 2.0], vec![3.0, 4.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![-1.0, 5.0], vec![2.0, 1.0]], vec![1.0, 0.5]).unwrap();
        let l3 = LinearNetwork::new(vec![vec![0.0, 0.0], vec![1.0, 1.0]], vec![0.0, 0.0]).unwrap();
        let x = vec![0.5, 2.0];
        let avg = apply_layer_average(&[l1.clone(), l2.clone(), l3.clone()], &x).unwrap();
        let weighted =
            apply_layer_weighted_sum(&[l1, l2, l3], &[1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], &x).unwrap();
        for (a, w) in avg.iter().zip(weighted.iter()) {
            assert!((a - w).abs() < 1e-12);
        }
    }

    #[test]
    fn apply_layer_average_empty_rejected() {
        assert!(apply_layer_average(&[], &[1.0]).is_err());
    }

    // ── iter-191: apply_gated_linear_combination ──────────────────

    #[test]
    fn gated_combination_equal_logits_matches_uniform_mean() {
        // Two identical L1, L2 with shared output_dim.
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![3.0]], vec![0.0]).unwrap();
        // gate_logits equal → softmax = (0.5, 0.5) → 0.5(x) + 0.5(3x) = 2x.
        let out = apply_gated_linear_combination(&[l1, l2], &[0.0, 0.0], &[4.0]).unwrap();
        assert!((out[0] - 8.0).abs() < 1e-12);
    }

    #[test]
    fn gated_combination_dominant_logit_picks_layer() {
        // Logit (1000, 0) → softmax ≈ (1, 0).
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![100.0]], vec![0.0]).unwrap();
        let out = apply_gated_linear_combination(&[l1, l2], &[1000.0, 0.0], &[2.0]).unwrap();
        assert!((out[0] - 2.0).abs() < 1e-9);
    }

    #[test]
    fn gated_combination_logit_count_mismatch_rejected() {
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![2.0]], vec![0.0]).unwrap();
        assert!(apply_gated_linear_combination(&[l1, l2], &[1.0], &[1.0]).is_err());
    }

    #[test]
    fn gated_combination_weights_sum_to_one() {
        // Output should equal a convex combination → must lie
        // between min and max layer outputs at the input.
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![5.0]], vec![0.0]).unwrap();
        let out = apply_gated_linear_combination(&[l1, l2], &[0.3, 0.7], &[2.0]).unwrap();
        // L1(2)=2, L2(2)=10. Output ∈ [2, 10].
        assert!(out[0] >= 2.0 - 1e-12 && out[0] <= 10.0 + 1e-12);
    }

    // ── iter-185: apply_layer_weighted_sum ────────────────────────

    #[test]
    fn weighted_sum_unit_weights_matches_layer_sum() {
        let l1 = LinearNetwork::new(vec![vec![1.0, 0.0], vec![0.0, 1.0]], vec![0.0, 0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![2.0, 0.0], vec![0.0, 2.0]], vec![0.0, 0.0]).unwrap();
        let input = vec![3.0, 4.0];
        let unit = apply_layer_weighted_sum(&[l1.clone(), l2.clone()], &[1.0, 1.0], &input).unwrap();
        let sum = apply_layer_sum(&[l1, l2], &input).unwrap();
        assert_eq!(unit, sum);
    }

    #[test]
    fn weighted_sum_scalar_multiplied_outputs() {
        // L1(x) = x, L2(x) = 2x. Weights (0.5, 0.5) → y = 0.5x + x = 1.5x.
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![2.0]], vec![0.0]).unwrap();
        let out = apply_layer_weighted_sum(&[l1, l2], &[0.5, 0.5], &[4.0]).unwrap();
        assert!((out[0] - 6.0).abs() < 1e-12);
    }

    #[test]
    fn weighted_sum_zero_weight_excludes_layer() {
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        let l2 = LinearNetwork::new(vec![vec![100.0]], vec![0.0]).unwrap();
        let out = apply_layer_weighted_sum(&[l1, l2], &[1.0, 0.0], &[5.0]).unwrap();
        assert!((out[0] - 5.0).abs() < 1e-12);
    }

    #[test]
    fn weighted_sum_weight_count_mismatch_rejected() {
        let l1 = LinearNetwork::new(vec![vec![1.0]], vec![0.0]).unwrap();
        assert!(apply_layer_weighted_sum(&[l1], &[1.0, 2.0], &[5.0]).is_err());
    }

    #[test]
    fn weighted_sum_empty_layers_rejected() {
        assert!(apply_layer_weighted_sum(&[], &[], &[1.0]).is_err());
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
