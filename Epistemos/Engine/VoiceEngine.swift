import Foundation
import os

// MARK: - VoiceEngine
// Swift wrapper for Chatterbox TTS Python daemon subprocess.
// Phase 8 scaffold — actual Python daemon integration comes later.

@MainActor @Observable
final class VoiceEngine {

    // MARK: - Voice Config

    struct VoiceConfig: Sendable, Codable {
        let agentId: String
        var referenceAudioPath: String?
        var enabled: Bool

        static func defaultConfig(for agent: AgentID) -> VoiceConfig {
            VoiceConfig(agentId: agent.rawValue, referenceAudioPath: nil, enabled: false)
        }
    }

    // MARK: - State

    enum EngineState: Equatable, Sendable {
        case stopped
        case starting
        case ready
        case speaking(agentId: String)
        case error(String)
    }

    private(set) var state: EngineState = .stopped
    private(set) var voiceConfigs: [AgentID: VoiceConfig] = [:]
    var readModeEnabled = false

    // MARK: - Init

    init() {
        for agent in AgentID.allCases {
            voiceConfigs[agent] = .defaultConfig(for: agent)
        }
    }

    // MARK: - Lifecycle

    func start() async {
        guard state == .stopped else { return }
        state = .starting

        // Phase 8 scaffold — Python daemon launch goes here.
        // Requires bundled Python + Chatterbox Turbo model.
        state = .ready
        Log.engine.info("VoiceEngine: ready (scaffold mode)")
    }

    func stop() {
        state = .stopped
        Log.engine.info("VoiceEngine: stopped")
    }

    // MARK: - TTS

    func speak(_ text: String, as agent: AgentID) async {
        guard state == .ready else { return }
        guard voiceConfigs[agent]?.enabled == true else { return }

        state = .speaking(agentId: agent.rawValue)

        // Phase 8 scaffold — sends JSON to Python daemon, receives WAV, plays via AVAudioEngine.
        Log.engine.debug("VoiceEngine: would speak as \(agent.rawValue): \(text.prefix(60))")

        state = .ready
    }

    // MARK: - Voice Config

    func setVoiceEnabled(_ enabled: Bool, for agent: AgentID) {
        voiceConfigs[agent]?.enabled = enabled
    }

    func setReferenceAudio(_ path: String?, for agent: AgentID) {
        voiceConfigs[agent]?.referenceAudioPath = path
    }

    var isReady: Bool { state == .ready }
}
