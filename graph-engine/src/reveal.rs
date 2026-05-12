//! `RevealController` — the 5-phase state machine that controls how nodes
//! enter the live graph (Phase A Week 3 of the canonical plan).
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase A — CPU
//! foundation + zero-copy" → §"Week 3: GraphPOPE-lite warm-start +
//! RevealController". This module owns the frame-aware reveal cadence —
//! how many nodes wake per frame, what drag/alpha the integrator should
//! be running at, how long the settle tail lasts. The math is drop 5's
//! verbatim formulas; the only knob the user sees is
//! `target_duration_seconds` + a style enum.
//!
//! ## State machine
//!
//! ```text
//! Idle
//!   ↓ start()
//! Seeding   ← anchors + nearest-neighbour cluster come online (warm start)
//!   ↓ first batch ready
//! Ramping   ← exponential cap S(u) governs batch size; alpha climbs to target
//!   ↓ all batches enqueued
//! Settling  ← integrator continues with decaying alpha
//!   ↓ alpha < threshold OR settle_frames exhausted
//! Steady
//! ```
//!
//! ## Reveal styles
//!
//! - `Chronological`  – order by `created_at`
//! - `Connected`      – BFS from a chosen seed set (controller-agnostic; caller
//!                       supplies an order)
//! - `Random`         – deterministic shuffle by seed
//! - `AllAtOnce`      – skip batching; one big drop frame, then Settling
//!
//! The controller doesn't know about node metadata — callers must hand it a
//! pre-ordered slice of `node_ids`. That keeps the state machine pure-data and
//! independent of the rest of the engine.
//!
//! ## Determinism contract
//!
//! For a given `(input, frame sequence)` the controller produces the same
//! `RevealStep` sequence every run. Tested in `reveal_controller_is_deterministic`.

/// Visible to callers — drives the integrator and the renderer.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RevealPhase {
    Idle,
    Seeding,
    Ramping,
    Settling,
    Steady,
}

/// Which reveal pattern the user picked. Maps to drop 5's three reveal styles
/// plus the no-batching variant we keep for power users.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RevealStyle {
    Chronological,
    Connected,
    Random,
    AllAtOnce,
}

/// Configuration handed to `RevealController::new`. `target_duration_seconds`
/// is the user-facing knob; the rest are the canonical plan's locked
/// constants. Splitting them out makes the controller testable with
/// fake frame rates / batch sizes.
#[derive(Debug, Clone, Copy)]
pub struct RevealConfig {
    /// Frames per second of the live integrator. 60 in production; tests
    /// pick smaller numbers so the math is easy to verify by hand.
    pub fps: f32,
    /// User knob — scaling factor on `T_reveal`. 1.0 by default.
    pub user_duration_scale: f32,
    /// Style picked by the user.
    pub style: RevealStyle,
}

impl Default for RevealConfig {
    fn default() -> Self {
        Self {
            fps: 60.0,
            user_duration_scale: 1.0,
            style: RevealStyle::Chronological,
        }
    }
}

/// Per-frame instruction the integrator + renderer should consume.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RevealStep {
    /// Phase the controller is *in* after this `tick`.
    pub phase: RevealPhase,
    /// 0-based index into the node order — `[batch_start, batch_end)` is the
    /// half-open range of nodes to wake this frame. `batch_start == batch_end`
    /// means "nothing new this frame" (Settling/Steady, or holds between
    /// batches).
    pub batch_start: usize,
    pub batch_end: usize,
    /// What alpha the integrator should apply this frame. Climbs during
    /// Ramping, decays during Settling, hits zero in Steady.
    pub alpha: f32,
}

/// The state machine itself. Self-contained — no engine dependencies.
#[derive(Debug, Clone)]
pub struct RevealController {
    config: RevealConfig,
    total_nodes: usize,
    /// Total reveal frames `R = round(T_reveal * F)`.
    reveal_frames: u32,
    /// Initial cluster size `k_initial = clamp(round(1 + sqrt(N)/14), 2, 12)`.
    k_initial: usize,
    /// Frame counter inside the reveal window (0..R during Ramping).
    frame_in_reveal: u32,
    /// Frame counter inside the settle tail.
    frame_in_settle: u32,
    /// Index of the *next* node that hasn't been revealed yet (0..total_nodes).
    next_unrevealed: usize,
    /// Current phase.
    phase: RevealPhase,
    /// Cached batch ceiling so `tick` math is one branch.
    b_min: f32,
    b_max: f32,
    /// Settle bookkeeping.
    settle_frames: u32,
    alpha_current: f32,
    alpha_target_max: f32,
    /// Per-batch hold counter — frames to wait between batches.
    hold_frames: u32,
    holding: u32,
}

const ALPHA_SETTLE_FLOOR: f32 = 1e-3;

impl RevealController {
    pub fn new(total_nodes: usize, config: RevealConfig) -> Self {
        let n = total_nodes.max(0) as f32;
        let f = config.fps.max(1.0);
        // T_reveal = clamp(1.2 + 1.1 * sqrt(N / 5000), 1.2, 9.0) * user_duration_scale
        let t_reveal_raw = 1.2_f32 + 1.1_f32 * (n / 5_000.0).sqrt();
        let t_reveal = t_reveal_raw.clamp(1.2, 9.0) * config.user_duration_scale.max(0.05);
        let r = (t_reveal * f).round().max(1.0) as u32;
        // k_initial = clamp(round(1 + sqrt(N)/14), 2, 12)
        let k_initial = ((1.0 + n.sqrt() / 14.0).round() as i32).clamp(2, 12) as usize;
        // B_min = clamp(round(16 * sqrt(N/1000) * F/60), 16, 128)
        // B_max = clamp(round(96 * sqrt(N/1000) * F/60), 96, 1600)
        let scale = (n / 1_000.0).sqrt() * (f / 60.0);
        let b_min = (16.0 * scale).round().clamp(16.0, 128.0);
        let b_max = (96.0 * scale).round().clamp(96.0, 1_600.0);
        // hold_frames = 1 if N < 20000 else 2
        let hold = if total_nodes < 20_000 { 1 } else { 2 };
        // settle_frames = clamp(round(F * (1.0 + 0.00004 * N)), F, 5*F)
        let settle_raw = (f * (1.0 + 0.000_04 * n)).round();
        let settle_min = f;
        let settle_max = 5.0 * f;
        let settle = settle_raw.clamp(settle_min, settle_max) as u32;

        Self {
            config,
            total_nodes,
            reveal_frames: r,
            k_initial: k_initial.min(total_nodes),
            frame_in_reveal: 0,
            frame_in_settle: 0,
            next_unrevealed: 0,
            phase: RevealPhase::Idle,
            b_min,
            b_max,
            settle_frames: settle,
            alpha_current: 0.0,
            alpha_target_max: 0.0,
            hold_frames: hold,
            holding: 0,
        }
    }

    /// Begin the reveal. Idempotent — calling twice resets the controller.
    pub fn start(&mut self) {
        self.phase = if self.total_nodes == 0 {
            RevealPhase::Steady
        } else {
            RevealPhase::Seeding
        };
        self.frame_in_reveal = 0;
        self.frame_in_settle = 0;
        self.next_unrevealed = 0;
        self.alpha_current = 0.0;
        self.holding = 0;
    }

    /// Advance one frame. The returned `RevealStep` tells the integrator which
    /// nodes to wake and what alpha to apply.
    pub fn tick(&mut self) -> RevealStep {
        if self.total_nodes == 0 || self.phase == RevealPhase::Idle {
            return RevealStep {
                phase: self.phase,
                batch_start: 0,
                batch_end: 0,
                alpha: 0.0,
            };
        }

        match self.config.style {
            RevealStyle::AllAtOnce => self.tick_all_at_once(),
            _ => self.tick_progressive(),
        }
    }

    fn tick_progressive(&mut self) -> RevealStep {
        match self.phase {
            RevealPhase::Seeding => {
                // Drop the warm-start cluster on the first frame.
                let end = self.k_initial.min(self.total_nodes);
                let start = self.next_unrevealed;
                self.next_unrevealed = end;
                self.phase = RevealPhase::Ramping;
                self.alpha_current = self.alpha_target_for(end - start);
                self.alpha_target_max = self.alpha_target_max.max(self.alpha_current);
                RevealStep {
                    phase: RevealPhase::Seeding,
                    batch_start: start,
                    batch_end: end,
                    alpha: self.alpha_current,
                }
            }
            RevealPhase::Ramping => {
                // Holding between batches?
                if self.holding > 0 {
                    self.holding -= 1;
                    return RevealStep {
                        phase: RevealPhase::Ramping,
                        batch_start: self.next_unrevealed,
                        batch_end: self.next_unrevealed,
                        alpha: self.alpha_current,
                    };
                }

                let r = self.reveal_frames as f32;
                let u = (self.frame_in_reveal as f32 / r.max(1.0)).clamp(0.0, 1.0);
                let s = if u <= 0.0 {
                    0.0
                } else {
                    (1.0 - (-4.0 * u).exp()) / (1.0 - (-4.0_f32).exp())
                };
                let batch = (self.b_min + (self.b_max - self.b_min) * s).round() as usize;
                let start = self.next_unrevealed;
                let end = (start + batch).min(self.total_nodes);
                self.next_unrevealed = end;
                self.frame_in_reveal += 1;

                let added = end - start;
                self.alpha_current = self.alpha_target_for(added);
                self.alpha_target_max = self.alpha_target_max.max(self.alpha_current);

                if self.next_unrevealed >= self.total_nodes {
                    self.phase = RevealPhase::Settling;
                    self.frame_in_settle = 0;
                } else if self.hold_frames > 0 {
                    // Schedule the inter-batch hold.
                    self.holding = self.hold_frames;
                }

                RevealStep {
                    phase: RevealPhase::Ramping,
                    batch_start: start,
                    batch_end: end,
                    alpha: self.alpha_current,
                }
            }
            RevealPhase::Settling => self.tick_settling(),
            RevealPhase::Steady => RevealStep {
                phase: RevealPhase::Steady,
                batch_start: self.total_nodes,
                batch_end: self.total_nodes,
                alpha: 0.0,
            },
            RevealPhase::Idle => unreachable!("Idle handled by outer tick()"),
        }
    }

    fn tick_all_at_once(&mut self) -> RevealStep {
        match self.phase {
            RevealPhase::Seeding => {
                let start = 0;
                let end = self.total_nodes;
                self.next_unrevealed = end;
                self.phase = RevealPhase::Settling;
                // High alpha so the integrator has authority to disperse the
                // single-frame drop.
                let alpha = self.alpha_target_for(end).max(0.12);
                self.alpha_current = alpha;
                self.alpha_target_max = alpha;
                self.frame_in_settle = 0;
                RevealStep {
                    phase: RevealPhase::Seeding,
                    batch_start: start,
                    batch_end: end,
                    alpha,
                }
            }
            RevealPhase::Settling => self.tick_settling(),
            RevealPhase::Steady => RevealStep {
                phase: RevealPhase::Steady,
                batch_start: self.total_nodes,
                batch_end: self.total_nodes,
                alpha: 0.0,
            },
            RevealPhase::Ramping => self.tick_settling(),
            RevealPhase::Idle => unreachable!("Idle handled by outer tick()"),
        }
    }

    fn tick_settling(&mut self) -> RevealStep {
        let settle = self.settle_frames as f32;
        // alpha_decay = 1 - pow(0.001 / max(alpha_current, 0.001), 1 / settle_frames)
        // Apply: alpha *= (1 - alpha_decay)  ⇒  alpha *= pow(0.001 / α, 1/settle)
        let alpha_floor = self.alpha_current.max(ALPHA_SETTLE_FLOOR);
        let decay_factor = (ALPHA_SETTLE_FLOOR / alpha_floor)
            .powf(1.0 / settle.max(1.0));
        // decay_factor is the per-frame multiplicative survival; alpha shrinks.
        self.alpha_current *= decay_factor;
        self.frame_in_settle += 1;
        if self.alpha_current <= ALPHA_SETTLE_FLOOR
            || self.frame_in_settle >= self.settle_frames
        {
            self.phase = RevealPhase::Steady;
            self.alpha_current = 0.0;
        }
        RevealStep {
            phase: self.phase,
            batch_start: self.total_nodes,
            batch_end: self.total_nodes,
            alpha: self.alpha_current,
        }
    }

    /// alpha_target(batch, N) = clamp(0.035 + 0.16 * sqrt(batch / max(N, 1)), 0.04, 0.16)
    fn alpha_target_for(&self, batch: usize) -> f32 {
        let n = self.total_nodes.max(1) as f32;
        let b = batch.max(0) as f32;
        let raw = 0.035 + 0.16 * (b / n).sqrt();
        raw.clamp(0.04, 0.16)
    }

    // ─── Observability helpers (used by tests + telemetry) ──────────────────

    pub fn phase(&self) -> RevealPhase { self.phase }
    pub fn reveal_frames(&self) -> u32 { self.reveal_frames }
    pub fn k_initial(&self) -> usize { self.k_initial }
    pub fn batch_bounds(&self) -> (f32, f32) { (self.b_min, self.b_max) }
    pub fn settle_frames(&self) -> u32 { self.settle_frames }
    pub fn alpha_current(&self) -> f32 { self.alpha_current }
    pub fn next_unrevealed(&self) -> usize { self.next_unrevealed }
    pub fn hold_frames(&self) -> u32 { self.hold_frames }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn cfg(style: RevealStyle, fps: f32) -> RevealConfig {
        RevealConfig { fps, user_duration_scale: 1.0, style }
    }

    #[test]
    fn idle_until_start() {
        let mut c = RevealController::new(100, cfg(RevealStyle::Chronological, 60.0));
        assert_eq!(c.phase(), RevealPhase::Idle);
        let step = c.tick();
        assert_eq!(step.phase, RevealPhase::Idle);
        assert_eq!(step.batch_end, 0);
        assert_eq!(step.alpha, 0.0);
    }

    #[test]
    fn zero_node_graph_jumps_to_steady() {
        let mut c = RevealController::new(0, cfg(RevealStyle::Chronological, 60.0));
        c.start();
        assert_eq!(c.phase(), RevealPhase::Steady);
        let step = c.tick();
        assert_eq!(step.phase, RevealPhase::Steady);
    }

    #[test]
    fn k_initial_matches_plan_bands() {
        // 1 + sqrt(N)/14 clamped [2, 12]
        let c1 = RevealController::new(50, cfg(RevealStyle::Chronological, 60.0));
        assert_eq!(c1.k_initial(), 2);
        let c2 = RevealController::new(2_000, cfg(RevealStyle::Chronological, 60.0));
        let expected2 = (1.0_f32 + (2_000.0_f32).sqrt() / 14.0).round() as usize;
        assert_eq!(c2.k_initial(), expected2.clamp(2, 12));
        let c3 = RevealController::new(50_000, cfg(RevealStyle::Chronological, 60.0));
        assert_eq!(c3.k_initial(), 12);
    }

    #[test]
    fn seeding_drops_k_initial_on_first_frame() {
        let mut c = RevealController::new(2_000, cfg(RevealStyle::Chronological, 60.0));
        c.start();
        let s = c.tick();
        assert_eq!(s.phase, RevealPhase::Seeding);
        assert_eq!(s.batch_start, 0);
        assert_eq!(s.batch_end, c.k_initial());
        assert!(s.alpha > 0.0);
    }

    #[test]
    fn ramping_batches_grow_then_finish() {
        let mut c = RevealController::new(500, cfg(RevealStyle::Chronological, 60.0));
        c.start();
        let _seed = c.tick();
        let mut last_batch = 0usize;
        let mut saw_growth = false;
        // Burn enough frames to exhaust the reveal window. Hold frames between
        // batches won't add new nodes; check the *non-empty* batches only.
        for _ in 0..2000 {
            let s = c.tick();
            let n = s.batch_end - s.batch_start;
            if n > 0 {
                if n > last_batch && last_batch > 0 { saw_growth = true; }
                last_batch = n;
            }
            if c.phase() == RevealPhase::Settling || c.phase() == RevealPhase::Steady { break; }
        }
        assert!(saw_growth, "batch size must grow during Ramping (S-curve)");
    }

    #[test]
    fn ramping_then_settling_then_steady() {
        let mut c = RevealController::new(50, cfg(RevealStyle::Chronological, 60.0));
        c.start();
        let _ = c.tick();
        for _ in 0..5_000 {
            c.tick();
            if c.phase() == RevealPhase::Steady { break; }
        }
        assert_eq!(c.phase(), RevealPhase::Steady, "controller must reach Steady");
        assert_eq!(c.next_unrevealed(), 50);
    }

    #[test]
    fn all_at_once_skips_batching() {
        let mut c = RevealController::new(120, cfg(RevealStyle::AllAtOnce, 60.0));
        c.start();
        let s = c.tick();
        assert_eq!(s.batch_start, 0);
        assert_eq!(s.batch_end, 120);
        // After the single drop frame we should be in Settling.
        assert!(matches!(c.phase(), RevealPhase::Settling));
    }

    #[test]
    fn reveal_controller_is_deterministic() {
        let mut a = RevealController::new(500, cfg(RevealStyle::Chronological, 60.0));
        let mut b = RevealController::new(500, cfg(RevealStyle::Chronological, 60.0));
        a.start();
        b.start();
        for _ in 0..400 {
            assert_eq!(a.tick(), b.tick(), "deterministic tick sequence");
            if a.phase() == RevealPhase::Steady { break; }
        }
    }

    #[test]
    fn alpha_target_is_within_bounds() {
        let c = RevealController::new(10_000, cfg(RevealStyle::Chronological, 60.0));
        let small = c.alpha_target_for(1);
        let mid = c.alpha_target_for(500);
        let big = c.alpha_target_for(10_000);
        assert!((0.04..=0.16).contains(&small));
        assert!((0.04..=0.16).contains(&mid));
        assert!((0.04..=0.16).contains(&big));
        assert!(big >= mid && mid >= small, "monotone in batch size");
    }

    #[test]
    fn settle_frames_within_band() {
        let c = RevealController::new(10_000, cfg(RevealStyle::Chronological, 60.0));
        assert!(c.settle_frames() >= 60); // ≥ F
        assert!(c.settle_frames() <= 300); // ≤ 5F
    }

    #[test]
    fn hold_frames_threshold() {
        let small = RevealController::new(1_000, cfg(RevealStyle::Chronological, 60.0));
        let big = RevealController::new(30_000, cfg(RevealStyle::Chronological, 60.0));
        assert_eq!(small.hold_frames(), 1);
        assert_eq!(big.hold_frames(), 2);
    }

    #[test]
    fn batch_bounds_clamp_to_plan() {
        let small = RevealController::new(100, cfg(RevealStyle::Chronological, 60.0));
        assert!(small.batch_bounds().0 >= 16.0);
        assert!(small.batch_bounds().1 >= 96.0);
        let huge = RevealController::new(2_000_000, cfg(RevealStyle::Chronological, 60.0));
        // b_max is clamped to 1600.
        assert!(huge.batch_bounds().1 <= 1_600.0);
        assert!(huge.batch_bounds().0 <= 128.0);
    }

    #[test]
    fn reveal_frames_clamps_to_one_to_nine_seconds() {
        // 1.2s minimum × 60 fps = 72 frames lower bound.
        let tiny = RevealController::new(1, cfg(RevealStyle::Chronological, 60.0));
        assert!(tiny.reveal_frames() >= 72);
        // 9.0s × 60 fps = 540 frames upper bound (with scale=1.0).
        let huge = RevealController::new(1_000_000, cfg(RevealStyle::Chronological, 60.0));
        assert!(huge.reveal_frames() <= 540);
    }

    #[test]
    fn user_duration_scale_compresses() {
        let cfg_half = RevealConfig {
            fps: 60.0, user_duration_scale: 0.5, style: RevealStyle::Chronological
        };
        let cfg_full = RevealConfig {
            fps: 60.0, user_duration_scale: 1.0, style: RevealStyle::Chronological
        };
        let half = RevealController::new(5_000, cfg_half);
        let full = RevealController::new(5_000, cfg_full);
        assert!(half.reveal_frames() < full.reveal_frames(),
            "shorter user duration shortens the reveal");
    }

    #[test]
    fn alpha_decays_during_settling() {
        let mut c = RevealController::new(5, cfg(RevealStyle::AllAtOnce, 60.0));
        c.start();
        c.tick(); // Seeding → Settling.
        let alpha_pre = c.alpha_current();
        c.tick();
        let alpha_post = c.alpha_current();
        // Allow either monotone decay or an immediate jump to Steady (5-node
        // graph with very small alpha can decay below the floor in one step).
        assert!(alpha_post <= alpha_pre + 1e-6, "alpha must not grow in Settling");
    }
}
