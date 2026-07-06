// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA CONTRACT, NOT A REPLACEMENT. The LIVE Epistemos/Engine/EpdocEditorBridge.swift is a large,
// shipped file that ALREADY implements the custom scheme + brotli: the scheme is `epistemos-doc://`
// (epdocEditorURLScheme, :36) with decompressBrotli (:347) — the `epdoc://` name in this skeleton's
// body is WRONG; never create a second scheme. What this skeleton ADDS to the live file: the epoch-
// stamped loadDocument/inbound-outbound message layer + the SuggestionPayload seam. NOTE the seam
// has TWO producers: June/MAS = agent_core via UniFFI (copy AgentEventDelegate, bridge.rs:83 +
// StreamingDelegate.swift); 1Code = the embedded Node backend via the Experimental bridges. One
// inbound schema, two producers.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  EpdocEditorBridge.swift
//  EPI-RP-02-LUMENLENS
//
//  The Swift <-> JS bridge for the Epdoc (Tiptap-in-WKWebView) lens. Owns:
//   - the epdoc:// custom URL scheme handler (brotli-decompressed package assets,
//     server-side; a custom scheme does NOT auto-decompress Content-Encoding: br)
//   - epoch-stamped inbound/outbound messages (Fork D)
//   - the seam where agent_core (Rust/UniFFI) hands suggestions in.
//
//  Platform hygiene: UniFFI callbacks MUST hop DispatchQueue.main.async (never .sync) —
//  a .sync hop from the Rust callback thread risks deadlock.

import WebKit

/// Mirror of the JS SuggestionPayload, marshalled across UniFFI from agent_core.
struct SuggestionPayloadFFI {
    let id: String
    let author: String
    let turnId: String
    let from: Int
    let to: Int
    let before: String
    let after: String
    let rationale: String?
    let sourceCitation: String?
}

final class EpdocEditorBridge: NSObject {

    /// Monotonic load nonce. Bumped on every programmatic load (Fork D).
    private(set) var currentEpoch: Int = 0

    private weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
    }

    // MARK: Load (host -> webview)

    func loadDocument(markdown: String, frontmatter: String) {
        currentEpoch &+= 1
        post(kind: "loadDocument", payload: [
            "epoch": currentEpoch,
            "markdown": markdown,
            "frontmatter": frontmatter,
        ])
    }

    func switchLens(_ lens: String) {
        post(kind: "switchLens", payload: ["epoch": currentEpoch, "lens": lens])
    }

    // MARK: Agent suggestions (agent_core/UniFFI -> webview)

    /// Called from a UniFFI foreign-trait callback on a Rust thread. Hop to main ASYNC.
    func onAgentSuggestion(_ p: SuggestionPayloadFFI) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.post(kind: "applySuggestion", payload: [
                "epoch": self.currentEpoch,
                "suggestion": [
                    "id": p.id, "author": p.author, "turnId": p.turnId,
                    "from": p.from, "to": p.to, "before": p.before, "after": p.after,
                    "rationale": p.rationale as Any, "sourceCitation": p.sourceCitation as Any,
                ],
            ])
        }
    }

    // MARK: Plumbing

    private func post(kind: String, payload: [String: Any]) {
        var msg = payload
        msg["kind"] = kind
        // TODO: JSONSerialization -> evaluateJavaScript("window.__epdocInbound(<json>)").
        _ = msg
    }
}

// MARK: - epdoc:// scheme handler (brotli, server-side)

extension EpdocEditorBridge: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        // TODO: resolve the requested package asset, brotli-DECODE it here (server-side),
        //       set the MIME type explicitly, and hand raw bytes to the task. Do NOT assume
        //       HTTPS behavior — no auto content-encoding, different CORS/caching rules.
        //       MAS: do NOT use the private _registerURLSchemeAsSecure (App Store rejection).
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // TODO: cancel in-flight asset work.
    }
}
