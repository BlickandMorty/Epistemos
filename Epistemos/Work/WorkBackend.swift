import Foundation

// WORK backend seam. Pro-only (`#if !EPISTEMOS_APP_STORE`) because repo execution,
// git lifecycle, and terminal automation are outside the MAS sandbox. The default
// backend is inert until a real secondary runtime is wired behind the no-hidden-
// fallback bar. REAL APIs ONLY — nothing here claims a capability it doesn't have.
#if !EPISTEMOS_APP_STORE

/// A capability the Work backend can provide once a real secondary runtime is wired.
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

/// The seam Work mode drives against the secondary backend.
protocol WorkBackend: Sendable {
    /// True only when a real secondary backend is wired AND live. Honest gate — never
    /// reports live for the inert seam.
    var isLive: Bool { get }
    /// The capabilities this backend GENUINELY provides (empty for the inert seam —
    /// never fakes secondary-backend capability).
    var capabilities: [WorkCapability] { get }
    /// Run a Work session (a repo task) against the secondary backend. Throws an HONEST
    /// `WorkBackendError` when no engine is wired — never a silent fallback.
    func runWorkSession(objective: String, workspace: URL) async throws -> String
}

/// INERT default — the seam exists + compiles, is not live, claims no capabilities,
/// and HONESTLY refuses to run.
struct InertWorkBackend: WorkBackend {
    var isLive: Bool { false }
    var capabilities: [WorkCapability] { [] }
    func runWorkSession(objective: String, workspace: URL) async throws -> String {
        throw WorkBackendError.engineNotWired
    }
}

/// The future real conformer's growth point. Today it delegates to the inert stub
/// so the type exists end-to-end WITHOUT claiming an engine it doesn't have.
struct DeferredWorkBackend: WorkBackend {
    private let backing = InertWorkBackend()
    var isLive: Bool { false }
    var capabilities: [WorkCapability] { backing.capabilities }
    func runWorkSession(objective: String, workspace: URL) async throws -> String {
        try await backing.runWorkSession(objective: objective, workspace: workspace)
    }
}

/// Resolves the Work backend for the current flag — honest, never a hidden route.
/// Armed only when the flag is on; even then inert until a real backend lands.
enum WorkBackendFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> WorkBackend {
        WorkBackendGateStatus.isEnabled(environment[WorkBackendGateStatus.flagName])
            ? DeferredWorkBackend()
            : InertWorkBackend()
    }
}

#endif
