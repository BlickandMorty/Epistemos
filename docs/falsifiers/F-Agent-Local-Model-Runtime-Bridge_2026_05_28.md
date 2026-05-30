# F-Agent-Local-Model-Runtime-Bridge

Date: 2026-05-28

## Purpose

Keep the core local-agent claim honest.

Epistemos already has a local model catalog, MLX runtime surface, GGUF runtime
surface, and a System G event seam. This falsifier asks the harder question:
does `AgentRuntimeV2` actually route `ProviderPolicy::LocalMlx` into live local
model generation, stream those events through System G, and emit an
`AnswerPacket` with local-model provenance?

Current answer: no. The artifact is intentionally red.

## Artifact

```text
artifacts/falsifiers/agent_local_model_runtime_bridge/result.json
```

Current status: schema-valid failure report.

Current bottleneck:

```text
wire_system_g_provider_policy_local_mlx_to_live_generation
```

## Command

```bash
Tools/falsifiers/f_agent_local_model_runtime_bridge.sh
```

Expected exit is non-zero until the live local-model agent bridge is wired. The
script still validates the artifact shape with `falsifier_validator`.

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
| `system_g_provider_policy_fail_closed_wired` | System G can accept a provider-aware `ProviderPolicy::LocalMlx` request and terminates with `local_provider_not_bound` instead of synthesizing model tokens. **Pass as of 2026-05-28.** |
| `system_g_local_model_provider_dispatch_wired` | System G calls live local model generation for `ProviderPolicy::LocalMlx`. **Still red.** |
| `live_local_model_answerpacket_provenance_wired` | The emitted AnswerPacket records the live local model identity/provenance. |

## Non-Drift Rule

This falsifier is not allowed to turn green from catalog metadata alone. A pass
requires live local generation on the laptop and witnessed provenance in the
packet path.

Until then:

- local models may be exposed only through the already-gated product routes;
- System G / AgentRuntimeV2 provider dispatch may fail closed, but must stay
  scaffold-labeled for live generation;
- the 70B/UAS route remains Vault/Research-only;
- a long-context candidate model cannot satisfy the canonical Qwen3 floor
  unless the matching falsifier is explicitly retargeted.

## Promotion Condition

Promote only when one local prompt suite proves:

1. `AgentBlueprint.provider_policy == ProviderPolicy::LocalMlx` reaches live
   MLX or GGUF generation.
2. System G emits streaming events from that runtime rather than echoing the
   prompt.
3. The `AnswerPacket` records model ID, runtime kind, context length, fallback
   or dynamic attention mode, and local provenance.
4. The route remains tier-honest: MAS stays practical; Pro may run the local
   agent bridge; Vault keeps 70B experiments red until the capability ceiling
   gates pass.
