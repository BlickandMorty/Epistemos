import Foundation
import Darwin
import SwiftData
import Testing
@testable import Epistemos

// MARK: - Phase S.2 / S.4 -- App Store hardening regressions
//
// These tests live at the Swift FFI boundary, not in Rust. They
// guard against the silent drift where:
//   - Swift build flags say this is the App Store target, but the
//     linked Rust binary was compiled WITHOUT `mas-sandbox`, so
//     Pro-only tools leak into the registry.
//   - The opposite: Pro target links a sandboxed Rust binary and
//     loses capabilities it needs.
//
// AppBootstrap.verifyAgentCorePolicyProfile() already fatalError's
// at launch if the profile-vs-flag pair is inconsistent. These
// tests exercise the same invariant from Swift Testing so CI fails before
// a user-visible crash would.
//
// Plan refs:
//   docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase S.2 + S.4
//   docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md section 1.7
//   docs/PHASE_S_AUDIT.md (companion audit report)

@Suite("Phase S -- App Store hardening")
struct AppStoreHardeningTests {

    /// Valid return values for `agentCorePolicyProfile()`.
    /// Keep this list in lockstep with `agent_core_policy_profile`
    /// in agent_core/src/bridge.rs:239.
    private static let validProfiles: Set<String> = ["direct", "mas_sandbox"]
    private static let killNineVaultReplacementTrialCount = 1_000

    // MARK: - KEELSTONE vault durability regressions

    @Test("VaultIndexActor export path uses AtomicVaultWriter for vault files")
    func vaultIndexActorExportUsesAtomicVaultWriter() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let writerSource = try loadMirroredSourceTextFile("Epistemos/Sync/AtomicVaultWriter.swift")
        let coordinatedWrite = Self.sourceSection(
            in: source,
            startingAt: "private func coordinatedWrite",
            endingBefore: "    // MARK: - One-Time Migrations"
        )

        #expect(
            writerSource.contains("actor AtomicVaultWriter"),
            "KEELSTONE Phase 1 requires the vault durable-write spine to live in Epistemos/Sync/AtomicVaultWriter.swift."
        )
        #expect(
            writerSource.contains("func write(_ content: String, to targetURL: URL)"),
            "AtomicVaultWriter's whole-buffer write signature is load-bearing for KEELSTONE and LUMENLENS."
        )
        #expect(
            writerSource.contains("NSFileCoordinator(filePresenter: nil)"),
            "AtomicVaultWriter must coordinate MAS vault writes instead of touching user-selected files directly."
        )
        #expect(
            writerSource.contains(".itemReplacementDirectory"),
            "AtomicVaultWriter must stage replacement data on the same volume before swapping the vault file."
        )
        #expect(
            writerSource.contains("replaceItemAt") || writerSource.contains("Darwin.rename"),
            "AtomicVaultWriter must atomically replace the vault file after the full temp buffer is synced."
        )
        #expect(
            coordinatedWrite?.contains("try await AtomicVaultWriter.shared.write(content, to: url)") == true,
            "VaultIndexActor.exportPage must route vault-file writeback through AtomicVaultWriter, not NoteFileStorage.writeTextAtomically or direct Data/String writes."
        )
        #expect(
            coordinatedWrite?.contains("NoteFileStorage.writeTextAtomically") == false,
            "VaultIndexActor's vault-file write path must not use NoteFileStorage.writeTextAtomically; managed sidecars are not vault truth."
        )
        #expect(
            coordinatedWrite?.contains(".write(to:") == false,
            "VaultIndexActor's vault-file write path must not use direct Data.write/String.write APIs."
        )
    }

    @Test("AtomicVaultWriter writes whole vault buffers through the coordinated durable path")
    func atomicVaultWriterWritesWholeVaultBuffers() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AtomicVaultWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("note.md")
        let oldBody = "# Old\n\n\(String(repeating: "old-body\n", count: 256))"
        let newBody = "# New\n\n\(String(repeating: "new-body\n", count: 256))"

        try await AtomicVaultWriter.shared.write(oldBody, to: target)
        #expect(try String(contentsOf: target, encoding: .utf8) == oldBody)

        try await AtomicVaultWriter.shared.write(newBody, to: target)
        #expect(try String(contentsOf: target, encoding: .utf8) == newBody)
    }

    @Test("VaultNoteEditor production seam uses coordinated vault IO")
    func vaultNoteEditorProductionSeamUsesCoordinatedVaultIO() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/VaultNoteEditor.swift")
        let fileSystem = Self.sourceSection(
            in: source,
            startingAt: "static func fileSystem()",
            endingBefore: "    /// Apply `edits` atomically"
        )

        #expect(
            fileSystem?.contains("try Self.coordinatedRead(url)") == true
                && source.contains("NSFileCoordinator(filePresenter: nil)"),
            "VaultNoteEditor.fileSystem() must coordinate reads from user-selected vault files."
        )
        #expect(
            fileSystem?.contains("AtomicVaultWriter.shared.write(content, to: url)") == true,
            "VaultNoteEditor.fileSystem() must write vault files through AtomicVaultWriter, not String.write/Data.write."
        )
        #expect(
            fileSystem?.contains("String(contentsOf:") == false
                && fileSystem?.contains(".write(to: url") == false,
            "VaultNoteEditor.fileSystem() must not directly read/write vault files with Foundation convenience APIs."
        )
    }

    @Test("kill -9 during same-volume vault replacement never leaves a partial note")
    func killNineDuringVaultReplacementNeverLeavesPartialNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultKillNineSoak-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let scriptURL = root.appendingPathComponent("writer.py")
        try Self.writeKillNineHarness(to: scriptURL)

        let stages = ["mid_temp_write", "pre_replace", "post_replace"]
        for trial in 0..<Self.killNineVaultReplacementTrialCount {
            let stage = stages[trial % stages.count]
            let targetURL = root.appendingPathComponent("note-\(trial).md")
            let markerURL = root.appendingPathComponent("marker-\(trial)")
            let payloadURL = root.appendingPathComponent("payload-\(trial).txt")
            let oldPayload = Self.killNinePayload(label: "OLD-\(trial)", lineCount: 512)
            let newPayload = Self.killNinePayload(label: "NEW-\(trial)", lineCount: 512)
            try await AtomicVaultWriter.shared.write(oldPayload, to: targetURL)
            try Data(newPayload.utf8).write(to: payloadURL, options: [])

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "python3",
                scriptURL.path,
                targetURL.path,
                markerURL.path,
                stage,
                payloadURL.path,
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()

            try Self.waitForFile(markerURL, timeout: 2.0)
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()

            let data = try Data(contentsOf: targetURL)
            let oldData = Data(oldPayload.utf8)
            let newData = Data(newPayload.utf8)
            let message: Comment = "Trial \(trial) killed writer at \(stage); vault file must be exactly old or exactly new, never truncated or mixed. Observed \(data.count) bytes."
            #expect(data == oldData || data == newData, message)
        }
    }

    @Test("VaultSyncService FSEvents stream replays and escalates deterministically")
    func vaultSyncServiceFSEventsUsesKeelstoneFlagsAndCheckpoint() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/VaultSyncService.swift")
        let watcher = Self.sourceSection(
            in: source,
            startingAt: "private func startFSEventsWatcher",
            endingBefore: "private func persistVaultFSEventCheckpoint"
        )
        let callback = Self.sourceSection(
            in: source,
            startingAt: "private nonisolated static var vaultFSEventsCallback",
            endingBefore: "private func startDirectoryDispatchSourceWatcher"
        )

        #expect(
            source.contains("vaultFSEventCheckpointPrefix = \"keelstone.lastEventID.\""),
            "KEELSTONE Phase 2 requires a persisted per-vault FSEvents checkpoint."
        )
        #expect(
            source.contains("SHA256.hash(data: Data(path.utf8))"),
            "The FSEvents checkpoint key must be per vault, not a single global event ID."
        )
        #expect(
            watcher?.contains("kFSEventStreamCreateFlagUseExtendedData") == true,
            "FSEvents must use extended data so path and fileID/inode are available for deterministic reconcile."
        )
        #expect(
            watcher?.contains("kFSEventStreamCreateFlagWatchRoot") == true,
            "FSEvents must watch the vault root so root moves/deletes escalate to a rescan/remount path."
        )
        #expect(
            watcher?.contains("kFSEventStreamEventIdSinceNow") == true
                && watcher?.contains("defaults.string(forKey: checkpointKey)") == true,
            "The stream must resume from the persisted checkpoint and only fall back to since-now on first mount."
        )
        #expect(
            callback?.contains("kFSEventStreamEventExtendedDataPathKey") == true
                && callback?.contains("kFSEventStreamEventExtendedFileIDKey") == true,
            "The callback must decode the real extended-data path and fileID keys; kFSEventStreamEventExtendedDataKeyInode is not real."
        )
    }

    @Test("VaultSyncService classifies FSEvents escalation and path events deterministically")
    func vaultSyncServiceFSEventsClassificationIsExecutable() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("keelstone-fsevents-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let note = root.appendingPathComponent("Note.md")
        try Data("body".utf8).write(to: note)
        let missing = root.appendingPathComponent("Missing.md")
        let hidden = root.appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent("Skip.md")
        let outside = fm.temporaryDirectory.appendingPathComponent("Outside.md")

        func event(_ url: URL, flags: Int, id: UInt64 = 1) -> VaultFileSystemEvent {
            VaultFileSystemEvent(
                path: url.path,
                flags: FSEventStreamEventFlags(flags),
                inode: 42,
                eventID: FSEventStreamEventId(id)
            )
        }
        func classify(_ event: VaultFileSystemEvent) -> VaultFileSystemEventClassification {
            VaultSyncService.classifyVaultFileSystemEvent(event, vaultURL: root)
        }

        #expect(classify(event(note, flags: 0)) == .changed(note.standardizedFileURL.path))
        #expect(
            classify(event(note, flags: kFSEventStreamEventFlagMustScanSubDirs)) == .fullRescan,
            "Dropped/coalesced FSEvents must escalate to a deterministic rescan."
        )
        #expect(
            classify(event(root, flags: kFSEventStreamEventFlagRootChanged)) == .fullRescan,
            "Root moves/deletes must not be treated as ordinary note edits."
        )
        #expect(
            classify(event(root, flags: kFSEventStreamEventFlagItemIsDir)) == .fullRescan,
            "Directory-level events are too coarse for path-only reconcile and must rescan."
        )
        #expect(
            classify(event(note, flags: kFSEventStreamEventFlagItemRemoved)) == .deleted(note.standardizedFileURL.path)
        )
        #expect(
            classify(event(missing, flags: kFSEventStreamEventFlagItemRenamed)) == .deleted(missing.standardizedFileURL.path)
        )
        #expect(
            classify(event(note, flags: kFSEventStreamEventFlagItemRenamed)) == .changed(note.standardizedFileURL.path)
        )
        #expect(classify(event(missing, flags: 0)) == .deleted(missing.standardizedFileURL.path))
        #expect(classify(event(hidden, flags: 0)) == .ignored)
        #expect(classify(event(outside, flags: 0)) == .ignored)
    }

    @Test("VaultSyncService does not hide external edits during self-write windows")
    func vaultSyncServiceSelfWriteWindowStillReconcilesEvents() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/VaultSyncService.swift")
        let debounce = Self.sourceSection(
            in: source,
            startingAt: "private func scheduleDebouncedVaultFileSystemRefresh",
            endingBefore: "private func drainAndProcessPendingVaultFileSystemChanges"
        )
        let drain = Self.sourceSection(
            in: source,
            startingAt: "private func drainAndProcessPendingVaultFileSystemChanges",
            endingBefore: "private nonisolated static func processExternalVaultFileSystemChanges"
        )

        #expect(
            debounce?.contains("removeAll(keepingCapacity: true)") == false,
            "A self-originated save window must not clear pending watcher paths; external edits can race inside the same FSEvents batch."
        )
        #expect(
            drain?.contains("guard !shouldIgnore") == false,
            "Self-originated events must still run through deterministic reconcile instead of being dropped."
        )
        #expect(
            drain?.contains("persistVaultFSEventCheckpoint(lastEventID, for: vaultURL)") == true,
            "The FSEvents checkpoint should advance only after the reconcile task reports success."
        )
    }

    @Test("Experimental backend quit cleanup reaps process trees across 100 cycles")
    func experimentalBackendQuitReapsProcessTreeForHundredCycleSoak() throws {
        let supervisor = try loadMirroredSourceTextFile("Epistemos/ExperimentalAgent/ExperimentalRuntimeSupervisor.swift")
        let appDelegate = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(
            supervisor.contains("AppBootstrap.shared?.orphanCleanup.track(process)"),
            "Experimental backend processes must be registered with OrphanSubprocessCleanup so app termination owns their process tree."
        )
        #expect(
            supervisor.contains("cleanupProcessTree(rootPID: pid)"),
            "ExperimentalRuntimeSupervisor.stop() must terminate the backend process tree, not only the root Process object."
        )
        #expect(
            supervisor.contains("AgentSurfaceChildLedger.forget(pid: pid)"),
            "Experimental backend cleanup must clear the crash-orphan ledger when the process exits or is deliberately stopped."
        )
        #expect(
            appDelegate.contains("ExperimentalRuntimeSupervisor.shared.stop()"),
            "EpistemosAppDelegate.performTeardown must stop the Experimental backend during app quit."
        )

        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return
        #else
        let cleanup = OrphanSubprocessCleanup()
        for cycle in 0..<100 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "sleep 60 & wait"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            let rootPID = pid_t(process.processIdentifier)
            cleanup.track(process)
            defer {
                cleanup.cleanupProcessTree(rootPID: rootPID)
                cleanup.untrack(rootPID)
            }

            let childPIDs = try Self.waitForChildPIDs(of: rootPID, timeout: 1.0)
            cleanup.cleanupProcessTree(rootPID: rootPID)
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
            cleanup.untrack(rootPID)

            try Self.waitForPIDExit(rootPID, timeout: 1.0)
            for childPID in childPIDs {
                let message: Comment = "Cycle \(cycle): child PID \(childPID) survived Experimental quit cleanup."
                #expect(try Self.waitForPIDExit(childPID, timeout: 1.0), message)
            }
        }
        #endif
    }

    @Test("iCloud materialization is async metadata-query based, never Thread.sleep polling")
    func iCloudMaterializerUsesAsyncMetadataQuery() throws {
        let materializer = try loadMirroredSourceTextFile("Epistemos/Sync/iCloudMaterializer.swift")
        let actor = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let upsert = Self.sourceSection(
            in: actor,
            startingAt: "private func upsertPage",
            endingBefore: "private func updateImportedBodyDerivedState"
        )

        #expect(
            materializer.contains("actor iCloudMaterializer"),
            "iCloud materialization must run off-main behind an actor."
        )
        #expect(
            materializer.contains("NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope"),
            "User-selected iCloud Drive vaults are external documents, not just the app's ubiquitous container."
        )
        #expect(
            materializer.contains("NSMetadataQueryDidUpdate"),
            "Hydration waits must be driven by NSMetadataQuery updates."
        )
        #expect(
            !materializer.contains("Thread.sleep"),
            "Do not poll iCloud downloads with Thread.sleep; that can block coordination and starve the sync daemon."
        )
        #expect(
            upsert?.contains("iCloudMaterializer.shared.state(of: fileURL)") == true
                && upsert?.contains("try await iCloudMaterializer.shared.whenLocal(fileURL)") == true,
            "VaultIndexActor import/reindex must materialize dataless iCloud files before classifying them as unreadable or unchanged."
        )
        #expect(
            !(upsert ?? "").contains("evictUbiquitousItem"),
            "Vault import/reindex must not evict ubiquitous items while coordinating or reading vault files."
        )
    }

    @Test("Dirty live editor external edits enter visible conflict-copy flow")
    func dirtyLiveEditorExternalEditCreatesConflictCopy() throws {
        let actor = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let upsert = Self.sourceSection(
            in: actor,
            startingAt: "private func upsertPage",
            endingBefore: "private func writeExternalEditConflictCopy"
        )
        let conflictCopy = Self.sourceSection(
            in: actor,
            startingAt: "private func writeExternalEditConflictCopy",
            endingBefore: "private func updateImportedBodyDerivedState"
        )

        #expect(
            upsert?.contains("NoteWindowManager.shared.editorBody(for: pageID)") == true,
            "Phase 4 requires a thin active-editor seam so unsaved live text is checked before external vault imports overwrite the managed body."
        )
        #expect(
            upsert?.contains("liveEditorIsDirty") == true
                && upsert?.contains("writeExternalEditConflictCopy") == true,
            "A dirty live editor changed on disk must enter a visible conflict-copy flow, not silently reload or clobber either side."
        )
        #expect(
            conflictCopy?.contains("external-conflict-") == true,
            "The conflict copy filename must be visible and recognizable in the vault."
        )
        #expect(
            conflictCopy?.contains("AtomicVaultWriter.shared.write(diskContent, to: candidate)") == true,
            "Conflict copies are vault files too; they must use the coordinated durable writer."
        )
        #expect(
            !actor.contains("write-lease") && !actor.contains("LensSessionCoordinator"),
            "KEELSTONE should keep only a thin editor seam; LUMENLENS owns the session machine/write lease."
        )
    }

    @Test("KEELSTONE body truth keeps production note saves vault-md-first")
    func keelstoneBodyTruthHasNoProductionSidecarWriters() throws {
        let productionSources = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )
        let forbiddenCalls = [
            "NoteFileStorage.writeBody(",
            "NoteFileStorage.writeBodyAsync(",
            "NoteFileStorage.writePreparedImportedVaultBodyAsync(",
            "NoteFileStorage.scheduleWriteBody(",
            ".saveBody(",
        ]
        let allowedDefinitionFiles: Set<String> = [
            "Epistemos/Sync/NoteFileStorage.swift",
            "Epistemos/Models/SDPage.swift",
        ]

        var violations: [String] = []
        for url in productionSources {
            let relativePath = Self.relativeMirroredSourcePath(for: url)
            guard !allowedDefinitionFiles.contains(relativePath) else { continue }
            let source = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            for forbiddenCall in forbiddenCalls where source.contains(forbiddenCall) {
                violations.append("\(relativePath): \(forbiddenCall)")
            }
        }

        #expect(
            violations.isEmpty,
            "KEELSTONE Phase 4.5 retires durable note-bodies as truth; production code must route body persistence through VaultSyncService.savePageBodyFileFirst / AtomicVaultWriter. Violations: \(violations)"
        )

        let vaultSync = try loadMirroredSourceTextFile("Epistemos/Sync/VaultSyncService.swift")
        let fileFirstSave = Self.sourceSection(
            in: vaultSync,
            startingAt: "func savePageBodyFileFirst",
            endingBefore: "    @discardableResult\n    func recoverDraftIfNewer"
        )
        #expect(
            fileFirstSave?.contains("NoteFileStorage.stageBodyForImmediateRead") == true
                && fileFirstSave?.contains("page.applyInteractiveDerivedState(from: stagedBody)") == true
                && fileFirstSave?.contains("BlockMirror.sync(pageId: pageId, body: stagedBody") == true
                && fileFirstSave?.contains("exportPage(pageId: pageId, to: vaultURL, bodyOverride: stagedBody)") == true,
            "The in-app body save path must stage only for immediate reads, refresh derived metadata, and write the exact whole buffer to the vault .md."
        )
        #expect(
            fileFirstSave?.contains("NoteFileStorage.writeBody") == false
                && fileFirstSave?.contains("page.saveBody") == false,
            "The file-first body save path must not persist retired note-body sidecars."
        )
    }

    @Test("KEELSTONE project.yml target-scoped surface and KINDRED macros cannot drift")
    func keelstoneProjectSurfaceMacroGuardrails() throws {
        let project = try loadMirroredSourceTextFile("project.yml")
        let baseSettings = Self.sourceSection(
            in: project,
            startingAt: "settings:\n  base:",
            endingBefore: "  configs:"
        )
        let targets = Self.sourceSection(
            in: project,
            startingAt: "targets:",
            endingBefore: "schemes:"
        ) ?? project
        let epistemosTarget = Self.yamlTopLevelSection(
            in: targets,
            marker: "  Epistemos:"
        )
        let appStoreTarget = Self.yamlTopLevelSection(
            in: targets,
            marker: "  Epistemos-AppStore:"
        )
        let appTargetMarkers = targets.components(separatedBy: .newlines)
            .filter { line in
                line == "  Epistemos:" || line == "  Epistemos-AppStore:"
            }

        #expect(
            appTargetMarkers == ["  Epistemos:", "  Epistemos-AppStore:"],
            "KEELSTONE requires exactly two app targets: Epistemos and Epistemos-AppStore."
        )
        #expect(
            baseSettings?.contains("EPISTEMOS_EXPERIMENTAL") == false
                && baseSettings?.contains("EPISTEMOS_APP_STORE") == false
                && baseSettings?.contains("KINDRED_ENABLED") == false,
            "Surface and KINDRED macros must never live in shared/base settings; App Store inherits base via $(inherited)."
        )
        #expect(
            epistemosTarget?.contains("EPISTEMOS_EXPERIMENTAL") == true
                && epistemosTarget?.contains("KINDRED_ENABLED") == true
                && epistemosTarget?.contains("EPISTEMOS_APP_STORE") == false,
            "The Epistemos target must define only the Experimental surface plus KINDRED_ENABLED."
        )
        #expect(
            appStoreTarget?.contains("EPISTEMOS_APP_STORE") == true
                && appStoreTarget?.contains("MAS_SANDBOX") == true
                && appStoreTarget?.contains("EPISTEMOS_EXPERIMENTAL") == false
                && appStoreTarget?.contains("KINDRED_ENABLED") == false,
            "The App Store target must define only the MAS surface and must not inherit KINDRED_ENABLED."
        )
    }

    @Test("AppSurface makes a flagless or double-surface build fail at compile time")
    func appSurfaceHasHardCompileGuards() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/App/AppSurface.swift")

        #expect(
            surface.contains("#if EPISTEMOS_APP_STORE && EPISTEMOS_EXPERIMENTAL")
                && surface.contains("#error("),
            "AppSurface must #error when both surface macros are active."
        )
        #expect(
            surface.contains("#if !EPISTEMOS_APP_STORE && !EPISTEMOS_EXPERIMENTAL")
                && surface.contains("neither EPISTEMOS_APP_STORE nor EPISTEMOS_EXPERIMENTAL is defined"),
            "A flagless build must fail to compile; there is no third surface."
        )
        #expect(
            !surface.contains("PRO_BUILD"),
            "Surface selection must use EPISTEMOS_EXPERIMENTAL/EPISTEMOS_APP_STORE, not a resurrected PRO_BUILD flag."
        )
    }

    @Test("KEELSTONE reconcile convergence: incremental change set equals fresh rebuild")
    @MainActor
    func keelstoneIncrementalReconcileEqualsFreshRebuild() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeelstoneConvergence-\(UUID().uuidString)", isDirectory: true)
        let vaultURL = root.appendingPathComponent("Vault", isDirectory: true)
        let bodiesURL = root.appendingPathComponent("Bodies", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let alphaURL = vaultURL.appendingPathComponent("Alpha.md")
        let betaURL = vaultURL.appendingPathComponent("Beta.md")
        let gammaURL = vaultURL.appendingPathComponent("Gamma.md")

        try Self.writeExternalVaultText("# Alpha\n\nfirst body\n", to: alphaURL)
        try Self.writeExternalVaultText("# Beta\n\nremove me\n", to: betaURL)

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(bodiesURL) {
            let incrementalContainer = try Self.makeKeelstoneModelContainer()
            let incrementalActor = VaultIndexActor(modelContainer: incrementalContainer)
            try await incrementalActor.importVault(from: vaultURL)

            try Self.writeExternalVaultText("# Alpha\n\nfirst body edited outside\n", to: alphaURL)
            try FileManager.default.removeItem(at: betaURL)
            try Self.writeExternalVaultText("# Gamma\n\nnew external note\n", to: gammaURL)

            _ = try await incrementalActor.reindexFile(at: alphaURL, vaultURL: vaultURL)
            try await incrementalActor.handleFileDeletion(at: betaURL)
            _ = try await incrementalActor.reindexFile(at: gammaURL, vaultURL: vaultURL)

            let incremental = try Self.keelstonePageSnapshot(
                in: incrementalContainer,
                vaultURL: vaultURL
            )

            let freshContainer = try Self.makeKeelstoneModelContainer()
            let freshActor = VaultIndexActor(modelContainer: freshContainer)
            try await freshActor.importVault(from: vaultURL)
            let fresh = try Self.keelstonePageSnapshot(
                in: freshContainer,
                vaultURL: vaultURL
            )

            #expect(
                incremental == fresh,
                "Incremental reconcile must converge to the same page snapshot as a fresh rebuild from disk. incremental=\(incremental) fresh=\(fresh)"
            )
        }
    }

    @Test("KEELSTONE derived search index corruption quarantines and rebuilds from page snapshots")
    func keelstoneSearchIndexCorruptionQuarantinesAndRebuildsFromSnapshots() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeelstoneSearchIndexRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let databaseURL = root.appendingPathComponent("search.sqlite")
        try Data("not a sqlite database".utf8).write(to: databaseURL, options: [])

        let service = try SearchIndexService(databaseURL: databaseURL)
        let quarantineDirectory = root.appendingPathComponent("search-index-quarantine", isDirectory: true)
        let quarantinedFiles = try FileManager.default.contentsOfDirectory(
            at: quarantineDirectory,
            includingPropertiesForKeys: nil
        )
        #expect(
            quarantinedFiles.contains { $0.lastPathComponent.contains("search.sqlite") },
            "A corrupt derived search.sqlite must be quarantined, not erased in place or treated as source of truth."
        )

        try await service.rebuildFromSwiftDataAsync([
            (
                id: "keelstone-note",
                title: "Keelstone",
                body: "Vault files remain truth after a derived-index quarantine.",
                tags: "durability",
                updatedAt: Date()
            ),
        ])
        let diagnostics = try service.supportDiagnostics()
        #expect(diagnostics.quickCheck == "ok")
        #expect(diagnostics.integrityCheck == "ok")
        #expect(diagnostics.manifest["last_full_rebuild_page_count"] == "1")
        #expect(diagnostics.manifest["last_truncate_checkpoint_at"] != nil)
    }

    @Test("KEELSTONE derived search index self-heal and diagnostics cannot drift")
    func keelstoneSearchIndexSelfHealSourceGuardrails() throws {
        let searchIndex = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(
            searchIndex.contains("openPreparedDatabaseWithRecovery(at:")
                && searchIndex.contains("quarantineDerivedDatabaseFiles(at:")
                && searchIndex.contains("search-index-quarantine"),
            "SearchIndexService must quarantine and reopen the derived SQLite cache when open/migrate/check fails."
        )
        #expect(
            searchIndex.contains("try setupSchema(dbPool)")
                && searchIndex.contains("try detectFeatures(dbPool)")
                && searchIndex.contains("throw SearchIndexError.recoveryReopenFailed"),
            "Migration/open failures must flow through the same quarantine recovery path as quick_check failures."
        )
        #expect(
            !searchIndex.contains("eraseDatabaseOnSchemaChange"),
            "Shipping GRDB code must never enable eraseDatabaseOnSchemaChange."
        )
        #expect(
            searchIndex.contains("CREATE TABLE IF NOT EXISTS derived_index_manifest")
                && searchIndex.contains("last_full_rebuild_page_count")
                && searchIndex.contains("last_truncate_checkpoint_at"),
            "The existing GRDB file needs KEELSTONE manifest rows for rebuild/checkpoint telemetry."
        )
        #expect(
            searchIndex.contains("func quickCheckForDiagnostics()")
                && searchIndex.contains("PRAGMA quick_check")
                && searchIndex.contains("func integrityCheckForDiagnostics()")
                && searchIndex.contains("PRAGMA integrity_check")
                && bootstrap.contains("func searchIndexSupportDiagnostics() async -> SearchIndexIntegrityDiagnostics?"),
            "quick_check and integrity_check must be reachable from support diagnostics, not only comments."
        )
        #expect(
            searchIndex.contains("func truncateCheckpoint() throws")
                && searchIndex.contains("db.checkpoint(.truncate)")
                && searchIndex.contains("pagesToUpsert.count + toDelete.count >= Self.bulkCheckpointThreshold"),
            "Bulk rebuild/reconcile must bound WAL growth with an explicit truncate checkpoint."
        )
    }

    @Test("agentCorePolicyProfile returns a recognized value")
    func policyProfileReturnsRecognizedValue() {
        let profile = agentCorePolicyProfile()
        let message: Comment = "Unrecognized policy profile: '\(profile)'. Update validProfiles and bridge.rs together when adding a new profile."
        #expect(Self.validProfiles.contains(profile), message)
    }

    /// Test builds default to the Pro target (the `Epistemos` scheme).
    /// Under the default test build, the FFI must report `"direct"`.
    /// If this test fails, either:
    ///   (a) the test scheme has been changed to Epistemos-AppStore,
    ///       in which case update this test's expected value and the
    ///       EPISTEMOS_APP_STORE compilation-flag branch below; or
    ///   (b) the agent_core Rust lib was built with `--features
    ///       mas-sandbox` but linked into the non-MAS Swift target,
    ///       which is the drift case this test exists to catch.
    @Test("policy profile matches the compiled Swift build flag")
    func policyProfileMatchesBuildFlag() {
        let profile = agentCorePolicyProfile()
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        let masMessage: Comment = "App Store build flag is set but linked agent_core is '\(profile)'. This is the exact condition AppBootstrap.verifyAgentCorePolicyProfile fatals on at launch; CI should fail here first."
        #expect(profile == "mas_sandbox", masMessage)
        #else
        let directMessage: Comment = "Pro (non-App Store) build flag but linked agent_core is '\(profile)'. Either the Rust lib was built with --features mas-sandbox and linked into the Pro target, or a new build variant was added without updating this test."
        #expect(profile == "direct", directMessage)
        #endif
    }

    // MARK: - Entitlements drift tests (Phase S.2)
    //
    // Parse the two entitlements plists from source and assert key
    // invariants. Catches the regression where a Pro-only entitlement
    // gets added to the MAS plist (blocking App Review) or where the
    // MAS plist loses `app-sandbox` (making the MAS archive unshippable).
    //
    // Reads from the test bundle's `SourceMirror/` (populated by the
    // EpistemosTests "Bundle Test Source Mirror" preBuildScript) rather
    // than `#filePath`. The mirror lives in DerivedData; using `#filePath`
    // pointed at `~/Downloads/Epistemos`, which can hang on macOS TCC
    // protected-folder prompts under xcodebuild test.

    private func loadEntitlements(named name: String) throws -> [String: Any] {
        let url = try sourceMirrorURL(for: "Epistemos/\(name)")
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw EntitlementsError.notADictionary(name)
        }
        return dict
    }

    enum EntitlementsError: Error {
        case notADictionary(String)
    }

    /// Keys that MUST be present in the MAS plist. Losing any of these
    /// means the MAS archive will be rejected or broken in production.
    private static let masRequiredKeys: [String] = [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.files.user-selected.read-write",
        "com.apple.security.files.bookmarks.app-scope",
    ]

    /// Keys that MUST NOT appear in the MAS plist. Adding any of these
    /// will trigger App Store review rejection (or weaken the sandbox
    /// enough that review rejects it). If a future feature genuinely
    /// needs one of these, it belongs in the Pro-only deployment
    /// profile, not in the App Store build.
    private static let masForbiddenKeys: [String] = [
        "com.apple.security.cs.allow-unsigned-executable-memory",
        "com.apple.security.cs.disable-library-validation",
        "com.apple.security.automation.apple-events",
        "com.apple.security.temporary-exception.mach-lookup.global-name",
        "com.apple.security.files.all",
        // document-scope bookmarks are Pro-only per the deployment
        // profile split (see docs/PHASE_S_AUDIT.md section 2 and
        // existing ProductionHardeningTests). App-scope bookmarks are
        // what MAS uses instead.
        "com.apple.security.files.bookmarks.document-scope",
    ]

    @Test("MAS entitlements plist declares every required App Store key")
    func masEntitlementsDeclareRequiredKeys() throws {
        let plist = try loadEntitlements(named: "Epistemos-AppStore.entitlements")
        for key in Self.masRequiredKeys {
            let message: Comment = "MAS plist is missing required key '\(key)'. Without this, the App Store archive will be rejected or the app will fail at launch inside the sandbox."
            #expect(plist[key] != nil, message)
            if let value = plist[key] as? Bool {
                #expect(value, "MAS plist key '\(key)' must be true, found false")
            }
        }
    }

    @Test("MAS entitlements plist omits every Pro-only App Store blocker")
    func masEntitlementsOmitProOnlyKeys() throws {
        let plist = try loadEntitlements(named: "Epistemos-AppStore.entitlements")
        for key in Self.masForbiddenKeys {
            let message: Comment = "MAS plist contains forbidden key '\(key)'. This entitlement belongs in the Pro-only deployment profile; adding it to the MAS plist will trigger App Store review rejection. Move it to Epistemos.entitlements or remove the underlying feature from the MAS source set."
            #expect(plist[key] == nil, message)
        }
    }

    // MARK: - Info.plist drift tests (Phase S.2)

    private func loadInfoPlist(named name: String) throws -> [String: Any] {
        let url = try sourceMirrorURL(for: name)
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw EntitlementsError.notADictionary(name)
        }
        return dict
    }

    /// Usage-description keys the MAS Info.plist must keep non-empty.
    /// Each corresponds to a capability the app actually exercises; an
    /// empty or missing description is an automatic App Review hold.
    private static let masRequiredUsageDescriptionKeys: [String] = [
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
        "NSDocumentsFolderUsageDescription",
        "NSDesktopFolderUsageDescription",
        "NSDownloadsFolderUsageDescription",
    ]

    @Test("MAS Info.plist answers the export-compliance question")
    func masInfoPlistDeclaresExportComplianceAnswer() throws {
        // `ITSAppUsesNonExemptEncryption` must be present in Info.plist
        // or App Store Connect asks the export-compliance questionnaire
        // on every submission. Setting it statically (true or false)
        // skips the questionnaire. Epistemos uses only standard
        // HTTPS/TLS so `false` is the correct answer; the test just
        // asserts the key is present so the drift that deletes it is
        // caught.
        let plist = try loadInfoPlist(named: "Epistemos-AppStore-Info.plist")
        let message: Comment = "MAS Info.plist is missing ITSAppUsesNonExemptEncryption. Without it App Store Connect will prompt the export-compliance questionnaire on every submission."
        #expect(plist["ITSAppUsesNonExemptEncryption"] != nil, message)
    }

    @Test("MAS Info.plist keeps required usage-description strings non-empty")
    func masInfoPlistKeepsUsageDescriptionsNonEmpty() throws {
        let plist = try loadInfoPlist(named: "Epistemos-AppStore-Info.plist")
        for key in Self.masRequiredUsageDescriptionKeys {
            let value = plist[key] as? String
            let missingMessage: Comment = "MAS Info.plist is missing '\(key)'. Without it, App Store review holds the submission pending a reason string."
            #expect(value != nil, missingMessage)
            let emptyMessage: Comment = "MAS Info.plist '\(key)' is empty. Must be a user-facing sentence; empty strings are an auto-reject."
            #expect(value?.isEmpty == false, emptyMessage)
        }
    }

    @Test("Pro entitlements plist still carries the Pro-only keys")
    func proEntitlementsStillCarryProOnlyKeys() throws {
        // Sanity check: if the Pro plist ever loses the Pro-only keys
        // the MAS test would start passing trivially. Assert the Pro
        // plist still declares the capabilities that justify having a
        // separate deployment profile at all. Note: Pro is not a true
        // superset of MAS, because MAS adds `com.apple.security.app-sandbox`
        // while Pro omits it; these are two different profiles, not a
        // subset / superset pair.
        let plist = try loadEntitlements(named: "Epistemos.entitlements")
        let proRequired = [
            // allow-unsigned-executable-memory (MLX) + automation.apple-events (Omega) dropped from
            // the Pro entitlements with cloud-only/Omega removal 2026-07-03; disable-library-validation
            // stays (required to load the embedded Rust dylibs).
            "com.apple.security.cs.disable-library-validation",
        ]
        for key in proRequired {
            let message: Comment = "Pro plist is missing '\(key)'. The Pro deployment profile exists to carry these; losing one means either Pro has narrowed in scope (update this test) or the plist drifted (fix the plist)."
            #expect(plist[key] != nil, message)
        }
    }

    // MARK: - PrivacyInfo.xcprivacy drift tests (Phase S.6)
    //
    // The PrivacyInfo.xcprivacy manifest declares the App Privacy posture
    // App Store review reads alongside the App Store Connect "App Privacy"
    // questionnaire. The audit doc PHASE_S_AUDIT.md section 3 (Privacy manifest) documents the
    // baseline these tests guard:
    //   NSPrivacyTracking          = false
    //   NSPrivacyTrackingDomains   = []
    //   NSPrivacyCollectedDataTypes = []
    //   NSPrivacyAccessedAPITypes  = 4 required-reason categories
    //
    // The Settings -> Privacy transparency pane added in slice S.6 shows
    // these manifest-backed fields to the user. If the manifest drifts (e.g.,
    // someone adds a tracking SDK and pushes NSPrivacyTracking to true,
    // or adds a data collection category) without updating the user-
    // facing pane in lockstep, App Review's stated posture and the
    // shipping app's stated posture would disagree. These tests catch
    // the drift before review does.

    private func loadPrivacyManifest() throws -> [String: Any] {
        let url = try sourceMirrorURL(for: "Epistemos/Resources/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw EntitlementsError.notADictionary("PrivacyInfo.xcprivacy")
        }
        return dict
    }

    @Test("PrivacyInfo.xcprivacy declares NSPrivacyTracking == false and no tracking domains")
    func privacyManifestDeclaresNoTracking() throws {
        let manifest = try loadPrivacyManifest()
        let trackingMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyTracking must be false. Flipping this to true is an App Store posture change that requires updating both the Settings -> Privacy pane and the App Store Connect App Privacy questionnaire in lockstep."
        #expect((manifest["NSPrivacyTracking"] as? Bool) == false, trackingMessage)

        let domains = manifest["NSPrivacyTrackingDomains"] as? [Any] ?? []
        let domainsMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyTrackingDomains must be empty. A non-empty array signals at least one domain doing user tracking and contradicts the user-facing claim that the app has no trackers."
        #expect(domains.isEmpty, domainsMessage)
    }

    @Test("PrivacyInfo.xcprivacy declares no NSPrivacyCollectedDataTypes")
    func privacyManifestCollectsNoData() throws {
        let manifest = try loadPrivacyManifest()
        let collected = manifest["NSPrivacyCollectedDataTypes"] as? [Any] ?? []
        let message: Comment = "PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes must be empty. Adding a collected-data category is a substantive privacy posture change that needs an explicit user-facing disclosure (Settings -> Privacy pane), an App Store Connect questionnaire update, and a privacy policy URL update."
        #expect(collected.isEmpty, message)
    }

    @Test("PrivacyInfo.xcprivacy declares the four expected NSPrivacyAccessedAPITypes with their reason codes")
    func privacyManifestDeclaresFourAccessedAPITypesWithReasons() throws {
        let manifest = try loadPrivacyManifest()
        let accessedAPITypes = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        var observed: [String: [String]] = [:]
        for entry in accessedAPITypes {
            guard let category = entry["NSPrivacyAccessedAPIType"] as? String else { continue }
            let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
            observed[category] = reasons
        }

        // The four required-reason API categories the audit doc section 3 records,
        // each with the exact Apple reason code we ship today. Adding a
        // fifth category requires updating PHASE_S_AUDIT.md section 3, this test,
        // and the user-facing Privacy pane together.
        let expected: [(category: String, reason: String)] = [
            ("NSPrivacyAccessedAPICategoryFileTimestamp", "C617.1"),
            ("NSPrivacyAccessedAPICategorySystemBootTime", "35F9.1"),
            ("NSPrivacyAccessedAPICategoryDiskSpace", "E174.1"),
            ("NSPrivacyAccessedAPICategoryUserDefaults", "CA92.1"),
        ]

        let countMessage: Comment = "PrivacyInfo.xcprivacy NSPrivacyAccessedAPITypes must have exactly \(expected.count) entries. Found \(accessedAPITypes.count). Add or remove a required-reason API together with PHASE_S_AUDIT.md section 3 and the Privacy pane."
        #expect(accessedAPITypes.count == expected.count, countMessage)

        for (category, reason) in expected {
            let categoryMessage: Comment = "PrivacyInfo.xcprivacy is missing required-reason API category '\(category)'. The audit baseline declares it; restore the entry or update PHASE_S_AUDIT.md section 3."
            #expect(observed[category] != nil, categoryMessage)
            let reasonMessage: Comment = "PrivacyInfo.xcprivacy category '\(category)' must list reason '\(reason)' (single-element array). Found \(observed[category] ?? [])."
            #expect(observed[category] == [reason], reasonMessage)
        }
    }

    // MARK: - App Store release-gate script regressions (Drop 12/13)

    @Test("App Review audit fails MAS subprocess findings instead of warning")
    func appReviewAuditFailsMASSubprocessFindingsInsteadOfWarning() throws {
        let source = try loadMirroredSourceTextFile("Tools/app-review-audit/app-review-audit.sh")

        #expect(
            !source.contains("::warning::W26 stage-0 informational"),
            "App Review audit still reports MAS subprocess findings as warnings. MAS-reachable subprocess/PTY/shell findings must fail the release gate."
        )
        #expect(
            !source.contains("stage-0 audit does not fail"),
            "App Review audit still documents subprocess findings as non-fatal stage-0 findings."
        )
        #expect(
            source.contains("::error::W26") && source.contains("MAS-reachable subprocess surface"),
            "App Review audit must emit an error when MAS-reachable subprocess patterns are found."
        )
        #expect(
            source.contains("target=${1:-appstore}") || source.contains("target=\"${1:-appstore}\""),
            "App Review audit should make the audited target explicit, defaulting to appstore."
        )
    }

    @Test("App Store artifact scan inspects final bundle strings symbols executables and resources")
    func appStoreArtifactScanInspectsFinalBundleStringsSymbolsExecutablesAndResources() throws {
        let source = try loadMirroredSourceTextFile("scripts/scan_appstore_bundle.sh")
        let requiredFragments = [
            "find \"$APP\" -type f",
            "strings",
            "nm -gU",
            "otool -L",
            "-perm",
            "pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl",
            "MOHAWK|MoLoRA|raw Helios|research packets|Hermes|omega_ax|omega-mcp|pty",
        ]

        for fragment in requiredFragments {
            #expect(
                source.contains(fragment),
                "scripts/scan_appstore_bundle.sh is missing required artifact-scan fragment: \(fragment)"
            )
        }
        #expect(
            source.contains("FORBIDDEN_SYMBOL_PATTERN"),
            "scripts/scan_appstore_bundle.sh must scan fork/exec as Mach-O symbol/linkage evidence, not only as raw strings."
        )
        #expect(
            source.contains("FORBIDDEN_PROCESS_SYMBOL_PATTERN='(^|[[:space:]])"),
            "scripts/scan_appstore_bundle.sh must match fork/exec as symbol tokens, not substrings inside Rust-mangled type names."
        )
        #expect(
            !source.contains("FORBIDDEN_STRING_PATTERN='(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)"),
            "scripts/scan_appstore_bundle.sh should not fail raw string scans on generic exec/fork text such as SQL exec logs; fork/exec belong in the symbol/linkage gate."
        )
        #expect(
            source.contains("(^|[^A-Za-z0-9_.])docker"),
            "scripts/scan_appstore_bundle.sh should flag Docker command/runtime evidence without treating benign ignored-path text like `.docker/` as a subprocess surface."
        )
    }

    // "App Store build patch disables MLX CPU JIT shell helper" removed with cloud-only/Omega
    // removal 2026-07-03 — the MLX dependency stack was deleted, so scripts/patch_mlx_metal_warnings.sh
    // no longer exists and there is no MLX CPU JIT to disable.

    @Test("App Store target does not link GGUF llama runtime")
    func appStoreTargetDoesNotLinkGGUFLlamaRuntime() throws {
        let spec = try loadMirroredSourceTextFile("project.yml")
        let pbxproj = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")

        let proTarget = Self.sourceSection(
            in: spec,
            startingAt: "  Epistemos:",
            endingBefore: "  Epistemos-AppStore:"
        )
        let appStoreTarget = Self.sourceSection(
            in: spec,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  # AR1"
        )
        let appStorePBXTarget = Self.sourceSection(
            in: pbxproj,
            startingAt: "/* Epistemos-AppStore */ = {\n\t\t\tisa = PBXNativeTarget;",
            endingBefore: "/* End PBXNativeTarget section */"
        )

        // GGUFRuntimeBridge + the llama.framework rm-step removed with cloud-only/Omega removal
        // 2026-07-03 — the GGUF/llama runtime is gone from BOTH targets (project.yml has no
        // GGUFRuntimeBridge or llama.framework), so the Pro-vs-AppStore split collapses to "absent everywhere".
        #expect(proTarget?.contains("GGUFRuntimeBridge") == false)
        #expect(appStoreTarget != nil)
        #expect(appStorePBXTarget != nil)
        #expect(appStoreTarget?.contains("GGUFRuntimeBridge") == false)
        #expect(appStorePBXTarget?.contains("GGUFRuntimeBridge") == false)
        #expect(appStoreTarget?.contains("rm -rf \"${frameworks_dir}/llama.framework\"") == false)
    }

    @Test("App Store source cannot canImport the GGUF runtime from shared DerivedData")
    func appStoreSourceCannotCanImportGGUFRuntimeFromSharedDerivedData() throws {
        let swiftFiles = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )
        let importHits = try swiftFiles.compactMap { url -> String? in
            let source = try String(contentsOf: url, encoding: .utf8)
            guard source.contains("canImport(GGUFRuntimeBridge)") else { return nil }
            return url.path
        }

        #expect(
            importHits.isEmpty,
            "Swift source must not canImport(GGUFRuntimeBridge). A prior Pro build leaves GGUFRuntimeBridge in shared DerivedData, making App Store builds import the Pro-only llama module. Hits: \(importHits.joined(separator: ", "))"
        )
    }

    @Test("App Store scheme has tests or CI runs a dedicated MAS artifact gate")
    func appStoreSchemeHasTestsOrCIRunsDedicatedMASArtifactGate() throws {
        let scheme = try loadMirroredSourceTextFile(
            "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme"
        )
        let ci = try loadMirroredSourceTextFile(".github/workflows/ci.yml")

        let testablesRange = scheme.range(of: "<Testables>")?.upperBound
        let testablesEnd = scheme.range(of: "</Testables>")?.lowerBound
        let testablesBody: Substring
        if let testablesRange, let testablesEnd, testablesRange <= testablesEnd {
            testablesBody = scheme[testablesRange..<testablesEnd]
        } else {
            testablesBody = ""
        }

        let schemeHasTestables = testablesBody.contains("<TestableReference")
        let ciRunsMASGate = ci.contains("Epistemos-AppStore")
            && ci.contains("Tools/app-review-audit/app-review-audit.sh")
            && ci.contains("scripts/scan_appstore_bundle.sh")

        #expect(
            schemeHasTestables || ciRunsMASGate,
            "Epistemos-AppStore.xcscheme has no Testables and CI does not run a dedicated MAS artifact gate."
        )
    }

    @Test("App Store agent command modes do not advertise Pro subprocess tools")
    func appStoreAgentCommandModesHideProSubprocessTools() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/AgentCommandCenterState.swift")
        let toolAllowlistSection = Self.sourceSection(
            in: source,
            startingAt: "var preferredToolNames: Set<String>",
            endingBefore: "var expertAllowlist: [String]"
        )
        #expect(
            toolAllowlistSection != nil,
            "AgentCommandCenterState.swift must keep preferredToolNames distinct enough for MAS tool-advertising source guards."
        )
        let guardedSource = toolAllowlistSection ?? source
        let proOnlyToolNames = [
            "action.bash",
            "action.terminal",
            "system.process",
            "execute_code",
        ]

        for caseMarker in ["case .debug:", "case .code:"] {
            let caseBody = Self.switchCaseBody(in: guardedSource, startingAt: caseMarker)
            #expect(
                caseBody != nil,
                "AgentCommandCenterState.swift is missing \(caseMarker); update this MAS source guard with the new command-mode layout."
            )
            guard let caseBody else { continue }

            #expect(
                caseBody.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"),
                "\(caseMarker) must gate Pro-only subprocess/tool names out of the MAS binary."
            )
            guard
                let gateRange = caseBody.range(of: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX"),
                let elseRange = caseBody.range(of: "#else", range: gateRange.upperBound..<caseBody.endIndex),
                let endifRange = caseBody.range(of: "#endif", range: elseRange.upperBound..<caseBody.endIndex)
            else {
                Issue.record("\(caseMarker) must use an explicit MAS branch and Pro branch around tool allowlists.")
                continue
            }

            let masBranch = String(caseBody[gateRange.upperBound..<elseRange.lowerBound])
            let proBranch = String(caseBody[elseRange.upperBound..<endifRange.lowerBound])
            for toolName in proOnlyToolNames {
                #expect(
                    !masBranch.contains(toolName),
                    "\(caseMarker) MAS branch must not embed Pro-only tool name \(toolName)."
                )
            }
            #expect(
                proBranch.contains("action.bash"),
                "\(caseMarker) Pro branch should keep the direct-build tool path; this guard is meant to gate MAS, not delete Pro capability."
            )
        }
    }

    private static func switchCaseBody(in source: String, startingAt marker: String) -> String? {
        guard let markerRange = source.range(of: marker) else { return nil }
        let searchRange = markerRange.upperBound..<source.endIndex
        let nextCase = source.range(of: "\n        case .", range: searchRange)?.lowerBound ?? source.endIndex
        return String(source[markerRange.lowerBound..<nextCase])
    }

    private static func sourceSection(
        in source: String,
        startingAt startMarker: String,
        endingBefore endMarker: String
    ) -> String? {
        guard let startRange = source.range(of: startMarker) else { return nil }
        let searchRange = startRange.upperBound..<source.endIndex
        let endIndex = source.range(of: endMarker, range: searchRange)?.lowerBound ?? source.endIndex
        return String(source[startRange.lowerBound..<endIndex])
    }

    private static func yamlTopLevelSection(in source: String, marker: String) -> String? {
        guard let markerRange = source.range(of: marker) else { return nil }
        let searchRange = markerRange.upperBound..<source.endIndex
        let endIndex = source[searchRange].ranges(of: "\n  ")
            .compactMap { range -> String.Index? in
                let lineStart = source.index(after: range.lowerBound)
                let rest = source[lineStart...]
                guard rest.hasPrefix("  "), !rest.hasPrefix("    ") else { return nil }
                return range.lowerBound
            }
            .first ?? source.endIndex
        return String(source[markerRange.lowerBound..<endIndex])
    }

    private static func relativeMirroredSourcePath(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        if let range = path.range(of: "/SourceMirror/") {
            return String(path[range.upperBound...])
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .standardizedFileURL
            .path
        let prefix = currentDirectory.hasSuffix("/") ? currentDirectory : currentDirectory + "/"
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }

        return url.lastPathComponent
    }

    private struct KeelstonePageSnapshot: Equatable, CustomStringConvertible {
        let relativePath: String
        let title: String
        let body: String
        let tags: [String]
        let wordCount: Int
        let lastSyncedBodyHash: String?

        var description: String {
            "(\(relativePath), title: \(title), words: \(wordCount), hash: \(lastSyncedBodyHash ?? "nil"))"
        }
    }

    @MainActor
    private static func makeKeelstoneModelContainer() throws -> ModelContainer {
        let schema = Schema([
            SDPage.self,
            SDFolder.self,
            SDPageVersion.self,
            SDBlock.self,
            SDNoteInsight.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private static func keelstonePageSnapshot(
        in container: ModelContainer,
        vaultURL: URL
    ) throws -> [KeelstonePageSnapshot] {
        let context = ModelContext(container)
        let pages = try context.fetch(FetchDescriptor<SDPage>())
        let rootPath = vaultURL.standardizedFileURL.path
        return pages.compactMap { page in
            guard let filePath = page.filePath else { return nil }
            let standardizedPath = URL(fileURLWithPath: filePath).standardizedFileURL.path
            guard standardizedPath.hasPrefix(rootPath + "/") else { return nil }
            return KeelstonePageSnapshot(
                relativePath: String(standardizedPath.dropFirst(rootPath.count + 1)),
                title: page.title,
                body: page.loadBody(mapped: false, fast: false),
                tags: page.tags,
                wordCount: page.wordCount,
                lastSyncedBodyHash: page.lastSyncedBodyHash
            )
        }
        .sorted { $0.relativePath < $1.relativePath }
    }

    private static func writeExternalVaultText(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let fd = open(url.path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }

        let bytes = Array(content.utf8)
        var offset = 0
        while offset < bytes.count {
            let written = bytes.withUnsafeBytes { buffer in
                write(fd, buffer.baseAddress!.advanced(by: offset), bytes.count - offset)
            }
            guard written > 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            offset += written
        }
        guard fsync(fd) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private static func killNinePayload(label: String, lineCount: Int) -> String {
        (0..<lineCount)
            .map { "\(label) line \($0) \(String(repeating: "x", count: 64))" }
            .joined(separator: "\n") + "\n"
    }

    private static func writeKillNineHarness(to url: URL) throws {
        let script = """
        import os
        import sys
        import time

        target_path = sys.argv[1]
        marker_path = sys.argv[2]
        stage = sys.argv[3]
        payload_path = sys.argv[4]
        with open(payload_path, "rb") as payload_file:
            payload = payload_file.read()
        directory = os.path.dirname(target_path)
        temp_path = os.path.join(
            directory,
            "." + os.path.basename(target_path) + ".tmp." + str(os.getpid()),
        )

        def mark_ready():
            marker_fd = os.open(marker_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            try:
                os.write(marker_fd, stage.encode("utf-8"))
                os.fsync(marker_fd)
            finally:
                os.close(marker_fd)

        temp_fd = os.open(temp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        try:
            if stage == "mid_temp_write":
                midpoint = max(1, len(payload) // 2)
                os.write(temp_fd, payload[:midpoint])
                os.fsync(temp_fd)
                mark_ready()
                time.sleep(30)
                os.write(temp_fd, payload[midpoint:])
            else:
                os.write(temp_fd, payload)
            os.fsync(temp_fd)
        finally:
            os.close(temp_fd)

        if stage == "pre_replace":
            mark_ready()
            time.sleep(30)

        os.replace(temp_path, target_path)

        if stage == "post_replace":
            mark_ready()
            time.sleep(30)

        directory_fd = os.open(directory, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)

        while True:
            time.sleep(1)
        """
        guard let data = script.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: [])
    }

    private static func waitForFile(_ url: URL, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return
            }
            usleep(10_000)
        }
        throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
    }

    private static func waitForChildPIDs(of rootPID: pid_t, timeout: TimeInterval) throws -> [pid_t] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let pids = childPIDs(of: rootPID)
            if !pids.isEmpty {
                return pids
            }
            usleep(10_000)
        }
        throw POSIXError(.ECHILD)
    }

    @discardableResult
    private static func waitForPIDExit(_ pid: pid_t, timeout: TimeInterval) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !pidIsAlive(pid) {
                return true
            }
            usleep(10_000)
        }
        return !pidIsAlive(pid)
    }

    private static func pidIsAlive(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private static func childPIDs(of parentPID: pid_t) -> [pid_t] {
        var capacity = 8
        while true {
            var buffer = Array(repeating: pid_t(0), count: capacity)
            let bufferSize = buffer.count * MemoryLayout<pid_t>.stride
            let childCount = Int(proc_listchildpids(parentPID, &buffer, Int32(bufferSize)))
            guard childCount > 0 else { return [] }
            if childCount < capacity {
                return Array(buffer.prefix(childCount))
            }
            capacity *= 2
        }
    }

    // MARK: - Per-file MAS-branch subprocess-launch regressions (Phase S.2)
    //
    // For files that MUST stay compiled into the MAS binary (i.e. the
    // ones that cannot be whole-file gated because they expose live
    // production API used by MAS-reachable callers), assert that the
    // MAS-visible portion does NOT contain `Process.init(`. The Pro
    // (non-MAS) branch is allowed to keep the subprocess fallback.

    /// Strip lines inside `#if !EPISTEMOS_APP_STORE ... #endif` blocks
    /// so the result reflects what the MAS compiler would see for the
    /// current branch.
    ///
    /// **Limitation -- simple-shape parser only.** This implementation
    /// tracks ONLY `#if !EPISTEMOS_APP_STORE` opens and matches them
    /// against the next `#endif`. It does NOT track other `#if`
    /// directives. That means: an unrelated `#if FOO` inside an excluded
    /// `#if !EPISTEMOS_APP_STORE` block will end on its own `#endif`
    /// rather than being treated as a nested level, and the next
    /// `#endif` would then incorrectly re-open the excluded section.
    /// This is fine for AudioTranscriber today, which uses the simple
    /// flat `#if !EPISTEMOS_APP_STORE ... #endif` shape with no nested
    /// `#if` directives. If a future file under this regression mixes
    /// nested `#if`s inside the gate, upgrade the parser to track
    /// generic `#if` depth before adding that file to the regression.
    /// Also does not interpret `#else` (no current call site needs it).
    private func masVisibleSource(_ source: String) -> String {
        var kept: [String] = []
        var inExcludedBlock = false
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if !EPISTEMOS_APP_STORE") {
                inExcludedBlock = true
                continue
            }
            if inExcludedBlock {
                if trimmed.hasPrefix("#endif") {
                    inExcludedBlock = false
                }
                continue
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    /// Result of `scanForMarkerInGateBranches(source:marker:)`.
    private struct GateMarkerScan {
        /// True if `marker` was seen inside a `#if !EPISTEMOS_APP_STORE`
        /// block (i.e., compiled into Pro but not MAS).
        var insideExcludedBlock: Bool
        /// True if `marker` was seen outside any `#if !EPISTEMOS_APP_STORE`
        /// block (i.e., compiled into both MAS and Pro).
        var outsideExcludedBlock: Bool
    }

    /// Walk a Swift source string line by line, track `#if
    /// !EPISTEMOS_APP_STORE` open / `#else` / `#endif` boundaries (the
    /// shape used by surgical S.2 gates), and report whether `marker`
    /// substring was seen inside the excluded block, outside, or both.
    /// Comment-only lines (starting with `//`) are skipped.
    ///
    /// Limitation: this helper, like `masVisibleSource`, only tracks
    /// `#if !EPISTEMOS_APP_STORE` opens. Other `#if` directives (e.g.
    /// `#if DEBUG`) inside the gated region are not recognized. Today's
    /// VaultSyncService and VaultChatMutator surgical gates use the
    /// simple flat shape; if a future call site mixes nested `#if`s
    /// inside the gate, upgrade this helper before adding the file to
    /// the regression set.
    private func scanForMarkerInGateBranches(
        source: String,
        marker: String
    ) -> GateMarkerScan {
        var inExcludedBlock = false
        var insideExcludedBlock = false
        var outsideExcludedBlock = false
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if !EPISTEMOS_APP_STORE") {
                inExcludedBlock = true
                continue
            }
            if inExcludedBlock {
                if trimmed.hasPrefix("#endif") || trimmed.hasPrefix("#else") {
                    // `#else` of `#if !EPISTEMOS_APP_STORE` opens the
                    // MAS-visible branch; treat it the same as `#endif`
                    // for the purpose of "are we still inside the
                    // excluded block".
                    inExcludedBlock = false
                    continue
                }
                if line.contains(marker) && !trimmed.hasPrefix("//") {
                    insideExcludedBlock = true
                }
            } else {
                if line.contains(marker) && !trimmed.hasPrefix("//") {
                    outsideExcludedBlock = true
                }
            }
        }
        return GateMarkerScan(
            insideExcludedBlock: insideExcludedBlock,
            outsideExcludedBlock: outsideExcludedBlock
        )
    }

    @Test("VaultSyncService MAS branch contains no tmutil Process.init")
    func vaultSyncServiceMASBranchHasNoTMUtilProcessInit() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Sync/VaultSyncService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the Pro branch must still keep the tmutil subprocess
        // implementation. Removing tmutil from the file entirely is not
        // the goal -- the Pro/direct release uses APFS safety snapshots
        // for recovery.
        let proSanity: Comment = "VaultSyncService.swift no longer contains Process.init -- the Pro/direct release relies on /usr/bin/tmutil for APFS safety snapshots. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        let scan = scanForMarkerInGateBranches(source: source, marker: "Process.init(")

        let outsideMessage: Comment = "VaultSyncService.swift contains a Process.init( call OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. The MAS sandbox cannot spawn /usr/bin/tmutil; this leaks subprocess launch into the MAS binary."
        #expect(!scan.outsideExcludedBlock, outsideMessage)

        let insideMessage: Comment = "VaultSyncService.swift no longer has Process.init( inside any `#if !EPISTEMOS_APP_STORE` block, but the file does still contain Process.init(. The Pro branch may have been moved or deleted; restore the gating shape so MAS stays subprocess-free here."
        #expect(scan.insideExcludedBlock, insideMessage)
    }

    @Test("VaultChatMutator MAS branch contains no /usr/bin/git Process.init or git-launch arguments")
    func vaultChatMutatorMASBranchHasNoGitProcessInit() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Vault/VaultChatMutator.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the Pro branch must still keep the git subprocess
        // implementation. Removing git from the file entirely is not
        // the goal -- the Pro/direct release uses git to record an
        // audit trail of approved staged vault mutations.
        let proSanity: Comment = "VaultChatMutator.swift no longer contains Process.init -- the Pro/direct release relies on /usr/bin/git for the staged-mutation audit trail. If this is intentional, update or remove this test."
        #expect(source.contains("Process.init("), proSanity)

        // First marker: the literal Process.init( allocation. Catches a
        // direct subprocess-spawn primitive.
        let processScan = scanForMarkerInGateBranches(source: source, marker: "Process.init(")
        let processOutsideMessage: Comment = "VaultChatMutator.swift contains a Process.init( call OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. The MAS sandbox cannot spawn /usr/bin/git; this leaks subprocess launch into the MAS binary. Approved staged mutations must still durable-write the file via VaultVerifiedFileWriter (already unconditional), but the git layer must stay Pro-only."
        #expect(!processScan.outsideExcludedBlock, processOutsideMessage)
        let processInsideMessage: Comment = "VaultChatMutator.swift no longer has Process.init( inside any `#if !EPISTEMOS_APP_STORE` block, but the file does still contain Process.init(. The Pro branch may have been moved or deleted; restore the gating shape so MAS stays subprocess-free here."
        #expect(processScan.insideExcludedBlock, processInsideMessage)

        // Second marker: the git executable selection. Catches the case
        // where someone keeps `Process.init` gated but moves the
        // git-specific executable configuration outside the gate --
        // which would silently make MAS prepare a git command even if
        // it cannot run it. Both halves must agree on the gate.
        let gitExecutableScan = scanForMarkerInGateBranches(
            source: source,
            marker: "process.executableURL = URL(fileURLWithPath: \"/usr/bin/git\")"
        )
        let gitExecutableOutsideMessage: Comment = "VaultChatMutator.swift contains `/usr/bin/git` executable setup OUTSIDE a `#if !EPISTEMOS_APP_STORE` block. Even if Process.init( is gated, leaking the git-specific executable prep is a sign that the surgical gate has drifted."
        #expect(!gitExecutableScan.outsideExcludedBlock, gitExecutableOutsideMessage)
        let gitExecutableInsideMessage: Comment = "VaultChatMutator.swift no longer has `/usr/bin/git` executable setup inside a `#if !EPISTEMOS_APP_STORE` block, but the file still contains Process.init(. The Pro git-launch shape may have been refactored away; restore it or update this test."
        #expect(gitExecutableScan.insideExcludedBlock, gitExecutableInsideMessage)
    }

    // MARK: - Category B regression (Phase S.2 ChunkedMCPFraming)
    //
    // The earlier ChunkedMCPFraming.swift used `dlopen(nil, RTLD_LAZY)` +
    // `dlsym("shm_open" / "shm_unlink")` to reach the POSIX symbols
    // because Swift cannot import variadic C functions. That self-handle
    // dlopen was sandbox-safe but the literal `dlopen` / `dlsym` /
    // `RTLD_LAZY` strings could attract paranoid App Store review
    // tooling. The fix replaced the runtime-symbol-lookup with a fixed-
    // signature C shim (`Epistemos/Bridge/ShmPosixShim.{h,c}`) wired
    // through `Epistemos-Bridging-Header.h`. This regression asserts
    // the dlopen / dlsym workaround does not creep back in.

    @Test("ChunkedMCPFraming Swift source has no dlopen/dlsym/RTLD_LAZY in compiled code")
    func chunkedMCPFramingHasNoDlopenWorkaround() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Bridge/ChunkedMCPFraming.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // Sanity: the C shim is the replacement; the Swift file still
        // calls into it via the bridging header. If `epistemos_shm_open`
        // is gone, the shim was deleted and the dlopen workaround is
        // probably back.
        let shimSanity: Comment = "ChunkedMCPFraming.swift no longer references epistemos_shm_open. The Phase S.2 Category B C-shim replacement may have been reverted; restore it (Epistemos/Bridge/ShmPosixShim.{h,c}) or update this test."
        #expect(source.contains("epistemos_shm_open"), shimSanity)

        // The actual regression: dlopen / dlsym / RTLD_LAZY must not
        // appear in non-comment code. Reuse the existing #if-aware
        // scanner; for ChunkedMCPFraming there is no `#if !EPISTEMOS_APP_STORE`
        // gate in this file, so EVERY non-comment occurrence shows up
        // in `outsideExcludedBlock`. Both flags must be false to pass.
        for marker in ["dlopen(", "dlsym(", "RTLD_LAZY"] {
            let scan = scanForMarkerInGateBranches(source: source, marker: marker)
            let message: Comment = "ChunkedMCPFraming.swift contains `\(marker)` in non-comment code. The dlopen(nil) / dlsym workaround was replaced by the fixed-signature C shim in Epistemos/Bridge/ShmPosixShim.{h,c}; restore the shim path or update this test."
            #expect(!scan.outsideExcludedBlock && !scan.insideExcludedBlock, message)
        }
    }

    // MARK: - Bounded-agent termination invariants (Phase S.4)
    //
    // Phase S.4 acceptance criterion (PHASE_S_AUDIT.md §7, IMPLEMENTATION_PLAN_FROM_ADVICE.md §S.4):
    // the agent loop must terminate at the maxTurns ceiling and must NOT
    // re-enter the backend after the ceiling fires. The local loop's strict
    // `.maxTurnsExceeded(N)` invariant is asserted directly in
    // `EpistemosTests/LocalAgentLoopTests.swift::localLoopStopsWhenToolCallsNeverConverge`.
    // This suite covers the parallel invariant on the Swift `AgentQueryEngine`
    // harness, which has its own ceiling-check at
    // `Epistemos/Engine/AgentHarness/AgentQueryEngine.swift:169`:
    //   if let maxTurns = config.maxTurns, turnCount > maxTurns {
    //       continuation.yield(.sessionComplete(result: .errorMaxTurns(...)))
    //       return
    //   }
    // The test uses a per-call unique backend identifier so it does not need
    // a global unregister API, and a recording backend whose execute() bumps
    // an actor-protected counter so we can assert the engine does NOT call
    // through after the ceiling fires.

    @Test("AgentQueryEngine emits .errorMaxTurns and stops calling the backend after maxTurns")
    func agentQueryEngineHaltsAtMaxTurnsCeiling() async {
        let stats = RecordingMaxTurnsBackendStats()
        let identifier = "test.AppStoreHardeningTests.maxTurnsCeiling.\(UUID().uuidString)"
        let backend = RecordingMaxTurnsBackend(identifier: identifier, stats: stats)

        await MainActor.run {
            BackendRegistry.shared.register(backend)
        }

        let config = AgentQueryEngineConfig(
            backendIdentifier: identifier,
            maxTurns: 1,
            cwd: FileManager.default.temporaryDirectory.path
        )
        let engine = AgentQueryEngine(config: config)

        // Turn 1 -- turnCount becomes 1, NOT greater than maxTurns=1, so the
        // engine resolves the backend and drives one execute() call. The
        // recording backend yields `.complete(...)` immediately so the turn
        // ends with `.success`.
        var turn1Result: AgentQueryEngineResult?
        do {
            for try await event in await engine.submitMessage("first") {
                if case .sessionComplete(let result) = event {
                    turn1Result = result
                }
            }
        } catch {
            Issue.record("Turn 1 should not throw, got: \(error)")
        }
        let executeCallsAfterTurn1 = await stats.executeCallCount()
        let turn1ExpectMessage: Comment =
            "Turn 1 must drive the backend exactly once before the maxTurns ceiling can fire on turn 2 (turnCount becomes 1, 1 > 1 is false)."
        #expect(executeCallsAfterTurn1 == 1, turn1ExpectMessage)
        if case .success = turn1Result {
            // expected branch
        } else {
            Issue.record("Expected .success on turn 1, got: \(String(describing: turn1Result))")
        }

        // Turn 2 -- turnCount becomes 2, 2 > 1 fires the ceiling. The engine
        // must yield `.errorMaxTurns(turns: 2)` and must NOT call execute()
        // again. This is the invariant Phase S.4 was added to lock down.
        var turn2Result: AgentQueryEngineResult?
        do {
            for try await event in await engine.submitMessage("second") {
                if case .sessionComplete(let result) = event {
                    turn2Result = result
                }
            }
        } catch {
            Issue.record("Turn 2 should not throw, got: \(error)")
        }
        let executeCallsAfterTurn2 = await stats.executeCallCount()
        let turn2BackendCallMessage: Comment =
            "Backend execute() must NOT be called after the maxTurns ceiling fires on turn 2; expected counter to remain 1, observed \(executeCallsAfterTurn2)."
        #expect(executeCallsAfterTurn2 == 1, turn2BackendCallMessage)
        if case .errorMaxTurns(_, let turns) = turn2Result {
            let turnsMessage: Comment =
                "Phase S.4 ceiling invariant: AgentQueryEngine reports `turns` from the post-increment turnCount; with maxTurns=1, turn 2 must report turns=2."
            #expect(turns == 2, turnsMessage)
        } else {
            Issue.record("Expected .errorMaxTurns on turn 2, got: \(String(describing: turn2Result))")
        }
    }
}

// MARK: - Test helpers for AgentQueryEngine ceiling test

/// Actor-protected counter for backend execute() invocations. Lives outside
/// the suite struct because Swift Testing requires `@Test` methods to be
/// instance-bound but the recording backend protocol is `nonisolated Sendable`
/// -- the actor lets the backend's execute() bump a counter without sharing
/// mutable state.
private actor RecordingMaxTurnsBackendStats {
    private var count: Int = 0
    func bump() { count += 1 }
    func executeCallCount() -> Int { count }
}

/// Minimal `AgentBackend` that records every execute() call into the shared
/// stats actor and yields a single immediate `.complete` event so the engine's
/// turn loop terminates cleanly. The unique `identifier` prevents collisions
/// with backends registered by app bootstrap or other test runs -- there is no
/// global unregister API, and this avoids needing one.
private struct RecordingMaxTurnsBackend: AgentBackend {
    let identifier: String
    let displayName: String = "AppStoreHardening recording backend (max-turns)"
    let stats: RecordingMaxTurnsBackendStats

    func execute(
        prompt: String,
        history: [String],
        options: AgentExecOptions
    ) async throws -> AsyncThrowingStream<AgentBackendEvent, Error> {
        await stats.bump()
        return AsyncThrowingStream { continuation in
            continuation.yield(.complete(sessionID: nil, stopReason: "stop"))
            continuation.finish()
        }
    }
}
