import Foundation
import Testing

@Suite("Retired browser capability status")
struct SSMBrowserCapabilityStatusTests {
    @Test("retired browser capability status source remains physically absent")
    func retiredBrowserCapabilityStatusSourceRemainsPhysicallyAbsent() {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/Engine/BrowserCapabilityStatus.swift")

        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }
}
