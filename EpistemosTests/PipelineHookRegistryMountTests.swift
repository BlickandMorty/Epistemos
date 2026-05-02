import Testing

@Suite("Pipeline HookRegistry Mount")
struct PipelineHookRegistryMountTests {
    @Test("PipelineService mounts HookRegistry at the local tool-loop boundary")
    func pipelineServiceMountsHookRegistryAtLocalToolLoopBoundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(source.contains("HookRegistry.shared.fireBeforePromptBuild"))
        #expect(source.contains("HookRegistry.shared.fireBeforeToolCall"))
        #expect(source.contains("HookRegistry.shared.fireAfterToolCall"))
        #expect(source.contains("hook_cancelled"))
    }

    @Test("HookRegistry production mount stays out of forbidden runtime surfaces")
    func hookRegistryProductionMountStaysOutOfForbiddenRuntimeSurfaces() throws {
        let forbiddenSources = [
            "Epistemos/App/ChatCoordinator.swift",
            "Epistemos/Omega/OmegaPermissions.swift",
            "Epistemos/Omega/Vision/TCCPermissionState.swift",
            "Epistemos/Omega/iMessageDriver/IMessageDriverService.swift",
        ]

        for relativePath in forbiddenSources {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("HookRegistry.shared"))
        }
    }
}
