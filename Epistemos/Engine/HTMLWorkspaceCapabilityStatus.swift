import Foundation

// SS-HW (owner 2026-06-20): "the html workspace does not work as well but idk if its marked as such."
// The HTML Workspace renders, edits, and accepts agent chat patches. Goose full-surface regenerate,
// the gated app message bridge, JS console/error capture, DOM picker/style inspection, and the
// vendored Pyodide runtime were proven in-app on 2026-06-30 with visible source+preview/
// console/inspector updates. The codebase has
// a GateStatus honesty convention, but the
// HTML workspace shipped silently as if complete.
//
// This is that honest marker: a pure, verified capability ledger the Settings diagnostics row surfaces,
// so the workspace's real state is scannable instead of reading as "done." Every entry below was
// confirmed in code and in the running app (HTMLWorkspacePatchRouter is present for the live agent
// edit path; HTMLWorkspaceGooseRegenerator is Goose-only and the live app replaced source+preview
// through regenerate; the app bridge is sandbox-gated and records bounded commands into the console
// panel; the console bridge records runtime console.error/window error diagnostics from a clean
// package; the DOM inspector receives click-picked selector/style payloads from WKWebView; Pyodide
// is build-vendored and opt-in, and ran Python in WKWebView).
enum HTMLWorkspaceCapabilityStatus {

    struct Capability: Sendable, Equatable {
        let name: String
        /// True = works today. False = a static/stub/deferred seam (honest, not a silent gap).
        let isLive: Bool
        let note: String
    }

    static let capabilities: [Capability] = [
        Capability(name: "Multi-file HTML/CSS/JS editing", isLive: true, note: "Real NSDocument package"),
        Capability(name: "WKWebView live preview", isLive: true, note: "Debounced re-render on edit with package-local asset/data/route serving"),
        Capability(name: "Agent chat patch pipeline", isLive: true, note: "HTMLWorkspacePatchRouter applies edits"),
        Capability(name: "Package-local HTML routes", isLive: true, note: "routes/<name> files round-trip in the package, serve through the local scheme, and can be set/removed by structured patches"),
        Capability(name: "Vault data.json feed", isLive: true, note: "Opt-in manifest data_feed renders VaultSyncService.searchFullAsync results and patches data-only preview updates without reload"),
        Capability(name: "Export / import / PDF / snapshot", isLive: true, note: "Wired; HTML and PDF exports inline package asset references before writing rendered artifacts"),
        Capability(name: "Live-DOM outline", isLive: true, note: "Preview WebView reports a runtime DOM snapshot; source regex is only the fallback when preview is not mounted"),
        Capability(name: "Full-surface regenerate", isLive: true, note: "Goose-only streaming sheet applied a real replaceDocument/regenerate update in-app with source+preview replacement and provenance-backed patch routing"),
        Capability(name: "App message-bridge", isLive: true, note: "Sandbox-gated safe API receives bounded ping/status/event.record messages from WKWebView and records them into the console panel"),
        Capability(name: "JS console / error capture", isLive: true, note: "Proven in-app from a clean package: console.error and thrown window Error were captured into the visible console panel and persisted console-errors.json"),
        Capability(name: "DOM picker / style inspector", isLive: true, note: "Proven in-app: clicking button#dom-proof-target in WKWebView populated the inspector with selector, text preview, and computed styles"),
        Capability(name: "Python (Pyodide / WASM)", isLive: true, note: "Build-vendored, sandbox-gated Pyodide runtime proved in-app by running Python in WKWebView and rendering Pyodide result: 45"),
    ]

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — the workspace works as a renderer/editor but is not
    /// the full web-app builder yet, and says so.
    static var summary: String {
        "\(liveCount) live, \(deferredCount) gated/static/deferred — renders, edits, agent-patches/regenerates through Goose, serves package-local assets/data/routes in preview, inlines package assets for HTML/PDF export, shows a live DOM outline, can opt into Vault-backed data.json refresh, has a sandbox-gated app message bridge, captures JS console/window errors, supports click-to-inspect DOM picker/style inspection, and runs build-vendored Pyodide/Python when explicitly enabled."
    }
}
