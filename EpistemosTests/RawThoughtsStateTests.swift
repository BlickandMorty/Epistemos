import Foundation
import Testing
@testable import Epistemos

@Suite("RawThoughtsState")
struct RawThoughtsStateTests {

    // MARK: - Helpers

    /// Returns the EPISTEMOS_RAW_THOUGHTS_V0 environment value at process
    /// start. The state class reads it on demand, so flipping this within a
    /// single test would be racy across the suite. We instead test the
    /// scan helper (which is `nonisolated` and ignores the flag), and rely on
    /// the live env value to gate `refresh(...)`'s short-circuit.
    private static var envFlagIsEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_RAW_THOUGHTS_V0"] == "1"
    }

    private static func makeFixtureRoot() throws -> URL {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("RawThoughtsStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func writeManifest(
        in runDir: URL,
        runId: String,
        provider: String,
        model: String,
        startedAtMs: Int64,
        endedAtMs: Int64?,
        status: String
    ) throws {
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        var manifest: [String: Any] = [
            "run_id": runId,
            "provider": provider,
            "model": model,
            "started_at": startedAtMs,
            "status": status,
        ]
        if let endedAtMs {
            manifest["ended_at"] = endedAtMs
        }
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: runDir.appendingPathComponent("manifest.json"))
        try Data().write(to: runDir.appendingPathComponent("events.jsonl"))
    }

    // MARK: - Scan tests

    @Test("scan returns 0 runs for empty vault root")
    func scanEmptyVault() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let runs = RawThoughtsState.scan(vaultRoot: root)
        #expect(runs.isEmpty)
    }

    @Test("scan returns 0 runs when Raw Thoughts dir is missing")
    func scanMissingRawThoughtsDir() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create some unrelated content in the vault.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Notes"),
            withIntermediateDirectories: true
        )
        let runs = RawThoughtsState.scan(vaultRoot: root)
        #expect(runs.isEmpty)
    }

    @Test("scan parses a single fixture manifest")
    func scanSingleManifest() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let runDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("anthropic")
            .appendingPathComponent("2026-04-25_run_abcdef")
        try Self.writeManifest(
            in: runDir,
            runId: "run_abcdef",
            provider: "anthropic",
            model: "claude-opus-4-7",
            startedAtMs: 1_745_600_000_000,
            endedAtMs: 1_745_600_010_000,
            status: "completed"
        )

        let runs = RawThoughtsState.scan(vaultRoot: root)
        #expect(runs.count == 1)
        let first = try #require(runs.first)
        #expect(first.id == "run_abcdef")
        #expect(first.provider == "anthropic")
        #expect(first.model == "claude-opus-4-7")
        #expect(first.status == "completed")
        #expect(first.endedAt != nil)
        // macOS symlinks /var -> /private/var; FileManager.contentsOfDirectory
        // returns the resolved /private/var path while our locally-built `runDir`
        // is the unresolved /var path. Compare canonical paths instead.
        #expect(first.folderURL.resolvingSymlinksInPath()
                == runDir.resolvingSymlinksInPath())
    }

    @Test("scan ignores malformed manifest")
    func scanIgnoresBadManifest() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let runDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("anthropic")
            .appendingPathComponent("2026-04-25_bad")
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: runDir.appendingPathComponent("manifest.json"))

        let runs = RawThoughtsState.scan(vaultRoot: root)
        #expect(runs.isEmpty)
    }

    @Test("scan sorts newest first across multiple runs")
    func scanSortsByNewestFirst() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let providerDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("openai")
        try Self.writeManifest(
            in: providerDir.appendingPathComponent("2026-04-24_run_old"),
            runId: "run_old",
            provider: "openai",
            model: "gpt-5.4",
            startedAtMs: 1_745_500_000_000,
            endedAtMs: nil,
            status: "completed"
        )
        try Self.writeManifest(
            in: providerDir.appendingPathComponent("2026-04-25_run_new"),
            runId: "run_new",
            provider: "openai",
            model: "gpt-5.4",
            startedAtMs: 1_745_600_000_000,
            endedAtMs: nil,
            status: "completed"
        )

        let runs = RawThoughtsState.scan(vaultRoot: root)
        #expect(runs.count == 2)
        #expect(runs.first?.id == "run_new")
        #expect(runs.last?.id == "run_old")
    }

    @Test("runs(in:matching:) scopes to provider hint")
    func providerHintFilters() {
        let now = Date()
        let folder = URL(fileURLWithPath: "/tmp/dummy")
        let runs: [RawThoughtsState.RunSummary] = [
            .init(id: "a", provider: "anthropic", model: "claude-opus-4-7",
                  startedAt: now, endedAt: nil, status: "completed", folderURL: folder),
            .init(id: "b", provider: "openai", model: "gpt-5.4",
                  startedAt: now, endedAt: nil, status: "completed", folderURL: folder),
        ]
        let scoped = RawThoughtsState.runs(in: runs, matching: "anthropic")
        #expect(scoped.count == 1)
        #expect(scoped.first?.id == "a")
    }

    @Test("runs(in:matching:) returns all when hint is empty")
    func providerHintEmptyReturnsAll() {
        let now = Date()
        let folder = URL(fileURLWithPath: "/tmp/dummy")
        let runs: [RawThoughtsState.RunSummary] = [
            .init(id: "a", provider: "anthropic", model: "claude-opus-4-7",
                  startedAt: now, endedAt: nil, status: "completed", folderURL: folder),
            .init(id: "b", provider: "openai", model: "gpt-5.4",
                  startedAt: now, endedAt: nil, status: "completed", folderURL: folder),
        ]
        let scoped = RawThoughtsState.runs(in: runs, matching: "")
        #expect(scoped.count == 2)
    }

    // MARK: - Refresh tests (require @MainActor)

    @MainActor
    @Test("refresh respects isEnabled flag — disabled clears runs without scanning")
    func refreshRespectsDisabledFlag() async throws {
        // We can only assert the disabled-path behavior reliably across
        // arbitrary CI environments. When the env flag IS set, we still
        // exercise the enabled path to verify the scan plumbing works.
        let state = RawThoughtsState()
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Even with a fixture present, when the flag is unset refresh must
        // assign an empty array and never error.
        let runDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("anthropic")
            .appendingPathComponent("2026-04-25_run_flag")
        try Self.writeManifest(
            in: runDir,
            runId: "run_flag",
            provider: "anthropic",
            model: "claude-opus-4-7",
            startedAtMs: 1_745_600_000_000,
            endedAtMs: nil,
            status: "completed"
        )

        await state.refresh(vaultRoot: root)
        if Self.envFlagIsEnabled {
            #expect(state.runs.count == 1)
            #expect(state.runFolderURL(runId: "run_flag") == runDir)
        } else {
            #expect(state.runs.isEmpty)
        }
    }

    // MARK: - Inspector artifact recovery

    @Test("inspector keeps valid JSONL lines when final line is partial")
    func inspectorKeepsValidLinesWithPartialFinalJSONL() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let runDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("anthropic")
            .appendingPathComponent("2026-04-25_run_partial")
        try Self.writeManifest(
            in: runDir,
            runId: "run_partial",
            provider: "anthropic",
            model: "claude-opus-4-7",
            startedAtMs: 1_745_600_000_000,
            endedAtMs: nil,
            status: "running"
        )
        let validText = #"{"type":"text_delta","index":0,"text":"ok"}"#
        let validTool = #"{"type":"tool_use","id":"tc_1","name":"search","input":{"query":"rust"}}"#
        let partial = #"{"type":"redacted_thinking","index":1,"data":"opaque"#
        try "\(validText)\n\(validTool)\n\(partial)".write(
            to: runDir.appendingPathComponent("events.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try "# Summary\nRecovered".write(
            to: runDir.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        let artifacts = RawThoughtsInspectorView.loadRunArtifacts(folderURL: runDir)
        #expect(artifacts.eventLines.count == 3)
        #expect(artifacts.eventLines[0] == validText)
        #expect(artifacts.eventLines[1] == validTool)
        #expect(artifacts.eventLines[2] == partial)
        #expect(artifacts.summaryMarkdown == "# Summary\nRecovered")
        #expect(artifacts.loadError == nil)
    }

    @Test("inspector caps high-rate event logs to a bounded tail window")
    func inspectorCapsHighRateEventLogTail() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let runDir = root
            .appendingPathComponent("Raw Thoughts")
            .appendingPathComponent("openai")
            .appendingPathComponent("2026-04-29_run_high_rate")
        try Self.writeManifest(
            in: runDir,
            runId: "run_high_rate",
            provider: "openai",
            model: "gpt-5.4",
            startedAtMs: 1_745_600_000_000,
            endedAtMs: nil,
            status: "running"
        )

        let lines = (0..<750).map { index in
            #"{"type":"token","index":\#(index),"text":"line-\#(index)"}"#
        }
        try lines.joined(separator: "\n").write(
            to: runDir.appendingPathComponent("events.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let artifacts = RawThoughtsInspectorView.loadRunArtifacts(folderURL: runDir)
        #expect(artifacts.eventLines.count == RawThoughtsInspectorView.maxVisibleEventLines)
        #expect(artifacts.eventLines.first == lines[250])
        #expect(artifacts.eventLines.last == lines[749])
        #expect(artifacts.loadError == nil)
    }

    @Test("event tail reader drops a partial first line when reading from middle")
    func eventTailReaderDropsPartialFirstLine() throws {
        let root = try Self.makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let eventsURL = root.appendingPathComponent("events.jsonl")
        let lines = (0..<20).map { index in
            "event-\(index)-abcdefghijklmnopqrstuvwxyz"
        }
        try lines.joined(separator: "\n").write(
            to: eventsURL,
            atomically: true,
            encoding: .utf8
        )

        let tail = try RawThoughtsInspectorView.loadEventTailLines(
            eventsURL: eventsURL,
            maxLines: 5,
            maxBytes: 80
        )

        #expect(tail.count <= 5)
        #expect(tail.last == lines.last)
        #expect(tail.allSatisfy { lines.contains($0) })
    }

    // MARK: - Graph type round-trip (per Patch 5 acceptance criterion)

    @Test("GraphNodeType raw values for Raw Thoughts cases round-trip via Codable")
    func graphNodeTypeRawThoughtsRoundTrip() throws {
        let cases: [GraphNodeType] = [.run, .rawThought, .toolTrace]
        for nodeType in cases {
            let encoded = try JSONEncoder().encode(nodeType)
            let decoded = try JSONDecoder().decode(GraphNodeType.self, from: encoded)
            #expect(decoded == nodeType)
        }
    }

    @Test("GraphEdgeType raw values for Raw Thoughts edges round-trip via Codable")
    func graphEdgeTypeRawThoughtsRoundTrip() throws {
        let cases: [GraphEdgeType] = [.producedDuring, .generatedBy, .derivedFrom, .summarizes]
        for edgeType in cases {
            let encoded = try JSONEncoder().encode(edgeType)
            let decoded = try JSONDecoder().decode(GraphEdgeType.self, from: encoded)
            #expect(decoded == edgeType)
        }
    }

    @Test("GraphNodeType.allCases excludes app-level cases (FFI contract preserved)")
    func graphNodeTypeAllCasesExcludesRawThoughts() {
        // FFI contract: allCases must remain exactly the 14 FFI-bridged types.
        // Raw Thoughts and typed cognitive-artifact cases are app-level only.
        #expect(GraphNodeType.allCases.count == 14)
        #expect(!GraphNodeType.allCases.contains(.run))
        #expect(!GraphNodeType.allCases.contains(.rawThought))
        #expect(!GraphNodeType.allCases.contains(.toolTrace))
        #expect(GraphNodeType.appLevelCases == [
            .run, .rawThought, .toolTrace,
            .proseNote, .document, .code, .output,
        ])
    }

    @Test("GraphEdgeType.allCases excludes Raw Thoughts edges (FFI contract preserved)")
    func graphEdgeTypeAllCasesExcludesRawThoughts() {
        #expect(GraphEdgeType.allCases.count == 12)
        #expect(!GraphEdgeType.allCases.contains(.producedDuring))
        #expect(!GraphEdgeType.allCases.contains(.generatedBy))
        #expect(!GraphEdgeType.allCases.contains(.derivedFrom))
        #expect(!GraphEdgeType.allCases.contains(.summarizes))
        #expect(GraphEdgeType.appLevelCases == [
            .producedDuring, .generatedBy, .derivedFrom, .summarizes,
        ])
    }

    @Test("Raw Thoughts node types have display names and icons")
    func rawThoughtsNodeTypesPresentation() {
        for type in GraphNodeType.appLevelCases {
            #expect(!type.displayName.isEmpty)
            #expect(!type.icon.isEmpty)
        }
    }
}
