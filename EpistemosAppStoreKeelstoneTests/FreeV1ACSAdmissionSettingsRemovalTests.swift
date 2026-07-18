import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 ACS admission Settings removal tests must compile in the App Store target.")
#endif

@Suite("Free V1 ACS admission Settings removal")
struct FreeV1ACSAdmissionSettingsRemovalTests {
    @Test("Free V1 omits the unmounted ACS tool-call admission Settings row")
    func freeV1OmitsACSAdmissionSettingsRow() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let retiredPath = "Epistemos/Views/Settings/ACSAdmissionHealthRow.swift"

        #expect(
            !FileManager.default.fileExists(
                atPath: repositoryRoot.appendingPathComponent(retiredPath).path
            ),
            "Free V1 must not retain an unmounted ACS tool-call admission Settings row: \(retiredPath)"
        )
    }
}
