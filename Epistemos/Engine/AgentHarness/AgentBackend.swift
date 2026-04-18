import Foundation

/// Options carried into every AgentBackend.execute call. Mirrors Multica's
/// ExecOptions 1:1 so we can swap backends without per-option shims.
nonisolated struct AgentExecOptions: Codable, Sendable {
    /// Working directory the backend should treat as "project root" — where
    /// it writes runtime-config files and resolves relative paths.
    var cwd: String
    var model: String?
    var systemPrompt: String?
    var maxTurns: Int?
    var timeoutSeconds: Double?
    var resumeSessionID: String?
    var customArgs: [String]
    var mcpConfigJSON: Data?

    init(
        cwd: String,
        model: String? = nil,
        systemPrompt: String? = nil,
        maxTurns: Int? = nil,
        timeoutSeconds: Double? = nil,
        resumeSessionID: String? = nil,
        customArgs: [String] = [],
        mcpConfigJSON: Data? = nil
    ) {
        self.cwd = cwd
        self.model = model
        self.systemPrompt = systemPrompt
        self.maxTurns = maxTurns
        self.timeoutSeconds = timeoutSeconds
        self.resumeSessionID = resumeSessionID
        self.customArgs = customArgs
        self.mcpConfigJSON = mcpConfigJSON
    }
}

/// Event shape streamed by any AgentBackend. Kept deliberately narrow so the
/// backend contract stays provider-agnostic — richer per-provider delegate
/// callbacks (StreamingDelegate) are one layer up.
nonisolated enum AgentBackendEvent: Sendable {
    case text(String)
    case thinking(String)
    case toolUse(id: String, name: String, input: Data)
    case toolResult(id: String, output: String, isError: Bool)
    case usage(model: String, usage: TokenUsage)
    case status(String)
    case log(String)
    case error(String)
    case complete(sessionID: String?, stopReason: String?)
}

/// Provider-agnostic backend contract. Each concrete implementation (cloud
/// Claude over URLSession, local MLX, a CLI subprocess, a future Rust daemon
/// worker) conforms to this and streams AgentBackendEvent back to the caller.
nonisolated protocol AgentBackend: Sendable {
    /// Stable string identifier used to look up this backend in BackendRegistry.
    var identifier: String { get }

    /// A one-line human-facing description for settings surfaces.
    var displayName: String { get }

    /// Entry point. The returned stream must:
    /// - emit incremental events as they happen (no pre-buffering)
    /// - emit exactly one `.complete(...)` terminal event
    /// - fail-fast on unrecoverable errors with `.error(...)` followed by
    ///   `.complete(...)`
    func execute(
        prompt: String,
        history: [String],
        options: AgentExecOptions
    ) async throws -> AsyncThrowingStream<AgentBackendEvent, Error>
}

/// Registry of available backends. Backends register themselves at boot so a
/// caller can resolve by identifier (e.g., "claude", "gpt5", "qwen-local",
/// "codex-cli") without the dispatcher knowing provider specifics.
@MainActor
final class BackendRegistry {
    static let shared = BackendRegistry()

    private var backends: [String: any AgentBackend] = [:]

    func register(_ backend: any AgentBackend) {
        backends[backend.identifier] = backend
    }

    func resolve(_ identifier: String) -> (any AgentBackend)? {
        backends[identifier]
    }

    func allIdentifiers() -> [String] {
        Array(backends.keys).sorted()
    }
}

/// Writes the runtime-config file that CLI-style agent backends read on
/// entry (CLAUDE.md / AGENTS.md / GEMINI.md). Ported from Multica's
/// InjectRuntimeConfig — the cleanest way to teach external agent processes
/// our harness conventions without stuffing 2K tokens into every system
/// prompt.
nonisolated enum RuntimeBootstrapWriter {
    /// Maps a backend identifier to the canonical runtime-config filename
    /// that backend reads on entry. AGENTS.md is the fallback for anything
    /// that isn't Claude or Gemini, matching the convention used by Codex,
    /// OpenCode, OpenClaw, and the broader open-agent ecosystem.
    nonisolated enum TargetFile {
        static func fileName(forBackendID identifier: String) -> String {
            switch identifier.lowercased() {
            case "claude", "anthropic", "claude-code", "openclaw":
                return "CLAUDE.md"
            case "gemini", "gemini-cli":
                return "GEMINI.md"
            default:
                return "AGENTS.md"
            }
        }
    }

    /// Writes a runtime-config file into `workDir` for the backend identified
    /// by `backendID`. Existing files are overwritten only when
    /// `overwriteExisting` is true — defaulting to false preserves anything
    /// the user (or the upstream agent) already placed there.
    static func inject(
        workDir: URL,
        backendID: String,
        content: String,
        overwriteExisting: Bool = false
    ) throws {
        let fileName = TargetFile.fileName(forBackendID: backendID)
        let url = workDir.appendingPathComponent(fileName)

        if !overwriteExisting,
           FileManager.default.fileExists(atPath: url.path) {
            return
        }

        try content.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
