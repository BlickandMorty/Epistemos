import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 capability-bridge closure tests must compile in the App Store target.")
#endif

@Suite("Free V1 retired agent closure")
struct FreeV1CapabilityBridgeClosureTests {
    @Test("Free V1 does not ship retired agent/provider closures")
    func freeV1DoesNotShipRetiredAgentProviderClosures() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for retiredPath in [
            "Epistemos/Security/CapabilityBridge.swift",
            "EpistemosTests/CapabilityBridgeTests.swift",
            "Epistemos/Engine/CapabilityManifestBuilder.swift",
            "Epistemos/Engine/CommandInputParser.swift",
            "EpistemosTests/CommandInputParserTests.swift",
            "Epistemos/State/CommandCenterDiagnostics.swift",
            "EpistemosTests/CommandCenterDiagnosticsTests.swift",
            "Epistemos/Views/Approval/ApprovalModalView.swift",
            "Epistemos/A2UI/Catalog.swift",
            "Epistemos/A2UI/Validator.swift",
            "Epistemos/A2UI/Components/NoteCard.swift",
            "EpistemosTests/A2UICatalogTests.swift",
        ] {
            #expect(
                !FileManager.default.fileExists(
                    atPath: repositoryRoot.appendingPathComponent(retiredPath).path
                ),
                "Free V1 must not ship retired general-agent code: \(retiredPath)"
            )
        }
    }

}
