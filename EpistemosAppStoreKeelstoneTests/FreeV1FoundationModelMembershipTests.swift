import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 FoundationModels membership tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 FoundationModels membership")
struct FreeV1FoundationModelMembershipTests {
    @Test("Free V1 excludes FoundationModels generation and the general model manifest loader")
    func freeV1ExcludesNonRetainedModelRuntimeSources() throws {
        let project = try sourceText("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))

        for excludedSource in [
            "Engine/AppleIntelligenceService.swift",
            "Engine/LocalModelInfrastructure.swift",
        ] {
            #expect(
                appTarget.components(separatedBy: "\\n").filter {
                    $0 == "          - \(excludedSource)"
                }.count == 1,
                "Free V1 must not compile \(excludedSource); it belongs only to the retained base runtime."
            )
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func appStoreTarget(in project: String) -> String? {
        guard let targetRange = project.range(of: "  Epistemos-AppStore:\\n") else { return nil }
        let suffix = project[targetRange.upperBound...]
        guard let nextTargetRange = suffix.range(of: "  EpistemosWidgets:\\n") else {
            return String(suffix)
        }
        return String(suffix[..<nextTargetRange.lowerBound])
    }
}
