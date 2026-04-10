import Foundation

// MARK: - AgentRuntime Protocol
// Unified abstraction for all agent backends. The UI only talks to AgentRuntime —
// swapping from local Rust loop to Claude Managed Sessions is a one-line change.
//
// Implementations:
//   LocalRustRuntime — wraps existing Rust agent_core FFI (default)
//   ClaudeManagedRuntime — wraps CMA API (optional, experimental)

/// Protocol that makes all agent backends interchangeable.
@MainActor
protocol AgentRuntime: AnyObject, Sendable {
    /// Unique identifier for this runtime type.
    var runtimeId: String { get }

    /// Human-readable name shown in settings.
    var displayName: String { get }

    /// Whether this runtime is currently available (keys set, feature enabled, etc.).
    var isAvailable: Bool { get }

    /// Start an agent session. Returns a session ID.
    func startSession(
        objective: String,
        config: AgentSessionConfig
    ) async throws -> String

    /// Cancel a running session.
    func cancelSession(_ sessionId: String) async

    /// Subscribe to events from a running session.
    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentRuntimeEvent>

    /// Query current session state (for UI display).
    func sessionState(_ sessionId: String) -> AgentSessionState
}

// MARK: - Session Config

/// Unified session configuration — works for all backends.
struct AgentSessionConfig: Sendable {
    var maxTurns: Int = 50
    var maxCostUSD: Double?
    var enableBash: Bool = false
    var enableWebSearch: Bool = true
    var enableVaultWrite: Bool = false
    var additionalContext: String = ""
    var runtimePreference: RuntimePreference = .localFirst

    enum RuntimePreference: String, Sendable, Codable {
        case localFirst   // prefer local, fall back to cloud
        case cloudFirst   // prefer cloud, fall back to local
        case localOnly    // never use cloud
        case cloudOnly    // never use local
    }
}

// MARK: - Agent Events

/// Unified event stream — identical schema regardless of backend.
enum AgentRuntimeEvent: Sendable {
    case sessionStarted(sessionId: String)
    case turnStarted(turn: Int)
    case tokenEmitted(token: String)
    case thinkingEmitted(token: String)
    case toolCallStarted(toolName: String, args: String)
    case toolCallCompleted(toolName: String, result: String, durationMs: Int)
    case approvalRequired(toolName: String, args: String, riskLevel: String)
    case budgetWarning(spentUSD: Double, limitUSD: Double)
    case turnCompleted(turn: Int, content: String)
    case sessionCompleted(totalTurns: Int, totalCostUSD: Double)
    case sessionFailed(error: String)
    case sessionCancelled
}

// MARK: - Agent Session State

/// Simplified session state for UI display.
enum AgentSessionState: Sendable {
    case idle
    case running(turn: Int)
    case pausedForApproval(toolName: String)
    case completed(turns: Int)
    case failed(error: String)
    case cancelled
}

// MARK: - Runtime Registry

/// Manages available runtimes and provides the active one.
@MainActor
@Observable
final class AgentRuntimeRegistry {
    private(set) var runtimes: [any AgentRuntime] = []
    var activeRuntimeId: String = "local-rust"

    var activeRuntime: (any AgentRuntime)? {
        runtimes.first { $0.runtimeId == activeRuntimeId }
    }

    var availableRuntimes: [any AgentRuntime] {
        runtimes.filter(\.isAvailable)
    }

    func register(_ runtime: any AgentRuntime) {
        runtimes.append(runtime)
    }

    func setActive(_ runtimeId: String) {
        guard runtimes.contains(where: { $0.runtimeId == runtimeId }) else { return }
        activeRuntimeId = runtimeId
    }
}
