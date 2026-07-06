# June MAS Connection Audit

Date: 2026-07-06
Scope: MAS June agent surface only: `Epistemos/JuneAgent/**`, the in-process MAS `agent_core` runner, active vault path handoff, and MAS/JUNE evidence. This audit deliberately excludes Pro, ExperimentalAgent/1Code, Tauri, Retro, and unrelated product surfaces.

## Canon Read

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
- `docs/prompts/BUILD_PROMPT_MAS_JUNE_ENTERPRISE.md`
- `docs/research/GOOSE_MAS_BUILD_CANON_2026_06_30.md`
- `docs/research/GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`
- `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`
- `docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
- `CLAUDE.md` MAS agent constraints
- Official API spot-checks: Foundation Models, StoreKit receipt validation / App Store Server API direction, security-scoped bookmarks, `WKWebView`, and custom scheme handlers.

## Executive Verdict

Primary verdict after Phase B source forge: HALF-WIRED, improving toward CONNECTED.

The prior prime suspect was real: before this cycle, June's cloud turns were still direct chat and local rows claimed function-calling to satisfy the picker. That is now fixed in source. June cloud turns route through the in-process `GooseMASAgentCoreRunner`, stream text/thinking/tool/approval/completion events into the June runtime, and use the active app vault path when `VaultSyncService` is already watching a selected security-scoped vault.

The honest remaining blocker is proof, not plumbing: DoD-2 still requires a running sandboxed App Store build task that reads and writes the user's vault through the approval UI. The code now has the source path for that proof, but the proof has not been captured in this cycle. Runtime probing did capture one useful truth-boundary result: unconfigured cloud access now fails loudly with a Settings-directed `cloudNotConfigured` message instead of pretending to work.

## Highest-Risk Findings

### HIGH-1: Cloud lane bypassed `agent_core`

Verdict: FIXED IN SOURCE, RUNTIME PROOF PENDING.

Supposed: June cloud turns should map `session.create/resume -> prompt.submit -> stream -> interrupt` onto `agent_core runAgentSession`, preserving thinking, tools, permission requests, completion, and cancellation.

Actual now:

- `Epistemos/JuneAgent/JuneAgentGateway.swift:603` builds an agent-core cloud stream with `GooseMASAgentCoreRunner.streamGooseMASAgentCoreRun`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:630` routes both direct `CloudTextModelID` rows and `JuneModelID.cloud` through that stream.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:467` maps runner events into June frames: `message.delta`, `thinking.delta`, `tool.start`, `tool.complete`, `approval.request`, and `message.complete`.
- `Epistemos/Goose/GooseInProcessACPServer.swift:49` calls `runAgentSession` in process, disables bash with `enableBash: false`, binds the MAS allowlist, and cancels via `cancelAgentSession`.

Residual: the old `JuneCloudEngine` proxy client still exists as receipt/proxy scaffolding and test target material, but the June gateway no longer calls it.

### HIGH-2: Local model rows faked tool capability

Verdict: FIXED IN SOURCE AND RUNTIME.

Supposed: local = chat tier, no fake function-calling; cloud = agentic only when backed by the real agent loop.

Actual now:

- `Epistemos/JuneAgent/JuneAgentGateway.swift:1044` documents `modelSupportsTools` as the truth boundary.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:1053` exposes Apple FM as an `epistemos-local-chat` row with `capabilities: []`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:1064` exposes GGUF rows as local chat rows with `capabilities: []`.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:1099` gives direct cloud rows `supportsFunctionCalling` only when `provider.supportsAgentTier` is true.
- `Epistemos/State/InferenceState.swift:64` defines the agent-tier gate as OpenAI/Anthropic only.
- `/Users/jojo/dev/june-epistemos/src/lib/model-privacy.ts:61` now recognizes only provider-empty `epistemos-local-chat` rows as local chat, while `modelSupportsTools` remains capability-only.
- `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx:2434` lets those explicit local chat rows be selected without granting tools, and `:7202` changes the footer copy to say local chat runs on this Mac while tools stay on the configured cloud-agent lane.
- `/Users/jojo/dev/june-epistemos/src/test/model-privacy.test.ts:104` proves local chat rows are not tool-capable and cloud rows cannot borrow the local-chat trait.

Runtime proof: the cleaned App Store product served `june://bundle/index.html` from `Contents/Resources/JuneWeb/dist/assets/main-n3fFHdY3.js`; `Apple Intelligence (on-device)` appeared in All models, selected without the old "can't run tools" rejection, updated the footer to "Tools stay on the configured cloud-agent lane", and answered a tiny local chat prompt with "Hello! How can I help you today?"

### HIGH-3: Swift gateway lacked approval response RPC

Verdict: FIXED IN SOURCE, RUNTIME PROOF PENDING.

Supposed: `agent_core` permission requests should render as `approval.request`, block the run, and resume only when June sends `approval.respond`.

Actual now:

- `Epistemos/JuneAgent/JuneAgentGateway.swift:385` handles `approval.respond` with session, bounded choice, optional request id, and fail-closed stale-response validation.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:508` records pending approvals and emits `approval.request` payloads.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:815` bounds pending approval state and denies floods or invalid ids.
- `Epistemos/JuneAgent/JuneAgentGateway.swift:378` and `Epistemos/JuneAgent/JuneAgentGateway.swift:948` deny pending approvals on interrupt/delete.

Residual: June's current web response omits `request_id` in some paths, so the gateway supports oldest-pending fallback by session. That is acceptable for the current single active approval pattern, but request-id propagation should become the next UI hardening pass.

### HIGH-4: App Store bundle shipped Pro/runtime process binaries

Verdict: FIXED IN SOURCE AND CLEANED PRODUCT.

Supposed: MAS builds must not ship forbidden process runtimes or stdio MCP binaries. June is in-process only; no hidden sidecar, shell, terminal, stdio MCP, opencode, node, or bun runtime may be present as a reachable MAS artifact.

Actual found in the first App Store debug product:

- `/tmp/epistemos-appstore-dd-june-cycle1-localgate/Build/Products/Debug/Epistemos.app/Contents/Resources/node`
- `/tmp/epistemos-appstore-dd-june-cycle1-localgate/Build/Products/Debug/Epistemos.app/Contents/Resources/bun`
- `/tmp/epistemos-appstore-dd-june-cycle1-localgate/Build/Products/Debug/Epistemos.app/Contents/Resources/opencode`
- `/tmp/epistemos-appstore-dd-june-cycle1-localgate/Build/Products/Debug/Epistemos.app/Contents/Resources/omega_mcp_stdio`
- Flattened sentinel files `.bun-1.3.14-bun-darwin-aarch64` and `.opencode-1.17.9-opencode-darwin-arm64`

Root cause: Xcode's synchronized resource groups flatten files from `Epistemos/Resources/opencode-runtime/bin` and `Epistemos/Resources/openchamber-runtime/bin` into `Contents/Resources` even though `bundle-app-runtime-assets.sh` already strips Goose binaries for App Store builds.

Fix: `bundle-app-runtime-assets.sh:235` now adds `remove_app_store_forbidden_runtime_artifacts`, and the App Store branch calls it at `:257`. A disposable fake App Store resources directory proved it removes only `goose`, `goosed`, `node`, `bun`, `opencode`, `omega_mcp_stdio`, and the flattened bun/opencode sentinels while preserving unrelated resources. The same patched script was run against the already-built App Store product; a root `Contents/Resources` scan returned `0 forbidden-root-resources` while preserving the vendored June asset `main-n3fFHdY3.js`.

## Seven-Layer Audit

| Layer | Supposed | Actual | Verdict |
| --- | --- | --- | --- |
| 1. June SPA -> bridge | Vendored June loads in MAS WKWebView, no Tauri runtime, no sidecar, pinned scheme origin. | `JuneAgentSurfaceView.swift:44` creates a non-persistent `WKWebView`; `JuneAgentSurfaceView.swift:47` serves the bundle through `JuneSchemeHandler`; `JuneAgentSurfaceView.swift:96` injects the shim. `JuneSchemeHandler.swift:52` confines paths and `JuneSchemeHandler.swift:94` sets a same-origin CSP. | CONNECTED |
| 2. 13 plan-critical invokes + Tauri shim | The Hermes/Tauri client should get enough native answers to boot, list sessions/messages, select models, and submit turns; unavailable June features should be honest no-ops. | `JuneAgentBridge.swift:151` services `bootstrap_app`; `:158` accounts status; `:176` bridge status/start/stop; `:180` sessions; `:182` messages; `:185` ensure session/model; `:196` delete; `:202` title suggestion; `:225` provider settings; `:234` list models; `:242` set model. Side panels such as notes/folders/dictation/task lists return bounded empty shapes. Unknown commands log and resolve `null`; malformed payloads are dropped at `:50`/`:59`. | CONNECTED with LOW orphan/no-op inventory |
| 3. Bridge -> gateway RPC | Webview RPC must stay in process, validate payload shape/size, and never expose secrets to JS. | `JuneAgentBridge.swift:50` forwards bounded `epistemosGateway` frames; `JuneAgentGateway.swift:317` caps raw frames to 1 MB and validates JSON-RPC shape; `JuneAgentBridge.swift:123` injects replies through escaped JSON string literals. | CONNECTED |
| 4. Gateway -> engine stream | `session.create`, `prompt.submit`, stream, interrupt, and model selection must reach the selected engine lane. | `JuneAgentGateway.swift:336` creates durable sessions; `:354` starts turns; `:431` resolves persisted/requested model; `:603` builds the cloud agent stream; `:646` keeps local lanes text-only; `:378` cancels running turns and approvals. | CONNECTED in source |
| 5. Cloud agentic loop | Cloud runs the full `agent_core` loop, not direct chat. | `GooseMASAgentCoreRunner` calls `runAgentSession` in process at `GooseInProcessACPServer.swift:87`; the June gateway maps all agent events at `JuneAgentGateway.swift:467`. Runtime with Keychain disabled reached the cloud lane and failed honestly with `cloudNotConfigured`; a successful tool-using cloud run still requires configured cloud access. | CONNECTED in source, blocked for successful runtime proof |
| 6. MAS tool catalog and vault substrate | Only MAS-legal tools are reachable; vault I/O uses the selected security-scoped vault; no shell/subprocess/stdio tools. | `GooseInProcessACPServer.swift:36` allowlists `vault.search/read/write/list`, `knowledge.recall`, web fetch/search, `http_fetch`, and `think`; `:68` sets `enableBash: false`. `JuneAgentGateway.swift:767` now gives agent_core the already-watched `VaultSyncService.vaultURL` and falls back to env/scratch only when no vault is active. `JuneAgentGateway.swift:800` redacts known vault roots from tool payloads sent to JS. | HALF-WIRED: source connected, end-to-end vault task not yet proven |
| 7. Capability, sessions, paywall, hardening | Capability copy must be truthful; sessions durable/crash-safe; cloud credentials/proxy gate must stay Keychain/StoreKit; no forbidden tool appears. | Local rows are chat-only; direct cloud tool rows require `supportsAgentTier`; the vendored June fork now lets explicit local chat rows be selected without tool claims, proven in the cleaned product. `JuneSessionStore` persists sessions/messages/model and auto-titles, but thinking/tool replay is still live-only text persistence. Provider secrets live in Keychain via existing provider/proxy systems; StoreKit proxy client exists, but June's `Epistemos Cloud` row currently selects configured agent-tier providers rather than proving receipt-gated proxy admission. First runtime packaging pass found flattened `node`/`bun`/`opencode`/`omega_mcp_stdio`; source cleanup plus post-build product cleanup now scan clean. | HALF-WIRED |

## Phase B Changes Landed In Source

- Cloud agent path: direct cloud IDs and `JuneModelID.cloud` now call `makeAgentCoreCloudStream` instead of the old direct text stream.
- Event translation: text, thinking, tools, permission, completion, and errors are translated into June's existing event vocabulary.
- Approval bridge: added `approval.respond`, bounded pending approval state, interruption/delete denial, stale response failure, and 10-minute runner timeout inherited from `AgentApprovalGate`.
- Capability truth: removed local fake `supportsFunctionCalling`; local rows now advertise `epistemos-local-chat` and empty capabilities; non-agent-tier cloud providers are visible but not advertised as tool-capable.
- Vendored June truth gate: local chat rows are selectable in the web picker without changing `modelSupportsTools`, and cloud rows cannot borrow the local-chat trait.
- Vault substrate: cloud agent runs use the app's active watched vault path when present and never default to `$HOME`; no-vault sessions use an app-support scratch directory.
- Payload hardening: tool input/result payloads are capped and known vault roots are redacted before reaching JS.
- Session/model parity: per-session model selection can persist through `ensure_hermes_bridge_session`, `prompt.submit` model params, and `/model ...` commands.
- Dead-code reduction: removed the stale gateway `cloudMessages` helper that belonged to the direct-chat cloud path.
- MAS packaging hardening: App Store bundle cleanup now removes flattened Pro/runtime executables and stdio MCP sentinels after Xcode resource copying.

## Orphans And Placeholders

- `JuneCloudEngine.swift`: retained for the receipt-gated proxy scaffolding/tests, but no longer called by `JuneAgentGateway`. Status: DEFERRED MED until proxy-backed `epistemos-cloud` is either wired into agent_core or removed from the June row copy.
- `list_notes`, `list_folders`, `list_agent_tasks`, dictation, cron/toolset/skill admin invokes: bounded empty shapes by design for MAS June room. Status: LOW if they remain visible in UI; acceptable if hidden by June surface composition.
- `JuneSessionStore` replay: assistant text persists; thinking/tool/approval structure does not. Status: MED until durable structured event replay exists.
- HTTP-MCP allowlist: runner allows web/http tools by name, but fixed HTTPS endpoint allowlist proof was not captured in this cycle. Status: MED release-gate evidence item.

## Hardening Report

Thermonuclear shape across Phase B touched surface:

- HIGH: 0 open HIGHs in the touched June gateway path.
- HIGH-4 FIXED: App Store resource flattening shipped forbidden `node`, `bun`, `opencode`, and `omega_mcp_stdio` binaries. `bundle-app-runtime-assets.sh` now strips them for App Store builds; the patched script cleaned the App Store product and the product scan returned `0 forbidden-root-resources`.
- MED-1 FIXED IN SOURCE / PROOF PENDING: cloud agent loop now routes through in-process `agent_core`, but DoD-2 still needs a sandbox runtime transcript with vault read/write and approval.
- MED-2 FIXED: local capability truth is honest in Swift and vendored June; running June selected Apple Intelligence without fake tool caps and completed a tiny local chat turn.
- MED-3 OPEN: StoreKit receipt-gated proxy admission is not the current June cloud path; `Epistemos Cloud` copy must be reconciled with configured-provider agent_core routing or a proxy provider slug.
- MED-4 OPEN: structured thinking/tool replay is live-streamed but not durable across relaunch.
- MED-5 OPEN: fixed HTTPS remote MCP allowlist must be proven in `agent_core` runtime evidence, not inferred from Swift tool names.
- LOW-1 OPEN: side-feature no-op invokes should be pruned from visible June UI if they remain reachable.

Non-negotiable grep/proof status:

- No subprocess introduced in touched June gateway path.
- Local rows do not claim function calling.
- Cloud stream uses bounded `AsyncThrowingStream` from existing runner path; response bytes and pending approvals are bounded.
- Secrets do not enter webview JS in touched code.
- No `UserDefaults` secret storage was added.
- No `.sync` UniFFI callback was added.
- No forbidden MAS tool names were added to the Swift allowlist.
- App Store packaging source cleanup now strips flattened forbidden runtime artifacts; patched product scan returned clean.

## Verification Evidence

- Source guard subset: PASS. Checks included no `localPickerCapabilities`, no `bootstrap.cloudLLMClient.stream` in June gateway, cloud route calls `makeAgentCoreCloudStream`, and Apple FM fallback does not.
- Vendored June web tests: PASS for `./node_modules/.bin/vitest run src/test/model-privacy.test.ts` (12 tests) and `./node_modules/.bin/tsc --noEmit` in `/Users/jojo/dev/june-epistemos`.
- Vendored June web bundle: PASS. `./build-june-web.sh` staged 27 files and the product copied `Contents/Resources/JuneWeb/dist/assets/main-n3fFHdY3.js`; main chunk remains a perf warning at 522 KB gz.
- Runtime cloud-not-configured proof: PASS for honest failure. In the sandboxed MAS build, a vault/tool prompt on the default cloud row returned `Error: Cloud access is not configured. Connect this provider or Epistemos Cloud in Settings, or pick an on-device model.`
- Runtime local-picker regression: FIXED. The prior product rejected `Apple Intelligence (on-device)` with "can't run June's tools"; the cleaned product selected it, displayed the cloud-agent caveat, and answered "Hello! How can I help you today?"
- App Store forbidden-resource script test: PASS in `/tmp/epistemos-mas-runtime-cleanup-test`; the cleanup removed the forbidden runtime artifacts and preserved `keep.txt`.
- App Store forbidden-resource product scan: PASS after running patched `bundle-app-runtime-assets.sh` against `/tmp/epistemos-appstore-dd-june-cycle1-localgate/Build/Products/Debug/Epistemos.app`; root `Contents/Resources` scan returned `0 forbidden-root-resources`.
- App Store build: PASS with isolated derived data: `xcodebuild -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-appstore-dd-june build CODE_SIGNING_ALLOWED=NO`.
- Rust library tests: PASS for `cargo test --manifest-path agent_core/Cargo.toml --lib` (5,572 tests).
- Full Rust tests: BLOCKED before execution by unrelated source-guard includes for missing `Epistemos/LocalAgent/RuntimeRouter.swift` and `Epistemos/Views/Settings/RuntimeLanesSection.swift`.
- Swift test scheme: BLOCKED. `Epistemos-AppStore` has no test action; broad `Epistemos` focused test failed before executing with missing `llama` module dependency.
- Running sandboxed end-to-end vault task: NOT YET CAPTURED. This keeps DoD-2/DoD-5 amber-red.
- Running cloud-vault task with Keychain disabled: BLOCKED HONESTLY. The task rendered `Error: Cloud access is not configured. Connect this provider or Epistemos Cloud in Settings, or pick an on-device model.` No `june-mas-runtime-proof.md` file was written to the synthetic vault.
- Running selected-vault caution: a manual Settings vault-selection attempt unexpectedly began connecting a remembered/user folder (`Kimi_Agent_Deterministic AI Deep Dive`) instead of the synthetic proof vault; the app was interrupted immediately. Future runtime proof should use an isolated selected-vault harness or explicit owner-approved path, not blind UI selection.

## Current DoD Status

- DoD-1 audit: UPDATED with Phase B/C source evidence.
- DoD-2 real cloud agent: AMBER-RED. Source is wired to `agent_core`; a real sandboxed vault read/write task with approval proof is still required.
- DoD-3 capability truth: GREEN for the tested local/cloud gating slice. Local chat is selectable/useful without tool claims; cloud-not-configured guides honestly.
- DoD-4 hardening: AMBER-GREEN. Gateway path has no open source HIGHs; packaging HIGH is fixed in source and product scan. Release-grade successful cloud-vault runtime evidence remains blocked by cloud configuration.
- DoD-5 verification: AMBER-RED. App Store build and Rust library tests passed; full test suite and running MAS task are not complete.

## Next Cycle Crux

The next frontier should not add another metadata gate. It should use the new June agent-core cloud-loop skill to capture the missing running proof: open the App Store build, connect/select a sandboxed vault, ask June to find notes and write a new note, approve the tool request, and retain transcript/screenshot/log evidence that the tool call used the selected vault with no raw secret or forbidden tool exposure.
