import Testing
import Foundation
@testable import Epistemos

/// Owner §122/§194 two-mode ontology: the single source of truth for the current mode + per-mode armed state.
/// Verifies persistence + that `isArmed` reads the REAL act/work gates (the integration, not just a stored bool).
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

    @Test("an unrecognized stored value falls back to act (honest default)")
    func unknownFallsBackToAct() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("garbage", forKey: WorkspaceModeSelection.defaultsKey)
        #expect(WorkspaceModeSelection.current(defaults: defaults) == .act)
    }

    #if !EPISTEMOS_APP_STORE
    @Test("isArmed reads the REAL gates — act override arms act, work override arms work, independently")
    func isArmedReadsGates() {
        let suite = "test.workspace.mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // nothing armed by default (no env, no override).
        #expect(!WorkspaceModeSelection.isArmed(.act, environment: [:], defaults: defaults))
        #expect(!WorkspaceModeSelection.isArmed(.work, environment: [:], defaults: defaults))

        // arming the ACT gate (via its override) arms act only.
        ActOsaurusGateStatus.setOverride(true, defaults: defaults)
        #expect(WorkspaceModeSelection.isArmed(.act, environment: [:], defaults: defaults))
        #expect(!WorkspaceModeSelection.isArmed(.work, environment: [:], defaults: defaults))

        // arming the WORK gate arms work; act stays as set (independent surfaces).
        WorkOpenCodeShellGateStatus.setOverride(true, defaults: defaults)
        #expect(WorkspaceModeSelection.isArmed(.work, environment: [:], defaults: defaults))
        #expect(WorkspaceModeSelection.isArmed(.act, environment: [:], defaults: defaults))

        // and the env flag path is honored too (no override → env arms work).
        WorkOpenCodeShellGateStatus.setOverride(nil, defaults: defaults)
        #expect(WorkspaceModeSelection.isArmed(
            .work, environment: [WorkOpenCodeShellGateStatus.flagName: "1"], defaults: defaults))
    }
    #endif
}
