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
/// Follows Epistemos pattern: @MainActor @Observable (never ObservableObject).
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

    var detectedModelPath: URL? {
        guard !availableModels.isEmpty, selectedModelIndex < availableModels.count else { return nil }
        return availableModels[selectedModelIndex].path
    }
    var detectedModelName: String? {
        guard !availableModels.isEmpty, selectedModelIndex < availableModels.count else { return nil }
        return availableModels[selectedModelIndex].name
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
    }

    private func detectInstalledModels() {
        let modelBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
                lastTrainingError = "No text content found in vault (\(parseResult.parsedFiles) files parsed, \(parseResult.errors.count) errors)"
                trainingState = .error
                return
            }

            // Phase 2: Generate synthetic data
            trainingState = .generating
            progress = KFProgress(phase: "Generating training data from \(chunks.count) chunks (\(parseResult.parsedFiles) notes)...", percentage: 0.10, eta: nil)
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

            // Use the first available training file
            guard let (_, dataURL) = synthResult.trainingFiles.first else {
                lastTrainingError = "No training data files produced"
                trainingState = .error
                return
            }

            let adapterOutputDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Epistemos/Adapters/\(UUID().uuidString)")

            // Deploy scripts if needed (idempotent)
            let pyEnv = PythonEnvironmentManager.shared
            try? pyEnv.deployScripts()

            let trainer = QLoRATrainer(
                pythonPath: pyEnv.isReady ? pyEnv.pythonPath : "/usr/bin/python3",
                scriptsDirectory: pyEnv.scriptsDirectory
            )

            let metadata: AdapterMetadata
            switch recommendation.profile {
            case .knowledge, .mixed:
                metadata = try await trainer.trainKnowledgeAdapter(
                    modelPath: modelPath,
                    dataPath: dataURL,
                    outputPath: adapterOutputDir,
                    numIters: 1000
                ) { [weak self] tp in
                    Task { @MainActor in
                        let pct = 0.55 + Double(tp.iteration) / Double(tp.totalIterations) * 0.35
                        self?.progress = KFProgress(
                            phase: "Training... (iter \(tp.iteration)/\(tp.totalIterations))",
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
                    numIters: 1000
                )
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

            trainingState = .complete
            progress = KFProgress(phase: "Complete — adapter is now active", percentage: 1.0, eta: nil)

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

    // MARK: - Routing

    func recommendedAdapterType(for prompt: String) -> AdapterType? {
        router.routeAutomatic(prompt: prompt)
    }

    // MARK: - Feedback

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
