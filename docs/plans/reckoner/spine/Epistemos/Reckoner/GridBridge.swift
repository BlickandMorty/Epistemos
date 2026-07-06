// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// Solid core (epoch owner, stale-drop, main.async). Add: handler teardown path (paired with
// DatasetTabHost dismantleNSView), guard on `&+=` wrap, and JS-side inbound epoch validation as the
// other half (see grid-bridge.ts header). Zero-events-on-load bar unchanged.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// Native side of the grid bridge. The host owns the monotonic epoch; stale
// outbound is dropped HERE before touching session state. Dataset loads run
// inside the epoch so loading emits zero change/autosave (hard constraint #4).
// UniFFI/agent_core callbacks hop DispatchQueue.main.async — never .sync.
// (Dependencies / hand-off seam: epoch/suppression pattern owned by
// EPI-RP-02-LUMENLENS; extended here, not redefined.)

import Foundation
import WebKit
import Observation

@Observable
final class GridBridge: NSObject, WKScriptMessageHandler {
    private(set) var currentEpoch: GridEpoch = 0
    private(set) var loadState: GridLoadState = .idle
    weak var webView: WKWebView?

    enum GridLoadState: Equatable {
        case idle, loading(GridEpoch), ready, calcError(String), bridgeLost
    }

    func loadDataset(_ ref: DatasetRef, snapshotB64: String?) {
        currentEpoch &+= 1
        loadState = .loading(currentEpoch)
        send(.loadDataset(epoch: currentEpoch, datasetId: ref.id.uuidString, snapshotB64: snapshotB64))
    }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        // TODO: decode envelope; DROP if epoch != currentEpoch (stale);
        // route: rawEdit → DatasetStore persist + TabularLedger append;
        //        loadApplied → loadState = .ready;
        //        calcCompleted → F6 datasetChanged/calcCompleted events;
        //        suggestionResolved → ledger accept_state;
        //        embedInvalidated → F6 event → embeds show relink state.
    }

    /// agent_core streamed suggestion (off-main) — main hop, then stage in the grid.
    func onAgentSuggestion(_ dto: TabularSuggestionDTO) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.send(.stageSuggestion(epoch: self.currentEpoch, suggestion: dto))
        }
    }

    private func send(_ msg: GridInbound) { /* TODO: JSON → evaluateJavaScript */ }
}
