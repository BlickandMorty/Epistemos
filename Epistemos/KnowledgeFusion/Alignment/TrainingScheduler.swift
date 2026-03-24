import Foundation
import AppKit
import IOKit.ps

// MARK: - TrainingScheduler

/// Unified scheduling authority for all Knowledge Fusion training activities.
/// Training runs ONLY during idle/overnight periods — NEVER blocking the typing path.
///
/// Per ANCHOR 1 Subsystem 4 and Epistemos audit patterns:
/// - Uses NSBackgroundActivityScheduler with 24-hour interval
/// - Checks CGEventSourceSecondsSinceLastEventType > 1800 (30 min idle)
/// - Defers if battery powered and < 80%
/// - Maximum 1 concurrent training job
@MainActor @Observable
final class TrainingScheduler {

    // MARK: - State

    var isTrainingActive = false
    var lastKTORunDate: Date? {
        get { UserDefaults.standard.object(forKey: "KnowledgeFusion.lastKTORunDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "KnowledgeFusion.lastKTORunDate") }
    }
    var lastVaultTrainingDate: Date? {
        get { UserDefaults.standard.object(forKey: "KnowledgeFusion.lastVaultTrainingDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "KnowledgeFusion.lastVaultTrainingDate") }
    }

    private var ktoScheduler: NSBackgroundActivityScheduler?
    private var vaultScheduler: NSBackgroundActivityScheduler?

    // MARK: - Scheduling

    func startScheduling() {
        // KTO preference alignment: nightly
        let kto = NSBackgroundActivityScheduler(identifier: "com.epistemos.kto-training")
        kto.interval = 86400  // 24 hours
        kto.repeats = true
        kto.qualityOfService = .background
        kto.schedule { [weak self] completion in
            guard let self else {
                completion(.finished)
                return
            }
            Task { @MainActor in
                if self.shouldRunTraining() {
                    await self.onKTOSchedulerFired()
                }
                completion(.finished)
            }
        }
        ktoScheduler = kto

        // Vault re-training: weekly
        let vault = NSBackgroundActivityScheduler(identifier: "com.epistemos.vault-training")
        vault.interval = 604800  // 7 days
        vault.repeats = true
        vault.qualityOfService = .background
        vault.schedule { [weak self] completion in
            guard let self else {
                completion(.finished)
                return
            }
            Task { @MainActor in
                if self.shouldRunTraining() {
                    await self.onVaultSchedulerFired()
                }
                completion(.finished)
            }
        }
        vaultScheduler = vault
    }

    func stopScheduling() {
        ktoScheduler?.invalidate()
        vaultScheduler?.invalidate()
        ktoScheduler = nil
        vaultScheduler = nil
    }

    // MARK: - Condition Checks

    /// Returns true if system conditions are met for training.
    func shouldRunTraining() -> Bool {
        // Rule 1: No concurrent training
        guard !isTrainingActive else { return false }

        // Rule 2: System must be idle > 30 minutes
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        guard idleSeconds > 1800 else { return false }

        // Rule 3: Check power state
        if !isPluggedIn() && batteryLevel() < 80 {
            return false
        }

        return true
    }

    /// Returns true if extended idle conditions are met (for autoresearch).
    func shouldRunAutoresearch() -> Bool {
        guard shouldRunTraining() else { return false }

        // Autoresearch needs >60 minutes idle
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        return idleSeconds > 3600
    }

    // MARK: - Callbacks (override in integration)

    private func onKTOSchedulerFired() async {
        // Placeholder — wired in Phase 7 UI integration
        lastKTORunDate = Date()
    }

    private func onVaultSchedulerFired() async {
        // Placeholder — wired in Phase 7 UI integration
        lastVaultTrainingDate = Date()
    }

    // MARK: - Power Helpers

    private func isPluggedIn() -> Bool {
        // Use IOKit power source info
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] ?? []
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                if let powerSource = desc[kIOPSPowerSourceStateKey as String] as? String {
                    return powerSource == kIOPSACPowerValue as String
                }
            }
        }
        return true  // Default to true if can't determine
    }

    private func batteryLevel() -> Int {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] ?? []
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                if let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int {
                    return capacity
                }
            }
        }
        return 100  // Default to full if can't determine
    }
}
