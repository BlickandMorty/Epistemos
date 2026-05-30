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
//! Same kernel, different acceptance threshold. The 2026-05-27 M2 Pro
//! witness shows a full Fisher-Yates permutation is a failure stressor
//! (~6% of STREAM), not a product-green access pattern. Promotion now
//! requires a locality-aware gather schedule or equivalent mitigation
//! before the Metal path can satisfy the ≥70% STREAM gate.
//!
//! `gather_with_scale` adds a per-element scale lookup, useful for
//! the BitNet b1.58 absmean codec where each gathered weight tile
//! carries its own scale: `out[i] = source[indices[i]] * scales[i]`.

use serde::{Deserialize, Serialize};

pub const DEFAULT_PAGE_GATHER_BLOCK_ELEMENTS: usize = 8_192;

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PageGatherStats {
    pub elements_read: usize,
    pub max_index: u32,
    pub sequential: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum PageGatherAccessClass {
    Empty,
    Sequential,
    LocalWindow,
    BlockSorted,
    SparseScatter,
    FullCoverageRandom,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum PageGatherScheduleClass {
    AsSubmitted,
    BlockSorted,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PageGatherSchedulePlan {
    pub schedule_class: PageGatherScheduleClass,
    pub block_elements: usize,
    pub execution_indices: Vec<u32>,
    pub logical_positions: Vec<u32>,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PageGatherPacket {
    pub logical_position: u32,
    pub value: f32,
}

impl PageGatherSchedulePlan {
    pub fn len(&self) -> usize {
        self.execution_indices.len()
    }

    pub fn is_empty(&self) -> bool {
        self.execution_indices.is_empty()
    }

    pub fn access_class(&self) -> PageGatherAccessClass {
        match self.schedule_class {
            PageGatherScheduleClass::AsSubmitted => PageGatherAccessClass::SparseScatter,
            PageGatherScheduleClass::BlockSorted => PageGatherAccessClass::BlockSorted,
        }
    }
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

    /// Classify the measured access pattern so callers do not confuse
    /// a correctness stressor with a PageGather-promotable layout.
    ///
    /// `FullCoverageRandom` is the 2026-05-27 failed Metal witness:
    /// correct output, broad Fisher-Yates-like source coverage, and
    /// far below the ≥70% STREAM target until the caller introduces a
    /// locality-aware schedule.
    pub fn access_class(&self, source_len: usize) -> Option<PageGatherAccessClass> {
        if self.elements_read == 0 {
            return Some(PageGatherAccessClass::Empty);
        }
        if self.sequential {
            return Some(PageGatherAccessClass::Sequential);
        }

        let coverage = self.source_coverage(source_len)?;
        let density = self.elements_read as f32 / source_len as f32;
        if coverage <= 0.25 {
            Some(PageGatherAccessClass::LocalWindow)
        } else if coverage >= 0.80 && density >= 0.80 {
            Some(PageGatherAccessClass::FullCoverageRandom)
        } else {
            Some(PageGatherAccessClass::SparseScatter)
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HeliosError {
    /// `indices[i]` was >= `source.len()`.
    IndexOutOfRange {
        i: usize,
        index: u32,
        source_len: usize,
    },
    /// `out.len() != indices.len()`.
    OutLengthMismatch { indices: usize, out: usize },
    /// `scales.len() != indices.len()`.
    ScalesLengthMismatch { indices: usize, scales: usize },
    /// Block-sorted scheduling requires a non-zero block size.
    BlockElementsZero,
    /// Schedule logical-position storage is u32-backed for Metal parity.
    IndexCountTooLarge { indices: usize },
    /// Scheduled values did not match the plan length.
    ScheduleLengthMismatch { schedule: usize, values: usize },
    /// A schedule or packet stream reused the same logical position twice.
    DuplicateLogicalPosition {
        logical_position: u32,
        first_slot: usize,
        duplicate_slot: usize,
    },
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

/// Build a locality-aware execution plan for PageGather.
///
/// The plan preserves caller-visible logical order through
/// `logical_positions`, while ordering `execution_indices` by source
/// block. The Metal path can execute the localized walk, then scatter
/// results back through the logical positions. This is the scheduler-side
/// contract proven promising by `locality_probe_result.json`; it is not
/// by itself a primary F-PageGather-M2Pro pass.
pub fn block_sorted_schedule(
    indices: &[u32],
    source_len: usize,
    block_elements: usize,
) -> Result<PageGatherSchedulePlan, HeliosError> {
    if block_elements == 0 {
        return Err(HeliosError::BlockElementsZero);
    }
    if indices.len() > u32::MAX as usize {
        return Err(HeliosError::IndexCountTooLarge {
            indices: indices.len(),
        });
    }

    let mut entries: Vec<(u32, u32, u32)> = Vec::with_capacity(indices.len());
    for (logical_position, &index) in indices.iter().enumerate() {
        if (index as usize) >= source_len {
            return Err(HeliosError::IndexOutOfRange {
                i: logical_position,
                index,
                source_len,
            });
        }
        let block = (index as usize / block_elements) as u32;
        entries.push((block, index, logical_position as u32));
    }
    entries
        .sort_unstable_by_key(|&(block, index, logical_position)| (block, index, logical_position));

    let mut execution_indices = Vec::with_capacity(entries.len());
    let mut logical_positions = Vec::with_capacity(entries.len());
    for (_block, index, logical_position) in entries {
        execution_indices.push(index);
        logical_positions.push(logical_position);
    }

    Ok(PageGatherSchedulePlan {
        schedule_class: PageGatherScheduleClass::BlockSorted,
        block_elements,
        execution_indices,
        logical_positions,
    })
}

/// Execute a precomputed PageGather schedule and write results in
/// caller-visible logical order.
pub fn gather_scheduled(
    source: &[f32],
    plan: &PageGatherSchedulePlan,
    out: &mut [f32],
) -> Result<PageGatherStats, HeliosError> {
    if out.len() != plan.len() {
        return Err(HeliosError::OutLengthMismatch {
            indices: plan.len(),
            out: out.len(),
        });
    }
    if plan.execution_indices.len() != plan.logical_positions.len() {
        return Err(HeliosError::ScheduleLengthMismatch {
            schedule: plan.execution_indices.len(),
            values: plan.logical_positions.len(),
        });
    }

    let mut max_index = 0_u32;
    let mut sequential = matches!(plan.schedule_class, PageGatherScheduleClass::AsSubmitted);
    for (execution_slot, &index) in plan.execution_indices.iter().enumerate() {
        if (index as usize) >= source.len() {
            return Err(HeliosError::IndexOutOfRange {
                i: execution_slot,
                index,
                source_len: source.len(),
            });
        }
        let logical_position = plan.logical_positions[execution_slot] as usize;
        if logical_position >= out.len() {
            return Err(HeliosError::OutLengthMismatch {
                indices: plan.len(),
                out: logical_position + 1,
            });
        }
        if index > max_index {
            max_index = index;
        }
        if index as usize != logical_position {
            sequential = false;
        }
        out[logical_position] = source[index as usize];
    }

    Ok(PageGatherStats {
        elements_read: plan.len(),
        max_index,
        sequential,
    })
}

/// Execute a PageGather schedule as a compact packet stream instead of
/// restoring dense logical order immediately.
///
/// This mirrors `pageGatherPacketizeScheduled` in Metal:
/// `packets[i] = (logical_positions[i], source[execution_indices[i]])`.
/// Callers that can consume witness-coordinate packets avoid the random
/// destination writes that made dense scheduled restore the current
/// `F-PageGather-M2Pro` bottleneck.
pub fn gather_packetized(
    source: &[f32],
    plan: &PageGatherSchedulePlan,
) -> Result<(Vec<PageGatherPacket>, PageGatherStats), HeliosError> {
    if plan.execution_indices.len() != plan.logical_positions.len() {
        return Err(HeliosError::ScheduleLengthMismatch {
            schedule: plan.execution_indices.len(),
            values: plan.logical_positions.len(),
        });
    }

    let mut first_slot_by_logical_position: Vec<Option<usize>> = vec![None; plan.len()];
    let mut packets = Vec::with_capacity(plan.len());
    let mut max_index = 0_u32;
    let mut sequential = matches!(plan.schedule_class, PageGatherScheduleClass::AsSubmitted);

    for (execution_slot, &index) in plan.execution_indices.iter().enumerate() {
        if (index as usize) >= source.len() {
            return Err(HeliosError::IndexOutOfRange {
                i: execution_slot,
                index,
                source_len: source.len(),
            });
        }

        let logical_position = plan.logical_positions[execution_slot];
        let logical_index = logical_position as usize;
        if logical_index >= plan.len() {
            return Err(HeliosError::OutLengthMismatch {
                indices: plan.len(),
                out: logical_index + 1,
            });
        }
        if let Some(first_slot) = first_slot_by_logical_position[logical_index] {
            return Err(HeliosError::DuplicateLogicalPosition {
                logical_position,
                first_slot,
                duplicate_slot: execution_slot,
            });
        }
        first_slot_by_logical_position[logical_index] = Some(execution_slot);

        if index > max_index {
            max_index = index;
        }
        if index as usize != logical_index {
            sequential = false;
        }
        packets.push(PageGatherPacket {
            logical_position,
            value: source[index as usize],
        });
    }

    Ok((
        packets,
        PageGatherStats {
            elements_read: plan.len(),
            max_index,
            sequential,
        },
    ))
}

/// Restore a packetized PageGather stream into dense caller-visible order.
///
/// This is intentionally a separate step so product paths can remain
/// packetized through retrieval, ranking, and witness rendering, then pay
/// dense projection only at surfaces that truly require it.
pub fn restore_packets(packets: &[PageGatherPacket], out: &mut [f32]) -> Result<(), HeliosError> {
    if out.len() != packets.len() {
        return Err(HeliosError::OutLengthMismatch {
            indices: packets.len(),
            out: out.len(),
        });
    }

    let mut first_slot_by_logical_position: Vec<Option<usize>> = vec![None; out.len()];
    for (slot, packet) in packets.iter().enumerate() {
        let logical_index = packet.logical_position as usize;
        if logical_index >= out.len() {
            return Err(HeliosError::OutLengthMismatch {
                indices: packets.len(),
                out: logical_index + 1,
            });
        }
        if let Some(first_slot) = first_slot_by_logical_position[logical_index] {
            return Err(HeliosError::DuplicateLogicalPosition {
                logical_position: packet.logical_position,
                first_slot,
                duplicate_slot: slot,
            });
        }
        first_slot_by_logical_position[logical_index] = Some(slot);
        out[logical_index] = packet.value;
    }

    Ok(())
}

/// Convenience wrapper for the product-candidate schedule measured by
/// the 2026-05-27 locality probe.
pub fn gather_block_sorted(
    source: &[f32],
    indices: &[u32],
    block_elements: usize,
    out: &mut [f32],
) -> Result<(PageGatherSchedulePlan, PageGatherStats), HeliosError> {
    if out.len() != indices.len() {
        return Err(HeliosError::OutLengthMismatch {
            indices: indices.len(),
            out: out.len(),
        });
    }
    let plan = block_sorted_schedule(indices, source.len(), block_elements)?;
    let stats = gather_scheduled(source, &plan, out)?;
    Ok((plan, stats))
}

/// Convenience wrapper for the packetized product-candidate schedule measured
/// by the 2026-05-27 locality probe.
pub fn gather_block_sorted_packetized(
    source: &[f32],
    indices: &[u32],
    block_elements: usize,
) -> Result<
    (
        PageGatherSchedulePlan,
        Vec<PageGatherPacket>,
        PageGatherStats,
    ),
    HeliosError,
> {
    let plan = block_sorted_schedule(indices, source.len(), block_elements)?;
    let (packets, stats) = gather_packetized(source, &plan)?;
    Ok((plan, packets, stats))
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
            HeliosError::IndexOutOfRange {
                i: 0,
                index: 5,
                source_len: 2
            }
        );
    }

    #[test]
    fn out_length_mismatch_errors() {
        let src = vec![1.0_f32, 2.0];
        let idx: Vec<u32> = vec![0, 1];
        let mut out = vec![0.0_f32; 3];
        let err = gather(&src, &idx, &mut out).unwrap_err();
        assert_eq!(err, HeliosError::OutLengthMismatch { indices: 2, out: 3 });
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
            HeliosError::ScalesLengthMismatch {
                indices: 2,
                scales: 3
            }
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
        let s = PageGatherStats {
            elements_read: 3,
            max_index: 99,
            sequential: false,
        };
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
        let s = PageGatherStats {
            elements_read: 100,
            max_index: 99,
            sequential: true,
        };
        assert_eq!(s.bytes_read(4), 400);
    }

    #[test]
    fn bytes_read_f16_is_two_per_element() {
        let s = PageGatherStats {
            elements_read: 100,
            max_index: 99,
            sequential: true,
        };
        assert_eq!(s.bytes_read(2), 200);
    }

    #[test]
    fn bytes_read_zero_elements_is_zero() {
        let s = PageGatherStats {
            elements_read: 0,
            max_index: 0,
            sequential: true,
        };
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
        let s = PageGatherStats {
            elements_read: 100,
            max_index: 99,
            sequential: true,
        };
        assert!(approx(s.source_coverage(100).unwrap(), 1.0, 1e-6));
    }

    #[test]
    fn source_coverage_window_quarter_returns_quarter() {
        // gather first 25 of 100 → max_index = 24 → coverage = 25/100 = 0.25.
        let s = PageGatherStats {
            elements_read: 25,
            max_index: 24,
            sequential: true,
        };
        assert!(approx(s.source_coverage(100).unwrap(), 0.25, 1e-6));
    }

    #[test]
    fn source_coverage_empty_source_returns_none() {
        let s = PageGatherStats {
            elements_read: 0,
            max_index: 0,
            sequential: true,
        };
        assert!(s.source_coverage(0).is_none());
    }

    #[test]
    fn source_coverage_single_element_at_end_still_full_coverage() {
        // gather one element at the last index → max_index = len-1
        // → coverage = 1.0 even though only 1 element gathered. This
        // is the design point: source_coverage measures the WORKING
        // SET TOUCHED, not the elements_read.
        let s = PageGatherStats {
            elements_read: 1,
            max_index: 99,
            sequential: false,
        };
        assert!(approx(s.source_coverage(100).unwrap(), 1.0, 1e-6));
    }

    #[test]
    fn access_class_separates_sequential_from_failed_random_stressor() {
        let sequential = PageGatherStats {
            elements_read: 100,
            max_index: 99,
            sequential: true,
        };
        assert_eq!(
            sequential.access_class(100),
            Some(PageGatherAccessClass::Sequential)
        );

        let random_full = PageGatherStats {
            elements_read: 100,
            max_index: 99,
            sequential: false,
        };
        assert_eq!(
            random_full.access_class(100),
            Some(PageGatherAccessClass::FullCoverageRandom)
        );
    }

    #[test]
    fn access_class_keeps_local_window_and_sparse_scatter_distinct() {
        let local = PageGatherStats {
            elements_read: 16,
            max_index: 23,
            sequential: false,
        };
        assert_eq!(
            local.access_class(100),
            Some(PageGatherAccessClass::LocalWindow)
        );

        let sparse = PageGatherStats {
            elements_read: 1,
            max_index: 99,
            sequential: false,
        };
        assert_eq!(
            sparse.access_class(100),
            Some(PageGatherAccessClass::SparseScatter)
        );
    }

    #[test]
    fn block_sorted_schedule_groups_by_source_block() {
        let idx: Vec<u32> = vec![7, 0, 3, 6, 1, 4, 2, 5];
        let plan = block_sorted_schedule(&idx, 8, 2).unwrap();
        assert_eq!(plan.schedule_class, PageGatherScheduleClass::BlockSorted);
        assert_eq!(plan.block_elements, 2);
        assert_eq!(plan.access_class(), PageGatherAccessClass::BlockSorted);
        assert_eq!(plan.execution_indices, vec![0, 1, 2, 3, 4, 5, 6, 7]);
        assert_eq!(plan.logical_positions, vec![1, 4, 6, 2, 5, 7, 3, 0]);
    }

    #[test]
    fn gather_block_sorted_preserves_logical_output() {
        let src: Vec<f32> = (0..8).map(|i| i as f32 * 10.0).collect();
        let idx: Vec<u32> = vec![7, 0, 3, 6, 1, 4, 2, 5];
        let mut scheduled_out = vec![0.0_f32; idx.len()];
        let (plan, stats) = gather_block_sorted(&src, &idx, 2, &mut scheduled_out).unwrap();

        let expected: Vec<f32> = idx.iter().map(|&index| src[index as usize]).collect();
        assert_eq!(scheduled_out, expected);
        assert_eq!(plan.execution_indices, vec![0, 1, 2, 3, 4, 5, 6, 7]);
        assert_eq!(stats.elements_read, idx.len());
        assert_eq!(stats.max_index, 7);
        assert!(!stats.sequential);
    }

    #[test]
    fn packetized_block_sorted_preserves_source_local_order_and_witness_positions() {
        let src: Vec<f32> = (0..8).map(|i| i as f32 * 10.0).collect();
        let idx: Vec<u32> = vec![7, 0, 3, 6, 1, 4, 2, 5];

        let (plan, packets, stats) = gather_block_sorted_packetized(&src, &idx, 2).unwrap();

        assert_eq!(plan.execution_indices, vec![0, 1, 2, 3, 4, 5, 6, 7]);
        assert_eq!(plan.logical_positions, vec![1, 4, 6, 2, 5, 7, 3, 0]);
        assert_eq!(
            packets,
            vec![
                PageGatherPacket {
                    logical_position: 1,
                    value: 0.0
                },
                PageGatherPacket {
                    logical_position: 4,
                    value: 10.0
                },
                PageGatherPacket {
                    logical_position: 6,
                    value: 20.0
                },
                PageGatherPacket {
                    logical_position: 2,
                    value: 30.0
                },
                PageGatherPacket {
                    logical_position: 5,
                    value: 40.0
                },
                PageGatherPacket {
                    logical_position: 7,
                    value: 50.0
                },
                PageGatherPacket {
                    logical_position: 3,
                    value: 60.0
                },
                PageGatherPacket {
                    logical_position: 0,
                    value: 70.0
                },
            ]
        );
        assert_eq!(stats.elements_read, idx.len());
        assert_eq!(stats.max_index, 7);
        assert!(!stats.sequential);
    }

    #[test]
    fn restore_packets_reconstructs_dense_logical_order() {
        let src: Vec<f32> = (0..8).map(|i| i as f32 * 10.0).collect();
        let idx: Vec<u32> = vec![7, 0, 3, 6, 1, 4, 2, 5];
        let (_plan, packets, _stats) = gather_block_sorted_packetized(&src, &idx, 2).unwrap();

        let mut restored = vec![0.0_f32; packets.len()];
        restore_packets(&packets, &mut restored).unwrap();

        let expected: Vec<f32> = idx.iter().map(|&index| src[index as usize]).collect();
        assert_eq!(restored, expected);
    }

    #[test]
    fn packetized_gather_rejects_duplicate_logical_positions() {
        let src: Vec<f32> = (0..4).map(|i| i as f32).collect();
        let plan = PageGatherSchedulePlan {
            schedule_class: PageGatherScheduleClass::BlockSorted,
            block_elements: 2,
            execution_indices: vec![0, 1],
            logical_positions: vec![0, 0],
        };

        let err = gather_packetized(&src, &plan).unwrap_err();

        assert_eq!(
            err,
            HeliosError::DuplicateLogicalPosition {
                logical_position: 0,
                first_slot: 0,
                duplicate_slot: 1
            }
        );
    }

    #[test]
    fn restore_packets_rejects_duplicate_logical_positions() {
        let packets = vec![
            PageGatherPacket {
                logical_position: 0,
                value: 1.0,
            },
            PageGatherPacket {
                logical_position: 0,
                value: 2.0,
            },
        ];
        let mut out = vec![0.0_f32; 2];

        let err = restore_packets(&packets, &mut out).unwrap_err();

        assert_eq!(
            err,
            HeliosError::DuplicateLogicalPosition {
                logical_position: 0,
                first_slot: 0,
                duplicate_slot: 1
            }
        );
    }

    #[test]
    fn restore_packets_rejects_out_of_range_logical_position() {
        let packets = vec![PageGatherPacket {
            logical_position: 2,
            value: 1.0,
        }];
        let mut out = vec![0.0_f32; 1];

        let err = restore_packets(&packets, &mut out).unwrap_err();

        assert_eq!(err, HeliosError::OutLengthMismatch { indices: 1, out: 3 });
    }

    #[test]
    fn packetized_gather_rejects_bad_source_index() {
        let src: Vec<f32> = vec![0.0, 1.0];
        let plan = PageGatherSchedulePlan {
            schedule_class: PageGatherScheduleClass::BlockSorted,
            block_elements: 2,
            execution_indices: vec![0, 2],
            logical_positions: vec![0, 1],
        };

        let err = gather_packetized(&src, &plan).unwrap_err();

        assert_eq!(
            err,
            HeliosError::IndexOutOfRange {
                i: 1,
                index: 2,
                source_len: 2
            }
        );
    }

    #[test]
    fn block_sorted_schedule_rejects_zero_block_size() {
        let err = block_sorted_schedule(&[0, 1], 2, 0).unwrap_err();
        assert_eq!(err, HeliosError::BlockElementsZero);
    }

    #[test]
    fn block_sorted_schedule_rejects_bad_source_index() {
        let err = block_sorted_schedule(&[0, 8], 8, 2).unwrap_err();
        assert_eq!(
            err,
            HeliosError::IndexOutOfRange {
                i: 1,
                index: 8,
                source_len: 8
            }
        );
    }

    #[test]
    fn scheduled_gather_detects_corrupt_plan_lengths() {
        let src: Vec<f32> = (0..4).map(|i| i as f32).collect();
        let mut out = vec![0.0_f32; 2];
        let plan = PageGatherSchedulePlan {
            schedule_class: PageGatherScheduleClass::BlockSorted,
            block_elements: 2,
            execution_indices: vec![0, 1],
            logical_positions: vec![0],
        };
        let err = gather_scheduled(&src, &plan, &mut out).unwrap_err();
        assert_eq!(
            err,
            HeliosError::ScheduleLengthMismatch {
                schedule: 2,
                values: 1
            }
        );
    }

    #[test]
    fn as_submitted_schedule_reports_actual_sequentiality() {
        let src: Vec<f32> = (0..4).map(|i| i as f32).collect();
        let mut out = vec![0.0_f32; 4];
        let plan = PageGatherSchedulePlan {
            schedule_class: PageGatherScheduleClass::AsSubmitted,
            block_elements: 0,
            execution_indices: vec![0, 2, 1, 3],
            logical_positions: vec![0, 1, 2, 3],
        };

        let stats = gather_scheduled(&src, &plan, &mut out).unwrap();

        assert_eq!(out, vec![0.0, 2.0, 1.0, 3.0]);
        assert!(!stats.sequential);
    }
}
