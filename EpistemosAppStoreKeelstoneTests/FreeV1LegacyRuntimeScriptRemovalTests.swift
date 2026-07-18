import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Legacy runtime-script removal tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 legacy runtime-script removal")
struct FreeV1LegacyRuntimeScriptRemovalTests {
    @Test("Free V1 omits retired local-generative runtime probes")
    func freeV1OmitsRetiredLocalGenerativeRuntimeProbes() {
        let retiredPaths = [
            "scripts/gguf-answer-probe.sh",
            "scripts/llama-mas-sandbox-spike.sh",
            "scripts/apple-fm-quickchat-probe.sh",
            "scripts/apple-fm-quickchat-probe/main.swift",
        ]

        for retiredPath in retiredPaths {
            #expect(
                !freeV1RetiredPathExists(
                    retiredPath,
                    sourceFilePath: #filePath
                ),
                "Free V1 must not retain a retired local-generative runtime probe."
            )
        }
    }
}
