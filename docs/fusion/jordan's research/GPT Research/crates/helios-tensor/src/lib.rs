//! Deterministic CPU tensor primitives used as Metal golden references.

/// In-place Fast Walsh-Hadamard Transform. Length must be a power of two.
pub fn fwht_inplace(values: &mut [f32]) {
    assert!(values.len().is_power_of_two(), "FWHT length must be power of two");
    let mut h = 1;
    while h < values.len() {
        for i in (0..values.len()).step_by(h * 2) {
            for j in i..(i + h) {
                let x = values[j];
                let y = values[j + h];
                values[j] = x + y;
                values[j + h] = x - y;
            }
        }
        h *= 2;
    }
}

/// Numerically stable softmax.
#[must_use]
pub fn softmax(logits: &[f32]) -> Vec<f32> {
    let max = logits.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let exps: Vec<f32> = logits.iter().map(|v| (*v - max).exp()).collect();
    let sum: f32 = exps.iter().sum();
    exps.into_iter().map(|v| v / sum).collect()
}

/// eml primitive.
#[must_use]
pub fn eml(x: f32, y: f32) -> f32 {
    x.exp() - y.max(1.0e-12).ln()
}

/// KL divergence for logits through softmax.
#[must_use]
pub fn kl_from_logits(reference: &[f32], candidate: &[f32]) -> f32 {
    let p = softmax(reference);
    let q = softmax(candidate);
    p.iter().zip(q.iter()).map(|(a, b)| a * (a / b.max(1.0e-12)).ln()).sum()
}

#[cfg(test)]
mod tests {
    use super::{eml, fwht_inplace, kl_from_logits, softmax};

    #[test]
    fn fwht_known_vector() {
        let mut v = [1.0, 2.0, 3.0, 4.0];
        fwht_inplace(&mut v);
        assert_eq!(v, [10.0, -2.0, -4.0, 0.0]);
    }

    #[test]
    fn softmax_sums_to_one() {
        let s: f32 = softmax(&[1.0, 2.0, 3.0]).iter().sum();
        assert!((s - 1.0).abs() < 1.0e-6);
    }

    #[test]
    fn identical_logits_have_zero_kl() {
        assert!(kl_from_logits(&[1.0, 2.0], &[1.0, 2.0]) < 1.0e-6);
    }

    #[test]
    fn eml_matches_definition() {
        assert!((eml(1.0, 2.0) - (1.0_f32.exp() - 2.0_f32.ln())).abs() < 1.0e-6);
    }
}
