import Foundation
import os

@MainActor @Observable
final class MLXModelManager {

    enum ModelStatus: Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready(modelId: String)
        case error(String)
    }

    private(set) var status: ModelStatus = .idle
    private(set) var availableMemoryGB: Double = 0

    let engine: MLXEngine

    init(engine: MLXEngine = MLXEngine()) {
        self.engine = engine
        refreshMemory()
    }

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var loadedModelId: String? {
        if case .ready(let id) = status { return id }
        return nil
    }

    func loadModel(spec: MLXModelSpec) async {
        guard spec.sizeGB <= availableMemoryGB else {
            status = .error("Not enough memory (\(String(format: "%.1f", availableMemoryGB))GB available, \(String(format: "%.1f", spec.sizeGB))GB needed)")
            return
        }

        status = .downloading(progress: 0)

        do {
            let loadTime = try await engine.loadModel(id: spec.hfId) { [weak self] progress in
                Task { @MainActor [weak self] in
                    let fraction = progress.fractionCompleted
                    if fraction < 1.0 {
                        self?.status = .downloading(progress: fraction)
                    } else {
                        self?.status = .loading
                    }
                }
            }
            status = .ready(modelId: spec.id)
            Log.engine.info("MLX model loaded: \(spec.displayName) in \(String(format: "%.1f", loadTime))s")
        } catch {
            status = .error(error.localizedDescription)
            Log.engine.error("MLX model load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func unloadModel() async {
        await engine.unloadModel()
        status = .idle
        refreshMemory()
    }

    func refreshMemory() {
        availableMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }

    var compatibleModels: [MLXModelSpec] {
        MLXModelRegistry.modelsForMemory(availableGB: availableMemoryGB)
    }
}
