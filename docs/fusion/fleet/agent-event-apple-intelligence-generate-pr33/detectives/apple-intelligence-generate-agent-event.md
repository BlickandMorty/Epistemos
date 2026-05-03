---
role: detective
slice: agent-event-apple-intelligence-generate-pr33
concept: Apple Intelligence direct generate AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §0 H3, §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AppleIntelligenceService.swift:34
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AppleIntelligenceService.swift:165
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_apple_intelligence_generate_pr33_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Apple Intelligence fallback is real"
  code_says: "[paraphrase] AppleIntelligenceService.generate exists and is called from TriageService and app surfaces."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AppleIntelligenceService.swift
load_bearing_quote: "Apple Intelligence fallback is real"
verdict: open
usefulness: +1
usefulness_reason: Identifies an uninstrumented direct on-device runtime boundary after PR32.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H3 says Apple Intelligence is real, not placeholder, so provenance gaps on this path matter.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12 allows Apple Intelligence inside Core/App Store bounded execution.
- `AppleIntelligenceService.generate(...)` is the direct service boundary; no `AgentToolProvenanceRecorder` exists in the file today.
- The service augments system prompts with model-vault context before generation, so the PR must persist only counts/booleans, never prompt text or augmented prompt content.

## Open Questions

- Whether to mount a shared app-level recorder through `AppBootstrap`; recommendation is no for PR33 because `AgentToolProvenanceRecorder()` already persists through `EventStore.shared` and avoids unrelated app bootstrap churn.

## Recommendation

Add injectable test seams plus additive AgentEvent lifecycle recording inside `AppleIntelligenceService.generate(...)`. Keep FoundationModels behavior, thermal policy, breaker policy, routing, and availability semantics unchanged.
