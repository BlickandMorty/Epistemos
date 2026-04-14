import Foundation

nonisolated enum HierarchicalAgentRole: String, Codable, Sendable, CaseIterable {
    case overseer
    case mainAgent = "main_agent"
    case subAgent = "sub_agent"
    case controlPlane = "control_plane"
}

nonisolated enum AgentMessageType: String, Codable, Sendable, CaseIterable {
    case instruction
    case critique
    case evidence
    case review
    case status
    case interventionRequest = "intervention_request"
}

nonisolated enum AgentRequestedAction: String, Codable, Sendable, CaseIterable {
    case execute
    case review
    case verify
    case escalate
    case decline
}

nonisolated struct AgentMessageConstraints: Codable, Sendable, Equatable {
    let recursionDepthLimit: Int?
    let reviewRoundLimit: Int?
    let allowedTools: [String]
}

nonisolated struct HierarchicalAgentMessage: Codable, Sendable, Equatable {
    let messageID: String
    let taskID: String
    let parentTaskID: String?
    let senderRole: HierarchicalAgentRole
    let senderID: String
    let recipientRole: HierarchicalAgentRole
    let recipientID: String
    let messageType: AgentMessageType
    let instruction: String
    let constraints: AgentMessageConstraints
    let budgetRef: String
    let evidenceRefs: [String]
    let confidence: Double?
    let requestedAction: AgentRequestedAction
    let timestamp: Date

    func validated() throws -> HierarchicalAgentMessage {
        let normalized = HierarchicalAgentMessage(
            messageID: Self.trimmed(messageID),
            taskID: Self.trimmed(taskID),
            parentTaskID: Self.trimmedOrNil(parentTaskID),
            senderRole: senderRole,
            senderID: Self.trimmed(senderID),
            recipientRole: recipientRole,
            recipientID: Self.trimmed(recipientID),
            messageType: messageType,
            instruction: Self.trimmed(instruction),
            constraints: AgentMessageConstraints(
                recursionDepthLimit: constraints.recursionDepthLimit,
                reviewRoundLimit: constraints.reviewRoundLimit,
                allowedTools: Self.uniqueTrimmedStrings(constraints.allowedTools)
            ),
            budgetRef: Self.trimmed(budgetRef),
            evidenceRefs: Self.uniqueTrimmedStrings(evidenceRefs),
            confidence: confidence,
            requestedAction: requestedAction,
            timestamp: timestamp
        )

        guard !normalized.messageID.isEmpty else {
            throw AgentHierarchyProtocolError.emptyMessageID
        }
        guard !normalized.taskID.isEmpty else {
            throw AgentHierarchyProtocolError.emptyTaskID
        }
        guard !normalized.senderID.isEmpty else {
            throw AgentHierarchyProtocolError.emptySenderID
        }
        guard !normalized.recipientID.isEmpty else {
            throw AgentHierarchyProtocolError.emptyRecipientID
        }
        guard !normalized.instruction.isEmpty else {
            throw AgentHierarchyProtocolError.emptyInstruction
        }
        guard !normalized.budgetRef.isEmpty else {
            throw AgentHierarchyProtocolError.emptyBudgetReference
        }
        if let confidence = normalized.confidence {
            guard confidence.isFinite, (0 ... 1).contains(confidence) else {
                throw AgentHierarchyProtocolError.invalidConfidence(confidence)
            }
        }
        if let recursionDepthLimit = normalized.constraints.recursionDepthLimit {
            guard recursionDepthLimit >= 0 else {
                throw AgentHierarchyProtocolError.invalidConstraint("recursion depth must be zero or greater")
            }
        }
        if let reviewRoundLimit = normalized.constraints.reviewRoundLimit {
            guard reviewRoundLimit >= 0 else {
                throw AgentHierarchyProtocolError.invalidConstraint("review rounds must be zero or greater")
            }
        }

        try AgentHierarchyTopology.validate(sender: normalized.senderRole, recipient: normalized.recipientRole)
        return normalized
    }
}

nonisolated struct HierarchicalAgentAuditEntry: Codable, Sendable, Equatable {
    let senderRole: HierarchicalAgentRole
    let senderID: String
    let recipientRole: HierarchicalAgentRole
    let recipientID: String
    let purpose: String
    let evidenceRefs: [String]
    let confidence: Double?
    let cost: String
    let changedFinalResult: Bool
    let timestamp: Date
}

nonisolated enum AgentHierarchyProtocolError: LocalizedError, Equatable {
    case emptyMessageID
    case emptyTaskID
    case emptySenderID
    case emptyRecipientID
    case emptyInstruction
    case emptyBudgetReference
    case invalidConfidence(Double)
    case invalidConstraint(String)
    case disallowedTopology(HierarchicalAgentRole, HierarchicalAgentRole)

    var errorDescription: String? {
        switch self {
        case .emptyMessageID:
            return "Agent message id must not be empty."
        case .emptyTaskID:
            return "Agent task id must not be empty."
        case .emptySenderID:
            return "Agent sender id must not be empty."
        case .emptyRecipientID:
            return "Agent recipient id must not be empty."
        case .emptyInstruction:
            return "Agent instruction must not be empty."
        case .emptyBudgetReference:
            return "Agent budget reference must not be empty."
        case .invalidConfidence(let confidence):
            return "Agent confidence \(confidence) must be finite and between 0 and 1."
        case .invalidConstraint(let message):
            return message
        case .disallowedTopology(let sender, let recipient):
            return "Messages from \(sender.rawValue) to \(recipient.rawValue) are not allowed in the hierarchical topology."
        }
    }
}

nonisolated enum AgentHierarchyTopology {
    static func validate(
        sender: HierarchicalAgentRole,
        recipient: HierarchicalAgentRole
    ) throws {
        let allowed = switch (sender, recipient) {
        case (.overseer, .mainAgent),
             (.mainAgent, .overseer),
             (.mainAgent, .subAgent),
             (.subAgent, .mainAgent),
             (.controlPlane, .overseer),
             (.controlPlane, .mainAgent),
             (.mainAgent, .controlPlane):
            true
        default:
            false
        }

        guard allowed else {
            throw AgentHierarchyProtocolError.disallowedTopology(sender, recipient)
        }
    }
}

private extension HierarchicalAgentMessage {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedOrNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func uniqueTrimmedStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values.map(trimmed) where !value.isEmpty {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }
}
