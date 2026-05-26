import AVFoundation
import Foundation

nonisolated private enum AmbientFrequencyDSP {
    static let minFrequencyHz: Float = 20
    static let maxFrequencyHz: Float = 20_000
    static let defaultWaveformRawValue = 0
    static let maxWaveformRawValue = 4

    @inline(__always)
    static func sanitizedFrequency(_ value: Float, fallback: Float) -> Float {
        guard value.isFinite else { return fallback.isFinite ? fallback : 440 }
        return min(max(value, minFrequencyHz), maxFrequencyHz)
    }

    @inline(__always)
    static func sanitizedPan(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, -1), 1)
    }

    @inline(__always)
    static func sanitizedGain(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    @inline(__always)
    static func sanitizedLayerVolume(_ value: Float) -> Float {
        guard value.isFinite else { return 1 }
        return min(max(value, 0), 2)
    }

    @inline(__always)
    static func sanitizedDistortion(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    @inline(__always)
    static func sanitizedWaveform(_ value: Float) -> Int {
        guard value.isFinite else { return defaultWaveformRawValue }
        guard value >= 0, value <= Float(maxWaveformRawValue) else {
            return defaultWaveformRawValue
        }
        return min(max(Int(value.rounded()), defaultWaveformRawValue), maxWaveformRawValue)
    }

    @inline(__always)
    static func sanitizedBitCrushDepth(_ value: Float) -> Int {
        guard value.isFinite else { return 16 }
        if value <= 1 { return 1 }
        if value >= 16 { return 16 }
        return Int(value.rounded())
    }

    @inline(__always)
    static func sanitizedSampleRateHold(_ value: Float) -> Int {
        guard value.isFinite else { return 1 }
        if value <= 1 { return 1 }
        if value >= 64 { return 64 }
        return Int(value.rounded())
    }
}

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
    nonisolated static let minFrequencyHz = AmbientFrequencyDSP.minFrequencyHz

    /// Max slider value (Hz) — half of the lowest expected sample rate
    /// (22.05 kHz Nyquist at 44.1k) minus a safety margin.
    nonisolated static let maxFrequencyHz = AmbientFrequencyDSP.maxFrequencyHz
    nonisolated private static let renderChannelCount: AVAudioChannelCount = 2
    nonisolated private static let fallbackRenderSampleRates: [Double] = [48_000, 44_100]

    // MARK: - Private state

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning = false

    /// Shared parameter block accessible from both UI and audio thread.
    /// Naturally-aligned 32-bit Float reads/writes are atomic on Apple
    /// Silicon. The smoother on the audio side absorbs any value tearing.
    private let params = LivePlayerParameters()

    // MARK: - Public control

    /// Start the engine. Idempotent; safe to call multiple times.
    func start() throws {
        try start(layers: [], controls: [])
    }

    /// Start the engine with the active Ambient Frequencies preset/module
    /// layers. Empty `layers` preserves the original single-oscillator tone
    /// lab path.
    func start(
        layers: [AmbientFrequencyLayer],
        controls: [AmbientFrequencyLayerMixControl] = []
    ) throws {
        guard !isRunning else { return }
        params.configureMix(layers: layers, controls: controls)

        // Determine the hardware output format the system gives us. Defaults
        // to 48 kHz stereo on most macOS hardware; 44.1 kHz on AirPods etc.
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)

        // Build a stereo render format so we can deliver per-channel L/R.
        // Prefer the hardware sample rate, then the mixer rate, then known
        // macOS-safe rates. Some output devices briefly report formats that
        // cannot seed a source-node format while the route is settling.
        let renderFormat = try Self.makeStereoRenderFormat(
            preferredSampleRate: outputFormat.sampleRate,
            fallbackSampleRates: [mixerFormat.sampleRate] + Self.fallbackRenderSampleRates
        )
        let sampleRate = renderFormat.sampleRate

        let params = self.params
        params.precomputeSmootherCoefficients(sampleRate: Float(sampleRate))

        let node = AmbientFrequencyRenderCallback.makeSourceNode(
            renderFormat: renderFormat,
            sampleRate: sampleRate,
            params: params
        )

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: renderFormat)

        do {
            engine.prepare()
            try engine.start()
            sourceNode = node
            isRunning = true
        } catch {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
            sourceNode = nil
            isRunning = false
            throw AmbientFrequencyLivePlayerError.engineStartFailed(underlying: error)
        }
    }

    /// Stop the engine. Idempotent.
    func stop() {
        guard isRunning else { return }
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        isRunning = false
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
        params.waveform = Float(waveform.rawValue)
    }

    /// Toggle mute (gain → 0 with smoothing; doesn't reset phase).
    func setMuted(_ muted: Bool) {
        params.muted = muted ? 1 : 0
    }

    /// Set live bit-depth crush. `bitDepth ∈ [1, 16]`; 16 = no effect,
    /// 8 = Amiga/NES era, 4 = Atari 4-bit volume, 1 = PC speaker beeper.
    /// Applied after the waveform, before pan/gain. Real-time updatable.
    func setBitCrushDepth(_ bits: Int) {
        params.bitCrushDepth = Float(min(max(bits, 1), 16))
    }

    /// Set live sample-rate reduction (zero-order hold). `holdFactor ∈ [1, 64]`;
    /// 1 = no effect, 8 = every 8th sample held (8 kHz effective at 64 kHz).
    /// The aliasing IS the vintage chip effect.
    func setSampleRateHold(_ factor: Int) {
        params.sampleRateHold = Float(min(max(factor, 1), 64))
    }

    /// Update one active preset layer's live mixer controls without
    /// rebuilding the audio graph.
    func setLayerControl(index: Int, control: AmbientFrequencyLayerMixControl) {
        params.setLayerControl(index: index, control: control)
    }

    /// Bulk-update all active preset layer controls.
    func setLayerControls(_ controls: [AmbientFrequencyLayerMixControl]) {
        params.setLayerControls(controls)
    }

    // MARK: - Read-only state observation (UI side)

    var currentSmoothedFrequency: Float { params.smoothedFrequencyForUI }
    var currentSmoothedPan: Float { params.smoothedPanForUI }
    var currentSmoothedGain: Float { params.smoothedGainForUI }

    @inline(__always)
    nonisolated static func sanitizedFrequency(_ value: Float, fallback: Float) -> Float {
        AmbientFrequencyDSP.sanitizedFrequency(value, fallback: fallback)
    }

    @inline(__always)
    nonisolated static func sanitizedPan(_ value: Float) -> Float {
        AmbientFrequencyDSP.sanitizedPan(value)
    }

    @inline(__always)
    nonisolated static func sanitizedGain(_ value: Float) -> Float {
        AmbientFrequencyDSP.sanitizedGain(value)
    }

    @inline(__always)
    nonisolated static func sanitizedWaveform(_ value: Float) -> Int {
        AmbientFrequencyDSP.sanitizedWaveform(value)
    }

    @inline(__always)
    nonisolated static func sanitizedBitCrushDepth(_ value: Float) -> Int {
        AmbientFrequencyDSP.sanitizedBitCrushDepth(value)
    }

    @inline(__always)
    nonisolated static func sanitizedSampleRateHold(_ value: Float) -> Int {
        AmbientFrequencyDSP.sanitizedSampleRateHold(value)
    }

    nonisolated static func makeStereoRenderFormat(
        preferredSampleRate: Double,
        fallbackSampleRates: [Double] = fallbackRenderSampleRates
    ) throws -> AVAudioFormat {
        var seenRates: [Double] = []
        for sampleRate in [preferredSampleRate] + fallbackSampleRates {
            guard sampleRate.isFinite, sampleRate > 0 else { continue }
            guard !seenRates.contains(where: { abs($0 - sampleRate) < 0.0001 }) else { continue }
            seenRates.append(sampleRate)

            if let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: renderChannelCount
            ) {
                return format
            }
            if let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: renderChannelCount,
                interleaved: false
            ) {
                return format
            }
        }
        throw AmbientFrequencyLivePlayerError.couldNotCreateRenderFormat
    }

}

nonisolated private enum AmbientFrequencyRenderCallback {
    static func makeSourceNode(
        renderFormat: AVAudioFormat,
        sampleRate: Double,
        params: LivePlayerParameters
    ) -> AVAudioSourceNode {
        // The render block runs on a real-time audio thread. Build it from a
        // nonisolated helper so Swift never stamps the callback as MainActor.
        AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList in
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in bufferList {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }

            guard bufferList.count >= 2 else {
                return noErr
            }

            let leftPtr = bufferList[0].mData?.assumingMemoryBound(to: Float.self)
            let rightPtr = bufferList[1].mData?.assumingMemoryBound(to: Float.self)
            guard let leftPtr, let rightPtr else { return noErr }
            let leftFrames = Int(bufferList[0].mDataByteSize) / MemoryLayout<Float>.stride
            let rightFrames = Int(bufferList[1].mDataByteSize) / MemoryLayout<Float>.stride
            let safeFrameCount = min(Int(frameCount), leftFrames, rightFrames)
            guard safeFrameCount > 0 else { return noErr }

            params.renderBlock(
                leftPtr: leftPtr,
                rightPtr: rightPtr,
                frameCount: safeFrameCount,
                sampleRate: Float(sampleRate)
            )

            return noErr
        }
    }
}

/// Shared parameter block. UI-side mutations are atomic per-field (single
/// Float read/write is atomic on Apple Silicon). The audio-thread render
/// block consumes the targets through one-pole IIR smoothers.
///
/// Marked `@unchecked Sendable` because we manage thread safety manually
/// per field — Swift's strict concurrency can't see through the atomic
/// guarantees provided by Apple Silicon's ARM64v8 spec.
private nonisolated final class LivePlayerParameters: @unchecked Sendable {
    private static let maxMixLayerCount = 64

    private var mixLayers: [AmbientFrequencyLayer] = []
    private var mixFrame: Int = 0
    private let layerVolumes: UnsafeMutableBufferPointer<Float>
    private let layerPans: UnsafeMutableBufferPointer<Float>
    private let layerDistortions: UnsafeMutableBufferPointer<Float>
    private let layerDelaySends: UnsafeMutableBufferPointer<Float>
    private let layerDelayTimes: UnsafeMutableBufferPointer<Float>
    private let layerDelayFeedbacks: UnsafeMutableBufferPointer<Float>
    private let layerSpaceSends: UnsafeMutableBufferPointer<Float>
    private let layerTones: UnsafeMutableBufferPointer<Float>
    private let layerTonePreviousLeft: UnsafeMutableBufferPointer<Float>
    private let layerTonePreviousRight: UnsafeMutableBufferPointer<Float>
    private var delayBufferLeft: [Float] = []
    private var delayBufferRight: [Float] = []
    private var delayBufferFrames = 1
    private var delayWriteFrame = 0

    // Target values written by UI; read by audio thread.
    var targetFrequency: Float = 440
    var targetPan: Float = 0
    var targetGain: Float = 0.3
    var waveform: Float = Float(AmbientFrequencyDSP.defaultWaveformRawValue)
    var muted: Float = 0
    /// Bit-depth crush, [1, 16]; 16 = no effect, lower = "pixel crunch."
    var bitCrushDepth: Float = 16
    /// Sample-rate reduction (zero-order hold), [1, 64]; 1 = no effect.
    var sampleRateHold: Float = 1

    // Smoothed values updated per-sample on audio thread; mirrored to UI
    // for visual feedback. UI-side reads are atomic Float; small tearing OK.
    var smoothedFrequencyForUI: Float = 440
    var smoothedPanForUI: Float = 0
    var smoothedGainForUI: Float = 0.3

    // Smoother state (audio-thread only).
    private var smoothedFrequency: Float = 440
    private var smoothedPan: Float = 0
    private var smoothedGain: Float = 0.3

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

    init() {
        layerVolumes = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerPans = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerDistortions = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerDelaySends = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerDelayTimes = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerDelayFeedbacks = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerSpaceSends = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerTones = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerTonePreviousLeft = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        layerTonePreviousRight = UnsafeMutableBufferPointer<Float>.allocate(capacity: Self.maxMixLayerCount)
        for index in 0..<Self.maxMixLayerCount {
            layerVolumes[index] = Float(AmbientFrequencyLayerMixControl.neutral.volume)
            layerPans[index] = Float(AmbientFrequencyLayerMixControl.neutral.pan)
            layerDistortions[index] = Float(AmbientFrequencyLayerMixControl.neutral.distortion)
            layerDelaySends[index] = Float(AmbientFrequencyLayerMixControl.neutral.delaySend)
            layerDelayTimes[index] = Float(AmbientFrequencyLayerMixControl.neutral.delayTimeSeconds)
            layerDelayFeedbacks[index] = Float(AmbientFrequencyLayerMixControl.neutral.delayFeedback)
            layerSpaceSends[index] = Float(AmbientFrequencyLayerMixControl.neutral.spaceSend)
            layerTones[index] = Float(AmbientFrequencyLayerMixControl.neutral.tone)
            layerTonePreviousLeft[index] = 0
            layerTonePreviousRight[index] = 0
        }
    }

    deinit {
        layerVolumes.deallocate()
        layerPans.deallocate()
        layerDistortions.deallocate()
        layerDelaySends.deallocate()
        layerDelayTimes.deallocate()
        layerDelayFeedbacks.deallocate()
        layerSpaceSends.deallocate()
        layerTones.deallocate()
        layerTonePreviousLeft.deallocate()
        layerTonePreviousRight.deallocate()
    }

    func configureMix(
        layers: [AmbientFrequencyLayer],
        controls: [AmbientFrequencyLayerMixControl]
    ) {
        mixLayers = Array(layers.prefix(Self.maxMixLayerCount))
        mixFrame = 0
        delayWriteFrame = 0
        resetEffectState()
        setLayerControls(controls)
    }

    func setLayerControls(_ controls: [AmbientFrequencyLayerMixControl]) {
        for index in 0..<Self.maxMixLayerCount {
            let control = index < controls.count ? controls[index].sanitized : .neutral
            layerVolumes[index] = Float(control.volume)
            layerPans[index] = Float(control.pan)
            layerDistortions[index] = Float(control.distortion)
            layerDelaySends[index] = Float(control.delaySend)
            layerDelayTimes[index] = Float(control.delayTimeSeconds)
            layerDelayFeedbacks[index] = Float(control.delayFeedback)
            layerSpaceSends[index] = Float(control.spaceSend)
            layerTones[index] = Float(control.tone)
        }
    }

    func setLayerControl(index: Int, control: AmbientFrequencyLayerMixControl) {
        guard index >= 0, index < Self.maxMixLayerCount else { return }
        let control = control.sanitized
        layerVolumes[index] = Float(control.volume)
        layerPans[index] = Float(control.pan)
        layerDistortions[index] = Float(control.distortion)
        layerDelaySends[index] = Float(control.delaySend)
        layerDelayTimes[index] = Float(control.delayTimeSeconds)
        layerDelayFeedbacks[index] = Float(control.delayFeedback)
        layerSpaceSends[index] = Float(control.spaceSend)
        layerTones[index] = Float(control.tone)
    }

    /// Precompute smoother coefficients for the given sample rate. Called
    /// once at engine start (and on sample-rate changes if the OS swaps
    /// audio routes).
    func precomputeSmootherCoefficients(sampleRate: Float) {
        guard sampleRate.isFinite, sampleRate > 0 else {
            gainPanAlpha = 0.999
            frequencyAlpha = 0.9998
            return
        }
        // α = exp(-1 / (timeConstantSeconds · sampleRate))
        let gainPanTimeConstant: Float = 0.020   // 20 ms — snappy
        let frequencyTimeConstant: Float = 0.080 // 80 ms — musical pitch glide
        gainPanAlpha = exp(-1.0 / (gainPanTimeConstant * sampleRate))
        frequencyAlpha = exp(-1.0 / (frequencyTimeConstant * sampleRate))
        configureEffectBuffers(sampleRate: sampleRate)
    }

    private func configureEffectBuffers(sampleRate: Float) {
        let frames = max(1, Int((Double(sampleRate) * 1.6).rounded()))
        let count = frames * Self.maxMixLayerCount
        guard count > 0 else { return }
        if delayBufferFrames != frames || delayBufferLeft.count != count || delayBufferRight.count != count {
            delayBufferFrames = frames
            delayBufferLeft = Array(repeating: 0, count: count)
            delayBufferRight = Array(repeating: 0, count: count)
            delayWriteFrame = 0
        } else {
            resetEffectState()
        }
    }

    private func resetEffectState() {
        if !delayBufferLeft.isEmpty {
            delayBufferLeft.withUnsafeMutableBufferPointer { buffer in
                for index in buffer.indices {
                    buffer[index] = 0
                }
            }
        }
        if !delayBufferRight.isEmpty {
            delayBufferRight.withUnsafeMutableBufferPointer { buffer in
                for index in buffer.indices {
                    buffer[index] = 0
                }
            }
        }
        for index in 0..<Self.maxMixLayerCount {
            layerTonePreviousLeft[index] = 0
            layerTonePreviousRight[index] = 0
        }
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
        let sampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        let sampleRateInt = max(1, Int(sampleRate.rounded()))
        let mutedFlag = muted >= 0.5

        for i in 0..<frameCount {
            let frequencyTarget = AmbientFrequencyDSP.sanitizedFrequency(
                targetFrequency,
                fallback: smoothedFrequency
            )
            let panTarget = AmbientFrequencyDSP.sanitizedPan(targetPan)
            let gainTarget = mutedFlag ? 0 : AmbientFrequencyDSP.sanitizedGain(targetGain)
            let waveformTarget = AmbientFrequencyDSP.sanitizedWaveform(waveform)
            let hold = AmbientFrequencyDSP.sanitizedSampleRateHold(sampleRateHold)
            let bits = AmbientFrequencyDSP.sanitizedBitCrushDepth(bitCrushDepth)

            // 1) Smooth params (one-pole IIR per sample).
            smoothedFrequency = frequencyAlpha * smoothedFrequency + (1 - frequencyAlpha) * frequencyTarget
            smoothedPan = gainPanAlpha * smoothedPan + (1 - gainPanAlpha) * panTarget
            smoothedGain = gainPanAlpha * smoothedGain + (1 - gainPanAlpha) * gainTarget

            var leftSample: Float
            var rightSample: Float

            if mixLayers.isEmpty {
                let sample = oscillatorSample(
                    waveform: waveformTarget,
                    hold: hold,
                    bits: bits,
                    twoPi: twoPi,
                    sampleRate: sampleRate
                )
                leftSample = sample
                rightSample = sample
            } else {
                let sample = mixSample(frame: mixFrame, sampleRate: sampleRateInt)
                mixFrame &+= 1
                leftSample = sample.left
                rightSample = sample.right
            }

            leftSample *= smoothedGain
            rightSample *= smoothedGain

            // Apply equal-power master pan (W3C spec).
            let panX = (smoothedPan + 1) * 0.5
            let leftGain = cos(panX * halfPi)
            let rightGain = sin(panX * halfPi)

            leftPtr[i] = leftSample * leftGain
            rightPtr[i] = rightSample * rightGain
        }

        // Mirror final smoothed values to UI-readable fields (atomic Float
        // writes; small tearing absorbed by SwiftUI poll cadence).
        smoothedFrequencyForUI = smoothedFrequency
        smoothedPanForUI = smoothedPan
        smoothedGainForUI = smoothedGain
    }

    @inline(__always)
    private func oscillatorSample(
        waveform: Int,
        hold: Int,
        bits: Int,
        twoPi: Double,
        sampleRate: Float
    ) -> Float {
        // Advance phase accumulator. Phase is double-precision to avoid drift
        // over long renders.
        phase += Double(smoothedFrequency) / Double(sampleRate)
        phase -= floor(phase)

        let sample: Float
        switch waveform {
        case 0:
            sample = Float(sin(phase * twoPi))
        case 1:
            sample = Float((2.0 / .pi) * asin(sin(phase * twoPi)))
        case 2:
            sample = Float(2.0 * phase - 1.0)
        case 3:
            sample = phase < 0.5 ? 1 : -1
        case 4:
            var s = noiseState
            s ^= s << 13
            s ^= s >> 7
            s ^= s << 17
            noiseState = s
            let mantissa = s >> 40
            sample = (Float(mantissa) / Float(UInt32(1) << 23)) - 1.0
        default:
            sample = 0
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

        if bits < 16 {
            let levels = Float(1 << (bits - 1))
            crunched = (crunched * levels).rounded() / levels
        }

        return crunched
    }

    @inline(__always)
    private func mixSample(frame: Int, sampleRate: Int) -> (left: Float, right: Float) {
        let time = Double(frame) / Double(sampleRate)
        var left: Float = 0
        var right: Float = 0

        for index in 0..<mixLayers.count {
            let volume = AmbientFrequencyDSP.sanitizedLayerVolume(layerVolumes[index])
            let pan = AmbientFrequencyDSP.sanitizedPan(layerPans[index])
            let distortion = AmbientFrequencyDSP.sanitizedDistortion(layerDistortions[index])
            let delaySend = AmbientFrequencyDSP.sanitizedDistortion(layerDelaySends[index])
            let delayTimeSeconds = min(max(layerDelayTimes[index].isFinite ? layerDelayTimes[index] : 0.32, 0.05), 1.5)
            let delayFeedback = min(max(layerDelayFeedbacks[index].isFinite ? layerDelayFeedbacks[index] : 0.28, 0), 0.85)
            let spaceSend = AmbientFrequencyDSP.sanitizedDistortion(layerSpaceSends[index])
            let tone = min(max(layerTones[index].isFinite ? layerTones[index] : 0, -1), 1)
            let mixed = renderLayerSample(
                index: index,
                layer: mixLayers[index],
                volume: volume,
                pan: pan,
                distortion: distortion,
                delaySend: delaySend,
                delayTimeSeconds: delayTimeSeconds,
                delayFeedback: delayFeedback,
                spaceSend: spaceSend,
                tone: tone,
                time: time,
                frame: frame,
                sampleRate: sampleRate
            )
            left += Float(mixed.left)
            right += Float(mixed.right)
        }

        if !mixLayers.isEmpty, delayBufferFrames > 1 {
            delayWriteFrame += 1
            if delayWriteFrame >= delayBufferFrames {
                delayWriteFrame = 0
            }
        }

        return (left, right)
    }

    private func renderLayerSample(
        index: Int,
        layer: AmbientFrequencyLayer,
        volume: Float,
        pan: Float,
        distortion: Float,
        delaySend: Float,
        delayTimeSeconds: Float,
        delayFeedback: Float,
        spaceSend: Float,
        tone: Float,
        time: Double,
        frame: Int,
        sampleRate: Int
    ) -> (left: Double, right: Double) {
        let raw = AmbientFrequencyAudioGenerator.layerSample(
            layer,
            time: time,
            frame: frame,
            sampleRate: sampleRate
        )
        let toned = applyLiveTone(index: index, raw: raw, amount: Double(tone))
        let dry = applyLiveLayerMix(
            toned,
            volume: volume,
            pan: pan,
            distortion: distortion
        )
        var left = dry.left
        var right = dry.right

        if delayBufferFrames > 1, !delayBufferLeft.isEmpty, !delayBufferRight.isEmpty {
            let base = index * delayBufferFrames
            var feedbackLeft: Float = 0
            var feedbackRight: Float = 0

            if delaySend > 0 {
                let delayFrames = max(1, Int((Double(delayTimeSeconds) * Double(sampleRate)).rounded()))
                let delayed = readDelaySample(base: base, delayFrames: delayFrames)
                left += Double(delayed.left * delaySend)
                right += Double(delayed.right * delaySend)
                feedbackLeft = delayed.left * delayFeedback
                feedbackRight = delayed.right * delayFeedback
            }

            if spaceSend > 0 {
                addSpaceTap(base: base, sampleRate: sampleRate, seconds: 0.029, gain: 0.42, send: spaceSend, left: &left, right: &right)
                addSpaceTap(base: base, sampleRate: sampleRate, seconds: 0.043, gain: 0.31, send: spaceSend, left: &left, right: &right)
                addSpaceTap(base: base, sampleRate: sampleRate, seconds: 0.071, gain: 0.23, send: spaceSend, left: &left, right: &right)
                addSpaceTap(base: base, sampleRate: sampleRate, seconds: 0.113, gain: 0.16, send: spaceSend, left: &left, right: &right)
            }

            let writeIndex = base + delayWriteFrame
            delayBufferLeft[writeIndex] = clampLiveSample(Float(dry.left) + feedbackLeft)
            delayBufferRight[writeIndex] = clampLiveSample(Float(dry.right) + feedbackRight)
        }

        return (left, right)
    }

    @inline(__always)
    private func applyLiveLayerMix(
        _ leftRight: (left: Double, right: Double),
        volume: Float,
        pan: Float,
        distortion: Float
    ) -> (left: Double, right: Double) {
        let left = liveDistort(leftRight.left * Double(volume), amount: distortion)
        let right = liveDistort(leftRight.right * Double(volume), amount: distortion)
        return AmbientFrequencyAudioGenerator.applyEqualPowerPan(
            (left: left, right: right),
            pan: Double(pan)
        )
    }

    @inline(__always)
    private func liveDistort(_ sample: Double, amount: Float) -> Double {
        guard amount > 0 else { return sample }
        let wet = liveSoftClip(sample * Double(1 + amount * 18))
        return sample * Double(1 - amount) + wet * Double(amount)
    }

    @inline(__always)
    private func liveSoftClip(_ sample: Double) -> Double {
        if sample >= 1 { return 1 }
        if sample <= -1 { return -1 }
        return 1.5 * sample - 0.5 * sample * sample * sample
    }

    @inline(__always)
    private func addSpaceTap(
        base: Int,
        sampleRate: Int,
        seconds: Double,
        gain: Float,
        send: Float,
        left: inout Double,
        right: inout Double
    ) {
        let tapFrames = max(1, Int((seconds * Double(sampleRate)).rounded()))
        let sample = readDelaySample(base: base, delayFrames: tapFrames)
        let tapGain = send * gain
        left += Double(sample.left * tapGain)
        right += Double(sample.right * tapGain)
    }

    private func readDelaySample(base: Int, delayFrames: Int) -> (left: Float, right: Float) {
        let offset = min(max(delayFrames, 1), delayBufferFrames - 1)
        let readFrame = (delayWriteFrame - offset + delayBufferFrames) % delayBufferFrames
        let index = base + readFrame
        guard index >= 0, index < delayBufferLeft.count, index < delayBufferRight.count else {
            return (0, 0)
        }
        return (delayBufferLeft[index], delayBufferRight[index])
    }

    private func applyLiveTone(
        index: Int,
        raw: (left: Double, right: Double),
        amount: Double
    ) -> (left: Double, right: Double) {
        let amount = min(max(amount.isFinite ? amount : 0, -1), 1)
        guard abs(amount) > 0.001 else {
            layerTonePreviousLeft[index] = Float(raw.left)
            layerTonePreviousRight[index] = Float(raw.right)
            return raw
        }

        let previousLeft = Double(layerTonePreviousLeft[index])
        let previousRight = Double(layerTonePreviousRight[index])
        layerTonePreviousLeft[index] = Float(raw.left)
        layerTonePreviousRight[index] = Float(raw.right)
        return (
            liveToneSample(raw.left, previous: previousLeft, amount: amount),
            liveToneSample(raw.right, previous: previousRight, amount: amount)
        )
    }

    private func liveToneSample(_ sample: Double, previous: Double, amount: Double) -> Double {
        if amount < 0 {
            let warm = (sample + previous) * 0.5
            return sample * (1 + amount) + warm * -amount
        }
        let bright = sample + (sample - previous) * 0.65
        return sample * (1 - amount) + Double(clampLiveSample(Float(bright))) * amount
    }

    private func clampLiveSample(_ sample: Float) -> Float {
        if sample > 1 { return 1 }
        if sample < -1 { return -1 }
        return sample
    }
}

enum AmbientFrequencyLivePlayerError: Error, LocalizedError {
    case invalidOutputFormat
    case couldNotCreateRenderFormat
    case engineStartFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidOutputFormat:
            return "Could not start live playback because the current audio output format has no valid sample rate."
        case .couldNotCreateRenderFormat:
            return "Could not create AVAudioFormat for live playback (stereo 32-bit float)."
        case .engineStartFailed(let underlying):
            return "Could not start live playback: \(underlying.localizedDescription)"
        }
    }
}
