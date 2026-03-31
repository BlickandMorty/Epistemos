import Foundation

// MARK: - Agent Desktop Loop (VLM Desktop)

/// Perceive-Think-Act-Verify loop for the isolated agent desktop.
///
/// The loop runs on the agent's dedicated Space:
/// 1. PERCEIVE: ScreenCaptureKit frame + AX tree via Screen2AXFusion
/// 2. THINK: LLM reasons about current state vs goal, plans next action
/// 3. ACT: Execute action via AgentActionExecutor (AX-first, CGEvent fallback)
/// 4. VERIFY: Re-capture screen, check if action succeeded
/// 5. LOG: Record action + screenshot to trace
///
/// Repeat until goal met, max iterations, timeout, or user cancellation.
@MainActor @Observable
final class AgentDesktopLoop {

    // MARK: - Configuration

    let maxIterations = 100
    let maxRetries = 3
    let uiSettleDelay: Duration = .milliseconds(400)
    let totalTimeout: Duration = .seconds(900) // 15 minutes

    // MARK: - State

    enum LoopState: String, Sendable {
        case idle, perceiving, thinking, confirmationWait
        case acting, verifying, logging
        case completed, failed, cancelled, timedOut
    }

    private(set) var state: LoopState = .idle
    private(set) var iteration: Int = 0
    private(set) var currentGoal: String = ""
    private(set) var trace: [TraceEntry] = []
    private var cancelled = false

    struct TraceEntry: Identifiable, Sendable {
        let id = UUID()
        let iteration: Int
        let timestamp: Date
        let perception: String
        let reasoning: String
        let actionDescription: String
        let success: Bool
    }

    // MARK: - Dependencies

    let desktopManager: AgentDesktopManager
    let executor: AgentActionExecutor
    let perception: Screen2AXFusion

    init(
        desktopManager: AgentDesktopManager,
        executor: AgentActionExecutor,
        perception: Screen2AXFusion
    ) {
        self.desktopManager = desktopManager
        self.executor = executor
        self.perception = perception
    }

    // MARK: - Main Loop

    /// Run the agent loop for a given goal.
    func run(goal: String, targetBundleID: String) async -> DesktopSessionResult {
        currentGoal = goal
        state = .perceiving
        iteration = 0
        trace = []
        cancelled = false

        let sessionStart = Date()

        // Prepare the desktop.
        await desktopManager.prepare(targetBundleID: targetBundleID)
        guard desktopManager.state == .ready else {
            state = .failed
            return DesktopSessionResult(
                success: false,
                iterations: 0,
                reason: desktopManager.errorMessage ?? "Desktop setup failed"
            )
        }
        desktopManager.activate()

        defer {
            if ![.completed, .failed, .cancelled, .timedOut].contains(state) {
                state = .failed
            }
        }

        while iteration < maxIterations, !cancelled {
            // Check total timeout.
            if Date().timeIntervalSince(sessionStart) > Double(totalTimeout.components.seconds) {
                state = .timedOut
                break
            }

            iteration += 1

            // 1. PERCEIVE
            state = .perceiving
            let pid = desktopManager.targetAppPID ?? ProcessInfo.processInfo.processIdentifier
            let perceptionResult = perception.perceiveQuick(pid: pid)

            // 2. THINK — placeholder for LLM reasoning
            state = .thinking
            let perceptionSummary = "AX tree: \(perceptionResult.interactiveCount) elements, method: \(perceptionResult.method)"

            // In a full implementation, the LLM would analyze the perception
            // against the goal and decide the next action. For now, we
            // record the perception and break (single-step execution).
            let reasoning = "Perceived \(perceptionResult.interactiveCount) interactive elements. Goal: \(goal)."

            // 3. ACT — in the full implementation, the LLM's planned action
            // would be executed here. For now, this is a template for
            // the Perceive-Think-Act-Verify loop structure.
            state = .acting

            // 4. VERIFY
            state = .verifying
            try? await Task.sleep(for: uiSettleDelay)

            // 5. LOG
            state = .logging
            let entry = TraceEntry(
                iteration: iteration,
                timestamp: Date(),
                perception: perceptionSummary,
                reasoning: reasoning,
                actionDescription: "observe",
                success: true
            )
            trace.append(entry)

            // For now, complete after one perception cycle.
            // Full implementation loops until LLM determines goal is met.
            state = .completed
            break
        }

        // Tear down.
        await desktopManager.tearDown()

        let finalState = state
        return DesktopSessionResult(
            success: finalState == .completed,
            iterations: iteration,
            reason: finalState.rawValue
        )
    }

    /// Cancel the current loop.
    func cancel() {
        cancelled = true
        state = .cancelled
    }
}

// MARK: - Session Result

struct DesktopSessionResult: Sendable {
    let success: Bool
    let iterations: Int
    let reason: String
}
