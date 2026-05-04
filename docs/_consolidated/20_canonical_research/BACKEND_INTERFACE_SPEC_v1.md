# Backend Interface Spec v1.1

> **Index status**: CANONICAL-RESEARCH — 3-layer runtime spec (Rust control plane + gguf/mlx/remote runtimes); canonical operations (load_model/generate/cancel/...) for Phase 1.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



## Summary
Epistemos uses a three-layer runtime architecture.

- Rust is the control plane and owns routing, lifecycle, policy, cancellation, telemetry, fallback, and safety decisions.
- `gguf`, `mlx`, and later `remote` are sibling execution runtimes under that control plane.
- Model artifacts are backend-specific packaging details, not app-level architecture concepts.
- Phase 1 primary text generation runtime is `gguf`.
- `mlx` is a permanent runtime and must remain first-class for embeddings, adaptation, image generation, and MLX-native auxiliary models.
- `remote` exists in the contract shape but is not a Phase 1 implementation target.
- No runtime may silently reroute, self-escalate, or switch backends without a Rust control-plane decision.

## Public Contract

### Canonical operations
Rust exposes these operations:

- `load_model(request) -> model_handle`
- `unload_model(model_handle) -> unload_result`
- `generate(request) -> stream_handle`
- `cancel(stream_handle) -> cancel_result`
- `stats(target) -> runtime_stats`
- `set_policy(policy) -> policy_result`
- `embed(request) -> embedding_result`
- `adapt(request) -> adapt_result`
- `image_generate(request) -> image_result`

Phase 1 scope:

- Fully implement `load_model`, `unload_model`, `generate`, `cancel`, `stats`, and `set_policy`.
- Implement `embed` through `mlx` when embeddings are live.
- Keep `adapt` and `image_generate` in the public contract but return explicit `unsupported_capability` until their owning phases begin.
- Keep advanced execution features policy-gated, capability-checked, telemetry-visible, and fail-closed by default.

### Required identities
- `runtime_kind`: `gguf`, `mlx`, `remote`
- `execution_mode`: `local`, `remote`, `hybrid`
- `model_id`: logical model identity
- `artifact_id`: optional backend-specific packaged artifact identity
- `reasoning_profile`: optional requested reasoning profile resolved by Rust policy
- `execution_policy_ref`: optional opaque Rust-issued policy handle for bounded compute steering

Use `model_id` for routing, UX identity, and logical policy. Use `artifact_id` for backend loading, telemetry, and artifact-specific diagnostics.

### Runtime resolution
`runtime_kind` in requests may be optional.

Rules:

- If omitted, Rust resolves the runtime from routing policy and capability.
- If provided, it is a requested runtime, not an unconditional override.
- Rust may deny or override a requested runtime if policy, capability, or safety requires it.

Expose both identities in telemetry and summaries:

- `requested_runtime_kind?`
- `resolved_runtime_kind`

### Capability handshake
The control plane exposes a preflight capability handshake before execution begins.

- `handshake(request) -> runtime_handshake`

Handshake purpose:

- resolve the runtime before launch
- resolve the reasoning profile before launch
- expose machine-readable runtime capabilities before execution begins
- make fallback explicit before work starts
- fail closed on unsupported operations instead of discovering the mismatch after launch

Handshake request fields:

- `requested_runtime_kind?`
- `execution_mode`
- `operation`
- `reasoning_profile?`
- `execution_policy_ref?`

Handshake result fields:

- `requested_runtime_kind?`
- `resolved_runtime_kind`
- `requested_reasoning_profile?`
- `resolved_reasoning_profile?`
- `execution_policy_id?`
- `capabilities`
- `used_fallback_resolution`

Handshake rules:

- unsupported operations fail with `unsupported_capability`
- denied profiles or mismatched policy refs fail with `policy_denied`
- fallback remains Rust-owned and visible through `used_fallback_resolution`
- the handshake is advisory/preflight and does not permit runtimes to self-reroute

### Model handle rules
Model handles are runtime-scoped and not portable across runtimes.

Rules:

- A handle loaded by `gguf` is valid only for `gguf`.
- A handle loaded by `mlx` is valid only for `mlx`.
- Cross-runtime handle use must fail deterministically with `invalid_transition` or `model_not_loaded`.

### Generation request shape
Generation requests include:

- `request_id`
- `requested_runtime_kind?`
- `execution_mode`
- `model_id`
- `artifact_id?`
- `model_handle?`
- `prompt`
- `system_prompt?`
- `max_output_tokens`
- `temperature`
- `stop_sequences`
- `tool_policy_ref?`
- `context_ref?`
- `reasoning_profile?`
- `execution_policy_ref?`
- `priority`
- `timeout_ms`
- `stream_options`

Do not include provider-specific cloud fields, auth, or Overseer connector schema in this runtime contract.

### Pull-stream interface
The public generation surface is pull-based.

Exposed operations:

- `poll_event(stream_handle) -> generation_event`
- `poll_events(stream_handle, max_events) -> [generation_event]`
- `close_stream(stream_handle) -> close_result`

Event types:

- `started`
- `token`
- `status`
- `tool_status`
- `summary`
- `completed`
- `failed`
- `cancelled`

Event ordering guarantees:

- `started` must be first if emitted.
- `token` may only appear after `started`.
- `summary` may appear before a terminal event, never after one.
- Exactly one terminal event is allowed.
- No event may appear after `completed`, `failed`, or `cancelled`.

Event semantics:

- `token` contains visible output only.
- `status` contains runtime state such as `loading_model`, `prefill`, `decode`, `ssd_read`, `fallback_engaged`.
- `tool_status` is optional in Phase 1 and only appears when a local path actually includes tool execution.
- Internal callbacks are allowed behind the boundary, but the public contract remains pull-based.

### Summary and error model
Every run emits a normalized summary containing:

- `request_id`
- `requested_runtime_kind?`
- `resolved_runtime_kind`
- `requested_reasoning_profile?`
- `resolved_reasoning_profile`
- `execution_mode`
- `model_id`
- `artifact_id?`
- `execution_policy_id?`
- `fallback_mode`
- `time_to_first_token_ms`
- `total_duration_ms`
- `tokens_per_second`
- `output_token_count`
- `output_character_count`
- `memory_pressure_state`
- `execution_phase`
- `masking_state`
- `kv_policy_state`
- `expert_budget_state`
- `adaptation_state`
- `guardrail_state`
- `plan_trace_present`
- `cancelled`
- `error_class`

Typed error classes:

- `model_not_found`
- `model_not_loaded`
- `unsupported_capability`
- `timeout`
- `cancelled`
- `policy_denied`
- `runtime_unavailable`
- `memory_pressure`
- `invalid_transition`
- `backend_failure`
- `contract_violation`

Backend-specific failures must be normalized into this shared set before leaving the runtime boundary.

### Capability reporting
`stats(target)` and the runtime handshake must expose machine-readable capability flags for the resolved runtime:

- `supports_generate`
- `supports_embed`
- `supports_adapt`
- `supports_image_generate`
- `supports_structured_masking`
- `supports_dynamic_sparsity`
- `supports_speculative_decoding`
- `supports_streaming_from_ssd`
- `supports_kv_policy`
- `supports_expert_budgeting`
- `supports_serial_io_audit`
- `supports_tool_calls`

Phase 1 capabilities must be truthful. Unsupported advanced features must not be advertised as available.

## Routing, Ownership, and Preservation

### Phase 1 routing defaults
- Main chat and primary local reasoning use `gguf`.
- Complex local reasoning under the control plane uses `gguf`.
- Embeddings use `mlx`.
- Adaptation uses `mlx`.
- Image generation uses `mlx`.
- MLX-native auxiliary local models use `mlx`.

### MLX Preservation Rule
MLX is a permanent runtime in the architecture, not a compatibility shim.

Rules:

- Do not remove existing MLX runtime, loading, or management infrastructure unless replacing it with an equivalent MLX path behind the new contract.
- Do not delete MLX-native support for embeddings, rerankers, classifiers, auxiliary local models, or future adaptation/image workloads.
- Do not treat GGUF as a universal replacement for MLX.
- GGUF is the primary Phase 1 text-generation runtime only.
- If MLX generation paths are migrated during Phase 1, migrate them behind the new contract rather than deleting them.
- Any MLX feature not actively wired into Phase 1 main chat should be marked secondary, experimental, or auxiliary, not removed.

### Adapt scope
`adapt(request)` is reserved for lightweight backend-scoped adaptation operations.

It includes future:

- LoRA workflows
- micro-TTT workflows
- adapter application flows

It does not imply:

- unrestricted training
- full fine-tuning
- broad training orchestration in v1

### Fallback authority
All fallback and reroute decisions belong to Rust.

Rules:

- Runtimes may report memory pressure, backend failure, unsupported capability, or serial-policy violations.
- Runtimes must not silently reroute to another backend.
- Runtimes must not self-escalate to cloud.
- Runtimes must not switch from `gguf` to `mlx` or vice versa without a Rust decision.
- Unsupported or failing requests return normalized errors and let Rust decide reroute, fail, or defer.

### Phase 1 non-goals
- No full GGUF/MLX generation parity
- No dual-primary text-generation systems
- No mid-generation backend switching
- No provider-specific cloud behavior in the base runtime contract
- No broad feature expansion before the interface is locked

## Migration and Test Plan

### Migration sequence
- Write `Backend Interface Spec v1` as the lock document before further runtime expansion.
- Introduce shared Rust request, event, summary, and error types above all runtimes.
- Migrate the current primary local text path behind the contract with `gguf` as the resolved Phase 1 generation owner.
- Migrate existing MLX infrastructure behind the same contract without deleting it.
- Keep cloud abstract in the contract and out of provider-specific implementation during Phase 1.

### Contract tests
- load -> generate -> poll -> complete
- load -> generate -> cancel -> cancelled
- one and only one terminal event per stream
- no event after terminal event
- unsupported operations return `unsupported_capability`
- backend-specific failures normalize into shared error classes

### Routing and handle tests
- main chat resolves to `gguf`
- embeddings resolve to `mlx`
- requested runtime may be overridden by Rust policy
- requested and resolved runtime identities are visible in summaries
- cross-runtime handle reuse fails deterministically

### Serial and fallback tests
- no SSD read while GPU compute is active
- turn-boundary readahead only occurs at turn boundary
- expert prefetch remains disabled
- fallback transitions are threshold-driven and observable
- runtimes report conditions, Rust decides fallback

### Telemetry tests
- every run reports runtime identity, model identity, TTFT, tok/s, fallback mode, phase, and error class
- cancelled runs still emit normalized summary data
- artifact-specific diagnostics remain visible through `artifact_id`
- plan trace presence remains visible through summaries and stats

## Assumptions and Defaults
- Phase 1 primary text-generation runtime is `gguf`.
- `mlx` remains a permanent first-class runtime.
- The public streaming interface is pull-based.
- The initial implementation target is local execution only.
- `remote` is a reserved runtime kind in v1, not a Phase 1 provider implementation.
- Any v1 capability present in the public contract but not implemented in Phase 1 must fail explicitly with `unsupported_capability`.
- Reserved capabilities must not silently no-op, partially execute, or return placeholder success.
