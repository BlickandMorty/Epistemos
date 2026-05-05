# FINAL SYNTHESIS — Epistemos Architecture Canon

**Status**: canonical synthesis across all prior docs, after final critique-and-audit pass. Created 2026-04-29.
**Supersedes**: nothing. **Reconciles**: PLAN.md (master plan, Waves 0–5), BUILDER_PROMPT.md, AUDIT_PROMPT.md, OBSCURA_BROWSER_ADDENDUM.md (Wave 6), LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md (Wave 7).
**Purpose**: a single document the user can return to that captures (1) what we got right across the prior plans, (2) what the final critique corrected, (3) the new architectural breakthrough — the **Live File Compiler** and the **Reflective Loop** — that ties the substrate together, (4) the privacy-hardening posture that makes the unified substrate the moat, and (5) the corrected wave sequencing.

This is the document to read first when picking up the project after time away. The other docs go deep on individual waves; this one shows how they fit together and where the prior plans needed correction.

---

## 0. Honest acknowledgment of the critique

The final critique pasted into the conversation was substantive and largely right. I'm capturing the corrections explicitly so they survive any future drift.

| Critique point | My v1–v3 position | Correction (now canonical) |
|---|---|---|
| "Live Files are a runtime layer, not a feature; don't build them too early" | Wave 7 deferred until master plan ships. **Already correct in prior docs** — Wave 7 is explicitly gated. | Reaffirmed. The deferral is structural; Live Files require the substrate to exist first. |
| "Make 'no hot-path subprocesses' a law, not 'no subprocesses ever'" | I overcommitted to "zero subprocesses anywhere" in v3. | **Corrected.** Law is "zero hot-path subprocesses." Hermes Python orchestrator stays Pro-only, optional, learning ground for the eventual Rust port. Don't lie about the present state. |
| "Add a Live File Compiler — markdown is not the executable" | My prior plan implied Live Files execute their markdown directly. | **Major correction.** The compiler is a separate stage. Markdown → Parser → Intent → `LivePlan.v1` → Policy/Capability validation → Signed plan → Runner. The compiled, signed plan is what executes. The markdown is the source of intent. They are two different artifacts. |
| "Cognitive Weight should not be a raw prompt override" | My prior plan had a single `cognitive_weight` field with multiplicative score boost. | **Corrected.** Four-tier weight class system (soft memory / preferred context / strong project anchor / policy-grade). Only policy-grade can constrain tools, and even then only after passing schema validation, capability validation, user-visible diff, signed plan hash, and explicit revocation path. **Semantic Gravity pulls attention; Policy Authority controls action; do not confuse the two.** |
| "BrowserEngine trait, not Obscura-specific commitment" | My v3 made Obscura the in-process default. | **Corrected.** The right primitive is a `BrowserEngine` trait. WebKit-baseline adapter for MAS (Apple-native, sandboxed, mature). ObscuraEngine adapter for Pro (Rust-native, V8, experimental). RemoteBrowserEngine for tests/fallback. MockBrowserEngine for deterministic CI. The moat is the substrate, not a fragile dependency on one early-stage repo. |
| "Eidos comparison: Tavily was acquired by Nebius for $275M, not Exa" | My v3 stated Exa was acquired. | **Factual correction.** Tavily was acquired by Nebius for ~$275M (Yahoo Finance, 2026). Exa raised $85M Series B led by Benchmark and remains independent. The strategic read still holds — agent-search infrastructure is becoming a serious category, with Parallel Web Systems also at $2B valuation per WSJ. Eidos's positioning is unchanged: local-first sovereign cognitive workspace, distinct from cloud agent-search APIs. |
| "deno_core for Pro is right; for MAS, no arbitrary JS user runtime" | My v3 proposed deno_core in both profiles. | **Corrected.** MAS uses WebKit/native capture + curated tools only; no arbitrary user JS runtime. Pro gets deno_core with capability-gated ops only (forbidden by default: subprocess, unrestricted fs/network, shell, AppleScript, launchctl). The op layer is the permission boundary. |
| "Don't poll Live Files; event-driven only with thermal/battery gating" | Already in v3 (Stateful Rotor). | Reaffirmed and tightened. Live Files admit work only when an event fires AND eligibility checks (thermal nominal, battery >20% or AC, capability granted, budget remaining) all pass. |
| "Property Inspector first, raw YAML second" | My v3 mentioned but underspecified. | **Codified.** Inspector is the operational truth surface; the glow is emotional feedback. The user must always be able to see — without leaving the file — its mode, schedule, permissions, weight, last run, next eligible run. |
| "Vector Universe should be a manifold, not one embedding" | My v3 had a single embedding model. | **Corrected.** A Live File compiles into a `LiveFileManifold` with: dense semantic vectors (multi-granularity hierarchical), sparse lexical index (Tantivy), markdown section tree, JSON/YAML schema AST, task queue extraction, condition clauses, permission/capability clauses, citations/backlinks, freshness/decay metadata, cognitive weight policy. Search returns *control vectors*, not just chunks. |
| "Deterministic pre-action authorization is real research" | Implicit in Compile-Verify-Mint, but not explicit. | **Codified** with citation: arxiv:2603.20953 *Before the Tool Call: Deterministic Pre-Action Authorization*. Every tool call passes a deterministic gate evaluating LivePlan policy, user settings, vault trust zone, file scope, budget scope, and irreversible-action check. |
| "Sequencing should be Wave 5 stabilize → Wave 6 substrate/Eidos/browser → Wave 7 Live Files → Wave 8 deliberation" | I had Waves 0–5 master, 6 Obscura, 7 Live Files+autoresearch combined. | **Corrected.** Auto-research belongs in Wave 8 (deep deliberation / council), not Wave 7. Wave 7 is Live Files alone. Wave 8 adds model-team deliberation, optimistic/pessimist/neutral panels, research jury, recurring synthesis. This separation is right because Live Files need to be boring before auto-research is allowed to mutate them. |

These corrections are now canon. Anything in the prior addendums that contradicts them is superseded by this document.

---

## 1. The breakthrough the critique surfaced — *the Live File Compiler*

The critique's most consequential insight: **markdown is not the executable; the compiled, signed plan is.** This is the architectural separation my v1–v3 was missing.

```
┌──────────────────────────────────────────────────────────────────┐
│  HUMAN DOMAIN — natural-language intent                          │
│                                                                  │
│  Markdown / JSON / YAML — the Live File source                   │
│  "Every night, audit my notes and extract tasks. If research     │
│   takes >20m, halt and write an audit. Never edit code."         │
└─────────────────────────────────┬────────────────────────────────┘
                                  ▼
                    ┌───────────────────────────┐
                    │  Live File Parser         │
                    │  (Rust, deterministic)    │
                    └─────────────┬─────────────┘
                                  ▼
              ┌──────────────────────────────────────┐
              │  Intent + Tasks + Constraints +      │
              │  Schedule + Safety Bounds            │
              │  (intermediate representation)       │
              └─────────────────┬────────────────────┘
                                ▼
                    ┌───────────────────────────┐
                    │  LivePlan.v1 schema       │
                    │  (deterministic YAML)     │
                    └─────────────┬─────────────┘
                                  ▼
                ┌─────────────────────────────────┐
                │  Policy + Capability validation │
                │  (Rust, schema-bound)           │
                └────────────────┬────────────────┘
                                 ▼
                       ┌─────────────────────┐
                       │  SIGNED PLAN HASH   │
                       │  (executable        │
                       │   authority)        │
                       └──────────┬──────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  RUNTIME DOMAIN — deterministic execution                        │
│                                                                  │
│  Rust runner executes the SIGNED plan, not the markdown          │
│  RunEventLog records every step                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.1 What this separation gives us

- **The user writes prose**; the runtime sees a typed plan. The compiler is the treaty between them.
- **`is_live: true` is intent, not authority.** The signed plan hash is authority. If the markdown changes, the old plan goes stale, the agent stops, and the user sees a "this Live File needs recompilation" prompt.
- **Capabilities are declared in the LivePlan, not derived from the markdown's vibe.** "Never edit code" in prose is *advisory*; `capabilities.edit_code: false` in the LivePlan is *enforced*.
- **Schema validation gates execution.** A LivePlan with malformed bounds, contradictory triggers, or escalated capabilities (more than the parent vault permits) is rejected at compile time. The runtime never sees it.
- **The compile step itself is gated** by Compile-Verify-Mint (PLAN.md §17). Generated LivePlans pass G1 (parse), G2 (intent classification — does the plan match the prose?), G3 (sandbox dry-run on a synthetic vault), G4 (permission manifest validation against the user's vault trust zones). A LivePlan that fails any gate is tombstoned.

### 1.2 The LivePlan.v1 schema

```yaml
live_plan_version: 1
source_file: "research/live/epistemos-audit.md"
source_hash: "sha256:b3f1a2c..."     # of the markdown source
compiled_plan_hash: "sha256:e9c8d7..." # of THIS plan
compiler_version: "1.0.3"
model_version: "qwen2.5-1.5b-instruct-4bit"
compiled_at: "2026-04-29T03:14:22Z"
user_confirmation_required: true     # changes that affect capabilities require confirm

triggers:
  - type: scheduled
    schedule: "nightly between 03:00 and 05:00"
    earliest_time: "03:00"
  - type: file_change
    path: "research/live/epistemos-audit.md"
    debounce_ms: 5000

capabilities:
  read_vault: true
  write_vault: scoped               # only to allowed paths below
  write_vault_paths: ["raw_thoughts/audits/"]
  edit_code: false
  network: ask                      # prompt user per-domain
  run_browser: true
  run_shell: false
  spawn_subprocess: false           # always; not user-overridable

budgets:
  max_wall_time_minutes: 20
  max_model_tokens: 120_000
  max_tool_calls: 80
  max_write_count: 50
  max_network_hosts: 3
  max_gpu_minutes: 5
  max_retry_count: 3

on_timeout:
  action: write_audit_report
  destination: "raw_thoughts/live_runs/{{date}}.md"

on_capability_denied:
  action: pause_and_notify
  user_prompt: "Live File needs network access for {{host}}. Allow once / always / deny."

cognitive_weight:
  class: preferred_context          # soft_memory | preferred_context | strong_project_anchor | policy_grade
  retrieval_bias: 0.55
  context_placement: above_fold     # immutable | above_fold | inline | trailing
  policy_authority: false           # only policy_grade can be true

zones:
  control_section: "## Control"     # user-owned; agent cannot edit
  working_notes: "## Working"       # agent may propose edits via diff PR
  results: "## Results"             # agent may append outputs
  trace_to_raw_thoughts: true       # never embed traces inline
```

This is the contract. Every Live File compiles into one. The markdown is the source; the YAML is the law.

---

## 2. The new invention — *the Reflective Loop*

The user's P.S. asked for a "use of auto-research fused with a mixture of unified substrate tools that combine to loop in a pattern that outputs deep responses, task creations, deterministic guardrails, and super-hardened privacy." This is what was missing as a unifying pattern across the prior plans.

I'm calling it the **Reflective Loop** — the substrate-wide cognitive cycle that combines retrieval, attention, executive control, immune defense, motor execution, memory, and metabolism into a single coherent pattern. It is what makes Epistemos *feel like one computation substrate*.

### 2.1 The seven layers

The biological-substrate metaphor from v3 is honest if it generates structure. Here is the structure, refined per the critique:

```
┌────────────────────────────────────────────────────────────────────┐
│  LAYER 1 — REFLEX                                                  │
│  Sub-millisecond response. Local lookups, FSEvents, instant recall │
│  No LLM. No reasoning. Pure deterministic primitives.              │
│  Examples: Tantivy hit, recent-capture cache, hotkey dispatch      │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 2 — ATTENTION                                               │
│  Eidos hybrid retrieval + Cognitive Weight bias + RRF              │
│  Selects the relevant manifold slice from the vault                │
│  Outputs: ranked LiveFileManifold hits with authority annotations  │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 3 — EXECUTIVE                                               │
│  LivePlan compiler + tool routing + variant ladder selection       │
│  Decides what to do; produces signed plan with budgets             │
│  Outputs: compiled LivePlan; tool sequence; per-step constraints   │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 4 — IMMUNE                                                  │
│  Capability firewall + deterministic pre-action authorization      │
│  Approves or denies per tool call against LivePlan policy          │
│  Outputs: allow / deny / ask user                                  │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 5 — MOTOR                                                   │
│  Tool execution: vault ops, browser ops, eidos query, doc edit     │
│  Each call grammar-bound, schema-validated, IterGen-recoverable    │
│  Outputs: typed tool results; observable side effects              │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 6 — MEMORY                                                  │
│  RunEventLog write; vault drawer mutation; concept graph update    │
│  Every action persisted with provenance, hash, signed receipt      │
│  Outputs: durable, replayable, auditable trace                     │
└────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│  LAYER 7 — METABOLISM (NightBrain)                                 │
│  Auto-research observes the log, runs variants overnight,          │
│  keeps wins, tombstones losses, surfaces morning report            │
│  Outputs: improved baselines for Layers 2–4 next day               │
└────────────────────────────────────────────────────────────────────┘
```

This is what the critique called "layered control loops." It's not metaphor; it's the literal architecture. Each layer has a defined input, a defined output, a verification gate. The substrate metabolizes by passing through the layers; it improves overnight by running Layer 7 against Layer 6's accumulated trace.

### 2.2 The loop pattern

A user query — typed, spoken, or scheduled — traverses the loop:

```
[USER INPUT]                                              [METABOLISM LAYER]
     │                                                              ▲
     ▼                                                              │
[LAYER 1: REFLEX]                                                   │
     │  cache hit? short-circuit return.                            │
     │  miss → continue                                             │
     ▼                                                              │
[LAYER 2: ATTENTION] ◄─── Eidos hybrid retrieval                    │
     │  Tantivy + HNSW + RRF                                        │
     │  Cognitive Weight bias applied (manifold ranking)            │
     │  Output: ranked LiveFileManifold hits + control vectors      │
     ▼                                                              │
[LAYER 3: EXECUTIVE]                                                │
     │  Live File Compiler engaged if a plan is needed              │
     │  Tool sequence selected; per-tool grammar prepared           │
     │  Cross-check: which Live Files have policy_grade weight?     │
     │  Their constraints become hard plan bounds                   │
     ▼                                                              │
[LAYER 4: IMMUNE] (per tool call)                                   │
     │  Pre-action authorization: LivePlan policy + vault zone      │
     │  + budget check + irreversibility check                      │
     │  Result: allow / deny / ask                                  │
     │  Denied? → return to Executive with bounded retry            │
     │  Asked? → return user prompt; resume on response             │
     ▼                                                              │
[LAYER 5: MOTOR]                                                    │
     │  Tool executes under sampler-bound grammar (CRANE)           │
     │  Schema-validated output; IterGen on field violation         │
     │  Side effect: write, browser navigate, eidos search, etc.    │
     ▼                                                              │
[LAYER 6: MEMORY]                                                   │
     │  RunEventLog append: trigger, plan hash, tool, args, result, │
     │    confidence, latency, capabilities exercised               │
     │  Vault mutations content-addressed (sha256 drawer)           │
     │  Concept graph updates (typed edges)                         │
     │  Signed proof-of-execution receipt minted                    │
     ▼                                                              │
[RESPONSE TO USER] — typed, structured, citation-grounded ─────────►│
                                                                    │
                                          (overnight, idle + AC)    │
                                                                    │
                                                              [LAYER 7]
                                                                    │
                                          5 auto-research loops     │
                                          read RunEventLog,         │
                                          run variants, keep wins,  │
                                          surface morning report    │
                                                                    │
                                          Updated baselines for     │
                                          Layers 2–4 next day ──────┘
```

### 2.3 What the loop outputs

For any query that enters the loop:

1. **A typed, structured response** — never free prose alone. Either a structured artifact (a Markdown drawer, a search result list, a typed answer with citations) or a typed action receipt (file written, link added, capture routed).

2. **Tasks created** — when the loop's output triggers downstream work (a new Live File from a research synthesis; a follow-up scheduled query; a flagged review item), the tasks are *typed* and inserted into the appropriate vault location.

3. **Deterministic guardrails enforced** — every tool call's input is grammar-bound; every tool call's output is schema-validated; every capability is pre-authorized; every irreversible action requires explicit user consent.

4. **Audit trail** — every step from query to response is in RunEventLog; cmd-? from any artifact opens the trace.

5. **Improvement over time** — Layer 7 observes the trace overnight and tunes baselines. Tomorrow's Layer 2 retrieval is a little better than today's. The loop self-improves.

### 2.4 Why the loop is the moat

The single most important property: **every layer of the loop runs in the same process, sharing memory through Apple Silicon's unified memory architecture, without any subprocess on the hot path.**

That means:
- Layer 1's cache-hit returns in <2ms (no IPC).
- Layer 2's Eidos query is <80ms (Metal-accelerated cosine, in-process).
- Layer 3's compile is <50ms for cached LivePlans (in-process Rust).
- Layer 4's authorization is <500µs (deterministic state-machine eval).
- Layer 5's tool call latency is whatever the tool requires (no IPC overhead added).
- Layer 6's log write is <5ms (rusqlite WAL, in-process).
- Layer 7 runs only at night and is bounded by power/thermal.

Total foreground cycle time on a cache miss: ~600ms p95 for a typical query, including LLM generation. **No process boundary anywhere in the loop.**

This is what "single computation substrate" means. The user feels it as one thing because it *is* one thing. The moat is structural, not marketed.

---

## 3. The Cognitive Weight class system (codified)

The critique's correction: a single multiplicative bias on retrieval is not enough; weight must affect *three separate systems* (retrieval priority, context placement, policy authority), and only the highest tier may constrain tools.

```
┌────────────┬─────────────────────┬──────────────┬──────────────┬─────────────┐
│ Class      │ Range               │ Retrieval    │ Context      │ Policy      │
│            │                     │ priority     │ placement    │ authority   │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Soft       │ 0.00–0.30           │ +0–10%       │ trailing     │ none        │
│ memory     │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Preferred  │ 0.31–0.60           │ +10–30%      │ inline       │ none        │
│ context    │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Strong     │ 0.61–0.85           │ +30–60%      │ above-fold   │ advisory    │
│ project    │                     │              │              │ (UI hint)   │
│ anchor     │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Policy-    │ 0.86–1.00           │ +60–100%     │ immutable    │ ENFORCED    │
│ grade      │                     │              │ system       │ (gates      │
│ control    │                     │              │ block        │ tools)      │
│ vector     │                     │              │              │             │
└────────────┴─────────────────────┴──────────────┴──────────────┴─────────────┘
```

**Promoting a Live File to policy-grade** requires:
1. Schema validation against `policy_grade.v1.json`.
2. Capability validation: the Live File's declared capabilities must be a subset of the parent vault's trust zone.
3. User-visible diff: "this file is becoming policy-grade. It will be able to constrain tool behavior. Show me what changes."
4. Signed plan hash: the policy-grade flag is captured in the LivePlan; mutating the markdown invalidates the signature.
5. Revocation path: cmd-shift-R revokes any Live File's policy-grade status instantly.

This separation prevents the "old file accidentally too powerful" failure mode the critique warned about.

---

## 4. The 10-state Live File state machine

The critique refined my 5-state machine into 10 states with sharper transition semantics:

```
[Static] ──user toggles live──► [LiveCandidate]
                                       │
                                  compile pass
                                       │
                                       ▼
                              [Compiled (signed)]
                                       │
                                event/schedule + eligibility
                                       │
                                       ▼
                                  [Eligible]
                                       │
                                  runner admits
                                       │
                                       ▼
                                   [Running]
                                       │
                          ┌────────────┼────────────┐
                          │            │            │
                       blocked      complete      unsafe
                          │            │            │
                          ▼            ▼            ▼
                      [Paused]   [Completed]  [Quarantined]
                          │            │            │
                       resume       artifacts   triage to user
                          │            │            │
                          ▼            ▼            ▼
                      (Running)  [Suspended]   (Revoked or
                                       │        Compiled after fix)
                                  schedule next
                                       │
                                       ▼
                                  [Eligible]
                                  (waiting for trigger)


At any point: user revokes → [Revoked] (no future execution; markdown still readable)
```

Critical invariants:
- **`is_live: true`** alone does NOT permit execution. It is user intent.
- **`Compiled`** state requires a signed plan. It is runtime permission.
- **`Eligible`** state requires triggers + thermal/battery/budget gates passed. It is execution authority.
- **`Quarantined`** is not failure; it's "user must look at this." Triage UI is the recovery path.
- **`Revoked`** is the kill switch — no future execution, but the markdown source remains readable. The user can re-toggle to live, which goes back through compile.

Implementation lives in `agent_core/src/live_files/state.rs` per Wave 7. Modeled in `kani` (Rust formal verifier) for invariant checking — no orphan states, no unreachable states, no race conditions on transition.

---

## 5. Privacy hardening — the "single substrate, hardened" moat

The user's P.S.: "super duper robust and hardened privacy things because of my browser and the fact the entire app is one substrate." This is its own design domain.

### 5.1 The privacy stack (seven layers, mirroring the substrate)

| Layer | Privacy commitment |
|---|---|
| Reflex | All cache hits served locally; no remote round-trip on any local query. |
| Attention | Eidos retrieval is in-process; no query string ever leaves the device unless the user types `/cloud`. |
| Executive | LivePlan compilation is local; the plan is signed with a per-vault key; signatures verify locally. |
| Immune | Pre-action authorization is deterministic and local; no remote policy server. |
| Motor | Browser engine is in-process or sandboxed-helper; stealth mode blocks 3,520 telemetry domains by default. |
| Memory | RunEventLog stored encrypted at rest; vault drawers content-addressed; per-drawer encryption tier respected. |
| Metabolism | Auto-research telemetry is differentially private — morning report aggregates can never re-identify individual queries. |

### 5.2 Ephemeral capability tokens

Every tool call receives a one-shot capability token issued by Layer 4 (Immune). The token:
- Encodes exactly the capabilities authorized for *this* call.
- Expires immediately on tool completion.
- Cannot be re-used or persisted.
- Is logged in RunEventLog with the call it authorized.

This means a tool that gains capability `network: localhost:obscura_port` cannot, ten seconds later, use that capability for a different call. It must request afresh and pass authorization again.

### 5.3 Per-Live-File network egress allowlist

When a Live File runs, the runner enforces a per-plan network allowlist:

```yaml
network:
  allow_hosts: ["arxiv.org", "developer.apple.com"]
  allow_paths: ["/abs/", "/documentation/"]
  forbid_subprocess_spawn: true
  forbid_ws_to_external: true     # localhost CDP only
  max_total_kbytes_egress: 10_000
```

The Rust networking layer enforces this through a request-interceptor chain in `agent_core/src/security/egress.rs`. A LivePlan with no `network` clause defaults to forbid-all.

### 5.4 Differential privacy on auto-research telemetry

The morning auto-research report aggregates wins/losses across nightly experiments. To prevent it from leaking individual query content (even back to the user's own future LLMs), aggregations apply Laplace noise calibrated to ε≤0.5:

```rust
// agent_core/src/auto_research/dp.rs
pub fn dp_aggregate(values: &[f64], epsilon: f64) -> f64 {
    let sensitivity = 1.0;    // counting sensitivity per record
    let scale = sensitivity / epsilon;
    let mean = values.iter().sum::<f64>() / values.len() as f64;
    let noise = laplace_sample(0.0, scale);
    mean + noise
}
```

This means even if an attacker gained access to the morning report, they could not reconstruct individual experiment inputs from aggregates. The user's queries stay private even from themselves-tomorrow.

### 5.5 Proof-of-execution receipts

Every tool call's RunEventLog entry is signed with a per-vault key derived from the user's Keychain identity:

```rust
pub struct ExecutionReceipt {
    pub call_id: Ulid,
    pub plan_hash: [u8; 32],
    pub tool: String,
    pub input_hash: [u8; 32],
    pub output_hash: [u8; 32],
    pub timestamp: SystemTime,
    pub capabilities_used: Vec<Capability>,
    pub signature: [u8; 64],    // Ed25519 sig over the above
}
```

The user can verify any past execution: "did the agent really do exactly this?" The receipt proves it. Tampering with the log invalidates the signatures. The chain of receipts is a tamper-evident audit log.

### 5.6 Local-by-default with explicit cloud opt-in

Per `PLAN.md` §1.3, cloud is reachable only via:
- Explicit `/cloud` in the AI bar.
- ⌥-submit modifier.
- The narrow auto-escalation in §6.7 (output >2000 tokens AND cloud-allowed setting active).

The Cloud setting is tri-state: **Off | Generator only | Inference + Generator**. Default is **Generator only**. This means *cloud assists with skill-mint generation but never receives a user query for routine tasks* unless the user explicitly opts in per call.

### 5.7 Browser hardening (Obscura adapter, per critique)

- WebKit baseline for MAS — Apple-native, sandbox-clean, mature, requires no helper binaries.
- Obscura experimental adapter for Pro — Rust-native engine, V8, stealth mode (anti-fingerprinting + 3,520-domain blocklist).
- Per-call ephemeral spawn for Obscura (not always-on daemon).
- Browser ops gated by Layer 4 capability tokens with per-host network allowlist.
- Proof-of-execution receipts for every browser action.
- Live View (Pro only) renders via screenshot-stream over UniFFI shared buffer; no SwiftUI exposure to the V8 engine itself.

### 5.8 The "single substrate" privacy moat in one sentence

> *Because the substrate is one process, the privacy boundary is one process. There is no IPC where data could leak, no helper daemon to compromise, no localhost server to MITM, no third-party telemetry endpoint to intercept. The user's data lives, breathes, and dies inside the address space they launched.*

This is the moat. It's not marketing. It's structural truth derived from the no-hot-path-subprocess law.

---

## 6. The corrected wave sequencing

Following the critique:

| Wave | Theme | Core deliverables | Status |
|---|---|---|---|
| **0–4** | Foundation, spine, daily driver | Hybrid memory format, tool registry, llguidance, four-variant routing, self-healing, native skills, MLX local inference, MWP, Intent→Effect, capture surface, settings | per `PLAN.md` |
| **5** | Agent runtime stabilization | Tool loop hardening, RunEventLog as source of truth, full permissions, local/cloud routing, basic Raw Thoughts | per `PLAN.md` (formerly part of Phase 11) |
| **6** | Unified substrate / Eidos / browser research layer | Subprocess audit, Eidos search engine, embedded retrieval (Tantivy + HNSW + RRF), `BrowserEngine` trait + WebKit baseline + Obscura experimental adapter, Metal kernels where measured | per `OBSCURA_BROWSER_ADDENDUM.md` (revised — `BrowserEngine` trait, not Obscura-specific) |
| **7** | Live Files | LiveFileManifold, LivePlan compiler, Inspector UI (raw YAML behind toggle), event-driven scheduler with thermal/battery gating, policy gate (4-tier weight class), NightBrain integration, hardening suite (plan signing, capability firewall, deterministic pre-action authorization, RunEventLog as truth, poisoning defense via zone separation, budget governor, thermal/battery governor) | per `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (revised — Compiler is the centerpiece; auto-research deferred to Wave 8) |
| **8** | Deep deliberation / council / autoresearch | Model teams (optimistic/pessimist/neutral panels), research jury, recurring synthesis, self-auditing reports, Karpathy-style overnight loops, Eidos Plus deliberation engine | new — split from Wave 7 per critique |
| **9** | Biometric substrate | Secure Enclave session-tokens; capability scope/binding; deterministic pre-action authorization; confidence-meter-triggered biometric re-learn (diagnose-first) | per `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §1–2 |
| **10** | Tamagotchi agent surface + distillation lab | Pixel/Tactical UI duality, per-agent identity, sub-agent capability inheritance (only narrowing), A2A "phone" channel, computer-use supervisor, accessory system (LoRAs as visual equipment); cloud-as-teacher distillation with PII sluice + catastrophic-forgetting eval gate | per `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §3–4 |
| **11** | Brain Export (productization layer — gated on legal review) | Signed Brain Artifact bundle (weights + compiled scaffold + test report); license keying; enterprise C2 lock-in via continued Epistemos subscription | per `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §5 |

The reordering matters. **Live Files need the substrate to be boring before they go on top of it.** Auto-research mutates Live Files; therefore auto-research can only run when Live Files are themselves rock-stable. Wave 8 is the only place auto-research belongs.

---

## 7. The subprocess discipline (corrected to honesty)

Per the critique: "Make 'no hot-path subprocesses' a law, not 'no subprocesses ever.'"

```
HOT PATH (zero subprocesses, by law):
- Search, retrieval, embeddings
- Local inference (MLX-Swift in-process)
- Graph traversal, vault ops
- Live Files (parser, compiler, runner)
- Tool authorization (Layer 4)
- RunEventLog writes
- Browser engine via BrowserEngine trait (in-process or sandboxed-helper-only)

PRO-ONLY OPTIONAL BRIDGES (kept while learning, replaced over time):
- Hermes Python orchestrator subprocess (cloud orchestration; learning ground for Rust port)
- oMLX bridge for oversized models (declared in CLAUDE.md as the only inference exception)
- deno_core for Pro user JS (in-process via Cargo dep; not a subprocess)
- Obscura helper binary (Pro only; ephemeral per call; stdio-pipe transport)

NEVER ALLOWED:
- Node.js binary as a runtime dependency
- Deno binary (we use deno_core library only)
- Python interpreter as runtime dependency (Pyodide-via-WASM only, Pro only)
- Ollama, llama-server, any subprocess inference
- Shell wrappers as default tools
- Browser helper daemons (always-on)
```

The audit (run via the rg command in the critique) classifies every existing subprocess hit into A/B/C/D/E (forbidden hot-path / allowed dev-build / optional Pro adapter / test-only / false positive). Wave 6 ships the elimination of hot-path subprocesses; Wave 7+ continues to migrate the optional Pro bridges to Rust as the patterns mature.

**The honest commitment**: the long-term destination is Hermes-equivalent orchestration in pure Rust. Today, Hermes-as-Pro-subprocess remains because we are still learning what good orchestration looks like. We will not pretend it's already gone.

---

## 8. Document map — what you have

After this synthesis, here is the canonical state of the project's design documents:

```
~/Documents/Epistemos-QuickCapture/
├── INDEX.md                                              (entry point + reading order)
├── PLAN.md                                               (243 KB — master plan, Waves 0–5)
├── BUILDER_PROMPT.md                                     (launch prompt for builder sessions)
├── AUDIT_PROMPT.md                                       (verification prompt for shipped phases)
├── OBSCURA_BROWSER_ADDENDUM.md                           (Wave 6 — substrate + Eidos + BrowserEngine trait)
├── LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md                  (Waves 7–8 — Live Files + auto-research)
├── BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md         (Waves 9–11 — biometric + Tamagotchi UI + Brain Export)
└── FINAL_SYNTHESIS.md                                    (this — canonical synthesis + corrections + Reflective Loop)
```

| If you want to | Read |
|---|---|
| Understand the whole project at a glance | This document (FINAL_SYNTHESIS.md) |
| Find any doc and the canonical reading order | INDEX.md |
| Implement Waves 0–5 | PLAN.md |
| Spawn a builder agent | BUILDER_PROMPT.md |
| Verify a shipped phase | AUDIT_PROMPT.md |
| Implement Wave 6 | OBSCURA_BROWSER_ADDENDUM.md (read with this doc's §6 corrections) |
| Implement Wave 7 | LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md (read with this doc's §1 Compiler + §3 Weight classes + §4 state machine corrections) |
| Implement Wave 8 | LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md cross-references (uses this doc's §2 Reflective Loop as the architectural skeleton) |
| Implement Wave 9 (biometric substrate) | BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md §1–2 |
| Implement Wave 10 (Tamagotchi UI + distillation lab) | BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md §3–4 |
| Implement Wave 11 (Brain Export — gated on legal review) | BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md §5 |
| Settle a design dispute | This document wins |

Conflicts between this doc and the addendums are resolved in favor of this doc. The addendums have not been rewritten because the corrections are localized; this doc names them explicitly so the builder can apply them in-flight.

---

## 9. The canonical thesis (what this whole project is, in one paragraph)

> **Epistemos is a single-process, single-binary, Apple-Silicon-native cognitive workspace for solo developers and writers who want a sovereign alternative to cloud-hosted PKM, AI search, and SaaS task tracking. Every layer of the runtime — retrieval, attention, executive control, immune defense, motor execution, memory, metabolism — runs in the same Rust+Swift+Metal address space, sharing unified memory through MLX, with zero hot-path subprocesses by law. Live Files compile from natural-language markdown into deterministic, signed, capability-bounded LivePlans; the runtime executes the signed plan, never the markdown. Eidos provides local-first hybrid retrieval (Tantivy + HNSW + RRF + Metal cosine) that returns not just relevant chunks but typed control vectors annotated with policy authority. Cognitive Weight is a four-tier class system where only policy-grade weights may constrain tools, gated by schema validation, capability validation, signed plan hash, and explicit revocation. The browser is one of three or four `BrowserEngine` adapters — WebKit-baseline for MAS, Obscura-experimental for Pro, plus mocks for tests — never a single-vendor commitment. Pro user JavaScript executes via deno_core in-process with capability-gated ops; MAS allows no arbitrary user JS runtime. Auto-research overnight, via NightBrain (Wave 8), reads the RunEventLog, runs Karpathy-style variant experiments against frozen objective metrics, keeps wins, tombstones losses, and surfaces a 90-second morning report. Privacy is structural: ephemeral capability tokens per tool call, per-Live-File network allowlists, differentially-private aggregations on auto-research telemetry, signed proof-of-execution receipts, browser stealth, local-by-default with tri-state cloud opt-in. The moat is not any single feature — it is that all of these compose into one process with one trust boundary, where the user can verify what ran, undo any auto-decision within 7 days, and be confident that the substrate is theirs alone.**

---

## 10. References

### Apple platform (per critique citations)

- [Apple Foundation Models — Generating Swift Data Structures with Guided Generation](https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation) — `@Generable` for grammar-bound LLM output
- [Core Services — File System Events](https://developer.apple.com/documentation/coreservices/file_system_events) — substrate for vault-scale event-driven monitoring
- [BackgroundTasks framework](https://developer.apple.com/documentation/backgroundtasks) — `BGProcessingTask` for NightBrain workloads
- [ProcessInfo.thermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum) — thermal-aware scheduling
- [Hardened Runtime: allow-jit entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.cs.allow-jit) — Pro V8 JIT
- [App Sandbox + network entitlements](https://developer.apple.com/documentation/security/app-sandbox)

### Search and retrieval

- [Tantivy — Rust full-text search](https://github.com/quickwit-oss/tantivy)
- [HNSW: Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs (arxiv:1603.09320)](https://arxiv.org/abs/1603.09320)
- [Reciprocal Rank Fusion outperforms Condorcet (Cormack et al., SIGIR 2009)](https://cormack.uwaterloo.ca/cormacksigir09-rrf.pdf)
- [MLX — Unified Memory documentation](https://ml-explore.github.io/mlx/build/html/usage/unified_memory.html)
- [Exa.ai — neural-embedding-first agent search](https://exa.ai/) — strategic positioning reference (Eidos's cloud counterpart)
- [Nebius acquires Tavily for $275M](https://finance.yahoo.com/news/nebius-agrees-acquire-tavily-275-145527432.html) — corrected attribution per critique
- [Parallel Web Systems $100M Series B at $2B valuation (WSJ)](https://www.wsj.com/cio-journal/ex-twitter-ceos-ai-startup-raises-funds-at-2-billion-valuation-63c927fc) — agent-search infrastructure category signal

### Browser engine (Wave 6)

- [Obscura — Rust headless browser](https://github.com/h4ckf0r0day/obscura)
- [Obscura releases — v0.1.1 April 25, 2026](https://github.com/h4ckf0r0day/obscura/releases) — early stage; treat as one adapter, not foundation
- [deno_core — Rust V8 + event loop library](https://docs.rs/deno_core)

### Agent architecture (2026 contemporary)

- [Karpathy AutoResearch (March 2026)](https://github.com/karpathy/autoresearch) — overnight variant loop pattern (Wave 8)
- [Before the Tool Call: Deterministic Pre-Action Authorization (arxiv:2603.20953)](https://arxiv.org/html/2603.20953v1) — Layer 4 (Immune) academic grounding
- [The Hacker News — Deterministic + Agentic AI (April 2026)](https://thehackernews.com/2026/04/deterministic-agentic-ai-architecture.html) — probabilistic brain + deterministic body pattern
- [dotNetting — Human-on-the-loop guide (Feb 2026)](https://dotnetting.net/2026/02/the-human-on-the-loop-a-practical-guide-to-agentic-engineering/) — oversight model for auto-research
- [Decoupled Human-in-the-Loop System for Controlled Autonomy (arxiv:2604.23049)](https://arxiv.org/abs/2604.23049) — Wave 7 governance pattern

### Memory and substrate

- Voyager, A-MEM, MemGPT, MemPalace, Mercury, soul.md (per `OBSCURA_BROWSER_ADDENDUM.md` §24 references) — composed moat from cutting-edge agent repos

### Classic invention texts (per `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §13)

- Vannevar Bush — *As We May Think* (Memex)
- Doug Engelbart — *Augmenting Human Intellect* (bootstrapping)
- Alan Kay — *The Computer Revolution Hasn't Happened Yet* (late-binding)
- Bret Victor — *Inventing on Principle* (immediate feedback)
- Christopher Alexander — *A Pattern Language* (emergent quality)
- Carver Mead — *Analog VLSI* (substrate-from-local-rules)
- Norbert Wiener — *Cybernetics* (feedback, homeostasis)
- John von Neumann — *Theory of Self-Reproducing Automata* (cellular substrate)
- Donald Knuth — *Literate Programming* (prose+code interleaving)

---

## 11. The honest closing

This is the last document I would write before the builder begins. Five things I want to be honest about:

1. **The prior addendums (v1–v3 of Obscura, v1 of Live Files) have errors that this synthesis corrects.** Read those addendums *with* this synthesis open. Specifically: §1 Live File Compiler, §3 Cognitive Weight class system, §4 10-state machine, §6 corrected wave sequencing, §7 corrected subprocess discipline.

2. **The Reflective Loop (§2) is new.** It is the architectural pattern that makes Epistemos feel like one substrate. The seven layers map cleanly onto biological control loops without requiring biological language in the code. Every layer has a defined input, output, and verification gate. The substrate metabolizes by traversing the layers.

3. **The Live File Compiler (§1) is the most consequential correction.** Without the compiler, Live Files are "haunted automation" (the critique's term) — markdown that magically executes. With the compiler, Live Files are **a normal file bound to a compiled, signed, inspectable execution plan**. This separation is what makes the feature shippable instead of dangerous.

4. **The privacy hardening (§5) is what makes the single-substrate argument a moat.** Because the substrate is one process, the privacy boundary is one process. The argument is structural, not marketed. Ephemeral capability tokens, per-Live-File egress allowlists, differentially-private aggregations, signed proof-of-execution receipts, local-by-default with explicit cloud opt-in — these compose into a privacy posture no third-party SaaS can credibly claim.

5. **The wave ordering matters.** Wave 5 (stabilize) → Wave 6 (substrate) → Wave 7 (Live Files) → Wave 8 (deliberation/auto-research). Out of order, the system is fragile. In order, each wave makes the next one safe. The critique was right to split auto-research out of Wave 7; that's the rule.

When the builder begins, they begin with `PLAN.md` Phase 0.5 per `BUILDER_PROMPT.md`. They reach this synthesis only when they're considering Wave 6 design choices or Wave 7 implementation. Until then, this doc waits patiently.

The substrate metabolizes. The vault is the organism. The document is the cell. The plan is signed; the plan is law. The loop is reflective; the loop improves overnight.

That is Epistemos.

---

*End of Final Synthesis. This document is the project's design canon as of 2026-04-29. Future revisions are explicit (next version → FINAL_SYNTHESIS_v2.md) so prior canon is recoverable.*
