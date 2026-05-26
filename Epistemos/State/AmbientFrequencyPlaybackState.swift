import Foundation
import Observation

enum AmbientFrequencyPlaybackMode: String, Sendable {
    case activeMix
    case toneLab

    var label: String {
        switch self {
        case .activeMix: return "active mix"
        case .toneLab: return "tone lab"
        }
    }
}

struct AmbientFrequencyPlaybackRequest: Equatable, Sendable {
    var title: String
    var mode: AmbientFrequencyPlaybackMode
    var layers: [AmbientFrequencyLayer]
    var controls: [AmbientFrequencyLayerMixControl]
    var frequencyHz: Float
    var pan: Double
    var gain: Double
    var waveform: AmbientFrequencyLivePlayer.Waveform
    var bitCrushDepth: Int
    var sampleRateHold: Int
}

@MainActor
@Observable
final class AmbientFrequencyPlaybackState {
    @ObservationIgnored private let player = AmbientFrequencyLivePlayer()

    private(set) var isRunning = false
    private(set) var status: String?
    private(set) var title = "Ambient Frequencies"
    private(set) var subtitle = "idle"
    private(set) var mode: AmbientFrequencyPlaybackMode = .activeMix
    private(set) var layerCount = 0

    var landingMediaTitle: String {
        title.isEmpty ? "Ambient Frequencies" : title
    }

    var landingMediaSubtitle: String {
        isRunning ? subtitle : "idle"
    }

    func start(_ request: AmbientFrequencyPlaybackRequest) {
        if isRunning {
            player.stop()
            isRunning = false
        }

        updateDisplay(from: request)

        do {
            if request.mode == .toneLab {
                try player.start()
            } else {
                try player.start(
                    layers: request.layers,
                    controls: request.controls
                )
            }
            applyTargets(from: request)
            isRunning = true
            status = nil
        } catch {
            isRunning = false
            status = "Live player failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        player.stop()
        isRunning = false
        status = nil
        subtitle = "idle"
    }

    func restartIfRunning(_ request: AmbientFrequencyPlaybackRequest) {
        guard isRunning else { return }
        start(request)
    }

    func applyTargets(from request: AmbientFrequencyPlaybackRequest) {
        updateDisplay(from: request)
        player.setFrequency(request.frequencyHz)
        player.setPan(Float(request.pan))
        player.setGain(Float(request.gain))
        player.setWaveform(request.waveform)
        player.setBitCrushDepth(request.bitCrushDepth)
        player.setSampleRateHold(request.sampleRateHold)
        if request.mode == .activeMix {
            player.setLayerControls(request.controls)
        }
    }

    func setGain(_ gain: Double) {
        player.setGain(Float(gain))
    }

    func setPan(_ pan: Double) {
        player.setPan(Float(pan))
    }

    func setFrequency(_ frequencyHz: Float) {
        player.setFrequency(frequencyHz)
    }

    func setWaveform(_ waveform: AmbientFrequencyLivePlayer.Waveform) {
        player.setWaveform(waveform)
    }

    func setBitCrushDepth(_ bitDepth: Int) {
        player.setBitCrushDepth(bitDepth)
    }

    func setSampleRateHold(_ hold: Int) {
        player.setSampleRateHold(hold)
    }

    func setLayerControl(index: Int, control: AmbientFrequencyLayerMixControl) {
        player.setLayerControl(index: index, control: control)
    }

    func setLayerControls(_ controls: [AmbientFrequencyLayerMixControl]) {
        player.setLayerControls(controls)
    }

    private func updateDisplay(from request: AmbientFrequencyPlaybackRequest) {
        title = request.title
        mode = request.mode
        layerCount = request.layers.count
        switch request.mode {
        case .activeMix:
            subtitle = "\(request.mode.label) • \(request.layers.count) sounds"
        case .toneLab:
            subtitle = "\(request.mode.label) • \(formatFrequency(request.frequencyHz))"
        }
    }

    private func formatFrequency(_ hz: Float) -> String {
        if hz >= 1000 {
            return String(format: "%.2f kHz", hz / 1000)
        }
        return String(format: "%.1f Hz", hz)
    }
}
