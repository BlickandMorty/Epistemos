import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AmbientFrequencySettingsView: View {
    @AppStorage("epistemos.ambientFrequencies.presetID")
    private var selectedPresetID = AmbientFrequencyPreset.schumannCocktail.id
    @AppStorage("epistemos.ambientFrequencies.durationMinutes")
    private var durationMinutes: Double = 30
    @State private var isExporting = false
    @State private var exportStatus: String?

    private static let wavType = UTType(filenameExtension: "wav") ?? .audio

    private var selectedPreset: AmbientFrequencyPreset {
        AmbientFrequencyPreset.preset(id: selectedPresetID)
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
                    Text(selectedPreset.intent)
                        .foregroundStyle(.secondary)
                }
                SettingsDescriptionText(text: selectedPreset.summary)

                if selectedPreset.requiresHeadphones {
                    Label("Use headphones for binaural separation.", systemImage: "headphones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Components") {
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
}

#Preview("Ambient Frequency Settings") {
    AmbientFrequencySettingsView()
}
