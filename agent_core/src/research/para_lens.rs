//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.6.19 — Para(Lens(Smooth)) ↔ Rust trait
//!   correspondence.
//! - Cruttwell, Gavranović, Ghani, Wilson, Zanasi, "Categorical
//!   Foundations of Gradient-Based Learning", arXiv:2103.01931, 2021 —
//!   the Para(Lens(C)) construction for backprop.
//! - Wilson, Zanasi, "Categories of Differentiable Polynomial
//!   Circuits for Machine Learning", arXiv:2404.00408, 2024 — the
//!   "polynomial circuit" instance the V6.1 §1.8 theorem hunt targets.
//!
//! # Wave J B.6.19 — Para(Lens(Smooth)) Rust trait substrate
//!
//! The Cruttwell et al. 2021 categorical view of a neural network
//! layer:
//!
//! ```text
//! Lens(C):
//!   morphism (A → B) is a pair of C-morphisms
//!   forward:  A → B
//!   backward: A × B' → A'   (B' = cotangent of B, A' = of A)
//!
//! Para(Lens(C)):
//!   adds a "parameter object" P, so a layer is
//!   forward:  P × A → B
//!   backward: P × A × B' → P' × A'
//! ```
//!
//! The Rust trait below is the direct mirror. A `ParaLens` impl is
//! one layer; the substrate floor includes a [`LinearLayer`] reference
//! impl showing how the forward + backward pair compose.
//!
//! Substrate floor: scalar weights + 1-D input/output (single-feature
//! "neuron"). Real implementations use matrix weights + multi-feature
//! tensors; the trait shape carries over verbatim.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ParaLensError {
    InputLengthMismatch { expected: usize, actual: usize },
    OutputLengthMismatch { expected: usize, actual: usize },
    GradientLengthMismatch { expected: usize, actual: usize },
}

impl ParaLensError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            ParaLensError::InputLengthMismatch { .. } => "input_length_mismatch",
            ParaLensError::OutputLengthMismatch { .. } => "output_length_mismatch",
            ParaLensError::GradientLengthMismatch { .. } => "gradient_length_mismatch",
        }
    }

    pub const fn is_input_mismatch(&self) -> bool {
        matches!(self, ParaLensError::InputLengthMismatch { .. })
    }

    pub const fn is_output_mismatch(&self) -> bool {
        matches!(self, ParaLensError::OutputLengthMismatch { .. })
    }

    pub const fn is_gradient_mismatch(&self) -> bool {
        matches!(self, ParaLensError::GradientLengthMismatch { .. })
    }

    /// `(expected, actual)` pair carried by any of the three variants
    /// — they share the same struct shape.
    pub const fn lengths(&self) -> (usize, usize) {
        match self {
            ParaLensError::InputLengthMismatch { expected, actual }
            | ParaLensError::OutputLengthMismatch { expected, actual }
            | ParaLensError::GradientLengthMismatch { expected, actual } => (*expected, *actual),
        }
    }
}

/// Backward result: gradients flow to both the parameter and the input.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ParaLensBackward {
    pub param_grad: Vec<f32>,
    pub input_grad: Vec<f32>,
}

impl ParaLensBackward {
    /// L2 norm of the parameter gradient. The "how big is this
    /// parameter update?" diagnostic; large values flag potential
    /// gradient-explosion paths.
    pub fn param_grad_norm(&self) -> f32 {
        self.param_grad.iter().map(|g| g * g).sum::<f32>().sqrt()
    }

    /// L2 norm of the input gradient. Mirror of [`Self::param_grad_norm`].
    pub fn input_grad_norm(&self) -> f32 {
        self.input_grad.iter().map(|g| g * g).sum::<f32>().sqrt()
    }

    /// Predicate: every entry in both gradients is exactly 0.0.
    /// Useful as a sentinel for "this backward call propagated no
    /// signal" (e.g., ReLU in the dead branch).
    pub fn is_zero(&self) -> bool {
        self.param_grad.iter().all(|&g| g == 0.0)
            && self.input_grad.iter().all(|&g| g == 0.0)
    }
}

pub trait ParaLens {
    /// Parameter-vector size.
    fn param_size(&self) -> usize;
    fn input_size(&self) -> usize;
    fn output_size(&self) -> usize;

    /// `forward: P × A → B`
    fn forward(
        &self,
        params: &[f32],
        input: &[f32],
        output: &mut [f32],
    ) -> Result<(), ParaLensError>;

    /// `backward: P × A × B' → P' × A'`
    fn backward(
        &self,
        params: &[f32],
        input: &[f32],
        output_grad: &[f32],
    ) -> Result<ParaLensBackward, ParaLensError>;
}

/// Reference [`ParaLens`] impl: 1-input, 1-output linear "neuron" with
/// 2 parameters (slope + intercept): `y = w * x + b`.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct LinearLayer;

impl ParaLens for LinearLayer {
    fn param_size(&self) -> usize {
        2
    }
    fn input_size(&self) -> usize {
        1
    }
    fn output_size(&self) -> usize {
        1
    }

    fn forward(
        &self,
        params: &[f32],
        input: &[f32],
        output: &mut [f32],
    ) -> Result<(), ParaLensError> {
        if params.len() != 2 {
            return Err(ParaLensError::InputLengthMismatch { expected: 2, actual: params.len() });
        }
        if input.len() != 1 {
            return Err(ParaLensError::InputLengthMismatch { expected: 1, actual: input.len() });
        }
        if output.len() != 1 {
            return Err(ParaLensError::OutputLengthMismatch {
                expected: 1,
                actual: output.len(),
            });
        }
        let w = params[0];
        let b = params[1];
        output[0] = w * input[0] + b;
        Ok(())
    }

    fn backward(
        &self,
        params: &[f32],
        input: &[f32],
        output_grad: &[f32],
    ) -> Result<ParaLensBackward, ParaLensError> {
        if params.len() != 2 {
            return Err(ParaLensError::InputLengthMismatch { expected: 2, actual: params.len() });
        }
        if input.len() != 1 {
            return Err(ParaLensError::InputLengthMismatch { expected: 1, actual: input.len() });
        }
        if output_grad.len() != 1 {
            return Err(ParaLensError::GradientLengthMismatch {
                expected: 1,
                actual: output_grad.len(),
            });
        }
        // y = w * x + b
        // dy/dw = x, dy/db = 1, dy/dx = w
        let w = params[0];
        let x = input[0];
        let dy = output_grad[0];
        Ok(ParaLensBackward {
            param_grad: vec![dy * x, dy * 1.0],
            input_grad: vec![dy * w],
        })
    }
}

/// Parameterless activation: `y = max(0, x)`. Second reference
/// [`ParaLens`] impl. The `param_size = 0` case shows the trait
/// shape carries over to activation layers without losing the
/// `Para(Lens(C))` structure (the parameter object is just the
/// unit element).
///
/// Backward: `dy/dx = (x > 0) ? 1 : 0`. The non-smooth point at
/// `x = 0` is a measure-zero corner case; substrate floor uses the
/// "left derivative" (0). Production may use the subgradient form.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ReluLayer;

impl ParaLens for ReluLayer {
    fn param_size(&self) -> usize {
        0
    }
    fn input_size(&self) -> usize {
        1
    }
    fn output_size(&self) -> usize {
        1
    }

    fn forward(
        &self,
        params: &[f32],
        input: &[f32],
        output: &mut [f32],
    ) -> Result<(), ParaLensError> {
        if !params.is_empty() {
            return Err(ParaLensError::InputLengthMismatch {
                expected: 0,
                actual: params.len(),
            });
        }
        if input.len() != 1 {
            return Err(ParaLensError::InputLengthMismatch {
                expected: 1,
                actual: input.len(),
            });
        }
        if output.len() != 1 {
            return Err(ParaLensError::OutputLengthMismatch {
                expected: 1,
                actual: output.len(),
            });
        }
        output[0] = input[0].max(0.0);
        Ok(())
    }

    fn backward(
        &self,
        params: &[f32],
        input: &[f32],
        output_grad: &[f32],
    ) -> Result<ParaLensBackward, ParaLensError> {
        if !params.is_empty() {
            return Err(ParaLensError::InputLengthMismatch {
                expected: 0,
                actual: params.len(),
            });
        }
        if input.len() != 1 {
            return Err(ParaLensError::InputLengthMismatch {
                expected: 1,
                actual: input.len(),
            });
        }
        if output_grad.len() != 1 {
            return Err(ParaLensError::GradientLengthMismatch {
                expected: 1,
                actual: output_grad.len(),
            });
        }
        // dy/dx = (x > 0) ? 1 : 0 ; left derivative at 0 is 0.
        let x = input[0];
        let dy = output_grad[0];
        let grad = if x > 0.0 { dy } else { 0.0 };
        Ok(ParaLensBackward {
            param_grad: vec![],
            input_grad: vec![grad],
        })
    }
}

/// Categorical compose of two `ParaLens` impls per Cruttwell et al.
/// 2021 §3. Composed[A, B] is `B ∘ A`: forward runs A then B; backward
/// runs B-back then A-back per the chain rule.
///
/// Param vector layout: `[p_a... | p_b...]` — A's params first, B's
/// params second. The composed param size is `A.param_size +
/// B.param_size`.
///
/// Size constraint: `A.output_size == B.input_size`. Detected at
/// forward/backward time as `OutputLengthMismatch` since the trait
/// doesn't have a constructor that can fail.
#[derive(Clone, Copy, Debug)]
pub struct Composed<A: ParaLens, B: ParaLens> {
    pub first: A,
    pub second: B,
}

impl<A: ParaLens, B: ParaLens> Composed<A, B> {
    pub fn new(first: A, second: B) -> Self {
        Self { first, second }
    }
}

impl<A: ParaLens, B: ParaLens> ParaLens for Composed<A, B> {
    fn param_size(&self) -> usize {
        self.first.param_size() + self.second.param_size()
    }

    fn input_size(&self) -> usize {
        self.first.input_size()
    }

    fn output_size(&self) -> usize {
        self.second.output_size()
    }

    fn forward(
        &self,
        params: &[f32],
        input: &[f32],
        output: &mut [f32],
    ) -> Result<(), ParaLensError> {
        if params.len() != self.param_size() {
            return Err(ParaLensError::InputLengthMismatch {
                expected: self.param_size(),
                actual: params.len(),
            });
        }
        if self.first.output_size() != self.second.input_size() {
            return Err(ParaLensError::OutputLengthMismatch {
                expected: self.second.input_size(),
                actual: self.first.output_size(),
            });
        }
        let (p_a, p_b) = params.split_at(self.first.param_size());
        let mut intermediate = vec![0.0_f32; self.first.output_size()];
        self.first.forward(p_a, input, &mut intermediate)?;
        self.second.forward(p_b, &intermediate, output)?;
        Ok(())
    }

    fn backward(
        &self,
        params: &[f32],
        input: &[f32],
        output_grad: &[f32],
    ) -> Result<ParaLensBackward, ParaLensError> {
        if params.len() != self.param_size() {
            return Err(ParaLensError::InputLengthMismatch {
                expected: self.param_size(),
                actual: params.len(),
            });
        }
        if self.first.output_size() != self.second.input_size() {
            return Err(ParaLensError::OutputLengthMismatch {
                expected: self.second.input_size(),
                actual: self.first.output_size(),
            });
        }
        let (p_a, p_b) = params.split_at(self.first.param_size());
        // Re-run forward to materialize the intermediate `y` value.
        // Caching `y` from forward would be more efficient; substrate
        // floor recomputes to keep the trait stateless.
        let mut intermediate = vec![0.0_f32; self.first.output_size()];
        self.first.forward(p_a, input, &mut intermediate)?;
        // Backward through B: gives dp_b and dy.
        let b_back = self.second.backward(p_b, &intermediate, output_grad)?;
        // Backward through A: takes dy as A's output_grad, gives dp_a and dx.
        let a_back = self.first.backward(p_a, input, &b_back.input_grad)?;
        // Concatenate param grads in [a | b] order matching forward.
        let mut param_grad = a_back.param_grad;
        param_grad.extend(b_back.param_grad);
        Ok(ParaLensBackward {
            param_grad,
            input_grad: a_back.input_grad,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn linear_layer_sizes_match_constructor() {
        let l = LinearLayer;
        assert_eq!(l.param_size(), 2);
        assert_eq!(l.input_size(), 1);
        assert_eq!(l.output_size(), 1);
    }

    #[test]
    fn linear_forward_zero_params_zero_input_is_zero_output() {
        let l = LinearLayer;
        let mut out = vec![99.0_f32];
        l.forward(&[0.0, 0.0], &[0.0], &mut out).unwrap();
        assert!(approx(out[0], 0.0, 1e-6));
    }

    #[test]
    fn linear_forward_y_equals_w_x_plus_b() {
        let l = LinearLayer;
        let mut out = vec![0.0_f32];
        l.forward(&[2.0, 3.0], &[4.0], &mut out).unwrap();
        // y = 2*4 + 3 = 11
        assert!(approx(out[0], 11.0, 1e-6));
    }

    #[test]
    fn linear_backward_param_grads_correct() {
        let l = LinearLayer;
        // dy/dw = x = 5; dy/db = 1
        let bw = l.backward(&[2.0, 3.0], &[5.0], &[1.0]).unwrap();
        assert!(approx(bw.param_grad[0], 5.0, 1e-6));
        assert!(approx(bw.param_grad[1], 1.0, 1e-6));
    }

    #[test]
    fn linear_backward_input_grad_is_weight() {
        let l = LinearLayer;
        let bw = l.backward(&[7.0, 3.0], &[5.0], &[1.0]).unwrap();
        assert!(approx(bw.input_grad[0], 7.0, 1e-6));
    }

    #[test]
    fn linear_backward_scales_with_output_grad() {
        let l = LinearLayer;
        let bw1 = l.backward(&[2.0, 0.0], &[3.0], &[1.0]).unwrap();
        let bw2 = l.backward(&[2.0, 0.0], &[3.0], &[5.0]).unwrap();
        assert!(approx(bw2.param_grad[0] / bw1.param_grad[0], 5.0, 1e-6));
        assert!(approx(bw2.input_grad[0] / bw1.input_grad[0], 5.0, 1e-6));
    }

    #[test]
    fn linear_forward_wrong_param_size_errors() {
        let l = LinearLayer;
        let mut out = vec![0.0_f32];
        let err = l.forward(&[1.0], &[2.0], &mut out).unwrap_err();
        assert_eq!(
            err,
            ParaLensError::InputLengthMismatch { expected: 2, actual: 1 }
        );
    }

    #[test]
    fn linear_backward_wrong_grad_size_errors() {
        let l = LinearLayer;
        let err = l.backward(&[1.0, 2.0], &[3.0], &[1.0, 1.0]).unwrap_err();
        assert_eq!(
            err,
            ParaLensError::GradientLengthMismatch { expected: 1, actual: 2 }
        );
    }

    #[test]
    fn finite_difference_check_matches_analytic_backward() {
        // Numerically verify dy/dw, dy/db, dy/dx vs analytic backward.
        let l = LinearLayer;
        let params = vec![3.0_f32, -2.0];
        let input = vec![5.0_f32];
        let mut y0 = vec![0.0_f32];
        l.forward(&params, &input, &mut y0).unwrap();
        let eps = 1e-3_f32;
        let mut y_w = vec![0.0_f32];
        l.forward(&[params[0] + eps, params[1]], &input, &mut y_w).unwrap();
        let mut y_b = vec![0.0_f32];
        l.forward(&[params[0], params[1] + eps], &input, &mut y_b).unwrap();
        let mut y_x = vec![0.0_f32];
        l.forward(&params, &[input[0] + eps], &mut y_x).unwrap();
        let bw = l.backward(&params, &input, &[1.0]).unwrap();
        assert!(approx((y_w[0] - y0[0]) / eps, bw.param_grad[0], 1e-3));
        assert!(approx((y_b[0] - y0[0]) / eps, bw.param_grad[1], 1e-3));
        assert!(approx((y_x[0] - y0[0]) / eps, bw.input_grad[0], 1e-3));
    }

    #[test]
    fn backward_roundtrips_through_serde_json() {
        let bw = ParaLensBackward {
            param_grad: vec![1.0, 2.0],
            input_grad: vec![3.0],
        };
        let json = serde_json::to_string(&bw).unwrap();
        let back: ParaLensBackward = serde_json::from_str(&json).unwrap();
        assert_eq!(bw, back);
    }

    #[test]
    fn zero_output_grad_yields_zero_input_and_param_grads() {
        let l = LinearLayer;
        let bw = l.backward(&[2.0, 3.0], &[5.0], &[0.0]).unwrap();
        assert!(approx(bw.param_grad[0], 0.0, 1e-6));
        assert!(approx(bw.param_grad[1], 0.0, 1e-6));
        assert!(approx(bw.input_grad[0], 0.0, 1e-6));
    }

    // ── ReluLayer tests (iter 93) ───────────────────────────────────────────

    #[test]
    fn relu_layer_sizes_correct() {
        let r = ReluLayer;
        assert_eq!(r.param_size(), 0);
        assert_eq!(r.input_size(), 1);
        assert_eq!(r.output_size(), 1);
    }

    #[test]
    fn relu_forward_positive_passes_through() {
        let r = ReluLayer;
        let mut out = vec![0.0_f32];
        r.forward(&[], &[3.5], &mut out).unwrap();
        assert!(approx(out[0], 3.5, 1e-6));
    }

    #[test]
    fn relu_forward_negative_clamps_to_zero() {
        let r = ReluLayer;
        let mut out = vec![0.0_f32];
        r.forward(&[], &[-2.0], &mut out).unwrap();
        assert!(approx(out[0], 0.0, 1e-6));
    }

    #[test]
    fn relu_forward_at_zero_outputs_zero() {
        let r = ReluLayer;
        let mut out = vec![99.0_f32];
        r.forward(&[], &[0.0], &mut out).unwrap();
        assert!(approx(out[0], 0.0, 1e-6));
    }

    #[test]
    fn relu_backward_positive_input_passes_grad() {
        let r = ReluLayer;
        let bw = r.backward(&[], &[1.5], &[7.0]).unwrap();
        assert!(bw.param_grad.is_empty());
        assert!(approx(bw.input_grad[0], 7.0, 1e-6));
    }

    #[test]
    fn relu_backward_negative_input_zeros_grad() {
        let r = ReluLayer;
        let bw = r.backward(&[], &[-1.5], &[7.0]).unwrap();
        assert!(approx(bw.input_grad[0], 0.0, 1e-6));
    }

    #[test]
    fn relu_backward_at_zero_uses_left_derivative() {
        let r = ReluLayer;
        let bw = r.backward(&[], &[0.0], &[7.0]).unwrap();
        assert!(approx(bw.input_grad[0], 0.0, 1e-6));
    }

    #[test]
    fn relu_rejects_non_empty_params() {
        let r = ReluLayer;
        let mut out = vec![0.0_f32];
        let err = r.forward(&[1.0], &[2.0], &mut out).unwrap_err();
        assert_eq!(
            err,
            ParaLensError::InputLengthMismatch { expected: 0, actual: 1 }
        );
    }

    #[test]
    fn relu_finite_difference_matches_analytic() {
        let r = ReluLayer;
        for x_val in &[-2.0_f32, -0.5, 0.5, 2.0] {
            let mut y0 = vec![0.0_f32];
            r.forward(&[], &[*x_val], &mut y0).unwrap();
            let eps = 1e-3_f32;
            let mut y_x = vec![0.0_f32];
            r.forward(&[], &[x_val + eps], &mut y_x).unwrap();
            let bw = r.backward(&[], &[*x_val], &[1.0]).unwrap();
            let fd = (y_x[0] - y0[0]) / eps;
            assert!(
                approx(fd, bw.input_grad[0], 1e-3),
                "x={}: fd={}, analytic={}",
                x_val,
                fd,
                bw.input_grad[0]
            );
        }
    }

    // ── Composed<A, B> tests (iter 100) ─────────────────────────────────────

    #[test]
    fn composed_linear_then_relu_sizes_correct() {
        let c = Composed::new(LinearLayer, ReluLayer);
        assert_eq!(c.param_size(), 2); // 2 from LinearLayer + 0 from ReluLayer
        assert_eq!(c.input_size(), 1);
        assert_eq!(c.output_size(), 1);
    }

    #[test]
    fn composed_two_linears_concatenates_params() {
        let c = Composed::new(LinearLayer, LinearLayer);
        assert_eq!(c.param_size(), 4); // 2 + 2
    }

    #[test]
    fn composed_forward_runs_linear_then_relu() {
        // LinearLayer: y_mid = 2*x + (-3) = 2*x - 3
        // ReluLayer:   y_out = max(0, y_mid)
        let c = Composed::new(LinearLayer, ReluLayer);
        let params = vec![2.0_f32, -3.0]; // [w, b] for LinearLayer
        let mut out = vec![0.0_f32];

        // x = 5 → mid = 7 → out = 7
        c.forward(&params, &[5.0], &mut out).unwrap();
        assert!(approx(out[0], 7.0, 1e-6));

        // x = 1 → mid = -1 → out = 0 (relu clamps)
        c.forward(&params, &[1.0], &mut out).unwrap();
        assert!(approx(out[0], 0.0, 1e-6));
    }

    #[test]
    fn composed_backward_chain_rule_active_branch() {
        // x = 5, params = [2, -3] → mid = 7 (positive, relu passes).
        // dout/dy_mid = 1 (relu in active region)
        // dy_mid/dw = x = 5
        // dy_mid/db = 1
        // dy_mid/dx = w = 2
        let c = Composed::new(LinearLayer, ReluLayer);
        let bw = c.backward(&[2.0, -3.0], &[5.0], &[1.0]).unwrap();
        assert_eq!(bw.param_grad.len(), 2);
        assert!(approx(bw.param_grad[0], 5.0, 1e-6)); // dL/dw
        assert!(approx(bw.param_grad[1], 1.0, 1e-6)); // dL/db
        assert!(approx(bw.input_grad[0], 2.0, 1e-6)); // dL/dx
    }

    #[test]
    fn composed_backward_zero_grad_in_inactive_relu_branch() {
        // x = 1, params = [2, -3] → mid = -1 (relu OFF).
        // All gradients should be zero (relu kills the chain).
        let c = Composed::new(LinearLayer, ReluLayer);
        let bw = c.backward(&[2.0, -3.0], &[1.0], &[1.0]).unwrap();
        assert!(approx(bw.param_grad[0], 0.0, 1e-6));
        assert!(approx(bw.param_grad[1], 0.0, 1e-6));
        assert!(approx(bw.input_grad[0], 0.0, 1e-6));
    }

    #[test]
    fn composed_param_grads_ordered_a_then_b() {
        // Compose Linear → Linear. Param vector = [w1, b1, w2, b2].
        // Output: y = w2 * (w1 * x + b1) + b2.
        // dL/dw1 = w2 * x (with dL/dout = 1)
        // dL/db1 = w2
        // dL/dw2 = w1 * x + b1
        // dL/db2 = 1
        let c = Composed::new(LinearLayer, LinearLayer);
        let params = vec![3.0_f32, 0.5, 2.0, -1.0];
        let x = 4.0_f32;
        let bw = c.backward(&params, &[x], &[1.0]).unwrap();
        let mid = 3.0 * x + 0.5;
        assert_eq!(bw.param_grad.len(), 4);
        assert!(approx(bw.param_grad[0], 2.0 * x, 1e-5)); // dL/dw1 = w2 * x = 8
        assert!(approx(bw.param_grad[1], 2.0, 1e-6));    // dL/db1 = w2
        assert!(approx(bw.param_grad[2], mid, 1e-5));    // dL/dw2 = mid
        assert!(approx(bw.param_grad[3], 1.0, 1e-6));    // dL/db2
        assert!(approx(bw.input_grad[0], 3.0 * 2.0, 1e-5)); // dL/dx = w1 * w2
    }

    #[test]
    fn composed_rejects_wrong_param_size() {
        let c = Composed::new(LinearLayer, ReluLayer);
        let mut out = vec![0.0_f32];
        // expected 2, give 3.
        let err = c.forward(&[1.0, 2.0, 3.0], &[0.0], &mut out).unwrap_err();
        assert!(matches!(err, ParaLensError::InputLengthMismatch { expected: 2, actual: 3 }));
    }

    // ── diagnostic surface (iter 164) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            ParaLensError::InputLengthMismatch { expected: 1, actual: 2 },
            ParaLensError::OutputLengthMismatch { expected: 1, actual: 2 },
            ParaLensError::GradientLengthMismatch { expected: 1, actual: 2 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_classifiers_partition_variants() {
        let variants = [
            ParaLensError::InputLengthMismatch { expected: 1, actual: 2 },
            ParaLensError::OutputLengthMismatch { expected: 1, actual: 2 },
            ParaLensError::GradientLengthMismatch { expected: 1, actual: 2 },
        ];
        // Cross-surface invariant: exactly one of the 3 predicates is true.
        for e in variants {
            let trio = [e.is_input_mismatch(), e.is_output_mismatch(), e.is_gradient_mismatch()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn error_lengths_extracts_pair() {
        let e = ParaLensError::InputLengthMismatch { expected: 7, actual: 3 };
        assert_eq!(e.lengths(), (7, 3));
        let e = ParaLensError::OutputLengthMismatch { expected: 1, actual: 5 };
        assert_eq!(e.lengths(), (1, 5));
        let e = ParaLensError::GradientLengthMismatch { expected: 2, actual: 9 };
        assert_eq!(e.lengths(), (2, 9));
    }

    #[test]
    fn backward_grad_norms_are_nonnegative() {
        // Cross-surface invariant: L2 norms are always ≥ 0.
        let bw = ParaLensBackward {
            param_grad: vec![3.0, 4.0],
            input_grad: vec![1.0],
        };
        assert!((bw.param_grad_norm() - 5.0).abs() < 1e-6); // 3-4-5
        assert!((bw.input_grad_norm() - 1.0).abs() < 1e-6);
        assert!(bw.param_grad_norm() >= 0.0);
        assert!(bw.input_grad_norm() >= 0.0);
    }

    #[test]
    fn backward_is_zero_when_all_grads_zero() {
        let z = ParaLensBackward { param_grad: vec![0.0, 0.0], input_grad: vec![0.0] };
        assert!(z.is_zero());
        let nz = ParaLensBackward { param_grad: vec![0.0, 0.0001], input_grad: vec![0.0] };
        assert!(!nz.is_zero());
        let empty = ParaLensBackward { param_grad: vec![], input_grad: vec![] };
        assert!(empty.is_zero()); // vacuously
    }

    #[test]
    fn relu_dead_branch_backward_is_zero() {
        // Cross-surface invariant: ReluLayer in the dead branch (x ≤ 0)
        // produces a zero ParaLensBackward.
        let r = ReluLayer;
        let bw = r.backward(&[], &[-2.0], &[5.0]).unwrap();
        assert!(bw.is_zero());
        assert!((bw.input_grad_norm() - 0.0).abs() < 1e-9);
    }

    #[test]
    fn composed_dead_relu_yields_zero_backward() {
        // Cross-surface: the existing test
        // `composed_backward_zero_grad_in_inactive_relu_branch` showed
        // all gradients = 0; verify via is_zero predicate.
        let c = Composed::new(LinearLayer, ReluLayer);
        let bw = c.backward(&[2.0, -3.0], &[1.0], &[1.0]).unwrap();
        assert!(bw.is_zero());
    }

    #[test]
    fn composed_finite_difference_matches_analytic_chain() {
        // For Linear→Linear chain at multiple operating points,
        // central-difference dy/dw1 should match the analytic chain.
        let c = Composed::new(LinearLayer, LinearLayer);
        let params = vec![3.0_f32, 0.5, 2.0, -1.0];
        let x = 4.0_f32;
        let eps = 1e-3_f32;

        let mut y_base = vec![0.0_f32];
        c.forward(&params, &[x], &mut y_base).unwrap();

        // Perturb w1 (index 0).
        let mut perturbed = params.clone();
        perturbed[0] += eps;
        let mut y_pert = vec![0.0_f32];
        c.forward(&perturbed, &[x], &mut y_pert).unwrap();

        let fd = (y_pert[0] - y_base[0]) / eps;
        let bw = c.backward(&params, &[x], &[1.0]).unwrap();
        assert!(approx(fd, bw.param_grad[0], 1e-3));
    }
}
