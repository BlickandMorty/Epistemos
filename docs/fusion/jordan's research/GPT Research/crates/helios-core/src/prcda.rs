//! Predictive residual coding and Sherry-style 3:4 sparse ternary blocks.

/// Predictor abstraction: the LM/substrate supplies decoder-side side information.
pub trait Predictor {
    fn predict(&self, residual_stream: &[f32]) -> Vec<f32>;
}

/// A deterministic residual checkpoint for L1.
#[derive(Clone, Debug, PartialEq)]
pub struct ResidualCheckpoint {
    pub token_start: u64,
    pub hidden_size: usize,
    pub packed: SherryPacked,
}

/// Packed 3:4 sparse ternary blocks. Each 4-value block stores one zero index
/// and the signs of the three nonzero entries in exactly 5 bits.
#[derive(Clone, Debug, PartialEq)]
pub struct SherryPacked {
    pub original_len: usize,
    pub scales: Vec<f32>,
    pub codes: Vec<u8>,
}

/// Sherry-style sparse ternary codec.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SherryCodec {
    pub epsilon: f32,
}

impl Default for SherryCodec {
    fn default() -> Self {
        Self { epsilon: 1.0e-6 }
    }
}

impl SherryCodec {
    /// Encode residual values into sparse ternary 3:4 groups.
    #[must_use]
    pub fn encode_residual(&self, residual: &[f32]) -> SherryPacked {
        let mut scales = Vec::new();
        let mut codes = Vec::new();
        for chunk in residual.chunks(4) {
            let mut block = [0.0_f32; 4];
            for (dst, src) in block.iter_mut().zip(chunk.iter()) {
                *dst = *src;
            }
            let zero_index = block
                .iter()
                .enumerate()
                .min_by(|a, b| a.1.abs().total_cmp(&b.1.abs()))
                .map_or(0, |(idx, _)| idx);
            let mut sign_bits = 0_u8;
            let mut sign_pos = 0_u8;
            let mut scale_acc = 0.0;
            let mut scale_count = 0.0;
            for (idx, value) in block.iter().enumerate() {
                if idx == zero_index {
                    continue;
                }
                if *value < 0.0 {
                    sign_bits |= 1 << sign_pos;
                }
                sign_pos += 1;
                scale_acc += value.abs();
                scale_count += 1.0;
            }
            let scale = (scale_acc / scale_count).max(self.epsilon);
            scales.push(scale);
            codes.push(((zero_index as u8) << 3) | (sign_bits & 0b111));
        }
        SherryPacked { original_len: residual.len(), scales, codes }
    }

    /// Decode sparse ternary residual values.
    #[must_use]
    pub fn decode_residual(&self, packed: &SherryPacked) -> Vec<f32> {
        let mut out = Vec::with_capacity(packed.codes.len() * 4);
        for (code, scale) in packed.codes.iter().zip(packed.scales.iter()) {
            let zero_index = usize::from(code >> 3);
            let mut sign_pos = 0_u8;
            for idx in 0..4 {
                if idx == zero_index {
                    out.push(0.0);
                } else {
                    let is_negative = ((*code >> sign_pos) & 1) == 1;
                    out.push(if is_negative { -*scale } else { *scale });
                    sign_pos += 1;
                }
            }
        }
        out.truncate(packed.original_len);
        out
    }

    /// Build an L1 checkpoint from raw residual values.
    #[must_use]
    pub fn checkpoint(&self, token_start: u64, hidden_size: usize, residual: &[f32]) -> ResidualCheckpoint {
        ResidualCheckpoint { token_start, hidden_size, packed: self.encode_residual(residual) }
    }
}

/// Compute surprise = actual - predicted elementwise.
#[must_use]
pub fn compute_surprise(predicted: &[f32], actual: &[f32]) -> Vec<f32> {
    assert_eq!(predicted.len(), actual.len(), "surprise dimension mismatch");
    predicted.iter().zip(actual.iter()).map(|(p, a)| a - p).collect()
}

#[cfg(test)]
mod tests {
    use super::{compute_surprise, SherryCodec};

    #[test]
    fn surprise_is_actual_minus_predicted() {
        assert_eq!(compute_surprise(&[1.0, 2.0], &[3.0, 1.0]), vec![2.0, -1.0]);
    }

    #[test]
    fn sherry_codec_uses_one_code_per_four_values() {
        let codec = SherryCodec::default();
        let packed = codec.encode_residual(&[0.1, -0.2, 0.8, -0.7, 1.0]);
        assert_eq!(packed.codes.len(), 2);
        assert_eq!(codec.decode_residual(&packed).len(), 5);
    }

    #[test]
    fn sherry_code_is_five_bits() {
        let codec = SherryCodec::default();
        let packed = codec.encode_residual(&[1.0, -2.0, 0.01, 4.0]);
        assert!(packed.codes[0] < 32);
    }
}
