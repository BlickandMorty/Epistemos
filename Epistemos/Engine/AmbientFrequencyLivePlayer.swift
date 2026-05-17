import AVFoundation
import Foundation

/// Real-time live frequency player for the Ambient Frequencies feature.
///
/// Architecture (per research 2026-05-16, primary sources W3C Web Audio §6.3.3,
/// WWDC 2019 §510 "What's New in AVAudioEngine", musicdsp.org one-pole
/// smoother, Analog Devices DDS reference):
///
/// - `AVAudioEngine` + `AVAudioSourceNode` — the canonical Apple stack for
///   custom synth callbacks since 2019. MAS-safe (no subprocess, no JIT for
///   user code). Auto-handles audio session, format negotiation, headphone
///   route changes.
///
/// - Single phase accumulator (Double) for click-free frequency changes
///   (NCO/DDS pattern: `phase += freq / sampleRate; sample = sin(2π·phase)`).
///   Phase is per-instance state, NEVER reset on parameter change — that's
///   how the user can sweep 100 Hz → 10 kHz without any clicks.
///
/// - One-pole IIR smoothers per parameter to defeat zipper noise:
///   `smoothed = α·smoothed + (1-α)·target` per sample. Time constants:
///   20 ms for gain/pan (snappy), 80 ms for frequency (pitch is exponential
///   in human perception; longer smoothing is more "musical").
///
/// - SwiftUI ↔ audio thread bridge: target values held in a class with
///   `@unchecked Sendable` + UnsafeMutablePointer to Float32 storage.
///   Naturally-aligned 32-bit reads/writes are atomic on Apple Silicon
///   (ARM64v8 atomic-load/store guarantee). Smoother absorbs any tearing.
///
/// - Equal-power pan (W3C spec): `leftGain = cos(x·π/2); rightGain = sin(x·π/2)`
///   where x = (pan+1)/2. Matches `AmbientFrequencyLayer.applyEqualPowerPan`.
///
/// - EML (Helios V6.1 F-ULP-Oracle): intentionally NOT in the render hot path.
///   Per the iter-86 deep research, EML has no audio-DSP relevance. Left as
///   `#if EPISTEMOS_EML_VERIFY` debug-only probe stub for future verification
///   work.
///
/// USAGE:
/// ```swift
/// let player = AmbientFrequencyLivePlayer()
/// try player.start()
/// player.setFrequency(440)           // 440 Hz A
/// player.setWaveform(.sineWave)
/// player.setPan(-0.5)                // half-left
/// player.setGain(0.3)
/// // ... user moves sliders, params update in real time ...
/// player.stop()
/// ```
///
/// Threading:
/// - UI methods (`setFrequency`, `setPan`, etc.) — call from any thread.
/// - `start()` / `stop()` — call from main actor; throws if engine setup fails.
/// - The audio render block runs on a real-time audio thread (DO NOT call
///   `print()`, `os_log`, alloc, lock, or any Swift class method from it).
@MainActor
final class AmbientFrequencyLivePlayer {

    // MARK: - Public configuration

    enum Waveform: Int, CaseIterable, Identifiable, Sendable {
        case sineWave = 0
        case triangleWave = 1
        case sawtoothWave = 2
        case squareWave = 3
        case whiteNoise = 4

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .sineWave: return "Sine"
            case .triangleWave: return "Triangle"
            case .sawtoothWave: return "Sawtooth"
            case .squareWave: return "Square (50% PWM)"
            case .whiteNoise: return "White noise"
            }
        }
    }

    /// Min slider value (Hz) — slightly above zero to avoid divide-by-zero
    /// edge cases and sub-hearing infrasound.
    static let minFrequencyHz: Float = 20

    /// Max slider value (Hz) — half of the lowest expected sample rate
    /// (22.05 kHz Nyquist at 44.1k) minus a safety margin.
    static let maxFrequencyHz: Float = 20_000

    // MARK: - Private state

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning = false

    /// Shared parameter block accessible from both UI and audio thread.
    /// Naturally-aligned 32-bit Float reads/writes are atomic on Apple
    /// Silicon. The smoother on the audio side absorbs any value tearing.
    private let params = LivePlayerParameters()

    /// UI/UX audit 2026-05-17 iter-2 P2-3 (deep-hardening):
    /// AVAudioEngineConfigurationChange observer. macOS posts this
    /// notification whenever the audio route changes (headphones plug
    /// /unplug, sample-rate switch, hardware swap). When fired, the
    /// engine has already stopped internally — we need to rebuild the
    /// source node with the new output format so the render block's
    /// captured sample rate stays valid, and re-compute the smoother
    /// coefficients (α depends on the new fs).
    private var configChangeObserver: NSObjectProtocol?

    // MARK: - Public control

    /// Start the engine. Idempotent; safe to call multiple times.
    func start() throws {
        guard !isRunning else { return }

        // Determine the hardware output format the system gives us.
        // Defaults to 48 kHz stereo on most macOS hardware; 44.1 kHz on
        // AirPods etc. **Defensive fallback** to 44.1 kHz / stereo if
        // the output node reports a degenerate format (sampleRate == 0
        // or channelCount == 0) — observed on macOS when the engine is
        // queried before the audio HAL has activated a default device.
        // Without this fallback, `AVAudioFormat(standardFormatWithSampleRate:
        // channels:)` returns nil and we hit
        // `couldNotCreateRenderFormat`, which the user sees as "Live
        // player failed: …".
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let resolvedSampleRate: Double = outputFormat.sampleRate > 0
            ? outputFormat.sampleRate
            : 44_100
        let resolvedChannelCount: AVAudioChannelCount = outputFormat.channelCount >= 1
            ? max(2, outputFormat.channelCount)
            : 2

        // Build a stereo render format so we can deliver per-channel L/R.
        // Use the same sample rate the hardware chose to avoid format
        // mismatch + extra conversion in the engine. mainMixerNode
        // internally re-samples to the actual hardware rate if needed.
        guard let renderFormat = AVAudioFormat(
            standardFormatWithSampleRate: resolvedSampleRate,
            channels: resolvedChannelCount
        ) else {
            throw AmbientFrequencyLivePlayerError.couldNotCreateRenderFormat
        }

        let sampleRate = resolvedSampleRate

        let params = self.params
        params.precomputeSmootherCoefficients(sampleRate: Float(sampleRate))

        // The render block runs on a real-time audio thread. NO Swift class
        // calls, NO allocations, NO locks. Just pointer math + libm.
        let node = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList in
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Stereo render: write left into buffers[0], right into buffers[1].
            // SwiftUI standard format is non-interleaved 32-bit float, so each
            // buffer holds `frameCount` Float32 samples.
            guard bufferList.count >= 2 else {
                // Fallback: zero out everything and bail.
                for buffer in bufferList {
                    if let data = buffer.mData {
                        memset(data, 0, Int(buffer.mDataByteSize))
                    }
                }
                return noErr
            }

            let leftPtr = bufferList[0].mData?.assumingMemoryBound(to: Float.self)
            let rightPtr = bufferList[1].mData?.assumingMemoryBound(to: Float.self)
            guard let leftPtr, let rightPtr else { return noErr }

            params.renderBlock(
                leftPtr: leftPtr,
                rightPtr: rightPtr,
                frameCount: Int(frameCount),
                sampleRate: Float(sampleRate)
            )

            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: renderFormat)

        // `prepare()` allocates audio hardware resources ahead of start.
        // Without this, first-launch start() can fail with
        // `AVAudioEngineErrorCodeCannotStartEngine` because the engine
        // hasn't yet wired up its render thread or claimed an output
        // device. The call is idempotent — repeat invocations are safe.
        engine.prepare()

        do {
            try engine.start()
        } catch {
            // Defensive cleanup: leave the engine in a sane state if
            // start fails so the next user click can retry without
            // leaking an attached-but-disconnected source node.
            engine.detach(node)
            throw AmbientFrequencyLivePlayerError.engineStartFailed(
                underlying: error.localizedDescription
            )
        }
        sourceNode = node
        isRunning = true

        // Subscribe to route / sample-rate changes after the engine is
        // running. The handler hops to MainActor (this class is
        // @MainActor) and re-runs start() against the new output
        // format — without this, a headphone unplug would leave the
        // smoother coefficients tuned to the old fs and the render
        // block's captured sample rate value stale.
        if configChangeObserver == nil {
            configChangeObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleConfigurationChange()
                }
            }
        }
    }

    /// Re-derive the render graph after the OS reports a configuration
    /// change. AVAudioEngine has already stopped itself by the time
    /// this fires; we tear down our source node + restart cleanly so
    /// the new output sample rate flows through the smoother and the
    /// render closure both.
    private func handleConfigurationChange() {
        guard configChangeObserver != nil else { return }
        // Mark not-running so start() doesn't bail at its idempotency
        // guard. Detach the stale source node first; the engine itself
        // is already stopped.
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        isRunning = false
        // Re-enter the start path. If anything fails (route became
        // unusable mid-flight) we end in the stopped state, which is
        // safe — the UI's livePlayerRunning flag will be re-armed on
        // the next user click.
        try? start()
    }

    /// Stop the engine. Idempotent.
    func stop() {
        guard isRunning else {
            // Even if not running, drop the observer if it's somehow
            // dangling — defensive against partial-init or repeated-
            // stop sequences.
            detachConfigChangeObserver()
            return
        }
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        isRunning = false
        detachConfigChangeObserver()
    }

    private func detachConfigChangeObserver() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }
    }

    // MARK: - Parameter setters (UI side; any thread)

    /// Set the target frequency in Hz. The render thread smooths via one-pole
    /// IIR (80 ms time constant for musical pitch glides without zipper noise).
    func setFrequency(_ hz: Float) {
        let clamped = min(max(hz, Self.minFrequencyHz), Self.maxFrequencyHz)
        params.targetFrequency = clamped
    }

    /// Set stereo pan: -1 = full left, 0 = center (-3 dB equal-power),
    /// +1 = full right.
    func setPan(_ pan: Float) {
        params.targetPan = min(max(pan, -1), 1)
    }

    /// Set output gain ∈ [0, 1].
    func setGain(_ gain: Float) {
        params.targetGain = min(max(gain, 0), 1)
    }

    /// Set the active waveform.
    func setWaveform(_ waveform: Waveform) {
        params.waveform = waveform.rawValue
    }

    /// Toggle mute (gain → 0 with smoothing; doesn't reset phase).
    func setMuted(_ muted: Bool) {
        params.muted = muted
    }

    /// Set live bit-depth crush. `bitDepth ∈ [1, 16]`; 16 = no effect,
    /// 8 = Amiga/NES era, 4 = Atari 4-bit volume, 1 = PC speaker beeper.
    /// Applied after the waveform, before pan/gain. Real-time updatable.
    func setBitCrushDepth(_ bits: Int) {
        params.bitCrushDepth = min(max(bits, 1), 16)
    }

    /// Set live sample-rate reduction (zero-order hold). `holdFactor ∈ [1, 64]`;
    /// 1 = no effect, 8 = every 8th sample held (8 kHz effective at 64 kHz).
    /// The aliasing IS the vintage chip effect.
    func setSampleRateHold(_ factor: Int) {
        params.sampleRateHold = min(max(factor, 1), 64)
    }

    /// Audiophile-grade master volume in decibels. Range [-60, +6] dB.
    /// Applied at the *end* of the render chain, after pan + bit-crush
    /// + SRR + HPF, so it scales the final mixed output uniformly.
    /// 0 dB = unity gain (matches the `gain` slider's 1.0 reference);
    /// negative values attenuate; +6 dB doubles amplitude (and is
    /// safely caught by the soft-clip limiter below if enabled).
    /// Smoothed via the existing gain α (~20 ms) so changes are
    /// click-free.
    func setMasterVolumeDb(_ db: Float) {
        params.targetMasterVolumeDb = min(max(db, -60), 6)
    }

    /// Soft-clip limiter on / off. When on, the final output passes
    /// through a stateless cubic soft-clipper that smoothly limits
    /// peaks to ±0.95 instead of hard-clipping at ±1.0. Recommended
    /// on by default — clipping into a DAC is audibly harsh; this
    /// catches accidental gain spikes from interactive sliders.
    /// (Musicdsp.org #79 Schlecht soft-clip topology.)
    func setLimiterEnabled(_ enabled: Bool) {
        params.limiterEnabled = enabled
    }

    /// High-pass filter cutoff in Hz applied to the final mix. Removes
    /// DC offset + sub-sonic rumble that bit-crush + SRR can introduce
    /// at extreme settings. Default 20 Hz (below human hearing).
    /// Setting to 0 disables the filter entirely.
    func setHighPassCutoffHz(_ hz: Float) {
        params.highPassCutoffHz = min(max(hz, 0), 200)
    }

    // MARK: - Read-only state observation (UI side)

    var currentSmoothedFrequency: Float { params.smoothedFrequencyForUI }
    var currentSmoothedPan: Float { params.smoothedPanForUI }
    var currentSmoothedGain: Float { params.smoothedGainForUI }

    /// Peak amplitude observed during the last render block (in linear
    /// units, [0, 1]). Use for a VU-style meter. Updated atomically
    /// at the end of each render callback.
    var currentPeakLevel: Float { params.peakLevelForUI }
}

/// Shared parameter block. UI-side mutations are atomic per-field (single
/// Float read/write is atomic on Apple Silicon). The audio-thread render
/// block consumes the targets through one-pole IIR smoothers.
///
/// Marked `@unchecked Sendable` because we manage thread safety manually
/// per field — Swift's strict concurrency can't see through the atomic
/// guarantees provided by Apple Silicon's ARM64v8 spec.
private final class LivePlayerParameters: @unchecked Sendable {

    // Target values written by UI; read by audio thread.
    var targetFrequency: Float = 440
    var targetPan: Float = 0
    var targetGain: Float = 0.3
    var waveform: Int = AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue
    var muted: Bool = false
    /// Bit-depth crush, [1, 16]; 16 = no effect, lower = "pixel crunch."
    var bitCrushDepth: Int = 16
    /// Sample-rate reduction (zero-order hold), [1, 64]; 1 = no effect.
    var sampleRateHold: Int = 1
    /// Master volume in dB, [-60, +6]. 0 dB = unity gain. Applied at the
    /// END of the render chain (post-pan, post-pixel-crunch).
    var targetMasterVolumeDb: Float = 0
    /// Soft-clip limiter on/off. Default true — catches accidental
    /// gain spikes before they reach the DAC.
    var limiterEnabled: Bool = true
    /// High-pass cutoff in Hz, [0, 200]. Default 20 Hz removes DC +
    /// sub-sonic rumble that pixel-crunch can introduce. 0 disables.
    var highPassCutoffHz: Float = 20

    // Smoothed values updated per-sample on audio thread; mirrored to UI
    // for visual feedback. UI-side reads are atomic Float; small tearing OK.
    var smoothedFrequencyForUI: Float = 440
    var smoothedPanForUI: Float = 0
    var smoothedGainForUI: Float = 0.3
    /// Atomic peak-level mirror, [0, 1]. UI polls via TimelineView for
    /// a VU-style meter. Updated once per render callback (end of
    /// `renderBlock`), so it tracks block-peak rather than sample-peak —
    /// good enough for a 30 Hz UI refresh.
    var peakLevelForUI: Float = 0

    // Smoother state (audio-thread only).
    private var smoothedFrequency: Float = 440
    private var smoothedPan: Float = 0
    private var smoothedGain: Float = 0.3
    /// Master volume smoothed linearly per sample. Computed from dB at
    /// the per-frame boundary so dB scrub is smooth in perceived loudness.
    private var smoothedMasterVolumeLinear: Float = 1.0
    /// One-pole HPF state per channel. y[n] = α·(y[n-1] + x[n] - x[n-1])
    /// — see musicdsp.org #117 (Andrew Simper's 1-pole HPF).
    private var hpfLastInputLeft: Float = 0
    private var hpfLastOutputLeft: Float = 0
    private var hpfLastInputRight: Float = 0
    private var hpfLastOutputRight: Float = 0
    /// Last seen HPF cutoff so we can re-derive α only when the user
    /// drags the slider, not every sample.
    private var lastSeenHpfCutoff: Float = -1
    private var hpfAlpha: Float = 0

    // Smoother coefficients (precomputed on sample-rate set).
    private var gainPanAlpha: Float = 0.999    // ~20 ms
    private var frequencyAlpha: Float = 0.9998 // ~80 ms

    // Phase accumulator [0, 1) — DDS-style. Click-free freq changes.
    private var phase: Double = 0

    // Noise PRNG state (audio-thread only).
    private var noiseState: UInt64 = 0xCAFE_BABE_DEAD_BEEF

    // Sample-rate-reduce state: counter + last-held sample.
    private var holdCounter: Int = 0
    private var heldSample: Float = 0
    // UI/UX audit 2026-05-17 P2-1: when the user drags the SRR slider
    // mid-render, reset the holdCounter so the next sample refreshes
    // from the live waveform instead of replaying a stale heldSample
    // until the counter wraps modulo the new hold value.
    private var lastSeenSampleRateHold: Int = 1

    /// Precompute smoother coefficients for the given sample rate. Called
    /// once at engine start (and on sample-rate changes if the OS swaps
    /// audio routes).
    func precomputeSmootherCoefficients(sampleRate: Float) {
        // α = exp(-1 / (timeConstantSeconds · sampleRate))
        let gainPanTimeConstant: Float = 0.020   // 20 ms — snappy
        let frequencyTimeConstant: Float = 0.080 // 80 ms — musical pitch glide
        gainPanAlpha = exp(-1.0 / (gainPanTimeConstant * sampleRate))
        frequencyAlpha = exp(-1.0 / (frequencyTimeConstant * sampleRate))
    }

    /// Real-time render block. NO allocations, NO locks, NO Swift class
    /// dispatch from here. Just scalar math + pointer writes.
    func renderBlock(
        leftPtr: UnsafeMutablePointer<Float>,
        rightPtr: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Float
    ) {
        let halfPi: Float = .pi / 2
        let twoPi: Double = 2.0 * .pi
        let mutedFlag = muted

        // Audiophile-grade chain prep — per-frame, NOT per-sample:
        //
        // 1. Master volume target in linear units (10^(dB/20)). dB → linear
        //    conversion is expensive (exp10), so we do it once per frame
        //    and per-sample smooth toward that linear target via the
        //    existing gainPanAlpha (≈ 20 ms). dB scrub feels perceptually
        //    smooth because dB itself is a logarithmic scale.
        // 2. HPF coefficient α — re-derive ONLY when the cutoff actually
        //    changes (compared via `lastSeenHpfCutoff`). At fc=20 Hz,
        //    fs=48 kHz: α ≈ 0.9974. Cutoff = 0 disables the filter.
        // 3. Peak-tracker reset for this block. Per-frame peak feeds the
        //    UI VU meter; we mirror the max(|L|, |R|) seen this block.
        let masterTargetLinear = powf(10, targetMasterVolumeDb / 20)
        let cutoff = highPassCutoffHz
        if cutoff != lastSeenHpfCutoff {
            lastSeenHpfCutoff = cutoff
            if cutoff > 0 {
                // One-pole HPF α = exp(-2π · fc / fs). Musicdsp.org #117.
                hpfAlpha = expf(-2.0 * .pi * cutoff / sampleRate)
            } else {
                hpfAlpha = 0
            }
        }
        let hpfEnabled = cutoff > 0
        let limiterOn = limiterEnabled
        var blockPeak: Float = 0

        for i in 0..<frameCount {
            // 1) Smooth params (one-pole IIR per sample).
            smoothedFrequency = frequencyAlpha * smoothedFrequency + (1 - frequencyAlpha) * targetFrequency
            smoothedPan = gainPanAlpha * smoothedPan + (1 - gainPanAlpha) * targetPan
            let gainTarget = mutedFlag ? 0 : targetGain
            smoothedGain = gainPanAlpha * smoothedGain + (1 - gainPanAlpha) * gainTarget

            // 2) Advance phase accumulator. Phase is double-precision to
            //    avoid drift over long renders.
            phase += Double(smoothedFrequency) / Double(sampleRate)
            phase -= floor(phase)

            // 3) Compute waveform sample at current phase.
            let sample: Float
            switch waveform {
            case 0: // sineWave
                sample = Float(sin(phase * twoPi))
            case 1: // triangleWave
                // 2/π · asin(sin(2πφ)) — closed-form aliasing-free triangle.
                sample = Float((2.0 / .pi) * asin(sin(phase * twoPi)))
            case 2: // sawtoothWave
                sample = Float(2.0 * phase - 1.0)
            case 3: // squareWave (50% PWM)
                sample = phase < 0.5 ? 1 : -1
            case 4: // whiteNoise
                // xorshift64* — fast, deterministic, lock-free.
                var s = noiseState
                s ^= s << 13
                s ^= s >> 7
                s ^= s << 17
                noiseState = s
                // Map to [-1, 1] using high 24 bits as a 24-bit signed float.
                let mantissa = s >> 40
                sample = (Float(mantissa) / Float(UInt32(1) << 23)) - 1.0
            default:
                sample = 0
            }

            // 4) PIXEL CRUNCH — sample-rate reduce (zero-order hold) BEFORE
            //    bit-crush, per Sonalksis/TAL canonical Decimator topology.
            //    Aliasing is the desired effect.
            let hold = sampleRateHold
            // UI/UX audit 2026-05-17 P2-1: when the user changes the hold
            // value mid-render, reset the counter so the next sample
            // refreshes from the live waveform — otherwise the stale
            // heldSample would replay for up to N-1 samples while the
            // counter wraps under the new modulus.
            if hold != lastSeenSampleRateHold {
                holdCounter = 0
                lastSeenSampleRateHold = hold
            }
            var crunched: Float
            if hold > 1 {
                if holdCounter == 0 {
                    heldSample = sample
                }
                crunched = heldSample
                holdCounter = (holdCounter + 1) % hold
            } else {
                crunched = sample
                holdCounter = 0
            }

            // 5) PIXEL CRUNCH — bit-depth crush (musicdsp.org #124 midrise).
            //    bitDepth = 16 → no effect; 8 = Amiga/NES; 4 = Atari; 1 = PC speaker.
            let bits = bitCrushDepth
            if bits < 16 {
                let levels = Float(1 << (bits - 1))
                crunched = (crunched * levels).rounded() / levels
            }

            // 6) Apply gain (legacy "gain" slider, [0, 1]).
            let amped = crunched * smoothedGain

            // 7) Apply equal-power pan (W3C spec).
            let panX = (smoothedPan + 1) * 0.5
            let leftGain = cos(panX * halfPi)
            let rightGain = sin(panX * halfPi)

            var leftSample = amped * leftGain
            var rightSample = amped * rightGain

            // 8) Per-channel one-pole HPF — remove DC drift + sub-sonic
            //    rumble that pixel-crunch + SRR can introduce. State held
            //    in `hpfLast{Input,Output}{Left,Right}` so each render
            //    callback resumes smoothly. Formula per musicdsp.org #117:
            //      y[n] = α·(y[n-1] + x[n] - x[n-1])
            //    α = exp(-2π·fc/fs); larger α = lower cutoff.
            if hpfEnabled {
                let hpfLeft = hpfAlpha * (hpfLastOutputLeft + leftSample - hpfLastInputLeft)
                hpfLastInputLeft = leftSample
                hpfLastOutputLeft = hpfLeft
                leftSample = hpfLeft
                let hpfRight = hpfAlpha * (hpfLastOutputRight + rightSample - hpfLastInputRight)
                hpfLastInputRight = rightSample
                hpfLastOutputRight = hpfRight
                rightSample = hpfRight
            }

            // 9) Smooth master volume toward linear target (post-dB
            //    conversion done at frame boundary). One-pole IIR shares
            //    the gain/pan α (≈ 20 ms) so dB scrub is click-free.
            smoothedMasterVolumeLinear =
                gainPanAlpha * smoothedMasterVolumeLinear +
                (1 - gainPanAlpha) * masterTargetLinear
            leftSample *= smoothedMasterVolumeLinear
            rightSample *= smoothedMasterVolumeLinear

            // 10) Soft-clip limiter (musicdsp.org #79 cubic Schlecht).
            //     y = 1.5·x − 0.5·x³ in [-1, 1], clamps outside ±1.
            //     Stateless, allocation-free, audibly transparent below
            //     0.7 magnitude — only kicks in on accidental spikes.
            //     Keeps peaks ≤ 1.0 so the DAC never hard-clips.
            if limiterOn {
                leftSample = softClipCubic(leftSample)
                rightSample = softClipCubic(rightSample)
            }

            leftPtr[i] = leftSample
            rightPtr[i] = rightSample

            // 11) Peak meter — track block-max |amplitude| for the UI.
            let absLeft = leftSample < 0 ? -leftSample : leftSample
            let absRight = rightSample < 0 ? -rightSample : rightSample
            let frameMax = absLeft > absRight ? absLeft : absRight
            if frameMax > blockPeak { blockPeak = frameMax }
        }

        // Mirror final smoothed values to UI-readable fields (atomic Float
        // writes; small tearing absorbed by SwiftUI poll cadence).
        smoothedFrequencyForUI = smoothedFrequency
        smoothedPanForUI = smoothedPan
        smoothedGainForUI = smoothedGain
        peakLevelForUI = blockPeak
    }

    /// Stateless cubic soft-clipper from musicdsp.org #79 (Schlecht
    /// 2002). Smooth transition through the linear region around 0,
    /// gentle saturation as |x| approaches 1, and hard-clamp outside
    /// ±1. Allocation-free, no branches in the hot path beyond the
    /// magnitude compare. Audibly transparent below ~0.7 magnitude.
    @inline(__always)
    private func softClipCubic(_ x: Float) -> Float {
        if x >= 1 { return 1 }
        if x <= -1 { return -1 }
        return 1.5 * x - 0.5 * x * x * x
    }
}

enum AmbientFrequencyLivePlayerError: Error, LocalizedError {
    case couldNotCreateRenderFormat
    /// `engine.start()` threw — wrap the system error message so the UI
    /// can surface a meaningful hint (most common cause on macOS: no
    /// audio output device available, or the HAL hasn't activated one
    /// yet). User-facing message includes the underlying error string
    /// so an end-user bug report carries enough info to diagnose.
    case engineStartFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateRenderFormat:
            return "Could not create AVAudioFormat for live playback (stereo 32-bit float). Try plugging in headphones or unplugging them to force the audio HAL to re-activate."
        case .engineStartFailed(let underlying):
            return "Audio engine could not start: \(underlying). If this persists, check System Settings → Sound for an active output device."
        }
    }
}
