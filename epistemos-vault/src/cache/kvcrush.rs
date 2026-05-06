//! HELIOS V5 W22b — KVCrush (Vault).
//!
//! HELIOS-W22-KVCRUSH guard
//!
//! KVCrush is an experimental ternary-quantized KV-cache layer
//! that trades fidelity for memory at long context. Lane 5 Vault.

use serde::{Deserialize, Serialize};

/// Ternary KV cell: each scalar reduced to {-1, 0, +1}.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TernaryKvCell(pub i8);

impl TernaryKvCell {
    pub fn from_f32(v: f32, threshold: f32) -> Self {
        if v > threshold {
            Self(1)
        } else if v < -threshold {
            Self(-1)
        } else {
            Self(0)
        }
    }
}

/// KVCrush memory accounting.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct KvCrushFootprint {
    pub original_bytes: u64,
    pub crushed_bytes: u64,
}

impl KvCrushFootprint {
    pub fn compression_ratio(&self) -> f32 {
        if self.crushed_bytes == 0 {
            return 0.0;
        }
        self.original_bytes as f32 / self.crushed_bytes as f32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ternary_quantization_respects_threshold() {
        assert_eq!(TernaryKvCell::from_f32(0.5, 0.4).0, 1);
        assert_eq!(TernaryKvCell::from_f32(-0.5, 0.4).0, -1);
        assert_eq!(TernaryKvCell::from_f32(0.0, 0.4).0, 0);
        assert_eq!(TernaryKvCell::from_f32(0.4, 0.4).0, 0);
    }

    #[test]
    fn compression_ratio_is_original_over_crushed() {
        let f = KvCrushFootprint {
            original_bytes: 1000,
            crushed_bytes: 100,
        };
        assert!((f.compression_ratio() - 10.0).abs() < 1e-6);
    }

    #[test]
    fn compression_ratio_handles_zero_crushed_safely() {
        let f = KvCrushFootprint {
            original_bytes: 1000,
            crushed_bytes: 0,
        };
        assert_eq!(f.compression_ratio(), 0.0);
    }
}
