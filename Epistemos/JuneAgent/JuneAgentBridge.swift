#if EPISTEMOS_APP_STORE
import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers
import WebKit
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

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
    /// Read-aloud: the overlay posts {action:"speak"|"stop", text} → the shared
    /// on-device synthesizer (native-side only; no audio/voice code in JS).
    static let speakChannel = "epistemosSpeak"

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentBridge")
    private static let maxInvokeCommandBytes = 128
    private static let maxInvokePayloadBytes = 1_000_000
    private static let maxSafeJavaScriptInteger = 9_007_199_254_740_991.0
    private static let maxNativeNotesPayloadItems = 500
    private static let maxNativeFoldersPayloadItems = 1_000
    private static let maxNativeNotePreviewCharacters = 320
    private static let maxNativeNoteContentCharacters = 120_000

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
                let callId = Self.validatedInvokeCallID(body["callId"]),
                let cmd = body["cmd"] as? String,
                cmd.utf8.count <= Self.maxInvokeCommandBytes
            else {
                Self.log.warning("invoke message failed shape validation")
                return
            }
            let args = body["args"] as? [String: Any] ?? [:]
            guard Self.invokeArgsAreBounded(args) else {
                Self.log.warning("invoke message failed payload bounds")
                return
            }
            if cmd == "system_prompt_forge_preview" {
                handleSystemPromptForgePreviewInvoke(callId: callId, args: args)
                return
            }
            if cmd == "get_note" {
                handleGetNoteInvoke(callId: callId, args: args)
                return
            }
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
        case Self.speakChannel:
            guard
                let body = message.body as? [String: Any],
                let action = body["action"] as? String
            else {
                Self.log.warning("speak message failed shape validation")
                return
            }
            handleSpeak(action: action, text: (body["text"] as? String) ?? "")
        default:
            break
        }
    }

    private static func validatedInvokeCallID(_ rawValue: Any?) -> Int? {
        if let int = rawValue as? Int,
           int >= 0,
           Double(int) <= maxSafeJavaScriptInteger {
            return int
        }
        guard !(rawValue is Bool),
              let number = rawValue as? NSNumber else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite,
              double.rounded(.towardZero) == double,
              double >= 0,
              double <= maxSafeJavaScriptInteger else {
            return nil
        }
        return number.intValue
    }

    private static func invokeArgsAreBounded(_ args: [String: Any]) -> Bool {
        let wrapper: [String: Any] = ["args": args]
        guard JSONSerialization.isValidJSONObject(wrapper),
              let data = try? JSONSerialization.data(withJSONObject: wrapper) else {
            return false
        }
        return data.count <= maxInvokePayloadBytes
    }

    /// Read-aloud: synthesize NATIVE-SIDE via the shared on-device engine. We
    /// CONSUME EpistemosSpeechSynthesizer (owned by the app-wide voice agent);
    /// never edit it, never put voice/audio code in the webview. Honest gate —
    /// speak() itself refuses when Kokoro isn't ready (no AVSpeech fallback),
    /// and voiceIdentifier nil uses the user's ModelVoicePickerSection pick.
    private func handleSpeak(action: String, text: String) {
        let synth = EpistemosSpeechSynthesizer.shared
        if action == "stop" {
            synth.stop()
            return
        }
        // Bound to the engine's OWN input cap (not an arbitrary smaller number)
        // so a long reply reads in full up to what Kokoro supports, while still
        // defending against untrusted webview payloads. Anything within the cap
        // never trips speak()'s length guard.
        _ = synth.speak(String(text.prefix(EpistemosSpeechSynthesizer.maxTextToSpeechInputCharacters)))
    }

    private func handleSystemPromptForgePreviewInvoke(callId: Int, args: [String: Any]) {
        let request = args["request"] as? [String: Any] ?? [:]
        let text = (request["text"] as? String) ?? ""
        let patternIDs = (request["patternIds"] as? [String]) ?? []
        guard text.utf8.count <= 200_000,
              patternIDs.count <= 16 else {
            resolveInvoke(
                callId: callId,
                result: JuneSystemPromptForgePreviewPayload(
                    originalText: "",
                    upgradedText: "",
                    changed: false,
                    mode: JuneSystemPromptForge.mode,
                    groundingStatus: "System Prompt Forge input was too large.",
                    changeSummary: ["Rejected oversized behavior input before native work."],
                    clarifyingQuestions: [],
                    patternsApplied: [],
                    citations: []
                ).dictionary
            )
            return
        }
        let activeVaultURL = Self.activeVaultURL()
        Task { [weak self] in
            let payload = await Task.detached(priority: .userInitiated) {
                JuneSystemPromptForge.previewPayload(
                    originalText: text,
                    patternIDs: patternIDs,
                    activeVaultURL: activeVaultURL
                )
            }.value
            self?.resolveInvoke(callId: callId, result: payload.dictionary)
        }
    }

    private func handleGetNoteInvoke(callId: Int, args: [String: Any]) {
        let request = args["request"] as? [String: Any] ?? [:]
        guard let noteID = Self.boundedNativeID(request["noteId"]),
              let snapshot = Self.nativeNoteSnapshot(noteID: noteID) else {
            resolveInvoke(callId: callId, result: Self.unavailableNotePayload(noteID: request["noteId"] as? String))
            return
        }
        Task { [weak self] in
            let content = await Task.detached(priority: .userInitiated) {
                await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: snapshot.id,
                    filePath: snapshot.filePath,
                    inlineBody: snapshot.inlineBody,
                    mapped: false,
                    fast: true
                )
            }.value
            self?.resolveInvoke(
                callId: callId,
                result: Self.nativeNoteDetailPayload(snapshot: snapshot, content: content)
            )
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
    /// the gateway's durable store). Notes/folders are read-only native
    /// metadata/detail projections; mutations remain native/review-owned.
    private func handleInvoke(cmd: String, args: [String: Any]) -> Any? {
        let request = args["request"] as? [String: Any] ?? [:]

        switch cmd {
        case "bootstrap_app":
            return Self.bootstrapPayload()
        case "os_accounts_status":
            // Local free lane (Plan 1-MAS §0.6): no account required. The
            // `subscription` field is DELIBERATELY OMITTED: June's funding gate
            // (account-gate.ts shouldBlockOnFunding) blocks when it sees a
            // known non-live subscription with depleted credits, and
            // `subscribed:false` counts as "known non-live" — leaving the free
            // lane reachable only by the accidental absence of a `credits`
            // field. Omitting subscription makes hasKnownNonLiveSubscription
            // return false, so the gate can NEVER block the free lane. Honest:
            // MAS subscriptions are StoreKit-managed (Phase 4), independent of
            // the OS-Accounts view, so subscription state here is genuinely N/A.
            return [
                "signedIn": true,
                "configured": true,
                "localDev": true,
                "user": ["id": "local-user", "handle": "you", "displayName": "You"],
                "balance": ["usdMillis": 0],
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
        case "june_export_replay_bundle":
            return exportReplayBundlePayload(request: request)
        case "hermes_bridge_skills":
            return Self.skillsPayload()
        case "get_hermes_bridge_skill":
            guard let name = Self.boundedSkillName((request["name"] as? String) ?? "") else {
                return Self.unavailableSkillPayload(name: "skill")
            }
            return Self.skillDocumentPayload(name: name)
        case "update_hermes_bridge_skill":
            guard let name = Self.boundedSkillName((request["name"] as? String) ?? "") else {
                return Self.unavailableSkillPayload(name: "skill")
            }
            return Self.skillDocumentPayload(name: name)
        case "toggle_hermes_bridge_skill":
            guard let name = Self.boundedSkillName((request["name"] as? String) ?? "") else {
                return ["ok": false, "name": "", "enabled": false]
            }
            guard let vaultPath = Self.selectedVaultPath(),
                  Self.skillPromotionGatePassed(name: name, vaultPath: vaultPath) else {
                return ["ok": false, "name": name, "enabled": false, "withheld": true]
            }
            let enabled = (request["enabled"] as? Bool) ?? true
            Self.setSkillEnabled(name: name, enabled: enabled)
            return ["ok": true, "name": name, "enabled": enabled]
        case "ensure_hermes_bridge_session":
            if let sessionID = request["sessionId"] as? String {
                if let title = request["title"] as? String, !title.isEmpty {
                    gateway.store.renameSession(
                        id: sessionID,
                        title: Self.boundedTitle(title)
                    )
                }
                if let model = request["model"] as? String,
                   !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    _ = gateway.setSessionModel(model, for: sessionID)
                }
            }
            return NSNull()
        case "delete_hermes_bridge_session":
            if let sessionID = request["sessionId"] as? String {
                gateway.forgetSession(sessionID)
                gateway.store.deleteSession(id: sessionID)
            }
            return NSNull()
        case "suggest_agent_session_title":
            // Invoke args aren't frame-size-bounded like gateway frames; cap the
            // prompt before deriving (a title is only the first few words, so
            // never scan a megabyte-sized string from a hostile page).
            let prompt = String(((request["prompt"] as? String) ?? "").prefix(4000))
            return ["title": Self.deriveTitle(from: prompt)]
        case "hermes_agent_cli_access":
            return ["enabled": false]
        case "list_agent_tasks":
            return ["items": [[String: Any]]()]
        case "list_notes":
            let folderID = Self.boundedNativeID(request["folderId"])
            return ["items": Self.nativeNotesPayload(folderID: folderID)]
        case "list_folders":
            return Self.nativeFoldersPayload()
        case "list_session_folders", "list_dictionary_entries",
             "hermes_bridge_toolsets", "hermes_bridge_cron_jobs":
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
        case "system_prompt_forge_settings":
            return JuneSystemPromptForge.settingsPayload()
        case "system_prompt_forge_save":
            let text = (request["text"] as? String) ?? ""
            let accepted = (request["acceptedText"] as? String) ?? ""
            let patternIDs = (request["patternIds"] as? [String]) ?? []
            guard text.utf8.count <= 200_000,
                  accepted.utf8.count <= 300_000,
                  patternIDs.count <= 16 else {
                var payload = JuneSystemPromptForge.settingsPayload()
                payload["saved"] = false
                payload["error"] = "System Prompt Forge input was too large."
                return payload
            }
            return JuneSystemPromptForge.savePayload(
                originalText: text,
                acceptedText: accepted,
                patternIDs: patternIDs
            )
        case "system_prompt_forge_reset":
            return JuneSystemPromptForge.resetPayload()
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
        case "create_note":
            return Self.readOnlyNoteMutationPayload(title: "New note")
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

    private static func bootstrapPayload() -> [String: Any] {
        [
            "folders": nativeFoldersPayload(),
            "notes": nativeNotesPayload(folderID: nil),
            "activeRecoveries": [[String: Any]](),
            "providerConfigured": true,
        ]
    }

    private static func nativeNotesPayload(folderID: String?) -> [[String: Any]] {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return [] }
        var descriptor = SDPage.activePagesDescriptor
        descriptor.fetchLimit = maxNativeNotesPayloadItems
        let pages = (try? context.fetch(descriptor)) ?? []
        return pages.compactMap { page in
            guard page.templateId == nil else { return nil }
            if let folderID, page.folder?.id != folderID { return nil }
            return nativeNoteListPayload(page)
        }
    }

    private static func nativeFoldersPayload() -> [[String: Any]] {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return [] }
        var descriptor = FetchDescriptor<SDFolder>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.name),
                SortDescriptor(\.createdAt),
            ]
        )
        descriptor.fetchLimit = maxNativeFoldersPayloadItems
        let folders = (try? context.fetch(descriptor)) ?? []
        return folders.map(nativeFolderPayload)
    }

    private struct NativeNoteSnapshot: Sendable {
        let id: String
        let title: String
        let summary: String
        let inlineBody: String
        let filePath: String?
        let folderID: String?
        let createdAt: Date
        let updatedAt: Date
        let wordCount: Int
    }

    private static func nativeNoteSnapshot(noteID: String) -> NativeNoteSnapshot? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        var descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == noteID })
        descriptor.fetchLimit = 1
        guard let page = try? context.fetch(descriptor).first,
              !page.isArchived,
              page.templateId == nil else {
            return nil
        }
        return NativeNoteSnapshot(
            id: page.id,
            title: page.title,
            summary: page.summary,
            inlineBody: page.body,
            filePath: page.filePath,
            folderID: page.folder?.id,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            wordCount: page.wordCount
        )
    }

    private static func nativeNoteDetailPayload(snapshot: NativeNoteSnapshot, content: String) -> [String: Any] {
        var payload = nativeNoteListPayload(snapshot)
        let content = boundedNativeNoteContent(content)
        payload["editedContent"] = content
        payload["generatedContent"] = content
        payload["activeTab"] = "notes"
        payload["readOnly"] = true
        return payload
    }

    private static func nativeNoteListPayload(_ page: SDPage) -> [String: Any] {
        let title = boundedNativeText(page.title, maxCharacters: 240)
        let preview = nativeNotePreview(page)
        var payload: [String: Any] = [
            "id": page.id,
            "title": title.isEmpty ? "Untitled" : title,
            "preview": preview,
            "processingStatus": "ready",
            "folderIds": page.folder.map { [$0.id] } ?? [String](),
            "createdAt": nativeISODate(page.createdAt),
            "updatedAt": nativeISODate(page.updatedAt),
            "readOnly": true,
        ]
        if page.wordCount > 0 {
            payload["wordCount"] = page.wordCount
        }
        return payload
    }

    private static func nativeNoteListPayload(_ snapshot: NativeNoteSnapshot) -> [String: Any] {
        let title = boundedNativeText(snapshot.title, maxCharacters: 240)
        var payload: [String: Any] = [
            "id": snapshot.id,
            "title": title.isEmpty ? "Untitled" : title,
            "preview": nativeNotePreview(
                title: snapshot.title,
                summary: snapshot.summary,
                inlineBody: snapshot.inlineBody
            ),
            "processingStatus": "ready",
            "folderIds": snapshot.folderID.map { [$0] } ?? [String](),
            "createdAt": nativeISODate(snapshot.createdAt),
            "updatedAt": nativeISODate(snapshot.updatedAt),
            "readOnly": true,
        ]
        if snapshot.wordCount > 0 {
            payload["wordCount"] = snapshot.wordCount
        }
        return payload
    }

    private static func nativeFolderPayload(_ folder: SDFolder) -> [String: Any] {
        let name = boundedNativeText(folder.name, maxCharacters: 240)
        var payload: [String: Any] = [
            "id": folder.id,
            "name": name.isEmpty ? "Untitled Folder" : name,
            "createdAt": nativeISODate(folder.createdAt),
            "updatedAt": nativeISODate(folder.createdAt),
            "readOnly": true,
        ]
        let relativePath = boundedNativeText(folder.relativePath, maxCharacters: 500)
        if !relativePath.isEmpty {
            payload["description"] = relativePath
        }
        return payload
    }

    private static func unavailableNotePayload(noteID: String?) -> [String: Any] {
        let now = nativeISODate(Date())
        let id = boundedNativeID(noteID) ?? "unavailable-note"
        return [
            "id": id,
            "title": "Note unavailable",
            "preview": "This note is unavailable from the native vault index.",
            "processingStatus": "failed",
            "folderIds": [String](),
            "createdAt": now,
            "updatedAt": now,
            "activeTab": "notes",
            "lastError": "This read-only MAS bridge could not load the requested note.",
            "readOnly": true,
        ]
    }

    private static func readOnlyNoteMutationPayload(title: String) -> [String: Any] {
        let now = nativeISODate(Date())
        return [
            "id": "native-notes-read-only",
            "title": title,
            "preview": "Create notes from the native Notes popover or an approved agent vault-write action.",
            "processingStatus": "failed",
            "folderIds": [String](),
            "createdAt": now,
            "updatedAt": now,
            "activeTab": "notes",
            "lastError": "June's web notes bridge is read-only in the MAS build.",
            "readOnly": true,
        ]
    }

    private static func nativeNotePreview(_ page: SDPage) -> String {
        nativeNotePreview(title: page.title, summary: page.summary, inlineBody: page.body)
    }

    private static func nativeNotePreview(title: String, summary: String, inlineBody: String) -> String {
        let summary = boundedNativeText(summary, maxCharacters: maxNativeNotePreviewCharacters)
        if !summary.isEmpty { return summary }
        let body = boundedNativeText(inlineBody, maxCharacters: maxNativeNotePreviewCharacters)
        if !body.isEmpty { return body }
        return boundedNativeText(title, maxCharacters: maxNativeNotePreviewCharacters)
    }

    private static func boundedNativeID(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 160,
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    private static func boundedNativeText(_ value: String, maxCharacters: Int) -> String {
        let collapsed = value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxCharacters else { return collapsed }
        return "\(collapsed.prefix(maxCharacters))..."
    }

    private static func boundedNativeNoteContent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxNativeNoteContentCharacters else { return trimmed }
        return "\(trimmed.prefix(maxNativeNoteContentCharacters))..."
    }

    private static func nativeISODate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func exportReplayBundlePayload(request: [String: Any]) -> [String: Any] {
        guard
            let sessionID = Self.boundedReplayToken(request["sessionId"], maxCharacters: 160),
            let answerPacketID = Self.boundedReplayToken(request["answerPacketId"], maxCharacters: 128)
        else {
            return ["ok": false, "error": "Replay bundle unavailable for this turn."]
        }
        let messageID = Self.boundedReplayToken(request["messageId"], maxCharacters: 160)
        let messages = gateway.store.loadMessages(sessionID: sessionID)
        let storedTurnMatches = messages.contains { message in
            message.role == "assistant"
                && message.answerPacketID == answerPacketID
                && (messageID == nil || message.id == messageID)
        }
        guard storedTurnMatches else {
            return ["ok": false, "error": "Replay bundle unavailable for this turn."]
        }

        #if canImport(agent_coreFFI)
        let generatedAtMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
        let bundleID = Self.replayBundleID(sessionID: sessionID, answerPacketID: answerPacketID)
        let bytes: [UInt8]
        do {
            bytes = try exportReplayBundleEpbundleBytes(
                bundleId: bundleID,
                runId: sessionID,
                answerPacketId: answerPacketID,
                generatedAtMs: generatedAtMs
            )
        } catch {
            Self.log.error("ReplayBundle export failed: \(error.localizedDescription, privacy: .public)")
            return ["ok": false, "error": "Replay bundle export failed."]
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(bundleID).epbundle"
        if let type = UTType(filenameExtension: "epbundle") ?? UTType("com.epistemos.epbundle") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else {
            return ["ok": false, "cancelled": true]
        }
        do {
            try Data(bytes).write(to: url, options: [.atomic])
            return ["ok": true, "filename": url.lastPathComponent]
        } catch {
            Self.log.error("ReplayBundle save failed: \(error.localizedDescription, privacy: .public)")
            return ["ok": false, "error": "Replay bundle could not be saved."]
        }
        #else
        return ["ok": false, "error": "Replay bundle export is unavailable in this build."]
        #endif
    }

    private static func boundedReplayToken(_ value: Any?, maxCharacters: Int) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxCharacters else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    private static func replayBundleID(sessionID: String, answerPacketID: String) -> String {
        let sessionPart = sessionID.filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(36)
        let packetPart = answerPacketID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }.prefix(80)
        let id = "june-\(sessionPart)-\(packetPart)"
        return String(id.prefix(140))
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
        // Single source of truth for title derivation (shared with the store's
        // auto-title), so a suggested title and a store-side title never diverge.
        let derived = JuneSessionStore.deriveTitle(from: prompt)
        return derived.isEmpty ? "New chat" : derived
    }

    private static func boundedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(160))
    }

    private struct SkillRegistryRow {
        let name: String
        let description: String
        let version: String
        let useCount: UInt32
        let successRate: Double
    }

    private static let disabledSkillsDefaultsKey = "epistemos.june.disabledSkills"
    private static let minimumSkillPromotionUseCount: UInt32 = 4
    private static let minimumSkillPromotionSuccessRate = 0.75

    private static func skillsPayload() -> [[String: Any]] {
        guard let vaultPath = selectedVaultPath() else {
            return []
        }
        return skillRegistryRows(vaultPath: vaultPath)
            .filter(skillPassedPromotionGate)
            .compactMap { skill -> [String: Any]? in
                guard let name = boundedSkillName(skill.name) else { return nil }
                return [
                    "name": name,
                    "description": String(skill.description.prefix(1000)),
                    "category": "Gate-passed vault skill",
                    "enabled": skillEnabled(name: name),
                    "source": "external",
                    "readOnly": true,
                    "version": String(skill.version.prefix(64)),
                    "useCount": Int(skill.useCount),
                    "successRate": skill.successRate,
                    "promotionStatus": "gate_passed",
                ]
            }
    }

    private static func skillRegistryRows(vaultPath: String) -> [SkillRegistryRow] {
        #if canImport(agent_coreFFI)
        let skills = listRegisteredSkills(vaultPath: vaultPath)
        #else
        let skills = listRegisteredSkillsLocal(vaultPath: vaultPath)
        #endif
        return skills.map { skill in
            SkillRegistryRow(
                name: skill.name,
                description: skill.description,
                version: skill.version,
                useCount: skill.useCount,
                successRate: skill.successRate
            )
        }
    }

    private static func skillDocumentPayload(name: String) -> [String: Any] {
        guard
            let vaultPath = selectedVaultPath(),
            skillPromotionGatePassed(name: name, vaultPath: vaultPath),
            let content = SkillVaultFileIO.readSkillMarkdown(vaultPath: vaultPath, skillName: name)
        else {
            return unavailableSkillPayload(name: name)
        }
        return [
            "name": name,
            "relativePath": "skills/\(name)/SKILL.md",
            "content": content,
            "readOnly": true,
        ]
    }

    private static func skillPromotionGatePassed(name: String) -> Bool {
        guard let vaultPath = selectedVaultPath() else { return false }
        return skillPromotionGatePassed(name: name, vaultPath: vaultPath)
    }

    private static func skillPromotionGatePassed(name: String, vaultPath: String) -> Bool {
        skillRegistryRows(vaultPath: vaultPath).contains { skill in
            boundedSkillName(skill.name) == name && skillPassedPromotionGate(skill)
        }
    }

    private static func skillPassedPromotionGate(_ skill: SkillRegistryRow) -> Bool {
        skill.useCount >= minimumSkillPromotionUseCount
            && skill.successRate.isFinite
            && skill.successRate >= minimumSkillPromotionSuccessRate
    }

    private static func unavailableSkillPayload(name: String) -> [String: Any] {
        [
            "name": name,
            "relativePath": "",
            "content": "Skill content unavailable. Do not treat this as an active skill.",
            "readOnly": true,
        ]
    }

    private static func selectedVaultPath() -> String? {
        let registry = VaultRegistry.shared
        return registry.resolveVaultPath(for: registry.selectedIdentity)
    }

    private static func activeVaultURL() -> URL? {
        guard AppBootstrap.shared?.vaultSync.isWatching == true else { return nil }
        return AppBootstrap.shared?.vaultSync.vaultURL?.standardizedFileURL
    }

    private static func skillEnabled(name: String) -> Bool {
        !disabledSkillNames().contains(name)
    }

    private static func setSkillEnabled(name: String, enabled: Bool) {
        var disabled = disabledSkillNames()
        if enabled {
            disabled.remove(name)
        } else {
            disabled.insert(name)
        }
        UserDefaults.standard.set(disabled.sorted(), forKey: disabledSkillsDefaultsKey)
    }

    private static func disabledSkillNames() -> Set<String> {
        Set((UserDefaults.standard.stringArray(forKey: disabledSkillsDefaultsKey) ?? [])
            .compactMap { boundedSkillName($0) })
    }

    private static func boundedSkillName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 128,
              trimmed != ".",
              trimmed != "..",
              !trimmed.hasPrefix("."),
              trimmed.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 0x2F, 0x5C, 0x3A:
                      return false
                  default:
                      return !CharacterSet.controlCharacters.contains(scalar)
                  }
              }) else {
            return nil
        }
        return trimmed
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
