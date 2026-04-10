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
    static let shared = Phase5Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase5Bridge")

    private init() {}

    // MARK: - Specialty C1: SSM State Management

    /// Decode `actionJson` and route to `SSMStateService`. Supports the
    /// non-cache-touching actions list/prune/total_size. Save and load
    /// require live MLX cache access (the cache is owned by the model
    /// container's generation context) and are intentionally NOT exposed
    /// here — the chat path saves cache snapshots automatically as part
    /// of the inference loop, not via agent FFI.
    func manageSsmState(actionJson: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else {
            return errorJson("AppBootstrap is not initialised")
        }
        let svc = bootstrap.ssmStateService
        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return errorJson("invalid SSM action JSON")
        }

        let action = (payload["action"] as? String)?.lowercased() ?? "list"
        let modelId = (payload["model_id"] as? String) ?? "*"

        switch action {
        case "list":
            let states = svc.listStates(modelId: modelId)
            let entries = states.map { entry -> [String: Any] in
                [
                    "url": entry.url.path,
                    "session_id": entry.sessionId,
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                ]
            }
            return jsonString([
                "success": true,
                "action": "list",
                "model_id": modelId,
                "count": states.count,
                "states": entries,
            ])
        case "prune":
            let keepCount = (payload["keep_count"] as? Int) ?? 5
            let removed = svc.pruneStates(modelId: modelId, keepCount: keepCount)
            return jsonString([
                "success": true,
                "action": "prune",
                "model_id": modelId,
                "removed": removed,
                "kept": keepCount,
            ])
        case "total_size":
            let bytes = svc.totalDiskUsage()
            return jsonString([
                "success": true,
                "action": "total_size",
                "bytes": bytes,
            ])
        case "save", "load":
            return errorJson(
                "ssm_resume save/load are not callable from the agent FFI — they require live MLX cache access. Use list/prune/total_size instead, or save the state from the chat session that owns the cache."
            )
        default:
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
