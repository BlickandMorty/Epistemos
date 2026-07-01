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
    var runtimeExtensibilityEnabled: Bool = defaultRuntimeExtensibilityEnabled()
    var allowlistWarning: Bool = allowlistWarning(
        from: ProcessInfo.processInfo.environment
    )

    nonisolated var dictionary: [String: Any] {
        var value: [String: Any] = [
            "GOOSE_ALLOWLIST_WARNING": allowlistWarning,
            "GOOSE_BUNDLE_NAME": bundleName,
            "GOOSE_WORKING_DIR": workingDirectory,
            "EPISTEMOS_MAS_EXTENSIBILITY_DISABLED": !runtimeExtensibilityEnabled,
            "EPISTEMOS_RUNTIME_EXTENSIBILITY_ENABLED": runtimeExtensibilityEnabled,
            "USE_ACP_CHAT": useACPChat,
        ]
        if let version {
            value["GOOSE_VERSION"] = version
        }
        return value
    }

    nonisolated static func defaultRuntimeExtensibilityEnabled() -> Bool {
        #if EPISTEMOS_APP_STORE
        false
        #else
        true
        #endif
    }

    nonisolated static func allowlistWarning(from environment: [String: String]) -> Bool {
        environment["GOOSE_ALLOWLIST_WARNING"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "true"
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

/// Boot shim injects runtime host config only (`GOOSE_API_HOST`, `USE_ACP_CHAT`, etc.).
/// Provider/model inventory must come from Goose ACP (`_goose/unstable/providers/*`) via the
/// staged Web UI overlay — never from Swift hardcoded lists in `getConfig` or `defaultSettings`.
enum GooseWebBootShim {
    static let dispositionLedger: [String: GooseWebAffordanceDisposition] = [
        "addRecentDir": .implementedNative,
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
        "window.open": .implementedNative,
        "reactReady": .implementedNative,
        "on": .compatibilityPreserved,
        "off": .compatibilityPreserved,
        "emit": .compatibilityPreserved,
        "logInfo": .compatibilityPreserved,
        "hideWindow": .implementedNative,
        "createChatWindow": .implementedRuntime,
        "closeWindow": .implementedRuntime,
        "showOpenDialog": .implementedNative,
        "showSaveDialog": .implementedNative,
        "showMessageBox": .implementedNative,
        "directoryChooser": .implementedNative,
        "selectFileOrDirectory": .implementedNative,
        "selectImportSessionFile": .implementedNative,
        "openExternal": .implementedNative,
        "openInChrome": .implementedNative,
        "openDirectoryInExplorer": .implementedNative,
        "getBinaryPath": .implementedNative,
        "readFile": .implementedNative,
        "readFileDataURL": .implementedNative,
        "writeFile": .implementedNative,
        "ensureDirectory": .implementedNative,
        "launchApp": .implementedNative,
        "refreshApp": .implementedNative,
        "closeApp": .implementedNative,
        "openNotificationsSettings": .implementedNative,
        "showNotification": .implementedNative,
        "setWindowTitle": .implementedNative,
        "reloadApp": .implementedRuntime,
        "checkForOllama": .implementedNative,
        "getAllowedExtensions": .implementedNative,
        "getPathForFile": .compatibilityPreserved,
        "listFiles": .implementedNative,
        "listRecentDirs": .implementedNative,
        "listGitWorktreeDirs": .implementedNative,
        "readGitDiff": .implementedNative,
        "readGitHubCompareURL": .implementedNative,
        "setMenuBarIcon": .implementedNative,
        "getMenuBarIconState": .implementedNative,
        "setDockIcon": .implementedNative,
        "getDockIconState": .implementedNative,
        "setWakelock": .implementedNative,
        "getWakelockState": .implementedNative,
        "setSpellcheck": .implementedNative,
        "getSpellcheckState": .implementedNative,
        "isAnyWindowFocused": .implementedNative,
        "getIsFullScreen": .implementedNative,
        "onMouseBackButtonClicked": .compatibilityPreserved,
        "offMouseBackButtonClicked": .compatibilityPreserved,
        "hasAcceptedRecipeBefore": .implementedNative,
        "recordRecipeHash": .implementedNative,
        "getVersion": .implementedNative,
        "apps.list": .implementedRuntime,
        "apps.import": .implementedRuntime,
        "apps.export": .implementedRuntime,
        "epistemos.context.snapshot": .implementedNative,
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
            "runtimeExtensibilityEnabled": bootstrap.config.runtimeExtensibilityEnabled,
        ]
        let payloadJSON = jsonLiteral(payload)
        return """
        (() => {
          const epistemosGoose = Object.freeze(\(payloadJSON));
          const runtimeConfig = Object.assign({}, epistemosGoose.config);
          const runtimeExtensibilityEnabled = epistemosGoose.runtimeExtensibilityEnabled === true;
          window.__epistemosGooseRuntimeExtensibilityEnabled = runtimeExtensibilityEnabled;
          const visibleError = (name) => async () => {
            throw new Error(`Epistemos native host has not implemented ${name} yet.`);
          };
          const runtimeExtensibilityError = (surface = 'Runtime extensibility') => new Error(`${surface} is disabled in the App Store build.`);
          const nullAffordance = async () => null;
          const trueAffordance = async () => true;
          const falseAffordance = async () => false;
          const undefinedAffordance = async () => undefined;
          const noop = () => undefined;
          const updateUnavailable = async () => ({ success: false, updateInfo: null, error: 'Goose updater shell is disabled in Epistemos.' });
          const blockedExtensibilityRoutes = new Set(runtimeExtensibilityEnabled ? [] : [
            '/apps',
            '/extensions',
            '/recipes',
            '/schedules',
            '/skills'
          ]);
          const normalizedHashRoute = () => {
            const raw = String(window.location.hash || '#/').replace(/^#/, '') || '/';
            const path = raw.split('?')[0].replace(/\\/+$/g, '') || '/';
            return path.startsWith('/') ? path : `/${path}`;
          };
          const enforceRuntimeExtensibilityRouteGate = () => {
            if (runtimeExtensibilityEnabled) return false;
            const path = normalizedHashRoute();
            if (!blockedExtensibilityRoutes.has(path)) return false;
            window.history.replaceState(null, document.title, `${window.location.pathname}${window.location.search}#/`);
            emitEvent('epistemos-runtime-extensibility-blocked', path);
            return true;
          };
          const clone = (value) => {
            if (value === null || typeof value !== 'object') return value;
            return JSON.parse(JSON.stringify(value));
          };
          const maxConsoleMessageCharacters = 4096;
          const maxACPTraceFrameCharacters = 1024 * 1024;
          const maxNativeBridgePayloadBytes = 16 * 1024 * 1024;
          const maxNativePromptPayloadBytes = 1024 * 1024;
          const maxNativeAffordanceNameCharacters = 96;
          const maxImportedApps = 32;
          const maxImportedAppHtmlBytes = 16 * 1024 * 1024;
          const maxImportedAppNameCharacters = 128;
          const appBridgeError = (message) => new Error(`Epistemos Apps bridge: ${message}`);
          const gooseAPIURL = (path) => new URL(path, epistemosGoose.baseURL).toString();
          const gooseFetch = async (path, options = {}) => {
            const response = await fetch(gooseAPIURL(path), {
              ...options,
              headers: {
                'Content-Type': 'application/json',
                'X-Secret-Key': epistemosGoose.secretKey,
                ...(options.headers || {})
              }
            });
            if (!response.ok) {
              throw appBridgeError(`Goose HTTP ${path} failed with ${response.status}`);
            }
            const contentType = response.headers.get('content-type') || '';
            return contentType.includes('application/json') ? response.json() : response.text();
          };
          const utf8ByteLength = (value) => {
            const text = String(value ?? '');
            if (typeof TextEncoder === 'function') {
              return new TextEncoder().encode(text).length;
            }
            return unescape(encodeURIComponent(text)).length;
          };
          const boundedText = (value, maxCharacters) => {
            const text = String(value ?? '');
            return text.length > maxCharacters ? `${text.slice(0, maxCharacters)}...` : text;
          };
          const boundedJSONClone = (value, maxBytes, label) => {
            const serialized = JSON.stringify(value);
            if (serialized === undefined) return undefined;
            if (utf8ByteLength(serialized) > maxBytes) {
              throw new Error(`Epistemos ${label} payload is over ${maxBytes} bytes.`);
            }
            return JSON.parse(serialized);
          };
          const boundedNativeAffordanceName = (name) => {
            const normalized = String(name || '').replace(/[\\u0000-\\u001f\\u007f]/g, '').trim();
            if (!normalized || normalized.length > maxNativeAffordanceNameCharacters) {
              throw new Error(`Epistemos native affordance name is invalid or over ${maxNativeAffordanceNameCharacters} characters.`);
            }
            return normalized;
          };
          const boundedImportedAppName = (name) => {
            const normalized = String(name || '')
              .replace(/[\\u0000-\\u001f\\u007f]/g, '')
              .trim()
              .slice(0, maxImportedAppNameCharacters);
            return normalized || 'Imported app';
          };
          const loadImportedApps = async () => {
            if (!runtimeExtensibilityEnabled) return [];
            try {
              const parsed = await postNativeAffordance('listImportedApps');
              if (!Array.isArray(parsed)) return [];
              return parsed.filter((app) =>
                app &&
                typeof app === 'object' &&
                typeof app.name === 'string' &&
                typeof app.uri === 'string' &&
                (typeof app.text !== 'string' || utf8ByteLength(app.text) <= maxImportedAppHtmlBytes) &&
                app.mcpServers?.includes?.('apps')
              ).slice(-maxImportedApps);
            } catch {
              return [];
            }
          };
          const saveImportedApps = async (apps) => {
            if (!runtimeExtensibilityEnabled) {
              throw runtimeExtensibilityError('App import');
            }
            try {
              const saved = await postNativeAffordance('saveImportedApps', [apps.slice(-maxImportedApps)]);
              if (!saved) throw new Error('native store rejected imported apps');
            } catch (error) {
              throw appBridgeError(`could not persist imported app: ${consoleString(error)}`);
            }
          };
          const importedAppTitle = (html) => {
            try {
              const doc = new DOMParser().parseFromString(html, 'text/html');
              const title = doc.querySelector('title')?.textContent?.trim();
              if (title) return boundedImportedAppName(title);
              const heading = doc.querySelector('h1,h2')?.textContent?.trim();
              if (heading) return boundedImportedAppName(heading);
            } catch {}
            return 'Imported app';
          };
          const importedAppSlug = (name) => {
            let slug = '';
            for (const char of String(name || 'app').toLowerCase()) {
              const isLetter = char >= 'a' && char <= 'z';
              const isDigit = char >= '0' && char <= '9';
              slug += isLetter || isDigit ? char : '-';
            }
            return slug.replace(/-+/g, '-').replace(/^-|-$/g, '') || 'app';
          };
          const buildImportedApp = (html) => {
            if (typeof html !== 'string' || html.trim().length === 0) {
              throw appBridgeError('imported app HTML is empty');
            }
            if (utf8ByteLength(html) > maxImportedAppHtmlBytes) {
              throw appBridgeError(`imported app HTML is over ${maxImportedAppHtmlBytes} bytes`);
            }
            const name = importedAppTitle(html);
            const id = `${importedAppSlug(name)}-${Date.now().toString(36)}`;
            return {
              uri: `ui://epistemos/apps/${id}`,
              name,
              description: 'Imported HTML app',
              mimeType: 'text/html;profile=mcp-app',
              text: html,
              width: 960,
              height: 720,
              resizable: true,
              mcpServers: ['apps'],
              _meta: {
                'openai/widgetDescription': 'Imported Epistemos app',
                'epistemos/imported': true
              }
            };
          };
          const listLiveApps = async (sessionId = null) => {
            if (!runtimeExtensibilityEnabled) return [];
            const path = sessionId
              ? `/agent/list_apps?session_id=${encodeURIComponent(sessionId)}`
              : '/agent/list_apps';
            const response = await gooseFetch(path);
            return Array.isArray(response?.apps) ? response.apps : [];
          };
          const importLiveApp = async (html) => gooseFetch('/agent/import_app', {
            method: 'POST',
            body: JSON.stringify({ html })
          });
          const exportLiveApp = async (name) => gooseFetch(`/agent/export_app/${encodeURIComponent(name)}`);
          const epistemosGooseApps = Object.freeze({
            listApps: async (sessionId = null) => {
              if (!runtimeExtensibilityEnabled) return { apps: [] };
              try {
                return { apps: await listLiveApps(sessionId) };
              } catch (error) {
                console.warn('Epistemos Apps bridge falling back to native imported apps:', error);
                return { apps: await loadImportedApps() };
              }
            },
            importApp: async (html) => {
              if (!runtimeExtensibilityEnabled) {
                throw runtimeExtensibilityError('App import');
              }
              try {
                return await importLiveApp(html);
              } catch (error) {
                console.warn('Epistemos Apps bridge import falling back to native store:', error);
              }
              const nextApp = buildImportedApp(html);
              const apps = (await loadImportedApps()).filter((app) => app.name !== nextApp.name);
              apps.push(nextApp);
              await saveImportedApps(apps);
              return { name: nextApp.name, message: `Imported ${nextApp.name}` };
            },
            exportApp: async (name) => {
              if (!runtimeExtensibilityEnabled) {
                throw runtimeExtensibilityError('App export');
              }
              try {
                return await exportLiveApp(name);
              } catch (error) {
                console.warn('Epistemos Apps bridge export falling back to native store:', error);
              }
              const app = (await loadImportedApps()).find((entry) => entry.name === name);
              if (!app?.text) {
                throw appBridgeError(`no imported app named ${name}`);
              }
              return app.text;
            }
          });
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
          const consoleEvents = [];
          const consoleString = (value) => {
            if (value instanceof Error) return boundedText(value.message, maxConsoleMessageCharacters);
            if (typeof value === 'string') return boundedText(value, maxConsoleMessageCharacters);
            try { return boundedText(JSON.stringify(value), maxConsoleMessageCharacters); }
            catch { return boundedText(String(value), maxConsoleMessageCharacters); }
          };
          for (const level of ['error', 'warn']) {
            const nativeConsole = console[level]?.bind(console) || (() => undefined);
            console[level] = (...args) => {
              consoleEvents.push({
                level,
                message: args.map(consoleString).join(' ')
              });
              while (consoleEvents.length > 80) consoleEvents.shift();
              nativeConsole(...args);
            };
          }
          const acpTrace = (() => {
            const requests = new Map();
            const events = [];
            const push = (event) => {
              events.push(Object.assign({ at: Date.now() }, event));
              while (events.length > 400) events.shift();
            };
            const parse = (data) => {
              if (typeof data !== 'string') return null;
              if (data.length > maxACPTraceFrameCharacters) return null;
              try { return JSON.parse(data); } catch { return null; }
            };
            const idKey = (id) => id === undefined || id === null ? '' : String(id);
            const stopReason = (result) => result?.stopReason ?? result?.stop_reason ?? null;
            const isPromptMethod = (method) => method === 'session/prompt' || method === 'prompt';
            const methodCounts = (direction) => events
              .filter((event) => event.direction === direction && event.method)
              .reduce((counts, event) => {
                counts[event.method] = (counts[event.method] || 0) + 1;
                return counts;
              }, {});
            const traceOutgoing = (data) => {
              const message = parse(data);
              if (!message || !message.method) return;
              const id = idKey(message.id);
              if (id) {
                requests.set(id, message.method);
                // review M2: bound the pending-request map so a request that never gets a reply
                // (long-lived surface) cannot grow it without limit. Map keeps insertion order, so
                // dropping the oldest key is the natural eviction.
                while (requests.size > 500) requests.delete(requests.keys().next().value);
              }
              push({ direction: 'out', id, method: message.method });
            };
            const traceIncoming = (data) => {
              const message = parse(data);
              if (!message) return;
              const id = idKey(message.id);
              const method = requests.get(id) || message.method || '';
              if (message.result !== undefined || message.error !== undefined) {
                // review M2: the request is complete — reclaim its pending-request entry so the map
                // does not leak one entry per request over the life of the page.
                if (id) requests.delete(id);
                push({
                  direction: 'in',
                  id,
                  method,
                  stopReason: stopReason(message.result),
                  error: message.error?.message ?? null
                });
              } else if (message.method) {
                push({ direction: 'in', method: message.method });
              }
            };
            const promptResponses = () => events.filter((event) =>
              event.direction === 'in' && (isPromptMethod(event.method) || event.stopReason !== null)
            );
            return {
              traceSocket: (state, detail = null) => push({ direction: 'socket', method: `websocket:${state}`, detail }),
              traceOutgoing,
              traceIncoming,
              snapshot: () => {
                const responses = promptResponses();
                const lastPromptResponse = responses[responses.length - 1] || null;
                return {
                  events: events.slice(),
                  promptRequestCount: events.filter((event) =>
                    event.direction === 'out' && isPromptMethod(event.method)
                  ).length,
                  promptResponseCount: responses.length,
                  lastPromptStopReason: lastPromptResponse?.stopReason ?? null,
                  lastPromptError: lastPromptResponse?.error ?? null,
                  outgoingMethodCounts: methodCounts('out'),
                  incomingMethodCounts: methodCounts('in')
                };
              }
            };
          })();
          if (typeof window.WebSocket === 'function' && !window.__epistemosGooseACPTraceInstalled) {
            const NativeWebSocket = window.WebSocket;
            const TracedWebSocket = function(url, protocols) {
              const socket = protocols === undefined ? new NativeWebSocket(url) : new NativeWebSocket(url, protocols);
              const isACP = String(url || '').includes('/acp');
              if (!isACP) return socket;
              acpTrace.traceSocket('construct');
              socket.addEventListener('open', () => acpTrace.traceSocket('open'), { once: true });
              socket.addEventListener('close', (event) => acpTrace.traceSocket('close', event?.code ?? null));
              socket.addEventListener('error', () => acpTrace.traceSocket('error'));
              socket.addEventListener('message', (event) => acpTrace.traceIncoming(event.data));
              const tracedSend = (data) => {
                acpTrace.traceOutgoing(data);
                return socket.send(data);
              };
              const boundMethods = new Map();
              const boundMethod = (target, property, value) => {
                const cached = boundMethods.get(property);
                if (cached?.source === value) return cached.bound;
                const bound = value.bind(target);
                boundMethods.set(property, { source: value, bound });
                return bound;
              };
              return new Proxy(socket, {
                get(target, property) {
                  if (property === 'send') {
                    return tracedSend;
                  }
                  const value = Reflect.get(target, property, target);
                  return typeof value === 'function' ? boundMethod(target, property, value) : value;
                },
                set(target, property, value) {
                  return Reflect.set(target, property, value, target);
                }
              });
            };
            TracedWebSocket.prototype = NativeWebSocket.prototype;
            Object.setPrototypeOf(TracedWebSocket, NativeWebSocket);
            window.WebSocket = TracedWebSocket;
            window.__epistemosGooseACPTraceInstalled = true;
          }
          const showNotification = (data) => postNativeAffordance('showNotification', [data || {}]);
          const epistemosContextSnapshot = () => postNativeAffordance('epistemos.context.snapshot');
          const postHostPrompt = async (type, request) => {
            const handler = window.webkit?.messageHandlers?.epistemosGoosePrompt;
            if (!handler?.postMessage) {
              throw new Error('Epistemos native prompt bridge is unavailable.');
            }
            const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
            return await handler.postMessage({
              type,
              id,
              request: boundedJSONClone(request, maxNativePromptPayloadBytes, 'native prompt')
            });
          };
          const postNativeAffordance = async (name, args = []) => {
            const handler = window.webkit?.messageHandlers?.epistemosGooseNative;
            if (!handler?.postMessage) {
              throw new Error('Epistemos native affordance bridge is unavailable.');
            }
            const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
            return await handler.postMessage({
              name: boundedNativeAffordanceName(name),
              id,
              args: boundedJSONClone(Array.isArray(args) ? args : [], maxNativeBridgePayloadBytes, 'native affordance')
            });
          };
          const externalOpenURL = (rawURL) => {
            if (typeof rawURL !== 'string' || rawURL.trim() === '') return null;
            try {
              const url = new URL(rawURL, window.location.href);
              return ['http:', 'https:', 'mailto:', 'tel:'].includes(url.protocol) ? url.href : null;
            } catch {
              return null;
            }
          };
          const extensionDeepLinkURL = (rawURL) => {
            if (typeof rawURL !== 'string' || rawURL.trim() === '') return null;
            try {
              const url = new URL(rawURL);
              return url.protocol === 'goose:' && url.hostname === 'extension' ? url.href : null;
            } catch {
              return null;
            }
          };
          const sessionDeepLinkURL = (rawURL) => {
            if (typeof rawURL !== 'string' || rawURL.trim() === '') return null;
            try {
              const url = new URL(rawURL);
              return url.protocol === 'goose:' && url.hostname === 'sessions' ? url.href : null;
            } catch {
              return null;
            }
          };
          const forwardGooseDeepLink = (rawURL) => {
            const extensionHref = extensionDeepLinkURL(rawURL);
            if (extensionHref) {
              if (!runtimeExtensibilityEnabled) {
                console.warn(runtimeExtensibilityError('Extension install').message);
                return true;
              }
              emitEvent('add-extension', extensionHref);
              return true;
            }
            const sessionHref = sessionDeepLinkURL(rawURL);
            if (!sessionHref) return false;
            emitEvent('open-shared-session', sessionHref);
            return true;
          };
          const forwardExternalOpen = (rawURL) => {
            const href = externalOpenURL(rawURL);
            if (!href) return false;
            void postNativeAffordance('openExternal', [href]).catch((error) => {
              console.error('Epistemos window.open bridge failed:', error);
            });
            return true;
          };
          const nativeWindowOpen = typeof window.open === 'function' ? window.open.bind(window) : null;
          Object.defineProperty(window, 'open', {
            configurable: true,
            value: (url, target, features) => {
              if (forwardGooseDeepLink(url)) return null;
              if (forwardExternalOpen(url)) return null;
              return nativeWindowOpen ? nativeWindowOpen(url, target, features) : null;
            }
          });
          document.addEventListener('click', (event) => {
            const target = event.target instanceof Element ? event.target : null;
            const anchor = target?.closest?.('a[href]');
            if (!anchor || (!forwardGooseDeepLink(anchor.href) && !(
              anchor.matches('a[target="_blank"][href]') && forwardExternalOpen(anchor.href)
            ))) return;
            event.preventDefault();
            event.stopPropagation();
          }, true);
          const getSetting = async (key) => {
            const stored = await postNativeAffordance('getSetting', [key]);
            if (stored?.found) return clone(stored.value);
            return clone(epistemosGoose.settings[key]);
          };
          const setSetting = async (key, value) => {
            await postNativeAffordance('setSetting', [key, value]);
          };
          const routeMap = {
            chat: '/',
            pair: '/pair',
            settings: '/settings',
            sessions: '/sessions',
            schedules: '/schedules',
            recipes: '/recipes',
            skills: '/skills',
            permission: '/permission',
            ConfigureProviders: '/configure-providers',
            sharedSession: '/shared-session'
          };
          const setRuntimeLaunchConfig = (options = {}) => {
            for (const key of ['REQUEST_DIR', 'recipeDeeplink', 'recipeId', 'recipeParameters', 'scheduledJobId']) {
              delete runtimeConfig[key];
            }
            if (options.dir) {
              runtimeConfig.REQUEST_DIR = options.dir;
              runtimeConfig.GOOSE_WORKING_DIR = options.dir;
            }
            for (const key of ['recipeDeeplink', 'recipeId', 'recipeParameters', 'scheduledJobId']) {
              if (Object.prototype.hasOwnProperty.call(options, key) && options[key] !== undefined) {
                runtimeConfig[key] = clone(options[key]);
              }
            }
          };
          const createChatWindow = async (options = {}) => {
            const launch = options || {};
            setRuntimeLaunchConfig(launch);
            let appPath = launch.viewType ? (routeMap[launch.viewType] || '/') : '/';
            if (blockedExtensibilityRoutes.has(appPath)) appPath = '/';
            const initialMessage = launch.query || launch.initialMessage || '';
            if (appPath === '/' && (
              launch.recipeDeeplink !== undefined ||
              launch.recipeId !== undefined ||
              initialMessage
            )) {
              appPath = '/pair';
            }
            const searchParams = new URLSearchParams();
            if (launch.resumeSessionId) {
              searchParams.set('resumeSessionId', launch.resumeSessionId);
              if (appPath === '/') appPath = '/pair';
            } else if (appPath === '/pair') {
              searchParams.set('launchId', `${Date.now()}`);
            }
            window.location.hash = `${appPath}?${searchParams.toString()}`;
            if (initialMessage) {
              setTimeout(() => emitEvent('set-initial-message', initialMessage, {
                noAutoSubmit: Boolean(launch.initialMessageNoAutoSubmit),
                gooseMode: launch.initialGooseMode
              }), 0);
            } else {
              setTimeout(() => emitEvent('focus-input'), 0);
            }
          };
          const closeWindow = () => {
            if (window.location.hash.startsWith('#/launcher')) {
              window.location.hash = '#/';
            }
          };
          if (!runtimeExtensibilityEnabled) {
            window.addEventListener('hashchange', enforceRuntimeExtensibilityRouteGate, true);
            setTimeout(enforceRuntimeExtensibilityRouteGate, 0);
          }
          const electron = window.electron || {};
          Object.defineProperties(electron, {
            platform: { configurable: true, value: epistemosGoose.platform },
            arch: { configurable: true, value: epistemosGoose.arch },
            reactReady: { configurable: true, value: () => postNativeAffordance('reactReady') },
            getGoosedHostPort: { configurable: true, value: async () => epistemosGoose.baseURL },
            getSecretKey: { configurable: true, value: async () => epistemosGoose.secretKey },
            getAcpUrl: { configurable: true, value: async () => epistemosGoose.acpUrl },
            getConfig: { configurable: true, value: () => Object.assign({}, runtimeConfig) },
            getSetting: { configurable: true, value: getSetting },
            setSetting: { configurable: true, value: setSetting },
            on: { configurable: true, value: onEvent },
            off: { configurable: true, value: offEvent },
            emit: { configurable: true, value: emitEvent },
            broadcastThemeChange: { configurable: true, value: (themeData) => emitEvent('theme-changed', themeData) },
            logInfo: { configurable: true, value: (...args) => console.info(...args) },
            hideWindow: { configurable: true, value: () => postNativeAffordance('hideWindow') },
            createChatWindow: { configurable: true, value: createChatWindow },
            closeWindow: { configurable: true, value: closeWindow },
            showOpenDialog: { configurable: true, value: (options = {}) => postNativeAffordance('showOpenDialog', [options]) },
            showSaveDialog: { configurable: true, value: (options = {}) => postNativeAffordance('showSaveDialog', [options]) },
            showMessageBox: { configurable: true, value: (options = {}) => postNativeAffordance('showMessageBox', [options]) },
            directoryChooser: { configurable: true, value: () => postNativeAffordance('directoryChooser') },
            selectFileOrDirectory: { configurable: true, value: (defaultPath) => postNativeAffordance('selectFileOrDirectory', defaultPath === undefined ? [] : [defaultPath]) },
            selectImportSessionFile: { configurable: true, value: () => postNativeAffordance('selectImportSessionFile') },
            openExternal: { configurable: true, value: (url) => postNativeAffordance('openExternal', [url]) },
            openInChrome: { configurable: true, value: (url) => { void postNativeAffordance('openInChrome', [url]); } },
            openDirectoryInExplorer: { configurable: true, value: (directoryPath) => postNativeAffordance('openDirectoryInExplorer', [directoryPath]) },
            getBinaryPath: { configurable: true, value: (binaryName) => postNativeAffordance('getBinaryPath', [binaryName]) },
            readFile: { configurable: true, value: (filePath) => postNativeAffordance('readFile', [filePath]) },
            readFileDataURL: { configurable: true, value: (filePath) => postNativeAffordance('readFileDataURL', [filePath]) },
            writeFile: { configurable: true, value: (filePath, content) => postNativeAffordance('writeFile', [filePath, content]) },
            ensureDirectory: { configurable: true, value: (dirPath) => postNativeAffordance('ensureDirectory', [dirPath]) },
            launchApp: { configurable: true, value: (app) => postNativeAffordance('launchApp', [app]) },
            refreshApp: { configurable: true, value: (app) => postNativeAffordance('refreshApp', [app]) },
            closeApp: { configurable: true, value: (appName) => postNativeAffordance('closeApp', [appName]) },
            openNotificationsSettings: { configurable: true, value: () => postNativeAffordance('openNotificationsSettings') },
            showNotification: { configurable: true, value: showNotification },
            setWindowTitle: { configurable: true, value: (title) => postNativeAffordance('setWindowTitle', [title]) },
            reloadApp: { configurable: true, value: () => window.location.reload() },
            checkForOllama: { configurable: true, value: () => postNativeAffordance('checkForOllama') },
            getAllowedExtensions: { configurable: true, value: () => runtimeExtensibilityEnabled ? postNativeAffordance('getAllowedExtensions') : Promise.resolve([]) },
            getPathForFile: { configurable: true, value: (file) => {
              const path = file?.path || file?.epistemosNativePath || '';
              if (typeof path === 'string' && path.startsWith('/')) return path;
              throw new Error('Native file path is unavailable for this WebView file object.');
            } },
            listFiles: { configurable: true, value: (dirPath, extension) => postNativeAffordance('listFiles', extension === undefined ? [dirPath] : [dirPath, extension]) },
            addRecentDir: { configurable: true, value: (dir) => postNativeAffordance('addRecentDir', [dir]) },
            listRecentDirs: { configurable: true, value: () => postNativeAffordance('listRecentDirs') },
            listGitWorktreeDirs: { configurable: true, value: (dir) => postNativeAffordance('listGitWorktreeDirs', [dir]) },
            readGitDiff: { configurable: true, value: (dirPath) => postNativeAffordance('readGitDiff', [dirPath]) },
            readGitHubCompareURL: { configurable: true, value: (dirPath) => postNativeAffordance('readGitHubCompareURL', [dirPath]) },
            setMenuBarIcon: { configurable: true, value: (show) => postNativeAffordance('setMenuBarIcon', [show]) },
            getMenuBarIconState: { configurable: true, value: () => postNativeAffordance('getMenuBarIconState') },
            setDockIcon: { configurable: true, value: (show) => postNativeAffordance('setDockIcon', [show]) },
            getDockIconState: { configurable: true, value: () => postNativeAffordance('getDockIconState') },
            setWakelock: { configurable: true, value: (enabled) => postNativeAffordance('setWakelock', [enabled]) },
            getWakelockState: { configurable: true, value: () => postNativeAffordance('getWakelockState') },
            setSpellcheck: { configurable: true, value: (enabled) => postNativeAffordance('setSpellcheck', [enabled]) },
            getSpellcheckState: { configurable: true, value: () => postNativeAffordance('getSpellcheckState') },
            isAnyWindowFocused: { configurable: true, value: () => postNativeAffordance('isAnyWindowFocused') },
            getIsFullScreen: { configurable: true, value: () => postNativeAffordance('getIsFullScreen') },
            onMouseBackButtonClicked: { configurable: true, value: (callback) => callback },
            offMouseBackButtonClicked: { configurable: true, value: noop },
            hasAcceptedRecipeBefore: { configurable: true, value: (recipe) => postNativeAffordance('hasAcceptedRecipeBefore', [recipe]) },
            recordRecipeHash: { configurable: true, value: (recipe) => postNativeAffordance('recordRecipeHash', [recipe]) },
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
            get: { configurable: true, value: (key) => runtimeConfig[key] },
            getAll: { configurable: true, value: () => Object.assign({}, runtimeConfig) }
          });
          window.appConfig = appConfig;
          window.epistemos = Object.assign(window.epistemos || {}, {
            context: Object.freeze({
              snapshot: epistemosContextSnapshot
            }),
            goose: Object.freeze({
              acpUrl: epistemosGoose.acpUrl,
              dispositionLedger: Object.freeze(epistemosGoose.ledger),
              acpTrace: acpTrace.snapshot,
              consoleEvents: () => consoleEvents.slice(),
              runtimeExtensibilityEnabled,
              apps: epistemosGooseApps,
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

    private static let bootstrapSerializationFailureMessage = "Epistemos failed to serialize the Goose Web boot payload."

    private static func jsonLiteral(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            assertionFailure(bootstrapSerializationFailureMessage)
            return #"(() => { throw new Error("Epistemos failed to serialize the Goose Web boot payload."); })()"#
        }
        return string
    }
}
