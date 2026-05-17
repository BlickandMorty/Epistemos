//! `HeliosPage` — the three-stage shadow-first paging type.
//!
//! Per F-ShadowFirst-PageEscalation falsifier §2:
//!
//! | Stage | Bit-width | Storage | Read cost |
//! |---|---|---|---|
//! | **Sketch** | INT8 (1 byte/elem) | RAM hot working set | always read |
//! | **Residual** | INT8 + per-block scale | RAM warm pool | promoted if sketch score ≥ residual_threshold |
//! | **Exact** | bf16 / fp16 / fp32 | SSD cold | exact-decode if residual margin ≤ exact_threshold |
//!
//! Substrate-floor: all three tiers live in-memory. Production
//! (Phase B.G.B5 / Phase C):
//! - Sketch lives in RAM hot (always-read).
//! - Residual lives in RAM warm pool (eviction-aware).
//! - Exact lives on SSD as mmap'd file region.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::uas::UasAddress;

/// One residual block — `data` is INT8 quantized; `scale` is the
/// fp32 multiplier that recovers approximate float values
/// (`block_data[i] as f32 * block.scale`).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResidualBlock {
    /// INT8 quantized residual values. Length = `block_size` per the
    /// codec; mismatch surfaces `HeliosPageError::BadResidualBlock`.
    pub data: Vec<i8>,
    /// Per-block fp32 scale to dequantize.
    pub scale: f32,
}

/// Exact-tier page handle — pointer to a mmap'd region on SSD.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExactPageHandle {
    /// Path to the backing file. Substrate-floor uses any path; production
    /// expects `/<App Group container>/.epcache/pages/<sha>.bin`.
    pub file_path: PathBuf,
    /// Byte offset within the file (page-aligned in production).
    pub byte_offset: u64,
    /// Byte length of the exact-decoded payload.
    pub byte_length: u64,
    /// Codec the exact data is stored in.
    pub codec: ExactCodec,
}

/// Codec for exact-tier storage.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExactCodec {
    /// bfloat16. 2 bytes per element. Apple Silicon-native.
    Bf16,
    /// IEEE fp16. 2 bytes per element.
    Fp16,
    /// IEEE fp32. 4 bytes per element. Highest precision; only for
    /// reference checks.
    Fp32,
}

impl ExactCodec {
    pub const fn bytes_per_element(self) -> usize {
        match self {
            ExactCodec::Bf16 | ExactCodec::Fp16 => 2,
            ExactCodec::Fp32 => 4,
        }
    }

    pub const fn wire_tag(self) -> &'static str {
        match self {
            ExactCodec::Bf16 => "bf16",
            ExactCodec::Fp16 => "fp16",
            ExactCodec::Fp32 => "fp32",
        }
    }
}

/// Three-stage page representation.
///
/// `sketch` is always present (RAM hot); `residual` and `exact_handle`
/// are optional — pages can live as sketch-only (cheapest case) and
/// promote to residual or exact only when escalation policy demands it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HeliosPage {
    /// UAS address — identity independent of where the page currently
    /// lives.
    pub address: UasAddress,
    /// INT8 sketch (RAM hot). Length is page-size-dependent; production
    /// typical is 64-256 INT8 elements per page.
    pub sketch: Vec<i8>,
    /// Residual blocks (RAM warm). `None` if not yet promoted.
    pub residual: Option<Vec<ResidualBlock>>,
    /// Exact-tier handle (SSD cold). `None` if not yet promoted OR if
    /// the page is sketch-only.
    pub exact_handle: Option<ExactPageHandle>,
}

/// Error surface for HeliosPage construction + escalation.
#[derive(Clone, Debug, PartialEq)]
pub enum HeliosPageError {
    EmptySketch,
    BadResidualBlock { expected_size: usize, actual_size: usize },
    ExactHandleMismatchedCodec { handle_codec: ExactCodec, requested: ExactCodec },
}

impl HeliosPage {
    /// Construct a sketch-only page.
    pub fn sketch_only(address: UasAddress, sketch: Vec<i8>) -> Result<Self, HeliosPageError> {
        if sketch.is_empty() {
            return Err(HeliosPageError::EmptySketch);
        }
        Ok(Self {
            address,
            sketch,
            residual: None,
            exact_handle: None,
        })
    }

    /// Promote to include a residual.
    pub fn with_residual(
        mut self,
        residual: Vec<ResidualBlock>,
        block_size: usize,
    ) -> Result<Self, HeliosPageError> {
        for block in &residual {
            if block.data.len() != block_size {
                return Err(HeliosPageError::BadResidualBlock {
                    expected_size: block_size,
                    actual_size: block.data.len(),
                });
            }
        }
        self.residual = Some(residual);
        Ok(self)
    }

    /// Promote to include an exact-tier handle.
    pub fn with_exact_handle(mut self, handle: ExactPageHandle) -> Self {
        self.exact_handle = Some(handle);
        self
    }

    /// Returns the residency tier this page currently occupies:
    /// 1 → sketch-only · 2 → sketch + residual · 3 → all three tiers.
    pub fn tier_depth(&self) -> u8 {
        if self.exact_handle.is_some() {
            3
        } else if self.residual.is_some() {
            2
        } else {
            1
        }
    }

    /// Returns `true` if this page has a residual tier promoted.
    pub fn has_residual(&self) -> bool {
        self.residual.is_some()
    }

    /// Returns `true` if this page has an exact handle.
    pub fn has_exact(&self) -> bool {
        self.exact_handle.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::UasKind;

    fn sample_address() -> UasAddress {
        UasAddress::new(UasKind::KvPage, b"helios-page-test", 0)
    }

    #[test]
    fn sketch_only_page_starts_at_tier_1() {
        let p = HeliosPage::sketch_only(sample_address(), vec![1, 2, 3]).unwrap();
        assert_eq!(p.tier_depth(), 1);
        assert!(!p.has_residual());
        assert!(!p.has_exact());
    }

    #[test]
    fn empty_sketch_errors() {
        let err = HeliosPage::sketch_only(sample_address(), vec![]).unwrap_err();
        assert_eq!(err, HeliosPageError::EmptySketch);
    }

    #[test]
    fn promote_to_residual_tier_2() {
        let p = HeliosPage::sketch_only(sample_address(), vec![1, 2, 3, 4])
            .unwrap()
            .with_residual(
                vec![
                    ResidualBlock { data: vec![10, 20], scale: 0.5 },
                    ResidualBlock { data: vec![30, 40], scale: 0.25 },
                ],
                2,
            )
            .unwrap();
        assert_eq!(p.tier_depth(), 2);
        assert!(p.has_residual());
        assert!(!p.has_exact());
    }

    #[test]
    fn bad_residual_block_size_errors() {
        let err = HeliosPage::sketch_only(sample_address(), vec![1, 2])
            .unwrap()
            .with_residual(
                vec![ResidualBlock { data: vec![1, 2, 3], scale: 1.0 }],
                2,
            )
            .unwrap_err();
        assert_eq!(
            err,
            HeliosPageError::BadResidualBlock { expected_size: 2, actual_size: 3 }
        );
    }

    #[test]
    fn promote_to_exact_tier_3() {
        let handle = ExactPageHandle {
            file_path: PathBuf::from("/tmp/exact.bin"),
            byte_offset: 0,
            byte_length: 1024,
            codec: ExactCodec::Bf16,
        };
        let p = HeliosPage::sketch_only(sample_address(), vec![1])
            .unwrap()
            .with_exact_handle(handle);
        assert_eq!(p.tier_depth(), 3);
        assert!(p.has_exact());
        assert!(!p.has_residual()); // exact without residual = still tier_depth 3
    }

    #[test]
    fn codec_byte_widths() {
        assert_eq!(ExactCodec::Bf16.bytes_per_element(), 2);
        assert_eq!(ExactCodec::Fp16.bytes_per_element(), 2);
        assert_eq!(ExactCodec::Fp32.bytes_per_element(), 4);
    }

    #[test]
    fn codec_wire_tags_locked() {
        assert_eq!(ExactCodec::Bf16.wire_tag(), "bf16");
        assert_eq!(ExactCodec::Fp16.wire_tag(), "fp16");
        assert_eq!(ExactCodec::Fp32.wire_tag(), "fp32");
    }

    #[test]
    fn serde_round_trip_helios_page() {
        let p = HeliosPage::sketch_only(sample_address(), vec![1, 2, 3])
            .unwrap()
            .with_residual(vec![ResidualBlock { data: vec![10, 20], scale: 0.5 }], 2)
            .unwrap();
        let json = serde_json::to_string(&p).expect("serialize must succeed");
        let parsed: HeliosPage = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(p, parsed);
    }
}
