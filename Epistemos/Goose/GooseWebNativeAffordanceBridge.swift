import AppKit
import Foundation
import UniformTypeIdentifiers
import WebKit

@MainActor
final class GooseWebNativeAffordanceBridge: NSObject, WKScriptMessageHandlerWithReply {
    typealias Handler = @MainActor ([Any]) throws -> Any?

    nonisolated static let blockedExternalProtocols: Set<String> = [
        "file",
        "javascript",
        "data",
        "vbscript",
        "blob",
        "about",
        "chrome",
        "chrome-extension",
    ]

    nonisolated private static let webProtocols: Set<String> = ["http", "https"]

    private let handlers: [String: Handler]

    init(handlers: [String: Handler] = [:]) {
        self.handlers = handlers
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard let body = message.body as? [String: Any] else {
            replyHandler(nil, "Malformed Epistemos Goose native affordance request.")
            return
        }
        receiveAffordanceMessage(body, replyHandler: replyHandler)
    }

    func receiveAffordanceMessage(
        _ body: [String: Any],
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard let name = body["name"] as? String,
              body["id"] is String,
              let args = body["args"] as? [Any] else {
            replyHandler(nil, "Malformed Epistemos Goose native affordance request.")
            return
        }

        do {
            replyHandler(try handleAffordance(name: name, args: args), nil)
        } catch {
            replyHandler(nil, error.localizedDescription)
        }
    }

    func handleAffordance(name: String, args: [Any]) throws -> Any? {
        if let handler = handlers[name] {
            return try handler(args)
        }

        switch name {
        case "showOpenDialog":
            return runOpenDialog(options: dictionaryArgument(args, at: 0) ?? [:])
        case "showSaveDialog":
            return runSaveDialog(options: dictionaryArgument(args, at: 0) ?? [:])
        case "directoryChooser":
            return runOpenDialog(options: [
                "properties": ["openDirectory", "createDirectory"],
                "defaultPath": NSHomeDirectory(),
            ])
        case "selectFileOrDirectory":
            return runSelectFileOrDirectory(defaultPath: stringArgument(args, at: 0))
        case "selectImportSessionFile":
            return runSelectImportSessionFile()
        case "openExternal":
            guard let rawURL = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try openExternal(rawURL)
            return nil
        case "openInChrome":
            guard let rawURL = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try openBrowserURL(rawURL)
            return nil
        case "openDirectoryInExplorer":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return openDirectory(path)
        default:
            throw GooseWebNativeAffordanceBridgeError.unsupported(name)
        }
    }

    nonisolated static func shouldOpenExternalURL(_ rawURL: String) -> Bool {
        guard let scheme = URL(string: rawURL)?.scheme?.lowercased() else { return false }
        return !blockedExternalProtocols.contains(scheme)
    }

    nonisolated static func shouldOpenBrowserURL(_ rawURL: String) -> Bool {
        guard let scheme = URL(string: rawURL)?.scheme?.lowercased() else { return false }
        return webProtocols.contains(scheme)
    }

    private func runOpenDialog(options: [String: Any]) -> [String: Any] {
        let panel = NSOpenPanel()
        applyOpenOptions(options, to: panel)
        let response = panel.runModal()
        guard response == .OK else {
            return ["canceled": true, "filePaths": []]
        }
        return [
            "canceled": false,
            "filePaths": panel.urls.map(\.path),
        ]
    }

    private func runSaveDialog(options: [String: Any]) -> [String: Any] {
        let panel = NSSavePanel()
        applyPanelOptions(options, to: panel)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return ["canceled": true]
        }
        return [
            "canceled": false,
            "filePath": url.path,
        ]
    }

    private func runSelectFileOrDirectory(defaultPath: String?) -> String? {
        var options: [String: Any] = [
            "properties": ["openFile", "openDirectory"],
        ]
        options["defaultPath"] = existingDefaultDirectoryPath(defaultPath) ?? NSHomeDirectory()
        let result = runOpenDialog(options: options)
        guard result["canceled"] as? Bool == false,
              let filePaths = result["filePaths"] as? [String] else {
            return nil
        }
        return filePaths.first
    }

    private func runSelectImportSessionFile() -> [String: Any]? {
        let result = runOpenDialog(options: [
            "title": "Import session",
            "defaultPath": NSHomeDirectory(),
            "properties": ["openFile", "showHiddenFiles"],
            "filters": [
                ["name": "Session files", "extensions": ["json", "jsonl"]],
                ["name": "All files", "extensions": ["*"]],
            ],
        ])
        guard result["canceled"] as? Bool == false,
              let filePaths = result["filePaths"] as? [String],
              let filePath = filePaths.first else {
            return nil
        }

        do {
            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
            return ["filePath": filePath, "contents": contents]
        } catch {
            return ["filePath": filePath, "contents": "", "error": error.localizedDescription]
        }
    }

    private func openExternal(_ rawURL: String) throws {
        guard Self.shouldOpenExternalURL(rawURL), let url = URL(string: rawURL) else {
            return
        }
        guard NSWorkspace.shared.open(url) else {
            throw GooseWebNativeAffordanceBridgeError.openFailed(rawURL)
        }
    }

    private func openBrowserURL(_ rawURL: String) throws {
        guard Self.shouldOpenBrowserURL(rawURL), let url = URL(string: rawURL) else {
            return
        }
        guard NSWorkspace.shared.open(url) else {
            throw GooseWebNativeAffordanceBridgeError.openFailed(rawURL)
        }
    }

    private func openDirectory(_ path: String) -> Bool {
        let expandedPath = expandTilde(path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath, isDirectory: true))
    }

    private func applyOpenOptions(_ options: [String: Any], to panel: NSOpenPanel) {
        let properties = Set((options["properties"] as? [String]) ?? [])
        panel.canChooseDirectories = properties.contains("openDirectory")
        panel.canChooseFiles = properties.contains("openFile") || !panel.canChooseDirectories
        panel.allowsMultipleSelection = properties.contains("multiSelections")
        panel.canCreateDirectories = properties.contains("createDirectory")
        panel.showsHiddenFiles = properties.contains("showHiddenFiles")
        applyPanelOptions(options, to: panel)
    }

    private func applyPanelOptions(_ options: [String: Any], to panel: NSSavePanel) {
        if let title = options["title"] as? String {
            panel.title = title
        }
        if let message = options["message"] as? String {
            panel.message = message
        }
        if let prompt = options["buttonLabel"] as? String {
            panel.prompt = prompt
        }
        if let defaultPath = options["defaultPath"] as? String {
            applyDefaultPath(defaultPath, to: panel)
        }
        if let contentTypes = allowedContentTypes(from: options["filters"] as? [[String: Any]]) {
            panel.allowedContentTypes = contentTypes
        }
    }

    private func applyDefaultPath(_ path: String, to panel: NSSavePanel) {
        let expandedPath = expandTilde(path)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                panel.directoryURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
            } else {
                let url = URL(fileURLWithPath: expandedPath, isDirectory: false)
                panel.directoryURL = url.deletingLastPathComponent()
                panel.nameFieldStringValue = url.lastPathComponent
            }
        } else {
            panel.directoryURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        }
    }

    private func allowedContentTypes(from filters: [[String: Any]]?) -> [UTType]? {
        guard let filters else { return nil }
        let extensions = filters
            .compactMap { $0["extensions"] as? [String] }
            .flatMap { $0 }
        guard !extensions.isEmpty, !extensions.contains("*") else { return nil }
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? nil : types
    }

    private func existingDefaultDirectoryPath(_ path: String?) -> String? {
        guard let path else { return nil }
        let expandedPath = expandTilde(path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            return expandedPath
        }
        return URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
    }

    private func expandTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func dictionaryArgument(_ args: [Any], at index: Int) -> [String: Any]? {
        guard args.indices.contains(index) else { return nil }
        return args[index] as? [String: Any]
    }

    private func stringArgument(_ args: [Any], at index: Int) -> String? {
        guard args.indices.contains(index) else { return nil }
        return args[index] as? String
    }
}

private enum GooseWebNativeAffordanceBridgeError: LocalizedError {
    case missingArgument(String)
    case openFailed(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            "Missing argument for Epistemos Goose native affordance: \(name)."
        case .openFailed(let rawURL):
            "Failed to open Epistemos Goose native URL: \(rawURL)."
        case .unsupported(let name):
            "Unsupported Epistemos Goose native affordance: \(name)."
        }
    }
}
