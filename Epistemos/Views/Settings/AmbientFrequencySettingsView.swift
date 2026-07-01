import AppKit
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum AmbientFrequencyExportDiagnostics {
    static let maxStatusMessageCharacters = 360
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func statusMessage(for error: Error, fallback: String = "Ambient export failed.") -> String {
        if let exportError = error as? AmbientFrequencyAudioGeneratorError {
            return statusMessage(for: exportError, fallback: fallback)
        }
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return statusMessage("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
    }

    static func statusMessage(_ message: String, fallback: String = "Ambient export failed.") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxStatusMessageCharacters else {
            return value
        }
        return String(value.prefix(maxStatusMessageCharacters)) + "..."
    }

    private static func statusMessage(
        for error: AmbientFrequencyAudioGeneratorError,
        fallback: String
    ) -> String {
        switch error {
        case .couldNotCreateOutput(let url):
            let filename = url.lastPathComponent.isEmpty ? "selected file" : url.lastPathComponent
            return statusMessage("Could not create output file \(filename).", fallback: fallback)
        default:
            return statusMessage(error.errorDescription ?? fallback, fallback: fallback)
        }
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let safeDomain = String(value.prefix(maxDomainCharacters))
        return safeDomain.isEmpty ? "Error" : safeDomain
    }
}

private struct AmbientFrequencyMusicSongSettings {
    let key: AmbientFrequencyMusicKey
    let scale: AmbientFrequencyMusicScale
    let chord: AmbientFrequencyChordQuality
    let pattern: AmbientFrequencyMusicPattern
    let instrument: AmbientFrequencyRetroInstrument
    let octave: Int
    let tempoBPM: Double
    let amplitude: Double
}

private enum AmbientFrequencyMusicSongPreset: String, CaseIterable, Identifiable {
    case custom
    case neonArp
    case arcadeSleep
    case glassPad
    case dungeonBass
    case sunsetPluck
    case dreamBell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .custom: return "Custom"
        case .neonArp: return "Neon arp"
        case .arcadeSleep: return "Arcade sleep"
        case .glassPad: return "Glass pad"
        case .dungeonBass: return "Dungeon bass"
        case .sunsetPluck: return "Sunset pluck"
        case .dreamBell: return "Dream bell"
        }
    }

    var settings: AmbientFrequencyMusicSongSettings? {
        switch self {
        case .custom:
            return nil
        case .neonArp:
            return AmbientFrequencyMusicSongSettings(
                key: .c,
                scale: .minorPentatonic,
                chord: .minor7,
                pattern: .arpUp,
                instrument: .pulse25,
                octave: 4,
                tempoBPM: 112,
                amplitude: 0.11
            )
        case .arcadeSleep:
            return AmbientFrequencyMusicSongSettings(
                key: .a,
                scale: .dorian,
                chord: .sus2,
                pattern: .chipSong,
                instrument: .pulse50,
                octave: 3,
                tempoBPM: 96,
                amplitude: 0.10
            )
        case .glassPad:
            return AmbientFrequencyMusicSongSettings(
                key: .fSharp,
                scale: .lydian,
                chord: .major7,
                pattern: .chordPulse,
                instrument: .opl2Pad,
                octave: 4,
                tempoBPM: 72,
                amplitude: 0.08
            )
        case .dungeonBass:
            return AmbientFrequencyMusicSongSettings(
                key: .d,
                scale: .phrygian,
                chord: .power,
                pattern: .bassWalk,
                instrument: .saw,
                octave: 2,
                tempoBPM: 84,
                amplitude: 0.12
            )
        case .sunsetPluck:
            return AmbientFrequencyMusicSongSettings(
                key: .g,
                scale: .mixolydian,
                chord: .dominant7,
                pattern: .melodyWander,
                instrument: .softPluck,
                octave: 4,
                tempoBPM: 92,
                amplitude: 0.10
            )
        case .dreamBell:
            return AmbientFrequencyMusicSongSettings(
                key: .e,
                scale: .wholeTone,
                chord: .augmented,
                pattern: .triadBounce,
                instrument: .fmBell,
                octave: 5,
                tempoBPM: 76,
                amplitude: 0.08
            )
        }
    }
}

private struct AmbientFrequencyMixRecipe: Identifiable {
    let id: String
    let title: String
    let summary: String
    let moduleIds: [String]

    static let softFocus = AmbientFrequencyMixRecipe(
        id: "soft-focus",
        title: "soft focus",
        summary: "Pink bed, wind, and a small bird layer. Smooth first, detailed second.",
        moduleIds: [
            "color-pink",
            "nature-wind",
            "nature-birds-chirping",
        ]
    )

    static let retroRain = AmbientFrequencyMixRecipe(
        id: "retro-rain",
        title: "retro rain",
        summary: "Gentle rain with NES motion and a low brown floor.",
        moduleIds: [
            "nature-gentle-rain",
            "color-brown",
            "retro-nes-arpeggio",
        ]
    )

    static let deepCave = AmbientFrequencyMixRecipe(
        id: "deep-cave",
        title: "deep cave",
        summary: "Brown cave, distant thunder, and a restrained sub pulse.",
        moduleIds: [
            "color-brown",
            "nature-distant-thunder",
            "texture-sub-bass-pulse",
        ]
    )

    static let allRecipes: [AmbientFrequencyMixRecipe] = [
        .softFocus,
        .retroRain,
        .deepCave,
    ]
}

struct AmbientFrequencySettingsView: View {
    @Environment(AmbientFrequencyPlaybackState.self)
    private var ambientPlayback
    @AppStorage("epistemos.ambientFrequencies.presetID")
    private var selectedPresetID = AmbientFrequencyPreset.schumannCocktail.id
    @AppStorage("epistemos.ambientFrequencies.durationMinutes")
    private var durationMinutes: Double = 30
    @AppStorage("epistemos.ambientFrequencies.customMixEnabled")
    private var customMixEnabled = false
    @AppStorage("epistemos.ambientFrequencies.activeModuleIds")
    private var activeModuleIdsCSV = ""
    @AppStorage("epistemos.ambientFrequencies.layerControlsJSON")
    private var layerControlsJSON = "{}"
    @AppStorage("epistemos.ambientFrequencies.music.enabled")
    private var musicEnabled = false
    @AppStorage("epistemos.ambientFrequencies.music.songPreset")
    private var musicSongPresetRaw = AmbientFrequencyMusicSongPreset.neonArp.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.key")
    private var musicKeyRaw = AmbientFrequencyMusicKey.c.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.scale")
    private var musicScaleRaw = AmbientFrequencyMusicScale.minorPentatonic.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.chord")
    private var musicChordRaw = AmbientFrequencyChordQuality.minor7.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.pattern")
    private var musicPatternRaw = AmbientFrequencyMusicPattern.arpUp.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.instrument")
    private var musicInstrumentRaw = AmbientFrequencyRetroInstrument.pulse25.rawValue
    @AppStorage("epistemos.ambientFrequencies.music.octave")
    private var musicOctave = 4
    @AppStorage("epistemos.ambientFrequencies.music.tempoBPM")
    private var musicTempoBPM = 96.0
    @AppStorage("epistemos.ambientFrequencies.music.amplitude")
    private var musicAmplitude = 0.11
    @State private var isExporting = false
    @State private var exportStatus: String?
    @State private var liveRestartTask: Task<Void, Never>?
    @State private var presetExpanded = true
    @State private var soundStackExpanded = true
    @State private var composerExpanded = false
    @State private var mixerExpanded = true
    @State private var playbackExpanded = true
    @State private var exportExpanded = false

    // MARK: - Live frequency player (iter 87)
    @AppStorage("epistemos.ambientFrequencies.liveToneLabEnabled")
    private var liveToneLabEnabled = false
    /// Stored as the slider position [0, 1]; converted to Hz via exponential
    /// mapping (industry standard for pitch sliders — every octave is the
    /// same visual distance).
    @AppStorage("epistemos.ambientFrequencies.liveFrequencySliderPosition")
    private var liveFrequencySliderPosition: Double = 0.55  // ≈440 Hz at 20-20000 range
    @AppStorage("epistemos.ambientFrequencies.livePan")
    private var livePan: Double = 0
    @AppStorage("epistemos.ambientFrequencies.liveGain")
    private var liveGain: Double = 0.3
    @AppStorage("epistemos.ambientFrequencies.liveWaveform")
    private var liveWaveformRaw = AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue
    @AppStorage("epistemos.ambientFrequencies.liveBitCrush")
    private var liveBitCrush: Double = 16  // 16 = no effect, ≥1
    @AppStorage("epistemos.ambientFrequencies.liveSampleRateHold")
    private var liveSampleRateHold: Double = 1  // 1 = no effect, ≤64

    private var liveFrequencyHz: Float {
        let minHz = Double(AmbientFrequencyLivePlayer.minFrequencyHz)
        let maxHz = Double(AmbientFrequencyLivePlayer.maxFrequencyHz)
        let pos = min(max(liveFrequencySliderPosition, 0), 1)
        return Float(minHz * pow(maxHz / minHz, pos))
    }

    private var liveWaveform: AmbientFrequencyLivePlayer.Waveform {
        get {
            AmbientFrequencyLivePlayer.Waveform(rawValue: liveWaveformRaw) ?? .sineWave
        }
        nonmutating set {
            liveWaveformRaw = newValue.rawValue
        }
    }

    private var liveWaveformBinding: Binding<AmbientFrequencyLivePlayer.Waveform> {
        Binding(
            get: { liveWaveform },
            set: { liveWaveform = $0 }
        )
    }

    private static let wavType = UTType(filenameExtension: "wav") ?? .audio

    private var basePreset: AmbientFrequencyPreset {
        AmbientFrequencyPreset.preset(id: selectedPresetID)
    }

    /// The preset that the export pipeline actually consumes — either the
    /// base preset when custom mix is off, or the composed preset when it's on.
    private var selectedPreset: AmbientFrequencyPreset {
        let preset: AmbientFrequencyPreset
        if customMixEnabled {
            preset = AmbientFrequencyPreset.composed(
                base: basePreset,
                modules: activeModules,
                durationSeconds: resolvedDurationMinutes * 60
            )
        } else {
            preset = basePreset
        }
        var layers = preset.layers
        var idSuffixes: [String] = []
        var titleSuffixes: [String] = []
        var summarySuffixes: [String] = []
        let requiresHeadphones = preset.requiresHeadphones

        if musicEnabled, !musicComposerLayers.isEmpty {
            layers.append(contentsOf: musicComposerLayers)
            idSuffixes.append("music")
            titleSuffixes.append("Retro")
            summarySuffixes.append("retro \(musicPattern.label.lowercased()) in \(musicKey.label) \(musicScale.label.lowercased()) at \(Int(safeMusicTempoBPM.rounded())) BPM")
        }

        guard !idSuffixes.isEmpty else {
            return preset
        }
        return AmbientFrequencyPreset(
            id: "\(preset.id)+\(idSuffixes.joined(separator: "+"))",
            title: "\(preset.title) + \(titleSuffixes.joined(separator: " + "))",
            intent: preset.intent,
            summary: "\(preset.summary)  + \(summarySuffixes.joined(separator: " + ")).",
            requiresHeadphones: requiresHeadphones,
            defaultDurationSeconds: preset.defaultDurationSeconds,
            layers: layers
        )
    }

    private var musicSongPreset: AmbientFrequencyMusicSongPreset {
        AmbientFrequencyMusicSongPreset(rawValue: musicSongPresetRaw) ?? .neonArp
    }

    private var musicKey: AmbientFrequencyMusicKey {
        AmbientFrequencyMusicKey(rawValue: musicKeyRaw) ?? .c
    }

    private var musicScale: AmbientFrequencyMusicScale {
        AmbientFrequencyMusicScale(rawValue: musicScaleRaw) ?? .minorPentatonic
    }

    private var musicChord: AmbientFrequencyChordQuality {
        AmbientFrequencyChordQuality(rawValue: musicChordRaw) ?? .minor7
    }

    private var musicPattern: AmbientFrequencyMusicPattern {
        AmbientFrequencyMusicPattern(rawValue: musicPatternRaw) ?? .arpUp
    }

    private var musicInstrument: AmbientFrequencyRetroInstrument {
        AmbientFrequencyRetroInstrument(rawValue: musicInstrumentRaw) ?? .pulse25
    }

    private var safeMusicOctave: Int {
        min(max(musicOctave, 1), 6)
    }

    private var safeMusicTempoBPM: Double {
        guard musicTempoBPM.isFinite else { return 96 }
        return min(max(musicTempoBPM, 40), 220)
    }

    private var safeMusicAmplitude: Double {
        guard musicAmplitude.isFinite else { return 0.11 }
        return min(max(musicAmplitude, 0), 0.5)
    }

    private var musicRootMidiNote: Int {
        12 * (safeMusicOctave + 1) + musicKey.semitone
    }

    private var musicComposerLayers: [AmbientFrequencyLayer] {
        guard musicEnabled else { return [] }
        return [
            .retroMusic(
                rootMidiNote: musicRootMidiNote,
                scale: musicScale,
                chord: musicChord,
                pattern: musicPattern,
                instrument: musicInstrument,
                tempoBPM: safeMusicTempoBPM,
                amplitude: safeMusicAmplitude
            ),
        ]
    }

    private var activeModuleIds: Set<String> {
        Set(activeModuleIdsCSV
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }

    private var activeModules: [AmbientFrequencySoundModule] {
        AmbientFrequencySoundModule.allModules.filter { activeModuleIds.contains($0.id) }
    }

    private var liveLayerControls: [AmbientFrequencyLayerMixControl] {
        layerControls(for: selectedPreset.id, count: selectedPreset.layers.count)
    }

    private var livePlaybackRequest: AmbientFrequencyPlaybackRequest {
        AmbientFrequencyPlaybackRequest(
            title: selectedPreset.title,
            mode: liveToneLabEnabled ? .toneLab : .activeMix,
            layers: selectedPreset.layers,
            controls: liveLayerControls,
            frequencyHz: liveFrequencyHz,
            pan: livePan,
            gain: liveGain,
            waveform: liveWaveform,
            bitCrushDepth: Int(liveBitCrush),
            sampleRateHold: Int(liveSampleRateHold)
        )
    }

    private func layerControls(
        for presetID: String,
        count: Int
    ) -> [AmbientFrequencyLayerMixControl] {
        var controls = decodedLayerControlStore()[presetID] ?? []
        if controls.count < count {
            controls.append(contentsOf: Array(repeating: .neutral, count: count - controls.count))
        }
        if controls.count > count {
            controls = Array(controls.prefix(count))
        }
        return controls.map(\.sanitized)
    }

    private func layerControl(at index: Int) -> AmbientFrequencyLayerMixControl {
        let controls = liveLayerControls
        guard index >= 0, index < controls.count else {
            return .neutral
        }
        return controls[index]
    }

    private func updateLayerControl(
        at index: Int,
        _ update: (inout AmbientFrequencyLayerMixControl) -> Void
    ) {
        guard index >= 0, index < selectedPreset.layers.count else { return }
        var store = decodedLayerControlStore()
        var controls = layerControls(for: selectedPreset.id, count: selectedPreset.layers.count)
        var control = controls[index]
        update(&control)
        controls[index] = control.sanitized
        store[selectedPreset.id] = controls
        if let data = try? JSONEncoder().encode(store),
           let json = String(data: data, encoding: .utf8) {
            layerControlsJSON = json
        }
        if ambientPlayback.isRunning, !liveToneLabEnabled {
            ambientPlayback.setLayerControl(index: index, control: controls[index])
        }
    }

    private func decodedLayerControlStore() -> [String: [AmbientFrequencyLayerMixControl]] {
        guard let data = layerControlsJSON.data(using: .utf8),
              let store = try? JSONDecoder().decode([String: [AmbientFrequencyLayerMixControl]].self, from: data) else {
            return [:]
        }
        return store
    }

    private func toggleModule(_ moduleId: String) {
        var ids = activeModuleIds
        if ids.contains(moduleId) {
            ids.remove(moduleId)
        } else {
            ids.insert(moduleId)
        }
        activeModuleIdsCSV = ids.sorted().joined(separator: ",")
        restartLivePlayerIfRunning()
    }

    private func applyMixRecipe(_ recipe: AmbientFrequencyMixRecipe) {
        let validIds = recipe.moduleIds
            .filter { AmbientFrequencySoundModule.module(id: $0) != nil }
        customMixEnabled = true
        activeModuleIdsCSV = validIds.sorted().joined(separator: ",")
        restartLivePlayerIfRunning()
    }

    private func applyMusicSongPreset(_ preset: AmbientFrequencyMusicSongPreset) {
        guard let settings = preset.settings else {
            restartLivePlayerIfRunning()
            return
        }
        musicKeyRaw = settings.key.rawValue
        musicScaleRaw = settings.scale.rawValue
        musicChordRaw = settings.chord.rawValue
        musicPatternRaw = settings.pattern.rawValue
        musicInstrumentRaw = settings.instrument.rawValue
        musicOctave = settings.octave
        musicTempoBPM = settings.tempoBPM
        musicAmplitude = settings.amplitude
        restartLivePlayerIfRunning()
    }

    private func markMusicCustomAndRestart() {
        if musicSongPresetRaw != AmbientFrequencyMusicSongPreset.custom.rawValue {
            musicSongPresetRaw = AmbientFrequencyMusicSongPreset.custom.rawValue
            return
        }
        restartLivePlayerIfRunning()
    }

    private func startLivePlayer() {
        ambientPlayback.start(livePlaybackRequest)
    }

    private func stopLivePlayer() {
        ambientPlayback.stop()
    }

    private func restartLivePlayerIfRunning() {
        scheduleLiveRestartIfRunning()
    }

    private func scheduleLiveRestartIfRunning() {
        guard ambientPlayback.isRunning else { return }
        liveRestartTask?.cancel()
        liveRestartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            ambientPlayback.restartIfRunning(livePlaybackRequest)
        }
    }

    private func applyLivePlayerTargets() {
        ambientPlayback.applyTargets(from: livePlaybackRequest)
    }

    private var resolvedDurationMinutes: Double {
        guard durationMinutes.isFinite else {
            return 30
        }
        return min(max(durationMinutes, 5), 120)
    }

    @ViewBuilder
    private func layerMixerControls(
        index: Int,
        control: AmbientFrequencyLayerMixControl
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            mixerSliderRow(
                title: "Volume",
                valueText: String(format: "%.2fx", control.volume),
                value: layerControlBinding(index: index, \.volume),
                range: 0...2,
                minimumLabel: "0",
                maximumLabel: "2x"
            )

            mixerSliderRow(
                title: "Pan",
                valueText: panLabel(for: control.pan),
                value: layerControlBinding(index: index, \.pan),
                range: -1...1,
                minimumLabel: "L",
                maximumLabel: "R"
            )

            mixerSliderRow(
                title: "Distortion",
                valueText: String(format: "%.0f%%", control.distortion * 100),
                value: layerControlBinding(index: index, \.distortion),
                range: 0...1,
                minimumLabel: "clean",
                maximumLabel: "drive"
            )

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    mixerSliderRow(
                        title: "Tone filter",
                        valueText: toneLabel(for: control.tone),
                        value: layerControlBinding(index: index, \.tone),
                        range: -1...1,
                        minimumLabel: "warm",
                        maximumLabel: "bright"
                    )

                    mixerSliderRow(
                        title: "Delay send",
                        valueText: percentLabel(control.delaySend),
                        value: layerControlBinding(index: index, \.delaySend),
                        range: 0...1,
                        minimumLabel: "dry",
                        maximumLabel: "wet"
                    )

                    mixerSliderRow(
                        title: "Delay time",
                        valueText: secondsLabel(control.delayTimeSeconds),
                        value: layerControlBinding(index: index, \.delayTimeSeconds),
                        range: 0.05...1.5,
                        minimumLabel: "short",
                        maximumLabel: "long"
                    )

                    mixerSliderRow(
                        title: "Feedback",
                        valueText: percentLabel(control.delayFeedback),
                        value: layerControlBinding(index: index, \.delayFeedback),
                        range: 0...0.85,
                        minimumLabel: "one",
                        maximumLabel: "loop"
                    )

                    mixerSliderRow(
                        title: "Space",
                        valueText: percentLabel(control.spaceSend),
                        value: layerControlBinding(index: index, \.spaceSend),
                        range: 0...1,
                        minimumLabel: "near",
                        maximumLabel: "wide"
                    )
                }
                .padding(.top, 6)
            } label: {
                Label("FX: delay / space / tone", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.top, 6)
    }

    private func layerControlBinding(
        index: Int,
        _ keyPath: WritableKeyPath<AmbientFrequencyLayerMixControl, Double>
    ) -> Binding<Double> {
        Binding(
            get: { layerControl(at: index)[keyPath: keyPath] },
            set: { value in
                updateLayerControl(at: index) { control in
                    control[keyPath: keyPath] = value
                }
            }
        )
    }

    @ViewBuilder
    private func mixerSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        minimumLabel: String,
        maximumLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                Text(valueText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(minimumLabel).font(.caption2)
            } maximumValueLabel: {
                Text(maximumLabel).font(.caption2)
            }
        }
    }

    var body: some View {
        let displayedPreset = selectedPreset
        let displayedControls = layerControls(for: displayedPreset.id, count: displayedPreset.layers.count)
        let activeIds = activeModuleIds
        let activeModuleList = activeModules

        Form {
            SettingsDescriptionCard(
                title: "Frequencies & Sounds",
                systemImage: "waveform.path",
                text: "Choose a preset, add a sound bed, optionally layer retro music, mix each sound, then play or export the result."
            )

            SettingsDisclosureSection(
                title: "Preset / Vibe",
                subtitle: basePreset.title,
                systemImage: "sparkles",
                isExpanded: $presetExpanded
            ) {
                Picker("Preset", selection: $selectedPresetID) {
                    ForEach(AmbientFrequencyPreset.allPresets) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Intent") {
                    Text(basePreset.intent)
                        .foregroundStyle(.secondary)
                }
                SettingsDescriptionText(text: basePreset.summary)

                if basePreset.requiresHeadphones {
                    Label("Use headphones for binaural separation.", systemImage: "headphones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsDisclosureSection(
                title: "Sound Bed",
                subtitle: customMixEnabled
                    ? "\(activeModuleList.count) sounds layered"
                    : "Curated beds first, module library collapsed",
                systemImage: "square.stack.3d.up",
                isExpanded: $soundStackExpanded
            ) {
                Toggle("Layer a sound bed", isOn: $customMixEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(AmbientFrequencyMixRecipe.allRecipes) { recipe in
                        Button {
                            applyMixRecipe(recipe)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.title)
                                        .font(.caption.weight(.semibold))
                                    Text(recipe.summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if customMixEnabled {
                    DisclosureGroup("Advanced sound modules") {
                        ForEach(AmbientFrequencySoundModuleCategory.allCases) { category in
                            DisclosureGroup(category.rawValue) {
                                ForEach(AmbientFrequencySoundModule.modules(in: category)) { module in
                                    Toggle(isOn: Binding(
                                        get: { activeIds.contains(module.id) },
                                        set: { _ in toggleModule(module.id) }
                                    )) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(module.title).font(.caption.weight(.semibold))
                                            Text(module.summary).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                    }

                    LabeledContent("Active modules") {
                        Text(activeModuleList.isEmpty ? "—" : "\(activeModuleList.count) layered (\(activeModuleList.map(\.title).joined(separator: ", ")))")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    LabeledContent("Composed layer count") {
                        Text("\(displayedPreset.layers.count) layers total")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            SettingsDisclosureSection(
                title: "Retro",
                subtitle: musicEnabled
                    ? "\(musicSongPreset.label), \(musicKey.label) \(musicScale.label), \(Int(safeMusicTempoBPM.rounded())) BPM"
                    : "Optional key, scale, chord, pattern, and instrument layer",
                systemImage: "music.note.list",
                isExpanded: $composerExpanded
            ) {
                Toggle("Add key/scale/chord music layer", isOn: $musicEnabled)
                    .onChange(of: musicEnabled) { _, _ in restartLivePlayerIfRunning() }

                if musicEnabled {
                    Picker("Song preset", selection: $musicSongPresetRaw) {
                        ForEach(AmbientFrequencyMusicSongPreset.allCases) { preset in
                            Text(preset.label).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: musicSongPresetRaw) { _, newValue in
                        applyMusicSongPreset(AmbientFrequencyMusicSongPreset(rawValue: newValue) ?? .neonArp)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Music level") {
                            Text(String(format: "%.2f", safeMusicAmplitude))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $musicAmplitude, in: 0...0.5) {
                            Text("Music level")
                        }
                        .onChange(of: musicAmplitude) { _, newValue in
                            if !newValue.isFinite { musicAmplitude = 0.11 }
                            if musicSongPresetRaw != AmbientFrequencyMusicSongPreset.custom.rawValue {
                                musicSongPresetRaw = AmbientFrequencyMusicSongPreset.custom.rawValue
                            }
                            scheduleLiveRestartIfRunning()
                        }
                    }

                    DisclosureGroup("Advanced retro controls") {
                        DisclosureGroup("Harmony") {
                            Picker("Key", selection: $musicKeyRaw) {
                                ForEach(AmbientFrequencyMusicKey.allCases) { key in
                                    Text(key.label).tag(key.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: musicKeyRaw) { _, _ in markMusicCustomAndRestart() }

                            Picker("Scale", selection: $musicScaleRaw) {
                                ForEach(AmbientFrequencyMusicScale.allCases) { scale in
                                    Text(scale.label).tag(scale.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: musicScaleRaw) { _, _ in markMusicCustomAndRestart() }

                            Picker("Chord", selection: $musicChordRaw) {
                                ForEach(AmbientFrequencyChordQuality.allCases) { chord in
                                    Text(chord.label).tag(chord.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: musicChordRaw) { _, _ in markMusicCustomAndRestart() }
                        }

                        DisclosureGroup("Performance") {
                            Picker("Pattern", selection: $musicPatternRaw) {
                                ForEach(AmbientFrequencyMusicPattern.allCases) { pattern in
                                    Text(pattern.label).tag(pattern.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: musicPatternRaw) { _, _ in markMusicCustomAndRestart() }

                            Picker("Instrument", selection: $musicInstrumentRaw) {
                                ForEach(AmbientFrequencyRetroInstrument.allCases) { instrument in
                                    Text(instrument.label).tag(instrument.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: musicInstrumentRaw) { _, _ in markMusicCustomAndRestart() }

                            Stepper(value: $musicOctave, in: 1...6, step: 1) {
                                LabeledContent("Octave") {
                                    Text("\(safeMusicOctave)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .onChange(of: musicOctave) { _, _ in markMusicCustomAndRestart() }

                            VStack(alignment: .leading, spacing: 6) {
                                LabeledContent("Tempo") {
                                    Text("\(Int(safeMusicTempoBPM.rounded())) BPM")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(value: $musicTempoBPM, in: 40...220, step: 1) {
                                    Text("Tempo")
                                }
                                .onChange(of: musicTempoBPM) { _, newValue in
                                    if !newValue.isFinite { musicTempoBPM = 96 }
                                    if musicSongPresetRaw != AmbientFrequencyMusicSongPreset.custom.rawValue {
                                        musicSongPresetRaw = AmbientFrequencyMusicSongPreset.custom.rawValue
                                    }
                                    scheduleLiveRestartIfRunning()
                                }
                            }
                        }
                    }
                }
            }

            SettingsDisclosureSection(
                title: "Per-Sound Mix",
                subtitle: "\(displayedPreset.layers.count) channel strips with volume, pan, drive, tone, delay, and space",
                systemImage: "slider.horizontal.3",
                isExpanded: $mixerExpanded
            ) {
                SettingsDescriptionText(
                    text: "Every active sound has its own compact channel strip. Keep volume, pan, and drive visible; open FX only when you want delay, room space, or tone shaping. These controls affect live playback and exported WAVs."
                )

                ForEach(Array(displayedPreset.layers.enumerated()), id: \.offset) { index, layer in
                    let control = displayedControls.indices.contains(index) ? displayedControls[index] : .neutral
                    DisclosureGroup {
                        layerMixerControls(index: index, control: control)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sound \(index + 1): \(layer.label)")
                                .font(.caption.weight(.semibold))
                            SettingsDescriptionText(text: layer.description)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            SettingsDisclosureSection(
                title: "Playback & Export",
                subtitle: ambientPlayback.isRunning
                    ? ambientPlayback.landingMediaSubtitle
                    : "\(Int(resolvedDurationMinutes)) min export, active mix playback",
                systemImage: ambientPlayback.isRunning ? "stop.fill" : "play.fill",
                isExpanded: $playbackExpanded
            ) {
                HStack(spacing: 10) {
                    Button {
                        if ambientPlayback.isRunning {
                            stopLivePlayer()
                        } else {
                            startLivePlayer()
                        }
                    } label: {
                        Label(
                            ambientPlayback.isRunning ? "Stop" : "Play",
                            systemImage: ambientPlayback.isRunning ? "stop.fill" : "play.fill"
                        )
                    }
                    if ambientPlayback.isRunning {
                        Text(liveToneLabEnabled ? "Live tone lab" : "Live active mix")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                if let status = ambientPlayback.status {
                    SettingsDescriptionText(text: status)
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Master volume") {
                        Text(String(format: "%.2f", liveGain))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $liveGain, in: 0...1) {
                        Text("Master volume")
                    }
                    .onChange(of: liveGain) { _, _ in
                        if ambientPlayback.isRunning {
                            ambientPlayback.setGain(liveGain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Master pan") {
                        Text(panLabel(for: livePan))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $livePan, in: -1...1) {
                        Text("Master pan")
                    } minimumValueLabel: {
                        Text("L").font(.caption2)
                    } maximumValueLabel: {
                        Text("R").font(.caption2)
                    }
                    .onChange(of: livePan) { _, _ in
                        if ambientPlayback.isRunning {
                            ambientPlayback.setPan(livePan)
                        }
                    }
                }

                DisclosureGroup("Advanced tone lab") {
                    Toggle("Single oscillator tone lab", isOn: $liveToneLabEnabled)
                        .onChange(of: liveToneLabEnabled) { _, _ in restartLivePlayerIfRunning() }

                    if liveToneLabEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent("Frequency") {
                                Text(formatFrequency(liveFrequencyHz))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $liveFrequencySliderPosition, in: 0...1) {
                                Text("Frequency")
                            } minimumValueLabel: {
                                Text("20 Hz").font(.caption2)
                            } maximumValueLabel: {
                                Text("20 kHz").font(.caption2)
                            }
                            .onChange(of: liveFrequencySliderPosition) { _, _ in
                                if ambientPlayback.isRunning {
                                    ambientPlayback.setFrequency(liveFrequencyHz)
                                }
                            }
                            Text("Exponential mapping: every octave is equal slider distance.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Waveform", selection: liveWaveformBinding) {
                            ForEach(AmbientFrequencyLivePlayer.Waveform.allCases) { waveform in
                                Text(waveform.label).tag(waveform)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: liveWaveformRaw) { _, _ in
                            if ambientPlayback.isRunning {
                                ambientPlayback.setWaveform(liveWaveform)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                PixelCrunchBadge()
                                Text("PIXEL CRUNCH")
                                    .font(.system(.caption, design: .monospaced).weight(.bold))
                                    .tracking(2)
                            }
                            .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Bit depth") {
                                    Text(bitDepthLabel(Int(liveBitCrush)))
                                        .foregroundStyle(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                        .monospacedDigit()
                                }
                                Slider(value: $liveBitCrush, in: 1...16, step: 1) {
                                    Text("Bit depth")
                                } minimumValueLabel: {
                                    Text("1-bit").font(.caption2.monospaced())
                                } maximumValueLabel: {
                                    Text("16-bit").font(.caption2.monospaced())
                                }
                                .onChange(of: liveBitCrush) { _, _ in
                                    if ambientPlayback.isRunning {
                                        ambientPlayback.setBitCrushDepth(Int(liveBitCrush))
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Sample-rate hold") {
                                    Text("÷\(Int(liveSampleRateHold))")
                                        .foregroundStyle(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                        .monospacedDigit()
                                }
                                Slider(value: $liveSampleRateHold, in: 1...64, step: 1) {
                                    Text("Sample-rate hold")
                                } minimumValueLabel: {
                                    Text("÷1").font(.caption2.monospaced())
                                } maximumValueLabel: {
                                    Text("÷64").font(.caption2.monospaced())
                                }
                                .onChange(of: liveSampleRateHold) { _, _ in
                                    if ambientPlayback.isRunning {
                                        ambientPlayback.setSampleRateHold(Int(liveSampleRateHold))
                                    }
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("Export WAV", isExpanded: $exportExpanded) {
                    Stepper(value: $durationMinutes, in: 5...120, step: 5) {
                        LabeledContent("Duration") {
                            Text("\(Int(resolvedDurationMinutes)) minutes")
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Sample rate") {
                        Text("44100 Hz")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Format") {
                        Text("32-bit float WAV")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            exportCurrentPreset()
                        } label: {
                            Label(isExporting ? "Exporting..." : "Export WAV", systemImage: "square.and.arrow.down")
                        }
                        .disabled(isExporting)

                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let exportStatus {
                        SettingsDescriptionText(text: exportStatus)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            liveRestartTask?.cancel()
        }
        .onChange(of: durationMinutes) { _, newValue in
            if !newValue.isFinite {
                durationMinutes = 30
            }
        }
        .onChange(of: selectedPresetID) { _, _ in restartLivePlayerIfRunning() }
        .onChange(of: customMixEnabled) { _, _ in restartLivePlayerIfRunning() }
    }

    private func exportCurrentPreset() {
        let panel = NSSavePanel()
        panel.title = "Export Ambient Frequency WAV"
        panel.allowedContentTypes = [Self.wavType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultFilename()

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            return
        }

        let request = AmbientFrequencyExportRequest(
            preset: selectedPreset,
            durationSeconds: resolvedDurationMinutes * 60,
            sampleRate: AmbientFrequencyAudioGenerator.defaultSampleRate,
            outputURL: outputURL,
            layerControls: liveLayerControls
        )

        Task { @MainActor in
            isExporting = true
            exportStatus = "Rendering \(selectedPreset.title)..."
            do {
                let report = try await Task.detached(priority: .userInitiated) {
                    try AmbientFrequencyAudioGenerator.export(request)
                }.value
                exportStatus = "Wrote \(Int(report.durationSeconds / 60)) min, \(report.sampleRate) Hz, \(report.bitDepth)-bit float WAV to \(report.outputURL.lastPathComponent)."
            } catch {
                exportStatus = AmbientFrequencyExportDiagnostics.statusMessage(for: error)
            }
            isExporting = false
        }
    }

    private func defaultFilename() -> String {
        let minutes = Int(resolvedDurationMinutes)
        return "\(selectedPreset.id)-\(minutes)min-44100-float32.wav"
    }

    private func formatFrequency(_ hz: Float) -> String {
        if hz >= 1000 {
            return String(format: "%.2f kHz", hz / 1000)
        }
        return String(format: "%.1f Hz", hz)
    }

    private func panLabel(for pan: Double) -> String {
        if abs(pan) < 0.02 {
            return "Center"
        }
        let pct = Int(abs(pan) * 100)
        return pan < 0 ? "L \(pct)%" : "R \(pct)%"
    }

    private func toneLabel(for tone: Double) -> String {
        if abs(tone) < 0.02 {
            return "Neutral"
        }
        let pct = Int(abs(tone) * 100)
        return tone < 0 ? "Warm \(pct)%" : "Bright \(pct)%"
    }

    private func percentLabel(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    private func secondsLabel(_ value: Double) -> String {
        String(format: "%.2fs", min(max(value, 0.05), 1.5))
    }

    private func bitDepthLabel(_ bits: Int) -> String {
        switch bits {
        case 1: return "1-bit (PC speaker)"
        case 4: return "4-bit (Atari TIA)"
        case 8: return "8-bit (NES/Amiga)"
        case 12: return "12-bit (SNES era)"
        case 16: return "16-bit (no crush)"
        default: return "\(bits)-bit"
        }
    }
}

/// Pixel-art 8×8 sprite badge for "PIXEL CRUNCH" section header. Uses
/// SwiftUI Canvas with `interpolationQuality = .none` so pixels render as
/// crisp blocks at any scale — per the macOS 26 pixel-art SwiftUI pattern.
/// Glyph: a stylized "downsample" arrow showing input → quantized output.
private struct PixelCrunchBadge: View {
    private static let scale: CGFloat = 3

    // 8×8 pixel pattern. 1 = filled, 0 = transparent. Stylized "crush"
    // arrow pointing down.
    private static let pattern: [[Int]] = [
        [1, 0, 0, 0, 0, 0, 0, 1],
        [1, 1, 0, 0, 0, 0, 1, 1],
        [0, 1, 1, 0, 0, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1],
    ]

    var body: some View {
        Canvas { context, _ in
            // SwiftUI Canvas fills axis-aligned rectangles with crisp edges
            // by default (no anti-aliasing on integer-aligned solid fills),
            // giving us pixel-art rendering for free without the
            // .interpolation API. This is the canonical macOS pattern for
            // pixel-art sprites in SwiftUI.
            for (y, row) in Self.pattern.enumerated() {
                for (x, value) in row.enumerated() where value == 1 {
                    let rect = CGRect(
                        x: CGFloat(x) * Self.scale,
                        y: CGFloat(y) * Self.scale,
                        width: Self.scale,
                        height: Self.scale
                    )
                    context.fill(Path(rect), with: .color(.accentColor))
                }
            }
        }
        .frame(width: 8 * Self.scale, height: 8 * Self.scale)
        .accessibilityHidden(true)
    }
}

#Preview("Ambient Frequency Settings") {
    AmbientFrequencySettingsView()
        .environment(AmbientFrequencyPlaybackState())
}
