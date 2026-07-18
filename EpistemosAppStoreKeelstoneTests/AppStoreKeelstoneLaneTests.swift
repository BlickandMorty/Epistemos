import AppKit
import Foundation
import GRDB
import SwiftData
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("KEELSTONE App Store lane tests must compile with EPISTEMOS_APP_STORE and MAS_SANDBOX.")
#endif

private actor PageIdentityExportGate {
    private var invocationCount = 0
    private var firstStarted = false
    private var firstReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func begin() async -> Int {
        invocationCount += 1
        let invocation = invocationCount
        if invocation == 1 {
            firstStarted = true
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
            if !firstReleased {
                await withCheckedContinuation { releaseWaiters.append($0) }
            }
        }
        return invocation
    }

    func waitUntilFirstStarted() async {
        guard !firstStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseFirst() {
        firstReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func count() -> Int {
        invocationCount
    }
}

private actor AsyncCompletionProbe {
    private var completed = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func markCompleted() {
        completed = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    func isCompleted() -> Bool {
        completed
    }

    func waitUntilCompleted() async {
        guard !completed else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private nonisolated final class SynchronousCountProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.withLock { value += 1 }
    }

    func count() -> Int {
        lock.withLock { value }
    }
}

private nonisolated final class SynchronousOrderProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func record(_ value: String) {
        lock.withLock { values.append(value) }
    }

    func snapshot() -> [String] {
        lock.withLock { values }
    }
}

private nonisolated final class SynchronousURLProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedURLs: [URL] = []

    func record(_ url: URL) {
        lock.withLock {
            recordedURLs.append(url.standardizedFileURL)
        }
    }

    func snapshot() -> [URL] {
        lock.withLock { recordedURLs }
    }
}

private nonisolated final class UtilityModelContainerOwner: @unchecked Sendable {
    private static let releaseQueue = DispatchQueue(
        label: "com.epistemos.tests.model-container-release",
        qos: .utility
    )

    private let lock = NSLock()
    private var container: ModelContainer?

    init(_ container: ModelContainer) {
        self.container = container
    }

    var value: ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        guard let container else {
            preconditionFailure("ModelContainer was already released")
        }
        return container
    }

    func releaseOnUtility() async {
        await withCheckedContinuation { continuation in
            Self.releaseQueue.async { [self] in
                lock.lock()
                let releasedContainer = container
                container = nil
                lock.unlock()
                withExtendedLifetime(releasedContainer) {}
                continuation.resume()
            }
        }
    }
}

private struct RuntimeDefaultsCleanupTrait: TestTrait, SuiteTrait, TestScoping {
    let isRecursive = true

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        defer { FoundationSafety.clearTestRuntimeDefaultsIfNeeded() }
        try await function()
    }
}

@Suite("KEELSTONE App Store Lane", .serialized, RuntimeDefaultsCleanupTrait())
@MainActor
struct AppStoreKeelstoneLaneTests {
    private final class SourceGuardBundleToken {}

    private let vaultBookmarkKey = "epistemos.vaultBookmark"
    private let lastVaultPathKey = "epistemos.lastVaultPath"

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func withUtilityReleasedModelContainer(
        _ operation: @MainActor (ModelContainer) async throws -> Void
    ) async throws {
        let owner = UtilityModelContainerOwner(try makeContainer())
        do {
            try await operation(owner.value)
        } catch {
            await owner.releaseOnUtility()
            throw error
        }
        await owner.releaseOnUtility()
    }

    private func makeTempDirectory(prefix: String = "keelstone-appstore") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeUncreatedTempDirectory(prefix: String = "keelstone-appstore-first-run") -> URL {
        // FirstRunBootstrap intentionally refuses symlinked path components.
        // Darwin's temporary directory begins below /var, which is a symlink,
        // so use the per-user cache directory for this adversarial-safe fixture.
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppStoreKeelstoneLaneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let bundle = Bundle(for: SourceGuardBundleToken.self)
        if let resources = bundle.resourceURL {
            let candidate = resources
                .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw CocoaError(
            .fileNoSuchFile,
            userInfo: [
                NSFilePathErrorKey: relativePath,
                NSLocalizedDescriptionKey: "Repository source fixture was not staged into the test bundle."
            ]
        )
    }

    private func sourceSection(in text: String, startingAt start: String, endingBefore end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text[startRange.upperBound...].range(of: end) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.lowerBound])
    }

    @Test("App Store lane compiles the App Store surface")
    func appStoreLaneCompilesAppStoreSurface() {
        #expect(AppSurface.current == .appStore)
        #expect(AppSurface.current.isSandboxed)
        #expect(!AppSurface.current.allowsSubprocessCapabilities)
    }

    @Test("App Store runtime audit isolation rejects incomplete or production-like roots")
    func appStoreRuntimeAuditIsolationRejectsIncompleteOrProductionLikeRoots() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("Epistemos-AppStoreAuditIsolation-\(UUID().uuidString)", isDirectory: true)
        let applicationSupportRoot = root.appendingPathComponent("Application Support", isDirectory: true)
        let appGroupRoot = root.appendingPathComponent("App Group", isDirectory: true)
        let suiteName = "com.epistemos.audit.runtime.\(UUID().uuidString)"
        let environment = [
            FoundationSafety.applicationSupportOverrideEnvironmentKey: applicationSupportRoot.path,
            FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey: appGroupRoot.path,
            FoundationSafety.auditRuntimeDefaultsSuiteEnvironmentKey: suiteName,
        ]
        defer { try? fileManager.removeItem(at: root) }

        #expect(
            FoundationSafety.auditRuntimeDefaultsSuiteName(
                processInfoEnvironment: environment
            ) == suiteName
        )
        #expect(
            FoundationSafety.auditRuntimeAppGroupDirectory(
                fileManager: fileManager,
                processInfoEnvironment: environment
            )?.path == appGroupRoot.resolvingSymlinksInPath().standardizedFileURL.path
        )
        #expect(
            FoundationSafety.isAuditRuntimeIsolationActive(
                fileManager: fileManager,
                processInfoEnvironment: environment
            )
        )
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: environment
            ) == .active
        )
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: [:]
            ) == .notRequested
        )
        #expect(
            SavedApplicationStatePurger.shouldSuppressRestorableStateAtLaunch(
                processInfoEnvironment: environment
            )
        )
        #expect(
            !SavedApplicationStatePurger.shouldPurgeAtLaunch(
                processInfoEnvironment: environment
            )
        )
        #expect(
            EpistemosDocumentController.shouldSuppressRestorableDocumentReopen(
                processInfoEnvironment: environment
            )
        )
        #expect(
            !VaultSyncService.shouldMigrateLegacyVaultBookmarkDefaults(
                processInfoEnvironment: environment
            )
        )

        var auditWithLegacySkipEnvironment = environment
        auditWithLegacySkipEnvironment["EPISTEMOS_SKIP_VAULT_RESTORE"] = "1"
        #expect(
            !SavedApplicationStatePurger.shouldPurgeAtLaunch(
                processInfoEnvironment: auditWithLegacySkipEnvironment
            )
        )
        #expect(
            SavedApplicationStatePurger.shouldSuppressRestorableStateAtLaunch(
                processInfoEnvironment: auditWithLegacySkipEnvironment
            )
        )

        var invalidSuiteEnvironment = environment
        invalidSuiteEnvironment[FoundationSafety.auditRuntimeDefaultsSuiteEnvironmentKey] =
            "com.epistemos.production"
        #expect(
            !FoundationSafety.isAuditRuntimeIsolationActive(
                fileManager: fileManager,
                processInfoEnvironment: invalidSuiteEnvironment
            )
        )
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: invalidSuiteEnvironment
            ) == .requestedButInvalid
        )

        var incompleteEnvironment = environment
        incompleteEnvironment.removeValue(
            forKey: FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey
        )
        #expect(
            !FoundationSafety.isAuditRuntimeIsolationActive(
                fileManager: fileManager,
                processInfoEnvironment: incompleteEnvironment
            )
        )

        let applicationSupportOnlyEnvironment = [
            FoundationSafety.applicationSupportOverrideEnvironmentKey: applicationSupportRoot.path,
        ]
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: applicationSupportOnlyEnvironment
            ) == .notRequested
        )

        let appGroupOnlyEnvironment = [
            FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey: appGroupRoot.path,
        ]
        let defaultsSuiteOnlyEnvironment = [
            FoundationSafety.auditRuntimeDefaultsSuiteEnvironmentKey: suiteName,
        ]
        let missingDefaultsSuiteEnvironment = [
            FoundationSafety.applicationSupportOverrideEnvironmentKey: applicationSupportRoot.path,
            FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey: appGroupRoot.path,
        ]
        let missingApplicationSupportEnvironment = [
            FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey: appGroupRoot.path,
            FoundationSafety.auditRuntimeDefaultsSuiteEnvironmentKey: suiteName,
        ]
        for incompleteAuditEnvironment in [
            appGroupOnlyEnvironment,
            defaultsSuiteOnlyEnvironment,
            missingDefaultsSuiteEnvironment,
            missingApplicationSupportEnvironment,
        ] {
            #expect(
                FoundationSafety.auditRuntimeIsolationRequestState(
                    fileManager: fileManager,
                    processInfoEnvironment: incompleteAuditEnvironment
                ) == .requestedButInvalid
            )
        }

        var collidingRootsEnvironment = environment
        collidingRootsEnvironment[FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey] =
            applicationSupportRoot.path
        #expect(
            !FoundationSafety.isAuditRuntimeIsolationActive(
                fileManager: fileManager,
                processInfoEnvironment: collidingRootsEnvironment
            )
        )

        var nestedRootsEnvironment = environment
        nestedRootsEnvironment[FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey] =
            applicationSupportRoot
                .appendingPathComponent("Nested App Group", isDirectory: true)
                .path
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: nestedRootsEnvironment
            ) == .requestedButInvalid
        )

        var productionGroupEnvironment = environment
        productionGroupEnvironment[FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey] =
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/group.com.epistemos.shared")
                .path
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: productionGroupEnvironment
            ) == .requestedButInvalid
        )

        var productionSupportEnvironment = environment
        productionSupportEnvironment[FoundationSafety.applicationSupportOverrideEnvironmentKey] =
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Epistemos")
                .path
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: productionSupportEnvironment
            ) == .requestedButInvalid
        )

        var caseVariantSupportEnvironment = environment
        caseVariantSupportEnvironment[FoundationSafety.applicationSupportOverrideEnvironmentKey] =
            root.appendingPathComponent(
                "library/application support/Epistemos",
                isDirectory: true
            ).path
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: caseVariantSupportEnvironment
            ) == .requestedButInvalid
        )

        let protectedSymlinkTarget = root
            .appendingPathComponent("Library/Application Support/Epistemos", isDirectory: true)
        try fileManager.createDirectory(
            at: protectedSymlinkTarget,
            withIntermediateDirectories: true
        )
        let protectedSymlink = root.appendingPathComponent("audit-support-link", isDirectory: true)
        try fileManager.createSymbolicLink(
            at: protectedSymlink,
            withDestinationURL: protectedSymlinkTarget
        )
        var symlinkSupportEnvironment = environment
        symlinkSupportEnvironment[FoundationSafety.applicationSupportOverrideEnvironmentKey] =
            protectedSymlink.path
        #expect(
            FoundationSafety.auditRuntimeIsolationRequestState(
                fileManager: fileManager,
                processInfoEnvironment: symlinkSupportEnvironment
            ) == .requestedButInvalid
        )

        let auditDefaultVault = FirstRunBootstrap.defaultVaultURL(
            fileManager: fileManager,
            processInfoEnvironment: environment
        )
        #expect(
            auditDefaultVault.path == applicationSupportRoot
                .appendingPathComponent("Runtime Audit Vault", isDirectory: true)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
        )
        #expect(
            !EpistemosFont.shouldRegisterExternalReferenceFonts(
                processInfoEnvironment: environment
            )
        )
        #expect(
            !EpistemosFont.shouldRegisterExternalReferenceFonts(
                processInfoEnvironment: [:]
            )
        )
        #expect(
            !AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: false,
                fileManager: fileManager,
                processInfoEnvironment: environment
            )
        )
        #expect(
            AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: false,
                fileManager: fileManager,
                processInfoEnvironment: [:]
            )
        )

        #expect(
            FoundationSafety.runtimeWindowFrameAutosaveName(
                "EpdocDocumentWindow.audit",
                processInfoEnvironment: environment
            ) == nil
        )
        #expect(
            FoundationSafety.runtimeWindowFrameAutosaveName(
                "EpdocDocumentWindow.production",
                processInfoEnvironment: [:]
            ) == "EpdocDocumentWindow.production"
        )

        let auditSavedStateBundleIdentifier = "com.epistemos.audit.test.\(UUID().uuidString)"
        let auditSavedStateDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(
                "\(auditSavedStateBundleIdentifier).savedState",
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: auditSavedStateDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: auditSavedStateDirectory) }
        SavedApplicationStatePurger.purgeIfNeeded(
            bundleIdentifier: auditSavedStateBundleIdentifier,
            fileManager: fileManager,
            processInfoEnvironment: auditWithLegacySkipEnvironment
        )
        #expect(fileManager.fileExists(atPath: auditSavedStateDirectory.path))

        let foundationSource = try loadRepoTextFile("Epistemos/Engine/Extensions.swift")
        let quarantineSource = try loadRepoTextFile("Epistemos/Engine/QuarantineArchive.swift")
        let vaultSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let firstRunSource = try loadRepoTextFile("Epistemos/Vault/FirstRunBootstrap.swift")
        let fontSource = try loadRepoTextFile("Epistemos/Theme/EpistemosFont.swift")
        let bootstrapSource = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let testDefaultsResolver = try #require(sourceSection(
            in: foundationSource,
            startingAt: "static func resolvedRuntimeUserDefaults(",
            endingBefore: "    static func testRuntimeDefaultsSuiteName("
        ))
        #expect(foundationSource.components(separatedBy: "UserDefaults.standard").count == 2)
        #expect(
            foundationSource.contains(
                "Darwin.atexit(clearEpistemosTestRuntimeDefaultsAtProcessExit)"
            )
        )
        #expect(
            foundationSource.contains(
                "private nonisolated func clearEpistemosTestRuntimeDefaultsAtProcessExit()"
            )
        )
        #expect(
            foundationSource.contains(
                "clearTestRuntimeDefaultsIfNeeded(defaults: runtimeUserDefaults)"
            )
        )
        #expect(
            foundationSource.contains(
                "guard auditRuntimeIsolationRequestState() == .notRequested,\n"
                    + "              testRuntimeDefaultsSuiteName() != nil"
            )
        )
        #expect(foundationSource.contains("_ = testRuntimeDefaultsExitCleanupRegistration"))
        let cleanupRegistration = try #require(
            testDefaultsResolver.range(of: "_ = testRuntimeDefaultsExitCleanupRegistration")
        )
        let suiteConstruction = try #require(
            testDefaultsResolver.range(of: "UserDefaults(suiteName: suiteName)")
        )
        #expect(cleanupRegistration.lowerBound < suiteConstruction.lowerBound)
        #expect(!quarantineSource.contains("userDefaults = .standard"))
        #expect(vaultSource.contains("case .active:\n            return nil"))
        #expect(firstRunSource.contains("Runtime Audit Vault"))
        #expect(fontSource.contains("shouldRegisterExternalReferenceFonts"))
        #expect(fontSource.contains("MatrixTypeDisplay-Bold"))
        #expect(fontSource.contains("MatrixDotsDemoRegular"))
        #expect(fontSource.contains("ChonkyPixels"))
        #expect(bootstrapSource.contains("case .active:\n            return false"))
    }

    @Test("App Store runtime audit same-suite handles and App Group remain stable and disposable")
    func appStoreRuntimeAuditDefaultsAndAppGroupRemainStableAndDisposable() throws {
        let fileManager = FileManager.default
        let root = try makeTempDirectory(prefix: "keelstone-runtime-audit-isolation")
        let productionGroup = root.appendingPathComponent("Production Group", isDirectory: true)
        let auditGroup = root.appendingPathComponent("Audit Group", isDirectory: true)
        let legacyGroup = root.appendingPathComponent("Legacy", isDirectory: true)
        let legacyDatabase = legacyGroup.appendingPathComponent("provenance.sqlite")
        let suiteName = "com.epistemos.audit.runtime.\(UUID().uuidString)"
        let environment = [
            FoundationSafety.applicationSupportOverrideEnvironmentKey:
                root.appendingPathComponent("Application Support", isDirectory: true).path,
            FoundationSafety.auditRuntimeAppGroupRootEnvironmentKey: auditGroup.path,
            FoundationSafety.auditRuntimeDefaultsSuiteEnvironmentKey: suiteName,
        ]
        defer {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
            try? fileManager.removeItem(at: root)
        }

        try fileManager.createDirectory(at: legacyGroup, withIntermediateDirectories: true)
        try Data("legacy-group-sentinel".utf8).write(to: legacyDatabase)
        let resolvedAuditDefaults = FoundationSafety.resolvedRuntimeUserDefaults(
            fileManager: fileManager,
            processInfoEnvironment: environment
        )
        #expect(resolvedAuditDefaults !== UserDefaults.standard)

        let firstDefaultsHandle = VaultSyncService.makeDefaultUserDefaultsForTesting(
            processInfoEnvironment: environment
        )
        #expect(firstDefaultsHandle !== UserDefaults.standard)
        firstDefaultsHandle.set("bookmark-sentinel", forKey: "runtime-audit-bookmark-probe")
        let secondDefaultsHandle = VaultSyncService.makeDefaultUserDefaultsForTesting(
            processInfoEnvironment: environment
        )

        #expect(
            secondDefaultsHandle.string(forKey: "runtime-audit-bookmark-probe")
                == "bookmark-sentinel"
        )
        #expect(
            VaultSyncService.shouldRestoreVaultFromBookmark(
                processInfoEnvironment: environment
            )
        )

        var productionProviderCallCount = 0
        let container = AppGroupContainer(
            fileManager: fileManager,
            legacyBaseURL: legacyGroup,
            containerURLProvider: { _ in
                productionProviderCallCount += 1
                return productionGroup
            },
            processInfoEnvironment: environment
        )
        #expect(container.rootURL == auditGroup.resolvingSymlinksInPath().standardizedFileURL)
        try container.ensureLayout()
        try container.migrateLegacyDatabasesIfNeeded()
        #expect(fileManager.fileExists(atPath: auditGroup.path))
        #expect(!fileManager.fileExists(atPath: productionGroup.path))
        #expect(fileManager.fileExists(atPath: legacyDatabase.path))
        #expect(!fileManager.fileExists(atPath: container.provenanceDBURL.path))
        #expect(productionProviderCallCount == 0)

        let testFallbackGroup = root.appendingPathComponent("XCTest Fallback", isDirectory: true)
        let testProviderGroup = root.appendingPathComponent("XCTest Production Group", isDirectory: true)
        var testProviderCallCount = 0
        let testContainer = AppGroupContainer(
            fileManager: fileManager,
            legacyBaseURL: testFallbackGroup,
            containerURLProvider: { _ in
                testProviderCallCount += 1
                return testProviderGroup
            },
            processInfoEnvironment: [
                "XCTestConfigurationFilePath": root
                    .appendingPathComponent("Epistemos.xctestconfiguration")
                    .path,
            ]
        )
        #expect(testContainer.containerURL == nil)
        #expect(testContainer.rootURL.standardizedFileURL.path == testFallbackGroup.standardizedFileURL.path)
        try testContainer.ensureLayout()
        try testContainer.migrateLegacyDatabasesIfNeeded()
        #expect(fileManager.fileExists(atPath: testFallbackGroup.path))
        #expect(!fileManager.fileExists(atPath: testProviderGroup.path))
        #expect(testProviderCallCount == 0)

        let testDefaultsProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let testDefaultsEnvironment = [
            "XCTestConfigurationFilePath": root
                .appendingPathComponent("EpistemosDefaults.xctestconfiguration")
                .path,
        ]
        let testDefaultsSuiteName = try #require(
            FoundationSafety.testRuntimeDefaultsSuiteName(
                processInfoEnvironment: testDefaultsEnvironment,
                processIdentifier: testDefaultsProcessIdentifier
            )
        )
        #expect(
            testDefaultsSuiteName
                == "com.epistemos.test.runtime.\(testDefaultsProcessIdentifier)"
        )
        let testDefaultsPlistURL = try #require(
            FoundationSafety.testRuntimeDefaultsPlistURL(
                fileManager: fileManager,
                processInfoEnvironment: testDefaultsEnvironment,
                processIdentifier: testDefaultsProcessIdentifier
            )
        )
        FoundationSafety.clearTestRuntimeDefaultsIfNeeded(
            fileManager: fileManager,
            processInfoEnvironment: testDefaultsEnvironment,
            processIdentifier: testDefaultsProcessIdentifier
        )
        defer {
            FoundationSafety.clearTestRuntimeDefaultsIfNeeded(
                fileManager: fileManager,
                processInfoEnvironment: testDefaultsEnvironment,
                processIdentifier: testDefaultsProcessIdentifier
            )
        }

        let firstTestDefaultsHandle = FoundationSafety.resolvedRuntimeUserDefaults(
            fileManager: fileManager,
            processInfoEnvironment: testDefaultsEnvironment,
            processIdentifier: testDefaultsProcessIdentifier,
            resetTestDomain: true
        )
        #expect(firstTestDefaultsHandle !== UserDefaults.standard)
        #expect(firstTestDefaultsHandle.object(forKey: "xctest-defaults-sentinel") == nil)
        firstTestDefaultsHandle.set("isolated", forKey: "xctest-defaults-sentinel")
        _ = firstTestDefaultsHandle.synchronize()

        let secondTestDefaultsHandle = FoundationSafety.resolvedRuntimeUserDefaults(
            fileManager: fileManager,
            processInfoEnvironment: testDefaultsEnvironment,
            processIdentifier: testDefaultsProcessIdentifier
        )
        #expect(secondTestDefaultsHandle.string(forKey: "xctest-defaults-sentinel") == "isolated")
        FoundationSafety.clearTestRuntimeDefaultsIfNeeded(
            fileManager: fileManager,
            processInfoEnvironment: testDefaultsEnvironment,
            processIdentifier: testDefaultsProcessIdentifier
        )
        #expect(secondTestDefaultsHandle.object(forKey: "xctest-defaults-sentinel") == nil)
        #expect(!fileManager.fileExists(atPath: testDefaultsPlistURL.path))
    }

    @Test("App Store reconciler does not conflict-copy its own identical live save")
    func appStoreReconcilerRejectsSelfWriteConflictCopy() {
        let incomingBody = "# Current\n\nPersisted from the live editor.\n"
        let staleBaseHash = SDPage.bodyHash("# Previous\n\nOlder base.\n")

        #expect(
            !VaultIndexActor.liveEditorBodyConflictsWithVaultBody(
                liveEditorBody: incomingBody,
                vaultBody: incomingBody,
                lastSyncedBodyHash: staleBaseHash
            )
        )
        #expect(
            VaultIndexActor.liveEditorBodyConflictsWithVaultBody(
                liveEditorBody: "# Current\n\nUnsaved local edit.\n",
                vaultBody: "# Current\n\nIndependent external edit.\n",
                lastSyncedBodyHash: staleBaseHash
            )
        )
        #expect(
            !VaultIndexActor.localDraftConflictsWithVaultBody(
                liveEditorBody: incomingBody,
                localDraftBody: "# Previous\n\nStale staged draft.\n",
                incomingBodyHash: SDPage.bodyHash(incomingBody),
                needsVaultSync: true
            )
        )
        #expect(
            VaultIndexActor.localDraftConflictsWithVaultBody(
                liveEditorBody: nil,
                localDraftBody: "# Current\n\nUnsaved staged draft.\n",
                incomingBodyHash: SDPage.bodyHash(incomingBody),
                needsVaultSync: true
            )
        )
        #expect(
            !VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: incomingBody,
                localDraftBody: "# Previous\n\nStale staged draft.\n",
                vaultBody: incomingBody
            )
        )
        #expect(
            VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: "# Previous\n\nClean editor base.\n",
                localDraftBody: "# Previous\n\nClean staged base.\n",
                vaultBody: incomingBody
            )
        )
        #expect(
            !VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: nil,
                localDraftBody: incomingBody,
                vaultBody: incomingBody
            )
        )
    }

    @Test("App Store live-body lookup ignores stale unrelated text views")
    func appStoreLiveBodyLookupUsesMatchingProseEditor() {
        let rootView = NSView()

        let staleTextView = NSTextView()
        staleTextView.string = "# Previous\n\nStale generic text view.\n"
        rootView.addSubview(staleTextView)

        let (otherScrollView, otherEditor) = ProseTextView2.makeTextKit2()
        otherEditor.pageId = "other-page"
        otherEditor.string = "# Other\n\nUnrelated prose editor.\n"
        rootView.addSubview(otherScrollView)

        let (liveScrollView, liveEditor) = ProseTextView2.makeTextKit2()
        liveEditor.pageId = "target-page"
        liveEditor.string = "# Current\n\n[archive-self-write:live-marker]\n"
        rootView.addSubview(liveScrollView)

        #expect(
            NoteWindowManager.editorBody(in: rootView, matchingPageId: "target-page")
                == liveEditor.string
        )
    }

    @Test("App Store live-body lookup prefers the active same-page editor")
    func appStoreLiveBodyLookupUsesMatchingFirstResponder() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let rootView = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = rootView

        let (staleScrollView, staleEditor) = ProseTextView2.makeTextKit2()
        staleEditor.pageId = "target-page"
        staleEditor.string = "# Previous\n\nStale retained prose editor.\n"
        rootView.addSubview(staleScrollView)

        let (liveScrollView, liveEditor) = ProseTextView2.makeTextKit2()
        liveEditor.pageId = "target-page"
        liveEditor.string = "# Current\n\n[archive-self-write:active-marker]\n"
        rootView.addSubview(liveScrollView)

        #expect(window.makeFirstResponder(liveEditor))
        #expect(
            NoteWindowManager.editorBody(in: window, matchingPageId: "target-page")
                == liveEditor.string
        )
    }

    @Test("App Store local Prose saves do not impersonate external changes")
    func appStoreLocalProseSaveNotificationCarriesOrigin() {
        let savedBody = "# Current\n\n[archive-self-write:durable-local-save]\n"
        let localSave = NoteFileStorage.pageBodyChangeNotification(
            pageId: "target-page",
            origin: .localEditorSave,
            savedBody: savedBody
        )
        let externalChange = NoteFileStorage.pageBodyChangeNotification(
            pageId: "target-page",
            origin: .external,
            savedBody: nil
        )

        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: localSave,
                currentEditorBody: savedBody
            ) == .acceptLocalSave(savedBody)
        )
        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: localSave,
                currentEditorBody: "# Current\n\nUnsaved sibling edit.\n"
            ) == .externalChange
        )
        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: externalChange,
                currentEditorBody: savedBody
            ) == .externalChange
        )
    }

    @Test("App Store Markdown Document keeps live stats after delayed placeholder fallback")
    func appStoreMarkdownDocumentKeepsLiveStatsAfterPlaceholderFallback() async throws {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = "# Loaded Markdown\n\nThe bridge reports real document statistics.\n"

        controller.loadInitialContent(
            emptyJSON,
            title: "Loaded Markdown",
            markdownSource: markdown
        )
        controller.installEditorDispatch { _ in }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(
            .documentStatsChanged(wordCount: 8, characterCount: 57),
            epoch: 1
        )

        try await Task.sleep(for: .milliseconds(350))

        #expect(controller.toolbarModel.wordCount == 8)
        #expect(controller.toolbarModel.characterCount == 57)
    }

    @Test("normal Epistemos scheme launches the MAS target")
    func normalEpistemosSchemeLaunchesMASTarget() throws {
        let project = try loadRepoTextFile("project.yml")
        let defaultScheme = try loadRepoTextFile("Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme")
        let defaultBuildAction = defaultScheme.components(separatedBy: "<TestAction").first ?? defaultScheme

        #expect(project.contains("  Epistemos:\n    build:\n      targets:\n        Epistemos-AppStore: all\n        EpistemosAppStoreKeelstoneTests: [test]"))
        #expect(!project.contains("Epistemos-LegacyDev"))
        #expect(!project.contains("Epistemos-Experimental"))
        #expect(!project.contains("EPISTEMOS_EXPERIMENTAL"))
        #expect(defaultScheme.contains("BlueprintName = \"Epistemos-AppStore\""))
        #expect(defaultScheme.contains("BuildableName = \"Epistemos.app\""))
        #expect(defaultScheme.contains("BlueprintName = \"EpistemosAppStoreKeelstoneTests\""))
        #expect(!defaultScheme.contains("BlueprintName = \"Epistemos\""))
        #expect(!defaultScheme.contains("BlueprintName = \"EpistemosTests\""))
        #expect(!defaultScheme.contains("Epistemos-LegacyDev"))
        #expect(!defaultScheme.contains("Epistemos-Experimental"))
        #expect(defaultBuildAction.contains("BuildableName = \"EpistemosAppStoreKeelstoneTests.xctest\""))
        #expect(defaultBuildAction.contains("buildForRunning = \"NO\""))
        #expect(defaultBuildAction.contains("buildForArchiving = \"NO\""))
    }

    @Test("App Store privacy manifest covers container and user-selected vault timestamps")
    func appStorePrivacyManifestCoversUserSelectedVaultTimestamps() throws {
        let manifestText = try loadRepoTextFile("Epistemos/Resources/PrivacyInfo.xcprivacy")
        let manifestData = try #require(manifestText.data(using: .utf8))
        let manifest = try #require(
            PropertyListSerialization.propertyList(from: manifestData, format: nil)
                as? [String: Any]
        )
        let accessedTypes = try #require(
            manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        )
        let fileTimestampEntry = try #require(accessedTypes.first {
            $0["NSPrivacyAccessedAPIType"] as? String
                == "NSPrivacyAccessedAPICategoryFileTimestamp"
        })
        let reasons = try #require(
            fileTimestampEntry["NSPrivacyAccessedAPITypeReasons"] as? [String]
        )

        #expect(Set(reasons) == ["C617.1", "3B52.1"])
    }

    @Test("Free V1 removes the retired Agent Home route instead of concealing it")
    func freeV1RemovesRetiredAgentHomeRoute() throws {
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let landingFeatures = try loadRepoTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let pixelSurface = try loadRepoTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let homeContent = try #require(sourceSection(
            in: uiState,
            startingAt: "enum HomeContent: Equatable, Sendable {",
            endingBefore: "    var homeContent: HomeContent = .greeting"
        ))
        let featureDefinition = try #require(sourceSection(
            in: landingFeatures,
            startingAt: "enum LandingFeatureButton: String, CaseIterable, Identifiable {",
            endingBefore: "struct LandingFeatureButtonTile: View"
        ))
        let glyphDefinition = try #require(sourceSection(
            in: pixelSurface,
            startingAt: "enum PixelGlyphKind {",
            endingBefore: "struct PixelPanelBackground: View"
        ))

        for retainedCase in [
            "case greeting",
            "case graph",
            "case document(HomeDocumentSelection)",
            "case meeting",
            "case arxiv",
            "case browser",
        ] {
            #expect(homeContent.contains(retainedCase))
        }
        #expect(!homeContent.contains("case agent"))

        for retiredLandingToken in [
            "case .agent:",
            "homeContent = .agent",
            "agentPageTitle",
            "agentSurface",
            "JuneAgentSurfaceView",
            "EPISTEMOS_OPEN_AGENT_ON_LAUNCH",
        ] {
            #expect(!landing.contains(retiredLandingToken))
        }
        #expect(!featureDefinition.contains("case agent"))
        #expect(!glyphDefinition.contains("case agent"))
        #expect(!rootView.contains("JuneAgentNavBar"))

        #expect(landing.contains("register(.landingHome)"))
        #expect(featureDefinition.contains("case .browser: .agent"))
        #expect(!ProductCapabilityPolicy.isAvailable(.paidAgent))
    }

    #if !EPISTEMOS_FREE_V1
    @Test("App Store lane accepts WebKit numeric JSON-RPC ids for June sessions")
    func appStoreLaneAcceptsWebKitNumericJSONRPCIDsForJuneSessions() throws {
        let gateway = JuneAgentGateway()
        var deliveredFrames: [String] = []
        gateway.deliver = { deliveredFrames.append($0) }

        gateway.handleFrame(#"{"jsonrpc":"2.0","id":1,"method":"session.create","params":{"title":"Smoke"}}"#)

        let reply = try #require(deliveredFrames.first)
        let data = try #require(reply.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["id"] as? Int == 1)
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["session_id"] as? String != nil)

        deliveredFrames.removeAll()
        gateway.handleFrame(#"{"jsonrpc":"2.0","id":true,"method":"session.create","params":{"title":"Rejected"}}"#)
        #expect(deliveredFrames.isEmpty)
    }
    #endif

    @Test("App Store lane preserves safe agent_core FFI diagnostics")
    func appStoreLanePreservesSafeAgentCoreFFIDiagnostics() {
        #if canImport(agent_coreFFI)
        let safe = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "provider error: OPENAI_API_KEY is not configured"),
            fallback: "agent_core MAS run failed"
        )
        #expect(safe == "agent_core MAS run failed: provider error: OPENAI_API_KEY is not configured")
        #expect(!safe.contains("domain="))

        let pathBearing = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "Failed to open vault: /Users/jojo/PrivateVault"),
            fallback: "agent_core MAS run failed"
        )
        #expect(pathBearing == "agent_core MAS run failed: Failed to open vault: <redacted-path>")
        #expect(!pathBearing.contains("domain="))
        #expect(!pathBearing.contains("/Users/jojo"))
        #expect(!pathBearing.contains("PrivateVault"))

        let credentialBearing = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "provider rejected bearer sk-private-value"),
            fallback: "agent_core MAS run failed"
        )
        #expect(credentialBearing.contains("domain=Epistemos.AgentErrorFfi"))
        #expect(!credentialBearing.contains("sk-private-value"))
        #endif

        let callbackPath = EngineLogDiagnostics.agentCoreCallbackMessage(
            "Failed to create session folder: /Users/jojo/PrivateVault/sessions",
            fallback: "agent_core MAS run failed"
        )
        #expect(callbackPath == "agent_core MAS run failed: Failed to create session folder: <redacted-path>")

        let callbackCredential = EngineLogDiagnostics.agentCoreCallbackMessage(
            "authorization bearer sk-private-value",
            fallback: "agent_core MAS run failed"
        )
        #expect(callbackCredential == "agent_core MAS run failed")
    }

    @Test("Free V1 excludes agent_core credential-environment choreography")
    func freeV1ExcludesAgentCoreCredentialEnvironmentChoreography() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let runtimeState = try loadRepoTextFile("Epistemos/State/ProductRuntimeState.swift")
        let globalAgentTypes = try #require(sourceSection(
            in: bootstrap,
            startingAt: "#if !EPISTEMOS_FREE_V1\nnonisolated struct StartupAutoDiscoveryKeyMapping",
            endingBefore: "@MainActor\nfinal class AppBootstrap"
        ))
        let agentEnvironmentRuntime = try #require(sourceSection(
            in: bootstrap,
            startingAt: "#if !EPISTEMOS_FREE_V1\n    private nonisolated static var agentCoreManagedOAuthEnvironmentVars",
            endingBefore: "    #if !EPISTEMOS_FREE_V1\n    nonisolated static func startupAutoDiscoveryReportForTesting"
        ))

        #expect(globalAgentTypes.contains("private actor AgentCoreEnvironmentScopeGate"))
        #expect(agentEnvironmentRuntime.contains("nonisolated static func withScopedAgentCoreEnvironment"))
        #expect(bootstrap.contains("#if !EPISTEMOS_FREE_V1\n        if ProductCapabilityPolicy.isAvailable(.models)"))
        #expect(!runtimeState.contains("FreeV1RuntimeState"))
    }

    @Test("App Store lane keeps clean Markdown Document switches read-only")
    func appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly() throws {
        let surface = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let sharedTests = try loadRepoTextFile("EpistemosTests/EditorProvenanceStoreTests.swift")
        let bridgeTests = try loadRepoTextFile("EpistemosTests/EpdocEditorBridgeTests.swift")
        let largeDocumentFixture = try loadRepoTextFile("docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md")
        let flushSection = try #require(sourceSection(
            in: surface,
            startingAt: "func flushPendingMarkdown() async -> Bool",
            endingBefore: "func flushPendingProvenanceWrites() async"
        ))
        let currentEditorBodySection = try #require(sourceSection(
            in: workspace,
            startingAt: "private func currentEditorBody(for page: SDPage) -> String?",
            endingBefore: "@discardableResult\n    private func flushCurrentEditor"
        ))

        #expect(surface.contains("enum MarkdownDocumentSurfacePerformancePolicy"))
        #expect(largeDocumentFixture.utf8.count >= 450_000)
        #expect(largeDocumentFixture.split(whereSeparator: \.isWhitespace).count >= 60_000)
        #expect(surface.contains("static let autosaveQuietWindow: Duration = .seconds(2)"))
        #expect(surface.contains("reloadSamePageExternalMarkdown = true"))
        #expect(surface.contains("guard MarkdownDocumentSurfacePerformancePolicy.reloadSamePageExternalMarkdown else"))
        #expect(surface.contains("let isActive: Bool"))
        #expect(surface.contains(".onChange(of: isActive)"))
        #expect(surface.contains("pendingExternalMarkdownReload"))
        #expect(surface.contains("if isActive, let pending = pendingExternalMarkdownReload"))
        #expect(surface.contains("shouldRecoverCleanEmptyInitialLoad"))
        #expect(surface.contains("visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(markdown)"))
        #expect(surface.contains("preferredNonEmptyRememberedMarkdown(hostMarkdown: markdown)"))
        #expect(surface.contains("controller.latestMarkdownSnapshot,\n            latestMarkdown,\n            hostMarkdown"))
        #expect(surface.contains("markdown: coordinator.markdownForAssistContext(hostMarkdown: markdown)"))
        #expect(surface.contains("guard isDirty else { return hostMarkdown }"))
        #expect(bridgeTests.contains("func cleanEpdocAssistContextUsesCanonicalHostMarkdown()"))
        #expect(surface.contains("let becameActive = !wasActive && isActive"))
        #expect(surface.contains("shouldRecoverVisibleBlankOnReactivation"))
        #expect(surface.contains("controller.toolbarModel.characterCount == 0"))
        #expect(surface.contains("shouldProbeVisibleMarkdownOnCleanReactivation"))
        #expect(surface.contains("requestCleanReactivationMarkdownProbe(expectedMarkdown: markdown)"))
        #expect(workspace.contains("let documentSurfaceIsAvailable = noteModeOptions(for: page).modes.contains(.document)"))
        #expect(workspace.contains("noteDocumentSurface(page: page, isActive: resolvedMode == .document)"))
        #expect(workspace.contains(".opacity(resolvedMode == .document ? 1 : 0)"))
        #expect(workspace.contains("noteNonDocumentEditorSurface(page: page, availableSize: availableSize)"))
        #expect(workspace.contains("isSpuriousCleanEmptySnapshot"))
        #expect(workspace.contains("lensSwitchBody(candidate: currentEditorBody(for: page), baseline: baseline)"))
        #expect(workspace.contains("ignored empty editor snapshot during lens switch"))
        #expect(workspace.contains("body.isEmpty && !persistedBody.isEmpty"))
        #expect(!workspace.contains("body.isEmpty && !persistedBody.isEmpty && !noteSession.state.needsWriteLease"))
        #expect(currentEditorBodySection.contains("switch resolvedNoteMode(for: page)"))
        #expect(currentEditorBodySection.contains("case .edit:\n            return NoteEditorViewFinder.findEditorTextView(for: pageId)?.string"))
        #expect(currentEditorBodySection.contains("case .document, .source, .preview:"))
        #expect(!currentEditorBodySection.hasPrefix("if let responder = NoteEditorViewFinder.findEditorTextView"))
        #expect(workspace.contains("isActive: isActive"))
        #expect(chrome.contains("pendingInitialMarkdownEmptyEchoRetries"))
        #expect(chrome.contains("pendingCleanReactivationMarkdownProbe"))
        #expect(chrome.contains("verifiedCleanReactivationMarkdown"))
        #expect(chrome.contains("requestCleanReactivationMarkdownProbe(expectedMarkdown: String)"))
        #expect(chrome.contains("guard verifiedCleanReactivationMarkdown != expectedMarkdown else"))
        #expect(chrome.contains("reloadMarkdownSourceForCleanReactivation"))
        #expect(chrome.contains("preferredNonEmptyMarkdownSource"))
        #expect(chrome.contains("markdownBodyIsEmpty"))
        #expect(chrome.contains("re-pushing non-empty Markdown source"))
        #expect(chrome.contains("Epdoc clean Markdown snapshot was empty; re-pushing non-empty host Markdown source"))
        #expect(chrome.contains("clean reactivation probe returned empty content"))
        #expect(chrome.contains("suppressing empty save over non-empty source"))
        #expect(chrome.contains("prepareForWebContentProcessRecovery"))
        #expect(chrome.contains("reloading editor with host Markdown recovery source"))
        #expect(chrome.contains("webView.load(URLRequest(url: url))"))
        #expect(chrome.contains("public func detachEditorDispatch()"))
        #expect(chrome.contains("editorIsReady = false"))
        #expect(chrome.contains("didPushInitialContent = false"))
        #expect(chrome.contains("pendingCleanReactivationMarkdownProbe = nil"))
        #expect(!chrome.contains("editor blanked; reopen the note to recover"))
        #expect(surface.contains("ignored empty direct editor snapshot over non-empty Markdown source"))
        #expect(surface.contains("Task.sleep(for: MarkdownDocumentSurfacePerformancePolicy.autosaveQuietWindow)"))
        #expect(flushSection.contains("let hadPendingSave = saveTask != nil"))
        #expect(flushSection.contains("guard hadPendingSave || hadOutstandingWrite || controller.toolbarModel.isDirty else"))
        #expect(flushSection.contains("let hasPendingMarkdownSnapshot = latestMarkdown != lastFlushedMarkdown"))
        #expect(flushSection.contains("if !hasPendingMarkdownSnapshot"))
        #expect(flushSection.contains("return true"))
        #expect(flushSection.contains("requestStableCurrentMarkdownSnapshotFromEditor()"))
        #expect(flushSection.contains("requestFreshMarkdownSnapshotIfPossible()"))
        #expect(surface.contains("private func requestCurrentMarkdownSnapshotFromEditor() async -> Bool"))
        #expect(surface.contains("private var markdownWriteTail: Task<Bool, Never>?"))
        #expect(surface.contains("_ = await predecessor.value"))
        #expect(surface.contains("if self.markdownRevision == revision"))
        #expect(surface.contains("private var markdownSaveWorkerGeneration: UInt64 = 0"))
        #expect(surface.contains("guard saveTask == nil else { return }"))
        #expect(surface.contains("guard debounceGeneration == self.markdownDebounceGeneration else { continue }"))
        #expect(surface.contains("let markdownToSave = self.latestMarkdown"))
        #expect(surface.contains("private func cancelMarkdownSaveWorker()"))
        #expect(!surface.contains("saveTask?.cancel()\n        saveTask = Task"))
        #expect(surface.contains("private var markdownFlushTask: Task<Bool, Never>?"))
        #expect(sharedTests.contains("cleanMarkdownDocumentSurfaceSwitchesDoNotSaveNormalizedSnapshots"))
        #expect(sharedTests.contains("samePageMarkdownUpdatesDoNotRemountTheRichDocumentTree"))
        #expect(sharedTests.contains("samePageMarkdownDocumentReloadsWhenAsyncBodyArrivesAfterEmptyMount"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceReloadsExternalLensChangesOnReactivation"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceRepushesNonEmptyMarkdownWhenBlankOnReactivation"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceProbesStaleStatsAndSuppressesBlankReactivationSnapshots"))
        #expect(sharedTests.contains("verifiedCleanMarkdownDocumentSurfaceReactivationSkipsRepeatedSnapshotProbe"))
        #expect(bridgeTests.contains("chromeControllerRepushesNonEmptyMarkdownSourceAfterEmptyInitialEcho"))
        #expect(bridgeTests.contains("markdownDocumentSurfaceReactivatesFromNonEmptyHostWhenWebKitSnapshotWasEmpty"))
        #expect(bridgeTests.contains("chromeControllerRecoversLastMarkdownSourceAfterWebContentTermination"))
        #expect(sharedTests.contains("| --- | --- |"))
        #expect(sharedTests.contains("savedMarkdown.isEmpty"))
    }

    @Test("App Store lane bounds Epdoc notebook manifest parsing on large normal notes")
    func appStoreLaneBoundsEpdocNotebookManifestParsingOnLargeNormalNotes() {
        let lateManifest = String(repeating: "ordinary body line\n", count: 5_000) + """
        ```epistemos-notebook
        version: 1
        tab: id=11111111-1111-4111-8111-111111111111 type=sheet version=1 title="Too Late" ref="dataset:late.dataset.md"
        ```
        """

        let parsed = EpdocNotebookManifest.parse(in: lateManifest)

        #expect(parsed.tabs.isEmpty)
        #expect(parsed.source == .none)
    }

    @Test("App Store lane keeps same-page Epdoc updates from remounting rich document state")
    func appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let externalMarkdown = "| A | B |\n| --- | --- |\n| 1 | 2 |\n\nExternal line\n"

        coordinator.configure(
            pageId: "same-page-appstore",
            title: "Same Page App Store",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/same-page-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-appstore",
            title: "Same Page App Store",
            markdown: externalMarkdown,
            theme: .light,
            noteRelativePath: "notes/same-page-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(
            commands == [
                .setMarkdownForLoad(markdown: externalMarkdown, epoch: 2),
                .focusStart,
            ]
        )
    }

    @Test("App Store lane reloads same-page Epdoc when async body arrives after empty mount")
    func appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let loadedMarkdown = """
        ---
        title: Loaded Later
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "same-page-empty-then-loaded-appstore",
            title: "Loaded Later",
            markdown: "",
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-empty-then-loaded-appstore",
            title: "Loaded Later",
            markdown: loadedMarkdown,
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: loadedMarkdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == loadedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane re-pushes non-empty Epdoc Markdown when initial bridge echo is empty")
    func appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        ---
        title: App Store table
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store table", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(savedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1)])
    }

    @Test("App Store lane re-pushes Epdoc Markdown after clean post-load blank snapshot")
    func appStoreLaneRepushesEpdocMarkdownAfterCleanPostLoadBlankSnapshot() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # App Store Post-load Blank Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store Post-load Blank Proof", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: markdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(savedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
    }

    @Test("App Store lane recovers Epdoc after WebKit blanking with last Markdown source")
    func appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let editedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Edited table"}]}]}"#
            .data(using: .utf8)!
        let loadedMarkdown = "| A | B |\n| - | - |\n| 1 | 2 |\n"
        let editedMarkdown = "| A | B |\n| - | - |\n| 3 | 4 |\n"
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store table", markdownSource: loadedMarkdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: loadedMarkdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: editedJSON), epoch: 1)
        controller.handleBridgeMessage(.markdownDidChange(markdown: editedMarkdown, writeback: nil), epoch: 1)
        commands.removeAll()

        #expect(savedMarkdown == [editedMarkdown])
        #expect(controller.prepareForWebContentProcessRecovery())
        #expect(controller.currentLoadEpoch == 2)
        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
        #expect(controller.toolbarModel.isDirty)

        controller.handleBridgeMessage(.editorReady)

        #expect(commands == [.setMarkdownForLoad(markdown: editedMarkdown, epoch: 2), .focusStart])
    }

    @Test("App Store lane reloads hidden Epdoc only when another lens changed markdown")
    func appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(commands.isEmpty)

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(!commands.isEmpty)
    }

    @Test("App Store lane repushes hidden blank Epdoc on Document reactivation")
    func appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-blank-appstore",
            title: "Hidden Blank App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(coordinator.controller.toolbarModel.characterCount == 0)

        coordinator.configure(
            pageId: "hidden-blank-appstore",
            title: "Hidden Blank App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store Epdoc bridge flushes survive inactive display-link starvation")
    func appStoreEpdocBridgeFlushesSurviveInactiveDisplayLinkStarvation() throws {
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let scheduler = try #require(sourceSection(
            in: chrome,
            startingAt: "private func scheduleOutboundFlush()",
            endingBefore: "    @objc private func handleOutboundDisplayLinkTick"
        ))
        let flush = try #require(sourceSection(
            in: chrome,
            startingAt: "private func flushOutboundQueue()",
            endingBefore: "        // No explicit deinit"
        ))
        let shutdown = try #require(sourceSection(
            in: chrome,
            startingAt: "func shutdown()",
            endingBefore: "        nonisolated func userContentController("
        ))

        #expect(scheduler.contains("outboundFallbackTask = Task { @MainActor [weak self] in"))
        #expect(scheduler.contains("Task.sleep(for: EpdocOutboundFlushPolicy.occludedFallbackDelay)"))
        #expect(scheduler.contains("guard self.outboundFlushScheduled else { return }"))
        #expect(scheduler.contains("self.flushOutboundQueue()"))
        #expect(flush.contains("outboundFallbackTask?.cancel()"))
        #expect(flush.contains("outboundFallbackTask = nil"))
        #expect(shutdown.contains("outboundFallbackTask?.cancel()"))
        #expect(shutdown.contains("outboundFallbackTask = nil"))
    }

    @Test("App Store lane recovers hidden Epdoc when WebKit snapshot is empty but host Markdown is non-empty")
    func appStoreLaneRecoversHiddenEpdocWhenWebKitSnapshotIsEmptyButHostMarkdownIsNonEmpty() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Host Recovery Source

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "appstore-empty-webkit-reactivation",
            title: "App Store Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/appstore-empty-webkit-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        coordinator.controller.loadInitialContent(
            emptyJSON,
            title: "App Store Host Recovery Source",
            markdownSource: ""
        )
        commands.removeAll()

        coordinator.configure(
            pageId: "appstore-empty-webkit-reactivation",
            title: "App Store Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/appstore-empty-webkit-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 3), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane re-pushes Epdoc Markdown after WebView remount")
    func appStoreLaneRepushesEpdocMarkdownAfterWebViewRemount() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # Remount Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []

        controller.loadInitialContent(emptyJSON, title: "Remount Proof", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        controller.detachEditorDispatch()
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(!controller.toolbarModel.isDirty)
    }

    @Test("App Store lane refuses empty direct Epdoc flush over non-empty Markdown")
    func appStoreLaneRefusesEmptyDirectEpdocFlushOverNonEmptyMarkdown() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []
        let markdown = """
        # Direct Snapshot Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "direct-empty-snapshot-appstore",
            title: "Direct Snapshot Proof",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/direct-empty-snapshot-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installMarkdownSnapshotProvider {
            ""
        }
        coordinator.controller.toolbarModel.isDirty = true

        let didFlush = await coordinator.flushPendingMarkdown()

        #expect(!didFlush)
        #expect(savedMarkdown.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane probes stale Epdoc stats and suppresses blank reactivation snapshots")
    func appStoreLaneProbesStaleEpdocStatsAndSuppressesBlankReactivationSnapshots() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []
        var savedJSON: [Data] = []
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # App Store Stale Stats Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.onContentChanged = { savedJSON.append($0) }
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 8, characterCount: 72), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])

        coordinator.controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(commands == [.flushDocumentSnapshot, .setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(savedMarkdown.isEmpty)
        #expect(savedJSON.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane skips repeated clean Epdoc reactivation probe after verified snapshot")
    func appStoreLaneSkipsRepeatedCleanEpdocReactivationProbeAfterVerifiedSnapshot() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Verified Reactivation

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let normalizedMarkdown = markdown.replacingOccurrences(of: "| - | - |", with: "| --- | --- |")

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 8, characterCount: 72), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: normalizedMarkdown, writeback: nil), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == normalizedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane keeps editor typing and surface switches off heavy outline paths")
    func appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let codeDebouncer = try loadRepoTextFile("Epistemos/Engine/CodeEditorContentDebouncer.swift")
        let coreEditorCoordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let proseBridge = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let typingRefresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func refreshVisibleEditorMetrics()",
            endingBefore: "    private func scheduleMetricsRefresh("
        ))
        let metricsRefresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func scheduleMetricsRefresh(",
            endingBefore: "    private func captureSelectionAndOpenIdeas()"
        ))

        #expect(workspace.contains("static let liveTypingMetricsQuietWindow: Duration = .milliseconds(900)"))
        #expect(workspace.contains("static let liveTypingRefreshesHeavyOutlines = false"))
        #expect(workspace.contains("static let graphEmbeddedInitialRefreshesHeavyOutlines = false"))
        #expect(workspace.contains("static let nonEditOutlineOverlayEnabled = false"))
        #expect(workspace.contains("try? await Task.sleep(for: NoteWorkspacePerformancePolicy.liveTypingMetricsQuietWindow)"))
        #expect(typingRefresh.contains("includeHeavyOutlines: NoteWorkspacePerformancePolicy.liveTypingRefreshesHeavyOutlines"))
        #expect(metricsRefresh.contains("includeHeavyOutlines: Bool = true"))
        #expect(metricsRefresh.contains("if includeHeavyOutlines && deterministicOutlineState.isEnabled"))
        #expect(metricsRefresh.contains("if includeHeavyOutlines {\n                // Slice 3 cutover"))
        #expect(workspace.contains("includeHeavyOutlines: shouldRunHeavyOutlineWork(for: page)"))
        #expect(workspace.contains("private func shouldRunHeavyOutlineWork(for page: SDPage) -> Bool"))
        #expect(workspace.contains("return NoteWorkspacePerformancePolicy.graphEmbeddedInitialRefreshesHeavyOutlines"))
        #expect(workspace.contains("if let page = pages.first,\n                   shouldMountOutlineOverlay(for: page)"))
        #expect(workspace.contains("private func shouldMountOutlineOverlay(for page: SDPage) -> Bool"))
        #expect(workspace.contains("guard !presentation.usesGraphEmbeddedChrome else {\n            return false\n        }"))
        #expect(workspace.contains("return NoteWorkspacePerformancePolicy.nonEditOutlineOverlayEnabled"))
        #expect(workspace.contains("case .edit:\n            return tocItems"))
        #expect(!workspace.contains("return tocItems.isEmpty ? nil : tocItems"))
        #expect(workspace.contains("return markdownSourceFallbackContent(for: page, filePath: route.filePath)"))
        #expect(codeEditor.contains("static let textSnapshotPublishDelay: Duration = .milliseconds(140)"))
        #expect(codeEditor.contains("private func scheduleTextSnapshotPublish()"))
        #expect(codeEditor.contains("@State private var textSnapshotRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard textSnapshotTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == textSnapshotRevision else { continue }"))
        #expect(codeEditor.contains("try? await Task.sleep(for: CodeEditorPerformancePolicy.textSnapshotPublishDelay)"))
        #expect(codeEditor.contains("scheduleTextSnapshotPublish()"))
        #expect(!codeEditor.contains("textSnapshotTask?.cancel()\n        textSnapshotTask = Task"))
        #expect(codeEditor.contains("@State private var livePreviewRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard livePreviewTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == livePreviewRevision else { continue }"))
        #expect(codeEditor.contains("scheduleLivePreviewUpdate()"))
        #expect(!codeEditor.contains("scheduleLivePreviewUpdate(for: newText)"))
        #expect(codeEditor.contains("@State private var outlineRefreshRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard outlineRefreshTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == outlineRefreshRevision else { continue }"))
        #expect(codeEditor.contains("scheduleOutlineRefresh()"))
        #expect(!codeEditor.contains("scheduleOutlineRefresh(for: newText)"))
        #expect(codeDebouncer.contains("defaultQuietWindowMs: Int = 900"))
        #expect(proseTextView.contains("proseReparseDebounceWindow(characterCount: Int)"))
        #expect(proseTextView.contains("case ..<80_000:\n            0.16"))
        #expect(proseTextView.contains("default:\n            0.28"))
        #expect(proseTextView.contains("deadline: .now() + debounceWindow"))
        #expect(proseTextView.contains("static let renderedTableOverlayRefreshDelay: Duration = .milliseconds(220)"))
        #expect(proseBridge.contains("private var bindingSyncRevision: UInt64 = 0"))
        #expect(proseBridge.contains("private var dataDetectionRevision: UInt64 = 0"))
        #expect(proseBridge.contains("guard bindingSyncTask == nil else { return }"))
        #expect(proseBridge.contains("guard dataDetectionTask == nil else { return }"))
        #expect(proseBridge.contains("guard scheduledRevision == self.bindingSyncRevision else { continue }"))
        #expect(proseBridge.contains("guard scheduledRevision == self.dataDetectionRevision else { continue }"))
        #expect(proseBridge.contains("debouncedBindingSync()"))
        #expect(proseBridge.contains("scheduleDataDetection()"))
        #expect(!proseBridge.contains("debouncedBindingSync(newText)"))
        #expect(!proseBridge.contains("scheduleDataDetection(newText)"))
        #expect(prose.contains("let onEditStarted: @MainActor () -> Void"))
        #expect(prose.contains("guard newValue != lastPersistedBody else { return }\n            onEditStarted()"))
        #expect(workspace.contains("themeOverride: noteWorkspaceTheme,\n                contentWidthMode: contentWidthMode,\n                onEditStarted: {\n                    markEditorDirtyBeforeDebouncedSave()"))
        #expect(!codeEditor.contains("if isEditable {\n                    onTextSnapshot?(newText)"))
        #expect(coreEditorCoordinator.contains("const textSnapshotDelays = {"))
        #expect(coreEditorCoordinator.contains("document.addEventListener(\"input\", scheduleTextSnapshot, true);"))
        #expect(coreEditorCoordinator.contains("document.addEventListener(\"selectionchange\", scheduleMetadataSnapshot, true);"))
        #expect(coreEditorCoordinator.contains("payload.text = text;"))
        #expect(coreEditorCoordinator.contains("let contentDirty = { value: false };"))
        #expect(coreEditorCoordinator.contains("contentDirty.value = true;"))
        #expect(coreEditorCoordinator.contains("if (contentDirty.value)"))
        #expect(!coreEditorCoordinator.contains("if (contentDirty) {"))
        #expect(coreEditorCoordinator.contains("private var didReportPendingContentDirty = false"))
        #expect(coreEditorCoordinator.contains("self.onContentDirty?()"))
        #expect(workspace.contains("onEditStarted: {\n                markDocumentEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("@State private var documentEditorRevision: UInt64 = 0"))
        #expect(!coreEditorCoordinator.contains("const contentDirty = false;"))
        #expect(coreEditorCoordinator.contains("hasPendingEditorTextSnapshot"))
        #expect(!coreEditorCoordinator.contains("setInterval(() => postSnapshot(\"snapshot\"), 250);"))
        #expect(vaultSync.contains("private var graphPageMutationRefreshTask: Task<Void, Never>?"))
        #expect(vaultSync.contains("case .vaultPageChanged:\n            scheduleGraphRefreshAfterPageMutation()"))
        #expect(vaultSync.contains("private func scheduleGraphRefreshAfterPageMutation()"))
        #expect(!vaultSync.contains("private func publishVaultMutation(_ event: AppEvent) {\n        vaultMutationEpoch &+= 1\n        AppBootstrap.shared?.graphState.needsRefresh = true"))
    }

    @Test("App Store lane clears stale clean lens snapshots after persisted reload")
    func appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let refresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func schedulePersistedBodyRefresh(for page: SDPage?)",
            endingBefore: "    private func persistedBodyFor("
        ))
        let invalidator = try #require(sourceSection(
            in: workspace,
            startingAt: "private func clearCleanModeBodySnapshotIfStale",
            endingBefore: "    private func persistedBodyFor("
        ))

        #expect(refresh.contains("modeBodySnapshot = nil"))
        #expect(refresh.contains("clearCleanModeBodySnapshotIfStale(for: pageId, reloadedBody: body)"))
        #expect(invalidator.contains("snapshot.pageId == pageId"))
        #expect(invalidator.contains("snapshot.body != reloadedBody"))
        #expect(invalidator.contains("let isEmptySnapshotOverLoadedBody = snapshot.body.isEmpty && !reloadedBody.isEmpty"))
        #expect(invalidator.contains("guard isEmptySnapshotOverLoadedBody || !noteSession.state.needsWriteLease else"))
        #expect(invalidator.contains("modeBodySnapshot = nil"))
    }

    @Test("App Store lane renders local editor sessions editable before onAppear")
    func appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sessionMachine = try loadRepoTextFile("Epistemos/Views/Notes/NoteSessionStateMachine.swift")
        let focusedTests = try loadRepoTextFile("EpistemosTests/NoteSessionStateMachineTests.swift")
        let inputGate = try #require(sourceSection(
            in: workspace,
            startingAt: "private var editorSurfacesAcceptInput: Bool",
            endingBefore: "    private func shouldMountOutlineOverlay"
        ))

        #expect(inputGate.contains("noteSession.canWrite || noteSession.currentOwnerID == nil"))
        #expect(workspace.contains("isEditable: editorSurfacesAcceptInput"))
        #expect(!workspace.contains("isEditable: noteSession.canWrite"))
        #expect(workspace.contains("noteSession.configureLeaseStore("))
        #expect(workspace.contains("_ = noteSession.open()"))
        #expect(workspace.contains("@State private var noteSessionLifecycleGeneration: UInt64 = 0"))
        #expect(workspace.contains("noteSessionLifecycleGeneration &+= 1"))
        #expect(workspace.contains("let teardownGeneration = noteSessionLifecycleGeneration"))
        #expect(workspace.contains("guard noteSessionLifecycleGeneration == teardownGeneration else { return }"))
        #expect(workspace.contains("_ = noteSession.open()\n                _ = noteSession.acquireCleanLeaseHandoffIfAvailable()"))
        #expect(!workspace.contains("if presentation.usesGraphEmbeddedChrome {\n                    _ = noteSession.acquireCleanLeaseHandoffIfAvailable()"))
        #expect(workspace.contains("guard beginNoteSessionWrite(reason: .idleDebounce) else { return false }"))
        #expect(workspace.contains("private func beginNoteSessionWrite(reason: NoteSessionSaveReason) -> Bool"))
        #expect(sessionMachine.contains("func registerSession(_ session: NoteSessionStateMachine)"))
        #expect(sessionMachine.contains("func acquireCleanLeaseHandoffIfAvailable() -> Bool"))
        #expect(sessionMachine.contains("func acquireOrHandoffCleanOwner("))
        #expect(sessionMachine.contains("ownerCanHandoffCleanly(noteID: noteID, ownerID: owner)"))
        #expect(sessionMachine.contains("refreshRegisteredSessions(for: noteID)"))
        #expect(sessionMachine.contains("clearInactiveStoredOwnerIfNeeded(noteID: noteID, sessionID: sessionID, store: store)"))
        #expect(sessionMachine.contains("activeSessionIDs"))
        #expect(sessionMachine.contains("activeSessionIDs.remove(ownerID)"))
        #expect(sessionMachine.contains("return false"))
        #expect(sessionMachine.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(sessionMachine.contains("MAS relaunches must not trust a persisted owner solely because a PID"))
        #expect(sessionMachine.contains("sessionID: String = NoteSessionLeaseRegistry.makeSessionID()"))
        #expect(focusedTests.contains("relaunchReclaimsOrphanedPersistedLeaseSoSourceStaysEditable"))
        #expect(focusedTests.contains("deallocatedCleanOwnerDoesNotKeepGraphSourceEditorsReadOnly"))
        #expect(focusedTests.contains("legacy-orphan"))
        #expect(sessionMachine.contains("resetInMemoryLeaseRegistryForTests"))
    }

    @Test("App Store lane retries restored Source reads after vault restore")
    func appStoreLaneRetriesRestoredSourceReadsAfterVaultRestore() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let refresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func scheduleCodeFileBodyRefresh(for page: SDPage?)",
            endingBefore: "    private func currentSourceRouteMatches(pageId: String, filePath: String) -> Bool"
        ))

        #expect(workspace.contains(".onChange(of: vaultSync.vaultURL?.standardizedFileURL.path)"))
        #expect(workspace.contains("schedulePersistedBodyRefresh(for: pages.first)\n                scheduleCodeFileBodyRefresh(for: pages.first)"))
        #expect(refresh.contains("guard let vaultURL = vaultSync.vaultURL else"))
        #expect(refresh.contains("codeFileBodySnapshot = CodeFileBodySnapshot"))
        #expect(!refresh.contains("refusing async code file read with no active vault"))
        #expect(refresh.contains("CodeFileService.readCodeFileAsync("))
        #expect(workspace.contains("let currentRoute = sourceEditorRoute(for: currentPage)"))
        #expect(!workspace.contains("let currentRoute = sourceFileRoute(for: currentPage)"))
    }

    @Test("App Store lane reclaims orphaned Source lease after relaunch")
    func appStoreLaneReclaimsOrphanedSourceLeaseAfterRelaunch() throws {
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)

        let firstLaunch = NoteSessionStateMachine(noteID: "appstore-note-relaunch", sessionID: "legacy-orphan")
        firstLaunch.configureLeaseStore(store)
        #expect(firstLaunch.open())
        #expect(try store.ownerID(for: "appstore-note-relaunch") == "legacy-orphan")

        NoteSessionStateMachine.resetInMemoryLeaseRegistryForTests()

        let secondLaunch = NoteSessionStateMachine(noteID: "appstore-note-relaunch", sessionID: "second-launch")
        secondLaunch.configureLeaseStore(store)
        #expect(secondLaunch.open())
        #expect(secondLaunch.canWrite)
        #expect(try store.ownerID(for: "appstore-note-relaunch") == "second-launch")
    }

    @Test("App Store lane reclaims pid-shaped persisted Source lease after relaunch")
    func appStoreLaneReclaimsPidShapedPersistedSourceLeaseAfterRelaunch() throws {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)
        let oldOwner = "epistemos:\(ProcessInfo.processInfo.processIdentifier):stale-owner-from-previous-launch"

        let firstLaunch = NoteSessionStateMachine(noteID: "appstore-note-pid-relaunch", sessionID: oldOwner)
        firstLaunch.configureLeaseStore(store)
        #expect(firstLaunch.open())
        #expect(try store.ownerID(for: "appstore-note-pid-relaunch") == oldOwner)

        NoteSessionStateMachine.resetInMemoryLeaseRegistryForTests()

        let secondLaunch = NoteSessionStateMachine(noteID: "appstore-note-pid-relaunch", sessionID: "second-launch")
        secondLaunch.configureLeaseStore(store)
        #expect(secondLaunch.open())
        #expect(secondLaunch.canWrite)
        #expect(try store.ownerID(for: "appstore-note-pid-relaunch") == "second-launch")
        #else
        #expect(true)
        #endif
    }

    @Test("App Store lane lets graph embedded editor take a clean active lease")
    func appStoreLaneLetsGraphEmbeddedEditorTakeCleanActiveLease() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "appstore-note-clean-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "appstore-note-clean-handoff", sessionID: "graph")

        #expect(owner.open())
        #expect(!graph.open())
        #expect(graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(!owner.canWrite)
        #expect(graph.canWrite)
    }

    @Test("App Store lane reclaims deallocated graph editor owner so Source stays editable")
    func appStoreLaneReclaimsDeallocatedGraphEditorOwnerSoSourceStaysEditable() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        var owner: NoteSessionStateMachine? = NoteSessionStateMachine(
            noteID: "appstore-note-deallocated-owner",
            sessionID: "owner"
        )
        #expect(owner?.open() == true)
        owner = nil

        let graph = NoteSessionStateMachine(
            noteID: "appstore-note-deallocated-owner",
            sessionID: "graph"
        )
        #expect(graph.open())
        #expect(graph.canWrite)
    }

    @Test("App Store lane blocks graph embedded editor while owner is dirty")
    func appStoreLaneBlocksGraphEmbeddedEditorWhileOwnerIsDirty() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "appstore-note-dirty-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "appstore-note-dirty-handoff", sessionID: "graph")

        #expect(owner.open())
        _ = owner.recordUserEdit(source: .user)
        #expect(!graph.open())
        #expect(!graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(owner.canWrite)
        #expect(!graph.canWrite)
    }

    @Test("App Store lane debounces transclusion overlay refreshes during prose typing")
    func appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping() throws {
        let transclusion = try loadRepoTextFile("Epistemos/Views/Notes/TransclusionOverlayManager2.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let refreshAfterTextChange = try #require(sourceSection(
            in: transclusion,
            startingAt: "func refreshAfterTextChange()",
            endingBefore: "    func refreshForScroll()"
        ))
        let removeAll = try #require(sourceSection(
            in: transclusion,
            startingAt: "func removeAll()",
            endingBefore: "    private func configureOverlay("
        ))

        #expect(proseTextView.contains("static let transclusionOverlayRefreshDelay: Duration = .milliseconds(160)"))
        #expect(transclusion.contains("private var textChangeRefreshTask: Task<Void, Never>?"))
        #expect(refreshAfterTextChange.contains("textChangeRefreshTask?.cancel()"))
        #expect(refreshAfterTextChange.contains("Task.sleep(for: NoteEditorPerformancePolicy.transclusionOverlayRefreshDelay)"))
        #expect(refreshAfterTextChange.contains("self.refresh(recalculateDocumentState: true)"))
        #expect(!refreshAfterTextChange.contains("\n        refresh(recalculateDocumentState: true)"))
        #expect(removeAll.contains("textChangeRefreshTask?.cancel()"))
    }

    @Test("App Store lane skips unchanged Source snapshots before rewriting parent state")
    func appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let snapshot = try #require(sourceSection(
            in: workspace,
            startingAt: "private func recordSourceEditorSnapshot(page: SDPage, filePath: String, content: String)",
            endingBefore: "    @discardableResult\n    private func persistMarkdownSourceEditorContent("
        ))

        #expect(snapshot.contains("let existingSourceBody = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: filePath)"))
        #expect(snapshot.contains("if existingSourceBody != content"))
        #expect(snapshot.contains("guard modeBodySnapshot?.body(ifMatches: page.id) != persistedContent.body else { return }"))
        #expect(snapshot.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: persistedContent.body)"))
    }

    @Test("App Store Source saves replace stale frontmatter snapshots with canonical page state")
    func appStoreSourceSavesReplaceStaleFrontmatterSnapshotsWithCanonicalPageState() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))

        #expect(sourceSave.contains("persistedBody = persistedSourceBody"))
        #expect(sourceSave.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: persistedSourceBody)"))
        #expect(sourceSave.contains("refreshMarkdownSourceSnapshot(for: page)"))
        #expect(!sourceSave.contains("body: content"))
    }

    @Test("App Store Source title renames preserve editor identity and refresh paths in place")
    func appStoreSourceTitleRenamesPreserveEditorIdentityAndRefreshPathsInPlace() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let sourceSurface = try #require(sourceSection(
            in: workspace,
            startingAt: "private func noteNonDocumentEditorSurface(page: SDPage, availableSize: CGSize)",
            endingBefore: "    /// Saves code file content back to disk"
        ))
        let sourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))

        #expect(sourceSurface.contains(".id(page.id)"))
        #expect(!sourceSurface.contains(".id(\"\\(page.id)::\\(route.filePath)\")"))
        #expect(!workspace.contains("sourceEditorPresentationRevision"))
        #expect(!sourceSave.contains("page.filePath = filePath"))
        #expect(codeEditor.contains(".onChange(of: initialContent)"))
    }

    @Test("App Store title renames update Prose and Epdoc in place without viewport jumps")
    func appStoreTitleRenamesUpdateLiveEditorsInPlaceWithoutViewportJumps() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let proseView = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let proseBridge = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let documentSurface = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let epdocBridge = try loadRepoTextFile("Epistemos/Engine/EpdocEditorBridge.swift")
        let inbound = try loadRepoTextFile("js-editor/src/bridge/inbound.ts")
        let editor = try loadRepoTextFile("js-editor/src/index.ts")
        let identityCommit = try #require(sourceSection(
            in: workspace,
            startingAt: "private func commitNoteIdentity(_ draft: NoteIdentityDraft, for page: SDPage) async -> Bool",
            endingBefore: "    private func overlayGraphEmbeddedToolbar(page: SDPage)"
        ))
        let proseObserver = try #require(sourceSection(
            in: proseBridge,
            startingAt: "coord.replaceRangeObserver = NotificationCenter.default.addObserver(",
            endingBefore: "        // Overlay subsystems (Phase 9)"
        ))
        let epdocTitleCommand = try #require(sourceSection(
            in: inbound,
            startingAt: "replaceDocumentTitle(title: string, epoch?: number): boolean",
            endingBefore: "    setContentWidth(value: string): void"
        ))

        #expect(proseView.contains("static func syncedNoteTitleEdit("))
        #expect(identityCommit.contains("\"mapSelection\": true"))
        #expect(identityCommit.contains("\"persistedHostMutation\": true"))
        #expect(!identityCommit.contains("\"selectedRange\": NSValue(range: titleEdit.selectedRange)"))
        #expect(!identityCommit.contains("NSRange(location: 0, length: (currentBody as NSString).length)"))
        #expect(proseObserver.contains("MarkdownEditorCommands.mappedSelection("))
        #expect(proseObserver.contains("tv.selectedRange()"))
        #expect(proseObserver.contains("undoManager?.disableUndoRegistration()"))
        #expect(proseObserver.contains("coord.acceptPersistedHostMutation(tv.string)"))
        #expect(proseObserver.contains("let scrollOrigin = tv.enclosingScrollView?.contentView.bounds.origin ?? .zero"))
        #expect(proseObserver.contains("ProseEditorScrollRestoration.restore(scrollOrigin, in: tv.enclosingScrollView)"))

        let oldBody = "# Old 🧭\n\nBody 😀"
        let selection = NSRange(location: (oldBody as NSString).length, length: 0)
        let titleMutation = try #require(
            ProseEditorView.syncedNoteTitleMutation(in: oldBody, with: "Expanded 🧪 Title")
        )
        let titleEdit = try #require(
            ProseEditorView.syncedNoteTitleEdit(
                in: oldBody,
                with: "Expanded 🧪 Title",
                selection: selection
            )
        )
        #expect(titleMutation.expectedText == "# Old 🧭")
        #expect(titleMutation.replacementText == "# Expanded 🧪 Title")
        #expect(titleMutation.applying(to: oldBody) == "# Expanded 🧪 Title\n\nBody 😀")
        #expect(titleEdit.replacementRange == titleMutation.range)
        #expect(titleEdit.selectedRange.location == selection.location + (
            titleMutation.replacementText.utf16.count - titleMutation.expectedText.utf16.count
        ))
        let beforeTitleEdit = try #require(
            ProseEditorView.syncedNoteTitleEdit(
                in: oldBody,
                with: "Expanded 🧪 Title",
                selection: NSRange(location: 0, length: 0)
            )
        )
        #expect(beforeTitleEdit.selectedRange == NSRange(location: 0, length: 0))
        let spanningSelection = NSRange(location: 2, length: 12)
        let spanningEdit = try #require(
            ProseEditorView.syncedNoteTitleEdit(
                in: oldBody,
                with: "Expanded 🧪 Title",
                selection: spanningSelection
            )
        )
        #expect(spanningEdit.selectedRange.location == 2)
        #expect(spanningEdit.selectedRange != titleEdit.selectedRange)
        #expect(
            ProseEditorView.syncedNoteTitleMutation(
                in: "```markdown\n# Not the title\n```\n\nBody",
                with: "Ignored"
            ) == nil
        )

        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Old Title\n\nBody\n"
        let renamedMarkdown = "# New Title\n\nBody\n"
        var commands: [EpdocEditorCommand] = []
        coordinator.configure(
            pageId: "title-stability-appstore",
            title: "Old Title",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-stability.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { commands.append($0) }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()
        coordinator.configure(
            pageId: "title-stability-appstore",
            title: "New Title",
            markdown: renamedMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-stability.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(commands == [.replaceDocumentTitle(title: "New Title", epoch: 2)])
        #expect(coordinator.controller.latestMarkdownSnapshot == renamedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)

        coordinator.controller.handleBridgeMessage(
            .documentStatsChanged(wordCount: 4, characterCount: 18),
            epoch: 2
        )
        commands.removeAll()
        coordinator.configure(
            pageId: "title-stability-appstore",
            title: "New Title",
            markdown: renamedMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-stability.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "title-stability-appstore",
            title: "New Title",
            markdown: renamedMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-stability.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(commands == [.flushDocumentSnapshot])
        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(markdown: initialMarkdown, writeback: nil),
            epoch: 2
        )
        #expect(commands == [
            .flushDocumentSnapshot,
            .setMarkdownForLoad(markdown: renamedMarkdown, epoch: 3),
            .focusStart,
        ])

        let blankCoordinator = MarkdownDocumentSurfaceCoordinator()
        let blankMarkdown = "# Same Title\n\nBody\n"
        var blankCommands: [EpdocEditorCommand] = []
        blankCoordinator.configure(
            pageId: "title-noop-blank-appstore",
            title: "Same Title",
            markdown: blankMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-noop-blank.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        blankCoordinator.controller.installEditorDispatch { blankCommands.append($0) }
        blankCoordinator.controller.handleBridgeMessage(.editorReady)
        blankCoordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        blankCommands.removeAll()
        blankCoordinator.configure(
            pageId: "title-noop-blank-appstore",
            title: "Same Title",
            markdown: blankMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-noop-blank.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(blankCommands == [
            .setMarkdownForLoad(markdown: blankMarkdown, epoch: 2),
            .focusStart,
        ])

        let queuedCoordinator = MarkdownDocumentSurfaceCoordinator()
        var queuedCommands: [EpdocEditorCommand] = []
        queuedCoordinator.configure(
            pageId: "title-queued-appstore",
            title: "Old Title",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-queued.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        queuedCoordinator.controller.installEditorDispatch { queuedCommands.append($0) }
        queuedCoordinator.controller.handleBridgeMessage(.editorReady)
        queuedCommands.removeAll()
        queuedCoordinator.configure(
            pageId: "title-queued-appstore",
            title: "New Title",
            markdown: renamedMarkdown,
            theme: .light,
            noteRelativePath: "notes/title-queued.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(queuedCommands.isEmpty)
        queuedCoordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        #expect(queuedCommands == [.replaceDocumentTitle(title: "New Title", epoch: 2)])

        #expect(documentSurface.contains("synchronizeCleanSyncedTitleChange"))
        #expect(chrome.contains("synchronizeCleanHostTitle"))
        #expect(epdocBridge.contains("case replaceDocumentTitle(title: String, epoch: Int)"))
        #expect(inbound.contains("replaceDocumentTitle(title: string, epoch?: number): boolean"))
        #expect(epdocTitleCommand.contains("if (title.trim().length === 0) return false"))
        #expect(epdocTitleCommand.contains(".insertText(title, from, to)"))
        #expect(!epdocTitleCommand.contains("replace(/\\s+/g"))
        #expect(inbound.contains(".setMeta(HOST_LOAD_META, true)"))
        #expect(editor.contains("transaction.getMeta(HOST_LOAD_META) !== true"))
    }

    @Test("App Store identity body-save failure restores exact path bytes and metadata")
    func appStoreIdentityBodySaveFailureRestoresExactPathBytesAndMetadata() async throws {
        enum StubError: Error { case exportFailedAfterReplace }

        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let vaultSyncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let atomicWriterSource = try loadRepoTextFile("Epistemos/Sync/AtomicVaultWriter.swift")
        let coordinatedMutationSource = try loadRepoTextFile("Epistemos/Sync/CoordinatedVaultFileMutation.swift")
        let identityCommit = try #require(sourceSection(
            in: workspace,
            startingAt: "private func commitNoteIdentity(_ draft: NoteIdentityDraft, for page: SDPage) async -> Bool",
            endingBefore: "    private func overlayGraphEmbeddedToolbar(page: SDPage)"
        ))
        let transaction = try #require(sourceSection(
            in: vaultSyncSource,
            startingAt: "func commitPageIdentityFileFirst(",
            endingBefore: "    @discardableResult\n    func savePageBodyFileFirst("
        ))

        let bodySave = try #require(transaction.range(
            of: "AtomicVaultWriter.writeSynchronously("
        ))
        let physicalMove = try #require(transaction.range(
            of: "CoordinatedVaultFileMutation.moveItem("
        ))
        let metadataMutation = try #require(transaction.range(of: "page.title = title"))
        #expect(bodySave.lowerBound < physicalMove.lowerBound)
        #expect(bodySave.lowerBound < metadataMutation.lowerBound)
        #expect(physicalMove.lowerBound < metadataMutation.lowerBound)
        #expect(transaction.contains("ifCurrentMatches: expectedBaseline"))
        #expect(transaction.contains("ifSourceMatches: .contents(forwardData)"))
        #expect(!transaction.contains("performPageBodyFileFirstSave("))
        #expect(!transaction.contains("movePage(pageId:"))
        #expect(!transaction.contains("renamePageFile(pageId:"))
        #expect(identityCommit.contains("vaultSync.commitPageIdentityFileFirst("))
        #expect(!identityCommit.contains("vaultSync.movePage("))
        #expect(!identityCommit.contains("vaultSync.renamePageFile("))
        #expect(atomicWriterSource.contains("guard let callbackResult else"))
        #expect(atomicWriterSource.contains("throw AtomicVaultWriteError.coordinationCallbackNotInvoked"))
        #expect(coordinatedMutationSource.contains("throw CoordinatedVaultFileMutationError.coordinationCallbackNotInvoked"))
        #expect(!coordinatedMutationSource.contains("operationResult ?? .removed"))

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-rollback")
        let noteBodiesURL = try makeTempDirectory(prefix: "keelstone-identity-body-cache")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: noteBodiesURL)
        }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) { @MainActor in
            let oldFolder = SDFolder(name: "Old Folder")
            let targetFolder = SDFolder(name: "Target Folder")
            let page = SDPage(title: "Old")
            let originalUpdatedAt = Date(timeIntervalSince1970: 1_725_000_000)
            let originalURL = vaultURL
                .appendingPathComponent(oldFolder.relativePath, isDirectory: true)
                .appendingPathComponent("Old-1.md", isDirectory: false)
            let forwardURL = vaultURL
                .appendingPathComponent(targetFolder.relativePath, isDirectory: true)
                .appendingPathComponent("New.md", isDirectory: false)
            let originalBytes = Data("---\ntags: [before]\n---\n# Old\n\nBody 😀\n".utf8)

            try FileManager.default.createDirectory(
                at: originalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try AtomicVaultWriter.writeSynchronously(originalBytes, to: originalURL)
            page.tags = ["before"]
            page.frontMatter = ["tags": "before"]
            page.folder = oldFolder
            page.subfolder = oldFolder.relativePath
            page.filePath = originalURL.path
            page.updatedAt = originalUpdatedAt
            page.lastSyncedBodyHash = SDPage.bodyHash("# Old\n\nBody 😀\n")
            page.needsVaultSync = false
            context.insert(oldFolder)
            context.insert(targetFolder)
            context.insert(page)
            try context.save()

            service.setVaultURLForTesting(vaultURL)
            service.setPageIdentityAfterForwardWriteOverrideForTesting { _, _ in
                throw StubError.exportFailedAfterReplace
            }

            let result = await service.commitPageIdentityFileFirst(
                pageId: page.id,
                title: "New",
                tags: ["after"],
                folder: targetFolder,
                subfolder: targetFolder.relativePath,
                markdownBody: "# New\n\nBody 😀\n"
            )

            #expect(result == .rolledBack)
            #expect(page.title == "Old")
            #expect(page.tags == ["before"])
            #expect(page.folder?.id == oldFolder.id)
            #expect(page.subfolder == oldFolder.relativePath)
            #expect(page.filePath == originalURL.path)
            #expect(page.updatedAt == originalUpdatedAt)
            #expect(!page.needsVaultSync)
            #expect(FileManager.default.fileExists(atPath: originalURL.path))
            #expect(!FileManager.default.fileExists(atPath: forwardURL.path))
            #expect(try Data(contentsOf: originalURL) == originalBytes)
            let markdownFiles = try FileManager.default.subpathsOfDirectory(atPath: vaultURL.path)
                .filter { $0.hasSuffix(".md") }
            #expect(markdownFiles == ["Old Folder/Old-1.md"])
            #expect(NoteFileStorage.stagedOrPersistedDraftBody(pageId: page.id) == "# Old\n\nBody 😀\n")

            let verificationContext = ModelContext(container)
            let pageID = page.id
            let persistedPage = try #require(try verificationContext.fetch(
                FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageID })
            ).first)
            #expect(persistedPage.title == "Old")
            #expect(persistedPage.tags == ["before"])
            #expect(persistedPage.filePath == originalURL.path)
            #expect(persistedPage.updatedAt == originalUpdatedAt)
            #expect(!persistedPage.needsVaultSync)
        }
    }

    @Test("App Store explicit saves never mark a newer edit clean after an older export")
    func appStoreExplicitSavePreservesNewerDirtyEdit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-explicit-save-race")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let oldBody = "# Race\n\nbody before save\n"
        let newBody = "# Race\n\nbody after save started\n"
        let oldSyncDate = Date(timeIntervalSince1970: 1_727_000_000)
        let priorFilePath = vaultURL.appendingPathComponent("prior-race.md").path
        let page = SDPage(title: "Race")
        page.body = oldBody
        page.filePath = priorFilePath
        page.lastSyncedBodyHash = "previous-hash"
        page.lastSyncedAt = oldSyncDate
        page.needsVaultSync = true
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)

        let gate = PageIdentityExportGate()
        service.setExportPageOverrideForTesting { pageId, _ in
            _ = await gate.begin()
            return (
                vaultURL.appendingPathComponent("\(pageId).md").path,
                SDPage.bodyHash(oldBody)
            )
        }

        let saveTask = try #require(service.savePage(pageId: page.id))
        await gate.waitUntilFirstStarted()
        page.body = newBody
        page.needsVaultSync = true
        try context.save()
        await gate.releaseFirst()
        await saveTask.value

        #expect(page.needsVaultSync)
        #expect(page.filePath == priorFilePath)
        #expect(page.lastSyncedBodyHash == "previous-hash")
        #expect(page.lastSyncedAt == oldSyncDate)
    }

    @Test("App Store dirty saves rerun when a note changes during export")
    func appStoreDirtySaveRerunsAfterStaleExport() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-dirty-save-race")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let oldBody = "# Dirty\n\nfirst body\n"
        let newBody = "# Dirty\n\nsecond body\n"
        let page = SDPage(title: "Dirty")
        page.body = oldBody
        page.needsVaultSync = true
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)

        let gate = PageIdentityExportGate()
        service.setExportPageOverrideForTesting { pageId, _ in
            let invocation = await gate.begin()
            let exportedBody = invocation == 1 ? oldBody : newBody
            return (
                vaultURL.appendingPathComponent("\(pageId).md").path,
                SDPage.bodyHash(exportedBody)
            )
        }

        let saveTask = try #require(service.saveAllDirtyPages())
        await gate.waitUntilFirstStarted()
        page.body = newBody
        page.needsVaultSync = true
        try context.save()
        await gate.releaseFirst()
        await saveTask.value

        #expect(await gate.count() == 2)
        #expect(!page.needsVaultSync)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(newBody))
    }

    @Test("App Store suspended saves cannot publish across vault sessions")
    func appStoreSuspendedSaveCannotCommitAcrossVaultSessionChange() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultA = try makeTempDirectory(prefix: "keelstone-save-session-a")
        let vaultB = try makeTempDirectory(prefix: "keelstone-save-session-b")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultA)
            try? FileManager.default.removeItem(at: vaultB)
        }

        let oldBody = "# Session\n\nold body\n"
        let newBody = "# Session\n\nnew body\n"
        let oldSyncDate = Date(timeIntervalSince1970: 1_727_100_000)
        let originalURL = vaultA.appendingPathComponent("Session.md")
        let exportedURL = vaultA.appendingPathComponent("Session-exported.md")
        let page = SDPage(title: "Session")
        page.body = oldBody
        page.filePath = originalURL.path
        page.lastSyncedBodyHash = SDPage.bodyHash(oldBody)
        page.lastSyncedAt = oldSyncDate
        page.needsVaultSync = true
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultA)

        let gate = PageIdentityExportGate()
        service.setExportPageOverrideForTesting { _, exportVaultURL in
            #expect(exportVaultURL.standardizedFileURL == vaultA.standardizedFileURL)
            _ = await gate.begin()
            return (exportedURL.path, SDPage.bodyHash(newBody))
        }

        let saveTask = Task { @MainActor in
            await service.savePageBodyFileFirst(pageId: page.id, body: newBody)
        }
        await gate.waitUntilFirstStarted()
        service.setVaultURLForTesting(vaultB)
        await gate.releaseFirst()

        #expect(await saveTask.value == false)
        #expect(service.vaultURL?.standardizedFileURL == vaultB.standardizedFileURL)
        #expect(page.filePath == originalURL.path)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(oldBody))
        #expect(page.lastSyncedAt == oldSyncDate)
        #expect(page.needsVaultSync)
    }

    @Test("App Store stop drains an admitted save before clearing its vault session")
    func appStoreStopDrainsAdmittedSaveBeforeClearingVaultSession() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-save-stop-drain")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let body = "# Drain\n\nfinish before disconnect\n"
        let exportedURL = vaultURL.appendingPathComponent("Drain.md")
        let page = SDPage(title: "Drain")
        page.needsVaultSync = true
        context.insert(page)
        try context.save()
        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        service.setVaultURLForTesting(vaultURL, isSecurityScoped: true)

        let exportGate = PageIdentityExportGate()
        service.setExportPageOverrideForTesting { _, exportVaultURL in
            #expect(exportVaultURL.standardizedFileURL == vaultURL.standardizedFileURL)
            _ = await exportGate.begin()
            return (exportedURL.path, SDPage.bodyHash(body))
        }

        let saveTask = Task { @MainActor in
            await service.savePageBodyFileFirst(pageId: page.id, body: body)
        }
        await exportGate.waitUntilFirstStarted()

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        for _ in 0..<50 where !service.isVaultMutationDrainActiveForTesting() {
            await Task.yield()
        }

        #expect(service.isVaultMutationDrainActiveForTesting())
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 1)
        #expect(!(await stopCompletion.isCompleted()))
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(await service.savePageBodyFileFirst(pageId: page.id, body: "rejected during drain") == false)
        #expect(await service.commitPageIdentityFileFirst(
            pageId: page.id,
            title: "Rejected During Drain",
            tags: [],
            folder: nil,
            subfolder: nil,
            markdownBody: nil
        ) == .rejected)
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 1)
        #expect(await exportGate.count() == 1)
        #expect(page.title == "Drain")
        await exportGate.releaseFirst()

        #expect(await saveTask.value)
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(service.vaultURL == nil)
        #expect(page.filePath == exportedURL.path)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(body))
        #expect(!page.needsVaultSync)
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
    }

    @Test("App Store queued identity commits cannot cross a same-path vault epoch")
    func appStoreQueuedIdentityCommitCannotCrossSamePathVaultEpoch() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-same-path-epoch")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let originalBody = "# Original\n\noriginal body\n"
        let firstBody = "# First\n\nfirst body\n"
        let secondBody = "# Second\n\nsecond body\n"
        let originalURL = vaultURL.appendingPathComponent("Original.md")
        try AtomicVaultWriter.writeSynchronously(Data(originalBody.utf8), to: originalURL)

        let page = SDPage(title: "Original")
        page.body = originalBody
        page.filePath = originalURL.path
        page.lastSyncedBodyHash = SDPage.bodyHash(originalBody)
        page.needsVaultSync = false
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)

        let forwardWriteGate = PageIdentityExportGate()
        service.setPageIdentityAfterForwardWriteOverrideForTesting { _, _ in
            _ = await forwardWriteGate.begin()
        }

        let firstCommit = Task { @MainActor in
            await service.commitPageIdentityFileFirst(
                pageId: page.id,
                title: "First",
                tags: ["first"],
                folder: nil,
                subfolder: nil,
                markdownBody: firstBody
            )
        }
        await forwardWriteGate.waitUntilFirstStarted()
        let secondCommit = Task { @MainActor in
            await service.commitPageIdentityFileFirst(
                pageId: page.id,
                title: "Second",
                tags: ["second"],
                folder: nil,
                subfolder: nil,
                markdownBody: secondBody
            )
        }
        for _ in 0..<50 where service.activeVaultMutationAdmissionCountForTesting() < 2 {
            await Task.yield()
        }
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 2)
        service.setVaultURLForTesting(vaultURL)
        await forwardWriteGate.releaseFirst()

        #expect(await firstCommit.value == .rolledBack)
        #expect(await secondCommit.value == .rejected)
        #expect(await forwardWriteGate.count() == 1)
        #expect(page.title == "Original")
        #expect(page.tags.isEmpty)
        #expect(page.filePath == originalURL.path)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(originalBody))
        #expect(try Data(contentsOf: originalURL) == Data(originalBody.utf8))
        #expect(!FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("First.md").path))
        #expect(!FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("Second.md").path))
    }

    @Test("App Store unreadable candidate preflight preserves mounted vault and balances scope")
    func appStoreUnreadableCandidatePreflightPreservesMountedVaultAndBalancesScope() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultA = try makeTempDirectory(prefix: "keelstone-candidate-preflight-a")
        let missingVaultB = makeUncreatedTempDirectory(prefix: "keelstone-candidate-preflight-b")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-candidate-preflight-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultA)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        let bookmarkA = Data("bookmark-a".utf8)
        defaults.set(bookmarkA, forKey: vaultBookmarkKey)
        defaults.set(vaultA.standardizedFileURL.path, forKey: lastVaultPathKey)

        let scopeStartProbe = SynchronousURLProbe()
        let scopeStopProbe = SynchronousURLProbe()
        let importProbe = SynchronousURLProbe()
        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setSecurityScopeAccessOperationForTesting { url in
            scopeStartProbe.record(url)
            return true
        }
        service.setSecurityScopeStopOperationForTesting { url in
            scopeStopProbe.record(url)
        }
        service.setHybridMigrationOperationForTesting { _ in }
        service.setInitialImportOperationForTesting { url in
            importProbe.record(url)
            return url.standardizedFileURL == vaultA.standardizedFileURL
        }
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in .none },
            apply: { _ in },
            completion: {}
        )

        service.startWatching(
            vaultURL: vaultA,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        let initialImport = try #require(service.initialImportTaskForTesting())
        await initialImport.value
        let searchServiceA = try #require(service.searchService)

        let didSwitch = await service.switchToVaultAsync(
            vaultURL: missingVaultB,
            refreshAmbientManifestImmediately: false
        )
        for _ in 0..<20 where importProbe.snapshot().count == 1 {
            await Task.yield()
        }

        #expect(!didSwitch)
        #expect(service.vaultURL?.standardizedFileURL == vaultA.standardizedFileURL)
        #expect(service.isWatching)
        #expect(service.searchService === searchServiceA)
        #expect(defaults.data(forKey: vaultBookmarkKey) == bookmarkA)
        #expect(defaults.string(forKey: lastVaultPathKey) == vaultA.standardizedFileURL.path)
        #expect(scopeStartProbe.snapshot() == [missingVaultB.standardizedFileURL])
        #expect(scopeStopProbe.snapshot() == [missingVaultB.standardizedFileURL])
        #expect(importProbe.snapshot() == [vaultA.standardizedFileURL])
    }

    @Test("App Store stop awaits a cancellation-ignoring import before releasing its vault scope")
    func appStoreStopAwaitsCancellationIgnoringImportBeforeScopeRelease() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-import-stop-drain")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-import-stop-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setSecurityScopeAccessOperationForTesting { _ in true }
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "import-stop-drain") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)

        let importGate = PageIdentityExportGate()
        service.setInitialImportOperationForTesting { importURL in
            #expect(importURL.standardizedFileURL == vaultURL.standardizedFileURL)
            _ = await importGate.begin()
            return true
        }

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await importGate.waitUntilFirstStarted()
        let initialImportTask = try #require(service.initialImportTaskForTesting())

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        for _ in 0..<50 where !service.isVaultMutationDrainActiveForTesting() {
            await Task.yield()
        }
        for _ in 0..<50 {
            if await stopCompletion.isCompleted() || !scopeReleaseProbe.snapshot().isEmpty {
                break
            }
            await Task.yield()
        }

        #expect(service.isVaultMutationDrainActiveForTesting())
        #expect(!(await stopCompletion.isCompleted()))
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)

        await importGate.releaseFirst()
        await initialImportTask.value

        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
        #expect(service.vaultURL == nil)
        #expect(service.lastVaultImportSummary == nil)
        #expect(vaultChangedCount == 0)
    }

    @Test("App Store stop awaits a cancellation-ignoring hybrid migration before releasing its vault scope")
    func appStoreStopAwaitsCancellationIgnoringHybridMigrationBeforeScopeRelease() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-hybrid-migration-stop-drain")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-hybrid-migration-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setSecurityScopeAccessOperationForTesting { _ in true }
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        service.setInitialImportOperationForTesting { _ in true }

        let migrationGate = PageIdentityExportGate()
        service.setHybridMigrationOperationForTesting { _ in
            _ = await migrationGate.begin()
        }

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await migrationGate.waitUntilFirstStarted()

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        await service.waitUntilVaultMutationDrainBeginsForTesting()

        #expect(service.isVaultMutationDrainActiveForTesting())
        #expect(!(await stopCompletion.isCompleted()))
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)

        await migrationGate.releaseFirst()

        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
        #expect(service.vaultURL == nil)
    }

    @Test("App Store hybrid migration is retained before initial import")
    func appStoreHybridMigrationIsOwnedBeforeInitialImport() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let beginWatching = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private func beginWatching(",
            endingBefore: "    private func readableVaultURLAfterSecurityScopeSettle("
        ))
        let migrationCall = try #require(beginWatching.range(
            of: "await Self.performHybridMigrations("
        ))
        let importStart = try #require(beginWatching.range(
            of: "let importResult: InitialImportResult"
        ))

        #expect(migrationCall.lowerBound < importStart.lowerBound)
        if migrationCall.lowerBound < importStart.lowerBound {
            let migrationToImport = String(
                beginWatching[migrationCall.upperBound..<importStart.lowerBound]
            )
            #expect(migrationToImport.contains("guard !Task.isCancelled"))
            #expect(migrationToImport.contains(
                "self.vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true)"
            ))
        }
        #expect(!beginWatching.contains(
            "Task(priority: .utility) {\n                await Self.performHybridMigrations("
        ))
    }

    @Test("App Store hybrid migration finishes before initial import begins")
    func appStoreHybridMigrationCompletesBeforeInitialImportBegins() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-hybrid-migration-order")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-hybrid-migration-order-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        let order = SynchronousOrderProbe()
        let migrationGate = PageIdentityExportGate()
        service.setHybridMigrationOperationForTesting { _ in
            order.record("migration-started")
            _ = await migrationGate.begin()
            order.record("migration-finished")
        }
        service.setInitialImportOperationForTesting { _ in
            order.record("import-started")
            return false
        }

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await migrationGate.waitUntilFirstStarted()
        let initialImportTask = try #require(service.initialImportTaskForTesting())

        #expect(order.snapshot() == ["migration-started"])

        await migrationGate.releaseFirst()
        await initialImportTask.value

        #expect(order.snapshot() == [
            "migration-started",
            "migration-finished",
            "import-started",
        ])
    }

    @Test("App Store stop owns cancellation-ignoring initial derived work before scope release")
    func appStoreStopAwaitsCancellationIgnoringInitialDerivedWorkBeforeScopeRelease() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-initial-derived-stop")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-initial-derived-stop-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setSecurityScopeAccessOperationForTesting { _ in true }
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        service.setHybridMigrationOperationForTesting { _ in }
        service.setInitialImportOperationForTesting { _ in true }

        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "initial-derived-stop") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)

        let derivedGate = PageIdentityExportGate()
        let applyProbe = SynchronousCountProbe()
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, workload in
                #expect(workload == .rebuild)
                _ = await derivedGate.begin()
                return .rebuild(documents: ["old": "must not apply while draining"])
            },
            apply: { _ in applyProbe.increment() },
            completion: { await derivedCompletion.markCompleted() }
        )

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await derivedGate.waitUntilFirstStarted()

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        await service.waitUntilVaultMutationDrainBeginsForTesting()

        #expect(service.isVaultMutationDrainActiveForTesting())
        #expect(!(await stopCompletion.isCompleted()))
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)
        #expect(vaultChangedCount == 0)

        await derivedGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(applyProbe.count() == 0)
        #expect(vaultChangedCount == 0)
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
        #expect(service.vaultURL == nil)
    }

    @Test("App Store initial derived work cannot apply across a same-path epoch")
    func appStoreInitialDerivedWorkCannotApplyAcrossSamePathEpoch() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-initial-derived-same-path")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-initial-derived-same-path-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setHybridMigrationOperationForTesting { _ in }
        service.setInitialImportOperationForTesting { _ in true }
        let applyProbe = SynchronousCountProbe()
        let derivedGate = PageIdentityExportGate()
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in
                _ = await derivedGate.begin()
                return .rebuild(documents: ["old": "must not cross epochs"])
            },
            apply: { _ in applyProbe.increment() },
            completion: { await derivedCompletion.markCompleted() }
        )

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await derivedGate.waitUntilFirstStarted()

        service.setVaultURLForTesting(vaultURL)
        await derivedGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        #expect(applyProbe.count() == 0)
    }

    @Test("App Store initial derived pipeline runs exactly once before ready publication")
    func appStoreInitialDerivedPipelineRunsOnceBeforeReadyPublication() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-initial-derived-order")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-initial-derived-order-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        let order = SynchronousOrderProbe()
        service.setHybridMigrationOperationForTesting { _ in order.record("migration") }
        service.setInitialImportOperationForTesting { _ in
            order.record("import")
            return true
        }
        let eventBus = EventBus()
        eventBus.subscribe(id: "initial-derived-order") { event in
            if case .vaultChanged = event {
                order.record("ready")
            }
        }
        service.setEventBus(eventBus)

        let derivedGate = PageIdentityExportGate()
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in
                order.record("derived")
                _ = await derivedGate.begin()
                return .rebuild(documents: [:])
            },
            apply: { _ in order.record("apply") },
            completion: { await derivedCompletion.markCompleted() }
        )

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await derivedGate.waitUntilFirstStarted()
        await derivedGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        #expect(order.snapshot() == [
            "migration",
            "import",
            "derived",
            "apply",
            "ready",
        ])
    }

    @Test("App Store initial pipeline owns Search Spotlight Recall and buffers watcher work")
    func appStoreInitialPipelineOwnsDerivedLegsAndBuffersWatcherWork() async throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let vaultIndex = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")
        let beginWatching = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private func beginWatching(",
            endingBefore: "    private func readableVaultURLAfterSecurityScopeSettle("
        ))
        let derivedWork = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func performInitialImportDerivedWork(",
            endingBefore: "    private nonisolated static func performInitialImport("
        ))
        let initialImport = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func performInitialImport(",
            endingBefore: "    private nonisolated static let instantRecallRebuildBodyCharacterLimit"
        ))
        let searchDiffOwner = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func performSearchIndexDiffSync(",
            endingBefore: "    private nonisolated static func scheduleInstantRecallIndexRebuild("
        ))
        let watcherDrain = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private func drainAndProcessPendingVaultFileSystemChanges(",
            endingBefore: "    private func startNextVaultFileSystemProcessorIfNeeded()"
        ))
        let spotlight = try #require(sourceSection(
            in: vaultIndex,
            startingAt: "func spotlightReindexAll",
            endingBefore: "    // MARK: - Coordinated File Access"
        ))
        let diffSync = try #require(sourceSection(
            in: searchIndex,
            startingAt: "nonisolated func diffSync(",
            endingBefore: "    // MARK: - Diff Sync Helpers"
        ))
        let searchPreparation = try #require(
            searchDiffOwner.range(of: "prepareSuppressedSearchMutationBatchReceipt(")
        )
        let searchPublication = try #require(
            searchDiffOwner.range(of: "searchService.notifyIndexChangedAsync(")
        )
        let searchConsumption = try #require(
            searchDiffOwner.range(of: "consumeSuppressedSearchMutationBatch(")
        )

        #expect(!beginWatching.contains("Task.detached(priority: .utility)"))
        #expect(beginWatching.contains("await Self.performInitialImportDerivedWork("))
        #expect(beginWatching.contains(
            "Self.applyInstantRecallMutation(derivedResult.recallMutation)"
        ))
        #expect(derivedWork.contains("guard let searchService else"))
        #expect(derivedWork.contains(
            "guard let searchSynchronizationReceipt = await Self.performSearchIndexDiffSync("
        ))
        #expect(!derivedWork.contains("setSearchIndexNotificationsEnabled"))
        #expect(derivedWork.contains("spotlightJournalReceipt = try await actor.spotlightReindexAll("))
        #expect(derivedWork.contains("since: spotlightCursor"))
        #expect(derivedWork.contains("await Self.prepareInstantRecallMutation("))
        #expect(
            derivedWork.components(
                separatedBy: "guard await canContinue() else"
            ).count == 5
        )
        #expect(initialImport.contains("guard let importSnapshot = try await actor.importVault("))
        #expect(initialImport.contains("await actor.beginSuppressedSearchMutationBatch("))
        #expect(initialImport.contains("searchMutationBatchID: suppressedSearchBatchID"))
        #expect(watcherDrain.contains(
            "guard initialImportCompleted || allowBeforeInitialImportCompletion else { return nil }"
        ))
        #expect(beginWatching.contains("let initialSpotlightCursor = spotlightCursor(for: url)"))
        #expect(beginWatching.contains("self.persistSpotlightCursor(finalSpotlightReceipt, for: url)"))
        #expect(beginWatching.contains("initialImportCompletedOverride: true"))
        #expect(!spotlight.contains("Task.detached"))
        #expect(spotlight.contains("async throws -> VaultSpotlightJournalReceipt"))
        #expect(spotlight.contains("since lastIndexDate: Date?"))
        #expect(spotlight.contains("order: .forward"))
        #expect(!spotlight.contains("fetchLimit = 1000"))
        #expect(spotlight.contains("guard await NoteEntitySpotlightIndexer.indexBulk(entities)"))
        #expect(spotlight.contains("try Task.checkCancellation()"))
        #expect(spotlight.contains("typedRows.append((page.id, page.title, pageBody))"))
        #expect(!spotlight.contains("$0.body"))
        #expect(!spotlight.contains("UserDefaults.standard"))
        #expect(!spotlight.contains("Date.now"))
        #expect(searchDiffOwner.contains("notifyObservers: false"))
        #expect(searchDiffOwner.contains("diffReceipt = try await searchService.diffSync("))
        #expect(searchDiffOwner.contains("prepareSuppressedSearchMutationBatchReceipt("))
        #expect(searchDiffOwner.contains("searchService.notifyIndexChangedAsync("))
        #expect(searchDiffOwner.contains("consumeSuppressedSearchMutationBatch("))
        #expect(searchDiffOwner.contains("synchronizationReceipt.changedDependencies"))
        #expect(searchPreparation.lowerBound < searchPublication.lowerBound)
        #expect(searchPublication.lowerBound < searchConsumption.lowerBound)
        #expect(!vaultSync.contains("setSearchIndexNotificationsEnabled"))
        #expect(!vaultIndex.contains("searchIndexNotificationsEnabled"))
        #expect(!searchDiffOwner.contains(".searchPages"))
        #expect(!searchDiffOwner.contains(".searchBlocks"))
        #expect(diffSync.contains("let receipt = try applyDiff("))
        #expect(diffSync.contains("await notifyIndexChangedAsync(receipt.changedDependencies)"))
    }

    @Test("App Store buffers watcher changes until initial import is complete and drains once")
    func appStoreWatcherBuffersDuringInitialImportAndDrainsOnce() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-import-watcher-buffer")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }
        let changedURL = vaultURL.appendingPathComponent("Buffered.md")
        try AtomicVaultWriter.writeSynchronously("# Buffered\n", to: changedURL)
        service.setVaultURLForTesting(vaultURL)
        service.setInitialImportCompletedForTesting(false)

        let processorProbe = SynchronousCountProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            processorProbe.increment()
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: false)
        }
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 70,
                eventID: 98_001
            )
        ])

        let bufferedState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(processorProbe.count() == 0)
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(bufferedState.changedPathCount == 1)
        #expect(bufferedState.lastEventID == 98_001)

        service.setInitialImportCompletedForTesting(true)
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        let drainedState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(processorProbe.count() == 1)
        #expect(drainedState.changedPathCount == 0)
        #expect(drainedState.lastEventID == nil)
    }

    @Test("App Store failed buffered watcher reconciliation cannot publish initial ready")
    func appStoreFailedBufferedWatcherReconciliationCannotPublishInitialReady() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-import-watcher-failure")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-import-watcher-failure-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setHybridMigrationOperationForTesting { _ in }
        let importGate = PageIdentityExportGate()
        service.setInitialImportOperationForTesting { _ in
            _ = await importGate.begin()
            return true
        }
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in .none },
            apply: { _ in },
            completion: { await derivedCompletion.markCompleted() }
        )
        let processorProbe = SynchronousCountProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            processorProbe.increment()
            return VaultFileSystemProcessingResult(didProcess: false, didMutate: false)
        }
        let readyProbe = SynchronousCountProbe()
        let eventBus = EventBus()
        eventBus.subscribe(id: "failed-buffered-watcher-ready") { event in
            if case .vaultChanged = event {
                readyProbe.increment()
            }
        }
        service.setEventBus(eventBus)

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await importGate.waitUntilFirstStarted()
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: vaultURL.appendingPathComponent("Ignored.png").path,
                flags: 0,
                inode: 71,
                eventID: 98_101
            )
        ])
        await importGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        let pendingState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(processorProbe.count() == 1)
        #expect(readyProbe.count() == 0)
        #expect(pendingState.needsFullRescan)
        #expect(pendingState.lastEventID == 98_101)
    }

    @Test("App Store initial readiness drains a watcher event delivered before the first fence resumes")
    func appStoreInitialReadinessDrainsWatcherEventDeliveredBeforeFirstFenceResumes() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-import-watcher-late-event")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-import-watcher-late-event-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setHybridMigrationOperationForTesting { _ in }
        let importGate = PageIdentityExportGate()
        service.setInitialImportOperationForTesting { _ in
            _ = await importGate.begin()
            return true
        }
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in .none },
            apply: { _ in },
            completion: { await derivedCompletion.markCompleted() }
        )

        let order = SynchronousOrderProbe()
        let processorProbe = SynchronousCountProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            processorProbe.increment()
            order.record("process")
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: false)
        }
        let readyProbe = SynchronousCountProbe()
        let eventBus = EventBus()
        eventBus.subscribe(id: "late-buffered-watcher-ready") { event in
            if case .vaultChanged = event {
                readyProbe.increment()
                order.record("ready")
            }
        }
        service.setEventBus(eventBus)

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await importGate.waitUntilFirstStarted()

        let firstDeletedURL = vaultURL.appendingPathComponent("Deleted-A.md")
        let lateDeletedURL = vaultURL.appendingPathComponent("Deleted-B.md")
        let lateDelivery = service.captureVaultFileSystemEventDeliveryForTesting()
        let completionProbe = SynchronousCountProbe()
        service.setVaultFileSystemRecallCompletionOperationForTesting {
            completionProbe.increment()
            guard completionProbe.count() == 1 else { return }
            order.record("late")
            await lateDelivery([
                VaultFileSystemEvent(
                    path: lateDeletedURL.path,
                    flags: 0,
                    inode: 74,
                    eventID: 98_202
                )
            ])
        }
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: firstDeletedURL.path,
                flags: 0,
                inode: 73,
                eventID: 98_201
            )
        ])

        await importGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        let pendingState = service.vaultFileSystemEventPendingStateForTesting()
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(
            vaultURL: vaultURL
        )
        #expect(processorProbe.count() == 2)
        #expect(completionProbe.count() == 2)
        #expect(order.snapshot() == ["process", "late", "process", "ready"])
        #expect(readyProbe.count() == 1)
        #expect(pendingState.changedPathCount == 0)
        #expect(pendingState.deletedPathCount == 0)
        #expect(!pendingState.needsFullRescan)
        #expect(pendingState.lastEventID == nil)
        #expect(defaults.string(forKey: checkpointKey) == "98202")
    }

    @Test("App Store initial import publishes committed Search dependencies once")
    func appStoreInitialImportPublishesCommittedSearchDependenciesOnce() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-initial-search-receipt")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-initial-search-receipt-index")
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        defer {
            try? searchService.databaseWriter().close()
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageToken = "initialpage\(token)"
        let blockToken = "initialblock\(token)"
        let noteSource = "# \(pageToken)\n\n\(blockToken)\n"
        try AtomicVaultWriter.writeSynchronously(
            Data(noteSource.utf8),
            to: vaultURL.appendingPathComponent("Initial.md")
        )

        let notificationDependencies = SynchronousOrderProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            let dependencies = notification.userInfo?["queryDependencyKeys"] as? [String] ?? []
            notificationDependencies.record(
                dependencies.sorted().joined(separator: ",")
            )
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        let batchID = try #require(
            await actor.beginSuppressedSearchMutationBatch(for: searchService)
        )
        let importSnapshot = try await actor.importVault(
            from: vaultURL,
            searchMutationBatchID: batchID
        )

        #expect(importSnapshot != nil)
        #expect(try searchService.search(query: pageToken, limit: 10).isEmpty == false)
        #expect(try searchService.searchBlocks(query: blockToken).isEmpty == false)
        #expect(notificationDependencies.snapshot().isEmpty)

        let pendingSnapshot = try #require(
            await actor.suppressedSearchMutationBatchSnapshot(
                id: batchID,
                service: searchService
            )
        )
        #expect(pendingSnapshot.isValid)
        #expect(pendingSnapshot.revision > 0)
        #expect(pendingSnapshot.committed.upsertedPageCount == 1)
        #expect(pendingSnapshot.committed.deletedPageCount == 0)
        #expect(pendingSnapshot.committed.upsertedBlockCount > 0)
        #expect(pendingSnapshot.committed.deletedBlockCount == 0)
        #expect(pendingSnapshot.committed.changedDependencies == [.searchPages, .searchBlocks])

        let timestamps = try #require(await actor.requiredPageTimestampsForSearchDiff())
        let unchangedReceipt = try await searchService.diffSync(
            swiftDataPages: timestamps,
            fullPageProvider: { id in await actor.fullPageData(for: id) },
            notifyObservers: false
        )
        #expect(unchangedReceipt.upsertedPageCount == 0)
        #expect(unchangedReceipt.deletedPageCount == 0)
        #expect(unchangedReceipt.deletedBlockCount == 0)
        #expect(unchangedReceipt.changedDependencies.isEmpty)

        let continuationChecks = SynchronousCountProbe()
        let cancelledReceipt = await VaultSyncService.performSearchIndexDiffSyncForTesting(
            from: actor,
            searchService: searchService,
            suppressedSearchBatchID: batchID,
            canContinue: {
                continuationChecks.increment()
                return continuationChecks.count() == 1
            }
        )
        #expect(cancelledReceipt == nil)
        #expect(continuationChecks.count() == 2)
        #expect(notificationDependencies.snapshot().isEmpty)

        let preparedSnapshot = try #require(
            await actor.suppressedSearchMutationBatchSnapshot(
                id: batchID,
                service: searchService
            )
        )
        #expect(preparedSnapshot.revision == pendingSnapshot.revision)
        #expect(preparedSnapshot.committed == pendingSnapshot.committed)
        #expect(preparedSnapshot.preparedDiff == unchangedReceipt)

        let synchronizationReceipt = try #require(
            await VaultSyncService.performSearchIndexDiffSyncForTesting(
                from: actor,
                searchService: searchService,
                suppressedSearchBatchID: batchID
            )
        )

        #expect(synchronizationReceipt.suppressedImport == pendingSnapshot.committed)
        #expect(synchronizationReceipt.diff == unchangedReceipt)
        #expect(synchronizationReceipt.total == pendingSnapshot.committed)
        #expect(synchronizationReceipt.changedDependencies == [.searchPages, .searchBlocks])
        #expect(notificationDependencies.snapshot() == ["searchBlocks,searchPages"])

        let consumedSnapshot = await actor.suppressedSearchMutationBatchSnapshot(
            id: batchID,
            service: searchService
        )
        #expect(consumedSnapshot == nil)

        let repeatedReceipt = await VaultSyncService.performSearchIndexDiffSyncForTesting(
            from: actor,
            searchService: searchService,
            suppressedSearchBatchID: batchID
        )
        #expect(repeatedReceipt == nil)
        #expect(notificationDependencies.snapshot() == ["searchBlocks,searchPages"])
    }

    @Test("App Store Search diff rejects a missing required page before deleting stale rows")
    func appStoreSearchDiffRejectsMissingRequiredPageBeforeDeletingStaleRows() async throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-diff-missing-page")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let requiredID = "required-\(token)"
        let staleID = "stale-\(token)"
        let requiredToken = "required\(token)"
        let staleToken = "stale\(token)"
        try searchService.upsert(
            id: requiredID,
            title: requiredToken,
            body: "required row must survive a rejected projection",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.upsert(
            id: staleID,
            title: staleToken,
            body: "stale row must not be deleted before validation",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )

        let notificationProbe = SynchronousCountProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            notificationProbe.increment()
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        var rejectedRequiredPage = false
        do {
            try await searchService.diffSync(
                swiftDataPages: [
                    (id: requiredID, updatedAt: Date(timeIntervalSince1970: 2)),
                ],
                fullPageProvider: { _ in nil },
                notifyObservers: true
            )
            Issue.record("Expected a missing required Search projection to reject the diff.")
        } catch SearchIndexError.missingRequiredPage(let pageID) {
            rejectedRequiredPage = pageID == requiredID
        } catch {
            Issue.record("Expected missingRequiredPage, got \(error).")
        }

        let requiredResults = try searchService.search(query: requiredToken, limit: 10)
        let staleResults = try searchService.search(query: staleToken, limit: 10)
        #expect(rejectedRequiredPage)
        #expect(requiredResults.contains { $0.pageId == requiredID })
        #expect(staleResults.contains { $0.pageId == staleID })
        #expect(notificationProbe.count() == 0)
    }

    @Test("App Store Search notifications stay with their producing service")
    func appStoreSearchNotificationsStayWithTheirProducingService() async throws {
        let searchRootA = try makeTempDirectory(prefix: "keelstone-search-notification-source-a")
        let searchRootB = try makeTempDirectory(prefix: "keelstone-search-notification-source-b")
        defer {
            try? FileManager.default.removeItem(at: searchRootA)
            try? FileManager.default.removeItem(at: searchRootB)
        }
        let searchServiceA = try SearchIndexService(
            databaseURL: searchRootA.appendingPathComponent("search.sqlite")
        )
        let searchServiceB = try SearchIndexService(
            databaseURL: searchRootB.appendingPathComponent("search.sqlite")
        )
        let pagePlan = QueryPlan(
            steps: [.fts5Search(query: "correlated", scope: .pages)],
            combiner: .single
        )
        let allSearchPlan = QueryPlan(
            steps: [.fts5Search(query: "correlated", scope: .all)],
            combiner: .single
        )
        let reactiveA = ReactiveQuery(
            runtime: QueryRuntime(
                graphStore: GraphStore(),
                graphState: GraphState(),
                searchIndex: searchServiceA
            ),
            plan: pagePlan
        )
        let reactiveB = ReactiveQuery(
            runtime: QueryRuntime(
                graphStore: GraphStore(),
                graphState: GraphState(),
                searchIndex: searchServiceB
            ),
            plan: pagePlan
        )
        let allSearchReactiveA = ReactiveQuery(
            runtime: QueryRuntime(
                graphStore: GraphStore(),
                graphState: GraphState(),
                searchIndex: searchServiceA
            ),
            plan: allSearchPlan
        )

        let notificationSources = SynchronousOrderProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            if let source = notification.object as? SearchIndexService {
                if source === searchServiceB {
                    notificationSources.record("service-b")
                } else if source === searchServiceA {
                    notificationSources.record("service-a")
                } else {
                    notificationSources.record("other-service")
                }
            } else {
                notificationSources.record("nil")
            }
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        let pageID = "correlated-\(UUID().uuidString)"
        let updatedAt = Date(timeIntervalSinceReferenceDate: 805_700_000)
        let receipt = try await searchServiceB.diffSync(
            swiftDataPages: [(id: pageID, updatedAt: updatedAt)],
            fullPageProvider: { requestedID in
                guard requestedID == pageID else { return nil }
                return (
                    title: "Correlated notification",
                    body: "The producing Search service owns this event.",
                    tags: "",
                    updatedAt: updatedAt
                )
            },
            notifyObservers: true
        )
        #expect(receipt.upsertedPageCount == 1)
        #expect(notificationSources.snapshot().contains("service-b"))

        let serviceBNotification = Notification(
            name: .searchIndexDidUpdate,
            object: searchServiceB,
            userInfo: QueryDependencyKey.userInfo(for: [.searchPages])
        )
        #expect(reactiveB.shouldInvalidate(for: serviceBNotification))
        #expect(!reactiveA.shouldInvalidate(for: serviceBNotification))
        #expect(HTMLWorkspaceDataFeedStatus.shouldRefresh(
            for: serviceBNotification,
            activeSearchService: searchServiceB
        ))
        #expect(!HTMLWorkspaceDataFeedStatus.shouldRefresh(
            for: serviceBNotification,
            activeSearchService: searchServiceA
        ))

        let readableFallback = Notification(
            name: .searchIndexDidUpdate,
            object: nil,
            userInfo: QueryDependencyKey.userInfo(for: [.searchReadable])
        )
        #expect(allSearchReactiveA.shouldInvalidate(for: readableFallback))
        #expect(HTMLWorkspaceDataFeedStatus.shouldRefresh(
            for: readableFallback,
            activeSearchService: searchServiceA
        ))
    }

    @Test("App Store linked SQLite provides every Search FTS5 round trip")
    func appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips() throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-fts5-host")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageToken = "fts5page\(token)"
        let blockToken = "fts5block\(token)"
        let readableToken = "fts5readable\(token)"
        let pageID = "fts5-page-\(token)"

        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "The App Store host must index this page token.",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: "fts5-block-\(token)", content: blockToken)],
            notifyObservers: false
        )

        let databaseWriter = searchService.databaseWriter()
        try databaseWriter.write { db in
            try db.execute(
                sql: """
                    INSERT INTO readable_blocks
                        (artifact_id, artifact_kind, block_id, block_kind,
                         title_path, body, updated_at, vault_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    pageID,
                    ArtifactKind.document.snakeCaseString,
                    "fts5-readable-\(token)",
                    ReadableBlockKind.paragraph.rawValue,
                    "FTS5 host proof",
                    readableToken,
                    ReadableBlock.iso8601(Date(timeIntervalSince1970: 1)),
                    "keelstone-fts5-host",
                ]
            )
        }

        let requiredTables = Set([
            "page_search",
            "block_search",
            "readable_blocks_fts",
        ])
        let installedTables = try databaseWriter.read { db in
            Set(try String.fetchAll(
                db,
                sql: """
                    SELECT name
                    FROM sqlite_master
                    WHERE type = 'table' AND name IN (?, ?, ?)
                    """,
                arguments: StatementArguments(requiredTables.sorted())
            ))
        }
        #expect(installedTables == requiredTables)
        guard installedTables == requiredTables else { return }

        let matchCounts = try databaseWriter.read { db in
            (
                pages: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM page_search WHERE page_search MATCH ?",
                    arguments: [pageToken]
                ) ?? 0,
                blocks: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM block_search WHERE block_search MATCH ?",
                    arguments: [blockToken]
                ) ?? 0,
                readableBlocks: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM readable_blocks_fts WHERE readable_blocks_fts MATCH ?",
                    arguments: [readableToken]
                ) ?? 0
            )
        }
        #expect(matchCounts.pages == 1)
        #expect(matchCounts.blocks == 1)
        #expect(matchCounts.readableBlocks == 1)
    }

    @Test("App Store required Search timestamp read failure cannot mutate or notify")
    func appStoreSearchRequiredTimestampReadFailureCannotMutateOrNotify() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-required-timestamps")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageID = "preserved-page-\(token)"
        let blockID = "preserved-block-\(token)"
        let pageToken = "preservedpage\(token)"
        let blockToken = "preservedblock\(token)"
        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "must survive a required timestamp read failure",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: blockID, content: blockToken)],
            notifyObservers: false
        )

        let readProbe = SynchronousCountProbe()
        await actor.setRequiredPageTimestampsOperationForTesting {
            readProbe.increment()
            throw NSError(
                domain: "AppStoreKeelstoneTests.RequiredSearchTimestampRead",
                code: 1
            )
        }
        let notificationProbe = SynchronousCountProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            notificationProbe.increment()
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        let synchronizationReceipt = await VaultSyncService.performSearchIndexDiffSyncForTesting(
            from: actor,
            searchService: searchService
        )

        #expect(readProbe.count() == 1)
        #expect(synchronizationReceipt == nil)
        #expect(try searchService.search(query: pageToken, limit: 10).contains {
            $0.pageId == pageID
        })
        #expect(try searchService.searchBlocks(query: blockToken).contains {
            $0.blockId == blockID
        })
        #expect(notificationProbe.count() == 0)
    }

    @Test("App Store Search diff owners require fail-closed timestamp reads")
    func appStoreSearchDiffOwnersRequireFailClosedTimestampReads() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let initialOwner = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func performSearchIndexDiffSync(",
            endingBefore: "    private nonisolated static func scheduleInstantRecallIndexRebuild("
        ))
        let watcherOwner = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func processExternalVaultFileSystemChanges(",
            endingBefore: "    // MARK: - Version Capture"
        ))

        #expect(initialOwner.contains("requiredPageTimestampsForSearchDiff()"))
        #expect(watcherOwner.contains("requiredPageTimestampsForSearchDiff()"))
        #expect(!initialOwner.contains("allPageTimestamps()"))
        #expect(!watcherOwner.contains("allPageTimestamps()"))
    }

    @Test("App Store Search diff removes blocks owned by stale pages")
    func appStoreSearchDiffRemovesBlocksOwnedByStalePages() async throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-diff-stale-block")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageID = "stale-page-\(token)"
        let blockID = "stale-block-\(token)"
        let pageToken = "stalepage\(token)"
        let blockToken = "staleblock\(token)"
        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "page scheduled for exact diff removal",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: blockID, content: blockToken)],
            notifyObservers: false
        )
        #expect(try searchService.searchBlocks(query: blockToken).contains {
            $0.blockId == blockID
        })

        let receipt = try await searchService.diffSync(
            swiftDataPages: [],
            fullPageProvider: { _ in nil },
            notifyObservers: false
        )

        #expect(receipt.sourcePageCount == 0)
        #expect(receipt.upsertedPageCount == 0)
        #expect(receipt.deletedPageCount == 1)
        #expect(receipt.deletedBlockCount == 1)
        #expect(receipt.finalIndexedPageCount == 0)
        #expect(receipt.finalIndexedBlockCount == 0)
        #expect(receipt.remainingOrphanBlockCount == 0)
        #expect(receipt.changedDependencies == [.searchPages, .searchBlocks])
        #expect(try searchService.search(query: pageToken, limit: 10).isEmpty)
        #expect(try searchService.searchBlocks(query: blockToken).isEmpty)
    }

    @Test("App Store full Search rebuild removes blocks owned by removed pages")
    func appStoreFullSearchRebuildRemovesBlocksOwnedByRemovedPages() async throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-rebuild-orphan-block")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let removedPageID = "removed-rebuild-page-\(token)"
        let removedBlockID = "removed-rebuild-block-\(token)"
        let removedPageToken = "removedrebuildpage\(token)"
        let removedBlockToken = "removedrebuildblock\(token)"
        let retainedPageID = "retained-rebuild-page-\(token)"
        let retainedBlockID = "retained-rebuild-block-\(token)"
        let retainedPageToken = "retainedrebuildpage\(token)"
        let retainedBlockToken = "retainedrebuildblock\(token)"
        try searchService.upsert(
            id: removedPageID,
            title: removedPageToken,
            body: "page removed by an authoritative full rebuild",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: removedPageID,
            blocks: [(blockId: removedBlockID, content: removedBlockToken)],
            notifyObservers: false
        )
        try searchService.upsert(
            id: retainedPageID,
            title: retainedPageToken,
            body: "page retained by an authoritative full rebuild",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: retainedPageID,
            blocks: [(blockId: retainedBlockID, content: retainedBlockToken)],
            notifyObservers: false
        )
        #expect(try searchService.search(query: removedPageToken, limit: 10).contains {
            $0.pageId == removedPageID
        })
        #expect(try searchService.searchBlocks(query: removedBlockToken).contains {
            $0.blockId == removedBlockID && $0.pageId == removedPageID
        })
        #expect(try searchService.search(query: retainedPageToken, limit: 10).contains {
            $0.pageId == retainedPageID
        })
        #expect(try searchService.searchBlocks(query: retainedBlockToken).contains {
            $0.blockId == retainedBlockID && $0.pageId == retainedPageID
        })

        try await searchService.rebuildFromSwiftDataAsync([
            (
                id: retainedPageID,
                title: retainedPageToken,
                body: "page retained by an authoritative full rebuild",
                tags: "",
                updatedAt: Date(timeIntervalSince1970: 2)
            ),
        ])

        #expect(try !searchService.search(query: removedPageToken, limit: 10).contains {
            $0.pageId == removedPageID
        })
        #expect(try !searchService.searchBlocks(query: removedBlockToken).contains {
            $0.blockId == removedBlockID && $0.pageId == removedPageID
        })
        #expect(try searchService.search(query: retainedPageToken, limit: 10).contains {
            $0.pageId == retainedPageID
        })
        #expect(try searchService.searchBlocks(query: retainedBlockToken).contains {
            $0.blockId == retainedBlockID && $0.pageId == retainedPageID
        })
    }

    @Test("App Store committed Search rebuild survives checkpoint maintenance failure")
    func appStoreCommittedSearchRebuildSurvivesCheckpointMaintenanceFailure() async throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-rebuild-checkpoint")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let removedPageID = "checkpoint-removed-page-\(token)"
        let removedBlockID = "checkpoint-removed-block-\(token)"
        let removedPageToken = "checkpointremovedpage\(token)"
        let removedBlockToken = "checkpointremovedblock\(token)"
        let replacementPageID = "checkpoint-replacement-page-\(token)"
        let replacementPageToken = "checkpointreplacementpage\(token)"
        try searchService.upsert(
            id: removedPageID,
            title: removedPageToken,
            body: "page removed by the committed rebuild",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: removedPageID,
            blocks: [(blockId: removedBlockID, content: removedBlockToken)],
            notifyObservers: false
        )
        try #require(try searchService.search(query: removedPageToken, limit: 10).contains {
            $0.pageId == removedPageID
        })
        try #require(try searchService.searchBlocks(query: removedBlockToken).contains {
            $0.blockId == removedBlockID && $0.pageId == removedPageID
        })

        let checkpointMarkerBefore = try searchService.supportDiagnostics()
            .manifest["last_truncate_checkpoint_at"]
        searchService.setForceTruncateCheckpointFailureForTesting(true)
        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        let notificationDependencies = SynchronousOrderProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            let dependencies = notification.userInfo?["queryDependencyKeys"] as? [String] ?? []
            notificationDependencies.record(
                dependencies.sorted().joined(separator: ",")
            )
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        var checkpointFailureEscaped = false
        do {
            try await searchService.rebuildFromSwiftDataAsync([
                (
                    id: replacementPageID,
                    title: replacementPageToken,
                    body: "replacement committed before checkpoint maintenance",
                    tags: "",
                    updatedAt: Date(timeIntervalSince1970: 2)
                ),
            ])
        } catch {
            checkpointFailureEscaped = true
        }
        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        let checkpointMarkerAfter = try searchService.supportDiagnostics()
            .manifest["last_truncate_checkpoint_at"]
        #expect(!checkpointFailureEscaped)
        #expect(try searchService.search(query: replacementPageToken, limit: 10).contains {
            $0.pageId == replacementPageID
        })
        #expect(try !searchService.search(query: removedPageToken, limit: 10).contains {
            $0.pageId == removedPageID
        })
        #expect(try !searchService.searchBlocks(query: removedBlockToken).contains {
            $0.blockId == removedBlockID && $0.pageId == removedPageID
        })
        #expect(notificationDependencies.snapshot() == ["searchBlocks,searchPages"])
        #expect(checkpointMarkerAfter == checkpointMarkerBefore)
    }

    @Test("App Store manual Search rebuild source failure cannot erase projections")
    func appStoreManualSearchRebuildSourceFailureCannotEraseProjections() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-manual-search-rebuild-source")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-manual-search-rebuild-source-db")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        service.setVaultURLForTesting(vaultURL)
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        await service.setSearchServiceForTesting(searchService)
        let installedFailureSeam = await service
            .setForceRequiredDerivedRebuildSourceFailureForTesting(true)
        try #require(installedFailureSeam)

        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageID = "preserved-manual-rebuild-page-\(token)"
        let blockID = "preserved-manual-rebuild-block-\(token)"
        let pageToken = "preservedmanualpage\(token)"
        let blockToken = "preservedmanualblock\(token)"
        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "must survive a failed manual rebuild source read",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: blockID, content: blockToken)],
            notifyObservers: false
        )
        let seededPageResults = try searchService.search(query: pageToken, limit: 10)
        let seededBlockResults = try searchService.searchBlocks(query: blockToken)
        try #require(seededPageResults.contains {
            $0.pageId == pageID
        })
        try #require(seededBlockResults.contains {
            $0.blockId == blockID && $0.pageId == pageID
        })

        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        let notificationProbe = SynchronousCountProbe()
        let notificationToken = NotificationCenter.default.addObserver(
            forName: .searchIndexDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            notificationProbe.increment()
        }
        defer { NotificationCenter.default.removeObserver(notificationToken) }

        service.rebuildIndex()
        try #require(service.isIndexing)
        for _ in 0..<500 {
            guard service.isIndexing else { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(!service.isIndexing)
        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))

        #expect(try searchService.search(query: pageToken, limit: 10).contains {
            $0.pageId == pageID
        })
        #expect(try searchService.searchBlocks(query: blockToken).contains {
            $0.blockId == blockID && $0.pageId == pageID
        })
        #expect(notificationProbe.count() == 0)
    }

    @Test("App Store public Search deletion rolls back when block deletion fails")
    func appStorePublicSearchDeleteRollsBackWhenBlockDeletionFails() throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-delete-rollback")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let databaseURL = searchRoot.appendingPathComponent("search.sqlite")
        let searchService = try SearchIndexService(databaseURL: databaseURL)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageID = "rollback-page-\(token)"
        let blockID = "rollback-block-\(token)"
        let pageToken = "rollbackpage\(token)"
        let blockToken = "rollbackblock\(token)"
        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "page must survive a failed atomic deletion",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: blockID, content: blockToken)],
            notifyObservers: false
        )
        let triggerWriter = try DatabaseQueue(path: databaseURL.path)
        try triggerWriter.write { db in
            try db.execute(sql: """
                CREATE TRIGGER force_search_block_delete_failure
                BEFORE DELETE ON indexed_blocks
                BEGIN
                    SELECT RAISE(ABORT, 'forced block deletion failure');
                END
                """)
        }

        var rejected = false
        do {
            try searchService.delete(pageId: pageID, notifyObservers: false)
            Issue.record("Expected the forced block deletion failure to reject the transaction.")
        } catch {
            rejected = true
        }

        #expect(rejected)
        #expect(try searchService.search(query: pageToken, limit: 10).contains {
            $0.pageId == pageID
        })
        #expect(try searchService.searchBlocks(query: blockToken).contains {
            $0.blockId == blockID
        })
    }

    @Test("App Store public Search deletion removes page-owned blocks atomically")
    func appStorePublicSearchDeleteRemovesPageOwnedBlocksAtomically() throws {
        let searchRoot = try makeTempDirectory(prefix: "keelstone-search-delete-page-blocks")
        defer { try? FileManager.default.removeItem(at: searchRoot) }
        let searchService = try SearchIndexService(
            databaseURL: searchRoot.appendingPathComponent("search.sqlite")
        )
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let pageID = "deleted-page-\(token)"
        let blockID = "deleted-block-\(token)"
        let pageToken = "deletedpage\(token)"
        let blockToken = "deletedblock\(token)"
        try searchService.upsert(
            id: pageID,
            title: pageToken,
            body: "page removed through the public deletion contract",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1),
            notifyObservers: false
        )
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: blockID, content: blockToken)],
            notifyObservers: false
        )
        #expect(try searchService.search(query: pageToken, limit: 10).contains {
            $0.pageId == pageID
        })
        #expect(try searchService.searchBlocks(query: blockToken).contains {
            $0.blockId == blockID
        })

        let receipt = try searchService.delete(
            pageId: pageID,
            notifyObservers: false
        )

        #expect(receipt.deletedPageCount == 1)
        #expect(receipt.deletedBlockCount == 1)
        #expect(receipt.changedDependencies == [.searchPages, .searchBlocks])
        #expect(try searchService.search(query: pageToken, limit: 10).isEmpty)
        #expect(try searchService.searchBlocks(query: blockToken).isEmpty)

        let noOpReceipt = try searchService.delete(
            pageId: pageID,
            notifyObservers: false
        )
        #expect(noOpReceipt.deletedPageCount == 0)
        #expect(noOpReceipt.deletedBlockCount == 0)
        #expect(noOpReceipt.changedDependencies.isEmpty)

        let orphanBlockID = "orphan-block-\(token)"
        let orphanBlockToken = "orphanblock\(token)"
        try searchService.replaceBlocksForPage(
            pageId: pageID,
            blocks: [(blockId: orphanBlockID, content: orphanBlockToken)],
            notifyObservers: false
        )
        let orphanReceipt = try searchService.delete(
            pageId: pageID,
            notifyObservers: false
        )
        #expect(orphanReceipt.deletedPageCount == 0)
        #expect(orphanReceipt.deletedBlockCount == 1)
        #expect(orphanReceipt.changedDependencies == [.searchBlocks])
        #expect(try searchService.searchBlocks(query: orphanBlockToken).isEmpty)
    }

    @Test("App Store Search page deletion has one atomic production owner")
    func appStoreSearchPageDeletionHasOneAtomicProductionOwner() throws {
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")
        let vaultIndex = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let deletion = try #require(sourceSection(
            in: searchIndex,
            startingAt: "nonisolated func delete(\n        pageId: String,",
            endingBefore: "    // MARK: - Test Hooks"
        ))
        let failedImportCleanup = try #require(sourceSection(
            in: vaultIndex,
            startingAt: "private func discardPendingImportedPages(",
            endingBefore: "    private func restorePendingUpdatedPages("
        ))
        let duplicateCleanup = try #require(sourceSection(
            in: vaultIndex,
            startingAt: "private func removePageArtifacts(",
            endingBefore: "    /// Upsert a page from a .md file URL."
        ))

        #expect(deletion.contains("try Self.deletePageRows(ids: [pageId], in: db)"))
        #expect(deletion.contains("SearchIndexPageDeletionReceipt("))
        #expect(deletion.contains("if notifyObservers, !receipt.changedDependencies.isEmpty"))
        #expect(deletion.contains("receipt.changedDependencies"))
        for owner in [failedImportCleanup, duplicateCleanup] {
            #expect(owner.contains("validatedSearchMutationContext("))
            #expect(owner.contains("batchID: searchMutationBatchID"))
            #expect(owner.contains("let receipt = try searchContext.service.delete("))
            #expect(owner.contains("notifyObservers: searchContext.notifyObservers"))
            #expect(owner.contains("receipt.mutationReceipt"))
            #expect(owner.contains("recordSearchIndexMutation("))
            #expect(owner.contains("recordSearchIndexMutationFailure("))
            #expect(!owner.contains("searchIndexNotificationsEnabled"))
            #expect(!owner.contains("deleteBlocksForPage"))
        }
    }

    @Test("App Store typed Spotlight deletion uses the IndexedEntity APIs")
    func appStoreTypedSpotlightDeletionUsesIndexedEntityAPIs() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/NoteEntitySpotlightIndexer.swift")
        #expect(source.contains(
            "deleteAppEntities(identifiedBy: noteIds, ofType: NoteEntity.self)"
        ))
        #expect(source.contains("deleteAppEntities(ofType: NoteEntity.self)"))
        #expect(!source.contains("deleteSearchableItems(withIdentifiers: noteIds)"))
    }

    @Test("App Store initial import rejects a nil importer snapshot")
    func appStoreInitialImportRejectsNilImporterSnapshot() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let root = try makeTempDirectory(prefix: "keelstone-nil-import-snapshot")
        defer { try? FileManager.default.removeItem(at: root) }
        let missingVaultURL = root.appendingPathComponent("Missing", isDirectory: true)

        #expect(!(await VaultSyncService.initialImportSucceedsForTesting(
            actor: actor,
            url: missingVaultURL
        )))
    }

    @Test("App Store Spotlight startup cursors are scoped to the exact vault")
    func appStoreSpotlightStartupCursorIsVaultScoped() throws {
        let vaultA = try makeTempDirectory(prefix: "keelstone-spotlight-cursor-a")
        let vaultB = try makeTempDirectory(prefix: "keelstone-spotlight-cursor-b")
        defer {
            try? FileManager.default.removeItem(at: vaultA)
            try? FileManager.default.removeItem(at: vaultB)
        }

        let keyA = VaultSyncService.spotlightCursorKeyForTesting(vaultURL: vaultA)
        let keyB = VaultSyncService.spotlightCursorKeyForTesting(vaultURL: vaultB)
        #expect(keyA != keyB)
        #expect(keyA.hasPrefix("keelstone.spotlightCursor.v2."))
        #expect(!keyA.contains("epistemos.lastSpotlightIndexDate"))
    }

    @Test("App Store recovery issue keeps watcher gate closed after initial derived work")
    func appStoreRecoveryIssueKeepsWatcherGateClosedAfterInitialDerivedWork() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-import-recovery-gate")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-import-recovery-gate-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }
        try AtomicVaultWriter.writeSynchronously(
            "# Must remain visible to recovery validation\n",
            to: vaultURL.appendingPathComponent("Unimported.md")
        )

        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setHybridMigrationOperationForTesting { _ in }
        service.setInitialImportOperationForTesting { _ in true }
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in .none },
            apply: { _ in },
            completion: { await derivedCompletion.markCompleted() }
        )
        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await derivedCompletion.waitUntilCompleted()
        #expect(service.recoveryIssue != nil)

        let processorProbe = SynchronousCountProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            processorProbe.increment()
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: false)
        }
        let laterURL = vaultURL.appendingPathComponent("StillBuffered.md")
        try AtomicVaultWriter.writeSynchronously("# Later\n", to: laterURL)
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: laterURL.path,
                flags: 0,
                inode: 72,
                eventID: 98_102
            )
        ])
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        let pendingState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(processorProbe.count() == 0)
        #expect(pendingState.changedPathCount == 1)
        #expect((pendingState.lastEventID ?? 0) >= 98_102)
    }

    @Test("App Store stale vault callbacks cannot seed a new vault epoch")
    func appStoreStaleVaultFileSystemCallbackCannotSeedNewVaultEpoch() async throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultA = try makeTempDirectory(prefix: "keelstone-watcher-session-a")
        let vaultB = try makeTempDirectory(prefix: "keelstone-watcher-session-b")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultA)
            try? FileManager.default.removeItem(at: vaultB)
        }

        service.setVaultURLForTesting(vaultA)
        let staleDelivery = service.captureVaultFileSystemEventDeliveryForTesting()
        let deliveryGate = PageIdentityExportGate()
        let staleEvent = VaultFileSystemEvent(
            path: vaultA.appendingPathComponent("Old.md").path,
            flags: 0,
            inode: 41,
            eventID: 91_001
        )
        let deliveryTask = Task { @MainActor in
            _ = await deliveryGate.begin()
            staleDelivery([staleEvent])
        }
        await deliveryGate.waitUntilFirstStarted()

        service.setVaultURLForTesting(vaultB)
        service.setVaultURLForTesting(vaultA)
        await deliveryGate.releaseFirst()
        await deliveryTask.value

        let pendingState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(service.vaultURL?.standardizedFileURL == vaultA.standardizedFileURL)
        #expect(pendingState.changedPathCount == 0)
        #expect(pendingState.deletedPathCount == 0)
        #expect(!pendingState.needsFullRescan)
        #expect(pendingState.lastEventID == nil)
        #expect(!pendingState.debounceActive)
    }

    @Test("App Store stop clears all seeded vault watcher state")
    func appStoreStopClearsAllSeededVaultWatcherState() throws {
        let container = try makeContainer()
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-stop")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Changed.md")
        let deletedURL = vaultURL.appendingPathComponent("Deleted.md")
        try AtomicVaultWriter.writeSynchronously("# Changed\n", to: changedURL)

        service.setVaultURLForTesting(vaultURL)
        let deliver = service.captureVaultFileSystemEventDeliveryForTesting()
        deliver([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 51,
                eventID: 92_001
            ),
            VaultFileSystemEvent(
                path: deletedURL.path,
                flags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved),
                inode: 52,
                eventID: 92_002
            ),
            VaultFileSystemEvent(
                path: vaultURL.path,
                flags: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs),
                inode: nil,
                eventID: 92_003
            ),
        ])

        let seeded = service.vaultFileSystemEventPendingStateForTesting()
        #expect(seeded.changedPathCount == 1)
        #expect(seeded.deletedPathCount == 1)
        #expect(seeded.needsFullRescan)
        #expect(seeded.lastEventID == 92_003)
        #expect(seeded.debounceActive)

        service.stopWatching(preserveData: true)

        let stopped = service.vaultFileSystemEventPendingStateForTesting()
        #expect(service.vaultURL == nil)
        #expect(!service.isWatching)
        #expect(stopped.changedPathCount == 0)
        #expect(stopped.deletedPathCount == 0)
        #expect(!stopped.needsFullRescan)
        #expect(stopped.lastEventID == nil)
        #expect(!stopped.debounceActive)
    }

    @Test("App Store stop awaits a cancellation-ignoring vault watcher processor")
    func appStoreStopAwaitsCancellationIgnoringVaultFileSystemProcessorBeforeScopeRelease() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-processor-stop")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-processor-stop") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL, isSecurityScoped: true)

        let processorGate = PageIdentityExportGate()
        service.setExternalVaultFileSystemChangesOperationForTesting {
            processingVaultURL,
            changedPaths,
            deletedPaths,
            needsFullRescan in
            #expect(processingVaultURL.standardizedFileURL == vaultURL.standardizedFileURL)
            #expect(changedPaths == [changedURL.standardizedFileURL.path])
            #expect(deletedPaths.isEmpty)
            #expect(!needsFullRescan)
            _ = await processorGate.begin()
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: true)
        }
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 61,
                eventID: 93_001
            )
        ])
        await processorGate.waitUntilFirstStarted()
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 1)

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        await service.waitUntilVaultMutationDrainBeginsForTesting()

        #expect(service.isVaultMutationDrainActiveForTesting())
        #expect(!(await stopCompletion.isCompleted()))
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)

        await processorGate.releaseFirst()

        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
        #expect(service.vaultURL == nil)
        #expect(vaultChangedCount == 0)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        #expect(defaults.object(forKey: checkpointKey) == nil)
    }

    @Test("App Store started vault watcher processing cannot publish across a same-path epoch")
    func appStoreStartedVaultFileSystemProcessorCannotPublishAcrossSamePathEpoch() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-processor-same-path")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-processor-same-path") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL)

        let processorGate = PageIdentityExportGate()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            _ = await processorGate.begin()
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: true)
        }
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 62,
                eventID: 93_002
            )
        ])
        await processorGate.waitUntilFirstStarted()
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 1)

        service.setVaultURLForTesting(vaultURL)
        await processorGate.releaseFirst()
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)
        #expect(vaultChangedCount == 0)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        #expect(defaults.object(forKey: checkpointKey) == nil)
    }

    @Test("App Store stop owns cancellation-ignoring watcher Recall work through scope release")
    func appStoreStopAwaitsCancellationIgnoringVaultWatcherRecallWorkBeforeScopeRelease() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-recall-stop")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let scopeReleaseProbe = SynchronousURLProbe()
        service.setSecurityScopeStopOperationForTesting { url in
            scopeReleaseProbe.record(url)
        }
        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-recall-stop") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL, isSecurityScoped: true)

        let recallGate = PageIdentityExportGate()
        let recallApplyProbe = SynchronousCountProbe()
        let recallCompletion = AsyncCompletionProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            VaultFileSystemProcessingResult(
                didProcess: true,
                didMutate: true,
                postImportRecallWorkload: .rebuild
            )
        }
        service.setVaultFileSystemRecallPreparationOperationForTesting { _, workload in
            #expect(workload == .rebuild)
            _ = await recallGate.begin()
            return .rebuild(documents: ["old-note": "old vault text"])
        }
        service.setVaultFileSystemRecallApplyOperationForTesting { _ in
            recallApplyProbe.increment()
        }
        service.setVaultFileSystemRecallCompletionOperationForTesting {
            await recallCompletion.markCompleted()
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 68,
                eventID: 97_001
            )
        ])
        await recallGate.waitUntilFirstStarted()

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            let didStop = await service.stopWatchingAsync(preserveData: true)
            await stopCompletion.markCompleted()
            return didStop
        }
        await service.waitUntilVaultMutationDrainBeginsForTesting()

        #expect(service.activeVaultMutationAdmissionCountForTesting() == 1)
        #expect(!(await stopCompletion.isCompleted()))
        #expect(scopeReleaseProbe.snapshot().isEmpty)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)

        await recallGate.releaseFirst()
        await recallCompletion.waitUntilCompleted()

        #expect(await stopTask.value)
        #expect(await stopCompletion.isCompleted())
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(scopeReleaseProbe.snapshot() == [vaultURL.standardizedFileURL])
        #expect(service.vaultURL == nil)
        #expect(recallApplyProbe.count() == 0)
        #expect(vaultChangedCount == 0)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        #expect(defaults.object(forKey: checkpointKey) == nil)
    }

    @Test("App Store watcher Recall work cannot apply across a same-path epoch")
    func appStoreVaultWatcherRecallWorkCannotApplyAcrossSamePathEpoch() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-recall-same-path")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-recall-same-path") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL)

        let recallGate = PageIdentityExportGate()
        let recallApplyProbe = SynchronousCountProbe()
        let recallCompletion = AsyncCompletionProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            VaultFileSystemProcessingResult(
                didProcess: true,
                didMutate: true,
                postImportRecallWorkload: .rebuild
            )
        }
        service.setVaultFileSystemRecallPreparationOperationForTesting { _, _ in
            _ = await recallGate.begin()
            return .rebuild(documents: ["old-note": "must not cross epochs"])
        }
        service.setVaultFileSystemRecallApplyOperationForTesting { _ in
            recallApplyProbe.increment()
        }
        service.setVaultFileSystemRecallCompletionOperationForTesting {
            await recallCompletion.markCompleted()
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 69,
                eventID: 97_002
            )
        ])
        await recallGate.waitUntilFirstStarted()

        service.setVaultURLForTesting(vaultURL)
        await recallGate.releaseFirst()
        await recallCompletion.waitUntilCompleted()
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        #expect(service.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL)
        #expect(recallApplyProbe.count() == 0)
        #expect(vaultChangedCount == 0)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        #expect(defaults.object(forKey: checkpointKey) == nil)
    }

    @Test("App Store watcher publishes a committed partial mutation without checkpoint advance")
    func appStoreVaultFileSystemProcessorPublishesPartialMutationWithoutCheckpointAdvance() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-partial-mutation")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        defaults.set("93000", forKey: checkpointKey)

        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-partial-mutation") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL)
        let recallApplyProbe = SynchronousCountProbe()
        let recallCompletion = AsyncCompletionProbe()
        service.setVaultFileSystemRecallPreparationOperationForTesting { _, workload in
            #expect(workload == .rebuild)
            return .rebuild(documents: [:])
        }
        service.setVaultFileSystemRecallApplyOperationForTesting { _ in
            recallApplyProbe.increment()
        }
        service.setVaultFileSystemRecallCompletionOperationForTesting {
            await recallCompletion.markCompleted()
        }
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            VaultFileSystemProcessingResult(
                didProcess: false,
                didMutate: true,
                postImportRecallWorkload: .rebuild
            )
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 63,
                eventID: 93_003
            )
        ])
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()
        await recallCompletion.waitUntilCompleted()

        #expect(vaultChangedCount == 1)
        #expect(recallApplyProbe.count() == 1)
        #expect(defaults.string(forKey: checkpointKey) == "93000")
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
    }

    @Test("App Store watcher checkpoint never regresses after an older completed event")
    func appStoreVaultFileSystemCheckpointPersistenceIsMonotonic() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-monotonic-checkpoint")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        defaults.set("94002", forKey: checkpointKey)
        service.setVaultURLForTesting(vaultURL)
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            VaultFileSystemProcessingResult(didProcess: true, didMutate: false)
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 64,
                eventID: 94_001
            )
        ])
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        #expect(defaults.string(forKey: checkpointKey) == "94002")
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
    }

    @Test("App Store watcher serializes accepted processor batches in event order")
    func appStoreVaultFileSystemProcessorBatchesAreFIFO() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-processor-fifo")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let firstURL = vaultURL.appendingPathComponent("First.md")
        let secondURL = vaultURL.appendingPathComponent("Second.md")
        try AtomicVaultWriter.writeSynchronously("# First\n", to: firstURL)
        try AtomicVaultWriter.writeSynchronously("# Second\n", to: secondURL)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)

        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-processor-fifo") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL)

        let processorGate = PageIdentityExportGate()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            _ = await processorGate.begin()
            return VaultFileSystemProcessingResult(didProcess: true, didMutate: true)
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: firstURL.path,
                flags: 0,
                inode: 65,
                eventID: 95_001
            )
        ])
        await processorGate.waitUntilFirstStarted()
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: secondURL.path,
                flags: 0,
                inode: 66,
                eventID: 95_002
            )
        ])

        let acceptedState = service.vaultFileSystemProcessorStateForTesting()
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 2)
        #expect(acceptedState.running == 1)
        #expect(acceptedState.queued == 1)

        await processorGate.releaseFirst()
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        let completedState = service.vaultFileSystemProcessorStateForTesting()
        #expect(await processorGate.count() == 2)
        #expect(completedState.running == 0)
        #expect(completedState.queued == 0)
        #expect(vaultChangedCount == 2)
        #expect(defaults.string(forKey: checkpointKey) == "95002")
    }

    @Test("App Store successful full reconciliation heals a failed checkpoint barrier")
    func appStoreVaultFileSystemProcessorSuccessHealsFailedCheckpointBarrier() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-checkpoint-barrier")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let changedURL = vaultURL.appendingPathComponent("Existing.md")
        try AtomicVaultWriter.writeSynchronously("# Existing\n", to: changedURL)
        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(vaultURL: vaultURL)
        defaults.set("96000", forKey: checkpointKey)

        let eventBus = EventBus()
        var vaultChangedCount = 0
        eventBus.subscribe(id: "watcher-checkpoint-barrier") { event in
            if case .vaultChanged = event {
                vaultChangedCount += 1
            }
        }
        service.setEventBus(eventBus)
        service.setVaultURLForTesting(vaultURL)

        let processorGate = PageIdentityExportGate()
        await processorGate.releaseFirst()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            let invocation = await processorGate.begin()
            return VaultFileSystemProcessingResult(
                didProcess: invocation != 1,
                didMutate: true,
                completedAuthoritativeFullRescan: invocation != 1
            )
        }

        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 67,
                eventID: 96_001
            )
        ])
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: changedURL.path,
                flags: 0,
                inode: 67,
                eventID: 96_002
            )
        ])
        await service.waitUntilVaultMutationAdmissionsFinishForTesting()

        #expect(await processorGate.count() == 2)
        #expect(vaultChangedCount == 2)
        #expect(defaults.string(forKey: checkpointKey) == "96002")
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
    }

    @Test("App Store watcher Recall missing page cannot apply or checkpoint")
    func appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint() async throws {
        try await withUtilityReleasedModelContainer { container in
            let defaults = makeIsolatedDefaults()
            let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
            let vaultURL = try makeTempDirectory(prefix: "keelstone-watcher-recall-missing-page")
            defer {
                service.stopWatching(preserveData: true)
                try? FileManager.default.removeItem(at: vaultURL)
            }

            let changedURL = vaultURL.appendingPathComponent("Changed.md")
            try AtomicVaultWriter.writeSynchronously("# Changed\n", to: changedURL)
            let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(
                vaultURL: vaultURL
            )
            defaults.set("98300", forKey: checkpointKey)
            service.setVaultURLForTesting(vaultURL)

            let recallApplyProbe = SynchronousCountProbe()
            let recallCompletion = AsyncCompletionProbe()
            service.setVaultFileSystemRecallApplyOperationForTesting { _ in
                recallApplyProbe.increment()
            }
            service.setVaultFileSystemRecallCompletionOperationForTesting {
                await recallCompletion.markCompleted()
            }
            service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
                VaultFileSystemProcessingResult(
                    didProcess: true,
                    didMutate: true,
                    postImportRecallWorkload: .incremental(
                        changedPageIDs: ["missing-required-page"],
                        deletedPageIDs: []
                    )
                )
            }

            service.processVaultFileSystemEventsImmediatelyForTesting([
                VaultFileSystemEvent(
                    path: changedURL.path,
                    flags: 0,
                    inode: 75,
                    eventID: 98_301
                )
            ])
            await service.waitUntilVaultMutationAdmissionsFinishForTesting()
            await recallCompletion.waitUntilCompleted()

            let pendingState = service.vaultFileSystemEventPendingStateForTesting()
            #expect(recallApplyProbe.count() == 0)
            #expect(defaults.string(forKey: checkpointKey) == "98300")
            #expect(pendingState.needsFullRescan)
            #expect(pendingState.lastEventID == 98_301)
            #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
        }
    }

    @Test("App Store required Recall rebuild source failure returns no mutation")
    func appStoreRequiredRecallRebuildSourceFailureReturnsNoMutation() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        await actor.setForceRequiredDerivedRebuildSourceFailureForTesting(true)

        let pages = await actor.requiredPagesForInstantRecallRebuild()

        #expect(pages?.count == nil)
    }

    @Test("App Store initial readiness rejects failed buffered Recall rebuild preparation")
    func appStoreInitialReadinessRejectsFailedBufferedRecallRebuildPreparation() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-initial-recall-source-failure")
        let searchRoot = try makeTempDirectory(prefix: "keelstone-initial-recall-source-failure-search")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: searchRoot)
        }

        let checkpointKey = VaultSyncService.vaultFSEventCheckpointKeyForTesting(
            vaultURL: vaultURL
        )
        defaults.set("98400", forKey: checkpointKey)
        service.setSearchDatabaseURLForTesting(searchRoot.appendingPathComponent("search.sqlite"))
        service.setHybridMigrationOperationForTesting { _ in }
        let importGate = PageIdentityExportGate()
        service.setInitialImportOperationForTesting { _ in
            _ = await importGate.begin()
            return true
        }
        let derivedCompletion = AsyncCompletionProbe()
        service.setInitialImportDerivedOperationsForTesting(
            operation: { _, _, _ in .none },
            apply: { _ in },
            completion: { await derivedCompletion.markCompleted() }
        )

        let processorProbe = SynchronousCountProbe()
        service.setExternalVaultFileSystemChangesOperationForTesting { _, _, _, _ in
            processorProbe.increment()
            return VaultFileSystemProcessingResult(
                didProcess: true,
                didMutate: false,
                postImportRecallWorkload: .rebuild
            )
        }
        let recallPreparationProbe = SynchronousCountProbe()
        service.setVaultFileSystemRecallPreparationOperationForTesting { _, workload in
            #expect(workload == .rebuild)
            recallPreparationProbe.increment()
            return nil
        }
        let recallApplyProbe = SynchronousCountProbe()
        service.setVaultFileSystemRecallApplyOperationForTesting { _ in
            recallApplyProbe.increment()
        }
        let readyProbe = SynchronousCountProbe()
        let eventBus = EventBus()
        eventBus.subscribe(id: "failed-buffered-recall-source-ready") { event in
            if case .vaultChanged = event {
                readyProbe.increment()
            }
        }
        service.setEventBus(eventBus)

        service.startWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
        await importGate.waitUntilFirstStarted()
        service.processVaultFileSystemEventsImmediatelyForTesting([
            VaultFileSystemEvent(
                path: vaultURL.appendingPathComponent("Buffered.md").path,
                flags: 0,
                inode: 76,
                eventID: 98_401
            )
        ])
        await importGate.releaseFirst()
        await derivedCompletion.waitUntilCompleted()

        let pendingState = service.vaultFileSystemEventPendingStateForTesting()
        #expect(processorProbe.count() == 1)
        #expect(recallPreparationProbe.count() == 1)
        #expect(recallApplyProbe.count() == 0)
        #expect(readyProbe.count() == 0)
        #expect(service.recoveryIssue != nil)
        #expect(defaults.string(forKey: checkpointKey) == "98400")
        #expect(pendingState.needsFullRescan)
        #expect(pendingState.lastEventID == 98_401)
        #expect(service.activeVaultMutationAdmissionCountForTesting() == 0)
    }

    @Test("App Store watcher routes ambient manifest refresh through compiled Free owners")
    func appStoreVaultFileSystemProcessorHasOneAmbientManifestRefreshOwner() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let processorCompletion = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private func completeVaultFileSystemBatch(",
            endingBefore: "    private nonisolated static func processExternalVaultFileSystemChanges("
        ))
        let ambientManifestRefresh = try #require(sourceSection(
            in: appBootstrap,
            startingAt: "func refreshAmbientManifest()",
            endingBefore: "    func refreshLiveNoteScheduler()"
        ))

        #expect(!freeV1RetiredPathExists(
            "Epistemos/App/AppCoordinator.swift",
            sourceFilePath: #filePath
        ))
        #expect(processorCompletion.contains("publishVaultMutation(.vaultChanged)"))
        #expect(!processorCompletion.contains("refreshAmbientManifest()"))
        #expect(ambientManifestRefresh.contains("await vaultSync.buildAmbientManifest()"))
        #expect(ambientManifestRefresh.contains("vaultSync.ambientManifest = manifest"))
        #expect(!ambientManifestRefresh.contains("coordinator"))
        #expect(vaultSync.contains("AppBootstrap.shared?.refreshAmbientManifest()"))
    }

    @Test("App Store watcher Recall maintenance has one lifecycle owner")
    func appStoreVaultWatcherRecallMaintenanceHasOneLifecycleOwner() throws {
        let vaultIndex = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let artifactRemoval = try #require(sourceSection(
            in: vaultIndex,
            startingAt: "private func removePageArtifacts(",
            endingBefore: "    /// Upsert a page from a .md file URL."
        ))

        #expect(!artifactRemoval.contains("instantRecallService"))
        #expect(!artifactRemoval.contains("Task { @MainActor"))
    }

    @Test("App Store watcher Recall rebuild prepares off-main and swaps atomically")
    func appStoreVaultWatcherRecallRebuildPreparesOffMainAndSwapsAtomically() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let recallService = try loadRepoTextFile("Epistemos/Engine/InstantRecallService.swift")
        let processor = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private func startNextVaultFileSystemProcessorIfNeeded()",
            endingBefore: "    private func completeVaultFileSystemBatch("
        ))
        let preparation = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private nonisolated static func prepareInstantRecallMutation(",
            endingBefore: "    private static func applyInstantRecallMutation("
        ))
        let apply = try #require(sourceSection(
            in: vaultSync,
            startingAt: "private static func applyInstantRecallMutation(",
            endingBefore: "    private nonisolated static func boundedInstantRecallText("
        ))
        let asyncRebuild = try #require(sourceSection(
            in: recallService,
            startingAt: "func rebuildIndexAsync(notes: [(id: String, text: String)]) async",
            endingBefore: "    func replaceIndex(with preparedDocuments: [String: String])"
        ))
        let replacement = try #require(sourceSection(
            in: recallService,
            startingAt: "func replaceIndex(with preparedDocuments: [String: String])",
            endingBefore: "    private nonisolated static func makeDocumentMap("
        ))

        #expect(processor.contains("vaultFileSystemProcessorTask = Task.detached(priority: .utility)"))
        #expect(processor.contains("recallMutation = await Self.prepareInstantRecallMutation("))
        #expect(processor.contains("let effectiveResult: VaultFileSystemProcessingResult"))
        #expect(processor.contains("completionResult = effectiveResult"))
        #expect(processor.contains("await self.completeVaultFileSystemBatch("))
        #expect(preparation.contains("requiredPagesForInstantRecallRebuild()"))
        #expect(preparation.contains("documents.reserveCapacity(pages.count)"))
        #expect(preparation.contains("return .rebuild(documents: documents)"))
        #expect(apply.contains("service.replaceIndex(with: documents)"))
        #expect(!apply.contains("notes.map"))
        #expect(asyncRebuild.contains("Task.detached(priority: .utility)"))
        #expect(asyncRebuild.contains("replaceIndex(with: preparedDocuments)"))
        #expect(replacement.contains("documents = preparedDocuments"))
    }

    @Test("App Store Recall atomically replaces prepared documents and filters async rebuild input")
    func appStoreInstantRecallPreparedReplacementResetsStateAndFiltersAsyncInput() async {
        let service = InstantRecallService()
        service.indexNote(noteId: "stale", text: "obsoletecobaltmarker")
        _ = service.search(queryText: "obsoletecobaltmarker")

        #expect(service.documentCount == 1)
        #expect(service.lastResults.map(\.docId) == ["stale"])
        #expect(service.searchCount == 1)

        service.replaceIndex(with: [
            "current": "currentambermarker",
            "second": "secondsaffronmarker",
        ])

        #expect(service.documentCount == 2)
        #expect(service.lastResults.isEmpty)
        #expect(service.searchCount == 0)
        #expect(service.averageSearchLatencyMs == 0)
        #expect(service.maxSearchLatencyMs == 0)
        #expect(service.search(queryText: "obsoletecobaltmarker").isEmpty)
        #expect(service.search(queryText: "currentambermarker").map(\.docId) == ["current"])

        await service.rebuildIndexAsync(notes: [
            (id: "blank", text: "  \n\t"),
            (id: "rebuilt", text: "rebuiltverdantmarker"),
        ])

        #expect(service.documentCount == 1)
        #expect(service.lastResults.isEmpty)
        #expect(service.searchCount == 0)
        #expect(service.search(queryText: "currentambermarker").isEmpty)
        #expect(service.search(queryText: "rebuiltverdantmarker").map(\.docId) == ["rebuilt"])
    }

    @Test("App Store identity rollback preserves a pre-existing unsaved draft separately from disk bytes")
    func appStoreIdentityRollbackPreservesPreExistingDirtyDraft() async throws {
        enum StubError: Error { case exportFailedAfterReplace }

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-dirty-draft")
        let noteBodiesURL = try makeTempDirectory(prefix: "keelstone-identity-dirty-draft-bodies")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: noteBodiesURL)
        }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) { @MainActor in
            let diskBody = "# Old\n\ndurable disk body\n"
            let dirtyDraft = "# Old\n\nnewer unsaved draft\n"
            let forwardBody = "# New\n\nnewer unsaved draft\n"
            let originalURL = vaultURL.appendingPathComponent("Old.md")
            try AtomicVaultWriter.writeSynchronously(Data(diskBody.utf8), to: originalURL)

            let page = SDPage(title: "Old")
            page.body = "# Old\n\nstale inline draft\n"
            page.filePath = originalURL.path
            page.lastSyncedBodyHash = SDPage.bodyHash(diskBody)
            page.needsVaultSync = true
            context.insert(page)
            try context.save()
            _ = NoteFileStorage.stageBodyForImmediateRead(pageId: page.id, content: dirtyDraft)
            service.setVaultURLForTesting(vaultURL)
            service.setPageIdentityAfterForwardWriteOverrideForTesting { _, _ in
                throw StubError.exportFailedAfterReplace
            }

            let result = await service.commitPageIdentityFileFirst(
                pageId: page.id,
                title: "New",
                tags: [],
                folder: nil,
                subfolder: nil,
                markdownBody: forwardBody
            )

            #expect(result == .rolledBack)
            #expect(try Data(contentsOf: originalURL) == Data(diskBody.utf8))
            #expect(page.needsVaultSync)
            #expect(NoteFileStorage.stagedOrPersistedDraftBody(pageId: page.id) == dirtyDraft)
        }
    }

    @Test("App Store identity rollback never overwrites an unrelated file that arrived at the original path")
    func appStoreIdentityRollbackRefusesOccupiedOriginalPath() throws {
        let root = try makeTempDirectory(prefix: "keelstone-identity-collision")
        defer { try? FileManager.default.removeItem(at: root) }

        let missingForwardURL = root.appendingPathComponent("Forward.md")
        let originalURL = root.appendingPathComponent("Original.md")
        let snapshotBytes = Data("original snapshot bytes".utf8)
        let unrelatedBytes = Data("unrelated external file".utf8)
        try AtomicVaultWriter.writeSynchronously(unrelatedBytes, to: originalURL)

        #expect(throws: Error.self) {
            try VaultSyncService.restorePageIdentityFileForTesting(
                currentFilePath: missingForwardURL.path,
                originalFilePath: originalURL.path,
                originalFileData: snapshotBytes,
                vaultURL: root
            )
        }
        #expect(try Data(contentsOf: originalURL) == unrelatedBytes)
        #expect(!FileManager.default.fileExists(atPath: missingForwardURL.path))
    }

    @Test("App Store vault file CAS primitives preserve bytes on every baseline mismatch")
    func appStoreVaultFileCASPrimitivesPreserveMismatchedBytes() throws {
        let root = try makeTempDirectory(prefix: "keelstone-vault-cas")
        defer { try? FileManager.default.removeItem(at: root) }

        let targetURL = root.appendingPathComponent("Target.md")
        let firstBytes = Data("first bytes".utf8)
        let secondBytes = Data("second bytes".utf8)
        let externalBytes = Data("external bytes".utf8)

        let createdBaseline = try AtomicVaultWriter.writeSynchronously(
            firstBytes,
            to: targetURL,
            ifCurrentMatches: .absent
        )
        #expect(createdBaseline == .contents(firstBytes))
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: targetURL.path
        )
        let replacedBaseline = try AtomicVaultWriter.writeSynchronously(
            secondBytes,
            to: targetURL,
            ifCurrentMatches: createdBaseline
        )
        #expect(replacedBaseline == .contents(secondBytes))
        let replacedAttributes = try FileManager.default.attributesOfItem(atPath: targetURL.path)
        #expect((replacedAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o755)
        do {
            try AtomicVaultWriter.writeSynchronously(
                externalBytes,
                to: targetURL,
                ifCurrentMatches: .contents(firstBytes)
            )
            Issue.record("Expected a stale-content write baseline to be rejected.")
        } catch AtomicVaultWriteError.baselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected AtomicVaultWriteError.baselineMismatch, got \(error).")
        }
        do {
            try AtomicVaultWriter.writeSynchronously(
                externalBytes,
                to: targetURL,
                ifCurrentMatches: .absent
            )
            Issue.record("Expected an occupied target to reject the absent baseline.")
        } catch AtomicVaultWriteError.baselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected AtomicVaultWriteError.baselineMismatch, got \(error).")
        }
        let missingTargetURL = root.appendingPathComponent("Missing.md")
        do {
            try AtomicVaultWriter.writeSynchronously(
                externalBytes,
                to: missingTargetURL,
                ifCurrentMatches: .contents(Data())
            )
            Issue.record("Expected a missing target to reject a content baseline.")
        } catch AtomicVaultWriteError.baselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected AtomicVaultWriteError.baselineMismatch, got \(error).")
        }
        #expect(try Data(contentsOf: targetURL) == secondBytes)
        #expect(!FileManager.default.fileExists(atPath: missingTargetURL.path))

        let emptyTargetURL = root.appendingPathComponent("Empty.md")
        let emptyBaseline = try AtomicVaultWriter.writeSynchronously(
            Data(),
            to: emptyTargetURL,
            ifCurrentMatches: .absent
        )
        #expect(emptyBaseline == .contents(Data()))
        #expect(FileManager.default.fileExists(atPath: emptyTargetURL.path))
        _ = try AtomicVaultWriter.writeSynchronously(
            firstBytes,
            to: emptyTargetURL,
            ifCurrentMatches: .contents(Data())
        )
        #expect(try Data(contentsOf: emptyTargetURL) == firstBytes)

        let moveSourceURL = root.appendingPathComponent("MoveSource.md")
        let moveDestinationURL = root.appendingPathComponent("MoveDestination.md")
        try AtomicVaultWriter.writeSynchronously(firstBytes, to: moveSourceURL)
        do {
            try CoordinatedVaultFileMutation.moveItem(
                at: moveSourceURL,
                to: moveDestinationURL,
                ifSourceMatches: .absent
            )
            Issue.record("Expected an absent move-source baseline to be rejected as invalid.")
        } catch CoordinatedVaultFileMutationError.invalidSourceBaseline {
            // Expected.
        } catch {
            Issue.record("Expected invalidSourceBaseline, got \(error).")
        }
        do {
            try CoordinatedVaultFileMutation.moveItem(
                at: moveSourceURL,
                to: moveDestinationURL,
                ifSourceMatches: .contents(secondBytes)
            )
            Issue.record("Expected a stale move-source baseline to be rejected.")
        } catch CoordinatedVaultFileMutationError.sourceBaselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected sourceBaselineMismatch, got \(error).")
        }
        #expect(try Data(contentsOf: moveSourceURL) == firstBytes)
        #expect(!FileManager.default.fileExists(atPath: moveDestinationURL.path))

        try AtomicVaultWriter.writeSynchronously(externalBytes, to: moveDestinationURL)
        do {
            try CoordinatedVaultFileMutation.moveItem(
                at: moveSourceURL,
                to: moveDestinationURL,
                ifSourceMatches: .contents(firstBytes)
            )
            Issue.record("Expected an occupied move destination to be rejected.")
        } catch CoordinatedVaultFileMutationError.destinationBaselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected destinationBaselineMismatch, got \(error).")
        }
        #expect(try Data(contentsOf: moveSourceURL) == firstBytes)
        #expect(try Data(contentsOf: moveDestinationURL) == externalBytes)

        do {
            try CoordinatedVaultFileMutation.removeItem(
                at: moveSourceURL,
                ifCurrentMatches: .contents(secondBytes)
            )
            Issue.record("Expected a stale removal baseline to be rejected.")
        } catch CoordinatedVaultFileMutationError.targetBaselineMismatch {
            // Expected.
        } catch {
            Issue.record("Expected targetBaselineMismatch, got \(error).")
        }
        #expect(try Data(contentsOf: moveSourceURL) == firstBytes)
        do {
            try CoordinatedVaultFileMutation.removeItem(
                at: moveSourceURL,
                ifCurrentMatches: .absent
            )
            Issue.record("Expected an absent removal baseline to be rejected as invalid.")
        } catch CoordinatedVaultFileMutationError.invalidTargetBaseline {
            // Expected.
        } catch {
            Issue.record("Expected invalidTargetBaseline, got \(error).")
        }
        try CoordinatedVaultFileMutation.removeItem(
            at: moveDestinationURL,
            ifCurrentMatches: .contents(externalBytes)
        )
        try CoordinatedVaultFileMutation.moveItem(
            at: moveSourceURL,
            to: moveDestinationURL,
            ifSourceMatches: .contents(firstBytes)
        )
        #expect(!FileManager.default.fileExists(atPath: moveSourceURL.path))
        #expect(try Data(contentsOf: moveDestinationURL) == firstBytes)
        try CoordinatedVaultFileMutation.removeItem(
            at: moveDestinationURL,
            ifCurrentMatches: .contents(firstBytes)
        )
        #expect(!FileManager.default.fileExists(atPath: moveDestinationURL.path))
    }

    @Test("App Store body export preserves a pre-existing external front-matter edit")
    func appStoreBodyExportRejectsExternalFrontMatterEdit() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-frontmatter-conflict")
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let fileURL = vaultURL.appendingPathComponent("Original.md")
        let originalSource = "---\ntitle: Original\ntags: [old]\n---\n\n# Original\n\nbody\n"
        let externalSource = "---\ntitle: Original\ntags: [external]\n---\n\n# Original\n\nbody\n"
        try AtomicVaultWriter.writeSynchronously(Data(originalSource.utf8), to: fileURL)
        try await actor.importVault(from: vaultURL)

        let verifyContext = ModelContext(container)
        let page = try #require(try verifyContext.fetch(FetchDescriptor<SDPage>()).first)
        try AtomicVaultWriter.writeSynchronously(Data(externalSource.utf8), to: fileURL)

        do {
            _ = try await actor.exportPage(
                pageId: page.id,
                to: vaultURL,
                bodyOverride: "# Original\n\nlocal body edit\n",
                indexForSearch: false
            )
            Issue.record("Expected the external front-matter edit to block export.")
        } catch VaultPageExportError.externalModification {
            // Expected.
        } catch {
            Issue.record("Expected VaultPageExportError.externalModification, got \(error).")
        }
        #expect(try Data(contentsOf: fileURL) == Data(externalSource.utf8))
    }

    @Test("App Store raw source saves never apply Markdown title or reference semantics")
    func appStoreRawSourceSaveSkipsMarkdownDerivedState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-raw-source-save")
        let noteBodiesURL = try makeTempDirectory(prefix: "keelstone-raw-source-bodies")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: noteBodiesURL)
        }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) { @MainActor in
            let fileURL = vaultURL.appendingPathComponent("script.py")
            let oldSource = "# Existing comment\nprint('old')\n"
            let newSource = "# New Heading\nprint('[[not-a-note]] ((not-a-block))')\n"
            try AtomicVaultWriter.writeSynchronously(Data(oldSource.utf8), to: fileURL)

            let page = SDPage(title: "Script")
            page.filePath = fileURL.path
            page.body = oldSource
            page.lastSyncedBodyHash = SDPage.bodyHash(oldSource)
            page.lastSyncedAt = .now
            page.needsVaultSync = true
            context.insert(page)
            try context.save()
            service.setVaultURLForTesting(vaultURL)

            #expect(await service.savePageBodyFileFirst(pageId: page.id, body: newSource))
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == newSource)
            #expect(page.title == "Script")
            #expect(page.filePath == fileURL.path)
            #expect(page.body == oldSource)
            #expect(page.blockReferences.isEmpty)
            #expect(page.wikilinkReferences.isEmpty)
            #expect(page.lastSyncedBodyHash == SDPage.bodyHash(newSource))
            #expect(!page.needsVaultSync)
            let sidecar = try #require(
                CodeFileService(vaultRoot: vaultURL).readCodeFile(at: fileURL).sidecar
            )
            #expect(sidecar.contentHash == CodeFileService.contentHash(of: Data(newSource.utf8)))
        }
    }

    @Test("App Store identity preflight CAS preserves an external edit that arrives before the forward write")
    func appStoreIdentityPreflightCASPreservesExternalEdit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-prewrite-external")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let originalURL = vaultURL.appendingPathComponent("Original.md")
        let originalBytes = Data("# Original\n\noriginal body\n".utf8)
        let externalBytes = Data("# External\n\nexternal edit before CAS\n".utf8)
        try AtomicVaultWriter.writeSynchronously(originalBytes, to: originalURL)

        let page = SDPage(title: "Original")
        page.filePath = originalURL.path
        page.lastSyncedBodyHash = SDPage.bodyHash(String(decoding: originalBytes, as: UTF8.self))
        page.needsVaultSync = false
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)
        service.setPageIdentityBeforeForwardWriteOverrideForTesting { _, writeURL in
            try AtomicVaultWriter.writeSynchronously(externalBytes, to: writeURL)
        }

        let result = await service.commitPageIdentityFileFirst(
            pageId: page.id,
            title: "Renamed",
            tags: [],
            folder: nil,
            subfolder: nil,
            markdownBody: "# Renamed\n\ntransaction body\n"
        )

        #expect(result == .recoveryRequired)
        #expect(try Data(contentsOf: originalURL) == externalBytes)
        #expect(page.title == "Original")
        #expect(page.filePath == originalURL.path)
    }

    @Test("App Store identity move preserves a destination that appears after path selection")
    func appStoreIdentityMovePreservesRacingDestination() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-destination-race")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let originalURL = vaultURL.appendingPathComponent("Original.md")
        let destinationURL = vaultURL.appendingPathComponent("Renamed.md")
        let originalBytes = Data("# Original\n\noriginal body\n".utf8)
        let externalDestinationBytes = Data("# External\n\nracing destination\n".utf8)
        try AtomicVaultWriter.writeSynchronously(originalBytes, to: originalURL)

        let page = SDPage(title: "Original")
        page.filePath = originalURL.path
        page.lastSyncedBodyHash = SDPage.bodyHash(String(decoding: originalBytes, as: UTF8.self))
        page.needsVaultSync = false
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)
        service.setPageIdentityBeforeForwardWriteOverrideForTesting { _, _ in
            try AtomicVaultWriter.writeSynchronously(externalDestinationBytes, to: destinationURL)
        }

        let result = await service.commitPageIdentityFileFirst(
            pageId: page.id,
            title: "Renamed",
            tags: [],
            folder: nil,
            subfolder: nil,
            markdownBody: "# Renamed\n\ntransaction body\n"
        )

        #expect(result == .rolledBack)
        #expect(try Data(contentsOf: originalURL) == originalBytes)
        #expect(try Data(contentsOf: destinationURL) == externalDestinationBytes)
        #expect(page.title == "Original")
        #expect(page.filePath == originalURL.path)
    }

    @Test("App Store identity rollback preserves an external edit that replaces transaction bytes")
    func appStoreIdentityRollbackPreservesExternalEditAfterForwardWrite() async throws {
        enum StubError: Error { case externalEditArrived }

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-postwrite-external")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let originalURL = vaultURL.appendingPathComponent("Original.md")
        let originalBytes = Data("# Original\n\noriginal body\n".utf8)
        let externalBytes = Data("# External\n\nexternal edit after CAS\n".utf8)
        try AtomicVaultWriter.writeSynchronously(originalBytes, to: originalURL)

        let page = SDPage(title: "Original")
        page.filePath = originalURL.path
        page.lastSyncedBodyHash = SDPage.bodyHash(String(decoding: originalBytes, as: UTF8.self))
        page.needsVaultSync = false
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)
        service.setPageIdentityAfterForwardWriteOverrideForTesting { _, writeURL in
            try AtomicVaultWriter.writeSynchronously(externalBytes, to: writeURL)
            throw StubError.externalEditArrived
        }

        let result = await service.commitPageIdentityFileFirst(
            pageId: page.id,
            title: "Renamed",
            tags: [],
            folder: nil,
            subfolder: nil,
            markdownBody: "# Renamed\n\ntransaction body\n"
        )

        #expect(result == .recoveryRequired)
        #expect(try Data(contentsOf: originalURL) == externalBytes)
        #expect(page.title == "Original")
        #expect(page.filePath == originalURL.path)
    }

    @Test("App Store identity commits serialize the entire per-note file transaction")
    func appStoreIdentityCommitsSerializeWholeTransactionPerPage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-identity-serialization")
        let noteBodiesURL = try makeTempDirectory(prefix: "keelstone-identity-serialization-bodies")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: noteBodiesURL)
        }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) { @MainActor in
            let page = SDPage(title: "Old")
            let originalURL = vaultURL.appendingPathComponent("Old.md")
            let firstURL = vaultURL.appendingPathComponent("First.md")
            let secondURL = vaultURL.appendingPathComponent("Second.md")
            let originalBody = "# Old\n\nOriginal body\n"
            let firstBody = "# First\n\nFirst body\n"
            let secondBody = "# Second\n\nSecond body\n"
            try AtomicVaultWriter.writeSynchronously(Data(originalBody.utf8), to: originalURL)
            page.body = originalBody
            page.filePath = originalURL.path
            page.lastSyncedBodyHash = SDPage.bodyHash(originalBody)
            context.insert(page)
            try context.save()

            service.setVaultURLForTesting(vaultURL)
            let gate = PageIdentityExportGate()
            service.setPageIdentityAfterForwardWriteOverrideForTesting { _, _ in
                _ = await gate.begin()
            }

            let firstCommit = Task { @MainActor in
                await service.commitPageIdentityFileFirst(
                    pageId: page.id,
                    title: "First",
                    tags: ["first"],
                    folder: nil,
                    subfolder: nil,
                    markdownBody: firstBody
                )
            }
            await gate.waitUntilFirstStarted()

            let secondCommit = Task { @MainActor in
                await service.commitPageIdentityFileFirst(
                    pageId: page.id,
                    title: "Second",
                    tags: ["second"],
                    folder: nil,
                    subfolder: nil,
                    markdownBody: secondBody
                )
            }
            await Task.yield()
            await Task.yield()

            #expect(page.title == "Old")
            #expect(await gate.count() == 1)
            await gate.releaseFirst()

            #expect(await firstCommit.value == .committed)
            #expect(await secondCommit.value == .committed)
            #expect(await gate.count() == 2)
            #expect(page.title == "Second")
            #expect(page.tags == ["second"])
            #expect(page.filePath == secondURL.path)
            #expect(!FileManager.default.fileExists(atPath: originalURL.path))
            #expect(!FileManager.default.fileExists(atPath: firstURL.path))
            let secondSource = try String(contentsOf: secondURL, encoding: .utf8)
            let (secondFrontMatter, persistedSecondBody) = VaultIndexActor.parseFrontMatter(secondSource)
            #expect(secondFrontMatter["title"] == "Second")
            #expect(secondFrontMatter["tags"] == "second")
            #expect(persistedSecondBody == secondBody)
        }
    }

    @Test("App Store identity move failure restores durable body metadata and deterministic search truth")
    func appStoreIdentityMoveFailureRestoresAllDurableAndDerivedTruth() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let root = try makeTempDirectory(prefix: "keelstone-identity-derived-rollback")
        let vaultURL = root.appendingPathComponent("Vault", isDirectory: true)
        let noteBodiesURL = root.appendingPathComponent("Bodies", isDirectory: true)
        let searchURL = root.appendingPathComponent("search.sqlite")
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: root)
        }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL) { @MainActor in
            let targetFolder = SDFolder(name: "Blocked")
            let page = SDPage(title: "Old")
            let originalURL = vaultURL.appendingPathComponent("Old.md")
            let blockedFolderURL = vaultURL.appendingPathComponent(targetFolder.relativePath)
            let oldBody = "# Old\n\noldrollbackneedle\n"
            let forwardBody = "# New\n\nforwardrollbackneedle\n"
            let originalBytes = Data(oldBody.utf8)
            let originalUpdatedAt = Date(timeIntervalSince1970: 1_726_000_000)
            try AtomicVaultWriter.writeSynchronously(originalBytes, to: originalURL)
            try AtomicVaultWriter.writeSynchronously(Data("not a directory".utf8), to: blockedFolderURL)

            page.filePath = originalURL.path
            page.body = oldBody
            page.updatedAt = originalUpdatedAt
            page.lastSyncedBodyHash = SDPage.bodyHash(oldBody)
            page.lastSyncedAt = originalUpdatedAt
            page.needsVaultSync = false
            context.insert(targetFolder)
            context.insert(page)
            try context.save()

            service.setVaultURLForTesting(vaultURL)
            let searchService = try SearchIndexService(databaseURL: searchURL)
            await service.setSearchServiceForTesting(searchService)
            try searchService.upsert(
                id: page.id,
                title: page.title,
                body: oldBody,
                tags: "",
                updatedAt: originalUpdatedAt
            )

            let result = await service.commitPageIdentityFileFirst(
                pageId: page.id,
                title: "New",
                tags: ["forward"],
                folder: targetFolder,
                subfolder: targetFolder.relativePath,
                markdownBody: forwardBody
            )

            #expect(result == .rolledBack)
            #expect(try Data(contentsOf: originalURL) == originalBytes)
            #expect(page.title == "Old")
            #expect(page.filePath == originalURL.path)
            #expect(page.updatedAt == originalUpdatedAt)
            #expect(page.lastSyncedBodyHash == SDPage.bodyHash(oldBody))
            #expect(page.lastSyncedAt == originalUpdatedAt)
            #expect(!page.needsVaultSync)
            #expect(NoteFileStorage.stagedOrPersistedDraftBody(pageId: page.id) == oldBody)
            #expect(try searchService.search(query: "oldrollbackneedle").contains { $0.pageId == page.id })
            #expect(try searchService.search(query: "forwardrollbackneedle").isEmpty)

            let verificationContext = ModelContext(container)
            let pageID = page.id
            let persistedPage = try #require(try verificationContext.fetch(
                FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageID })
            ).first)
            #expect(persistedPage.title == "Old")
            #expect(persistedPage.filePath == originalURL.path)
            #expect(persistedPage.lastSyncedBodyHash == SDPage.bodyHash(oldBody))
            #expect(!persistedPage.needsVaultSync)
        }
    }

    @Test("App Store Source file moves migrate their hashed code sidecar")
    func appStoreSourceMoveMigratesCodeSidecar() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-source-sidecar-move")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let codeService = CodeFileService(vaultRoot: vaultURL)
        let originalURL = try codeService.createCodeFile(
            relativeDirectory: "Code",
            name: "Original",
            kind: .swift,
            body: "struct Original {}\n",
            provenance: CodeProvenance(producer: .human)
        )
        let originalRelativePath = "Code/Original.swift"
        let movedRelativePath = "Moved/Original.swift"
        let originalSidecarURL = CodeSidecarPath.sidecarURL(
            forVaultRoot: vaultURL,
            vaultRelativePath: originalRelativePath
        )
        let movedSidecarURL = CodeSidecarPath.sidecarURL(
            forVaultRoot: vaultURL,
            vaultRelativePath: movedRelativePath
        )
        let page = SDPage(title: "Original")
        page.format = "code"
        page.filePath = originalURL.path
        context.insert(page)
        try context.save()
        service.setVaultURLForTesting(vaultURL)

        #expect(service.movePage(pageId: page.id, toSubfolder: "Moved"))
        #expect(!FileManager.default.fileExists(atPath: originalSidecarURL.path))
        #expect(FileManager.default.fileExists(atPath: movedSidecarURL.path))
        let sidecar = try JSONDecoder.epdocCanonical.decode(
            CodeArtifactSidecar.self,
            from: Data(contentsOf: movedSidecarURL)
        )
        #expect(sidecar.vaultRelativePath == movedRelativePath)
        #expect(sidecar.kind == .swift)
    }

    @Test("App Store editor identity popover writes the real vault-backed note fields")
    func appStoreEditorIdentityPopoverWritesVaultBackedNoteFields() throws {
        let draft = NoteIdentityDraft(
            title: "  Research\nPlan  ",
            tagsText: "  research, Swift, RESEARCH, , vault  ",
            folderID: "projects"
        )
        #expect(draft.normalizedTitle == "Research Plan")
        #expect(draft.normalizedTags == ["research", "Swift", "vault"])
        #expect(draft.folderID == "projects")

        let body = "# Previous title\n\nBody"
        #expect(
            ProseEditorView.replacingSyncedNoteTitle(in: body, with: draft.normalizedTitle)
                == "# Research Plan\n\nBody"
        )
        #expect(
            ProseEditorView.replacingSyncedNoteTitle(
                in: "```markdown\n# Not a title\n```\n\nBody",
                with: "Ignored"
            ) == nil
        )

        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let popover = try loadRepoTextFile("Epistemos/Views/Notes/NoteIdentityPopover.swift")
        #expect(workspace.contains("noteIdentityTitleControl(page)"))
        #expect(workspace.contains("graphEmbeddedToolbarTitle(page)"))
        #expect(workspace.contains("commitNoteIdentity(draft, for: page)"))
        #expect(workspace.contains("vaultSync.commitPageIdentityFileFirst("))
        #expect(popover.contains("identityField(label: \"Name\")"))
        #expect(popover.contains("identityField(label: \"Tags\")"))
        #expect(popover.contains("identityField(label: \"Where\")"))
        #expect(!popover.contains("MarkEdit"))
    }

    @Test("App Store Epdoc uses bounded JS document stats while typing")
    func appStoreEpdocUsesBoundedDocumentStatsWhileTyping() async throws {
        let controller = EpdocEditorChromeController()
        let initialJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"initial"}]}]}"#.data(using: .utf8)!
        let firstEditJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"outdated status"}]}]}"#.data(using: .utf8)!
        let latestEditJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"latest words only"}]}]}"#.data(using: .utf8)!

        controller.loadInitialContent(initialJSON, title: "Typing stability")
        controller.installEditorDispatch { _ in }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.contentDidChange(json: initialJSON), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: firstEditJSON), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: latestEditJSON), epoch: 1)
        controller.handleBridgeMessage(.documentStatsChanged(wordCount: 9, characterCount: 99), epoch: 1)

        try await Task.sleep(for: .milliseconds(400))

        #expect(controller.toolbarModel.isDirty)
        #expect(controller.toolbarModel.characterCount == 99)
        #expect(controller.toolbarModel.wordCount == 9)
    }

    @Test("App Store editors keep full Epdoc status work off ordinary typing and Source H1 uses Matrix Bold")
    func appStoreEditorsKeepTypingStableAndSourceH1UsesMatrixBold() throws {
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let liveMutation = try #require(sourceSection(
            in: chrome,
            startingAt: "onContentChanged(json)",
            endingBefore: "        case let .markdownDidChange(markdown, writeback):"
        ))
        let sourceTheme = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorThemePalette.swift")
        let runtimeResources = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")
        let fontRegistry = try loadRepoTextFile("Epistemos/Theme/EpistemosFont.swift")
        let tiptapIndex = try loadRepoTextFile("js-editor/src/index.ts")
        let tiptapInbound = try loadRepoTextFile("js-editor/src/bridge/inbound.ts")
        let tiptapMarkdownFallback = try #require(sourceSection(
            in: tiptapIndex,
            startingAt: "function markdownSnapshotWithVisibleTextFallback",
            endingBefore: "function markdownBodyText"
        ))
        let tiptapContentSnapshot = try #require(sourceSection(
            in: tiptapIndex,
            startingAt: "function postContentDidChangeSnapshot",
            endingBefore: "function documentIsLarge"
        ))
        let tiptapInboundSnapshot = try #require(sourceSection(
            in: tiptapInbound,
            startingAt: "function postDocumentSnapshot",
            endingBefore: "function runEditorCommand"
        ))
        let swiftSnapshotProvider = try #require(sourceSection(
            in: chrome,
            startingAt: "private func evaluateCurrentMarkdownSnapshot()",
            endingBefore: "        // MARK: - Outbound"
        ))

        #expect(chrome.contains("enum EpdocEditorPerformancePolicy"))
        #expect(chrome.contains("smallDocumentStatusJSONByteLimit"))
        #expect(liveMutation.contains("scheduleDerivedStatusRefresh(from: json)"))
        #expect(!liveMutation.contains("refreshDerivedStatus(from: json)"))
        #expect(chrome.contains("Live `documentStatsChanged`"))
        #expect(!chrome.contains("Task.detached(priority: .utility)"))
        #expect(!liveMutation.contains("EpdocDerivedStatusSnapshot.resolve(from: json)"))
        #expect(tiptapIndex.contains("markdownProjectionMode"))
        #expect(tiptapIndex.contains("LARGE_DOCUMENT_NODE_SIZE"))
        #expect(tiptapIndex.contains("MARKDOWN_FULL_SNAPSHOT_IDLE_MS"))
        #expect(tiptapIndex.contains("scheduleDeferredFullMarkdownSnapshot(ed)"))
        #expect(tiptapIndex.contains("postMarkdownDidChange(editor, { preferWriteback: false })"))
        #expect(tiptapInbound.contains("postContentSnapshot?: (editor: Editor) => void"))
        #expect(tiptapInbound.contains("postDocumentSnapshot(editor, callbacks.postContentSnapshot, callbacks.postMarkdownSnapshot)"))
        #expect(tiptapContentSnapshot.contains("if (markdownProjectionMode) return;"))
        #expect(tiptapContentSnapshot.contains("JSON.stringify(ed.getJSON())"))
        #expect(tiptapInboundSnapshot.contains("if (postContentSnapshot)"))
        #expect(tiptapInboundSnapshot.contains("postContentSnapshot(editor)"))
        #expect(tiptapInboundSnapshot.contains("JSON.stringify(editor.getJSON())"))
        #expect(tiptapMarkdownFallback.contains("if (markdownBodyText(markdown).trim().length > 0) return markdown;"))
        let tiptapBodyCheckIndex = try #require(tiptapMarkdownFallback.range(of: "markdownBodyText(markdown)")?.lowerBound)
        let tiptapTextScanIndex = try #require(tiptapMarkdownFallback.range(of: "textBetween(")?.lowerBound)
        #expect(tiptapBodyCheckIndex < tiptapTextScanIndex)
        #expect(swiftSnapshotProvider.contains("markdownBodyText(markdown).trim().length > 0"))
        let swiftBodyCheckIndex = try #require(swiftSnapshotProvider.range(of: "markdownBodyText(markdown)")?.lowerBound)
        let swiftTextScanIndex = try #require(swiftSnapshotProvider.range(of: "textBetween(")?.lowerBound)
        #expect(swiftBodyCheckIndex < swiftTextScanIndex)

        #expect(sourceTheme.contains("sourceHeading1FontFace"))
        #expect(sourceTheme.contains(".cm-md-heading1 {"))
        #expect(sourceTheme.contains("font-family: ${sourceHeading1FontFace}"))
        #expect(sourceTheme.contains("/chunk-loader/fonts/MatrixTypeDisplay-Bold.otf"))
        #expect(runtimeResources.contains("static let fontHost = \"fonts\""))
        #expect(runtimeResources.contains("\"otf\": \"font/otf\""))
        #expect(fontRegistry.contains("registerFont(named: \"MatrixtypeDisplay-9MyE5\", extension: \"ttf\")"))
        #expect(fontRegistry.contains("registerFont(named: \"MatrixTypeDisplay-Bold\", extension: \"otf\")"))
        #expect(fontRegistry.contains("registerFont(named: \"MatrixDotsDemoRegular\", extension: \"ttf\")"))
        #expect(fontRegistry.contains("registerFont(named: \"ChonkyPixels\", extension: \"ttf\")"))
        #expect(fontRegistry.contains("registerFont(named: \"GNF\", extension: \"ttf\")"))
    }

    @Test("App Store Markdown editors start Matrix Bold loading before CoreEditor becomes visible")
    func appStoreSourcePreloadsMatrixBoldBeforeCoreEditorStartup() throws {
        let document = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")
        let sourceTheme = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorThemePalette.swift")

        #expect(document.contains("state.mode.usesMarkdownTypography"))
        #expect(document.contains("MarkEditCoreEditorSourceTypography.bootstrapHTML"))
        #expect(document.contains("templateWithSourceTypography"))
        #expect(sourceTheme.contains("enum MarkEditCoreEditorSourceTypography"))
        #expect(sourceTheme.contains("rel=\"preload\""))
        #expect(sourceTheme.contains("/chunk-loader/fonts/MatrixTypeDisplay-Bold.otf"))
        #expect(sourceTheme.contains("font-display: optional"))
        #expect(sourceTheme.contains("font-family: ${sourceHeading1FontFace}"))
    }

    @Test("App Store Prose restores scroll only after incoming layout has settled")
    func appStoreProseRestoresScrollAfterIncomingLayoutAndExternalSync() throws {
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let pageSwap = try #require(sourceSection(
            in: prose,
            startingAt: "func handlePageSwap()",
            endingBefore: "        // MARK: - Theme Change"
        ))
        let externalSync = try #require(sourceSection(
            in: prose,
            startingAt: "// External body sync",
            endingBefore: "        }\n\n        // MARK: - Page Swap"
        ))

        let centeringRange = try #require(pageSwap.range(of: "updateCentering()"))
        let restoreRange = try #require(pageSwap.range(of: "ProseEditorScrollRestoration.restore"))
        #expect(centeringRange.lowerBound < restoreRange.lowerBound)
        #expect(externalSync.contains("let scrollOrigin = scrollView?.contentView.bounds.origin ?? .zero"))
        #expect(externalSync.contains("ProseEditorScrollRestoration.restore(scrollOrigin, in: scrollView)"))
        #expect(prose.contains("enum ProseEditorScrollRestoration"))
        #expect(prose.contains("scrollView.reflectScrolledClipView(scrollView.contentView)"))
    }

    @Test("App Store Preview retains a bounded parsed layout for stable content")
    func appStorePreviewCachesStableContentAcrossGeometryRefreshes() throws {
        let preview = try loadRepoTextFile("Epistemos/Views/Notes/NotePreviewSurfaceView.swift")

        #expect(preview.contains("enum NotePreviewContentCache"))
        #expect(preview.contains("static let countLimit = 12"))
        #expect(preview.contains("NotePreviewContentCache.columns(for: content)"))
        #expect(preview.contains("NoteDualPreviewLayout.columnContents(in: content)"))
    }

    @Test("App Store lane does not double-schedule block mirrors before file-first saves")
    func appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let noteDraftStore = try loadRepoTextFile("Epistemos/Sync/NoteDraftStore.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let documentSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func saveMarkdownDocumentSurfaceContent(page: SDPage, markdown: String) async -> Bool",
            endingBefore: "    private func codeFileServiceForActiveVault("
        ))
        #expect(documentSave.contains("let editorRevision = documentEditorRevision"))
        #expect(documentSave.contains("if documentEditorRevision == editorRevision"))
        #expect(documentSave.contains("_ = noteSession.recordUserEdit(source: .user)"))
        let markdownSourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))
        let editorFlush = try #require(sourceSection(
            in: workspace,
            startingAt: "private func flushCurrentEditor(reason: NoteSessionSaveReason = .explicitSave) async -> NoteEditorFlushResult",
            endingBefore: "    @discardableResult\n    private func beginNoteSessionWrite("
        ))
        let proseSave = try #require(sourceSection(
            in: prose,
            startingAt: "private func debouncedSave(_ newValue: String)",
            endingBefore: "    /// NOTE-4"
        ))
        let fileFirstSave = try #require(sourceSection(
            in: vaultSync,
            startingAt: "func savePageBodyFileFirst(pageId: String, body: String) async -> Bool",
            endingBefore: "    @discardableResult\n    func recoverDraftIfNewer"
        ))

        #expect(documentSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: markdown)"))
        #expect(markdownSourceSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: persistedSourceBody)"))
        #expect(markdownSourceSave.contains("persistedContent.applyMarkdownNoteState(to: page)"))
        #expect(editorFlush.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: fullText)"))
        #expect(proseSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: newValue)"))
        #expect(proseSave.contains("NoteDraftStore.deleteIfMatching(pageId: pageId, durableBody: newValue)"))
        #expect(noteDraftStore.contains("private static let fileLock = NSLock()"))
        #expect(noteDraftStore.contains("draftMatchesDurableBody(draftBody, durableBody: durableBody)"))
        #expect(!noteDraftStore.contains("!draftBody.isEmpty else { continue }"))
        #expect(noteDraftStore.contains("_ = deleteIfMatching(pageId: pageId, durableBody: draftBody)"))
        #expect(!noteDraftStore.contains("defer { try? FileManager.default.removeItem(at: item) }"))
        #expect(!documentSave.contains("stageBodyWrite(pageId: pageId, fullText: markdown)"))
        #expect(!markdownSourceSave.contains("stageBodyWrite(pageId: pageId, fullText: persistedSourceBody)"))
        #expect(!editorFlush.contains("stageBodyWrite(pageId: pageId, fullText: fullText)"))
        #expect(!documentSave.contains("try modelContext.save()"))
        #expect(!markdownSourceSave.contains("try modelContext.save()"))
        #expect(!editorFlush.contains("try modelContext.save()"))
        #expect(!proseSave.contains("page.applyInteractiveDerivedState(from: newValue)"))
        #expect(!proseSave.contains("scheduleBlockMirrorSync(pageId: pageId, body: newValue)"))
        #expect(!proseSave.contains("saveModelContext(reason: \"debounced save"))
        #expect(!documentSave.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(!markdownSourceSave.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(!markdownSourceSave.contains("CodeFileService.updateCodeFileAsync("))
        #expect(!markdownSourceSave.contains("vaultSync.savePage(pageId: pageId)"))
        #expect(!editorFlush.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(fileFirstSave.contains("publishCommittedPageDerivedState(page: page, body: stagedBody)"))
        #expect(fileFirstSave.contains("page.applyInteractiveDerivedState(from: stagedBody)"))
        #expect(fileFirstSave.contains("page.updatedAt = .now"))
        let exportIndex = try #require(fileFirstSave.range(of: "let result = try await exportPage("))
        #expect(fileFirstSave.contains("indexForSearch: false"))
        #expect(fileFirstSave.contains("initialMutationFingerprint == pageBodyMutationFingerprint(for: page)"))
        let derivedIndex = try #require(fileFirstSave.range(of: "page.applyInteractiveDerivedState(from: stagedBody)"))
        #expect(fileFirstSave.contains("ProseEditorView.syncedNoteTitle(from: stagedBody)"))
        #expect(fileFirstSave.contains("performPageIdentityFileFirstCommit("))
        #expect(!fileFirstSave.contains("ProseEditorView.syncNoteTitleIfNeeded("))
        let saveIndex = try #require(fileFirstSave.range(of: "try context.save()"))
        let mirrorIndex = try #require(fileFirstSave.range(of: "publishCommittedPageDerivedState(page: page, body: stagedBody)"))
        #expect(exportIndex.lowerBound < derivedIndex.lowerBound)
        #expect(exportIndex.lowerBound < saveIndex.lowerBound)
        #expect(exportIndex.lowerBound < mirrorIndex.lowerBound)
        #expect(!fileFirstSave.contains("BlockMirror.sync(pageId: pageId, body: stagedBody"))
        #expect(vaultSync.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
    }

    @Test("App Store lane keeps dirty graph rebuilds out of graph startup")
    func appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let backgroundTests = try loadRepoTextFile("EpistemosTests/BackgroundGraphLoadingTests.swift")
        let appSource = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let controller = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")
        let metalGraph = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let loadGraph = try #require(sourceSection(
            in: graphState,
            startingAt: "func loadGraph(container: ModelContainer) async",
            endingBefore: "    /// Synchronous load for callers"
        ))
        let structuralRefresh = try #require(sourceSection(
            in: graphState,
            startingAt: "func refreshStructuralDataAsync(container: ModelContainer) async -> Bool",
            endingBefore: "    private func applyIncrementalStructuralRefresh("
        ))
        let openNode = try #require(sourceSection(
            in: graphState,
            startingAt: "func openNode(_ id: String)",
            endingBefore: "    func openNote(_ sourceId: String)"
        ))
        let ensureOverlay = try #require(sourceSection(
            in: controller,
            startingAt: "private func ensureOverlay(autoLoadGraph: Bool = true)",
            endingBefore: "    private func loadGraphForDocumentRevealIfNeeded() async"
        ))
        let routeLeave = try #require(sourceSection(
            in: overlay,
            startingAt: "graphOpenStartTask?.cancel()",
            endingBefore: "        // Leaving canvas (note / folder route)"
        ))
        let routeVisibilitySync = try #require(sourceSection(
            in: overlay,
            startingAt: "private func syncGraphWorkspaceChromeVisibility(isCanvas: Bool)",
            endingBefore: "    // MARK: - Fullscreen Handling"
        ))
        let pinnedPanelTimerStart = try #require(sourceSection(
            in: overlay,
            startingAt: "private func startPinnedPanelTimer()",
            endingBefore: "    private func stopPinnedPanelTimer()"
        ))
        let embeddedRouteSync = try #require(sourceSection(
            in: embedded,
            startingAt: "private func syncEmbeddedRouteState(_ route: GraphWorkspaceRoute)",
            endingBefore: "    private func scheduleEmbeddedCanvasStart()"
        ))
        let sidebarRefresh = try #require(sourceSection(
            in: sidebar,
            startingAt: "private func refreshGraphSidebarCachesIfNeeded()",
            endingBefore: "    private var notesContent: some View"
        ))
        let bootstrapCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "switch graphInitialRenderBootstrapState(",
            endingBefore: "        // Sync force params"
        ))
        let fullRecommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "        // Re-commit graph data when mode/filter changes",
            endingBefore: "        flushPendingInteractionInputs(engine: engine)"
        ))
        let scheduleFullCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "private func scheduleFullGraphCommitIfNeeded(",
            endingBefore: "    private func applyPostFullCommitCameraAction"
        ))
        let viewWindowCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "override func viewDidMoveToWindow()",
            endingBefore: "    private func refreshWindowObservers()"
        ))
        let fullOverlayCommit = try #require(sourceSection(
            in: overlay,
            startingAt: "        // Commit graph data after window is set up.",
            endingBefore: "        // Observe system appearance changes so the graph reacts"
        ))

        #expect(graphState.contains("func deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(graphState.contains("pendingRebuild = true"))
        #expect(openNode.contains("case .note, .person, .project, .topic, .decision, .event, .resource:"))
        #expect(openNode.contains("selectNode(nil)\n            openNote(resolvedId)"))
        #expect(openNode.contains("case .folder:\n            selectNode(nil)\n            openFolder(resolvedId)"))
        #expect(!openNode.contains("case .person:\n            selectNode(id)"))
        #expect(!openNode.contains("case .resource:\n            selectNode(id)"))
        #expect(metalGraph.contains("GraphSurfaceInlineEditability.opensInlineToday(node.type)"))
        #expect(metalGraph.contains("contextOpenNode("))
        #expect(metalGraph.contains("graphState?.openNode(nodeId)"))
        #expect(metalGraph.contains("graphState?.openNode(uuid)"))
        #expect(!metalGraph.contains("graphState?.requestEditorMode = true\n        graphState?.selectNode(uuid)"))
        #expect(loadGraph.contains("if store.nodeCount == 0, !isBuildingStructural"))
        #expect(loadGraph.contains("deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(!loadGraph.contains("if (needsRefresh || store.nodeCount == 0)"))
        #expect(structuralRefresh.contains("await store.loadFromRecordsCooperatively("))
        #expect(!structuralRefresh.contains("store.loadFromRecords(nodeRecords: records.nodes, edgeRecords: records.edges)"))
        #expect(graphStore.contains("let createdOrderTask = Task.detached(priority: .utility)"))
        #expect(graphStore.contains("_nodeIdsByCreatedAtDesc = await createdOrderTask.value"))
        #expect(backgroundTests.contains("func cooperativeRecordLoadingPreservesNewestFirstOrder()"))
        #expect(ensureOverlay.contains("if autoLoadGraph, hasActiveVault, needsRefresh, graphState.isLoaded"))
        #expect(ensureOverlay.contains("graphState.deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(!ensureOverlay.contains("refreshStructuralDataAsync(container: modelContainer)"))
        #expect(appSource.contains("private static func ensureEmbeddedGraphLoadStarted(bootstrap: AppBootstrap)"))
        #expect(appSource.contains("ensureEmbeddedGraphLoadStarted(bootstrap: bootstrap)"))
        #expect(appSource.contains("Task(priority: .utility) {\n                await graphState.loadGraph(container: modelContainer)\n            }"))
        #expect(appSource.contains("graphState.deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(routeLeave.contains("graphState.cancelOverlayPhysicsCycle()"))
        #expect(routeLeave.contains("metalView?.pauseEngine()"))
        #expect(routeLeave.contains("graphState.selectNode(nil)"))
        #expect(routeLeave.contains("inspectorState.clearSelection()"))
        #expect(routeVisibilitySync.contains("if isCanvas {\n            startPinnedPanelTimer()"))
        #expect(routeVisibilitySync.contains("stopPinnedPanelTimer()"))
        #expect(pinnedPanelTimerStart.contains("guard graphState.currentRoute.isCanvas else"))
        #expect(pinnedPanelTimerStart.contains("stopPinnedPanelTimer()"))
        #expect(embeddedRouteSync.contains("graphState.cancelOverlayPhysicsCycle()"))
        #expect(embeddedRouteSync.contains("quiesceEmbeddedInspectorWork()"))
        #expect(embedded.contains("private func quiesceEmbeddedInspectorWork()"))
        #expect(embedded.contains("graphState.selectNode(nil)\n        inspectorState.clearSelection()"))
        #expect(sidebar.contains("struct HologramSidebarCacheSnapshot: Sendable"))
        #expect(sidebar.contains("guard graphState.currentRoute.isCanvas else { return }"))
        #expect(sidebar.contains(".onChange(of: graphState.currentRoute) { _, route in"))
        #expect(sidebar.contains("cacheBuildTask?.cancel()"))
        #expect(sidebar.contains("updateGraphSearchResultsIfNeeded(for: queryText)"))
        #expect(sidebarRefresh.contains("let nodeRecords = Array(graphState.store.nodes.values)"))
        #expect(sidebarRefresh.contains("let edgeRecords = Array(graphState.store.edges.values)"))
        #expect(sidebarRefresh.contains("cacheBuildTask = Task(priority: .utility)"))
        #expect(sidebarRefresh.contains("await Task.yield()"))
        #expect(sidebarRefresh.contains("Task.detached(priority: .utility)"))
        #expect(sidebarRefresh.contains("HologramSidebarNotesTreeBuilder.buildCache("))
        #expect(!sidebarRefresh.contains("cachedNotesTreeSnapshot = HologramSidebarNotesTreeBuilder.build(store: graphState.store)"))
        #expect(metalGraph.contains("nonisolated struct GraphFullCommitPayload: Sendable"))
        #expect(metalGraph.contains("private var pendingFullGraphCommitVersion: Int?"))
        #expect(metalGraph.contains("private func scheduleFullGraphCommitIfNeeded("))
        #expect(metalGraph.contains("func scheduleGraphDataCommitIfNeeded(\n        isPageMode: Bool,\n        zoomToPageAfterCommit: Bool = false"))
        #expect(metalGraph.contains("Task.detached(priority: .utility)"))
        #expect(metalGraph.contains("makeVisibleNodeBatchPayloadFromSnapshot("))
        #expect(metalGraph.contains("makeVisibleEdgeBatchPayloadFromSnapshot("))
        #expect(scheduleFullCommit.contains("if pendingFullGraphCommitVersion == graphDataVersion"))
        #expect(scheduleFullCommit.contains("needsRender = false"))
        #expect(scheduleFullCommit.contains("pendingFullGraphCommitVersion = graphDataVersion"))
        #expect(bootstrapCommit.contains("scheduleFullGraphCommitIfNeeded(graphState: graphState, isPageMode: isPageMode)"))
        #expect(!bootstrapCommit.contains("commitGraphData()"))
        #expect(fullRecommit.contains("postCommitCameraAction: cameraAction"))
        #expect(!fullRecommit.contains("commitGraphData()"))
        #expect(viewWindowCommit.contains("scheduleGraphDataCommitIfNeeded(isPageMode: isPageMode)"))
        #expect(!viewWindowCommit.contains("commitGraphData()"))
        #expect(overlay.contains("graphView.scheduleGraphDataCommitIfNeeded(isPageMode:"))
        #expect(!overlay.contains("graphView.commitGraphData()"))
        #expect(fullOverlayCommit.contains("graphView.setAnchorRect(frame)"))
        #expect(fullOverlayCommit.contains("zoomToPageAfterCommit: isPageMode"))
        #expect(!fullOverlayCommit.contains("graphView.zoomInClose()"))
    }

    @Test("App Store Markdown Document dirty switch saves direct editor snapshot")
    func appStoreMarkdownDocumentDirtySwitchSavesDirectEditorSnapshot() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-fresh-snapshot-page",
            title: "App Store Fresh Snapshot Page",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/appstore-fresh-snapshot.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "Alpha typed before lens switch\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        coordinator.controller.handleBridgeMessage(
            .contentDidChange(
                json:
                #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Alpha typed before lens switch"}]}]}"#
                    .data(using: .utf8)!
            ),
            epoch: 1
        )
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown == ["Alpha typed before lens switch\n"])
        #expect(commands.isEmpty)
    }

    @Test("App Store Markdown Document pending snapshot switches without webview snapshot flush")
    func appStoreMarkdownDocumentPendingSnapshotSwitchSkipsWebViewSnapshotFlush() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []
        var directSnapshotRequests = 0

        coordinator.configure(
            pageId: "appstore-pending-snapshot-page",
            title: "App Store Pending Snapshot Page",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/appstore-pending-snapshot.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            directSnapshotRequests += 1
            return "Snapshot request should not be needed\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(markdown: "Alpha typed before lens switch\n", writeback: nil),
            epoch: 1
        )
        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown == ["Alpha typed before lens switch\n"])
        #expect(directSnapshotRequests == 0)
        #expect(commands.isEmpty)
    }

    @Test("App Store Markdown Document clean switch does not save normalized table snapshot")
    func appStoreMarkdownDocumentCleanSwitchDoesNotSaveNormalizedTableSnapshot() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-clean-switch-page",
            title: "App Store Clean Switch Page",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/appstore-clean-switch.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown.isEmpty)
        #expect(commands.isEmpty)
    }

    @Test("App Store lane parks Codex account backend and local session import")
    func appStoreLaneParksCodexAccountBackendAndLocalSessionImport() throws {
        let inference = try loadRepoTextFile("Epistemos/State/ProductRuntimeState.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let skills = try loadRepoTextFile("Epistemos/Vault/SkillDiscoveryCatalog.swift")
        let openAIProvider = try loadRepoTextFile("agent_core/src/providers/openai.rs")
        let bridge = try loadRepoTextFile("agent_core/src/bridge.rs")
        let scan = try loadRepoTextFile("scripts/scan_appstore_bundle.sh")
        let gate = try loadRepoTextFile("scripts/keelstone-release-gate.sh")

        #expect(!freeV1RetiredPathExists(
            "Epistemos/Engine/CloudProviderAuthService.swift",
            sourceFilePath: #filePath
        ))
        #expect(inference.contains("OpenAI local account import is unavailable in the App Store build"))
        #expect(inference.contains("private var openAIUsesCodexAccountRuntime: Bool"))
        #expect(inference.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        false"))
        #expect(bootstrap.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(bootstrap.contains("overrides[\"OPENAI_AUTH_MODE\"] = \"codex\""))
        #expect(settings.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n            if provider == .openAI"))
        #expect(settings.contains("ForEach(inference.cloudModels(for: provider), id: \\.self)"))
        #expect(skills.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(openAIProvider.contains("#[cfg(feature = \"mas-build\")]\n    fn from_env"))
        #expect(openAIProvider.contains("fn resolve_openai_auth(api_key: String) -> OpenAIAuth"))
        #expect(openAIProvider.contains("#[cfg(not(feature = \"mas-build\"))]\nconst OPENAI_CODEX_RESPONSES_API"))
        #expect(bridge.contains("#[cfg(not(feature = \"mas-build\"))]\n        \"openai_gpt53_codex\""))
        #expect(scan.contains("\\.codex/(auth|models_cache)\\.json"))
        #expect(scan.contains("backend-api/codex"))
        #expect(scan.contains("\\.claude/\\.credentials\\.json"))
        #expect(scan.contains("claude-cli/[0-9]"))
        #expect(scan.contains("platform\\.claude\\.com/v1/oauth/token"))
        #expect(gate.contains("require_appstore_no_parked_account_runtime_markers"))
    }

    @Test("App Store Settings coalesces rapid sidebar detail construction")
    func appStoreSettingsCoalescesRapidSidebarDetailConstruction() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("@State private var detailSelection: SettingsSection?"))
        #expect(settings.contains(".task(id: selection)"))
        #expect(settings.contains("SettingsDetailNavigationPolicy.debounceMilliseconds"))
        #expect(settings.contains("switch SettingsSection.safeDetailSelection(for: detailSelection)"))
        #expect(settings.contains("transaction.disablesAnimations = true"))
    }

    @Test("free V1 removes Daily Brief composition and Landing execution")
    func freeV1RemovesDailyBriefCompositionAndLandingExecution() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let retiredState = "State/DailyBriefState.swift"
        let sources = [
            try loadRepoTextFile("Epistemos/App/AppBootstrap.swift"),
            try loadRepoTextFile("Epistemos/App/AppEnvironment.swift"),
            try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift"),
        ]

        #expect(!freeV1RetiredPathExists(
            "Epistemos/\(retiredState)",
            sourceFilePath: #filePath
        ))
        #expect(!projectYML.contains("          - \(retiredState)"))
        #expect(!project.contains("\n\t\t\t\t\(retiredState),"))

        for source in sources {
            #expect(!source.contains("DailyBriefState"))
            #expect(!source.contains("dailyBriefState"))
            #expect(!source.contains("dailyBrief"))
            #expect(!source.contains("Daily Brief"))
        }
    }

    @Test("free V1 removes the legacy session graph generator without removing the canonical graph")
    func freeV1RemovesLegacySessionGraphGenerator() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let graphBuilder = try loadRepoTextFile("Epistemos/Graph/GraphBuilder.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let retiredService = "Vault/KnowledgeGraphService.swift"

        #expect(!freeV1RetiredPathExists(
            "Epistemos/\(retiredService)",
            sourceFilePath: #filePath
        ))
        #expect(!projectYML.contains("          - \(retiredService)"))
        #expect(!project.contains("\n\t\t\t\t\(retiredService),"))
        #expect(graphBuilder.contains("final class GraphBuilder"))
        #expect(graphStore.contains("final class GraphStore"))
    }

    @Test("free V1 removes legacy agent-session vault maintenance without removing vault sync")
    func freeV1RemovesLegacyAgentSessionVaultMaintenance() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        for retiredPath in [
            "Epistemos/Vault/VaultLifecycleService.swift",
            "Epistemos/Views/Vault/ConflictCardView.swift",
        ] {
            #expect(!freeV1RetiredPathExists(retiredPath, sourceFilePath: #filePath))
        }

        #expect(vaultSync.contains("final class VaultSyncService"))
    }

    @Test("free V1 hides workspace-summary controls and closes direct generation admission")
    func freeV1WorkspaceSummaryAdmissionFailsClosed() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let workspaceSummary = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")

        #expect(settings.contains("if ProductCapabilityPolicy.isAvailable(.generativeActions) {\n                Section(\"Workspace Summaries\")"))
        #expect(settings.contains("if ProductCapabilityPolicy.isAvailable(.generativeActions) {\n                Section(\"Live Notes\")"))
        #expect(workspaceSummary.contains("func startAutoSummaryLoop() {\n        guard ProductCapabilityPolicy.isAvailable(.generativeActions) else {\n            stopAutoSummaryLoop()\n            return\n        }"))
        #expect(workspaceSummary.contains("func generateSummaryNow() async {\n        guard ProductCapabilityPolicy.isAvailable(.generativeActions) else { return }"))
        #expect(workspaceSummary.contains("func generateSummaryNowReturning() async -> String? {\n        guard ProductCapabilityPolicy.isAvailable(.generativeActions) else { return nil }"))
    }

    @Test("free V1 preserves companion records without compiling companion runtime surfaces")
    func freeV1PreservesCompanionRecordsWithoutCompanionRuntimeSurfaces() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let schema = try loadRepoTextFile("Epistemos/Models/EpistemosSchema.swift")
        let companionModel = try loadRepoTextFile("Epistemos/Models/Companion/CompanionModel.swift")
        let localizable = try loadRepoTextFile("Epistemos/Resources/Localizable.xcstrings")
        let appSurface = try loadRepoTextFile("Epistemos/App/AppSurface.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let environment = try loadRepoTextFile("Epistemos/App/AppEnvironment.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!projectYML.contains("          - Views/Landing/Farm/**"))
        for retiredExclusion in [
            "Models/Companion/CompanionAnimationState.swift",
            "State/Companion/**",
        ] {
            #expect(!projectYML.contains("          - \(retiredExclusion)"))
        }
        for retiredSource in [
            "Engine/DeterministicPRNG.swift",
            "Models/Companion/CompanionAnimationState.swift",
            "State/Companion/CompanionOutputSchemaValidation.swift",
            "State/Companion/CompanionState.swift",
        ] {
            #expect(!freeV1RetiredPathExists(
                "Epistemos/\(retiredSource)",
                sourceFilePath: #filePath
            ))
            #expect(!project.contains("\n\t\t\t\t\(retiredSource),"))
            #expect(!projectYML.contains("          - \(retiredSource)"))
        }
        for retiredFarmSource in [
            "Views/Landing/Farm/CompanionAvatarGlyph.swift",
            "Views/Landing/Farm/CompanionCreationFlow.swift",
            "Views/Landing/Farm/CompanionDeleteSheet.swift",
            "Views/Landing/Farm/CompanionRoamingField.swift",
            "Views/Landing/Farm/CompanionRestoreSheet.swift",
            "Views/Landing/Farm/CompanionView.swift",
            "Views/Landing/Farm/LandingFarmView.swift",
            "Views/Landing/Farm/NotesSidebarSkin.swift",
        ] {
            #expect(!freeV1RetiredPathExists(
                "Epistemos/\(retiredFarmSource)",
                sourceFilePath: #filePath
            ))
            #expect(!project.contains("\n\t\t\t\t\(retiredFarmSource),"))
        }

        #expect(schema.contains("CompanionModel.self"))
        #expect(!projectYML.contains("          - Models/Companion/CompanionModel.swift"))
        for persistedDeclaration in [
            "@Attribute(.unique) var id: String",
            "var name: String = \"\"",
            "var tagline: String = \"\"",
            "var bodyKindRaw: String = \"orb\"",
            "var accentHex: String = \"#7BA8E0\"",
            "var identityHash: String = \"\"",
            "var createdAt: Date = Date.now",
            "var lastInteractedAt: Date = Date.now",
            "var archivedAt: Date?",
        ] {
            #expect(companionModel.contains(persistedDeclaration))
        }
        for retiredSymbol in [
            "CompanionBodyKind",
            "CompanionBodyFamily",
            "CompanionBlockAspect",
            "CompanionLegStyle",
            "CompanionAntennaStyle",
            "CompanionEyeTreatment",
            "CompanionHeadStyle",
            "CompanionArmStyle",
            "CompanionEyeShape",
            "CompanionAccessoryStyle",
            "creationPresets",
            "computeIdentityHash",
            "var bodyKind:",
            "var isArchived:",
            "displayName",
            "var hint:",
            "func customized(",
            "DeterministicPRNG",
            "agent",
            "chat",
            "tool",
            "renderer",
        ] {
            #expect(!companionModel.contains(retiredSymbol))
        }
        for retiredSymbol in [
            "CompanionState",
            "companionState",
            "seedDefaultIfEmpty",
        ] {
            #expect(!bootstrap.contains(retiredSymbol))
        }
        #expect(!environment.contains("companionState"))
        for retiredLocalizationKey in [
            "· %lld companion%@",
            "+ add companion",
            "Activate %@ as the foreground landing companion",
            "Companion %@",
            "COMPANIONS",
            "Create Companion",
            "no active\\ncompanion",
            "NO COMPANIONS",
            "Save Companion",
            "Status: display only",
        ] {
            #expect(!localizable.contains("\"\(retiredLocalizationKey)\" : {"))
        }
        #expect(!localizable.contains("LandingFarmView"))
        #expect(!appSurface.contains("rendersCompanionPresence"))
        for retiredSymbol in [
            "CompanionRosterEntry",
            "farmShowingCreate",
            "farmEditTarget",
            "farmDeleteTarget",
            "farmShowingRestore",
            "landingCompanionDock",
            "CompanionCreationFlow",
            "CompanionDeleteSheet",
            "CompanionRestoreSheet",
            "LandingFarmView",
            "presentFarmCompanionCreate",
            "presentFarmCompanionEdit",
            "dismissFarmCompanionEditor",
        ] {
            #expect(!landing.contains(retiredSymbol))
        }
    }

    @Test("free V1 physically removes the zero-caller conversation persistence producer")
    func freeV1PhysicallyRemovesConversationPersistenceProducer() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let runtimeValidation = try loadRepoTextFile("EpistemosTests/RuntimeValidationTests.swift")

        #expect(!freeV1RetiredPathExists(
            "Epistemos/Vault/ConversationPersistence.swift",
            sourceFilePath: #filePath
        ))
        #expect(!freeV1RetiredPathExists(
            "EpistemosTests/ConversationPersistenceTests.swift",
            sourceFilePath: #filePath
        ))
        #expect(!project.contains("\n\t\t\t\tVault/ConversationPersistence.swift,"))
        #expect(!projectYML.contains("          - Vault/ConversationPersistence.swift"))
        #expect(!runtimeValidation.contains("ConversationPersistence"))
        #expect(!runtimeValidation.contains("conversationPersistence"))
    }

    @Test("free V1 physically removes obsolete Omega verification scripts")
    func freeV1PhysicallyRemovesObsoleteOmegaVerificationScripts() throws {
        let releaseScriptAudit = try loadRepoTextFile("EpistemosTests/ReleaseScriptAuditTests.swift")

        #expect(!freeV1RetiredPathExists("omega_verify.sh", sourceFilePath: #filePath))
        #expect(!freeV1RetiredPathExists(
            "scripts/verify/omega_verify.sh",
            sourceFilePath: #filePath
        ))
        #expect(!freeV1RetiredPathExists("STARTING_PROMPT.md", sourceFilePath: #filePath))
        #expect(!freeV1RetiredPathExists("AGENT_PROGRESS.md", sourceFilePath: #filePath))
        #expect(!freeV1RetiredPathExists(
            "sprint-omega-1-foundation.md",
            sourceFilePath: #filePath
        ))
        for retiredReferenceImplementation in [
            "INTEGRATION_GUIDE.md",
            "compaction.rs",
            "prompt_caching.rs",
            "reference-code/INTEGRATION_GUIDE.md",
            "reference-code/compaction.rs",
            "reference-code/prompt_caching.rs",
            "reference-code/security.rs",
            "reference-code/think.rs",
            "security.rs",
            "think.rs",
        ] {
            #expect(!freeV1RetiredPathExists(
                retiredReferenceImplementation,
                sourceFilePath: #filePath
            ))
        }
        #expect(!releaseScriptAudit.contains("scripts/verify/omega_verify.sh"))
    }

    @Test("free V1 excludes the interactive provenance console without deleting provenance data")
    func freeV1ExcludesProvenanceConsoleWithoutDeletingProvenanceData() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let provenanceEvent = try loadRepoTextFile("Epistemos/Models/AgentProvenanceEvent.swift")

        for retiredPath in [
            "Engine/ProvenanceConsoleProjectionService.swift",
            "Views/Settings/ProvenanceConsoleView.swift",
        ] {
            #expect(!freeV1RetiredPathExists("Epistemos/\(retiredPath)", sourceFilePath: #filePath))
            #expect(!projectYML.contains("          - \(retiredPath)"))
            #expect(!project.contains("\n\t\t\t\t\(retiredPath),"))
        }

        #expect(settings.contains("case .provenance: GeneralDetailView()"))
        #expect(!settings.contains("ProvenanceConsoleView"))
        #expect(eventStore.contains("final class EventStore"))
        #expect(provenanceEvent.contains("public struct AgentProvenanceEvent"))
        #expect(!projectYML.contains("          - State/EventStore.swift"))
        #expect(!projectYML.contains("          - Models/AgentProvenanceEvent.swift"))
        #expect(!project.contains("\n\t\t\t\tState/EventStore.swift,"))
        #expect(!project.contains("\n\t\t\t\tModels/AgentProvenanceEvent.swift,"))
    }

    @Test("free V1 removes Writing Tools authority without removing the restricted MarkEdit editor")
    func freeV1ExcludesWritingToolsWithoutRemovingRestrictedMarkEditEditor() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let proseBridge = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let coreEditor = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let coreCoordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let corePackage = try loadRepoTextFile("LocalPackages/MarkEdit/MarkEditCore/Package.swift")
        let coreEntry = try loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/index.ts")
        let coreAPI = try loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/src/api/modules.ts")
        let coreExtensions = try loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/src/extensions.ts")
        let previewModule = try loadRepoTextFile("LocalPackages/MarkEdit/CoreEditor/src/modules/preview/index.ts")

        #expect(!freeV1RetiredPathExists(
            "Epistemos/MarkEdit/MarkEditShellCompatibility.swift",
            sourceFilePath: #filePath
        ))
        #expect(!projectYML.contains("          - MarkEdit/MarkEditShellCompatibility.swift"))
        #expect(!project.contains("MarkEdit/MarkEditShellCompatibility.swift"))

        let retiredWritingToolsBridge = "Views/Notes/WritingToolsBridge.swift"
        #expect(!freeV1RetiredPathExists(
            "Epistemos/\(retiredWritingToolsBridge)",
            sourceFilePath: #filePath
        ))
        #expect(!projectYML.contains("          - \(retiredWritingToolsBridge)"))
        #expect(!project.contains("\n\t\t\t\t\(retiredWritingToolsBridge),"))

        #expect(!projectYML.contains("- path: LocalPackages/MarkEdit/MarkEditMac/Sources"))
        #expect(!project.contains("path = LocalPackages/MarkEdit/MarkEditMac/Sources;"))
        #expect(!projectYML.contains("      - package: MarkEditKit"))
        #expect(!projectYML.contains("      - package: MarkEditModules"))
        #expect(!projectYML.contains("  MarkEditKit:\n"))
        #expect(!projectYML.contains("  MarkEditModules:\n"))
        #expect(!projectYML.contains("- path: LocalPackages/MarkEdit/MarkEditMac/Resources"))
        #expect(!projectYML.contains("- path: LocalPackages/MarkEdit/MarkEditMac/Base.lproj"))
        #expect(!projectYML.contains("- path: LocalPackages/MarkEdit/MarkEditMac/mul.lproj"))
        #expect(!projectYML.contains("- path: LocalPackages/MarkEdit/MarkEditMac/AppShortcuts.xcstrings"))
        #expect(projectYML.contains("      - package: MarkEditCore"))
        #expect(!projectYML.contains("          - Resources/chunks/**"))
        #expect(!projectYML.contains("          - chunks/**"))
        #expect(projectYML.contains("          - Resources/CoreEditor/chunks/**"))
        #expect(projectYML.contains("          - CoreEditor/chunks/**"))
        #expect(!project.contains("/* MarkEditKit in Frameworks */"))
        #expect(!project.contains("/* AppKitExtensions in Frameworks */"))
        #expect(!project.contains("/* Previewer in Frameworks */"))

        #expect(corePackage.contains("exclude: [\n        \"Extensions/WebKit+Extension.swift\",\n      ]"))
        #expect(!workspace.contains("showAppleWritingTools"))
        #expect(!workspace.contains("WritingToolsBridge"))
        #expect(!proseBridge.contains("WritingToolsBridge"))
        #expect(!proseBridge.contains("writingToolsObserver"))
        #expect(proseTextView.contains("tv.writingToolsBehavior = .none"))
        #expect(!proseTextView.contains("tv.writingToolsBehavior = .default"))
        #expect(!proseTextView.contains("WritingToolsBridge"))
        #expect(coreEditor.contains("#if EPISTEMOS_FREE_V1\n        configuration.writingToolsBehavior = .none"))
        #expect(coreEditor.contains("#if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)"))
        #expect(workspace.contains("#if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)"))
        #expect(!workspace.contains("#if canImport(MarkEditKit)"))
        #expect(coreEditor.contains("var allowsMarkEditWindowToolbar: Bool = false"))
        #expect(coreEditor.contains("webView.underPageBackgroundColor = .clear"))
        #expect(!coreEditor.contains("webView.setValue(false, forKey: \"drawsBackground\")"))
        for forbiddenNativeReplyModule in ["(\"api\",", "(\"foundationModels\",", "(\"translation\","] {
            #expect(!coreCoordinator.contains(forbiddenNativeReplyModule))
        }
        #expect(coreCoordinator.contains("case (\"preview\", \"show\")"))

        for forbiddenRuntimeModule in [
            "WebModuleAPIImpl",
            "WebModuleWritingToolsImpl",
            "WebModuleFoundationModelsImpl",
            "NativeModuleAPI",
            "NativeModuleFoundationModels",
            "NativeModuleTranslation",
        ] {
            #expect(!coreEntry.contains(forbiddenRuntimeModule))
        }
        for forbiddenAPI in [
            "Translator",
            "languageModel",
            "terminateApp",
            "showSavePanel",
            "runService",
            "openFile",
            "deleteFile",
            "getPasteboardItems",
        ] {
            #expect(!coreAPI.contains(forbiddenAPI))
        }
        #expect(!coreExtensions.contains("isWritingToolsActive"))

        #expect(previewModule.contains("export function showPreview(event: MouseEvent)"))
        #expect(previewModule.contains("window.nativeModules.preview.show({ code, type, rect: getClientRect(rect) });"))
        #expect(!projectYML.contains("          - Views/Notes/MarkEditCoreEditorView.swift"))
    }

    @Test("free V1 compiles no Browser ResearchHub or Foundation Models implementation")
    func freeV1ExcludesBrowserResearchHubAndFoundationModelsImplementation() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let policy = try loadRepoTextFile("Epistemos/App/ProductCapabilityPolicy.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let landingFeatures = try loadRepoTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let utilityWindows = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")
        let noteWindows = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")
        let dataDetection = try loadRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let pdfContext = try loadRepoTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeedPDFContextSource.swift")
        let noteContext = try loadRepoTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeedNoteContextSource.swift")
        let originalPDFAffordance = try loadRepoTextFile("Epistemos/LiteParse/ViewOriginalPDFAffordance.swift")
        let appTarget = try #require(sourceSection(
            in: projectYML,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  EpistemosWidgets:"
        ))
        let appSourceExceptions = try #require(sourceSection(
            in: project,
            startingAt: "37F519C8472FADBCC70357FE /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {",
            endingBefore: "45C30E899114488A41C98903 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {"
        ))
        let widgetTarget = try #require(sourceSection(
            in: projectYML,
            startingAt: "  EpistemosWidgets:",
            endingBefore: "  EpistemosAppStoreKeelstoneTests:"
        ))
        let widgetDebug = try #require(sourceSection(
            in: project,
            startingAt: "1F14548A8F23EC8EDB5E078D /* Debug */ = {",
            endingBefore: "270971C8366877BE7C679F8F /* Debug */ = {"
        ))
        let widgetRelease = try #require(sourceSection(
            in: project,
            startingAt: "669764D62A1F85DBFF0FBACD /* Release */ = {",
            endingBefore: "87BD216EA3C485A0985D9D33 /* Debug */ = {"
        ))

        #expect(widgetTarget.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS: \"$(inherited) DEBUG EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_FREE_V1\""))
        #expect(widgetTarget.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS: \"$(inherited) EPISTEMOS_APP_STORE MAS_SANDBOX EPISTEMOS_FREE_V1\""))
        #expect(widgetDebug.contains("EPISTEMOS_FREE_V1"))
        #expect(widgetRelease.contains("EPISTEMOS_FREE_V1"))

        let retiredBrowserDiagnosticsSources = [
            "Engine/BrowserCapabilityStatus.swift",
            "Views/Settings/BrowserCapabilityHealthRow.swift",
        ]
        for retiredSource in retiredBrowserDiagnosticsSources {
            #expect(!freeV1RetiredPathExists("Epistemos/\(retiredSource)", sourceFilePath: #filePath))
            #expect(!appTarget.contains("          - \(retiredSource)"))
            #expect(!appSourceExceptions.contains("\t\t\t\t\(retiredSource),"))
        }

        let excludedPatterns = [
            "Arxiv/**",
            "Engine/BrowserTrackerContentBlocker.swift",
            "Views/Arxiv/**",
            "Views/Browser/**",
        ]
        for excludedPattern in excludedPatterns {
            #expect(appTarget.contains("          - \(excludedPattern)"))
        }

        let excludedSources = [
            "Arxiv/ArxivClient.swift",
            "Arxiv/ArxivIngestService.swift",
            "Arxiv/ArxivPullGateStatus.swift",
            "Engine/BrowserTrackerContentBlocker.swift",
            "Views/Arxiv/ArxivSearchView.swift",
            "Views/Browser/BrowserHomePage.swift",
            "Views/Browser/BrowserThemeInjection.swift",
            "Views/Browser/BrowserView.swift",
        ]
        let retainedPaidSourceBodies = [
            try loadRepoTextFile("Epistemos/Arxiv/ArxivClient.swift"),
            try loadRepoTextFile("Epistemos/Arxiv/ArxivIngestService.swift"),
            try loadRepoTextFile("Epistemos/Arxiv/ArxivPullGateStatus.swift"),
            try loadRepoTextFile("Epistemos/Engine/BrowserTrackerContentBlocker.swift"),
            try loadRepoTextFile("Epistemos/Views/Arxiv/ArxivSearchView.swift"),
            try loadRepoTextFile("Epistemos/Views/Browser/BrowserHomePage.swift"),
            try loadRepoTextFile("Epistemos/Views/Browser/BrowserThemeInjection.swift"),
            try loadRepoTextFile("Epistemos/Views/Browser/BrowserView.swift"),
        ]
        #expect(retainedPaidSourceBodies.count == excludedSources.count)
        #expect(retainedPaidSourceBodies.allSatisfy { !$0.isEmpty })
        for excludedSource in excludedSources {
            #expect(appSourceExceptions.contains(excludedSource))
        }

        let foundationModelsSources = [
            try loadRepoTextFile("Epistemos/Graph/OntologyClassifier.swift"),
            try loadRepoTextFile("Epistemos/Engine/AppleIntelligenceService.swift"),
            try loadRepoTextFile("Epistemos/Engine/AFMSessionPool.swift"),
            try loadRepoTextFile("Epistemos/Engine/AFMSidecarGenerator.swift"),
            try loadRepoTextFile("Epistemos/Engine/IntakeValve.swift"),
            try loadRepoTextFile("Epistemos/Engine/ConversationStateClassifier.swift"),
            try loadRepoTextFile("Epistemos/Engine/SessionTelemetryClassifier.swift"),
        ]
        for source in foundationModelsSources {
            #expect(source.contains("#if !EPISTEMOS_FREE_V1 && canImport(FoundationModels)"))
            #expect(!source.contains("#if canImport(FoundationModels)"))
        }
        #expect(foundationModelsSources[1].contains("#if !EPISTEMOS_FREE_V1 && canImport(FoundationModels)\n    @available(macOS 26.0, *)\n    private func summarizeTranscript(session: LanguageModelSession)"))

        #expect(policy.contains("case browser"))
        #expect(policy.contains("case sourceDiscovery"))
        #expect(policy.contains(".browser,"))
        #expect(policy.contains(".sourceDiscovery:"))
        #expect(landing.contains("#if !EPISTEMOS_FREE_V1\n                HomeEmbeddedPage(title: \"arXiv\")"))
        #expect(landing.contains("#if !EPISTEMOS_FREE_V1\n                HomeEmbeddedPage(title: \"Browser\")"))
        #expect(landing.contains("#if !EPISTEMOS_FREE_V1\n        .sheet(isPresented: $showingArxivSearch)"))
        #expect(landingFeatures.contains("#if EPISTEMOS_FREE_V1\n            return false\n            #else\n            return ArxivPullGateStatus.status().isActive"))
        #expect(utilityWindows.contains("#if EPISTEMOS_FREE_V1\n                Color.clear\n                #else\n                BrowserView()"))
        #expect(noteWindows.contains("func openBrowserTab(url: String? = nil) {\n        #if EPISTEMOS_FREE_V1\n        return\n        #else\n        guard ProductCapabilityPolicy.isAvailable(.browser) else"))
        #expect(dataDetection.contains("#if EPISTEMOS_FREE_V1\n                NSWorkspace.shared.open(url)\n                #else\n                Task { @MainActor in\n                    NoteWindowManager.shared.openBrowserTab"))
        #expect(!settings.contains("BrowserCapabilityHealthRow"))
        #expect(!settings.contains("ProductCapabilityPolicy.isAvailable(.browser)"))
        #expect(pdfContext.contains("source == \"arxiv\""))
        #expect(pdfContext.contains("\"arxiv_id\""))
        #expect(pdfContext.contains("\"source_pdf\""))
        #expect(noteContext.contains("static func noteResults("))
        #expect(originalPDFAffordance.contains("ViewOriginalPDFAffordance"))

        #expect(projectYML.contains("      - package: KokoroPipeline"))
        #expect(projectYML.contains("      - package: MarkEditCore"))
        #expect(!projectYML.contains("          - VoicePro/**"))
        #expect(!projectYML.contains("          - Engine/EpistemosSpeechSynthesizer.swift"))
        #expect(!projectYML.contains("          - Views/Notes/MarkEditCoreEditorView.swift"))
    }

    @Test("free V1 compiles no NaturalLanguage model-backed analysis")
    func freeV1ExcludesNaturalLanguageModelBackedAnalysis() throws {
        let analysis = try loadRepoTextFile("Epistemos/Engine/NLAnalysisService.swift")
        let capture = try loadRepoTextFile("Epistemos/Engine/TextCapturePipeline.swift")
        let transparency = try loadRepoTextFile("Epistemos/Models/AgentTransparencyModels.swift")
        let noteInsights = try loadRepoTextFile("Epistemos/Engine/NoteInsightService.swift")
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let embeddings = try loadRepoTextFile("Epistemos/Graph/EmbeddingService.swift")
        let hologramInspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        let guardedImport = "#if !EPISTEMOS_FREE_V1\nimport NaturalLanguage\n#endif"
        for source in [
            analysis,
            capture,
            transparency,
            noteInsights,
            graphState,
            hologramInspector,
            inspectorState,
        ] {
            #expect(source.contains(guardedImport))
        }
        #expect(embeddings.contains("import NaturalLanguage"))
        #expect(embeddings.contains("#if EPISTEMOS_FREE_V1\n        AppleSentenceEmbeddingLookup()"))

        #expect(analysis.contains("#if EPISTEMOS_FREE_V1\n        return []\n        #else\n        let tagger = NLTagger"))
        #expect(analysis.contains("#if EPISTEMOS_FREE_V1\n        return nil\n        #else\n        let recognizer = NLLanguageRecognizer"))
        #expect(analysis.contains("#if EPISTEMOS_FREE_V1\n        return 0\n        #else\n        let tagger = NLTagger"))
        #expect(analysis.contains("#if EPISTEMOS_FREE_V1\n        return deterministicWordCount(text)"))
        #expect(capture.contains("#if EPISTEMOS_FREE_V1\n        var firstSentence = deterministicFirstSentence(in: text)"))
        #expect(capture.contains("#if EPISTEMOS_FREE_V1\n        return []\n        #else\n        let tagger = NLTagger"))
        #expect(transparency.contains("#if EPISTEMOS_FREE_V1\n        return deterministicFreeAnalysis(trimmed)"))

        #if EPISTEMOS_FREE_V1
        #expect(NLAnalysisService.extractEntities(from: "Jordan met Apple in Chicago.").isEmpty)
        #expect(NLAnalysisService.detectLanguage("This is an English sentence.") == nil)
        #expect(NLAnalysisService.sentiment(of: "I absolutely love this result.") == 0)
        #expect(NLAnalysisService.wordCount("naïve café 東京 123") == 4)

        let pipeline = TextCapturePipeline()
        #expect(pipeline.extractEntities(from: "Jordan met Apple in Chicago.").isEmpty)

        let personalityText = String(repeating: "Evidence questions and careful planning matter. ", count: 4)
        let firstSignals = ContentPersonalitySignals.analyze(personalityText)
        let secondSignals = ContentPersonalitySignals.analyze(personalityText)
        #expect(firstSignals == secondSignals)
        #expect(firstSignals.sentiment == 0)
        #expect(firstSignals.entityKeywords.isEmpty)
        #expect(!firstSignals.dominantTopics.isEmpty)
        #endif
    }

    @Test("free V1 App Intents compile graph is an exact deterministic whitelist")
    func freeV1AppIntentsCompileGraphUsesExactWhitelist() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let noteActions = try loadRepoTextFile("Epistemos/Intents/Custom/NoteActionIntents.swift")
        let cognitiveIntents = try loadRepoTextFile("Epistemos/Intents/Schemas/CognitiveIntents.swift")
        let focusFilters = try loadRepoTextFile("Epistemos/Intents/Schemas/EpistemosFocusFilters.swift")
        let controlWidget = try loadRepoTextFile("Epistemos/Intents/Schemas/EpistemosControlWidget.swift")
        let systemSearch = try loadRepoTextFile("Epistemos/Intents/Schemas/SystemSearchIntent.swift")
        let widgetBundle = try loadRepoTextFile("EpistemosWidgets/EpistemosWidgetsBundle.swift")
        let shortcutsProvider = try loadRepoTextFile("Epistemos/Intents/EpistemosShortcutsProvider.swift")
        let appTarget = try #require(sourceSection(
            in: projectYML,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  EpistemosWidgets:"
        ))
        let appSourceExceptions = try #require(sourceSection(
            in: project,
            startingAt: "37F519C8472FADBCC70357FE /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {",
            endingBefore: "45C30E899114488A41C98903 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {"
        ))

        for retiredIntentPath in [
            "Intents/Custom/AnalysisIntents.swift",
            "Intents/Custom/DailyBriefingIntent.swift",
            "Intents/Entities/BrainDumpEntity.swift",
            "Intents/Entities/ChatEntity.swift",
            "Intents/Schemas/VisualIntelligenceIntents.swift",
        ] {
            #expect(!freeV1RetiredPathExists("Epistemos/\(retiredIntentPath)", sourceFilePath: #filePath))
            #expect(!appTarget.contains("          - \(retiredIntentPath)"))
            #expect(!appSourceExceptions.contains("\t\t\t\t\(retiredIntentPath),"))
        }

        let excludedPatterns = ["Intents/Schemas/EpistemosControlWidget.swift"]
        for excludedPattern in excludedPatterns {
            #expect(appTarget.contains("          - \(excludedPattern)"))
            #expect(appSourceExceptions.contains("\t\t\t\t\(excludedPattern),"))
        }
        #expect(noteActions.contains("#if !EPISTEMOS_FREE_V1\n\n// MARK: Summarize Note"))
        #expect(noteActions.contains("#endif\n\n// MARK: Open Vault File"))
        #expect(cognitiveIntents.contains("#if !EPISTEMOS_FREE_V1\n\n// MARK: - 2. AttachThoughtToContext"))
        #expect(cognitiveIntents.hasSuffix("#endif\n"))
        #expect(focusFilters.contains("#if !EPISTEMOS_FREE_V1\nimport AppIntents\nimport OSLog\n#endif"))
        #expect(focusFilters.contains("#if !EPISTEMOS_FREE_V1\n\nprivate let focusLog"))
        #expect(focusFilters.hasSuffix("#endif\n"))
        #expect(controlWidget.contains("#if !EPISTEMOS_FREE_V1\n@available(macOS 26.0, *)\nstruct EpistemosSandboxControl"))
        #expect(controlWidget.contains("#endif\n\n// MARK: - WidgetBundle wrapper"))
        #expect(widgetBundle.contains("#if !EPISTEMOS_FREE_V1\n        EpistemosSandboxControl()\n        #endif"))
        #expect(systemSearch.contains("Searches across your local Epistemos notes and documents."))
        #expect(!systemSearch.contains("chat history"))
        #expect(!systemSearch.contains("notes, research"))

        let expectedShortcutIntents = [
            "CreateNoteIntent",
            "SystemSearchIntent",
            "QuickCaptureIntent",
            "CaptureBrainDumpIntent",
        ]
        #expect(shortcutsProvider.components(separatedBy: "AppShortcut(").count - 1 == 4)
        for expectedIntent in expectedShortcutIntents {
            #expect(shortcutsProvider.contains("intent: \(expectedIntent)()"))
        }
        for forbiddenIntent in [
            "AskAboutNotesIntent",
            "AttachThoughtToContextIntent",
            "DailyBriefingIntent",
            "DelegateToAgentIntent",
            "OpenRawThoughtSandboxIntent",
            "RecallActiveThesisIntent",
            "SummarizeNoteIntent",
        ] {
            #expect(!shortcutsProvider.contains(forbiddenIntent))
        }
    }

    @Test("free V1 app plist advertises no legacy SiriKit INIntent handlers")
    func freeV1AppPlistOmitsLegacySiriKitIntentHandlers() throws {
        let sourcePlist = try loadRepoTextFile("Epistemos-AppStore-Info.plist")
        let sourceData = try #require(sourcePlist.data(using: .utf8))
        let sourceDictionary = try #require(
            PropertyListSerialization.propertyList(
                from: sourceData,
                options: [],
                format: nil
            ) as? [String: Any]
        )

        #expect(sourceDictionary["INIntentsSupported"] == nil)
        #if EPISTEMOS_FREE_V1
        #expect(Bundle.main.object(forInfoDictionaryKey: "INIntentsSupported") == nil)
        #endif
    }

    @Test("free V1 privacy metadata matches explicit Meeting and Quick Capture transcription")
    func freeV1PrivacyMetadataMatchesExplicitMeetingTranscription() throws {
        let expectedMicrophonePurpose = "Epistemos uses the microphone only when you start Meeting transcription or Dictate in Quick Capture."
        let sourcePlist = try loadRepoTextFile("Epistemos-AppStore-Info.plist")
        let sourcePlistData = try #require(sourcePlist.data(using: .utf8))
        let sourceDictionary = try #require(
            PropertyListSerialization.propertyList(
                from: sourcePlistData,
                options: [],
                format: nil
            ) as? [String: Any]
        )
        let sourceEntitlements = try loadRepoTextFile("Epistemos/Epistemos-AppStore.entitlements")
        let sourceEntitlementsData = try #require(sourceEntitlements.data(using: .utf8))
        let sourceEntitlementsDictionary = try #require(
            PropertyListSerialization.propertyList(
                from: sourceEntitlementsData,
                options: [],
                format: nil
            ) as? [String: Any]
        )
        let analyzer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")

        #expect(sourceDictionary["NSMicrophoneUsageDescription"] as? String == expectedMicrophonePurpose)
        #expect(sourceDictionary["NSSpeechRecognitionUsageDescription"] == nil)
        #expect(sourceEntitlementsDictionary["com.apple.security.device.audio-input"] as? Bool == true)
        #expect(analyzer.contains("let granted = await AVCaptureDevice.requestAccess(for: .audio)"))
        #expect(analyzer.contains("let transcriber = SpeechTranscriber("))
        #expect(!analyzer.contains("SFSpeechRecognizer("))

        #if EPISTEMOS_FREE_V1
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String == expectedMicrophonePurpose)
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") == nil)
        #endif
    }

    @Test("free V1 Quick Capture dictation is real and cannot preempt another capture owner")
    func freeV1QuickCaptureDictationUsesScopedNativeVoiceCapture() throws {
        let quickCapture = try loadRepoTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        let removedAudioURL = try #require(Bundle(for: SourceGuardBundleToken.self).resourceURL)
            .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
            .appendingPathComponent("Epistemos/Engine/UnavailableAudioCapture.swift")
        let voiceInput = try loadRepoTextFile("Epistemos/Engine/LiveVoiceInputService.swift")
        let analyzer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")
        let voiceButton = try loadRepoTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")
        let meeting = try loadRepoTextFile("Epistemos/Engine/MeetingNoteCaptureService.swift")
        let meetingDraftStore = try loadRepoTextFile("Epistemos/Engine/MeetingDraftStore.swift")
        let utilityWindows = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let cognitiveIntents = try loadRepoTextFile("Epistemos/Intents/Schemas/CognitiveIntents.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!quickCapture.contains("@State private var audioRecorder = AudioRecorder()"))
        #expect(!quickCapture.contains("@State private var transcriber = AudioTranscriber()"))
        #expect(!quickCapture.contains("toggleAudioRecording()"))
        #expect(quickCapture.contains("VoiceInputButton("))
        #expect(quickCapture.contains("purpose: .quickCapture"))
        #expect(quickCapture.contains("QuickCaptureDraftStore"))
        #expect(quickCapture.contains("restoreQuickCaptureDraftIfNeeded()"))
        #expect(quickCapture.contains("persistQuickCaptureDraftBeforeDismissal()"))
        #expect(quickCapture.contains(".onChange(of: dictationPartial)"))
        #expect(quickCapture.contains("onActivityChange: { isActive in"))
        #expect(quickCapture.contains("Recovered unfinished dictation"))
        #expect(quickCapture.contains("QuickCaptureDraftStore.deleteIfMatching(submittedDraft)"))
        #expect(quickCapture.contains("maxBodyCharacters: QuickCaptureDraftStore.maxDraftCharacters"))
        #expect(quickCapture.contains("case rootOverlay = \"root-overlay\""))
        #expect(quickCapture.contains("case landingInline = \"landing-inline\""))
        #expect(quickCapture.contains("NotificationCenter.default.publisher(for: .requestQuickCaptureDismissal)"))
        #expect(quickCapture.contains("requestedSlot == presentationSlot else { return }"))
        #expect(rootView.contains("name: .requestQuickCaptureDismissal"))
        #expect(rootView.contains("object: QuickCapturePresentationSlot.rootOverlay"))
        #expect(rootView.contains("presentationSlot: .rootOverlay"))
        #expect(landing.contains("name: .requestQuickCaptureDismissal"))
        #expect(landing.contains("object: QuickCapturePresentationSlot.landingInline"))
        #expect(landing.contains("presentationSlot: .landingInline"))

        #expect(quickCapture.contains("try AtomicVaultWriter.writeSynchronously(data, to: url)"))
        #expect(quickCapture.contains("let encodedSize = values.fileSize"))
        #expect(quickCapture.contains("encodedSize <= maxEncodedDraftBytes"))
        #expect(quickCapture.contains("Data(contentsOf: url, options: .mappedIfSafe)"))
        #expect(quickCapture.contains("data.count <= maxEncodedDraftBytes"))

        let meetingDraftCoordinator = try #require(sourceSection(
            in: meetingDraftStore,
            startingAt: "private final class IOCoordinator: @unchecked Sendable",
            endingBefore: "    private static func directory(create: Bool, baseDirectory: URL?)"
        ))
        #expect(meetingDraftStore.contains("private static let maxEncodedDraftBytes = 16_004_096"))
        #expect(meetingDraftStore.contains("private static let coordinator = IOCoordinator()"))
        #expect(meetingDraftCoordinator.contains("private let queue = DispatchQueue("))
        #expect(meetingDraftCoordinator.contains("qos: .utility"))
        #expect(meetingDraftCoordinator.contains("private var latestRevisionByDraft: [String: UInt64] = [:]"))
        #expect(meetingDraftCoordinator.contains("private var terminalDrafts: Set<String> = []"))
        #expect(meetingDraftCoordinator.contains("func enqueueWrite("))
        #expect(meetingDraftCoordinator.contains("guard !terminalDrafts.contains(draftKey),"))
        #expect(meetingDraftCoordinator.contains("revision > currentRevision else { return }"))
        #expect(meetingDraftCoordinator.contains("func enqueueTerminalDelete("))
        #expect(meetingDraftCoordinator.contains("terminalRevision = max(revision, currentRevision + 1)"))
        let meetingTerminalRevision = try #require(
            meetingDraftCoordinator.range(of: "latestRevisionByDraft[draftKey] = terminalRevision")?.lowerBound
        )
        let meetingTerminalTombstone = try #require(
            meetingDraftCoordinator.range(of: "terminalDrafts.insert(draftKey)")?.lowerBound
        )
        let meetingTerminalOperation = try #require(
            meetingDraftCoordinator.range(of: "operation()", range: meetingTerminalTombstone..<meetingDraftCoordinator.endIndex)?.lowerBound
        )
        #expect(meetingTerminalRevision < meetingTerminalTombstone)
        #expect(meetingTerminalTombstone < meetingTerminalOperation)
        #expect(meetingDraftCoordinator.contains("queue.sync {}"))

        let meetingDraftWrite = try #require(sourceSection(
            in: meetingDraftStore,
            startingAt: "static func write(",
            endingBefore: "    /// Remove a session's draft"
        ))
        let meetingDraftDelete = try #require(sourceSection(
            in: meetingDraftStore,
            startingAt: "static func delete(",
            endingBefore: "    static func waitForPendingOperations()"
        ))
        #expect(meetingDraftWrite.contains("coordinator.enqueueWrite(draftKey: key, revision: revision)"))
        #expect(meetingDraftWrite.contains("data.count <= maxEncodedDraftBytes"))
        #expect(meetingDraftWrite.contains("try AtomicVaultWriter.writeSynchronously(data, to: url)"))
        #expect(meetingDraftDelete.contains("coordinator.enqueueTerminalDelete(draftKey: key, revision: revision)"))
        #expect(meetingDraftDelete.contains("try FileManager.default.removeItem(at: url)"))
        #expect(meetingDraftDelete.contains("try AtomicVaultWriter.synchronizeParentDirectory(of: url)"))
        #expect(meetingDraftStore.contains("static func waitForPendingOperations()"))
        #expect(meetingDraftStore.contains("coordinator.waitForPendingOperations()"))
        #expect(meetingDraftStore.contains("values.isRegularFile == true"))
        #expect(meetingDraftStore.contains("values.isSymbolicLink != true"))
        #expect(meetingDraftStore.contains("fileSize <= maxEncodedDraftBytes"))
        #expect(meetingDraftStore.contains("Data(contentsOf: item, options: .mappedIfSafe)"))

        #expect(quickCapture.contains("let committedText: String"))
        #expect(quickCapture.contains("let partialTranscript: String"))
        #expect(quickCapture.contains("captureText = QuickCaptureDraftStore.restoredCommittedText(from: draft)"))
        #expect(quickCapture.contains("recoveredDictationFragment = QuickCaptureDraftStore.recoveredPartialTranscript(from: draft)"))
        #expect(quickCapture.contains("Text(\"Recovered unfinished dictation\")"))
        #expect(quickCapture.contains("Button(\"Discard\")"))
        #expect(quickCapture.contains("Button(\"Add to Draft\")"))

        #expect(quickCapture.contains("guard decodeDraft(at: url, expectedSlot: expectedDraft.slot) == expectedDraft else"))
        #expect(quickCapture.contains("QuickCaptureDraftStore.deleteIfMatching(submittedDraft)"))
        #expect(quickCapture.contains("static let maxDraftCharacters = 2_000_000"))
        #expect(quickCapture.contains("maxBodyCharacters: QuickCaptureDraftStore.maxDraftCharacters"))

        #expect(!FileManager.default.fileExists(atPath: removedAudioURL.path))
        #expect(voiceInput.contains("VoiceCaptureLease"))
        #expect(voiceInput.contains("start(owner:"))
        #expect(voiceInput.contains("stop(owner:"))
        #expect(voiceInput.contains("tearDown(owner:"))
        #expect(voiceInput.contains("consumeTranscript(owner:"))
        #expect(analyzer.contains("sessionID: UUID"))
        #expect(analyzer.contains("stop(sessionID:"))
        #expect(analyzer.contains("guard activeSessionID == sessionID else { return }"))
        #expect(analyzer.contains("self?.stopInternal(sessionID: sessionID)"))
        #expect(voiceButton.contains("service.stop(owner: owner)"))
        #expect(voiceButton.contains("service.consumeTranscript(owner: owner)"))
        #expect(voiceButton.contains("service.tearDown(owner: owner)"))
        #expect(voiceButton.contains("public let onActivityChange: (Bool) -> Void"))
        #expect(voiceButton.contains("onActivityChange: @escaping (Bool) -> Void = { _ in }"))
        #expect(voiceButton.contains("if wasActive != isActive"))
        #expect(voiceButton.contains("onActivityChange(isActive)"))
        #expect(voiceButton.contains(".onChange(of: service.state) { _, _ in\n            syncPhaseFromService()"))
        let voiceTerminalSync = try #require(sourceSection(
            in: voiceButton,
            startingAt: "private func syncPhaseFromService()",
            endingBefore: "    private func drainAndRelease("
        ))
        #expect(voiceTerminalSync.contains("case .idle:"))
        #expect(voiceTerminalSync.contains("drainAndRelease(activeLease, terminalPhase: .idle, interrupted: false)"))
        #expect(voiceTerminalSync.contains("case .unavailable(let message), .error(let message):"))
        #expect(voiceTerminalSync.contains("drainAndRelease(activeLease, terminalPhase: .error(message), interrupted: true)"))

        let voiceTerminalDrain = try #require(sourceSection(
            in: voiceButton,
            startingAt: "private func drainAndRelease(",
            endingBefore: "    private func transition(to newPhase: Phase)"
        ))
        let voiceTerminalStop = try #require(
            voiceTerminalDrain.range(of: "service.stop(owner: owner)")?.lowerBound
        )
        let voiceTerminalConsume = try #require(
            voiceTerminalDrain.range(of: "service.consumeTranscript(owner: owner)")?.lowerBound
        )
        let voiceTerminalRelease = try #require(
            voiceTerminalDrain.range(of: "service.tearDown(owner: owner)")?.lowerBound
        )
        let voiceTerminalClearLease = try #require(
            voiceTerminalDrain.range(of: "activeLease = nil")?.lowerBound
        )
        #expect(voiceTerminalStop < voiceTerminalConsume)
        #expect(voiceTerminalConsume < voiceTerminalRelease)
        #expect(voiceTerminalRelease < voiceTerminalClearLease)
        #expect(quickCapture.contains("onActivityChange: { isActive in"))
        #expect(quickCapture.contains("isDictationActive = isActive"))
        #expect(!utilityWindows.contains("LiveVoiceInputService.shared.stop()"))

        let meetingTearDownStart = try #require(meeting.range(of: "func tearDownCapture()")?.lowerBound)
        let meetingDiscardStart = try #require(
            meeting.range(of: "func discard()", range: meetingTearDownStart..<meeting.endIndex)?.lowerBound
        )
        let meetingTearDown = meeting[meetingTearDownStart..<meetingDiscardStart]
        let meetingStop = try #require(meetingTearDown.range(of: "voiceInput.stop(owner: owner)")?.lowerBound)
        let meetingDrain = try #require(meetingTearDown.range(of: "voiceInput.consumeTranscript(owner: owner)")?.lowerBound)
        let meetingFlush = try #require(meetingTearDown.range(of: "flushDraft()")?.lowerBound)
        let meetingRelease = try #require(meetingTearDown.range(of: "voiceInput.tearDown(owner: owner)")?.lowerBound)
        #expect(meetingStop < meetingDrain)
        #expect(meetingDrain < meetingFlush)
        #expect(meetingFlush < meetingRelease)

        let meetingDraftSchedule = try #require(sourceSection(
            in: meeting,
            startingAt: "private func scheduleDraftWrite()",
            endingBefore: "    /// Write the current transcript immediately"
        ))
        let meetingDraftFlush = try #require(sourceSection(
            in: meeting,
            startingAt: "private func flushDraft()",
            endingBefore: "    /// Look for an unsaved transcript"
        ))
        let meetingRecoveryScan = try #require(sourceSection(
            in: meeting,
            startingAt: "func refreshRecoverableDraft()",
            endingBefore: "    /// Restore a recovered draft"
        ))
        #expect(meeting.contains("private var draftRevision: UInt64 = 0"))
        #expect(meeting.contains("private func nextDraftRevision() -> UInt64"))
        #expect(meetingDraftSchedule.contains("draftWriteTask?.cancel()"))
        #expect(meetingDraftSchedule.contains("MeetingDraftStore.write("))
        #expect(meetingDraftSchedule.contains("revision: self.nextDraftRevision()"))
        #expect(!meetingDraftSchedule.contains("Task.detached"))
        #expect(meetingDraftFlush.contains("draftWriteTask?.cancel()"))
        #expect(meetingDraftFlush.contains("MeetingDraftStore.write("))
        #expect(meetingDraftFlush.contains("revision: nextDraftRevision()"))
        #expect(meeting.contains("MeetingDraftStore.delete(\n                sessionId: sessionId,\n                revision: nextDraftRevision()"))
        #expect(meetingRecoveryScan.contains("recoveryScanTask?.cancel()"))
        #expect(meetingRecoveryScan.contains("Task.detached(priority: .utility)"))
        #expect(meetingRecoveryScan.contains("self.captureGeneration == generation"))
        #expect(meetingRecoveryScan.contains("self.transcriptText.isEmpty"))
        #expect(meetingRecoveryScan.contains("self.state == .idle"))

        let quickCaptureDisappear = try #require(sourceSection(
            in: quickCapture,
            startingAt: ".onDisappear {",
            endingBefore: "        .onChange(of: captureText)"
        ))
        let quickCaptureClose = try #require(sourceSection(
            in: quickCapture,
            startingAt: "private func close(restoreHomeFocus: Bool = true)",
            endingBefore: "    private func finishDismissal(restoreHomeFocus: Bool)"
        ))
        let quickCaptureRestore = try #require(sourceSection(
            in: quickCapture,
            startingAt: "private func restoreQuickCaptureDraftIfNeeded()",
            endingBefore: "    private func scheduleQuickCaptureDraftWrite()"
        ))
        let quickCaptureDraftSchedule = try #require(sourceSection(
            in: quickCapture,
            startingAt: "private func scheduleQuickCaptureDraftWrite()",
            endingBefore: "    private func persistQuickCaptureDraftBeforeDismissal()"
        ))
        let quickCaptureCloseProcessingGuard = try #require(
            quickCaptureClose.range(of: "guard !isProcessing else")?.lowerBound
        )
        let quickCaptureCloseDismissal = try #require(
            quickCaptureClose.range(of: "isDismissing = true")?.lowerBound
        )
        #expect(quickCaptureCloseProcessingGuard < quickCaptureCloseDismissal)
        #expect(quickCaptureClose.contains("Wait for this capture to finish saving before closing."))
        #expect(quickCaptureClose.contains("guard !isDictationActive else"))
        #expect(quickCaptureClose.contains("guard !isDismissing else { return }"))
        #expect(quickCaptureClose.contains("persistQuickCaptureDraftBeforeDismissal()"))
        let disappearDismissalGuard = try #require(
            quickCaptureDisappear.range(of: "isDismissing = true")?.lowerBound
        )
        let disappearInterruptedRecover = try #require(
            quickCaptureDisappear.range(of: "recoverInterruptedDictation(interruptedTranscript)")?.lowerBound
        )
        let disappearPersistence = try #require(
            quickCaptureDisappear.range(of: "persistQuickCaptureDraftForDisappearance()")?.lowerBound
        )
        let disappearCleanup = try #require(
            quickCaptureDisappear.range(of: "cleanupTransientCaptureState()")?.lowerBound
        )
        #expect(disappearInterruptedRecover < disappearDismissalGuard)
        #expect(disappearDismissalGuard < disappearPersistence)
        #expect(disappearPersistence < disappearCleanup)
        #expect(quickCaptureRestore.contains("Task.detached(priority: .utility)"))
        #expect(quickCaptureRestore.contains("QuickCaptureDraftStore.claim(slot: slot, sessionID: sessionID)"))
        #expect(quickCaptureRestore.contains("!Task.isCancelled"))
        #expect(quickCaptureRestore.contains("!isDismissing"))
        #expect(quickCaptureRestore.contains("ownsPresentation"))
        #expect(quickCaptureRestore.contains("QuickCapturePresentationRegistry.shared.owns(sessionID)"))
        #expect(quickCaptureRestore.contains("draftRevision = draft.revision"))
        #expect(quickCaptureRestore.contains("captureText = QuickCaptureDraftStore.restoredCommittedText(from: draft)"))
        #expect(quickCaptureRestore.contains("recoveredDictationFragment = QuickCaptureDraftStore.recoveredPartialTranscript(from: draft)"))
        #expect(quickCaptureRestore.contains("draftSessionReady = true"))
        #expect(!quickCaptureRestore.contains("max(draftRevision, draft.revision)"))
        #expect(!quickCaptureRestore.contains("scheduleQuickCaptureDraftWrite()"))
        #expect(quickCaptureDraftSchedule.contains("!draftFlushedForDismissal"))
        #expect(quickCaptureDraftSchedule.contains("!isDismissing,"))
        #expect(quickCaptureDraftSchedule.contains("ownsPresentation,"))
        #expect(quickCaptureDraftSchedule.contains("draftSessionReady,"))
        #expect(quickCaptureDraftSchedule.contains("QuickCapturePresentationRegistry.shared.owns(presentationOwnerID) else { return }"))
        #expect(quickCapture.contains(".disabled(isProcessing || isDismissing)"))

        #expect(settings.contains("use the Dictate button inside the overlay"))
        #expect(cognitiveIntents.contains("Leave blank to dictate."))
    }

    @Test("free V1 capture ownership and Quick Capture recovery are deterministic without audio")
    func freeV1CaptureOwnershipAndDraftRecoveryAreDeterministic() throws {
        let quickID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let meetingID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let quick = VoiceCaptureLease(id: quickID, purpose: .quickCapture)
        let meeting = VoiceCaptureLease(id: meetingID, purpose: .meeting)
        var registry = VoiceCaptureLeaseRegistry()

        #expect(registry.reserve(quick) == .acquired)
        #expect(registry.reserve(quick) == .alreadyOwned)
        #expect(registry.reserve(meeting) == .busy(.quickCapture))
        let releasedWrongOwner = registry.release(meeting)
        #expect(!releasedWrongOwner)
        #expect(registry.owns(quick))
        let releasedQuickCapture = registry.release(quick)
        #expect(releasedQuickCapture)
        #expect(registry.reserve(meeting) == .acquired)
        #expect(QuickCaptureDraftStore.maxDraftCharacters == 2_000_000)

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-store-quick-draft-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let initial = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            committedText: "Typed text",
            partialTranscript: "spoken fragment",
            revision: 2
        )
        let newer = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            committedText: "Newer text",
            partialTranscript: "",
            revision: 4
        )
        let stale = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            committedText: "Stale text",
            partialTranscript: "",
            revision: 3
        )
        let landing = QuickCaptureDraftStore.Draft(
            slot: .landingInline,
            committedText: "Landing text",
            partialTranscript: "",
            revision: 4
        )

        #expect(QuickCaptureDraftStore.write(initial, baseDirectory: base))
        #expect(QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: base) == initial)
        #expect(QuickCaptureDraftStore.restoredCommittedText(from: initial) == "Typed text")
        #expect(QuickCaptureDraftStore.recoveredPartialTranscript(from: initial) == "spoken fragment")
        #expect(QuickCaptureDraftStore.write(landing, baseDirectory: base))
        #expect(QuickCaptureDraftStore.write(newer, baseDirectory: base))
        #expect(!QuickCaptureDraftStore.write(stale, baseDirectory: base))
        #expect(QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: base) == newer)
        #expect(QuickCaptureDraftStore.load(slot: .landingInline, baseDirectory: base) == landing)

        let equalRevisionCollision = QuickCaptureDraftStore.Draft(
            slot: .rootOverlay,
            committedText: "Conflicting revision-four text",
            partialTranscript: "",
            revision: 4
        )
        #expect(!QuickCaptureDraftStore.write(equalRevisionCollision, baseDirectory: base))
        #expect(QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: base) == newer)
        #expect(!QuickCaptureDraftStore.deleteIfMatching(stale, baseDirectory: base))
        #expect(QuickCaptureDraftStore.deleteIfMatching(newer, baseDirectory: base))
        let retiredRootDraft = try #require(
            QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: base)
        )
        #expect(retiredRootDraft.isEmpty)
        #expect(retiredRootDraft.revision == newer.revision)
        #expect(!QuickCaptureDraftStore.write(stale, baseDirectory: base))
        #expect(QuickCaptureDraftStore.load(slot: .rootOverlay, baseDirectory: base) == retiredRootDraft)
        #expect(QuickCaptureDraftStore.load(slot: .landingInline, baseDirectory: base) == landing)
    }

    @Test("free V1 removes agent/cloud runtime residue and preserves external-owner exclusions")
    func freeV1RemovesAgentCloudRuntimeResidueAndPreservesExternalOwnerExclusions() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inference = try loadRepoTextFile("Epistemos/State/ProductRuntimeState.swift")
        let freeAssetCatalog = try loadRepoTextFile("Epistemos/Assets.xcassets/Contents.json")
        let retainedAccent = try loadRepoTextFile("Epistemos/Assets.xcassets/AccentColor.colorset/Contents.json")
        let retainedMenuBarIcon = try loadRepoTextFile("Epistemos/Assets.xcassets/MenuBarIcon.imageset/Contents.json")
        let appTarget = try #require(sourceSection(
            in: projectYML,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  EpistemosWidgets:"
        ))
        let appSourceExceptions = try #require(sourceSection(
            in: project,
            startingAt: "37F519C8472FADBCC70357FE /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {",
            endingBefore: "45C30E899114488A41C98903 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {"
        ))

        for retiredPattern in [
            "Views/Skills/**",
            "XPC/**",
            "Assets.xcassets/ProviderLogo*.imageset/**",
        ] {
            #expect(!appTarget.contains("          - \(retiredPattern)"))
        }

        let retiredRuntimeSettingsSource = "Views/Settings/RuntimeLanesSection.swift"
        #expect(!freeV1RetiredPathExists(
            "Epistemos/\(retiredRuntimeSettingsSource)",
            sourceFilePath: #filePath
        ))
        #expect(!appTarget.contains("          - \(retiredRuntimeSettingsSource)"))
        #expect(!appSourceExceptions.contains("\t\t\t\t\(retiredRuntimeSettingsSource),"))

        for retiredCloudSource in [
            "Epistemos/AgentSurface/AgentSurfaceChildLedger.swift",
            "Epistemos/LocalAgent/RuntimeRouter.swift",
            "Epistemos/State/ProductRuntimeState+RouteProfiles.swift",
            "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            "Epistemos/Views/Shared/ProviderBrandLogo.swift",
            "Epistemos/Views/Shared/ProviderLogoView.swift",
            "Epistemos/Views/Skills/SkillEvolutionView.swift",
            "Epistemos/XPC/AgentServiceClient.swift",
            "Epistemos/XPC/AgentServiceProtocol.swift",
            "Epistemos/XPC/MockProviderServiceStreaming.swift",
            "Epistemos/XPC/ProviderServiceClient.swift",
            "Epistemos/XPC/ProviderServiceStreamingProtocol.swift",
            "Epistemos/XPC/XPCTrust.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(retiredCloudSource, sourceFilePath: #filePath),
                "Free V1 must physically remove \(retiredCloudSource)."
            )
        }
        #expect(!freeAssetCatalog.contains("ProviderLogo"))
        #expect(!retainedAccent.isEmpty)
        #expect(!retainedMenuBarIcon.isEmpty)

        for providerAssetName in [
            "ProviderLogoAI21",
            "ProviderLogoApple",
            "ProviderLogoClaude",
            "ProviderLogoClaudeCode",
            "ProviderLogoDeepSeek",
            "ProviderLogoFalcon",
            "ProviderLogoGemini",
            "ProviderLogoGemma",
            "ProviderLogoHuggingFace",
            "ProviderLogoKimi",
            "ProviderLogoLiquid",
            "ProviderLogoLlama",
            "ProviderLogoMiniMax",
            "ProviderLogoMistral",
            "ProviderLogoOpenAI",
            "ProviderLogoQwen",
            "ProviderLogoZai",
        ] {
            #expect(!freeV1RetiredPathExists(
                "Epistemos/Assets.xcassets/\(providerAssetName).imageset",
                sourceFilePath: #filePath
            ))
            #expect(!project.contains(providerAssetName))
            #expect(NSImage(named: NSImage.Name(providerAssetName)) == nil)
        }

        #expect(settings.contains("case .cloudModels: GeneralDetailView()"))
        #expect(settings.contains("#if !EPISTEMOS_FREE_V1\nprivate struct CloudModelsSettingsView: View"))
        #expect(settings.contains("#endif\n\nprivate struct GeneralDetailView: View"))
        #expect(inference.contains("#if !EPISTEMOS_FREE_V1\n    func providerBrand(for provider: CloudModelProvider) -> ProviderBrand {"))

        #expect(projectYML.contains("      - package: KokoroPipeline"))
        #expect(projectYML.contains("      - package: MarkEditCore"))
        #expect(!appTarget.contains("VoicePro/**"))
        #expect(!appTarget.contains("Views/Shared/ModelVoicePickerSection.swift"))
        #expect(!appTarget.contains("Views/Notes/MarkEditCoreEditorView.swift"))
    }

    @Test("free V1 excludes QuickChat Goose and legacy agent workspace sources")
    func freeV1ExcludesQuickChatGooseAndLegacyAgentWorkspaceSources() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let appTarget = try #require(sourceSection(
            in: projectYML,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  EpistemosWidgets:"
        ))
        let repositoryFixtureStaging = try #require(sourceSection(
            in: projectYML,
            startingAt: "          for source_guard in ${source_guards}; do",
            endingBefore: "    settings:"
        ))
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let substrateHealth = try loadRepoTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        let epdocChrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let epdocDock = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let markdownSurface = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let kokoroRuntime = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        let speechSynthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let markEditEditor = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let quickCapture = try loadRepoTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        let textCapture = try loadRepoTextFile("Epistemos/Engine/TextCapturePipeline.swift")
        let deterministicSearch = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")
        let homeState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let featureButtons = try loadRepoTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let pixelSurface = try loadRepoTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let retiredJuneSurfaceProbe = "June" + "Agent" + "SurfaceView("
        #expect(!homeState.contains("case " + "agent"))
        #expect(!landing.contains("case " + ".agent"))
        #expect(!landing.contains("agent" + "PageTitle"))
        #expect(!landing.contains("agent" + "Surface"))
        #expect(!landing.contains("EPISTEMOS_OPEN_" + "AGENT_ON_LAUNCH"))
        #expect(!landing.contains(retiredJuneSurfaceProbe))
        #expect(!featureButtons.contains("case " + "agent"))
        #expect(!pixelSurface.contains("case " + "agent"))
        #expect(!appTarget.contains("          - JuneAgent/**"))
        #expect(repositoryFixtureStaging.contains("Epistemos/JuneAgent/*)"))
        #expect(repositoryFixtureStaging.contains(
            "skipping intentionally absent Free V1 source root Epistemos/JuneAgent/"
        ))
        #expect(!ProductCapabilityPolicy.isAvailable(.paidAgent))
        #expect(featureButtons.contains("case .browser: .agent"))
        #expect(landing.contains("register(.landingHome)"))
        #expect(landing.contains("unregister(.landingHome)"))
        for retiredQuickChatSource in [
            "QuickChat/AppleFMQuickChatBackend.swift",
            "QuickChat/GGUFModelCatalog.swift",
            "QuickChat/LocalGGUFQuickChatBackend.swift",
            "QuickChat/QuickChatController.swift",
            "QuickChat/QuickChatModelDownloadManager.swift",
            "QuickChat/QuickChatModels.swift",
            "QuickChat/QuickChatStageView.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(retiredQuickChatSource)",
                    sourceFilePath: #filePath
                ),
                "Free V1 must physically remove \(retiredQuickChatSource)."
            )
        }
        #expect(!freeV1RetiredPathExists("Epistemos/QuickChat", sourceFilePath: #filePath))
        #expect(!appTarget.contains("QuickChat/**"))
        #expect(!project.contains("QuickChat/"))

        for retiredSource in [
            "AgentWorkspace/AgentCloudConsent.swift",
            "AgentWorkspace/AgentSubscriptionService.swift",
            "AgentWorkspace/EpistemosProxyClient.swift",
            "AgentWorkspace/AgentWorkspaceSession.swift",
            "Goose/GooseMASAgentCoreCatalog.swift",
            "Goose/GooseMASAgentCoreProviderSlug.swift",
            "Goose/GooseMASAgentCoreRunner.swift",
        ] {
            #expect(
                !freeV1RetiredPathExists(
                    "Epistemos/\(retiredSource)",
                    sourceFilePath: #filePath
                ),
                "Free V1 must physically remove \(retiredSource)."
            )
        }

        func freeV1GateKind(_ condition: String) -> Int {
            let compact = condition.replacingOccurrences(of: " ", with: "")
            if compact == "!EPISTEMOS_FREE_V1" || compact.hasPrefix("!EPISTEMOS_FREE_V1&&") {
                return 1
            }
            if compact == "EPISTEMOS_FREE_V1" || compact.hasPrefix("EPISTEMOS_FREE_V1&&") {
                return -1
            }
            return 0
        }

        func allOccurrencesArePaidGuarded(_ symbol: String, in source: String) -> Bool {
            var conditionalBranches: [Int] = []
            var foundSymbol = false

            for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#if ") {
                    conditionalBranches.append(freeV1GateKind(String(line.dropFirst(4))))
                    continue
                }
                if line.hasPrefix("#elseif ") {
                    guard !conditionalBranches.isEmpty else { return false }
                    conditionalBranches[conditionalBranches.count - 1] = freeV1GateKind(
                        String(line.dropFirst(8))
                    )
                    continue
                }
                if line == "#else" {
                    guard let current = conditionalBranches.popLast() else { return false }
                    conditionalBranches.append(current == 1 ? -1 : (current == -1 ? 1 : 0))
                    continue
                }
                if line == "#endif" {
                    guard conditionalBranches.popLast() != nil else { return false }
                    continue
                }
                if rawLine.contains(symbol) {
                    foundSymbol = true
                    guard conditionalBranches.contains(1) else { return false }
                }
            }

            return foundSymbol && conditionalBranches.isEmpty
        }

        for (source, symbols) in [
            (substrateHealth, ["JuneAgentHealthRow("]),
            (epdocChrome, ["JuneEpdocAssistContext", "JuneEpdocAssistBridge"]),
            (epdocDock, ["JuneEpdocAssistContext", "JuneEpdocAssistSubmissionResult"]),
            (markdownSurface, ["JuneEpdocAssistContext(", "JuneEpdocAssistSelection("]),
        ] {
            for symbol in symbols {
                #expect(allOccurrencesArePaidGuarded(symbol, in: source))
            }
        }

        #expect(substrateHealth.contains("#if !EPISTEMOS_FREE_V1\n                    if ProductCapabilityPolicy.isAvailable(.paidAgent)"))
        #expect(epdocChrome.contains("#if EPISTEMOS_FREE_V1\n    public init("))
        #expect(markdownSurface.contains("#if EPISTEMOS_FREE_V1\n        EpdocEditorChromeView("))

        #expect(projectYML.contains("      - package: KokoroPipeline"))
        #expect(projectYML.contains("      - package: MarkEditCore"))
        for retainedPattern in [
            "VoicePro/**",
            "Engine/EpistemosSpeechSynthesizer.swift",
            "Views/Notes/MarkEditCoreEditorView.swift",
            "Views/Capture/**",
            "Engine/TextCapturePipeline.swift",
            "Sync/SearchIndexService.swift",
        ] {
            #expect(!appTarget.contains("          - \(retainedPattern)"))
        }
        #expect(kokoroRuntime.contains("nonisolated enum KokoroCoreMLSynthesizer"))
        #expect(speechSynthesizer.contains("final class EpistemosSpeechSynthesizer"))
        #expect(markEditEditor.contains("import MarkEditCore"))
        #expect(quickCapture.contains("struct QuickCaptureView: View"))
        #expect(textCapture.contains("final class TextCapturePipeline"))
        #expect(textCapture.contains("deterministicFirstSentence"))
        #expect(deterministicSearch.contains("actor SearchIndexService"))
        #expect(deterministicSearch.contains("nonisolated func search(query: String, limit: Int = 50)"))
    }

    @Test("free V1 target excludes paid inference and agent linkage")
    func freeV1TargetExcludesPaidInferenceAndAgentLinkage() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectYML = try loadRepoTextFile("project.yml")
        let releaseGate = try loadRepoTextFile("scripts/keelstone-release-gate.sh")
        let ciWorkflow = try loadRepoTextFile(".github/workflows/ci.yml")
        let xcodebuildWrapper = try loadRepoTextFile("scripts/xcodebuild_epistemos.sh")
        let gitIgnore = try loadRepoTextFile(".gitignore")
        let freeDebug = try #require(sourceSection(
            in: project,
            startingAt: "0E2E8A072CB582D720A3E905 /* Debug */ = {",
            endingBefore: "1F14548A8F23EC8EDB5E078D /* Debug */ = {"
        ))
        let freeRelease = try #require(sourceSection(
            in: project,
            startingAt: "60C8CDCD31A36814C6A7DF36 /* Release */ = {",
            endingBefore: "669764D62A1F85DBFF0FBACD /* Release */ = {"
        ))
        let freeTestDebug = try #require(sourceSection(
            in: project,
            startingAt: "270971C8366877BE7C679F8F /* Debug */ = {",
            endingBefore: "302222A7A65CA4537312765F /* Release */ = {"
        ))
        let freeTestRelease = try #require(sourceSection(
            in: project,
            startingAt: "302222A7A65CA4537312765F /* Release */ = {",
            endingBefore: "3085888BBD65E9917811BC78 /* Release */ = {"
        ))
        let freeBindingExceptions = try #require(sourceSection(
            in: project,
            startingAt: "28ED660DDD0AE43C1E151F78 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {",
            endingBefore: "37F519C8472FADBCC70357FE /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {"
        ))

        for freeConfiguration in [freeDebug, freeRelease] {
            #expect(!freeConfiguration.contains("-lagent_core"))
            #expect(!freeConfiguration.contains("-lomega_mcp"))
            #expect(!freeConfiguration.contains("agent_coreFFI"))
            #expect(!freeConfiguration.contains("omega_mcpFFI"))
        }
        for freeTestConfiguration in [freeTestDebug, freeTestRelease] {
            #expect(freeTestConfiguration.contains("EPISTEMOS_FREE_V1"))
            #expect(!freeTestConfiguration.contains("agent_coreFFI"))
            #expect(!freeTestConfiguration.contains("omega_mcpFFI"))
        }
        #expect(!project.contains("E70B453353C9AB5E24A29DFA /* EpistemosLlama in Frameworks */"))
        #expect(project.contains("EPISTEMOS_PRODUCT_EDITION:-"))
        #expect(!project.contains("build-omega-mcp.sh"))
        #expect(!project.contains("build-agent-core.sh"))
        #expect(!projectYML.contains("-lomega_mcp"))
        #expect(!projectYML.contains("-lagent_core"))
        #expect(!projectYML.contains("agent_coreFFI"))
        #expect(!projectYML.contains("omega_mcpFFI"))
        #expect(!projectYML.contains("- package: EpistemosLlama\n        product: EpistemosLlama"))
        #expect(!projectYML.contains("  EpistemosLlama:\n    path: LocalPackages/EpistemosLlama"))
        #expect(!projectYML.contains("LocalPackages/EpistemosLlama"))
        #expect(!project.contains("XCLocalSwiftPackageReference \"LocalPackages/EpistemosLlama\""))
        #expect(!project.contains("/* EpistemosLlama */"))
        #expect(!freeV1RetiredPathExists("LocalPackages/EpistemosLlama", sourceFilePath: #filePath))
        #expect(!freeV1RetiredPathExists("scripts/fetch-llama-xcframework.sh", sourceFilePath: #filePath))
        #expect(!ciWorkflow.contains("LocalPackages/EpistemosLlama"))
        #expect(!ciWorkflow.contains("fetch-llama-xcframework.sh"))
        #expect(!xcodebuildWrapper.contains("ensure_pinned_llama_xcframework"))
        #expect(!xcodebuildWrapper.contains("fetch-llama-xcframework.sh"))
        #expect(!gitIgnore.contains("LocalPackages/EpistemosLlama"))
        #expect(projectYML.contains("- path: build-rust/swift-bindings\n        type: syncedFolder\n        includes:\n          - epistemos_core.swift"))
        #expect(!projectYML.contains("          - \"*.swift\""))
        #expect(!projectYML.contains("build-omega-mcp.sh"))
        #expect(!projectYML.contains("build-agent-core.sh"))
        #expect(projectYML.contains("for forbidden_framework in llama.framework libagent_core.dylib libomega_mcp.dylib; do"))
        #expect(freeBindingExceptions.contains("agent_core.swift"))
        #expect(freeBindingExceptions.contains("omega_mcp.swift"))
        let freeAppExceptions = try #require(sourceSection(
            in: project,
            startingAt: "37F519C8472FADBCC70357FE /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {",
            endingBefore: "45C30E899114488A41C98903 /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {"
        ))
        for excludedRuntimeSource in [
            "State/ProductRuntimeState.swift",
        ] {
            #expect(projectYML.contains("          - \(excludedRuntimeSource)"))
            #expect(freeAppExceptions.contains("\t\t\t\t\(excludedRuntimeSource),"))
        }
        for retiredRuntimeSource in [
            "Engine/CapabilityManifestBuilder.swift",
            "Engine/CloudProviderAuthService.swift",
            "Engine/CommandInputParser.swift",
            "Engine/EventDrain.swift",
            "Engine/OpenAICompatibleChatSupport.swift",
            "Engine/RustEventRingClient.swift",
            "Engine/URLSessionTransportSupport.swift",
            "Engine/LLMService.swift",
            "Engine/TriageService.swift",
            "Engine/PipelineService.swift",
            "Omega/Inference/ToolCallParser.swift",
            "Omega/Knowledge/ODIATraceGenerator.swift",
            "Omega/Knowledge/TraceDataMixer.swift",
            "State/CommandCenterDiagnostics.swift",
            "Vault/ContradictionDetectionService.swift",
            "Vault/LiveNoteExecutor.swift",
            "Vault/SessionBrowser.swift",
            "Vault/SkillEvolutionService.swift",
            "Views/Chat/ComposerReferenceBrowser.swift",
            "Views/Chat/NotesMentionDropdown.swift",
            "Views/Notes/VaultOrganizerView.swift",
            "Views/Sessions/FSRSReviewSidebar.swift",
            "Views/Sessions/SessionListView.swift",
        ] {
            #expect(!freeV1RetiredPathExists("Epistemos/\(retiredRuntimeSource)", sourceFilePath: #filePath))
            #expect(!projectYML.contains("          - \(retiredRuntimeSource)"))
            #expect(!freeAppExceptions.contains("\t\t\t\t\(retiredRuntimeSource),"))
        }
        #expect(releaseGate.contains("require_appstore_free_v1_without_paid_inference_or_agent_runtimes"))
    }

    @Test("free V1 retained agent bridges fail closed before paid bindings")
    func freeV1RetainedAgentBridgesFailClosed() throws {
        let vaultRecall = try loadRepoTextFile("Epistemos/VaultRecall/VaultRecallWiring.swift")
        let mcpBridge = try loadRepoTextFile("Epistemos/Omega/MCPBridge.swift")
        let sdPage = try loadRepoTextFile("Epistemos/Models/SDPage.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let chatTypes = try loadRepoTextFile("Epistemos/Models/ChatTypes.swift")
        let eidosBridge = try loadRepoTextFile("Epistemos/Eidos/EidosBridge.swift")
        let eidosWiring = try loadRepoTextFile("Epistemos/Eidos/EidosWiring.swift")
        let engineDiagnostics = try loadRepoTextFile("Epistemos/Engine/EngineLogDiagnostics.swift")
        let latticeWBO = try loadRepoTextFile("Epistemos/LatticeWBO/LatticeWBOWiring.swift")
        let fUlp = try loadRepoTextFile("Epistemos/FUlp/FUlpWiring.swift")
        let acsAdmission = try loadRepoTextFile("Epistemos/ACSAdmission/ACSAdmissionWiring.swift")
        let epistemosApp = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let shadowFFI = try loadRepoTextFile("Epistemos/Engine/RustShadowFFIClient.swift")
        let opLogFFI = try loadRepoTextFile("Epistemos/Engine/RustOpLogFFIClient.swift")

        #expect(vaultRecall.contains("guard ProductCapabilityPolicy.isAvailable(.sourceDiscovery) else { return nil }"))
        #expect(vaultRecall.contains("#if canImport(agent_coreFFI)\n        do {\n            let raw = try vaultRecallTraceJson"))
        #expect(mcpBridge.contains("private static func builtinToolsPayload() -> String {"))
        #expect(mcpBridge.contains("#if canImport(omega_mcpFFI)\n        guard ProductCapabilityPolicy.isAvailable(.agentAutomation) else { return \"[]\" }\n        return builtinToolsJson()"))
        #expect(mcpBridge.contains("#if canImport(omega_mcpFFI)\n    private(set) var dispatcher: McpDispatcher?"))
        #expect(mcpBridge.contains("guard ProductCapabilityPolicy.isAvailable(.agentAutomation) else {\n            return Self.jsonRpcError("))
        #expect(mcpBridge.contains("message: \"MCP is unavailable in this build.\""))
        #expect(sdPage.contains("#if canImport(agent_coreFFI)\n        if resourceServiceIsReady()"))
        #expect(sdPage.contains("let resourceId = try await resourceResolve(reference: reference)"))
        #expect(sdPage.contains("let content = try await resourceRead(id: resourceId)"))
        #expect(appBootstrap.contains("private func initializeRustResourceServiceIfReady() {\n        #if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)"))
        #expect(appBootstrap.contains("try resourceServiceInit(vaultRoot: vaultPath, vaultId: vaultID)"))
        #expect(appBootstrap.contains("#if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)\n        EidosVaultBootstrapper.openProductionIndexIfReady("))
        #expect(chatTypes.contains("#if canImport(agent_coreFFI)\n    func toAttachedResource() -> AttachedResource?"))
        #expect(chatTypes.contains("return attachedResourceFromUi("))
        #expect(chatTypes.contains("return attachedResourceFromPaste("))
        #expect(eidosBridge.contains("#if canImport(agent_coreFFI)\nnonisolated extension EidosBridge"))
        #expect(eidosBridge.contains("#else\nnonisolated extension EidosBridge"))
        #expect(eidosBridge.contains("public static func openVaultIndex(signature: String) -> EidosIndexManifestId? { nil }"))
        #expect(eidosWiring.contains("#if canImport(agent_coreFFI)"))
        #expect(eidosWiring.contains("let raw = try eidosSearchLexicalJson(query: query, topK: topK)"))
        #expect(eidosWiring.contains("#else\n        return nil\n        #endif"))
        #expect(engineDiagnostics.contains("#if canImport(agent_coreFFI)\n    private static func agentCoreMessage(from error: Error) -> String?"))
        #expect(latticeWBO.contains("#if canImport(agent_coreFFI)\n        do {\n            let raw = try oplogLatticeWboStatsJson()"))
        #expect(latticeWBO.contains("#else\n        return nil\n        #endif"))
        #expect(fUlp.contains("#if canImport(agent_coreFFI)\n        let started = Date()\n        do {\n            let raw = try fulpOracleAcceptanceWitnessJson()"))
        #expect(fUlp.contains("#else\n        let error = NSError("))
        #expect(acsAdmission.contains("#if canImport(agent_coreFFI)\n        do {\n            let raw = try acsAdmissionStrictPolicySummaryJson()"))
        #expect(acsAdmission.contains("#else\n        let error = NSError("))
        #expect(epistemosApp.contains("#if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)\n        let relief = respondToMemoryPressure(level: level == .critical ? 2 : 1)"))
        #expect(epistemosApp.contains("#else\n        metadata[\"rustSegmentsEvicted\"] = \"0\""))
        #expect(appBootstrap.contains("#if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)\n        let relief = respondToMemoryPressure(level: 2)"))
        #expect(appBootstrap.contains("rustSegmentsEvicted: rustSegmentsEvicted"))
        #expect(appBootstrap.contains("private func initializeRustPermissionStoreIfReady() {\n        #if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)"))
        #expect(shadowFFI.contains("#if canImport(agent_coreFFI)\n@_silgen_name(\"etl_queue_stats_json\")"))
        #expect(shadowFFI.contains("#else\nnonisolated private func etl_queue_stats_json("))
        #expect(opLogFFI.contains("#if canImport(agent_coreFFI)\n@_silgen_name(\"oplog_open_at\")"))
        #expect(opLogFFI.contains("#else\nnonisolated private func oplog_open_at("))
        #expect(appBootstrap.contains("#if !EPISTEMOS_FREE_V1 && canImport(agent_coreFFI)\n        if let eventStore = EventStore.shared {\n            self._mutationOpLogProjectionWorker"))
    }

    @Test("App Store lane owns a visible read-aloud surface path")
    func appStoreLaneOwnsVisibleReadAloudSurfacePath() throws {
        let registry = try loadRepoTextFile("Epistemos/Engine/EpistemosVisibleReadAloud.swift")
        let helper = try loadRepoTextFile("Epistemos/Engine/EpistemosAgentReadAloud.swift")
        let readAloud = try loadRepoTextFile("Epistemos/Views/Shared/ReadAloudButton.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let epdoc = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift")
        let quickCapture = try loadRepoTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        let meeting = try loadRepoTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        let preferences = try loadRepoTextFile("Epistemos/Engine/VoicePreferences.swift")
        let voiceDetail = try loadRepoTextFile("Epistemos/Views/Settings/VoiceSettingsDetailView.swift")
        let modelVoicePicker = try loadRepoTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        let kokoroSettings = try loadRepoTextFile("Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift")
        let synthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let runtimeLoader = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift")
        let runtimeBridge = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        let pipeline = try loadRepoTextFile("LocalPackages/KokoroPipeline/Sources/KokoroPipeline/KokoroPipeline.swift")
        let appCommands = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(registry.contains("enum EpistemosVisibleReadAloudSurface"))
        #expect(registry.contains("case landingHome"))
        #expect(registry.contains("case proseNoteBody"))
        #expect(registry.contains("case codeEditor"))
        #expect(registry.contains("case epdocSelection"))
        #expect(registry.contains("case quickCapture"))
        #expect(registry.contains("case meetingTranscript"))
        #expect(registry.contains("case htmlWorkspaceSource"))
        #expect(registry.contains("final class EpistemosVisibleReadAloudRegistry"))
        #expect(registry.contains("func visibleText("))
        #expect(registry.contains("enum EpistemosReadAloudDiagnostics"))
        #expect(registry.contains("AppBootstrap.shared?.uiState.showToast"))
        #expect(!registry.contains("CGWindowList"))
        #expect(!registry.contains("screencapture"))
        #expect(!registry.contains("OCR"))

        #expect(helper.contains("static func readVisibleSurface("))
        #expect(helper.contains("Read visible surface requested preferred="))
        #expect(helper.contains("EpistemosVisibleReadAloudRegistry.shared.visibleText"))
        #expect(helper.contains("maxResponsiveReadVisibleCharacters"))
        #expect(helper.contains("responsiveReadVisibleText"))
        #expect(helper.contains("Read visible surface queued surface="))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)"))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showUnavailableToast"))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showFailureToast"))
        #expect(registry.contains("activate: Bool = true"))
        #expect(registry.contains("showExcerptToast(surface:"))
        #expect(registry.contains("static func showQueuedToast(surface: EpistemosVisibleReadAloudSurface? = nil)"))
        #expect(readAloud.contains("public let surface: EpistemosVisibleReadAloudSurface?"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showNoVisibleTextToast(surface: surface)"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showUnavailableToast()"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.logTextToSpeechReadiness("))
        #expect(readAloud.contains("EpistemosAgentReadAloud.responsiveReadVisibleText("))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showInputExcerptToast()"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)"))
        #expect(readAloud.contains("private var disabled: Bool {\n        false\n    }"))

        #expect(landing.contains("register(.landingHome)"))
        #expect(landing.contains("landingVisibleReadAloudText()"))
        #expect(landing.contains("unregister(.landingHome)"))
        #expect(prose.contains("register(.proseNoteBody)"))
        #expect(prose.contains("currentEditorBody(for: page) ?? persistedBodyFor(page)"))
        #expect(prose.contains("private func noteReadAloudText(for page: SDPage) -> String"))
        #expect(prose.contains("let readAloudText = noteReadAloudText(for: page)"))
        #expect(prose.contains("markActive(.codeEditor)"))
        #expect(codeEditor.contains("register(.codeEditor, activate: false)"))
        #expect(!codeEditor.contains("EpistemosVisibleReadAloudRegistry.shared.markActive(.codeEditor)"))
        #expect(epdoc.contains("register(.epdocSelection)"))
        #expect(quickCapture.contains("register(.quickCapture)"))
        #expect(quickCapture.contains("private static let previewSignalQuietWindow: Duration = .milliseconds(120)"))
        #expect(quickCapture.contains("let nextSignals = await Task.detached(priority: .utility)"))
        #expect(meeting.contains("register(.meetingTranscript)"))
        let htmlWorkspace = try loadRepoTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(htmlWorkspace.contains("register(.htmlWorkspaceSource)"))
        #expect(htmlWorkspace.contains("HTMLWorkspaceReadAloudText.plainVisibleText"))
        #expect(htmlWorkspace.contains("unregister(.htmlWorkspaceSource)"))
        #expect(settings.contains("EpistemosAgentReadAloud.speak(preview)"))
        #expect(settings.contains("logTextToSpeechReadiness(context: \"settings-voice-preview\")"))
        #expect(settings.contains("accessibilityIdentifier(\"settings.voice.preview.\\(key)\")"))
        #expect(settings.contains("preview: \"Kokoro is ready.\""))
        #expect(settings.contains("if VoicePreferences.allowsReadAloudEffects"))
        #expect(preferences.contains("public nonisolated static var allowsReadAloudEffects"))
        #expect(preferences.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(preferences.contains("public nonisolated static func shippedReadAloudEffect"))
        #expect(preferences.contains("false\n        #else\n        true"))
        #expect(preferences.contains(".clean\n        #else\n        requested"))
        #expect(preferences.contains("when Kokoro is installed and ready"))
        #expect(!preferences.contains("once native Kokoro playback is wired"))
        #expect(!preferences.contains("remains unavailable until native Kokoro playback is wired"))
        #expect(voiceDetail.contains("VoicePreferencesSection()"))
        #expect(voiceDetail.contains("KokoroVoiceProSettingsSection()"))
        #expect(voiceDetail.contains(".formStyle(.grouped)"))
        #expect(voiceDetail.contains(".scrollContentBackground(.hidden)"))
        #expect(voiceDetail.contains("logTextToSpeechReadiness(context: \"voice-settings-detail\")"))
        #expect(modelVoicePicker.contains("English default"))
        #expect(modelVoicePicker.contains("EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()"))
        #expect(modelVoicePicker.contains("normalizeBoundVoiceIdentifier(against: englishVoices)"))
        #expect(modelVoicePicker.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(!modelVoicePicker.contains("personalVoiceAuthorization"))
        #expect(!modelVoicePicker.contains("requestPersonalVoiceAuthorization"))
        #expect(!modelVoicePicker.contains("voiceQualityHint()"))
        #expect(!modelVoicePicker.contains("AVSpeechUtteranceMinimumSpeechRate"))
        #expect(modelVoicePicker.contains("logTextToSpeechReadiness(context: \"settings-voice-model-preview\")"))
        #expect(modelVoicePicker.contains("accessibilityIdentifier(\"settings.voice.modelPreview\")"))
        #expect(modelVoicePicker.contains("previewText: String = \"Kokoro is ready.\""))
        #expect(kokoroSettings.contains("static let voiceSystemImage = \"waveform\""))
        #expect(!kokoroSettings.contains("waveform.badge.sparkles"))
        #expect(kokoroSettings.contains("logTextToSpeechReadiness(context: \"voice-settings-kokoro-section\")"))
        #expect(synthesizer.contains("static func logTextToSpeechReadiness("))
        #expect(synthesizer.contains("readinessLog.notice("))
        #expect(synthesizer.contains("Self.log.notice("))
        #expect(synthesizer.contains("Kokoro TTS queued chars="))
        #expect(synthesizer.contains("Kokoro TTS voice resolved requested="))
        #expect(synthesizer.contains("englishOnly=true"))
        #expect(synthesizer.contains("Kokoro TTS render started"))
        #expect(synthesizer.contains("Kokoro TTS render finished"))
        #expect(synthesizer.contains("Kokoro TTS playback started"))
        #expect(synthesizer.contains("Kokoro TTS playback completed"))
        #expect(!synthesizer.contains("_ = AVSpeechSynthesisVoice.speechVoices()"))
        #expect(synthesizer.contains("effectiveKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("preferredEnglishKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("installedEnglishKokoroVoices("))
        #expect(synthesizer.contains("installedEnglishIDs"))
        #expect(synthesizer.contains("VoicePreferences.shippedReadAloudEffect(requestedEffect)"))
        #expect(synthesizer.contains("Kokoro TTS using clean MAS effect requested="))
        #expect(synthesizer.contains("KokoroVoiceGateStatus.starterVoiceIdentifier"))
        #expect(synthesizer.contains("legacyGateEnabled="))
        #expect(synthesizer.contains("modelRoot="))
        #expect(synthesizer.contains("manifestValid="))
        #expect(synthesizer.contains("KokoroPipelineLinked="))
        #expect(synthesizer.contains("isTextToSpeechAvailable="))
        #expect(runtimeLoader.contains("KokoroCoreMLPipelineCache"))
        #expect(runtimeLoader.contains("pipelineCache.pipeline(for: resources)"))
        #expect(runtimeBridge.contains("responsiveDurationTokenCeiling = 32"))
        #expect(runtimeBridge.contains("responsiveDurationTokenLimit(from: resources.durationTokenSizes)"))
        #expect(!runtimeBridge.contains("maxTokenCount: resources.durationTokenSizes.max() ?? 512"))
        #expect(runtimeBridge.contains("englishPhonemeSymbols("))
        #expect(runtimeBridge.contains("englishPronunciationLexicon"))
        #expect(runtimeBridge.contains("approximateEnglishPhonemes(forWord:"))
        #expect(runtimeBridge.contains("isEnglishKokoroVoiceIdentifier(voiceIdentifier)"))
        #expect(pipeline.contains("Core ML models are loaded lazily on first use"))
        #expect(pipeline.contains("private var durationModels: [String: MLModel] = [:]"))
        #expect(pipeline.contains("private static func loadModel(at url: URL, computeUnits: MLComputeUnits) throws -> MLModel"))
        #expect(appCommands.contains("Button(\"Open Voice Settings\")"))
        #expect(appCommands.contains("showSettings(section: .voice)"))
        #expect(appCommands.contains("Button(\"Read Visible Surface\")"))
        #expect(appCommands.contains("EpistemosAgentReadAloud.readVisibleSurface()"))
        #expect(appCommands.contains(".keyboardShortcut(\"r\", modifiers: [.command, .shift])"))
        #expect(appCommands.contains("private enum KokoroLaunchProof"))
        #expect(appCommands.contains("--epistemos-run-kokoro-proof-on-launch"))
        #expect(appCommands.contains("epistemos.voice.runKokoroProofOnLaunchOnce"))
        #expect(appCommands.contains("phraseLanguage=en"))
        #expect(appCommands.contains("logTextToSpeechReadiness(context: \"launch-voice-proof\")"))
        #expect(appCommands.contains("EpistemosAgentReadAloud.speak(phrase)"))
        #expect(!appCommands.contains("AVSpeechSynthesizer("))
    }

    @Test("App Store audio resources stay dormant until explicit user actions")
    func appStoreAudioResourcesStayDormantUntilExplicitUserActions() throws {
        let synthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let analyzer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let meeting = try loadRepoTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(!synthesizer.contains("private let kokoroEngine = AVAudioEngine()"))
        #expect(!synthesizer.contains("private let kokoroPlayer = AVAudioPlayerNode()"))
        #expect(synthesizer.contains("private var kokoroPlaybackGraph:"))
        #expect(synthesizer.contains("let graph = try resolveKokoroPlaybackGraph()"))

        #expect(!analyzer.contains("private let engine = AVAudioEngine()"))
        #expect(analyzer.contains("private var engine: AVAudioEngine?"))
        #expect(analyzer.contains("let engine = AVAudioEngine()"))
        #expect(analyzer.contains("AVCaptureDevice.requestAccess(for: .audio)"))

        for renderSource in [landing, meeting, settings] {
            #expect(!renderSource.contains("AVCaptureDevice.authorizationStatus(for: .audio)"))
        }

#if DEBUG
        let speechSynthesizer = EpistemosSpeechSynthesizer.shared
        speechSynthesizer.stop()
        #expect(!speechSynthesizer.hasAllocatedKokoroPlaybackGraphForTesting)
        speechSynthesizer.pause()
        speechSynthesizer.resume()
        _ = speechSynthesizer.isSpeaking
        _ = speechSynthesizer.isPaused
        #expect(!speechSynthesizer.hasAllocatedKokoroPlaybackGraphForTesting)

        if #available(macOS 26.0, *) {
            let speechAnalyzer = EpistemosSpeechAnalyzer.shared
            #expect(!speechAnalyzer.hasAllocatedAudioEngineForTesting)
        }
#endif
    }

    @Test("App Store Kokoro defaults to English voice and phoneme input")
    func appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput() throws {
        let voices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "Spanish · Female",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "am_michael",
                displayName: "Michael",
                language: "American English · Male",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "af_heart",
                displayName: "Heart",
                language: "American English · Female",
                quality: .premium
            )
        ]
        let mislabeledNonEnglishVoices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "American English · Female",
                quality: .premium
            )
        ]
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "am_michael",
                globalDefault: nil,
                installedVoices: voices
            ) == "am_michael"
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "ef_dora",
                globalDefault: "com.apple.speech.synthesis.voice.not-kokoro",
                installedVoices: voices
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "ef_dora",
                globalDefault: nil,
                installedVoices: mislabeledNonEnglishVoices
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: nil,
                globalDefault: nil,
                installedVoices: []
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "am_michael",
                installedVoices: voices
            ) == "am_michael"
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "ef_dora",
                installedVoices: voices
            ) == nil
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "com.apple.speech.synthesis.voice.not-kokoro",
                installedVoices: voices
            ) == nil
        )
        let synthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let runtimeBridge = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        #expect(synthesizer.contains(".filter(isEnglishKokoroVoiceOption)"))
        #expect(synthesizer.contains("return voices.first(where: isEnglishKokoroVoiceOption)?.identifier"))
        #expect(synthesizer.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(runtimeBridge.contains("private nonisolated static func isEnglishKokoroVoiceIdentifier"))
        #expect(runtimeBridge.contains("isEnglishKokoroVoiceIdentifier(voiceIdentifier)"))
        #expect(!runtimeBridge.contains(#""—", "\u{2010}""#))
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(!VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .clean)
        #else
        #expect(VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .pixelArt)
        #endif

        let symbols = ["k", "ˈ", "O", "ə", "ɹ", "ɪ", "z", " ", "ɛ", "d", "i", "."]
        let vocabulary = Dictionary(uniqueKeysWithValues: symbols.enumerated().map { ($0.element, Int32($0.offset + 1)) })
        let phonemes = KokoroCoreMLSynthesizer.englishPhonemeSymbols(
            for: "Kokoro is ready.",
            vocabulary: vocabulary
        )

        #expect(phonemes.contains("ə"))
        #expect(phonemes.contains("ɹ"))
        #expect(phonemes.contains("ɛ"))
        #expect(!phonemes.starts(with: ["k", "o", "k", "o", "r", "o"]))
    }

    @Test("App Store lane first-run and upgrade bootstrap matrix")
    func appStoreLaneFirstRunAndUpgradeBootstrapMatrix() throws {
        let freshVault = makeUncreatedTempDirectory()
        defer { try? FileManager.default.removeItem(at: freshVault) }

        #expect(FirstRunBootstrap.isFresh(at: freshVault))
        let freshReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(freshReceipt.wasFresh)
        for relative in FirstRunBootstrap.scaffoldFolders {
            let folder = freshVault.appendingPathComponent(relative, isDirectory: true)
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
        let secondReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(!secondReceipt.wasFresh)
        #expect(secondReceipt.metadata.createdAt == freshReceipt.metadata.createdAt)

        let partialVault = makeUncreatedTempDirectory(prefix: "keelstone-appstore-partial")
        defer { try? FileManager.default.removeItem(at: partialVault) }
        try FileManager.default.createDirectory(
            at: partialVault.appendingPathComponent("notes", isDirectory: true),
            withIntermediateDirectories: true
        )
        #expect(FirstRunBootstrap.isFresh(at: partialVault))
        let partialReceipt = try FirstRunBootstrap.bootstrap(at: partialVault)
        #expect(partialReceipt.wasFresh)
        #expect(partialReceipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count - 1)
    }

    @Test("App Store lane rejects stale and non-security-scoped startup bookmarks")
    func appStoreLaneRejectsInvalidStartupBookmarks() {
        let stale = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: true,
            usedSecurityScope: true,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!stale.isReadyForAutomaticRestore)
        #expect(stale.failureReason == "Saved vault bookmark is stale and must be re-selected.")

        let plain = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: false,
            usedSecurityScope: false,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!plain.isReadyForAutomaticRestore)
        #expect(plain.failureReason == "Saved vault bookmark is not security-scoped and must be re-selected.")
    }

    @Test("App Store lane checks startup bookmark readability while security scope is active")
    func appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive() {
        let vaultURL = URL(fileURLWithPath: "/tmp/appstore-scoped-vault", isDirectory: true)
        var scopeActive = false
        var checkedExistsWhileScoped = false
        var checkedReadableWhileScoped = false
        var stoppedAfterReadabilityCheck = false

        let validation = VaultSyncService.scopedStartupBookmarkValidationForTesting(
            resolvedURL: vaultURL,
            isStale: false,
            usedSecurityScope: true,
            accessSecurityScope: { _ in
                scopeActive = true
                return true
            },
            stopSecurityScope: { _ in
                #expect(checkedExistsWhileScoped)
                #expect(checkedReadableWhileScoped)
                stoppedAfterReadabilityCheck = true
                scopeActive = false
            },
            fileExists: { path in
                #expect(path == vaultURL.path)
                #expect(scopeActive)
                checkedExistsWhileScoped = true
                return true
            },
            isReadableFile: { path in
                #expect(path == vaultURL.path)
                #expect(scopeActive)
                checkedReadableWhileScoped = true
                return true
            },
            requiresSecurityScopedVaultAccess: true
        )

        #expect(validation.bookmarkExists)
        #expect(validation.isReadyForAutomaticRestore)
        #expect(validation.failureReason == nil)
        #expect(stoppedAfterReadabilityCheck)
        #expect(scopeActive == false)
    }

    @Test("App Store lane defers vault-source warnings before ready bookmark restore")
    func appStoreLaneDefersVaultSourceWarningsBeforeReadyBookmarkRestore() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: true,
                failureReason: nil
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.unrecoverablePageIds.isEmpty)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane retries transient MAS bookmark preflight instead of warning")
    func appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark points to a missing or unreadable directory."
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.vaultBookmarkExists)
        #expect(!report.vaultBookmarkReadyForAutomaticRestore)
        #expect(!report.vaultBookmarkBlocksAutomaticRestore)
        #expect(report.unrecoverablePageIds.isEmpty)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane lets saved vault restore repair managed body cache gaps")
    func appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: ["managed-body-ok", "managed-body-missing"],
            readBodyData: { pageId in
                pageId == "managed-body-ok" ? Data("ok".utf8) : nil
            },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark points to a missing or unreadable directory."
            )
        )

        #expect(report.corruptedPageIds == ["managed-body-missing"])
        #expect(report.vaultBookmarkExists)
        #expect(!report.vaultBookmarkBlocksAutomaticRestore)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane startup restore failure preserves local vault state")
    func appStoreLaneStartupRestoreFailurePreservesLocalVaultState() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let restoreFailureHandler = try #require(sourceSection(
            in: source,
            startingAt: "private func handleRestoreFailure(",
            endingBefore: "private nonisolated static func suspiciousVaultRestoreReconfirmationReason"
        ))

        #expect(!restoreFailureHandler.contains("clearVaultData()"))
        #expect(restoreFailureHandler.contains("preserving local vault state"))
    }

    @Test("App Store bookmark timeout does not wait for blocked synchronous resolution")
    func appStoreBookmarkResolutionTimeoutIsNonStructured() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let timeoutResolver = try #require(sourceSection(
            in: source,
            startingAt: "private nonisolated static func resolveVaultBookmarkWithTimeout(",
            endingBefore: "private func clearDerivedLocalStateForRecovery()"
        ))

        #expect(source.contains("private nonisolated final class VaultBookmarkResolutionRace"))
        #expect(source.contains("private var continuation: CheckedContinuation<ResolvedVaultBookmark, Error>?"))
        #expect(timeoutResolver.contains("withCheckedThrowingContinuation"))
        #expect(timeoutResolver.contains("Task.detached"))
        #expect(timeoutResolver.contains("race.resume(.failure(VaultBookmarkResolutionError.timedOut))"))
        #expect(!timeoutResolver.contains("withThrowingTaskGroup"))
        #expect(!timeoutResolver.contains("group.cancelAll()"))
        #expect(source.contains("func startupBookmarkValidationWithTimeout() async -> VaultBookmarkStartupValidation"))
        #expect(source.contains("private var pendingStartupResolvedBookmark:"))
        #expect(source.contains("cached.bookmarkData == data"))
        #expect(source.contains("resolvedBookmark = cached.resolvedBookmark"))
        #expect(source.contains("pendingStartupResolvedBookmark = nil"))
        #expect(bootstrap.components(separatedBy: "await vaultSync.startupBookmarkValidationWithTimeout()").count == 2)
        #expect(bootstrap.contains("let vaultBookmarkValidation = report.vaultBookmarkValidation"))
    }

    @Test("App Store lane preserves saved bookmark on transient restore failures")
    func appStoreLanePreservesBookmarkOnTransientRestoreFailures() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let lostScopeBranch = try #require(sourceSection(
            in: source,
            startingAt: "if !gained {",
            endingBefore: "let isReadableVault = await readableVaultURLAfterSecurityScopeSettle(url)"
        ))
        let missingDirectoryBranch = try #require(sourceSection(
            in: source,
            startingAt: "if !isReadableVault {",
            endingBefore: "if isStale {"
        ))

        #expect(lostScopeBranch.contains("Security scope not granted for vault bookmark"))
        #expect(missingDirectoryBranch.contains("Vault directory not found or readable at"))
        #expect(source.contains("readableVaultURLAfterSecurityScopeSettle"))
        #expect(source.contains("isReadableVaultDirectory"))
        #expect(!lostScopeBranch.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
        #expect(!missingDirectoryBranch.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
    }

    @Test("App Store automatic restore failures never delete persisted vault selection")
    func appStoreAutomaticRestoreFailuresNeverDeletePersistedVaultSelection() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let automaticRestore = try #require(sourceSection(
            in: source,
            startingAt: "func restoreVaultFromBookmark() async",
            endingBefore: "        // Pass scopeAlreadyAcquired=true"
        ))

        #expect(!automaticRestore.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
        #expect(automaticRestore.contains("preserving the saved vault selection for retry"))
        #expect(automaticRestore.contains("reason: reason,\n                bookmarkExists: true"))
    }

    @Test("App Store lane does not stack vault-source-loss warnings while a bookmark exists")
    func appStoreLaneDefersVaultSourceLossWarningsForBlockedBookmarksToo() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is stale and must be re-selected."
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.vaultBookmarkBlocksAutomaticRestore)
        #expect(report.unrecoverablePageIds.isEmpty)
        let toast = AppBootstrap.startupIntegrityToastForTesting(report: report)
        #expect(toast?.message.contains("Saved vault bookmark is stale and must be re-selected.") == true)
        #expect(toast?.message.contains("no body file or vault source") == false)
    }

    @Test("App Store lane keeps graph inspector preview read-only")
    func appStoreLaneKeepsHologramInspectorPreviewReadOnly() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let previewBody = try #require(sourceSection(
            in: source,
            startingAt: "private func noteEditorBody(pageId: String)",
            endingBefore: "private func loadEditorPreview(pageId: String)"
        ))

        #expect(previewBody.contains("CodeInspectorPreview(content: editorText"))
        #expect(previewBody.contains("formattedMarkdownView(editorText)"))
        #expect(previewBody.contains("loadEditorPreview(pageId: pageId)"))
        #expect(previewBody.contains("loadEditorPreview(pageId: newId)"))
        #expect(source.contains("private enum HologramInspectorPreviewPolicy"))
        #expect(source.contains("static let maxBodyCharacters = 24_000"))
        #expect(source.contains("Task(priority: HologramInspectorPreviewPolicy.loadPriority)"))
        #expect(source.contains("guard graphState.currentRoute.isCanvas else"))
        #expect(source.contains("cancelEditorPreview()"))
        #expect(source.contains("HologramInspectorPreviewPolicy.boundedBody("))
        #expect(!previewBody.contains(".onChange(of: editorText)"))
        #expect(!previewBody.contains("flushEditorIfNeeded(pageId:"))
        #expect(!previewBody.contains("debouncedEditorSave(pageId:"))
        #expect(!source.contains("private func debouncedEditorSave"))
        #expect(!source.contains("private func markPageDirty"))
        #expect(!source.contains("NoteFileStorage.stageBodyForImmediateRead(pageId: pageId"))
        #expect(!source.contains("savePageBodyFileFirst(pageId: pageId"))
        #expect(!source.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(source.contains("private func loadEditorPreviewSnapshot(pageId: String) async -> EditorPreviewSnapshot"))
        #expect(source.contains("Task.detached(priority: HologramInspectorPreviewPolicy.loadPriority)"))
        #expect(!source.contains("Task.detached(priority: .userInitiated)"))
        #expect(!source.contains("NoteWindowManager.shared.currentBody(for: pageId)"))
    }

    @Test("App Store file-first title renames converge without duplicate vault files")
    func appStoreFileFirstTitleRenamesConvergeWithoutDuplicateVaultFiles() async throws {
        let vaultSyncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let liveRenamePath = try #require(
            sourceSection(
                in: vaultSyncSource,
                startingAt: "func renamePageFile(pageId: String, newTitle: String) -> Task<String?, Never>?",
                endingBefore: "    func renameDirectory(from oldRelativePath: String, to newRelativePath: String) -> Bool"
            )
        )
        #expect(liveRenamePath.contains("VaultIndexActor.renamePageFileOnDisk("))
        #expect(!liveRenamePath.contains("actor?.renamePageFile("))

        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-title-rename")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        service.setVaultURLForTesting(vaultURL)
        let pageId = try #require(
            await service.createPage(title: "Untitled", body: "")
        )
        let page = try #require(
            try context.fetch(FetchDescriptor<SDPage>())
                .first(where: { $0.id == pageId })
        )

        for revision in 1...3 {
            // Source-mode snapshots reapply parsed frontmatter metadata before
            // the file-first service gives the first H1 canonical title priority.
            // Repeating that sequence must converge on one file, not re-export
            // a stale pre-rename path and dedupe a new copy per keystroke.
            page.title = "Frontmatter Title"
            try context.save()
            #expect(
                await service.savePageBodyFileFirst(
                    pageId: pageId,
                    body: "# Canonical H1\n\nRevision \(revision)"
                )
            )
            let canonicalURL = vaultURL.appendingPathComponent("Canonical H1.md")
            #expect(page.filePath == canonicalURL.path)
            #expect(FileManager.default.fileExists(atPath: canonicalURL.path))
            #expect(!context.hasChanges)
            try await Task.sleep(for: .milliseconds(150))
        }

        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "md" }
        #expect(markdownFiles.map(\.lastPathComponent) == ["Canonical H1.md"])
        #expect(
            try String(contentsOf: markdownFiles[0], encoding: .utf8)
                .contains("Revision 3")
        )

        let refreshedPage = try #require(
            try context.fetch(FetchDescriptor<SDPage>())
                .first(where: { $0.id == pageId })
        )
        let refreshedPath = try #require(refreshedPage.filePath)
        let refreshedURL = URL(fileURLWithPath: refreshedPath)
            .resolvingSymlinksInPath()
        let enumeratedURL = markdownFiles[0].resolvingSymlinksInPath()
        #expect(refreshedURL == enumeratedURL)
    }

    @Test("App Store lane refuses plain bookmark fallback when persisting vault selection")
    func appStoreLaneRefusesPlainBookmarkFallback() throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-bookmark")
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setBookmarkDataWriterForTesting { _, options in
            if options.contains(.withSecurityScope) {
                throw CocoaError(.fileReadUnknown)
            }
            return Data("plain-bookmark".utf8)
        }

        let didPersist = service.persistVaultSelection(vaultURL)

        #expect(!didPersist)
        #expect(defaults.data(forKey: vaultBookmarkKey) == nil)
        #expect(defaults.string(forKey: lastVaultPathKey) == nil)
        #expect(!defaults.bool(forKey: "epistemos.hasEverConnectedAVault"))
    }

    @Test("App Store lane freezes writes when the mounted vault root disappears")
    func appStoreLaneRootUnavailabilityFreezesWrites() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-unavailable")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        defaults.set(Data("bookmark".utf8), forKey: vaultBookmarkKey)
        let page = SDPage(title: "Unavailable Root")
        context.insert(page)
        try context.save()

        service.setVaultURLForTesting(vaultURL)
        service.setInitialImportCompletedForTesting(true)
        try FileManager.default.removeItem(at: vaultURL)

        service.handleVaultVolumeUnavailableForTesting(
            vaultURL: vaultURL,
            reason: "appstore lane root unavailable"
        )

        #expect(service.vaultURL == nil)
        #expect(!service.isWatching)
        #expect(service.recoveryIssue?.reason == "appstore lane root unavailable")
        #expect(defaults.data(forKey: vaultBookmarkKey) == Data("bookmark".utf8))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).count == 1)
        #expect(await service.savePageBodyFileFirst(pageId: page.id, body: "edited") == false)
    }

    @Test("App Store Source owns a live MarkEdit wrap toggle without an adjustable width")
    func appStoreSourceOwnsLiveMarkEditWrapping() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let state = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
        let coordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let toolbar = try #require(sourceSection(
            in: workspace,
            startingAt: "private var noteToolbarPrimaryActions: some View",
            endingBefore: "    private var compactProseFormattingMenu"
        ))
        let reload = try #require(sourceSection(
            in: state,
            startingAt: "func requiresReload(comparedTo other: MarkEditCoreEditorState) -> Bool",
            endingBefore: "    private var clampedTabWidth"
        ))

        #expect(workspace.contains("@AppStorage(\"epistemos.sourceEditor.lineWrapping\""))
        #expect(workspace.contains("private var sourceLineWrapping = true"))
        #expect(toolbar.contains("Wrap Lines"))
        #expect(toolbar.contains("sourceLineWrapping"))
        #expect(toolbar.contains("label: \"Prose width\""))
        #expect(!toolbar.contains("Source width"))
        #expect(workspace.contains("sourceLineWrapping: sourceLineWrapping"))
        #expect(codeEditor.contains("let sourceLineWrapping: Bool"))
        #expect(codeEditor.contains("wrapLines: sourceLineWrapping"))
        #expect(codeEditor.contains("contentWidthMode: .wide"))
        #expect(codeEditor.contains("@AppStorage(\"codeEditor.wrapLines\""))
        #expect(state.contains("func replacingLineWrapping(_ nextLineWrapping: Bool)"))
        #expect(!reload.contains("wrapLines != other.wrapLines"))
        #expect(coordinator.contains("setLineWrapping({ enabled:"))
        #expect(coordinator.contains("window.config.lineWrapping === enabled"))
        #expect(coordinator.contains("lineWrappingApplicationGeneration"))
    }

    @Test("App Store Landing restores native shortcut hints and exposes canonical Markdown and JSON document creation")
    func appStoreLandingRestoresNativeFormatCommands() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let commands = try loadRepoTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(landing.contains("title: \"Markdown (.md)\""))
        #expect(landing.contains("shortcut: \"\\u{2318}N\""))
        #expect(landing.contains("title: \"JSON Document (.epdoc)\""))
        #expect(landing.contains("shortcut: \"\\u{2325}\\u{2318}N\""))
        #expect(landing.contains("action: createAndOpenEpdocDocument"))
        #expect(landing.contains("createUntitledEpdocDocument(in: vaultSync.vaultURL)"))
        #expect(landing.contains(".accessibilityLabel(\"New JSON Document (.epdoc)\")"))
        #expect(landing.contains("Markdown dot m d"))
        #expect(landing.contains("JSON document dot epdoc"))

        #expect(commands.contains("allowDisplayFont: false"))
        #expect(commands.contains("if let shortcut"))
        #expect(commands.contains(".hoverGlass("))
        #expect(commands.contains("LandingShortcutDisplay.keyCornerRadius + 4"))
        #expect(!commands.contains("PixelCommandTypewriterText("))

        #expect(app.contains("Button(\"New Markdown Document (.md)\")"))
        #expect(app.contains("Button(\"New JSON Document (.epdoc)\")"))
        #expect(app.contains(".keyboardShortcut(\"n\", modifiers: [.command, .option])"))
    }

    @Test("App Store graph preserves and opens Epdoc document nodes")
    func appStoreGraphPreservesAndOpensEpdocNodes() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let epdoc = try loadRepoTextFile("Epistemos/Engine/EpdocDocument.swift")
        let openNode = try #require(sourceSection(
            in: graphState,
            startingAt: "func openNode(_ id: String)",
            endingBefore: "    func openNote(_ sourceId: String)"
        ))
        let restoreVisibility = try #require(sourceSection(
            in: graphState,
            startingAt: "private func restoreGraphNodeVisibility()",
            endingBefore: "    private func sanitizeSelectionAfterFilterChange()"
        ))
        let synchronousBuild = try #require(sourceSection(
            in: graphState,
            startingAt: "func buildStructuralGraph(context: ModelContext)",
            endingBefore: "    /// Lightweight refresh"
        ))

        #expect(graphState.contains("nodeVisibilityDefaultsVersionKey"))
        #expect(graphState.contains("nodeVisibilityDefaultsVersion"))
        #expect(restoreVisibility.contains("GraphNodeType.document"))
        #expect(restoreVisibility.contains("nodeVisibilityDefaultsVersionKey"))
        #expect(openNode.contains("case .document:"))
        #expect(openNode.contains("EpdocDocumentOpening.openDocument("))
        #expect(openNode.contains("withManifestID: resolvedId"))
        #expect(synchronousBuild.contains("try store.load(context: context)"))
        #expect(!synchronousBuild.contains("store.loadDirect(nodes: result.nodes, edges: result.edges)"))
        #expect(epdoc.contains("deferStructuralRefreshUntilGraphIsVisible()"))
    }

    @Test("App Store Notes sidebar routes files to Home or Multitask and exposes exactly two graph destinations")
    func appStoreNotesSidebarOwnsExplicitWorkspaceDestinations() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let noteWindows = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")
        let homeDocument = try loadRepoTextFile("Epistemos/Views/Landing/HomeDocumentWorkspaceView.swift")
        let workspace = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let hologram = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(sidebar.contains("enum NotesSidebarOpenDestination"))
        #expect(sidebar.contains("case home"))
        #expect(sidebar.contains("case multitask"))
        #expect(sidebar.contains("private var openDestination = NotesSidebarOpenDestination.multitask"))
        #expect(sidebar.contains("NotesSidebarDestinationPicker"))
        #expect(sidebar.contains("HomeDocumentRouter.openPage"))
        #expect(sidebar.contains("HomeDocumentRouter.openDocument"))
        #expect(sidebar.contains("Home Graph"))
        #expect(sidebar.contains("Multitask Graph"))
        #expect(sidebar.contains("Notes Sidebar (Command-2)"))

        #expect(landing.contains("LandingGraphDestinationTile"))
        #expect(landing.contains("Home Graph"))
        #expect(landing.contains("Multitask Graph"))
        #expect(landing.contains("KnowledgeGraphShortcutDispatcher.openHomeGraph"))
        #expect(landing.contains("KnowledgeGraphShortcutDispatcher.openMultitaskGraph"))

        #expect(app.contains("static func openHomeGraph"))
        #expect(app.contains("static func openMultitaskGraph"))
        #expect(app.contains("static func revealPage"))
        #expect(app.contains("static func revealDocument"))
        #expect(!app.contains("HologramController.shared.toggle()"))
        #expect(noteWindows.contains("func openGraphTab()"))
        #expect(noteWindows.contains("var isGraphTabOpen: Bool"))
        #expect(noteWindows.contains("HomeGraphEmbeddedView(host: .multitask)"))
        #expect(workspace.contains("KnowledgeGraphShortcutDispatcher.openMultitaskGraph()"))
        #expect(!workspace.contains("HologramController.shared.show()"))
        #expect(uiState.contains("case document(HomeDocumentSelection)"))
        #expect(homeDocument.contains("presentation: .embeddedHome"))
        #expect(homeDocument.contains("JSON Document (.epdoc) · saved preview"))
        #expect(homeDocument.contains("HTMLWorkspacePreviewView(package: package"))

        #expect(!settings.contains("Shaped Graph (experimental)"))
        #expect(!settings.contains("AppearanceShapedGraphSection"))
        #expect(!hologram.contains("shapedGraphExperimental"))
        #expect(!uiState.contains("shapedGraphExperimental"))
    }

    @Test("App Store editor titles reuse the historical ASCII blur reveal without toolbar glass")
    func appStoreEditorTitlesReuseHistoricalMotionTitle() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let motionTitle = try loadRepoTextFile("Epistemos/Views/Shared/MotionTitle.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(workspace.contains("MotionTitle("))
        #expect(workspace.contains("EditorTitleRevealKey("))
        #expect(workspace.contains("surface: resolvedNoteMode(for: page).rawValue"))
        #expect(workspace.contains("activationGeneration: titleRevealGeneration"))
        #expect(workspace.contains(".sharedBackgroundVisibility(.hidden)"))
        #expect(workspace.contains("NoteIdentityPopover("))

        #expect(chrome.contains("MotionTitle("))
        #expect(chrome.contains("EditorTitleRevealKey("))
        #expect(chrome.contains(".sharedBackgroundVisibility(.hidden)"))
        #expect(motionTitle.contains("TypewriterASCIIRippleText("))
        #expect(motionTitle.contains(".motionReveal()"))

        let topBar = try #require(sourceSection(
            in: codeEditor,
            startingAt: "private var codeEditorTopBar: some View",
            endingBefore: "    private var editorWithSearch"
        ))
        #expect(!topBar.contains("CodeFileIdentityChip("))
    }

    @Test("App Store Epdoc save and derived work stay truthful and coalesced")
    func appStoreEpdocSaveAndDerivedWorkAreCoalesced() throws {
        let document = try loadRepoTextFile("Epistemos/Engine/EpdocDocument.swift")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let toolbar = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")
        let nativeEditor = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocTextKit2EditorView.swift")
        let graphProjector = try loadRepoTextFile("Epistemos/Engine/EpdocGraphProjector.swift")

        #expect(document.contains("canvasEngine: .standaloneEpdocDefault"))
        #expect(document.contains("derivedProjectionTask?.cancel()"))
        #expect(document.contains("scheduleDerivedProjection(contentJSON:"))
        #expect(document.contains("setValidatedNativeContentJSON("))
        #expect(document.contains("to: fileURL,\n                    ofType: fileType,\n                    for: .saveOperation,"))
        #expect(document.contains("completionHandler:"))
        #expect(chrome.contains("Label(\"Save Now\""))
        #expect(chrome.components(separatedBy: ".keyboardShortcut(\"s\", modifiers: .command)").count == 2)
        #expect(!toolbar.contains("public var onSave"))
        #expect(toolbar.contains("EpdocEditorToolbarCapabilities"))
        #expect(chrome.contains("capabilities: canvasEngine == .nativeTextKit2"))
        #expect(!nativeEditor.contains("controller?.toolbarModel.isDirty = false"))
        #expect(nativeEditor.contains("guard EpdocContentWidthUpdatePolicy.requiresMutation("))
        #expect(nativeEditor.contains("EpdocCheckpointSchedulingPolicy.quietWindowMilliseconds"))
        #expect(nativeEditor.contains("Task.detached(priority: .utility)"))
        #expect(!graphProjector.contains("EpdocComplexityCalculator"))
        #expect(!graphProjector.contains("ComplexityWeights"))
    }
}
