# F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe - 2026-06-05

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

- Status: PASS, retained L1 runtime primary witness.
- Command: `Tools/falsifiers/f_small_model_runtime_harness_first_token_runtime_probe.sh`
- Artifact: `artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/result.json`
- Sidecar: `artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/live_probe.json`
- Current L1 cursor: `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe`
- Scope: one owner-approved, local, small-model first-token probe only; not MAS Live, not app WRV, not L2 green, not a 70B route, and not a 128K shard rerun.

## What It Proves

This witness consumes `F-SmallModelRuntimeHarnessLoggedRuntimeSmoke` and validates a retained redacted MLX sidecar for `Qwen/Qwen3-4B-MLX-4bit`. The probe observed exactly one first token from a synthetic non-user prompt, recorded the prompt hash and token hash, retained no raw token text, and bound the run to rollback, RunEventLog, AnswerPacket, privacy, budget, SCOPE-Rex, SovereignGate, compatibility, and cancellation refs.

The retained sidecar records `load_ms=1525`, `first_token_ms=737`, `total_ms=2261`, `chunks_observed=1`, `output_token_count=1`, `first_token_utf8_len=1`, and `model_bytes_loaded=2153272351`. This is intentionally not metadata-only: small local model bytes were opened for the retained falsifier probe.

## Required Rejections

The primitive rejects missing sidecar/logged-smoke/model/config/tokenizer/prompt/admission/SCOPE-Rex/SovereignGate/compatibility/cancellation/rollback/RunEventLog/AnswerPacket/privacy/budget/token refs, missing phases, duplicate runs, missing first token, more than one output token, raw token retention, user-data prompts, zero runtime or model bytes for the live probe, over-budget bytes or timings, committed mutation, route-policy mutation, gate bypass, AnswerPacket suppression, hidden route authority, hidden chain/cloud, app-path subprocess spawn, autogenous-kernel attempts, 70B probes, long-context shard probes, MAS overclaims, false L2/L3 green claims, metadata overflow, and nondeterministic addresses.

## Three-Layer Truth

- L1: Advanced. `F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe` passes as retained small-model runtime evidence and that landing cursor is historical; downstream product AnswerPacket, product-route recheck, fresh safety, fresh live, fresh AnswerPacket, and fresh WRV rungs now pass, and the current regenerated guard reports `next_existing_work=small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe` with duplicate risk `0` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe`.
- L2: Not advanced. The capability kernel remains `overall_pass=false`, route status `vault_research_route_with_packetized_mitigation`, with `next_bottleneck=small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe` after downstream `F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe`.
- L3: Not advanced. User-facing/product runtime and WRV are unchanged; the app has not yet proven a reachable local-model AnswerPacket path, MAS live agent mode, live 70B, or KV-Direct 128K.

## Caveat

This proves the harness can produce one small local first token under a retained, redacted, bounded witness. The next unit must packetize that runtime output into app-side AnswerPacket/RunEventLog proof before any product-route or user-facing claim can move.
