# Architecture Options And Recommended Direction

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



This file frames the core architecture choice.

## Option A — Swift-native agents

Pros:

- best UI integration
- best fit with current `@Observable` state model
- easiest streaming into SwiftUI / AppKit
- aligns with the old `AgentEngine` direction

Cons:

- risk of mixing too much orchestration, tool execution, and UI state together
- harder to keep long-running agent loops isolated from view concerns
- less natural place for search/memory/tool-runtime heavy lifting

## Option B — Rust-native agents

Pros:

- good fit for durable loops, step execution, tool runtime, logs
- good fit for retrieval, search, memory, and file/graph operations
- aligns with the pragmatic OpenClaw-style backlog direction

Cons:

- weaker direct integration with current Swift-first state and UI layers
- more bridging complexity for session state and interactive approval flows
- easy to overbuild too early

## Option C — Hybrid Swift + Rust

Pros:

- best fit for this repo
- Swift can own UI, session presentation, settings, and app integration
- Rust can own durable step runtime, retrieval-heavy tools, memory/search internals, and audit logs
- aligns with the repo's actual architecture style

Cons:

- more boundary design work up front
- requires discipline to avoid duplicating logic across languages

## Recommended Direction

The best fit for Epistemos is a **hybrid architecture**:

- Swift owns:
  - agent session state presented to the UI
  - agent dashboards / approval surfaces
  - chat and note integration
  - model routing coordination
  - high-level orchestration
- Rust owns:
  - tool execution runtime
  - step logs / action history
  - search-heavy and memory-heavy backends
  - durable plan/tool/observe loops if they become complex

## Important nuance

This does **not** mean "build the whole agent engine in Rust first."

A good practical sequence is:

1. Swift-first session orchestration on top of existing app services
2. shared tool contracts
3. move retrieval / step-runtime pieces into Rust where it clearly helps

## Recommended Product Direction

Do not restore the old huge multi-agent workstation whole-cloth.

Instead:

- keep the current app
- add a powerful but focused agent layer
- start with useful note/research/writing agents
- defer graph NPCs and broad theatrical surfaces

## Recommended V1 Agent Set

Best likely V1 set:

- **Research Agent**
  - research synthesis
  - source gathering
  - reading and summarization
- **Librarian / Enrichment Agent**
  - summarize notes
  - connect notes
  - extract tasks / themes / follow-ups
  - suggest links and structure
- **Writer Agent**
  - rewrite
  - essay drafting
  - note-to-outline
  - note-to-essay / note-to-brief

The old Builder concept is probably not the right first priority for this app now.

