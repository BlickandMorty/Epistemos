# PLAN 1 (MAS) — Vendor June + agent_core in-process backend (cloud + local)

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: this is now the
> sole active agent/product lane. Read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. Any remaining
> "sibling Experimental/1Code" language is historical. MAS/June must absorb the
> useful Epdoc assist, note-edit, data, research, and capability workflows through
> App Store-safe June + in-process `agent_core`; do not route active work to 1Code,
> Kindred, OpenChamber, Pro, Developer-ID, subprocess, terminal, stdio MCP, or Node.

**Date:** 2026-07-04 · **Status: CANONICAL for the Mac App Store build and sole
active agent surface as of 2026-07-07.** The old `PROMPT_PLAN_1_PRO_OPENCHAMBER.md`
track is archived/deleted by owner directive 2026-07-06; Experimental/1Code is
parked by owner directive 2026-07-07.

> 🔴 **ARCHITECTURE CORRECTION 2026-07-04 (owner):** the MAS agent surface is **June,
> VENDORED and run as its real UI using the vendored-web overlay discipline —
> with its backend swapped to Epistemos's in-process `agent_core` (cloud + local).** This
> REPLACES the earlier "native SwiftUI in June's visual language" approach, which produced
> a theme-tinted *demo* that skipped June's actual look. Cloning the real June UI makes the
> demo-look **structurally impossible** — you get June because it *is* June. This is the owner's original intent ("use June as the
> base and do a quick goose backend swap with its in-process part").

**Verification basis (clone-checked 2026-07-04):** June clone `.research-clones/june`
(`open-software-network/os-june`, MIT). Verified: normal Vite build (`build: tsc && vite
build` → static web assets, WKWebView-embeddable); a **small IPC seam**
(**13 `invoke()` call sites**) + a **separable `june-api`** backend layer; its agent runs on
**Hermes** (`src/lib/hermes-control-plane`) — the swap target; **~30 Tauri window/shell API
hits** = the runtime coupling the adapter must shim (the one real risk → the §9 spike gates
it first). Engine facts (Apple FM, llama.cpp, StoreKit, ingest) re-verified from the
2026-07-03 MAS research corpus (`docs/research/MAS_RESEARCH_CORPUS_RAW_2026_07_03.md`) +
canon `docs/research/GOOSE_MAS_BUILD_CANON_2026_06_30.md`.

---

## §0 LOCKED DECISIONS

1. **MAS build** (Epistemos-AppStore scheme, `EPISTEMOS_APP_STORE` + `MAS_SANDBOX`). App
   Sandbox + hardened runtime. **No subprocess, no local server binary, no `network.server`,
   no JIT/exec-memory entitlements.** June-web-in-WKWebView (bundled local assets, no Tauri
   runtime) + `agent_core` in-process via UniFFI + URLSession + embedded llama.cpp — all
   sandbox-legal.
2. **THE AGENT SURFACE = VENDORED JUNE** (fork + `epistemos/` overlay; no OpenChamber dependency)
   §6). June's real web frontend, built with its own Vite pipeline, bundled as static
   assets, loaded in the existing WKWebView. **You are cloning June, not reimplementing it.**
   Native chrome (pill / mascot / all-chats sheet) wraps it. The Epistemos wave / click-to-search
   **landing (Home) stays native**; June is the
   **Agent room** — its Agent tab mounts the real June surface, never a "not available" stub.
3. **BACKEND SWAP: Hermes → `agent_core` (in-process), cloud AND local.** June's UI expects a
   Hermes control plane; the adapter (§3) routes its calls to `agent_core` instead. The
   in-process agent is provider-plural per conversation: **cloud** = the receipt-gated proxy;
   **local** = the embedded `LocalChatEngine` (llama.cpp) + Apple Foundation Models — **"goose
   in-process cloud and local"** (owner). No Tauri, no Hermes runtime, no subprocess ships.
4. **June visual fidelity is now STRUCTURAL** — it's June's actual code, so "looks like a
   demo" cannot happen. The old §0.4 "measure and reimplement in native SwiftUI" gate is
   RETIRED (that path failed). Verify by booting the real June UI, not by matching a mockup.
5. **Capability truth:** small local models are unreliable at tool-calling → label/gate
   honestly (local = chat / light-agent tier; full agentic tool-loops = cloud tier). Never
   fake full agent capability on a local model. Show the active engine; hide absent features.
6. **Money:** free = local (Apple FM + GGUF, ungated). Paid = cloud agent via StoreKit 2 →
   proxy verify → short-lived token. **No provider keys in the binary** (proxy-side only;
   tokens in Keychain).
7. **MAS-only surface:** this is the active agent product line. Developer-ID,
   Experimental, 1Code, browser-use, and subprocess-backed capabilities are
   parked provenance unless a later owner directive reopens them. The vendored
   June fork + `agent_core` backend are the MAS agent surface; OpenChamber/ProAgent
   are not current surfaces.

## §1 THE JUNE VENDORING + ADAPTER SEAM

June is a Tauri app whose frontend is a normal web app; vendoring = take the frontend, drop
Tauri, run it in a WKWebView, and bridge its backend calls to `agent_core`. Concretely:

- **Fork June + overlay** (`epistemos/`): Epistemos changes as
  NEW files; unavoidable in-place edits → a `PATCH_LEDGER.md`; pin the June commit; the fork
  lives OUTSIDE the Epistemos tree (never `git add` `.research-clones/`).
- **Build + stage:** `bun/npm run build` (Vite) → static assets → bundle into the app; load
  via `loadFileURL` in the WKWebView (no server, no Tauri). The instant-open recipe (§8)
  applies: eager WebView + placeholder, kept warm across tab-switch.
- **The three coupling points to bridge/shim** (verified counts):
  1. **13 `invoke()` sites** (Tauri IPC → the Hermes/backend): reroute each to the
     `agent_core` adapter (§3) via `WKScriptMessageHandler` — the same in-page bridge the
     editor already uses. This is the backend swap.
  2. **~30 Tauri window/shell API hits** (`appWindow`, `WebviewWindow`, etc.): shim with a
     small JS polyfill (a `window.__TAURI__` stand-in) that maps the handful June actually
     uses to native equivalents or no-ops. Enumerate them in the spike.
  3. **Hermes control-plane calls** (`src/lib/hermes-control-plane`): these are the agent
     session/model/settings surface → map onto `agent_core`'s session/prompt/stream/tools.
- **De-risk FIRST (the §9 spike):** boot the built June frontend in a plain WKWebView with a
  stubbed bridge and prove it renders + navigates; THEN wire one real `agent_core` turn
  through the adapter. **Honest gate:** June's Tauri coupling must be measured in its own spike;
  host-agnostic UI was — if the window-API coupling proves deeper than the ~30 sites suggest,
  surface it at the spike and decide (shim harder vs. scope down) BEFORE the full vendor.

## §2 THE ENGINE LANE — agent_core, cloud + local (verified facts live here)

The vendored June UI drives `agent_core`; `agent_core` resolves the model per conversation:

- **Local (free lane).** **Apple Foundation Models** when available (`import FoundationModels`,
  **macOS 26+**; `SystemLanguageModel.default.availability`, `LanguageModelSession(model:tools:)`,
  `respond`/`streamResponse`; AFM 3 Core = summarize/extract/rewrite, not world knowledge;
  catch `guardrailViolation` → fall back to GGUF) + **embedded llama.cpp** (`LocalChatEngine`
  façade the first pass already built — KEEP it; pin an upstream XCFramework, `GGML_METAL=ON` +
  `GGML_METAL_EMBED_LIBRARY=ON`, `llama_model_load_from_file`/`llama_init_from_model`, **no JIT
  entitlement**, GGUFs in the app container). Model set (KV-math corrected): **Qwen3-4B default**,
  Qwen3-8B stronger, Qwen2.5-7B for long-doc; **Phi-3.5-mini rejected** (dense MHA KV trap).
  RAM-gate at launch; refuse oversized loads gracefully (never swap/crash).
- **Cloud (paid lane).** The existing provider stack pointed at the receipt-gated proxy;
  short-lived bearer token (Keychain), rotated.
- **Selection:** a composer chip in June's UI picks the lane (mirror the existing engine-chip interaction);
  `GooseMASAgentCoreCatalog` lists BOTH a local and a cloud provider (masBounded, in-process).
- **KEEP from the first pass** (real, working): the `agent_core` FFI loop (`runAgentSession`
  + `AgentEventDelegate` deltas), `LocalChatEngine`, `AppleFMQuickChatBackend`,
  `LocalGGUFQuickChatBackend` — these become the engine behind June. **RETIRE** the native
  `QuickChatStageView`/`AgentWorkspaceView` *UIs* (June's UI replaces them); their backends
  survive as the local engine.

## §3 THE ADAPTER (June frontend ↔ agent_core)

An `agent_core`-shaped bridge that satisfies the subset of June's backend calls its UI makes
(discover the exact set from the 13 invokes + the Hermes client during the spike). Shape:
- **session/new · prompt · stream · abort** → `agent_core` `runAgentSession` + the
  `AgentEventDelegate` deltas (`on_text_delta`/`on_thinking_delta`/`on_tool_started`/
  `on_permission_required`/…), translated into whatever event shape June's UI consumes.
- **providers/models** → the catalog's local+cloud entries.
- **tool permission** → June's approval UI ↔ `on_permission_required` (dry-run→confirm).
- **window/shell shims** → the `window.__TAURI__` polyfill (§1).
- Bridge runs Swift-side; secrets never enter the webview JS. UniFFI callbacks hop to main
  via `async`, never `.sync`.

## §4 MAS TOOL CATALOG + INGEST

- **Tool allowlist (from canon):** vault I/O (security-scoped bookmarks); in-app caps
  (PDF→md, search/graph/provenance); **HTTP MCP over a fixed HTTPS allowlist** (never stdio);
  cloud calls via the proxy. **Forbidden while MAS-only is active:** `cli_passthrough`, `terminal`, bash
  `registry`, `stdio_mcp`, `imessage`, `apple`/osascript, `code_execution`, schedules/
  extension-installer UI. Absent tools are *absent*, with one honest "bounded on MAS" note.
- **Ingest (all MAS-legal, on-device):** receipt/image → **Apple Vision `VNRecognizeTextRequest`**
  → agent structures → preview → insert + provenance; PDF → PDFKit/existing EdgeParse; CSV/JSON
  native; messy paste → agent field-inference. Cloud OCR is off unless it goes through the
  receipt-gated MAS proxy with explicit user consent. (Shared with Plan 9's ingest.)

## §5 PAYWALL + PROXY

StoreKit 2 purchase → app sends the JWS `Transaction` to the proxy → proxy verifies via App
Store Server API (.p8 server-side; validate x5c chain) → issues a short-lived token → cloud
lane carries it → App Store Server Notifications V2 drive renewals/cancellations. Bind with
`appAccountToken`. Free local lane needs no gate. verifyReceipt is deprecated — don't use it.

## §6 VENDORING DISCIPLINE (current neutral web-donor pattern)

Fork June + upstream remote, pinned commit; ALL Epistemos changes as NEW files in one
`epistemos/` overlay (the adapter, the Tauri shims, the native-chrome bridge, theme); a
`PATCH_LEDGER.md` row per unavoidable in-place edit; the fork is its own working copy OUTSIDE
the Epistemos tree. Update cadence: fetch upstream → merge (conflicts only in patch-ledger
files) → build → stage → smoke (boot in WKWebView). Never `git add -A`; never commit
`.research-clones/`; no worktrees.

## §7 NATIVE CHROME + LANDING

- The Epistemos **wave / click-to-search landing (Home) stays native** (restore from
  `9aa497bc6` / `8ba7ff61cb` if not already) — it's the app's front door, not part of June.
- **Native chrome wraps June:** the toolbar pill (Home/Agent/Notes/Settings), the all-chats
  sheet, and any MAS-safe status/provenance indicator for active agent work.
  Chrome drives June via injected intent events, never by reloading the SPA URL (kills the
  session — same rule as existing native navigation pills). The Agent tab mounts June; no stub.

## §8 PERFORMANCE + HARDENING (per-phase gates — read-first the doctrines)

- **Performance** (`AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`): June is now a web
  surface, so BOTH sides apply — web (production Vite build, code-split, bundle budget,
  virtualized lists, isolated streaming render, SW off) + app (eager WebView + placeholder,
  off-main engine init, **keep the WebView + loaded GGUF model WARM across tab-switch**,
  shared process pool, memory-pressure). Budgets in `perf-budgets.toml` `[agent_surface]`.
- **Hardening** (`AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`): per-phase four-lens pass
  (security/memory-leak/data-leak/robustness), thermonuclear disposition; a HIGH blocks the
  commit. Top risks here: **loopback/asset-origin pinning + no secret in webview JS + validate
  the invoke-bridge payloads** (the June IPC bridge is a trust boundary); **FFI truth boundary**
  for agent_core (no Rust panic SIGTRAPs the process); **llama.cpp OOM guard**; supervision +
  circuit breaker on the proxy; **ingest = untrusted** (malformed receipt/PDF can't corrupt or
  crash); the **instruction-source boundary** (content the agent reads is data, never commands).
- A perf regression AND a hardening HIGH each block the phase commit.

## §9 PHASES + ACCEPTANCE

- **Phase 0 — Spikes (de-risk, AppStore scheme):**
  (a) **June-in-WKWebView:** build June's frontend, load bundled assets in a plain WKWebView,
      shim the ~30 Tauri window APIs + stub the 13 invokes → it **renders + navigates** and
      **looks like June** (owner glance). This gates the whole approach.
  (b) **agent_core turn:** drive one MAS June turn through the direct in-process
      `GooseMASAgentCoreRunner` / `runAgentSession` path and stream deltas into June.
      The old MAS Goose ACP runtime flag is retired; do not re-enable a loopback Goose
      surface for App Store builds.
  (c) **llama.cpp local:** the embedded lane generates tokens sandboxed, release-signed, no
      forbidden entitlements — PASS (already proven; reuse `LocalChatEngine`).
  *If (a) reveals deeper Tauri coupling than the ~30 sites, do not blindly vendor. Record the
  blocker, choose the smallest reversible adapter/prototype path, and continue only while the
  MAS no-subprocess/no-server/no-JIT rules still hold; ask the owner only for destructive or
  scope-changing choices.*
- **Phase 1 — Vendor + adapter:** fork+overlay June; wire the adapter so June's chat runs a
  real `agent_core` conversation end-to-end (local lane first). *Accept: chat in June's real
  UI, answered by Apple FM/llama.cpp locally; survives relaunch; looks like June (owner-confirmed).*
- **Phase 2 — Cloud lane + engine chip:** proxy provider in agent_core + the local/cloud chip
  in June. *Accept: pick cloud → a proxy turn; pick local → an on-device turn; both in June.*
- **Phase 3 — Native chrome + landing:** pill/all-chats/mascot wrap June; native wave landing;
  Agent tab = June (no stub). *Accept: chrome + June feel like one app; which-build is obvious.*
- **Phase 4 — Paywall + ingest + tools:** StoreKit→proxy→token; Vision/PDF ingest w/ provenance;
  MAS tool allowlist + 5.1.2(i) consent; approvals. *Accept: purchase→cloud turn; a receipt
  photo → structured rows; a tool blocks on approval.*
- **Phase 5 — MLX retirement + hardening + submission:** delete the MLX lane (separate commits);
  entitlement audit (remove `cs.allow-jit` + `network.server`); OOM soak; review notes.
- Every phase ends: commit + owner-visual checkpoint + the perf/hardening gates.

## §10 CORRECTIONS LOG (do not resurrect)

1. ~~"native SwiftUI in June's visual language" (measure + reimplement)~~ → **REJECTED
   2026-07-04** (produced a theme-tinted demo). Architecture = **vendor the real June UI**.
2. ~~native `QuickChatStageView` / `AgentWorkspaceView` as the surface~~ → superseded by
   vendored June; their **engine backends** (`LocalChatEngine`/AppleFM/GGUF) are KEPT.
3. ~~QuickChat ungated leaking into Pro~~ → moot (June is the surface, gated to MAS).
4. ~~agent_core cloud-only~~ → **cloud + local** in-process (§2/§3).
5. ~~Apple FM on macOS 15 / `import LanguageModels`~~ → macOS 26, `FoundationModels`.
6. ~~Phi-3.5-mini as long-doc default~~ → Qwen3-4B; Phi rejected (KV math).

## §11 BUILD RUNBOOK (start here)

- **R1 vendor:** fork `open-software-network/os-june` → clone OUTSIDE the repo; pin the
  commit; `npm/bun install && run build` must pass UNTOUCHED before edits.
- **R2 spike:** stage the built assets, `loadFileURL` in a throwaway WKWebView host;
  enumerate the exact Tauri window APIs used (grep `@tauri-apps/api/window`, `appWindow`,
  `WebviewWindow`) and the 13 `invoke()` targets; shim/stub them; confirm render+nav.
- **R3 adapter:** map June's backend calls → `agent_core` (session/prompt/stream/tools) via
  `WKScriptMessageHandler`; secret never in JS.
- **R4 engine:** register local (LocalChatEngine/AppleFM) + cloud (proxy) providers in
  `GooseMASAgentCoreCatalog`; wire the composer chip.
- **R5 chrome:** native pill/all-chats/mascot wrap June (intent events, never URL reload);
  native wave landing; Agent tab = June.
- **R6 fonts:** June's fonts may be commercial (ABC Diatype/Martina/Berkeley Mono) — if the
  vendored CSS references them, substitute the nearest licensed/bundled equivalents in the
  overlay; do NOT ship unlicensed font files.
- **Acceptance per phase in §9.** Swift builds: isolated DerivedData, AppStore scheme,
  `CODE_SIGNING_ALLOWED=NO`, BUILD SUCCEEDED before commit; never two xcodebuilds at once.

## §12 GUARDRAILS

- MAS = no subprocess / no server / no `network.server` / no JIT-exec entitlements; all
  in-process (June-web-in-WKWebView + agent_core FFI + embedded llama.cpp).
- Never `git add -A`; never commit `.research-clones/`; no worktrees.
- Keys/tokens in Keychain, never the binary; provider keys proxy-side only.
- Don't touch KEELSTONE's OpenChamber/ProAgent deletion work, the Experimental/1Code lane, the graph,
  or the editors (Plan 2) beyond the seams.
- Never modify the goose/June backend *engines* to force a fit — swap at the adapter, overlay
  the frontend. Commit per coherent step; report honestly (no "done" without §9 acceptance).
- **"Done" requires objective evidence, not owner presence:** provide screenshot/log/runtime
  evidence that it renders as real June and completes a working `agent_core` turn. The owner may
  later review taste/feel, but the implementing agent must not wait for owner confirmation before
  closing the build gate.
