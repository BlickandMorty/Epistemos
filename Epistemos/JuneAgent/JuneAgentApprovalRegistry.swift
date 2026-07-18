#if EPISTEMOS_APP_STORE
import Foundation

// SAFETY: every decision is guarded by `condition`. The wait occurs on the
// agent_core callback thread, never the main actor, and times out closed.
nonisolated final class AgentApprovalGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var decisions: [String: Bool] = [:]

    func deliver(id: String, approved: Bool) {
        condition.lock()
        decisions[id] = approved
        condition.broadcast()
        condition.unlock()
    }

    func awaitDecision(id: String) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline {
            if let decision = decisions.removeValue(forKey: id) {
                return decision
            }
            condition.wait(until: min(deadline, Date().addingTimeInterval(1)))
        }
        return false
    }
}

nonisolated final class JuneAgentApprovalRegistry: @unchecked Sendable {
    static let maxApprovalChoiceCharacters = 64
    private static let maxPendingApprovals = 16

    private struct PendingApproval {
        let id: String
        let sessionID: String
        let toolName: String
    }

    private let gate = AgentApprovalGate()
    private var pendingApprovals: [String: PendingApproval] = [:]
    private var pendingApprovalIDsBySession: [String: [String]] = [:]

    func awaitDecision(id: String) -> Bool {
        gate.awaitDecision(id: id)
    }

    func deliver(id: String, approved: Bool) {
        gate.deliver(id: id, approved: approved)
    }

    @MainActor
    @discardableResult
    func recordPendingApproval(id: String, sessionID: String, toolName: String) -> Bool {
        guard JuneToolEventBounds.isBoundedToolProtocolID(id),
              !sessionID.isEmpty,
              !toolName.isEmpty,
              toolName.utf8.count <= JuneToolEventBounds.maxToolNameBytes else {
            gate.deliver(id: id, approved: false)
            return false
        }
        if pendingApprovals[id] == nil, pendingApprovals.count >= Self.maxPendingApprovals {
            gate.deliver(id: id, approved: false)
            return false
        }
        pendingApprovals[id] = PendingApproval(id: id, sessionID: sessionID, toolName: toolName)
        var ids = pendingApprovalIDsBySession[sessionID] ?? []
        if !ids.contains(id) {
            ids.append(id)
        }
        pendingApprovalIDsBySession[sessionID] = ids
        return true
    }

    @MainActor
    func popPendingApprovalID(sessionID: String, requestID: String) -> Bool {
        guard let pending = pendingApprovals[requestID],
              pending.sessionID == sessionID else {
            return false
        }
        pendingApprovals.removeValue(forKey: requestID)
        pendingApprovalIDsBySession[sessionID]?.removeAll { $0 == requestID }
        if pendingApprovalIDsBySession[sessionID]?.isEmpty == true {
            pendingApprovalIDsBySession[sessionID] = nil
        }
        return true
    }

    @MainActor
    func denyPendingApprovals(sessionID: String) {
        guard let ids = pendingApprovalIDsBySession.removeValue(forKey: sessionID) else { return }
        for id in ids {
            pendingApprovals.removeValue(forKey: id)
            gate.deliver(id: id, approved: false)
        }
    }
}

#endif
