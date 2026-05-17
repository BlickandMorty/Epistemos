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
    /// Audiophile per-export master gain in dB (iter 34, 2026-05-17).
    /// Attenuation-only [-60, 0] so the rendered WAV's peak is bounded
    /// by the existing 0.92 normalize ceiling. 0 dB matches pre-iter-34
    /// behavior. Persisted so a user's preferred export level survives
    /// relaunches and applies to every preset.
    @AppStorage("epistemos.ambientFrequencies.exportMasterGainDb")
    private var exportMasterGainDb: Double = 0
    @State private var isExporting = false
    @State private var exportStatus: String?
    /// Separate live-player status so engine errors don't surface inside
    /// the unrelated Export section (UI/UX audit 2026-05-17 P1-1).
    @State private var livePlayerStatus: String?

    // MARK: - Live frequency player (iter 87)
    @State private var livePlayer = AmbientFrequencyLivePlayer()
    @State private var livePlayerRunning = false
    /// Stored as the slider position [0, 1]; converted to Hz via exponential
    /// mapping (industry standard for pitch sliders — every octave is the
    /// same visual distance).
    @AppStorage("epistemos.ambientFrequencies.liveFrequencySliderPosition")
    private var liveFrequencySliderPosition: Double = 0.55  // ≈440 Hz at 20-20000 range
    @AppStorage("epistemos.ambientFrequencies.livePan")
    private var livePan: Double = 0
    @AppStorage("epistemos.ambientFrequencies.liveGain")
    private var liveGain: Double = 0.3
    @AppStorage("epistemos.ambientFrequencies.liveWaveformRaw")
    private var liveWaveformRaw: Int = AmbientFrequencyLivePlayer.Waveform.sineWave.rawValue
    @AppStorage("epistemos.ambientFrequencies.liveBitCrush")
    private var liveBitCrush: Double = 16  // 16 = no effect, ≥1
    @AppStorage("epistemos.ambientFrequencies.liveSampleRateHold")
    private var liveSampleRateHold: Double = 1  // 1 = no effect, ≤64

    // MARK: - Audiophile dynamics chain (deep-hardening 2026-05-17)
    //
    // Master volume in dB plus a small but musically-correct mastering
    // chain (HPF + soft-clip limiter). Per-control reasoning lives at
    // the engine in `AmbientFrequencyLivePlayer.swift` — these are just
    // the persisted state + UI bindings.

    /// Master volume in decibels, [-60, +6]. 0 dB = unity. Audiophile
    /// scale: every -6 dB ≈ half perceived loudness; -∞ is mute. Slider
    /// uses dB directly so step granularity matches musical perception.
    @AppStorage("epistemos.ambientFrequencies.liveMasterVolumeDb")
    private var liveMasterVolumeDb: Double = 0
    /// Soft-clip limiter toggle. On by default — guards the DAC from
    /// accidental gain spikes (the legacy `gain * masterVolume` could
    /// otherwise reach 2+ at the slider's upper edge).
    @AppStorage("epistemos.ambientFrequencies.liveLimiterEnabled")
    private var liveLimiterEnabled: Bool = true
    /// High-pass cutoff in Hz, [0, 200]. Removes DC + sub-sonic rumble
    /// that pixel-crunch + SRR can produce. 0 disables; default 20 Hz
    /// (below human hearing).
    @AppStorage("epistemos.ambientFrequencies.liveHighPassCutoffHz")
    private var liveHighPassCutoffHz: Double = 20

    /// Polled peak level (linear, [0, 1]) for the VU-style meter.
    /// `TimelineView(.periodic(1/30))` refreshes this from
    /// `livePlayer.currentPeakLevel` while the engine is running.
    @State private var liveDisplayedPeak: Float = 0
    /// Held peak for the VU meter's classic "peak hold + decay" marker.
    /// When a new peak exceeds the held value, we latch it; after
    /// `peakHoldSeconds` of no surpass, the held value linearly decays
    /// over `peakDecaySeconds` back to the live peak. Audiophile
    /// mastering tools use this so a transient spike is visible long
    /// enough for the eye to catch.
    @State private var liveHeldPeak: Float = 0
    /// Wall-clock at which the held peak was last updated. Set on every
    /// new latch; consulted by the decay logic.
    @State private var liveHeldPeakSetAt: Date = .distantPast
    private let peakHoldSeconds: Double = 1.5
    private let peakDecaySeconds: Double = 0.5

    /// Typed accessor over the persisted raw waveform value. Falls back to
    /// sine on a corrupt value (defense in depth; @AppStorage Int defaults
    /// will already handle missing keys).
    private var liveWaveform: AmbientFrequencyLivePlayer.Waveform {
        get { AmbientFrequencyLivePlayer.Waveform(rawValue: liveWaveformRaw) ?? .sineWave }
        nonmutating set { liveWaveformRaw = newValue.rawValue }
    }

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

                // iter-34 (2026-05-17 deep-hardening): per-export master
                // gain knob. Attenuation-only so the existing 0.92
                // auto-normalize ceiling bounds the final peak — no
                // clipping risk regardless of slider position. Matches
                // the live-player Dynamics Chain section vocabulary.
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Master gain (export)") {
                        Text(formatDb(exportMasterGainDb))
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                            .monospacedDigit()
                    }
                    Slider(value: $exportMasterGainDb, in: -60...0, step: 0.5) {
                        Text("Master gain (export)")
                    } minimumValueLabel: {
                        Text("-60 dB").font(.caption2.monospaced())
                    } maximumValueLabel: {
                        Text("0 dB").font(.caption2.monospaced())
                    }
                    .accessibilityValue(formatDb(exportMasterGainDb))
                    Text("Audiophile per-export attenuation. Applied AFTER the auto-normalize-to-0.92 stage, so the rendered WAV is bounded — never clips. 0 dB matches the pre-iter-34 default behavior.")
                        .font(.caption2)
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
                            livePlayerStatus = nil
                        } else {
                            do {
                                try livePlayer.start()
                                livePlayer.setFrequency(liveFrequencyHz)
                                livePlayer.setPan(Float(livePan))
                                livePlayer.setGain(Float(liveGain))
                                livePlayer.setWaveform(liveWaveform)
                                livePlayer.setBitCrushDepth(Int(liveBitCrush))
                                livePlayer.setSampleRateHold(Int(liveSampleRateHold))
                                // Deep-hardening 2026-05-17: push the
                                // audiophile dynamics chain state on
                                // start so the engine matches the
                                // persisted UI values before the first
                                // sample renders.
                                livePlayer.setMasterVolumeDb(Float(liveMasterVolumeDb))
                                livePlayer.setLimiterEnabled(liveLimiterEnabled)
                                livePlayer.setHighPassCutoffHz(Float(liveHighPassCutoffHz))
                                livePlayerRunning = true
                                livePlayerStatus = nil
                            } catch {
                                livePlayerStatus = "Live player failed: \(error.localizedDescription)"
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

                if let livePlayerStatus {
                    // iter-37 hardening: previously the live-player
                    // error rendered as plain secondary-style description
                    // text, which a user scanning the page could miss.
                    // Surface with an exclamation glyph, orange tint, +
                    // a "Copy" affordance so the user can paste the
                    // underlying error into a bug report.
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 13))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(livePlayerStatus)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                            HStack(spacing: 6) {
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(livePlayerStatus, forType: .string)
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                .help("Copy error text to clipboard for bug reports")
                                .accessibilityLabel("Copy error to clipboard")
                                Button("Dismiss") {
                                    self.livePlayerStatus = nil
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                .help("Clear the error message")
                                .accessibilityLabel("Dismiss live player error")
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.orange.opacity(0.30), lineWidth: 0.5)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Live player error: \(livePlayerStatus)")
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
                    // iter-35 hardening: bring legacy slider a11y to parity
                    // with the iter-31 Dynamics Chain sliders. VoiceOver
                    // users now hear the actual Hz / pan-percent / gain
                    // value instead of the raw 0…1 slider position.
                    .accessibilityValue(formatFrequency(liveFrequencyHz))
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
                    .accessibilityValue(panLabel(for: livePan))
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
                    .accessibilityValue(String(format: "%.2f", liveGain))
                    // iter-38 clarity: the legacy "Gain" slider applies
                    // BEFORE pan + HPF + master volume — it's effectively
                    // a pre-pan input drive. The user-facing "Master
                    // volume" knob in the Dynamics Chain section is the
                    // final output level. Caption makes the chain order
                    // legible.
                    Text("Pre-pan input drive. The Master volume slider in the Dynamics Chain section below is the final output level.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Picker("Waveform", selection: $liveWaveformRaw) {
                    ForEach(AmbientFrequencyLivePlayer.Waveform.allCases) { waveform in
                        Text(waveform.label).tag(waveform.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: liveWaveformRaw) { _, _ in
                    if livePlayerRunning {
                        livePlayer.setWaveform(liveWaveform)
                    }
                }

                // ▓░ PIXEL CRUNCH ░▓ — bit-crush + sample-rate-reduce
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
                            if livePlayerRunning {
                                livePlayer.setBitCrushDepth(Int(liveBitCrush))
                            }
                        }
                        .accessibilityValue(bitDepthLabel(Int(liveBitCrush)))
                        Text("Quantize sample amplitude to N bits. 8 = Amiga/NES era. 4 = Atari 2600. 1 = PC speaker beeper. Per musicdsp.org #124.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                            if livePlayerRunning {
                                livePlayer.setSampleRateHold(Int(liveSampleRateHold))
                            }
                        }
                        .accessibilityValue("Divide by \(Int(liveSampleRateHold))")
                        Text("Zero-order hold: every Nth sample held. Aliasing IS the effect — defines the lo-fi vintage chip sound.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // ─── Audiophile dynamics chain ───
                // (master volume in dB · HPF · soft-clip limiter · VU meter)
                // Deep-hardening pass 2026-05-17: per user direction
                // ("true good high quality volume controls"), the live
                // player now ships a small mastering chain on top of
                // the legacy gain slider. Each stage is documented at
                // the engine: AmbientFrequencyLivePlayer.swift §
                // renderBlock steps 8-11 (HPF / master volume / soft-
                // clip / peak meter).
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tint)
                        Text("DYNAMICS CHAIN")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .tracking(2)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Master volume") {
                            Text(formatDb(liveMasterVolumeDb))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                                .monospacedDigit()
                        }
                        Slider(value: $liveMasterVolumeDb, in: -60...6, step: 0.5) {
                            Text("Master volume")
                        } minimumValueLabel: {
                            Text("-60 dB").font(.caption2.monospaced())
                        } maximumValueLabel: {
                            Text("+6 dB").font(.caption2.monospaced())
                        }
                        .onChange(of: liveMasterVolumeDb) { _, _ in
                            if livePlayerRunning {
                                livePlayer.setMasterVolumeDb(Float(liveMasterVolumeDb))
                            }
                        }
                        .accessibilityValue("\(formatDb(liveMasterVolumeDb))")
                        Text("Audiophile-grade master volume. Every -6 dB ≈ half perceived loudness. 0 dB = unity. Applied post-pan, post-pixel-crunch, pre-limiter.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $liveLimiterEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Soft-clip limiter")
                                    .font(.caption.weight(.semibold))
                                Text("Cubic soft-clip (musicdsp.org #79). Catches accidental gain spikes; transparent below ~0.7 magnitude.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: liveLimiterEnabled) { _, newValue in
                            if livePlayerRunning {
                                livePlayer.setLimiterEnabled(newValue)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("High-pass cutoff") {
                            Text(formatHighPass(liveHighPassCutoffHz))
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                                .monospacedDigit()
                        }
                        Slider(value: $liveHighPassCutoffHz, in: 0...200, step: 1) {
                            Text("High-pass cutoff")
                        } minimumValueLabel: {
                            Text("Off").font(.caption2.monospaced())
                        } maximumValueLabel: {
                            Text("200 Hz").font(.caption2.monospaced())
                        }
                        .onChange(of: liveHighPassCutoffHz) { _, _ in
                            if livePlayerRunning {
                                livePlayer.setHighPassCutoffHz(Float(liveHighPassCutoffHz))
                            }
                        }
                        Text("One-pole high-pass filter. 20 Hz default kills DC + sub-sonic rumble that pixel-crunch can introduce. Per musicdsp.org #117.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // VU-style peak meter — polled from
                    // `livePlayer.currentPeakLevel` at 30 Hz while the
                    // engine is running. Gives the user honest visual
                    // feedback on output level + clip warning.
                    //
                    // iter-36 (2026-05-17 deep-hardening): adds classic
                    // audiophile peak-hold behavior. A transient peak
                    // latches the `liveHeldPeak` indicator for 1.5 s,
                    // then linearly decays over 500 ms back to the live
                    // peak — so the eye can see a momentary spike that
                    // 30 Hz instant rendering would blink past.
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Output peak") {
                            HStack(spacing: 6) {
                                Text(formatPeak(liveDisplayedPeak))
                                    .foregroundStyle(peakColor(liveDisplayedPeak))
                                    .font(.system(.caption, design: .monospaced))
                                    .monospacedDigit()
                                Text("(hold \(formatPeak(liveHeldPeak)))")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption2.monospaced())
                                    .monospacedDigit()
                            }
                        }
                        if livePlayerRunning {
                            TimelineView(.periodic(from: .now, by: 1.0 / 30)) { context in
                                peakMeterBar(peak: livePlayer.currentPeakLevel, hold: liveHeldPeak)
                                    .onChange(of: livePlayer.currentPeakLevel) { _, newValue in
                                        liveDisplayedPeak = newValue
                                        updateHeldPeak(newValue: newValue, now: context.date)
                                    }
                            }
                        } else {
                            peakMeterBar(peak: 0, hold: 0)
                        }
                        Text("Block-peak meter with 1.5 s hold + 0.5 s decay (audiophile mastering convention). Green safe, amber loud, red clipping. Limiter on means red is rare even at +6 dB.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
        // UI/UX audit 2026-05-17 P1-3: don't leak the AVAudioEngine when the
        // user navigates away from this Settings tab. start()/stop() are
        // idempotent, so this is safe to call unconditionally.
        .onDisappear {
            livePlayer.stop()
            livePlayerRunning = false
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
            outputURL: outputURL,
            masterGainDb: exportMasterGainDb
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

    // MARK: - Dynamics-chain formatters (deep-hardening 2026-05-17)

    private func formatDb(_ db: Double) -> String {
        if db <= -60 {
            return "−∞ dB (mute)"
        }
        if abs(db) < 0.05 {
            return "0.0 dB (unity)"
        }
        let sign = db > 0 ? "+" : ""
        return String(format: "\(sign)%.1f dB", db)
    }

    private func formatHighPass(_ hz: Double) -> String {
        if hz <= 0 {
            return "Off"
        }
        return String(format: "%.0f Hz", hz)
    }

    private func formatPeak(_ peak: Float) -> String {
        if peak <= 0.00001 {
            return "−∞ dBFS"
        }
        let db = 20 * log10(peak)
        return String(format: "%.1f dBFS", db)
    }

    /// Peak-meter text color: green up to -12 dBFS (~0.25 linear),
    /// orange up to -3 dBFS (~0.71), red above (warning of clipping).
    private func peakColor(_ peak: Float) -> Color {
        switch peak {
        case ..<0.25: return .green
        case ..<0.71: return .orange
        default: return .red
        }
    }

    /// Compact horizontal peak bar — three-zone (green / orange / red)
    /// background with a fill width proportional to `peak`. Honors the
    /// same zone palette as `peakColor`. `hold` parameter (iter 36)
    /// draws a 1.5-pixel vertical "peak-hold" marker at the held peak
    /// position — classic audiophile-meter behavior so transient peaks
    /// are visible past the 30 Hz instant-rendering blink.
    @ViewBuilder
    private func peakMeterBar(peak: Float, hold: Float = 0) -> some View {
        GeometryReader { geo in
            let safeWidth = geo.size.width * 0.71
            let warnWidth = geo.size.width * (1 - 0.71)
            ZStack(alignment: .leading) {
                // Background zones
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: max(0, safeWidth - 0.35 * geo.size.width))
                    Rectangle()
                        .fill(Color.orange.opacity(0.22))
                        .frame(width: 0.35 * geo.size.width)
                    Rectangle()
                        .fill(Color.red.opacity(0.25))
                        .frame(width: warnWidth)
                }
                // Active fill
                Rectangle()
                    .fill(peakColor(peak))
                    .frame(width: max(0, min(1, CGFloat(peak))) * geo.size.width)
                    .animation(.linear(duration: 0.05), value: peak)
                // Peak-hold marker (1.5 px vertical bar at the held peak).
                if hold > 0.001 {
                    Rectangle()
                        .fill(peakColor(hold))
                        .frame(width: 1.5)
                        .offset(x: max(0, min(1, CGFloat(hold))) * geo.size.width - 0.75)
                        .animation(.linear(duration: 0.05), value: hold)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output peak meter")
        .accessibilityValue("Current \(formatPeak(peak)), peak-hold \(formatPeak(hold))")
    }

    /// Latch / decay the peak-hold marker (iter 36). Called from the
    /// 30 Hz TimelineView on every new sample-block peak. New peak
    /// >= held → latch + reset hold timestamp. Otherwise, after a
    /// `peakHoldSeconds` hold window, linearly decay over
    /// `peakDecaySeconds` toward the live peak.
    private func updateHeldPeak(newValue: Float, now: Date) {
        if newValue >= liveHeldPeak {
            liveHeldPeak = newValue
            liveHeldPeakSetAt = now
            return
        }
        let elapsed = now.timeIntervalSince(liveHeldPeakSetAt)
        if elapsed <= peakHoldSeconds {
            return  // still in hold window
        }
        // Decay phase: linearly interpolate held → newValue over
        // peakDecaySeconds.
        let decayProgress = min(1, (elapsed - peakHoldSeconds) / peakDecaySeconds)
        let target = newValue
        let initial = liveHeldPeak
        let decayed = initial + (target - initial) * Float(decayProgress)
        liveHeldPeak = decayed
        if decayProgress >= 1 {
            liveHeldPeakSetAt = now
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
}
