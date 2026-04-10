import Testing
@testable import Epistemos

@Suite("Runtime Capability And Performance Policies")
struct RuntimeCapabilityAndPerformancePolicyTests {
    @Test("mamba2 warms the custom runtime but keeps agent mode hidden until fully validated")
    func mamba2CustomRuntimeProfileAndReleaseGating() throws {
        let model = LocalTextModelID.mamba2_2B4Bit
        let profile = try #require(model.ssmRuntimeProfile)

        #expect(profile.warmsCustomMetalRuntime == CustomSSMRuntimeSupport.isAvailable)
        #expect(profile.chunkLength == 128)
        #expect(profile.recommendedHeapSizeBytes >= 16 * 1_024 * 1_024)
        #expect(model.agentToolTier == .readOnly)
        #expect(!model.canActAsAgent)
        #expect(!model.supportsAgentMode)
    }

    @Test("cloud model identifiers stay unique across providers")
    func cloudModelIdentifiersAreUnique() {
        let rawValues = CloudTextModelID.allCases.map(\.rawValue)
        let vendorPairs = CloudTextModelID.allCases.map { "\($0.provider.rawValue):\($0.vendorModelID)" }

        #expect(Set(rawValues).count == rawValues.count)
        #expect(Set(vendorPairs).count == vendorPairs.count)
    }

    @Test("graph interaction policy relaxes rendering pressure while interacting")
    func graphInteractionPolicyAdjustsForActiveGestures() {
        let idleWait = GraphInteractionRenderPolicy.inFlightWaitMilliseconds(
            isInteracting: false,
            lowPowerMode: false
        )
        let activeWait = GraphInteractionRenderPolicy.inFlightWaitMilliseconds(
            isInteracting: true,
            lowPowerMode: false
        )

        #expect(activeWait > idleWait)
        #expect(
            GraphInteractionRenderPolicy.selectedNodePublishDistance(isInteracting: true)
                > GraphInteractionRenderPolicy.selectedNodePublishDistance(isInteracting: false)
        )
        #expect(
            GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames(isInteracting: true)
                > GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames(isInteracting: false)
        )
    }

    @Test("code editor policy hides semantic refresh work until the sidebar is visible")
    func codeEditorPolicyGatesSemanticSidebarWork() {
        #expect(CodeEditorPerformancePolicy.shouldRefreshSemanticContext(isSidebarVisible: true))
        #expect(!CodeEditorPerformancePolicy.shouldRefreshSemanticContext(isSidebarVisible: false))
    }

    @Test("code editor release path disables unfinished sidecars by default")
    func codeEditorReleasePolicyDisablesUnfinishedSurfaces() {
        #expect(!CodeEditorReleasePolicy.semanticSidebarEnabled)
        #expect(!CodeEditorReleasePolicy.aiPartnerEnabled)
    }

    @Test("code editor policy increases debounce windows for larger files")
    func codeEditorPolicyScalesForLargeFiles() {
        let smallOutline = CodeEditorPerformancePolicy.outlineRefreshDelayMilliseconds(characterCount: 1_200)
        let largeOutline = CodeEditorPerformancePolicy.outlineRefreshDelayMilliseconds(characterCount: 48_000)
        let smallInsight = CodeEditorPerformancePolicy.insightRefreshDelayMilliseconds(characterCount: 1_200)
        let largeInsight = CodeEditorPerformancePolicy.insightRefreshDelayMilliseconds(characterCount: 48_000)

        #expect(largeOutline > smallOutline)
        #expect(largeInsight > smallInsight)
    }
}
