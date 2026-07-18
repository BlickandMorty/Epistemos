import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Thermal monitor removal tests must compile in the Free App Store target.")
#endif

@Suite("Free V1 thermal monitor removal")
struct ThermalMonitorRemovalTests {
    @Test("Free V1 omits the retired agent and cloud throttle singleton")
    func freeV1OmitsRetiredThermalMonitor() {
        #expect(
            !freeV1RetiredPathExists(
                "Epistemos/State/ThermalMonitor.swift",
                sourceFilePath: #filePath
            ),
            "Free V1 must not retain the uncalled agent and cloud thermal throttle singleton."
        )
    }
}
