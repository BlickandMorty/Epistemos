import Foundation
import Testing
@testable import Epistemos

// Proves the WorkOpenGUISupervisor wire contract is SYMMETRIC with the runtime-proven `og-sidecar.mjs` (the Node
// sidecar that drives the OpenGUI Runtime). The supervisor's pure helpers (`encodeCommand`/`decodeFrame`/env/extractors)
// are the only part verifiable WITHOUT spawning the sidecar; the live spawn+stream is owner-runtime-proof (OWED).
// Field names here mirror og-sidecar.mjs EXACTLY: in `{id,cmd,...}`; out `ready`/`reply{id,ok,data}`/`error`/`event{sessionId,event}`.
@Suite("WorkOpenGUISupervisor — NDJSON wire contract (mirrors og-sidecar.mjs)")
struct WorkOpenGUISupervisorTests {

    // MARK: encodeCommand (Swift → sidecar stdin)

    @Test("encodeCommand emits one NDJSON line with id+cmd+args, parseable as the sidecar parses it")
    func encodesCommand() throws {
        let line = try WorkOpenGUISupervisor.encodeCommand(
            id: "r7", cmd: "init", args: ["repo": "/tmp/x", "harnesses": ["opencode", "codex"]])
        #expect(line.hasSuffix("\n")) // line-delimited
        let obj = try #require(
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        #expect(obj["id"] as? String == "r7")
        #expect(obj["cmd"] as? String == "init")
        #expect(obj["repo"] as? String == "/tmp/x")
        #expect((obj["harnesses"] as? [String]) == ["opencode", "codex"])
    }

    @Test("encodeCommand with no args still carries id+cmd (e.g. diagnose/close)")
    func encodesBareCommand() throws {
        let line = try WorkOpenGUISupervisor.encodeCommand(id: "r1", cmd: "diagnose", args: [:])
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        #expect(obj["cmd"] as? String == "diagnose")
        #expect(obj["id"] as? String == "r1")
    }

    // MARK: decodeFrame (sidecar stdout → Swift)

    @Test("decodeFrame parses the `ready` frame")
    func decodesReady() {
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"ready\"}") == .ready)
    }

    @Test("decodeFrame parses a `reply` frame; connectedHarnessIds extract → the engine-picker list")
    func decodesReplyInit() throws {
        let frame = WorkOpenGUISupervisor.decodeFrame(
            "{\"type\":\"reply\",\"id\":\"r1\",\"ok\":true,\"data\":{\"connectedHarnessIds\":[\"opencode\",\"codex\"],\"errors\":[]}}")
        guard case .reply(let id, let ok, let data) = frame else { Issue.record("not a reply"); return }
        #expect(id == "r1")
        #expect(ok)
        #expect(WorkOpenGUISupervisor.stringArray(data, key: "connectedHarnessIds") == ["opencode", "codex"])
    }

    @Test("validatedConnectedHarnesses rejects zero connected engines with the sidecar init errors")
    func rejectsZeroConnectedHarnesses() throws {
        let ok = Data(#"{"connectedHarnessIds":["opencode"],"errors":[]}"#.utf8)
        #expect(try WorkOpenGUISupervisor.validatedConnectedHarnesses(ok) == ["opencode"])

        let empty = Data(#"{"connectedHarnessIds":[],"errors":[{"harnessId":"opencode","error":"Server process exited with code 1"}]}"#.utf8)
        do {
            _ = try WorkOpenGUISupervisor.validatedConnectedHarnesses(empty)
            Issue.record("expected zero connected harnesses to throw")
        } catch WorkOGError.sidecar(let message) {
            #expect(message.contains("init connected no Work engines"))
            #expect(message.contains("opencode"))
            #expect(message.contains("Server process exited"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("decodeFrame parses a `reply` with sessionId → stringField extracts it (sessions.create)")
    func decodesReplyCreate() {
        let frame = WorkOpenGUISupervisor.decodeFrame(
            "{\"type\":\"reply\",\"id\":\"r2\",\"ok\":true,\"data\":{\"sessionId\":\"opencode:ses_abc\",\"harnessId\":\"opencode\"}}")
        guard case .reply(_, let ok, let data) = frame else { Issue.record("not a reply"); return }
        #expect(ok)
        #expect(WorkOpenGUISupervisor.stringField(data, key: "sessionId") == "opencode:ses_abc")
    }

    @Test("decodeFrame parses an `error` frame with id (→ fails that request) and without id (→ lastError)")
    func decodesError() {
        let withID = WorkOpenGUISupervisor.decodeFrame("{\"type\":\"error\",\"id\":\"r3\",\"message\":\"boom\"}")
        guard case .error(let id, let msg) = withID else { Issue.record("not an error"); return }
        #expect(id == "r3")
        #expect(msg == "boom")
        let noID = WorkOpenGUISupervisor.decodeFrame("{\"type\":\"error\",\"message\":\"global\"}")
        guard case .error(let id2, _) = noID else { Issue.record("not an error"); return }
        #expect(id2 == nil)
    }

    @Test("decodeFrame parses an `event` frame; the raw event JSON round-trips (LiveSessionEvent forwarded to UI)")
    func decodesEvent() throws {
        let frame = WorkOpenGUISupervisor.decodeFrame(
            "{\"type\":\"event\",\"sessionId\":\"opencode:ses_abc\",\"event\":{\"type\":\"part.text.appended\",\"text\":\"hi\",\"seq\":4}}")
        guard case .event(let sid, let event) = frame else { Issue.record("not an event"); return }
        #expect(sid == "opencode:ses_abc")
        let obj = try #require(try JSONSerialization.jsonObject(with: event) as? [String: Any])
        #expect(obj["type"] as? String == "part.text.appended")
        #expect(obj["text"] as? String == "hi")
    }

    @Test("decodeFrame parses a `harnessEvent` frame; the HarnessEvent JSON round-trips (permission card channel)")
    func decodesHarnessEvent() throws {
        let frame = WorkOpenGUISupervisor.decodeFrame(
            "{\"type\":\"harnessEvent\",\"event\":{\"type\":\"permission.requested\",\"harnessId\":\"codex\",\"request\":{\"id\":\"perm_1\",\"harnessId\":\"codex\",\"sessionID\":\"ses_x\",\"permission\":\"bash\",\"patterns\":[\"ls\"]}}}")
        guard case .harnessEvent(let event) = frame else { Issue.record("not a harnessEvent"); return }
        let obj = try #require(try JSONSerialization.jsonObject(with: event) as? [String: Any])
        #expect(obj["type"] as? String == "permission.requested")
        // the forwarded HarnessEvent decodes into a native permission request (the routeHarnessEvent path)
        let request = try #require(WorkPermissionRequestDecoder.decode(any: obj))
        #expect(request.id == "perm_1")
        #expect(request.harnessID == "codex")
        #expect(request.permission == "bash")
    }

    @Test("sidecar stamps harness events with their source harnessId before forwarding")
    func sidecarStampsHarnessEvents() throws {
        let sidecar = try loadMirroredSourceTextFile(".research-clones/work/opengui/og-sidecar.mjs")
        #expect(sidecar.contains("const forwarded = { ...ev, harnessId: hid }"))
        #expect(sidecar.contains("forwarded.request = { ...ev.request, harnessId: hid }"))
        #expect(sidecar.contains(#"out({ type: "harnessEvent", event: forwarded })"#))
    }

    @Test("decodeFrame returns nil for blank / non-JSON / unknown-type lines (sidecar diagnostics go to stderr)")
    func decodeRejectsNoise() {
        #expect(WorkOpenGUISupervisor.decodeFrame("") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("   ") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("[og-sidecar] ready") == nil) // stderr-style diagnostic
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"unknown\"}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("not json") == nil)
    }

    @Test("decodeFrame rejects unrouteable sidecar frames instead of inventing blank ids")
    func decodeRejectsUnrouteableFrames() {
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"reply\",\"ok\":true,\"data\":{}}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"reply\",\"id\":\"  \",\"ok\":true,\"data\":{}}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"event\",\"event\":{\"type\":\"part.text.appended\"}}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"event\",\"sessionId\":\"\",\"event\":{\"type\":\"part.text.appended\"}}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"event\",\"sessionId\":\"opencode:ses_1\"}") == nil)
        #expect(WorkOpenGUISupervisor.decodeFrame("{\"type\":\"harnessEvent\"}") == nil)
    }

    @Test("messages limit is omitted when invalid and capped before crossing the sidecar boundary")
    func messagesLimitBounds() {
        #expect(WorkOpenGUISupervisor.sanitizedMessagesLimit(nil) == nil)
        #expect(WorkOpenGUISupervisor.sanitizedMessagesLimit(0) == nil)
        #expect(WorkOpenGUISupervisor.sanitizedMessagesLimit(-1) == nil)
        #expect(WorkOpenGUISupervisor.sanitizedMessagesLimit(25) == 25)
        #expect(WorkOpenGUISupervisor.sanitizedMessagesLimit(10_000) == 500)
    }

    @Test("requireOK surfaces ok:false sidecar replies as errors")
    func requireOKSurfacesFalseReplies() throws {
        try WorkOpenGUISupervisor.requireOK(WorkOGReply(ok: true, data: nil), command: "send")
        do {
            try WorkOpenGUISupervisor.requireOK(WorkOGReply(ok: false, data: nil), command: "send")
            Issue.record("expected ok:false to throw")
        } catch WorkOGError.sidecar(let message) {
            #expect(message == "send returned ok=false")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: env / round-trip

    @Test("processEnvironment prepends the bundled OpenCode runtime bin, Resources, and bun dir to PATH")
    func buildsEnv() throws {
        let resources = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkOpenGUIResources-\(UUID().uuidString)", isDirectory: true)
        let runtimeBin = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeBin, withIntermediateDirectories: true)
        let runtime = runtimeBin.appendingPathComponent("opencode")
        try Data("#!/bin/sh\n".utf8).write(to: runtime)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtime.path)
        defer { try? FileManager.default.removeItem(at: resources) }

        let env = WorkOpenGUISupervisor.processEnvironment(
            bunDir: URL(fileURLWithPath: "/opt/x/bin"), base: ["PATH": "/usr/bin"],
            resourcesOverride: resources)
        let path = try #require(env["PATH"])
        let entries = path.split(separator: ":").map(String.init)
        let runtimeIdx = try #require(entries.firstIndex(of: runtimeBin.path))
        let resourcesIdx = try #require(entries.firstIndex(of: resources.path))
        let bunIdx = try #require(entries.firstIndex(of: "/opt/x/bin"))
        let usrIdx = try #require(entries.firstIndex(of: "/usr/bin"))
        #expect(runtimeIdx < resourcesIdx)
        #expect(resourcesIdx < bunIdx)
        #expect(bunIdx < usrIdx) // our dirs win over the inherited PATH
    }

    @Test("resolveBundledBun finds bun next to the structured bundled OpenCode runtime")
    func resolvesStructuredBundledBun() throws {
        let resources = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkOpenGUIBun-\(UUID().uuidString)", isDirectory: true)
        let runtimeBin = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeBin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: resources) }
        for name in ["opencode", "bun"] {
            let file = runtimeBin.appendingPathComponent(name)
            try Data("#!/bin/sh\n".utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }

        #expect(WorkOpenGUISupervisor.resolveBundledBun(inResources: resources) == runtimeBin.appendingPathComponent("bun"))
    }

    // Audit #8/#9 regression guard: a UNIQUE per-launch opencode port makes the sidecar's reapOpencode spawn-scoped
    // (the sidecar reads OPENGUI_OPENCODE_PORT on BOTH the bridge bind and the reap pkill). Omitted → sidecar default 4096.
    @Test("processEnvironment sets OPENGUI_OPENCODE_PORT when a port is given; omits it (→ sidecar default) when nil")
    func buildsEnvPort() throws {
        let withPort = WorkOpenGUISupervisor.processEnvironment(
            bunDir: URL(fileURLWithPath: "/opt/x/bin"), opencodePort: 53117, base: ["PATH": "/usr/bin"])
        #expect(withPort["OPENGUI_OPENCODE_PORT"] == "53117")
        let noPort = WorkOpenGUISupervisor.processEnvironment(
            bunDir: URL(fileURLWithPath: "/opt/x/bin"), base: ["PATH": "/usr/bin"])
        #expect(noPort["OPENGUI_OPENCODE_PORT"] == nil)
        let invalid = WorkOpenGUISupervisor.processEnvironment(
            bunDir: URL(fileURLWithPath: "/opt/x/bin"), opencodePort: 70000, base: ["PATH": "/usr/bin"])
        #expect(invalid["OPENGUI_OPENCODE_PORT"] == nil)
        let privileged = WorkOpenGUISupervisor.processEnvironment(
            bunDir: URL(fileURLWithPath: "/opt/x/bin"), opencodePort: 80, base: ["PATH": "/usr/bin"])
        #expect(privileged["OPENGUI_OPENCODE_PORT"] == nil)
        #expect(WorkOpenGUISupervisor.isValidManagedOpencodePort(1025))
        #expect(!WorkOpenGUISupervisor.isValidManagedOpencodePort(1024))
        #expect(!WorkOpenGUISupervisor.isValidManagedOpencodePort(65536))
    }

    @Test("freeTCPPort returns a usable loopback port (or nil), never a bogus/privileged value")
    func freePort() {
        if let p = WorkOpenGUISupervisor.freeTCPPort() {
            #expect(p > 1024 && p <= 65535)   // OS-assigned ephemeral port, never 0 / privileged
        }   // nil is an acceptable failure mode (caller falls back to the sidecar default 4096)
    }

    // MARK: Epistemos app-tool rooting

    @Test("OpenGUI provisioning roots native app tools at the active Epistemos vault, not the managed work cwd")
    func nativeToolRootPrefersEpistemosVault() {
        let workspace = URL(fileURLWithPath: "/tmp/epistemos-work-opengui", isDirectory: true)
        let vault = URL(fileURLWithPath: "/Users/example/EpistemosVault", isDirectory: true)
        #expect(WorkOpenGUIProvisioner.nativeToolRoot(workspace: workspace, epistemosVaultRoot: vault) == vault)
    }

    @Test("OpenGUI provisioning falls back to the managed work cwd only when no Epistemos vault is available")
    func nativeToolRootFallsBackToWorkspace() {
        let workspace = URL(fileURLWithPath: "/tmp/epistemos-work-opengui", isDirectory: true)
        #expect(WorkOpenGUIProvisioner.nativeToolRoot(workspace: workspace, epistemosVaultRoot: nil) == workspace)
    }

    @Test("OpenWork WebView preview also prefers the active Epistemos vault for native app tools")
    func webSurfaceToolWorkspacePrefersEpistemosVault() {
        let vault = URL(fileURLWithPath: "/Users/example/EpistemosVault", isDirectory: true)
        #expect(WorkWebSurfaceView.toolWorkspace(epistemosVaultRoot: vault) == vault)
    }

    @Test("OpenGUI native MCP config merge preserves existing workspace config")
    func openGUINativeMCPMergePreservesExistingConfig() throws {
        let existing = """
        {
          "$schema": "https://opencode.ai/config.json",
          "mcp": {
            "playwright": { "type": "local", "command": ["npx", "@playwright/mcp"], "enabled": true }
          },
          "theme": "opencode"
        }
        """
        let json = try #require(WorkOpenGUIProvisioner.mergedNativeMCPConfigJSON(
            existingJSON: existing,
            registration: WorkNativeMCPRegistration(url: "http://127.0.0.1:5511/mcp", token: "tok")))
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let mcp = try #require(obj["mcp"] as? [String: Any])
        let native = try #require(mcp["epistemos-native"] as? [String: Any])

        #expect(obj["theme"] as? String == "opencode")
        #expect(mcp["playwright"] != nil)
        #expect(native["type"] as? String == "remote")
        #expect(native["url"] as? String == "http://127.0.0.1:5511/mcp")
        #expect((native["headers"] as? [String: String])?["Authorization"] == "Bearer tok")
        #expect(native["enabled"] as? Bool == true)
    }

    @Test("OpenGUI native MCP config merge only accepts user-space loopback /mcp registrations with a bearer")
    func openGUINativeMCPMergeRejectsUnsafeRegistrations() throws {
        #expect(WorkOpenGUIProvisioner.isValidNativeMCPRegistration(
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5511/mcp", token: "tok")))
        #expect(WorkOpenGUIProvisioner.isValidNativeMCPRegistration(
            WorkNativeMCPRegistration(url: "http://localhost:5511/mcp", token: "tok")))
        #expect(WorkOpenGUIProvisioner.isValidNativeMCPRegistration(
            WorkNativeMCPRegistration(url: "http://[::1]:5511/mcp", token: "tok")))

        for bad in [
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5511/mcp", token: "  "),
            WorkNativeMCPRegistration(url: "https://127.0.0.1:5511/mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5511/not-mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1.evil.example:5511/mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://example.com:5511/mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1/mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:0/mcp", token: "tok"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:80/mcp", token: "tok"),
        ] {
            #expect(!WorkOpenGUIProvisioner.isValidNativeMCPRegistration(bad))
            #expect(WorkOpenGUIProvisioner.mergedNativeMCPConfigJSON(existingJSON: nil, registration: bad) == nil)
        }
    }

    @Test("round-trip: a command Swift encodes is what the sidecar reads back (init harnesses survive)")
    func roundTrips() throws {
        let line = try WorkOpenGUISupervisor.encodeCommand(
            id: "r9", cmd: "sessions.create", args: ["title": "t", "harnessId": "codex"])
        // The sidecar JSON.parse(line) sees exactly these fields:
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        #expect(obj["cmd"] as? String == "sessions.create")
        #expect(obj["harnessId"] as? String == "codex") // the picker's chosen engine survives the wire
    }

    @Test("OpenGUI sidecar keeps the full Work command surface wired and the command queue recoverable")
    func sidecarCommandSurfaceGuard() throws {
        let sidecar = try loadMirroredSourceTextFile(".research-clones/work/opengui/og-sidecar.mjs")
        let supervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUISupervisor.swift")

        for required in [
            #"case "init":"#,
            #"case "diagnose":"#,
            #"case "connect":"#,
            #"case "sessions.list":"#,
            #"case "sessions.create":"#,
            #"case "sessions.open":"#,
            #"case "send":"#,
            #"case "waitIdle":"#,
            #"case "abort":"#,
            #"case "respondPermission":"#,
            #"case "respondQuestion":"#,
            #"case "rejectQuestion":"#,
            #"case "messages":"#,
            #"case "loadResources":"#,
            #"case "close":"#,
        ] {
            #expect(sidecar.contains(required))
        }

        for required in [
            #"request("init""#,
            #"request("diagnose""#,
            #"request("connect""#,
            #"request("sessions.list""#,
            #"request("sessions.create""#,
            #"request("sessions.open""#,
            #"request("send""#,
            #"request("waitIdle""#,
            #"request("abort""#,
            #"request("respondPermission""#,
            #"request("respondQuestion""#,
            #"request("rejectQuestion""#,
            #"request("messages""#,
            #"request("loadResources""#,
        ] {
            #expect(supervisor.contains(required))
        }

        #expect(sidecar.contains("function queueFailure(e)"))
        #expect(sidecar.contains("commandQueue = commandQueue.then(() => handle(msg),"))
        #expect(sidecar.contains("return handle(msg);"))
        #expect(supervisor.contains(#"Self.nonEmptyString(obj["sessionID"])"#))
        #expect(supervisor.contains(#"Self.nonEmptyString(obj["sessionId"])"#))
        for command in [
            "send",
            "waitIdle",
            "abort",
            "respondPermission",
            "respondQuestion",
            "rejectQuestion",
            "diagnose",
            "sessions.list",
            "messages",
        ] {
            #expect(supervisor.contains(#"try Self.requireOK(reply, command: "\#(command)")"#))
        }
    }

    @Test("OpenGUI supervisor fails ready and pending requests immediately on sidecar EOF")
    func supervisorEOFDoesNotLeaveRequestsWaitingForTimeout() throws {
        let supervisor = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUISupervisor.swift")

        #expect(supervisor.contains("private func failAllPending(_ error: Error)"))
        #expect(supervisor.contains(#"failReady(error)"#))
        #expect(supervisor.contains(#"failAllPending(error)"#))
        #expect(supervisor.contains(#"failAllPending(WorkOGError.sidecar("Epistemos Work runtime exited."))"#))
        #expect(supervisor.contains("WorkServerDiagnostics.statusMessage("))
        #expect(!supervisor.contains("error.localizedDescription"))
        #expect(!supervisor.contains("String(describing: error)"))
    }

    @Test("OpenGUI sidecar/probe keeps the no-model open + messages endpoint proof")
    func sidecarOpenMessagesProbeGuard() throws {
        let sidecar = try loadMirroredSourceTextFile(".research-clones/work/opengui/og-sidecar.mjs")
        let probe = try loadMirroredSourceTextFile(".research-clones/work/opengui/og-open-messages-probe.mjs")

        for required in [
            #"case "sessions.open":"#,
            "await h.sessions.open(msg.sessionId)",
            #"case "messages":"#,
            "await entry.session.messages({ limit: msg.limit, before: msg.before })",
        ] {
            #expect(sidecar.contains(required))
        }

        for required in [
            #"cmd: "sessions.open""#,
            #"cmd: "messages""#,
            "openedId !== createdId",
            "messages !== undefined && messages !== null",
            "OPENGUI_OPENCODE_PORT",
        ] {
            #expect(probe.contains(required))
        }
    }

    @Test("OpenGUI sidecar has a no-model probe proving command errors do not poison later commands")
    func sidecarErrorRecoveryProbeGuard() throws {
        let probe = try loadMirroredSourceTextFile(".research-clones/work/opengui/og-error-recovery-probe.mjs")

        for required in [
            #"cmd: "sessions.list", harnessId: "missing-engine""#,
            #"harness not connected: missing-engine"#,
            #"cmd: "sessions.list", harnessId: "opencode""#,
            "valid command ran after sidecar error",
            "OPENGUI_OPENCODE_PORT",
        ] {
            #expect(probe.contains(required))
        }
    }
}
