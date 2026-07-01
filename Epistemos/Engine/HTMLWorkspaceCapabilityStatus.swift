import Foundation

// SS-HW (owner 2026-06-20): "the html workspace does not work as well but idk if its marked as such."
// The HTML Workspace renders, edits, serves package-local resources, and accepts agent chat patches.
// The app bridge, JS console capture, DOM picker/style inspection, full-surface regenerate UX, and
// vendored Pyodide path have code-level wiring, but they must stay marked non-live until a current
// build can prove them in-app. The app target is presently blocked before launch by an unrelated
// out-of-lane build error, so this ledger must not claim live UI proof for those caps.
//
// This is that honest marker: a pure, verified capability ledger the Settings diagnostics row surfaces,
// so the workspace's real state is scannable instead of overclaiming. Flip a deferred entry to live
// only with current in-app evidence.
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
        Capability(name: "Export / import / PDF / snapshot", isLive: true, note: "Wired; HTML/PDF exports inline package assets, and site-folder export writes index, routes, shared assets, and route-relative asset mirrors"),
        Capability(name: "Live-DOM outline", isLive: true, note: "Preview WebView reports a runtime DOM snapshot; source regex is only the fallback when preview is not mounted"),
        Capability(name: "Full-surface regenerate", isLive: false, note: "replaceDocument/regenerate patch plumbing exists, with one-click stream-to-preview/apply, visible revert, pixel-captioned presets, advanced manual fallback kept recovery-only, workspace-context grounding, source-labelled bounded context payloads, explicit context metadata preservation, required-source availability metadata that survives data-feed refresh, structured prompt context records, stable drag context IDs, selected-preview prompt targeting, source-kind compact feed status, preview-side context rail, in-preview context picker, selected-preview drop targets, generated dashboard section nav, generated data-backed context picker, generated pinned-context tray, generated data-backed sorting, scoped context-tab visible counts, and clickable tabbed vault result detail panes; awaits current in-app proof"),
        Capability(name: "App message-bridge", isLive: false, note: "Sandbox-gated safe API parses bounded ping/status/event.record messages with structured event attributes, records diagnostics, dispatches a response event, exposes a promise request helper, and has manual probe + insertable demo scaffold paths; awaits current in-app proof"),
        Capability(name: "JS console / error capture", isLive: false, note: "Console log/info/warn/error + window-error/unhandled-rejection capture script, typed severity/source pipeline, clearable panel, and manual probe path are wired; awaits current in-app proof"),
        Capability(name: "DOM picker / style inspector", isLive: false, note: "Click-pick inspector bridge, hover-highlighted picker, escaped selector copy, nth-of-type focused selectors, style payload parser, focused style edits, and open-panel probe path are wired; awaits current in-app proof"),
        Capability(name: "Python (Pyodide / WASM)", isLive: false, note: "Build-vendored Pyodide assets, sandbox-gated runtime path, bounded run input, local/blob worker CSP, insertable demo scaffold, and runtime probe are wired; awaits current in-app proof"),
    ]

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — the workspace works as a renderer/editor but is not
    /// the full web-app builder yet, and says so.
    static var summary: String {
        "\(liveCount) live, \(deferredCount) awaiting current in-app proof — renders, edits, agent-patches, serves package-local assets/data/routes in preview, exports HTML/PDF with inlined package assets, exports site folders with routes and route-relative asset mirrors, shows a live DOM outline, and can opt into Vault-backed data.json refresh. Full regenerate stream-to-preview/apply/revert UX with pixel-captioned presets, advanced manual fallback kept recovery-only, workspace-context grounding, source-labelled bounded context payloads, explicit context metadata preservation, required-source availability metadata that survives data-feed refresh, structured prompt context records, stable drag context IDs, selected-preview prompt targeting, source-kind compact feed status, preview-side context rail, in-preview context picker, selected-preview drop targets, generated dashboard section nav, generated data-backed context picker, generated pinned-context tray, generated data-backed sorting, scoped context-tab visible counts, and clickable tabbed vault result detail panes, app bridge demo/runtime with promise requests and structured event attributes, JS console/window-error/rejection capture, hover-highlighted DOM picker/style inspection with focused selectors and style edits, and build-vendored Pyodide demo/runtime with bounded run input plus local/blob worker CSP remain gated until a launchable build proves them."
    }
}
