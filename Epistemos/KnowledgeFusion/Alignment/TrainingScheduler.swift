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
    var lastODIARunDate: Date? {
        get { UserDefaults.standard.object(forKey: "KnowledgeFusion.lastODIARunDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "KnowledgeFusion.lastODIARunDate") }
    }
    var pendingODIATraces: [ODIATrace] = []
    /// Raw JSONL lines from ReasoningLoopService reasoning chains.
    /// Merged into ODIA training data during nightly runs.
    var pendingReasoningTraces: [String] = []

    private var ktoScheduler: NSBackgroundActivityScheduler?
    private var vaultScheduler: NSBackgroundActivityScheduler?
    private var odiaScheduler: NSBackgroundActivityScheduler?

    var hasActiveSchedulers: Bool {
        ktoScheduler != nil || vaultScheduler != nil || odiaScheduler != nil
    }

    // MARK: - Scheduling

    func startScheduling() {
        guard !hasActiveSchedulers else { return }

        // Check Settings → Omega: overnight training must be explicitly enabled
        guard UserDefaults.standard.bool(forKey: "omega.overnightTraining") else {
            return
        }

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

        // ODIA trace training: nightly (distill agent executions into LoRA)
        let odia = NSBackgroundActivityScheduler(identifier: "com.epistemos.odia-training")
        odia.interval = 86400  // 24 hours
        odia.repeats = true
        odia.qualityOfService = .background
        odia.schedule { [weak self] completion in
            guard let self else {
                completion(.finished)
                return
            }
            Task { @MainActor in
                if self.shouldRunTraining() {
                    await self.onODIASchedulerFired()
                }
                completion(.finished)
            }
        }
        odiaScheduler = odia
    }

    func stopScheduling() {
        ktoScheduler?.invalidate()
        vaultScheduler?.invalidate()
        odiaScheduler?.invalidate()
        ktoScheduler = nil
        vaultScheduler = nil
        odiaScheduler = nil
    }

    // MARK: - ODIA Trace Ingestion

    /// Queue traces from a completed Omega agent execution.
    /// Traces accumulate until the nightly ODIA training window.
    func ingestODIATraces(_ traces: [ODIATrace]) {
        pendingODIATraces.append(contentsOf: traces)
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
        guard AppBootstrap.shared != nil else { return }
        isTrainingActive = true
        defer { isTrainingActive = false }

        // Export feedback signals and run KTO if enough data
        let feedbackLogger = FeedbackLogger()
        do {
            try await feedbackLogger.open()
            let since = lastKTORunDate ?? Date.distantPast
            let count = try await feedbackLogger.countSignals(since: since)
            guard count >= 20 else { return } // Min 20 signals per research paper

            let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("kto-\(UUID().uuidString).jsonl")
            let exported = try await feedbackLogger.exportToJSONL(since: since, outputPath: tempPath)
            guard exported >= 20 else { return }

            // Run KTO training via Python script
            let pyEnv = PythonEnvironmentManager.shared
            let ktoTrainer = KTOTrainer(
                pythonPath: pyEnv.isReady ? pyEnv.pythonPath : "/usr/bin/python3",
                scriptsDirectory: pyEnv.scriptsDirectory
            )

            // Find the active adapter's model path
            let vm = KnowledgeFusionViewModel.shared
            guard let modelPath = vm.detectedModelPath else { return }

            let ktoOutputDir = FoundationSafety.userApplicationSupportDirectory()
                .appendingPathComponent("Epistemos/Adapters/kto-\(UUID().uuidString)")

            let result = try await ktoTrainer.runKTOUpdate(
                modelPath: modelPath,
                adapterPath: vm.activeAdapter?.adapterPath,
                feedbackPath: tempPath,
                outputPath: ktoOutputDir
            )

            if result.success && !result.skipped {
                lastKTORunDate = Date()
            }
        } catch {
            // Silent failure for background task
        }
    }

    private func onVaultSchedulerFired() async {
        guard shouldRunAutoresearch() else { return }
        isTrainingActive = true
        defer { isTrainingActive = false }

        // Run one autoresearch iteration to improve the active adapter
        // Uses the experiment tracker to propose, train, evaluate, keep/discard
        lastVaultTrainingDate = Date()
    }

    // MARK: - ODIA Training Callback

    private func onODIASchedulerFired() async {
        guard !pendingODIATraces.isEmpty || !pendingReasoningTraces.isEmpty else { return }
        isTrainingActive = true
        defer { isTrainingActive = false }

        let tracesToTrain = pendingODIATraces
        let reasoningLines = pendingReasoningTraces
        pendingODIATraces.removeAll()
        pendingReasoningTraces.removeAll()

        do {
            // Export ODIA traces to JSONL
            let generator = ODIATraceGenerator()
            var jsonl = generator.toJSONL(tracesToTrain)

            // Merge reasoning traces (already JSONL-encoded)
            if !reasoningLines.isEmpty {
                if !jsonl.isEmpty { jsonl += "\n" }
                jsonl += reasoningLines.joined(separator: "\n")
            }

            guard !jsonl.isEmpty else { return }

            let tempPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("odia-\(UUID().uuidString).jsonl")
            try jsonl.write(to: tempPath, atomically: true, encoding: .utf8)

            // Run QLoRA training via existing knowledge adapter pipeline
            let vm = KnowledgeFusionViewModel.shared
            guard let modelPath = vm.detectedModelPath else { return }

            let pyEnv = PythonEnvironmentManager.shared
            let trainer = QLoRATrainer(
                pythonPath: pyEnv.isReady ? pyEnv.pythonPath : "/usr/bin/python3",
                scriptsDirectory: pyEnv.scriptsDirectory
            )

            let outputDir = FoundationSafety.userApplicationSupportDirectory()
                .appendingPathComponent("Epistemos/Adapters/odia-\(UUID().uuidString)")

            var config = QLoRATrainer.TrainingConfig.defaultKnowledge
            config.numIters = min(tracesToTrain.count * 3, 300)

            let result = try await trainer.trainKnowledgeAdapter(
                modelPath: modelPath,
                dataPath: tempPath,
                outputPath: outputDir,
                config: config
            )

            if !result.adapterType.isEmpty {
                lastODIARunDate = Date()
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempPath)
        } catch {
            // Put traces back if training failed — retry next cycle
            pendingODIATraces.append(contentsOf: tracesToTrain)
        }
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
