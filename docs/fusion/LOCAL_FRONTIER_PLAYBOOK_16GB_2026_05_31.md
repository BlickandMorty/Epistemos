---
state: candidate-canon
created_on: 2026-05-31
source_prompt: user-supplied Epistemos local frontier playbook for 16 GB consumer hardware
source_status: external citations and benchmark claims are intake-only until primary sources are verified
promotion_rule: no product or runtime claim promotes from this playbook without a named falsifier, local harness, visible surface, and rollback path
---

# Local Frontier Playbook For 16 GB Hardware

This playbook turns the 16 GB local-reasoning ambition into a falsifiable
architecture program. It does not claim that Epistemos already achieves
frontier-level local reasoning. It defines what would have to be true for that
claim to become honest.

The core target remains:

```text
cold trillion, hot five billion, active minimum
```

The research posture is intentionally ambitious: do not start from "consumer
hardware cannot do it." Start from "what would have to be addressable, cold,
warmed, selected, verified, and witnessed for it to work?" The disciplined
answer is not dense residency. It is UAS-addressed substrate selection across
layers, blocks, adapters, KV pages, notes, tools, kernels, and future
parameter-component atlases.

The physical guardrail stays equally strict. UAS can make SSD/AppColdStore
bytes first-class cognitive objects, but it does not make SSD latency equal RAM
latency. Any speed or quality claim must come from measured layout locality,
prewarm, cache reuse, active-byte minimization, route repair, and falsifiers.

The user-facing product goal is not a literal dense trillion-parameter model
resident on a 16 GB Mac. The goal is a governed cognitive substrate that can
wake the smallest sufficient set of evidence, graph state, KV pages, adapters,
weight blocks, tools, kernels, and verifiers for a task, then prove what it did
through RunEventLog and AnswerPacket.

## Status Lock

This document is Pro Research / Pro Vault-Preserved until falsifiers promote
parts of it. It may guide manifest schemas, route-card shapes, test design, and
safe scaffolds. It must not be cited as proof that local 70B, 128K, 1T, SSD-as-
RAM, arbitrary ANE kernels, or "better than MoE" behavior is live.

External source names in this playbook, including MLX, MLX-LM, PagedAttention,
KIVI, DMC, Mamba, Mamba-2, Titans, Tutti, DUAL-BLADE, Switch Transformer,
Mixtral, DeepSeekMoE, QLoRA, DoRA, MoLE, APD, SPD, LongBench, Loong, MMLU-Pro,
GPQA, and LiveCodeBench, are intake leads unless a future PR verifies primary
sources and pins exact claims.

## Architecture Sentence

Epistemos is not a local model wrapper. It is an app-owned substrate runtime:

```text
Intent
  -> UAS/OAS address resolution
  -> AppColdStore / ColdStore residency candidates
  -> PageGather / Shadow / VaultRecall / Eidos evidence candidates
  -> ActiveAssembly support minimization
  -> RuntimeRouter / System G route plan
  -> controller / reasoner / KV / adapter / tool / kernel execution
  -> Hyperdynamic repair and ReasoningEscrow
  -> SCOPE-Rex / SovereignGate admission
  -> RunEventLog + AnswerPacket visible proof
```

UAS is the primitive. AppColdStore is storage layout and cache control.
ActiveAssembly is waking-set selection. Eidos is evidence/citation validation.
RuntimeRouter/System G executes under policy. Primitive IRs and falsifiers
verify the pieces. The model is one executor inside the substrate.

## Target Envelope

These are candidate targets for the first serious M2 Pro 16 GB harness. They
are not product promises.

| Metric | Candidate target |
|---|---:|
| Weighted reasoning score vs fixed remote reference | 0.85-0.90x |
| Closed-citation validity | >= 98% |
| Hallucinated citation rate | <= 1% |
| Peak unified memory on M2 Pro 16 GB | <= 15.5 GB |
| First-token latency, simple note QA | <= 2.5 s p50 |
| First-token latency, research synthesis | <= 8 s p50 |
| Decode throughput | 4-12 tok/s depending on task |
| Active dense-equivalent parameters | p50 < 3B, p95 < 8B |
| Cold-store budget | 100-300 GB |
| Witness completeness for admitted outputs | 100% |

## Baselines

Do not optimize until the baselines are fixed.

| Baseline | Description | Purpose |
|---|---|---|
| A | Single quantized dense local model, no substrate, no retrieval beyond prompt stuffing. | Raw local-model floor. |
| B | Same model plus conventional note/document RAG. | Ordinary retrieval gain. |
| C | Memory-optimized baseline: paged/offloaded KV or MoE-like route, but no Eidos/repair/runtime substrate. | Infrastructure-only comparison. |
| D | Full Epistemos path: ActiveAssembly, Eidos closed citations, repair, KV/AppColdStore, UAS copy lineage, adapters. | Actual substrate thesis. |

The full architecture only wins if D beats A, B, and C on quality, evidence
validity, active bytes, and visible proof. If D is slower and not materially
better than B or C, the route should be narrowed or killed.

## Support Selection Objective

The most important runtime objective is support selection per byte:

```text
AssemblyScore(i) =
  MarginalUtility(i)
  / (Bytes(i) + lambda * Latency(i) + mu * CopyRisk(i) + nu * Drift(i))
```

Candidate support object `i` can be a note chunk, graph island, adapter delta,
weight block, KV page, tool result, kernel, proof witness, or route-card prior.

`MarginalUtility(i)` must be task-specific and evidence-backed. It should
include relevance, contradiction reduction, citation coverage, expected route
confidence, verifier gain, and downstream repair savings. Raw saliency,
embedding similarity, or model confidence is never enough by itself.

## Active Weight And State Accounting

Any "active parameter" claim must be measured, not guessed.

```text
ActiveWeightParams(request) =
  sum(touched_chunk_bytes * 8 / effective_bits_per_param)
```

Report:

- request-level union of touched weight chunks;
- per-token touched chunks where available;
- always-on controller/trunk bytes;
- selected expert/adapter bytes;
- KV bytes;
- SSM/fast-weight state bytes;
- tool-state bytes;
- cold bytes read;
- warm cache hit rate;
- large-buffer copy count.

State bytes are not parameters. KV, SSM state, fast weights, prompt caches,
tool state, and evidence packets must be reported separately.

## AppColdStore Role

AppColdStore is the app-owned substrate storage direction:

- Durable atlas: Application Support / App Group root for installed models,
  packed weight pages, adapter banks, manifests, hashes, and licenses.
- Warm cache: Caches directory for decoded page bundles, coactivation packs,
  ANE/Core ML scout outputs, reusable prompt/KV summaries, and regenerable
  scratch.
- Hot runway: mmap arena, resident buffers, Metal heaps, MLX/Metal active
  tensors, selected KV strip, and active adapter slices under strict byte
  budgets.
- Staging: atomic download/repack/verification temp roots.

SwiftData stores manifests, route cards, hashes, provenance, and visible state.
It must not store giant model/KV blobs.

App-owned storage can improve effective speed only through layout, locality,
prewarm, fewer copies, atomic rebuilds, and better eviction. It does not change
NVMe latency into RAM latency.

## Apple Silicon Split

The heterogeneous Apple route must stay honest:

| Lane | Candidate role | Hard boundary |
|---|---|---|
| ANE / Core ML | compiled scout models, route classifiers, saliency predictors, small verifier heads | no arbitrary kernels, private ANE dependency, or hidden route authority |
| MLX / MPS / Metal | tensor execution, KV/page kernels, block scan, quantized matmul, graph kernels | no claim without copy/latency/quality measurement |
| Rust substrate | UAS, AppColdStore manifests, mmap safety, scheduler, HotRentLedger, route cards | no hidden product truth; must witness |
| Lean / schema | proof artifacts, schema checks, theorem/falsifier contracts | not per-token hot path |
| Swift app shell | user-visible state, consent, review, note graph, inspector surfaces | no hidden architecture authority |

`F-AppleSilicon-RouteSplit` should prove that ANE/Core ML scouts plus Rust
scheduler plus MLX/Metal execution beat a simpler local baseline after dispatch
and copy overhead. Otherwise remove the scout lane or batch it.

## Falsifier Ladder

| Falsifier | Protects | Candidate pass criterion |
|---|---|---|
| `F-Measurement-Floor-16GB` | baseline honesty | A/B/C/D harness exists, fixed splits, peak UMA, active bytes, SSD reads, copy count, citations, and witness completeness recorded. |
| `F-ActiveAssembly-Minimal` | smallest sufficient support thesis | Support bytes drop >= 50% vs naive top-k/prompt stuffing while quality stays within 2 points of oracle support and citation recall >= 0.98 of oracle. |
| `F-KV-Direct-Gate` | long-context local viability | Hybrid RAM/SSD KV keeps peak UMA within budget, quality drop <= 2 points vs full-RAM reference, and decode remains product-usable. |
| `F-UAS-CopyCount` | Apple UMA truth | No large-buffer copies on declared hot paths and >= 99.9% hot bytes have lineage. |
| `F-AppColdStore-Layout` | app-owned storage value | Packed atlas / warm cache / prewarm beats raw snapshot layout on latency and bytes read while preserving checksum/WBO/rebuild guarantees. |
| `F-AppleSilicon-RouteSplit` | heterogeneous lane value | ANE/Core ML scout + Rust scheduler + MLX/Metal execution improves route quality or cost after dispatch/copy overhead. |
| `F-ULP-Oracle` | fused-kernel numeric honesty | Kernel outputs stay within declared tolerance against CPU reference on protected domains. |
| `F-SemiseparableBlockScan` | controller-lane viability | Route-choice quality stays near dense-controller baseline while throughput improves on long sequences. |
| `F-PageGather-M2Pro` | sketch -> rescore -> exact paging value | Bytes read and latency drop materially while support recall stays near exact retrieval. |
| `F-Erdos-Lift-Optimality` | lift/project thesis | Lift/project route beats best surface-native baseline on normalized utility-per-cost across most benchmark families. |
| `F-70B-Local-Cocktail` | composition quality claim | Full system beats A/B/C and reaches the declared remote-reference fraction under RAM, latency, citation, and witness targets. |

Existing PASS artifacts remain scoped to what they measured. For example, a
synthetic `F-ActiveAssembly-Minimal` PASS does not prove live model packet
routing. A copy-count PASS on one route does not prove all MLX/Metal hot paths.

## Roadmap Order

1. Measurement floor: A/B/C/D harness, active-byte manifests, copy lineage,
   peak UMA, SSD reads, route timing.
2. Evidence floor: Eidos closed citations, VaultCitation-style private suite,
   ResearchTrace-style synthesis suite, repair records.
3. Active Assembly: candidate support object model, sketch/rescore selector,
   oracle support comparison, PageGather.
4. AppColdStore / KV fabric: manifests, packed layout, warm cache, prefix/KV
   accounting, compressed RAM tier, SSD-cold tier.
5. Controller lane: small SSM/semiseparable/dense scout for route choice,
   interrupt scoring, page scheduling.
6. Learning lanes: adapter registry, eval cards, QLoRA/DoRA-style persistent
   deltas, bounded session-local fast weights.
7. Final integration: local cocktail / cold atlas studies only after
   measurement, evidence, support, and memory gates are stable.
8. User-facing verification: AnswerPacket, Provenance Console, Substrate
   Health, RunTimeline, and manual computer-use verification of the product
   path before promotion to Pro Live.

## Drift Guards

- Do not optimize benchmark scores before citation validity and witness
  completeness exist.
- Do not call retrieval success "reasoning" unless the answer survives
  Eidos/SCOPE-Rex/AnswerPacket checks.
- Do not call cold bytes "active parameters."
- Do not call warm cache "resident model capacity."
- Do not claim ANE acceleration unless dispatch, copy, and end-to-end route
  measurements beat the simpler path.
- Do not claim long-context victory from prompt stuffing alone.
- Do not let visual style work promote runtime claims.

## Visual Note

The tan/brown retro playbook visual language is optional presentation style,
not architecture authority. It can be used for docs or artifacts only when it
does not conflict with the active UI/theme work and does not make research
claims look shipped.
