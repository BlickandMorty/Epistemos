import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 AppSupervisor boundary tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 AppSupervisor inference boundary")
struct FreeV1AppSupervisorBoundaryTests {
    @Test("Free V1 reports its absent inference runtime as unavailable without compiling runtime state")
    func freeV1InferenceHealthFailsClosedWithoutRuntimeState() throws {
        let source = try sourceText("Epistemos/State/AppSupervisor.swift")
        let availability = try #require(
            sourceSection(
                in: source,
                startingAt: "    var isAIAvailable: Bool {",
                endingBefore: "    var isWriteAvailable: Bool {"
            )
        )
        let check = try #require(
            sourceSection(
                in: source,
                startingAt: "    private func checkInference() async -> Bool {",
                endingBefore: "    private func startNetworkMonitor()"
            )
        )

        let freeBranch = try #require(
            sourceSection(
                in: check,
                startingAt: "#if EPISTEMOS_FREE_V1",
                endingBefore: "#else"
            )
        )
        let paidBranch = try #require(
            sourceSection(
                in: check,
                startingAt: "#else",
                endingBefore: "#endif"
            )
        )

        #expect(freeBranch.contains("return false"))
        #expect(!freeBranch.contains("runtimeState"))
        #expect(paidBranch.contains("bootstrap.runtimeState.appleIntelligenceAvailable"))
        #expect(availability.contains("#if EPISTEMOS_FREE_V1\n        false\n        #else"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourceSection(
        in text: String,
        startingAt start: String,
        endingBefore end: String
    ) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text[startRange.upperBound...].range(of: end) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.lowerBound])
    }
}
