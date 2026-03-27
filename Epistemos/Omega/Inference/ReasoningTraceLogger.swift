import Foundation
import os

// MARK: - ReasoningTraceLogger

/// Converts completed reasoning chains into JSONL training traces.
///
/// Output format: chat-style JSONL compatible with mlx-lm fine-tuning.
/// Each round produces one training example capturing the think → critique → refine cycle.
/// The full chain also produces a planning-style trace for multi-step reasoning training.
///
/// Traces are raw JSONL strings (not ODIATrace objects) to sidestep the
/// Omega/Knowledge vs KnowledgeFusion/SyntheticData type drift.
@MainActor
final class ReasoningTraceLogger {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "ReasoningTrace")

    /// Convert a completed reasoning chain into JSONL training lines.
    ///
    /// Returns an array of JSONL strings, each a valid JSON object with a "messages" array.
    /// These feed directly into `TrainingScheduler.pendingReasoningTraces`.
    func logReasoningChain(
        query: String,
        rounds: [ReasoningRound],
        finalAnswer: String,
        totalDurationMs: UInt64
    ) -> [String] {
        guard !rounds.isEmpty else { return [] }

        var jsonlLines: [String] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        // Per-round traces: teach the model each step of the reasoning process
        for round in rounds {
            let systemContent = buildRoundSystemPrompt(round: round, totalRounds: rounds.count)
            let userContent = buildRoundUserPrompt(query: query, round: round)
            let assistantContent = round.refinedOutput.isEmpty ? round.thinkOutput : round.refinedOutput

            let entry = TrainingEntry(messages: [
                .init(role: "system", content: systemContent),
                .init(role: "user", content: userContent),
                .init(role: "assistant", content: assistantContent),
            ])

            if let data = try? encoder.encode(entry),
               let line = String(data: data, encoding: .utf8) {
                jsonlLines.append(line)
            }
        }

        // Full chain trace: teach the model the complete multi-step reasoning pattern
        if rounds.count > 1 {
            let chainEntry = buildChainTrace(query: query, rounds: rounds, finalAnswer: finalAnswer)
            if let data = try? encoder.encode(chainEntry),
               let line = String(data: data, encoding: .utf8) {
                jsonlLines.append(line)
            }
        }

        log.info("Logged \(jsonlLines.count) reasoning traces (\(rounds.count) rounds, \(totalDurationMs)ms)")
        return jsonlLines
    }

    // MARK: - Round Prompts

    private func buildRoundSystemPrompt(round: ReasoningRound, totalRounds: Int) -> String {
        let phase: String
        if round.roundIndex == 0 {
            phase = "initial reasoning"
        } else if !round.toolCalls.isEmpty {
            phase = "reasoning with tool-augmented refinement (round \(round.roundIndex + 1)/\(totalRounds))"
        } else {
            phase = "self-refined reasoning (round \(round.roundIndex + 1)/\(totalRounds))"
        }

        return "You are performing \(phase). " +
            "Think step by step, critique your reasoning, and refine until quality score >= 0.7. " +
            "Quality achieved: \(String(format: "%.2f", round.qualityScore))."
    }

    private func buildRoundUserPrompt(query: String, round: ReasoningRound) -> String {
        var parts = ["Question: \(query)"]

        if !round.critiqueOutput.isEmpty {
            parts.append("Self-critique: \(String(round.critiqueOutput.prefix(500)))")
        }

        if !round.toolCalls.isEmpty {
            let toolSummary = round.toolCalls.map { "\($0.toolName)(\($0.query)): \(String($0.result.prefix(300)))" }
                .joined(separator: "\n")
            parts.append("Tool results:\n\(toolSummary)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Chain Trace

    private func buildChainTrace(
        query: String,
        rounds: [ReasoningRound],
        finalAnswer: String
    ) -> TrainingEntry {
        let roundsSummary = rounds.enumerated().map { idx, round in
            let toolInfo = round.toolCalls.isEmpty ? "" : " [tools: \(round.toolCalls.map(\.toolName).joined(separator: ", "))]"
            return "Round \(idx + 1): score=\(String(format: "%.2f", round.qualityScore))\(toolInfo)"
        }.joined(separator: "\n")

        return TrainingEntry(messages: [
            .init(
                role: "system",
                content: "You are performing recursive multi-step reasoning. " +
                    "Loop through THINK → CRITIQUE → ACT → REFINE until quality is sufficient. " +
                    "This trace shows a \(rounds.count)-round reasoning chain."
            ),
            .init(
                role: "user",
                content: "Question: \(query)\n\nReasoning rounds:\n\(roundsSummary)"
            ),
            .init(
                role: "assistant",
                content: finalAnswer
            ),
        ])
    }
}

// MARK: - Training Entry (JSONL format)

private struct TrainingEntry: Codable {
    let messages: [Message]

    struct Message: Codable {
        let role: String
        let content: String
    }
}
