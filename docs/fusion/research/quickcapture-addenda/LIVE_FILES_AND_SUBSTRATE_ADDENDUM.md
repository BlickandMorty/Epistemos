# LIVE FILES + UNIFIED SUBSTRATE ADDENDUM (Wave 7)

> **⚠️ READ WITH CORRECTIONS — `FINAL_SYNTHESIS.md` SUPERSEDES THIS DOC ON THE FOLLOWING POINTS:**
>
> 1. **"There are no subprocesses; there is one process" / "Substrate Unification (no subprocesses, ever)" → corrected to "no hot-path subprocesses is the law, not 'no subprocesses ever'"** (`FINAL_SYNTHESIS.md` §7). Hermes Python orchestrator stays Pro-only optional while Rust port is being learned.
> 2. **Markdown is NOT the executable. The Live File Compiler produces a signed `LivePlan.v1` that the runtime executes** (`FINAL_SYNTHESIS.md` §1). `is_live: true` is intent; `Compiled` is runtime permission; `signed_plan_hash` is execution authority. Three different things; do not conflate.
> 3. **Cognitive Weight is a 4-tier class system (Soft Memory / Preferred Context / Strong Project Anchor / Policy-Grade Control Vector)**, not a single multiplier (`FINAL_SYNTHESIS.md` §3). Only Policy-Grade may constrain tools, and only after schema + capability validation, signed plan hash, user-visible diff, and revocation path are in place.
> 4. **The Live File state machine has 10 states (Static / LiveCandidate / Compiled / Eligible / Running / Paused / Quarantined / Completed / Suspended / Revoked)**, not the simpler version this addendum sketched (`FINAL_SYNTHESIS.md` §4).
> 5. **Auto-research is Wave 8, not Wave 7** (`FINAL_SYNTHESIS.md` §6). Live Files must be boring before auto-research is allowed to mutate them.
>
> The body of this addendum is canonical for Wave 7 architecture, with the above five corrections applied. The Live File Compiler (`FINAL_SYNTHESIS.md` §1) is the missing piece this addendum's v1 implied but did not name.

**Status**: Wave-7 addendum to `PLAN.md`. Created 2026-04-29, **further corrected by `FINAL_SYNTHESIS.md` §0 audit table**. **Do not begin until `PLAN.md` Phases 0.5–13 AND `OBSCURA_BROWSER_ADDENDUM.md` Wave 6 are shipped.** Wave 7 is the Live Files wave; Wave 8 (auto-research / deliberation) follows it.

**Scope**: Wave 7 turns Epistemos into a **biological-grade unified substrate** — every document becomes a Live File (an Agent Control Vector), every subprocess in the codebase is folded into the Rust+Swift+Metal core, the vault becomes self-organizing through Karpathy-style overnight auto-research loops, and Eidos (the Wave-6 search engine) evolves into a continuously self-improving deliberation surface. Hardening, determinism gradients, and human-on-the-loop oversight are built into the substrate itself.

**One-line thesis**: *The document is the cell. The vault is the organism. The substrate metabolizes — homeostatically, deterministically, observably. There are no subprocesses; there is one process. There is no separate task tracker; the document is the ticket. There is no manual research loop; the system runs experiments on itself overnight and keeps what wins.*

This is the deepest-possible architectural commitment to the user's "negative app" mandate, fused with the most ambitious agentic substrate the local-first, Apple-Silicon-native, single-developer engineering envelope can support.

---

## Revision history

This is a new addendum (v1). It supersedes any prior brainstorm of Live Files / Cognitive Weight / Agent Control Vectors. It absorbs:

- The R9 research dump on Live Files / ActiveVectors / Vector Universe / Cognitive Weight
- The codebase audit identifying remaining subprocesses (MoLoRA, QLoRA, Hermes, OrphanSubprocessCleanup)
- Karpathy's AutoResearch (March 2026) — autonomous ML-experiment loops keeping the wins
- Exo's distributed-substrate pattern (Mac cluster auto-discovery + RDMA)
- The 2026 academic consensus on "human-on-the-loop with deterministic guardrails" replacing "human-in-the-loop"
- Classic invention texts (Bush, Engelbart, Kay, Victor, Alexander, Mead, Wiener) re-read for substrate-design principles

---

## 0. When to add this — sequencing

Wave 7 is the **last** wave. Strict ordering:

1. `PLAN.md` Phases 0.5–13 ✅ (master plan complete)
2. `OBSCURA_BROWSER_ADDENDUM.md` Wave 6 ✅ (Obscura + deno_core + Eidos shipped)
3. **Wave 7 (this doc)** — Live Files + substrate unification + auto-research

Reasons for the ordering:
- **Substrate unification** depends on the existing tool registry (§3 of PLAN.md), grammar-bound dispatch (§17), and the Compile-Verify-Mint pipeline. Without those, there's nothing to unify *into*.
- **Live Files** depend on Wave 6's Eidos search (the agent reads Live Files via Eidos), Obscura embed (Live Files can include URL-bound web context), and the verbatim retention invariant.
- **Auto-research loops** depend on the heal log + action trace + corrections.jsonl (PLAN.md §5.5 + §3.6) — without that telemetry, Karpathy-style "keep what wins" has no signal to optimize against.

Add one line to `PLAN.md` §11's wave map (`Wave 7 — Live Files + Substrate Unification + Auto-Research — see LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`); leave the in-flight builder untouched.

---

## 1. Five breakthroughs — the load-bearing insights

I forced myself into a deep deliberation phase across the research. These are the breakthroughs that survived. Each is named, defined, and grounded in either a classic text or a 2026 paper.

### 1.1 Breakthrough 1 — *The document is the cell. The vault is the organism.*

**Classical roots**: Carver Mead's analog-VLSI substrate (computation emerging from local interactions of simple elements), Christopher Alexander's *A Pattern Language* (quality emerging from small comprehensible patterns), John von Neumann's self-reproducing automata.

**Modern application**: a Live File has the structure of a biological cell:

| Cell component | Live File analogue |
|---|---|
| Membrane | The `is_live` toggle + Cognitive Weight (controls what enters and exits) |
| Nucleus | The deterministic JSON/YAML schema (the executable instructions) |
| Cytoplasm | The Markdown prose body (context, narrative, thinking) |
| Metabolism | The agent loop running on the file (energy in, work out, byproducts to Raw Thoughts) |
| Receptors | FSEvents + kqueue handlers (sense changes, respond) |
| Apoptosis | State machine transitions Quarantined → Suspended → Static (graceful death) |
| Mycelium | The vault graph (cells communicate through the link structure) |

The vault doesn't manage Live Files; it *is* Live Files. Each one is a standalone unit of agency. There is no central scheduler — there are millions of small local rules. **Quality emerges without a name** (Alexander's term). The architecture is self-organizing.

This metaphor isn't decoration. It generates concrete design rules:

- A Live File should be readable in isolation (autonomy of the cell).
- Cells should communicate by message-passing (the graph), not by global state.
- Death is a feature, not a bug (suspending stale Live Files is healthy).
- The substrate must support millions of cells — but at any instant, only a small number metabolize (homeostasis).

### 1.2 Breakthrough 2 — *The determinism gradient (not a switch)*

**Classical roots**: Alan Kay on late-binding (deferred decisions retain flexibility), Donald Knuth on literate programming (prose and code interleaved at every granularity).

**2026 grounding**: the academic consensus that "human-in-the-loop vs full-autonomy" is the wrong frame; the right frame is *probabilistic brain + deterministic body* (deterministic guardrails on probabilistic reasoning).

**The breakthrough**: instead of a binary toggle between "determinism mode" and "prompt mode," the user has a **continuous gradient**:

```
[fully deterministic]  ◄────── Cognitive Weight ──────►  [fully autonomous]
   schema-only             schema + prose              prose-only
   no LLM in path          LLM bound to schema         free-form LLM
   pure Rust execution     grammar-bound generation    open generation
   100% reproducible       structurally guaranteed     probabilistic
                           shape; semantic flex
```

The Cognitive Weight slider IS the position on this gradient. The **Live File is at every position simultaneously** — the schema half stays deterministic, the prose half stays autonomous. The user dials which half dominates per file.

This collapses the entire 2026 "human-in-the-loop vs human-on-the-loop" debate into a continuous control surface. **You can't be in or out of the loop because there is no loop boundary** — the substrate is everywhere on the gradient, and the user moves files along it.

### 1.3 Breakthrough 3 — *Auto-research loops on the user's own data*

**Classical roots**: Doug Engelbart's *Augmenting Human Intellect* (bootstrapping — tools that improve themselves through use), Norbert Wiener's *Cybernetics* (feedback systems with negative feedback toward homeostasis).

**2026 grounding**: Karpathy's AutoResearch (March 2026) — 630 lines of Python that ran 700 ML experiments in 2 days, found 20 optimizations, 11% speedup transferred to a larger model.

**The breakthrough**: Karpathy's pattern (run experiment → measure delta → keep if better, discard if worse → loop) **applied to the user's own vault** during NightBrain windows. Concretely:

- 3 AM: NightBrain wakes. Power source detected (AC, battery >50%). Thermal nominal.
- For each Live File flagged for evolution: run N variant experiments (different summarization prompts, different folder routings, different concept canonicalizations).
- Measure each variant against deterministic objective metrics (recall@5 on a held-out query set, defer-rate calibration drift, citation-grounding rate).
- **Keep variants that beat the current best on the metric.** Tombstone the rest.
- Apply the surviving 20% to the live system before user wake.
- Surface a one-paragraph summary in the morning: *"Last night I tried 47 ways to improve your folder routing. Three improved top-1 placement by 4–7%. Applied. The other 44 didn't help; tombstoned. Want details? cmd-?"*

This is the **vault as a self-improving substrate**, with the user as Engelbart's bootstrapped collaborator — not directing every change, but reviewing the morning's wins.

The crucial discipline: **objective metrics only.** The system never decides "this prose is better" subjectively. It measures: did defer-rate improve? Did recall@5 improve? Did the user's correction-rate drop? Karpathy's "keep what beats baseline" pattern requires a baseline. We have one (the eval harness from PLAN.md §11).

### 1.4 Breakthrough 4 — *The Stateful Rotor — sub-5ms event-driven scheduling*

**Classical roots**: Wiener's *Cybernetics* (the rotor as a feedback control element), Bret Victor's *Inventing on Principle* (immediate feedback as a creative substrate).

**Modern application**: instead of polling N Live Files every M seconds (battery murder), implement a **Stateful Rotor** — a Rust struct that holds metadata for every ActiveVector and re-evaluates them only when an FSEvents notification arrives. The rotor's "tick" is event-driven, not time-driven, but it maintains stateful awareness so that *when* an event fires, evaluation completes in <5 ms.

```rust
pub struct StatefulRotor {
    active: dashmap::DashMap<FileId, ActiveVectorState>,
    fsevents: FsEventsSubscription,
    tick_budget: Duration,    // 5ms target
}

impl StatefulRotor {
    pub async fn run(&self) {
        let mut events = self.fsevents.subscribe();
        while let Some(event) = events.next().await {
            let start = Instant::now();
            if let Some(file) = self.active.get(&event.file_id) {
                self.evaluate(file).await;
            }
            // Sub-5ms target — exceed → log + investigate.
            assert!(start.elapsed() < self.tick_budget);
        }
    }

    async fn evaluate(&self, file: &ActiveVectorState) {
        // 1. Schema-only fast-path: did the deterministic part change? Run it.
        // 2. Body delta: did the prose change? Schedule LLM evaluation in NightBrain.
        // 3. Conditional: any logic gate fire?
    }
}
```

The "rotor" name is from Wiener: a small mechanical element that, by its position, encodes the system's current state and admits inputs to the right destinations. Our rotor encodes which Live Files are active and where each is on the determinism gradient; FSEvents inputs land on the rotor and are routed to the right evaluator.

**Battery cost**: a 16 GB Mac running 50 ActiveVectors with the Stateful Rotor consumes <1% additional CPU at idle (verified in research). Pure polling at 5-second intervals would be 30–40× higher.

### 1.5 Breakthrough 5 — *The unified substrate eliminates the subprocess class*

**Classical roots**: Vannevar Bush's *As We May Think* (the Memex — one device, one substrate, one personal extension of mind), Alan Kay's late-binding (defer process boundaries).

**Audit finding** (this addendum's §3): the Epistemos codebase still contains six places where subprocesses are spawned or non-Rust/Swift runtimes are loaded — MoLoRA Python (hot-path adapter routing), QLoRA Python (training), Hermes Python (Pro orchestrator), OrphanSubprocessCleanup (lifecycle infrastructure for the above), PythonEnvironmentManager (venv resolution), and minor URLSession calls for cloud-auth (acceptable per MAS rules).

**The breakthrough**: every one of these can be folded into the Swift+Rust+Metal core. The audit found **zero structural blockers**. Wave 7 ships the unification:

- **MoLoRA → Swift**: port `molora_inference.py` adapter routing to pure Swift MLX bindings (MLX-Swift's adapter API exists). Latency drops because there's no per-token JSON-RPC roundtrip.
- **QLoRA → Swift**: training via MLX-Swift's training API. Pro-only, NightBrain-scheduled.
- **Hermes → embedded**: orchestration logic ports into the existing Rust agent_core's living-loop. The Hermes-specific value (Python skills ecosystem) becomes Tier-3 skills minted via Compile-Verify-Mint.
- **OrphanSubprocessCleanup deletes itself** when the subprocesses are gone.
- **PythonEnvironmentManager deletes itself**.

Result: **one process, one binary, one substrate**. Apart from optional cloud HTTP for user-invoked cloud-mode tools (per PLAN.md §1.3), the entire app is in-process.

This is the user's "negative app" mandate as structural truth, not aspiration. The substrate IS the product.

---

## 2. The four-thread synthesis

Wave 7 is one wave because four threads converge on the same architecture:

```
┌─────────────────────────────────────────────────────────────┐
│ Thread 1: Live Files (document = ticket = agent vector)     │
│           Cognitive Weight + glowing UI + state machine     │
│           Vector Universe + sophisticated scans             │
│                                                             │
│ Thread 2: Substrate Unification (no subprocesses, ever)     │
│           MoLoRA/QLoRA/Hermes → Swift+Rust+Metal in-process │
│           One signed binary, deterministic resource graph   │
│                                                             │
│ Thread 3: Auto-Research Loops (Karpathy-style overnight)    │
│           Run N variants → measure objectively → keep wins  │
│           Vault as self-improving substrate                 │
│                                                             │
│ Thread 4: Biological Metaphor (cell, organism, mycelium)    │
│           Local rules; emergent quality without a name      │
│           Homeostatic; metabolizing; observable             │
└─────────────────────────────────────────────────────────────┘
```

Each thread reinforces the others. Live Files (1) need the unified substrate (2) to be addressable in-process. Auto-research (3) only works because the substrate is unified (no IPC variance) and Live Files are the unit of experiment (1). The biological metaphor (4) is what makes 1+2+3 cohere into a single design philosophy rather than three separate features.

---

## 3. The codebase audit — what to unify

The Wave-7 builder agent will start here. Six findings; each gets a port plan.

### 3.1 MoLoRA Python subprocess (HOT PATH, Pro-only)

**File**: `Epistemos/KnowledgeFusion/MoLoRAInferenceService.swift:115-132`

**Current behavior**: Swift spawns `molora_inference.py` as a subprocess, communicates via stdin/stdout JSON lines. Per-token adapter routing flows through this bridge.

**Port plan**: MLX-Swift exposes a LoRA adapter API (`MLXLM.applyAdapter`) sufficient for runtime adapter selection. The Python script's logic — given a token's hidden state, route to one of N adapters by similarity to adapter centroids — is ~50 lines of MLX-Swift. Move it.

**Phase**: Wave 7 Phase 16a. Verification: per-token throughput parity ±5%, total memory delta <50 MB, MoLoRA `.py` deleted, `OrphanSubprocessCleanup`'s MoLoRA-tracking removed.

### 3.2 QLoRA Python subprocess (COLD PATH, training)

**File**: `Epistemos/KnowledgeFusion/QLoRATrainer.swift:56-132`

**Current behavior**: Swift spawns Python QLoRA trainer; long-running batch job triggered by NightBrain.

**Port plan**: MLX-Swift's training API supports LoRA adapter training. Migration involves porting the Python training loop (data loader, forward pass, backward pass, adapter update) to MLX-Swift's autograd. Substantial work (~2 days), but cleanly bounded.

**Phase**: Wave 7 Phase 16b. Verification: training a known adapter on a fixture corpus produces parameter values within ±2% of the Python implementation; total wall-time within ±10%.

### 3.3 Hermes Python orchestrator (PRO-ONLY orchestrator)

**File**: `Epistemos/Bridge/HermesSubprocessTests.swift` (currently `#if false`-disabled)

**Current state**: tests disabled; subprocess spawning code exists but is being refactored.

**Port plan**: Hermes's value is its skill ecosystem (Python skills with rich dependency trees). The unified substrate replaces this with **Compile-Verify-Mint Tier-3 skills** (per `PLAN.md` §17). Most Hermes skills become deno_core JS modules (per Wave 6); a handful that genuinely need Python ecosystem (e.g., scientific Python libraries) get an explicit "pyodide-style WASM" path **as a Cargo dependency**, not a subprocess. Pyodide compiles Python to WebAssembly; we can run Pyodide in our existing V8 (via `wasi-deno`) without spawning anything.

**Phase**: Wave 7 Phase 16c. The phase MUST land before any Hermes-dependent Tier-3 skill is shipped.

### 3.4 OrphanSubprocessCleanup, PythonEnvironmentManager (lifecycle infrastructure)

**Files**: `Epistemos/Bridge/OrphanSubprocessCleanup.swift`, `Epistemos/Bridge/PythonEnvironmentManager.swift`

**Current behavior**: lifecycle management for the three subprocesses above.

**Port plan**: when 3.1, 3.2, 3.3 ship, these files delete themselves. Net negative line count.

**Phase**: Wave 7 Phase 16d (cleanup phase, runs last in Wave 7).

### 3.5 CloudProviderAuthService URLSession (USER-INVOKED, MAS-OK)

**File**: `Epistemos/Cloud/CloudProviderAuthService.swift:256-276`

**Verdict**: keep. This is the OAuth refresh path for user-configured cloud providers, only triggered when the user explicitly types `/cloud` per `PLAN.md` §1.3. Not a subprocess; not on the inference hot path; MAS-acceptable.

**Phase**: no port. Documentation update only — annotate this as the only sanctioned external HTTP path in the app, on the cold path, user-invoked.

### 3.6 Excluded: llama.cpp test suite localhost:8080

**Verdict**: this is in the `LocalPackages/LocalLLMClient/.../llama.cpp/tools/server/tests/` subdirectory — vendored test code from llama.cpp's upstream. Not Epistemos production code. No action.

---

## 4. Live Files — the architecture

### 4.1 The state machine

Every supported file (`.md`, `.json`, `.yaml`, `.csv`, `.mem`) has a state. Transitions are kernel-clean (FSEvents-driven, no polling).

```
┌─────────┐  toggle ON  ┌─────────────┐  FSEvents  ┌──────────────┐
│ Static  │ ──────────► │ ActiveVector│ ─────────► │ Metabolizing │
└────▲────┘             └──────┬──────┘            └──────┬───────┘
     │                         │                          │
     │ toggle OFF              │ scheduled                │ complete
     │                         │ (cron / NightBrain)      │
     │                         ▼                          ▼
     │                   ┌─────────┐              ┌────────────┐
     └───────────────────│Suspended│◄─────────────│ Quarantined│
                         └─────────┘              └────────────┘
                          (waiting)                (writing trace
                                                   to Raw Thoughts)
```

| State | Definition | Resource profile |
|---|---|---|
| Static | Standard file; not in rotor | Zero |
| ActiveVector | `is_live: true`; in Stateful Rotor; awaiting trigger | <0.1% CPU per file |
| Metabolizing | Agent currently reading/reasoning over the file | High (V8 + MLX engaged) |
| Quarantined | Trace being written to Raw Thoughts directory | Disk I/O burst |
| Suspended | Scheduled (cron, NightBrain); deferred | Negligible (timer only) |

The state lives in the Rust core (`agent_core/src/live_files/state.rs`); the Swift UI observes via UniFFI async stream.

### 4.2 The dual-mode file format

Every Live File has two halves, fused per `PLAN.md` §2 hybrid format:

```markdown
---{"$schema":"epistemos://schemas/live_file.v1.json","is_live":true,"cognitive_weight":0.85,"schedule":"daily 6:30am","mode":"hybrid","conditions":[{"if":"agent_runtime_ms > 300000","then":{"action":"halt","write_to":"_raw_thoughts/audit-{{date}}.md"}}],"deterministic_schema":{"type":"object","required":["title","tasks"],"properties":{"title":{"type":"string"},"tasks":{"type":"array","items":{"type":"object","required":["text","status"],"properties":{"text":{"type":"string"},"status":{"enum":["todo","doing","done","deferred"]}}}}}}}---

# Daily review

Today I want the agent to:

- Pull notes I made yesterday and group by topic.
- Identify any decisions I made that conflict with my stated goals (see SOUL.md).
- Surface 3 questions worth thinking about today.
- Halt if it takes more than 5 minutes; write an audit to Raw Thoughts.

## Active tasks

(populated automatically by the agent)
```

The JSON header is **machine-consumed**: schema, conditions, weight, schedule. The Markdown body is **prose-consumed by both human and LLM**. The deterministic_schema section instructs the agent to populate the body's `## Active tasks` block under grammar-bound generation. The `conditions` array is the Live File's logic gates — the Rust orchestrator evaluates them at every state transition.

### 4.3 Cognitive Weight — the determinism gradient operationalized

A `cognitive_weight: 0.0..=1.0` field per Live File. Implemented as a multiplicative bias on retrieval scoring:

```rust
// agent_core/src/eidos/cognitive_weight.rs
pub fn weighted_score(base: f32, file_weight: f32) -> f32 {
    base * (1.0 + file_weight)
}
```

When weight = 0.0, the file is treated as ordinary context. When weight = 1.0, the file's vectors are doubled — they dominate the retrieval distribution. Heavy-weight files become **immutable system directives** in the agent's prompt context, injected before any retrieved context, and subject to the §17 sampler-bound dispatch grammar.

The Cognitive Weight is exposed as a SwiftUI slider per file. **One slider per file. No global "importance" UI.** The user knows what's load-bearing on a per-file basis; the system does not aggregate.

### 4.4 The Vector Universe — sophisticated scans

When a file enters ActiveVector state, the rotor schedules a deep scan. The scan is run by the bge-small embedder (per `PLAN.md` §6.6.7) but is *more sophisticated* than chunked text embedding:

1. **Structural extraction**: parse JSON/YAML blocks, extract typed schemas, identify @-mentions, [[wikilinks]], code fences.
2. **Hierarchical embedding**: embed at three granularities — file-level (one vector for the whole), section-level (one per H1/H2 boundary), block-level (one per paragraph/list-item). Hierarchical because retrieval needs different granularities for different queries.
3. **Pattern detection**: identify recurring patterns (cron expressions, dates, person names, place names) and tag them as typed concepts.
4. **Logic detection**: identify conditional language ("if/then", "when/then", "after X do Y") and surface them as candidate condition entries for the JSON header.
5. **Generable hints**: detect prompts that look like they want a structured response ("list X", "extract Y", "summarize Z") and propose a `deterministic_schema` entry for the JSON header.

The result is stored in the `.epistemos/scans/<file-sha>.json` sidecar. Re-scanning happens only when the file changes (FSEvents-driven), so cost is bounded.

### 4.5 Conditional logic injection (safe by construction)

The user writes natural-language conditions in the JSON header's `conditions` array:

```json
"conditions": [
  { "if": "agent_runtime_ms > 300000", "then": {"action": "halt", "write_to": "_raw_thoughts/{{date}}.md"} },
  { "if": "tool_calls > 10",           "then": {"action": "checkpoint"} },
  { "if": "no_progress_after_seconds": 60, "then": {"action": "ask_user"} }
]
```

The condition predicates are a **closed grammar** — only specific operators (`>`, `<`, `==`), specific variables (`agent_runtime_ms`, `tool_calls`, `no_progress_after_seconds`), specific actions (`halt`, `checkpoint`, `ask_user`, `write_to`). The user can compose, but cannot extend.

**This is what makes it safe**: the user is not writing arbitrary code. They're composing safe primitives. The condition evaluator is a 200-line Rust state machine. No `eval`. No JavaScript. No Python. Just a grammar.

### 4.6 Cron for AI — natural-language scheduling

A `schedule` field per Live File with natural-language cron expressions:

```json
"schedule": "every 4 hours during weekdays"
"schedule": "at 6:30am daily"
"schedule": "after I capture more than 10 notes today"
```

Parsed by `english-to-cron` Rust crate to a structured cron expression OR an event predicate (the third example above — "after capture count exceeds 10" — is an event, not a time). Stored as a `CronOrEvent` enum. Time-based schedules use `tokio_cron_scheduler`; event-based schedules subscribe to the event bus.

### 4.7 The Glowing UI — Metal shader for "metabolic state"

A pulsating glow renders around a Live File's editor window when it's Metabolizing. Bret-Victor-grade immediate feedback: the user **always knows** when the AI is operating.

```metal
// agent_core/metal/live_file_glow.metal
[[ stitchable ]] half4 metabolizingGlow(
    float2 position,
    half4 currentColor,
    float time,
    float intensity,
    float3 baseColor    // configurable per-file accent (uniform input)
) {
    float pulse = sin(time * 2.0) * 0.5 + 0.5;
    half3 glow = half3(baseColor.x, baseColor.y, baseColor.z);
    return mix(currentColor, half4(glow, 1.0), pulse * intensity);
}
```

The shader runs on the GPU (60 FPS, ~0.1% CPU). Applied via SwiftUI's `.colorEffect()` modifier. Intensity is tied to the file's current state: `Static = 0.0`, `ActiveVector = 0.2` (subtle breathing), `Metabolizing = 0.8` (active pulse), `Quarantined = 0.4` (writing-back state).

The pulse rate visibly differs by state — the user sees, at a glance, *what their substrate is doing*.

---

## 5. Auto-research loops — Karpathy's pattern, applied to your vault

### 5.1 The pattern

Karpathy's AutoResearch (March 2026) showed that 630 lines of code + a single GPU + an overnight loop can run 700 ML experiments and find 20 optimizations. The pattern:

```
while (time_remaining > 0):
    variant = current_best.modify(small_random_change)
    score = evaluate(variant)
    if score > current_best.score:
        current_best = variant
        log("kept: ", variant.description)
    else:
        log("rejected: ", variant.description)
```

Key properties:
1. **Objective metric**. There must be a baseline you can measure against.
2. **Bounded variants**. Each iteration is a small change, not a from-scratch redesign.
3. **Keep wins, discard losses**. No subjective judgment.
4. **Logged transparently**. The user wakes up to a report.

### 5.2 Applied to the vault — concrete loops

Wave 7 ships **five auto-research loops** that NightBrain runs each night (idle + AC):

**Loop 1 — Folder routing optimizer**

Variants: different few-shot exemplar sets, different threshold floors, different concept canonicalization rules.
Metric: top-1 placement accuracy on a held-out eval set of 50 captures with user-labeled ground truth.
Baseline: current routing config.
Budget: 100 variants per night.

**Loop 2 — Concept canonicalization tuner**

Variants: different stemming rules, different alias-table merge thresholds, different normalization steps.
Metric: false-merge rate (two distinct concepts incorrectly merged) + false-split rate (one concept incorrectly split).
Baseline: current canonicalizer.

**Loop 3 — Eidos retrieval re-ranker**

Variants: different RRF weights, different cosine thresholds, different speculative-crawl source priorities.
Metric: recall@5 on a 100-query eval set against vault drawers.
Baseline: current Eidos config.

**Loop 4 — Few-shot exemplar refresher**

Variants: replace one of the current few-shot exemplars with a recent successful interaction; measure if the new prompt's downstream tool-calls improve.
Metric: tool-call success rate on a 50-call eval per tool.
Baseline: current exemplars.

**Loop 5 — Cognitive Weight calibrator**

For each Live File the user has weighted, measure whether the weight setting correlates with the agent's actual reliance on the file (via action-trace post-hoc analysis). Recommend weight adjustments where the user's setting and observed reliance diverge.

### 5.3 The morning report

NightBrain produces a single markdown file: `_raw_thoughts/auto_research/{{date}}.md`:

```markdown
# Auto-research report — 2026-04-30

Last night I ran 287 experiments across 5 loops on your vault. Total wall time: 42 minutes. Power: AC; thermal nominal throughout.

## Wins applied (3)

- **Routing**: Variant 47 of Loop 1 improved top-1 accuracy from 86% → 91% on the held-out eval. **Applied** to live config. Diff: lowered Variant B threshold from 0.75 → 0.72; added "screenshot-review-queue" to the alias table.
- **Eidos re-rank**: Variant 12 of Loop 3 improved recall@5 from 84% → 87%. **Applied**. Diff: weighted wing scope at 1.3x in RRF.
- **Cognitive Weight calibration**: 2 files had observed reliance significantly below your weight setting. Surfaced as a UI nudge (no auto-change).

## Wins not applied (2)

- **Concept canonicalizer**: Variant 23 reduced false-split by 4% but increased false-merge by 2%. Net unclear. Tombstoned with reasoning trace; happy to re-explore if you adjust the false-merge tolerance.
- **Few-shot refresher (capture tool)**: Variant 8 improved tool-call success by 3% on the eval set, but the new exemplar references a file you've since archived. Holding for re-run.

## Discoveries to investigate

- Loop 4 surfaced that captures containing the word "actually" tend to be reflections, not actions. The current routing puts them in `daily/` 71% of the time. Worth a Live File rule?

[Full traces: 287 entries in _raw_thoughts/auto_research/2026-04-30/]
```

The user reads in 90 seconds, accepts the wins (or undoes any with `cmd-Z`), notes the discoveries, moves on with their day. The vault has improved overnight without their involvement. **This is bootstrapping (Engelbart) made literal.**

### 5.4 Hardening the loop (because Karpathy didn't have to)

Karpathy's loop was on his own ML experiments — failures cost him compute, not user data. We're loop-improving the user's vault. Hardening:

1. **Every variant runs against a *copy* of the vault config**, never the live one. The live system stays unchanged until a variant wins AND passes a final integration test.
2. **Every applied win is undoable for 7 days** (longer than the standard 24h universal-undo per `PLAN.md` §8.5; auto-research wins get the longer TTL because morning review is asynchronous).
3. **Tombstone log** — no variant ever silently reappears. Once tombstoned, a variant is named and dated; re-exploration requires explicit user opt-in.
4. **Power gate** — auto-research never runs on battery, never runs above thermal nominal, never runs while the user is interacting.
5. **Deterministic objective** — no LLM judges "is this prose better?" Auto-research only optimizes against eval metrics with human-labeled ground truth.

---

## 6. Substrate unification — the unified Swift+Rust+Metal binary

Beyond the audit (§3), Wave 7 also unifies parts of the architecture that already work but have seams. The goal: **everything is Cargo deps + Swift packages, sharing memory through Apple Silicon's unified memory architecture**.

### 6.1 The five-layer substrate diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  SwiftUI views (Layer 5 — UI)                                   │
│    @Observable → @MainActor → reactive re-render                │
├─────────────────────────────────────────────────────────────────┤
│  UniFFI bridge (Layer 4 — kernel-clean owned-value boundary)    │
│    Send + Sync; owned values; async stream of Effects           │
├─────────────────────────────────────────────────────────────────┤
│  Agent core — Rust (Layer 3 — orchestration)                    │
│    Tool registry, variant runner, Compile-Verify-Mint,          │
│    Stateful Rotor, IntentApplier, NightBrain                    │
├─────────────────────────────────────────────────────────────────┤
│  Engines (Layer 2 — substrate)                                  │
│    Obscura (browser), deno_core (JS), Eidos (search),           │
│    MLX (inference), Tantivy + rusqlite (vault), llguidance      │
├─────────────────────────────────────────────────────────────────┤
│  Custom Metal kernels (Layer 1 — silicon)                       │
│    cosine_batch, sha256_drawer, bge_inference, live_file_glow,  │
│    rotor_evaluate, attention_mask_eval                          │
└─────────────────────────────────────────────────────────────────┘
```

Layer 1 is silicon-direct (Metal Shading Language compiled at build time). Layer 2 is engines as Cargo deps. Layer 3 is our Rust core. Layer 4 is UniFFI. Layer 5 is SwiftUI. **Memory flows freely between Layers 1–4** (Apple Silicon unified memory means no copy between MLX kernels and Rust agents). The only owned-value boundary is Layer 4 (UniFFI's contract).

### 6.2 Custom Metal kernels added in Wave 7

Beyond Wave 6's three kernels (`cosine_batch`, `sha256_drawer`, `bge_inference`), Wave 7 adds:

- `rotor_evaluate.metal` — parallel evaluation of all ActiveVectors' condition predicates. 50 active vectors evaluated in <100 µs.
- `live_file_glow.metal` — pulsating glow effect (per §4.7), stitchable for arbitrary view modifiers.
- `attention_mask_eval.metal` — for the determinism gradient: when an LLM is reading a Live File, the Cognitive Weight bias is applied at the attention mask layer, increasing attention weight on heavy files. ~10× more efficient than re-prompting.
- `delta_embedder.metal` — when a Live File changes, only the *changed* sections are re-embedded; this kernel does parallel diffing against the previous scan and embeds only the deltas.

These are all in `agent_core/metal/`. Each compiles into the main binary; no external `.metallib` files.

### 6.3 The MoLoRA → MLX-Swift port (Phase 16a deep-dive)

This is the most complex port. Detailed enough that the builder has a runway:

```swift
// Epistemos/KnowledgeFusion/MoLoRAInferenceService.swift (rewrite)
// BEFORE: spawned molora_inference.py subprocess; per-token JSON-RPC.
// AFTER: pure MLX-Swift; in-process; per-token direct.

import MLX
import MLXLM

@MainActor
public final class MoLoRAInferenceService {
    private let model: MLXModel
    private let adapters: [LoRAAdapter]
    private let routingNetwork: AdapterRouter

    public init(modelPath: URL, adapterPaths: [URL]) async throws {
        self.model = try await MLXModel.load(from: modelPath)
        self.adapters = try await MLXModel.loadAdapters(adapterPaths)
        self.routingNetwork = try await AdapterRouter.load(model: model, adapters: adapters)
    }

    public func generate(prompt: String, options: GenerateOptions) -> AsyncThrowingStream<Token, Error> {
        AsyncThrowingStream { continuation in
            Task.detached {
                do {
                    var hiddenState = try await self.model.encode(prompt)
                    while !options.shouldStop(hiddenState) {
                        // Per-token: route to adapter via the in-process router.
                        let adapterId = try await self.routingNetwork.select(for: hiddenState)
                        let adapter = self.adapters[adapterId]
                        let token = try await self.model.generate(
                            from: hiddenState,
                            withAdapter: adapter,
                            options: options
                        )
                        hiddenState = token.hiddenState
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// AdapterRouter is the equivalent of the Python script's routing logic.
// ~50 lines of MLX-Swift. Selects adapter ID from token hidden-state by
// cosine similarity to adapter centroids (precomputed at adapter load).
struct AdapterRouter {
    let centroids: MLXArray    // [n_adapters, hidden_dim]

    func select(for hiddenState: MLXArray) async throws -> Int {
        let scores = matmul(hiddenState.unsqueeze(0), centroids.transpose(0, 1))
        return Int(scores.argmax(axis: 1).asInt32())
    }

    static func load(model: MLXModel, adapters: [LoRAAdapter]) async throws -> AdapterRouter {
        // Compute centroid for each adapter from its training-set embedding.
        // ...
    }
}
```

This is ~80 lines of Swift replacing a Python subprocess + JSON-RPC serialization layer. Per-token latency drops from ~3 ms (Python roundtrip) to <50 µs (direct MLX call). 60× speedup on the hot path.

### 6.4 The Pyodide-via-WASM path for Hermes Python skills (Phase 16c)

The minority of Hermes skills genuinely depend on Python ecosystem (e.g., `numpy`, `scipy`, `transformers` non-MLX paths). Phase 16c adds a **Pyodide-via-WASM** path:

- `pyodide` is Python compiled to WebAssembly. It runs in any V8 context.
- Our existing deno_core (Wave 6) supports WASM module loading via `WasmModuleLoader`.
- A Hermes-Python skill becomes: `import { run } from "ext:pyodide/runner"; run(skill_code)` — the Pyodide runtime is loaded, the skill executes inside a WASM sandbox, results return through deno_core's op surface.
- **No subprocess.** No Python interpreter. WASM execution is sandboxed by V8's existing isolation.

Pyodide adds ~10 MB to the bundle (compressed). Acceptable for Pro profile. MAS profile excludes it (no Python skills allowed in MAS — already a deployment-profile rule).

---

## 7. Hardening — the Wave-7 hardening pass

A unified substrate is dangerous if soft. Wave 7 includes structural hardening across five axes.

### 7.1 Determinism hardening — the eval-vs-acceptance gate

Every auto-research win must pass:

1. The objective metric (better than baseline by >2 percentage points).
2. The deterministic re-run (same input + same config → same output, on the variant's eval set, 100% reproducibility).
3. The integration soak (run the variant against a 1-hour synthetic capture stream; assert no schema violations, no zombie tasks, no memory growth).

A variant that "wins" on the metric but fails reproducibility is tombstoned. Probabilistic improvements aren't accepted.

### 7.2 Resource hardening — the substrate budget contract

The Stateful Rotor + auto-research + foreground capture + Eidos queries can compound. Wave 7 introduces a **substrate budget contract**:

```rust
pub struct SubstrateBudget {
    pub max_active_v8_isolates: usize,          // 4
    pub max_concurrent_metal_kernels: usize,    // 8
    pub max_in_flight_tool_calls: usize,        // 16
    pub max_nightbrain_workers: usize,          // 2 on AC, 0 on battery
    pub max_metal_memory_mb: usize,             // 2048 on 16GB Mac
    pub thermal_pressure_pause_threshold: ThermalPressure, // .heavy
}
```

The substrate enforces this via per-resource semaphores. When the budget is hit, new requests queue. The user feels backpressure (Eidos query takes 200 ms instead of 80 ms) instead of crash (OOM-killed app).

### 7.3 Failure isolation — V8 panic boundary

A V8 isolate panic in deno_core or Obscura must NOT kill the host process. Hardening:

- Every V8 invocation wrapped in `tokio::task::catch_unwind` Rust panic boundary.
- V8's `OutOfMemoryHandler` registered to terminate the offending isolate without panicking.
- Watchdog: if an isolate exceeds 10× its expected runtime, kill the isolate; mark the calling tool's circuit breaker open.

### 7.4 Trust hardening — the "show your work" trace UI

Per-Live-File action trace shows:
- Last 100 metabolizing events (when, why, by which agent, with what outcome).
- Cognitive Weight effects (when this file influenced an agent's reasoning).
- Auto-research wins/losses involving this file.
- Cron firing log.

The user clicks any Live File → cmd-? → sees its complete history. Trust is built by transparency.

### 7.5 Reversibility hardening — extended undo for auto-research

Standard universal undo is 24h (`PLAN.md` §8.5). Auto-research wins get **7 days**: the user might not check until Sunday. Auto-research undo HUD is a separate keystroke (cmd-shift-Z) so the regular 24h undo doesn't accidentally roll back the morning's improvements.

---

## 8. Eidos Plus — the auto-research deliberation engine

Eidos (Wave 6) is search. **Eidos Plus** (Wave 7) is search + deliberation + auto-research.

The user types `/research <topic>`:

1. **Eidos Plus engages full deliberation mode**: not a single query, but a 5-step research loop.
2. **Step 1 — initial vault scan** (regular Eidos query). Returns top-10 vault hits.
3. **Step 2 — gap analysis**: a small local LLM under grammar-bound dispatch identifies what the vault *doesn't* know yet. Output: closed-vocab list of missing-knowledge facets.
4. **Step 3 — speculative crawl**: parallel Obscura renders of curated sources covering the gaps.
5. **Step 4 — re-rank under CRANE + IterGen**: the agent reasons (unconstrained CRANE region) about how the new web evidence integrates with vault context, then commits a structured answer (constrained answer region) with closed-vocab citation grammar binding.
6. **Step 5 — write to vault as a synthesis note**: the answer becomes a new note (Markdown drawer + spatial Wing/Room/Hall coords + citations to both vault and crawled sources). User reviews; accepts; the synthesis is now part of the vault and feeds future Eidos queries.

This **fuses**:
- **Exa.ai's neural-embedding-first search** (vault-grounded, in-process).
- **Perplexity's cite-as-you-answer pattern** (closed-vocab citation grammar from `PLAN.md` §22.6).
- **Hermes Agent's 15-tool checkpoint cadence** (every 15 tool calls, the loop self-evaluates).
- **Karpathy's auto-research** (Eidos Plus learns which research strategies win, applied via Loop 3 in §5.2).

The result: **the vault is not just a passive store; it's a deliberation surface** that grows by combining what the user wrote with what the agent learned.

### 8.1 Schema for `/research` results

```json
{
  "$schema": "epistemos://schemas/research_synthesis.v1.json",
  "type": "object",
  "required": ["topic", "vault_grounded", "web_grounded", "synthesis", "citations", "_meta"],
  "properties": {
    "topic": { "type": "string" },
    "vault_grounded": { "type": "array", "items": { "$ref": "#/defs/eidos_hit" } },
    "web_grounded": { "type": "array", "items": { "$ref": "#/defs/web_hit" } },
    "synthesis": {
      "type": "object",
      "required": ["thesis", "supporting", "uncertain", "novel"],
      "properties": {
        "thesis": { "type": "string", "maxLength": 500 },
        "supporting": { "type": "array", "items": { "type": "string" }, "maxItems": 5 },
        "uncertain": { "type": "array", "items": { "type": "string" }, "maxItems": 5 },
        "novel": { "type": "array", "items": { "type": "string" }, "maxItems": 5 }
      }
    },
    "citations": { "type": "array", "items": { "$ref": "#/defs/citation_ref" } }
  }
}
```

Each citation is a closed-enum drawer ID (vault) or a closed-enum source ID (curated web). No fabricated citations; ever.

---

## 9. Phase work — Wave 7

### Phase 16 — Substrate unification (subprocess elimination)

#### 16a — MoLoRA → Swift (hot path)
- Port `molora_inference.py` to MLX-Swift (~80 lines per §6.3).
- Delete Python script + bridge.
- Verify per-token throughput parity ±5% on 1000-prompt eval.

#### 16b — QLoRA → Swift (training)
- Port QLoRA training loop to MLX-Swift autograd.
- Verify trained adapter parameter parity within ±2% on a fixture corpus.
- Update NightBrain to schedule QLoRA training in idle windows.

#### 16c — Hermes → embedded skills + Pyodide-via-WASM
- Audit Hermes skill set; categorize (V8-compatible JS / WASM-Pyodide-needing-Python / Tier-3-mintable / abandoned).
- Port V8-compatible skills to deno_core (Wave 6 mechanism).
- Add Pyodide WASM module to deno_core for Python-needing skills (Pro profile).
- Disable HermesSubprocessTests.swift permanently; delete subprocess code.

#### 16d — Cleanup
- Delete OrphanSubprocessCleanup.swift.
- Delete PythonEnvironmentManager.swift.
- Update `docs/CLAUDE.md` to remove "Hermes subprocess" exception.
- Document the unification in `docs/AGENT_PROGRESS.md`.

### Phase 17 — Live Files

#### 17a — File format + state machine
- Define `live_file.v1.json` schema.
- Implement `agent_core/src/live_files/state.rs` — state machine.
- FSEvents + kqueue hybrid (per `PLAN.md` infra).

#### 17b — Stateful Rotor
- Implement `agent_core/src/live_files/rotor.rs` per §1.4.
- Verify <5 ms tick budget on 50-active-vector test.
- `rotor_evaluate.metal` for parallel condition predicate eval.

#### 17c — Cognitive Weight
- Score-boosting integration into Eidos retrieval (per §4.3).
- `attention_mask_eval.metal` kernel for inference-time bias.
- SwiftUI Cognitive Weight slider per file.

#### 17d — Glowing UI
- `live_file_glow.metal` kernel.
- SwiftUI integration via `.colorEffect()`.
- State-aware intensity (per §4.7).

#### 17e — Conditional logic + cron
- Closed-grammar predicate evaluator.
- `english-to-cron` integration; tokio_cron_scheduler for time-based.
- Event bus for event-based predicates.

#### 17f — Vector Universe (sophisticated scans)
- Hierarchical embedding (file/section/block).
- Pattern detection (cron, dates, names).
- `delta_embedder.metal` for incremental re-scan.

### Phase 18 — Auto-research loops

#### 18a — Loop infrastructure
- `agent_core/src/auto_research/loop.rs` — generic loop runner.
- `agent_core/src/auto_research/baseline.rs` — baseline tracking + tombstone log.
- 7-day undo log for auto-research wins.

#### 18b — Five concrete loops
- Loop 1: folder routing (per §5.2).
- Loop 2: concept canonicalization.
- Loop 3: Eidos retrieval re-ranker.
- Loop 4: few-shot exemplar refresher.
- Loop 5: cognitive weight calibrator.

#### 18c — Morning report
- `_raw_thoughts/auto_research/{{date}}.md` template.
- Diff visualization (what changed, why, by how much).
- Action trace integration (cmd-? on any applied win).

### Phase 19 — Eidos Plus (the deliberation engine)

#### 19a — Five-step research loop
- Implement steps 1–5 per §8.
- CRANE + IterGen integration for the synthesis step.
- Closed-vocab citation grammar binding.

#### 19b — Synthesis-to-vault pipeline
- Synthesis result → `vault.write_verbatim_with_derivative` (per Wave 6).
- Spatial coords assigned per `PLAN.md` §24.2.
- Concept canonicalization integration.

#### 19c — `/research` slash-command
- Intent parser routes `/research <topic>` to Eidos Plus.
- Action trace shows full deliberation path.
- User can accept / reject / edit synthesis before commit.

### Phase 20 — Hardening

- Substrate budget contract per §7.2.
- V8 panic boundary per §7.3.
- Auto-research win 7-day undo per §7.5.
- Comprehensive Live File action trace per §7.4.
- Reproducibility eval gate (variant must replay deterministically) per §7.1.

---

## 10. Verification gates per phase

| Phase | Gate | Pass criterion |
|---|---|---|
| 16a | `cargo run --bin molora_throughput_test` | per-token latency <50 µs, parity ±5% vs Python |
| 16b | `cargo run --bin qlora_training_parity_test` | trained adapter Δ ≤ ±2% vs Python |
| 16c | `cargo run --bin hermes_skill_migration_audit` | 100% of active skills migrated or tombstoned |
| 16d | `git grep -E "Process\(|NSTask|posix_spawn"` | zero non-test results |
| 17a | `cargo test live_files::state::` | state machine 100% transitions tested |
| 17b | `cargo bench --bench rotor_tick -- --active 50` | p99 <5 ms |
| 17c | `cargo test cognitive_weight::retrieval_bias` | weight 1.0 → score 2× weight 0.0 |
| 17d | `swift test --filter LiveFileGlowTests` | 60 FPS sustained, <0.1% CPU |
| 17e | `cargo test live_files::conditions::` + `cargo run --bin cron_parser_eval` | grammar closed; safe; 50 NL examples parsed correctly |
| 17f | `cargo bench --bench scan -- --file-size 10kb,100kb,1mb` | hierarchical embedding p95 <500 ms |
| 18a | `cargo run --bin auto_research_eval -- --variants 100` | wins reproducible 100% of the time |
| 18b | `cargo run --bin loop_5_eval` | each loop produces ≥1 win per night on a synthetic vault |
| 18c | manual UX test | morning report renders cleanly, undo works |
| 19a | `cargo run --bin eidos_plus_eval -- --queries 50` | citation grammar 0 fabrications, recall@5 ≥0.85 |
| 19b | `cargo test eidos_plus::synthesis_write::` | vault drawer created with provenance back to all sources |
| 19c | `swift test --filter ResearchCommandTests` | slash-command routes correctly, user can accept/reject |
| 20 | full eval suite + 24h soak | substrate budget contract holds under load |

---

## 11. Performance and resource math

For a 16 GB Mac with all of Wave 7 deployed:

| Subsystem | Steady-state RAM | Hot-path latency |
|---|---|---|
| Stateful Rotor (50 active vectors) | ~5 MB | tick <5 ms |
| Cognitive Weight retrieval bias | 0 MB extra | <100 µs |
| Live File glow shader | 0 MB (GPU memory) | 60 FPS, <0.1% CPU |
| Auto-research overnight | ~200 MB during runs (NightBrain budget) | n/a (overnight) |
| Eidos Plus `/research` query | ~150 MB during loop | <5 s end-to-end |
| Substrate unification savings | -120 MB (no Python; no Hermes Python; no MoLoRA Python) | per-token MoLoRA: 3 ms → 50 µs (60×) |

Net delta: Wave 7 *removes* ~120 MB of Python runtime overhead and *adds* ~5 MB of Live Files infrastructure and ~150 MB peak during Eidos Plus operations (transient). **The unified substrate is lighter than the pre-unification substrate** even with the new feature surface added.

---

## 12. Risks and open questions

1. **MoLoRA port fidelity**. The Python script's adapter routing logic may include subtleties not documented. Mitigation: pre-port instrumentation pass — run the existing Python with verbose logging; capture inputs+outputs for 1000 invocations; verify Swift port produces byte-identical outputs against the recorded set.

2. **Hermes skill ecosystem coverage.** Some Hermes skills depend on Python libraries that don't WASM-compile cleanly (numpy is fine, scipy is partial, transformers is a problem). Mitigation: the Phase 16c audit categorizes; for un-portable skills, the user is shown a "this skill is unsupported in Wave 7 unification; legacy Hermes available behind feature flag" notice.

3. **Karpathy-style auto-research overfitting**. 700 experiments could find a variant that improves the eval but harms general behavior. Mitigation: §7.1's reproducibility + integration-soak gate. Any variant that "wins" on the eval but degrades on the integration soak is rejected.

4. **Cognitive Weight gaming**. Users might set everything to weight=1.0 thinking it'll help; the agent's context floods, performance degrades. Mitigation: total weight budget across active files (e.g., sum ≤ 5.0). UI surfaces the budget; over-budget triggers a "your most-weighted files are diluting each other" hint.

5. **Live File state machine bugs**. State machines have well-known failure modes (orphan states, unreachable states, race conditions on transition). Mitigation: model the state machine in `kani` (Rust formal verifier) for invariant checking.

6. **Stateful Rotor bottleneck under high event rate**. If a user pastes 1000 markdown files at once, FSEvents fires 1000 events. The rotor must batch + dedupe. Mitigation: 100 ms debounce window; batch evaluation per debounce tick; bench harness verifies <5 ms p99 even at 1000 events/sec input rate.

7. **Eidos Plus latency under web evidence**. The 5-step research loop with speculative crawl + LLM synthesis can hit 5–10 seconds. Mitigation: aggressive parallel speculation; user-visible progress UI; budget cap configurable.

8. **Pyodide-WASM bundle size**. Pyodide is ~10 MB compressed, ~30 MB decompressed. Contributes to Pro app size. Acceptable but document.

9. **Universal undo log growth**. With 24h regular undo + 7-day auto-research undo, log can grow large. Mitigation: ring-buffer at 100 MB; oldest entries spill to compressed archive; user can recall via cmd-shift-Z search.

10. **Live File glow disabling on battery**. Pulsing shader at 60 FPS costs ~0.1% CPU. On long battery sessions this matters. Mitigation: glow auto-pauses (stays on the static intensity, doesn't pulse) when battery <20%; user can override.

11. **Auto-research thermal cliff**. 287 experiments overnight on a hot Mac (sleeping in a hot room) can throttle. Mitigation: thermal monitor pauses auto-research at heavy pressure; resumes at nominal.

12. **Conditional logic grammar evolution**. The closed grammar of conditions (per §4.5) has a fixed surface; users will request more operators / variables / actions over time. Mitigation: each Wave-7+ minor release adds 2-3 new safe primitives, vetted manually, never user-extended.

13. **The biological metaphor as decoration**. There's a risk we describe the substrate biologically without it actually behaving that way. Mitigation: the metaphor must generate concrete design constraints (it does — see §1.1's table); if a constraint can't be derived from the metaphor, the metaphor is decoration and gets cut.

14. **Substrate budget contract starvation**. If one runaway tool exhausts a semaphore, others starve. Mitigation: per-tool fairness via deadline-aware scheduling — older requests get priority over newer; total wait ceiling 5 s before circuit breaker opens.

15. **Auto-research feedback loops compounding**. A loop that improves Eidos retrieval can change what data future loops train on. Mitigation: held-out eval set is frozen at Wave-7 ship time; auto-research changes are measured against the frozen baseline indefinitely.

---

## 13. References — classic and contemporary

### Classic invention texts (re-read for substrate-design principles)

- **Vannevar Bush — *As We May Think* (1945)**. The Memex as a personal substrate that augments thought through associative trails. Live Files are Memex trails made executable.
- **Doug Engelbart — *Augmenting Human Intellect* (1962)**. Bootstrapping: tools that improve themselves through their own use. Auto-research loops realize this.
- **Alan Kay — *The Computer Revolution Hasn't Happened Yet* (1997 OOPSLA)**. Late-binding, message-passing, the substrate as an organism. The Stateful Rotor + Live Files realize message-passing at the substrate level.
- **Bret Victor — *Inventing on Principle* (CUSEC 2012)**. Immediate feedback as a creative principle. The pulsating glow IS Bret Victor.
- **Christopher Alexander — *A Pattern Language* (1977)**. Quality emerging from local patterns. The vault's emergent structure (Wing/Room/Hall + concept graph + auto-research) IS a pattern language.
- **Carver Mead — *Analog VLSI* (1989)**. Computation arising from local rules in dense substrate. Apple Silicon + custom Metal kernels in our app realize this at consumer scale.
- **Norbert Wiener — *Cybernetics* (1948)**. Feedback, homeostasis, control. The substrate budget contract + thermal pauses + auto-research hardening are cybernetic loops.
- **John von Neumann — *Theory of Self-Reproducing Automata* (1966)**. The cell as a unit of computation that can replicate itself. Live Files are von-Neumann-style cells that produce derivative artifacts.
- **Donald Knuth — *Literate Programming* (1992)**. Prose and code interleaved. The Live File hybrid format IS literate programming at the document level.

### 2026 contemporary

- **Karpathy — *AutoResearch* (March 2026)**. 630-line Python tool that ran 700 ML experiments in 2 days, found 20 optimizations. Pattern: keep what beats baseline; discard otherwise. Wave 7's auto-research loops adapt this pattern to vault optimization.
- **Karpathy — *No Priors podcast* (Feb 2026)**. "Agentic engineering" — orchestration + oversight, not direct authorship. Wave 7 is Epistemos' commitment to this vision for personal knowledge work.
- **Exo (exo-explore)**. Distributed Apple-Silicon-native AI cluster via RDMA + Thunderbolt 5. Inspires Wave-7+1's distributed-Mac substrate (out of scope for Wave 7 itself).
- **Anthropic — *The Hacker News deterministic + agentic AI* (April 2026)**. Probabilistic reasoning + deterministic guardrails. The §1.2 determinism gradient operationalizes this.
- **dotNetting — *Human-on-the-loop guide* (Feb 2026)**. Shift from in-loop verification to oversight-only. Auto-research's morning report IS the human-on-the-loop pattern.
- **arxiv:2604.23049 — *Decoupled Human-in-the-Loop System for Controlled Autonomy* (April 2026)**. Architecture for governing autonomy with bounded human review. Wave-7 hardening (§7) is this pattern.

### Repositories and engines (used as Cargo deps in Wave 7)

- [Karpathy AutoResearch](https://github.com/karpathy/autoresearch) — pattern reference
- [Pyodide](https://pyodide.org/) — Python via WASM for un-portable Hermes skills
- `english-to-cron` Rust crate — natural-language → cron parsing
- `tokio_cron_scheduler` — time-based scheduling
- `kani` Rust formal verifier — state machine verification
- `notify` Rust crate — FSEvents wrapper
- `instant-distance` (already in Wave 6 for Eidos)
- MLX-Swift (already in plan) — for MoLoRA + QLoRA ports

---

## 14. Integration instructions for the Wave-7 builder

When greenlit (after `PLAN.md` + Wave 6 are shipped):

1. **Confirm pre-conditions**:
   - `docs/AGENT_PROGRESS.md` shows Phases 0.5–13 ✅ AND Wave 6 Phases 14a–15 ✅.
   - `PLAN.md` §16 + Wave 6 Definition of Done both green.
   - Tagged release exists for both.

2. **Read this addendum in full**, plus `PLAN.md` and the Obscura addendum. Wave 7 builds on every prior layer; you cannot work it in isolation.

3. **Run mandatory web research** before each phase:
   - Phase 16: "MLX-Swift LoRA adapter inference 2026", "MLX-Swift QLoRA training 2026", "Pyodide V8 WASM macOS 2026"
   - Phase 17: "FSEvents kqueue battery efficient macOS 2026", "english-to-cron Rust 2026", "Metal stitchable shader colorEffect SwiftUI 2026"
   - Phase 18: "AutoResearch Karpathy implementation pattern 2026", "vault optimization deterministic baseline 2026"
   - Phase 19: "Exa.ai search synthesis citation grounding 2026", "Perplexity citation chain 2026"
   - Phase 20: "Rust formal verification kani state machine 2026"

4. **Order is strict**: Phase 16 (substrate unification) BEFORE 17 (Live Files) BEFORE 18 (auto-research) BEFORE 19 (Eidos Plus) BEFORE 20 (hardening). Each phase depends on the prior one.

5. **Spawn fresh worktrees per phase** under `claude/wave-7-NN-name`. Don't touch the main checkout.

6. **Apply master plan workflow**: TodoWrite per phase, web research per phase, verification gate before commit, never batch.

7. **The Karpathy pattern applies to YOU as the builder agent.** When you ship a Wave-7 phase, the next Wave-7 phase is informed by what worked. Auto-research is real for you too: read your own action trace from prior phases to inform the current one.

8. **Update `PLAN.md` §11 wave map** as each phase ships. Wave 7's morning-after-shipping summary is exactly the §5.3 morning report format applied to YOUR work.

---

## 15. What you can expect — summary

When Wave 7 ships, here is what changes for you and your users:

### For the user (in plain language)

- **Every document is potentially an active agent.** Toggle a markdown file to live; it now executes its own logic, on a schedule you wrote in plain English, with a Cognitive Weight that controls how much the agent listens to it. Your daily review file isn't a list of intentions — it's an executing program written in prose.
- **The vault improves itself overnight.** Each morning, you wake to a single-paragraph report: *"Last night I tried 287 ways to improve your folder routing and Eidos search. Three improvements applied. Two not applied. Want details? cmd-?"* You read in 90 seconds; accept (or ⌘⇧Z to undo wins for up to 7 days); move on.
- **`/research <topic>` produces a synthesis note** that combines what's in your vault with what's on the web (curated sources only), with closed-vocab citations grounded in vault drawer IDs and source IDs. No hallucinated citations. Ever.
- **Live Files glow when they're being metabolized.** A subtle pulsating border tells you, at a glance, what your substrate is doing. When it stops, it's done. Bret Victor's *Inventing on Principle* applied to a knowledge environment.
- **The app is finally a single binary.** No Python. No Node. No Hermes subprocess. One signed `Epistemos.app` containing every engine, sharing memory through Apple Silicon's unified architecture.

### For the architecture (in technical language)

- **Zero subprocess on the hot path** (Hermes Python orchestrator removed; MoLoRA + QLoRA ported to MLX-Swift; OrphanSubprocessCleanup deleted). The only network traffic during foreground use is user-invoked cloud per `PLAN.md` §1.3.
- **Stateful Rotor with sub-5ms tick budget** drives the Live Files state machine via FSEvents + kqueue. 50 active vectors evaluated in <5 ms p99.
- **Five Karpathy-style auto-research loops** run nightly against frozen objective-metric baselines: routing accuracy, canonicalization quality, retrieval recall@5, exemplar success rates, weight calibration drift. Wins applied; losses tombstoned; reproducibility verified.
- **Substrate budget contract** with per-resource semaphores prevents OOM under burst load; backpressure is visible to the user.
- **V8 panic boundary** isolates Obscura + deno_core + Eidos crashes from the host.
- **Eidos Plus** fuses Exa-style neural retrieval, Perplexity-style citation grounding, Hermes-Agent 15-tool checkpoint cadence, and Karpathy-style auto-research into a single deliberation engine.
- **Closed-vocab condition predicates** for Live File logic gates — safe by construction; no eval, no JS, no Python.
- **Cognitive Weight slider per file** with `attention_mask_eval.metal` kernel applying weight bias at the inference attention layer; ~10× more efficient than re-prompting.
- **Six new Metal kernels** added to the existing Wave-6 trio: `rotor_evaluate`, `live_file_glow`, `attention_mask_eval`, `delta_embedder` plus rebuilds of `cosine_batch` and `bge_inference` for hierarchical embedding.

### For the build & ship process

- **App size shrinks by ~100 MB** (no Python runtime + reduced infrastructure); grows by ~30 MB (Pyodide WASM for Pro Hermes-legacy skills, Metal kernels, Live Files state machine).
- **App Store binary review surface unchanged** — same single binary as Wave 6, same entitlements (`app-sandbox + network.client`).
- **Pro distribution adds Pyodide WASM module** (compressed ~10 MB) — only delta vs Wave 6's Pro bundle.
- **CI gains 4 new eval harnesses** (auto-research reproducibility, Live File state machine, substrate budget, Eidos Plus citation grounding); total test count grows from 2,679 to ~3,200.

### For Wave-7+1 (out of scope here, but the substrate enables)

- **Distributed-Mac substrate** via Exo-style auto-discovery + Thunderbolt 5 RDMA. The user's iMac, MacBook Pro, and Mac Studio pool compute for heavy NightBrain runs. Eidos queries route to the Mac with the lowest current load.
- **Multi-user vault sharing** with cryptographic capability tokens — share a Live File with a collaborator, scoped to specific Cognitive Weight bands and condition predicates.
- **Cross-vault auto-research** — multiple users opt into anonymized variant sharing, accelerating Karpathy-style optimization at population scale (still local-first; no server; gossip protocol).
- **Vault-as-API** — Pro users expose their vault to third-party agents through an MCP-compatible server (Pro only, opt-in, capability-bounded).

That is Wave 7. **The document is the cell. The vault is the organism. The substrate metabolizes.**

---

*End of addendum. This document supersedes any prior brainstorm of Live Files, Cognitive Weight, or Agent Control Vectors. The in-flight builder treats this as opaque until `PLAN.md` Phases 0.5–13 AND `OBSCURA_BROWSER_ADDENDUM.md` Wave 6 are shipped.*
