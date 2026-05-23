import Foundation
import QuartzCore

/// Adaptive frame-rate + thermal policy for the landing-wave renderer.
///
/// Goals (per user request, 2026-04-24):
///   - **120Hz** default on ProMotion displays
///   - Fall back to **60Hz** when the system reports Low Power Mode OR thermal
///     state has escalated past `.fair`
///   - Keep CPU/GPU usage proportional to actually-visible motion — the
///     renderer pauses entirely when occluded (handled by the host, not here)
///
/// Why this matters: `CAMetalDisplayLink` on macOS historically pegged at
/// 120Hz, which consumes 2–4× the resources needed for a mostly-idle surface.
/// Setting a `preferredFrameRateRange(min, max, preferred)` lets the system
/// glide down during idle periods and back up during active animation.
///
/// References:
///   - [Optimize for variable refresh rate displays — WWDC21 (Session 10147)](https://developer.apple.com/videos/play/wwdc2021/10147/)
///   - [CADisplayLink docs](https://developer.apple.com/documentation/quartzcore/cadisplaylink)
///   - [Running 120Hz with low latency (Apple forum)](https://developer.apple.com/forums/thread/763426)
///   - [ProcessInfo.isLowPowerModeEnabled](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled)
///   - [NSProcessInfo.thermalState](https://developer.apple.com/documentation/foundation/nsprocessinfo/1417480-thermalstate)
enum LandingWavePerformancePolicy {

    /// The cadence tiers the landing-wave renderer supports. The selected
    /// tier's frame-rate range is fed into `CAMetalDisplayLink`.
    enum Tier {
        /// Active drop choreography or visible micro-wave — aim for 120Hz on
        /// ProMotion, accept down to 60Hz on non-ProMotion displays.
        case high
        /// Low Power Mode or thermal fair/serious — cap at 60Hz.
        case low
        /// Thermal critical — downshift to 30Hz. Animation still runs, but at
        /// much lower cadence to let the system cool.
        case survival
    }

    /// Frame rate range for a given tier. Mirrors `CAFrameRateRange` ctor args
    /// without taking a hard dependency on QuartzCore at the enum site.
    struct Range {
        let minimum: Float
        let maximum: Float
        let preferred: Float
    }

    static func range(for tier: Tier) -> Range {
        switch tier {
        case .high:     return Range(minimum: 60, maximum: 120, preferred: 120)
        case .low:      return Range(minimum: 30, maximum: 60,  preferred: 60)
        case .survival: return Range(minimum: 15, maximum: 30,  preferred: 30)
        }
    }

    /// Determine which tier the current system state lands in. Prefer calling
    /// this on state-change notifications rather than every frame.
    ///
    /// 2026-05-20: when the user has flipped the master "Force maximum
    /// FPS" toggle (epistemos.graph.forceMaximumFPS UserDefault, owned
    /// by GraphState), every code path here pins to `.high` (60-120 fps
    /// preferred 120) regardless of thermal state or LPM. Explicit
    /// user opt-in to ProMotion's top rate.
    static func currentTier(
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> Tier {
        if UserDefaults.standard.bool(forKey: "epistemos.graph.forceMaximumFPS") {
            return .high
        }
        if thermalState == .critical { return .survival }
        if lowPowerMode || thermalState == .serious || thermalState == .fair { return .low }
        return .high
    }

    /// Produce a QuartzCore `CAFrameRateRange` for a tier. Kept separate from
    /// `Range` so unit tests can assert against plain floats without touching
    /// QuartzCore types.
    ///
    /// 2026-05-20: when `epistemos.graph.forceMaximumFPS` is on, this
    /// returns a tight 120/120/120 range so the wave's display link
    /// commits to ProMotion's top rate (no adaptive drop to 60 when the
    /// GPU slips momentarily).
    static func frameRateRange(for tier: Tier) -> CAFrameRateRange {
        if UserDefaults.standard.bool(forKey: "epistemos.graph.forceMaximumFPS") {
            return CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
        }
        let r = range(for: tier)
        return CAFrameRateRange(minimum: r.minimum, maximum: r.maximum, preferred: r.preferred)
    }
}
