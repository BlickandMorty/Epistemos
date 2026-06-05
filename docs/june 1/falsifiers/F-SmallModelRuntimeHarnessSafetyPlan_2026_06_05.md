# F-SmallModelRuntimeHarnessSafetyPlan — Small-Model Runtime Harness Safety Plan

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

Status: PASS metadata-only primary witness on 2026-06-05.

Command:

```bash
Tools/falsifiers/f_small_model_runtime_harness_safety_plan.sh
```

Artifact:

```text
artifacts/falsifiers/small_model_runtime_harness_safety_plan/result.json
```

## Scope

`F-SmallModelRuntimeHarnessSafetyPlan` consumes the `small_model_runtime_harness_safety_plan` cursor and proves the small-model runtime harness safety plan is ready for a dry-run-only witness. It does not run MLX, load model bytes, spawn subprocesses, mutate route policy, touch 70B runtime probes, or promote product capability.

## What Passed

- Required stages are bound: catalog inventory, dry-run witness, owner approval gate, abortable runtime probe, and evidence review.
- Required lanes are bound: `qwen3_small_catalog_smoke`, `local_agent_notes_research_smoke`, and `coding_tool_dry_run_smoke`.
- Every lane requires a serialized executor, cancellation ref, rollback ref, RunEventLog ref, AnswerPacket ref, privacy fence, owner approval, and dry-run-first evidence.
- Budgets are bounded before runtime: context, prompt, decode, memory, runtime seconds, and metadata bytes.
- Invalid fixtures reject missing/duplicate lanes, missing stages, missing owner approval, missing dry-run-first evidence, runtime-enabled lanes, missing executor/cancellation/rollback/AnswerPacket/privacy refs, budget overflow, MAS overclaim, L2/L3 green claims, hidden route authority, route-policy mutation, gate bypass, AnswerPacket suppression, hidden chain/cloud fallback, subprocess spawn, autogenous-kernel attempts, 70B probe attempts, runtime/model/transport bytes, metadata overflow, and nondeterministic addresses.

## Three-Layer Truth

L1 architecture cursor advanced to `small_model_runtime_harness_dry_run_witness`.

L2 capability route remains `vault_research_route_with_packetized_mitigation`; live local 70B, KV-Direct 128K, live ColdStream transport, and live small-model product runtime are still red.

L3 user-facing/product runtime is unchanged.

## Rollback

If this witness becomes stale, rerun `Tools/falsifiers/f_small_model_runtime_harness_safety_plan.sh`, then regenerate `Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh` and `Tools/falsifiers/f_architecture_pending_work_guard.sh`. Do not run the MLX harness or promote a product/runtime route from this metadata witness alone.
