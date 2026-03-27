# Post-V1 Opportunity Map

## Purpose

This document separates high-upside post-V1 opportunities from V1 release gating.

The rule is simple:

- V1 ships the coherent note-thinking app
- post-V1 work expands that app
- deferred moonshots do not get to redefine whether V1 is “real”

## Foundation-First Opportunities

These are the best post-V1 investments because they deepen the product Epistemos already is.

### 1. Stronger Ambient Retrieval

Build on:

- `Epistemos/App/AppCoordinator.swift#refreshAmbientManifest`
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Engine/NoteInsightService.swift`

What this could become:

- more automatic context shadows
- stronger cross-note recall in home chat
- better note-level suggestions while writing
- more visible “I remember this for you” product moments

Why it matters:

- it strengthens the core promise without changing the app’s identity

### 2. Temporal Knowledge, Not Just Session History

Build on:

- `Epistemos/Models/SDPageVersion.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/State/TimeMachineService.swift`
- `Epistemos/Views/Landing/TimeMachineView.swift`

What this could become:

- explicit contradiction tracking
- belief evolution timelines
- “what changed in my thinking?” views
- stronger intellectual-autobiography tooling

Why it matters:

- it is one of the most distinctive ideas in the research corpus
- it is currently only partially alive

### 3. Better Cross-Note Synthesis

Build on:

- `Epistemos/Engine/NoteInsightService.swift`
- `Epistemos/State/WorkspaceSummaryService.swift`
- `Epistemos/State/DailyBriefState.swift`
- `Epistemos/State/DialogueChatState.swift`

What this could become:

- gap detector
- contradiction surfacing
- merge/split suggestions
- “stale but now relevant” note resurfacing

Why it matters:

- it turns retrieval into reasoning support rather than plain recall

### 4. Graph As A True Thinking Surface

Build on:

- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Views/Graph/HologramOverlay.swift`
- `Epistemos/Views/Graph/HologramNodeInspector.swift`

What this could become:

- stronger page-scoped graph workflows
- richer graph-native queries
- better graph-to-note round trips
- more trustworthy graph storytelling

Why it matters:

- the graph is already real, but still feels like an advanced surface rather than a central reasoning tool

## Fantasy-First Opportunities

These may be valuable long-term, but they should not distort near-term priorities.

### 1. Full Omega / Agentic Computer Use

Examples:

- `Epistemos/Omega/**`
- `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
- `Epistemos/Intents/Custom/OmegaIntent.swift`

Why this waits:

- different product boundary
- different risk profile
- different permission and distribution story

### 2. Full Knowledge-Fusion Training Flywheel

Examples:

- `Epistemos/KnowledgeFusion/**`
- `docs/TRAINING_GUIDE.md`

Why this waits:

- high complexity
- high training interference risk
- not required for a coherent first release

### 3. Full Dual-Brain / Device-Action Vision

Why this waits:

- it belongs to a later platform layer, not the first public statement of what Epistemos is

## Horizon View

## +1 Week

Best outcomes:

- cleaner V1 story in onboarding/settings/release materials
- reproducible build and release checklist
- sharper QA confidence in the core note workflow

Training interference:

- `None`

## +2 To 4 Weeks

Best outcomes:

- more visible ambient retrieval
- stronger related-note explanations
- better graph/time-machine polish
- more coherent advanced-surface storytelling

Training interference:

- mostly `None` to `Low` if retrieval formats stay stable

## +1 To 2 Months

Best outcomes:

- first-class gap detector
- contradiction and belief-drift tooling
- stronger query and synthesis workflows
- graph becoming a real cognitive surface instead of an optional visual extra

Training interference:

- `Low` to `Medium`, depending on whether storage/index/prompt contracts change

## Long-Horizon North Star

Best outcomes:

- true temporal epistemic operating system
- deeply personalized recall and synthesis
- optional automation and agentic execution
- optional training/fusion systems that sit on top of a stable core product

Training interference:

- often `Medium` to `High`

## Best Post-V1 Sequence

1. Deepen retrieval and cross-note synthesis first.
2. Deepen temporal knowledge second.
3. Deepen graph utility third.
4. Revisit agentic and training-heavy systems only after the core app has shipped cleanly and learned from real users.

## What Not To Do Immediately After V1

- do not let Omega become the new default release frame before the core app matures
- do not create retraining debt by churning note formats or retrieval contracts casually
- do not confuse “interesting infrastructure” with “better user value”
- do not expand scope faster than the product story gets clearer
