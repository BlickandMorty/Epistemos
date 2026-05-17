//! `sketch_topk` — INT8 sketch dot-product + top-K over a HeliosPage corpus.
//!
//! Per F-ShadowFirst-PageEscalation falsifier §2:
//! - Stage 1 of the three-stage escalation policy.
//! - INT8 dot-product on Metal hardware in production; CPU scalar
//!   reference here.
//! - Output: top-K indices + i32 scores, caller-allocated.
//!
//! Substrate-floor: CPU scalar implementation; production wires this
//! into `Epistemos/Shaders/PageGather.metal` for the Metal scatter
//! kernel that scores sketches in parallel.

use crate::research::page_gather::helios_page::HeliosPage;

/// Error surface for sketch-topk.
#[derive(Clone, Debug, PartialEq)]
pub enum SketchTopKError {
    /// Query sketch length mismatched the corpus pages' sketch length.
    SketchLengthMismatch { expected: usize, got: usize },
    /// Output buffer was empty (k = 0); no top-K to compute.
    EmptyOutputBuffer,
}

/// Compute top-K HeliosPage indices by INT8-sketch inner product.
///
/// - `query`: query sketch (INT8). All pages in `corpus` must have a
///   sketch of identical length.
/// - `corpus`: candidate pages.
/// - `output`: caller-allocated `[(page_index, score)]` buffer of
///   length K. Pre-initialized to `(0, i32::MIN)` is a fine starting
///   state; the function overwrites in-place.
///
/// Zero allocations on hot path; zero copies of any sketch or score.
pub fn sketch_top_k(
    query: &[i8],
    corpus: &[HeliosPage],
    output: &mut [(usize, i32)],
) -> Result<(), SketchTopKError> {
    if output.is_empty() {
        return Err(SketchTopKError::EmptyOutputBuffer);
    }
    let expected_len = query.len();

    // Initialize output to all (0, MIN) so the first comparison always
    // overwrites.
    for slot in output.iter_mut() {
        *slot = (0, i32::MIN);
    }

    for (page_idx, page) in corpus.iter().enumerate() {
        if page.sketch.len() != expected_len {
            return Err(SketchTopKError::SketchLengthMismatch {
                expected: expected_len,
                got: page.sketch.len(),
            });
        }
        let score = int8_inner_product(query, &page.sketch);

        // Find the slot with the smallest score.
        let mut min_idx = 0;
        let mut min_score = output[0].1;
        for (i, slot) in output.iter().enumerate().skip(1) {
            if slot.1 < min_score {
                min_idx = i;
                min_score = slot.1;
            }
        }

        if score > min_score {
            output[min_idx] = (page_idx, score);
        }
    }

    Ok(())
}

/// Scalar INT8 inner product: `Σ (a[i] as i32) * (b[i] as i32)`.
///
/// Substrate-floor reference. Production uses Metal's INT8 SIMD GEMV
/// (per F-PageGather-M2Pro Metal kernel) for ~70% of MEASURED M2 Pro
/// STREAM throughput on 256/512/1024 MB working sets.
#[inline]
pub fn int8_inner_product(a: &[i8], b: &[i8]) -> i32 {
    debug_assert_eq!(a.len(), b.len());
    let mut acc = 0_i32;
    for (x, y) in a.iter().zip(b.iter()) {
        acc += (*x as i32) * (*y as i32);
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{UasAddress, UasKind};

    fn page(seed: u64, sketch: Vec<i8>) -> HeliosPage {
        let address = UasAddress::new(UasKind::KvPage, &seed.to_le_bytes(), 0);
        HeliosPage::sketch_only(address, sketch).unwrap()
    }

    #[test]
    fn inner_product_correctness() {
        assert_eq!(int8_inner_product(&[1, 2, 3], &[4, 5, 6]), 4 + 10 + 18);
        assert_eq!(int8_inner_product(&[127, 127], &[127, 127]), 127 * 127 * 2);
        assert_eq!(int8_inner_product(&[-1, -1], &[1, 1]), -2);
        assert_eq!(int8_inner_product(&[], &[]), 0);
    }

    #[test]
    fn top_k_picks_highest_score() {
        let corpus = vec![
            page(0, vec![1, 1, 1, 1]),      // ip with query = 4
            page(1, vec![10, 10, 10, 10]),  // ip = 40 (max)
            page(2, vec![5, 5, 5, 5]),      // ip = 20
            page(3, vec![-10, -10, -10, -10]), // ip = -40
        ];
        let query = vec![1, 1, 1, 1];
        let mut output = vec![(0_usize, i32::MIN); 1];
        sketch_top_k(&query, &corpus, &mut output).unwrap();
        assert_eq!(output[0].0, 1, "top-1 must be page index 1 (max score 40)");
        assert_eq!(output[0].1, 40);
    }

    #[test]
    fn top_k_picks_top_3() {
        let corpus = vec![
            page(0, vec![1; 4]),  // 4
            page(1, vec![10; 4]), // 40
            page(2, vec![5; 4]),  // 20
            page(3, vec![3; 4]),  // 12
            page(4, vec![-1; 4]), // -4
        ];
        let query = vec![1; 4];
        let mut output = vec![(0_usize, i32::MIN); 3];
        sketch_top_k(&query, &corpus, &mut output).unwrap();
        let mut ids: Vec<usize> = output.iter().map(|(i, _)| *i).collect();
        ids.sort();
        assert_eq!(ids, vec![1, 2, 3], "top-3 must be {{40, 20, 12}} = indices {{1, 2, 3}}");
    }

    #[test]
    fn length_mismatch_errors() {
        let corpus = vec![page(0, vec![1, 2, 3])];
        let query = vec![1, 2, 3, 4];
        let mut output = vec![(0_usize, i32::MIN); 1];
        let err = sketch_top_k(&query, &corpus, &mut output).unwrap_err();
        assert_eq!(
            err,
            SketchTopKError::SketchLengthMismatch { expected: 4, got: 3 }
        );
    }

    #[test]
    fn empty_output_buffer_errors() {
        let corpus = vec![page(0, vec![1, 1])];
        let query = vec![1, 1];
        let mut output: Vec<(usize, i32)> = vec![];
        let err = sketch_top_k(&query, &corpus, &mut output).unwrap_err();
        assert_eq!(err, SketchTopKError::EmptyOutputBuffer);
    }

    #[test]
    fn k_larger_than_corpus_still_works() {
        let corpus = vec![page(0, vec![1, 1]), page(1, vec![2, 2])];
        let query = vec![1, 1];
        let mut output = vec![(0_usize, i32::MIN); 5]; // K=5, corpus=2
        sketch_top_k(&query, &corpus, &mut output).unwrap();
        // 2 valid entries (indices 0 + 1); 3 entries remain at (0, MIN).
        let valid: Vec<&(usize, i32)> = output.iter().filter(|(_, s)| *s != i32::MIN).collect();
        assert_eq!(valid.len(), 2);
    }
}
