import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 landing-smoke removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 stale landing smoke removal")
struct FreeV1LandingFeatureSmokeRemovalTests {
    @Test("Free V1 omits the stale agent and MCP landing smoke harness")
    func freeV1OmitsStaleLandingFeatureSmokeHarness() {
        let retiredPath = "scripts/landing-feature-buttons-smoke.swift"

        #expect(
            !freeV1RetiredPathExists(
                retiredPath,
                sourceFilePath: #filePath
            ),
            "Free V1 must not retain the stale agent and MCP landing smoke harness."
        )
    }
}
