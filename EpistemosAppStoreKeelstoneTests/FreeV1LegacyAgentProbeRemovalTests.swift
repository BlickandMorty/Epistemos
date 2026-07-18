import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Legacy agent-probe removal tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 legacy agent-probe removal")
struct FreeV1LegacyAgentProbeRemovalTests {
    @Test("Free V1 omits the retired cloud-agent MAS spike harness")
    func freeV1OmitsRetiredCloudAgentMASSpikeHarness() {
        let retiredPaths = [
            "scripts/agent-core-mas-spike.sh",
            "scripts/agent-core-mas-spike/main.swift",
            "scripts/extensibility-smoke-stubs.swift",
        ]

        for retiredPath in retiredPaths {
            #expect(
                !freeV1RetiredPathExists(
                    retiredPath,
                    sourceFilePath: #filePath
                ),
                "Free V1 must not retain the retired cloud-agent MAS spike harness."
            )
        }
    }
}
