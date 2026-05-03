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
    typealias ComputerActionExecutor = @MainActor (String) async -> String
    typealias PressElementExecutor = @MainActor (String, String) -> AXResponse
    typealias SetFocusedValueExecutor = @MainActor (String, String) -> AXResponse
    typealias FindElementsExecutor = @MainActor (String, String) -> AXResponse
    typealias FileExistsProvider = @MainActor (String) -> Bool
    typealias FileModificationDateProvider = @MainActor (String) -> Date?
    typealias WatchSleeper = @MainActor (Int) async -> Void

    static let shared = Phase4Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase4Bridge")
    private let perceptionProvider: PerceptionProvider
    private let computerActionExecutor: ComputerActionExecutor
    private let pressElementExecutor: PressElementExecutor
    private let setFocusedValueExecutor: SetFocusedValueExecutor
    private let findElementsExecutor: FindElementsExecutor
    private let fileExistsProvider: FileExistsProvider
    private let fileModificationDateProvider: FileModificationDateProvider
    private let watchSleeper: WatchSleeper
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var perceiveToolCallSequence: UInt64 = 0
    private var interactToolCallSequence: UInt64 = 0
    private var screenWatchToolCallSequence: UInt64 = 0

    init(
        perceptionProvider: @escaping PerceptionProvider = { appName in
            guard let fusion = AppBootstrap.shared?.screen2AXFusion else {
                return nil
            }
            return await fusion.perceive(appName: appName)
        },
        computerActionExecutor: @escaping ComputerActionExecutor = { actionJson in
            await ComputerUseBridge.shared.execute(actionJSON: actionJson)
        },
        pressElementExecutor: @escaping PressElementExecutor = { bundleID, target in
            AXorcistBridge.shared.pressElement(bundleID: bundleID, title: target)
        },
        setFocusedValueExecutor: @escaping SetFocusedValueExecutor = { value, bundleID in
            AXorcistBridge.shared.setFocusedValue(value, bundleID: bundleID)
        },
        findElementsExecutor: @escaping FindElementsExecutor = { bundleID, target in
            AXorcistBridge.shared.findElements(bundleID: bundleID, title: target)
        },
        fileExistsProvider: @escaping FileExistsProvider = { path in
            FileManager.default.fileExists(atPath: path)
        },
        fileModificationDateProvider: @escaping FileModificationDateProvider = { path in
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            return attrs?[.modificationDate] as? Date
        },
        watchSleeper: @escaping WatchSleeper = { milliseconds in
            try? await Task.sleep(for: .milliseconds(milliseconds))
        },
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.perceptionProvider = perceptionProvider
        self.computerActionExecutor = computerActionExecutor
        self.pressElementExecutor = pressElementExecutor
        self.setFocusedValueExecutor = setFocusedValueExecutor
        self.findElementsExecutor = findElementsExecutor
        self.fileExistsProvider = fileExistsProvider
        self.fileModificationDateProvider = fileModificationDateProvider
        self.watchSleeper = watchSleeper
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
        let parsedRequest = parsePhase4InteractRequest(actionJson: actionJson)
        let toolCallID = nextInteractToolCallID()
        recordPhase4InteractEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: parsedRequest
        )

        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "invalid_action_json",
                errorMessage: "Phase4 interact request was not accepted."
            )
            return errorJson("invalid action JSON")
        }
        let action = (payload["action"] as? String)?.lowercased() ?? ""
        let bundleID = payload["bundle_id"] as? String

        switch action {
        case "click", "screenshot", "type_text", "scroll", "keypress":
            // Forward straight to ComputerUseBridge — it knows the
            // pixel-coordinate variants of these actions.
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest
            )
            let start = Date()
            let response = await computerActionExecutor(actionJson)
            let result = phase4InteractResult(
                response,
                actionClass: parsedRequest.actionClass
            )
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: result.success ? .toolCallCompleted : .toolCallFailed,
                status: result.success ? .completed : .failed,
                request: parsedRequest,
                result: result.success ? result : nil,
                durationMs: durationMilliseconds(since: start),
                failureClass: result.success ? nil : result.failureClass,
                errorMessage: result.success ? nil : "Phase4 interact computer action failed."
            )
            return response
        case "press_target", "press":
            // AX-fuzzy press by element title.
            guard let target = payload["target"] as? String else {
                recordPhase4InteractEvent(
                    toolCallID: toolCallID,
                    kind: .toolCallFailed,
                    status: .failed,
                    request: parsedRequest,
                    failureClass: "missing_target",
                    errorMessage: "Phase4 interact request was not accepted."
                )
                return errorJson("press_target requires 'target'")
            }
            guard let bundleID else {
                recordPhase4InteractEvent(
                    toolCallID: toolCallID,
                    kind: .toolCallFailed,
                    status: .failed,
                    request: parsedRequest,
                    failureClass: "missing_bundle_id",
                    errorMessage: "Phase4 interact request was not accepted."
                )
                return errorJson("press_target requires 'bundle_id'")
            }
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest
            )
            let start = Date()
            let response = pressElementExecutor(bundleID, target)
            let (success, errorMessage) = Self.unpack(response)
            let result = Phase4InteractResult(
                success: success,
                resultClass: success ? "ax_press" : "ax_failed",
                failureClass: success ? nil : phase4AXFailureClass(errorMessage)
            )
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: success ? .toolCallCompleted : .toolCallFailed,
                status: success ? .completed : .failed,
                request: parsedRequest,
                result: success ? result : nil,
                durationMs: durationMilliseconds(since: start),
                failureClass: success ? nil : result.failureClass,
                errorMessage: success ? nil : "Phase4 interact AX action failed."
            )
            return jsonString([
                "success": success,
                "action": "press_target",
                "target": target,
                "bundle_id": bundleID,
                "error": errorMessage as Any,
            ])
        case "set_value", "type_target":
            guard let value = payload["value"] as? String else {
                recordPhase4InteractEvent(
                    toolCallID: toolCallID,
                    kind: .toolCallFailed,
                    status: .failed,
                    request: parsedRequest,
                    failureClass: "missing_value",
                    errorMessage: "Phase4 interact request was not accepted."
                )
                return errorJson("set_value requires 'value'")
            }
            guard let bundleID else {
                recordPhase4InteractEvent(
                    toolCallID: toolCallID,
                    kind: .toolCallFailed,
                    status: .failed,
                    request: parsedRequest,
                    failureClass: "missing_bundle_id",
                    errorMessage: "Phase4 interact request was not accepted."
                )
                return errorJson("set_value requires 'bundle_id'")
            }
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: .toolCallStarted,
                status: .started,
                request: parsedRequest
            )
            let start = Date()
            let response = setFocusedValueExecutor(value, bundleID)
            let (success, errorMessage) = Self.unpack(response)
            let result = Phase4InteractResult(
                success: success,
                resultClass: success ? "ax_set_value" : "ax_failed",
                failureClass: success ? nil : phase4AXFailureClass(errorMessage)
            )
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: success ? .toolCallCompleted : .toolCallFailed,
                status: success ? .completed : .failed,
                request: parsedRequest,
                result: success ? result : nil,
                durationMs: durationMilliseconds(since: start),
                failureClass: success ? nil : result.failureClass,
                errorMessage: success ? nil : "Phase4 interact AX action failed."
            )
            return jsonString([
                "success": success,
                "action": "set_value",
                "bundle_id": bundleID,
                "error": errorMessage as Any,
            ])
        default:
            recordPhase4InteractEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "unsupported_action",
                errorMessage: "Phase4 interact action was unsupported."
            )
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
        let parsedRequest = parsePhase4ScreenWatchRequest(watchJson: watchJson)
        let toolCallID = nextScreenWatchToolCallID()
        recordPhase4ScreenWatchEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: parsedRequest
        )

        guard let data = watchJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            recordPhase4ScreenWatchEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                request: parsedRequest,
                failureClass: "invalid_watch_json",
                errorMessage: "Phase4 screen watch request was not accepted."
            )
            return errorJson("invalid watch JSON")
        }
        let mode = (payload["mode"] as? String)?.lowercased() ?? "timeout_ms"
        let timeoutSecs = (payload["timeout_secs"] as? Int) ?? 30
        let pollIntervalMs = (payload["poll_interval_ms"] as? Int) ?? 250
        let target = payload["target"] as? String ?? ""

        let start = Date()
        let deadline = start.addingTimeInterval(TimeInterval(timeoutSecs))
        recordPhase4ScreenWatchEvent(
            toolCallID: toolCallID,
            kind: .toolCallStarted,
            status: .started,
            request: parsedRequest
        )

        while Date() < deadline {
            if Task.isCancelled { break }
            switch mode {
            case "ax_present":
                if let bundleID = payload["bundle_id"] as? String, !target.isEmpty {
                    let response = findElementsExecutor(bundleID, target)
                    if case .success(let payload, _) = response, payload != nil {
                        let response = jsonString([
                            "triggered": true,
                            "mode": mode,
                            "elapsed_ms": elapsedMs(since: start),
                        ])
                        recordPhase4ScreenWatchEvent(
                            toolCallID: toolCallID,
                            kind: .toolCallCompleted,
                            status: .completed,
                            request: parsedRequest,
                            result: Phase4ScreenWatchResult(
                                triggered: true,
                                reasonClass: "condition_met"
                            ),
                            durationMs: durationMilliseconds(since: start)
                        )
                        return response
                    }
                }
            case "file_exists":
                if !target.isEmpty, fileExistsProvider(target) {
                    let response = jsonString([
                        "triggered": true,
                        "mode": mode,
                        "elapsed_ms": elapsedMs(since: start),
                    ])
                    recordPhase4ScreenWatchEvent(
                        toolCallID: toolCallID,
                        kind: .toolCallCompleted,
                        status: .completed,
                        request: parsedRequest,
                        result: Phase4ScreenWatchResult(
                            triggered: true,
                            reasonClass: "condition_met"
                        ),
                        durationMs: durationMilliseconds(since: start)
                    )
                    return response
                }
            case "file_changed":
                if !target.isEmpty {
                    if let modDate = fileModificationDateProvider(target), modDate > start {
                        let response = jsonString([
                            "triggered": true,
                            "mode": mode,
                            "elapsed_ms": elapsedMs(since: start),
                        ])
                        recordPhase4ScreenWatchEvent(
                            toolCallID: toolCallID,
                            kind: .toolCallCompleted,
                            status: .completed,
                            request: parsedRequest,
                            result: Phase4ScreenWatchResult(
                                triggered: true,
                                reasonClass: "condition_met"
                            ),
                            durationMs: durationMilliseconds(since: start)
                        )
                        return response
                    }
                }
            case "timeout_ms":
                // Pure sleep mode — fall through to the timeout below.
                break
            default:
                recordPhase4ScreenWatchEvent(
                    toolCallID: toolCallID,
                    kind: .toolCallFailed,
                    status: .failed,
                    request: parsedRequest,
                    durationMs: durationMilliseconds(since: start),
                    failureClass: "unsupported_watch_mode",
                    errorMessage: "Phase4 screen watch mode was unsupported."
                )
                return errorJson("unknown watch mode: \(mode)")
            }
            await watchSleeper(pollIntervalMs)
        }

        let triggered = mode == "timeout_ms"
        let response = jsonString([
            "triggered": mode == "timeout_ms",
            "mode": mode,
            "elapsed_ms": elapsedMs(since: start),
            "reason": mode == "timeout_ms" ? "elapsed" : "timeout",
        ])
        recordPhase4ScreenWatchEvent(
            toolCallID: toolCallID,
            kind: .toolCallCompleted,
            status: .completed,
            request: parsedRequest,
            result: Phase4ScreenWatchResult(
                triggered: triggered,
                reasonClass: triggered ? "elapsed" : "timeout"
            ),
            durationMs: durationMilliseconds(since: start)
        )
        return response
    }

    // MARK: - Helpers

    private struct Phase4PerceiveRequest {
        let appScope: String?
        let depthClass: String
    }

    private struct Phase4InteractRequest {
        let actionClass: String
        let routeClass: String
        let appScope: String?
        let targetScope: String?
        let valueLengthBucket: String?
        let coordinateBucket: String?
        let directionClass: String?
        let keyClass: String?
    }

    private struct Phase4InteractResult {
        let success: Bool
        let resultClass: String
        let failureClass: String?
    }

    private struct Phase4ScreenWatchRequest {
        let modeClass: String
        let appScope: String?
        let targetScope: String?
        let timeoutBucket: String
        let pollIntervalBucket: String
    }

    private struct Phase4ScreenWatchResult {
        let triggered: Bool
        let reasonClass: String
    }

    private func nextPerceiveToolCallID() -> String {
        let sequence = perceiveToolCallSequence
        if perceiveToolCallSequence < UInt64.max {
            perceiveToolCallSequence += 1
        }
        return "phase4-perceive-\(sequence)"
    }

    private func nextInteractToolCallID() -> String {
        let sequence = interactToolCallSequence
        if interactToolCallSequence < UInt64.max {
            interactToolCallSequence += 1
        }
        return "phase4-interact-\(sequence)"
    }

    private func nextScreenWatchToolCallID() -> String {
        let sequence = screenWatchToolCallSequence
        if screenWatchToolCallSequence < UInt64.max {
            screenWatchToolCallSequence += 1
        }
        return "phase4-screen-watch-\(sequence)"
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

    private func recordPhase4ScreenWatchEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: Phase4ScreenWatchRequest,
        result: Phase4ScreenWatchResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "phase4-screen-watch",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "phase4-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "phase4.screen_watch.\(request.modeClass)",
            argumentsJSON: phase4ScreenWatchArgumentsJSON(request),
            resultJSON: result.map(phase4ScreenWatchResultJSON),
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: phase4ScreenWatchMetadata(
                request: request,
                result: result,
                failureClass: failureClass
            )
        )
    }

    private func recordPhase4InteractEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: Phase4InteractRequest,
        result: Phase4InteractResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "phase4-interact",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "phase4-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "phase4.interact.\(request.actionClass)",
            argumentsJSON: phase4InteractArgumentsJSON(request),
            resultJSON: result.map(phase4InteractResultJSON),
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: phase4InteractMetadata(
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

    private func phase4ScreenWatchArgumentsJSON(_ request: Phase4ScreenWatchRequest) -> String {
        var payload: [String: Any] = [
            "mode_class": request.modeClass,
            "timeout_bucket": request.timeoutBucket,
            "poll_interval_bucket": request.pollIntervalBucket,
        ]
        if let appScope = request.appScope {
            payload["app_scope"] = appScope
        }
        if let targetScope = request.targetScope {
            payload["target_scope"] = targetScope
        }
        return jsonString(payload)
    }

    private func phase4InteractArgumentsJSON(_ request: Phase4InteractRequest) -> String {
        var payload: [String: Any] = [
            "action_class": request.actionClass,
            "route_class": request.routeClass,
        ]
        if let appScope = request.appScope {
            payload["app_scope"] = appScope
        }
        if let targetScope = request.targetScope {
            payload["target_scope"] = targetScope
        }
        if let valueLengthBucket = request.valueLengthBucket {
            payload["value_length_bucket"] = valueLengthBucket
        }
        if let coordinateBucket = request.coordinateBucket {
            payload["coordinate_bucket"] = coordinateBucket
        }
        if let directionClass = request.directionClass {
            payload["direction_class"] = directionClass
        }
        if let keyClass = request.keyClass {
            payload["key_class"] = keyClass
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

    private func phase4ScreenWatchResultJSON(_ result: Phase4ScreenWatchResult) -> String {
        jsonString([
            "triggered": result.triggered,
            "reason_class": result.reasonClass,
        ])
    }

    private func phase4InteractResultJSON(_ result: Phase4InteractResult) -> String {
        jsonString([
            "success": result.success,
            "result_class": result.resultClass,
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

    private func phase4ScreenWatchMetadata(
        request: Phase4ScreenWatchRequest,
        result: Phase4ScreenWatchResult?,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "phase4_bridge",
            "surface": "screen_watch",
            "mode_class": request.modeClass,
        ]
        if let result {
            metadata["reason_class"] = result.reasonClass
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
    }

    private func phase4InteractMetadata(
        request: Phase4InteractRequest,
        result: Phase4InteractResult?,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "phase4_bridge",
            "surface": "interact",
            "action_class": request.actionClass,
            "route_class": request.routeClass,
        ]
        if let result {
            metadata["result_class"] = result.resultClass
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
    }

    private func parsePhase4InteractRequest(actionJson: String) -> Phase4InteractRequest {
        guard let data = actionJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Phase4InteractRequest(
                actionClass: "invalid_json",
                routeClass: "none",
                appScope: nil,
                targetScope: nil,
                valueLengthBucket: nil,
                coordinateBucket: nil,
                directionClass: nil,
                keyClass: nil
            )
        }

        let actionClass = phase4InteractActionClass(payload["action"] as? String)
        return Phase4InteractRequest(
            actionClass: actionClass,
            routeClass: phase4InteractRouteClass(actionClass),
            appScope: optionalAppScope(
                (payload["bundle_id"] as? String) ?? (payload["app_name"] as? String)
            ),
            targetScope: targetScope(payload["target"] as? String),
            valueLengthBucket: valueLengthBucket(
                (payload["value"] as? String) ?? (payload["text"] as? String)
            ),
            coordinateBucket: coordinateBucket(x: payload["x"] as? Int, y: payload["y"] as? Int),
            directionClass: interactDirectionClass(payload["direction"] as? String),
            keyClass: actionClass == "key" ? interactKeyClass(payload["text"] as? String) : nil
        )
    }

    private func parsePhase4ScreenWatchRequest(watchJson: String) -> Phase4ScreenWatchRequest {
        guard let data = watchJson.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Phase4ScreenWatchRequest(
                modeClass: "invalid_json",
                appScope: nil,
                targetScope: nil,
                timeoutBucket: "unknown",
                pollIntervalBucket: "unknown"
            )
        }

        return Phase4ScreenWatchRequest(
            modeClass: screenWatchModeClass(payload["mode"] as? String),
            appScope: optionalAppScope(payload["bundle_id"] as? String),
            targetScope: targetScope(payload["target"] as? String),
            timeoutBucket: secondsBucket(payload["timeout_secs"] as? Int),
            pollIntervalBucket: millisecondsBucket(payload["poll_interval_ms"] as? Int)
        )
    }

    private func screenWatchModeClass(_ rawMode: String?) -> String {
        switch rawMode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case nil, "", "timeout_ms":
            return "timeout"
        case "ax_present":
            return "ax_present"
        case "file_exists":
            return "file_exists"
        case "file_changed":
            return "file_changed"
        default:
            return "unknown"
        }
    }

    private func secondsBucket(_ seconds: Int?) -> String {
        guard let seconds else { return "default" }
        switch seconds {
        case ...0:
            return "0"
        case 1...5:
            return "1_5"
        case 6...30:
            return "6_30"
        case 31...120:
            return "31_120"
        default:
            return "121_plus"
        }
    }

    private func millisecondsBucket(_ milliseconds: Int?) -> String {
        guard let milliseconds else { return "default" }
        switch milliseconds {
        case ...0:
            return "0"
        case 1...100:
            return "1_100"
        case 101...500:
            return "101_500"
        case 501...1_000:
            return "501_1000"
        default:
            return "1001_plus"
        }
    }

    private func phase4InteractActionClass(_ rawAction: String?) -> String {
        switch rawAction?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "click":
            return "click"
        case "screenshot":
            return "screenshot"
        case "type_text":
            return "type"
        case "scroll":
            return "scroll"
        case "keypress", "key_press":
            return "key"
        case "press_target", "press":
            return "press"
        case "set_value", "type_target":
            return "set_value"
        case nil, "":
            return "unknown"
        default:
            return "unknown"
        }
    }

    private func phase4InteractRouteClass(_ actionClass: String) -> String {
        switch actionClass {
        case "click", "screenshot", "type", "scroll", "key":
            return "computer_use"
        case "press", "set_value":
            return "axorcist"
        case "invalid_json":
            return "none"
        default:
            return "unknown"
        }
    }

    private func phase4InteractResult(_ resultJSON: String, actionClass: String) -> Phase4InteractResult {
        guard let data = resultJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Phase4InteractResult(
                success: false,
                resultClass: "invalid_result_json",
                failureClass: "invalid_result_json"
            )
        }

        let success = payload["success"] as? Bool == true
        if success {
            return Phase4InteractResult(
                success: true,
                resultClass: phase4InteractResultClass(actionClass: actionClass, payload: payload),
                failureClass: nil
            )
        }

        return Phase4InteractResult(
            success: false,
            resultClass: "failed",
            failureClass: phase4InteractFailureClass(payload["error"] as? String)
        )
    }

    private func phase4InteractResultClass(actionClass: String, payload: [String: Any]) -> String {
        if payload["screenshot_base64"] != nil {
            return "computer_screenshot"
        }
        if payload["accessibility_tree"] != nil || payload["elements"] != nil {
            return "computer_ax_tree"
        }
        switch actionClass {
        case "click", "type", "scroll", "key":
            return "computer_input"
        default:
            return "completed"
        }
    }

    private func phase4InteractFailureClass(_ error: String?) -> String {
        let error = error?.lowercased() ?? ""
        if error.contains("accessibility permission") {
            return "accessibility_permission_denied"
        }
        if error.contains("unknown action") {
            return "unsupported_action"
        }
        if error.contains("invalid action") {
            return "invalid_action_json"
        }
        if error.contains("not found") {
            return "app_unavailable"
        }
        return "interact_action_failed"
    }

    private func phase4AXFailureClass(_ error: Any) -> String {
        guard let message = error as? String else {
            return "ax_action_failed"
        }
        let lowercased = message.lowercased()
        if lowercased.contains("not found") {
            return "target_unavailable"
        }
        if lowercased.contains("permission") {
            return "accessibility_permission_denied"
        }
        return "ax_action_failed"
    }

    private func appScope(_ appName: String) -> String? {
        appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "specific"
    }

    private func optionalAppScope(_ appName: String?) -> String? {
        guard let appName, !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "specific"
    }

    private func targetScope(_ target: String?) -> String? {
        guard let target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "specified"
    }

    private func valueLengthBucket(_ value: String?) -> String? {
        guard let value else { return nil }
        switch value.count {
        case 0:
            return "0"
        case 1...16:
            return "1_16"
        case 17...64:
            return "17_64"
        default:
            return "65_plus"
        }
    }

    private func coordinateBucket(x: Int?, y: Int?) -> String? {
        guard let x, let y else { return nil }
        let bucketSize = 100
        return "\(x / bucketSize * bucketSize)-\(y / bucketSize * bucketSize)"
    }

    private func interactDirectionClass(_ direction: String?) -> String? {
        switch direction?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "up":
            return "up"
        case "down":
            return "down"
        case "left":
            return "left"
        case "right":
            return "right"
        case nil, "":
            return nil
        default:
            return "unknown"
        }
    }

    private func interactKeyClass(_ key: String?) -> String {
        switch key?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "return", "enter", "tab", "space", "delete", "escape", "esc":
            return "editing"
        case "up", "down", "left", "right":
            return "navigation"
        case nil, "":
            return "empty"
        default:
            return "other"
        }
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
