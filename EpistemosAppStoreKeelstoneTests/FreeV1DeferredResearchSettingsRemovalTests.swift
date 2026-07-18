import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 deferred-research settings removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 deferred research settings removal")
struct FreeV1DeferredResearchSettingsRemovalTests {
    @Test("Free V1 omits unmounted retired settings probes")
    func freeV1OmitsUnmountedRetiredSettingsProbes() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let retiredPaths = [
            "Epistemos/Views/Settings/HELIOSv5SettingsView.swift",
            "Epistemos/Views/Settings/HyperdynamicLoopHealthRow.swift",
            "Epistemos/Views/Settings/KnowledgeCoreRuntimeHealthRow.swift",
            "Epistemos/Views/Settings/OpLogProjectionHealthRow.swift",
            "Epistemos/Views/Settings/ArenaHealthRow.swift",
            "Epistemos/Views/Settings/LatticeWBOHealthRow.swift",
            "Epistemos/Views/Settings/SubstrateDriftMonitorHealthRow.swift",
            "Epistemos/Views/Settings/HTMLWorkspaceHealthRow.swift",
            "Epistemos/Views/Settings/GraphEventVisibilityRow.swift",
            "Epistemos/Views/Settings/KnowledgeCoreOutlinePreview.swift",
            "Epistemos/Views/Settings/ACSAdmissionHealthRow.swift",
            "Epistemos/Views/Settings/DeterministicSchemaGateHealthRow.swift",
            "Epistemos/Views/Settings/EmlRerankGateHealthRow.swift",
            "Epistemos/Views/Settings/FUlpHealthRow.swift",
            "Epistemos/Views/Settings/KnowledgeCoreReadParityHealthRow.swift",
        ]

        for retiredPath in retiredPaths {
            #expect(
                !FileManager.default.fileExists(
                    atPath: repositoryRoot.appendingPathComponent(retiredPath).path
                ),
                "Free V1 must not retain an unmounted retired settings probe: \(retiredPath)"
            )
        }
    }
}
