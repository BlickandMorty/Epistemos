import Foundation
import os

// MARK: - SOAR State
// Observable state for SOAR (Stepping On A Rock) engine UI.
// Config is persisted to UserDefaults so settings survive app restarts.

private let log = Logger(subsystem: "com.epistemos", category: "SOARState")

@MainActor @Observable
final class SOARState {
    var soarConfig: SOARConfig = .default {
        didSet { persistConfig() }
    }
    var currentSession: SOARSession?
    var isAtEdge: Bool = false
    var status: SOARSessionStatus = .probing
    var iterationsCompleted: Int = 0

    private static let configKey = "epistemos.soar.config"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.configKey),
           let saved = try? JSONDecoder().decode(SOARConfig.self, from: data) {
            soarConfig = saved
            log.info("Restored SOAR config (enabled: \(saved.enabled))")
        }
    }

    func updateConfig(_ config: SOARConfig) {
        soarConfig = config
    }

    func setSession(_ session: SOARSession) {
        currentSession = session
    }

    func setAtEdge(_ atEdge: Bool) {
        isAtEdge = atEdge
    }

    func setStatus(_ status: SOARSessionStatus) {
        self.status = status
    }

    func setIterationsCompleted(_ count: Int) {
        iterationsCompleted = count
    }

    func reset() {
        currentSession = nil
        isAtEdge = false
        status = .probing
        iterationsCompleted = 0
    }

    private func persistConfig() {
        if let data = try? JSONEncoder().encode(soarConfig) {
            UserDefaults.standard.set(data, forKey: Self.configKey)
        }
    }
}
