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
    nonisolated static let maxGitWorktreeEntries = 10
    nonisolated static let maxGitWorktreeListBytes = 4 * 1024 * 1024
    nonisolated static let maxGitStatusBytes = 64 * 1024
    nonisolated static let maxGitDiffBytes = 256 * 1024
    nonisolated static let maxGitWorktreePathCharacters = 4_096
    nonisolated static let maxGitBranchNameCharacters = 256
    nonisolated static let maxGitRemoteURLCharacters = 2_048
    nonisolated static let maxNativeAffordanceNameCharacters = 96
    nonisolated static let maxLaunchedAppNameCharacters = 128
    nonisolated static let maxRecentDirsFileBytes = 64 * 1024
    nonisolated static let maxNativeSettingKeyCharacters = 160
    nonisolated static let maxNativeSettingJSONBytes = 256 * 1024
    nonisolated static let maxNativeSettingsEntries = 512
    nonisolated static let maxNativeSettingDepth = 32
    nonisolated static let maxNativeSettingCollectionEntries = 4_096
    nonisolated static let maxImportedApps = 32
    nonisolated static let maxImportedAppsStoreBytes = 64 * 1024 * 1024
    nonisolated static let maxImportedAppHTMLBytes = 16 * 1024 * 1024
    nonisolated static let maxImportedAppNameCharacters = 128
    nonisolated static let maxImportedAppsCollectionEntries = 4_096
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
    nonisolated static let maxAllowedExtensionsURLCharacters = 4_096
    nonisolated static let maxAllowedExtensionsBytes = 256 * 1024
    nonisolated static let maxAllowedExtensions = 1_024
    nonisolated static let maxAllowedExtensionCommandCharacters = 512
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
    private let importedAppsURL: URL
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
        self.importedAppsURL = root
            .appendingPathComponent("imported-apps", isDirectory: true)
            .appendingPathComponent("apps.json", isDirectory: false)
        self.recipeHashesRoot = root.appendingPathComponent("recipe-hashes", isDirectory: true)
        let configuredFileRoots = initialScopedFileRoots ?? []
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

        if name == "getAllowedExtensions" {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    replyHandler(try await getAllowedExtensions(), nil)
                } catch {
                    replyHandler(nil, Self.nativeErrorMessage(for: error))
                }
            }
            return
        }

        // The git-worktree affordance spawns a Process() and waits up to 3s; running it on
        // @MainActor (the sync handleAffordance path) FROZE the UI for ~3s every time the Goose
        // surface's directory chip (DirSwitcher) queried worktrees on transition. Route it
        // off-main, mirroring the getAllowedExtensions carve-out above. (goose-3s 2026-07-01)
        #if !EPISTEMOS_APP_STORE
        if name == "listGitWorktreeDirs" {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    guard let path = self.stringArgument(args, at: 0) else {
                        throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
                    }
                    replyHandler(await self.listGitWorktreeDirsOffMain(path), nil)
                } catch {
                    replyHandler(nil, Self.nativeErrorMessage(for: error))
                }
            }
            return
        }
        #endif

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
        case "reactReady":
            return true
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
            // App Review 2.5.2 (MAS self-containment): no external app-launch / openURL
            // seam is reachable from the Goose WebUI on the App Store build.
            #if EPISTEMOS_APP_STORE
            throw GooseWebNativeAffordanceBridgeError.proOnlyInAppStore(name)
            #else
            guard let rawURL = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try openExternal(rawURL)
            return nil
            #endif
        case "openInChrome":
            #if EPISTEMOS_APP_STORE
            throw GooseWebNativeAffordanceBridgeError.proOnlyInAppStore(name)
            #else
            guard let rawURL = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try openBrowserURL(rawURL)
            return nil
            #endif
        case "openDirectoryInExplorer":
            #if EPISTEMOS_APP_STORE
            return false
            #else
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return openDirectory(path)
            #endif
        case "getBinaryPath":
            // Binary discovery only serves the (Pro-only) subprocess seams; on the
            // App Store build return the "not found" sentinel so nothing is locatable.
            #if EPISTEMOS_APP_STORE
            return ""
            #else
            guard let binaryName = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return resolveBinaryPath(binaryName)
            #endif
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
            // App Review 2.5.2: the `git` subprocess seam is Pro-only; return an
            // empty roster on the App Store build so no Process() is ever spawned.
            #if EPISTEMOS_APP_STORE
            return [[String: Any]]()
            #else
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return listGitWorktreeDirs(path)
            #endif
        case "readGitDiff":
            #if EPISTEMOS_APP_STORE
            return [
                "ok": false,
                "error": "Git diff is Pro-only and is not available in the App Store build.",
            ] as [String: Any]
            #else
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return readGitDiff(path)
            #endif
        case "readGitHubCompareURL":
            #if EPISTEMOS_APP_STORE
            return [
                "ok": false,
                "error": "GitHub compare is Pro-only and is not available in the App Store build.",
            ] as [String: Any]
            #else
            guard let path = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return readGitHubCompareURL(path)
            #endif
        case "launchApp":
            // App Review 2.5.2: gate the MCP-app launch seam on the App Store build.
            #if EPISTEMOS_APP_STORE
            throw GooseWebNativeAffordanceBridgeError.proOnlyInAppStore(name)
            #else
            guard let app = dictionaryArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try launchApp(app)
            return nil
            #endif
        case "refreshApp":
            #if EPISTEMOS_APP_STORE
            throw GooseWebNativeAffordanceBridgeError.proOnlyInAppStore(name)
            #else
            guard let app = dictionaryArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            try refreshApp(app)
            return nil
            #endif
        case "closeApp":
            guard let appName = stringArgument(args, at: 0) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            closeApp(name: appName)
            return nil
        case "openNotificationsSettings":
            // App Review 2.5.2: opens System Settings via NSWorkspace — gate on MAS.
            #if EPISTEMOS_APP_STORE
            return false
            #else
            return openNotificationsSettings()
            #endif
        case "showNotification":
            return showNotification(dictionaryArgument(args, at: 0) ?? [:])
        case "checkForOllama":
            // App Review 2.5.2: local Ollama detection is a subprocess-lane probe with
            // no honest MAS meaning — report absent on the App Store build.
            #if EPISTEMOS_APP_STORE
            return false
            #else
            return checkForOllama()
            #endif
        case "getAllowedExtensions":
            return []
        case "setWindowTitle":
            guard let title = Self.boundedNativeWindowTitle(stringArgument(args, at: 0)) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setWindowTitle(title)
        case "hideWindow":
            return hideWindow()
        case "getSetting":
            guard let key = Self.boundedNativeSettingKey(stringArgument(args, at: 0)) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return nativeSetting(forKey: key)
        case "setSetting":
            guard let key = Self.boundedNativeSettingKey(stringArgument(args, at: 0)),
                  args.indices.contains(1) else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return setNativeSetting(args[1], forKey: key)
        case "listImportedApps":
            return listImportedApps()
        case "saveImportedApps":
            guard let apps = args.first as? [[String: Any]] else {
                throw GooseWebNativeAffordanceBridgeError.missingArgument(name)
            }
            return try saveImportedApps(apps)
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
        case "isAnyWindowFocused":
            return isAnyWindowFocused()
        case "getIsFullScreen":
            return getIsFullScreen()
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
        case "epistemos.context.snapshot":
            return GooseAppContextSnapshot.current().dictionary
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

    nonisolated static func boundedNativeWindowTitle(_ rawText: String?) -> String? {
        boundedNativeDialogText(
            rawText,
            maxCharacters: maxNativeDialogTitleCharacters,
            fallback: "Epistemos Goose"
        )
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

    private func gitProcessEnvironment(git: String) -> [String: String] {
        let gitDir = URL(fileURLWithPath: git, isDirectory: false).deletingLastPathComponent().path
        return [
            "PATH": "\(gitDir):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
            "HOME": fileManager.homeDirectoryForCurrentUser.path,
            "LANG": "en_US.UTF-8",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0",
        ]
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

    /// FAST @MainActor validation (filesystem stats + scoped-root allow-check) shared by the
    /// sync + off-main callers. Returns the resolved git binary, expanded path, and minimal
    /// env, or nil when the path isn't allowed / isn't a real directory.
    private func gitWorktreeInvocation(for path: String) -> (git: String, expandedPath: String, env: [String: String])? {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        var isDirectory: ObjCBool = false
        guard isPathAllowed(expandedPath),
              fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return nil
        }
        let git = resolveBinaryPath("git")
        guard !git.isEmpty else { return nil }
        return (git, expandedPath, gitProcessEnvironment(git: git))
    }

    private func listGitWorktreeDirs(_ path: String) -> [[String: Any]] {
        // Owner 2026-07-01: DISABLED — `git worktree list` on this large repo takes seconds and
        // the Goose directory chip runs it on every transition (the perceived Goose hang). The
        // worktree roster is non-essential; return empty. (re-enable: restore the invocation below)
        []
    }

    /// Off-main variant. The git Process()+semaphore.wait(+3) blocked @MainActor and was the
    /// exact 3-second freeze when the Goose surface's directory chip (DirSwitcher) queried git
    /// worktrees as the surface became active. Validation stays on @MainActor (fast fs stats);
    /// only the subprocess wait is detached. Behavior/timeouts/caps are identical. (goose-3s 2026-07-01)
    private func listGitWorktreeDirsOffMain(_ path: String) async -> [[String: Any]] {
        // Owner 2026-07-01: DISABLED (see listGitWorktreeDirs). Return empty instantly so the
        // Goose directory chip never waits on git. The off-main plumbing + runGitWorktreeList
        // worker remain below for easy re-enable.
        []
    }

    nonisolated static func runGitWorktreeList(
        git: String,
        expandedPath: String,
        environment: [String: String]
    ) -> [[String: Any]] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        // review LOW-2: this runs git on a WEB-CHOSEN directory, so neutralize attacker-controlled git
        // config that could run code. `-c core.fsmonitor=false` blocks a malicious repo `.git/config`
        // from spawning an fsmonitor command; `-c protocol.allow=never` blocks any sub-fetch.
        process.arguments = [
            "-c", "core.fsmonitor=false",
            "-c", "protocol.allow=never",
            "-C", expandedPath, "worktree", "list", "--porcelain",
        ]
        // Minimal env computed on @MainActor by the caller (gitWorktreeInvocation) and passed in —
        // DYLD_*/LD_*/Malloc*/NODE_*/PYTHON* stripped + SYSTEM/GLOBAL git config ignored.
        process.environment = environment
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
        var worktrees: [[String: Any]] = []
        var currentPath: String?
        var currentBranch: String?

        func appendCurrentWorktree(stop: inout Bool) {
            guard let path = currentPath,
                  seen.insert(path).inserted else {
                currentPath = nil
                currentBranch = nil
                return
            }

            var item: [String: Any] = ["path": path]
            if let currentBranch {
                item["branch"] = currentBranch
            }
            worktrees.append(item)
            currentPath = nil
            currentBranch = nil
            if worktrees.count >= Self.maxGitWorktreeEntries {
                stop = true
            }
        }

        output.enumerateLines { line, stop in
            if line.hasPrefix("worktree ") {
                appendCurrentWorktree(stop: &stop)
                guard !stop else { return }
                currentPath = Self.boundedGitWorktreePath(String(line.dropFirst("worktree ".count)))
                currentBranch = nil
            } else if line.hasPrefix("branch ") {
                currentBranch = Self.gitWorktreeBranchName(String(line.dropFirst("branch ".count)))
            }
        }
        if worktrees.count < Self.maxGitWorktreeEntries {
            var stop = false
            appendCurrentWorktree(stop: &stop)
        }
        return worktrees
    }

    private func readGitDiff(_ path: String) -> [String: Any] {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        func result(
            ok: Bool,
            status: String? = nil,
            branch: String? = nil,
            pullRequestURL: String? = nil,
            pullRequestSearchURL: String? = nil,
            diff: String = "",
            truncated: Bool = false,
            error: String? = nil
        ) -> [String: Any] {
            let errorValue: Any = error.map { $0 as Any } ?? NSNull()
            let statusValue: Any = status.map { $0 as Any } ?? NSNull()
            let branchValue: Any = branch.map { $0 as Any } ?? NSNull()
            let pullRequestURLValue: Any = pullRequestURL.map { $0 as Any } ?? NSNull()
            let pullRequestSearchURLValue: Any = pullRequestSearchURL.map { $0 as Any } ?? NSNull()
            return [
                "ok": ok,
                "status": statusValue,
                "branch": branchValue,
                "pullRequestURL": pullRequestURLValue,
                "pullRequestSearchURL": pullRequestSearchURLValue,
                "diff": diff,
                "truncated": truncated,
                "path": expandedPath,
                "base": "HEAD",
                "error": errorValue,
            ]
        }

        var isDirectory: ObjCBool = false
        guard isPathAllowed(expandedPath),
              fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return result(
                ok: false,
                error: "Epistemos blocked Goose WebView git diff outside scoped roots."
            )
        }
        let git = resolveBinaryPath("git")
        guard !git.isEmpty else {
            return result(ok: false, error: "Git is unavailable.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        process.arguments = [
            "-c", "core.fsmonitor=false",
            "-c", "protocol.allow=never",
            "-c", "diff.external=",
            "-c", "core.pager=cat",
            "-C", expandedPath,
            "diff",
            "--no-ext-diff",
            "--no-textconv",
            "--no-color",
            "--find-renames",
            "HEAD",
            "--",
        ]
        process.environment = gitProcessEnvironment(git: git)
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let stdoutHandle = stdout.fileHandleForReading
        let drainBox = GooseAffordanceDataBox()
        let drainDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            drainBox.store(Self.readBoundedPipeData(
                stdoutHandle,
                maxBytes: Self.maxGitDiffBytes
            ))
            drainDone.signal()
        }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return result(ok: false, error: "Git diff could not start.")
        }
        if semaphore.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            return result(ok: false, error: "Git diff timed out.")
        }
        _ = drainDone.wait(timeout: .now() + 1)
        guard process.terminationStatus == 0 else {
            return result(ok: false, error: "No git diff is available for this directory.")
        }

        let outputData = drainBox.load()
        let truncated = outputData.count > Self.maxGitDiffBytes
        let boundedData = truncated ? Data(outputData.prefix(Self.maxGitDiffBytes)) : outputData
        let diff = String(data: boundedData, encoding: .utf8) ?? ""
        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return result(ok: false, error: "No tracked changes to attach.")
        }
        let status = readGitStatus(expandedPath, git: git)
        let pullRequest = gitHubPullRequestContext(expandedPath, git: git)
        return result(
            ok: true,
            status: status,
            branch: pullRequest?.branch,
            pullRequestURL: pullRequest?.url,
            pullRequestSearchURL: pullRequest?.searchURL,
            diff: diff,
            truncated: truncated
        )
    }

    private func gitHubPullRequestContext(_ path: String, git: String) -> (
        url: String,
        searchURL: String,
        branch: String
    )? {
        guard let branch = readGitSingleLine(
            path,
            git: git,
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            maxBytes: Self.maxGitBranchNameCharacters + 1
        ).flatMap(Self.boundedGitBranchName),
              branch != "HEAD",
              let remote = readGitSingleLine(
                path,
                git: git,
                arguments: ["remote", "get-url", "origin"],
                maxBytes: Self.maxGitRemoteURLCharacters + 1
              ).flatMap(Self.boundedGitRemoteURL),
              let repositoryPath = Self.gitHubRepositoryPath(from: remote),
              let pullRequestURL = Self.gitHubCompareURL(repositoryPath: repositoryPath, branch: branch),
              let pullRequestSearchURL = Self.gitHubPullRequestSearchURL(
                repositoryPath: repositoryPath,
                branch: branch
              ) else {
            return nil
        }
        return (url: pullRequestURL, searchURL: pullRequestSearchURL, branch: branch)
    }

    private func readGitStatus(_ path: String, git: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        process.arguments = [
            "-c", "core.fsmonitor=false",
            "-c", "protocol.allow=never",
            "-C", path,
            "status",
            "--short",
            "--branch",
            "--untracked-files=normal",
        ]
        process.environment = gitProcessEnvironment(git: git)
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let stdoutHandle = stdout.fileHandleForReading
        let drainBox = GooseAffordanceDataBox()
        let drainDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            drainBox.store(Self.readBoundedPipeData(
                stdoutHandle,
                maxBytes: Self.maxGitStatusBytes
            ))
            drainDone.signal()
        }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            process.terminate()
            return nil
        }
        _ = drainDone.wait(timeout: .now() + 1)
        guard process.terminationStatus == 0 else { return nil }

        let outputData = drainBox.load()
        guard outputData.count <= Self.maxGitStatusBytes else { return nil }
        let status = String(data: outputData, encoding: .utf8) ?? ""
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedStatus.isEmpty ? nil : trimmedStatus
    }

    private func readGitHubCompareURL(_ path: String) -> [String: Any] {
        let expandedPath = Self.standardizedPath(expandTilde(path))
        func result(
            ok: Bool,
            url: String? = nil,
            pullRequestSearchURL: String? = nil,
            branch: String? = nil,
            error: String? = nil
        ) -> [String: Any] {
            let urlValue: Any = url.map { $0 as Any } ?? NSNull()
            let pullRequestSearchURLValue: Any = pullRequestSearchURL.map { $0 as Any } ?? NSNull()
            let branchValue: Any = branch.map { $0 as Any } ?? NSNull()
            let errorValue: Any = error.map { $0 as Any } ?? NSNull()
            return [
                "ok": ok,
                "url": urlValue,
                "pullRequestSearchURL": pullRequestSearchURLValue,
                "branch": branchValue,
                "path": expandedPath,
                "error": errorValue,
            ]
        }

        var isDirectory: ObjCBool = false
        guard isPathAllowed(expandedPath),
              fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isSymbolicLink(expandedPath) else {
            return result(
                ok: false,
                error: "Epistemos blocked Goose WebView git compare outside scoped roots."
            )
        }
        let git = resolveBinaryPath("git")
        guard !git.isEmpty else {
            return result(ok: false, error: "Git is unavailable.")
        }
        guard let branch = readGitSingleLine(
            expandedPath,
            git: git,
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            maxBytes: Self.maxGitBranchNameCharacters + 1
        ).flatMap(Self.boundedGitBranchName),
              branch != "HEAD" else {
            return result(ok: false, error: "No current git branch is available.")
        }
        guard let remote = readGitSingleLine(
            expandedPath,
            git: git,
            arguments: ["remote", "get-url", "origin"],
            maxBytes: Self.maxGitRemoteURLCharacters + 1
        ).flatMap(Self.boundedGitRemoteURL) else {
            return result(ok: false, branch: branch, error: "No origin remote is available.")
        }
        guard let repositoryPath = Self.gitHubRepositoryPath(from: remote),
              let pullRequestURL = Self.gitHubCompareURL(repositoryPath: repositoryPath, branch: branch),
              let pullRequestSearchURL = Self.gitHubPullRequestSearchURL(
                repositoryPath: repositoryPath,
                branch: branch
              ) else {
            return result(ok: false, branch: branch, error: "The origin remote cannot open a GitHub pull request.")
        }
        return result(ok: true, url: pullRequestURL, pullRequestSearchURL: pullRequestSearchURL, branch: branch)
    }

    private func readGitSingleLine(
        _ path: String,
        git: String,
        arguments: [String],
        maxBytes: Int
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git, isDirectory: false)
        process.arguments = [
            "-c", "core.fsmonitor=false",
            "-c", "protocol.allow=never",
            "-C", path,
        ] + arguments
        process.environment = gitProcessEnvironment(git: git)
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let stdoutHandle = stdout.fileHandleForReading
        let drainBox = GooseAffordanceDataBox()
        let drainDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            drainBox.store(Self.readBoundedPipeData(stdoutHandle, maxBytes: maxBytes))
            drainDone.signal()
        }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            process.terminate()
            return nil
        }
        _ = drainDone.wait(timeout: .now() + 1)
        guard process.terminationStatus == 0 else { return nil }

        let outputData = drainBox.load()
        guard outputData.count <= maxBytes else { return nil }
        let line = (String(data: outputData, encoding: .utf8) ?? "")
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return line?.isEmpty == false ? line : nil
    }

    nonisolated static func boundedGitBranchName(_ branch: String) -> String? {
        let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxGitBranchNameCharacters,
              !trimmed.contains(".."),
              !trimmed.contains("\\"),
              !trimmed.hasPrefix("-"),
              !trimmed.hasPrefix("/"),
              !trimmed.hasSuffix("/") else {
            return nil
        }
        let blocked = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: " ~^:?*["))
        guard trimmed.unicodeScalars.allSatisfy({ !blocked.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    nonisolated static func gitWorktreeBranchName(_ ref: String) -> String? {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "refs/heads/"
        let branch = trimmed.hasPrefix(prefix) ? String(trimmed.dropFirst(prefix.count)) : trimmed
        return boundedGitBranchName(branch)
    }

    nonisolated static func boundedGitRemoteURL(_ remote: String) -> String? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxGitRemoteURLCharacters,
              !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    nonisolated static func gitHubRepositoryPath(from remote: String) -> String? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPath: String?
        if let url = URL(string: trimmed),
           url.host?.lowercased() == "github.com" {
            rawPath = url.path
        } else if trimmed.hasPrefix("git@github.com:") {
            rawPath = "/" + String(trimmed.dropFirst("git@github.com:".count))
        } else {
            rawPath = nil
        }

        guard let rawPath else { return nil }
        let cleaned = rawPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "", options: [.anchored, .backwards])
        let parts = cleaned.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let owner = String(parts[0])
        let repo = String(parts[1])
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !owner.isEmpty,
              !repo.isEmpty,
              owner.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              repo.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return "\(owner)/\(repo)"
    }

    nonisolated static func gitHubCompareURL(repositoryPath: String, branch: String) -> String? {
        guard let branch = boundedGitBranchName(branch) else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?#[]@")
        guard let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return "https://github.com/\(repositoryPath)/compare/\(encodedBranch)?expand=1"
    }

    nonisolated static func gitHubPullRequestSearchURL(repositoryPath: String, branch: String) -> String? {
        guard let branch = boundedGitBranchName(branch),
              var components = URLComponents(string: "https://github.com/\(repositoryPath)/pulls") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: "is:pr head:\(branch)"),
        ]
        return components.url?.absoluteString
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

    private func checkForOllama() -> Bool {
        Self.checkForOllamaHostConfigured(environment: ProcessInfo.processInfo.environment) ||
            !resolveBinaryPath("ollama").isEmpty ||
            Self.checkForOllamaRunningApp()
    }

    private func getAllowedExtensions() async throws -> [String] {
        guard let url = Self.allowedExtensionsURL(environment: ProcessInfo.processInfo.environment) else {
            return []
        }

        let data: Data
        if url.isFileURL {
            data = try Self.readAllowedExtensionsFile(url)
        } else {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard responseData.count <= Self.maxAllowedExtensionsBytes else {
                throw GooseWebNativeAffordanceBridgeError.disallowed("GOOSE_ALLOWLIST over size limit")
            }
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw GooseWebNativeAffordanceBridgeError.openFailed(
                    "GOOSE_ALLOWLIST fetch failed with HTTP \(http.statusCode)"
                )
            }
            data = responseData
        }

        guard let yaml = String(data: data, encoding: .utf8) else {
            throw GooseWebNativeAffordanceBridgeError.disallowed("GOOSE_ALLOWLIST is not UTF-8")
        }
        return Self.allowedExtensionCommands(fromYAML: yaml)
    }

    nonisolated static func allowedExtensionsURL(environment: [String: String]) -> URL? {
        guard let rawValue = environment["GOOSE_ALLOWLIST"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              rawValue.utf8.count <= maxAllowedExtensionsURLCharacters,
              !rawValue.utf8.contains(0) else {
            return nil
        }
        if rawValue.hasPrefix("/") {
            return URL(fileURLWithPath: rawValue)
        }
        guard let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              ["https", "http", "file"].contains(scheme) else {
            return nil
        }
        return url
    }

    nonisolated static func allowedExtensionCommands(fromYAML yaml: String) -> [String] {
        var commands: [String] = []
        for line in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
            guard commands.count < maxAllowedExtensions else { break }
            let withoutComment = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            var trimmed = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("- ") {
                trimmed = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard trimmed.hasPrefix("command:") else { continue }
            let rawCommand = String(trimmed.dropFirst("command:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let command = boundedAllowedExtensionCommand(rawCommand) else { continue }
            commands.append(command)
        }
        return commands
    }

    nonisolated private static func boundedAllowedExtensionCommand(_ rawCommand: String) -> String? {
        var command = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if command.count >= 2,
           let first = command.first,
           let last = command.last,
           (first == "\"" && last == "\"" || first == "'" && last == "'") {
            command = String(command.dropFirst().dropLast())
        }
        guard !command.isEmpty,
              command.count <= maxAllowedExtensionCommandCharacters,
              !command.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return command
    }

    nonisolated private static func readAllowedExtensionsFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }
        let data = try handle.read(upToCount: maxAllowedExtensionsBytes + 1) ?? Data()
        guard data.count <= maxAllowedExtensionsBytes else {
            throw GooseWebNativeAffordanceBridgeError.disallowed("GOOSE_ALLOWLIST over size limit")
        }
        return data
    }

    nonisolated static func checkForOllamaHostConfigured(environment: [String: String]) -> Bool {
        guard let rawValue = environment["OLLAMA_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              rawValue.utf8.count <= maxNativeOpenURLCharacters else {
            return false
        }
        guard let url = URL(string: rawValue), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return webProtocols.contains(scheme)
    }

    private static func checkForOllamaRunningApp() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            let bundleID = application.bundleIdentifier?.lowercased()
            let appName = application.localizedName?.lowercased()
            return bundleID == "com.ollama.ollama" || appName == "ollama"
        }
    }

    private func setWindowTitle(_ title: String) -> Bool {
        guard let window = targetHostWindow() else { return false }
        window.title = title
        return true
    }

    private func hideWindow() -> Bool {
        guard let window = targetHostWindow() else { return false }
        window.orderOut(nil)
        return true
    }

    private func isAnyWindowFocused() -> Bool {
        NSApp.windows.contains { $0.isKeyWindow || $0.isMainWindow }
    }

    private func getIsFullScreen() -> Bool {
        guard let window = targetHostWindow() else { return false }
        return window.styleMask.contains(.fullScreen)
    }

    private func targetHostWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
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

    private func nativeSetting(forKey key: String) -> [String: Any] {
        guard let rawValue = nativeSettingsStore()[key],
              rawValue.utf8.count <= Self.maxNativeSettingJSONBytes,
              let data = rawValue.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope.keys.contains("value") else {
            return ["found": false]
        }
        return [
            "found": true,
            "value": envelope["value"] ?? NSNull(),
        ]
    }

    private func setNativeSetting(_ value: Any, forKey key: String) -> Bool {
        if value is NSNull {
            var store = nativeSettingsStore()
            store.removeValue(forKey: key)
            preferences.set(store, forKey: PreferenceKey.nativeSettingsStore)
            return true
        }

        guard Self.nativeSettingValueIsPersistable(value),
              let rawValue = Self.encodedNativeSettingValue(value) else {
            return false
        }

        var store = nativeSettingsStore()
        guard store[key] != nil || store.count < Self.maxNativeSettingsEntries else {
            return false
        }
        store[key] = rawValue
        preferences.set(store, forKey: PreferenceKey.nativeSettingsStore)
        return true
    }

    private func nativeSettingsStore() -> [String: String] {
        let rawStore = preferences.dictionary(forKey: PreferenceKey.nativeSettingsStore) ?? [:]
        var store: [String: String] = [:]
        for (rawKey, rawValue) in rawStore {
            guard let key = Self.boundedNativeSettingKey(rawKey),
                  let value = rawValue as? String,
                  value.utf8.count <= Self.maxNativeSettingJSONBytes else {
                continue
            }
            store[key] = value
        }
        return store
    }

    private nonisolated static func nativeSettingValueIsPersistable(_ value: Any) -> Bool {
        GooseNativeJSONSizeBudget.permits(
            value,
            maxBytes: Self.maxNativeSettingJSONBytes,
            maxDepth: Self.maxNativeSettingDepth,
            maxCollectionEntries: Self.maxNativeSettingCollectionEntries
        )
    }

    private nonisolated static func encodedNativeSettingValue(_ value: Any) -> String? {
        let envelope: [String: Any] = ["value": value]
        guard JSONSerialization.isValidJSONObject(envelope),
              let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]),
              data.count <= Self.maxNativeSettingJSONBytes else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func listImportedApps() -> [[String: Any]] {
        guard let data = try? Self.readImportedAppsFile(importedAppsURL),
              let rawApps = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return Self.sanitizedImportedApps(rawApps)
    }

    private func saveImportedApps(_ rawApps: [[String: Any]]) throws -> Bool {
        let apps = Self.sanitizedImportedApps(rawApps)
        guard GooseNativeJSONSizeBudget.permits(
            apps,
            maxBytes: Self.maxImportedAppsStoreBytes,
            maxDepth: Self.maxNativeSettingDepth,
            maxCollectionEntries: Self.maxImportedAppsCollectionEntries
        ) else {
            throw GooseWebNativeAffordanceBridgeError.disallowed("imported apps store over size limit")
        }
        let data = try JSONSerialization.data(withJSONObject: apps, options: [.sortedKeys])
        guard data.count <= Self.maxImportedAppsStoreBytes else {
            throw GooseWebNativeAffordanceBridgeError.disallowed("imported apps store over size limit")
        }
        try fileManager.createDirectory(
            at: importedAppsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: importedAppsURL, options: [.atomic])
        return true
    }

    nonisolated private static func readImportedAppsFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }
        let data = try handle.read(upToCount: maxImportedAppsStoreBytes + 1) ?? Data()
        guard data.count <= maxImportedAppsStoreBytes else {
            throw GooseWebNativeAffordanceBridgeError.disallowed("imported apps store over size limit")
        }
        return data
    }

    nonisolated static func sanitizedImportedApps(_ rawApps: [[String: Any]]) -> [[String: Any]] {
        Array(rawApps.compactMap(sanitizedImportedApp).suffix(maxImportedApps))
    }

    nonisolated private static func sanitizedImportedApp(_ rawApp: [String: Any]) -> [String: Any]? {
        guard let uri = boundedImportedAppString(rawApp["uri"], maxCharacters: maxAllowedExtensionsURLCharacters),
              let name = boundedImportedAppString(rawApp["name"], maxCharacters: maxImportedAppNameCharacters),
              let text = boundedImportedAppString(rawApp["text"], maxBytes: maxImportedAppHTMLBytes),
              importedAppMCPServers(rawApp["mcpServers"]).contains("apps") else {
            return nil
        }

        var app: [String: Any] = [
            "uri": uri,
            "name": name,
            "text": text,
            "mcpServers": ["apps"],
        ]
        if let description = boundedImportedAppString(rawApp["description"], maxCharacters: 512) {
            app["description"] = description
        }
        if let mimeType = boundedImportedAppString(rawApp["mimeType"], maxCharacters: 128) {
            app["mimeType"] = mimeType
        }
        if let width = importedAppPositiveInt(rawApp["width"]) {
            app["width"] = width
        }
        if let height = importedAppPositiveInt(rawApp["height"]) {
            app["height"] = height
        }
        if let resizable = rawApp["resizable"] as? Bool {
            app["resizable"] = resizable
        } else if let resizable = rawApp["resizable"] as? NSNumber {
            app["resizable"] = resizable.boolValue
        }
        if let meta = rawApp["_meta"] as? [String: Any],
           GooseNativeJSONSizeBudget.permits(
               meta,
               maxBytes: 16 * 1024,
               maxDepth: 8,
               maxCollectionEntries: 256
           ) {
            app["_meta"] = meta
        }
        return app
    }

    nonisolated private static func boundedImportedAppString(
        _ value: Any?,
        maxCharacters: Int
    ) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        return trimmed
    }

    nonisolated private static func boundedImportedAppString(
        _ value: Any?,
        maxBytes: Int
    ) -> String? {
        guard let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= maxBytes,
              !text.utf8.contains(0) else {
            return nil
        }
        return text
    }

    nonisolated private static func importedAppMCPServers(_ value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { $0 as? String }
    }

    nonisolated private static func importedAppPositiveInt(_ value: Any?) -> Int? {
        let intValue: Int?
        switch value {
        case let value as Int:
            intValue = value
        case let value as NSNumber:
            intValue = value.intValue
        default:
            intValue = nil
        }
        guard let intValue, intValue > 0, intValue <= 4_096 else { return nil }
        return intValue
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

    // Defense-in-depth for explicitly scoped home paths: even after a user grants a broad directory,
    // a benign XSS in the Goose UI must not read credentials or write persistence/RCE payloads.
    // Deny, for BOTH read and write, sensitive home-relative locations that are never legitimate
    // project-file targets.
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
        //  • check the symlink-RESOLVED path too - otherwise a symlink anywhere inside an explicitly
        //    scoped home path pointing at ~/.ssh/id_rsa would slip past a purely lexical check.
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
        // sensitive dotfile (e.g. ~/.zshrc) because its parent was explicitly scoped.
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

    nonisolated static func boundedNativeSettingKey(_ rawKey: String?) -> String? {
        guard let rawKey else { return nil }
        let withoutControls = String(String.UnicodeScalarView(rawKey.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }))
        let trimmed = withoutControls.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= Self.maxNativeSettingKeyCharacters else {
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

nonisolated enum GooseNativeJSONSizeBudget {
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
    case proOnlyInAppStore(String)

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
        case .proOnlyInAppStore(let name):
            "The Goose native affordance \"\(name)\" is Pro-only and is not available in the App Store build."
        }
    }
}

private enum PreferenceKey {
    static let showMenuBarIcon = "epistemos.goose.showMenuBarIcon"
    static let showDockIcon = "epistemos.goose.showDockIcon"
    static let enableWakelock = "epistemos.goose.enableWakelock"
    static let spellcheckEnabled = "epistemos.goose.spellcheckEnabled"
    static let nativeSettingsStore = "epistemos.goose.nativeSettings"
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
/// Ferries a non-Sendable [[String: Any]] affordance result across the actor boundary from an
/// off-main worker back to the @MainActor bridge. `nonisolated` so its init runs off-main under
/// the module's SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor. (goose-3s 2026-07-01)
private nonisolated final class GooseAffordanceResultBox: @unchecked Sendable {
    let value: [[String: Any]]
    init(value: [[String: Any]]) { self.value = value }
}

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
