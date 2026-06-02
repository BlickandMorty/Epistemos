---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: recursive browser/bookmark/X intake plus primary validation of LLM visualizations, mechanistic arithmetic probes, LLM sorting, agent traces, and observability systems
status: architecture doctrine; no product promotion without replayable traces, privacy redaction, diagnosis, rollback, byte budgets, and visible proof
---

# Substrate Trace Observatory - 2026-06-01

## Thesis

The next breakthrough is not another hidden router. It is the ability to watch
the substrate think at the unit Epistemos claims to control.

For UAS/AppColdStore, the 70B cocktail, active cold storage, and neural-control
claims to become plausible, each important run must emit a replayable trace
frame for the units it selected:

```text
source cards
  + prompt/cache/KV pages
  + model route and feature/heuristic probes
  + proof or verifier lane
  + tool and agent actions
  + cold faults and byte budgets
  + answer deltas
  -> CognitiveTraceGraph
  -> RouteMicroscopeFrame
  -> diagnosis / layout patch / route patch / proof repair
```

The app should not only answer; it should show the route by which the answer
became physically and logically credible. Visualizations are not tutorial
decorations here. They become engineering instruments: a way for the user and
future agents to inspect attention/KV pressure, source grounding, heuristic
neurons, comparison/ranking failures, tool actions, cold misses, and verifier
events.

This preserves the ambition: Epistemos can become a new software paradigm by
making cold cognition addressable, schedulable, and inspectable.

It preserves the rigor: if the route cannot be replayed, diagnosed, redacted,
and tied to a falsifier, it is not substrate control. It is only a story.

## Why this exists

The bookmark pass found a distinct cluster that the current working-set canon
did not yet fully absorb:

- LLM and transformer visualizations show that model internals can be made
  inspectable enough for humans to reason about.
- Arithmetic and sorting analyses show that small mechanistic details, such
  as heuristic neurons or pairwise comparison failures, can dominate reasoning
  quality.
- Editor/CLI agents such as `99` and Kimi Code CLI show the ergonomics of
  search, work, logs, MCP/tools, and source-aware coding loops.
- Observability systems show the trace/span vocabulary that production AI
  applications already use, but the canon needs a diagnosis and replay layer
  above ordinary logs.
- X bookmark search surfaced KV-cache and VRAM-pressure threads, reinforcing
  that KV, prompt cache, context, and cold-memory behavior must be visible as
  separate first-class costs.

The missing organ is a microscope: a local, redacted, replayable observatory
that turns every route into a structured object the app can compare.

## Bookmark intake translated into doctrine

| Source handle | Signal | Canonical interpretation |
|---|---|---|
| `bbycroft.net/llm` and transformer visualization bookmarks | Transformer internals can be shown as layers, attention, residual flow, logits, and token probabilities. | Build `RouteMicroscopeFrame` as an operational visualization of real Epistemos traces, not a static explainer. |
| Pradyumna Chippigiri visualization list | The user saved a curated map of high-quality interactive transformer explainers. | Visualization quality is part of engineering: if a future agent cannot inspect the route, the route is under-instrumented. |
| Data Processing Club arithmetic analysis and arXiv 2410.21272 | Arithmetic behavior can be explained by sparse heuristic neurons and logit contributions rather than a clean algorithm. | Add `AlgorithmicFailureProbe` and `HeuristicNeuronCard` for bounded mechanistic probes where model access permits. |
| Data Processing Club LLM sorting analysis | LLM calls can act as noisy comparison functions; listwise methods can become unstable at scale. | Route ranking, source ranking, and brain selection need comparison traces, parse checks, and tournament audits. |
| ThePrimeagen/99 | Agentic editor work benefits from search, work tracking, logs, file/rule completion, provider switching, and stop controls. | The Epistemos agent surface should expose work-search traces and cancelable in-flight route frames instead of hiding them in chat. |
| Kimi Code / Kimi CLI | Modern coding agents read/edit code, run shell commands, search/fetch the web, use MCP/ACP, and adjust actions during execution. | Tool and agent actions become `AgentActionFrame`s inside the same trace graph as model and source events. |
| ResearchRabbit / Consensus / NotebookLM bookmarks | Source-grounded research tools organize literature, map connections, and answer against source corpora. | Source tools feed `SourceReasoningOverlay`, but Eidos, citations, and proof gates decide evidence authority. |
| X bookmark search: KV-cache and VRAM threads | Practical local inference pain often comes from KV/cache/context memory, not only model weights. | `AttentionKVTrace` must report KV bytes, prompt-cache hits/misses, eviction, compatibility, and quality caveats separately from weight bytes. |

## Source links

- LLM Visualization: `https://bbycroft.net/llm`
- Best LLM and Transformer Visualizations: `https://pradyumnachippigiri.dev/til/ai/llm-transformer-visualizations`
- How LLMs Really Do Arithmetic: `https://data-processing.club/llmmath/`
- Sorting with LLMs: `https://data-processing.club/llmsort/`
- Arithmetic Without Algorithms: `https://arxiv.org/abs/2410.21272`
- Verifying Chain-of-Thought Reasoning via Its Computational Graph:
  `https://arxiv.org/abs/2510.09312`
- Sequences of Logits Reveal the Low Rank Structure of Language Models:
  `https://arxiv.org/abs/2510.24966`
- ThePrimeagen/99: `https://github.com/ThePrimeagen/99`
- Kimi Code: `https://www.kimi.com/code/`
- Kimi CLI: `https://github.com/MoonshotAI/kimi-cli`
- OpenTelemetry traces: `https://opentelemetry.io/docs/concepts/signals/traces/`
- Langfuse observability overview: `https://langfuse.com/docs/observability/overview`
- Phoenix tracing concepts:
  `https://arize.com/docs/phoenix/tracing/concepts-tracing/what-are-traces`
- ResearchRabbit: `https://www.researchrabbit.ai/`
- Consensus: `https://consensus.app/`
- NotebookLM: `https://notebooklm.google.com/`
- X bookmark signal - KV Cache Explained:
  `https://x.com/itsjayyy_07/status/2050963647988740178`
- X bookmark signal - KV cache / VRAM pressure:
  `https://x.com/Maor_Elkarat/status/2050866949643477241`

## Primary validation extracted

| Source | Validated motif | Architecture use |
|---|---|---|
| OpenTelemetry traces | A trace is made of spans; spans carry attributes, events, links, status, and nested parent/child relationships. | `CognitiveTraceGraph` uses trace/span semantics instead of ad hoc logs. |
| Langfuse observability docs | LLM application tracing captures prompts, responses, token usage, latency, tools, retrieval, timing, inputs, outputs, and metadata. | Epistemos traces must include model, source, tool, cost, and retrieval events when they shape output. |
| Phoenix/OpenInference docs | LLM systems use span kinds such as chain, retriever, reranker, LLM, embedding, agent, and tool. | Trace frames should classify every route event so the UI can filter and replay by subsystem. |
| Data Processing Club arithmetic + arXiv 2410.21272 | Sparse heuristic neurons and logit-lens-style contributions can explain correct and incorrect arithmetic outputs. | Mechanistic probes become optional Pro Research artifacts, never hidden product proof. |
| arXiv 2510.09312 | Computational graphs of reasoning steps can expose structural fingerprints of errors and guide targeted interventions. | `VisualProofCapsule` should bind answer quality to computational/route structure where accessible. |
| arXiv 2510.24966 | Sequences of logits can reveal low-rank structure across model outputs. | `LogitSubspaceSketch` can become a cheap diagnostic for route drift and model-region reuse. |
| Kimi Code / Kimi CLI | Agents can combine terminal execution, codebase analysis, web fetch, MCP tools, and IDE/ACP integration. | Epistemos should represent every such action as a typed, replayable, cancelable `AgentActionFrame`. |
| ThePrimeagen/99 | Editor agents expose search/work operations, logs, provider selection, and stop controls. | Agent UI should prioritize searchable traces, quick-fix style action lists, and explicit stop surfaces. |

## L16-Candidate: Observable Substrate Law

A local cognitive substrate becomes engineerable only when every selected
source, page, cache, model route, tool action, proof lane, and failure mode
emits a replayable trace frame dense enough for a human or agent to debug.

```text
Utility(trace | route) =
  diagnosis_delta
  + replay_delta
  + source_grounding_delta
  + verifier_delta
  + layout_learning_delta
  + user_trust_delta
  - trace_overhead
  - privacy_risk
  - redaction_loss
  - UI_complexity
  - stale_diagnosis_risk
```

Promotion condition:

- every important route emits spans for retrieval, rerank, model call, KV
  event, verifier, tool action, cold fault, cache restore, layout patch, and
  answer emission where applicable;
- every span has owner organ, UAS address or pinned runtime identity,
  privacy class, byte/token/cost fields where relevant, and rollback link when
  a mutation occurs;
- route traces can be replayed or dry-run compared against a frozen fixture;
- failures are classified by layer: source, retrieval, ranking, context,
  KV/cache, model route, tool, verifier, cold I/O, UI, or policy;
- redaction prevents private bookmark, browser, note, prompt, and credential
  leakage before traces enter research corpora;
- visual surfaces do not claim hidden chain-of-thought access; they show
  route, evidence, spans, deltas, and verifier artifacts; and
- AnswerPacket exposes which trace frames materially shaped the answer.

## New primitive set

### `CognitiveTraceGraph`

The typed graph of one mission's execution.

```text
CognitiveTraceGraph {
  mission_id
  trace_id
  spans
  source_edges
  kv_edges
  model_route_edges
  tool_edges
  verifier_edges
  cold_fault_edges
  answer_packet_ref
  redaction_manifest
}
```

### `RouteMicroscopeFrame`

The visual unit the user can inspect.

```text
RouteMicroscopeFrame {
  frame_id
  trace_id
  timestamp
  organ
  selected_unit_ref
  why_selected
  bytes_or_tokens
  latency
  quality_delta
  verifier_delta
  visible_summary
  drilldown_refs
}
```

### `AttentionKVTrace`

KV and attention/cache behavior as a first-class witness.

```text
AttentionKVTrace {
  model_id
  tokenizer_id
  prompt_digest
  kv_unit_refs
  hit_tokens
  miss_tokens
  evicted_tokens
  kv_bytes
  codec
  compatibility_fence
  quality_caveat
}
```

### `AlgorithmicFailureProbe`

A bounded probe for tasks where the model may be relying on fragile heuristics.

```text
AlgorithmicFailureProbe {
  task_family
  fixture_set
  expected_algorithm
  observed_route_features
  heuristic_matches
  logit_or_score_delta
  failure_signature
  intervention_candidate
}
```

### `HeuristicNeuronCard`

Optional Pro Research card for known local models where hooks are available.

```text
HeuristicNeuronCard {
  model_id
  layer
  unit_or_feature_id
  activation_condition
  downstream_token_or_route_effect
  dataset_fixture
  ablation_delta
  privacy_class
  caveat
}
```

### `SourceReasoningOverlay`

Connects sources to reasoning steps without turning a source tool into
authority.

```text
SourceReasoningOverlay {
  source_card_refs
  cited_claims
  unsupported_claims
  contradiction_flags
  retrieval_span_refs
  rerank_span_refs
  citation_span_refs
}
```

### `AgentActionFrame`

Typed tool/editor/browser/shell action as a replayable trace unit.

```text
AgentActionFrame {
  action_id
  provider
  tool_name
  input_digest
  output_digest
  capability_scope
  side_effect_class
  cancel_state
  rollback_handle
  log_ref
}
```

### `TraceComparisonDeck`

Side-by-side comparison of runs, routes, prompts, cache policies, or model
choices.

```text
TraceComparisonDeck {
  baseline_trace
  candidate_trace
  changed_units
  quality_delta
  evidence_delta
  verifier_delta
  byte_delta
  latency_delta
  failure_delta
  decision
}
```

### `TelemetryToWorkingSetPatch`

The bridge from observability to actual layout/routing improvement.

```text
TelemetryToWorkingSetPatch {
  trace_refs
  diagnosed_layer
  patch_type: layout | prefetch | cache | route | prompt | verifier | tool
  expected_delta
  held_out_fixture
  rollback_handle
  promotion_gate
}
```

### `VisualProofCapsule`

The visible proof surface for one answer.

```text
VisualProofCapsule {
  answer_packet_ref
  route_microscope_refs
  source_overlay_ref
  verifier_refs
  kv_trace_ref
  cold_fault_ref
  diagnosis_summary
  user_visible_limits
}
```

### `HumanDebugHandle`

A stable handle that lets the user jump from answer to trace without exposing
private internals by default.

```text
HumanDebugHandle {
  handle_id
  answer_packet_ref
  redaction_level
  default_view
  export_policy
  local_only
}
```

## Architecture bridge

`Substrate Trace Observatory` is not a new authority. It is a witness layer
over existing organs:

```text
MissionPacket
  -> Eidos / SourceSignalGraph
  -> RouteScoutSSM / SparseWakeProposal / VerifierBudgetAuction
  -> SemanticWorkingSetPlan
  -> ResidencyPageTable / PrefetchWindow / TransportRunManifest
  -> RuntimeRouter / System G
  -> model, cache, transport, verifier, tool, editor, browser, graph events
  -> CognitiveTraceGraph
  -> RouteMicroscopeFrame / VisualProofCapsule
  -> TelemetryToWorkingSetPatch
  -> SCOPE-Rex / SovereignGate promotion
  -> RunEventLog + AnswerPacket
```

The observatory is the bridge between **visible proof** and **learning
layout**. It does not wake bytes. It proves what woke, why it woke, what it
cost, whether it helped, and what patch should be considered next.

## 2026-06-01 companion trace frames

Two newer candidate laws add required trace surfaces:

- L17 sparse wake routes must emit a route-scout frame with scout inputs,
  selected/rejected units, verifier budget, expected hot/KV/cold bytes,
  uncertainty, ablation/shadow-run status, and fast-weight regret update.
- L18 ColdStream routes must emit a transport frame with byte ranges,
  destination lease, codec stage, copy count, cancellation group, p95/p99
  stall, read amplification, fallback, and AnswerPacket caveat.
- L20 Residency PatternBoost routes must emit a discovery frame with assembly
  genome, constraint repair edits, sparse fingerprint, held-out fixture scores,
  elite-archive lineage, LatticeAbstentionGate result, ComputeResumeLease,
  distilled cold-route patch, rollback handle, and ablation status.

Neither frame may expose hidden chain-of-thought or become authority. They are
debug handles for route, byte, and verifier decisions.

## Product posture

MAS/Pro-safe:

- AnswerPacket trace summary;
- source overlay with citations and unsupported-claim flags;
- KV byte/token summary without hidden chain-of-thought;
- cold-fault summary;
- tool/action log with redaction;
- "why this route" compact view.

Pro Research only:

- activation hooks;
- heuristic-neuron cards;
- logit-subspace sketches;
- intervention candidates;
- replay of private browser/bookmark traces;
- trace-derived policy mutation.

Never:

- expose hidden chain-of-thought as truth;
- store raw private browser/bookmark/search data without redaction;
- promote trace-derived patches without held-out validation and rollback;
- treat an attractive visualization as proof;
- let a tracing backend become the source of architectural authority.

## Backlog

1. Define `CognitiveTraceGraph` schema and redaction manifest.
2. Add trace span taxonomy: source, retriever, reranker, model, embedding,
   KV/cache, page-table, prefetch, verifier, tool, editor, browser, answer.
3. Add `RouteMicroscopeFrame` renderer to the lattice/artifact layer first.
4. Create a dry-run fixture where a `SemanticWorkingSetPlan` emits a trace,
   then a `TelemetryToWorkingSetPatch`.
5. Add a `ResidencyPatternBoostTrace` dry-run fixture before any discovered
   route/layout patch is allowed to influence live routing.
6. Bind `VisualProofCapsule` to AnswerPacket in documentation before code.
7. Add privacy gates before importing Chrome/X/bookmark traces into any
   durable research corpus.

## Canonical read rule

Read this file when a session touches trace observability, LLM visualization,
attention/KV visualization, mechanistic interpretability probes, heuristic
neurons, route microscopy, sparse wake debugging, transport tracing,
model-route debugging, agent action replay, OpenTelemetry/Langfuse/Phoenix-style
tracing, source-grounded research UI, visual proof, cold-fault diagnosis, or
trace-derived policy/layout patches.
