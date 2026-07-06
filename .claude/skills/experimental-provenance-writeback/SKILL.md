---
name: experimental-provenance-writeback
description: >
  Add an Epistemos knowledge-substrate capability to the embedded 1Code (Experimental)
  agent surface by round-tripping between the web renderer and a native reply-capable
  script-message handler that reads/writes the user's vault. Use when building any
  "embedded-agent" feature that must reach Epistemos state (vault notes, graph,
  provenance, RRF search) FROM the 1Code web UI without native SwiftUI chrome and
  without editing onecode-shim.js. Class: web-UI → native `epistemos` reply channel →
  Epistemos service (vault/graph/provenance).
---

# Experimental: renderer → native → Epistemos-substrate round-trip

## When to use
Any Cycle feature where the embedded 1Code web UI must invoke an **Epistemos-only**
capability the frontier agent apps structurally cannot have (field study:
`docs/research/AGENT_APP_FIELD_STUDY.md`) — vault write-back, graph recall, RRF-ranked
retrieval, provenance logging, "open cited note in Epistemos". This is the reusable
CLASS behind the "Save to vault" provenance-write-back build (Cycle 1).

## The pattern (three hops, no SwiftUI, no shim edit)

1. **Web trigger (renderer overlay, NEW file where possible).** Add a React control to
   the donor UI (e.g. a button on `message-action-buttons.tsx`, an item in the selection
   popover). Post DIRECTLY to the reply-capable native handler — do NOT edit
   `onecode-shim.js` (that's the trap; the handler is already registered
   `WKScriptMessageHandlerWithReply`):
   ```ts
   const handler = (window as any).webkit?.messageHandlers?.epistemos
   if (!handler) return               // honest gate: only inside the WKWebView host
   const res = await handler.postMessage({ kind: "vault:create-note", payload: { title, body } })
   if (res?.success) toast.success(...) else toast.error(res?.error ?? "…")
   ```
   Honest-gate every capability on the channel's existence so the donor build still works.

2. **Native handler (Swift, the Coordinator's `reply(to:payload:)` switch in
   `ExperimentalSurfaceView.swift`).** Add a `case "your:verb":` returning `(Any?, String?)`.
   Read `AppBootstrap.shared?.vaultSync.vaultURL` (or the graph/provenance service),
   validate + length-cap the payload, do the work, return `["success": true, ...]`.
   File writes go to `<vault>/notes/*.md` (the `ShadowVaultBootstrapper` crawl path →
   auto-reindexed). Async work (NSSavePanel etc.) goes in the `async didReceive` entry
   instead of the sync `reply`.

3. **Epistemos service.** Reuse the substrate: the `epistemos-vault` MCP (`omega_mcp_stdio`)
   for agent-driven vault ops; `AppBootstrap.vaultSync` for user-driven writes;
   `RRFFusionQuery`/`epistemos-shadow` for ranked search; the `agent_core` ClaimLedger for
   provenance. Do NOT duplicate these — connect to them.

## Verification (DoD — running app, not a compile)
- Build the fork (`build-experimental-web.sh` re-bundles the renderer overlay).
- **Never two `xcodebuild`s at once** (DB-lock collision corrupts intermediates + the
  Rust dylib; if it happens, rebuild `build-agent-core.sh` then the app).
- Prove in the running app with a screenshot/file-artifact: the web control renders, the
  native side did the work (a real file in the vault / a real graph edit).
- **Known verification hazard (Cycle 1):** a machine-wide macOS **Keychain prompt storm**
  (`app.epistemos` reads without an always-allow ACL) can pop a modal that silently
  intercepts synthetic clicks. Set the ACL / batch the reads, or click Always-Allow once,
  before driving the UI. This is also a Phase-E hardening target.

## Ledger + rails
Every in-place fork edit → a `PATCH_LEDGER.md` row. Overlay in NEW renderer/backend files.
Keys stay in Keychain, never in webview JS. Never `git add -A`; `.research-clones/` is
gitignored. Compose this skill in later cycles for graph-recall and RRF-retrieval builds.
