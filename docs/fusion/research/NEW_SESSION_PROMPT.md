Continue work in `/Users/jojo/Downloads/Epistemos`.

Before making any edits, READ THESE FILES FIRST and summarize them back in your own words:

- `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`

Do not start coding until you:
1. summarize the architecture,
2. identify what phase we are in,
3. identify what is explicitly out of scope,
4. identify any contradictions or missing implementation hooks.

If any of these files are missing, say exactly which ones are missing and stop before implementation.

Non-negotiable truths:
- Rust is the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` are sibling runtimes.
- `gguf` owns primary local text generation.
- `mlx` is permanent and owns embeddings, helper models, adaptation, image generation, and Apple-native auxiliary workloads.
- No silent backend rerouting.
- No runtime self-escalates to cloud.
- No mid-generation backend switching.
- Public runtime contract stays pull-based.
- Serial GPU->SSD->GPU invariant must hold in streamed/fallback paths.
- Trust the OS page cache.
- No speculative expert prefetch during active decode.
- Base weights stay immutable.
- Adaptation is bounded, reversible, MLX-first, and helper-model-first.

Implementation rule:
- audit first
- preserve MLX
- keep GGUF primary for main reasoning
- use explicit telemetry and fail closed
- do not widen scope casually
