import Foundation
import Testing
@testable import Epistemos

// MARK: - KnowledgeFusionViewModel Tests

private func makeKnowledgeFusionTestAdapter(
    name: String = "Test Adapter"
) throws -> (record: AdapterRecord, cleanup: () -> Void) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("kf-ui-adapter-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    try Data([0x00]).write(to: directory.appendingPathComponent("adapter_weights.safetensors"))
    try "{}".write(
        to: directory.appendingPathComponent("adapter_config.json"),
        atomically: true,
        encoding: .utf8
    )

    let metadataPath = directory.appendingPathComponent("training_metadata.json")
    let metadataJSON = """
    {"adapter_type":"knowledge","source_vault":"test","lora_rank":32,"lora_alpha":64,\
    "target_modules":["q_proj"],"learning_rate":0.00002,"num_examples":100,"num_iters":50,\
    "training_duration_seconds":30.0,"created_at":"2026-03-23T00:00:00Z","base_model":"test","quality_score":null}
    """
    try metadataJSON.write(to: metadataPath, atomically: true, encoding: .utf8)

    let record = AdapterRecord(
        id: UUID(),
        name: name,
        type: .knowledge,
        adapterPath: directory,
        metadataPath: metadataPath,
        sourceVault: "TestVault",
        createdAt: Date(),
        qualityScore: nil,
        isActive: false,
        baseModel: "Qwen2.5-3B-Instruct-4bit",
        loraRank: 32,
        parameterCount: 32 * 4096 * 2,
        trainingExamples: 500
    )

    return (record, { try? FileManager.default.removeItem(at: directory) })
}

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

    @Test("Export adapter writes bundle via async view-model path")
    @MainActor
    func exportAdapter() async throws {
        let vm = KnowledgeFusionViewModel()
        let (record, cleanup) = try makeKnowledgeFusionTestAdapter(name: "Exported")
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-vm-export-\(UUID().uuidString)")
        defer {
            cleanup()
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let bundleURL = await vm.exportAdapter(record, outputDirectory: outputDirectory)

        #expect(bundleURL != nil)
        if let bundleURL {
            #expect(FileManager.default.fileExists(atPath: bundleURL.path))
            #expect(bundleURL.pathExtension == AdapterExporter.bundleExtension)
        }
        #expect(vm.lastTrainingError == nil)
    }

    @Test("Training history export routes through async view-model export")
    func trainingHistoryExportUsesAsyncViewModelPath() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("await vm.exportAdapter("))
        #expect(source.contains("Task {"))
        #expect(!source.contains("try exporter.export("))
    }
}
