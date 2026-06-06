---
falsifier: F-TurboVec-RuntimeShadowBenchmarkPlan
date: 2026-06-06
status: PASS
scope: metadata-only T1/L1 research-to-build witness
---

# F-TurboVec-RuntimeShadowBenchmarkPlan

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 witness.

Artifact:

- `artifacts/falsifiers/turbovec_runtime_shadow_benchmark_plan/result.json`
- Command:
  `Tools/falsifiers/f_turbovec_runtime_shadow_benchmark_plan.sh`
- Primitive:
  `agent_core/src/uas/turbovec_runtime_shadow_benchmark_plan.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_turbovec_runtime_shadow_benchmark_plan.rs`
- Upstream witness:
  `F-TurboVec-LatencyMemoryAbstention`
- Deterministic shadow-plan address:
  `turbovec_runtime_shadow_benchmark_plan:3b10b4f388e95d4009649ee03a53fdb2dbba633539a03eeb50fc2469f3b98478@1779039600000`
- Next research-to-build unit:
  `turbovec_quarantine_real_adapter_owner_approval_probe`

Measurements:

- 1 accepted runtime shadow benchmark plan.
- 6 tiny replay scenarios: warm-hit, cold-miss, cancellation, memory pressure,
  empty allowlist, and recall regression.
- 59 red fixtures rejected.
- 1 shadow win recorded and 5 visible fallback/abstention cases.
- Max p99 latency: `40000` micros.
- Max planned replay bytes: `160000`.
- Minimum planned memory headroom: `-32000`.
- Max recall delta: `200000` micros.
- Zero opened/loaded index bytes.
- Zero allocated runtime bytes.
- Zero model/runtime/provider bytes.
- Zero copied product files.

## Hardening Axes

The witness proves:

- the upstream latency/memory abstention witness is bound and cursor-aligned;
- shadow replay must be deterministic and sample-counted;
- exact AppColdStore baseline comparison remains required;
- recall regression cannot be recorded as a shadow win;
- p95/p99 latency, timeout, cancellation, and memory envelopes are enforced;
- cold miss, cancellation, memory pressure, empty allowlist, and recall
  regression cases must fall back visibly;
- rollback, RunEventLog, AnswerPacket, and compatibility-fence refs are
  required;
- shadow replay cannot mutate routes or inject model context;
- runtime/index/model/provider/product-copy bytes remain zero;
- MAS, Live, T2+, L2/L3, live dense 70B, SSD-as-RAM, and hidden route
  authority claims reject.

## Scope Boundary

This advances only the TurboVec/Eidos research-to-build L1 branch. It does not
import TurboVec, run a benchmark, build or open an index, allocate runtime
buffers, load Gemma/QAT/GGUF/MLX/LiteRT/model bytes, choose RuntimeRouter or
System G routes, advance L2 capability, or make L3 user-facing model capability
green.

Correct phrasing:

> Architecture/research-to-build cursor advanced; product capability and user
> surface did not.

## Next

The next retrieval/index research-to-build unit is
`turbovec_quarantine_real_adapter_owner_approval_probe`, because the first real
external adapter probe must be owner-approved, quarantined, provenance-bound,
and non-authoritative before compressed retrieval can influence
large-local-model context selection.
