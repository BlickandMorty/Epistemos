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
    static let shared = Phase4Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase4Bridge")

    private init() {}

    // MARK: - Specialty A1: perceive

    /// Perceive an app via Screen2AXFusion. `depth` is one of:
    /// - "fast"     — AX tree only (no OCR enrichment)
    /// - "enriched" — AX tree + Apple Vision OCR fallback (default)
    /// - "full"     — AX + OCR + VLM (currently identical to enriched)
    /// Returns JSON of the form
    /// `{ elements, screenshot_path?, latency_ms, method, error? }`.
    func perceive(appName: String, depth: String) async -> String {
        guard let fusion = AppBootstrap.shared?.screen2AXFusion else {
            return errorJson("Screen2AXFusion is not initialised")
        }
        let result = await fusion.perceive(appName: appName)

        let payload: [String: Any] = [
            "method": String(describing: result.method),
            "interactive_count": result.interactiveCount,
            "latency_ms": result.latencyMs,
            "depth": depth,
            "ax_tree_json": result.axTreeJson,
            "ocr_count": result.ocrTexts.count,
        ]
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

    private func elapsedMs(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
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
