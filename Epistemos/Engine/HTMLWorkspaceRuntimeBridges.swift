import Foundation

nonisolated enum HTMLWorkspaceConsoleCapturePolicy {
    static let environmentFlag = "EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentFlag] != "0"
    }
}

nonisolated enum HTMLWorkspaceConsoleBridge {
    static let messageHandlerName = "epistemosWorkspaceConsole"

    static var enabled: Bool {
        HTMLWorkspaceConsoleCapturePolicy.isEnabled()
    }

    struct DiagnosticPayload: Equatable, Sendable {
        let message: String
        let source: String?
        let line: UInt32
        let column: UInt32

        static func fromMessageBody(_ body: Any) -> DiagnosticPayload? {
            guard let payload = body as? [String: Any] else { return nil }
            let rawMessage = nonEmptyString(payload["message"]) ?? "Console error"
            let rawSource = nonEmptyString(payload["source"])
            let bounded = HTMLWorkspaceConsoleError(
                message: rawMessage,
                source: rawSource,
                line: uint32(payload["line"]),
                column: uint32(payload["column"]),
                timestamp: 0
            ).boundedForPackage()
            return DiagnosticPayload(
                message: bounded.message,
                source: bounded.source,
                line: bounded.line,
                column: bounded.column
            )
        }

        private static func nonEmptyString(_ value: Any?) -> String? {
            guard let string = value as? String,
                  !string.isEmpty else {
                return nil
            }
            return string
        }

        private static func uint32(_ value: Any?) -> UInt32 {
            guard let number = value as? NSNumber else { return 0 }
            let raw = number.int64Value
            guard raw > 0 else { return 0 }
            return UInt32(min(raw, Int64(UInt32.max)))
        }
    }

    /// Read-only: forwards errors, never exposes an app API. Posts {message, source, line, column}.
    static let injectionScript = """
    (function(){
      function post(message, source, line, column){
        try {
          window.webkit.messageHandlers.epistemosWorkspaceConsole.postMessage({
            message: String(message), source: source || null, line: line || 0, column: column || 0
          });
        } catch (e) {}
      }
      window.addEventListener('error', function(e){ post(e.message || 'Error', e.filename, e.lineno, e.colno); });
      window.addEventListener('unhandledrejection', function(e){ post('Unhandled promise rejection: ' + e.reason, null, 0, 0); });
      var origError = console.error;
      console.error = function(){ post(Array.prototype.slice.call(arguments).join(' '), null, 0, 0); origError.apply(console, arguments); };
      var origWarn = console.warn;
      console.warn = function(){ post(Array.prototype.slice.call(arguments).join(' '), null, 0, 0); origWarn.apply(console, arguments); };
    })();
    """
}

nonisolated struct HTMLWorkspaceElementInspection: Equatable, Sendable {
    let selector: String
    let tagName: String
    let elementID: String?
    let classes: [String]
    let textPreview: String
    let styles: [String: String]

    static func fromMessageBody(_ body: Any) -> HTMLWorkspaceElementInspection? {
        guard let payload = body as? [String: Any],
              let selector = boundedString(payload["selector"], limit: 512),
              let tagName = boundedString(payload["tagName"], limit: 64) else {
            return nil
        }
        let elementID = boundedString(payload["id"], limit: 128)
        let classes = (payload["classes"] as? [String] ?? [])
            .compactMap { boundedString($0, limit: 96) }
            .prefix(12)
        let textPreview = boundedString(payload["text"], limit: 240) ?? ""
        let rawStyles = payload["styles"] as? [String: String] ?? [:]
        var styles: [String: String] = [:]
        for (key, value) in rawStyles where styles.count < 24 {
            guard let safeKey = boundedString(key, limit: 64),
                  let safeValue = boundedString(value, limit: 160) else { continue }
            styles[safeKey] = safeValue
        }
        return HTMLWorkspaceElementInspection(
            selector: selector,
            tagName: tagName,
            elementID: elementID,
            classes: Array(classes),
            textPreview: textPreview,
            styles: styles
        )
    }

    private static func boundedString(_ value: Any?, limit: Int) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit))
    }
}

nonisolated enum HTMLWorkspaceInspectorBridge {
    static let messageHandlerName = "epistemosWorkspaceInspector"

    static let disableScript = """
    window.__epistemosInspectorEnabled = false;
    """

    static let installScript = """
    (function(){
      if (window.__epistemosInspectorInstalled) {
        window.__epistemosInspectorEnabled = true;
        return;
      }
      window.__epistemosInspectorInstalled = true;
      window.__epistemosInspectorEnabled = true;
      function selectorFor(node) {
        if (!node || !node.tagName) { return 'unknown'; }
        var tag = String(node.tagName).toLowerCase();
        if (node.id) { return tag + '#' + node.id; }
        var classes = Array.prototype.slice.call(node.classList || []).slice(0, 4);
        return tag + classes.map(function(name){ return '.' + name; }).join('');
      }
      function textFor(node) {
        return String((node && node.textContent) || '').replace(/\\s+/g, ' ').trim().slice(0, 240);
      }
      function post(node) {
        var style = window.getComputedStyle(node);
        var keys = ['display','position','width','height','margin','padding','color','background-color','font-family','font-size','font-weight','line-height','border-radius','border-color'];
        var styles = {};
        keys.forEach(function(key){ styles[key] = style.getPropertyValue(key); });
        window.webkit.messageHandlers.epistemosWorkspaceInspector.postMessage({
          selector: selectorFor(node),
          tagName: String(node.tagName || '').toLowerCase(),
          id: node.id || null,
          classes: Array.prototype.slice.call(node.classList || []),
          text: textFor(node),
          styles: styles
        });
      }
      document.addEventListener('click', function(event) {
        if (!window.__epistemosInspectorEnabled) { return; }
        event.preventDefault();
        event.stopPropagation();
        post(event.target);
      }, true);
    })();
    """
}
