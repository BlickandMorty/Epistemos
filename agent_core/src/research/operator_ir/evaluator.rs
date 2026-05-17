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
