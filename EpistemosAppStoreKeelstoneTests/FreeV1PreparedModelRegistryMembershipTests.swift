import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 registry-membership tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 prepared-model registry membership")
struct FreeV1PreparedModelRegistryMembershipTests {
    @Test("Free V1 compiles no general prepared-model manifest loader")
    func freeV1CompilesNoGeneralPreparedModelManifestLoader() throws {
        let source = try sourceText("Epistemos/Engine/LocalModelInfrastructure.swift")
        let guardedStart = try #require(source.range(
            of: "#if !EPISTEMOS_FREE_V1\nnonisolated enum PreparedModelRegistryError"
        ))
        let guardedEnd = try #require(source.range(
            of: "#endif",
            range: guardedStart.upperBound..<source.endIndex
        ))
        let guardedRegistry = String(source[guardedStart.lowerBound..<guardedEnd.upperBound])
        let freePrefix = String(source[..<guardedStart.lowerBound])

        for generalRegistryIdentity in [
            "final class PreparedModelRegistryState",
            "final class PreparedModelRegistry",
            "EPISTEMOS_MODEL_MANIFEST_PATH",
            "repoManifestURL",
            "trust_remote_code",
            "download_path",
            "adapter_path",
        ] {
            #expect(guardedRegistry.contains(generalRegistryIdentity))
            #expect(!freePrefix.contains(generalRegistryIdentity))
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
}
