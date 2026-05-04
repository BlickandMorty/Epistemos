# Google Research Prompt — Epistemos Agents, Local Models, and Useful Note-Workflows

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



You are doing a deep technical and product research pass for a real macOS app that already exists and is actively used.

Your task is not to redesign the app from scratch.
Your task is to determine the best production-grade way to add truly useful agents to the current app.

Read all attached markdown files before answering.

## What This App Is

This is **Epistemos**, a native macOS knowledge app built with:

- Swift 6
- SwiftUI
- AppKit bridges for the note editor
- SwiftData
- Metal
- Rust FFI for the graph engine

Today the app already has:

- a polished home / landing experience
- a main AI chat
- a native note editor with inline AI note chat
- a research service
- a query engine over the graph + search index
- a full-screen graph overlay driven by Rust + Metal
- a detached settings window
- Apple Intelligence routing for simple tasks
- cloud providers for harder tasks

Do not propose restoring old shell UI, old nav pill, old library, or old product structure.
The current app visuals and layout are the baseline to preserve.

## What The User Actually Wants

The user wants agents that are genuinely useful for second-brain and note-taking work, especially:

- research
- note enrichment
- note organization and linking
- essay writing
- drafting and rewriting
- proactive but not annoying note assistance

The user is specifically unsure about:

- whether there is a true native Swift 6 way to build powerful agents
- whether a Swift + Rust split is better
- whether agents should use local models, APIs, or both
- how to get the same feeling of power and usefulness seen in strong API-backed agent products

The user does not want shallow demo agents.
The user wants real agents that can actually do meaningful work inside the app.

## Hard Constraints

These are not optional:

- Preserve the current app structure and visual direction.
- Do not restore the old broad multi-agent UI blindly.
- Treat the current app as the baseline and extend it carefully.
- Apple Intelligence should remain the first routing layer for trivial/simple tasks.
- MLX local models should be the next local intelligence layer.
- Qwen should remain the primary local family.
- Gemma should remain the secondary local fallback family.
- Chatterbox should remain the primary TTS engine if voice is part of the plan.
- The answer must optimize for real shipping quality on macOS, not demo quality.
- The answer must distinguish clearly between:
  - what can be built cleanly now
  - what should be deferred
  - what is too risky or too heavy for V1

## Historical Context You Must Respect

This repo contains three different layers of agent planning:

1. A large March 7-10 native multi-agent vision
2. A real but later reverted implementation across phases 1-10
3. A later, more pragmatic OpenClaw-style "minimal agent runtime" direction

Your answer must reconcile these rather than blindly picking one.

## What You Need To Determine

### A. Best architecture for agents in this exact app

Determine the best architecture for agents inside this existing codebase:

- Swift-native only
- Rust-native only
- hybrid Swift + Rust

Be decisive about:

- where agent orchestration should live
- where tool execution should live
- where memory should live
- where session state should live
- where approvals / permissions should live
- where streaming and UI integration should live

### B. Best way to achieve actually impressive agent behavior

The user explicitly wants agents that feel powerful, not fake.

Research what actually makes note-oriented agents feel strong in practice:

- model quality
- tool design
- retrieval quality
- session memory
- planning loop
- approvals
- UI visibility
- proactive behavior
- writeback safety
- undo / audit logs

Explain what matters most and what matters less.

### C. Local vs API vs hybrid

The user is unsure whether agents should be local, API-based, or both.

Determine the best architecture for:

- Apple Intelligence
- MLX local Qwen + Gemma
- cloud frontier models

Be specific about:

- which layer should handle triage
- which layer should handle summarization / extraction / compaction
- which layer should handle planning
- which layer should handle multi-step research
- which layer should handle writing / essay generation
- which layer should handle tool-using autonomous loops

Explain how to get strong API-agent quality while still benefiting from local models.

### D. Best initial agent set

Propose the best V1 agents for Epistemos today.

Likely candidates include:

- Research agent
- Librarian / enrichment agent
- Writer / essay agent
- Organizer / linker agent

Determine:

- which should ship first
- which should be merged or split
- which old concepts should be dropped or deferred

### E. Best tool system for this app

Determine the best tool architecture using the app's existing capabilities.

Consider tools like:

- notes create / read / update
- graph query / graph search
- search index / full-text search
- research search
- note enrichment
- vault access
- app-specific query engine

Recommend:

- tool schema style
- approval model
- safe write model
- undo / replay / audit trail
- tool budget / recursion guard
- cancellation model

### F. Best memory architecture

The old plan proposed working, episodic, and semantic memory.

Determine the best realistic memory system for this app now:

- what should exist in V1
- what should be deferred
- what should remain lightweight
- how graph + notes + search index should participate
- whether Rust should own semantic memory / retrieval

### G. Best UI and UX

The user wants agents to be useful without breaking the current app.

Recommend the best agent UI strategy for this exact app:

- main chat integration
- note-level agent workflows
- background agent dashboard or not
- research mode integration
- notifications
- approvals
- logs / review surfaces
- whether graph NPCs should be deferred

### H. Best implementation plan for this repo

Use the attached repo context to produce a step-by-step implementation plan that fits the current codebase.

It must include:

- architecture recommendation
- V1 scope
- phase order
- what should not be restored from the old system
- where to reuse existing services
- what to prototype first
- what to harden before shipping

## Required Output

Your answer must be structured and decisive.

Give me:

1. Executive recommendation
2. Most accurate interpretation of the repo's old agent plans
3. Best architecture for this exact app
4. Best local/API/hybrid model routing strategy
5. Best V1 agent set
6. Best tool and memory architecture
7. Best UI / UX architecture
8. Step-by-step implementation plan for this codebase
9. Risk register
10. What not to do

## Important Constraints

- Be concrete.
- Do not hide behind "it depends."
- Do not recommend a huge framework unless it is clearly superior.
- Prefer solutions that fit a native Swift + Rust macOS app.
- Distinguish clearly between aspirational ideas and practical V1 choices.

