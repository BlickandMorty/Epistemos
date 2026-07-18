import AppKit
import CoreServices
import CryptoKit
import Foundation
import Observation
import SQLite3
import SwiftData
import os

// MARK: - VaultSyncService
// Markdown vault hybrid: connected vault files are live, portable note inputs.
// Managed note bodies remain the app's editor/cache safety layer for undo,
// derived indexes, and conflict protection.
//
// Save triggers: per-note Save (Cmd+S), Save All (Shift+Cmd+S), auto-save interval.
// Import: initial vault import on attach, manual "Sync from Vault" button,
// and debounced recursive file-system events from external editors/tools.

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

    nonisolated var isRetryableAutomaticRestorePreflightFailure: Bool {
        guard bookmarkExists, !isReadyForAutomaticRestore, let failureReason else {
            return false
        }

        return failureReason == "Saved vault bookmark points to a missing or unreadable directory."
            || failureReason == "Saved vault bookmark lost security-scoped access."
    }

    nonisolated var shouldBlockAutomaticRestore: Bool {
        bookmarkExists
            && !isReadyForAutomaticRestore
            && !isRetryableAutomaticRestorePreflightFailure
    }
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
    let forceBlocksWorkspaceInteraction: Bool

    init(
        snapshot: VaultHealthSnapshot,
        reason: String,
        forceBlocksWorkspaceInteraction: Bool = false
    ) {
        self.id = UUID().uuidString
        self.snapshot = snapshot
        self.reason = reason
        self.forceBlocksWorkspaceInteraction = forceBlocksWorkspaceInteraction
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
        forceBlocksWorkspaceInteraction
            || (snapshot.isVaultReadable && snapshot.vaultMarkdownCount > 0)
    }
}

enum PageIdentityCommitResult: Equatable, Sendable {
    case committed
    case rejected
    case rolledBack
    case recoveryRequired
}

private enum PageBodyFileSaveResult: Equatable {
    case saved
    case stale
    case failed
}

private actor VaultPageFileMutationGate {
    private var lockedPageIDs = Set<String>()
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func acquire(pageId: String) async {
        if lockedPageIDs.insert(pageId).inserted {
            return
        }
        await withCheckedContinuation { continuation in
            waiters[pageId, default: []].append(continuation)
        }
    }

    func release(pageId: String) {
        if var pageWaiters = waiters[pageId], !pageWaiters.isEmpty {
            let continuation = pageWaiters.removeFirst()
            if pageWaiters.isEmpty {
                waiters.removeValue(forKey: pageId)
            } else {
                waiters[pageId] = pageWaiters
            }
            continuation.resume()
            return
        }
        lockedPageIDs.remove(pageId)
    }
}

private struct VaultMutationAdmission: Sendable {
    let requestID: UInt64
    let lifecycleEpoch: UInt64
    let vaultPath: String
}

fileprivate struct VaultLifecycleToken: Sendable, Equatable {
    let lifecycleEpoch: UInt64
    let vaultPath: String
}

private enum VaultLifecyclePhase {
    case disconnected(epoch: UInt64)
    case operational(epoch: UInt64, vaultPath: String)
    case draining(epoch: UInt64, vaultPath: String)
}

/// A candidate is admitted before it can replace any mounted vault state. The
/// receipt holds the exact canonical bootstrap result, bounded folder scan, and
/// preconstructed search dependency needed by the later mount transition.
nonisolated enum VaultPostImportRecallWorkload: Sendable, Equatable {
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

struct VaultFileSystemEvent: Sendable {
    let path: String
    let flags: FSEventStreamEventFlags
    let inode: UInt64?
    let eventID: FSEventStreamEventId

    nonisolated var requiresFullRescan: Bool {
        contains(kFSEventStreamEventFlagMustScanSubDirs)
            || contains(kFSEventStreamEventFlagUserDropped)
            || contains(kFSEventStreamEventFlagKernelDropped)
            || contains(kFSEventStreamEventFlagRootChanged)
            || contains(kFSEventStreamEventFlagMount)
            || contains(kFSEventStreamEventFlagUnmount)
    }

    nonisolated var itemIsDirectory: Bool {
        contains(kFSEventStreamEventFlagItemIsDir)
    }

    nonisolated var itemWasRemoved: Bool {
        contains(kFSEventStreamEventFlagItemRemoved)
    }

    nonisolated var itemWasRenamed: Bool {
        contains(kFSEventStreamEventFlagItemRenamed)
    }

    nonisolated var signalsVaultRootAvailabilityChange: Bool {
        contains(kFSEventStreamEventFlagRootChanged)
            || contains(kFSEventStreamEventFlagMount)
            || contains(kFSEventStreamEventFlagUnmount)
    }

    private nonisolated func contains(_ flag: Int) -> Bool {
        flags & FSEventStreamEventFlags(flag) != 0
    }
}

nonisolated struct VaultFileSystemProcessingResult: Sendable {
    let didProcess: Bool
    let didMutate: Bool
    let completedAuthoritativeFullRescan: Bool
    let postImportRecallWorkload: VaultPostImportRecallWorkload

    init(
        didProcess: Bool,
        didMutate: Bool,
        completedAuthoritativeFullRescan: Bool = false,
        postImportRecallWorkload: VaultPostImportRecallWorkload = .none
    ) {
        self.didProcess = didProcess
        self.didMutate = didMutate
        self.completedAuthoritativeFullRescan = completedAuthoritativeFullRescan
        self.postImportRecallWorkload = postImportRecallWorkload
    }
}

nonisolated struct VaultSpotlightJournalReceipt: Sendable, Equatable {
    let candidateCursor: Date?
    let pageCount: Int
    let legacyItemCount: Int
    let typedEntityCount: Int
}

nonisolated struct VaultInstantRecallNote: Sendable, Equatable {
    let id: String
    let text: String
}

nonisolated enum VaultInstantRecallMutation: Sendable, Equatable {
    case none
    case incremental(changedNotes: [VaultInstantRecallNote], deletedPageIDs: [String])
    case rebuild(documents: [String: String])
}

enum VaultFileSystemEventClassification: Equatable, Sendable {
    case fullRescan
    case changed(String)
    case deleted(String)
    case ignored
}

fileprivate final class VaultFileWatcherCallbackBox {
    nonisolated(unsafe) weak var service: VaultSyncService?
    let lifecycleToken: VaultLifecycleToken

    init(service: VaultSyncService, lifecycleToken: VaultLifecycleToken) {
        self.service = service
        self.lifecycleToken = lifecycleToken
    }

    nonisolated func handle(_ events: [VaultFileSystemEvent]) {
        Task { @MainActor [weak service, lifecycleToken] in
            service?.handleVaultFileSystemEvents(events, lifecycleToken: lifecycleToken)
        }
    }
}

private final class VaultFileWatcherState {
    var source: DispatchSourceFileSystemObject?
    var eventStream: FSEventStreamRef?
    var callbackBox: Unmanaged<VaultFileWatcherCallbackBox>?
    var fileDescriptor: Int32 = -1
    var debounceTask: Task<Void, Never>?
    let eventQueue = DispatchQueue(label: "com.epistemos.vault.fsevents", qos: .utility)
    var pendingChangedPaths = Set<String>()
    var pendingDeletedPaths = Set<String>()
    var pendingFullRescan = false
    var pendingLastEventID: FSEventStreamEventId?
    var pendingRevision: UInt64 = 0
    let clock = ContinuousClock()
    var ignoreUntil: ContinuousClock.Instant?
}

nonisolated private final class VaultFileSystemBatchCompletionFence: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private var result: VaultFileSystemProcessingResult?
    private var waiters: [CheckedContinuation<VaultFileSystemProcessingResult?, Never>] = []

    func wait() async -> VaultFileSystemProcessingResult? {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isFinished {
                let completedResult = result
                lock.unlock()
                continuation.resume(returning: completedResult)
                return
            }
            waiters.append(continuation)
            lock.unlock()
        }
    }

    func finish(with result: VaultFileSystemProcessingResult?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        self.result = result
        let pendingWaiters = waiters
        waiters.removeAll(keepingCapacity: false)
        lock.unlock()
        pendingWaiters.forEach { $0.resume(returning: result) }
    }
}

private let log = Logger(subsystem: "com.epistemos", category: "VaultSync")

@MainActor
private enum VaultImportProgressBridge {
    static func publish(_ snapshot: VaultImportProgressSnapshot, lifecycleToken: VaultLifecycleToken) {
        guard let vaultSync = AppBootstrap.shared?.vaultSync,
              vaultSync.vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true)
        else { return }
        vaultSync.applyVaultImportProgress(snapshot)
    }
}

@MainActor @Observable
final class VaultSyncService {
    typealias ExportPageOperation = @Sendable (String, URL) async throws -> (path: String, bodyHash: String)?
    typealias InitialImportOperation = @Sendable (URL) async -> Bool
    typealias HybridMigrationOperation = @Sendable (VaultIndexActor) async -> Void
    typealias InitialImportDerivedOperation = @Sendable (
        VaultIndexActor,
        SearchIndexService?,
        VaultPostImportRecallWorkload
    ) async -> VaultInstantRecallMutation
    typealias InitialImportDerivedApplyOperation = @MainActor @Sendable (
        VaultInstantRecallMutation
    ) -> Void
    typealias InitialImportDerivedCompletionOperation = @Sendable () async -> Void
    typealias ExternalVaultFileSystemChangesOperation = @Sendable (
        URL,
        [String],
        [String],
        Bool
    ) async -> VaultFileSystemProcessingResult
    typealias VaultFileSystemRecallPreparationOperation = @Sendable (
        VaultIndexActor,
        VaultPostImportRecallWorkload
    ) async -> VaultInstantRecallMutation?
    typealias VaultFileSystemRecallApplyOperation = @MainActor @Sendable (
        VaultInstantRecallMutation
    ) -> Void
    typealias VaultFileSystemRecallCompletionOperation = @Sendable () async -> Void
    typealias PageIdentityBeforeForwardWriteOperation = @Sendable (String, URL) async throws -> Void
    typealias PageIdentityAfterForwardWriteOperation = @Sendable (String, URL) async throws -> Void
    typealias TMUtilCommandRunner = @Sendable ([String]) throws -> String
    typealias BookmarkDataWriter = @Sendable (URL, URL.BookmarkCreationOptions) throws -> Data
    typealias SecurityScopeAccessOperation = @Sendable (URL) -> Bool
    typealias SecurityScopeStopOperation = @Sendable (URL) -> Void
    fileprivate nonisolated static let bookmarkKey = "epistemos.vaultBookmark"
    fileprivate nonisolated static let lastVaultPathKey = "epistemos.lastVaultPath"
    fileprivate nonisolated static let vaultFSEventCheckpointPrefix = "keelstone.lastEventID."
    fileprivate nonisolated static let trustedSuspiciousVaultPathKey = "epistemos.confirmedSuspiciousVaultPath"
    fileprivate nonisolated static let autoSaveIntervalKey = "epistemos.autoSaveInterval"
    fileprivate nonisolated static let testDefaultsSuitePrefix = "com.epistemos.tests.VaultSyncService."
    fileprivate nonisolated static let skipRestoreEnvironmentKey = "EPISTEMOS_SKIP_VAULT_RESTORE"
    private nonisolated static let spotlightCursorPrefix = "keelstone.spotlightCursor.v2."
    /// Set at the very start of `disconnect()`. If the app crashes /
    /// is force-quit mid-disconnect, this flag survives and is detected
    /// by `restoreVaultFromBookmark()` on the next launch — which then
    /// clears the bookmark BEFORE attempting any restore. Cleared by
    /// `disconnect()` when teardown completes cleanly.
    fileprivate nonisolated static let disconnectInProgressKey = "epistemos.disconnectInProgress"
    /// Set the first time the user successfully attaches a vault.
    /// VaultReprompSheet (`ISSUE-2026-05-12-002`) only auto-prompts
    /// when this flag is unset — i.e., the user has NEVER attached a
    /// vault before. After explicit disconnect, the flag remains set
    /// so the user is not pestered with a re-prompt sheet for a vault
    /// they intentionally removed.
    fileprivate nonisolated static let hasEverConnectedVaultKey = "epistemos.hasEverConnectedAVault"
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

    private nonisolated static func vaultCheckpointID(for vaultURL: URL) -> String {
        let path = vaultURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func vaultFSEventCheckpointKey(for vaultURL: URL) -> String {
        "\(vaultFSEventCheckpointPrefix)\(vaultCheckpointID(for: vaultURL))"
    }

    private nonisolated static func spotlightCursorKey(for vaultURL: URL) -> String {
        "\(spotlightCursorPrefix)\(vaultCheckpointID(for: vaultURL))"
    }

    private nonisolated static func vaultFSEventStartID(
        for vaultURL: URL,
        defaults: UserDefaults
    ) -> FSEventStreamEventId {
        let checkpointKey = vaultFSEventCheckpointKey(for: vaultURL)
        return defaults.string(forKey: checkpointKey)
            .flatMap(UInt64.init)
            .map { FSEventStreamEventId($0) }
            ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    }

#if DEBUG
    nonisolated static func vaultFSEventCheckpointKeyForTesting(vaultURL: URL) -> String {
        vaultFSEventCheckpointKey(for: vaultURL)
    }

    nonisolated static func vaultFSEventStartIDForTesting(
        vaultURL: URL,
        defaults: UserDefaults
    ) -> FSEventStreamEventId {
        vaultFSEventStartID(for: vaultURL, defaults: defaults)
    }

    nonisolated static func spotlightCursorKeyForTesting(vaultURL: URL) -> String {
        spotlightCursorKey(for: vaultURL)
    }
#endif

    nonisolated static func shouldRestoreVaultFromBookmark(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        FoundationSafety.requireValidAuditRuntimeIsolationIfRequested(
            processInfoEnvironment: processInfoEnvironment
        )
        return processInfoEnvironment["XCTestConfigurationFilePath"] == nil
            && !shouldSkipVaultRestore(processInfoEnvironment: processInfoEnvironment)
    }

    nonisolated static func shouldMigrateLegacyVaultBookmarkDefaults(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        switch FoundationSafety.auditRuntimeIsolationRequestState(
            processInfoEnvironment: processInfoEnvironment
        ) {
        case .notRequested:
            return true
        case .active:
            return false
        case .requestedButInvalid:
            preconditionFailure("Runtime-audit bookmark isolation is incomplete or invalid")
        }
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
        switch FoundationSafety.auditRuntimeIsolationRequestState(
            processInfoEnvironment: processInfoEnvironment
        ) {
        case .active:
            return FoundationSafety.resolvedRuntimeUserDefaults(
                processInfoEnvironment: processInfoEnvironment
            )
        case .requestedButInvalid:
            preconditionFailure("Runtime-audit bookmark defaults are incomplete or invalid")
        case .notRequested:
            break
        }

        guard shouldRestoreVaultFromBookmark(processInfoEnvironment: processInfoEnvironment), !isRunningTests else {
            let suiteName = "\(testDefaultsSuitePrefix)\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                preconditionFailure("Could not create isolated no-restore defaults")
            }
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }
        return FoundationSafety.resolvedRuntimeUserDefaults(
            processInfoEnvironment: processInfoEnvironment
        )
    }

#if DEBUG
    nonisolated static func makeDefaultUserDefaultsForTesting(
        processInfoEnvironment: [String: String]
    ) -> UserDefaults {
        makeDefaultUserDefaults(processInfoEnvironment: processInfoEnvironment)
    }
#endif

    private struct DirtySaveBatch {
        let context: ModelContext
        let dirtyIds: [String]
    }

    private struct AcceptedVaultFileSystemBatch: Sendable {
        let admission: VaultMutationAdmission
        let lifecycleToken: VaultLifecycleToken
        let vaultURL: URL
        let actor: VaultIndexActor
        let searchService: SearchIndexService?
        let processingOperation: ExternalVaultFileSystemChangesOperation?
        let recallPreparationOperation: VaultFileSystemRecallPreparationOperation?
        let recallApplyOperation: VaultFileSystemRecallApplyOperation?
        let recallCompletionOperation: VaultFileSystemRecallCompletionOperation?
        let changedPaths: [String]
        let deletedPaths: [String]
        let needsFullRescan: Bool
        let lastEventID: FSEventStreamEventId?
        let completionFence: VaultFileSystemBatchCompletionFence
    }

    private struct InitialImportResult: Sendable {
        let didImport: Bool
        let snapshot: VaultImportProgressSnapshot?
        let suppressedSearchBatchID: SearchIndexMutationBatchID?
    }

    private struct InitialImportDerivedResult: Sendable {
        let searchSynchronizationReceipt: SearchIndexSynchronizationReceipt?
        let recallMutation: VaultInstantRecallMutation
        let spotlightJournalReceipt: VaultSpotlightJournalReceipt?
    }

    private struct PageIdentityTransactionSnapshot {
        let title: String
        let tags: [String]
        let folder: SDFolder?
        let subfolder: String?
        let filePath: String?
        var fileData: Data?
        var diskBody: String
        let localDraftBody: String?
        let inlineBody: String
        let emoji: String
        let isJournal: Bool
        let journalDate: String?
        let parentPageId: String?
        let templateId: String?
        let frontMatter: [String: String]
        let updatedAt: Date
        let lastSyncedBodyHash: String?
        let lastSyncedAt: Date?
        let needsVaultSync: Bool
        let blockReferences: [String]
        let wikilinkReferences: [String]
        let wikilinkReferenceScanSignature: String?

        init(page: SDPage, fileData: Data?, diskBody: String, localDraftBody: String?) {
            title = page.title
            tags = page.tags
            folder = page.folder
            subfolder = page.subfolder
            filePath = page.filePath
            self.fileData = fileData
            self.diskBody = diskBody
            self.localDraftBody = localDraftBody
            inlineBody = page.body
            emoji = page.emoji
            isJournal = page.isJournal
            journalDate = page.journalDate
            parentPageId = page.parentPageId
            templateId = page.templateId
            frontMatter = page.frontMatter
            updatedAt = page.updatedAt
            lastSyncedBodyHash = page.lastSyncedBodyHash
            lastSyncedAt = page.lastSyncedAt
            needsVaultSync = page.needsVaultSync
            blockReferences = page.blockReferences
            wikilinkReferences = page.wikilinkReferences
            wikilinkReferenceScanSignature = page.wikilinkReferenceScanSignature
        }

        func restore(on page: SDPage) {
            page.title = title
            page.tags = tags
            page.folder = folder
            page.subfolder = subfolder
            page.filePath = filePath
            page.body = inlineBody
            page.emoji = emoji
            page.isJournal = isJournal
            page.journalDate = journalDate
            page.parentPageId = parentPageId
            page.templateId = templateId
            page.frontMatter = frontMatter
            page.updatedAt = updatedAt
            page.lastSyncedBodyHash = lastSyncedBodyHash
            page.lastSyncedAt = lastSyncedAt
            page.needsVaultSync = needsVaultSync
            page.blockReferences = blockReferences
            page.wikilinkReferences = wikilinkReferences
            page.wikilinkReferenceScanSignature = wikilinkReferenceScanSignature
        }

        func stillMatches(_ page: SDPage) -> Bool {
            title == page.title
                && tags == page.tags
                && folder?.id == page.folder?.id
                && subfolder == page.subfolder
                && filePath == page.filePath
                && inlineBody == page.body
                && emoji == page.emoji
                && isJournal == page.isJournal
                && journalDate == page.journalDate
                && parentPageId == page.parentPageId
                && templateId == page.templateId
                && frontMatter == page.frontMatter
                && updatedAt == page.updatedAt
                && lastSyncedBodyHash == page.lastSyncedBodyHash
                && lastSyncedAt == page.lastSyncedAt
                && needsVaultSync == page.needsVaultSync
                && blockReferences == page.blockReferences
                && wikilinkReferences == page.wikilinkReferences
                && wikilinkReferenceScanSignature == page.wikilinkReferenceScanSignature
        }
    }

    private struct PageIdentityDraftFingerprint: Equatable {
        let liveBody: String?
        let inlineBody: String
        let pendingBody: String?
    }

    private struct PageIdentityTargetFingerprint: Equatable {
        let folderID: String?
        let folderRelativePath: String?
        let subfolder: String?
    }

    private struct PageBodyMutationFingerprint: Equatable {
        let liveBody: String?
        let inlineBody: String
        let pendingBody: String?
        let saveRequestGeneration: UInt64?
    }

    private struct PageIdentityMetadataFingerprint: Equatable {
        let title: String
        let tags: [String]
        let folderID: String?
        let subfolder: String?
        let filePath: String?
        let inlineBody: String
        let emoji: String
        let isJournal: Bool
        let journalDate: String?
        let parentPageId: String?
        let templateId: String?
        let frontMatter: [String: String]
        let updatedAt: Date
        let lastSyncedBodyHash: String?
        let lastSyncedAt: Date?
        let needsVaultSync: Bool
        let blockReferences: [String]
        let wikilinkReferences: [String]
        let wikilinkReferenceScanSignature: String?

        init(page: SDPage) {
            title = page.title
            tags = page.tags
            folderID = page.folder?.id
            subfolder = page.subfolder
            filePath = page.filePath
            inlineBody = page.body
            emoji = page.emoji
            isJournal = page.isJournal
            journalDate = page.journalDate
            parentPageId = page.parentPageId
            templateId = page.templateId
            frontMatter = page.frontMatter
            updatedAt = page.updatedAt
            lastSyncedBodyHash = page.lastSyncedBodyHash
            lastSyncedAt = page.lastSyncedAt
            needsVaultSync = page.needsVaultSync
            blockReferences = page.blockReferences
            wikilinkReferences = page.wikilinkReferences
            wikilinkReferenceScanSignature = page.wikilinkReferenceScanSignature
        }
    }

    private struct PageIdentityFileMutationReceipt: Sendable {
        let originalURL: URL?
        let originalData: Data?
        let forwardData: Data
        var currentURL: URL
        var moved: Bool
    }

    private enum PageIdentityTransactionError: Error {
        case invalidOriginalFileData
        case missingOriginalFile
        case missingOriginalFileData
        case originalPathOccupied
        case vaultLifecycleChanged
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
    private var initialImportOperationOverride: InitialImportOperation?
    private var hybridMigrationOperationOverride: HybridMigrationOperation?
    private var initialImportDerivedOperationOverride: InitialImportDerivedOperation?
    private var initialImportDerivedApplyOperationOverride: InitialImportDerivedApplyOperation?
    private var initialImportDerivedCompletionOperationOverride: InitialImportDerivedCompletionOperation?
    private var pageIdentityBeforeForwardWriteOverride: PageIdentityBeforeForwardWriteOperation?
    private var pageIdentityAfterForwardWriteOverride: PageIdentityAfterForwardWriteOperation?
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
    private var securityScopeStopOperation: SecurityScopeStopOperation = { url in
        url.stopAccessingSecurityScopedResource()
    }
    private var requiresSecurityScopedVaultAccessOverride: Bool?
    private var defaults = FoundationSafety.runtimeUserDefaults

    private(set) var vaultURL: URL?
    private(set) var isWatching = false
    /// Data MED-3: consecutive all-failed export batches (0 = healthy). A sustained
    /// streak means the vault volume/path is unreachable and recent edits aren't
    /// reaching disk (they stay dirty + retry). Surfaced as a Settings diagnostic.
    private(set) var vaultSaveFailureStreak: Int = 0
    private(set) var lastVaultSaveError: String?
    var isVaultSaveHealthy: Bool { vaultSaveFailureStreak < 2 }
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
    @ObservationIgnored
    private var importTaskLifecycleToken: VaultLifecycleToken?
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
    private var vaultLifecycleEpoch: UInt64 = 0
    @ObservationIgnored
    private var vaultLifecyclePhase: VaultLifecyclePhase = .disconnected(epoch: 0)
    @ObservationIgnored
    private var nextVaultMutationRequestID: UInt64 = 0
    @ObservationIgnored
    private var activeVaultMutationAdmissions: [UInt64: VaultMutationAdmission] = [:]
    @ObservationIgnored
    private var vaultMutationDrainWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored
    private var vaultMutationDrainStartWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored
    private var powerModeObserverTask: Task<Void, Never>?
    private var inFlightDirtySaveTask: Task<Void, Never>?
    @ObservationIgnored
    private var fileFirstSaveTails: [String: Task<Bool, Never>] = [:]
    @ObservationIgnored
    private var fileFirstSaveTailGenerations: [String: UInt64] = [:]
    @ObservationIgnored
    private var fileFirstSaveGenerations: [String: UInt64] = [:]
    @ObservationIgnored
    private var nextFileFirstSaveGeneration: UInt64 = 0
    private let pageFileMutationGate = VaultPageFileMutationGate()
    @ObservationIgnored
    private var graphPageMutationRefreshTask: Task<Void, Never>?
    private var pendingDirtySaveRequest = false
    private var initialImportCompleted = false
    private var pendingStartupResolvedBookmark: (
        bookmarkData: Data,
        resolvedBookmark: ResolvedVaultBookmark
    )?
    @ObservationIgnored
    private var externalVaultFileSystemChangesOperationOverride: ExternalVaultFileSystemChangesOperation?
    @ObservationIgnored
    private var vaultFileSystemRecallPreparationOperationOverride: VaultFileSystemRecallPreparationOperation?
    @ObservationIgnored
    private var vaultFileSystemRecallApplyOperationOverride: VaultFileSystemRecallApplyOperation?
    @ObservationIgnored
    private var vaultFileSystemRecallCompletionOperationOverride: VaultFileSystemRecallCompletionOperation?
    @ObservationIgnored
    private var acceptedVaultFileSystemBatches: [AcceptedVaultFileSystemBatch] = []
    @ObservationIgnored
    private var acceptedVaultFileSystemBatchHead = 0
    @ObservationIgnored
    private var vaultFileSystemProcessorTask: Task<Void, Never>?
    @ObservationIgnored
    private var blockedFSEventCheckpointToken: VaultLifecycleToken?

    // MARK: - File Watching
    @ObservationIgnored
    private let fileWatcherState = VaultFileWatcherState()
    private nonisolated static let recoverySnapshotLimit = 20
    private nonisolated static let maxInitialReadinessWatcherDrains = 8

    private struct ResolvedVaultBookmark: Sendable {
        let url: URL
        let isStale: Bool
        let usedSecurityScope: Bool
    }

    fileprivate struct PreparedVaultSelection: Sendable {
        let bookmarkData: Data
        let standardizedPath: String
        let userConfirmedSuspiciousFolder: Bool
    }

    private enum VaultBookmarkResolutionError: Error, Sendable {
        case corrupted
        case timedOut
    }

    private nonisolated final class VaultBookmarkResolutionRace: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<ResolvedVaultBookmark, Error>?

        init(continuation: CheckedContinuation<ResolvedVaultBookmark, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<ResolvedVaultBookmark, Error>) {
            let continuation = lock.withLock {
                let pending = self.continuation
                self.continuation = nil
                return pending
            }
            continuation?.resume(with: result)
        }
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

    private func advanceVaultLifecycleEpoch() -> UInt64 {
        vaultLifecycleEpoch &+= 1
        if vaultLifecycleEpoch == 0 {
            vaultLifecycleEpoch = 1
        }
        return vaultLifecycleEpoch
    }

    private func activateVaultLifecycle(for vaultURL: URL) {
        let epoch = advanceVaultLifecycleEpoch()
        vaultLifecyclePhase = .operational(
            epoch: epoch,
            vaultPath: vaultURL.standardizedFileURL.path
        )
        blockedFSEventCheckpointToken = nil
    }

    private func disconnectVaultLifecycle() {
        vaultLifecyclePhase = .disconnected(epoch: advanceVaultLifecycleEpoch())
    }

    private func currentOperationalVaultLifecycleToken(for vaultURL: URL) -> VaultLifecycleToken? {
        let standardizedPath = vaultURL.standardizedFileURL.path
        guard case let .operational(epoch, vaultPath) = vaultLifecyclePhase,
              vaultPath == standardizedPath,
              self.vaultURL?.standardizedFileURL.path == standardizedPath
        else {
            return nil
        }
        return VaultLifecycleToken(lifecycleEpoch: epoch, vaultPath: vaultPath)
    }

    fileprivate func vaultLifecycleTokenIsCurrent(
        _ token: VaultLifecycleToken,
        requireOperational: Bool
    ) -> Bool {
        guard vaultURL?.standardizedFileURL.path == token.vaultPath else { return false }
        switch vaultLifecyclePhase {
        case let .operational(epoch, vaultPath):
            return epoch == token.lifecycleEpoch && vaultPath == token.vaultPath
        case let .draining(epoch, vaultPath):
            return !requireOperational
                && epoch == token.lifecycleEpoch
                && vaultPath == token.vaultPath
        case .disconnected:
            return false
        }
    }

    private func registerVaultMutation() -> VaultMutationAdmission? {
        guard let vaultURL else { return nil }
        guard case let .operational(epoch, vaultPath) = vaultLifecyclePhase,
              vaultURL.standardizedFileURL.path == vaultPath
        else {
            return nil
        }
        nextVaultMutationRequestID &+= 1
        if nextVaultMutationRequestID == 0 {
            nextVaultMutationRequestID = 1
        }
        let admission = VaultMutationAdmission(
            requestID: nextVaultMutationRequestID,
            lifecycleEpoch: epoch,
            vaultPath: vaultPath
        )
        activeVaultMutationAdmissions[admission.requestID] = admission
        return admission
    }

    private func vaultMutationAdmissionIsCurrent(
        _ admission: VaultMutationAdmission,
        vaultURL: URL? = nil
    ) -> Bool {
        guard activeVaultMutationAdmissions[admission.requestID]?.lifecycleEpoch
                == admission.lifecycleEpoch,
              (vaultURL ?? self.vaultURL)?.standardizedFileURL.path == admission.vaultPath
        else {
            return false
        }
        switch vaultLifecyclePhase {
        case let .operational(epoch, vaultPath),
             let .draining(epoch, vaultPath):
            return epoch == admission.lifecycleEpoch && vaultPath == admission.vaultPath
        case .disconnected:
            return false
        }
    }

    private func finishVaultMutation(_ admission: VaultMutationAdmission) {
        guard activeVaultMutationAdmissions.removeValue(forKey: admission.requestID) != nil,
              activeVaultMutationAdmissions.isEmpty
        else {
            return
        }
        let waiters = vaultMutationDrainWaiters
        vaultMutationDrainWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func beginVaultMutationDrain() {
        guard case let .operational(epoch, vaultPath) = vaultLifecyclePhase else { return }
        vaultLifecyclePhase = .draining(epoch: epoch, vaultPath: vaultPath)
        let waiters = vaultMutationDrainStartWaiters
        vaultMutationDrainStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func waitForVaultMutationDrain() async {
        if !activeVaultMutationAdmissions.isEmpty {
            await withCheckedContinuation { continuation in
                vaultMutationDrainWaiters.append(continuation)
            }
        }
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

    func setVaultURLForTesting(_ vaultURL: URL?, isSecurityScoped: Bool = false) {
        self.vaultURL = vaultURL
        self.isSecurityScoped = vaultURL != nil && isSecurityScoped
        guard let vaultURL else {
            initialImportCompleted = false
            disconnectVaultLifecycle()
            indexActor = nil
            return
        }
        activateVaultLifecycle(for: vaultURL)
        initialImportCompleted = true
        if indexActor == nil {
            indexActor = VaultIndexActor(modelContainer: modelContainer)
        }
    }

    func importVaultForTesting(from vaultURL: URL) async throws {
        self.vaultURL = vaultURL
        activateVaultLifecycle(for: vaultURL)
        let actor = VaultIndexActor(modelContainer: modelContainer)
        indexActor = actor
        try await actor.importVault(from: vaultURL)
    }

    func setExportPageOverrideForTesting(_ exportPageOverride: ExportPageOperation?) {
        self.exportPageOverride = exportPageOverride
    }

    func setInitialImportOperationForTesting(_ operation: InitialImportOperation?) {
        initialImportOperationOverride = operation
    }

    func setHybridMigrationOperationForTesting(_ operation: HybridMigrationOperation?) {
        hybridMigrationOperationOverride = operation
    }

    func setInitialImportDerivedOperationsForTesting(
        operation: InitialImportDerivedOperation?,
        apply: InitialImportDerivedApplyOperation?,
        completion: InitialImportDerivedCompletionOperation?
    ) {
        initialImportDerivedOperationOverride = operation
        initialImportDerivedApplyOperationOverride = apply
        initialImportDerivedCompletionOperationOverride = completion
    }

    func setExternalVaultFileSystemChangesOperationForTesting(
        _ operation: ExternalVaultFileSystemChangesOperation?
    ) {
        externalVaultFileSystemChangesOperationOverride = operation
    }

    func setVaultFileSystemRecallPreparationOperationForTesting(
        _ operation: VaultFileSystemRecallPreparationOperation?
    ) {
        vaultFileSystemRecallPreparationOperationOverride = operation
    }

    func setVaultFileSystemRecallApplyOperationForTesting(
        _ operation: VaultFileSystemRecallApplyOperation?
    ) {
        vaultFileSystemRecallApplyOperationOverride = operation
    }

    func setVaultFileSystemRecallCompletionOperationForTesting(
        _ operation: VaultFileSystemRecallCompletionOperation?
    ) {
        vaultFileSystemRecallCompletionOperationOverride = operation
    }

    func initialImportTaskForTesting() -> Task<Void, Never>? {
        importTask
    }

    nonisolated static func initialImportSucceedsForTesting(
        actor: VaultIndexActor,
        url: URL
    ) async -> Bool {
        (await performInitialImport(
            actor: actor,
            url: url,
            searchService: nil
        )).didImport
    }

    nonisolated static func performSearchIndexDiffSyncForTesting(
        from actor: VaultIndexActor,
        searchService: SearchIndexService,
        suppressedSearchBatchID: SearchIndexMutationBatchID? = nil,
        canContinue: (@MainActor @Sendable () -> Bool)? = nil
    ) async -> SearchIndexSynchronizationReceipt? {
        await performSearchIndexDiffSync(
            from: actor,
            searchService: searchService,
            suppressedSearchBatchID: suppressedSearchBatchID,
            canContinue: canContinue
        )
    }

    func setPageIdentityAfterForwardWriteOverrideForTesting(
        _ operation: PageIdentityAfterForwardWriteOperation?
    ) {
        pageIdentityAfterForwardWriteOverride = operation
    }

    func setPageIdentityBeforeForwardWriteOverrideForTesting(
        _ operation: PageIdentityBeforeForwardWriteOperation?
    ) {
        pageIdentityBeforeForwardWriteOverride = operation
    }

    func setSearchServiceForTesting(_ searchService: SearchIndexService?) async {
        self.searchService = searchService
        if let searchService {
            await indexActor?.setSearchService(searchService)
        }
    }

#if DEBUG
    @discardableResult
    func setForceRequiredDerivedRebuildSourceFailureForTesting(_ shouldFail: Bool) async -> Bool {
        guard let indexActor else { return false }
        await indexActor.setForceRequiredDerivedRebuildSourceFailureForTesting(shouldFail)
        return true
    }
#endif

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

    func setSecurityScopeStopOperationForTesting(_ operation: SecurityScopeStopOperation?) {
        securityScopeStopOperation = operation ?? { url in
            url.stopAccessingSecurityScopedResource()
        }
    }

    func isVaultMutationDrainActiveForTesting() -> Bool {
        if case .draining = vaultLifecyclePhase {
            return true
        }
        return false
    }

    func activeVaultMutationAdmissionCountForTesting() -> Int {
        activeVaultMutationAdmissions.count
    }

    func waitUntilVaultMutationDrainBeginsForTesting() async {
        switch vaultLifecyclePhase {
        case .draining, .disconnected:
            return
        case .operational:
            await withCheckedContinuation { continuation in
                vaultMutationDrainStartWaiters.append(continuation)
            }
        }
    }

    func waitUntilVaultMutationAdmissionsFinishForTesting() async {
        await waitForVaultMutationDrain()
    }

    func vaultFileSystemProcessorStateForTesting() -> (running: Int, queued: Int) {
        (
            running: vaultFileSystemProcessorTask == nil ? 0 : 1,
            queued: acceptedVaultFileSystemBatches.count - acceptedVaultFileSystemBatchHead
        )
    }

    func captureVaultFileSystemEventDeliveryForTesting()
        -> @MainActor @Sendable ([VaultFileSystemEvent]) -> Void
    {
        guard let vaultURL,
              let lifecycleToken = currentOperationalVaultLifecycleToken(for: vaultURL)
        else {
            return { _ in }
        }
        return { [weak self, lifecycleToken] events in
            self?.handleVaultFileSystemEvents(events, lifecycleToken: lifecycleToken)
        }
    }

    func vaultFileSystemEventPendingStateForTesting() -> (
        changedPathCount: Int,
        deletedPathCount: Int,
        needsFullRescan: Bool,
        lastEventID: FSEventStreamEventId?,
        debounceActive: Bool
    ) {
        (
            changedPathCount: fileWatcherState.pendingChangedPaths.count,
            deletedPathCount: fileWatcherState.pendingDeletedPaths.count,
            needsFullRescan: fileWatcherState.pendingFullRescan,
            lastEventID: fileWatcherState.pendingLastEventID,
            debounceActive: fileWatcherState.debounceTask != nil
        )
    }

    func processVaultFileSystemEventsImmediatelyForTesting(
        _ events: [VaultFileSystemEvent]
    ) {
        guard let vaultURL,
              let lifecycleToken = currentOperationalVaultLifecycleToken(for: vaultURL)
        else { return }
        handleVaultFileSystemEvents(events, lifecycleToken: lifecycleToken)
        fileWatcherState.debounceTask?.cancel()
        fileWatcherState.debounceTask = nil
        _ = drainAndProcessPendingVaultFileSystemChanges(
            shouldIgnore: false,
            lifecycleToken: lifecycleToken
        )
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
        guard value,
              let vaultURL,
              let lifecycleToken = currentOperationalVaultLifecycleToken(for: vaultURL)
        else { return }
        fileWatcherState.debounceTask?.cancel()
        fileWatcherState.debounceTask = nil
        _ = drainAndProcessPendingVaultFileSystemChanges(
            shouldIgnore: false,
            lifecycleToken: lifecycleToken
        )
    }

    func handleVaultVolumeUnavailableForTesting(vaultURL: URL, reason: String) {
        handleVaultVolumeUnavailable(vaultURL: vaultURL, reason: reason)
    }

    func clearPendingStartupRestoreForTesting() {
        clearPendingStartupRestore()
    }

    func startupBookmarkValidation() -> VaultBookmarkStartupValidation {
        Self.startupBookmarkValidation(
            bookmarkData: defaults.data(forKey: Self.bookmarkKey)
        )
    }

    func startupBookmarkValidationWithTimeout() async -> VaultBookmarkStartupValidation {
        guard let bookmarkData = defaults.data(forKey: Self.bookmarkKey) else {
            pendingStartupResolvedBookmark = nil
            return VaultBookmarkStartupValidation(
                bookmarkExists: false,
                isReadyForAutomaticRestore: true,
                failureReason: nil
            )
        }

        let resolvedBookmark: ResolvedVaultBookmark
        do {
            resolvedBookmark = try await Self.resolveVaultBookmarkWithTimeout(bookmarkData)
        } catch {
            pendingStartupResolvedBookmark = nil
            return Self.makeStartupBookmarkValidation(
                bookmarkExists: true,
                resolvedURL: nil,
                isStale: false,
                usedSecurityScope: false,
                accessGranted: false,
                isReadable: false,
                requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
            )
        }
        pendingStartupResolvedBookmark = (
            bookmarkData: bookmarkData,
            resolvedBookmark: resolvedBookmark
        )
        return Self.startupBookmarkValidation(
            resolvedBookmark: resolvedBookmark,
            accessSecurityScope: { url in
                url.startAccessingSecurityScopedResource()
            },
            stopSecurityScope: { url in
                url.stopAccessingSecurityScopedResource()
            },
            fileExists: { path in
                FileManager.default.fileExists(atPath: path)
            },
            isReadableFile: { path in
                FileManager.default.isReadableFile(atPath: path)
            },
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
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

    nonisolated static func scopedStartupBookmarkValidationForTesting(
        resolvedURL: URL,
        isStale: Bool,
        usedSecurityScope: Bool,
        accessSecurityScope: (URL) -> Bool,
        stopSecurityScope: (URL) -> Void,
        fileExists: (String) -> Bool,
        isReadableFile: (String) -> Bool,
        requiresSecurityScopedVaultAccess: Bool
    ) -> VaultBookmarkStartupValidation {
        startupBookmarkValidation(
            resolvedBookmark: ResolvedVaultBookmark(
                url: resolvedURL,
                isStale: isStale,
                usedSecurityScope: usedSecurityScope
            ),
            accessSecurityScope: accessSecurityScope,
            stopSecurityScope: stopSecurityScope,
            fileExists: fileExists,
            isReadableFile: isReadableFile,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess
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

    private func exportPage(
        pageId: String,
        to vaultURL: URL,
        bodyOverride: String? = nil,
        indexForSearch: Bool = true
    ) async throws -> (path: String, bodyHash: String)? {
        if let exportPageOverride {
            return try await exportPageOverride(pageId, vaultURL)
        }
        return try await indexActor?.exportPage(
            pageId: pageId,
            to: vaultURL,
            bodyOverride: bodyOverride,
            indexForSearch: indexForSearch
        )
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
        pendingStartupResolvedBookmark = nil
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

    fileprivate func prepareVaultSelection(
        _ url: URL,
        userConfirmedSuspiciousFolder: Bool = false
    ) -> PreparedVaultSelection? {
        // USER REPORT 2026-05-12 v4: in DEV builds the app is not
        // sandboxed and security-scoped bookmark creation can fail with
        // "The file couldn't be opened" for paths the picker just
        // accepted. The fallback to a plain bookmark is the *correct*
        // path in that case, so try plain FIRST in dev builds to avoid
        // the noisy "Falling back to plain bookmark" warning. In
        // sandbox / App Store builds, security-scoped is required and
        // the existing strict path applies.
        let needsSecurityScope = requiresSecurityScopedVaultAccess()
        let bookmark: Data

        if !needsSecurityScope {
            // Dev / Developer ID build — plain bookmark is sufficient.
            do {
                bookmark = try makeBookmarkData(for: url, options: [])
            } catch {
                log.error("Failed to persist plain vault bookmark for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        } else {
            // Sandboxed build — security-scoped bookmark is required.
            do {
                bookmark = try makeBookmarkData(for: url, options: .withSecurityScope)
            } catch {
                log.error(
                    """
                    Failed to persist required security-scoped vault bookmark for \(url.path, privacy: .public): \
                    \(error.localizedDescription, privacy: .public)
                    """
                )
                return nil
            }
        }

        return PreparedVaultSelection(
            bookmarkData: bookmark,
            standardizedPath: url.standardizedFileURL.path,
            userConfirmedSuspiciousFolder: userConfirmedSuspiciousFolder
        )
    }

    fileprivate func commitPreparedVaultSelection(_ selection: PreparedVaultSelection) {
        defaults.set(selection.bookmarkData, forKey: Self.bookmarkKey)
        defaults.set(selection.standardizedPath, forKey: Self.lastVaultPathKey)
        // Mark the "has ever connected a vault" flag only after relaunch
        // permission is ready to commit. A failed bookmark preparation must
        // leave the previous persisted vault selection completely untouched.
        defaults.set(true, forKey: Self.hasEverConnectedVaultKey)
        if selection.userConfirmedSuspiciousFolder {
            defaults.set(selection.standardizedPath, forKey: Self.trustedSuspiciousVaultPathKey)
        } else {
            defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
        }
        recoveryIssue = nil
    }

    @discardableResult
    func persistVaultSelection(_ url: URL, userConfirmedSuspiciousFolder: Bool = false) -> Bool {
        guard let selection = prepareVaultSelection(
            url,
            userConfirmedSuspiciousFolder: userConfirmedSuspiciousFolder
        ) else {
            return false
        }
        commitPreparedVaultSelection(selection)
        return true
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
        restoreFailed: Bool,
        initialImportCompletedOverride: Bool? = nil
    ) async -> VaultRecoveryIssue? {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: candidateVaultURL,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed,
            initialImportCompletedOverride: initialImportCompletedOverride
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

        guard let preparedSelection = prepareVaultSelection(vaultURL) else {
            isRecoveringLocalState = false
            isIndexing = false
            vaultActivityMessage = nil
            let snapshot = await buildVaultHealthSnapshot(
                candidateVaultURL: vaultURL,
                bookmarkExists: defaults.data(forKey: Self.bookmarkKey) != nil,
                restoreFailed: true
            )
            recoveryIssue = VaultRecoveryIssue(
                snapshot: snapshot,
                reason: "Epistemos could not save permission to restore this vault on relaunch. Select the folder again."
            )
            return false
        }

        do {
            try await snapshotLocalStateOffMain()
            stopWatching(preserveData: true)
            await clearDerivedLocalStateForRecovery()
            commitPreparedVaultSelection(preparedSelection)
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
        restoreFailed: Bool,
        initialImportCompletedOverride: Bool? = nil
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
            initialImportCompleted: initialImportCompletedOverride ?? initialImportCompleted,
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
        // HONEST NO-VAULT (owner 2026-06-24 — authority "make the no-vault state honest"): with no candidate,
        // no active vault, and no last-path hint, there is genuinely NO recovery target — return nil rather
        // than fabricating ~/My mind. Fabricating it made health snapshots root at a non-existent/empty
        // default and read like a real (but empty) vault. The last-path hint above is preserved as the safety
        // net for a temporarily-unresolved bookmark. Both call sites already treat this as Optional
        // (buildVaultHealthSnapshot:939 + currentVaultHealthSnapshot:985 use .map / if let / nil-safe
        // comparableVaultCounts), so nil is honest "no recovery target", not a crash.
        return nil
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
        switch FoundationSafety.auditRuntimeIsolationRequestState() {
        case .active:
            return nil
        case .requestedButInvalid:
            preconditionFailure("Runtime-audit preference snapshots are not isolated")
        case .notRequested:
            break
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

        guard let snapshotRoot = recoverySnapshotRootURL() else {
            return
        }

        // USER REPORT 2026-05-12 (ISSUE-12-011): the original
        // implementation ran `contentsOfDirectory` + per-entry
        // `resourceValues(forKeys:)` + `removeItem` on the main thread
        // synchronously. On launch, this contributes to the multi-
        // second hang the user observed in their runtime trace.
        // Move it to a background Task so the bookmark-restore flow
        // doesn't block on filesystem I/O during app startup. The
        // limit-enforcement is best-effort anyway — excess snapshots
        // simply linger one more launch if the task hasn't completed
        // by the time the next launch arrives.
        let snapshotLimit = Self.recoverySnapshotLimit
        Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: snapshotRoot.path) else {
                return
            }
            do {
                try Self.pruneRecoverySnapshots(in: snapshotRoot, maxCount: snapshotLimit)
            } catch {
                Self.backgroundLog.error("Failed to prune recovery snapshots: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func createAPFSSafetySnapshotIfPossible(reason: String) {
        guard let manifestURL = apfsSnapshotManifestURL() else { return }
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
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
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
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

        return startupBookmarkValidation(
            resolvedBookmark: resolvedBookmark,
            accessSecurityScope: { url in
                url.startAccessingSecurityScopedResource()
            },
            stopSecurityScope: { url in
                url.stopAccessingSecurityScopedResource()
            },
            fileExists: { path in
                FileManager.default.fileExists(atPath: path)
            },
            isReadableFile: { path in
                FileManager.default.isReadableFile(atPath: path)
            },
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess()
        )
    }

    private nonisolated static func startupBookmarkValidation(
        resolvedBookmark: ResolvedVaultBookmark,
        accessSecurityScope: (URL) -> Bool,
        stopSecurityScope: (URL) -> Void,
        fileExists: (String) -> Bool,
        isReadableFile: (String) -> Bool,
        requiresSecurityScopedVaultAccess: Bool
    ) -> VaultBookmarkStartupValidation {
        let accessGranted: Bool
        let isReadable: Bool
        let resolvedPath = resolvedBookmark.url.path

        if resolvedBookmark.usedSecurityScope {
            accessGranted = accessSecurityScope(resolvedBookmark.url)
            if accessGranted {
                defer { stopSecurityScope(resolvedBookmark.url) }
                isReadable = fileExists(resolvedPath) && isReadableFile(resolvedPath)
            } else {
                isReadable = false
            }
        } else {
            isReadable = fileExists(resolvedPath) && isReadableFile(resolvedPath)
            accessGranted = isReadable
        }

        return makeStartupBookmarkValidation(
            bookmarkExists: true,
            resolvedURL: resolvedBookmark.url,
            isStale: resolvedBookmark.isStale,
            usedSecurityScope: resolvedBookmark.usedSecurityScope,
            accessGranted: accessGranted,
            isReadable: isReadable,
            requiresSecurityScopedVaultAccess: requiresSecurityScopedVaultAccess
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

    private nonisolated static func replaceOrMoveFile(from temporaryURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(
                destinationURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    private nonisolated static func isSQLiteDatabaseFile(at url: URL) -> Bool {
        guard let data = mappedFileData(at: url, label: "SQLite signature probe"),
              data.count >= 16 else {
            return false
        }

        return Array(data.prefix(16)) == Array("SQLite format 3\u{0}".utf8)
    }

    nonisolated static func backupSQLiteDatabaseIfPresent(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                ".\(destinationURL.lastPathComponent).tmp-\(UUID().uuidString)",
                isDirectory: false
            )
        defer { try? fileManager.removeItem(at: temporaryURL) }

        guard isSQLiteDatabaseFile(at: sourceURL) else {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try replaceOrMoveFile(from: temporaryURL, to: destinationURL)
            return
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
            temporaryURL.path,
            &destinationDB,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let destinationDB else {
            throw sqliteBackupError(
                domain: "VaultSyncService.SQLiteBackup.OpenDestination",
                code: -1,
                databaseURL: temporaryURL,
                db: destinationDB
            )
        }

        do {
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
            var busyRetryCount = 0
            repeat {
                resultCode = sqlite3_backup_step(backup, 512)
                if resultCode == SQLITE_OK {
                    busyRetryCount = 0
                } else if resultCode == SQLITE_BUSY || resultCode == SQLITE_LOCKED {
                    busyRetryCount += 1
                    if busyRetryCount > 200 {
                        break
                    }
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

        try replaceOrMoveFile(from: temporaryURL, to: destinationURL)
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
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = arguments
        process.environment = SanitizedEnvironment.build()

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
        // EPISTEMOS_APP_STORE or MAS_SANDBOX before reaching this helper, so this
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

        // USER REPORT 2026-05-12 fix (ISSUE-2026-05-12-012): when
        // `tmutil deletelocalsnapshots` fails on a stuck old snapshot
        // (macOS pinned it, or it's no longer present), the original
        // code propagated the error → `saveAPFSSnapshotManifest` never
        // ran → the stuck snapshot stayed in the manifest → next prune
        // attempt tried to delete it again → infinite log spam.
        //
        // Fix: catch each delete failure independently. If tmutil
        // refuses to delete a snapshot, drop it from the manifest
        // anyway — we have no way to recover from a stuck snapshot,
        // and keeping it in the manifest just generates noise. The
        // worst case is a stuck snapshot on disk that the user has to
        // clear themselves via `tmutil thinlocalsnapshots /` later;
        // that's strictly better than the current "spam errors
        // forever" behaviour.
        var deleteFailures: [(snapshotID: String, error: String)] = []
        for snapshotID in snapshotIDsToDelete {
            do {
                _ = try commandRunner(["deletelocalsnapshots", snapshotID])
            } catch {
                deleteFailures.append((snapshotID, error.localizedDescription))
                // Log once per snapshot per session, not per prune cycle.
                backgroundLog.warning(
                    "APFS snapshot \(snapshotID, privacy: .public) delete failed; dropping from manifest to stop retry loop: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let remainingSnapshotIDs = Set(sortedManifest.suffix(maxCount).map(\.snapshotID))
        let remainingManifest = sortedManifest.filter { remainingSnapshotIDs.contains($0.snapshotID) }
        try saveAPFSSnapshotManifest(remainingManifest, at: manifestURL)

        // Re-throw the first delete failure ONLY if every delete
        // attempted failed (true I/O / tmutil-unavailable problem).
        // Partial failure → manifest still updated, no throw, no spam.
        if !deleteFailures.isEmpty && deleteFailures.count == snapshotIDsToDelete.count {
            throw NSError(
                domain: "VaultSyncService.APFSSnapshotPrune",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "All \(snapshotIDsToDelete.count) APFS snapshot deletes failed: \(deleteFailures.first?.error ?? "unknown error")",
                ]
            )
        }
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
        try await withCheckedThrowingContinuation { continuation in
            let race = VaultBookmarkResolutionRace(continuation: continuation)
            Task.detached(priority: .userInitiated) {
                guard let resolved = resolveVaultBookmark(bookmarkData) else {
                    race.resume(.failure(VaultBookmarkResolutionError.corrupted))
                    return
                }
                race.resume(.success(resolved))
            }
            Task.detached(priority: .utility) {
                try? await Task.sleep(for: timeout)
                race.resume(.failure(VaultBookmarkResolutionError.timedOut))
            }
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

    private func publishPostImportMaintenance(
        lifecycleToken: VaultLifecycleToken
    ) -> Bool {
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true) else {
            return false
        }
        publishVaultMutation(.vaultChanged)
        AppBootstrap.shared?.refreshAmbientManifest()
        AppBootstrap.shared?.scheduleHealthyVaultBodyCleanup()
        scheduleGraphRefreshAfterVaultImport()
        return true
    }

    private func recordInitialImportFailure(
        vaultURL: URL,
        lifecycleToken: VaultLifecycleToken,
        reason: String
    ) async {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: vaultURL,
            bookmarkExists: true,
            restoreFailed: false
        )
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true) else {
            return
        }
        recoveryIssue = VaultRecoveryIssue(snapshot: snapshot, reason: reason)
        AppBootstrap.shared?.uiState.showToast(reason, type: .error)
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
                Log.vault.warning(
                    "Vault restore failed before a recovery issue was detected; preserving local vault state."
                )
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

    /// USER REPORT 2026-05-12 v3 migration: `hasEverConnectedAVault` was
    /// added in `fa2c29f91` and is set on first `persistVaultSelection`
    /// going forward. Users who connected vaults BEFORE that commit have
    /// the flag unset, which makes the VaultReprompSheet incorrectly
    /// auto-prompt them after explicit disconnect (the post-update nag).
    ///
    /// This one-time migration detects "user has been using Epistemos
    /// for a while" via any of three signals and back-fills the flag:
    ///   - a bookmark currently exists (still has a vault)
    ///   - lastVaultPath is recorded (had a vault before)
    ///   - epistemos.setupComplete is true (finished onboarding)
    ///
    /// Idempotent — once the flag is true it stays true; the migration
    /// short-circuits on subsequent calls.
    fileprivate func migrateHasEverConnectedFlagIfNeeded() {
        guard !defaults.bool(forKey: Self.hasEverConnectedVaultKey) else { return }
        let hasBookmark = defaults.data(forKey: Self.bookmarkKey) != nil
        let hasLastPath = defaults.string(forKey: Self.lastVaultPathKey) != nil
        let setupComplete = defaults.bool(forKey: "epistemos.setupComplete")
        if hasBookmark || hasLastPath || setupComplete {
            defaults.set(true, forKey: Self.hasEverConnectedVaultKey)
            log.info("migrated hasEverConnectedAVault=true (bookmark=\(hasBookmark, privacy: .public) lastPath=\(hasLastPath, privacy: .public) setup=\(setupComplete, privacy: .public))")
        }
    }

    /// Restore vault from saved bookmark on app launch.
    /// Call from RootView.onAppear (after NSApp is alive).
    func restoreVaultFromBookmark() async {
        migrateHasEverConnectedFlagIfNeeded()
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

        // USER REPORT 2026-05-12 v2: crash-safe disconnect recovery.
        // If the app force-quit during disconnect (long teardown on
        // large vaults can take 30+ seconds), the in-progress flag
        // survives. Detect it here, clear the bookmark + flag, and
        // skip restoration — completing the user's intent even though
        // the original teardown was interrupted.
        if defaults.bool(forKey: Self.disconnectInProgressKey) {
            log.warning("Detected disconnect-in-progress flag from previous launch; completing disconnect by clearing bookmark + skipping restore.")
            clearPersistedVaultSelection()
            defaults.removeObject(forKey: Self.disconnectInProgressKey)
            isIndexing = false
            vaultActivityMessage = nil
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
        } else if Self.shouldMigrateLegacyVaultBookmarkDefaults() {
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
        } else {
            log.info("📦 No vault bookmark in isolated audit domain — legacy domains skipped")
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
        if let cached = pendingStartupResolvedBookmark,
           cached.bookmarkData == data {
            resolvedBookmark = cached.resolvedBookmark
            pendingStartupResolvedBookmark = nil
        } else {
            pendingStartupResolvedBookmark = nil
            do {
                resolvedBookmark = try await Self.resolveVaultBookmarkWithTimeout(data)
            } catch VaultBookmarkResolutionError.timedOut {
                handleRestoreFailure(
                    reason: "Vault bookmark resolution timed out — please reattach the vault folder",
                    bookmarkExists: true
                )
                return
            } catch {
                log.error(
                    "Failed to resolve the saved vault bookmark; preserving the saved vault selection for retry"
                )
                handleRestoreFailure(
                    reason: "📦 Failed to resolve vault bookmark",
                    bookmarkExists: true
                )
                return
            }
        }
        let url = resolvedBookmark.url
        let isStale = resolvedBookmark.isStale
        let usedSecurityScope = resolvedBookmark.usedSecurityScope
        log.info(
            "📦 Resolved bookmark → \(url.path, privacy: .private) (stale=\(isStale), securityScope=\(usedSecurityScope))"
        )

        if requiresSecurityScopedVaultAccess() && !usedSecurityScope {
            log.warning(
                "Saved vault bookmark is not security-scoped; preserving the saved vault selection for retry"
            )
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
            handleRestoreFailure(
                reason: "Security scope not granted for vault bookmark",
                bookmarkExists: true
            )
            return
        }

        let isReadableVault = await readableVaultURLAfterSecurityScopeSettle(url)
        if !isReadableVault {
            url.stopAccessingSecurityScopedResource()
            handleRestoreFailure(
                reason: "Vault directory not found or readable at \(url.path)",
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
            defaults.removeObject(forKey: Self.trustedSuspiciousVaultPathKey)
            handleRestoreFailure(
                reason: reason,
                bookmarkExists: true
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
            guard activeVaultMutationAdmissions.isEmpty else {
                log.error("Refusing synchronous vault replacement while file mutations are active; use switchToVaultAsync")
                return
            }
            stopWatching()
            guard !isWatching else { return }
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

        let vaultName = vaultURL.lastPathComponent

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
            vaultActivityMessage = "Connecting \"\(vaultName)\"... acquiring access"
            let gained = startSecurityScopedAccess(for: vaultURL)
            guard gained else {
                isIndexing = false
                recoveryIssue = nil
                vaultActivityMessage = nil
                log.error(
                    "Security scope not granted for candidate vault \(vaultURL.path, privacy: .public); keeping current vault active"
                )
                return false
            }
            beginScopeAlreadyAcquired = true
            acquiredCandidateSecurityScope = true
        }

        if acquiredCandidateSecurityScope,
           !(await readableVaultURLAfterSecurityScopeSettle(vaultURL)) {
            securityScopeStopOperation(vaultURL)
            vaultActivityMessage = nil
            log.error("Candidate vault is unavailable after security scope acquisition; keeping current vault active")
            return false
        }

        if isWatching {
            vaultActivityMessage = "Connecting \"\(vaultName)\"... releasing previous vault"
            let didClear = await stopWatchingAsync(preserveData: false, skipRecoverySnapshot: true)
            guard didClear else {
                if acquiredCandidateSecurityScope {
                    vaultURL.stopAccessingSecurityScopedResource()
                }
                vaultActivityMessage = nil
                return false
            }
        } else {
            vaultActivityMessage = "Connecting \"\(vaultName)\"... clearing stale state"
            let didClear = await clearDisconnectedDerivedLocalStateBeforeVaultSwitchIfNeeded()
            guard didClear else {
                vaultActivityMessage = nil
                return false
            }
        }

        vaultActivityMessage = "Connecting \"\(vaultName)\"... starting watcher"
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
        activateVaultLifecycle(for: vaultURL)
        let lifecycleToken = VaultLifecycleToken(
            lifecycleEpoch: vaultLifecycleEpoch,
            vaultPath: vaultURL.standardizedFileURL.path
        )
        VaultCrashRecorder.updateVaultURL(vaultURL)
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
        let initialSpotlightCursor = spotlightCursor(for: url)
        isIndexing = true
        beginVaultImportProgress(vaultName: vaultURL.lastPathComponent, phase: "Loading vault \"\(vaultURL.lastPathComponent)\"")
        let progressHandler: VaultIndexActor.VaultImportProgressHandler = { snapshot in
            await VaultImportProgressBridge.publish(snapshot, lifecycleToken: lifecycleToken)
        }
        let initialImportOperation = initialImportOperationOverride
        let hybridMigrationOperation = hybridMigrationOperationOverride
        let initialImportDerivedOperation = initialImportDerivedOperationOverride
        let initialImportDerivedApplyOperation = initialImportDerivedApplyOperationOverride
        let initialImportDerivedCompletionOperation = initialImportDerivedCompletionOperationOverride
        importTaskLifecycleToken = lifecycleToken
        importTask = Task {
            var didBecomeReady = false
            let canContinue: @MainActor @Sendable () -> Bool = { [weak self] in
                guard let self else { return false }
                return !Task.isCancelled
                    && self.vaultLifecycleTokenIsCurrent(
                        lifecycleToken,
                        requireOperational: true
                    )
            }
            defer {
                if self.importTaskLifecycleToken == lifecycleToken {
                    self.finishVaultImportProgress(keepSummary: didBecomeReady)
                    self.vaultActivityMessage = nil
                    self.isIndexing = false
                    self.importTaskLifecycleToken = nil
                    self.importTask = nil
                }
            }
            if let actor {
                await Self.performHybridMigrations(
                    actor: actor,
                    operation: hybridMigrationOperation
                )
            }
            guard !Task.isCancelled,
                  self.vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true)
            else {
                return
            }
            let importResult: InitialImportResult
            if let initialImportOperation {
                importResult = InitialImportResult(
                    didImport: await initialImportOperation(url),
                    snapshot: nil,
                    suppressedSearchBatchID: nil
                )
            } else {
                importResult = await Self.performInitialImport(
                    actor: actor,
                    url: url,
                    searchService: svc,
                    progressHandler: progressHandler
                )
            }
            guard !Task.isCancelled,
                  self.vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true)
            else {
                if let actor,
                   let svc,
                   let batchID = importResult.suppressedSearchBatchID {
                    await actor.discardSuppressedSearchMutationBatch(
                        id: batchID,
                        service: svc
                    )
                }
                return
            }
            let didImport = importResult.didImport
            if didImport {
                if let snapshot = importResult.snapshot {
                    await progressHandler(
                        snapshot.withPhase("Starting background indexes", isComplete: false)
                    )
                }
                guard canContinue(), let actor else {
                    if let actor,
                       let svc,
                       let batchID = importResult.suppressedSearchBatchID {
                        await actor.discardSuppressedSearchMutationBatch(
                            id: batchID,
                            service: svc
                        )
                    }
                    await initialImportDerivedCompletionOperation?()
                    return
                }

                let recallWorkload =
                    importResult.snapshot?.postImportRecallWorkload ?? .rebuild
                let derivedResult: InitialImportDerivedResult?
                if let initialImportDerivedOperation {
                    derivedResult = InitialImportDerivedResult(
                        searchSynchronizationReceipt: nil,
                        recallMutation: await initialImportDerivedOperation(
                            actor,
                            svc,
                            recallWorkload
                        ),
                        spotlightJournalReceipt: nil
                    )
                } else {
                    derivedResult = await Self.performInitialImportDerivedWork(
                        actor: actor,
                        searchService: svc,
                        vaultURL: url,
                        spotlightCursor: initialSpotlightCursor,
                        recallWorkload: recallWorkload,
                        suppressedSearchBatchID: importResult.suppressedSearchBatchID,
                        canContinue: canContinue
                    )
                }
                guard canContinue() else {
                    await initialImportDerivedCompletionOperation?()
                    return
                }
                guard let derivedResult else {
                    await self.recordInitialImportFailure(
                        vaultURL: url,
                        lifecycleToken: lifecycleToken,
                        reason: "Vault loaded, but a required local index could not be prepared. Epistemos kept readiness closed so it can retry safely."
                    )
                    await initialImportDerivedCompletionOperation?()
                    return
                }
                if let initialImportDerivedApplyOperation {
                    initialImportDerivedApplyOperation(derivedResult.recallMutation)
                } else {
                    Self.applyInstantRecallMutation(derivedResult.recallMutation)
                }
                guard canContinue() else {
                    await initialImportDerivedCompletionOperation?()
                    return
                }

                var finalSpotlightReceipt = derivedResult.spotlightJournalReceipt
                var successfulWatcherDrainCount = 0
                while true {
                    guard canContinue() else {
                        await initialImportDerivedCompletionOperation?()
                        return
                    }
                    self.fileWatcherState.debounceTask?.cancel()
                    self.fileWatcherState.debounceTask = nil

                    if self.hasPendingVaultFileSystemChanges,
                       successfulWatcherDrainCount
                            >= Self.maxInitialReadinessWatcherDrains {
                        await self.recordInitialImportFailure(
                            vaultURL: url,
                            lifecycleToken: lifecycleToken,
                            reason: "Vault files kept changing during startup. Epistemos preserved the remaining changes and kept readiness closed so it can retry safely."
                        )
                        await initialImportDerivedCompletionOperation?()
                        return
                    }

                    let bufferedWatcherFence =
                        self.drainAndProcessPendingVaultFileSystemChanges(
                            shouldIgnore: false,
                            lifecycleToken: lifecycleToken,
                            allowBeforeInitialImportCompletion: true
                        )
                    if let bufferedWatcherFence {
                        let bufferedResult = await bufferedWatcherFence.wait()
                        guard canContinue() else {
                            await initialImportDerivedCompletionOperation?()
                            return
                        }
                        guard bufferedResult?.didProcess == true else {
                            await self.recordInitialImportFailure(
                                vaultURL: url,
                                lifecycleToken: lifecycleToken,
                                reason: "Vault changes arrived during startup but could not be reconciled. Epistemos preserved them for a safe retry and did not mark the vault ready."
                            )
                            await initialImportDerivedCompletionOperation?()
                            return
                        }
                        successfulWatcherDrainCount += 1

                        if let currentSpotlightReceipt = finalSpotlightReceipt {
                            do {
                                finalSpotlightReceipt = try await actor.spotlightReindexAll(
                                    since: currentSpotlightReceipt.candidateCursor
                                        ?? initialSpotlightCursor
                                )
                            } catch {
                                await self.recordInitialImportFailure(
                                    vaultURL: url,
                                    lifecycleToken: lifecycleToken,
                                    reason: "Vault changes were reconciled, but system search did not acknowledge the startup catch-up. Epistemos kept readiness closed so no stale completion is claimed."
                                )
                                await initialImportDerivedCompletionOperation?()
                                return
                            }
                        }
                        continue
                    }

                    let pendingRevision = self.fileWatcherState.pendingRevision
                    let recoveryIssue = await self.detectRecoveryIssue(
                        candidateVaultURL: url,
                        bookmarkExists: true,
                        restoreFailed: false,
                        initialImportCompletedOverride: true
                    )
                    guard canContinue() else {
                        await initialImportDerivedCompletionOperation?()
                        return
                    }
                    guard pendingRevision == self.fileWatcherState.pendingRevision,
                          !self.hasPendingVaultFileSystemChanges,
                          self.vaultFileSystemProcessorTask == nil,
                          self.acceptedVaultFileSystemBatchHead
                            == self.acceptedVaultFileSystemBatches.count
                    else {
                        continue
                    }

                    self.recoveryIssue = recoveryIssue
                    guard recoveryIssue == nil else {
                        AppBootstrap.shared?.uiState.showToast(
                            "Vault import needs recovery before Epistemos can mark it ready.",
                            type: .error
                        )
                        await initialImportDerivedCompletionOperation?()
                        return
                    }

                    if let finalSpotlightReceipt {
                        self.persistSpotlightCursor(finalSpotlightReceipt, for: url)
                    }
                    self.initialImportCompleted = true
                    guard self.publishPostImportMaintenance(lifecycleToken: lifecycleToken) else {
                        await initialImportDerivedCompletionOperation?()
                        return
                    }
                    break
                }
                if let snapshot = importResult.snapshot {
                    await progressHandler(snapshot.withPhase("Vault ready", isComplete: true))
                }
                guard canContinue() else {
                    await initialImportDerivedCompletionOperation?()
                    return
                }
                didBecomeReady = true
                AppBootstrap.shared?.uiState.showToast(
                    "Vault loaded: \(url.lastPathComponent)",
                    type: .success
                )
                await initialImportDerivedCompletionOperation?()
            } else {
                AppBootstrap.shared?.uiState.showToast(
                    "Couldn't load vault \"\(url.lastPathComponent)\".",
                    type: .error
                )
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

    private func readableVaultURLAfterSecurityScopeSettle(_ url: URL) async -> Bool {
        let delaysNanoseconds: [UInt64] = [0, 75_000_000, 150_000_000, 300_000_000, 600_000_000]
        for delay in delaysNanoseconds {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            if Self.isReadableVaultDirectory(url) {
                return true
            }
        }
        return false
    }

    private nonisolated static func isReadableVaultDirectory(_ url: URL) -> Bool {
        let path = url.path
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return fileManager.isReadableFile(atPath: path)
    }

    /// Stop watching and release resources.
    /// - Parameter preserveData: When `true`, keeps SwiftData models intact so the
    ///   next launch can do an incremental import (~instant) instead of a full reimport (~13s).
    ///   Pass `false` (default) for vault switches/disconnects to clear stale data.
    func stopWatching(preserveData: Bool = false) {
        beginVaultMutationDrain()
        quiesceVaultIngressForDrain()
        guard activeVaultMutationAdmissions.isEmpty, importTask == nil else {
            Task { @MainActor [weak self] in
                _ = await self?.stopWatchingAsync(preserveData: preserveData)
            }
            return
        }
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
    func stopWatchingAsync(preserveData: Bool = false, skipRecoverySnapshot: Bool = false) async -> Bool {
        beginVaultMutationDrain()
        quiesceVaultIngressForDrain()
        await waitForVaultMutationDrain()
        let initialImportTask = importTask
        await initialImportTask?.value
        prepareToStopWatching()

        if preserveData {
            finalizeStoppedWatching(preserveData: true)
            return true
        }

        var didClearLocalData = true
        // USER REPORT 2026-05-12 v2 perf: explicit disconnect intentionally
        // forgets data — the recovery snapshot is wasted I/O. Default
        // path (recovery, replace-vault, etc.) keeps the snapshot for
        // safety; only the disconnect button opts out. The snapshot is
        // the dominant cost on large vaults (APFS clone + SQLite copies);
        // skipping it converts "30s wait" into "1-3s wait" without
        // changing the destructive-clear semantics.
        if !skipRecoverySnapshot {
            do {
                try await snapshotLocalStateOffMain()
            } catch {
                didClearLocalData = false
                log.error("Failed to snapshot local state before clear; aborting destructive stop: \(error.localizedDescription, privacy: .public)")
                handleSnapshotFailureBeforeDestructiveClear(error)
            }
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

    private func quiesceVaultIngressForDrain() {
        importTask?.cancel()
        autoSaveTask?.cancel()
        versionCaptureTask?.cancel()
        manifestRefreshTask?.cancel()
        inFlightDirtySaveTask?.cancel()
        stopBackgroundMaintenanceTimers()
        stopFileWatcher()
    }

    private func prepareToStopWatching() {
        quiesceVaultIngressForDrain()
        importTask = nil
        importTaskLifecycleToken = nil
        autoSaveTask = nil
        versionCaptureTask = nil
        manifestRefreshTask = nil
        inFlightDirtySaveTask = nil
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
            securityScopeStopOperation(url)
            isSecurityScoped = false
        }

        vaultURL = nil
        disconnectVaultLifecycle()
        VaultCrashRecorder.updateVaultURL(nil)
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
    /// Called on explicit vault transitions/resets after recovery safeguards run.
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
            // A partial delete before the single save() can leave staged bulk
            // deletes armed on the SHARED mainContext; a later unrelated save()
            // (e.g. savePage) would then flush them, dropping data this clear
            // never committed. Roll back so a failed clear leaves the context
            // clean rather than dirty (no-op if delete(model:) committed
            // immediately).
            context.rollback()
            Log.vault.error("Failed to clear vault data: \(error.localizedDescription, privacy: .public)")
        }

        AppBootstrap.shared?.clearVaultLifecycleRuntimeState(
            reason: "VaultSyncService cleared local vault data"
        )
    }

    private nonisolated static func performHybridMigrations(
        actor: VaultIndexActor,
        operation: HybridMigrationOperation?
    ) async {
        if let operation {
            await operation(actor)
            return
        }
        await actor.migrateToHybridSync()
        await actor.migrateFromExternalStorage()
    }

    private nonisolated static func performInitialImportDerivedWork(
        actor: VaultIndexActor,
        searchService: SearchIndexService?,
        vaultURL: URL,
        spotlightCursor: Date?,
        recallWorkload: VaultPostImportRecallWorkload,
        suppressedSearchBatchID: SearchIndexMutationBatchID?,
        canContinue: @escaping @MainActor @Sendable () -> Bool
    ) async -> InitialImportDerivedResult? {
        guard await canContinue() else {
            if let suppressedSearchBatchID,
               let searchService {
                await actor.discardSuppressedSearchMutationBatch(
                    id: suppressedSearchBatchID,
                    service: searchService
                )
            }
            return nil
        }
        guard let searchService else {
            Log.vault.error("Initial Search index preparation failed: no Search service")
            return nil
        }
        guard let searchSynchronizationReceipt = await Self.performSearchIndexDiffSync(
            from: actor,
            searchService: searchService,
            suppressedSearchBatchID: suppressedSearchBatchID,
            canContinue: canContinue
        ) else { return nil }
        guard await canContinue() else { return nil }

        let spotlightJournalReceipt: VaultSpotlightJournalReceipt
        do {
            spotlightJournalReceipt = try await actor.spotlightReindexAll(
                since: spotlightCursor
            )
        } catch {
            Log.vault.error(
                "Initial Spotlight journal request failed for \(vaultURL.lastPathComponent, privacy: .private): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        guard await canContinue() else { return nil }

        guard let mutation = await Self.prepareInstantRecallMutation(
            from: actor,
            workload: recallWorkload
        ) else {
            Log.vault.error("Initial Instant Recall preparation failed")
            return nil
        }
        guard await canContinue() else { return nil }
        return InitialImportDerivedResult(
            searchSynchronizationReceipt: searchSynchronizationReceipt,
            recallMutation: mutation,
            spotlightJournalReceipt: spotlightJournalReceipt
        )
    }

    private nonisolated static func performInitialImport(
        actor: VaultIndexActor?,
        url: URL,
        searchService: SearchIndexService?,
        progressHandler: VaultIndexActor.VaultImportProgressHandler? = nil
    ) async -> InitialImportResult {
        let importInterval = Log.vaultPerf.beginInterval("initialVaultImport")
        defer { Log.vaultPerf.endInterval("initialVaultImport", importInterval) }
        guard let actor else {
            Log.vault.error("Initial vault import failed: no active VaultIndexActor")
            return InitialImportResult(
                didImport: false,
                snapshot: nil,
                suppressedSearchBatchID: nil
            )
        }

        let suppressedSearchBatchID: SearchIndexMutationBatchID?
        if let searchService {
            suppressedSearchBatchID = await actor.beginSuppressedSearchMutationBatch(
                for: searchService
            )
            guard suppressedSearchBatchID != nil else {
                Log.vault.error("Initial vault import failed: Search mutation batch could not be opened")
                return InitialImportResult(
                    didImport: false,
                    snapshot: nil,
                    suppressedSearchBatchID: nil
                )
            }
        } else {
            suppressedSearchBatchID = nil
        }
        do {
            guard let importSnapshot = try await actor.importVault(
                from: url,
                progress: progressHandler,
                searchMutationBatchID: suppressedSearchBatchID
            ) else {
                if let suppressedSearchBatchID,
                   let searchService {
                    await actor.discardSuppressedSearchMutationBatch(
                        id: suppressedSearchBatchID,
                        service: searchService
                    )
                }
                Log.vault.error("Initial vault import failed: importer returned no snapshot")
                return InitialImportResult(
                    didImport: false,
                    snapshot: nil,
                    suppressedSearchBatchID: nil
                )
            }
            Log.vault.info("Initial vault import complete")

            await MainActor.run {
                AppBootstrap.shared?.graphState.needsRefresh = true
            }
            return InitialImportResult(
                didImport: true,
                snapshot: importSnapshot,
                suppressedSearchBatchID: suppressedSearchBatchID
            )
        } catch {
            if let suppressedSearchBatchID,
               let searchService {
                await actor.discardSuppressedSearchMutationBatch(
                    id: suppressedSearchBatchID,
                    service: searchService
                )
            }
            Log.vault.error(
                "Initial vault import failed: \(error.localizedDescription, privacy: .public)")
            return InitialImportResult(
                didImport: false,
                snapshot: nil,
                suppressedSearchBatchID: nil
            )
        }
    }

    private nonisolated static let instantRecallRebuildBodyCharacterLimit = 16_384

    private nonisolated static func scheduleSpotlightReindex(from actor: VaultIndexActor?) {
        guard let actor else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await actor.spotlightReindexAll(since: nil)
            } catch {
                Log.vault.error(
                    "Scheduled Spotlight journal request failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private nonisolated static func scheduleSearchIndexDiffSync(
        from actor: VaultIndexActor?,
        searchService: SearchIndexService?
    ) {
        guard let actor, let searchService else { return }
        Task.detached(priority: .utility) {
            _ = await performSearchIndexDiffSync(
                from: actor,
                searchService: searchService
            )
        }
    }

    private nonisolated static func performSearchIndexDiffSync(
        from actor: VaultIndexActor,
        searchService: SearchIndexService?,
        suppressedSearchBatchID: SearchIndexMutationBatchID? = nil,
        canContinue: (@MainActor @Sendable () -> Bool)? = nil
    ) async -> SearchIndexSynchronizationReceipt? {
        guard let searchService else { return nil }
        let diffSyncInterval = Log.vaultPerf.beginInterval("initialVaultDiffSync")
        defer { Log.vaultPerf.endInterval("initialVaultDiffSync", diffSyncInterval) }

        if let canContinue, !(await canContinue()) {
            return nil
        }

        let suppressedSnapshot: SuppressedSearchMutationBatchSnapshot?
        if let suppressedSearchBatchID {
            guard let snapshot = await actor.suppressedSearchMutationBatchSnapshot(
                id: suppressedSearchBatchID,
                service: searchService
            ), snapshot.isValid else {
                Log.vault.error("FTS5 diff-sync stopped: suppressed Search mutation batch was missing or invalid")
                return nil
            }
            suppressedSnapshot = snapshot
        } else {
            suppressedSnapshot = nil
        }

        let synchronizationReceipt: SearchIndexSynchronizationReceipt
        if let suppressedSnapshot,
           let preparedDiff = suppressedSnapshot.preparedDiff {
            synchronizationReceipt = SearchIndexSynchronizationReceipt(
                suppressedImport: suppressedSnapshot.committed,
                diff: preparedDiff
            )
        } else {
            guard let timestamps = await actor.requiredPageTimestampsForSearchDiff() else {
                Log.vault.error("FTS5 diff-sync stopped: required page timestamps could not be read")
                return nil
            }
            let diffReceipt: SearchIndexDiffReceipt
            do {
                diffReceipt = try await searchService.diffSync(
                    swiftDataPages: timestamps,
                    fullPageProvider: { id in await actor.fullPageData(for: id) },
                    notifyObservers: false
                )
            } catch {
                Log.vault.error("FTS5 diff-sync failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }

            if let suppressedSearchBatchID,
               let suppressedSnapshot {
                guard let prepared = await actor.prepareSuppressedSearchMutationBatchReceipt(
                    id: suppressedSearchBatchID,
                    expectedRevision: suppressedSnapshot.revision,
                    service: searchService,
                    diff: diffReceipt
                ) else {
                    Log.vault.error("FTS5 diff-sync stopped: suppressed Search mutation batch changed before publication")
                    return nil
                }
                synchronizationReceipt = prepared
            } else {
                synchronizationReceipt = SearchIndexSynchronizationReceipt(
                    suppressedImport: .empty,
                    diff: diffReceipt
                )
            }
        }

        if !synchronizationReceipt.changedDependencies.isEmpty {
            let didNotify = await searchService.notifyIndexChangedAsync(
                synchronizationReceipt.changedDependencies,
                when: canContinue
            )
            guard didNotify else { return nil }
        }
        if let suppressedSearchBatchID,
           let suppressedSnapshot {
            guard await actor.consumeSuppressedSearchMutationBatch(
                id: suppressedSearchBatchID,
                expectedRevision: suppressedSnapshot.revision,
                service: searchService
            ) else {
                Log.vault.error("FTS5 diff-sync stopped: published Search mutation batch could not be consumed exactly")
                return nil
            }
        }
        return synchronizationReceipt
    }

    private nonisolated static func scheduleInstantRecallIndexRebuild(from actor: VaultIndexActor?) {
        guard let actor else { return }
        Task.detached(priority: .utility) {
            guard let mutation = await prepareInstantRecallMutation(
                from: actor,
                workload: .rebuild
            ) else {
                Log.vault.error("Scheduled Instant Recall rebuild preparation failed")
                return
            }
            await MainActor.run {
                applyInstantRecallMutation(mutation)
            }
        }
    }

    private nonisolated static func scheduleInstantRecallPostImportUpdate(
        from actor: VaultIndexActor?,
        snapshot: VaultImportProgressSnapshot?
    ) {
        guard let actor else { return }
        let workload = snapshot?.postImportRecallWorkload ?? .rebuild
        guard workload != .none else { return }

        Task.detached(priority: .utility) {
            guard let mutation = await prepareInstantRecallMutation(
                from: actor,
                workload: workload
            ) else {
                Log.vault.error("Scheduled Instant Recall update preparation failed")
                return
            }
            await MainActor.run {
                applyInstantRecallMutation(mutation)
            }
        }
    }

    private nonisolated static func prepareInstantRecallMutation(
        from actor: VaultIndexActor,
        workload: VaultPostImportRecallWorkload
    ) async -> VaultInstantRecallMutation? {
        switch workload {
        case .none:
            return .some(.none)
        case .incremental(let changedPageIDs, let deletedPageIDs):
            var changedNotes: [VaultInstantRecallNote] = []
            changedNotes.reserveCapacity(changedPageIDs.count)
            for pageID in changedPageIDs {
                guard let page = await actor.fullPageData(for: pageID) else {
                    Log.vault.error(
                        "Instant Recall preparation could not resolve required page \(pageID, privacy: .private)"
                    )
                    return nil
                }
                changedNotes.append(
                    VaultInstantRecallNote(
                        id: pageID,
                        text: boundedInstantRecallText(
                            title: page.title,
                            body: page.body,
                            tags: page.tags
                        )
                    )
                )
            }
            return .incremental(
                changedNotes: changedNotes,
                deletedPageIDs: deletedPageIDs
            )
        case .rebuild:
            guard let pages = await actor.requiredPagesForInstantRecallRebuild() else {
                Log.vault.error("Instant Recall rebuild source fetch failed")
                return nil
            }
            var documents: [String: String] = [:]
            documents.reserveCapacity(pages.count)
            for page in pages {
                let text = boundedInstantRecallText(
                    title: page.title,
                    body: page.body,
                    tags: page.tags
                )
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    documents[page.id] = text
                }
            }
            return .rebuild(documents: documents)
        }
    }

    private static func applyInstantRecallMutation(_ mutation: VaultInstantRecallMutation) {
        guard let service = AppBootstrap.shared?.instantRecallService else { return }
        switch mutation {
        case .none:
            return
        case .incremental(let changedNotes, let deletedPageIDs):
            for pageID in deletedPageIDs {
                service.removeNote(noteId: pageID)
            }
            for note in changedNotes {
                service.indexNote(noteId: note.id, text: note.text)
            }
        case .rebuild(let documents):
            service.replaceIndex(with: documents)
        }
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
    /// for callers that need the matched IDs.
    func searchIndex(query: String) async -> [String] {
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                do {
                    let fused = try await svc.fusedSearchAsync(query: checkedQuery)
                    return fused.map(\.parentDocID)
                } catch {
                    log.error("RRF fused searchIndex failed; falling back to legacy page search: \(error.localizedDescription, privacy: .public)")
                }
            }
            let results = try await svc.searchAsync(query: checkedQuery)
            return results.map(\.pageId)
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
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                do {
                    let fused = try svc.fusedSearch(
                        query: checkedQuery,
                        weights: FusionWeights(maxResults: checkedLimit)
                    )
                    return fused.map(Self.mapFusedToSearchResult)
                } catch {
                    log.error("RRF fused searchFull failed; falling back to legacy page search: \(error.localizedDescription, privacy: .public)")
                }
            }
            let results = try svc.search(query: checkedQuery, limit: checkedLimit)
            return results
        } catch {
            log.error("searchFull failed (fusion=\(RRFFusionFlags.isEnabled, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func searchFullAsync(query: String, limit: Int = 20) async -> [SearchResult] {
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        guard let svc = searchService else { return [] }
        do {
            if RRFFusionFlags.isEnabled {
                do {
                    let fused = try await svc.fusedSearchAsync(
                        query: checkedQuery,
                        weights: FusionWeights(maxResults: checkedLimit)
                    )
                    return fused.map(Self.mapFusedToSearchResult)
                } catch {
                    log.error("RRF fused searchFullAsync failed; falling back to legacy page search: \(error.localizedDescription, privacy: .public)")
                }
            }
            let results = try await svc.searchAsync(query: checkedQuery, limit: checkedLimit)
            return results
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
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        guard let svc = searchService else { return [] }
        do {
            return try await svc.searchBlocksAsync(query: checkedQuery, limit: checkedLimit)
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
            defer {
                Log.vaultPerf.endInterval("rebuildIndex", interval)
                isIndexing = false
            }
            guard let pages = await actor.requiredPagesForSearchRebuild() else {
                log.error("FTS5 index rebuild stopped: required pages could not be read")
                return
            }
            do {
                try await svc.rebuildFromSwiftDataAsync(pages)
            } catch {
                log.error("FTS5 index rebuild failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Migration


    // MARK: - Sync from Vault

    /// Pull external .md changes from the vault folder.
    /// Returns conflicts (both sides changed) for the UI to resolve.
    func syncFromVault() async -> [VaultSyncConflict] {
        guard let vaultURL,
              let actor = indexActor,
              let lifecycleToken = currentOperationalVaultLifecycleToken(for: vaultURL)
        else { return [] }
        let interval = Log.vaultPerf.beginInterval("syncFromVault")
        defer { Log.vaultPerf.endInterval("syncFromVault", interval) }
        isIndexing = true
        beginVaultImportProgress(vaultName: vaultURL.lastPathComponent, phase: "Syncing vault \"\(vaultURL.lastPathComponent)\"")
        defer {
            finishVaultImportProgress(keepSummary: true)
            vaultActivityMessage = nil
            isIndexing = false
        }
        let progressHandler: VaultIndexActor.VaultImportProgressHandler = { snapshot in
            await VaultImportProgressBridge.publish(snapshot, lifecycleToken: lifecycleToken)
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
        guard vaultURL != nil else {
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

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
            guard let page = self.fetchFirst(desc, in: context, label: "saved page body snapshot") else {
                return
            }
            let body = self.latestAvailableBody(for: page, pageId: pageId)
            _ = await self.savePageBodyFileFirst(pageId: pageId, body: body)
        }
        return task
    }

    private func preparePageForExport(pageId: String, context: ModelContext) {
        NoteFileStorage.requestFlush(pageId: pageId)

        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "page export preparation") else {
            return
        }
        page.needsVaultSync = true
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
    /// The read-side async cascade in `VaultIndexActor`, `SpotlightIndexer`,
    /// `EntityExtractor`, and `GraphState` now routes through the R.3 gateway
    /// for every read-facing code path.
    private func latestAvailableBody(for page: SDPage, pageId: String) -> String {
        if let liveBody = NoteWindowManager.shared.editorBody(for: pageId) {
            return liveBody
        }
        if page.needsVaultSync {
            if let pendingBody = NoteFileStorage.pendingBodyForImmediateRead(pageId: pageId) {
                return pendingBody
            }
            if !page.body.isEmpty {
                return page.body
            }
            if let localBody = NoteFileStorage.stagedOrPersistedDraftBody(pageId: pageId) {
                return localBody
            }
        }
        return page.loadBody(mapped: true)
    }

    private func scheduleBlockMirrorSync(pageId: String, body: String) {
        guard !pageId.isEmpty else { return }
        let container = modelContainer
        Task {
            await BlockMirrorSyncCoordinator.shared.scheduleSync(
                pageId: pageId,
                body: body,
                modelContainer: container
            )
        }
    }

    @discardableResult
    func commitPageIdentityFileFirst(
        pageId: String,
        title: String,
        tags: [String],
        folder: SDFolder?,
        subfolder: String?,
        markdownBody: String?
    ) async -> PageIdentityCommitResult {
        guard let admission = registerVaultMutation() else { return .rejected }
        defer { finishVaultMutation(admission) }
        _ = issuePageBodySaveGeneration(pageId: pageId)
        await pageFileMutationGate.acquire(pageId: pageId)
        guard !Task.isCancelled,
              vaultMutationAdmissionIsCurrent(admission)
        else {
            await pageFileMutationGate.release(pageId: pageId)
            return .rejected
        }
        let result = await performPageIdentityFileFirstCommit(
            pageId: pageId,
            title: title,
            tags: tags,
            folder: folder,
            subfolder: subfolder,
            markdownBody: markdownBody,
            admission: admission
        )
        await pageFileMutationGate.release(pageId: pageId)
        return result
    }

    private func performPageIdentityFileFirstCommit(
        pageId: String,
        title: String,
        tags: [String],
        folder: SDFolder?,
        subfolder: String?,
        markdownBody: String?,
        admission: VaultMutationAdmission
    ) async -> PageIdentityCommitResult {
        guard let vaultURL,
              vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL)
        else {
            log.warning("Cannot commit page identity: no vault URL")
            return .rejected
        }
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "page identity transaction") else {
            return .rejected
        }

        let initialTargetFingerprint = pageIdentityTargetFingerprint(
            folder: folder,
            subfolder: subfolder
        )
        let initialDraftFingerprint = pageIdentityDraftFingerprint(for: page)
        let localDraftBody = initialDraftFingerprint.liveBody
            ?? (page.needsVaultSync
                ? (initialDraftFingerprint.pendingBody
                    ?? (!page.body.isEmpty ? page.body : nil))
                : nil)
        var snapshot = PageIdentityTransactionSnapshot(
            page: page,
            fileData: nil,
            diskBody: page.body,
            localDraftBody: localDraftBody
        )
        let originalURL = snapshot.filePath.map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
        let originalFileData: Data?
        if let originalURL {
            do {
                originalFileData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: originalURL)
                }.value
            } catch {
                log.error(
                    "Refusing note identity mutation without rollback bytes: \(error.localizedDescription, privacy: .public)"
                )
                return .rejected
            }
        } else {
            originalFileData = nil
        }

        guard snapshot.stillMatches(page),
              initialDraftFingerprint == pageIdentityDraftFingerprint(for: page),
              pageIdentityTargetStillMatches(
                initialTargetFingerprint,
                folder: folder,
                subfolder: subfolder
              )
        else {
            log.warning("Refusing note identity mutation after its source state changed during preflight")
            return .rejected
        }
        let originalBody: String
        do {
            originalBody = try Self.pageIdentityBody(
                from: originalFileData,
                fileURL: originalURL,
                fallback: localDraftBody ?? snapshot.inlineBody
            )
        } catch {
            log.error("Refusing note identity mutation with undecodable source bytes")
            return .rejected
        }
        snapshot.fileData = originalFileData
        snapshot.diskBody = originalBody
        let forwardBody = markdownBody ?? localDraftBody ?? originalBody
        var forwardFrontMatter = snapshot.frontMatter
        if let originalURL,
           let originalFileData,
           VaultIndexActor.shouldWriteMarkdownFrontMatter(to: originalURL)
        {
            guard let originalSource = String(data: originalFileData, encoding: .utf8) else {
                return .rejected
            }
            let currentFrontMatter = VaultIndexActor.parseFrontMatter(originalSource).0
            forwardFrontMatter = currentFrontMatter
            let currentBodyHash = SDPage.bodyHash(originalBody)
            guard forwardBody == originalBody
                    || snapshot.lastSyncedBodyHash == currentBodyHash
            else {
                log.warning("Refusing note identity mutation after external body content changed")
                return .rejected
            }
        }
        let titleChanged = title != snapshot.title
        let locationChanged = folder?.id != snapshot.folder?.id || subfolder != snapshot.subfolder
        let destinationURL = Self.pageIdentityDestinationURL(
            originalURL: originalURL,
            title: title,
            subfolder: subfolder,
            vaultURL: vaultURL,
            renameFile: titleChanged,
            moveFile: locationChanged
        )
        let forwardData: Data
        if VaultIndexActor.shouldWriteMarkdownFrontMatter(to: destinationURL) {
            forwardData = Data(VaultIndexActor.buildMarkdownSource(
                pageId: page.id,
                title: title,
                tags: tags,
                emoji: snapshot.emoji,
                isJournal: snapshot.isJournal,
                journalDate: snapshot.journalDate,
                parentPageId: snapshot.parentPageId,
                templateId: snapshot.templateId,
                frontMatter: forwardFrontMatter,
                body: forwardBody
            ).utf8)
        } else if markdownBody == nil,
                  !snapshot.needsVaultSync,
                  let originalFileData
        {
            forwardData = originalFileData
        } else {
            forwardData = Data(forwardBody.utf8)
        }

        let writeURL = originalURL ?? destinationURL
        let expectedBaseline = originalFileData.map { VaultFileBaseline.contents($0) } ?? .absent
        var receipt: PageIdentityFileMutationReceipt?
        do {
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                return .rejected
            }
            if let pageIdentityBeforeForwardWriteOverride {
                try await pageIdentityBeforeForwardWriteOverride(page.id, writeURL)
            }
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                return .rejected
            }
            let writtenBaseline = try await Task.detached(priority: .userInitiated) {
                try AtomicVaultWriter.writeSynchronously(
                    forwardData,
                    to: writeURL,
                    ifCurrentMatches: expectedBaseline
                )
            }.value
            guard writtenBaseline == .contents(forwardData) else {
                return .rejected
            }
            receipt = PageIdentityFileMutationReceipt(
                originalURL: originalURL,
                originalData: originalFileData,
                forwardData: forwardData,
                currentURL: writeURL,
                moved: false
            )
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                throw PageIdentityTransactionError.vaultLifecycleChanged
            }

            if let pageIdentityAfterForwardWriteOverride {
                try await pageIdentityAfterForwardWriteOverride(page.id, writeURL)
            }
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                throw PageIdentityTransactionError.vaultLifecycleChanged
            }

            if writeURL != destinationURL {
                try await Task.detached(priority: .userInitiated) {
                    try CoordinatedVaultFileMutation.moveItem(
                        at: writeURL,
                        to: destinationURL,
                        ifSourceMatches: .contents(forwardData)
                    )
                }.value
                receipt?.currentURL = destinationURL
                receipt?.moved = true
            }
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                throw PageIdentityTransactionError.vaultLifecycleChanged
            }
        } catch {
            if receipt == nil {
                let observedBaseline = try? Self.observedVaultFileBaseline(at: writeURL)
                if observedBaseline == expectedBaseline {
                    log.error(
                        "Refusing note identity mutation after its forward write was not applied: \(error.localizedDescription, privacy: .public)"
                    )
                    return .rejected
                }
                if observedBaseline == .contents(forwardData) {
                    receipt = PageIdentityFileMutationReceipt(
                        originalURL: originalURL,
                        originalData: originalFileData,
                        forwardData: forwardData,
                        currentURL: writeURL,
                        moved: false
                    )
                } else {
                    recordPageIdentityRecoveryIssue(
                        pageId: page.id,
                        reason: "Epistemos could not prove whether a failed note write changed the vault file. The current bytes were preserved for reconciliation."
                    )
                    return .recoveryRequired
                }
            }

            if writeURL != destinationURL,
               receipt?.currentURL == writeURL
            {
                let sourceBaseline = try? Self.observedVaultFileBaseline(at: writeURL)
                let destinationBaseline = try? Self.observedVaultFileBaseline(at: destinationURL)
                if sourceBaseline == .contents(forwardData) {
                    // The move did not apply; rollback still owns the source bytes.
                } else if sourceBaseline == .absent,
                          destinationBaseline == .contents(forwardData)
                {
                    receipt?.currentURL = destinationURL
                    receipt?.moved = true
                } else {
                    recordPageIdentityRecoveryIssue(
                        pageId: page.id,
                        reason: "Epistemos could not prove the outcome of a failed note move. Both paths were preserved for reconciliation."
                    )
                    return .recoveryRequired
                }
            }
            guard let receipt else { return .recoveryRequired }
            return await pageIdentityRollbackResult(
                page: page,
                snapshot: snapshot,
                receipt: receipt,
                context: context,
                failure: "note file mutation",
                metadataWasApplied: false,
                expectedAppliedDraft: initialDraftFingerprint
            )
        }

        guard let receipt else { return .rejected }
        let finalBytesStillMatch = await Task.detached(priority: .userInitiated) {
            (try? Data(contentsOf: receipt.currentURL)) == receipt.forwardData
        }.value
        guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL),
              finalBytesStillMatch,
              snapshot.stillMatches(page),
              initialDraftFingerprint == pageIdentityDraftFingerprint(for: page),
              pageIdentityTargetStillMatches(
                initialTargetFingerprint,
                folder: folder,
                subfolder: subfolder
              )
        else {
            return await pageIdentityRollbackResult(
                page: page,
                snapshot: snapshot,
                receipt: receipt,
                context: context,
                failure: "note state revalidation",
                metadataWasApplied: false,
                expectedAppliedDraft: initialDraftFingerprint
            )
        }

        page.title = title
        page.tags = tags
        page.folder = folder
        page.subfolder = subfolder
        page.filePath = receipt.currentURL.path
        page.updatedAt = .now
        if VaultIndexActor.shouldWriteMarkdownFrontMatter(to: receipt.currentURL) {
            page.frontMatter = VaultIndexActor.parseFrontMatter(
                String(decoding: forwardData, as: UTF8.self)
            ).0
            page.applyInteractiveDerivedState(from: forwardBody)
        }
        page.lastSyncedBodyHash = SDPage.bodyHash(forwardBody)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        let appliedMetadataFingerprint = PageIdentityMetadataFingerprint(page: page)
        let appliedDraftFingerprint = pageIdentityDraftFingerprint(for: page)
        do {
            try context.save()
        } catch {
            return await pageIdentityRollbackResult(
                page: page,
                snapshot: snapshot,
                receipt: receipt,
                context: context,
                failure: "note metadata save",
                metadataWasApplied: true,
                expectedAppliedMetadata: appliedMetadataFingerprint,
                expectedAppliedDraft: appliedDraftFingerprint
            )
        }

        _ = NoteFileStorage.stageBodyForImmediateRead(pageId: page.id, content: forwardBody)

        publishCommittedPageDerivedState(
            page: page,
            body: forwardBody
        )
        return .committed
    }

    private func pageIdentityDraftFingerprint(for page: SDPage) -> PageIdentityDraftFingerprint {
        PageIdentityDraftFingerprint(
            liveBody: NoteWindowManager.shared.editorBody(for: page.id),
            inlineBody: page.body,
            pendingBody: NoteFileStorage.pendingBodyForImmediateRead(pageId: page.id)
        )
    }

    private func pageIdentityTargetFingerprint(
        folder: SDFolder?,
        subfolder: String?
    ) -> PageIdentityTargetFingerprint {
        PageIdentityTargetFingerprint(
            folderID: folder?.id,
            folderRelativePath: folder?.relativePath,
            subfolder: subfolder
        )
    }

    private func pageIdentityTargetStillMatches(
        _ initial: PageIdentityTargetFingerprint,
        folder: SDFolder?,
        subfolder: String?
    ) -> Bool {
        initial == pageIdentityTargetFingerprint(folder: folder, subfolder: subfolder)
    }

    private func issuePageBodySaveGeneration(pageId: String) -> UInt64 {
        nextFileFirstSaveGeneration &+= 1
        if nextFileFirstSaveGeneration == 0 {
            nextFileFirstSaveGeneration = 1
        }
        fileFirstSaveGenerations[pageId] = nextFileFirstSaveGeneration
        return nextFileFirstSaveGeneration
    }

    private func pageBodyMutationFingerprint(
        for page: SDPage,
        saveRequestGeneration: UInt64? = nil
    ) -> PageBodyMutationFingerprint {
        PageBodyMutationFingerprint(
            liveBody: NoteWindowManager.shared.editorBody(for: page.id),
            inlineBody: page.body,
            pendingBody: NoteFileStorage.pendingBodyForImmediateRead(pageId: page.id),
            saveRequestGeneration: saveRequestGeneration ?? fileFirstSaveGenerations[page.id]
        )
    }

    private func pageIdentityRollbackResult(
        page: SDPage,
        snapshot: PageIdentityTransactionSnapshot,
        receipt: PageIdentityFileMutationReceipt,
        context: ModelContext,
        failure: String,
        metadataWasApplied: Bool,
        expectedAppliedMetadata: PageIdentityMetadataFingerprint? = nil,
        expectedAppliedDraft: PageIdentityDraftFingerprint? = nil
    ) async -> PageIdentityCommitResult {
        if await restorePageIdentityTransaction(
            page: page,
            snapshot: snapshot,
            receipt: receipt,
            context: context,
            metadataWasApplied: metadataWasApplied,
            expectedAppliedMetadata: expectedAppliedMetadata,
            expectedAppliedDraft: expectedAppliedDraft
        ) {
            return .rolledBack
        }
        recordPageIdentityRecoveryIssue(
            pageId: page.id,
            reason: "Epistemos could not safely roll back a failed \(failure). Editing is paused so the vault can be reconciled without overwriting another file."
        )
        return .recoveryRequired
    }

    private func recordPageIdentityRecoveryIssue(pageId: String, reason: String) {
        recoveryIssue = VaultRecoveryIssue(
            snapshot: currentVaultHealthSnapshot(restoreFailed: true),
            reason: reason,
            forceBlocksWorkspaceInteraction: true
        )
        log.fault("Note identity recovery required for \(pageId, privacy: .public): \(reason, privacy: .public)")
    }

    private func publishCommittedPageDerivedState(page: SDPage, body: String) {
        do {
            try searchService?.upsert(
                id: page.id,
                title: page.title,
                body: body,
                tags: page.tags.joined(separator: " "),
                updatedAt: page.updatedAt
            )
        } catch {
            log.error(
                "Failed to index committed note identity for \(page.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        scheduleBlockMirrorSync(pageId: page.id, body: body)
        SpotlightIndexer.index(page)
        publishVaultMutation(.vaultPageChanged(pageId: page.id))
    }

    private func restorePageIdentityTransaction(
        page: SDPage,
        snapshot: PageIdentityTransactionSnapshot,
        receipt: PageIdentityFileMutationReceipt,
        context: ModelContext,
        metadataWasApplied: Bool,
        expectedAppliedMetadata: PageIdentityMetadataFingerprint?,
        expectedAppliedDraft: PageIdentityDraftFingerprint?
    ) async -> Bool {
        suppressFileWatcherForSelfOriginatedChange()
        let transactionVaultURL = vaultURL
        let fileRestoreError = await Task.detached(priority: .userInitiated) {
            do {
                try Self.restorePageIdentityFile(
                    receipt: receipt,
                    vaultURL: transactionVaultURL
                )
                return nil as String?
            } catch {
                return error.localizedDescription
            }
        }.value
        guard let fileRestoreError else {
            guard metadataWasApplied else {
                if let expectedAppliedDraft,
                   snapshot.stillMatches(page),
                   expectedAppliedDraft == pageIdentityDraftFingerprint(for: page),
                   snapshot.localDraftBody == nil,
                   NoteFileStorage.pendingBodyForImmediateRead(pageId: page.id) == nil,
                   NoteWindowManager.shared.editorBody(for: page.id) == nil
                {
                    _ = NoteFileStorage.stageBodyForImmediateRead(
                        pageId: page.id,
                        content: snapshot.diskBody
                    )
                }
                return true
            }
            guard let expectedAppliedMetadata,
                  let expectedAppliedDraft,
                  expectedAppliedMetadata == PageIdentityMetadataFingerprint(page: page),
                  expectedAppliedDraft == pageIdentityDraftFingerprint(for: page)
            else {
                log.fault(
                    "Note identity file bytes were restored, but newer in-memory edits prevented metadata rollback."
                )
                return false
            }
            snapshot.restore(on: page)
            if snapshot.localDraftBody == nil,
               NoteFileStorage.pendingBodyForImmediateRead(pageId: page.id) == nil,
               NoteWindowManager.shared.editorBody(for: page.id) == nil
            {
                _ = NoteFileStorage.stageBodyForImmediateRead(
                    pageId: page.id,
                    content: snapshot.diskBody
                )
            }
            do {
                try context.save()
            } catch {
                log.fault(
                    "Note identity bytes were restored but metadata rollback failed: \(error.localizedDescription, privacy: .public)"
                )
                return false
            }
            publishCommittedPageDerivedState(
                page: page,
                body: snapshot.diskBody
            )
            return true
        }

        log.fault(
            "Note identity rollback refused to publish an unverified file path: \(fileRestoreError, privacy: .public)"
        )
        return false
    }

    private nonisolated static func restorePageIdentityFile(
        receipt: PageIdentityFileMutationReceipt,
        vaultURL: URL?
    ) throws {
        guard let originalURL = receipt.originalURL else {
            try CoordinatedVaultFileMutation.removeItem(
                at: receipt.currentURL,
                ifCurrentMatches: .contents(receipt.forwardData)
            )
            return
        }
        guard let originalFileData = receipt.originalData else {
            throw PageIdentityTransactionError.missingOriginalFileData
        }

        if receipt.currentURL != originalURL {
            try CoordinatedVaultFileMutation.moveItem(
                at: receipt.currentURL,
                to: originalURL,
                ifSourceMatches: .contents(receipt.forwardData)
            )
        }

        try AtomicVaultWriter.writeSynchronously(
            originalFileData,
            to: originalURL,
            ifCurrentMatches: .contents(receipt.forwardData)
        )
    }

    nonisolated static func restorePageIdentityFileForTesting(
        currentFilePath: String?,
        originalFilePath: String?,
        originalFileData: Data?,
        vaultURL: URL?
    ) throws {
        guard let originalFilePath else {
            throw PageIdentityTransactionError.missingOriginalFile
        }
        guard let originalFileData else {
            throw PageIdentityTransactionError.missingOriginalFileData
        }
        let originalURL = URL(fileURLWithPath: originalFilePath).standardizedFileURL
        if let currentFilePath {
            let currentURL = URL(fileURLWithPath: currentFilePath).standardizedFileURL
            if currentURL != originalURL,
               FileManager.default.fileExists(atPath: originalURL.path)
            {
                guard try Data(contentsOf: originalURL) == originalFileData else {
                    throw PageIdentityTransactionError.originalPathOccupied
                }
            }
        }
    }

    private nonisolated static func observedVaultFileBaseline(
        at fileURL: URL
    ) throws -> VaultFileBaseline {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .absent
        }
        return .contents(try Data(contentsOf: fileURL))
    }

    private nonisolated static func pageIdentityBody(
        from fileData: Data?,
        fileURL: URL?,
        fallback: String
    ) throws -> String {
        guard let fileData, let fileURL else { return fallback }
        guard let raw = String(data: fileData, encoding: .utf8) else {
            throw PageIdentityTransactionError.invalidOriginalFileData
        }
        guard VaultIndexActor.shouldWriteMarkdownFrontMatter(to: fileURL) else {
            return raw
        }
        return VaultIndexActor.parseFrontMatter(raw).1
    }

    private nonisolated static func pageIdentityDestinationURL(
        originalURL: URL?,
        title: String,
        subfolder: String?,
        vaultURL: URL,
        renameFile: Bool,
        moveFile: Bool
    ) -> URL {
        if let originalURL, !renameFile, !moveFile {
            return originalURL
        }
        let parentURL = subfolder
            .flatMap { path in
                let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty
                    ? nil
                    : vaultURL.appendingPathComponent(trimmed, isDirectory: true)
            }
            ?? vaultURL
        let originalExtension = originalURL?.pathExtension ?? "md"
        let fileExtension = originalExtension.isEmpty ? "md" : originalExtension
        let baseName: String
        if renameFile || originalURL == nil {
            baseName = VaultIndexActor.sanitizeFileBaseName(
                title,
                preservingExtension: fileExtension
            )
        } else {
            baseName = originalURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        }
        var candidate = parentURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)
        if candidate.standardizedFileURL == originalURL?.standardizedFileURL {
            return candidate
        }
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let suffixText = suffix > 100 ? String(UUID().uuidString.prefix(8)) : String(suffix)
            candidate = parentURL
                .appendingPathComponent("\(baseName)-\(suffixText)")
                .appendingPathExtension(fileExtension)
            suffix += 1
        }
        return candidate
    }

    @discardableResult
    func savePageBodyFileFirst(pageId: String, body: String) async -> Bool {
        guard let admission = registerVaultMutation() else { return false }
        defer { finishVaultMutation(admission) }
        let predecessor = fileFirstSaveTails[pageId]
        let generation = issuePageBodySaveGeneration(pageId: pageId)
        let task = Task { @MainActor [weak self] in
            if let predecessor {
                _ = await predecessor.value
            }
            guard let self else { return false }
            await self.pageFileMutationGate.acquire(pageId: pageId)
            guard self.vaultMutationAdmissionIsCurrent(admission) else {
                await self.pageFileMutationGate.release(pageId: pageId)
                return false
            }
            let result = await self.performPageBodyFileFirstSave(
                pageId: pageId,
                body: body,
                generation: generation,
                admission: admission
            ) == .saved
            await self.pageFileMutationGate.release(pageId: pageId)
            return result
        }
        fileFirstSaveTails[pageId] = task
        fileFirstSaveTailGenerations[pageId] = generation
        let result = await task.value
        if fileFirstSaveTailGenerations[pageId] == generation {
            fileFirstSaveTails.removeValue(forKey: pageId)
            fileFirstSaveTailGenerations.removeValue(forKey: pageId)
        }
        if fileFirstSaveGenerations[pageId] == generation {
            fileFirstSaveGenerations.removeValue(forKey: pageId)
        }
        return result
    }

    private func performPageBodyFileFirstSave(
        pageId: String,
        body: String,
        generation: UInt64,
        admission: VaultMutationAdmission
    ) async -> PageBodyFileSaveResult {
        guard let vaultURL,
              vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL)
        else {
            log.warning("Cannot save page body: no vault URL")
            return .failed
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "file-first body save page") else {
            return .failed
        }
        guard fileFirstSaveGenerations[pageId] == generation else {
            return .stale
        }

        guard let stagedBody = NoteFileStorage.stageBodyForImmediateRead(pageId: pageId, content: body) else {
            return .failed
        }
        let initialMutationFingerprint = pageBodyMutationFingerprint(
            for: page,
            saveRequestGeneration: generation
        )
        let isMarkdownBacked = page.filePath
            .map { VaultIndexActor.shouldWriteMarkdownFrontMatter(to: URL(fileURLWithPath: $0)) }
            ?? true
        if isMarkdownBacked,
           let syncedTitle = ProseEditorView.syncedNoteTitle(from: stagedBody),
           syncedTitle != page.title
        {
            let identityResult = await performPageIdentityFileFirstCommit(
                pageId: pageId,
                title: syncedTitle,
                tags: page.tags,
                folder: page.folder,
                subfolder: page.subfolder,
                markdownBody: stagedBody,
                admission: admission
            )
            if identityResult == .committed {
                NoteFileStorage.clearPendingBodyForImmediateRead(
                    pageId: pageId,
                    matching: stagedBody
                )
            }
            guard fileFirstSaveGenerations[pageId] == generation else {
                page.needsVaultSync = true
                try? context.save()
                return .stale
            }
            switch identityResult {
            case .committed:
                return .saved
            case .rolledBack:
                page.needsVaultSync = true
                try? context.save()
                return .stale
            case .rejected, .recoveryRequired:
                page.needsVaultSync = true
                try? context.save()
                return .failed
            }
        }
        suppressFileWatcherForSelfOriginatedChange()

        do {
            guard let result = try await exportPage(
                pageId: pageId,
                to: vaultURL,
                bodyOverride: stagedBody,
                indexForSearch: false
            ) else {
                return .failed
            }
            guard vaultMutationAdmissionIsCurrent(admission, vaultURL: vaultURL) else {
                NoteFileStorage.clearPendingBodyForImmediateRead(
                    pageId: pageId,
                    matching: stagedBody
                )
                page.needsVaultSync = true
                try? context.save()
                return .stale
            }
            let exportedHash = SDPage.bodyHash(stagedBody)
            guard result.bodyHash == exportedHash else {
                page.needsVaultSync = true
                try? context.save()
                log.error("File-first save returned a mismatched body hash for \(pageId, privacy: .public)")
                return .failed
            }
            guard initialMutationFingerprint == pageBodyMutationFingerprint(for: page) else {
                NoteFileStorage.clearPendingBodyForImmediateRead(
                    pageId: pageId,
                    matching: stagedBody
                )
                page.needsVaultSync = true
                try? context.save()
                return .stale
            }

            let resultURL = URL(fileURLWithPath: result.path)
            let resultIsMarkdown = VaultIndexActor.shouldWriteMarkdownFrontMatter(to: resultURL)
            page.filePath = result.path
            if resultIsMarkdown {
                page.applyInteractiveDerivedState(from: stagedBody)
            }
            page.updatedAt = .now
            page.lastSyncedBodyHash = exportedHash
            page.lastSyncedAt = .now
            page.needsVaultSync = false
            try context.save()
            NoteFileStorage.clearPendingBodyForImmediateRead(
                pageId: pageId,
                matching: stagedBody
            )
            publishCommittedPageDerivedState(page: page, body: stagedBody)
            return .saved
        } catch {
            page.needsVaultSync = true
            try? context.save()
            log.error("Failed file-first body save for \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    func drainFileFirstSaveTails() async -> Bool {
        var allSaved = true
        while !fileFirstSaveTails.isEmpty {
            let snapshot = fileFirstSaveTails.compactMap { pageId, task in
                fileFirstSaveTailGenerations[pageId].map { (pageId, $0, task) }
            }
            guard !snapshot.isEmpty else { break }
            for (pageId, generation, task) in snapshot {
                if !(await task.value) {
                    allSaved = false
                }
                if fileFirstSaveTailGenerations[pageId] == generation {
                    fileFirstSaveTails.removeValue(forKey: pageId)
                    fileFirstSaveTailGenerations.removeValue(forKey: pageId)
                }
                if fileFirstSaveGenerations[pageId] == generation {
                    fileFirstSaveGenerations.removeValue(forKey: pageId)
                }
            }
        }
        return allSaved
    }

    @discardableResult
    func recoverDraftIfNewer(
        pageId: String,
        body: String,
        draftModificationDate: Date
    ) async -> Bool {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, in: context, label: "draft recovery page") else {
            return false
        }
        let vaultBodyDate: Date = {
            guard let filePath = page.filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty
            else { return .distantPast }
            let fileURL = URL(fileURLWithPath: filePath)
            return (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
        }()
        guard draftModificationDate > vaultBodyDate else {
            return false
        }
        return await savePageBodyFileFirst(pageId: pageId, body: body)
    }

    /// Save all dirty pages to their vault .md files.
    @discardableResult
    func saveAllDirtyPages() -> Task<Void, Never>? {
        if let task = inFlightDirtySaveTask, !task.isCancelled {
            pendingDirtySaveRequest = true
            return task
        }

        guard let admission = registerVaultMutation() else { return nil }
        guard let initialBatch = nextDirtySaveBatch() else {
            finishVaultMutation(admission)
            return nil
        }

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishVaultMutation(admission) }
            await self.runDirtySaveLoop(
                startingWith: initialBatch,
                admission: admission
            )
        }
        inFlightDirtySaveTask = task
        return task
    }

    private func nextDirtySaveBatch() -> DirtySaveBatch? {
        guard vaultURL != nil else { return nil }

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
            dirtyIds: dirtyPages.map(\.id)
        )
    }

    private func runDirtySaveLoop(
        startingWith initialBatch: DirtySaveBatch,
        admission: VaultMutationAdmission
    ) async {
        let interval = Log.vaultPerf.beginInterval("saveAllDirtyPages")
        defer {
            Log.vaultPerf.endInterval("saveAllDirtyPages", interval)
            inFlightDirtySaveTask = nil
            pendingDirtySaveRequest = false
        }

        var currentBatch: DirtySaveBatch? = initialBatch
        while !Task.isCancelled {
            guard vaultMutationAdmissionIsCurrent(admission) else { return }
            pendingDirtySaveRequest = false
            guard let batch = currentBatch ?? nextDirtySaveBatch() else { return }
            currentBatch = nil

            var successfulExportCount = 0
            var exportFailures = 0

            for pageId in batch.dirtyIds {
                let generation = issuePageBodySaveGeneration(pageId: pageId)
                await pageFileMutationGate.acquire(pageId: pageId)
                guard vaultMutationAdmissionIsCurrent(admission) else {
                    await pageFileMutationGate.release(pageId: pageId)
                    return
                }
                let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                let page = fetchFirst(desc, in: batch.context, label: "dirty page body snapshot")
                let body = page.map { latestAvailableBody(for: $0, pageId: pageId) }
                let saveResult = if let body {
                    await performPageBodyFileFirstSave(
                        pageId: pageId,
                        body: body,
                        generation: generation,
                        admission: admission
                    )
                } else {
                    PageBodyFileSaveResult.failed
                }
                await pageFileMutationGate.release(pageId: pageId)
                if fileFirstSaveGenerations[pageId] == generation {
                    fileFirstSaveGenerations.removeValue(forKey: pageId)
                }

                switch saveResult {
                case .saved:
                    successfulExportCount += 1
                    if let page {
                        AppBootstrap.shared?.instantRecallService.indexNote(noteId: page.id, text: body ?? "")
                    }
                case .stale:
                    pendingDirtySaveRequest = true
                case .failed:
                    exportFailures += 1
                    lastVaultSaveError = "File-first save failed for page \(pageId)"
                }
            }

            // Data MED-3: a whole batch failing to export usually means the vault
            // volume/path became unreachable. Track the streak so a "recent edits not
            // saved" diagnostic can be surfaced (Settings → vault-save health); reset
            // on any success. Additive — does NOT change the save/retry logic (the
            // pages stay dirty and retry on the next tick / on reconnect).
            if successfulExportCount > 0 {
                vaultSaveFailureStreak = 0
                lastVaultSaveError = nil
            } else if exportFailures > 0 {
                vaultSaveFailureStreak += 1
            }

            log.info("Saved \(successfulExportCount) of \(batch.dirtyIds.count) dirty pages to vault")

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
            fileWatcherActive: fileWatcherState.eventStream != nil || fileWatcherState.source != nil
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
        switch event {
        case .vaultChanged:
            graphPageMutationRefreshTask?.cancel()
            graphPageMutationRefreshTask = nil
            AppBootstrap.shared?.graphState.needsRefresh = true
        case .vaultPageChanged:
            scheduleGraphRefreshAfterPageMutation()
        default:
            break
        }
        eventBus?.emit(event)
    }

    private func scheduleGraphRefreshAfterPageMutation() {
        graphPageMutationRefreshTask?.cancel()
        graphPageMutationRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            AppBootstrap.shared?.graphState.needsRefresh = true
            self?.graphPageMutationRefreshTask = nil
        }
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
    /// FSEvents gives recursive, path-level events so external editors and AI tools can edit
    /// files anywhere in the vault and the changed note is reindexed without a full import.
    /// A directory DispatchSource remains as a coarse fallback if FSEvents cannot be created.
    private func startFileWatcher() {
        guard let url = vaultURL,
              let lifecycleToken = currentOperationalVaultLifecycleToken(for: url)
        else { return }
        stopFileWatcher()

        if startFSEventsWatcher(for: url, lifecycleToken: lifecycleToken) {
            log.info("FSEvents watcher started for: \(url.lastPathComponent, privacy: .public)")
            return
        }

        startDirectoryDispatchSourceWatcher(for: url, lifecycleToken: lifecycleToken)
    }

    private func startFSEventsWatcher(
        for url: URL,
        lifecycleToken: VaultLifecycleToken
    ) -> Bool {
        let callbackBox = VaultFileWatcherCallbackBox(
            service: self,
            lifecycleToken: lifecycleToken
        )
        let unmanagedBox = Unmanaged.passRetained(callbackBox)
        var context = FSEventStreamContext(
            version: 0,
            info: unmanagedBox.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let pathsToWatch = [url.path] as CFArray
        let since = Self.vaultFSEventStartID(for: url, defaults: defaults)
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseExtendedData
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagWatchRoot
                | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.vaultFSEventsCallback,
            &context,
            pathsToWatch,
            since,
            0.15,
            flags
        ) else {
            unmanagedBox.release()
            log.warning("File watcher: failed to create recursive FSEvents stream")
            return false
        }

        FSEventStreamSetDispatchQueue(stream, fileWatcherState.eventQueue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            unmanagedBox.release()
            log.warning("File watcher: failed to start recursive FSEvents stream")
            return false
        }

        fileWatcherState.eventStream = stream
        fileWatcherState.callbackBox = unmanagedBox
        return true
    }

    private func spotlightCursor(for vaultURL: URL) -> Date? {
        defaults.object(forKey: Self.spotlightCursorKey(for: vaultURL)) as? Date
    }

    private func persistSpotlightCursor(
        _ receipt: VaultSpotlightJournalReceipt,
        for vaultURL: URL
    ) {
        guard let candidateCursor = receipt.candidateCursor else { return }
        let key = Self.spotlightCursorKey(for: vaultURL)
        if let storedCursor = defaults.object(forKey: key) as? Date,
           storedCursor >= candidateCursor {
            return
        }
        defaults.set(candidateCursor, forKey: key)
    }

    private func persistVaultFSEventCheckpoint(
        _ eventID: FSEventStreamEventId,
        for vaultURL: URL
    ) {
        let key = Self.vaultFSEventCheckpointKey(for: vaultURL)
        if let storedValue = defaults.string(forKey: key),
           let storedEventID = UInt64(storedValue),
           storedEventID >= eventID {
            return
        }
        defaults.set(String(eventID), forKey: key)
    }

    private nonisolated static var vaultFSEventsCallback: FSEventStreamCallback {
        { _, info, eventCount, eventPaths, eventFlags, eventIDs in
            guard let info else { return }
            let box = Unmanaged<VaultFileWatcherCallbackBox>.fromOpaque(info).takeUnretainedValue()
            let eventPayloads = unsafeBitCast(eventPaths, to: NSArray.self)
            var events: [VaultFileSystemEvent] = []
            events.reserveCapacity(eventCount)

            for index in 0..<eventCount {
                guard index < eventPayloads.count else { continue }
                let payload = eventPayloads[index]
                let path: String?
                let inode: UInt64?
                if let dict = payload as? NSDictionary {
                    path = dict[kFSEventStreamEventExtendedDataPathKey as String] as? String
                    inode = (dict[kFSEventStreamEventExtendedFileIDKey as String] as? NSNumber)?
                        .uint64Value
                } else {
                    path = payload as? String
                    inode = nil
                }
                guard let path else { continue }
                events.append(
                    VaultFileSystemEvent(
                        path: path,
                        flags: eventFlags[index],
                        inode: inode,
                        eventID: eventIDs[index]
                    )
                )
            }

            guard !events.isEmpty else { return }
            box.handle(events)
        }
    }

    private func startDirectoryDispatchSourceWatcher(
        for url: URL,
        lifecycleToken: VaultLifecycleToken
    ) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            log.warning("File watcher: failed to open vault directory for monitoring")
            return
        }
        fileWatcherState.fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .link, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self, lifecycleToken] in
            self?.handleFileSystemChange(lifecycleToken: lifecycleToken)
        }

        source.setCancelHandler { [fd] in
            close(fd)
        }

        source.resume()
        fileWatcherState.source = source
        log.info("Directory fallback watcher started for: \(url.lastPathComponent, privacy: .public)")
    }

    private func stopFileWatcher() {
        fileWatcherState.debounceTask?.cancel()
        fileWatcherState.debounceTask = nil
        fileWatcherState.ignoreUntil = nil
        fileWatcherState.pendingChangedPaths.removeAll(keepingCapacity: false)
        fileWatcherState.pendingDeletedPaths.removeAll(keepingCapacity: false)
        fileWatcherState.pendingFullRescan = false
        fileWatcherState.pendingLastEventID = nil
        if let stream = fileWatcherState.eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fileWatcherState.eventStream = nil
        }
        if let callbackBox = fileWatcherState.callbackBox {
            callbackBox.release()
            fileWatcherState.callbackBox = nil
        }
        if let source = fileWatcherState.source {
            source.cancel()
            fileWatcherState.source = nil
            fileWatcherState.fileDescriptor = -1
        }
    }

    private func suppressFileWatcherForSelfOriginatedChange(window: Duration = .seconds(3)) {
        guard isWatching else { return }
        let deadline = fileWatcherState.clock.now + window
        if let existingDeadline = fileWatcherState.ignoreUntil, existingDeadline > deadline {
            return
        }
        fileWatcherState.ignoreUntil = deadline
    }

    func suppressNextFileWatcherChangeForSelfOriginatedWrite(window: Duration = .seconds(3)) {
        suppressFileWatcherForSelfOriginatedChange(window: window)
    }

    private func shouldIgnoreFileWatcherChange() -> Bool {
        guard let deadline = fileWatcherState.ignoreUntil else { return false }
        let now = fileWatcherState.clock.now
        if now < deadline {
            return true
        }
        fileWatcherState.ignoreUntil = nil
        return false
    }

    fileprivate func handleVaultFileSystemEvents(
        _ events: [VaultFileSystemEvent],
        lifecycleToken: VaultLifecycleToken
    ) {
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true),
              let vaultURL
        else { return }
        if !events.isEmpty {
            fileWatcherState.pendingRevision &+= 1
        }
        for event in events {
            if let pendingLastEventID = fileWatcherState.pendingLastEventID {
                fileWatcherState.pendingLastEventID = max(pendingLastEventID, event.eventID)
            } else {
                fileWatcherState.pendingLastEventID = event.eventID
            }

            if event.signalsVaultRootAvailabilityChange, !isReadableVaultURL(vaultURL) {
                handleVaultVolumeUnavailable(
                    vaultURL: vaultURL,
                    reason: "Vault volume unavailable after a root file-system event; writes are paused until the vault is reattached."
                )
                return
            }

            switch Self.classifyVaultFileSystemEvent(event, vaultURL: vaultURL) {
            case .fullRescan:
                fileWatcherState.pendingFullRescan = true
            case .changed(let path):
                fileWatcherState.pendingDeletedPaths.remove(path)
                fileWatcherState.pendingChangedPaths.insert(path)
            case .deleted(let path):
                fileWatcherState.pendingChangedPaths.remove(path)
                fileWatcherState.pendingDeletedPaths.insert(path)
            case .ignored:
                continue
            }
        }

        scheduleDebouncedVaultFileSystemRefresh(lifecycleToken: lifecycleToken)
    }

    private func handleVaultVolumeUnavailable(vaultURL: URL, reason: String) {
        let snapshot = currentVaultHealthSnapshot(restoreFailed: true)
        stopWatching(preserveData: true)
        recoveryIssue = VaultRecoveryIssue(snapshot: snapshot, reason: reason)
        vaultActivityMessage = nil
        isIndexing = false
        log.error(
            "Vault volume unavailable at \(vaultURL.path, privacy: .private); watcher stopped and local state preserved."
        )
    }

    nonisolated static func classifyVaultFileSystemEvent(
        _ event: VaultFileSystemEvent,
        vaultURL: URL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> VaultFileSystemEventClassification {
        if event.requiresFullRescan || event.itemIsDirectory {
            return .fullRescan
        }

        guard let fileURL = importableVaultEventFileURL(from: event.path, vaultURL: vaultURL) else {
            return .ignored
        }

        let exists = fileExists(fileURL)
        if event.itemWasRemoved || (event.itemWasRenamed && !exists) || !exists {
            return .deleted(fileURL.path)
        }
        return .changed(fileURL.path)
    }

    private nonisolated static func importableVaultEventFileURL(from path: String, vaultURL: URL) -> URL? {
        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        let vaultRoot = vaultURL.standardizedFileURL.path
        let vaultPrefix = vaultRoot.hasSuffix("/") ? vaultRoot : "\(vaultRoot)/"
        let filePath = fileURL.path

        guard filePath.hasPrefix(vaultPrefix), filePath.count > vaultPrefix.count else {
            return nil
        }

        let relativePath = String(filePath.dropFirst(vaultPrefix.count))
        let components = relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }
        guard !components.contains(where: { $0.hasPrefix(".") || VaultIndexActor.shouldSkipDescendants(for: $0) }) else {
            return nil
        }
        guard VaultIndexActor.isImportableNoteFile(fileURL) else { return nil }
        return fileURL
    }

    /// Coarse fallback when FSEvents cannot be started. The directory source has no paths, so
    /// the safest useful response is a complete import pass with the importer's own deletion guards.
    private func handleFileSystemChange(lifecycleToken: VaultLifecycleToken) {
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true) else { return }
        fileWatcherState.pendingFullRescan = true
        fileWatcherState.pendingRevision &+= 1
        scheduleDebouncedVaultFileSystemRefresh(lifecycleToken: lifecycleToken)
    }

    /// Debounced handler for file-system event batches.
    /// Waits 2 seconds after the last change before importing, so rapid
    /// saves (e.g. typing in an external editor) don't trigger 50 imports.
    private func scheduleDebouncedVaultFileSystemRefresh(
        lifecycleToken: VaultLifecycleToken
    ) {
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true) else { return }
        let shouldIgnore = shouldIgnoreFileWatcherChange()
        if shouldIgnore {
            log.debug("File watcher: self-originated event window active; reconciling anyway to avoid hiding external races")
        }

        fileWatcherState.debounceTask?.cancel()
        fileWatcherState.debounceTask = Task { @MainActor [weak self, lifecycleToken] in
            guard await Self.sleepHandlingCancellation(
                for: .seconds(2),
                label: "file watcher debounce"
            ) else { return }
            guard !Task.isCancelled else { return }
            guard let self,
                  self.vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true)
            else { return }
            _ = self.drainAndProcessPendingVaultFileSystemChanges(
                shouldIgnore: shouldIgnore,
                lifecycleToken: lifecycleToken
            )
        }
    }

    private var hasPendingVaultFileSystemChanges: Bool {
        fileWatcherState.pendingLastEventID != nil
            || !fileWatcherState.pendingChangedPaths.isEmpty
            || !fileWatcherState.pendingDeletedPaths.isEmpty
            || fileWatcherState.pendingFullRescan
    }

    private func drainAndProcessPendingVaultFileSystemChanges(
        shouldIgnore: Bool,
        lifecycleToken: VaultLifecycleToken,
        allowBeforeInitialImportCompletion: Bool = false
    ) -> VaultFileSystemBatchCompletionFence? {
        guard vaultLifecycleTokenIsCurrent(lifecycleToken, requireOperational: true) else {
            return nil
        }
        guard initialImportCompleted || allowBeforeInitialImportCompletion else { return nil }
        let changedPaths = Array(fileWatcherState.pendingChangedPaths)
        let deletedPaths = Array(fileWatcherState.pendingDeletedPaths)
        let needsFullRescan = fileWatcherState.pendingFullRescan
        let lastEventID = fileWatcherState.pendingLastEventID
        guard !changedPaths.isEmpty
                || !deletedPaths.isEmpty
                || needsFullRescan
                || lastEventID != nil
        else { return nil }
        guard let vaultURL, let actor = indexActor else { return nil }
        guard let admission = registerVaultMutation() else { return nil }
        let completionFence = VaultFileSystemBatchCompletionFence()
        fileWatcherState.pendingChangedPaths.removeAll(keepingCapacity: true)
        fileWatcherState.pendingDeletedPaths.removeAll(keepingCapacity: true)
        fileWatcherState.pendingFullRescan = false
        fileWatcherState.pendingLastEventID = nil

        acceptedVaultFileSystemBatches.append(
            AcceptedVaultFileSystemBatch(
                admission: admission,
                lifecycleToken: lifecycleToken,
                vaultURL: vaultURL,
                actor: actor,
                searchService: searchService,
                processingOperation: externalVaultFileSystemChangesOperationOverride,
                recallPreparationOperation: vaultFileSystemRecallPreparationOperationOverride,
                recallApplyOperation: vaultFileSystemRecallApplyOperationOverride,
                recallCompletionOperation: vaultFileSystemRecallCompletionOperationOverride,
                changedPaths: changedPaths,
                deletedPaths: deletedPaths,
                needsFullRescan: needsFullRescan,
                lastEventID: lastEventID,
                completionFence: completionFence
            )
        )
        startNextVaultFileSystemProcessorIfNeeded()
        return completionFence
    }

    private func startNextVaultFileSystemProcessorIfNeeded() {
        guard vaultFileSystemProcessorTask == nil,
              acceptedVaultFileSystemBatchHead < acceptedVaultFileSystemBatches.count
        else { return }

        let batch = acceptedVaultFileSystemBatches[acceptedVaultFileSystemBatchHead]
        acceptedVaultFileSystemBatchHead += 1
        if acceptedVaultFileSystemBatchHead == acceptedVaultFileSystemBatches.count {
            acceptedVaultFileSystemBatches.removeAll(keepingCapacity: true)
            acceptedVaultFileSystemBatchHead = 0
        } else if acceptedVaultFileSystemBatchHead >= 64 {
            acceptedVaultFileSystemBatches.removeFirst(acceptedVaultFileSystemBatchHead)
            acceptedVaultFileSystemBatchHead = 0
        }

        vaultFileSystemProcessorTask = Task.detached(priority: .utility) { [weak self] in
            var completionResult: VaultFileSystemProcessingResult?
            defer { batch.completionFence.finish(with: completionResult) }
            guard let self else { return }
            let result: VaultFileSystemProcessingResult
            if let processingOperation = batch.processingOperation {
                result = await processingOperation(
                    batch.vaultURL,
                    batch.changedPaths,
                    batch.deletedPaths,
                    batch.needsFullRescan
                )
            } else {
                result = await Self.processExternalVaultFileSystemChanges(
                    actor: batch.actor,
                    vaultURL: batch.vaultURL,
                    changedPaths: batch.changedPaths,
                    deletedPaths: batch.deletedPaths,
                    needsFullRescan: batch.needsFullRescan,
                    searchService: batch.searchService
                )
            }
            let recallMutation: VaultInstantRecallMutation?
            switch result.postImportRecallWorkload {
            case .none:
                recallMutation = .some(.none)
            default:
                if let preparationOperation = batch.recallPreparationOperation {
                    recallMutation = await preparationOperation(
                        batch.actor,
                        result.postImportRecallWorkload
                    )
                } else {
                    recallMutation = await Self.prepareInstantRecallMutation(
                        from: batch.actor,
                        workload: result.postImportRecallWorkload
                    )
                }
            }
            let effectiveResult: VaultFileSystemProcessingResult
            if result.postImportRecallWorkload != .none, recallMutation == nil {
                Self.backgroundLog.error(
                    "File watcher: required Instant Recall preparation failed; preserving the batch for retry"
                )
                effectiveResult = VaultFileSystemProcessingResult(
                    didProcess: false,
                    didMutate: result.didMutate,
                    completedAuthoritativeFullRescan: false,
                    postImportRecallWorkload: result.postImportRecallWorkload
                )
            } else {
                effectiveResult = result
            }
            await self.completeVaultFileSystemBatch(
                batch,
                result: effectiveResult,
                recallMutation: recallMutation ?? .none
            )
            await batch.recallCompletionOperation?()
            completionResult = effectiveResult
        }
    }

    private func completeVaultFileSystemBatch(
        _ batch: AcceptedVaultFileSystemBatch,
        result: VaultFileSystemProcessingResult,
        recallMutation: VaultInstantRecallMutation
    ) {
        defer {
            vaultFileSystemProcessorTask = nil
            finishVaultMutation(batch.admission)
            startNextVaultFileSystemProcessorIfNeeded()
        }

        guard vaultLifecycleTokenIsCurrent(
            batch.lifecycleToken,
            requireOperational: true
        ) else { return }

        switch recallMutation {
        case .none:
            break
        default:
            if let recallApplyOperation = batch.recallApplyOperation {
                recallApplyOperation(recallMutation)
            } else {
                Self.applyInstantRecallMutation(recallMutation)
            }
        }

        if !result.didProcess {
            blockedFSEventCheckpointToken = batch.lifecycleToken
            requeueFailedVaultFileSystemBatch(batch)
        }

        if result.didProcess,
           result.completedAuthoritativeFullRescan,
           blockedFSEventCheckpointToken == batch.lifecycleToken {
            blockedFSEventCheckpointToken = nil
        }

        if result.didProcess,
           blockedFSEventCheckpointToken != batch.lifecycleToken,
           let lastEventID = batch.lastEventID {
            persistVaultFSEventCheckpoint(lastEventID, for: batch.vaultURL)
        }

        if result.didMutate {
            publishVaultMutation(.vaultChanged)
        }
    }

    private func requeueFailedVaultFileSystemBatch(
        _ batch: AcceptedVaultFileSystemBatch
    ) {
        for path in batch.changedPaths
            where !fileWatcherState.pendingDeletedPaths.contains(path) {
            fileWatcherState.pendingChangedPaths.insert(path)
        }
        for path in batch.deletedPaths
            where !fileWatcherState.pendingChangedPaths.contains(path) {
            fileWatcherState.pendingDeletedPaths.insert(path)
        }
        fileWatcherState.pendingFullRescan = true
        if let batchEventID = batch.lastEventID {
            fileWatcherState.pendingLastEventID = max(
                fileWatcherState.pendingLastEventID ?? 0,
                batchEventID
            )
        }
        fileWatcherState.pendingRevision &+= 1
    }

    private nonisolated static func processExternalVaultFileSystemChanges(
        actor: VaultIndexActor,
        vaultURL: URL,
        changedPaths: [String],
        deletedPaths: [String],
        needsFullRescan: Bool,
        searchService: SearchIndexService?
    ) async -> VaultFileSystemProcessingResult {
        let log = Logger(subsystem: "com.epistemos", category: "VaultSync")
        var didMutate = false
        var postImportRecallWorkload: VaultPostImportRecallWorkload = .none

        do {
            if needsFullRescan {
                log.info("File watcher: path detail unavailable — running guarded vault import")
                let shouldRemoveMissingFilesDuringFallbackImport = false
                guard let snapshot = try await actor.importVault(
                    from: vaultURL,
                    deleteMissingFiles: shouldRemoveMissingFilesDuringFallbackImport
                ) else {
                    return VaultFileSystemProcessingResult(didProcess: false, didMutate: false)
                }
                didMutate = snapshot.postImportMutationCount > 0
                if didMutate {
                    postImportRecallWorkload = snapshot.postImportRecallWorkload
                }
            } else {
                for path in deletedPaths.sorted() {
                    let fileURL = URL(fileURLWithPath: path)
                    try await actor.handleFileDeletion(at: fileURL)
                    didMutate = true
                    postImportRecallWorkload = .rebuild
                }

                for path in changedPaths.sorted() {
                    let fileURL = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let changed = try await actor.reindexFile(at: fileURL, vaultURL: vaultURL)
                        didMutate = didMutate || changed
                        if changed {
                            postImportRecallWorkload = .rebuild
                        }
                    } else {
                        try await actor.handleFileDeletion(at: fileURL)
                        didMutate = true
                        postImportRecallWorkload = .rebuild
                    }
                }
            }

            guard didMutate else {
                return VaultFileSystemProcessingResult(didProcess: true, didMutate: false)
            }

            if let searchService {
                guard let timestamps = await actor.requiredPageTimestampsForSearchDiff() else {
                    log.error(
                        "File watcher: required Search timestamps could not be read; preserving the batch for retry"
                    )
                    return VaultFileSystemProcessingResult(
                        didProcess: false,
                        didMutate: didMutate,
                        postImportRecallWorkload: postImportRecallWorkload
                    )
                }
                try await searchService.diffSync(
                    swiftDataPages: timestamps,
                    fullPageProvider: { id in await actor.fullPageData(for: id) }
                )
            }

            return VaultFileSystemProcessingResult(
                didProcess: true,
                didMutate: true,
                postImportRecallWorkload: postImportRecallWorkload
            )
        } catch {
            log.error("File watcher: external vault refresh failed: \(error.localizedDescription, privacy: .public)")
            return VaultFileSystemProcessingResult(
                didProcess: false,
                didMutate: didMutate,
                postImportRecallWorkload: postImportRecallWorkload
            )
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
        allowVaultSelectionPrompt: Bool = false,
        frontMatter: [String: String] = [:]
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
        page.updateBodyDerivedState(from: body)
        if !frontMatter.isEmpty {
            page.frontMatter = frontMatter
        }
        page.subfolder = subfolder
        page.wordCount = body.split(separator: " ").count

        let context = modelContainer.mainContext
        context.insert(page)
        BlockMirror.sync(pageId: failedPageId, body: body, modelContext: context)
        page.lastSyncedBodyHash = nil
        page.lastSyncedAt = nil
        page.needsVaultSync = true
        do {
            try context.save()
        } catch {
            rollBackCreatedPage(page, pageId: failedPageId, title: title, context: context)
            Log.vault.error("Failed to save new page '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let pageId = failedPageId
        suppressFileWatcherForSelfOriginatedChange()
        let exportResult: (path: String, bodyHash: String)
        do {
            guard let result = try await exportPage(pageId: pageId, to: vaultURL, bodyOverride: body) else {
                rollBackCreatedPage(page, pageId: pageId, title: title, context: context)
                publishVaultMutation(.vaultChanged)
                return nil
            }
            exportResult = result
        } catch {
            rollBackCreatedPage(page, pageId: pageId, title: title, context: context)
            publishVaultMutation(.vaultChanged)
            log.error(
                "Failed to export new page to disk: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }

        page.filePath = exportResult.path
        let currentHash = SDPage.bodyHash(body)
        if currentHash == exportResult.bodyHash {
            page.lastSyncedBodyHash = currentHash
            page.lastSyncedAt = .now
            page.needsVaultSync = false
        } else {
            page.needsVaultSync = true
        }

        do {
            try context.save()
        } catch {
            Log.vault.error(
                "Failed to save new page export tracking: \(error.localizedDescription, privacy: .public)"
            )
        }

        SpotlightIndexer.index(page)
        publishVaultMutation(.vaultChanged)
        return pageId
    }

    private func rollBackCreatedPage(_ page: SDPage, pageId: String, title: String, context: ModelContext) {
        context.delete(page)
        let blockDescriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId }
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
        NoteFileStorage.deleteBody(pageId: pageId)
        do {
            try context.save()
        } catch {
            Log.vault.error(
                "Failed to roll back new page '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Directory Operations

    private func removeVaultItem(at url: URL, label: String) {
        suppressFileWatcherForSelfOriginatedChange()
        do {
            let result = try CoordinatedVaultFileMutation.trashOrRemoveItem(at: url)
            switch result {
            case .trashed:
                log.info("Moved \(label, privacy: .public) to Trash: \(url.path, privacy: .private)")
            case .removed:
                log.info("Deleted \(label, privacy: .public): \(url.path, privacy: .private)")
            }
            publishVaultMutation(.vaultChanged)
        } catch {
            log.error(
                "Failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
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

    /// Rename a page's vault file to match a new title.
    /// Call this after updating page.title so the Finder filename stays in sync.
    @discardableResult
    func renamePageFile(pageId: String, newTitle: String) -> Task<String?, Never>? {
        guard let vaultURL else {
            log.warning("Cannot rename page file: no vault URL")
            return nil
        }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.id == pageId }
        )
        let context = modelContainer.mainContext
        guard let page = fetchFirst(
            descriptor,
            in: context,
            label: "page selected for live file rename"
        ), let oldPath = page.filePath else {
            log.warning("Cannot rename page file: page or file path unavailable")
            return nil
        }
        suppressFileWatcherForSelfOriginatedChange()
        let task = Task { () -> String? in
            do {
                let renameTask = Task.detached(priority: .userInitiated) {
                    try VaultIndexActor.renamePageFileOnDisk(
                        oldPath: oldPath,
                        newTitle: newTitle,
                        vaultURL: vaultURL
                    )
                }
                guard let renamedPath = try await renameTask.value else { return nil }

                page.filePath = renamedPath
                try context.save()
                log.info(
                    "Renamed page file: \(URL(fileURLWithPath: oldPath).lastPathComponent, privacy: .public) → \(URL(fileURLWithPath: renamedPath).lastPathComponent, privacy: .public)"
                )
                return renamedPath
            } catch {
                log.error("Failed to rename page file: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        return task
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
            try CoordinatedVaultFileMutation.moveItem(at: oldURL, to: newURL)
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
    func movePage(
        pageId: String,
        toSubfolder subfolder: String?,
        publishMutation: Bool = true
    ) -> Bool {
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

            var performedMove: (from: URL, to: URL)?
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

                    try CoordinatedVaultFileMutation.moveItem(at: oldURL, to: newURL)
                    performedMove = (from: oldURL, to: newURL)
                }

                page.filePath = newURL.path
            } else {
                page.filePath = nil
            }

            page.subfolder = normalizedSubfolder
            page.updatedAt = .now
            do {
                try context.save()
            } catch {
                // MED #2 (audit 2026-07-03): the disk move already succeeded but the
                // SwiftData filePath update failed to persist. Roll the file back so
                // disk matches the persisted (old) path — otherwise the moved file
                // re-imports as a DUPLICATE page on the next launch (store still points
                // at the old path; the file now sits at the new one).
                if let move = performedMove {
                    do {
                        try CoordinatedVaultFileMutation.moveItem(at: move.to, to: move.from)
                        page.filePath = move.from.path
                    } catch {
                        log.fault(
                            "Failed to roll back page move after metadata save failure: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
                throw error
            }

            if page.filePath == nil {
                savePage(pageId: pageId)
            }
            if publishMutation {
                publishVaultMutation(.vaultChanged)
            }
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

        guard let preparedSelection = vaultSync.prepareVaultSelection(
            url,
            userConfirmedSuspiciousFolder: assessment.shouldConfirmSelection
        ) else {
            AppBootstrap.shared?.uiState.showToast(
                "Epistemos could not save permission to restore this vault on relaunch. Select the folder again.",
                type: .error
            )
            vaultSync.vaultActivityMessage = nil
            vaultSync.isIndexing = false
            return false
        }

        vaultSync.vaultActivityMessage = "Opening vault \"\(url.lastPathComponent)\"..."
        let didSwitch = await vaultSync.switchToVaultAsync(vaultURL: url)
        if didSwitch {
            vaultSync.commitPreparedVaultSelection(preparedSelection)

            // Reset UI only after successful switch and persisted relaunch permission.
            beforeSwitch()
            NoteWindowManager.shared.resetForVaultRebuild()
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

            // Step 0 (USER REPORT 2026-05-12 v2 fix): mark "disconnect in
            // progress" atomically. The original RCA13-P0-001 fix cleared
            // the bookmark FIRST so a force-quit couldn't leave the vault
            // re-mountable, but that ordering hangs `stopWatchingAsync`
            // because the file-watcher tear-down + filesystem snapshots
            // depend on the security-scoped URL still being live. The
            // bookmark in UserDefaults is what makes the URL re-mountable
            // on launch; the in-memory `vaultURL` is what `stopWatching`
            // needs to call `stopAccessingSecurityScopedResource()`.
            //
            // New pattern: set an in-progress flag immediately. The flag
            // is persistent across crashes. On next launch, restoration
            // sees the flag + clears the bookmark BEFORE the bookmark
            // gets a chance to re-mount the vault. Best of both worlds —
            // no hang during disconnect AND crash-safe.
            FoundationSafety.runtimeUserDefaults.set(true, forKey: VaultSyncService.disconnectInProgressKey)

            // Step 1: canonical runtime-state clear — graph engine,
            // query engine, contextual shadows, instant recall,
            // workspace restore. Mirrors resetAllData() phase 1.
            vaultSync.vaultActivityMessage = "Disconnecting vault... clearing graph engine"
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
            //
            // Skip the recovery snapshot — the user has explicitly told
            // the app to forget this vault, so the snapshot is wasted
            // I/O on large vaults (30+ seconds of APFS clone + SQLite
            // copies). The destructive-clear semantics are unchanged.
            vaultSync.vaultActivityMessage = "Disconnecting vault... releasing watcher"
            let didClear = await vaultSync.stopWatchingAsync(
                preserveData: false,
                skipRecoverySnapshot: true
            )
            if didClear {
                vaultSync.dismissRecoveryIssue()
            } else {
                vaultSync.vaultActivityMessage = "Disconnecting vault... force-clearing state"
                await vaultSync.forceClearDerivedLocalStateForFullReset()
            }
            // NOW clear the persisted vault selection (safe — stopWatching
            // has released the security-scoped URL).
            vaultSync.vaultActivityMessage = "Disconnecting vault... finalizing"
            vaultSync.clearPersistedVaultSelection()
            // Also clear the in-progress flag — disconnect completed
            // cleanly, no recovery needed on next launch.
            FoundationSafety.runtimeUserDefaults.removeObject(forKey: VaultSyncService.disconnectInProgressKey)
            await Task.yield()

            // Step 3: reset UI surface — vaultURL is already nil so
            // SwiftUI flips to the empty state on the next pass. The
            // setup assistant is re-armed by `setupComplete = false`
            // below; keep the legacy full-screen SetupView hidden so it
            // cannot sit between the user and the vault picker.
            notesUI.resetForVaultSwitch()
            NoteWindowManager.shared.resetForVaultRebuild()
            AppBootstrap.shared?.ambientManifest = nil
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            AppBootstrap.shared?.uiState.needsSetup = false
            // Re-arm the SetupAssistant sheet by clearing the
            // first-launch completion flag so the rich setup flow
            // surfaces again instead of being locked out.
            FoundationSafety.runtimeUserDefaults.set(false, forKey: "epistemos.setupComplete")
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
