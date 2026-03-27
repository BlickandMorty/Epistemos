import Foundation

// MARK: - ODIA Trace Generator

/// Generates ODIA (Observe-Decide-Interact-Assess) format training traces
/// from the Omega execution log (omega-mcp SQLite database).
///
/// ODIA traces are used to train the model on tool-calling patterns:
/// - Observe: the task description and current state
/// - Decide: which tool to call and why
/// - Interact: the tool call with arguments
/// - Assess: the result and whether it succeeded
@MainActor
final class StructuredODIATraceGenerator {

    /// Generate structured ODIA training pairs from execution results.
    /// NOTE: These are raw structured traces. For the canonical chat-format
    /// training data, use Omega/Knowledge/ODIATraceGenerator instead.
    func generateStructuredTraces(from results: [AgentStepResult], taskDescription: String, steps: [AgentStep]) -> [StructuredODIATrace] {
        var traces: [StructuredODIATrace] = []

        for (index, step) in steps.enumerated() {
            guard let result = results.first(where: { $0.stepId == step.id }) else { continue }

            // Only include successful traces for training (quality filter)
            guard result.success else { continue }

            let trace = StructuredODIATrace(
                observe: ODIAObservation(
                    taskDescription: taskDescription,
                    stepIndex: index,
                    totalSteps: steps.count,
                    currentState: index > 0 ? "Previous step completed" : "Initial state"
                ),
                decide: ODIADecision(
                    reasoning: "Selected \(step.assignedAgent) agent with \(step.toolName) tool",
                    agentName: step.assignedAgent,
                    toolName: step.toolName,
                    confidence: result.confidence
                ),
                interact: ODIAInteraction(
                    toolCall: step.toolName,
                    argumentsJson: step.argumentsJson,
                    durationMs: result.durationMs
                ),
                assess: ODIAAssessment(
                    success: result.success,
                    outputJson: result.outputJson,
                    error: result.error
                )
            )
            traces.append(trace)
        }

        return traces
    }

    /// Convert structured traces to JSONL format.
    func toJSONL(_ traces: [StructuredODIATrace]) -> String {
        traces.compactMap { trace in
            guard let data = try? JSONEncoder().encode(trace),
                  let line = String(data: data, encoding: .utf8) else { return nil }
            return line
        }.joined(separator: "\n")
    }
}

// MARK: - ODIA Types (Structured Format)
// NOTE: This is the STRUCTURED ODIA format used for raw trace generation.
// The CANONICAL training format is the chat-style ODIATrace in Omega/Knowledge/ODIATraceGenerator.swift.
// TrainingScheduler uses the canonical (chat-format) type.

struct StructuredODIATrace: Codable, Sendable {
    let observe: ODIAObservation
    let decide: ODIADecision
    let interact: ODIAInteraction
    let assess: ODIAAssessment
}

struct ODIAObservation: Codable, Sendable {
    let taskDescription: String
    let stepIndex: Int
    let totalSteps: Int
    let currentState: String
}

struct ODIADecision: Codable, Sendable {
    let reasoning: String
    let agentName: String
    let toolName: String
    let confidence: Double
}

struct ODIAInteraction: Codable, Sendable {
    let toolCall: String
    let argumentsJson: String
    let durationMs: UInt64
}

struct ODIAAssessment: Codable, Sendable {
    let success: Bool
    let outputJson: String
    let error: String?
}
