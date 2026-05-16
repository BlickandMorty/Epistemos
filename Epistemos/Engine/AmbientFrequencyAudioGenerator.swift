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

    nonisolated static let allPresets: [AmbientFrequencyPreset] = [
        .schumannCocktail,
        .deltaRest,
        .thetaDrift,
        .alphaFocus,
        .betaClarity,
        .gammaSpark,
    ]

    nonisolated static func preset(id: String) -> AmbientFrequencyPreset {
        allPresets.first { $0.id == id } ?? .schumannCocktail
    }
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
