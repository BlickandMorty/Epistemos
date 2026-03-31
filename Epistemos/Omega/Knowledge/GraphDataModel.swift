import Foundation

// MARK: - Agent Execution Graph Data Model (Omega-6)

/// Converts agent execution traces into graph-compatible data structures
/// for visualization in the knowledge graph.
///
/// Each agent task execution produces a subgraph:
/// - Root node: the task description (type: .idea)
/// - Step nodes: individual agent steps (type: .source)
/// - Tool nodes: tools used (type: .tag)
/// - Edges: execution flow (root → steps), tool usage (step → tool)
@MainActor
final class AgentGraphDataModel {

    // MARK: - Graph Node Types for Agent Execution

    struct ExecutionGraphNode: Identifiable, Sendable {
        let id: String
        let label: String
        let type_: NodeType
        let weight: Double
        let metadata: [String: String]

        enum NodeType: String, Sendable {
            case task        // Root: the task description
            case step        // An individual agent step
            case tool        // A tool used during execution
            case agent       // An agent that executed steps
            case result      // A successful result
        }
    }

    struct ExecutionGraphEdge: Sendable {
        let source: String
        let target: String
        let type_: EdgeType
        let weight: Double

        enum EdgeType: String, Sendable {
            case executedBy   // task → agent
            case contains     // task → step
            case usedTool     // step → tool
            case dependsOn    // step → step (from dependsOn array)
            case produced     // step → result
        }
    }

    struct ExecutionSubgraph: Sendable {
        let nodes: [ExecutionGraphNode]
        let edges: [ExecutionGraphEdge]
        let taskId: String
        let taskDescription: String
    }

    // MARK: - Conversion

    /// Convert a completed task execution into a graph subgraph.
    static func fromExecution(
        taskDescription: String,
        steps: [AgentStep],
        results: [UUID: AgentStepResult]
    ) -> ExecutionSubgraph {
        let taskId = UUID().uuidString
        var nodes: [ExecutionGraphNode] = []
        var edges: [ExecutionGraphEdge] = []

        // Root task node.
        nodes.append(ExecutionGraphNode(
            id: taskId,
            label: String(taskDescription.prefix(60)),
            type_: .task,
            weight: 1.0,
            metadata: ["full_description": taskDescription]
        ))

        // Collect unique agents and tools.
        var seenAgents: Set<String> = []
        var seenTools: Set<String> = []

        for step in steps {
            let stepId = step.id.uuidString
            let result = results[step.id]
            let success = result?.success ?? false

            // Step node.
            nodes.append(ExecutionGraphNode(
                id: stepId,
                label: String(step.description.prefix(40)),
                type_: .step,
                weight: success ? 1.0 : 0.3,
                metadata: [
                    "tool": step.toolName,
                    "agent": step.assignedAgent,
                    "success": success ? "true" : "false",
                    "duration_ms": "\(result?.durationMs ?? 0)",
                ]
            ))

            // Task → Step edge.
            edges.append(ExecutionGraphEdge(
                source: taskId,
                target: stepId,
                type_: .contains,
                weight: 0.8
            ))

            // Agent node (deduplicated).
            if !seenAgents.contains(step.assignedAgent) {
                seenAgents.insert(step.assignedAgent)
                let agentId = "agent-\(step.assignedAgent)"
                nodes.append(ExecutionGraphNode(
                    id: agentId,
                    label: step.assignedAgent,
                    type_: .agent,
                    weight: 0.7,
                    metadata: [:]
                ))
                edges.append(ExecutionGraphEdge(
                    source: taskId,
                    target: agentId,
                    type_: .executedBy,
                    weight: 0.6
                ))
            }

            // Tool node (deduplicated).
            if !seenTools.contains(step.toolName) {
                seenTools.insert(step.toolName)
                let toolId = "tool-\(step.toolName)"
                nodes.append(ExecutionGraphNode(
                    id: toolId,
                    label: step.toolName,
                    type_: .tool,
                    weight: 0.5,
                    metadata: [:]
                ))
            }

            // Step → Tool edge.
            edges.append(ExecutionGraphEdge(
                source: stepId,
                target: "tool-\(step.toolName)",
                type_: .usedTool,
                weight: 0.5
            ))

            // Step dependency edges.
            for depId in step.dependsOn {
                edges.append(ExecutionGraphEdge(
                    source: depId.uuidString,
                    target: stepId,
                    type_: .dependsOn,
                    weight: 0.9
                ))
            }

            // Result node for successful steps.
            if success, let output = result?.outputJson, !output.isEmpty {
                let resultId = "result-\(stepId)"
                nodes.append(ExecutionGraphNode(
                    id: resultId,
                    label: "Result",
                    type_: .result,
                    weight: 0.6,
                    metadata: ["output_preview": String(output.prefix(200))]
                ))
                edges.append(ExecutionGraphEdge(
                    source: stepId,
                    target: resultId,
                    type_: .produced,
                    weight: 0.4
                ))
            }
        }

        return ExecutionSubgraph(
            nodes: nodes,
            edges: edges,
            taskId: taskId,
            taskDescription: taskDescription
        )
    }
}
