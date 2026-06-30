import Foundation

// DeerFlow slice 5d — the Swift seam that drives the NATIVE multi-agent
// deep-research run (agent_core `deep_research`: planner → parallel isolated
// sub-agents → [id]-cited synthesis) over the UniFFI `run_deep_research_session`
// export. No Python sidecar — the orchestration is native Rust.
//
// The `runDeepResearchSession` FFI symbol is compiled ONLY into the pro-build of
// agent_core (the Rust fn is `#[cfg(feature = "pro-build")]`; build-agent-core.sh
// selects mas-build for the App Store target, pro-build otherwise), so this whole
// surface is gated by `!EPISTEMOS_APP_STORE` to mirror that cargo split — exactly
// like `LocalGgufRuntimeBridge`.
//
// Two honest gates, BOTH required before a run can happen:
//   1. `EPISTEMOS_DEEP_RESEARCH_V0` (the SAME flag the Rust
//      `deep_research_enabled()` reads, surfaced by `DeepResearchGateStatus`) —
//      OFF by default → callers stay on the normal single-agent path.
//   2. a recognized CLOUD provider (`DeepResearchGateStatus.isCloudProvider`) —
//      deep research's sub-agents are tool/web users (a cloud capability), and
//      the explicit allowlist means it can NEVER silently run on a route the
//      user didn't pick (owner priority #1: no hidden GPT route).
//
// The seam compiles + is reachable; nothing runs it until the owner opts in AND
// a Research/Work affordance calls `run` (next slice wires the UI + arXiv/HF/
// autoresearch). The Rust side returns the whole report at the end (no streaming
// delegate), so this is a single `await` — simpler than `runAgentSession`.

// `DeepResearchOutcome` + `DeepResearchFinding` (the pure, FFI-independent result
// types) live in the always-compiled Epistemos/Engine/DeepResearchReport.swift
// alongside the pure `DeepResearchReportRenderer`, so they compile + unit-test on
// MAS too; only this FFI-calling surface is Pro-gated.

#if !EPISTEMOS_APP_STORE

enum DeepResearchServiceError: Error, LocalizedError, Sendable {
    case disabled
    case localProviderUnsupported
    case emptyObjective
    case bindingsUnavailable
    case runtime(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Deep research is off. Set \(DeepResearchGateStatus.flagName)=1 to enable it."
        case .localProviderUnsupported:
            return "Deep research needs a cloud model — its parallel sub-agents use web search and tools."
        case .emptyObjective:
            return "Deep research needs a question to investigate."
        case .bindingsUnavailable:
            return "Deep research runtime is unavailable in this build."
        case .runtime(let message):
            return DeepResearchRuntimeDiagnostics.runtimeMessage(message)
        }
    }
}

enum DeepResearchRuntimeDiagnostics {
    nonisolated static let maxRuntimeErrorCharacters = 360

    nonisolated static func runtimeMessage(_ message: String, fallback: String = "Deep research runtime failed.") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? fallback : trimmed
        guard description.count > maxRuntimeErrorCharacters else {
            return description
        }
        return String(description.prefix(maxRuntimeErrorCharacters)) + "..."
    }

    nonisolated static func externalErrorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        let domain = nsError.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = domain.isEmpty ? "Error" : domain
        return runtimeMessage("Deep research runtime failed (\(label) \(nsError.code)).")
    }
}

/// Pro-only, flag-gated entry to the native deep-research runtime.
enum DeepResearchService {
    /// Default knobs, tuned for the M2 Pro 16GB ship rig: a small parallel
    /// fan-out (the orchestrator caps the live width to the plan's widest layer
    /// anyway), bounded sub-agent + synthesis turns so a run can't wander.
    static let defaultMaxConcurrency: UInt32 = 3
    static let defaultSubAgentMaxTurns: UInt32 = 6
    static let defaultSynthesisMaxTurns: UInt32 = 4

    /// Flag gate (mirrors the Rust `deep_research_enabled()` truth table).
    static var isEnabled: Bool { DeepResearchGateStatus.status().isActive }

    /// Whether a run could be started right now for `providerName`: flag ON AND
    /// a recognized cloud provider. Lets a caller decide whether to even show a
    /// "Deep research" affordance without throwing.
    static func isAvailable(forProvider providerName: String) -> Bool {
        isEnabled && DeepResearchGateStatus.isCloudProvider(providerName)
    }

    /// Honest one-line reason a run can't start for `providerName` (flag off vs
    /// local-only model). Used to surface a clear chat error instead of silently
    /// doing nothing. Precedence matches `run`'s guards: flag first, then cloud.
    static func unavailableReason(forProvider providerName: String) -> String {
        if !isEnabled {
            return "Deep research is off. Turn it on with \(DeepResearchGateStatus.flagName)=1 (Pro)."
        }
        if !DeepResearchGateStatus.isCloudProvider(providerName) {
            return "Deep research needs a cloud model — its parallel sub-agents use web search and tools. Switch to a cloud model and try again."
        }
        return "Deep research is unavailable right now."
    }

    /// Run a deep-research session and return the finished, `[id]`-cited report.
    /// Throws `.disabled` (flag off), `.localProviderUnsupported` (honest
    /// capability gate), `.emptyObjective`, or `.bindingsUnavailable` (no FFI in
    /// this build). All inputs are validated HERE before the FFI hop so the Rust
    /// side never sees a half-formed request.
    static func run(
        objective: String,
        providerName: String,
        vaultPath: String,
        maxConcurrency: UInt32 = defaultMaxConcurrency,
        subAgentMaxTurns: UInt32 = defaultSubAgentMaxTurns,
        synthesisMaxTurns: UInt32 = defaultSynthesisMaxTurns
    ) async throws -> DeepResearchOutcome {
        let trimmedObjective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedObjective.isEmpty else { throw DeepResearchServiceError.emptyObjective }
        guard isEnabled else { throw DeepResearchServiceError.disabled }
        guard DeepResearchGateStatus.isCloudProvider(providerName) else {
            throw DeepResearchServiceError.localProviderUnsupported
        }

        // Deep research's sub-agents need the web/agent tools; the Rust inner
        // builds an Agent-tier registry (minus delegate_task — the run owns its
        // own fan-out) regardless, but we pass a matching agent-tier ToolConfig
        // with web enabled. `allowedToolNames: nil` → tier is the only gate.
        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: false,
            enableWebSearch: true,
            toolTier: "agent",
            allowedToolNames: nil
        )

        return try await invokeDeepResearch(
            objective: trimmedObjective,
            providerName: providerName,
            toolConfig: toolConfig,
            maxConcurrency: max(1, maxConcurrency),
            subAgentMaxTurns: max(1, subAgentMaxTurns),
            synthesisMaxTurns: max(1, synthesisMaxTurns)
        )
    }
}

#if canImport(agent_coreFFI)
/// Real pro-build path: drive the generated UniFFI symbol + map the FFI record
/// into the Swift-native outcome. A non-`DeepResearchServiceError` from the FFI
/// (e.g. the typed `AgentErrorFFI`) is wrapped as `.runtime` so callers see one
/// uniform error type.
private func invokeDeepResearch(
    objective: String,
    providerName: String,
    toolConfig: ToolConfig,
    maxConcurrency: UInt32,
    subAgentMaxTurns: UInt32,
    synthesisMaxTurns: UInt32
) async throws -> DeepResearchOutcome {
    do {
        let report = try await runDeepResearchSession(
            objective: objective,
            providerName: providerName,
            toolConfig: toolConfig,
            maxConcurrency: maxConcurrency,
            subAgentMaxTurns: subAgentMaxTurns,
            synthesisMaxTurns: synthesisMaxTurns
        )
        return DeepResearchOutcome(
            objective: report.objective,
            report: report.report,
            findings: report.subResults.map {
                DeepResearchFinding(id: $0.id, question: $0.question, findings: $0.findings)
            }
        )
    } catch let error as DeepResearchServiceError {
        throw error
    } catch {
        throw DeepResearchServiceError.runtime(DeepResearchRuntimeDiagnostics.externalErrorDescription(error))
    }
}
#else
/// Fallback for targets that don't link `agent_coreFFI` (unit-test hosts):
/// honest "no deep-research backend in this build".
private func invokeDeepResearch(
    objective: String,
    providerName: String,
    toolConfig: ToolConfig,
    maxConcurrency: UInt32,
    subAgentMaxTurns: UInt32,
    synthesisMaxTurns: UInt32
) async throws -> DeepResearchOutcome {
    throw DeepResearchServiceError.bindingsUnavailable
}
#endif

#endif // !EPISTEMOS_APP_STORE
