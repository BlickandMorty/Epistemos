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

    // "HookRegistry production mount stays out of forbidden runtime surfaces" removed with
    // cloud-only/Omega removal 2026-07-03 — all three forbidden surfaces (OmegaPermissions.swift,
    // Vision/TCCPermissionState.swift, and iMessageDriver/IMessageDriverService.swift) were deleted
    // from app source, so there is no forbidden surface left to guard.
}
