import Foundation
import os

private let depthLog = Logger(subsystem: "com.epistemos", category: "AgentDepthLimiter")

// MARK: - Agent Depth Limiter
// Prevents infinite subagent cascades by limiting delegation recursion depth.
// A coordinator agent can delegate to sub-agents, which can delegate further,
// but the chain is capped at a configurable depth (default 3).
//
// Usage: Check canDelegate() before spawning a sub-agent. Call push()/pop()
// around delegation boundaries.

@MainActor
final class AgentDepthLimiter {

    /// Max delegation depth before blocking further sub-agent spawning.
    let maxDepth: Int

    /// Current delegation depth.
    private(set) var currentDepth: Int = 0

    /// Stack of agent IDs at each depth level (for diagnostics).
    private var depthStack: [String] = []

    init(maxDepth: Int = 3) {
        self.maxDepth = maxDepth
    }

    /// Whether a sub-agent delegation is allowed at current depth.
    var canDelegate: Bool {
        currentDepth < maxDepth
    }

    /// Push a new delegation level. Returns false if depth limit exceeded.
    @discardableResult
    func push(agentId: String) -> Bool {
        guard canDelegate else {
            let stackTrace = self.depthStack.joined(separator: " > ")
            depthLog.warning("Delegation blocked: depth \(self.currentDepth) >= max \(self.maxDepth). Stack: \(stackTrace)")
            return false
        }
        currentDepth += 1
        depthStack.append(agentId)
        depthLog.debug("Delegation push: depth=\(self.currentDepth), agent=\(agentId)")
        return true
    }

    /// Pop a delegation level after sub-agent completes.
    func pop() {
        guard currentDepth > 0 else {
            depthLog.warning("pop() called at depth 0 — ignoring")
            return
        }
        let agent = depthStack.removeLast()
        currentDepth -= 1
        depthLog.debug("Delegation pop: depth=\(self.currentDepth), returned from \(agent)")
    }

    /// Reset to root level (e.g. on new plan).
    func reset() {
        currentDepth = 0
        depthStack.removeAll()
    }

    /// Diagnostic: current delegation chain as a readable string.
    var chainDescription: String {
        depthStack.isEmpty ? "(root)" : depthStack.joined(separator: " → ")
    }
}
