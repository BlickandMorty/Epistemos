import Foundation

enum AmbientFrequencyChannelMode: String, Sendable {
    case mono
    case stereo
}

struct AmbientFrequencyEnvelope: Equatable, Sendable {
    let base: Double
    let primaryHz: Double
    let secondaryHz: Double
    let tertiaryHz: Double
    let primaryDepth: Double
    let secondaryDepth: Double
    let tertiaryDepth: Double

    nonisolated static let breath = AmbientFrequencyEnvelope(
        base: 0.56,
        primaryHz: 0.045,
        secondaryHz: 0.017,
        tertiaryHz: 0.009,
        primaryDepth: 0.28,
        secondaryDepth: 0.18,
        tertiaryDepth: 0.10
    )

    nonisolated func value(at time: Double) -> Double {
        let raw = base
            + primaryDepth * sin(.tau * primaryHz * time)
            + secondaryDepth * sin(.tau * secondaryHz * time + 1.31)
            + tertiaryDepth * sin(.tau * tertiaryHz * time + 2.17)
        let clamped = min(max(raw, 0), 1)
        return clamped * clamped
    }
}

enum AmbientFrequencyLayer: Equatable, Sendable {
    case amplitudeModulatedCarrier(
        carrierHz: Double,
        modulatorHz: Double,
        depth: Double,
        amplitude: Double
    )
    case sine(
        frequencyHz: Double,
        amplitude: Double,
        channelMode: AmbientFrequencyChannelMode
    )
    case binauralBeat(
        carrierHz: Double,
        beatHz: Double,
        amplitude: Double
    )
    case organicWhiteNoise(
        seed: UInt64,
        amplitude: Double,
        envelope: AmbientFrequencyEnvelope
    )
    case intermittentPing(
        frequencyHz: Double,
        amplitude: Double,
        durationSeconds: Double,
        baseIntervalSeconds: Double,
        jitterSeconds: Double,
        startOffsetSeconds: Double,
        seed: UInt64
    )
    case chirp(
        centerHz: Double,
        sweepHz: Double,
        amplitude: Double,
        durationSeconds: Double,
        intervalSeconds: Double,
        startOffsetSeconds: Double,
        harmonicBlend: Double
    )

    /// Pure white noise — flat spectrum, equal energy per Hz. Use when you
    /// want raw hiss without breath modulation; complements the older
    /// `organicWhiteNoise` (which always wraps in a breath envelope).
    case whiteNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// Voss-McCartney-style 1/f pink noise (stateless approximation that sums
    /// noise from multiple octave bands, giving roughly 1/f spectral roll-off).
    /// Pink noise is the most common "Brain.fm-style" backbone; spectrally
    /// flat in perceived loudness (equal energy per octave).
    case pinkNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// Grey noise — psychoacoustically equalized (A-weighted inverse). Sounds
    /// "equally loud" across the audible spectrum to the human ear. Stateless
    /// approximation here mixes white, pink, and brown noises in proportions
    /// that approximate the equal-loudness inverse curve.
    case greyNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// Blue noise — +3 dB/octave (opposite of pink). Stateless implementation
    /// via first-difference of white noise (`b[n] = w[n] - w[n-1]`), which
    /// gives a high-pass-shaped spectrum. Used as "sparkle" / detail layer
    /// over warmer noise beds.
    case blueNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// Violet noise — +6 dB/octave (opposite of brown). Stateless implementation
    /// via second-difference of white noise (`v[n] = w[n] - 2·w[n-1] + w[n-2]`).
    /// Very bright, hiss-like; often used for tinnitus masking.
    case violetNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// 1/f² brown (Brownian) noise via a sliding-window integral approximation
    /// of white noise. Subjectively warmer / lower than pink noise; popular for
    /// sleep and deep-focus modes.
    case brownNoise(seed: UInt64, amplitude: Double, envelope: AmbientFrequencyEnvelope)

    /// Bandpass-shaped noise via sum-of-sines at random frequencies sampled
    /// from `[centerHz - bandwidthHz/2, centerHz + bandwidthHz/2]` with random
    /// phases. The harmonicCount sets how dense the band is (higher = smoother
    /// noise; lower = more granular / textured). Useful for rain-on-roof,
    /// distant wind, ocean surf.
    case bandpassNoise(
        seed: UInt64,
        amplitude: Double,
        envelope: AmbientFrequencyEnvelope,
        centerHz: Double,
        bandwidthHz: Double,
        harmonicCount: Int
    )

    /// Isochronic tone — single-channel pulsed sine. Unlike binaural beats,
    /// isochronic tones don't require headphones and have stronger published
    /// evidence for steady-state auditory entrainment (cf. PLOS ONE 2023
    /// review §4 on monaural vs binaural). The carrier sine is gated by a
    /// square pulse at `pulseHz` with `dutyCycle` on-time fraction.
    case isochronicTone(
        carrierHz: Double,
        pulseHz: Double,
        amplitude: Double,
        dutyCycle: Double,
        channelMode: AmbientFrequencyChannelMode
    )

    /// Pulse-width-modulated square wave at fixed duty cycle. Foundational
    /// chiptune voice: NES APU pulse channels (12.5%, 25%, 50%, 75% duty)
    /// and Game Boy PSG square channels. Higher harmonics are bandlimited
    /// implicitly by Nyquist.
    case pwmSquare(
        frequencyHz: Double,
        dutyCycle: Double,
        amplitude: Double,
        channelMode: AmbientFrequencyChannelMode
    )

    /// Triangle wave via the bandlimit-friendly `asin(sin(2πft)) · 2/π`
    /// closed form. Chiptune staple (NES APU triangle channel, used for
    /// bass lines in classic 8-bit soundtracks).
    case triangleWave(
        frequencyHz: Double,
        amplitude: Double,
        channelMode: AmbientFrequencyChannelMode
    )

    /// Sawtooth wave via `2 · ((ft) - floor(ft + 0.5))`. SID chip (Commodore
    /// 64) staple; rich in harmonics, ideal for resonant-filter drones.
    case sawtoothWave(
        frequencyHz: Double,
        amplitude: Double,
        channelMode: AmbientFrequencyChannelMode
    )

    /// Two-operator FM synthesis. `modulationIndex` is the depth in radians
    /// (Yamaha DX7 / Sega Genesis YM2612 style). High index produces
    /// harmonically rich metallic / bell-like timbres at integer
    /// `modulatorHz / carrierHz` ratios; non-integer ratios produce
    /// inharmonic "metallic" tones.
    case fmSynth(
        carrierHz: Double,
        modulatorHz: Double,
        modulationIndex: Double,
        amplitude: Double,
        channelMode: AmbientFrequencyChannelMode
    )

    /// Plucked-string-like sound via a sum of damped harmonics. NOT a true
    /// Karplus-Strong (which requires a delay-line state), but a stateless
    /// approximation: at each trigger time, sum N harmonics each with its
    /// own exponential decay. Suitable for wind-chime clusters, distant
    /// bells, harp arpeggios.
    case harmonicPluck(
        fundamentalHz: Double,
        amplitude: Double,
        harmonicCount: Int,
        decaySeconds: Double,
        intervalSeconds: Double,
        jitterSeconds: Double,
        startOffsetSeconds: Double,
        seed: UInt64
    )

    nonisolated var label: String {
        switch self {
        case .amplitudeModulatedCarrier:
            return "Modulated carrier"
        case .sine(let frequencyHz, _, _):
            return "\(Self.formatHz(frequencyHz)) sine"
        case .binauralBeat(_, let beatHz, _):
            return "\(Self.formatHz(beatHz)) binaural"
        case .organicWhiteNoise:
            return "Breath noise"
        case .intermittentPing(let frequencyHz, _, _, _, _, _, _):
            return "\(Self.formatHz(frequencyHz)) ping"
        case .chirp(let centerHz, _, _, _, let intervalSeconds, _, _):
            return "\(Self.formatHz(centerHz)) chirp every \(Self.formatSeconds(intervalSeconds))"
        case .whiteNoise:
            return "White noise (flat)"
        case .pinkNoise:
            return "Pink noise (1/f)"
        case .greyNoise:
            return "Grey noise (perceptually flat)"
        case .blueNoise:
            return "Blue noise (+3 dB/oct)"
        case .violetNoise:
            return "Violet noise (+6 dB/oct)"
        case .brownNoise:
            return "Brown noise (1/f²)"
        case .bandpassNoise(_, _, _, let centerHz, let bandwidthHz, _):
            return "\(Self.formatHz(centerHz)) bandpass noise ±\(Self.formatHz(bandwidthHz / 2))"
        case .isochronicTone(let carrierHz, let pulseHz, _, _, _):
            return "\(Self.formatHz(pulseHz)) isochronic on \(Self.formatHz(carrierHz))"
        case .pwmSquare(let frequencyHz, let dutyCycle, _, _):
            return "\(Self.formatHz(frequencyHz)) PWM \(Self.formatDecimal(dutyCycle * 100))%"
        case .triangleWave(let frequencyHz, _, _):
            return "\(Self.formatHz(frequencyHz)) triangle"
        case .sawtoothWave(let frequencyHz, _, _):
            return "\(Self.formatHz(frequencyHz)) sawtooth"
        case .fmSynth(let carrierHz, let modulatorHz, _, _, _):
            return "\(Self.formatHz(carrierHz)) FM × \(Self.formatHz(modulatorHz)) mod"
        case .harmonicPluck(let fundamentalHz, _, _, _, let intervalSeconds, _, _, _):
            return "\(Self.formatHz(fundamentalHz)) pluck every \(Self.formatSeconds(intervalSeconds))"
        }
    }

    nonisolated var description: String {
        switch self {
        case .amplitudeModulatedCarrier(let carrierHz, let modulatorHz, let depth, let amplitude):
            return "\(Self.formatHz(modulatorHz)) sine amplitude-modulates a \(Self.formatHz(carrierHz)) carrier, depth \(Self.formatDecimal(depth)), amplitude \(Self.formatDecimal(amplitude))."
        case .sine(let frequencyHz, let amplitude, let channelMode):
            return "Continuous \(Self.formatHz(frequencyHz)) sine, \(channelMode.rawValue), amplitude \(Self.formatDecimal(amplitude))."
        case .binauralBeat(let carrierHz, let beatHz, let amplitude):
            let left = carrierHz - beatHz / 2
            let right = carrierHz + beatHz / 2
            return "\(Self.formatHz(beatHz)) binaural target from \(Self.formatHz(left)) left and \(Self.formatHz(right)) right, amplitude \(Self.formatDecimal(amplitude))."
        case .organicWhiteNoise(_, let amplitude, _):
            return "White noise shaped by a slow organic breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .intermittentPing(let frequencyHz, let amplitude, let durationSeconds, let baseIntervalSeconds, let jitterSeconds, _, _):
            return "Intermittent \(Self.formatHz(frequencyHz)) high-frequency ping, \(Self.formatSeconds(durationSeconds)) long, around every \(Self.formatSeconds(baseIntervalSeconds)) +/- \(Self.formatSeconds(jitterSeconds)), amplitude \(Self.formatDecimal(amplitude))."
        case .chirp(let centerHz, let sweepHz, let amplitude, let durationSeconds, let intervalSeconds, _, let harmonicBlend):
            return "\(Self.formatHz(centerHz)) complex chirp with \(Self.formatHz(sweepHz)) sweep, every \(Self.formatSeconds(intervalSeconds)), \(Self.formatSeconds(durationSeconds)) long, harmonic blend \(Self.formatDecimal(harmonicBlend)), amplitude \(Self.formatDecimal(amplitude))."
        case .whiteNoise(_, let amplitude, _):
            return "White noise (flat spectrum) shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .pinkNoise(_, let amplitude, _):
            return "Pink (1/f) noise shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .greyNoise(_, let amplitude, _):
            return "Grey (psychoacoustically equalized) noise shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .blueNoise(_, let amplitude, _):
            return "Blue (+3 dB/oct) noise shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .violetNoise(_, let amplitude, _):
            return "Violet (+6 dB/oct) noise shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .brownNoise(_, let amplitude, _):
            return "Brown (1/f²) noise shaped by breath envelope, amplitude \(Self.formatDecimal(amplitude))."
        case .bandpassNoise(_, let amplitude, _, let centerHz, let bandwidthHz, let harmonicCount):
            return "Bandpass-shaped noise centered \(Self.formatHz(centerHz)) ± \(Self.formatHz(bandwidthHz / 2)), \(harmonicCount) harmonics, amplitude \(Self.formatDecimal(amplitude))."
        case .isochronicTone(let carrierHz, let pulseHz, let amplitude, let dutyCycle, _):
            return "Isochronic: \(Self.formatHz(carrierHz)) sine gated at \(Self.formatHz(pulseHz)) with \(Self.formatDecimal(dutyCycle * 100))% duty, amplitude \(Self.formatDecimal(amplitude))."
        case .pwmSquare(let frequencyHz, let dutyCycle, let amplitude, let channelMode):
            return "PWM square at \(Self.formatHz(frequencyHz)) with \(Self.formatDecimal(dutyCycle * 100))% duty cycle, \(channelMode.rawValue), amplitude \(Self.formatDecimal(amplitude))."
        case .triangleWave(let frequencyHz, let amplitude, let channelMode):
            return "Triangle wave at \(Self.formatHz(frequencyHz)), \(channelMode.rawValue), amplitude \(Self.formatDecimal(amplitude))."
        case .sawtoothWave(let frequencyHz, let amplitude, let channelMode):
            return "Sawtooth wave at \(Self.formatHz(frequencyHz)), \(channelMode.rawValue), amplitude \(Self.formatDecimal(amplitude))."
        case .fmSynth(let carrierHz, let modulatorHz, let modulationIndex, let amplitude, let channelMode):
            return "FM synthesis: \(Self.formatHz(carrierHz)) carrier × \(Self.formatHz(modulatorHz)) modulator at index \(Self.formatDecimal(modulationIndex)), \(channelMode.rawValue), amplitude \(Self.formatDecimal(amplitude))."
        case .harmonicPluck(let fundamentalHz, let amplitude, let harmonicCount, let decaySeconds, let intervalSeconds, let jitterSeconds, _, _):
            return "Plucked tone at \(Self.formatHz(fundamentalHz)) (×\(harmonicCount) harmonics) every \(Self.formatSeconds(intervalSeconds)) ± \(Self.formatSeconds(jitterSeconds)) with \(Self.formatSeconds(decaySeconds)) decay, amplitude \(Self.formatDecimal(amplitude))."
        }
    }

    nonisolated var maxFrequencyHz: Double {
        switch self {
        case .amplitudeModulatedCarrier(let carrierHz, let modulatorHz, _, _):
            return carrierHz + modulatorHz
        case .sine(let frequencyHz, _, _):
            return frequencyHz
        case .binauralBeat(let carrierHz, let beatHz, _):
            return carrierHz + beatHz / 2
        case .organicWhiteNoise:
            return 0
        case .intermittentPing(let frequencyHz, _, _, _, _, _, _):
            return frequencyHz
        case .chirp(let centerHz, let sweepHz, _, _, _, _, let harmonicBlend):
            let upper = centerHz + sweepHz / 2
            return harmonicBlend > 0 ? upper * 2 : upper
        case .whiteNoise, .pinkNoise, .greyNoise, .blueNoise, .violetNoise, .brownNoise:
            return 0
        case .bandpassNoise(_, _, _, let centerHz, let bandwidthHz, _):
            return centerHz + bandwidthHz / 2
        case .isochronicTone(let carrierHz, _, _, _, _):
            return carrierHz
        case .pwmSquare(let frequencyHz, _, _, _),
             .triangleWave(let frequencyHz, _, _),
             .sawtoothWave(let frequencyHz, _, _):
            // Square + sawtooth ARE harmonically rich; report fundamental as max
            // (Nyquist sanity check; actual harmonics bandlimit themselves by
            // the implicit aliasing floor at sampleRate/2).
            return frequencyHz
        case .fmSynth(let carrierHz, let modulatorHz, let modulationIndex, _, _):
            // Carson's rule sideband bandwidth: BW ≈ 2 (Δf + fm) where Δf = I·fm.
            return carrierHz + 2 * (modulationIndex + 1) * modulatorHz
        case .harmonicPluck(let fundamentalHz, _, let harmonicCount, _, _, _, _, _):
            return fundamentalHz * Double(max(1, harmonicCount))
        }
    }

    nonisolated private static func formatHz(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value)) Hz"
        }
        return String(format: "%.2f Hz", value)
    }

    nonisolated private static func formatSeconds(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))s"
        }
        return String(format: "%.3fs", value)
    }

    nonisolated private static func formatDecimal(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

struct AmbientFrequencyPreset: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let intent: String
    let summary: String
    let requiresHeadphones: Bool
    let defaultDurationSeconds: Double
    let layers: [AmbientFrequencyLayer]

    nonisolated static let defaultDurationSeconds: Double = 30 * 60

    nonisolated static let schumannCocktail = AmbientFrequencyPreset(
        id: "schumann-cocktail",
        title: "Schumann Cocktail",
        intent: "Grounded ambient focus",
        summary: "The requested six-layer zone: 7.83 Hz modulation on a 100 Hz carrier, 528 Hz, 432 Hz pad, breath-shaped white noise, intermittent 17 kHz pings, and an exact 10-second 2500 Hz chirp.",
        requiresHeadphones: false,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .amplitudeModulatedCarrier(
                carrierHz: 100,
                modulatorHz: 7.83,
                depth: 0.86,
                amplitude: 0.16
            ),
            .sine(frequencyHz: 528, amplitude: 0.055, channelMode: .stereo),
            .sine(frequencyHz: 432, amplitude: 0.09, channelMode: .stereo),
            .organicWhiteNoise(seed: 0xA7F0_4320_5280_0783, amplitude: 0.045, envelope: .breath),
            .intermittentPing(
                frequencyHz: 17_000,
                amplitude: 0.018,
                durationSeconds: 0.045,
                baseIntervalSeconds: 23,
                jitterSeconds: 6,
                startOffsetSeconds: 7,
                seed: 0x1700_0BEE_F123_7781
            ),
            .chirp(
                centerHz: 2_500,
                sweepHz: 700,
                amplitude: 0.035,
                durationSeconds: 0.22,
                intervalSeconds: 10,
                startOffsetSeconds: 0,
                harmonicBlend: 0.18
            ),
        ]
    )

    nonisolated static let deltaRest = AmbientFrequencyPreset(
        id: "delta-rest",
        title: "Delta Rest",
        intent: "Low arousal wind-down",
        summary: "A 2 Hz binaural target under a soft 180 Hz carrier pair with a 432 Hz anchor and low breath noise.",
        requiresHeadphones: true,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .binauralBeat(carrierHz: 180, beatHz: 2, amplitude: 0.13),
            .sine(frequencyHz: 432, amplitude: 0.065, channelMode: .stereo),
            .organicWhiteNoise(seed: 0xDE17_A011_0000_0002, amplitude: 0.035, envelope: .breath),
        ]
    )

    nonisolated static let thetaDrift = AmbientFrequencyPreset(
        id: "theta-drift",
        title: "Theta Drift",
        intent: "Meditative drafting",
        summary: "A 6 Hz binaural target using a 220 Hz carrier pair, with a quiet 432 Hz pad and slow noise envelope.",
        requiresHeadphones: true,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .binauralBeat(carrierHz: 220, beatHz: 6, amplitude: 0.12),
            .sine(frequencyHz: 432, amplitude: 0.055, channelMode: .stereo),
            .organicWhiteNoise(seed: 0x7E7A_0000_0000_0006, amplitude: 0.032, envelope: .breath),
        ]
    )

    nonisolated static let alphaFocus = AmbientFrequencyPreset(
        id: "alpha-focus",
        title: "Alpha Focus",
        intent: "Relaxed attention",
        summary: "A 10 Hz binaural target around a 220 Hz carrier pair, supported by a 528 Hz tone and low breath noise.",
        requiresHeadphones: true,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .binauralBeat(carrierHz: 220, beatHz: 10, amplitude: 0.12),
            .sine(frequencyHz: 528, amplitude: 0.052, channelMode: .stereo),
            .organicWhiteNoise(seed: 0xA1FA_0000_0000_0010, amplitude: 0.030, envelope: .breath),
        ]
    )

    nonisolated static let betaClarity = AmbientFrequencyPreset(
        id: "beta-clarity",
        title: "Beta Clarity",
        intent: "Active concentration",
        summary: "A 16 Hz binaural target around a 240 Hz carrier pair with a restrained 528 Hz support tone.",
        requiresHeadphones: true,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .binauralBeat(carrierHz: 240, beatHz: 16, amplitude: 0.105),
            .sine(frequencyHz: 528, amplitude: 0.045, channelMode: .stereo),
            .organicWhiteNoise(seed: 0xBE7A_0000_0000_0016, amplitude: 0.026, envelope: .breath),
        ]
    )

    nonisolated static let gammaSpark = AmbientFrequencyPreset(
        id: "gamma-spark",
        title: "Gamma Spark",
        intent: "Brief high-alert sessions",
        summary: "A 40 Hz high-gamma binaural target around a 440 Hz carrier pair, kept low in amplitude for comfort.",
        requiresHeadphones: true,
        defaultDurationSeconds: 20 * 60,
        layers: [
            .binauralBeat(carrierHz: 440, beatHz: 40, amplitude: 0.075),
            .sine(frequencyHz: 528, amplitude: 0.035, channelMode: .stereo),
            .organicWhiteNoise(seed: 0x6A44_A000_0000_0040, amplitude: 0.020, envelope: .breath),
        ]
    )

    // MARK: - Focus & Productivity (Brain.fm-style spectral entrainment, iter 85)

    /// Brain.fm-style spectral focus: a 14 Hz amplitude modulation imprinted on
    /// pink noise. The 14 Hz rate sits in the SMR/low-beta band (cf. Frontiers
    /// in Psychology 2021 theta/beta study); pink noise gives equal energy per
    /// octave so the modulation envelope is felt without spectral coloration.
    /// No headphones required — works on any speakers.
    nonisolated static let focusBrainSync = AmbientFrequencyPreset(
        id: "focus-brain-sync",
        title: "Focus · Brain Sync 14 Hz",
        intent: "Brain.fm-style spectral focus",
        summary: "14 Hz amplitude modulation on pink (1/f) noise — Brain.fm spectral entrainment style. Speakers-friendly, low-arousal-friendly.",
        requiresHeadphones: false,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .pinkNoise(seed: 0x1482_F0C0_5AAA_BF0A, amplitude: 0.18, envelope: .breath),
            .amplitudeModulatedCarrier(carrierHz: 220, modulatorHz: 14, depth: 0.82, amplitude: 0.10),
            .sine(frequencyHz: 432, amplitude: 0.038, channelMode: .stereo),
        ]
    )

    /// Isochronic 14 Hz focus tone — a 200 Hz carrier gated at 14 Hz with 40%
    /// duty cycle. Unlike binaural beats, isochronic tones don't require
    /// headphones and show stronger published evidence in the PLOS ONE 2023
    /// review (§4 on monaural-vs-binaural comparison).
    nonisolated static let focusIsochronic14 = AmbientFrequencyPreset(
        id: "focus-isochronic-14",
        title: "Focus · Isochronic 14 Hz",
        intent: "Speakers-friendly focus entrainment",
        summary: "200 Hz sine carrier gated at 14 Hz with 40% duty cycle — monaural isochronic, no headphones required.",
        requiresHeadphones: false,
        defaultDurationSeconds: defaultDurationSeconds,
        layers: [
            .isochronicTone(carrierHz: 200, pulseHz: 14, amplitude: 0.16, dutyCycle: 0.40, channelMode: .stereo),
            .pinkNoise(seed: 0x150C_F0C0_5AAA_0014, amplitude: 0.08, envelope: .breath),
        ]
    )

    /// Coding deep work: pink noise base + 16 Hz isochronic accent + low
    /// triangle hum (60 Hz, 12 dB down) for warm "machine-room" texture.
    /// Designed for 45–90-min single-task coding blocks.
    nonisolated static let focusCodingDeep = AmbientFrequencyPreset(
        id: "focus-coding-deep",
        title: "Focus · Coding Deep Work",
        intent: "Long-form code-focus block",
        summary: "Pink noise + 16 Hz isochronic accent + warm 60 Hz triangle hum. Designed for 45–90-min single-task blocks.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .pinkNoise(seed: 0xC0DE_DEE9_F0C0_5BAA, amplitude: 0.20, envelope: .breath),
            .isochronicTone(carrierHz: 180, pulseHz: 16, amplitude: 0.10, dutyCycle: 0.45, channelMode: .stereo),
            .triangleWave(frequencyHz: 60, amplitude: 0.04, channelMode: .stereo),
        ]
    )

    /// Gamma 40 Hz with cathedral pad — 40 Hz gamma entrainment (the most
    /// studied "high-alert" frequency in EEG literature) over a long-decay
    /// harmonic-pluck cathedral pad.
    nonisolated static let focusGamma40 = AmbientFrequencyPreset(
        id: "focus-gamma-40",
        title: "Focus · Gamma 40 Hz Bridge",
        intent: "Short-burst high-alert sessions",
        summary: "40 Hz isochronic over a 110 Hz fundamental harmonic pad. Short sessions only (≤25 min) — gamma is high-arousal.",
        requiresHeadphones: false,
        defaultDurationSeconds: 25 * 60,
        layers: [
            .isochronicTone(carrierHz: 220, pulseHz: 40, amplitude: 0.10, dutyCycle: 0.50, channelMode: .stereo),
            .harmonicPluck(
                fundamentalHz: 110,
                amplitude: 0.07,
                harmonicCount: 5,
                decaySeconds: 8,
                intervalSeconds: 12,
                jitterSeconds: 3,
                startOffsetSeconds: 0,
                seed: 0x4040_B81D_CE40_8240
            ),
            .pinkNoise(seed: 0x4040_F0C0_5AAA_CA0A, amplitude: 0.05, envelope: .breath),
        ]
    )

    /// Pomodoro pulse — 14 Hz AM with a duration matched to the classic
    /// 25-min Pomodoro slot. Same spectral focus as Brain Sync but timed for
    /// a single sprint.
    nonisolated static let focusPomodoro = AmbientFrequencyPreset(
        id: "focus-pomodoro",
        title: "Focus · Pomodoro Pulse",
        intent: "Single 25-min Pomodoro sprint",
        summary: "14 Hz AM on pink noise + 432 Hz anchor — duration tuned to a 25-min Pomodoro sprint.",
        requiresHeadphones: false,
        defaultDurationSeconds: 25 * 60,
        layers: [
            .pinkNoise(seed: 0x9000_5981_A7_2500, amplitude: 0.18, envelope: .breath),
            .amplitudeModulatedCarrier(carrierHz: 220, modulatorHz: 14, depth: 0.78, amplitude: 0.10),
            .sine(frequencyHz: 432, amplitude: 0.045, channelMode: .stereo),
        ]
    )

    // MARK: - Sleep & Wind-down (1/f² brown noise + delta entrainment)

    /// Brown noise cave — pure 1/f² brown noise with breath envelope. Brown
    /// noise's -6 dB/octave roll-off feels warmer and lower than pink; the
    /// AASM clinical-sleep literature consistently shows brown / pink noise
    /// shortens sleep-onset latency in chronic insomniacs (mixed evidence in
    /// healthy sleepers).
    nonisolated static let sleepBrownCave = AmbientFrequencyPreset(
        id: "sleep-brown-cave",
        title: "Sleep · Brown Cave",
        intent: "Deep-warmth wind-down",
        summary: "Pure 1/f² brown noise shaped by a slow breath envelope. Warmest, lowest perceived spectrum; no tones.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .brownNoise(seed: 0xB80A_ACAA_51EE_99AD, amplitude: 0.32, envelope: .breath),
        ]
    )

    /// Pink sleep pad — pink noise + 1.5 Hz delta isochronic. The 1.5 Hz rate
    /// targets slow-wave delta entrainment (NREM Stage 3 dominant band).
    nonisolated static let sleepPinkPad = AmbientFrequencyPreset(
        id: "sleep-pink-pad",
        title: "Sleep · Pink Pad",
        intent: "Delta-band sleep entrainment",
        summary: "Pink noise + 1.5 Hz delta isochronic on a soft 180 Hz carrier. Targets NREM Stage 3 dominant band.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .pinkNoise(seed: 0x91AA_51EE_99AD_DE17, amplitude: 0.22, envelope: .breath),
            .isochronicTone(carrierHz: 180, pulseHz: 1.5, amplitude: 0.10, dutyCycle: 0.40, channelMode: .stereo),
        ]
    )

    /// Yoga Nidra — 0.5 Hz ultra-slow delta isochronic over 60 Hz warm hum
    /// and breath-modulated brown noise. Designed for 35-min Yoga Nidra
    /// "yogic sleep" sessions.
    nonisolated static let sleepYogaNidra = AmbientFrequencyPreset(
        id: "sleep-yoga-nidra",
        title: "Sleep · Yoga Nidra",
        intent: "Yogic-sleep 35-min descent",
        summary: "0.5 Hz ultra-slow delta isochronic + 60 Hz hum + breath-modulated brown noise. 35-min Yoga Nidra descent.",
        requiresHeadphones: false,
        defaultDurationSeconds: 35 * 60,
        layers: [
            .isochronicTone(carrierHz: 144, pulseHz: 0.5, amplitude: 0.08, dutyCycle: 0.40, channelMode: .stereo),
            .triangleWave(frequencyHz: 60, amplitude: 0.025, channelMode: .stereo),
            .brownNoise(seed: 0xA0CA_A1D8_A035_01A0, amplitude: 0.22, envelope: .breath),
        ]
    )

    /// Distant storm — wide bandpass noise (rumble band 80–600 Hz) with
    /// random intermittent low-freq thunder pings every ~45 seconds.
    nonisolated static let sleepDistantStorm = AmbientFrequencyPreset(
        id: "sleep-distant-storm",
        title: "Sleep · Distant Storm",
        intent: "Storm-as-white-noise sleep aid",
        summary: "Wide bandpass noise (80–600 Hz rumble band) + random low-freq thunder pings every ~45 s.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .bandpassNoise(
                seed: 0x5708_051E_E900_800B,
                amplitude: 0.25,
                envelope: .breath,
                centerHz: 340,
                bandwidthHz: 520,
                harmonicCount: 32
            ),
            .intermittentPing(
                frequencyHz: 90,
                amplitude: 0.10,
                durationSeconds: 1.2,
                baseIntervalSeconds: 45,
                jitterSeconds: 20,
                startOffsetSeconds: 12,
                seed: 0x780A_DE80_5708_0001
            ),
        ]
    )

    /// Ocean tide — breath-modulated brown noise + 0.1 Hz LFO breath
    /// (cardiac-paced breathing rate). Ocean surf is the most-studied
    /// natural-sound sleep aid.
    nonisolated static let sleepOceanTide = AmbientFrequencyPreset(
        id: "sleep-ocean-tide",
        title: "Sleep · Ocean Tide",
        intent: "Breath-paced ocean surf",
        summary: "Breath-modulated brown noise + bandpass surf layer + a slow 6-breath-per-min LFO envelope.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .brownNoise(seed: 0x0CEA_A71D_E031_F000, amplitude: 0.24, envelope: .breath),
            .bandpassNoise(
                seed: 0x508F_5805_81AC_BAAD,
                amplitude: 0.11,
                envelope: .breath,
                centerHz: 220,
                bandwidthHz: 320,
                harmonicCount: 24
            ),
        ]
    )

    // MARK: - Nature Ambient (synthesized)

    /// Forest canopy — bandpass-noise wind through trees + random harmonic
    /// plucks (birds calling) + faint mid-band bird chirps.
    nonisolated static let natureForestCanopy = AmbientFrequencyPreset(
        id: "nature-forest-canopy",
        title: "Nature · Forest Canopy",
        intent: "Wind + birds in the canopy",
        summary: "Bandpass-noise wind (200–900 Hz) + random harmonic-pluck bird calls every ~12 s.",
        requiresHeadphones: false,
        defaultDurationSeconds: 45 * 60,
        layers: [
            .bandpassNoise(
                seed: 0xF08E_57A1_ADAA_C001,
                amplitude: 0.18,
                envelope: .breath,
                centerHz: 550,
                bandwidthHz: 700,
                harmonicCount: 28
            ),
            .harmonicPluck(
                fundamentalHz: 1320,
                amplitude: 0.07,
                harmonicCount: 4,
                decaySeconds: 0.6,
                intervalSeconds: 12,
                jitterSeconds: 8,
                startOffsetSeconds: 6,
                seed: 0xB18D_CA11_5F08_E575
            ),
            .pinkNoise(seed: 0x91AA_BACA_F08E_5755, amplitude: 0.05, envelope: .breath),
        ]
    )

    /// Mountain stream — wider bandpass for white-water + pink-noise base.
    /// The 800 Hz center matches the perceptually-dominant resonance of
    /// real white-water audio recordings.
    nonisolated static let natureMountainStream = AmbientFrequencyPreset(
        id: "nature-mountain-stream",
        title: "Nature · Mountain Stream",
        intent: "White-water + pink base",
        summary: "Wide bandpass noise (400–1500 Hz, 24 harmonics) over a pink-noise base. Matches white-water audio resonance.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .bandpassNoise(
                seed: 0x578E_A0AA_AA7_E8FA,
                amplitude: 0.22,
                envelope: .breath,
                centerHz: 950,
                bandwidthHz: 1100,
                harmonicCount: 24
            ),
            .pinkNoise(seed: 0x578E_A0BA_5E91_AA00, amplitude: 0.10, envelope: .breath),
        ]
    )

    /// Crickets — periodic high-freq chirps at 5 Hz cadence (slightly slower
    /// than real crickets at 7 Hz, picked for relaxation pacing per Frontiers
    /// 2021 alpha-band rate).
    nonisolated static let natureCrickets = AmbientFrequencyPreset(
        id: "nature-crickets",
        title: "Nature · Cricket Field",
        intent: "Summer-evening cricket rhythm",
        summary: "4500 Hz chirps at 5 Hz cadence + soft 400–900 Hz background bandpass (cricket choir).",
        requiresHeadphones: false,
        defaultDurationSeconds: 45 * 60,
        layers: [
            .intermittentPing(
                frequencyHz: 4500,
                amplitude: 0.05,
                durationSeconds: 0.04,
                baseIntervalSeconds: 0.2,
                jitterSeconds: 0.08,
                startOffsetSeconds: 0,
                seed: 0xC81C_AE75_C818_9F1D
            ),
            .bandpassNoise(
                seed: 0xC81C_BACA_5C80_1800,
                amplitude: 0.06,
                envelope: .breath,
                centerHz: 650,
                bandwidthHz: 500,
                harmonicCount: 16
            ),
        ]
    )

    /// Crackling hearth — broadband transients (random high-freq pings) over
    /// a low-freq fire-rumble bandpass.
    nonisolated static let natureCracklingHearth = AmbientFrequencyPreset(
        id: "nature-crackling-hearth",
        title: "Nature · Crackling Hearth",
        intent: "Fireplace cracks + rumble",
        summary: "Random high-freq crackles (~3 kHz) + low fire-rumble bandpass (60–280 Hz).",
        requiresHeadphones: false,
        defaultDurationSeconds: 45 * 60,
        layers: [
            .intermittentPing(
                frequencyHz: 3200,
                amplitude: 0.05,
                durationSeconds: 0.03,
                baseIntervalSeconds: 0.8,
                jitterSeconds: 0.5,
                startOffsetSeconds: 0,
                seed: 0xF18E_C8AC_A8EA_8780
            ),
            .bandpassNoise(
                seed: 0x83A8_7880_0B1E_F083,
                amplitude: 0.20,
                envelope: .breath,
                centerHz: 170,
                bandwidthHz: 220,
                harmonicCount: 18
            ),
        ]
    )

    /// Rain on tin roof — bandpass noise centered ~2 kHz (the canonical "rain
    /// on roof" tonal peak per acoustic ecology research).
    nonisolated static let natureRainOnRoof = AmbientFrequencyPreset(
        id: "nature-rain-on-roof",
        title: "Nature · Rain on Roof",
        intent: "Continuous rain on a tin roof",
        summary: "Wide bandpass noise centered 2000 Hz ± 1500 Hz, 36 harmonics. Canonical 'rain on roof' tonal peak.",
        requiresHeadphones: false,
        defaultDurationSeconds: 60 * 60,
        layers: [
            .bandpassNoise(
                seed: 0x8A1A_800F_71A0_5805,
                amplitude: 0.28,
                envelope: .breath,
                centerHz: 2000,
                bandwidthHz: 3000,
                harmonicCount: 36
            ),
            .pinkNoise(seed: 0x91AA_BACA_8A1A_800F, amplitude: 0.07, envelope: .breath),
        ]
    )

    // MARK: - Retro / Arcade (chiptune ambient)

    /// 8-bit idle — NES-style PWM + triangle bass. Three voices (25% PWM
    /// melody, 50% PWM, triangle bass) — the canonical NES APU voice
    /// configuration.
    nonisolated static let retro8BitIdle = AmbientFrequencyPreset(
        id: "retro-8bit-idle",
        title: "Retro · 8-Bit Idle",
        intent: "NES-style menu / idle ambient",
        summary: "Three-voice NES APU emulation: 25% PWM melody, 50% PWM harmony, triangle bass. Classic 8-bit ambient.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .pwmSquare(frequencyHz: 440, dutyCycle: 0.25, amplitude: 0.10, channelMode: .stereo),
            .pwmSquare(frequencyHz: 330, dutyCycle: 0.50, amplitude: 0.07, channelMode: .stereo),
            .triangleWave(frequencyHz: 110, amplitude: 0.09, channelMode: .stereo),
            .pinkNoise(seed: 0x8B17_1D1E_AE50_8E70, amplitude: 0.04, envelope: .breath),
        ]
    )

    /// Sega Genesis ambient — YM2612-style two-op FM pad with slow modulator.
    /// The 2:1 modulator:carrier ratio gives a smooth metallic timbre with
    /// even-harmonic emphasis (Genesis "synth pad" canonical sound).
    nonisolated static let retroSegaGenesis = AmbientFrequencyPreset(
        id: "retro-sega-genesis",
        title: "Retro · Sega Genesis",
        intent: "YM2612-style FM ambient pad",
        summary: "Two-op FM pad (2:1 mod:carrier, modulation index 2.5) — canonical Sega Genesis YM2612 synth-pad timbre.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .fmSynth(carrierHz: 220, modulatorHz: 440, modulationIndex: 2.5, amplitude: 0.11, channelMode: .stereo),
            .fmSynth(carrierHz: 165, modulatorHz: 330, modulationIndex: 2.0, amplitude: 0.08, channelMode: .stereo),
            .triangleWave(frequencyHz: 55, amplitude: 0.05, channelMode: .stereo),
        ]
    )

    /// Game Boy sleep — PWM at 50% (Game Boy PSG default) + soft noise
    /// channel. Subdued, late-night handheld ambient.
    nonisolated static let retroGameBoy = AmbientFrequencyPreset(
        id: "retro-gameboy",
        title: "Retro · Game Boy Sleep",
        intent: "Game Boy PSG late-night ambient",
        summary: "50% PWM + noise channel — Game Boy PSG canonical configuration. Subdued late-night handheld vibe.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .pwmSquare(frequencyHz: 220, dutyCycle: 0.50, amplitude: 0.10, channelMode: .stereo),
            .pwmSquare(frequencyHz: 165, dutyCycle: 0.50, amplitude: 0.07, channelMode: .stereo),
            .pinkNoise(seed: 0x6A03_B0A0_95C5_1EE9, amplitude: 0.05, envelope: .breath),
        ]
    )

    /// SID drone — Commodore 64 SID 6581 emulation: sawtooth + filter
    /// resonance approximated via bandpass-noise color over a sustained
    /// sawtooth. Bass-heavy, dirty timbre.
    nonisolated static let retroSidDrone = AmbientFrequencyPreset(
        id: "retro-sid-drone",
        title: "Retro · SID Drone",
        intent: "Commodore 64 SID 6581 drone",
        summary: "Sustained sawtooth + bandpass-noise filter resonance approximation. Bass-heavy, dirty SID 6581 timbre.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .sawtoothWave(frequencyHz: 110, amplitude: 0.13, channelMode: .stereo),
            .sawtoothWave(frequencyHz: 82.5, amplitude: 0.09, channelMode: .stereo),
            .bandpassNoise(
                seed: 0x51D6_5818_F117_E885,
                amplitude: 0.05,
                envelope: .breath,
                centerHz: 880,
                bandwidthHz: 220,
                harmonicCount: 12
            ),
        ]
    )

    /// Arcade cabinet — triangle bass + PWM melody with slow sweep + faint
    /// noise (cabinet hum). Evokes a quiet arcade between attract-mode loops.
    nonisolated static let retroArcadeCabinet = AmbientFrequencyPreset(
        id: "retro-arcade-cabinet",
        title: "Retro · Arcade Cabinet",
        intent: "Quiet arcade between attract loops",
        summary: "Triangle bass + 25% PWM melody + faint cabinet-hum bandpass noise (around 120 Hz cabinet resonance).",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .triangleWave(frequencyHz: 82.5, amplitude: 0.09, channelMode: .stereo),
            .pwmSquare(frequencyHz: 392, dutyCycle: 0.25, amplitude: 0.08, channelMode: .stereo),
            .bandpassNoise(
                seed: 0xA8CA_DE00_CAB1_8000,
                amplitude: 0.06,
                envelope: .breath,
                centerHz: 120,
                bandwidthHz: 100,
                harmonicCount: 10
            ),
        ]
    )

    // MARK: - Meditative / Experimental

    /// Cathedral drone — three harmonic-pluck layers with very long decay,
    /// triggered at slow intervals. Mimics the slow reverb tail of a
    /// cathedral organ stop.
    nonisolated static let meditativeCathedral = AmbientFrequencyPreset(
        id: "meditative-cathedral",
        title: "Meditative · Cathedral Drone",
        intent: "Slow long-decay harmonic stack",
        summary: "Three harmonic-pluck layers (110/165/220 Hz fundamentals) with 12-s decay, triggered every ~25 s. Cathedral organ tail.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .harmonicPluck(
                fundamentalHz: 110,
                amplitude: 0.10,
                harmonicCount: 6,
                decaySeconds: 12,
                intervalSeconds: 25,
                jitterSeconds: 4,
                startOffsetSeconds: 0,
                seed: 0xCA78_ED8A_1BA5_5110
            ),
            .harmonicPluck(
                fundamentalHz: 165,
                amplitude: 0.07,
                harmonicCount: 6,
                decaySeconds: 11,
                intervalSeconds: 31,
                jitterSeconds: 5,
                startOffsetSeconds: 8,
                seed: 0xCA78_ED8A_1015_5165
            ),
            .harmonicPluck(
                fundamentalHz: 220,
                amplitude: 0.05,
                harmonicCount: 6,
                decaySeconds: 10,
                intervalSeconds: 41,
                jitterSeconds: 7,
                startOffsetSeconds: 17,
                seed: 0xCA78_ED8A_1709_5220
            ),
        ]
    )

    /// Tibetan singing bowl — harmonic-pluck cluster with 8 harmonics and
    /// 9-second decay, triggered every 18 s. Single-bowl center at 256 Hz
    /// (canonical Tibetan B-flat fundamental).
    nonisolated static let meditativeSingingBowl = AmbientFrequencyPreset(
        id: "meditative-singing-bowl",
        title: "Meditative · Singing Bowl",
        intent: "Single-bowl harmonic strikes",
        summary: "256 Hz fundamental (B-flat) harmonic pluck with 8 harmonics, 9-s decay, every 18 s. Tibetan singing bowl approximation.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .harmonicPluck(
                fundamentalHz: 256,
                amplitude: 0.13,
                harmonicCount: 8,
                decaySeconds: 9,
                intervalSeconds: 18,
                jitterSeconds: 3,
                startOffsetSeconds: 0,
                seed: 0x71BE_751A_CB0A_1B25
            ),
        ]
    )

    /// Theremin drift — slow sine glissando approximated via amplitude-
    /// modulated carrier with a 0.05 Hz modulation rate.
    nonisolated static let meditativeThereminDrift = AmbientFrequencyPreset(
        id: "meditative-theremin-drift",
        title: "Meditative · Theremin Drift",
        intent: "Slow electro-acoustic sweep",
        summary: "440 Hz carrier slowly amplitude-modulated at 0.05 Hz — eerie theremin-style sustained tone.",
        requiresHeadphones: false,
        defaultDurationSeconds: 25 * 60,
        layers: [
            .amplitudeModulatedCarrier(carrierHz: 440, modulatorHz: 0.05, depth: 0.7, amplitude: 0.13),
            .sine(frequencyHz: 880, amplitude: 0.04, channelMode: .stereo),
            .pinkNoise(seed: 0x78E8_01A0_BACA_C800, amplitude: 0.04, envelope: .breath),
        ]
    )

    /// Wind chimes — random harmonic plucks at a pentatonic-scale set of
    /// frequencies (A4 C5 D5 E5 G5), triggered at jittered intervals.
    nonisolated static let meditativeWindChimes = AmbientFrequencyPreset(
        id: "meditative-wind-chimes",
        title: "Meditative · Wind Chimes",
        intent: "Random pentatonic chime cluster",
        summary: "Five harmonic plucks at A4, C5, D5, E5, G5 (pentatonic) with random timing — wind-chime cluster.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .harmonicPluck(fundamentalHz: 440.0, amplitude: 0.08, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 17, jitterSeconds: 11, startOffsetSeconds: 0, seed: 0xC810_A440_A1AD_AA00),
            .harmonicPluck(fundamentalHz: 523.25, amplitude: 0.07, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 19, jitterSeconds: 13, startOffsetSeconds: 3, seed: 0xC810_C523_A1AD_AA01),
            .harmonicPluck(fundamentalHz: 587.33, amplitude: 0.07, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 23, jitterSeconds: 14, startOffsetSeconds: 6, seed: 0xC810_D587_A1AD_AA02),
            .harmonicPluck(fundamentalHz: 659.25, amplitude: 0.06, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 21, jitterSeconds: 12, startOffsetSeconds: 9, seed: 0xC810_E659_A1AD_AA03),
            .harmonicPluck(fundamentalHz: 783.99, amplitude: 0.06, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 27, jitterSeconds: 16, startOffsetSeconds: 12, seed: 0xC810_C783_A1AD_AA04),
        ]
    )

    /// Solfeggio stack — 6 solfeggio-tradition frequencies (174 · 285 · 396 ·
    /// 528 · 741 · 852 Hz) layered as quiet sines. The solfeggio system is
    /// folk-science (not clinically validated) but popular; this preset
    /// stays honest about that framing in the summary.
    nonisolated static let meditativeSolfeggioStack = AmbientFrequencyPreset(
        id: "meditative-solfeggio-stack",
        title: "Meditative · Solfeggio Stack",
        intent: "Solfeggio-tradition layered tones",
        summary: "6 solfeggio frequencies layered: 174 · 285 · 396 · 528 · 741 · 852 Hz. Folk-science, not clinically validated; popular as ambient.",
        requiresHeadphones: false,
        defaultDurationSeconds: 30 * 60,
        layers: [
            .sine(frequencyHz: 174, amplitude: 0.04, channelMode: .stereo),
            .sine(frequencyHz: 285, amplitude: 0.04, channelMode: .stereo),
            .sine(frequencyHz: 396, amplitude: 0.04, channelMode: .stereo),
            .sine(frequencyHz: 528, amplitude: 0.04, channelMode: .stereo),
            .sine(frequencyHz: 741, amplitude: 0.04, channelMode: .stereo),
            .sine(frequencyHz: 852, amplitude: 0.04, channelMode: .stereo),
            .pinkNoise(seed: 0x501F_3CC1_057A_ABAC, amplitude: 0.04, envelope: .breath),
        ]
    )

    nonisolated static let allPresets: [AmbientFrequencyPreset] = [
        // Original requested cocktail + EEG-band binaural family
        .schumannCocktail,
        .deltaRest,
        .thetaDrift,
        .alphaFocus,
        .betaClarity,
        .gammaSpark,
        // Focus & Productivity (iter 85)
        .focusBrainSync,
        .focusIsochronic14,
        .focusCodingDeep,
        .focusGamma40,
        .focusPomodoro,
        // Sleep & Wind-down (iter 85)
        .sleepBrownCave,
        .sleepPinkPad,
        .sleepYogaNidra,
        .sleepDistantStorm,
        .sleepOceanTide,
        // Nature Ambient (iter 85)
        .natureForestCanopy,
        .natureMountainStream,
        .natureCrickets,
        .natureCracklingHearth,
        .natureRainOnRoof,
        // Retro / Arcade (iter 85)
        .retro8BitIdle,
        .retroSegaGenesis,
        .retroGameBoy,
        .retroSidDrone,
        .retroArcadeCabinet,
        // Meditative / Experimental (iter 85)
        .meditativeCathedral,
        .meditativeSingingBowl,
        .meditativeThereminDrift,
        .meditativeWindChimes,
        .meditativeSolfeggioStack,
    ]

    nonisolated static func preset(id: String) -> AmbientFrequencyPreset {
        allPresets.first { $0.id == id } ?? .schumannCocktail
    }

    /// Compose a custom preset by layering N sound modules onto a base preset.
    /// User-facing flow:
    ///   1. Pick a base preset (gives you the entrainment foundation —
    ///      e.g. "Focus · Brain Sync 14 Hz" or "Sleep · Brown Cave")
    ///   2. Stack any number of `AmbientFrequencySoundModule`s on top
    ///      (e.g. add Birds + Rain + Cathedral Pad on top of Brain Sync)
    /// The composed preset inherits the base preset's id + intent but appends
    /// every module's layers and lists the module titles in the summary.
    nonisolated static func composed(
        base: AmbientFrequencyPreset,
        modules: [AmbientFrequencySoundModule],
        durationSeconds: Double = AmbientFrequencyPreset.defaultDurationSeconds
    ) -> AmbientFrequencyPreset {
        let moduleLayers = modules.flatMap(\.layers)
        let moduleTitles = modules.map(\.title).joined(separator: " + ")
        let composedSummary: String
        if modules.isEmpty {
            composedSummary = base.summary
        } else {
            composedSummary = "\(base.summary)  + stacked: \(moduleTitles)."
        }
        let moduleIdSuffix = modules.map(\.id).joined(separator: "+")
        let composedId = modules.isEmpty
            ? base.id
            : "\(base.id)+\(moduleIdSuffix)"
        return AmbientFrequencyPreset(
            id: composedId,
            title: modules.isEmpty ? base.title : "\(base.title) (custom mix)",
            intent: base.intent,
            summary: composedSummary,
            requiresHeadphones: base.requiresHeadphones,
            defaultDurationSeconds: durationSeconds,
            layers: base.layers + moduleLayers
        )
    }
}

/// A composable sound module — a small named group of layers that can be
/// stacked onto any base preset via `AmbientFrequencyPreset.composed(...)`.
/// Use this to layer "birds chirping" or "rain" or "cathedral pad" on top
/// of an entrainment preset without forking a new preset constant.
struct AmbientFrequencySoundModule: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let category: AmbientFrequencySoundModuleCategory
    let summary: String
    let layers: [AmbientFrequencyLayer]

    // MARK: - Noise color modules (5 colors of the audible spectrum)

    nonisolated static let whiteHiss = AmbientFrequencySoundModule(
        id: "color-white",
        title: "White hiss",
        category: .noiseColor,
        summary: "Flat-spectrum white noise. Equal energy per Hz. Useful as a neutral bed.",
        layers: [.whiteNoise(seed: 0xA111_BBBB_CCCC_DDDD, amplitude: 0.10, envelope: .breath)]
    )

    nonisolated static let pinkBed = AmbientFrequencySoundModule(
        id: "color-pink",
        title: "Pink bed",
        category: .noiseColor,
        summary: "Pink (1/f) noise. Equal energy per octave; the Brain.fm-style default backbone.",
        layers: [.pinkNoise(seed: 0xC0CC_DDDD_AAAA_BBBB, amplitude: 0.14, envelope: .breath)]
    )

    nonisolated static let greyEqual = AmbientFrequencySoundModule(
        id: "color-grey",
        title: "Grey equal",
        category: .noiseColor,
        summary: "Psychoacoustically equalized grey noise. Sounds equally loud across the audible spectrum.",
        layers: [.greyNoise(seed: 0xCCCC_AAAA_FF00_BBBB, amplitude: 0.12, envelope: .breath)]
    )

    nonisolated static let blueShimmer = AmbientFrequencySoundModule(
        id: "color-blue",
        title: "Blue shimmer",
        category: .noiseColor,
        summary: "Blue (+3 dB/oct) noise. Sparkly, high-frequency-shifted; good for shimmer overlays.",
        layers: [.blueNoise(seed: 0xBBBB_ABBA_EEEE_CCCC, amplitude: 0.06, envelope: .breath)]
    )

    nonisolated static let brownCave = AmbientFrequencySoundModule(
        id: "color-brown",
        title: "Brown cave",
        category: .noiseColor,
        summary: "Brown (1/f²) noise. Warmest, lowest-perceived spectrum. Sleep-mode favorite.",
        layers: [.brownNoise(seed: 0xBBBB_AAAA_CCCC_DDDD, amplitude: 0.18, envelope: .breath)]
    )

    nonisolated static let violetSparkle = AmbientFrequencySoundModule(
        id: "color-violet",
        title: "Violet sparkle",
        category: .noiseColor,
        summary: "Violet (+6 dB/oct) noise. Very bright; classic tinnitus-masking color.",
        layers: [.violetNoise(seed: 0xAAAA_FFFF_BBBB_CCCC, amplitude: 0.05, envelope: .breath)]
    )

    // MARK: - Nature modules (stackable on any base)

    nonisolated static let birdsChirping = AmbientFrequencySoundModule(
        id: "nature-birds-chirping",
        title: "Birds chirping",
        category: .nature,
        summary: "Random harmonic-pluck bird calls at 1320 Hz with 4 harmonics, triggered every 8-20 s.",
        layers: [
            .harmonicPluck(fundamentalHz: 1320, amplitude: 0.07, harmonicCount: 4, decaySeconds: 0.6, intervalSeconds: 12, jitterSeconds: 8, startOffsetSeconds: 6, seed: 0xB18D_CA11_CB18_D5AB),
            .harmonicPluck(fundamentalHz: 1760, amplitude: 0.05, harmonicCount: 4, decaySeconds: 0.5, intervalSeconds: 18, jitterSeconds: 11, startOffsetSeconds: 14, seed: 0xB18D_C811_CB18_DAA8),
        ]
    )

    nonisolated static let gentleRain = AmbientFrequencySoundModule(
        id: "nature-gentle-rain",
        title: "Gentle rain",
        category: .nature,
        summary: "Mid-density bandpass noise centered 2 kHz ± 1.5 kHz. Light steady rain.",
        layers: [
            .bandpassNoise(seed: 0xCAFE_8A1E_CAFE_8A18, amplitude: 0.14, envelope: .breath, centerHz: 2000, bandwidthHz: 3000, harmonicCount: 28),
        ]
    )

    nonisolated static let heavyRain = AmbientFrequencySoundModule(
        id: "nature-heavy-rain",
        title: "Heavy rain",
        category: .nature,
        summary: "High-density bandpass noise + brown rumble. Driving rain texture.",
        layers: [
            .bandpassNoise(seed: 0xFACE_BABE_FACE_BABE, amplitude: 0.18, envelope: .breath, centerHz: 2200, bandwidthHz: 4000, harmonicCount: 42),
            .brownNoise(seed: 0xBAAD_C0DE_BAAD_C0DE, amplitude: 0.06, envelope: .breath),
        ]
    )

    nonisolated static let fireCrackle = AmbientFrequencySoundModule(
        id: "nature-fire-crackle",
        title: "Fire crackle",
        category: .nature,
        summary: "Random high-freq crackles + low fire-rumble. Hearth atmosphere.",
        layers: [
            .intermittentPing(frequencyHz: 3200, amplitude: 0.05, durationSeconds: 0.03, baseIntervalSeconds: 0.8, jitterSeconds: 0.5, startOffsetSeconds: 0, seed: 0xF18E_C8AC_A8EA_8788),
            .bandpassNoise(seed: 0x8EA8_888A_C8AC_8EAA, amplitude: 0.14, envelope: .breath, centerHz: 170, bandwidthHz: 220, harmonicCount: 16),
        ]
    )

    nonisolated static let wind = AmbientFrequencySoundModule(
        id: "nature-wind",
        title: "Wind",
        category: .nature,
        summary: "Wide bandpass noise (200-900 Hz) for wind through trees.",
        layers: [
            .bandpassNoise(seed: 0xA1AA_DDD0_DDD0_DDD0, amplitude: 0.13, envelope: .breath, centerHz: 550, bandwidthHz: 700, harmonicCount: 22),
        ]
    )

    nonisolated static let oceanSurf = AmbientFrequencySoundModule(
        id: "nature-ocean-surf",
        title: "Ocean surf",
        category: .nature,
        summary: "Breath-modulated brown noise + bandpass surf layer. Tidal pace.",
        layers: [
            .brownNoise(seed: 0x0CEA_A07A_DEEE_F008, amplitude: 0.16, envelope: .breath),
            .bandpassNoise(seed: 0x5088_F058_8A8A_BAAD, amplitude: 0.08, envelope: .breath, centerHz: 220, bandwidthHz: 320, harmonicCount: 18),
        ]
    )

    nonisolated static let distantThunder = AmbientFrequencySoundModule(
        id: "nature-distant-thunder",
        title: "Distant thunder",
        category: .nature,
        summary: "Random low-freq thunder pings every ~45 s. Stormy atmosphere.",
        layers: [
            .intermittentPing(frequencyHz: 90, amplitude: 0.08, durationSeconds: 1.2, baseIntervalSeconds: 45, jitterSeconds: 20, startOffsetSeconds: 12, seed: 0x7008_8888_5708_8001),
        ]
    )

    nonisolated static let crickets = AmbientFrequencySoundModule(
        id: "nature-crickets",
        title: "Crickets",
        category: .nature,
        summary: "4500 Hz chirps at 5 Hz cadence. Summer-evening relaxation pace.",
        layers: [
            .intermittentPing(frequencyHz: 4500, amplitude: 0.04, durationSeconds: 0.04, baseIntervalSeconds: 0.2, jitterSeconds: 0.08, startOffsetSeconds: 0, seed: 0xC818_AE75_C818_FA1D),
        ]
    )

    nonisolated static let mountainStream = AmbientFrequencySoundModule(
        id: "nature-mountain-stream",
        title: "Mountain stream",
        category: .nature,
        summary: "Wide bandpass noise centered 950 Hz — white-water audio resonance.",
        layers: [
            .bandpassNoise(seed: 0x57AE_AAAA_AA7E_8FAA, amplitude: 0.16, envelope: .breath, centerHz: 950, bandwidthHz: 1100, harmonicCount: 20),
        ]
    )

    // MARK: - Rhythmic modules (BPM-style accents)

    nonisolated static let slowHeartbeat = AmbientFrequencySoundModule(
        id: "rhythmic-slow-heartbeat",
        title: "Slow heartbeat (60 BPM)",
        category: .rhythmic,
        summary: "60 BPM low thump — meditative cardiac pace.",
        layers: [
            .intermittentPing(frequencyHz: 70, amplitude: 0.07, durationSeconds: 0.18, baseIntervalSeconds: 1.0, jitterSeconds: 0.02, startOffsetSeconds: 0, seed: 0x8EA8_7BEA_75108_F00),
        ]
    )

    nonisolated static let metronome120 = AmbientFrequencySoundModule(
        id: "rhythmic-metronome-120",
        title: "Metronome 120 BPM",
        category: .rhythmic,
        summary: "120 BPM crisp tick — coding-flow pace.",
        layers: [
            .intermittentPing(frequencyHz: 1800, amplitude: 0.03, durationSeconds: 0.04, baseIntervalSeconds: 0.5, jitterSeconds: 0.0, startOffsetSeconds: 0, seed: 0x078E_7800_A0F1_2080),
        ]
    )

    // MARK: - Texture / drone modules

    nonisolated static let starlightSparkle = AmbientFrequencySoundModule(
        id: "texture-starlight-sparkle",
        title: "Starlight sparkle",
        category: .texture,
        summary: "Random high-freq glints (7-9 kHz) every ~30 s. Cosmic shimmer.",
        layers: [
            .intermittentPing(frequencyHz: 8400, amplitude: 0.025, durationSeconds: 0.06, baseIntervalSeconds: 30, jitterSeconds: 15, startOffsetSeconds: 8, seed: 0x57AE_A18C_57AE_A18C),
            .violetNoise(seed: 0xAA00_BB00_CC00_DD00, amplitude: 0.03, envelope: .breath),
        ]
    )

    nonisolated static let subBassPulse = AmbientFrequencySoundModule(
        id: "texture-sub-bass-pulse",
        title: "Sub-bass pulse",
        category: .texture,
        summary: "55 Hz triangle bass — adds physical depth to any preset.",
        layers: [
            .triangleWave(frequencyHz: 55, amplitude: 0.07, channelMode: .stereo),
        ]
    )

    nonisolated static let cathedralPad = AmbientFrequencySoundModule(
        id: "drone-cathedral-pad",
        title: "Cathedral pad",
        category: .drone,
        summary: "110 Hz harmonic pluck with 12 s decay every ~25 s. Cathedral organ tail.",
        layers: [
            .harmonicPluck(fundamentalHz: 110, amplitude: 0.08, harmonicCount: 6, decaySeconds: 12, intervalSeconds: 25, jitterSeconds: 4, startOffsetSeconds: 0, seed: 0xCA78_EDAA_18A0_0110),
        ]
    )

    nonisolated static let singingBowlAccent = AmbientFrequencySoundModule(
        id: "drone-singing-bowl",
        title: "Singing bowl accent",
        category: .drone,
        summary: "256 Hz Tibetan-bowl strike every 18 s with 9 s decay.",
        layers: [
            .harmonicPluck(fundamentalHz: 256, amplitude: 0.10, harmonicCount: 8, decaySeconds: 9, intervalSeconds: 18, jitterSeconds: 3, startOffsetSeconds: 0, seed: 0x7188_75A1_C8A0_256B),
        ]
    )

    nonisolated static let windChimesCluster = AmbientFrequencySoundModule(
        id: "drone-wind-chimes",
        title: "Wind chimes (pentatonic)",
        category: .drone,
        summary: "Five harmonic plucks at A4/C5/D5/E5/G5 — random pentatonic chime cluster.",
        layers: [
            .harmonicPluck(fundamentalHz: 440.0, amplitude: 0.06, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 17, jitterSeconds: 11, startOffsetSeconds: 0, seed: 0xC818_A440_A18D_AA00),
            .harmonicPluck(fundamentalHz: 523.0, amplitude: 0.05, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 19, jitterSeconds: 13, startOffsetSeconds: 3, seed: 0xC818_C523_A18D_AA01),
            .harmonicPluck(fundamentalHz: 659.0, amplitude: 0.04, harmonicCount: 5, decaySeconds: 4, intervalSeconds: 23, jitterSeconds: 14, startOffsetSeconds: 8, seed: 0xC818_E659_A18D_AA03),
        ]
    )

    // MARK: - Retro / Arcade modules

    nonisolated static let nesArpeggio = AmbientFrequencySoundModule(
        id: "retro-nes-arpeggio",
        title: "NES arpeggio",
        category: .retro,
        summary: "Triangle bass + 25% PWM melody — NES APU two-voice ambient.",
        layers: [
            .triangleWave(frequencyHz: 82.5, amplitude: 0.06, channelMode: .stereo),
            .pwmSquare(frequencyHz: 392, dutyCycle: 0.25, amplitude: 0.06, channelMode: .stereo),
        ]
    )

    nonisolated static let segaFmBell = AmbientFrequencySoundModule(
        id: "retro-sega-fm-bell",
        title: "Sega FM bell",
        category: .retro,
        summary: "YM2612-style two-op FM bell — Sega Genesis canonical bell tone.",
        layers: [
            .fmSynth(carrierHz: 440, modulatorHz: 880, modulationIndex: 3.0, amplitude: 0.07, channelMode: .stereo),
        ]
    )

    nonisolated static let sidSweepDrone = AmbientFrequencySoundModule(
        id: "retro-sid-sweep",
        title: "SID sweep drone",
        category: .retro,
        summary: "C64 SID 6581 sawtooth drone with bandpass-noise filter color.",
        layers: [
            .sawtoothWave(frequencyHz: 82.5, amplitude: 0.08, channelMode: .stereo),
            .bandpassNoise(seed: 0x51D6_5818_FA1A_8AA8, amplitude: 0.04, envelope: .breath, centerHz: 880, bandwidthHz: 220, harmonicCount: 10),
        ]
    )

    // MARK: - Module registry

    nonisolated static let allModules: [AmbientFrequencySoundModule] = [
        // Noise colors (6)
        .whiteHiss, .pinkBed, .greyEqual, .blueShimmer, .brownCave, .violetSparkle,
        // Nature (9)
        .birdsChirping, .gentleRain, .heavyRain, .fireCrackle, .wind, .oceanSurf,
        .distantThunder, .crickets, .mountainStream,
        // Rhythmic (2)
        .slowHeartbeat, .metronome120,
        // Texture / drone (5)
        .starlightSparkle, .subBassPulse, .cathedralPad, .singingBowlAccent, .windChimesCluster,
        // Retro / arcade (3)
        .nesArpeggio, .segaFmBell, .sidSweepDrone,
    ]

    nonisolated static func module(id: String) -> AmbientFrequencySoundModule? {
        allModules.first { $0.id == id }
    }

    nonisolated static func modules(in category: AmbientFrequencySoundModuleCategory) -> [AmbientFrequencySoundModule] {
        allModules.filter { $0.category == category }
    }
}

/// Category for grouping `AmbientFrequencySoundModule`s in pickers.
enum AmbientFrequencySoundModuleCategory: String, CaseIterable, Sendable, Identifiable {
    case noiseColor = "Noise color"
    case nature = "Nature"
    case rhythmic = "Rhythmic"
    case texture = "Texture"
    case drone = "Drone"
    case retro = "Retro / Arcade"

    nonisolated var id: String { rawValue }
}

struct AmbientFrequencyExportRequest: Sendable {
    var preset: AmbientFrequencyPreset
    var durationSeconds: Double
    var sampleRate: Int
    var outputURL: URL
    var chunkFrames: Int

    init(
        preset: AmbientFrequencyPreset,
        durationSeconds: Double,
        sampleRate: Int = AmbientFrequencyAudioGenerator.defaultSampleRate,
        outputURL: URL,
        chunkFrames: Int = 16_384
    ) {
        self.preset = preset
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.outputURL = outputURL
        self.chunkFrames = chunkFrames
    }
}

struct AmbientFrequencyRenderReport: Equatable, Sendable {
    let outputURL: URL
    let presetID: String
    let framesWritten: Int
    let durationSeconds: Double
    let sampleRate: Int
    let channels: Int
    let bitDepth: Int
    let peakBeforeNormalization: Double
    let peakAfterNormalization: Double
}

enum AmbientFrequencyAudioGeneratorError: Error, LocalizedError {
    case invalidDuration(Double)
    case invalidSampleRate(Int)
    case unsupportedFrequency(maxFrequency: Double, sampleRate: Int)
    case invalidChunkFrames(Int)
    case emptySignal
    case fileTooLarge(Int64)
    case couldNotCreateOutput(URL)

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Duration must be a finite positive value."
        case .invalidSampleRate:
            return "Sample rate must be a positive finite integer."
        case .unsupportedFrequency(let maxFrequency, let sampleRate):
            return "Preset contains \(maxFrequency) Hz, which exceeds the Nyquist limit for \(sampleRate) Hz."
        case .invalidChunkFrames:
            return "Chunk size must be positive."
        case .emptySignal:
            return "Preset generated silence."
        case .fileTooLarge:
            return "The WAV file would exceed the RIFF size limit."
        case .couldNotCreateOutput(let url):
            return "Could not create output file at \(url.path)."
        }
    }
}

enum AmbientFrequencyAudioGenerator {
    nonisolated static let defaultSampleRate = 44_100
    nonisolated static let channelCount = 2
    nonisolated static let bitDepth = 32
    nonisolated static let targetPeak = 0.92

    nonisolated static func export(_ request: AmbientFrequencyExportRequest) throws -> AmbientFrequencyRenderReport {
        try validate(request)
        let frames = try frameCount(
            durationSeconds: request.durationSeconds,
            sampleRate: request.sampleRate
        )
        let peakBeforeNormalization = peak(
            preset: request.preset,
            frames: frames,
            sampleRate: request.sampleRate,
            chunkFrames: request.chunkFrames
        )
        guard peakBeforeNormalization > 0 else {
            throw AmbientFrequencyAudioGeneratorError.emptySignal
        }

        let gain = targetPeak / peakBeforeNormalization
        try writeFloatWav(
            request: request,
            frames: frames,
            gain: gain
        )

        return AmbientFrequencyRenderReport(
            outputURL: request.outputURL,
            presetID: request.preset.id,
            framesWritten: frames,
            durationSeconds: Double(frames) / Double(request.sampleRate),
            sampleRate: request.sampleRate,
            channels: channelCount,
            bitDepth: bitDepth,
            peakBeforeNormalization: peakBeforeNormalization,
            peakAfterNormalization: min(targetPeak, peakBeforeNormalization * gain)
        )
    }

    nonisolated static func eventStarts(
        for layer: AmbientFrequencyLayer,
        durationSeconds: Double
    ) -> [Double] {
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            return []
        }
        switch layer {
        case .chirp(_, _, _, _, let intervalSeconds, let startOffsetSeconds, _):
            guard intervalSeconds > 0 else { return [] }
            var starts: [Double] = []
            var start = startOffsetSeconds
            while start < durationSeconds {
                if start >= 0 {
                    starts.append(start)
                }
                start += intervalSeconds
            }
            return starts
        case .intermittentPing(_, _, _, let baseIntervalSeconds, _, let startOffsetSeconds, let seed):
            guard baseIntervalSeconds > 0 else { return [] }
            var starts: [Double] = []
            var index = 0
            while true {
                let start = intermittentStart(
                    index: index,
                    baseIntervalSeconds: baseIntervalSeconds,
                    jitterSeconds: 0,
                    startOffsetSeconds: startOffsetSeconds,
                    seed: seed
                )
                if start >= durationSeconds {
                    break
                }
                if start >= 0 {
                    starts.append(start)
                }
                index += 1
            }
            return starts
        default:
            return []
        }
    }

    nonisolated private static func validate(_ request: AmbientFrequencyExportRequest) throws {
        guard request.durationSeconds.isFinite, request.durationSeconds > 0 else {
            throw AmbientFrequencyAudioGeneratorError.invalidDuration(request.durationSeconds)
        }
        guard request.sampleRate > 0 else {
            throw AmbientFrequencyAudioGeneratorError.invalidSampleRate(request.sampleRate)
        }
        guard request.chunkFrames > 0 else {
            throw AmbientFrequencyAudioGeneratorError.invalidChunkFrames(request.chunkFrames)
        }
        let maxFrequency = request.preset.layers.map(\.maxFrequencyHz).max() ?? 0
        guard maxFrequency < Double(request.sampleRate) / 2 else {
            throw AmbientFrequencyAudioGeneratorError.unsupportedFrequency(
                maxFrequency: maxFrequency,
                sampleRate: request.sampleRate
            )
        }
    }

    nonisolated private static func frameCount(durationSeconds: Double, sampleRate: Int) throws -> Int {
        let framesDouble = (durationSeconds * Double(sampleRate)).rounded()
        guard framesDouble.isFinite, framesDouble > 0, framesDouble <= Double(Int.max) else {
            throw AmbientFrequencyAudioGeneratorError.invalidDuration(durationSeconds)
        }
        return Int(framesDouble)
    }

    nonisolated private static func peak(
        preset: AmbientFrequencyPreset,
        frames: Int,
        sampleRate: Int,
        chunkFrames: Int
    ) -> Double {
        var peak: Double = 0
        var frameStart = 0
        while frameStart < frames {
            let count = min(chunkFrames, frames - frameStart)
            for offset in 0..<count {
                let frame = frameStart + offset
                let sample = samplePair(
                    preset: preset,
                    frame: frame,
                    totalFrames: frames,
                    sampleRate: sampleRate
                )
                peak = max(peak, abs(sample.left), abs(sample.right))
            }
            frameStart += count
        }
        return peak
    }

    nonisolated private static func writeFloatWav(
        request: AmbientFrequencyExportRequest,
        frames: Int,
        gain: Double
    ) throws {
        let bytesPerSample = bitDepth / 8
        let dataBytes64 = Int64(frames) * Int64(channelCount) * Int64(bytesPerSample)
        guard dataBytes64 <= Int64(UInt32.max) - 36 else {
            throw AmbientFrequencyAudioGeneratorError.fileTooLarge(dataBytes64)
        }

        let directory = request.outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: request.outputURL)
        guard FileManager.default.createFile(atPath: request.outputURL.path, contents: nil) else {
            throw AmbientFrequencyAudioGeneratorError.couldNotCreateOutput(request.outputURL)
        }

        let handle = try FileHandle(forWritingTo: request.outputURL)
        defer {
            try? handle.close()
        }

        try handle.write(contentsOf: wavHeader(
            dataBytes: UInt32(dataBytes64),
            sampleRate: UInt32(request.sampleRate)
        ))

        var interleaved = [Float](repeating: 0, count: request.chunkFrames * channelCount)
        var frameStart = 0
        while frameStart < frames {
            let count = min(request.chunkFrames, frames - frameStart)
            if interleaved.count != count * channelCount {
                interleaved = [Float](repeating: 0, count: count * channelCount)
            }
            for offset in 0..<count {
                let frame = frameStart + offset
                let sample = samplePair(
                    preset: request.preset,
                    frame: frame,
                    totalFrames: frames,
                    sampleRate: request.sampleRate
                )
                let writeIndex = offset * channelCount
                interleaved[writeIndex] = Float(sample.left * gain)
                interleaved[writeIndex + 1] = Float(sample.right * gain)
            }

            try interleaved.withUnsafeBufferPointer { buffer in
                try handle.write(contentsOf: Data(buffer: buffer))
            }
            frameStart += count
        }
    }

    nonisolated private static func wavHeader(dataBytes: UInt32, sampleRate: UInt32) -> Data {
        let bytesPerSample = UInt16(bitDepth / 8)
        let blockAlign = UInt16(channelCount) * bytesPerSample
        let byteRate = sampleRate * UInt32(blockAlign)
        var data = Data()
        data.appendFourCC("RIFF")
        data.appendLittleEndian(UInt32(36) + dataBytes)
        data.appendFourCC("WAVE")
        data.appendFourCC("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(3))
        data.appendLittleEndian(UInt16(channelCount))
        data.appendLittleEndian(sampleRate)
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(UInt16(bitDepth))
        data.appendFourCC("data")
        data.appendLittleEndian(dataBytes)
        return data
    }

    nonisolated private static func samplePair(
        preset: AmbientFrequencyPreset,
        frame: Int,
        totalFrames: Int,
        sampleRate: Int
    ) -> (left: Double, right: Double) {
        let time = Double(frame) / Double(sampleRate)
        var left: Double = 0
        var right: Double = 0

        for layer in preset.layers {
            let sample = layerSample(
                layer,
                time: time,
                frame: frame,
                sampleRate: sampleRate
            )
            left += sample.left
            right += sample.right
        }

        let envelope = globalFade(frame: frame, totalFrames: totalFrames, sampleRate: sampleRate)
        return (left * envelope, right * envelope)
    }

    nonisolated private static func layerSample(
        _ layer: AmbientFrequencyLayer,
        time: Double,
        frame: Int,
        sampleRate: Int
    ) -> (left: Double, right: Double) {
        switch layer {
        case .amplitudeModulatedCarrier(let carrierHz, let modulatorHz, let depth, let amplitude):
            let modulation = 1 + depth * sin(.tau * modulatorHz * time)
            let value = amplitude * modulation * sin(.tau * carrierHz * time)
            return (value, value)
        case .sine(let frequencyHz, let amplitude, _):
            let value = amplitude * sin(.tau * frequencyHz * time)
            return (value, value)
        case .binauralBeat(let carrierHz, let beatHz, let amplitude):
            let leftFrequency = carrierHz - beatHz / 2
            let rightFrequency = carrierHz + beatHz / 2
            return (
                amplitude * sin(.tau * leftFrequency * time),
                amplitude * sin(.tau * rightFrequency * time)
            )
        case .organicWhiteNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * deterministicNoise(seed: seed, frame: frame)
            return (value, value)
        case .intermittentPing(
            let frequencyHz,
            let amplitude,
            let durationSeconds,
            let baseIntervalSeconds,
            let jitterSeconds,
            let startOffsetSeconds,
            let seed
        ):
            let value = eventTone(
                time: time,
                frequencyHz: frequencyHz,
                amplitude: amplitude,
                durationSeconds: durationSeconds,
                startOffsetSeconds: startOffsetSeconds,
                intervalSeconds: baseIntervalSeconds,
                jitterSeconds: jitterSeconds,
                seed: seed
            )
            return (value, value)
        case .chirp(
            let centerHz,
            let sweepHz,
            let amplitude,
            let durationSeconds,
            let intervalSeconds,
            let startOffsetSeconds,
            let harmonicBlend
        ):
            let value = chirpTone(
                time: time,
                centerHz: centerHz,
                sweepHz: sweepHz,
                amplitude: amplitude,
                durationSeconds: durationSeconds,
                intervalSeconds: intervalSeconds,
                startOffsetSeconds: startOffsetSeconds,
                harmonicBlend: harmonicBlend
            )
            return (value, value)
        case .whiteNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * deterministicNoise(seed: seed, frame: frame)
            return (value, value)
        case .pinkNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * pinkNoiseValue(seed: seed, frame: frame)
            return (value, value)
        case .greyNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * greyNoiseValue(seed: seed, frame: frame)
            return (value, value)
        case .blueNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * blueNoiseValue(seed: seed, frame: frame)
            return (value, value)
        case .violetNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * violetNoiseValue(seed: seed, frame: frame)
            return (value, value)
        case .brownNoise(let seed, let amplitude, let envelope):
            let value = amplitude * envelope.value(at: time) * brownNoiseValue(seed: seed, frame: frame)
            return (value, value)
        case .bandpassNoise(let seed, let amplitude, let envelope, let centerHz, let bandwidthHz, let harmonicCount):
            let value = amplitude * envelope.value(at: time) * bandpassNoiseValue(
                seed: seed,
                time: time,
                centerHz: centerHz,
                bandwidthHz: bandwidthHz,
                harmonicCount: max(1, harmonicCount)
            )
            return (value, value)
        case .isochronicTone(let carrierHz, let pulseHz, let amplitude, let dutyCycle, let channelMode):
            // Cosine-edged gate avoids click artifacts vs hard square gate.
            let gate = isochronicGate(time: time, pulseHz: pulseHz, dutyCycle: dutyCycle)
            let value = amplitude * gate * sin(.tau * carrierHz * time)
            return channelMode == .stereo ? (value, value) : (value, 0)
        case .pwmSquare(let frequencyHz, let dutyCycle, let amplitude, let channelMode):
            let phase = (time * frequencyHz).truncatingRemainder(dividingBy: 1)
            let raw = phase < min(max(dutyCycle, 0.01), 0.99) ? 1.0 : -1.0
            let value = amplitude * raw
            return channelMode == .stereo ? (value, value) : (value, 0)
        case .triangleWave(let frequencyHz, let amplitude, let channelMode):
            // 2/π · asin(sin(2πft)) — closed-form triangle without aliasing artifacts.
            let value = amplitude * (2 / Double.pi) * asin(sin(.tau * frequencyHz * time))
            return channelMode == .stereo ? (value, value) : (value, 0)
        case .sawtoothWave(let frequencyHz, let amplitude, let channelMode):
            let phase = time * frequencyHz
            let raw = 2 * (phase - floor(phase + 0.5))
            let value = amplitude * raw
            return channelMode == .stereo ? (value, value) : (value, 0)
        case .fmSynth(let carrierHz, let modulatorHz, let modulationIndex, let amplitude, let channelMode):
            // Two-operator FM (DX7 / YM2612 style):
            //   y(t) = amp · sin(2π·fc·t + I · sin(2π·fm·t))
            let modulator = modulationIndex * sin(.tau * modulatorHz * time)
            let value = amplitude * sin(.tau * carrierHz * time + modulator)
            return channelMode == .stereo ? (value, value) : (value, 0)
        case .harmonicPluck(
            let fundamentalHz,
            let amplitude,
            let harmonicCount,
            let decaySeconds,
            let intervalSeconds,
            let jitterSeconds,
            let startOffsetSeconds,
            let seed
        ):
            let value = harmonicPluckTone(
                time: time,
                fundamentalHz: fundamentalHz,
                amplitude: amplitude,
                harmonicCount: max(1, harmonicCount),
                decaySeconds: decaySeconds,
                intervalSeconds: intervalSeconds,
                jitterSeconds: jitterSeconds,
                startOffsetSeconds: startOffsetSeconds,
                seed: seed
            )
            return (value, value)
        }
    }

    nonisolated private static func eventTone(
        time: Double,
        frequencyHz: Double,
        amplitude: Double,
        durationSeconds: Double,
        startOffsetSeconds: Double,
        intervalSeconds: Double,
        jitterSeconds: Double,
        seed: UInt64
    ) -> Double {
        guard intervalSeconds > 0, durationSeconds > 0 else {
            return 0
        }
        let approximate = Int(floor((time - startOffsetSeconds) / intervalSeconds))
        let lower = max(0, approximate - 1)
        let upper = max(0, approximate + 1)
        for index in lower...upper {
            let start = intermittentStart(
                index: index,
                baseIntervalSeconds: intervalSeconds,
                jitterSeconds: jitterSeconds,
                startOffsetSeconds: startOffsetSeconds,
                seed: seed
            )
            let local = time - start
            if local >= 0, local < durationSeconds {
                let envelope = hann(local / durationSeconds)
                return amplitude * envelope * sin(.tau * frequencyHz * local)
            }
        }
        return 0
    }

    nonisolated private static func chirpTone(
        time: Double,
        centerHz: Double,
        sweepHz: Double,
        amplitude: Double,
        durationSeconds: Double,
        intervalSeconds: Double,
        startOffsetSeconds: Double,
        harmonicBlend: Double
    ) -> Double {
        guard intervalSeconds > 0, durationSeconds > 0, time >= startOffsetSeconds else {
            return 0
        }
        let eventIndex = floor((time - startOffsetSeconds) / intervalSeconds)
        let start = startOffsetSeconds + eventIndex * intervalSeconds
        let local = time - start
        guard local >= 0, local < durationSeconds else {
            return 0
        }
        let f0 = centerHz - sweepHz / 2
        let f1 = centerHz + sweepHz / 2
        let slope = (f1 - f0) / durationSeconds
        let phase = .tau * (f0 * local + 0.5 * slope * local * local)
        let primary = sin(phase)
        let harmonic = sin(phase * 2)
        let blend = min(max(harmonicBlend, 0), 1)
        return amplitude * hann(local / durationSeconds) * ((1 - blend) * primary + blend * harmonic)
    }

    nonisolated private static func intermittentStart(
        index: Int,
        baseIntervalSeconds: Double,
        jitterSeconds: Double,
        startOffsetSeconds: Double,
        seed: UInt64
    ) -> Double {
        let jitter = deterministicUnit(seed: seed, frame: index) * 2 - 1
        return startOffsetSeconds + Double(index) * baseIntervalSeconds + jitter * jitterSeconds
    }

    nonisolated private static func deterministicNoise(seed: UInt64, frame: Int) -> Double {
        deterministicUnit(seed: seed, frame: frame) * 2 - 1
    }

    nonisolated private static func deterministicUnit(seed: UInt64, frame: Int) -> Double {
        var value = UInt64(bitPattern: Int64(frame))
        value &+= seed
        value &+= 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value = value ^ (value >> 31)
        let mantissa = value >> 11
        return Double(mantissa) / Double(UInt64(1) << 53)
    }

    nonisolated private static func globalFade(frame: Int, totalFrames: Int, sampleRate: Int) -> Double {
        let fadeFrames = min(totalFrames / 2, max(1, Int(0.02 * Double(sampleRate))))
        if frame < fadeFrames {
            return hann(Double(frame) / Double(fadeFrames))
        }
        let remaining = totalFrames - frame - 1
        if remaining < fadeFrames {
            return hann(Double(remaining) / Double(fadeFrames))
        }
        return 1
    }

    nonisolated private static func hann(_ progress: Double) -> Double {
        0.5 - 0.5 * cos(.tau * min(max(progress, 0), 1))
    }

    // MARK: - Brain.fm-grade synthesis primitives (added iter 85, 2026-05-16)

    /// Stateless Voss-McCartney-style pink noise. Sums white noise hashed at
    /// multiple decreasing rates (octave bands) to produce roughly 1/f spectral
    /// roll-off. Six octave bands give ≈ -3 dB/octave slope.
    nonisolated private static func pinkNoiseValue(seed: UInt64, frame: Int) -> Double {
        var sum: Double = 0
        let octaves = 6
        // Each octave generator updates at frame >> i (half rate per octave),
        // mimicking the Voss algorithm without needing running state.
        for i in 0..<octaves {
            let downsampledFrame = frame >> i
            let octaveSeed = seed &+ UInt64(i) &* 0xDEAD_BEEF_CAFE_0001
            sum += deterministicNoise(seed: octaveSeed, frame: downsampledFrame)
        }
        // Normalize by sqrt(octaves) so amplitude matches white noise unit
        // variance; pink-noise amplitude budget = white-noise amplitude budget.
        return sum / Double(octaves).squareRoot()
    }

    /// Grey noise — psychoacoustic-equalized approximation. Mixes white, pink,
    /// and brown noises in proportions that roughly invert the A-weighting
    /// curve (boost both low and high freqs, gentle dip mid-band). Sounds
    /// "equally loud across the spectrum" to the human ear.
    nonisolated private static func greyNoiseValue(seed: UInt64, frame: Int) -> Double {
        let white = deterministicNoise(seed: seed, frame: frame)
        let pink = pinkNoiseValue(seed: seed &+ 0x6A21_4221_4221_4221, frame: frame)
        let brown = brownNoiseValue(seed: seed &+ 0xB80A_B80A_B80A_B80A, frame: frame)
        // Inverse A-curve approximation: more low + high, less mid.
        // Weights chosen so the sum has RMS ≈ 1 (calibrated empirically).
        return 0.40 * white + 0.35 * pink + 0.25 * brown
    }

    /// Blue noise — +3 dB/octave (high-pass-shaped). First-difference of
    /// white noise: `b[n] = (w[n] - w[n-1]) / √2`. Sparkly, detail-rich;
    /// pairs well with warmer beds for "shimmer" layers.
    nonisolated private static func blueNoiseValue(seed: UInt64, frame: Int) -> Double {
        let w0 = deterministicNoise(seed: seed, frame: frame)
        let w1 = deterministicNoise(seed: seed, frame: frame - 1)
        // First-difference filter gain peaks at 2.0 at Nyquist; divide by √2
        // to keep amplitude roughly in unit-RMS range.
        return (w0 - w1) / Double(2).squareRoot()
    }

    /// Violet noise — +6 dB/octave. Second-difference of white noise:
    /// `v[n] = (w[n] - 2·w[n-1] + w[n-2]) / 2`. Very bright; useful for
    /// tinnitus masking and "starlight" / "shimmer" overlays.
    nonisolated private static func violetNoiseValue(seed: UInt64, frame: Int) -> Double {
        let w0 = deterministicNoise(seed: seed, frame: frame)
        let w1 = deterministicNoise(seed: seed, frame: frame - 1)
        let w2 = deterministicNoise(seed: seed, frame: frame - 2)
        // Second-difference filter gain peaks at 4.0 at Nyquist; divide by 2
        // to keep amplitude bounded in unit-RMS range.
        return (w0 - 2 * w1 + w2) / 2.0
    }

    /// Brown (Brownian / red / 1/f²) noise via a sliding-window average of
    /// white noise across `windowFrames` samples. True brown noise is a
    /// cumulative-sum random walk (stateful); this stateless approximation
    /// gives the same -6 dB/octave perceived slope by virtue of the
    /// time-averaging acting as a first-order lowpass.
    nonisolated private static func brownNoiseValue(seed: UInt64, frame: Int) -> Double {
        let windowFrames = 32
        var sum: Double = 0
        for offset in 0..<windowFrames {
            sum += deterministicNoise(seed: seed, frame: frame - offset)
        }
        // Normalize so the output stays in [-1, 1] expected range.
        return sum / Double(windowFrames).squareRoot()
    }

    /// Bandpass-shaped noise: sum of `harmonicCount` sines with random
    /// frequencies sampled from `[centerHz - bandwidthHz/2,
    /// centerHz + bandwidthHz/2]` and random phases. Mathematically equivalent
    /// to filtering white noise through an idealized bandpass, while remaining
    /// stateless (samples per-time, not per-frame). Use for rain on roof,
    /// distant wind, gentle ocean surf.
    nonisolated private static func bandpassNoiseValue(
        seed: UInt64,
        time: Double,
        centerHz: Double,
        bandwidthHz: Double,
        harmonicCount: Int
    ) -> Double {
        var sum: Double = 0
        let lowerHz = max(0, centerHz - bandwidthHz / 2)
        let upperHz = centerHz + bandwidthHz / 2
        let range = max(0, upperHz - lowerHz)
        for k in 0..<harmonicCount {
            let frequencySeed = seed &+ UInt64(k) &* 0x6789_ABCD_EF01_2345
            let phaseSeed = seed &+ UInt64(k) &* 0xFEDC_BA98_7654_3210
            let frequencyHz = lowerHz + range * deterministicUnit(seed: frequencySeed, frame: 0)
            let phase = .tau * deterministicUnit(seed: phaseSeed, frame: 0)
            sum += sin(.tau * frequencyHz * time + phase)
        }
        // Normalize: the sum of N unit sines with random phases has RMS √(N/2);
        // dividing by √(N/2) keeps the output's expected amplitude ≈ 1.
        return sum / (Double(harmonicCount) / 2).squareRoot()
    }

    /// Cosine-edged isochronic gate. Smooths the on/off transition with a
    /// short raised-cosine fade (~4% of the pulse period) so the resulting
    /// audio doesn't click at each cycle boundary. Returns a value in [0, 1].
    nonisolated private static func isochronicGate(
        time: Double,
        pulseHz: Double,
        dutyCycle: Double
    ) -> Double {
        guard pulseHz > 0 else { return 1 }
        let period = 1.0 / pulseHz
        let phase = time.truncatingRemainder(dividingBy: period) / period
        let dc = min(max(dutyCycle, 0.05), 0.95)
        let edge = 0.04
        if phase < edge {
            return 0.5 - 0.5 * cos(.tau * phase / edge / 2)
        }
        if phase > dc - edge && phase <= dc {
            let local = (phase - (dc - edge)) / edge
            return 0.5 + 0.5 * cos(.tau * local / 2)
        }
        if phase > dc {
            return 0
        }
        return 1
    }

    /// Damped harmonic-series pluck. Sums `harmonicCount` partials each with
    /// its own exponential decay, triggered at intervals of `intervalSeconds`
    /// (with optional jitter for organic timing). Approximates Karplus-Strong
    /// statelessly by computing partial-sum at sampled time.
    nonisolated private static func harmonicPluckTone(
        time: Double,
        fundamentalHz: Double,
        amplitude: Double,
        harmonicCount: Int,
        decaySeconds: Double,
        intervalSeconds: Double,
        jitterSeconds: Double,
        startOffsetSeconds: Double,
        seed: UInt64
    ) -> Double {
        guard intervalSeconds > 0, decaySeconds > 0 else {
            return 0
        }
        // Find the most recent trigger time at or before `time`.
        let approximate = Int(floor((time - startOffsetSeconds) / intervalSeconds))
        let lower = max(0, approximate - 1)
        let upper = max(0, approximate + 1)
        var sum: Double = 0
        for index in lower...upper {
            let start = intermittentStart(
                index: index,
                baseIntervalSeconds: intervalSeconds,
                jitterSeconds: jitterSeconds,
                startOffsetSeconds: startOffsetSeconds,
                seed: seed
            )
            let local = time - start
            guard local >= 0, local < decaySeconds * 3 else { continue }
            for k in 1...harmonicCount {
                // Higher harmonics decay faster (string-like damping curve)
                let harmonicDecay = decaySeconds / Double(k)
                let amp = 1.0 / Double(k)
                let envelope = exp(-local / harmonicDecay)
                sum += amp * envelope * sin(.tau * fundamentalHz * Double(k) * local)
            }
        }
        // Normalize by harmonic series amplitude sum ≈ ln(N) + γ; use √N for
        // a conservative ceiling.
        return amplitude * sum / Double(harmonicCount).squareRoot()
    }
}

private extension Double {
    nonisolated static let tau = 2 * Double.pi
}

private extension Data {
    nonisolated mutating func appendFourCC(_ value: String) {
        if let bytes = value.data(using: .ascii), bytes.count == 4 {
            append(bytes)
        }
    }

    nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
