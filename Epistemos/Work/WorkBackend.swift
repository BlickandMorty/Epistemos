import Foundation

// Goose=WORK seam (R-GOOSE). The interface WORK mode drives against the extracted
// Goose engine. Pro-only (`#if !EPISTEMOS_APP_STORE`) — the Goose engine (code
// execution, git, subagents) is outside the MAS sandbox. The INERT stub is the
// default until the Goose Rust core is vendored (block/goose, Apache-2.0, into
// agent_core via UniFFI) and wired behind the no-hidden-fallback bar. REAL APIs
// ONLY — nothing here claims a capability it doesn't have. GOOSE GUARDRAIL: this
// seam is ISOLATED — it touches NOTHING in the Chat (Epistemos) / Act (Osaurus) path.
#if !EPISTEMOS_APP_STORE

/// A capability the Goose Work engine provides (the R-GOOSE engine pieces).
enum WorkCapability: String, CaseIterable, Sendable, Equatable {
    case repoIndexing
    case gitLifecycle
    case multiFileDiff
    case testAndFixLoop
    case parallelSubagents
    case yamlRecipes
}

/// Honest errors for a Work session — no engine is wired, or the run failed. The
/// caller surfaces these; it NEVER silently falls back to the Chat/Act engine.
enum WorkBackendError: Error, Equatable {
    case engineNotWired
    case runFailed(String)
}

/// The seam Work mode drives against the Goose engine.
protocol WorkBackend: Sendable {
    /// True only when a real Goose engine is wired AND live. Honest gate — never
    /// reports live for the inert seam.
    var isLive: Bool { get }
    /// The capabilities this backend GENUINELY provides (empty for the inert seam —
    /// never fakes Goose capability).
    var capabilities: [WorkCapability] { get }
    /// Run a Work session (a repo task) against the Goose engine. Throws an HONEST
    /// `WorkBackendError` when no engine is wired — never a silent fallback.
    func runWorkSession(objective: String, workspace: URL) async throws -> String
}

/// INERT default — the seam exists + compiles, is not live, claims no capabilities,
/// and HONESTLY refuses to run. The state until the Goose Rust core is vendored.
struct InertWorkBackend: WorkBackend {
    var isLive: Bool { false }
    var capabilities: [WorkCapability] { [] }
    func runWorkSession(objective: String, workspace: URL) async throws -> String {
        throw WorkBackendError.engineNotWired
    }
}

/// The real conformer's growth point (vendor block/goose → agent_core → UniFFI →
/// here). Today it delegates to the inert stub so the type exists end-to-end WITHOUT
/// claiming an engine it doesn't have. When the Goose core lands, this drives it.
struct GooseWorkBackend: WorkBackend {
    private let backing = InertWorkBackend()
    var isLive: Bool { false }
    var capabilities: [WorkCapability] { backing.capabilities }
    func runWorkSession(objective: String, workspace: URL) async throws -> String {
        try await backing.runWorkSession(objective: objective, workspace: workspace)
    }
}

/// Resolves the Work backend for the current flag — honest, never a hidden route.
/// Armed only when the flag is on; even then inert until the Goose core lands.
enum WorkBackendFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> WorkBackend {
        WorkBackendGateStatus.isEnabled(environment[WorkBackendGateStatus.flagName])
            ? GooseWorkBackend()
            : InertWorkBackend()
    }
}

#endif
