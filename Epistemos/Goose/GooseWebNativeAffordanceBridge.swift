import AppKit
import CryptoKit
import Foundation
import IOKit.pwr_mgt
import UniformTypeIdentifiers
import UserNotifications
import WebKit

@MainActor
final class GooseWebNativeAffordanceBridge: NSObject, WKScriptMessageHandlerWithReply {
    typealias Handler = @MainActor ([Any]) throws -> Any?

    // SECURITY (deep-hardening 2026-06-29 #13/#24): deny-by-default ALLOWLIST of safe
    // user-facing schemes. A denylist permitted smb://, ftp://, vnc://, ssh:// and arbitrary
    // app deep-link schemes from WebView content (LSOpen of attacker-chosen handlers).
    nonisolated static let allowedExternalSchemes: Set<String> = [
        "http",
        "https",
        "mailto",
        "tel",
    ]

    nonisolated private static let webProtocols: Set<String> = ["http", "https"]
    nonisolated static let maxLaunchedAppWindows = 16
    nonisolated static let minLaunchedAppWindowWidth: Double = 320
    nonisolated static let minLaunchedAppWindowHeight: Double = 240
    nonisolated static let maxLaunchedAppWindowWidth: Double = 1_600
    nonisolated static let maxLaunchedAppWindowHeight: Double = 1_200
    nonisolated static let maxLaunchedAppContentBytes = 16 * 1024 * 1024
    nonisolated static let maxNativeFileReadBytes = 16 * 1024 * 1024
    nonisolated static let maxNativeFileWriteBytes = 16 * 1024 * 1024
    nonisolated static let maxNativeDirectoryListEntries = 5_000
    nonisolated static let maxGitWorktreeListBytes = 4 * 1024 * 1024
    nonisolated static let maxGitWorktreePathCharacters = 4_096
    nonisolated static let maxNativeAffordanceNameCharacters = 96
    nonisolated static let maxLaunchedAppNameCharacters = 128
    nonisolated static let maxRecentDirsFileBytes = 64 * 1024
    nonisolated static let maxRecipeHashInputBytes = 1 * 1024 * 1024
    nonisolated static let maxRecipeHashDepth = 32
    nonisolated static let maxRecipeHashCollectionEntries = 4_096
    nonisolated static let maxNativeDialogButtons = 8
    nonisolated static let maxNativeDialogTitleCharacters = 160
    nonisolated static let maxNativeDialogMessageCharacters = 2_048
    nonisolated static let maxNativeDialogDetailCharacters = 8_192
    nonisolated static let maxNativeDialogButtonCharacters = 80
    nonisolated static let maxNativeErrorMessageCharacters = 512
    nonisolated static let maxNativeErrorDomainCharacters = 96
    nonisolated static let maxNativeNotificationTitleCharacters = 160
    nonisolated static let maxNativeNotificationBodyCharacters = 2_048
    nonisolated static let maxNativeFileDialogFilters = 16
    nonisolated static let maxNativeFileDialogExtensions = 64
    nonisolated static let maxNativeFileDialogExtensionCharacters = 32
    nonisolated static let maxNativeBinarySearchPathCharacters = 8_192
    nonisolated static let maxNativeBinarySearchPathEntryCharacters = 4_096
    nonisolated static let maxNativeBinarySearchPathEntries = 64
    nonisolated static let defaultNativeBinarySearchDirectories = [
        "/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin",
    ]
    nonisolated static let maxNativeOpenURLCharacters = 4_096
    nonisolated static let maxNativeURLSchemeCharacters = 64

    private let handlers: [String: Handler]
    private let fileManager: FileManager
    private let applicationSupportRoot: URL
    private let recentDirsURL: URL
    private let recipeHashesRoot: URL
    private let preferences: UserDefaults
    private let maxAppWindowCount: Int
    private var scopedFileRoots: Set<String>
    private var appWindows: [String: NSWindow] = [:]
    private var appWebViews: [String: WKWebView] = [:]
    private var appWindowDelegates: [String: GooseWebNativeAppWindowDelegate] = [:]
    private var appGuestNavDelegates: [String: GooseWebNativeAppGuestNavigationDelegate] = [:]
    private var wakelockAssertionID: IOPMAssertionID = 0
    /// Registered loopback origins (the goose/goosed server + UI server ports) shared with the main
    /// surface's `GooseTrustedLoopbackOrigins`. Set by the host view. When present, app-launch URIs
    /// and guest top-frame navigations are pinned to these EXACT registered ports (review M1/M3) —
    /// not merely "any loopback host", which would let an MCP app pivot to another local service.
    /// nil only in tests / before wiring → callers fall back to host-only loopback.
    var trustedLoopbackOrigins: GooseTrustedLoopbackOrigins?

    init(
        handlers: [String: Handler] = [:],
        initialScopedFileRoots: [URL]? = nil,
        applicationSupportRoot: URL? = nil,
        preferences: UserDefaults = .standard,
        fileManager: FileManager = .default,
        maxLaunchedAppWindows: Int = GooseWebNativeAffordanceBridge.maxLaunchedAppWindows
    ) {
        self.handlers = handlers
        self.fileManager = fileManager
        self.preferences = preferences
        self.maxAppWindowCount = Swift.max(0, maxLaunchedAppWindows)
        let root = applicationSupportRoot ?? Self.defaultApplicationSupportRoot(fileManager: fileManager)
        self.applicationSupportRoot = root
        self.recentDirsURL = root
            .appendingPathComponent("recent-dirs", isDirectory: true)
            .appendingPathComponent("recent-dirs.json", isDirectory: false)
        self.recipeHashesRoot = root.appendingPathComponent("recipe-hashes", isDirectory: true)
        let configuredFileRoots = initialScopedFileRoots ?? [fileManager.homeDirectoryForCurrentUser]
        let rootPaths = [
            Self.standardizedPath(root.path),
            Self.standardizedPath(fileManager.temporaryDirectory.path),
            Self.standardizedPath(fileManager.currentDirectoryPath),
        ] + configuredFileRoots.map { Self.standardizedPath($0.path) }
        self.scopedFileRoots = Set(rootPaths.flatMap { [$0, Self.resolvedSymlinkPath($0)] })
    }

    isolated deinit {
        closeAllApps()
        if wakelockAssertionID != 0 {
            IOPMAssertionRelease(wakelockAssertionID)
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        // review C-M3: this handler is registered in the `.page` content world (NOT forMainFrameOnly),
        // so a foreign subframe (iframe) could otherwise reach native file/app/dialog affordances even
        // if the nav-gate is bypassed. Defense-in-depth: only the main frame may drive native
        // affordances — reject everything else at the WebKit boundary.
        guard message.frameInfo.isMainFrame else {
            replyHandler(nil, "Epistemos blocked a Goose native affordance from a non-main frame.")
            return
        }
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
        guard let rawName = body["name"] as? String,
              body["id"] is String,
              let args = body["args"] as? [Any],
              let name = Self.boundedNativeAffordanceName(rawName) else {
            replyHandler(nil, "Malformed Epistemos Goose native affordance request.")
            return
        }

        do {
            replyHandler(try handleAffordance(name: name, args: args), nil)
        } catch {
            replyHandler(nil, Self.nativeErrorMessage(for: error))
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
        case "showMessageBox":
            return runMessageBox(options: dictionaryArgument(args, at: 0) ?? [:])
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
        case "getBinaryPath":
            guard let binaryName = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return resolveBinaryPath(binaryName)
        case "readFile":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return readFile(path)
        case "readFileDataURL":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return readFileDataURL(path)
        case "writeFile":
            guard let path = stringArgument(args, at: 0),
                  let content = stringArgument(args, at: 1) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return writeFile(path, content: content)
        case "ensureDirectory":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return ensureDirectory(path)
        case "listFiles":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return listFiles(path, extensionFilter: stringArgument(args, at: 1))
        case "listGitWorktreeDirs":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return listGitWorktreeDirs(path)
        case "launchApp":
            guard let app = dictionaryArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try launchApp(app)
            return nil
        case "refreshApp":
            guard let app = dictionaryArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try refreshApp(app)
            return nil
        case "closeApp":
            guard let appName = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            closeApp(name: appName)
            return nil
        case "openNotificationsSettings":
            return openNotificationsSettings()
        case "showNotification":
            return showNotification(dictionaryArgument(args, at: 0) ?? [:])
        case "setMenuBarIcon":
            guard let show = boolArgument(args.first) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setMenuBarIcon(show)
        case "getMenuBarIconState":
            return menuBarIconState()
        case "setDockIcon":
            guard let show = boolArgument(args.first) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setDockIcon(show)
        case "getDockIconState":
            return dockIconState()
        case "setWakelock":
            guard let enabled = boolArgument(args.first) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setWakelock(enabled)
        case "getWakelockState":
            return wakelockState()
        case "setSpellcheck":
            guard let enabled = boolArgument(args.first) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setSpellcheck(enabled)
        case "getSpellcheckState":
            return spellcheckState()
        case "addRecentDir":
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return addRecentDirectory(path)
        case "listRecentDirs":
            return listRecentDirectories()
        case "hasAcceptedRecipeBefore":
            return hasAcceptedRecipeBefore(args.first)
        case "recordRecipeHash":
            return recordRecipeHash(args.first)
        default:
            throw GooseWebNativeAffordanceBridgeError.unsupported(name)
        }
    }

    nonisolated static func shouldOpenExternalURL(_ rawURL: String) -> Bool {
        guard let scheme = boundedURLScheme(rawURL) else { return false }
        return allowedExternalSchemes.contains(scheme)
    }

    nonisolated static func shouldOpenBrowserURL(_ rawURL: String) -> Bool {
        guard let scheme = boundedURLScheme(rawURL) else { return false }
        return webProtocols.contains(scheme)
    }

    nonisolated private static func boundedURLScheme(_ rawURL: String) -> String? {
        guard rawURL.utf8.count <= maxNativeOpenURLCharacters,
              !rawURL.utf8.contains(0),
              let scheme = URL(string: rawURL)?.scheme,
              scheme.utf8.count <= maxNativeURLSchemeCharacters,
              !scheme.utf8.contains(0) else {
            return nil
        }
        return scheme.lowercased()
    }

    private func runOpenDialog(options: [String: Any]) -> [String: Any] {
        let panel = NSOpenPanel()
        applyOpenOptions(options, to: panel)
        let response = panel.runModal()
        guard response == .OK else {
            return ["canceled": true, "filePaths": []]
        }
        rememberScopedAccess(for: panel.urls)
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
        rememberScopedAccess(for: [url])
        return [
            "canceled": false,
            "filePath": url.path,
        ]
    }

    private func runMessageBox(options: [String: Any]) -> [String: Any] {
        let alert = NSAlert()
        alert.alertStyle = alertStyle(from: options["type"] as? String)
        alert.messageText = Self.boundedNativeDialogText(
            options["message"] as? String,
            maxCharacters: Self.maxNativeDialogMessageCharacters,
            fallback: "Goose"
        ) ?? "Goose"
        if let detail = Self.boundedNativeDialogText(
            options["detail"] as? String,
            maxCharacters: Self.maxNativeDialogDetailCharacters
        ) {
            alert.informativeText = detail
        }
        let buttons = Self.boundedNativeDialogButtons(options["buttons"] as? [String])
        for button in buttons {
            alert.addButton(withTitle: button)
        }
        let defaultId = intArgument(options["defaultId"])
        let cancelId = intArgument(options["cancelId"])
        for (index, button) in alert.buttons.enumerated() {
            button.keyEquivalent = ""
            if index == defaultId {
                button.keyEquivalent = "\r"
            }
            if index == cancelId {
                button.keyEquivalent = "\u{1b}"
            }
        }
        let checkbox = checkboxButton(options: options)
        alert.accessoryView = checkbox
        let response = alert.runModal()
        let index = max(0, Int(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue))
        return [
            "response": min(index, buttons.count - 1),
            "checkboxChecked": checkbox?.state == .on,
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

        return Self.importSessionFileResult(filePath: filePath, fileManager: fileManager)
    }

    static func importSessionFileResult(
        filePath: String,
        fileManager: FileManager = .default
    ) -> [String: Any] {
        let expandedPath = standardizedPath(filePath)
        guard !exceedsNativeFileReadLimit(expandedPath, fileManager: fileManager) else {
            return [
                "filePath": filePath,
                "contents": "",
                "error": "Epistemos blocked Goose WebView import session file read over \(maxNativeFileReadBytes) bytes.",
            ]
        }
        if let data = readNativeFileData(expandedPath, fileManager: fileManager),
           let contents = String(data: data, encoding: .utf8) {
            return ["filePath": filePath, "contents": contents]
        }
        return [
            "filePath": filePath,
            "contents": "",
            "error": boundedNativeErrorMessage("Goose WebView import session file read failed."),
        ]
    }

    nonisolated static func boundedNativeDialogButtons(_ rawButtons: [String]?) -> [String] {
        let buttons = (rawButtons ?? []).compactMap {
            boundedNativeDialogText(
                $0,
                maxCharacters: maxNativeDialogButtonCharacters
            )
        }
        let bounded = Array(buttons.prefix(maxNativeDialogButtons))
        return bounded.isEmpty ? ["OK"] : bounded
    }

    nonisolated static func boundedNativeDialogText(
        _ rawText: String?,
        maxCharacters: Int,
        fallback: String? = nil
    ) -> String? {
        guard let rawText else { return fallback }
        let withoutControls = String(String.UnicodeScalarView(rawText.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t"
        }))
        let trimmed = withoutControls.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(Swift.max(0, maxCharacters)))
    }

    nonisolated static func boundedNativeErrorMessage(
        _ message: String,
        fallback: String = "Goose native affordance failed."
    ) -> String {
        boundedNativeDialogText(
            message,
            maxCharacters: maxNativeErrorMessageCharacters,
            fallback: fallback
        ) ?? fallback
    }

    nonisolated static func nativeErrorMessage(
        for error: Error,
        fallback: String = "Goose native affordance failed."
    ) -> String {
        if error is GooseWebNativeAffordanceBridgeError {
            return boundedNativeErrorMessage(error.localizedDescription, fallback: fallback)
        }

        let nsError = error as NSError
        return boundedNativeErrorMessage(
            "\(fallback) (domain=\(safeNativeErrorDomain(nsError.domain)) code=\(nsError.code)).",
            fallback: fallback
        )
    }

    nonisolated static func safeNativeErrorDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("\\") else {
            return "Error"
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = String(String.UnicodeScalarView(trimmed.unicodeScalars.filter { allowed.contains($0) }))
        guard !filtered.isEmpty else { return "Error" }
        return String(filtered.prefix(maxNativeErrorDomainCharacters))
    }

    private func openExternal(_ rawURL: String) throws {
        // review MED-3: deny is fail-closed AND honest — throw so the WebView learns the scheme was
        // rejected instead of silently treating a blocked open as success.
        guard Self.shouldOpenExternalURL(rawURL), let url = URL(string: rawURL) else {
            throw GooseWebNativeAffordanceBridgeError.disallowed(rawURL)
        }
        guard NSWorkspace.shared.open(url) else {
            throw GooseWebNativeAffordanceBridgeError.openFailed(rawURL)
        }
    }

    private func openBrowserURL(_ rawURL: String) throws {
        guard Self.shouldOpenBrowserURL(rawURL), let url = URL(string: rawURL) else {
            throw GooseWebNativeAffordanceBridgeError.disallowed(rawURL)
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
        // Security (review H1): this is WEB-DRIVEN, so NEVER hand the path to NSWorkspace.open — a
        // `.app` (or `.workflow`/`.scptd`/document-package) bundle IS a directory, so `open` would
        // LAUNCH it, reopening exactly the LSOpen handler-launch threat the openExternal allowlist
        // (#13/#24) closed. Confine to a consented scope, reject bundles, and REVEAL in Finder
        // (`selectFile` opens a Finder window and never launches anything).
        guard isPathAllowed(expandedPath) else { return false }
        let url = URL(fileURLWithPath: expandedPath, isDirectory: true)
        if let values = try? url.resourceValues(forKeys: [.isApplicationKey, .isPackageKey]),
           values.isApplication == true || values.isPackage == true {
            return false
        }
        return NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
    }

    private func resolveBinaryPath(_ binaryName: String) -> String {
        let safeName = URL(fileURLWithPath: binaryName).lastPathComponent
        guard !safeName.isEmpty, safeName == binaryName else { return "" }
        for directory in Self.nativeBinarySearchDirectories() {
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(safeName, isDirectory: false)
                .path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return ""
    }

    nonisolated static func nativeBinarySearchDirectories(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        guard let path = environment["PATH"] else {
            return defaultNativeBinarySearchDirectories
        }
        guard path.utf8.count <= maxNativeBinarySearchPathCharacters,
              !path.utf8.contains(0) else {
            return defaultNativeBinarySearchDirectories
        }
        let directories = path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(maxNativeBinarySearchPathEntries)
            .compactMap { nativeBinarySearchDirectory(String($0)) }
        return directories
    }

    nonisolated private static func nativeBinarySearchDirectory(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= maxNativeBinarySearchPathEntryCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        return trimmed
    }

    private func readFile(_ path: String) -> [String: Any] {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        guard isPathAllowed(expandedPath) else {
            return [
                "file": "",
                "filePath": expandedPath,
                "error": "Epistemos blocked Goose WebView file read outside scoped roots.",
                "found": false,
            ]
        }
        guard !exceedsNativeFileReadLimit(expandedPath) else {
            return [
                "file": "",
                "filePath": expandedPath,
                "error": "Epistemos blocked Goose WebView file read over \(Self.maxNativeFileReadBytes) bytes.",
                "found": false,
            ]
        }
        if let data = readNativeFileData(expandedPath),
           let contents = String(data: data, encoding: .utf8) {
            return ["file": contents, "filePath": expandedPath, "error": NSNull(), "found": true]
        }
        return [
            "file": "",
            "filePath": expandedPath,
            "error": Self.boundedNativeErrorMessage("Goose WebView file read failed."),
            "found": false,
        ]
    }

    private func readFileDataURL(_ path: String) -> String? {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        guard isPathAllowed(expandedPath),
              !isSymbolicLink(expandedPath),
              let data = readNativeFileData(expandedPath) else { return nil }
        let fileURL = URL(fileURLWithPath: expandedPath, isDirectory: false)
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func readNativeFileData(_ expandedPath: String) -> Data? {
        Self.readNativeFileData(expandedPath, fileManager: fileManager)
    }

    nonisolated static func readNativeFileData(
        _ expandedPath: String,
        fileManager: FileManager = .default
    ) -> Data? {
        readRegularFileData(
            expandedPath,
            maxBytes: Self.maxNativeFileReadBytes,
            fileManager: fileManager
        )
    }

    nonisolated static func readRegularFileData(
        _ expandedPath: String,
        maxBytes: Int,
        fileManager: FileManager = .default
    ) -> Data? {
        let maxBytes = max(0, maxBytes)
        guard let size = fileSize(atPath: expandedPath, fileManager: fileManager),
              size <= UInt64(maxBytes) else {
            return nil
        }
        let fileURL = URL(fileURLWithPath: expandedPath, isDirectory: false)
        guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
              resourceValues.isRegularFile == true else {
            return nil
        }

        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let readLimit = maxBytes == Int.max ? Int.max : maxBytes + 1
            let data = try handle.read(upToCount: readLimit) ?? Data()
            guard data.count <= maxBytes else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func writeFile(_ path: String, content: String) -> Bool {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        guard isPathAllowedForWrite(expandedPath) else { return false }
        guard content.utf8.count <= Self.maxNativeFileWriteBytes else { return false }
        do {
            try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            rememberScopedAccess(for: [URL(fileURLWithPath: expandedPath, isDirectory: false)])
            return true
        } catch {
            return false
        }
    }

    private func ensureDirectory(_ path: String) -> Bool {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        guard isPathAllowedForWrite(expandedPath) else { return false }
        do {
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: expandedPath, isDirectory: true),
                withIntermediateDirectories: true
            )
            rememberScopedRoot(expandedPath)
            return true
        } catch {
            return false
        }
    }

    private func listFiles(_ path: String, extensionFilter: String?) -> [String] {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        var isDirectory: ObjCBool = false
        guard isPathAllowed(expandedPath),
              fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return []
        }
        do {
            let files = try fileManager.contentsOfDirectory(atPath: expandedPath)
            let filteredFiles: [String]
            if let extensionFilter, !extensionFilter.isEmpty {
                filteredFiles = files.filter { $0.hasSuffix(extensionFilter) }
            } else {
                filteredFiles = files
            }
            return Array(filteredFiles
                .sorted(by: Self.directoryEntryPrecedes)
                .prefix(Self.maxNativeDirectoryListEntries))
        } catch {
            return []
        }
    }

    private func listGitWorktreeDirs(_ path: String) -> [String] {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        var isDirectory: ObjCBool = false
        guard isPathAllowed(expandedPath),
              fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return []
        }
        let git = resolveBinaryPath("git")
        guard !git.isEmpty else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        // review LOW-2: this runs git on a WEB-CHOSEN directory, so neutralize attacker-controlled git
        // config that could run code. `-c core.fsmonitor=false` blocks a malicious repo `.git/config`
        // from spawning an fsmonitor command; `-c protocol.allow=never` blocks any sub-fetch.
        process.arguments = [
            "-c", "core.fsmonitor=false",
            "-c", "protocol.allow=never",
            "-C", expandedPath, "worktree", "list", "--porcelain",
        ]
        // SECURITY (deep-hardening 2026-06-29 #23): set an explicit minimal environment instead of
        // inheriting the full process env (which carries DYLD_*/LD_*/Malloc*/NODE_*/PYTHON* etc.).
        // review LOW-2: also ignore SYSTEM + GLOBAL git config (~/.gitconfig can carry tokens/pagers/
        // hooks); only the repo config git needs for `worktree list` is consulted.
        let gitDir = URL(fileURLWithPath: git, isDirectory: false).deletingLastPathComponent().path
        process.environment = [
            "PATH": "\(gitDir):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
            "HOME": fileManager.homeDirectoryForCurrentUser.path,
            "LANG": "en_US.UTF-8",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0",
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        // review M4: DRAIN the stdout pipe CONCURRENTLY with the process running. Previously the pipe
        // was read only AFTER waiting for termination, so a repo with many worktrees (git output >
        // the ~64KB pipe buffer) made git BLOCK on write → the terminationHandler never fired → the
        // wait timed out → a dishonest empty result. Concurrent draining also means the wait now
        // completes as soon as git exits (fast), instead of risking the full 3s watchdog window.
        let stdoutHandle = stdout.fileHandleForReading
        let drainBox = GooseAffordanceDataBox()
        let drainDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            drainBox.store(Self.readBoundedPipeData(
                stdoutHandle,
                maxBytes: Self.maxGitWorktreeListBytes
            ))
            drainDone.signal()
        }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return []
        }
        if semaphore.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            return []
        }
        // The process has exited → it closed its write end → the concurrent drain hits EOF promptly.
        _ = drainDone.wait(timeout: .now() + 1)
        guard process.terminationStatus == 0 else { return [] }
        let outputData = drainBox.load()
        guard outputData.count <= Self.maxGitWorktreeListBytes else { return [] }
        let output = String(data: outputData, encoding: .utf8) ?? ""
        var seen = Set<String>()
        var worktrees: [String] = []
        output.enumerateLines { line, stop in
            guard line.hasPrefix("worktree "),
                  let path = Self.boundedGitWorktreePath(String(line.dropFirst("worktree ".count))),
                  seen.insert(path).inserted else {
                return
            }
            worktrees.append(path)
            if worktrees.count >= Self.maxNativeDirectoryListEntries {
                stop = true
            }
        }
        return worktrees
    }

    nonisolated static func boundedGitWorktreePath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxGitWorktreePathCharacters else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func readBoundedPipeData(_ handle: FileHandle, maxBytes: Int) -> Data {
        let maxBytes = max(0, maxBytes)
        let captureLimit = maxBytes == Int.max ? Int.max : maxBytes + 1
        let chunkSize = 64 * 1024
        var data = Data()

        while true {
            if data.count < captureLimit {
                let requestedBytes = min(chunkSize, captureLimit - data.count)
                guard requestedBytes > 0 else { break }
                let chunk: Data?
                do {
                    chunk = try handle.read(upToCount: requestedBytes)
                } catch {
                    break
                }
                guard let chunk, !chunk.isEmpty else {
                    break
                }
                data.append(chunk)
                if data.count < captureLimit {
                    continue
                }
            }

            while true {
                let overflow: Data?
                do {
                    overflow = try handle.read(upToCount: chunkSize)
                } catch {
                    break
                }
                guard let overflow, !overflow.isEmpty else {
                    break
                }
            }
            break
        }

        return data
    }

    private func addRecentDirectory(_ path: String) -> Bool {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return false
        }

        var dirs = listRecentDirectories().filter { $0 != expandedPath }
        dirs.insert(expandedPath, at: 0)
        dirs = Array(dirs.prefix(12))
        do {
            try fileManager.createDirectory(
                at: recentDirsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: ["dirs": dirs], options: [.prettyPrinted, .sortedKeys])
            try data.write(to: recentDirsURL, options: .atomic)
            // SECURITY: recent-dirs is a display-only convenience list. It must NOT grant
            // filesystem scope — otherwise a WebView call (addRecentDir + readFile) is a full
            // path-sandbox escape. Scope is widened ONLY via the consented NSOpenPanel path
            // (rememberScopedAccess). Deep-hardening 2026-06-29 C1.
            return true
        } catch {
            return false
        }
    }

    private func listRecentDirectories() -> [String] {
        guard let data = Self.readRegularFileData(
                recentDirsURL.path,
                maxBytes: Self.maxRecentDirsFileBytes,
                fileManager: fileManager
              ),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dirs = object["dirs"] as? [String] else {
            return []
        }
        let validDirs = dirs
            .map { Self.standardizedPath(expandTilde($0)) }
            .filter { path in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
                    && !isSymbolicLink(path)
            }
        // SECURITY: do NOT re-grant scope when merely listing recent dirs (this re-broadened
        // scopedFileRoots on every launch, persisting any escape across restarts). Display-only.
        // Deep-hardening 2026-06-29 C1.
        return validDirs
    }

    private func hasAcceptedRecipeBefore(_ recipe: Any?) -> Bool {
        guard let hash = recipeHash(recipe) else { return false }
        return fileManager.fileExists(atPath: recipeHashesRoot.appendingPathComponent("\(hash).hash").path)
    }

    private func recordRecipeHash(_ recipe: Any?) -> Bool {
        guard let hash = recipeHash(recipe) else { return false }
        do {
            try fileManager.createDirectory(at: recipeHashesRoot, withIntermediateDirectories: true)
            let fileURL = recipeHashesRoot.appendingPathComponent("\(hash).hash", isDirectory: false)
            try ISO8601DateFormatter().string(from: Date()).write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private enum GuestAppLoad {
        case html(String)
        case uri(URL)
    }

    /// An MCP-app `uri` / guest top-frame navigation is allowed only to a REGISTERED loopback origin
    /// (exact port) when the registered set is wired (review M1/M3) — not merely "any loopback host",
    /// which would let an app pivot to another local service. Falls back to host-only loopback when
    /// the set is absent (tests / pre-wiring).
    private func isAllowedAppOrigin(_ url: URL) -> Bool {
        if let trustedLoopbackOrigins {
            return trustedLoopbackOrigins.isAllowed(url)
        }
        return GooseTrustedLoopbackOrigins.isLoopback(url.host)
    }

    private func launchApp(_ app: [String: Any]) throws {
        let name = try appName(from: app)
        // L2: reuse an existing window even when MINIMIZED (`isVisible` is false for a miniaturized
        // window, which previously built a duplicate and orphaned the prior webview).
        if let existingWindow = appWindows[name] {
            if existingWindow.isMiniaturized { existingWindow.deminiaturize(nil) }
            existingWindow.makeKeyAndOrderFront(nil)
            appWebViews[name]?.reload()
            return
        }
        guard appWindows.count < maxAppWindowCount else {
            throw GooseWebNativeAffordanceBridgeError.appWindowLimitExceeded(maxAppWindowCount)
        }

        // Resolve the content SOURCE before creating any webview/window, so a rejected uri (review M3)
        // throws an honest error with NOTHING created or leaked — instead of building a window the
        // guest nav delegate then silently blanks (the owner's "Apps loading failures" dead window).
        let guestLoad: GuestAppLoad
        if let html = try htmlContent(from: app, appName: name) {
            guestLoad = .html(html)
        } else if let rawURI = app["uri"] as? String,
                  Self.shouldOpenBrowserURL(rawURI),
                  let url = URL(string: rawURI),
                  isAllowedAppOrigin(url) {
            guestLoad = .uri(url)
        } else {
            throw GooseWebNativeAffordanceBridgeError.missingAppContent(name)
        }

        // SECURITY (deep-hardening 2026-06-29 #14 + review M1): the guest webview renders
        // attacker-influenced HTML. Non-persistent store, NO script handlers, and a nav delegate that
        // pins the top frame to the app-support render root + about: + REGISTERED loopback ports only
        // (not any loopback host — review M1), denying external / file-traversal / dangerous schemes.
        let guestConfiguration = WKWebViewConfiguration()
        guestConfiguration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(
            frame: .zero,
            configuration: guestConfiguration
        )
        let guestNavDelegate = GooseWebNativeAppGuestNavigationDelegate(
            allowedFileRoot: applicationSupportRoot,
            trustedLoopbackOrigins: trustedLoopbackOrigins
        )
        webView.navigationDelegate = guestNavDelegate
        appGuestNavDelegates[name] = guestNavDelegate
        switch guestLoad {
        case .html(let html):
            webView.loadHTMLString(html, baseURL: applicationSupportRoot)
        case .uri(let url):
            webView.load(URLRequest(url: url))
        }

        let width = appWindowDimension(
            app["width"],
            fallback: 800,
            min: Self.minLaunchedAppWindowWidth,
            max: Self.maxLaunchedAppWindowWidth
        )
        let height = appWindowDimension(
            app["height"],
            fallback: 600,
            min: Self.minLaunchedAppWindowHeight,
            max: Self.maxLaunchedAppWindowHeight
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: windowStyleMask(resizable: boolArgument(app["resizable"]) ?? true),
            backing: .buffered,
            defer: false
        )
        window.title = formatAppName(name)
        window.contentView = webView
        window.center()

        let delegate = GooseWebNativeAppWindowDelegate { [weak self] in
            self?.appWindows.removeValue(forKey: name)
            self?.appWebViews.removeValue(forKey: name)
            self?.appWindowDelegates.removeValue(forKey: name)
            self?.appGuestNavDelegates.removeValue(forKey: name)
        }
        window.delegate = delegate
        appWindows[name] = window
        appWebViews[name] = webView
        appWindowDelegates[name] = delegate
        window.makeKeyAndOrderFront(nil)
    }

    private func refreshApp(_ app: [String: Any]) throws {
        let name = try appName(from: app)
        guard let window = appWindows[name], let webView = appWebViews[name] else { return }
        window.makeKeyAndOrderFront(nil)
        webView.reload()
    }

    private func closeApp(name: String) {
        guard let name = Self.normalizedAppName(name),
              name.count <= Self.maxLaunchedAppNameCharacters else { return }
        appWindows[name]?.close()
        appWindows.removeValue(forKey: name)
        appWebViews.removeValue(forKey: name)
        appWindowDelegates.removeValue(forKey: name)
        appGuestNavDelegates.removeValue(forKey: name)   // L1: was leaked (relied on windowWillClose)
    }

    /// Closes every launched MCP-app window and clears the registries. Invoked on
    /// Goose surface teardown so launched app windows do not outlive the surface as
    /// orphaned top-level NSWindows holding WKWebViews with no remaining UI to close
    /// them. Snapshot + clear the registries BEFORE closing: `window.close()` fires
    /// the `windowWillClose` delegate, which mutates these dictionaries; iterating a
    /// live dictionary while closing would mutate during iteration.
    func closeAllApps() {
        let windows = Array(appWindows.values)
        appWindows.removeAll()
        appWebViews.removeAll()
        appWindowDelegates.removeAll()
        appGuestNavDelegates.removeAll()   // L1: was leaked here too
        for window in windows {
            window.close()
        }
    }

    private func openNotificationsSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    private func showNotification(_ data: [String: Any]) -> Bool {
        let content = UNMutableNotificationContent()
        content.title = Self.boundedNativeDialogText(
            data["title"] as? String,
            maxCharacters: Self.maxNativeNotificationTitleCharacters,
            fallback: "Epistemos"
        ) ?? "Epistemos"
        content.body = Self.boundedNativeDialogText(
            data["body"] as? String,
            maxCharacters: Self.maxNativeNotificationBodyCharacters,
            fallback: ""
        ) ?? ""
        let request = UNNotificationRequest(
            identifier: "epistemos-goose-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        return true
    }

    private func setMenuBarIcon(_ show: Bool) -> Bool {
        preferences.set(show, forKey: PreferenceKey.showMenuBarIcon)
        if show {
            StatusBar.shared.setup()
        } else {
            StatusBar.shared.remove()
        }
        return true
    }

    private func menuBarIconState() -> Bool {
        preferenceBool(forKey: PreferenceKey.showMenuBarIcon, defaultValue: true)
    }

    private func setDockIcon(_ show: Bool) -> Bool {
        preferences.set(show, forKey: PreferenceKey.showDockIcon)
        if show {
            return NSApp.setActivationPolicy(.regular)
        }
        if !menuBarIconState() {
            _ = setMenuBarIcon(true)
        }
        return NSApp.setActivationPolicy(.accessory)
    }

    private func dockIconState() -> Bool {
        preferenceBool(forKey: PreferenceKey.showDockIcon, defaultValue: true)
    }

    private func setWakelock(_ enabled: Bool) -> Bool {
        preferences.set(enabled, forKey: PreferenceKey.enableWakelock)
        if enabled {
            guard wakelockAssertionID == 0 else { return true }
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Epistemos Goose wakelock" as CFString,
                &assertionID
            )
            guard result == kIOReturnSuccess else { return false }
            wakelockAssertionID = assertionID
            return true
        }

        if wakelockAssertionID != 0 {
            IOPMAssertionRelease(wakelockAssertionID)
            wakelockAssertionID = 0
        }
        return true
    }

    private func wakelockState() -> Bool {
        preferenceBool(forKey: PreferenceKey.enableWakelock, defaultValue: false)
    }

    private func setSpellcheck(_ enabled: Bool) -> Bool {
        preferences.set(enabled, forKey: PreferenceKey.spellcheckEnabled)
        return true
    }

    private func spellcheckState() -> Bool {
        preferenceBool(forKey: PreferenceKey.spellcheckEnabled, defaultValue: true)
    }

    private func preferenceBool(forKey key: String, defaultValue: Bool) -> Bool {
        preferences.object(forKey: key) == nil ? defaultValue : preferences.bool(forKey: key)
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
        if let title = Self.boundedNativeDialogText(
            options["title"] as? String,
            maxCharacters: Self.maxNativeDialogTitleCharacters
        ) {
            panel.title = title
        }
        if let message = Self.boundedNativeDialogText(
            options["message"] as? String,
            maxCharacters: Self.maxNativeDialogMessageCharacters
        ) {
            panel.message = message
        }
        if let prompt = Self.boundedNativeDialogText(
            options["buttonLabel"] as? String,
            maxCharacters: Self.maxNativeDialogButtonCharacters
        ) {
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
        guard let extensions = Self.boundedNativeFileDialogExtensions(from: filters) else { return nil }
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

    private func alertStyle(from type: String?) -> NSAlert.Style {
        switch type {
        case "warning":
            return .warning
        case "error":
            return .critical
        default:
            return .informational
        }
    }

    // review M2 (defense-in-depth): the default file scope is broad (the home dir), so even a benign
    // XSS in the Goose UI could otherwise read credentials or write persistence/RCE payloads. Deny —
    // for BOTH read and write — a small set of sensitive home-relative locations that are never
    // legitimate project-file targets. This does NOT narrow the legitimate project scope.
    nonisolated private static let sensitiveHomeRelativeDirs = [
        ".ssh", ".aws", ".gnupg", ".config/gh", ".config/git",
        ".docker", ".kube",
        "Library/Keychains", "Library/LaunchAgents",
        "Library/Cookies", "Library/Messages", "Library/Mail",
    ]
    nonisolated private static let sensitiveHomeRelativeFiles = [
        ".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile", ".netrc",
        ".git-credentials", ".npmrc", ".pypirc",
    ]

    private func isSensitivePath(_ path: String) -> Bool {
        // Deny known-sensitive home locations for BOTH read and write. Two hardening rules the first
        // cut missed (review HIGH-1/HIGH-2):
        //  • case-INSENSITIVE match — the default macOS volume is case-insensitive, so ~/.SSH and
        //    ~/.ZSHRC open the real ~/.ssh / ~/.zshrc on disk; a case-sensitive denylist was trivially
        //    bypassed. Over-matching a sensitive name on a rare case-sensitive volume is harmless
        //    (fail-closed).
        //  • check the symlink-RESOLVED path too — otherwise a symlink anywhere inside the broad home
        //    scope pointing at ~/.ssh/id_rsa would slip past a purely lexical check.
        let home = Self.standardizedPath(fileManager.homeDirectoryForCurrentUser.path)
        let candidates = [Self.standardizedPath(path), Self.resolvedSymlinkPath(path)]
        for candidate in candidates {
            for dir in Self.sensitiveHomeRelativeDirs
            where Self.path(candidate, isInsideOrEqualTo: home + "/" + dir, caseInsensitive: true) {
                return true
            }
            for file in Self.sensitiveHomeRelativeFiles
            where Self.path(candidate, isInsideOrEqualTo: home + "/" + file, caseInsensitive: true) {
                return true
            }
        }
        return false
    }

    private func isPathAllowed(_ path: String) -> Bool {
        if isSensitivePath(path) { return false }
        let normalizedPath = Self.standardizedPath(path)
        let resolvedPath = Self.resolvedSymlinkPath(normalizedPath)
        return isPathInsideScopedRoot(normalizedPath) && isPathInsideScopedRoot(resolvedPath)
    }

    private func isPathAllowedForWrite(_ path: String) -> Bool {
        if isSymbolicLink(path) { return false }
        // Check the TARGET directly: the parent-dir fallback below would otherwise allow writing a
        // sensitive dotfile (e.g. ~/.zshrc) because its parent (~) is in the broad default scope.
        if isSensitivePath(path) { return false }
        if isPathAllowed(path) { return true }
        let parent = Self.standardizedPath(URL(fileURLWithPath: path).deletingLastPathComponent().path)
        if isSensitivePath(parent) { return false }
        return isPathAllowed(parent)
    }

    private func rememberScopedAccess(for urls: [URL]) {
        for url in urls {
            let path = Self.standardizedPath(url.path)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                rememberScopedRoot(path)
            } else {
                rememberScopedRoot(URL(fileURLWithPath: path).deletingLastPathComponent().path)
                scopedFileRoots.insert(path)
            }
        }
    }

    private func rememberScopedRoot(_ path: String) {
        let standardized = Self.standardizedPath(path)
        scopedFileRoots.insert(standardized)
        scopedFileRoots.insert(Self.resolvedSymlinkPath(standardized))
    }

    private func isPathInsideScopedRoot(_ path: String) -> Bool {
        scopedFileRoots.contains { Self.path(path, isInsideOrEqualTo: $0) }
    }

    private func isSymbolicLink(_ path: String) -> Bool {
        (try? fileManager.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private func exceedsNativeFileReadLimit(_ path: String) -> Bool {
        Self.exceedsNativeFileReadLimit(path, fileManager: fileManager)
    }

    private static func exceedsNativeFileReadLimit(_ path: String, fileManager: FileManager) -> Bool {
        let maxBytes = UInt64(Self.maxNativeFileReadBytes)
        for candidate in [Self.resolvedSymlinkPath(path), path] {
            if let size = fileSize(atPath: candidate, fileManager: fileManager) {
                return size > maxBytes
            }
        }
        return false
    }

    private nonisolated static func fileSize(atPath path: String, fileManager: FileManager) -> UInt64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.uint64Value
    }

    private func recipeHash(_ recipe: Any?) -> String? {
        guard let data = Self.recipeHashData(from: recipe) else {
            return nil
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func recipeHashData(from recipe: Any?) -> Data? {
        guard let recipe else { return nil }
        if let string = recipe as? String {
            guard string.utf8.count <= Self.maxRecipeHashInputBytes else { return nil }
            return Data(string.utf8)
        }
        guard GooseNativeJSONSizeBudget.permits(
            recipe,
            maxBytes: Self.maxRecipeHashInputBytes,
            maxDepth: Self.maxRecipeHashDepth,
            maxCollectionEntries: Self.maxRecipeHashCollectionEntries
        ),
              JSONSerialization.isValidJSONObject(recipe),
              let data = try? JSONSerialization.data(withJSONObject: recipe, options: [.sortedKeys]),
              data.count <= Self.maxRecipeHashInputBytes else {
            return nil
        }
        return data
    }

    private func appName(from app: [String: Any]) throws -> String {
        guard let rawName = app["name"] as? String,
              let name = Self.normalizedAppName(rawName) else {
            throw GooseWebNativeAffordanceBridgeError.missingArgument("launchApp")
        }
        guard name.count <= Self.maxLaunchedAppNameCharacters else {
            throw GooseWebNativeAffordanceBridgeError.appNameTooLong(Self.maxLaunchedAppNameCharacters)
        }
        return name
    }

    private nonisolated static func normalizedAppName(_ rawName: String) -> String? {
        let withoutControls = String(String.UnicodeScalarView(rawName.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }))
        let trimmed = withoutControls.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func htmlContent(from app: [String: Any], appName: String) throws -> String? {
        if let text = app["text"] as? String {
            guard text.utf8.count <= Self.maxLaunchedAppContentBytes else {
                throw GooseWebNativeAffordanceBridgeError.appContentTooLarge(appName, Self.maxLaunchedAppContentBytes)
            }
            return text
        }
        if let blob = app["blob"] as? String {
            guard blob.utf8.count <= Self.maxEncodedAppContentBytes else {
                throw GooseWebNativeAffordanceBridgeError.appContentTooLarge(appName, Self.maxLaunchedAppContentBytes)
            }
            guard let data = Data(base64Encoded: blob) else { return nil }
            guard data.count <= Self.maxLaunchedAppContentBytes else {
                throw GooseWebNativeAffordanceBridgeError.appContentTooLarge(appName, Self.maxLaunchedAppContentBytes)
            }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func formatAppName(_ name: String) -> String {
        name
            .split(separator: "_")
            .map { part in part.prefix(1).uppercased() + String(part.dropFirst()) }
            .joined(separator: " ")
    }

    private func windowStyleMask(resizable: Bool) -> NSWindow.StyleMask {
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable {
            mask.insert(.resizable)
        }
        return mask
    }

    private func numberArgument(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        default:
            return nil
        }
    }

    private func appWindowDimension(
        _ value: Any?,
        fallback: Double,
        min minValue: Double,
        max maxValue: Double
    ) -> CGFloat {
        guard let dimension = numberArgument(value), dimension.isFinite else {
            return CGFloat(fallback)
        }
        return CGFloat(Swift.min(Swift.max(dimension, minValue), maxValue))
    }

    private static var maxEncodedAppContentBytes: Int {
        ((maxLaunchedAppContentBytes + 2) / 3) * 4
    }

    private func boolArgument(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        default:
            return nil
        }
    }

    nonisolated static func boundedNativeFileDialogExtensions(from filters: [[String: Any]]?) -> [String]? {
        guard let filters else { return nil }
        var seen = Set<String>()
        var extensions: [String] = []
        var inspectedExtensions = 0
        for filter in filters.prefix(Self.maxNativeFileDialogFilters) {
            guard let rawExtensions = filter["extensions"] as? [String] else { continue }
            for rawExtension in rawExtensions {
                guard inspectedExtensions < Self.maxNativeFileDialogExtensions else {
                    return extensions.isEmpty ? nil : extensions
                }
                inspectedExtensions += 1
                guard let fileExtension = boundedNativeFileDialogExtension(rawExtension) else { continue }
                if fileExtension == "*" {
                    return nil
                }
                if seen.insert(fileExtension).inserted {
                    extensions.append(fileExtension)
                    if extensions.count >= Self.maxNativeFileDialogExtensions {
                        return extensions
                    }
                }
            }
        }
        return extensions.isEmpty ? nil : extensions
    }

    private nonisolated static func boundedNativeFileDialogExtension(_ rawExtension: String) -> String? {
        let withoutControls = String(String.UnicodeScalarView(rawExtension.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }))
        let trimmed = withoutControls
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard !trimmed.isEmpty,
              trimmed.count <= Self.maxNativeFileDialogExtensionCharacters,
              trimmed.allSatisfy({ $0 == "*" || $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        return trimmed
    }

    nonisolated static func boundedNativeAffordanceName(_ rawName: String) -> String? {
        let withoutControls = String(String.UnicodeScalarView(rawName.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }))
        let trimmed = withoutControls.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= Self.maxNativeAffordanceNameCharacters else {
            return nil
        }
        return trimmed
    }

    private func intArgument(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        default:
            return nil
        }
    }

    private func checkboxButton(options: [String: Any]) -> NSButton? {
        guard let label = Self.boundedNativeDialogText(
            options["checkboxLabel"] as? String,
            maxCharacters: Self.maxNativeDialogButtonCharacters
        ) else {
            return nil
        }
        let checkbox = NSButton(checkboxWithTitle: label, target: nil, action: nil)
        checkbox.state = (boolArgument(options["checkboxChecked"]) ?? false) ? .on : .off
        return checkbox
    }

    private func dictionaryArgument(_ args: [Any], at index: Int) -> [String: Any]? {
        guard args.indices.contains(index) else { return nil }
        return args[index] as? [String: Any]
    }

    private func stringArgument(_ args: [Any], at index: Int) -> String? {
        guard args.indices.contains(index) else { return nil }
        return args[index] as? String
    }

    private static func defaultApplicationSupportRoot(fileManager: FileManager) -> URL {
        let support = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (support ?? fileManager.temporaryDirectory)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("GooseWebHost", isDirectory: true)
    }

    private static func standardizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func resolvedSymlinkPath(_ path: String) -> String {
        let resolvedPath = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .path
        return standardizedPath(resolvedPath)
    }

    private nonisolated static func directoryEntryPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        let order = lhs.localizedStandardCompare(rhs)
        if order == .orderedSame {
            return lhs < rhs
        }
        return order == .orderedAscending
    }

    private static func path(_ path: String, isInsideOrEqualTo root: String, caseInsensitive: Bool = false) -> Bool {
        var normalizedPath = standardizedPath(path)
        var normalizedRoot = standardizedPath(root)
        if caseInsensitive {
            normalizedPath = normalizedPath.lowercased()
            normalizedRoot = normalizedRoot.lowercased()
        }
        return normalizedPath == normalizedRoot || normalizedPath.hasPrefix(normalizedRoot + "/")
    }
}

enum GooseNativeJSONSizeBudget {
    static func permits(
        _ object: Any,
        maxBytes: Int,
        maxDepth: Int,
        maxCollectionEntries: Int
    ) -> Bool {
        var remaining = maxBytes
        return consume(
            object,
            remaining: &remaining,
            depth: 0,
            maxDepth: maxDepth,
            maxCollectionEntries: maxCollectionEntries
        )
    }

    private static func consume(
        _ object: Any,
        remaining: inout Int,
        depth: Int,
        maxDepth: Int,
        maxCollectionEntries: Int
    ) -> Bool {
        guard depth <= maxDepth else { return false }
        switch object {
        case let dictionary as [String: Any]:
            return consumeDictionary(
                dictionary.map { ($0.key, $0.value) },
                remaining: &remaining,
                depth: depth,
                maxDepth: maxDepth,
                maxCollectionEntries: maxCollectionEntries
            )
        case let dictionary as NSDictionary:
            let entries = dictionary.compactMap { rawKey, rawValue -> (String, Any)? in
                guard let key = rawKey as? String else { return nil }
                return (key, rawValue)
            }
            guard entries.count == dictionary.count else { return false }
            return consumeDictionary(
                entries,
                remaining: &remaining,
                depth: depth,
                maxDepth: maxDepth,
                maxCollectionEntries: maxCollectionEntries
            )
        case let array as [Any]:
            return consumeArray(
                array,
                remaining: &remaining,
                depth: depth,
                maxDepth: maxDepth,
                maxCollectionEntries: maxCollectionEntries
            )
        case let array as NSArray:
            return consumeArray(
                array.map { $0 },
                remaining: &remaining,
                depth: depth,
                maxDepth: maxDepth,
                maxCollectionEntries: maxCollectionEntries
            )
        case let string as String:
            return subtract(stringCost(string), from: &remaining)
        case _ as NSNull:
            return subtract(4, from: &remaining)
        case _ as Bool:
            return subtract(5, from: &remaining)
        case let number as NSNumber:
            return subtract(number.stringValue.utf8.count, from: &remaining)
        default:
            return false
        }
    }

    private static func consumeDictionary(
        _ entries: [(String, Any)],
        remaining: inout Int,
        depth: Int,
        maxDepth: Int,
        maxCollectionEntries: Int
    ) -> Bool {
        guard entries.count <= maxCollectionEntries,
              subtract(2, from: &remaining) else {
            return false
        }
        for (key, value) in entries {
            guard subtract(stringCost(key), from: &remaining),
                  subtract(2, from: &remaining),
                  consume(
                    value,
                    remaining: &remaining,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    maxCollectionEntries: maxCollectionEntries
                  ) else {
                return false
            }
        }
        return true
    }

    private static func consumeArray(
        _ array: [Any],
        remaining: inout Int,
        depth: Int,
        maxDepth: Int,
        maxCollectionEntries: Int
    ) -> Bool {
        guard array.count <= maxCollectionEntries,
              subtract(2, from: &remaining) else {
            return false
        }
        for value in array {
            guard subtract(1, from: &remaining),
                  consume(
                    value,
                    remaining: &remaining,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    maxCollectionEntries: maxCollectionEntries
                  ) else {
                return false
            }
        }
        return true
    }

    private static func stringCost(_ string: String) -> Int {
        let byteCount = string.utf8.count
        guard byteCount <= (Int.max - 2) / 6 else { return Int.max }
        return byteCount * 6 + 2
    }

    private static func subtract(_ cost: Int, from remaining: inout Int) -> Bool {
        guard cost <= remaining else { return false }
        remaining -= cost
        return true
    }
}

private enum GooseWebNativeAffordanceBridgeError: LocalizedError {
    case missingArgument(String)
    case missingAppContent(String)
    case appNameTooLong(Int)
    case appContentTooLarge(String, Int)
    case appWindowLimitExceeded(Int)
    case openFailed(String)
    case disallowed(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            "Missing argument for Epistemos Goose native affordance: \(name)."
        case .missingAppContent(let name):
            "Missing renderable MCP app content for Epistemos Goose app: \(name)."
        case .appNameTooLong(let limit):
            "Epistemos blocked Goose from opening an MCP app with a name over \(limit) characters."
        case .appContentTooLarge(let name, let limit):
            "Epistemos blocked oversized MCP app content for Goose app \(name) (limit: \(limit) bytes)."
        case .appWindowLimitExceeded(let limit):
            "Epistemos blocked Goose from opening another MCP app window (limit: \(limit))."
        case .openFailed(let rawURL):
            "Failed to open Epistemos Goose native URL: \(rawURL)."
        case .disallowed(let rawURL):
            "Epistemos blocked a disallowed Goose native URL scheme: \(rawURL)."
        case .unsupported(let name):
            "Unsupported Epistemos Goose native affordance: \(name)."
        }
    }
}

private enum PreferenceKey {
    static let showMenuBarIcon = "epistemos.goose.showMenuBarIcon"
    static let showDockIcon = "epistemos.goose.showDockIcon"
    static let enableWakelock = "epistemos.goose.enableWakelock"
    static let spellcheckEnabled = "epistemos.goose.spellcheckEnabled"
}

@MainActor
private final class GooseWebNativeAppWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

/// SECURITY (deep-hardening 2026-06-29 #14): navigation gate for MCP-app guest webviews. The guest
/// HTML is attacker-influenced, so the top frame may only render the initial widget (its
/// app-support render root) + about:; registered loopback http(s) document navigation is allowed,
/// but ANY external origin, arbitrary file: path, ws:/wss:, javascript:/data:/app-deeplink
/// navigation is denied.
/// Mutable byte box handed to a background pipe-drain (review M4).
private nonisolated final class GooseAffordanceDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ data: Data) {
        lock.lock()
        self.data = data
        lock.unlock()
    }

    func load() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private final class GooseWebNativeAppGuestNavigationDelegate: NSObject, WKNavigationDelegate {
    private let allowedFileRoot: String
    private let trustedLoopbackOrigins: GooseTrustedLoopbackOrigins?

    init(allowedFileRoot: URL?, trustedLoopbackOrigins: GooseTrustedLoopbackOrigins?) {
        self.allowedFileRoot = allowedFileRoot?.standardizedFileURL.path ?? ""
        self.trustedLoopbackOrigins = trustedLoopbackOrigins
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        switch url.scheme?.lowercased() {
        case "about":
            decisionHandler(.allow)
        case "file":
            let path = url.standardizedFileURL.path
            let allowed = !allowedFileRoot.isEmpty
                && (path == allowedFileRoot || path.hasPrefix(allowedFileRoot + "/"))
            decisionHandler(allowed ? .allow : .cancel)
        case "http", "https":
            // review M1: pin to the REGISTERED loopback ports (the goose/goosed + UI servers), NOT
            // any loopback host — otherwise an MCP app could navigate its top frame to another local
            // service (a local model server / notebook-with-token / an admin panel) as a same-origin
            // SSRF pivot. Fall back to host-only loopback only when the registered set isn't wired.
            let allowed: Bool
            if let trustedLoopbackOrigins {
                allowed = trustedLoopbackOrigins.isAllowed(url)
            } else {
                allowed = GooseTrustedLoopbackOrigins.isLoopback(url.host)
            }
            decisionHandler(allowed ? .allow : .cancel)
        default:
            decisionHandler(.cancel)
        }
    }
}
