import Foundation
import Testing

@testable import Epistemos

@Suite("Free V1 retired event-ring scaffold")
nonisolated struct EventRingRemovalTests {
    @Test("the unused substrate event-ring sources remain absent")
    func retiredEventRingSourcesRemainAbsent() throws {
        for relativePath in [
            "Epistemos/Engine/EventDrain.swift",
            "Epistemos/Engine/RustEventRingClient.swift",
        ] {
            let sourceURL = try sourceMirrorURL(for: relativePath)
            #expect(
                !FileManager.default.fileExists(atPath: sourceURL.path),
                "\(relativePath) must remain absent from the Free source mirror."
            )
        }
    }
}
