# RESEARCH_INDEX.md
## Purpose
This file tells Codex which research docs exist, how much authority they have, and when to read them.

## Rule
Do NOT treat all research docs as equal.
Use them in this order:

### Tier 1 — Source of Truth
Read first and follow unless the codebase proves otherwise:
- `BACKEND_INTERFACE_SPEC_v1.md`
- `PLAN_V2.md`
- `CODEX_CONTEXT_PACK.md`
- `COMPUTE_STEERING_SPEC_v1.md`
- `ADAPTATION_SUBSYSTEM_SPEC_v1.md`
- `OVERSEER_AND_AGENT_HIERARCHY.md`

These are the distilled architecture docs.
They override raw brainstorming docs when there is conflict.

### Tier 2 — Implementation Guidance / Research Synthesis
Read if needed for deeper context:
- uploaded `GPT4.md` / `Phase-One Clarification`
- uploaded `GPT 6.md` / `Unifying localized compute research with the Epistemos runtime plan`
- uploaded `Perplexity 5.md` / `Localized Compute Research Map`
- uploaded long-form localized compute PDF / hardware + MLX + Rust synthesis

Use these to:
- understand why the architecture is shaped this way
- validate bounded placement of KAN / TTT / MoE / SSM
- justify invariants like serial GPU->SSD->GPU and MLX helper-model preservation

### Tier 3 — Historical / exploratory / visionary docs
Read only when explicitly needed:
- older Gemini / Claude / ChatGPT / Perplexity syntheses
- early “Contextual Scalpel” writeups
- brainstorming docs that assume more simultaneous features than the current plan allows

Use these as idea backlogs, not direct build instructions.

## What Codex should do with the research
- Extract constraints, not vibes
- Prefer consensus findings over one-off exciting claims
- Reject claims that conflict with the current architecture unless code or measurements justify a change
- Keep KAN in bounded graph/reranking roles
- Keep TTT/LoRA in bounded MLX helper-model adaptation roles
- Keep SSM/Mamba in memory-compression/helper roles
- Keep MoE/SSD streaming inside the GGUF runtime lane and preserve the serial invariant

## Hard warning
Do not let raw research documents widen scope during implementation.
The architecture docs remain the build source of truth.
