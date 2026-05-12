import Foundation

// MARK: - Hybrid Action Space Router (Ω-HAS)

/// Routes tasks to the optimal execution arm: CLI (terminal) or GUI (computer/automation).
///
/// Signal analysis uses weighted keyword matching on step descriptions.
/// Pre-assigned agents are always respected. Ambiguous tasks default to CLI (faster, more reliable).
///
/// The HybridRouter sits above DualBrainRouter — it decides the execution *modality*
/// (CLI vs GUI), while DualBrainRouter decides the inference *brain* (GPU vs ANE).
@MainActor @Observable
final class HybridRouter {

    // MARK: - Types

    enum ExecutionArm: String, Sendable {
        case cli    // Terminal agent (action.bash / action.terminal)
        case gui    // Computer agent (see/click/type) or Automation agent
        case either // Both viable; prefer CLI for speed
    }

    struct RoutingDecision: Sendable {
        let arm: ExecutionArm
        let confidence: Double
        let reasoning: String
        let suggestedAgent: String?
        let suggestedTool: String?
    }

    // MARK: - Signal Tables

    private static let cliSignals: [(pattern: String, weight: Double)] = [
        ("git ", 0.95), ("npm ", 0.9), ("cargo ", 0.95), ("brew ", 0.9),
        ("xcodebuild", 0.95), ("make ", 0.9), ("cmake", 0.9),
        ("grep ", 0.85), ("find ", 0.85), ("ls ", 0.8),
        ("curl ", 0.85), ("wget ", 0.85), ("pip ", 0.9),
        ("build", 0.7), ("compile", 0.8), ("test", 0.7),
        ("deploy", 0.8), ("install", 0.75), ("run command", 0.95),
        ("execute command", 0.95), ("in terminal", 0.9), ("shell", 0.85),
        ("swift build", 0.95), ("swift test", 0.95), ("python", 0.8),
    ]

    private static let guiSignals: [(pattern: String, weight: Double)] = [
        ("click", 0.95), ("tap", 0.9), ("screenshot", 0.95),
        ("scroll", 0.85), ("visual", 0.8), ("dialog", 0.85),
        ("button", 0.85), ("menu", 0.85), ("window", 0.7),
        ("browser", 0.6), ("ui element", 0.9), ("accessibility", 0.9),
        ("see the screen", 0.95), ("look at", 0.8),
        ("open app", 0.6), ("switch to", 0.6), ("type into", 0.8),
        ("press key", 0.85), ("keyboard shortcut", 0.85),
    ]

    /// Pre-assigned agents that should never be re-routed.
    private static let cliAgents: Set<String> = ["terminal", "file"]
    private static let guiAgents: Set<String> = ["computer", "automation"]

    // MARK: - Classification

    /// Classify a step's optimal execution arm.
    func classify(step: AgentStep) -> RoutingDecision {
        // Pre-assigned agents are always respected.
        if Self.cliAgents.contains(step.assignedAgent) {
            return RoutingDecision(
                arm: .cli, confidence: 1.0,
                reasoning: "Pre-assigned to CLI agent '\(step.assignedAgent)'",
                suggestedAgent: nil, suggestedTool: nil
            )
        }
        if Self.guiAgents.contains(step.assignedAgent) {
            return RoutingDecision(
                arm: .gui, confidence: 1.0,
                reasoning: "Pre-assigned to GUI agent '\(step.assignedAgent)'",
                suggestedAgent: nil, suggestedTool: nil
            )
        }

        // Score description against CLI and GUI signals.
        let description = step.description.lowercased()
        let cliScore = Self.cliSignals
            .filter { description.contains($0.pattern) }
            .map(\.weight).max() ?? 0.0
        let guiScore = Self.guiSignals
            .filter { description.contains($0.pattern) }
            .map(\.weight).max() ?? 0.0

        if cliScore > guiScore + 0.1 {
            return RoutingDecision(
                arm: .cli, confidence: cliScore,
                reasoning: "CLI signals dominate (\(String(format: "%.2f", cliScore)) vs \(String(format: "%.2f", guiScore)))",
                suggestedAgent: "terminal",
                suggestedTool: "action.terminal"
            )
        } else if guiScore > cliScore + 0.1 {
            return RoutingDecision(
                arm: .gui, confidence: guiScore,
                reasoning: "GUI signals dominate (\(String(format: "%.2f", guiScore)) vs \(String(format: "%.2f", cliScore)))",
                suggestedAgent: "computer",
                suggestedTool: nil
            )
        } else {
            // Ambiguous: default to CLI for speed and reliability.
            return RoutingDecision(
                arm: .either, confidence: max(cliScore, guiScore),
                reasoning: "Ambiguous signals (\(String(format: "%.2f", cliScore)) CLI vs \(String(format: "%.2f", guiScore)) GUI), defaulting to CLI",
                suggestedAgent: "terminal",
                suggestedTool: "action.terminal"
            )
        }
    }

    // MARK: - Re-routing

    /// Returns a new step with agent/tool overridden if routing suggests a different arm.
    /// If the step is already optimally routed, returns it unchanged.
    func rerouteIfNeeded(_ step: AgentStep) -> AgentStep {
        let decision = classify(step: step)

        // Only re-route if the router has a confident suggestion and the current
        // agent doesn't match the suggested arm.
        guard let suggestedAgent = decision.suggestedAgent,
              suggestedAgent != step.assignedAgent,
              decision.confidence >= 0.7 else {
            return step
        }

        return AgentStep(
            id: step.id,
            description: step.description,
            assignedAgent: suggestedAgent,
            toolName: decision.suggestedTool ?? step.toolName,
            argumentsJson: step.argumentsJson,
            riskLevel: step.riskLevel,
            dependsOn: step.dependsOn
        )
    }
}
