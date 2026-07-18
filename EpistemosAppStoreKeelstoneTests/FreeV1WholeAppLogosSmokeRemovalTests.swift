import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 provider-logo smoke removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 stale provider-logo smoke removal")
struct FreeV1WholeAppLogosSmokeRemovalTests {
    @Test("Free V1 omits the stale provider and MCP logo smoke harness")
    func freeV1OmitsStaleProviderAndMCPLogoSmokeHarness() {
        let retiredPath = "scripts/whole-app-logos-smoke.swift"

        #expect(
            !freeV1RetiredPathExists(
                retiredPath,
                sourceFilePath: #filePath
            ),
            "Free V1 must not retain the stale provider and MCP logo smoke harness."
        )
    }
}
