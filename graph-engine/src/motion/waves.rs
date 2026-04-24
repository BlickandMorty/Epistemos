//! Authored wave rings — task 3 of the v3 graph motion spec.
//!
//! The v3 spec explicitly rejects solving a 2-D wave equation on the
//! existing FluidGrid because it "produces visual chaos when you run two
//! drags in succession" (docs/GRAPH_WAVES_PLAN.md §1, v3 §4.2). Instead
//! each ripple is an authored `WaveEvent` — an expanding Gaussian shell
//! with baked speed, amplitude, and decay — and the active set is capped
//! at eight. The shell reads as "water" because the force profile is:
//!
//! 1. **Gaussian ring** traveling outward at `speed_px_s`, so nodes
//!    nearer the centre feel the wave first and outer nodes feel it
//!    later — the perceptual "delayed propagation" that d3-style sims
//!    can't produce.
//! 2. **Exponential temporal decay** so amplitude folds to 1/e in
//!    `decay_s` seconds — the ring weakens as it ages.
//! 3. **Radial `1/√r` falloff** for 2-D energy conservation; clamped
//!    near the origin so a node at the drag centre doesn't see an
//!    infinite spike.
//!
//! Times are passed as `f64` monotonic seconds (sim-time) so tests can
//! inject deterministic timestamps without waiting on real wall-clock
//! sleeps. The simulation records its own `t_epoch` and converts
//! `Instant::now()` to sim-seconds when calling into the accumulator.

use smallvec::SmallVec;

/// A single authored ripple event.
///
/// All fields are public for straightforward test construction — the
/// struct is a plain value type with no invariants beyond "fields are
/// finite non-negative floats" which callers uphold via the `emit`
/// constructor. Forcing the type to `Copy` keeps the hot accumulate
/// loop free of borrow dances.
#[derive(Clone, Copy, Debug)]
pub struct WaveEvent {
    /// Epicentre in world units.
    pub center_x: f32,
    pub center_y: f32,
    /// Sim-seconds at which the event was spawned. Monotonic and
    /// strictly increasing for a given simulation.
    pub t_start_s: f64,
    /// Radial speed of the expanding ring (world units per second).
    pub speed_px_s: f32,
    /// Peak amplitude of the traveling shell. Combined with decay and
    /// radial falloff to produce the per-node force magnitude.
    pub amplitude: f32,
    /// Gaussian ring thickness. FWHM ≈ 2.355 × sigma.
    pub sigma_px: f32,
    /// Exponential 1/e temporal decay time. After `~3 × decay_s` the
    /// amplitude has folded below ~5% and the event can be retired.
    pub decay_s: f32,
    /// Retirement radius — beyond this the force is clamped to zero,
    /// regardless of what the shell equation would otherwise produce.
    pub max_radius_px: f32,
}

impl WaveEvent {
    /// Calibrated capillary-wave speed (v3 §4.2): real capillary waves
    /// travel ~23 cm/s; at typical screen DPI that maps to ~320 px/s
    /// for a ring that crosses one node-spacing in a perceptibly
    /// "watery" ~100 ms.
    pub const DEFAULT_SPEED_PX_S: f32 = 320.0;
    /// Ring thickness: wider = softer, blurrier wave; narrower =
    /// crisper front but risks stroboscopic feel.
    pub const DEFAULT_SIGMA_PX: f32 = 80.0;
    /// 1/e fold time — gives ~3 visible oscillations before decay.
    pub const DEFAULT_DECAY_S: f32 = 0.9;
    /// Hard radial cutoff for the force. Viewport-scale upper bound.
    pub const DEFAULT_MAX_RADIUS_PX: f32 = 1400.0;

    /// Floor on the radial divisor so a node sitting *at* the wave
    /// centre doesn't see a 1/0 spike. 16 px roughly matches a node
    /// radius at default zoom — below this the node is so close to the
    /// drag origin that the reading of a "travelling ring" breaks down
    /// anyway.
    pub const ORIGIN_CLAMP_PX: f32 = 16.0;

    /// Retirement threshold — once the temporal envelope drops below
    /// 5% AND the front has passed `max_radius_px`, the event is
    /// finished and the caller can evict it.
    pub const RETIRE_AMPLITUDE_FRACTION: f32 = 0.05;

    /// Compute the per-node radial force vector at world position
    /// `(x, y)` given the current sim-time. Returns `(0, 0)` outside
    /// the wave's spatial or temporal window so callers can add the
    /// result unconditionally without a zero-check.
    #[inline]
    pub fn force_at(&self, x: f32, y: f32, now_s: f64) -> (f32, f32) {
        let age_s = (now_s - self.t_start_s) as f32;
        if age_s <= 0.0 {
            return (0.0, 0.0);
        }

        let dx = x - self.center_x;
        let dy = y - self.center_y;
        let r_sq = dx * dx + dy * dy;
        if r_sq <= 0.0 || !r_sq.is_finite() {
            return (0.0, 0.0);
        }
        let r = r_sq.sqrt();
        if r > self.max_radius_px {
            return (0.0, 0.0);
        }

        // Gaussian shell traveling outward at `speed_px_s`.
        let r_front = self.speed_px_s * age_s;
        let band = (r - r_front) / self.sigma_px.max(1e-3);
        let shell = (-band * band).exp();

        // Temporal amplitude decay — independent of space.
        let t_env = (-age_s / self.decay_s.max(1e-3)).exp();

        // 2-D radial energy conservation, clamped near the origin.
        let r_clamped = r.max(Self::ORIGIN_CLAMP_PX);
        let radial = 1.0 / r_clamped.sqrt();

        let mag = self.amplitude * shell * t_env * radial;
        let inv_r = 1.0 / r;
        (mag * dx * inv_r, mag * dy * inv_r)
    }

    /// True once the temporal envelope has decayed below 5%. The
    /// accumulator can then skip the event entirely and eventually
    /// `retire_finished` evicts it from the list.
    #[inline]
    pub fn is_retired(&self, now_s: f64) -> bool {
        let age_s = (now_s - self.t_start_s) as f32;
        if age_s < 0.0 {
            return false;
        }
        let t_env = (-age_s / self.decay_s.max(1e-3)).exp();
        if t_env < Self::RETIRE_AMPLITUDE_FRACTION {
            return true;
        }
        // Belt-and-suspenders: even if decay is somehow disabled,
        // stop once the wavefront has crossed the retirement radius.
        let r_front = self.speed_px_s * age_s;
        r_front > self.max_radius_px + self.sigma_px * 3.0
    }
}

/// Bounded active-event queue. Invariant: `events.len() <= CAPACITY`.
///
/// Stored via `SmallVec` so the happy path (few concurrent waves) stays
/// on the stack and avoids heap allocation inside the interactive path.
#[derive(Debug, Default)]
pub struct ActiveWaves {
    events: SmallVec<[WaveEvent; 8]>,
}

impl ActiveWaves {
    /// Maximum number of concurrently active ripple events. Beyond this
    /// the oldest is evicted to make room for a new one — the resulting
    /// force is a linear sum across events, so the cap also bounds the
    /// per-node accumulation cost.
    pub const CAPACITY: usize = 8;

    /// Release speeds below this threshold (world units / s) do not
    /// spawn a wave. Matches the `mouse_up` threshold in engine.rs so
    /// "holding and letting go" produces no ripple, while a visible
    /// flick always does.
    pub const RELEASE_MIN_SPEED_PX_S: f32 = 5.0;

    /// Coupling gain from raw wave force into per-tick velocity delta.
    /// Canonical starting value per v3 spec — parity with FluidGrid's
    /// `FLUID_K = 0.2` so both overlay layers live on a shared scale
    /// and tune together. An earlier session bumped this to 0.5 in
    /// response to "feels subtle," but the cause was a per-second vs
    /// per-tick unit mismatch on release velocity (fixed in `d7f4be40`);
    /// with the release integrated correctly, 0.2 is the right starting
    /// point and deeper tuning belongs in a dedicated A/B commit rather
    /// than a diagnostic patch.
    pub const DEFAULT_COUPLING: f32 = 0.2;

    pub fn new() -> Self {
        Self {
            events: SmallVec::new(),
        }
    }

    pub fn len(&self) -> usize {
        self.events.len()
    }

    pub fn is_empty(&self) -> bool {
        self.events.is_empty()
    }

    pub fn clear(&mut self) {
        self.events.clear();
    }

    /// Spawn a new wave from a drag-release event. Release speed below
    /// `RELEASE_MIN_SPEED_PX_S` is silently ignored (no ripple, since
    /// the user was effectively holding the node still). Amplitude
    /// scales as `sqrt(speed / 300)` for sublinear stacking — rapid
    /// repeated drags don't explode the visual noise floor.
    pub fn emit(&mut self, center_x: f32, center_y: f32, release_vx: f32, release_vy: f32, now_s: f64) {
        let speed_sq = release_vx * release_vx + release_vy * release_vy;
        if !speed_sq.is_finite() || speed_sq < Self::RELEASE_MIN_SPEED_PX_S.powi(2) {
            return;
        }

        let speed = speed_sq.sqrt();
        let energy = (speed / 300.0).min(3.0);
        // Amplitude base follows v3 spec §6 starting value. A 600 px/s
        // flick produces `45 × √2 ≈ 64` units of amplitude, which with
        // the 1/√r radial falloff and 0.2 coupling lands as a visible
        // ring once the release integrator is correctly unit-scaled
        // (see `d7f4be40` — the previous "feels subtle" report was a
        // symptom of the rubber-band kick stealing the attention, not
        // an amplitude shortfall). `sqrt` inside `energy` keeps the
        // stacking sublinear under rapid repeated drags.
        let amplitude = 45.0 * energy.sqrt();

        if self.events.len() >= Self::CAPACITY {
            // Evict the OLDEST event so the freshest user action always
            // lands — mirrors the lossy-latest queue pattern used for
            // drag impulses elsewhere in the motion system (GPT
            // correction "5. The SIMD test ..." → `force_push` latest).
            self.events.remove(0);
        }

        self.events.push(WaveEvent {
            center_x,
            center_y,
            t_start_s: now_s,
            speed_px_s: WaveEvent::DEFAULT_SPEED_PX_S,
            amplitude,
            sigma_px: WaveEvent::DEFAULT_SIGMA_PX,
            decay_s: WaveEvent::DEFAULT_DECAY_S,
            max_radius_px: WaveEvent::DEFAULT_MAX_RADIUS_PX,
        });
    }

    /// Drop events whose temporal envelope has folded below 5% OR whose
    /// wavefront has already cleared the retirement radius.
    pub fn retire_finished(&mut self, now_s: f64) {
        self.events.retain(|w| !w.is_retired(now_s));
    }

    /// Per-tick force accumulation. Only applies to free (non-fixed)
    /// nodes — pinned nodes are still held to their fx/fy by the
    /// simulation core, so giving them a wave impulse would be a
    /// no-op at best and a race at worst. Safe to call with an empty
    /// event list — early-returns without touching the input buffers.
    ///
    /// The `coupling` parameter scales the raw force into a velocity
    /// delta and matches the convention used by the fluid grid
    /// (`vx[i] += force * FLUID_K`). A later commit migrates both to a
    /// force buffer integrated with a proper dt.
    pub fn accumulate(
        &self,
        vx: &mut [f32],
        vy: &mut [f32],
        x: &[f32],
        y: &[f32],
        fx: &[Option<f32>],
        coupling: f32,
        now_s: f64,
    ) {
        if self.events.is_empty() {
            return;
        }
        let n = vx.len().min(x.len()).min(y.len()).min(fx.len()).min(vy.len());
        for i in 0..n {
            if fx[i].is_some() {
                continue;
            }
            let px = x[i];
            let py = y[i];
            let mut ax = 0.0_f32;
            let mut ay = 0.0_f32;
            for wave in &self.events {
                let (wx, wy) = wave.force_at(px, py, now_s);
                ax += wx;
                ay += wy;
            }
            vx[i] += ax * coupling;
            vy[i] += ay * coupling;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn standard_event(t_start_s: f64) -> WaveEvent {
        WaveEvent {
            center_x: 0.0,
            center_y: 0.0,
            t_start_s,
            speed_px_s: WaveEvent::DEFAULT_SPEED_PX_S,
            amplitude: 100.0,
            sigma_px: WaveEvent::DEFAULT_SIGMA_PX,
            decay_s: WaveEvent::DEFAULT_DECAY_S,
            max_radius_px: WaveEvent::DEFAULT_MAX_RADIUS_PX,
        }
    }

    #[test]
    fn force_at_is_zero_before_birth() {
        let w = standard_event(10.0);
        let (fx, fy) = w.force_at(100.0, 0.0, 9.9);
        assert_eq!(fx, 0.0);
        assert_eq!(fy, 0.0);
    }

    #[test]
    fn force_at_is_zero_beyond_max_radius() {
        let w = standard_event(0.0);
        let (fx, fy) = w.force_at(w.max_radius_px + 100.0, 0.0, 1.0);
        assert_eq!(fx, 0.0);
        assert_eq!(fy, 0.0);
    }

    #[test]
    fn force_at_is_radially_outward() {
        // +X direction → fx positive, fy zero.
        let w = standard_event(0.0);
        let (fx, fy) = w.force_at(200.0, 0.0, 0.6); // front at r=192
        assert!(fx > 0.0, "fx should point outward (+X) but was {}", fx);
        assert!(fy.abs() < 1e-4, "fy should be zero on the X-axis but was {}", fy);

        let (fx2, fy2) = w.force_at(-200.0, 0.0, 0.6);
        assert!(fx2 < 0.0, "fx should point outward (-X) but was {}", fx2);
        assert!(fy2.abs() < 1e-4, "fy should be zero on the X-axis but was {}", fy2);
    }

    #[test]
    fn force_at_peaks_at_expanding_front() {
        // At age=1s with speed 320, the shell peaks at r=320. Sampling
        // exactly at the front (shell max) should produce larger force
        // than the same radius at age=0s (front still at origin).
        let w = standard_event(0.0);
        let (fx_on_front, _) = w.force_at(320.0, 0.0, 1.0);
        let (fx_behind_front, _) = w.force_at(320.0, 0.0, 0.0);
        assert!(
            fx_on_front.abs() > fx_behind_front.abs() * 2.0,
            "on-front force {} should dominate off-front {}",
            fx_on_front,
            fx_behind_front
        );
    }

    #[test]
    fn force_at_respects_origin_clamp() {
        // Node at the exact centre returns zero (r_sq == 0 guard) —
        // avoids NaN from the inv_r division. Nearby nodes still get
        // bounded force via ORIGIN_CLAMP_PX on the 1/√r term.
        let w = standard_event(0.0);
        let (fx0, fy0) = w.force_at(0.0, 0.0, 0.5);
        assert_eq!(fx0, 0.0);
        assert_eq!(fy0, 0.0);

        let (fx_near, _) = w.force_at(1.0, 0.0, 0.5);
        assert!(fx_near.is_finite(), "near-origin force must be finite: {}", fx_near);
    }

    #[test]
    fn is_retired_true_after_decay_envelope_drops_below_threshold() {
        let w = standard_event(0.0);
        // decay_s = 0.9, so at age = 3 * decay_s = 2.7s envelope = e^-3 ≈ 0.05.
        // Slightly past that guarantees retirement.
        assert!(w.is_retired(3.0));
    }

    #[test]
    fn is_retired_false_before_decay_envelope_drops() {
        let w = standard_event(0.0);
        // At age = decay_s, envelope = 1/e ≈ 0.37 — well above 5%.
        assert!(!w.is_retired(0.9));
    }

    #[test]
    fn active_waves_emit_respects_capacity() {
        let mut w = ActiveWaves::new();
        for i in 0..ActiveWaves::CAPACITY + 5 {
            // Release velocity well above threshold.
            w.emit(i as f32, 0.0, 400.0, 0.0, i as f64 * 0.01);
        }
        assert_eq!(w.len(), ActiveWaves::CAPACITY);
    }

    #[test]
    fn active_waves_emit_evicts_oldest_first() {
        let mut w = ActiveWaves::new();
        // Fill the queue with events at distinguishable centres.
        for i in 0..ActiveWaves::CAPACITY {
            w.emit(i as f32, 0.0, 400.0, 0.0, i as f64 * 0.01);
        }
        let oldest_center = w.events[0].center_x;
        assert_eq!(oldest_center, 0.0);

        // One more emit should push out the first event.
        w.emit(1000.0, 0.0, 400.0, 0.0, 1.0);
        assert_eq!(w.len(), ActiveWaves::CAPACITY);
        assert_ne!(
            w.events[0].center_x, oldest_center,
            "oldest event should have been evicted"
        );
        assert_eq!(w.events[ActiveWaves::CAPACITY - 1].center_x, 1000.0);
    }

    #[test]
    fn active_waves_emit_skips_below_threshold_speed() {
        let mut w = ActiveWaves::new();
        w.emit(0.0, 0.0, 1.0, 0.0, 0.0); // below 5 px/s
        assert_eq!(w.len(), 0);

        w.emit(0.0, 0.0, 6.0, 0.0, 0.0); // above 5 px/s
        assert_eq!(w.len(), 1);
    }

    #[test]
    fn active_waves_emit_rejects_nonfinite_release_velocity() {
        let mut w = ActiveWaves::new();
        w.emit(0.0, 0.0, f32::NAN, 10.0, 0.0);
        w.emit(0.0, 0.0, 10.0, f32::INFINITY, 0.0);
        assert_eq!(w.len(), 0);
    }

    #[test]
    fn accumulate_is_no_op_with_empty_events() {
        let mut vx = vec![0.0_f32; 3];
        let mut vy = vec![0.0_f32; 3];
        let x = vec![0.0_f32, 100.0, -50.0];
        let y = vec![0.0_f32; 3];
        let fx: Vec<Option<f32>> = vec![None; 3];
        let w = ActiveWaves::new();

        w.accumulate(&mut vx, &mut vy, &x, &y, &fx, 0.2, 0.1);
        assert!(vx.iter().all(|&v| v == 0.0));
        assert!(vy.iter().all(|&v| v == 0.0));
    }

    #[test]
    fn accumulate_skips_fixed_nodes() {
        let mut vx = vec![0.0_f32; 2];
        let mut vy = vec![0.0_f32; 2];
        let x = vec![150.0_f32, 150.0]; // both inside max_radius
        let y = vec![0.0_f32; 2];
        // Node 0 is fixed (pinned), node 1 is free.
        let fx: Vec<Option<f32>> = vec![Some(150.0), None];
        let mut w = ActiveWaves::new();
        w.emit(0.0, 0.0, 400.0, 0.0, 0.0);

        w.accumulate(&mut vx, &mut vy, &x, &y, &fx, 0.2, 0.5);
        assert_eq!(vx[0], 0.0, "fixed node must not accumulate force");
        assert_ne!(vx[1], 0.0, "free node should accumulate force");
    }

    #[test]
    fn retire_finished_prunes_decayed_events() {
        let mut w = ActiveWaves::new();
        w.emit(0.0, 0.0, 400.0, 0.0, 0.0);
        w.emit(100.0, 0.0, 400.0, 0.0, 1.0);
        assert_eq!(w.len(), 2);
        // Advance sim-time past 3 × decay_s of the first event only.
        w.retire_finished(3.0);
        assert_eq!(w.len(), 1);
        assert_eq!(w.events[0].center_x, 100.0);
    }

    #[test]
    fn accumulate_bounded_even_with_full_capacity() {
        // All 8 events are sampled every tick — verify the summed
        // force at a typical distance is still finite and reasonable
        // (no numerical explosion from stacking).
        let mut w = ActiveWaves::new();
        for _ in 0..ActiveWaves::CAPACITY {
            w.emit(0.0, 0.0, 600.0, 0.0, 0.0);
        }
        let mut vx = vec![0.0_f32];
        let mut vy = vec![0.0_f32];
        let x = vec![320.0_f32]; // at the expanding front
        let y = vec![0.0_f32];
        let fx: Vec<Option<f32>> = vec![None];
        w.accumulate(&mut vx, &mut vy, &x, &y, &fx, 0.2, 1.0);
        assert!(vx[0].is_finite());
        assert!(vx[0].abs() < 5000.0, "wave stack produced implausible force: {}", vx[0]);
    }
}
