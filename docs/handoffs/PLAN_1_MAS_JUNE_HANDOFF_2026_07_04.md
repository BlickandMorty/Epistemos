# PLAN 1 (MAS) — June Agent Surface — Handoff (2026-07-04)

> **For an unbounded successor agent.** This is the MAS/June track: the vendored
> June web UI in a WKWebView, backed in-process by Epistemos engines, presented
> as the App Store build's Agent room. It is **feature-complete, exhaustively
> hardened, and green-built.** What remains is genuinely *gated* (an in-app
> audio witness, and Phase-4 owner work) — not more code you can write today.
> Read this before touching anything; then read `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
> (the plan) and the two Goose-MAS canon docs referenced in §7.

---

## 0. SCOPE (hard boundaries — do not cross)

**Yours:** `Epistemos/JuneAgent/*`, the fork overlay `~/dev/june-epistemos/epistemos/*`
(shim + spike — overlay ONLY, never June's `src/`), `build-june-web.sh`,
`bundle_june_web()` in `bundle-app-runtime-assets.sh`, and the smallest-additive
shared-file branches you already own: `LandingView` `.agent` MAS side,
`RootView` MAS pill branch, `SubstrateHealthPanel` `JuneAgentHealthRow`.

**Not yours:** June upstream `src/`, the Pro/OpenChamber track, the graph, the
editors, `Epistemos/VoicePro/*`, `EpistemosSpeechSynthesizer` (consume, never
edit), `agent_core` (Rust), the Goose track (`Epistemos/Goose/*`). No new
shared-file surface without a sibling note. Never `git add -A` — the repo tree
has 40-50 concurrent files from other agents; stage only your files by path.

---

## 1. WHAT SHIPS (the architecture in one screen)

- **Surface:** June's real Vite/React web build (pinned fork @ `a626597`) runs in
  a `WKWebView` served over a custom `june://` scheme (file:// silently
  CORS-blocks ES-module scripts). One process-lifetime webview
  (`JuneAgentSurfaceHolder`) = instant reopen across tab switches, no reload.
- **Bridge (June JS → native):** a Tauri-internals **shim**
  (`epistemos/tauri-internals-shim.js`) polyfills `window.__TAURI_INTERNALS__`,
  routing `invoke()` and the Hermes gateway WebSocket to native
  `WKScriptMessageHandler` channels (`epistemosInvoke` / `epistemosGateway` /
  `epistemosEvents` / `epistemosConsole` / `epistemosSpeak`). Host mode is flagged
  by `window.__EPISTEMOS_HOST__`.
- **Gateway (`JuneAgentGateway`):** answers June's Hermes JSON-RPC (`ping`,
  `session.create/resume`, `prompt.submit`, `session.interrupt`) and streams
  `message.delta`/`message.complete` back. Owns the durable `JuneSessionStore`.
- **Engines (in-process, MAS-legal):**
  - **Local (free, ungated):** `AppleFMQuickChatBackend` (Apple Foundation
    Models; guardrail trip falls back to GGUF) + `LocalGGUFQuickChatBackend`
    (embedded llama.cpp via `EpistemosLlama`, in-process linked lib — NOT the
    pro-build subprocess). Chat tier. Conversation history folded into system
    instructions.
  - **Cloud (paid):** `JuneCloudEngine` → receipt-gated proxy
    (`EpistemosProxyClient`), OpenAI-compatible SSE, real role-tagged
    system+history array. Honest-gated: no Keychain session → `notSubscribed`.
- **Scheme gating:** everything is `#if EPISTEMOS_APP_STORE`.

Data flow is one clean source of truth: **the store** feeds both June's
displayed transcript AND the engines' conversation context AND the native
all-chats/read-latest — resume, relaunch, titles, history all reconnect from it.

---

## 2. WHAT'S DONE + COMMITTED (Epistemos, `mas-agent` commits)

| SHA | What |
|---|---|
| `e96f068f2` | Release the June-warmed GGUF model under **critical memory pressure** (wired the zero-caller `unloadForMemoryPressure` into `performMemoryPressureRelief`) |
| `5ebec3a5f` | Remove dead `JuneAgentIntents.openSettings` (zero-caller) |
| `813af1923` | **Local model picker**: June shows/downloads/switches all catalog GGUF (Qwen3-4B/8B, Qwen2.5-7B) + **store corruption-quarantine** (`decodeOrQuarantine`) |
| `a5a7854fc` | **All-chats** delete + search |
| `5b69e6d1b` | **Read-aloud** (read-latest + per-message + selected-text) |
| `b28659021` | Scheme handler concurrent asset reads (faster cold-open) |
| `7efad0a3a` | `build-june-web.sh` excludes `*.map` (no source-map / June-source leak) |
| `da81a8cbc` | `JuneWebAssets` env override + dev-fork **DEBUG-only** (RELEASE loads bundled signed UI only; 2.5.2) |
| `4727ef16c` | Read-aloud selection pill dark-mode border + keyboard-deselect dismissal |
| `87e63c118` | All-chats **delete confirmation** + **current-session highlight** |
| `497b9e653` | Read-aloud bound to engine's own TTS input cap (full-length replies) |
| `f22d333f6` | Read-aloud overlay robustness: survives **React re-renders** + **live TTS availability** (no restart) |

Earlier landed (engine depth, free-lane, titles, history): see the memory ledger
`plan1-mas-june-loop-state` — 3 disconnections fixed (agent amnesia → history on
both lanes; title drift → store self-titles; fragile free-lane gate → subscription
omitted so June's funding gate can't paywall local), plus trust-boundary
hardening (session-id allowlist, concurrent-turn cap 8, 512KB response cap,
suggest-title prompt cap).

**Fork overlay commits:** shim host-mode routing (`fa443b0b`), gateway bridge +
full-turn spike (`f86d8331`), menu-bar forwarding (`2f84f3e4`), host-invoke
timeout (`66d94a6c`), CSP parity (`10c40f0a`), free-lane witness (`185af29a`),
**read-aloud selector witness (`eb0f6952`)**.

---

## 3. READ-ALOUD (the last feature; fully wired)

Consumes `EpistemosSpeechSynthesizer.shared` (**never edited** — owned by the
app-wide voice agent). Audio synthesized **native-side only**; zero audio/voice
code in the webview. Voice = the user's `ModelVoicePickerSection` pick
(`voiceIdentifier: nil`, never hardcoded). Honest gate at UI + engine:
`isTextToSpeechAvailable()` / `textToSpeechStatusMessage()`; `speak()` refuses
when Kokoro isn't ready — **no AVSpeech fallback, no fake**.

Three affordances:
1. **Read latest** — native speaker button in `JuneAgentNavBar`; reads
   `gateway.latestAssistantReply()` (the *shown* session via `currentSessionID`,
   fallback most-recent, cleared on delete); toggles speaker⇄stop.
2. **Per-message** — overlay-injected button into each assistant turn's own
   `.agent-turn-actions-inner` (appears on hover, native to June); reads
   `.agent-assistant-turn-body`; posts `{action:"speak",text}` to `epistemosSpeak`.
3. **Selected text** — floating pill on any selection posts `getSelection()`.

Robustness in the overlay (`JuneAgentSurfaceView` inline userScript): `MutationObserver`
re-adds the button if React reconciliation drops it (removedNodes handling);
`ttsReady()` is a **live** gate + `__EPISTEMOS_READALOUD_REFRESH__` is re-pushed
from the surface `.onAppear` so read-aloud appears the moment the voice installs
mid-session; pill is React-safe (appended to `document.body`, outside `#root`).

**Web-side witnessed** (spike `eb0f6952`): `--host-send` confirms
`.agent-assistant-turn`/`.agent-turn-actions-inner`/`.agent-assistant-turn-body`
exist in June's rendered DOM → the overlay injects correctly. **Only the native
audio remains un-witnessed** (no Kokoro in the spike) — that is the in-app item (§5).

---

## 4. HARDENING — four-lens, complete across every file

- **Security:** `june://` traversal-confined + CSP + unlicensed-font 404;
  `jsStringLiteral` escapes both native→JS directions (`\`, `"`, `\n\r\t`,
  U+2028/9, all ctrl<0x20); inbound is `postMessage` (auto-serialized);
  webview config secure-default (no auto-popups, `window.open`→external or nil,
  never nested webview); session-id allowlist to `[A-Za-z0-9-]`; every input
  bounded (frame 1MB, speak = engine cap, prompt.submit 200KB, suggest-title
  4000, concurrent turns 8, response 512KB); RELEASE loads only bundled signed UI;
  no source maps shipped; no secrets/audio in webview JS (server-side/Keychain).
- **Memory:** process-lifetime holder; `runningTurns` Tasks removed on
  completion (weak self); no retain cycles (bridge→gateway→Task all weak);
  store = small structs + on-demand messages; GGUF unloads under critical pressure.
- **Data:** on-device TTS (no network); local sandboxed store; cloud sends only
  the user's own history to their own proxy.
- **Robustness:** frame validation + unknown-method→null; engine errors mapped
  (`describeEngineError`, honest `modelPreparing` while downloading); atomic
  writes + **corruption-quarantine** (`decodeOrQuarantine` moves a bad file
  aside, never overwrites); drift-proof session metadata (`messageCount` SET not
  ++); DOM/React overlay resilience; cancellation propagates (interrupt → engine
  cancel → `message.complete` cancelled).

---

## 5. WHAT REMAINS — GATED, with exact pointers

### 5.1 In-app audio witness (the ONE code-adjacent thing left; owner-gated)
The spike proves the web-side DOM; only the **native Kokoro audio** path is
un-witnessed. When you get a sandboxed MAS build + a release window:
- Cold-launch sandboxed (NOT Debug — Debug is non-sandboxed and lies).
- June loads → new session → prompt → click read-aloud → **HEAR** the reply in
  the user's voice. Confirm speaker⇄stop toggles.
- With the Kokoro voice **uninstalled**: the button shows unavailable /
  disabled with the honest status — **NOT** an AVSpeech fallback, NOT a fake.
- Confirm live behaviors: per-message button **persists across a re-render**;
  read-aloud **appears after a mid-session voice install** (no restart);
  all-chats **delete confirmation**, **current-session highlight**, **dark-mode
  pill** render correctly; model picker downloads + switches a GGUF.
- Blank/silent = a gap; instrument and fix, don't report done on a blank surface.

### 5.2 Phase-4 (owner-gated — needs StoreKit + a deployed proxy)
- **StoreKit 2 subscription** → mint the Keychain session token
  `JuneCloudEngine` requires. Until then cloud honestly throws `notSubscribed`
  and sends nothing.
- **⚠️ Guideline 5.1.2(i) consent (App Store REJECTION risk):** before the FIRST
  cloud send transmits conversation/personal data to a third-party AI, you MUST
  show an explicit consent UI naming the provider(s). Not needed today (no send
  path), MANDATORY when 5.1.2 wires. `requiresThirdPartyAIConsent` in the Goose
  track already exempts `local`/`mlx`/`foundation`/`apple` — mirror that shape.
- **Cloud proactive token refresh** (`EpistemosProxySession.needsRefresh`
  exists) — needs the StoreKit JWS source to `exchangeReceipt`. Current
  attempt-then-honest-401 is correct without a refresh source.
- **Per-cloud-model selection** — single proxy-resolved "Epistemos Cloud" entry
  is the plan design; a model list needs the deployed proxy to expose one.
- **Cloud tools + reasoning parts:** if a future cloud lane emits reasoning/tool
  parts, read-aloud must **exclude** `.agent-tool-stack` + the reasoning element
  before reading `.agent-assistant-turn-body` (today the gateway emits only
  answer deltas, so the body is answer-only — verified).

### 5.3 Optional goose-in-process LOCAL lane (owner said "nvm" 2026-07-04)
Feasibility spike (agent `ad5f8c54`) verdict: **in-process goose on MAS is
cloud-only today** — `agent_core` has NO in-process local provider (gguf is
`#[cfg(pro-build)]` subprocess; no MLX/Apple-FM provider). Making goose drive a
local model = "work X": add an in-process host-callback `AgentProvider` to
`agent_core` (mas-build) + a `goose_mas.rs` local entry + router arm + live
proof. **Cross-track (agent_core + Goose/PRO) — owner deferred it.** Do NOT
start without explicit owner re-approval + PRO coordination. The shipping local
lane is the QuickChat one (§1), which the owner endorsed.

---

## 6. BUILD & WITNESS DISCIPLINE (you WILL fight PRO for the slot)

- **Isolated DD:** `-derivedDataPath ~/.cache/epistemos-dd-mas`,
  `-scheme Epistemos-AppStore`, `CODE_SIGNING_ALLOWED=NO`. Gate on the literal
  `BUILD SUCCEEDED`.
- **NEVER `xcodebuild` while PRO's is running.** Use the **self-retrying
  wait-until-free wrapper** (background/nohup): wait for `pgrep -x xcodebuild`
  to clear, then wait for the shared FFI header
  `build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h` size to be **stable
  8s** (PRO regenerates it 100746↔103725 mid-build → stale-PCM), then
  `rm -rf $DD/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules`, then
  build; retry ≤6 on `"has been modified since the module file"`. (Reference the
  last wrapper in the loop transcript / memory cursor.)
- **Web-side witness:** `swiftc -O epistemos/spike/JuneSpikeHost.swift -o out` then
  `./out <fork>/dist <fork>/epistemos/tauri-internals-shim.js out.png 18 --host-send`
  → grep `SPIKE-PROBE`. Modes: `--send` / `--host-send` / `--host-intents`.
- **exit-144 environmental kills** hit long foreground Bash — run builds detached.

---

## 7. KEY FILES + CANON

- `Epistemos/JuneAgent/JuneAgentGateway.swift` — gateway + `JuneSessionStore` +
  model catalog + history composition (most-active file).
- `JuneAgentBridge.swift` — WKScriptMessageHandler channels + invoke table +
  `handleSpeak` + `jsStringLiteral`.
- `JuneAgentSurfaceView.swift` — webview config, userScripts (shim, TTS flag,
  read-aloud overlay), holder, reveal/focus, `JuneWebViewRepresentable`.
- `JuneAgentChrome.swift` — `JuneAgentIntents`, `JuneAgentActivityModel`,
  `JuneAllChatsSheet`, mascot hook.
- `JuneAgentNavBar.swift` — MAS pill + read-latest button.
- `JuneSchemeHandler.swift` / `JuneWebAssets.swift` — `june://` serving +
  bundle resolution.
- `JuneCloudEngine.swift` — cloud SSE client.
- Fork: `epistemos/tauri-internals-shim.js`, `epistemos/spike/JuneSpikeHost.swift`.
- **Canon:** `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`,
  `docs/research/GOOSE_MAS_BUILD_CANON_2026_06_30.md`,
  `docs/research/GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`.
- **Live ledger:** memory `plan1-mas-june-loop-state` (full audit trail).

---

## 8. RAILS (non-negotiable, MAS)

No subprocess / no socket / no `network.server` / no JIT-exec beyond declared
entitlements. Keys/tokens in Keychain, never the binary or webview JS. No audio
in webview JS. UniFFI/async callbacks hop to main via async, **never `.sync`**
(deadlock). Real APIs only, honest capability gating, no fake features. Don't
touch the Pro track. Commit per coherent step on `BUILD SUCCEEDED`.

*Handoff written 2026-07-04 at a clean, green-built HEAD (`f22d333f6`). The
surface is done to the limit of code + static/spike verification; the remaining
value is unlocked by the in-app witness and Phase-4, not by more edits.*
