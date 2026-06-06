---
title: F-TurboVec-RecallQualityExactBaseline
created_on: 2026-06-06
status: PASS
artifact: artifacts/falsifiers/turbovec_recall_quality_exact_baseline/result.json
scope: metadata-only T1/L1
---

# F-TurboVec-RecallQualityExactBaseline - 2026-06-06

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

PASS as a metadata-only primary witness. `F-TurboVec-RecallQualityExactBaseline` turns the prior crash-safe persistence witness into a recall-quality contract: compressed Eidos/TurboVec results must be compared against exact AppColdStore baselines, must remain a subset of Scope/Sovereign allowlists, must exclude deleted/private/unknown IDs, and must abstain with visible proof when recall misses the floor.

Artifact:

- `artifacts/falsifiers/turbovec_recall_quality_exact_baseline/result.json`
- Command: `Tools/falsifiers/f_turbovec_recall_quality_exact_baseline.sh`
- Primitive: `agent_core/src/uas/turbovec_recall_quality_exact_baseline_plan.rs`
- Binary: `agent_core/src/bin/falsify_turbovec_recall_quality_exact_baseline.rs`

## What Passed

- 1 accepted recall-quality plan.
- 5 held-out synthetic query fixtures: exact hit, private/deleted exclusion, duplicate-source dedupe, recall-miss abstention, and empty-allowed visible AnswerPacket.
- 53 red fixtures rejected.
- Exact baseline refs are AppColdStore refs, not README/provider claims.
- Below-floor recall is allowed only when the query visibly abstains/fallbacks; the accepted miss fixture records `500000` micros recall and does not mutate route state.
- Zero exact-baseline/index/model/runtime/provider bytes opened or loaded.
- Deterministic recall-quality plan address:
  `turbovec_recall_quality_exact_baseline_plan:3a1c57cf29d30f2dc36724267b80e15640a25e8876ac9ff5b1c46fa04f6c014f@1779039400000`
- Next research-to-build unit:
  `turbovec_latency_memory_abstention_plan`

## Hardening Axes

The witness proves:

- the upstream crash-safe persistent-index gate must already be PASS and point at this cursor;
- exact AppColdStore baselines, held-out query coverage, and declared recall calculation are required;
- approximate results must be a subset of the allowlist and cannot include deleted/private/unknown IDs;
- duplicate exact/result/allowlist IDs reject;
- empty allowed results require a visible AnswerPacket;
- below-floor recall must abstain or fallback with proof refs;
- latency budget and memory ledger are declared but not measured as live runtime proof;
- rollback, RunEventLog, AnswerPacket, and compatibility fence are required;
- exact-baseline/index/model/runtime/provider byte counts remain zero;
- hidden route authority, route mutation, MAS/Live/T2+ promotion, live dense 70B, and SSD-as-RAM claims reject.

## Scope Boundary

This advances L1 architecture cursor truth only for the TurboVec compressed-retrieval research branch. It does not import TurboVec code, build an index, open exact baseline files, measure live recall, prove latency, load Gemma/QAT/GGUF/MLX/LiteRT, choose RuntimeRouter/System G routes, advance L2 capability, or make L3 user-facing model capability green.

Correct phrasing:

> Architecture cursor for TurboVec recall-quality hardening advanced; product capability and user surface did not.

## Next

The next retrieval/index research-to-build unit is `turbovec_latency_memory_abstention_plan`, because exact-baseline quality is now specified but latency, memory, timeout, and abstention envelopes still need proof before compressed retrieval can help large-local-model context selection.
