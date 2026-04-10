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
    private let autoApproveModifications: Bool
    private let maxCharsPerMessage: Int = 3_500
    /// Prefix prepended to every chunk before send. Used by group routing
    /// to label which model produced which reply (e.g. "[qwen-2b] ...").
    private let replyPrefix: String?

    // Accumulated output state — protected by `lock`.
    private let lock = NSLock()
    private var accumulatedText: String = ""
    private var emittedToolErrors: [String] = []
    private var reportedResult = false

    init(
        contactHandle: String,
        vaultPath: String,
        autoApproveModifications: Bool,
        replyPrefix: String? = nil
    ) {
        self.contactHandle = contactHandle
        self.vaultPath = vaultPath
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
        // The driver never prompts the human — it's running on their behalf
        // over iMessage. Pre-approve based on the contact's auto_approve
        // flag. `waitForPermission` is where the ACTUAL decision happens.
        logger.info("Permission required for \(toolName, privacy: .public) — auto_approve=\(self.autoApproveModifications)")
    }

    func onContextCompacting(currentTokens: UInt32) {}
    func onContextCompacted(newMessageCount: UInt32) {}
    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {}

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        guard !reportedResult else { return }
        reportedResult = true

        let reply: String = {
            lock.lock()
            defer { lock.unlock() }
            let trimmed = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "(no response)"
            }
            let cleaned = Self.stripMarkdown(trimmed)
            if let prefix = replyPrefix, !prefix.isEmpty {
                return prefix + cleaned
            }
            return cleaned
        }()

        // Chunk long replies so iMessage doesn't refuse to deliver.
        let chunks = Self.chunk(reply, maxLength: maxCharsPerMessage)
        let contactHandle = self.contactHandle
        let vaultPath = self.vaultPath

        Task.detached {
            for (idx, chunk) in chunks.enumerated() {
                let payload: [String: Any] = [
                    "action": "send",
                    "to": contactHandle,
                    "message": chunk,
                ]
                guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                      let jsonStr = String(data: jsonData, encoding: .utf8) else {
                    continue
                }
                do {
                    #if canImport(agent_coreFFI)
                    let result = try await executeToolCall(
                        vaultPath: vaultPath,
                        tier: "agent",
                        toolName: "imessage",
                        inputJson: jsonStr
                    )
                    if !result.success {
                        // Log and continue — failing partway is better than
                        // silently dropping the whole reply.
                        await MainActor.run {
                            Logger(subsystem: "com.epistemos", category: "IMessageReplyDelegate")
                                .warning("imessage send chunk \(idx + 1)/\(chunks.count) failed: \(result.error ?? "unknown", privacy: .public)")
                        }
                    }
                    #endif
                } catch {
                    await MainActor.run {
                        Logger(subsystem: "com.epistemos", category: "IMessageReplyDelegate")
                            .error("imessage send failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
                // Small inter-chunk delay so the messages arrive in order
                // and don't trigger Messages.app rate limiting.
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func onError(message: String) {
        guard !reportedResult else { return }
        reportedResult = true
        logger.error("Agent error: \(message, privacy: .public)")
        let contactHandle = self.contactHandle
        let vaultPath = self.vaultPath
        let prefix = self.replyPrefix ?? ""
        let errorBody = "Sorry, I hit an error: \(message)"
        Task.detached {
            let payload: [String: Any] = [
                "action": "send",
                "to": contactHandle,
                "message": prefix + errorBody,
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                #if canImport(agent_coreFFI)
                _ = try? await executeToolCall(
                    vaultPath: vaultPath,
                    tier: "agent",
                    toolName: "imessage",
                    inputJson: jsonStr
                )
                #endif
            }
        }
    }

    // MARK: - Computer action / permissions

    func executeComputerAction(actionJson: String) -> String {
        // The driver runs autonomously — no computer use allowed.
        "{\"success\":false,\"error\":\"computer use disabled in iMessage driver\"}"
    }

    func waitForPermission(permissionId: String) -> Bool {
        // Auto-approve all tools whose tier is already allowed; fall back
        // to the contact's auto_approve flag for anything that requires
        // explicit approval.
        return autoApproveModifications
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

    func triggerNightbrainJob(jobType: String, priority: String) -> String {
        "{\"status\":\"skipped\",\"error\":\"nightbrain trigger disabled in iMessage driver\"}"
    }

    // MARK: - Helpers

    /// Break a long reply into iMessage-safe chunks at paragraph boundaries.
    private static func chunk(_ text: String, maxLength: Int) -> [String] {
        LocalReplyAccumulator.chunk(text, maxLength: maxLength)
    }

    /// Strip markdown emphasis / headings / code fences so the reply reads
    /// cleanly in the iMessage conversation view.
    private static func stripMarkdown(_ text: String) -> String {
        LocalReplyAccumulator.stripMarkdown(text)
    }
}
