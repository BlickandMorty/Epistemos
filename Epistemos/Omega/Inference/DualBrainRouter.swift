import Foundation
import os

// MARK: - Dual Brain Router

/// Routes agent tasks to the appropriate inference brain:
/// - Brain 1 (Reasoning, Metal GPU): Planning, DAG generation, complex reasoning, code gen
/// - Brain 2 (Device Action, ANE): AX tree parsing, click targeting, screenshot verification
///
/// When Brain 2 is unavailable, all tasks fall back to Brain 1 (shared GPU).
/// Mirrors the routing table from the master prompt (Anchor 3).
@MainActor @Observable
final class DualBrainRouter {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "DualBrain")

    /// Hardware tier for capability-aware routing.
    let hardwareTier: HardwareTierManager

    /// Brain 2 service (fast device actions).
    let deviceAgent: DeviceAgentService

    /// Whether dual-brain mode is active (Brain 2 has a dedicated backend).
    var isDualBrainActive: Bool { deviceAgent.isReady && deviceAgent.isANEDedicated && hardwareTier.supportsDualModel }

    /// Routing statistics for the current session.
    private(set) var brain1Count: Int = 0
    private(set) var brain2Count: Int = 0
    private(set) var fallbackCount: Int = 0

    init(hardwareTier: HardwareTierManager, deviceAgent: DeviceAgentService) {
        self.hardwareTier = hardwareTier
        self.deviceAgent = deviceAgent
    }

    /// Determine which brain should handle a task based on its category.
    func route(task: AgentStep) -> BrainTarget {
        let target = classify(step: task)

        switch target {
        case .brain1ReasoningGPU:
            brain1Count += 1
        case .brain2DeviceANE:
            if deviceAgent.isReady {
                brain2Count += 1
            } else {
                fallbackCount += 1
                log.debug("Brain 2 unavailable, falling back to Brain 1 for: \(task.toolName, privacy: .public)")
                return .brain1ReasoningGPU
            }
        }

        return target
    }

    /// Classify a step into the appropriate brain target.
    /// Matches the routing table from Anchor 3:
    /// - Planning/Reasoning/CodeGen → Brain 1
    /// - UIInteraction/ScreenParse/KeyboardInput/VisualVerify → Brain 2
    private func classify(step: AgentStep) -> BrainTarget {
        // Route by agent type first
        switch step.assignedAgent {
        case "automation":
            // All UI automation goes to Brain 2
            return .brain2DeviceANE

        case "computer":
            // Ghost computer use (AX + input simulation) goes to Brain 2
            return .brain2DeviceANE

        case "safari":
            // Safari page inspection → Brain 2, planning/search → Brain 1
            switch step.toolName {
            case "get_page_url", "get_page_title":
                return .brain2DeviceANE
            default:
                return .brain1ReasoningGPU
            }

        case "terminal":
            // Command generation needs reasoning
            return .brain1ReasoningGPU

        case "notes":
            // Note search/create needs reasoning context
            return .brain1ReasoningGPU

        case "file":
            // File operations need reasoning for content generation
            switch AgentToolNameAliases.canonical(step.toolName) {
            case "file.list":
                return .brain2DeviceANE // Simple directory listing
            default:
                return .brain1ReasoningGPU
            }

        default:
            return .brain1ReasoningGPU
        }
    }

    /// Route a task and execute it on the appropriate brain.
    /// For Brain 2 tasks, uses DeviceAgentService. For Brain 1, returns nil
    /// (caller should use the standard OmegaInferenceBridge path).
    func routeAndExecuteIfBrain2(
        step: AgentStep,
        axTreeJson: String?
    ) async throws -> DeviceActionResult? {
        let target = route(task: step)
        guard target == .brain2DeviceANE, deviceAgent.isReady else {
            return nil
        }

        // Brain 2 handles UI resolution
        guard let axTree = axTreeJson, !axTree.isEmpty else {
            throw DeviceAgentError.selectorNotFound("No AX tree provided for Brain 2 task")
        }

        return try await deviceAgent.resolveUIAction(
            axTreeJson: axTree,
            userIntent: step.description
        )
    }

    /// Reset routing statistics.
    func resetStats() {
        brain1Count = 0
        brain2Count = 0
        fallbackCount = 0
    }
}

// MARK: - Brain Target

/// Which inference brain should handle a task.
enum BrainTarget: String, Sendable {
    /// Brain 1: Reasoning model on Metal GPU (Qwen 4B bridge → future Epistemos-Base 3B Mamba-3).
    case brain1ReasoningGPU = "Brain1-GPU"
    /// Brain 2: Device action model on ANE (future Epistemos-Nano 1B CoreML).
    case brain2DeviceANE = "Brain2-ANE"
}
