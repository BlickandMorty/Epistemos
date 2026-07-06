# June MAS Connection Audit

Date: 2026-07-06
Scope: MAS June agent surface only: `Epistemos/JuneAgent/**`, the existing in-process MAS agent runner, and MAS/JUNE audit evidence. This audit deliberately excludes Pro, ExperimentalAgent, Tauri, Retro, and unrelated product surfaces.

## Canon Read

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
- `docs/prompts/BUILD_PROMPT_MAS_JUNE_ENTERPRISE.md`
- `docs/research/GOOSE_MAS_BUILD_CANON_2026_06_30.md`
- `docs/research/GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`
- `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`
- `docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
- `CLAUDE.md` MAS agent constraints
- Official spot-checks: Apple App Review Guidelines 2.5.2/5.1.2/public API, App Sandbox file access, WebKit `WKWebView`/script-message transport, StoreKit transaction/server validation, Foundation Models availability.

## Executive Verdict

The MAS June surface is real enough to render and stream chat, but it is not yet the enterprise-grade agent described by the canon.

Primary verdict: HALF-WIRED.

The web bundle, asset sandbox, native bridge, durable sessions, warm-webview performance path, and local chat lanes are mostly connected. The cloud lane, however, is still direct text streaming through `cloudLLMClient`/`JuneCloudEngine`, not the in-process `agent_core` loop. That disconnect also forces a second serious issue: local rows currently advertise `supportsFunctionCalling` just to satisfy June's picker, even though local mode is chat-only.

## Highest-Risk Findings

### HIGH-1: Cloud lane bypasses `agent_core`

Verdict: DISCONNECTED.

Supposed: June cloud turns should map `session/new -> prompt -> stream -> abort` onto `agent_core runAgentSession` plus `AgentEventDelegate`, preserving thinking, tools, permission requests, completion, and cancellation.

Actual:

- `Epistemos/JuneAgent/JuneAgentGateway.swift:507` routes direct `CloudTextModelID` rows to `makeDirectCloudStream`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:553` calls `AppBootstrap.cloudLLMClient.stream(...)`, which is text chat, not the agent loop.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:514` routes `JuneModelID.cloud` to `JuneCloudEngine.shared.stream`.
- `Epistemos/JuneAgent/JuneCloudEngine.swift:61` posts OpenAI-compatible `/chat/completions` and only yields `delta.content`.

Impact: no vault tools, no MAS tool allowlist execution, no thinking blocks, no tool cards, no approval flow, no end-to-end agent task. DoD-2 is red.

### HIGH-2: Local model rows fake tool capability

Verdict: DISCONNECTED from capability truth.

Supposed: local = chat tier, no fake function-calling; cloud = agentic only when the real agent loop is wired.

Actual:

- `Epistemos/JuneAgent/JuneAgentGateway.swift:302` defines `localPickerCapabilities = ["supportsFunctionCalling"]`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:751` and `Epistemos/JuneAgent/JuneAgentGateway.swift:777` attach that marker to Apple FM and GGUF rows.
- The vendored June picker treats `supportsFunctionCalling` as the hard gate in `/Users/jojo/dev/june-epistemos/src/lib/model-privacy.ts`; the MAS prompt explicitly says this gate is the truth boundary.

Impact: local chat rows can be selected because they claim the exact capability they do not have. DoD-3 is red.

### HIGH-3: Swift gateway lacks approval response RPC

Verdict: HALF-WIRED.

Supposed: `agent_core` permission requests should render as `approval.request`, block the run, and resume when June sends `approval.respond`.

Actual:

- Vendored June already renders `approval.request` and sends `approval.respond`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift` handles `ping`, `session.create`, `session.resume`, `prompt.submit`, `session.interrupt`, and `command.dispatch`; it does not handle `approval.respond`.
- `GooseMASAgentCoreRunner` already exposes `permissionHandler` but the existing AgentWorkspace wrapper uses a native approval gate, not June's web approval card.

Impact: once the cloud lane is moved to `agent_core`, permission-required tasks would stall or auto-fail unless June's response path is wired.

## Seven-Layer Audit

| Layer | Supposed | Actual | Verdict |
| --- | --- | --- | --- |
| 1. Vendored June web app | Bundle loads inside MAS WKWebView; no Tauri runtime, no sidecar. | `JuneAgentSurfaceView` resolves bundled assets, uses non-persistent WK data store, injects the host shim, and serves `june://bundle/index.html`. | CONNECTED |
| 2. Transport and bridge | Webview RPC and streams stay in-process; no listening port; payloads bounded. | `JuneAgentBridge` uses `WKScriptMessageHandler`; gateway frames are capped to 1 MB in `JuneAgentGateway`; assets are confined by `JuneSchemeHandler` with CSP. Invoke args are command-bounded but lack one global byte cap. | CONNECTED with one MED hardening item |
| 3. Cloud agentic loop | Cloud uses `agent_core runAgentSession` and streams text, thinking, tools, approvals, completion. | Cloud is direct chat streaming. `GooseMASAgentCoreRunner` exists and can emit the needed events, but June does not call it. | DISCONNECTED |
| 4. MAS tool catalog | Only sandbox-legal tools: vault, knowledge/search/provenance, fixed HTTPS remote MCP; no shell/subprocess/stdio/code execution. | The reusable runner has an allowlist (`vault.*`, `knowledge.recall`, `web.*`, `http_fetch`, `think`) and disables bash. Since June never calls it, the catalog is present but not connected. | HALF-WIRED |
| 5. Capability truth and picker | Local chat rows stay no-tools; cloud rows advertise tools only if backed by a real agent loop. | Local rows fake `supportsFunctionCalling`. Direct provider rows also advertise function-calling while routing to direct chat. | DISCONNECTED |
| 6. Session history and stream fidelity | Durable sessions preserve enough structure for text, thinking, tool, and approval replay. | `JuneSessionStore` persists title/model/text messages. Live June can render thinking/tools/approvals, but persisted history is text-only. | HALF-WIRED |
| 7. Paywall, secrets, and MAS review | Secrets stay Keychain/native; StoreKit/proxy gate is honest; no JS secrets; no local server/subprocess. | `JuneCloudEngine` uses Keychain proxy session and no JS secret. Direct provider rows use saved credentials through native cloud client. Third-party AI consent/product copy and receipt-proof need final MAS release evidence. | HALF-WIRED |

## Connected Pieces Worth Preserving

- `JuneSchemeHandler` confines asset paths, blocks unlicensed upstream fonts, serves CSP, and reads assets off-main.
- `JuneAgentSurfaceHolder` keeps the WKWebView warm with non-persistent storage, matching the performance doctrine.
- `JuneAgentGateway` already bounds frame size, concurrent turns, prompt size, title size, and response bytes.
- `GooseMASAgentCoreRunner` already emits text, thinking, tool start, tool complete, permission required, completion, and errors from `agent_core`.
- Vendored June already supports `message.*`, `thinking.delta`, `tool.*`, and `approval.request` frames in the chat runtime.

## Phase B Fix Order

1. Add failing MAS/JUNE source-guard tests for capability truth and cloud `agent_core` routing.
2. Remove `localPickerCapabilities`; keep local rows selectable without claiming tool capability, or make them honest non-tool rows if the current picker refuses them.
3. Route cloud model turns through `GooseMASAgentCoreRunner.streamGooseMASAgentCoreRun`.
4. Translate runner events to June frames:
   - `.textDelta` -> `message.delta`
   - `.thinkingDelta` -> `thinking.delta`
   - `.toolStarted` -> `tool.start`
   - `.toolCompleted` -> `tool.complete`
   - `.permissionRequired` -> `approval.request`
   - `.complete` -> `message.complete`
5. Add `approval.respond` handling in `JuneAgentGateway` with request/session validation and a bounded pending-approval registry.
6. Keep local lanes chat-only and make `cloudNotConfigured`/subscription errors explicit.
7. Re-run MAS/JUNE automated checks, then the broader release-audit checks only after the focused lane is green.

## Phase C Hardening Targets

- Security: global byte caps for invoke args; sanitize tool input/result summaries before sending to JS; prove no token/path/prompt bytes in logs.
- Memory: bound pending approvals, stream buffers, trace frames, and persisted histories; avoid unbounded AsyncStream patterns.
- Data leak: no raw Keychain values in JS/UserDefaults/logs; no raw vault path exposure beyond required user-facing file labels.
- Robustness/fluidity: cancellation must cancel `agent_core`; stale approval responses must fail closed; cloud errors must render as recoverable chat errors.

## Current DoD Status

- DoD-1 audit: this document.
- DoD-2 real cloud agent: RED until June calls `agent_core` and a vault/tool task passes end to end.
- DoD-3 capability truth: RED until local rows stop claiming function calling.
- DoD-4 hardening: RED until Phase B code is audited and checks pass.
- DoD-5 verification: RED until `swift test`, `cargo test --manifest-path agent_core/Cargo.toml`, MAS App Store scheme build, sandbox manual run, and repeated zero-fail release-audit evidence are complete.
