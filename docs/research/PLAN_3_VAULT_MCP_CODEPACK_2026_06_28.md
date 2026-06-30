# Plan 3 — Vault-as-MCP-server (shipped code, Pass 4)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §5c`. Expose the vault/KC/Eidos as a READ-ONLY local MCP endpoint so
> external AI tools (Claude Desktop/Cursor) can query the user's notes. The Plan 3 Swift endpoint, lifecycle, Keychain
> token store, and Settings row are shipped; optional Rust byte-parity hardening remains separate.
> `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified seams (reuse, don't fork)
- **Transport:** `WorkNativeMCPServer.swift` — loopback-only NWListener (`requiredInterfaceType=.loopback :94`), bearer
  auth (`isAuthorized :224` + constant-time `:241`), Origin/DNS-rebind defense (`isAllowedOrigin :230`), 202 notification
  handling (`:186`), and it ALREADY takes a `token:` init param (`:71`) → inject a persistent token without touching
  transport. Pure static helpers reusable verbatim: `routeOutcome :205`, `httpResponse :253`, `acceptedResponse :268`,
  `isNotification :279`, `randomToken :297`; `WorkMCPHTTPRequest.parse`.
- **Core pattern:** `WorkToolMCPCore.handle(requestJSON:) async -> String` (`:15`) — JSON-RPC switch + shaping helpers.
- **Host pattern:** `WorkNativeMCPHost` (`:14`, `@MainActor`, `ensureServer`, executor from
  `ToolTierBridge(vaultPath:tier:).toolExecutor() :69`).
- **Read/write split (source of truth):** `omega-mcp/src/vault.rs:825 is_vault_tool` — READ verbs =
  `vault.read/search/list` + wikilink graph reads (`backlinks/outlinks/dangling_links/note_links/link_candidates/orphan_notes`);
  WRITE verbs = `vault.write/write_file`, `vault.patch_note`. **Read-only = exclude the write verbs.**
- **Resources:** `dispatcher.rs:292 handle_resources_list` + `:320 handle_resources_read` emit `vault:///<rel>`
  (path-safe via `VaultExecutor`). Keychain: `Keychain.save(_:for:)/.load(for:)` (`:85,104`).

## 1. `VaultMCPCore.swift` [DELIVERED]
Mirrors `WorkToolMCPCore` but: `tools/list` advertises ONLY `readToolNames` (`vault.search/read/list`, `eidos.query`,
the 6 graph reads); `tools/call` **canonicalizes aliases through `AgentToolNameAliases.canonical` then rejects anything not on the allowlist with
`-32601 "read-only vault server"`** (enforced at the core — even a full-tier executor can't be coerced into a write);
`resources/list` enumerates path-contained `.md` notes as `vault:///<rel>` in a detached utility worker, and
`resources/read` reads only path-contained Markdown through the same detached resource path; final reads reopen the
resolved note with `O_NOFOLLOW`, verify a regular file with `fstat`, enforce the byte cap on the descriptor, and reject
invalid UTF-8. Tool calls still go through the read-only executor allowlist. Empty vault → honest-empty (`resources:[]`,
real empty search/list payloads). Direct core dispatch rejects JSON-RPC request strings over the 8 MiB cap before JSON
parsing, requires a JSON-RPC 2.0 object envelope before dispatch, and caps echoed string request IDs, matching the
loopback HTTP body limit. Pure
helpers (`successResponse`/`errorResponse`/`toolCallResult`/`argumentsJSON`/`markdownRelPaths`/`noteText`) testable with
a stub executor, no network/FFI in the file.

## 2. `VaultMCPServer.swift` [DELIVERED]
Loopback `/mcp` NWListener binding `VaultMCPCore`, delegating auth/framing/routing to `WorkNativeMCPServer`'s static
helpers (one audited copy of the security logic). Difference from `WorkNativeMCPServer`: a **persistent** bearer token
(not per-launch). Lifecycle = same `start()`/`stop()` + `.ready`→`WorkNativeMCPRegistration{url,token}` shape;
`WorkNativeMCPRegistration.isTrustedLoopbackMCP (:33)` validates it for free.

## 3. `VaultMCPTokenStore.swift` [DELIVERED]
`currentToken()` returns the stored token or mints+persists one (`WorkNativeMCPServer.randomToken()` CSPRNG, 24-byte
base64) via `Keychain.save(_, for: "vault_mcp_bearer")` — **never UserDefaults** (CLAUDE.md). Stored/generated bearer
values must be printable ASCII and at least 24 characters; weak or control-character values are discarded and replaced
with a fresh fallback token. `rotateToken()` re-mints (invalidates old client configs). `masked(_)` → `abcd…wxyz` for
display.

## 4. `VaultMCPHost.swift` [DELIVERED]
`@MainActor`, idempotent-per-vault `ensureServer`, async `start(vaultRoot:)` polling `.ready`, `stop()`,
`rotateTokenAndRestart(vaultRoot:)`, and active-vault-scoped registration lookup so a Settings refresh cannot present
an old server for a different connected vault. **OFF BY DEFAULT** — nothing calls `start()` at bootstrap; only the
Settings toggle does. Executor uses
`ToolTierBridge(vaultPath:, tier:.readOnly, allowedToolNames: Set(VaultMCPCore.readToolNames))`;
`ChatToolTier.readOnly` maps to the Rust full tier only with an explicit allowlist, and the core's allowlist still
enforces read-only.

## 5. `VaultMCPServerSettingsRow.swift` [DELIVERED]
Toggle start/stop; shows `http://127.0.0.1:<port>/mcp` + masked token + **Rotate** + **"Copy MCP client config"** →
`{"type":"http","url":…,"headers":{"Authorization":"Bearer …"}}` (the shape Claude Desktop/Cursor expect, same as the
in-repo OpenCode config writer). Surfaces "Running (vault empty)" honestly.

## MAS/Pro + honesty
- Read-only enforced at the CORE (allowlist; write/exec verbs never surfaced) — defense-in-depth, not client trust.
- **Pro-gated + off-by-default** (a loopback HTTP server is App-Review-sensitive) behind the existing `PolicyProfile`/
  `#if PRO_BUILD` seam; MAS build compiles the types but hides the row.
- Empty-vault honesty (no fabricated notes); path-traversal safety inherited from `VaultExecutor`; persistent token in
  Keychain + constant-time compare + loopback bind + Origin allowlist all inherited from the audited transport.

## Remaining optional hardening (flagged, not guessed)
1. Optional Pro increment: bind the Rust `MCPDispatcher.dispatch()` (`dispatcher.rs:235`, already serves resources) over
   a UniFFI seam for byte-parity with the stdio server (no Swift re-enumeration).
