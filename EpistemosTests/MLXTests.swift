import Testing
import Foundation
@testable import Epistemos

@Suite("MLX Model Registry")
struct MLXModelRegistryTests {

    @Test("Registry contains expected model families")
    func registryFamilies() {
        let families = Set(MLXModelRegistry.models.map(\.family))
        #expect(families.contains("0.8B"))
        #expect(families.contains("2B"))
        #expect(families.contains("4B"))
        #expect(families.contains("9B"))
    }

    @Test("All models have valid IDs and HuggingFace IDs")
    func modelValidation() {
        for model in MLXModelRegistry.models {
            #expect(!model.id.isEmpty)
            #expect(!model.hfId.isEmpty)
            #expect(model.hfId.contains("mlx-community/"))
            #expect(!model.displayName.isEmpty)
            #expect(model.sizeGB > 0)
        }
    }

    @Test("Find by ID returns correct model")
    func findById() {
        let found = MLXModelRegistry.find(id: "qwen3.5-4b-q4")
        #expect(found != nil)
        #expect(found?.family == "4B")
        #expect(found?.quantization == "Q4")
    }

    @Test("Find by HuggingFace ID returns correct model")
    func findByHfId() {
        let found = MLXModelRegistry.find(hfId: "mlx-community/Qwen3.5-0.8B-MLX-4bit")
        #expect(found != nil)
        #expect(found?.id == "qwen3.5-0.8b-q4")
    }

    @Test("Find returns nil for unknown ID")
    func findUnknown() {
        #expect(MLXModelRegistry.find(id: "nonexistent") == nil)
        #expect(MLXModelRegistry.find(hfId: "nonexistent") == nil)
    }

    @Test("Models for memory filters correctly")
    func memoryFilter() {
        let small = MLXModelRegistry.modelsForMemory(availableGB: 1.0)
        #expect(small.allSatisfy { $0.sizeGB <= 1.0 })

        let all = MLXModelRegistry.modelsForMemory(availableGB: 100.0)
        #expect(all.count == MLXModelRegistry.models.count)

        let none = MLXModelRegistry.modelsForMemory(availableGB: 0.1)
        #expect(none.isEmpty)
    }

    @Test("Grouped by family maintains order")
    func groupedOrder() {
        let grouped = MLXModelRegistry.groupedByFamily
        let families = grouped.map(\.family)
        #expect(families == ["0.8B", "2B", "4B", "9B"])
    }

    @Test("Each group has at least one model")
    func groupsNonEmpty() {
        for group in MLXModelRegistry.groupedByFamily {
            #expect(!group.models.isEmpty)
        }
    }

    @Test("Model IDs are unique")
    func uniqueIds() {
        let ids = MLXModelRegistry.models.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

@Suite("LLMProviderType MLX Case")
struct LLMProviderMLXTests {

    @Test("MLX provider has correct display properties")
    func mlxDisplayProperties() {
        let mlx = LLMProviderType.mlx
        #expect(mlx.displayName == "MLX")
        #expect(mlx.iconName == "cpu")
        #expect(mlx.rawValue == "mlx")
    }

    @Test("MLX is included in CaseIterable")
    func mlxInAllCases() {
        #expect(LLMProviderType.allCases.contains(.mlx))
    }
}

@Suite("MLXEngine Think Tag Stripping")
struct MLXEngineThinkTagTests {

    @Test("Strips complete think tags")
    func stripComplete() {
        let input = "<think>internal reasoning</think>Hello world"
        let result = MLXEngine.stripThinkingTags(input)
        #expect(result == "Hello world")
    }

    @Test("Strips multiple think blocks")
    func stripMultiple() {
        let input = "<think>first</think>Hello <think>second</think>world"
        let result = MLXEngine.stripThinkingTags(input)
        #expect(result == "Hello world")
    }

    @Test("Returns text unchanged when no think tags")
    func noTags() {
        let input = "Just regular text"
        let result = MLXEngine.stripThinkingTags(input)
        #expect(result == "Just regular text")
    }

    @Test("Handles empty think tags")
    func emptyThink() {
        let input = "<think></think>Content"
        let result = MLXEngine.stripThinkingTags(input)
        #expect(result == "Content")
    }

    @Test("Handles orphaned close tag")
    func orphanedClose() {
        let input = "some text</think>Real content"
        let result = MLXEngine.stripThinkingTags(input)
        #expect(result == "Real content")
    }
}
