#if EPISTEMOS_EXPERIMENTAL
import AppKit
import Foundation
import UserNotifications

/// The `/host` ws control client: the headless backend's electron-shim forwards
/// its `dialog` / `shell` / notification calls here (fork PATCH_LEDGER rows 7-8 —
/// the four folder pickers + save dialog terminate in NSOpenPanel/NSSavePanel).
///
/// Wire format (backend → host): `{callId: Int, kind: String, payload: {…}}`
/// Reply (host → backend):       `{callId: Int, result: <JSON>}`
///
/// Panels must run on the main actor; the receive loop hops accordingly.
@MainActor
final class ExperimentalHostBridge {
    private let uiPort: Int
    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectDelay: Duration = .milliseconds(500)
    private var wantsConnection = false

    init(uiPort: Int) {
        self.uiPort = uiPort
    }

    func connect() {
        wantsConnection = true
        openSocket()
    }

    func disconnect() {
        wantsConnection = false
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func openSocket() {
        guard wantsConnection, let url = URL(string: "ws://127.0.0.1:\(uiPort)/host") else { return }
        let socket = URLSession.shared.webSocketTask(with: url)
        task = socket
        socket.resume()
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            await self?.receiveForever(socket)
        }
    }

    private func receiveForever(_ socket: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                reconnectDelay = .milliseconds(500)
                guard case .string(let text) = message,
                      text.utf8.count <= 4_000_000, // §9 bridge discipline: length cap
                      let data = text.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let callId = object["callId"] as? Int,
                      let kind = object["kind"] as? String
                else { continue }
                let payload = object["payload"] as? [String: Any] ?? [:]
                let result = await handle(kind: kind, payload: payload)
                await send(callId: callId, result: result, over: socket)
            } catch {
                break // socket died — fall through to reconnect
            }
        }
        guard wantsConnection, !Task.isCancelled else { return }
        try? await Task.sleep(for: reconnectDelay)
        reconnectDelay = min(reconnectDelay * 2, .seconds(8))
        openSocket()
    }

    private func send(callId: Int, result: [String: Any], over socket: URLSessionWebSocketTask) async {
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(withJSONObject: ["callId": callId, "result": result]),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await socket.send(.string(text))
    }

    // MARK: - Request handling

    private func handle(kind: String, payload: [String: Any]) async -> [String: Any] {
        switch kind {
        case "dialog:open":
            return runOpenPanel(payload)
        case "dialog:save":
            return runSavePanel(payload)
        case "shell:open-external":
            return openExternal(payload)
        case "shell:show-item":
            if let path = payload["path"] as? String, !path.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                return ["ok": true]
            }
            return ["ok": false]
        case "shell:trash-item":
            if let path = payload["path"] as? String, !path.isEmpty {
                do {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    return ["ok": true]
                } catch {
                    return ["ok": false, "error": String(describing: error)]
                }
            }
            return ["ok": false]
        case "notification:show":
            postNotification(payload)
            return ["ok": true]
        default:
            return ["ok": false, "error": "unhandled host kind: \(kind)"]
        }
    }

    /// Electron OpenDialogOptions → NSOpenPanel. The donor's four picker sites
    /// pass `properties` like ["openDirectory","createDirectory"].
    private func runOpenPanel(_ payload: [String: Any]) -> [String: Any] {
        let properties = payload["properties"] as? [String] ?? []
        let panel = NSOpenPanel()
        panel.canChooseDirectories = properties.contains("openDirectory")
        panel.canChooseFiles = properties.contains("openFile") || !properties.contains("openDirectory")
        panel.allowsMultipleSelection = properties.contains("multiSelections")
        panel.canCreateDirectories = properties.contains("createDirectory")
        if let title = payload["title"] as? String { panel.message = title }
        if let buttonLabel = payload["buttonLabel"] as? String { panel.prompt = buttonLabel }
        if let defaultPath = payload["defaultPath"] as? String, !defaultPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: defaultPath)
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, !panel.urls.isEmpty else {
            return ["canceled": true, "filePaths": [String]()]
        }
        return ["canceled": false, "filePaths": panel.urls.map(\.path)]
    }

    private func runSavePanel(_ payload: [String: Any]) -> [String: Any] {
        let panel = NSSavePanel()
        if let title = payload["title"] as? String { panel.message = title }
        if let defaultPath = payload["defaultPath"] as? String, !defaultPath.isEmpty {
            let url = URL(fileURLWithPath: defaultPath)
            panel.directoryURL = url.deletingLastPathComponent()
            panel.nameFieldStringValue = url.lastPathComponent
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return ["canceled": true]
        }
        return ["canceled": false, "filePath": url.path]
    }

    private func openExternal(_ payload: [String: Any]) -> [String: Any] {
        guard let raw = payload["url"] as? String,
              raw.utf8.count <= 8_192,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme) // never file:/custom schemes from web content
        else { return ["ok": false] }
        NSWorkspace.shared.open(url)
        return ["ok": true]
    }

    private func postNotification(_ payload: [String: Any]) {
        let title = (payload["title"] as? String ?? "Epistemos").prefix(120)
        let body = (payload["body"] as? String ?? "").prefix(500)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(title)
            content.body = String(body)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil
            )
            center.add(request)
        }
    }
}
#endif
