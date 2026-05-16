//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §1-§2 (PageGather
//!   baseline + scatter). Acceptance bar: scatter throughput ≥ 70% of
//!   the STREAM-on-Metal baseline at {256 MB, 512 MB} working sets on
//!   M2 Pro 16 GB.
//! - McCalpin, J. D., "Memory bandwidth and machine balance in current
//!   high performance computers", IEEE TCCA newsletter Dec 1995 —
//!   STREAM benchmark methodology (the baseline this kernel is
//!   measured against).
//!
//! # Helios stage 1-2 — PageGather scatter (CPU reference)
//!
//! `out[i] = source[indices[i]]` for unbounded `source` (production
//! target: 256 MB - 512 MB IOSurface buffer; substrate-floor tests
//! use small Vec<f32>). The Metal variant runs on the GPU side via
//! `Epistemos/Shaders/PageGather.metal` (stub landed alongside this
//! module); production dispatch wire-in lives in Swift.
//!
//! The "scatter" half (stage 2) is the random-index variant: indices
//! are arbitrary u32s into `source`. The "gather" half (stage 1) is
//! the contiguous variant: indices are a prefix `[0, 1, 2, …]`.
//! Same kernel, different acceptance threshold (scatter must hit ≥70%
//! of STREAM since random-pattern access hurts the prefetcher).
//!
//! `gather_with_scale` adds a per-element scale lookup, useful for
//! the BitNet b1.58 absmean codec where each gathered weight tile
//! carries its own scale: `out[i] = source[indices[i]] * scales[i]`.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PageGatherStats {
    pub elements_read: usize,
    pub max_index: u32,
    pub sequential: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HeliosError {
    /// `indices[i]` was >= `source.len()`.
    IndexOutOfRange { i: usize, index: u32, source_len: usize },
    /// `out.len() != indices.len()`.
    OutLengthMismatch { indices: usize, out: usize },
    /// `scales.len() != indices.len()`.
    ScalesLengthMismatch { indices: usize, scales: usize },
}

fn validate_gather(
    source_len: usize,
    indices: &[u32],
    out_len: usize,
) -> Result<PageGatherStats, HeliosError> {
    if out_len != indices.len() {
        return Err(HeliosError::OutLengthMismatch {
            indices: indices.len(),
            out: out_len,
        });
    }
    let mut max_index: u32 = 0;
    let mut sequential = true;
    for (i, &idx) in indices.iter().enumerate() {
        if (idx as usize) >= source_len {
            return Err(HeliosError::IndexOutOfRange {
                i,
                index: idx,
                source_len,
            });
        }
        if idx > max_index {
            max_index = idx;
        }
        if (idx as usize) != i {
            sequential = false;
        }
    }
    Ok(PageGatherStats {
        elements_read: indices.len(),
        max_index,
        sequential,
    })
}

/// Gather/scatter: `out[i] = source[indices[i]]`. CPU reference for
/// the Metal kernel at `Epistemos/Shaders/PageGather.metal`. Returns
/// stats (elements read, max index, sequential-flag) so callers can
/// distinguish gather (sequential) from scatter (random) without
/// re-scanning indices.
pub fn gather(
    source: &[f32],
    indices: &[u32],
    out: &mut [f32],
) -> Result<PageGatherStats, HeliosError> {
    let stats = validate_gather(source.len(), indices, out.len())?;
    for (i, &idx) in indices.iter().enumerate() {
        out[i] = source[idx as usize];
    }
    Ok(stats)
}

/// `out[i] = source[indices[i]] * scales[i]`. Two-input variant for
/// codecs that carry per-element scale alongside packed weights
/// (e.g. BitNet b1.58 absmean tiles).
pub fn gather_with_scale(
    source: &[f32],
    indices: &[u32],
    scales: &[f32],
    out: &mut [f32],
) -> Result<PageGatherStats, HeliosError> {
    if scales.len() != indices.len() {
        return Err(HeliosError::ScalesLengthMismatch {
            indices: indices.len(),
            scales: scales.len(),
        });
    }
    let stats = validate_gather(source.len(), indices, out.len())?;
    for (i, &idx) in indices.iter().enumerate() {
        out[i] = source[idx as usize] * scales[i];
    }
    Ok(stats)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sequential_gather_returns_prefix_and_flags_sequential() {
        let src = vec![10.0_f32, 20.0, 30.0, 40.0];
        let idx: Vec<u32> = vec![0, 1, 2, 3];
        let mut out = vec![0.0_f32; 4];
        let s = gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, src);
        assert!(s.sequential);
        assert_eq!(s.max_index, 3);
        assert_eq!(s.elements_read, 4);
    }

    #[test]
    fn random_scatter_picks_correct_elements_and_flags_not_sequential() {
        let src = vec![10.0_f32, 20.0, 30.0, 40.0];
        let idx: Vec<u32> = vec![3, 0, 2];
        let mut out = vec![0.0_f32; 3];
        let s = gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, vec![40.0, 10.0, 30.0]);
        assert!(!s.sequential);
        assert_eq!(s.max_index, 3);
    }

    #[test]
    fn index_out_of_range_errors() {
        let src = vec![1.0_f32, 2.0];
        let idx: Vec<u32> = vec![5];
        let mut out = vec![0.0_f32; 1];
        let err = gather(&src, &idx, &mut out).unwrap_err();
        assert_eq!(
            err,
            HeliosError::IndexOutOfRange { i: 0, index: 5, source_len: 2 }
        );
    }

    #[test]
    fn out_length_mismatch_errors() {
        let src = vec![1.0_f32, 2.0];
        let idx: Vec<u32> = vec![0, 1];
        let mut out = vec![0.0_f32; 3];
        let err = gather(&src, &idx, &mut out).unwrap_err();
        assert_eq!(
            err,
            HeliosError::OutLengthMismatch { indices: 2, out: 3 }
        );
    }

    #[test]
    fn empty_indices_yields_empty_output_and_zero_max() {
        let src = vec![1.0_f32, 2.0];
        let idx: Vec<u32> = vec![];
        let mut out: Vec<f32> = vec![];
        let s = gather(&src, &idx, &mut out).unwrap();
        assert_eq!(s.elements_read, 0);
        assert_eq!(s.max_index, 0);
        assert!(s.sequential);
    }

    #[test]
    fn gather_with_scale_multiplies_per_element() {
        let src = vec![1.0_f32, 2.0, 3.0, 4.0];
        let idx: Vec<u32> = vec![0, 1, 2, 3];
        let scales = vec![10.0_f32, 0.5, -1.0, 0.0];
        let mut out = vec![0.0_f32; 4];
        let s = gather_with_scale(&src, &idx, &scales, &mut out).unwrap();
        assert_eq!(out, vec![10.0, 1.0, -3.0, 0.0]);
        assert!(s.sequential);
    }

    #[test]
    fn scales_length_mismatch_errors() {
        let src = vec![1.0_f32; 4];
        let idx: Vec<u32> = vec![0, 1];
        let scales = vec![1.0_f32; 3];
        let mut out = vec![0.0_f32; 2];
        let err = gather_with_scale(&src, &idx, &scales, &mut out).unwrap_err();
        assert_eq!(
            err,
            HeliosError::ScalesLengthMismatch { indices: 2, scales: 3 }
        );
    }

    #[test]
    fn gather_at_high_index_works() {
        let src: Vec<f32> = (0..1024).map(|i| i as f32).collect();
        let idx: Vec<u32> = vec![1023, 512, 0];
        let mut out = vec![0.0_f32; 3];
        gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, vec![1023.0, 512.0, 0.0]);
    }

    #[test]
    fn duplicate_indices_allowed_and_repeat_source_elements() {
        let src = vec![7.0_f32, 11.0];
        let idx: Vec<u32> = vec![0, 0, 1, 1];
        let mut out = vec![0.0_f32; 4];
        gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, vec![7.0, 7.0, 11.0, 11.0]);
    }

    #[test]
    fn stats_max_index_tracks_max_across_all_indices() {
        let src = vec![0.0_f32; 100];
        let idx: Vec<u32> = vec![5, 99, 7, 99, 3];
        let mut out = vec![0.0_f32; 5];
        let s = gather(&src, &idx, &mut out).unwrap();
        assert_eq!(s.max_index, 99);
        assert!(!s.sequential);
    }

    #[test]
    fn stats_serializes_through_serde_json() {
        let s = PageGatherStats { elements_read: 3, max_index: 99, sequential: false };
        let json = serde_json::to_string(&s).unwrap();
        let back: PageGatherStats = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn gather_overwrites_prior_out_values() {
        let src = vec![1.0_f32, 2.0];
        let idx: Vec<u32> = vec![0];
        let mut out = vec![99.0_f32];
        gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, vec![1.0]);
    }
}
