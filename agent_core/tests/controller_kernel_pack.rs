//! F-ControllerKernelPack — substrate-floor integration harness.
//!
//! Per `docs/falsifiers/F-ControllerKernelPack_2026_05_17.md`.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::{scalar_add_in_place, scalar_mul_in_place,
//! max_reduce, argmax_reduce, copy_range, zero_fill}` at scale across the
//! 7-array-size sweep (1, 16, 64, 256, 1024, 4096, 16384) the falsifier
//! §2 enumerates.
//!
//! Production-PASS requires Metal kernel pack p99 < 50 µs at 4096
//! elements; substrate-floor exercises the Rust CPU reference for
//! correctness at every size. Numerical-equivalence (Track A per
//! falsifier §3) lives in the existing
//! `agent_core/src/helios/controller_pack.rs::tests` unit tests; this
//! harness adds the at-scale cross-size + sequence-execution cover.

use agent_core::helios::{
    argmax_reduce, copy_range, max_reduce, scalar_add_in_place, scalar_mul_in_place, zero_fill,
};

const SIZE_SWEEP: &[usize] = &[1, 16, 64, 256, 1024, 4096, 16_384];

fn deterministic_buffer(size: usize, seed: u64) -> Vec<f32> {
    let mut rng = seed;
    (0..size)
        .map(|_| {
            rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
            ((rng & 0xFFFF) as f32) / 65536.0 - 0.5 // [-0.5, 0.5)
        })
        .collect()
}

#[test]
fn scalar_add_correctness_across_size_sweep() {
    for &size in SIZE_SWEEP {
        let original = deterministic_buffer(size, 0xCC11_AA00);
        let mut buf = original.clone();
        scalar_add_in_place(&mut buf, 0.5);
        for (a, b) in original.iter().zip(buf.iter()) {
            assert!((a + 0.5 - b).abs() < 1e-6, "scalar_add mismatch at size {}", size);
        }
    }
}

#[test]
fn scalar_mul_correctness_across_size_sweep() {
    for &size in SIZE_SWEEP {
        let original = deterministic_buffer(size, 0xCC11_BB00);
        let mut buf = original.clone();
        scalar_mul_in_place(&mut buf, 2.0);
        for (a, b) in original.iter().zip(buf.iter()) {
            assert!((a * 2.0 - b).abs() < 1e-6, "scalar_mul mismatch at size {}", size);
        }
    }
}

#[test]
fn max_reduce_finds_known_maximum() {
    for &size in SIZE_SWEEP {
        if size < 2 {
            continue;
        }
        let mut buf = deterministic_buffer(size, 0xCC11_CC00);
        // Plant a clear maximum at index size/2.
        buf[size / 2] = 100.0;
        let max = max_reduce(&buf).expect("max_reduce must succeed");
        assert!((max - 100.0).abs() < 1e-6, "max_reduce failed at size {}", size);
    }
}

#[test]
fn argmax_reduce_finds_known_argmax() {
    for &size in SIZE_SWEEP {
        if size < 2 {
            continue;
        }
        let mut buf = deterministic_buffer(size, 0xCC11_DD00);
        let planted_idx = size - 1;
        buf[planted_idx] = 1000.0;
        let am = argmax_reduce(&buf).expect("argmax_reduce must succeed");
        assert_eq!(am, planted_idx, "argmax mismatch at size {}", size);
    }
}

#[test]
fn copy_range_preserves_values() {
    for &size in SIZE_SWEEP {
        let src = deterministic_buffer(size, 0xCC11_EE00);
        let mut dst = vec![0.0_f32; size];
        copy_range(&mut dst, &src).expect("copy_range must succeed");
        assert_eq!(src, dst, "copy mismatch at size {}", size);
    }
}

#[test]
fn zero_fill_zeroes_buffer() {
    for &size in SIZE_SWEEP {
        let mut buf = deterministic_buffer(size, 0xCC11_FF00);
        zero_fill(&mut buf);
        for (i, &v) in buf.iter().enumerate() {
            assert_eq!(v, 0.0, "zero_fill leaked at size {} index {}", size, i);
        }
    }
}

/// Sequence test (per F-ControllerKernelPack falsifier §3): run all 6
/// kernels in sequence over a 4096-element buffer, 100 iterations. The
/// substrate-floor doesn't measure wall-clock budget (< 30 ms per
/// falsifier §3), but proves the kernels compose correctly.
#[test]
fn six_kernel_sequence_composes() {
    let size = 4096;
    let original = deterministic_buffer(size, 0xCC11_5500);
    let mut buf = original.clone();
    let mut dst = vec![0.0_f32; size];

    for _ in 0..100 {
        scalar_add_in_place(&mut buf, 0.001);
        scalar_mul_in_place(&mut buf, 1.001);
        let _ = max_reduce(&buf).expect("max_reduce");
        let _ = argmax_reduce(&buf).expect("argmax_reduce");
        copy_range(&mut dst, &buf).expect("copy_range");
        zero_fill(&mut buf);
        copy_range(&mut buf, &dst).expect("copy_range back");
    }

    // After 100 iterations of (+0.001, *1.001) the buffer has been
    // transformed predictably. The point of the test is that the
    // sequence runs without panic or error.
    assert!(buf.iter().all(|v| v.is_finite()), "no NaN/Inf after 100 sequences");
}

/// Empty input edge cases.
#[test]
fn max_reduce_on_empty_errors() {
    let empty: Vec<f32> = vec![];
    assert!(max_reduce(&empty).is_err());
}

#[test]
fn argmax_reduce_first_index_tie_break() {
    // First-index tie-break per falsifier §3 acceptance.
    let buf = vec![1.0, 1.0, 1.0]; // all equal
    let am = argmax_reduce(&buf).expect("argmax of ties must return some index");
    assert_eq!(am, 0, "tie-break should pick first index");
}
