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

/// Backward result: gradients flow to both the parameter and the input.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ParaLensBackward {
    pub param_grad: Vec<f32>,
    pub input_grad: Vec<f32>,
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
}
