//! # Scan-IR — recurrence / SSM / Mamba-2 / linear-attention substrate
//!
//! Source:
//! - Dao, Gu, "Transformers are SSMs: Generalized Models and Efficient
//!   Algorithms Through Structured State Space Duality", arXiv:2405.21060
//!   (ICML 2024). §6 the SSD algorithm — the canonical parallel-block
//!   scan that this IR's lowering targets.
//! - Blelloch, "Prefix Sums and Their Applications", CMU-CS-90-190
//!   (1990). The associative-operator-over-monoid abstraction.
//! - Doctrine §2.3 + §4.3 — Scan-IR primitive signature + lowering plan.
//! - Phase B2 close-out `docs/audits/PHASE_B2_CLOSEOUT_2026_05_17.md` §6
//!   — iter-24 plan entry.
//!
//! ## T3 coordination
//!
//! Per driver SCOPE LOCK: this module is **coord T3 for F-SemiseparableBlockScan-
//! Correctness**. Scan-IR exports the typed AST [`grammar::ScanProgram`] +
//! the associativity-certificate emitter (Phase B3 iter-28). T3 owns the
//! falsifier oracle (a Dao/Gu reference SSD implementation + a fixture
//! sequence). Iter-26 lowering + iter-27 integration test is the
//! handoff window.

//! ## Usage example
//!
//! Sequential left-fold scan + parallel-block SSD scan, both
//! producing the same output sequence on an associative op.
//!
//! ```
//! use agent_core::research::scan_ir::{
//!     sequential_scan, ssd_block_scan, ScanProgram,
//! };
//!
//! // Prefix-sum scan: initial = 0, inputs = [1, 2, 3, 4, 5].
//! let prog = ScanProgram::new(0i32, vec![1, 2, 3, 4, 5]);
//! let op = |a: &i32, b: &i32| a + b;
//!
//! let seq = sequential_scan(&prog, op);
//! assert_eq!(seq, vec![0, 1, 3, 6, 10, 15]);
//!
//! // SSD parallel-block scan with identity = 0, block_size = 2.
//! let ssd = ssd_block_scan(&prog, op, 0, 2);
//! assert_eq!(ssd, seq);  // §4.I:892: bit-equal to sequential
//! ```

pub mod certificate;
pub mod evaluator;
pub mod grammar;
pub mod lowering;

pub use certificate::lean_certificate as scan_lean_certificate;
pub use evaluator::{
    first_difference, running_above_ratio, running_argmax, running_argmin,
    running_first_difference_abs,
    running_below_ratio, running_count_above, running_count_below,
    running_count_near_zero,
    running_count_in_range, running_count_negative, running_count_positive,
    running_count_consecutive_ties,
    running_count_local_maxima, running_count_local_minima,
    running_count_strict_decrease,
    running_count_strict_increase, running_count_turning_points,
    running_sign_changes,
    running_ema, running_first_difference,
    running_geometric_mean, running_harmonic_mean, running_l1_norm,
    running_cumulative_log_returns, running_cumulative_simple_return,
    running_realized_variance, running_realized_volatility,
    running_l2_norm, running_log_returns, running_log_sum_exp,
    running_max, running_max_drawdown,
    running_standard_deviation, running_sum_of_squares,
    running_unbiased_standard_deviation, running_unbiased_variance,
    running_max_drawup,
    running_max_abs, running_max_abs_signed,
    running_mean, running_mean_abs, running_mean_squared,
    running_min_abs, running_min_abs_signed,
    running_min, running_min_max_pair, running_product, running_quadratic_mean,
    running_range, running_relative_first_difference,
    running_squared_differences, running_squared_increments,
    running_fourth_central_moment, running_kurtosis, running_skewness, running_sum,
    running_third_central_moment, running_total_variation, running_variance,
    running_zscore,
    sequential_reduce, sequential_scan,
};
pub use grammar::ScanProgram;
pub use lowering::ssd_block_scan;
