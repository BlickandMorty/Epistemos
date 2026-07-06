// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// DEFECTS: (1) `.dataset(DatasetRef)` is IMPOSSIBLE — NoteWorkspaceMode is a String raw-value enum
// (guard-pinned, NoteEditorLayoutTests:238); use a PLAIN `.dataset` case + derive DatasetRef from
// page.filePath. (2) "one enum case, nothing else" is FALSE — the real touch set (~6, all
// mechanical, enumerated in the review): enum label/help/symbol switches; noteModeOptions (csv/xlsx
// → [.dataset]); NotesSidebar.preferredInitialMode (csv/xlsx → .dataset); openInEditor routing lane;
// two exhaustive switches (activeOutlineExternalItems, currentEditorBody); the noteEditorSurface
// mount. resolvedNoteMode needs NOTHING (falls back). (3) Missing the repo's OWN hardening:
// dismantleNSView + shutdown removing the script handler (the exact 40-60MB leak Epdoc fixed,
// EpdocEditorChromeView:799/:972), .nonPersistent() websiteDataStore + shared pool, bridge in
// makeCoordinator not @State. Follow the Epdoc chrome donor exactly.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Mounts the grid WKWebView when the lens host enters the dataset mode.
// (Dependencies / hand-off seam: NoteDetailWorkspaceView / NoteWorkspaceMode are
// owned by EPI-RP-02-LUMENLENS. RECKONER adds ONE enum case — .dataset(DatasetRef)
// — and registers this host for it. The lens state machine is not modified;
// grid-first, no standalone Data room, no new chat.)

import SwiftUI
import WebKit

struct DatasetTabHost: NSViewRepresentable {
    let ref: DatasetRef
    @State private var bridge = GridBridge()

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        // TODO: reuse the existing custom-scheme brotli handler for the
        // reckoner-grid bundle; root HTML MUST load via the custom scheme so
        // in-page fetch of chunks + wasm routes through the handler;
        // application/wasm MIME for instantiateStreaming (OQ-5).
        cfg.userContentController.add(bridge, name: "reckoner")
        let web = WKWebView(frame: .zero, configuration: cfg)
        bridge.webView = web
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        // TODO: on ref change → DatasetStore snapshot (icalc bytes) → bridge.loadDataset
        // Virtualized hydration: visible rows + buffer from GRDB, never all 100k at once.
    }
}
