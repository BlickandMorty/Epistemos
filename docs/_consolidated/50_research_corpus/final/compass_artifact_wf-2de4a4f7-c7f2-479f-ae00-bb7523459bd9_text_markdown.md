# Epistemos × Hermes Agent — Architectural Dossier for the Hermes Creative Hackathon

> Solo developer: **Jojo / @BlickandMorty**. Submission window: **April 25 → EOD May 4, 2026** (Pacific assumed). Prize pool: **$25K** (Nous Research × Kimi/Moonshot). Stack: Swift 6 + Rust via UniFFI, Metal at 120fps on M2 Pro / 18GB, GRDB+SQLite WAL with F_FULLFSYNC, MLX-Swift, Hermes Agent v0.11.x.
>
> This dossier honors the manifesto (no compromise on architectural vision) while marking every UNVERIFIED claim with a resolving experiment. Where multiple genuine implementation contenders exist, all are presented with deep trade-offs — no single picks where alternatives compete.

---

## 0. Critical preamble — repository audit findings

### 0.1 BlickandMorty/Epistemos — INACCESSIBLE

The user-supplied repo URL `https://github.com/BlickandMorty/Epistemos` returned **no public trace** in any search, indexed page, or fetch attempt as of 2026-04-26. Most likely cause: private repository (404-on-unauthorized matches all observations). Recommendations citing "current state of substrate-core / UniFFI bridge / Metal renderer / OpLog / GRDB" therefore treat the manifesto as the authoritative description and mark each as **UNVERIFIED-against-repo**. The dossier provides target file paths the developer can map onto the existing tree.

**Resolving experiment for every UNVERIFIED-against-repo item:** publish the repo (or paste `tree -L 3`, `tokei`, `git log --oneline -n 20`, and Cargo.toml workspace members) so a follow-up audit can pin recommendations to specific files and line numbers.

### 0.2 NousResearch/hermes-agent — fully audited

Hermes is **MIT licensed**, Python 3.11+, ~3,700 commits, v0.11.x as of April 2026. Confirmed file paths used throughout this dossier:

| Subsystem | File path | Key facts |
|---|---|---|
| Skill loader | `agent/skill_utils.py`, `agent/prompt_builder.py:595/678/786/792` | YAML frontmatter; `~/.hermes/skills/`; `MAX_DESCRIPTION_LENGTH=1024`; lazy-load instruction at line 792 |
| MCP client | `tools/mcp_tool.py` (~1047 lines), `tools/mcp_oauth.py` | Official `mcp` Python package; stdio + streamable_http + SSE + WebSocket; `notifications/tools/list_changed` for dynamic discovery |
| execute_code | `tools/code_execution_tool.py` | POSIX-only, Python 3.11 subprocess + UDS RPC. **NOT OpenShell.** Limits 300s/50-call/50KB stdout/10KB stderr. `SANDBOX_ALLOWED_TOOLS` whitelist |
| Memory | `tools/memory_tool.py`, `hermes_state.py` | MEMORY.md/USER.md frozen-snapshot pattern; SQLite WAL + FTS5 |
| Skills tool | `tools/skills_tool.py` | `skill_manage` writes `~/.hermes/skills/<name>/SKILL.md` atomically |
| Plugins | `~/.hermes/plugins/*.py`, `hermes_cli/plugins.py:108-117` | `pre_tool_call` (with veto, PRs #9377/#10626/#10763), `post_tool_call`, `on_session_start`, etc. |
| Delegate | `tools/delegate_tool.py` (~560 lines) | `ThreadPoolExecutor(max_workers=delegation.max_concurrent_children)`, default 3, depth cap 1-3 |
| Gateway | `gateway/run.py`, `gateway/platforms/{telegram,discord,slack,...}` | Long-running daemon; per-platform tool gating |
| API server | exposes `/v1/chat/completions`, `/v1/responses`, `/api/jobs` | `Idempotency-Key`, `X-Hermes-Session-Id` |
| Persona | `~/.hermes/SOUL.md`, `~/.hermes/memories/{USER,MEMORY}.md` | `§` entry delimiter; concatenated into system prompt |
| ACP mode | `acp_adapter/server.py` | JSON-RPC over stdio, planned/early (#569) |

**Integration patterns (recommended):** (1) MCP server (zero Hermes changes), (2) plugin via lifecycle hooks, (3) HTTP api-server for chat stream, (4) custom skill, (5) memory provider plugin, (6) gateway adapter.

**Honcho self-hosted server is AGPL-3.0** — only matters if bundled. Hermes core is MIT.

### 0.3 Adjacent Nous repos

- **`hermes-agent-self-evolution`** (~2.3k★, MIT): DSPy + GEPA pipeline. Points at Hermes via `HERMES_AGENT_REPO` env var. Eval sources: `synthetic | sessiondb | golden | auto`. Output: PR against hermes-agent.
- **`atropos`** (~1.1k★): RL trajectory framework. JSONL/ShareGPT export. Hermes feeds via `batch_runner.py` + `trajectory_compressor.py`.
- **`OpenShell`**: NousResearch's own appears to be a fork/stub; canonical is **NVIDIA/OpenShell**. Vanilla Hermes execute_code does NOT use OpenShell. The community `hermesclaw` project bridges them.
- **`autonovel`**: README structure (tagline → ASCII arch diagram → quickstart → phases → file tree → mental model → acknowledgements) is the **Nous house style** — replicate for Epistemos.

---

## 1. Executive Summary Table

| Domain | Status | Recommended approach | Hackathon-critical | Post-hackathon dependency | Primary risk |
|---|---|---|---|---|---|
| **D1** MCP substrate surface | Verified (rmcp 1.3) | **Hybrid C+B**: in-process Streamable-HTTP rmcp server for Hermes discoverability + UniFFI for hot-path | **Y** | Y | rmcp `local` feature still maturing; Swift 6 Sendable for async UniFFI (#2448) |
| **D2** Skills as graph nodes | Partial | **Hybrid (D)**: SKILL.md mirror + MCP `apply_skill` + plugin `pre_tool_call` veto | **Y** | Y | Symlink-vs-copy issue with `iter_skill_index_files` (`os.walk` followlinks=False) |
| **D3** Loop profiles | Partial | **Hybrid (c)** YAML manifest + Python steps via `execute_code`. WASM as v2 | N (post) | Y | execute_code POSIX-only sandbox; not a real isolator |
| **D4** Schema-driven UI | Verified | **Hybrid (D)**: runtime ViewRegistry + concrete typed NodeViews + Sourcery for table | **Y** | Y | Streaming JSON shape parity with Hermes wire format UNVERIFIED |
| **D5** Embedded browser | Partial | **Hybrid (D)**: WKWebView visible + MCP browser-actions + Hermes' Camofox/Browserbase for scrape | N (post) | Y | WKWebView no headless / no first-class CDP |
| **D6** Session graph as live cognition | Verified | Custom Swift actor + ring buffer drained per Metal frame, tokio `broadcast(4096)` upstream | **Y** | Y | UniFFI async + Swift 6 Sendable rough edges |
| **D7** Landing page → app handoff | Verified | Web stands alone (Cloudflare Pages); `epistemos://launch` deep-link as bonus | **Y** | N | Custom-scheme silent-fail when app uninstalled |
| **D8** Node taxonomy | Verified | 7 first-class types (RawThought, ImplementationPlan, Recall, Skill, LoopProfile, Synthesis, Session) | **Y** | Y | None |
| **D9** Aesthetic stack | Verified | **Press Start 2P (OFL)** + SF Pro/Mono + Pixel Operator (CC0); cyan #4FE0D2 primary, amber #E0A04F as Hermes-thinking accent; `cubic-bezier(0.65,0,0.35,1)` is `easeInOutSine`, NOT `ease-in-out` | **Y** | N | Berkeley Mono is a license trap for editor-class apps |
| **D10** Submission mechanics | Verified prize+date; UNVERIFIED tracks/timezone | Tweet @NousResearch + Discord post + GitHub MCP repo + landing + 3-5min judge cut | **Y** | N | Deadline timezone — submit by EOD May 3 PT |
| **D11** Ambient recall | Partial | bge-small via MLX (hackathon) → nomic-Matryoshka-256 (post); 250ms debounce; sidebar primary, peek secondary, ⌘K palette tertiary | **Y** | Y | All latency numbers UNVERIFIED until §11 harness runs |
| **D12** Multi-model orchestration | Verified | Swift dispatcher (B) + Hermes `auxiliary:` per-task overrides (C) | N (post) | Y | Hermes' `_meta` forwarding to Anthropic adapter UNVERIFIED |
| **D13** Niche Hermes | Verified | Cron audits + Telegram gateway + nudge redirect + delegate-as-subgraph + ShareGPT→Atropos + agentskills.io publish | **N (post for most)**; **Y for cron + delegate** | Y | Memory-nudge sentinel string UNVERIFIED |
| **D14** CLI vs MCP | Partial | **api-server SSE** for chat stream + **MCP** for graph ops; ACP later | **Y** | Y | `--json` on `hermes chat` not in published flag set |

---

## 2. Per-domain deep dives

### D1 — The MCP Substrate Surface

**State of the art.** rmcp 1.3.0 (March 2026), tokio-coupled, JSON Schema 2020-12 via `schemars`. Spec target MCP 2025-11-25. Feature flags: `server`, `client`, `macros`, `transport-streamable-http-server`, `transport-streamable-http-client`, `transport-child-process`, `transport-sse-{server,client}`, `auth`, **`local`** (v1.3.0, `!Send` tool handlers — relevant when holding Metal device handles).

**Six-verb tool surface — VALIDATED + 1 (the brief lists 7 verbs; ship all 7):**
`graph.search_semantic`, `graph.search_fulltext`, `graph.get_node`, `graph.traverse`, `graph.create_node`, `graph.create_edge`, `graph.commit_session`. Working `tools.rs` provided in the prior research bundle uses the modern macro form `#[tool_router] / #[tool(description=…)] / Parameters<T> / #[tool_handler]` directly cited from the rmcp v1.x README.

**Process model — three contenders compared:**

| | A. Subprocess (stdio MCP) | B. In-process socket/SSE | C. In-process FFI (UniFFI) |
|---|---|---|---|
| Latency | 0.1–2 ms | 0.05–0.5 ms | **1–10 µs** |
| Crash containment | **Best** | Coupled | Coupled |
| 120fps fit (~10 calls/frame) | Busts 8.33ms | Borderline | **Always under** |
| Hermes integration | Native MCP | Native MCP | Bypasses MCP semantics |
| Debug | Separate `lldb -p` | Single Instruments | Single Instruments + unified trace |

**Recommended (hot+cold):** **C for hot path, B for advertisement.** UniFFI handles Metal frame budget; an in-process Streamable-HTTP rmcp server bound to `127.0.0.1:7421/mcp` (or UDS, supported in rmcp 1.3 PR #749) keeps Hermes's stock Python MCP client seeing tools natively. Hermes hot-path graph queries from Python would route via `apply_skill` into the same Rust core, avoiding double serialization.

**SlotMap u64 generational keys → wire format:** **Typed `{idx: u32, gen: u32}`** (option C). Lossless in JSON Schema, hand-editable, pretty-prints in Hermes traces. Cap SlotMap to 2^32 slots and 2^32 generations (~136 yrs at 1M nodes/sec churn).

**GraphEvent emission:** **`tokio::sync::broadcast(4096)`** as the canonical fan-out. Renderer subscribes via UniFFI callback and tolerates `Lagged` by snapshotting (`graph.get_node`). GRDB writes via separate `mpsc` consumer on its own serial DispatchQueue, batched every 50 ms. Sidebar gets its own broadcast receiver.

**Risks & mitigations:**
- rmcp `local` feature interaction with `axum` server thread model — verify with a smoke test before relying on it for !Send Metal state.
- macOS Hardened Runtime + sandboxed app + helper tool: bundle `substrate-mcp` inside `Contents/MacOS/`, sign with same Team ID, `com.apple.security.inherit` entitlement. Avoid posix_spawn of arbitrary executables.

**Verification experiment:** Smoke-test by running rmcp's counter example, swapping in the 7 graph tools, and asserting via Hermes's `hermes mcp test epistemos` that the schemas surface in `tools/list` with expected JSON Schema 2020-12 shape.

---

### D2 — Skills as Graph Nodes

**Four integration approaches** (deep table in prior research bundle). Recommend **(D) Hybrid: SKILL.md mirror + MCP `apply_skill`**:
- Plugin `on_session_start` projects graph-stored skills into `~/.hermes/skills/<name>/SKILL.md` filtered by current session subgraph.
- Plugin `pre_tool_call` vetoes `skill_manage(action="create")` and routes through UDS RPC to the Rust core (`skills.upsert_from_hermes`).
- MCP server exposes `epistemos.create_skill_node` and `epistemos.apply_skill` as alternative path when Hermes' native skills toolset is disabled.

**Skill node Rust schema** (cited primary spec: agentskills.io — name ≤64 chars `[a-z0-9-]`, description ≤1024 chars):
```rust
#[derive(uniffi::Record, Serialize, Deserialize, JsonSchema)]
pub struct Skill {
    pub name: String, pub description: String, pub version: String,
    pub body: String, pub applies_to: AppliesTo, pub examples: Vec<SkillExample>,
    pub parent: Option<NodeId>, pub source_session: SessionId,
    pub hermes_metadata: Option<HermesMetadata>,
}
```
Edges: `applies-to-type`, `learned-in-session`, `refined-from`.

**Autonomous skill creation flow** trace: `skill_manage(action="create")` → `tools/skills_tool.py` create branch → atomic write of `~/.hermes/skills/<name>/SKILL.md`. Two interception points:
1. **Plugin veto (recommended):** `~/.hermes/plugins/epistemos_skill_redirect.py` registers `pre_tool_call`. Returns `{block: True, error: "Skill committed as <node_id> in Epistemos graph"}` — the model receives this string as the tool result.
2. **Replacement:** Disable `skills` toolset entirely (`disabled_toolsets: [skills]`); Epistemos MCP server advertises `epistemos.create_skill_node` instead.

**Skill retrieval at turn start:** `agent/prompt_builder.py:595` `build_skills_system_prompt` walks `~/.hermes/skills/` via `iter_skill_index_files` (`os.walk`, **followlinks=False**). To filter by session subgraph: rebuild the directory before each session via the plugin.

**UNVERIFIED + resolving experiment:** Symlinks may not be followed. Resolve by using `shutil.copytree` (cheap; SKILL.md ~5KB) or hardlinks at the *file* level rather than directory symlinks.

**Worked example (synthesize_long_form):** Full event sequence from `pre_tool_call` veto through MCP `epistemos.create_skill_node`, through Rust `GraphStore.upsert_skill` emitting `node.created` + 3 edge events, through SwiftUI subscriber animating the new skill node into the Metal canvas. Available verbatim in the prior research bundle (T0–T12).

**Verification experiment:** 30-line pytest harness using `tmp_path` + `monkeypatch.setenv("HERMES_HOME", str(tmp_path))` asserting (a) plugin veto fires, (b) RPC sent, (c) no SKILL.md written under redirected HERMES_HOME.

---

### D3 — Loop Profiles (The Editable Brain)

**Five DSL options** compared in trade-off table (see prior bundle). Recommend **(c) Hybrid YAML manifest + Python steps via `execute_code`** for hackathon, plan **(d) WASM via wasmtime** as v2.

**Sandboxing comparison (cited primary):**
- Hermes subprocess+UDS: not a real sandbox (Issue #4146); same uid, no seccomp/namespace; `terminal` is in `SANDBOX_ALLOWED_TOOLS`.
- **wasmtime** (recommended target): capability-based, `WasiCtxBuilder` deny-by-default fs+net; `set_fuel` for CPU; `set_epoch_deadline` for wall-clock kill. Per-invocation grants are explicit and additive.
- macOS `sandbox-exec` (SBPL): kernel-backed but Apple-deprecated; gate on `which sandbox-exec`.
- App Sandbox: outer fence; entitlements baked into parent — cannot vary per-invocation.

**Layering recommendation:** App Sandbox (outer) + `sandbox-exec` profile (mid) per loop run + Hermes UDS/whitelist (inner). For evolved profiles → wasmtime so the policy travels with the artifact.

**LoopProfile entity** (Rust):
```rust
pub struct LoopProfile {
    pub id: Uuid, pub name: String, pub description: String,
    pub target_kind: String, pub trigger: LoopTrigger, pub source: LoopSource,
    pub body: String, pub version: u32, pub refined_from: Option<Uuid>, pub metrics: LoopMetrics,
}
pub enum LoopTrigger { Manual, Scheduled { cron: String }, Event { kind: String } }
pub enum LoopSource { Python, Yaml, Wasm, Lua }
```

**`loop-runtime` crate skeleton** (~80 lines, full code in prior bundle): public API `LoopRuntime::register/invoke/events`, tokio mpsc bus, YAML interpreter for 4 step kinds (`query`, `traverse`, `embed`, `create`).

**GEPA / DSPy mapping:** Frame LoopProfile as a `dspy.Module` with `dspy.GEPA(metric=…, auto="medium", reflection_lm=dspy.LM("openrouter/qwen/qwen3-next-80b-a3b-thinking", max_tokens=65536))`. Concrete CLI:
```bash
export HERMES_AGENT_REPO=~/.hermes/hermes-agent
export EPISTEMOS_SESSION_DB=~/Library/Application\ Support/Epistemos/sessions.db
python -m evolution.loops.evolve_loop \
    --loop deepen_thought --iterations 10 --eval-source sessiondb \
    --reflection-lm openrouter/qwen/qwen3-next-80b-a3b-thinking \
    --output ~/.epistemos/loops/deepen_thought.evolved.py
```

**Worked example `deepen_thought`** in YAML, Python (via execute_code with `from hermes_tools import web_search` + `from epistemos_tools import emit_node, emit_edge`), and WASM (Rust → wasm32-wasip2 component with WIT bindings) — all in prior bundle.

**Verification experiment:** Run §D3.7 fixture (100 invocations × 6 events) against all three substrates; YAML interpreter should hit ≥50,000 events/s on M-series; Python and WASM 2-3 orders of magnitude slower.

---

### D4 — Schema-Driven UI Synthesis

**State of the art (cited primary):** SwiftUI dynamic forms via KeyPath are limited to per-kind once kind is resolved. **AppIntents `@Parameter` rendering surface is system-owned** (WWDC23/10103) — cannot return arbitrary SwiftUI views; pattern model only. **`@Observable` + Macros (Swift 5.9+)** is the canonical fine-grained dependency-tracking primitive; `withObservationTracking { ... } onChange:` for streaming reads. **FoundationModels** (`@Generable`, `session.streamResponse(generating: T.self)`, `T.PartiallyGenerated` mirror) is *only generation*, not rendering — but its API surface is the canonical Apple-blessed streaming idiom.

**No public Swift port of `react-jsonschema-form` exists.** Closest libraries: `ajevans99/swift-json-schema` (★★★★, Swift 6 race-safe, `@Schemable` macro), `mattt/JSONSchema`, `kylef/JSONSchema.swift` (validator only), `SwiftedMind/SwiftAgent` (★★★★, FoundationModels-style streaming patterns).

**Five top-contender architectures** (matrix in prior bundle):
| | A. Pure runtime | B. Type-erased ViewBuilder | C. Sourcery codegen | D. Hybrid | E. Macros `#NodeView` |
|---|---|---|---|---|---|
| Type safety | ★★ | ★★★ | ★★★★★ | ★★★★ | ★★★★★ |
| SwiftUI diffing | ★★ | ★★★ | ★★★★★ | ★★★★ | ★★★★★ |
| Hackathon time | ★★★★★ | ★★★★ | ★★ | ★★★★ | ★★ |
| Post-hackathon | ★★★ | ★★★ | ★★★★★ | ★★★★★ | ★★★★ |

**Recommendation: (D) Hybrid.** Runtime `ViewRegistry<NodeKind, AnyView>` delegates to concrete typed `NodeView`s per kind. Sourcery generates the registry table from `Schemas/*.json`. Migration path to (E) macros post-hackathon.

**Streaming partial structured outputs:** Hermes returns partial JSON token-by-token. Pattern: `@Observable` model holds `Snapshot` type with all-optional properties (mirrors Apple's `T.PartiallyGenerated`). Coalesce delta updates at frame boundaries (8.33ms@120Hz). Full `StreamingImplementationPlanView` and `StreamingSynthesisView` in prior bundle, with `Task.sleep(nanoseconds: frameNS)` debounce + `.redacted(reason: .placeholder)` for un-arrived fields + `.transition(.opacity)` for arrival animation.

**JSON Schema 2020-12 for all 6 view kinds** (RawThought, ImplementationPlan, Recall, Skill, LoopProfile, Synthesis) — full schemas in prior bundle.

**ViewRegistry module** — full Swift 6 code (~280 LOC) in prior bundle. Public surface:
```swift
public protocol NodeView: View { associatedtype Model: Codable & Identifiable & Sendable; init(model: Model) }
public final class ViewRegistry {
    public static let shared = ViewRegistry()
    public func register<V: NodeView>(kind: NodeKind, _ view: V.Type)
    public func view(for kind: any NodeKindRepresentable, payload: Data) -> AnyView
}
```
Plus 6 concrete `NodeView` implementations (RawThoughtView, ImplementationPlanView, RecallView, SkillView, LoopProfileView, SynthesisView). Adding `ResearchNote` = one new file + one enum case + one register line (Sourcery makes it literally one file).

**Verification:** Swift Testing harness asserts (a) all 6 registered, (b) sample JSON for each decodes and renders without throw, (c) unknown kind falls back, (d) malformed payload shows decode error. Snapshot-test with `pointfreeco/swift-snapshot-testing`.

**UNVERIFIED:** Hermes wire-format JSON schema parity with Apple `@Generable`. Resolving experiment: capture 100 real Hermes Pro tool-call responses, attempt `JSONDecoder().decode` against each, count successes; if <100% add a translation layer.

---

### D5 — The Embedded Browser

**Hermes web/browser backends (verified):** Web search = Firecrawl/Brave/Tavily/Exa/Parallel. Browser = Playwright local + Browserbase + Browser Use (Nous Tool Gateway) + Camofox (`CAMOFOX_URL`).

**WKWebView vs Chromium** trade table (prior bundle): WKWebView gives **real Safari fingerprint** (better evasion than headless Chrome) but lacks headless/CDP/full request rewrite. Web Inspector requires `com.apple.security.get-task-allow=YES` (dev only).

**Four approaches compared:**
- **A.** MCP→WKWebView: low integration cost (already have it), high observability via `evaluateJavaScript`+`takeSnapshot`.
- **B.** Anthropic computer-use vs WKWebView: vision drift, slow, costly.
- **C.** CEF/Servo embed: Servo macOS arm64 unstable; CEF binary 100MB+; rejected.
- **D.** Hybrid: WKWebView visible (MCP browser-actions) + Hermes' Camofox/Browserbase for hostile/scrape targets.

**Recommended: D, with A as the in-app primary.** No new code for scrape — defer to Hermes's existing `web_search`/`browser_use_*`.

**MCP browser-actions server skeleton** (Rust rmcp, full code in prior bundle): tools `navigate`, `click(selector)`, `type(selector,text)`, `read_dom(selector?)`, `screenshot`, `scroll(dy)`, `wait(selector,timeout_ms)`. Bound to `127.0.0.1:7421/mcp` via Streamable HTTP. Hermes config: `mcp.servers.epistemos-browser.url`.

**BrowserView SwiftUI host** (full code in prior bundle): `WKWebView` with `WKUserScript` injection at `atDocumentStart` exposing `window.__epistemos.readDOM(sel)`; async `evaluateJavaScript` for click/type; `WKSnapshotConfiguration` for screenshots.

**Permission model:** Read/screenshot allow; click/type/cross-domain-nav prompt; jsEval prompt; persisted at (origin, action) tuple.

**Demo session:** "Read the latest WebKit blog and create Recall nodes for the top 3 features" → `navigate` → `read_dom(main)` → 3× `epistemos-recall.create_node`.

---

### D6 — Session Graph as Live Cognition

**GraphEvent schema** (Rust enum + Swift bridge, full code prior bundle): 11 variants — `NodeCreated`, `NodeMutated`, `NodeAccessed`, `EdgeCreated`, `EdgeTraversed`, `SessionStarted`, `SessionCommitted`, `ToolInvocationStarted/Completed`, `EmbeddingComputed`, plus `LoopBegan/Ended` from D3. Each carries a `position_seed` so the renderer instantiates without back-querying.

**Subscription mechanism comparison** (prior bundle): `AsyncSequence` (single-iterator, awkward for 120fps), Combine (`RunLoop.main` jitter), Observation (`@Observable` is pull-based — wrong tool for streams), **custom Swift actor + SPSC ring buffer** (recommended). Drained per `MTKView.draw(_:)` on the GPU dispatch queue, frame-aligned to CADisplayLink. Backpressure: on overflow, coalesce.

**Three Metal animation primitives** as shader uniforms (NOT SwiftUI animations) — full MSL code in prior bundle:
1. **`pulse(node_id, color, duration)`** — ring-expansion outward from node center, gaussian feathered, fades as `1 - in.pulseT`.
2. **`flash_edge(from, to, color)`** — traveling-light gaussian along oriented thin quad.
3. **`phase_in(node_id, glare_passes=1)`** — alpha fade with optional diagonal glare overlay using `(in.localUV.x + in.localUV.y) * 0.7071` axis projection.

Plus full vertex shaders, billboarding math, `FrameUniforms` and `NodeInstance`/`EdgeInstance` structs in a bridging header.

**Frame budget at 120fps with concurrent reasoning (M3 Max, N=10K nodes / 30K edges):**
| Stage | Budget |
|---|---|
| UniFFI marshalling | <0.05 ms |
| Force-directed Verlet | 1.5–3.0 ms |
| Scene mutation | 0.2–0.5 ms |
| Encode | 0.3–0.5 ms |
| GPU exec | 1–2 ms |
| Compositor | ~0.3 ms |
| **Headroom** | ≈2–3 ms |

**Triple buffering** (Apple primary source verified): 3× `MTLBuffer` + `dispatch_semaphore_t` initialised to 3. Pattern in prior bundle. Per Apple Developer Forums thread/651581: never use `maximumDrawableCount = 2` at 120Hz — risk of stuttering 12-20-12 ms cadence. **Ship native arm64 (no Rosetta)** — Apple capped 60Hz under Rosetta.

**Layout: GPU compute vs CPU SIMD.** N≤10K → CPU SIMD via `accelerate`/`simd_float4`. N≥20K → GPU compute shader (Barnes-Hut on GPU or O(N²) tiled @ 128 threads/group).

**Session toggle UX:** Orthographic camera (preserves spatial relationships during transition), critically-damped spring (ω₀=12, ζ=1.0, ~400ms settling). Out-of-session nodes get `inSession=0.0`, `dimFactor=0.25`, separate Gaussian blur pass masked by stencil.

**Verification:** Real-device Instruments profiling at 1500 events/s on M3 Pro; assert P99 frame time ≤ 8.33ms.

---

### D7 — Landing Page → App Handoff

**Custom URL scheme XML** (verified):
```xml
<key>CFBundleURLTypes</key><array><dict>
  <key>CFBundleTypeRole</key><string>Editor</string>
  <key>CFBundleURLName</key><string>app.epistemos.deeplink</string>
  <key>CFBundleURLSchemes</key><array><string>epistemos</string></array>
</dict></array>
```

**SwiftUI `.onOpenURL`** is the modern path — works for cold AND warm launch. AppKit `NSAppleEventManager` only needed if you must access the options dictionary.

**Architectural decision: web stands alone.** Most judges won't install. Optimize for video-watcher first; deep-link is bonus. Hybrid: web teases, app continues seamlessly via `epistemos://launch?from=web&t=<ts>`.

**ASCII wave at 60fps:** JS + Canvas with monospace font (~50 lines, full impl in prior bundle). Two superimposed sines for organic feel; `CHARS = ' .,:;-~=*#@'`. M1 Air handles 80×24 with no jank. Metal-equivalent stub for in-app version uses a glyph atlas + `fragment float4 ascii_wave_fragment` shader.

**Pixel-art type-on:** CSS `@keyframes` with `steps(12, end)` over 0.96s + `@keyframes blink` at 1.06s `steps(2, start) infinite`. Full HTML/CSS in prior bundle, with `prefers-reduced-motion: reduce` opt-out.

**Glare on web:** CSS `@keyframes` with `linear-gradient` mask + `transform: translateX(-100%) → 100%` over `0.7s cubic-bezier(0.65, 0, 0.35, 1)`. SVG filter and WebGL options rejected as overkill.

**Glare in app:** Full `glare.metal` (vertex + fragment) + `GlareRenderer: MTKViewDelegate` + `GlareView: NSViewRepresentable` Swift host (~120 LOC, in prior bundle). 700ms ease-in-out-sine. Trigger on Hermes-thinking-complete event.

**Pixel font (HERO):** **Press Start 2P (OFL 1.1, Cody Boisclair)** — verified license, 8×8 cell, derived from Namco Return of Ishtar arcade ROM. ~61KB. Hero 24-48px only.

**Accessibility:** `prefers-reduced-motion` web, `@Environment(\.accessibilityReduceMotion)` SwiftUI, `aria-live="polite"` for screen readers, `NSAccessibility.post(.announcementRequested)` after type-on.

**Hosting:** Cloudflare Pages free, custom domain `epistemos.app` ($12/yr at CF Registrar at-cost). Whole site under 50KB.

---

### D8 — Node Taxonomy of Thought

**7 node types — Rust definitions** (full code in prior bundle):

```rust
pub struct NodeMeta { id: Uuid, created_at: DateTime<Utc>, session_id: Uuid, author: String }
pub struct RawThought { meta: NodeMeta, text: String, prompted_by: Option<Uuid> }
pub struct ImplementationPlan { meta, title, sections: Vec<PlanSection>, derived_from: Vec<Uuid>, implements: Option<Uuid> }
pub struct Recall { meta, query, content, source_uri, recalls: Uuid }
pub struct Skill { meta, name, markdown, applies_to_type, learned_in_session, refined_from }
pub struct LoopProfileNode = LoopProfile  // from D3
pub struct Synthesis { meta, title, essay, synthesizes: Vec<Uuid>, citations: Vec<Uuid> }
pub struct Session { meta, title, closed_at, succeeds, contains }
```

**`NodeKind` enum** with `default_view()` mapping to ViewRegistry keys (`view.thought.markdown`, `view.plan.sectioned`, etc.).

**`EdgeKind` enum** — 14 predicates: `PromptedBy, Recalls, FromSource, DerivedFrom, Cites, Implements, AppliesToType, LearnedInSession, RefinedFrom, TargetsType, InvokedFrom, Synthesizes, Contains, Succeeds`.

**Lifecycle table:**
| Type | Creator | Mutations | Deletion | Indexing |
|---|---|---|---|---|
| RawThought | user, loop-runtime | append-only | tombstone | FTS5+vector |
| ImplementationPlan | Hermes | sections appendable, CRDT-merge | tombstone | FTS5+vector |
| Recall | system | immutable | hard-delete on source vanish | FTS5+vector |
| Skill | Hermes | markdown editable, version-bumps | soft-delete | FTS5+vector |
| LoopProfile | user | body editable, version-bumps | soft (cannot if invoked-from edges) | FTS5 |
| Synthesis | user | editable until commit | tombstone | FTS5+vector |
| Session | system | title editable, closed_at, contains computed | archive only | FTS5 |

**Full example session GraphEvent stream** in prior bundle (28 events, exercises all 7 NodeKinds and the major edge types).

**Verification (Rust test):** `tokio::test` programmatically constructs example, asserts all 7 NodeKind variants present, asserts edge topology, asserts exactly 3 prompted-by edges from `t0`.

---

### D9 — The Aesthetic Stack

**Typography (license-verified):**
| Role | Font | License | File |
|---|---|---|---|
| Hero | Press Start 2P | OFL 1.1 | PressStart2P-Regular.ttf |
| Body proportional | SF Pro | Apple system | (system) |
| Code/mono | SF Mono | Apple system | (system) |
| Pixel body accent | Pixel Operator | CC0 1.0 | PixelOperator.ttf |
| CRT/thinking log | VT323 | OFL 1.1 | VT323-Regular.ttf |

**CRITICAL LICENSE TRAP: Berkeley Mono carve-out** — usgraphics.com explicitly says "If you're building an IDE, Terminal app, Text Editor, etc., we generally do not allow it." Epistemos = PKM/cognitive-substrate displays user prose → falls into this gray zone. **AVOID.** `IoskeleyMono` (Iosevka build, OFL) is the safe alternative.

**Color palette (sRGB + P3, contrast verified):**
| Token | sRGB | Contrast on #000 |
|---|---|---|
| inkBlack #000000 | (0,0,0) | — |
| parchment #F5F2EA | (0.961, 0.949, 0.918) | 18.95:1 (AAA both) |
| accentCyan #4FE0D2 | (0.310, 0.878, 0.824) | 10.74:1 (AAA both) |
| accentAmber #E0A04F | (0.878, 0.627, 0.310) | 8.55:1 (AA body, AAA large) |

**Cyan vs amber recommendation: cyan primary, amber as one-off Hermes-thinking accent.** Cyan reads as on-brief in current AI/dev-tools visual culture; amber is the "Granola" warm-distinctive move and gets its single moment in the granular-hum + glare. Cyan also legibility-wins at 8px (chromatic luminance higher than amber in pixel-art mode).

**Motion specification — KEY CORRECTION:** `cubic-bezier(0.65, 0, 0.35, 1)` is **`easeInOutSine`**, NOT the CSS `ease-in-out` keyword (which is `(0.42, 0, 0.58, 1)`). Use the explicit numeric form everywhere; call it "smooth" or "easeInOutSine" in code/docs.

| Trigger | Duration | Curve |
|---|---|---|
| Button press, panel collapse, hover | 200ms | easeInOutSine `(0.65,0,0.35,1)` |
| Graph node arrival | 400ms | easeOutQuart `(0.25,1,0.5,1)` |
| Glare signature | 700ms | easeInOutSine |

`CAMetalDisplayLink` preferred over `CADisplayLink` on macOS 14+ (Apple Developer Forums thread/763426).

**Tokens.swift** — full file in prior bundle. Defines `Tokens.Palette.{inkBlack, parchment, accentCyan, accentAmber}` (sRGB + P3), `Tokens.Type.{hero, body, mono, crt}`, `Tokens.Motion.{transition, arrival, glare}`, and `Motion.prefersReducedMotion` gate.

**Pixel-art generation pipeline:** **Aseprite hand-authoring only.** $19.99 one-time. Indexed color mode with `epistemos.gpl` palette (4 swatches + transparent). Sprite sizes 8/16/32/64/128/1024. Forbid anti-aliasing, sub-pixel blending, drop shadows. **DO NOT use Stable Diffusion / Midjourney** — legal exposure (Andersen v. Stability AI unresolved), style theft, and bad signal for an AI hackathon (autonovel/ANTI-SLOP.md aligned).

**Audio post-hackathon:** AVAudioSourceNode (iOS 13/macOS 10.15+) is the cleanest path; AudioKit's `Granulator` works for hackathon prototype. Granular hum drone at 82Hz or 110Hz, ≤−24 LUFS, default OFF.

---

### D10 — Hackathon Submission Mechanics

**Verified:**
- Hackathon: "Hermes Agent Creative Hackathon" presented by @Kimi_Moonshot & @NousResearch.
- Announcement: x.com/NousResearch/status/2045225469088326039 (Apr 17, 3:38 PM, "16 days, $25k").
- Prize pool: **$25,000**.
- Topic scope: "video, image, audio, 3D, long-form writing, **creative software, interactive media** and more" — Epistemos squarely on-brief.

**UNVERIFIED:**
- Track structure (Main/Kimi split implied by dual sponsorship but not in writing).
- Deadline timezone — assume Pacific. **Submit by EOD May 3 PT for 24h buffer.**
- Judging criteria — none published; infer: creative use of Hermes + technical depth + polish + user value.

**Past winners archetype (autonovel verified primary):** README structure = tagline → lineage citation → concrete production proof → quickstart → phase breakdown → tools table → file tree → mental model → API requirements → production history → acknowledgements. **Replicate this structure.**

`hermes-embodied` pattern: personal quote opening + ASCII architecture diagram with Hermes Agent at top + skills underneath = Nous community style.

**Discord submission norms (UNVERIFIED but consistent):** drop X/Twitter URL + 2-3 line writeup + repo links in `creative-hackathon-submissions`. No spam-pinging. Engagement is signal but don't game.

**Companion artifacts:**
1. Open MCP server repo `github.com/you/epistemos-mcp` (separate, MIT, public).
2. Landing page on Cloudflare Pages w/ embedded video + waitlist.
3. YouTube unlisted "judge cut" 3-5 min linked from README.
4. 5-tweet thread.

**Submission checklist** — comprehensive list of 26 items in prior research bundle covering Product, Repos, Landing, Video, Submission Posts, Legal/Provenance.

**5-tweet thread** (full copy in prior bundle):
1. Hook + 60s video + tag both sponsors
2. Problem (PKM is editing not thinking)
3. Technical how (Swift 6 / Metal / FTS5 / MCP)
4. Aesthetic position (restraint as warmth)
5. Invitation + links

**README skeleton** (full structure in prior bundle): mirrors autonovel.

**Landing page wireframe:** ASCII wave background → HERMES AGENT type-on → Epistemos tagline → Launch button (deep-link) + Download → embedded video → waitlist form → footer.

---

### D11 — Instant Ambient Recall

**MLX-Swift embedding model selection** (cited primary):
| Model | Dim | Params | MTEB | MLX-Swift | Est. M2 Pro 50-tok latency (UNVERIFIED) |
|---|---|---|---|---|---|
| **bge-small-en-v1.5** (BAAI) | 384 | 33M | 62.17 | ✅ `MLXEmbedders.bge_micro` | **8–15 ms** |
| **nomic-embed-text-v1.5** | 768 (Matryoshka 512/256/128/64) | 137M | 62.28 (≤1.24pt drop @ 512) | ✅ `MLXEmbedders.nomic_text_v1_5` | 35–60 ms |
| mxbai-embed-large-v1 | 1024 | 335M | 64.68 | ⚠️ via mzbac/Blaizzy | 80–140 ms (busts budget) |
| gte-large-en-v1.5 | 1024 | 434M | 65.39 | ❌ port required | >120 ms |
| Apple NLEmbedding | 512 | system | not on MTEB | ✅ native | 1-3 ms (lowest quality) |
| **Apple FoundationModels** | n/a | 3B | n/a | ✅ generation only — **NO public embeddings API** |

**Recommendation:** bge-small for hackathon, nomic-embed-Matryoshka-256 post-hackathon.

**Latency budget:** P50 target 45ms / P95 95ms / hard ceiling 120ms from "user paused" to "result rendered". Hot tier (session-warm SIMD): <10ms over ≤2k vectors. Cold tier (full vault via UniFFI to `graph.search_semantic`): 50-200ms, fired only when `cosine < 0.55` on hot.

**Three triggers, three surfaces:**
| Trigger | Cost | Surface |
|---|---|---|
| Cursor pause (250ms idle, debounced) | bge-small required | Ambient sidebar (PRIMARY) |
| Paragraph completion | nomic-256 affordable | Peek-on-hover (paragraph gutter) |
| ⌘K hotkey | mxbai-large affordable | Floating command palette |

**Reject inline ghost text:** wrong cognitive contract (predicts what you'd write vs surfaces what you've written elsewhere) + TextKit2 cursor positioning fragility.

**Cross-app capture:**
| Mechanism | Permission | Latency | Verdict |
|---|---|---|---|
| AXUIElement | Accessibility TCC | <5ms | **Recommended primary** |
| ScreenCaptureKit + Vision OCR | Screen Recording (orange indicator!) | 40-120ms | Skip for v1 |
| NSPasteboard polling | none | <1ms but explicit-copy only | Universal fallback |

**Privacy invariant in code:** `AmbientRecallEngine.submitToMCP(_:intent: ExplicitInvocation)` — token can only be minted by user-gesture code paths (⌘K palette, explicit "send to Hermes" button).

**Working code stubs** (full in prior bundle):
- `BGESmallEmbeddingModel: actor` wrapping MLXEmbedders, ~30 LOC
- `AmbientRecallEngine: actor` with cancel-and-replace 250ms debounce + speculative graph fire + cosine ≥0.6 display gate
- `AmbientSidebarView` SwiftUI subscriber with asymmetric in/out transitions
- `AccessibilityCapture` reading `kAXFocusedUIElementAttribute` + `kAXSelectedTextAttribute`

**Comparison to incumbents:** Mem.ai (cloud), Reflect (cloud), Heptabase (no ambient), Notion AI (cloud) — **no incumbent ships on-device + ambient + restraint + graph-aware all four.** Differentiated wedge.

**Verification experiments** (resolve all UNVERIFIED perf):
- §11.1 latency harness: synthetic CGEvent keystrokes at human-realistic Pareto intervals; measure paintedAt-keystrokeAt; compute P50/P95/P99 over 10 minutes battery + AC.
- §11.2 quality test: 20 hand-curated query-target pairs; top-5 hit rate (target ≥90%) and MRR (target ≥0.7).
- §11.3 capture coverage probe across 10 apps.

---

### D12 — Local/Cloud Model Orchestration

**Three routing approaches:** (A) Hermes-as-router — fragile prompt drift; (B) External Swift dispatcher — total control, lowest latency, recommended for production; (C) Schema-typed routing via `_meta` annotations — Hermes already does this with `auxiliary:` (vision/compression/extraction) and per-task `delegation.{model,base_url,api_key}` overrides (#14974).

**Recommended: B + C hybrid.** Swift owns dispatch by intent; tools carry preferred-backend hints in their `_meta`.

**`Orchestrator` actor** (full Swift code prior bundle): dispatch table maps `Purpose` → `ModelClient`. Default routing:
```swift
.graphContext: "apex-mini-mlx", .ambientRecall: "bge-small-mlx",
.synthesis: "claude-sonnet-4.5", .discovery: "hermes-web", .classification: "apex-mini-mlx"
```

**Per-model trace UI:** `ModelInvocation` struct (model, provider, latencyMs, tokens, costUsdMicros, traceId) + `ModelTraceOverlay` SwiftUI view with provider-color dots + monospace.

**`programmatic_tool_calling` collapse — worked example:** Single execute_code script doing `web_search → web_extract → mcp_call(apex_complete) → mcp_call(create_nodes)` — 12KB of HTML stays out of the LLM context window; only `print(f"wrote {len(notes)} Recall nodes")` reaches the conversation.

---

### D13 — Niche Hermes Capabilities

**Cron audits/digests** (verified: parsed by LLM into croniter, ticked every 60s by gateway daemon, cap with `HERMES_CRON_SCRIPT_TIMEOUT`):
```
/cron add "Every night at 2:30am, walk Recall graph via epistemos-recall MCP — find orphan nodes,
 duplicate-title clusters, stale (>90d). Write audit to ~/Library/Logs/Epistemos/audits/$(date +%F).md"
/cron add "Every Sunday at 8pm, generate synthesis digest from past 7d Recall, group by tag,
 summarize via claude-sonnet, write as kind='digest/weekly'."
/cron add "Every 6 hours, embed any Recall where embedding_version < current. Cap 200/run."
```

**Telegram gateway** (verified primary): `TELEGRAM_ALLOWED_USERS=<numeric_ids>`, optional `hermes pairing approve telegram XKGH5N7P` (1h TTL, 1-per-10-min RL, 5-fail lockout, 0600 chmod). Disable terminal/execute_code on phone via `disabled_toolsets`. Voice memos auto-transcribed by faster-whisper.

**Periodic nudge redirect:** Plugin `pre_llm_call` hook intercepts the memory-nudge system prompt and rewrites it to call `epistemos-recall.create_node` instead of editing MEMORY.md. **UNVERIFIED:** exact sentinel string in nudge composer. Resolving experiment: `grep -rn "evaluate" ~/.hermes/hermes-agent/agent/`.

**Subagent delegation as session subgraphs** (verified `tools/delegate_tool.py`): each delegate call → Recall node `kind=session/subagent` with edges parent_session_id → child + child → all created nodes + final summary as `kind=session/summary` linked back. Tune `delegation.max_concurrent_children: 4`, `max_spawn_depth: 2`, leaf model `google/gemini-3-flash-preview`.

**Trajectory export → Atropos** (verified ShareGPT format): SwiftUI 1-5 thumbs widget after every Claude synthesis writes `metadata.epistemos_synthesis_quality`; trajectory JSONL via `--save-trajectories`; ingest via `python -m environments.atropos.ingest --reward-key metadata.epistemos_synthesis_quality --reward-scale 5`.

**agentskills.io publishing** (verified spec): Apache-2.0 spec; SKILL.md required; `name` ≤64 chars `[a-z0-9-]`; `description` ≤1024. Publish `epistemos-recall-search` skill via `hermes skills publish --to github`.

---

### D14 — CLI Integration

**`hermes chat --json` UNVERIFIED.** Not in published top-level flag set. `batch_runner.py` is the documented JSONL path.

**Resolving experiment:** Argparse introspection script in prior bundle (`python -c "import hermes_cli.main; ..."`) plus `grep -RInE 'add_argument\(.+--json'` plus functional probe `hermes chat --json -q -p ci <<< 'echo hi'`.

**CLI vs MCP:**
| | CLI subprocess | MCP |
|---|---|---|
| First-token | 600-1500ms cold | 10-50ms in-process |
| Structured | stdout text + ANSI; needs --quiet --plain | Native JSON-RPC, schema-validated |
| Tool calls visible | No — hidden in subprocess | Yes — first-class events |
| Streaming | Whatever TUI emits | Streamable HTTP / SSE |

**Recommended hybrid (full ASCII diagram in prior bundle):**
- **Phase 1 (today)**: `/v1/chat/completions?stream=true` (api-server SSE) for chat stream + 3 in-process MCP servers (`epistemos-browser:7421`, `epistemos-recall:7422`, `epistemos-models:7423`).
- **Phase 2 (when ACP stabilizes)**: switch chat stream to `hermes acp` over stdio for richer typed events.
- **Phase 3**: publish Epistemos as ACP-client registry entry.

`Idempotency-Key` enables safe synthesis retries; `X-Hermes-Session-Id` keeps each Epistemos document on its own resumable Hermes session.

---

## 3. Cross-domain integration narrative

The dossier converges on **a single pipeline** spanning all 14 domains:

```
USER KEYSTROKE
    ↓ (D11 ambient: 250ms debounce → MLX bge-small embed)
Swift @Observable AmbientRecallState
    ↓ (UniFFI hop into Rust)
graph.search_semantic (in-process, <1ms hot tier)
    ↓ (D6 GraphEvent: NodeAccessed, EmbeddingComputed)
tokio::sync::broadcast(4096)
    ↓ (UniFFI callback → Swift actor → SPSC ring buffer)
MTKView.draw frame-aligned drain (D6)
    ↓ (D6 Metal shaders: pulse, flash_edge, phase_in @ 120fps)
RENDERED
    
USER INVOKES HERMES (⌘K palette)
    ↓ (D11 ExplicitInvocation token minted)
Swift Orchestrator (D12) routes by Purpose
    ↓ (D14 hybrid: HTTP api-server SSE for stream + MCP for graph ops)
Hermes AIAgent
    ↓ (D2 plugin pre_tool_call vetoes skill_manage)
Hermes makes MCP tool call → epistemos-{recall,browser,models} (D1, D5)
    ↓ (rmcp 1.3 Streamable HTTP, in-process socket)
Rust SubstrateCore mutates graph + emits GraphEvent
    ↓ (D6 broadcast → renderer)
    ↓ (D8 NodeKind dispatched to D4 ViewRegistry)
SwiftUI NodeView<RawThought / Skill / Synthesis> renders
    ↓ (D4 streaming variants coalesce at 8.33ms frame boundaries)
USER SEES IT EVOLVE LIVE
```

**Every MCP tool call → GraphEvent → Metal animation → ViewRegistry render is one pipeline.** The graph IS the agent runtime. Sessions are subgraphs that compound. Skills are nodes; loops are nodes targeting nodes; synthesis is a first-class node citing other nodes; recalls are auto-created edge events; the renderer is the agent's working memory made visible. There is no "agent" separate from the substrate — Hermes is a faculty whose actions are graph mutations and whose context is a graph projection.

---

## 4. The Compressed Vector — 9-day plan (April 26 → May 4)

| Day | Date | Track | Deliverables | Blocked-on |
|---|---|---|---|---|
| **0** | Sat Apr 26 | Audit + Setup | Make repo public; expose `tree -L 3`; spike rmcp 1.3 hello-world; spike MLX bge-small load + embed; verify `hermes chat --json` (D14 experiment) | research closed |
| **1** | Sun Apr 27 | D1 + D8 | `substrate-mcp` Rust crate with 7 tools registered against rmcp; NodeKind/EdgeKind enums; NodeId wire format `{idx,gen}`; Hermes config points at `127.0.0.1:7421/mcp` | labor |
| **2** | Mon Apr 28 | D2 + D6 | Plugin `epistemos_skill_redirect.py` shipping veto path; `tokio::sync::broadcast(4096)` GraphEvent emitter; UniFFI callback bridging into Swift `GraphEventInbox` | labor |
| **3** | Tue Apr 29 | D6 + D8 | Three Metal shaders (pulse, flash_edge, phase_in); `MTKView` triple-buffered render loop @ 120Hz; force-directed Verlet for N≤10K | labor |
| **4** | Wed Apr 30 | D4 + D11 | ViewRegistry + 6 concrete NodeViews; StreamingImplementationPlanView; AmbientRecallEngine with 250ms debounce; sidebar UI | labor |
| **5** | Thu May 1 | D5 + D12 + D7 web | MCP browser-actions server (7 tools); BrowserView SwiftUI host; Orchestrator dispatch; Cloudflare Pages landing live with type-on + glare | labor |
| **6** | Fri May 2 | Demo session + polish | Hero session round-trip: user authors RawThought → Hermes Recall → Hermes ImplementationPlan → user Synthesis → Hermes saves Skill → user commits. Session view animated. Metal glare on Hermes-thinking-complete. | research (Hermes wire-format parity D4) |
| **7** | Sat May 3 | Recording + thread + buffer | 60-90s Twitter cut + 3-5min YouTube unlisted judge cut + thread copy + README + Discord post drafted. **Submit by EOD PT.** | labor |
| **8** | Sun May 4 | Reserve | If anything broke yesterday, fix today. Otherwise: D13 cron skills as polish; engagement on the thread. | optional |

**Reroutes (per load-bearing component):**
- **rmcp 1.3 doesn't compile** with `local` feature → fall back to v0.16 + global `Sync` constraint, hold Metal device behind `Mutex`.
- **UniFFI async + Swift 6 Sendable warnings persist** → wrap async UniFFI calls in a `Task { @MainActor in ... }` shim; ship with `@unchecked Sendable` on `GraphEventInbox`.
- **MLX bge-small fails to load** at hackathon → fall back to Apple `NLEmbedding.sentenceEmbedding(for: .english)` (1-3ms, 512-dim) for ambient; defer MLX to post-hackathon.
- **120fps drops** under realistic load on M2 Pro → drop to 60fps target; visual quality unchanged (the eye doesn't notice when motion is restrained).
- **Plugin `pre_tool_call` veto contract not stable** in v0.11 → ship the MCP-replacement path (disable Hermes `skills` toolset, advertise `epistemos.create_skill_node`).
- **WKWebView automation flaky on a target site** → record demo against a known-good site (the Apple WebKit blog), defer hardening.

**The hard constraint:** the demo session in Day 6 must work end-to-end. Everything else can be cut.

---

## 5. The Compounded Trajectory — Post-Hackathon (8-12 weeks)

1. **Loop profiles ship** with WASM substrate (wasmtime + WASI capabilities). Migrate `deepen_thought` from Python to Rust→wasm32-wasip2.
2. **Browser MCP server** hardens (Camofox integration, cross-origin policy editor, persistent permission ledger).
3. **Schema-driven UI for arbitrary types** (D4 path E): `#NodeView` Swift macro generates registry table at compile time; user-defined node kinds via Sourcery + JSON schemas in `~/.epistemos/schemas/`.
4. **Branching session forks** — `Session.succeeds` enables alt-history exploration; CRDT merge for ImplementationPlan sections.
5. **Multi-model orchestration UI** — surface `_meta` annotations as visible per-tool model badges; per-session cost ledger.
6. **Computer-use integration** — Anthropic computer-use (Claude) drives WKWebView via vision when Camofox/Browserbase fail; vision tool calls bridge to `evaluateJavaScript` + `CGWindowListCreateImage`.
7. **GEPA-evolved loops** (`hermes-agent-self-evolution`) — `evolve_loop` opens PRs against `~/.epistemos/loops/` with before/after holdout scores.
8. **Trajectory feedback to Atropos** — synthesis-quality thumbs become RL reward signal training a fine-tuned local synthesizer.

---

## 6. Hero demo storyboard — 60-90 seconds

| t | shot | narration overlay | on-screen |
|---|---|---|---|
| 0:00–0:05 | Cold-open. Black screen. Pixel cursor blink. | (silence) | `█` |
| 0:05–0:13 | "HERMES AGENT" types on (steps 12, 80ms/char). 700ms diagonal glare sweep on completion. | (silence) | type-on + glare |
| 0:13–0:20 | Cut to app launch. Graph view pans into focus, ~80 nodes orbiting. ASCII waves at 0.3 opacity behind. | "Your notes don't sit there." | wide |
| 0:20–0:30 | User types "deepening agent reasoning" into a RawThought. Sidebar (D11) populates with 3 related vault hits — fade in over 240ms. Cursor stays in flow. | "They think with you." | sidebar surfaces |
| 0:30–0:42 | User invokes Hermes (⌘K). Hermes-thinking sprite animates (granular hum drone faintly audible). Session subgraph dims; new Recall + ImplementationPlan nodes phase in with 1-pass glare. | "Hermes is a faculty of the substrate, not a wrapper." | session focus |
| 0:42–0:55 | LoopProfile `deepen_thought` invoked. 3 child RawThoughts emerge over 1.2s, each with edge flash from parent. Renderer at full 120fps; FPS counter visible top-right. | "Loops are user code targeting typed nodes." | loop animation |
| 0:55–1:08 | Hermes auto-saves a learned Skill. Camera pulls back; `learned-in-session` edge animates from new Skill node to current Session node. Skill description appears in side panel. | "Skills are nodes. Learned in this session, applies to RawThought." | skill autoredirect |
| 1:08–1:18 | User commits session. `graph.commit_session` → SessionCommitted event. Subgraph re-renders as compacted. Hash printed beneath. | "Commit is permanent. The graph IS the agent runtime." | commit |
| 1:18–1:25 | Final card: Press Start 2P "EPISTEMOS" + line "Built for the Hermes Creative Hackathon. @NousResearch · @Kimi_Moonshot." Glare sweep. | (silence) | end card |

---

## 7. Submission package

**5-tweet thread** (verbatim copy in §D10 prior bundle).

**README skeleton** — autonovel-shaped (§D10). 

**Landing page wireframe** — black, ASCII waves bg, type-on hero, embedded video, waitlist form (§D10).

**Judge-cut outline (3-5 min YouTube unlisted):**
1. 0:00-0:30 — manifesto intro (substrate, not notes app; Hermes as faculty)
2. 0:30-1:30 — graph as agent runtime (D6 visual hero; show GraphEvent → Metal animation pipeline live)
3. 1:30-2:30 — skills as nodes (D2 demo; show autonomous Hermes skill creation redirected to graph)
4. 2:30-3:30 — ambient recall (D11 demo; live typing with sidebar)
5. 3:30-4:30 — loop profiles (D3 demo; user edits YAML, runs against RawThought, watches subgraph spawn)
6. 4:30-5:00 — outro (open MCP repo, agentskills.io plan, post-hackathon trajectory)

---

## 8. Risk register — ordered by mitigation priority

| # | Risk | Probability | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Repo private/inaccessible blocks any audit-derived recommendation | confirmed | high | **Publish repo today** OR paste tree+tokei+Cargo.toml inline |
| 2 | Hermes wire format ↔ Apple `@Generable` JSON Schema parity | UNVERIFIED | high (D4 streaming) | Capture 100 real Hermes Pro responses, count decode successes; add translation layer if <100% |
| 3 | All ambient-recall latency numbers UNVERIFIED | UNVERIFIED | high (D11 UX) | Run §11.1 latency harness Day 0 |
| 4 | Deadline timezone UNVERIFIED | likely | high | Submit by EOD May 3 PT (24h buffer) |
| 5 | 120fps Metal target may not hold under realistic load | UNVERIFIED | medium | Real-device Instruments profiling Day 3 |
| 6 | UniFFI async + Swift 6 strict Sendable rough edges (#2448) | likely | medium | Ship `@unchecked Sendable` on GraphEventInbox |
| 7 | Plugin `pre_tool_call` veto contract may shift v0.11→v0.12 | possible | medium | Pin Hermes version; ship MCP-replacement fallback |
| 8 | Memory-nudge sentinel string | UNVERIFIED | low | Grep before relying on D13 nudge redirect |
| 9 | iter_skill_index_files follows symlinks? | UNVERIFIED | low | Use copytree/hardlink instead |
| 10 | Berkeley Mono license trap if accidentally bundled | possible | high (legal) | Use Press Start 2P + SF Pro + Pixel Operator only |
| 11 | Honcho self-hosted is AGPL-3.0 | confirmed | low | Don't bundle the server; use client SDK only |
| 12 | rmcp `local` feature interaction with axum | UNVERIFIED | medium | Smoke-test before relying on it |
| 13 | macOS Hardened Runtime + sandboxed app + helper subprocess | possible | high | Bundle helper inside `Contents/MacOS/`, same Team ID |
| 14 | WKWebView no-headless / no-CDP bites scrape demos | likely | low | Demo against known-good sites; defer hostile targets |
| 15 | Submission track structure UNVERIFIED | likely | low | Write submission post platform-agnostic |

---

## 9. Capability honesty appendix — every UNVERIFIED claim with resolving experiment

| # | Claim | Resolving experiment |
|---|---|---|
| 1 | BlickandMorty/Epistemos repo structure (substrate-core, UniFFI bridge, Metal renderer, OpLog, GRDB, MCP scaffolding, TextKit2 rope, ~137K Swift / ~94K Rust LOC, 120fps) | Publish repo OR paste `tree -L 3`, `tokei`, `git log --oneline -n 20`, `Cargo.toml` inline |
| 2 | rmcp 1.3 MSRV exact value | `cat rust-toolchain.toml` against pinned commit |
| 3 | rmcp first-party WebSocket transport | `grep transport-ws crates/rmcp/Cargo.toml` |
| 4 | rmcp `stdio()` source path | `grep -rn "pub fn stdio" crates/rmcp/src/` |
| 5 | UniFFI 1.0 cut date | `cargo search uniffi` |
| 6 | Swift 6 Sendable conformance for async UniFFI calls (#2448) | Check issue #2448 status |
| 7 | macOS Hardened Runtime helper-tool entitlements | Apple's "Embedding a Helper Tool in a Sandboxed App" doc |
| 8 | `hermes chat --json` exists | Argparse introspection script + `grep -RInE 'add_argument\(.+--json'` |
| 9 | Memory-nudge sentinel string for `pre_llm_call` redirect | `grep -rn "evaluate" agent/ run_agent.py` |
| 10 | `iter_skill_index_files` follows symlinks | Drop probe SKILL.md as symlinked dir; check `hermes skills list` |
| 11 | `tools/skills_tool.py` exact create-handler symbol name | `python -c "import tools.skills_tool as t; print([n for n in dir(t) if 'create' in n.lower()])"` |
| 12 | MCP server receives `session_id` from Hermes | Print env in MCP command spawn |
| 13 | `delegate_tool.py` exact LOC | `wc -l tools/delegate_tool.py` |
| 14 | MCP `_meta` forwarded by Hermes Anthropic adapter | Custom server returning `_meta`; inspect `hermes tools --json` |
| 15 | `hermes skills publish --to github` exact CLI shape | `hermes skills --help` |
| 16 | bge-small / nomic / mxbai latency on M2 Pro 18GB | §11.1 latency harness |
| 17 | bge-small / nomic top-5 hit rate on personal vault | §11.2 quality test, 20 hand-curated pairs |
| 18 | AXUIElement coverage across {Bear, VS Code, Obsidian, Notion, Mail, Slack, Safari, Chrome, Figma, iA Writer} | §11.3 capture coverage probe |
| 19 | 120fps actually holds at 1500 events/s on M2/M3 Pro | Real-device Instruments System Trace |
| 20 | autonovel video format / hackathon artifact list | Find the autonovel demo video link from autonovel README or Nous blog |
| 21 | Hackathon track structure (Main + Kimi split) | Watch @NousResearch + @Kimi_Moonshot for follow-up tweets |
| 22 | Hackathon deadline timezone | Same — but in absence, submit by EOD May 3 PT |
| 23 | Hackathon judging criteria | Same |
| 24 | macOS 27 retains `sandbox-exec` CLI wrapper | Gate on `which sandbox-exec`; provide wasmtime fallback |
| 25 | NousResearch/OpenShell is real fork or stub | `git clone` and inspect |
| 26 | SOUL.md default skeleton content | Inspect a fresh `hermes setup` install |
| 27 | Existence of `examples/` directory in hermes-agent | Browse main branch |
| 28 | Cron scheduler library (croniter vs schedule vs custom) | Inspect `cron/scheduler.py` import block |
| 29 | Apple FoundationModels public embeddings API | Re-check `developer.apple.com/documentation/FoundationModels` at WWDC26 |
| 30 | GEPA `auto="medium"` budget (~$2-10) sufficient to lift `deepen_thought` | Run evolve_loop on 20-train/10-val SessionDB-mined dataset; measure holdout delta |

---

## Closing note

Every recommendation in this dossier is grounded in primary sources where possible (rmcp v1.3 README, UniFFI guide, Apple Metal docs, hermes-agent source paths verified by line number, agentskills.io spec, MTEB scores from BAAI/Nomic/Mixedbread cards). Where claims are UNVERIFIED — most numerically about latency or about Hermes's internal wire format — they are paired with the cheapest experiment that resolves them. The architecture honors the manifesto without compromise: graph as agent runtime, skills as nodes, sessions as compounding subgraphs, MCP for discoverability + UniFFI for hot path, restraint-as-warmth as a motion vocabulary expressed in concrete CAMediaTimingFunction tuples, ambient recall on-device with the privacy boundary enforced by an `ExplicitInvocation` token type that only user-gesture code can mint.

Win the hackathon by shipping the demo session in Day 6 — everything else compounds afterward.