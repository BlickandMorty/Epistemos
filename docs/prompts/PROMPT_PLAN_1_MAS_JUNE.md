# PLAN 1 (MAS) — Two Surfaces: Wave Quick Chat + June Agent Workspace on agent_core

**Date:** 2026-07-03 · **Status: CANONICAL for the Mac App Store build** · Sibling of
[`PROMPT_PLAN_1_PRO_OPENCHAMBER.md`](PROMPT_PLAN_1_PRO_OPENCHAMBER.md) (Pro track).
Together these two replace the retired reskin-era Plan 1.

**Verification basis:** consolidated from a 5-dossier MAS research corpus (2×GPT,
2×Gemini, 1 Claude synthesis), then re-verified 2026-07-03 against:

- goose clone `.research-clones/work/goose` @ `8b1d500` — 14/14 embedding claims
  checked in source. [VERIFIED-CODE]
- June clone `.research-clones/june` @ `a626597` (2026-07-01,
  `open-software-network/os-june`) — Tauri + Hermes-framework agent confirmed.
- **The Epistemos repo itself** — the private MAS canon + scaffold the research models
  could not read: `docs/research/GOOSE_MAS_BUILD_CANON_2026_06_30.md`,
  `GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`, `GooseRuntimeSupervisor.swift`,
  `GooseInProcessACPServer.swift`, `GooseMASAgentCoreCatalog.swift`,
  `agent_core/src/bridge.rs`. [VERIFIED-CODE]
- Web: Apple FoundationModels WWDC26 (AFM 3 / `LanguageModel` protocol / image input,
  macOS 26 floor).

**Raw research corpus (provenance only — contains corrected errors, never build from
it):** `docs/research/MAS_RESEARCH_CORPUS_RAW_2026_07_03.md`.

---

## §0 LOCKED OWNER DECISIONS

1. **This is the MAS build** (Epistemos-AppStore scheme, `EPISTEMOS_APP_STORE` +
   `MAS_SANDBOX` compile flags — both already exist). App Sandbox + hardened runtime.
   **No subprocess, no helper binary, no local server binary, no `goosed`, no Ollama,
   no `llama-cli`.** OpenChamber/OpenCode/browser-use are Pro-only — never here.
2. **Two deliberately different surfaces, one brand:**
   - **Surface A — Quick Chat ("answer me"):** the restored wave/click-to-search
     landing chat. Local-only, free, no account. Engines: Apple Foundation Models
     (zero-download, availability-gated) + embedded llama.cpp GGUF (opt-in download).
   - **Surface B — June Agent Workspace ("do this for me"):** a deliberate,
     visually distinct workspace. Engine: **`agent_core` in-process** driving CLOUD
     models through the receipt-gated Epistemos proxy. Paid tier.
   - Anti-mixing is a hard rule (§3.4): different entry, layout, density, verbs.
3. **The MAS "goose engine" = `agent_core`** (owner canon, verified at
   `GOOSE_MAS_BUILD_CANON_2026_06_30.md:151-160`): "Epistemos's MAS path uses
   `agent_core` (your own in-process Rust runtime)." Embedding Block's `goose` crate
   is the **documented, source-validated fallback** (§Appendix) — not the plan.
   All five research dossiers assumed the goose-crate path; they are redirected here.
4. **June = design grammar + measurable reference, not a code donor.** Verified: os-june
   is Tauri + web frontend + Hermes-framework agent — zero portable SwiftUI. Surface B
   is **native SwiftUI in June's visual language**, measured from `.research-clones/june`
   (same source as the Pro track's bar + gradient).
5. **Money:** free = everything local (ungated). Paid = Surface B cloud agent via
   StoreKit 2 → proxy verify → short-lived token. **No provider API keys in the
   binary, ever** (proxy holds them; tokens in Keychain).
6. **Capability truth:** MAS's bounded tool set is shown honestly ("bounded on MAS"),
   never faked, never silently empty. Pro-only tools are absent, not greyed lies.

---

## §1 VERIFIED SCAFFOLD REALITY (what already exists — reuse, don't rebuild)

The scaffold is **~80% of Surface B's engine**, further along than our own status notes
claimed. Verified in-repo [VERIFIED-CODE]:

| Piece | Where | State |
|---|---|---|
| MAS in-process path gate | `GooseRuntimeSupervisor.swift:191-208` — `#if EPISTEMOS_APP_STORE` + env `EPISTEMOS_MAS_GOOSE_V0 == "1"` | Real, owner-off by default |
| In-process runner | `runInProcessAgentCore` (`GooseRuntimeSupervisor.swift:269-313`) → `GooseInProcessACPServer.swift:35-116` → `GooseMASAgentCoreRunner.streamGooseMASAgentCoreRun()` → **`runAgentSession()` agent_core FFI** | **REAL loop, not a stub** (the "loop unwired" note in memory/retired-plan was stale) |
| Agent loop FFI | `agent_core/src/bridge.rs:938-984` `run_agent_session(session_id, objective, provider_name, tool_config, agent_config, delegate)` → `AgentResultFFI` | Mature |
| Streaming events | `AgentEventDelegate` (bridge.rs:83-180): `on_thinking_delta`, `on_text_delta`, `on_tool_input_delta`, `on_tool_started`, `on_tool_completed`, **`on_permission_required`**, `on_context_compacting`, `on_turn_started`, `on_complete` | The complete Surface-B event vocabulary already exists |
| Capability catalog | `GooseMASAgentCoreCatalog.swift` ← `gooseMasAcpCatalogJson()` FFI: `providers[]`, `extensions[]`, `proGatedCapabilities[]`, per-provider `masBounded`, `policyProfile: "mas_sandbox"` | Wired, structured |
| FFI plumbing | UniFFI 0.29.5 (tokio), `crate-type = ["cdylib","staticlib","rlib"]`, `#if canImport(agent_coreFFI)` | Standard in-repo; callbacks must hop `DispatchQueue.main.async`, never `.sync` |
| Providers | `instantiate_provider()` (bridge.rs ~997-1050): Claude/OpenAI/Gemini/Perplexity over reqwest HTTPS; `ToolRegistry` with tier gating (`chat_lite`/`chat_pro`/`agent`/`full`) + per-tool allowlist | Reuse for the proxy wiring |
| Surface A restore target | git tag `checkpoint-2026-03-20-landing-chat` → `9aa497bc6`; commit `8ba7ff61cb` "Add ASCII ripple UI accents" | Both reachable — restorable |

**What does NOT exist and is genuinely new work:**
1. **Embedded llama.cpp.** The only GGUF path today is `run_local_gguf_generation` →
   `GgufCliProvider` which **spawns `llama-cli` (subprocess — Pro-only, MAS-illegal)**.
   Surface A's local-model lane must be built as a linked library (§2.1).
2. **Surface B's native June-style workspace UI** (§3.3).
3. **Proxy provider + StoreKit token flow** (§5) — providers exist; the receipt-gated
   endpoint/token rotation does not.
4. Surface A's Apple FM integration in the chat path (FoundationModels is already
   linked/used in the MarkEdit editor package for completions — the framework
   integration precedent exists in-repo, not in the chat lane).

**Simplification unlocked by the native decision:** the canon's transport debate
(loopback `WorkSPAServer` + `network.server` vs `WKScriptMessageHandlerWithReply`) was
about serving a WEB surface. With Surface B native SwiftUI, **Swift calls
`runAgentSession` + `AgentEventDelegate` directly over UniFFI — no ACP hop, no
loopback listener, no `network.server` entitlement at all.** `GooseInProcessACPServer`
stays as a validated asset for any future web client; it is off the critical path.

---

## §2 SURFACE A — WAVE QUICK CHAT (local, free)

### 2.1 Engines

- **Default when available: Apple Foundation Models** (`import FoundationModels`,
  **macOS 26+ only**). Real API: `SystemLanguageModel.default.availability`
  (`.available` / `.unavailable(.deviceNotEligible | .appleIntelligenceNotEnabled |
  .modelNotReady)`), `LanguageModelSession(model:tools:)`, `session.respond` /
  `streamResponse`, `@Generable`/`@Guide`. AFM 3 Core = 3B on-device (summarize/
  extract/rewrite — NOT parametric world knowledge); WWDC26 adds image input (AFM 3
  Core Advanced tier only — availability-gate it) and a `LanguageModel` protocol.
  **Guardrails throw on legitimate scholarly content sometimes (medicine/conflict/
  sexuality)** — catch `guardrailViolation` and fall back to the GGUF lane.
  Roughly half the Mac base can't run macOS 26 in mid-2026 → FM is the enhancement,
  **GGUF is the reliability floor.**
- **Opt-in stronger local: embedded llama.cpp.** Pin an upstream **XCFramework release**
  (`llama-b<NNNN>-xcframework.zip`, SPM `binaryTarget` + checksum) or build with the
  current flags: `BUILD_SHARED_LIBS=OFF`, `GGML_METAL=ON` (default on macOS),
  **`GGML_METAL_EMBED_LIBRARY=ON`** (embeds the metallib — kills the sandbox
  path-resolution problem), `LLAMA_BUILD_SERVER=OFF`, examples/tests off. Current C
  API: `llama_model_load_from_file` + `llama_init_from_model` (old names deprecated).
  Thin Swift/ObjC++ façade exposing only load/unload, context, token stream, cancel,
  window accounting. **Apple Silicon only** (this app never shipped Intel).
  **No JIT / unsigned-executable-memory / disable-library-validation entitlements** —
  Metal shader compilation happens in system driver processes (PocketPal/Private LLM
  precedent); verify once on a release-signed build before submission.
- GGUF storage: app container `Application Support` (self-contained, no bookmarks
  needed); security-scoped bookmarks only for user-imported model files.
  Atomic download + checksum + resume; delete-on-corrupt.

### 2.2 Model set — CORRECTED by KV-cache math (supersedes the earlier Qwen2.5/Phi pick)

KV/token = `2 × layers × kv_heads × head_dim × 2 bytes` (FP16):

| Model | KV heads | KV/token | Q4_K_M size | 16 GB (~10.5 GB usable) verdict | License |
|---|---|---|---|---|---|
| **Qwen3-4B-Instruct** — **default download** | 8 (GQA) | ~147 KB | ~2.5 GB | Best quality-per-GB for a reading app; generous context headroom | Apache-2.0 |
| **Qwen3-8B** — stronger opt-in | 8 (GQA) | ~147 KB | ~5 GB | Comfortable; the 7B-class flagship | Apache-2.0 |
| Qwen2.5-7B-Instruct — long-doc alternative | **4** (GQA) | **~56 KB** (lowest) | 4.68 GB | 32K comfortable, 40K+ possible — uniquely strong for max-context reading | Apache-2.0 |
| Qwen2.5-14B | 8 (GQA) | ~192 KB | 8.99 GB | ~4-8K only — label "short context" or drop from v1 | Apache-2.0 |
| ~~Phi-3.5-mini~~ | **32 (dense MHA)** | **~384 KB** | ~2.3 GB | **REJECTED as long-doc option** — 6.9× Qwen-7B's KV/token; small weights hide a KV trap | MIT |

Rules: RAM-gate at launch (`ProcessInfo.physicalMemory`, keep ≥4.5 GB system head-
room); when extracted-text + reply budget exceeds the safe window, **refuse gracefully
and offer chunked reading** — never limp into swap. Honest copy: "a paper fits; a
book needs chunking." Catalog stays Apache-2.0/MIT only (no HF license-acceptance
gating in the downloader).

### 2.3 Surface A UI + the MLX retirement

UI = restore the click-to-search wave landing chat from `9aa497bc6` /
`8ba7ff61cb` (verified reachable), modernized onto current theme tokens. Single calm
column; verbs: ask/summarize/explain; **zero agent furniture, zero model egress** —
a compliance asset (demonstrably local).
The MLX lane (`MLXInferenceService` + mlx-swift) is **retired by owner decision
(2026-07-02)** — llama.cpp embedded + Apple FM replace it. Removal is its own
workstream: land Surface A's llama.cpp lane FIRST, prove parity, then delete MLX in a
separate commit series (never mid-feature).

---

## §3 SURFACE B — JUNE AGENT WORKSPACE (cloud, paid)

### 3.1 Engine wiring (reuse §1)

Native SwiftUI drives `agent_core` directly: `runAgentSession` per turn with
`CancellationToken`-style stop, `AgentEventDelegate` → `@Observable` view state
(main-actor hop via `DispatchQueue.main.async` — never `.sync`). Provider =
"epistemos-cloud": the existing provider stack pointed at the proxy base URL with the
short-lived token as bearer; token rotation re-instantiates the provider config.
Session persistence in the app container (existing agent_core session store).

### 3.2 MAS tool catalog (from the canon — hard-coded, no runtime extensibility)

**Allowed:** vault I/O via security-scoped bookmarks; in-app capabilities (PDF→md,
search/graph/provenance); **HTTP MCP over a fixed HTTPS allowlist** (never stdio);
cloud model calls via the proxy.
**Forbidden on MAS (Pro-only, per Guideline 2.5.2):** `cli_passthrough`, `terminal`,
bash `registry`, `stdio_mcp`, `imessage`, `apple`/osascript, `code_execution`,
schedules/extension-installer UI (no `goose://` deeplinks, no "add MCP server").
The catalog's `proGatedCapabilities[]` + `masBounded` flags already model this —
wire the Swift-side guard so absent tools are *absent*, with one honest "bounded on
MAS" explainer.

### 3.3 Workspace furniture (native SwiftUI, June's visual language)

Multi-pane: session/step rail (transcript of turns + steps) · center activity feed ·
right editable document pane. Cards mapped 1:1 to the verified delegate events:
thinking block (collapsible, streams `on_thinking_delta`), tool card with status
transitions (`on_tool_started`/`on_tool_completed`), **approval sheet** blocking on
`on_permission_required` (Approve/Deny round-trip), live text deltas, source/citation
rail, cancel control, session timeline. Measure spacing/warmth/radii from
`.research-clones/june` — grammar only; no web components ported.
**Companion/mascot hook (Plan 5 owns the implementation):** reserve the static+emotive
mascot slot on Surface B's header + the landing, per the product-shape canon (mascot
visible on the agent surface / editors / landing, and on any surface where the agent is
actively working). Plan 1 ships the slot; Plan 5 ships the mascot.

### 3.4 Anti-mixing rules (hard)

| Axis | A — Quick Chat | B — June Workspace |
|---|---|---|
| Entry | default landing | deliberate button/destination |
| Verbs | ask · summarize · explain | do · research · revise · approve |
| Layout / density | one calm column, sparse | multi-pane, dense, stateful |
| Agent furniture | none | always visible (steps/tools/approvals) |
| Engine / network | local only, no model egress | agent_core → proxy HTTPS only |
| Account | none | subscription |

---

## §4 COMPLIANCE + PACKAGING

Entitlements: `app-sandbox` ✓ · `network.client` ✓ (proxy + model downloads) ·
`files.user-selected.read-write` + `files.bookmarks.app-scope` ✓ · **`network.server`
NOT set** (native surface needs no loopback) · **no** JIT / unsigned-exec-memory /
disable-library-validation. Hardened runtime via the MAS pipeline.
**⚠️ Concrete cleanup [VERIFIED-CODE]:** the CURRENT `Epistemos-AppStore.entitlements`
already declares **`cs.allow-jit` (MLX legacy)** and **`network.server` (old loopback
plan)** — **REMOVE BOTH in Phase 5.** llama.cpp's Metal path needs no JIT and the
native surface needs no server socket; shipping without them is a review win.

- **2.5.2 (weights = data):** GGUF files are data parsed by the bundled, signed
  inference engine — no downloaded code, no helpers, no shared locations. Review
  notes state exactly that (PocketPal AI / Private LLM precedent). Store weights in
  the container, never in `Contents/Frameworks`.
- **5.1.2(i) third-party-AI consent (Nov-2025 rule, from the canon — the research
  corpus mostly missed it):** explicit user permission BEFORE the first byte of
  vault/personal data reaches a cloud provider, per provider. Build the consent
  interstitial into Surface B's first-run and provider switches.
- **2.4.5:** self-contained bundle, sandboxed, no auto-launch background persistence.
- WKWebView is NOT itself a rejection risk (the app already ships WKWebView editors
  on MAS) — Surface B is native by owner choice + robustness, not compliance fear.
- Keys: proxy session tokens in Keychain; provider keys exist only server-side.

## §5 PAYWALL + PROXY

StoreKit 2 purchase → app sends the JWS-signed `Transaction` to the proxy → proxy
verifies via App Store Server API (.p8 key server-side; validate x5c chain) → issues a
short-lived token → every Surface B request carries it → App Store Server
Notifications V2 drive renewals/cancellations/refunds (respond 2xx promptly,
idempotent; retry behavior changed ~March 2026). Bind purchases with
`appAccountToken` for proxy rate-limiting. Free lane needs no gate at all.
verifyReceipt is deprecated — don't use it.

## §6 CORRECTIONS LOG (research-corpus claims overruled — do not resurrect)

1. ~~MAS engine = embed Block's `goose` crate~~ (all 5 dossiers) → **engine =
   `agent_core`** per owner canon; goose-crate embedding = validated fallback only.
2. ~~`goose-sdk` does not exist~~ (Claude synthesis) → it **exists** at
   `crates/goose-sdk` (UniFFI ping/pong scaffold) in the verified clone. Moot for the
   chosen path, but the synthesis's "correction" was itself wrong.
3. `AgentEvent` has **4** variants (`Message`, `McpNotification`, `HistoryReplaced`,
   **`Usage`**) — synthesis said 3. Sub-recipes run **in-process** (`RecipeHandler`),
   not via a `goose run` subprocess. `AgentManager::instance()` is real.
4. ~~Apple FM on macOS 15 / `import LanguageModels` / `generateText(replyingTo:)`~~
   (Gemini-2) → hallucinated. Real: **macOS 26**, `FoundationModels`,
   `SystemLanguageModel.default`, `LanguageModelSession.respond/streamResponse`.
5. ~~Phi-3.5-mini = long-context champion (32-64K headroom)~~ (GPT-1) → wrong; 32
   dense MHA KV heads ⇒ ~384 KB/token. Corrected model set in §2.2 (supersedes the
   owner's earlier Qwen2.5/Phi shortlist too).
6. ~~June unverifiable / June = portable workspace components~~ → June is real,
   local, **Tauri + Hermes-framework** (verified clone) — design reference only.
7. ~~"real agent_core loop still unwired"~~ (our own retired-plan note) → stale; the
   runner calls `runAgentSession` today and the catalog FFI returns real structure.
8. ~~Legacy llama.cpp flags (`LLAMA_STATIC`, `LLAMA_METAL`), universal
   arm64+x86_64~~ (Gemini-1) → current `GGML_*` flags (§2.1), Apple Silicon only.
9. ~~Loopback ACP server + `network.server` entitlement required~~ → not with a
   native Surface B; direct UniFFI. (Canon's transport correction already preferred
   script-message over loopback; native makes both moot.)
10. ~~WKWebView risks 4.2.2 rejection~~ (Gemini-2) → overblown; irrelevant anyway
    (native chosen).

## §7 PHASES

- **Phase 0 — De-risk spike (2 proofs, AppStore scheme):** (a) llama.cpp XCFramework
  + Metal generating tokens inside the sandbox on a release-signed build with zero
  forbidden entitlements; (b) `EPISTEMOS_MAS_GOOSE_V0=1` end-to-end `runAgentSession`
  turn streaming deltas into a stub view.
- **Phase 1 — Surface A:** restore wave chat (`9aa497bc6`); Apple FM
  availability-gated + guardrail fallback; GGUF download/load lane (Qwen3-4B
  default); RAM gating + chunking refusal. Ship-able alone.
- **Phase 2 — MLX retirement:** delete the MLX lane after parity (separate commits).
- **Phase 3 — Paywall:** StoreKit 2 + proxy + short-lived tokens + Notifications V2.
- **Phase 4 — Surface B:** native June-style workspace on the verified delegate
  events; MAS tool allowlist + 5.1.2(i) consent; approvals; session timeline.
- **Phase 5 — Hardening + submission:** entitlement audit, review notes (weights =
  data; two-surface split; no subprocess), OOM soak on 16 GB, offline behavior.

## §8 FEATURE LEDGER (shipping gate)

| Capability | Surface | Engine | MAS legality |
|---|---|---|---|
| Zero-download chat | A | Apple FM (macOS 26+, gated) | ✓ first-party |
| Stronger local chat / long-doc reading | A | embedded llama.cpp + GGUF | ✓ weights=data |
| Model download manager (checksum/resume/RAM-gate) | A | app | ✓ |
| Multi-step cloud agent | B | agent_core → proxy | ✓ in-process, paywalled |
| Thinking/tool/approval stream | B | `AgentEventDelegate` | ✓ |
| Agent doc editing + vault access | B | agent_core tools + bookmarks | ✓ |
| HTTP MCP (fixed allowlist) | B | agent_core | ✓ (never stdio) |
| Subscription gate | B | StoreKit 2 + proxy | ✓ |
| `goosed` / Ollama / `llama-cli` / stdio MCP / terminal / code-exec / schedules UI | — | — | ✗ Pro-only, excluded |

## §9 OPEN QUESTIONS (defaults in place — build proceeds)

1. Final model catalog → **default: Qwen3-4B + Qwen3-8B + Qwen2.5-7B(long-doc);
   14B deferred; Phi dropped.**
2. First-run: FM-if-available vs always-offer-download → **default: FM instantly
   when available, quiet "stronger local model" upsell.**
3. Surface B v1 tool scope → **default: vault read/write + PDF→md + search/cite +
   doc editing; everything network-ish behind approval.**
4. MLX deletion timing → **default: Phase 2, after Surface A parity.**
5. Keyring vs container secrets for the proxy token → **default: Keychain
   (existing pattern).**

## §Appendix — Block goose crate: validated fallback (not chosen)

If `agent_core` ever falls short, embedding `crates/goose` is source-proven at
`8b1d500`: `default = []` features; pure `Agent::reply` spawns nothing/binds nothing
with extensions=[] + `scheduler_service=None` + no container; `AgentConfig::new(6
params)`; `update_provider` + `from_custom_config` (OPENAI_HOST/CUSTOM_HEADERS) for
the proxy; `ToolConfirmationRouter` oneshot approvals; `GOOSE_PATH_ROOT` +
`GOOSE_DISABLE_KEYRING` for container scoping; `goose-sdk` UniFFI scaffold to extend;
ACP-in-core (`SessionType::Acp`) as the future stable boundary. Riskiest hazard:
non-empty extension config spawns MCP stdio children — validate extensions=[] at
construction.

## §10 GUARDRAILS

- Never spawn anything on the MAS path; never enable `network.server`; never request
  JIT/exec-memory entitlements without a proven release-signed failure.
- Keys/tokens in Keychain, never UserDefaults; provider keys never in the binary.
- Swift changes: isolated-DerivedData `xcodebuild` (AppStore scheme too),
  `CODE_SIGNING_ALLOWED=NO`, BUILD SUCCEEDED before commit; never two builds at once.
- Never `git add -A`; never commit `.research-clones/`; no worktrees.
- UniFFI callbacks hop to main via `async`, never `.sync`.
- Don't touch the Pro/OpenChamber track, the graph, or the editors from this track.

---

## §11 BUILD RUNBOOK (start here — decisions pre-made)

**R1. Phase-0 spike A — llama.cpp in the sandbox.** SPM binaryTarget against a pinned
upstream release:
`.binaryTarget(name: "llama", url: "https://github.com/ggml-org/llama.cpp/releases/
download/b<NNNN>/llama-b<NNNN>-xcframework.zip", checksum: "<sha256>")` — or build
locally with the §2.1 flags. Write ONE façade protocol and nothing more:
`LocalChatEngine { load(modelURL, contextTokens) · stream(prompt, onToken) · cancel() ·
unload() }` wrapping `llama_model_load_from_file` + `llama_init_from_model`. Prove it
on the **Epistemos-AppStore scheme, release-signed, with `cs.allow-jit` already
REMOVED** — that's the whole point of the spike.

**R2. Phase-0 spike B — one agent_core turn.** `EPISTEMOS_MAS_GOOSE_V0=1` on the
AppStore scheme; drive `GooseMASAgentCoreRunner.streamGooseMASAgentCoreRun()`
(`GooseInProcessACPServer.swift:49-114`) or call `runAgentSession` directly; assert
`on_text_delta`/`on_thinking_delta` arrive and render on the main actor.

**R3. Surface A restore — exact files [VERIFIED-CODE]:** from `9aa497bc6`
(tag `checkpoint-2026-03-20-landing-chat`):
- `Epistemos/Views/Landing/LandingView.swift` + `LiquidGreeting.swift` — still on HEAD:
  **diff against the checkpoint, don't clobber.**
- DELETED since (restore via `git show 9aa497bc6:<path> > <path>`):
  `Epistemos/Views/Landing/CommandPaletteOverlay.swift`,
  `CommandPaletteWindowController.swift`, `Epistemos/Views/Chat/{ChatView,
  ChatInputBar, MessageBubble}.swift`, `Epistemos/Views/MiniChat/{MiniChatView,
  MiniChatWindowController}.swift` (MiniChat optional).
- From `8ba7ff61cb`: `Epistemos/Theme/PhysicsModifiers.swift` (+298 lines — the ASCII
  ripple accents) + its `LiquidGreeting` delta.
Expect API drift (SDChat/theme tokens have moved since March) — treat restored files as
source material and compile-fix forward, wiring generation to the §2 engines instead of
the old inference path.

**R4. Proxy contract (server work, parallelizable):**
`POST /v1/auth/verify-receipt {storekit_jws}` → verify via App Store Server API →
`{token, expiresAt}`; `POST /v1/chat/completions` (OpenAI-compatible,
`Authorization: Bearer <token>`) → SSE; App Store Server Notifications V2 webhook →
revoke/refresh entitlement. Client: token in Keychain, refresh below ~20% TTL;
agent_core's provider config points at the proxy base URL (existing provider stack).

**R5. Phase acceptance:** P0 = both spikes green (GGUF tokens sandboxed without JIT;
delta stream from agent_core). P1 = wave chat answers locally — Apple FM when
available, GGUF fallback proven, `guardrailViolation` fallback proven on one flagged
prompt, RAM gate refuses an oversized load gracefully. P3 = sandbox-StoreKit purchase →
token → cloud turn end-to-end. P4 = approval sheet blocks a tool; bounded-tools
explainer visible; 5.1.2(i) consent sheet appears before the first cloud send. Each
phase ends in a commit + an owner-visual checkpoint.

---

## §12 CARRY-FORWARD — instant-open (owner-loved; PRESERVE, adapted for native)

The current goose surface opens **instantly** when clicked (recipe in
`Epistemos/Goose/GooseWebSurfaceView.swift` + `GooseRuntimeSupervisor.swift`) — the owner
wants that felt-speed kept. MAS is **native SwiftUI**, so some mechanisms change shape, but
the principle carries fully: **never block the main actor, keep the expensive thing warm,
show a loading state — never a hang.**

- **Native views are already instant.** Surface A (wave chat) + Surface B (native
  workspace) render immediately — no WebView, no server to boot. Don't add either.
- **The expensive resource is the LOCAL MODEL, not the UI.** Apple Foundation Models is
  **zero-load (instant)** — so Surface A defaulting to Apple FM when available IS the
  instant-open path. The llama.cpp GGUF lane is the only heavy load.
- **#2 off-main init (KEEP — load-bearing).** Init `agent_core` and load any GGUF model in
  `Task.detached(.userInitiated)`, NEVER on `@MainActor` — same reason the goose spawn had
  to move off-main (`GooseRuntimeSupervisor.swift:421-427`): heavy init / signature
  validation freezes the UI inline.
- **#3 lazy on first appear (KEEP).** Start the agent_core session / model load from
  `.task` on the surface, not at app launch.
- **#4 loading state, not a hang (KEEP).** While the model loads or agent_core inits, show
  a warm loading view (the wave landing itself, or a shimmer); poll readiness, then swap in
  the live surface — mirror `loadWhenReady` (`GooseWebSurfaceView.swift:446-472`).
- **#5 keep the runtime + model WARM across tab switches (KEEP — the native analog of
  WebView keep-alive).** Do NOT unload the GGUF model or tear down the agent_core session
  when the user switches away from Agent and back — only pause. Re-entering is instant
  because the model is already resident. (Respect the existing idle-unload memory-pressure
  policy: warm on tab-switch, unload only under real pressure.)
- **#6 inject-at-render (KEEP).** Inject theme/config at render time; preload static assets
  into memory; no per-open disk walk.

Net: Surface A is instant by leaning on Apple FM (zero-load) with a warm GGUF fallback that
survives tab-switches; Surface B is instant because it's native + a warm in-process
agent_core. Same felt-speed as goose today, achieved natively.

**Full perf canon (READ-FIRST):** `docs/research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
— §3 (app-side/native: off-main, warm-model invariant, shared process pool, memory-pressure
handlers, lazy-init) + §5 (perf is a per-phase gate). Budgets in `docs/perf-budgets.toml`
`[agent_surface]` (esp. `mas_model_retained_on_switch = 1` — the GGUF model MUST stay
resident across an Agent tab-switch; unloading on switch is a regression). MAS's agent
surface is native (no web bundle), so §2 web-side rules apply only to the app's editor/
KaTeX WebViews, not here. A perf regression blocks the phase commit like a broken build.

---

## §13 HARDENING (baked in, per-phase gate — READ-FIRST `AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`)

Each phase ends with a bounded four-lens hardening pass (security · memory-leak · data-leak ·
robustness/fluidity) reported thermonuclear-shape; a HIGH blocks the phase commit. This
surface's specific top risks:
1. **FFI truth boundary** (doctrine §2 — the historical #1 flaw): verify `agent_core`'s panic
   strategy vs its unwinding assumption so no Rust panic SIGTRAPs the process across UniFFI;
   `mem::forget` extracted payloads. UniFFI callbacks hop main via `async`, never `.sync`.
2. **llama.cpp OOM guard:** the RAM gate must refuse an oversized model/context load gracefully
   (never limp into swap or crash); model unloads under memory pressure; keep-warm on
   tab-switch is the perf invariant, unload only under real pressure.
3. **Supervision, not polling** of the in-process runtime + honest `.failed` states;
   circuit breaker (ring buffer, N-consecutive half-open) on the cloud proxy; thermal pause =
   breaker no-op; Apple FM `guardrailViolation` → GGUF fallback (already core).
4. **Ingest = untrusted input** (doctrine §3C): a malformed receipt/PDF/CSV must not crash the
   parser or corrupt a table; OCR'd/parsed text is DATA the agent never executes; provenance on
   every ingested record; the instruction-source boundary on the Data/chat agent.
5. **Secrets in Keychain**, provider keys server-side only; parameterized SQL for any GRDB the
   surface adds. Every unsafe block `// SAFETY:`; no `try!`/force-unwrap/`print()` in prod.
   Perf AND hardening HIGHs both block the commit.
