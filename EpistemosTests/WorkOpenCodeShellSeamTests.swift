import Testing
import Foundation
@testable import Epistemos

/// WORK = OpenCode shell — Seam A (owner 2026-06-21). Locks the honest-inert contract
/// for the OpenCode terminal-shell seam: a pure gate, an inert default that NEVER
/// fakes a terminal (refuses with an honest error), a centralized factory, and a
/// visible health row. Mirrors the Goose=WORK / ActOsaurus seam tests. This is the
/// foundation the native terminal view (SwiftTerm/PTY) + lazy Bun engine + vendored
/// OpenCode TUI plug into.
@Suite("Work = OpenCode shell — Seam A (honest-inert)")
struct WorkOpenCodeShellSeamTests {
    #if !EPISTEMOS_APP_STORE
    @Test("in-app toggle override resolves: override > env flag > off (owner §194, work twin of act)")
    func workOverrideResolutionOrder() {
        let suite = "test.work.opencode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let on = [WorkOpenCodeShellGateStatus.flagName: "1"]

        // no override → defer to env (off by default).
        #expect(!WorkOpenCodeShellGateStatus.resolvedActive(environment: [:], defaults: defaults))
        #expect(WorkOpenCodeShellGateStatus.resolvedActive(environment: on, defaults: defaults))
        // override forces ON with env unset…
        WorkOpenCodeShellGateStatus.setOverride(true, defaults: defaults)
        #expect(WorkOpenCodeShellGateStatus.override(defaults: defaults) == true)
        #expect(WorkOpenCodeShellGateStatus.resolvedActive(environment: [:], defaults: defaults))
        // …and OFF even when the env flag says on (override WINS).
        WorkOpenCodeShellGateStatus.setOverride(false, defaults: defaults)
        #expect(!WorkOpenCodeShellGateStatus.resolvedActive(environment: on, defaults: defaults))
        // clearing reverts to env-flag behavior.
        WorkOpenCodeShellGateStatus.setOverride(nil, defaults: defaults)
        #expect(WorkOpenCodeShellGateStatus.override(defaults: defaults) == nil)
        #expect(WorkOpenCodeShellGateStatus.resolvedActive(environment: on, defaults: defaults))
    }

    @Test("status reflects the override SOURCE honestly (in-app toggle vs env)")
    func workOverrideStatusReflectsSource() {
        let suite = "test.work.opencode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        WorkOpenCodeShellGateStatus.setOverride(true, defaults: defaults)
        let on = WorkOpenCodeShellGateStatus.status(environment: [:], defaults: defaults)
        #expect(on.isActive)
        #expect(on.detail.contains("in-app toggle"))

        WorkOpenCodeShellGateStatus.setOverride(false, defaults: defaults)
        let off = WorkOpenCodeShellGateStatus.status(
            environment: [WorkOpenCodeShellGateStatus.flagName: "1"], defaults: defaults)
        #expect(!off.isActive, "override OFF beats env=1")
        #expect(off.detail.contains("in-app toggle"))
    }
    #endif

    @Test("gate is pure + honest: off by default, arms on the Pro flag")
    func gateHonesty() {
        let off = WorkOpenCodeShellGateStatus.status(environment: [:])
        #expect(off.isActive == false)
        #expect(off.headline.contains("OpenCode"))

        #expect(WorkOpenCodeShellGateStatus.isEnabled("1"))
        #expect(WorkOpenCodeShellGateStatus.isEnabled("true"))
        #expect(WorkOpenCodeShellGateStatus.isEnabled(nil) == false)
        #expect(WorkOpenCodeShellGateStatus.isEnabled("0") == false)

        #if !EPISTEMOS_APP_STORE
        let armed = WorkOpenCodeShellGateStatus.status(
            environment: [WorkOpenCodeShellGateStatus.flagName: "1"]
        )
        #expect(armed.isActive == true)
        #expect(armed.detail.contains("INERT"))   // honest: armed ≠ live
        #else
        let mas = WorkOpenCodeShellGateStatus.status(environment: [:])
        #expect(mas.detail.contains("Pro"))        // honest "Pro only" on MAS, never a silent cut
        #endif
    }

    @Test("inert shell never fakes a terminal — not ready, refuses the launch spec")
    func inertShellRefuses() {
        let shell = InertWorkOpenCodeShell()
        #expect(shell.isReady == false)
        #expect(throws: WorkShellError.self) {
            _ = try shell.launchSpec(workspace: URL(fileURLWithPath: "/tmp"))
        }
    }

    @Test("factory resolves to the inert shell until the real runtime lands")
    func factoryHonest() {
        let shell = WorkOpenCodeShellFactory.resolve(environment: [:])
        #expect(shell.isReady == false)
        // Even ARMED resolves inert today — no fake terminal before the vendor lands.
        let armed = WorkOpenCodeShellFactory.resolve(
            environment: [WorkOpenCodeShellGateStatus.flagName: "1"]
        )
        #expect(armed.isReady == false)
    }

    @Test("launch spec is a pure value type — constructing it starts no process")
    func launchSpecIsPureValue() {
        let spec = WorkShellLaunchSpec(
            executableURL: URL(fileURLWithPath: "/usr/bin/opencode"),
            arguments: ["tui"],
            workingDirectory: URL(fileURLWithPath: "/tmp/work"),
            environment: ["OPENCODE_ENGINE": "http://127.0.0.1:0"]
        )
        #expect(spec.arguments == ["tui"])
        #expect(spec.environment["OPENCODE_ENGINE"]?.contains("127.0.0.1") == true)
    }

    @Test("visible health row exists (rule #8 — the owner can SEE the seam) + is wired")
    func healthRowVisibleAndWired() throws {
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkOpenCodeShellHealthRow.swift")
        #expect(row.contains("struct WorkOpenCodeShellHealthRow"))
        #expect(row.contains("WorkOpenCodeShellGateStatus.status"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("WorkOpenCodeShellHealthRow()"))
    }
}
