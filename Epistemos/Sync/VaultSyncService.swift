import AppKit
import CryptoKit
import Foundation
import Observation
import SQLite3
import SwiftData
import os

// MARK: - VaultSyncService
// Apple Notes Hybrid: SwiftData is the sole source of truth during editing.
// Vault .md files are an import/export target — NOT a live sync partner.
//
// Save triggers: per-note Save (Cmd+S), Save All (Shift+Cmd+S), auto-save interval.
// Import: initial vault import on attach, manual "Sync from Vault" button.
// No live file watching — VaultFilePresenter has been removed.

/// A conflict detected during "Sync from Vault" — both the in-app and on-disk versions changed.
struct VaultSyncConflict: Identifiable {
    let id: String  // page ID
    let title: String
    let appBody: String
    let diskBody: String
}

struct VaultBookmarkStartupValidation: Sendable {
    let bookmarkExists: Bool
    let isReadyForAutomaticRestore: Bool
    let failureReason: String?
}

struct VaultHealthSnapshot: Sendable {
    let vaultURL: URL?
    let isVaultReadable: Bool
    let vaultMarkdownCount: Int
    let indexedPageCount: Int
    let indexedPagesWithFilePath: Int
    let totalIndexedPageCount: Int
    let nonVaultPageCount: Int
    let duplicateTrackedPathCount: Int
    let localBodyFileCount: Int
    let bookmarkExists: Bool
    let restoreFailed: Bool
    let initialImportCompleted: Bool
    let hadPriorLocalState: Bool

    var displayPath: String {
        vaultURL?.path ?? "No readable vault path detected"
    }

    var hasSevereIndexMismatch: Bool {
        guard isVaultReadable, vaultMarkdownCount > 0 else { return false }
        guard indexedPagesWithFilePath > 0 else { return true }
        if vaultMarkdownCount >= 50 {
            return indexedPageCount < max(10, vaultMarkdownCount / 10)
        }
        return indexedPageCount < max(1, vaultMarkdownCount / 2)
    }

    var hasCollapsedBodyCache: Bool {
        guard localBodyFileCount > 0, totalIndexedPageCount > 0 else { return false }
        return localBodyFileCount < min(totalIndexedPageCount, 3) && indexedPagesWithFilePath == 0
    }

    var requiresRecovery: Bool {
        if restoreFailed && hadPriorLocalState {
            return true
        }
        guard initialImportCompleted else { return false }
        return hasSevereIndexMismatch || hasCollapsedBodyCache
    }
}

struct VaultRecoveryIssue: Identifiable, Sendable {
    let id: String
    let snapshot: VaultHealthSnapshot
    let reason: String

    init(snapshot: VaultHealthSnapshot, reason: String) {
        self.id = UUID().uuidString
        self.snapshot = snapshot
        self.reason = reason
    }

    var detailText: String {
        """
        \(reason)

        Vault path: \(snapshot.displayPath)
        Vault notes on disk: \(snapshot.vaultMarkdownCount)
        Vault-backed indexed notes in app: \(snapshot.indexedPageCount)
        Unique tracked vault paths: \(snapshot.indexedPagesWithFilePath)
        Total indexed notes in app: \(snapshot.totalIndexedPageCount)
        Non-vault indexed notes: \(snapshot.nonVaultPageCount)
        Duplicate tracked vault paths: \(snapshot.duplicateTrackedPathCount)
        Local note-body files: \(snapshot.localBodyFileCount)
        """
    }

    var blocksWorkspaceInteraction: Bool {
        snapshot.isVaultReadable && snapshot.vaultMarkdownCount > 0
    }
}

enum VaultPostImportRecallWorkload: Sendable, Equatable {
    case none
    case incremental(changedPageIDs: [String], deletedPageIDs: [String])
    case rebuild
}

struct VaultImportProgressSnapshot: Sendable, Equatable {
    nonisolated static let incrementalPostImportIndexChangeLimit = 256

    var vaultName: String
    var phase: String
    var processedFileCount: Int
    var totalImportableFileCount: Int
    var discoveredRegularFileCount: Int
    var unsupportedFileCount: Int
    var skippedPolicyCount: Int
    var folderCount: Int
    var duplicateFileNameCount: Int
    var insertedCount: Int
    var updatedCount: Int
    var unchangedCount: Int
    var deletedCount: Int
    var unreadableCount: Int
    var failedCount: Int
    var trackedVaultPageCount: Int
    var uniqueTrackedPathCount: Int
    var nonVaultPageCount: Int
    var duplicateTrackedPathCount: Int
    var fileTypeCounts: [String: Int]
    var unsupportedFileTypeCounts: [String: Int]
    var skippedPolicyReasonCounts: [String: Int]
    var postImportChangedPageIDs: [String]
    var postImportDeletedPageIDs: [String]
    var postImportChangeIDsAreComplete: Bool
    var isComplete: Bool

    nonisolated static func starting(vaultName: String, phase: String = "Preparing vault import") -> VaultImportProgressSnapshot {
        VaultImportProgressSnapshot(
            vaultName: vaultName,
            phase: phase,
            processedFileCount: 0,
            totalImportableFileCount: 0,
            discoveredRegularFileCount: 0,
            unsupportedFileCount: 0,
            skippedPolicyCount: 0,
            folderCount: 0,
            duplicateFileNameCount: 0,
            insertedCount: 0,
            updatedCount: 0,
            unchangedCount: 0,
            deletedCount: 0,
            unreadableCount: 0,
            failedCount: 0,
            trackedVaultPageCount: 0,
            uniqueTrackedPathCount: 0,
            nonVaultPageCount: 0,
            duplicateTrackedPathCount: 0,
            fileTypeCounts: [:],
            unsupportedFileTypeCounts: [:],
            skippedPolicyReasonCounts: [:],
            postImportChangedPageIDs: [],
            postImportDeletedPageIDs: [],
            postImportChangeIDsAreComplete: true,
            isComplete: false
        )
    }

    var progressFraction: Double? {
        guard totalImportableFileCount > 0 else { return nil }
        return min(1, max(0, Double(processedFileCount) / Double(totalImportableFileCount)))
    }

    var compactStatusMessage: String {
        if totalImportableFileCount > 0 {
            return "\(phase): \(processedFileCount)/\(totalImportableFileCount) files"
        }
        return phase
    }

    var primarySummary: String {
        if isComplete {
            return "Imported \(uniqueTrackedPathCount) vault-backed items from \(vaultName)"
        }
        return compactStatusMessage
    }

    var mutationSummary: String {
        "\(insertedCount) new, \(updatedCount) updated, \(unchangedCount) unchanged, \(deletedCount) deleted"
    }

    var issueSummary: String {
        "\(unreadableCount) unreadable, \(failedCount) failed, \(duplicateTrackedPathCount) duplicate tracked paths"
    }

    var inventorySummary: String {
        "\(discoveredRegularFileCount) regular files discovered; \(totalImportableFileCount) importable, \(unsupportedFileCount) unsupported, \(skippedPolicyCount) skipped by policy, \(folderCount) folders"
    }

    nonisolated var postImportMutationCount: Int {
        insertedCount + updatedCount + deletedCount
    }

    nonisolated var canApplyIncrementalPostImportIndexing: Bool {
        isComplete
            && postImportChangeIDsAreComplete
            && postImportMutationCount <= Self.incrementalPostImportIndexChangeLimit
    }

    nonisolated var postImportRecallWorkload: VaultPostImportRecallWorkload {
        guard canApplyIncrementalPostImportIndexing else { return .rebuild }
        guard !postImportChangedPageIDs.isEmpty || !postImportDeletedPageIDs.isEmpty else {
            return .none
        }
        return .incremental(
            changedPageIDs: postImportChangedPageIDs,
            deletedPageIDs: postImportDeletedPageIDs
        )
    }

    func topFileTypes(limit: Int = 6) -> [(String, Int)] {
        sortedCounts(fileTypeCounts, limit: limit)
    }

    func topUnsupportedFileTypes(limit: Int = 5) -> [(String, Int)] {
        sortedCounts(unsupportedFileTypeCounts, limit: limit)
    }

    func topSkippedPolicyReasons(limit: Int = 5) -> [(String, Int)] {
        sortedCounts(skippedPolicyReasonCounts, limit: limit)
    }

    func withPhase(_ phase: String, isComplete: Bool? = nil) -> VaultImportProgressSnapshot {
        var copy = self
        copy.phase = phase
        if let isComplete {
            copy.isComplete = isComplete
        }
        return copy
    }

    private func sortedCounts(_ counts: [String: Int], limit: Int) -> [(String, Int)] {
        counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}

private struct VersionCaptureSnapshot: Sendable {
    let pageId: String
    let title: String
    let body: String
    let wordCount: Int
}

private let log = Logger(subsystem: "com.epistemos", category: "VaultSync")

@MainActor
private enum VaultImportProgressBridge {
    static func publish(_ snapshot: VaultImportProgressSnapshot, expectedVaultPath: String) {
        guard let vaultSync = AppBootstrap.shared?.vaultSync,
              vaultSync.vaultURL?.standardizedFileURL.path == expectedVaultPath
        else { return }
        vaultSync.applyVaultImportProgress(snapshot)
    }
}

@MainActor @Observable
final class VaultSyncService {
    typealias ExportPageOperation = @Sendable (String, URL) async throws -> (path: String, bodyHash: String)?
    typealias TMUtilCommandRunner = @Sendable ([String]) throws -> String
    typealias BookmarkDataWriter = @Sendable (URL, URL.BookmarkCreationOptions) throws -> Data
    typealias SecurityScopeAccessOperation = @Sendable (URL) -> Bool
    fileprivate nonisolated static let bookmarkKey = "epistemos.vaultBookmark"
    fileprivate nonisolated static let lastVaultPathKey = "epistemos.lastVaultPath"
    fileprivate nonisolated static let trustedSuspiciousVaultPathKey = "epistemos.confirmedSuspiciousVaultPath"
    fileprivate nonisolated static let autoSaveIntervalKey = "epistemos.autoSaveInterval"
    fileprivate nonisolated static let testDefaultsSuitePrefix = "com.epistemos.tests.VaultSyncService."
    fileprivate nonisolated static let skipRestoreEnvironmentKey = "EPISTEMOS_SKIP_VAULT_RESTORE"
    private nonisolated static let backgroundLog = Logger(
        subsystem: "com.epistemos",
        category: "VaultSync"
    )
    private nonisolated static let defaultRecoveryVaultURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("My mind", isDirectory: true)
    }()

    private nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || Bundle.main.bundleURL.pathExtension == "xctest"
    }

    private nonisolated static func requiresSecurityScopedVaultAccess() -> Bool {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return true
        #else
        return false
        #endif
    }

    nonisolated static func shouldRestoreVaultFromBookmark(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        processInfoEnvironment["XCTestConfigurationFilePath"] == nil
            && !shouldSkipVaultRestore(processInfoEnvironment: processInfoEnvironment)
    }

    private nonisolated static func shouldSkipVaultRestore(
        processInfoEnvironment: [String: String]
    ) -> Bool {
        guard let raw = processInfoEnvironment[skipRestoreEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }

        switch raw {
        case "1", "true", "yes", "y":
            return true
        default:
            return false
        }
    }

    nonisolated private static func makeDefaultUserDefaults(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserDefaults {
        guard shouldRestoreVaultFromBookmark(processInfoEnvironment: processInfoEnvironment), !isRunningTests else {
            let suiteName = "\(testDefaultsSuitePrefix)\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }
        return .standard
    }

    private struct DirtySaveBatch {
        let context: ModelContext
        let vaultURL: URL
        let dirtyIds: [String]
    }

    private struct APFSSnapshotRecord: Codable, Sendable {
        let snapshotID: String
        let createdAt: Date
        let reason: String
    }

    private struct LocalFilesystemStateTargets: Sendable {
        let noteBodiesURL: URL
        let searchDatabaseURL: URL?
        let styleCacheURL: URL?
    }

    private var indexActor: VaultIndexActor?
    private let modelContainer: ModelContainer
    var exportPageOverride: ExportPageOperation?
    private var searchDatabaseURLOverride: URL?
    private var appSupportDirectoryURLOverride: URL?
    private var preferencesFileURLOverride: URL?
    private var recoverySnapshotRootURLOverride: URL?
    private var managedBodyCountProvider: (@Sendable () -> Int)?
    private var tmutilCommandRunnerOverride: TMUtilCommandRunner?
    private var bookmarkDataWriterOverride: BookmarkDataWriter?
    private var securityScopeAccessOperation: SecurityScopeAccessOperation = { url in
        url.startAccessingSecurityScopedResource()
    }
    private var requiresSecurityScopedVaultAccessOverride: Bool?
    private var defaults = UserDefaults.standard

    private(set) var vaultURL: URL?
    private(set) var isWatching = false
    var ambientManifest: VaultManifest?

    /// Whether the vault is being imported/indexed. Starts true if a vault
    /// bookmark exists so the landing page shows a vault sync message on the
    /// very first frame, before the import Task even begins.
    var isIndexing = false
    var vaultActivityMessage: String?
    var vaultImportProgress: VaultImportProgressSnapshot?
    var lastVaultImportSummary: VaultImportProgressSnapshot?
    var recoveryIssue: VaultRecoveryIssue?
    var isRecoveringLocalState = false

    /// FTS5 search index (GRDB). Created in startWatching, nil'd in stopWatching.
    private(set) var searchService: SearchIndexService?

    /// EventBus for emitting vaultChanged events on mutations.
    private weak var eventBus: EventBus?

    /// Set the EventBus reference for vault change notifications.
    func setEventBus(_ bus: EventBus) { eventBus = bus }

    /// Whether we hold a security-scoped resource on the vault URL.
    private var isSecurityScoped = false

    private var importTask: Task<Void, Never>?
    private var autoSaveTask: Task<Void, Never>?
    private var versionCaptureTask: Task<Void, Never>?
    private var manifestRefreshTask: Task<Void, Never>?
    /// Monotonic counter of vault mutations. Bumped whenever a vault
    /// event is emitted so the periodic manifest-refresh timer can tell
    /// whether anything has actually changed since its last tick and
    /// skip the rebuild otherwise. Idle = zero work.
    @ObservationIgnored
    private var vaultMutationEpoch: UInt64 = 0
    @ObservationIgnored
    private var lastManifestRefreshEpoch: UInt64 = 0
    @ObservationIgnored
    private var powerModeObserverTask: Task<Void, Never>?
    private var inFlightDirtySaveTask: Task<Void, Never>?
    private var pendingDirtySaveRequest = false
    private var initialImportCompleted = false

    // MARK: - File Watching
    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var fileWatcherFD: Int32 = -1
    private var fileWatchDebounceTask: Task<Void, Never>?
    private let fileWatcherClock = ContinuousClock()
    private var fileWatcherIgnoreUntil: ContinuousClock.Instant?
    private nonisolated static let recoverySnapshotLimit = 20

    private struct ResolvedVaultBookmark: Sendable {
        let url: URL
        let isStale: Bool
        let usedSecurityScope: Bool
    }

    private enum VaultBookmarkResolutionError: Error {
        case corrupted
        case timedOut
    }

    init(modelContainer: ModelContainer, userDefaults: UserDefaults? = nil) {
        let resolvedDefaults = userDefaults ?? Self.makeDefaultUserDefaults()
        self.modelContainer = modelContainer
        self.defaults = resolvedDefaults
        let hasStartupVaultBookmark = resolvedDefaults.data(forKey: Self.bookmarkKey) != nil
        self.isIndexing = hasStartupVaultBookmark
        self.vaultActivityMessage = hasStartupVaultBookmark ? "Restoring saved vault..." : nil
        self.autoSaveInterval = resolvedDefaults.double(forKey: Self.autoSaveIntervalKey)
        startObservingPowerModeChangesIfNeeded()
    }

    deinit {
        powerModeObserverTask?.cancel()
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> [T]? {
        do {
            return try context.fetch(descriptor)
        } catch {
            log.error(
                "VaultSyncService: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> T? {
        fetchAll(descriptor, in: context, label: label)?.first
    }

    private func fetchCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> Int? {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            log.error(
                "VaultSyncService: failed to fetch count for \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func fetchBackgroundAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> [T]? {
        do {
            return try context.fetch(descriptor)
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func fetchBackgroundFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> T? {
        fetchBackgroundAll(descriptor, in: context, label: label)?.first
    }

    private nonisolated static func fetchBackgroundCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        label: String
    ) -> Int? {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed to fetch count for \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func mappedFileData(at url: URL, label: String) -> Data? {
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed to read \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func removeItemIfPresent(at url: URL, label: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private nonisolated static func recreateDirectory(at url: URL, label: String) {
        let fm = FileManager.default
        removeItemIfPresent(at: url, label: label)
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed to create \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private nonisolated static func sleepHandlingCancellation(
        for duration: Duration,
        label: String
    ) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return true
        } catch is CancellationError {
            return false
        } catch {
            backgroundLog.error(
                "VaultSyncService: failed during \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    func setVaultURLForTesting(_ vaultURL: URL?) {
        self.vaultURL = vaultURL
        if vaultURL == nil {
            indexActor = nil
            return
        }
        if indexActor == nil {
            indexActor = VaultIndexActor(modelContainer: modelContainer)
        }
    }

    func importVaultForTesting(from vaultURL: URL) async throws {
        self.vaultURL = vaultURL
        let actor = VaultIndexActor(modelContainer: modelContainer)
        indexActor = actor
        try await actor.importVault(from: vaultURL)
    }

    func setExportPageOverrideForTesting(_ exportPageOverride: ExportPageOperation?) {
        self.exportPageOverride = exportPageOverride
    }

    func setSearchDatabaseURLForTesting(_ databaseURL: URL?) {
        searchDatabaseURLOverride = databaseURL
    }

    func setAppSupportDirectoryURLForTesting(_ url: URL?) {
        appSupportDirectoryURLOverride = url
    }

    func setPreferencesFileURLForTesting(_ url: URL?) {
        preferencesFileURLOverride = url
    }

    func setRecoverySnapshotRootURLForTesting(_ url: URL?) {
        recoverySnapshotRootURLOverride = url
    }

    func setManagedBodyCountProviderForTesting(_ provider: (@Sendable () -> Int)?) {
        managedBodyCountProvider = provider
    }

    func setTMUtilCommandRunnerForTesting(_ runner: TMUtilCommandRunner?) {
        tmutilCommandRunnerOverride = runner
    }

    func setBookmarkDataWriterForTesting(_ writer: BookmarkDataWriter?) {
        bookmarkDataWriterOverride = writer
    }

    func setSecurityScopeAccessOperationForTesting(_ operation: SecurityScopeAccessOperation?) {
        securityScopeAccessOperation = operation ?? { url in
            url.startAccessingSecurityScopedResource()
        }
    }

    func setRequiresSecurityScopedVaultAccessForTesting(_ value: Bool?) {
        requiresSecurityScopedVaultAccessOverride = value
    }

    func setUserDefaultsForTesting(_ userDefaults: UserDefaults) {
        defaults = userDefaults
        isIndexing = userDefaults.data(forKey: Self.bookmarkKey) != nil
        autoSaveInterval = userDefaults.double(forKey: Self.autoSaveIntervalKey)
    }

    func setInitialImportCompletedForTesting(_ value: Bool) {
        initialImportCompleted = value
    }

    func clearPendingStartupRestoreForTesting() {
        clearPendingStartupRestore()
    }

    func startupBookmarkValidation() -> VaultBookmarkStartupValidation {
        Self.startupBookmarkValidation(
            bookmarkData: defaults.data(forKey: Self.bookmarkKey)
        )
    }

    nonisolated static func startupBookmarkValidationForTesting(
        bookmarkExists: Bool,
        resolvedURL: URL?,
        isStale: Bool,
        usedSecurityScope: Bool,
        accessGranted: Bool,
        isReadable: Bool,
        requiresSecurityScopedVaultAccess: Bool? = nil
    ) -> VaultBookmarkStartupValidation {
        makeStartupBookmarkValidation(
            bookmarkExists: bookmarkExists,
            resolvedURL: resolvedURL,
            isStale: isStale,
            usedSecurityScope: usedSecurityScope,
            accessGranted: accessGranted,
            isReadable: isReadable,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess
                ?? Self.requiresSecurityScopedVaultAccess()
        )
    }

    nonisolated static func vaultWatchStartAllowedForTesting(
        scopeAlreadyAcquired: Bool,
        accessGranted: Bool,
        requiresSecurityScopedVaultAccess: Bool
    ) -> Bool {
        vaultWatchStartAllowed(
            scopeAlreadyAcquired: scopeAlreadyAcquired,
            accessGranted: accessGranted,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess
        )
    }

    nonisolated static func suspiciousVaultRestoreReconfirmationReasonForTesting(
        resolvedURL: URL,
        assessment: VaultIndexActor.VaultFolderSelectionAssessment,
        trustedSuspiciousVaultPath: String?
    ) -> String? {
        suspiciousVaultRestoreReconfirmationReason(
            resolvedURL: resolvedURL,
            assessment: assessment,
            trustedSuspiciousVaultPath: trustedSuspiciousVaultPath
        )
    }

    private func exportPage(pageId: String, to vaultURL: URL) async throws -> (path: String, bodyHash: String)? {
        if let exportPageOverride {
            return try await exportPageOverride(pageId, vaultURL)
        }
        return try await indexActor?.exportPage(pageId: pageId, to: vaultURL)
    }

    private func makeBookmarkData(
        for url: URL,
        options: URL.BookmarkCreationOptions
    ) throws -> Data {
        if let bookmarkDataWriterOverride {
            return try bookmarkDataWriterOverride(url, options)
        }
        return try url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func requiresSecurityScopedVaultAccess() -> Bool {
        requiresSecurityScopedVaultAccessOverride
            ?? Self.requiresSecurityScopedVaultAccess()
    }

    private func startSecurityScopedAccess(for url: URL) -> Bool {
        securityScopeAccessOperation(url)
    }

    func dismissRecoveryIssue() {
        recoveryIssue = nil
    }

    func clearPendingStartupRestore() {
        guard !isWatching else { return }
        isIndexing = false
        vaultActivityMessage = nil
        vaultImportProgress = nil
    }

    var visibleVaultImportDetails: VaultImportProgressSnapshot? {
        vaultImportProgress ?? lastVaultImportSummary
    }

    fileprivate func beginVaultImportProgress(vaultName: String, phase: String = "Preparing vault import") {
        vaultImportProgress = .starting(vaultName: vaultName, phase: phase)
        lastVaultImportSummary = nil
        vaultActivityMessage = vaultImportProgress?.compactStatusMessage
    }

    fileprivate func applyVaultImportProgress(_ snapshot: VaultImportProgressSnapshot) {
        vaultImportProgress = snapshot
        vaultActivityMessage = snapshot.compactStatusMessage
        if snapshot.isComplete {
            lastVaultImportSummary = snapshot
        }
    }

    fileprivate func finishVaultImportProgress(keepSummary: Bool) {
        if keepSummary, let snapshot = vaultImportProgress, snapshot.isComplete {
            lastVaultImportSummary = snapshot
        }
        vaultImportProgress = nil
    }

    fileprivate func clearVaultImportTelemetry() {
        vaultImportProgress = nil
        lastVaultImportSummary = nil
    }

    func persistVaultSelection(_ url: URL, userConfirmedSuspiciousFolder: Bool = false) {
        defaults.set(url.path, forKey: Self.lastVaultPathKey)
        let standardizedPath = url.standardizedFileURL.path
        var didPersistBookmark = false

        do {
            let bookmark = try makeBookmarkData(for: url, options: .withSecurityScope)
            defaults.set(bookmark, forKey: Self.bookmarkKey)
            didPersistBookmark = true
        } catch {
            guard !requiresSecurityScopedVaultAccess() else {
                defaults.removeObject(forKey: Self.bookmarkKey)
                log.error(
                    """
                    Failed to persist required security-scoped vault bookmark for \(url.path, privacy: .public): \
                    \(error.localizedDescription, privacy: .public)
                    """
                )
                defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
                recoveryIssue = nil
                return
            }
            do {
                let bookmark = try makeBookmarkData(for: url, options: [])
                defaults.set(bookmark, forKey: Self.bookmarkKey)
                didPersistBookmark = true
                log.warning(
                    """
                    Falling back to a plain vault bookmark for \(url.path, privacy: .public) \
                    after security-scoped persistence failed: \(error.localizedDescription, privacy: .public)
                    """
                )
            } catch {
                defaults.removeObject(forKey: Self.bookmarkKey)
                log.error(
                    "Failed to persist vault bookmark for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if didPersistBookmark && userConfirmedSuspiciousFolder {
            defaults.set(standardizedPath, forKey: Self.trustedSuspiciousVaultPathKey)
        } else {
            defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
        }
        recoveryIssue = nil
    }

    func clearPersistedVaultSelection() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        defaults.removeObject(forKey: Self.lastVaultPathKey)
        defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
    }

    func shouldRunBodyCleanup(candidateVaultURL: URL?) async -> Bool {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: candidateVaultURL,
            bookmarkExists: defaults.data(forKey: Self.bookmarkKey) != nil,
            restoreFailed: false
        )
        guard snapshot.initialImportCompleted else { return false }
        guard snapshot.isVaultReadable, snapshot.vaultMarkdownCount > 0 else { return false }
        guard snapshot.indexedPagesWithFilePath > 0 else { return false }
        return !snapshot.requiresRecovery
    }

    func detectRecoveryIssue(
        candidateVaultURL: URL?,
        bookmarkExists: Bool,
        restoreFailed: Bool
    ) async -> VaultRecoveryIssue? {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: candidateVaultURL,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed
        )
        guard snapshot.requiresRecovery else { return nil }
        return VaultRecoveryIssue(snapshot: snapshot, reason: recoveryReason(for: snapshot))
    }

    @discardableResult
    func recoverFromVault(at vaultURL: URL) async -> Bool {
        guard !isRecoveringLocalState else { return false }
        isRecoveringLocalState = true
        recoveryIssue = nil
        isIndexing = true
        vaultActivityMessage = "Recovering vault \"\(vaultURL.lastPathComponent)\"..."
        initialImportCompleted = false

        do {
            try await snapshotLocalStateOffMain()
            stopWatching(preserveData: true)
            await clearDerivedLocalStateForRecovery()
            persistVaultSelection(vaultURL)
            startWatching(vaultURL: vaultURL)
            await importTask?.value
            let issue = await detectRecoveryIssue(
                candidateVaultURL: vaultURL,
                bookmarkExists: true,
                restoreFailed: false
            )
            recoveryIssue = issue
            isRecoveringLocalState = false
            vaultActivityMessage = nil
            return issue == nil
        } catch {
            isRecoveringLocalState = false
            isIndexing = false
            vaultActivityMessage = nil
            let snapshot = await buildVaultHealthSnapshot(
                candidateVaultURL: vaultURL,
                bookmarkExists: true,
                restoreFailed: true
            )
            recoveryIssue = VaultRecoveryIssue(
                snapshot: snapshot,
                reason: "Epistemos could not rebuild its local vault state: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func buildVaultHealthSnapshot(
        candidateVaultURL: URL?,
        bookmarkExists: Bool,
        restoreFailed: Bool
    ) async -> VaultHealthSnapshot {
        let resolvedVaultURL = resolvedRecoveryVaultURL(from: candidateVaultURL)
        let isVaultReadable = resolvedVaultURL.map(isReadableVaultURL(_:)) ?? false
        let vaultMarkdownCount: Int
        if let resolvedVaultURL, isVaultReadable {
            vaultMarkdownCount = await Task.detached(priority: .utility) {
                VaultIndexActor.countImportableNoteFiles(in: resolvedVaultURL)
            }.value
        } else {
            vaultMarkdownCount = 0
        }
        let managedBodyCountProvider = self.managedBodyCountProvider
        let localBodyFileCount = await Task.detached(priority: .utility) {
            managedBodyCountProvider?() ?? NoteFileStorage.managedBodyCount()
        }.value

        let context = modelContainer.mainContext
        let pages = fetchAll(
            FetchDescriptor<SDPage>(),
            in: context,
            label: "vault health pages"
        ) ?? []
        let comparableCounts = comparableVaultCounts(
            pages: pages,
            resolvedVaultURL: resolvedVaultURL
        )

        return VaultHealthSnapshot(
            vaultURL: resolvedVaultURL,
            isVaultReadable: isVaultReadable,
            vaultMarkdownCount: vaultMarkdownCount,
            indexedPageCount: comparableCounts.trackedVaultPageCount,
            indexedPagesWithFilePath: comparableCounts.uniqueTrackedVaultPathCount,
            totalIndexedPageCount: pages.count,
            nonVaultPageCount: comparableCounts.nonVaultPageCount,
            duplicateTrackedPathCount: comparableCounts.duplicateTrackedPathCount,
            localBodyFileCount: localBodyFileCount,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed,
            initialImportCompleted: initialImportCompleted,
            hadPriorLocalState: !pages.isEmpty
                || localBodyFileCount > 0
                || defaults.string(forKey: Self.lastVaultPathKey) != nil
        )
    }

    private func currentVaultHealthSnapshot(restoreFailed: Bool) -> VaultHealthSnapshot {
        let resolvedVaultURL = resolvedRecoveryVaultURL(from: vaultURL)
        let isVaultReadable = resolvedVaultURL.map(isReadableVaultURL(_:)) ?? false
        let vaultMarkdownCount =
            if let resolvedVaultURL, isVaultReadable {
                VaultIndexActor.countImportableNoteFiles(in: resolvedVaultURL)
            } else {
                0
            }
        let localBodyFileCount = managedBodyCountProvider?() ?? NoteFileStorage.managedBodyCount()
        let context = modelContainer.mainContext
        let pages = fetchAll(
            FetchDescriptor<SDPage>(),
            in: context,
            label: "current vault health pages"
        ) ?? []
        let comparableCounts = comparableVaultCounts(
            pages: pages,
            resolvedVaultURL: resolvedVaultURL
        )

        return VaultHealthSnapshot(
            vaultURL: resolvedVaultURL,
            isVaultReadable: isVaultReadable,
            vaultMarkdownCount: vaultMarkdownCount,
            indexedPageCount: comparableCounts.trackedVaultPageCount,
            indexedPagesWithFilePath: comparableCounts.uniqueTrackedVaultPathCount,
            totalIndexedPageCount: pages.count,
            nonVaultPageCount: comparableCounts.nonVaultPageCount,
            duplicateTrackedPathCount: comparableCounts.duplicateTrackedPathCount,
            localBodyFileCount: localBodyFileCount,
            bookmarkExists: defaults.data(forKey: Self.bookmarkKey) != nil,
            restoreFailed: restoreFailed,
            initialImportCompleted: initialImportCompleted,
            hadPriorLocalState: !pages.isEmpty
                || localBodyFileCount > 0
                || defaults.string(forKey: Self.lastVaultPathKey) != nil
        )
    }

    private func handleSnapshotFailureBeforeDestructiveClear(_ error: Error) {
        let snapshot = currentVaultHealthSnapshot(restoreFailed: true)
        recoveryIssue = VaultRecoveryIssue(
            snapshot: snapshot,
            reason:
                "Epistemos could not create a recovery snapshot before clearing local vault data: \(error.localizedDescription). The clear was aborted to protect your local state."
        )
    }

    private func resolvedRecoveryVaultURL(from candidateVaultURL: URL?) -> URL? {
        if let candidateVaultURL {
            return candidateVaultURL
        }
        if let vaultURL {
            return vaultURL
        }
        if let hintedPath = defaults.string(forKey: Self.lastVaultPathKey),
           !hintedPath.isEmpty {
            return URL(fileURLWithPath: hintedPath, isDirectory: true)
        }
        return Self.defaultRecoveryVaultURL
    }

    private func comparableVaultCounts(
        pages: [SDPage],
        resolvedVaultURL: URL?
    ) -> VaultIndexActor.VaultImportComparableCounts {
        guard let resolvedVaultURL else {
            return VaultIndexActor.VaultImportComparableCounts(
                trackedVaultPageCount: 0,
                uniqueTrackedVaultPathCount: 0,
                duplicateTrackedPathCount: 0,
                nonVaultPageCount: pages.count
            )
        }
        return VaultIndexActor.comparableVaultPageCounts(pages: pages, in: resolvedVaultURL)
    }

    private func isReadableVaultURL(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) && fm.isReadableFile(atPath: url.path)
    }

    private func recoveryReason(for snapshot: VaultHealthSnapshot) -> String {
        if snapshot.restoreFailed {
            return "Epistemos could not reconnect to the vault and the local index is no longer trustworthy."
        }
        if snapshot.hasCollapsedBodyCache {
            return "Epistemos kept only a collapsed local note-body cache after the vault stayed readable."
        }
        if snapshot.indexedPagesWithFilePath == 0 && snapshot.vaultMarkdownCount > 0 {
            return "Epistemos can read the vault on disk, but the local index lost every file-path mapping."
        }
        if snapshot.hasSevereIndexMismatch {
            return "Epistemos indexed only a small fraction of the readable vault."
        }
        return "Epistemos detected a vault mismatch and needs to rebuild its local state."
    }

    private func appSupportDirectoryURL() -> URL? {
        if let appSupportDirectoryURLOverride {
            return appSupportDirectoryURLOverride
        }
        let appSupportBase = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)
        return appSupportBase.appendingPathComponent("Epistemos", isDirectory: true)
    }

    private func preferencesFileURL() -> URL? {
        if let preferencesFileURLOverride {
            return preferencesFileURLOverride
        }
        guard let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return library
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("com.epistemos.app.plist")
    }

    private func recoverySnapshotRootURL() -> URL? {
        if let recoverySnapshotRootURLOverride {
            return recoverySnapshotRootURLOverride
        }
        let appSupportBase = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)
        return appSupportBase.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
    }

    private func apfsSnapshotManifestURL() -> URL? {
        recoverySnapshotRootURL()?.appendingPathComponent("apfs-snapshot-manifest.json")
    }

    private func defaultSearchDatabaseURL() -> URL? {
        searchDatabaseURLOverride ?? appSupportDirectoryURL()?.appendingPathComponent("search.sqlite")
    }

    private func snapshotLocalState() throws {
        createAPFSSafetySnapshotIfPossible(reason: "local-state-recovery")
        try Self.createRecoverySnapshot(
            snapshotRoot: recoverySnapshotRootURL(),
            appSupportURL: appSupportDirectoryURL(),
            preferencesURL: preferencesFileURL(),
            sqliteSourceURLs: sqliteDatabaseURLsForSnapshot(),
            maxCount: Self.recoverySnapshotLimit
        )
    }

    private func snapshotLocalStateOffMain() async throws {
        createAPFSSafetySnapshotIfPossible(reason: "local-state-recovery")
        let snapshotRoot = recoverySnapshotRootURL()
        let appSupportURL = appSupportDirectoryURL()
        let preferencesURL = preferencesFileURL()
        let sqliteSourceURLs = sqliteDatabaseURLsForSnapshot()

        try await Task.detached(priority: .utility) {
            try Self.createRecoverySnapshot(
                snapshotRoot: snapshotRoot,
                appSupportURL: appSupportURL,
                preferencesURL: preferencesURL,
                sqliteSourceURLs: sqliteSourceURLs,
                maxCount: Self.recoverySnapshotLimit
            )
        }.value
    }

    private nonisolated static func createRecoverySnapshot(
        snapshotRoot: URL?,
        appSupportURL: URL?,
        preferencesURL: URL?,
        sqliteSourceURLs: [URL],
        maxCount: Int
    ) throws {
        let fm = FileManager.default
        guard let snapshotRoot else { return }
        try fm.createDirectory(at: snapshotRoot, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let snapshotURL = snapshotRoot.appendingPathComponent(
            "snapshot-\(formatter.string(from: .now))-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        try fm.createDirectory(at: snapshotURL, withIntermediateDirectories: true)

        if let appSupportURL, fm.fileExists(atPath: appSupportURL.path) {
            let snapshottedAppSupportURL = snapshotURL.appendingPathComponent(
                appSupportURL.lastPathComponent,
                isDirectory: true
            )
            let heavyweightSkipRoots = heavyweightRecoverySnapshotSkipRoots(
                appSupportURL: appSupportURL,
                searchDatabaseURL: defaultSearchDatabaseURL(appSupportURL: appSupportURL)
            )
            try copyDirectoryContents(
                at: appSupportURL,
                to: snapshottedAppSupportURL,
                skipping: sqliteSourceURLs.filter { $0.deletingLastPathComponent() == appSupportURL }
                    + heavyweightSkipRoots
            )

            for databaseURL in sqliteSourceURLs {
                let destinationURL = snapshottedAppSupportURL.appendingPathComponent(databaseURL.lastPathComponent)
                try backupSQLiteDatabaseIfPresent(at: databaseURL, to: destinationURL)
            }
        }

        if let preferencesURL, fm.fileExists(atPath: preferencesURL.path) {
            try fm.copyItem(
                at: preferencesURL,
                to: snapshotURL.appendingPathComponent(preferencesURL.lastPathComponent)
            )
        }

        try pruneRecoverySnapshots(in: snapshotRoot, maxCount: maxCount)
    }

    private func pruneRecoverySnapshotsIfNeeded() {
        pruneAPFSSafetySnapshotsIfNeeded()

        guard let snapshotRoot = recoverySnapshotRootURL(),
              FileManager.default.fileExists(atPath: snapshotRoot.path) else {
            return
        }

        do {
            try Self.pruneRecoverySnapshots(in: snapshotRoot, maxCount: Self.recoverySnapshotLimit)
        } catch {
            log.error("Failed to prune recovery snapshots: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func createAPFSSafetySnapshotIfPossible(reason: String) {
        guard let manifestURL = apfsSnapshotManifestURL() else { return }
        #if EPISTEMOS_APP_STORE
        // The App Store sandbox cannot spawn /usr/bin/tmutil. APFS
        // safety snapshots are an optional Pro/direct maintenance
        // layer on top of the file-copy recovery snapshots, which
        // remain active in MAS. Skip silently here; tests that wire
        // a custom `TMUtilCommandRunner` go through a different code
        // path, so this early return does not affect them.
        if tmutilCommandRunnerOverride == nil { return }
        #endif
        let commandRunner = tmutilCommandRunnerOverride ?? Self.runTMUtilCommand

        Task.detached(priority: .utility) {
            do {
                _ = try Self.createAPFSSafetySnapshot(
                    reason: reason,
                    manifestURL: manifestURL,
                    maxCount: Self.recoverySnapshotLimit,
                    commandRunner: commandRunner
                )
            } catch {
                Self.backgroundLog.error("Failed to create APFS safety snapshot: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func pruneAPFSSafetySnapshotsIfNeeded() {
        guard let manifestURL = apfsSnapshotManifestURL(),
              FileManager.default.fileExists(atPath: manifestURL.path) else {
            return
        }
        #if EPISTEMOS_APP_STORE
        // Same MAS-sandbox rationale as createAPFSSafetySnapshotIfPossible.
        if tmutilCommandRunnerOverride == nil { return }
        #endif
        let commandRunner = tmutilCommandRunnerOverride ?? Self.runTMUtilCommand

        Task.detached(priority: .utility) {
            do {
                try Self.pruneAPFSSnapshotManifest(
                    at: manifestURL,
                    maxCount: Self.recoverySnapshotLimit,
                    commandRunner: commandRunner
                )
            } catch {
                Self.backgroundLog.error("Failed to prune APFS safety snapshots: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private nonisolated static func startupBookmarkValidation(
        bookmarkData: Data?
    ) -> VaultBookmarkStartupValidation {
        guard let bookmarkData else {
            return VaultBookmarkStartupValidation(
                bookmarkExists: false,
                isReadyForAutomaticRestore: true,
                failureReason: nil
            )
        }

        guard let resolvedBookmark = resolveVaultBookmark(bookmarkData) else {
            return makeStartupBookmarkValidation(
                bookmarkExists: true,
                resolvedURL: nil,
                isStale: false,
                usedSecurityScope: false,
                accessGranted: false,
                isReadable: false,
                requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
            )
        }

        let accessGranted: Bool
        if resolvedBookmark.usedSecurityScope {
            accessGranted = resolvedBookmark.url.startAccessingSecurityScopedResource()
            if accessGranted {
                resolvedBookmark.url.stopAccessingSecurityScopedResource()
            }
        } else {
            accessGranted = FileManager.default.isReadableFile(atPath: resolvedBookmark.url.path)
        }

        let isReadable = FileManager.default.fileExists(atPath: resolvedBookmark.url.path)
            && FileManager.default.isReadableFile(atPath: resolvedBookmark.url.path)

        return makeStartupBookmarkValidation(
            bookmarkExists: true,
            resolvedURL: resolvedBookmark.url,
            isStale: resolvedBookmark.isStale,
            usedSecurityScope: resolvedBookmark.usedSecurityScope,
            accessGranted: accessGranted,
            isReadable: isReadable,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
        )
    }

    private nonisolated static func makeStartupBookmarkValidation(
        bookmarkExists: Bool,
        resolvedURL: URL?,
        isStale: Bool,
        usedSecurityScope: Bool,
        accessGranted: Bool,
        isReadable: Bool,
        requiresSecurityScopedVaultAccess: Bool
    ) -> VaultBookmarkStartupValidation {
        guard bookmarkExists else {
            return VaultBookmarkStartupValidation(
                bookmarkExists: false,
                isReadyForAutomaticRestore: true,
                failureReason: nil
            )
        }

        guard resolvedURL != nil else {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark could not be resolved."
            )
        }

        if isStale {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is stale and must be re-selected."
            )
        }

        if requiresSecurityScopedVaultAccess && !usedSecurityScope {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is not security-scoped and must be re-selected."
            )
        }

        if requiresSecurityScopedVaultAccess && !accessGranted {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark lost security-scoped access."
            )
        }

        if usedSecurityScope && !accessGranted {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark lost security-scoped access."
            )
        }

        if !isReadable {
            return VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark points to a missing or unreadable directory."
            )
        }

        return VaultBookmarkStartupValidation(
            bookmarkExists: true,
            isReadyForAutomaticRestore: true,
            failureReason: nil
        )
    }

    private nonisolated static func vaultWatchStartAllowed(
        scopeAlreadyAcquired: Bool,
        accessGranted: Bool,
        requiresSecurityScopedVaultAccess: Bool
    ) -> Bool {
        scopeAlreadyAcquired || accessGranted || !requiresSecurityScopedVaultAccess
    }

    private func sqliteDatabaseURLsForSnapshot() -> [URL] {
        var urls: [URL] = []
        if let appSupportURL = appSupportDirectoryURL() {
            urls.append(appSupportURL.appendingPathComponent("event-store.sqlite"))
        }
        var seenPaths = Set<String>()
        return urls.filter { seenPaths.insert($0.standardizedFileURL.path).inserted }
    }

    private nonisolated static func defaultSearchDatabaseURL(appSupportURL: URL) -> URL {
        appSupportURL.appendingPathComponent("search.sqlite")
    }

    private nonisolated static func heavyweightRecoverySnapshotSkipRoots(
        appSupportURL: URL?,
        searchDatabaseURL: URL?
    ) -> [URL] {
        guard let appSupportURL else { return [] }
        var urls = [
            appSupportURL.appendingPathComponent("default.store"),
            appSupportURL.appendingPathComponent("default.store-wal"),
            appSupportURL.appendingPathComponent("default.store-shm"),
            appSupportURL.appendingPathComponent("note-bodies", isDirectory: true),
            appSupportURL.appendingPathComponent("Models", isDirectory: true),
            appSupportURL.appendingPathComponent("ssm_cache", isDirectory: true),
            appSupportURL.appendingPathComponent("runtime_diagnostics", isDirectory: true),
            appSupportURL.appendingPathComponent("style-cache", isDirectory: true),
        ]
        if let searchDatabaseURL {
            urls.append(searchDatabaseURL)
        }
        return urls
    }

    private nonisolated static func copyDirectoryContents(
        at sourceDirectoryURL: URL,
        to destinationDirectoryURL: URL,
        skipping skippedRootURLs: [URL]
    ) throws {
        let fm = FileManager.default
        let skippedPaths = Set(
            skippedRootURLs.flatMap { url in
                sqliteCompanionURLs(for: url).map(\.standardizedFileURL.path)
            }
        )
        let skippedRootPaths = Set(skippedRootURLs.map(\.standardizedFileURL.path))

        func isSkipped(_ url: URL) -> Bool {
            let path = url.standardizedFileURL.path
            if skippedPaths.contains(path) || skippedRootPaths.contains(path) {
                return true
            }
            return skippedRootPaths.contains { path.hasPrefix($0 + "/") }
        }

        try fm.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
        guard let enumerator = fm.enumerator(
            at: sourceDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }

        while let itemURL = enumerator.nextObject() as? URL {
            if isSkipped(itemURL) {
                enumerator.skipDescendants()
                continue
            }
            let standardizedPath = itemURL.standardizedFileURL.path
            let relativePath = String(standardizedPath.dropFirst(sourceDirectoryURL.standardizedFileURL.path.count + 1))
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let destinationURL = destinationDirectoryURL.appendingPathComponent(
                relativePath,
                isDirectory: resourceValues.isDirectory == true
            )

            if resourceValues.isDirectory == true {
                try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: itemURL, to: destinationURL)
            }
        }
    }

    private nonisolated static func sqliteCompanionURLs(for databaseURL: URL) -> [URL] {
        [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
        ]
    }

    private nonisolated static func replaceFileCopy(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private nonisolated static func isSQLiteDatabaseFile(at url: URL) -> Bool {
        guard let data = mappedFileData(at: url, label: "SQLite signature probe"),
              data.count >= 16 else {
            return false
        }

        return Array(data.prefix(16)) == Array("SQLite format 3\u{0}".utf8)
    }

    nonisolated static func backupSQLiteDatabaseIfPresent(at sourceURL: URL, to destinationURL: URL) throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return
        }

        guard isSQLiteDatabaseFile(at: sourceURL) else {
            try replaceFileCopy(from: sourceURL, to: destinationURL)
            return
        }

        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let sourceDB else {
            throw sqliteBackupError(
                domain: "VaultSyncService.SQLiteBackup.OpenSource",
                code: -1,
                databaseURL: sourceURL,
                db: sourceDB
            )
        }
        defer { sqlite3_close(sourceDB) }

        var destinationDB: OpaquePointer?
        guard sqlite3_open_v2(
            destinationURL.path,
            &destinationDB,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let destinationDB else {
            throw sqliteBackupError(
                domain: "VaultSyncService.SQLiteBackup.OpenDestination",
                code: -1,
                databaseURL: destinationURL,
                db: destinationDB
            )
        }
        defer { sqlite3_close(destinationDB) }

        sqlite3_busy_timeout(sourceDB, 1_000)
        sqlite3_busy_timeout(destinationDB, 1_000)

        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw sqliteBackupError(
                domain: "VaultSyncService.SQLiteBackup.Init",
                code: Int(sqlite3_errcode(destinationDB)),
                databaseURL: sourceURL,
                db: destinationDB
            )
        }
        defer { sqlite3_backup_finish(backup) }

        var resultCode: Int32
        repeat {
            resultCode = sqlite3_backup_step(backup, 128)
            if resultCode == SQLITE_OK || resultCode == SQLITE_BUSY || resultCode == SQLITE_LOCKED {
                sqlite3_sleep(25)
            }
        } while resultCode == SQLITE_OK || resultCode == SQLITE_BUSY || resultCode == SQLITE_LOCKED

        guard resultCode == SQLITE_DONE else {
            throw sqliteBackupError(
                domain: "VaultSyncService.SQLiteBackup.Step",
                code: Int(resultCode),
                databaseURL: sourceURL,
                db: destinationDB
            )
        }
    }

    private nonisolated static func sqliteBackupError(
        domain: String,
        code: Int,
        databaseURL: URL,
        db: OpaquePointer?
    ) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite backup error"
        return NSError(
            domain: domain,
            code: code,
            userInfo: [
                NSFilePathErrorKey: databaseURL.path,
                NSLocalizedDescriptionKey: "\(message) (\(databaseURL.lastPathComponent))",
            ]
        )
    }

    private nonisolated static func pruneRecoverySnapshots(in rootURL: URL, maxCount: Int) throws {
        guard maxCount >= 0 else { return }

        let entries = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let directories = try entries.filter { entryURL in
            try entryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }
        let sortedDirectories = directories.sorted { $0.lastPathComponent > $1.lastPathComponent }

        for directoryURL in sortedDirectories.dropFirst(maxCount) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    nonisolated static func pruneRecoverySnapshotsForTesting(at rootURL: URL, maxCount: Int) throws {
        try pruneRecoverySnapshots(in: rootURL, maxCount: maxCount)
    }

    private nonisolated static func runTMUtilCommand(_ arguments: [String]) throws -> String {
        #if !EPISTEMOS_APP_STORE
        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "VaultSyncService.TMUtil",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: errorOutput.isEmpty ? output : errorOutput,
                ]
            )
        }

        return output
        #else
        // The App Store sandbox cannot spawn /usr/bin/tmutil. APFS
        // safety snapshots are a Pro/direct maintenance feature, not
        // part of core vault sync; `createAPFSSafetySnapshotIfPossible`
        // and `pruneAPFSSafetySnapshotsIfNeeded` early-return under
        // EPISTEMOS_APP_STORE before reaching this helper, so this
        // throw is defense-in-depth in case a future caller wires up
        // a path that bypasses those guards. Tests that need real
        // tmutil semantics inject a custom `TMUtilCommandRunner` via
        // `setTMUtilCommandRunnerForTesting` and never hit this branch.
        _ = arguments
        throw NSError(
            domain: "VaultSyncService.TMUtil",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "tmutil is not available in the App Store sandbox build; APFS safety snapshots are skipped.",
            ]
        )
        #endif
    }

    private nonisolated static func parseAPFSSnapshotID(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "com.apple.TimeMachine."
        let suffix = ".local"
        guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(suffix) else {
            return nil
        }
        return String(trimmed.dropFirst(prefix.count).dropLast(suffix.count))
    }

    private nonisolated static func listAPFSSnapshotIDs(
        commandRunner: TMUtilCommandRunner
    ) throws -> Set<String> {
        let output = try commandRunner(["listlocalsnapshots", "/"])
        return Set(
            output
                .split(separator: "\n")
                .compactMap { parseAPFSSnapshotID(from: String($0)) }
        )
    }

    private nonisolated static func loadAPFSSnapshotManifest(at manifestURL: URL) throws -> [APFSSnapshotRecord] {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode([APFSSnapshotRecord].self, from: data)
    }

    private nonisolated static func saveAPFSSnapshotManifest(
        _ manifest: [APFSSnapshotRecord],
        at manifestURL: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private nonisolated static func createAPFSSafetySnapshot(
        reason: String,
        manifestURL: URL,
        maxCount: Int,
        commandRunner: TMUtilCommandRunner
    ) throws -> [String] {
        let before = try listAPFSSnapshotIDs(commandRunner: commandRunner)
        _ = try commandRunner(["localsnapshot"])
        let after = try listAPFSSnapshotIDs(commandRunner: commandRunner)
        let createdSnapshotIDs = Array(after.subtracting(before)).sorted()

        guard !createdSnapshotIDs.isEmpty else {
            return []
        }

        var manifest = try loadAPFSSnapshotManifest(at: manifestURL)
        let existingSnapshotIDs = Set(manifest.map(\.snapshotID))
        let createdAt = Date()
        for snapshotID in createdSnapshotIDs where !existingSnapshotIDs.contains(snapshotID) {
            manifest.append(
                APFSSnapshotRecord(
                    snapshotID: snapshotID,
                    createdAt: createdAt,
                    reason: reason
                )
            )
        }
        try saveAPFSSnapshotManifest(manifest, at: manifestURL)
        try pruneAPFSSnapshotManifest(at: manifestURL, maxCount: maxCount, commandRunner: commandRunner)
        return createdSnapshotIDs
    }

    private nonisolated static func pruneAPFSSnapshotManifest(
        at manifestURL: URL,
        maxCount: Int,
        commandRunner: TMUtilCommandRunner
    ) throws {
        guard maxCount >= 0 else { return }

        let manifest = try loadAPFSSnapshotManifest(at: manifestURL)
        guard manifest.count > maxCount else {
            return
        }

        let sortedManifest = manifest.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.snapshotID < $1.snapshotID
            }
            return $0.createdAt < $1.createdAt
        }
        let snapshotIDsToDelete = sortedManifest.prefix(sortedManifest.count - maxCount).map(\.snapshotID)

        for snapshotID in snapshotIDsToDelete {
            _ = try commandRunner(["deletelocalsnapshots", snapshotID])
        }

        let remainingSnapshotIDs = Set(sortedManifest.suffix(maxCount).map(\.snapshotID))
        let remainingManifest = sortedManifest.filter { remainingSnapshotIDs.contains($0.snapshotID) }
        try saveAPFSSnapshotManifest(remainingManifest, at: manifestURL)
    }

    nonisolated static func createAPFSSafetySnapshotForTesting(
        reason: String,
        manifestURL: URL,
        maxCount: Int,
        commandRunner: @escaping TMUtilCommandRunner
    ) throws -> [String] {
        try createAPFSSafetySnapshot(
            reason: reason,
            manifestURL: manifestURL,
            maxCount: maxCount,
            commandRunner: commandRunner
        )
    }

    nonisolated static func readAPFSSnapshotManifestForTesting(manifestURL: URL) throws -> [String] {
        try loadAPFSSnapshotManifest(at: manifestURL)
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.snapshotID < $1.snapshotID
                }
                return $0.createdAt < $1.createdAt
            }
            .map(\.snapshotID)
    }

    nonisolated static func writeAPFSSnapshotManifestForTesting(
        snapshotIDs: [String],
        reasons: [String: String],
        manifestURL: URL
    ) throws {
        let manifest = snapshotIDs.enumerated().map { index, snapshotID in
            APFSSnapshotRecord(
                snapshotID: snapshotID,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                reason: reasons[snapshotID] ?? "test"
            )
        }
        try saveAPFSSnapshotManifest(manifest, at: manifestURL)
    }

    private nonisolated static func resolveVaultBookmark(_ bookmarkData: Data) -> ResolvedVaultBookmark? {
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedVaultBookmark(url: resolvedURL, isStale: isStale, usedSecurityScope: true)
        } catch {
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return ResolvedVaultBookmark(url: resolvedURL, isStale: isStale, usedSecurityScope: false)
            } catch {
                return nil
            }
        }
    }

    private nonisolated static func resolveVaultBookmarkWithTimeout(
        _ bookmarkData: Data,
        timeout: Duration = .seconds(5)
    ) async throws -> ResolvedVaultBookmark {
        try await withThrowingTaskGroup(of: ResolvedVaultBookmark.self) { group in
            group.addTask {
                guard let resolved = resolveVaultBookmark(bookmarkData) else {
                    throw VaultBookmarkResolutionError.corrupted
                }
                return resolved
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw VaultBookmarkResolutionError.timedOut
            }

            guard let result = try await group.next() else {
                throw VaultBookmarkResolutionError.timedOut
            }
            group.cancelAll()
            return result
        }
    }

    private func clearDerivedLocalStateForRecovery() async {
        clearVaultData()
        sanitizeTransientSelectionsForVaultRebuild()
        ambientManifest = nil
        AppBootstrap.shared?.ambientManifest = nil
        await clearLocalFilesystemStateOffMain()
    }

    private func localFilesystemStateTargets() -> LocalFilesystemStateTargets {
        let appSupportURL = appSupportDirectoryURL()
        return LocalFilesystemStateTargets(
            noteBodiesURL: NoteFileStorage.storageDirectory(),
            searchDatabaseURL: defaultSearchDatabaseURL(),
            styleCacheURL: appSupportURL?.appendingPathComponent("style-cache", isDirectory: true)
        )
    }

    private func clearLocalFilesystemState() {
        Self.clearLocalFilesystemState(localFilesystemStateTargets())
    }

    private func clearLocalFilesystemStateOffMain() async {
        let targets = localFilesystemStateTargets()
        await Task.detached(priority: .utility) {
            Self.clearLocalFilesystemState(targets)
        }.value
    }

    private nonisolated static func clearLocalFilesystemState(_ targets: LocalFilesystemStateTargets) {
        _ = NoteFileStorage.removeAllManagedBodies(in: targets.noteBodiesURL)
        clearSearchIndexFiles(at: targets.searchDatabaseURL)
        clearDerivedFilesystemCaches(at: targets.styleCacheURL)
    }

    private nonisolated static func clearSearchIndexFiles(at databaseURL: URL?) {
        guard let databaseURL else { return }
        let fm = FileManager.default
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-wal"),
        ]
        for url in urls where fm.fileExists(atPath: url.path) {
            removeItemIfPresent(at: url, label: "search index file")
        }
    }

    private nonisolated static func clearDerivedFilesystemCaches(at styleCacheURL: URL?) {
        let fm = FileManager.default
        if let styleCacheURL,
           fm.fileExists(atPath: styleCacheURL.path) {
            recreateDirectory(at: styleCacheURL, label: "style cache directory")
        }
    }

    private func sanitizeTransientSelectionsForVaultRebuild() {
        AppBootstrap.shared?.notesUI.resetForVaultSwitch()
        NoteWindowManager.shared.resetForVaultRebuild()
        if let graphState = AppBootstrap.shared?.graphState {
            graphState.selectNode(nil)
            graphState.selectedNodeScreenPoint = nil
        }
    }

    private func schedulePostImportMaintenance(vaultURL: URL, bookmarkExists: Bool, restoreFailed: Bool) async {
        initialImportCompleted = true
        let issue = await detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed
        )
        recoveryIssue = issue
        guard issue == nil else { return }

        publishVaultMutation(.vaultChanged)
        AppBootstrap.shared?.refreshAmbientManifest()
        AppBootstrap.shared?.scheduleHealthyVaultBodyCleanup()
        scheduleGraphRefreshAfterVaultImport()
    }

    private func scheduleGraphRefreshAfterVaultImport() {
        Task { @MainActor [weak self] in
            await self?.refreshGraphAfterVaultImport()
        }
    }

    private func refreshGraphAfterVaultImport() async {
        guard let bootstrap = AppBootstrap.shared else { return }
        let graphState = bootstrap.graphState
        graphState.needsRefresh = true
        graphState.shouldSnapNextGlobalRecommitCamera = true

        if !graphState.isLoaded {
            await graphState.loadGraph(container: modelContainer)
            return
        }

        let refreshed = await graphState.refreshStructuralDataAsync(
            container: modelContainer
        )
        if !refreshed {
            graphState.requestRecommit()
        }
    }

    private func handleRestoreFailure(
        reason: String,
        bookmarkExists: Bool
    ) {
        isIndexing = false
        vaultActivityMessage = nil
        initialImportCompleted = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            let issue = await self.detectRecoveryIssue(
                candidateVaultURL: nil,
                bookmarkExists: bookmarkExists,
                restoreFailed: true
            )
            if let issue {
                self.recoveryIssue = issue
            } else {
                self.recoveryIssue = nil
                self.clearVaultData()
            }
            log.warning("\(reason, privacy: .public)")
        }
    }

    private nonisolated static func suspiciousVaultRestoreReconfirmationReason(
        resolvedURL: URL,
        assessment: VaultIndexActor.VaultFolderSelectionAssessment,
        trustedSuspiciousVaultPath: String?
    ) -> String? {
        guard assessment.shouldConfirmSelection else { return nil }
        let standardizedPath = resolvedURL.standardizedFileURL.path
        guard trustedSuspiciousVaultPath == standardizedPath else {
            return """
            Saved vault folder must be confirmed again before automatic restore. \
            \(assessment.confirmationMessage)
            """
        }
        return nil
    }

    // MARK: - Lifecycle

    /// Restore vault from saved bookmark on app launch.
    /// Call from RootView.onAppear (after NSApp is alive).
    func restoreVaultFromBookmark() async {
        pruneRecoverySnapshotsIfNeeded()

        guard Self.shouldRestoreVaultFromBookmark() else {
            isIndexing = false
            vaultActivityMessage = nil
            if Self.isRunningTests || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                log.info("Skipping vault bookmark restore under tests")
            } else {
                log.info("Skipping vault bookmark restore via environment override")
            }
            return
        }

        let interval = Log.vaultPerf.beginInterval("restoreVaultFromBookmark")
        defer { Log.vaultPerf.endInterval("restoreVaultFromBookmark", interval) }

        // Migration: check old domains for vault bookmark data.
        // 1. Brainiac.epistemos (rename session stored "epistemos.vaultBookmark" there)
        // 2. com.lucid.app (v2 stored "epistemos.vaultBookmark" there)
        // After bundle ID reverted to Brainiac.lucid-v3, those domains are orphaned.
        var data = defaults.data(forKey: Self.bookmarkKey)
        if let data {
            log.info("📦 Vault bookmark found in current domain (\(data.count) bytes)")
        } else {
            log.info("📦 No vault bookmark in current domain — checking migration sources")
            let migrations: [(suite: String, key: String)] = [
                ("Brainiac.epistemos", "epistemos.vaultBookmark"),
                ("com.lucid.app", "epistemos.vaultBookmark"),
            ]
            for (suite, key) in migrations {
                if let oldSuite = UserDefaults(suiteName: suite) {
                    let oldData = oldSuite.data(forKey: key)
                    log.info(
                        "📦 Checking \(suite, privacy: .public)/\(key, privacy: .public): \(oldData.map { "\($0.count) bytes" } ?? "nil", privacy: .public)"
                    )
                    if let oldData {
                        data = oldData
                        defaults.set(oldData, forKey: Self.bookmarkKey)
                        oldSuite.removeObject(forKey: key)
                        log.info(
                            "📦 Migrated vault bookmark from \(suite, privacy: .public) (\(oldData.count) bytes)"
                        )
                        break
                    }
                } else {
                    log.info("📦 Could not open suite \(suite, privacy: .public)")
                }
            }
        }
        guard let data else {
            log.info("📦 No bookmark data found anywhere")
            handleRestoreFailure(
                reason: "Vault bookmark missing on launch",
                bookmarkExists: false
            )
            return
        }
        log.info("📦 Resolving bookmark (\(data.count) bytes)")
        let resolvedBookmark: ResolvedVaultBookmark
        do {
            resolvedBookmark = try await Self.resolveVaultBookmarkWithTimeout(data)
        } catch VaultBookmarkResolutionError.timedOut {
            handleRestoreFailure(
                reason: "Vault bookmark resolution timed out — please reattach the vault folder",
                bookmarkExists: true
            )
            return
        } catch {
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "📦 Failed to resolve vault bookmark",
                bookmarkExists: true
            )
            return
        }
        let url = resolvedBookmark.url
        let isStale = resolvedBookmark.isStale
        let usedSecurityScope = resolvedBookmark.usedSecurityScope
        log.info(
            "📦 Resolved bookmark → \(url.path, privacy: .private) (stale=\(isStale), securityScope=\(usedSecurityScope))"
        )

        if requiresSecurityScopedVaultAccess() && !usedSecurityScope {
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "Saved vault bookmark is not security-scoped and must be re-selected",
                bookmarkExists: true
            )
            return
        }

        // Start security-scoped access and keep it — do NOT release before startWatching.
        // Security-scoped access is reference-counted; releasing then re-acquiring creates
        // a window where the scope is lost and background actors can't read files.
        let gained: Bool
        if usedSecurityScope {
            gained = startSecurityScopedAccess(for: url)
        } else {
            // No security scope needed — bookmark resolved without it (non-sandboxed).
            // Create a fresh security-scoped bookmark so future launches work cleanly.
            gained = FileManager.default.isReadableFile(atPath: url.path)
            if gained {
                do {
                    let fresh = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    defaults.set(fresh, forKey: Self.bookmarkKey)
                    log.info("Created fresh security-scoped bookmark for vault")
                } catch {
                    log.error(
                        "Failed to create fresh security-scoped bookmark for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
        if !gained {
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "Security scope not granted for vault bookmark",
                bookmarkExists: true
            )
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        if !exists {
            url.stopAccessingSecurityScopedResource()
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "Vault directory not found at \(url.path)",
                bookmarkExists: true
            )
            return
        }

        if isStale {
            do {
                let fresh = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                defaults.set(fresh, forKey: Self.bookmarkKey)
            } catch {
                log.error(
                    "Failed to refresh stale vault bookmark for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                if requiresSecurityScopedVaultAccess() {
                    if usedSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                    defaults.removeObject(forKey: Self.bookmarkKey)
                    handleRestoreFailure(
                        reason: "Saved vault bookmark is stale and could not be refreshed; please reattach the vault folder",
                        bookmarkExists: true
                    )
                    return
                }
            }
        }

        let trustedSuspiciousVaultPath = defaults.string(forKey: Self.trustedSuspiciousVaultPathKey)
        let selectionAssessment = await Task.detached(priority: .utility) {
            VaultIndexActor.vaultFolderSelectionAssessment(for: url)
        }.value
        if let reason = Self.suspiciousVaultRestoreReconfirmationReason(
            resolvedURL: url,
            assessment: selectionAssessment,
            trustedSuspiciousVaultPath: trustedSuspiciousVaultPath
        ) {
            if usedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            defaults.removeObject(forKey: Self.bookmarkKey)
            defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
            handleRestoreFailure(
                reason: reason,
                bookmarkExists: false
            )
            return
        }

        // Pass scopeAlreadyAcquired=true so startWatching doesn't double-acquire.
        // Skip the optimistic manifest rebuild here; post-import maintenance will
        // refresh it once the restored vault snapshot is authoritative.
        startWatching(
            vaultURL: url,
            scopeAlreadyAcquired: true,
            refreshAmbientManifestImmediately: false
        )
    }

    /// Start watching a vault directory. Performs initial import, then watches for changes.
    /// - Parameter scopeAlreadyAcquired: If true, the caller has already called
    ///   `startAccessingSecurityScopedResource()` — we track it but don't call again.
    func startWatching(
        vaultURL: URL,
        scopeAlreadyAcquired: Bool = false,
        refreshAmbientManifestImmediately: Bool = true
    ) {
        let interval = Log.vaultPerf.beginInterval("startWatching")
        defer { Log.vaultPerf.endInterval("startWatching", interval) }

        // If already watching, stop first (allows re-selection of vault folder)
        if isWatching {
            stopWatching()
        }
        _ = beginWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: scopeAlreadyAcquired,
            refreshAmbientManifestImmediately: refreshAmbientManifestImmediately
        )
    }

    @discardableResult
    func switchToVaultAsync(
        vaultURL: URL,
        scopeAlreadyAcquired: Bool = false,
        refreshAmbientManifestImmediately: Bool = true
    ) async -> Bool {
        let interval = Log.vaultPerf.beginInterval("switchToVaultAsync")
        defer { Log.vaultPerf.endInterval("switchToVaultAsync", interval) }

        // Already watching this exact vault — no-op
        if isWatching,
           let current = self.vaultURL,
           current.standardizedFileURL == vaultURL.standardizedFileURL {
            return true
        }

        var beginScopeAlreadyAcquired = scopeAlreadyAcquired
        var acquiredCandidateSecurityScope = false
        if isWatching,
           !scopeAlreadyAcquired,
           requiresSecurityScopedVaultAccess() {
            let gained = startSecurityScopedAccess(for: vaultURL)
            guard gained else {
                isIndexing = false
                recoveryIssue = nil
                log.error(
                    "Security scope not granted for candidate vault \(vaultURL.path, privacy: .public); keeping current vault active"
                )
                return false
            }
            beginScopeAlreadyAcquired = true
            acquiredCandidateSecurityScope = true
        }

        if isWatching {
            let didClear = await stopWatchingAsync(preserveData: false)
            guard didClear else {
                if acquiredCandidateSecurityScope {
                    vaultURL.stopAccessingSecurityScopedResource()
                }
                return false
            }
        } else {
            let didClear = await clearDisconnectedDerivedLocalStateBeforeVaultSwitchIfNeeded()
            guard didClear else {
                return false
            }
        }

        return beginWatching(
            vaultURL: vaultURL,
            scopeAlreadyAcquired: beginScopeAlreadyAcquired,
            refreshAmbientManifestImmediately: refreshAmbientManifestImmediately
        )
    }

    private func beginWatching(
        vaultURL: URL,
        scopeAlreadyAcquired: Bool,
        refreshAmbientManifestImmediately: Bool
    ) -> Bool {
        // No clearVaultData() here — incremental import handles stale data.
        // clearVaultData() is only called in stopWatching() (vault switch)
        // and restoreVaultFromBookmark() failure paths.

        let accessGranted: Bool
        if scopeAlreadyAcquired {
            isSecurityScoped = true
            accessGranted = true
        } else {
            // Start security-scoped access (required for sandboxed apps)
            let gained = startSecurityScopedAccess(for: vaultURL)
            if gained {
                isSecurityScoped = true
            }
            log.info("Security scope acquired: \(gained)")
            accessGranted = gained
        }

        guard Self.vaultWatchStartAllowed(
            scopeAlreadyAcquired: scopeAlreadyAcquired,
            accessGranted: accessGranted,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
        ) else {
            if isSecurityScoped {
                vaultURL.stopAccessingSecurityScopedResource()
                isSecurityScoped = false
            }
            isIndexing = false
            recoveryIssue = nil
            log.error("Security scope not granted for sandbox-required vault start at \(vaultURL.path, privacy: .public)")
            return false
        }

        self.vaultURL = vaultURL
        self.isWatching = true
        self.initialImportCompleted = false
        self.recoveryIssue = nil
        self.ambientManifest = nil
        AppBootstrap.shared?.ambientManifest = nil
        defaults.set(vaultURL.path, forKey: Self.lastVaultPathKey)

        // Create background indexer
        indexActor = VaultIndexActor(modelContainer: modelContainer)

        // Create FTS5 search index
        do {
            let svc = try SearchIndexService(databaseURL: searchDatabaseURLOverride)
            self.searchService = svc
            AppBootstrap.shared?.queryEngine.invalidateRuntime()
        } catch {
            log.error("Failed to create SearchIndexService: \(error.localizedDescription, privacy: .public)")
        }

        // Initial vault import
        let actor = indexActor
        let url = vaultURL
        let svc = searchService
        isIndexing = true
        beginVaultImportProgress(vaultName: vaultURL.lastPathComponent, phase: "Loading vault \"\(vaultURL.lastPathComponent)\"")
        let expectedVaultPath = vaultURL.standardizedFileURL.path
        let progressHandler: VaultIndexActor.VaultImportProgressHandler = { snapshot in
            await VaultImportProgressBridge.publish(snapshot, expectedVaultPath: expectedVaultPath)
        }
        importTask = Task {
            let didImport = await Self.performInitialImport(
                actor: actor,
                url: url,
                searchService: svc,
                progressHandler: progressHandler
            )
            if didImport {
                await self.schedulePostImportMaintenance(
                    vaultURL: url,
                    bookmarkExists: true,
                    restoreFailed: false
                )
                AppBootstrap.shared?.uiState.showToast(
                    "Vault loaded: \(url.lastPathComponent)",
                    type: .success
                )
            } else {
                AppBootstrap.shared?.uiState.showToast(
                    "Couldn't load vault \"\(url.lastPathComponent)\".",
                    type: .error
                )
            }
            self.finishVaultImportProgress(keepSummary: didImport)
            self.vaultActivityMessage = nil
            self.isIndexing = false
        }


        if let actor = indexActor {
            Task(priority: .utility) {
                await actor.migrateToHybridSync()
                await actor.migrateFromExternalStorage()
            }
        }
        restartAutoSaveTimer()
        applyPowerMode(PowerGuard.shared.currentMode)
        startFileWatcher()

        if refreshAmbientManifestImmediately {
            // Build ambient manifest optimistically for interactive vault picks.
            // Launch-time bookmark restore skips this to avoid duplicate startup work.
            AppBootstrap.shared?.refreshAmbientManifest()
        }

        log.info("VaultSyncService started for: \(vaultURL.lastPathComponent, privacy: .public)")
        return true
    }

    /// Stop watching and release resources.
    /// - Parameter preserveData: When `true`, keeps SwiftData models intact so the
    ///   next launch can do an incremental import (~instant) instead of a full reimport (~13s).
    ///   Pass `false` (default) for vault switches/disconnects to clear stale data.
    func stopWatching(preserveData: Bool = false) {
        prepareToStopWatching()

        var shouldClearLocalData = !preserveData
        if !preserveData {
            do {
                try snapshotLocalState()
            } catch {
                shouldClearLocalData = false
                log.error("Failed to snapshot local state before clear; aborting destructive stop: \(error.localizedDescription, privacy: .public)")
                handleSnapshotFailureBeforeDestructiveClear(error)
            }
            if shouldClearLocalData {
                clearLocalVaultState()
            }
        }

        finalizeStoppedWatching(preserveData: preserveData)
    }

    @discardableResult
    func stopWatchingAsync(preserveData: Bool = false) async -> Bool {
        if preserveData {
            stopWatching(preserveData: true)
            return true
        }

        prepareToStopWatching()

        var didClearLocalData = true
        do {
            try await snapshotLocalStateOffMain()
        } catch {
            didClearLocalData = false
            log.error("Failed to snapshot local state before clear; aborting destructive stop: \(error.localizedDescription, privacy: .public)")
            handleSnapshotFailureBeforeDestructiveClear(error)
        }
        if didClearLocalData {
            await clearLocalVaultStateOffMain()
        }

        finalizeStoppedWatching(preserveData: preserveData)
        return didClearLocalData
    }

    func forceClearDerivedLocalStateForFullReset() async {
        await clearDerivedLocalStateForRecovery()
        dismissRecoveryIssue()
    }

    private func prepareToStopWatching() {
        importTask?.cancel()
        importTask = nil
        autoSaveTask?.cancel()
        autoSaveTask = nil
        versionCaptureTask?.cancel()
        versionCaptureTask = nil
        manifestRefreshTask?.cancel()
        manifestRefreshTask = nil
        stopBackgroundMaintenanceTimers()
        stopFileWatcher()
        indexActor = nil
        searchService = nil
        AppBootstrap.shared?.queryEngine.invalidateRuntime()
        ambientManifest = nil
        AppBootstrap.shared?.ambientManifest = nil
    }

    private func clearLocalVaultState() {
        clearVaultData()
        SpotlightIndexer.removeAll()
        clearLocalFilesystemState()
    }

    private func clearLocalVaultStateOffMain() async {
        clearVaultData()
        SpotlightIndexer.removeAll()
        await clearLocalFilesystemStateOffMain()
    }

    private func finalizeStoppedWatching(preserveData: Bool) {
        if isSecurityScoped, let url = vaultURL {
            url.stopAccessingSecurityScopedResource()
            isSecurityScoped = false
        }

        vaultURL = nil
        isWatching = false
        isIndexing = false
        vaultActivityMessage = nil
        clearVaultImportTelemetry()
        initialImportCompleted = false
        log.info("VaultSyncService stopped (preserveData=\(preserveData))")
    }

    private func clearDisconnectedDerivedLocalStateBeforeVaultSwitchIfNeeded() async -> Bool {
        guard hasDerivedLocalVaultDataForSwitch() else { return true }

        do {
            try await snapshotLocalStateOffMain()
        } catch {
            log.error("Failed to snapshot disconnected local state before vault switch; aborting clear: \(error.localizedDescription, privacy: .public)")
            handleSnapshotFailureBeforeDestructiveClear(error)
            return false
        }

        await clearLocalVaultStateOffMain()
        return true
    }

    private func hasDerivedLocalVaultDataForSwitch() -> Bool {
        let context = modelContainer.mainContext
        let pageCount = fetchCount(
            FetchDescriptor<SDPage>(),
            in: context,
            label: "cached pages before vault switch"
        ) ?? 0
        let folderCount = fetchCount(
            FetchDescriptor<SDFolder>(),
            in: context,
            label: "cached folders before vault switch"
        ) ?? 0
        let graphNodeCount = fetchCount(
            FetchDescriptor<SDGraphNode>(),
            in: context,
            label: "cached graph nodes before vault switch"
        ) ?? 0
        let graphEdgeCount = fetchCount(
            FetchDescriptor<SDGraphEdge>(),
            in: context,
            label: "cached graph edges before vault switch"
        ) ?? 0
        let localBodyCount = managedBodyCountProvider?() ?? NoteFileStorage.managedBodyCount()

        return pageCount > 0
            || folderCount > 0
            || graphNodeCount > 0
            || graphEdgeCount > 0
            || localBodyCount > 0
    }

    /// Delete all vault pages/folders AND graph data from SwiftData.
    /// Called on every vault transition and startup failure to prevent stale ghost data.
    private func clearVaultData() {
        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDBlock.self)
            try context.delete(model: SDPageVersion.self)
            try context.delete(model: SDNoteInsight.self)
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.delete(model: SDGraphNode.self)
            try context.delete(model: SDGraphEdge.self)
            try context.save()
            Log.vault.info("Cleared all vault + graph data from SwiftData")
        } catch {
            Log.vault.error("Failed to clear vault data: \(error.localizedDescription, privacy: .public)")
        }

        AppBootstrap.shared?.clearVaultLifecycleRuntimeState(
            reason: "VaultSyncService cleared local vault data"
        )
    }

    private nonisolated static func performInitialImport(
        actor: VaultIndexActor?,
        url: URL,
        searchService: SearchIndexService?,
        progressHandler: VaultIndexActor.VaultImportProgressHandler? = nil
    ) async -> Bool {
        let importInterval = Log.vaultPerf.beginInterval("initialVaultImport")
        guard let actor else {
            Log.vault.error("Initial vault import failed: no active VaultIndexActor")
            Log.vaultPerf.endInterval("initialVaultImport", importInterval)
            return false
        }

        if let searchService {
            await actor.setSearchService(searchService)
        }
        let importSnapshot: VaultImportProgressSnapshot?
        do {
            importSnapshot = try await actor.importVault(from: url, progress: progressHandler)
            Log.vault.info("Initial vault import complete")

            await MainActor.run {
                AppBootstrap.shared?.graphState.needsRefresh = true
            }

            if let importSnapshot {
                await progressHandler?(importSnapshot.withPhase("Starting background indexes", isComplete: false))
            }
            scheduleSpotlightReindex(from: actor)
            scheduleInstantRecallPostImportUpdate(from: actor, snapshot: importSnapshot)
        } catch {
            Log.vault.error(
                "Initial vault import failed: \(error.localizedDescription, privacy: .public)")
            Log.vaultPerf.endInterval("initialVaultImport", importInterval)
            return false
        }
        Log.vaultPerf.endInterval("initialVaultImport", importInterval)

        scheduleSearchIndexDiffSync(from: actor, searchService: searchService)
        if let importSnapshot {
            await progressHandler?(importSnapshot.withPhase("Vault ready", isComplete: true))
        }
        return true
    }

    private nonisolated static let instantRecallRebuildBodyCharacterLimit = 16_384

    private nonisolated static func scheduleSpotlightReindex(from actor: VaultIndexActor?) {
        guard let actor else { return }
        Task.detached(priority: .utility) {
            await actor.spotlightReindexAll()
        }
    }

    private nonisolated static func scheduleSearchIndexDiffSync(
        from actor: VaultIndexActor?,
        searchService: SearchIndexService?
    ) {
        guard let actor, let searchService else { return }
        Task.detached(priority: .utility) {
            let diffSyncInterval = Log.vaultPerf.beginInterval("initialVaultDiffSync")
            defer { Log.vaultPerf.endInterval("initialVaultDiffSync", diffSyncInterval) }
            let timestamps = await actor.allPageTimestamps()
            do {
                try await searchService.diffSync(
                    swiftDataPages: timestamps,
                    fullPageProvider: { id in await actor.fullPageData(for: id) }
                )
            } catch {
                Log.vault.error("FTS5 diff-sync failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private nonisolated static func scheduleInstantRecallIndexRebuild(from actor: VaultIndexActor?) {
        guard let actor else { return }
        Task.detached(priority: .utility) {
            await rebuildInstantRecallIndex(from: actor)
        }
    }

    private nonisolated static func scheduleInstantRecallPostImportUpdate(
        from actor: VaultIndexActor?,
        snapshot: VaultImportProgressSnapshot?
    ) {
        guard let actor else { return }
        guard let snapshot else {
            scheduleInstantRecallIndexRebuild(from: actor)
            return
        }
        let changedPageIDs: [String]
        let deletedPageIDs: [String]
        switch snapshot.postImportRecallWorkload {
        case .none:
            return
        case .rebuild:
            scheduleInstantRecallIndexRebuild(from: actor)
            return
        case .incremental(let changed, let deleted):
            changedPageIDs = changed
            deletedPageIDs = deleted
        }

        Task.detached(priority: .utility) {
            var changedNotes: [(id: String, text: String)] = []
            changedNotes.reserveCapacity(changedPageIDs.count)
            for pageID in changedPageIDs {
                guard let page = await actor.fullPageData(for: pageID) else { continue }
                changedNotes.append((
                    id: pageID,
                    text: boundedInstantRecallText(
                        title: page.title,
                        body: page.body,
                        tags: page.tags
                    )
                ))
            }

            await MainActor.run {
                guard let service = AppBootstrap.shared?.instantRecallService else { return }
                for pageID in deletedPageIDs {
                    service.removeNote(noteId: pageID)
                }
                for note in changedNotes {
                    service.indexNote(noteId: note.id, text: note.text)
                }
            }
        }
    }

    private nonisolated static func rebuildInstantRecallIndex(from actor: VaultIndexActor?) async {
        guard let actor else { return }
        let pages = await actor.allPagesForRebuild()
        let notes = pages.map { page in
            (
                id: page.id,
                text: boundedInstantRecallText(
                    title: page.title,
                    body: page.body,
                    tags: page.tags
                )
            )
        }
        guard let service = await MainActor.run(body: { AppBootstrap.shared?.instantRecallService }) else {
            return
        }
        await service.rebuildIndexAsync(notes: notes)
    }

    private nonisolated static func boundedInstantRecallText(
        title: String,
        body: String,
        tags: String
    ) -> String {
        let trimmedBody =
            body.count > instantRecallRebuildBodyCharacterLimit
            ? String(body.prefix(instantRecallRebuildBodyCharacterLimit))
            : body
        let trimmedTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTags.isEmpty else {
            return "\(title)\n\n\(trimmedBody)"
        }
        return "\(title)\n\(trimmedTags)\n\n\(trimmedBody)"
    }

    // MARK: - Vault Context (Background)

    /// Search the vault for notes relevant to a chat query and format as context.
    /// Delegates to VaultIndexActor so all disk-heavy body reads run off the main thread.
    func buildVaultContext(for query: String) async -> String? {
        await indexActor?.buildVaultContext(for: query)
    }

    /// Build lightweight ambient manifest (entries only, no bodies).
    func buildAmbientManifest() async -> VaultManifest? {
        await indexActor?.buildAmbientManifest(vaultTitle: canonicalVaultTitle())
    }

    /// Build complete vault manifest with recent bodies (for vault briefing).
    func buildVaultManifest() async -> VaultManifest? {
        await indexActor?.buildVaultManifest(vaultTitle: canonicalVaultTitle())
    }

    /// Fetch full note bodies by ID for @-mention resolution.
    func fetchNoteBodies(ids: [String]) async -> [VaultManifest.NoteBody] {
        await indexActor?.fetchNoteBodies(ids: ids) ?? []
    }

    /// Find notes matching a title query.
    func findNotesByTitle(_ query: String) async -> [VaultManifest.ManifestEntry] {
        await indexActor?.findNotesByTitle(query) ?? []
    }

    /// Search note bodies via FTS5 full-text index. Returns matching page IDs.
    /// Flag-aware: `EPISTEMOS_RRF_FUSION_V1` routes through the fused
    /// path and returns parent doc IDs from the fused entity rollup
    /// (RRF Phase 4 wiring site §6 — AgentRuntime context retrieval +
    /// any caller that just needs the matched IDs).
    func searchIndex(query: String) async -> [String] {
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                let fused = try await svc.fusedSearchAsync(query: query)
                return fused.map(\.parentDocID)
            }
            return try await svc.searchAsync(query: query).map(\.pageId)
        } catch {
            log.error("FTS5 search failed (fusion=\(RRFFusionFlags.isEnabled, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Full-text search with ranked results + snippets. For command palette deep search.
    /// When `EPISTEMOS_RRF_FUSION_V1` is enabled, dispatches through the
    /// fused single-SQL path (RRF Phase 4 wiring site §1 — Landing
    /// search bar, plus all command-palette callers). Translates
    /// `[FusedResult]` → `[SearchResult]` so existing callers stay
    /// source-compatible.
    func searchFull(query: String, limit: Int = 20) -> [SearchResult] {
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                let fused = try svc.fusedSearch(
                    query: query,
                    weights: FusionWeights(maxResults: limit)
                )
                return fused.map(Self.mapFusedToSearchResult)
            }
            return try svc.search(query: query, limit: limit)
        } catch {
            log.error("searchFull failed (fusion=\(RRFFusionFlags.isEnabled, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func searchFullAsync(query: String, limit: Int = 20) async -> [SearchResult] {
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                let fused = try await svc.fusedSearchAsync(
                    query: query,
                    weights: FusionWeights(maxResults: limit)
                )
                return fused.map(Self.mapFusedToSearchResult)
            }
            return try await svc.searchAsync(query: query, limit: limit)
        } catch {
            log.error("searchFullAsync failed (fusion=\(RRFFusionFlags.isEnabled, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Translate a `FusedResult` (RRF Phase 3) into the legacy
    /// `SearchResult` shape so existing callers don't need to change.
    /// `title` is left empty because the fused query doesn't surface
    /// it directly — UI sites that need it look up via the page-id
    /// they already have. Phase 5 perf tests cover round-trip parity.
    nonisolated private static func mapFusedToSearchResult(_ fused: FusedResult) -> SearchResult {
        SearchResult(
            pageId: fused.parentDocID,
            title: "",
            snippet: fused.snippet ?? "",
            rank: fused.fusedScore
        )
    }

    func searchBlocksAsync(query: String, limit: Int = 20) async -> [BlockSearchResult] {
        guard let svc = searchService else { return [] }
        do {
            return try await svc.searchBlocksAsync(query: query, limit: limit)
        } catch {
            return []
        }
    }

    private func canonicalVaultTitle() -> String {
        let rawTitle = vaultURL?.lastPathComponent
            ?? defaults.string(forKey: Self.lastVaultPathKey).map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? Self.defaultRecoveryVaultURL.lastPathComponent
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Vault" : trimmed
    }

    /// Manually trigger a full FTS5 index rebuild.
    /// Called from Settings > Vault > "Rebuild Index" button.
    func rebuildIndex() {
        guard let actor = indexActor, let svc = searchService else { return }
        isIndexing = true
        Task {
            let interval = Log.vaultPerf.beginInterval("rebuildIndex")
            defer { Log.vaultPerf.endInterval("rebuildIndex", interval) }
            let pages = await actor.allPagesForRebuild()
            do {
                try await svc.rebuildFromSwiftDataAsync(pages)
            } catch {
                log.error("FTS5 index rebuild failed: \(error.localizedDescription, privacy: .public)")
            }
            isIndexing = false
        }
    }

    // MARK: - Migration


    // MARK: - Sync from Vault

    /// Pull external .md changes from the vault folder.
    /// Returns conflicts (both sides changed) for the UI to resolve.
    func syncFromVault() async -> [VaultSyncConflict] {
        guard let vaultURL, let actor = indexActor else { return [] }
        let interval = Log.vaultPerf.beginInterval("syncFromVault")
        defer { Log.vaultPerf.endInterval("syncFromVault", interval) }
        isIndexing = true
        beginVaultImportProgress(vaultName: vaultURL.lastPathComponent, phase: "Syncing vault \"\(vaultURL.lastPathComponent)\"")
        defer {
            finishVaultImportProgress(keepSummary: true)
            vaultActivityMessage = nil
            isIndexing = false
        }
        let expectedVaultPath = vaultURL.standardizedFileURL.path
        let progressHandler: VaultIndexActor.VaultImportProgressHandler = { snapshot in
            await VaultImportProgressBridge.publish(snapshot, expectedVaultPath: expectedVaultPath)
        }

        let context = modelContainer.mainContext
        do {
            try context.save()  // Persist latest state
        } catch {
            Log.vault.error("Failed to save before sync-from-vault: \(error.localizedDescription, privacy: .public)")
        }

        // Re-import vault (handles new files + updates)
        do {
            let importSnapshot = try await actor.importVault(from: vaultURL, progress: progressHandler)
            if let importSnapshot {
                await progressHandler(importSnapshot.withPhase("Starting background indexes", isComplete: false))
            }
            Self.scheduleSpotlightReindex(from: actor)
            Self.scheduleInstantRecallPostImportUpdate(from: actor, snapshot: importSnapshot)
            Self.scheduleSearchIndexDiffSync(from: actor, searchService: searchService)

            if let importSnapshot {
                await progressHandler(importSnapshot.withPhase("Vault ready", isComplete: true))
            }
        } catch {
            log.error("Sync import failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        // Signal the graph to rebuild with synced data
        AppBootstrap.shared?.graphState.needsRefresh = true

        let pageCount = await actor.allPageTimestamps().count
        log.info("Sync from vault complete: \(pageCount) pages")
        publishVaultMutation(.vaultChanged)
        return []
    }

    // MARK: - Write Operations

    // MARK: - Explicit Save (Apple Notes Hybrid)

    /// Save a single page to its vault .md file and update sync tracking fields.
    @discardableResult
    func savePage(pageId: String) -> Task<Void, Never>? {
        guard let vaultURL else {
            log.warning("Cannot save page: no vault URL")
            return nil
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard fetchFirst(descriptor, in: context, label: "page save preflight") != nil else {
            return nil
        }

        preparePageForExport(pageId: pageId, context: context)
        scheduleVersionCaptureIfNeeded(pageId: pageId, context: context)

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before page export (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return nil
        }

        suppressFileWatcherForSelfOriginatedChange()

        let task = Task {
            do {
                await NoteFileStorage.flushPendingBodyToDisk(pageId: pageId)
                let exportResult = try await self.exportPage(pageId: pageId, to: vaultURL)

                await MainActor.run {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                    if let result = exportResult,
                       let page = self.fetchFirst(desc, in: context, label: "saved page sync tracking") {
                        let currentHash = SDPage.bodyHash(
                            self.latestAvailableBody(for: page, pageId: pageId)
                        )
                        if currentHash == result.bodyHash {
                            page.lastSyncedBodyHash = currentHash
                            page.lastSyncedAt = .now
                            page.needsVaultSync = false
                            SpotlightIndexer.index(page)
                        } else {
                            page.needsVaultSync = true
                        }
                        do {
                            try context.save()
                        } catch {
                            Log.vault.error("Failed to save sync tracking for page (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }

                if let path = exportResult?.path {
                    log.info("Saved page to vault: \(path, privacy: .private)")
                }

                await MainActor.run { [weak self] in
                    self?.publishVaultMutation(.vaultPageChanged(pageId: pageId))
                }
            } catch {
                log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return task
    }

    private func preparePageForExport(pageId: String, context: ModelContext) {
        NoteFileStorage.requestFlush(pageId: pageId)

        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "page export preparation") else {
            return
        }

        let currentBody = latestAvailableBody(for: page, pageId: pageId)
        guard let stagedBody = NoteFileStorage.stageBodyForImmediateRead(
            pageId: pageId,
            content: currentBody
        ) else { return }
        page.applyInteractiveDerivedState(from: stagedBody)
        page.needsVaultSync = true
        ProseEditorView.syncNoteTitleIfNeeded(
            from: stagedBody,
            for: page,
            modelContext: context
        ) { [weak self] resolvedPageId, newTitle in
            self?.renamePageFile(pageId: resolvedPageId, newTitle: newTitle)
        }
    }

    /// Phase R.3 scope guard: the 4 `page.loadBody` call sites in
    /// `VaultSyncService` are intentionally NOT migrated to
    /// `loadBodyAsync` — they all run on the MainActor inside
    /// synchronous save-path state machines (dirty-page hash
    /// checks, version capture, new-page save tracking) where
    /// lifting to async requires refactoring the entire SaveBatch
    /// coordinator. These sites are write-side bookkeeping (compare
    /// current body vs last-synced hash), not the "6+ duplicate
    /// read codepaths" that I-002 / I-003 describes.
    /// The read-side async cascade in `VaultIndexActor`,
    /// `SpotlightIndexer`, `EntityExtractor`, `GraphState`, and
    /// `CloudKnowledgeDistillationService` now routes through the
    /// R.3 gateway for every read-facing code path.
    private func latestAvailableBody(for page: SDPage, pageId: String) -> String {
        if let liveBody = NoteWindowManager.shared.editorBody(for: pageId) {
            return liveBody
        }
        if !page.body.isEmpty {
            return page.body
        }
        return page.loadBody(mapped: true)
    }

    /// Save all dirty pages to their vault .md files.
    @discardableResult
    func saveAllDirtyPages() -> Task<Void, Never>? {
        if let task = inFlightDirtySaveTask, !task.isCancelled {
            pendingDirtySaveRequest = true
            return task
        }

        guard let initialBatch = nextDirtySaveBatch() else { return nil }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runDirtySaveLoop(startingWith: initialBatch)
        }
        inFlightDirtySaveTask = task
        return task
    }

    private func nextDirtySaveBatch() -> DirtySaveBatch? {
        guard let vaultURL else { return nil }

        let context = modelContainer.mainContext
        let dirtyDescriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.needsVaultSync == true || $0.lastSyncedBodyHash == nil }
        )
        guard let dirtyPages = fetchAll(dirtyDescriptor, in: context, label: "dirty pages"),
              !dirtyPages.isEmpty else {
            log.info("No dirty pages to save")
            return nil
        }

        for page in dirtyPages {
            preparePageForExport(pageId: page.id, context: context)
            scheduleVersionCaptureIfNeeded(pageId: page.id, context: context)
        }

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before dirty pages export: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        return DirtySaveBatch(
            context: context,
            vaultURL: vaultURL,
            dirtyIds: dirtyPages.map(\.id)
        )
    }

    private func runDirtySaveLoop(startingWith initialBatch: DirtySaveBatch) async {
        let interval = Log.vaultPerf.beginInterval("saveAllDirtyPages")
        defer {
            Log.vaultPerf.endInterval("saveAllDirtyPages", interval)
            inFlightDirtySaveTask = nil
            pendingDirtySaveRequest = false
        }

        var currentBatch: DirtySaveBatch? = initialBatch
        while !Task.isCancelled {
            pendingDirtySaveRequest = false
            guard let batch = currentBatch ?? nextDirtySaveBatch() else { return }
            currentBatch = nil

            struct SuccessfulExport {
                let pageId: String
                let bodyHash: String
            }
            var successfulExports: [SuccessfulExport] = []
            successfulExports.reserveCapacity(batch.dirtyIds.count)

            for pageId in batch.dirtyIds {
                do {
                    suppressFileWatcherForSelfOriginatedChange()
                    await NoteFileStorage.flushPendingBodyToDisk(pageId: pageId)
                    if let result = try await exportPage(pageId: pageId, to: batch.vaultURL) {
                        successfulExports.append(SuccessfulExport(pageId: pageId, bodyHash: result.bodyHash))
                    }
                } catch {
                    log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            for export in successfulExports {
                let pid = export.pageId
                let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pid })
                guard let page = fetchFirst(desc, in: batch.context, label: "dirty page sync tracking") else {
                    continue
                }

                let currentHash = SDPage.bodyHash(
                    latestAvailableBody(for: page, pageId: pid)
                )
                if currentHash == export.bodyHash {
                    page.lastSyncedBodyHash = currentHash
                    page.lastSyncedAt = .now
                    page.needsVaultSync = false
                    SpotlightIndexer.index(page)
                    // Ω18: Index synced note for instant recall
                    let body = page.loadBody(mapped: true)
                    AppBootstrap.shared?.instantRecallService.indexNote(noteId: page.id, text: body)
                } else {
                    pendingDirtySaveRequest = true
                }
            }

            do {
                try batch.context.save()
            } catch {
                Log.vault.error("Failed to save sync tracking after dirty pages export: \(error.localizedDescription, privacy: .public)")
            }

            log.info("Saved \(successfulExports.count) of \(batch.dirtyIds.count) dirty pages to vault")

            guard pendingDirtySaveRequest else { return }
        }
    }

    /// Auto-save interval in seconds. 0 = disabled.
    /// Stored property so @Observable tracks it and SwiftUI re-renders on change.
    var autoSaveInterval: TimeInterval = 0 {
        didSet {
            defaults.set(autoSaveInterval, forKey: Self.autoSaveIntervalKey)
            restartAutoSaveTimer()
        }
    }

    /// Start or restart the auto-save timer.
    func restartAutoSaveTimer() {
        autoSaveTask?.cancel()
        autoSaveTask = nil

        let interval = autoSaveInterval
        guard interval > 0, isWatching else { return }

        autoSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard await Self.sleepHandlingCancellation(
                    for: .seconds(interval),
                    label: "auto-save timer"
                ) else { return }
                guard !Task.isCancelled else { return }
                self?.saveAllDirtyPages()
            }
        }
    }

    private func startObservingPowerModeChangesIfNeeded() {
        guard powerModeObserverTask == nil else { return }

        powerModeObserverTask = Task.detached(priority: .utility) { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: PowerGuard.modeDidChangeNotification
            )

            for await notification in stream {
                guard !Task.isCancelled else { break }

                let mode: PowerMode
                if let rawValue = notification.userInfo?[PowerGuard.modeUserInfoKey] as? Int,
                   let observedMode = PowerMode(rawValue: rawValue) {
                    mode = observedMode
                } else {
                    mode = await MainActor.run { PowerGuard.shared.currentMode }
                }

                await MainActor.run { [weak self] in
                    self?.applyPowerMode(mode)
                }
            }
        }
    }

    private func applyPowerMode(_ mode: PowerMode) {
        guard isWatching else { return }

        if mode.disablesBackground {
            stopBackgroundMaintenanceTimers()
            return
        }

        startBackgroundMaintenanceTimers()
    }

    private func startBackgroundMaintenanceTimers() {
        startVersionCaptureTimer()
        startManifestRefreshTimer()
    }

    private func stopBackgroundMaintenanceTimers() {
        versionCaptureTask?.cancel()
        versionCaptureTask = nil
        manifestRefreshTask?.cancel()
        manifestRefreshTask = nil
    }

    func handlePowerModeChangeForTesting(_ mode: PowerMode) {
        applyPowerMode(mode)
    }

    func backgroundMaintenanceTimersStateForTesting() -> (
        versionCaptureActive: Bool,
        manifestRefreshActive: Bool
    ) {
        (
            versionCaptureActive: versionCaptureTask != nil,
            manifestRefreshActive: manifestRefreshTask != nil
        )
    }

    func vaultCoreSyncStateForTesting() -> (
        isWatching: Bool,
        autoSaveActive: Bool,
        fileWatcherActive: Bool
    ) {
        (
            isWatching: isWatching,
            autoSaveActive: autoSaveTask != nil,
            fileWatcherActive: fileWatcherSource != nil
        )
    }

    /// Periodic manifest refresh (5-minute interval) as safety net for external edits.
    private func startManifestRefreshTimer() {
        manifestRefreshTask?.cancel()
        manifestRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard await Self.sleepHandlingCancellation(
                    for: .seconds(300),
                    label: "manifest refresh timer"
                ) else { return }
                guard !Task.isCancelled else { return }
                // Only refresh when the vault has actually mutated since
                // the last refresh. Without this guard the 5-minute timer
                // rebuilt the full ambient manifest forever at idle and
                // churned both CPU and log noise even when nothing had
                // changed. See docs/AGENT_PROGRESS.md 2026-04-19 entry.
                guard let self else { return }
                guard self.vaultMutationEpoch != self.lastManifestRefreshEpoch else {
                    continue
                }
                self.lastManifestRefreshEpoch = self.vaultMutationEpoch
                AppBootstrap.shared?.refreshAmbientManifest()
            }
        }
    }

    /// Emit a vault mutation event AND bump the internal epoch so the
    /// manifest-refresh timer can tell whether anything has actually
    /// changed. Every direct `eventBus?.emit(.vaultChanged)` /
    /// `.vaultPageChanged` call path should go through this helper so
    /// the idle path stays quiet.
    private func publishVaultMutation(_ event: AppEvent) {
        vaultMutationEpoch &+= 1
        AppBootstrap.shared?.graphState.needsRefresh = true
        eventBus?.emit(event)
    }

    /// Exposed to external mutation paths (file watcher) that refresh
    /// the ambient manifest directly without going through
    /// `publishVaultMutation`. Bumps the epoch so the idle-guard in the
    /// periodic timer still sees the change on its next tick.
    func markVaultMutated() {
        vaultMutationEpoch &+= 1
    }

    // MARK: - File System Watcher

    /// Monitor the vault directory for external changes (creates, modifies, deletes, renames).
    /// Uses GCD DispatchSource for efficient kernel-level notifications.
    /// Debounces rapid changes (e.g. editor auto-save) with a 2-second delay.
    private func startFileWatcher() {
        guard let url = vaultURL else { return }
        stopFileWatcher()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            log.warning("File watcher: failed to open vault directory for monitoring")
            return
        }
        fileWatcherFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .link, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleFileSystemChange()
        }

        source.setCancelHandler { [fd] in
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
        log.info("File watcher started for: \(url.lastPathComponent, privacy: .public)")
    }

    private func stopFileWatcher() {
        fileWatchDebounceTask?.cancel()
        fileWatchDebounceTask = nil
        fileWatcherIgnoreUntil = nil
        if let source = fileWatcherSource {
            source.cancel()
            fileWatcherSource = nil
            fileWatcherFD = -1
        }
    }

    private func suppressFileWatcherForSelfOriginatedChange(window: Duration = .seconds(3)) {
        guard isWatching else { return }
        let deadline = fileWatcherClock.now + window
        if let existingDeadline = fileWatcherIgnoreUntil, existingDeadline > deadline {
            return
        }
        fileWatcherIgnoreUntil = deadline
    }

    private func shouldIgnoreFileWatcherChange() -> Bool {
        guard let deadline = fileWatcherIgnoreUntil else { return false }
        let now = fileWatcherClock.now
        if now < deadline {
            return true
        }
        fileWatcherIgnoreUntil = nil
        return false
    }

    /// Debounced handler for file system change events.
    /// Waits 2 seconds after the last change before re-importing, so rapid
    /// saves (e.g. typing in an external editor) don't trigger 50 reimports.
    private func handleFileSystemChange() {
        fileWatchDebounceTask?.cancel()
        // Capture what we need before detaching — avoids @MainActor inheritance
        // so the heavy vault import doesn't block the UI.
        let vaultURL = self.vaultURL
        let actor = self.indexActor
        let searchService = self.searchService
        let shouldIgnore = shouldIgnoreFileWatcherChange()

        fileWatchDebounceTask = Task.detached(priority: .utility) {
            let log = Logger(subsystem: "com.epistemos", category: "VaultSync")
            guard await Self.sleepHandlingCancellation(
                for: .seconds(2),
                label: "file watcher debounce"
            ) else { return }
            guard !Task.isCancelled, let vaultURL, let actor else { return }
            guard !shouldIgnore else {
                log.info("File watcher: skipping self-originated vault change")
                return
            }
            log.info("File watcher: vault changed externally — re-importing")
            do {
                let importSnapshot = try await actor.importVault(from: vaultURL, deleteMissingFiles: false)
                log.info("File watcher: re-import complete")
                VaultSyncService.scheduleInstantRecallPostImportUpdate(from: actor, snapshot: importSnapshot)

                // Hop back to main actor for UI state updates. External
                // vault changes must use the same canonical mutation event as
                // in-app saves so graph/search observers cannot miss new
                // files written outside Epistemos.
                await MainActor.run { [weak vaultSync = AppBootstrap.shared?.vaultSync] in
                    vaultSync?.publishVaultMutation(.vaultChanged)
                    AppBootstrap.shared?.refreshAmbientManifest()
                }

                // Diff-sync FTS5 search index
                if let svc = searchService {
                    let timestamps = await actor.allPageTimestamps()
                    try await svc.diffSync(
                        swiftDataPages: timestamps,
                        fullPageProvider: { id in await actor.fullPageData(for: id) }
                    )
                }
            } catch {
                log.error("File watcher: re-import failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Version Capture

    private nonisolated static let maxVersionsPerPage = 50
    nonisolated static let maxTotalVersions = 10_000

    /// Capture a snapshot of the current page body as a version, if it changed.
    func captureVersionIfNeeded(pageId: String) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "version capture page") else {
            return
        }
        let currentBody = NoteWindowManager.shared.editorBody(for: pageId) ?? page.loadBody()
        guard !currentBody.isEmpty else { return }

        // Check if body actually changed since last version
        let pid = page.id
        var versionDesc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        versionDesc.fetchLimit = 1
        if let latest = fetchFirst(versionDesc, in: context, label: "latest captured version"),
           latest.body == currentBody {
            return
        }

        let version = SDPageVersion(pageId: pageId, title: page.title, body: currentBody, wordCount: page.wordCount)
        context.insert(version)
        do {
            try context.save()
        } catch {
            context.delete(version)
            Log.vault.error("Failed to save captured version for page \(pageId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        log.info("Captured version for page \(pageId.prefix(8))")
        Self.pruneVersions(pageId: pageId, modelContainer: modelContainer)
        pruneVersionsGlobal()
    }

    private func scheduleVersionCaptureIfNeeded(pageId: String, context: ModelContext) {
        guard let snapshot = versionCaptureSnapshot(pageId: pageId, context: context) else { return }
        let modelContainer = modelContainer
        Task.detached(priority: .utility) {
            Self.captureVersionSnapshotIfNeeded(snapshot, modelContainer: modelContainer)
        }
    }

    private func versionCaptureSnapshot(pageId: String, context: ModelContext) -> VersionCaptureSnapshot? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "version capture snapshot page") else {
            return nil
        }
        let currentBody = latestAvailableBody(for: page, pageId: pageId)
        guard !currentBody.isEmpty else { return nil }
        return VersionCaptureSnapshot(
            pageId: pageId,
            title: page.title,
            body: currentBody,
            wordCount: page.wordCount
        )
    }

    private nonisolated static func captureVersionSnapshotIfNeeded(
        _ snapshot: VersionCaptureSnapshot,
        modelContainer: ModelContainer
    ) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let pageId = snapshot.pageId
        var versionDesc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        versionDesc.fetchLimit = 1
        if let latest = fetchBackgroundFirst(
            versionDesc,
            in: context,
            label: "latest background captured version"
        ), latest.body == snapshot.body {
            return
        }

        let version = SDPageVersion(
            pageId: snapshot.pageId,
            title: snapshot.title,
            body: snapshot.body,
            wordCount: snapshot.wordCount
        )
        context.insert(version)
        do {
            try context.save()
        } catch {
            Log.vault.error(
                "Failed to save captured version for page \(snapshot.pageId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        Self.backgroundLog.info("Captured version for page \(snapshot.pageId.prefix(8))")
        pruneVersions(pageId: snapshot.pageId, modelContainer: modelContainer)
        pruneVersionsGlobal(modelContainer: modelContainer)
    }

    /// Keep only the most recent N versions per page.
    private nonisolated static func pruneVersions(pageId: String, modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        var desc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        desc.fetchOffset = Self.maxVersionsPerPage
        guard let old = fetchBackgroundAll(desc, in: context, label: "old page versions"),
              !old.isEmpty else { return }
        for version in old { context.delete(version) }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after pruning versions for page \(pageId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        Self.backgroundLog.info("Pruned \(old.count) old versions for page \(pageId.prefix(8))")
    }

    /// Delete the oldest versions across all pages when total exceeds the global limit.
    /// Called after every per-page prune to keep storage bounded.
    func pruneVersionsGlobal() {
        Self.pruneVersionsGlobal(modelContainer: modelContainer)
    }

    private nonisolated static func pruneVersionsGlobal(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let countDesc = FetchDescriptor<SDPageVersion>()
        guard let totalCount = fetchBackgroundCount(
            countDesc,
            in: context,
            label: "all page versions"
        ),
              totalCount > Self.maxTotalVersions else { return }

        let excess = totalCount - Self.maxTotalVersions
        var oldestDesc = FetchDescriptor<SDPageVersion>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        oldestDesc.fetchLimit = excess
        guard let oldest = fetchBackgroundAll(
            oldestDesc,
            in: context,
            label: "oldest page versions"
        ), !oldest.isEmpty else { return }
        for version in oldest { context.delete(version) }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after global version prune: \(error.localizedDescription, privacy: .public)")
        }
        Self.backgroundLog.info("Global version prune: removed \(oldest.count) oldest versions (total was \(totalCount))")
    }

    /// Start a 10-minute timer that captures versions for all dirty pages.
    private func startVersionCaptureTimer() {
        versionCaptureTask?.cancel()
        versionCaptureTask = Task { [weak self] in
            while !Task.isCancelled {
                guard await Self.sleepHandlingCancellation(
                    for: .seconds(600),
                    label: "version capture timer"
                ) else { return }
                guard !Task.isCancelled, let self else { return }
                self.autoCaptureVersions()
            }
        }
    }

    /// Capture versions for all dirty pages (called by timer).
    private func autoCaptureVersions() {
        let context = modelContainer.mainContext
        let dirtyDescriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.needsVaultSync == true || $0.lastSyncedBodyHash == nil }
        )
        guard let dirtyPages = fetchAll(
            dirtyDescriptor,
            in: context,
            label: "auto-capture dirty pages"
        ),
              !dirtyPages.isEmpty else { return }
        for page in dirtyPages {
            scheduleVersionCaptureIfNeeded(pageId: page.id, context: context)
        }
        log.info("Auto-captured versions for \(dirtyPages.count) dirty pages")
    }

    /// Create a new page in SwiftData and write its .md file.
    /// Returns the page ID for immediate navigation.
    func createPage(
        title: String,
        body: String = "",
        emoji: String = "",
        subfolder: String? = nil,
        allowVaultSelectionPrompt: Bool = false
    )
        async -> String?
    {
        if vaultURL == nil {
            guard allowVaultSelectionPrompt,
                  !Self.isRunningTests,
                  let notesUI = AppBootstrap.shared?.notesUI
            else {
                log.warning("Cannot create page: no vault URL")
                return nil
            }

            let didSelectVault = await VaultConnectionActions.selectVaultFolderForImmediateUse(
                notesUI: notesUI,
                vaultSync: self
            )
            guard didSelectVault else { return nil }
        }

        guard let vaultURL else {
            log.warning("Cannot create page: no vault URL")
            return nil
        }

        let page = SDPage(title: title, emoji: emoji)
        let failedPageId = page.id
        page.saveBody(body)
        page.subfolder = subfolder
        page.wordCount = body.split(separator: " ").count

        // Insert into main context (we're on MainActor)
        let context = modelContainer.mainContext
        context.insert(page)
        BlockMirror.sync(pageId: failedPageId, body: body, modelContext: context)
        do {
            try context.save()  // Explicit save ensures the page is persisted before background export
        } catch {
            context.delete(page)
            let blockDescriptor = FetchDescriptor<SDBlock>(
                predicate: #Predicate<SDBlock> { $0.pageId == failedPageId }
            )
            do {
                let transientBlocks = try context.fetch(blockDescriptor)
                for block in transientBlocks {
                    context.delete(block)
                }
            } catch {
                Log.vault.error(
                    "Failed to clean up transient blocks for new page '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)"
                )
            }
            NoteFileStorage.deleteBody(pageId: failedPageId)
            Log.vault.error("Failed to save new page '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }

        // Index in Spotlight
        SpotlightIndexer.index(page)
        page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody())
        page.lastSyncedAt = .now
        page.needsVaultSync = false

        // Export to disk in background
        let pageId = failedPageId
        suppressFileWatcherForSelfOriginatedChange()
        Task { [weak self] in
            do {
                _ = try await self?.exportPage(pageId: pageId, to: vaultURL)
            } catch {
                log.error(
                    "Failed to export new page to disk: \(error.localizedDescription, privacy: .public)"
                )
            }
            await MainActor.run {
                self?.publishVaultMutation(.vaultChanged)
            }
        }

        return pageId
    }

    // MARK: - Directory Operations

    private func removeVaultItem(at url: URL, label: String) {
        suppressFileWatcherForSelfOriginatedChange()
        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            log.info("Moved \(label, privacy: .public) to Trash: \(url.path, privacy: .private)")
            publishVaultMutation(.vaultChanged)
        } catch {
            do {
                try FileManager.default.removeItem(at: url)
                log.info("Deleted \(label, privacy: .public): \(url.path, privacy: .private)")
                publishVaultMutation(.vaultChanged)
            } catch {
                log.error(
                    "Failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Delete the .md file for a page from the vault.
    /// Called when user deletes a page from the sidebar — prevents orphan resurrection on reimport.
    func deletePageFromDisk(filePath: String?) {
        guard let filePath, FileManager.default.fileExists(atPath: filePath) else { return }
        removeVaultItem(at: URL(fileURLWithPath: filePath), label: "page file")
    }

    /// Delete a physical directory from the vault.
    /// Called when user deletes a folder — prevents folder resurrection on reimport.
    func deleteDirectory(relativePath: String) {
        guard let vaultURL else { return }
        let dirURL = vaultURL.appendingPathComponent(relativePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }
        removeVaultItem(at: dirURL, label: "directory")
    }

    /// Create a physical directory in the vault for an SDFolder.
    /// `relativePath` is the folder's path relative to vault root (e.g. "Projects/2026").
    ///
    /// Returns `true` when the directory exists on disk after this call,
    /// `false` when the FS operation failed (no vault URL, mkdir error, etc.).
    /// Pre-RCA13 callers ignored failures by accident — see the
    /// VaultOrganizer move/create transactional-safety hardening.
    @discardableResult
    func createDirectory(relativePath: String) -> Bool {
        guard let vaultURL else {
            log.warning("Cannot create directory: no vault URL")
            return false
        }
        let dirURL = vaultURL.appendingPathComponent(relativePath, isDirectory: true)
        do {
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            log.info("Created directory: \(relativePath, privacy: .public)")
            return true
        } catch {
            log.error(
                "Failed to create directory \(relativePath, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    /// Rename a page's vault .md file to match a new title.
    /// Call this after updating page.title so the Finder filename stays in sync.
    func renamePageFile(pageId: String, newTitle: String) {
        guard let vaultURL else {
            log.warning("Cannot rename page file: no vault URL")
            return
        }
        let actor = indexActor
        suppressFileWatcherForSelfOriginatedChange()
        Task {
            do {
                try await actor?.renamePageFile(pageId: pageId, newTitle: newTitle, vaultURL: vaultURL)
            } catch {
                log.error("Failed to rename page file: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Rename a directory in the vault. Both paths are relative to vault root.
    ///
    /// Returns `true` on success, `false` if the operation failed (no vault
    /// URL, move error, etc.). See RCA13-P0-001 transactional safety hardening.
    @discardableResult
    func renameDirectory(from oldRelativePath: String, to newRelativePath: String) -> Bool {
        guard let vaultURL else {
            log.warning("Cannot rename directory: no vault URL")
            return false
        }
        let oldURL = vaultURL.appendingPathComponent(oldRelativePath, isDirectory: true)
        let newURL = vaultURL.appendingPathComponent(newRelativePath, isDirectory: true)

        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            // Directory doesn't exist on disk yet — create the new one instead
            return createDirectory(relativePath: newRelativePath)
        }

        do {
            // Ensure parent of new path exists
            let parentURL = newURL.deletingLastPathComponent()
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(
                at: parentURL, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            log.info(
                "Renamed directory: \(oldRelativePath, privacy: .public) → \(newRelativePath, privacy: .public)"
            )
            return true
        } catch {
            log.error("Failed to rename directory: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Move a page's markdown file into a different vault subfolder and keep SwiftData in sync.
    ///
    /// Returns `true` when the move succeeded (file on disk + SwiftData both
    /// reflect the new location), `false` when any FS / persistence step
    /// failed. Pre-RCA13 callers ignored failures by accident, leaving
    /// SwiftData claiming the move while disk stayed in the old location.
    @discardableResult
    func movePage(pageId: String, toSubfolder subfolder: String?) -> Bool {
        guard let vaultURL else {
            log.warning("Cannot move page: no vault URL")
            return false
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "page move") else { return false }

        let normalizedSubfolder: String? = {
            guard let subfolder else { return nil }
            let trimmed = subfolder.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        let targetParentURL =
            normalizedSubfolder.map { vaultURL.appendingPathComponent($0, isDirectory: true) }
            ?? vaultURL

        do {
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(
                at: targetParentURL,
                withIntermediateDirectories: true
            )

            if let existingPath = page.filePath,
                FileManager.default.fileExists(atPath: existingPath)
            {
                let oldURL = URL(fileURLWithPath: existingPath)
                var newURL = targetParentURL.appendingPathComponent(oldURL.lastPathComponent)

                if newURL.path != oldURL.path {
                    let baseName = oldURL.deletingPathExtension().lastPathComponent
                    let ext = oldURL.pathExtension
                    var suffix = 1
                    while FileManager.default.fileExists(atPath: newURL.path) {
                        let candidateName =
                            suffix > 100
                            ? "\(baseName)-\(UUID().uuidString.prefix(8))"
                            : "\(baseName)-\(suffix)"
                        newURL = targetParentURL.appendingPathComponent(candidateName)
                            .appendingPathExtension(ext)
                        suffix += 1
                    }

                    try FileManager.default.moveItem(at: oldURL, to: newURL)
                }

                page.filePath = newURL.path
            } else {
                page.filePath = nil
            }

            page.subfolder = normalizedSubfolder
            page.updatedAt = .now
            try context.save()

            if page.filePath == nil {
                savePage(pageId: pageId)
            }
            publishVaultMutation(.vaultChanged)
            return true
        } catch {
            log.error("Failed to move page: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

}

@MainActor
enum VaultConnectionActions {
    @MainActor
    fileprivate static func connectSelectedVaultAsync(
        url: URL,
        vaultSync: VaultSyncService,
        beforeSwitch: @escaping @MainActor () -> Void = {}
    ) async -> Bool {
        vaultSync.vaultActivityMessage = "Checking vault \"\(url.lastPathComponent)\"..."
        vaultSync.isIndexing = true
        let assessment = await Task.detached(priority: .utility) {
            VaultIndexActor.vaultFolderSelectionAssessment(for: url)
        }.value

        guard shouldProceedWithVaultSelection(url: url, assessment: assessment) else {
            vaultSync.vaultActivityMessage = nil
            vaultSync.isIndexing = false
            return false
        }

        vaultSync.vaultActivityMessage = "Opening vault \"\(url.lastPathComponent)\"..."
        let didSwitch = await vaultSync.switchToVaultAsync(vaultURL: url)
        if didSwitch {
            // Reset UI only after successful switch
            beforeSwitch()
            NoteWindowManager.shared.resetForVaultRebuild()
            vaultSync.persistVaultSelection(
                url,
                userConfirmedSuspiciousFolder: assessment.shouldConfirmSelection
            )
            return true
        }

        log.error("Vault switch to \(url.lastPathComponent, privacy: .public) failed")
        // RCA13 vault-add silent-abort fix: surface the failure
        // so the user knows the picker close wasn't success.
        // Previously the picker closed and nothing happened —
        // looked like a soft-broken button.
        AppBootstrap.shared?.uiState.showToast(
            "Couldn't open \"\(url.lastPathComponent)\" as a vault. Try a different folder.",
            type: .error
        )
        vaultSync.vaultActivityMessage = nil
        vaultSync.isIndexing = false
        return false
    }

    static func connectSelectedVault(
        url: URL,
        vaultSync: VaultSyncService,
        beforeSwitch: @escaping @MainActor () -> Void = {}
    ) {
        Task { @MainActor in
            _ = await connectSelectedVaultAsync(
                url: url,
                vaultSync: vaultSync,
                beforeSwitch: beforeSwitch
            )
        }
    }

    @MainActor
    fileprivate static func selectVaultFolderForImmediateUse(
        notesUI: NotesUIState,
        vaultSync: VaultSyncService
    ) async -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        // Same folder already connected — no-op
        if let current = vaultSync.vaultURL,
           current.standardizedFileURL == url.standardizedFileURL { return true }

        return await connectSelectedVaultAsync(url: url, vaultSync: vaultSync) {
            notesUI.resetForVaultSwitch()
        }
    }

    static func selectVaultFolder(notesUI: NotesUIState, vaultSync: VaultSyncService) {
        Task { @MainActor in
            _ = await selectVaultFolderForImmediateUse(notesUI: notesUI, vaultSync: vaultSync)
        }
    }

    static func disconnect(notesUI: NotesUIState, vaultSync: VaultSyncService) {
        // Per user 2026-05-10 + RCA13-P0-001: previously disconnect was
        // much weaker than Reset Everything — never called
        // clearVaultLifecycleRuntimeState, never force-cleared derived
        // state when no local body data was watched, so graph engine
        // payload, query engine, contextual shadows, shadow indexer,
        // and instant recall all leaked through to the next vault.
        //
        // The first attempt at this fix (d85cfbc46) ran the canonical
        // clear synchronously on the calling MainActor BEFORE the Task,
        // which hung the UI because graphState.resetForVaultLifecycle
        // makes 4 sync Rust FFI calls into the graph engine. This
        // version keeps the entire teardown inside an async Task and
        // yields between heavy steps so the UI repaints between the
        // sync FFI clears.
        Task { @MainActor in
            vaultSync.vaultActivityMessage = "Disconnecting vault..."
            vaultSync.isIndexing = true
            defer {
                vaultSync.vaultActivityMessage = nil
                vaultSync.isIndexing = false
            }

            // Step 0 (USER REPORT 2026-05-12 fix): wipe the persisted
            // bookmark FIRST, before any heavy async teardown. Previous
            // ordering ran clearPersistedVaultSelection() after
            // stopWatchingAsync(preserveData: false), which on large
            // vaults can take 30+ seconds. If the user force-quit during
            // that window, the bookmark survived → next launch silently
            // re-mounted the "disconnected" vault. Clearing the bookmark
            // up front makes the disconnect durable even if the user
            // kills the app mid-teardown; the worst they get is a stale
            // graph/shadow index, not a phantom vault re-mount.
            vaultSync.clearPersistedVaultSelection()

            // Step 1: canonical runtime-state clear — graph engine,
            // query engine, contextual shadows, instant recall,
            // workspace restore. Mirrors resetAllData() phase 1.
            AppBootstrap.shared?.clearVaultLifecycleRuntimeState(
                reason: "Disconnect Vault started",
                clearWorkspaceRestore: true
            )
            await Task.yield()

            // Step 2: stop the vault watcher. If there was no local
            // body data to clear, force the derived-state clear path
            // anyway so disconnect can't leave a half-wiped shadow /
            // instant-recall / search index. Matches resetAllData()
            // phase 2 fallback.
            let didClear = await vaultSync.stopWatchingAsync(preserveData: false)
            if didClear {
                vaultSync.dismissRecoveryIssue()
            } else {
                await vaultSync.forceClearDerivedLocalStateForFullReset()
            }
            await Task.yield()

            // Step 3: reset UI surface — vaultURL is already nil so
            // SwiftUI flips to the empty state on the next pass. The
            // setup assistant is re-armed by `setupComplete = false`
            // below; keep the legacy full-screen SetupView hidden so it
            // cannot sit between the user and the vault picker.
            AppBootstrap.shared?.chatState.clearMessages()
            notesUI.resetForVaultSwitch()
            NoteWindowManager.shared.resetForVaultRebuild()
            AppBootstrap.shared?.ambientManifest = nil
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            AppBootstrap.shared?.uiState.needsSetup = false
            // Re-arm the SetupAssistant sheet by clearing the
            // first-launch completion flag so the rich setup flow
            // surfaces again instead of being locked out.
            UserDefaults.standard.set(false, forKey: "epistemos.setupComplete")
            await Task.yield()

            // Step 4: post-teardown clear catches any state emitted
            // by background tasks during the async gap (e.g. a late
            // shadow-indexer callback completing into the now-dead
            // vault). Matches resetAllData() phase 3.
            AppBootstrap.shared?.clearVaultLifecycleRuntimeState(
                reason: "Disconnect Vault completed",
                clearWorkspaceRestore: true
            )
            AppBootstrap.shared?.uiState.showToast("Vault disconnected", type: .success)
        }
    }

    private static func shouldProceedWithVaultSelection(
        url: URL,
        assessment: VaultIndexActor.VaultFolderSelectionAssessment
    ) -> Bool {
        guard assessment.shouldConfirmSelection else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This Folder May Not Be a Notes Vault"
        alert.informativeText = assessment.confirmationMessage
        alert.addButton(withTitle: "Use Folder")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
