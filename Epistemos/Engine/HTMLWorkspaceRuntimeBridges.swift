import Foundation

nonisolated enum HTMLWorkspaceConsoleCapturePolicy {
    static let environmentFlag = "EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentFlag] != "0"
    }
}

nonisolated enum HTMLWorkspaceSafeAPI {
    static let messageHandlerName = "htmlWorkspaceSafeAPI"
    static let sourceName = "epistemos://html-workspace/app-bridge"
    static let maxCommandLength = 96
    static let maxMessageLength = 280
    static let maxRequestIDLength = 80
    static let maxEventNameLength = 96
    static let maxAttributeCount = 12
    static let maxAttributeKeyLength = 48
    static let maxAttributeValueLength = 160

    struct Command: Equatable, Sendable {
        let name: String
        let message: String?
        let requestID: String?
        let eventName: String?
        let attributes: [String: String]

        var isSupported: Bool {
            HTMLWorkspaceSafeAPI.isSupportedCommandName(name)
        }

        static func fromMessageBody(_ body: Any) -> Command? {
            if let raw = boundedString(body, limit: maxCommandLength) {
                return Command(name: raw, message: nil, requestID: nil, eventName: nil, attributes: [:])
            }
            guard let payload = body as? [String: Any],
                  let name = boundedString(
                    payload["command"] ?? payload["type"] ?? payload["name"],
                    limit: maxCommandLength
                  ) else {
                return nil
            }
            let nestedPayload = payload["payload"] as? [String: Any]
            let message = boundedString(
                payload["message"] ?? payload["label"] ?? nestedPayload?["message"] ?? nestedPayload?["label"],
                limit: maxMessageLength
            )
            let requestID = boundedString(
                payload["requestId"] ?? payload["request_id"] ?? nestedPayload?["requestId"] ?? nestedPayload?["request_id"],
                limit: maxRequestIDLength
            )
            let eventName = boundedString(
                payload["eventName"] ?? payload["event"] ?? nestedPayload?["eventName"] ?? nestedPayload?["event"],
                limit: maxEventNameLength
            )
            let attributes = boundedAttributes(
                payload["attributes"] ?? payload["properties"] ?? nestedPayload?["attributes"] ?? nestedPayload?["properties"]
            )
            return Command(
                name: name,
                message: message,
                requestID: requestID,
                eventName: eventName,
                attributes: attributes
            )
        }

        private static func boundedString(_ value: Any?, limit: Int) -> String? {
            guard let raw = value as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard trimmed.count > limit else { return trimmed }
            return String(trimmed.prefix(limit))
        }

        private static func boundedAttributeValue(_ value: Any?, limit: Int) -> String? {
            switch value {
            case let string as String:
                return boundedString(string, limit: limit)
            case let bool as Bool:
                return boundedString(bool ? "true" : "false", limit: limit)
            case let number as NSNumber:
                return boundedString(number.stringValue, limit: limit)
            default:
                return nil
            }
        }

        private static func boundedAttributes(_ value: Any?) -> [String: String] {
            guard let raw = value as? [String: Any] else { return [:] }
            var attributes: [String: String] = [:]
            for (key, value) in raw where attributes.count < maxAttributeCount {
                guard let boundedKey = boundedString(key, limit: maxAttributeKeyLength),
                      let boundedValue = boundedAttributeValue(value, limit: maxAttributeValueLength) else {
                    continue
                }
                attributes[boundedKey] = boundedValue
            }
            return attributes
        }
    }

    static func isSupportedCommandName(_ name: String) -> Bool {
        switch name.lowercased() {
        case "ping", "workspace.status", "status", "event.record", "record":
            return true
        default:
            return false
        }
    }

    static func diagnosticMessage(
        for command: Command,
        package: HTMLWorkspacePackage
    ) -> String {
        switch command.name.lowercased() {
        case "ping":
            if let message = command.message, !message.isEmpty {
                return "App bridge ping: \(message)"
            }
            return "App bridge ping: ok"
        case "workspace.status", "status":
            let network = package.manifest.sandboxPolicy.allowNetwork ? "network" : "offline"
            return "App bridge status: \(package.manifest.id) / \(network) / safeAPI v\(package.manifest.sandboxPolicy.safeAPIVersion)"
        case "event.record", "record":
            if let eventName = command.eventName {
                let suffix = command.attributes.isEmpty ? "" : " (\(command.attributes.count) fields)"
                if let message = command.message, !message.isEmpty {
                    return "App bridge event: \(eventName) - \(message)\(suffix)"
                }
                return "App bridge event: \(eventName)\(suffix)"
            }
            return "App bridge event: \(command.message ?? "received")"
        default:
            return "App bridge unsupported command: \(command.name)"
        }
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
        let severity: HTMLWorkspaceConsoleSeverity

        static func fromMessageBody(_ body: Any) -> DiagnosticPayload? {
            guard let payload = body as? [String: Any] else { return nil }
            let rawMessage = nonEmptyString(payload["message"]) ?? "Console error"
            let rawSource = nonEmptyString(payload["source"])
            let rawLevel = nonEmptyString(payload["level"]) ?? nonEmptyString(payload["severity"])
            let bounded = HTMLWorkspaceConsoleError(
                message: rawMessage,
                source: rawSource,
                line: uint32(payload["line"]),
                column: uint32(payload["column"]),
                timestamp: 0,
                severity: HTMLWorkspaceConsoleSeverity.fromBridgeLevel(rawLevel)
            ).boundedForPackage()
            return DiagnosticPayload(
                message: bounded.message,
                source: bounded.source,
                line: bounded.line,
                column: bounded.column,
                severity: bounded.severity
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

    /// Read-only: forwards errors, never exposes an app API. Posts {level, message, source, line, column}.
    static let injectionScript = """
    (function(){
      if (window.__epistemosConsoleBridgeInstalled === true) { return; }
      try {
        Object.defineProperty(window, '__epistemosConsoleBridgeInstalled', {
          value: true,
          writable: false,
          configurable: false,
          enumerable: false
        });
      } catch (e) {
        window.__epistemosConsoleBridgeInstalled = true;
      }
      function post(level, message, source, line, column){
        try {
          window.webkit.messageHandlers.epistemosWorkspaceConsole.postMessage({
            level: String(level || 'error'), message: String(message), source: source || null, line: line || 0, column: column || 0
          });
        } catch (e) {}
      }
      function consoleValueToString(value){
        try {
          if (value instanceof Error) { return value.stack || value.message || String(value); }
          if (value && typeof value === 'object') {
            try { return JSON.stringify(value); } catch (e) {}
          }
          return String(value);
        } catch (e) {
          return '[unserializable console value]';
        }
      }
      function consoleArgumentsToString(args){
        return Array.prototype.slice.call(args).map(consoleValueToString).join(' ');
      }
      function errorEventMessage(event){
        var message = event && event.message ? String(event.message) : 'Error';
        var detail = event && event.error ? consoleValueToString(event.error) : null;
        if (detail && detail !== message) { return message + '\\n' + detail; }
        return message;
      }
      function rejectionMessage(event){
        var reason = event && 'reason' in event ? event.reason : undefined;
        return 'Unhandled promise rejection: ' + consoleValueToString(reason);
      }
      function wrapConsole(method, level){
        var original = console[method];
        console[method] = function(){
          post(level, consoleArgumentsToString(arguments), null, 0, 0);
          if (typeof original === 'function') { return original.apply(console, arguments); }
        };
      }
      window.addEventListener('error', function(e){ post('error', errorEventMessage(e), e && e.filename, e && e.lineno, e && e.colno); });
      window.addEventListener('unhandledrejection', function(e){ post('error', rejectionMessage(e), null, 0, 0); });
      wrapConsole('debug', 'diagnostic');
      wrapConsole('log', 'diagnostic');
      wrapConsole('info', 'info');
      wrapConsole('warn', 'warning');
      wrapConsole('error', 'error');
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

    var styleRulePatch: HTMLWorkspaceStyleRulePatch? {
        let declarations = Self.styleRuleDeclarations(from: styles)
        guard !declarations.isEmpty else { return nil }
        return HTMLWorkspaceStyleRulePatch(selector: selector, declarations: declarations)
    }

    func styleRulePatch(property: String, value: String) -> HTMLWorkspaceStyleRulePatch? {
        let trimmedProperty = property.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSafeStyleDeclaration(name: trimmedProperty, value: trimmedValue) else { return nil }
        return HTMLWorkspaceStyleRulePatch(
            selector: selector,
            declarations: [trimmedProperty: trimmedValue]
        )
    }

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
        let rawStyles = payload["styles"] as? [String: Any] ?? [:]
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

    private static let promotedStyleProperties = [
        "display",
        "position",
        "color",
        "background-color",
        "font-family",
        "font-size",
        "font-weight",
        "line-height",
        "margin",
        "padding",
        "border-radius",
        "border-color",
    ]

    private static func styleRuleDeclarations(from styles: [String: String]) -> [String: String] {
        var declarations: [String: String] = [:]
        for property in promotedStyleProperties {
            guard let value = normalizedStyleValue(styles[property], for: property) else { continue }
            declarations[property] = value
        }
        return declarations
    }

    private static func normalizedStyleValue(_ value: String?, for property: String) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch property {
        case "background-color", "border-color":
            let lowercased = trimmed.lowercased()
            guard lowercased != "transparent",
                  lowercased != "rgba(0, 0, 0, 0)" else {
                return nil
            }
        case "display":
            guard trimmed.lowercased() != "block" else { return nil }
        case "position":
            guard trimmed.lowercased() != "static" else { return nil }
        default:
            break
        }
        return isSafeStyleDeclaration(name: property, value: trimmed) ? trimmed : nil
    }

    private static func isSafeStyleDeclaration(name: String, value: String) -> Bool {
        let property = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !property.isEmpty,
              property == name,
              property.range(of: #"^[A-Za-z-]+$"#, options: .regularExpression) != nil,
              !value.isEmpty,
              !value.contains("{"),
              !value.contains("}"),
              !value.contains(";"),
              !value.contains("<"),
              value.count <= 512 else {
            return false
        }
        let lowercasedValue = value.lowercased()
        return !lowercasedValue.contains("javascript:")
            && !lowercasedValue.contains("expression(")
            && !lowercasedValue.contains("@import")
    }
}

nonisolated enum HTMLWorkspaceInspectorBridge {
    static let messageHandlerName = "epistemosWorkspaceInspector"

    static let disableScript = """
    window.__epistemosInspectorEnabled = false;
    document.documentElement.removeAttribute('data-epistemos-inspector-active');
    if (window.__epistemosInspectorHover) {
      window.__epistemosInspectorHover.removeAttribute('data-epistemos-inspector-hover');
      window.__epistemosInspectorHover = null;
    }
    if (window.__epistemosInspectorSelected) {
      window.__epistemosInspectorSelected.removeAttribute('data-epistemos-inspected');
      window.__epistemosInspectorSelected = null;
    }
    """

    static let installScript = """
    (function(){
      if (window.__epistemosInspectorInstalled) {
        window.__epistemosInspectorEnabled = true;
        document.documentElement.setAttribute('data-epistemos-inspector-active', 'true');
        return;
      }
      window.__epistemosInspectorInstalled = true;
      window.__epistemosInspectorEnabled = true;
      document.documentElement.setAttribute('data-epistemos-inspector-active', 'true');
      if (!document.getElementById('epistemos-inspector-highlight-style')) {
        var highlightStyle = document.createElement('style');
        highlightStyle.id = 'epistemos-inspector-highlight-style';
        highlightStyle.textContent = 'html[data-epistemos-inspector-active="true"], html[data-epistemos-inspector-active="true"] * { cursor: crosshair !important; } [data-epistemos-inspector-hover="true"] { box-shadow: 0 0 0 1px var(--epistemos-workspace-accent), 0 0 0 4px color-mix(in srgb, var(--epistemos-workspace-accent) 16%, transparent) !important; } [data-epistemos-inspected="true"] { box-shadow: 0 0 0 2px var(--epistemos-workspace-accent), 0 0 0 6px color-mix(in srgb, var(--epistemos-workspace-accent) 22%, transparent) !important; }';
        document.head.appendChild(highlightStyle);
      }
      function bounded(value, limit) {
        return String(value || '').slice(0, limit);
      }
      function elementFor(value) {
        if (!value) { return null; }
        if (value.nodeType === 1) { return value; }
        if (value.parentElement && value.parentElement.nodeType === 1) { return value.parentElement; }
        return null;
      }
      function classesFor(node, limit) {
        return Array.prototype.slice.call(node.classList || []).slice(0, limit).map(function(name) {
          return bounded(name, 96);
        });
      }
      function escapeIdent(value, limit) {
        var raw = bounded(value, limit);
        if (window.CSS && typeof window.CSS.escape === 'function') {
          return window.CSS.escape(raw);
        }
        return raw.replace(/[^a-zA-Z0-9_-]/g, '\\$&');
      }
      function nthOfType(node) {
        var index = 1;
        var tag = node && node.tagName ? String(node.tagName).toLowerCase() : '';
        var sibling = node ? node.previousElementSibling : null;
        while (sibling) {
          if (String(sibling.tagName || '').toLowerCase() === tag) { index += 1; }
          sibling = sibling.previousElementSibling;
        }
        return index;
      }
      function selectorSegmentFor(node) {
        if (!node || !node.tagName) { return 'unknown'; }
        var tag = String(node.tagName).toLowerCase();
        if (node.id) { return tag + '#' + escapeIdent(node.id, 128); }
        var classes = classesFor(node, 4).map(function(name){ return escapeIdent(name, 96); });
        if (classes.length) { return tag + classes.map(function(name){ return '.' + name; }).join(''); }
        if (tag === 'html' || tag === 'body') { return tag; }
        return tag + ':nth-of-type(' + nthOfType(node) + ')';
      }
      function selectorFor(node) {
        if (!node || !node.tagName) { return 'unknown'; }
        var parts = [];
        var current = node;
        while (current && current.tagName && parts.length < 4) {
          var segment = selectorSegmentFor(current);
          parts.unshift(segment);
          if (current.id || segment === 'body' || segment === 'html') { break; }
          current = current.parentElement;
        }
        return parts.join(' > ') || selectorSegmentFor(node);
      }
      function textFor(node) {
        return String((node && node.textContent) || '').replace(/\\s+/g, ' ').trim().slice(0, 240);
      }
      function markSelected(node) {
        node = elementFor(node);
        if (!node) { return; }
        if (window.__epistemosInspectorSelected && window.__epistemosInspectorSelected !== node) {
          window.__epistemosInspectorSelected.removeAttribute('data-epistemos-inspected');
        }
        if (window.__epistemosInspectorHover) {
          window.__epistemosInspectorHover.removeAttribute('data-epistemos-inspector-hover');
          window.__epistemosInspectorHover = null;
        }
        window.__epistemosInspectorSelected = node;
        if (node && node.setAttribute) {
          node.setAttribute('data-epistemos-inspected', 'true');
        }
      }
      function markHovered(node) {
        node = elementFor(node);
        if (!node) { return; }
        if (window.__epistemosInspectorHover && window.__epistemosInspectorHover !== node) {
          window.__epistemosInspectorHover.removeAttribute('data-epistemos-inspector-hover');
        }
        window.__epistemosInspectorHover = node;
        if (node && node.setAttribute && node !== window.__epistemosInspectorSelected) {
          node.setAttribute('data-epistemos-inspector-hover', 'true');
        }
      }
      function clearHovered(node) {
        node = elementFor(node);
        if (node && node === window.__epistemosInspectorHover) {
          node.removeAttribute('data-epistemos-inspector-hover');
          window.__epistemosInspectorHover = null;
        }
      }
      function post(node) {
        node = elementFor(node);
        if (!node) { return false; }
        markSelected(node);
        var style = window.getComputedStyle(node);
        var keys = ['display','position','width','height','margin','padding','color','background-color','font-family','font-size','font-weight','line-height','border-radius','border-color'];
        var styles = {};
        keys.forEach(function(key){ styles[key] = style.getPropertyValue(key); });
        try {
          window.webkit.messageHandlers.epistemosWorkspaceInspector.postMessage({
            selector: selectorFor(node),
            tagName: String(node.tagName || '').toLowerCase(),
            id: node.id ? bounded(node.id, 128) : null,
            classes: classesFor(node, 12),
            text: textFor(node),
            styles: styles
          });
          return true;
        } catch (e) {}
        return false;
      }
      window.__epistemosInspectElement = post;
      document.addEventListener('mouseover', function(event) {
        if (!window.__epistemosInspectorEnabled) { return; }
        markHovered(event.target);
      }, true);
      document.addEventListener('mouseout', function(event) {
        if (!window.__epistemosInspectorEnabled) { return; }
        clearHovered(event.target);
      }, true);
      document.addEventListener('click', function(event) {
        if (!window.__epistemosInspectorEnabled) { return; }
        event.preventDefault();
        event.stopPropagation();
        post(event.target);
      }, true);
    })();
    """

    static let probeScript = """
    (function(){
      if (!window.__epistemosInspectorEnabled || typeof window.__epistemosInspectElement !== 'function') {
        return 'missing';
      }
      var target = document.querySelector('[data-epistemos-inspect], main, article, section, button, a, body') || document.body || document.documentElement;
      if (!target) { return 'missing-target'; }
      return window.__epistemosInspectElement(target) ? 'posted' : 'post-failed';
    })();
    """
}
