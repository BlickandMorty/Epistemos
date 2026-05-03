// Phase5Bridge.swift
//
// Bridges the Phase 5 Inference Specialties (manage_ssm_state,
// constrained_generate) from the Rust agent_core FFI to the existing
// Swift services (SSMStateService, ConstrainedDecodingService).
//
// All public methods are @MainActor — the StreamingDelegate hops the
// FFI thread onto the main actor via a Task + DispatchSemaphore so the
// Rust handler can call this synchronously.

import AppKit
import Foundation
import os

@MainActor
final class Phase5Bridge {
    typealias SSMStateServiceProvider = @MainActor () -> SSMStateService?

    static let shared = Phase5Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase5Bridge")
    private let ssmStateServiceProvider: SSMStateServiceProvider
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var ssmToolCallSequence: UInt64 = 0

    init(
        ssmStateServiceProvider: @escaping SSMStateServiceProvider = {
            AppBootstrap.shared?.ssmStateService
        },
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.ssmStateServiceProvider = ssmStateServiceProvider
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    // MARK: - Specialty C1: SSM State Management

    /// Decode `actionJson` and route to `SSMStateService`. Supports the
    /// non-cache-touching actions list/prune/total_size. Save and load
    /// require live MLX cache access (the cache is owned by the model
    /// container's generation context) and are intentionally NOT exposed
    /// here — the chat path saves cache snapshots automatically as part
    /// of the inference loop, not via agent FFI.
    func manageSsmState(actionJson: String) async -> String {
        let toolCallID = nextSsmToolCallID()
        let parsedRequest = parseSsmStateRequest(actionJson: actionJson)
        recordSsmStateEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: parsedRequest
        )

        guard let svc = ssmStateServiceProvider() else {
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "bootstrap_unavailable",
                errorMessage: "SSM action could not be started."
            )
            return errorJson("AppBootstrap is not initialised")
        }
        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "invalid_action_json",
                errorMessage: "SSM action was not accepted."
            )
            return errorJson("invalid SSM action JSON")
        }

        let action = (payload["action"] as? String)?.lowercased() ?? "list"
        let modelId = (payload["model_id"] as? String) ?? "*"

        switch action {
        case "list":
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest
            )
            let start = Date()
            let states = svc.listStates(modelId: modelId)
            let entries = states.map { entry -> [String: Any] in
                [
                    "url": entry.url.path,
                    "session_id": entry.sessionId,
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                ]
            }
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallCompleted,
                status: .completed,
                request: parsedRequest,
                result: .list(count: states.count),
                durationMs: durationMilliseconds(since: start)
            )
            return jsonString([
                "success": true,
                "action": "list",
                "model_id": modelId,
                "count": states.count,
                "states": entries,
            ])
        case "prune":
            let keepCount = boundedKeepCount(payload["keep_count"] as? Int)
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest.withKeepCount(keepCount)
            )
            let start = Date()
            let removed = svc.pruneStates(modelId: modelId, keepCount: keepCount)
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallCompleted,
                status: .completed,
                request: parsedRequest.withKeepCount(keepCount),
                result: .prune(removed: removed, kept: keepCount),
                durationMs: durationMilliseconds(since: start)
            )
            return jsonString([
                "success": true,
                "action": "prune",
                "model_id": modelId,
                "removed": removed,
                "kept": keepCount,
            ])
        case "total_size":
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest
            )
            let start = Date()
            let bytes = svc.totalDiskUsage()
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallCompleted,
                status: .completed,
                request: parsedRequest,
                result: .totalSize(bytes: bytes),
                durationMs: durationMilliseconds(since: start)
            )
            return jsonString([
                "success": true,
                "action": "total_size",
                "bytes": bytes,
            ])
        case "save", "load":
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "live_cache_action_unavailable",
                errorMessage: "SSM action was not accepted."
            )
            return errorJson(
                "ssm_resume save/load are not callable from the agent FFI — they require live MLX cache access. Use list/prune/total_size instead, or save the state from the chat session that owns the cache."
            )
        default:
            recordSsmStateEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "unsupported_action",
                errorMessage: "SSM action was not accepted."
            )
            return errorJson("unknown SSM action: \(action)")
        }
    }

    // MARK: - Specialty C2: Constrained Generation

    /// Decode `grammarJson` and run constrained decoding via
    /// `ConstrainedDecodingService`. The grammar can be one of:
    /// - `{ "grammar": "tool_call", "tool_name": String, "argument_schema": Object }`
    /// - `{ "grammar": "planning", "tool_schemas": [Object] }`
    /// - `{ "grammar": "custom", "custom_ebnf": String }` — currently unsupported
    func generateConstrained(prompt: String, grammarJson: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else {
            return errorJson("AppBootstrap is not initialised")
        }
        let svc = bootstrap.constrainedDecoding
        guard svc.isAvailable else {
            return errorJson("constrained decoding generator not registered (MLX backend missing)")
        }
        guard let data = grammarJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return errorJson("invalid grammar JSON")
        }
        let kind = (payload["grammar"] as? String)?.lowercased() ?? "tool_call"
        let maxTokens = (payload["max_tokens"] as? Int) ?? 512

        do {
            switch kind {
            case "tool_call":
                guard let toolName = payload["tool_name"] as? String else {
                    return errorJson("tool_call grammar requires 'tool_name'")
                }
                let schema = (payload["argument_schema"] as? [String: Any]) ?? [:]
                let output = try await svc.generateConstrainedToolCall(
                    prompt: prompt,
                    systemPrompt: nil,
                    toolName: toolName,
                    argumentSchema: schema,
                    maxTokens: maxTokens
                )
                return jsonString([
                    "success": true,
                    "grammar": "tool_call",
                    "tool_name": toolName,
                    "output": output ?? "",
                ])
            case "planning":
                let schemas = (payload["tool_schemas"] as? [[String: Any]]) ?? []
                let output = try await svc.generateConstrainedPlan(
                    prompt: prompt,
                    systemPrompt: nil,
                    toolSchemas: schemas,
                    maxTokens: maxTokens
                )
                return jsonString([
                    "success": true,
                    "grammar": "planning",
                    "output": output ?? "",
                    "tool_count": schemas.count,
                ])
            case "custom":
                return errorJson("custom EBNF grammars are not yet wired through the Phase5Bridge")
            default:
                return errorJson("unknown grammar kind: \(kind)")
            }
        } catch {
            return errorJson("constrained decoding failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private struct SSMStateRequest {
        let actionClass: String
        let modelScope: String
        let keepCount: Int?

        func withKeepCount(_ keepCount: Int) -> Self {
            Self(actionClass: actionClass, modelScope: modelScope, keepCount: keepCount)
        }
    }

    private enum SSMStateResult {
        case list(count: Int)
        case prune(removed: Int, kept: Int)
        case totalSize(bytes: Int)
    }

    private func nextSsmToolCallID() -> String {
        let sequence = ssmToolCallSequence
        if ssmToolCallSequence < UInt64.max {
            ssmToolCallSequence += 1
        }
        return "phase5-ssm-state-\(sequence)"
    }

    private func parseSsmStateRequest(actionJson: String) -> SSMStateRequest {
        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return SSMStateRequest(actionClass: "invalid_json", modelScope: "unknown", keepCount: nil)
        }

        let action = boundedSsmActionClass(payload["action"] as? String)
        let modelScope = modelScope(payload["model_id"] as? String)
        return SSMStateRequest(
            actionClass: action,
            modelScope: modelScope,
            keepCount: (payload["keep_count"] as? Int).map(boundedKeepCount)
        )
    }

    private func boundedSsmActionClass(_ action: String?) -> String {
        switch action?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "list":
            return "list"
        case "prune":
            return "prune"
        case "total_size":
            return "total_size"
        case "save":
            return "save"
        case "load":
            return "load"
        case nil, "":
            return "list"
        default:
            return "unknown"
        }
    }

    private func modelScope(_ modelID: String?) -> String {
        guard let modelID,
              !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "wildcard"
        }
        return modelID == "*" ? "wildcard" : "specific"
    }

    private func boundedKeepCount(_ keepCount: Int?) -> Int {
        min(max(keepCount ?? 5, 0), 100)
    }

    private func durationMilliseconds(since start: Date) -> UInt64? {
        let elapsed = Int(Date().timeIntervalSince(start) * 1_000)
        return elapsed >= 0 ? UInt64(elapsed) : nil
    }

    private func recordSsmStateEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: SSMStateRequest,
        result: SSMStateResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "phase5-ssm-state",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "phase5-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "ssm_state_manage",
            argumentsJSON: ssmStateArgumentsJSON(request),
            resultJSON: result.map(ssmStateResultJSON),
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: ssmStateMetadata(request: request, result: result, failureClass: failureClass)
        )
    }

    private func ssmStateArgumentsJSON(_ request: SSMStateRequest) -> String {
        var payload: [String: Any] = [
            "action_class": request.actionClass,
            "model_scope": request.modelScope,
        ]
        if let keepCount = request.keepCount {
            payload["keep_count"] = keepCount
        }
        return jsonString(payload)
    }

    private func ssmStateResultJSON(_ result: SSMStateResult) -> String {
        switch result {
        case .list(let count):
            return jsonString([
                "success": true,
                "action_class": "list",
                "count": count,
            ])
        case .prune(let removed, let kept):
            return jsonString([
                "success": true,
                "action_class": "prune",
                "removed": removed,
                "kept": kept,
            ])
        case .totalSize(let bytes):
            return jsonString([
                "success": true,
                "action_class": "total_size",
                "bytes": bytes,
            ])
        }
    }

    private func ssmStateMetadata(
        request: SSMStateRequest,
        result: SSMStateResult?,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "phase5_bridge",
            "surface": "ssm_state",
            "action_class": request.actionClass,
            "model_scope": request.modelScope,
        ]
        if result != nil {
            metadata["result"] = "completed"
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
    }

    private func errorJson(_ message: String) -> String {
        jsonString(["error": message, "success": false])
    }

    private func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"json_encode_failed\"}"
        }
        return string
    }
}
