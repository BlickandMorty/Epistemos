use std::collections::HashSet;

use agent_core::lattice::{
    babai_nearest_plane, dequantize, quantize_to_lattice, CholeskyBasis, E8Codebook, LatticeError,
    LatticeFamily, LeechCodebook,
};
use agent_core::wbo6::{Wbo6Budget, Wbo6Term};

fn scaled_key<const N: usize>(vector: &[f32; N]) -> Vec<i16> {
    vector
        .iter()
        .map(|value| (value * 2.0).round() as i16)
        .collect()
}

fn squared_norm<const N: usize>(vector: &[f32; N]) -> f32 {
    vector.iter().map(|value| value * value).sum()
}

#[test]
fn e8_norm2_shell_has_240_unique_vectors() {
    let vectors = E8Codebook.norm2_vectors();
    let unique: HashSet<_> = vectors.iter().map(scaled_key).collect();

    assert_eq!(vectors.len(), E8Codebook::NORM2_COUNT);
    assert_eq!(unique.len(), E8Codebook::NORM2_COUNT);
    assert!(vectors
        .iter()
        .all(|vector| (squared_norm(vector) - 2.0).abs() < 1.0e-6));
}

#[test]
fn e8_norm4_shell_has_2160_unique_vectors() {
    let vectors = E8Codebook.norm4_vectors();
    let unique: HashSet<_> = vectors.iter().map(scaled_key).collect();

    assert_eq!(vectors.len(), E8Codebook::NORM4_COUNT);
    assert_eq!(unique.len(), E8Codebook::NORM4_COUNT);
    assert!(vectors
        .iter()
        .all(|vector| (squared_norm(vector) - 4.0).abs() < 1.0e-6));
}

#[test]
fn e8_nearest_norm2_selects_closest_root() {
    let mut target = [0.0_f32; E8Codebook::DIM];
    target[0] = 1.1;
    target[1] = 0.9;

    let nearest = E8Codebook.nearest_norm2(&target).unwrap();

    assert_eq!(nearest[0], 1.0);
    assert_eq!(nearest[1], 1.0);
    assert!(nearest[2..].iter().all(|value| *value == 0.0));
}

#[test]
fn leech_codebook_keeps_full_shell_as_metadata_only() {
    assert_eq!(LeechCodebook.norm4_count(), LeechCodebook::NORM4_COUNT);
    assert_eq!(LeechCodebook.sample_norm4(0).len(), 0);

    let sample = LeechCodebook.sample_norm4(16);

    assert_eq!(sample.len(), 16);
    assert!(sample
        .iter()
        .all(|vector| (squared_norm(vector) - 4.0).abs() < 1.0e-5));
}

#[test]
fn babai_rounds_identity_basis_without_panics() {
    let basis = CholeskyBasis::new(vec![vec![1.0, 0.0], vec![0.0, 1.0]]).unwrap();

    assert_eq!(
        babai_nearest_plane(&[1.2, -1.7], &basis).unwrap(),
        vec![1, -2]
    );
}

#[test]
fn babai_handles_lower_triangular_dependencies_forward() {
    let basis = CholeskyBasis::new(vec![vec![2.0, 0.0], vec![1.0, 3.0]]).unwrap();

    assert_eq!(
        babai_nearest_plane(&[4.0, 2.0], &basis).unwrap(),
        vec![2, 0]
    );
}

#[test]
fn babai_rejects_invalid_basis_and_dimension_mismatch() {
    assert_eq!(
        CholeskyBasis::new(vec![vec![1.0, 1.0], vec![0.0, 1.0]]),
        Err(LatticeError::InvalidBasis)
    );

    let basis = CholeskyBasis::new(vec![vec![1.0, 0.0], vec![0.0, 1.0]]).unwrap();
    assert_eq!(
        babai_nearest_plane(&[1.0], &basis),
        Err(LatticeError::DimensionMismatch {
            expected: 2,
            actual: 1
        })
    );
}

#[test]
fn scalar_quantizer_round_trips_shape_and_finite_residual() {
    let vector = [0.125, -0.5, 0.875, 0.0, 0.25, -0.75, 1.0, -1.0];

    let quantized = quantize_to_lattice(&vector, LatticeFamily::E8).unwrap();
    let reconstructed = dequantize(&quantized).unwrap();

    assert_eq!(quantized.indices.len(), E8Codebook::DIM);
    assert_eq!(reconstructed.len(), E8Codebook::DIM);
    assert!(quantized.residual_norm.is_finite());
    assert!(quantized.residual_norm >= 0.0);
}

#[test]
fn scalar_quantizer_rejects_wrong_family_dimension_and_nan() {
    assert_eq!(
        quantize_to_lattice(&[1.0, 2.0], LatticeFamily::E8),
        Err(LatticeError::DimensionMismatch {
            expected: E8Codebook::DIM,
            actual: 2
        })
    );
    assert_eq!(
        quantize_to_lattice(&[f32::NAN], LatticeFamily::Cubic),
        Err(LatticeError::InvalidValue)
    );
}

#[test]
fn quantization_budget_terms_consume_only_t_q() {
    let quantized = quantize_to_lattice(&[0.25, -0.5, 0.75], LatticeFamily::Cubic).unwrap();
    let terms = quantized.quantization_budget_terms().unwrap();

    for term in agent_core::wbo6::Wbo6Term::ALL {
        if term == Wbo6Term::Quantization {
            assert_eq!(terms.get(term), f64::from(quantized.residual_norm));
        } else {
            assert_eq!(terms.get(term), 0.0);
        }
    }
}

#[test]
fn quantization_budget_evaluates_measured_drift() {
    let quantized = quantize_to_lattice(&[1.0, 0.5, -0.25], LatticeFamily::Cubic).unwrap();
    let terms = quantized.quantization_budget_terms().unwrap();
    let evaluation = Wbo6Budget::new(terms)
        .with_tolerance(1.0e-9)
        .unwrap()
        .evaluate(0.0)
        .unwrap();

    assert!(evaluation.passed);
    assert!(evaluation.bound >= 0.0);
}
