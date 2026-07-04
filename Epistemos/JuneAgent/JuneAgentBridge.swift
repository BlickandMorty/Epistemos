#if EPISTEMOS_APP_STORE
import AppKit
import Foundation
import WebKit
import os

/// The trust boundary between June's webview and the native host
/// (Plan 1-MAS §3 + hardening doctrine §3.A: every payload validated +
/// bounded; no secret ever crosses into JS; replies are injected as JSON
/// string literals, never interpolated code).
///
/// Two channels, both via `WKScriptMessageHandler`:
/// - `epistemosInvoke`  — Tauri `invoke()` commands from the shim
///   (`{callId, cmd, args}` → `resolveInvoke(callId, resultJSON, error)`).
/// - `epistemosGateway` — Hermes gateway JSON-RPC frames from the shim's
///   WebSocket stand-in (`{frame}` → `gatewayDeliver(frameJSON)`).
@MainActor
final class JuneAgentBridge: NSObject, WKScriptMessageHandler {
    static let invokeChannel = "epistemosInvoke"
    static let gatewayChannel = "epistemosGateway"
    static let consoleChannel = "epistemosConsole"
    /// June → native chrome: june:menu-bar:* emits forwarded by the shim.
    static let eventsChannel = "epistemosEvents"

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentBridge")

    let gateway = JuneAgentGateway()

    /// Wired by the surface view to `webView.evaluateJavaScript`.
    var runJS: ((String) -> Void)?

    override init() {
        super.init()
        gateway.deliver = { [weak self] frameJSON in
            guard let self else { return }
            self.runJS?(
                "window.__EPISTEMOS_TAURI_SHIM__ && window.__EPISTEMOS_TAURI_SHIM__.gatewayDeliver(\(Self.jsStringLiteral(frameJSON)));"
            )
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case Self.gatewayChannel:
            guard
                let body = message.body as? [String: Any],
                let frame = body["frame"] as? String
            else {
                Self.log.warning("gateway message failed shape validation")
                return
            }
            gateway.handleFrame(frame)
        case Self.invokeChannel:
            guard
                let body = message.body as? [String: Any],
                let callId = body["callId"] as? Int,
                let cmd = body["cmd"] as? String,
                cmd.count <= 128
            else {
                Self.log.warning("invoke message failed shape validation")
                return
            }
            let args = body["args"] as? [String: Any] ?? [:]
            let result = handleInvoke(cmd: cmd, args: args)
            resolveInvoke(callId: callId, result: result)
        case Self.eventsChannel:
            guard
                let body = message.body as? [String: Any],
                let event = body["event"] as? String,
                event.hasPrefix("june:menu-bar:")
            else {
                Self.log.warning("events message failed shape validation")
                return
            }
            if event == "june:menu-bar:agent-state",
               let payload = body["payload"] as? [String: Any] {
                JuneAgentActivityModel.shared.apply(statePayload: payload)
            }
        case Self.consoleChannel:
            #if DEBUG
            if let line = message.body as? String {
                Self.log.debug("june console: \(line.prefix(600), privacy: .public)")
            }
            #endif
        default:
            break
        }
    }

    private func resolveInvoke(callId: Int, result: Any?) {
        let payload: Any = result ?? NSNull()
        // Top-level scalars are valid JSON fragments; wrap to keep
        // JSONSerialization happy, unwrap in JS.
        let wrapper: [String: Any] = ["v": payload]
        guard
            JSONSerialization.isValidJSONObject(wrapper),
            let data = try? JSONSerialization.data(withJSONObject: wrapper),
            let json = String(data: data, encoding: .utf8)
        else {
            Self.log.error("invoke result not serializable for \(callId)")
            runJS?("window.__EPISTEMOS_TAURI_SHIM__ && window.__EPISTEMOS_TAURI_SHIM__.resolveInvoke(\(callId), null, 'serialization failure');")
            return
        }
        runJS?("window.__EPISTEMOS_TAURI_SHIM__ && window.__EPISTEMOS_TAURI_SHIM__.resolveInvoke(\(callId), \(Self.jsStringLiteral(json)), null);")
    }

    // MARK: - Invoke command table

    /// Honest Swift-side answers for the boot + send-path command set the
    /// Phase-0 spike enumerated. Hermes-session commands are REAL (backed by
    /// the gateway's durable store); side-feature commands (dictation,
    /// notes, Venice models) return honest empty shapes — those features are
    /// not part of the MAS agent room.
    private func handleInvoke(cmd: String, args: [String: Any]) -> Any? {
        let request = args["request"] as? [String: Any] ?? [:]

        switch cmd {
        case "bootstrap_app":
            return [
                "folders": [[String: Any]](),
                "notes": [[String: Any]](),
                "activeRecoveries": [[String: Any]](),
                "providerConfigured": true,
            ]
        case "os_accounts_status":
            // Local free lane (Plan 1-MAS §0.6): no account required. The
            // StoreKit-backed cloud gate replaces this in Phase 4.
            return [
                "signedIn": true,
                "configured": true,
                "localDev": true,
                "user": ["id": "local-user", "handle": "you", "displayName": "You"],
                "balance": ["usdMillis": 0],
                "subscription": ["subscribed": false],
            ]
        case "hermes_bridge_status", "start_hermes_bridge":
            return Self.bridgeStatusPayload
        case "stop_hermes_bridge":
            return ["running": false]
        case "hermes_bridge_sessions":
            return gateway.store.sessionsPayload()
        case "hermes_bridge_session_messages":
            guard let sessionID = request["sessionId"] as? String else { return ["messages": []] }
            return gateway.store.messagesPayload(sessionID: sessionID)
        case "ensure_hermes_bridge_session":
            if let sessionID = request["sessionId"] as? String,
               let title = request["title"] as? String, !title.isEmpty {
                gateway.store.renameSession(id: sessionID, title: title)
            }
            return NSNull()
        case "delete_hermes_bridge_session":
            if let sessionID = request["sessionId"] as? String {
                gateway.forgetSession(sessionID)
                gateway.store.deleteSession(id: sessionID)
            }
            return NSNull()
        case "suggest_agent_session_title":
            let prompt = (request["prompt"] as? String) ?? ""
            return ["title": Self.deriveTitle(from: prompt)]
        case "hermes_agent_cli_access":
            return ["enabled": false]
        case "list_agent_tasks":
            return ["items": [[String: Any]]()]
        case "list_notes":
            return ["items": [[String: Any]]()]
        case "list_folders", "list_session_folders", "list_dictionary_entries",
             "hermes_bridge_skills", "hermes_bridge_toolsets", "hermes_bridge_cron_jobs":
            return [[String: Any]]()
        case "hermes_bridge_messaging_platforms":
            return ["platforms": [[String: Any]]()]
        case "hermes_bridge_filesystem_snapshot":
            return ["roots": [[String: Any]]()]
        case "list_dictation_history":
            return ["items": [[String: Any]](), "retentionDays": 0]
        case "dictation_settings":
            return ["settings": Self.dictationSettingsPayload]
        case "provider_model_settings":
            return [
                "settings": [
                    "transcriptionProvider": "local",
                    "transcriptionModel": "local",
                    "generationModel": gateway.currentDefaultModelID(),
                    "imageModel": "",
                ],
            ]
        case "list_venice_models":
            let mode = (request["mode"] as? String) ?? "generation"
            return [
                "mode": mode,
                "modelType": "text",
                "selectedModel": gateway.currentDefaultModelID(),
                "models": gateway.modelsPayload(),
            ]
        case "set_venice_model":
            if let modelId = request["modelId"] as? String {
                gateway.setDefaultModel(modelId)
            }
            return [
                "transcriptionProvider": "local",
                "transcriptionModel": "local",
                "generationModel": gateway.currentDefaultModelID(),
                "imageModel": "",
            ]
        case "check_recording_source_readiness":
            let mode = (request["sourceMode"] as? String) ?? "microphoneOnly"
            return ["sourceMode": mode, "ready": false, "sources": [[String: Any]]()]
        case "create_note", "get_note":
            let now = ISO8601DateFormatter().string(from: Date())
            let id = (request["noteId"] as? String) ?? UUID().uuidString
            return [
                "id": id, "title": "Untitled", "preview": "",
                "processingStatus": "draft", "folderIds": [String](),
                "createdAt": now, "updatedAt": now,
            ]
        case "dictation_hotkey_status":
            return ["type": "idle"]
        case "latest_dictation_event", "fetch_update", "set_dock_icon",
             "dictation_helper_command":
            return NSNull()
        case "june_open_community_page":
            // Public constant in June's own JS (JUNE_COMMUNITY_URL); routed
            // through the backend only for target=_blank reliability.
            if let url = URL(string: "https://t.me/osjune") { NSWorkspace.shared.open(url) }
            return NSNull()
        case "open_privacy_settings":
            let pane = (request["pane"] as? String) ?? "microphone"
            let target: String
            switch pane {
            case "accessibility":
                target = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case "systemAudio":
                target = "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture"
            default:
                target = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            }
            if let url = URL(string: target) { NSWorkspace.shared.open(url) }
            return NSNull()
        case "june_open_verify_page", "os_accounts_open_portal", "os_accounts_upgrade":
            // No june-api attestation service or accounts portal exists in this
            // build — honest no-op (§0.5 capability truth), logged for diagnosis.
            Self.log.info("external-page command has no destination in this build: \(cmd, privacy: .public)")
            return NSNull()
        case "get_release_channel":
            return "stable"
        case "os_accounts_referral_summary":
            return [
                "code": "", "url": "", "referredCount": 0, "pendingCount": 0,
                "qualifiedCount": 0, "earnedMonths": 0, "appliedMonths": 0,
                "availableMonths": 0,
            ]
        default:
            Self.log.info("invoke defaulted (null): \(cmd, privacy: .public)")
            return NSNull()
        }
    }

    private static let bridgeStatusPayload: [String: Any] = {
        let connection: [String: Any] = [
            "baseUrl": "epistemos://gateway-http",
            "wsUrl": "epistemos://gateway",
            "token": "", // no secret in webview JS — in-process bridge needs none
            "port": 0,
            "command": "in-process agent_core",
            "hermesHome": "",
            "providerProxyPort": 0,
            "pid": 0,
            "sandboxed": true,
            "fullMode": false,
        ]
        return ["running": true, "connection": connection, "connections": [connection]]
    }()

    private static let dictationSettingsPayload: [String: Any] = {
        let shortcut: [String: Any] = [
            "code": "F5",
            "modifiers": [
                "command": false, "control": false, "option": false,
                "shift": false, "function": true,
            ],
            "label": "fn F5",
            "pressCount": 1,
        ]
        return [
            "pushToTalkShortcut": shortcut,
            "toggleShortcut": shortcut,
            "microphone": [String: Any](),
            "style": "standard",
        ]
    }()

    private static func deriveTitle(from prompt: String) -> String {
        let words = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(6)
        let title = words.joined(separator: " ")
        if title.isEmpty { return "New session" }
        return String(title.prefix(60))
    }

    /// Escapes a Swift string into a double-quoted JS string literal —
    /// including U+2028/U+2029 — so injected content can never break out of
    /// the literal (hardening doctrine §3.A).
    static func jsStringLiteral(_ value: String) -> String {
        var out = "\""
        out.reserveCapacity(value.count + 2)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{2028}": out += "\\u2028"
            case "\u{2029}": out += "\\u2029"
            case let s where s.value < 0x20:
                out += String(format: "\\u%04x", s.value)
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}
#endif
