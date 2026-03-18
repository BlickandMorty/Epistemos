# Recovered Agent Plan History

This repo contains several different agent plans. They are not all equal.

## The Three Historical Layers

### 1. The big March 7-10 vision

Primary docs:

- `docs/plans/2026-03-07-agent-system-design.md`
- `docs/plans/2026-03-07-agent-system-implementation-plan.md`
- `docs/superpowers/specs/2026-03-10-craft-inspired-vision-design.md`

This was the biggest vision:

- native multi-agent knowledge workstation
- four agents: Triage, Librarian, Writer, Builder
- MLX-first local inference
- Learning Pool via Perplexica-style search
- graph NPCs
- Chatterbox voice
- trust levels
- agent panel / dashboard
- memory system

This is the most complete aspirational vision.

### 2. The real historical implementation

Key commits:

- `74242ad` Phase 1: MLX on-device inference provider
- `fe367fe` Phase 2: Agent Engine Core
- `69008ee` Phases 3-5: Librarian, Writer, Builder agents
- `89b9803` Phase 6: Learning Pool scaffold
- `7b783df` Phase 7: Graph NPC state
- `d165391` Phase 8: Voice system scaffold
- `10c4871` Phase 9: Three-tier memory system
- `b0ec6fc` Phase 10: notification / trust / voice settings UI
- `6944dd0` TTS fully integrated across all surfaces
- `60efc0c` revert of phases 1-10

This proves the repo did not just have ideas. It had real code.

### 3. The later pragmatic direction

Primary source:

- `docs/future-work-audit.md` Wave 14.2 "Autonomous Agents (Open Claw)"

This direction is much more grounded:

- app-owned agent runtime
- simple `plan -> tool_call -> observe -> repeat` loop
- agents use the app's own providers as brains
- agents use the app's own commands/services as tools
- smaller, less theatrical scope

This is probably the best practical correction to the earlier big vision.

## Most Accurate Interpretation

The most accurate current understanding is:

- the March 10 v5 spec is the most complete statement of what the user wanted
- the March 7 implementation plan is the most detailed execution map
- the reverted phases 1-10 prove the system was structurally real
- the later OpenClaw-style backlog is the best grounded direction for what should be built now

So the correct modern direction is not:

- restore the whole old multi-agent product as-is

It is:

- keep the current app
- recover the best ideas
- rebuild a more useful, more practical agent layer on top of today's architecture

## User Intent Captured In The Old Docs

Important locked decisions from the old design docs:

- agent communication should support manual and ambient collaboration
- notes agents should be both passive and proactive
- trust should be configurable
- triage should be model-driven
- the user wanted Claude Code style agent loops
- the user wanted real note/research usefulness, not passive mascots

The old docs are valuable because they capture user intent, even where the product scope was too large.

