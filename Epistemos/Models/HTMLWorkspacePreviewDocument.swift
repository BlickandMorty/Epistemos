import Foundation

nonisolated private enum HTMLWorkspacePreviewFonts {
    private final class BundleProbe {}

    static let fontFaceCSS: String = {
        [
            fontFace(
                family: "MatrixTypeDisplay-Regular",
                fileName: "MatrixtypeDisplay-9MyE5",
                ext: "ttf",
                mimeType: "font/ttf",
                aliases: ["MatrixTypeDisplay"]
            ),
            fontFace(
                family: "ChonkyPixels",
                fileName: "ChonkyPixels",
                ext: "ttf",
                mimeType: "font/ttf"
            ),
        ].compactMap { $0 }.joined(separator: "\n\n")
    }()

    private static func fontFace(
        family: String,
        fileName: String,
        ext: String,
        mimeType: String,
        aliases: [String] = []
    ) -> String? {
        guard let dataURL = fontDataURL(fileName: fileName, ext: ext, mimeType: mimeType) else {
            return nil
        }
        let allFamilies = [family] + aliases
        return allFamilies.map { familyName in
            """
        @font-face {
          font-family: "\(familyName)";
          src: local("\(familyName)"), local("\(family)"), url("\(dataURL)") format("truetype");
          font-style: normal;
          font-weight: 400;
          font-synthesis: none;
          font-display: swap;
        }
        """
        }.joined(separator: "\n\n")
    }

    private static func fontDataURL(fileName: String, ext: String, mimeType: String) -> String? {
        guard let url = bundleFontURL(fileName: fileName, ext: ext),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func bundleFontURL(fileName: String, ext: String) -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleProbe.self)] + Bundle.allBundles + Bundle.allFrameworks
        var visited = Set<String>()
        for bundle in bundles {
            let path = bundle.bundleURL.path
            guard visited.insert(path).inserted else { continue }
            if let url = bundle.url(forResource: fileName, withExtension: ext) {
                return url
            }
            if let url = bundle.url(
                forResource: fileName,
                withExtension: ext,
                subdirectory: "Fonts"
            ) {
                return url
            }
        }
        return nil
    }
}

nonisolated public enum HTMLWorkspacePreviewDocument {
    public static func render(
        package: HTMLWorkspacePackage,
        routeName: String? = nil,
        theme: HTMLWorkspacePreviewTheme? = nil,
        themeGuardCSSOverride: String? = nil,
        resourceMode: HTMLWorkspacePreviewResourceMode = .packageLocal
    ) -> String {
        let package = switch resourceMode {
        case .packageLocal:
            package
        case .inlinePackageAssets:
            HTMLWorkspacePackageResources.packageWithInlineAssets(package)
        }
        let csp = package.manifest.sandboxPolicy.contentSecurityPolicy
        let themeAttribute = theme.map { #" data-epistemos-theme="\#($0.rawValue)""# } ?? ""
        let themeCSS = themeGuardCSSOverride ?? theme?.guardCSS ?? HTMLWorkspacePreviewTheme.defaultGuardCSS
        let routeHTML = routeName.flatMap { package.routes[$0] }
        let bodyHTML = routeHTML ?? package.indexHTML
        return """
        <!doctype html>
        <html\(themeAttribute)>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="\(escapeAttribute(csp))">
          <style id="epistemos-font-face">
        \(HTMLWorkspacePreviewFonts.fontFaceCSS)
          </style>
          <style id="epistemos-theme-guard">
        \(themeCSS)
          </style>
          <style>\(package.styleCSS)</style>
          <style id="epistemos-theme-host">
        \(HTMLWorkspacePreviewTheme.hostCSS)
          </style>
        </head>
        <body>
        \(bodyHTML)
          <script type="application/json" id="workspace-data">\(escapeScriptData(package.dataJSON))</script>
          <script id="epistemos-workspace-runtime">
        \(HTMLWorkspacePreviewRuntime.script(
            pythonPolicyEnabled: package.manifest.sandboxPolicy.allowPythonRuntime,
            appBridgeEnabled: package.manifest.sandboxPolicy.allowAppBridge,
            safeAPIVersion: package.manifest.sandboxPolicy.safeAPIVersion
        ))
          </script>
          <script>\(package.scriptJS)</script>
        </body>
        </html>
        """
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeScriptData(_ value: String) -> String {
        value
            .replacingOccurrences(of: "</script", with: "<\\/script", options: [.caseInsensitive])
    }
}

nonisolated enum HTMLWorkspacePreviewRuntime {
    static func script(
        pythonPolicyEnabled: Bool,
        appBridgeEnabled: Bool,
        safeAPIVersion: UInt32
    ) -> String {
        let pythonAvailable = pythonPolicyEnabled && HTMLWorkspacePythonRuntime.isAvailable
        let pythonStatus: String = if !pythonPolicyEnabled {
            "disabled"
        } else if pythonAvailable {
            "available"
        } else {
            "missing-vendored-assets"
        }
        let pythonBaseURL = HTMLWorkspacePythonRuntime.baseURLString
        let pythonMissingResources = stringArrayLiteral(HTMLWorkspacePythonRuntime.missingRequiredResourceNames)
        let appBridgeJavaScript = appBridgeScript(
            enabled: appBridgeEnabled,
            safeAPIVersion: safeAPIVersion
        )
        return """
    (() => {
      const dataNode = document.getElementById('workspace-data');
      const parseWorkspaceData = (raw) => {
        try {
          return JSON.parse(raw || '{}');
        } catch (error) {
          console.error('HTMLWorkspace data.json parse failed', error);
          return { error: 'Invalid data.json' };
        }
      };
      const state = {
        data: parseWorkspaceData(dataNode?.textContent || '{}')
      };
      const appBridge = \(appBridgeJavaScript);
      const replaceWorkspaceData = (nextData, rawJSON = null, emitEvent = true) => {
        state.data = nextData;
        if (dataNode) {
          dataNode.textContent = rawJSON === null ? JSON.stringify(nextData) : String(rawJSON);
        }
        if (emitEvent) {
          try {
            window.dispatchEvent(new CustomEvent('htmlworkspace:datachange', { detail: nextData }));
          } catch (error) {
            console.warn('HTMLWorkspace datachange event failed', error);
          }
        }
        return true;
      };

      Object.defineProperty(window, '__epistemosReplaceWorkspaceData', {
        value(nextData, rawJSON = null) {
          return replaceWorkspaceData(nextData, rawJSON);
        },
        writable: false,
        configurable: false,
        enumerable: false
      });

      replaceWorkspaceData(state.data, dataNode?.textContent || '{}', false);

      const pythonRuntime = (() => {
        const enabled = \(pythonPolicyEnabled ? "true" : "false");
        const available = \(pythonAvailable ? "true" : "false");
        const status = "\(pythonStatus)";
        const baseURL = "\(pythonBaseURL)";
        const missingResources = \(pythonMissingResources);
        let loadPromise = null;
        function loadScript(src) {
          return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = src;
            script.async = true;
            script.onload = () => resolve();
            script.onerror = () => reject(new Error('Failed to load Pyodide script: ' + src));
            document.head.appendChild(script);
          });
        }
        async function load() {
          if (!enabled) {
            throw new Error('HTML Workspace Python runtime is disabled by sandbox policy');
          }
          if (!available) {
            throw new Error('HTML Workspace Python runtime is not bundled in this build');
          }
          if (!loadPromise) {
            loadPromise = (async () => {
              if (typeof window.loadPyodide !== 'function') {
                await loadScript(baseURL + '\(HTMLWorkspacePythonRuntime.entryScriptName)');
              }
              if (typeof window.loadPyodide !== 'function') {
                throw new Error('Pyodide loader did not register loadPyodide');
              }
              return window.loadPyodide({ indexURL: baseURL });
            })();
          }
          return loadPromise;
        }
        async function run(code) {
          const pyodide = await load();
          return pyodide.runPythonAsync(String(code ?? ''));
        }
        return Object.freeze({
          enabled,
          available,
          status,
          missingResources,
          baseURL: available ? baseURL : null,
          load,
          run
        });
      })();

      const toArray = (children) => Array.isArray(children) ? children : [children];
      const api = {
        get data() {
          return state.data;
        },
        app: appBridge,
        python: pythonRuntime,
        q(selector, scope = document) {
          return scope.querySelector(selector);
        },
        qa(selector, scope = document) {
          return Array.from(scope.querySelectorAll(selector));
        },
        el(tagName, attributes = {}, children = []) {
          const node = document.createElement(tagName);
          Object.entries(attributes || {}).forEach(([key, value]) => {
            if (value === false || value === null || value === undefined) { return; }
            if (key === 'class') {
              node.className = String(value);
            } else if (key === 'text') {
              node.textContent = String(value);
            } else {
              node.setAttribute(key, value === true ? '' : String(value));
            }
          });
          toArray(children).forEach((child) => {
            if (child === null || child === undefined) { return; }
            node.append(child instanceof Node ? child : document.createTextNode(String(child)));
          });
          return node;
        },
        mount(target, node) {
          const host = typeof target === 'string' ? document.querySelector(target) : target;
          if (!host || !node) { return null; }
          host.replaceChildren(node);
          return host;
        }
      };

      Object.defineProperty(window, 'HTMLWorkspace', {
        value: Object.freeze(api),
        writable: false,
        configurable: false,
        enumerable: false
      });

      Object.defineProperty(window, 'HTMLWorkspaceApp', {
        value: appBridge,
        writable: false,
        configurable: false,
        enumerable: false
      });
    })();
    """
    }

    private static func appBridgeScript(enabled: Bool, safeAPIVersion: UInt32) -> String {
        guard enabled else {
            return """
        (() => Object.freeze({
          enabled: false,
          safeAPIVersion: \(safeAPIVersion),
          post() { return false; },
          request() { return Promise.reject(new Error('HTML Workspace app bridge is disabled')); },
          ping() { return false; },
          status() { return false; },
          record() { return false; }
        }))()
        """
        }

        return """
        (() => {
          const handlerName = "\(HTMLWorkspaceSafeAPI.messageHandlerName)";
          const maxCommandLength = \(HTMLWorkspaceSafeAPI.maxCommandLength);
          const maxMessageLength = \(HTMLWorkspaceSafeAPI.maxMessageLength);
          const responseEventName = 'htmlworkspace:appbridge';
          const defaultTimeoutMs = 5000;
          const maxTimeoutMs = 30000;
          const maxPendingRequests = 64;
          let requestCounter = 0;
          const pendingRequests = new Map();
          const bounded = (value, limit) => {
            if (value === null || value === undefined) { return null; }
            const text = String(value).trim();
            return text.length ? text.slice(0, limit) : null;
          };
          const bridgeError = (message) => new Error(message);
          const handler = () => {
            try {
              return window.webkit?.messageHandlers?.[handlerName];
            } catch (error) {
              return null;
            }
          };
          const timeoutFor = (options) => {
            const raw = options && Number(options.timeoutMs);
            if (!Number.isFinite(raw) || raw <= 0) { return defaultTimeoutMs; }
            return Math.max(100, Math.min(maxTimeoutMs, raw));
          };
          const preparePayload = (command, message = null) => {
            const name = bounded(command, maxCommandLength);
            if (!name) { return null; }
            const target = handler();
            if (!target || typeof target.postMessage !== 'function') { return null; }
            const payload = {
              command: name,
              safeAPIVersion: \(safeAPIVersion),
              requestId: 'safeapi-' + (++requestCounter)
            };
            const text = bounded(message, maxMessageLength);
            if (text) { payload.message = text; }
            return { target, payload };
          };
          const postPrepared = (prepared) => {
            if (!prepared) { return false; }
            try {
              prepared.target.postMessage(prepared.payload);
              return true;
            } catch (error) {
              return false;
            }
          };
          const post = (command, message = null) => postPrepared(preparePayload(command, message));
          const trimPendingQueue = () => {
            if (pendingRequests.size < maxPendingRequests) { return; }
            const oldest = pendingRequests.keys().next().value;
            if (!oldest) { return; }
            const entry = pendingRequests.get(oldest);
            pendingRequests.delete(oldest);
            if (entry) {
              window.clearTimeout(entry.timer);
              entry.reject(bridgeError('HTML Workspace app bridge request queue full'));
            }
          };
          const request = (command, message = null, options = {}) => new Promise((resolve, reject) => {
            const prepared = preparePayload(command, message);
            if (!prepared) {
              reject(bridgeError('HTML Workspace app bridge handler unavailable'));
              return;
            }
            const requestId = prepared.payload.requestId;
            trimPendingQueue();
            const timer = window.setTimeout(() => {
              if (!pendingRequests.has(requestId)) { return; }
              pendingRequests.delete(requestId);
              reject(bridgeError('HTML Workspace app bridge request timed out'));
            }, timeoutFor(options));
            pendingRequests.set(requestId, { resolve, reject, timer });
            try {
              prepared.target.postMessage(prepared.payload);
            } catch (error) {
              window.clearTimeout(timer);
              pendingRequests.delete(requestId);
              reject(error instanceof Error ? error : bridgeError('HTML Workspace app bridge request failed'));
            }
          });
          window.addEventListener(responseEventName, (event) => {
            const detail = event && event.detail ? event.detail : {};
            const requestId = typeof detail.requestId === 'string' ? detail.requestId : null;
            if (!requestId || !pendingRequests.has(requestId)) { return; }
            const entry = pendingRequests.get(requestId);
            pendingRequests.delete(requestId);
            window.clearTimeout(entry.timer);
            entry.resolve(Object.freeze({
              command: typeof detail.command === 'string' ? detail.command : null,
              requestId,
              message: typeof detail.message === 'string' ? detail.message : '',
              safeAPIVersion: Number.isFinite(Number(detail.safeAPIVersion)) ? Number(detail.safeAPIVersion) : \(safeAPIVersion)
            }));
          });
          return Object.freeze({
            enabled: true,
            safeAPIVersion: \(safeAPIVersion),
            post,
            request,
            ping(message = null) { return post('ping', message); },
            status() { return post('workspace.status'); },
            record(message = null) { return post('event.record', message); }
          });
        })()
        """
    }

    private static func stringArrayLiteral(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let literal = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return literal
    }
}
