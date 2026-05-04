//! Quantization helpers for Helios.

pub use helios_core::{SherryCodec, SherryPacked};

/// NF4-like scalar quantizer with a fixed symmetric codebook.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Nf4Codec {
    pub scale: f32,
}

impl Default for Nf4Codec {
    fn default() -> Self {
        Self { scale: 1.0 }
    }
}

impl Nf4Codec {
    const CODEBOOK: [f32; 16] = [-1.0, -0.696, -0.525, -0.394, -0.284, -0.184, -0.091, 0.0, 0.079, 0.161, 0.246, 0.337, 0.440, 0.562, 0.723, 1.0];

    #[must_use]
    pub fn encode(self, values: &[f32]) -> Vec<u8> {
        let mut codes = Vec::with_capacity(values.len());
        for value in values {
            let normalized = (*value / self.scale).clamp(-1.0, 1.0);
            let mut best = 0_u8;
            let mut best_err = f32::INFINITY;
            for (idx, code) in Self::CODEBOOK.iter().enumerate() {
                let err = (normalized - *code).abs();
                if err < best_err {
                    best_err = err;
                    best = idx as u8;
                }
            }
            codes.push(best);
        }
        codes
    }

    #[must_use]
    pub fn decode(self, codes: &[u8]) -> Vec<f32> {
        codes.iter().map(|c| Self::CODEBOOK[usize::from(*c & 0x0f)] * self.scale).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::Nf4Codec;

    #[test]
    fn nf4_roundtrips_shape() {
        let codec = Nf4Codec { scale: 2.0 };
        let codes = codec.encode(&[-2.0, 0.0, 1.0]);
        assert_eq!(codec.decode(&codes).len(), 3);
    }
}
