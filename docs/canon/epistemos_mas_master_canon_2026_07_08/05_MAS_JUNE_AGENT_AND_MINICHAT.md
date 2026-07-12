# 05 - MAS June Agent and MiniChat

## Non-negotiable answer

**Epdoc MiniChat / Epdoc Assist should be MAS-June owned. It should not be Goose, 1Code, Kindred, Node/Tauri, a local server, a subprocess, or a separate runtime.**

## MAS June architecture

The active agent surface is June in the MAS app. The preferred architecture is:

- Vendored/bundled June frontend as static app resources.
- Swift `WKWebView` host with native chrome and native permission/approval surfaces.
- `JuneAgentBridge` / equivalent message bridge to Swift.
- Swift calls in-process `agent_core` through UniFFI or direct FFI.
- Cloud lane uses receipt/proxy if monetized; secrets live in Keychain.
- Local lane uses Apple Foundation Models or bundled local model path only when honest and verified.
- One capability registry, one approval path, one provenance ledger, one status/event bus.

## Forbidden architecture

- No Tauri runtime in MAS.
- No Node backend.
- No local server.
- No subprocess agent runtime.
- No stdio MCP.
- No terminal/code-exec tools.
- No second transcript database.
- No hidden sidecar or loopback server unless explicitly reviewed and justified.

## MiniChat tradeoff

| Option | Verdict | Reason |
|---|---|---|
| Native shell + same June session | Preferred | Best MAS story; keeps one authority and native approval/provenance |
| Compact bundled June component | Conditional | Accept if it reuses session/tool/provenance and does not create a runtime/server/db |
| Fully native independent chat | Risky | Duplicates transcript/composer state unless carefully bridged |
| Goose/1Code/Kindred | Parked/forbidden as active | Violates owner lock |
| Separate runtime/database | Forbidden | Creates second chat/tool authority |

## Approval and provenance model

Every tool or edit suggestion must produce:

- run ID
- turn ID
- tool name/schema version
- requested scope
- approval status
- preview/dry-run diff where destructive
- ledger event
- final applied artifact/hash
- rollback/undo path

## StoreKit / proxy / cloud notes

If cloud tools are paid, use StoreKit and official App Store Server API flow. App Review notes must describe what cloud features do, what data leaves device, whether user files are sent, and how users can stay local/offline. Provider keys stay server-side; any short-lived app token lives in Keychain.

## Foundation Models/local model notes

Apple Foundation Models is the cleanest local path where available. Third-party local models are not categorically impossible, but they require: bundle-size evidence, memory/cancel/teardown proof, no executable downloads, no hidden server, no default mutation without owner approval, and honest capability labels. Local models must not advertise tool authority unless grammar/tool path is genuinely proven.

## Required release evidence

- One real cloud turn.
- One real local turn or honest unavailable state.
- One approved MAS-safe tool call.
- One denied tool call.
- One MiniChat/Epdoc assist suggestion linked to the same ledger.
- Source/strings scan proves no `Goose`, `OpenChamber`, `Kindred`, `1Code`, `Tauri`, `Node`, `stdio`, `terminal`, `subprocess`, `browser-use`, `Chromium` runtime in MAS archive.
- Keychain-only secret proof.
- App Review notes written.
