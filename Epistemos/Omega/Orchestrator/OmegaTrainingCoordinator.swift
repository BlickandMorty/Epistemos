import Foundation

// MARK: - Omega Training Coordinator

/// Bridges the Omega execution pipeline with KnowledgeFusion training components.
/// When Omega generates execution traces, this coordinator:
/// 1. Feeds successful traces to StructuredODIATraceGenerator for structured training data
/// 2. Uses TrainingScheduler (which accepts [StructuredODIATrace]) to schedule overnight training runs
/// 3. Connects to ExperienceReplayBuffer for catastrophic forgetting prevention
/// 4. Monitors via CSISafeguard during autoresearch iterations
///
/// NOTE: This coordinator and TrainingScheduler both use StructuredODIATrace (Codable, observe/decide/interact/assess).
/// The canonical chat-format ODIATrace (Omega/Knowledge) is used only by Omega/Knowledge/TraceDataMixer for mlx-lm format.
@MainActor @Observable
final class OmegaTrainingCoordinator {
    private let traceGenerator = StructuredODIATraceGenerator()
    private let dataMixer = TraceDataMixer()

    /// Generate structured ODIA training data from completed Omega execution results.
    /// Pass taskType "research" for research tasks to get 2x weight in nightly training.
    func generateTrainingData(
        from results: [AgentStepResult],
        taskDescription: String,
        steps: [AgentStep],
        taskType: String = "general"
    ) -> [StructuredODIATrace] {
        traceGenerator.generateStructuredTraces(from: results, taskDescription: taskDescription, steps: steps, taskType: taskType)
    }

    /// Export traces as JSONL for training pipeline consumption.
    func exportTracesAsJSONL(traces: [StructuredODIATrace]) -> String {
        traceGenerator.toJSONL(traces)
    }

    /// Mix ODIA traces with other training data at the 40/20/20/20 ratio.
    func mixTrainingData(
        odiaTraces: [StructuredODIATrace],
        generalData: [String],
        reasoningData: [String],
        automationData: [String],
        targetCount: Int
    ) -> String {
        dataMixer.mix(
            odiaTraces: odiaTraces,
            generalData: generalData,
            reasoningData: reasoningData,
            automationData: automationData,
            targetCount: targetCount
        )
    }
}
