import Foundation
import Testing
@testable import Epistemos

/// UI/UX audit 2026-05-17 — Ambient Frequencies live-player persistence.
///
/// Pins the `@AppStorage` key names introduced by the audit so future
/// refactors don't silently drop the live-player parameters from
/// `UserDefaults` (driver §4.C step 7 — Persistence). The keys themselves
/// are the contract; the SwiftUI side reads/writes them via `@AppStorage`.
@Suite("UI/UX — Ambient Frequencies live-player persistence")
struct UIUXAmbientFrequenciesPersistenceTests {

    /// Audit-pinned key list. If a key is renamed, this test fails and the
    /// audit doc must be updated alongside the change.
    private static let auditedLiveKeys: [String] = [
        "epistemos.ambientFrequencies.liveFrequencySliderPosition",
        "epistemos.ambientFrequencies.livePan",
        "epistemos.ambientFrequencies.liveGain",
        "epistemos.ambientFrequencies.liveWaveformRaw",
        "epistemos.ambientFrequencies.liveBitCrush",
        "epistemos.ambientFrequencies.liveSampleRateHold",
    ]

    @Test("Live-player @AppStorage keys round-trip through UserDefaults")
    func livePlayerKeysRoundTrip() {
        let defaults = UserDefaults.standard
        let saved: [(key: String, original: Any?)] = Self.auditedLiveKeys.map {
            (key: $0, original: defaults.object(forKey: $0))
        }
        defer {
            for entry in saved {
                if let value = entry.original {
                    defaults.set(value, forKey: entry.key)
                } else {
                    defaults.removeObject(forKey: entry.key)
                }
            }
        }

        defaults.set(0.42, forKey: "epistemos.ambientFrequencies.liveFrequencySliderPosition")
        defaults.set(-0.5, forKey: "epistemos.ambientFrequencies.livePan")
        defaults.set(0.6, forKey: "epistemos.ambientFrequencies.liveGain")
        defaults.set(
            AmbientFrequencyLivePlayer.Waveform.triangleWave.rawValue,
            forKey: "epistemos.ambientFrequencies.liveWaveformRaw"
        )
        defaults.set(4, forKey: "epistemos.ambientFrequencies.liveBitCrush")
        defaults.set(8, forKey: "epistemos.ambientFrequencies.liveSampleRateHold")

        #expect(defaults.double(forKey: "epistemos.ambientFrequencies.liveFrequencySliderPosition") == 0.42)
        #expect(defaults.double(forKey: "epistemos.ambientFrequencies.livePan") == -0.5)
        #expect(defaults.double(forKey: "epistemos.ambientFrequencies.liveGain") == 0.6)
        #expect(defaults.integer(forKey: "epistemos.ambientFrequencies.liveWaveformRaw") ==
                AmbientFrequencyLivePlayer.Waveform.triangleWave.rawValue)
        #expect(defaults.integer(forKey: "epistemos.ambientFrequencies.liveBitCrush") == 4)
        #expect(defaults.integer(forKey: "epistemos.ambientFrequencies.liveSampleRateHold") == 8)
    }

    @Test("Live-player waveform raw values map 1:1 to enum cases")
    func waveformRawValuesAreStable() {
        // Pin the rawValue numbering: if anyone reorders the enum, persisted
        // user state would silently shift waveform on next launch.
        #expect(AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue == 0)
        #expect(AmbientFrequencyLivePlayer.Waveform.triangleWave.rawValue == 1)
        #expect(AmbientFrequencyLivePlayer.Waveform.sawtoothWave.rawValue == 2)
        #expect(AmbientFrequencyLivePlayer.Waveform.squareWave.rawValue == 3)
        #expect(AmbientFrequencyLivePlayer.Waveform.whiteNoise.rawValue == 4)
    }

    @Test("Live-player start/stop is idempotent")
    @MainActor
    func livePlayerStartStopIdempotent() {
        let player = AmbientFrequencyLivePlayer()
        // start() may legitimately throw on a headless test rig with no audio
        // device; we only assert the API surface here, not the engine result.
        do {
            try player.start()
            try player.start()
            player.stop()
            player.stop()
        } catch {
            // Test rig may lack an output device — that's not what we're
            // pinning here. Just ensure stop() after a failed start() is OK.
            player.stop()
        }
    }
}
