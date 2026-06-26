import Testing
import Foundation
@testable import Epistemos

/// Mode ontology: the single source of truth for the current mode + per-mode readiness.
/// Verifies persistence + that `isArmed` reads the REAL act/work readiness seams (the integration, not just a stored bool).
@Suite("Workspace mode selection — current mode + per-mode armed state")
struct WorkspaceModeSelectionTests {
    @Test("defaults to act; selecting persists the mode")
    func selectionPersists() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(WorkspaceModeSelection.current(defaults: defaults) == .act)  // default
        WorkspaceModeSelection.select(.work, defaults: defaults)
        #expect(WorkspaceModeSelection.current(defaults: defaults) == .work)
        WorkspaceModeSelection.select(.act, defaults: defaults)
        #expect(WorkspaceModeSelection.current(defaults: defaults) == .act)
    }

    @Test("selecting a mode posts a live route notification")
    func selectingPostsLiveRouteNotification() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let recorder = WorkspaceModeNotificationRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: WorkspaceModeSelection.didSelectNotification,
            object: defaults,
            queue: nil
        ) { notification in
            recorder.record(mode: notification.userInfo?[WorkspaceModeSelection.selectedModeUserInfoKey] as? String)
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            defaults.removePersistentDomain(forName: suite)
        }

        WorkspaceModeSelection.select(.work, defaults: defaults)

        #expect(defaults.string(forKey: WorkspaceModeSelection.defaultsKey) == WorkspaceModeKind.work.rawValue)
        #expect(recorder.lastMode == WorkspaceModeKind.work.rawValue)
    }

    @Test("an unrecognized stored value falls back to act (honest default)")
    func unknownFallsBackToAct() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("garbage", forKey: WorkspaceModeSelection.defaultsKey)
        #expect(WorkspaceModeSelection.current(defaults: defaults) == .act)
    }

    #if !EPISTEMOS_APP_STORE
    @Test("isArmed reads the real readiness seams — act follows shared route, work follows bundled runtime")
    func isArmedReadsGates() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let workReady = WorkOpenCodeRuntime.bundledRuntimeURL() != nil

        // ACT is default-on through the shared local-agent route; WORK is ready only if the real runtime is.
        #expect(WorkspaceModeSelection.isArmed(.act, environment: [:], defaults: defaults))
        #expect(WorkspaceModeSelection.isArmed(.work, environment: [:], defaults: defaults) == workReady)

        // The legacy WORK gate no longer fakes visible readiness; act stays independent.
        WorkOpenCodeShellGateStatus.setOverride(true, defaults: defaults)
        #expect(WorkspaceModeSelection.isArmed(.work, environment: [:], defaults: defaults) == workReady)
        #expect(WorkspaceModeSelection.isArmed(.act, environment: [:], defaults: defaults))

        // The env flag remains a compatibility seam, but the picker dot follows real runtime readiness.
        WorkOpenCodeShellGateStatus.setOverride(nil, defaults: defaults)
        #expect(WorkspaceModeSelection.isArmed(
            .work, environment: [WorkOpenCodeShellGateStatus.flagName: "1"], defaults: defaults) == workReady)
    }
    #endif
}

private final class WorkspaceModeNotificationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var mode: String?

    var lastMode: String? {
        lock.lock()
        defer { lock.unlock() }
        return mode
    }

    func record(mode selectedMode: String?) {
        lock.lock()
        defer { lock.unlock() }
        mode = selectedMode
    }
}
