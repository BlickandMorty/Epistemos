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
    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "Hooks")
    static let shared = HookRegistry()

    private var hooks: [any AgentHook] = []

    /// Register a hook. Later registrations fire after earlier ones (pipeline order).
    func register(_ hook: any AgentHook) {
        hooks.append(hook)
        Self.log.info("HookRegistry: registered hook '\(hook.hookId)'")
    }

    /// Unregister a hook by ID.
    func unregister(hookId: String) {
        hooks.removeAll { $0.hookId == hookId }
        Self.log.info("HookRegistry: unregistered hook '\(hookId)'")
    }

    /// Fire beforePromptBuild — chains through all hooks.
    func fireBeforePromptBuild(context: PromptContext) async -> PromptContext {
        var ctx = context
        for hook in hooks {
            ctx = await hook.beforePromptBuild(context: ctx)
        }
        return ctx
    }

    /// Fire beforeToolCall — any hook returning nil cancels the call.
    func fireBeforeToolCall(call: HookToolCall) async -> HookToolCall? {
        var current: HookToolCall? = call
        for hook in hooks {
            guard let c = current else { return nil }
            current = await hook.beforeToolCall(call: c)
        }
        return current
    }

    /// Fire afterToolCall — chains through all hooks.
    func fireAfterToolCall(call: HookToolCall, result: HookToolResult) async -> HookToolResult {
        var r = result
        for hook in hooks {
            r = await hook.afterToolCall(call: call, result: r)
        }
        return r
    }

    /// Fire afterSessionEnd — all hooks fire (no chaining).
    func fireAfterSessionEnd(sessionId: String, turns: Int, success: Bool) async {
        for hook in hooks {
            await hook.afterSessionEnd(sessionId: sessionId, turns: turns, success: success)
        }
    }

    /// Current hook count (for diagnostics).
    var count: Int { hooks.count }
}
