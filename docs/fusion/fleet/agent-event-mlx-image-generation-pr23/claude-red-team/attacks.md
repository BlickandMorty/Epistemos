---
role: codex-red-team
slice: agent-event-mlx-image-generation-pr23
brief: docs/fusion/deliberation/agent_event_mlx_image_generation_pr23_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens the slice against reopening real image generation or leaking prompts/image paths.
---

## Attacks

### A1 — Do not accidentally make deferred image generation appear shipped [P2]
**Surface:** `MLXImageGenerationService.generate(prompt:aspectRatio:)`
**Attack:** Instrumentation must not convert the current explicit failure envelope into a completed/successful product signal when Flux is unavailable. A failed pipeline-resolution call should end with `.toolCallFailed`, not `.toolCallCompleted`, even though the Swift method returns a JSON envelope string to the caller.
**Evidence:** `docs/architecture/PLAN_V2_UPDATED.md` §16 says image generation is deferred and hidden until the local runtime works.
**Mitigation proposed:** Classify `MLXImageGenerationError.fluxPipelineUnavailable` as a closed failure class and record failed AgentEvents while preserving the existing returned error envelope.

### A2 — Prompt and image-path leakage risk [P2]
**Surface:** AgentEvent arguments/results for image generation
**Attack:** Image prompts are often highly private and output paths may reveal vault/user filesystem structure. Persisting either into AgentEvent JSON would violate the provenance privacy pattern from PR14-PR22.
**Evidence:** Card 7 closed slices repeatedly exclude query/prompt bodies, result text, paths, and arbitrary errors.
**Mitigation proposed:** Persist only prompt character count, aspect ratio, provider, elapsed time, hit/success status, and closed failure class.

## Brief verdict

Approved. Ship only the bounded provenance wrapper and tests; do not touch real Flux, FAL, Rust media tools, UI, catalogs, or provider routing.
