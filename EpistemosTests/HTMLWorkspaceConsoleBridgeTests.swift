import Testing
import Foundation

@testable import Epistemos

// SS-HW seam upgrade — the JS console / error-capture bridge that was a deferred empty stub. The
// document's console pipeline (HTMLWorkspaceConsoleError + .recordConsoleError + the console panel)
// already existed; only the JS→Swift capture was missing. These pin the capture script + its
// default-on behavior + the wiring into the existing pipeline + the honest capability-ledger note.
@Suite("SS-HW — JS console capture bridge")
struct HTMLWorkspaceConsoleBridgeTests {

    @Test("the console-capture bridge defaults ON with an env opt-out")
    func flagDefaultsOnWithOptOut() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"] == nil {
            #expect(HTMLWorkspaceConsoleBridge.enabled == true)
        }
        #expect(!HTMLWorkspaceConsoleCapturePolicy.isEnabled(environment: ["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0": "0"]))
    }

    @Test("the injection script captures window errors + console diagnostics and posts to the handler")
    func injectionScriptCapturesErrors() {
        let js = HTMLWorkspaceConsoleBridge.injectionScript
        #expect(js.contains("addEventListener('error'"))
        #expect(js.contains("unhandledrejection"))
        #expect(js.contains("console.debug"))
        #expect(js.contains("console.log"))
        #expect(js.contains("console.info"))
        #expect(js.contains("console.error"))
        #expect(js.contains("console.warn"))
        #expect(js.contains("window.__epistemosConsoleBridgeInstalled === true"))
        #expect(js.contains("Object.defineProperty(window, '__epistemosConsoleBridgeInstalled'"))
        #expect(js.contains("level: String(level || 'error')"))
        #expect(js.contains("var maxMessageLength = \(HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters);"))
        #expect(js.contains("var maxSourceLength = \(HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters);"))
        #expect(js.contains("function boundedText(value, limit)"))
        #expect(js.contains("... [truncated]"))
        #expect(js.contains("message: boundedText(message, maxMessageLength)"))
        #expect(js.contains("source: source ? boundedText(source, maxSourceLength) : null"))
        #expect(js.contains("wrapConsole('debug', 'diagnostic')"))
        #expect(js.contains("wrapConsole('log', 'diagnostic')"))
        #expect(js.contains("wrapConsole('info', 'info')"))
        #expect(js.contains("wrapConsole('warn', 'warning')"))
        #expect(js.contains("consoleValueToString"))
        #expect(js.contains("function errorEventMessage(event)"))
        #expect(js.contains("event.error ? consoleValueToString(event.error) : null"))
        #expect(js.contains("function rejectionMessage(event)"))
        #expect(js.contains("consoleValueToString(reason)"))
        #expect(js.contains("[unserializable console value]"))
        #expect(js.contains("typeof original === 'function'"))
        #expect(js.contains("post('error', errorEventMessage(e), e && e.filename, e && e.lineno, e && e.colno)"))
        #expect(js.contains("post('error', rejectionMessage(e), null, 0, 0)"))
        #expect(js.contains("messageHandlers.epistemosWorkspaceConsole.postMessage"))
        #expect(HTMLWorkspaceConsoleBridge.messageHandlerName == "epistemosWorkspaceConsole")
    }

    @Test("console payloads are bounded before entering the editor pipeline")
    func diagnosticPayloadBoundsWebKitMessages() throws {
        let diagnostic = try #require(HTMLWorkspaceConsoleBridge.DiagnosticPayload.fromMessageBody([
            "message": String(repeating: "m", count: HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters + 100),
            "source": String(repeating: "s", count: HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters + 100),
            "line": NSNumber(value: -4),
            "column": NSNumber(value: UInt64(UInt32.max) + 99),
            "level": "warn",
        ]))

        #expect(diagnostic.message.count == HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters)
        #expect(diagnostic.message.hasSuffix("... [truncated]"))
        #expect(diagnostic.source?.count == HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters)
        #expect(diagnostic.source?.hasSuffix("... [truncated]") == true)
        #expect(diagnostic.line == 0)
        #expect(diagnostic.column == UInt32.max)
        #expect(diagnostic.severity == .warning)
        #expect(HTMLWorkspaceConsoleSeverity.fromBridgeLevel("debug") == .diagnostic)
    }

    @Test("the editor records captured errors through the existing .recordConsoleError pipeline")
    func editorWiresCaptureToPipeline() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(editor.contains("onConsoleError:"))
        #expect(editor.contains(".recordConsoleError(error)"))
        #expect(editor.contains("onClear: clearConsole"))
        #expect(editor.contains("HTMLWorkspacePatchApplier.apply(.clearConsole, to: package)"))
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")
        let panels = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPanels.swift")
        let bridges = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceRuntimeBridges.swift")
        #expect(preview.contains("HTMLWorkspaceConsoleBridge.messageHandlerName"))
        #expect(preview.contains("HTMLWorkspaceConsoleBridge.DiagnosticPayload.fromMessageBody"))
        #expect(preview.contains("syncConsoleHandler(for: webView)"))
        #expect(preview.contains("installConsoleBridgeUserScript(on:"))
        #expect(preview.contains("consoleUserScriptInstalled"))
        #expect(preview.contains("webView.evaluateJavaScript(HTMLWorkspaceConsoleBridge.injectionScript)"))
        #expect(preview.contains("removeAllUserScripts()"))
        #expect(bridges.contains("__epistemosConsoleBridgeInstalled"))
        #expect(preview.contains("requestConsoleProbe"))
        #expect(preview.contains("consoleProbeScript"))
        #expect(preview.contains("HTML Workspace log probe"))
        #expect(preview.contains("HTML Workspace info probe"))
        #expect(preview.contains("HTML Workspace console probe"))
        #expect(preview.contains("HTML Workspace error probe"))
        #expect(preview.contains("HTML Workspace window error probe"))
        #expect(preview.contains("HTML Workspace rejection probe"))
        #expect(preview.contains("onConsoleError?(error.boundedForPackage())"))
        #expect(preview.contains("source: diagnostic.source ?? activeDocumentSourceName"))
        #expect(preview.contains("severity: diagnostic.severity"))
        #expect(preview.contains(#"return "\(HTMLWorkspacePackageEntry.routes)/\(routeName)""#))
        #expect(panels.contains("Button(action: onClear)"))
        #expect(panels.contains(#"Label("Clear console", systemImage: "trash")"#))
        #expect(panels.contains("severityLabel(for: error.severity)"))
        #expect(panels.contains(#""WARN""#))
        #expect(panels.contains(#""ERROR""#))
        // The console handler is cleaned up on detach (no leaked WKScriptMessageHandler).
        #expect(preview.contains("consoleHandlerInstalled = false"))
    }

    @Test("the capability ledger honestly notes the bridge is wired but not live-proven")
    func ledgerNotesWiredBridgeAwaitingInAppProof() {
        let console = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name.contains("JS console") }
        #expect(console != nil)
        #expect(console?.isLive == false)
        #expect(console?.note.contains("wired") == true)
        #expect(console?.note.contains("log/info/warn/error") == true)
        #expect(console?.note.contains("typed severity/source pipeline") == true)
        #expect(console?.note.contains("clearable panel") == true)
        #expect(console?.note.contains("manual probe path") == true)
        #expect(console?.note.contains("awaits current in-app proof") == true)
    }

    @Test("DOM inspector exposes a selector copy action through the editor")
    func domInspectorExposesSelectorCopyAction() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let panels = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPanels.swift")
        let bridges = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceRuntimeBridges.swift")

        #expect(editor.contains("onCopySelector: copyInspectorSelector"))
        #expect(editor.contains("onCreateStyleRule: addInspectorStyleRule"))
        #expect(editor.contains("onCopyStyleRulePatch: copyInspectorStyleRulePatch"))
        #expect(editor.contains("onUpdateStyleDeclaration: updateInspectorStyleDeclaration"))
        #expect(editor.contains("onCopyStyleDeclarationPatch: copyInspectorStyleDeclarationPatch"))
        #expect(editor.contains("private func copyInspectorSelector(_ selector: String)"))
        #expect(editor.contains("NSPasteboard.general.setString(selector, forType: .string)"))
        #expect(editor.contains(#"statusText = "Selected \(boundedInspectorSelectorStatus(inspection.selector))""#))
        #expect(editor.contains("private func boundedInspectorSelectorStatus(_ value: String) -> String"))
        #expect(editor.contains("private func addInspectorStyleRule(_ inspection: HTMLWorkspaceElementInspection)"))
        #expect(editor.contains("guard let styleRulePatch = inspection.styleRulePatch else"))
        #expect(editor.contains(".updateStyleRule(styleRulePatch)"))
        #expect(editor.contains(#"""
            previewPackage = package
            liveDOMSnapshot = nil
            statusText = "Inspected styles added"
            """#))
        #expect(editor.contains("private func copyInspectorStyleRulePatch(_ inspection: HTMLWorkspaceElementInspection)"))
        #expect(editor.contains("private func updateInspectorStyleDeclaration("))
        #expect(editor.contains("inspection.styleRulePatch(property: property, value: value)"))
        #expect(editor.contains("private func copyInspectorStyleDeclarationPatch("))
        #expect(editor.contains("private func copyInspectorStylePatch(_ styleRulePatch: HTMLWorkspaceStyleRulePatch)"))
        #expect(editor.contains("HTMLWorkspacePatchCommandBatch("))
        #expect(editor.contains("HTMLWorkspacePatchCommandParser.fencedLanguage"))
        #expect(editor.contains(#"statusText = "Style patch copied""#))
        #expect(editor.contains(#"statusText = "Style updated""#))
        #expect(editor.contains("selectedPane = .css"))
        #expect(panels.contains("let onCopySelector: (String) -> Void"))
        #expect(panels.contains("let onCreateStyleRule: (HTMLWorkspaceElementInspection) -> Void"))
        #expect(panels.contains("let onCopyStyleRulePatch: (HTMLWorkspaceElementInspection) -> Void"))
        #expect(panels.contains("let onUpdateStyleDeclaration: (HTMLWorkspaceElementInspection, String, String) -> Void"))
        #expect(panels.contains("let onCopyStyleDeclarationPatch: (HTMLWorkspaceElementInspection, String, String) -> Void"))
        #expect(panels.contains(#"Label("Copy selector", systemImage: "doc.on.doc")"#))
        #expect(panels.contains(#"Label("Add style rule", systemImage: "paintbrush")"#))
        #expect(panels.contains(#"Label("Apply style", systemImage: "checkmark")"#))
        #expect(panels.contains(#"Label("Copy style patch", systemImage: "curlybraces")"#))
        #expect(panels.contains("onCopySelector(selectedElementInspection.selector)"))
        #expect(panels.contains("onCreateStyleRule(selectedElementInspection)"))
        #expect(panels.contains("onCopyStyleRulePatch(selectedElementInspection)"))
        #expect(panels.contains("onUpdateStyleDeclaration(inspection, styleProperty, styleValue)"))
        #expect(panels.contains("onCopyStyleDeclarationPatch(inspection, styleProperty, styleValue)"))
        #expect(bridges.contains("function escapeIdent(value, limit)"))
        #expect(bridges.contains("window.CSS.escape(raw)"))
        #expect(bridges.contains("epistemos-inspector-highlight-style"))
        #expect(bridges.contains("data-epistemos-inspector-active"))
        #expect(bridges.contains("data-epistemos-inspector-hover"))
        #expect(bridges.contains("cursor: crosshair"))
        #expect(bridges.contains("data-epistemos-inspected"))
        #expect(bridges.contains("function markHovered(node)"))
        #expect(bridges.contains("function clearHovered(node)"))
        #expect(bridges.contains("function markSelected(node)"))
        #expect(bridges.contains("function elementFor(value)"))
        #expect(bridges.contains("if (value.nodeType === 1) { return value; }"))
        #expect(bridges.contains("if (value.parentElement && value.parentElement.nodeType === 1) { return value.parentElement; }"))
        #expect(bridges.contains("node = elementFor(node);"))
        #expect(bridges.contains("if (!node) { return false; }"))
        #expect(bridges.contains("return window.__epistemosInspectElement(target) ? 'posted' : 'post-failed';"))
        #expect(bridges.contains("document.addEventListener('mouseover'"))
        #expect(bridges.contains("document.addEventListener('mouseout'"))
        #expect(bridges.contains("window.__epistemosInspectorSelected.removeAttribute('data-epistemos-inspected')"))
        #expect(bridges.contains("window.__epistemosInspectorHover.removeAttribute('data-epistemos-inspector-hover')"))
        #expect(bridges.contains("function nthOfType(node)"))
        #expect(bridges.contains("function selectorSegmentFor(node)"))
        #expect(bridges.contains("previousElementSibling"))
        #expect(bridges.contains("return tag + ':nth-of-type(' + nthOfType(node) + ')'"))
        #expect(bridges.contains("while (current && current.tagName && parts.length < 4)"))
        #expect(bridges.contains("return parts.join(' > ') || selectorSegmentFor(node)"))
        #expect(bridges.contains("return tag + '#' + escapeIdent(node.id, 128)"))
        #expect(bridges.contains("classesFor(node, 4).map(function(name){ return escapeIdent(name, 96); })"))
        #expect(bridges.contains("try {\n          window.webkit.messageHandlers.epistemosWorkspaceInspector.postMessage"))
        #expect(bridges.contains("} catch (e) {}"))
        #expect(bridges.contains("Self.isSafeStyleDeclaration(name: safeKey, value: safeValue)"))
    }

    @Test("DOM inspector style payloads accept WebKit dictionary shapes")
    func domInspectorStylePayloadsAcceptWebKitDictionaryShapes() throws {
        let inspection = try #require(HTMLWorkspaceElementInspection.fromMessageBody([
            "selector": "main#hero",
            "tagName": "main",
            "classes": ["hero"],
            "text": "Hello",
            "styles": [
                "font-size": "16px",
                "background-color": "rgb(0, 0, 0)",
            ] as [String: Any],
        ]))

        #expect(inspection.selector == "main#hero")
        #expect(inspection.styles["font-size"] == "16px")
        #expect(inspection.styles["background-color"] == "rgb(0, 0, 0)")
    }

    @Test("DOM inspector drops unsafe style payload values before panel state")
    func domInspectorDropsUnsafeStylePayloadValues() throws {
        let inspection = try #require(HTMLWorkspaceElementInspection.fromMessageBody([
            "selector": "main#hero",
            "tagName": "main",
            "styles": [
                "font-size": "16px",
                "background-image": "url(javascript:alert(1))",
                "width": "expression(alert(1))",
                "color": "red; background: blue",
                "bad key": "10px",
            ] as [String: Any],
        ]))

        #expect(inspection.styles["font-size"] == "16px")
        #expect(inspection.styles["background-image"] == nil)
        #expect(inspection.styles["width"] == nil)
        #expect(inspection.styles["color"] == nil)
        #expect(inspection.styles["bad key"] == nil)
    }

    @Test("DOM inspector can promote captured styles into a validated style patch")
    func domInspectorPromotesCapturedStylesIntoStylePatch() throws {
        let inspection = try #require(HTMLWorkspaceElementInspection.fromMessageBody([
            "selector": "section.hero",
            "tagName": "section",
            "styles": [
                "display": "grid",
                "position": "static",
                "color": "rgb(15, 23, 42)",
                "background-color": "transparent",
                "font-size": "18px",
                "font-weight": "700",
                "width": "640px",
            ] as [String: Any],
        ]))

        let patch = try #require(inspection.styleRulePatch)

        #expect(patch.selector == "section.hero")
        #expect(patch.declarations["display"] == "grid")
        #expect(patch.declarations["color"] == "rgb(15, 23, 42)")
        #expect(patch.declarations["font-size"] == "18px")
        #expect(patch.declarations["font-weight"] == "700")
        #expect(patch.declarations["position"] == nil)
        #expect(patch.declarations["background-color"] == nil)
        #expect(patch.declarations["width"] == nil)
    }

    @Test("DOM inspector can build a focused style declaration patch")
    func domInspectorBuildsFocusedStyleDeclarationPatch() throws {
        let inspection = try #require(HTMLWorkspaceElementInspection.fromMessageBody([
            "selector": "button.primary",
            "tagName": "button",
            "styles": [:] as [String: Any],
        ]))

        let patch = try #require(inspection.styleRulePatch(property: " color ", value: " rebeccapurple "))

        #expect(patch.selector == "button.primary")
        #expect(patch.declarations == ["color": "rebeccapurple"])
        #expect(inspection.styleRulePatch(property: "", value: "red") == nil)
        #expect(inspection.styleRulePatch(property: "color", value: " ") == nil)
        #expect(inspection.styleRulePatch(property: " color ", value: "red") == nil)
        #expect(inspection.styleRulePatch(property: "background-image", value: "url(javascript:alert(1))") == nil)
        #expect(inspection.styleRulePatch(property: "width", value: "expression(alert(1))") == nil)
        #expect(inspection.styleRulePatch(property: "color", value: "@import url(evil.css)") == nil)
    }

    @Test("Python demo scaffold enables the runtime and adds editable source panes")
    func pythonDemoScaffoldAddsEditableSourcePanes() throws {
        var package = HTMLWorkspacePackage.defaultPackage()
        package.manifest.sandboxPolicy.allowPythonRuntime = false

        let updated = try HTMLWorkspacePythonDemoScaffold.apply(to: package, updatedAt: 123)

        #expect(updated.manifest.sandboxPolicy.allowPythonRuntime == true)
        #expect(updated.indexHTML.contains("data-python-output"))
        #expect(updated.styleCSS.contains(".python-demo"))
        #expect(updated.styleCSS.contains(".python-demo pre"))
        #expect(updated.scriptJS.contains(HTMLWorkspacePythonDemoScaffold.scriptMarker))
        #expect(updated.scriptJS.contains("window.HTMLWorkspace.python"))
        #expect(updated.scriptJS.contains("runtime.run(code)"))
        #expect(updated.scriptJS.contains("runtime.missingResources"))
        #expect(updated.scriptJS.contains("app.record('python.demo.completed'"))
        #expect(updated.scriptJS.contains("result: String(result)"))
        #expect(updated.manifest.updatedAt == 123)
        #expect(updated.manifest.contentHash == updated.currentContentHash)
    }

    @Test("Python runtime exposes a manual probe affordance")
    func pythonRuntimeExposesManualProbeAffordance() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")

        #expect(editor.contains(#"Button("Test Python Runtime""#))
        #expect(editor.contains("pythonProbeNonce &+= 1"))
        #expect(editor.contains("Python runtime probe requested"))
        #expect(editor.contains("HTMLWorkspacePythonRuntime.availabilityStatusText"))
        #expect(preview.contains("var pythonProbeNonce: Int = 0"))
        #expect(preview.contains("pendingPythonProbeNonce"))
        #expect(preview.contains("func requestPythonProbe(_ nonce: Int, in webView: WKWebView)"))
        #expect(preview.contains("Python runtime manual probe"))
    }

    @Test("Python runtime exposes missing-resource diagnostics without paths")
    func pythonRuntimeExposesMissingResourceDiagnostics() throws {
        let runtime = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspacePythonRuntime.swift")
        let previewDocument = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspacePreviewDocument.swift")
        let bundleScript = try loadMirroredSourceTextFile("bundle-app-runtime-assets.sh")

        #expect(runtime.contains("static var missingRequiredResourceNames"))
        #expect(runtime.contains("availabilityStatusText"))
        #expect(!runtime.contains("availabilityStatusText:"))
        #expect(previewDocument.contains("const missingResources ="))
        #expect(previewDocument.contains("missingResources,"))
        #expect(previewDocument.contains("const maxCodeLength = 20000"))
        #expect(previewDocument.contains("let runQueue = Promise.resolve()"))
        #expect(previewDocument.contains("function boundedCode(code)"))
        #expect(previewDocument.contains("throw new Error('HTML Workspace Python code is too large')"))
        #expect(previewDocument.contains("const source = boundedCode(code);"))
        #expect(previewDocument.contains("return await loadPromise;"))
        #expect(previewDocument.contains("loadPromise = null;"))
        #expect(previewDocument.contains("const result = runQueue.then(execute, execute);"))
        #expect(previewDocument.contains("runQueue = result.catch(() => {});"))
        #expect(previewDocument.contains("pyodide.runPythonAsync(source)"))
        #expect(previewDocument.contains("stringArrayLiteral(HTMLWorkspacePythonRuntime.missingRequiredResourceNames)"))
        #expect(bundleScript.contains(#"[ -f "$candidate/pyodide.mjs" ]"#))
        #expect(bundleScript.contains(#"[ -f "$candidate/pyodide.asm.mjs" ]"#))
    }

    @Test("Python demo scaffold is idempotent when inserted twice")
    func pythonDemoScaffoldIsIdempotent() throws {
        let once = try HTMLWorkspacePythonDemoScaffold.apply(to: HTMLWorkspacePackage.defaultPackage(), updatedAt: 123)
        let twice = try HTMLWorkspacePythonDemoScaffold.apply(to: once, updatedAt: 456)

        #expect(twice.scriptJS.components(separatedBy: HTMLWorkspacePythonDemoScaffold.scriptMarker).count == 2)
        #expect(twice.indexHTML == once.indexHTML)
        #expect(twice.styleCSS == once.styleCSS)
        #expect(twice.manifest.updatedAt == 456)
    }

    @Test("app bridge demo scaffold enables bridge and adds editable source panes")
    func appBridgeDemoScaffoldAddsEditableSourcePanes() throws {
        var package = HTMLWorkspacePackage.defaultPackage()
        package.manifest.sandboxPolicy.allowAppBridge = false
        package.manifest.sandboxPolicy.safeAPIVersion = 0

        let updated = try HTMLWorkspaceAppBridgeDemoScaffold.apply(to: package, updatedAt: 123)

        #expect(updated.manifest.sandboxPolicy.allowAppBridge == true)
        #expect(updated.manifest.sandboxPolicy.safeAPIVersion == 1)
        #expect(updated.indexHTML.contains("data-app-bridge-demo"))
        #expect(updated.indexHTML.contains("data-app-bridge-output"))
        #expect(updated.indexHTML.contains("data-app-bridge-action"))
        #expect(updated.styleCSS.contains(".app-bridge-demo"))
        #expect(updated.styleCSS.contains(".app-bridge-demo button"))
        #expect(updated.styleCSS.contains(".app-bridge-demo output"))
        #expect(updated.scriptJS.contains(HTMLWorkspaceAppBridgeDemoScaffold.scriptMarker))
        #expect(updated.scriptJS.contains("window.HTMLWorkspace && window.HTMLWorkspace.app"))
        #expect(updated.scriptJS.contains("app.request('ping', label)"))
        #expect(updated.scriptJS.contains("detail.requestId ?"))
        #expect(updated.scriptJS.contains("App bridge failed:"))
        #expect(updated.scriptJS.contains("App bridge' + version + ': sending...'"))
        #expect(updated.scriptJS.contains("app.status()"))
        #expect(updated.scriptJS.contains("app.record('app.bridge.demo', { source: 'demo scaffold', probe: label })"))
        #expect(updated.manifest.updatedAt == 123)
        #expect(updated.manifest.contentHash == updated.currentContentHash)
    }

    @Test("app bridge demo scaffold is idempotent when inserted twice")
    func appBridgeDemoScaffoldIsIdempotent() throws {
        let once = try HTMLWorkspaceAppBridgeDemoScaffold.apply(to: HTMLWorkspacePackage.defaultPackage(), updatedAt: 123)
        let twice = try HTMLWorkspaceAppBridgeDemoScaffold.apply(to: once, updatedAt: 456)

        #expect(twice.scriptJS.components(separatedBy: HTMLWorkspaceAppBridgeDemoScaffold.scriptMarker).count == 2)
        #expect(twice.indexHTML == once.indexHTML)
        #expect(twice.styleCSS == once.styleCSS)
        #expect(twice.manifest.sandboxPolicy.allowAppBridge == true)
        #expect(twice.manifest.updatedAt == 456)
    }
}

@Suite("SS-HW — app bridge payloads")
struct HTMLWorkspaceSafeAPIBridgeTests {
    @Test("safe API string messages become bounded commands")
    func stringMessagesBecomeBoundedCommands() throws {
        let command = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody("  ping  "))

        #expect(command.name == "ping")
        #expect(command.message == nil)
    }

    @Test("safe API dictionary messages use bounded command and payload text")
    func dictionaryMessagesUseBoundedCommandAndPayloadText() throws {
        let command = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody([
            "type": String(repeating: "x", count: HTMLWorkspaceSafeAPI.maxCommandLength + 100),
            "payload": [
                "label": String(repeating: "m", count: HTMLWorkspaceSafeAPI.maxMessageLength + 100),
            ],
        ]))

        #expect(command.name.count == HTMLWorkspaceSafeAPI.maxCommandLength)
        #expect(command.message?.count == HTMLWorkspaceSafeAPI.maxMessageLength)
        #expect(command.requestID == nil)
        #expect(command.eventName == nil)
        #expect(command.attributes.isEmpty)
    }

    @Test("safe API dictionary messages carry bounded request IDs for response correlation")
    func dictionaryMessagesCarryBoundedRequestIDs() throws {
        let command = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody([
            "command": "ping",
            "requestId": String(repeating: "r", count: HTMLWorkspaceSafeAPI.maxRequestIDLength + 20),
        ]))

        #expect(command.name == "ping")
        #expect(command.requestID?.count == HTMLWorkspaceSafeAPI.maxRequestIDLength)
    }

    @Test("safe API event records keep bounded structured attributes")
    func eventRecordsKeepBoundedStructuredAttributes() throws {
        let command = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody([
            "command": "event.record",
            "payload": [
                "eventName": String(repeating: "e", count: HTMLWorkspaceSafeAPI.maxEventNameLength + 20),
                "attributes": [
                    "source": "demo scaffold",
                    "count": 3,
                    "enabled": true,
                    "ignored": ["nested"],
                ],
            ],
        ]))

        #expect(command.name == "event.record")
        #expect(command.eventName?.count == HTMLWorkspaceSafeAPI.maxEventNameLength)
        #expect(command.attributes["source"] == "demo scaffold")
        #expect(command.attributes["count"] == "3")
        #expect(command.attributes["ignored"] == nil)
    }

    @Test("safe API event records cap structured attribute count")
    func eventRecordsCapStructuredAttributeCount() throws {
        var rawAttributes: [String: Any] = [
            "source": "demo scaffold",
            "count": 3,
            "enabled": true,
        ]
        for index in 0...HTMLWorkspaceSafeAPI.maxAttributeCount {
            rawAttributes["extra-\(index)"] = String(repeating: "x", count: HTMLWorkspaceSafeAPI.maxAttributeValueLength + 20)
        }
        let command = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody([
            "command": "event.record",
            "payload": [
                "eventName": String(repeating: "e", count: HTMLWorkspaceSafeAPI.maxEventNameLength + 20),
                "attributes": rawAttributes,
            ],
        ]))

        #expect(command.attributes.count == HTMLWorkspaceSafeAPI.maxAttributeCount)
        #expect(command.attributes.values.allSatisfy { $0.count <= HTMLWorkspaceSafeAPI.maxAttributeValueLength })
    }

    @Test("safe API diagnostics are generated by the shared runtime bridge contract")
    func diagnosticsComeFromRuntimeBridgeContract() throws {
        let status = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody(["command": "status"]))
        let unsupported = try #require(HTMLWorkspaceSafeAPI.Command.fromMessageBody(["command": "danger.zone"]))
        let package = HTMLWorkspacePackage.defaultPackage()

        #expect(status.isSupported)
        #expect(!unsupported.isSupported)
        #expect(HTMLWorkspaceSafeAPI.diagnosticMessage(for: status, package: package).contains("safeAPI v1"))
        #expect(HTMLWorkspaceSafeAPI.diagnosticMessage(for: unsupported, package: package).contains("unsupported command"))

        let preview = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")
        let bridges = try loadMirroredSourceTextFile("Epistemos/Engine/HTMLWorkspaceRuntimeBridges.swift")
        let previewDocument = try loadMirroredSourceTextFile("Epistemos/Models/HTMLWorkspacePreviewDocument.swift")
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(preview.contains("HTMLWorkspaceSafeAPI.Command.fromMessageBody"))
        #expect(preview.contains("App bridge probe:"))
        #expect(preview.contains("weak var webView: WKWebView?"))
        #expect(preview.contains("dispatchAppBridgeResponse(command: command, in: webView)"))
        #expect(preview.contains("htmlworkspace:appbridge"))
        #expect(preview.contains("CustomEvent('htmlworkspace:appbridge'"))
        #expect(preview.contains("requestId: \\(Self.optionalJavaScriptStringLiteral(command.requestID))"))
        #expect(preview.contains("ok: \\(isSupported ? \"true\" : \"false\")"))
        #expect(preview.contains("error: \\(Self.optionalJavaScriptStringLiteral(isSupported ? nil : response))"))
        #expect(bridges.contains("static let maxAttributeCount"))
        #expect(bridges.contains("App bridge event: \\(eventName)"))
        #expect(bridges.contains("static let maxRequestIDLength"))
        #expect(bridges.contains("static func isSupportedCommandName"))
        #expect(bridges.contains("var isSupported: Bool"))
        #expect(previewDocument.contains("const nextRequestId = () =>"))
        #expect(previewDocument.contains("window.crypto.randomUUID"))
        #expect(previewDocument.contains("window.crypto.getRandomValues(values)"))
        #expect(previewDocument.contains("requestId: nextRequestId()"))
        #expect(!previewDocument.contains("requestId: 'safeapi-' + (++requestCounter)"))
        #expect(previewDocument.contains("if (detail.ok === false)"))
        #expect(previewDocument.contains("entry.reject(bridgeError("))
        #expect(previewDocument.contains("pendingRequests.set(requestId, { resolve, reject, timer, command: prepared.payload.command });"))
        #expect(previewDocument.contains("if (!response.command || entry.command !== response.command)"))
        #expect(previewDocument.contains("HTML Workspace app bridge response command mismatch"))
        #expect(previewDocument.contains("const responseVersion = Number(detail.safeAPIVersion);"))
        #expect(previewDocument.contains("safeAPIVersion: Number.isFinite(responseVersion) ? responseVersion : null"))
        #expect(previewDocument.contains("if (response.safeAPIVersion !== \\(safeAPIVersion))"))
        #expect(previewDocument.contains("HTML Workspace app bridge response version mismatch"))
        #expect(previewDocument.contains("ok: detail.ok !== false"))
        #expect(previewDocument.contains("error: typeof detail.error === 'string' ? detail.error : null"))
        #expect(previewDocument.contains("entry.resolve(response);"))
        #expect(editor.contains(#"Button("Test Runtime Bridges""#))
        #expect(editor.contains("private func testRuntimeBridgeProbes()"))
        #expect(editor.contains(#"statusText = "Runtime bridge probes requested""#))
        #expect(editor.contains(#"Button("Test App Bridge""#))
        #expect(editor.contains(#"Button("Insert App Bridge Demo""#))
        #expect(editor.contains("HTMLWorkspaceAppBridgeDemoScaffold.apply"))
        #expect(editor.contains("appBridgeProbeNonce &+="))
        #expect(editor.contains(#"Button("Test Console Capture""#))
        #expect(editor.contains("consoleProbeNonce &+="))
        #expect(!preview.contains("nonisolated enum HTMLWorkspaceSafeAPI"))
        #expect(bridges.contains("nonisolated enum HTMLWorkspaceSafeAPI"))
    }

    @Test("sandbox runtime toggles bypass the source-edit preview debounce")
    func sandboxRuntimeTogglesBypassSourceEditPreviewDebounce() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let appBridgeStart = try #require(editor.range(of: "private func setAppBridgeEnabled"))
        let pythonStart = try #require(editor.range(of: "private func setPythonRuntimeEnabled"))
        let regenerateStart = try #require(editor.range(of: "private func openRegenerateSheet"))
        let appBridgeToggle = String(editor[appBridgeStart.lowerBound..<pythonStart.lowerBound])
        let pythonToggle = String(editor[pythonStart.lowerBound..<regenerateStart.lowerBound])

        for toggle in [appBridgeToggle, pythonToggle] {
            #expect(toggle.contains("previewUpdateTask?.cancel()"))
            #expect(toggle.contains("previewUpdateTask = nil"))
            #expect(toggle.contains("liveDOMSnapshot = nil"))
            #expect(toggle.contains("previewPackage = updated"))
            #expect(!toggle.contains("schedulePreviewUpdate(updated)"))
        }
    }
}
