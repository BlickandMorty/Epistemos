import Foundation

@main
struct HTMLWorkspaceRuntimeSmoke {
    static func main() {
        let capabilities = Dictionary(
            uniqueKeysWithValues: HTMLWorkspaceCapabilityStatus.capabilities.map { ($0.name, $0.isLive) }
        )

        require(HTMLWorkspaceConsoleCapturePolicy.isEnabled(environment: [:]), "console capture should default on")
        require(
            !HTMLWorkspaceConsoleCapturePolicy.isEnabled(
                environment: [HTMLWorkspaceConsoleCapturePolicy.environmentFlag: "0"]
            ),
            "console capture env opt-out should work"
        )
        require(capabilities["JS console / error capture"] == true, "console capture gate should be live")
        require(capabilities["DOM picker / style inspector"] == true, "DOM picker gate should be live")
        require(capabilities["Full-surface regenerate"] == true, "regenerate gate should be live")
        require(capabilities["App message-bridge"] == true, "app bridge gate should be live")
        require(capabilities["Python (Pyodide / WASM)"] == true, "Python runtime gate should be live")

        let longText = String(repeating: "x", count: 400)
        let body: [String: Any] = [
            "selector": "button#save.primary",
            "tagName": "button",
            "id": "save",
            "classes": ["primary", "toolbar"],
            "text": longText,
            "styles": [
                "display": "inline-flex",
                "font-size": "13px",
                "background-color": "rgb(20, 20, 20)",
            ],
        ]
        guard let inspection = HTMLWorkspaceElementInspection.fromMessageBody(body) else {
            require(false, "inspection payload should parse")
            return
        }
        require(inspection.selector == "button#save.primary", "selector should round-trip")
        require(inspection.tagName == "button", "tag should round-trip")
        require(inspection.elementID == "save", "id should round-trip")
        require(inspection.classes == ["primary", "toolbar"], "classes should round-trip")
        require(inspection.textPreview.count == 240, "text preview should be bounded")
        require(inspection.styles["font-size"] == "13px", "styles should round-trip")

        let inspectorScript = HTMLWorkspaceInspectorBridge.installScript
        require(
            inspectorScript.contains(HTMLWorkspaceInspectorBridge.messageHandlerName),
            "inspector script should post through the app message handler"
        )
        require(inspectorScript.contains("getComputedStyle"), "inspector script should read computed styles")
        require(inspectorScript.contains("border-radius"), "inspector script should include expected style keys")
        require(HTMLWorkspaceInspectorBridge.disableScript.contains("__epistemosInspectorEnabled = false"), "disable script missing")
        require(HTMLWorkspaceCapabilityStatus.summary.contains("click-to-inspect"), "summary should disclose inspector live")
        require(HTMLWorkspaceCapabilityStatus.summary.contains("Pyodide"), "summary should disclose Python live")

        print(
            "html workspace smoke OK: console_default_on=true dom_picker_live=true regenerate_live=true bridge_live=true python_live=true"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("html workspace smoke failed: \(message)\n".utf8))
            Foundation.exit(1)
        }
    }
}
