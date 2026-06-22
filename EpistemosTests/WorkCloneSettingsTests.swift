import Testing
import Foundation
@testable import Epistemos

/// PER-CLONE SETTINGS — "Work (OpenCode)" tab (owner 2026-06-21). Second per-clone tab (after Act).
/// Verifies the tab is wired through the SettingsView surface AND that it mounts the REAL native terminal
/// host (WorkTerminalHostView) + the honest seam health rows — so the work terminal infrastructure is
/// reachable, not a dead component. The exhaustive SettingsSection switches staying compilable is proven
/// by the build itself.
@Suite("Per-clone settings — Work (OpenCode) tab")
struct WorkCloneSettingsTests {
    @Test("the work-clone tab is wired through SettingsView (enum + list + detail)")
    func tabWiredIntoSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(src.contains("case workClone = \"Work (OpenCode)\""))
        #expect(src.contains(".workClone,"))                       // appears in the sections list
        #expect(src.contains("case .workClone: WorkCloneSettingsView()"))  // detail wired
    }

    @Test("the work-clone view mounts the REAL terminal host + honest seam rows (no dead surface)")
    func mountsTerminalHostAndHealth() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkCloneSettingsView.swift")
        #expect(src.contains("WorkTerminalHostView("))    // the real native terminal, now reachable
        #expect(src.contains("WorkOpenCodeShellHealthRow")) // shell seam status
        #expect(src.contains("WorkBackendHealthRow"))       // goose engine seam status
        // Honest arming guidance, not a fake "it works".
        #expect(src.contains("EPISTEMOS_WORK_OPENCODE_V0"))
    }
}
