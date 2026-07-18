import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 registry-composition tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 prepared-model registry composition")
struct FreeV1PreparedModelRegistryRemovalTests {
    @Test("Free V1 does not compose the general prepared-model registry")
    func freeV1BootstrapAndEnvironmentExcludeTheGeneralRegistry() throws {
        let bootstrap = try sourceText("Epistemos/App/AppBootstrap.swift")
        let environment = try sourceText("Epistemos/App/AppEnvironment.swift")

        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    private var preparedRetrievalRefreshTask: Task<Void, Never>?\n    private var didStartDeferredRuntimeServices = false\n    #endif"
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    let preparedModelRegistryState: PreparedModelRegistryState\n    let preparedModelRegistry: PreparedModelRegistry\n    #endif"
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n        let preparedModelRegistryState = PreparedModelRegistryState()"
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    private func startDeferredRuntimeServicesIfNeeded()"
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    private func applyPreparedRetrievalRuntimeConfiguration("
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n        preparedRetrievalRefreshTask?.cancel()\n        preparedRetrievalRefreshTask = nil\n        #endif"
            )
        )
        #expect(
            bootstrap.contains(
                "#if EPISTEMOS_FREE_V1\n        queryEngine.configure(\n            graphStore: graphState.store,\n            graphState: graphState,\n            searchIndexProvider: searchIndexProvider\n        )\n        #else"
            )
        )
        #expect(
            bootstrap.contains(
                "preparedRetrievalRuntimeConfiguration: preparedModelRegistryState.retrievalRuntimeConfiguration"
            )
        )
        #expect(
            environment.contains(
                "#if !EPISTEMOS_FREE_V1\n            .environment(bootstrap.preparedModelRegistryState)\n            #endif"
            )
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
