# F-AblationShadowRun - 2026-06-04

**June 1 mirror:** this page mirrors `docs/falsifiers/F-AblationShadowRun_2026_06_04.md` for the `JUNE1-CANON-FUSION-LOCK` recovery surface.

**North star:** Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Result

- Status: PASS as a metadata-only L1 architecture witness.
- Command: `Tools/falsifiers/f_ablation_shadow_run.sh`
- Artifact: `artifacts/falsifiers/ablation_shadow_run/result.json`
- Falsifier ID: `F-AblationShadowRun`
- Artifact kind: `primary_witness`
- Scope: planner / metadata evidence only; no runtime bytes, no model bytes, no live sparse route authority.
- L1 next cursor: `F-AxiomAxiomatic-SourceDistinction`
- L2 product route: still `vault_research_route_with_packetized_mitigation`
- L2 next bottleneck: `axiom_axiomatic_source_distinction`
- L3 user-facing/product runtime: unchanged.

## What Passed

The witness binds upstream `F-ShadowWakeOracle` refs, baseline and candidate traces, remove-one-unit counterfactuals, route labels, oracle label refs, quality/verifier/latency/byte deltas, decisions, rollback, RunEventLog, AnswerPacket, compatibility fence, privacy class, held-out split, and a deterministic UAS address:

`uas:ablation-shadow-run:sha256:684599ddbff33a315e5d788b0f26e7ec1e9c46f97a646046b4efba9d29a5c5ff`

Measured fixture facts:

- `fixture_count=2`
- `ablation_run_count=6`
- `retained_case_count=4`
- `demoted_case_count=1`
- `abstain_case_count=1`
- `decision_accuracy_bps=9350`
- `retained_success_bps=9120`
- `min_retained_quality_delta_bps=390`
- `min_retained_verifier_delta_bps=350`
- `max_retained_latency_delta_ms=42`
- `max_retained_byte_delta=1572864`

The retained candidates beat keep-all, remove-all, random-ablation, and no-ablation baselines.

## Hardening

The binary rejects empty, duplicate, missing, stale, incompatible, hidden-authority, hidden-chain, cloud-source, live-promotion, base-weight-mutation, route-policy-mutation, cache-mutation, runtime-byte, model-byte, unbeaten-baseline, low-accuracy, low-retained-success, weak-quality, weak-verifier, latency-overflow, byte-overflow, diversity-missing, and metadata-over-budget fixtures before any route claim can promote.

## Truth Layers

L1 advanced. This witness proves the architecture cursor can move past ablation because useful units survive a counterfactual remove-one-unit shadow run with visible rollback/log/packet evidence.

L2 did not advance to product-green. The capability kernel still reports `overall_pass=false`, route status `vault_research_route_with_packetized_mitigation`, and next bottleneck `axiom_axiomatic_source_distinction`.

L3 did not advance. No user-facing runtime, MAS capability, live 70B route, live PatternBoost route, or autogenous-kernel behavior is promoted by this metadata witness.
