# Plan 1-MAS — Finalization Handoff (2026-07-03)

Honest §8-ledger state for the MAS agent surface (June Surface A wave chat +
Surface B agent workspace). Branch `feat/goose-surface`. Every claim below is
either PROVEN with a re-runnable witness, CODE-COMPLETE + AppStore-build-green,
or explicitly APP-GATED / EXTERNAL (never fake-flipped).

## Commits
- `df82dc438` P0a — embedded llama.cpp lane + sandboxed no-JIT spike
- `86e7603a1` P0b — agent_core delta-stream spike + 3 provider 400-fixes
- `c8d7926d4` P1/P3/P4 — Surface A + Surface B + paywall client (build green)
- `1502edbae` P1 — Surface A Apple FM witness (PASS live)
- `bf4f04e24` P5 — drop cs.allow-jit from AppStore entitlements

## §8 FEATURE LEDGER — honest status

| Capability | Surface | State | Evidence |
|---|---|---|---|
| Zero-download chat (Apple FM) | A | **PROVEN LIVE** | `scripts/apple-fm-quickchat-probe.sh` → availability=available, streamed answer via snapshot→delta, guardrail reported |
| Stronger local chat (embedded llama.cpp GGUF) | A | **PROVEN** (sandbox + answer) | P0a `scripts/llama-mas-sandbox-spike.sh` (27 tokens, Metal, app-sandbox only, no JIT). `scripts/gguf-answer-probe.sh` (the app's DEFAULT Qwen3-4B model + app ChatML template → coherent answer via `LlamaLocalChatEngine`, 60 tokens @ 17.6 tps). `llama.framework` embedded in the built `Epistemos.app/Contents/Frameworks`. **App-gated:** in-UI answer needs the app launched. |
| Model download manager (checksum/resume/RAM-gate) | A | **CHECKSUM SOURCE PROVEN** + catalog fixed | `QuickChatModelDownloadManager` (HF-published-sha256, atomic, resume, delete-on-corrupt). Verified the HF tree-API `oid` == the file's sha256 for Qwen3-4B (`7485fe6f…`) — the verify-then-install source is correct even for XET repos. **Fixed 2 real catalog bugs:** default repo `Qwen/Qwen3-4B-Instruct-2507-GGUF` didn't exist (→ `Qwen/Qwen3-4B-GGUF`); Qwen2.5-7B official Q4_K_M is split across 2 files (→ single-file `bartowski/Qwen2.5-7B-Instruct-GGUF`). **Live UI download not exercised** (needs app launch). |
| Multi-step cloud agent (agent_core → proxy) | B | **ENGINE PROVEN** + UI wired | P0b `scripts/agent-core-mas-spike.sh` (real 2-turn run, delta stream, main-hop). `AgentWorkspaceSession` drives `GooseMASAgentCoreRunner` directly. **App-gated:** proxy-backed run needs the deployed proxy (below). |
| Thinking/tool/approval stream | B | **PROVEN** (approval round-trip) + UI cards | P0b proved `permission_required` unblocks the loop. `AgentApprovalGate` (NSCondition, blocks the FFI worker not main, 10-min deadline). **App-gated:** live sheet needs interactive app. |
| Agent doc editing + vault access | B | CODE-COMPLETE, build green | document pane + bounded vault path (never $HOME) |
| HTTP MCP (fixed allowlist) | B | CODE-COMPLETE | runner `allowedMASTools` excludes forbidden tools (absent = absent) |
| Subscription gate (StoreKit 2 + proxy) | B | CODE-COMPLETE, build green | `AgentSubscriptionService` + `EpistemosProxyClient` (Keychain token, appAccountToken). **External:** needs sandbox StoreKit product config + the deployed proxy. |
| goosed/Ollama/llama-cli/stdio/terminal/code-exec/schedules | — | **EXCLUDED** | computer_use now `cfg(pro-build)`; GgufCliProvider is pro-build; runner allowlist blocks the rest |

## Build gate
`Epistemos-AppStore` scheme, isolated `-derivedDataPath .derived-data-mas`,
`CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED** (build 3, GGUF lane linked).
EpistemosLlama unit tests **6/6 pass** (`swift test --package-path
LocalPackages/EpistemosLlama`).

## What genuinely remains (owner / external / interactive)

1. **Deployed proxy server (§5 / §11 R4).** The CLIENT is built; the server
   (`POST /v1/auth/verify-receipt`, `/v1/chat/completions` SSE, App Store
   Server Notifications V2 webhook) is separate, explicitly-parallelizable
   infra the owner deploys. Until it exists, Surface B cloud runs use the
   direct provider (dev) rather than the receipt-gated proxy.
2. **Interactive in-app proofs (§7 P1/P4 acceptance):** GGUF live answer,
   Surface B approval sheet blocking a tool, 5.1.2(i) consent sheet, StoreKit
   sandbox purchase → token → cloud turn. All need the running app + (for the
   last) a deployed proxy. NOTE: a PRO-agent app instance was running during
   this session — do not launch a second (shared app-group container).
3. **network.server removal (§5 / task #9 BLOCKER).** Cannot drop while the
   owner-kept Work/OpenCode lane (`WorkSPAServer`/`WorkNativeMCPServer`) opens
   NWListener loopback sockets unconditionally on the AppStore target. Owner
   decision: scheme-gate those listeners off MAS, or keep the entitlement.
4. **OOM soak on 16 GB (§7 P5).** Needs the running app + a resident model.
5. **Release-signed final verification** of the no-JIT entitlement on the full
   app (P0a proved the llama lane; the whole-app signed launch is the last
   confirmation before submission).

## Minor v1-deferred polish (in-code, low priority)
- Surface A "quiet stronger-local upsell" when FM is available (§9.2) — today
  the download offer shows only when no engine is available.
- Surface B transcript persistence to the app container (§3.1) — runs are
  in-memory; agent_core persists per sessionId but the Swift `runs` array is
  ephemeral across launches.

## Re-runnable witnesses
- `bash scripts/llama-mas-sandbox-spike.sh` — GGUF tokens, sandboxed, no JIT
- `bash scripts/agent-core-mas-spike.sh` — agent_core stream + approval
- `bash scripts/apple-fm-quickchat-probe.sh` — Apple FM live answer
- `swift test --package-path LocalPackages/EpistemosLlama` — engine unit tests
