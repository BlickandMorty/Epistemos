import CoreGraphics
import Foundation

/// Design constants for the landing liquid-wave search surface.
///
/// All numeric tokens live here so the spec in docs/LANDING_WAVE_SEARCH_PLAN.md
/// has a single authoritative source in code. Every magic number in this feature
/// should trace back to a constant here.
enum LandingWaveDesign {

    // MARK: - Compact flat bar dimensions

    /// Width bounds for the compact flat search bar. Landing-only; smaller than
    /// the 900pt legacy popover width per §8.1 of the plan.
    static let barMaxWidth: CGFloat = 520
    static let barMinWidth: CGFloat = 420
    static let barHeight: CGFloat = 44
    static let barCornerRadius: CGFloat = 12
    static let barHorizontalPadding: CGFloat = 14
    static let barTopPadding: CGFloat = 10
    static let barBottomPadding: CGFloat = 10
    static let barControlRowSpacing: CGFloat = 6
    static let barInputFontSize: CGFloat = 14
    static let barStrokeWidth: CGFloat = 1
    static let barStrokeOpacity: Double = 0.28

    // MARK: - Wave grid

    /// Target number of ASCII cells per 100pt of window width. Dense enough for
    /// a visible warp texture while staying bounded to the click neighborhood.
    static let cellsPer100ptWidth: CGFloat = 20
    /// Target number of ASCII cells per 100pt of window height.
    static let cellsPer100ptHeight: CGFloat = 12
    /// Minimum wave grid size regardless of window. Prevents degenerate 1×1 dispatches.
    static let minGridSize = SIMD2<Int32>(x: 96, y: 48)
    /// Maximum grid size cap. 240×136 = 32,640 cells — denser than the old
    /// pool at normal window sizes without expanding full-screen cost.
    static let maxGridSize = SIMD2<Int32>(x: 240, y: 136)

    // MARK: - Wave physics (linear 2D wave equation, see plan §6.1)

    /// Wave propagation speed squared. CFL stability requires c² ≤ 0.5 for a
    /// 4-neighbour Laplacian; 0.16 keeps the click bloom slower and tighter.
    static let waveSpeedSquared: Float = 0.16
    /// Per-tick amplitude decay factor. Tightened so the smaller click bloom
    /// resolves cleanly instead of expanding across the whole landing page.
    static let waveDamping: Float = 0.988
    /// Ambient micro-wave amplitude after the initial drop has settled.
    /// Keep the resting surface nearly still; the click should read as a
    /// compact warp, not a full-screen pool.
    static let ambientAmplitude: Float = 0.006
    /// Upper bound on concurrent in-flight drop impulses the shader will honor.
    static let maxInFlightDrops = 8

    // MARK: - ASCII luminance ramp (see plan §7.2)

    /// Density-sorted 16-character ramp used by the wave fragment shader.
    /// Index 0 (empty) is implicit; the shader maps height → the ramp.
    static let luminanceRamp: [Character] = [
        " ", ".", ":", ";", "i", "l", "!", "+", "*", "x", "%", "#", "░", "▓", "█", "@",
    ]

    /// Box-drawing glyph set for the bar-rim emergence beat (see plan §8.3).
    /// These are painted as sprites on top of the wave buffer for ~150ms.
    static let barRimGlyphs: [Character] = [
        "┌", "┐", "└", "┘", "─", "│", "┬", "┴", "├", "┤", "┼", "╔", "╗", "╚", "╝",
    ]

    /// Column glyphs used for the "water-trail" while the bar is mid-emergence
    /// (see plan §8.4). Height field values at the column sample these.
    static let waterTrailGlyphs: [Character] = ["│", "┃", "┆", "┇"]

    /// Droplet glyphs for the secondary-droplet fall-back (see plan §6.3, t=200ms).
    static let dropletGlyphs: [Character] = ["·", "∙", "•"]

    // MARK: - Drop impact choreography (see plan §6.3)
    //
    // Timings are milliseconds from click-time. The renderer dispatches impulses
    // on the first frame whose timestamp exceeds each beat.

    enum DropBeatMillis {
        static let impactFlash: Int = 0
        static let splashCrown: Int = 90
        static let crater: Int = 160
        static let worthingtonJet: Int = 260
        static let secondaryDroplet: Int = 420
        static let concentricWavesStart: Int = 360
        static let barRimStart: Int = 480
        static let chromeFadeStart: Int = 640
        static let settle: Int = 920
    }

    /// Strength multipliers applied to each beat's primary impulse. Boosted
    /// on 2026-04-24 so the wave reads clearly on the landing backdrop — the
    /// earlier values produced ripples that were technically correct but
    /// visually subtle.
    enum DropBeatStrength {
        static let impactFlash: Float = 4.9
        static let splashCrown: Float = 2.1
        static let crater: Float = -3.8  // negative — forms the cavity
        static let worthingtonJet: Float = 2.8
        static let secondaryDroplet: Float = 0.7
    }

    // MARK: - Anisotropic ripple (see plan §6.2)

    /// Forward-bias amplitude for the anisotropic ripple term. 0.0 = perfectly
    /// radial; higher values accentuate the direction of cursor motion.
    static let anisotropicBiasAmplitude: Float = 0.4
    /// Seconds of cursor motion to remember when inferring direction. After
    /// this window with no movement, the ripple reverts to radial.
    static let cursorMotionMemorySeconds: Double = 0.6

    // MARK: - Bar emergence (see plan §8.3)

    /// Total duration of the bar chrome fade-in + overshoot, seconds.
    /// Tightened (2026-04-24) from 0.20s → 0.14s per user feedback that
    /// earlier timing felt "lack luster." Snappier = stronger snap.
    static let barEmergenceDuration: Double = 0.14
    /// Initial vertical offset before chrome springs to rest position.
    /// Reduced with duration so the motion still completes cleanly.
    static let barEmergenceOffset: CGFloat = 16
    /// Initial scale before the emergence spring. Slightly more compressed
    /// than before for a more assertive pop-out.
    static let barEmergenceScale: CGFloat = 0.88

    // MARK: - Water trail (see plan §8.4)

    /// Window (seconds from click) during which the water-trail column is active.
    static let waterTrailWindow: ClosedRange<Double> = 0.30...0.48
    /// The snap frame: single frame of maximum stretch before the break.
    static let waterTrailSnapMoment: Double = 0.42

    // MARK: - Haptic beat (see plan §9)

    enum HapticBeatDelay {
        static let impact: Double = 0.00
        static let worthingtonJet: Double = 0.19
        static let waveCrest: Double = 0.42
    }

    // MARK: - Glyph atlas

    /// Cell dimensions in the atlas texture (pixels). SF Mono 14pt with 2× HiDPI
    /// rasterization → 32×32 cell is enough headroom for any ramp glyph.
    static let atlasCellSize = SIMD2<Int32>(x: 32, y: 32)
    /// Atlas grid dimensions (cells). 64×32 = 2048 cells, far more than needed.
    static let atlasGridSize = SIMD2<Int32>(x: 64, y: 32)

    /// Authoritative list of every glyph baked into the atlas. Deterministic
    /// ordering: ramp first, then rim, then trail, then droplets. Tests rely
    /// on this order; do not shuffle.
    static let atlasGlyphOrder: [Character] = Array(
        luminanceRamp + barRimGlyphs + waterTrailGlyphs + dropletGlyphs
    )
}
