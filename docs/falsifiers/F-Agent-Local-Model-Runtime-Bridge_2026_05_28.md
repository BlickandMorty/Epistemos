# F-Agent-Local-Model-Runtime-Bridge

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Date: 2026-05-28

## Purpose

Keep the core local-agent claim honest.

Epistemos already has a local model catalog, MLX runtime surface, GGUF runtime
surface, and a System G event seam. This falsifier asks the harder question:
does `AgentRuntimeV2` actually route `ProviderPolicy::LocalMlx` into live local
model generation, stream those events through System G, and emit an
`AnswerPacket` with local-model provenance?

Current answer: yes for the guarded local-model bridge slice. The artifact is
a primary witness for local-model handoff, live prompt-suite execution, and
AnswerPacket provenance. It is not a 70B, 128K, or capability-ceiling pass.

## Artifact

```text
artifacts/falsifiers/agent_local_model_runtime_bridge/result.json
```

Current status: schema-valid primary witness.

Current bottleneck:

```text
ready_for_capability_ceiling_recheck
```

## Command

```bash
Tools/falsifiers/f_agent_local_model_runtime_bridge.sh
```

Expected exit is zero while the local-model bridge source audit and retained
live prompt-suite artifact remain valid. The script validates the artifact
shape with `falsifier_validator` and does not launch a new model run by itself.

## Current Axes

| Axis | Meaning |
|---|---|
| `local_model_catalog_available` | The app has the local model catalog and Qwen3 floor entries. |
| `qwen3_floor_fallback_preserved` | The practical fallback remains `Qwen3-8B-MLX-4bit`. |
| `dense_36b_gate_preserved` | The dense 36B model gate remains 32 GB even in power-user mode. |
| `mlx_runtime_client_available` | The Swift MLX runtime client exists. |
| `gguf_runtime_client_available` | The Swift GGUF runtime client exists. |
| `provider_policy_local_mlx_available` | Agent blueprints can name a local MLX provider policy. |
| `system_g_event_seam_available` | System G can stream events and produce witnessed AnswerPackets. |
| `local_agent_adapter_dispatch_wired` | The Rust LocalAgent adapter has a real dispatch body. **Pass as of 2026-05-28.** |
| `rust_local_mlx_handoff_wired` | Rust System G accepts `ProviderPolicy::LocalMlx` and emits a local-model handoff instead of pretending Rust owns Swift/MLX generation. |
| `swift_local_model_handoff_event_wired` | Swift mirrors the local-model handoff event and provider policy payload. |
| `swift_local_model_handoff_consumed` | The real System G seam consumes the handoff through the registered local client. |
| `app_bootstrap_local_client_registered` | App bootstrap registers `RealSystemGRunSeam` with the local model client. |
| `system_g_local_model_provider_dispatch_wired` | System G hands `ProviderPolicy::LocalMlx` to live local generation. **Pass as of the retained prompt-suite witness.** |
| `live_local_model_answerpacket_provenance_wired` | The emitted AnswerPacket records the live local model identity/provenance. |
| `live_agent_local_model_prompt_suite_passed` | Retained local prompt-suite witness shows at least one live local-model handoff, token stream, model id, and AnswerPacket provenance. |

## Non-Drift Rule

This falsifier is not allowed to turn green from catalog metadata alone. Its
current primary witness depends on the retained live prompt-suite artifact:

```text
artifacts/falsifiers/agent_local_model_runtime_bridge/live_prompt_suite.json
```

That artifact records `Qwen/Qwen3-8B-MLX-4bit`, `token_chunk_count=10`,
`total_output_chars=41`, `system_g_local_model_handoff_seen=true`, and
`answerpacket_local_model_provenance_seen=true`.

Even while green:

- local models may be exposed only through the already-gated product routes;
- System G V1 deterministic dispatch remains synthetic for non-local provider
  routes; the local-model handoff route is the witnessed path;
- the 70B/UAS route remains Pro Vault-Preserved / Pro Research only;
- a long-context candidate model cannot satisfy the canonical Qwen3 floor
  unless the matching falsifier is explicitly retargeted.

## Promotion Condition

This row is promoted only for the local-agent runtime bridge slice because one
retained local prompt suite proves:

1. `AgentBlueprint.provider_policy == ProviderPolicy::LocalMlx` reaches live
   MLX or GGUF generation.
2. System G emits streaming events from that runtime rather than echoing the
   prompt.
3. The `AnswerPacket` records model ID, runtime kind, context length, fallback
   or dynamic attention mode, and local provenance.
4. The route remains tier-honest: MAS stays practical; Pro may run the local
   agent bridge; Vault keeps 70B experiments red until the capability ceiling
   gates pass.
