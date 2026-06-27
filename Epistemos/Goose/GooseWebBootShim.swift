import Foundation

enum GooseWebAffordanceDisposition: String, Equatable, Sendable {
    case implementedNative = "implemented-native"
    case implementedRuntime = "implemented-runtime"
    case hiddenShell = "hidden-shell"
    case compatibilityPreserved = "compatibility-preserved"
    case deferredWithVisibleError = "deferred-with-visible-error"
}

struct GooseWebConfig: Equatable, Sendable {
    var version: String?
    var bundleName: String = "Epistemos"
    var useACPChat: Bool = true
    var workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    nonisolated var dictionary: [String: Any] {
        var value: [String: Any] = [
            "GOOSE_ALLOWLIST_WARNING": false,
            "GOOSE_BUNDLE_NAME": bundleName,
            "GOOSE_WORKING_DIR": workingDirectory,
            "USE_ACP_CHAT": useACPChat,
        ]
        if let version {
            value["GOOSE_VERSION"] = version
        }
        return value
    }
}

struct GooseWebBootstrap: Equatable, Sendable {
    let baseURL: URL
    let secretKey: String
    var config: GooseWebConfig = GooseWebConfig()

    var runtimeBaseURL: String {
        var value = baseURL.absoluteString
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    var acpURL: String {
        GooseRuntimeSupervisor.acpWebSocketURL(base: baseURL, secretKey: secretKey)?.absoluteString ?? ""
    }

    var appConfigDictionary: [String: Any] {
        var value = config.dictionary
        value["GOOSE_API_HOST"] = runtimeBaseURL
        return value
    }

    var platform: String { "darwin" }

    var arch: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x64"
        #else
        return "unknown"
        #endif
    }
}

enum GooseWebBootShim {
    static let dispositionLedger: [String: GooseWebAffordanceDisposition] = [
        "addRecentDir": .compatibilityPreserved,
        "appConfig.get": .implementedNative,
        "appConfig.getAll": .implementedNative,
        "arch": .implementedNative,
        "broadcastThemeChange": .implementedNative,
        "getGoosedHostPort": .implementedRuntime,
        "getSecretKey": .implementedRuntime,
        "getAcpUrl": .implementedRuntime,
        "getConfig": .implementedNative,
        "getSetting": .implementedNative,
        "setSetting": .implementedNative,
        "platform": .implementedNative,
        "reactReady": .compatibilityPreserved,
        "on": .compatibilityPreserved,
        "off": .compatibilityPreserved,
        "emit": .compatibilityPreserved,
        "logInfo": .compatibilityPreserved,
        "hideWindow": .compatibilityPreserved,
        "createChatWindow": .compatibilityPreserved,
        "closeWindow": .compatibilityPreserved,
        "showOpenDialog": .implementedNative,
        "showSaveDialog": .implementedNative,
        "showMessageBox": .deferredWithVisibleError,
        "directoryChooser": .implementedNative,
        "selectFileOrDirectory": .implementedNative,
        "selectImportSessionFile": .implementedNative,
        "openExternal": .implementedNative,
        "openInChrome": .implementedNative,
        "openDirectoryInExplorer": .implementedNative,
        "getBinaryPath": .deferredWithVisibleError,
        "readFile": .deferredWithVisibleError,
        "writeFile": .deferredWithVisibleError,
        "ensureDirectory": .deferredWithVisibleError,
        "launchApp": .deferredWithVisibleError,
        "refreshApp": .deferredWithVisibleError,
        "closeApp": .deferredWithVisibleError,
        "openNotificationsSettings": .deferredWithVisibleError,
        "showNotification": .compatibilityPreserved,
        "setWindowTitle": .compatibilityPreserved,
        "reloadApp": .compatibilityPreserved,
        "checkForOllama": .compatibilityPreserved,
        "getAllowedExtensions": .compatibilityPreserved,
        "getPathForFile": .compatibilityPreserved,
        "listFiles": .compatibilityPreserved,
        "listRecentDirs": .compatibilityPreserved,
        "listGitWorktreeDirs": .compatibilityPreserved,
        "setMenuBarIcon": .compatibilityPreserved,
        "getMenuBarIconState": .compatibilityPreserved,
        "setDockIcon": .compatibilityPreserved,
        "getDockIconState": .compatibilityPreserved,
        "setWakelock": .compatibilityPreserved,
        "getWakelockState": .compatibilityPreserved,
        "setSpellcheck": .compatibilityPreserved,
        "getSpellcheckState": .compatibilityPreserved,
        "isAnyWindowFocused": .compatibilityPreserved,
        "getIsFullScreen": .compatibilityPreserved,
        "onMouseBackButtonClicked": .compatibilityPreserved,
        "offMouseBackButtonClicked": .compatibilityPreserved,
        "hasAcceptedRecipeBefore": .compatibilityPreserved,
        "recordRecipeHash": .compatibilityPreserved,
        "getVersion": .implementedNative,
        "getUpdateState": .hiddenShell,
        "isUsingGitHubFallback": .hiddenShell,
        "getAutoDownloadDisabled": .hiddenShell,
        "onUpdaterEvent": .hiddenShell,
        "checkForUpdates": .hiddenShell,
        "downloadUpdate": .hiddenShell,
        "installUpdate": .hiddenShell,
        "quitAndInstall": .hiddenShell,
    ]

    static func bootstrapScript(for bootstrap: GooseWebBootstrap) -> String {
        let ledger = dispositionLedger.mapValues(\.rawValue)
        let payload: [String: Any] = [
            "baseURL": bootstrap.runtimeBaseURL,
            "secretKey": bootstrap.secretKey,
            "acpUrl": bootstrap.acpURL,
            "config": bootstrap.appConfigDictionary,
            "settings": defaultSettings,
            "platform": bootstrap.platform,
            "arch": bootstrap.arch,
            "ledger": ledger,
        ]
        let payloadJSON = jsonLiteral(payload)
        return """
        (() => {
          const epistemosGoose = Object.freeze(\(payloadJSON));
          const visibleError = (name) => async () => {
            throw new Error(`Epistemos native host has not implemented ${name} yet.`);
          };
          const nullAffordance = async () => null;
          const trueAffordance = async () => true;
          const falseAffordance = async () => false;
          const undefinedAffordance = async () => undefined;
          const noop = () => undefined;
          const updateUnavailable = async () => ({ success: false, updateInfo: null, error: 'Goose updater shell is disabled in Epistemos.' });
          const clone = (value) => {
            if (value === null || typeof value !== 'object') return value;
            return JSON.parse(JSON.stringify(value));
          };
          const settingsStorageKey = 'epistemos.goose.settings';
          const loadSettings = () => {
            try {
              const stored = JSON.parse(localStorage.getItem(settingsStorageKey) || '{}');
              return Object.assign({}, epistemosGoose.settings, stored);
            } catch {
              return Object.assign({}, epistemosGoose.settings);
            }
          };
          const saveSettings = (settings) => {
            try {
              localStorage.setItem(settingsStorageKey, JSON.stringify(settings));
            } catch {}
          };
          const listeners = new Map();
          const onEvent = (channel, callback) => {
            const bucket = listeners.get(channel) || new Set();
            bucket.add(callback);
            listeners.set(channel, bucket);
          };
          const offEvent = (channel, callback) => {
            const bucket = listeners.get(channel);
            if (!bucket) return;
            bucket.delete(callback);
            if (bucket.size === 0) listeners.delete(channel);
          };
          const emitEvent = (channel, ...args) => {
            const event = Object.freeze({ sender: 'epistemos-goose-webview', channel });
            for (const callback of listeners.get(channel) || []) {
              try { callback(event, ...args); } catch (error) { console.error(error); }
            }
          };
          const getSetting = async (key) => clone(loadSettings()[key]);
          const setSetting = async (key, value) => {
            const settings = loadSettings();
            settings[key] = clone(value);
            saveSettings(settings);
          };
          const showNotification = async (data) => {
            if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
              new Notification(data?.title || 'Epistemos', { body: data?.body || '' });
            }
            return null;
          };
          const postHostPrompt = async (type, request) => {
            const handler = window.webkit?.messageHandlers?.epistemosGoosePrompt;
            if (!handler?.postMessage) {
              throw new Error('Epistemos native prompt bridge is unavailable.');
            }
            const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
            return await handler.postMessage({ type, id, request: clone(request) });
          };
          const postNativeAffordance = async (name, args = []) => {
            const handler = window.webkit?.messageHandlers?.epistemosGooseNative;
            if (!handler?.postMessage) {
              throw new Error('Epistemos native affordance bridge is unavailable.');
            }
            const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
            return await handler.postMessage({ name, id, args: clone(Array.isArray(args) ? args : []) });
          };
          const electron = window.electron || {};
          Object.defineProperties(electron, {
            platform: { configurable: true, value: epistemosGoose.platform },
            arch: { configurable: true, value: epistemosGoose.arch },
            reactReady: { configurable: true, value: noop },
            getGoosedHostPort: { configurable: true, value: async () => epistemosGoose.baseURL },
            getSecretKey: { configurable: true, value: async () => epistemosGoose.secretKey },
            getAcpUrl: { configurable: true, value: async () => epistemosGoose.acpUrl },
            getConfig: { configurable: true, value: () => epistemosGoose.config },
            getSetting: { configurable: true, value: getSetting },
            setSetting: { configurable: true, value: setSetting },
            on: { configurable: true, value: onEvent },
            off: { configurable: true, value: offEvent },
            emit: { configurable: true, value: emitEvent },
            broadcastThemeChange: { configurable: true, value: (themeData) => emitEvent('theme-changed', themeData) },
            logInfo: { configurable: true, value: (...args) => console.info(...args) },
            hideWindow: { configurable: true, value: noop },
            createChatWindow: { configurable: true, value: noop },
            closeWindow: { configurable: true, value: noop },
            showOpenDialog: { configurable: true, value: (options = {}) => postNativeAffordance('showOpenDialog', [options]) },
            showSaveDialog: { configurable: true, value: (options = {}) => postNativeAffordance('showSaveDialog', [options]) },
            showMessageBox: { configurable: true, value: visibleError('showMessageBox') },
            directoryChooser: { configurable: true, value: () => postNativeAffordance('directoryChooser') },
            selectFileOrDirectory: { configurable: true, value: (defaultPath) => postNativeAffordance('selectFileOrDirectory', defaultPath === undefined ? [] : [defaultPath]) },
            selectImportSessionFile: { configurable: true, value: () => postNativeAffordance('selectImportSessionFile') },
            openExternal: { configurable: true, value: (url) => postNativeAffordance('openExternal', [url]) },
            openInChrome: { configurable: true, value: (url) => { void postNativeAffordance('openInChrome', [url]); } },
            openDirectoryInExplorer: { configurable: true, value: (directoryPath) => postNativeAffordance('openDirectoryInExplorer', [directoryPath]) },
            getBinaryPath: { configurable: true, value: visibleError('getBinaryPath') },
            readFile: { configurable: true, value: visibleError('readFile') },
            writeFile: { configurable: true, value: visibleError('writeFile') },
            ensureDirectory: { configurable: true, value: visibleError('ensureDirectory') },
            launchApp: { configurable: true, value: visibleError('launchApp') },
            refreshApp: { configurable: true, value: visibleError('refreshApp') },
            closeApp: { configurable: true, value: visibleError('closeApp') },
            openNotificationsSettings: { configurable: true, value: visibleError('openNotificationsSettings') },
            showNotification: { configurable: true, value: showNotification },
            setWindowTitle: { configurable: true, value: nullAffordance },
            reloadApp: { configurable: true, value: () => window.location.reload() },
            checkForOllama: { configurable: true, value: falseAffordance },
            getAllowedExtensions: { configurable: true, value: async () => [] },
            getPathForFile: { configurable: true, value: (file) => file?.path || file?.name || '' },
            listFiles: { configurable: true, value: async () => [] },
            addRecentDir: { configurable: true, value: trueAffordance },
            listRecentDirs: { configurable: true, value: async () => [] },
            listGitWorktreeDirs: { configurable: true, value: async () => [] },
            setMenuBarIcon: { configurable: true, value: trueAffordance },
            getMenuBarIconState: { configurable: true, value: trueAffordance },
            setDockIcon: { configurable: true, value: trueAffordance },
            getDockIconState: { configurable: true, value: trueAffordance },
            setWakelock: { configurable: true, value: undefinedAffordance },
            getWakelockState: { configurable: true, value: falseAffordance },
            setSpellcheck: { configurable: true, value: undefinedAffordance },
            getSpellcheckState: { configurable: true, value: trueAffordance },
            isAnyWindowFocused: { configurable: true, value: async () => document.hasFocus() },
            getIsFullScreen: { configurable: true, value: falseAffordance },
            onMouseBackButtonClicked: { configurable: true, value: (callback) => callback },
            offMouseBackButtonClicked: { configurable: true, value: noop },
            hasAcceptedRecipeBefore: { configurable: true, value: falseAffordance },
            recordRecipeHash: { configurable: true, value: trueAffordance },
            getVersion: { configurable: true, value: () => epistemosGoose.config.GOOSE_VERSION || '' },
            getUpdateState: { configurable: true, value: nullAffordance },
            isUsingGitHubFallback: { configurable: true, value: falseAffordance },
            getAutoDownloadDisabled: { configurable: true, value: falseAffordance },
            onUpdaterEvent: { configurable: true, value: noop },
            checkForUpdates: { configurable: true, value: updateUnavailable },
            downloadUpdate: { configurable: true, value: updateUnavailable },
            installUpdate: { configurable: true, value: updateUnavailable },
            quitAndInstall: { configurable: true, value: updateUnavailable }
          });
          window.electron = electron;
          const appConfig = window.appConfig || {};
          Object.defineProperties(appConfig, {
            get: { configurable: true, value: (key) => epistemosGoose.config[key] },
            getAll: { configurable: true, value: () => Object.assign({}, epistemosGoose.config) }
          });
          window.appConfig = appConfig;
          window.epistemos = Object.assign(window.epistemos || {}, {
            goose: Object.freeze({
              acpUrl: epistemosGoose.acpUrl,
              dispositionLedger: Object.freeze(epistemosGoose.ledger),
              requestPermission: (request) => postHostPrompt('permission', request),
              requestElicitation: (request) => postHostPrompt('elicitation', request),
              requestNativeAffordance: (name, args) => postNativeAffordance(name, args)
            })
          });
        })();
        """
    }

    private static let defaultSettings: [String: Any] = [
        "showMenuBarIcon": true,
        "disableAutoDownload": false,
        "showDockIcon": true,
        "enableWakelock": false,
        "enableNotifications": true,
        "spellcheckEnabled": true,
        "keyboardShortcuts": [
            "focusWindow": "CommandOrControl+Alt+G",
            "quickLauncher": "CommandOrControl+Alt+Shift+G",
            "newChat": "CommandOrControl+T",
            "newChatWindow": "CommandOrControl+N",
            "openDirectory": "CommandOrControl+O",
            "settings": "CommandOrControl+,",
            "find": "CommandOrControl+F",
            "findNext": "CommandOrControl+G",
            "findPrevious": "CommandOrControl+Shift+G",
            "alwaysOnTop": "CommandOrControl+Shift+T",
            "toggleNavigation": "CommandOrControl+/",
        ],
        "externalGoosed": [
            "enabled": false,
            "url": "",
            "secret": "",
        ],
        "theme": "light",
        "useSystemTheme": true,
        "language": "system",
        "responseStyle": "concise",
        "showPricing": true,
        "sessionSharing": [
            "enabled": false,
            "baseUrl": "",
        ],
        "seenAnnouncementIds": [],
    ]

    private static func jsonLiteral(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
