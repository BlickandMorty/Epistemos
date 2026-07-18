import Foundation
import Testing

@Suite("Retired Vault Organizer")
struct VaultOrganizerPrivacyGuardTests {
    @Test("retired Vault Organizer source remains physically absent")
    func retiredVaultOrganizerSourceRemainsPhysicallyAbsent() {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/Views/Notes/VaultOrganizerView.swift")

        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }
}
