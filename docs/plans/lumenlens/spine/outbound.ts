// outbound.ts — webview -> host (Swift) messages. EPI-RP-02-LUMENLENS.
// Epoch-stamped so the host can correlate a reply with the load it belongs to and
// ignore anything stamped with a superseded epoch.

import type { LoadEpoch } from "./document-load-state";

export type OutboundMessage =
  | { kind: "docDirty"; epoch: LoadEpoch }
  // Fork B: writeback carries ONLY the changed block range, never the whole doc.
  | { kind: "writeback"; epoch: LoadEpoch; changedFrom: number; changedTo: number; blockMarkdown: string }
  | { kind: "suggestionResolved"; epoch: LoadEpoch; suggestionId: string; state: "accepted" | "rejected" }
  | { kind: "editPosition"; epoch: LoadEpoch; pos: number; caret: { x: number; y: number; h: number } }
  | { kind: "loadSettled"; epoch: LoadEpoch };

/** Post to the host. The message handler name ("epdoc") must match EpdocEditorBridge. */
export function postOutbound(msg: OutboundMessage): void {
  const bridge = (window as unknown as {
    webkit?: { messageHandlers?: { epdoc?: { postMessage: (s: string) => void } } };
  }).webkit?.messageHandlers?.epdoc;
  if (!bridge) {
    // TODO: dev fallback (console) when running outside WKWebView.
    return;
  }
  bridge.postMessage(JSON.stringify(msg));
}
