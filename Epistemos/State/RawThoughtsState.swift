import Foundation
import OSLog

// MARK: - RawThoughtsState
// Patch 5 / USER_WIRING_GAPS G2 — Swift consumer of the per-run Raw Thoughts
// artifact folders emitted by `agent_core/src/storage/raw_thoughts.rs`.
//
// Folder layout (mirrors the Rust emitter):
//   <vault_root>/Raw Thoughts/<provider>/<YYYY-MM-DD>_<short-run-id>/
//     manifest.json   — required
//     events.jsonl    — required
//     summary.md      — optional
//     links.json      — optional
//
// Reads happen on a detached utility task; only the published `runs` array
// is mutated on the MainActor. Hidden behind the `EPISTEMOS_RAW_THOUGHTS_V0`
// environment flag (matches the Rust emitter's flag).

@MainActor
@Observable
final class RawThoughtsState {

    // MARK: - Types

    /// Sidebar / inspector summary of one Raw Thoughts run. Decoded from the
    /// run folder's `manifest.json`; the folder URL is preserved so the
    /// inspector can stream `events.jsonl` and optionally render `summary.md`.
    struct RunSummary: Identifiable, Hashable, Sendable {
        let id: String      // run_id
        let provider: String
        let model: String
        let startedAt: Date
        let endedAt: Date?
        let status: String  // "running" / "completed" / "errored" / "cancelled"
        let folderURL: URL
    }

    // MARK: - Manifest decoder
    // Mirror of `RawThoughtsManifest` in raw_thoughts.rs. Timestamps are unix
    // milliseconds per the Rust emitter's wire format.
    nonisolated private struct DecodedManifest: Decodable, Sendable {
        let runId: String
        let promptId: String?
        let provider: String
        let model: String
        let startedAt: Int64
        let endedAt: Int64?
        let status: String

        enum CodingKeys: String, CodingKey {
            case runId = "run_id"
            case promptId = "prompt_id"
            case provider
            case model
            case startedAt = "started_at"
            case endedAt = "ended_at"
            case status
        }
    }

    // MARK: - Published state

    var runs: [RunSummary] = []

    /// Static mirror of the emission flag so a diagnostics surface can read the
    /// state WITHOUT the @Observable instance (no @Environment dependency, so it
    /// can live in Settings without a launch-crash risk).
    nonisolated static var isEmissionEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_RAW_THOUGHTS_V0"] == "1"
    }

    /// True when the user has opted into Raw Thoughts V0 emission this process.
    /// Mirrors the Rust emitter's flag; the per-vault sidebar surface hides
    /// entirely when false (canon), so the Settings diagnostics row is the
    /// honest, discoverable answer to "is this still a thing?".
    var isEnabled: Bool { Self.isEmissionEnabled }

    /// SS-GE (owner 2026-06-21): an honest one-line status for the Settings
    /// diagnostics row. The owner "didn't see raw thoughts in the vault, wasn't
    /// sure it's still a thing" — because the per-vault surface is hidden when
    /// emission is off. This makes the feature discoverable (what it is, whether
    /// it's recording, how to turn it on, where to browse runs) without flipping
    /// the default-off emitter flag or adding a do-nothing toggle.
    nonisolated static func diagnosticStatus(isEnabled: Bool) -> String {
        isEnabled
            ? "On — recording each model run's raw thinking + tool calls into <vault>/Raw Thoughts/. Browse runs under a model vault row in the Notes sidebar."
            : "Off — set EPISTEMOS_RAW_THOUGHTS_V0=1 to record each model run's raw thinking + tool calls into <vault>/Raw Thoughts/, then browse them under a model vault row."
    }

    // MARK: - Internals

    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "RawThoughtsState")
    private var lastScannedRoot: URL?

    init() {}

    // MARK: - Refresh

    /// Re-scan `<vault_root>/Raw Thoughts/<provider>/<run-folder>/` and
    /// publish the result on `runs`. Off-MainActor file enumeration + JSON
    /// parse; only the final assignment touches @MainActor state.
    func refresh(vaultRoot: URL) async {
        guard isEnabled else {
            runs = []
            lastScannedRoot = vaultRoot
            return
        }
        let snapshot = await Task.detached(priority: .utility) {
            Self.scan(vaultRoot: vaultRoot)
        }.value
        runs = snapshot
        lastScannedRoot = vaultRoot
    }

    /// Folder URL for a given run id (looked up against the last-scanned cache).
    func runFolderURL(runId: String) -> URL? {
        runs.first(where: { $0.id == runId })?.folderURL
    }

    // MARK: - Off-MainActor scan

    nonisolated static func scan(vaultRoot: URL) -> [RunSummary] {
        let rawThoughtsRoot = vaultRoot.appendingPathComponent("Raw Thoughts", isDirectory: true)
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: rawThoughtsRoot.path, isDirectory: &isDir),
              isDir.boolValue else {
            return []
        }

        let providerKeys: [URLResourceKey] = [.isDirectoryKey]
        guard let providerEntries = try? fileManager.contentsOfDirectory(
            at: rawThoughtsRoot,
            includingPropertiesForKeys: providerKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var collected: [RunSummary] = []
        let decoder = JSONDecoder()

        for providerURL in providerEntries {
            let isProviderDir = (try? providerURL.resourceValues(forKeys: Set(providerKeys)).isDirectory) ?? false
            guard isProviderDir else { continue }

            guard let runEntries = try? fileManager.contentsOfDirectory(
                at: providerURL,
                includingPropertiesForKeys: providerKeys,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for runURL in runEntries {
                let isRunDir = (try? runURL.resourceValues(forKeys: Set(providerKeys)).isDirectory) ?? false
                guard isRunDir else { continue }

                let manifestURL = runURL.appendingPathComponent("manifest.json", isDirectory: false)
                guard let data = try? Data(contentsOf: manifestURL) else { continue }
                guard let manifest = try? decoder.decode(DecodedManifest.self, from: data) else {
                    log.warning("RawThoughtsState: malformed manifest at \(manifestURL.path, privacy: .public)")
                    continue
                }

                let summary = RunSummary(
                    id: manifest.runId,
                    provider: manifest.provider,
                    model: manifest.model,
                    startedAt: Date(timeIntervalSince1970: TimeInterval(manifest.startedAt) / 1000.0),
                    endedAt: manifest.endedAt.map {
                        Date(timeIntervalSince1970: TimeInterval($0) / 1000.0)
                    },
                    status: manifest.status,
                    folderURL: runURL
                )
                collected.append(summary)
            }
        }

        // Newest first — sidebar default sort.
        return collected.sorted { lhs, rhs in
            lhs.startedAt > rhs.startedAt
        }
    }

    /// Filter a snapshot of runs to a single provider (case-insensitive
    /// substring match against the manifest's `provider` field). Used by the
    /// sidebar to scope each model vault's row to its own runs.
    nonisolated static func runs(in runs: [RunSummary], matching providerHint: String) -> [RunSummary] {
        let needle = providerHint.lowercased()
        guard !needle.isEmpty else { return runs }
        return runs.filter { run in
            run.provider.lowercased().contains(needle)
                || run.model.lowercased().contains(needle)
        }
    }
}
