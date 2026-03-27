# Epistemos V1 Scope Boundary

## Purpose

This document defines the release boundary for a coherent Epistemos V1.

The goal is to judge the product by the app that exists today and the core note-thinking value it already delivers, not by the full Omega / agent / training / autonomy moonshot described across older research papers.

## What Counts As V1

Epistemos V1 is the local-first macOS thinking app centered on:

- native note creation, editing, and navigation
- local persistence and vault connection
- search and retrieval across notes
- note-grounded AI assistance
- contextual memory surfaces around the active vault and active note
- workspace/session memory
- graph and temporal views only insofar as they support the core note-thinking experience
- polish, responsiveness, and trust in the day-to-day writing/research workflow

### Core V1 Product Surfaces

These are in scope for release gating because they are live and user-facing:

- `Epistemos/App/RootView.swift` — main shell and landing/chat routing
- `Epistemos/Views/Landing/LandingView.swift` — landing/search/composer entry point
- `Epistemos/Views/Notes/ProseEditorView.swift` and `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` — production note editor
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` and `Epistemos/Views/Notes/NoteWindowManager.swift` — note workspace and note windows
- `Epistemos/Sync/NoteFileStorage.swift` and `Epistemos/Sync/VaultSyncService.swift` — local note bodies and vault bridge
- `Epistemos/Sync/SearchIndexService.swift` — FTS-backed note/block search
- `Epistemos/State/NoteChatState.swift` and `Epistemos/App/ChatCoordinator.swift` — note-grounded AI
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` — live recall support already feeding note chat
- `Epistemos/Engine/NoteInsightService.swift` — related-note and semantic note analysis
- `Epistemos/State/WorkspaceService.swift` and `Epistemos/State/WorkspaceSummaryService.swift` — workspace memory and session summaries
- `Epistemos/State/TimeMachineService.swift` and `Epistemos/Views/Landing/TimeMachineView.swift` — time-machine surface
- `Epistemos/Graph/GraphState.swift`, `Epistemos/Graph/GraphStore.swift`, and `Epistemos/Views/Graph/HologramOverlay.swift` — graph surface

## What Does Not Count As V1 Gating

These areas may exist in the tree and may be cataloged as context, but they are not V1 blockers:

- `Epistemos/Omega/**`
- `Epistemos/Views/Omega/**`
- `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
- `Epistemos/Intents/Custom/OmegaIntent.swift`
- autonomous computer use
- Screen2AX
- multi-agent orchestration
- MCP-heavy automation workflows
- agent memory/recipe systems
- app-control / browser-control / terminal-control features
- self-improvement loops and autoresearch loops
- per-app adapter routing and MoLoRA ambitions
- full knowledge-fusion training pipelines, QLoRA/KTO, and training-data generation
- planned model-tier migration work (`1B nano / 3B base / 8B pro`)

### Why Omega And Agents Are Explicitly Out

They fail the V1 coherence test for this release decision:

- they are not required to make the note-thinking app coherent
- they pull the product story toward automation instead of thinking-with-notes
- they introduce additional permission, security, and distribution complexity
- they risk turning a release-readiness audit into scope creep
- they overlap heavily with training and routing work that is still intentionally evolving

## The Practical V1 Definition

If the app can reliably let a user:

- connect a vault
- create and edit notes comfortably
- search and retrieve notes quickly
- chat with their notes and current vault context
- reopen their prior workspace
- inspect recent session history and summaries
- optionally use graph/time surfaces as advanced support tools

then V1 can ship without Omega, Agents, Screen2AX, or training-system completion.

## Anti-Scope-Creep Rules

- Do not fail V1 because the North Star contains V2/V3/V4 ideas.
- Do not count a prototype, stub, or dormant file as a shipping obligation.
- Do not let Omega re-enter V1 through onboarding, marketing, or settings copy.
- Do not headline immersive temporal visualization, belief tracking, or agent automation unless the app actually delivers them end to end.
- Treat graph and time-machine surfaces as advanced support features unless they are validated to the same standard as the note workflow.

## Anti-Training-Interference Rules

Pre-launch recommendations should avoid destabilizing deferred training work.

### Safe Before V1

- release-copy and onboarding clarity
- settings information architecture
- build/release reproducibility work
- manual QA and smoke testing
- bug fixes in core note/search/workspace flows that do not change corpus structure

### Avoid Before V1

- changing note corpus formatting in ways that alter future training data assumptions
- changing retrieval/index formats that would force re-ingestion or invalidate prepared assets
- changing prompt/data contracts relied on by trace generation or adapter work
- changing model-routing contracts or checkpoint assumptions
- coupling the shipping note app more tightly to Omega or training subsystems

## Recommendation Standard

Every pre-launch recommendation should carry a training interference rating:

- `None` — no effect on training, adapters, retrieval assets, or corpus contracts
- `Low` — small localized effect, no retraining debt expected
- `Medium` — touches formats, prompts, indexing, or runtime contracts enough to create follow-up work
- `High` — would likely create retraining debt, asset invalidation, or model-stack churn

The intended V1 polish set should stay almost entirely in `None` or `Low`.

## Release Boundary Summary

### In

- notes
- vault
- TK2 editor
- search
- note-grounded AI
- recall/context surfaces
- workspace/session memory
- graph as an advanced but real surface
- time machine as an advanced but real surface

### Out

- Omega
- Agents
- computer use
- Screen2AX
- training pipelines
- MoLoRA / adapter-routing evolution
- self-improvement loops
- major model-stack migration work
