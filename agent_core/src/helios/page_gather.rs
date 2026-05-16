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

impl PageGatherStats {
    /// Total bytes read from source given a per-element size.
    /// Substrate-floor input to STREAM-comparable bandwidth
    /// estimates: divide by elapsed seconds to get GB/s.
    /// f32 elements use `element_size = 4`; f16 = 2; u32 = 4.
    pub fn bytes_read(&self, element_size: usize) -> usize {
        self.elements_read * element_size
    }

    /// Fraction of source the gather touched: `(max_index + 1) /
    /// source_len`. Returns `None` if `source_len == 0`. A value
    /// near 1.0 means the gather sweeps the whole source (random
    /// access across the entire working set — the scatter
    /// acceptance bar case); near 0 means a small contiguous window.
    pub fn source_coverage(&self, source_len: usize) -> Option<f32> {
        if source_len == 0 {
            return None;
        }
        let touched = (self.max_index as usize).saturating_add(1);
        Some(touched as f32 / source_len as f32)
    }
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

    // ── bytes_read + source_coverage tests (iter 122) ───────────────────────

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn bytes_read_f32_is_four_per_element() {
        let s = PageGatherStats { elements_read: 100, max_index: 99, sequential: true };
        assert_eq!(s.bytes_read(4), 400);
    }

    #[test]
    fn bytes_read_f16_is_two_per_element() {
        let s = PageGatherStats { elements_read: 100, max_index: 99, sequential: true };
        assert_eq!(s.bytes_read(2), 200);
    }

    #[test]
    fn bytes_read_zero_elements_is_zero() {
        let s = PageGatherStats { elements_read: 0, max_index: 0, sequential: true };
        assert_eq!(s.bytes_read(4), 0);
    }

    #[test]
    fn bytes_read_stream_baseline_512mb_check() {
        // STREAM-comparable: 512 MB working set at f32 = 128M elements.
        // bytes_read(4) for 128M = 512 MB exactly.
        let s = PageGatherStats {
            elements_read: 128 * 1024 * 1024,
            max_index: 128 * 1024 * 1024 - 1,
            sequential: true,
        };
        assert_eq!(s.bytes_read(4), 512 * 1024 * 1024);
    }

    #[test]
    fn source_coverage_full_sweep_returns_one() {
        // gather over the whole source [0..len-1] → max_index = len-1
        // → coverage = len/len = 1.0.
        let s = PageGatherStats { elements_read: 100, max_index: 99, sequential: true };
        assert!(approx(s.source_coverage(100).unwrap(), 1.0, 1e-6));
    }

    #[test]
    fn source_coverage_window_quarter_returns_quarter() {
        // gather first 25 of 100 → max_index = 24 → coverage = 25/100 = 0.25.
        let s = PageGatherStats { elements_read: 25, max_index: 24, sequential: true };
        assert!(approx(s.source_coverage(100).unwrap(), 0.25, 1e-6));
    }

    #[test]
    fn source_coverage_empty_source_returns_none() {
        let s = PageGatherStats { elements_read: 0, max_index: 0, sequential: true };
        assert!(s.source_coverage(0).is_none());
    }

    #[test]
    fn source_coverage_single_element_at_end_still_full_coverage() {
        // gather one element at the last index → max_index = len-1
        // → coverage = 1.0 even though only 1 element gathered. This
        // is the design point: source_coverage measures the WORKING
        // SET TOUCHED, not the elements_read.
        let s = PageGatherStats { elements_read: 1, max_index: 99, sequential: false };
        assert!(approx(s.source_coverage(100).unwrap(), 1.0, 1e-6));
    }
}
