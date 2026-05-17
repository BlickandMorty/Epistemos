import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AmbientFrequencySettingsView: View {
    @AppStorage("epistemos.ambientFrequencies.presetID")
    private var selectedPresetID = AmbientFrequencyPreset.schumannCocktail.id
    @AppStorage("epistemos.ambientFrequencies.durationMinutes")
    private var durationMinutes: Double = 30
    @AppStorage("epistemos.ambientFrequencies.customMixEnabled")
    private var customMixEnabled = false
    @AppStorage("epistemos.ambientFrequencies.activeModuleIds")
    private var activeModuleIdsCSV = ""
    @State private var isExporting = false
    @State private var exportStatus: String?

    // MARK: - Live frequency player (iter 87)
    @State private var livePlayer = AmbientFrequencyLivePlayer()
    @State private var livePlayerRunning = false
    /// Stored as the slider position [0, 1]; converted to Hz via exponential
    /// mapping (industry standard for pitch sliders — every octave is the
    /// same visual distance).
    @State private var liveFrequencySliderPosition: Double = 0.55  // ≈440 Hz at 20-20000 range
    @State private var livePan: Double = 0
    @State private var liveGain: Double = 0.3
    @State private var liveWaveform: AmbientFrequencyLivePlayer.Waveform = .sineWave

    private var liveFrequencyHz: Float {
        let minHz = Double(AmbientFrequencyLivePlayer.minFrequencyHz)
        let maxHz = Double(AmbientFrequencyLivePlayer.maxFrequencyHz)
        let pos = min(max(liveFrequencySliderPosition, 0), 1)
        return Float(minHz * pow(maxHz / minHz, pos))
    }

    private static let wavType = UTType(filenameExtension: "wav") ?? .audio

    private var basePreset: AmbientFrequencyPreset {
        AmbientFrequencyPreset.preset(id: selectedPresetID)
    }

    /// The preset that the export pipeline actually consumes — either the
    /// base preset when custom mix is off, or the composed preset when it's on.
    private var selectedPreset: AmbientFrequencyPreset {
        if customMixEnabled {
            return AmbientFrequencyPreset.composed(
                base: basePreset,
                modules: activeModules,
                durationSeconds: resolvedDurationMinutes * 60
            )
        }
        return basePreset
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

    private func toggleModule(_ moduleId: String) {
        var ids = activeModuleIds
        if ids.contains(moduleId) {
            ids.remove(moduleId)
        } else {
            ids.insert(moduleId)
        }
        activeModuleIdsCSV = ids.sorted().joined(separator: ",")
    }

    private func isActive(_ moduleId: String) -> Bool {
        activeModuleIds.contains(moduleId)
    }

    private var resolvedDurationMinutes: Double {
        guard durationMinutes.isFinite else {
            return 30
        }
        return min(max(durationMinutes, 5), 120)
    }

    var body: some View {
        Form {
            SettingsDescriptionCard(
                title: "Ambient Frequencies",
                systemImage: "waveform.path",
                text: "Generate local, mathematically synthesized stereo WAV presets. The presets expose exact tones and binaural targets, but they are not medical treatment and do not guarantee brainwave entrainment."
            )

            Section("Preset Zone") {
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

            Section("Custom Mix Builder") {
                Toggle("Stack additional sounds on top of the base preset", isOn: $customMixEnabled)

                if customMixEnabled {
                    SettingsDescriptionText(
                        text: "Toggle modules to layer them on top of the selected base preset. Birds + rain + cathedral pad + a base focus pulse all play together. Disable to use the base preset by itself."
                    )

                    ForEach(AmbientFrequencySoundModuleCategory.allCases) { category in
                        DisclosureGroup(category.rawValue) {
                            ForEach(AmbientFrequencySoundModule.modules(in: category)) { module in
                                Toggle(isOn: Binding(
                                    get: { isActive(module.id) },
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

                    LabeledContent("Active modules") {
                        Text(activeModules.isEmpty ? "—" : "\(activeModules.count) layered (\(activeModules.map(\.title).joined(separator: ", ")))")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    LabeledContent("Composed layer count") {
                        Text("\(selectedPreset.layers.count) layers total")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section("Components (active mix)") {
                ForEach(Array(selectedPreset.layers.enumerated()), id: \.offset) { _, layer in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(layer.label)
                            .font(.caption.weight(.semibold))
                        SettingsDescriptionText(text: layer.description)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Export") {
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

            Section("Live Frequency Player — interactive real-time") {
                SettingsDescriptionText(
                    text: "Real-time AVAudioEngine synthesizer. Move the sliders and hear the change immediately — phase-continuous (no clicks), one-pole IIR smoothed (no zipper noise), W3C equal-power panning (-3 dB center). Industry-standard real-time audio per WWDC 2019 §510."
                )

                HStack(spacing: 10) {
                    Button {
                        if livePlayerRunning {
                            livePlayer.stop()
                            livePlayerRunning = false
                        } else {
                            do {
                                try livePlayer.start()
                                livePlayer.setFrequency(liveFrequencyHz)
                                livePlayer.setPan(Float(livePan))
                                livePlayer.setGain(Float(liveGain))
                                livePlayer.setWaveform(liveWaveform)
                                livePlayerRunning = true
                            } catch {
                                exportStatus = "Live player failed: \(error.localizedDescription)"
                            }
                        }
                    } label: {
                        Label(
                            livePlayerRunning ? "Stop" : "Play",
                            systemImage: livePlayerRunning ? "stop.fill" : "play.fill"
                        )
                    }
                    if livePlayerRunning {
                        Text("Live — moving sliders updates in real time")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

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
                        if livePlayerRunning {
                            livePlayer.setFrequency(liveFrequencyHz)
                        }
                    }
                    Text("Exponential mapping — every octave is equal slider distance (industry standard for pitch).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Pan") {
                        Text(panLabel(for: livePan))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $livePan, in: -1...1) {
                        Text("Pan")
                    } minimumValueLabel: {
                        Text("L").font(.caption2)
                    } maximumValueLabel: {
                        Text("R").font(.caption2)
                    }
                    .onChange(of: livePan) { _, _ in
                        if livePlayerRunning {
                            livePlayer.setPan(Float(livePan))
                        }
                    }
                    Text("W3C equal-power pan law — leftGain² + rightGain² = 1 (constant power, -3 dB center).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Gain") {
                        Text(String(format: "%.2f", liveGain))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $liveGain, in: 0...1) {
                        Text("Gain")
                    }
                    .onChange(of: liveGain) { _, _ in
                        if livePlayerRunning {
                            livePlayer.setGain(Float(liveGain))
                        }
                    }
                }

                Picker("Waveform", selection: $liveWaveform) {
                    ForEach(AmbientFrequencyLivePlayer.Waveform.allCases) { waveform in
                        Text(waveform.label).tag(waveform)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: liveWaveform) { _, _ in
                    if livePlayerRunning {
                        livePlayer.setWaveform(liveWaveform)
                    }
                }
            }

            Section("Research Posture") {
                SettingsDescriptionText(
                    text: "EEG band labels are used as precise audio targets only. Published binaural-beat studies are heterogeneous and mixed, so Epistemos keeps claims conservative and exports exactly what the preset says."
                )
            }
        }
        .formStyle(.grouped)
        .onChange(of: durationMinutes) { _, newValue in
            if !newValue.isFinite {
                durationMinutes = 30
            }
        }
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
            outputURL: outputURL
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
                exportStatus = error.localizedDescription
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
}

#Preview("Ambient Frequency Settings") {
    AmbientFrequencySettingsView()
}
