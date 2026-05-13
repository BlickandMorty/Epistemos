import Foundation
import OSLog

// MARK: - N1 — PromptTreePersister
//
// Serializes a typed `Prompt` to / from the on-disk PTF (Prompt Tree
// Format) layout at:
//
//   <vault>/.epistemos/prompts/<sessionID>/<turnIndex>/
//     ├── manifest.json       (Prompt envelope: version + id + cacheHints)
//     ├── identity.json       (IdentitySection if present)
//     ├── tools.json          ([ToolSpec])
//     ├── memory.json         (MemorySection if present)
//     ├── task.json           (TaskSection)
//     ├── constraints.json    ([ConstraintSection])
//     └── output_schema.json  (OutputSchema if present)
//
// PTF makes every prompt audit-able from Finder. Users + audit agents
// can inspect exact shape on disk; round-trip parse confirms PromptTree
// → PTF → Prompt produces an identical Prompt (verified by tests).
//
// GC policy: keep last N=20 turns per session. Older turns get pruned
// by NightBrain (or on-demand via `gcStaleTurns`). The active session's
// most recent turn is never pruned.
//
// **Privacy doctrine** (RCA9-P2-005 fix-pass 2026-05-13):
//   - PromptTree is OPT-IN. Default is `false`; persistence only
//     fires when `PromptTreePreferences.isEnabled()` returns true
//     (via UserDefaults toggle in Settings → Structured Surfaces,
//     or `EPISTEMOS_PROMPT_TREE=1` env var for CI).
//   - API keys are NEVER persisted here. Keys live in macOS Keychain
//     (`SecItemAdd` / `SecItemCopyMatching`) and are looked up at
//     HTTP-request time, NOT included in the `Prompt` struct that
//     PTF serializes. Verified by structural design: the `Prompt`
//     Codable type has no `apiKey` / `bearerToken` / `secret` fields.
//   - Attached user content (note text, vault snippets) IS persisted
//     by design — these are the prompt inputs the user already saw.
//     If your vault contains secrets (raw `sk-...` strings, etc.),
//     they will appear in PTF dumps via attached-note text.
//   - Recommended scan after enabling PTF on a sensitive vault:
//       find "$VAULT/.epistemos/prompts" -type f -maxdepth 5 -print
//       rg "sk-|xoxb-|Bearer |BEGIN PRIVATE KEY|API_KEY" \\
//          "$VAULT/.epistemos/prompts"
//   - Purge controls: GC policy = keep last 20 turns per session +
//     `gcStaleTurns` on-demand purge. To zero out completely:
//       rm -rf "$VAULT/.epistemos/prompts/"
//     The directory will be recreated on the next persisted turn.
//
// Doctrine refs:
//   - 01_DOCTRINE.md §6 #1 (no silent behavior — every prompt on disk)
//   - PLAN_V2.md §3.4 (capability honesty — auditable history)
//   - Audit register RCA9-P2-005 (this header is the fix-pass evidence)

public actor PromptTreePersister {

    public static let directoryName = ".epistemos/prompts"
    public static let recentTurnsKept = 20

    private let log = Logger(
        subsystem: "com.epistemos",
        category: "PromptTreePersister"
    )

    public static let shared = PromptTreePersister()

    private init() {}

    // MARK: - Persist

    /// Writes a Prompt as a PTF directory. Creates intermediate dirs
    /// as needed. Idempotent — re-persisting the same Prompt overwrites
    /// the existing files in-place.
    ///
    /// - Throws: filesystem errors only. Encoding errors are
    ///   programmer bugs (Codable conformance is total) so they
    ///   surface through `try` rather than swallowing.
    public func persist(
        _ prompt: Prompt,
        sessionID: String,
        turnIndex: Int,
        vaultRoot: URL
    ) throws {
        let dir = directory(
            sessionID: sessionID,
            turnIndex: turnIndex,
            vaultRoot: vaultRoot
        )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let manifest = PromptNode.Manifest(
            version: prompt.version,
            id: prompt.id,
            cacheHints: prompt.cacheHints
        )
        try writeJSON(manifest, to: dir.appendingPathComponent(PromptNode.Filename.manifest.rawValue), encoder: encoder)

        if let identity = prompt.identity {
            try writeJSON(identity, to: dir.appendingPathComponent(PromptNode.Filename.identity.rawValue), encoder: encoder)
        }
        try writeJSON(prompt.tools, to: dir.appendingPathComponent(PromptNode.Filename.tools.rawValue), encoder: encoder)
        if let memory = prompt.memory {
            try writeJSON(memory, to: dir.appendingPathComponent(PromptNode.Filename.memory.rawValue), encoder: encoder)
        }
        try writeJSON(prompt.task, to: dir.appendingPathComponent(PromptNode.Filename.task.rawValue), encoder: encoder)
        try writeJSON(prompt.constraints, to: dir.appendingPathComponent(PromptNode.Filename.constraints.rawValue), encoder: encoder)
        if let schema = prompt.outputSchema {
            try writeJSON(schema, to: dir.appendingPathComponent(PromptNode.Filename.outputSchema.rawValue), encoder: encoder)
        }

        log.info(
            "PTF persisted session=\(sessionID, privacy: .public) turn=\(turnIndex, privacy: .public) at=\(dir.path, privacy: .public)"
        )
    }

    // MARK: - Load

    /// Reads a PTF directory back into a Prompt. Returns nil if the
    /// directory doesn't exist or the manifest is missing — both are
    /// expected when querying for a turn that wasn't persisted.
    /// Throws on corrupted JSON (programmer-detectable bug).
    public func load(
        sessionID: String,
        turnIndex: Int,
        vaultRoot: URL
    ) throws -> Prompt? {
        let dir = directory(
            sessionID: sessionID,
            turnIndex: turnIndex,
            vaultRoot: vaultRoot
        )

        let manifestURL = dir.appendingPathComponent(PromptNode.Filename.manifest.rawValue)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest: PromptNode.Manifest = try readJSON(at: manifestURL, decoder: decoder)

        let identity: IdentitySection? = try readJSONOptional(at: dir.appendingPathComponent(PromptNode.Filename.identity.rawValue), decoder: decoder)
        let tools: [ToolSpec] = try readJSONOptional(at: dir.appendingPathComponent(PromptNode.Filename.tools.rawValue), decoder: decoder) ?? []
        let memory: MemorySection? = try readJSONOptional(at: dir.appendingPathComponent(PromptNode.Filename.memory.rawValue), decoder: decoder)
        let task: TaskSection = try readJSON(at: dir.appendingPathComponent(PromptNode.Filename.task.rawValue), decoder: decoder)
        let constraints: [ConstraintSection] = try readJSONOptional(at: dir.appendingPathComponent(PromptNode.Filename.constraints.rawValue), decoder: decoder) ?? []
        let outputSchema: OutputSchema? = try readJSONOptional(at: dir.appendingPathComponent(PromptNode.Filename.outputSchema.rawValue), decoder: decoder)

        return Prompt(
            version: manifest.version,
            id: manifest.id,
            identity: identity,
            tools: tools,
            memory: memory,
            task: task,
            constraints: constraints,
            outputSchema: outputSchema,
            cacheHints: manifest.cacheHints
        )
    }

    // MARK: - GC

    /// Prune turns older than `recentTurnsKept`. Returns the number of
    /// directories deleted. Does NOT delete the session directory
    /// itself even when empty — the session may still be active.
    @discardableResult
    public func gcStaleTurns(
        sessionID: String,
        vaultRoot: URL,
        keep: Int = recentTurnsKept
    ) throws -> Int {
        let sessionDir = vaultRoot
            .appendingPathComponent(Self.directoryName)
            .appendingPathComponent(sessionID)
        guard FileManager.default.fileExists(atPath: sessionDir.path) else { return 0 }

        let entries = try FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        // Turn dirs are named with the integer turn index — keep the
        // top-K by numeric value, prune the rest.
        let turnDirs: [(Int, URL)] = entries.compactMap { url in
            guard
                let last = url.pathComponents.last,
                let turn = Int(last)
            else { return nil }
            return (turn, url)
        }
        guard turnDirs.count > keep else { return 0 }

        let sorted = turnDirs.sorted { $0.0 > $1.0 }  // newest first
        let toPrune = sorted.dropFirst(keep)

        var deleted = 0
        for (_, url) in toPrune {
            do {
                try FileManager.default.removeItem(at: url)
                deleted += 1
            } catch {
                log.warning(
                    "PTF gc: failed to delete \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        log.info(
            "PTF gc: session=\(sessionID, privacy: .public) deleted=\(deleted, privacy: .public) kept=\(keep, privacy: .public)"
        )
        return deleted
    }

    // MARK: - Helpers

    nonisolated public func directory(
        sessionID: String,
        turnIndex: Int,
        vaultRoot: URL
    ) -> URL {
        vaultRoot
            .appendingPathComponent(Self.directoryName)
            .appendingPathComponent(sessionID)
            .appendingPathComponent(String(turnIndex))
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL, encoder: JSONEncoder) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func readJSON<T: Decodable>(at url: URL, decoder: JSONDecoder) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func readJSONOptional<T: Decodable>(at url: URL, decoder: JSONDecoder) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try readJSON(at: url, decoder: decoder)
    }
}
