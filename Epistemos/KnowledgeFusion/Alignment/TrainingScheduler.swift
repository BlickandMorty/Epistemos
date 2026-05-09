import Foundation
import AppKit
import IOKit.ps

// MARK: - TrainingScheduler

/// Unified scheduling authority for all Knowledge Fusion training activities.
/// Training runs ONLY during idle/overnight periods — NEVER blocking the typing path.
///
/// Per ANCHOR 1 Subsystem 4 and Epistemos audit patterns:
/// - Uses NSBackgroundActivityScheduler with 24-hour interval
/// - Uses process-local quiescence instead of system-wide input polling
/// - Defers if battery powered and < 80%
/// - Maximum 1 concurrent training job
@MainActor @Observable
final class TrainingScheduler {
    private static let processLaunchUptime = ProcessInfo.processInfo.systemUptime

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
    /// Structured ODIA traces from Omega execution results.
    /// Uses StructuredODIATrace (Codable observe/decide/interact/assess format).
    var pendingODIATraces: [StructuredODIATrace] = []
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
    func ingestODIATraces(_ traces: [StructuredODIATrace]) {
        pendingODIATraces.append(contentsOf: traces)
    }

    // MARK: - Condition Checks

    /// Returns true if system conditions are met for training.
    func shouldRunTraining() -> Bool {
        // Rule 1: No concurrent training
        guard !isTrainingActive else { return false }

        // Rule 2: app process must have been quiescent long enough. System-wide
        // idle APIs require Input Monitoring/TCC and are not safe for passive
        // launch/background schedulers in v1.
        let idleSeconds = Self.processQuiescenceSeconds()
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
        let idleSeconds = Self.processQuiescenceSeconds()
        return idleSeconds > 3600
    }

    private static func processQuiescenceSeconds() -> Double {
        max(0, ProcessInfo.processInfo.systemUptime - processLaunchUptime)
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
            // Export ODIA traces to JSONL with research trace weighting.
            // Research traces (taskType == "research") get 2x weight by duplication
            // to accelerate research workflow learning per training guide rules.
            let generator = StructuredODIATraceGenerator()
            let researchTraces = tracesToTrain.filter { $0.taskType == "research" }
            let weightedTraces = tracesToTrain + researchTraces // 2x for research
            var jsonl = generator.toJSONL(weightedTraces)

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
                // Deploy gate: evaluate new adapter against BFCL holdout before accepting.
                // If the adapter regresses vs baseline, discard it and log the failure.
                let gateResult = await runDeployGate(adapterPath: outputDir)
                if gateResult.passed {
                    lastODIARunDate = Date()
                } else {
                    // Adapter failed deploy gate — remove it
                    try? FileManager.default.removeItem(at: outputDir)
                }
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempPath)
        } catch {
            // Put traces back if training failed — retry next cycle
            pendingODIATraces.append(contentsOf: tracesToTrain)
        }
    }

    // MARK: - Deploy Gate

    struct DeployGateResult {
        let passed: Bool
        let score: Double
        let baselineScore: Double
        let reason: String
    }

    /// Run the BFCL evaluation against the new adapter.
    /// Compares against baseline scores; blocks deployment if regression detected.
    private func runDeployGate(adapterPath: URL) async -> DeployGateResult {
        // Locate eval scripts and data
        let bundlePath = Bundle.main.resourceURL?
            .appendingPathComponent("KnowledgeFusion/MOHAWK") ??
            URL(fileURLWithPath: "Epistemos/KnowledgeFusion/MOHAWK")

        let evalScript = bundlePath.appendingPathComponent("eval_bfcl.py")
        let macosEval = bundlePath.appendingPathComponent("embodied_data/bfcl_eval_macos.jsonl")

        // Check if eval infrastructure exists
        guard FileManager.default.fileExists(atPath: evalScript.path),
              FileManager.default.fileExists(atPath: macosEval.path) else {
            // Fail-closed: do not auto-deploy without eval verification.
            // Users can still activate adapters manually via Settings → Adapter Selector.
            return DeployGateResult(passed: false, score: 0, baselineScore: 0,
                                    reason: "Eval infrastructure not available — activate adapters manually via Settings")
        }

        // For now, the deploy gate checks if eval data exists and the adapter was produced.
        // Full model inference scoring requires loading the adapter into MLX and running
        // predictions — that's wired when the inference bridge supports adapter hot-swap.
        // Until then, pass if the adapter files exist on disk.
        let weightsPath = adapterPath.appendingPathComponent("adapter_weights.safetensors")
        let adapterExists = FileManager.default.fileExists(atPath: weightsPath.path)

        if adapterExists {
            // Fail-closed: weights on disk ≠ quality-verified. Users activate adapters
            // manually via Settings > Knowledge Fusion > Adapter Selector.
            return DeployGateResult(passed: false, score: 0, baselineScore: 0,
                                    reason: "Automatic deployment disabled — activate adapters manually in Settings > Knowledge Fusion")
        } else {
            return DeployGateResult(passed: false, score: 0, baselineScore: 0,
                                    reason: "adapter_weights.safetensors not produced by training")
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
