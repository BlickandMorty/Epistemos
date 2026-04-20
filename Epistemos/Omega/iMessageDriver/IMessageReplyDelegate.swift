import Foundation
import os

/// `AgentEventDelegate` implementation specialised for the iMessage driver.
/// It accumulates every `textDelta` and every *final* tool-completed payload,
/// and on `onComplete` sends the collected response back to the contact that
/// originally messaged the agent — via the `imessage send` tool.
///
/// This delegate never calls the computer-use bridge, never asks the user
/// clarifying questions, and never surfaces permission prompts. It runs
/// autonomously — the safety net is the ContactConfig stored in the
/// `imessage_contacts` table (tier, auto_approve, allowed).
nonisolated final class IMessageReplyDelegate: AgentStreamEventDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.epistemos", category: "IMessageReplyDelegate")
    private let contactHandle: String
    private let vaultPath: String
    private let replyChannel: any DriverChannelReplying
    private let autoApproveModifications: Bool
    /// Prefix prepended to every chunk before send. Used by group routing
    /// to label which model produced which reply (e.g. "[qwen-2b] ...").
    private let replyPrefix: String?
    private let permissionLock = NSLock()
    private var pendingPermissionRequests: [String: AgentPermissionRequest] = [:]

    // Accumulated output state — protected by `lock`.
    private let lock = NSLock()
    private var accumulatedText: String = ""
    private var emittedToolErrors: [String] = []
    private var reportedResult = false

    init(
        contactHandle: String,
        vaultPath: String,
        replyChannel: any DriverChannelReplying,
        autoApproveModifications: Bool,
        replyPrefix: String? = nil
    ) {
        self.contactHandle = contactHandle
        self.vaultPath = vaultPath
        self.replyChannel = replyChannel
        self.autoApproveModifications = autoApproveModifications
        self.replyPrefix = replyPrefix
    }

    // MARK: - Accumulation

    func onThinkingDelta(thought: String) {
        // We deliberately drop thinking text — the user gets the final
        // answer only. Thinking is a private audit trail stored in
        // session_store via the agent loop.
    }

    func onTextDelta(delta: String) {
        lock.lock()
        accumulatedText.append(delta)
        lock.unlock()
    }

    func onToolInputDelta(index: UInt32, partialJson: String) {}

    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        logger.info("Tool started: \(name, privacy: .public)")
    }

    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {
        if isError {
            lock.lock()
            emittedToolErrors.append(result.prefix(200).description)
            lock.unlock()
        }
    }

    func onSubagentSpawned(agentId: String, role: String) {}

    func onPermissionRequired(
        permissionId: String,
        toolName: String,
        inputJson: String,
        riskLevel: String
    ) {
        let request = AgentPermissionRequest(
            id: permissionId,
            toolName: toolName,
            inputJson: inputJson,
            riskLevel: AgentRuntimeRiskLevel(rustValue: riskLevel),
            description: "Tool '\(toolName)' requires approval."
        )

        permissionLock.lock()
        pendingPermissionRequests[permissionId] = request
        permissionLock.unlock()

        logger.info("Permission required for \(toolName, privacy: .public) — category=\(request.approvalReason, privacy: .public)")
    }

    func onContextCompacting(currentTokens: UInt32) {}
    func onContextCompacted(newMessageCount: UInt32) {}
    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {}

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        lock.lock()
        guard !reportedResult else {
            lock.unlock()
            return
        }
        reportedResult = true
        lock.unlock()

        let reply: String = {
            lock.lock()
            defer { lock.unlock() }
            return accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let contactHandle = self.contactHandle
        let vaultPath = self.vaultPath
        let replyChannel = self.replyChannel
        let replyPrefix = self.replyPrefix
        let channelID = replyChannel.channelID

        Task.detached {
            await DriverChannelReplyTransport.sendChunkedReply(
                reply,
                to: contactHandle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                over: replyChannel,
                onSendError: { chunkIndex, chunkCount, errorDescription in
                    await MainActor.run {
                        Logger(subsystem: "com.epistemos", category: "IMessageReplyDelegate")
                            .warning("\(channelID, privacy: .public) send chunk \(chunkIndex)/\(chunkCount) failed: \(errorDescription, privacy: .public)")
                    }
                }
            )
        }
    }

    func onError(message: String) {
        lock.lock()
        guard !reportedResult else {
            lock.unlock()
            return
        }
        reportedResult = true
        lock.unlock()
        logger.error("Agent error: \(message, privacy: .public)")
        let contactHandle = self.contactHandle
        let vaultPath = self.vaultPath
        let replyChannel = self.replyChannel
        let replyPrefix = self.replyPrefix
        let channelID = replyChannel.channelID
        let errorBody = "Sorry, I hit an error: \(message)"
        Task.detached {
            await DriverChannelReplyTransport.sendChunkedReply(
                errorBody,
                to: contactHandle,
                vaultPath: vaultPath,
                replyPrefix: replyPrefix,
                over: replyChannel,
                onSendError: { chunkIndex, chunkCount, errorDescription in
                    await MainActor.run {
                        Logger(subsystem: "com.epistemos", category: "IMessageReplyDelegate")
                            .warning("\(channelID, privacy: .public) error send chunk \(chunkIndex)/\(chunkCount) failed: \(errorDescription, privacy: .public)")
                    }
                }
            )
        }
    }

    // MARK: - Computer action / permissions

    func executeComputerAction(actionJson: String) -> String {
        // The driver runs autonomously — no computer use allowed.
        "{\"success\":false,\"error\":\"computer use disabled in iMessage driver\"}"
    }

    func waitForPermission(permissionId: String) -> Bool {
        permissionLock.lock()
        let request = pendingPermissionRequests.removeValue(forKey: permissionId)
        permissionLock.unlock()

        guard let request else {
            return false
        }

        switch request.permissionCategory {
        case .genericRead:
            return true
        case .localDataRead, .localDataWrite, .destructive:
            logger.warning("Denying \(request.toolName, privacy: .public) because it requires on-device human approval.")
            return false
        case .modification:
            return autoApproveModifications
        }
    }

    func askUserQuestion(questionJson: String) -> String {
        // The driver cannot ask interactive questions.
        "{\"response\":\"\",\"choice_index\":null}"
    }

    func perceiveApp(appName: String, depth: String) -> String {
        "{\"elements\":[],\"error\":\"perceive disabled in iMessage driver\"}"
    }

    func interactWithApp(actionJson: String) -> String {
        "{\"success\":false,\"error\":\"interact disabled in iMessage driver\"}"
    }

    func startScreenWatch(watchJson: String) -> String {
        "{\"triggered\":false,\"error\":\"screen_watch disabled in iMessage driver\"}"
    }

    func manageSsmState(actionJson: String) -> String {
        "{\"success\":false,\"error\":\"ssm_resume disabled in iMessage driver\"}"
    }

    func generateConstrained(prompt: String, grammarJson: String) -> String {
        "{\"output\":\"\",\"error\":\"constrained_generate disabled in iMessage driver\"}"
    }

    func generateImage(prompt: String, aspectRatio: String) -> String {
        // The iMessage driver is reply-isolated and must not escalate to
        // MLX Flux or any cloud image provider mid-conversation. This is
        // an explicit, canonical denial so no fake success can surface.
        "{\"error\":\"image_generate disabled in iMessage driver — reply isolation forbids mid-conversation media escalation\"}"
    }

    func triggerNightbrainJob(jobType: String, priority: String) -> String {
        "{\"status\":\"skipped\",\"error\":\"nightbrain trigger disabled in iMessage driver\"}"
    }

    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String {
        "{\"success\":false,\"error\":\"inline_partner disabled in iMessage driver\"}"
    }
}
