import Foundation
import Testing
@testable import Epistemos

// MARK: - KnowledgeFusionViewModel Tests

@Suite("KnowledgeFusionViewModel")
struct KnowledgeFusionViewModelTests {

    @Test("Initial state is idle")
    @MainActor
    func initialState() {
        let vm = KnowledgeFusionViewModel()
        #expect(vm.trainingState == .idle)
        #expect(vm.activeAdapter == nil)
        #expect(vm.installedAdapters.isEmpty)
        #expect(vm.lastTrainingError == nil)
        #expect(vm.autoresearchRunning == false)
    }

    @Test("Activate and deactivate adapter")
    @MainActor
    func activateDeactivate() async throws {
        let registryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-vm-reg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: registryPath) }

        let registry = AdapterRegistry(storagePath: registryPath)
        let vm = KnowledgeFusionViewModel(registry: registry)

        // Create test adapter
        let adapterDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-vm-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        try Data([0x00]).write(to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))
        defer { try? FileManager.default.removeItem(at: adapterDir) }

        let metaJSON = """
        {"adapter_type":"knowledge","source_vault":"test","lora_rank":32,"lora_alpha":64,\
        "target_modules":["q_proj"],"learning_rate":0.00002,"num_examples":100,"num_iters":50,\
        "training_duration_seconds":30.0,"created_at":"2026-03-23T00:00:00Z","base_model":"test","quality_score":null}
        """
        let metaPath = adapterDir.appendingPathComponent("training_metadata.json")
        try metaJSON.write(to: metaPath, atomically: true, encoding: .utf8)

        let record = AdapterRecord(
            id: UUID(), name: "Test", type: .knowledge,
            adapterPath: adapterDir, metadataPath: metaPath,
            sourceVault: "test", createdAt: Date(), qualityScore: nil,
            isActive: false, baseModel: "test", loraRank: 32,
            parameterCount: 1000, trainingExamples: 100
        )

        try await registry.register(record)
        await vm.loadState()

        #expect(vm.installedAdapters.count == 1)
        #expect(vm.activeAdapter == nil)

        await vm.activateAdapter(record)
        #expect(vm.activeAdapter?.id == record.id)

        await vm.deactivateAdapter()
        #expect(vm.activeAdapter == nil)
    }

    @Test("Router recommends correct adapter type")
    @MainActor
    func routerRecommendation() {
        let vm = KnowledgeFusionViewModel()

        #expect(vm.recommendedAdapterType(for: "Help me write in my style") == .style)
        #expect(vm.recommendedAdapterType(for: "What did I write about quantum computing in my notes?") == .knowledge)
        #expect(vm.recommendedAdapterType(for: "Tell me a joke") == nil)
    }

    @Test("Delete adapter removes from registry")
    @MainActor
    func deleteAdapter() async throws {
        let registryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-vm-del-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: registryPath) }

        let registry = AdapterRegistry(storagePath: registryPath)
        let vm = KnowledgeFusionViewModel(registry: registry)

        let adapterDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-vm-del-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        try Data([0x00]).write(to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))

        let metaPath = adapterDir.appendingPathComponent("training_metadata.json")
        try "{}".write(to: metaPath, atomically: true, encoding: .utf8)

        let record = AdapterRecord(
            id: UUID(), name: "ToDelete", type: .knowledge,
            adapterPath: adapterDir, metadataPath: metaPath,
            sourceVault: "test", createdAt: Date(), qualityScore: nil,
            isActive: false, baseModel: "test", loraRank: 32,
            parameterCount: 1000, trainingExamples: 100
        )

        try await registry.register(record)
        await vm.loadState()
        #expect(vm.installedAdapters.count == 1)

        await vm.deleteAdapter(record)
        #expect(vm.installedAdapters.isEmpty)
    }
}
