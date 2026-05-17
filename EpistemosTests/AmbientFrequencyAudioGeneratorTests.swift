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
        #expect(detailSource.contains("Preset Zone"))
        #expect(detailSource.contains("32-bit float WAV"))
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

    @Test("Module lookup by id is consistent with allModules registry")
    func moduleLookupByIdRoundTrip() throws {
        let birds = try #require(AmbientFrequencySoundModule.module(id: "nature-birds-chirping"))
        #expect(birds.category == .nature)
        let pink = try #require(AmbientFrequencySoundModule.module(id: "color-pink"))
        #expect(pink.category == .noiseColor)
        #expect(AmbientFrequencySoundModule.module(id: "totally-nonexistent") == nil)
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
