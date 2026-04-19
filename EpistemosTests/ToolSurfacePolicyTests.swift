import Testing
@testable import Epistemos

struct ToolSurfacePolicyTests {
    private static func makeTool(name: String) -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: "rust",
            description: "test tool \(name)",
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    @Test func unsupportedImageGenerationDisappearsFromVisibleToolSurfaces() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "image_generate"),
            Self.makeTool(name: "vision_analyze"),
            Self.makeTool(name: "text_to_speech"),
        ])

        #expect(filtered.map(\.name) == ["vision_analyze", "text_to_speech"])
    }

    @Test func thinkDisappearsFromVisibleToolSurfaces() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "think"),
            Self.makeTool(name: "vault_search"),
        ])

        #expect(filtered.map(\.name) == ["vault_search"])
    }
}
