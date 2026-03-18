# Reference Repos And Research Questions

These local repos and files were part of the broader planning context and should be considered during research.

## Local Reference Repos On Disk

Under:

- `/Users/jojo/projects/logic to implement/`

Relevant items:

- `openclaw-main`
  - important for agent loop patterns and tool-runtime ideas
- `picoclaw-main`
  - important for minimal agent-runtime philosophy
- `Perplexica-master`
  - relevant to the old Learning Pool / research-engine idea
- `mlxchat-main`
  - important for MLX Swift architecture and streaming/local model UX
- `chatterbox-master`
  - important for TTS packaging/runtime direction
- `fish-speech-main`
  - useful comparison point, likely later-phase voice option rather than default
- `CoPaw-main`
  - useful comparative inspiration for agent behavior and ergonomics
- `Agent Document.md`
  - likely historical external reasoning input tied to the old agent direction

## Prior Repo Docs To Respect

- `docs/plans/2026-03-07-agent-system-design.md`
- `docs/plans/2026-03-07-agent-system-implementation-plan.md`
- `docs/superpowers/specs/2026-03-10-craft-inspired-vision-design.md`
- `docs/future-work-audit.md`
- `docs/session-handoff-2026-03-07.md`

Also note the existing MLX/TTS Google research pack:

- `docs/google-research-pack-2026-03-18/`

That pack is relevant because the best agent answer should be consistent with:

- Apple Intelligence first
- MLX local next
- Qwen primary local family
- Gemma fallback local family
- Chatterbox as the main TTS engine

## Direct Questions To Answer

Please answer these concretely:

1. What is the best true agent architecture for this app today: Swift, Rust, or hybrid?
2. How should agent sessions and UI state map onto the current Swift app?
3. What should Rust own first, if anything?
4. What should the first three truly useful agents be?
5. How should those agents integrate with:
   - main chat
   - note chat
   - research
   - graph search / query
   - settings
6. What is the best local/API/hybrid routing strategy to actually make these agents impressive?
7. What are the best first MLX models for these agents on MacBook Pro hardware?
8. What should remain local, and what should use frontier APIs?
9. How should tools, approvals, undo, audit logs, and safe writeback work?
10. Which pieces of the old big vision should be deferred or dropped?

## Decision Standard

Please optimize for:

- usefulness
- native macOS quality
- architectural fit with this repo
- safety
- performance
- realistic shipping scope

Do not optimize for:

- maximum conceptual ambition
- framework novelty
- theatrical UI before usefulness

