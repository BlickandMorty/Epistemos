// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// BACKEND REUSE IS MANDATORY: the minichat WKWebView loads the SAME supervisor backend
// (ExperimentalRuntimeSupervisor.shared uiBaseURL) — ONE Node child, ledgered + reaped
// (AgentSurfaceChildLedger; reap verified in applicationWillTerminate). NEVER spawn a second
// backend. Sessions live server-side, so a second SPA instance against the same origin shares
// them; continuity = same sub_chats.sessionId (CONFIRMED column, schema :75) + streamId exists
// for stream resume (:76; IPCChatTransport.reconnectToStream). Caveats: (1) per-webview
// ExperimentalStateBridge routing needed (single weak ref today); (2) each webview injects its
// own shim WKUserScript (already webview-local). Streaming contract (VERIFIED): tRPC subscription
// `claude.chat` wrapped by AI-SDK IPCChatTransport — NOT `claude.onMessage` (name refuted).
// abortAllClaudeSessions confirmed at claude.ts:304.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  MinichatDock.swift
//  EPI-RP-05-KINDRED · D3 continuity + the 1code-fork extraction seam (BINDING)
//
//  The Epdoc sidebar minichat: a docked mini-variant of the 1Code agent surface, embedded
//  in a WKWebView. It shares `sessionId` with the 1Code MAIN agent so it is the SAME
//  companion — continuity, not a second fragmenting chat.
//
//  Extraction from the fork (.research-clones/1code, 21st-dev/1code, Apache-2.0):
//    KEEP  src/renderer/features/agents/{main,lib,stores,atoms,ui}
//          - active-chat.tsx, messages-list.tsx, chat-input-area.tsx
//          - lib/ipc-chat-transport.ts (AI-SDK ChatTransport over IPC)
//          - stores/sub-chat-store.ts (sub_chats.sessionId continuity)
//    STRIP features/sidebar, features/terminal (xterm/node-pty), features/file-viewer,
//          the git client, Monaco.
//    Keep the fork rebaseable: model the extraction as an OpenSpec change proposal
//    (openspec/changes/<verb-led-id>/) so it survives upstream rebases.
//
//  1Code-ONLY: on MAS this whole file compiles to an EmptyView (no companion surface).

#if KINDRED_ENABLED
import SwiftUI
import WebKit

struct MinichatDock: NSViewRepresentable {
    let companionId: String
    let sessionId: String        // SHARED with the 1Code main agent -> same companion

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // TODO: register the epdoc:// (or a dedicated minichat) scheme handler.
        // TODO: bridge the extracted tRPC/AI-SDK transport onto the Swift<->JS channel.
        // TODO: boot the headless Node backend (1Code/Experimental allows subprocess).
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // TODO: push presence + the current LoadEpoch so the dock stays in lock-step
        //       with the document it edits.
    }
}
#else
/// MAS: no companion surface. The dock does not exist.
struct MinichatDock: View {
    let companionId: String
    let sessionId: String
    var body: some View { EmptyView() }
}
#endif
