---
name: june-agent-core-cloud-loop
description: Use when connecting, auditing, hardening, or extending the MAS June cloud agent loop through in-process agent_core, June event frames, approval gating, selected-vault routing, honest local/cloud capability boundaries, and MAS App Store bundle/runtime cleanup checks.
---

# June Agent-Core Cloud Loop

## Description

Use this skill when connecting, auditing, hardening, or extending the MAS June cloud agent loop. It applies when June turns must route through in-process `agent_core`, stream agent events into the vendored June UI, preserve honest local/cloud capability boundaries, and use the selected vault without violating MAS sandbox rules.

Do not use this skill for `Epistemos/ExperimentalAgent/**`, Pro-only sidecars, Tauri, stdio MCP, shell/terminal tools, or any 1Code/Experimental fork work.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`
4. `docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
5. `Epistemos/JuneAgent/JuneAgentBridge.swift`
6. `Epistemos/JuneAgent/JuneAgentGateway.swift`
7. `Epistemos/JuneAgent/JuneAgentCoreVaultScope.swift` when vault pathing or root redaction is touched.
8. `Epistemos/JuneAgent/JuneToolEventBounds.swift` when tool/approval event payloads or ids are touched.
9. `Epistemos/Goose/GooseInProcessACPServer.swift`
10. `Epistemos/Sync/VaultSyncService.swift` when vault pathing or security scope is touched.

## Method

1. Prove the surface boundary first.
   - Confirm all touched code is under `#if EPISTEMOS_APP_STORE`.
   - Confirm no edits touch `Epistemos/ExperimentalAgent/**`, `src-tauri/`, Retro, or unrelated lanes.
   - Confirm June uses `WKScriptMessageHandler` and the custom `june://` scheme, not a sidecar or local server.
   - Validate JSON-RPC ids at gateway ingress before echoing replies: only bounded strings, finite safe numbers, or null; never arrays, objects, booleans, or oversized ids.

2. Preserve capability truth before adding power.
   - Default June to the cloud-agent lane: a configured cloud provider's preferred model first, then the generic `JuneModelID.cloud` row with an honest `cloudNotConfigured` path.
   - Local Apple FM/GGUF models are secondary privacy/offline chat lanes unless a future deterministic tool-call proof explicitly upgrades a specific local capability.
   - Local rows are chat tier only: no `supportsFunctionCalling`, no fake tools, no dead tool buttons.
   - Cloud rows may advertise agent capability only when they route through the real agent loop.
   - Non-agent-tier cloud providers can remain visible as cloud chat/provider rows, but must not be marked as full agent rows.

3. Route cloud through the in-process runner.
   - Direct `CloudTextModelID` rows and `JuneModelID.cloud` should call `GooseMASAgentCoreRunner.streamGooseMASAgentCoreRun`.
   - Local Apple FM/GGUF streams should be wrapped as text events and must not fall into the cloud path.
   - Unknown or legacy local ids must fall back to on-device lanes, never cloud.

4. Preserve the event contract exactly.
   - `.textDelta` -> `message.delta` with both `text` and `delta`.
   - `.thinkingDelta` -> `thinking.delta` with both `text` and `delta`.
   - `.toolStarted` -> `tool.start`.
   - `.toolCompleted` -> `tool.complete`.
   - `.permissionRequired` -> `approval.request`.
   - `.complete` -> `message.complete`.
   - Byte-bound emitted tool payloads and redact active vault roots before sending anything to JS, including raw paths, `file://` URLs, percent-encoded paths, and symlink-resolved forms. Scan with root-length lookahead before final truncation so a vault root split across the cap does not leak a prefix.
   - Bound tool event metadata separately from payload bodies: tool ids are exact byte-limited protocol handles, while tool names and approval risk labels are byte-limited display/replay fields before JS events and durable replay. Approval request ids are exact protocol handles, so oversized/empty/control-character ids fail closed instead of being truncated.
   - Keep this boundary factored: `JuneAgentCoreVaultScope` owns selected-vault/scratch scope and redaction candidates; `JuneToolEventBounds` owns payload truncation, metadata bounds, protocol-id validation, and approval descriptions. Do not reintroduce these helpers into the gateway event loop.

5. Make approvals fail closed.
   - Add or verify `approval.respond`.
   - Validate `session_id`, bounded `choice`, and a required bounded `request_id` that exactly matches the pending approval for that session.
   - Keep pending approvals bounded.
   - Deny pending approvals on interrupt, deletion, cancellation, overflow, stale ids, or timeout.

6. Use the app-owned vault scope.
   - Prefer `AppBootstrap.shared?.vaultSync.vaultURL` only when `VaultSyncService` is already watching the selected vault.
   - Do not re-resolve bookmarks or independently call `startAccessingSecurityScopedResource` from June gateway code.
   - Never default to `$HOME` or ambient `EPISTEMOS_VAULT_PATH`/`VAULT_PATH`; no-vault runs use an app-support scratch directory.
   - Preserve the extracted `@MainActor` helper boundary so app-state reads keep the same actor isolation they had inside `JuneAgentGateway`.

7. Remove bypasses and stale helpers.
   - Delete old direct-chat cloud helpers when the gateway no longer calls them.
   - Retain proxy scaffolding only when it has a named future admission path and tests.
   - Document retained orphans in `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`.

8. Verify in layers.
   - Source guard: no fake local tool caps, no `bootstrap.cloudLLMClient.stream` in June gateway, cloud exact routes call the agent-core stream, local fallback does not.
   - Gateway id guard: `JuneAgentGateway` must use `JuneGatewayReplyID(rawValue:)` before `reply` / `replyError`, including async Prompt Forge replies.
   - Default guard: `currentDefaultModelID()` must prefer configured cloud, otherwise `JuneModelID.cloud`; never restore local-first fallback as the silent default.
   - June vault authority guard: `JuneAgentGateway` must call `JuneAgentCoreVaultScope.vaultPathForAgentCore()`, `JuneAgentCoreVaultScope` must use only the selected watched vault or app-support scratch, and `JuneToolEventBounds` must redact roots with deterministic longest-first candidates before JS exposure.
   - Vault fallback guard: `Epistemos/Goose/GooseInProcessACPServer.swift` must not contain `NSHomeDirectory()`; empty MAS runner/session cwd values must use the shared Application Support scratch fallback.
   - Bundle guard: in App Store products, scan `Contents/Resources` for forbidden flattened runtime artifacts (`node`, `bun`, `opencode`, `omega_mcp_stdio`, `goose`, `goosed`, `.bun-*`, `.opencode-*`); `bundle-app-runtime-assets.sh` must remove them for MAS builds.
   - MCP guard: non-`pro-build` Rust must not auto-discover arbitrary URL-MCP config files. MAS HTTP-MCP requires an explicit fixed HTTPS allowlist admission path before `mcp_servers` can become nonempty.
   - Build: `xcodebuild -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` with isolated DerivedData if needed.
   - Rust: at least `cargo test --manifest-path agent_core/Cargo.toml --lib`; full cargo when repo source-guard includes are healthy.
   - Runtime: open the sandboxed MAS build, run a vault read/write task through June, approve the permission prompt, and retain transcript/screenshot/log evidence.

## Review Checklist

- No subprocess, shell, stdio MCP, terminal, code execution, scheduler, imessage, AppleScript, or extension-installer tool is reachable from MAS June.
- MAS URL-MCP discovery stays disabled unless a fixed HTTPS allowlist is explicitly wired and tested.
- No Pro/runtime executable is packaged into the MAS app bundle as a flattened resource, even if direct-build resource folders exist in source.
- No provider key, proxy token, raw receipt, or Keychain value crosses into JS.
- JSON-RPC reply ids are bounded scalar values before being echoed to JS.
- No `.sync` is added to UniFFI callback paths.
- Streams and pending states are bounded.
- Approval responses require an exact pending request id; there is no oldest-pending fallback.
- Tool payload root redaction covers raw path, file URL, encoded, and symlink-resolved forms before any payload reaches JS, with UTF-8 byte caps and truncation marker preservation.
- Tool event ids are exact bounded handles, and tool names/risk labels are bounded before live JS emission, approval descriptions, skill-composition observation, and durable session replay.
- Vault scope and event bounds stay in their extracted MAS helpers; gateway changes should compose them instead of growing another private helper cluster.
- Local stays useful as private chat, not falsely agentic.
- Cloud is the primary default; local only becomes active by explicit user choice or an honest offline/privacy flow.
- Cloud errors are explicit: configuration/subscription/provider gaps guide the user instead of silently failing.
- `docs/research/JUNE_MAS_CONNECTION_AUDIT.md` is updated with verdicts and evidence after every meaningful loop change.
