//! Source:
//! - `docs/fusion/helios v6.2.md` — Helios v6.2 8-stage falsifier order
//!   (PageGather baseline → scatter → InterruptScore → PacketRouter1bit →
//!   ControllerKernelPack → SemiseparableBlockScan → LocalRecallIsland →
//!   RULER+BABILong).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.2 — Helios kernel slice list + M2 Pro 16 GB adaptation
//!   contract.
//! - `project_v6_1_proof_ledger` user-memory — 5 V6.1 kernels +
//!   InterruptScore.metal originally tagged "canonical_target_not_
//!   implemented_here"; Phase B.2 lands them on M2 Pro 16 GB.
//!
//! # Phase B.2 — Helios V5/V6.1/V6.2 hardware-validated kernels
//!
//! 8-stage falsifier order (this substrate-floor module ships stage 1
//! + stage 2 only — PageGather baseline + scatter as CPU references
//! plus a Metal stub). Stages 3-8 land in subsequent iters:
//!
//! 1. **PageGather baseline** ([`page_gather`]) — STREAM-on-Metal
//!    probe; expected 63-73 GB/s on M2 Pro.
//! 2. **PageGather scatter** ([`page_gather`]) — ≥70% baseline at
//!    {256 MB, 512 MB} working sets.
//! 3. Swift CPU InterruptScore P99 <100µs — LANDED 2026-05-12 (Swift
//!    side, outside Terminal B scope); verify still green.
//! 4. PacketRouter1bit.metal dispatch P99 <100µs (NOT-STARTED).
//! 5. ControllerKernelPack.metal 6 fused micro-kernels (NOT-STARTED).
//! 6. SemiseparableBlockScan.metal correctness vs PyTorch
//!    `ssd_minimal.py` Listing 1 (NOT-STARTED).
//! 7. LocalRecallIsland.metal 32K Core: 50 trials × 5 depths passkey
//!    ≥0.95 (NOT-STARTED).
//! 8. RULER + BABILong harness at 32K under 30 min wall-clock on M2
//!    Pro 16 GB (NOT-STARTED).
//!
//! ## HARDWARE-BUDGET
//!
//! Canonical Wave J Helios target was M2 Max 64 GB; Terminal B adapts
//! to M2 Pro 16 GB. Working-set ceiling for PageGather drops from
//! 512 MB / 1024 MB pairs to {256 MB, 512 MB} (per driver §5 Phase
//! B.2 stage 2). Larger ceilings deferred to M2 Max validation path.

pub mod controller_pack;
pub mod local_recall_island;
pub mod long_context_harness;
pub mod packet_router;
pub mod page_gather;
pub mod ssd_block_scan;

pub use controller_pack::{
    argmax_reduce, copy_range, max_reduce, scalar_add_in_place, scalar_mul_in_place,
    zero_fill, ControllerKernelError,
};
pub use local_recall_island::{
    passkey_retrieve, run_passkey_trials, single_passkey_trial, RecallError,
    RecallReport, RecallStore,
};
pub use long_context_harness::{
    aggregate_results, run_synthetic_harness, HarnessError, HarnessReport, Task,
    TaskResult, STAGE_8_BUDGET_MS,
};
pub use packet_router::{
    route_1bit, unroute_1bit, PacketRouterError, PacketRouterStats, RoutingOutputs,
};
pub use page_gather::{
    gather, gather_with_scale, HeliosError, PageGatherStats,
};
pub use ssd_block_scan::{
    compare_scans, ssd_block_scan_scalar, ssd_scan_scalar, ssd_stability_check, SsdScanError,
    SsdScanResult,
};
