import Foundation

// MARK: - ODIA Trace Generator

/// Converts Omega agent execution results into ODIA (Offline Distillation with
/// Imitation from Actions) training traces. Each successful execution becomes
/// a training example: system prompt + user query → tool calls + results.
///
/// Output format: JSONL compatible with mlx-lm fine-tuning.
/// Composition target: 40% of training data (per TRAINING_GUIDE.md).
@MainActor
final class ODIATraceGenerator {

    /// Generate ODIA traces from completed agent execution.
    func generateTraces(
        from results: [AgentStepResult],
        taskDescription: String,
        steps: [AgentStep]
    ) -> [ODIATrace] {
        // Only generate traces from successful executions
        let successPairs = zip(steps, results).filter { $0.1.success }
        guard !successPairs.isEmpty else { return [] }

        // Single-step: one trace per step
        // Multi-step: one trace for the full plan + individual step traces
        var traces: [ODIATrace] = []

        // Full plan trace (multi-step reasoning)
        if successPairs.count > 1 {
            let planJson = successPairs.map { step, result in
                [
                    "tool": step.toolName,
                    "agent": step.assignedAgent,
                    "arguments": step.argumentsJson,
                    "result": result.outputJson,
                ]
            }
            if let planData = try? JSONSerialization.data(withJSONObject: planJson),
               let planString = String(data: planData, encoding: .utf8) {
                traces.append(ODIATrace(
                    systemPrompt: "You are a task planner. Output a JSON array of steps.",
                    userQuery: taskDescription,
                    assistantResponse: planString,
                    traceType: .planning,
                    stepCount: successPairs.count,
                    totalDurationMs: results.reduce(0) { $0 + $1.durationMs },
                    timestamp: Date()
                ))
            }
        }

        // Individual step traces (tool calling)
        for (step, result) in successPairs {
            let response = """
            {"tool": "\(step.toolName)", "arguments": \(step.argumentsJson), "result": \(result.outputJson)}
            """
            traces.append(ODIATrace(
                systemPrompt: "You are an agent. Call the appropriate tool.",
                userQuery: "\(taskDescription) — Step: \(step.description)",
                assistantResponse: response,
                traceType: .toolCall,
                stepCount: 1,
                totalDurationMs: result.durationMs,
                timestamp: Date()
            ))
        }

        return traces
    }

    /// Convert traces to JSONL format for mlx-lm training.
    func toJSONL(_ traces: [ODIATrace]) -> String {
        traces.compactMap { trace in
            let entry: [String: Any] = [
                "messages": [
                    ["role": "system", "content": trace.systemPrompt],
                    ["role": "user", "content": trace.userQuery],
                    ["role": "assistant", "content": trace.assistantResponse],
                ]
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: entry),
                  let line = String(data: data, encoding: .utf8) else { return nil }
            return line
        }.joined(separator: "\n")
    }
}

// MARK: - ODIA Trace Type

struct ODIATrace: Sendable {
    let systemPrompt: String
    let userQuery: String
    let assistantResponse: String
    let traceType: ODIATraceType
    let stepCount: Int
    let totalDurationMs: Int
    let timestamp: Date
}

enum ODIATraceType: String, Sendable {
    case planning = "planning"
    case toolCall = "tool_call"
    case verification = "verification"
    case reasoning = "reasoning"
}
