# NEW_SESSION_PROMPT_AUDITED


> **Index status**: SUPERSEDED-HISTORICAL — Phase-specific historical reference; superseded by MASTER_FUSION.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).


Continue work in `/Users/jojo/Downloads/Epistemos`.

Before making any edits, READ THESE FILES FIRST and summarize them back in your own words:

REQUIRED ARCHITECTURE DOCS
- `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`

OPTIONAL RESEARCH DOCS
Only read these if the task touches the relevant area or if the architecture docs leave a gap:
- localized compute research synthesis docs
- phase-one clarification docs
- KAN / TTT / MoE / SSM research maps
- Siri routing research docs
- longer “Contextual Scalpel” exploratory writeups

STOP CONDITIONS
Do not start coding until you:
1. summarize the architecture,
2. identify the current phase,
3. identify what is explicitly in scope,
4. identify what is explicitly out of scope,
5. identify any contradictions or missing hooks in the existing codebase.

If any required architecture files are missing, say exactly which files are missing and stop.

NON-NEGOTIABLE TRUTHS
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
- The overseer is a supervisory role, not a fixed model family.
- SSM/Mamba belongs primarily to memory compression and helper roles, not default planner identity.
- Hierarchical agent coordination is allowed; unrestricted agent swarms are not.

IMPLEMENTATION DISCIPLINE
- Audit first.
- Preserve MLX.
- Keep GGUF primary for main reasoning.
- Use explicit telemetry and fail closed.
- Do not widen scope casually.
- Do not claim a capability is working unless it is actually executing and verified.

REPORT FORMAT BEFORE CODING
Reply with:
A. architecture summary
B. current phase
C. scoped task interpretation
D. contradictions / missing hooks
E. exact file-level plan

Only after that should implementation begin.
