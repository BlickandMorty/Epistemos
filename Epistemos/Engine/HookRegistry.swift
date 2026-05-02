import Foundation
import os

// MARK: - HookRegistry
// Event-driven plugin intercept system inspired by OpenClaw's hook architecture.
// Enables skills, plugins, and services to intercept and modify agent behavior
// without forking core code.
//
// Hook points:
//   beforePromptBuild — inject context into system prompt
//   beforeToolCall — intercept/modify/cancel tool calls
//   afterToolCall — observe/modify tool results
//   afterSessionEnd — post-processing (skill evolution, analytics)

/// Context passed to hooks before prompt construction.
struct PromptContext: Sendable {
    var systemPromptSuffix: String = ""
    var additionalToolDescriptions: [String] = []
    var injectedFacts: [String] = []
}

/// Represents a tool call that hooks can intercept.
struct HookToolCall: Sendable {
    let id: String
    let name: String
    let argsJson: String
}

/// Represents a tool result that hooks can modify.
struct HookToolResult: Sendable {
    let toolCallId: String
    let content: String
    let isError: Bool
}

/// Protocol for agent lifecycle hooks.
/// Implement only the methods you care about — defaults are no-ops.
protocol AgentHook: Sendable {
    nonisolated var hookId: String { get }

    /// Called before the system prompt is built. Inject context, facts, or tool descriptions.
    func beforePromptBuild(context: PromptContext) async -> PromptContext

    /// Called before each tool execution. Return nil to cancel the call.
    func beforeToolCall(call: HookToolCall) async -> HookToolCall?

    /// Called after each tool execution. Can modify the result.
    func afterToolCall(call: HookToolCall, result: HookToolResult) async -> HookToolResult

    /// Called after agent session completes. For analytics, skill evolution, etc.
    func afterSessionEnd(sessionId: String, turns: Int, success: Bool) async
}

/// Default implementations — hooks only need to override what they use.
extension AgentHook {
    func beforePromptBuild(context: PromptContext) async -> PromptContext { context }
    func beforeToolCall(call: HookToolCall) async -> HookToolCall? { call }
    func afterToolCall(call: HookToolCall, result: HookToolResult) async -> HookToolResult { result }
    func afterSessionEnd(sessionId: String, turns: Int, success: Bool) async {}
}

/// Central registry that manages and fires hooks.
actor HookRegistry {
    typealias PersistAgentEvent = @Sendable (AgentProvenanceEvent) -> Bool
    typealias NowMilliseconds = @Sendable () -> Int64

    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "Hooks")
    static let shared = HookRegistry()

    private var hooks: [any AgentHook] = []
    private var sequenceByRunID: [String: UInt64] = [:]
    private let nowMilliseconds: NowMilliseconds
    private let persistAgentEvent: PersistAgentEvent

    init(
        nowMilliseconds: @escaping NowMilliseconds = {
            let milliseconds = Date().timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite else { return 0 }
            return Int64(milliseconds.rounded())
        },
        persistAgentEvent: @escaping PersistAgentEvent = { event in
            EventStore.shared?.saveAgentEvent(event) ?? false
        }
    ) {
        self.nowMilliseconds = nowMilliseconds
        self.persistAgentEvent = persistAgentEvent
    }

    /// Register a hook. Later registrations fire after earlier ones (pipeline order).
    func register(_ hook: any AgentHook) {
        hooks.append(hook)
        recordHookEvent(
            kind: .hookRegistered,
            hookID: hook.hookId,
            hookPoint: "registration"
        )
        Self.log.info("HookRegistry: registered hook '\(hook.hookId)'")
    }

    /// Unregister a hook by ID.
    func unregister(hookId: String) {
        hooks.removeAll { $0.hookId == hookId }
        Self.log.info("HookRegistry: unregistered hook '\(hookId)'")
    }

    /// Fire beforePromptBuild — chains through all hooks.
    func fireBeforePromptBuild(context: PromptContext, runID: String? = nil) async -> PromptContext {
        var ctx = context
        for hook in hooks {
            recordHookEvent(
                kind: .hookFired,
                hookID: hook.hookId,
                hookPoint: "before_prompt_build",
                runID: runID
            )
            ctx = await hook.beforePromptBuild(context: ctx)
            recordHookEvent(
                kind: .hookCompleted,
                hookID: hook.hookId,
                hookPoint: "before_prompt_build",
                runID: runID,
                outcome: "completed"
            )
        }
        return ctx
    }

    /// Fire beforeToolCall — any hook returning nil cancels the call.
    func fireBeforeToolCall(call: HookToolCall, runID: String? = nil) async -> HookToolCall? {
        var current: HookToolCall? = call
        for hook in hooks {
            guard let c = current else { return nil }
            recordHookEvent(
                kind: .hookFired,
                hookID: hook.hookId,
                hookPoint: "before_tool_call",
                runID: runID,
                metadata: [
                    "tool_call_id": c.id,
                    "tool_name": c.name,
                ]
            )
            current = await hook.beforeToolCall(call: c)
            recordHookEvent(
                kind: .hookCompleted,
                hookID: hook.hookId,
                hookPoint: "before_tool_call",
                runID: runID,
                outcome: current == nil ? "cancelled" : "completed",
                metadata: [
                    "tool_call_id": c.id,
                    "tool_name": c.name,
                ]
            )
        }
        return current
    }

    /// Fire afterToolCall — chains through all hooks.
    func fireAfterToolCall(
        call: HookToolCall,
        result: HookToolResult,
        runID: String? = nil
    ) async -> HookToolResult {
        var r = result
        for hook in hooks {
            recordHookEvent(
                kind: .hookFired,
                hookID: hook.hookId,
                hookPoint: "after_tool_call",
                runID: runID,
                metadata: [
                    "tool_call_id": call.id,
                    "tool_name": call.name,
                    "is_error": String(r.isError),
                ]
            )
            r = await hook.afterToolCall(call: call, result: r)
            recordHookEvent(
                kind: .hookCompleted,
                hookID: hook.hookId,
                hookPoint: "after_tool_call",
                runID: runID,
                outcome: "completed",
                metadata: [
                    "tool_call_id": call.id,
                    "tool_name": call.name,
                    "is_error": String(r.isError),
                ]
            )
        }
        return r
    }

    /// Fire afterSessionEnd — all hooks fire (no chaining).
    func fireAfterSessionEnd(
        sessionId: String,
        turns: Int,
        success: Bool,
        runID: String? = nil
    ) async {
        let resolvedRunID = normalizedRunID(runID) ?? normalizedRunID(sessionId)
        for hook in hooks {
            recordHookEvent(
                kind: .hookFired,
                hookID: hook.hookId,
                hookPoint: "after_session_end",
                runID: resolvedRunID,
                metadata: [
                    "session_id": sessionId,
                    "turns": String(turns),
                    "success": String(success),
                ]
            )
            await hook.afterSessionEnd(sessionId: sessionId, turns: turns, success: success)
            recordHookEvent(
                kind: .hookCompleted,
                hookID: hook.hookId,
                hookPoint: "after_session_end",
                runID: resolvedRunID,
                outcome: success ? "completed" : "failed",
                metadata: [
                    "session_id": sessionId,
                    "turns": String(turns),
                    "success": String(success),
                ]
            )
        }
    }

    /// Current hook count (for diagnostics).
    var count: Int { hooks.count }

    @discardableResult
    private func recordHookEvent(
        kind: AgentProvenanceEventKind,
        hookID: String,
        hookPoint rawHookPoint: String,
        runID: String? = nil,
        outcome: String? = nil,
        metadata extraMetadata: [String: String] = [:]
    ) -> Bool {
        let hookID = hookID.trimmingCharacters(in: .whitespacesAndNewlines)
        let hookPoint = rawHookPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hookID.isEmpty, !hookPoint.isEmpty else { return false }

        let resolvedRunID = normalizedRunID(runID) ?? "hook-registry:\(hookPoint)"
        let sequence = sequenceByRunID[resolvedRunID] ?? 0
        guard sequence < UInt64.max else { return false }
        sequenceByRunID[resolvedRunID] = sequence + 1

        var metadata = [
            "source": "hook_registry",
            "hook_id": hookID,
            "hook_point": hookPoint,
        ]
        if let outcome = normalizedRunID(outcome) {
            metadata["outcome"] = outcome
        }
        for (key, value) in extraMetadata {
            let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            metadata[key] = value
        }

        let event = AgentProvenanceEvent(
            eventID: "agent-event:\(resolvedRunID):hook:\(kind.rawValue):\(hookID):\(hookPoint):\(sequence)",
            runID: resolvedRunID,
            traceID: nil,
            sequence: sequence,
            kind: kind,
            actor: .system,
            occurredAtMs: nowMilliseconds(),
            tool: nil,
            metadata: metadata
        )
        return persistAgentEvent(event)
    }

    private func normalizedRunID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
