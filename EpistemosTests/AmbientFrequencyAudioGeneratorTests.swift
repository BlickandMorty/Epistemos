import Foundation
import Testing
@testable import Epistemos

@Suite("Ambient Frequency Audio Generator")
struct AmbientFrequencyAudioGeneratorTests {
    @Test("Schumann cocktail preserves the requested exact component frequencies")
    func schumannCocktailPreservesRequestedFrequencies() {
        let preset = AmbientFrequencyPreset.schumannCocktail
        let descriptions = preset.layers.map(\.description).joined(separator: "\n")

        #expect(descriptions.contains("7.83 Hz"))
        #expect(descriptions.contains("100 Hz"))
        #expect(descriptions.contains("528 Hz"))
        #expect(descriptions.contains("432 Hz"))
        #expect(descriptions.contains("17000 Hz"))
        #expect(descriptions.contains("2500 Hz"))
    }

    @Test("Chirp triggers exactly every 10 seconds within the render duration")
    func chirpTriggersEveryTenSeconds() throws {
        let chirp = try #require(AmbientFrequencyPreset.schumannCocktail.layers.first { layer in
            if case .chirp = layer {
                return true
            }
            return false
        })

        let starts = AmbientFrequencyAudioGenerator.eventStarts(
            for: chirp,
            durationSeconds: 30
        )

        #expect(starts == [0, 10, 20])
    }

    @Test("Export writes stereo 44.1 kHz 32-bit float WAV with exact frame count")
    func exportWritesFloatWavHeaderAndFrameCount() throws {
        let outputURL = temporaryOutputURL()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let report = try AmbientFrequencyAudioGenerator.export(
            AmbientFrequencyExportRequest(
                preset: .schumannCocktail,
                durationSeconds: 0.25,
                sampleRate: 44_100,
                outputURL: outputURL,
                chunkFrames: 512
            )
        )

        let data = try Data(contentsOf: outputURL)
        #expect(String(data: data[0..<4], encoding: .ascii) == "RIFF")
        #expect(String(data: data[8..<12], encoding: .ascii) == "WAVE")
        #expect(littleEndianUInt16(data, offset: 20) == 3)
        #expect(littleEndianUInt16(data, offset: 22) == 2)
        #expect(littleEndianUInt32(data, offset: 24) == 44_100)
        #expect(littleEndianUInt16(data, offset: 34) == 32)
        #expect(report.framesWritten == 11_025)
        #expect(littleEndianUInt32(data, offset: 40) == UInt32(report.framesWritten * 2 * 4))
    }

    @Test("Export normalization keeps samples within floating point full scale")
    func exportNormalizationKeepsSamplesWithinFullScale() throws {
        let outputURL = temporaryOutputURL()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let report = try AmbientFrequencyAudioGenerator.export(
            AmbientFrequencyExportRequest(
                preset: .schumannCocktail,
                durationSeconds: 0.5,
                sampleRate: 44_100,
                outputURL: outputURL,
                chunkFrames: 1_024
            )
        )

        let data = try Data(contentsOf: outputURL)
        let sampleBytes = data.dropFirst(44)
        var maxSample: Float = 0
        var offset = sampleBytes.startIndex
        while offset + 4 <= sampleBytes.endIndex {
            let bits = UInt32(sampleBytes[offset])
                | UInt32(sampleBytes[offset + 1]) << 8
                | UInt32(sampleBytes[offset + 2]) << 16
                | UInt32(sampleBytes[offset + 3]) << 24
            let sample = Float(bitPattern: bits)
            #expect(sample.isFinite)
            maxSample = max(maxSample, abs(sample))
            offset += 4
        }

        #expect(report.peakBeforeNormalization > 0)
        #expect(report.peakAfterNormalization <= AmbientFrequencyAudioGenerator.targetPeak + 0.0001)
        #expect(maxSample <= Float(AmbientFrequencyAudioGenerator.targetPeak + 0.0001))
    }

    @Test("Settings exposes Ambient Frequencies as a reachable pane")
    @MainActor
    func settingsExposeAmbientFrequenciesPane() throws {
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let detailSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AmbientFrequencySettingsView.swift")

        #expect(SettingsView.SettingsSection.visibleSections.contains(.ambientFrequencies))
        #expect(SettingsView.SettingsSection.ambientFrequencies.category == .capture)
        #expect(settingsSource.contains("AmbientFrequencySettingsView()"))
        #expect(detailSource.contains("Frequencies & Sounds"))
        #expect(detailSource.contains("Preset / Vibe"))
        #expect(detailSource.contains("Playback & Export"))
        #expect(detailSource.contains("32-bit float WAV"))
        #expect(detailSource.contains("AmbientFrequencyExportDiagnostics.statusMessage(for: error)"))
        #expect(detailSource.contains("String(message.prefix(maxStatusMessageCharacters + 32))"))
        #expect(detailSource.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(detailSource.contains("maxStatusMessageCharacters - 3"))
        #expect(!detailSource.contains("exportStatus = error.localizedDescription"))
    }

    @Test("Export diagnostics redact external and output paths")
    func exportDiagnosticsRedactExternalAndOutputPaths() {
        let privatePath = "/Users/example/Private Vault/export.wav"
        let external = NSError(
            domain: privatePath,
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "write failed at \(privatePath)"]
        )
        let externalStatus = AmbientFrequencyExportDiagnostics.statusMessage(for: external)

        #expect(externalStatus.contains("Ambient export failed."))
        #expect(externalStatus.contains("domain=Error"))
        #expect(externalStatus.contains("code=7"))
        #expect(externalStatus.count <= AmbientFrequencyExportDiagnostics.maxStatusMessageCharacters)
        #expect(!externalStatus.contains(privatePath))
        #expect(!externalStatus.contains("write failed"))

        let oversizedStatus = AmbientFrequencyExportDiagnostics.statusMessage(
            String(repeating: "a", count: AmbientFrequencyExportDiagnostics.maxStatusMessageCharacters + 40)
        )
        #expect(oversizedStatus.count == AmbientFrequencyExportDiagnostics.maxStatusMessageCharacters)

        let outputStatus = AmbientFrequencyExportDiagnostics.statusMessage(
            for: AmbientFrequencyAudioGeneratorError.couldNotCreateOutput(URL(fileURLWithPath: privatePath))
        )
        #expect(outputStatus.contains("export.wav"))
        #expect(!outputStatus.contains(privatePath))
    }

    @Test("Live player sanitizes realtime parameters before modulo and bit shifting")
    func livePlayerSanitizesRealtimeParameters() {
        #expect(AmbientFrequencyLivePlayer.sanitizedSampleRateHold(.nan) == 1)
        #expect(AmbientFrequencyLivePlayer.sanitizedSampleRateHold(0) == 1)
        #expect(AmbientFrequencyLivePlayer.sanitizedSampleRateHold(-8) == 1)
        #expect(AmbientFrequencyLivePlayer.sanitizedSampleRateHold(128) == 64)
        #expect(AmbientFrequencyLivePlayer.sanitizedSampleRateHold(.greatestFiniteMagnitude) == 64)

        #expect(AmbientFrequencyLivePlayer.sanitizedBitCrushDepth(.nan) == 16)
        #expect(AmbientFrequencyLivePlayer.sanitizedBitCrushDepth(0) == 1)
        #expect(AmbientFrequencyLivePlayer.sanitizedBitCrushDepth(40) == 16)
        #expect(AmbientFrequencyLivePlayer.sanitizedBitCrushDepth(.greatestFiniteMagnitude) == 16)

        #expect(AmbientFrequencyLivePlayer.sanitizedWaveform(.nan) == AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue)
        #expect(AmbientFrequencyLivePlayer.sanitizedWaveform(-1) == AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue)
        #expect(AmbientFrequencyLivePlayer.sanitizedWaveform(99) == AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue)
    }

    @Test("Live player can create a stereo fallback render format")
    func livePlayerCreatesStereoFallbackRenderFormat() throws {
        let format = try AmbientFrequencyLivePlayer.makeStereoRenderFormat(
            preferredSampleRate: .nan,
            fallbackSampleRates: [0, .infinity, 48_000, 44_100]
        )

        #expect(format.sampleRate == 48_000)
        #expect(format.channelCount == 2)
        #expect(format.commonFormat == .pcmFormatFloat32)
        #expect(!format.isInterleaved)
    }

    @Test("Live player render callback is built outside MainActor isolation")
    func livePlayerRenderCallbackIsBuiltOutsideMainActorIsolation() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/AmbientFrequencyLivePlayer.swift")

        #expect(source.contains("nonisolated private enum AmbientFrequencyDSP"))
        #expect(source.contains("nonisolated private enum AmbientFrequencyRenderCallback"))
        #expect(source.contains("private nonisolated final class LivePlayerParameters"))
        #expect(source.contains("let node = AmbientFrequencyRenderCallback.makeSourceNode("))
        #expect(!source.contains("let node = AVAudioSourceNode(format: renderFormat) {"))
        #expect(!source.contains("AmbientFrequencyLivePlayer.sanitizedFrequency(\n                targetFrequency"))
        #expect(source.contains("throw AmbientFrequencyLivePlayerError.engineStartFailed(underlying: error)"))
    }

    @Test("Live player engine start failures keep a useful user-facing message")
    func livePlayerEngineStartFailuresKeepAUsefulMessage() throws {
        let underlying = NSError(
            domain: "AudioUnit",
            code: -10875,
            userInfo: [NSLocalizedDescriptionKey: "output device unavailable"]
        )

        let message = try #require(
            AmbientFrequencyLivePlayerError.engineStartFailed(underlying: underlying).errorDescription
        )

        #expect(message.contains("Could not start live playback"))
        #expect(message.contains("output device unavailable"))
    }

    @Test("Live player persists outside Ambient Frequency settings")
    func livePlayerPersistsOutsideAmbientFrequencySettings() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AmbientFrequencySettingsView.swift")
        let environment = try loadMirroredSourceTextFile("Epistemos/App/AppEnvironment.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(source.contains("@Environment(AmbientFrequencyPlaybackState.self)"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains(".onDisappear {\n            liveRestartTask?.cancel()\n        }"))
        #expect(!source.contains("livePlayer.stop()"))
        #expect(source.contains("AmbientFrequencyPlaybackRequest"))
        #expect(environment.contains(".environment(bootstrap.ambientFrequencyPlaybackState)"))
        #expect(bootstrap.contains("let ambientFrequencyPlaybackState = AmbientFrequencyPlaybackState()"))
        #expect(landing.contains("@Environment(AmbientFrequencyPlaybackState.self)"))
        #expect(landing.contains("landingAmbientFrequencyMediaChip"))
    }

    private func temporaryOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ambient-frequency-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }

    // MARK: - Iter 86: noise-color completeness + sound-module composition

    @Test("All six noise colors are registered as modules (white/pink/grey/blue/violet/brown)")
    func allSixNoiseColorsRegistered() {
        let colorIds = AmbientFrequencySoundModule.modules(in: .noiseColor).map(\.id)
        #expect(colorIds.contains("color-white"))
        #expect(colorIds.contains("color-pink"))
        #expect(colorIds.contains("color-grey"))
        #expect(colorIds.contains("color-blue"))
        #expect(colorIds.contains("color-violet"))
        #expect(colorIds.contains("color-brown"))
    }

    @Test("Composing a base preset with zero modules returns the base unchanged in layer count")
    func composedZeroModulesEqualsBase() {
        let base = AmbientFrequencyPreset.schumannCocktail
        let composed = AmbientFrequencyPreset.composed(base: base, modules: [])
        #expect(composed.layers.count == base.layers.count)
        #expect(composed.id == base.id)
    }

    @Test("Composing a base preset with 3 modules adds their layers")
    func composedWithModulesStacksLayers() {
        let base = AmbientFrequencyPreset.focusBrainSync
        let modules: [AmbientFrequencySoundModule] = [
            .birdsChirping,
            .gentleRain,
            .cathedralPad,
        ]
        let composed = AmbientFrequencyPreset.composed(base: base, modules: modules)
        let expectedLayerCount = base.layers.count + modules.reduce(0) { $0 + $1.layers.count }
        #expect(composed.layers.count == expectedLayerCount)
        #expect(composed.title.contains("custom mix"))
        // The composed id must thread every module id
        #expect(composed.id.contains("nature-birds-chirping"))
        #expect(composed.id.contains("nature-gentle-rain"))
        #expect(composed.id.contains("drone-cathedral-pad"))
    }

    @Test("Module registry covers all six categories with at least one module each")
    func everyModuleCategoryNonEmpty() {
        for category in AmbientFrequencySoundModuleCategory.allCases {
            let modules = AmbientFrequencySoundModule.modules(in: category)
            #expect(!modules.isEmpty, "Category \(category.rawValue) must have at least 1 module")
        }
    }

    // MARK: - Iter 87: equal-power pan (W3C spec) + indirect .panned wrapper

    @Test("Equal-power pan at center yields equal -3 dB gains for L and R")
    func equalPowerPanCenterIsMinus3dB() {
        let panned = AmbientFrequencyAudioGenerator.applyEqualPowerPan((left: 1.0, right: 1.0), pan: 0)
        // cos(π/4) = sin(π/4) = √2/2 ≈ 0.70710678
        let expected = sqrt(2.0) / 2.0
        #expect(abs(panned.left - expected) < 1e-9, "Center pan should give √½ left gain")
        #expect(abs(panned.right - expected) < 1e-9, "Center pan should give √½ right gain")
        // Constant-power invariant: leftGain² + rightGain² = 1
        let constantPower = panned.left * panned.left + panned.right * panned.right
        #expect(abs(constantPower - 1.0) < 1e-9, "Constant-power invariant should hold")
    }

    @Test("Equal-power pan at -1 routes all energy to left channel")
    func equalPowerPanFullLeftRoutesAllToLeft() {
        let panned = AmbientFrequencyAudioGenerator.applyEqualPowerPan((left: 1.0, right: 1.0), pan: -1)
        #expect(abs(panned.left - 1.0) < 1e-9, "Full-left pan should leave left at full")
        #expect(abs(panned.right) < 1e-9, "Full-left pan should silence right")
    }

    @Test("Equal-power pan at +1 routes all energy to right channel")
    func equalPowerPanFullRightRoutesAllToRight() {
        let panned = AmbientFrequencyAudioGenerator.applyEqualPowerPan((left: 1.0, right: 1.0), pan: 1)
        #expect(abs(panned.left) < 1e-9, "Full-right pan should silence left")
        #expect(abs(panned.right - 1.0) < 1e-9, "Full-right pan should leave right at full")
    }

    @Test("Per-layer mixer volume can silence a rendered sound")
    func perLayerMixerVolumeCanSilenceRenderedSound() {
        let preset = AmbientFrequencyPreset(
            id: "test-one-sine",
            title: "Test One Sine",
            intent: "Test",
            summary: "Test",
            requiresHeadphones: false,
            defaultDurationSeconds: 1,
            layers: [.sine(frequencyHz: 100, amplitude: 1, channelMode: .stereo)]
        )

        let audible = AmbientFrequencyAudioGenerator.samplePair(
            preset: preset,
            frame: 3,
            totalFrames: 1_000,
            sampleRate: 1_000
        )
        let muted = AmbientFrequencyAudioGenerator.samplePair(
            preset: preset,
            frame: 3,
            totalFrames: 1_000,
            sampleRate: 1_000,
            layerControls: [AmbientFrequencyLayerMixControl(volume: 0, pan: 0, distortion: 0)]
        )

        #expect(abs(audible.left) > 0.01)
        #expect(abs(muted.left) < 1e-9)
        #expect(abs(muted.right) < 1e-9)
    }

    @Test("Per-layer mixer pan and distortion stay bounded")
    func perLayerMixerPanAndDistortionStayBounded() {
        let hardRight = AmbientFrequencyAudioGenerator.applyLayerMix(
            (left: 1, right: 1),
            control: AmbientFrequencyLayerMixControl(volume: 1, pan: 1, distortion: 0)
        )
        #expect(abs(hardRight.left) < 1e-9)
        #expect(abs(hardRight.right - 1) < 1e-9)

        let driven = AmbientFrequencyAudioGenerator.applyLayerMix(
            (left: 0.95, right: 0.95),
            control: AmbientFrequencyLayerMixControl(volume: 2, pan: 0, distortion: 1)
        )
        #expect(abs(driven.left) <= 1)
        #expect(abs(driven.right) <= 1)
    }

    @Test("Per-layer mixer delay and space controls add bounded ambience")
    func perLayerMixerDelayAndSpaceAddAmbience() {
        let layer: AmbientFrequencyLayer = .pwmSquare(
            frequencyHz: 1,
            dutyCycle: 0.5,
            amplitude: 1,
            channelMode: .stereo
        )
        let dry = AmbientFrequencyAudioGenerator.mixedLayerSample(
            layer,
            control: AmbientFrequencyLayerMixControl(volume: 1, pan: 0, distortion: 0),
            time: 0.05,
            frame: 50,
            sampleRate: 1_000
        )
        let wet = AmbientFrequencyAudioGenerator.mixedLayerSample(
            layer,
            control: AmbientFrequencyLayerMixControl(
                volume: 1,
                pan: 0,
                distortion: 0,
                delaySend: 0.5,
                delayTimeSeconds: 0.05,
                delayFeedback: 0.35,
                spaceSend: 0.25,
                tone: 0
            ),
            time: 0.05,
            frame: 50,
            sampleRate: 1_000
        )

        #expect(abs(wet.left) > abs(dry.left))
        #expect(abs(wet.right) > abs(dry.right))
        #expect(wet.left.isFinite)
        #expect(wet.right.isFinite)
    }

    @Test("Nature bandpass noise is smooth filtered noise, not metallic sine stacks")
    func natureBandpassNoiseUsesSmoothFilteredNoise() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/AmbientFrequencyAudioGenerator.swift")

        #expect(source.contains("smoothBandpassNoiseValue"))
        #expect(source.contains("smoothNoiseValue"))
        #expect(!source.contains("for k in 0..<harmonicCount"))
        #expect(!source.contains("sum += sin(.tau * frequencyHz * time + phase)"))
    }

    @Test("Live player renders FX with stateful delay buffers")
    func livePlayerRendersFXWithStatefulDelayBuffers() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/AmbientFrequencyLivePlayer.swift")

        #expect(source.contains("delayBufferLeft"))
        #expect(source.contains("renderLayerSample"))
        #expect(source.contains("readDelaySample"))
        #expect(!source.contains("AmbientFrequencyAudioGenerator.mixedLayerSample("))
    }

    @Test("Live active mix render path avoids per-sample allocation shapes")
    func liveActiveMixRenderPathAvoidsPerSampleAllocationShapes() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/AmbientFrequencyLivePlayer.swift")

        #expect(!source.contains("let taps: [(seconds: Double, gain: Double)]"))
        #expect(!source.contains("let control = AmbientFrequencyLayerMixControl("))
        #expect(source.contains("addSpaceTap("))
    }

    @Test("Per-layer mixer decodes old control JSON with neutral FX defaults")
    func perLayerMixerDecodesOldControlJSONWithNeutralFXDefaults() throws {
        let data = try #require(#"{"volume":0.4,"pan":-0.25,"distortion":0.2}"#.data(using: .utf8))
        let control = try JSONDecoder().decode(AmbientFrequencyLayerMixControl.self, from: data)

        #expect(control.volume == 0.4)
        #expect(control.pan == -0.25)
        #expect(control.distortion == 0.2)
        #expect(control.delaySend == AmbientFrequencyLayerMixControl.neutral.delaySend)
        #expect(control.delayTimeSeconds == AmbientFrequencyLayerMixControl.neutral.delayTimeSeconds)
        #expect(control.delayFeedback == AmbientFrequencyLayerMixControl.neutral.delayFeedback)
        #expect(control.spaceSend == AmbientFrequencyLayerMixControl.neutral.spaceSend)
        #expect(control.tone == AmbientFrequencyLayerMixControl.neutral.tone)
    }

    @Test("Indirect .panned layer wraps another layer + preserves its maxFrequencyHz")
    func indirectPannedLayerWraps() {
        let wrapped: AmbientFrequencyLayer = .sine(frequencyHz: 432, amplitude: 0.1, channelMode: .stereo)
        let panned: AmbientFrequencyLayer = .panned(layer: wrapped, pan: -0.5)
        // The panned wrapper inherits the wrapped layer's max frequency
        #expect(panned.maxFrequencyHz == wrapped.maxFrequencyHz)
        // Label includes both the wrapped layer's label and the pan position
        #expect(panned.label.contains("432 Hz sine"))
        #expect(panned.label.contains("L50%"))
    }

    // MARK: - Iter 88: pixel crunch — bit-crush + OPL2 + retro presets

    @Test("Bit-crush at 1 bit reduces sample to ±1 (sign only)")
    func bitCrushOneBitProducesSignOnly() {
        // bitDepth=1 → 1 << 0 = 1 level. Round(s*1) maps any sample to
        // {-1, 0, +1}; with midrise quantization, 0.5 rounds up to +1 and
        // -0.5 rounds toward -1.
        let pos = AmbientFrequencyAudioGenerator.bitCrush(0.7, bitDepth: 1)
        let neg = AmbientFrequencyAudioGenerator.bitCrush(-0.7, bitDepth: 1)
        let zero = AmbientFrequencyAudioGenerator.bitCrush(0.0, bitDepth: 1)
        #expect(abs(pos - 1.0) < 1e-9, "0.7 at 1-bit should crush to +1")
        #expect(abs(neg - (-1.0)) < 1e-9, "-0.7 at 1-bit should crush to -1")
        #expect(abs(zero) < 1e-9, "0 at 1-bit should crush to 0")
    }

    @Test("Bit-crush at 8 bits has 128-step quantization grid")
    func bitCrushEightBitGrid() {
        // bitDepth=8 → 128 levels. Quantization step = 1/128 ≈ 0.0078125
        // Any sample should land on a multiple of 1/128.
        let crushed = AmbientFrequencyAudioGenerator.bitCrush(0.1234, bitDepth: 8)
        let multiple = crushed * 128
        let rounded = multiple.rounded()
        #expect(abs(multiple - rounded) < 1e-9, "8-bit crush should produce 1/128 grid steps")
    }

    @Test("Bit-crush at 16 bits is effectively pass-through within float precision")
    func bitCrushSixteenBitNearIdentity() {
        let original = 0.4321
        let crushed = AmbientFrequencyAudioGenerator.bitCrush(original, bitDepth: 16)
        // 16-bit grid step is 1/32768 ≈ 3e-5; well within audible identity.
        #expect(abs(crushed - original) < 1e-4)
    }

    @Test("OPL2 waveforms 0-3 produce expected geometric shapes at sample phases")
    func opl2WaveformShapes() {
        // waveform 0 = full sine. sin(0)=0, sin(π/2)=1, sin(π)≈0, sin(3π/2)=-1.
        #expect(abs(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.25, waveform: 0) - 1.0) < 1e-9)
        #expect(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.75, waveform: 0) < -0.99)

        // waveform 1 = half sine — negative half clamps to 0.
        #expect(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.75, waveform: 1) == 0)
        #expect(abs(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.25, waveform: 1) - 1.0) < 1e-9)

        // waveform 2 = full-wave rectified — abs of sine, always ≥ 0.
        #expect(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.75, waveform: 2) > 0.99)

        // waveform 3 = quarter sine — only first quarter [0, 0.5] active.
        #expect(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.6, waveform: 3) == 0)
        #expect(abs(AmbientFrequencyAudioGenerator.opl2Waveform(phase: 0.25, waveform: 3) - 1.0) < 1e-9)
    }

    @Test("Indirect .bitCrushed layer preserves wrapped layer's maxFrequencyHz")
    func bitCrushedLayerPreservesMaxFrequency() {
        let wrapped: AmbientFrequencyLayer = .sine(frequencyHz: 880, amplitude: 0.1, channelMode: .stereo)
        let crushed: AmbientFrequencyLayer = .bitCrushed(layer: wrapped, bitDepth: 8)
        #expect(crushed.maxFrequencyHz == 880)
        #expect(crushed.label.contains("880 Hz sine"))
        #expect(crushed.label.contains("8-bit crush"))
    }

    @Test("All 8 pixel-era presets are registered in allPresets")
    func allEightPixelEraPresetsRegistered() {
        let presetIds = AmbientFrequencyPreset.allPresets.map(\.id)
        #expect(presetIds.contains("pixel-atari-2600"))
        #expect(presetIds.contains("pixel-nes-classic"))
        #expect(presetIds.contains("pixel-c64-loader"))
        #expect(presetIds.contains("pixel-gameboy-dmg"))
        #expect(presetIds.contains("pixel-amiga-mod"))
        #expect(presetIds.contains("pixel-adlib-opl2"))
        #expect(presetIds.contains("pixel-pc-speaker"))
        #expect(presetIds.contains("pixel-genesis-ym2612"))
    }

    @Test("Pan format helper covers center, left, right")
    func formatPanCoversAllPositions() {
        #expect(AmbientFrequencyLayer.formatPan(0) == "C")
        #expect(AmbientFrequencyLayer.formatPan(0.01) == "C")  // within center tolerance
        #expect(AmbientFrequencyLayer.formatPan(-0.5) == "L50%")
        #expect(AmbientFrequencyLayer.formatPan(0.71) == "R71%")
        #expect(AmbientFrequencyLayer.formatPan(-1.0) == "L100%")
        #expect(AmbientFrequencyLayer.formatPan(1.0) == "R100%")
    }

    @Test("Module lookup by id is consistent with allModules registry")
    func moduleLookupByIdRoundTrip() throws {
        let birds = try #require(AmbientFrequencySoundModule.module(id: "nature-birds-chirping"))
        #expect(birds.category == .nature)
        let pink = try #require(AmbientFrequencySoundModule.module(id: "color-pink"))
        #expect(pink.category == .noiseColor)
        #expect(AmbientFrequencySoundModule.module(id: "totally-nonexistent") == nil)
    }

    @Test("Retro music layer renders a bounded audible pattern")
    func retroMusicLayerRendersBoundedAudiblePattern() {
        let layer: AmbientFrequencyLayer = .retroMusic(
            rootMidiNote: 60,
            scale: .minorPentatonic,
            chord: .minor7,
            pattern: .chipSong,
            instrument: .pulse25,
            tempoBPM: 120,
            amplitude: 0.18
        )

        var peak = 0.0
        for frame in 0..<4_000 {
            let pair = AmbientFrequencyAudioGenerator.layerSample(
                layer,
                time: Double(frame) / 44_100,
                frame: frame,
                sampleRate: 44_100
            )
            #expect(pair.left.isFinite)
            #expect(pair.right.isFinite)
            peak = max(peak, abs(pair.left), abs(pair.right))
        }

        #expect(peak > 0.001)
        #expect(peak <= 0.35)
        #expect(layer.label.contains("Retro"))
        #expect(layer.description.contains("Minor pentatonic"))
    }

    @Test("Live settings expose retro controls in a dedicated compact section")
    func liveSettingsExposeRetroControlsInDedicatedCompactSection() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AmbientFrequencySettingsView.swift")

        #expect(source.contains("title: \"Retro\""))
        #expect(source.contains("Advanced retro controls"))
        #expect(source.contains("AmbientFrequencyMusicSongPreset"))
        #expect(source.contains("musicComposerLayers"))
        #expect(source.contains(".retroMusic("))
        #expect(source.contains("Key"))
        #expect(source.contains("Scale"))
        #expect(source.contains("Chord"))
        #expect(source.contains("Pattern"))
    }

    @Test("Live settings expose active mix and per-sound controls without phantom clutter")
    func liveSettingsExposeActiveMixPerSoundControlsWithoutPhantomClutter() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AmbientFrequencySettingsView.swift")

        #expect(source.contains("Playback & Export"))
        #expect(source.contains("Per-Sound Mix"))
        #expect(source.contains("layerControls: liveLayerControls"))
        #expect(source.contains("ambientPlayback.start(livePlaybackRequest)"))
        #expect(source.contains("layers: selectedPreset.layers"))
        #expect(source.contains("FX: delay / space / tone"))
        #expect(source.contains("delaySend"))
        #expect(source.contains("spaceSend"))
        #expect(source.contains("tone"))
        #expect(!source.contains("Phantom / Binaural Pattern"))
        #expect(!source.contains("AmbientFrequencyPhantomPattern"))
        #expect(!source.contains("case triadic"))
        #expect(!source.contains("case quadWeave"))
    }

    @Test("Ambient settings use a compact Frequencies and Sounds flow")
    func ambientSettingsUseCompactFrequenciesAndSoundsFlow() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AmbientFrequencySettingsView.swift")
        let surface = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsSurfaceComponents.swift")

        #expect(surface.contains("struct SettingsDisclosureSection"))
        #expect(source.contains("SettingsDisclosureSection("))
        #expect(source.contains("AmbientFrequencyMixRecipe"))
        #expect(source.contains("applyMixRecipe("))
        #expect(source.contains("title: \"Preset / Vibe\""))
        #expect(source.contains("title: \"Sound Bed\""))
        #expect(source.contains("title: \"Retro\""))
        #expect(source.contains("title: \"Per-Sound Mix\""))
        #expect(source.contains("title: \"Playback & Export\""))
        #expect(source.contains("Advanced sound modules"))
        #expect(source.contains("Advanced tone lab"))
        #expect(source.contains("Export WAV"))
        #expect(source.contains("@State private var soundStackExpanded"))
        #expect(source.contains("@State private var mixerExpanded"))
        #expect(source.contains("layerMixerControls(index: index, control:"))
        #expect(!source.contains("let control = layerControl(at: index)\n        VStack"))
        #expect(!source.contains("Custom Mix Builder"))
        #expect(!source.contains("Research Posture"))
    }

    private func littleEndianUInt16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func littleEndianUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
