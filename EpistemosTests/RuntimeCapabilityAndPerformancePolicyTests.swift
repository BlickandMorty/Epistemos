import Testing
import CoreGraphics
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

    @Test("large graph overlay caps drawable scale without changing mini mode")
    func graphDrawableResolutionPolicyCapsOnlyLargeOverlays() {
        let fullScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let miniScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 360, height: 360),
            backingScale: 2.0,
            isMiniMode: true,
            lowPowerMode: false,
            qualityLevel: 0
        )

        #expect(fullScale < 2.0)
        #expect(fullScale >= 1.0)
        #expect(miniScale == 2.0)
    }

    @Test("drawable resolution policy preserves native scale under budget")
    func graphDrawableResolutionPolicyLeavesSmallViewsNative() {
        let scale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 600, height: 400),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let drawableSize = GraphDrawableResolutionPolicy.drawableSize(
            boundsSize: CGSize(width: 600, height: 400),
            scale: scale
        )

        #expect(scale == 2.0)
        #expect(drawableSize == CGSize(width: 1_200, height: 800))
    }

    @Test("cinematic fullscreen budget matches mini-like pixel pressure")
    func graphDrawableResolutionPolicyUsesMiniLikeCinematicBudget() {
        let cinematicScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let performanceScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 2
        )
        let cinematicSize = GraphDrawableResolutionPolicy.drawableSize(
            boundsSize: CGSize(width: 1_512, height: 982),
            scale: cinematicScale
        )
        let cinematicPixels = cinematicSize.width * cinematicSize.height

        #expect(cinematicScale < performanceScale)
        #expect(cinematicPixels <= 1_610_000)
        #expect(cinematicPixels >= 1_500_000)
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
