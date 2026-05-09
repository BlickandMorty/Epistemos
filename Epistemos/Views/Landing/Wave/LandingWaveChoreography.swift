import CoreGraphics
import Foundation

/// Scheduled drop-impulse event — "fire this impulse N seconds after click."
///
/// The renderer queues these at click time, then dispatches them to the GPU
/// on the first frame whose timestamp exceeds each beat. After dispatch each
/// event is removed from the queue so the shader injects the impulse exactly
/// once.
struct LandingWaveDropEvent: Equatable {
    /// Seconds from click time when this impulse fires.
    let timeOffset: Double
    /// Cell coordinates in grid space (anchored at click point; see makeSequence).
    let position: SIMD2<Float>
    /// Gaussian radius in cells.
    let radius: Float
    /// Amplitude — can be negative for the cavity beat.
    let strength: Float
}

/// Builds the canonical drop-impact sequence at a specific click location in
/// grid-cell coordinates. All timings and strengths trace back to the design
/// constants in `LandingWaveDesign` and the spec in
/// `docs/LANDING_WAVE_SEARCH_PLAN.md` §6.3.
enum LandingWaveChoreography {

    /// Compact ASCII warp sequence: impact → small orbital crown → negative
    /// gravity well → rebound → a few delayed orbital sparks. The visual
    /// should stay local to the click instead of blooming across the landing.
    static func makeSequence(
        at click: SIMD2<Float>,
        cursorDirection: SIMD2<Float>
    ) -> [LandingWaveDropEvent] {
        let dir = normalizeOrZero(cursorDirection)

        var events: [LandingWaveDropEvent] = []

        // t=0 — single-cell bright impact.
        events.append(
            LandingWaveDropEvent(
                timeOffset: ms(LandingWaveDesign.DropBeatMillis.impactFlash),
                position: click,
                radius: 0.48,
                strength: LandingWaveDesign.DropBeatStrength.impactFlash
            )
        )

        // t=90 — compact orbit ring. Cursor direction biases brightness, not radius.
        let crownRadius: Float = 1.18
        for i in 0..<8 {
            let theta = Float(i) / 8.0 * 2.0 * .pi
            let forwardBias = max(0, dot2D(SIMD2<Float>(cos(theta), sin(theta)), dir)) * 0.6 + 0.4
            let offset = SIMD2<Float>(cos(theta), sin(theta)) * crownRadius
            events.append(
                LandingWaveDropEvent(
                    timeOffset: ms(LandingWaveDesign.DropBeatMillis.splashCrown),
                    position: click + offset,
                    radius: 0.42,
                    strength: LandingWaveDesign.DropBeatStrength.splashCrown * forwardBias
                )
            )
        }

        // t=160 — gravity well: negative impulse pulls the field inward.
        events.append(
            LandingWaveDropEvent(
                timeOffset: ms(LandingWaveDesign.DropBeatMillis.crater),
                position: click,
                radius: 0.98,
                strength: LandingWaveDesign.DropBeatStrength.crater
            )
        )

        // t=260 — rebound in the center.
        events.append(
            LandingWaveDropEvent(
                timeOffset: ms(LandingWaveDesign.DropBeatMillis.worthingtonJet),
                position: click,
                radius: 0.72,
                strength: LandingWaveDesign.DropBeatStrength.worthingtonJet
            )
        )

        // t=300-420 — a slow clockwise spiral of tiny ASCII sparks.
        for i in 0..<4 {
            let theta = Float(i) / 4.0 * 2.0 * .pi + .pi / 4.0
            let radius = Float(0.72 - Double(i) * 0.12)
            let offset = SIMD2<Float>(cos(theta), sin(theta)) * radius
            events.append(
                LandingWaveDropEvent(
                    timeOffset: ms(LandingWaveDesign.DropBeatMillis.worthingtonJet + 40 + i * 34),
                    position: click + offset,
                    radius: 0.32,
                    strength: LandingWaveDesign.DropBeatStrength.secondaryDroplet * (1.0 - Float(i) * 0.12)
                )
            )
        }

        // t=420 — final tiny dot above the well.
        events.append(
            LandingWaveDropEvent(
                timeOffset: ms(LandingWaveDesign.DropBeatMillis.secondaryDroplet),
                position: click + SIMD2<Float>(0, -1.05),
                radius: 0.34,
                strength: LandingWaveDesign.DropBeatStrength.secondaryDroplet
            )
        )

        return events
    }

    /// Convert a millisecond beat to a seconds `TimeInterval`.
    private static func ms(_ milliseconds: Int) -> Double {
        Double(milliseconds) / 1000.0
    }

    private static func normalizeOrZero(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let m = sqrt(v.x * v.x + v.y * v.y)
        guard m > 0.001 else { return SIMD2<Float>(0, 0) }
        return v / m
    }

    private static func dot2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.x + a.y * b.y
    }
}
