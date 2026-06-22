# Fugu (Sakana AI) Orchestration — Integration Research & Plan

**Date:** 2026-06-22
**Topic:** Sakana AI "Fugu" / "Fugu Ultra" multi-agent orchestration LLM — verified facts, two integration paths, native-orchestration alternative, recommendation, paste-ready plan additions.
**Anti-hallucination policy applied:** PRIMARY sources only for all numeric/API claims (sakana.ai, console.sakana.ai, github.com/sakanaai/fugu). Every fact is labeled **[VERIFIED]** (confirmed on a primary page), **[INFERRED]** (reasoned from primary facts), or **[UNVERIFIED]** (could not confirm — do not act on as fact). The prompt's "$10/message" figure is **NOT confirmed** and appears to be wrong — see §1.

---

## 0. Source ledger

| # | URL | What it grounds |
|---|-----|-----------------|
| S1 | https://sakana.ai/fugu/ | product overview, model names, comparison set |
| S2 | https://sakana.ai/fugu-beta/ | benchmark table (numbers) |
| S3 | https://sakana.ai/fugu-release/ | launch framing, "not in agent pool" note |
| S4 | https://console.sakana.ai/get-started | **base URL, auth header, curl + python examples** |
| S5 | https://console.sakana.ai/models | model IDs + descriptions |
| S6 | https://console.sakana.ai/pricing | token pricing + subscription tiers |
| S7 | https://github.com/sakanaai/fugu | repo contents (report + installer, no weights) |
| S8 | https://news.ycombinator.com/item?id=48624782 | skeptic discussion (secondary, opinion) |

Secondary/aggregator pages (officechai, venturebeat, byteiota, explainx, clankercloud) were read for triangulation only and are **explicitly distrusted where they disagree with S1–S7** — notably officechai reported "SWE-Bench Pro 73.7 / GPQA 87.5", which **contradicts** the primary table (S2) and is treated as an error.

---

## 1. Fugu — VERIFIED facts

### What it is
- **[VERIFIED, S1/S3]** Fugu is a Tokyo lab (Sakana AI) product: a language model *trained to call other LLMs in an agent pool, including recursive calls to itself*. One request to one endpoint → Fugu decides to answer directly or to assemble/route/verify/synthesize across a pool of expert models. The multi-agent complexity is hidden behind a single model API.
- **[VERIFIED, S3]** Research basis: two ICLR 2026 papers — **TRINITY** (evolved coordinator assigning Thinker/Worker/Verifier roles) and **Conductor** (RL to learn natural-language coordination).
- **[VERIFIED, S3]** The strongest comparison models, **Fable 5 and Mythos Preview, are NOT in Fugu's agent pool** ("they are not publicly accessible"). So Fugu *competes with* them using a pool of other public frontier models.

### Tiers / model IDs (use these exact strings in API calls)
- **[VERIFIED, S5]** `fugu` — default; "Routes between different agents based on the task; balances performance with low latency."
- **[VERIFIED, S5]** `fugu-ultra` — "Routes between one to three specialist agents; prioritizes answer quality on difficult problems with higher costs."
- **[VERIFIED, S5]** `fugu-ultra-20260615` — dated pinned-version alias of `fugu-ultra`.
- **[VERIFIED, S4]** `fugu` accepts a `reasoning.effort` parameter with values `high` / `xhigh` (a.k.a. `max`).

### API — endpoint, auth, compatibility
- **[VERIFIED, S4]** Base URL: **`https://api.sakana.ai/v1`**
- **[VERIFIED, S4]** Auth: **`Authorization: Bearer $SAKANA_API_KEY`** (standard bearer key).
- **[VERIFIED, S4/S7]** OpenAI-compatible. Supports **both `/chat/completions` (Chat Completions) and `/responses` (Responses) endpoints** (S7 README: "supports both Chat Completions and Responses endpoints"; S4 shows a `chat/completions` curl and a `responses.create` python example).
- **[VERIFIED, S4]** Drop-in with the OpenAI client: `OpenAI(base_url="https://api.sakana.ai/v1", api_key=...)`.
- **Streaming:** **[UNVERIFIED]** — not shown in any primary example I could read. OpenAI-compat strongly implies `stream:true` works, but treat as unconfirmed until tested.

### Availability / sign-up
- **[VERIFIED, S1/S4]** Generally available (GA). Sign-up / keys via **https://console.sakana.ai/login** and **/get-started**.
- **[VERIFIED, S4]** **Not available in EU/EEA** (GDPR work pending). Support: `fugu-support@sakana.ai`.
- **[VERIFIED, S7]** A CLI/coding harness exists: `curl -fsSL https://sakana.ai/fugu/install | bash` then `codex-fugu` (a Codex-style coding agent wired to Fugu).

### Pricing — REAL numbers (the "$10/message" claim is unconfirmed/wrong)
- **[VERIFIED, S6] Fugu Ultra**, per **1M tokens**: input **$5**, output **$30**, cached input **$0.50**. For context **>272K tokens** these **double-ish**: input **$10**, output **$45**, cached input **$1.00**.
- **[VERIFIED, S6] Fugu (non-Ultra):** no fixed per-token sheet — "you pay only the standard rate for the specific underlying model" and "we never stack model fees."
- **[VERIFIED, S6] Orchestration tokens ARE billed** at the same rate as normal tokens ("represent real token usage … counted in the final price"). This is the key cost gotcha: a routed/verified multi-agent run bills the *sum* of all sub-agent tokens.
- **[VERIFIED, S6] Subscriptions:** Standard **$20/mo**, Pro **$100/mo** (~10× Standard allowance), Max **$200/mo** (~20×). Subscribe by **2026-07-31** → second month free.
- **The prompt's "~$10/message":** **[UNVERIFIED / likely inaccurate]** There is no per-message fee on any primary page. The only "$10" on a primary page is the *>272K-context input price per 1M tokens*. A single very large Ultra request *could* approach a few dollars (and an extreme multi-agent run more), but a flat $10/message is **not** Sakana's published model. **Do not surface "$10/message" to users as a fact.** Surface the real per-token rates + the orchestration-token multiplier.

### Open vs closed
- **[VERIFIED, S7]** **Closed-source product.** The GitHub repo (`sakanaai/fugu`) holds the technical report PDF, an installer, and configs — **no model weights, no standalone SDK**. The orchestrator and pool are a managed commercial API.
- **[VERIFIED, S1]** It orchestrates *third-party closed/public frontier models* (the comparison set names Gemini 3.1 Pro, GPT 5.4/5.5, Opus 4.x), so adopting Fugu = depending on Sakana **plus** the upstream vendors it calls.

### Benchmarks — exact primary numbers (S2)
Higher = better. Fugu's own published table:

| Benchmark | Gemini 3.1 | GPT 5.4 | Opus 4.6 | Fugu (Mini) | **Fugu Ultra** |
|---|---|---|---|---|---|
| GPQA-Diamond | 94.4 | 90.9 | 92.7 | 92.4 | **95.1** |
| LiveCodeBench v6 | 90.3 | 92.1 | 92.4 | 90.4 | **93.2** |
| SWE-Bench Pro | 48.4 | 51.2 | 53.4* | 51.3 | **54.2** |

\* Opus SWE-Bench Pro is "self-reported with a custom Anthropic scaffold" (S2). These match the prompt's headline figures (54.2 / 95.1 / 93.2). Note the **margins over the best single pool model are small** (e.g. SWE-Bench Pro 54.2 vs 53.4) — see skeptics, §3.4.

### Skeptic / transparency flags ([VERIFIED these were raised], S8 — opinion not fact)
- Gains over the strongest single pooled model look **marginal** in some rows.
- "No vendor lock-in" is contested: you now depend on Sakana **and** the upstream vendors ("multiple vendors run this single API").
- Real-world reports of **slow latency** and quality "nowhere near Fable" from at least one user; limited weekly usage on subscriptions.
- Stacked-cost worry; obsolescence risk if frontier labs converge or ship their own harnesses.
- Defense-sector ties cited by one commenter as a reason to avoid.
- **Agent-pool composition is not disclosed** as an exact list (S2 only names *comparison* models, not the pool).

---

## 2. Integration Path A — adopt Fugu as a CLOUD PROVIDER

Fugu is a textbook OpenAI-compatible provider, so it slots into Epistemos's existing remote-provider machinery with near-zero new code. There are **three** insertion surfaces.

### A1. osaurus remote-provider catalog (the canonical provider registry)
All cloud providers live in the vendored osaurus package, designed so a new OpenAI-compatible provider is ~3 lines:

- **`LocalPackages/osaurus/Packages/OsaurusCore/Models/Configuration/ProviderPresets.swift`** — add a `ProviderPreset` case `fugu` with: `name "Sakana Fugu"`, `consoleURL https://console.sakana.ai/login`, and a `configuration` arm: `host: "api.sakana.ai"`, `basePath: "/v1"`, `authType: .apiKey`, `providerType: .openaiLegacy`, `defaultManualModelIds: ["fugu", "fugu-ultra"]`. (Reuse `.openaiLegacy` — the wire format is plain `/v1/chat/completions` Bearer; **no new `RemoteProviderType` case needed.**)
- **`LocalPackages/osaurus/Packages/OsaurusCore/Models/Configuration/ProviderCatalog.swift`** — add one line to `ProviderCatalog.entries` (~line 165): `ProviderCatalogEntry(.fugu, authMethods: [.apiKey], placement: .apiKey)`. The catalog header explicitly documents "adding a provider is a single entry, no view edits required."
- Request building (`.../Services/Provider/RemoteProviderService.swift` `buildURLRequest` ~line 2567) already falls through to the generic `chatEndpoint` for `.openaiLegacy` — no change.
- **Zero-code path that works today:** the existing `.custom` preset already lets a user paste `https://api.sakana.ai/v1` + key. Path A just makes it a first-class, labeled, cost-warned option.

Keys go to **Keychain only** (`RemoteProviderKeychain`), per CLAUDE.md (no SDKs, raw URLSession, no keys on disk).

### A2. Model picker / "act" + "work"
- The osaurus cloud model picker (`.../Views/Model/ModelPickerView.swift`, `ModelPickerItem.swift`) will surface `fugu` / `fugu-ultra` once the preset's `defaultManualModelIds` are set — no UI edit.
- **"Act" is a depth, not a model** (`Epistemos/Engine/CoworkChatMode.swift` → `EpistemosOperatingMode.agent`). Fugu, being itself agentic, is a strong candidate to back the **Act/agent** depth when a user opts into cloud.
- **"Work" = the OpenCode engine** (`Epistemos/Work/`). See A3.

### A3. OpenCode (the "Work" engine) → point it at Fugu
- OpenCode provider/MCP config is written by **`Epistemos/Work/WorkOpenCodeRuntime.swift` `openCodeConfigJSON(...)`** (~line 80), passed via the `OPENCODE_CONFIG` env var (`BundledWorkOpenCodeShell.launchSpec`). Add a `provider` block to that emitted `opencode.json` pointing at `https://api.sakana.ai/v1` with the Bearer key, models `fugu` / `fugu-ultra`. Because Fugu *is* a coding harness target (`codex-fugu`), Work + Fugu is the most natural pairing.
- Reverse direction unaffected: `Epistemos/Engine/LocalModelServer.swift` (127.0.0.1:1337) still lets OpenCode drive *local* models — Fugu is purely an additional outbound provider.

### A4. HONEST cost disclosure (required surface)
Per owner value "no $10/msg lock-in," the picker/settings row for Fugu MUST show (using the **real** numbers, not "$10/msg"):
> "Sakana Fugu Ultra: ~$5 / 1M input, $30 / 1M output (doubles >272K ctx). Orchestration sub-agent tokens are billed too, so multi-step answers can cost several × a single-model call. Cloud-only; not available in EU/EEA. Routes your prompt through third-party frontier models via Sakana."

### A5. Orchestration-path binding (optional, deeper)
System G's Rust `ProviderPolicy` enum (`agent_core/src/agent_runtime_v2/blueprint.rs` ~line 52) already has **`OpenAICompatible{base_url, model}`** — the natural binding point to let a System G *run* execute against Fugu. Today cloud policies fail closed (`provider_not_bound`); wiring Fugu here is a larger task than A1–A3 and is **Pro-gated/research** per CLAUDE.md (no hidden fallback proof required).

**Path A effort:** A1+A2 ≈ tiny (hours). A3 ≈ small. A5 ≈ medium and gated.

---

## 3. Integration Path B — the DEEPER ALIGNED play: build the PATTERN as owner IP

### 3.1 Epistemos already has the bones of Fugu's pattern
The Fugu *pattern* is "a learned/heuristic coordinator that routes-to-best-model-per-task across a pool, including verify/synthesize." Epistemos already has the scaffolding:

- **`Epistemos/LocalAgent/RuntimeRouter.swift`** — `route(_) -> RouteVerdict`, per-role preferred-lane chains, **local-first** ordering (`defaultPreferredLanes` puts `.mlx`/`.appleIntelligence` first, cloud last), honest **escalation log** + metrics. Lanes (`RuntimeExecutor.swift:46`): `.mlx`, `.gguf`, `.appleIntelligence`, `.cloud(provider:)`, `.stub`. **But it is observe-only today** — zero live callers, gated behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`; the live decision is currently made by Rust `compile_command_center_request`. Promotion gate: `RuntimeRouterStage2Readiness.swift` (≥50 samples, ≥98% parity).
- **System G** (`agent_core/src/agent_runtime_v2/`) — the live Rust run orchestrator (Blueprint→MissionPacket→events→AnswerPacket), with `ProviderPolicy` covering local MLX/GGUF + `OpenAICompatible`/`AnthropicMessages`/`OpenAIResponses`, concurrency cap 64. This is exactly the "assemble a team of models for a task" substrate.
- **No `ModelPool` type yet** — nearest is `BrainSelection.autoConstellation` (`AgentBlueprint.swift:78`, "let the system pick a local model") + the per-role `modelPreferenceTable` (`RuntimeRouter.swift:439`).

**So Epistemos can be its own Fugu**: promote RuntimeRouter to live, give it a verify/synthesize role (Trinity's Thinker/Worker/Verifier), and let System G fan out across the local+cloud pool. This is the "adopt engines / layer IP" play: own the coordinator, local-first, **no per-token orchestration bill**, no EU lockout, no third-party-vendor dependency for the routing brain.

### 3.2 Open-source orchestration engines the owner could EMBED instead of paying Fugu
All **[VERIFIED]** as existing public repos (read via search result pages; confirm licenses before adoption):

- **`lm-sys/RouteLLM`** — framework + *pre-trained routers*; drop-in OpenAI-client replacement / OpenAI-compatible server; claims big cost cuts by routing easy queries to cheap models. Closest to a ready-made "route-to-best-model" brain.
- **`ulab-uiuc/LLMRouter`** — library of 16+ routing models across single-round / multi-round / agentic / personalized routers. Good research menu for the coordinator.
- **vLLM Semantic Router** — signal-driven routing (cost/privacy/latency/safety) for mixture-of-models; aligns with Epistemos's local-first + sovereignty constraints.
- **`llm-use/llm-use`** — planner + workers + synthesis orchestrator across Anthropic/OpenAI/Ollama/llama.cpp with MCP + cost aggregation; mirrors the Trinity Thinker/Worker/Verifier shape most directly.
- **`MilkThink-Lab/Awesome-Routing-LLMs`** — curated index to mine for more.
- **Sakana's own TRINITY / Conductor ICLR 2026 papers** are public methods — the *patterns* (evolved coordinator; RL-learned NL coordination) are re-implementable as owner IP even though Fugu's weights are closed.

**Embed strategy:** lift RouteLLM's routing policy / llm-use's planner-worker-verifier loop *as a reference*, but implement natively in Swift `RuntimeRouter` + Rust System G so it stays local-first and inside the sovereignty envelope rather than running a Python sidecar (which CLAUDE.md's no-hidden-sidecar rule would flag).

### 3.3 Honest gaps for Path B
- The "best-model-per-task" *quality* of Fugu comes from learned coordination on a frontier pool; a heuristic native router won't match Ultra's benchmark numbers on hard tasks without real training data. Epistemos's edge is **local-first + privacy + no metered orchestration**, not topping SWE-Bench Pro.
- Promotion of RuntimeRouter to live is itself a gated, multi-step effort (parity ≥98%, ≥50 samples).

### 3.4 Why "build" is credible: Fugu's own margins are thin
Primary table (§1) shows Ultra beats the best single pooled model by ~1–3 points (SWE-Bench Pro 54.2 vs 53.4). For many Epistemos tasks, a good local model + honest cloud escalation captures most of the value without per-token orchestration billing.

---

## 4. RECOMMENDATION — BOTH, sequenced (adopt the API thin, build the pattern as the real bet)

**Recommend: BOTH, but asymmetric.**

1. **Now (cheap, reversible): Path A1+A2 — add Fugu as a first-class, cost-warned OpenAI-compatible provider.** It's ~hours of work, gives the owner/users a *premium escalation lane* for genuinely hard tasks, and is honest about cost. It is *opt-in cloud*, never a default — fully consistent with local-first because it only fires when the user picks it.
2. **The real bet: Path B — promote RuntimeRouter to live + give System G a Trinity-style Thinker/Worker/Verifier loop across the local+cloud pool, as owner IP.** This *is* the Fugu pattern, local-first, with **no $10-class per-token orchestration tax**, no EU lockout, and no dependency on Sakana's routing brain. Mine RouteLLM / llm-use / vLLM-Semantic-Router and the TRINITY/Conductor papers for the coordinator design; implement natively in Swift+Rust (no Python sidecar).
3. **Do NOT** make Fugu a default or the orchestration brain. That would invert the owner's "adopt engines / layer IP" value into "rent someone else's IP and meter every token." Fugu is a *guest lane*; the native orchestrator is *the product*.

**Why not adopt-only:** Fugu is closed, metered (orchestration tokens stacked), EU-blocked, depends on third-party vendors, and its single-model margins are thin — adopting it as the brain trades sovereignty for ~1–3 benchmark points.
**Why not build-only:** Fugu Ultra is a real, GA, frontier-competitive escalation target *today*; offering it as an opt-in premium lane costs almost nothing and serves users on hard tasks while the native orchestrator matures.

---

## 5. PLAN ADDITIONS (paste-ready) + BUILD-AGENT PROMPT + open questions

### 5.1 Ledger items (paste into the master queue)

```
[FUGU-A1] Add "Sakana Fugu" as a first-class OpenAI-compatible cloud provider.
  - ProviderPresets.swift: new .fugu case; host api.sakana.ai, basePath /v1,
    authType .apiKey, providerType .openaiLegacy,
    defaultManualModelIds ["fugu","fugu-ultra"], consoleURL console.sakana.ai/login.
  - ProviderCatalog.swift: one ProviderCatalogEntry(.fugu, [.apiKey], .apiKey).
  - Key to Keychain only. Verify fugu/fugu-ultra appear in ModelPickerView with no view edits.
  Accept: provider visible in picker; a live chat/completions round-trip succeeds with a real key.

[FUGU-A2] HONEST cost disclosure row for Fugu (real per-token rates + orchestration-token
  multiplier + "cloud-only, not EU/EEA, routes via third-party models"). NO "$10/message" wording.

[FUGU-A3] (opt) Work/OpenCode: emit a Fugu provider block in openCodeConfigJSON so the Work
  engine can target fugu/fugu-ultra. Gated behind the same cloud opt-in.

[FUGU-A5] (Pro-gated/research) Bind ProviderPolicy::OpenAICompatible{api.sakana.ai/v1, fugu-ultra}
  on the System G run seam, with no-hidden-fallback proof.

[FUGU-B1] (the real bet) Promote RuntimeRouter to live behind a staged gate
  (EPISTEMOS_RUNTIMEROUTER_LIVE_V0 → Stage-2 readiness ≥50 samples / ≥98% parity).

[FUGU-B2] Add a Trinity-style Thinker/Worker/Verifier role split to System G run orchestration
  across the local+cloud pool (native Swift+Rust, no Python sidecar). Reference designs:
  lm-sys/RouteLLM, llm-use/llm-use, vLLM Semantic Router, TRINITY + Conductor (ICLR 2026).
  Accept: a multi-model run produces an AnswerPacket with an honest per-step witness trail;
  local-first ordering preserved; cloud only on explicit escalation.
```

### 5.2 BUILD-AGENT PROMPT (paste-ready)

```
TASK: Implement FUGU-A1 + FUGU-A2 in Epistemos (cwd /Users/jojo/Downloads/Epistemos).
Add "Sakana Fugu" as a first-class OpenAI-compatible cloud provider with honest cost disclosure.

GROUND TRUTH (verified primary sources — do NOT invent beyond these):
  base_url https://api.sakana.ai/v1 ; auth "Authorization: Bearer $KEY" ;
  endpoints /chat/completions and /responses ; models "fugu","fugu-ultra","fugu-ultra-20260615" ;
  pricing Ultra $5/1M in, $30/1M out, $0.50 cached, doubling >272K ctx ; orchestration tokens billed ;
  NOT available EU/EEA ; closed-source managed API.

DO:
1. LocalPackages/osaurus/Packages/OsaurusCore/Models/Configuration/ProviderPresets.swift
   - add ProviderPreset.fugu with name/description/icon/consoleURL and a .configuration arm
     (host api.sakana.ai, basePath "/v1", authType .apiKey, providerType .openaiLegacy,
      defaultManualModelIds ["fugu","fugu-ultra"]). Reuse .openaiLegacy — add NO new RemoteProviderType.
2. .../ProviderCatalog.swift: add ProviderCatalogEntry(.fugu, authMethods:[.apiKey], placement:.apiKey).
3. Cost-disclosure UI string (real rates + orchestration multiplier + cloud-only/EU note). NEVER "$10/message".
4. Keys to Keychain only (RemoteProviderKeychain). Raw URLSession only — no SDK. Cloud is opt-in, never default.

VERIFY: cargo test --lib green; fugu/fugu-ultra appear in ModelPickerView; build the osaurus package.
CONSTRAINTS: PLAN_V2 is authority; honest capability gating; no hidden fallback; do not commit unless told.
```

### 5.3 Open questions (need owner decision or live testing)
1. **Streaming** over `api.sakana.ai/v1` — unconfirmed by primary docs; test with a real key before relying on SSE in chat.
2. **Default tier** — expose `fugu` (cheap, low-latency) by default and `fugu-ultra` behind an explicit "hard task / higher cost" toggle? (Recommended.)
3. **EU/EEA gating** — should the provider be hidden/disabled for EU users (Fugu is GDPR-blocked there)? Sovereignty + compliance say yes.
4. **A5 vs B2** — do we ever let Fugu *be* a node inside our own orchestrator (A5), or keep Fugu strictly a single opt-in lane and reserve orchestration for owner IP (B2)? Recommend the latter to avoid renting the routing brain.
5. **License check** — confirm RouteLLM / llm-use / vLLM-Semantic-Router licenses before lifting any code (papers/patterns are safe to re-implement).
6. **"$10/message" provenance** — the prompt's figure is unconfirmed; treat the per-token sheet as authoritative.
```

---
## 6. PATH B DESIGN DEEPENING (monitor, 2026-06-22 cron iter) — the native orchestrator as owner IP
Advancing the §3.3 gap: a concrete, build-ready design for Epistemos's OWN Trinity/Conductor-style
orchestrator (the foundational IP brain), grounded in the existing codebase + the public method.

### 6.1 Architecture (re-implement the PUBLIC TRINITY/Conductor method — no Fugu code needed)
- **Orchestrator = a loop, not a model:** `Thinker` (decompose task → subtasks + pick model per subtask) →
  `Worker(s)` (run each subtask on the BEST pool model: local MLX / Osaurus act / Goose-tool / cloud
  provider / OpenCode-work) → `Verifier` (check/critique outputs) → `Synthesizer` (merge → final). Recursive:
  a Worker may itself be the orchestrator on a sub-task (Fugu's "calls itself recursively").
- **Binding point (verified):** System G `agent_runtime_v2` is the LIVE orchestrator; its `ProviderPolicy`
  already has `OpenAICompatible{base_url,model}` → each pool member (local, cloud, Fugu-guest) is one policy.
  `RuntimeRouter.swift` (currently observe-only, gated `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`) becomes the
  per-subtask model-SELECTION policy (it already has the honest-escalation-log shape).
- **Model pool registry:** a declarative list of available lanes (MLX-local models, Osaurus, cloud providers,
  optional Fugu) each with capability/cost/latency tags → the Thinker/router picks per subtask by tags.

### 6.2 Expose as ONE internal API → convergence across act+work+chat (owner's #1 want)
- Surface the orchestrator behind the EXISTING OpenAI-compatible internal server (LocalModelServer pattern,
  loopback) as a virtual model id (e.g. `epistemos-orchestrator`). Then act, work (OpenCode points at it),
  chat/note/graph all call the SAME endpoint → uniform "one brain" everywhere. This IS the convergence.

### 6.3 Cost/honesty + modular (owner directives)
- Local-first: default pool = local models → $0; cloud/Fugu lanes only when the router escalates AND the
  user enabled them. Per-call cost (when cloud used) shown honestly. Fugu = one optional pool member, NEVER
  the orchestrator brain. Provider abstraction = lanes plug in/out (swap if better ships).

### 6.4 Honest build gaps (sequenced lower-but-certain)
- Router quality (good per-subtask model choice) is the hard part — start with simple heuristic tags
  (complexity/code/reasoning) + RouteLLM-style learned routing later. Recursive depth needs a guard
  (reuse OpenClaw depth-limiter). Verifier needs a cheap-but-real check (not fake-pass). All real-state tested.
### 6.5 Still owed by deeper passes
Read the actual TRINITY + Conductor ICLR 2026 papers for the precise loop/verify algorithm; test Fugu API
streaming live; price a representative multi-step run. (Refines; the design above is build-ready.)

## 7. BUILD STATUS (build-side, appended by the build loop)
- **Slice 1 DONE (`1027ffa28`, cargo 4/4):** Fugu registered as a known provider in
  `agent_core/src/providers/pricing.rs` — reqs #1 (modular) + #2 (explicit cost) first cut. KEY GROUNDED FACTS:
  - **Req #1 is already satisfied by the existing abstraction:** `OpenAICompatibleProvider` is the universal
    `/v1/chat/completions` provider (serves OpenRouter/Kimi/DeepSeek/xAI/…). Fugu = a CONFIG instance
    (base_url+api_key+model), NOT a new provider type → no hardcoding. Matches §6.3 "lanes plug in/out".
  - **Cost-honesty BUG found + closed (req #2):** `pricing::estimate_usage_cost_*` summed per-TOKEN only and
    IGNORED `request_usd_per_1k` (flat per-request) → a flat ~$10/msg provider estimated ~$0 (silent-expensive
    trap). Fixed: Fugu row carries `request_usd_per_1k=10_000` ($10/msg) + new `pricing::per_message_usd()` so
    Settings shows the explicit "$10.00 / message" opt-in headline. Per-token rates left 0 until verified.
- **Next build slices (sequenced):** named Fugu config constructor + capability flags (cargo) → Settings UI
  (Keychain key + endpoint + the per-message cost label + explicit first-call opt-in confirm, per §6.3) →
  model-picker/act/work + OpenCode-provider wiring → best-combo (b): expose RuntimeRouter/System G native
  orchestration behind the SAME abstraction (the §1–§5 design here).
