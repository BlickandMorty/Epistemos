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
7. `Epistemos/Goose/GooseInProcessACPServer.swift`
8. `Epistemos/Sync/VaultSyncService.swift` when vault pathing or security scope is touched.

## Method

1. Prove the surface boundary first.
   - Confirm all touched code is under `#if EPISTEMOS_APP_STORE`.
   - Confirm no edits touch `Epistemos/ExperimentalAgent/**`, `src-tauri/`, Retro, or unrelated lanes.
   - Confirm June uses `WKScriptMessageHandler` and the custom `june://` scheme, not a sidecar or local server.

2. Preserve capability truth before adding power.
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
   - Bound emitted tool payloads and redact active vault roots before sending anything to JS.

5. Make approvals fail closed.
   - Add or verify `approval.respond`.
   - Validate `session_id`, bounded `choice`, and optional `request_id`.
   - Keep pending approvals bounded.
   - Deny pending approvals on interrupt, deletion, cancellation, overflow, stale ids, or timeout.

6. Use the app-owned vault scope.
   - Prefer `AppBootstrap.shared?.vaultSync.vaultURL` only when `VaultSyncService` is already watching the selected vault.
   - Do not re-resolve bookmarks or independently call `startAccessingSecurityScopedResource` from June gateway code.
   - Never default to `$HOME`; no-vault runs use an app-support scratch directory.

7. Remove bypasses and stale helpers.
   - Delete old direct-chat cloud helpers when the gateway no longer calls them.
   - Retain proxy scaffolding only when it has a named future admission path and tests.
   - Document retained orphans in `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`.

8. Verify in layers.
   - Source guard: no fake local tool caps, no `bootstrap.cloudLLMClient.stream` in June gateway, cloud exact routes call the agent-core stream, local fallback does not.
   - Build: `xcodebuild -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` with isolated DerivedData if needed.
   - Rust: at least `cargo test --manifest-path agent_core/Cargo.toml --lib`; full cargo when repo source-guard includes are healthy.
   - Runtime: open the sandboxed MAS build, run a vault read/write task through June, approve the permission prompt, and retain transcript/screenshot/log evidence.

## Review Checklist

- No subprocess, shell, stdio MCP, terminal, code execution, scheduler, imessage, AppleScript, or extension-installer tool is reachable from MAS June.
- No provider key, proxy token, raw receipt, or Keychain value crosses into JS.
- No `.sync` is added to UniFFI callback paths.
- Streams and pending states are bounded.
- Local stays useful as private chat, not falsely agentic.
- Cloud errors are explicit: configuration/subscription/provider gaps guide the user instead of silently failing.
- `docs/research/JUNE_MAS_CONNECTION_AUDIT.md` is updated with verdicts and evidence after every meaningful loop change.
