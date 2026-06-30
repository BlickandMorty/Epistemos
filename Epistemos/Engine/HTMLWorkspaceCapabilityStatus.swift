import Foundation

// SS-HW (owner 2026-06-20): "the html workspace does not work as well but idk if its marked as such."
// The HTML Workspace renders, edits, and accepts agent chat patches — but several seams are dead or
// static/gated (the app message-bridge path is still no-op, DOM "inspection" is a static regex of
// source rather than the live runtime DOM, the JS console bridge is wired but env-gated, there is no
// Python, and full-surface regenerate is only a source-quad patch primitive so far — no general
// streaming/provenance/multi-route scaffold yet). The codebase has a GateStatus honesty convention,
// but the HTML workspace shipped silently as if complete.
//
// This is that honest marker: a pure, verified capability ledger the Settings diagnostics row surfaces,
// so the workspace's real state is scannable instead of reading as "done." Every entry below was
// confirmed in code (safeAPI messages still no-op + safeAPIEnabled=false; console capture is wired
// behind EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0; no Pyodide/CPython refs; HTMLWorkspacePatchRouter
// present for the live agent edit path).
enum HTMLWorkspaceCapabilityStatus {

    struct Capability: Sendable, Equatable {
        let name: String
        /// True = works today. False = a static/stub/deferred seam (honest, not a silent gap).
        let isLive: Bool
        let note: String
    }

    static let capabilities: [Capability] = [
        Capability(name: "Multi-file HTML/CSS/JS editing", isLive: true, note: "Real NSDocument package"),
        Capability(name: "WKWebView live preview", isLive: true, note: "Debounced re-render on edit"),
        Capability(name: "Agent chat patch pipeline", isLive: true, note: "HTMLWorkspacePatchRouter applies edits"),
        Capability(name: "Vault data.json feed", isLive: true, note: "Opt-in manifest data_feed renders VaultSyncService.searchFullAsync results and patches data-only preview updates without reload"),
        Capability(name: "Export / import / PDF / snapshot", isLive: true, note: "Wired"),
        Capability(name: "App message-bridge", isLive: false, note: "didReceive handler is an empty stub; safeAPIEnabled defaults off"),
        Capability(name: "JS console / error capture", isLive: false, note: "Bridge now wired (window error + unhandledrejection + console.error/warn → the consoleErrors pipeline + panel) behind EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0; default off"),
        Capability(name: "Live-DOM inspection", isLive: false, note: "Static regex of source, not the runtime DOM"),
        Capability(name: "Python (Pyodide / WASM)", isLive: false, note: "Not built — research"),
        Capability(name: "Full-surface regenerate", isLive: false, note: "Core replaceDocument/regenerate source-quad patch op is wired; general streaming, provenance, and multi-route scaffold are still deferred"),
    ]

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — the workspace works as a renderer/editor but is not
    /// the full web-app builder yet, and says so.
    static var summary: String {
        "\(liveCount) live, \(deferredCount) gated/static/deferred — renders, edits, agent-patches, and can opt into Vault-backed data.json refresh; JS console capture is wired but env-gated, while the app-bridge, live-DOM inspection, Python, and full-surface regenerate UX remain deferred (partial artifact runtime, not a full web-app builder yet)."
    }
}
