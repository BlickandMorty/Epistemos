//! Source:
//! - Charisopoulos, Maragos arXiv:1805.08749 §3 — the explicit
//!   ReLU-to-(max,+) compilation procedure.
//! - Zhang, Naitzat, Lim arXiv:1805.07091 Thm 5.4 — every feedforward
//!   ReLU network with rational weights computes a tropical rational
//!   map.
//! - Doctrine §4.2 — first lowering target for Tropical-IR.
//! - Phase B1 close-out §7 — iter-21 plan entry.
//! - Companion: [`super::grammar`] (TropicalExpr the compile emits);
//!   [`super::evaluator`] (the property test cross-checks bytes-equal
//!   between the compiled TropicalExpr and a direct ReLU evaluator).
//!
//! # ReLU-to-Tropical compilation (binary-weights MVP)
//!
//! A single ReLU layer applies `y = max(0, W·x + b)` element-wise.
//! The MVP here handles **binary weights `w ∈ {0, 1}`** so each
//! `w_{ij} * x_j` is either omitted or contributes `x_j` directly
//! to the affine sum — no scalar-multiplication primitive needed
//! in the AST.
//!
//! Per-output expression for layer `(W, b)` at output `i`:
//!
//! ```text
//! y_i = max(0, Σ_{j : W[i][j] == 1} x_j + b_i)
//!     = TropicalExpr::Max([
//!           TropicalExpr::Const(0.0),
//!           <chain of TropicalExpr::Plus collapsing Var(j) leaves
//!            plus a Const(b_i)>
//!       ])
//! ```
//!
//! ## Gap from full Zhang/Naitzat/Lim equivalence
//!
//! Thm 5.4 requires rational weights, which need a
//! scalar-multiplication primitive `Scale(s, Box<TropicalExpr>)`
//! (or equivalent encoding via repeated Plus). This MVP intentionally
//! restricts to binary weights to land a useful slice without
//! extending the AST grammar; the general-weight extension is
//! Phase C scope per the close-out §7.

use super::grammar::TropicalExpr;

// ── iter-62 Phase C extension: general-weight ReLU compile ────────

/// A ReLU layer with arbitrary real-valued weights and biases.
/// Parallel to [`BinaryReluLayer`] (iter-21 binary-only MVP) but
/// supports the full Zhang/Naitzat/Lim Thm 5.4 case via the
/// [`TropicalExpr::Scale`] primitive (iter-61).
#[derive(Clone, Debug, PartialEq)]
pub struct RealReluLayer {
    pub weights: Vec<Vec<f64>>,
    pub biases: Vec<f64>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum RealReluLayerError {
    NonRectangular { expected_cols: usize, actual_cols: usize, row: usize },
    BiasShapeMismatch { expected: usize, actual: usize },
    NonFiniteWeight { row: usize, col: usize, value: f64 },
    NonFiniteBias { row: usize, value: f64 },
}

impl RealReluLayer {
    pub fn new(
        weights: Vec<Vec<f64>>,
        biases: Vec<f64>,
    ) -> Result<Self, RealReluLayerError> {
        if biases.len() != weights.len() {
            return Err(RealReluLayerError::BiasShapeMismatch {
                expected: weights.len(),
                actual: biases.len(),
            });
        }
        let expected_cols = weights.first().map(|r| r.len()).unwrap_or(0);
        for (row_idx, row) in weights.iter().enumerate() {
            if row.len() != expected_cols {
                return Err(RealReluLayerError::NonRectangular {
                    expected_cols,
                    actual_cols: row.len(),
                    row: row_idx,
                });
            }
            for (col_idx, &w) in row.iter().enumerate() {
                if !w.is_finite() {
                    return Err(RealReluLayerError::NonFiniteWeight {
                        row: row_idx,
                        col: col_idx,
                        value: w,
                    });
                }
            }
        }
        for (row, &b) in biases.iter().enumerate() {
            if !b.is_finite() {
                return Err(RealReluLayerError::NonFiniteBias { row, value: b });
            }
        }
        Ok(RealReluLayer { weights, biases })
    }

    pub fn output_dim(&self) -> usize {
        self.weights.len()
    }
    pub fn input_dim(&self) -> usize {
        self.weights.first().map(|r| r.len()).unwrap_or(0)
    }
}

/// Compile a real-weight ReLU layer to a vector of TropicalExpr
/// trees (one per output neuron). Each output `i` evaluates to
/// `max(0, Σ_j w_{ij}·x_j + b_i)` as a TropicalExpr using
/// `Scale(w_ij, Var(j))` for the weighted inputs.
pub fn compile_real_relu_layer(layer: &RealReluLayer) -> Vec<TropicalExpr> {
    let mut out = Vec::with_capacity(layer.output_dim());
    for (i, row) in layer.weights.iter().enumerate() {
        let bias = layer.biases[i];
        // Collect Scale(w_{ij}, Var(j)) for non-zero weights; skip zero
        // weights as a small structural optimization (they'd contribute 0
        // to the sum anyway).
        let mut affine_parts: Vec<TropicalExpr> = row
            .iter()
            .enumerate()
            .filter_map(|(j, &w)| {
                if w == 0.0 {
                    None
                } else {
                    Some(TropicalExpr::scale(w, TropicalExpr::var(j)))
                }
            })
            .collect();
        affine_parts.push(TropicalExpr::constant(bias));
        let affine = fold_plus(affine_parts);
        out.push(TropicalExpr::max(vec![
            TropicalExpr::constant(0.0),
            affine,
        ]));
    }
    out
}

/// Direct real-weight ReLU evaluator — the property-test oracle for
/// [`compile_real_relu_layer`].
pub fn evaluate_real_relu_layer_directly(
    layer: &RealReluLayer,
    valuation: &[f64],
) -> Vec<f64> {
    let mut out = Vec::with_capacity(layer.output_dim());
    for (i, row) in layer.weights.iter().enumerate() {
        let mut sum = layer.biases[i];
        for (j, &w) in row.iter().enumerate() {
            sum += w * valuation.get(j).copied().unwrap_or(0.0);
        }
        out.push(if sum > 0.0 { sum } else { 0.0 });
    }
    out
}

/// A single ReLU layer with binary weights and real biases.
///
/// `weights[i][j]` MUST be `0` or `1`. Other values are accepted by
/// the constructor but will trigger a panic from
/// [`Self::validate_binary_weights`] (called eagerly by
/// [`compile_relu_layer`]).
#[derive(Clone, Debug, PartialEq)]
pub struct BinaryReluLayer {
    pub weights: Vec<Vec<u8>>,
    pub biases: Vec<f64>,
}

/// Error returned when a layer fails validation.
#[derive(Clone, Debug, PartialEq)]
pub enum BinaryReluLayerError {
    /// Weight matrix is not rectangular.
    NonRectangular { expected_cols: usize, actual_cols: usize, row: usize },
    /// A weight cell is not 0 or 1.
    NonBinaryWeight { row: usize, col: usize, value: u8 },
    /// Bias vector length doesn't match the weight matrix rows.
    BiasShapeMismatch { expected: usize, actual: usize },
}

impl BinaryReluLayer {
    /// Construct + validate. Returns the layer or a shape error.
    pub fn new(
        weights: Vec<Vec<u8>>,
        biases: Vec<f64>,
    ) -> Result<Self, BinaryReluLayerError> {
        if biases.len() != weights.len() {
            return Err(BinaryReluLayerError::BiasShapeMismatch {
                expected: weights.len(),
                actual: biases.len(),
            });
        }
        let expected_cols = weights.first().map(|r| r.len()).unwrap_or(0);
        for (row_idx, row) in weights.iter().enumerate() {
            if row.len() != expected_cols {
                return Err(BinaryReluLayerError::NonRectangular {
                    expected_cols,
                    actual_cols: row.len(),
                    row: row_idx,
                });
            }
            for (col_idx, &w) in row.iter().enumerate() {
                if w > 1 {
                    return Err(BinaryReluLayerError::NonBinaryWeight {
                        row: row_idx,
                        col: col_idx,
                        value: w,
                    });
                }
            }
        }
        Ok(BinaryReluLayer { weights, biases })
    }

    /// Number of output neurons (= weight matrix row count).
    pub fn output_dim(&self) -> usize {
        self.weights.len()
    }

    /// Number of input variables (= weight matrix column count).
    pub fn input_dim(&self) -> usize {
        self.weights.first().map(|r| r.len()).unwrap_or(0)
    }
}

/// Compile a binary-weight ReLU layer to a vector of TropicalExpr
/// trees (one per output neuron).
///
/// `compile_relu_layer(layer)[i]` represents `y_i = max(0, Σ_j W[i][j]·x_j + b_i)`
/// as a TropicalExpr. Evaluating the i-th tree with input valuation
/// `x` yields the i-th ReLU output exactly (binary weights →
/// no rounding).
pub fn compile_relu_layer(layer: &BinaryReluLayer) -> Vec<TropicalExpr> {
    let mut out = Vec::with_capacity(layer.output_dim());
    for (i, row) in layer.weights.iter().enumerate() {
        // Build the affine sum: Σ_j x_j (for j with W[i][j]=1) + b_i.
        let bias = layer.biases[i];
        let mut affine_parts: Vec<TropicalExpr> = row
            .iter()
            .enumerate()
            .filter_map(|(j, &w)| {
                if w == 1 {
                    Some(TropicalExpr::var(j))
                } else {
                    None
                }
            })
            .collect();
        affine_parts.push(TropicalExpr::constant(bias));
        let affine = fold_plus(affine_parts);
        out.push(TropicalExpr::max(vec![
            TropicalExpr::constant(0.0),
            affine,
        ]));
    }
    out
}

/// Internal: fold a vector of TropicalExpr into a single left-leaning
/// chain of `Plus(Plus(Plus(a, b), c), …)`. Returns `Const(0.0)` for
/// an empty input (the additive identity).
fn fold_plus(parts: Vec<TropicalExpr>) -> TropicalExpr {
    let mut iter = parts.into_iter();
    let mut acc = match iter.next() {
        Some(first) => first,
        None => return TropicalExpr::constant(0.0),
    };
    for next in iter {
        acc = TropicalExpr::plus(acc, next);
    }
    acc
}

/// Direct ReLU evaluation (the reference oracle the property test
/// compares the compiled TropicalExpr against). Operates on the
/// same `BinaryReluLayer` + valuation that
/// [`compile_relu_layer`] consumes.
pub fn evaluate_relu_layer_directly(
    layer: &BinaryReluLayer,
    valuation: &[f64],
) -> Vec<f64> {
    let mut out = Vec::with_capacity(layer.output_dim());
    for (i, row) in layer.weights.iter().enumerate() {
        let mut sum = layer.biases[i];
        for (j, &w) in row.iter().enumerate() {
            if w == 1 {
                sum += valuation.get(j).copied().unwrap_or(0.0);
            }
        }
        out.push(if sum > 0.0 { sum } else { 0.0 });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::tropical_ir::evaluator::evaluate;

    fn layer(weights: Vec<Vec<u8>>, biases: Vec<f64>) -> BinaryReluLayer {
        BinaryReluLayer::new(weights, biases).unwrap()
    }

    #[test]
    fn compile_one_neuron_one_input_identity() {
        // Output = max(0, 1 * x_0 + 0) = max(0, x_0)
        let l = layer(vec![vec![1]], vec![0.0]);
        let trees = compile_relu_layer(&l);
        assert_eq!(trees.len(), 1);
        // Evaluate at x_0 = 3.5 → 3.5.
        assert_eq!(evaluate(&trees[0], &[3.5]).unwrap(), 3.5);
        // Evaluate at x_0 = -2.0 → 0.0.
        assert_eq!(evaluate(&trees[0], &[-2.0]).unwrap(), 0.0);
    }

    #[test]
    fn compile_one_neuron_one_input_with_bias() {
        // Output = max(0, x_0 + 0.5)
        let l = layer(vec![vec![1]], vec![0.5]);
        let trees = compile_relu_layer(&l);
        assert_eq!(evaluate(&trees[0], &[3.5]).unwrap(), 4.0);
        assert_eq!(evaluate(&trees[0], &[-1.0]).unwrap(), 0.0);
        assert_eq!(evaluate(&trees[0], &[-0.5]).unwrap(), 0.0);
        assert_eq!(evaluate(&trees[0], &[-0.25]).unwrap(), 0.25);
    }

    #[test]
    fn compile_two_input_or_gate_via_relu_with_bias() {
        // Output = max(0, x_0 + x_1 - 0.5)
        // We can't express negative bias in MVP... wait yes we can,
        // it's a Const not a weight. Bias can be any f64.
        let l = layer(vec![vec![1, 1]], vec![-0.5]);
        let trees = compile_relu_layer(&l);
        // x_0 + x_1 - 0.5; for x=(0,0): -0.5 → 0; (0.5,0.5): 0.5 → 0.5; (1,1): 1.5 → 1.5.
        assert_eq!(evaluate(&trees[0], &[0.0, 0.0]).unwrap(), 0.0);
        assert_eq!(evaluate(&trees[0], &[0.5, 0.5]).unwrap(), 0.5);
        assert_eq!(evaluate(&trees[0], &[1.0, 1.0]).unwrap(), 1.5);
    }

    #[test]
    fn compile_multi_output_layer() {
        // 2 inputs, 3 outputs:
        // y_0 = max(0, x_0 + 1)
        // y_1 = max(0, x_1 - 1)
        // y_2 = max(0, x_0 + x_1)
        let l = layer(
            vec![vec![1, 0], vec![0, 1], vec![1, 1]],
            vec![1.0, -1.0, 0.0],
        );
        let trees = compile_relu_layer(&l);
        assert_eq!(trees.len(), 3);
        let v = vec![2.0, 0.5];
        assert_eq!(evaluate(&trees[0], &v).unwrap(), 3.0);
        assert_eq!(evaluate(&trees[1], &v).unwrap(), 0.0);
        assert_eq!(evaluate(&trees[2], &v).unwrap(), 2.5);
    }

    #[test]
    fn compile_byte_equal_to_direct_relu_evaluator() {
        // §4.I:891 acceptance: small ReLU network compiles
        // byte-equal output on a fixture corpus.
        let l = layer(
            vec![vec![1, 1, 0], vec![0, 1, 1], vec![1, 0, 1]],
            vec![0.5, -0.25, 0.0],
        );
        let trees = compile_relu_layer(&l);
        let fixtures: Vec<Vec<f64>> = vec![
            vec![0.0, 0.0, 0.0],
            vec![1.0, 1.0, 1.0],
            vec![-1.0, 2.0, 3.0],
            vec![2.5, -3.5, 0.0],
            vec![100.0, -50.0, 25.0],
        ];
        for x in &fixtures {
            let direct = evaluate_relu_layer_directly(&l, x);
            let compiled: Vec<f64> = trees
                .iter()
                .map(|t| evaluate(t, x).unwrap())
                .collect();
            assert_eq!(
                direct.to_bits_vec(),
                compiled.to_bits_vec(),
                "input {:?} direct={:?} compiled={:?}",
                x, direct, compiled
            );
        }
    }

    /// Helper: compare f64 vectors as bit patterns (avoids
    /// `assert_eq!` quirks with NaN/0.0/-0.0).
    trait ToBitsVec {
        fn to_bits_vec(&self) -> Vec<u64>;
    }
    impl ToBitsVec for Vec<f64> {
        fn to_bits_vec(&self) -> Vec<u64> {
            self.iter().map(|x| x.to_bits()).collect()
        }
    }

    #[test]
    fn new_rejects_non_binary_weight() {
        let err = BinaryReluLayer::new(vec![vec![1, 2]], vec![0.0]).unwrap_err();
        match err {
            BinaryReluLayerError::NonBinaryWeight { row: 0, col: 1, value: 2 } => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }

    #[test]
    fn new_rejects_non_rectangular_weights() {
        let err = BinaryReluLayer::new(
            vec![vec![1, 0], vec![1]],
            vec![0.0, 0.0],
        )
        .unwrap_err();
        assert!(matches!(
            err,
            BinaryReluLayerError::NonRectangular { .. }
        ));
    }

    #[test]
    fn new_rejects_bias_shape_mismatch() {
        let err = BinaryReluLayer::new(vec![vec![1, 0]], vec![0.0, 1.0])
            .unwrap_err();
        assert_eq!(
            err,
            BinaryReluLayerError::BiasShapeMismatch {
                expected: 1,
                actual: 2,
            }
        );
    }

    #[test]
    fn output_dim_input_dim_match_weight_shape() {
        let l = layer(vec![vec![1, 0, 1], vec![0, 1, 0]], vec![0.0, 0.0]);
        assert_eq!(l.output_dim(), 2);
        assert_eq!(l.input_dim(), 3);
    }

    #[test]
    fn empty_layer_compiles_to_empty_vec() {
        let l = layer(vec![], vec![]);
        let trees = compile_relu_layer(&l);
        assert!(trees.is_empty());
    }

    #[test]
    fn fold_plus_empty_yields_zero_const() {
        let e = fold_plus(vec![]);
        assert_eq!(e, TropicalExpr::constant(0.0));
    }

    #[test]
    fn fold_plus_single_element_yields_that_element() {
        let e = fold_plus(vec![TropicalExpr::var(2)]);
        assert_eq!(e, TropicalExpr::var(2));
    }

    #[test]
    fn fold_plus_chains_left() {
        // [a, b, c] → Plus(Plus(a, b), c)
        let e = fold_plus(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::constant(2.0),
            TropicalExpr::constant(3.0),
        ]);
        match e {
            TropicalExpr::Plus(l, r) => {
                assert_eq!(*r, TropicalExpr::constant(3.0));
                match *l {
                    TropicalExpr::Plus(ll, lr) => {
                        assert_eq!(*ll, TropicalExpr::constant(1.0));
                        assert_eq!(*lr, TropicalExpr::constant(2.0));
                    }
                    other => panic!("expected nested Plus, got {:?}", other),
                }
            }
            other => panic!("expected Plus, got {:?}", other),
        }
    }

    // ── RealReluLayer + compile_real_relu_layer (iter-62) ─────────

    fn real_layer(weights: Vec<Vec<f64>>, biases: Vec<f64>) -> RealReluLayer {
        RealReluLayer::new(weights, biases).unwrap()
    }

    #[test]
    fn real_layer_validates_shape() {
        let l = real_layer(vec![vec![1.5, -0.5]], vec![0.25]);
        assert_eq!(l.input_dim(), 2);
        assert_eq!(l.output_dim(), 1);
    }

    #[test]
    fn real_layer_rejects_bias_mismatch() {
        let err =
            RealReluLayer::new(vec![vec![1.0]], vec![0.0, 0.0]).unwrap_err();
        assert_eq!(
            err,
            RealReluLayerError::BiasShapeMismatch {
                expected: 1,
                actual: 2,
            }
        );
    }

    #[test]
    fn real_layer_rejects_nan_weight() {
        let err = RealReluLayer::new(vec![vec![f64::NAN]], vec![0.0]).unwrap_err();
        assert!(matches!(err, RealReluLayerError::NonFiniteWeight { .. }));
    }

    #[test]
    fn compile_real_single_neuron_identity() {
        // y = max(0, 1.0 * x_0). At x=2 → 2; at x=-1 → 0.
        let l = real_layer(vec![vec![1.0]], vec![0.0]);
        let trees = compile_real_relu_layer(&l);
        assert_eq!(
            evaluate(&trees[0], &[2.0]).unwrap(),
            2.0
        );
        assert_eq!(
            evaluate(&trees[0], &[-1.0]).unwrap(),
            0.0
        );
    }

    #[test]
    fn compile_real_with_fractional_weights() {
        // y = max(0, 0.5 * x_0 + 0.25 * x_1 + 1.0)
        let l = real_layer(vec![vec![0.5, 0.25]], vec![1.0]);
        let trees = compile_real_relu_layer(&l);
        // x = (2, 4) → 0.5*2 + 0.25*4 + 1 = 1 + 1 + 1 = 3.
        assert_eq!(evaluate(&trees[0], &[2.0, 4.0]).unwrap(), 3.0);
        // x = (-3, 0) → -1.5 + 0 + 1 = -0.5 → max(0, -0.5) = 0.
        assert_eq!(evaluate(&trees[0], &[-3.0, 0.0]).unwrap(), 0.0);
    }

    #[test]
    fn compile_real_with_negative_weights() {
        // y = max(0, -2 * x_0 + 3 * x_1 - 0.5)
        let l = real_layer(vec![vec![-2.0, 3.0]], vec![-0.5]);
        let trees = compile_real_relu_layer(&l);
        // x = (1, 2) → -2 + 6 - 0.5 = 3.5.
        assert_eq!(evaluate(&trees[0], &[1.0, 2.0]).unwrap(), 3.5);
        // x = (2, 0) → -4 + 0 - 0.5 = -4.5 → 0.
        assert_eq!(evaluate(&trees[0], &[2.0, 0.0]).unwrap(), 0.0);
    }

    #[test]
    fn compile_real_byte_equal_to_direct_evaluator() {
        // §4.I:907 acceptance for general weights (Zhang/Naitzat/Lim
        // Thm 5.4): byte-equal output on a fixture.
        let l = real_layer(
            vec![
                vec![0.5, -0.25, 1.5],
                vec![-1.0, 2.0, 0.25],
                vec![3.0, 0.5, -0.75],
            ],
            vec![0.1, -0.3, 0.0],
        );
        let trees = compile_real_relu_layer(&l);
        let fixtures: Vec<Vec<f64>> = vec![
            vec![0.0, 0.0, 0.0],
            vec![1.0, 1.0, 1.0],
            vec![-1.0, 2.0, 3.0],
            vec![2.5, -3.5, 0.5],
            vec![100.0, -50.0, 25.0],
        ];
        for x in &fixtures {
            let direct = evaluate_real_relu_layer_directly(&l, x);
            let compiled: Vec<f64> = trees
                .iter()
                .map(|t| evaluate(t, x).unwrap())
                .collect();
            // Compare as bit patterns (handles 0 vs -0 and NaN strictly).
            let d_bits: Vec<u64> = direct.iter().map(|v| v.to_bits()).collect();
            let c_bits: Vec<u64> = compiled.iter().map(|v| v.to_bits()).collect();
            assert_eq!(
                d_bits, c_bits,
                "input {:?} direct={:?} compiled={:?}",
                x, direct, compiled
            );
        }
    }

    #[test]
    fn compile_real_zero_weights_are_skipped() {
        // Zero weights contribute 0 to the sum; the compiled tree
        // should still produce the correct output.
        let l = real_layer(vec![vec![0.0, 1.5, 0.0, -2.0]], vec![0.5]);
        let trees = compile_real_relu_layer(&l);
        // y = max(0, 1.5 * x_1 - 2 * x_3 + 0.5) at x=(99, 4, 99, 1)
        // = max(0, 6 - 2 + 0.5) = 4.5.
        assert_eq!(
            evaluate(&trees[0], &[99.0, 4.0, 99.0, 1.0]).unwrap(),
            4.5
        );
    }

    #[test]
    fn compile_real_negative_pre_activation_clamps_to_zero() {
        let l = real_layer(vec![vec![1.0]], vec![-100.0]);
        let trees = compile_real_relu_layer(&l);
        // y = max(0, x_0 - 100). At x=0 → 0.
        assert_eq!(evaluate(&trees[0], &[0.0]).unwrap(), 0.0);
    }

    #[test]
    fn compile_real_zero_input_with_bias() {
        let l = real_layer(vec![vec![3.0]], vec![2.5]);
        let trees = compile_real_relu_layer(&l);
        // y = max(0, 0 + 2.5) = 2.5.
        assert_eq!(evaluate(&trees[0], &[0.0]).unwrap(), 2.5);
    }
}
