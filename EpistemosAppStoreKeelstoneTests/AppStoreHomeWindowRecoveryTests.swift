import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("App Store home-window recovery tests must compile in the Free App Store target.")
#endif

@Suite("App Store home-window recovery")
struct AppStoreHomeWindowRecoveryTests {
    @Test("reopen recovery never schedules a second launch window")
    func reopenRecoveryIsManualOnly() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Epistemos/App/EpistemosApp.swift"),
            encoding: .utf8
        )
        let fallbackStart = try #require(source.range(of: "private struct FallbackHomeWindowContent"))
        let fallbackEnd = try #require(source.range(
            of: "\nenum SavedApplicationStatePurger",
            range: fallbackStart.upperBound..<source.endIndex
        ))
        let fallbackSection = source[fallbackStart.lowerBound..<fallbackEnd.lowerBound]
        let reopenStart = try #require(source.range(of: "func applicationShouldHandleReopen"))
        let reopenEnd = try #require(source.range(
            of: "\n    func applicationShouldOpenUntitledFile",
            range: reopenStart.upperBound..<source.endIndex
        ))
        let reopenSection = source[reopenStart.lowerBound..<reopenEnd.lowerBound]

        #expect(source.components(separatedBy: "WindowGroup(\"Epistemos\")").count - 1 == 1)
        #expect(!fallbackSection.contains("scheduleAfterLaunch"))
        #expect(!fallbackSection.contains("func schedule("))
        #expect(!fallbackSection.contains("orderFrontRegardless"))
        #expect(fallbackSection.contains("await Task.yield()"))
        #expect(fallbackSection.contains("private var pendingRecoveryTask: Task<Void, Never>?"))
        #expect(fallbackSection.contains("guard pendingRecoveryTask == nil else { return }"))
        #expect(fallbackSection.contains("self?.performPendingRecovery()"))
        #expect(fallbackSection.contains("pendingRecoveryTask = nil"))
        #expect(!source.contains("AppStoreFirstWindowPresenter"))
        #expect(reopenSection.contains("HomeWindowFallbackPresenter.shared.ensureHomeWindow()"))
        #expect(!reopenSection.contains("#if EPISTEMOS_APP_STORE"))
        #expect(reopenSection.contains("guard !Self.isRunningTests else { return true }"))
        #expect(reopenSection.contains("guard hasCompletedInitialLaunch else { return true }"))

        #expect(source.components(separatedBy: "private let isEpistemosTestHost =").count - 1 == 1)
        #expect(source.contains("NSClassFromString(\"XCTestCase\") != nil"))
        #expect(source.contains("Bundle.main.bundleURL.pathExtension == \"xctest\""))
        #expect(
            source.components(separatedBy: "private static let isRunningTests = isEpistemosTestHost").count - 1 == 3
        )

        let environmentStart = try #require(source.range(of: "private func currentEnvironmentMetadata() -> [String: String]"))
        let environmentEnd = try #require(source.range(
            of: "\n    private func boolLabel",
            range: environmentStart.upperBound..<source.endIndex
        ))
        let environmentMetadata = source[environmentStart.lowerBound..<environmentEnd.lowerBound]
        #expect(environmentMetadata.components(separatedBy: "\"homeWindowCount\"").count - 1 == 1)
        #expect(environmentMetadata.components(separatedBy: "\"visibleHomeWindowCount\"").count - 1 == 1)
        #expect(environmentMetadata.contains("HomeWindowIdentity.matches(window)"))
    }
}
