import Foundation
import SwiftUI

// MARK: - Types

enum KFTrainingState: String, Sendable {
    case idle
    case parsing = "Parsing vault..."
    case generating = "Generating training data..."
    case training = "Training adapter..."
    case evaluating = "Evaluating..."
    case complete = "Complete"
    case error = "Error"
}

struct KFProgress: Sendable {
    let phase: String
    let percentage: Double
    let eta: TimeInterval?
}

// MARK: - KnowledgeFusionViewModel

/// @Observable state class bridging all Phase 1-6 actors to SwiftUI.
/// Follows Epistemos pattern: @MainActor @Observable (never the legacy observable-object protocol).
@MainActor @Observable
final class KnowledgeFusionViewModel {

    /// Shared instance so training persists across view navigation.
    static let shared = KnowledgeFusionViewModel()

    // MARK: - Published State

    var trainingState: KFTrainingState = .idle
    var progress: KFProgress = KFProgress(phase: "", percentage: 0, eta: nil)
    var installedAdapters: [AdapterRecord] = []
    var activeAdapter: AdapterRecord?
    var lastTrainingError: String?
    var feedbackStats: FeedbackLogger.FeedbackStats?
    var autoresearchRunning = false
    var lastExperimentResult: ExperimentResult?

    /// The inference provider used for synthetic data generation.
    /// Set via `configure(mlxClient:)` after bootstrap.
    var inferenceProvider: KFInferenceProvider?

    /// Persistent training task that survives view destruction.
    /// Uses a detached task so navigating away from settings doesn't cancel training.
    private var trainingTask: Task<Void, Never>?

    /// All installed models available for training.
    var availableModels: [(name: String, path: URL)] = []
    /// Currently selected model for training.
    var selectedModelIndex: Int = 0

    // MARK: - Training Configuration (user-adjustable)

    /// Detected unified memory in GB.
    let systemMemoryGB: Int = {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
    }()

    /// Training iterations. More = better quality but slower. 100-1000 typical.
    var trainingIterations: Int = 200
    /// LoRA rank. Higher = more capacity but more memory. 8 for style, 16-32 for knowledge.
    var loraRank: Int = 16
    /// LoRA alpha. Usually 2x rank. Controls learning magnitude.
    var loraAlpha: Int = 32
    /// Batch size. 1 for 16GB, 2 for 32GB, 4 for 64GB+.
    var batchSize: Int = 1
    /// Max sequence length. 512-2048. Lower = less memory.
    var maxSeqLength: Int = 1024
    /// Learning rate. 1e-5 for style, 2e-5 for knowledge.
    var learningRate: Double = 2e-5

    /// Auto-configure based on system memory.
    /// LoRA rank is ALWAYS 16 for Nano tier (training non-negotiable).
    /// Rank 32 is reserved for Base tier (3B) when that path is enabled.
    /// Higher memory → larger batch/seq, NOT higher rank.
    func autoConfigureForHardware() {
        if systemMemoryGB >= 64 {
            batchSize = 4; maxSeqLength = 2048; loraRank = 16; loraAlpha = 32
            trainingIterations = 500
        } else if systemMemoryGB >= 32 {
            batchSize = 2; maxSeqLength = 2048; loraRank = 16; loraAlpha = 32
            trainingIterations = 300
        } else if systemMemoryGB >= 24 {
            batchSize = 2; maxSeqLength = 1024; loraRank = 16; loraAlpha = 32
            trainingIterations = 200
        } else {
            batchSize = 1; maxSeqLength = 1024; loraRank = 16; loraAlpha = 32
            trainingIterations = 200
        }
    }

    var detectedModelPath: URL? {
        guard !availableModels.isEmpty, selectedModelIndex < availableModels.count else { return nil }
        return availableModels[selectedModelIndex].path
    }
    var detectedModelName: String? {
        guard !availableModels.isEmpty, selectedModelIndex < availableModels.count else { return nil }
        return availableModels[selectedModelIndex].name
    }

    /// Last vault analysis result (shown in UI).
    var lastVaultAnalysis: VaultAnalysis?

    /// Apply settings from vault analysis.
    func applyVaultAnalysis(_ analysis: VaultAnalysis) {
        loraRank = analysis.recommendedRank
        loraAlpha = analysis.recommendedAlpha
        trainingIterations = analysis.recommendedIterations
        maxSeqLength = analysis.recommendedSeqLen
        learningRate = analysis.recommendedProfile == .style ? 1e-5 : 2e-5
        lastVaultAnalysis = analysis
    }

    // MARK: - Dependencies

    private let registry: AdapterRegistry
    private let loader: AdapterLoader
    private let router: AdapterRouter
    private let feedbackLogger: FeedbackLogger
    private let scheduler: TrainingScheduler

    init(
        registry: AdapterRegistry = AdapterRegistry(),
        loader: AdapterLoader = AdapterLoader(),
        router: AdapterRouter = AdapterRouter(),
        feedbackLogger: FeedbackLogger = FeedbackLogger(),
        scheduler: TrainingScheduler = TrainingScheduler()
    ) {
        self.registry = registry
        self.loader = loader
        self.router = router
        self.feedbackLogger = feedbackLogger
        self.scheduler = scheduler
    }

    /// Connect the live inference engine for synthetic data generation.
    func configure(triageService: TriageService) {
        self.inferenceProvider = MLXInferenceBridge(triageService: triageService)
    }

    /// Ingest reasoning trace JSONL lines for nightly training.
    func ingestReasoningTraces(_ jsonlLines: [String]) {
        scheduler.pendingReasoningTraces.append(contentsOf: jsonlLines)
    }

    /// Ingest structured ODIA traces for nightly training.
    /// Called by OrchestratorState after each task execution completes.
    func ingestODIATraces(_ traces: [StructuredODIATrace]) {
        scheduler.ingestODIATraces(traces)
    }

    // MARK: - Lifecycle

    func loadState() async {
        do {
            try await registry.load()
            installedAdapters = await registry.listAdapters()
            activeAdapter = await registry.getActiveAdapters().first

            try await feedbackLogger.open()
            feedbackStats = try await feedbackLogger.stats()
        } catch {
            lastTrainingError = error.localizedDescription
        }

        // Detect installed models for training
        detectInstalledModels()

        // Start the overnight training scheduler if the setting is enabled (Ω16)
        scheduler.startScheduling()
    }

    private func detectInstalledModels() {
        let modelBase = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos/Models/text/active")
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: modelBase, includingPropertiesForKeys: nil) else { return }
        availableModels = contents
            .filter { $0.hasDirectoryPath }
            .map { (name: $0.lastPathComponent, path: $0) }
            .sorted { $0.name < $1.name }
        if !availableModels.isEmpty {
            selectedModelIndex = 0
        }
    }

    // MARK: - Train on Vault (Persistent)

    /// Launches training in a detached task that survives view navigation.
    /// Call this instead of `trainOnVault` directly from views.
    func startTrainingOnVault(vaultURL: URL, modelPath: URL, inferenceProvider: KFInferenceProvider) {
        guard trainingState == .idle else { return }
        trainingTask?.cancel()
        trainingTask = Task.detached { [weak self] in
            await self?.trainOnVault(
                vaultURL: vaultURL,
                modelPath: modelPath,
                inferenceProvider: inferenceProvider
            )
        }
    }

    func trainOnVault(
        vaultURL: URL,
        modelPath: URL,
        inferenceProvider: KFInferenceProvider
    ) async {
        guard trainingState == .idle else { return }
        lastTrainingError = nil

        do {
            // Phase 1: Parse
            trainingState = .parsing
            progress = KFProgress(phase: "Parsing notes...", percentage: 0.05, eta: nil)

            let parser = VaultParser()
            let parseResult = await parser.parseVault(at: vaultURL)

            let chunker = DocumentChunker()
            let chunks = chunker.chunkAll(documents: parseResult.documents)

            guard !chunks.isEmpty else {
                lastTrainingError = "No text content found in vault (\(parseResult.parsedItems) files parsed, \(parseResult.errors.count) errors)"
                trainingState = .error
                return
            }

            // Phase 2: Generate synthetic data
            trainingState = .generating
            progress = KFProgress(phase: "Generating training data from \(chunks.count) chunks (\(parseResult.parsedItems) notes)...", percentage: 0.10, eta: nil)
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("kf-training-\(UUID().uuidString)")
            let generator = SyntheticDataGenerator(
                inferenceProvider: inferenceProvider,
                outputDirectory: outputDir
            )

            let synthResult = try await generator.generate(chunks: chunks) { [weak self] synthProgress in
                Task { @MainActor in
                    self?.progress = KFProgress(
                        phase: synthProgress.phase.rawValue,
                        percentage: 0.1 + synthProgress.fractionComplete * 0.4,
                        eta: nil
                    )
                }
            }

            guard synthResult.totalAccepted > 0 else {
                lastTrainingError = "Generated \(synthResult.totalGenerated) pairs but \(synthResult.totalAccepted) passed quality filter (threshold: 3/5). Discarded: \(synthResult.totalDiscarded). Try a vault with more detailed notes (500+ words per note)."
                trainingState = .error
                return
            }

            // Phase 3: Train
            trainingState = .training
            progress = KFProgress(phase: "Training adapter...", percentage: 0.55, eta: nil)

            let profileManager = TrainingProfileManager()
            let recommendation = try profileManager.recommend(
                knowledgePath: synthResult.trainingFiles[.knowledge],
                stylePath: synthResult.trainingFiles[.style],
                toolPath: synthResult.trainingFiles[.tool]
            )

            // Prefer the composed, IFD-filtered, CAMPUS-sorted training file if it exists.
            // Falls back to the first available raw synthesis output otherwise.
            let composedPath = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("Epistemos/KnowledgeFusion/MOHAWK/composed_training_data/train_final.jsonl")
            let dataURL: URL
            if FileManager.default.fileExists(atPath: composedPath.path) {
                dataURL = composedPath
            } else if let (_, firstFile) = synthResult.trainingFiles.first {
                dataURL = firstFile
            } else {
                lastTrainingError = "No training data files produced"
                trainingState = .error
                return
            }

            let adapterOutputDir = FoundationSafety.userApplicationSupportDirectory()
                .appendingPathComponent("Epistemos/Adapters/\(UUID().uuidString)")

            // Deploy scripts if needed (idempotent)
            let pyEnv = PythonEnvironmentManager.shared
            try? pyEnv.deployScripts()

            // Prepare experience replay buffer (10% general data to prevent catastrophic forgetting)
            let replayPath = FoundationSafety.userApplicationSupportDirectory()
                .appendingPathComponent("Epistemos/replay-buffer/general.jsonl")
            var replayDataPath: URL? = nil
            if FileManager.default.fileExists(atPath: replayPath.path) {
                replayDataPath = replayPath
            }

            let trainer = QLoRATrainer(
                pythonPath: pyEnv.isReady ? pyEnv.pythonPath : "/usr/bin/python3",
                scriptsDirectory: pyEnv.scriptsDirectory
            )

            let config = QLoRATrainer.TrainingConfig(
                numIters: trainingIterations,
                loraRank: loraRank,
                loraAlpha: loraAlpha,
                batchSize: batchSize,
                maxSeqLen: maxSeqLength,
                learningRate: learningRate
            )

            let metadata: AdapterMetadata
            switch recommendation.profile {
            case .knowledge, .mixed:
                metadata = try await trainer.trainKnowledgeAdapter(
                    modelPath: modelPath,
                    dataPath: dataURL,
                    outputPath: adapterOutputDir,
                    replayPath: replayDataPath,
                    config: config
                ) { [weak self] tp in
                    Task { @MainActor in
                        let pct = 0.55 + Double(tp.iteration) / Double(tp.totalIterations) * 0.35
                        self?.progress = KFProgress(
                            phase: "Training... (iter \(tp.iteration)/\(tp.totalIterations), loss: \(String(format: "%.3f", tp.loss)))",
                            percentage: pct,
                            eta: tp.estimatedTimeRemaining
                        )
                    }
                }
            case .style:
                metadata = try await trainer.trainStyleAdapter(
                    modelPath: modelPath,
                    dataPath: dataURL,
                    outputPath: adapterOutputDir,
                    replayPath: replayDataPath,
                    config: config
                ) { [weak self] tp in
                    Task { @MainActor in
                        let pct = 0.55 + Double(tp.iteration) / Double(tp.totalIterations) * 0.35
                        self?.progress = KFProgress(
                            phase: "Training... (iter \(tp.iteration)/\(tp.totalIterations), loss: \(String(format: "%.3f", tp.loss)))",
                            percentage: pct,
                            eta: tp.estimatedTimeRemaining
                        )
                    }
                }
            }

            // Phase 4: Register
            trainingState = .evaluating
            progress = KFProgress(phase: "Registering adapter...", percentage: 0.95, eta: nil)

            let record = AdapterRecord(
                id: UUID(),
                name: "\(vaultURL.lastPathComponent) — \(Date().formatted(date: .abbreviated, time: .omitted))",
                type: AdapterType(rawValue: metadata.adapterType) ?? .knowledge,
                adapterPath: adapterOutputDir,
                metadataPath: adapterOutputDir.appendingPathComponent("training_metadata.json"),
                sourceVault: vaultURL.lastPathComponent,
                createdAt: Date(),
                qualityScore: nil,
                isActive: false,
                baseModel: metadata.baseModel,
                loraRank: metadata.loraRank,
                parameterCount: metadata.loraRank * 4096 * metadata.targetModules.count * 2,
                trainingExamples: metadata.numExamples
            )

            try await registry.register(record)

            // Auto-activate the newly trained adapter so it's immediately in use
            try await registry.setActive(record.id, active: true)
            installedAdapters = await registry.listAdapters()
            activeAdapter = record

            // Phase 5: Generate skill files
            progress = KFProgress(phase: "Generating skill files...", percentage: 0.96, eta: nil)
            let skillGen = SkillGenerator(inferenceProvider: inferenceProvider)

            // Run repo analysis if vault had code
            let repoAnalysis: RepoAnalysis? = (lastVaultAnalysis?.codeFiles ?? 0) > 0
                ? RepoAnalyzer().analyze(vaultURL: vaultURL)
                : nil

            let _ = try await skillGen.generateSkills(
                vaultAnalysis: lastVaultAnalysis ?? VaultAnalyzer().analyze(vaultURL: vaultURL, systemMemoryGB: systemMemoryGB),
                repoAnalysis: repoAnalysis,
                trainingPairs: dataURL,
                sourceVault: vaultURL.lastPathComponent
            ) { [weak self] phase in
                Task { @MainActor in
                    self?.progress = KFProgress(phase: phase, percentage: 0.97, eta: nil)
                }
            }

            trainingState = .complete
            progress = KFProgress(phase: "Complete — adapter active, skills generated", percentage: 1.0, eta: nil)

        } catch {
            lastTrainingError = error.localizedDescription
            trainingState = .error
        }
    }

    // MARK: - Adapter Management

    func activateAdapter(_ record: AdapterRecord) async {
        do {
            // Deactivate current
            if let current = activeAdapter {
                try await registry.setActive(current.id, active: false)
                await loader.unload(current.id)
            }

            try await loader.load(record)
            try await registry.setActive(record.id, active: true)
            activeAdapter = record
            installedAdapters = await registry.listAdapters()
        } catch {
            lastTrainingError = error.localizedDescription
        }
    }

    func deactivateAdapter() async {
        guard let current = activeAdapter else { return }
        do {
            try await registry.setActive(current.id, active: false)
            await loader.unload(current.id)
            activeAdapter = nil
            installedAdapters = await registry.listAdapters()
        } catch {
            lastTrainingError = error.localizedDescription
        }
    }

    func deleteAdapter(_ record: AdapterRecord) async {
        do {
            if record.id == activeAdapter?.id {
                await deactivateAdapter()
            }
            try await registry.deregister(id: record.id)
            try? FileManager.default.removeItem(at: record.adapterPath)
            installedAdapters = await registry.listAdapters()
        } catch {
            lastTrainingError = error.localizedDescription
        }
    }

    @discardableResult
    func exportAdapter(_ record: AdapterRecord, outputDirectory: URL) async -> URL? {
        lastTrainingError = nil

        do {
            let exporter = AdapterExporter()
            return try await Task.detached(priority: .utility) {
                try exporter.export(record: record, outputDirectory: outputDirectory)
            }.value
        } catch {
            lastTrainingError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Routing

    func recommendedAdapterType(for prompt: String) -> AdapterType? {
        router.routeAutomatic(prompt: prompt)
    }

    // MARK: - Feedback
    // WIRED: NoteDetailWorkspaceView accept/discard buttons call logFeedback()
    // for every note chat response. Signals populate kto_feedback table in
    // knowledge_fusion.db for nightly KTO alignment training.

    func logFeedback(prompt: String, completion: String, desirable: Bool, type: FeedbackType) async {
        do {
            try await feedbackLogger.log(
                prompt: prompt, completion: completion,
                desirable: desirable, feedbackType: type
            )
            feedbackStats = try await feedbackLogger.stats()
        } catch {
            // Feedback logging should not surface errors to user
        }
    }

    func refreshStats() async {
        feedbackStats = try? await feedbackLogger.stats()
    }
}
