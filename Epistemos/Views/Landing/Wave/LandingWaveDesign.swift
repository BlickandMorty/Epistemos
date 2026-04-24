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

    /// Target number of ASCII cells per 100pt of window width. 1 cell ≈ 7pt wide.
    static let cellsPer100ptWidth: CGFloat = 14
    /// Target number of ASCII cells per 100pt of window height. 1 cell ≈ 14pt tall.
    static let cellsPer100ptHeight: CGFloat = 7
    /// Minimum wave grid size regardless of window. Prevents degenerate 1×1 dispatches.
    static let minGridSize = SIMD2<Int32>(x: 80, y: 32)
    /// Maximum grid size cap. 200×100 = 20,000 cells — trivial for compute.
    static let maxGridSize = SIMD2<Int32>(x: 240, y: 120)

    // MARK: - Wave physics (linear 2D wave equation, see plan §6.1)

    /// Wave propagation speed squared. CFL stability requires c² ≤ 0.5 for a
    /// 4-neighbour Laplacian; 0.21 gives visible-but-not-snappy propagation.
    static let waveSpeedSquared: Float = 0.21
    /// Per-tick amplitude decay factor. 0.995 damps a ripple to ~0 over ~1.4s.
    static let waveDamping: Float = 0.995
    /// Ambient micro-wave amplitude after the initial drop has settled.
    /// Pool is never fully still — sells "alive" presence at ~0 GPU cost.
    static let ambientAmplitude: Float = 0.05
    /// Upper bound on concurrent in-flight drop impulses the shader will honor.
    static let maxInFlightDrops = 8

    // MARK: - ASCII luminance ramp (see plan §7.2)

    /// Density-sorted 12-character ramp used by the wave fragment shader.
    /// Index 0 (empty) is implicit; the shader maps height → index ∈ [0, 11].
    static let luminanceRamp: [Character] = [
        " ", "·", ".", "-", "~", ":", "+", "*", "░", "▒", "▓", "█",
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
        static let splashCrown: Int = 30
        static let crater: Int = 60
        static let worthingtonJet: Int = 120
        static let secondaryDroplet: Int = 200
        static let concentricWavesStart: Int = 250
        static let barRimStart: Int = 350
        static let chromeFadeStart: Int = 480
        static let settle: Int = 550
    }

    /// Strength multipliers applied to each beat's primary impulse.
    enum DropBeatStrength {
        static let impactFlash: Float = 4.0
        static let splashCrown: Float = 1.8
        static let crater: Float = -2.5  // negative — forms the cavity
        static let worthingtonJet: Float = 3.0
        static let secondaryDroplet: Float = 0.6
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
    static let barEmergenceDuration: Double = 0.20
    /// Initial vertical offset before chrome springs to rest position.
    static let barEmergenceOffset: CGFloat = 14
    /// Initial scale before the emergence spring.
    static let barEmergenceScale: CGFloat = 0.92

    // MARK: - Water trail (see plan §8.4)

    /// Window (seconds from click) during which the water-trail column is active.
    static let waterTrailWindow: ClosedRange<Double> = 0.30...0.48
    /// The snap frame: single frame of maximum stretch before the break.
    static let waterTrailSnapMoment: Double = 0.42

    // MARK: - Haptic beat (see plan §9)

    enum HapticBeatDelay {
        static let impact: Double = 0.00
        static let worthingtonJet: Double = 0.12
        static let waveCrest: Double = 0.30
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
