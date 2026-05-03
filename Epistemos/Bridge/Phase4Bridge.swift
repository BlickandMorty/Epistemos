#if !EPISTEMOS_APP_STORE
// Phase4Bridge.swift
//
// Bridges the Phase 4 macOS Native Specialties (perceive, interact,
// screen_watch) from the Rust agent_core FFI to the existing
// `Screen2AXFusion`, `AXorcistBridge`, and `ComputerUseBridge` services.
//
// All public methods are @MainActor — the StreamingDelegate marshals the
// FFI thread onto the main actor via a Task + DispatchSemaphore so the
// Rust handler can call this synchronously without violating Swift 6
// strict concurrency.

import AppKit
import AXorcist
import Foundation
import os

@MainActor
final class Phase4Bridge {
    typealias PerceptionProvider = @MainActor (String) async -> PerceptionResult?

    static let shared = Phase4Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase4Bridge")
    private let perceptionProvider: PerceptionProvider
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var perceiveToolCallSequence: UInt64 = 0

    init(
        perceptionProvider: @escaping PerceptionProvider = { appName in
            guard let fusion = AppBootstrap.shared?.screen2AXFusion else {
                return nil
            }
            return await fusion.perceive(appName: appName)
        },
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.perceptionProvider = perceptionProvider
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    // MARK: - Specialty A1: perceive

    /// Perceive an app via Screen2AXFusion. `depth` is one of:
    /// - "fast"     — AX tree only (no OCR enrichment)
    /// - "enriched" — AX tree + Apple Vision OCR fallback (default)
    /// - "full"     — AX + OCR + VLM (currently identical to enriched)
    /// Returns JSON of the form
    /// `{ elements, screenshot_path?, latency_ms, method, error? }`.
    func perceive(appName: String, depth: String) async -> String {
        let toolCallID = nextPerceiveToolCallID()
        let request = Phase4PerceiveRequest(
            appScope: appScope(appName),
            depthClass: perceiveDepthClass(depth)
        )
        recordPhase4PerceiveEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: request
        )
        recordPhase4PerceiveEvent(
            toolCallID: toolCallID,
            kind: .toolCallStarted,
            status: .started,
            request: request
        )

        let start = Date()
        guard let result = await perceptionProvider(appName) else {
            recordPhase4PerceiveEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: request,
                durationMs: durationMilliseconds(since: start),
                failureClass: "perception_unavailable",
                errorMessage: "Phase4 perceive could not start."
            )
            return errorJson("Screen2AXFusion is not initialised")
        }

        let payload: [String: Any] = [
            "method": String(describing: result.method),
            "interactive_count": result.interactiveCount,
            "latency_ms": result.latencyMs,
            "depth": depth,
            "ax_tree_json": result.axTreeJson,
            "ocr_count": result.ocrTexts.count,
        ]
        recordPhase4PerceiveEvent(
            toolCallID: toolCallID,
            kind: .toolCallCompleted,
            status: .completed,
            request: request,
            result: result,
            durationMs: durationMilliseconds(since: start)
        )
        return jsonString(payload)
    }

    // MARK: - Specialty A2: interact

    /// Interact with an app. `actionJson` is a JSON object with the shape
    /// `{ "app_name": String?, "action": String, "target"?: String, "value"?: String, "x"?: Int, "y"?: Int }`.
    /// We delegate primitive screen actions (click, type, scroll) to the
    /// existing `ComputerUseBridge`, and AX-targeted actions to AXorcist.
    func interact(actionJson: String) async -> String {
        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return errorJson("invalid action JSON")
        }
        let action = (payload["action"] as? String)?.lowercased() ?? ""
        let bundleID = payload["bundle_id"] as? String

        switch action {
        case "click", "screenshot", "type_text", "scroll", "keypress":
            // Forward straight to ComputerUseBridge — it knows the
            // pixel-coordinate variants of these actions.
            return await ComputerUseBridge.shared.execute(actionJSON: actionJson)
        case "press_target", "press":
            // AX-fuzzy press by element title.
            guard let target = payload["target"] as? String else {
                return errorJson("press_target requires 'target'")
            }
            guard let bundleID else {
                return errorJson("press_target requires 'bundle_id'")
            }
            let response = AXorcistBridge.shared.pressElement(bundleID: bundleID, title: target)
            let (success, errorMessage) = Self.unpack(response)
            return jsonString([
                "success": success,
                "action": "press_target",
                "target": target,
                "bundle_id": bundleID,
                "error": errorMessage as Any,
            ])
        case "set_value", "type_target":
            guard let value = payload["value"] as? String else {
                return errorJson("set_value requires 'value'")
            }
            guard let bundleID else {
                return errorJson("set_value requires 'bundle_id'")
            }
            let response = AXorcistBridge.shared.setFocusedValue(value, bundleID: bundleID)
            let (success, errorMessage) = Self.unpack(response)
            return jsonString([
                "success": success,
                "action": "set_value",
                "bundle_id": bundleID,
                "error": errorMessage as Any,
            ])
        default:
            return errorJson("unknown interact action: \(action)")
        }
    }

    /// Translate an AXorcist `AXResponse` enum into a (success, error) pair
    /// suitable for the bridge's JSON envelope.
    private static func unpack(_ response: AXResponse) -> (Bool, Any) {
        switch response {
        case .success:
            return (true, NSNull())
        case let .error(message, _, _):
            return (false, message)
        }
    }

    // MARK: - Specialty A3: screen_watch

    /// Block until a screen / file / AX condition triggers, or until the
    /// supplied timeout fires. Modes:
    /// - "ax_present"   — wait for an element matching `target` (title) to appear in `bundle_id`
    /// - "file_exists"  — poll the filesystem for `target`
    /// - "file_changed" — record mtime, poll until it changes
    /// - "timeout_ms"   — minimum wait, used by callers as a sleep primitive
    func startScreenWatch(watchJson: String) async -> String {
        guard let data = watchJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return errorJson("invalid watch JSON")
        }
        let mode = (payload["mode"] as? String)?.lowercased() ?? "timeout_ms"
        let timeoutSecs = (payload["timeout_secs"] as? Int) ?? 30
        let pollIntervalMs = (payload["poll_interval_ms"] as? Int) ?? 250
        let target = payload["target"] as? String ?? ""

        let start = Date()
        let deadline = start.addingTimeInterval(TimeInterval(timeoutSecs))

        while Date() < deadline {
            if Task.isCancelled { break }
            switch mode {
            case "ax_present":
                if let bundleID = payload["bundle_id"] as? String, !target.isEmpty {
                    let response = AXorcistBridge.shared.findElements(
                        bundleID: bundleID,
                        title: target
                    )
                    if case .success(let payload, _) = response, payload != nil {
                        return jsonString([
                            "triggered": true,
                            "mode": mode,
                            "elapsed_ms": elapsedMs(since: start),
                        ])
                    }
                }
            case "file_exists":
                if !target.isEmpty, FileManager.default.fileExists(atPath: target) {
                    return jsonString([
                        "triggered": true,
                        "mode": mode,
                        "elapsed_ms": elapsedMs(since: start),
                    ])
                }
            case "file_changed":
                if !target.isEmpty {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: target)
                    if let modDate = attrs?[.modificationDate] as? Date, modDate > start {
                        return jsonString([
                            "triggered": true,
                            "mode": mode,
                            "elapsed_ms": elapsedMs(since: start),
                        ])
                    }
                }
            case "timeout_ms":
                // Pure sleep mode — fall through to the timeout below.
                break
            default:
                return errorJson("unknown watch mode: \(mode)")
            }
            try? await Task.sleep(for: .milliseconds(pollIntervalMs))
        }

        return jsonString([
            "triggered": mode == "timeout_ms",
            "mode": mode,
            "elapsed_ms": elapsedMs(since: start),
            "reason": mode == "timeout_ms" ? "elapsed" : "timeout",
        ])
    }

    // MARK: - Helpers

    private struct Phase4PerceiveRequest {
        let appScope: String?
        let depthClass: String
    }

    private func nextPerceiveToolCallID() -> String {
        let sequence = perceiveToolCallSequence
        if perceiveToolCallSequence < UInt64.max {
            perceiveToolCallSequence += 1
        }
        return "phase4-perceive-\(sequence)"
    }

    private func recordPhase4PerceiveEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: Phase4PerceiveRequest,
        result: PerceptionResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "phase4-perceive",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "phase4-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "phase4.perceive",
            argumentsJSON: phase4PerceiveArgumentsJSON(request),
            resultJSON: result.map(phase4PerceiveResultJSON),
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: phase4PerceiveMetadata(
                request: request,
                result: result,
                failureClass: failureClass
            )
        )
    }

    private func phase4PerceiveArgumentsJSON(_ request: Phase4PerceiveRequest) -> String {
        var payload: [String: Any] = [
            "depth_class": request.depthClass,
        ]
        if let appScope = request.appScope {
            payload["app_scope"] = appScope
        }
        return jsonString(payload)
    }

    private func phase4PerceiveResultJSON(_ result: PerceptionResult) -> String {
        jsonString([
            "method": result.method.rawValue,
            "interactive_count": max(0, result.interactiveCount),
            "ocr_count": result.ocrTexts.count,
            "latency_ms": safeMilliseconds(result.latencyMs),
            "success": result.method != .failed,
        ])
    }

    private func phase4PerceiveMetadata(
        request: Phase4PerceiveRequest,
        result: PerceptionResult?,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "phase4_bridge",
            "surface": "perceive",
            "depth_class": request.depthClass,
        ]
        if let appScope = request.appScope {
            metadata["app_scope"] = appScope
        }
        if let result {
            metadata["method"] = result.method.rawValue
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
    }

    private func appScope(_ appName: String) -> String? {
        appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "specific"
    }

    private func perceiveDepthClass(_ depth: String) -> String {
        switch depth.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fast":
            return "fast"
        case "enriched":
            return "enriched"
        case "full":
            return "full"
        case "":
            return "default"
        default:
            return "unknown"
        }
    }

    private func safeMilliseconds(_ value: Double) -> Int {
        guard value.isFinite, value >= 0 else { return 0 }
        return Int(value.rounded())
    }

    private func elapsedMs(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func durationMilliseconds(since start: Date) -> UInt64? {
        let elapsed = elapsedMs(since: start)
        return elapsed >= 0 ? UInt64(elapsed) : nil
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
#endif
