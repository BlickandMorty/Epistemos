import Foundation

// MARK: - Task Graph

/// Directed acyclic graph of agent steps with dependency tracking.
/// Supports sequential and parallel execution based on dependency edges.
@MainActor @Observable
final class TaskGraph {
    var steps: [AgentStep] = []
    var results: [UUID: AgentStepResult] = [:]
    var status: TaskGraphStatus = .idle

    /// Add a step to the graph.
    func addStep(_ step: AgentStep) {
        steps.append(step)
    }

    /// Get all steps that are ready to execute (all dependencies satisfied).
    func readySteps() -> [AgentStep] {
        let completedIds = Set(results.keys)
        return steps.filter { step in
            // Not yet executed
            !completedIds.contains(step.id) &&
            // All dependencies satisfied
            step.dependsOn.allSatisfy { completedIds.contains($0) }
        }
    }

    /// Record a step result.
    func recordResult(_ result: AgentStepResult) {
        results[result.stepId] = result
        updateStatus()
    }

    /// Whether all steps are complete.
    var isComplete: Bool {
        results.count == steps.count && !steps.isEmpty
    }

    /// Whether any step has failed.
    var hasFailed: Bool {
        results.values.contains { !$0.success }
    }

    /// Reset the graph for re-execution (keeps steps, clears results).
    func reset() {
        steps.removeAll()
        results.removeAll()
        status = .idle
    }

    private func updateStatus() {
        if hasFailed {
            status = .failed
        } else if isComplete {
            status = .completed
        } else {
            status = .executing
        }
    }
}

enum TaskGraphStatus: String, Sendable {
    case idle
    case planning
    case awaitingConfirmation
    case executing
    case completed
    case failed
    case paused // Research pause
}
